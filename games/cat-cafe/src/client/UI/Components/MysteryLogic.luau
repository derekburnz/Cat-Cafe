--!strict
-- Juniper's Mystery Market window (#2565 mystery-market.md section 2a, #2574), as rows for Screens/MysteryMarket. Pure
-- (no Theme), so the cloud spec runner checks it. Prices, the featured week and the buy rules are shared/MysteryMarket's,
-- the same the server uses, so the window never shows a price the server would not take.
--   view(state, now) -> View    this week's featured item (sale price, full price, "Sale ends in 4d 06h"), next week's
--                               "?" teaser ("Next sale: 4d 06h") and every other item at its full price, each with its
--                               Buy button's words and whether it can be pressed
--   left(seconds) -> string     "4d 06h", "6h 12m", "12m", at least "1m"
--   bang(state) -> string?      the bubble under the cart's "!" until the player first opens the window (#2574)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog")) :: any
local MysteryMarket = require(Shared:WaitForChild("MysteryMarket")) :: any

export type Row = {
	id: string,
	name: string,
	text: string,
	price: number, -- what it costs now (the sale price in its featured week)
	full: number, -- its everyday price
	sale: boolean,
	owned: boolean,
	locked: string?, -- "Opens at Tier 2" while below its tier
	button: string, -- the Buy button's words: the price, "Owned", "Tier 2" or "Soon"
	fish: boolean, -- the button shows the golden fish beside its price
	enabled: boolean,
	note: string?, -- the line under it: "You have this!", "Opens at Tier 2", "Not enough golden fish", "Opens soon"
}

export type View = {
	featured: Row?,
	ends: string?, -- "Sale ends in 4d 06h"
	nextLine: string?, -- "Next sale: 4d 06h"
	others: { Row },
	fish: number,
}

local MysteryLogic = {}

MysteryLogic.TITLE = "Mystery Market"
MysteryLogic.SUBTITLE = "Juniper's cart"
MysteryLogic.ICON = "❓"
MysteryLogic.SOON_TEXT = "Opens soon"
MysteryLogic.BANG_TEXT = "❓ Juniper's cart is here!"

-- "4d 06h" past a day, "6h 12m" past an hour, else "12m" (at least 1).
function MysteryLogic.left(seconds: number): string
	local minutes = math.max(1, math.ceil(seconds / 60))
	if minutes >= 24 * 60 then
		return string.format(
			"%dd %02dh",
			math.floor(minutes / (24 * 60)),
			math.floor((minutes % (24 * 60)) / 60)
		)
	elseif minutes >= 60 then
		return string.format("%dh %02dm", math.floor(minutes / 60), minutes % 60)
	end
	return string.format("%dm", minutes)
end

local function row(state: any, item: any, now: number, open: boolean): Row
	local owned = MysteryMarket.owns(state, item.id)
	local price: number = MysteryMarket.priceOf(item, now)
	local tier = math.max(1, math.floor(tonumber(state.tier) or 1))
	local locked = if tier < item.minTier
		then string.format("Opens at Tier %d", item.minTier)
		else nil
	local fish = math.floor(tonumber(state.goldenFish) or 0)
	local afford = fish >= price
	local button, note
	if owned then
		button, note = "Owned", MysteryMarket.OWNED_TEXT
	elseif locked ~= nil then
		button, note = string.format("Tier %d", item.minTier), locked
	elseif not open then
		button, note = "Soon", MysteryLogic.SOON_TEXT
	else
		button = tostring(price)
		note = if afford then nil else MysteryMarket.FISH_TEXT
	end
	return {
		id = item.id,
		name = item.name,
		text = item.text,
		price = price,
		full = item.cost,
		sale = price < item.cost,
		owned = owned,
		locked = locked,
		button = button,
		fish = not owned and locked == nil and open,
		enabled = not owned and locked == nil and open and afford,
		note = note,
	}
end

-- `flags` (live switch key -> on): an item behind a switch that is off is left off the shelf, featured or not (#3535).
function MysteryLogic.view(state: any, now: number, flags: { [string]: boolean }?): View
	local safe: any = {
		mystery = if type(state) == "table" and type(state.mystery) == "table"
			then state.mystery
			else {},
		goldenFish = if type(state) == "table" then state.goldenFish else 0,
		tier = if type(state) == "table" then state.tier else 1,
	}
	local open = type(state) == "table" and state.mysteryOpen == true
	local featuredId: string? = MysteryMarket.featuredAt(now)
	local featured: Row? = nil
	local others: { Row } = {}
	for _, item in Catalog.mysteryItems or {} do
		if not MysteryMarket.listed(item, flags) then
			continue
		end
		local made = row(safe, item, now, open)
		if item.id == featuredId then
			featured = made
		else
			table.insert(others, made)
		end
	end
	local nextAt: number = MysteryMarket.nextAt(now)
	local wait = MysteryLogic.left(nextAt - now)
	return {
		featured = featured,
		ends = if featured ~= nil then "Sale ends in " .. wait else nil,
		nextLine = if MysteryMarket.nextFeatured(now) ~= nil then "Next sale: " .. wait else nil,
		others = others,
		fish = math.floor(tonumber(safe.goldenFish) or 0),
	}
end

-- The bubble under the cart's "!" (#2574): only until the player first opens Juniper's window.
function MysteryLogic.bang(state: any): string?
	if type(state) ~= "table" or state.mysterySeen ~= false then
		return nil
	end
	return MysteryLogic.BANG_TEXT
end

return MysteryLogic
