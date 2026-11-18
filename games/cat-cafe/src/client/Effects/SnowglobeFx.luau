--!strict
-- Snowglobe Village's world effects (the Christmas Event, Tue Dec 1 to Sun Jan 3; Design-Agent's
-- snowglobe-village-spec section 7). Part 1, the two that need no Christmas models yet:
--   the air     gentle snow falls round you while you are within `airWithin` studs of the village's middle (tag
--               `centreTag`), the Snowy Mountain's own `snowfall` flakes. A fifth as thick with Reduce Motion, none
--               in Low performance.
--   the portal  the giant snow globe in the Town Square (tag `portalTag`) swirls with icy sparkles while you are
--               within `portalWithin` studs, so it reads as a way in from across the square; still with Reduce
--               Motion, none in Low performance. Its pivot is the globe's base; the swirl sits `portalLift` up.
-- Part 2, on Model-Agent's village parts (#5326; names in Presets.snowglobeFx.parts):
--   the spin    the flakes inside the globe (Portal_Spin, a Model pivoted at the globe's middle) turn once every
--               `Seconds` (its attribute) and the tree's star (TreeStar_Glow) once every `starSeconds`, while you are
--               within `spinWithin` studs. Still with Reduce Motion.
--   night light the village's Neon glow parts (the tree lights and windows, the stall's bulbs and lanterns, the portal
--               and its wreath, the star first) get a few soft PointLights at night, the nearest spread `lightGap`
--               studs apart, at most `lightsMost` (`lightsLow` on a phone or the low tier). None in Low performance.
-- GE tags SnowglobePortal and SnowglobeCentre; until the tags or parts are in the world nothing runs, so the module
-- is idle outside the event. On this client only; listening only.
-- Numbers in Presets.snowglobeFx.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local SnowglobeFx = {}

local started = false
local box: Part? = nil
local air: ParticleEmitter? = nil
type Portal = { anchor: Attachment, emitter: ParticleEmitter? }
local portals: { [Instance]: Portal } = {}

-- The snow's rate as a share of the preset's: 0 out of reach or in Low performance, `calm` with Reduce Motion, else
-- 1. `distance` is to the village's middle, nil while it is not in the world. Pure.
function SnowglobeFx.air(
	distance: number?,
	within: number,
	low: boolean,
	still: boolean,
	calm: number
): number
	if distance == nil or distance > within or low then
		return 0
	end
	return if still then calm else 1
end

-- Whether the portal swirls: within reach, not Low performance and not Reduce Motion. Pure.
function SnowglobeFx.swirls(distance: number, within: number, low: boolean, still: boolean): boolean
	return distance <= within and not low and not still
end

local function centre(): Vector3?
	for _, instance in CollectionService:GetTagged(Presets.snowglobeFx.centreTag) do
		local at = Context.positionOf(instance)
		if at ~= nil then
			return at
		end
	end
	return nil
end

local function stopAir()
	local part = box
	if part ~= nil then
		part:Destroy()
	end
	box, air = nil, nil
end

local function stepAir()
	local p = Presets.snowglobeFx
	local at = centre()
	local focus = Context.focus()
	local share = SnowglobeFx.air(
		if at ~= nil then Context.distance(at) else nil,
		p.airWithin,
		Context.lowPerformance,
		Context.reducedMotion(),
		p.calmRate
	)
	if share <= 0 or focus == nil then
		stopAir()
		return
	end
	local part = box
	if part == nil then
		local made = Context.effectPart("EffectsSnowglobeAir", p.box, Presets.palette.offwhite)
		made.Transparency = 1
		made.Parent = Context.folder()
		box = made
		local emitter = Particles.attach(p.snow, made)
		if emitter ~= nil then
			emitter.EmissionDirection = Enum.NormalId.Bottom
		end
		air = emitter
		part = made
	end
	local placed: Part = part :: Part
	placed.CFrame = CFrame.new(focus + Vector3.new(0, p.height, 0))
	local running = air
	if running ~= nil then
		Particles.switchOn(running, p.snow)
		running.Rate *= share
	end
end

local function forgetPortal(instance: Instance)
	local portal = portals[instance]
	if portal ~= nil then
		portal.anchor:Destroy()
		portals[instance] = nil
	end
end

local function stepPortals()
	local p = Presets.snowglobeFx
	local low, still = Context.lowPerformance, Context.reducedMotion()
	for _, instance in CollectionService:GetTagged(p.portalTag) do
		local at = Context.positionOf(instance)
		if at == nil or not instance:IsDescendantOf(game) then
			forgetPortal(instance)
			continue
		end
		local spot = (at :: Vector3) + Vector3.new(0, p.portalLift, 0)
		local on = SnowglobeFx.swirls(Context.distance(spot), p.portalWithin, low, still)
		local portal = portals[instance]
		if not on then
			if portal ~= nil then
				forgetPortal(instance)
			end
			continue
		end
		if portal == nil then
			local anchor = Particles.anchor("SnowglobePortal", spot)
			local emitter = Particles.attach(p.swirl, anchor)
			if emitter ~= nil then
				Particles.switchOn(emitter, p.swirl)
			end
			portals[instance] = { anchor = anchor, emitter = emitter }
		end
	end
	for instance in portals do
		if not CollectionService:HasTag(instance, p.portalTag) then
			forgetPortal(instance)
		end
	end
end

-- Part 2 ------------------------------------------------------------------------------------------------------------

