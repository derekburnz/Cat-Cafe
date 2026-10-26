--!strict
-- Client-side world touches: the park gate opens once the Park pass is owned, check-in fires itself at the
-- own cafe door while carrying, the first tutorial step advances when the player reaches the alley, and the
-- sky and street lamps follow the server's day and night clock (features F20). All cosmetic, all local.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
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
			local part = descendant :: BasePart
			part.CanCollide = not open
			part.Transparency = if open then 0.85 else (if part.Name == "Bars" then 0.35 else 0)
		elseif descendant:IsA("BillboardGui") then
			(descendant :: BillboardGui).Enabled = not open
		end
	end
end

-- Lighting per phase. Visual only, so the numbers live here rather than in Config.
local DAY_LIGHTING = {
	ClockTime = 14,
	Brightness = 2,
	OutdoorAmbient = Color3.fromRGB(150, 140, 130),
}
local NIGHT_LIGHTING = {
	ClockTime = 21.5,
	Brightness = 0.7,
	OutdoorAmbient = Color3.fromRGB(70, 75, 115),
}
local LIGHTING_TWEEN = TweenInfo.new(4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

-- Street lamps are any model whose name contains "StreetLamp" (placeholder or the asset thread's model).
local lampsOn = false

local function setLamp(light: Light)
	local model = light:FindFirstAncestorWhichIsA("Model")
	if model == nil or model.Name:find("StreetLamp", 1, true) == nil then
		return
	end
	light.Enabled = lampsOn
	local parent = light.Parent
	if parent ~= nil and parent:IsA("BasePart") then
		(parent :: BasePart).Material = if lampsOn
			then Enum.Material.Neon
			else Enum.Material.SmoothPlastic
	end
end

local function setLampsOn(on: boolean)
	lampsOn = on
	local world = Workspace:FindFirstChild("World")
	if world == nil then
		return
	end
	for _, descendant in world:GetDescendants() do
		if descendant:IsA("Light") then
			setLamp(descendant :: Light)
		end
	end
end

local function applyPhase(phase: any, instant: boolean)
	local night = phase == "night"
	local goal = if night then NIGHT_LIGHTING else DAY_LIGHTING
	if instant then
		Lighting.ClockTime = goal.ClockTime
		Lighting.Brightness = goal.Brightness
		Lighting.OutdoorAmbient = goal.OutdoorAmbient
	else
		TweenService:Create(Lighting, LIGHTING_TWEEN, goal :: any):Play()
	end
	setLampsOn(night)
end

local function followClock()
	-- Lamps that stream in or are built later pick up the current state.
	Workspace.DescendantAdded:Connect(function(descendant: Instance)
		if descendant:IsA("Light") then
			setLamp(descendant :: Light)
		end
	end)
	local clock = ReplicatedStorage:WaitForChild("Clock")
	applyPhase(clock:GetAttribute("Phase"), true)
	clock:GetAttributeChangedSignal("Phase"):Connect(function()
		applyPhase(clock:GetAttribute("Phase"), false)
	end)
end

function WorldController.start()
	task.spawn(followClock)

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
