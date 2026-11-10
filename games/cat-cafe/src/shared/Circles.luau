--!strict
-- The net as closing circles (data-model section 10). Pure: times are numbers in server time
-- (Workspace:GetServerTimeNow()) and random rolls come from a passed function, so tests are deterministic.
--
-- A net swing that hits a stray builds a schedule (F93): circles[rarity] circles, each shrinking for
-- shrinkSeconds[rarity] x (1 + u) with u uniform in [-CircleJitter, +CircleJitter] on every net, separated by
-- CircleGapMin to CircleGapMax, so a better net widens the bands but never changes the rhythm. A circle's target is
-- startsAt + shrinkSeconds. The server stamps each CatchPress on arrival, takes off half the player's ping (capped
-- at CatchLatencyCapSeconds) and grades |press - target|: within perfect Perfect, within good Good, else Miss.
-- v0.13.15 (F83): a stray's perfect and good are its net's times its rarity's catchWindow (windowsFor).
-- v0.4: the first Miss (a press outside Good, or no press by a circle's deadline) ends the attempt, and an attempt
-- with every circle Good or Perfect is a sure catch. No roll.
-- #1884 (catch-rework.md 7b): a net catch keeps a trust bar instead. It starts at Config.TrustStart and each ring
-- adds TrustPerfect, TrustGood or TrustMiss: the cat is caught once trust reaches the rarity's trustNeed and bolts
-- below 0, or when the rings run out (the all-Good count plus CatchSpareRings, #2332). Rings come on a steady beat,
-- CircleGapMin apart. An attempt with no trust (a rescue's tree circle) keeps the v0.4 rule.

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Circles = {}

-- One player's catch in progress. scores[i] and grades[i] are nil until circle i is judged; errors[i] is the
-- server-stamped timing error in seconds, nil when the circle expired without a press.
export type Attempt = {
	circles: { Types.CatchCircle },
	windows: Types.NetWindows,
	scores: { number },
	grades: { Types.RingGrade },
	errors: { [number]: number },
	nextIndex: number, -- the next circle to judge; #circles + 1 after the last
	missed: boolean, -- over without a catch: a Miss under the v0.4 rule, or the cat bolted (#1884)
	-- #1884: the trust bar, nil for the v0.4 rule. caught once trust reached need
	trust: number?,
	need: number?,
	caught: boolean,
}

-- #1884: the trust bar an attempt starts with and the trust that catches the cat.
export type Trust = { start: number, need: number }

-- Where circles may appear on screen, as fractions of its width and height.
local SCREEN_MIN_X, SCREEN_MAX_X = 0.25, 0.75
local SCREEN_MIN_Y, SCREEN_MAX_Y = 0.3, 0.7

-- The scripted-press check (reviewer S23): the last AUTO_PRESS_WINDOW circles, flagged above AUTO_PRESS_RATE and
-- cleared at or below AUTO_PRESS_CLEAR_RATE (v0.4).
Circles.AUTO_PRESS_WINDOW = 50
Circles.AUTO_PRESS_RATE = Config.AutoPressFlagRate
Circles.AUTO_PRESS_CLEAR_RATE = Config.AutoPressClearRate

local function clampNetLevel(netLevel: number): number
	local highest = 0
	for level in Config.NetWindows do
		highest = math.max(highest, level)
	end
	return math.clamp(math.floor(netLevel), 0, highest)
end

function Circles.windows(netLevel: number): Types.NetWindows
	return Config.NetWindows[clampNetLevel(netLevel)]
end

-- The windows a cat of `rarity` is judged with (v0.13.15 F83): the net level's Perfect and Good times the rarity's
-- catchWindow, so the bands narrow the rarer the cat. #2322: times the catchWindowScale of `areaId` (the stray's
-- area) when it has one, so the first area is a little easier.
function Circles.windowsFor(
	netLevel: number,
	rarity: Types.Rarity,
	areaId: string?
): Types.NetWindows
	local net = Circles.windows(netLevel)
	local scale = Catalog.rarities[rarity].catchWindow
	local area = if areaId ~= nil then Catalog.getArea(areaId) else nil
	if area ~= nil and area.catchWindowScale ~= nil then
		scale *= area.catchWindowScale
	end
	return { perfect = net.perfect * scale, good = net.good * scale }
end

-- What CatchSchedule sends: the two half-widths the UI draws as bands.
function Circles.publicWindows(windows: Types.NetWindows): Types.CatchWindows
	return { perfect = windows.perfect, good = windows.good }
end

-- `roll` returns a number in [0, 1) each call (Random:NextNumber on the server). Since F93 the net level changes
-- only the bands (windowsFor), never the circles; it stays an argument for the callers.
-- #1884 (catch-rework.md 7c): with the rarity's twists, each ring after the first may be a double (two circles
-- DoubleRingGap apart on one spot, both kind "double", half 1 and 2, each using one of the ring cap's rings) and
-- each ring after the second a paw ring (never two in a row, using none of them). Rings come until the cap is used.
function Circles.schedule(
	rarity: Types.Rarity,
	_netLevel: number,
	now: number,
	roll: () -> number
): { Types.CatchCircle }
	local def = Catalog.rarities[rarity]
	local jitter = Config.CircleJitter
	local cap = Circles.ringCap(rarity)
	local circles: { Types.CatchCircle } = {}
	local used, ring = 0, 0
	local lastPaw = false :: boolean
	while used < cap do
		ring += 1
		local startsAt = now + Config.CircleLeadInSeconds
		local previous = circles[#circles]
		if previous ~= nil then
			-- #1884: a steady beat, one ring every shrink time plus CircleGapMin
			startsAt = previous.startsAt + previous.shrinkSeconds + Config.CircleGapMin
		end
		local u = (roll() * 2 - 1) * jitter
		local circle: Types.CatchCircle = {
			startsAt = startsAt,
			shrinkSeconds = def.shrinkSeconds * (1 + u),
			x = SCREEN_MIN_X + roll() * (SCREEN_MAX_X - SCREEN_MIN_X),
			y = SCREEN_MIN_Y + roll() * (SCREEN_MAX_Y - SCREEN_MIN_Y),
			kind = "single" :: Types.CircleKind,
		}
		local kind: Types.CircleKind = Circles.ringKind(rarity, ring, lastPaw, cap - used, roll)
		lastPaw = kind == "paw"
		circle.kind = kind
		table.insert(circles, circle)
		if kind == "double" then
			circle.half = 1
			local second: Types.CatchCircle = {
				startsAt = startsAt + Config.DoubleRingGap,
				shrinkSeconds = circle.shrinkSeconds,
				x = circle.x,
				y = circle.y,
				kind = "double" :: Types.CircleKind,
				half = 2,
			}
			table.insert(circles, second)
			used += 2
		elseif kind == "single" then
			used += 1
		end
	end
	return circles
end

-- #1884 (7c): what ring number `ring` of a try at `rarity` is, with `left` of the cap's rings unused and `lastPaw`
-- true when the ring before was a paw ring. Rolls only for the twists the ring may get.
function Circles.ringKind(
	rarity: Types.Rarity,
	ring: number,
	lastPaw: boolean,
	left: number,
	roll: () -> number
): Types.CircleKind
	local def = Catalog.rarities[rarity]
	if def.pawRings and ring > 2 and not lastPaw and roll() < Config.PawRingChance then
		return "paw"
	end
	if def.doubleRings and ring > 1 and left >= 2 and roll() < Config.DoubleRingChance then
		return "double"
	end
	return "single"
end

-- #1884: the most rings a try at `rarity` can use, plus CatchSpareRings. A double uses two and a paw ring none.
-- #2317 (Derek2: "it randomly says cat gets away ... even if you didnt fully miss any circles if you take a lot of
-- circles") and #2332 ("it should fully be only failing if the heart bar hits 0"): the base is the all-Good count
-- (enough Goods to fill the bar from TrustStart), not the all-Perfect one, and CatchSpareRings is 16, so a run with
-- no Miss always fills the bar and the rings run out only after eight Misses the bar lived through. It used to be
-- the all-Perfect count plus 2, which on Epic and up ran out before an all-Good run filled the bar.
function Circles.ringCap(rarity: Types.Rarity): number
	local def = Catalog.rarities[rarity]
	local allGood = math.ceil((def.trustNeed - Config.TrustStart) / Config.TrustGood)
	return math.max(def.circles, allGood) + Config.CatchSpareRings
end

-- #1884: the most circles any schedule holds (a paw ring between every two used rings, at most): bounds the
-- CatchPress index.
function Circles.maxCircles(): number
	local most = 1
	for _, rarity in Catalog.rarityOrder do
		most = math.max(most, 2 * Circles.ringCap(rarity :: Types.Rarity))
	end
	return most
end

-- #1884: the trust bar of a net catch at `rarity`, TrustStart plus `bonus`, and the tutorial stray's (one ring,
-- caught on a Good or Perfect as before).
function Circles.trustFor(rarity: Types.Rarity, bonus: number?): Trust
	return { start = Config.TrustStart + (bonus or 0), need = Catalog.rarities[rarity].trustNeed }
end

function Circles.tutorialTrust(): Trust
	return { start = Config.TrustStart, need = Config.TrustStart + Config.TrustGood }
end

-- F87 (easy-start.md section 2b): a beginner's own tutorial stray, a Common, is caught on one circle that shrinks
-- for TutorialShrinkSeconds with no jitter, judged with the Common's bands for `netLevel` made TutorialWindowScale
-- times as wide.
function Circles.tutorialWindows(netLevel: number): Types.NetWindows
	local common = Circles.windowsFor(netLevel, "Common")
	local scale = Config.TutorialWindowScale
	return { perfect = common.perfect * scale, good = common.good * scale }
end

-- `hold` (#2920): the ring stops on its target and waits for the press (a player's very first catch).
function Circles.tutorialSchedule(
	now: number,
	roll: () -> number,
	hold: boolean?
): { Types.CatchCircle }
	return {
		{
			startsAt = now + Config.CircleLeadInSeconds,
			shrinkSeconds = Config.TutorialShrinkSeconds,
			x = SCREEN_MIN_X + roll() * (SCREEN_MAX_X - SCREEN_MIN_X),
			y = SCREEN_MIN_Y + roll() * (SCREEN_MAX_Y - SCREEN_MIN_Y),
			kind = "single",
			hold = if hold == true then true else nil,
			holdSeconds = if hold == true then Config.FirstRingHoldSeconds else nil,
		},
	}
end

function Circles.target(circle: Types.CatchCircle): number
	return circle.startsAt + circle.shrinkSeconds
end

-- After this a circle with no press is a Miss. #2920: a held ring waits its holdSeconds past its target.
function Circles.deadline(circle: Types.CatchCircle, windows: Types.NetWindows): number
	local wait = if circle.hold == true
		then circle.holdSeconds or Config.FirstRingHoldSeconds
		else windows.good
	return Circles.target(circle) + wait + Config.CatchLatencyCapSeconds
end

-- When the whole attempt is over even if no press ever comes.
function Circles.endsAt(circles: { Types.CatchCircle }, windows: Types.NetWindows): number
	return Circles.deadline(circles[#circles], windows)
end

-- How long the stray stays locked: the last target plus the good window plus a second (data-model section 10).
function Circles.lockUntil(circles: { Types.CatchCircle }, windows: Types.NetWindows): number
	local last = circles[#circles]
	if last.hold == true then
		return Circles.deadline(last, windows) + 1 -- #2920: the whole hold
	end
	return Circles.target(last) + windows.good + 1
end

-- Seconds taken off a press for the trip from the client: half the round-trip ping, capped.
function Circles.latency(pingSeconds: number): number
	if type(pingSeconds) ~= "number" or pingSeconds ~= pingSeconds or pingSeconds < 0 then
		return 0
	end
	return math.min(pingSeconds / 2, Config.CatchLatencyCapSeconds)
end

function Circles.grade(errorSeconds: number, windows: Types.NetWindows): (Types.CircleGrade, number)
	local err = math.abs(errorSeconds)
	if err <= windows.perfect then
		return "perfect", Config.CircleScorePerfect
	elseif err <= windows.good then
		return "good", Config.CircleScoreGood
	end
	return "miss", 0
end

-- `trust` nil keeps the v0.4 rule (a rescue's tree circle); a net catch passes Circles.trustFor's.
function Circles.newAttempt(
	circles: { Types.CatchCircle },
	windows: Types.NetWindows,
	trust: Trust?
): Attempt
	return {
		circles = circles,
		windows = windows,
		scores = {},
		grades = {},
		errors = {},
		nextIndex = 1,
		missed = false,
		trust = if trust ~= nil then trust.start else nil,
		need = if trust ~= nil then trust.need else nil,
		caught = false,
	}
end

-- The trust a grade adds (#1884).
function Circles.trustDelta(grade: Types.RingGrade): number
	if grade == "perfect" then
		return Config.TrustPerfect
	elseif grade == "good" then
		return Config.TrustGood
	elseif grade == "left" then
		return Config.TrustPawLeft -- a paw ring left alone (7c)
	end
	return Config.TrustMiss
end

-- Records the grade of the circle just judged (nextIndex already moved past it) and ends the attempt when it
-- should: the v0.4 rule ends at a Miss, the trust bar when it fills, drops below 0 or runs out of rings.
local function settle(attempt: Attempt, grade: Types.RingGrade)
	local trust = attempt.trust
	if trust == nil then
		if grade == "miss" then
			attempt.missed = true
		end
		return
	end
	trust += Circles.trustDelta(grade)
	attempt.trust = trust
	if trust >= (attempt.need :: number) then
		attempt.caught = true
	elseif trust < 0 or attempt.nextIndex > #attempt.circles then
		attempt.missed = true -- bolted, or no rings left
	end
end

function Circles.isDone(attempt: Attempt): boolean
	return attempt.missed or attempt.caught or attempt.nextIndex > #attempt.circles
end

-- Caught: the trust bar filled (#1884), or under the v0.4 rule every circle judged Good or Perfect.
function Circles.succeeded(attempt: Attempt): boolean
	if attempt.trust ~= nil then
		return attempt.caught
	end
	return not attempt.missed and attempt.nextIndex > #attempt.circles
end

-- #1884 (catch-rework.md 7d): PURRFECT when every judged ring was Perfect (a paw ring left alone counts as one, a
-- tapped one is a Miss), GREAT with at most one that was not, NICE otherwise; "bolt" for an attempt that did not
-- catch.
function Circles.finish(attempt: Attempt): Types.CatchFinishKind
	if not Circles.succeeded(attempt) then
		return "bolt"
	end
	local off = 0
	for _, grade in attempt.grades do
		if grade ~= "perfect" and grade ~= "left" then
			off += 1
		end
	end
	return if off == 0 then "purrfect" elseif off == 1 then "great" else "nice"
end

-- The deadline of the circle waiting to be judged, or nil once the attempt is over.
function Circles.nextDeadline(attempt: Attempt): number?
	if Circles.isDone(attempt) then
		return nil
	end
	return Circles.deadline(attempt.circles[attempt.nextIndex], attempt.windows)
end

-- Judges the waiting circle as never pressed: a Miss, or "left" for a paw ring (+1 trust, #1884 7c).
local function unpressed(attempt: Attempt)
	local index = attempt.nextIndex
	local grade: Types.RingGrade = if attempt.circles[index].kind == "paw" then "left" else "miss"
	attempt.scores[index] = 0
	attempt.grades[index] = grade
	attempt.nextIndex += 1
	settle(attempt, grade)
end

-- Marks each waiting circle whose deadline has passed by `now` a Miss (a paw ring "left"), in order, until one has
-- not or the attempt is over (under the v0.4 rule the first Miss ends it). Returns how many circles expired.
function Circles.expire(attempt: Attempt, now: number): number
	local expired = 0
	while true do
		local deadline = Circles.nextDeadline(attempt)
		if deadline == nil or now <= deadline then
			return expired
		end
		unpressed(attempt)
		expired += 1
	end
end

-- Judges a press for circle `index`. `pressTime` is the latency-corrected press, `now` the arrival time. Returns
-- the grade, or nil when the press is ignored: the attempt is over, already judged (a repeat or out of order) or
-- earlier than the circle's start. #1884: a press for a later circle first judges the waiting ones before it as
-- never pressed once the press is past their Good band (a double's second half pressed before the first half's
-- deadline, which allows for ping), and is ignored while any of them could still be hit. A tapped paw ring is a
-- Miss (7c). #2920: a held ring ignores presses before its target and grades any later one Perfect.
function Circles.press(
	attempt: Attempt,
	index: number,
	pressTime: number,
	now: number
): Types.RingGrade?
	Circles.expire(attempt, now)
	if math.floor(index) ~= index or index < attempt.nextIndex or index > #attempt.circles then
		return nil -- not a whole number (NaN included), already judged or past the last circle
	end
	if Circles.isDone(attempt) then
		return nil
	end
	local circle = attempt.circles[index]
	if circle.hold == true then
		-- #2920: nothing counts before the ring stops on its target (a Good band early, for the clock between the
		-- client's freeze and the server); a press from then on is a Perfect
		if pressTime < Circles.target(circle) - attempt.windows.good then
			return nil
		end
		pressTime = Circles.target(circle)
	end
	if pressTime < circle.startsAt then
		return nil
	end
	for waiting = attempt.nextIndex, index - 1 do
		if pressTime <= Circles.target(attempt.circles[waiting]) + attempt.windows.good then
			return nil
		end
	end
	while attempt.nextIndex < index do
		unpressed(attempt)
		if Circles.isDone(attempt) then
			return nil
		end
	end
	local err = pressTime - Circles.target(circle)
	local grade: Types.RingGrade, score: number = Circles.grade(err, attempt.windows)
	if circle.kind == "paw" then
		grade, score = "miss", 0 -- don't tap it
	end
	attempt.scores[index] = score
	attempt.grades[index] = grade
	attempt.errors[index] = err
	attempt.nextIndex += 1
	settle(attempt, grade)
	return grade
end

-- #2913: how the attempt's first missed ring was missed, for catch_circles: "missed_early" or "missed_late" by the
-- press's timing error, "missed_none" when it ran out with no press; nil when no ring was missed. A tapped paw ring
-- (a Miss for pressing at all) reads by its timing like any other.
function Circles.firstMiss(attempt: Attempt): string?
	for index = 1, attempt.nextIndex - 1 do
		if attempt.grades[index] == "miss" then
			local err = attempt.errors[index]
			if err == nil then
				return "missed_none"
			end
			return if err < 0 then "missed_early" else "missed_late"
		end
	end
	return nil
end

-- v0.3's catch chance, the mean of the circle scores (all Perfect 1.0, all Good 0.5); 0 for no circles. v0.4
-- decides a catch by its grades (Circles.succeeded); this stays for the specs and analytics.
function Circles.chance(scores: { number }): number
	if #scores == 0 then
		return 0
	end
	local total = 0
	for _, score in scores do
		total += score
	end
	return total / #scores
end

function Circles.perfectCount(attempt: Attempt): number
	local n = 0
	for _, grade in attempt.grades do
		if grade == "perfect" then
			n += 1
		end
	end
	return n
end

-- Charm a successful catch adds (data-model section 10 step 5): PerfectCharmBonus per Perfect, times
-- PurrfectCharmMultiplier for a PURRFECT (every judged ring Perfect, #1884). 0 for a failed attempt; the caller caps
-- charm at 100 and gives nothing to a profile flagged autoPress.
function Circles.charmGain(attempt: Attempt): number
	if not Circles.succeeded(attempt) then
		return 0
	end
	local gain = Config.PerfectCharmBonus * Circles.perfectCount(attempt)
	if Circles.finish(attempt) == "purrfect" then
		gain *= Config.PurrfectCharmMultiplier
	end
	return gain
end

-- Adds one judged circle to a player's recent history (true for Perfect), keeping the last AUTO_PRESS_WINDOW.
function Circles.pushHistory(history: { boolean }, perfect: boolean)
	table.insert(history, perfect)
	while #history > Circles.AUTO_PRESS_WINDOW do
		table.remove(history, 1)
	end
end

-- True when a full window of circles is Perfect more than AUTO_PRESS_RATE of the time (reviewer S23). Network
-- jitter keeps honest players below that on the Basic and Sturdy nets.
function Circles.looksScripted(history: { boolean }): boolean
	if #history < Circles.AUTO_PRESS_WINDOW then
		return false
	end
	local perfect = 0
	for _, isPerfect in history do
		if isPerfect then
			perfect += 1
		end
	end
	return perfect / #history > Circles.AUTO_PRESS_RATE
end

-- True when a full window of circles is Perfect at most AUTO_PRESS_CLEAR_RATE of the time, which clears the flag.
-- The history lives in memory and the flag in the save, so a partial window after a rejoin never clears it
-- (reviewer N46).
function Circles.looksHonest(history: { boolean }): boolean
	if #history < Circles.AUTO_PRESS_WINDOW then
		return false
	end
	local perfect = 0
	for _, isPerfect in history do
		if isPerfect then
			perfect += 1
		end
	end
	return perfect / #history <= Circles.AUTO_PRESS_CLEAR_RATE
end

return Circles
