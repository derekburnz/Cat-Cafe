--!strict
-- Purr Pot client audio (sound-designer). Builds the four SoundGroup channels, plays cues from Cues.luau, runs the
-- day and night music and the zone ambience, and turns moments into sounds. Client only: the server never plays a
-- sound. Asset ids live only in Cues.luau; a cue with no ids yet, or a file that fails to load, stays silent.
-- Rules: .claude/skills/audio-pipeline/SKILL.md section 7. How to wire it in: README.md next to this file.
--
-- Roblox terms: a Sound plays one audio asset. Parented to a part or attachment it plays in 3D (from that spot,
-- fading with distance); anywhere else it plays flat (2D). A SoundGroup is a mixer channel: every Sound points
-- at one, and the channel's Volume scales them all, which is how the settings toggles mute music or effects.

local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Cues = require(script.Cues)
local Logic = require(script.Logic)

local Audio = {}

export type Target = BasePart | Attachment | Vector3
export type Settings = { music: boolean, sfx: boolean }

-- Channel start volumes and the setting that mutes each (sound list section 2).
local GROUPS: { [string]: { volume: number, mutedBy: "music" | "sfx" } } = {
	Music = { volume = 0.5, mutedBy = "music" },
	Ambience = { volume = 0.6, mutedBy = "sfx" },
	Sfx = { volume = 0.8, mutedBy = "sfx" },
	Ui = { volume = 0.7, mutedBy = "sfx" },
}

local MUSIC_FADE = 2
local AMBIENCE_FADE = 1.5
local LOOP_FADE = 0.3
local DUCK_FADE = 0.3
local STINGER_DUCK = 0.4 -- music level under a stinger, the rank up jingle, a shiny reveal, the big fanfares
local CATCH_MUSIC = 0.6 -- music level during a catch or rescue
local CATCH_AMBIENCE = 0.5
local CATCH_DUCK_LIMIT = 30 -- seconds; a catch that never reports back still lets the music up again
local DUCK_LIMIT = 8 -- seconds; a stinger that never loads (so never ends) still lets the music up again
local ROLL_OFF_MIN = 8 -- studs of full volume around a 3D sound
local DEFAULT_RANGE = 60 -- studs at which a 3D sound fades out when its cue sets no range

type Voice = { sound: Sound, anchor: Attachment?, startedAt: number }
type Bed = { cue: string?, sound: Sound?, ducks: { [any]: number } }

local built = false
local started = false
local groups: { [string]: SoundGroup } = {}
local holder: Folder? = nil
local pools: { [string]: { Voice } } = {}
local bedSounds: { [string]: Sound } = {}
local lastPlayed: { [string]: number } = {}
local warned: { [string]: boolean } = {}
local rng = Random.new()

local ready = false -- set by the first applySettings
local enabled: { [string]: boolean } = { Music = true, Ambience = true, Sfx = true, Ui = true }
local phase: string? = nil
local phaseEndsAt: number? = nil
local bedGeneration = 0
local catchToken = 0
local zone: string? = nil
local music: Bed = { cue = nil, sound = nil, ducks = {} }
local ambience: Bed = { cue = nil, sound = nil, ducks = {} }

local function warnOnce(key: string, message: string)
	if warned[key] then
		return
	end
	warned[key] = true
	warn("[Audio] " .. message)
end

-- True when the cue has at least one uploaded file.
local function has(cueId: string): boolean
	local cue = Cues[cueId]
	return cue ~= nil and #cue.ids > 0
end

local function exists(cueId: string): boolean
	return Cues[cueId] ~= nil
end

local function tweenVolume(sound: Sound, volume: number, seconds: number): Tween
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local tween = TweenService:Create(sound, info, { Volume = volume })
	tween:Play()
	return tween
end

-- The four channels live in SoundService; Sounds that play flat wait in one folder next to them.
local function build()
	if built then
		return
	end
	built = true
	for name, def in GROUPS do
		local existing = SoundService:FindFirstChild(name)
		local group: SoundGroup
		if existing ~= nil and existing:IsA("SoundGroup") then
			group = existing :: SoundGroup
		else
			group = Instance.new("SoundGroup")
			group.Name = name
			group.Parent = SoundService
		end
		group.Volume = def.volume
		groups[name] = group
	end
	local folder = Instance.new("Folder")
	folder.Name = "CueSounds"
	folder.Parent = SoundService
	holder = folder
