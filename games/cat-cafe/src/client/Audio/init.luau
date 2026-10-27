--!strict
-- Cat Cafe client audio (sound-designer). Builds the four SoundGroup channels, plays cues from Cues.luau, runs the
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
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Cues = require(script.Cues)
local Effects = require(script.Parent.Effects)
local Logic = require(script.Logic)

local Audio = {}

export type Target = BasePart | Attachment | Vector3
-- musicVolume and sfxVolume are the settings sliders, 0 to 1 (missing means full volume).
export type Settings = { music: boolean, sfx: boolean, musicVolume: number?, sfxVolume: number? }

-- Channel start volumes and the setting that mutes each; its slider is musicVolume or sfxVolume (sound list section 2).
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
local STINGER_DUCK = 0.4 -- music level under a stinger, the rank up jingle, a gold reveal, the big fanfares
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

-- F66: the town bell rings DuskWarningSeconds before night, with the warning banner. Rescheduled on every clock
-- change; a generation number drops a bell that a newer schedule replaced.
local DUSK_WARNING = 15 -- until Config has DuskWarningSeconds
local duskGeneration = 0

local function scheduleDuskBell()
	duskGeneration += 1
	local generation = duskGeneration
	local configured = (Config :: any).DuskWarningSeconds
	local warning = if type(configured) == "number" then configured else DUSK_WARNING
	local inSeconds = Logic.duskBellIn(phase, phaseEndsAt, Workspace:GetServerTimeNow(), warning)
	if inSeconds ~= nil then
		task.delay(inSeconds, function()
			if generation == duskGeneration then
				Audio.play("duskBell")
			end
		end)
	end
end

local function followClock()
	local clock = ReplicatedStorage:WaitForChild("Clock")
	local function read()
		local value = clock:GetAttribute("Phase")
		phase = if type(value) == "string" then value else nil
		local endsAt = clock:GetAttribute("PhaseEndsAt")
		phaseEndsAt = if type(endsAt) == "number" then endsAt else nil
		scheduleDuskBell()
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

-- The part that stands for a tagged part or model: the part itself, a model's PrimaryPart or its first part.
local function partOf(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance :: BasePart
	elseif instance:IsA("Model") then
		local model = instance :: Model
		return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true) :: BasePart?
	end
	return nil
end

-- The part of a tagged world object whose attribute matches (a Stray by StrayId, a RescueSpot by RescueSpotId).
local function taggedPart(tag: string, attribute: string?, value: any): BasePart?
	for _, instance in CollectionService:GetTagged(tag) do
		if attribute == nil or (value ~= nil and instance:GetAttribute(attribute) == value) then
			local part = partOf(instance)
			if part ~= nil then
				return part
			end
		end
	end
	return nil
end

-- A one-shot on something the server may remove in the same frame (a fleeing stray, the leaving cart) plays at
-- its position, so the removal cannot cut it off.
local function spot(part: BasePart?): Vector3?
	return if part ~= nil then part.Position else nil
end

local carryStop: (() -> ())? = nil
local carrying = false
local dealerStop: (() -> ())? = nil
local rescueSpot: BasePart? = nil
local ZONE_GAP = 4 -- seconds between zone chimes, so walking along an area's open edge plays one
local TRAVEL_QUIET = 2 -- seconds after a trip with no zone chime: the travel sound already says where you went
local lastZoneCueAt: number? = nil
local lastTravelAt: number? = nil

-- The plot model a tagged thing sits in (tag Plot), or nil.
local function plotOf(instance: Instance): Instance?
	local at = instance.Parent
	while at ~= nil and not CollectionService:HasTag(at, "Plot") do
		at = at.Parent
	end
	return at
end

-- A cafe door only chatters while the cafe is open: someone owns the plot (a For Rent shop is shut, F38) and it is
-- day (the cafe closes at night, design v0.5 F44).
local function cafeOpen(door: Instance): boolean
	local plot = plotOf(door)
	local owner = if plot ~= nil then plot:GetAttribute("OwnerUserId") else nil
	return phase ~= "night" and type(owner) == "number" and owner ~= 0
end

-- A cat this player chose to hide (Show other cats off: `HiddenLocal`, set on this client only) makes no sound.
local function shown(cat: Instance): boolean
	return cat:GetAttribute("HiddenLocal") ~= true
