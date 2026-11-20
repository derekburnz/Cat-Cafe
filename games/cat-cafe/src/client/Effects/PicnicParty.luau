--!strict
-- The Picnic Party at the Park's Picnic Basket (#5572; Derek 2026-11-20 15:09 UTC: "rework the picnic basket into being
-- something cool and clean because its where a lot of people leave so it has to be something that hooks"). Behind the
-- switch `picnicParty`, read straight; off draws nothing and leaves today's basket exactly as it is. On this client
-- only, at its own `CampExtra` station with ExtraId "picnic" (Model-Agent's CatCafe_Camp_Park_PicnicStation):
-- - ready: the basket wobbles now and then, a soft gold glow, and a "PICNIC READY" sign over it sized in screen pixels
--   so it reads from the Park landing on a phone (Growth: only 23% of Park arrivals touch it); waiting: the sign reads
--   "Next picnic 12 m";
-- - the pop, as Picnic Time starts (the ring claim, the player's own step): the lid swings open, a checked blanket
--   rolls out beside the basket, three treats bounce onto it, confetti. About 1.5 s; the camera and controls are never
--   touched. Joining or streaming in while Picnic Time runs lays it all out at once;
-- - the blanket lies where shared/PicnicSeats puts it, so Gameplay's picnic strays (real server cats, still on its three
--   seats until caught) stand on it; nothing here seats a cat;
-- - the pack away as Picnic Time ends: the treats fade, the blanket rolls up, the lid shuts.
-- Reduce Motion: no wobble and no bounce, the basket stands open with the blanket out. Low performance: no Highlight.
--
-- State (Gameplay-Engineer's, server decides, attributes on the LocalPlayer): PicnicReady (bool), PicnicNextAt and
-- PicnicEndsAt (server unix seconds, read against Workspace:GetServerTimeNow; not set when Picnic Time goes to the bag,
-- so no pop then). Listening only:
-- no remotes. Model-Agent's blanket and treat models under ReplicatedStorage.Assets are used when they are there, with
-- simple stand-ins until then. Timelines and words in Effects/PicnicLogic, numbers in Presets.picnicParty.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PicnicSeats = require(Shared:WaitForChild("PicnicSeats"))

local Context = require(script.Parent.Context)
local Particles = require(script.Parent.Particles)
local PicnicLogic = require(script.Parent.PicnicLogic)
local Presets = require(script.Parent.Presets)

local PicnicParty = {}

local TAG = "CampExtra"

local started = false

type Lid = { model: Model, hinge: CFrame } -- the lid model, and its pivot shut (on its back edge, Model-Agent's #5580)

type Scene = {
	model: Model,
	base: CFrame, -- the station's own pivot, put back after each wobble
	frame: CFrame, -- the station's bounding box frame
	size: Vector3,
	lid: Lid?,
	glow: Highlight?,
	spot: Attachment, -- in the Terrain over the station: the sign and the light
	light: PointLight,
	sign: BillboardGui,
	words: TextLabel,
	blanket: { root: BasePart, model: Model?, rolled: Model?, near: CFrame, width: number }?,
	treats: { BasePart | Model },
	popAt: number?, -- os.clock the pop began
	packAt: number?, -- os.clock the pack away began
	signAt: number, -- os.clock the words were last set
}

local scene: Scene? = nil
local phaseWas: PicnicLogic.Phase = "off"
local lookedAt = -math.huge -- os.clock of the last look for the station while none is drawn
local tiltWas = 0
local warned = false
local LOOK_EVERY = 1 -- seconds between looks for the station

local function on(): boolean
	return ReplicatedStorage:GetAttribute("LiveFlag_" .. Presets.picnicParty.flag) == true
end

local function station(): Model?
	for _, instance in CollectionService:GetTagged(TAG) do
		if
			instance:IsA("Model")
			and instance:GetAttribute("ExtraId") == Presets.picnicParty.extraId
			and instance:IsDescendantOf(Workspace)
		then
			return instance :: Model
		end
	end
	return nil
end

local function number(name: string): number?
	local value = Players.LocalPlayer:GetAttribute(name)
	return if type(value) == "number" and value == value then value else nil
end

local function asset(name: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local found = if assets ~= nil then assets:FindFirstChild(name) else nil
	return if found ~= nil and found:IsA("Model") then found :: Model else nil
end

-- A copy with no scripts, every part anchored and out of the way of rays, touches and collisions.
local function inert(source: Model): Model
	local copy = source:Clone() :: Model
	for _, item in copy:GetDescendants() do
		if item:IsA("BaseScript") or item:IsA("ModuleScript") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			local part = item :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	return copy
end

-- The lid: Model-Agent's child model `<station>_Lid` (#5580), its pivot on its back edge, opening with a positive
-- turn about the pivot's X axis. Nil on a station without one (the stand-in has no lid to open).
local function findLid(model: Model): Lid?
	local found = model:FindFirstChild(model.Name .. Presets.picnicParty.lidSuffix)
	if found == nil or not found:IsA("Model") then
		return nil
	end
	local lid = found :: Model
	return { model = lid, hinge = lid:GetPivot() }
end

-- Turns the lid `degrees` open about its hinge.
local function lidDegrees(lid: Lid?, degrees: number)
	if lid == nil or lid.model.Parent == nil then
		return
	end
	lid.model:PivotTo(lid.hinge * CFrame.Angles(math.rad(degrees), 0, 0))
end

local function setLid(lid: Lid?, open: number)
	lidDegrees(lid, Presets.picnicParty.pop.lidOpen * open)
end

local function makeSign(spot: Attachment): (BillboardGui, TextLabel)
	local s = Presets.picnicParty.sign
	local gui = Instance.new("BillboardGui")
	gui.Name = "EffectsPicnicSign"
	gui.Adornee = spot
	gui.Size = UDim2.fromOffset(s.width, s.height)
	gui.LightInfluence = 0
	gui.MaxDistance = s.maxDistance
	gui.AlwaysOnTop = true -- Sync Nov 20: the Park arch lamp post covered "PICNIC READY" from the landing
	gui.ResetOnSpawn = false
	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.Size = UDim2.fromScale(1, 1)
	pill.BackgroundColor3 = s.gold
	pill.BorderSizePixel = 0
	pill.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = pill
	local edge = Instance.new("UIStroke")
	edge.Name = "Edge"
	edge.Color = s.ink
	edge.Thickness = 3
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = pill
	local words = Instance.new("TextLabel")
	words.Name = "Words"
	words.BackgroundTransparency = 1
	words.Size = UDim2.fromScale(0.88, 0.76)
	words.Position = UDim2.fromScale(0.5, 0.5)
	words.AnchorPoint = Vector2.new(0.5, 0.5)
	words.FontFace = Font.new(
		"rbxasset://fonts/families/FredokaOne.json",
		Enum.FontWeight.Bold,
		Enum.FontStyle.Normal
	)
	words.TextScaled = true
	words.TextColor3 = Color3.new(1, 1, 1)
	local stroke = Instance.new("UIStroke")
	stroke.Color = s.ink
	stroke.Thickness = 2
	stroke.Parent = words
	words.Parent = pill
	gui.Parent = Context.folder()
	return gui, words
end

local function drawSign(at: Scene, phase: PicnicLogic.Phase, now: number)
	local s = Presets.picnicParty.sign
	local text = PicnicLogic.sign(phase, number("PicnicNextAt"), now)
	at.sign.Enabled = text ~= nil
	if text == nil then
		return
	end
	at.words.Text = text :: string
	local ready = phase == "ready"
	at.sign.Size = if ready
		then UDim2.fromOffset(s.width, s.height)
		else UDim2.fromOffset(s.waitWidth, s.waitHeight)
	local pill = at.sign:FindFirstChild("Pill") :: Frame
	pill.BackgroundColor3 = if ready then s.gold else s.cream
	pill.BackgroundTransparency = if ready then 0 else s.faded
	at.words.TextColor3 = if ready then Color3.new(1, 1, 1) else s.ink
	local stroke = at.words:FindFirstChildOfClass("UIStroke")
	if stroke ~= nil then
		(stroke :: UIStroke).Enabled = ready
	end
end

local function build(model: Model): Scene
	local p = Presets.picnicParty
	local frame, size = model:GetBoundingBox()
	local spot = Instance.new("Attachment")
	spot.Name = "EffectsPicnicSpot"
	spot.WorldPosition = frame.Position + Vector3.new(0, size.Y / 2 + p.sign.lift, 0)
	spot.Parent = Workspace.Terrain
	local light = Instance.new("PointLight")
	light.Color = p.glow.fill
	light.Range = p.glow.range
	light.Brightness = 0
	light.Shadows = false
	light.Parent = spot
	local sign, words = makeSign(spot)
	return {
		model = model,
		base = model:GetPivot(),
		frame = frame,
		size = size,
		lid = findLid(model),
		glow = nil,
		spot = spot,
		light = light,
		sign = sign,
		words = words,
		blanket = nil,
		treats = {},
		popAt = nil,
		packAt = nil,
		signAt = -math.huge,
	}
end

local function setGlow(at: Scene, wanted: boolean)
	local g = Presets.picnicParty.glow
	local want = wanted and not Context.lowPerformance
	if want and at.glow == nil then
		local made = Instance.new("Highlight")
		made.Name = "EffectsPicnicGlow"
		made.Adornee = at.model
		made.FillColor = g.fill
		made.OutlineColor = g.fill
		made.FillTransparency = g.fillTransparency
		made.OutlineTransparency = g.outlineTransparency
		made.DepthMode = Enum.HighlightDepthMode.Occluded
		made.Parent = Context.folder()
		at.glow = made
	elseif not want and (at.glow :: Highlight?) ~= nil then
		(at.glow :: Highlight):Destroy()
		at.glow = nil
	end
end

-- The blanket's near edge on the ground beside the basket, facing out along the station's right.
local function blanketNear(at: Scene): CFrame
	return PicnicSeats.near(at.base)
end

-- The blanket: Model-Agent's model if it is in, else a flat part with checks on top.
local function makeBlanket(at: Scene)
	local b = Presets.picnicParty.blanket
	local near = blanketNear(at)
	local source = asset(b.model)
	if source ~= nil then
		local copy = inert(source)
		local _, size = copy:GetBoundingBox()
		copy.Parent = Context.folder()
		local root = copy.PrimaryPart or copy:FindFirstChildWhichIsA("BasePart", true)
		if root ~= nil and root:IsA("BasePart") then
			local rolledSource = asset(b.rolled)
			local rolled = if rolledSource ~= nil then inert(rolledSource) else nil
			if rolled ~= nil then
				rolled.Parent = Context.folder()
			end
			at.blanket = {
				root = root :: BasePart,
				model = copy,
				rolled = rolled,
				near = near,
				width = size.Z,
			}
			return
		end
		copy:Destroy()
	end
	local part = Context.effectPart("PicnicBlanket", b.size, b.white)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.CanvasSize = Vector2.new(b.squares * 20, b.squares * 20)
	gui.LightInfluence = 1
	gui.Parent = part
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromScale(1 / b.squares, 1 / b.squares)
	grid.CellPadding = UDim2.new()
	grid.Parent = gui
	for i = 0, b.squares * b.squares - 1 do
		local cell = Instance.new("Frame")
		cell.BorderSizePixel = 0
		local row, col = i // b.squares, i % b.squares
		cell.BackgroundColor3 = if (row + col) % 2 == 0 then b.red else b.white
		cell.Parent = gui
	end
	part.Parent = Context.folder()
	at.blanket =
		{ root = part :: BasePart, model = nil, rolled = nil, near = near, width = b.size.Z }
end

local function fade(item: Instance, share: number)
	if item:IsA("BasePart") then
		(item :: BasePart).LocalTransparencyModifier = share
	end
	for _, d in item:GetDescendants() do
		if d:IsA("BasePart") then
			(d :: BasePart).LocalTransparencyModifier = share
		elseif d:IsA("SurfaceGui") then
			(d :: SurfaceGui).Enabled = share < 0.5
		end
	end
end

-- Lays the blanket out `k` of the way (0 rolled, 1 flat). Model-Agent's pair: the rolled blanket rolls from the near
-- edge to the far one, turning as it goes, while the flat one comes in behind it (a model cannot be squashed on one
-- axis). The stand-in stretches from its near edge.
local function setBlanket(at: Scene, k: number)
	local blanket = at.blanket
	if blanket == nil then
		return
	end
	local b = Presets.picnicParty.blanket
	local w = blanket.width
	local out = math.max(0.02, k)
	local centre = blanket.near * CFrame.new(0, b.size.Y / 2, -w * out / 2)
	local model = blanket.model
	if model ~= nil then
		model:PivotTo(blanket.near * CFrame.new(0, 0, -w / 2))
		fade(model, 1 - k)
		local rolled = blanket.rolled
		if rolled ~= nil then
			local turn = -(w * k) / b.rollRadius -- radians a roll of that radius turns over that ground
			local axis = blanket.near * CFrame.new(0, b.rollRadius, -w * k)
			rolled:PivotTo(axis * CFrame.Angles(turn, 0, 0) * CFrame.new(0, -b.rollRadius, 0))
			fade(rolled, if k >= 1 then 1 else 0)
		end
	else
		blanket.root.Size = Vector3.new(b.size.X, b.size.Y, w * out)
		blanket.root.CFrame = centre
	end
end

-- A spot on the flat blanket: `at` in fractions of its sides (-0.5 to 0.5), `up` studs over it.
local function onBlanket(at: Scene, spot: Vector2, up: number): CFrame
	local blanket = at.blanket
	local near = if blanket ~= nil then blanket.near else blanketNear(at)
	local w = if blanket ~= nil then blanket.width else Presets.picnicParty.blanket.size.Z
	local side = Presets.picnicParty.blanket.size.X
	return near
		* CFrame.new(spot.X * side, Presets.picnicParty.blanket.size.Y + up, -w / 2 + spot.Y * w)
end

local function makeTreats(at: Scene)
	local p = Presets.picnicParty
	for i, treat in p.treats do
		local source = asset(treat.model)
		if source ~= nil then
			local copy = inert(source)
			fade(copy, 1) -- hidden until its flight starts, not shown where the asset was saved
			copy.Parent = Context.folder()
			at.treats[i] = copy
		else
			local part = Context.effectPart("PicnicTreat", p.treatSize, treat.colour)
			part.Shape = if i == 2 then Enum.PartType.Ball else Enum.PartType.Block
			part.Transparency = 1
			part.Parent = Context.folder()
			at.treats[i] = part
		end
	end
end

local function place(item: BasePart | Model, frame: CFrame)
	if item:IsA("Model") then
		(item :: Model):PivotTo(frame)
	else
		(item :: BasePart).CFrame = frame
	end
end

local function drawTreats(at: Scene, flights: { number? })
	local p = Presets.picnicParty
	local from = at.frame.Position + Vector3.new(0, at.size.Y / 2, 0)
	for i, item in at.treats do
		local k = flights[i]
		if item:IsA("BasePart") then
			(item :: BasePart).Transparency = if k == nil then 1 else 0
		elseif (k ~= nil) ~= (item:GetAttribute("Shown") == true) then
			fade(item, if k == nil then 1 else 0)
			item:SetAttribute("Shown", k ~= nil)
		end
		if k ~= nil then
			local land = onBlanket(at, p.treats[i].at, p.treatSize.Y / 2)
			local pos = from:Lerp(land.Position, k)
				+ Vector3.new(0, PicnicLogic.arc(k, p.pop.treatHeight), 0)
			place(item, CFrame.new(pos) * land.Rotation)
		end
	end
end

local function clearParty(at: Scene)
	for _, item in at.treats do
		item:Destroy()
	end
	at.treats = {}
	local blanket = at.blanket
	if blanket ~= nil then
		if blanket.model ~= nil then
			(blanket.model :: Model):Destroy()
			if blanket.rolled ~= nil then
				(blanket.rolled :: Model):Destroy()
			end
		else
			blanket.root:Destroy()
		end
	end
	at.blanket = nil
	setLid(at.lid, 0)
	at.popAt, at.packAt = nil, nil
end

local function forget()
	local at = scene
	if at == nil then
		return
	end
	scene = nil
	clearParty(at)
	setGlow(at, false)
	if at.model.Parent ~= nil then
		at.model:PivotTo(at.base)
	end
	at.sign:Destroy()
	at.spot:Destroy()
end

-- Begins the party's look: animated when it starts in front of the player, laid out when it was already running.
local function openParty(at: Scene, live: boolean)
	makeBlanket(at)
	makeTreats(at)
	at.popAt = if live and not Context.reducedMotion() then os.clock() else -math.huge
	if live then
		local p = Presets.picnicParty.pop
		task.delay(p.confettiAt, function()
			if scene == at and at.blanket ~= nil then
				local centre = onBlanket(at, Vector2.new(0, 0), 1).Position
				Particles.confetti(
					centre,
					if Context.lowPerformance then p.confetti // 2 else p.confetti
				)
			end
		end)
	end
end

local function step()
	if not on() then
		if scene ~= nil then
			forget()
		end
		phaseWas = "off"
		return
	end
	local at = scene
	if at ~= nil and (at.model.Parent == nil or not at.model:IsDescendantOf(Workspace)) then
		forget() -- streamed out or rebuilt: found again below
		at = nil
	end
	if at == nil then
		if os.clock() - lookedAt < LOOK_EVERY then
			return
		end
		lookedAt = os.clock()
		local model = station()
		if model == nil then
			phaseWas = "off"
			return
		end
		at = build(model :: Model)
		scene = at
		tiltWas = 0
	end
	local current = at :: Scene
	local now = Workspace:GetServerTimeNow()
	local ready = Players.LocalPlayer:GetAttribute("PicnicReady") == true
	local phase: PicnicLogic.Phase =
		PicnicLogic.phase(true, ready, number("PicnicEndsAt"), now) :: any
	local was = phaseWas
	phaseWas = phase
	local clock = os.clock()
	local p = Presets.picnicParty
	local still = Context.reducedMotion()

	-- the wobble, glow and light while a picnic waits
	setGlow(current, phase == "ready")
	local tilt = if phase == "ready" and not still
		then PicnicLogic.wobble(
			clock,
			p.wobble.every,
			p.wobble.seconds,
			p.wobble.degrees,
			p.wobble.wiggles
		)
		else 0
	if tilt ~= tiltWas and current.blanket == nil then
		tiltWas = tilt
		if current.lid ~= nil then
			-- Review-QA: the lid rattles open a little (its 11 parts), not the whole 233 part station
			lidDegrees(current.lid, math.abs(tilt) * p.wobble.lidShare)
		else
			current.model:PivotTo(current.base * CFrame.Angles(0, 0, math.rad(tilt)))
		end
	end
	local breath = 0.75 + 0.25 * math.sin(clock * 2 * math.pi / p.glow.pulse)
	current.light.Brightness = if phase == "ready"
		then p.glow.light * (if still then 1 else breath)
		else 0
	local bob = if still then 0 else math.sin(clock * 2 * math.pi / p.sign.bobSeconds) * p.sign.bob
	current.spot.WorldPosition = current.frame.Position
		+ Vector3.new(0, current.size.Y / 2 + p.sign.lift + bob, 0)
	if phase ~= was or clock - current.signAt >= 1 then
		current.signAt = clock
		drawSign(current, phase, now)
	end
	if phase == "ready" then
		-- the sign swells with each wobble so the rattle reads even with the basket behind the player's head
		local swell = 1 + p.sign.swell * math.min(1, math.abs(tilt) / p.wobble.degrees)
		current.sign.Size = UDim2.fromOffset(p.sign.width * swell, p.sign.height * swell)
	end

	-- the party: pop, pack away
	if phase == "party" and current.blanket == nil then
		openParty(current, was == "ready" or was == "waiting")
	elseif phase ~= "party" and current.blanket ~= nil and current.packAt == nil then
		current.packAt = if still then -math.huge else clock
	end
	if current.blanket == nil then
		return
	end
	local packAt = current.packAt
	if packAt ~= nil then
		local t = clock - packAt
		if t >= p.pack.seconds then
			clearParty(current)
			return
		end
		local gone, out, lid = PicnicLogic.pack(t)
		setBlanket(current, out)
		setLid(current.lid, lid)
		for _, item in current.treats do
			fade(item, gone)
		end
		return
	end
	local lid, roll, flights = PicnicLogic.pop(clock - (current.popAt or -math.huge), false)
	setLid(current.lid, lid)
	setBlanket(current, PicnicLogic.easeOut(roll))
	drawTreats(current, flights)
end

function PicnicParty.start()
	if started then
		return
	end
	started = true
	RunService.Heartbeat:Connect(function()
		local ok, err = pcall(step :: any)
		if not ok then
			if not warned then
				warned = true
				warn("[Effects] PicnicParty: " .. tostring(err))
			end
			pcall(forget)
		end
	end)
end

return PicnicParty
