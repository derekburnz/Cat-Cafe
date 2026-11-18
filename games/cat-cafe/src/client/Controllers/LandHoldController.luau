--!strict
-- #5269 (Sync 2026-11-18, switch landSafe): at high ping a repeat cannon visit landed on a pad whose floor had
-- streamed out of this client, and the character fell through the moment the server let it go. As the server lets go
-- of a character that flew in the last few seconds, this looks for floor under it; with none, it holds the character
-- in place on this client (characters are client-owned, so the hold is local and its spot is what the server sees),
-- asks for the stream around it, and lets go once the floor is in or after Cannon.LAND_HOLD_SECONDS.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Cannon = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Cannon"))

local LandHoldController = {}

local player = Players.LocalPlayer
local FLOWN_SECONDS = 15 -- a let go this long after a launch still counts as the landing
local POLL_SECONDS = 0.1

local function on(): boolean
	return ReplicatedStorage:GetAttribute("LiveFlag_" .. Cannon.LAND_FLAG) ~= false
end

local function floorUnder(character: Model, root: BasePart): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	return Workspace:Raycast(root.Position, Vector3.new(0, -Cannon.LAND_FLOOR_STUDS, 0), params)
		~= nil
end

local function watch(character: Model)
	local found = character:WaitForChild("HumanoidRootPart", 10)
	if found == nil or not found:IsA("BasePart") then
		return
	end
	local root = found :: BasePart
	local flewAt: number? = nil
	local holding = false
	character:GetAttributeChangedSignal("CannonLaunchAt"):Connect(function()
		if character:GetAttribute("CannonLaunchAt") ~= nil then
			flewAt = os.clock()
		end
	end)
	root:GetPropertyChangedSignal("Anchored"):Connect(function()
		if holding or root.Anchored or flewAt == nil or not on() then
			return
		end
		if os.clock() - (flewAt :: number) > FLOWN_SECONDS then
			return
		end
		flewAt = nil -- once a flight
		if floorUnder(character, root) then
			return
		end
		holding = true
		root.Anchored = true
		local at = root.Position
		task.spawn(function()
			pcall(function()
				player:RequestStreamAroundAsync(at, Cannon.LAND_HOLD_SECONDS)
			end)
		end)
		task.spawn(function()
			local started = os.clock()
			while
				os.clock() - started < Cannon.LAND_HOLD_SECONDS
				and root.Parent ~= nil
				and not floorUnder(character, root)
			do
				task.wait(POLL_SECONDS)
			end
			if root.Parent ~= nil then
				root.Anchored = false
			end
			holding = false
		end)
	end)
end

function LandHoldController.start()
	if player.Character ~= nil then
		task.spawn(watch, player.Character)
	end
	player.CharacterAdded:Connect(watch)
end

return LandHoldController
