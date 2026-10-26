--!strict
-- Client-side world touches: the park gate opens once the Park pass is owned, check-in fires itself at the
-- own cafe door while carrying, and the first tutorial step advances when the player reaches the alley.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(script.Parent.Parent.Net)
local UIController = require(script.Parent.UIController)

local WorldController = {}

local player = Players.LocalPlayer

local function rootPosition(): Vector3?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root.Position else nil
end

local function setGateOpen(open: boolean)
	local world = Workspace:FindFirstChild("World")
	local gate = if world ~= nil then world:FindFirstChild("ParkGate") else nil
	if gate == nil then
		return
	end
	for _, descendant in gate:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = not open
			descendant.Transparency = if open
				then 0.85
				else (if descendant.Name == "Bars" then 0.35 else 0)
		elseif descendant:IsA("BillboardGui") then
			descendant.Enabled = not open
		end
	end
end

function WorldController.start()
	local lastGateOpen: boolean? = nil
	local lastCheckIn = 0
	local sawAlley = false

	task.spawn(function()
		while true do
			task.wait(0.25)
			local state = UIController.state
			if state == nil then
				continue
			end

			local gateOpen = (state.upgradeLevels.park_access or 0) >= 1
			if gateOpen ~= lastGateOpen then
				lastGateOpen = gateOpen
				setGateOpen(gateOpen)
			end

			local position = rootPosition()
			if position == nil then
				continue
			end

			if state.carrying ~= nil then
				local door = UIController.ownDoor()
				if
					door ~= nil
					and (door.Position - position).Magnitude <= Config.CheckInRangeStuds - 1
					and os.clock() - lastCheckIn > 2
				then
					lastCheckIn = os.clock()
					Net.fire("CheckIn")
				end
			end

			if
				not sawAlley
				and state.tutorialStep == 0
				and position.Z > Config.World.AlleyCenterZ - Config.World.AlleyDepth / 2
			then
				sawAlley = true
				Net.fire("TutorialAdvance", 1)
			end
		end
	end)
end

return WorldController
