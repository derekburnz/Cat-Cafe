--!strict
-- #5533 goalChip (Design-Agent's new-start-v2-spec.md, shared/FreeStart): the two first goals of the play first start,
-- "Catch a cat +100" and "Take it to camp +100". Each pays FreeStart.GOAL_PAY coins once per save (its bit in
-- telemetry.startPaid): the first on the save's first catch by net, the second on its first camp check-in. Only for a
-- save on the play first start below FreeStart.UNTIL_TIER, with the goalChip switch on. The goal card reads
-- PlayerState.startGoals (CafeService), built from the same bits.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CafeService = require(script.Parent.CafeService)
local CatService = require(script.Parent.CatService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local FreeStart = require(ReplicatedStorage.Shared.FreeStart)
local LiveFlagService = require(script.Parent.LiveFlagService)
local Payout = require(script.Parent.Payout)
local SecondCat = require(ReplicatedStorage.Shared.SecondCat)
local Telemetry = require(script.Parent.Telemetry)

local StartGoalService = {}

-- Pays goal `bit` to `player` once, when it is due; true when it paid.
function StartGoalService.pay(player: Player, bit: number): boolean
	local profile = DataService.get(player)
	if profile == nil or not LiveFlagService.on(FreeStart.GOAL_FLAG) then
		return false
	end
	local state = profile.telemetry
	if not FreeStart.active(state.freeStart, Economy.tier(profile)) then
		return false
	end
	if not FreeStart.unpaid(state.startPaid, bit) then
		return false
	end
	state.startPaid = (state.startPaid or 0) + bit
	Payout.pay(player, profile, { coins = FreeStart.GOAL_PAY }, "start_goal_" .. bit)
	Telemetry.custom(player, "start_goal", bit, {})
	-- #5551 first_five_v1: chip 1 paid; after chip 2 the card shows the coin goal
	Telemetry.firstFive(
		player,
		profile,
		if bit == FreeStart.PAID_CAUGHT then "chip_catch_paid" else "coin_chip_shown"
	)
	CafeService.sync(player)
	return true
end

-- #5596 (Derek 2026-11-20: "make them instantly get the 1500 coins after first catch a lot of people are joining don't
-- have enough coins to rankup after first catch and leaving"), switch firstCatchCoins: a Tier 1 save's first catch by
-- net tops its coins up to the Tier 2 Rank Up cost, so Rank Up is ready at once. Once per save because only the first
-- net catch counts (stats.catsCaught less bait tames is 1), so it needs no saved mark. True when it paid.
StartGoalService.COINS_FLAG = "firstCatchCoins"
function StartGoalService.topUp(player: Player): boolean
	local profile = DataService.get(player)
	if profile == nil or not LiveFlagService.on(StartGoalService.COINS_FLAG) then
		return false
	end
	if Economy.tier(profile) ~= 1 or SecondCat.caught(profile.stats) > 1 then
		return false
	end
	local def = Catalog.getTier(2)
	local gap = if def ~= nil then math.ceil(def.cost - profile.coins) else 0
	if gap <= 0 then
		return false
	end
	Payout.pay(player, profile, { coins = gap }, "first_catch_rank_coins")
	Telemetry.custom(player, "first_catch_coins", gap, {})
	CafeService.sync(player)
	return true
end

function StartGoalService.start()
	CatService.onCaught(function(player: Player)
		StartGoalService.pay(player, FreeStart.PAID_CAUGHT)
		StartGoalService.topUp(player) -- #5596: after the +100, so the gap is what is still short
	end)
	CatService.onCampCheckIn(function(player: Player)
		StartGoalService.pay(player, FreeStart.PAID_HOME)
	end)
end

return StartGoalService
