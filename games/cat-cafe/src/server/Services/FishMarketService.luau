--!strict
-- The Golden Fish Market (F53, golden-fish.md sections 3 and 4): a stall in the street plaza tagged FishMarket.
-- OpenCrate(crateId) opens a banked crate, or buys one for its price in golden fish, for a player within
-- FishMarketRange, CrateOpenCooldownSeconds after their last open. The server rolls with its own Random (the lucky
-- twentieth on golden odds), adds the piece or pays its duplicate refund, puts a new furniture or decoration piece on
-- a free decor spot and answers CrateResult(crateId, decorId, duplicate, refund), so leaving mid-reveal keeps the
-- piece. BuyFishItem(itemId) buys a food or a perk level. Every cost comes from Catalog.fishShop and Config, never
-- from the client. Golden fish are earned only: nothing here is sold for Robux (monetization-policy).
-- F94 (rewards-and-shops.md section 3): the Fresh Catch shelf. By day shared/FreshCatch rolls a stock every
-- FreshCatchWindowSeconds, the same on every server, and each player may buy up to its amount of each row in the
-- window with BuyFreshCatch(itemId, window), refused for a window that has rolled over (S42). FreshCatchStock goes to
-- each player whenever their stock or bought counts change (sunrise, a new window, a join), nil at night, and after
-- every buy, bought or not. A window that stocks the Gold Rush Potion or the cheap crate sends one ShopAlert a window
-- to each player by day who has the golden fish for it and has settings.shopAlerts on; the window is saved in
-- profile.freshCatch.alerted, so a rejoin never alerts twice. No alert goes out until settings saves the switch.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CafeService = require(script.Parent.CafeService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local ClockService = require(script.Parent.ClockService)
local Config = require(ReplicatedStorage.Shared.Config)
local Crates = require(ReplicatedStorage.Shared.Crates)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local FreshCatch = require(ReplicatedStorage.Shared.FreshCatch)
local GoldenFish = require(ReplicatedStorage.Shared.GoldenFish)
local Guard = require(script.Parent.Parent.Util.Guard)
local Net = require(script.Parent.Net)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)

local FishMarketService = {}

FishMarketService.TAG = "FishMarket"

local random = Random.new()
local lastOpenAt: { [Player]: number } = {} -- os.clock() of each player's last crate, for the cooldown
local freshSent: { [Player]: string } = {} -- the Fresh Catch stock this player was last sent, so it is not resent
local CLOSED = "closed"

local PERK_NAMES: { [string]: string } = {
	golden_espresso = "Golden Espresso",
	big_bowl = "Big Bowl",
	extra_decor_spot = "Extra Decor Spot",
}

-- Saves a count, leaving a 0 out of the map (crates and crateLuck keep only what is there).
local function setCount(map: { [string]: number }, key: string, n: number)
	if n > 0 then
		map[key] = n
	else
		map[key] = nil
	end
end

-- True when the player stands within FishMarketRange of a Market stall.
local function nearMarket(player: Player): boolean
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	local position = (root :: BasePart).Position
	for _, instance in CollectionService:GetTagged(FishMarketService.TAG) do
		if
			instance:IsA("Model")
			and instance:IsDescendantOf(Workspace)
			and (instance:GetPivot().Position - position).Magnitude <= Config.FishMarketRange
		then
			return true
		end
	end
	return false
end

-- Opens one crate for the player, the checks already passed: takes a banked crate or the price, rolls, pays.
-- Returns the piece, whether it was a duplicate, the refund and whether a new piece went on a decor spot.
local function open(
	player: Player,
	profile: Types.PlayerProfile,
	crate: Types.CrateDef
): (Types.DecorDef, boolean, number, boolean)
	-- roll first (pure), then pay, so an error in the roll never takes the crate or the fish (review N168)
	local luck = profile.crateLuck[crate.area] or 0
	local decorId, lucky = Crates.roll(crate, luck, random:NextNumber(), random:NextNumber())
	local def = Catalog.getDecor(decorId) :: Types.DecorDef
	local rarity: Types.Rarity = def.rarity or "Common"
	local banked = profile.crates[crate.id] or 0
	if banked > 0 then
		setCount(profile.crates, crate.id, banked - 1)
	else
		local price = crate.price :: number
		GoldenFish.trySpend(profile, price)
		Telemetry.fishSink(player, profile, price, "Shop", "crate")
	end
	setCount(profile.crateLuck, crate.area, Crates.luckAfter(luck, rarity))
	profile.stats.cratesOpened += 1

	local duplicate = profile.decorOwned[decorId] == true
	local refund = 0
	local placed = false
	if duplicate then
		refund = Crates.refund(rarity)
		GoldenFish.credit(profile, refund)
		Telemetry.fishSource(player, profile, refund, "Gameplay", "crate_refund")
	else
		profile.decorOwned[decorId] = true
		-- a new furniture or decoration piece takes a free spot by itself; a new wallpaper, floor or paint waits for
		-- the window's "Use it" (ToggleDecor)
		local cap = Crates.spotCap(Economy.tier(profile), profile.fishPerks.extra_decor_spot or 0)
		if
			Crates.takesSpot(def)
			and Crates.spotsUsed(profile, Economy.replacedDecor(profile)) < cap
		then
			profile.decorPlaced[decorId] = true
			placed = true
		end
	end
	-- Analytics keeps three custom fields (review N169): the crate, "<rarity> <kind>" and the outcome, so the odds
	-- can be checked against results.
	local outcome = (if duplicate then "duplicate" else "new") .. (if lucky then " lucky" else "")
	Telemetry.custom(
		player,
		"crate_opened",
		1,
		{ crate.id, rarity .. " " .. (def.kind or "unknown"), outcome }
	)
	return def, duplicate, refund, placed
