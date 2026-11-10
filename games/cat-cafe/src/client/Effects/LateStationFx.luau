--!strict
-- The Tier 6 and 7 stations' effects (#2925; late-stations.md sections 1 and 2). The Oasis Spa's pool steams gently
-- for everyone near it (one emitter, still with Reduce Motion, off in Low performance). Your own spa results splash
-- a teal ring and droplets on the pool when a cat goes in, and send gold sparkles up off it for each cat that levels
-- up on a collect. A Relic Museum donation pops gold sparkles at its golden idol case; one that finishes a room adds
-- confetti, a gold ring and a short gold beam. The card's own tile sparkle is StoreBurst.play(tile, "exhibit" or
-- "room"), called by the UI.
--
-- Sources: the `LateStation`-tagged models (WorldBuilder; `StationId` "spa" or "museum") with the `Steam`,
-- `SparkleAnchor` attachments and the `..._Water` part of Model-Agent's art, and the server's
-- LateStationResult(stationId, ok, detail), hooked when it appears. Listening only. Numbers in Presets.lateStations.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local LateStationFx = {}

local TAG = "LateStation"

local started = false
local steams: { [Model]: ParticleEmitter } = {}
local spas: { [Model]: boolean } = {}

local function stationOf(id: string): Model?
	for _, instance in CollectionService:GetTagged(TAG) do
		if
			instance:IsA("Model")
			and instance:IsDescendantOf(Workspace)
			and instance:GetAttribute("StationId") == id
		then
			return instance :: Model
		end
	end
	return nil
end

local function waterOf(model: Model): BasePart?
	local suffix = Presets.lateStations.water
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name:sub(-#suffix) == suffix then
			return descendant :: BasePart
		end
	end
	return nil
end

-- The pool's top middle: the water part's top, else the model's middle.
local function poolTop(model: Model): Vector3
	local water = waterOf(model)
	if water ~= nil then
		return water.Position + Vector3.new(0, water.Size.Y / 2, 0)
	end
	return model:GetBoundingBox().Position
end

local function anchorAt(model: Model, name: string): Vector3?
	local anchor = model:FindFirstChild(name, true)
	if anchor ~= nil and anchor:IsA("Attachment") then
		return (anchor :: Attachment).WorldPosition
	end
	return nil
end

local function near(at: Vector3): boolean
	return Context.distance(at) <= Context.budget.animRadius
end

-- The steam on one spa: made once on its `Steam` attachment (else an anchor over the water), switched by distance.
local function steamOf(model: Model): ParticleEmitter?
	local made = steams[model]
	if made ~= nil and made.Parent ~= nil then
		return made
	end
	local host: Instance? = model:FindFirstChild("Steam", true)
	if host == nil or not host:IsA("Attachment") then
		if model:FindFirstChildWhichIsA("BasePart", true) == nil then
			return nil -- not streamed in yet
		end
		host = Particles.anchor("SpaSteam", poolTop(model))
	end
	local preset = Presets.lateStations.steamPreset
	local emitter = Particles.attach(preset, host :: Instance)
	if emitter ~= nil then
		emitter.Enabled = false
		steams[model] = emitter
	end
	return emitter
end

local function stepSteam()
	for model in spas do
		if model.Parent == nil then
			spas[model] = nil
			local emitter = steams[model]
			steams[model] = nil
			if emitter ~= nil then
				emitter:Destroy()
			end
			continue
		end
		local on = not Context.lowPerformance
		if on then
			local at = anchorAt(model, "Steam") or poolTop(model)
			on = Context.distance(at) <= Context.budget.ambientRadius
		end
		local emitter = if on then steamOf(model) else steams[model]
		if emitter ~= nil then
			if on and not emitter.Enabled then
				Particles.switchOn(emitter, Presets.lateStations.steamPreset)
			elseif not on then
				emitter.Enabled = false
			end
		end
	end
end

local function stationAdded(instance: Instance)
	if instance:IsA("Model") and instance:GetAttribute("StationId") == "spa" then
		spas[instance :: Model] = true
	end
end

local function spaResult(detail: { [string]: any })
	local model = stationOf("spa")
	if model == nil then
		return
	end
	local top = poolTop(model)
	if not near(top) then
		return
	end
	local p = Presets.lateStations
	local relaxed = detail.relaxed
	if type(relaxed) == "table" then
		local bursts = math.min(#relaxed, p.levelUpMost)
		for i = 1, bursts do
			task.delay((i - 1) * p.levelUpGap, function()
				Particles.burst("fishRise", top, p.levelUp, Presets.palette.golden)
			end)
		end
	elseif type(detail.uid) == "string" and detail.bought == nil then
		Particles.burst("splashDrops", top, p.splash, p.splashColour)
		Particles.ring(top, p.splashColour, p.splashRing)
	end
end

local function museumResult(detail: { [string]: any })
	local model = stationOf("museum")
	if model == nil then
		return
	end
	local at = anchorAt(model, "SparkleAnchor") or model:GetBoundingBox().Position
	if not near(at) then
		return
	end
	local p = Presets.lateStations
	Particles.burst("catchSparkle", at, p.donate, Presets.palette.golden)
	if type(detail.room) == "string" then
		local ground = model:GetBoundingBox().Position
		local _, size = model:GetBoundingBox()
		ground -= Vector3.new(0, size.Y / 2, 0)
		Particles.confetti(at, math.ceil(Context.budget.confetti * p.roomConfetti))
		Particles.ring(ground, Presets.palette.golden, p.roomRing)
		Particles.beam(ground, Presets.palette.golden, p.beamWidth, p.beamHeight, p.beamSeconds)
	end
end

function LateStationFx.start()
	if started then
		return
	end
	started = true
	for _, instance in CollectionService:GetTagged(TAG) do
		stationAdded(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(stationAdded)
	local wait = 0
	RunService.Heartbeat:Connect(function(dt: number)
		wait -= dt
		if wait <= 0 then
			wait = 1
			stepSteam()
		end
	end)
	Context.whenRemote("LateStationResult", function(remote: RemoteEvent)
		remote.OnClientEvent:Connect(function(stationId: unknown, ok: unknown, detail: unknown)
			if ok ~= true or type(detail) ~= "table" then
				return
			end
			local d = detail :: { [string]: any }
			if stationId == "spa" then
				spaResult(d)
			elseif stationId == "museum" then
				museumResult(d)
			end
		end)
	end)
end

return LateStationFx
