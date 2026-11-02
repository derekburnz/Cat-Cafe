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
--
-- A Lucky Day (F88, luck-and-rare-moments.md 1c): while the Clock's `LuckyDay` is on by day, the world takes a warm
-- gold tint through a ColorCorrectionEffect of this client's own (the place's Atmosphere and its day and night curve
-- in WorldController are untouched) and our clouds turn gold, easing in at sunrise and out at dusk. Joining during one
-- shows it at once. Numbers in Presets.luckyDay.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Presets = require(script.Parent.Presets)

local Sky = {}

local made: Clouds? = nil
local started = false
local lucky = false -- the Lucky Day look is on
local tint: ColorCorrectionEffect? = nil

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

-- Eases the Lucky Day look on or off, at once when `instant`.
local function setLucky(on: boolean, instant: boolean)
	if on == lucky then
		return
	end
	lucky = on
	local l = Presets.luckyDay
	local effect: ColorCorrectionEffect
	local existing = tint
	if existing ~= nil then
		effect = existing
	else
		effect = Instance.new("ColorCorrectionEffect")
		effect.Name = "EffectsLuckyDay"
		effect.TintColor = Color3.new(1, 1, 1)
		effect.Parent = Lighting
		tint = effect
	end
	local info = TweenInfo.new(
		if instant then 0 else l.seconds,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut
	)
	TweenService:Create(effect, info, {
		TintColor = if on then l.tint else Color3.new(1, 1, 1),
		Saturation = if on then l.saturation else 0,
		Brightness = if on then l.brightness else 0,
	}):Play()
	local clouds = made
	if clouds ~= nil then
		TweenService:Create(clouds, info, { Color = if on then l.clouds else Presets.sky.color })
			:Play()
	end
end

local function followClock()
	local clock = ReplicatedStorage:WaitForChild("Clock")
	local function read(instant: boolean)
		setLucky(
			Logic.luckyDayOn(clock:GetAttribute("LuckyDay"), clock:GetAttribute("Phase")),
			instant
		)
	end
	read(true)
	clock:GetAttributeChangedSignal("LuckyDay"):Connect(function()
		read(false)
	end)
	clock:GetAttributeChangedSignal("Phase"):Connect(function()
		read(false)
	end)
end

function Sky.start()
	if started then
		return
	end
	started = true
	Sky.refresh()
	task.spawn(followClock)
end

return Sky
