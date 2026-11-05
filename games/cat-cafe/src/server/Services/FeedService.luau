--!strict
-- Feeding cat food from the Bag (#1181, corner-shop-v2.md sections 3 and 4). Food bought at the Corner Shop or earned
-- waits in profile.catFood; FeedCat gives one to a cat whenever the player likes, from the Bag or the cat's card.
--   FeedCat(foodId, catUid)  C -> S  4 a second: a known food the player has at least one of, and one of the
--     player's own cats below CatMaxLevel (a cat at the top level would waste it). It takes one, adds the food's XP
--     through CatStats.addXp (level ups count in stats.catLevelUps, and CafeService.sync shows them), and answers
--     FeedResult(catUid, level, xp) and a ProfileSync. A refusal toasts why. There is no feeding cap: only buying
--     food is capped a day (CornerFoodXpPerDay), so earned food is never stuck.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CafeService = require(script.Parent.CafeService)
local CatStats = require(ReplicatedStorage.Shared.CatStats)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Guard = require(script.Parent.Parent.Util.Guard)
local Net = require(script.Parent.Net)
local Telemetry = require(script.Parent.Telemetry)

local FeedService = {}

local function commas(n: number): string
	local text = tostring(math.floor(n))
	local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return if out:sub(1, 1) == "," then out:sub(2) else out
end

local function onFeedCat(player: Player, rawFoodId: unknown, rawCatUid: unknown)
	local foodId, catUid = Guard.id(rawFoodId), Guard.id(rawCatUid)
	local profile = DataService.get(player)
	if foodId == nil or catUid == nil or profile == nil then
		return
	end
	local food = Catalog.getCatFood(foodId)
	local cat = profile.cats[catUid]
	if food == nil or cat == nil then
		return -- a forged or stale call: the Bag only offers the player's own foods and cats
	end
	local held = profile.catFood[foodId] or 0
	if held <= 0 then
		Net.toast(player, string.format("No %s left in your Bag", food.name), "warn")
		return
	end
	if CatStats.level(cat) >= Config.CatMaxLevel then
		Net.toast(player, "That cat is already at the top level", "warn")
		return
	end
	if held > 1 then
		profile.catFood[foodId] = held - 1
	else
		profile.catFood[foodId] = nil
	end
	local gained = CatStats.addXp(cat, food.xp)
	if gained > 0 then
		profile.stats.catLevelUps = (profile.stats.catLevelUps or 0) + gained
	end
	Telemetry.custom(player, "cat_fed", food.xp, { foodId })
	-- the catalog name: a typed name is filtered only where it is shown (CafeService), never in a toast
	local def = Catalog.getCat(cat.catId)
	local name = if def ~= nil then def.name else "Your cat"
	Net.toast(
		player,
		string.format("%s loved the %s: +%s XP", name, food.name, commas(food.xp)),
		"good"
	)
	Net.fire(player, "FeedResult", catUid, CatStats.level(cat), CatStats.xp(cat))
	CafeService.sync(player)
end

function FeedService.start()
	Net.on("FeedCat", onFeedCat)
end

return FeedService
