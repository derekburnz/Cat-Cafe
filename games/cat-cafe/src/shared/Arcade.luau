--!strict
-- The Cat Arcade's Circle Streak (#3062; a player's idea, credited on the card by IDEA_BY, Derek2 2026-11-10). Pure: times are server time
-- (Workspace:GetServerTimeNow()) and rolls come from a passed function, so the specs are deterministic.
--
-- One run costs Config.ArcadeCostFish golden fish. It is the catch's closing circles with no stray: every circle hit
-- Perfect is +2 points and Good +1 (Derek2 17:48: "make a perfect +2 and normal circle 1 that way good players can
-- go through the game fast"), and the first Miss, or a circle left alone, ends the run. Reaching Config.ArcadeMaxPoints
-- (100) ends it as a win, clamped (a Perfect from 99 shows 100).
--   - Fair for everyone: every player uses the net level 1 windows of a Common (Circles.windowsFor(1, "Common")), so
--     a net bought with coins gives no edge.
--   - Harder every Config.ArcadeStepEvery (5 since #3359) points from a start twice a Common's pace: the shrink time x
--     ArcadeShrinkStep (0.96) per step (never under ArcadeShrinkFloorSeconds), the Perfect and Good windows x
--     ArcadeWindowStep (0.97), the gap between circles from CircleGapMax toward CircleGapMin and the shrink wobble
--     from CircleJitter up to ArcadeJitterMax. Steps stop at MAX_STEP (20), which is 100 points.
--   - The server builds the circles BLOCK at a time (block), each block at the step its first circle starts on, and
--     judges every press as a catch's (Circles.press). The client never reports a score.
--   - Milestones every 10 points (Config.ArcadeMilestones) pay once per UTC day each: crossing one pays it even when
--     a +2 skips its number (9 -> 11 pays the 10). After a day's are paid, runs still chase the records.
--   - Records rank by points, then fewest circles: score(points, circles) = points * 1000 + (999 - circles).
-- No Robux anywhere: no extra try, continue or skip (Monetization-Agent's conditions, #3062).
-- #3296 (Derek2 2026-11-11: "arcade game 1 free attempt daily"): the first run of each UTC day is free; later runs
-- cost ArcadeCostFish. `freeDay` is the UTC day the free run was last used.
--
-- The save (its own DataStore, not the profile, so it needed no save version step or restart):
--   Save = { best, bestCircles, day, paid, legend, runs, freeDay }  `paid` the milestone points paid on UTC `day`
-- An older server reading a save drops `freeDay` (sanitize keeps only what it knows), so for the few minutes old and
-- new servers overlap a player could get one more free run; nothing else is lost.

local Circles = require(script.Parent.Circles)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Arcade = {}

Arcade.FLAG = "arcade"
Arcade.BLOCK = 10 -- circles in each block the server builds
Arcade.PERFECT_POINTS = 2
Arcade.GOOD_POINTS = 1
Arcade.MAX_STEP = 20 -- #3359: was 10; with a step every 5 points it climbs all the way to 100
Arcade.LEGEND_TITLE = "Arcade Legend"
Arcade.IDEA_BY = "Idea by its_cuzu098"
Arcade.TAG = "ArcadeCabinet"
Arcade.PROMPT = "ArcadePrompt"
Arcade.ASSET = "CatCafe_Town_ArcadeCabinet"
Arcade.NAME = "Cat Arcade"
Arcade.ACTION = "Play"
Arcade.PROMPT_RANGE = 10
Arcade.DAY_SECONDS = 86400

-- Where circles may appear on screen, as fractions of its width and height (the Catch screen's area).
local SCREEN_MIN_X, SCREEN_MAX_X = 0.25, 0.75
local SCREEN_MIN_Y, SCREEN_MAX_Y = 0.3, 0.7

export type Milestone = { at: number, prize: Types.IndexPrize, name: string }

export type Save = {
	best: number, -- the most points in one run
	bestCircles: number, -- the circles that best took (fewest at that best), 0 with no run yet
	day: number, -- the UTC day number `paid` is for
	paid: { number }, -- milestone points paid on `day`
	legend: boolean, -- reached 100 once: the Arcade Legend title, kept for good
	runs: number,
	freeDay: number, -- #3296: the UTC day the free run was last used, 0 never
}

export type Result = {
	points: number,
	circles: number,
	win: boolean,
	best: number,
	bestCircles: number,
	newBest: boolean,
	serverBest: number,
	serverCircles: number,
	serverName: string?,
	paid: { number }, -- milestones paid in this run
	today: { number }, -- every milestone paid today, this run's included
	legend: boolean,
}

-- What the window shows before and after a game (ArcadeState): `loaded` false while the save is still being read.
export type State = {
	loaded: boolean,
	best: number,
	bestCircles: number,
	today: { number },
	legend: boolean,
	serverBest: number,
	serverCircles: number,
	serverName: string?,
	free: boolean?, -- #3296: today's free run is still there (nil from an older server: none)
	-- #3338 (Derek2: the leaderboard button): the arcade's top players across every server, best first, at most TOP
	top: { Row }?,
}

-- #3338: one line of the arcade's leaderboard (ArcadeState.top).
export type Row = { rank: number, name: string, points: number, circles: number, me: boolean? }

Arcade.TOP = 10 -- lines on the window's leaderboard
Arcade.BOARD_STORE = "CatCafe_LB_Arcade" -- the OrderedDataStore of each player's best score, keyed by user id

function Arcade.milestones(): { Milestone }
	return Config.ArcadeMilestones :: any
end

function Arcade.milestoneAt(at: number): Milestone?
	for _, m in Arcade.milestones() do
		if m.at == at then
			return m
		end
	end
	return nil
end

-- The difficulty step at `points`: one per ArcadeStepEvery, 0 to MAX_STEP.
function Arcade.step(points: number): number
	return math.clamp(math.floor(points / Config.ArcadeStepEvery), 0, Arcade.MAX_STEP)
end

local function along(step: number): number
	return math.clamp(step, 0, Arcade.MAX_STEP) / Arcade.MAX_STEP
end

-- The Perfect and Good windows at `step`: the net level 1 Common's, narrowed ArcadeWindowStep per step.
function Arcade.windows(step: number): Types.NetWindows
	local base = Circles.windowsFor(1, "Common")
	local scale = Config.ArcadeWindowStep ^ math.clamp(step, 0, Arcade.MAX_STEP)
	return { perfect = base.perfect * scale, good = base.good * scale }
end

-- A circle's shrink time at `step`, before its wobble: ArcadeStartShrinkSeconds (#3359: half a Common's), quicker by
-- ArcadeShrinkStep per step.
function Arcade.shrink(step: number): number
	return Config.ArcadeStartShrinkSeconds
		* Config.ArcadeShrinkStep ^ math.clamp(step, 0, Arcade.MAX_STEP)
end

function Arcade.gap(step: number): number
	return Config.CircleGapMax + (Config.CircleGapMin - Config.CircleGapMax) * along(step)
end

function Arcade.jitter(step: number): number
	return Config.CircleJitter + (Config.ArcadeJitterMax - Config.CircleJitter) * along(step)
end

-- BLOCK circles at `step`, the first starting to shrink at `startsAt`, each the step's gap after the last's target,
-- each away from the one before on screen. `roll` returns a number in [0, 1).
function Arcade.block(step: number, startsAt: number, roll: () -> number): { Types.CatchCircle }
	local shrink = Arcade.shrink(step)
	local jitter = Arcade.jitter(step)
	local gap = Arcade.gap(step)
	local circles: { Types.CatchCircle } = {}
	local at = startsAt
	for _ = 1, Arcade.BLOCK do
		local u = (roll() * 2 - 1) * jitter
		local circle: Types.CatchCircle = {
			startsAt = at,
			shrinkSeconds = math.max(shrink * (1 + u), Config.ArcadeShrinkFloorSeconds), -- #3359
			x = SCREEN_MIN_X + roll() * (SCREEN_MAX_X - SCREEN_MIN_X),
			y = SCREEN_MIN_Y + roll() * (SCREEN_MAX_Y - SCREEN_MIN_Y),
			kind = "single",
		}
		table.insert(circles, circle)
		at = Circles.target(circle) + gap
	end
	return circles
end

-- The points after a circle judged `grade`, clamped to ArcadeMaxPoints.
function Arcade.add(points: number, grade: Types.RingGrade): number
	local gain = if grade == "perfect"
		then Arcade.PERFECT_POINTS
		elseif grade == "good" then Arcade.GOOD_POINTS
		else 0
	return math.min(points + gain, Config.ArcadeMaxPoints)
end

-- The milestones whose points lie in (before, after], lowest first.
function Arcade.crossed(before: number, after: number): { number }
	local out: { number } = {}
	for _, m in Arcade.milestones() do
		if m.at > before and m.at <= after then
			table.insert(out, m.at)
		end
	end
	table.sort(out)
	return out
end

function Arcade.day(now: number): number
	return math.floor(now / Arcade.DAY_SECONDS)
end

function Arcade.fresh(): Save
	return { best = 0, bestCircles = 0, day = 0, paid = {}, legend = false, runs = 0, freeDay = 0 }
end

local function whole(value: unknown, low: number, high: number): number
	if type(value) ~= "number" or value ~= value then
		return low
	end
	return math.clamp(math.floor(value), low, high)
end

-- A save read back from the DataStore, anything odd dropped. A day other than today's starts with nothing paid.
function Arcade.sanitize(raw: unknown, now: number): Save
	local save = Arcade.fresh()
	if type(raw) ~= "table" then
		return save
	end
	local t = raw :: { [string]: unknown }
	save.best = whole(t.best, 0, Config.ArcadeMaxPoints)
	save.bestCircles = whole(t.bestCircles, 0, 999)
	save.runs = whole(t.runs, 0, 2 ^ 31)
	save.legend = t.legend == true
	save.freeDay = whole(t.freeDay, 0, 2 ^ 31)
	local today = Arcade.day(now)
	if whole(t.day, 0, 2 ^ 31) == today and type(t.paid) == "table" then
		save.day = today
		for _, at in t.paid :: { unknown } do
			if
				type(at) == "number"
				and Arcade.milestoneAt(at) ~= nil
				and not table.find(save.paid, at)
			then
				table.insert(save.paid, at)
			end
		end
		table.sort(save.paid)
	end
	return save
end

-- Two saves of one player joined, for a write that lands on top of another server's (UpdateAsync): today's paid
-- milestones from both, the better record (more points, then fewer circles), the most runs, and the title if either has
-- it. Both should come through `sanitize` first, so a `paid` is only ever today's.
function Arcade.merge(stored: Save, mine: Save): Save
	local out = Arcade.fresh()
	out.legend = stored.legend or mine.legend
	out.runs = math.max(stored.runs, mine.runs)
	out.freeDay = math.max(stored.freeDay, mine.freeDay) -- a free run used on either server stays used
	if
		mine.best > stored.best
		or (
			mine.best == stored.best
			and mine.bestCircles > 0
			and (stored.bestCircles == 0 or mine.bestCircles < stored.bestCircles)
		)
	then
		out.best, out.bestCircles = mine.best, mine.bestCircles
	else
		out.best, out.bestCircles = stored.best, stored.bestCircles
	end
	out.day = math.max(stored.day, mine.day)
	for _, save in { stored, mine } do
		if save.day == out.day then
			for _, at in save.paid do
				if not table.find(out.paid, at) then
					table.insert(out.paid, at)
				end
			end
		end
	end
	table.sort(out.paid)
	return out
end

-- The milestones paid today, after moving `save` to today (a new UTC day clears them).
function Arcade.today(save: Save, now: number): { number }
	local day = Arcade.day(now)
	if save.day ~= day then
		save.day = day
		save.paid = {}
	end
	return save.paid
end

-- Marks and returns the milestones a run moving from `before` to `after` points pays now: those crossed that are
-- not paid today yet.
function Arcade.claim(save: Save, before: number, after: number, now: number): { number }
	local paid = Arcade.today(save, now)
	local out: { number } = {}
	for _, at in Arcade.crossed(before, after) do
		if not table.find(paid, at) then
			table.insert(paid, at)
			table.insert(out, at)
		end
	end
	table.sort(paid)
	return out
end

-- #3296: whether today's free run is still there.
function Arcade.freeToday(save: Save, now: number): boolean
	return save.freeDay ~= Arcade.day(now)
end

-- #3296: uses today's free run; false when it was already used.
function Arcade.useFree(save: Save, now: number): boolean
	if not Arcade.freeToday(save, now) then
		return false
	end
	save.freeDay = Arcade.day(now)
	return true
end

-- The Play button's words: "Play (free)" while today's free run is there, else "Play (1 🐟)".
function Arcade.playText(free: boolean): string
	if free then
		return "Play (free)"
	end
	return string.format("Play (%d 🐟)", Config.ArcadeCostFish)
end

-- The leaderboard score: points first, then fewer circles.
function Arcade.score(points: number, circles: number): number
	return math.clamp(math.floor(points), 0, Config.ArcadeMaxPoints) * 1000
		+ (999 - math.clamp(circles, 0, 999))
end

-- The points and circles a leaderboard score holds (score's other way round); 0, 0 for anything not a score.
function Arcade.fromScore(value: unknown): (number, number)
	if type(value) ~= "number" or value ~= value or value <= 0 then
		return 0, 0
	end
	local whole = math.floor(value :: number)
	local points = math.clamp(whole // 1000, 0, Config.ArcadeMaxPoints)
	local circles = math.clamp(999 - whole % 1000, 0, 999)
	return points, circles
end

-- #3338: leaderboard rows (Leaderboards.rows or withPresent, values are scores) as the window's lines, at most TOP,
-- `me` marking the viewer's.
function Arcade.topRows(rows: { Types.LeaderboardRow }, viewer: number?): { Row }
	local out: { Row } = {}
	for _, row in rows do
		if #out >= Arcade.TOP then
			break
		end
		local points, circles = Arcade.fromScore(row.value)
		if points <= 0 then
			continue
		end
		table.insert(out, {
			rank = #out + 1,
			name = row.name,
			points = points,
			circles = circles,
			me = if viewer ~= nil and row.userId == viewer then true else nil,
		})
	end
	return out
end

-- Whether a run of `points` in `circles` beats a record of `best` in `bestCircles` (nothing beats an empty one with 0).
function Arcade.beats(points: number, circles: number, best: number, bestCircles: number): boolean
	if points <= 0 then
		return false
	end
	if best <= 0 then
		return true
	end
	return Arcade.score(points, circles) > Arcade.score(best, bestCircles)
end

-- Records the run in `save`; true when it is a new personal best. Reaching the top earns the title for good.
function Arcade.record(save: Save, points: number, circles: number): boolean
	save.runs += 1
	if points >= Config.ArcadeMaxPoints then
		save.legend = true
	end
	if Arcade.beats(points, circles, save.best, save.bestCircles) then
		save.best = points
		save.bestCircles = circles
		return true
	end
	return false
end

-- "37", or "100 in 58 circles" for a full run.
function Arcade.words(points: number, circles: number): string
	if points >= Config.ArcadeMaxPoints and circles > 0 then
		return string.format("%d in %d circles", points, circles)
	end
	return tostring(points)
end

-- The results card's line: "Score 37 · Best 52 · Server best 61 (Sam)".
function Arcade.cardLine(result: Result): string
	local line = "Score " .. Arcade.words(result.points, result.circles)
	line ..= " · Best " .. Arcade.words(result.best, result.bestCircles)
	if result.serverBest > 0 then
		line ..= " · Server best " .. Arcade.words(result.serverBest, result.serverCircles)
		if result.serverName ~= nil then
			line ..= " (" .. result.serverName .. ")"
		end
	end
	return line
end

-- Why `profile` can't start a run now, in words, or nil. `busy` names a catch, rescue or flight in progress. `free`
-- (#3296): today's free run is still there, so no fish are needed.
function Arcade.startBlocker(
	fish: number,
	busy: string?,
	running: boolean,
	loaded: boolean,
	free: boolean?
): string?
	if not loaded then
		return "The arcade is still waking up, try again in a moment"
	end
	if running then
		return "Finish this game first"
	end
	if busy ~= nil then
		return busy
	end
	if free ~= true and fish < Config.ArcadeCostFish then
		return string.format("You need %d golden fish 🐟 to play", Config.ArcadeCostFish)
	end
	return nil
end

return Arcade
