--!strict
-- The Tier 6 and 7 stations' cats come alive (#2897; late-stations.md sections 1 and 2):
--   * Oasis Spa: your own soaking cats (SpaPoolController's copies, tagged CatCafeSpaSoak) float in the pool. They
--     bob, sway and slowly look about, each out of step, with a teal ring spreading on the water now and then. A cat
--     whose first level is earned (the card's "ready", Logic.soakReady) hops and wiggles every few seconds with a
--     few gold sparkles, so it reads as "come and collect me".
--   * Relic Museum: an exhibit you have just given (MuseumGalleryController's copies, tagged CatCafeExhibit, with
--     Fresh set) drops onto its plinth with one small bounce and a gold ring, instead of popping in.
-- The steam, splashes and donation sparkles are LateStationFx's.
--
-- Budgets: at most 3 soakers, moved at Presets.stationMotion.rate and only within the device's animRadius. Reduce
-- Motion keeps every cat still and skips the drop (the rings skip themselves). Low performance keeps the motion but
-- drops the ripples and sparkles. The copies are anchored client-only looks, so moving them is PivotTo only.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local StationMotion = {}

-- the tags and attributes the two controllers put on their copies
StationMotion.SOAK_TAG = "CatCafeSpaSoak"
StationMotion.EXHIBIT_TAG = "CatCafeExhibit"

type Soak = {
	base: CFrame,
	top: Vector3, -- over the head, from base
	phase: number,
	moved: boolean,
	nextRipple: number,
	nextSparkle: number,
}
type Drop = { base: CFrame, at: number }

local started = false
local soaks: { [Model]: Soak } = {}
local drops: { [Model]: Drop } = {}

local function overHead(model: Model, base: CFrame): Vector3
	local box, size = model:GetBoundingBox()
	return box.Position + Vector3.new(0, size.Y / 2 + 0.3, 0) - base.Position
end

local function soakAdded(instance: Instance)
	if not instance:IsA("Model") or not instance:IsDescendantOf(Workspace) then
		return
	end
	local model = instance :: Model
	local s = Presets.stationMotion
	local base = model:GetPivot()
	local phase = Logic.phaseOf(model.Name)
	local now = os.clock()
	soaks[model] = {
		base = base,
		top = overHead(model, base),
		phase = phase,
		moved = false,
		nextRipple = now + phase * s.rippleEvery,
		nextSparkle = now + phase * s.readySparkleEvery,
	}
end

local function exhibitAdded(instance: Instance)
	if
		not instance:IsA("Model")
		or instance:GetAttribute("Fresh") ~= true
		or not instance:IsDescendantOf(Workspace)
	then
		return
	end
	local model = instance :: Model
	local base = model:GetPivot()
	if Context.reducedMotion() or Context.distance(base.Position) > Context.budget.animRadius then
		return -- it simply stands there
	end
	drops[model] = { base = base, at = os.clock() }
	model:PivotTo(base + Vector3.new(0, Presets.stationMotion.dropHeight, 0)) -- before it is first drawn
end

local function forget(instance: Instance)
	if instance:IsA("Model") then
		soaks[instance :: Model] = nil
		drops[instance :: Model] = nil
	end
end

-- The water's top under a soaker: its Surface attribute (the pool's Soak attachment), else its pivot.
local function surfaceOf(model: Model, soak: Soak): Vector3
	local surface = model:GetAttribute("Surface")
	return if typeof(surface) == "Vector3" then surface :: Vector3 else soak.base.Position
end

local function stepDrops(now: number)
	local s = Presets.stationMotion
	for model, drop in drops do
		if model.Parent == nil then
			drops[model] = nil
			continue
		end
		local k = (now - drop.at) / s.dropSeconds
		if k >= 1 then
			drops[model] = nil
			model:PivotTo(drop.base)
			Particles.ring(drop.base.Position, Presets.palette.golden, s.dropRing)
			if not Context.lowPerformance then
				Particles.burst(
					"catchSparkle",
					drop.base.Position,
					s.dropSparkle,
					Presets.palette.golden
				)
			end
		else
			model:PivotTo(drop.base + Vector3.new(0, Logic.dropBounce(k) * s.dropHeight, 0))
		end
	end
end

local function stepSoaks(now: number)
	local s = Presets.stationMotion
	local still = Context.reducedMotion()
	local serverNow = Workspace:GetServerTimeNow()
	for model, soak in soaks do
		if model.Parent == nil then
			soaks[model] = nil
			continue
		end
		if still or Context.distance(soak.base.Position) > Context.budget.animRadius then
			if soak.moved then
				soak.moved = false
				model:PivotTo(soak.base)
			end
			continue
		end
		local ready = Logic.soakReady(
			serverNow,
			model:GetAttribute("DoneAt"),
			model:GetAttribute("Levels"),
			model:GetAttribute("StateAt")
		)
		local up, roll, turn = Logic.soakBob(now, soak.phase, ready)
		model:PivotTo(
			soak.base * CFrame.new(0, up, 0) * CFrame.Angles(0, turn, 0) * CFrame.Angles(0, 0, roll)
		)
		soak.moved = true
		if Context.lowPerformance then
			continue
		end
		if now >= soak.nextRipple then
			soak.nextRipple = now + s.rippleEvery
			Particles.ring(
				surfaceOf(model, soak),
				Presets.lateStations.splashColour,
				s.ripple,
				s.rippleSeconds
			)
		end
		if ready and now >= soak.nextSparkle then
			soak.nextSparkle = now + s.readySparkleEvery
			Particles.burst(
				"catchSparkle",
				soak.base.Position + soak.top,
				s.readySparkle,
				Presets.palette.golden
			)
		end
	end
end

function StationMotion.start()
	if started then
		return
	end
	started = true
	for _, instance in CollectionService:GetTagged(StationMotion.SOAK_TAG) do
		soakAdded(instance)
	end
	CollectionService:GetInstanceAddedSignal(StationMotion.SOAK_TAG):Connect(soakAdded)
	CollectionService:GetInstanceRemovedSignal(StationMotion.SOAK_TAG):Connect(forget)
	CollectionService:GetInstanceAddedSignal(StationMotion.EXHIBIT_TAG):Connect(exhibitAdded)
	CollectionService:GetInstanceRemovedSignal(StationMotion.EXHIBIT_TAG):Connect(forget)
	local wait = 0
	RunService.Heartbeat:Connect(function(dt: number)
		if next(drops) ~= nil then
			stepDrops(os.clock()) -- every frame, so the short drop is smooth
		end
		wait -= dt
		if wait > 0 or next(soaks) == nil then
			return
		end
		wait = Presets.stationMotion.rate
		stepSoaks(os.clock())
	end)
end

return StationMotion
