--!strict
-- Sell extra Commons (#1573, Derek 2026-11-05: "Sell extra Commons, keeping one of each"). One tap sells every
-- spare Common cat and keeps the best one of each kind. A cat is never sold when it is:
--   - working a role (`spotId`), or the kind's keeper (a working one, else its best plain cat by CatStats.isBetter at
--     the player's tier), so one of each stays;
--   - locked (F62), exclusive (F95), gold or rainbow (F99, only "base" cats count as spares);
--   - on a trade offer (`inTrade`, checked by the server).
-- The player always keeps at least one cat. Pure: CafeService's SellExtraCommons pays each one's rarity sellValue,
-- as SellCat does, and the cat room's button shows the count and coins before it is pressed.

local CatStats = require(script.Parent.CatStats)
local Catalog = require(script.Parent.Catalog)
local Types = require(script.Parent.Types)

local SellExtras = {}

SellExtras.RARITY = "Common"

export type Plan = {
	uids: { string }, -- the cats to sell, in uid order
	coins: number, -- what they pay together
}

-- The spare Commons in `profile` at `tier`. `inTrade(uid)` is true for a cat on a trade offer (nil: none are).
function SellExtras.plan(
	profile: Types.PlayerProfile,
	tier: number?,
	inTrade: ((string) -> boolean)?
): Plan
	local byKind: { [string]: { Types.CatInstance } } = {}
	for _, instance in profile.cats do
		local def = Catalog.getCat(instance.catId)
		if def ~= nil and def.rarity == SellExtras.RARITY then
			local list = byKind[instance.catId]
			if list == nil then
				list = {}
				byKind[instance.catId] = list
			end
			table.insert(list, instance)
		end
	end
	local uids: { string } = {}
	for _, list in byKind do
		table.sort(list, CatStats.betterFor(tier))
		-- the kind's keeper: a working cat if one works, else its best plain ("base") cat, so a gold or locked one
		-- never makes the best plain one a spare
		local keeper: Types.CatInstance? = nil
		for _, instance in list do
			if instance.spotId ~= nil then
				keeper = instance
				break
			end
		end
		if keeper == nil then
			for _, instance in list do
				if instance.variant == "base" then
					keeper = instance
					break
				end
			end
		end
		for _, instance in list do
			local def = Catalog.getCat(instance.catId) :: Types.CatDef
			local spare = instance ~= keeper
				and instance.spotId == nil
				and instance.locked ~= true
				and def.exclusive ~= true
				and instance.variant == "base"
				and not (inTrade ~= nil and inTrade(instance.uid))
			if spare then
				table.insert(uids, instance.uid)
			end
		end
	end
	table.sort(uids)
	-- never the last cat (SellCat's rule): with only Commons that are all spares, one stays
	local total = 0
	for _ in profile.cats do
		total += 1
	end
	while #uids > 0 and #uids >= total do
		table.remove(uids)
	end
	local value = Catalog.rarities[SellExtras.RARITY].sellValue
	return { uids = uids, coins = #uids * value }
end

return SellExtras
