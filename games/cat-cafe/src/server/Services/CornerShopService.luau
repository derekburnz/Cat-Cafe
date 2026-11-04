--!strict
-- The Corner Shop on the server (corner-shop.md, #1052; the rules are shared/CornerShop). A coins-only stall tagged
-- CornerShop in the Town Square, open day and night.
--   BuyCornerShop(itemId, window, shownPrice, catUid?)  C -> S  2 a second: within CornerShopRange of a stall, the
--     current window, fewer bought than the window stocks, the server's price (Economy.cornerPrice of the day rate)
--     not above `shownPrice`, the coins; a snack's catUid one of the player's cats and its XP within today's cap. It
--     charges the server's price (sink "corner_shop", event corner_shop_buy) and gives the item: a potion into the
--     bag, the snack's XP to that cat (a level up shows through CafeService.sync), or a show over the buyer's cafe.
--     Every buy, bought or refused, answers CornerShopStock; a refusal toasts why.
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
local CatStats = require(ReplicatedStorage.Shared.CatStats)
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
	local stock = CornerShop.view(state, window, Economy.incomePerSecond(profile))
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
	shows[userId] = if #live > 0 then live else nil
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

-- The cat `rawUid` names, if it is one of the player's.
local function ownCat(profile: Types.PlayerProfile, rawUid: unknown): Types.CatInstance?
	if rawUid == nil then
		return nil
	end
	local uid = Guard.id(rawUid)
	return if uid ~= nil then profile.cats[uid] else nil
end

local function onBuy(
	player: Player,
	rawItemId: unknown,
	rawWindow: unknown,
	rawShownPrice: unknown,
	rawCatUid: unknown
)
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
	local shownPrice = Guard.int(rawShownPrice, 0, 2 ^ 53)
	if itemId == nil or seenWindow == nil or shownPrice == nil then
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
	local price = Economy.cornerPrice(row, Economy.incomePerSecond(profile))
	local cat = if row.kind == "snack" then ownCat(profile, rawCatUid) else nil
	local blocker = CornerShop.buyBlocker(state, {
		itemId = itemId,
		seenWindow = seenWindow,
		shownPrice = shownPrice,
		ownsCat = row.kind ~= "snack" or cat ~= nil,
	}, window, price, profile.coins)
	if blocker ~= nil then
		refuse(blocker)
		return
	end
	-- review: the running show plus one waiting at most, so a cafe's queue never runs on for many minutes
	if row.kind == "show" and #liveShows(player.UserId, os.time()) >= SHOW_QUEUE_MAX then
		refuse("A show is already waiting over your cafe. Try again after it starts.")
		return
	end
	if not Economy.trySpend(profile, price) then
		refuse("Not enough coins")
		return
	end
	Telemetry.sink(player, profile, price, "Shop", "corner_shop")
	Telemetry.custom(player, "corner_shop_buy", price, { itemId, tostring(Economy.tier(profile)) })
	state.bought[itemId] = (state.bought[itemId] or 0) + 1
	if row.kind == "potion" then
		local potionId = row.potionId :: string
		profile.potions[potionId] = (profile.potions[potionId] or 0) + 1
		Net.toast(player, string.format("A %s went into your bag", row.name), "good")
	elseif row.kind == "snack" and cat ~= nil then
		local xp = row.xp or 0
		state.snackXp += xp
		local gained = CatStats.addXp(cat, xp)
		if gained > 0 then
			profile.stats.catLevelUps = (profile.stats.catLevelUps or 0) + gained
		end
		-- the catalog name: a typed name is filtered only where it is shown (CafeService), never in a toast
		local def = Catalog.getCat(cat.catId)
		local name = if def ~= nil then def.name else "Your cat"
		Net.toast(player, string.format("%s loved the %s: +%d XP", name, row.name, xp), "good")
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
