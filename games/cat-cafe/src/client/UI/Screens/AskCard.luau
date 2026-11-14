--!strict
-- A small slide-in ask at the bottom centre, over the travel row (F87, easy-start.md sections 2g and 4): one title
-- line, two or three buttons in a row and a gold bar that drains over the ask's seconds before it slides away.
-- Ignoring it is always fine. It carries:
--   * the one feedback faces ask, "How is it so far?" (init times it, Components/FeedbackLogic.askDue), which says
--     "Thanks!" for a moment after a face
--   * the "Need a hand?" card after StuckHelpSeconds on one tutorial step (Show me, Got it)
--   * later, F96's styled asks (UI.asks.show)
--   * F92's one invite nudge, "Playing with a friend gives you both +10% tips. Invite one?" with Invite and Not now,
--     on two title lines (Ask.lines)
--   show(ask)      slides it up with these words and buttons; an ask already up is answered nil and replaced
--   hide(how?)     slides it away, answering nil
--   follow()       keeps a shown card just over the HUD's bottom row as that row moves (#2694)
--   isShowing() -> boolean
-- #3657: an ask's answer may show the next ask on the same card (the faces ask's reasons); the card then stays up
-- with the new words and buttons, with no "Thanks!" between.
-- An ask's answer(id) runs once: the id of the button pressed, or nil when it drained, was closed, was hidden or was
-- replaced; its ended(how), when given, says which: "answered", "closed" (the X), "ignored" (it drained), "hidden"
-- or "replaced" (#2694's funnel). #2694 (Derek2: "make it easier to notice the close and make the tips bubbles (and
-- this bubble) smaller and less on your hotbar"): a red X on the card's corner, a narrower card, and its foot kept
-- clear of the bottom row.

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local Scale = require(script.Parent.Parent.Scale)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)

export type Choice = {
	id: string,
	label: string,
	icon: string?,
	style: Button.Style?, -- "ghost" by default
}

export type Ask = {
	title: string,
	choices: { Choice }, -- two or three
	seconds: number, -- how long it stays with no answer
	thanks: string?, -- said for THANKS_SECONDS after a press, in place of the title; nil slides away at once
	lines: number?, -- F92: 2 wraps a long title onto two lines and makes the card that much taller; 1 by default
	rows: number?, -- #3657: 2 lays the buttons over two rows (the first half, rounded down, on top), the card that much taller
	-- #4174: false hides the gold drain bar (a paid offer must not read as a countdown); it still slides away after
	-- its seconds. Shown by default.
	bar: boolean?,
	answer: (id: string?) -> (),
	ended: ((how: string) -> ())?,
}

export type Callbacks = {
	lift: () -> number, -- the HUD's bottomTop(): the card's foot sits this far over the screen's bottom (negative)
}

export type AskCard = {
	screenGui: ScreenGui,
	show: (self: AskCard, ask: Ask) -> (),
	hide: (self: AskCard, how: string?) -> (),
	follow: (self: AskCard) -> (),
	isShowing: (self: AskCard) -> boolean,
	destroy: (self: AskCard) -> (),
}

