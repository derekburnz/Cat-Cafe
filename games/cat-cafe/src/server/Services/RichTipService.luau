--!strict
-- Rich customers (F31, data-model section 12). By day, every RichCheckSeconds, each owned cafe that earns and has a
-- table rolls RichChance for a rich customer. A hit records a tip in this service's own table, keyed by plot:
-- { ownerUserId, serial, amount = Economy.richTipAmount(day rate), expiresAt = now + RichTipStaySeconds }. The
-- amount and expiry are mirrored to the plot attributes RichTipAmount and RichTipExpiresAt for display only (the
-- UI's gold marker, the client's rich customer and coin pile); decisions read the table.
-- ClaimRichTip() from the owner within RichTipRangeStuds of the plot's RichTipAnchor before expiry pays it now.
-- Unclaimed, it pays itself at expiry, checked every second, so the marker and the "+$X" toast close together.
-- Owner safety (S29): every path takes the record out of the table before it adds coins, so a tip pays exactly
-- once; the expiry pays only an owner who still holds the plot; leaving pays an open tip before the save.

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

local function show(plot: WorldBuilder.Plot, amount: number, expiresAt: number)
	plot.model:SetAttribute("RichTipAmount", amount)
	plot.model:SetAttribute("RichTipExpiresAt", expiresAt)
end

-- Takes the tip off the plot: out of the table and off the attributes. Only the caller that gets it back may pay
-- it, so no two paths can pay the same tip.
local function take(index: number): Tip?
	local tip = tips[index]
	if tip == nil then
		return nil
	end
	tips[index] = nil
	show(tip.plot, 0, 0)
	return tip
end

local function pay(player: Player, tip: Tip)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	Economy.credit(profile, tip.amount)
	CafeService.sync(player)
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
		return -- the expiry check pays it within a second
	end
	-- the device checks RichTipRangeStuds from the HumanoidRootPart; 2 studs of slack for movement in flight
	if not withinRange(player, plot.richTipAnchor.Position, Config.RichTipRangeStuds + 2) then
		Net.toast(player, "Walk closer to collect the tip", "info")
		return
	end
	local taken = take(plot.index)
	if taken ~= nil then
		pay(player, taken)
	end
end

-- Pays every tip whose time is up to the owner who still holds its plot; a tip whose owner has gone is dropped
-- (the leave path paid it already).
local function checkExpiries()
	local now = os.time()
	for index, tip in tips do
		if now < tip.expiresAt then
			continue
		end
		local taken = take(index)
		local owner = Players:GetPlayerByUserId(tip.ownerUserId)
		if taken ~= nil and owner ~= nil and PlotService.get(owner) == taken.plot then
			pay(owner, taken)
		end
	end
end

local function open(player: Player, plot: WorldBuilder.Plot, dayRate: number, now: number): Tip
	serial += 1
	local tip: Tip = {
		ownerUserId = player.UserId,
		serial = serial,
		amount = Economy.richTipAmount(dayRate),
		expiresAt = now + Config.RichTipStaySeconds,
		plot = plot,
	}
	tips[plot.index] = tip
	show(plot, tip.amount, tip.expiresAt)
	return tip
end

-- By day only: each owned cafe that earns, has a table for the rich customer to sit at and has no tip open rolls
-- RichChance.
local function roll()
	if ClockService.isNight() then
		return
	end
	local now = os.time()
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
			open(player, plot, dayRate, now)
		end
	end
end

function RichTipService.start()
	Net.on("ClaimRichTip", onClaimRichTip)
	-- leaving: an open tip goes into the save, never lost (S29); PlotService.release clears the attributes
	DataService.beforeRelease(function(player, profile)
		for index, tip in tips do
			if tip.ownerUserId == player.UserId then
				local taken = take(index)
				if taken ~= nil then
					Economy.credit(profile, taken.amount)
				end
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
	take(plot.index)
	local tip = open(player, plot, Economy.incomePerSecond(profile), os.time())
	if staySeconds ~= nil then
		tip.expiresAt = os.time() + staySeconds
		show(plot, tip.amount, tip.expiresAt)
	end
	return tip.amount
end

return RichTipService
