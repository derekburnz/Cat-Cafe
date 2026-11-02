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
--   hide()         slides it away, answering nil
--   isShowing() -> boolean
-- An ask's answer(id) runs once: the id of the button pressed, or nil when it drained, was hidden or was replaced.

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local Scale = require(script.Parent.Parent.Scale)
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
	answer: (id: string?) -> (),
}

export type Callbacks = {
	lift: () -> number, -- the HUD's bottomTop(): the card's foot sits this far over the screen's bottom (negative)
}

export type AskCard = {
	screenGui: ScreenGui,
	show: (self: AskCard, ask: Ask) -> (),
	hide: (self: AskCard) -> (),
	isShowing: (self: AskCard) -> boolean,
	destroy: (self: AskCard) -> (),
}

local CARD_W = 460
local TITLE_H = 30
local CHOICE_H = 50
local PAD = 12
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

	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeAsk",
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

	local choiceH = Scale.tapHeight(CHOICE_H, Theme.sizes.buttonDepth)
	self._choiceH = choiceH
	local cardH = PAD + TITLE_H + 6 + choiceH + PAD + BAR_H
	self._cardH = cardH
	local card: Frame = Create("Frame", {
		Name = "Card",
		BackgroundColor3 = Theme.modal.panel,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(CARD_W, cardH),
		ClipsDescendants = true,
		Visible = false,
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius + 4) }),
	})
	Outline.border(card, Theme.sizes.outline + 1)
	self._card = card
	self._title = Create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(PAD, PAD),
		Size = UDim2.new(1, -2 * PAD, 0, TITLE_H),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextColor3 = Theme.modal.text,
		Text = "",
		Parent = card,
	})
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
	local track: Frame = Create("Frame", {
		Name = "Track",
		BackgroundColor3 = Theme.colors.line,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, BAR_H),
		Parent = card,
	})
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
	local width = self._card.Parent.AbsoluteSize.X / scale
	self._card.Size = UDim2.fromOffset(math.min(CARD_W, math.max(280, width - 32)), self._cardH)
end

-- F92: one title line or two; the buttons and the card's foot move down with it.
function AskCard._setLines(self: any, lines: number)
	local titleH = if lines >= 2 then TITLE_H * 2 - 2 else TITLE_H
	self._title.TextWrapped = lines >= 2
	self._title.Size = UDim2.new(1, -2 * PAD, 0, titleH)
	self._row.Position = UDim2.fromOffset(PAD, PAD + titleH + 6)
	self._cardH = PAD + titleH + 6 + self._choiceH + PAD + BAR_H
	self:_fit()
end

function AskCard._place(self: any, shown: boolean): UDim2
	local lift = self._callbacks.lift()
	return if shown then UDim2.new(0.5, 0, 1, lift) else UDim2.new(0.5, 0, 1, self._cardH + 24)
end

-- The ask's buttons, made again for each ask, sharing the row evenly.
function AskCard._buildChoices(self: any, choices: { Choice })
	for _, button: Button.Button in self._buttons do
		button:destroy()
	end
	table.clear(self._buttons)
	local count = math.max(1, #choices)
	for index, choice in choices do
		local id = choice.id
		table.insert(
			self._buttons,
			Button.new({
				name = "Choice_" .. id,
				text = choice.label,
				icon = choice.icon,
				style = choice.style or "ghost",
				textSize = Theme.sizes.textBody,
				size = UDim2.new(1 / count, -GAP * (count - 1) / count, 1, 0),
				layoutOrder = index,
				parent = self._row,
				sound = "uiToggle",
				onClick = function()
					self:_press(id)
				end,
			})
		)
	end
end

-- Runs the ask's answer once.
function AskCard._answer(self: any, id: string?)
	local ask: Ask? = self._ask
	self._ask = nil
	if ask ~= nil then
		ask.answer(id)
	end
end

function AskCard.show(self: any, ask: Ask)
	if self._showing then
		self:_answer(nil)
	end
	self._showing = true
	self._ask = ask
	self._token += 1
	local token = self._token
	self._title.Text = ask.title
	self:_setLines(ask.lines or 1)
	self:_buildChoices(ask.choices)
	local card: Frame = self._card
	local wasVisible = card.Visible
	card.Visible = true
	if GuiService.ReducedMotionEnabled or wasVisible then
		card.Position = self:_place(true)
	else
		card.Position = self:_place(false)
		TweenService:Create(card, SLIDE, { Position = self:_place(true) }):Play()
	end
	Sound.play("uiHint")
	local bar: Frame = self._bar
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
			self:hide()
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
	self:_answer(id)
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

function AskCard.hide(self: any)
	if not self._showing then
		return
	end
	self:_answer(nil)
	self._showing = false
	self._token += 1
	local token = self._token
	local card: Frame = self._card
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
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return AskCard
