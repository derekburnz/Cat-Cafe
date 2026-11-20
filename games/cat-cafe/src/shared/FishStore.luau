--!strict
-- #4055 (Derek 2026-11-13 23:53 UTC, store-fish-prices plan): some Store passes can also be bought with golden fish, at
-- about 50 fish per Robux (rounded to 50). A pass bought with fish gives exactly what the Robux pass gives: its id
-- joins the player's owned set (PassService.addBought), so every check that reads PassService reads it the same way.
-- #4610 (Derek 2026-11-15 22:21 UTC: "make it only 2x/3x/4x money and starter pack robux only rest can be earned with
-- fish"): every Store pass is on the list except the 2x, 3x and 4x Money passes (ROBUX_ONLY_PASSES), and the
-- Starter Bundle stays a Robux only product. Nothing random is sold here. Pure.

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local FishStore = {}

FishStore.PER_ROBUX = 25 -- Derek 2026-11-17: "half all the fish prices for store" (was 50)

export type Item = {
	key: string, -- the save key in profile.fishBought, and what BuyWithFish sends
	name: string,
	passField: string, -- the Config field that holds the Robux pass id (a number, or a list whose first made id counts)
	robux: number, -- the full Robux price before any sale (Config.StoreWasPrice `was`), the fish price's base
	flag: string?, -- a LiveFlag the pass waits for (its Store card hides while off), so a fish buy waits too
}

-- In the Store's order. Robux prices from passes.json.
FishStore.LIST = {
	{ key = "stylishPack", name = "Stylish Pack", passField = "StylishPackPassId", robux = 99 },
	{ key = "winterPack", name = "Winter Pack", passField = "WinterPackPassId", robux = 99 },
	{ key = "chefPack", name = "Chef Pack", passField = "ChefPackPassId", robux = 99 },
	{ key = "spacePack", name = "Space Pack", passField = "SpacePackPassId", robux = 99 },
	{
		key = "accessories",
		name = "Cat Accessories",
		passField = "CatAccessoriesPassId",
		robux = 149,
	},
	{ key = "uniforms", name = "Uniform Styles", passField = "UniformStylesPassId", robux = 149 },
	{ key = "cafeStyle", name = "Cafe Style", passField = "CafeStylePassId", robux = 249 },
	{ key = "grand", name = "Grand Cafe Theme", passField = "GrandThemePassId", robux = 799 },
	{
		key = "gardenDecor",
		name = "Garden Decor Pack",
		passField = "GardenDecorPackPassId",
		robux = 149,
	},
	{ key = "signStyles", name = "Sign Style Pack", passField = "SignStylePackPassId", robux = 79 },
	-- #4610: the rest of the Store's passes, at the full price (the half price sale does not lower a fish price).
	-- Design-Agent may set final fish prices; until then the same 50 a Robux rule.
	{ key = "vip", name = "VIP", passField = "VipPassId", robux = 25 },
	{ key = "extraSlot", name = "Extra Slot", passField = "ExtraSlotPassIds", robux = 149 },
	{ key = "longNap", name = "Long Nap", passField = "LongNapPassId", robux = 199 },
	{ key = "secondBowl", name = "Second Bait Bowl", passField = "SecondBowlPassId", robux = 149 },
	{
		key = "autoBowl",
		name = "Auto Bowl",
		passField = "AutoBowlPassId",
		robux = 19,
		flag = "autoBowl",
	},
	{ key = "royalCat", name = "Royal Cat Pack", passField = "RoyalCatPassId", robux = 599 },
	{ key = "kingPack", name = "Cat King Pack", passField = "KingPackPassId", robux = 999 },
} :: { Item }

-- #4610: the only passes that are never sold for fish (with the Starter Bundle, a product, never on this list).
FishStore.ROBUX_ONLY_PASSES = { "MoneyPassIds" } :: { string }

