--!strict
-- #4437: the Money boost card the HUD's "2x Money" button opens on its first tap of a session (Components/
-- MoneyCardLogic has the rules and the words). A small MenuFamily window: the pass picture on the left; on the right
-- "Now" with the cafe's money a minute today and "With 2x Money" with the money a minute with the pass, in green; a
-- Buy button with the price across the foot and the window's X. Buy opens Roblox's prompt; the X just closes. No
-- countdown, no timer bar.

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local MenuFamily = require(script.Parent.Parent.Components.MenuFamily)
local MoneyCardLogic = require(script.Parent.Parent.Components.MoneyCardLogic)
local Panel = require(script.Parent.Parent.Components.Panel)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)

local PAL = MenuFamily.pal

export type Callbacks = {
	buy: () -> (),
	close: () -> (),
}

export type MoneyCard = {
	frame: Frame,
	render: (self: MoneyCard, view: MoneyCardLogic.View, picture: string?) -> (),
	destroy: (self: MoneyCard) -> (),
}

local MAX_SIZE = Vector2.new(440, 300)
local GAP = 10
local LABEL_H = 18
local VALUE_H = 30
local PICTURE_SHARE = 0.36 -- of the content's width

local MoneyCard = {}
MoneyCard.__index = MoneyCard

local function text(
	name: string,
	size: number,
	color: Color3,
	height: number,
	order: number,
	parent: Instance
): TextLabel
	return Create("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height),
		FontFace = if size >= Theme.sizes.textLarge then Theme.fonts.display else Theme.fonts.body,
		TextSize = size,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = order,
		Text = "",
		Parent = parent,
	})
end

function MoneyCard.new(callbacks: Callbacks): MoneyCard
	local self = setmetatable({}, MoneyCard) :: any
	local panel = Panel.new({
		dark = true,
		name = "MoneyCard",
		title = "2x Money",
		subtitle = MoneyCardLogic.SUBTITLE,
		color = Color3.fromHex("3DBF3F"),
		icon = "💰",
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = MAX_SIZE, Parent = panel.frame })
	panel.frame.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.frame.Position = UDim2.fromScale(0.5, 0.5)
	self._panel = panel
	self.frame = panel.frame
	local content = panel.content
	local buyH = Scale.tapHeight(Theme.sizes.touchMin, Theme.sizes.buttonDepth)
	local upper = UDim2.new(1, 0, 1, -(buyH + GAP))
	local top: Frame = Create("Frame", {
		Name = "Top",
		BackgroundTransparency = 1,
		Size = upper,
		Parent = content,
	})
	self._picture = Create("ImageLabel", {
		Name = "Picture",
		BackgroundColor3 = PAL.card,
		Size = UDim2.new(PICTURE_SHARE, 0, 1, 0),
		ScaleType = Enum.ScaleType.Fit,
		Image = "",
		Parent = top,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 12) }),
		Create("UIAspectRatioConstraint", { AspectRatio = 1 }),
		Create("UIPadding", {
			PaddingTop = UDim.new(0.06, 0),
			PaddingBottom = UDim.new(0.06, 0),
			PaddingLeft = UDim.new(0.06, 0),
			PaddingRight = UDim.new(0.06, 0),
		}),
	})
	local words: Frame = Create("Frame", {
		Name = "Words",
		BackgroundTransparency = 1,
		Position = UDim2.new(PICTURE_SHARE, GAP, 0, 0),
		Size = UDim2.new(1 - PICTURE_SHARE, -GAP, 1, 0),
		Parent = top,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2),
		}),
	})
	self._nowLabel = text("NowLabel", Theme.sizes.textSmall, PAL.subtext, LABEL_H, 1, words)
	self._nowLabel.Text = "Now"
	self._now = text("Now", Theme.sizes.textLarge, PAL.text, VALUE_H, 2, words)
	self._withLabel = text("WithLabel", Theme.sizes.textSmall, PAL.gold, LABEL_H, 3, words)
	self._with = text("With", Theme.sizes.textLarge, PAL.good, VALUE_H, 4, words)
	self._plain = text("Plain", Theme.sizes.textBody, PAL.text, VALUE_H * 2, 5, words)
	self._plain.TextWrapped = true
	self._plain.TextTruncate = Enum.TextTruncate.None
	self._buy = Button.new({
		name = "Buy",
		text = "Buy",
		style = "primary",
		size = UDim2.new(1, 0, 0, buyH),
		position = UDim2.new(0, 0, 1, -buyH),
		textSize = Theme.sizes.textBody,
		parent = content,
		onClick = function()
			callbacks.buy()
		end,
	})
	return self :: MoneyCard
end

function MoneyCard.render(self: any, view: MoneyCardLogic.View, picture: string?)
	self._panel:setTitle(view.title, view.subtitle)
	self._picture.Image = picture or ""
	self._picture.Visible = picture ~= nil
	local numbers = view.now ~= nil and view.with ~= nil
	self._nowLabel.Visible = numbers
	self._now.Visible = numbers
	self._withLabel.Visible = numbers
	self._with.Visible = numbers
	self._now.Text = view.now or ""
	self._with.Text = view.with or ""
	self._withLabel.Text = view.withLabel
	self._plain.Visible = not numbers
	self._plain.Text = view.plain or ""
	self._buy:setText(view.buy)
end

function MoneyCard.destroy(self: any)
	self._panel:destroy()
end

return MoneyCard
