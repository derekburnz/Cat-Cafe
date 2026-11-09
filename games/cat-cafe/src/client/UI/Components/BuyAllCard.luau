--!strict
-- #2593: the "Buy all?" confirm card over a shop window (the Night Dealer's look, #2573): a dim cover over the window,
-- and on it a card with the title, what it buys, the total and the coins left after, "You can afford n of m" when it
-- can't take everything, and Cancel and Buy.
--
--   BuyAllCard.new(parent, onBuy)              hidden until show; onBuy runs once per Buy and the card hides
--   card:show(title, list, sums, partial?)     fills it and shows it; again while up to refresh the words
--   card:hide()   card:visible() -> boolean   card:destroy()

local Button = require(script.Parent.Button)
local Create = require(script.Parent.Create)
local Outline = require(script.Parent.Outline)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)

local PAL = Theme.dark
local BUTTON = Vector2.new(124, 44)

export type BuyAllCard = {
	show: (self: BuyAllCard, title: string, list: string, sums: string, partial: string?) -> (),
	hide: (self: BuyAllCard) -> (),
	visible: (self: BuyAllCard) -> boolean,
	destroy: (self: BuyAllCard) -> (),
}

local BuyAllCard = {}
BuyAllCard.__index = BuyAllCard

local function line(card: Frame, name: string, order: number, props: { [string]: any }): TextLabel
	local label: TextLabel = Create("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textBody,
		TextColor3 = PAL.text,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = order,
		ZIndex = 22,
		Text = "",
		Parent = card,
	})
	for key, value in props do
		(label :: any)[key] = value
	end
	return label
end

function BuyAllCard.new(parent: Instance, onBuy: () -> ()): BuyAllCard
	local self = setmetatable({}, BuyAllCard) :: any
	local cover: TextButton = Create("TextButton", {
		Name = "BuyAllCover",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 20,
		Parent = parent,
	})
	local card: Frame = Create("Frame", {
		Name = "Card",
		BackgroundColor3 = PAL.card,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -40, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 21,
		Parent = cover,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UISizeConstraint", { MaxSize = Vector2.new(440, math.huge) }),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 16),
			PaddingTop = UDim.new(0, 14),
			PaddingBottom = UDim.new(0, 14),
		}),
		Create("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	})
	Outline.border(card, Theme.sizes.outline)
	self._title = line(card, "Title", 1, {
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextColor3 = Theme.colors.white,
	})
	Outline.text(self._title, 2)
	self._list = line(card, "List", 2, {})
	self._sums =
		line(card, "Sums", 3, { FontFace = Theme.fonts.display, TextColor3 = Theme.colors.gold })
	self._partial =
		line(card, "Partial", 4, { TextSize = Theme.sizes.textSmall, TextColor3 = PAL.subtext })
	local height = Scale.tapHeight(BUTTON.Y, Theme.sizes.buttonDepth)
	local buttons: Frame = Create("Frame", {
		Name = "Buttons",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height),
		LayoutOrder = 5,
		ZIndex = 22,
		Parent = card,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._cancel = Button.new({
		name = "Cancel",
		text = "Cancel",
		style = "ghost",
		size = UDim2.fromOffset(BUTTON.X, height),
		textSize = Theme.sizes.textBody,
		layoutOrder = 1,
		zIndex = 23,
		parent = buttons,
		onClick = function()
			self:hide()
		end,
	})
	self._buy = Button.new({
		name = "Buy",
		text = "Buy",
		style = "gold",
		size = UDim2.fromOffset(BUTTON.X, height),
		textSize = Theme.sizes.textBody,
		layoutOrder = 2,
		zIndex = 23,
		parent = buttons,
		onClick = function()
			if cover.Visible then
				self:hide()
				onBuy()
			end
		end,
	})
	self._cover = cover
	return self :: BuyAllCard
end

function BuyAllCard.show(self: any, title: string, list: string, sums: string, partial: string?)
	self._title.Text = title
	self._list.Text = list
	self._sums.Text = sums
	self._partial.Text = partial or ""
	self._partial.Visible = partial ~= nil
	self._cover.Visible = true
end

function BuyAllCard.hide(self: any)
	self._cover.Visible = false
end

function BuyAllCard.visible(self: any): boolean
	return self._cover.Visible
end

function BuyAllCard.destroy(self: any)
	self._cancel:destroy()
	self._buy:destroy()
	self._cover:Destroy()
end

return BuyAllCard
