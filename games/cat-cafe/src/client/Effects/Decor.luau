--!strict
-- Mythical cafe styles and decor (F53, golden-fish.md section 4): each of the six Mythical crate pieces has its own
-- bit of magic while it is in use. Midnight Sky's stars twinkle on the cafe's inside walls and a moon drifts along
-- the back wall; Aurora Sky's northern lights sway there instead; Glimmer Canal's floor shimmers with light moving
-- under the glass and a glint now and then; Rainbow Shimmer runs a slow rainbow over the cafe front and Gold Leaf
-- sends a sheen and glints over it, both seen from the street; the Blossom Tree drops petals. Which piece gets what
-- is Presets.decor by decor id.
--
-- Sources: each Plot's Wallpaper, Floor and Paint attributes (the style in use, which StyleController paints on the
-- plot's parts with the same tag) and placed pieces carrying DecorId. Walls, floor and front are measured from those
-- tagged parts. Every piece in use shows its still look (the stars, the moon, the light bands, the rainbow tint) as a
-- picture on a see-through sheet over the wall, floor or front. The nearest budget.decorEffects pieces within
-- ambientRadius also move (twinkles, drifts, scrolls, glints, petals) and take that many of the steady emitters
-- from Ambient. Low performance moves none; Reduce Motion keeps the glints and petals and stills the rest. Only this
-- client's copy changes.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Crates = require(ReplicatedStorage.Shared.Crates)

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local Decor = {}

-- "still": the picture only; "calm" (Reduce Motion): plus glints and petals; "full": everything moves.
type Mode = "still" | "calm" | "full"

type Piece = {
	plot: Model,
	decorId: string,
	spec: Presets.DecorSpec,
	model: Model?, -- a placed piece (the Blossom Tree)
	mode: Mode?, -- what is built now; nil until its walls, floor or front have streamed in
	made: { Instance },
	tweens: { Tween },
}

-- A plot-space box round a plot's tagged parts, and the top of its side walls (the front and back carry gables).
type Box = { lo: Vector3, hi: Vector3, eave: number }
type Sheet = { frame: CFrame, width: number, height: number, back: boolean }

local styles: { [Model]: { [string]: Piece } } = {} -- plot, then style attribute
local placed: { [Model]: Piece } = {} -- a placed decoration model
local watched: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local using = 0
local started = false

local palette = Presets.palette

local function newPiece(plot: Model, decorId: string, spec: Presets.DecorSpec, model: Model?): Piece
	return {
		plot = plot,
		decorId = decorId,
		spec = spec,
		model = model,
		mode = nil,
		made = {},
		tweens = {},
	}
end

local function stop(piece: Piece)
	for _, tween in piece.tweens do
		tween:Cancel()
	end
	for _, instance in piece.made do
		instance:Destroy()
	end
	table.clear(piece.tweens)
	table.clear(piece.made)
	piece.mode = nil
end

local function play(piece: Piece, instance: Instance, info: TweenInfo, goal: { [string]: any })
	local tween = TweenService:Create(instance, info, goal)
	tween:Play()
	table.insert(piece.tweens, tween)
end

