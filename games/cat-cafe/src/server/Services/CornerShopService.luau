--!strict
-- The Corner Shop on the server (corner-shop.md, #1052; v2 corner-shop-v2.md, #1180 and #1181; the rules are
-- shared/CornerShop). A coins-only stall tagged CornerShop in the Town Square, open day and night.
--   BuyCornerShop(itemId, window)  C -> S  2 a second: within CornerShopRange of a stall, then CornerShop.buyBlocker
--     (the tier gate, the current window, the window's amount, the family's daily limit, the food XP cap, the coins).
--     It charges the row's fixed price (sink "corner_shop", event corner_shop_buy) and gives the item: a potion into
--     the bag, food into the Bag's catFood (fed later with FeedCat; no cat pick), or a show over the buyer's cafe.
--     Arguments a v1 window still sends after `window` are ignored. Every buy, bought or refused, answers
--     CornerShopStock; a refusal toasts why.
--   CornerShopStock(stock)  S -> C: on join, at each new window, after every buy.
--   CafeShow(userId, showId, endsAt)  S -> all: one show at a time a cafe, so a bought show starts when the last one
--     ends, and at most SHOW_QUEUE_MAX are held (one playing, one waiting); a joiner gets every show still running
--     or waiting. Kept in memory: a show is a moment, not a save.
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
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)

local CornerShopService = {}

type Show = { showId: string, endsAt: number }

local SHOW_QUEUE_MAX = 2 -- shows a cafe holds at once: the one playing and the next

local sentWindow: { [Player]: number } = {} -- the window each player's last CornerShopStock was for
local shows: { [number]: { Show } } = {} -- each cafe owner's shows still running or waiting, in order

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
	local stock = CornerShop.view(state, window)
	Net.fire(player, "CornerShopStock", stock)
end

-- The shows of `userId` still running or waiting at `now`, the ended ones dropped.
local function liveShows(userId: number, now: number): { Show }
	local list: { Show } = shows[userId] or {}
	local live: { Show } = {}
	for _, show in list do
		if show.endsAt > now then
			table.insert(live, show)
		end
	end
	if #live > 0 then
		shows[userId] = live
	else
		shows[userId] = nil
	end
	return live
end

-- Queues a show over the buyer's cafe after the last one and tells everyone. Returns when it ends.
local function startShow(player: Player, row: Types.CornerShopRow): number
	local now = os.time()
	local live = liveShows(player.UserId, now)
	local startsAt = if #live > 0 then live[#live].endsAt else now
	local show: Show = { showId = row.showId :: string, endsAt = startsAt + (row.showSeconds or 0) }
	table.insert(live, show)
	shows[player.UserId] = live
	Net.fireAll("CafeShow", player.UserId, show.showId, show.endsAt)
	return show.endsAt
end

local function onBuy(player: Player, rawItemId: unknown, rawWindow: unknown)
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
	local blocker = CornerShop.buyBlocker(state, {
		itemId = itemId,
		seenWindow = seenWindow,
		tier = Economy.tier(profile),
		coins = profile.coins,
		foodHeld = if foodId ~= nil then profile.catFood[foodId] or 0 else 0,
	}, window)
	if blocker ~= nil then
		refuse(blocker)
		return
	end
	-- review: the running show plus one waiting at most, so a cafe's queue never runs on for many minutes
	if row.kind == "show" and #liveShows(player.UserId, os.time()) >= SHOW_QUEUE_MAX then
		refuse("A show is already waiting over your cafe. Try again after it starts.")
		return
	end
	if not Economy.trySpend(profile, row.price) then
		refuse("Not enough coins")
		return
	end
	Telemetry.sink(player, profile, row.price, "Shop", "corner_shop")
	Telemetry.custom(
		player,
		"corner_shop_buy",
		row.price,
		{ itemId, tostring(Economy.tier(profile)), row.size }
	)
	CornerShop.record(state, itemId)
	if row.kind == "potion" then
		local potionId = row.potionId :: string
		profile.potions[potionId] = (profile.potions[potionId] or 0) + 1
		Net.toast(player, string.format("A %s went into your bag", row.name), "good")
	elseif row.kind == "food" and foodId ~= nil then
		profile.catFood[foodId] = (profile.catFood[foodId] or 0) + 1
		Net.toast(player, string.format("A %s went into your Bag", row.name), "good")
	elseif row.kind == "show" then
		local endsAt = startShow(player, row)
		local waits = endsAt - (row.showSeconds or 0) > os.time()
		Net.toast(
			player,
			if waits
				then string.format("%s next, after the show over your cafe", row.name)
				else string.format("%s over your cafe!", row.name),
			"good"
		)
	end
	send(player, profile)
	CafeService.sync(player)
end

function CornerShopService.start()
	Net.on("BuyCornerShop", onBuy)
	DataService.onLoaded:Connect(function(player: Player, profile: Types.PlayerProfile)
		send(player, profile)
		local now = os.time()
		for userId in shows do
			for _, show in liveShows(userId, now) do
				Net.fire(player, "CafeShow", userId, show.showId, show.endsAt)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		sentWindow[player] = nil
		shows[player.UserId] = nil -- their cafe empties, so its shows end with it
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
