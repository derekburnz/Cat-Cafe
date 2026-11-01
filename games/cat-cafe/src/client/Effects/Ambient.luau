--!strict
-- Ambient life (design v0.4 section 4): espresso steam, chimney smoke, butterflies over the flower beds by day
-- (each wandering the whole bed, coming and going, and now and then flying over to another bed close by, so the
-- Town Square's lamp baskets share theirs; Derek 2026-10-28 17:48) and fireflies at night. Sources are found by name, the asset thread's `_Steam`, `_Chimney`, `_Flowers` and
-- `_Fireflies` objects (a part, or an object Model whose parts share its name), with fallbacks for the graybox: the top of each plot's Espresso model, a spot in front of
-- each cafe door and the street lamps. Only the nearest sources within range run, inside the device budget, and
-- the choice is made once a second, not every frame.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Decor = require(script.Parent.Decor)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local Ambient = {}

type Kind = "steam" | "chimney" | "fireflies" | "flowers"

-- A flower bed's ground: `frame` at the flowers' top in the bed's own axes, `half` its half size across (X and Z).
type Area = { frame: CFrame, half: Vector3 }

type Source = {
	kind: Kind,
	instance: Instance,
	fallback: boolean,
	position: Vector3?,
	area: Area?,
	holder: Instance?,
	emitter: ParticleEmitter?,
}

-- `source` is its home bed, which the budget counts; `at` is the bed it is over now, its home or one close by that it
-- flew to. `from` and `to` are spots in `at`'s own axes; the current flight left `from` at `legAt` and lands in
-- `legSeconds`, and on a flight to another bed `hopTo` is that bed and `hopSpot` the spot in its axes. It is away
-- until `outAt`, then out for `outSeconds`; `placed` is the `outAt` it was last put down for.
type Butterfly = {
	left: BasePart,
	right: BasePart,
	phase: number,
	source: Source?,
	at: Source?,
	hopTo: Source?,
	hopSpot: Vector3,
	from: Vector3,
	to: Vector3,
	legAt: number,
	legSeconds: number,
	outAt: number,
	outSeconds: number,
	placed: number,
	shown: number,
}

local TICK_SECONDS = 1
local LAMP_BOX = Vector3.new(16, 10, 16) -- studs of air fireflies drift in around a street lamp

local sources: { [Instance]: Source } = {}
local named: { [string]: number } = { steam = 0, chimney = 0, fireflies = 0, flowers = 0 }
local butterflies: { Butterfly } = {}
local neighbours: { [Source]: { Source } } = {} -- each chosen bed's beds close enough to fly to, read once a second
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
		if fly.at == source or fly.hopTo == source then
			fly.at, fly.hopTo = nil, nil -- it settles back over its home bed
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

-- The ground a flower source's butterflies wander: the bed's footprint plus `pad`, at least `least` each way.
local function areaOf(source: Source, top: Vector3): Area
	local b = Presets.butterfly
	local instance = source.instance
	local turn, size = CFrame.identity, Vector3.zero
	if source.fallback and instance:IsA("BasePart") then
		turn = (instance :: BasePart).CFrame.Rotation -- the graybox door zone: no bed, the least
	elseif instance:IsA("BasePart") then
		turn, size = (instance :: BasePart).CFrame.Rotation, (instance :: BasePart).Size
	elseif instance:IsA("Model") then
		local frame
		frame, size = (instance :: Model):GetBoundingBox()
		turn = frame.Rotation
	end
	return {
		frame = CFrame.new(top) * turn,
		half = Vector3.new(
			math.max(size.X / 2 + b.pad, b.least.X),
			0,
			math.max(size.Z / 2 + b.pad, b.least.Z)
		),
	}
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
		at = nil,
		hopTo = nil,
		hopSpot = Vector3.zero,
		from = Vector3.zero,
		to = Vector3.zero,
		legAt = 0,
		legSeconds = 0,
		outAt = 0,
		outSeconds = 0,
		placed = -1,
		shown = 0,
	}
