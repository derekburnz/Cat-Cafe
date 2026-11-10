--!strict
-- Crumbs off the bowl while the first bait cat eats (#2946). Animation-Engineer's FirstBaitCut fires
-- `Moments.FirstBaitEat(bowlPosition, seconds)` as the cat starts eating; a few blush and cream crumbs pop out of the
-- bowl every `gap` seconds for that long (Presets.baitCrumbs). Kept with Reduce Motion (small, slow), none in Low
-- performance. Listening only: no remotes, no game state.

local Context = require(script.Parent.Context)
local Moments = require(script.Parent.Parent.Moments)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local BaitCrumbs = {}

local started = false

local function eat(at: Vector3, seconds: number)
	if Context.lowPerformance then
		return
	end
	local p = Presets.baitCrumbs
	local spot = at + Vector3.new(0, p.lift, 0)
	local ends = os.clock() + math.min(seconds, p.most)
	task.spawn(function()
		while os.clock() < ends do
			Particles.burst(p.preset, spot, p.count)
			task.wait(p.gap)
		end
	end)
end

function BaitCrumbs.start()
	if started then
		return
	end
	started = true
	local moment = (Moments :: any).FirstBaitEat
	if moment ~= nil then
		moment:Connect(function(at: unknown, seconds: unknown)
			if typeof(at) == "Vector3" and type(seconds) == "number" and seconds > 0 then
				eat(at :: Vector3, seconds :: number)
			end
		end)
	end
end

return BaitCrumbs
