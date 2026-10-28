--!strict
-- Rich customers (F31, data-model section 12). By day, every RichCheckSeconds, each owned cafe that earns and has a
-- table rolls RichChance for a rich customer. A hit records a tip in this service's own table, keyed by plot:
-- { ownerUserId, serial, amount = Economy.richTipAmount(day rate), expiresAt = now + RichTipStaySeconds }. The
-- amount and expiry are mirrored to the plot attributes RichTipAmount and RichTipExpiresAt for display only (the
-- UI's gold marker, the client's rich customer and coin pile); decisions read the table.
-- ClaimRichTip() from the owner within RichTipRangeStuds of the plot's RichTipAnchor before expiry pays it now.
-- Only a claim pays (Derek 2026-10-28 01:32: "if you miss it you miss it"): at expiry, at nightfall or when the
-- owner leaves the tip is gone unpaid. A rich customer comes only by day before the dusk warning (data-model 12
-- v0.13.4), and the tip's expiry never runs past dusk, so no tip shows at night. The plot attribute RichTipOutcome
-- ("claimed" or "missed") is set just before the amount clears, so the client knows which it was.
-- Owner safety (S29): every path takes the record out of the table before it adds coins, so a tip pays exactly
-- once.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CafeService = require(script.Parent.CafeService)
local ClockService = require(script.Parent.ClockService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Net = require(script.Parent.Net)
local PlotService = require(script.Parent.PlotService)
local Potions = require(ReplicatedStorage.Shared.Potions)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local RichTipService = {}

type Tip = {
	ownerUserId: number,
	serial: number, -- which tip this is, for the logs and a later async path; a plot holds one at a time
	amount: number,
	expiresAt: number, -- os.time()
	plot: WorldBuilder.Plot,
}

local tips: { [number]: Tip } = {} -- plot index -> its open tip, one at a time
local serial = 0
local rng = Random.new()

local function withinRange(player: Player, position: Vector3, range: number): boolean
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return root ~= nil
		and root:IsA("BasePart")
		and ((root :: BasePart).Position - position).Magnitude <= range
end

local function show(plot: WorldBuilder.Plot, amount: number, expiresAt: number, outcome: string?)
	plot.model:SetAttribute("RichTipOutcome", outcome)
	plot.model:SetAttribute("RichTipAmount", amount)
	plot.model:SetAttribute("RichTipExpiresAt", expiresAt)
end

-- Takes the tip off the plot: out of the table and off the attributes, with `outcome` ("claimed" or "missed") for
-- the client. Only the caller that gets it back may pay it, so no two paths can pay the same tip.
local function take(index: number, outcome: string): Tip?
	local tip = tips[index]
	if tip == nil then
		return nil
	end
	tips[index] = nil
	show(tip.plot, 0, 0, outcome)
	return tip
end

local function logTip(player: Player, profile: Types.PlayerProfile, amount: number, outcome: string)
	Telemetry.source(player, profile, amount, "Gameplay", "rich_tip")
	Telemetry.custom(player, "rich_tip", amount, { outcome, tostring(Economy.tier(profile)) })
end

local function pay(player: Player, tip: Tip)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	Economy.credit(profile, tip.amount)
	logTip(player, profile, tip.amount, "claimed")
	CafeService.sync(player)
end

-- A tip nobody claimed: gone, no coins (analytics rich_tip "missed"). `profile` when the caller has it already.
local function miss(index: number, profile: Types.PlayerProfile?)
	local tip = take(index, "missed")
	if tip == nil then
		return
	end
	local owner = Players:GetPlayerByUserId(tip.ownerUserId)
	local ownerProfile = profile or (if owner ~= nil then DataService.get(owner) else nil)
	if owner ~= nil and ownerProfile ~= nil then
		Telemetry.custom(
			owner,
			"rich_tip",
			tip.amount,
			{ "missed", tostring(Economy.tier(ownerProfile)) }
		)
	end
end

local function onClaimRichTip(player: Player)
	local plot = PlotService.get(player)
	if plot == nil then
		return
	end
	local tip = tips[plot.index]
	if tip == nil or tip.ownerUserId ~= player.UserId or tip.plot ~= plot then
		return
	end
	if os.time() >= tip.expiresAt then
		return -- missed; the expiry check clears it within a second
	end
	-- the device checks RichTipRangeStuds from the HumanoidRootPart; 2 studs of slack for movement in flight
	if not withinRange(player, plot.richTipAnchor.Position, Config.RichTipRangeStuds + 2) then
		Net.toast(player, "Walk closer to collect the tip", "info")
		return
	end
	local taken = take(plot.index, "claimed")
	if taken ~= nil then
		pay(player, taken)
	end
end

-- Clears every tip whose time is up, unpaid.
local function checkExpiries()
	local now = os.time()
	for index, tip in tips do
		if now >= tip.expiresAt then
			miss(index)
		end
	end
end

local function open(
	player: Player,
	plot: WorldBuilder.Plot,
	dayRate: number,
	now: number,
	lastsUntil: number
): Tip
	serial += 1
	local tip: Tip = {
		ownerUserId = player.UserId,
		serial = serial,
		amount = Economy.richTipAmount(dayRate),
		expiresAt = math.min(now + Config.RichTipStaySeconds, lastsUntil),
		plot = plot,
	}
	tips[plot.index] = tip
	show(plot, tip.amount, tip.expiresAt, "")
	return tip
end

-- By day only, before the last DuskWarningSeconds: each owned cafe that earns, has a table for the rich
-- customer to sit at and has no tip open rolls RichChance. The tip ends at dusk at the latest. A Tip Potion running
-- when the visitor comes adds its share to the tip (F64).
local function roll()
	local now = os.time()
	local dusk = math.floor(ClockService.phaseEndsAt())
	if ClockService.isNight() or dusk - now <= Config.DuskWarningSeconds then
		return
	end
	for _, player in DataService.loadedPlayers() do
		local plot = PlotService.get(player)
		local profile = DataService.get(player)
		if plot == nil or profile == nil or tips[plot.index] ~= nil then
			continue
		end
		local dayRate = Economy.incomePerSecond(profile)
		if dayRate <= 0 or Economy.level(profile, "tables") < 1 then
			continue
		end
		if rng:NextNumber() < Config.RichChance then
			open(player, plot, dayRate * Potions.tipMultiplier(profile, now), now, dusk)
		end
	end
end

function RichTipService.start()
	Net.on("ClaimRichTip", onClaimRichTip)
	-- leaving: an open tip is missed, like any other unclaimed one
	DataService.beforeRelease(function(player, profile)
		for index, tip in tips do
			if tip.ownerUserId == player.UserId then
				miss(index, profile)
			end
		end
	end)
	-- nightfall: the cafe closes and the rich customer leaves with the tip (a debug jump to night lands here too)
	ClockService.changed:Connect(function(phase)
		if phase == "night" then
			for index in tips do
				miss(index)
			end
		end
	end)
	task.spawn(function()
		local nextRoll = os.clock() + Config.RichCheckSeconds
		while true do
			task.wait(1)
			checkExpiries()
			if os.clock() >= nextRoll then
				nextRoll = os.clock() + Config.RichCheckSeconds
				roll()
			end
		end
	end)
end

-- Studio-only test hook: opens a rich tip at the player's cafe now, whatever the clock and the roll. Returns the
-- amount, or 0 when the player has no cafe.
function RichTipService.debugOpen(player: Player, staySeconds: number?): number
	assert(RunService:IsStudio(), "debugOpen is Studio only")
	local plot = PlotService.get(player)
	local profile = DataService.get(player)
	if plot == nil or profile == nil then
		return 0
	end
	take(plot.index, "missed")
	local now = os.time()
	local tip = open(
		player,
		plot,
		Economy.incomePerSecond(profile),
		now,
		now + (staySeconds or Config.RichTipStaySeconds)
	)
	if staySeconds ~= nil then
		tip.expiresAt = now + staySeconds
		show(plot, tip.amount, tip.expiresAt, "")
	end
	return tip.amount
end

return RichTipService
