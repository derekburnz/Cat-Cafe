--!strict
-- The Decor screen's Lawn chip (F91; #1283, lawn-nursery.md section 6e, Derek2 11-05: "act like its another
-- plants/floor/walls section no edit lawn bs"). DecorShop shows it in place of its strip and grid when the Lawn chip
-- is picked, and only while the lawn is live (Components/LawnLogic.live).
--
-- Like Plants, Floor and Walls: one line on top with the total ("Lawn: 6 out, +18% money", the Money boosts row's
-- number), then a grid of the same cards, one per owned piece, path and fence (Components/LawnLogic.cards): the model
-- on a tile in its rarity colour, the rarity, the name, its bonus ("+3% money", paths and fences tagged "Path" or
-- "Fence"), and a Use or Remove button (below). The grid ends with where to buy more.

-- #1751 part 3 (Derek2: "lawn section is missing remove/use it buttons"): each card ends in one button,
-- LawnLogic.cardAction's Remove (green edge: it is out) or Use, forwarded as SetLawnSpot or SetLawnStyle; Equip Best
-- still lays the best lawn.

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local LawnLogic = require(script.Parent.Parent.Components.LawnLogic)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

-- the dark window palette (#1028), in place of Theme.modal
local PAL = Theme.dark

export type Callbacks = {
	-- #1751: Use or Remove on a card; a piece's spot and id ("" takes it in), or a path or fence and id ("" for none)
	setSpot: ((spotId: string, pieceId: string) -> ())?,
	setStyle: ((kind: string, id: string) -> ())?,
}

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

-- A small round pill: the rarity on the art.
local function pill(label: TextLabel): TextLabel
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = label })
	Create("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = label,
	})
	return label
end

function LawnTab.new(parent: Instance, callbacks: Callbacks?): LawnTab
	local self = setmetatable({}, LawnTab) :: any
	self._callbacks = callbacks or {}
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
	})
	local edge: UIStroke = Create("UIStroke", {
		Color = PAL.cardStroke,
		Thickness = Theme.sizes.stroke,
		Parent = frame,
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
	local entry: any = { frame = frame, icon = icon, edge = edge, action = nil }
	-- #1751: Use or Remove, from LawnLogic.cardAction at each render
	entry.button = Button.new({
		name = "Action",
		text = "",
		style = "primary",
		size = UDim2.new(1, -20, 0, self._statusHeight),
		anchorPoint = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -10),
		textSize = Theme.sizes.textSmall + 1,
		parent = frame,
		onClick = function()
			local action: LawnLogic.CardAction? = entry.action
			if action == nil or not action.enabled then
				return
			end
			local callbacks: Callbacks = self._callbacks
			if action.spotId ~= nil and action.pieceId ~= nil and callbacks.setSpot then
				callbacks.setSpot(action.spotId, action.pieceId)
			elseif action.styleKind ~= nil and action.styleId ~= nil and callbacks.setStyle then
				callbacks.setStyle(action.styleKind, action.styleId)
			end
		end,
	})
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
		local action = LawnLogic.cardAction(state, card)
		entry.action = action
		entry.button:setText(action.text)
		if entry.style ~= action.style then
			entry.style = action.style
			entry.button:setStyle(action.style :: any)
		end
		entry.button:setEnabled(action.enabled)
		-- an out piece, path or fence wears a green edge (the Out pill's place before #1751)
		entry.edge.Color = if card.out then Theme.colors.good else PAL.cardStroke
		entry.edge.Thickness = if card.out then Theme.sizes.stroke + 1 else Theme.sizes.stroke
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
		entry.button:destroy()
	end
	self.frame:Destroy()
end

return LawnTab
