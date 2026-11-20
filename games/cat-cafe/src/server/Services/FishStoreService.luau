--!strict
-- #4055 (shared/FishStore): BuyWithFish(key, shownPrice) buys one Store pass with golden fish. Refused while the
-- fishStore switch is off, for an unknown key or one whose own switch is off (#4610: the Auto Bowl), a pass not made, one already owned (by Robux or fish), during a trade
-- that holds fish, or with too few fish. On success the fish are spent, the key is saved in profile.fishBought and
-- PassService.grantFish makes the pass count as owned at once, exactly as the Robux pass would. From anywhere (the
-- Store is a menu), 1 a second (Net's limiter).

-- #4610 part 2: the key can also name a FishStore.PRODUCTS product (the Thank You Badge, the Cafe Pass). Then the
-- fish are spent and the product is given by the receipt's own function, and refunded if that gives nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CafePass = require(ReplicatedStorage.Shared.CafePass)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Economy = require(ReplicatedStorage.Shared.Economy)
local FishStore = require(ReplicatedStorage.Shared.FishStore)
local GoldenFish = require(ReplicatedStorage.Shared.GoldenFish)

local CafePassService = require(script.Parent.CafePassService)
local CafeService = require(script.Parent.CafeService)
local DataService = require(script.Parent.DataService)
local Guard = require(script.Parent.Parent.Util.Guard)
local LiveFlagService = require(script.Parent.LiveFlagService)
local Net = require(script.Parent.Net)
local PassService = require(script.Parent.PassService)
local ProductService = require(script.Parent.ProductService)
local Telemetry = require(script.Parent.Telemetry)
local TradeService = require(script.Parent.TradeService)

local FishStoreService = {}

local MAX_PRICE = 1000000

local function refuse(player: Player, reason: string)
	Net.toast(player, reason, "warn")
	CafeService.sync(player) -- the Store redraws from the server's view
end

-- #4610 part 2: a product bought with fish. The fish go first and come back (to the wallet only, never the lifetime
-- count) if the product's own grant gives nothing.
local function buyProduct(player: Player, profile: any, product: FishStore.Product, shown: number)
	local price = FishStore.price(product)
	if price > shown then
		refuse(player, "The price changed, have a look again")
		return
	end
	local season, _, endsAt = CafePass.seasonAt(os.time(), RunService:IsStudio())
	local reason = FishStore.productBlocker(
		profile,
		product,
		season,
		CafePass.saleOpen(os.time(), endsAt)
	) or TradeService.fishSpendBlocker(player)
	local def = Catalog.getProduct(product.productId)
	if reason == nil and def == nil then
		reason = "Coming soon"
	end
	if reason ~= nil or def == nil then
		refuse(player, reason or "Coming soon")
		return
	end
	local fishBefore = profile.goldenFish
	if not GoldenFish.trySpend(profile, price) then
		refuse(player, "Not enough golden fish yet")
		return
	end
	local given = false
	if product.once == "season" then
		given = CafePassService.buyPaid(player, profile)
		if given then
			Net.toast(player, "The Cafe Pass paid track is yours this season!", "good")
			CafePassService.send(player, profile)
		end
	else
		local result = ProductService.give(player, profile, def, "fish_" .. def.id, "Yours! ")
		given = not result.undone
	end
	if not given then
		profile.goldenFish += price
		refuse(player, "That didn't go through, your fish are back")
		return
	end
	Telemetry.fishSink(player, profile, price, "Shop", "fishstore_" .. product.key)
	Telemetry.custom(
		player,
		"fishstore_buy",
		fishBefore,
		{ product.key, "T" .. tostring(Economy.tier(profile)) }
	)
	CafeService.sync(player)
end

local function onBuy(player: Player, rawKey: unknown, rawShown: unknown)
	local key = Guard.id(rawKey)
	local shown = Guard.int(rawShown, 0, MAX_PRICE)
	local profile = DataService.get(player)
	if key == nil or shown == nil or profile == nil then
		return
	end
	local product = FishStore.product(key)
	if product ~= nil then
		buyProduct(player, profile, product, shown)
		return
	end
	local item = FishStore.item(key)
	if item == nil or (item.flag ~= nil and not LiveFlagService.on(item.flag)) then
		return
	end
	-- bowlAutoFree (Derek 2026-11-20): Auto refill and Auto claim are free, so the Auto Bowl pass is never sold
	local itemKey: string = item.key -- a plain string, so the check does not narrow item.key below
	if itemKey == "autoBowl" and LiveFlagService.on("bowlAutoFree") then
		return
	end
	local price = FishStore.price(item)
	if price > shown then
		refuse(player, "The price changed, have a look again")
		return
	end
	local id = FishStore.passId(item)
	local reason = FishStore.blocker(profile, item, PassService.owns(player, id))
		or TradeService.fishSpendBlocker(player)
	if reason ~= nil then
		refuse(player, reason)
		return
	end
	local fishBefore = profile.goldenFish
	if not GoldenFish.trySpend(profile, price) then
		refuse(player, "Not enough golden fish yet")
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
