--!strict
-- The Decor screen's Lawn chip (F91; #1283, lawn-nursery.md section 6e, Derek2 11-05: "act like its another
-- plants/floor/walls section no edit lawn bs"). DecorShop shows it in place of its strip and grid when the Lawn chip
-- is picked, and only while the lawn is live (Components/LawnLogic.live).
--
-- Like Plants, Floor and Walls: one line on top with the total ("Lawn: 6 out, +18% money", the Money boosts row's
-- number), then a grid of the same cards, one per owned piece, path and fence (Components/LawnLogic.cards): the model
-- on a tile in its rarity colour, the rarity, the name, its bonus ("+3% money", paths and fences tagged "Path" or
-- "Fence") and "Out" or "Stored". The server lays the best owned pieces by itself after every buy (LawnService,
-- Lawn.best), and the window's Equip Best stays, so nothing here is a button. The grid ends with where to buy more.

local Create = require(script.Parent.Parent.Components.Create)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local LawnLogic = require(script.Parent.Parent.Components.LawnLogic)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

-- the dark window palette (#1028), in place of Theme.modal
local PAL = Theme.dark

export type LawnTab = {
	frame: Frame,
	render: (self: LawnTab, state: Types.PlayerState) -> (),
	destroy: (self: LawnTab) -> (),
}

local CARD_WIDTH = 164 -- the inside decor's cards
local CARD_TOP = 152
local TOTAL_HEIGHT = 28 -- "Lawn: 6 out, +18% money"
local FOOTER_GLYPH = 56

local GLYPH = "🌷" -- a lawn piece with no model in Assets yet
local PATH_GLYPH = "🧱"
local FENCE_GLYPH = "🚧"

local LawnTab = {}
LawnTab.__index = LawnTab

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textBody,
		TextColor3 = PAL.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

-- A small round pill: the rarity on the art, "Out" or "Stored" at the foot.
local function pill(label: TextLabel): TextLabel
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = label })
	Create("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = label,
	})
	return label
end

function LawnTab.new(parent: Instance): LawnTab
	local self = setmetatable({}, LawnTab) :: any
	self._cards = {} :: { [string]: any }
	self._statusHeight = Scale.tapHeight(Theme.sizes.touchMin, Theme.sizes.buttonDepth)

	local frame: Frame = Create("Frame", {
		Name = "Lawn",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = parent,
	})
	self.frame = frame

	self._total = text({
		Name = "Total",
		Size = UDim2.new(1, 0, 0, TOTAL_HEIGHT),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody,
		Text = "Lawn",
		Parent = frame,
	})
	local gridTop = TOTAL_HEIGHT + Theme.sizes.gap
	self._grid = Create("ScrollingFrame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, gridTop),
		Size = UDim2.new(1, 0, 1, -gridTop),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = PAL.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = frame,
	}, {
		Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(CARD_WIDTH, CARD_TOP + self._statusHeight),
			CellPadding = UDim2.fromOffset(Theme.sizes.gap, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
		}),
		Create("UIPadding", { PaddingRight = UDim.new(0, 10) }),
	})

	-- the last cell: where lawn pieces are sold, like the decor grid's "Find more in crates"
	local footer: Frame = Create("Frame", {
		Name = "FindMore",
		LayoutOrder = 100000,
		BackgroundColor3 = PAL.card,
		BorderSizePixel = 0,
		Parent = self._grid,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = PAL.cardStroke, Thickness = Theme.sizes.stroke }),
	})
	text({
		Name = "Glyph",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 18),
		Size = UDim2.fromOffset(FOOTER_GLYPH, FOOTER_GLYPH),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = GLYPH,
		Parent = footer,
	})
	text({
		Name = "Title",
		Position = UDim2.fromOffset(10, FOOTER_GLYPH + 26),
		Size = UDim2.new(1, -20, 0, 22),
		FontFace = Theme.fonts.display,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = LawnLogic.SHOP_TITLE,
		TextScaled = true,
		Parent = footer,
	})
	text({
		Name = "Where",
		Position = UDim2.fromOffset(10, FOOTER_GLYPH + 50),
		Size = UDim2.new(1, -20, 0, 18),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = LawnLogic.SHOP_WHERE,
		Parent = footer,
	})

	return self :: LawnTab
end

-- One card, made the first time its piece or style is owned and kept: the model on a tile in its rarity colour, the
-- rarity, the name, the bonus line and the Out / Stored pill.
function LawnTab._card(self: any, card: LawnLogic.Card): any
	local frame: Frame = Create("Frame", {
		Name = card.id,
		BackgroundColor3 = PAL.card,
		BorderSizePixel = 0,
		Parent = self._grid,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = PAL.cardStroke, Thickness = Theme.sizes.stroke }),
	})
	local icon = ItemIcon.new({
		parent = frame,
		size = UDim2.fromOffset(76, 76),
		anchorPoint = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, 10),
	})
	icon:set(
		card.model,
		if card.kind == "path"
			then PATH_GLYPH
			elseif card.kind == "fence" then FENCE_GLYPH
			else GLYPH,
		card.rarity
	)
	pill(text({
		Name = "Rarity",
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.rarityColor(card.rarity),
		Position = UDim2.fromOffset(16, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textTiny,
		TextColor3 = Theme.rarityTextColor(card.rarity),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		Text = card.rarity or "",
		ZIndex = 3,
		Parent = frame,
	}))
	text({
		Name = "Name",
		Position = UDim2.fromOffset(10, 92),
		Size = UDim2.new(1, -20, 0, 22),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody,
		Text = card.name,
		Parent = frame,
	})
	text({
		Name = "Effect",
		Position = UDim2.fromOffset(10, 114),
		Size = UDim2.new(1, -20, 0, 18),
		TextSize = Theme.sizes.textTiny,
		TextColor3 = PAL.subtext,
		Text = LawnLogic.cardLine(card),
		Parent = frame,
	})
	local status = text({
		Name = "Status",
		BackgroundTransparency = 0,
		Position = UDim2.new(0, 10, 1, -(self._statusHeight + 10)),
		Size = UDim2.new(1, -20, 0, self._statusHeight - Theme.sizes.buttonDepth),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall + 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = frame,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall), Parent = status })
	local entry = { frame = frame, icon = icon, status = status }
	self._cards[card.id] = entry
	return entry
end

function LawnTab.render(self: any, state: Types.PlayerState)
	self._total.Text = LawnLogic.total(state)
	local shown: { [string]: boolean } = {}
	for order, card in LawnLogic.cards(state) do
		local entry = self._cards[card.id] or self:_card(card)
		entry.frame.LayoutOrder = order
		entry.frame.Visible = true
		entry.status.Text = if card.out then "Out" else "Stored"
		entry.status.BackgroundColor3 = if card.out then Theme.colors.good else PAL.cardStroke
		entry.status.TextColor3 = if card.out then Theme.colors.goodText else PAL.subtext
		shown[card.id] = true
	end
	for id, entry in self._cards do
		if not shown[id] then
			entry.frame.Visible = false
		end
	end
end

function LawnTab.destroy(self: any)
	for _, entry in self._cards do
		entry.icon:destroy()
	end
	self.frame:Destroy()
end

return LawnTab
