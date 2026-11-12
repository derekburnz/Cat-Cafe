--!strict
-- #3573 (shared/AfkCafe): this client's side of resting in your cafe. It tells the server when the player has had no
-- input for Config.AfkCafeSeconds (AfkIdle true) and the moment input comes back (AfkIdle false); the server decides
-- whether that is a rest (the zone, a still character, nothing carried). The HUD's chip follows the Player's CafeRest
-- attribute, which the server sets, and goes at the first input without waiting for the server.
-- Input is any key, button, tap, click, stick, mouse move or wheel, or a chat message typed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AfkCafe = require(Shared:WaitForChild("AfkCafe"))
local Config = require(Shared:WaitForChild("Config"))
local Net = require(script.Parent.Parent.Net)
local UI = require(script.Parent.Parent.UI)

local AfkController = {}

local STICK_DEADZONE = 0.2
local lastInput = os.clock()
local idle = false
local inputSeen = false -- any input this session (#3602)

local function chip()
	local player = Players.LocalPlayer
	local rest = player:GetAttribute(AfkCafe.ATTRIBUTE)
	UI.rest.set(idle and rest ~= nil, rest == true)
end

-- #3602: the server took the rest up again after a rejoin (AfkCafe.ARRIVED_ATTRIBUTE). With no input yet this
-- session the client counts as idle from here, so its first input is reported; with input already, it says so now.
local function arrived()
	if Players.LocalPlayer:GetAttribute(AfkCafe.ARRIVED_ATTRIBUTE) ~= true or idle then
		return
	end
	if inputSeen then
		Net.fire("AfkIdle", false)
	else
		idle = true
		chip()
	end
end

local function touched()
	lastInput = os.clock()
	inputSeen = true
	if idle then
		idle = false
		Net.fire("AfkIdle", false)
		chip() -- gone at once; the server's attribute follows
	end
end

function AfkController.start()
	UserInputService.InputBegan:Connect(touched)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.Accelerometer or kind == Enum.UserInputType.Gyro then
			return -- a phone lying on a table still reports tilt; that is not the player
		end
		if kind == Enum.UserInputType.Gamepad1 and input.Position.Magnitude < STICK_DEADZONE then
			return -- a resting stick's drift is not input
		end
		touched()
	end)
	UserInputService.TouchStarted:Connect(touched)
	Players.LocalPlayer.Chatted:Connect(touched)
	Players.LocalPlayer:GetAttributeChangedSignal(AfkCafe.ATTRIBUTE):Connect(chip)
	Players.LocalPlayer:GetAttributeChangedSignal(AfkCafe.ARRIVED_ATTRIBUTE):Connect(arrived)
	arrived()
	task.spawn(function()
		while true do
			task.wait(1)
			if not idle and os.clock() - lastInput >= Config.AfkCafeSeconds then
				idle = true
				Net.fire("AfkIdle", true)
			end
		end
	end)
end

return AfkController
