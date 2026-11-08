--!strict
-- #2345 (Derek2: "add an exclamation mark to the upgrades if something is available to buy that you can afford"):
-- one rule for an upgrade's next level, so the Upgrades window's Buy button (Screens/UpgradeShop) and the HUD tile's
-- red "!" (Notices, Screens/HUD) never disagree. Pure, so the cloud specs check it.
--   status(def, level, tier, money) -> Status   what the row's button shows for the next level
--   any(upgrades, state) -> boolean             some upgrade's next level can be bought right now
--   level(def, levels) -> number                 the level owned, never under startLevel (as ProfileSchema clamps
--                                                it: the Espresso machine starts at 1, and its level 1 costs 0)
-- Tier gates (data-model section 5b): level 1 needs requiresTier, higher levels requiresTierAtLevel's caps.

local Types = require(script.Parent.Parent.Types)

export type Status = {
	kind: string, -- "max" | "locked" | "none" (no price yet) | "buy" (affordable) | "dear" (not enough money)
	needsTier: number?, -- the tier the next level needs, when there is one
	cost: number?, -- the next level's price, when there is one
}

local UpgradeReady = {}

function UpgradeReady.level(def: Types.UpgradeDef, levels: { [string]: number }): number
	local start = if type(def.startLevel) == "number" then def.startLevel else 0
	return math.max(levels[def.id] or start, start)
end

function UpgradeReady.status(
	def: Types.UpgradeDef,
	level: number,
	tier: number,
	money: number
): Status
	if level >= def.maxLevel then
		return { kind = "max" }
	end
	local needsTier: number? = def.requiresTier
	local perLevel = def.requiresTierAtLevel
	if perLevel and perLevel[level + 1] then
		needsTier = math.max(needsTier or 0, perLevel[level + 1])
	end
	local cost = def.costs[level + 1]
	if needsTier ~= nil and tier < (needsTier :: number) then
		return { kind = "locked", needsTier = needsTier, cost = cost }
	end
	if cost == nil then
		return { kind = "none", needsTier = needsTier }
	end
	return { kind = if money >= cost then "buy" else "dear", needsTier = needsTier, cost = cost }
end

function UpgradeReady.any(upgrades: { Types.UpgradeDef }, state: Types.PlayerState): boolean
	for _, def in upgrades do
		local level = UpgradeReady.level(def, state.upgradeLevels)
		if UpgradeReady.status(def, level, state.tier, state.money).kind == "buy" then
			return true
		end
	end
	return false
end

return UpgradeReady
