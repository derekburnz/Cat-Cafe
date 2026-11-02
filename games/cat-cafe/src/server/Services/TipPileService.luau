--!strict
-- Tip piles (F61, data-model section 12, round 3 Q6). By day, every TipPileSeconds, each owned cafe that earns and
-- has a table gets a tip pile worth Economy.tipPileAmount(day rate), a Tip Potion's share included (F64).
-- Since F97 (notes-10-28-to-10-30.md section 1; Derek 2026-10-28 16:45: "No need to have a collect tips ... should
-- be automatic") a pile pays its owner the moment it appears, wherever they are, and counts as collected for quests
-- and achievements. The piles still show on the tables: each stays TipPileShowSeconds and at most TipPilesMax show,
-- mirrored to the plot attributes TipPiles (count) and TipPilesAmount (their total) for display only. F90's Waiter
-- will sweep them to the till instead. Night adds none. The rich visitor, the Collector and the Mystery gift are
-- still collected by hand.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CafeService = require(script.Parent.CafeService)
local ClockService = require(script.Parent.ClockService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local PlotService = require(script.Parent.PlotService)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local TipPileService = {}

type Shown = { amount: number, at: number } -- a paid pile on the tables: its amount and os.clock() it came

type Piles = {
	ownerUserId: number,
	plot: WorldBuilder.Plot,
	shown: { Shown }, -- oldest first
}

local piles: { [number]: Piles } = {} -- plot index -> the piles showing on its tables

local function show(plot: WorldBuilder.Plot, shown: { Shown })
	local sum = 0
	for _, pile in shown do
		sum += pile.amount
	end
	plot.model:SetAttribute("TipPiles", #shown)
	plot.model:SetAttribute("TipPilesAmount", sum)
end

-- Clears the plot's piles from the tables.
local function clear(index: number)
	local entry = piles[index]
	if entry ~= nil then
		piles[index] = nil
		show(entry.plot, {})
	end
end

-- Pays `player` a pile now and shows it on their cafe's tables. Returns the amount.
local function addPile(
	player: Player,
	profile: Types.PlayerProfile,
	plot: WorldBuilder.Plot,
	dayRate: number,
	now: number
): number
	local entry = piles[plot.index]
	if entry ~= nil and (entry.ownerUserId ~= player.UserId or entry.plot ~= plot) then
		clear(plot.index) -- left over from an earlier owner of the plot
	end
	local current: Piles = piles[plot.index]
		or { ownerUserId = player.UserId, plot = plot, shown = {} }
	piles[plot.index] = current
	local amount = Economy.tipPileAmount(dayRate * Economy.tipMultiplier(profile, now))
	Economy.credit(profile, amount)
	profile.stats.tipPilesCollected += 1 -- F73: each pile counts
	Telemetry.source(player, profile, amount, "Gameplay", "tip_pile")
	table.insert(current.shown, { amount = amount, at = os.clock() })
	while #current.shown > Config.TipPilesMax do
		table.remove(current.shown, 1)
	end
	show(plot, current.shown)
	CafeService.sync(player)
	return amount
end

-- Takes piles older than TipPileShowSeconds off the tables.
local function sweep()
	local cutoff = os.clock() - Config.TipPileShowSeconds
	for index, entry in piles do
		local before = #entry.shown
		while #entry.shown > 0 and entry.shown[1].at <= cutoff do
			table.remove(entry.shown, 1)
		end
		if #entry.shown == 0 then
			clear(index)
		elseif #entry.shown ~= before then
			show(entry.plot, entry.shown)
		end
	end
end

-- By day: a pile at every owned cafe that earns and has a table.
local function tick()
	if ClockService.isNight() then
		return
	end
	local now = os.time()
	for _, player in DataService.loadedPlayers() do
		local plot = PlotService.get(player)
		local profile = DataService.get(player)
		if plot == nil or profile == nil then
			continue
		end
		local dayRate = Economy.incomePerSecond(profile)
		if dayRate <= 0 or Economy.level(profile, "tables") < 1 then
			continue
		end
		addPile(player, profile, plot, dayRate, now)
	end
end

function TipPileService.start()
	-- leaving: the piles leave the tables with the owner
	DataService.beforeRelease(function(player)
		for index, entry in piles do
			if entry.ownerUserId == player.UserId then
				clear(index)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Config.TipPileSeconds)
			tick()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			sweep()
		end
	end)
end

-- How many piles show at `player`'s cafe and their total, for tests and the debug hook.
function TipPileService.showing(player: Player): (number, number)
	local plot = PlotService.get(player)
	local entry = if plot ~= nil then piles[plot.index] else nil
	if entry == nil or entry.ownerUserId ~= player.UserId then
		return 0, 0
	end
	local sum = 0
	for _, pile in entry.shown do
		sum += pile.amount
	end
	return #entry.shown, sum
end

-- Studio-only test hook: pays `count` piles (1 by default) to the player now, whatever the clock, at the day rate
-- (at least the $5 pile on a cafe with no income), each shown on the tables. Returns how many piles show after.
function TipPileService.debugAdd(player: Player, count: number?): number
	assert(RunService:IsStudio(), "debugAdd is Studio only")
	local plot = PlotService.get(player)
	local profile = DataService.get(player)
	if plot == nil or profile == nil then
		return 0
	end
	local now = os.time()
	for _ = 1, math.max(1, count or 1) do
		addPile(player, profile, plot, Economy.incomePerSecond(profile), now)
	end
	return (TipPileService.showing(player))
end

return TipPileService
