--!strict
-- The Corner Shop window's words and rules (#1052, corner-shop.md section 4), kept pure so the cloud tests can load
-- it (no Theme). Screens/CornerShop draws them. The server decides every buy (shared/CornerShop.buyBlocker); these
-- only grey a button the server would refuse anyway and say why.
--
--   clock(restocksAt, now)        "Restocks in 3:12"
--   chance(itemId)                "In stock 9 times in 10", "Always in stock"
--   stockLine(item)               "x2 left", "You bought 2", "None this time"
--   button(item, row, coins, room) the Buy button's words and whether it can be pressed
--   snackLine(snackXp)            "" (#1255: no daily cat food cap any more)
--   effect(row)                   what the row does, in a line
--   catsByLevel(cats)             the snack's cat picker, highest level first

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShortNumber = require(script.Parent.ShortNumber)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Config = require(Shared:WaitForChild("Config")) :: any
local SharedTypes = require(Shared:WaitForChild("Types"))

local CornerShopLogic = {}

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

-- How often the row is in stock, from Config.CornerShopSizeWeights by the row's size (corner-shop-v2.md section 1;
-- index 1 is the chance of none), in tenths.
function CornerShopLogic.chance(itemId: string): string
	local row = Catalog.getCornerShopRow(itemId)
	if row == nil then
		return ""
	end
	local weights: { number }? = (Config.CornerShopSizeWeights or {})[row.size]
	if weights == nil then
		return ""
	end
	local total = 0
	for _, weight in weights do
		total += weight
	end
	if total <= 0 then
		return ""
	end
	local none = weights[1] or 0
	if none <= 0 then
		return "Always in stock"
	end
	local tenths = math.floor((1 - none / total) * 10 + 0.5)
	if tenths <= 0 then
		return "Rarely in stock"
	end
	return ("In stock %d %s in 10"):format(tenths, if tenths == 1 then "time" else "times")
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
	if item.amount <= 0 then
		return "None this time"
	end
	local left = item.amount - item.bought
	if left <= 0 then
		return ("You bought %d"):format(item.bought)
	end
	return ("x%d left"):format(left)
end

-- The Buy button, in the server's order (shared/CornerShop.buyBlocker): "Tier 3", "None", "Sold out",
-- "Back tomorrow", "Food full", else "Buy · $1.2K", greyed when the coins fall short. "Back tomorrow" (#1435) is a row
-- whose family hit its daily limit: the server marks it `outToday` and the window never shows the limit itself (#1190).
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
		return { text = "None", enabled = false }
	end
	if item.bought >= item.amount then
		return { text = "Sold out", enabled = false }
	end
	if (item :: any).outToday == true then
		return { text = "Back tomorrow", enabled = false }
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

-- What a row does (corner-shop.md section 2), in one short line.
function CornerShopLogic.effect(row: Row): string
	if row.kind == "potion" then
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

return CornerShopLogic
