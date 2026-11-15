--!strict
-- The Auto Bowl pass (#4266, Derek 2026-11-14: "add an option to turn on auto claim and auto refill for bait bowl for
-- a game pass"). A game pass, not a random item: it only does the taps an owner can already do. Two saved switches,
-- profile.settings autoBowlClaim and autoBowlRefill (on by default; SetSetting takes them only from an owner):
--   claim    a cat that has arrived at a bowl is tamed for the player, as the Tame tap does
--   refill   an empty bowl that takes food gets the best food the player already owns; it never buys food
-- Both work only while the player owns Config.AutoBowlPassId and the `autoBowl` LiveFlag is on (BaitService). Pure.
--   passId() -> number                       the pass, 0 until it is made
--   active(flagKnown, flagOn, owns) -> bool  whether the switches act at all
--   bestFood(lures, have) -> string?         the owned food to use: the highest sortOrder, then cost, then id

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local AutoBowl = {}

AutoBowl.FLAG = "autoBowl"
AutoBowl.PASS_KEY = "AutoBowlPassId"
AutoBowl.KEYS = { claim = "autoBowlClaim", refill = "autoBowlRefill" } :: { [string]: string }

function AutoBowl.passId(): number
	local id = (Config :: any)[AutoBowl.PASS_KEY]
	return if type(id) == "number" and id == id then id else 0
end

-- A switch that is not in LiveFlags.KEYS yet reads as off, never as LiveFlagService's default on.
function AutoBowl.active(flagKnown: boolean, flagOn: boolean, owns: boolean): boolean
	return flagKnown and flagOn and owns and AutoBowl.passId() ~= 0
end

local function rank(lure: Types.LureDef): (number, number)
	local order = (lure :: any).sortOrder
	return if type(order) == "number" and order == order then order else 0,
		if type(lure.cost) == "number" and lure.cost == lure.cost then lure.cost else 0
end

function AutoBowl.bestFood(lures: { Types.LureDef }, have: { [string]: number }): string?
	local best: Types.LureDef? = nil
	for _, lure in lures do
		if (have[lure.id] or 0) < 1 then
			continue
		end
		if best == nil then
			best = lure
			continue
		end
		local order, cost = rank(lure)
		local bestOrder, bestCost = rank(best :: Types.LureDef)
		if
			order > bestOrder
			or (
				order == bestOrder
				and (cost > bestCost or (cost == bestCost and lure.id < (best :: Types.LureDef).id))
			)
		then
			best = lure
		end
	end
	return if best ~= nil then best.id else nil
end

return AutoBowl
