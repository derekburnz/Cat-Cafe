--!strict
-- The Corner Shop window's words and rules (#1052, corner-shop.md section 4), kept pure so the cloud tests can load
-- it (no Theme). Screens/CornerShop draws them. The server decides every buy (shared/CornerShop.buyBlocker); these
-- only grey a button the server would refuse anyway and say why.
--
--   clock(restocksAt, now)        "Restocks in 3:12"
--   chance(itemId)                "In stock 9 times in 10", "Always in stock"
--   stockLine(item)               "x2 left" while the player can buy some, else "" (#1671, #1678)
--   button(item, row, coins, room) the Buy button's words and whether it can be pressed
--   snackLine(snackXp)            "" (#1255: no daily cat food cap any more)
--   effect(row)                   what the row does, in a line
--   catsByLevel(cats)             the snack's cat picker, highest level first
--   sections(items)               #1599: the stock grouped under "Potions", "Cat food" and "Bait" headers
--   stateFromView(stock)          #2593: the saved shop state as far as CornerShopStock shows it
--   buyAll(stock, kind, tier, coins, held)  #2593: a section's Buy all plan and its card's words (shared planAll)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShortNumber = require(script.Parent.ShortNumber)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local CornerShop = require(Shared:WaitForChild("CornerShop"))
local SharedTypes = require(Shared:WaitForChild("Types"))

local CornerShopLogic = {}

-- #1577 (day-cart.md): the window's shown name; code keeps the CornerShop names. No help line since #1688.
CornerShopLogic.TITLE = "Day Cart"

export type Item = SharedTypes.CornerShopItem
export type Row = SharedTypes.CornerShopRow

export type ButtonView = { text: string, enabled: boolean }

export type CatEntry = { uid: string, catId: string, name: string?, level: number }

local function commas(n: number): string
	local whole = tostring(math.floor(math.abs(n) + 0.5))
	local out = whole:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return out
end

local function money(n: number): string
	return "$" .. ShortNumber.format(n)
end
CornerShopLogic.money = money

function CornerShopLogic.clock(restocksAt: number, now: number): string
	local left = math.max(0, math.ceil(restocksAt - now))
	return ("Restocks in %d:%02d"):format(left // 60, left % 60)
end

-- How often the row is in stock (#1577, day-cart.md): its place in the list by price (CornerShop.listOrder, cheapest
-- first) gives shared CornerShop.stockChance, 95% down 4.5% a place to 5%: "In stock 95% of days". The window keeps
-- the odds hidden (#1190); this is for the spec and any later odds card.
function CornerShopLogic.chance(itemId: string): string
	for place, index in CornerShop.listOrder() do
		if Catalog.cornerShop[index].id == itemId then
			local percent = math.floor(CornerShop.stockChance(place) * 1000 + 0.5) / 10
			return ("In stock %s%% of days"):format(tostring(percent))
		end
	end
	return ""
end

-- A row the player's tier doesn't open yet (corner-shop-v2.md section 2): "Opens at Tier 3", else nil.
function CornerShopLogic.gate(item: Item, tier: number?): string?
	local needs = item.needsTier
	if needs and (tier or 1) < needs then
		return ("Opens at Tier %d"):format(needs)
	end
	return nil
end

function CornerShopLogic.stockLine(item: Item): string
	-- #1678 (Derek2 11-05: "just more text clutter"): no "None this time" or "You bought 2", the button already
	-- says None or Sold out. #1671: past the family's limit the cart's stock is not the player's to buy, so no count
	-- beside "Back at sunrise" either.
	local left = item.amount - item.bought
	if item.amount <= 0 or left <= 0 or (item :: any).outToday == true then
		return ""
	end
	return ("x%d left"):format(left)
end

-- The Buy button, in the server's order (shared/CornerShop.buyBlocker): "Tier 3", "Out of stock", "Sold out",
-- "Back at sunrise", "Food full", else "Buy · $1.2K", greyed when the coins fall short. "Back at sunrise" (#1435) is a
-- row whose family hit its limit: the server marks it `outToday` and the window never shows the limit itself (#1190).
-- The limits refill at every in-game sunrise (#1631), so it reads as the server's "back at sunrise!" toast does.
function CornerShopLogic.button(
	item: Item,
	row: Row?,
	coins: number,
	snackRoom: number,
	tier: number?
): ButtonView
	local needs = item.needsTier
	if needs and (tier or 1) < needs then
		return { text = ("Tier %d"):format(needs), enabled = false }
	end
	if item.amount <= 0 then
		return { text = "Out of stock", enabled = false } -- #3340: was "None", unclear beside "x3 left"
	end
	if item.bought >= item.amount then
		return { text = "Sold out", enabled = false }
	end
	if (item :: any).outToday == true then
		return { text = "Back at sunrise", enabled = false }
	end
	if row and row.kind == "food" and (row.xp or 0) > snackRoom then
		return { text = "Food full", enabled = false }
	end
	return { text = "Buy · " .. money(item.price), enabled = coins >= item.price }
end

-- #1255: cat food has no daily XP cap, so the room is unlimited and the line is empty. Both stay for the window's
-- callers until UI-Engineer drops the line.
function CornerShopLogic.snackRoom(_snackXp: number): number
	return math.huge
end

function CornerShopLogic.snackLine(_snackXp: number): string
	return ""
end

-- What a row does (corner-shop.md section 2), in one short line. A bait row (#1281) also says how many of that food
-- the player has (`owned`).
function CornerShopLogic.effect(row: Row, owned: number?): string
	if row.kind == "bait" then
		return ("Bait for your bowl · You have %d"):format(owned or 0)
	elseif row.kind == "potion" then
		local potion = if row.potionId then Catalog.getPotion(row.potionId) else nil
		if potion == nil then
			return "Into your potion bag"
		end
		return ("%s for %d min, into your potion bag"):format(potion.effect, potion.minutes)
	elseif row.kind == "food" then
		return ("+%s XP cat food, into your Bag"):format(commas(row.xp or 0))
	end
	-- #1483: the bubble machine and fireworks shows are gone, so any other kind has no line yet
	return ""
end

-- #1599 (Derek2 11-05: "sections and smaller boxes/text per item so its easiest to see a lot and scroll through"):
-- the headers the window groups its rows under, by the row's kind.
CornerShopLogic.SECTION_TITLES = table.freeze({
	potion = "Potions",
	food = "Cat food",
	bait = "Bait",
	show = "Shows",
}) :: { [string]: string }
local OTHER = "More"

export type Section = { kind: string, title: string, indexes: { number } }

-- The stock's rows grouped by kind, each group in the order its first row comes in the stock and each row keeping its
-- place in the stock; `indexes` point into `items`. An item the catalog doesn't know goes under "More".
function CornerShopLogic.sections(items: { Item }): { Section }
	local out: { Section } = {}
	local byKind: { [string]: Section } = {}
	for index, item in items do
		local row = Catalog.cornerShopById[item.itemId]
		local kind: string = if row ~= nil then row.kind else "other"
		local section = byKind[kind]
		if section == nil then
			local made: Section = {
				kind = kind,
				title = CornerShopLogic.SECTION_TITLES[kind] or OTHER,
				indexes = {},
			}
			byKind[kind] = made
			table.insert(out, made)
			section = made
		end
		table.insert(section.indexes, index)
	end
	return out
end

-- The player's cats for the snack picker, highest level first (then by name, then uid, so the order holds still).
function CornerShopLogic.catsByLevel(
	cats: { [string]: any }?,
	names: { [string]: string }?
): { CatEntry }
	local out: { CatEntry } = {}
	local list: { [string]: any } = cats or {}
	for uid, cat in list do
		if type(cat) == "table" and type(cat.catId) == "string" then
			local catId: string = cat.catId
			local named: string? = if type(cat.name) == "string"
				then cat.name
				else (names or {})[catId]
			local level: number = if type(cat.level) == "number" then cat.level else 1
			local entry: CatEntry = { uid = uid, catId = catId, name = named, level = level }
			table.insert(out, entry)
		end
	end
	table.sort(out, function(a: CatEntry, b: CatEntry): boolean
		if a.level ~= b.level then
			return a.level > b.level
		end
		local an: string, bn: string = a.name or a.catId, b.name or b.catId
		if an ~= bn then
			return an < bn
		end
		return a.uid < b.uid
	end)
	return out
end

-- #2593: the shop state planAll needs, rebuilt from what CornerShopStock shows: each row's bought, and today's count
-- from `leftToday` when the server sends it, else the whole limit for a row that is out today (`outToday`) and 0 for
-- the rest (the server then stops at the limit and the card may have said one more).
function CornerShopLogic.stateFromView(
	stock: SharedTypes.CornerShopStock
): SharedTypes.CornerShopState
	local bought: { [string]: number } = {}
	local today: { [string]: number } = {}
	for _, item in stock.stock do
		bought[item.itemId] = item.bought or 0
		local row = Catalog.cornerShopById[item.itemId]
		local limit = if row then CornerShop.perDay(row.family) else nil
		local leftToday: number? = (item :: any).leftToday
		if limit ~= nil and type(leftToday) == "number" then
			today[item.itemId] = math.max(0, limit - leftToday)
		elseif limit ~= nil and item.outToday then
			today[item.itemId] = limit
		end
	end
	return {
		window = stock.window,
		bought = bought,
		day = 0,
		today = today,
		foodXpToday = stock.snackXp or 0,
	}
end

export type BuyAll = {
	count: number, -- items it buys
	of: number, -- items the section has for this player with no coin limit (the tier, stock, daily limits, Bag)
	total: number,
	after: number,
	list: string, -- "2 Money Potion · 1 Lucky Potion", best first
	partial: string?, -- "You can afford 3 of 5. The best go first." when coins stop it short
}

local function units(plan: { CornerShop.PlanItem }): number
	local n = 0
	for _, item in plan do
		n += item.count
	end
	return n
end

-- #3915: whether the view shows any top shelf row (the server leaves them out while the shelf is shut).
function CornerShopLogic.topShelfShown(stock: SharedTypes.CornerShopStock): boolean
	for _, item in stock.stock do
		local row = Catalog.cornerShopById[item.itemId]
		if row ~= nil and row.topShelf == true then
			return true
		end
	end
	return false
end

-- #2593: what Buy all on the `kind` section ("potion", "food" or "bait") takes for `coins`, or nil when nothing fits.
-- The same CornerShop.planAll the server runs (BuyCornerShopAll), so the card shows what it buys.
function CornerShopLogic.buyAll(
	stock: SharedTypes.CornerShopStock?,
	kind: string,
	tier: number,
	coins: number,
	held: CornerShop.Held
): BuyAll?
	if stock == nil then
		return nil
	end
	local state = CornerShopLogic.stateFromView(stock)
	-- #3915: the server's Buy all takes the top shelf while it is open, and the view sends its rows only then, so the
	-- card plans with the shelf open exactly when one of its rows is shown
	CornerShop.setTopShelf(CornerShopLogic.topShelfShown(stock))
	local plan, total = CornerShop.planAll(state, stock.window, kind, tier, coins, held)
	local count = units(plan)
	if count == 0 then
		return nil
	end
	local all = units((CornerShop.planAll(state, stock.window, kind, tier, math.huge, held)))
	local parts: { string } = {}
	for _, item in plan do
		local row = Catalog.cornerShopById[item.itemId]
		table.insert(parts, ("%d %s"):format(item.count, if row then row.name else item.itemId))
	end
	local of = math.max(all, count)
	return {
		count = count,
		of = of,
		total = total,
		after = math.max(0, coins - total),
		list = table.concat(parts, " · "),
		partial = if count < of
			then ("You can afford %d of %d. The best go first."):format(count, of)
			else nil,
	}
end

return CornerShopLogic