end

-- A stray twinkles for everyone nearby while it is gold or Epic and up (F42), so it can be found in the dark.
local function shimmers(stray: Instance): boolean
	return Logic.shimmers(stray:GetAttribute("Gold"), stray:GetAttribute("Rarity"))
end

-- World loops by CollectionService tag: the world builder tags a part or model and its loop plays while it
-- exists, streaming in and out with it. A tag with `near` plays only on the `max` (default 3) closest within that
-- many studs, so a full server never runs dozens of purrs at once. A tag with `when` plays only while that is
-- true, checked on the same tick.
type LoopDef = { cue: string, near: number?, max: number?, when: ((Instance) -> boolean)? }
local TAGGED_LOOPS: { [string]: LoopDef } = {
	CafeDoor = { cue = "loopCafeDoor", when = cafeOpen },
	Fountain = { cue = "loopFountain" },
	FishTank = { cue = "loopFishTank" },
	WorkingCat = { cue = "purr", near = 14, when = shown },
	Stray = { cue = "shimmerRare", near = 40, when = shimmers },
}
local MAX_NEAR_LOOPS = 3
local LOOP_CHECK_SECONDS = 0.5
type WorldLoop = { stop: () -> (), part: BasePart }
local worldLoops: { [Instance]: WorldLoop } = {}

-- Waits for the first applySettings like music and ambience, so a player who turned sound off never hears one.
local function startWorldLoop(instance: Instance, cueId: string)
	local running: WorldLoop? = worldLoops[instance]
	local part = partOf(instance)
	if ready and running == nil and part ~= nil then
		worldLoops[instance] = { stop = Audio.loop(cueId, part), part = part }
	end
end

local function stopWorldLoop(instance: Instance)
	local running: WorldLoop? = worldLoops[instance]
	if running ~= nil then
		worldLoops[instance] = nil
		running.stop()
	end
end

-- Starts or stops the loop of a tagged thing without `near` by its `when`.
local function syncWorldLoop(instance: Instance, def: LoopDef)
	local when = def.when
	if when == nil or when(instance) then
		startWorldLoop(instance, def.cue)
	else
		stopWorldLoop(instance)
	end
end

-- Restarts every world loop, on the first settings and after the sound setting changes (a muted channel starts
-- nothing).
local function refreshWorldLoops()
	for instance in worldLoops do
		stopWorldLoop(instance)
	end
	for tag, def in TAGGED_LOOPS do
		if def.near == nil then
			for _, instance in CollectionService:GetTagged(tag) do
				syncWorldLoop(instance, def)
			end
		end
	end
end

