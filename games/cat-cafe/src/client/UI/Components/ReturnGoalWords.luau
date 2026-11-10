--!strict
-- #2916 (an open loop at exit, a goal on return): the words and bars for Gameplay's next goals (shared/ReturnGoals,
-- ReturnGoalView): the session recap's SessionRecapView.goals and the welcome back card's PlayerState.returnGoals.
-- The server picks them and logs return_goal_shown and return_goal_done, so the client only draws. Pure (the money
-- formatter is passed in), so the specs load it.
--   row(goal, money) -> Row?         a goal as the recap's row: its words, its count and its bar (0 to 1), or nil for
--                                    a kind this client doesn't know
--                                      cats    "Open the Park: 3 of 5 cats"           "3/5"
--                                      rarity  "Rank up: 1 of 2 Epic or better cats"  "1/2"
--                                      coins   "Rank up to Famous Cafe"               "$1.2K / $5K"
--                                      away    "About $4.5K while you're away (8 h)"  no bar
--   rows(goals, money, max) -> { Row }   the known ones in the server's order, at most `max`
--   welcomeLine(goals, money) -> string? the welcome back card's line from the first goal that isn't "away":
--                                    "Next: open the Park, 3 of 5 cats"; nil with none

local Catalog = require(
	game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Catalog")
) :: any

export type Row = {
	kind: string,
	text: string,
	count: string?,
	progress: number?, -- nil: no bar ("away")
}

local ReturnGoalWords = {}

ReturnGoalWords.MAX = 3
ReturnGoalWords.MAX_SHORT = 2 -- a phone held sideways (Scale.isShort): the recap stays small (Derek2: phone space)

local AREA_NAMES: { [string]: string } = {
	alley = "Alleyway",
	park = "Park",
	neighbourhood = "Neighbourhood",
	woods = "Woods",
	sewer = "Sewer",
	desert = "Desert",
	ruins = "Ruins",
}

local function numberOf(x: unknown): number?
	return if type(x) == "number" and x == x then x :: number else nil
end

local function tierName(tier: number?): string?
	if tier == nil then
		return nil
	end
	local tiers = Catalog.tiers
	if type(tiers) == "table" then
		for _, def in tiers do
			if def.tier == tier and type(def.name) == "string" then
				return def.name
			end
		end
	end
	return nil
end

local function share(have: number, need: number): number
	return if need > 0 then math.clamp(have / need, 0, 1) else 1
end

local function hours(h: number): string
	return if h == math.floor(h) then tostring(h) else ("%.1f"):format(h)
end

function ReturnGoalWords.row(goal: any, money: (number) -> string): Row?
	if type(goal) ~= "table" or type(goal.kind) ~= "string" then
		return nil
	end
	local have, need = numberOf(goal.have), numberOf(goal.need)
	if goal.kind == "cats" and have ~= nil and need ~= nil then
		local area = if type(goal.area) == "string" then AREA_NAMES[goal.area] or goal.area else nil
		local lead = if area ~= nil then "Open the " .. area else "Rank up"
		return {
			kind = "cats",
			text = ("%s: %d of %d cats"):format(lead, have, need),
			count = ("%d/%d"):format(have, need),
			progress = share(have, need),
		}
	elseif goal.kind == "rarity" and type(goal.rarity) == "string" then
		if have == nil or need == nil then
			return nil
		end
		local rarity: string = goal.rarity
		return {
			kind = "rarity",
			text = ("Rank up: %d of %d %s or better cats"):format(have, need, rarity),
			count = ("%d/%d"):format(have, need),
			progress = share(have, need),
		}
	elseif goal.kind == "coins" and have ~= nil and need ~= nil then
		local name = tierName(numberOf(goal.tier))
		return {
			kind = "coins",
			text = if name ~= nil then "Rank up to " .. name else "Save up to rank up",
			count = ("%s / %s"):format(money(math.min(have, need)), money(need)),
			progress = share(have, need),
		}
	elseif goal.kind == "away" then
		local amount = numberOf(goal.amount)
		if amount == nil or amount <= 0 then
			return nil
		end
		local h = numberOf(goal.hours)
		return {
			kind = "away",
			text = if h ~= nil
				then ("About %s while you're away (%s\u{00A0}h)"):format(money(amount), hours(h))
				else ("About %s while you're away"):format(money(amount)),
			count = nil,
			progress = nil,
		}
	end
	return nil
end

function ReturnGoalWords.rows(goals: any, money: (number) -> string, max: number?): { Row }
	local out: { Row } = {}
	if type(goals) ~= "table" then
		return out
	end
	for _, goal in goals do
		local row = ReturnGoalWords.row(goal, money)
		if row ~= nil and #out < (max or ReturnGoalWords.MAX) then
			table.insert(out, row)
		end
	end
	return out
end

function ReturnGoalWords.welcomeLine(goals: any, money: (number) -> string): string?
	for _, row in ReturnGoalWords.rows(goals, money, math.huge) do
		if row.kind ~= "away" then
			local words = string.gsub(row.text, ": ", ", ", 1)
			return "Next: " .. string.lower(string.sub(words, 1, 1)) .. string.sub(words, 2)
		end
	end
	return nil
end

return ReturnGoalWords