type Spinner = { model: Model, base: CFrame, seconds: number }
local spinners: { [Model]: Spinner } = {}
local glowParts: { [BasePart]: number } = {} -- each Neon glow part and its pick rank (the star 1, the rest 2)
local lights: { [BasePart]: PointLight? } = {}

-- Which role an instance's name has: "spin", "star" or "light", else nil. Pure.
function SnowglobeFx.role(name: string, parts: typeof(Presets.snowglobeFx.parts)): string?
	if name == parts.spin then
		return "spin"
	elseif name == parts.star then
		return "star"
	end
	for _, light in parts.lights do
		if name == light then
			return "light"
		end
	end
	return nil
end

export type Spot = { at: Vector3, rank: number, distance: number }

-- The glow parts that get a light: by `rank`, then nearest, none within `gap` studs of one already picked, at most
-- `most`, only within `within`. The result is their indices in `spots`. Pure.
function SnowglobeFx.pickLights(
	spots: { Spot },
	within: number,
	gap: number,
	most: number
): { number }
	local order: { number } = {}
	for index, spot in spots do
		if spot.distance <= within then
			table.insert(order, index)
		end
	end
	table.sort(order, function(a: number, b: number): boolean
		local x, y = spots[a], spots[b]
		if x.rank ~= y.rank then
			return x.rank < y.rank
		end
		return x.distance < y.distance
	end)
	local picked: { number } = {}
	for _, index in order do
		if #picked >= most then
			break
		end
		local clear = true
		for _, other in picked do
			if (spots[other].at - spots[index].at).Magnitude < gap then
				clear = false
				break
			end
		end
		if clear then
			table.insert(picked, index)
		end
	end
	return picked
end

local function addSpinner(model: Model, seconds: number)
	if spinners[model] == nil then
		spinners[model] = { model = model, base = model:GetPivot(), seconds = math.max(seconds, 1) }
	end
end

local function noticed(instance: Instance)
	local p = Presets.snowglobeFx
	local role = SnowglobeFx.role(instance.Name, p.parts)
	if role == nil then
		return
	end
	if role == "spin" and instance:IsA("Model") then
		local seconds = instance:GetAttribute("Seconds")
		addSpinner(instance :: Model, if type(seconds) == "number" then seconds else p.spinSeconds)
	elseif role == "star" then
		if instance:IsA("Model") then
			addSpinner(instance :: Model, p.starSeconds)
			for _, piece in instance:GetDescendants() do
				if piece:IsA("BasePart") then
					glowParts[piece :: BasePart] = 1
				end
			end
		elseif instance:IsA("BasePart") then
			glowParts[instance :: BasePart] = 1
		end
	elseif role == "light" and instance:IsA("BasePart") then
		glowParts[instance :: BasePart] = 2
	end
end

local function stepSpin()
	local p = Presets.snowglobeFx
	local still = Context.reducedMotion()
	local now = os.clock()
	for model, spinner in spinners do
		if model.Parent == nil then
			spinners[model] = nil
			continue
		end
		if still or Context.distance(spinner.base.Position) > p.spinWithin then
			continue
		end
		local turn = (now / spinner.seconds % 1) * 2 * math.pi
		model:PivotTo(spinner.base * CFrame.Angles(0, turn, 0))
	end
end

local function clearLight(part: BasePart)
	local light: PointLight? = lights[part]
	if light ~= nil then
		light:Destroy()
		lights[part] = nil
	end
end

local function stepLights()
	local p = Presets.snowglobeFx
	local on = Context.isNight() and not Context.lowPerformance
	local list: { BasePart } = {}
	local spots: { Spot } = {}
	for part, rank in glowParts do
		if part.Parent == nil then
			glowParts[part] = nil
			clearLight(part)
			continue
		end
		if on then
			table.insert(list, part)
			table.insert(
				spots,
				{ at = part.Position, rank = rank, distance = Context.distance(part.Position) }
			)
		end
	end
	local wanted: { [BasePart]: boolean } = {}
	if on then
		local most = if Context.tier == "low" or Context.lite then p.lightsLow else p.lightsMost
		for _, index in SnowglobeFx.pickLights(spots, p.lightWithin, p.lightGap, most) do
			wanted[list[index]] = true
		end
	end
	for part in lights do
		if not wanted[part] then
			clearLight(part)
		end
	end
	for part in wanted do
		local has: PointLight? = lights[part]
		if has == nil then
			local light = Instance.new("PointLight")
			light.Name = "EffectsSnowglobeLight"
			light.Color = part.Color
			light.Brightness = p.lightBrightness
			light.Range = p.lightRange
			light.Shadows = false
			light.Parent = part
			lights[part] = light
		end
	end
end

local function watchParts()
	local prefix = Presets.snowglobeFx.parts.prefix
	local function check(instance: Instance)
		if string.sub(instance.Name, 1, #prefix) == prefix then
			noticed(instance)
		end
	end
	for _, instance in Workspace:GetDescendants() do
		check(instance)
	end
	Workspace.DescendantAdded:Connect(check)
	RunService.Heartbeat:Connect(function()
		if next(spinners) ~= nil then
			stepSpin()
		end
	end)
end

function SnowglobeFx.start()
	if started then
		return
	end
	started = true
	watchParts()
	task.spawn(function()
		local beat = 0
		while true do
			task.wait(Presets.snowglobeFx.every)
			stepAir()
			stepPortals()
			beat += 1
			if beat % Presets.snowglobeFx.lightEvery == 0 then
				stepLights()
			end
		end
	end)
end

return SnowglobeFx
