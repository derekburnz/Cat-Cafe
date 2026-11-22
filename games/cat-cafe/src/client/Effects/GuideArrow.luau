--!strict
-- #5465 (Derek 2026-11-19: "the paws for paths for tutorial steps are cute but laggy maybe just make them an arrow
-- beside character"), switch `guideArrow` (off by default): in place of the paw trail, one small chevron lies on the
-- ground just ahead of the player and points straight at the tutorial's target. With the switch on, UI's GuideTrail
-- lays no dots and works out no route; it only writes the target (`target`, a Vector3, nil when there is none or the
-- player has arrived) and the trail's colour (`colour`) on its folder, and this draws the arrow from them. No route
-- means it always shows, also where the far end has not streamed in (the stray on "catch 1 more cat", where the
-- paws went missing). It slides gently toward the target and back; Reduce Motion holds it still. Two parts, moved
-- once a frame, only while the folder is in the Workspace. On this client only; listening only. Numbers in
-- Presets.guideArrow.
-- #5647 (Derek 2026-11-22: "add a little gentle line of arrows slightly transparent", with a picture of chevrons on the
-- ground leading to the goal), switch arrowLine: in place of the one arrow, a line of up to `count` see-through
-- chevrons runs from just ahead of the player toward the target, `spacing` studs apart, each lying on the ground
-- under it (a ray down), with a soft brighter wave running along them toward the target (still with Reduce Motion).
-- The line stops `short` studs before the target and hides inside `arrive`. #5660: with arrowLine on and no tutorial
-- target, the line leads to the lit cannon after any Rank Up that opens an area (WorldGlow.litCannon, every tier).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Context = require(script.Parent.Context)
local Presets = require(script.Parent.Presets)
local WorldGlow = require(script.Parent.WorldGlow)

local GuideArrow = {}

type Chevron = { model: Model, arms: { BasePart } }

local started = false
local folder: Instance? = nil
local arms: { BasePart } = {}
local model: Model? = nil
local clock = 0

-- Where the arrow's middle lies and which way it points, flat: `ahead` studs from `feet` toward `target` plus `slide`
-- (the gentle back and forth). Nil when the target sits straight over or under the feet. Pure.
function GuideArrow.place(
	feet: Vector3,
	target: Vector3,
	ahead: number,
	slide: number
): (Vector3?, Vector3?)
	local way = Vector3.new(target.X - feet.X, 0, target.Z - feet.Z)
	if way.Magnitude < 0.01 then
		return nil, nil
	end
	local forward = way.Unit
	return feet + forward * (ahead + slide), forward
end

-- The slide at `t` seconds: `reach` studs at most, one go every `period` seconds; none with Reduce Motion. Pure.
function GuideArrow.slide(t: number, reach: number, period: number, still: boolean): number
	if still or period <= 0 then
		return 0
	end
	return reach * (0.5 - 0.5 * math.cos(t * 2 * math.pi / period))
end

-- #5647: how far along the way each chevron of the line lies, from `ahead` studs on, `spacing` apart, at most
-- `count`, none closer than `short` to the target `distance` studs away; empty inside `arrive`. Pure.
function GuideArrow.lineSpots(
	distance: number,
	ahead: number,
	spacing: number,
	count: number,
	short: number,
	arrive: number
): { number }
	local out: { number } = {}
	if distance <= arrive then
		return out
	end
	for i = 0, count - 1 do
		local along = ahead + i * spacing
		if along > distance - short then
			break
		end
		table.insert(out, along)
	end
	return out
end

-- #5647: the transparency of chevron `i` of `n` at `t` seconds: `base` at the wave's crest, up to `base + fade`
-- between, the crest running toward the target once every `period` seconds; `base` throughout with Reduce Motion.
function GuideArrow.lineFade(
	i: number,
	n: number,
	t: number,
	base: number,
	fade: number,
	period: number,
	still: boolean
): number
	if still or period <= 0 or n <= 0 then
		return base
	end
	local crest = 0.5 + 0.5 * math.cos(2 * math.pi * (t / period - (i - 1) / n))
	return base + fade * (1 - crest)
