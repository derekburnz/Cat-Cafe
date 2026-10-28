--!strict
-- Tip piles (F61, data-model section 12, round 3 Q6). By day, every TipPileSeconds, each owned cafe that earns and
-- has a table gets a tip pile worth Economy.tipPileAmount(day rate), a Tip Potion's share included (F64). Piles wait
-- in this service's own table, keyed by plot, up to TipPilesMax; no new pile comes while that many wait. The count
-- and total are mirrored to the plot attributes TipPiles and TipPilesAmount for display only (the client's coins on
-- the tables, the tipPile sound); decisions read the table.
-- CollectTips() from the owner standing on their own plot pays every waiting pile at once. The owner's client sends
-- it within TipPileCollectRangeStuds of a pile, and the till's Collect button sends it too. Only a collect pays
-- (Derek 2026-10-28 01:32: "if you miss it you miss it"): piles still waiting when the owner leaves are gone. Night
-- adds none, and the day's piles wait on the tables through it.
-- Owner safety (S29): the piles come out of the table before any coins are added, so each pays exactly once.

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
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local TipPileService = {}

type Piles = {
	ownerUserId: number,
	plot: WorldBuilder.Plot,
	amounts: { number }, -- one per pile, oldest first, each fixed when it came
}

local piles: { [number]: Piles } = {} -- plot index -> its waiting piles

local function total(entry: Piles): number
	local sum = 0
	for _, amount in entry.amounts do
		sum += amount
	end
	return sum
end

local function show(plot: WorldBuilder.Plot, count: number, amount: number)
	plot.model:SetAttribute("TipPiles", count)
	plot.model:SetAttribute("TipPilesAmount", amount)
end

-- Takes the plot's piles out of the table and off the attributes. Only the caller that gets them back may pay them.
local function take(index: number): Piles?
	local entry = piles[index]
	if entry == nil then
		return nil
	end
	piles[index] = nil
	show(entry.plot, 0, 0)
	return entry
end

local function onCollectTips(player: Player)
	local plot = PlotService.get(player)
	if plot == nil then
		return
	end
	local entry = piles[plot.index]
	if
		entry == nil
		or entry.ownerUserId ~= player.UserId
		or entry.plot ~= plot
		or #entry.amounts == 0
	then
		return
	end
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return
	end
	-- on the plot itself, front garden to yard (the same box as the safe zone), not just near a door
	if not WorldBuilder.inSafeZone(plot, (root :: BasePart).Position, 0) then
		return
	end
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	local taken = take(plot.index)
	if taken == nil then
		return
	end
	local amount = total(taken)
	Economy.credit(profile, amount)
	Telemetry.source(player, profile, amount, "Gameplay", "tip_pile")
	CafeService.sync(player)
end

-- Adds a pile to `player`'s cafe unless TipPilesMax already wait. Returns the new pile's amount, or nil.
local function addPile(
	player: Player,
	plot: WorldBuilder.Plot,
	dayRate: number,
	now: number
): number?
	local entry = piles[plot.index]
	if entry ~= nil and (entry.ownerUserId ~= player.UserId or entry.plot ~= plot) then
		take(plot.index) -- left over from an earlier owner of the plot: never theirs to collect now
	end
	local current: Piles = piles[plot.index]
		or { ownerUserId = player.UserId, plot = plot, amounts = {} }
	piles[plot.index] = current
	if #current.amounts >= Config.TipPilesMax then
		return nil
	end
	local profile = DataService.get(player)
	local multiplier = if profile ~= nil then Potions.tipMultiplier(profile, now) else 1
	local amount = Economy.tipPileAmount(dayRate * multiplier)
	table.insert(current.amounts, amount)
	show(plot, #current.amounts, total(current))
	return amount
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
		addPile(player, plot, dayRate, now)
	end
end

function TipPileService.start()
	Net.on("CollectTips", onCollectTips)
	-- leaving: waiting piles are gone, unpaid (v0.13.4)
	DataService.beforeRelease(function(player)
		for index, entry in piles do
			if entry.ownerUserId == player.UserId then
				take(index)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Config.TipPileSeconds)
			tick()
		end
	end)
end

-- How many piles wait at `player`'s cafe and their total, for tests and the debug hook.
function TipPileService.waiting(player: Player): (number, number)
	local plot = PlotService.get(player)
	local entry = if plot ~= nil then piles[plot.index] else nil
	if entry == nil or entry.ownerUserId ~= player.UserId then
		return 0, 0
	end
	return #entry.amounts, total(entry)
end

-- Studio-only test hook: adds `count` piles (1 by default) to the player's cafe now, whatever the clock, at the
-- day rate (at least the $5 pile on a cafe with no income). Returns how many piles wait after.
function TipPileService.debugAdd(player: Player, count: number?): number
	assert(RunService:IsStudio(), "debugAdd is Studio only")
	local plot = PlotService.get(player)
	local profile = DataService.get(player)
	if plot == nil or profile == nil then
		return 0
	end
	local now = os.time()
	for _ = 1, math.max(1, count or 1) do
		addPile(player, plot, Economy.incomePerSecond(profile), now)
	end
	return (TipPileService.waiting(player))
end

return TipPileService
