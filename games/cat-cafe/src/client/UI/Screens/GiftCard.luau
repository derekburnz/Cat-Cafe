--!strict
-- The like and favourite gift cards (#1947, like-prompts.md section 2): a small card in the middle of the screen with
-- a thank-you line, on the like card a drawing of the game page with a cursor on its 👍 (#3171), "Gift added!" over the gift's pictures (coins and potions, at most two pictures, F94) and two
-- buttons of the same size, "How to like" or "Favorite" and Close (#2705: the like card on touch has Got it alone). The gift was paid before the card came, so Close
-- keeps it. There is no backdrop, countdown or guilt line, and the card never comes back. The words are
-- Components/GiftCardLogic's.
--   show(kind, prize, onButton)   onButton(button) once: the first button's name ("like" or "favourite"), "close",
--                                 or nil when the card goes without a press (hide, a new card, destroy)
--   showAfter()                   the first button was pressed: its thank-you words and Close alone
--   hide()
--   isShowing() -> boolean
-- #2968 (console pass 2): on a gamepad the card takes the selection as it shows (GamepadNav.focus), B closes it as
-- Close does, and the selection from before comes back when it goes.

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local GamepadNav = require(script.Parent.Parent.Components.GamepadNav)
local GiftCardLogic = require(script.Parent.Parent.Components.GiftCardLogic)
local LikePicture = require(script.Parent.Parent.Components.LikePicture)
local Outline = require(script.Parent.Parent.Components.Outline)
local PrizeChips = require(script.Parent.Parent.Components.PrizeChips)
local Scale = require(script.Parent.Parent.Scale)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

export type GiftCard = {
	screenGui: ScreenGui,
	show: (
		self: GiftCard,
		kind: GiftCardLogic.Kind,
		prize: Types.IndexPrize,
		onButton: (button: string?) -> ()
	) -> (),
	showAfter: (self: GiftCard) -> (),
	hide: (self: GiftCard) -> (),
	isShowing: (self: GiftCard) -> boolean,
	destroy: (self: GiftCard) -> (),
}

local CARD_W = 400
local PAD = 16
local TITLE_H = 34
local BODY_TEXT = Theme.sizes.textBody + 1 -- #1981: 15 px regular body text was hard to read on the beige panel
local LINE_H = BODY_TEXT + 7
local GIFT_H = 70 -- "Gift added!" and the pictures under it
local TILE = 34
local GAP = 10
local POP = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local GiftCard = {}
GiftCard.__index = GiftCard

function GiftCard.new(parent: Instance): GiftCard
	local self = setmetatable({}, GiftCard) :: any
	self._onButton = nil :: ((button: string?) -> ())?
	self._single = false -- #2705: Got it alone
	self._kind = "like" :: GiftCardLogic.Kind
	self._focused = false -- #2968: the card took the gamepad selection; hide hands `_before` back
	self._before = nil :: GuiObject?

	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeGift",
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
	self._root = root

	local card: Frame = Create("Frame", {
		Name = "Card",
		BackgroundColor3 = Theme.modal.panel,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(CARD_W, 240),
		Visible = false,
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius + 4) }),
	})
	Outline.border(card, Theme.sizes.outline + 1)
	self._card = card
	self._pop = Create("UIScale", { Parent = card }) :: UIScale

	local title: TextLabel = Create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(PAD, PAD - 4),
		Size = UDim2.new(1, -PAD * 2, 0, TITLE_H),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 6,
		-- #1981: plain dark ink on the light panel; a black outline round dark words made them muddy
		TextColor3 = Theme.modal.text,
		Text = "",
		Parent = card,
	})
	self._title = title
	self._body = Create("TextLabel", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(PAD, PAD + TITLE_H),
		Size = UDim2.new(1, -PAD * 2, 0, LINE_H * 2),
		FontFace = Theme.fonts.bodyBold,
		TextSize = BODY_TEXT,
		TextColor3 = Theme.modal.text,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
		Parent = card,
	}) :: TextLabel

	-- #3171: the like card's drawing of the game page, a big cursor on its 👍
	local pictureHolder: Frame = Create("Frame", {
		Name = "PictureHolder",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -PAD * 2, 0, LikePicture.PICTURE_H),
		Visible = false,
		Parent = card,
	})
	self._pictureHolder = pictureHolder
	self._picture = LikePicture.new(pictureHolder)

	local gift: Frame = Create("Frame", {
		Name = "Gift",
		-- #1981: dark cocoa, so the white outlined words and amounts stand out (on caramel they were faint)
		BackgroundColor3 = Theme.colors.cocoaDeep,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -PAD * 2, 0, GIFT_H),
		Parent = card,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2),
		}),
	})
	self._gift = gift
	local added: TextLabel = Create("TextLabel", {
		Name = "Added",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.colors.gold,
		Text = "🎁 " .. GiftCardLogic.GIFT_LINE,
		LayoutOrder = 1,
		Parent = gift,
	})
	Outline.text(added, 1.5)
	self._chips = PrizeChips.new({
		parent = gift,
		name = "Prize",
		tile = TILE,
		textSize = Theme.sizes.textSmall,
		outlined = true,
		maxPictures = 2,
		showBonus = false,
		layoutOrder = 2,
	})

	local row: Frame = Create("Frame", {
		Name = "Buttons",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -PAD * 2, 0, Theme.sizes.touchMin),
		Parent = card,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, GAP),
		}),
	})
	self._row = row
	-- the two buttons are the same size, so Close is as easy to press as the ask (like-prompts.md section 2)
	-- sized in design px tall, so on a touch screen each Hit pad reaches a finger's 44 real px
	local half = UDim2.new(0.5, -GAP / 2, 0, Theme.sizes.touchMin)
	self._action = Button.new({
		name = "Action",
		text = "",
		style = "primary",
		size = half,
		textSize = Theme.sizes.textBody,
		layoutOrder = 1,
		parent = row,
		onClick = function()
			if self._single then
				self:_press(GiftCardLogic.GOT_IT_BUTTON) -- #2705: the like card on touch closes
				self:hide()
				return
			end
			self:_press(GiftCardLogic.TEXT[self._kind].button)
		end,
	})
	self._closeButton = Button.new({
		name = "Close",
		text = GiftCardLogic.CLOSE,
		style = "secondary",
		size = half,
		textSize = Theme.sizes.textBody,
		layoutOrder = 2,
		parent = row,
		onClick = function()
			self:_press(GiftCardLogic.CLOSE_BUTTON)
			self:hide()
		end,
	})

	self._resize = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if card.Visible then
			self:_layout()
		end
	end)
	-- #2968: B closes the card while the selection is on it (or on nothing), as Close does
	self._back = UserInputService.InputBegan:Connect(function(input: InputObject)
		if input.KeyCode ~= Enum.KeyCode.ButtonB or not card.Visible then
			return
		end
		local selected = GuiService.SelectedObject
		if selected == nil or selected:IsDescendantOf(card) then
			self:_press(GiftCardLogic.CLOSE_BUTTON)
			self:hide()
		end
	end)
	return self :: GiftCard
