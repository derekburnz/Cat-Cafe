--!strict
-- The Water Park's rides turn (#4070): the carousel and the teacups about their middles, the Ferris wheel about its
-- hub, slowly and on this client only. Model-Agent built each turning piece as its own Model in the area set
-- (waterparkset.py), named ending `CarouselTurn`, `TeacupsTurn` or `FerrisTurn`; the Ferris wheel's pods are drums on
-- the wheel's own axis, so turning the whole wheel leaves them looking upright.
--
-- The set's Models keep their pivots at the set's origin, so the axis is read from the piece itself: through the
-- middle of its box, straight up for the carousel and the teacups, along the box's thin side for the wheel
-- (Logic.rideAxis). The box is measured on the piece's copy in ReplicatedStorage.Assets where there is one, since
-- that copy is always whole while the one in the world may still be streaming in, and carried over through the
-- piece's PrimaryPart. A piece only turns once every part of it is here and anchored; if a part streams in or the
-- server moves it after that, it goes back to where it was built and is read again.
--
-- Budgets: the nearest `most` rides within `radius` studs turn, one on a device with no decor motion (phones on the
-- lite budget), at the budget's update rate and never faster than `hz`. Reduce Motion and Low performance leave
-- every ride still. A ride that stops stays where it is, so nothing snaps back in view. Numbers in Presets.rides.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Presets = require(script.Parent.Presets)

local Rides = {}

type Ride = {
	model: Model,
	spec: Presets.Ride,
	bound: boolean,
	base: CFrame, -- its pivot as built
	centre: Vector3, -- a point on its axis
	axis: Vector3,
	degrees: number, -- how far it has turned from `base`
	written: CFrame?, -- where this client last put it
	parts: number, -- how many parts it had when read
	moving: boolean,
	added: RBXScriptConnection?,
}

local rides: { [Model]: Ride } = {}
local moving: { Ride } = {}
local lastStep = 0
local started = false

