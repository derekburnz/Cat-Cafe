--!strict
-- #4251 Harvest Hollow, the limited autumn area (Derek OK'd 2026-11-14 with changes; spec in the project files,
-- Design-Agent/harvest-hollow-2026-11-14/harvest-hollow-spec.md). Shared data both sides read: the Harvest Stall's
-- items and pumpkin prices (section 4), the earns-like table for kept harvest cats (section 3b), when the area is
-- open and the tier it opens at. Pure: no services, so the cloud specs read it.
--   STALL                 the Stall's items in the window's order: { id, kind, name, price, model }
--   item(id)              one of them, or nil
--   TOTAL                 every item's price added up (480, about 8 hours of play over the 12 days)
--   earnsLike(rarity)     the rarity a kept harvest cat earns like in its owner's newest area
--   open(now)             true from OPENS_AT until CLOSES_AT (the server's date switch has the last word)
-- Fixed prices, nothing random, nothing sold for Robux here.

local HarvestHollow = {}

HarvestHollow.OPENS_AT = 1795636800 -- Wednesday 2026-11-25 20:00 UTC
HarvestHollow.CLOSES_AT = 1796601540 -- Sunday 2026-12-06 23:59 UTC
HarvestHollow.TIER = 2 -- Derek: the portal opens at Tier 2

export type Kind = "outfit" | "decor"
export type Item = {
	id: string,
	kind: Kind,
	name: string,
	price: number, -- pumpkins
	model: string, -- the picture's model in ReplicatedStorage.Assets
}

-- Model-Agent 2026-11-15 (#4375): all five outfits are hats on the Outfit_Hat spot; Sunflower Hat and Wheat Wreath
-- replace the draft's Autumn Scarf and Leaf Crown; #4378: Hay Bale Sofa, Paw Pumpkin and Apple Bushel (Season 1 already
-- has a Hay Bale Seat, a Pumpkin Lantern and an Apple Crate Shelf)
HarvestHollow.STALL = table.freeze({
	{
		id = "acorn_hat",
		kind = "outfit",
		name = "Acorn Hat",
		price = 40,
		model = "CatCafe_Accessory_AcornHat",
	},
	{
		id = "sunflower_hat",
		kind = "outfit",
		name = "Sunflower Hat",
		price = 50,
		model = "CatCafe_Accessory_SunflowerHat",
	},
	{
		id = "wheat_wreath",
		kind = "outfit",
		name = "Wheat Wreath",
		price = 60,
		model = "CatCafe_Accessory_WheatWreath",
	},
	{
		id = "pumpkin_hat",
		kind = "outfit",
		name = "Pumpkin Hat",
		price = 70,
		model = "CatCafe_Accessory_PumpkinHat",
	},
	{
		id = "feather_cap",
		kind = "outfit",
		name = "Feather Cap",
		price = 80,
		model = "CatCafe_Accessory_FeatherCap",
	},
	{
		id = "hay_bale_sofa",
		kind = "decor",
		name = "Hay Bale Sofa",
		price = 25,
		model = "CatCafe_Decor_HayBaleSofa",
	},
	{
		id = "paw_pumpkin",
		kind = "decor",
		name = "Paw Pumpkin",
		price = 30,
		model = "CatCafe_Decor_PawPumpkin",
	},
	{
		id = "apple_bushel",
		kind = "decor",
		name = "Apple Bushel",
		price = 30,
		model = "CatCafe_Decor_AppleBushel",
	},
	{
		id = "corn_sheaf",
		kind = "decor",
		name = "Corn Sheaf",
		price = 25,
		model = "CatCafe_Decor_CornSheaf",
	},
	{
		id = "pie_counter",
		kind = "decor",
		name = "Pie Counter",
		price = 40,
		model = "CatCafe_Decor_PieCounter",
	},
	{
		id = "harvest_wreath",
		kind = "decor",
		name = "Harvest Wreath",
		price = 30,
		model = "CatCafe_Decor_HarvestWreath",
	},
} :: { Item })

local byId: { [string]: Item } = {}
local total = 0
for _, entry in HarvestHollow.STALL do
	byId[entry.id] = entry
	total += entry.price
end
HarvestHollow.TOTAL = total

function HarvestHollow.item(id: unknown): Item?
	if type(id) ~= "string" then
		return nil
	end
	return byId[id :: string]
end

-- Section 3b (Derek): a kept harvest cat earns like the cat two rarities lower in its owner's newest area, never
-- below that area's Common
HarvestHollow.EARNS_LIKE = table.freeze({
	Mythical = "Epic",
	Legendary = "Rare",
	Epic = "Common",
	Rare = "Common",
	Common = "Common",
} :: { [string]: string })

function HarvestHollow.earnsLike(rarity: string): string
	return HarvestHollow.EARNS_LIKE[rarity] or "Common"
end

function HarvestHollow.open(now: number): boolean
	return now >= HarvestHollow.OPENS_AT and now < HarvestHollow.CLOSES_AT
end

return HarvestHollow
