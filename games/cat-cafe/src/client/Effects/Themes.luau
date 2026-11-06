--!strict
-- The cafe themes' own touches (#1624, store-pass-looks.md section 5). The Grand Cafe's chandelier: a warm light
-- under its six candle flames flickers softly, and now and then a flame catches a small glint. Its gold trims'
-- sweep is Decor's (`theme_grand`). With Reduce Motion the light holds still and there are no glints; in Low
-- performance it holds still too.
--
-- Source: the server's ThemeInside model in each plot (Gameplay-Engineer, #1687), its `Asset` attribute naming
-- CatCafe_Plot_ThemeGrandChandelier, and the chandelier's `_Glow` child Model (the six flames on a ring of `radius`
-- studs, themes.py). Only the nearest `most` within `within` studs light up. Listening only. Numbers in
-- Presets.themes.

local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local Themes = {}

type Chandelier = {
	light: PointLight?,
	holder: Part?,
	nextFlicker: number, -- os.clock()
	nextGlint: number,
}

local chandeliers: { [Model]: Chandelier } = {}
local started = false

local function flames(model: Model): Model?
	for _, child in model:GetDescendants() do
		if child:IsA("Model") and string.sub(child.Name, -5) == "_Glow" then
			return child :: Model
		end
	end
	return nil
end

local function douse(c: Chandelier)
	local holder = c.holder
	if holder ~= nil then
		c.holder = nil
		c.light = nil
		holder:Destroy()
	end
end

local function light(model: Model, c: Chandelier, now: number)
	local p = Presets.themes.chandelier
	local glow = flames(model)
	if glow == nil then
		douse(c) -- not streamed in yet
		return
	end
	local centre = glow:GetBoundingBox().Position
	local current = c.light
	if current == nil or c.holder == nil or (c.holder :: Part).Parent == nil then
		local holder = Context.effectPart("ChandelierLight", Vector3.new(0.1, 0.1, 0.1), p.colour)
		holder.Transparency = 1
		holder.Position = centre - Vector3.new(0, p.below, 0)
		local made = Instance.new("PointLight")
		made.Color = p.colour
		made.Range = p.range
		made.Brightness = p.brightness
		made.Shadows = false
		made.Parent = holder
		holder.Parent = Context.folder()
		c.holder, c.light = holder, made
		current = made
	end
	local still = Context.reducedMotion() or Context.lowPerformance
	if still then
		(current :: PointLight).Brightness = p.brightness
		return
	end
	if now >= c.nextFlicker then
		c.nextFlicker = now
			+ p.flickerEvery[1]
			+ math.random() * (p.flickerEvery[2] - p.flickerEvery[1]);
		(current :: PointLight).Brightness = p.brightness
			* (1 + (math.random() * 2 - 1) * p.flicker)
	end
	if now >= c.nextGlint then
		c.nextGlint = now + p.glintEvery * (0.7 + math.random() * 0.6)
		local angle = math.random() * 2 * math.pi
		local turn = model:GetPivot().Rotation
		local at = centre
			+ turn * Vector3.new(math.cos(angle) * p.radius, 0, math.sin(angle) * p.radius)
		Particles.burst("decorGlint", at, p.glints, p.colour)
	end
end

local function step()
	local p = Presets.themes.chandelier
	local now = os.clock()
	local candidates: { Logic.Candidate<Model> } = {}
	for model, c in chandeliers do
		if model.Parent == nil or model:GetAttribute("Asset") ~= p.asset then
			douse(c)
			chandeliers[model] = nil
		else
			table.insert(
				candidates,
				{ key = model, distance = Context.distance(model:GetPivot().Position) }
			)
		end
	end
	local chosen: { [Model]: boolean } = {}
	for _, model in Logic.nearest(candidates, p.within, p.most) do
		chosen[model] = true
		light(model, chandeliers[model], now)
	end
	for model, c in chandeliers do
		if not chosen[model] then
			douse(c)
		end
	end
end

local function consider(instance: Instance)
	if
		not instance:IsA("Model")
		or instance:GetAttribute("Asset") ~= Presets.themes.chandelier.asset
	then
		return
	end
	local known: Chandelier? = chandeliers[instance :: Model]
	if known then
		return
	end
	chandeliers[instance :: Model] =
		{ light = nil, holder = nil, nextFlicker = 0, nextGlint = os.clock() }
end

function Themes.start()
	if started then
		return
	end
	started = true
	for _, descendant in Workspace:GetDescendants() do
		consider(descendant)
	end
	Workspace.DescendantAdded:Connect(consider)
	task.spawn(function()
		while true do
			task.wait(Presets.themes.step)
			step()
		end
	end)
end

return Themes
