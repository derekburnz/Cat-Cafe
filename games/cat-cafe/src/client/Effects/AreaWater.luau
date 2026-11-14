--!strict
-- The new areas' still water comes alive (#4070 the Water Park, #4071 the Castle's moat and well). Model-Agent built
-- each water surface as a Model of Glass parts named `<Set>_<nnn>_<Piece>_Water`. By its piece (Presets.areaWater):
-- foam flecks drift round the lazy river, the splash pad's jets spray at their caps, the slides' landing pools mist,
-- and the wave pool, the kids' pools, the moat and the well wink with small glints; a ring spreads on the surface
-- now and then. The emitters sit on thin unseen sheets just over the water (never inside the Glass, which hides
-- particles behind it). Only the nearest few pieces within reach run, and of a long piece only the parts nearest
-- you. Reduce Motion drops the rings; Low performance leaves the water as built. On this client only; listening
-- only. Numbers in Presets.areaWater.

local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local AreaWater = {}

-- One part of a piece with its water running.
type Live = {
	made: { Instance },
	emitters: { [ParticleEmitter]: string },
	spot: Vector3, -- where a ring may start
	reach: number, -- how far from the spot
}

type Source = {
	model: Model,
	kind: Presets.AreaWaterKind,
	fit: { BasePart }, -- the parts its kind works on
	at: { Vector3 }, -- where each is
	centre: Vector3, -- the middle of them all (the river goes round it)
	floor: number, -- the lowest any of them reaches
	live: { [BasePart]: Live },
	nextRing: number,
}

local sources: { [Instance]: Source } = {}
local started = false

-- The kind of water a Model's name marks, or nil: it holds one of the sets, ends with the suffix and holds a piece.
function AreaWater.kindOf(name: string): Presets.AreaWaterKind?
	local p = Presets.areaWater
	if #name <= #p.suffix or string.sub(name, -#p.suffix) ~= p.suffix then
		return nil
	end
	local ours = false
	for _, set in p.sets do
		if string.find(name, set, 1, true) ~= nil then
			ours = true
			break
		end
	end
	if not ours then
		return nil
	end
	for _, kind in p.kinds do
		if string.find(name, kind.piece, 1, true) ~= nil then
			return kind
		end
	end
	return nil
end

-- Which of a part's axes (1 right, 2 up, 3 look) points most nearly straight up or down: `axisY` holds how far up
-- each points.
function AreaWater.upAxis(axisY: Vector3): number
	local x, y, z = math.abs(axisY.X), math.abs(axisY.Y), math.abs(axisY.Z)
	if y >= x and y >= z then
		return 2
	end
	return if x >= z then 1 else 3
end

-- The size of the thin sheet over a part: `thin` along the axis that points up, the part's own size across (times
-- `inner` for a disc, so the sheet's corners stay inside the circle).
function AreaWater.sheet(axisY: Vector3, size: Vector3, disc: boolean, thin: number): Vector3
	local scale = if disc then Presets.areaWater.inner else 1
	local up = AreaWater.upAxis(axisY)
	return Vector3.new(
		if up == 1 then thin else size.X * scale,
		if up == 2 then thin else size.Y * scale,
		if up == 3 then thin else size.Z * scale
	)
end

-- Half of what a part covers upward in the world.
function AreaWater.halfHeight(axisY: Vector3, size: Vector3): number
	return (math.abs(axisY.X) * size.X + math.abs(axisY.Y) * size.Y + math.abs(axisY.Z) * size.Z)
		/ 2
end

-- Whether a part lies flat: thin upward next to how wide it is.
function AreaWater.isFlat(axisY: Vector3, size: Vector3): boolean
	local tall = AreaWater.halfHeight(axisY, size) * 2
	local wide = math.max(size.X, size.Y, size.Z)
	return tall <= 1.5 and wide >= tall * 3
end

