--!strict
-- The Daily Treat (F70, data-model section 11e): a seven-stamp card, one stamp per UTC day played, never reset.
-- ClaimDailyTreat() stamps the card when a stamp is due and pays that day's prize through Payout (coins from the day
-- rate at claim time, foods, golden fish, banked spins up to SpinBankCap, crates and a potion), with one toast naming
-- all of it. Every claim, paid or refused, answers with ProfileSync, so a client that drifted gets the card back.
-- The card lives in the save (`dailyTreat`), so a rejoin or another server cannot stamp it twice in a day.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CafeService = require(script.Parent.CafeService)
local DailyTreat = require(ReplicatedStorage.Shared.DailyTreat)
local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net)
local Payout = require(script.Parent.Payout)
local Telemetry = require(script.Parent.Telemetry)

local DailyTreatService = {}

local function onClaimDailyTreat(player: Player)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	local day = DailyTreat.claim(profile.dailyTreat, os.time())
	if day ~= nil then
		local paid =
			Payout.pay(player, profile, DailyTreat.prize(day), "daily_treat", "TimedReward")
		Net.toast(player, "Daily Treat day " .. day .. ": " .. table.concat(paid, ", "), "good")
		Telemetry.custom(player, "daily_treat", day)
	end
	CafeService.sync(player)
end

function DailyTreatService.start()
	Net.on("ClaimDailyTreat", onClaimDailyTreat)
end

return DailyTreatService
