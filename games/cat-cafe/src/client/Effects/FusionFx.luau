--!strict
-- The Cat Fusion Observatory's effects (#4104; fusion-observatory.md section 3: "On start: five portraits fly into
-- the centre and swirl. On collect: a burst in the coat's colour. The flash limit is one a second at most, with
-- Reduce Motion respected."). Two halves.
--
-- In the window (the UI builds and owns its tiles; this only draws over them):
--   FusionFx.swirl(tiles, centre, coat, onDone?)  -- the five picked tiles, the object they meet at, "gold" or "rainbow"
--   FusionFx.burst(target, coat)                  -- round the new cat's picture on Collect
--   FusionFx.onBeat(fn(beat, coat))               -- Audio: "start", "meet" and "collect"
-- The swirl flies a copy of each tile (a plain disc in Low performance) in a closing spiral to the centre, each
-- starting a little after the last and shrinking as it goes, then one ring and a few sparkles in the coat's colour as
-- they meet, and calls `onDone` then. The burst is sparkles round the picture and rings after it: one colour and two
-- rings for gold, the six hues and three rings, slower, for rainbow. Rings come `ringGap` apart (never under a
-- second for two bright ones in a row: they are thin outlines, not screen flashes).
-- Reduce Motion: nothing flies and no ring grows; `onDone` runs at once and half the sparkles show.
--
-- At the dome (the `CampExtra`-tagged model whose name ends `_FusionObservatory`):
--   FusionFx.set(coat?, ready?)  -- your own fusion: "gold", "rainbow" or nil for a free dome; ready once it is done
--   FusionFx.collected(coat)     -- you collected: sparkles and a ring at the dome
-- While a fusion runs the dome's `_Glow` parts (the slit) take the coat's colour, the rainbow one drifting through
-- the hues, and five small paw lights circle the dome slowly; once ready they circle a little faster and the slit
-- breathes. Everyone else sees only the glow, from the model's `FusionCoat` attribute if the server sets it. The
-- lights hold still with Reduce Motion and are off in Low performance. Listening only: nothing here fires a remote
-- or changes game state. Numbers in Presets.fusion.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)
local ScreenFx = require(script.Parent.ScreenFx)

local FusionFx = {}

local TAG = "CampExtra" -- shared/CampExtras.TAG
local GUI_NAME = "FusionFx"

-- Audio listens here: `fn(beat, coat)` with beat "start" as the tiles leave, "meet" as they become one and "collect"
-- on the Collect burst. Flat sounds, the window's.
local listeners: { (string, string) -> () } = {}
function FusionFx.onBeat(fn: (string, string) -> ())
	table.insert(listeners, fn)
end

local function beat(name: string, coat: string)
	for _, fn in listeners do
		task.spawn(fn, name, coat)
	end
end

