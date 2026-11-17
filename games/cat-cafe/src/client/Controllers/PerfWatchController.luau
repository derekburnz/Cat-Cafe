--!strict
-- #4783: reports this client's load and frame rate through TelemetryReport (shared/PerfWatch). Analytics only;
-- nothing is shown and nothing is changed.
--   load_ready: once, the seconds from the client's first script line to the world ready (game loaded, the first
--     ProfileSync, own character's root in)
--   fps_avg: at each PerfWatch.MARKS minute, the average frames a second since the mark before, with the graphics
--     quality the player set (0 Automatic)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(script.Parent.Parent.Net)
local PerfWatch = require(Shared:WaitForChild("PerfWatch"))

local PerfWatchController = {}

local isSynced = false
local syncedSignal = Instance.new("BindableEvent")

-- Main calls this on the first ProfileSync (the same moment it reports boot_sync).
function PerfWatchController.synced()
	if not isSynced then
		isSynced = true
		syncedSignal:Fire()
	end
end

local function savedQuality(): number
	local ok, level = pcall(function(): number
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	return if ok and type(level) == "number" then level else 0
end

local function waitReady(bootAt: number)
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	if not isSynced then
		syncedSignal.Event:Wait()
	end
	local player = Players.LocalPlayer
	local character = player.Character or player.CharacterAdded:Wait()
	character:WaitForChild("HumanoidRootPart")
	Net.fire("TelemetryReport", PerfWatch.READY, math.min(os.clock() - bootAt, PerfWatch.MAX_READY))
end

local function watchFps()
	local frames, seconds = 0, 0
	local counting = RunService.RenderStepped:Connect(function(dt: number)
		if dt <= PerfWatch.GAP_SECONDS then
			frames += 1
			seconds += dt
		end
	end)
	local started = os.clock()
	for markIndex, minutes in PerfWatch.MARKS do
		task.wait(math.max(0, minutes * 60 - (os.clock() - started)))
		if frames > 0 then -- a window spent all in the background says nothing about the device
			Net.fire(
				"TelemetryReport",
				PerfWatch.FPS,
				PerfWatch.encode(markIndex, savedQuality(), PerfWatch.average(frames, seconds))
			)
		end
		frames, seconds = 0, 0
	end
	counting:Disconnect()
end

-- `bootAt` is os.clock() at the client's first script line (Main).
function PerfWatchController.start(bootAt: number)
	task.spawn(waitReady, bootAt)
	task.spawn(watchFps)
end

return PerfWatchController
