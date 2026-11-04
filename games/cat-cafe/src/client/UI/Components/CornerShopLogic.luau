--!strict
-- The Corner Shop window's words and rules (#1052, corner-shop.md section 4), kept pure so the cloud tests can load
-- it (no Theme). Screens/CornerShop draws them. The server decides every buy (shared/CornerShop.buyBlocker); these
-- only grey a button the server would refuse anyway and say why.
--
--   clock(restocksAt, now)        "Restocks in 3:12"
--   chance(itemId)                "In stock 9 times in 10", "Always in stock"
--   stockLine(item)               "x2 left", "You bought 2", "None this time"
--   button(item, row, coins, room) the Buy button's words and whether it can be pressed
--   snackLine(snackXp)            "Snacks today: 4,800 / 12,000 XP"
--   effect(row)                   what the row does, in a line
--   catsByLevel(cats)             the snack's cat picker, highest level first

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShortNumber = require(script.Parent.ShortNumber)

local Shared = ReplicatedStorage:WaitForChild("Shared")
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

-- How often the row is in stock, from Config.CornerShopAmountWeights (index 1 is the chance of none), in tenths.
function CornerShopLogic.chance(itemId: string): string
	local weights: { number }? = (Config.CornerShopAmountWeights or {})[itemId]
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
	return ("In stock %d times in 10"):format(tenths)
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

-- The Buy button: "None", "Sold out", "Snacks full", else "Buy · $1.2K", greyed when the coins fall short.
function CornerShopLogic.button(item: Item, row: Row?, coins: number, snackRoom: number): ButtonView
	if item.amount <= 0 then
		return { text = "None", enabled = false }
	end
	if item.bought >= item.amount then
		return { text = "Sold out", enabled = false }
	end
	if row and row.kind == "snack" and (row.xp or 0) > snackRoom then
		return { text = "Snacks full", enabled = false }
	end
	return { text = "Buy · " .. money(item.price), enabled = coins >= item.price }
end

function CornerShopLogic.snackRoom(snackXp: number): number
	return math.max(0, (Config.CornerSnackXpPerDay or 0) - snackXp)
end

function CornerShopLogic.snackLine(snackXp: number): string
	return ("Snacks today: %s / %s XP"):format(
		commas(snackXp),
		commas(Config.CornerSnackXpPerDay or 0)
	)
end

-- What a row does (corner-shop.md section 2), in one short line.
function CornerShopLogic.effect(row: Row): string
	if row.kind == "potion" then
		return "Walk faster for 5 min, into your potion bag"
	elseif row.kind == "snack" then
		return ("+%s XP for one of your cats"):format(commas(row.xp or 0))
	end
	local seconds = row.showSeconds or 0
	local length = if seconds >= 60
		then ("%d min"):format(seconds // 60)
		else ("%d s"):format(seconds)
	if row.showId == "fireworks" then
		return ("A %s firework show over your cafe"):format(length)
	end
	return ("Bubbles from your cafe's door for %s"):format(length)
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
			table.insert(out, {
				uid = uid,
				catId = cat.catId,
				name = if type(cat.name) == "string" then cat.name else (names or {})[cat.catId],
				level = if type(cat.level) == "number" then cat.level else 1,
			})
		end
	end
	table.sort(out, function(a, b)
		if a.level ~= b.level then
			return a.level > b.level
		end
		local an, bn = a.name or a.catId, b.name or b.catId
		if an ~= bn then
			return an < bn
		end
		return a.uid < b.uid
	end)
	return out
end

return CornerShopLogic
