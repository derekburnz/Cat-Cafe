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

-- Music without loops (sound list section 3, 2026-11-03). The songs a phase can play: its music cues with a file
-- (musicDayA, musicDayB, ... or musicNightA, ...), in letter order, so a new song joins by getting its file.
local SONG_LETTERS = { "A", "B", "C", "D", "E", "F", "G", "H" }

function Logic.songsFor(phase: string?, has: (string) -> boolean): { string }
	local base = if phase == "night" then "musicNight" else "musicDay"
	local songs: { string } = {}
	for _, letter in SONG_LETTERS do
		if has(base .. letter) then
			table.insert(songs, base .. letter)
		end
	end
	return songs
end

-- The next song, picked by `roll` (0 to 1): never the one that just played while there is another; nil for none.
function Logic.nextSong(songs: { string }, last: string?, roll: number): string?
	local choices: { string } = {}
	for _, song in songs do
		if song ~= last then
			table.insert(choices, song)
		end
	end
	if #choices == 0 then
		choices = songs
	end
	if #choices == 0 then
		return nil
	end
	return choices[math.clamp(math.floor(roll * #choices) + 1, 1, #choices)]
end

-- Where a play starts and how long it lasts, in seconds. A song of `seconds` is `sections` equal parts; a play is
-- `play` parts from the one `roll` picks (a seamless loop wraps round its end), or from the top when `fromTop`. A
-- song with no length given plays `fallback` seconds from the top.
function Logic.songPlay(
	seconds: number?,
	sections: number?,
	play: number,
	roll: number,
	fromTop: boolean,
	fallback: number
): (number, number)
	if type(seconds) ~= "number" or seconds <= 0 then
		return 0, fallback
	end
	local parts = if type(sections) == "number" and sections >= 1 then math.floor(sections) else 1
	local part = seconds / parts
	local first = if fromTop then 0 else math.clamp(math.floor(roll * parts), 0, parts - 1)
	return first * part, math.clamp(play, 1, parts) * part
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

-- A channel's volume: its start volume times the player's slider gain (1 when there is none), or 0 when the
-- player's switch turns it off.
function Logic.groupVolume(base: number, enabled: boolean, gain: number?): number
	return if enabled then base * (gain or 1) else 0
end

-- A settings volume slider (0 to 1) as a channel gain. Squared, because loudness follows decibels rather than
-- amplitude: half way is about -12 dB, which sounds roughly half as loud, where a straight line would barely change
-- until the bottom. Missing or not a number (an old save) is full volume; out of range is clamped.
function Logic.sliderGain(value: any): number
	if type(value) ~= "number" or value ~= value then
		return 1
	end
	local clamped = math.clamp(value, 0, 1)
	return clamped * clamped
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

-- The holdFill file lands on its pop this many seconds in; HoldDuration 0.5 plays it at 0.96 so the pop meets the
-- trigger. Very short or long holds are clamped so the pitch stays friendly.
Logic.HOLD_FILL_SECONDS = 0.48

-- PlaybackSpeed for the hold sound of a prompt held for `holdDuration` seconds; nil when the prompt has no hold.
function Logic.holdSpeed(holdDuration: number): number?
	if holdDuration ~= holdDuration or holdDuration <= 0 then
		return nil
	end
	return math.clamp(Logic.HOLD_FILL_SECONDS / holdDuration, 0.5, 2)
end

-- Whether a resting cafe cat purrs (reviewer N131, N150): on the sitting body (Pose "sit", PR #266) all day, on the
-- lying body only while Effects shows it loafing; never at night, when resting cats doze.
function Logic.restingPurrs(pose: any, night: boolean, loafing: boolean): boolean
	if night then
		return false
	end
	return pose == "sit" or loafing
end

-- Seconds until the dusk bell (F66): `warning` seconds before a day ends. nil at night, with no end time, or once
-- that moment passed more than a second ago, so joining late rings nothing.
function Logic.duskBellIn(phase: string?, endsAt: number?, now: number, warning: number): number?
	if phase ~= "day" or endsAt == nil then
		return nil
	end
	local inSeconds = endsAt - warning - now
	if inSeconds < -1 then
		return nil
	end
	return math.max(inSeconds, 0)
end

-- The shout-out cue for a rarity (F58): a Mythical gets its own sting, everything else the two-note chime.
function Logic.announceCue(rarity: string?): string
	local step = Logic.rarityStep(rarity)
	return if step ~= nil and step >= 5 then "announceMythical" else "announce"
end

-- Whether a server time attribute (a carry's CarryStartedAt, a tackle's TackleAt) is fresh: set within the last
-- `window` seconds (2 unless given), not a stale value seen on join. Anything but a number is not.
function Logic.freshStart(startedAt: any, now: number, window: number?): boolean
	return type(startedAt) == "number" and startedAt <= now + 1 and now - startedAt <= (window or 2)
end

-- The cue for a change to one of your plot's display attributes (data-model section 13): the Cat Collector arriving
-- (F63) and the Mystery Visitor's gift appearing (F64). The gift clearing stays quiet, since the server also clears
-- it at MysteryGiftKeepSeconds or a plot release; the UI plays giftOpen with the MysteryGiftResult card. TipPiles is
-- silent since F97 (#714): a pile pays as it appears (CoinPop) and the count only drops when old piles are swept.
-- A missing or odd value counts as 0; nil for anything else.
function Logic.plotCue(attribute: string, before: any, after: any): string?
	local was = if type(before) == "number" then before else 0
	local is = if type(after) == "number" then after else 0
	if attribute == "CollectorUntil" then
		return if was <= 0 and is > 0 then "visitorCollector" else nil
	elseif attribute == "MysteryGiftAt" then
		return if was <= 0 and is > 0 then "visitorMystery" else nil
	end
	return nil
end

-- F84: whether a spot (world X and Z) is out in a wild area. The four wild areas sit wildDistance from the
-- hometown's centre on the compass points and the hometown is well inside half that, so half is the line. False
-- while Config.World has no WildAreaDistance, so the town sounds as before until the cannon lands.
function Logic.inWild(x: number, z: number, wildDistance: any): boolean
	if type(wildDistance) ~= "number" or wildDistance <= 0 then
		return false
	end
	return math.sqrt(x * x + z * z) > wildDistance / 2
end

-- F84: the sound for a trip that worked (Travel). Home from a wild area is a cloud hop, known by where you are
-- before the move or by your fresh CloudHopAt after it; the Cannon button moves you at once to a cannon nearby, even
-- out in a wild area, so it poofs like any other trip (QA-Planner, A15).
function Logic.travelCue(destination: any, inWild: boolean, hopping: boolean): string
	if hopping or (inWild and destination ~= "cannon") then
		return "cloudHop"
	end
	return "travelPoof"
end

-- Whether a stray twinkles as a player comes near (rareNear): Mythical only. Derek 2026-10-28: the sound around
-- rare cats was annoying, so Epic, Legendary and gold strays are quiet now.
function Logic.shimmers(rarity: any): boolean
	local step = if type(rarity) == "string" then Logic.rarityStep(rarity) else nil
	return step ~= nil and step >= 5
end

-- The rare stray twinkle plays once as a player comes within `near` studs, and again only after they have been
-- further than `far` (so walking around the cat does not repeat it). Returns whether to play now and whether the
-- cat now counts as noticed.
function Logic.rareNotice(
	noticed: boolean,
	distance: number,
	near: number,
	far: number
): (boolean, boolean)
	if noticed then
		return false, distance <= far
	end
	return distance <= near, distance <= near
end

-- F99: a rainbow stray (its Variant "rainbow") twinkles with its own rainbowNear, a Mythical with rareNear, and
-- every other stray stays quiet.
function Logic.strayNoticeCue(rarity: any, variant: any): string?
	if variant == "rainbow" then
		return "rainbowNear"
	end
	return if Logic.shimmers(rarity) then "rareNear" else nil
end

-- F89 and F99: the sting on your own big pull (SecuredRare). A rainbow cat always gets its own; otherwise the
-- rarity's from Epic up (a gold Epic is the only Epic with a big pull). nil below Epic.
function Logic.pullSting(rarity: any, variant: any): string?
	if variant == "rainbow" then
		return "jingleRainbow"
	end
	local step = if type(rarity) == "string" then Logic.rarityStep(rarity) else nil
	if step == nil or step < 3 then
		return nil
	end
	return Logic.jingleFor(rarity)
end

local STING_RANK: { [string]: number } =
	{ jingleRare = 1, jingleEpic = 2, jingleLegendary = 3, jingleMythical = 4, jingleRainbow = 5 }

-- Two stings within `quiet` seconds (a tame's BaitTame and its SecuredRare land together): the same one or a
-- smaller one is skipped, a bigger one replaces the first (a rainbow's own sting over the rarity's).
function Logic.stingAction(
	lastCue: string?,
	lastAt: number?,
	cue: string,
	now: number,
	quiet: number
): "play" | "skip" | "replace"
	if lastCue == nil or lastAt == nil or now - lastAt >= quiet then
		return "play"
	end
	return if (STING_RANK[cue] or 0) > (STING_RANK[lastCue] or 0) then "replace" else "skip"
end

-- F100: a camp extra collected (CampExtraCollect's extraId). The Yard Sale is a purchase, so it has none.
local CAMP_EXTRA_CUES: { [string]: string } =
	{ picnic = "campBasket", pond = "campSplash", lostFound = "campRattle" }

function Logic.campExtraCue(extraId: any): string?
	return if type(extraId) == "string" then CAMP_EXTRA_CUES[extraId] else nil
end

-- F90 cats make the orders: the sound of a Barista starting on an order by station (only the espresso machine pours;
-- the oven and the counter work quietly under their puffs), and the scale step of the "ding!" when it is ready, so
-- the oven's is the lowest, a drink's a note up and the counter's two.
local ORDER_MAKE_CUES: { [string]: string } = { espresso = "orderPour" }
local ORDER_DING_STEPS: { [string]: number } = { oven = 1, espresso = 2, counter = 3 }

function Logic.orderMakeCue(station: any): string?
	return if type(station) == "string" then ORDER_MAKE_CUES[station] else nil
end

-- F84 cannon beats (#954, #955): when the flyer reaches the clouds and when the feet touch the pad, in seconds from
-- CannonLaunchAt. Config's CannonCloudsAt and CannonTouchdownAt when they are positive numbers; else the old clouds
-- time and the touchdown as the flight ends (CannonLaunchSeconds, else `flightFallback`). The touchdown never comes
-- before the clouds.
function Logic.cannonBeats(
	cloudsAt: any,
	touchdownAt: any,
	flight: any,
	cloudsFallback: number,
	flightFallback: number
): (number, number)
	local function positive(value: any): number?
		return if type(value) == "number" and value == value and value > 0 then value else nil
	end
	local clouds = positive(cloudsAt) or cloudsFallback
	local touchdown = positive(touchdownAt) or positive(flight) or flightFallback
	return clouds, math.max(touchdown, clouds)
end

-- Whether a plot is this player's own cafe, from its OwnerUserId attribute: only your own cafe's orders ding (#981).
-- A For Rent plot (0 or no owner) and anything but a number are nobody's.
function Logic.ownPlot(ownerUserId: any, yourUserId: number): boolean
	return type(ownerUserId) == "number" and ownerUserId ~= 0 and ownerUserId == yourUserId
end

function Logic.orderDingStep(station: any): number?
	return if type(station) == "string" then ORDER_DING_STEPS[station] else nil
end

-- F102: the trade countdown's tocks, one each whole second left (5, 4, 3, 2, 1 for a full TradeCountdownSeconds),
-- as delays from `now` in order; a state that arrives part way through gets only the seconds still ahead. At most
-- `maxTicks`, none once `endsAt` has passed or for a bad time.
function Logic.countdownTicks(now: number, endsAt: any, maxTicks: number): { number }
	local delays: { number } = {}
	if type(endsAt) ~= "number" or endsAt ~= endsAt or endsAt <= now then
		return delays
	end
	local count = math.min(math.ceil(endsAt - now - 1e-6), maxTicks)
	for left = count, 1, -1 do
		table.insert(delays, math.max(0, endsAt - left - now))
	end
	return delays
end

-- F101: the points a new RallyState's bar counts its steps from, so a step reached plays the cheer once: the last
-- state's points on the same lap, 0 on a newer lap, nil for the first state seen (joining mid-Rally is quiet) or
-- while no Rally runs.
function Logic.rallyFrom(before: { lap: number, points: number }?, lap: any, active: any): number?
	if before == nil or active ~= true or type(lap) ~= "number" then
		return nil
	end
	if lap == before.lap then
		return before.points
	end
	return if lap > before.lap then 0 else nil
end

-- The bait bowl (F28) between two ProfileSyncs: `before` and `after` are the syncs' `bait` (nil for an empty bowl)
-- and `catsBefore` and `catsAfter` how many cats each showed. "placed" when food went in, "arrive" when its cat came
-- (the sync names the cat only once it is at the bowl), "letgo" when a bowl with a cat emptied and no cat joined.
-- A tame adds its cat in the same sync and sounds with its check-in (CatCaught), so it is nil, like no change.
function Logic.baitChange(before: any, after: any, catsBefore: number, catsAfter: number): string?
	if type(after) == "table" then
		if type(before) ~= "table" or before.placedAt ~= after.placedAt then
			return "placed"
		end
		if before.cat == nil and type(after.cat) == "table" then
			return "arrive"
		end
		return nil
	end
	if type(before) == "table" and before.cat ~= nil and catsAfter <= catsBefore then
		return "letgo"
	end
	return nil
end

-- The arrival sound for a bait cat's coat: a gold one plays the gold reveal (F42), a rainbow one the rainbow shimmer
-- (F99) and any other the arrival mrrp.
function Logic.baitArriveCue(variant: any): string
	if variant == "gold" then
		return "goldReveal"
	elseif variant == "rainbow" then
		return "rainbowNear"
	end
	return "baitArrive"
end

-- Animation beats (Beats.hit) to sounds: the Bellhop Cat's bell (F96) and the camp extras' moving touches (F100).
local BEAT_CUES: { [string]: string } = {
	bellRing = "bellhopBell",
	fishJump = "campSplash",
	rodCast = "campSplash",
	basketOpen = "campBasket",
	lidRattle = "campRattle",
}

function Logic.beatCue(beat: any): string?
	return if type(beat) == "string" then BEAT_CUES[beat] else nil
end

-- How long a sound sheet's part lasts at a PlaybackSpeed (its region { start, stop } in seconds of the file), so
-- a play can be stopped at its end; nil for a cue without a valid region.
function Logic.regionSeconds(region: { number }?, speed: number): number?
	if region == nil or #region ~= 2 or region[2] <= region[1] then
		return nil
	end
	return (region[2] - region[1]) / math.max(speed, 0.01)
end

-- F89: each Legendary and Mythical decor piece's small sound (luck-and-rare-moments.md 2c), by its DecorId, and the
-- name of the moving part it comes from once Model-Agent's rework has one (nil plays it at the model).
local DECOR_SOUNDS: { [string]: { cue: string, part: string? } } = {
	park_blossom_tree = { cue = "decorBlossomTree", part = "CatCafe_Decor_BlossomTree_Chime_Swing" },
	sewer_bathtub_sofa = { cue = "decorBathtubSofa", part = "CatCafe_Decor_BathtubSofa_Duck_Bob" },
	woods_hollow_log_booth = {
		cue = "decorHollowLog",
		part = "CatCafe_Decor_HollowLogBooth_Lantern_Swing",
	},
	neighbourhood_ice_cream_counter = {
		cue = "decorIceCream",
		part = "CatCafe_Decor_IceCreamCounter_Sign_Spin",
	},
	park_duck_fountain = {
		cue = "decorDuckFountain",
		part = "CatCafe_Decor_DuckFountain_Ducklings_Spin",
	},
	alley_retro_jukebox = { cue = "decorJukebox", part = "CatCafe_Decor_RetroJukebox_Record_Spin" },
	classic_cat_tree_tower = {
		cue = "decorCatTree",
		part = "CatCafe_Decor_CatTreeTower_Toy1_Swing",
	},
}

function Logic.decorSound(decorId: any): (string?, string?)
	local entry = if type(decorId) == "string" then DECOR_SOUNDS[decorId] else nil
	if entry == nil then
		return nil, nil
	end
	return entry.cue, entry.part
end

-- F93 (catch-rework.md section 3): the result word a finished catch shows, from the server's grades: every circle
-- Perfect is PURRFECT, at least half Perfect EXCELLENT, any other success GREAT, and a miss "So close!".
function Logic.catchWord(grades: any, success: any): ("purrfect" | "excellent" | "great" | "close")?
	if success ~= true then
		return if success == false then "close" else nil
	end
	if type(grades) ~= "table" or #grades == 0 then
		return "great"
	end
	local perfect = 0
	for _, grade in grades do
		if grade == "perfect" then
			perfect += 1
		end
	end
	if perfect == #grades then
		return "purrfect"
	elseif perfect * 2 >= #grades then
		return "excellent"
	end
	return "great"
end

-- The word's own sound; PURRFECT already has purrfectChime (the Purrfect moment) and "So close!" catchMiss.
function Logic.wordCue(word: string?): string?
	if word == "excellent" then
		return "wordExcellent"
	elseif word == "great" then
		return "wordGreat"
	end
	return nil
end

return Logic
