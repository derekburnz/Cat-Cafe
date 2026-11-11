--!strict
-- The station reveal burst (#2687 part 3: "a sparkle burst" as the station is revealed). The first time this account
-- comes into an area whose station it owns (Moments.StationReveal, Gameplay's WorldController, once per area), a gold
-- beam rises off that camp's station, gold sparkles and confetti burst over it and two rings spread at its foot, then
-- the Unlocked card follows (UI). The build-in is off since #3191, so this is what marks the moment in the world.
-- Reduce Motion keeps the sparkles only; Low performance halves the pieces. It also fires the `stationReveal` beat
-- from the station for Sound-Agent's fanfare. Listening only.
--
-- Source: the `CampExtra`-tagged station models (shared/CampExtras.TAG) whose `Area` attribute is that area; they
-- stream in whole, so it waits up to `wait` seconds for one.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Beats = require(script.Parent.Parent.Audio.Beats)
local Context = require(script.Parent.Context)
local Moments = require(script.Parent.Parent.Moments)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local StationReveal = {}

local TAG = "CampExtra" -- shared/CampExtras.TAG

local started = false

-- The first streamed-in camp station of `area`.
local function stationOf(area: string): Model?
	for _, instance in CollectionService:GetTagged(TAG) do
		if
			instance:IsA("Model")
			and instance:GetAttribute("Area") == area
			and instance:IsDescendantOf(Workspace)
		then
			return instance :: Model
		end
	end
	return nil
end

-- Plays the burst over `model`.
function StationReveal.play(model: Model)
	local p = Presets.stationReveal
	local frame, size = model:GetBoundingBox()
	local foot = frame.Position - Vector3.new(0, size.Y / 2, 0)
	local over = foot + Vector3.new(0, size.Y + p.lift, 0)
	local few = Context.lowPerformance
	Beats.hit:Fire("stationReveal", model)
	Particles.burst(
		"catchSparkle",
		over,
		if few then p.sparkles // 2 else p.sparkles,
		Presets.palette.golden
	)
	if Context.reducedMotion() then
		return -- the beam, confetti and rings move, so they go
	end
	Particles.beam(foot, Presets.palette.golden, p.beamWidth, p.beamHeight, p.beamSeconds)
	Particles.confetti(over, if few then p.confetti // 2 else p.confetti, p.colours)
	local ring = math.max(size.X, size.Z) + p.ringPad
	for i = 1, p.rings do
		task.delay((i - 1) * p.ringGap, function()
			Particles.ring(
				foot + Vector3.new(0, 0.2, 0),
				Presets.palette.golden,
				ring * i,
				p.ringSeconds
			)
		end)
	end
end

local function reveal(area: unknown, _perkId: unknown)
	if type(area) ~= "string" then
		return
	end
	task.spawn(function()
		local giveUp = os.clock() + Presets.stationReveal.wait
		local model = stationOf(area :: string)
		while model == nil and os.clock() < giveUp do
			task.wait(0.2)
			model = stationOf(area :: string)
		end
		if model ~= nil then
			StationReveal.play(model)
		end
	end)
end

function StationReveal.start()
	if started then
		return
	end
	started = true
	Moments.StationReveal:Connect(reveal)
end

return StationReveal
