--!strict
-- The Rescue Rally on the UI (F101, rescue-rally.md sections 1 to 4), pure so the cloud spec runner checks it. The
-- server's RallyState comes through UI.rally.update; the steps are Catalog.rallySteps and the rules shared/Rally's.
--   view(state, now) -> View?        the banner and the Town Square board while a Rally runs, else nil: the lap
--                                    ("Lap 2" from the second), the fill (0 to 1), "45 / 90", the time left ("1d 4h
--                                    left"), each step's share, whether it is reached and its picture, and this
--                                    player's line ("You: 7 points", "Score 3 points to share the prizes", "1 more
--                                    point to share the prizes", "You've done your laps this weekend")
--   soon(state, now) -> string?      the line under the clock in the last SOON_SECONDS before a Rally starts:
--                                    "Rescue Rally in 5h 20m" (rescue-rally.md section 1, the Friday chip)
--   nightLine(state, now, night)     the Cat Cannon cards' tag while a Rally runs at night, when the stuck cats are
--                                    out: "Rally: rescues x3" (section 4), else nil
--   left(seconds) -> string          "1d 4h", "5h 20m", "12m", at least "1m"
--   stepPicture(prize)               a step's picture: its crate, else its potion, else the golden fish

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog")) :: any
local Config = require(Shared:WaitForChild("Config")) :: any
local Rally = require(Shared:WaitForChild("Rally")) :: any
local SharedTypes = require(Shared:WaitForChild("Types"))

export type Picture = { kind: "crate" | "potion" | "fish", id: string? }

export type Step = {
	share: number,
	reached: boolean,
	picture: Picture,
}

export type View = {
	lap: string?, -- "Lap 2" from the second lap
	fill: number,
	points: string,
	left: string,
	steps: { Step },
	mine: string,
	done: boolean, -- this player's laps are used up this weekend
}

local RallyLogic = {}

RallyLogic.TITLE = "Rescue Rally"
RallyLogic.ICON = "🏁"
RallyLogic.SOON_SECONDS = 12 * 3600

local MIN_POINTS: number = Config.RallyMinPoints or 3
local RESCUE_POINTS: number = (Config.RallyPoints or {}).rescue or 3
local CHECK_IN_POINTS: number = (Config.RallyPoints or {}).checkIn or 1

function RallyLogic.left(seconds: number): string
	local minutes = math.max(1, math.ceil(seconds / 60))
	if minutes >= 24 * 60 then
		local days, hours = math.floor(minutes / (24 * 60)), math.floor((minutes % (24 * 60)) / 60)
		return if hours > 0
			then string.format("%dd %dh", days, hours)
			else string.format("%dd", days)
	elseif minutes >= 60 then
		local hours, rest = math.floor(minutes / 60), minutes % 60
		return if rest > 0
			then string.format("%dh %dm", hours, rest)
			else string.format("%dh", hours)
	end
	return string.format("%dm", minutes)
end

function RallyLogic.stepPicture(prize: SharedTypes.IndexPrize?): Picture
	if prize ~= nil then
		local crates: { [string]: number } = prize.crates or {}
		for crateId in crates do
			return { kind = "crate", id = crateId }
		end
		local potions: { [string]: number } = prize.potions or {}
		for potionId in potions do
			return { kind = "potion", id = potionId }
		end
	end
	return { kind = "fish" }
end

local function running(state: SharedTypes.RallyState?, now: number): boolean
	return state ~= nil and state.active == true and (state.endsAt or 0) > now
end

local function mineLine(state: SharedTypes.RallyState): string
	if state.lapsDone then
		return "You've done your laps this weekend"
	end
	local mine = math.max(0, math.floor(state.myPoints or 0))
	if mine >= MIN_POINTS then
		return string.format("You: %d %s", mine, if mine == 1 then "point" else "points")
	elseif mine == 0 then
		return string.format("Score %d points to share the prizes", MIN_POINTS)
	end
	local more = MIN_POINTS - mine
	return string.format(
		"%d more %s to share the prizes",
		more,
		if more == 1 then "point" else "points"
	)
end

function RallyLogic.view(state: SharedTypes.RallyState?, now: number): View?
	if state == nil or not running(state, now) then
		return nil
	end
	local goal = math.max(1, math.floor(state.goal or 1))
	local points = math.clamp(math.floor(state.points or 0), 0, goal)
	local steps: { Step } = {}
	local defs: { SharedTypes.RallyStep } = Catalog.rallySteps or {}
	for index, step in defs do
		local at: number = Rally.stepAt(index, goal)
		table.insert(steps, {
			share = step.share,
			reached = points >= at,
			picture = RallyLogic.stepPicture(step.prize),
		})
	end
	local lap = math.max(1, math.floor(state.lap or 1))
	return {
		lap = if lap > 1 then string.format("Lap %d", lap) else nil,
		fill = points / goal,
		points = string.format("%d / %d", points, goal),
		left = RallyLogic.left(state.endsAt - now) .. " left",
		steps = steps,
		mine = mineLine(state),
		done = state.lapsDone == true,
	}
end

function RallyLogic.soon(state: SharedTypes.RallyState?, now: number): string?
	if state == nil or running(state, now) then
		return nil
	end
	local wait = (state.startsAt or 0) - now
	if wait <= 0 or wait > RallyLogic.SOON_SECONDS then
		return nil
	end
	return string.format("%s in %s", RallyLogic.TITLE, RallyLogic.left(wait))
end

function RallyLogic.nightLine(state: SharedTypes.RallyState?, now: number, night: boolean): string?
	if not night or not running(state, now) then
		return nil
	end
	return string.format(
		"Rally: rescues x%d",
		math.max(1, math.floor(RESCUE_POINTS / CHECK_IN_POINTS))
	)
end

return RallyLogic
