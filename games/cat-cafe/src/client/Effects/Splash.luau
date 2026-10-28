--!strict
-- Walking through water (Derek 2026-10-28 01:33: "little water splashes while walking through water"): a player or a
-- stray walking through a puddle, a pond, a pool or a fountain kicks up a few droplets and leaves a small ripple on
-- the water with each step, alternating feet, and one more as it steps in. Standing still, walking past the edge or
-- on a fountain's rim makes none. Everyone nearby sees everyone's.
--
-- Source: the world's water, any part whose name ends in "Water" or "Puddle" (Logic.isWaterName: the placeholders'
-- Water, every model's ..._Water, the Alley's puddles), found as it streams in; players' characters and Stray-tagged
-- cats, measured at their feet a few times a second (Logic.wading, Logic.waterStep). Listening only. Numbers in
-- Presets.splash; `Splash.stepped` fires for each splash so Audio can play a soft step on it.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Signal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Signal"))

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local Splash = {}

-- (position on the water, kind "player" | "cat") for each splash this client shows.
Splash.stepped = Signal.new() :: Signal.Signal<Vector3, string>

type Walker = {
	last: Vector3?,
	at: number, -- os.clock() of `last`
	carried: number, -- studs walked in the water since the last splash
	wet: boolean,
	side: number, -- the foot the next splash is under: 1 or -1
}

local water: { [BasePart]: boolean } = {}
local walkers: { [Model]: Walker } = setmetatable({}, { __mode = "k" }) :: any
local started = false

local function consider(instance: Instance)
	if instance:IsA("BasePart") and Logic.isWaterName(instance.Name) then
		water[instance :: BasePart] = true
	end
end

