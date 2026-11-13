--!strict
-- The Mystic Pool's quiet pointer (#3821): with the pool moved beside spawn (#3715), a soft light in the liquid
-- breathes slowly and a few sparkles drift up off it in the liquid's own colour, so a new player notices it without
-- a sign post or anything in the middle of town. Both fade from `full` studs out and are off past `within`
-- (Logic.beaconFade). Reduce Motion keeps the light still and the sparkles off; Low performance keeps the light only.
-- Finds the station by its tag (shared/Traits.TAG), so it follows the pool wherever it is placed. Nothing pauses
-- for a roll: the roll repaints the liquid and the light keeps its own colour. On this client only.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)
local Traits = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Traits"))

local PoolBeacon = {}

type Beacon = {
	holder: Attachment,
	light: PointLight,
	emitter: ParticleEmitter?,
	colour: Color3,
}

local beacons: { [Instance]: Beacon } = {}
local started = false

-- The liquid's middle and colour: the Model whose name ends in the pool's liquid suffix, else the station's pivot.
local function liquidOf(station: Model): (Vector3, Color3)
	local suffix = Presets.mysticPool.liquidSuffix
	for _, d in station:GetDescendants() do
		if d:IsA("Model") and string.sub(d.Name, -#suffix) == suffix then
			local model = d :: Model
			local part = model:FindFirstChildWhichIsA("BasePart", true)
			local colour = if part ~= nil then part.Color else Presets.poolBeacon.colour
			return model:GetPivot().Position, colour
		end
	end
	return station:GetPivot().Position, Presets.poolBeacon.colour
end

local function drop(instance: Instance)
	local b = beacons[instance]
	if b ~= nil then
		b.holder:Destroy()
		beacons[instance] = nil
	end
end

local function added(instance: Instance)
	if beacons[instance] ~= nil or not instance:IsA("Model") then
		return
	end
	local p = Presets.poolBeacon
	local at, colour = liquidOf(instance :: Model)
	local holder = Particles.anchor("PoolBeacon", at + Vector3.new(0, p.lift, 0))
	local light = Instance.new("PointLight")
	light.Color = colour
	light.Range = p.range
	light.Brightness = 0
	light.Shadows = false
	light.Parent = holder
	beacons[instance] = { holder = holder, light = light, emitter = nil, colour = colour }
end

local function step(now: number)
	local p = Presets.poolBeacon
	local still = Context.reducedMotion()
	for instance, b in beacons do
		if not instance:IsDescendantOf(workspace) then
			drop(instance)
			continue
		end
		local fade = Logic.beaconFade(Context.distance(b.holder.WorldPosition), p.full, p.within)
		local breath = if still then 1 else Logic.beaconBreath(now, p.breathSeconds, p.breathDip)
		b.light.Brightness = p.brightness * fade * breath
		local wantSparkles = fade > 0 and not still and not Context.lowPerformance
		if wantSparkles then
			local emitter = b.emitter
			if emitter == nil then
				local preset = Presets.emitters[p.emitter]
				if preset ~= nil then
					local made =
						Particles.make(preset, b.colour:Lerp(Presets.palette.offwhite, p.whiten))
					made.Name = "PoolBeaconMotes"
					made.Parent = b.holder
					b.emitter = made
					emitter = made
				end
			end
			if emitter ~= nil then
				emitter.Rate = p.rate * fade * Context.budget.rateScale
				emitter.Enabled = true
			end
		else
			local emitter = b.emitter
			if emitter ~= nil then
				emitter.Enabled = false
			end
		end
	end
end

function PoolBeacon.start()
	if started then
		return
	end
	started = true
	for _, instance in CollectionService:GetTagged(Traits.TAG) do
		added(instance)
	end
	CollectionService:GetInstanceAddedSignal(Traits.TAG):Connect(added)
	CollectionService:GetInstanceRemovedSignal(Traits.TAG):Connect(drop)
	task.spawn(function()
		while true do
			step(os.clock())
			task.wait(Presets.poolBeacon.tick)
		end
	end)
end

return PoolBeacon
