--!strict
-- Index rewards (F48, F54; data-model section 11b, golden-fish.md sections 4, 5 and 5b). ClaimIndexReward(areaId,
-- milestoneId) pays a milestone on an Index page (an area, "all" or a Decor Index page "decor_<pool>") once the
-- player has found enough and it has not been claimed. The claim is marked before anything is paid, so one
-- milestone pays once. Payout pays the prize; the permanent bonuses are not paid, since IndexRewards.totals reads
-- them from the claims. Nothing here can be bought.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CafeService = require(script.Parent.CafeService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local DataService = require(script.Parent.DataService)
local Guard = require(script.Parent.Parent.Util.Guard)
local IndexRewards = require(ReplicatedStorage.Shared.IndexRewards)
local Net = require(script.Parent.Net)
local Payout = require(script.Parent.Payout)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)

local IndexRewardService = {}

-- The page's name for the toast: the area's, "All Cats" or the Decor Index page's crate.
local function pageName(areaId: string): string
	if areaId == IndexRewards.ALL then
		return "All Cats"
	end
	local area = Catalog.getArea(areaId)
	if area ~= nil then
		return area.name
	end
	local pool = string.sub(areaId, #IndexRewards.DECOR_PREFIX + 1)
	local crate = Catalog.getCrate(pool .. "_crate")
	return if crate ~= nil then crate.name else areaId
end

local function onClaimIndexReward(player: Player, rawArea: unknown, rawMilestone: unknown)
	local areaId, milestoneId = Guard.id(rawArea), Guard.id(rawMilestone)
	local profile = DataService.get(player)
	if areaId == nil or milestoneId == nil or profile == nil then
		return
	end
	local blocker = IndexRewards.blocker(profile, areaId, milestoneId)
	if blocker ~= nil then
		Net.toast(player, blocker, "warn")
		CafeService.sync(player)
		return
	end
	local prize = IndexRewards.prize(areaId, milestoneId) :: Types.IndexPrize
	local claims = profile.indexRewards[areaId]
	if claims == nil then
		claims = {}
		profile.indexRewards[areaId] = claims
	end
	claims[milestoneId] = true
	local paid, coins = Payout.pay(player, profile, prize, "index_reward")
	Telemetry.custom(player, "index_reward", coins, { areaId, milestoneId })
	Net.toast(
		player,
		string.format("%s Index reward: %s", pageName(areaId), table.concat(paid, ", ")),
		"good"
	)
	CafeService.sync(player)
end

function IndexRewardService.start()
	Net.on("ClaimIndexReward", onClaimIndexReward)
end

return IndexRewardService