local CARD_W = 400
-- #3891 (Derek 2026-11-13: "make the ui for pop ups like this easier to see"): the title sits on a gold band in
-- white with a dark outline, a size bigger, and the card has a soft shadow under it
local TITLE_H = 30
local TITLE_TEXT = Theme.sizes.textLarge
local SHADOW = 6 -- px the shadow drops under the card
local CHOICE_TEXT = Theme.sizes.textBody
-- Studio 2026-11-13 (the invite card's X sat over the word "they"): the X hangs over the card's top right corner, so
-- the title's right end keeps its reach clear; set once the X is made
local TITLE_RIGHT = 0
local CHOICE_H = 44
local PAD = 10
local GAP = 8
local BAR_H = 5
local THANKS_SECONDS = 1.5
local SLIDE = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SLIDE_OUT = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local AskCard = {}
AskCard.__index = AskCard

function AskCard.new(parent: Instance, callbacks: Callbacks): AskCard
	local self = setmetatable({}, AskCard) :: any
	self._callbacks = callbacks
	self._token = 0
	self._showing = false
	self._ask = nil :: Ask?
	self._buttons = {} :: { Button.Button }
	self._lines = 1
	self._rows = 1

	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeAsk",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 16, -- over the HUD (10) and the Tackle bar (14), which covered its buttons at 11; under the windows (20)
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

	-- #2762 (Derek2: the "How is it so far?" ask is "for phone too big"): a size smaller on a phone held sideways in its
	-- width, title and padding; the buttons keep a finger's height (Scale.tapHeight)
	if Scale.isPhone() then
		CARD_W, TITLE_H, TITLE_TEXT, CHOICE_TEXT, PAD =
			340, 26, Theme.sizes.textBody + 2, Theme.sizes.textSmall, 7
		TITLE_RIGHT = 26
	end
	local choiceH = Scale.tapHeight(CHOICE_H, Theme.sizes.buttonDepth)
	self._choiceH = choiceH
	local cardH = PAD + TITLE_H + 6 + choiceH + PAD + BAR_H
	self._cardH = cardH
	-- the card and its X move together: the holder slides, the card fills it, the X hangs off its corner
	local holder: Frame = Create("Frame", {
		Name = "Holder",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(CARD_W, cardH),
		Visible = false,
		Parent = root,
	})
	self._holder = holder
	-- #3891: a soft dark shadow under the card, so it lifts off the world behind it
	Create("Frame", {
		Name = "Shadow",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, SHADOW),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		Parent = holder,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius + 4) }),
	})
	local card: Frame = Create("Frame", {
		Name = "Card",
		BackgroundColor3 = Theme.modal.panel,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
		Parent = holder,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius + 4) }),
	})
	Outline.border(card, Theme.sizes.outline + 2)
	self._card = card
	-- #3891: the gold band behind the title (the card's rounded top clips it)
	self._band = Create("Frame", {
		Name = "Band",
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, PAD + TITLE_H + 3),
		Parent = card,
	})
	self._title = Create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(PAD, PAD),
		Size = UDim2.new(1, -2 * PAD - TITLE_RIGHT, 0, TITLE_H),
		FontFace = Theme.fonts.display,
		TextSize = TITLE_TEXT,
		TextColor3 = Theme.colors.white,
		Text = "",
		Parent = card,
	})
	Outline.text(self._title, 2)
	-- the X: a finger wide on a touch screen (Scale.tapHeight), in the close red every window uses
	local touch = Scale.isTouch()
	local side = if touch then Theme.sizes.touchMin else 36 -- the UI gate's desktop minimum
	local tall = Scale.tapHeight(side, Theme.sizes.buttonDepth)
	local wide = math.max(side, tall - Theme.sizes.buttonDepth)
	self._close = Button.new({
		name = "Close",
		text = "X",
		style = "close",
		size = UDim2.fromOffset(wide, tall),
		anchorPoint = Vector2.new(0.5, 0.5),
		position = UDim2.new(1, -6, 0, 4),
		textSize = Theme.sizes.textLarge,
		sound = "uiClose",
		zIndex = 4,
		parent = holder,
		onClick = function()
			self:hide("closed")
		end,
	})
	-- how far the X (centred 6 in from the right edge, with its outline) reaches over the title's line, past PAD
	self._titleInset = math.max(0, math.ceil(6 + wide / 2 + Button.OUTLINE + 2 - PAD))
	self._row = Create("Frame", {
		Name = "Choices",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(PAD, PAD + TITLE_H + 6),
		Size = UDim2.new(1, -2 * PAD, 0, choiceH),
		Parent = card,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	-- #3657: the second row of buttons, for an ask with rows = 2
	self._row2 = Create("Frame", {
		Name = "Choices2",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(PAD, PAD + TITLE_H + 6 + choiceH + GAP),
		Size = UDim2.new(1, -2 * PAD, 0, choiceH),
		Visible = false,
		Parent = card,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
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
	self._bar = Create("Frame", {
		Name = "Bar",
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = track,
	})
	self._resize = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_fit()
	end)
	self:_fit()
	return self :: AskCard
end

-- CARD_W wide, or the screen less 16 px a side when narrower.
function AskCard._fit(self: any)
	local scale = math.max(self._uiScale.Scale, 0.01)
	local width = self._holder.Parent.AbsoluteSize.X / scale
	self._holder.Size = UDim2.fromOffset(math.min(CARD_W, math.max(280, width - 32)), self._cardH)
end

-- F92: one title line or two; the buttons and the card's foot move down with it. #3657: one row of buttons or two.
function AskCard._setLines(self: any, lines: number, rows: number?)
	local two = (rows or 1) >= 2
	self._lines = lines
	self._rows = if two then 2 else 1
	local titleH = if lines >= 2 then TITLE_H * 2 - 2 else TITLE_H
	self._title.TextWrapped = lines >= 2
	local inset: number = self._titleInset or 0
	self._title.Size = UDim2.new(1, -2 * PAD - inset - TITLE_RIGHT, 0, titleH)
	self._band.Size = UDim2.new(1, 0, 0, PAD + titleH + 3)
	self._row.Position = UDim2.fromOffset(PAD, PAD + titleH + 6)
	self._row2.Position = UDim2.fromOffset(PAD, PAD + titleH + 6 + self._choiceH + GAP)
	self._row2.Visible = two
	local buttonsH = if two then self._choiceH * 2 + GAP else self._choiceH
	self._cardH = PAD + titleH + 6 + buttonsH + PAD + BAR_H
	self:_fit()
end

function AskCard._place(self: any, shown: boolean): UDim2
	local lift = self._callbacks.lift()
	return if shown then UDim2.new(0.5, 0, 1, lift) else UDim2.new(0.5, 0, 1, self._cardH + 24)
end

-- The ask's buttons, made again for each ask, sharing the row evenly. #3657: over two rows, the first half (the
-- smaller half of an odd count, so the longer words lead with more room) on top, each row sharing its own width evenly.
function AskCard._buildChoices(self: any, choices: { Choice })
	for _, button: Button.Button in self._buttons do
		button:destroy()
	end
	table.clear(self._buttons)
	local top = if self._rows >= 2 then math.floor(#choices / 2) else #choices
	for index, choice in choices do
		local id = choice.id
		local upper = index <= top
		local count = math.max(1, if upper then top else #choices - top)
		table.insert(
			self._buttons,
			Button.new({
				name = "Choice_" .. id,
				text = choice.label,
				icon = choice.icon,
				-- the glyph's clean symbol beside the label (the Invite envelope, #1136)
				image = if choice.icon
					then ShopIcons.clean(Theme.cleanGlyphs[choice.icon] or "")
					else nil,
				style = choice.style or "ghost",
				textSize = CHOICE_TEXT,
				size = UDim2.new(1 / count, -GAP * (count - 1) / count, 1, 0),
				layoutOrder = index,
				parent = if upper then self._row else self._row2,
				sound = "uiToggle",
				onClick = function()
					self:_press(id)
				end,
			})
		)
	end
end

-- Runs the ask's answer once, and its ended with how it went.
function AskCard._answer(self: any, id: string?, how: string)
	local ask: Ask? = self._ask
	self._ask = nil
	if ask ~= nil then
		ask.answer(id)
		local ended = ask.ended
		if ended ~= nil then
			ended(how)
		end
	end
end

-- #2694: the HUD's bottom row can fold, unfold or grow a line under a shown card; it moves with it.
function AskCard.follow(self: any)
	if not self._showing then
		return
	end
	local slide: Tween? = self._slide
	if slide ~= nil and slide.PlaybackState == Enum.PlaybackState.Playing then
		return
	end
	local at = self:_place(true)
	if self._holder.Position ~= at then
		self._holder.Position = at
	end
end

function AskCard.show(self: any, ask: Ask)
	if self._showing then
		self:_answer(nil, "replaced")
	end
	self._showing = true
	self._ask = ask
	self._token += 1
	local token = self._token
	self._title.Text = ask.title
	self:_setLines(ask.lines or 1, ask.rows)
	self:_buildChoices(ask.choices)
	local card: Frame = self._holder
	local wasVisible = card.Visible
	card.Visible = true
	self._close.instance.Visible = true
	if GuiService.ReducedMotionEnabled or wasVisible then
		card.Position = self:_place(true)
	else
		card.Position = self:_place(false)
		local slide = TweenService:Create(card, SLIDE, { Position = self:_place(true) })
		self._slide = slide
		slide:Play()
	end
	Sound.play("uiHint")
	local bar: Frame = self._bar
	local track: Frame = self._track
	track.Visible = ask.bar ~= false
	local old: Tween? = self._drain
	if old then
		old:Cancel()
	end
	bar.Size = UDim2.fromScale(1, 1)
	local drain = TweenService:Create(
		bar,
		TweenInfo.new(ask.seconds, Enum.EasingStyle.Linear),
		{ Size = UDim2.fromScale(0, 1) }
	)
	self._drain = drain
	drain:Play()
	task.delay(ask.seconds, function()
		if self._token == token then
			self:hide("ignored")
		end
	end)
end

function AskCard._press(self: any, id: string)
	if not self._showing or self._ask == nil then
		return
	end
	local ask: Ask = self._ask
	self._token += 1
	local token = self._token
	local drain: Tween? = self._drain
	if drain then
		drain:Cancel()
	end
	for _, button: Button.Button in self._buttons do
		button:setEnabled(false)
	end
	self._close.instance.Visible = false
	self:_answer(id, "answered")
	if self._ask ~= nil then
		return -- #3657: the answer showed the next ask on this card
	end
	local thanks = ask.thanks
	if thanks == nil then
		self:hide()
		return
	end
	self._title.Text = thanks
	task.delay(THANKS_SECONDS, function()
		if self._token == token then
			self:hide()
		end
	end)
end

function AskCard.hide(self: any, how: string?)
	if not self._showing then
		return
	end
	self:_answer(nil, how or "hidden")
	self._showing = false
	self._token += 1
	local token = self._token
	local card: Frame = self._holder
	if GuiService.ReducedMotionEnabled then
		card.Visible = false
		return
	end
	local out = TweenService:Create(card, SLIDE_OUT, { Position = self:_place(false) })
	out.Completed:Once(function()
		if self._token == token then
			card.Visible = false
		end
	end)
	out:Play()
end

function AskCard.isShowing(self: any): boolean
	return self._showing
end

function AskCard.destroy(self: any)
	self._token += 1
	self._ask = nil
	self._resize:Disconnect()
	for _, button: Button.Button in self._buttons do
		button:destroy()
	end
	self._close:destroy()
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return AskCard
