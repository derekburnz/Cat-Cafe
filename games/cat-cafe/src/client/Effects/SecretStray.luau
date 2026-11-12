--!strict
-- A Secret stray in the world (#3470 section 5: "a soft dark aura and a thin beam of light to the sky that can be
-- seen from the camp"). A slow dark haze sits round the cat with a few pale stars drifting up through it, and a
-- thin beam of starlight stands over it, wider the further away you are so it stays a thin line on screen from any
-- distance and fades as you walk up so it never covers the catch. The beam holds still: nothing pulses or flashes.
-- Low performance drops the stars; Reduce Motion changes nothing, since nothing here moves quickly.
--
-- Sources. The haze: the Stray tag CatService puts on each stray model and its `Rarity` attribute, for a cat this
-- client has. The beam: the server's beacons, so it shows for a Secret stray too far away to be streamed in: the
-- Folder `SecretBeacons` in ReplicatedStorage (Catching.SECRET_BEACONS, made when the first Secret stray spawns)
-- holds one Vector3Value per live Secret stray, named by its StrayId, its Value the cat's position every 2 seconds.
-- The beam glides between those positions, and stands on the cat itself while its model is here. A Secret stray
-- with a model and no beacon (an older server) still gets its beam. Until the server knows the Secret rarity
-- (LiveFlag `secretCats`) there is no beacon and no such stray, and nothing here runs. Listening only. Numbers in
-- Presets.secretStray and the secretAura and secretStars emitters.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local SecretStray = {}

type Aura = {
	body: BasePart, -- what the haze rides; a cat streamed out and back in gets a new one
	emitters: { ParticleEmitter },
}

type Light = {
	foot: Part, -- unseen, under the beam; moved to the spot each frame
	beam: Beam,
	at: Vector3, -- where the beam stands now
	model: Model?, -- the cat, while this client has it
	beacon: Vector3Value?, -- the server's word on where it is
}

local auras: { [Model]: Aura } = {}
local lights: { [string]: Light } = {}
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

-- The key a stray's beam goes by: its StrayId, which is also its beacon's name.
local function keyOf(model: Model): string
	local id = model:GetAttribute("StrayId")
	return if type(id) == "string" and id ~= "" then id else model:GetFullName()
end

local function removeAura(model: Model)
	local aura: Aura? = auras[model]
	if aura == nil then
		return
	end
	auras[model] = nil
	for _, emitter in aura.emitters do
		emitter:Destroy()
	end
end

local function removeLight(key: string)
	local light: Light? = lights[key]
	if light == nil then
		return
	end
	lights[key] = nil
	light.foot:Destroy()
end

local function makeAura(model: Model): Aura?
	local body = bodyOf(model)
	if body == nil then
		return nil -- not streamed in yet
	end
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
	return { body = body, emitters = emitters }
end

local function makeLight(at: Vector3): Light
	local b = Presets.secretStray.beam
	local colour = Logic.glowColour("Secret")
	local foot = Context.effectPart("SecretBeam", Vector3.new(0.2, 0.2, 0.2), colour)
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
	beam.Color = ColorSequence.new(colour)
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Width0 = b.widthMin
	beam.Width1 = b.widthMin
	beam.Parent = foot
	foot.CFrame = CFrame.new(at)
	foot.Parent = Context.folder()
	return { foot = foot, beam = beam, at = at }
end

-- Each frame while a beam shows: it stands on the cat, or glides to the beacon's last word, and takes the width and
-- fade for how far you are.
local function step(dt: number)
	local b = Presets.secretStray.beam
	local camera = Workspace.CurrentCamera
	for _, light in lights do
		local model = light.model
		local beacon = light.beacon
		if model ~= nil and model.Parent ~= nil then
			light.at = model:GetPivot().Position
		elseif beacon ~= nil then
			light.at = Logic.secretGlide(light.at, beacon.Value, dt)
		end
		local at = light.at
		light.foot.CFrame = CFrame.new(at)
		local distance = if camera ~= nil then (camera.CFrame.Position - at).Magnitude else 0
		local width, foot = Logic.secretBeam(distance)
		light.beam.Width0 = width
		light.beam.Width1 = width
		light.beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, foot),
			NumberSequenceKeypoint.new(1 - b.topFade, foot),
			NumberSequenceKeypoint.new(1, 1),
		})
	end
end

local function check()
	local s = Presets.secretStray
	local focus = Context.focus()
	local function away(position: Vector3): number
		return if focus ~= nil then (position - focus).Magnitude else 0
	end
	-- every Secret stray this client knows of, by key: its model, its beacon or both
	local models: { [string]: Model } = {}
	local beacons: { [string]: Vector3Value } = {}
	local near: { Logic.Candidate<Model> } = {}
	local spots: { Logic.Candidate<string> } = {}
	for _, instance in CollectionService:GetTagged("Stray") do
		if isSecret(instance) then
			local model = instance :: Model
			local key = keyOf(model)
			local distance = away(model:GetPivot().Position)
			models[key] = model
			table.insert(near, { key = model, distance = distance })
			table.insert(spots, { key = key, distance = distance })
		end
	end
	local folder = ReplicatedStorage:FindFirstChild(s.beacons)
	if folder ~= nil then
		for _, child in folder:GetChildren() do
			if child:IsA("Vector3Value") then
				local value = child :: Vector3Value
				beacons[value.Name] = value
				local here: Model? = models[value.Name]
				if here == nil then
					table.insert(spots, { key = value.Name, distance = away(value.Value) })
				end
			end
		end
	end

	local wantedAura: { [Model]: boolean } = {}
	for _, model in Logic.nearestFirst(near, {}, math.huge, s.most) do
		wantedAura[model] = true
	end
	for model, aura in auras do
		if not wantedAura[model] or not aura.body:IsDescendantOf(model) then
			removeAura(model)
		end
	end
	for model in wantedAura do
		if auras[model] == nil then
			local made = makeAura(model)
			if made ~= nil then
				auras[model] = made
			end
		end
	end

	local wantedLight: { [string]: boolean } = {}
	for _, key in Logic.nearestFirst(spots, {}, math.huge, s.beams) do
		wantedLight[key] = true
	end
	for key in lights do
		if not wantedLight[key] then
			removeLight(key)
		end
	end
	for key in wantedLight do
		local model: Model? = models[key]
		local beacon: Vector3Value? = beacons[key]
		local light: Light? = lights[key]
		if light == nil then
			local at: Vector3? = nil
			if model ~= nil then
				at = model:GetPivot().Position
			elseif beacon ~= nil then
				at = beacon.Value
			end
			if at ~= nil then
				local made = makeLight(at)
				lights[key] = made
				light = made
			end
		end
		if light ~= nil then
			light.model = model
			light.beacon = beacon
		end
	end

	local running = loop
	if next(lights) ~= nil then
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
			removeAura(instance :: Model) -- caught or gone: at once
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
