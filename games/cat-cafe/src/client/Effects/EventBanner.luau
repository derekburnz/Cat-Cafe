--!strict
-- The update party's banner (#3419, for the launch in #3420): a cream and gold card that drops in at the top middle
-- of this player's screen, holds a title and up to three short lines for a few seconds, then slides away. Three uses:
--   "party"     the 1 hour Update Party starts (or you join during it): an "x2" badge, a shine and confetti
--   "giftSoon"  a gift is on its way: a golden fish badge and a few sparkles
--   "gift"      the gift is paid: the golden fish badge, a shine, confetti and golden fish hopping out of the card
--   "secrets"   the Secret cats are out (#3523, the 2026-11-13 update): a night strip, a "?" badge and the Secret
--               cats as black shapes in a row under the words, each with a "?" on it. The shapes are the cats' own
--               models from ReplicatedStorage.Assets drawn all black (Derek, 2026-11-12: "in banner ... blacked
--               out"), so a redesigned model changes its shape here by itself and no coat, glow or sparkle shows.
--               `cats = { "nebula", "cafe_ghost" }` draws only those, for a day one of them is held back.
--   EventBanner.show({ kind = "party", title = "Update Party!", lines = { "x2 cafe earnings until 6:00 PM" } })
--   EventBanner.onShown(function(kind) ... end)   called as a banner starts to drop in (Audio plays its sound there)
-- The caller owns the words (Design-Agent's, #3420 section 5); this only trims them to fit. Banners wait their turn:
-- one shows at a time, up to Presets.eventBanner.queue more wait, and a kind that is already showing or waiting is
-- dropped, so a rejoin or a double fire never stacks two of the same.
-- A tap or click on the card sends it away at once (Derek, 2026-11-12); left alone it goes after 5 seconds. Only the
-- card itself takes the tap, so the HUD round it still works. It sells nothing and opens nothing. Reduce Motion: it fades in
-- and out where it rests, with no shine, confetti or fish. Low performance: half the confetti and half the fish.
-- Everything plays once per banner and nothing loops, so nothing flashes. Client only; it never tells the server
-- anything. Numbers in Presets.eventBanner.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Catalog = require(ReplicatedStorage.Shared.Catalog)

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Presets = require(script.Parent.Presets)
local ScreenFx = require(script.Parent.ScreenFx)

local EventBanner = {}

export type Kind = "party" | "giftSoon" | "gift" | "secrets"
-- `cats`: the "secrets" card's cat ids when the caller names them; nil draws every Secret cat
export type Plan = {
	kind: Kind,
	title: string,
	lines: { string },
	seconds: number,
	cats: { string }?,
}

local FONT_ID = "rbxasset://fonts/families/FredokaOne.json"
local GUI_NAME = "EffectsEventBanner"

local rng = Random.new()
local waiting: { Plan } = {}
local showing: Plan? = nil
local listeners: { (kind: Kind) -> () } = {}

-- `text` cut to at most `most` characters (whole characters, never half of one), with spaces trimmed off both ends.
local function fit(text: string, most: number): string
	local trimmed = string.match(text, "^%s*(.-)%s*$") or ""
	local length = utf8.len(trimmed)
	if length == nil then
		return "" -- not valid text
	end
	if length <= most then
		return trimmed
	end
	local stop = utf8.offset(trimmed, most + 1)
	local cut = if stop ~= nil then string.sub(trimmed, 1, stop - 1) else trimmed
	return string.match(cut, "^(.-)%s*$") or cut
end

-- Pure: what a call to show draws, or nil when it draws nothing (no table, an unknown kind or no title). The title
-- and each line are trimmed and cut to the preset's lengths, empty and non-text lines are skipped, at most
-- `maxLines` are kept, and `seconds` (the hold) is kept inside the preset's range.
function EventBanner.plan(spec: any): Plan?
	local p = Presets.eventBanner
	if type(spec) ~= "table" then
		return nil
	end
	local kind = spec.kind
	if kind ~= "party" and kind ~= "giftSoon" and kind ~= "gift" and kind ~= "secrets" then
		return nil
	end
	if type(spec.title) ~= "string" then
		return nil
	end
	local title = fit(spec.title, p.titleLength)
	if title == "" then
		return nil
	end
	local lines: { string } = {}
	if type(spec.lines) == "table" then
		for _, line in ipairs(spec.lines) do
			if #lines >= p.maxLines then
				break
			end
			if type(line) == "string" then
				local short = fit(line, p.lineLength)
				if short ~= "" then
					table.insert(lines, short)
				end
			end
		end
	end
	local seconds = p.hold
	if type(spec.seconds) == "number" and spec.seconds == spec.seconds then
		seconds = math.clamp(spec.seconds, p.holdMin, p.holdMax)
	end
	local cats: { string }? = nil
	if type(spec.cats) == "table" then
		local named: { string } = {}
		for _, id in ipairs(spec.cats) do
			if type(id) == "string" then
				table.insert(named, id)
			end
		end
		cats = named
	end
	return {
		kind = kind :: Kind,
		title = title,
		lines = lines,
		seconds = seconds,
		cats = cats,
	}
end

-- Pure: whether a banner of `kind` may join the line: not while the same kind shows or waits, and not past `most`
-- waiting.
function EventBanner.accepts(
	showingKind: string?,
	waitingKinds: { string },
	kind: string,
	most: number
): boolean
	if showingKind == kind or #waitingKinds >= most then
		return false
	end
	return table.find(waitingKinds, kind) == nil
end

-- Pure: how far above its resting place the card's top is, `t` seconds into a banner that holds for `hold`: it drops
-- from `travel` pixels up with one small overshoot, rests at 0, then slides back up.
function EventBanner.lift(t: number, hold: number, travel: number): number
	local p = Presets.eventBanner
	if t <= 0 then
		return travel
	end
	if t < p.dropSeconds then
		return travel * (1 - Logic.easeOutBack(t / p.dropSeconds))
	end
	local leaving = t - p.dropSeconds - hold
	if leaving <= 0 then
		return 0
	end
	local k = math.min(leaving / p.leaveSeconds, 1)
	return travel * k * k
end

-- Pure: how see-through the card is with Reduce Motion (it fades in place instead of moving): 1 hidden, 0 solid.
function EventBanner.fade(t: number, hold: number): number
	local p = Presets.eventBanner
	if t <= 0 then
		return 1
	end
	if t < p.fadeSeconds then
		return 1 - t / p.fadeSeconds
	end
	local leaving = t - p.fadeSeconds - hold
	if leaving <= 0 then
		return 0
	end
	return math.min(leaving / p.fadeSeconds, 1)
end

-- Pure: the hold that makes a banner start to leave now: it was tapped `t` seconds in, takes `enter` seconds to
-- arrive and would have held for `hold`. A tap while it is still arriving lets it land, then it leaves at once.
function EventBanner.holdAfterTap(t: number, hold: number, enter: number): number
	return math.clamp(t - enter, 0, hold)
end

-- Pure: how many confetti sparkles and how many hopping fish a banner of `kind` gets on this device.
function EventBanner.counts(
	kind: Kind,
	lowPerformance: boolean,
	reducedMotion: boolean
): (number, number)
	if reducedMotion then
		return 0, 0
	end
	local p = Presets.eventBanner
	local confetti = if kind == "giftSoon" or kind == "secrets" then p.confettiSoon else p.confetti
	local fish = if kind == "gift" then p.fish else 0
	if lowPerformance then
		return math.ceil(confetti / 2), math.ceil(fish / 2)
	end
	return confetti, fish
end

-- Pure: the models drawn as black shapes on the "secrets" banner: the Secret cats in catalog order, at most the
-- preset's `shapeMost`. With `only` (cat ids) just those of them, so the row matches the cats that are really out
-- when one is held back; an id that is not a Secret cat draws nothing.
function EventBanner.shapeModels(only: { string }?): { string }
	local names: { string } = {}
	for _, def in Catalog.secretCats do
		if #names >= Presets.eventBanner.shapeMost then
			break
		end
		if only == nil or table.find(only, def.id) ~= nil then
			table.insert(names, Catalog.catModelName(def.id))
		end
	end
	return names
end

-- Pure: how tall the card for `kind` with `lines` lines is: the "secrets" card has the row of shapes under its words.
function EventBanner.height(kind: Kind, lines: number): number
	local p = Presets.eventBanner
	local words = p.titleHeight + lines * p.lineHeight + p.pad * 2
	return if kind == "secrets" then words + p.shapeRow else words
end

-- Whether a part of a left-off piece is one of its loose bits: no side longer than `most` studs.
function EventBanner.loose(x: number, y: number, z: number, most: number): boolean
	return math.max(x, y, z) <= most
end

-- Pure: how far back the camera stands so a box of `size`, turned any way round its upright axis, fills `fill` of
-- a square view `fov` degrees tall: its nearest face is still inside the view.
function EventBanner.shapeDistance(size: Vector3, fov: number, fill: number): number
	local half = math.max(size.Y, math.sqrt(size.X * size.X + size.Z * size.Z), 0.02) / 2
	return half / math.tan(math.rad(fov / 2)) / math.clamp(fill, 0.1, 1) + half
end

-- Calls `listener(kind)` each time a banner starts to show (Audio plays the banner's sound there).
function EventBanner.onShown(listener: (kind: Kind) -> ())
	table.insert(listeners, listener)
end

local function label(
	parent: Instance,
	name: string,
	text: string,
	size: number,
	colour: Color3
): TextLabel
	local made = Instance.new("TextLabel")
	made.Name = name
	made.BackgroundTransparency = 1
	made.FontFace = Font.new(FONT_ID, Enum.FontWeight.Bold)
	made.Text = text
	made.TextColor3 = colour
	made.TextScaled = true
	made.TextXAlignment = Enum.TextXAlignment.Left
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = size
	limit.MinTextSize = 10
	limit.Parent = made
	made.Parent = parent
	return made
end

local function round(parent: Instance, radius: UDim)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = parent
end

-- One Secret cat as a black shape: a copy of its model with everything but its solid parts taken off, drawn all
-- black by the ViewportFrame's tint, so a see-through or glowing cat is still one plain shape. With no model in
-- Assets it is a black dot. Each has a "?" on it. `fading` collects what Reduce Motion fades.
local function shape(parent: Instance, modelName: string, fading: { GuiObject }): Frame
	local p = Presets.eventBanner
	local holder = Instance.new("Frame")
	holder.Name = modelName
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(p.shapeSize, p.shapeSize)
	holder.Parent = parent
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local source = if assets ~= nil then assets:FindFirstChild(modelName) else nil
	local model: Model? = nil
	if source ~= nil and source:IsA("Model") then
		local copy = source:Clone() :: Model
		local solid = 0
		-- the loose bits of a named piece: its parts no longer than shapeLoose on any side (the bigger ones stay)
		for _, descendant in copy:GetDescendants() do
			if
				descendant:IsA("BasePart")
				and table.find(p.shapeLeaveOff, descendant.Name) ~= nil
			then
				local size = (descendant :: BasePart).Size
				if EventBanner.loose(size.X, size.Y, size.Z, p.shapeLoose) then
					descendant:Destroy()
				end
			end
		end
		for _, descendant in copy:GetDescendants() do
			if descendant:IsA("BasePart") then
				local part = descendant :: BasePart
				if part.Transparency >= p.shapeSeen then
					part:Destroy()
				else
					part.Transparency = 0
					part.Anchored = true
					solid += 1
				end
			elseif
				not descendant:IsA("Model")
				and not descendant:IsA("Folder")
				and not descendant:IsA("DataModelMesh")
			then
				descendant:Destroy() -- scripts, particles, beams, lights, labels, welds: none of it is the shape
			end
		end
		if solid > 0 then
			model = copy
		else
			copy:Destroy()
		end
	end
	if model ~= nil then
		local cat: Model = model
		local view = Instance.new("ViewportFrame")
		view.Name = "View"
		view.BackgroundTransparency = 1
		view.Size = UDim2.fromScale(1, 1)
		view.ImageColor3 = p.shapeColour
		local camera = Instance.new("Camera")
		camera.FieldOfView = p.shapeFov
		camera.Parent = view
		view.CurrentCamera = camera
		-- the cat at the origin facing the camera (models face -Z), turned to a three-quarter view
		cat:PivotTo(CFrame.new())
		local box, size = cat:GetBoundingBox()
		local centre = box.Position
		local distance = EventBanner.shapeDistance(size, p.shapeFov, p.shapeFill)
		camera.CFrame = CFrame.lookAt(centre + Vector3.new(0, size.Y * 0.15, -distance), centre)
		cat:PivotTo(
			CFrame.new(centre) * CFrame.Angles(0, math.rad(p.shapeTurn), 0) * CFrame.new(-centre)
		)
		cat.Parent = view
		view.Parent = holder
		table.insert(fading, view)
	else
		local dot = Instance.new("Frame")
		dot.Name = "Dot"
		dot.BackgroundColor3 = p.shapeColour
		dot.BorderSizePixel = 0
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromScale(0.5, 0.5)
		dot.Size = UDim2.fromScale(0.8, 0.8)
		round(dot, UDim.new(0.5, 0))
		dot.Parent = holder
		table.insert(fading, dot)
	end
	local mark = label(holder, "Mark", "?", p.markSize, p.markColour)
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.Position = UDim2.fromScale(0.5, 0.56)
	mark.Size = UDim2.fromOffset(p.markSize, p.markSize + 4)
	mark.TextXAlignment = Enum.TextXAlignment.Center
	mark.ZIndex = 2
	table.insert(fading, mark)
	return holder
end

-- The "secrets" card's row of black shapes. It lies over the card as its own frame, not inside it: the card is a
-- CanvasGroup, which may not draw a ViewportFrame. `run` moves it with the card and fades what `fading` holds.
local function shapes(
	gui: ScreenGui,
	card: GuiObject,
	fading: { GuiObject },
	only: { string }?
): Frame
	local p = Presets.eventBanner
	local over = Instance.new("Frame")
	over.Name = "Shapes"
	over.AnchorPoint = card.AnchorPoint
	over.BackgroundTransparency = 1
	over.Size = card.Size
	over.Position = card.Position
	over.ZIndex = 3
	local widest = Instance.new("UISizeConstraint")
	widest.MaxSize = Vector2.new(p.maxWidth, math.huge)
	widest.Parent = over
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.AnchorPoint = Vector2.new(0.5, 1)
	row.BackgroundTransparency = 1
	row.Position = UDim2.new(0.5, 0, 1, -p.pad / 2)
	row.Size = UDim2.new(1, 0, 0, p.shapeSize)
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, p.shapeGap)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = row
	for i, modelName in EventBanner.shapeModels(only) do
		shape(row, modelName, fading).LayoutOrder = i
	end
	row.Parent = over
	over.Parent = gui
	return over
end

-- The card for `plan`, parented to `gui` at its resting place; its shine band comes back with it.
local function build(gui: ScreenGui, plan: Plan): (CanvasGroup, UIGradient?)
	local p = Presets.eventBanner
	local secret = plan.kind == "secrets"
	local height = EventBanner.height(plan.kind, #plan.lines)
	local card = Instance.new("CanvasGroup")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.BackgroundColor3 = p.card
	card.BorderSizePixel = 0
	card.Size = UDim2.new(p.widthScale, 0, 0, height)
	card.Position = UDim2.new(0.5, 0, 0, GuiService:GetGuiInset().Y + p.top)
	card.ZIndex = 2 -- over the confetti and the fish, which come out from behind it
	round(card, UDim.new(0, p.corner))
	local widest = Instance.new("UISizeConstraint")
	widest.MaxSize = Vector2.new(p.maxWidth, math.huge)
	widest.Parent = card
	local outline = Instance.new("UIStroke")
	outline.Color = p.outline
	outline.Thickness = 3
	outline.Parent = card

	-- the gold strip behind the title (the night sky for the Secret cats)
	local strip = Instance.new("Frame")
	strip.Name = "Strip"
	strip.BackgroundColor3 = Color3.new(1, 1, 1)
	strip.BorderSizePixel = 0
	strip.Size = UDim2.new(1, 0, 0, p.titleHeight + p.pad)
	local gold = Instance.new("UIGradient")
	gold.Color = if secret
		then ColorSequence.new(p.nightTop, p.nightBottom)
		else ColorSequence.new(p.stripTop, p.stripBottom)
	gold.Rotation = 90
	gold.Parent = strip
	strip.Parent = card

	-- the round badge on the left: "x2" for the party, "?" for the Secret cats, the golden fish for a gift
	local words = height - (if secret then p.shapeRow else 0)
	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.BackgroundColor3 = if secret then p.secretBadge else p.badge
	badge.BorderSizePixel = 0
	badge.Position = UDim2.fromOffset(p.pad, words / 2)
	badge.Size = UDim2.fromOffset(p.badgeSize, p.badgeSize)
	badge.ZIndex = 3
	round(badge, UDim.new(0.5, 0))
	local rim = Instance.new("UIStroke")
	rim.Color = p.outline
	rim.Thickness = 3
	rim.Parent = badge
	if plan.kind == "party" or secret then
		local times = label(badge, "Times", if secret then "?" else "x2", 30, p.badgeText)
		times.Size = UDim2.fromScale(0.7, 0.7)
		times.Position = UDim2.fromScale(0.15, 0.15)
		times.TextXAlignment = Enum.TextXAlignment.Center
	else
		local fish = Instance.new("ImageLabel")
		fish.Name = "Fish"
		fish.BackgroundTransparency = 1
		fish.Image = p.fishImage
		fish.Size = UDim2.fromScale(0.76, 0.76)
		fish.Position = UDim2.fromScale(0.12, 0.12)
		fish.Parent = badge
	end
	badge.Parent = card

	local left = p.pad * 2 + p.badgeSize
	local title = label(card, "Title", plan.title, p.titleSize, p.titleText)
	title.Position = UDim2.fromOffset(left, p.pad / 2)
	title.Size = UDim2.new(1, -left - p.pad, 0, p.titleHeight)
	title.ZIndex = 2
	local edge = Instance.new("UIStroke")
	edge.Color = p.outline
	edge.Thickness = 2
	edge.Parent = title
	for i, line in plan.lines do
		local row = label(card, "Line" .. i, line, p.lineSize, p.lineText)
		row.Position =
			UDim2.fromOffset(left, p.titleHeight + p.pad + (i - 1) * p.lineHeight + p.pad / 2)
		row.Size = UDim2.new(1, -left - p.pad, 0, p.lineHeight - 2)
		row.ZIndex = 2
	end

	local band: UIGradient? = nil
	if plan.kind ~= "giftSoon" then
		local shine = Instance.new("Frame")
		shine.Name = "Shine"
		shine.BackgroundColor3 = Color3.new(1, 1, 1)
		shine.BorderSizePixel = 0
		shine.Size = UDim2.fromScale(1, 1)
		shine.ZIndex = 4
		shine.Active = false
		local gradient = Instance.new("UIGradient")
		local half = p.shineWidth / 2
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5 - half, 1),
			NumberSequenceKeypoint.new(0.5, p.shineTransparency),
			NumberSequenceKeypoint.new(0.5 + half, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Rotation = 20
		gradient.Offset = Vector2.new(-1, 0)
		gradient.Parent = shine
		shine.Parent = card
		band = gradient
	end
	-- the whole card is one unseen button: a tap sends the banner away (run listens to it)
	local tap = Instance.new("TextButton")
	tap.Name = "Tap"
	tap.BackgroundTransparency = 1
	tap.Text = ""
	tap.AutoButtonColor = false
	tap.Selectable = false -- a gamepad's selection never lands on it; it leaves by itself
	tap.Size = UDim2.fromScale(1, 1)
	tap.ZIndex = 5
	tap.Parent = card
	card.Parent = gui
	return card, band
end

-- Confetti round the card: `count` sparkles in the preset's colours, spread along its top and bottom edges.
local function confetti(gui: ScreenGui, card: GuiObject, count: number, colours: { Color3 })
	local p = Presets.eventBanner
	local corner = ScreenFx.toGui(gui, card.AbsolutePosition)
	local size = card.AbsoluteSize
	local byColour: { { Vector2 } } = {}
	for i = 1, #colours do
		byColour[i] = {}
	end
	for i = 1, count do
		local x = corner.X + size.X * (i - 0.5) / count
		local y = corner.Y + (if i % 2 == 0 then 0 else size.Y)
		table.insert(byColour[(i - 1) % #colours + 1], Vector2.new(x, y))
	end
	for i, spots in byColour do
		ScreenFx.sparkle(gui, spots, colours[i], {
			size = p.confettiSize,
			seconds = p.confettiSeconds,
			reach = p.confettiReach,
			stagger = p.confettiStagger,
		})
	end
end

type Hop = {
	image: ImageLabel,
	from: Vector2,
	across: number,
	up: number,
	size: number,
	delay: number,
	spin: number,
}

-- The gift's golden fish: `count` of them hop out from under the card, arc up and over, and fade as they fall.
local function fishHop(gui: ScreenGui, card: GuiObject, count: number)
	local p = Presets.eventBanner
	local corner = ScreenFx.toGui(gui, card.AbsolutePosition)
	local size = card.AbsoluteSize
	local hops: { Hop } = {}
	for i = 1, count do
		local image = Instance.new("ImageLabel")
		image.Name = "GiftFish"
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.BackgroundTransparency = 1
		image.Image = p.fishImage
		image.Visible = false
		image.Parent = gui
		local side = (i - 0.5) / count - 0.5 -- -0.5 at the left end to 0.5 at the right
		table.insert(hops, {
			image = image,
			from = Vector2.new(corner.X + size.X * (0.5 + side * 0.8), corner.Y + size.Y),
			across = side * p.fishSpread + rng:NextNumber(-12, 12),
			up = p.fishUp * rng:NextNumber(0.7, 1),
			size = p.fishSize * rng:NextNumber(0.8, 1.1),
			delay = (i - 1) * p.fishStagger,
			spin = rng:NextNumber(-25, 25),
		})
	end
	local began = os.clock()
	local last = p.fishSeconds + count * p.fishStagger
	local loop: RBXScriptConnection? = nil
	loop = RunService.RenderStepped:Connect(function()
		local t = os.clock() - began
		if t >= last or gui.Parent == nil then
			if loop ~= nil then
				loop:Disconnect()
			end
			for _, hop in hops do
				hop.image:Destroy()
			end
			return
		end
		for _, hop in hops do
			local k = (t - hop.delay) / p.fishSeconds
			local on = k > 0 and k < 1
			hop.image.Visible = on
			if on then
				-- a hop: up fast, then down past where it started
				local y = hop.from.Y - hop.up * 4 * k * (1 - k) + p.fishFall * k * k
				local x = hop.from.X + hop.across * k
				local grow = hop.size * math.min(k / 0.15, 1)
				hop.image.Position = UDim2.fromOffset(x, y)
				hop.image.Size = UDim2.fromOffset(grow, grow)
				hop.image.Rotation = hop.spin * k
				hop.image.ImageTransparency = math.clamp((k - 0.65) / 0.35, 0, 1)
			end
		end
	end)
end

local advance: () -> ()

local function run(plan: Plan)
	local gui = ScreenFx.gui(GUI_NAME, Presets.eventBanner.displayOrder)
	if gui == nil then
		showing = nil
		return
	end
	local p = Presets.eventBanner
	local still = Context.reducedMotion()
	local card, band = build(gui, plan)
	local fading: { GuiObject } = {}
	local over: Frame? = if plan.kind == "secrets"
		then shapes(gui, card, fading, plan.cats)
		else nil
	-- the shapes fade with the card (Reduce Motion); `seen` is 1 hidden, 0 solid
	local function fadeShapes(seen: number)
		for _, object in fading do
			if object:IsA("ViewportFrame") then
				(object :: ViewportFrame).ImageTransparency = seen
			elseif object:IsA("TextLabel") then
				(object :: TextLabel).TextTransparency = seen
			else
				object.BackgroundTransparency = seen
			end
		end
	end
	local rest = card.Position
	local travel = rest.Y.Offset + card.Size.Y.Offset + 12 -- from fully off the top of the screen
	local sparkles, fish = EventBanner.counts(plan.kind, Context.lowPerformance, still)
	local popped = false
	if still then
		card.GroupTransparency = 1
		fadeShapes(1)
	else
		card.Position = rest - UDim2.fromOffset(0, travel)
	end
	if over ~= nil then
		over.Position = card.Position
	end
	for _, listener in listeners do
		task.spawn(listener, plan.kind)
	end
	local began = os.clock()
	local enter = if still then p.fadeSeconds else p.dropSeconds
	local hold = plan.seconds
	local whole = enter + hold + (if still then p.fadeSeconds else p.leaveSeconds)
	local tap = card:FindFirstChild("Tap")
	if tap ~= nil and tap:IsA("GuiButton") then
		tap.Activated:Once(function()
			local shorter = EventBanner.holdAfterTap(os.clock() - began, hold, enter)
			whole -= hold - shorter
			hold = shorter
		end)
	end
	local loop: RBXScriptConnection? = nil
	loop = RunService.RenderStepped:Connect(function()
		local t = os.clock() - began
		if t >= whole or card.Parent == nil then
			if loop ~= nil then
				loop:Disconnect()
			end
			card:Destroy()
			if over ~= nil then
				over:Destroy()
			end
			showing = nil
			advance()
			return
		end
		if still then
			local seen = EventBanner.fade(t, hold)
			card.GroupTransparency = seen
			fadeShapes(seen)
			return
		end
		card.Position = rest - UDim2.fromOffset(0, EventBanner.lift(t, hold, travel))
		if over ~= nil then
			over.Position = card.Position
		end
		if band ~= nil then
			local k = (t - p.dropSeconds) / p.shineSeconds
			band.Offset = Vector2.new(-1 + 2 * math.clamp(k, 0, 1), 0)
		end
		if not popped and t >= p.dropSeconds then
			popped = true
			if sparkles > 0 then
				confetti(
					gui,
					card,
					sparkles,
					if plan.kind == "secrets" then p.secretColours else p.confettiColours
				)
			end
			if fish > 0 then
				fishHop(gui, card, fish)
			end
		end
	end)
end

advance = function()
	if showing ~= nil then
		return
	end
	local plan = table.remove(waiting, 1)
	if plan == nil then
		return
	end
	showing = plan
	run(plan)
end

-- Shows a banner (see the top of this file), after any that are already showing or waiting. Returns whether it was
-- taken: false for words it cannot draw, a kind already showing or waiting, or a full line.
function EventBanner.show(spec: any): boolean
	local plan = EventBanner.plan(spec)
	if plan == nil then
		return false
	end
	local kinds: { string } = {}
	for _, other in waiting do
		table.insert(kinds, other.kind)
	end
	local current = showing
	if
		not EventBanner.accepts(
			if current ~= nil then current.kind else nil,
			kinds,
			plan.kind,
			Presets.eventBanner.queue
		)
	then
		return false
	end
	table.insert(waiting, plan)
	advance()
	return true
end

return EventBanner