end

local function between(range: { number }): number
	return rng:NextNumber(range[1], range[2])
end

-- A random spot over the bed, in its own axes.
local function spotIn(area: Area): Vector3
	return Vector3.new(
		rng:NextNumber(-area.half.X, area.half.X),
		0,
		rng:NextNumber(-area.half.Z, area.half.Z)
	)
end

-- The next spell out: after a wait away (a shorter one the first time, so a bed's butterflies arrive one by one).
local function nextSpell(fly: Butterfly, now: number, first: boolean)
	local b = Presets.butterfly
	fly.outAt = now + between(if first then b.firstAway else b.away)
	fly.outSeconds = between(b.out)
end

-- A bed close to its home to fly over to, or its home again, never the bed it is over; nil when there is none.
local function hopTarget(fly: Butterfly): Source?
	local home, at = fly.source, fly.at
	if home == nil then
		return nil
	end
	local options: { Source } = {}
	if at ~= home then
		table.insert(options, home)
	end
	local near: { Source } = neighbours[home] or {}
	for _, source in near do
		if source ~= at and source.area ~= nil and source.instance.Parent ~= nil then
			table.insert(options, source)
		end
	end
	return if #options > 0 then options[rng:NextInteger(1, #options)] else nil
end

-- Now and then, instead of a spot on its own bed, a flight over to a spot on a bed close by (`hop`); its spell runs
-- on until it has landed there and looked about a little. False when it stays.
local function hopLeg(fly: Butterfly, area: Area, now: number): boolean
	local b = Presets.butterfly
	local hop = b.hop
	-- never once it has started fading out: stretching the spell then would snap it back to full
	if fly.outSeconds - (now - fly.outAt) < b.fade or rng:NextNumber() >= hop.chance then
		return false
	end
	local target = hopTarget(fly)
	local there = if target ~= nil then target.area else nil
	if target == nil or there == nil then
		return false
	end
	local spot = spotIn(there)
	fly.to = area.frame:PointToObjectSpace(there.frame:PointToWorldSpace(spot))
	fly.hopTo, fly.hopSpot = target, spot
	fly.legSeconds =
		math.clamp((fly.to - fly.from).Magnitude / hop.speed, hop.shortest, hop.longest)
	fly.legAt = now
	fly.outSeconds = math.max(fly.outSeconds, now - fly.outAt + fly.legSeconds + hop.stay)
	return true
end

-- The next flight from where it landed: now and then a hover over that spot first (never two in a row) or, when
-- `mayHop` (not straight after landing from one), a flight over to another bed close by, else off to another spot.
local function nextLeg(fly: Butterfly, area: Area, now: number, mayHop: boolean)
	local b = Presets.butterfly
	local hovered = fly.legSeconds > 0 and fly.from == fly.to
	local from = fly.to
	fly.from = from
	if mayHop and fly.legSeconds > 0 and hopLeg(fly, area, now) then
		return
	end
	if hovered or fly.legSeconds == 0 or rng:NextNumber() >= b.hover.chance then
		fly.to = spotIn(area)
		fly.legSeconds =
			math.clamp((fly.to - from).Magnitude / b.speed, b.legShortest, b.legLongest)
	else
		fly.legSeconds = between({ b.hover.shortest, b.hover.longest })
	end
	fly.legAt = now
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
			nextSpell(fly, os.clock(), true)
			wanted[source] -= 1
		end
	end
end

local function showFly(fly: Butterfly, shown: number)
	local parent = if shown > 0 then Context.folder() else nil
	if fly.left.Parent ~= parent then
		fly.left.Parent = parent
		fly.right.Parent = parent
	end
	if math.abs(shown - fly.shown) > 0.02 or (shown == 1) ~= (fly.shown == 1) then
		fly.left.Transparency = 1 - shown
		fly.right.Transparency = 1 - shown
		fly.shown = shown
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
	local b = Presets.butterfly
	local wing = b.wing
	local parts = flyParts
	local frames = flyFrames
	table.clear(parts)
	table.clear(frames)
	for _, fly in butterflies do
		local home = fly.source
		local homeArea = if home ~= nil then home.area else nil
		local shown = 0
		if homeArea ~= nil then
			if now - fly.outAt >= fly.outSeconds then
				nextSpell(fly, now, false) -- that spell is over: away for a while
			end
			shown = Logic.spell(now - fly.outAt, fly.outSeconds, b.fade)
		end
		showFly(fly, shown)
		if home == nil or homeArea == nil or shown <= 0 then
			continue
		end
		local at = fly.at
		local area = if at ~= nil then at.area else nil
		if fly.placed ~= fly.outAt or area == nil then
			-- A new spell, or the bed it flew to has gone: it comes down over a random spot of its own bed.
			fly.placed = fly.outAt
			fly.at, fly.hopTo = home, nil
			area = homeArea
			fly.to = spotIn(homeArea)
			fly.legSeconds = 0
			nextLeg(fly, homeArea, now, false)
		elseif now - fly.legAt >= fly.legSeconds then
			local landed = fly.hopTo
			local landedArea = if landed ~= nil then landed.area else nil
			if landed ~= nil and landedArea ~= nil then
				-- landed on the other bed: from here on it flies in that bed's axes
				fly.at = landed
				fly.to = fly.hopSpot
				area = landedArea
			end
			fly.hopTo = nil
			nextLeg(fly, area :: Area, now, landed == nil)
		end
		local here = area :: Area
		local hopping = fly.hopTo ~= nil
		local lift = Vector3.new(0, b.rise * (1 - shown), 0)
		local k = (now - fly.legAt) / fly.legSeconds
		if hopping then
			lift += Vector3.new(0, Logic.hopLift(k, b.hop.arc), 0)
		end
		local offset, flap = Logic.butterfly(now, fly.phase)
		local spot = Logic.butterflyLeg(fly.from, fly.to, k) + offset + lift
		local ahead = Logic.butterflyLeg(fly.from, fly.to, k + 0.1 / fly.legSeconds)
			+ Logic.butterfly(now + 0.1, fly.phase)
			+ lift
		local position = here.frame:PointToWorldSpace(spot)
		local next = here.frame:PointToWorldSpace(ahead)
		local heading = Vector3.new(next.X - position.X, 0, next.Z - position.Z)
		local body = if heading.Magnitude > 1e-3
			then CFrame.lookAt(position, position + heading)
			else CFrame.new(position)
		table.insert(parts, fly.left)
		table.insert(frames, body * CFrame.Angles(0, 0, flap) * CFrame.new(-wing.X / 2, 0, 0))
		table.insert(parts, fly.right)
		table.insert(frames, body * CFrame.Angles(0, 0, -flap) * CFrame.new(wing.X / 2, 0, 0))
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
		if source.kind == "flowers" then
			source.area = areaOf(source, position)
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
	-- Mythical cafe styles moving near the player take their share of the steady emitters first (F53).
	local share = math.max(0, budget.steadyEmitters - Decor.inUse())
	for _, source in Logic.nearest(steady, math.huge, share) do
		on[source] = true
		enable(source, source.position :: Vector3)
	end
	for _, source in sources do
		if not on[source] then
			disable(source)
		end
	end
	local b = Presets.butterfly
	local chosen = Logic.nearest(flowers, math.huge, math.floor(budget.butterflies / b.perSource))
	assignButterflies(chosen)
	-- the beds each chosen one's butterflies may fly over to
	table.clear(neighbours)
	for _, home in chosen do
		local near: { Source } = {}
		local at = home.position
		for _, source in sources do
			local there = source.position
			if
				source ~= home
				and source.kind == "flowers"
				and source.area ~= nil
				and at ~= nil
				and there ~= nil
				and (there - at).Magnitude <= b.hop.range
			then
				table.insert(near, source)
			end
		end
		neighbours[home] = near
	end
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
