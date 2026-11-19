--!strict
-- #5357: the townGround switch (shared/TownGround). Every TownGround.STEP seconds it reads the switch and, when it has
-- changed, sets each model tagged TownGround.TAG (the Town Square's paving and the paw print paths) Persistent with it
-- on, Default as built with it off. A model tagged later (a world rebuild) gets the current mode when it is tagged.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LiveFlagService = require(script.Parent.LiveFlagService)
local TownGround = require(ReplicatedStorage.Shared.TownGround)

local TownGroundService = {}

local switchOn = false

local function set(item: Instance)
	if item:IsA("Model") then
		local model = item :: Model
		local mode = TownGround.mode(switchOn)
		if model.ModelStreamingMode ~= mode then
			model.ModelStreamingMode = mode
		end
	end
end

local function apply(on: boolean)
	switchOn = on
	for _, item in CollectionService:GetTagged(TownGround.TAG) do
		set(item)
	end
end

function TownGroundService.start()
	CollectionService:GetInstanceAddedSignal(TownGround.TAG):Connect(set)
	task.spawn(function()
		local last: boolean? = nil
		while true do
			local on = LiveFlagService.on(TownGround.FLAG)
			if on ~= last then
				last = on
				apply(on)
			end
			task.wait(TownGround.STEP)
		end
	end)
end

return TownGroundService