end

local function onOpenCrate(player: Player, rawCrateId: unknown)
	local crateId = Guard.id(rawCrateId)
	local profile = DataService.get(player)
	if crateId == nil or profile == nil then
		return
	end
	local function refuse(reason: string)
		Net.toast(player, reason, "warn")
		Net.fire(player, "CrateResult", crateId, "", false, 0)
		CafeService.sync(player)
	end
	if not nearMarket(player) then
		refuse("Walk to the Golden Fish Market first")
		return
	end
	local last = lastOpenAt[player]
	if last ~= nil and os.clock() - last < Config.CrateOpenCooldownSeconds then
		refuse("One crate at a time")
		return
	end
	local blocker = Crates.openBlocker(profile, Economy.tier(profile), crateId)
	if blocker ~= nil then
		refuse(blocker)
		return
	end
	lastOpenAt[player] = os.clock()
	local def, duplicate, refund, placed =
		open(player, profile, Catalog.getCrate(crateId) :: Types.CrateDef)
	Net.fire(player, "CrateResult", crateId, def.id, duplicate, refund)
	if placed then
		CafeService.refreshPlot(player)
	end
	CafeService.sync(player)
end

local function onBuyFishItem(player: Player, rawItemId: unknown)
	local itemId = Guard.id(rawItemId)
	local profile = DataService.get(player)
	if itemId == nil or profile == nil then
		return
	end
	local row = Catalog.getFishShopRow(itemId)
	if row == nil then
		return
	end
	if not nearMarket(player) then
		Net.toast(player, "Walk to the Golden Fish Market first", "warn")
		return
	end
	local cost, reason = Crates.buyCost(profile, row)
	if cost == nil or not GoldenFish.trySpend(profile, cost) then
		Net.toast(player, reason or "Not enough golden fish", "warn")
		CafeService.sync(player)
		return
	end
	if row.kind == "lure" then
		profile.lures[itemId] = (profile.lures[itemId] or 0) + 1
		Telemetry.fishSink(player, profile, cost, "Shop", "lure")
		local lure = Catalog.getLure(itemId)
		Net.toast(
			player,
			string.format("Bought a %s", if lure ~= nil then lure.name else itemId),
			"good"
		)
	else
		local level = (profile.fishPerks[itemId] or 0) + 1
		profile.fishPerks[itemId] = level
		Telemetry.fishSink(player, profile, cost, "Shop", "perk")
		Net.toast(
			player,
			string.format("%s level %d, yours forever", PERK_NAMES[itemId] or itemId, level),
			"good"
		)
		if itemId == "big_bowl" then
			-- the next food waits less; a bowl filled since F54 keeps the readyAt UseLure gave it, as with Index
			-- claims, and only an older bowl without one moves up
			CafeService.refreshPlot(player)
		end
	end
	CafeService.sync(player)
end

-- The shown name of a Fresh Catch row: its potion's or its crate's.
local function freshName(row: Types.FreshCatchRow): string
	if row.kind == "potion" then
		local def = Catalog.getPotion(row.potionId or "")
		return if def ~= nil then def.name else row.id
	end
	local def = Catalog.getCrate(row.crateId or "")
	return if def ~= nil then def.name else row.id
end

-- Everyone's Fresh Catch amounts right now, with this player's bought counts of the current window. While this
-- server's window is behind the saved one every row shows as bought out (reviewer N32).
local function freshStockFor(profile: Types.PlayerProfile): Types.FreshCatchStock
	local window = FreshCatch.window(os.time())
	FreshCatch.refresh(profile.freshCatch, window)
	local behind = FreshCatch.behind(profile.freshCatch, window)
	local items: { Types.FreshCatchItem } = {}
	for _, item in FreshCatch.stock(window) do
		local row = Catalog.getFreshCatchRow(item.itemId)
		table.insert(items, {
			itemId = item.itemId,
			fish = if row ~= nil then row.fish else 0,
			amount = item.amount,
			bought = if behind
				then item.amount
				else math.min(profile.freshCatch.bought[item.itemId] or 0, item.amount),
		})
	end
	return { window = window, restocksAt = FreshCatch.restocksAt(window), stock = items }
end

local function freshKey(stock: Types.FreshCatchStock): string
	local parts = { tostring(stock.window) }
	for _, item in stock.stock do
		table.insert(parts, string.format("%s=%d/%d", item.itemId, item.bought, item.amount))
	end
	return table.concat(parts, ":")
end