-- Pure: the colour of `coat` at `t` seconds: gold, or the rainbow hues drifting round once every `huePeriod`.
function FusionFx.coatColour(coat: string?, t: number): Color3
	local p = Presets.fusion
	if coat ~= "rainbow" then
		return p.gold
	end
	local hues = Presets.rainbow.hues
	local at = (t / p.huePeriod) % 1 * #hues
	local i = math.floor(at)
	local a = hues[i % #hues + 1]
	local b = hues[(i + 1) % #hues + 1]
	return a:Lerp(b, at - i)
end

-- Pure: tile `i`'s place in the swirl `t` seconds in: `out` is how much of its starting offset from the centre is
-- left (1 at its own place, 0 at the centre), `turn` the radians that offset has turned by, `scale` its size. A tile
-- waits `stagger` seconds per place in line before it leaves.
function FusionFx.swirlAt(i: number, t: number): (number, number, number)
	local p = Presets.fusion.swirl
	local k = math.clamp((t - (math.max(i, 1) - 1) * p.stagger) / p.seconds, 0, 1)
	local eased = Logic.easeInOut(k)
	return 1 - eased, p.turns * 2 * math.pi * eased, 1 + (p.land - 1) * eased
end

-- Pure: the whole swirl's seconds for `count` tiles.
function FusionFx.swirlSeconds(count: number): number
	local p = Presets.fusion.swirl
	return p.seconds + (math.max(count, 1) - 1) * p.stagger
end

-- Pure: paw light `i` of `count` round the dome `t` seconds in: its offset from the dome's middle, on a level circle
-- of `radius`, one lap every `seconds`.
function FusionFx.pawAt(
	i: number,
	count: number,
	t: number,
	radius: number,
	seconds: number
): Vector3
	local angle = 2 * math.pi * ((i - 1) / math.max(count, 1) + t / seconds)
	return Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

-- Pure: how bright the slit is `t` seconds in, between `dip` and 1: steady while a fusion runs, breathing once
-- every `breathSeconds` when it is ready.
function FusionFx.slitGlow(ready: boolean, t: number): number
	local p = Presets.fusion.dome
	if not ready then
		return 1
	end
	return 1 - p.breathDip * (0.5 - 0.5 * math.cos(2 * math.pi * t / p.breathSeconds))
end

local function ghostOf(tile: GuiObject, gui: ScreenGui, colour: Color3): GuiObject
	local size = tile.AbsoluteSize
	local made: GuiObject
	if Context.lowPerformance then
		local disc = Instance.new("Frame")
		disc.BackgroundColor3 = colour
		disc.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = disc
		made = disc
	else
		made = tile:Clone() :: GuiObject
		for _, descendant in made:GetDescendants() do
			-- a copy must never run or lay itself out as the tile did
			if descendant:IsA("LuaSourceContainer") or descendant:IsA("UISizeConstraint") then
				descendant:Destroy()
			end
		end
	end
	made.Name = "FusionGhost"
	made.AnchorPoint = Vector2.new(0.5, 0.5)
	made.Size = UDim2.fromOffset(size.X, size.Y)
	made.LayoutOrder = 0
	made.Visible = true
	made.Parent = gui
	return made
end

local function meet(gui: ScreenGui, at: Vector2, across: number, coat: string, still: boolean)
	local p = Presets.fusion.swirl
	local colour = FusionFx.coatColour(coat, 0)
	local count = if still or Context.lowPerformance then math.ceil(p.sparkles / 2) else p.sparkles
	local spots = table.create(count, at)
	ScreenFx.sparkle(gui, spots, colour, {
		size = p.sparkleSize,
		seconds = p.sparkleSeconds,
		reach = across * p.reach,
		stagger = p.sparkleStagger,
	})
	if not still then
		ScreenFx.ring(gui, at, across * p.ringFrom, across * p.ringTo, colour, p.ringSeconds)
	end
end

-- The five picked `tiles` fly into `centre` and swirl together; `onDone` runs as they meet (at once with Reduce
-- Motion, or when nothing is on screen).
function FusionFx.swirl(tiles: { GuiObject }, centre: GuiObject, coat: string, onDone: (() -> ())?)
	beat("start", coat)
	local function done()
		beat("meet", coat)
		if onDone ~= nil then
			task.spawn(onDone)
		end
	end
	local gui = ScreenFx.gui(GUI_NAME, Presets.fusion.displayOrder)
	if gui == nil or not ScreenFx.shown(centre) then
		done()
		return
	end
	local middle = ScreenFx.centre(gui, centre)
	local across = math.max(centre.AbsoluteSize.X, centre.AbsoluteSize.Y)
	if Context.reducedMotion() then
		meet(gui, middle, across, coat, true)
		done()
		return
	end
	local colour = FusionFx.coatColour(coat, 0)
	local ghosts: { GuiObject } = {}
	local froms: { Vector2 } = {}
	local sizes: { Vector2 } = {}
	for _, tile in tiles do
		if #ghosts >= Presets.fusion.swirl.most then
			break
		end
		if ScreenFx.shown(tile) then
			local from = ScreenFx.centre(gui, tile)
			local ghost = ghostOf(tile, gui, colour)
			ghost.Position = UDim2.fromOffset(from.X, from.Y)
			table.insert(ghosts, ghost)
			table.insert(froms, from)
			table.insert(sizes, tile.AbsoluteSize)
		end
	end
	if #ghosts == 0 then
		meet(gui, middle, across, coat, false)
		done()
		return
	end
	local began = os.clock()
	local whole = FusionFx.swirlSeconds(#ghosts)
	local loop: RBXScriptConnection
	loop = RunService.RenderStepped:Connect(function()
		local t = os.clock() - began
		if t >= whole or gui.Parent == nil then
			loop:Disconnect()
			for _, ghost in ghosts do
				ghost:Destroy()
			end
			if gui.Parent ~= nil then
				meet(gui, middle, across, coat, false)
			end
			done()
			return
		end
		for i, ghost in ghosts do
			local out, turn, scale = FusionFx.swirlAt(i, t)
			local offset = (froms[i] - middle) * out
			local cos, sin = math.cos(turn), math.sin(turn)
			local at = middle
				+ Vector2.new(offset.X * cos - offset.Y * sin, offset.X * sin + offset.Y * cos)
			ghost.Position = UDim2.fromOffset(at.X, at.Y)
			ghost.Size = UDim2.fromOffset(sizes[i].X * scale, sizes[i].Y * scale)
		end
	end)
end

-- The points round `corner`..`corner + size`'s edge, `count` of them, evenly spaced from the top left.
local function edge(corner: Vector2, size: Vector2, count: number): { Vector2 }
	local spots: { Vector2 } = {}
	local around = 2 * (size.X + size.Y)
	for i = 1, count do
		local d = (i - 0.5) / count * around
		local spot: Vector2
		if d < size.X then
			spot = Vector2.new(d, 0)
		elseif d < size.X + size.Y then
			spot = Vector2.new(size.X, d - size.X)
		elseif d < 2 * size.X + size.Y then
			spot = Vector2.new(size.X - (d - size.X - size.Y), size.Y)
		else
			spot = Vector2.new(0, size.Y - (d - 2 * size.X - size.Y))
		end
		table.insert(spots, corner + spot)
	end
	return spots
end

-- The Collect burst round `target` (the new cat's picture) in the coat's colour.
function FusionFx.burst(target: GuiObject, coat: string)
	local kinds: { [string]: Presets.FusionBurst } = Presets.fusion.burst.kinds
	local k = kinds[coat] or kinds.gold
	local s = Presets.fusion.burst
	beat("collect", coat)
	if not ScreenFx.shown(target) then
		return
	end
	local gui = ScreenFx.gui(GUI_NAME, Presets.fusion.displayOrder)
	if gui == nil then
		return
	end
	local still = Context.reducedMotion()
	local count = k.sparkles
	if still or Context.lowPerformance then
		count = math.ceil(count / 2)
	end
	local size = target.AbsoluteSize
	local corner = ScreenFx.toGui(gui, target.AbsolutePosition)
	local reach = math.clamp(math.min(size.X, size.Y) * s.reach, s.reachMin, s.reachMax)
	local spots = edge(corner, size, count)
	-- one colour for gold; the rainbow shares its spots out between the hues, each hue a beat after the last
	local colours: { Color3 } = if coat == "rainbow"
		then Presets.rainbow.hues
		else { Presets.fusion.gold }
	for c, colour in colours do
		local mine: { Vector2 } = {}
		for i = c, #spots, #colours do
			table.insert(mine, spots[i])
		end
		task.delay((c - 1) * k.hueGap, function()
			if gui.Parent ~= nil then
				ScreenFx.sparkle(gui, mine, colour, {
					size = s.size,
					seconds = k.seconds,
					reach = reach,
					stagger = s.stagger,
				})
			end
		end)
	end
	if still then
		return
	end
	local middle = ScreenFx.centre(gui, target)
	local across = math.max(size.X, size.Y)
	for ring = 1, k.rings do
		task.delay((ring - 1) * s.ringGap, function()
			if gui.Parent ~= nil then
				local colour = colours[(ring - 1) * 2 % #colours + 1]
				ScreenFx.ring(
					gui,
					middle,
					across * s.ringFrom,
					across * s.ringTo,
					colour,
					k.ringSeconds
				)
			end
		end)
	end
end

-- The dome ------------------------------------------------------------------------------------------------------

type Glow = { part: BasePart, color: Color3, material: Enum.Material }

local started = false
local myCoat: string? = nil
local myReady = false
local since = os.clock()
local dome: Model? = nil
local glows: { Glow } = {}
local paws: { Part } = {}
local lit: string? = nil -- the coat the slit shows now

local function findDome(): Model?
	local suffix = Presets.fusion.dome.suffix
	for _, instance in CollectionService:GetTagged(TAG) do
		if
			instance:IsA("Model")
			and instance.Name:sub(-#suffix) == suffix
			and instance:IsDescendantOf(Workspace)
		then
			return instance :: Model
		end
	end
	return nil
end

local function dropPaws()
	for _, paw in paws do
		paw:Destroy()
	end
	table.clear(paws)
end

local function restoreGlows()
	for _, glow in glows do
		if glow.part.Parent ~= nil then
			glow.part.Color = glow.color
			glow.part.Material = glow.material
		end
	end
	lit = nil
end

local function readGlows(model: Model)
	table.clear(glows)
	local suffix = Presets.fusion.dome.glow
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name:sub(-#suffix) == suffix then
			local part = descendant :: BasePart
			table.insert(glows, { part = part, color = part.Color, material = part.Material })
		end
	end
end

local function coatOf(model: Model): string?
	if myCoat ~= nil then
		return myCoat
	end
	local shown = model:GetAttribute("FusionCoat")
	if shown == "gold" then
		return "gold"
	elseif shown == "rainbow" then
		return "rainbow"
	end
	return nil
end

local function stepDome(now: number)
	local model = dome
	if model == nil or model.Parent == nil then
		if model ~= nil then
			dropPaws()
			table.clear(glows)
			lit = nil
		end
		dome = nil
		return
	end
	local p = Presets.fusion.dome
	local at = model:GetPivot().Position
	local coat = coatOf(model)
	if coat == nil or Context.distance(at) > Context.budget.ambientRadius then
		if lit ~= nil then
			restoreGlows()
		end
		dropPaws()
		return
	end
	if #glows == 0 then
		readGlows(model)
	end
	local t = now - since
	local colour = FusionFx.coatColour(coat, t)
	local bright = FusionFx.slitGlow(myReady and myCoat ~= nil, t)
	local shown = colour:Lerp(Color3.new(0, 0, 0), (1 - bright) * 0.5)
	for _, glow in glows do
		if glow.part.Parent ~= nil then
			glow.part.Material = Enum.Material.Neon
			glow.part.Color = shown
		end
	end
	lit = coat
	-- the paw lights are yours alone
	if myCoat == nil or Context.lowPerformance then
		dropPaws()
		return
	end
	local _, size = model:GetBoundingBox()
	local radius = math.max(size.X, size.Z) / 2 * p.pawRadius
	local height = size.Y * p.pawHeight
	local middle = model:GetBoundingBox().Position - Vector3.new(0, size.Y / 2, 0)
	if #paws == 0 then
		for i = 1, p.paws do
			local paw = Context.effectPart("FusionPaw", Vector3.one * p.pawSize, colour)
			paw.Shape = Enum.PartType.Ball
			paw.Material = Enum.Material.Neon
			paw.Parent = Context.folder()
			paws[i] = paw
		end
	end
	local lap = if myReady then p.lapReady else p.lap
	local turn = if Context.reducedMotion() then 0 else t
	for i, paw in paws do
		local offset = FusionFx.pawAt(i, #paws, turn, radius, lap)
		paw.Position = middle + Vector3.new(0, height, 0) + offset
		paw.Color = if coat == "rainbow"
			then FusionFx.coatColour(coat, t + (i - 1) * Presets.fusion.huePeriod / #paws)
			else colour
	end
end

-- Your own fusion: `coat` "gold" or "rainbow" while one runs or waits in the dome (nil for a free dome), `ready`
-- once it is done. Call it on every PlayerState.fusion.
function FusionFx.set(coat: string?, ready: boolean?)
	local wanted: string? = if coat == "gold" or coat == "rainbow" then coat else nil
	if wanted ~= myCoat or (ready == true) ~= myReady then
		since = os.clock()
	end
	myCoat = wanted
	myReady = ready == true
end

-- You collected a `coat` cat: sparkles and a ring at the dome, if you stand near it.
function FusionFx.collected(coat: string)
	local model = dome or findDome()
	if model == nil then
		return
	end
	local p = Presets.fusion.dome
	local at, size = model:GetBoundingBox()
	local top = at.Position + Vector3.new(0, size.Y / 2, 0)
	if Context.distance(top) > Context.budget.animRadius then
		return
	end
	local colour = FusionFx.coatColour(coat, 0)
	Particles.burst("catchSparkle", top, p.collect, colour)
	if coat == "rainbow" then
		Particles.confetti(
			top,
			math.ceil(Context.budget.confetti * p.collectConfetti),
			Presets.rainbow.hues
		)
	end
	if not Context.reducedMotion() then
		Particles.ring(
			at.Position - Vector3.new(0, size.Y / 2, 0),
			colour,
			math.max(size.X, size.Z) * p.collectRing
		)
	end
end

-- Studio only: Workspace attribute `FusionFxTest` = "gold" or "rainbow" shows five stand-in tiles and one centre
-- tile, swirls them, bursts the centre a moment later and lights the dome (if it is built) for `seconds`.
local function studioTest(coat: string)
	local gui = ScreenFx.gui(GUI_NAME, Presets.fusion.displayOrder)
	if gui == nil then
		return
	end
	local holder = Instance.new("Frame")
	holder.Name = "FusionFxTest"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui
	local function tile(x: number, y: number, colour: Color3): Frame
		local made = Instance.new("Frame")
		made.AnchorPoint = Vector2.new(0.5, 0.5)
		made.Position = UDim2.fromScale(x, y)
		made.Size = UDim2.fromOffset(72, 72)
		made.BackgroundColor3 = colour
		made.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.2, 0)
		corner.Parent = made
		made.Parent = holder
		return made
	end
	local tiles: { GuiObject } = {}
	for i = 1, 5 do
		table.insert(tiles, tile(0.2 + i * 0.1, 0.3, Presets.palette.offwhite))
	end
	local centre = tile(0.5, 0.6, FusionFx.coatColour(coat, 0))
	centre.Visible = false
	FusionFx.set(coat, false)
	task.wait(0.2) -- a frame or two for the tiles to take their places
	FusionFx.swirl(tiles, centre, coat, function()
		for _, made in tiles do
			made.Visible = false
		end
		centre.Visible = true
		task.wait(1.5)
		FusionFx.set(coat, true)
		FusionFx.burst(centre, coat)
		FusionFx.collected(coat)
		task.wait(6)
		holder:Destroy()
		FusionFx.set(nil, false)
	end)
end

function FusionFx.start()
	if started then
		return
	end
	started = true
	if RunService:IsStudio() then
		Workspace:GetAttributeChangedSignal("FusionFxTest"):Connect(function()
			local coat = Workspace:GetAttribute("FusionFxTest")
			if coat == "gold" or coat == "rainbow" then
				task.spawn(studioTest, coat)
			end
		end)
	end
	local look = 0
	local wait = 0
	RunService.Heartbeat:Connect(function(dt: number)
		look -= dt
		if dome == nil and look <= 0 then
			look = Presets.fusion.dome.lookSeconds
			dome = findDome()
		end
		wait -= dt
		if wait <= 0 and dome ~= nil then
			wait = Presets.fusion.dome.rate
			stepDome(os.clock())
		end
	end)
end

return FusionFx
