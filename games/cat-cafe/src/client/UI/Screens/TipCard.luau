--!strict
-- A context tip's card (F87, easy-start.md section 3): one line with a glyph, sliding down from the top centre under
-- Roblox's top bar, over the clear band the lighter HUD keeps and above the toasts. It needs no press: a thin bar
-- along its foot drains over the card's seconds and it slides away, or a tap anywhere on it sends it away at once.
-- Components/TipQueue decides which tip and when; this only shows one. #2694 (Derek2: "make it easier to notice the
-- close and make the tips bubbles ... smaller"): a narrower, shorter card with a red X at its right end, which the
-- tap anywhere still answers.
--   show(text, icon, seconds, onDone)   onDone(tapped) once the card has gone
--   hide()                              sends a showing card away as if its time ran out
--   isShowing() -> boolean

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Create = require(script.Parent.Parent.Components.Create)
local GamepadNav = require(script.Parent.Parent.Components.GamepadNav)
local IconArt = require(script.Parent.Parent.Components.IconArt)
local Outline = require(script.Parent.Parent.Components.Outline)
local Scale = require(script.Parent.Parent.Scale)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)

export type TipCard = {
	screenGui: ScreenGui,
	show: (
		self: TipCard,
		text: string,
		icon: string,
		seconds: number,
		onDone: (tapped: boolean) -> ()
	) -> (),
	hide: (self: TipCard) -> (),
	isShowing: (self: TipCard) -> boolean,
	destroy: (self: TipCard) -> (),
}