-- Sends the player's Fresh Catch stock when it differs from what they have, or always with `force`; nil at night.
local function sendFresh(player: Player, force: boolean)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	if ClockService.isNight() then
		if force or freshSent[player] ~= CLOSED then
			freshSent[player] = CLOSED
			Net.fire(player, "FreshCatchStock", nil)
		end
		return
	end
	local stock = freshStockFor(profile)
	local key = freshKey(stock)
	if force or freshSent[player] ~= key then
		freshSent[player] = key
		Net.fire(player, "FreshCatchStock", stock)
	end
end

-- The once a window heads up (section 3): by day, with the switch on, for the first alert row in stock the player
-- can afford. The "Shop alerts" switch is settings.shopAlerts, which shared/Settings saves only once the UI's
-- Settings row for it is in (SettingsList.spec wants a row for every saved key); until then no alert goes out, so
-- nobody gets one they cannot turn off (review S100).
local function alertIfDue(player: Player, profile: Types.PlayerProfile)
	if ClockService.isNight() or not FreshCatch.alertsOn(profile.settings) then
		return
	end
	local window = FreshCatch.window(os.time())
	local row = FreshCatch.alertFor(profile.freshCatch, window, profile.goldenFish)
	if row ~= nil then
		profile.freshCatch.alerted = window
		Net.fire(player, "ShopAlert", row.id)
	end
end

local function onBuyFreshCatch(player: Player, rawItemId: unknown, rawWindow: unknown)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	local function refuse(text: string)
		Net.toast(player, text, "warn")
		sendFresh(player, true)
	end
	local itemId = Guard.id(rawItemId)
	local seenWindow = Guard.int(rawWindow, 0, 2 ^ 40)
	if itemId == nil or seenWindow == nil then
		sendFresh(player, true)
		return
	end
	if ClockService.isNight() then
		refuse("The Fresh Catch is back at sunrise.")
		return
	end
	if not nearMarket(player) then
		refuse("Walk to the Golden Fish Market first")
		return
	end
	local row = Catalog.getFreshCatchRow(itemId)
	if row == nil then
		refuse("That isn't on the Fresh Catch board.")
		return
	end
	local state = profile.freshCatch
	local window = FreshCatch.window(os.time())
	FreshCatch.refresh(state, window)
	if FreshCatch.behind(state, window) then
		refuse("The fresh catch is on its way. Try again in a moment.")
		return
	end
	if seenWindow ~= window then
		-- the stock rolled over while the player looked: they never saw these amounts (S42)
		refuse("A fresh catch just came in. Take another look.")
		return
	end
	local amount = FreshCatch.amountOf(window, itemId)
	local already = state.bought[itemId] or 0
	if amount <= 0 then
		refuse("None this time.")
		return
	end
	if already >= amount then
		refuse(
			if amount == 1
				then "You bought the only one this time."
				else "You bought them all this time."
		)
		return
	end
	if not GoldenFish.trySpend(profile, row.fish) then
		refuse("Not enough golden fish")
		return
	end
	Telemetry.fishSink(player, profile, row.fish, "Shop", "fresh_catch")
	Telemetry.custom(
		player,
		"fresh_catch_buy",
		row.fish,
		{ itemId, tostring(Economy.tier(profile)) }
	)
	state.bought[itemId] = already + 1
	local name = freshName(row)
	if row.kind == "potion" then
		local potionId = row.potionId :: string
		profile.potions[potionId] = (profile.potions[potionId] or 0) + 1
		Net.toast(player, string.format("Bought a %s. It's in your potion bag.", name), "good")
	else
		local crateId = row.crateId :: string
		setCount(profile.crates, crateId, (profile.crates[crateId] or 0) + 1)
		Net.toast(player, string.format("Bought a %s. Open it here any time.", name), "good")
	end
	CafeService.sync(player)
	sendFresh(player, true)
end

function FishMarketService.start()
	Players.PlayerRemoving:Connect(function(player)
		lastOpenAt[player] = nil
		freshSent[player] = nil
	end)
	Net.on("OpenCrate", onOpenCrate)
	Net.on("BuyFishItem", onBuyFishItem)
	Net.on("BuyFreshCatch", onBuyFreshCatch)
	ClockService.changed:Connect(function()
		for _, player in DataService.loadedPlayers() do
			sendFresh(player, false)
		end
	end)
	-- A new window, sunrise or a join changes someone's stock or alert; one check a second catches them all.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in DataService.loadedPlayers() do
				local profile = DataService.get(player)
				if profile ~= nil then
					sendFresh(player, false)
					alertIfDue(player, profile)
				end
			end
		end
	end)
end

-- Studio-only test hook (Debug.giveCrate): banks `count` of a crate, which the Market then opens for free.
function FishMarketService.debugGive(
	player: Player,
	profile: Types.PlayerProfile,
	crateId: string,
	count: number
)
	assert(Catalog.getCrate(crateId) ~= nil, "unknown crate " .. crateId)
	setCount(profile.crates, crateId, math.floor(count))
	lastOpenAt[player] = nil
	CafeService.sync(player)
end

return FishMarketService
