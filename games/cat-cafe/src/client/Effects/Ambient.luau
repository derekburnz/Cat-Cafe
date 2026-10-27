--!strict
-- Ambient life (design v0.4 section 4): espresso steam, chimney smoke, butterflies over the flower boxes by day
-- and fireflies at night. Sources are found by name, the asset thread's `_Steam`, `_Chimney`, `_Flowers` and
-- `_Fireflies` objects (a part, or an object Model whose parts share its name), with fallbacks for the graybox: the top of each plot's Espresso model, a spot in front of
-- each cafe door and the street lamps. Only the nearest sources within range run, inside the device budget, and
-- the choice is made once a second, not every frame.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local Ambient = {}

type Kind = "steam" | "chimney" | "fireflies" | "flowers"

type Source = {
	kind: Kind,
	instance: Instance,
	fallback: boolean,
	position: Vector3?,
	holder: Instance?,
	emitter: ParticleEmitter?,
}

type Butterfly = {
	left: BasePart,
	right: BasePart,
	phase: number,
	source: Source?,
}

local TICK_SECONDS = 1
local LAMP_BOX = Vector3.new(16, 10, 16) -- studs of air fireflies drift in around a street lamp

local sources: { [Instance]: Source } = {}
local named: { [string]: number } = { steam = 0, chimney = 0, fireflies = 0, flowers = 0 }
local butterflies: { Butterfly } = {}
local flyParts: { BasePart } = {} -- reused every frame
local flyFrames: { CFrame } = {}
local rng = Random.new()
local started = false

local function endsWith(text: string, suffix: string): boolean
	return #text >= #suffix and text:sub(-#suffix) == suffix
end

-- True when an ancestor is already a source of this kind: the exporter names an object's parts like its Model,
-- so one cup of steam stays one source.
local function insideSource(instance: Instance, kind: Kind): boolean
	local stop: Instance = Workspace
	local ancestor = instance.Parent
	while ancestor ~= nil and ancestor ~= stop do
		local source: Source? = sources[ancestor]
		if source ~= nil and source.kind == kind then
			return true
		end
		ancestor = ancestor.Parent
	end
	return false
end

local function add(kind: Kind, instance: Instance, fallback: boolean)
	local existing: Source? = sources[instance]
	if existing ~= nil or (not fallback and insideSource(instance, kind)) then
		return
	end
	sources[instance] = { kind = kind, instance = instance, fallback = fallback }
	if not fallback then
		named[kind] += 1
	end
end

local function remove(source: Source)
	local holder = source.holder
	if holder ~= nil then
		holder:Destroy()
	end
	if not source.fallback then
		named[source.kind] -= 1
	end
	for _, fly in butterflies do
		if fly.source == source then
			fly.source = nil
		end
	end
	sources[source.instance] = nil
end

local function classify(instance: Instance)
	local name = instance.Name
	local part = instance:IsA("BasePart")
	if
		(part or instance:IsA("Model") or instance:IsA("Attachment")) and endsWith(name, "_Steam")
	then
		add("steam", instance, false)
		return
	end
	if not part and not instance:IsA("Model") then
		return
	end
	if endsWith(name, "_Chimney") then
		add("chimney", instance, false)
	elseif endsWith(name, "_Flowers") then
		add("flowers", instance, false)
	elseif part and endsWith(name, "_Fireflies") then
		add("fireflies", instance, false)
	elseif part and name:find("StreetLamp", 1, true) ~= nil and endsWith(name, "_Bulb") then
		add("fireflies", instance, true)
	end
end

local function topOf(instance: Instance): Vector3?
	if instance.Parent == nil then
		return nil
	end
	if instance:IsA("Attachment") then
		return (instance :: Attachment).WorldPosition
	elseif instance:IsA("BasePart") then
		local part = instance :: BasePart
		return part.Position + part.CFrame.UpVector * (part.Size.Y / 2)
	elseif instance:IsA("Model") then
		if instance:FindFirstChildWhichIsA("BasePart", true) == nil then
			return nil -- its parts have not streamed in yet
		end
		local frame, size = (instance :: Model):GetBoundingBox()
		return frame.Position + Vector3.new(0, size.Y / 2, 0)
	end
	return nil
end

-- Where a source's effect plays this second, or nil while it has nowhere to play (gone, or not streamed in).
local function placeOf(source: Source): Vector3?
	local instance = source.instance
	if instance.Parent == nil then
		return nil
	end
	if source.kind == "fireflies" then
		return if instance:IsA("BasePart") then (instance :: BasePart).Position else nil
	elseif source.kind == "flowers" and source.fallback and instance:IsA("BasePart") then
		-- The graybox door zone: out on the pavement in front of the shop, at ground height.
		local door = instance :: BasePart
		return door.Position + door.CFrame.LookVector * 5 - Vector3.new(0, door.Size.Y / 2, 0)
	end
	local top = topOf(instance)
	if top ~= nil and source.kind == "chimney" then
		return top + Vector3.new(0, 0.5, 0)
	end
	return top
end

-- Fallback sources for the graybox, used only while no named source of that kind exists.
local function refreshFallbacks()
	for _, plot in CollectionService:GetTagged("Plot") do
		local espresso = plot:FindFirstChild("Espresso")
		if espresso ~= nil and named.steam == 0 then
			add("steam", espresso, true)
		end
		local door = plot:FindFirstChild("Door")
		if door ~= nil and door:IsA("BasePart") and named.flowers == 0 then
			add("flowers", door, true)
		end
	end
	for _, source in sources do
		if source.fallback and named[source.kind] > 0 then
			remove(source)
		end
	end
end

