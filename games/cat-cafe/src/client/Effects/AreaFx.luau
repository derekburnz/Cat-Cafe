--!strict
-- The Desert's and the Ruins' own effects (Tier 6 and 7, #2657; tier6-7-areas.md sections 4 and 5): the area's air
-- round you while you are in it (sand motes in the Desert, glyph-gold and jade motes in the Ruins), a puff in the
-- area's colour where one of its strays appears and where it leaves the ground (caught or gone), and in the Ruins a
-- mist puff round you when you drop into the mist below the plateau. The areas' boxes come from Config.World
-- (DesertCenterX and the rest, #2655); strays from the `Stray` tag and their `Area` attribute. Listening only: no remotes, no game state. The air is off
-- in Low performance and a fifth as thick with Reduce Motion (Presets.areaFx). In the Desert the nearest dune crests
-- also blow a plume of sand off their tops (Presets.areaFx.dunes; none with Reduce Motion or Low performance).
-- Over the Snowy Mountain (#4069), ribbons of northern light hang in the night sky while you are there
-- (AuroraSpec in Presets.areaFx: still with Reduce Motion, none in Low performance).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
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
	-- every area with effects (Presets.areaFx.areas): "snowy" reads Config.World's SnowyCenterX and the rest, so an
	-- area's air starts the day its box is in the Config (#4069)
	local ids: { string } = {}
	for area in Presets.areaFx.areas do
		table.insert(ids, area:sub(1, 1):upper() .. area:sub(2))
	end
	table.sort(ids)
	for _, id in ids do
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
	part.CFrame = CFrame.new(feet + Vector3.new(0, spec.lift or fx.lift, 0))
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

-- #4069: a little puff under your feet for every `footStuds` you walk on the ground in an area with one (snow in
-- the Snowy Mountain), and a step for whoever listens (AreaFx.onStep). No puff in Low performance or with Reduce
-- Motion.
local footAt: Vector3? = nil

-- Who wants to know about a step (Audio plays the area's step sound on it): `area` and where the feet are.
local stepListeners: { (area: string, at: Vector3) -> () } = {}

function AreaFx.onStep(listener: (area: string, at: Vector3) -> ())
	table.insert(stepListeners, listener)
end

local function updateFeet(area: string?, feet: Vector3, humanoid: Humanoid?)
	local spec = specOf(area)
	local count = if spec ~= nil then spec.footPuff else nil
	if spec == nil or area == nil or count == nil or humanoid == nil then
		footAt = nil
		return
	end
	local last = footAt
	if last == nil then
		footAt = feet
		return
	end
	local walked = Vector3.new(feet.X - last.X, 0, feet.Z - last.Z).Magnitude
	if walked < (spec.footStuds or 3) then
		return
	end
	footAt = feet
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		-- the puff is a picture, so it goes with Low performance and Reduce Motion; the step is still heard
		if not Context.lowPerformance and not Context.reducedMotion() then
			Particles.burst(spec.footPreset or "dust", feet, count, spec.footColour or spec.colour)
		end
		for _, listener in stepListeners do
			task.spawn(listener, area, feet)
		end
	end
end

-- Sand off the Desert's dune crests (#2925) ------------------------------------------------------------------

local crests: { BasePart } = {}
local scannedAt = -math.huge
local pickedAt = -math.huge
local plumes: { [BasePart]: Attachment } = {}

local function isCrest(name: string): boolean
	for _, suffix in Presets.areaFx.dunes.names do
		if name:sub(-#suffix) == suffix then
			return true
		end
	end
	return false
end

-- The Desert's area model (WorldBuilder's Workspace.World.Desert, `Area` "desert").
local function desertModel(): Instance?
	local world = Workspace:FindFirstChild("World")
	if world == nil then
		return nil
	end
	for _, child in world:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("Area") == "desert" then
			return child
		end
	end
	return nil
end

local function scanCrests()
	crests = {}
	local model = desertModel()
	if model == nil then
		return
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and isCrest(descendant.Name) then
			table.insert(crests, descendant :: BasePart)
		end
	end
end

local function dropPlumes()
	for part, anchor in plumes do
		anchor:Destroy()
		plumes[part] = nil
	end
end

local function updateDunes(area: string?, feet: Vector3)
	local d = Presets.areaFx.dunes
	if area ~= "desert" or Context.lowPerformance or Context.reducedMotion() then
		dropPlumes()
		return
	end
	local now = os.clock()
	if now - pickedAt < d.pickSeconds then
		return
	end
	pickedAt = now
	if now - scannedAt >= d.scanSeconds then
		scannedAt = now
		scanCrests()
	end
	local most: number = d.most[Context.tier] or d.most.low
	local near: { { part: BasePart, gap: number } } = {}
	for _, part in crests do
		if part.Parent ~= nil then
			local gap = (part.Position - feet).Magnitude
			if gap <= d.within then
				table.insert(near, { part = part, gap = gap })
			end
		end
	end
	table.sort(
		near,
		function(a: { part: BasePart, gap: number }, b: { part: BasePart, gap: number }): boolean
			return a.gap < b.gap
		end
	)
	local keep: { [BasePart]: boolean } = {}
	for i = 1, math.min(most, #near) do
		keep[near[i].part] = true
	end
	for part, anchor in plumes do
		if not keep[part] or part.Parent == nil then
			anchor:Destroy()
			plumes[part] = nil
		end
	end
	for part in keep do
		local had: Attachment? = plumes[part]
		if had == nil then
			local top = part.Position + part.CFrame.UpVector * (part.Size.Y / 2)
			local anchor = Particles.anchor("DuneSand", top)
			Particles.attach(d.emitter, anchor)
			plumes[part] = anchor
		end
	end
end

-- #4069: the northern lights. While it is night and you stand in an area with an `aurora`, its ribbons hang over the
-- area: two soft bands each, on one unseen part, bending slowly from side to side. They fade in when they start and
-- out when night ends or you leave.
type Ribbon = { bands: { Beam }, tweens: { Tween } }
local aurora: Part? = nil
local auroraArea: string? = nil
local auroraRibbons: { Ribbon } = {}
local auroraShown = 1 -- the transparency the bands' middles have now
local auroraRun = 0 -- counts fades, so a newer one stops an older one
local auroraLeaving = false -- fading out, to be dropped when the fade ends

-- Studio only: Workspace's `AreaAuroraTest` attribute set to an area's id ("snowy") hangs its northern lights over
-- where you stand, day or night, until it is cleared. "snowy,30" hangs them 30 studs up instead, low enough to see
-- without tilting the camera.
local testAurora: string? = nil
local testHeight: number? = nil
local testBox: any = nil

local function auroraLook(middle: number)
	local sequence = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, middle),
		NumberSequenceKeypoint.new(0.75, middle),
		NumberSequenceKeypoint.new(1, 1),
	})
	for _, ribbon in auroraRibbons do
		for _, band in ribbon.bands do
			band.Transparency = sequence
		end
	end
	auroraShown = middle
end

local function fadeAurora(spec: Presets.AuroraSpec, to: number, after: (() -> ())?)
	auroraRun += 1
	local run = auroraRun
	local from = auroraShown
	task.spawn(function()
		local steps = 12
		for i = 1, steps do
			if run ~= auroraRun then
				return
			end
			auroraLook(from + (to - from) * i / steps)
			task.wait(spec.fade / steps)
		end
		if run == auroraRun and after ~= nil then
			after()
		end
	end)
end

local function dropAurora()
	auroraRun += 1
	for _, ribbon in auroraRibbons do
		for _, tween in ribbon.tweens do
			tween:Cancel()
		end
	end
	if aurora ~= nil then
		aurora:Destroy()
	end
	aurora, auroraArea, auroraRibbons, auroraShown = nil, nil, {}, 1
	auroraLeaving = false
end

local function buildAurora(area: string, spec: Presets.AuroraSpec, box: any)
	local tiers: { [string]: number } = { high = 1, medium = 2, low = 3 }
	local count = spec.ribbons[tiers[Context.tier] or 3] or 2
	local part = Context.effectPart("AreaAurora", Vector3.one, spec.foot)
	part.Transparency = 1
	local height = testHeight or spec.height
	local middle = Vector3.new(box.centre.x, height, box.centre.z)
	part.CFrame = CFrame.new(middle)
	local calm = Context.reducedMotion()
	for _, r in
		Logic.auroraRibbons(
			count,
			box.centre,
			box.size,
			height,
			spec.spread,
			spec.rise,
			spec.curve,
			spec.seconds,
			spec.curveMost
		)
	do
		local ribbon: Ribbon = { bands = {}, tweens = {} }
		for layer, colour in { spec.foot, spec.top } do
			local lift = (layer - 1) * spec.width * (1 - spec.overlap)
			-- a Beam bends along its attachments' X axes, so they point across the ribbon
			local from = Instance.new("Attachment")
			from.Position = r.from - middle + Vector3.new(0, lift, 0)
			from.Axis = r.across
			from.Parent = part
			local to = Instance.new("Attachment")
			to.Position = r.to - middle + Vector3.new(0, lift, 0)
			to.Axis = r.across
			to.Parent = part
			local band = Instance.new("Beam")
			band.Name = "Ribbon"
			band.Attachment0 = from
			band.Attachment1 = to
			band.FaceCamera = true
			band.Segments = 16
			band.Color = ColorSequence.new(colour)
			-- the soft smoke picture, once along the band: it thins toward the band's edges and ends
			band.Texture = Presets.textures.smoke
			band.TextureMode = Enum.TextureMode.Stretch
			band.TextureLength = 1
			band.TextureSpeed = 0
			band.LightEmission = 1
			band.LightInfluence = 0
			band.Width0 = spec.width
			band.Width1 = spec.width
			band.CurveSize0 = r.bend
			band.CurveSize1 = r.bend -- the far end bends the other way: a slow S
			band.Parent = part
			table.insert(ribbon.bands, band)
			if not calm then
				local tween = TweenService:Create(
					band,
					TweenInfo.new(
						r.seconds + (layer - 1) * 1.5,
						Enum.EasingStyle.Sine,
						Enum.EasingDirection.InOut,
						-1,
						true
					),
					{ CurveSize0 = -r.bend, CurveSize1 = -r.bend }
				)
				tween:Play()
				table.insert(ribbon.tweens, tween)
			end
		end
		table.insert(auroraRibbons, ribbon)
	end
	part.Parent = Context.folder()
	aurora, auroraArea = part, area
	auroraLook(1)
	fadeAurora(spec, spec.shown)
end

local function updateAurora(here: string?, feet: Vector3)
	local area = here
	if testAurora ~= nil then
		area = testAurora
		if testBox == nil then
			testBox = {
				id = testAurora,
				centre = { x = feet.X, z = feet.Z },
				size = { width = 300, depth = 200 },
			}
		end
	end
	local spec = specOf(area)
	local wanted = if spec ~= nil then spec.aurora else nil
	local night = Context.isNight() or testAurora ~= nil
	if wanted == nil or area == nil or Context.lowPerformance or not night then
		local old = specOf(auroraArea)
		local was = if old ~= nil then old.aurora else nil
		if aurora == nil or was == nil or Context.lowPerformance then
			dropAurora()
		elseif not auroraLeaving then
			auroraLeaving = true
			fadeAurora(was, 1, dropAurora)
		end
		return
	end
	if aurora ~= nil and auroraArea == area then
		if auroraLeaving then -- night again, or you came back, before it had gone
			auroraLeaving = false
			fadeAurora(wanted, wanted.shown)
		end
		return
	end
	dropAurora()
	if testBox ~= nil then
		buildAurora(area, wanted, testBox)
		return
	end
	for _, box in areaBoxes() do
		if box.id == area then
			buildAurora(area, wanted, box)
			return
		end
	end
end

local function step()
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		dropAir()
		dropPlumes()
		dropAurora()
		return
	end
	local feet = (root :: BasePart).Position - Vector3.new(0, 3, 0)
	local area = Logic.areaAt(feet.X, feet.Z, areaBoxes(), Presets.areaFx.pad)
	updateAir(area, feet)
	updateMist(area, feet)
	updateDunes(area, feet)
	updateAurora(area, feet)
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	updateFeet(area, feet, humanoid :: Humanoid?)
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
	if RunService:IsStudio() then
		Workspace:GetAttributeChangedSignal("AreaAuroraTest"):Connect(function()
			local value = Workspace:GetAttribute("AreaAuroraTest")
			local old = specOf(auroraArea)
			local was = if old ~= nil then old.aurora else nil
			local parts = if type(value) == "string" then string.split(value, ",") else {}
			testAurora = if parts[1] ~= nil and parts[1] ~= "" then parts[1] else nil
			testHeight = tonumber(parts[2] or "")
			testBox = nil
			if testAurora == nil and aurora ~= nil and was ~= nil then
				auroraLeaving = true -- cleared: fade out as it does when night ends
				fadeAurora(was, 1, dropAurora)
			else
				dropAurora()
			end
		end)
	end
	task.spawn(function()
		while true do
			step()
			task.wait(Presets.areaFx.checkSeconds)
		end
	end)
end

return AreaFx
