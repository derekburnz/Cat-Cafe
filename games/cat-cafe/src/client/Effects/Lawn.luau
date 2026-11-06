--!strict
-- The front lawn pieces' own effects (#1283, front-lawn.md section 5; Derek2 2026-11-05: lawn decor "should have
-- effects"). What the models already do stays where it is: `_Bulbs` glow at night (WorldController), `_Swing`,
-- `_Spin` and `_Bob` move (Motion), `_Flowers` draw butterflies (Ambient) and `_Water` splashes (Splash). On top:
-- fireflies round the Lamp Post at night, ripples on the Bird Bath, a lantern light in the Garden Gnome Cat's paws at
-- night, the Little Fountain's spilling drops, basin ripples and night underglow, a glint off the Balloon Bunch, the
-- Fairy Light Arch's twinkling bulbs and fireflies at night, petals off the Flower Cart, a gold glint off the Cat
-- Tree Sign's star and twinkles on its bulbs at night, and gold motes and glints round the Golden Paw Statue.
--
-- Source: the lawn Models LawnBuilder stands in each plot's Lawn folder, carrying `LawnId` (the piece id), and
-- their children by name (lawn.py). Only the nearest budget.lawnEffects pieces within `within` studs show anything;
-- Reduce Motion drops the drifting particles and rings and keeps the lights and glints; Low performance shows none.
-- Listening only. Numbers in Presets.lawn.

local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local Lawn = {}

type Piece = {
	spec: Presets.LawnSpec,
	anchor: Attachment?, -- holds the steady emitter
	light: Part?,
	nextPulse: number, -- os.clock()
	nextTwinkle: number,
}

local pieces: { [Model]: Piece } = {}
local started = false

-- The first descendant whose name ends with `suffix` (lawn.py names children <model>_Water, <model>_Paw_Spin...).
local function find(model: Model, suffix: string): Instance?
	for _, descendant in model:GetDescendants() do
		local name = descendant.Name
		if string.sub(name, -#suffix) == suffix then
			return descendant
		end
	end
	return nil
end

local function spot(model: Model, at: string?, offset: Vector3): Vector3
	if at ~= nil then
		local found = find(model, at)
		if found ~= nil and found:IsA("Model") then
			return (found :: Model):GetBoundingBox().Position + offset
		elseif found ~= nil and found:IsA("BasePart") then
			return (found :: BasePart).Position + offset
		end
	end
	return (model:GetPivot() * CFrame.new(offset)).Position
end

local function stopEmitter(p: Piece)
	local anchor = p.anchor
	if anchor ~= nil then
		p.anchor = nil
		local lifetime = 1
		for _, emitter in anchor:GetChildren() do
			if emitter:IsA("ParticleEmitter") then
				(emitter :: ParticleEmitter).Enabled = false
				lifetime = math.max(lifetime, (emitter :: ParticleEmitter).Lifetime.Max)
			end
		end
		-- the particles already out drift on and fade
		Debris:AddItem(anchor, lifetime + 0.2)
	end
end

local function stopLight(p: Piece)
	local light = p.light
	if light ~= nil then
		p.light = nil
		light:Destroy()
	end
end

local function stop(p: Piece)
	stopEmitter(p)
	stopLight(p)
end

local function runEmitter(model: Model, p: Piece, wanted: boolean)
	local e = p.spec.emitter
	if e == nil or not wanted then
		stopEmitter(p)
		return
	end
	local anchor = p.anchor
	if anchor ~= nil and anchor.Parent ~= nil then
		local emitter = anchor:FindFirstChildOfClass("ParticleEmitter")
		if emitter ~= nil then
			Particles.switchOn(emitter :: ParticleEmitter, e.name) -- a new budget reaches it
		end
		return
	end
	local made = Particles.anchor("Lawn_" .. e.name, spot(model, e.at, e.offset))
	Particles.attach(e.name, made)
	p.anchor = made
end

local function runLight(model: Model, p: Piece, wanted: boolean)
	local l = p.spec.light
	if l == nil or not wanted then
		stopLight(p)
		return
	end
	if p.light ~= nil and (p.light :: Part).Parent ~= nil then
		return
	end
	local part = Context.effectPart("LawnLight", Vector3.new(0.1, 0.1, 0.1), l.colour)
	part.Transparency = 1
	part.Position = spot(model, l.at, l.offset)
	local light = Instance.new("PointLight")
	light.Color = l.colour
	light.Range = l.range
	light.Brightness = l.brightness
	light.Shadows = false
	light.Parent = part
	part.Parent = Context.folder()
	p.light = part
end

local function runPulse(model: Model, p: Piece, now: number)
	local pulse = p.spec.pulse
	if pulse == nil or now < p.nextPulse then
		return
	end
	p.nextPulse = now + pulse.every
	local at = spot(model, pulse.at, pulse.offset)
	local burst = pulse.burst
	if burst ~= nil then
		Particles.burst(burst, at, pulse.count or 3, pulse.colour)
	end
	local ring = pulse.ring
	if ring ~= nil then
		Particles.ring(at, pulse.colour, ring) -- skipped with Reduce Motion
	end
end

local function runTwinkle(model: Model, p: Piece, now: number)
	local t = p.spec.twinkle
	if t == nil or now < p.nextTwinkle then
		return
	end
	p.nextTwinkle = now + t.every
	local holder = find(model, t.at)
	if holder == nil then
		return
	end
	local bulbs: { BasePart } = {}
	if holder:IsA("BasePart") then
		table.insert(bulbs, holder :: BasePart)
	end
	for _, descendant in holder:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(bulbs, descendant :: BasePart)
		end
	end
	if #bulbs > 0 then
		local bulb = bulbs[math.random(1, #bulbs)]
		Particles.burst("decorGlint", bulb.Position, t.count, t.colour)
	end
end

local function step()
	local now = os.clock()
	local candidates: { Logic.Candidate<Model> } = {}
	for model, p in pieces do
		if model.Parent == nil then
			stop(p)
			pieces[model] = nil
		else
			table.insert(
				candidates,
				{ key = model, distance = Context.distance(model:GetPivot().Position) }
			)
		end
	end
	local night = Context.isNight()
	local calm = Context.reducedMotion()
	local chosen: { [Model]: boolean } = {}
	for _, model in Logic.nearest(candidates, Presets.lawn.within, Context.budget.lawnEffects) do
		chosen[model] = true
		local p = pieces[model]
		local spec = p.spec
		local e = spec.emitter
		runEmitter(model, p, e ~= nil and not calm and (e.night ~= true or night))
		local l = spec.light
		runLight(model, p, l ~= nil and (l.night ~= true or night))
		runPulse(model, p, now)
		if night then
			runTwinkle(model, p, now)
		end
	end
	for model, p in pieces do
		if not chosen[model] then
			stop(p)
		end
	end
end

local function consider(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local known: Piece? = pieces[instance :: Model]
	if known then
		return
	end
	local id = instance:GetAttribute("LawnId")
	if type(id) ~= "string" then
		return
	end
	local spec: Presets.LawnSpec? = Presets.lawn.pieces[id]
	if not spec then
		return
	end
	local now = os.clock()
	pieces[instance :: Model] = {
		spec = spec,
		anchor = nil,
		light = nil,
		-- each piece on its own beat, so two fountains never ripple together
		nextPulse = now + math.random() * (if spec.pulse ~= nil then spec.pulse.every else 1),
		nextTwinkle = now,
	}
end

function Lawn.start()
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
			task.wait(Presets.lawn.step)
			step()
		end
	end)
end

return Lawn
