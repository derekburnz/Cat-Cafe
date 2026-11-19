--!strict
-- #5357: the townGround switch (shared/TownGround). Every TownGround.STEP seconds it reads the switch and, when it has
-- changed, sets each model tagged TownGround.TAG (the Town Square's paving and the paw print paths) Persistent with it
-- on, Default as built with it off. A model tagged later (a world rebuild) gets the current mode when it is tagged.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LiveFlagService = require(script.Parent.LiveFlagService)
local PawFloor = require(script.Parent.Parent.World.PawFloor)
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
		local floorLast: boolean? = nil
		while true do
			local on = LiveFlagService.on(TownGround.FLAG)
			if on ~= last then
				last = on
				apply(on)
			end
			-- #5471: the paw prints drawn into the floor under them (World/PawFloor)
			local floor = LiveFlagService.on(TownGround.FLOOR_FLAG)
			if floor ~= floorLast then
				floorLast = floor
				local ok, err = pcall(function(): string?
					PawFloor.apply(floor)
					return nil -- CI's luau-lsp wants two values from pcall
				end)
				if not ok then
					warn("[TownGround] paws in the floor: " .. tostring(err))
				end
			end
			task.wait(TownGround.STEP)
		end
	end)
end

return TownGroundService