end

-- The card is CARD_W wide, or the screen less 16 px a side; the body takes as many rows as its words need.
function GiftCard._layout(self: any)
	local scale = math.max(self._uiScale.Scale, 0.01)
	local width = math.min(CARD_W, math.max(280, self._root.AbsoluteSize.X / scale - 32))
	local body: TextLabel = self._body
	-- about 0.5 em a character in the bold body font
	local rows = math.clamp(math.ceil(#body.Text * BODY_TEXT * 0.5 / (width - PAD * 2)), 1, 4)
	local bodyH = LINE_H * rows
	local y = PAD + TITLE_H
	body.Size = UDim2.new(1, -PAD * 2, 0, bodyH)
	y += bodyH + GAP
	local holder: Frame = self._pictureHolder
	if holder.Visible then
		holder.Position = UDim2.fromOffset(PAD, y)
		y += LikePicture.PICTURE_H + GAP
	end
	self._gift.Position = UDim2.fromOffset(PAD, y)
	y += GIFT_H + GAP + 2
	self._row.Position = UDim2.fromOffset(PAD, y)
	y += Theme.sizes.touchMin + PAD
	self._card.Size = UDim2.fromOffset(width, y)
end

function GiftCard.show(
	self: any,
	kind: GiftCardLogic.Kind,
	prize: Types.IndexPrize,
	onButton: (button: string?) -> ()
)
	self:_finish(nil)
	local text = GiftCardLogic.TEXT[kind]
	self._kind = kind
	self._onButton = onButton
	self._title.Text = text.icon .. " " .. text.title
	self._body.Text = text.body
	-- #2705: the like card on touch has Got it alone, the whole row wide
	local single = GiftCardLogic.single(kind, Scale.isTouch())
	self._single = single
	self._action:setText(if single then GiftCardLogic.GOT_IT else text.action)
	self._action.instance.Visible = true
	self._action.instance.Size = if single
		then UDim2.new(1, 0, 0, Theme.sizes.touchMin)
		else UDim2.new(0.5, -GAP / 2, 0, Theme.sizes.touchMin)
	self._closeButton.instance.Visible = not single
	self._closeButton.instance.Size = UDim2.new(0.5, -GAP / 2, 0, Theme.sizes.touchMin)
	self._chips:set(prize)
	-- #3171: the like card shows where the 👍 is on the game's page
	local picture = kind == "like"
	self._pictureHolder.Visible = picture
	if picture then
		self._picture:play()
	else
		self._picture:stop()
	end
	self:_layout()
	local card: Frame = self._card
	card.Visible = true
	if GuiService.ReducedMotionEnabled then
		self._pop.Scale = 1
	else
		self._pop.Scale = 0.6
		TweenService:Create(self._pop, POP, { Scale = 1 }):Play()
	end
	if not self._focused then
		local before, took = GamepadNav.focus(card)
		self._focused, self._before = took, before
	end
	Sound.play("giftClaim")
end

-- #2968: Close's own button face, for the selection once the first button has gone (GamepadNav skips a Close).
function GiftCard._closeFace(self: any): GuiButton?
	for _, piece in self._closeButton.instance:GetDescendants() do
		if piece:IsA("GuiButton") and (piece :: GuiButton).Selectable then
			return piece :: GuiButton
		end
	end
	return nil
end

-- The first button was pressed: its thank-you words, and Close alone in the middle.
function GiftCard.showAfter(self: any)
	if not self._card.Visible then
		return
	end
	self._body.Text = GiftCardLogic.TEXT[self._kind].after
	self._action.instance.Visible = false
	self._closeButton.instance.Size = UDim2.new(0.5, -GAP / 2, 0, Theme.sizes.touchMin)
	self:_layout()
	-- #2968: the selection was on the first button, which has gone; Close takes it
	local selected = GuiService.SelectedObject
	if self._focused and (selected == nil or selected:IsDescendantOf(self._action.instance)) then
		GuiService.SelectedObject = self:_closeFace()
	end
end

-- The first press reports; a later one (Close after Like) does not.
function GiftCard._press(self: any, button: string)
	self:_finish(button)
end

function GiftCard._finish(self: any, button: string?)
	local onButton: ((button: string?) -> ())? = self._onButton
	if onButton == nil then
		return
	end
	self._onButton = nil
	onButton(button)
end

function GiftCard.hide(self: any)
	self:_finish(nil)
	self._picture:stop()
	self._card.Visible = false
	if self._focused then
		self._focused = false
		local selected = GuiService.SelectedObject
		if selected == nil or selected:IsDescendantOf(self._card) then
			GamepadNav.restore(self._before)
		end
		self._before = nil
	end
end

function GiftCard.isShowing(self: any): boolean
	return self._card.Visible
end

function GiftCard.destroy(self: any)
	self:_finish(nil)
	self._resize:Disconnect()
	self._back:Disconnect()
	self._action:destroy()
	self._closeButton:destroy()
	self._chips:destroy()
	self._picture:destroy()
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return GiftCard