end

local function newSound(cueId: string, cue: Cues.Cue): Sound
	build()
	local sound = Instance.new("Sound")
	sound.Name = cueId
	sound.SoundGroup = groups[cue.group]
	sound.Volume = cue.volume
	sound.Looped = cue.looped == true
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = ROLL_OFF_MIN
	sound.RollOffMaxDistance = cue.range or DEFAULT_RANGE
	sound.Parent = holder
	return sound
end

-- Flat (nil), on a part or attachment, or at a point in the world (through an attachment in Terrain).
local function place(voice: Voice, at: Target?)
	local sound = voice.sound
	if at == nil then
		sound.Parent = holder
	elseif typeof(at) == "Vector3" then
		local anchor = voice.anchor
		if anchor == nil or anchor.Parent == nil then
			local fresh = Instance.new("Attachment")
			fresh.Name = sound.Name
			fresh.Parent = Workspace.Terrain
			voice.anchor = fresh
			anchor = fresh
		end
		(anchor :: Attachment).WorldPosition = at
		sound.Parent = anchor
	else
		sound.Parent = at
	end
end

local function dropVoice(voice: Voice)
	if voice.anchor ~= nil then
		voice.anchor:Destroy()
	end
	voice.sound:Destroy()
end

-- The pooled Sound for the next play of a cue: an idle one, a new one while under `voices`, else the oldest.
local function voiceFor(cueId: string, cue: Cues.Cue): Voice
	local pool = pools[cueId]
	if pool == nil then
		pool = {}
		pools[cueId] = pool
	end
	-- A part that streams out or is destroyed takes its Sound with it; forget those voices.
	for index = #pool, 1, -1 do
		if pool[index].sound.Parent == nil then
			dropVoice(table.remove(pool, index) :: Voice)
		end
	end
	local states: { Logic.VoiceState } = {}
	for index, voice in pool do
		states[index] = { playing = voice.sound.IsPlaying, startedAt = voice.startedAt }
	end
	local index = Logic.pickVoice(states, cue.voices or 1)
	local voice: Voice? = pool[index]
	if voice ~= nil then
		return voice
	end
	local fresh: Voice = { sound = newSound(cueId, cue), anchor = nil, startedAt = 0 }
	pool[index] = fresh
	return fresh
end

-- Ducking: a bed plays at its cue volume times the lowest active duck.
local function applyDucks(bed: Bed)
	local sound, cueId = bed.sound, bed.cue
	if sound ~= nil and cueId ~= nil then
		tweenVolume(sound, Cues[cueId].volume * Logic.duckLevel(bed.ducks), DUCK_FADE)
	end
end

-- Ducks the music to 40 % until `sound` ends, or DUCK_LIMIT seconds if it never loads.
local function duckWhile(sound: Sound)
	local key = {}
	music.ducks[key] = STINGER_DUCK
	applyDucks(music)
	local released = false
	local function release()
		if released then
			return
		end
		released = true
		music.ducks[key] = nil
		applyDucks(music)
	end
	sound.Ended:Once(release)
	task.delay(DUCK_LIMIT, release)
end

-- Music to 60 % and ambience to 50 % while a catch or rescue runs, so the circles are easy to hear.
local function duckForCatch(on: boolean)
	catchToken += 1
	local token = catchToken
	if on then
		music.ducks["catch"] = CATCH_MUSIC
		ambience.ducks["catch"] = CATCH_AMBIENCE
		task.delay(CATCH_DUCK_LIMIT, function()
			if token == catchToken then
				duckForCatch(false)
			end
		end)
	else
		music.ducks["catch"] = nil
		ambience.ducks["catch"] = nil
	end
	applyDucks(music)
	applyDucks(ambience)
end

