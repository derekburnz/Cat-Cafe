--!strict
-- #5643 The Christmas Event's Gift Stall on the server (snowglobe-village-spec section 5; shared/GiftStallSave holds
-- the rules). Nothing random and nothing for Robux.
--   BuyGift(id): one of GiftStallSave.ITEMS not bought yet, for its price in Snowflakes (profile.snowflakes), while
--     christmasEvent is on and the event's dates are open (AdventService.now, which Studio may move for Sync's look),
--     from Tier 2 and within GiftStallSave.RANGE studs of a model tagged SnowglobeStall. 1 a second. Answered with a
--     toast and a ProfileSync (PlayerState.giftStall), which the window reads.
--   Owned for good: a decor piece into profile.decorOwned (the Decor window), a hat through the Looks items CafeService
--     builds (GiftStallSave.lookItems). Each join puts the decor bought back into decorOwned, so a save is always whole.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Economy)
local GiftStallSave = require(ReplicatedStorage.Shared.GiftStallSave)
local Types = require(ReplicatedStorage.Shared.Types)

local AdventService = require(script.Parent.AdventService)
local CafeService = require(script.Parent.CafeService)
local DataService = require(script.Parent.DataService)
local Guard = require(script.Parent.Parent.Util.Guard)
local LiveFlagService = require(script.Parent.LiveFlagService)
local Net = require(script.Parent.Net)
local SnowglobeWorld = require(script.Parent.Parent.World.SnowglobeWorld)
local Telemetry = require(script.Parent.Telemetry)

local GiftStallService = {}

GiftStallService.STALL_TAG = SnowglobeWorld.STALL_TAG

local function nearStall(player: Player): boolean
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	local at = (root :: BasePart).Position
	for _, stall in CollectionService:GetTagged(GiftStallService.STALL_TAG) do
		local pivot: Vector3? = if stall:IsA("Model")
			then (stall :: Model):GetPivot().Position
			elseif stall:IsA("BasePart") then (stall :: BasePart).Position
			else nil
		if pivot ~= nil and (pivot - at).Magnitude <= GiftStallSave.RANGE then
			return true
		end
	end
	return false
end

local function onBuy(player: Player, rawId: unknown)
	local id = Guard.id(rawId)
	local profile = DataService.get(player)
	if id == nil or profile == nil then
		return
	end
	local function refuse(reason: string)
		Net.toast(player, reason, "warn")
		CafeService.sync(player) -- the window redraws from the server's view
	end
	local reason = GiftStallSave.buyBlocker(
		profile.giftStall,
		profile.snowflakes,
		id,
		AdventService.now(),
		Economy.tier(profile),
		LiveFlagService.on(GiftStallSave.FLAG)
	)
	if reason == nil and not nearStall(player) then
		reason = "Walk up to the Gift Stall first"
	end
	if reason ~= nil then
		refuse(reason :: string)
		return
	end
	local save = profile.giftStall or GiftStallSave.fresh()
	local before = profile.snowflakes or 0
	local left = GiftStallSave.buy(save, profile.snowflakes, id)
	if left == nil then
		refuse("You need more Snowflakes")
		return
	end
	profile.giftStall = save
	profile.snowflakes = if left > 0 then left else nil
	GiftStallSave.grantOwned(save, profile.decorOwned)
	local item = GiftStallSave.item(id) :: GiftStallSave.Item
	Telemetry.custom(
		player,
		"gift_buy",
		before,
		{ item.id, "T" .. tostring(Economy.tier(profile)) }
	)
	Net.toast(player, string.format("%s, yours to keep!", item.name), "good")
	CafeService.sync(player)
end

function GiftStallService.start()
	Net.on("BuyGift", onBuy)
	DataService.onLoaded:Connect(function(_player: Player, profile: Types.PlayerProfile)
		GiftStallSave.grantOwned(profile.giftStall, profile.decorOwned)
	end)
end

return GiftStallService
