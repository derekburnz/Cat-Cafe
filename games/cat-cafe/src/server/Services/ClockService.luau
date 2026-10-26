--!strict
-- The day and night clock (data-model section 9, features F20). The phase comes from shared/Clock.luau applied to
-- the time since this server started: day with ServerStartDaySeconds left, then night and day forever. It is
-- published as attributes on ReplicatedStorage.Clock (Phase, PhaseEndsAt) so clients read it without a remote.
-- PhaseEndsAt is on the Workspace:GetServerTimeNow() clock, which every client shares, so a countdown never trusts
-- the device clock.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Types = require(ReplicatedStorage.Shared.Types)

local ClockService = {}

-- Fires (phase, phaseEndsAt) after the attributes change. Night start is when waves and rescue spots roll.
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

-- Server time (Workspace:GetServerTimeNow()) when the current phase ends.
function ClockService.phaseEndsAt(): number
	return currentEndsAt
end

-- Studio-only test hook: jump to the start of a phase at its full length. Jumping to night rolls a wave at once.
function ClockService.debugSetPhase(phase: Types.ClockPhase)
	assert(RunService:IsStudio(), "debugSetPhase is Studio only")
	startedAt = os.clock() - Clock.startOf(phase)
	published = false
	tick()
end

return ClockService
