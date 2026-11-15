--!strict
-- #4098 (Tier 2 is a big fall for new players): the line under the goal card's "Catch new kinds of cat 2/3" that names
-- what the goal opens, so Cozy Cafe reads as the goal from the second cat on. Its numbers are the catalog's, so the
-- line is true. Pure, so the cloud specs check it.
--   opens(tierName, narrow) -> string?   "Opens Cozy Cafe and the Park 🏆", "Opens Cozy Cafe 🏆" on a phone's card
--   nextTier(tiers, tier) -> TierDef?     the tier after `tier` that is a goal now: nil at the top tier, and nil while
--                                         the next one waits behind its live switch (#3997: tier8, tier9, tier10), as
--                                         the server's rank up check says. RankUp.progress reads it, so the goal card,
--                                         the rank up card, the upgrade shop and the gate signs agree.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog")) :: any

local LateTiers = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LateTiers")) :: any

local GoalLines = {}

function GoalLines.nextTier(tiers: { any }?, tier: number?): any
	if type(tiers) ~= "table" or type(tier) ~= "number" then
		return nil
	end
	for _, def in tiers do
		if type(def) == "table" and def.tier == tier + 1 then
			return if LateTiers.tierOpen(def.tier) then def else nil
		end
	end
	return nil
end

function GoalLines.opens(tierName: string?, narrow: boolean?): string?
	if type(tierName) ~= "string" or tierName == "" then
		return nil
	end
	if narrow then
		return "Opens " .. tierName .. " 🏆"
	end
	local areaName: string? = nil
	for _, tier in Catalog.tiers do
		if tier.name == tierName and type(tier.area) == "string" then
			local area = Catalog.areasById[tier.area]
			areaName = if area then area.name else nil
		end
	end
	if areaName == nil then
		return "Opens " .. tierName .. " 🏆"
	end
	return "Opens " .. tierName .. " and the " .. areaName .. " 🏆"
end

return GoalLines