-- #4610 part 2: the Store's developer products that can be bought with golden fish. A fish buy gives exactly what
-- the receipt gives, through the same server function (ProductService.give for the Thank You Badge,
-- CafePassService.buyPaid for the Cafe Pass), so the two can never drift apart. `once` is how often it can be had:
-- "account" (profile.onceBought) or "season" (the running season's paid track). The Starter Bundle stays Robux only.
export type Product = {
	key: string, -- the Store card's key, and what BuyWithFish sends
	name: string,
	productId: string, -- the Catalog.products id (Config.ProductIds key)
	robux: number, -- the full Robux price, the fish price's base
	once: "account" | "season",
}
FishStore.PRODUCTS = {
	{
		key = "thankYou",
		name = "Thank You Badge",
		productId = "thank_you_badge",
		robux = 25,
		once = "account",
	},
	{ key = "cafePass", name = "Cafe Pass", productId = "cafe_pass", robux = 299, once = "season" },
} :: { Product }
FishStore.ROBUX_ONLY_PRODUCTS = { "starter_bundle" } :: { string }

local byKey: { [string]: Item } = {}
for _, item in FishStore.LIST do
	byKey[item.key] = item
end

function FishStore.item(key: string): Item?
	return byKey[key]
end

local productByKey: { [string]: Product } = {}
for _, product in FishStore.PRODUCTS do
	productByKey[product.key] = product
end

function FishStore.product(key: string): Product?
	return productByKey[key]
end

-- The fish price: PER_ROBUX fish a Robux, to the nearest 50 (R$99 -> 2,500). A pass or a product.
function FishStore.price(item: { robux: number }): number
	return math.floor(item.robux * FishStore.PER_ROBUX / 50 + 0.5) * 50
end

-- Whether a product's Robux product is made (Config.ProductIds), as its Store card reads it.
function FishStore.productMade(product: Product): boolean
	local id = Config.ProductIds[product.productId]
	return type(id) == "number" and id ~= 0
end

-- Whether this save has `product` already: the badge once an account, the Cafe Pass this save's season (the save
-- rolls onto the running season before a buy, CafePassService.buyPaid).
function FishStore.productHad(profile: Types.PlayerProfile, product: Product): boolean
	if product.once == "account" then
		return profile.onceBought[product.productId] == true
	end
	return profile.pass.paidSeason ~= 0 and profile.pass.paidSeason == profile.pass.season
end

-- Why `product` cannot be bought with fish now, or nil when it can. `season` is the running Cafe Pass season (0
-- while none runs) and `saleOpen` whether its paid track is offered now (CafePass.saleOpen); only the Cafe Pass reads
-- them.
function FishStore.productBlocker(
	profile: Types.PlayerProfile,
	product: Product,
	season: number,
	saleOpen: boolean
): string?
	if not FishStore.productMade(product) then
		return "Coming soon"
	end
	if product.once == "season" then
		if season == 0 or not saleOpen then
			return "The Cafe Pass opens again next season"
		end
		if profile.pass.paidSeason == season then
			return "You own this already"
		end
	elseif FishStore.productHad(profile, product) then
		return "You own this already"
	end
	if profile.goldenFish < FishStore.price(product) then
		return "Not enough golden fish yet"
	end
	return nil
end

-- The Robux pass's id, 0 while it is not made (then it cannot be bought with fish either). For a list field
-- (ExtraSlotPassIds), its first made id, as the Store card reads it.
function FishStore.passId(item: Item): number
	local id = (Config :: any)[item.passField]
	if type(id) == "table" then
		for _, each in id do
			if type(each) == "number" and each ~= 0 then
				return each
			end
		end
		return 0
	end
	return if type(id) == "number" then id else 0
end

-- The pass ids a save's fish purchases give, for PassService's owned set. Only made passes.
function FishStore.boughtIds(bought: { [string]: boolean }): { number }
	local ids: { number } = {}
	for _, item in FishStore.LIST do
		local id = FishStore.passId(item)
		if bought[item.key] == true and id ~= 0 then
			table.insert(ids, id)
		end
	end
	return ids
end

-- Why `item` cannot be bought with fish now, or nil when it can. `ownsPass` is whether the player owns the pass
-- already (by Robux or fish).
function FishStore.blocker(profile: Types.PlayerProfile, item: Item, ownsPass: boolean): string?
	if FishStore.passId(item) == 0 then
		return "Coming soon"
	end
	if ownsPass or profile.fishBought[item.key] == true then
		return "You own this already"
	end
	if profile.goldenFish < FishStore.price(item) then
		return "Not enough golden fish yet"
	end
	return nil
end

-- A save's fishBought, kept to known keys set true.
function FishStore.sanitize(raw: any): { [string]: boolean }
	local out: { [string]: boolean } = {}
	if type(raw) == "table" then
		for key, value in raw do
			if type(key) == "string" and byKey[key] ~= nil and value == true then
				out[key] = true
			end
		end
	end
	return out
end

-- For the Store (PlayerState.fishStore): each item's key, fish price and whether this save bought it with fish
-- (#4610: then each product's, bought meaning this save has it, by Robux or fish).
export type ViewRow = { key: string, fish: number, bought: boolean, made: boolean }
function FishStore.view(profile: Types.PlayerProfile): { ViewRow }
	local rows: { ViewRow } = {}
	for _, item in FishStore.LIST do
		table.insert(rows, {
			key = item.key,
			fish = FishStore.price(item),
			bought = profile.fishBought[item.key] == true,
			made = FishStore.passId(item) ~= 0,
		})
	end
	for _, product in FishStore.PRODUCTS do
		table.insert(rows, {
			key = product.key,
			fish = FishStore.price(product),
			bought = FishStore.productHad(profile, product),
			made = FishStore.productMade(product),
		})
	end
	return rows
end

return FishStore
