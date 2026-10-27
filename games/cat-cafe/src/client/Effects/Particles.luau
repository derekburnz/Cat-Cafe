--!strict
-- Particle emitters from Presets, pooled bursts, part confetti, the flat flash ring and the pop-up marks.
--
-- Roblox terms: a ParticleEmitter sprays flat sprites from its parent (a part or an Attachment). `Rate` is a
-- steady stream; `Emit(n)` fires n at once. Particles already in the air stay where they are when the emitter
-- moves, so one hidden emitter per kind can serve every burst in the world. An Attachment parented to
-- Workspace.Terrain sits at a world position, which is where the burst emitters live.

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Presets = require(script.Parent.Presets)

local Particles = {}

local DARK_WOOD = Color3.fromRGB(94, 70, 52) -- palette 2, the outline colour of the UI style

local rng = Random.new()

local function range(pair: { number }): NumberRange
	return NumberRange.new(pair[1], pair[2])
end

local function colours(list: { Color3 }): ColorSequence
	if #list == 1 then
		return ColorSequence.new(list[1])
	end
	local keys: { ColorSequenceKeypoint } = {}
	for i, colour in list do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#list - 1), colour))
	end
	return ColorSequence.new(keys)
end

-- A disabled emitter built from a preset; `tint` replaces its colours.
function Particles.make(preset: Presets.EmitterPreset, tint: Color3?): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = preset.texture
	emitter.Color = if tint ~= nil then ColorSequence.new(tint) else colours(preset.colors)
	emitter.Size = NumberSequence.new(preset.size[1], preset.size[2])
	emitter.Transparency = NumberSequence.new(preset.transparency[1], preset.transparency[2])
	emitter.Lifetime = range(preset.lifetime)
	emitter.Speed = range(preset.speed)
	emitter.SpreadAngle = Vector2.new(preset.spread, preset.spread)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Rate = preset.rate
	emitter.Acceleration = preset.acceleration or Vector3.zero
	emitter.Drag = preset.drag or 0
	local glow = preset.lightEmission
	emitter.LightEmission = glow or 0
	emitter.LightInfluence = if glow ~= nil then 0 else 1
	local spin = preset.rotSpeed
	if spin ~= nil then
		emitter.RotSpeed = range(spin)
		emitter.Rotation = NumberRange.new(0, 360)
	end
	emitter.Enabled = false
	return emitter
end

-- An Attachment at a world position, for a steady emitter that is not on a part.
function Particles.anchor(name: string, position: Vector3): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = position
	attachment.Parent = Workspace.Terrain
	return attachment
end

-- Switches a steady emitter on at its preset's rate times the budget's rateScale. Effects call it each time they
-- choose an emitter, so a new budget (the Low performance setting) reaches emitters made before it.
function Particles.switchOn(emitter: ParticleEmitter, presetName: string)
	local preset: Presets.EmitterPreset? = Presets.emitters[presetName]
	if preset ~= nil then
		emitter.Rate = preset.rate * Context.budget.rateScale
	end
	emitter.Enabled = true
end

-- A steady emitter on `parent`, switched on.
function Particles.attach(presetName: string, parent: Instance): ParticleEmitter?
	local preset: Presets.EmitterPreset? = Presets.emitters[presetName]
	if preset == nil then
		return nil
	end
	local emitter = Particles.make(preset)
	emitter.Name = presetName
	emitter.Parent = parent
	Particles.switchOn(emitter, presetName)
	return emitter
end

local pool: { [string]: ParticleEmitter } = {}

local function burstEmitter(presetName: string, tint: Color3?): ParticleEmitter?
	local key = if tint ~= nil then presetName .. "_" .. tint:ToHex() else presetName
	local existing: ParticleEmitter? = pool[key]
	if existing ~= nil then
		return existing
	end
	local preset: Presets.EmitterPreset? = Presets.emitters[presetName]
	if preset == nil then
		return nil
	end
	local emitter = Particles.make(preset, tint)
	emitter.Name = key
	emitter.Parent = Particles.anchor("Burst_" .. key, Vector3.zero)
	pool[key] = emitter
	return emitter
end

-- Fires `count` particles of a preset at a world position, scaled by the device budget.
function Particles.burst(presetName: string, at: Vector3, count: number, tint: Color3?)
	local emitter = burstEmitter(presetName, tint)
	if emitter == nil then
		return
	end
	local holder = emitter.Parent
	if holder ~= nil and holder:IsA("Attachment") then
		local attachment = holder :: Attachment
		attachment.Position = at
	end
	local budget = Context.budget
	emitter:Emit(math.clamp(math.floor(count * budget.burstScale + 0.5), 1, budget.maxBurst))
end

-- Confetti --------------------------------------------------------------------------------------------------

type Piece = {
	part: BasePart,
	origin: Vector3,
	velocity: Vector3,
	spin: Vector3,
	phase: number,
	born: number,
}

local pieces: { Piece } = {}
local spare: { BasePart } = {}
local confettiLoop: RBXScriptConnection? = nil
local moving: { BasePart } = {} -- reused every frame
local frames: { CFrame } = {}

