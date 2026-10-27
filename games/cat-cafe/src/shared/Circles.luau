--!strict
-- The net as closing circles (data-model section 10). Pure: times are numbers in server time
-- (Workspace:GetServerTimeNow()) and random rolls come from a passed function, so tests are deterministic.
--
-- GrabBegin builds a schedule: circles[rarity] circles, each shrinking for shrinkSeconds[rarity] x (1 + u) with u
-- uniform in [-jitter, +jitter] for the net level, separated by CircleGapMin to CircleGapMax. A circle's target is
-- startsAt + shrinkSeconds. The server stamps each CatchPress on arrival, takes off half the player's ping (capped
-- at CatchLatencyCapSeconds) and grades |press - target|: within perfect Perfect, within good Good, else Miss.
-- v0.4: the first Miss (a press outside Good, or no press by a circle's deadline) ends the attempt, and an attempt
-- with every circle Good or Perfect is a sure catch. No roll.

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
	grades: { Types.CircleGrade },
	errors: { [number]: number },
	nextIndex: number, -- the next circle to judge; #circles + 1 after the last
	missed: boolean, -- a circle was a Miss, which ends the attempt
}

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

-- What CatchSchedule sends: the two half-widths the UI draws as bands.
function Circles.publicWindows(windows: Types.NetWindows): Types.CatchWindows
	return { perfect = windows.perfect, good = windows.good }
end

-- `roll` returns a number in [0, 1) each call (Random:NextNumber on the server).
function Circles.schedule(
	rarity: Types.Rarity,
	netLevel: number,
	now: number,
	roll: () -> number
): { Types.CatchCircle }
	local def = Catalog.rarities[rarity]
	local jitter = Circles.windows(netLevel).jitter
	local circles: { Types.CatchCircle } = {}
	local startsAt = now + Config.CircleLeadInSeconds
	for i = 1, def.circles do
		if i > 1 then
			local previous = circles[i - 1]
			local gap = Config.CircleGapMin + roll() * (Config.CircleGapMax - Config.CircleGapMin)
			startsAt = previous.startsAt + previous.shrinkSeconds + gap
		end
		local u = (roll() * 2 - 1) * jitter
		table.insert(circles, {
			startsAt = startsAt,
			shrinkSeconds = def.shrinkSeconds * (1 + u),
			x = SCREEN_MIN_X + roll() * (SCREEN_MAX_X - SCREEN_MIN_X),
			y = SCREEN_MIN_Y + roll() * (SCREEN_MAX_Y - SCREEN_MIN_Y),
		})
	end
	return circles
end

function Circles.target(circle: Types.CatchCircle): number
	return circle.startsAt + circle.shrinkSeconds
end

-- After this a circle with no press is a Miss.
function Circles.deadline(circle: Types.CatchCircle, windows: Types.NetWindows): number
	return Circles.target(circle) + windows.good + Config.CatchLatencyCapSeconds
end

-- When the whole attempt is over even if no press ever comes.
function Circles.endsAt(circles: { Types.CatchCircle }, windows: Types.NetWindows): number
	return Circles.deadline(circles[#circles], windows)
end

-- How long the stray stays locked: the last target plus the good window plus a second (data-model section 10).
function Circles.lockUntil(circles: { Types.CatchCircle }, windows: Types.NetWindows): number
	return Circles.target(circles[#circles]) + windows.good + 1
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

function Circles.newAttempt(circles: { Types.CatchCircle }, windows: Types.NetWindows): Attempt
	return {
		circles = circles,
		windows = windows,
		scores = {},
		grades = {},
		errors = {},
		nextIndex = 1,
		missed = false,
	}
end

function Circles.isDone(attempt: Attempt): boolean
	return attempt.missed or attempt.nextIndex > #attempt.circles
end

-- Every circle judged Good or Perfect: a sure catch (v0.4).
function Circles.succeeded(attempt: Attempt): boolean
	return not attempt.missed and attempt.nextIndex > #attempt.circles
end

-- The deadline of the circle waiting to be judged, or nil once the attempt is over.
function Circles.nextDeadline(attempt: Attempt): number?
	if Circles.isDone(attempt) then
		return nil
	end
	return Circles.deadline(attempt.circles[attempt.nextIndex], attempt.windows)
end

-- Marks the waiting circle a Miss once its deadline has passed by `now`, which ends the attempt. Returns how many
-- circles expired: 0 or 1, since nothing after a Miss is judged.
function Circles.expire(attempt: Attempt, now: number): number
	local deadline = Circles.nextDeadline(attempt)
	if deadline == nil or now <= deadline then
		return 0
	end
	attempt.scores[attempt.nextIndex] = 0
	attempt.grades[attempt.nextIndex] = "miss"
	attempt.nextIndex += 1
	attempt.missed = true
	return 1
end

-- Judges a press for circle `index`. `pressTime` is the latency-corrected press, `now` the arrival time. Returns
-- the grade, or nil when the press is ignored: the attempt is over, not the next circle (out of order, a repeat,
-- or already judged) or earlier than the circle's start.
function Circles.press(
	attempt: Attempt,
	index: number,
	pressTime: number,
	now: number
): Types.CircleGrade?
	Circles.expire(attempt, now)
	if Circles.isDone(attempt) or index ~= attempt.nextIndex then
		return nil
	end
	local circle = attempt.circles[index]
	if pressTime < circle.startsAt then
		return nil
	end
	local err = pressTime - Circles.target(circle)
	local grade: Types.CircleGrade, score: number = Circles.grade(err, attempt.windows)
	attempt.scores[index] = score
	attempt.grades[index] = grade
	attempt.errors[index] = err
	attempt.nextIndex += 1
	if grade == "miss" then
		attempt.missed = true
	end
	return grade
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
-- PurrfectCharmMultiplier when every circle is Perfect. 0 for a failed attempt; the caller caps charm at 100 and
-- gives nothing to a profile flagged autoPress.
function Circles.charmGain(attempt: Attempt): number
	if not Circles.succeeded(attempt) then
		return 0
	end
	local perfect = Circles.perfectCount(attempt)
	local gain = Config.PerfectCharmBonus * perfect
	if perfect == #attempt.circles then
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
