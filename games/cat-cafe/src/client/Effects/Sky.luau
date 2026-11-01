--!strict
-- Clouds in the sky (Derek 2026-10-28 17:05: "add clouds in sky and nicer background of the actual game outside of
-- the map"; the backdrop past the map is Model-Agent's). Roblox's own cloud layer, a Clouds object under Terrain,
-- soft and about half cover, so the pale skybox (sky.py) still shows between them. The sun and moon light it, so it
-- warms at dusk and darkens at night on its own, and a gentle wind drifts it across. Off in Low performance.
--
-- The live place is built from files and has no clouds or wind of its own; a place that has its own Clouds keeps
-- them, and a wind already blowing is left as it is. Nothing in the game follows the wind (no emitter sets
-- WindAffectsDrag, and there is no terrain grass), so the wind only moves the clouds. Only this client's copy
-- changes. Numbers in Presets.sky.

local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Presets = require(script.Parent.Presets)

local Sky = {}

local made: Clouds? = nil
local started = false

-- Shows the clouds, or hides them in Low performance. Call it whenever the settings change; it does nothing
-- before start().
function Sky.refresh()
	if not started then
		return
	end
	local clouds: Clouds
	local existing = made
	if existing ~= nil then
		clouds = existing
	else
		local terrain = Workspace.Terrain
		if terrain:FindFirstChildWhichIsA("Clouds") ~= nil then
			return -- the place's own clouds
		end
		local s = Presets.sky
		clouds = Instance.new("Clouds")
		clouds.Name = "EffectsClouds"
		clouds.Cover = s.cover
		clouds.Density = s.density
		clouds.Color = s.color
		clouds.Parent = terrain
		made = clouds
		if Workspace.GlobalWind.Magnitude < 1e-3 then
			Workspace.GlobalWind = s.wind
		end
	end
	clouds.Enabled = not Context.lowPerformance
end

function Sky.start()
	if started then
		return
	end
	started = true
	Sky.refresh()
end

return Sky