-- Whether a part's `right` points the way the water goes round `centre` (counterclockwise seen from above).
function AreaWater.withFlow(position: Vector3, centre: Vector3, right: Vector3): boolean
	-- straight up crossed with the way out from the middle: (out.Z, 0, -out.X)
	local outX, outZ = position.X - centre.X, position.Z - centre.Z
	return right.X * outZ - right.Z * outX >= 0
end

local function axesUp(part: BasePart): Vector3
	local cf = part.CFrame
	return Vector3.new(cf.RightVector.Y, cf.UpVector.Y, cf.LookVector.Y)
end

local function isBall(part: BasePart): boolean
	return part:IsA("Part") and (part :: Part).Shape == Enum.PartType.Ball
end

local function isDisc(part: BasePart): boolean
	return part:IsA("Part") and (part :: Part).Shape == Enum.PartType.Cylinder
end

local function drop(s: Source, part: BasePart)
	local live = s.live[part]
	if live ~= nil then
		for _, instance in live.made do
			instance:Destroy()
		end
		s.live[part] = nil
	end
end

local function stop(s: Source)
	for part in s.live do
		drop(s, part)
	end
end

-- The parts of a piece its kind works on, read once: the water never moves.
local function measure(s: Source)
	local wantBalls = s.kind.spray ~= nil
	table.clear(s.fit)
	table.clear(s.at)
	local centre, floor = Vector3.zero, math.huge
	for _, d in s.model:GetDescendants() do
		if d:IsA("BasePart") then
			local part = d :: BasePart
			local axisY = axesUp(part)
			local fits = if wantBalls then isBall(part) else AreaWater.isFlat(axisY, part.Size)
			if fits then
				table.insert(s.fit, part)
				table.insert(s.at, part.Position)
				centre += part.Position
				floor = math.min(floor, part.Position.Y - AreaWater.halfHeight(axisY, part.Size))
			end
		end
	end
	s.centre = if #s.fit > 0 then centre / #s.fit else centre
	s.floor = floor
end

-- The parts nearest you, at most kind.parts of them, and how near the nearest is.
local function nearest(s: Source): ({ BasePart }, number)
	local candidates: { Logic.Candidate<BasePart> } = {}
	local best = math.huge
	for i, part in s.fit do
		local distance = Context.distance(s.at[i])
		best = math.min(best, distance)
		candidates[i] = { key = part, distance = distance }
	end
	if #s.fit <= s.kind.parts then
		return s.fit, best
	end
	return Logic.nearest(candidates, math.huge, s.kind.parts), best
end

local function make(s: Source, part: BasePart)
	local p = Presets.areaWater
	local kind = s.kind
	local live: Live = { made = {}, emitters = {}, spot = part.Position, reach = 0 }
	local function keep(emitter: ParticleEmitter?, name: string)
		if emitter ~= nil then
			live.emitters[emitter] = name
		end
	end
	local axisY = axesUp(part)
	local half = AreaWater.halfHeight(axisY, part.Size)
	local top = part.Position + Vector3.new(0, half + p.lift, 0)
	local on = kind.glint or kind.flow
	if on ~= nil then
		local size = AreaWater.sheet(axisY, part.Size, isDisc(part), 0.05)
		local sheet = Context.effectPart("EffectsWaterSheet", size, p.colour)
		sheet.Transparency = 1
		sheet.CFrame = part.CFrame.Rotation + top
		sheet.Parent = Context.folder()
		table.insert(live.made, sheet)
		local emitter = Particles.attach(on, sheet)
		if emitter ~= nil and kind.flow ~= nil then
			local with = AreaWater.withFlow(part.Position, s.centre, part.CFrame.RightVector)
			emitter.EmissionDirection = if with then Enum.NormalId.Right else Enum.NormalId.Left
		end
		keep(emitter, on)
	end
	local spray = kind.spray
	if spray ~= nil then
		local holder = Particles.anchor("EffectsWaterSpray", top)
		table.insert(live.made, holder)
		keep(Particles.attach(spray, holder), spray)
		-- a jet's ring spreads on the pad under it, not up at its cap
		live.spot = Vector3.new(part.Position.X, s.floor + p.lift, part.Position.Z)
	else
		local sides = { part.Size.X, part.Size.Y, part.Size.Z }
		table.sort(sides)
		live.spot = top
		live.reach = sides[2] * p.ringInner
	end
	local mist = kind.mist
	if mist ~= nil then
		local holder = Particles.anchor("EffectsWaterMist", top)
		table.insert(live.made, holder)
		keep(Particles.attach(mist, holder), mist)
	end
	s.live[part] = live
