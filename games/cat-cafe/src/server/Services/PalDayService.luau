--!strict
-- Pal Day (#4913, behind the palDay switch, off by default; shared/Pals). Once a UTC day, the first 5 minutes of play
-- beside at least one pal (PalService's pal clock) pay Pals.GIFT: 30 golden fish and 1 banked spin. Never in the
-- tutorial or an account's first 5 minutes, nothing lost by missing a day, no streak. The day is marked before paying
-- (profile.palDay.day), so a failure inside never pays twice. The player gets PalDayPaid(fish, spins) for the loot
-- card, and pal_day_claimed goes out (value 1; how the first pal was linked, tier; Roblox splits it by device).
-- The player's PalDayDue attribute (Motion-FX's heart over pals, #5081) is Pals.palDayDue on every check and false
-- right after paying, while the switch is on; nil while it is off.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CafeService = require(script.Parent.CafeService)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local LiveFlagService = require(script.Parent.LiveFlagService)
local Net = require(script.Parent.Net)
local PalService = require(script.Parent.PalService)
local Pals = require(ReplicatedStorage.Shared.Pals)
local Payout = require(script.Parent.Payout)
local PlayTime = require(script.Parent.Parent.Util.PlayTime)
local ReturnAB = require(ReplicatedStorage.Shared.ReturnAB)
local Spin = require(ReplicatedStorage.Shared.Spin)
local Telemetry = require(script.Parent.Telemetry)

local PalDayService = {}

local CHECK_SECONDS = 10
local DUE_ATTRIBUTE = "PalDayDue"

local function check(player: Player, now: number)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	-- Derek 2026-11-17 15:24 UTC: the palDay 50/50 (shared/ReturnAB): the off group never gets the gift or its due mark
	if not ReturnAB.allows("palDay", player.UserId, profile.telemetry.firstDay) then
		player:SetAttribute(DUE_ATTRIBUTE, nil)
		return
	end
	local due =
		Pals.palDayDue(profile.palDay, now, PlayTime.seconds(player, profile), profile.tutorialStep)
	player:SetAttribute(DUE_ATTRIBUTE, due)
	local seconds, first = PalService.palSeconds(player)
	if not due or seconds < Pals.PAL_DAY_SECONDS then
		return
	end
	profile.palDay.day = Spin.day(now) -- marked before paying
	player:SetAttribute(DUE_ATTRIBUTE, false)
	Payout.pay(player, profile, { fish = Pals.GIFT.fish, spins = Pals.GIFT.spins }, "pal_day")
	Telemetry.custom(
		player,
		"pal_day_claimed",
		1,
		{ first or "friend", tostring(Economy.tier(profile)) }
	)
	Net.fire(player, "PalDayPaid", Pals.GIFT.fish, Pals.GIFT.spins)
	CafeService.sync(player)
end

function PalDayService.start()
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			if not LiveFlagService.on(Pals.PAL_DAY_FLAG) then
				for _, player in Players:GetPlayers() do
					if player:GetAttribute(DUE_ATTRIBUTE) ~= nil then
						player:SetAttribute(DUE_ATTRIBUTE, nil)
					end
				end
			else
				local now = os.time()
				for _, player in Players:GetPlayers() do
					local ok, err: any = pcall(function()
						check(player, now)
					end)
					if not ok then
						warn(
							"[PalDay] check failed for user "
								.. tostring(player.UserId)
								.. ": "
								.. tostring(err)
						)
					end
				end
			end
		end
	end)
end

return PalDayService
