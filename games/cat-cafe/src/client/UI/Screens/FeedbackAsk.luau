--!strict
-- The one slide-in feedback ask (F87, easy-start.md section 4): once per account, after FeedbackAskMinutes of play
-- in a session and only between activities (init decides when, Components/FeedbackLogic.askDue), the three faces
-- slide up at the bottom centre over the travel row with "How is it so far?". A gold bar drains over
-- FeedbackLogic.ASK_SECONDS (10) and it slides away. A face tap sends at once (callbacks.send), says "Thanks!" and
-- slides away. Ignoring it is fine and it never comes back. No reward, so the answers stay honest.
--   show()        slides it up
--   isShowing() -> boolean

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local FeedbackLogic = require(script.Parent.Parent.Components.FeedbackLogic)
local Outline = require(script.Parent.Parent.Components.Outline)
local Scale = require(script.Parent.Parent.Scale)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)

export type Callbacks = {
	send: (face: string) -> (),
	lift: () -> number, -- the HUD's bottomTop(): the card's foot sits this far over the screen's bottom (negative)
}

export type FeedbackAsk = {
	screenGui: ScreenGui,
	show: (self: FeedbackAsk) -> (),
	isShowing: (self: FeedbackAsk) -> boolean,
	destroy: (self: FeedbackAsk) -> (),
}

local CARD_W = 460
local TITLE_H = 30
local FACE_H = 50
local PAD = 12
local GAP = 8
local BAR_H = 5
local THANKS_SECONDS = 1.5
local SLIDE = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SLIDE_OUT = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local TITLE = "How is it so far?"

local FeedbackAsk = {}
FeedbackAsk.__index = FeedbackAsk

function FeedbackAsk.new(parent: Instance, callbacks: Callbacks): FeedbackAsk
	local self = setmetatable({}, FeedbackAsk) :: any
	self._callbacks = callbacks
	self._token = 0
	self._showing = false
	self._buttons = {} :: { Button.Button }

	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeFeedbackAsk",
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

	local faceH = Scale.tapHeight(FACE_H, Theme.sizes.buttonDepth)
	local cardH = PAD + TITLE_H + 6 + faceH + PAD + BAR_H
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
		Text = TITLE,
		Parent = card,
	})
	local row: Frame = Create("Frame", {
		Name = "Faces",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(PAD, PAD + TITLE_H + 6),
		Size = UDim2.new(1, -2 * PAD, 0, faceH),
		Parent = card,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local count = #FeedbackLogic.FACES
	for index, face in FeedbackLogic.FACES do
		local id = face.id
		table.insert(
			self._buttons,
			Button.new({
				name = "Face_" .. id,
				text = face.label,
				icon = face.glyph,
				style = "ghost",
				textSize = Theme.sizes.textBody,
				size = UDim2.new(1 / count, -GAP * (count - 1) / count, 1, 0),
				layoutOrder = index,
				parent = row,
				sound = "uiToggle",
				onClick = function()
					self:_answer(id)
				end,
			})
		)
	end
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
	return self :: FeedbackAsk
end

-- CARD_W wide, or the screen less 16 px a side when narrower.
function FeedbackAsk._fit(self: any)
	local scale = math.max(self._uiScale.Scale, 0.01)
	local width = self._card.Parent.AbsoluteSize.X / scale
	self._card.Size = UDim2.fromOffset(math.min(CARD_W, math.max(280, width - 32)), self._cardH)
end

function FeedbackAsk._place(self: any, shown: boolean): UDim2
	local lift = self._callbacks.lift()
	return if shown then UDim2.new(0.5, 0, 1, lift) else UDim2.new(0.5, 0, 1, self._cardH + 24)
end

function FeedbackAsk.show(self: any)
	if self._showing then
		return
	end
	self._showing = true
	self._token += 1
	local token = self._token
	self._title.Text = TITLE
	for _, button: Button.Button in self._buttons do
		button:setEnabled(true)
	end
	local card: Frame = self._card
	card.Visible = true
	if GuiService.ReducedMotionEnabled then
		card.Position = self:_place(true)
	else
		card.Position = self:_place(false)
		TweenService:Create(card, SLIDE, { Position = self:_place(true) }):Play()
	end
	Sound.play("uiHint")
	local bar: Frame = self._bar
	bar.Size = UDim2.fromScale(1, 1)
	local drain = TweenService:Create(
		bar,
		TweenInfo.new(FeedbackLogic.ASK_SECONDS, Enum.EasingStyle.Linear),
		{ Size = UDim2.fromScale(0, 1) }
	)
	self._drain = drain
	drain:Play()
	task.delay(FeedbackLogic.ASK_SECONDS, function()
		if self._token == token then
			self:_hide()
		end
	end)
end

function FeedbackAsk._answer(self: any, face: string)
	if not self._showing then
		return
	end
	self._token += 1
	local token = self._token
	local drain: Tween? = self._drain
	if drain then
		drain:Cancel()
	end
	for _, button: Button.Button in self._buttons do
		button:setEnabled(false)
	end
	self._title.Text = "Thanks!"
	self._callbacks.send(face)
	task.delay(THANKS_SECONDS, function()
		if self._token == token then
			self:_hide()
		end
	end)
end

function FeedbackAsk._hide(self: any)
	if not self._showing then
		return
	end
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

function FeedbackAsk.isShowing(self: any): boolean
	return self._showing
end

function FeedbackAsk.destroy(self: any)
	self._token += 1
	self._resize:Disconnect()
	for _, button: Button.Button in self._buttons do
		button:destroy()
	end
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return FeedbackAsk
