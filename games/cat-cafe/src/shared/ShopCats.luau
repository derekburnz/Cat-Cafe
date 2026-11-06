--!strict
-- The shop-only cats sold on a game pass (#1447, store-skus.md, #1191), pure: which pass gives which cat, and which of
-- them a player who owns their passes is still missing. ShopCatService gives a missing one at join and on purchase,
-- so the cat is "yours to keep": one per account, back again if it is ever gone. Each is an exclusive cat
-- (Catalog), so it earns like a cat of its rarity from the owner's newest area at every tier (CatStats.areaMultiplier),
-- can't be sold, traded or offered to the Cat Collector, and counts toward no "different cats" or Index page.

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local ShopCats = {}

export type ShopCat = { catId: string, passKey: string }

-- passKey is the Config field that holds the pass id (0 while the pass is not made, never given)
ShopCats.LIST = table.freeze({
	table.freeze({ catId = "duchess_marzipan", passKey = "RoyalCatPassId" }), -- the Royal Cat, a Legendary
	table.freeze({ catId = "king_croissant", passKey = "KingPackPassId" }), -- the King Cat Pack's King Cat, a Mythical
	-- #1822: the King Cat alone; KingCatPassId is 0 until Tools-Agent makes the pass, so it gives nothing until then
	table.freeze({ catId = "king_croissant", passKey = "KingCatPassId" }),
}) :: { ShopCat }

-- The pass id that gives `entry`, or 0 when it is not made.
function ShopCats.passId(entry: ShopCat): number
	local id = (Config :: any)[entry.passKey]
	return if type(id) == "number" then id else 0
end

-- Every made shop-cat pass id, for PassService to look up.
function ShopCats.passIds(): { number }
	local ids: { number } = {}
	for _, entry in ShopCats.LIST do
		local id = ShopCats.passId(entry)
		if id ~= 0 then
			table.insert(ids, id)
		end
	end
	return ids
end

-- Whether `profile` has a cat of `catId`.
function ShopCats.has(profile: Types.PlayerProfile, catId: string): boolean
	for _, instance in profile.cats do
		if instance.catId == catId then
			return true
		end
	end
	return false
end

-- The cat ids, in LIST order, whose pass `owns` says the player has and that `profile` does not hold. A cat two
-- owned passes give (#1822: the King Cat on the pack and alone) is listed once.
function ShopCats.toGive(
	profile: Types.PlayerProfile,
	owns: (passId: number) -> boolean
): { string }
	local give: { string } = {}
	for _, entry in ShopCats.LIST do
		local id = ShopCats.passId(entry)
		if
			id ~= 0
			and owns(id)
			and table.find(give, entry.catId) == nil
			and not ShopCats.has(profile, entry.catId)
		then
			table.insert(give, entry.catId)
		end
	end
	return give
end

return ShopCats