-- Where on the water `foot` stands, or nil when it is not in any. The water is a flat plate: its thinnest axis is
-- its up, and one standing on its side (a waterfall's sheet) is not walked through.
local function surfaceUnder(foot: Vector3): Vector3?
	for part in water do
		if part.Parent == nil then
			water[part] = nil
			continue
		end
		local size = part.Size
		local reach = math.max(size.X, size.Y, size.Z) / 2 + 1
		local offset = foot - part.Position
		if math.abs(offset.X) > reach or math.abs(offset.Z) > reach then
			continue
		end
		local frame = part.CFrame
		local rel = frame:PointToObjectSpace(foot)
		local up: Vector3, along: number, half: number, u: number, v: number, halfU: number, halfV: number
		if size.X <= size.Y and size.X <= size.Z then
			up, along, half, u, v, halfU, halfV =
				frame.XVector, rel.X, size.X / 2, rel.Y, rel.Z, size.Y / 2, size.Z / 2
		elseif size.Y <= size.Z then
			up, along, half, u, v, halfU, halfV =
				frame.YVector, rel.Y, size.Y / 2, rel.X, rel.Z, size.X / 2, size.Z / 2
		else
			up, along, half, u, v, halfU, halfV =
				frame.ZVector, rel.Z, size.Z / 2, rel.X, rel.Y, size.X / 2, size.Y / 2
		end
		if math.abs(up.Y) < Presets.splash.flat then
			continue
		end
		local height = (if up.Y < 0 then -along else along) - half -- above the water's top
		-- a cylinder's round faces are across its X axis
		local round = up == frame.XVector
			and part:IsA("Part")
			and (part :: Part).Shape == Enum.PartType.Cylinder
		if Logic.wading(height, u, v, halfU, halfV, round) then
			return foot - Vector3.new(0, height, 0)
		end
	end
	return nil
end

local function ripple(at: Vector3, diameter: number)
	local s = Presets.splash
	local ring =
		Context.effectPart("Ripple", Vector3.new(0.05, s.rippleFrom, s.rippleFrom), s.rippleColour)
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency = s.rippleTransparency
	ring.CFrame = CFrame.new(at + Vector3.new(0, 0.04, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = Context.folder()
	TweenService:Create(
		ring,
		TweenInfo.new(s.rippleSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.05, diameter, diameter), Transparency = 1 }
	):Play()
	Debris:AddItem(ring, s.rippleSeconds + 0.1)
end

local function splash(at: Vector3, kind: string)
	local s = Presets.splash
	ripple(at, s.ripple[kind])
	Particles.burst("splashDrops", at + Vector3.new(0, 0.1, 0), s.drops[kind])
	Splash.stepped:Fire(at, kind)
end

-- One walker's feet this tick: a splash on stepping in, then one every stride while it keeps walking in the water.
local function step(model: Model, foot: Vector3, sideways: Vector3, kind: string)
	local s = Presets.splash
	local w: Walker = walkers[model]
		or { last = nil, at = 0, carried = 0, wet = false, side = 1 } :: Walker
	walkers[model] = w
	local last, now = w.last, os.clock()
	local seconds = now - w.at
	w.last, w.at = foot, now
	if last == nil or seconds <= 0 then
		return
	end
	local flat = Vector3.new(foot.X - last.X, 0, foot.Z - last.Z)
	local moved = flat.Magnitude
	local surface = if moved / seconds >= s.minSpeed then surfaceUnder(foot) else nil
	if surface == nil then
		w.wet = false
		w.carried = 0
		return
	end
	local due: boolean
	if not w.wet then
		w.wet, due, w.carried = true, true, 0
	else
		due, w.carried = Logic.waterStep(w.carried, moved, s.stride[kind])
	end
	if due then
		local across = if moved > 1e-3 then Vector3.new(-flat.Z, 0, flat.X).Unit else sideways
		splash((surface :: Vector3) + across * s.side[kind] * w.side, kind)
		w.side = -w.side
	end
end

local function feetOfCharacter(character: Model): (Vector3?, Vector3)
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root == nil or not root:IsA("BasePart") or humanoid == nil or humanoid.Health <= 0 then
		return nil, Vector3.xAxis
	end
	local body = root :: BasePart
	return body.Position - Vector3.new(0, body.Size.Y / 2 + humanoid.HipHeight, 0),
		body.CFrame.RightVector
end

local function feetOfCat(cat: Model): (Vector3?, Vector3)
	if cat:FindFirstChildWhichIsA("BasePart", true) == nil then
		return nil, Vector3.xAxis
	end
	local frame, size = cat:GetBoundingBox()
	return frame.Position - Vector3.new(0, Logic.halfExtents(frame, size).Y, 0), frame.RightVector
end

local function check()
	local focus = Context.focus()
	if focus == nil or next(water) == nil then
		return
	end
	local s = Presets.splash
	local most = if Context.lowPerformance
		then s.most.saver
		elseif Context.tier == "low" then s.most.low
		else s.most.high
	local candidates: { Logic.Candidate<Model> } = {}
	local kinds: { [Model]: string } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character ~= nil then
			kinds[character] = "player"
			table.insert(candidates, {
				key = character,
				distance = if player == Players.LocalPlayer
					then 0
					else Context.distance(character:GetPivot().Position),
			})
		end
	end
	for _, instance in CollectionService:GetTagged("Stray") do
		if instance:IsA("Model") and instance:IsDescendantOf(Workspace) then
			local cat = instance :: Model
			kinds[cat] = "cat"
			table.insert(
				candidates,
				{ key = cat, distance = Context.distance(cat:GetPivot().Position) }
			)
		end
	end
	local chosen: { [Model]: boolean } = {}
	for _, model in Logic.nearest(candidates, s.maxDistance, most) do
		chosen[model] = true
		local kind = kinds[model]
		local foot, sideways
		if kind == "player" then
			foot, sideways = feetOfCharacter(model)
		else
			foot, sideways = feetOfCat(model)
		end
		if foot ~= nil then
			step(model, foot, sideways, kind)
		else
			walkers[model] = nil
		end
	end
	for model in walkers do
		if not chosen[model] then
			walkers[model] = nil -- starts afresh when it is next near, so no splash for the distance in between
		end
	end
end

function Splash.start()
	if started then
		return
	end
	started = true
	Workspace.DescendantAdded:Connect(consider)
	task.spawn(function()
		for _, descendant in Workspace:GetDescendants() do
			consider(descendant)
		end
		while true do
			check()
			task.wait(Presets.splash.checkEvery)
		end
	end)
end

return Splash
