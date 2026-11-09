--!strict
-- The Corner Shop on the server (corner-shop.md, #1052; v2 corner-shop-v2.md, #1180 and #1181; the rules are
-- shared/CornerShop). A coins-only stall tagged CornerShop in the Town Square, open day and night.
--   BuyCornerShop(itemId, window)  C -> S  2 a second: within CornerShopRange of a stall, then CornerShop.buyBlocker
--     (the tier gate, the current window, the window's amount, the family's daily limit, the food XP cap, the coins).
--     It charges the row's fixed price (sink "corner_shop", event corner_shop_buy) and gives the item: a potion into
--     the bag, or food into the Bag's catFood (fed later with FeedCat; no cat pick). The cafe shows (the Bubble
--     Machine and Cafe Fireworks) are gone from the game (#1381).
--   BuyCornerShop(itemId, window, shownPrice?): #1281 (section 1b) a "bait" row gives its food into `lures` at
--     Economy.foodPrice for the player's tier, up to CornerShop.LURE_MAX held, and refuses when that price is above
--     `shownPrice` (the window showed an older one). Other rows ignore shownPrice; a later catUid is ignored. Every buy, bought or refused, answers
--     CornerShopStock; a refusal toasts why.
--   BuyCornerShopAll(kind, window)  C -> S  #2593, 1 every 2 s: a section's Buy all (CornerShop.planAll), each one
--     through the same checks; one toast and one CornerShopStock.
--   CornerShopStock(stock)  S -> C: on join, at each new window, after every buy.
-- Nothing here is random, sold for golden fish or Robux, or raises income (corner-shop.md section 3).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CafeService = require(script.Parent.CafeService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local ClockService = require(script.Parent.ClockService)
local Config = require(ReplicatedStorage.Shared.Config)
local CornerShop = require(ReplicatedStorage.Shared.CornerShop)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Guard = require(script.Parent.Parent.Util.Guard)
local Net = require(script.Parent.Net)
local ShortNumber = require(ReplicatedStorage.Shared.ShortNumber)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)

local CornerShopService = {}

local sentWindow: { [Player]: number } = {} -- the window each player's last CornerShopStock was for

local function nearStall(player: Player): boolean
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	local position = (root :: BasePart).Position
	for _, instance in CollectionService:GetTagged(CornerShop.TAG) do
		if
			instance:IsA("Model")
			and instance:IsDescendantOf(Workspace)
			and (instance:GetPivot().Position - position).Magnitude <= Config.CornerShopRange
		then
			return true
		end
	end
	return false
end

-- The player's state refreshed for now, and the window.
local function refreshed(profile: Types.PlayerProfile): (Types.CornerShopState, number)
	local now = os.time()
	local window = CornerShop.window(now)
	CornerShop.refresh(profile.cornerShop, window, CornerShop.day(now))
	return profile.cornerShop, window
end

local function send(player: Player, profile: Types.PlayerProfile)
	local state, window = refreshed(profile)
	sentWindow[player] = window
	local stock = CornerShop.view(state, window, Economy.tier(profile))
	Net.fire(player, "CornerShopStock", stock)
end

local function onBuy(player: Player, rawItemId: unknown, rawWindow: unknown, rawShownPrice: unknown)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	local function refuse(text: string)
		Net.toast(player, text, "warn")
		send(player, profile)
	end
	local itemId = Guard.id(rawItemId)
	local seenWindow = Guard.int(rawWindow, 0, 2 ^ 40)
	-- nil, or not a whole number of coins (a v1 window's), checks no shown price
	local shownPrice = Guard.int(rawShownPrice, 0, 2 ^ 53)
	if itemId == nil or seenWindow == nil then
		send(player, profile)
		return
	end
	if not nearStall(player) then
		refuse("Walk up to the Corner Shop first")
		return
	end
	local row = Catalog.getCornerShopRow(itemId)
	if row == nil then
		refuse("That isn't in the Corner Shop.")
		return
	end
	Economy.settle(profile, os.time(), ClockService.epoch())
	local state, window = refreshed(profile)
	local foodId = row.foodId
	local lureId = row.lureId
	local tier = Economy.tier(profile)
	local blocker = CornerShop.buyBlocker(state, {
		itemId = itemId,
		seenWindow = seenWindow,
		tier = tier,
		coins = profile.coins,
		foodHeld = if foodId ~= nil then profile.catFood[foodId] or 0 else 0,
		lureHeld = if lureId ~= nil then profile.lures[lureId] or 0 else nil,
		shownPrice = shownPrice,
	}, window)
	if blocker ~= nil then
		refuse(blocker)
		return
	end
	local price = CornerShop.priceOf(row, tier)
	if not Economy.trySpend(profile, price) then
		refuse("Not enough coins")
		return
	end
	Telemetry.sink(player, profile, price, "Shop", if lureId ~= nil then lureId else "corner_shop")
	Telemetry.custom(player, "corner_shop_buy", price, { itemId, tostring(tier), row.size })
	CornerShop.record(state, itemId)
	if row.kind == "potion" then
		local potionId = row.potionId :: string
		profile.potions[potionId] = (profile.potions[potionId] or 0) + 1
		Net.toast(player, string.format("A %s went into your bag", row.name), "good")
	elseif row.kind == "food" and foodId ~= nil then
		profile.catFood[foodId] = (profile.catFood[foodId] or 0) + 1
		Net.toast(player, string.format("A %s went into your Bag", row.name), "good")
	elseif row.kind == "bait" and lureId ~= nil then
		profile.lures[lureId] = (profile.lures[lureId] or 0) + 1
		Net.toast(player, string.format("Bought %s (%d)", row.name, profile.lures[lureId]), "good")
	end
	send(player, profile)
	CafeService.sync(player)
end

local KINDS = { potion = true, food = true, bait = true }

-- #2593: Buy all for one section of the Day Cart. The stall's range and the window as one buy, then the server's own
-- CornerShop.planAll of this player's state, tier, coins and Bag, each one bought through CornerShop.buyBlocker,
-- priceOf and record as BuyCornerShop does; one toast and one CornerShopStock.
local function onBuyAll(player: Player, rawKind: unknown, rawWindow: unknown)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	local function refuse(text: string)
		Net.toast(player, text, "warn")
		send(player, profile)
	end
	local kind = if type(rawKind) == "string" and KINDS[rawKind] then rawKind else nil
	local seenWindow = Guard.int(rawWindow, 0, 2 ^ 40)
	if kind == nil or seenWindow == nil then
		send(player, profile)
		return
	end
	if not nearStall(player) then
		refuse("Walk up to the Corner Shop first")
		return
	end
	Economy.settle(profile, os.time(), ClockService.epoch())
	local state, window = refreshed(profile)
	if seenWindow ~= window then
		refuse("The Corner Shop just restocked. Take another look.")
		return
	end
	local tier = Economy.tier(profile)
	local plan = CornerShop.planAll(
		state,
		window,
		kind,
		tier,
		profile.coins,
		{ catFood = profile.catFood, lures = profile.lures }
	)
	local count, spent = 0, 0
	for _, item in plan do
		local row = Catalog.getCornerShopRow(item.itemId)
		if row == nil then
			continue
		end
		local foodId, lureId = row.foodId, row.lureId
		for _ = 1, item.count do
			local blocker = CornerShop.buyBlocker(state, {
				itemId = row.id,
				seenWindow = window,
				tier = tier,
				coins = profile.coins,
				foodHeld = if foodId ~= nil then profile.catFood[foodId] or 0 else 0,
				lureHeld = if lureId ~= nil then profile.lures[lureId] or 0 else nil,
			}, window)
			local price = CornerShop.priceOf(row, tier)
			if blocker ~= nil or not Economy.trySpend(profile, price) then
				break
			end
			Telemetry.sink(
				player,
				profile,
				price,
				"Shop",
				if lureId ~= nil then lureId else "corner_shop"
			)
			Telemetry.custom(player, "corner_shop_buy", price, { row.id, tostring(tier), row.size })
			CornerShop.record(state, row.id)
			if row.kind == "potion" then
				local potionId = row.potionId :: string
				profile.potions[potionId] = (profile.potions[potionId] or 0) + 1
			elseif row.kind == "food" and foodId ~= nil then
				profile.catFood[foodId] = (profile.catFood[foodId] or 0) + 1
			elseif row.kind == "bait" and lureId ~= nil then
				profile.lures[lureId] = (profile.lures[lureId] or 0) + 1
			end
			count += 1
			spent += price
		end
	end
	if count == 0 then
		refuse("Not enough coins")
		return
	end
	Net.toast(
		player,
		string.format(
			"Bought %d %s for $%s",
			count,
			if count == 1 then "item" else "items",
			ShortNumber.format(spent)
		),
		"good"
	)
	send(player, profile)
	CafeService.sync(player)
end

function CornerShopService.start()
	Net.on("BuyCornerShop", onBuy)
	Net.on("BuyCornerShopAll", onBuyAll) -- #2593
	DataService.onLoaded:Connect(function(player: Player, profile: Types.PlayerProfile)
		send(player, profile)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		sentWindow[player] = nil
	end)
	-- A new window restocks everyone's shop; one check a second catches the edge.
	task.spawn(function()
		while true do
			task.wait(1)
			local window = CornerShop.window(os.time())
			for _, player in DataService.loadedPlayers() do
				local profile = DataService.get(player)
				if profile ~= nil and sentWindow[player] ~= window then
					send(player, profile)
				end
			end
		end
	end)
end

return CornerShopService
