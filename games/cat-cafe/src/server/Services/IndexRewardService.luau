--!strict
-- Index rewards (F48, F54; data-model section 11b, golden-fish.md sections 4, 5 and 5b). ClaimIndexReward(areaId,
-- milestoneId) pays a milestone on an Index page (an area, "all" or a Decor Index page "decor_<pool>") once the
-- player has found enough and it has not been claimed. The claim is marked before anything is paid, so one
-- milestone pays once. Prizes are coins (a minimum or seconds of the day rate), foods, golden fish, banked spins
-- (up to SpinBankCap; the rest are dropped) and crates (banked for the Golden Fish Market, "highest" resolved at
-- the claim). The permanent bonuses are not paid: IndexRewards.totals reads them from the claims. Nothing here can
-- be bought.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CafeService = require(script.Parent.CafeService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local GoldenFish = require(ReplicatedStorage.Shared.GoldenFish)
local Guard = require(script.Parent.Parent.Util.Guard)
local IndexRewards = require(ReplicatedStorage.Shared.IndexRewards)
local Net = require(script.Parent.Net)
local Prizes = require(ReplicatedStorage.Shared.Prizes)
local Spin = require(ReplicatedStorage.Shared.Spin)
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

-- Pays the prize and returns what it paid, for the toast ("+$300", "2 Tuna", "+25 golden fish", "2 spins",
-- "1 Alley Crate", "+2% tips forever"), and the coins.
local function pay(
	player: Player,
	profile: Types.PlayerProfile,
	prize: Types.IndexPrize
): ({ string }, number)
	local paid: { string } = {}
	local coins = Prizes.coins(prize.coins, prize.coinSeconds, Economy.incomePerSecond(profile))
	if coins > 0 then
		Economy.credit(profile, coins)
		Telemetry.source(player, profile, coins, "Gameplay", "index_reward")
		table.insert(paid, string.format("+$%d", coins))
	end
	if prize.lures ~= nil then
		for lureId, count in prize.lures do
			profile.lures[lureId] = (profile.lures[lureId] or 0) + count
			local lure = Catalog.getLure(lureId)
			table.insert(
				paid,
				string.format("%d %s", count, if lure ~= nil then lure.name else lureId)
			)
		end
	end
	local fish = prize.fish
	if fish ~= nil and fish > 0 then
		GoldenFish.credit(profile, fish)
		Telemetry.fishSource(player, profile, fish, "Gameplay", "index_reward")
		table.insert(paid, string.format("+%d golden fish", fish))
	end
	local spins = prize.spins
	if spins ~= nil and spins > 0 then
		local banked = Spin.bank(profile.spin, spins)
		table.insert(
			paid,
			if banked < spins
				then string.format("%d of %d spins (Spins full)", banked, spins)
				else string.format("%d spin%s", spins, if spins == 1 then "" else "s")
		)
	end
	if prize.crates ~= nil then
		for crateId, count in prize.crates do
			local paidId = Prizes.crateFor(crateId, Economy.tier(profile))
			local crate = if paidId ~= nil then Catalog.getCrate(paidId) else nil
			if paidId ~= nil and crate ~= nil then
				profile.crates[paidId] = (profile.crates[paidId] or 0) + count
				table.insert(paid, string.format("%d %s", count, crate.name))
			end
		end
	end
	local forever = (prize.bonus or 0) + (prize.goldLuck or 0) + (prize.baitSpeed or 0)
	if forever > 0 then
		local what = if prize.goldLuck ~= nil
			then "gold luck"
			elseif prize.baitSpeed ~= nil then "faster bait"
			else "tips"
		table.insert(paid, string.format("+%d%% %s forever", math.floor(forever * 100 + 0.5), what))
	end
	if prize.tag ~= nil then
		table.insert(paid, string.format("the %s tag", prize.tag))
	end
	return paid, coins
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
	local paid, coins = pay(player, profile, prize)
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