end

-- Runs the water on the parts nearest you, leaving alone the ones already running: walking along the river, only
-- the part you leave behind stops and the one ahead starts.
local function run(s: Source, wanted: { BasePart })
	local keepOn: { [BasePart]: boolean } = {}
	for _, part in wanted do
		keepOn[part] = true
		if s.live[part] == nil and part.Parent ~= nil then
			make(s, part)
		end
	end
	for part, live in s.live do
		if not keepOn[part] then
			drop(s, part)
		else
			-- a new budget reaches emitters made before it
			for emitter, name in live.emitters do
				Particles.switchOn(emitter, name)
			end
		end
	end
end

local function ring(s: Source, now: number)
	local every, size = s.kind.ringEvery, s.kind.ring
	if every == nil or size == nil or now < s.nextRing then
		return
	end
	s.nextRing = now + every * (0.8 + math.random() * 0.4)
	if Context.reducedMotion() then
		return
	end
	local spots: { Live } = {}
	for _, live in s.live do
		table.insert(spots, live)
	end
	if #spots == 0 then
		return
	end
	local p = Presets.areaWater
	local live = spots[math.random(1, #spots)]
	local offset =
		Vector3.new((math.random() * 2 - 1) * live.reach, 0, (math.random() * 2 - 1) * live.reach)
	Particles.ring(live.spot + offset, p.colour, size, p.ringSeconds)
end

local function consider(instance: Instance)
	if not instance:IsA("Model") or sources[instance] ~= nil then
		return
	end
	local kind = AreaWater.kindOf(instance.Name)
	if kind == nil then
		return
	end
	local s: Source = {
		model = instance :: Model,
		kind = kind,
		fit = {},
		at = {},
		centre = Vector3.zero,
		floor = 0,
		live = {},
		nextRing = os.clock() + math.random() * (kind.ringEvery or 1),
	}
	measure(s)
	sources[instance] = s
end

local function pick()
	local p = Presets.areaWater
	local candidates: { Logic.Candidate<Source> } = {}
	local wanted: { [Source]: { BasePart } } = {}
	for model, s in sources do
		if not model:IsDescendantOf(Workspace) then
			stop(s)
			sources[model] = nil
		elseif #s.fit > 0 and not Context.lowPerformance then
			local parts, distance = nearest(s)
			wanted[s] = parts
			table.insert(candidates, { key = s, distance = distance })
		end
	end
	local running: { [Source]: boolean } = {}
	local most = Context.budget.waterfalls + p.extra
	for _, s in Logic.nearest(candidates, p.within, most) do
		running[s] = true
		run(s, wanted[s])
	end
	local now = os.clock()
	for _, s in sources do
		if running[s] then
			ring(s, now)
		elseif next(s.live) ~= nil then
			stop(s)
		end
	end
end

function AreaWater.start()
	if started then
		return
	end
	started = true
	for _, descendant in Workspace:GetDescendants() do
		consider(descendant)
	end
	Workspace.DescendantAdded:Connect(function(descendant: Instance)
		if descendant:IsA("Model") then
			if AreaWater.kindOf(descendant.Name) ~= nil then
				task.defer(consider, descendant)
			end
		elseif descendant:IsA("BasePart") then
			-- the water's parts stream in after its Model: measure a known piece again as they arrive
			local parent = descendant.Parent
			local known: Source? = if parent ~= nil then sources[parent] else nil
			if known ~= nil then
				stop(known)
				task.defer(measure, known)
			end
		end
	end)
	task.spawn(function()
		while true do
			pick()
			task.wait(Presets.areaWater.pick)
		end
	end)
end

return AreaWater
