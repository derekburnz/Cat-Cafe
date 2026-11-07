--!strict
-- The session recap card (#1920, first-hour.md section 6): what its up to four lines say, each only when true, and
-- when it may show. Gameplay's SessionRecap sends the session's own numbers once, after RecapAfterSeconds of play;
-- the rest comes from what the client already holds. There is no countdown, no "don't leave" wording and no store
-- link: leaving loses nothing. Pure (no Theme, no Format: the money formatter is passed in), so the specs load it.
--   lines(input) -> { string }       1 "Today: 3 new cats, $12K earned"   2 what's next   3 a cooking bait cat
--                                    4 the offline share, then tomorrow's Daily Treat and quests
--   next(state, nextTier) -> string? "Grand Opening 6/8: Twelve different cats", else "Next: rank up to <tier>"
--   canShow(input) -> boolean        on, after the tutorial, not catching, carrying or in a menu, idle IDLE_SECONDS

local RoadmapLogic = require(script.Parent.RoadmapLogic)

export type View = { minutes: number?, newCats: number?, earned: number? }

export type Input = {
	view: View,
	state: { [string]: any },
	nextTier: string?, -- the next tier's name, nil at the top tier
	baitReadyAt: { number }, -- each cooking bowl's readyAt in server time
	now: number, -- server time
	offlineRate: number, -- 0.5, or the Long Nap pass's 1
	offlineCapSeconds: number,
	money: (number) -> string,
}

export type Gate = {
	enabled: boolean, -- the sessionRecap setting (nil reads as on)
	tutorialStep: number?,
	catching: boolean,
	carrying: boolean,
	menuOpen: boolean,
	idleSeconds: number,
}

local RecapLogic = {}

RecapLogic.AUTO_HIDE = 12 -- seconds
RecapLogic.IDLE_SECONDS = 5
RecapLogic.SETTING = "sessionRecap"
RecapLogic.TITLE = "Your cafe so far"
RecapLogic.MAX_LINES = 4

local function count(raw: any): number
	return if type(raw) == "number" and raw == raw and raw > 0 then math.floor(raw) else 0
end

local function today(view: View, money: (number) -> string): string?
	local cats = count(view.newCats)
	local earned = count(view.earned)
	local parts: { string } = {}
	if cats > 0 then
		table.insert(parts, if cats == 1 then "1 new cat" else ("%d new cats"):format(cats))
	end
	if earned > 0 then
		table.insert(parts, money(earned) .. " earned")
	end
	if #parts == 0 then
		return nil
	end
	return "Today: " .. table.concat(parts, ", ")
end

function RecapLogic.next(state: { [string]: any }, nextTier: string?): string?
	local view = RoadmapLogic.view(state)
	if view then
		for _, row in view.rows do
			if row.next then
				return ("%s: %s"):format(view.title, row.text)
			end
		end
	end
	if nextTier then
		return "Next: rank up to " .. nextTier
	end
	return nil
end

local function bait(readyAt: { number }, now: number): string?
	local soonest: number? = nil
	for _, at in readyAt do
		if at > now and (soonest == nil or at < soonest) then
			soonest = at
		end
	end
	if soonest == nil then
		return nil
	end
	local minutes = math.max(1, math.ceil((soonest - now) / 60))
	return ("Your bait cat arrives in %d min. It waits for you"):format(minutes)
end

local function hours(seconds: number): string
	local h = seconds / 3600
	return if h == math.floor(h) then tostring(h) else ("%.1f"):format(h)
end

local function away(input: Input): string
	local line = ("Your cafe earns while you're away: %d%% for up to %s h"):format(
		math.floor(input.offlineRate * 100 + 0.5),
		hours(input.offlineCapSeconds)
	)
	local treat = input.state.dailyTreat
	local tomorrow = if type(treat) == "table"
			and treat.due ~= true
			and type(treat.nextDay) == "number"
		then ("Tomorrow: Daily Treat day %d and new quests"):format(treat.nextDay)
		else "Tomorrow: new quests"
	return line .. ". " .. tomorrow
end

function RecapLogic.lines(input: Input): { string }
	local out: { string } = {}
	local done = today(input.view, input.money)
	if done then
		table.insert(out, done)
	end
	local nextLine = RecapLogic.next(input.state, input.nextTier)
	if nextLine then
		table.insert(out, nextLine)
	end
	local cooking = bait(input.baitReadyAt, input.now)
	if cooking then
		table.insert(out, cooking)
	end
	table.insert(out, away(input))
	return out
end

function RecapLogic.canShow(gate: Gate): boolean
	return gate.enabled
		and (gate.tutorialStep or 0) >= RoadmapLogic.TUTORIAL_DONE
		and not gate.catching
		and not gate.carrying
		and not gate.menuOpen
		and gate.idleSeconds >= RecapLogic.IDLE_SECONDS
end

return RecapLogic
