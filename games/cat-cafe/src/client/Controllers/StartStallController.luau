--!strict
-- #5562 (Design-Agent's new-start-v2-spec.md, Sync's new start look 2026-11-20: nothing called WorldGlow.stall): the
-- goal chip's stall timer for a save on the play first start (shared/FreeStart). When the goal it shows has not moved
-- for STALL seconds, its thing in the world glows for Presets.worldGlow.stallSeconds (Effects/WorldGlow.stall, switch
-- stallGlow), once per goal: the nearest free stray for "Catch a cat", the camp for "Take it to camp", and after the
-- Tier 2 Rank Up the cannon while CannonGlowArea is set (until the first flight there). Time spent in a catch, a
-- cutscene or a window does not count, so the glow never comes in the middle of something.
-- Client only: it sends nothing.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CannonGlow = require(Shared:WaitForChild("CannonGlow"))
local FreeStart = require(Shared:WaitForChild("FreeStart"))
local UI = require(script.Parent.Parent.UI)
local UIController = require(script.Parent.UIController)
local WorldGlow = require(script.Parent.Parent.Effects.WorldGlow)

local StartStallController = {}

local STALL = 11 -- seconds the goal stays where it is before its glow
local POLL = 0.5
local REACH = 120 -- studs: a stray farther than this is not "the nearest cat"

local started = false
local glowed: { [string]: boolean } = {} -- the goals that have had their glow (once each)

-- The goal the chip shows now, for a save on the play first start: "catch", "camp", "cannon" or nil.
function StartStallController.goalOf(
	free: boolean,
	tier: number,
	goals: { caught: boolean, home: boolean }?,
	glowArea: unknown
): string?
	if not free then
		return nil
	end
	if goals ~= nil and not goals.caught then
		return "catch"
	end
	if goals ~= nil and not goals.home then
		return "camp"
	end
	if tier >= 2 and type(glowArea) == "string" and glowArea ~= "" then
		return "cannon"
	end
	return nil
end

-- Whether something else holds the player now (a catch, a carry for the catch goal, a window, a cutscene).
local function busy(goal: string): boolean
	local u: any = UI
	local circles: any = if u.catch ~= nil then u.catch.circlesActive else nil
	if type(circles) == "function" and (circles :: () -> boolean)() == true then
		return true
	end
	if u.isOpen() ~= nil then
		return true
	end
	local held: any = if u.cutscene ~= nil then u.cutscene.held else nil
	if type(held) == "function" and (held :: () -> boolean)() == true then
		return true
	end
	local character = Players.LocalPlayer.Character
	if character == nil then
		return true
	end
	-- a cat in hand is the catch goal done a moment before the server says so
	return goal == "catch" and character:GetAttribute("CarryingCatId") ~= nil
end

-- The nearest stray that can be caught now (not running, not in someone else's catch), within REACH.
local function nearestStray(): Model?
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	local now = Workspace:GetServerTimeNow()
	local best: Model?, bestDistance = nil, REACH
	for _, instance in CollectionService:GetTagged("Stray") do
		if not instance:IsA("Model") or not instance:IsDescendantOf(Workspace) then
			continue
		end
		local fleeing = instance:GetAttribute("FleeingUntil")
		local locked = instance:GetAttribute("LockedBy")
		if
			(type(fleeing) == "number" and fleeing > now)
			or (type(locked) == "number" and locked ~= 0 and locked ~= Players.LocalPlayer.UserId)
		then
			continue
		end
		local model = instance :: Model
		local distance = (model:GetPivot().Position - (root :: BasePart).Position).Magnitude
		if distance < bestDistance then
			best, bestDistance = model, distance
		end
	end
	return best
end

local function glow(goal: string): boolean
	if goal == "catch" then
		local stray = nearestStray()
		if stray == nil then
			return false
		end
		WorldGlow.stall(stray)
	elseif goal == "camp" then
		WorldGlow.stall("camp")
	else
		WorldGlow.stall("cannon")
	end
	return true
end

function StartStallController.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		local current: string? = nil
		local still = 0
		while true do
			local dt = task.wait(POLL)
			local state: any = UIController.state
			local goal = if state ~= nil
				then StartStallController.goalOf(
					FreeStart.quiet(state.tier),
					if type(state.tier) == "number" then state.tier else 1,
					state.startGoals,
					Players.LocalPlayer:GetAttribute(CannonGlow.ATTR)
				)
				else nil
			if goal ~= current then
				current, still = goal, 0
			elseif goal ~= nil and not glowed[goal :: string] then
				local now = goal :: string
				if busy(now) then
					still = 0
				else
					still += dt
					if still >= STALL and glow(now) then
						glowed[now] = true
					end
				end
			end
		end
	end)
end

return StartStallController
