--!strict
-- #4447: the Dragon Keep's Double Jump and Glide on this client (shared/AirMoves holds the rules). The server sets
-- the DoubleJump and Glide player attributes from the slotted cards (DragonKeepService); with neither set nothing
-- here runs on a frame. Never while the character is held still (JumpHeight 0: a catch, a carry freeze) or anchored
-- (a cannon flight).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AirMoves = require(Shared:WaitForChild("AirMoves"))

local AirMovesController = {}

local player = Players.LocalPlayer
local state = AirMoves.new()
local humanoid: Humanoid? = nil
local root: BasePart? = nil

local function free(): boolean
	return humanoid ~= nil
		and root ~= nil
		and humanoid.Health > 0
		and humanoid.JumpHeight > 0
		and not (root :: BasePart).Anchored
end

local function bind(character: Model)
	humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	AirMoves.landed(state)
	local h = humanoid
	if h == nil then
		return
	end
	h.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Freefall or new == Enum.HumanoidStateType.Jumping then
			AirMoves.leftGround(state, os.clock())
		elseif
			new == Enum.HumanoidStateType.Landed
			or new == Enum.HumanoidStateType.Running
			or new == Enum.HumanoidStateType.Swimming
			or new == Enum.HumanoidStateType.Seated
		then
			AirMoves.landed(state)
		end
	end)
end

function AirMovesController.start()
	if player.Character ~= nil then
		task.spawn(bind, player.Character)
	end
	player.CharacterAdded:Connect(bind)
	UserInputService.JumpRequest:Connect(function()
		local double = player:GetAttribute("DoubleJump") == true
		if AirMoves.request(state, os.clock(), double and free()) then
			(humanoid :: Humanoid):ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end)
	RunService.Heartbeat:Connect(function()
		if player:GetAttribute("Glide") ~= true or not free() then
			return
		end
		local part = root :: BasePart
		local velocity = part.AssemblyLinearVelocity
		local fall = AirMoves.glideFall(state, os.clock(), true, velocity.Y)
		if fall ~= nil then
			part.AssemblyLinearVelocity = Vector3.new(velocity.X, fall, velocity.Z)
		end
	end)
end

return AirMovesController
