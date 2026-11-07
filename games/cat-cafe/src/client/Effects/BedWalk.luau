--!strict
-- The bedtime walk drawn on each client (#2050, Derek2 2026-11-07: cats "appear on a role as greeter then like
-- teleport part by part really quick away"). At nightfall and sunrise the server used to step every working cat's
-- anchored model along its trip each frame, and on a live server each part's move replicated on its own, so a cat
-- came apart on the way. Now the server leaves the model where it is, sets the trip on it (Gameplay-Engineer's
-- BedTripAt, BedTripSpeed, BedTripHop, BedTripRoute and BedTripTo; Shared.Bedtime reads them) and pivots it once
-- onto the bed when the trip ends. While BedTripAt is set this client hides that model and walks a local copy of it
-- along the route by server time (a late joiner starts partway), trotting on the floor and hopping up the cat trees
-- and beds, then shows the model again once it has landed, fading the copy out over Presets.bedWalk.fade.
-- Any cafe's cats, within the animation radius; past it, or with Reduce Motion, nothing is drawn and the cat just
-- appears at the end. The copy never collides or blocks a click; nothing here fires a remote or moves the model.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Bedtime = require(ReplicatedStorage.Shared.Bedtime)
local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Pose = require(script.Parent.Pose)
local Presets = require(script.Parent.Presets)

local BedWalk = {}

-- The local mark Cats.luau reads to leave a model alone while its copy walks.
BedWalk.MARK = "BedWalkLocal"

type Walk = {
	model: Model,
	copy: Model,
	rig: Pose.Rig,
	hidden: { BasePart },
	shown: { BasePart },
	points: { Bedtime.TripPoint },
	speed: number,
	hop: number,
	at: number, -- server time the trip starts
	seconds: number,
	stride: number,
	phase: number,
	lastPosition: Vector3?,
	endedAt: number?, -- os.clock() the trip ended (BedTripAt cleared), as the copy fades out
}

local walks: { [Model]: Walk } = {}
local watched: { [Model]: RBXScriptConnection } = {}
local stepping: RBXScriptConnection? = nil
local started = false

local TRIP = "BedTripAt"

local function partsOf(model: Model): { BasePart }
	local parts: { BasePart } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant :: BasePart)
		end
	end
	return parts
end

local function setFade(parts: { BasePart }, k: number)
	for _, part in parts do
		if part.Parent ~= nil then
			part.LocalTransparencyModifier = k
		end
	end
end

local function finish(walk: Walk)
	walks[walk.model] = nil
	setFade(walk.hidden, 0)
	if walk.model.Parent ~= nil then
		walk.model:SetAttribute(BedWalk.MARK, nil)
	end
	walk.copy:Destroy()
end

-- The trip on `model` as numbers, or nil when it carries none or the route does not read.
local function tripOf(model: Model): ({ Bedtime.TripPoint }?, number, number, number)
	local at = model:GetAttribute(TRIP)
	local route = model:GetAttribute("BedTripRoute")
	local speed = model:GetAttribute("BedTripSpeed")
	local hop = model:GetAttribute("BedTripHop")
	if type(at) ~= "number" or type(route) ~= "string" then
		return nil, 0, 0, 0
	end
	local points = Bedtime.decodeTrip(route)
	if points == nil or #points < 2 then
		return nil, 0, 0, 0
	end
	return points,
		at,
		if type(speed) == "number" and speed > 0 then speed else 6,
		if type(hop) == "number" and hop > 0 then hop else 0.45
end

local function begin(model: Model)
	if walks[model] ~= nil or Context.reducedMotion() then
		return
	end
	local points, at, speed, hop = tripOf(model)
	if points == nil then
		return
	end
	if Context.distance(model:GetPivot().Position) > Context.budget.animRadius then
		return
	end
	local copy = model:Clone() :: Model
	copy.Name = "BedWalker"
	for _, descendant in copy:GetDescendants() do
		if descendant:IsA("BillboardGui") or descendant:IsA("ParticleEmitter") then
			descendant:Destroy() -- the rate tag and sparkles stay on the hidden model
		end
	end
	local shown = partsOf(copy)
	for _, part in shown do
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.LocalTransparencyModifier = 0
	end
	copy.Parent = Context.folder()
	local rig = Pose.bind(copy)
	if rig == nil or rig.usesMotors then
		copy:Destroy()
		return
	end
	local hidden = partsOf(model)
	setFade(hidden, 1)
	model:SetAttribute(BedWalk.MARK, true)
	walks[model] = {
		model = model,
		copy = copy,
		rig = rig,
		hidden = hidden,
		shown = shown,
		points = points,
		speed = speed,
		hop = hop,
		at = at,
		seconds = Bedtime.tripSeconds(points, speed, hop),
		stride = 0,
		phase = Logic.phaseOf(tostring(model:GetAttribute("Uid") or model.Name)) * 100,
		lastPosition = nil,
		endedAt = nil,
	}
	if stepping == nil then
		stepping = RunService.PreRender:Connect(BedWalk.step)
	end
