--!strict
-- The Spin Wheel station (F49, areas-and-stations B3): whenever anyone spins, the server sets the station's
-- LastSpinAt (server time) and every client nearby turns its Wheel about the hub, easing to a stop, with the rim
-- lights chasing round, the pointer knocked aside by each slice edge and a sparkle at the pointer when it stops.
-- It stops on the won slice, which the server sets as LastSlice just before LastSpinAt (somewhere inside the slice,
-- never by an edge, so it never looks like a near miss), at an angle every client works out the same from the two.
-- A player who joins later sees the wheel at the same resting angle. With no LastSlice it stops anywhere. Once it
-- has stopped, a rarer prize gets more: a ring and confetti for a "good" one, and for a "jackpot" gold confetti, a
-- gold ring, falling sparkles and longer blinking (Logic.prizeTier, from the slice's chance in Catalog.spinWheel).
--
-- The station is a model tagged SpinWheel, its front toward -Z of its pivot. Its `Wheel` (or `..._Wheel`) is a Model
-- pivoted at the hub, with slice 1 under the pointer at rest and slice n (n - 1) sixths of a turn round from it, the
-- way the wheel turns (the placeholder's layout); `Pointer` and the `RimLight` parts sit outside it. The whole Wheel
-- turns as one about its axle, which is the thinnest axis of its disc (its PrimaryPart, else its biggest part)
-- pointing to the back of the station. The Wheel's own pivot only gives the hub: on the placeholder its rotation lay
-- in the wheel's face (a Model with a PrimaryPart ignores the WorldPivot it sets), so turning about it flipped the
-- wheel end over end (Derek 2026-10-28 01:03). Every part is the server's; the turn is drawn on this client only.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog"))

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local Wheel = {}

type Station = {
	model: Model,
	wheel: Model,
	rest: CFrame, -- the hub where the server placed it, its Z axis the axle and its Y axis up across the face
	parts: { BasePart },
	offsets: { CFrame }, -- each wheel part in the hub's frame at rest
	frames: { CFrame }, -- reused every frame
	pointer: BasePart?,
	pointerRest: CFrame,
	lights: { BasePart },
	lit: { Enum.Material }, -- each rim light's own material, put back when it stops
	angle: number, -- how far this client has turned the wheel from rest, radians about the axle
	from: number,
	to: number,
	began: number, -- os.clock() the turn started, moved back by how late LastSpinAt replicated
	spinning: boolean,
	prize: Logic.PrizeTier, -- how the slice it is turning to is celebrated when it stops
}

local stations: { [Model]: Station } = {}
local weights: { [number]: number } = {}
for _, row in Catalog.spinWheel do
	weights[row.slice] = row.weight
end
local rng = Random.new()
local watched: { [Model]: boolean } = {}
local loop: RBXScriptConnection? = nil
local started = false

local function named(instance: Instance, name: string): boolean
	local text = instance.Name
	return text == name or (#text > #name + 1 and text:sub(-(#name + 1)) == "_" .. name)
end

local function findWheel(model: Model): Model?
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Model") and named(descendant, "Wheel") then
			return descendant :: Model
		end
	end
	return nil
end

-- The hub as the server placed it, turned so its Z axis is the axle (see the header) and its Y axis is up across the
-- wheel's face.
local function restOf(model: Model, wheel: Model, parts: { BasePart }): CFrame
	local disc = wheel.PrimaryPart
	if disc == nil then
		local most = -1
		for _, part in parts do
			local size = part.Size
			local volume = size.X * size.Y * size.Z
			if volume > most then
				disc, most = part, volume
			end
		end
	end
	local hub = wheel:GetPivot().Position
	if disc == nil then
		return CFrame.new(hub)
	end
	local frame = disc.CFrame
	local back = model:GetPivot().ZVector
	local axle =
		Logic.thinAxis(frame.RightVector, frame.UpVector, frame.LookVector, disc.Size, back)
	local up = Logic.wheelUp(axle, back)
	return CFrame.fromMatrix(hub, up:Cross(axle), up, axle)
end

-- Reads the wheel as the server placed it. Nil while it has not streamed in (the station is Persistent, so this
-- is only ever brief).
local function bind(model: Model): Station?
	local wheel = findWheel(model)
	if wheel == nil then
		return nil
	end
	local parts: { BasePart } = {}
	for _, descendant in wheel:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant :: BasePart)
		end
	end
	if #parts == 0 then
		return nil
	end
	local rest = restOf(model, wheel, parts)
	local station: Station = {
		model = model,
		wheel = wheel,
		rest = rest,
		parts = parts,
		offsets = {},
		frames = {},
		pointer = nil,
		pointerRest = CFrame.identity,
		lights = {},
		lit = {},
		angle = 0,
		from = 0,
		to = 0,
		began = 0,
		spinning = false,
		prize = "small",
	}
	for _, part in parts do
		table.insert(station.offsets, rest:Inverse() * part.CFrame)
		table.insert(station.frames, part.CFrame)
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and not descendant:IsDescendantOf(wheel) then
			local part = descendant :: BasePart
			if named(part, "Pointer") and station.pointer == nil then
				station.pointer = part
				station.pointerRest = part.CFrame
			elseif named(part, "RimLight") then
				table.insert(station.lights, part)
				table.insert(station.lit, part.Material)
			end
		end
	end
	return station
end

local function stationOf(model: Model): Station?
	local station: Station? = stations[model]
	if station ~= nil and station.wheel.Parent ~= nil and station.parts[1].Parent ~= nil then
		return station
	end
	local fresh = bind(model)
	if fresh ~= nil then
		stations[model] = fresh
	else
		stations[model] = nil
	end
	return fresh
end

local function draw(station: Station, angle: number)
	station.angle = angle
	local hub = station.rest * CFrame.Angles(0, 0, angle)
	for i, offset in station.offsets do
		station.frames[i] = hub * offset
	end
	Workspace:BulkMoveTo(station.parts, station.frames, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Knocks the pointer aside about the hub's axis at its top, as a slice edge passes under it.
local function tiltPointer(station: Station, degrees: number)
	local pointer = station.pointer
	if pointer == nil then
		return
	end
	local axes = station.rest.Rotation
	local hinge = CFrame.new(station.pointerRest.Position + axes.UpVector * pointer.Size.Y / 2)
		* axes
	pointer.CFrame = hinge
		* CFrame.Angles(0, 0, math.rad(degrees))
		* hinge:Inverse()
		* station.pointerRest
end

local function setLights(station: Station, on: (index: number) -> boolean)
	for i, light in station.lights do
		light.Material = if on(i) then station.lit[i] else Enum.Material.SmoothPlastic
	end
end

local function flashesOf(station: Station): (number, number)
	local w = Presets.wheel
	if station.prize == "jackpot" then
		return w.jackpotFlashes, w.jackpotFlashSeconds
	end
	return w.flashes, w.flashSeconds
end

-- A good or jackpot prize, once the wheel has stopped on it: a ring at the foot of the station and confetti from the
-- top of the wheel; a jackpot's are gold, with sparkles falling from above the wheel too.
local function celebrate(station: Station)
	local w = Presets.wheel
	if station.prize == "small" then
		return
	end
	local frame, size = station.model:GetBoundingBox()
	local foot = frame.Position - Vector3.new(0, size.Y / 2 - 0.1, 0)
	local top = frame.Position + Vector3.new(0, size.Y / 2, 0)
	if station.prize == "good" then
		Particles.ring(foot, Presets.palette.mint, w.goodRing, w.ringSeconds)
		Particles.confetti(top, math.ceil(Context.budget.confetti * w.goodConfetti))
		return
	end
	Particles.ring(foot, Presets.palette.golden, w.jackpotRing, w.ringSeconds)
	Particles.confetti(
		top,
		math.ceil(Context.budget.confetti * w.jackpotConfetti),
		Presets.purrfectColors
	)
	local wide = math.max(size.X, size.Z) / 2
	for i = 1, w.showers do
		task.delay(0.15 + (i - 1) * w.showerEvery, function()
			local across = station.rest.RightVector * rng:NextNumber(-wide, wide)
			Particles.burst(
				"shower",
				top + across + Vector3.new(0, 1, 0),
				Presets.bursts.shower,
				Presets.palette.golden
			)
		end)
	end
end

local function finish(station: Station)
	station.spinning = false
	draw(station, station.to)
	tiltPointer(station, 0)
	setLights(station, function()
		return true
	end)
end

local function step()
	local w = Presets.wheel
	local now = os.clock()
	local still = Context.reducedMotion()
	local any = false
	for _, station in stations do
		if not station.spinning then
			continue
		end
		if station.wheel.Parent == nil then
			station.spinning = false
			continue
		end
		local t = now - station.began
		local flashes, flashSeconds = flashesOf(station)
		if t >= w.seconds + flashSeconds then
			finish(station)
			continue
		end
		any = true
		local k = math.min(t / w.seconds, 1)
		if k < 1 then
			local angle = station.from + (station.to - station.from) * Logic.wheelEase(k)
			draw(station, angle)
			tiltPointer(station, Logic.pointerTilt(angle, w.slices, w.tick, w.tickShare) * (1 - k))
			if not still then
				setLights(station, function(i: number): boolean
					return Logic.chaseOn(i, t, w.chaseStep)
				end)
			end
		elseif station.angle ~= station.to then
			-- it has just stopped: settle exactly, sparkle at the pointer, then the lights blink together
			draw(station, station.to)
			tiltPointer(station, 0)
			local pointer = station.pointer
			if pointer ~= nil then
				Particles.burst(
					"catchSparkle",
					pointer.Position,
					w.sparkles,
					Presets.palette.golden
				)
			end
			celebrate(station)
		elseif not still then
			local flash = math.floor((t - w.seconds) / (flashSeconds / (flashes * 2)))
			setLights(station, function(): boolean
				return flash % 2 == 0
			end)
		end
	end
	if not any and loop ~= nil then
		loop:Disconnect()
		loop = nil
	end
end

local function lastSpinAt(model: Model): number
	local value = model:GetAttribute("LastSpinAt")
	return if type(value) == "number" then value else 0
end

-- LastSpinAt changed: turn from wherever the wheel is to the angle every client agrees on. A spin seen late starts
-- as far in as it is late; one already over, or too far away to see, just moves the wheel there.
local function spun(model: Model)
	local at = lastSpinAt(model)
	local station = stationOf(model)
	if station == nil or at <= 0 then
		return
	end
	local w = Presets.wheel
	local slice = model:GetAttribute("LastSlice")
	local won = if type(slice) == "number" then slice else nil
	local rest = Logic.wheelRest(at, won, w.slices)
	station.prize = Logic.prizeTier(weights, won)
	local late = math.max(0, Workspace:GetServerTimeNow() - at)
	if late >= w.seconds or Context.distance(station.rest.Position) > w.within then
		station.spinning = false
		station.to = Logic.wheelTarget(station.angle, rest, 0)
		finish(station)
		return
	end
	station.from = station.angle
	station.to = Logic.wheelTarget(
		station.angle,
		rest,
		if Context.reducedMotion() then w.stillTurns else w.turns
	)
	station.began = os.clock() - late
	station.spinning = true
	if loop == nil then
		loop = RunService.Heartbeat:Connect(step)
	end
end

local function watch(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local model = instance :: Model
	if watched[model] then
		return
	end
	watched[model] = true
	model:GetAttributeChangedSignal("LastSpinAt"):Connect(function()
		spun(model)
	end)
	if lastSpinAt(model) > 0 then
		spun(model) -- joined after a spin: show the wheel where everyone else sees it
	end
end

function Wheel.start()
	if started then
		return
	end
	started = true
	CollectionService:GetInstanceAddedSignal("SpinWheel"):Connect(watch)
	CollectionService:GetInstanceRemovedSignal("SpinWheel"):Connect(function(instance: Instance)
		if instance:IsA("Model") then
			stations[instance :: Model] = nil
		end
	end)
	for _, instance in CollectionService:GetTagged("SpinWheel") do
		watch(instance)
	end
end

return Wheel
