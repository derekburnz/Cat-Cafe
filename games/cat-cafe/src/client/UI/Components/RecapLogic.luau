--!strict
-- The session recap card (#1920, first-hour.md section 6): what its up to four lines say, each only when true, and
-- when it may show. Gameplay's SessionRecap sends the session's own numbers once, after RecapAfterSeconds of play;
-- the rest comes from what the client already holds. There is no countdown, no "don't leave" wording and no store
-- link: leaving loses nothing. Pure (no Theme, no Format: the money formatter is passed in), so the specs load it.
--   lines(input) -> { string }       1 "Today: 3 new cats, $12K earned"   2 what's next   3 a cooking bait cat
--                                    4 the offline share, then tomorrow's Daily Treat and quests
--                                    #2123 (first-hour.md 6a): with Gameplay's ReturnHook pick, 3 the offline share
--                                    alone and 4 one "Tomorrow" line (RecapLogic.tomorrow); the bait line goes
--   hook(raw) -> Hook?               ReturnHook.pick's table as sent, checked; nil for none or a bad one
--   treatWords(day) -> string?       #2123: the Daily Treat day's prize in words, its first two things after the
--                                    coins, best first ("2 Small Snacks", "15 Golden Fish and 1 spin"); nil for an unknown day
--   tomorrow(hook) -> string         "Your bait cat will be waiting for you", "Tomorrow: Daily Treat day 2, 2 Cat
--                                    Snacks" or "Tomorrow: new daily quests"
--   next(state, nextTier) -> string? "Grand Opening 6/8: Twelve different cats", else "Next: rank up to <tier>"
--   canShow(input) -> boolean        on, after the tutorial, not catching, carrying or in a menu, idle IDLE_SECONDS

local IndexRewards = require(script.Parent.IndexRewards)
local RoadmapLogic = require(script.Parent.RoadmapLogic)

local Catalog = require(
	game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Catalog")
) :: any

export type View = { minutes: number?, newCats: number?, earned: number?, tomorrow: any? }

-- #2123: Gameplay's ReturnHook.pick, the one best reason to come back (first-hour.md 6a). ProfileSync sends it as
-- state.returnHook (picked at join, for the welcome back card) and SessionRecap's view as `tomorrow` (the recap's
-- line); nil when there is none. The server sends no prize: the treat's words come from Catalog.dailyTreat here.
export type Hook = { kind: string, day: number?, prize: string? } -- kind "bait", "treat" or "quests"

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

local function offline(input: Input): string
	-- a no-break space, so "8 h" never splits over two rows
	return ("Your cafe earns while you're away: %d%% for up to %s\u{00A0}h"):format(
		math.floor(input.offlineRate * 100 + 0.5),
		hours(input.offlineCapSeconds)
	)
end

-- Before #2123's pick reaches the client: the offline share and tomorrow's Daily Treat and quests on one line.
local function away(input: Input): string
	local line = offline(input)
	local treat = input.state.dailyTreat
	local tomorrow = if type(treat) == "table"
			and treat.due ~= true
			and type(treat.nextDay) == "number"
		then ("Tomorrow: Daily Treat day %d and new quests"):format(treat.nextDay)
		else "Tomorrow: new quests"
	return line .. ". " .. tomorrow
end

local KINDS = { bait = true, treat = true, quests = true }
local PRIZE_MAX = 40 -- characters; a longer prize name is left off

function RecapLogic.hook(raw: any): Hook?
	if type(raw) ~= "table" or type(raw.kind) ~= "string" or not KINDS[raw.kind] then
		return nil
	end
	local day = raw.day
	local prize = raw.prize
	return {
		kind = raw.kind,
		day = if type(day) == "number"
				and day == day
				and day >= 1
				and day < 1e6
			then math.floor(day)
			else nil,
		prize = if type(prize) == "string"
				and #prize > 0
				and #prize <= PRIZE_MAX
			then prize
			else nil,
	}
end

local WORTH: { [string]: number } =
	{ crate = 1, lure = 2, potion = 3, catFood = 4, fish = 5, spins = 6 }

-- A prize part's name, "" when it has none to give.
local function partName(part: IndexRewards.PrizePart): string
	local id = part.id or ""
	local kind = part.kind
	local def: any = nil
	if kind == "fish" then
		return "Golden Fish"
	elseif kind == "spins" then
		return if part.amount == 1 then "spin" else "spins"
	elseif kind == "lure" then
		def = Catalog.getLure(id)
	elseif kind == "crate" then
		def = Catalog.getCrate(id)
	elseif kind == "potion" then
		def = Catalog.getPotion(id)
	elseif kind == "catFood" then
		def = Catalog.getCatFood(id)
	end
	local name: string = if def ~= nil and type(def.name) == "string" then def.name else ""
	local plural = #name > 0 and part.amount > 1 and string.sub(name, -1) ~= "s"
	return if plural then name .. "s" else name
end

function RecapLogic.treatWords(day: number?): string?
	local row = if day ~= nil then (Catalog.dailyTreat or {})[day] else nil
	if type(row) ~= "table" or type(row.prize) ~= "table" then
		return nil
	end
	-- the best two things first (a crate before bait, food and fish); the coins follow the day's earning rate, so they
	-- never make the line
	local parts: { IndexRewards.PrizePart } = {}
	for _, part in IndexRewards.prizeParts(row.prize, nil) do
		if WORTH[part.kind] ~= nil and partName(part) ~= "" then
			table.insert(parts, part)
		end
	end
	table.sort(parts, function(a, b)
		return WORTH[a.kind] < WORTH[b.kind]
	end)
	local words: { string } = {}
	for index = 1, math.min(2, #parts) do
		table.insert(words, ("%d %s"):format(parts[index].amount, partName(parts[index])))
	end
	return if #words > 0 then table.concat(words, " and ") else nil
end

function RecapLogic.tomorrow(hook: Hook): string
	if hook.kind == "bait" then
		return "Your bait cat will be waiting for you"
	elseif hook.kind == "treat" then
		local line = if hook.day
			then ("Tomorrow: Daily Treat day %d"):format(hook.day)
			else "Tomorrow: your Daily Treat"
		local prize = hook.prize or RecapLogic.treatWords(hook.day)
		return if prize then line .. ", " .. prize else line
	end
	return "Tomorrow: new daily quests"
end

function RecapLogic.lines(input: Input): { string }
	local out: { string } = {}
	local hook = RecapLogic.hook(input.view.tomorrow) or RecapLogic.hook(input.state.returnHook)
	local done = today(input.view, input.money)
	if done then
		table.insert(out, done)
	end
	local nextLine = RecapLogic.next(input.state, input.nextTier)
	if nextLine then
		table.insert(out, nextLine)
	end
	if hook then
		-- #2123: the offline share on its own line, then the one Tomorrow line (it names a bait cat that outlasts the
		-- session, so the cooking line goes)
		table.insert(out, offline(input))
		table.insert(out, RecapLogic.tomorrow(hook))
		return out
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
