--!strict
-- The Decor screen's Front lawn tab (F91, front-lawn.md section 3). DecorShop shows it in place of its strip and grid
-- when the "Front lawn" chip is picked, and only while the lawn is live (Components/LawnLogic.live).
--
-- Like the inside decor: a "Your lawn" strip on top with the path in use, the fence in use ("None") and the lawn
-- spots ("1 / 2" used of open), then the Edit lawn button. Tapping a slot shows its cards below: path styles, fence
-- styles, or the pieces (yours first, then the shop's). A piece card says Place (onto the first open spot of its
-- size), Put away, Spots full, its price, or the tier that sells it; a style card Use it, In use, Take down (the
-- fence), its price or tier. Edit lawn opens the edit view (Screens/LawnEdit), where a spot is picked by its ring.
-- Everything here is a request: the callbacks become BuyLawn, SetLawnSpot and SetLawnStyle, which the server checks.

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
	buyLawn: (id: string, spotId: string?) -> (),
	setLawnSpot: (spotId: string, pieceId: string) -> (), -- "" clears the spot
	setLawnStyle: (kind: Types.LawnStyleKind, id: string) -> (), -- "" lays Grey Slabs or takes the fence down
	editLawn: () -> (),
}

export type Filter = "pieces" | "path" | "fence"

export type LawnTab = {
	frame: Frame,
	render: (self: LawnTab, state: Types.PlayerState) -> (),
	setFilter: (self: LawnTab, filter: Filter) -> (),
	destroy: (self: LawnTab) -> (),
}

local CARD_WIDTH = 164 -- the inside decor's cards
local CARD_TOP = 152
local STRIP_HEIGHT = 58
local SLOT_WIDTH = 164 -- "White Picket" fits beside the picture
local EDIT_W = 150
local SHOP_ORDER = 1000 -- a shop card's LayoutOrder past every owned piece
local STYLE_KINDS: { Types.LawnStyleKind } = { "path", "fence" }

local GLYPH = "🌷" -- a lawn piece or style with no model in Assets yet
local PATH_GLYPH = "🧱"
local FENCE_GLYPH = "🚧"
local EDIT_GLYPH = "✏️"

local SLOTS: { { filter: Filter, label: string, glyph: string } } = {
	{ filter = "path", label = "Path", glyph = PATH_GLYPH },
	{ filter = "fence", label = "Fence", glyph = FENCE_GLYPH },
	{ filter = "pieces", label = "Lawn spots", glyph = GLYPH },
}

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

