--!strict
-- The Daily Treat card's rules (F70, data-model section 11e), shared so the window's stamps and the HUD button's dot
-- agree with what DailyTreatService pays. No Roblox services: times are os.time() readings (UTC seconds; the client
-- passes Workspace:GetServerTimeNow()).
-- Seven stamps, one per UTC day played (the day as for the free spin). A missed day loses nothing: the card waits
-- for the next stamp, and after day 7 the next stamp starts a fresh card at day 1. Nothing here is sold, sped up or
-- restored for Robux, and there is no streak to lose (monetization-policy).

local Catalog = require(script.Parent.Catalog)
local Spin = require(script.Parent.Spin)
local Types = require(script.Parent.Types)

local DailyTreat = {}

DailyTreat.DAYS = #Catalog.dailyTreat

-- Whether a stamp is due at `now`: the card's last claim was on an earlier UTC day.
function DailyTreat.due(state: Types.DailyTreatState, now: number): boolean
	return Spin.day(now) > state.lastDay
end

-- The day the next stamp pays: the one after the last, or day 1 on a full card.
function DailyTreat.nextDay(state: Types.DailyTreatState): number
	return if state.stamp >= DailyTreat.DAYS then 1 else state.stamp + 1
end

-- Day `day`'s prize (1 to DAYS).
function DailyTreat.prize(day: number): Types.IndexPrize
	return Catalog.dailyTreat[day].prize
end

-- Stamps the card at `now` and returns the day it pays, or nil when no stamp is due yet.
function DailyTreat.claim(state: Types.DailyTreatState, now: number): number?
	if not DailyTreat.due(state, now) then
		return nil
	end
	local day = DailyTreat.nextDay(state)
	state.stamp = day
	state.lastDay = Spin.day(now)
	return day
end

-- What ProfileSync sends: the card, whether a stamp is due at `now` and the day it pays.
function DailyTreat.view(state: Types.DailyTreatState, now: number): Types.DailyTreatView
	return {
		stamp = state.stamp,
		lastDay = state.lastDay,
		due = DailyTreat.due(state, now),
		nextDay = DailyTreat.nextDay(state),
	}
end

-- A save's card made valid: whole numbers, `stamp` from 0 to DAYS and `lastDay` from 0 to today (a day in the future
-- would hold back every stamp until then).
function DailyTreat.sanitize(raw: unknown, now: number): Types.DailyTreatState
	local state: Types.DailyTreatState = { stamp = 0, lastDay = 0 }
	if type(raw) == "table" then
		local stamp = (raw :: any).stamp
		local lastDay = (raw :: any).lastDay
		if type(stamp) == "number" and stamp == stamp then
			state.stamp = math.clamp(math.floor(stamp), 0, DailyTreat.DAYS)
		end
		if type(lastDay) == "number" and lastDay == lastDay then
			state.lastDay = math.clamp(math.floor(lastDay), 0, Spin.day(now))
		end
	end
	return state
end

return DailyTreat