-- One kept Sound per music or ambience bed, made on first use; nil while the cue has no file.
local function loopSound(cueId: string): Sound?
	local kept: Sound? = bedSounds[cueId]
	if kept ~= nil then
		return kept
	end
	local cue = Cues[cueId]
	if cue == nil then
		return nil
	end
	local id = Logic.pickId(cue.ids, rng:NextNumber())
	if id == nil then
		return nil
	end
	local sound = newSound(cueId, cue)
	sound.Looped = true
	sound.SoundId = id
	bedSounds[cueId] = sound
	return sound
end

-- Crossfades a bed (music or ambience) to another cue; nil fades to silence. One bed of each plays at a time.
local function crossfade(bed: Bed, cueId: string?, fade: number)
	if cueId == bed.cue then
		return
	end
	local old = bed.sound
	if old ~= nil then
		tweenVolume(old, 0, fade).Completed:Once(function(state: Enum.PlaybackState)
			if state == Enum.PlaybackState.Completed and old ~= bed.sound then
				old:Stop()
			end
		end)
	end
	local sound = if cueId ~= nil then loopSound(cueId) else nil
	bed.cue = if sound ~= nil then cueId else nil
	bed.sound = sound
	if sound ~= nil and cueId ~= nil then
		sound.Volume = 0
		sound.TimePosition = 0
		sound:Play()
		tweenVolume(sound, Cues[cueId].volume * Logic.duckLevel(bed.ducks), fade)
	end
end

-- Plays a cue once. `at` makes it 3D (a part, an attachment or a point); nil plays it flat. `step` raises the
-- pitch one note of the pentatonic scale per step (circle 1 to 5, rescue hit 1 to 6). Returns the Sound, or nil
-- when the cue is silent (no file yet, or played again inside its minGap).
function Audio.play(cueId: string, at: Target?, step: number?): Sound?
	local cue = Cues[cueId]
	if cue == nil then
		warnOnce(cueId, "no cue named " .. cueId)
		return nil
	end
	local id = Logic.pickId(cue.ids, rng:NextNumber())
	if id == nil or not enabled[cue.group] then
		return nil -- no file yet, or its channel is muted (nothing to download)
	end
	local now = os.clock()
	if not Logic.canPlay(lastPlayed[cueId], now, cue.minGap or 0) then
		return nil
	end
	lastPlayed[cueId] = now
	local voice = voiceFor(cueId, cue)
	local sound = voice.sound
	sound.SoundId = id
	sound.PlaybackSpeed = Logic.speed(cue.pitch, step, rng:NextNumber())
	place(voice, at)
	voice.startedAt = now
	sound.TimePosition = 0
	sound:Play()
	if cue.duck then
		duckWhile(sound)
	end
	return sound
end

-- Starts a looped cue (carryPurr, loopDealerCart, shimmerRare, loopFountain) at a target, flat when nil. Returns
-- a function that fades it out and removes it. Safe to call for a cue with no file yet (returns a no-op).
function Audio.loop(cueId: string, at: Target?): () -> ()
	local cue = Cues[cueId]
	if cue == nil then
		warnOnce(cueId, "no cue named " .. cueId)
		return function() end
	end
	local id = Logic.pickId(cue.ids, rng:NextNumber())
	if id == nil or not enabled[cue.group] then
		return function() end
	end
	local voice: Voice = { sound = newSound(cueId, cue), anchor = nil, startedAt = os.clock() }
	local sound = voice.sound
	sound.Looped = true
	sound.SoundId = id
	sound.PlaybackSpeed = Logic.speed(cue.pitch, nil, rng:NextNumber())
	place(voice, at)
	sound.Volume = 0
	sound:Play()
	tweenVolume(sound, cue.volume, LOOP_FADE)
	local stopped = false
	return function()
		if stopped then
			return
		end
		stopped = true
		if sound.Parent == nil then
			dropVoice(voice) -- its part is already gone
			return
		end
		tweenVolume(sound, 0, LOOP_FADE).Completed:Once(function()
			dropVoice(voice)
		end)
	end
end

local function phaseLength(name: string?): number
	return if name == "night" then Config.NightLengthSeconds else Config.DayLengthSeconds
end

