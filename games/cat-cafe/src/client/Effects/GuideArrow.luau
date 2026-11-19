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

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Presets = require(script.Parent.Presets)

local GuideArrow = {}

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
