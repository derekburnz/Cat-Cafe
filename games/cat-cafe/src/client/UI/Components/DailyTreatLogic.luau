--!strict
-- The Daily Treat card as the window and the HUD's Daily tile show it (F70, data-model section 11e): seven stamps,
-- one per UTC day played, never reset; after day 7 the next stamp starts a fresh card.
--   view(raw) -> DailyTreatView?          ProfileSync's dailyTreat made safe: whole numbers, stamp 0 to DAYS
--   due(view, now) -> boolean             a stamp can be claimed: the server said so, or a UTC day has turned since
--                                         the last claim (the game stays open past midnight)
--   cells(view, days, now) -> { Cell }    one per day: "stamped", "ready" (due now), "next" (tomorrow) or "later"; a
--                                         full card stays all stamped until the next stamp is due, then reads fresh
--   untilTomorrow(now) -> seconds         to the next UTC midnight, when the next stamp comes due
--   waitText(seconds) -> string           "5 h 12 min", "42 min"
--   claimedDay(before, after) -> number?  the day a sync just stamped (lastDay moved on), for the stamp sound
--   stampSound(day) -> string             uiDailyStamp for days 1 to 6, jingleDailyCard for the day that fills the card
--   autoOpen(view, now, tutorialStep)     the window may open by itself: a stamp is due and the tutorial is over
-- Pure: no Theme, Format or CFrame, so the cloud test runner checks it. `now` is Workspace:GetServerTimeNow().

local Types = require(script.Parent.Parent.Types)

export type CellState = "stamped" | "ready" | "next" | "later"
export type Cell = { day: number, prize: Types.IndexPrize?, state: CellState }

local DAY = 86400
local TUTORIAL_DONE = 5 -- the tutorial's last step, as the HUD's quest line waits for

local DailyTreatLogic = {}

DailyTreatLogic.DAYS = 7

local function whole(value: any, low: number, high: number): number
	if type(value) ~= "number" or value ~= value then
		return low
	end
	return math.clamp(math.floor(value), low, high)
end

function DailyTreatLogic.view(raw: any): Types.DailyTreatView?
	if type(raw) ~= "table" then
		return nil
	end
	local stamp = whole(raw.stamp, 0, DailyTreatLogic.DAYS)
	return {
		stamp = stamp,
		lastDay = whole(raw.lastDay, 0, math.huge),
		due = raw.due == true,
		nextDay = if stamp >= DailyTreatLogic.DAYS then 1 else stamp + 1,
	}
end

function DailyTreatLogic.due(view: Types.DailyTreatView?, now: number): boolean
	if view == nil then
		return false
	end
	return view.due or math.floor(now / DAY) > view.lastDay
end

function DailyTreatLogic.cells(
	view: Types.DailyTreatView?,
	days: { Types.DailyTreatDay }?,
	now: number
): { Cell }
	local prizes: { [number]: Types.IndexPrize } = {}
	local list: { Types.DailyTreatDay } = days or {}
	for _, row in list do
		if type(row) == "table" and type(row.day) == "number" and type(row.prize) == "table" then
			prizes[row.day] = row.prize
		end
	end
	local count = DailyTreatLogic.DAYS
	local due = DailyTreatLogic.due(view, now)
	local stamp = if view then view.stamp else 0
	if stamp >= count and due then
		stamp = 0 -- the next stamp starts a fresh card
	end
	local cells: { Cell } = {}
	for day = 1, count do
		local state: CellState = if day <= stamp
			then "stamped"
			elseif day == stamp + 1 then (if due then "ready" else "next")
			else "later"
		table.insert(cells, { day = day, prize = prizes[day], state = state })
	end
	return cells
end

function DailyTreatLogic.untilTomorrow(now: number): number
	return DAY - now % DAY
end

function DailyTreatLogic.waitText(seconds: number): string
	local left = if type(seconds) == "number" and seconds == seconds
		then math.max(0, seconds)
		else 0
	local minutes = math.max(1, math.ceil(left / 60))
	if minutes >= 60 then
		return ("%d h %d min"):format(minutes // 60, minutes % 60)
	end
	return ("%d min"):format(minutes)
end

function DailyTreatLogic.claimedDay(
	before: Types.DailyTreatView?,
	after: Types.DailyTreatView?
): number?
	if before == nil or after == nil or after.lastDay <= before.lastDay or after.stamp < 1 then
		return nil
	end
	return after.stamp
end

function DailyTreatLogic.stampSound(day: number): string
	return if day >= DailyTreatLogic.DAYS then "jingleDailyCard" else "uiDailyStamp"
end

function DailyTreatLogic.autoOpen(
	view: Types.DailyTreatView?,
	now: number,
	tutorialStep: number?
): boolean
	return DailyTreatLogic.due(view, now) and (tutorialStep or TUTORIAL_DONE) >= TUTORIAL_DONE
end

return DailyTreatLogic