end

local function build(): Model
	local p = Presets.guideArrow
	local made = Instance.new("Model")
	made.Name = p.name
	for side = -1, 1, 2 do
		local arm = Instance.new("Part")
		arm.Name = if side < 0 then "Left" else "Right"
		arm.Size = Vector3.new(p.width, p.thick, p.length)
		arm.Material = Enum.Material.Neon
		arm.Transparency = p.transparency
		arm.Anchored = true
		arm.CanCollide = false
		arm.CanQuery = false
		arm.CanTouch = false
		arm.CastShadow = false
		arm.Locked = true
		arm:SetAttribute("Side", side)
		arm.Parent = made
		table.insert(arms, arm)
	end
	return made
end

local function feet(): Vector3?
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	local part = root :: BasePart
	local humanoid = (character :: Model):FindFirstChildOfClass("Humanoid")
	local hip = if humanoid ~= nil then humanoid.HipHeight else 2
	return part.Position - Vector3.new(0, part.Size.Y / 2 + hip, 0)
end

local function hide()
	if model ~= nil then
		model.Parent = nil
	end
end

local function step(dt: number)
	clock += dt
	local trail = folder
	if trail == nil or trail.Parent == nil then
		hide()
		return
	end
	local target = trail:GetAttribute(Presets.guideArrow.target)
	local at = feet()
	if typeof(target) ~= "Vector3" or at == nil then
		hide()
		return
	end
	local p = Presets.guideArrow
	local slide = GuideArrow.slide(clock, p.reach, p.period, Context.reducedMotion())
	local middle, forward = GuideArrow.place(at :: Vector3, target :: Vector3, p.ahead, slide)
	if middle == nil or forward == nil then
		hide()
		return
	end
	local shape = model
	if shape == nil then
		shape = build()
		model = shape
	end
	local colour = trail:GetAttribute(p.colour)
	local frame = CFrame.lookAt(
		middle + Vector3.new(0, p.lift, 0),
		middle + Vector3.new(0, p.lift, 0) + forward
	)
	for _, arm in arms do
		local side = arm:GetAttribute("Side") :: number
		-- each arm runs back from the tip at `spread` off the line, so the two make a ">" pointing forward
		arm.CFrame = frame * CFrame.Angles(0, side * p.spread, 0) * CFrame.new(0, 0, p.length / 2)
		if typeof(colour) == "Color3" and arm.Color ~= colour then
			arm.Color = colour
		end
	end
	if (shape :: Model).Parent ~= Workspace then
		(shape :: Model).Parent = Workspace
	end
end

-- #5647: the arrow line ------------------------------------------------------------------------------------------

local line: { Chevron } = {}
local lineHome: Folder? = nil
local rayParams: RaycastParams? = nil -- made at first use (the test shim has no RaycastParams)

local function lineOn(): boolean
	return ReplicatedStorage:GetAttribute("LiveFlag_" .. Presets.guideArrow.lineFlag) == true
end

local function chevron(index: number): Chevron
	local found = line[index]
	if found ~= nil then
		return found
	end
	local p = Presets.guideArrow
	local home = lineHome
	if home == nil then
		home = Instance.new("Folder")
		home.Name = p.lineName
		lineHome = home
	end
	local made = Instance.new("Model")
	made.Name = "Chevron" .. index
	local parts: { BasePart } = {}
	for side = -1, 1, 2 do
		local arm = Instance.new("Part")
		arm.Name = if side < 0 then "Left" else "Right"
		arm.Size = Vector3.new(p.lineWidth, p.thick, p.lineLength)
		arm.Material = Enum.Material.Neon
		arm.Anchored = true
		arm.CanCollide = false
		arm.CanQuery = false
		arm.CanTouch = false
		arm.CastShadow = false
		arm.Locked = true
		arm:SetAttribute("Side", side)
		arm.Parent = made
		table.insert(parts, arm)
	end
	made.Parent = home
	local c: Chevron = { model = made, arms = parts }
	line[index] = c
	return c
