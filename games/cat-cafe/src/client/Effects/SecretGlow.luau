--!strict
-- The Secret cats' own glow (#3544; Derek 2026-11-12: "make secrets have a special glow also when you see them
-- around cafe or world"). Every Secret cat near you, a stray out in an area or one somebody owns (walking a cafe,
-- on a perch, at a station, carried or riding in a Backpack), sits in a soft starlight halo that slowly breathes,
-- lights the ground round it a little and, for the owned ones, lets a few small stars drift up. It is the same for
-- all three cats, so it comes to mean "Secret", and it is pale violet white, unlike gold's sparkle and the rainbow
-- coat, and rides on top of both without touching the cat's own colours.
--
-- It is a glow, not a pointer: no arrow, nothing on top of walls (particles and a light are hidden by what stands
-- in front of them) and no Highlight, so a full cafe never meets the Highlight limit. The halo is locked to the
-- cat, so it stays on a stray that runs. It fades out between `full` and `within` studs. Low performance keeps a
-- thinner halo alone (no light, no stars), never nothing. Reduce Motion holds the breathing still.
--
-- Source, listening only: the `CatId` attribute every cat model carries, looked up in the Catalog. Until the
-- server has Secret cats out (LiveFlag `secretCats`) no model is one and nothing here runs. A stray's dark haze,
-- stars and sky beam stay with Effects/SecretStray. Numbers in Presets.secretGlow and the secretHalo emitter.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage.Shared.Catalog)

local CafeWalk = require(script.Parent.CafeWalk)
local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local SecretGlow = {}

type Glow = {
	body: BasePart, -- what it rides; a cat streamed out and back in gets a new one
	halo: ParticleEmitter?,
	stars: ParticleEmitter?,
	light: PointLight?,
	distance: number,
	made: { Instance },
}

local known: { [Model]: boolean } = {} -- every Secret cat model this client has
local watched: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local glows: { [Model]: Glow } = {}
local loop: RBXScriptConnection? = nil
local began = os.clock()
local started = false

local function bodyOf(model: Model): BasePart?
	if model.PrimaryPart ~= nil then
		return model.PrimaryPart
	end
	local part = model:FindFirstChildWhichIsA("BasePart", true)
	return if part ~= nil then part :: BasePart else nil
end

local function isSecret(model: Model): boolean
	local id = model:GetAttribute("CatId")
	if type(id) ~= "string" then
		return false
	end
	local def = Catalog.getCat(id)
	return def ~= nil and def.rarity == Catalog.SECRET
end

local function remove(model: Model)
	local glow: Glow? = glows[model]
	if glow == nil then
		return
	end
	glows[model] = nil
	for _, instance in glow.made do
		instance:Destroy()
	end
end

local function make(model: Model, distance: number): Glow?
	local body = bodyOf(model)
	if body == nil then
		return nil -- not streamed in yet
	end
	local g = Presets.secretGlow
	local made: { Instance } = {}
	local halo = Particles.attach("secretHalo", body)
	if halo ~= nil then
		halo.LockedToPart = true -- it stays round a stray that runs
		halo.ZOffset = g.behind -- behind the cat, so its own colours are not washed out
		table.insert(made, halo)
	end
	local stars: ParticleEmitter? = nil
	local light: PointLight? = nil
	if not Context.lowPerformance then
		-- a stray already has its stars from SecretStray
		if not CollectionService:HasTag(model, "Stray") then
			stars = Particles.attach("secretStars", body)
			if stars ~= nil then
				table.insert(made, stars)
			end
		end
		local lamp = Instance.new("PointLight")
		lamp.Name = "SecretGlow"
		lamp.Color = g.colour
		lamp.Range = g.range
		lamp.Brightness = 0
		lamp.Shadows = false
		lamp.Parent = body
		light = lamp
		table.insert(made, lamp)
	end
	return {
		body = body,
		halo = halo,
		stars = stars,
		light = light,
		distance = distance,
		made = made,
	}
end

-- Each frame while a glow shows: the light breathes and fades with distance.
local function step()
	local t = os.clock() - began
	local reduced = Context.reducedMotion()
	for _, glow in glows do
		local light = glow.light
		if light ~= nil then
			light.Brightness = Presets.secretGlow.brightness
				* Logic.secretGlowLevel(glow.distance, t, reduced)
		end
	end
end

local function check()
	local g = Presets.secretGlow
	local most = if Context.lowPerformance then g.mostLow else g.most
	local candidates: { Logic.Candidate<Model> } = {}
	local away: { [Model]: number } = {}
	for model in known do
		if not model:IsDescendantOf(Workspace) or not isSecret(model) then
			known[model] = nil
			remove(model)
			continue
		end
		-- not a cat hidden by Show other cats, nor a waiter's seated model while its copy walks (CafeWalk)
		if model:GetAttribute("HiddenLocal") == true or CafeWalk.isAway(model) then
			continue
		end
		local distance = Context.distance(model:GetPivot().Position)
		away[model] = distance
		table.insert(candidates, { key = model, distance = distance })
	end
	local wanted: { [Model]: boolean } = {}
	for _, model in Logic.nearest(candidates, g.within, most) do
		wanted[model] = true
	end
	for model, glow in glows do
		if not wanted[model] or not glow.body:IsDescendantOf(model) then
			remove(model)
		end
	end
	for model in wanted do
		local glow: Glow? = glows[model]
		if glow == nil then
			glow = make(model, away[model])
			if glow ~= nil then
				glows[model] = glow
			end
		end
		if glow ~= nil then
			glow.distance = away[model]
			-- the halo thins out with distance (and on Low performance through the budget's rateScale)
			local share = Logic.secretGlowFade(glow.distance)
			local halo = glow.halo
			if halo ~= nil then
				Particles.switchOn(halo, "secretHalo")
				halo.Rate *= share
			end
			local stars = glow.stars
			if stars ~= nil then
				stars.Enabled = share > g.starsFrom
			end
		end
	end
	local running = loop
	if next(glows) ~= nil then
		if running == nil then
			loop = RunService.Heartbeat:Connect(step)
		end
	elseif running ~= nil then
		running:Disconnect()
		loop = nil
	end
end

local function consider(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local model = instance :: Model
	if watched[model] then
		return
	end
	if model:GetAttribute("CatId") == nil then
		return -- every cat model carries CatId before it is parented
	end
	watched[model] = true
	if isSecret(model) then
		known[model] = true
	end
end

function SecretGlow.start()
	if started then
		return
	end
	started = true
	for _, descendant in Workspace:GetDescendants() do
		consider(descendant)
	end
	Workspace.DescendantAdded:Connect(consider)
	task.spawn(function()
		local warned = false
		while true do
			-- one odd model must not end every glow for the session: report it once and keep going
			local ok, problem = pcall(check)
			if not ok and not warned then
				warned = true
				warn("[Effects] SecretGlow: " .. tostring(problem))
			end
			task.wait(Presets.secretGlow.checkEvery)
		end
	end)
end

return SecretGlow
