--!strict
-- The Ruins' running water (#3257, Animation-Engineer's Ruins batch: a waterfall by the cat colossus and a fountain
-- in CatCafe_Ruins_Set). The water is a Model named `..._Waterfall_Water` or `..._Fountain_Water` of Glass parts.
-- Each tall, thin part is a falling sheet: pale streaks slide down through it, soft mist rises at its foot and a
-- ring spreads on the pool there now and then, so the water reads as running from across the Ruins. Only the
-- nearest few within reach run (budget.waterfalls). Reduce Motion keeps the streaks and mist without the rings;
-- Low performance keeps the streaks only. On this client only; listening only. Numbers in Presets.ruinsWater.

local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local RuinsWater = {}

type Source = {
	model: Model,
	sheets: { BasePart },
	feet: { Vector3 },
	on: boolean,
	made: { Instance },
	mists: { ParticleEmitter },
	nextRipple: number,
}

local sources: { [Instance]: Source } = {}
local started = false

-- Whether a Model's name marks it as Ruins water.
function RuinsWater.isWater(name: string): boolean
	for _, suffix in Presets.ruinsWater.suffixes do
		if #name > #suffix and string.sub(name, -#suffix) == suffix then
			return true
		end
	end
	return false
end

-- Half the height a part covers in the world: `axisY` holds how far up its right, up and look axes point.
function RuinsWater.halfHeight(axisY: Vector3, size: Vector3): number
	return (math.abs(axisY.X) * size.X + math.abs(axisY.Y) * size.Y + math.abs(axisY.Z) * size.Z)
		/ 2
end

-- How far up a part's right, up and look axes point.
local function axesUp(part: BasePart): Vector3
	local cf = part.CFrame
	return Vector3.new(cf.RightVector.Y, cf.UpVector.Y, cf.LookVector.Y)
end

-- Whether a part is a falling sheet: tall in the world and thin across.
function RuinsWater.isSheet(axisY: Vector3, size: Vector3): boolean
	local p = Presets.ruinsWater
	local tall = RuinsWater.halfHeight(axisY, size) * 2
	local sides = { size.X, size.Y, size.Z }
	table.sort(sides)
	return tall >= p.sheetHeight and sides[1] <= p.sheetThin
end

-- The sheets' feet, one per group closer than `merge` studs across (the lowest of the group).
function RuinsWater.feet(points: { Vector3 }): { Vector3 }
	local merge = Presets.ruinsWater.merge
	local out: { Vector3 } = {}
	for _, point in points do
		local joined = false
		for i, foot in out do
			local across = Vector3.new(point.X - foot.X, 0, point.Z - foot.Z).Magnitude
			if across <= merge then
				if point.Y < foot.Y then
					out[i] = point
				end
				joined = true
				break
			end
		end
		if not joined then
			table.insert(out, point)
		end
	end
	return out
end

local function stop(s: Source)
	for _, instance in s.made do
		instance:Destroy()
	end
	table.clear(s.made)
	table.clear(s.mists)
	s.on = false
end

local function run(s: Source)
	local p = Presets.ruinsWater
	if not s.on then
		s.on = true
		for _, sheet in s.sheets do
			local emitter = Particles.attach(p.streaks, sheet)
			if emitter ~= nil then
				emitter.EmissionDirection = Enum.NormalId.Bottom
				table.insert(s.made, emitter)
			end
		end
		for _, foot in s.feet do
			local holder = Particles.anchor("RuinsMist", foot + Vector3.new(0, p.mistLift, 0))
			table.insert(s.made, holder)
			local emitter = Particles.attach(p.mist, holder)
			if emitter ~= nil then
				table.insert(s.mists, emitter)
			end
		end
		s.nextRipple = os.clock() + math.random() * p.rippleEvery
	end
	-- a new Low performance setting reaches emitters made before it
	for _, emitter in s.mists do
		emitter.Enabled = not Context.lowPerformance
	end
	for _, instance in s.made do
		if instance:IsA("ParticleEmitter") and instance.Name == p.streaks then
			Particles.switchOn(instance :: ParticleEmitter, p.streaks)
		end
	end
end

local function ripple(s: Source, now: number)
	local p = Presets.ruinsWater
	if now < s.nextRipple then
		return
	end
	s.nextRipple = now + p.rippleEvery
	if Context.reducedMotion() or Context.lowPerformance then
		return
	end
	for _, foot in s.feet do
		Particles.ring(foot + Vector3.new(0, 0.05, 0), p.colour, p.ring, p.ringSeconds)
	end
end

local function consider(instance: Instance)
	local known: Source? = sources[instance]
	if not instance:IsA("Model") or known ~= nil or not RuinsWater.isWater(instance.Name) then
		return
	end
	local model = instance :: Model
	local sheets: { BasePart } = {}
	local points: { Vector3 } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local part = d :: BasePart
			if RuinsWater.isSheet(axesUp(part), part.Size) then
				table.insert(sheets, part)
				local foot = part.Position.Y - RuinsWater.halfHeight(axesUp(part), part.Size)
				table.insert(points, Vector3.new(part.Position.X, foot, part.Position.Z))
			end
		end
	end
	if #sheets == 0 then
		return
	end
	sources[model] = {
		model = model,
		sheets = sheets,
		feet = RuinsWater.feet(points),
		on = false,
		made = {},
		mists = {},
		nextRipple = 0,
	}
end

local function pick()
	local p = Presets.ruinsWater
	local candidates: { Logic.Candidate<Source> } = {}
	for model, s in sources do
		if not model:IsDescendantOf(Workspace) then
			stop(s)
			sources[model] = nil
		else
			table.insert(
				candidates,
				{ key = s, distance = Context.distance(model:GetPivot().Position) }
			)
		end
	end
	local chosen: { [Source]: boolean } = {}
	for _, s in Logic.nearest(candidates, p.within, Context.budget.waterfalls) do
		chosen[s] = true
		run(s)
	end
	local now = os.clock()
	for _, s in sources do
		if chosen[s] then
			ripple(s, now)
		elseif s.on then
			stop(s)
		end
	end
end

function RuinsWater.start()
	if started then
		return
	end
	started = true
	for _, descendant in Workspace:GetDescendants() do
		consider(descendant)
	end
	Workspace.DescendantAdded:Connect(function(descendant: Instance)
		-- the water's parts stream in after its Model, so take a known water Model again as they arrive
		local parent = descendant.Parent
		local known: Source? = if parent ~= nil then sources[parent] else nil
		if descendant:IsA("BasePart") and parent ~= nil and known ~= nil then
			stop(known)
			sources[parent] = nil
			task.defer(consider, parent)
		elseif descendant:IsA("Model") then
			task.defer(consider, descendant)
		end
	end)
	task.spawn(function()
		while true do
			pick()
			task.wait(math.min(Presets.ruinsWater.pick, Presets.ruinsWater.rippleEvery))
		end
	end)
end

return RuinsWater
