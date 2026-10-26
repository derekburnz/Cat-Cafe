--!strict
-- Pure audio rules for the Audio module: which voice to reuse, spam gaps, pitch, which music bed or ambience bed
-- plays, ducking and channel volumes. Pure: no Roblox services, so tests can require it.
-- The rules come from docs/audio/cat-cafe/sound-list.md sections 2 to 5.

local Logic = {}

-- Major pentatonic as PlaybackSpeed (sound list 5.1): circle 1 to 5 plays one step higher each, so a run of
-- Perfects plays a little tune from one sample. Steps past 5 go up an octave (a 6-hit rescue).
Logic.SCALE = { 1, 1.125, 1.25, 1.5, 5 / 3 }

export type VoiceState = { playing: boolean, startedAt: number }

-- Index of the voice to use: the first idle one, a new one (#voices + 1) while under `max`, else the oldest.
function Logic.pickVoice(voices: { VoiceState }, max: number): number
	for index, voice in voices do
		if not voice.playing then
			return index
		end
	end
	if #voices < math.max(1, max) then
		return #voices + 1
	end
	local oldest = 1
	for index, voice in voices do
		if voice.startedAt < voices[oldest].startedAt then
			oldest = index
		end
	end
	return oldest
end

-- False while the cue played less than `minGap` seconds ago (drops coin spam and double presses).
function Logic.canPlay(lastPlayed: number?, now: number, minGap: number): boolean
	return lastPlayed == nil or now - lastPlayed >= minGap
end

-- PlaybackSpeed for one step of the scale; nil or below 1 is the root.
function Logic.scaleStep(step: number?): number
	if step == nil or step < 1 then
		return 1
	end
	local index = math.floor(step) - 1
	local octave = index // #Logic.SCALE
	return Logic.SCALE[index % #Logic.SCALE + 1] * 2 ^ octave
end

-- PlaybackSpeed for one play: the scale step times a random pick inside the cue's pitch range.
-- `roll` is a number in [0, 1), passed in so tests stay deterministic.
function Logic.speed(pitch: { number }?, step: number?, roll: number): number
	local base = Logic.scaleStep(step)
	if pitch == nil or #pitch < 2 then
		return base
	end
	return base * (pitch[1] + (pitch[2] - pitch[1]) * roll)
end

-- One asset id out of a cue's variants; nil when the cue has none yet (silent, never an error).
function Logic.pickId(ids: { string }, roll: number): string?
	if #ids == 0 then
		return nil
	end
	return ids[math.clamp(math.floor(roll * #ids) + 1, 1, #ids)]
end

-- Seconds already played of the current phase, from its length and the shared server clock.
function Logic.secondsInto(phaseLength: number, endsAt: number?, now: number): number
	if endsAt == nil then
		return 0
	end
	return math.clamp(phaseLength - (endsAt - now), 0, phaseLength)
end

-- The music bed for a phase: A first, B once `bedSeconds` have played (sound list section 3). Falls back to the
-- other bed when one has no file yet, and to nil when neither has.
function Logic.bedFor(
	phase: string?,
	secondsInto: number,
	bedSeconds: number,
	has: (string) -> boolean
): string?
	local base = if phase == "night" then "musicNight" else "musicDay"
	local first, second = base .. "A", base .. "B"
	local want = if secondsInto >= bedSeconds then second else first
	if has(want) then
		return want
	end
	local other = if want == first then second else first
	return if has(other) then other else nil
end

-- The ambience bed for a zone and phase: amb<Zone><Day|Night>, else amb<Zone>, else nil (silence).
function Logic.ambienceFor(zone: string?, phase: string?, has: (string) -> boolean): string?
	if zone == nil or zone == "" then
		return nil
	end
	local name = "amb" .. string.upper(string.sub(zone, 1, 1)) .. string.sub(zone, 2)
	local timed = name .. (if phase == "night" then "Night" else "Day")
	if has(timed) then
		return timed
	end
	return if has(name) then name else nil
end

-- The music level while ducks are active: the lowest one wins, 1 when there are none.
function Logic.duckLevel(ducks: { [any]: number }): number
	local level = 1
	for _, value in ducks do
		level = math.min(level, value)
	end
	return level
end

-- A channel's volume: its start volume, or 0 when the player's setting turns it off.
function Logic.groupVolume(base: number, enabled: boolean): number
	return if enabled then base else 0
end

-- The catch jingle for a rarity (sound list section 3); Common has none. Secret is the v0.2 name for Mythical.
local JINGLES: { [string]: string } = {
	rare = "jingleRare",
	epic = "jingleEpic",
	legendary = "jingleLegendary",
	mythical = "jingleMythical",
	secret = "jingleMythical",
}

function Logic.jingleFor(rarity: string?): string?
	if rarity == nil then
		return nil
	end
	return JINGLES[string.lower(rarity)]
end

-- A rarity's place in the order, 1 for Common up to 5 for Mythical, so a shout-out chime rises with rarity.
local RARITY_STEPS: { [string]: number } =
	{ common = 1, rare = 2, epic = 3, legendary = 4, mythical = 5, secret = 5 }

function Logic.rarityStep(rarity: string?): number?
	if rarity == nil then
		return nil
	end
	return RARITY_STEPS[string.lower(rarity)]
end

-- The indexes of the `max` nearest distances within `radius`, nearest first (which world loops to keep playing).
function Logic.nearest(distances: { number }, radius: number, max: number): { number }
	local inside = {}
	for index, distance in distances do
		if distance <= radius then
			table.insert(inside, index)
		end
	end
	table.sort(inside, function(a, b)
		return distances[a] < distances[b]
	end)
	local out = {}
	for i = 1, math.min(max, #inside) do
		out[i] = inside[i]
	end
	return out
end

-- The grade cue for a circle; the code says "perfect", the sound list says "Perfect", both work.
local GRADES: { [string]: string } = {
	perfect = "circlePerfect",
	good = "circleGood",
	miss = "circleMiss",
}

function Logic.gradeCue(grade: string?): string?
	if grade == nil then
		return nil
	end
	return GRADES[string.lower(grade)]
end

-- The food cue for a bait id: foodKibble, foodTuna, foodSalmon; anything else is a dealer food.
function Logic.foodCue(lureId: string?, exists: (string) -> boolean): string
	if lureId ~= nil and lureId ~= "" then
		local name = "food" .. string.upper(string.sub(lureId, 1, 1)) .. string.sub(lureId, 2)
		if exists(name) then
			return name
		end
	end
	return "foodDealer"
end

-- The hit cue for a rescue trap (data-model TrapType); nil for a trap with no sound of its own yet.
local TRAPS: { [string]: string } = {
	trash_bin = "rescueHitBin",
	garbage_bag = "rescueHitBag",
	tree = "rescueHitTree",
	trashcan = "rescueHitCan",
}

function Logic.trapCue(trapType: string?): string?
	if trapType == nil then
		return nil
	end
	return TRAPS[trapType]
end

return Logic
