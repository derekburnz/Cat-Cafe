--!strict
-- #3573 (shared/AfkCafe): this client's side of resting in your cafe. It tells the server when the player has had no
-- input for Config.AfkCafeSeconds (AfkIdle true) and the moment input comes back (AfkIdle false); the server decides
-- whether that is a rest (the zone, a still character, nothing carried). The rest banner (#3701) follows the Player's
-- CafeRestZone and CafeRest attributes, which the server sets, and leaves its count or its green at the first input
-- without waiting for the server.
-- Input is any key, button, tap, click, stick, mouse move or wheel, or a chat message typed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AfkCafe = require(Shared:WaitForChild("AfkCafe"))
local Config = require(Shared:WaitForChild("Config"))
local Net = require(script.Parent.Parent.Net)
local RestBannerLogic = require(script.Parent.Parent.UI.Components.RestBannerLogic)
local UI = require(script.Parent.Parent.UI)

local AfkController = {}

local STICK_DEADZONE = 0.2
local lastInput = os.clock()
local idle = false
local inputSeen = false -- any input this session (#3602)

local welcomeAt: number? = nil -- os.clock() the banner's welcome last came up (#3701)
local wasInZone = false
local counting = false -- the banner shows its count: the next input takes it down at once

-- #3701: the cafe rest banner (UI/Components/RestBanner) follows the server's CafeRestZone and CafeRest attributes
-- and this client's own count of the time since its last input. It replaces the rest chip of #3573.
local function chip()
	local player = Players.LocalPlayer
	local rest = player:GetAttribute(AfkCafe.ATTRIBUTE)
	local zone = player:GetAttribute(AfkCafe.ZONE_ATTRIBUTE)
	local now = os.clock()
	local inZone = zone ~= nil
	local ui: any = UI
	local calm = ui.rest.calm() and not AfkController.rejoinQuiet()
	if inZone and not wasInZone and calm and RestBannerLogic.welcomeDue(welcomeAt, now) then
		welcomeAt = now
	end
	-- a walk in during a window or a catch is not counted as seen: the welcome comes at the next walk in
	wasInZone = inZone and (calm or wasInZone)
	local state, remaining = RestBannerLogic.pick({
		rest = if idle and type(rest) == "boolean" then rest else nil,
		zone = if type(zone) == "boolean" then zone else nil,
		sinceInput = now - lastInput,
		welcomeAge = if welcomeAt ~= nil then now - welcomeAt else nil,
		calm = calm,
		wait = Config.AfkCafeSeconds,
	})
	local doubled = if state == "resting" then rest == true else zone == true
	counting = state == "counting"
	ui.rest.banner(state, doubled, remaining)
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
	elseif counting then
		chip()
	end
end

-- #3602: true from a rest's rejoin (AfkCafe.REJOIN_ATTRIBUTE) until this session's first input: the player is
-- away, so the UI holds every ask (UIController's quiet) until they are back.
function AfkController.rejoinQuiet(): boolean
	return not inputSeen and Players.LocalPlayer:GetAttribute(AfkCafe.REJOIN_ATTRIBUTE) == true
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
	Players.LocalPlayer:GetAttributeChangedSignal(AfkCafe.ZONE_ATTRIBUTE):Connect(chip)
	Players.LocalPlayer:GetAttributeChangedSignal(AfkCafe.ARRIVED_ATTRIBUTE):Connect(arrived)
	arrived()
	task.spawn(function()
		while true do
			task.wait(1)
			if not idle and os.clock() - lastInput >= Config.AfkCafeSeconds then
				idle = true
				Net.fire("AfkIdle", true)
			end
			chip() -- the banner's welcome runs out and its count ticks
		end
	end)
end

return AfkController
