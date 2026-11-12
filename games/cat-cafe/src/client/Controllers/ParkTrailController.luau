--!strict
-- #3554: the goal and paw trail to a first Park catch, rules and words in UI/Components/ParkTrailLogic. Each tick it
-- works out whether they apply (the `parkGateTrail` switch, Tier 2, no Park cat yet), where the trail leads (the
-- nearest Cat Cannon outside the Park, the nearest free stray inside it) and hands both to the UI (UI.parkTrail.set:
-- the goal card's line and the tutorial trail drawn as paw prints). The trail hides while a window is open, a cat is
-- carried or the areas are shut for the night, and rests as ParkTrailLogic.step says. Telemetry: park_trail shown,
-- entered and caught, each once a session.
-- Roblox terms: CollectionService tags are labels on instances; every Cat Cannon model carries "CatCannon".

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Net = require(script.Parent.Parent.Net)
local ParkFirstLogic = require(script.Parent.Parent.UI.Components.ParkFirstLogic)
local ParkTrailLogic = require(script.Parent.Parent.UI.Components.ParkTrailLogic)
local UI = require(script.Parent.Parent.UI)
local UIController = require(script.Parent.UIController)

local ParkTrailController = {}

local player = Players.LocalPlayer
local TICK_SECONDS = 0.5
local CANNON_TAG = "CatCannon"

local rest = ParkTrailLogic.rest()
local lastPhase: ParkTrailLogic.Phase? = nil
local wasDue = false
local sent: { [string]: boolean } = {}

local function report(value: string)
	if not sent[value] then
		sent[value] = true
		Net.fire("TelemetryReport", ParkTrailLogic.TELEMETRY, value)
	end
end

local function areaOf(catId: string): string?
	local def = Catalog.getCat(catId)
	return if def ~= nil then def.area else nil
end

local function root(): BasePart?
	local character = player.Character
	local part = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if part ~= nil and part:IsA("BasePart") then part :: BasePart else nil
end

local function moving(): boolean
	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	return humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0.1
end

-- The nearest Cat Cannon that has streamed in.
local function nearestCannon(from: Vector3): BasePart?
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, model in CollectionService:GetTagged(CANNON_TAG) do
		if not model:IsA("Model") or not model:IsDescendantOf(Workspace) then
			continue
		end
		local part = (model :: Model).PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
		if part ~= nil and part:IsA("BasePart") then
			local distance = ((part :: BasePart).Position - from).Magnitude
			if distance < bestDistance then
				best, bestDistance = part :: BasePart, distance
			end
		end
	end
	return best
end

-- The nearest free Park stray (ParkFirstLogic.pick's rules: not locked by or kept for someone else, not a dropped cat).
local function nearestStray(from: Vector3): BasePart?
	local world = Workspace:FindFirstChild("World")
	local folder = if world ~= nil then world:FindFirstChild("Strays") else nil
	if folder == nil then
		return nil
	end
	local list: { ParkFirstLogic.Stray } = {}
	local parts: { BasePart } = {}
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
	local index = ParkFirstLogic.pick(list, from, player.UserId, ParkTrailLogic.STRAY_RANGE)
	return if index ~= nil then parts[index] else nil
end

local function areasShut(): boolean
	local clock = ReplicatedStorage:FindFirstChild("Clock")
	return clock ~= nil and clock:GetAttribute("AreasOpen") == false
end

local function tick(dt: number)
	local state = UIController.state
	local on = LiveFlags.shown(
		ParkTrailLogic.FLAG,
		ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. ParkTrailLogic.FLAG)
	)
	if state == nil then
		return
	end
	local caught = ParkFirstLogic.caught(state.collection, areaOf)
	if not ParkTrailLogic.due(on, state.tier, caught) then
		if wasDue then
			wasDue = false
			lastPhase = nil
			UI.parkTrail.set(nil, nil)
			if caught and on then
				report(ParkTrailLogic.CAUGHT)
			end
		end
		return
	end
	wasDue = true
	local phase = (ParkTrailLogic.phase(UI.cannon.area) :: any) :: ParkTrailLogic.Phase
	if phase ~= lastPhase then
		if phase == "catch" then
			report(ParkTrailLogic.ENTERED)
		end
		lastPhase = phase
		ParkTrailLogic.restart(rest)
	end
	local goal = ParkTrailLogic.goal(phase)
	local from = root()
	-- the walk is not on while a window is up, a cat is carried or the areas are shut; the rest clock waits too
	if from == nil or UI.isOpen() ~= nil or state.carrying ~= nil or areasShut() then
		UI.parkTrail.set(nil, goal)
		return
	end
	if not ParkTrailLogic.step(rest, dt, moving()) then
		UI.parkTrail.set(nil, goal)
		return
	end
	local target = if phase == "catch"
		then nearestStray(from.Position)
		else nearestCannon(from.Position)
	UI.parkTrail.set(target, goal)
	if target ~= nil then
		report(ParkTrailLogic.SHOWN)
	end
end

function ParkTrailController.start()
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(TICK_SECONDS)
			local now = os.clock()
			tick(now - last)
			last = now
		end
	end)
end

return ParkTrailController