-- A resting cafe cat purrs by day (Logic.restingPurrs): one sitting on the seated body (Pose "sit", PR #266) the whole
-- day, one still on the lying body while it loafs (Effects.isLoafing). Only the nearest one within LOAF_NEAR, because
-- Effects animates a budget of cats and a purr from a cat that is not moving would sound wrong (reviewer N131).
-- Resting cats are the Napping children of each Plot's Cats.
local LOAF_NEAR = 14
local loafing: Instance? = nil

local function followLoaf(root: BasePart?)
	local best: Instance? = nil
	local bestDistance = LOAF_NEAR
	if root ~= nil then
		for _, plot in CollectionService:GetTagged("Plot") do
			local cats = plot:FindFirstChild("Cats")
			for _, cat in if cats ~= nil then cats:GetChildren() else {} do
				local part = if cat:IsA("Model")
						and cat:GetAttribute("Napping") == true
						and shown(cat)
					then partOf(cat)
					else nil
				local distance = if part ~= nil
					then (part.Position - root.Position).Magnitude
					else math.huge
				if
					distance <= bestDistance
					and Logic.restingPurrs(
						cat:GetAttribute("Pose"),
						phase == "night",
						Effects.isLoafing(cat :: Model)
					)
				then
					best, bestDistance = cat, distance
				end
			end
		end
	end
	local was = loafing
	if was ~= nil and was ~= best then
		stopWorldLoop(was)
	end
	loafing = best
	if best ~= nil then
		startWorldLoop(best, "purr") -- nothing while it purrs; restarts it after a settings change stopped it
	end
end

-- Twice a second: restarts a loop whose part streamed out from under its model, starts loops on tagged models
-- whose parts streamed in after the tag (reviewer N55), follows each `when` (a cafe opening or closing for the
-- night), keeps the `near` loops on the closest tagged things and the purr on the nearest resting cat.
local function followWorldLoops()
	while true do
		task.wait(LOOP_CHECK_SECONDS)
		for instance, running in worldLoops do
			if running.part.Parent == nil then
				stopWorldLoop(instance)
			end
		end
		local root = you()
		for tag, def in TAGGED_LOOPS do
			local radius = def.near
			if radius == nil then
				for _, instance in CollectionService:GetTagged(tag) do
					syncWorldLoop(instance, def)
				end
			else
				local when = def.when
				local instances: { Instance } = {}
				local distances: { number } = {}
				for _, instance in CollectionService:GetTagged(tag) do
					local part = partOf(instance)
					if root ~= nil and part ~= nil and (when == nil or when(instance)) then
						table.insert(instances, instance)
						table.insert(distances, (part.Position - root.Position).Magnitude)
					end
				end
				local keep: { [Instance]: boolean } = {}
				for _, index in Logic.nearest(distances, radius, def.max or MAX_NEAR_LOOPS) do
					keep[instances[index]] = true
					startWorldLoop(instances[index], def.cue)
				end
				for _, instance in CollectionService:GetTagged(tag) do
					if not keep[instance] then
						stopWorldLoop(instance)
					end
				end
			end
		end
		followLoaf(root)
	end
end

local function followTags()
	for tag, def in TAGGED_LOOPS do
		CollectionService:GetInstanceRemovedSignal(tag):Connect(stopWorldLoop)
		if def.near == nil then
			CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance: Instance)
				syncWorldLoop(instance, def)
			end)
			for _, instance in CollectionService:GetTagged(tag) do
				syncWorldLoop(instance, def)
			end
		end
	end
	task.spawn(followWorldLoops)
end

-- A missed cat hisses and bolts, and every player nearby hears both (reviewer N56): the hiss follows the stray's
-- HissAt attribute, which the server sets on a Miss, and the sprint its FleeingUntil (design v0.5, F40), playing
-- on the cat itself so it runs off with it. Each at most once per cat per second, like the Effects hiss.
local STRAY_GAP = 1
type StrayWatch = { connections: { RBXScriptConnection }, last: { [string]: number } }
local strayWatches: { [Instance]: StrayWatch } = {}

local function watchStray(instance: Instance)
	local existing: StrayWatch? = strayWatches[instance]
	if existing then
		return
	end
	local watch: StrayWatch = { connections = {}, last = {} }
	strayWatches[instance] = watch
	-- part is nil while the cat streams in: no sound rather than a flat one everywhere
	local function once(cueId: string, onCat: boolean)
		local now = os.clock()
		local last: number? = watch.last[cueId]
		local part = partOf(instance)
		if part ~= nil and (last == nil or now - last >= STRAY_GAP) then
			watch.last[cueId] = now
			local at: Target = if onCat then part else part.Position
			Audio.play(cueId, at)
		end
	end
	table.insert(
		watch.connections,
		instance:GetAttributeChangedSignal("HissAt"):Connect(function()
			once("catHiss", false)
		end)
	)
	table.insert(
		watch.connections,
		instance:GetAttributeChangedSignal("FleeingUntil"):Connect(function()
			local untilTime = instance:GetAttribute("FleeingUntil")
			if type(untilTime) == "number" and untilTime > Workspace:GetServerTimeNow() then
				once("straySprint", true)
			end
		end)
	)
end

local function unwatchStray(instance: Instance)
	local watch: StrayWatch? = strayWatches[instance]
	if watch then
		for _, connection in watch.connections do
			connection:Disconnect()
		end
	end
	strayWatches[instance] = nil
end

local function followStrays()
	CollectionService:GetInstanceAddedSignal("Stray"):Connect(watchStray)
	CollectionService:GetInstanceRemovedSignal("Stray"):Connect(unwatchStray)
	for _, instance in CollectionService:GetTagged("Stray") do
		watchStray(instance)
	end
end

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

