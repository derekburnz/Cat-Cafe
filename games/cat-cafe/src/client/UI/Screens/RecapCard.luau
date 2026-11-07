--!strict
-- The session recap card (#1920, first-hour.md section 6): once a session, a small card slides up from the bottom
-- centre with "Your cafe so far" and up to four lines (Components/RecapLogic), leading with what's next. There is no
-- dark backdrop, no countdown bar and no store link: an X closes it and it slides away by itself after
-- RecapLogic.AUTO_HIDE seconds. Leaving the game loses nothing, so nothing here says otherwise.
--   show(lines, onClosed)   onClosed(secondsUp) once the card has gone, closed or timed out
--   hide()
--   isShowing() -> boolean

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local RecapLogic = require(script.Parent.Parent.Components.RecapLogic)
local Scale = require(script.Parent.Parent.Scale)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)

export type RecapCard = {
	screenGui: ScreenGui,
	show: (self: RecapCard, lines: { string }, onClosed: (secondsUp: number) -> ()) -> (),
	hide: (self: RecapCard) -> (),
	isShowing: (self: RecapCard) -> boolean,
	destroy: (self: RecapCard) -> (),
}

local CARD_W = 380
local BOTTOM = 92 -- over the bottom row of HUD buttons
local PAD = 14
local TITLE_H = 30
local LINE_H = 24
local GAP = 4
local SLIDE = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SLIDE_OUT = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local RecapCard = {}
RecapCard.__index = RecapCard

function RecapCard.new(parent: Instance): RecapCard
	local self = setmetatable({}, RecapCard) :: any
	self._token = 0
	self._onClosed = nil :: ((secondsUp: number) -> ())?
	self._shownAt = 0
	self._labels = {} :: { TextLabel }

	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeRecap",
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

	local card: Frame = Create("Frame", {
		Name = "Card",
		BackgroundColor3 = Theme.modal.panel,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -BOTTOM),
		Size = UDim2.fromOffset(CARD_W, TITLE_H + PAD * 2),
		Visible = false,
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius + 4) }),
	})
	Outline.border(card, Theme.sizes.outline + 1)
	self._card = card

	local title: TextLabel = Create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(PAD, PAD - 4),
		Size = UDim2.new(1, -(PAD * 2 + Theme.sizes.touchMin), 0, TITLE_H),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 4,
		TextColor3 = Theme.modal.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = RecapLogic.TITLE,
		Parent = card,
	})
	Outline.text(title, 1.5)
	self._closeButton = Button.new({
		name = "Close",
		text = "X",
		style = "close",
		size = UDim2.fromOffset(Theme.sizes.touchMin, Theme.sizes.touchMin),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, -6, 0, 6),
		textSize = Theme.sizes.textLarge,
		zIndex = 3,
		parent = card,
		onClick = function()
			self:hide()
		end,
	})
	for index = 1, RecapLogic.MAX_LINES do
		self._labels[index] = Create("TextLabel", {
			Name = "Line" .. index,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(PAD, PAD + TITLE_H + 4),
			Size = UDim2.new(1, -PAD * 2, 0, LINE_H),
			FontFace = Theme.fonts.body,
			TextSize = Theme.sizes.textSmall + 1,
			TextColor3 = Theme.modal.text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			Text = "",
			Visible = false,
			Parent = card,
		})
	end

	self._resize = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if self._onClosed ~= nil then
			self:_layout()
		end
	end)
	return self :: RecapCard
end

-- The card is CARD_W wide, or the screen less 16 px a side; a line that wraps takes up to three rows.
function RecapCard._layout(self: any)
	local scale = math.max(self._uiScale.Scale, 0.01)
	local width = math.min(CARD_W, math.max(260, self._card.Parent.AbsoluteSize.X / scale - 32))
	local y = PAD + TITLE_H + 4
	for _, label: TextLabel in self._labels do
		if label.Visible then
			-- about 6 px a character at this size; #2123 counts 7 so a line just short of the width (the offline share
			-- on its own) gets its second row
			local rows = math.clamp(math.ceil(#label.Text * 7 / (width - PAD * 2)), 1, 3)
			local height = LINE_H * rows - (rows - 1) * 4
			label.Position = UDim2.fromOffset(PAD, y)
			label.Size = UDim2.new(1, -PAD * 2, 0, height)
			y += height + GAP
		end
	end
	self._card.Size = UDim2.fromOffset(width, y - GAP + PAD)
end

function RecapCard.show(self: any, lines: { string }, onClosed: (secondsUp: number) -> ())
	if self._onClosed ~= nil then
		self:_close()
	end
	self._token += 1
	local token = self._token
	self._onClosed = onClosed
	self._shownAt = os.clock()
	for index, label in self._labels do
		local line = lines[index]
		label.Visible = line ~= nil
		label.Text = line or ""
	end
	self:_layout()
	local card: Frame = self._card
	card.Visible = true
	local shown = UDim2.new(0.5, 0, 1, -BOTTOM)
	if GuiService.ReducedMotionEnabled then
		card.Position = shown
	else
		card.Position = UDim2.new(0.5, 0, 1, card.Size.Y.Offset + 20)
		TweenService:Create(card, SLIDE, { Position = shown }):Play()
	end
	Sound.play("uiHint")
	task.delay(RecapLogic.AUTO_HIDE, function()
		if self._token == token then
			self:_close()
		end
	end)
end

function RecapCard._close(self: any)
	local onClosed: ((secondsUp: number) -> ())? = self._onClosed
	if onClosed == nil then
		return
	end
	self._onClosed = nil
	self._token += 1
	local token = self._token
	local card: Frame = self._card
	if GuiService.ReducedMotionEnabled then
		card.Visible = false
	else
		local out = TweenService:Create(
			card,
			SLIDE_OUT,
			{ Position = UDim2.new(0.5, 0, 1, card.Size.Y.Offset + 20) }
		)
		out.Completed:Once(function()
			if self._token == token then
				card.Visible = false
			end
		end)
		out:Play()
	end
	onClosed(math.floor(os.clock() - self._shownAt + 0.5))
end

function RecapCard.hide(self: any)
	self:_close()
end

function RecapCard.isShowing(self: any): boolean
	return self._onClosed ~= nil
end

function RecapCard.destroy(self: any)
	self._token += 1
	self._onClosed = nil
	self._resize:Disconnect()
	self._closeButton:destroy()
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return RecapCard
