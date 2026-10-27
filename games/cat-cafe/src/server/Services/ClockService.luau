--!strict
-- The day and night clock (data-model section 9, features F20). The phase comes from shared/Clock.luau applied to
-- the time since this server started: day with ServerStartDaySeconds left, then night and day forever. It is
-- published as attributes on ReplicatedStorage.Clock (Phase, PhaseEndsAt) so clients read it without a remote.
-- PhaseEndsAt is on the Workspace:GetServerTimeNow() clock, which every client shares, so a countdown never trusts
-- the device clock. v0.9 (F66): AreasOpen is false from night start to sunrise, when the catching areas are closed
-- (the client's fences, the travel buttons); NightService does the closing and opening on `changed`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Types = require(ReplicatedStorage.Shared.Types)

local ClockService = {}

-- Fires (phase, phaseEndsAt) after the attributes change. NightService closes the areas at night start and spawns
-- the sunrise wave at day start.
ClockService.changed = Signal.new() :: Signal.Signal<Types.ClockPhase, number>

local clockFolder: Folder? = nil
local startedAt = 0 -- os.clock() when the server started; debugSetPhase shifts it
local currentPhase: Types.ClockPhase = "day"
local currentEndsAt = 0
local published = false
local generation = 0 -- bumps on every reschedule, so a timer from before a debug jump never fires

local function publish(phase: Types.ClockPhase, secondsLeft: number)
	published = true
	currentPhase = phase
	currentEndsAt = Workspace:GetServerTimeNow() + secondsLeft
	local folder = clockFolder
	if folder ~= nil then
		folder:SetAttribute("Phase", phase)
		folder:SetAttribute("PhaseEndsAt", currentEndsAt)
		folder:SetAttribute("AreasOpen", phase == "day")
	end
	ClockService.changed:Fire(phase, currentEndsAt)
end

-- Publishes the phase if it changed, then sleeps until it ends.
local function tick()
	generation += 1
	local myGeneration = generation
	local phase: Types.ClockPhase, secondsLeft: number = Clock.phaseAt(os.clock() - startedAt)
	if not published or phase ~= currentPhase then
		publish(phase, secondsLeft)
	end
	task.delay(secondsLeft, function()
		if generation == myGeneration then
			tick()
		end
	end)
end

function ClockService.start()
	local existing = ReplicatedStorage:FindFirstChild("Clock")
	if existing ~= nil and existing:IsA("Folder") then
		clockFolder = existing :: Folder
	else
		local created = Instance.new("Folder")
		created.Name = "Clock"
		created.Parent = ReplicatedStorage
		clockFolder = created
	end
	startedAt = os.clock()
	tick()
end

function ClockService.phase(): Types.ClockPhase
	return currentPhase
end

function ClockService.isNight(): boolean
	return currentPhase == "night"
end

-- False from night start to sunrise (F66): no catching, rescuing, shoving or travelling into the areas.
function ClockService.areasOpen(): boolean
	return currentPhase == "day"
end

-- Server time (Workspace:GetServerTimeNow()) when the current phase ends.
function ClockService.phaseEndsAt(): number
	return currentEndsAt
end

-- The os.time() at which this server's clock read 0, for Economy.settle to split a window at phase boundaries
-- (data-model section 11). A debug jump moves it, so a window that spans the jump is settled as the new clock says.
function ClockService.epoch(): number
	return os.time() - (os.clock() - startedAt)
end

-- Studio-only test hook: jump to the start of a phase at its full length. Jumping to night closes the areas at
-- once; jumping to day spawns the sunrise wave.
function ClockService.debugSetPhase(phase: Types.ClockPhase)
	assert(RunService:IsStudio(), "debugSetPhase is Studio only")
	startedAt = os.clock() - Clock.startOf(phase)
	published = false
	tick()
end

return ClockService
