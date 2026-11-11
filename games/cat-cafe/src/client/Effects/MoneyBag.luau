--!strict
-- Rich customers' money bags (#3360, rich-money-bags.md): the server keeps one display record per waiting bag in
-- a plot's RichBags folder (attributes Position, Amount, ExpiresAt and, just before it goes, Outcome). When a bag
-- drops, a gold ring opens on its spot with a few sparkles, so the drop is seen from across the cafe; when it is
-- collected ("claimed"), sparkles pop and a ring spreads, with a little gold confetti in your own cafe. A missed
-- bag just goes. Reduce Motion keeps the sparkles only; far cafes are skipped. Listening only: it reads the
-- replicated records and fires nothing.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Context = require(script.Parent.Context)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)
local RichBags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RichBags"))

local MoneyBag = {}

local FOLDER = RichBags.FOLDER
local started = false
local watched: { [Instance]: boolean } = {}

-- What a bag's record asks for: "drop" when it appears still waiting, "collect" when its Outcome turns
-- "claimed", nil for a missed bag or anything else.
function MoneyBag.beat(outcome: unknown, isNew: boolean): string?
	if outcome == "claimed" then
		return "collect"
	end
	if outcome == nil and isNew then
		return "drop"
	end
	return nil
end

local function spot(record: Instance): Vector3?
	local position = record:GetAttribute("Position")
	if typeof(position) ~= "Vector3" then
		return nil
	end
	if Context.distance(position) > Presets.moneyBag.within then
		return nil
	end
	return position
end

local function isMine(plot: Instance): boolean
	return plot:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId
end

function MoneyBag.drop(at: Vector3)
	local p = Presets.moneyBag
	Particles.burst(
		"catchSparkle",
		at + Vector3.new(0, p.lift, 0),
		p.dropSparkles,
		Presets.palette.golden
	)
	if not Context.reducedMotion() then
		Particles.ring(at, Presets.palette.golden, p.dropRing, p.ringSeconds)
	end
end

function MoneyBag.collect(at: Vector3, mine: boolean)
	local p = Presets.moneyBag
	local few = Context.lowPerformance
	Particles.burst(
		"catchSparkle",
		at + Vector3.new(0, p.lift, 0),
		if few then p.collectSparkles // 2 else p.collectSparkles,
		Presets.palette.golden
	)
	if Context.reducedMotion() then
		return
	end
	Particles.ring(at, Presets.palette.golden, p.collectRing, p.ringSeconds)
	if mine and not few then
		Particles.confetti(at + Vector3.new(0, p.lift, 0), p.confetti, p.colours)
	end
end

local function watchRecord(plot: Instance, record: Instance, isNew: boolean)
	if MoneyBag.beat(record:GetAttribute("Outcome"), isNew) == "drop" then
		local at = spot(record)
		if at ~= nil then
			MoneyBag.drop(at)
		end
	end
	local connection: RBXScriptConnection
	connection = record:GetAttributeChangedSignal("Outcome"):Connect(function()
		connection:Disconnect()
		if MoneyBag.beat(record:GetAttribute("Outcome"), false) == "collect" then
			local at = spot(record)
			if at ~= nil then
				MoneyBag.collect(at, isMine(plot))
			end
		end
	end)
	record.Destroying:Connect(function()
		connection:Disconnect()
	end)
end

local function watchFolder(plot: Instance, folder: Instance)
	if watched[folder] then
		return
	end
	watched[folder] = true
	-- bags already waiting when the cafe streams in get no drop
	for _, record in folder:GetChildren() do
		watchRecord(plot, record, false)
	end
	folder.ChildAdded:Connect(function(record)
		watchRecord(plot, record, true)
	end)
	folder.Destroying:Connect(function()
		watched[folder] = nil
	end)
end

local function watchPlot(plot: Instance)
	local folder = plot:FindFirstChild(FOLDER)
	if folder ~= nil then
		watchFolder(plot, folder)
	end
	plot.ChildAdded:Connect(function(child)
		if child.Name == FOLDER then
			watchFolder(plot, child)
		end
	end)
end

function MoneyBag.start()
	if started then
		return
	end
	started = true
	for _, plot in CollectionService:GetTagged("Plot") do
		watchPlot(plot)
	end
	CollectionService:GetInstanceAddedSignal("Plot"):Connect(watchPlot)
end

return MoneyBag