local TOP = 12 -- under the top bar (the ScreenGui keeps to the safe insets)
local BAR_H = 5
local SLIDE = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SLIDE_OUT = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
-- The card's sizes (design px). #2762 (Derek2: the tips are "for phone too big"): a phone held sideways draws the UI
-- at the touch floor, about 1.6 times its share of a PC's screen, so there the card is a size smaller (Scale.isPhone).
type Layout = {
	w: number,
	h: number,
	icon: number,
	glyph: number,
	x: number,
	xText: number,
	pad: number,
	text: number,
}
local FULL: Layout = {
	w = 400,
	h = 64,
	icon = 42,
	glyph = 24,
	x = 28,
	xText = 18,
	pad = 12,
	text = Theme.sizes.textBody + 1,
}
local PHONE: Layout = {
	w = 300,
	h = 60, -- the whole card is the close: a finger high (44 px at the touch floor)
	icon = 30,
	glyph = 17,
	x = 22,
	xText = 14,
	pad = 8,
	text = Theme.sizes.textBody,
}
local CLEAR = 8 -- the gap kept under anything in `avoid` (#2393)
-- #5625 (Derek 2026-11-20: the tips pop ups are "broken and ugly", and "the bad tip hud is still in game"): with the
-- ask cards' askClean switch on, the tip takes the same clean look: the glyph's disc and the X as little house buttons
-- (gold and red, light top to deeper bottom), the X a rounded square like the ask card's, and the timer bar inset and
-- rounded over the foot in place of a flat strip on the card's edge. Read as each tip shows.
local CLEAN_FLAG = "askClean"
local CLEAN_BAR_H = 4
local CLEAN_BAR_FOOT = 5 -- the bar's gap over the card's foot
local CLEAN_UP = 5 -- the disc, line and X sit this far over the middle, clear of the bar
local CLEAN_LINE_TRIM = 18 -- the line's box is this much shorter than the card, so two lines clear the bar too
local CLEAN_X_RADIUS = 8
local CLEAN_GOLD = ColorSequence.new(Theme.button.gold.top, Theme.button.gold.bottom)
local CLEAN_RED = ColorSequence.new(Theme.button.close.top, Theme.button.close.bottom)

local function cleanOn(): boolean
	return ReplicatedStorage:GetAttribute("LiveFlag_" .. CLEAN_FLAG) == true
end

local TipCard = {}
TipCard.__index = TipCard

-- `avoid` gives the HUD pieces the card must not cover at the top centre (the counters and Luck row on a phone,
-- #2393); nil keeps it at TOP.
function TipCard.new(parent: Instance, avoid: (() -> { GuiObject })?): TipCard
	local self = setmetatable({}, TipCard) :: any
	self._avoid = avoid
	self._token = 0
	self._onDone = nil :: ((tapped: boolean) -> ())?
	self._drain = nil :: Tween?
	local L: Layout = if Scale.isPhone() then PHONE else FULL
	self._layout = L

	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeTips",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 11, -- over the HUD (10), under the windows
		Parent = parent,
	})
	self.screenGui = screenGui
	local root: Frame = Create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui,
	})
	self._uiScale = Scale.bind(root)

	local card: TextButton = Create("TextButton", {
		Name = "Card",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.modal.panel,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -(L.h + 20)),
		Size = UDim2.fromOffset(L.w, L.h),
		ClipsDescendants = true,
		Visible = false,
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius + 4) }),
		-- a phone held upright is narrower than the card: the card keeps 16 px from each edge
		Create("UISizeConstraint", { MinSize = Vector2.new(240, L.h) }),
	})
	Outline.border(card, Theme.sizes.outline + 1)
	self._card = card

	local disc: Frame = Create("Frame", {
		Name = "Icon",
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, L.pad, 0.5, -1),
		Size = UDim2.fromOffset(L.icon, L.icon),
		Parent = card,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	Outline.border(disc, 2.5)
	self._disc = disc
	self._discFace = Create("UIGradient", {
		Name = "Face",
		Color = CLEAN_GOLD,
		Rotation = 90,
		Enabled = false,
		Parent = disc,
	})
	self._icon = Create("TextLabel", {
		Name = "Glyph",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.fonts.display,
		TextSize = L.glyph,
		TextColor3 = Theme.colors.white,
		Text = "",
		Parent = disc,
	})
	self._line = Create("TextLabel", {
		Name = "Line",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, L.pad + L.icon + L.pad, 0.5, -1),
		Size = UDim2.new(1, -(L.pad + L.icon + L.pad + 10 + L.x + 10), 1, -12),
		FontFace = Theme.fonts.display,
		TextSize = L.text,
		TextColor3 = Theme.modal.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = "",
		Parent = card,
	})
	-- the X: the whole card is the close, this shows it
	local x: TextLabel = Create("TextLabel", {
		Name = "X",
		BackgroundColor3 = Theme.colors.red,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, -1),
		Size = UDim2.fromOffset(L.x, L.x),
		Text = "",
		Parent = card,
	})
	-- the letter is its own label over the square: a UIGradient on a TextLabel tints its text too, which hid the X
	-- on the clean look's red face (Sync 2026-11-20)
	Create("TextLabel", {
		Name = "Letter",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.fonts.display,
		TextSize = L.xText,
		TextColor3 = Theme.colors.white,
		Text = "X",
		Parent = x,
	})
	self._xCorner = Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = x })
	self._xFace = Create("UIGradient", {
		Name = "Face",
		Color = CLEAN_RED,
		Rotation = 90,
		Enabled = false,
		Parent = x,
	})
	Outline.border(x, 2)
	self._x = x
	local track: Frame = Create("Frame", {
		Name = "Track",
		BackgroundColor3 = Theme.colors.line,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, BAR_H),
		Parent = card,
	})
	self._track = track
	self._trackCorner = Create("UICorner", { CornerRadius = UDim.new(0, 0), Parent = track })
	self._bar = Create("Frame", {
		Name = "Bar",
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = track,
	})
	self._barCorner = Create("UICorner", { CornerRadius = UDim.new(0, 0), Parent = self._bar })

	self._tap = card.Activated:Connect(function()
		if self._onDone ~= nil then
			Sound.play("uiClose")
			self:_close(true)
		end
	end)
	self._resize = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_fit()
	end)
	self:_fit()
	return self :: TipCard
end

-- The card is its layout's width, or the screen less 16 px a side when that is narrower.
function TipCard._fit(self: any)
	local scale = math.max(self._uiScale.Scale, 0.01)
	local width = self._card.Parent.AbsoluteSize.X / scale
	local L: Layout = self._layout
	self._card.Size = UDim2.fromOffset(math.min(L.w, math.max(240, width - 32)), L.h)
end

-- How far down the card comes (design px): TOP, or just under anything in `avoid` it would cover there.
function TipCard._clearTop(self: any): number
	local avoid: (() -> { GuiObject })? = self._avoid
	local root: Frame = self._card.Parent
	local scale = self._uiScale.Scale
	if avoid == nil or scale <= 0 or root.AbsoluteSize.X <= 0 then
		return TOP
	end
	local width = self._card.Size.X.Offset * scale
	local left = root.AbsolutePosition.X + (root.AbsoluteSize.X - width) / 2 - CLEAR * scale
	local right = left + width + 2 * CLEAR * scale
	local rootTop = root.AbsolutePosition.Y
	local top = TOP
	for _, object in avoid() do
		local size, at = object.AbsoluteSize, object.AbsolutePosition
		if
			object.Visible
			and size.X > 0
			and at.X < right
			and at.X + size.X > left
			and at.Y < rootTop + (TOP + self._layout.h + CLEAR) * scale
		then
			top = math.max(top, math.ceil((at.Y + size.Y - rootTop) / scale) + CLEAR)
		end
	end
	return top
end