end

local function advance(walk: Walk, now: number, serverNow: number, dt: number): boolean
	local b = Presets.bedWalk
	local t = math.clamp(serverNow - walk.at, 0, walk.seconds)
	local position, look = Bedtime.tripAt(walk.points, walk.speed, walk.hop, t)
	local flat = Vector3.new(look.X, 0, look.Z)
	local yaw = Logic.yawOf(if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1))
	local last = walk.lastPosition
	local moved = if last ~= nil
		then Vector3.new(position.X - last.X, 0, position.Z - last.Z).Magnitude
		else 0
	walk.lastPosition = position
	-- the legs go at the speed it crosses the floor (a hop straight up barely strides)
	local speed = if t >= walk.seconds or dt <= 0 then 0 else math.min(moved / dt, walk.speed * 1.5)
	walk.stride += speed * dt / Logic.strideLength(math.max(speed, 0.1))
	local rig = walk.rig
	if not Pose.read(rig) then
		return false
	end
	Pose.hold(rig, CFrame.new(position) * CFrame.Angles(0, yaw, 0))
	local o = Logic.idle("stray", now + walk.phase, rig.kind)
	Logic.gait(o, speed, walk.stride, 0)
	Pose.draw(rig, o, -1)
	-- the end: once the server has landed the model (BedTripAt cleared), it shows again as the copy fades out
	local ended = walk.endedAt
	if ended ~= nil then
		local k = math.clamp((now - ended) / b.fade, 0, 1)
		setFade(walk.shown, k)
		setFade(walk.hidden, 1 - k)
		if k >= 1 then
			return false
		end
	end
	return true
end

function BedWalk.step(dt: number)
	local now = os.clock()
	local serverNow = Workspace:GetServerTimeNow()
	for model, walk in walks do
		if model.Parent == nil or walk.copy.Parent == nil then
			finish(walk)
			continue
		end
		if not advance(walk, now, serverNow, dt) then
			finish(walk)
		end
	end
	if next(walks) == nil and stepping ~= nil then
		stepping:Disconnect()
		stepping = nil
	end
end

-- Whether `model`'s bedtime trip is being drawn by its copy here (Cats.luau leaves the model alone meanwhile).
function BedWalk.isWalking(model: Model): boolean
	return walks[model] ~= nil
end

local function watch(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local model = instance :: Model
	local had: RBXScriptConnection? = watched[model]
	if had then
		return
	end
	watched[model] = model:GetAttributeChangedSignal(TRIP):Connect(function()
		local walk = walks[model]
		local at = model:GetAttribute(TRIP)
		if at == nil then
			if walk ~= nil and walk.endedAt == nil then
				walk.endedAt = os.clock() -- landed: the model shows again as the copy fades
			end
		elseif walk == nil or walk.at ~= at then
			if walk ~= nil then
				finish(walk) -- a new trip on the same model (back to the station at sunrise): this one gives way
			end
			begin(model)
		end
	end)
	begin(model)
end

local function unwatch(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local model = instance :: Model
	local connection: RBXScriptConnection? = watched[model]
	if connection then
		connection:Disconnect()
		watched[model] = nil
	end
	local walk = walks[model]
	if walk ~= nil then
		finish(walk)
	end
end

function BedWalk.start()
	if started then
		return
	end
	started = true
	CollectionService:GetInstanceAddedSignal("WorkingCat"):Connect(watch)
	CollectionService:GetInstanceRemovedSignal("WorkingCat"):Connect(unwatch)
	for _, instance in CollectionService:GetTagged("WorkingCat") do
		watch(instance)
	end
end

return BedWalk