-- Slides a picture across its sheet from X scale `from` to `to` in `seconds`, over and over, starting at `start` so
-- a few in a row stay spread out.
local function drift(
	piece: Piece,
	object: GuiObject,
	from: number,
	to: number,
	start: number,
	seconds: number
)
	local y = object.Position.Y
	local function at(x: number): UDim2
		return UDim2.new(x, 0, y.Scale, y.Offset)
	end
	object.Position = at(start)
	local first = TweenService:Create(
		object,
		TweenInfo.new(seconds * (to - start) / (to - from), Enum.EasingStyle.Linear),
		{ Position = at(to) }
	)
	first.Completed:Connect(function(state: Enum.PlaybackState)
		if state == Enum.PlaybackState.Completed then
			object.Position = at(from)
			play(
				piece,
				object,
				TweenInfo.new(seconds, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
				{ Position = at(to) }
			)
		end
	end)
	first:Play()
	table.insert(piece.tweens, first)
end

-- Geometry -----------------------------------------------------------------------------------------------------

local function measure(plot: Model, tag: string): Box?
	local pivot = plot:GetPivot()
	local lo = Vector3.one * math.huge
	local hi = -lo
	local centres: { Vector3 } = {}
	local tops: { number } = {}
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("BasePart") and instance:IsDescendantOf(plot) then
			local part = instance :: BasePart
			local frame = pivot:ToObjectSpace(part.CFrame)
			local half = Logic.halfExtents(frame, part.Size)
			lo = lo:Min(frame.Position - half)
			hi = hi:Max(frame.Position + half)
			table.insert(centres, frame.Position)
			table.insert(tops, frame.Position.Y + half.Y)
		end
	end
	if #centres == 0 then
		return nil
	end
	local eave = lo.Y
	for i, centre in centres do
		if centre.X - lo.X <= 1.5 or hi.X - centre.X <= 1.5 then
			eave = math.max(eave, tops[i])
		end
	end
	return { lo = lo, hi = hi, eave = eave }
end

local function facing(pivot: CFrame, at: Vector3, normal: Vector3): CFrame
	return pivot * CFrame.lookAt(at, at + normal)
end

-- Sheets just inside the back and side walls, their Front faces into the room.
local function wallSheets(plot: Model, box: Box): { Sheet }
	local fx = Presets.decorFx
	local inset = fx.layer + fx.lift
	local lo, hi = box.lo, box.hi
	local bottom, top = lo.Y + fx.wallFrom, box.eave - fx.wallTo
	if top - bottom < 1 then
		return {}
	end
	local y = (bottom + top) / 2
	local midX, midZ = (lo.X + hi.X) / 2, (lo.Z + hi.Z) / 2
	local across = hi.X - lo.X - 2 * fx.layer
	local deep = hi.Z - lo.Z - 2 * fx.layer
	local pivot = plot:GetPivot()
	return {
		{
			frame = facing(pivot, Vector3.new(midX, y, hi.Z - inset), Vector3.new(0, 0, -1)),
			width = across,
			height = top - bottom,
			back = true,
		},
		{
			frame = facing(pivot, Vector3.new(lo.X + inset, y, midZ), Vector3.new(1, 0, 0)),
			width = deep,
			height = top - bottom,
			back = false,
		},
		{
			frame = facing(pivot, Vector3.new(hi.X - inset, y, midZ), Vector3.new(-1, 0, 0)),
			width = deep,
			height = top - bottom,
			back = false,
		},
	}
end

-- A sheet just outside the cafe front (plot -Z faces the street), up to the eave, its Front face to the street.
local function frontSheet(plot: Model, box: Box): Sheet
	local lo, hi = box.lo, box.hi
	local at = Vector3.new((lo.X + hi.X) / 2, (lo.Y + box.eave) / 2, lo.Z - Presets.decorFx.lift)
	return {
		frame = facing(plot:GetPivot(), at, Vector3.new(0, 0, -1)),
		width = hi.X - lo.X,
		height = box.eave - lo.Y,
		back = false,
	}
end

-- The plot's biggest floor part the Floor style paints.
local function floorOf(plot: Model): BasePart?
	local best: BasePart? = nil
	local most = 0
	for _, instance in CollectionService:GetTagged("Floor") do
		if instance:IsA("BasePart") and instance:IsDescendantOf(plot) then
			local size = (instance :: BasePart).Size
			if size.X * size.Z > most then
				best, most = instance :: BasePart, size.X * size.Z
			end
		end
	end
	return best
end

-- Where the Blossom Tree's petals fall from: a part named for its canopy, else the top of the model.
local function canopyOf(model: Model): (CFrame, Vector3)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local name = descendant.Name
			if name:sub(-6) == "Canopy" or name:sub(-7) == "Blossom" then
				return (descendant :: BasePart).CFrame, (descendant :: BasePart).Size
			end
		end
	end
	local frame, size = model:GetBoundingBox()
	return frame * CFrame.new(0, size.Y / 2 - 0.3, 0), size
end

-- Pictures -----------------------------------------------------------------------------------------------------

local function sheet(
	piece: Piece,
	name: string,
	frame: CFrame,
	size: Vector3,
	face: Enum.NormalId,
	pixels: number,
	light: number
): SurfaceGui
	local part = Context.effectPart(name, size, palette.offwhite)
	part.Transparency = 1
	part.CFrame = frame
	part.Parent = Context.folder()
	table.insert(piece.made, part)
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixels
	gui.LightInfluence = light
	gui.Parent = part
	return gui
end

-- An invisible box that a glint or petal emitter sprays from, switched on.
local function sprayer(piece: Piece, frame: CFrame, size: Vector3)
	local spec = piece.spec
	local presetName = spec.emitter
	local preset: Presets.EmitterPreset? = if presetName ~= nil
		then Presets.emitters[presetName]
		else nil
	if presetName == nil or preset == nil then
		return
	end
	local pad = Context.effectPart("Decor_" .. presetName, size, palette.offwhite)
	pad.Transparency = 1
	pad.CFrame = frame
	pad.Parent = Context.folder()
	table.insert(piece.made, pad)
	local emitter = Particles.make(preset)
	emitter.Name = presetName
	if spec.colors ~= nil then
		Particles.paint(emitter, spec.colors)
	end
	emitter.Parent = pad
	Particles.switchOn(emitter, presetName)
end

local function shape(parent: Instance, props: { [string]: any }): Frame
	local made = Instance.new("Frame")
	made.BorderSizePixel = 0
	made.AnchorPoint = Vector2.new(0.5, 0.5)
	for key, value in props do
		(made :: any)[key] = value
	end
	made.Parent = parent
	return made
end

local function round(object: GuiObject)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = object
end

-- A soft band of colour: `colors` and transparency `shown` at its middle, fading out at both edges along `rotation`.
local function softBand(
	band: Frame,
	colors: { Color3 },
	shown: number,
	rotation: number
): UIGradient
	local keys: { ColorSequenceKeypoint } = {}
	for i, colour in colors do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(1, #colors - 1), colour))
	end
	local gradient = Instance.new("UIGradient")
	gradient.Color = if #keys > 1 then ColorSequence.new(keys) else ColorSequence.new(colors[1])
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, shown),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Rotation = rotation
	gradient.Parent = band
	return gradient
end

-- Stars at the same places on every client (`rng` is seeded by the plot and wall), some twinkling in "full".
local function stars(piece: Piece, gui: SurfaceGui, rng: Random, count: number, mode: Mode)
	local s = Presets.decorFx.stars
	for i = 1, count do
		local size = rng:NextInteger(s.size[1], s.size[2])
		local shown = rng:NextNumber(s.shown[1], s.shown[2])
		local x, y = rng:NextNumber(0.03, 0.97), rng:NextNumber(0.04, 0.9)
		local twinkles = rng:NextNumber() < s.twinkleShare
		local period = rng:NextNumber(s.twinkle[1], s.twinkle[2])
		local delay = rng:NextNumber(0, period)
		local diamond = size >= s.diamondFrom
		local star = shape(gui, {
			Name = "Star",
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromOffset(size, size),
			Rotation = if diamond then 45 else 0,
			BackgroundColor3 = if i % 3 == 0 then palette.offwhite else palette.sparkle,
			BackgroundTransparency = shown,
			ZIndex = 1,
		})
		if not diamond then
			round(star)
		end
		if mode == "full" and twinkles then
			local info = TweenInfo.new(
				period,
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.InOut,
				-1,
				true,
				delay
			)
			play(piece, star, info, { BackgroundTransparency = s.faded })
		end
	end
end

-- A full moon in rings of soft glow, with two faint craters, drifting along the back wall in "full".
local function moon(piece: Piece, gui: SurfaceGui, mode: Mode)
	local m = Presets.decorFx.moon
	local holder = shape(gui, {
		Name = "Moon",
		Position = UDim2.fromScale(m.from, m.height),
		Size = UDim2.fromOffset(m.size, m.size),
		BackgroundTransparency = 1,
		ZIndex = 3,
	})
	for _, ring in m.glow do
		round(shape(holder, {
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(m.size * ring[1], m.size * ring[1]),
			BackgroundColor3 = palette.lampWarm,
			BackgroundTransparency = ring[2],
			ZIndex = 3,
		}))
	end
	local disc = shape(holder, {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = palette.offwhite,
		ZIndex = 4,
	})
	round(disc)
	for _, crater in { { 0.36, 0.4, 0.22 }, { 0.62, 0.64, 0.16 } } do
		round(shape(disc, {
			Position = UDim2.fromScale(crater[1], crater[2]),
			Size = UDim2.fromScale(crater[3], crater[3]),
			BackgroundColor3 = palette.furGrey,
			BackgroundTransparency = m.crater,
			ZIndex = 5,
		}))
	end
	if mode == "full" then
		local info =
			TweenInfo.new(m.seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		play(piece, holder, info, { Position = UDim2.fromScale(m.to, m.height) })
	end
end

-- Curtains of northern light, violet at the top to teal at the foot, swaying and shimmering in "full".
local function aurora(piece: Piece, gui: SurfaceGui, rng: Random, mode: Mode)
	local a = Presets.decorFx.aurora
	for i = 1, a.bands do
		local x = 0.5 + rng:NextNumber(-0.15, 0.15)
		local y = 0.2 + (i - 1) * 0.16
		local tilt = rng:NextNumber(-a.sway, a.sway)
		local band = shape(gui, {
			Name = "Aurora",
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(1.4, a.height),
			Rotation = tilt,
			BackgroundColor3 = palette.offwhite,
			ZIndex = 2,
		})
		local gradient =
			softBand(band, { palette.aurora, palette.mint, palette.signTeal }, a.shown, 90)
		if mode == "full" then
			local seconds = a.seconds[i] or a.seconds[#a.seconds]
			local sway =
				TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
			play(
				piece,
				band,
				sway,
				{ Rotation = -tilt, Position = UDim2.fromScale(x + a.drift, y) }
			)
			local shimmer = TweenInfo.new(
				seconds * 0.7,
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.InOut,
				-1,
				true
			)
			play(piece, gradient, shimmer, { Offset = Vector2.new(0, a.shimmer) })
		end
	end
end

-- Bands of light under Glimmer Canal's glass, sliding across in "full".
local function canal(piece: Piece, gui: SurfaceGui, rng: Random, mode: Mode)
	local c = Presets.decorFx.canal
	for i = 1, c.bands do
		local start = (i - 0.5) / c.bands * 1.6 - 0.3
		local seconds = rng:NextNumber(c.seconds[1], c.seconds[2])
		local band = shape(gui, {
			Name = "Shimmer",
			Position = UDim2.fromScale(start, 0.5),
			Size = UDim2.fromScale(c.width, 1.8),
			Rotation = c.tilt,
			BackgroundColor3 = palette.offwhite,
		})
		softBand(band, { palette.pastelSky, palette.milk, palette.pastelSky }, c.shown, 0)
		if mode == "full" then
			drift(piece, band, -0.3, 1.3, start, seconds)
		end
	end
end

-- Rainbow Shimmer's tint over the cafe front: the rainbow twice over on a strip twice as wide, so scrolling it one
-- width across in "full" loops without a seam.
local function rainbow(piece: Piece, gui: SurfaceGui, mode: Mode)
	local r = Presets.decorFx.rainbow
	local list: { Color3 } = {}
	for _ = 1, 2 do
		for _, colour in r.colors do
			table.insert(list, colour)
		end
	end
	table.insert(list, r.colors[1])
	local strip = shape(gui, {
		Name = "Rainbow",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(2, 1),
		BackgroundColor3 = palette.offwhite,
	})
	local keys: { ColorSequenceKeypoint } = {}
	for i, colour in list do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#list - 1), colour))
	end
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(keys)
	gradient.Transparency = NumberSequence.new(r.shown)
	gradient.Parent = strip
	if mode == "full" then
		drift(piece, strip, 0, -1, 0, r.seconds)
	end
end

-- Gold Leaf's sheen: a light band sweeping over the front, on the sheet only part of each crossing, in "full".
local function sheen(piece: Piece, gui: SurfaceGui)
	local s = Presets.decorFx.sheen
	local band = shape(gui, {
		Name = "Sheen",
		Position = UDim2.fromScale(-1.5, 0.5),
		Size = UDim2.fromScale(s.width, 1.6),
		Rotation = s.tilt,
		BackgroundColor3 = palette.goldLight,
	})
	softBand(band, { palette.goldLight, palette.offwhite, palette.goldLight }, s.shown, 0)
	drift(piece, band, -1.5, 2.5, -1.5, s.seconds)
end

local function seedOf(plot: Model, salt: number): number
	local index = plot:GetAttribute("PlotIndex")
	return (if type(index) == "number" then index else 0) * 97 + salt
end

-- Builds a piece's look for `mode`; false while what it shows on has not streamed in.
local function build(piece: Piece, mode: Mode): boolean
	local fx = Presets.decorFx
	local look = piece.spec.look
	local plot = piece.plot
	if look == "stars" or look == "aurora" then
		local box = measure(plot, "Wallpaper")
		if box == nil then
			return false
		end
		for i, wall in wallSheets(plot, box) do
			local size = Vector3.new(wall.width, wall.height, 0.05)
			local gui =
				sheet(piece, "Decor_" .. look, wall.frame, size, Enum.NormalId.Front, fx.pixels, 0)
			local rng = Random.new(seedOf(plot, i))
			if look == "stars" then
				stars(piece, gui, rng, if wall.back then fx.stars.back else fx.stars.side, mode)
				if wall.back then
					moon(piece, gui, mode)
				end
			else
				stars(piece, gui, rng, fx.aurora.stars, mode)
				aurora(piece, gui, rng, mode)
			end
		end
		return true
	elseif look == "canal" then
		local floor = floorOf(plot)
		if floor == nil then
			return false
		end
		local top = floor.CFrame * CFrame.new(0, floor.Size.Y / 2 + fx.lift, 0)
		local size = Vector3.new(floor.Size.X, 0.05, floor.Size.Z)
		local gui = sheet(piece, "Decor_canal", top, size, Enum.NormalId.Top, fx.floorPixels, 0.5)
		canal(piece, gui, Random.new(seedOf(plot, 7)), mode)
		if mode ~= "still" then
			sprayer(
				piece,
				top * CFrame.new(0, 0.15, 0),
				Vector3.new(floor.Size.X * 0.9, 0.1, floor.Size.Z * 0.9)
			)
		end
		return true
	elseif look == "rainbow" or look == "goldLeaf" then
		local box = measure(plot, "Paint")
		if box == nil then
			return false
		end
		local front = frontSheet(plot, box)
		local size = Vector3.new(front.width, front.height, 0.05)
		if look == "rainbow" then
			local gui = sheet(
				piece,
				"Decor_rainbow",
				front.frame,
				size,
				Enum.NormalId.Front,
				fx.floorPixels,
				fx.rainbow.light
			)
			rainbow(piece, gui, mode)
		elseif mode ~= "still" then
			-- Gold Leaf's still look is the foil itself.
			if mode == "full" then
				local gui = sheet(
					piece,
					"Decor_goldLeaf",
					front.frame,
					size,
					Enum.NormalId.Front,
					fx.floorPixels,
					0.6
				)
				sheen(piece, gui)
			end
			sprayer(
				piece,
				front.frame * CFrame.new(0, 0, -0.15),
				Vector3.new(front.width, front.height, 0.2)
			)
		end
		return true
	elseif look == "petals" then
		local model = piece.model
		if model == nil or model.Parent == nil then
			return false
		end
		if mode ~= "still" then
			local at, size = canopyOf(model)
			local pad = fx.petalPad
			sprayer(piece, at, Vector3.new(size.X * pad, 0.2, size.Z * pad))
		end
		return true
	end
	return true
end

-- Tracking -----------------------------------------------------------------------------------------------------

local function watchPlot(plot: Model)
	if watched[plot] then
		return
	end
	watched[plot] = true
	local function consider(instance: Instance)
		if not instance:IsA("Model") or placed[instance :: Model] ~= nil then
			return
		end
		local decorId = instance:GetAttribute("DecorId")
		local spec = if type(decorId) == "string" then Presets.decor[decorId] else nil
		if spec ~= nil and spec.on == "model" then
			placed[instance :: Model] = newPiece(plot, decorId :: string, spec, instance :: Model)
		end
	end
	for _, descendant in plot:GetDescendants() do
		consider(descendant)
	end
	plot.DescendantAdded:Connect(consider)
end

-- Finds the Mythical styles in use on every plot, and drops pieces taken out of use.
local function scan()
	for _, instance in CollectionService:GetTagged("Plot") do
		if not instance:IsA("Model") or not instance:IsDescendantOf(Workspace) then
			continue
		end
		local plot = instance :: Model
		watchPlot(plot)
		local slots = styles[plot]
		if slots == nil then
			slots = {}
			styles[plot] = slots
		end
		local inPlot = slots :: { [string]: Piece }
		for _, slot in Crates.STYLE_SLOTS do
			local decorId = plot:GetAttribute(slot.attribute)
			local spec = if type(decorId) == "string" then Presets.decor[decorId] else nil
			local piece: Piece? = inPlot[slot.attribute]
			if piece ~= nil and (spec == nil or piece.decorId ~= decorId) then
				stop(piece)
				inPlot[slot.attribute] = nil
				piece = nil
			end
			if piece == nil and spec ~= nil and spec.on == slot.attribute then
				inPlot[slot.attribute] = newPiece(plot, decorId :: string, spec, nil)
			end
		end
	end
	for plot, slots in styles do
		if plot.Parent == nil then
			for _, piece in slots do
				stop(piece)
			end
			styles[plot] = nil
		end
	end
	for model, piece in placed do
		if model.Parent == nil then
			stop(piece)
			placed[model] = nil
		end
	end
end

-- Chooses which pieces move and builds each one's look when its mode changes.
local function choose()
	local budget = Context.budget
	local all: { Piece } = {}
	local candidates: { Logic.Candidate<Piece> } = {}
	local function add(piece: Piece, at: Vector3)
		table.insert(all, piece)
		table.insert(candidates, { key = piece, distance = Context.distance(at) })
	end
	for plot, slots in styles do
		for _, piece in slots do
			add(piece, plot:GetPivot().Position)
		end
	end
	for model, piece in placed do
		add(piece, model:GetPivot().Position)
	end
	local chosen: { [Piece]: boolean } = {}
	local picked = Logic.nearest(candidates, budget.ambientRadius, budget.decorEffects)
	for _, piece in picked do
		chosen[piece] = true
	end
	using = #picked
	local calm = Context.reducedMotion()
	for _, piece in all do
		local wanted: Mode = if not chosen[piece] then "still" elseif calm then "calm" else "full"
		if piece.mode ~= wanted then
			stop(piece)
			if build(piece, wanted) then
				piece.mode = wanted
			else
				stop(piece)
			end
		end
	end
end

-- How many Mythical pieces are moving now; Ambient leaves them that many of the steady emitters.
function Decor.inUse(): number
	return using
end

function Decor.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		while true do
			scan()
			choose()
			task.wait(Presets.decorFx.checkEvery)
		end
	end)
end

return Decor
