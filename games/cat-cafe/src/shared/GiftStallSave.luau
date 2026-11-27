--!strict
-- #5643 The Christmas Event's Gift Stall (snowglobe-village-spec section 5): 8 items at fixed prices in Snowflakes,
-- nothing random and nothing for Robux. Pure, so the cloud specs run it; GiftStallService applies it.
--   ITEMS                              the spec's 8 items (id, kind, name, price), 1,800 Snowflakes in all (TOTAL)
--   item(id)                           an item, or nil
--   fresh() / sanitize(raw)            profile.giftStall: { bought = { [id] = true } }. No VERSION bump (as #5502's
--                                      Snowflakes): an older server drops the field, so christmasEvent goes on only
--                                      once every server runs this code
--   openAt(now)                        the event's dates: from Advent.FIRST_OPEN (Nov 29 2026 17:00 UTC) until
--                                      Advent.CLOSES (the end of Jan 3 2027)
--   buyBlocker(save, flakes, id, now, tier, flagOn)   why a buy is refused, or nil
--   buy(save, flakes, id)              the Snowflakes left once the item is bought, or nil (after buyBlocker said nil)
--   decorId(id) / lookId(id)           where an item is owned for good: a decor piece in profile.decorOwned
--                                      (Catalog.christmasDecor), a hat as a Looks accessory (the Style tab)
--   grantOwned(save, decorOwned)       puts every decor piece bought into decorOwned; returns how many it added
--   lookItems(save, items)             a copy of the Looks items with the hats bought added under lookId
--   view(save, flakes)                 the window's view (Components/GiftStallLogic.View)

local Advent = require(script.Parent.Advent)

local GiftStallSave = {}

GiftStallSave.FLAG = "christmasEvent"
GiftStallSave.TIER = 2 -- the portal's tier (spec section 1)
GiftStallSave.OPENS_AT = Advent.FIRST_OPEN
GiftStallSave.CLOSES_AT = Advent.CLOSES
GiftStallSave.TOTAL = 1800
GiftStallSave.RANGE = 22 -- studs from a SnowglobeStall's pivot: the window closes at 18 (UI.giftStall), plus 4

export type Kind = "outfit" | "decor"
export type Item = { id: string, kind: Kind, name: string, price: number }
export type Save = { bought: { [string]: boolean } }
export type ViewItem = { id: string, name: string, cost: number, owned: boolean }
export type View = { snowflakes: number, items: { ViewItem } }

local function entry(id: string, kind: Kind, name: string, price: number): Item
	local item: Item = { id = id, kind = kind, name = name, price = price }
	table.freeze(item :: any)
	return item
end

GiftStallSave.ITEMS = table.freeze({
	entry("santa_hat", "outfit", "Santa Hat", 150),
	entry("reindeer_antlers", "outfit", "Reindeer Antlers", 200),
	entry("knit_beanie", "outfit", "Knit Beanie", 250),
	entry("present_pile", "decor", "Present Pile", 150),
	entry("snowman", "decor", "Snowman", 200),
	entry("gingerbread_house", "decor", "Gingerbread House", 250),
	entry("stocking_wall", "decor", "Stocking Wall", 250),
	entry("little_tree", "decor", "Little Lit Tree", 350),
}) :: { Item }

local byId: { [string]: Item } = {}
for _, item in GiftStallSave.ITEMS do
	byId[item.id] = item
end

function GiftStallSave.item(id: string): Item?
	return byId[id]
end

function GiftStallSave.decorId(id: string): string
	return "decor_" .. id
end

function GiftStallSave.lookId(id: string): string
	return "acc_" .. id
end

function GiftStallSave.fresh(): Save
	return { bought = {} }
end

-- Only known item ids survive, so a hand-edited or old save can never own something the stall does not sell.
function GiftStallSave.sanitize(raw: unknown): Save?
	if type(raw) ~= "table" then
		return nil
	end
	local out = GiftStallSave.fresh()
	local bought = (raw :: any).bought
	if type(bought) == "table" then
		for id, yes in bought do
			if type(id) == "string" and yes == true and byId[id] ~= nil then
				out.bought[id] = true
			end
		end
	end
	return out
end

function GiftStallSave.openAt(now: number): boolean
	return now >= GiftStallSave.OPENS_AT and now < GiftStallSave.CLOSES_AT
end

local function whole(n: unknown): number
	return if type(n) == "number" and n == n then math.max(0, math.floor(n)) else 0
end

function GiftStallSave.buyBlocker(
	save: Save?,
	flakes: number?,
	id: string,
	now: number,
	tier: number,
	flagOn: boolean
): string?
	local item = byId[id]
	if item == nil then
		return "Unknown item"
	end
	if not flagOn then
		return "The Gift Stall is closed"
	end
	if now < GiftStallSave.OPENS_AT then
		return "The Gift Stall opens Sun Nov 29"
	end
	if now >= GiftStallSave.CLOSES_AT then
		return "The Gift Stall is closed until next Christmas"
	end
	if tier < GiftStallSave.TIER then
		return string.format("Opens at Tier %d", GiftStallSave.TIER)
	end
	if save ~= nil and save.bought[id] == true then
		return "Already yours"
	end
	if whole(flakes) < item.price then
		return "You need more Snowflakes"
	end
	return nil
end

function GiftStallSave.buy(save: Save, flakes: number?, id: string): number?
	local item = byId[id]
	local have = whole(flakes)
	if item == nil or save.bought[id] == true or have < item.price then
		return nil
	end
	save.bought[id] = true
	return have - item.price
end

function GiftStallSave.grantOwned(save: Save?, decorOwned: { [string]: boolean }): number
	if save == nil then
		return 0
	end
	local added = 0
	for id, yes in save.bought do
		local item = if yes then byId[id] else nil
		if item ~= nil and item.kind == "decor" then
			local decorId = GiftStallSave.decorId(id)
			if decorOwned[decorId] ~= true then
				decorOwned[decorId] = true
				added += 1
			end
		end
	end
	return added
end

-- A copy; nothing is saved, so the hats stay owned through save.bought alone (as HarvestSave.lookItems).
function GiftStallSave.lookItems(save: Save?, items: { [string]: boolean }): { [string]: boolean }
	local out = table.clone(items)
	if save == nil then
		return out
	end
	for id, yes in save.bought do
		local item = if yes then byId[id] else nil
		if item ~= nil and item.kind == "outfit" then
			out[GiftStallSave.lookId(id)] = true
		end
	end
	return out
end

function GiftStallSave.view(save: Save?, flakes: number?): View
	local items: { ViewItem } = {}
	for _, item in GiftStallSave.ITEMS do
		table.insert(items, {
			id = item.id,
			name = item.name,
			cost = item.price,
			owned = save ~= nil and save.bought[item.id] == true,
		})
	end
	return { snowflakes = whole(flakes), items = items }
end

return GiftStallSave
