--!strict
-- Snowglobe Village's world effects (the Christmas Event, Tue Dec 1 to Sun Jan 3; Design-Agent's
-- snowglobe-village-spec section 7). Part 1, the two that need no Christmas models yet:
--   the air     gentle snow falls round you while you are within `airWithin` studs of the village's middle (tag
--               `centreTag`), the Snowy Mountain's own `snowfall` flakes. A fifth as thick with Reduce Motion, none
--               in Low performance.
--   the portal  the giant snow globe in the Town Square (tag `portalTag`) swirls with icy sparkles while you are
--               within `portalWithin` studs, so it reads as a way in from across the square; still with Reduce
--               Motion, none in Low performance. Its pivot is the globe's base; the swirl sits `portalLift` up.
-- The tag names wait on Model-Agent's village (due Nov 23) and Gameplay-Engineer's event row; until either is in
-- the world nothing runs, so the module is idle outside the event. On this client only; listening only.
-- Numbers in Presets.snowglobeFx.

local CollectionService = game:GetService("CollectionService")

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

function SnowglobeFx.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		while true do
			task.wait(Presets.snowglobeFx.every)
			stepAir()
			stepPortals()
		end
	end)
end

return SnowglobeFx
