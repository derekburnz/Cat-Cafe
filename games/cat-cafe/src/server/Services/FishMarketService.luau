--!strict
-- The Golden Fish Market (F53, golden-fish.md sections 3 and 4): a stall in the street plaza tagged FishMarket.
-- OpenCrate(crateId) opens a banked crate, or buys one for its price in golden fish, for a player within
-- FishMarketRange, CrateOpenCooldownSeconds after their last open. The server rolls with its own Random (the lucky
-- twentieth on golden odds), adds the piece or pays its duplicate refund, puts a new furniture or decoration piece on
-- a free decor spot and answers CrateResult(crateId, decorId, duplicate, refund), so leaving mid-reveal keeps the
-- piece. BuyFishItem(itemId) buys a food or a perk level. Every cost comes from Catalog.fishShop and Config, never
-- from the client. Golden fish are earned only: nothing here is sold for Robux (monetization-policy).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CafeService = require(script.Parent.CafeService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local Crates = require(ReplicatedStorage.Shared.Crates)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local GoldenFish = require(ReplicatedStorage.Shared.GoldenFish)
local Guard = require(script.Parent.Parent.Util.Guard)
local Net = require(script.Parent.Net)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)

local FishMarketService = {}

FishMarketService.TAG = "FishMarket"

local random = Random.new()
local lastOpenAt: { [Player]: number } = {} -- os.clock() of each player's last crate, for the cooldown

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
	local banked = profile.crates[crate.id] or 0
	if banked > 0 then
		setCount(profile.crates, crate.id, banked - 1)
	else
		local price = crate.price :: number
		GoldenFish.trySpend(profile, price)
		Telemetry.fishSink(player, profile, price, "Shop", "crate")
	end
	local luck = profile.crateLuck[crate.area] or 0
	local decorId, lucky = Crates.roll(crate, luck, random:NextNumber(), random:NextNumber())
	local def = Catalog.getDecor(decorId) :: Types.DecorDef
	local rarity: Types.Rarity = def.rarity or "Common"
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
	Telemetry.custom(
		player,
		"crate_opened",
		1,
		{ crate.id, rarity, def.kind or "unknown", tostring(duplicate), tostring(lucky) }
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
			CafeService.refreshPlot(player) -- the bowl's BaitReadyAt moves up
		end
	end
	CafeService.sync(player)
end

function FishMarketService.start()
	Players.PlayerRemoving:Connect(function(player)
		lastOpenAt[player] = nil
	end)
	Net.on("OpenCrate", onOpenCrate)
	Net.on("BuyFishItem", onBuyFishItem)
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
