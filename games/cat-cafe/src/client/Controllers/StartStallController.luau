--!strict
-- #5562 (Design-Agent's new-start-v2-spec.md, Sync's new start look 2026-11-20: nothing called WorldGlow.stall): the
-- goal chip's stall timer for a save on the play first start (shared/FreeStart). When the goal it shows has not moved
-- for STALL seconds, its thing in the world glows for Presets.worldGlow.stallSeconds (Effects/WorldGlow.stall, switch
-- stallGlow), once per goal: the nearest free stray for "Catch a cat", the nearest camp cannon for "Take it to camp",
-- and after the Tier 2 Rank Up the nearest cannon while CannonGlowArea is set (until the first flight there), each
-- only within REACH studs (#5569: never the Town Square cannon from the Alleyway). Time spent in a catch, a
-- cutscene or a window does not count, so the glow never comes in the middle of something.
-- Client only: it sends nothing.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CannonGlow = require(Shared:WaitForChild("CannonGlow"))
local FreeStart = require(Shared:WaitForChild("FreeStart"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local UI = require(script.Parent.Parent.UI)
local UIController = require(script.Parent.UIController)
local WorldGlow = require(script.Parent.Parent.Effects.WorldGlow)

local StartStallController = {}

local STALL = 11 -- seconds the goal stays where it is before its glow
local POLL = 0.5
-- studs: the stall glow's target is the nearest valid thing this near (Design 2026-11-20: within about 150 studs, in
-- the player's own area; nothing that near, no glow until there is)
local REACH = 150
local STALL_FLAG = "stallGlow" -- Effects/WorldGlow's switch (Presets.worldGlow.stallFlag)

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

-- The nearest Cat Cannon within REACH: a camp cannon for the camp goal, any (the camp's or the Town Square's) for the
-- cannon goal, so the lit camp cannon beside the player wins over the Town Square's far away (Sync 2026-11-20).
local function nearestCannon(campOnly: boolean): Model?
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	local best: Model?, bestDistance = nil, REACH
	for _, instance in CollectionService:GetTagged("CatCannon") do
		local id = instance:GetAttribute("CannonId")
		if
			not instance:IsA("Model")
			or type(id) ~= "string"
			or (campOnly and id == CannonGlow.TOWN)
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
	-- Review-QA on #5563: while stallGlow is off WorldGlow.stall does nothing, so the goal is not marked done
	if ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. STALL_FLAG) ~= true then
		return false
	end
	local target: Model? = if goal == "catch" then nearestStray() else nearestCannon(goal == "camp")
	if target == nil then
		return false
	end
	WorldGlow.stall(target :: Model)
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
