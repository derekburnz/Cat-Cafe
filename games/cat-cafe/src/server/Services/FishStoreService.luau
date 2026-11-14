--!strict
-- #4055 (shared/FishStore): BuyWithFish(key, shownPrice) buys one Store pass with golden fish. Refused while the
-- fishStore switch is off, for an unknown key, a pass not made, one already owned (by Robux or fish), during a trade
-- that holds fish, or with too few fish. On success the fish are spent, the key is saved in profile.fishBought and
-- PassService.grantFish makes the pass count as owned at once, exactly as the Robux pass would. From anywhere (the
-- Store is a menu), 1 a second (Net's limiter).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Economy)
local FishStore = require(ReplicatedStorage.Shared.FishStore)
local GoldenFish = require(ReplicatedStorage.Shared.GoldenFish)
local Guard = require(ReplicatedStorage.Shared.Guard)

local CafeService = require(script.Parent.CafeService)
local DataService = require(script.Parent.DataService)
local LiveFlagService = require(script.Parent.LiveFlagService)
local Net = require(script.Parent.Net)
local PassService = require(script.Parent.PassService)
local Telemetry = require(script.Parent.Telemetry)
local TradeService = require(script.Parent.TradeService)

local FishStoreService = {}

local MAX_PRICE = 1000000

local function onBuy(player: Player, rawKey: unknown, rawShown: unknown)
	local key = Guard.id(rawKey)
	local shown = Guard.int(rawShown, 0, MAX_PRICE)
	local profile = DataService.get(player)
	if key == nil or shown == nil or profile == nil or not LiveFlagService.on(FishStore.FLAG) then
		return
	end
	local item = FishStore.item(key)
	if item == nil then
		return
	end
	local function refuse(reason: string)
		Net.toast(player, reason, "warn")
		CafeService.sync(player) -- the Store redraws from the server's view
	end
	local price = FishStore.price(item)
	if price > shown then
		refuse("The price changed, have a look again")
		return
	end
	local id = FishStore.passId(item)
	local reason = FishStore.blocker(profile, item, PassService.owns(player, id))
		or TradeService.fishSpendBlocker(player)
	if reason ~= nil then
		refuse(reason)
		return
	end
	local fishBefore = profile.goldenFish
	if not GoldenFish.trySpend(profile, price) then
		refuse("Not enough golden fish yet")
		return
	end
	profile.fishBought[item.key] = true
	PassService.grantFish(player, id) -- fires `changed`: the cafe, its look and the pass decor update and sync
	Telemetry.fishSink(player, profile, price, "Shop", "fishstore_" .. item.key)
	Telemetry.custom(
		player,
		"fishstore_buy",
		fishBefore,
		{ item.key, "T" .. tostring(Economy.tier(profile)) }
	)
	Net.toast(player, string.format("%s, yours forever!", item.name), "good")
	CafeService.sync(player)
end

function FishStoreService.start()
	Net.on("BuyWithFish", onBuy)
end

return FishStoreService