-- Music follows the server clock. On a phase change the bed fades out, the stinger plays and the new phase's
-- A bed fades in; B takes over halfway through the phase. Joining mid-phase picks the bed for that moment.
-- With music turned off no bed is loaded at all.
local function refreshMusic(changed: boolean)
	if not ready then
		return
	end
	bedGeneration += 1
	local generation = bedGeneration
	if not enabled.Music then
		crossfade(music, nil, MUSIC_FADE)
		return
	end
	local half = phaseLength(phase) / 2
	local into = 0
	if changed then
		crossfade(music, nil, MUSIC_FADE)
		Audio.play(if phase == "night" then "stingDusk" else "stingDawn")
		task.delay(MUSIC_FADE, function()
			if generation == bedGeneration then
				crossfade(music, Logic.bedFor(phase, 0, half, has), MUSIC_FADE)
			end
		end)
	else
		into = Logic.secondsInto(phaseLength(phase), phaseEndsAt, Workspace:GetServerTimeNow())
		crossfade(music, Logic.bedFor(phase, into, half, has), MUSIC_FADE)
	end
	if into < half then
		task.delay(half - into, function()
			if generation == bedGeneration then
				crossfade(music, Logic.bedFor(phase, half, half, has), MUSIC_FADE)
			end
		end)
	end
end

local function refreshAmbience()
	if ready then
		local cueId = if enabled.Ambience then Logic.ambienceFor(zone, phase, has) else nil
		crossfade(ambience, cueId, AMBIENCE_FADE)
	end
end

local function followClock()
	local clock = ReplicatedStorage:WaitForChild("Clock")
	local function read()
		local value = clock:GetAttribute("Phase")
		phase = if type(value) == "string" then value else nil
		local endsAt = clock:GetAttribute("PhaseEndsAt")
		phaseEndsAt = if type(endsAt) == "number" then endsAt else nil
	end
	read()
	clock:GetAttributeChangedSignal("Phase"):Connect(function()
		local before = phase
		read()
		refreshMusic(before ~= nil)
		refreshAmbience()
	end)
	clock:GetAttributeChangedSignal("PhaseEndsAt"):Connect(read)
	refreshMusic(false)
	refreshAmbience()
end

-- Loads the short cues marked preload, so the first net swing is not late. Failures are logged once.
local function preload()
	local sounds: { Instance } = {}
	for _, cue in Cues do
		if cue.preload then
			for _, id in cue.ids do
				local sound = Instance.new("Sound")
				sound.SoundId = id
				table.insert(sounds, sound)
			end
		end
	end
	if #sounds == 0 then
		return
	end
	local ok, err = pcall(function()
		ContentProvider:PreloadAsync(
			sounds,
			function(assetId: string, status: Enum.AssetFetchStatus)
				if status ~= Enum.AssetFetchStatus.Success then
					warnOnce(assetId, "could not load " .. assetId .. " (" .. status.Name .. ")")
				end
			end
		)
	end)
	if not ok then
		warnOnce("preload", "preload failed: " .. tostring(err))
	end
	for _, sound in sounds do
		sound:Destroy()
	end
end

-- Moments ------------------------------------------------------------------------------------------------------
-- Moment args arrive from client code but are still checked, so a missing or odd value only loses a sound.

local function num(value: any): number?
	return if type(value) == "number" then value else nil
end

local function str(value: any): string?
	return if type(value) == "string" then value else nil
end

local function vec(value: any): Vector3?
	return if typeof(value) == "Vector3" then value else nil
end

