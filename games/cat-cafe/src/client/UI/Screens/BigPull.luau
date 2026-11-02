--!strict
-- The big pull card (F89, luck-and-rare-moments.md 2a and 2b): when this player secures a Legendary, a Mythical, a gold
-- Epic or better or any rainbow cat (F99), or a Legendary or Mythical piece comes out of a crate, the screen's edges
-- warm to the rarity colour, light rays turn slowly behind a big card with the cat's portrait (or the piece's icon),
-- the rarity word ("LEGENDARY!", "GOLD MYTHICAL!", "RAINBOW COMMON!") slams in from 1.6 times size with a small shake
-- and the cat's kind (or the piece's name) sits under it. A new style piece's card has "Use it". The first Epic a
-- player ever secures gets a smaller card ("FIRST EPIC!"). A tap on the card closes it after 1 second; it closes by
-- itself at 2.4 seconds (2 for the first Epic). Controls stay on: only the card takes taps.
-- Reduce Motion: no shake and no turning rays. VFX's confetti and sparkles (Effects/Pull, DisplayOrder 47) burst over
-- it; DisplayOrder 44 sits over the windows (20), toasts (30) and popups (40) and under the cannon card (46).

local GuiService = game:GetService("GuiService")

local BigPullLogic = require(script.Parent.Parent.Components.BigPullLogic)
local Button = require(script.Parent.Parent.Components.Button)
local CatPortrait = require(script.Parent.Parent.Components.CatPortrait)
local Create = require(script.Parent.Parent.Components.Create)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local Outline = require(script.Parent.Parent.Components.Outline)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

-- A crate piece's picture: the same as the Market's reveal tile (ItemIcon:set).
export type Piece = { asset: string?, glyph: string, image: string? }

export type View = {
	card: BigPullLogic.Card,
	rarity: string,
	word: string, -- BigPullLogic.word
	tone: BigPullLogic.Tone,
	name: string, -- the cat's kind (never its nickname) or the piece's name
	cat: Types.CatDef?, -- a cat's portrait
	shiny: boolean?, -- a gold coat on the portrait
	piece: Piece?, -- a crate piece's icon, in place of the portrait
	onUse: (() -> ())?, -- "Use it" on a new style piece
}

export type BigPull = {
	screenGui: ScreenGui,
	show: (self: BigPull, view: View) -> (),
	hide: (self: BigPull) -> (),
	showing: (self: BigPull) -> boolean,
	destroy: (self: BigPull) -> (),
}

local CARD = Vector2.new(340, 330)
local USE_H = 46 -- Use it, taller on a phone for a 44 px face (Scale.tapHeight)
local ART_H = 196
local WORD_Y = 14 + ART_H + 6
local RAYS = 600
local RAY_BARS = 8 -- each bar crosses the middle, so 16 rays
local FIRST_EPIC_SCALE = 0.8
local EDGE_TOP = 0.2 -- share of the screen each glowing edge reaches in
local EDGE_SIDE = 0.16
local EDGE_STRENGTH = 0.3 -- transparency at the very edge

local POP = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SLAM_AT = 0.12 -- the word starts to fall in once the card has mostly popped
local SLAM = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local SHAKE = {
	Vector2.new(-7, 3),
	Vector2.new(6, -4),
	Vector2.new(-4, 2),
	Vector2.new(3, -1),
	Vector2.new(0, 0),
}
local SHAKE_STEP = 0.045
local RAY_SPIN = TweenInfo.new(10, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)
local GLOW_IN = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CLOSE = TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.In)
local FADE = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local BigPull = {}
BigPull.__index = BigPull

local function still(): boolean
	return GuiService.ReducedMotionEnabled
end

-- One glowing edge: the colour at the screen's edge fading to nothing inward. `rotation` points the fade inward.
local function edge(
	parent: Instance,
	name: string,
	props: { [string]: any },
	rotation: number
): (Frame, UIGradient)
	local frame: Frame = Create("Frame", {
		Name = name,
		BackgroundColor3 = Theme.colors.white,
		BorderSizePixel = 0,
		Parent = parent,
	})
	for key, value in props do
		(frame :: any)[key] = value
	end
	local gradient: UIGradient = Create("UIGradient", {
		Rotation = rotation,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, EDGE_STRENGTH),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = frame,
	})
	return frame, gradient
end

