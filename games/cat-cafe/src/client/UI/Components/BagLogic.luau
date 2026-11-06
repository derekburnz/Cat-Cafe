--!strict
-- The Bag's words and lists (corner-shop-v2.md section 3, #1181), kept pure so the cloud tests can load them.
-- Screens/Potions draws the Bag: its Potions tab is the potion bag as before, its Cat Food tab these rows.
--
--   foods(defs, have)        the foods the player has, in catalog order: { id, name, xp, count }
--   baits(defs, have)        #1281: the bait foods (lures) the player has, rarest first (#1609, as the bowl lists
--                            them): { id, name, count, def }
--   total(state)             everything in the Bag (potions plus cat food), for the HUD tile's count
--   xpLine(xp)               "+2,000 XP"
--   catLine(level, xp)       "Level 23 · 1,400 XP to 24", or "Level 50 · Max" at the cap
--   canFeed(level)           false at the top level (the server refuses those, FeedCat)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any

local FoodOrder = require(script.Parent.FoodOrder)

local BagLogic = {}

export type Food = { id: string, name: string, xp: number, count: number }

local function commas(n: number): string
	local text = tostring(math.floor(n))
	local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end
BagLogic.commas = commas

function BagLogic.foods(defs: { any }?, have: { [string]: number }?): { Food }
	local out: { Food } = {}
	local owned: { [string]: number } = have or {}
	local list: { any } = defs or {}
	for _, def in list do
		local count = owned[def.id]
		if type(count) == "number" and count >= 1 then
			table.insert(
				out,
				{ id = def.id, name = def.name, xp = def.xp or 0, count = math.floor(count) }
			)
		end
	end
	return out
end

export type Bait = { id: string, name: string, count: number, def: any }

-- #1281 (corner-shop-v2.md section 1b): the Bag's Bait tab lists the bowl foods the player has; they go in at the
-- bowl, so the tab has no Use. #1609 (Derek2 11-05: "sort bait in inventory and bowl menu by rarity"): rarest first,
-- in the bowl's order (Components/FoodOrder).
function BagLogic.baits(defs: { any }?, have: { [string]: number }?): { Bait }
	local out: { Bait } = {}
	local owned: { [string]: number } = have or {}
	local list: { any } = FoodOrder.defs(defs or {}, true)
	for _, def in list do
		local count = owned[def.id]
		if type(count) == "number" and count >= 1 then
			table.insert(
				out,
				{ id = def.id, name = def.name, count = math.floor(count), def = def }
			)
		end
	end
	return out
end

function BagLogic.total(state: any): number
	local sum = 0
	for _, field in { "potions", "catFood" } do
		local found: { [string]: number }? = if type(state) == "table" then state[field] else nil
		local bag: { [string]: number } = found or {}
		for _, count in bag do
			if type(count) == "number" and count > 0 then
				sum += math.floor(count)
			end
		end
	end
	return sum
end

function BagLogic.xpLine(xp: number): string
	return "+" .. commas(xp) .. " XP"
end

local function maxLevel(): number
	return Config.CatMaxLevel or 50
end

function BagLogic.canFeed(level: number): boolean
	return level < maxLevel()
end

-- #1773: the feed card's bar, how far the cat is toward its next level (0 to 1); 1 at the top level.
function BagLogic.xpFraction(level: number, xp: number?): number
	if level >= maxLevel() then
		return 1
	end
	local need = (Config.CatXpBase or 0) * math.max(1, math.floor(level))
	return if need > 0 then math.clamp((xp or 0) / need, 0, 1) else 0
end

-- XP from `level` to the next, as CatStats.xpToNext counts it (Config.CatXpBase per level).
function BagLogic.catLine(level: number, xp: number?): string
	if level >= maxLevel() then
		return ("Level %d · Max"):format(level)
	end
	local need = (Config.CatXpBase or 0) * math.max(1, math.floor(level))
	local left = math.max(0, math.ceil(need - (xp or 0)))
	return ("Level %d · %s XP to %d"):format(level, commas(left), level + 1)
end

return BagLogic
