--!strict
-- #5533 goalChip (Design-Agent's new-start-v2-spec.md, shared/FreeStart): the two first goals of the play first start,
-- "Catch a cat +100" and "Take it to camp +100". Each pays FreeStart.GOAL_PAY coins once per save (its bit in
-- telemetry.startPaid): the first on the save's first catch by net, the second on its first camp check-in. Only for a
-- save on the play first start below FreeStart.UNTIL_TIER, with the goalChip switch on. The goal card reads
-- PlayerState.startGoals (CafeService), built from the same bits.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CafeService = require(script.Parent.CafeService)
local CatService = require(script.Parent.CatService)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local FreeStart = require(ReplicatedStorage.Shared.FreeStart)
local LiveFlagService = require(script.Parent.LiveFlagService)
local Payout = require(script.Parent.Payout)
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
	CafeService.sync(player)
	return true
end

function StartGoalService.start()
	CatService.onCaught(function(player: Player)
		StartGoalService.pay(player, FreeStart.PAID_CAUGHT)
	end)
	CatService.onCampCheckIn(function(player: Player)
		StartGoalService.pay(player, FreeStart.PAID_HOME)
	end)
end

return StartGoalService