local function enable(source: Source, position: Vector3)
	local emitter = source.emitter
	if emitter == nil then
		if source.kind == "fireflies" then
			-- Fireflies fill a box of air, so they need a part (an Attachment emits from a point).
			local instance = source.instance
			local sized = not source.fallback and instance:IsA("BasePart")
			local box = Context.effectPart("Fireflies", LAMP_BOX, Presets.palette.lampWarm)
			if sized then
				box.Size = (instance :: BasePart).Size
			end
			box.Transparency = 1
			box.CFrame = CFrame.new(position)
			box.Parent = Context.folder()
			source.holder = box
			emitter = Particles.attach("fireflies", box)
			if emitter ~= nil then
				emitter.Shape = Enum.ParticleEmitterShape.Box
				emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
			end
		else
			local anchor = Particles.anchor("Ambient_" .. source.kind, position)
			source.holder = anchor
			emitter = Particles.attach(source.kind, anchor)
		end
		source.emitter = emitter
	end
	local holder = source.holder
	if holder ~= nil and holder:IsA("Attachment") then
		local anchor = holder :: Attachment
		anchor.Position = position
	end
	if emitter ~= nil then
		Particles.switchOn(emitter, source.kind)
	end
end

local function disable(source: Source)
	local emitter = source.emitter
	if emitter ~= nil then
		emitter.Enabled = false
	end
end

-- Butterflies ------------------------------------------------------------------------------------------------

local function newButterfly(index: number): Butterfly
	local b = Presets.butterfly
	local colour = b.colors[(index - 1) % #b.colors + 1]
	return {
		left = Context.effectPart("ButterflyWing", b.wing, colour),
		right = Context.effectPart("ButterflyWing", b.wing, colour),
		phase = rng:NextNumber(0, 2 * math.pi),
		source = nil,
	}
end

local function assignButterflies(chosen: { Source })
	local b = Presets.butterfly
	local wanted: { [Source]: number } = {}
	for _, source in chosen do
		wanted[source] = b.perSource
	end
	-- Keep butterflies already at a chosen source; free the rest.
	for _, fly in butterflies do
		local source = fly.source
		if source ~= nil and (wanted[source] or 0) > 0 then
			wanted[source] -= 1
		else
			fly.source = nil
		end
	end
	for _, source in chosen do
		while (wanted[source] or 0) > 0 do
			local free: Butterfly? = nil
			for _, fly in butterflies do
				if fly.source == nil then
					free = fly
					break
				end
			end
			local fly: Butterfly = if free ~= nil then free else newButterfly(#butterflies + 1)
			if free == nil then
				table.insert(butterflies, fly)
			end
			fly.source = source
			wanted[source] -= 1
		end
	end
	for _, fly in butterflies do
		local parent = if fly.source ~= nil then Context.folder() else nil
		fly.left.Parent = parent
		fly.right.Parent = parent
	end
end

local elapsed = 0

local function flutter(dt: number)
	elapsed += dt
	if elapsed < 1 / Context.budget.animHz then
		return
	end
	elapsed = 0
	local now = os.clock()
	local wing = Presets.butterfly.wing
	local parts = flyParts
	local frames = flyFrames
	table.clear(parts)
	table.clear(frames)
	for _, fly in butterflies do
		local source = fly.source
		local centre = if source ~= nil then source.position else nil
		if centre ~= nil then
			local offset, flap = Logic.butterfly(now, fly.phase)
			local ahead = Logic.butterfly(now + 0.1, fly.phase)
			local position = centre + offset
			local heading = Vector3.new(ahead.X - offset.X, 0, ahead.Z - offset.Z)
			local body = if heading.Magnitude > 1e-3
				then CFrame.lookAt(position, position + heading)
				else CFrame.new(position)
			table.insert(parts, fly.left)
			table.insert(frames, body * CFrame.Angles(0, 0, flap) * CFrame.new(-wing.X / 2, 0, 0))
			table.insert(parts, fly.right)
			table.insert(frames, body * CFrame.Angles(0, 0, -flap) * CFrame.new(wing.X / 2, 0, 0))
		end
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- The once a second choice ------------------------------------------------------------------------------------

local function tick()
	refreshFallbacks()
	local budget = Context.budget
	local night = Context.isNight()
	local steady: { Logic.Candidate<Source> } = {}
	local flowers: { Logic.Candidate<Source> } = {}
	for _, source in sources do
		if source.instance.Parent == nil then
			remove(source)
			continue
		end
		local position = placeOf(source)
		source.position = position
		if position == nil then
			continue
		end
		local distance = Context.distance(position)
		local kind = source.kind
		local near = distance <= budget.ambientRadius
		if near and (kind == "steam" or (kind == "fireflies" and night)) then
			table.insert(steady, { key = source, distance = distance })
		elseif kind == "chimney" and distance <= budget.chimneyRadius then
			-- Smoke on the skyline reads from far off, so it ranks as if it were twice as close.
			table.insert(steady, { key = source, distance = distance / 2 })
		elseif near and kind == "flowers" and not night then
			table.insert(flowers, { key = source, distance = distance })
		end
	end
	local on: { [Source]: boolean } = {}
	for _, source in Logic.nearest(steady, math.huge, budget.steadyEmitters) do
		on[source] = true
		enable(source, source.position :: Vector3)
	end
	for _, source in sources do
		if not on[source] then
			disable(source)
		end
	end
	local perSource = Presets.butterfly.perSource
	assignButterflies(Logic.nearest(flowers, math.huge, math.floor(budget.butterflies / perSource)))
end

function Ambient.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		local world = Workspace:WaitForChild("World")
		for _, descendant in world:GetDescendants() do
			classify(descendant)
		end
		world.DescendantAdded:Connect(classify)
		while true do
			tick()
			task.wait(TICK_SECONDS)
		end
	end)
	RunService.PreRender:Connect(flutter)
end

return Ambient
