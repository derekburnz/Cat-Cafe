--!strict
-- The Rescue Rally weekend's rules (F101, rescue-rally.md), pure; RallyService runs the server's bar.
-- The Rally runs from Config.RallyStartWeekday 00:00 UTC for RallyHours each week (`isActive`), or at any time with
-- RallyForce. `weekend(now)` numbers the weeks from that start, so a save's laps start again at the next one. A lap's
-- `goal` is RallyPointsPerPlayer times the players, never fewer than RallyMinPlayers'; `stepsCrossed` names the steps
-- (Catalog.rallySteps) a score passed. `pays` decides whether a player gets a step's prize: they scored
-- RallyMinPoints this lap, and the lap is one they were already paid from or they have laps left this weekend.

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Rally = {}

local DAY = 86400
local WEEK = 7 * DAY
local EPOCH_WEEKDAY = 4 -- 1970-01-01 was a Thursday (0 is Sunday, as os.date's %w)

-- The kinds of play that score, as Config.RallyPoints names them.
Rally.KINDS = { "checkIn", "tame", "rescue", "teamRescue" }

-- The first Rally start, in seconds after the epoch: the first RallyStartWeekday at 00:00 UTC on or after it.
local function base(): number
	return ((Config.RallyStartWeekday - EPOCH_WEEKDAY) % 7) * DAY
end

-- The number of the Rally week `now` falls in: it turns over at each Rally start.
function Rally.weekend(now: number): number
	return (now - base()) // WEEK
end

-- When the Rally of `now`'s week starts (the latest start at or before `now`).
function Rally.weekStart(now: number): number
	return base() + Rally.weekend(now) * WEEK
end

-- Whether `now` is inside a Rally weekend.
function Rally.inWindow(now: number): boolean
	return now - Rally.weekStart(now) < Config.RallyHours * 3600
end

-- Whether a Rally runs at `now`: inside the weekend, or at any time when `force` is on.
function Rally.isActive(now: number, force: boolean): boolean
	return force or Rally.inWindow(now)
end

-- When the Rally running at `now` ends: the weekend's end, or for a forced one outside it the next weekend's start
-- (where the real one takes over). 0 when none runs.
function Rally.endsAt(now: number, force: boolean): number
	if Rally.inWindow(now) then
		return Rally.weekStart(now) + Config.RallyHours * 3600
	end
	return if force then Rally.weekStart(now) + WEEK else 0
end

-- When the next Rally starts: the running weekend's own start while inside one, else next week's.
function Rally.startsAt(now: number): number
	local start = Rally.weekStart(now)
	return if Rally.inWindow(now) then start else start + WEEK
end

-- A lap's goal with `players` in the server.
function Rally.goal(players: number): number
	return Config.RallyPointsPerPlayer * math.max(math.floor(players), Config.RallyMinPlayers)
end

-- The points `goal` must reach for step `index` (its share of the goal, rounded up).
function Rally.stepAt(index: number, goal: number): number
	local step = Catalog.rallySteps[index]
	return math.ceil(step.share * goal - 1e-9)
end

-- The steps (indexes into Catalog.rallySteps, in order) a bar going from `before` to `after` points of `goal` passed.
function Rally.stepsCrossed(before: number, after: number, goal: number): { number }
	local crossed: { number } = {}
	if goal <= 0 then
		return crossed
	end
	for index in Catalog.rallySteps do
		local at = Rally.stepAt(index, goal)
		if before < at and after >= at then
			table.insert(crossed, index)
		end
	end
	return crossed
end

-- The points one `kind` of play scores (Config.RallyPoints), 0 for anything else.
function Rally.pointsFor(kind: string): number
	local points = Config.RallyPoints[kind]
	return if type(points) == "number" and points > 0 then points else 0
end

function Rally.fresh(now: number): Types.RallySave
	return { weekend = Rally.weekend(now), laps = 0 }
end

-- A saved Rally record cleaned: whole numbers, the weekend never past `now`'s, laps 0 to RallyMaxLaps. Anything else
-- starts fresh.
function Rally.sanitize(raw: unknown, now: number): Types.RallySave
	local this = Rally.weekend(now)
	if type(raw) ~= "table" then
		return Rally.fresh(now)
	end
	local record = raw :: { [string]: unknown }
	local weekend, laps = record.weekend, record.laps
	if
		type(weekend) ~= "number"
		or type(laps) ~= "number"
		or weekend ~= weekend
		or laps ~= laps
		or weekend > this
		or weekend < 0
	then
		return Rally.fresh(now)
	end
	return {
		weekend = math.floor(weekend),
		laps = math.clamp(math.floor(laps), 0, Config.RallyMaxLaps),
	}
end

-- Starts the laps again when the save is from an earlier weekend.
function Rally.settle(save: Types.RallySave, now: number)
	local this = Rally.weekend(now)
	if save.weekend ~= this then
		save.weekend = this
		save.laps = 0
	end
end

-- Whether a player with `myPoints` this lap gets a step's prize, and marks the lap as paid when it is a new one for
-- them (`counted` false): they need RallyMinPoints, and a new lap needs laps left this weekend.
function Rally.pays(save: Types.RallySave, now: number, myPoints: number, counted: boolean): boolean
	if myPoints < Config.RallyMinPoints then
		return false
	end
	Rally.settle(save, now)
	if counted then
		return true
	end
	if save.laps >= Config.RallyMaxLaps then
		return false
	end
	save.laps += 1
	return true
end

-- Whether a player can earn nothing more this lap: their laps are used up and this lap is not one of them.
function Rally.lapsDone(save: Types.RallySave, now: number, counted: boolean): boolean
	Rally.settle(save, now)
	return not counted and save.laps >= Config.RallyMaxLaps
end

return Rally