function LawnTab.new(parent: Instance, callbacks: Callbacks): LawnTab
	local self = setmetatable({}, LawnTab) :: any
	self._callbacks = callbacks
	self._filter = "pieces" :: Filter
	self._cards = {} :: { any }
	self._slots = {} :: { any }
	self._state = nil :: Types.PlayerState?
	self._actionHeight = Scale.tapHeight(Theme.sizes.touchMin, Theme.sizes.buttonDepth)

	local frame: Frame = Create("Frame", {
		Name = "Lawn",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = parent,
	})
	self.frame = frame

	local strip: ScrollingFrame = Create("ScrollingFrame", {
		Name = "YourLawn",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -(EDIT_W + Theme.sizes.gap), 0, STRIP_HEIGHT),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		Parent = frame,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for order, def in SLOTS do
		local slot: TextButton = Create("TextButton", {
			Name = (def.label:gsub(" ", "")),
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = PAL.card,
			BorderSizePixel = 0,
			LayoutOrder = order,
			Size = UDim2.fromOffset(SLOT_WIDTH, STRIP_HEIGHT),
			Parent = strip,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		})
		local stroke: UIStroke = Create("UIStroke", {
			Color = PAL.cardStroke,
			Thickness = Theme.sizes.stroke,
			Parent = slot,
		})
		local icon = ItemIcon.new({
			parent = slot,
			size = UDim2.fromOffset(STRIP_HEIGHT - 12, STRIP_HEIGHT - 12),
			anchorPoint = Vector2.new(0, 0.5),
			position = UDim2.new(0, 6, 0.5, 0),
		})
		text({
			Name = "Kind",
			Position = UDim2.fromOffset(STRIP_HEIGHT, 7),
			Size = UDim2.new(1, -(STRIP_HEIGHT + 6), 0, 16),
			FontFace = Theme.fonts.bodyBold,
			TextSize = Theme.sizes.textTiny,
			TextColor3 = PAL.subtext,
			Text = def.label,
			Parent = slot,
		})
		local value = text({
			Name = "Value",
			Position = UDim2.fromOffset(STRIP_HEIGHT, 24),
			Size = UDim2.new(1, -(STRIP_HEIGHT + 6), 0, 24),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody,
			Parent = slot,
		})
		local connection = slot.Activated:Connect(function()
			self:setFilter(def.filter)
		end)
		table.insert(self._slots, {
			filter = def.filter,
			glyph = def.glyph,
			frame = slot,
			stroke = stroke,
			icon = icon,
			value = value,
			connection = connection,
		})
	end

	self._edit = Button.new({
		name = "EditLawn",
		text = "Edit lawn",
		icon = EDIT_GLYPH,
		style = "gold",
		size = UDim2.fromOffset(EDIT_W, STRIP_HEIGHT),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, 0, 0, 0),
		textSize = Theme.sizes.textBody,
		parent = frame,
		onClick = function()
			callbacks.editLawn()
		end,
	})

	local gridTop = STRIP_HEIGHT + Theme.sizes.gap
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
			CellSize = UDim2.fromOffset(CARD_WIDTH, CARD_TOP + self._actionHeight),
			CellPadding = UDim2.fromOffset(Theme.sizes.gap, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
		}),
		Create("UIPadding", { PaddingRight = UDim.new(0, 10) }),
	})

	for _, piece in LawnLogic.pieces() do
		self:_card(piece.id, piece.name, piece.model, nil, piece, nil)
	end
	for _, kind in STYLE_KINDS do
		for _, style in LawnLogic.styles(kind) do
			self:_card(style.id, style.name, style.model, style.kind, nil, style)
		end
	end
	self:setFilter("pieces")

	return self :: LawnTab
end

-- One card: the model on a tile, the On lawn / In use / Owned pill, the name, what it is, and the button.
function LawnTab._card(
	self: any,
	id: string,
	name: string,
	model: string,
	kind: Types.LawnStyleKind?,
	piece: Types.LawnPieceDef?,
	style: Types.LawnStyleDef?
)
	local card: Frame = Create("Frame", {
		Name = id,
		BackgroundColor3 = PAL.card,
		BorderSizePixel = 0,
		Parent = self._grid,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = PAL.cardStroke, Thickness = Theme.sizes.stroke }),
	})
	local icon = ItemIcon.new({
		parent = card,
		size = UDim2.fromOffset(76, 76),
		anchorPoint = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, 10),
	})
	icon:set(
		model,
		if kind == "path" then PATH_GLYPH elseif kind == "fence" then FENCE_GLYPH else GLYPH,
		nil
	)
	local badge = text({
		Name = "Owned",
		BackgroundColor3 = Theme.colors.good,
		BackgroundTransparency = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textTiny,
		TextColor3 = Theme.colors.goodText,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		Visible = false,
		ZIndex = 3,
		Parent = card,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = badge })
	Create("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = badge,
	})
	text({
		Name = "Name",
		Position = UDim2.fromOffset(10, 92),
		Size = UDim2.new(1, -20, 0, 22),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody,
		Text = name,
		Parent = card,
	})
	local what = if piece
		then ("%s · Tier %d"):format(LawnLogic.sizeName(piece.spot), piece.tier)
		elseif kind == "path" then "Path"
		else "Fence"
	text({
		Name = "Effect",
		Position = UDim2.fromOffset(10, 114),
		Size = UDim2.new(1, -20, 0, 18),
		TextSize = Theme.sizes.textTiny,
		TextColor3 = PAL.subtext,
		Text = what,
		Parent = card,
	})
	local entry: any = {
		id = id,
		kind = kind,
		piece = piece,
		style = style,
		frame = card,
		icon = icon,
		badge = badge,
		order = #self._cards + 1,
		action = nil :: LawnLogic.Action?,
	}
	entry.button = Button.new({
		name = "Action",
		text = "",
		style = "primary",
		size = UDim2.new(1, -20, 0, self._actionHeight),
		position = UDim2.new(0, 10, 1, -(self._actionHeight + 10)),
		textSize = Theme.sizes.textSmall + 1,
		parent = card,
		onClick = function()
			self:_press(entry)
		end,
	})
	table.insert(self._cards, entry)
