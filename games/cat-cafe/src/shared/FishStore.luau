--!strict
-- #4055 (Derek 2026-11-13 23:53 UTC, store-fish-prices plan): some Store passes can also be bought with golden fish, at
-- about 50 fish per Robux (rounded to 50). A pass bought with fish gives exactly what the Robux pass gives: its id
-- joins the player's owned set (PassService.addBought), so every check that reads PassService reads it the same way.
-- The money passes, VIP, the Royal and King cats, Extra Slot, Second Bowl, the Starter Bundle, the Cafe Pass and the
-- Thank You Badge are never on this list (Robux only). Nothing random is sold here. Pure.

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local FishStore = {}

FishStore.FLAG = "fishStore" -- the live switch: BuyWithFish is refused and the Store shows no fish prices while off
FishStore.PER_ROBUX = 50

export type Item = {
	key: string, -- the save key in profile.fishBought, and what BuyWithFish sends
	name: string,
	passField: string, -- the Config field that holds the Robux pass id
	robux: number, -- the Robux price (passes.json), the fish price's base
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
} :: { Item }

local byKey: { [string]: Item } = {}
for _, item in FishStore.LIST do
	byKey[item.key] = item
end

function FishStore.item(key: string): Item?
	return byKey[key]
end

-- The fish price: PER_ROBUX fish a Robux, to the nearest 50 (R$99 -> 4,950).
function FishStore.price(item: Item): number
	return math.floor(item.robux * FishStore.PER_ROBUX / 50 + 0.5) * 50
end

-- The Robux pass's id, 0 while it is not made (then it cannot be bought with fish either).
function FishStore.passId(item: Item): number
	local id = (Config :: any)[item.passField]
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

-- For the Store (PlayerState.fishStore): each item's key, fish price and whether this save bought it with fish.
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
	return rows
end

return FishStore