local function you(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root :: BasePart else nil
end

-- The part of a tagged world object whose attribute matches (a Stray by StrayId, a RescueSpot by RescueSpotId).
local function taggedPart(tag: string, attribute: string?, value: any): BasePart?
	for _, instance in CollectionService:GetTagged(tag) do
		if attribute == nil or (value ~= nil and instance:GetAttribute(attribute) == value) then
			if instance:IsA("BasePart") then
				return instance :: BasePart
			elseif instance:IsA("Model") then
				local model = instance :: Model
				return model.PrimaryPart
					or model:FindFirstChildWhichIsA("BasePart", true) :: BasePart?
			end
		end
	end
	return nil
end

local carryStop: (() -> ())? = nil
local carrying = false
local dealerStop: (() -> ())? = nil
local rescueSpot: BasePart? = nil
local shimmering: { [string]: Instance } = {}

local function stopCarry()
	if carryStop ~= nil then
		carryStop()
		carryStop = nil
	end
end

-- The purr plays while carrying; restarted when the sound setting changes so it follows the toggle.
local function refreshCarry()
	stopCarry()
	if carrying then
		carryStop = Audio.loop("carryPurr")
	end
end

-- A one-shot on something the server may remove in the same frame (a fleeing stray, the leaving cart) plays at
-- its position, so the removal cannot cut it off.
local function spot(part: BasePart?): Vector3?
	return if part ~= nil then part.Position else nil
end

local function rarityJingle(rarity: any)
	local jingle = Logic.jingleFor(str(rarity))
	if jingle ~= nil then
		Audio.play(jingle)
	end
end

-- Moment name to sounds (sound list section 6). NightStart and DayStart are absent on purpose: the music already
-- follows the clock attribute, so it also knows the phase on join. CarryStart is absent too: the purr follows the
-- synced carrying state (Audio.setCarrying), so a missed moment can never leave it purring.
local HANDLERS: { [string]: (...any) -> () } = {
	CatchStart = function()
		duckForCatch(true)
		Audio.play("catchStart")
	end,
	CircleAppear = function(index: any)
		Audio.play("circleAppear", nil, num(index))
	end,
	NetSwing = function()
		Audio.play("netSwing", you())
	end,
	CircleGrade = function(index: any, grade: any)
		local cueId = Logic.gradeCue(str(grade))
		if cueId == "circleMiss" then
			Audio.play(cueId)
		elseif cueId ~= nil then
			Audio.play(cueId, nil, num(index))
		end
	end,
	CatchSuccess = function(_strayId: any, rarity: any)
		duckForCatch(false)
		Audio.play("catchSparkle")
		rarityJingle(rarity)
	end,
	CatchFail = function()
		duckForCatch(false)
		Audio.play("catchMiss")
	end,
	StrayFlee = function(strayId: any)
		Audio.play("strayFlee", spot(taggedPart("Stray", "StrayId", strayId)))
	end,

	RescueStart = function(rescueSpotId: any)
		rescueSpot = taggedPart("RescueSpot", "RescueSpotId", rescueSpotId)
		duckForCatch(true)
		Audio.play("rescueStart")
	end,
	RescueHit = function(hits: any, _needed: any, _pawsLeft: any, trapType: any)
		local cueId = Logic.trapCue(str(trapType))
		if cueId ~= nil then
			Audio.play(cueId, spot(rescueSpot))
		end
		Audio.play("rescueHitTone", nil, num(hits))
	end,
	RescueMiss = function()
		Audio.play("rescueMiss")
	end,
	RescueDrop = function()
		Audio.play("rescueDrop", spot(rescueSpot))
	end,
	RescueDone = function(_rescueSpotId: any, rarity: any)
		duckForCatch(false)
		Audio.play("rescueDone")
		rarityJingle(rarity)
	end,
	RescueFail = function()
		duckForCatch(false)
		Audio.play("rescueFail")
	end,
	RescueCancel = function()
		duckForCatch(false)
		Audio.play("rescueFail")
	end,

	BumpLoose = function(role: any, position: any)
		if role == "carrier" then
			Audio.play("uiError")
		end
		Audio.play("bumpLoose", vec(position))
	end,
	BumpHeld = function(_role: any, position: any)
		Audio.play("bumpHeld", vec(position))
	end,
	CheckIn = function()
		Audio.play("checkInBell", you())
	end,
	CatFound = function()
		Audio.play("jingleCatFound")
	end,

	BaitPlaced = function(lureId: any)
		Audio.play(Logic.foodCue(str(lureId), exists), you())
	end,
	BaitArrive = function()
		Audio.play("baitArrive")
	end,
	BaitTame = function(rarity: any)
		Audio.play("baitTame")
		rarityJingle(rarity)
	end,
	BaitLetGo = function()
		Audio.play("baitLetGo")
	end,

	ShinyReveal = function()
		Audio.play("shinyReveal")
	end,
	RareStrayNearby = function(strayId: any)
		local id = str(strayId)
		for key, part in shimmering do
			if part.Parent == nil then
				shimmering[key] = nil
			end
		end
		local part = taggedPart("Stray", "StrayId", id)
		local known: Instance? = if id ~= nil then shimmering[id] else nil
		if id ~= nil and part ~= nil and known == nil then
			shimmering[id] = part
			Audio.loop("shimmerRare", part) -- removed with the stray's part
		end
	end,
	CatPlaced = function()
		Audio.play("catPlaced")
	end,
	CatSold = function()
		Audio.play("catSold")
	end,

	CoinPop = function(position: any)
		Audio.play("coinPop", vec(position))
	end,
	Purchase = function()
		Audio.play("purchase")
	end,
	RankUp = function()
		Audio.play("jingleRankUp")
	end,
	AreaUnlock = function()
		Audio.play("gateOpen")
	end,
	RichArrive = function()
		Audio.play("richArrive")
	end,
	RichTipClaim = function()
		Audio.play("richTip")
	end,
	DealerArrive = function()
		local cart = taggedPart("DealerCart")
		Audio.play("dealerArrive", cart)
		if dealerStop == nil and cart ~= nil then
			dealerStop = Audio.loop("loopDealerCart", cart)
		end
	end,
	DealerLeave = function()
		if dealerStop ~= nil then
			dealerStop()
			dealerStop = nil
		end
		Audio.play("dealerLeave", spot(taggedPart("DealerCart")))
	end,
	OfflineClaim = function()
		Audio.play("offlineClaim")
	end,
	Announce = function()
		Audio.play("announce")
	end,
}

-- Public hooks -------------------------------------------------------------------------------------------------

-- Builds the channels, preloads the short cues and starts following the server clock. Music and ambience wait for
-- the first applySettings, so a player who turned music off never hears a note.
function Audio.start()
	if started then
		return
	end
	started = true
	build()
	task.spawn(preload)
	task.spawn(followClock)
end

-- Applies the player's settings (ProfileSync `settings`): music off silences Music; sound off silences Ambience,
-- Sfx and Ui. A muted channel loads nothing. Call it on every ProfileSync and on each toggle; it is cheap.
function Audio.applySettings(settings: Settings)
	build()
	local musicWas, ambienceWas, sfxWas = enabled.Music, enabled.Ambience, enabled.Sfx
	for name, def in GROUPS do
		local on = if def.mutedBy == "music" then settings.music ~= false else settings.sfx ~= false
		enabled[name] = on
		groups[name].Volume = Logic.groupVolume(def.volume, on)
	end
	if enabled.Sfx ~= sfxWas then
		refreshCarry()
	end
	if not ready then
		ready = true
		refreshMusic(false)
		refreshAmbience()
		return
	end
	if enabled.Music ~= musicWas then
		refreshMusic(false)
	end
	if enabled.Ambience ~= ambienceWas then
		refreshAmbience()
	end
end

-- Whether the player is carrying a cat (ProfileSync `carrying` is set): a quiet purr plays while it is.
-- Call it on every ProfileSync; it only starts or stops the purr when the state changes.
function Audio.setCarrying(isCarrying: boolean)
	if isCarrying ~= carrying then
		carrying = isCarrying
		refreshCarry()
	end
end

-- The zone the ambience follows: "Cafe", "Alley", "Park" (later "Neighbourhood", "Woods", "Sewer"); nil for none.
function Audio.setZone(newZone: string?)
	zone = newZone
	refreshAmbience()
end

-- Connects every moment Audio knows to its sounds. `moments` maps a moment name to a signal with :Connect
-- (src/client/Moments.luau once the engineer adds it); moments it does not have yet are skipped.
function Audio.bindMoments(moments: { [string]: any })
	for name, handler in HANDLERS do
		local signal = moments[name]
		if signal ~= nil then
			signal:Connect(handler)
		end
	end
end

return Audio