-- Hold to catch (F45): a stray's or stuck cat's prompt (and a manhole's) is held for its HoldDuration before it
-- fires. The fill sound runs with the UI's fill, stretched so its pop lands on the trigger, and fades out if the
-- key is let go early. A cat that is still running shows no fill, so it plays nothing either.
local HOLD_FADE = 0.06
local holdSound: Sound? = nil
local holdPrompt: ProximityPrompt? = nil
local holdStartedAt = 0
local holdFade: Tween? = nil -- a let-go fade still running; a new hold cancels it so it cannot stop the new fill

local function running(prompt: ProximityPrompt): boolean
	local model = prompt:FindFirstAncestorWhichIsA("Model")
	local untilTime = if model ~= nil then model:GetAttribute("FleeingUntil") else nil
	return type(untilTime) == "number" and untilTime > Workspace:GetServerTimeNow()
end

local function holdBegan(prompt: ProximityPrompt)
	local playSpeed = Logic.holdSpeed(prompt.HoldDuration)
	if playSpeed == nil or prompt.Style ~= Enum.ProximityPromptStyle.Custom or running(prompt) then
		return
	end
	local sound = Audio.play("holdFill")
	if sound ~= nil then
		-- holdFill has one voice, so play() has just restarted the Sound a let-go fade was turning down; cancel
		-- that fade (its handler stops the Sound only when the fade completes) so the new fill keeps playing
		local fade = holdFade
		if fade ~= nil then
			holdFade = nil
			fade:Cancel()
		end
		sound.Volume = Cues.holdFill.volume
		sound.PlaybackSpeed = playSpeed
		holdSound, holdPrompt, holdStartedAt = sound, prompt, os.clock()
	end
end

local function holdEnded(prompt: ProximityPrompt)
	local sound = holdSound
	if sound == nil or prompt ~= holdPrompt then
		return
	end
	holdSound, holdPrompt = nil, nil
	if os.clock() - holdStartedAt >= prompt.HoldDuration - 0.05 then
		return -- the hold finished: the pop rings out
	end
	local fade = tweenVolume(sound, 0, HOLD_FADE)
	holdFade = fade
	fade.Completed:Once(function(state: Enum.PlaybackState)
		if holdFade == fade then
			holdFade = nil
		end
		if state == Enum.PlaybackState.Completed then
			sound:Stop()
		end
		sound.Volume = Cues.holdFill.volume
	end)
end

local function followHolds()
	ProximityPromptService.PromptButtonHoldBegan:Connect(holdBegan)
	ProximityPromptService.PromptButtonHoldEnded:Connect(holdEnded)
end

-- A gold cat in your arms (F42) plays the gold reveal, with the effects' burst: when the HeldCat arrives gold or
-- its Gold turns on (a rescued cat's surprise). Once per HeldCat; one already held when this starts stays quiet.
local function watchHeld(child: Instance, fresh: boolean)
	if child.Name ~= "HeldCat" or not child:IsA("Model") then
		return
	end
	local played = not fresh and child:GetAttribute("Gold") == true
	local function check()
		if not played and child:GetAttribute("Gold") == true then
			played = true
			Audio.play("goldReveal")
		end
	end
	child:GetAttributeChangedSignal("Gold"):Connect(check)
	check()
end

local function followHeldCats()
	local function watchCharacter(character: Model, fresh: boolean)
		character.ChildAdded:Connect(function(child: Instance)
			watchHeld(child, true)
		end)
		for _, child in character:GetChildren() do
			watchHeld(child, fresh)
		end
	end
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(function(character: Model)
		watchCharacter(character, true)
	end)
	local character = player.Character
	if character ~= nil then
		watchCharacter(character, false)
	end
end

-- F55 and F56 on every player's character, so everyone nearby hears them: a catch's getaway follows RushUntil (the
-- server time the Catch Rush ends) and a carry starting follows CarryStartedAt, which is how a dropped cat being
-- picked up sounds. Your own catch already rings with CatchSuccess or RescueDone, so your carry start stays quiet for
-- CATCH_QUIET after one; the check waits a moment in case the attribute lands before the moment.
local CHARACTER_GAP = 1
local CATCH_QUIET = 2
local lastCatchAt: number? = nil

local function watchCharacter(character: Model, isLocal: boolean): { RBXScriptConnection }
	local last: { [string]: number } = {}
	local function once(cueId: string)
		local now = os.clock()
		local root = character:FindFirstChild("HumanoidRootPart")
		if
			root ~= nil
			and root:IsA("BasePart")
			and Logic.canPlay(last[cueId], now, CHARACTER_GAP)
		then
			last[cueId] = now
			Audio.play(cueId, root :: BasePart)
		end
	end
	local rush = character:GetAttributeChangedSignal("RushUntil"):Connect(function()
		local untilTime = character:GetAttribute("RushUntil")
		if type(untilTime) == "number" and untilTime > Workspace:GetServerTimeNow() then
			once("getaway")
		end
	end)
	local carry = character:GetAttributeChangedSignal("CarryStartedAt"):Connect(function()
		if
			not Logic.freshStart(
				character:GetAttribute("CarryStartedAt"),
				Workspace:GetServerTimeNow()
			)
		then
			return
		end
		task.delay(0.2, function()
			if not isLocal or Logic.canPlay(lastCatchAt, os.clock(), CATCH_QUIET) then
				once("catPickUp")
			end
		end)
	end)
	return { rush, carry }
end

-- One character's watches per player, dropped when it is removed, so respawns do not pile up connections (N163).
local function followCharacters()
	local function watchPlayer(player: Player)
		local isLocal = player == Players.LocalPlayer
		local connections: { RBXScriptConnection } = {}
		local function drop()
			for _, connection in connections do
				connection:Disconnect()
			end
			connections = {}
		end
		player.CharacterAdded:Connect(function(character: Model)
			drop()
			connections = watchCharacter(character, isLocal)
		end)
		player.CharacterRemoving:Connect(drop)
		if player.Character ~= nil then
			connections = watchCharacter(player.Character, isLocal)
		end
	end
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
end

-- F61, F63 and F64 on your own plot, from its display attributes (Logic.plotCue): the tip piles being collected, the
-- Cat Collector arriving, the Mystery Visitor's gift appearing. A plot that streams out and back in is watched once.
local PLOT_ATTRIBUTES = { "TipPiles", "CollectorUntil", "MysteryGiftAt" }
local plotWatches: { [Instance]: { RBXScriptConnection } } = {}

local function watchPlot(plot: Instance)
	if plotWatches[plot] ~= nil then
		return
	end
	local connections: { RBXScriptConnection } = {}
	plotWatches[plot] = connections
	for _, attribute in PLOT_ATTRIBUTES do
		local before = plot:GetAttribute(attribute)
		table.insert(
			connections,
			plot:GetAttributeChangedSignal(attribute):Connect(function()
				local after = plot:GetAttribute(attribute)
				local cueId = Logic.plotCue(attribute, before, after)
				before = after
				if
					cueId ~= nil
					and plot:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId
				then
					Audio.play(cueId)
				end
			end)
		)
	end
end

local function unwatchPlot(plot: Instance)
	local connections: { RBXScriptConnection }? = plotWatches[plot]
	if connections then
		for _, connection in connections do
			connection:Disconnect()
		end
	end
	plotWatches[plot] = nil
end

local function followPlots()
	CollectionService:GetInstanceAddedSignal("Plot"):Connect(watchPlot)
	CollectionService:GetInstanceRemovedSignal("Plot"):Connect(unwatchPlot)
	for _, plot in CollectionService:GetTagged("Plot") do
		watchPlot(plot)
	end
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
		lastCatchAt = os.clock()
		duckForCatch(false)
		Audio.play("catchSparkle")
		rarityJingle(rarity)
	end,
	CatchFail = function()
		duckForCatch(false)
		Audio.play("catchMiss") -- the cat's hiss follows its HissAt attribute, for everyone nearby
	end,
	Purrfect = function()
		Audio.play("purrfectChime")
	end,
	StrayFlee = function(strayId: any) -- a stray leaving the area; the sprint after a miss follows FleeingUntil
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
		lastCatchAt = os.clock()
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

	-- Shove (v0.5, F41; Bump in code): every landed shove, then the knock-loose roll's result when the target
	-- was carrying. The toasts play their own bonk.
	Shove = function(_role: any, position: any)
		Audio.play("shove", vec(position))
	end,
	BumpLoose = function(_role: any, position: any)
		Audio.play("bumpLoose", vec(position))
	end,
	BumpHeld = function(_role: any, position: any)
		Audio.play("bumpHeld", vec(position))
	end,
	CheckIn = function()
		Audio.play("checkInBell", you())
	end,
	CatFound = function(_catId: any, isNew: any)
		if isNew ~= false then -- a cat you already have only rings the door bell (CheckIn)
			Audio.play("jingleCatFound")
		end
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

	-- F42: a bait or rescue cat that turns out gold; a gold cat in your arms plays it by itself (watchHeld), and a
	-- gold or Epic stray twinkles through the Stray world loop, so RareStrayNearby is gone.
	GoldReveal = function()
		Audio.play("goldReveal")
	end,
	-- Drop (F45, the Drop button or G): the cat hops down at your feet.
	CatDrop = function(position: any)
		Audio.play("catDrop", vec(position) or you())
	end,
	-- Fast travel, the My Cafe button and the manholes, once the server says the trip worked.
	Travel = function()
		lastTravelAt = os.clock()
		Audio.play("travelPoof")
	end,
	-- Roles (Staff tab, Equip Best, Unequip All): one sound however many cats change in the same sync.
	CatPlaced = function()
		Audio.play("catPlaced")
	end,
	UnplaceCat = function()
		Audio.play("catRest")
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
	AreaUnlock = function(_areaId: any, position: any)
		Audio.play("gateOpen", vec(position))
	end,
	PlotOpened = function(position: any)
		Audio.play("shuttersUp", vec(position))
		Audio.play("signFlip", vec(position))
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
	TipJarClaim = function() -- F47
		Audio.play("giftClaim")
	end,
	IndexReward = function() -- F48
		Audio.play("indexReward")
	end,
	-- F58: a Mythical shout-out (the sunrise wave's or a catch) plays its own sting once it has a file.
	Announce = function(_text: any, rarity: any)
		local cueId = Logic.announceCue(str(rarity))
		if cueId ~= "announce" and has(cueId) then
			Audio.play(cueId)
		else
			Audio.play("announce", nil, Logic.rarityStep(str(rarity)))
		end
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
	followTags()
	followStrays()
	followHolds()
	followHeldCats()
	followCharacters()
	followPlots()
end

-- Applies the player's settings (ProfileSync `settings`): music off silences Music; sound off silences Ambience,
-- Sfx and Ui. The music slider scales Music and the sound slider the other three; a switch that is off wins, and a
-- slider at 0 counts as off. A muted channel loads nothing. Call it with the first settings and again whenever they change (the
-- settings switches); a call with unchanged settings changes nothing, so calling it more often is harmless.
function Audio.applySettings(settings: Settings)
	build()
	local musicWas, ambienceWas, sfxWas = enabled.Music, enabled.Ambience, enabled.Sfx
	for name, def in GROUPS do
		local isMusic = def.mutedBy == "music"
		local switch = if isMusic then settings.music else settings.sfx
		local gain = Logic.sliderGain(if isMusic then settings.musicVolume else settings.sfxVolume)
		local on = switch ~= false and gain > 0
		enabled[name] = on
		groups[name].Volume = Logic.groupVolume(def.volume, on, gain)
	end
	if enabled.Sfx ~= sfxWas then
		refreshCarry()
	end
	if enabled.Sfx ~= sfxWas or enabled.Ambience ~= ambienceWas then
		refreshWorldLoops()
	end
	if not ready then
		ready = true
		refreshMusic(false)
		refreshAmbience()
		refreshWorldLoops()
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
-- Walking between the safe street (nil or "Cafe") and a catching area also plays a chime with the Safe zone chip:
-- zoneArea in, zoneSafe out, one per ZONE_GAP and none right after a trip.
function Audio.setZone(newZone: string?)
	local cueId = Logic.zoneCue(zone, newZone)
	zone = newZone
	refreshAmbience()
	local now = os.clock()
	if
		cueId ~= nil
		and Logic.canPlay(lastZoneCueAt, now, ZONE_GAP)
		and Logic.canPlay(lastTravelAt, now, TRAVEL_QUIET)
	then
		lastZoneCueAt = now
		Audio.play(cueId)
	end
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
