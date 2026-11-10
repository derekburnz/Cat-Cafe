--!strict
-- #2915 (Design-Agent's spec, step 2): the Park-first hint's two parts in the Park itself, rules and words in
-- UI/Components/ParkFirstLogic. The rank-up card's "Fly to the Park" and the picker's ring are the UI's (UI.cannon.fly).
--   The first landing in the Park, once per account: "Strays wait near the camp 🐾" for 3 s, a moment after the
--   landing, then TipSeen("park_first") saves it in tipsSeen. Telemetry park_first_hint "toast".
--   NUDGE_AFTER seconds into a Park visit with no Park cat yet: the nearest free stray within RANGE studs wears the
--   tutorial's flashing ring (UI/Components/StepTarget: a gold Highlight round the cat, and an arrow at the screen's
--   edge while it is off screen) for RING_SECONDS, or until it is caught or leaves; once a session. Telemetry
--   park_first_hint "ring".
-- Roblox terms: the Highlight is made on this client, so only this player sees the ring.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Net = require(script.Parent.Parent.Net)
local ParkFirstLogic = require(script.Parent.Parent.UI.Components.ParkFirstLogic)
local StepTarget = require(script.Parent.Parent.UI.Components.StepTarget)
local UI = require(script.Parent.Parent.UI)
local UIController = require(script.Parent.UIController)

local ParkFirstController = {}

local player = Players.LocalPlayer
local TICK_SECONDS = 1

local toasted = false -- this session, so a slow sync never shows it twice
local rung = false
local ring: StepTarget.StepTarget? = nil

local function areaOf(catId: string): string?
	local def = Catalog.getCat(catId)
	return if def ~= nil then def.area else nil
end

local function caughtPark(): boolean
	local state = UIController.state
	return state ~= nil and ParkFirstLogic.caught(state.collection, areaOf)
end

local function rootPosition(): Vector3?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then (root :: BasePart).Position else nil
end

-- The landing toast, once the flight that CannonLaunch started has landed (the server clears Launching on landing).
local function toastOnLanding()
	local character = player.Character
	if character == nil then
		return
	end
	local started = os.clock()
	while
		character.Parent ~= nil
		and character:GetAttribute("Launching") == true
		and os.clock() - started < 15
	do
		task.wait(0.2)
	end
	task.wait(ParkFirstLogic.TOAST_AFTER_LANDING)
	local state = UIController.state
	if toasted or state == nil or UI.cannon.area ~= ParkFirstLogic.AREA then
		return
	end
	if not ParkFirstLogic.toastDue(ParkFirstLogic.AREA, state.tipsSeen, caughtPark()) then
		return
	end
	toasted = true
	if state.tipsSeen ~= nil then
		state.tipsSeen[ParkFirstLogic.TIP] = true
	end
	UI.toast(ParkFirstLogic.TOAST, "info", ParkFirstLogic.TOAST_SECONDS)
	Net.fire("TipSeen", ParkFirstLogic.TIP, false)
	Net.fire("TelemetryReport", ParkFirstLogic.TELEMETRY, "toast")
end

-- The free Park strays in Workspace.World.Strays, for ParkFirstLogic.pick.
local function strays(): ({ ParkFirstLogic.Stray }, { BasePart })
	local list: { ParkFirstLogic.Stray } = {}
	local parts: { BasePart } = {}
	local world = Workspace:FindFirstChild("World")
	local folder = if world ~= nil then world:FindFirstChild("Strays") else nil
	if folder == nil then
		return list, parts
	end
	for _, model in folder:GetChildren() do
		if not model:IsA("Model") then
			continue
		end
		local body = (model :: Model).PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
		if body == nil then
			continue
		end
		local locked = model:GetAttribute("LockedBy")
		local beginner = model:GetAttribute("Beginner")
		local area = model:GetAttribute("Area")
		table.insert(list, {
			position = (body :: BasePart).Position,
			area = if type(area) == "string" then area else nil,
			lockedBy = if type(locked) == "number" then locked else 0,
			beginner = if type(beginner) == "number" then beginner else 0,
			dropped = model:GetAttribute("Dropped") == true,
		})
		table.insert(parts, body :: BasePart)
	end
	return list, parts
end

local function nudge(): boolean
	local at = rootPosition()
	if at == nil then
		return false
	end
	local list, parts = strays()
	local index = ParkFirstLogic.pick(list, at, player.UserId, ParkFirstLogic.RANGE)
	if index == nil then
		return false
	end
	local target = parts[index]
	if ring == nil then
		ring = StepTarget.new(player:WaitForChild("PlayerGui"))
	end
	local shown = ring :: StepTarget.StepTarget
	shown:show(target)
	Net.fire("TelemetryReport", ParkFirstLogic.TELEMETRY, "ring")
	local endsAt = os.clock() + ParkFirstLogic.RING_SECONDS
	task.spawn(function()
		-- StepTarget hides by itself when the cat's part leaves (caught or gone)
		while os.clock() < endsAt and target.Parent ~= nil and not caughtPark() do
			task.wait(0.5)
		end
		shown:hide()
	end)
	return true
end

function ParkFirstController.start()
	Net.on("CannonLaunch", function(destination: string, launchAt: number?)
		if destination == ParkFirstLogic.AREA and type(launchAt) == "number" and not toasted then
			task.spawn(toastOnLanding)
		end
	end)
	task.spawn(function()
		local inPark = 0
		while true do
			task.wait(TICK_SECONDS)
			if UI.cannon.area ~= ParkFirstLogic.AREA then
				inPark = 0
				continue
			end
			inPark += TICK_SECONDS
			if ParkFirstLogic.nudgeDue(inPark, caughtPark(), rung) then
				-- no free stray in range yet: look again next second, the visit's clock keeps running
				rung = nudge()
			end
		end
	end)
end

return ParkFirstController