local function stepConfetti()
	local now = os.clock()
	local c = Presets.confetti
	table.clear(moving)
	table.clear(frames)
	local i = 1
	while i <= #pieces do
		local piece = pieces[i]
		local age = now - piece.born
		if age >= c.seconds then
			piece.part.Parent = nil
			table.insert(spare, piece.part)
			pieces[i] = pieces[#pieces]
			pieces[#pieces] = nil
		else
			local position = piece.origin + Logic.confettiOffset(piece.velocity, age, piece.phase)
			local spin = piece.spin * age
			table.insert(moving, piece.part)
			table.insert(frames, CFrame.new(position) * CFrame.Angles(spin.X, spin.Y, spin.Z))
			piece.part.Transparency = math.clamp((age - (c.seconds - 0.4)) / 0.4, 0, 1)
			i += 1
		end
	end
	if #moving > 0 then
		Workspace:BulkMoveTo(moving, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
	if #pieces == 0 and confettiLoop ~= nil then
		confettiLoop:Disconnect()
		confettiLoop = nil
	end
end

-- Paper confetti from a point: small client-only parts on one shared loop, never more than maxLive at once.
function Particles.confetti(at: Vector3, count: number, palette: { Color3 }?)
	local c = Presets.confetti
	local colours = palette or Presets.confettiColors
	local wanted = if Context.reducedMotion() then math.ceil(count * 0.4) else count
	local n = math.min(wanted, c.maxLive - #pieces)
	local now = os.clock()
	for i = 1, n do
		local part = table.remove(spare)
		if part == nil then
			part = Context.effectPart("Confetti", c.size, colours[1])
		end
		local piece = part :: BasePart
		piece.Color = colours[(i - 1) % #colours + 1]
		piece.Transparency = 0
		piece.CFrame = CFrame.new(at)
		piece.Parent = Context.folder()
		local angle = rng:NextNumber(0, 2 * math.pi)
		local side = rng:NextNumber(c.sideSpeed[1], c.sideSpeed[2])
		table.insert(pieces, {
			part = piece,
			origin = at,
			velocity = Vector3.new(
				math.cos(angle) * side,
				rng:NextNumber(c.upSpeed[1], c.upSpeed[2]),
				math.sin(angle) * side
			),
			spin = Vector3.new(rng:NextNumber(-9, 9), rng:NextNumber(-6, 6), rng:NextNumber(-9, 9)),
			phase = rng:NextNumber(0, 2 * math.pi),
			born = now,
		})
	end
	if n > 0 and confettiLoop == nil then
		confettiLoop = RunService.Heartbeat:Connect(stepConfetti)
	end
end

-- Flash ring and marks ---------------------------------------------------------------------------------------

-- A flat disc that grows and fades under a big moment (Purrfect, a gate opening, a getaway), to `diameter` studs
-- over `seconds` (Presets.ring by default). One flash; skipped with Reduce Motion.
function Particles.ring(at: Vector3, colour: Color3, diameter: number?, seconds: number?)
	if Context.reducedMotion() then
		return
	end
	local r =
		{ diameter = diameter or Presets.ring.diameter, seconds = seconds or Presets.ring.seconds }
	local ring = Context.effectPart("Ring", Vector3.new(0.12, 1, 1), colour)
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.3
	ring.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = Context.folder()
	local info = TweenInfo.new(r.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService
		:Create(ring, info, { Size = Vector3.new(0.12, r.diameter, r.diameter), Transparency = 1 })
		:Play()
	Debris:AddItem(ring, r.seconds + 0.1)
end

-- A beam of light from `at` straight up: it shoots up to `height` studs over the first part of `seconds`, holds and
-- fades, narrowing as it goes (Presets.beam). One flash; skipped with Reduce Motion.
function Particles.beam(at: Vector3, colour: Color3, width: number, height: number, seconds: number)
	if Context.reducedMotion() then
		return
	end
	local b = Presets.beam
	-- A cylinder's length runs along its X axis, so it is turned to stand up.
	local upright = CFrame.Angles(0, 0, math.pi / 2)
	local beam = Context.effectPart("Beam", Vector3.new(0.1, width, width), colour)
	beam.Shape = Enum.PartType.Cylinder
	beam.Material = Enum.Material.Neon
	beam.Transparency = 0.35
	beam.CFrame = CFrame.new(at) * upright
	beam.Parent = Context.folder()
	local rise = TweenInfo.new(seconds * b.grow, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(beam, rise, {
		Size = Vector3.new(height, width, width),
		CFrame = CFrame.new(at + Vector3.new(0, height / 2, 0)) * upright,
	}):Play()
	local fade = TweenInfo.new(
		seconds * (1 - b.holdShare),
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In,
		0,
		false,
		seconds * b.holdShare
	)
	TweenService
		:Create(
			beam,
			fade,
			{ Transparency = 1, Size = Vector3.new(height, width * 0.6, width * 0.6) }
		)
		:Play()
	Debris:AddItem(beam, seconds + 0.1)
end

-- A word or symbol that pops up over a part, rises and fades: the "!" of a hiss.
function Particles.mark(adornee: BasePart, text: string, colour: Color3, seconds: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "EffectsMark"
	gui.Adornee = adornee
	gui.Size = UDim2.fromScale(0.3, 0.3) -- studs
	gui.StudsOffsetWorldSpace = Vector3.new(0, 1.4, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 80
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = colour
	label.TextStrokeColor3 = DARK_WOOD
	label.TextStrokeTransparency = 0
	label.Parent = gui
	gui.Parent = Context.folder()
	local pop = TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(gui, pop, { Size = UDim2.fromScale(1.4, 1.4) }):Play()
	local fade = TweenInfo.new(
		seconds * 0.5,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In,
		0,
		false,
		seconds * 0.5
	)
	TweenService:Create(gui, fade, { StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0) }):Play()
	TweenService:Create(label, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(gui, seconds + 0.1)
end

return Particles
