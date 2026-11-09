--!strict
-- The Desert's and the Ruins' own effects (Tier 6 and 7, #2657; tier6-7-areas.md sections 4 and 5): the area's air
-- round you while you are in it (sand motes in the Desert, glyph-gold and jade motes in the Ruins), a puff in the
-- area's colour where one of its strays appears and where it leaves the ground (caught or gone), and in the Ruins a
-- mist puff round you when you drop into the mist below the plateau. The areas' boxes come from Config.World
-- (DesertCenterX and the rest, #2655); strays from the `Stray` tag and their `Area` attribute. Listening only: no remotes, no game state. The air is off
-- in Low performance and a fifth as thick with Reduce Motion (Presets.areaFx).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local AreaFx = {}

local started = false
local air: Part? = nil -- the box of air round you, while you are in an area with air
local airArea: string? = nil
local airEmitter: ParticleEmitter? = nil
local misted = false -- the mist puffed for this fall
local strays: { [Instance]: Vector3 } = {}
local puffSecond = 0 -- the second the puff count is for
local puffs = 0
local boxes: { any }? = nil

-- The areas' boxes: Config.World's Desert* and Ruins* (#2655).
local function areaBoxes(): { any }
	local found = boxes
	if found ~= nil then
		return found
	end
	local world = (Config :: any).World
	local list: { any } = {}
	for _, id in { "Desert", "Ruins" } do
		local x = if type(world) == "table" then world[id .. "CenterX"] else nil
		local z = if type(world) == "table" then world[id .. "CenterZ"] else nil
		local width = if type(world) == "table" then world[id .. "Width"] else nil
		local depth = if type(world) == "table" then world[id .. "Depth"] else nil
		if
			type(x) == "number"
			and type(z) == "number"
			and type(width) == "number"
			and type(depth) == "number"
		then
			table.insert(list, {
				id = id:lower(),
				centre = { x = x, z = z },
				size = { width = width, depth = depth },
			})
		end
	end
	boxes = list
	return list
end

local function specOf(area: unknown): Presets.AreaFxSpec?
	if type(area) ~= "string" then
		return nil
	end
	local spec: Presets.AreaFxSpec? = Presets.areaFx.areas[area]
	return spec
end

local function puffAt(spec: Presets.AreaFxSpec, at: Vector3)
	if Context.distance(at) > Context.budget.animRadius then
		return
	end
	local second = math.floor(os.clock())
	if second ~= puffSecond then
		puffSecond, puffs = second, 0
	end
	if puffs >= Context.budget.areaPuffs then
		return -- a whole wave landing at once puffs only the first few (#2661)
	end
	puffs += 1
	Particles.burst(spec.puffPreset, at, spec.puff, spec.colour)
end

local function feetOf(model: Model): Vector3
	local frame, size = model:GetBoundingBox()
	return frame.Position - Vector3.new(0, size.Y / 2 - 0.3, 0)
end

local function strayAdded(instance: Instance, quiet: boolean?)
	if not instance:IsA("Model") or not instance:IsDescendantOf(Workspace) then
		return -- a template in ReplicatedStorage.Assets may carry the tag too
	end
	local spec = specOf(instance:GetAttribute("Area"))
	if spec == nil then
		return
	end
	task.defer(function()
		local model = instance :: Model
		if model.Parent == nil or model:FindFirstChildWhichIsA("BasePart", true) == nil then
			return
		end
		local at = feetOf(model)
		strays[model] = at
		if not quiet then
			puffAt(spec, at)
		end
	end)
end

local function strayRemoved(instance: Instance)
	local at: Vector3? = strays[instance]
	strays[instance] = nil
	if
		at ~= nil
		and instance:IsA("Model")
		and instance:FindFirstChildWhichIsA("BasePart", true) ~= nil
	then
		at = feetOf(instance :: Model) -- where it is now: strays walk
	end
	local spec = specOf(instance:GetAttribute("Area"))
	if at ~= nil and spec ~= nil then
		puffAt(spec, at)
	end
end

local function dropAir()
	if air ~= nil then
		air:Destroy()
	end
	air, airArea, airEmitter = nil, nil, nil
end

-- The air round you in the area you stand in, if it has some and the budget allows it.
local function updateAir(area: string?, feet: Vector3)
	local spec = specOf(area)
	if spec == nil or Context.lowPerformance then
		dropAir()
		return
	end
	local fx = Presets.areaFx
	local box = air
	if box == nil or airArea ~= area then
		dropAir()
		local part = Context.effectPart("AreaAir", fx.box, spec.colour)
		part.Transparency = 1
		part.Parent = Context.folder()
		local emitter = Particles.attach(spec.air, part)
		if emitter == nil then
			part:Destroy()
			return
		end
		box, air, airArea, airEmitter = part, part, area, emitter
	end
	local part = box :: Part
	part.CFrame = CFrame.new(feet + Vector3.new(0, fx.lift, 0))
	local emitter = airEmitter
	if emitter ~= nil then
		Particles.switchOn(emitter, spec.air)
		if Context.reducedMotion() then
			emitter.Rate *= fx.calmRate
		end
	end
end

-- The Ruins' mist: once per fall, when you are `mistDepth` under the plateau inside its box.
local function updateMist(area: string?, feet: Vector3)
	local spec = specOf(area)
	local depth = if spec ~= nil then spec.mistDepth else nil
	if spec == nil or depth == nil or spec.mist == nil then
		misted = false
		return
	end
	if feet.Y > -depth then
		misted = false
		return
	end
	if not misted then
		misted = true
		Particles.burst("smokePuff", feet, spec.mist :: number, spec.mistColour or spec.colour)
	end
end

local function step()
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		dropAir()
		return
	end
	local feet = (root :: BasePart).Position - Vector3.new(0, 3, 0)
	local area = Logic.areaAt(feet.X, feet.Z, areaBoxes(), Presets.areaFx.pad)
	updateAir(area, feet)
	updateMist(area, feet)
end

function AreaFx.start()
	if started then
		return
	end
	started = true
	for _, instance in CollectionService:GetTagged("Stray") do
		strayAdded(instance, true) -- already there when you arrive: no puff
	end
	CollectionService:GetInstanceAddedSignal("Stray"):Connect(function(instance: Instance)
		strayAdded(instance)
	end)
	CollectionService:GetInstanceRemovedSignal("Stray"):Connect(strayRemoved)
	task.spawn(function()
		while true do
			step()
			task.wait(Presets.areaFx.checkSeconds)
		end
	end)
end

return AreaFx
