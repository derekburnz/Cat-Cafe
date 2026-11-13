--!strict
-- Juniper's Mystery Market (#2565, mystery-market.md): a cart on the Town Square tagged MysteryMarket. BuyMystery
-- (itemId, shownPrice) buys one item of Catalog.mysteryItems for golden fish, once, from its minTier, for a player
-- within MysteryMarketRange of the cart. The price comes from the server's own clock (shared/MysteryMarket.priceOf):
-- the featured item of the week costs MysterySaleShare of its price. A price above the one the window showed (the
-- sale ended while it was open) is refused with "The sale just ended", never charged. MarkMysterySeen() records the
-- first visit, which clears the "!" over the cart. Golden fish are earned only: nothing here is sold for Robux, and
-- nothing is random (rule 9).
--
-- Config.MysteryOpen false refuses every buy outside Studio: profile.mystery is a new save field, so an older server
-- would drop a bought item. The shelf opens with the ProfileSchema.VERSION bump, in a publish that restarts servers.
-- What each item does lives where it acts (the Backpack's second carry slot in CatService, the Long Net's reach).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BagColours = require(ReplicatedStorage.Shared.BagColours)
local CafeService = require(script.Parent.CafeService)
local CatService = require(script.Parent.CatService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local GoldenFish = require(ReplicatedStorage.Shared.GoldenFish)
local Guard = require(script.Parent.Parent.Util.Guard)
local LiveFlagService = require(script.Parent.LiveFlagService)
local MysteryMarket = require(ReplicatedStorage.Shared.MysteryMarket)
local Net = require(script.Parent.Net)
local NetSwing = require(ReplicatedStorage.Shared.NetSwing)
local Telemetry = require(script.Parent.Telemetry)
local TradeService = require(script.Parent.TradeService)
local Types = require(ReplicatedStorage.Shared.Types)

local MysteryMarketService = {}

MysteryMarketService.TAG = "MysteryMarket"

local MAX_PRICE = 1e6

-- #2565: the Long Net's extra reach as the player attribute NetExtraStuds, for the client's reach glow (the server
-- reads the profile itself).
local function applyPerks(player: Player, profile: Types.PlayerProfile)
	local extra = NetSwing.extraFor(profile.mystery)
	player:SetAttribute("NetExtraStuds", if extra > 0 then extra else nil)
end

-- True when the shelf takes buys in this server.
function MysteryMarketService.isOpen(): boolean
	return Config.MysteryOpen or RunService:IsStudio()
end

-- True when the player stands within MysteryMarketRange of a MysteryMarket cart (a model or a part).
local function nearCart(player: Player): boolean
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	local position = (root :: BasePart).Position
	for _, instance in CollectionService:GetTagged(MysteryMarketService.TAG) do
		local at: Vector3? = nil
		if instance:IsA("Model") then
			at = instance:GetPivot().Position
		elseif instance:IsA("BasePart") then
			at = instance.Position
		end
		if
			at ~= nil
			and instance:IsDescendantOf(Workspace)
			and (at - position).Magnitude <= Config.MysteryMarketRange
		then
			return true
		end
	end
	return false
end

local function onBuy(player: Player, rawItemId: unknown, rawShown: unknown)
	local itemId = Guard.id(rawItemId)
	local shown = Guard.int(rawShown, 0, MAX_PRICE)
	local profile = DataService.get(player)
	if itemId == nil or shown == nil or profile == nil then
		return
	end
	local item = Catalog.getMysteryItem(itemId)
	if item == nil then
		return
	end
	local function refuse(reason: string)
		Net.toast(player, reason, "warn")
		CafeService.sync(player) -- the window redraws from the server's view
	end
	if not MysteryMarketService.isOpen() then
		refuse("Juniper's cart opens soon")
		return
	end
	-- #3535: an item behind a live switch is not sold while the switch is off (the window hides it)
	if item.flag ~= nil and not LiveFlagService.on(item.flag) then
		refuse("Juniper's cart opens soon")
		return
	end
	if not nearCart(player) then
		refuse("Walk to Juniper's cart first")
		return
	end
	local now = os.time()
	local price = MysteryMarket.priceOf(item, now)
	if price > shown then
		refuse(MysteryMarket.SALE_ENDED_TEXT)
		return
	end
	local ok, reason = MysteryMarket.canBuy(profile, item, now)
	local frozen = TradeService.fishSpendBlocker(player) -- #2745 (section 1d)
	if frozen ~= nil then
		ok, reason = false, frozen
	end
	local fishBefore = profile.goldenFish
	if not ok or not GoldenFish.trySpend(profile, price) then
		refuse(reason or MysteryMarket.FISH_TEXT)
		return
	end
	profile.mystery[item.id] = true
	profile.mysterySeen = true
	applyPerks(player, profile)
	if item.id == "backpack" then
		CatService.wearBackpack(player) -- #2719: on their back at once
	end
	CatService.refreshSpeed(player) -- #3535: the Speed Shoes count on the carry in hand
	Telemetry.fishSink(player, profile, price, "Shop", "mystery_" .. item.id)
	Telemetry.custom(player, "mystery_buy", fishBefore, {
		item.id,
		tostring(MysteryMarket.slot(now)),
		"T" .. tostring(Economy.tier(profile)),
	})
	Net.toast(player, string.format("%s, yours forever!", item.name), "good")
	CafeService.sync(player)
end

local function onSeen(player: Player)
	local profile = DataService.get(player)
	if profile == nil or profile.mysterySeen then
		return
	end
	profile.mysterySeen = true
	CafeService.sync(player)
end

-- #3699 (shared/BagColours): the Backpack's owner picks its two colours. Two ids of BagColours.LIST and nothing
-- else; free, from anywhere, as often as the rate limit allows. Refused quietly with the switch off, without the
-- Backpack or for an unknown id (the window never sends those).
local function onBagColours(player: Player, rawMain: unknown, rawTrim: unknown)
	local main, trim = Guard.id(rawMain), Guard.id(rawTrim)
	local profile = DataService.get(player)
	if
		main == nil
		or trim == nil
		or profile == nil
		or not LiveFlagService.on(BagColours.FLAG)
		or not BagColours.valid(main)
		or not BagColours.valid(trim)
	then
		return
	end
	if not MysteryMarket.owns(profile, BagColours.ITEM) then
		Net.toast(player, BagColours.WORDS.locked, "warn")
		return
	end
	local picks = BagColours.sanitize({ main = main, trim = trim })
	local before = BagColours.picks(profile.bagColours)
	if before.main == main and before.trim == trim then
		return
	end
	profile.bagColours = picks
	CatService.tintBackpack(player)
	Telemetry.custom(player, "bag_colours", 1, { main, trim })
	CafeService.sync(player)
end

function MysteryMarketService.start()
	Net.on("BuyMystery", onBuy)
	Net.on("SetBagColours", onBagColours)
	Net.on("MarkMysterySeen", onSeen)
	DataService.onLoaded:Connect(function(player: Player)
		local profile = DataService.get(player)
		if profile ~= nil then
			applyPerks(player, profile)
		end
	end)
end

return MysteryMarketService
