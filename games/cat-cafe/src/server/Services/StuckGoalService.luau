--!strict
-- #2912 (shared/StuckGoal): the server's part of the stuck cat pointer. ProfileSync carries whether the save waits
-- for its first rescue (CafeService, PlayerState.stuckGoal); this follows each waiting player every CHECK_SECONDS:
-- one more sync when the wait ends (a rescue began), and the two step_time events, each once a session:
-- rescue_trail_shown when the Alleyway's starter trap holds a cat for them while the areas are open, and
-- rescue_trail_followed when they come within StuckGoal.FOLLOWED_STUDS of it in the TRAIL_SECONDS after.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CafeService = require(script.Parent.CafeService)
local ClockService = require(script.Parent.ClockService)
local DataService = require(script.Parent.DataService)
local RescueService = require(script.Parent.RescueService)
local StuckGoal = require(ReplicatedStorage.Shared.StuckGoal)
local Telemetry = require(script.Parent.Telemetry)

local StuckGoalService = {}

local CHECK_SECONDS = 2

type Seen = { waiting: boolean, shownAt: number?, followed: boolean }
local seen: { [Player]: Seen } = {}

local function check(player: Player)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	local entry = seen[player]
	if entry == nil then
		entry = { waiting = false, shownAt = nil :: number?, followed = false } :: Seen
		seen[player] = entry
	end
	local waiting = StuckGoal.waiting(profile)
	if entry.waiting and not waiting then
		CafeService.sync(player) -- the goal card goes back to the rank up
	end
	entry.waiting = waiting
	if not waiting or entry.followed or not ClockService.areasOpen() then
		return
	end
	local cat = RescueService.starterCat(StuckGoal.AREA)
	if cat == nil then
		return
	end
	local now = os.clock()
	if entry.shownAt == nil then
		entry.shownAt = now
		Telemetry.stepTime(player, profile, StuckGoal.SHOWN)
	end
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if
		root ~= nil
		and root:IsA("BasePart")
		and now - (entry.shownAt :: number) <= StuckGoal.TRAIL_SECONDS
		and StuckGoal.followed(root.Position, cat)
	then
		entry.followed = true
		Telemetry.stepTime(player, profile, StuckGoal.FOLLOWED)
	end
end

function StuckGoalService.start()
	Players.PlayerRemoving:Connect(function(player: Player)
		seen[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			for _, player in DataService.loadedPlayers() do
				check(player)
			end
		end
	end)
end

return StuckGoalService