local function specOf(name: string): Presets.Ride?
	for suffix, spec in Presets.rides.kinds do
		if string.sub(name, -#suffix) == suffix then
			return spec
		end
	end
	return nil
end

-- The piece's copy in ReplicatedStorage.Assets, which is never streamed.
local function templateOf(model: Model): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local found = if assets ~= nil then assets:FindFirstChild(model.Name, true) else nil
	if found ~= nil and found:IsA("Model") then
		return found :: Model
	end
	return nil
end

local function partsOf(model: Model): (number, boolean)
	local count, anchored = 0, true
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			count += 1
			anchored = anchored and (descendant :: BasePart).Anchored
		end
	end
	return count, anchored
end

-- Whether something else (the server, or a part streaming in again) moved it since this client last put it.
local function movedOff(ride: Ride): boolean
	local written = ride.written
	if written == nil then
		return false
	end
	local now = ride.model:GetPivot()
	return (now.Position - written.Position).Magnitude > 0.01
		or now.LookVector:Dot(written.LookVector) < 0.9999
end

-- Reads a ride where it stands: its axis and the pivot it turns from. False while it is not all here.
local function bind(ride: Ride): boolean
	local model = ride.model
	local count, anchored = partsOf(model)
	if count == 0 or not anchored then
		return false
	end
	local box: CFrame, size: Vector3
	local template = templateOf(model)
	local primary = model.PrimaryPart
	local templatePrimary = if template ~= nil then template.PrimaryPart else nil
	if template ~= nil and primary ~= nil and templatePrimary ~= nil then
		if partsOf(template) ~= count then
			return false -- still streaming in
		end
		local templateBox: CFrame
		templateBox, size = template:GetBoundingBox()
		box = primary.CFrame * templatePrimary.CFrame:ToObjectSpace(templateBox)
	else
		box, size = model:GetBoundingBox()
	end
	ride.base = model:GetPivot()
	ride.centre = box.Position
	ride.axis = Logic.rideAxis(ride.spec.axis, size, box.RightVector, box.LookVector)
	ride.degrees = 0
	ride.written = nil
	ride.parts = count
	ride.bound = true
	return true
end

local function place(ride: Ride)
	-- a turn of `degrees` about the line through `centre` along `axis`, in front of the pivot as built
	local turn = CFrame.new(ride.centre)
		* CFrame.fromAxisAngle(ride.axis, math.rad(ride.degrees))
		* CFrame.new(-ride.centre)
	local cframe = turn * ride.base
	ride.model:PivotTo(cframe)
	ride.written = cframe
end

-- Back to where it was built, to be read again: only when the model no longer matches what was read.
local function reset(ride: Ride)
	if ride.bound and ride.model.Parent ~= nil and ride.written ~= nil and not movedOff(ride) then
		ride.model:PivotTo(ride.base)
	end
	ride.bound = false
	ride.written = nil
	ride.moving = false
end

local function consider(instance: Instance)
	if not instance:IsA("Model") or rides[instance :: Model] ~= nil then
		return
	end
	local spec = specOf(instance.Name)
	if spec == nil then
		return
	end
	local model = instance :: Model
	local ride: Ride = {
		model = model,
		spec = spec,
		bound = false,
		base = CFrame.new(),
		centre = Vector3.zero,
		axis = Vector3.yAxis,
		degrees = 0,
		written = nil,
		parts = 0,
		moving = false,
		added = nil,
	}
	rides[model] = ride
	-- a part arriving after the ride was read stands where the server built it, not where the ride has turned to
	ride.added = model.DescendantAdded:Connect(function(descendant: Instance)
		if ride.bound and descendant:IsA("BasePart") then
			reset(ride)
		end
	end)
end

-- How many rides may turn at once on this device.
local function most(): number
	if Context.reducedMotion() or Context.lowPerformance then
		return 0
	end
	local p = Presets.rides
	return if Context.budget.decorMotion > 0 then p.most else p.mostLite
end

-- Every `pick` seconds: the nearest few within `radius` turn; the rest stay where they are.
local function pick()
	local limit = most()
	local candidates: { Logic.Candidate<Ride> } = {}
	for model, ride in rides do
		if not model:IsDescendantOf(Workspace) then
			local added = ride.added
			if added ~= nil then
				added:Disconnect()
			end
			rides[model] = nil
		elseif limit > 0 then
			-- the set's pivot is far from the ride: measure to the ride's own axis once it is read
			local at = if ride.bound then ride.centre else model:GetBoundingBox().Position
			table.insert(candidates, { key = ride, distance = Context.distance(at) })
		end
	end
	local on: { [Ride]: boolean } = {}
	local now: { Ride } = {}
	if limit > 0 then
		for _, ride in Logic.nearest(candidates, Presets.rides.radius, limit) do
			if ride.bound and (movedOff(ride) or partsOf(ride.model) ~= ride.parts) then
				reset(ride)
			end
			if ride.bound or bind(ride) then
				on[ride] = true
				ride.moving = true
				table.insert(now, ride)
			end
		end
	end
	for _, ride in moving do
		if not on[ride] then
			ride.moving = false
		end
	end
	moving = now
end

local function step()
	local now = os.clock()
	local hz = math.min(Context.budget.animHz, Presets.rides.hz)
	local dt = now - lastStep
	if dt < 1 / hz then
		return
	end
	lastStep = now
	dt = math.min(dt, Presets.rides.longest) -- after a hitch the ride carries on, it does not leap
	for _, ride in moving do
		if ride.moving and ride.bound and ride.model.Parent ~= nil then
			if movedOff(ride) then
				reset(ride)
			else
				ride.degrees = (ride.degrees + dt * 360 / ride.spec.seconds) % 360
				place(ride)
			end
		end
	end
end

function Rides.start()
	if started then
		return
	end
	started = true
	for _, descendant in Workspace:GetDescendants() do
		consider(descendant)
	end
	Workspace.DescendantAdded:Connect(consider)
	task.spawn(function()
		while true do
			pick()
			task.wait(Presets.rides.pick)
		end
	end)
	RunService.Heartbeat:Connect(step)
end

return Rides