function BigPull.new(parent: Instance): BigPull
	local self = setmetatable({}, BigPull) :: any
	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeBigPull",
		ResetOnSpawn = false,
		IgnoreGuiInset = true, -- the warm edges reach the very top of the screen
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 44,
		Enabled = false,
		Parent = parent,
	})
	self.screenGui = screenGui

	-- the warm edges, in screen space so they hug the real edges at any scale
	local edges: Frame = Create("Frame", {
		Name = "Edges",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui,
	})
	self._edges = edges
	self._edgeFrames = {}
	self._edgeGradients = {}
	for _, spec in
		{
			{ "Top", { Size = UDim2.fromScale(1, EDGE_TOP) }, 90 },
			{
				"Bottom",
				{
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.fromScale(1, EDGE_TOP),
				},
				-90,
			},
			{ "Left", { Size = UDim2.fromScale(EDGE_SIDE, 1) }, 0 },
			{
				"Right",
				{
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromScale(EDGE_SIDE, 1),
				},
				180,
			},
		} :: { { any } }
	do
		local frame, gradient = edge(edges, spec[1], spec[2], spec[3])
		table.insert(self._edgeFrames, frame)
		table.insert(self._edgeGradients, gradient)
	end

	local root: Frame = Create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui,
	})
	self._uiScale = Scale.bind(root)

	-- the card and its rays move and grow together
	local holder: Frame = Create("Frame", {
		Name = "Pull",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(CARD.X, CARD.Y),
		Parent = root,
	})
	self._holder = holder
	self._size = Create("UIScale", { Parent = holder })

	local rays: Frame = Create("Frame", {
		Name = "Rays",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(RAYS, RAYS),
		ZIndex = 1,
		Parent = holder,
	})
	self._rays = rays
	self._rayGradients = {}
	for index = 1, RAY_BARS do
		local ray: Frame = Create("Frame", {
			Name = "Ray",
			BackgroundColor3 = Theme.colors.white,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 34, 1, 0),
			Rotation = (index - 1) * (180 / RAY_BARS),
			ZIndex = 1,
			Parent = rays,
		})
		table.insert(
			self._rayGradients,
			Create("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, 0.25),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Parent = ray,
			})
		)
	end
	self._raySpin = nil :: Tween?

	-- the card itself takes the tap that closes it
	local card: TextButton = Create("TextButton", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.colors.paper,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 2,
		Parent = holder,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius + 6) }) })
	self._card = card
	self._stroke = Create("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Theme.colors.gold,
		Thickness = 5,
		Parent = card,
	})

	local art: Frame = Create("Frame", {
		Name = "Art",
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.new(1, -28, 0, ART_H),
		ZIndex = 3,
		Parent = card,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	Outline.border(art, 2)
	self._art = art
	self._artGradient = Create("UIGradient", { Enabled = false, Rotation = 35, Parent = art })
	self._portrait = CatPortrait.new({
		parent = art,
		size = UDim2.new(1, 0, 1, 0),
		zIndex = 4,
	})
	self._icon = ItemIcon.new({
		parent = art,
		size = UDim2.fromOffset(ART_H - 24, ART_H - 24),
		anchorPoint = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
		name = "PieceIcon",
	})
	self._icon.frame.ZIndex = 4

	local word: TextLabel = Create("TextLabel", {
		Name = "Word",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, WORD_Y),
		Size = UDim2.new(1, -20, 0, 58),
		FontFace = Theme.fonts.display,
		TextScaled = true, -- "RAINBOW LEGENDARY!" shrinks to fit; shorter words stay at 46
		TextColor3 = Theme.colors.white,
		Text = "",
		ZIndex = 5,
		Parent = card,
	}, { Create("UITextSizeConstraint", { MaxTextSize = 46 }) })
	Outline.text(word, 4)
	self._word = word
	self._wordScale = Create("UIScale", { Parent = word })
	self._wordGradient = Create("UIGradient", { Enabled = false, Parent = word })

	self._kind = Create("TextLabel", {
		Name = "Kind",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, WORD_Y + 60),
		Size = UDim2.new(1, -24, 0, 30),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textLarge + 2,
		TextColor3 = Theme.modal.text,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		ZIndex = 5,
		Parent = card,
	})

	local useH = Scale.tapHeight(USE_H, Theme.sizes.buttonDepth)
	self._useRoom = useH + 12 -- extra card height under the kind line for Use it
	self._use = Button.new({
		name = "UseIt",
		text = "Use it",
		style = "primary",
		size = UDim2.fromOffset(170, useH),
		anchorPoint = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -12),
		textSize = Theme.sizes.textBody + 2,
		zIndex = 6,
		parent = card,
		onClick = function()
			self:_useIt()
		end,
	})
	self._use.instance.Visible = false

	card.Activated:Connect(function()
		self:_tapped()
	end)

	self._token = 0
	self._startedAt = 0
	self._tapAfter = 1
	self._onUse = nil :: (() -> ())?
	self._open = false
	return self :: BigPull
end

-- Paints the edges, the rays, the card's rim and the word in the view's tone.
function BigPull._paint(self: any, view: View)
	local rainbow = view.tone == "rainbow"
	local color = if view.tone == "gold" then Theme.colors.gold else Theme.rarityColor(view.rarity)
	for _, frame in self._edgeFrames do
		frame.BackgroundColor3 = if rainbow then Theme.colors.white else color
	end
	-- a rainbow edge runs its bands from the screen's edge inward; any other edge is its frame's colour
	local bands = if rainbow then Theme.rainbow else ColorSequence.new(Theme.colors.white)
	for _, gradient in self._edgeGradients do
		gradient.Color = bands
	end
	local rayColor = if rainbow
		then Theme.colors.white
		elseif view.tone == "gold" then Theme.colors.gold
		else color:Lerp(Theme.colors.gold, 0.3)
	for _, ray in self._rays:GetChildren() do
		if ray:IsA("Frame") then
			ray.BackgroundColor3 = rayColor
		end
	end
	for _, gradient in self._rayGradients do
		gradient.Color = bands
	end
	self._stroke.Color = if rainbow then Theme.colors.white else color
	self._art.BackgroundColor3 = if rainbow then Theme.colors.white else color
	self._artGradient.Color = Theme.rainbow
	self._artGradient.Enabled = rainbow
	self._word.TextColor3 = if rainbow then Theme.colors.white else color
	self._wordGradient.Color = Theme.rainbow
	self._wordGradient.Enabled = rainbow
