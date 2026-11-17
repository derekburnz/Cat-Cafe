--!strict
-- #5026: the areaOnly switch (shared/AreaOnly). Every AreaOnly.STEP seconds it reads the switch and, when it has
-- changed, sets each area night fence's and camp cannon's ModelStreamingMode: Atomic with it on, Persistent (as
-- WorldBuilder builds them) with it off. A fence inside a cafe (the closed back door) and the Town Square cannon are
-- left alone.

local CollectionService = game:GetService("CollectionService")
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

local function apply(on: boolean)
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
