--!strict
-- The Tip Jar's sums (F47, data-model section 11b): which of the twelve playtime gifts are claimed, ready or
-- still counting down, and what a coin gift is worth. Pure: no Theme, so the cloud spec runner can load it.
--
-- The server sends TipJarState { sessionStartedAt, claimed } (server time, GetServerTimeNow) when the profile
-- loads and after each claim; the UI counts down from it with Catalog.tipJar. A coin gift pays
-- max(minCoins, floor(dayRate * seconds)) at claim time, so the card shows an estimate from the synced rate.

export type Row = {
	step: number,
	minutes: number,
	kind: string, -- "coins" or "lure"
	seconds: number?, -- coins: seconds of day rate
	minCoins: number?,
	lureId: string?, -- lure: the food and how many
	count: number?,
	spins: number?, -- F49: Spin Wheel spins it also banks (steps 11 and 12)
	fish: number?, -- F52: golden fish it also gives (step 12)
}

export type Jar = {
	sessionStartedAt: number,
	claimed: { [any]: boolean }?, -- 12 booleans by step; a sparse map's keys may arrive as strings
}

export type StepState = "claimed" | "ready" | "waiting"

export type StepView = {
	row: Row,
	state: StepState,
	remaining: number, -- seconds until it unlocks, 0 once ready or claimed
}

export type Summary = {
	ready: number, -- gifts waiting for a Claim press
	nextIn: number?, -- seconds until the next gift unlocks, nil when none is left to wait for
	left: number, -- gifts not claimed yet
}

local TipJarLogic = {}

-- The day rate behind a coin gift: the synced income drops to the night share after dark (data-model 11).
function TipJarLogic.dayRate(incomePerSecond: number, night: boolean, nightShare: number): number
	if night and nightShare > 0 then
		return incomePerSecond / nightShare
	end
	return incomePerSecond
end

function TipJarLogic.coins(row: Row, dayRate: number): number
	return math.max(row.minCoins or 0, math.floor(math.max(0, dayRate) * (row.seconds or 0)))
end

-- A sparse { [step] = true } crosses a RemoteEvent with string keys, so look under both.
function TipJarLogic.isClaimed(jar: Jar?, step: number): boolean
	local claimed = if jar then jar.claimed else nil
	if claimed == nil then
		return false
	end
	return claimed[step] == true or claimed[tostring(step)] == true
end

-- One view per row in step order. Without a jar (no TipJarState yet) every gift is waiting from now.
function TipJarLogic.views(rows: { Row }, jar: Jar?, now: number): { StepView }
	local elapsed = if jar then now - jar.sessionStartedAt else 0
	local views: { StepView } = {}
	for _, row in rows do
		local remaining = math.max(0, row.minutes * 60 - elapsed)
		local state: StepState = if TipJarLogic.isClaimed(jar, row.step)
			then "claimed"
			elseif jar and remaining <= 0 then "ready"
			else "waiting"
		table.insert(views, {
			row = row,
			state = state,
			remaining = if state == "waiting" then remaining else 0,
		})
	end
	table.sort(views, function(a: StepView, b: StepView): boolean
		return a.row.step < b.row.step
	end)
	return views
end

function TipJarLogic.summary(views: { StepView }): Summary
	local ready, left = 0, 0
	local nextIn: number? = nil
	for _, view in views do
		if view.state ~= "claimed" then
			left += 1
		end
		if view.state == "ready" then
			ready += 1
		elseif view.state == "waiting" then
			local soonest: number? = nextIn
			if soonest == nil or view.remaining < soonest then
				nextIn = view.remaining
			end
		end
	end
	return { ready = ready, nextIn = nextIn, left = left }
end

-- "4:05" under an hour, "1:02:05" past it.
function TipJarLogic.clock(seconds: number): string
	local total = math.max(0, math.ceil(seconds))
	local hours = total // 3600
	local minutes = (total % 3600) // 60
	local secs = total % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%d:%02d", minutes, secs)
end

return TipJarLogic