end

function BigPull.show(self: any, view: View)
	self._token += 1
	local token = self._token
	local reduced = still()
	self:_paint(view)
	self._word.Text = view.word
	self._kind.Text = view.name
	if view.cat ~= nil then
		self._portrait.frame.Visible = true
		self._icon.frame.Visible = false
		self._portrait:set(view.cat, view.shiny == true)
	else
		self._portrait:set(nil)
		self._portrait.frame.Visible = false
		local piece = view.piece
		self._icon.frame.Visible = piece ~= nil
		if piece ~= nil then
			self._icon:set(piece.asset, piece.glyph, view.rarity, piece.image)
		end
	end
	self._onUse = view.onUse
	local useIt = view.onUse ~= nil
	self._use.instance.Visible = useIt
	self._holder.Size = UDim2.fromOffset(CARD.X, CARD.Y + (if useIt then self._useRoom else 0))
	self._holder.Position = UDim2.fromScale(0.5, 0.5)
	local tapAfter, closeAt = BigPullLogic.times(view.card)
	self._tapAfter = tapAfter
	self._startedAt = os.clock()
	self._open = true
	self.screenGui.Enabled = true

	-- the edges warm up
	for _, frame in self._edgeFrames do
		frame.BackgroundTransparency = 1
		Tween.to(frame, GLOW_IN, { BackgroundTransparency = 0 })
	end
	-- the rays turn slowly; with Reduce Motion they hold still
	if self._raySpin then
		self._raySpin:Cancel()
		self._raySpin = nil
	end
	self._rays.Rotation = 0
	if not reduced then
		self._raySpin = Tween.to(self._rays, RAY_SPIN, { Rotation = 360 })
	end
	-- the card pops in, then the word slams down onto it with a small shake
	local size = if view.card == "first_epic" then FIRST_EPIC_SCALE else 1
	self._size.Scale = size * 0.6
	Tween.to(self._size, POP, { Scale = size })
	self._wordScale.Scale = BigPullLogic.SLAM
	self._word.TextTransparency = 1
	task.delay(SLAM_AT, function()
		if self._token ~= token then
			return
		end
		self._word.TextTransparency = 0
		Tween.to(self._wordScale, SLAM, { Scale = 1 })
		if reduced then
			return
		end
		for index, offset in SHAKE do
			task.delay(SLAM.Time + (index - 1) * SHAKE_STEP, function()
				if self._token == token then
					self._holder.Position = UDim2.new(0.5, offset.X, 0.5, offset.Y)
				end
			end)
		end
	end)
	task.delay(closeAt, function()
		if self._token == token then
			self:_close()
		end
	end)
end

-- A tap on the card closes it once it has been up `tapAfter` seconds.
function BigPull._tapped(self: any)
	if not self._open or os.clock() - self._startedAt < self._tapAfter then
		return
	end
	self:_close()
end

function BigPull._useIt(self: any)
	if not self._open or os.clock() - self._startedAt < self._tapAfter then
		return
	end
	local onUse = self._onUse
	self:_close()
	if onUse then
		onUse()
	end
end

-- Shrinks the card away and cools the edges; with Reduce Motion it goes at once.
function BigPull._close(self: any)
	if not self._open then
		return
	end
	self._open = false
	self._onUse = nil
	self._token += 1
	local token = self._token
	if still() then
		self:hide()
		return
	end
	Tween.to(self._size, CLOSE, { Scale = 0 })
	for _, frame in self._edgeFrames do
		Tween.to(frame, FADE, { BackgroundTransparency = 1 })
	end
	task.delay(math.max(CLOSE.Time, FADE.Time), function()
		if self._token == token then
			self:hide()
		end
	end)
end

function BigPull.hide(self: any)
	self._token += 1
	self._open = false
	self._onUse = nil
	if self._raySpin then
		self._raySpin:Cancel()
		self._raySpin = nil
	end
	self._holder.Position = UDim2.fromScale(0.5, 0.5)
	self._portrait:set(nil)
	self.screenGui.Enabled = false
end

function BigPull.showing(self: any): boolean
	return self._open == true
end

function BigPull.destroy(self: any)
	self._token += 1
	if self._raySpin then
		self._raySpin:Cancel()
		self._raySpin = nil
	end
	self._portrait:destroy()
	self._icon:destroy()
	self._use:destroy()
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return BigPull