-- #5625: the clean look on or off, as the tip shows
function TipCard._paint(self: any, clean: boolean, luck: boolean)
	local L: Layout = self._layout
	local up = if clean then -CLEAN_UP else -1
	local disc: Frame = self._disc
	disc.Position = UDim2.new(0, L.pad, 0.5, up)
	disc.BackgroundColor3 = if luck
		then Theme.luck.circle
		elseif clean then Color3.new(1, 1, 1)
		else Theme.colors.gold
	self._discFace.Enabled = clean and not luck
	local line: TextLabel = self._line
	line.Position = UDim2.new(0, L.pad + L.icon + L.pad, 0.5, up)
	line.Size = UDim2.new(
		1,
		-(L.pad + L.icon + L.pad + 10 + L.x + 10),
		1,
		if clean then -CLEAN_LINE_TRIM else -12
	)
	local x: TextLabel = self._x
	x.Position = UDim2.new(1, -10, 0.5, up)
	x.BackgroundColor3 = if clean then Color3.new(1, 1, 1) else Theme.colors.red
	self._xFace.Enabled = clean
	self._xCorner.CornerRadius = if clean then UDim.new(0, CLEAN_X_RADIUS) else UDim.new(1, 0)
	local track: Frame = self._track
	local round = if clean then UDim.new(1, 0) else UDim.new(0, 0)
	self._trackCorner.CornerRadius = round
	self._barCorner.CornerRadius = round
	if clean then
		track.Position = UDim2.new(0, L.pad, 1, -CLEAN_BAR_FOOT)
		track.Size = UDim2.new(1, -2 * L.pad, 0, CLEAN_BAR_H)
	else
		track.Position = UDim2.fromScale(0, 1)
		track.Size = UDim2.new(1, 0, 0, BAR_H)
	end
end

function TipCard.show(
	self: any,
	text: string,
	icon: string,
	seconds: number,
	onDone: (tapped: boolean) -> ()
)
	if self._onDone ~= nil then
		self:_close(false)
	end
	self._token += 1
	local token = self._token
	self._onDone = onDone
	self._line.Text = text
	self._icon.Text = icon
	-- #1258: the luck tip shows the luck chip's look, the clean clover (black outline drawn in) on the dark green circle
	-- with no gold round it; the other tips keep their glyph on the gold disc
	local luck = icon == Theme.icons.luck
	self:_paint(cleanOn(), luck)
	IconArt.set(self._icon, if luck then icon else nil, 0.82)
	local card: TextButton = self._card
	card.Visible = true
	local bar: Frame = self._bar
	bar.Size = UDim2.fromScale(1, 1)
	local top = self:_clearTop()
	if GuiService.ReducedMotionEnabled then
		card.Position = UDim2.new(0.5, 0, 0, top)
	else
		card.Position = UDim2.new(0.5, 0, 0, -(self._layout.h + 20))
		TweenService:Create(card, SLIDE, { Position = UDim2.new(0.5, 0, 0, top) }):Play()
	end
	Sound.play("uiHint")
	local drain = TweenService:Create(
		bar,
		TweenInfo.new(seconds, Enum.EasingStyle.Linear),
		{ Size = UDim2.fromScale(0, 1) }
	)
	self._drain = drain
	drain:Play()
	task.delay(seconds, function()
		if self._token == token then
			self:_close(false)
		end
	end)
	-- #4224 (console): B puts the tip away, without taking the selection (the player keeps moving)
	GamepadNav.pushBack("tipCard", card, function(): boolean?
		self:_close(false)
		return true
	end)
end

function TipCard._close(self: any, tapped: boolean)
	local onDone: ((tapped: boolean) -> ())? = self._onDone
	if onDone == nil then
		return
	end
	self._onDone = nil
	GamepadNav.popBack("tipCard")
	self._token += 1
	local token = self._token
	local drain: Tween? = self._drain
	if drain then
		drain:Cancel()
		self._drain = nil
	end
	local card: TextButton = self._card
	if GuiService.ReducedMotionEnabled then
		card.Visible = false
	else
		local out = TweenService:Create(
			card,
			SLIDE_OUT,
			{ Position = UDim2.new(0.5, 0, 0, -(self._layout.h + 20)) }
		)
		out.Completed:Once(function()
			if self._token == token then
				card.Visible = false
			end
		end)
		out:Play()
	end
	onDone(tapped)
end

function TipCard.hide(self: any)
	self:_close(false)
end

function TipCard.isShowing(self: any): boolean
	return self._onDone ~= nil
end

function TipCard.destroy(self: any)
	self._token += 1
	self._onDone = nil
	self._tap:Disconnect()
	self._resize:Disconnect()
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return TipCard
