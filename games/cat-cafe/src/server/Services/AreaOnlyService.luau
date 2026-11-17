--!strict
-- #5026: the areaOnly switch (shared/AreaOnly). Every AreaOnly.STEP seconds it reads the switch and, when it has
-- changed, sets each area night fence's and camp cannon's ModelStreamingMode: Atomic with it on, Persistent (as
-- WorldBuilder builds them) with it off. A fence inside a cafe (the closed back door) and the Town Square cannon are
-- left alone. Each cafe (#5026, Sync's census: the 8 cafes are 14,800 instances on every device) and the Persistent
-- models in it (door sets, cat flap, decor) turn PersistentPerPlayer for the cafe's owner: kept on the owner's device
-- wherever they are, streaming like the street for everyone else. Off, they go back to Persistent.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AreaOnly = require(ReplicatedStorage.Shared.AreaOnly)
local LiveFlagService = require(script.Parent.LiveFlagService)

local AreaOnlyService = {}

local function inPlot(model: Instance): boolean
	local node = model.Parent
	while node ~= nil do
		if CollectionService:HasTag(node, "Plot") then
			return true
		end
		node = node.Parent
	end
	return false
end

local function set(model: Model, mode: Enum.ModelStreamingMode)
	if model.ModelStreamingMode ~= mode then
		model.ModelStreamingMode = mode
	end
end

local function ownerOf(plot: Model): Player?
	local id = plot:GetAttribute("OwnerUserId")
	return if type(id) == "number" and id > 0 then Players:GetPlayerByUserId(id) else nil
end

-- One cafe model: with the switch on, PersistentPerPlayer kept for `owner` alone; off, Persistent as built.
local function keepFor(model: Model, on: boolean, owner: Player?)
	set(model, AreaOnly.cafeMode(on))
	for _, player in model:GetPersistentPlayers() do
		if player:IsA("Player") and (not on or player ~= owner) then
			model:RemovePersistentPlayer(player :: Player)
		end
	end
	if on and owner ~= nil and table.find(model:GetPersistentPlayers(), owner) == nil then
		model:AddPersistentPlayer(owner)
	end
end

local function kept(model: Model): boolean
	local mode = model.ModelStreamingMode
	return mode == Enum.ModelStreamingMode.Persistent
		or mode == Enum.ModelStreamingMode.PersistentPerPlayer
end

-- A cafe and every model in it that is kept (Persistent, or PersistentPerPlayer from this service)
local function applyCafe(plot: Model, on: boolean)
	local owner = ownerOf(plot)
	keepFor(plot, on, owner)
	for _, descendant in plot:GetDescendants() do
		if descendant:IsA("Model") and kept(descendant :: Model) then
			keepFor(descendant :: Model, on, owner)
		end
	end
end

local switchOn = false
local watched: { [Instance]: boolean } = {}

-- Follows a cafe's owner and the models CafeService puts in it (door sets and decor are made Persistent)
local function watchCafe(plot: Model)
	if watched[plot] then
		return
	end
	watched[plot] = true
	plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		applyCafe(plot, switchOn)
	end)
	plot.DescendantAdded:Connect(function(descendant: Instance)
		if not switchOn or not descendant:IsA("Model") then
			return
		end
		task.defer(function() -- after the same frame's ModelStreamingMode set
			local model = descendant :: Model
			if switchOn and model:IsDescendantOf(plot) and kept(model) then
				keepFor(model, true, ownerOf(plot))
			end
		end)
	end)
end

local function apply(on: boolean)
	switchOn = on
	for _, plot in CollectionService:GetTagged("Plot") do
		if plot:IsA("Model") then
			watchCafe(plot :: Model)
			applyCafe(plot :: Model, on)
		end
	end
	local mode = AreaOnly.fenceMode(on)
	for _, fence in CollectionService:GetTagged("NightFence") do
		if fence:IsA("Model") and not inPlot(fence) then
			set(fence :: Model, mode)
		end
	end
	for _, cannon in CollectionService:GetTagged("CatCannon") do
		if cannon:IsA("Model") and AreaOnly.cannonStreams(cannon:GetAttribute("CannonId")) then
			set(cannon :: Model, mode)
		end
	end
end

function AreaOnlyService.start()
	task.spawn(function()
		local last: boolean? = nil
		while true do
			local on = LiveFlagService.on(AreaOnly.FLAG)
			if on ~= last then
				last = on
				apply(on)
			end
			task.wait(AreaOnly.STEP)
		end
	end)
end

return AreaOnlyService