end

function LawnTab._press(self: any, entry: any)
	local action: LawnLogic.Action? = entry.action
	if action == nil or not action.enabled then
		return
	end
	local callbacks: Callbacks = self._callbacks
	local mode = action.mode
	if mode == "buy" then
		callbacks.buyLawn(entry.id, nil)
	elseif mode == "place" and action.spotId then
		callbacks.setLawnSpot(action.spotId, entry.id)
	elseif mode == "away" and action.spotId then
		callbacks.setLawnSpot(action.spotId, "")
	elseif mode == "use" and entry.kind then
		callbacks.setLawnStyle(entry.kind, entry.id)
	elseif mode == "takeDown" then
		callbacks.setLawnStyle("fence", "")
	end
end

function LawnTab.setFilter(self: any, filter: Filter)
	self._filter = filter
	for _, slot in self._slots do
		local picked = slot.filter == filter
		slot.stroke.Color = if picked then Theme.colors.gold else PAL.cardStroke
		slot.stroke.Thickness = if picked then Theme.sizes.stroke + 1 else Theme.sizes.stroke
	end
	for _, entry in self._cards do
		entry.frame.Visible = (filter == "pieces" and entry.piece ~= nil) or entry.kind == filter
	end
	self._grid.CanvasPosition = Vector2.zero
end

function LawnTab.render(self: any, state: Types.PlayerState)
	self._state = state
	local used, open = LawnLogic.counts(state)
	for _, slot in self._slots do
		if slot.filter == "pieces" then
			slot.icon:set(nil, slot.glyph, nil)
			slot.value.Text = ("%d / %d"):format(used, open)
			slot.value.TextColor3 = if open > 0 and used >= open then Theme.colors.red else PAL.text
			continue
		end
		local id = LawnLogic.inUse(state, slot.filter)
		local style = if id ~= nil then LawnLogic.getStyle(id) else nil
		slot.icon:set(if style then style.model else nil, slot.glyph, nil)
		slot.value.Text = if style then style.name else "None"
		slot.value.TextColor3 = if style then PAL.text else PAL.subtext
	end
	for _, entry in self._cards do
		local action = if entry.piece
			then LawnLogic.pieceAction(state, entry.piece)
			else LawnLogic.styleAction(state, entry.style)
		entry.action = action
		entry.button:setText(action.text)
		entry.button:setStyle(action.style :: any)
		entry.button:setEnabled(action.enabled)
		local owned = LawnLogic.owns(state, entry.id)
		local onLawn = action.mode == "away" or action.mode == "inUse" or action.mode == "takeDown"
		entry.badge.Visible = owned
		entry.badge.Text = if onLawn then (if entry.piece then "On lawn" else "In use") else "Owned"
		-- yours first, then the shop's, each in catalog order
		entry.frame.LayoutOrder = if owned then entry.order else SHOP_ORDER + entry.order
	end
end

function LawnTab.destroy(self: any)
	for _, slot in self._slots do
		slot.icon:destroy()
		slot.connection:Disconnect()
	end
	for _, entry in self._cards do
		entry.icon:destroy()
		entry.button:destroy()
	end
	self._edit:destroy()
	self.frame:Destroy()
end

return LawnTab
