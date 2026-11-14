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

type Source = {
	model: Model,
	kind: Presets.AreaWaterKind,
	on: boolean,
	made: { Instance },
	emitters: { [ParticleEmitter]: string },
	spots: { Vector3 }, -- where a ring may start: the top of each running part
	reach: { number }, -- how far from each spot it may start
	madeAt: Vector3?, -- where you stood when its parts were chosen
	nextRing: number,
}

local sources: { [Instance]: Source } = {}
local started = false
local REBUILD = 14 -- studs you walk before a long piece chooses its parts again

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

local function stop(s: Source)
	for _, instance in s.made do
		instance:Destroy()
	end
	table.clear(s.made)
	table.clear(s.emitters)
	table.clear(s.spots)
	table.clear(s.reach)
	s.on = false
	s.madeAt = nil
end

-- The parts of a piece its kind works on, nearest you first, at most kind.parts of them.
local function chosen(s: Source): { BasePart }
	local wantBalls = s.kind.spray ~= nil
	local candidates: { Logic.Candidate<BasePart> } = {}
	for _, d in s.model:GetDescendants() do
		if d:IsA("BasePart") then
			local part = d :: BasePart
			local fits = if wantBalls
				then isBall(part)
				else AreaWater.isFlat(axesUp(part), part.Size)
			if fits then
				table.insert(candidates, { key = part, distance = Context.distance(part.Position) })
			end
		end
	end
	return Logic.nearest(candidates, math.huge, s.kind.parts)
end

local function keep(s: Source, emitter: ParticleEmitter?, name: string)
	if emitter ~= nil then
		s.emitters[emitter] = name
	end
end

local function build(s: Source)
	local p = Presets.areaWater
	local kind = s.kind
	local parts = chosen(s)
	local centre = Vector3.zero
	local all = 0
	for _, d in s.model:GetDescendants() do
		if d:IsA("BasePart") then
			centre += (d :: BasePart).Position
			all += 1
		end
	end
	if all > 0 then
		centre /= all
	end
	local floor = math.huge
	for _, part in parts do
		local axisY = axesUp(part)
		local half = AreaWater.halfHeight(axisY, part.Size)
		floor = math.min(floor, part.Position.Y - half)
		local top = part.Position + Vector3.new(0, half + p.lift, 0)
		local on = kind.glint or kind.flow
		if on ~= nil then
			local size = AreaWater.sheet(axisY, part.Size, isDisc(part), 0.05)
			local sheet = Context.effectPart("EffectsWaterSheet", size, p.colour)
			sheet.Transparency = 1
			sheet.CFrame = part.CFrame.Rotation + top
			sheet.Parent = Context.folder()
			table.insert(s.made, sheet)
			local emitter = Particles.attach(on, sheet)
			if emitter ~= nil and kind.flow ~= nil then
				emitter.EmissionDirection = if AreaWater.withFlow(
						part.Position,
						centre,
						part.CFrame.RightVector
					)
					then Enum.NormalId.Right
					else Enum.NormalId.Left
			end
			keep(s, emitter, on)
		end
		local spray = kind.spray
		if spray ~= nil then
			local holder = Particles.anchor("EffectsWaterSpray", top)
			table.insert(s.made, holder)
			keep(s, Particles.attach(spray, holder), spray)
		end
		local mist = kind.mist
		if mist ~= nil then
			local holder = Particles.anchor("EffectsWaterMist", top)
			table.insert(s.made, holder)
			keep(s, Particles.attach(mist, holder), mist)
		end
		if kind.spray == nil then
			local sides = { part.Size.X, part.Size.Y, part.Size.Z }
			table.sort(sides)
			table.insert(s.spots, top)
			table.insert(s.reach, sides[2] * p.ringInner)
		end
	end
	if kind.spray ~= nil then
		-- a jet's ring spreads on the pad under it, not up at its cap
		for _, part in parts do
			table.insert(s.spots, Vector3.new(part.Position.X, floor + p.lift, part.Position.Z))
			table.insert(s.reach, 0)
		end
	end
	s.madeAt = Context.focus()
	s.on = true
	s.nextRing = os.clock() + math.random() * (kind.ringEvery or 1)
end

local function run(s: Source)
	if s.on then
		-- a long piece follows you along it
		local at, from = Context.focus(), s.madeAt
		if at ~= nil and from ~= nil and (at - from).Magnitude > REBUILD then
			stop(s)
		end
	end
	if not s.on then
		build(s)
	end
	-- a new budget reaches emitters made before it
	for emitter, name in s.emitters do
		Particles.switchOn(emitter, name)
	end
end

local function ring(s: Source, now: number)
	local every, size = s.kind.ringEvery, s.kind.ring
	if every == nil or size == nil or now < s.nextRing or #s.spots == 0 then
		return
	end
	s.nextRing = now + every * (0.8 + math.random() * 0.4)
	if Context.reducedMotion() then
		return
	end
	local p = Presets.areaWater
	local i = math.random(1, #s.spots)
	local reach = s.reach[i]
	local offset = Vector3.new((math.random() * 2 - 1) * reach, 0, (math.random() * 2 - 1) * reach)
	Particles.ring(s.spots[i] + offset, p.colour, size, p.ringSeconds)
end

local function consider(instance: Instance)
	if not instance:IsA("Model") or sources[instance] ~= nil then
		return
	end
	local kind = AreaWater.kindOf(instance.Name)
	if kind == nil or instance:FindFirstChildWhichIsA("BasePart", true) == nil then
		return
	end
	sources[instance] = {
		model = instance :: Model,
		kind = kind,
		on = false,
		made = {},
		emitters = {},
		spots = {},
		reach = {},
		madeAt = nil,
		nextRing = 0,
	}
end

-- The nearest point of a piece, for choosing between pieces: its nearest part, since the lazy river rings the park.
local function distanceTo(s: Source): number
	local best = math.huge
	for _, d in s.model:GetDescendants() do
		if d:IsA("BasePart") then
			best = math.min(best, Context.distance((d :: BasePart).Position))
		end
	end
	return best
end

local function pick()
	local p = Presets.areaWater
	local candidates: { Logic.Candidate<Source> } = {}
	for model, s in sources do
		if not model:IsDescendantOf(Workspace) then
			stop(s)
			sources[model] = nil
		else
			table.insert(candidates, { key = s, distance = distanceTo(s) })
		end
	end
	local running: { [Source]: boolean } = {}
	if not Context.lowPerformance then
		local most = Context.budget.waterfalls + p.extra
		for _, s in Logic.nearest(candidates, p.within, most) do
			running[s] = true
			run(s)
		end
	end
	local now = os.clock()
	for _, s in sources do
		if running[s] then
			ring(s, now)
		elseif s.on then
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
		-- the water's parts stream in after its Model, so take a known piece again as they arrive
		local parent = descendant.Parent
		local known: Source? = if parent ~= nil then sources[parent] else nil
		if descendant:IsA("BasePart") and parent ~= nil then
			if known ~= nil then
				stop(known)
			else
				task.defer(consider, parent)
			end
		elseif descendant:IsA("Model") then
			task.defer(consider, descendant)
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