end

local function hideLine()
	if lineHome ~= nil then
		(lineHome :: Folder).Parent = nil
	end
end

-- the ground under `spot` (a ray down from `rise` over it), else `spot` itself
local function ground(spot: Vector3, character: Model?): Vector3
	local p = Presets.guideArrow
	local params = rayParams
	if params == nil then
		params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		rayParams = params
	end
	local made = params :: RaycastParams
	made.FilterDescendantsInstances = if character ~= nil then { character } else {}
	local hit = Workspace:Raycast(
		spot + Vector3.new(0, p.rise, 0),
		Vector3.new(0, -(p.rise + p.drop), 0),
		made
	)
	return if hit ~= nil then hit.Position else spot
end

local function drawLine(at: Vector3, target: Vector3, colour: Color3?)
	local p = Presets.guideArrow
	local way = Vector3.new(target.X - at.X, 0, target.Z - at.Z)
	local count = if Context.lowPerformance then p.lowCount else p.count
	local spots = GuideArrow.lineSpots(way.Magnitude, p.ahead, p.spacing, count, p.short, p.arrive)
	if #spots == 0 then
		hideLine()
		return
	end
	local forward = way.Unit
	local character = Players.LocalPlayer.Character
	local still = Context.reducedMotion()
	local tint = colour or p.lineColour
	for i, along in spots do
		local c = chevron(i)
		local spot = ground(at + forward * along, character)
		local middle = spot + Vector3.new(0, p.lift, 0)
		local frame = CFrame.lookAt(middle, middle + forward)
		local fade =
			GuideArrow.lineFade(i, #spots, clock, p.lineBase, p.lineFade, p.linePeriod, still)
		for _, arm in c.arms do
			local side = arm:GetAttribute("Side") :: number
			arm.CFrame = frame
				* CFrame.Angles(0, side * p.spread, 0)
				* CFrame.new(0, 0, p.lineLength / 2)
			arm.Transparency = fade
			if arm.Color ~= tint then
				arm.Color = tint
			end
		end
		if c.model.Parent == nil then
			c.model.Parent = lineHome
		end
	end
	for i = #spots + 1, #line do
		line[i].model.Parent = nil
	end
	if lineHome ~= nil and (lineHome :: Folder).Parent ~= Workspace then
		(lineHome :: Folder).Parent = Workspace
	end
end

-- one frame of the line: the tutorial's target first, else the lit cannon (#5660)
local function stepLine(dt: number)
	clock += dt
	hide()
	local trail = folder
	local target: unknown = nil
	local colour: unknown = nil
	if trail ~= nil and trail.Parent ~= nil then
		target = trail:GetAttribute(Presets.guideArrow.target)
		colour = trail:GetAttribute(Presets.guideArrow.colour)
	end
	if typeof(target) ~= "Vector3" then
		target = WorldGlow.litCannon()
		colour = nil
	end
	local at = feet()
	if typeof(target) ~= "Vector3" or at == nil then
		hideLine()
		return
	end
	drawLine(at :: Vector3, target :: Vector3, if typeof(colour) == "Color3" then colour else nil)
end

local function consider(child: Instance)
	if child:IsA("Folder") and child.Name == Presets.trailSparkle.folder then
		folder = child
	end
end

function GuideArrow.start()
	if started then
		return
	end
	started = true
	for _, child in Workspace:GetChildren() do
		consider(child)
	end
	Workspace.ChildAdded:Connect(consider)
	RunService.Heartbeat:Connect(function(dt: number)
		if lineOn() then
			stepLine(dt)
			return
		end
		hideLine()
		if folder == nil or (folder :: Instance).Parent == nil then
			if model ~= nil and (model :: Model).Parent ~= nil then
				hide()
			end
			return
		end
		step(dt)
	end)
end

return GuideArrow
