--!strict
-- #3555: the first rank up's walk-through on this client (shared/RankSpot). The server says when it may show (the
-- Player attribute RankSpotlight, server/Services/RankSpotService: the rank up possible, Tier 1, the safe area, not
-- put away). This controller waits for a free moment (UI.rankSpot.moment), then lights the goal card ("You can rank
-- up!") and, in the rank up window, its button ("Press to rank up"), with the tutorial's own dim and pointer
-- (UI.rankSpot.set). A press on the dim closes it and puts it away for good (TipSeen); the server's word going away
-- (coins spent, out of the safe area, ranked up) only hides it. Nothing shows while the switch is off, because the
-- server never sets the attribute then.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(script.Parent.Parent.Net)
local RankSpot = require(Shared:WaitForChild("RankSpot"))
local UI = require(script.Parent.Parent.UI)

local RankSpotController = {}

local TICK = 0.25

local player = Players.LocalPlayer
local phase: RankSpot.Phase = "none"
local freeSeconds = 0
local putAway = false -- closed by a press on the dim this session; the save has it from the next sync
local reported: { [string]: boolean } = {}

local function report(kind: string)
	if not reported[kind] then
		reported[kind] = true
		Net.fire("TelemetryReport", RankSpot.TELEMETRY, kind)
	end
end

local function show(next: RankSpot.Phase)
	local rankSpot = UI.rankSpot :: any
	if next == "none" then
		rankSpot.set("none")
		phase = "none"
		return
	end
	local shown: boolean = rankSpot.set(next, (RankSpot.WORDS :: any)[next], function()
		-- a press anywhere on the dim: closed, and it does not come back as a dim
		putAway = true
		report("closed")
		Net.fire("TipSeen", RankSpot.SEEN, false)
		rankSpot.set("none")
		phase = "none"
	end)
	phase = if shown then next else "none"
	if shown then
		report("shown")
	end
end

local function tick(dt: number)
	local rankSpot = UI.rankSpot :: any
	local moment: unknown = rankSpot.moment
	if type(moment) ~= "function" then
		return
	end
	local free: boolean, window: string? = (moment :: () -> (boolean, string?))()
	freeSeconds = if free then freeSeconds + dt else 0
	local due = not putAway and player:GetAttribute(RankSpot.ATTRIBUTE) == true
	local next = RankSpot.phase(due, phase, freeSeconds, window)
	if next ~= phase then
		show(next)
	end
end

function RankSpotController.start()
	task.spawn(function()
		while true do
			tick(task.wait(TICK))
		end
	end)
end

return RankSpotController
