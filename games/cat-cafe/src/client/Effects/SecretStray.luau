--!strict
-- A Secret stray in the world (#3470 section 5: "a soft dark aura and a thin beam of light to the sky that can be
-- seen from the camp"). A slow dark haze sits round the cat with a few pale stars drifting up through it, and a
-- thin beam of starlight stands over it, wider the further away you are so it stays a thin line on screen from any
-- distance and fades as you walk up so it never covers the catch. The beam holds still: nothing pulses or flashes.
-- Low performance drops the stars; Reduce Motion changes nothing, since nothing here moves quickly.
--
-- Source: the Stray tag CatService puts on each stray model and its `Rarity` attribute. Until the server knows the
-- Secret rarity (LiveFlag `secretCats`) no stray carries it and nothing here runs. The beam shows only for a cat
-- this client has (a stray outside the streaming range has no model here), for the `most` nearest. Listening only.
-- Numbers in Presets.secretStray and the secretAura and secretStars emitters.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local SecretStray = {}

type Entry = {
	body: BasePart, -- what the haze rides; a cat streamed out and back in gets a new one
	emitters: { ParticleEmitter },
	foot: Part, -- unseen, under the beam; moved to the cat each frame
	beam: Beam,
}

local entries: { [Model]: Entry } = {}
local loop: RBXScriptConnection? = nil
local started = false

local function bodyOf(model: Model): BasePart?
	if model.PrimaryPart ~= nil then
		return model.PrimaryPart
	end
	local part = model:FindFirstChildWhichIsA("BasePart", true)
	return if part ~= nil then part :: BasePart else nil
end

local function isSecret(instance: Instance): boolean
	return instance:IsA("Model")
		and instance:IsDescendantOf(Workspace)
		and instance:GetAttribute("Rarity") == "Secret"
end

local function remove(model: Model)
	local entry: Entry? = entries[model]
	if entry == nil then
		return
	end
	entries[model] = nil
	for _, emitter in entry.emitters do
		emitter:Destroy()
	end
	entry.foot:Destroy()
end

local function make(model: Model): Entry?
	local body = bodyOf(model)
	if body == nil then
		return nil -- not streamed in yet
	end
	local b = Presets.secretStray.beam
	local emitters: { ParticleEmitter } = {}
	local haze = Particles.attach("secretAura", body)
	if haze ~= nil then
		table.insert(emitters, haze)
	end
	if not Context.lowPerformance then
		local stars = Particles.attach("secretStars", body)
		if stars ~= nil then
			table.insert(emitters, stars)
		end
	end
	local light = Logic.glowColour("Secret")
	local foot = Context.effectPart("SecretBeam", Vector3.new(0.2, 0.2, 0.2), light)
	foot.Transparency = 1
	local from = Instance.new("Attachment")
	from.Name = "From"
	from.Position = Vector3.new(0, b.lift, 0)
	from.Parent = foot
	local to = Instance.new("Attachment")
	to.Name = "To"
	to.Position = Vector3.new(0, b.lift + b.height, 0)
	to.Parent = foot
	local beam = Instance.new("Beam")
	beam.Name = "Light"
	beam.Attachment0 = from
	beam.Attachment1 = to
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Color = ColorSequence.new(light)
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Width0 = b.widthMin
	beam.Width1 = b.widthMin
	beam.Parent = foot
	foot.CFrame = CFrame.new(model:GetPivot().Position)
	foot.Parent = Context.folder()
	return { body = body, emitters = emitters, foot = foot, beam = beam }
end

-- Each frame while a Secret stray shows: the beam follows the cat and takes the width and fade for how far you are.
local function step()
	local b = Presets.secretStray.beam
	local camera = Workspace.CurrentCamera
	for model, entry in entries do
		if model.Parent == nil then
			continue -- the next check drops it
		end
		local at = model:GetPivot().Position
		entry.foot.CFrame = CFrame.new(at)
		local distance = if camera ~= nil then (camera.CFrame.Position - at).Magnitude else 0
		local width, foot = Logic.secretBeam(distance)
		entry.beam.Width0 = width
		entry.beam.Width1 = width
		entry.beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, foot),
			NumberSequenceKeypoint.new(1 - b.topFade, foot),
			NumberSequenceKeypoint.new(1, 1),
		})
	end
end

local function check()
	local focus = Context.focus()
	local candidates: { Logic.Candidate<Model> } = {}
	for _, instance in CollectionService:GetTagged("Stray") do
		if isSecret(instance) then
			local model = instance :: Model
			local distance = if focus ~= nil
				then (model:GetPivot().Position - focus).Magnitude
				else 0
			table.insert(candidates, { key = model, distance = distance })
		end
	end
	local wanted: { [Model]: boolean } = {}
	for _, model in Logic.nearestFirst(candidates, {}, math.huge, Presets.secretStray.most) do
		wanted[model] = true
	end
	for model, entry in entries do
		if not wanted[model] or not entry.body:IsDescendantOf(model) then
			remove(model)
		end
	end
	for model in wanted do
		if entries[model] == nil then
			entries[model] = make(model)
		end
	end
	local running = loop
	if next(entries) ~= nil then
		if running == nil then
			loop = RunService.RenderStepped:Connect(step)
		end
	elseif running ~= nil then
		running:Disconnect()
		loop = nil
	end
end

function SecretStray.start()
	if started then
		return
	end
	started = true
	CollectionService:GetInstanceRemovedSignal("Stray"):Connect(function(instance: Instance)
		if instance:IsA("Model") then
			remove(instance :: Model) -- caught or gone: at once
		end
	end)
	task.spawn(function()
		while true do
			check()
			task.wait(Presets.secretStray.checkEvery)
		end
	end)
end

return SecretStray
