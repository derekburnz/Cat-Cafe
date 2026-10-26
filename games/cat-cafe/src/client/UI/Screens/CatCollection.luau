--!strict
-- Collection screen with two tabs.
--   Book: every catalog cat grouped by rarity, "?" silhouettes for cats not found yet, tap for details.
--   Cat room: the cats the player owns (instances with a uid), Place / Move, Remove and Sell.
-- Needs state.cats and catalog.spots for the cat room; without them the tab is hidden.

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local Format = require(script.Parent.Parent.Components.Format)
local Panel = require(script.Parent.Parent.Components.Panel)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

export type Callbacks = {
	placeCat: (uid: string, spotId: string) -> (),
	unplaceCat: (uid: string) -> (),
	sellCat: (uid: string) -> (),
	close: () -> (),
}

export type CatCollection = {
	frame: Frame,
	setCatalog: (self: CatCollection, catalog: Types.Catalog) -> (),
	render: (self: CatCollection, state: Types.PlayerState) -> (),
	showTab: (self: CatCollection, tab: "Book" | "Room") -> (),
	destroy: (self: CatCollection) -> (),
}

local CELL = Vector2.new(108, 124)
local TAB_HEIGHT = 40
local DETAIL_HEIGHT = 92
local ROOM_ROW = 76
local SPOT_ROW = 48

-- Sell asks for confirmation from this rarity up (data-model: Rare and above).
local CONFIRM_SELL_FROM = 2
-- Shown on the confirm button so the player sees the price before agreeing (data-model section 2).
local RARITY_SELL_VALUE: { [string]: number } =
	{ Common = 25, Rare = 150, Epic = 600, Legendary = 3000, Secret = 10000 }

local CatCollection = {}
CatCollection.__index = CatCollection

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.modal.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

local function rarityIndex(rarity: string): number
	return table.find(Theme.rarityOrder, rarity) or 1
end

local function catColor(def: Types.CatDef): Color3
	local rgb = def.color
	if rgb and #rgb >= 3 then
		return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	end
	return Theme.rarityColor(def.rarity)
end

local function pill(
	parent: Instance,
	label: string,
	color: Color3,
	textColor: Color3,
	position: UDim2,
	anchor: Vector2?
)
	return Create("TextLabel", {
		Name = "Pill",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		Position = position,
		AnchorPoint = anchor or Vector2.new(),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textTiny,
		TextColor3 = textColor,
		Text = label,
		Parent = parent,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
	})
end

local function scroller(
	name: string,
	parent: Instance,
	position: UDim2,
	size: UDim2
): ScrollingFrame
	return Create("ScrollingFrame", {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = position,
		Size = size,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.colors.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = parent,
	}, {
		Create(
			"UIListLayout",
			{ Padding = UDim.new(0, Theme.sizes.gap), SortOrder = Enum.SortOrder.LayoutOrder }
		),
		Create("UIPadding", { PaddingRight = UDim.new(0, 10) }),
	})
end

function CatCollection.new(callbacks: Callbacks): CatCollection
	local self = setmetatable({}, CatCollection) :: any
	self._callbacks = callbacks
	self._catalog = nil :: Types.Catalog?
	self._catById = {} :: { [string]: Types.CatDef }
	self._cells = {} :: { [string]: any }
	self._sections = {} :: { [string]: any }
	self._roomRows = {} :: { [string]: any }
	self._spotRows = {} :: { any }
	self._buttons = {} :: { any }
	self._tab = "Book"
	self._selected = nil :: string?
	self._placing = nil :: string? -- uid waiting for a spot pick
	self._confirmSell = nil :: string? -- uid waiting for sell confirmation
	self._dirty = true
	self._lastState = nil :: Types.PlayerState?

	local panel = Panel.new({
		name = "Collection",
		title = "Cat collection",
		subtitle = "0 / 0 found",
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = Vector2.new(820, 580), Parent = panel.frame })
	self._panel = panel
	self.frame = panel.frame

	-- tabs
	local tabs: Frame = Create("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, TAB_HEIGHT),
		Parent = panel.content,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._bookTab = Button.new({
		name = "BookTab",
		text = "Book",
		style = "gold",
		size = UDim2.fromOffset(120, TAB_HEIGHT),
		textSize = Theme.sizes.textBody,
		layoutOrder = 1,
		parent = tabs,
		onClick = function()
			self:showTab("Book")
		end,
	})
	self._roomTab = Button.new({
		name = "RoomTab",
		text = "Cat room",
		style = "ghost",
		size = UDim2.fromOffset(120, TAB_HEIGHT),
		textSize = Theme.sizes.textBody,
		layoutOrder = 2,
		parent = tabs,
		onClick = function()
			self:showTab("Room")
		end,
	})

	-- Book: detail strip + grid of sections
	local bookTop = TAB_HEIGHT + Theme.sizes.gap
	self._book = Create("Frame", {
		Name = "Book",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, bookTop),
		Size = UDim2.new(1, 0, 1, -bookTop),
		Parent = panel.content,
	})
	local detail: Frame = Create("Frame", {
		Name = "Detail",
		BackgroundColor3 = Theme.modal.card,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, DETAIL_HEIGHT),
		Parent = self._book,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = Theme.modal.cardStroke, Thickness = Theme.sizes.stroke }),
	})
	self._detailArt = Create("Frame", {
		Name = "Art",
		BackgroundColor3 = Theme.colors.line,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(DETAIL_HEIGHT - 24, DETAIL_HEIGHT - 24),
		Parent = detail,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	self._detailName = text({
		Name = "Name",
		Position = UDim2.fromOffset(DETAIL_HEIGHT, 10),
		Size = UDim2.new(1, -(DETAIL_HEIGHT + 120), 0, 26),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		Text = "Tap a cat",
		Parent = detail,
	})
	self._detailMeta = text({
		Name = "Meta",
		Position = UDim2.fromOffset(DETAIL_HEIGHT, 38),
		Size = UDim2.new(1, -(DETAIL_HEIGHT + 20), 0, 18),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.subtext,
		Text = "Grey border Common, blue Rare, purple Epic, gold Legendary.",
		Parent = detail,
	})
	self._detailDesc = text({
		Name = "Description",
		Position = UDim2.fromOffset(DETAIL_HEIGHT, 58),
		Size = UDim2.new(1, -(DETAIL_HEIGHT + 20), 0, 24),
		TextSize = Theme.sizes.textSmall,
		Text = "Each cat earns on its own. A cat on its favorite spot earns 1.5x.",
		Parent = detail,
	})
	self._detailPill = pill(
		detail,
		"",
		Theme.colors.line,
		Theme.colors.ink,
		UDim2.new(1, -12, 0, 12),
		Vector2.new(1, 0)
	)
	self._detailPill.Visible = false

	self._grid = scroller(
		"Grid",
		self._book,
		UDim2.fromOffset(0, DETAIL_HEIGHT + Theme.sizes.gap),
		UDim2.new(1, 0, 1, -(DETAIL_HEIGHT + Theme.sizes.gap))
	)

	-- Cat room: list of owned cats; spot picker slides in on Place
	self._room = Create("Frame", {
		Name = "Room",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, bookTop),
		Size = UDim2.new(1, 0, 1, -bookTop),
		Visible = false,
		Parent = panel.content,
	})
	self._roomHint = text({
		Name = "Hint",
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.subtext,
		Text = "Placed cats earn. Resting cats wait in the back room.",
		Parent = self._room,
	})
	self._roomList = scroller("List", self._room, UDim2.fromOffset(0, 28), UDim2.new(1, 0, 1, -28))

	self._spotPicker = Create("Frame", {
		Name = "SpotPicker",
		BackgroundColor3 = Theme.modal.card,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 28),
		Size = UDim2.new(0, 280, 1, -28),
		Visible = false,
		ZIndex = 5,
		Parent = self._room,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = Theme.colors.caramel, Thickness = Theme.sizes.stroke }),
	})
	text({
		Name = "Title",
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -70, 0, 24),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody,
		Text = "Pick a spot",
		ZIndex = 6,
		Parent = self._spotPicker,
	})
	table.insert(
		self._buttons,
		Button.new({
			name = "Cancel",
			text = "X",
			style = "ghost",
			size = UDim2.fromOffset(40, 36),
			anchorPoint = Vector2.new(1, 0),
			position = UDim2.new(1, -6, 0, 4),
			parent = self._spotPicker,
			zIndex = 6,
			onClick = function()
				self._placing = nil
				self._spotPicker.Visible = false
			end,
		})
	)
	self._spotList =
		scroller("Spots", self._spotPicker, UDim2.fromOffset(8, 44), UDim2.new(1, -16, 1, -52))
	self._spotList.ZIndex = 6

	return self :: CatCollection
end

function CatCollection.showTab(self: any, tab: "Book" | "Room")
	self._tab = tab
	self._book.Visible = tab == "Book"
	self._room.Visible = tab == "Room"
	self._bookTab:setStyle(if tab == "Book" then "gold" else "ghost")
	self._roomTab:setStyle(if tab == "Room" then "gold" else "ghost")
	self._placing = nil
	self._confirmSell = nil
	self._spotPicker.Visible = false
	if self._lastState then
		self._dirty = true
		self:render(self._lastState)
	end
end

function CatCollection._select(self: any, catId: string)
	self._selected = catId
	local def: Types.CatDef? = self._catById[catId]
	local state: Types.PlayerState? = self._lastState
	if not def then
		return
	end
	assert(def)
	local found = false
	if state then
		found = (state.collection and state.collection[catId] ~= nil)
			or state.catsOwned[catId] ~= nil
	end
	self._detailArt.BackgroundColor3 = if found then catColor(def) else Theme.colors.line
	self._detailName.Text = if found then def.name else "Not found yet"
	local meta = {}
	table.insert(meta, Format.rate(def.incomePerSecond))
	if def.favoriteSpot then
		table.insert(meta, "loves the " .. def.favoriteSpot)
	end
	if def.area then
		table.insert(
			meta,
			"found in " .. (if def.area == "both" then "the alley and park" else "the " .. def.area)
		)
	end
	self._detailMeta.Text = table.concat(meta, "  ·  ")
	self._detailDesc.Text = if found
		then (def.description or "")
		else "Keep looking in the " .. (if def.area == "park" then "park" else "alley") .. "."
	self._detailPill.Visible = true
	self._detailPill.Text = def.rarity
	self._detailPill.BackgroundColor3 = Theme.rarityColor(def.rarity)
	self._detailPill.TextColor3 = Theme.rarityTextColor(def.rarity)
end

function CatCollection._buildBook(self: any)
	for _, cell in self._cells do
		cell.connection:Disconnect()
	end
	table.clear(self._cells)
	for _, section in self._sections do
		section.frame:Destroy()
	end
	table.clear(self._sections)
	table.clear(self._catById)

	local catalog: Types.Catalog? = self._catalog
	if not catalog then
		return
	end
	assert(catalog)

	for order, rarity in Theme.rarityOrder do
		local cats = {}
		for _, def in catalog.cats do
			self._catById[def.id] = def
			if def.rarity == rarity then
				table.insert(cats, def)
			end
		end
		if #cats == 0 then
			continue
		end
		local section: Frame = Create("Frame", {
			Name = rarity,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = order,
			Parent = self._grid,
		})
		local header = text({
			Name = "Header",
			Size = UDim2.new(1, 0, 0, 24),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody,
			TextColor3 = Theme.rarityColor(rarity),
			Text = rarity,
			Parent = section,
		})
		local cells: Frame = Create("Frame", {
			Name = "Cells",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Position = UDim2.fromOffset(0, 28),
			Size = UDim2.new(1, 0, 0, 0),
			Parent = section,
		}, {
			Create("UIGridLayout", {
				CellSize = UDim2.fromOffset(CELL.X, CELL.Y),
				CellPadding = UDim2.fromOffset(Theme.sizes.gap, Theme.sizes.gap),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		self._sections[rarity] = { frame = section, header = header, cells = cells, count = #cats }

		for index, def in cats do
			local cell: TextButton = Create("TextButton", {
				Name = def.id,
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = Theme.modal.card,
				BorderSizePixel = 0,
				LayoutOrder = index,
				Parent = cells,
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
				Create(
					"UIStroke",
					{ Color = Theme.rarityColor(rarity), Thickness = Theme.sizes.stroke }
				),
			})
			local art: Frame = Create("Frame", {
				Name = "Art",
				BackgroundColor3 = Theme.colors.line,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 12),
				Size = UDim2.fromOffset(56, 56),
				Parent = cell,
			}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
			local glyph = text({
				Name = "Glyph",
				Size = UDim2.fromScale(1, 1),
				FontFace = Theme.fonts.display,
				TextSize = 26,
				TextColor3 = Theme.colors.paper,
				TextXAlignment = Enum.TextXAlignment.Center,
				Text = "?",
				Parent = art,
			})
			local name = text({
				Name = "Name",
				Position = UDim2.fromOffset(6, 74),
				Size = UDim2.new(1, -12, 0, 20),
				FontFace = Theme.fonts.display,
				TextSize = Theme.sizes.textSmall + 1,
				TextXAlignment = Enum.TextXAlignment.Center,
				Text = "???",
				Parent = cell,
			})
			local count = text({
				Name = "Count",
				Position = UDim2.fromOffset(6, 96),
				Size = UDim2.new(1, -12, 0, 18),
				TextSize = Theme.sizes.textTiny,
				TextColor3 = Theme.modal.subtext,
				TextXAlignment = Enum.TextXAlignment.Center,
				Text = "",
				Parent = cell,
			})
			local connection = cell.Activated:Connect(function()
				self:_select(def.id)
			end)
			self._cells[def.id] = {
				frame = cell,
				art = art,
				glyph = glyph,
				name = name,
				count = count,
				def = def,
				connection = connection,
			}
		end
	end
end

function CatCollection._buildSpots(self: any)
	for _, row in self._spotRows do
		row.button:destroy()
		row.frame:Destroy()
	end
	table.clear(self._spotRows)
	local catalog: Types.Catalog? = self._catalog
	if not catalog or not catalog.spots then
		return
	end
	assert(catalog)
	for index, spot in catalog.spots :: { Types.SpotDef } do
		local row: Frame = Create("Frame", {
			Name = spot.id,
			BackgroundColor3 = Theme.modal.panel,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, SPOT_ROW),
			LayoutOrder = index,
			ZIndex = 6,
			Parent = self._spotList,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }) })
		local label = text({
			Name = "Label",
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(1, -100, 0, 22),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textSmall + 1,
			Text = spot.id,
			ZIndex = 7,
			Parent = row,
		})
		local sub = text({
			Name = "Sub",
			Position = UDim2.fromOffset(10, 26),
			Size = UDim2.new(1, -100, 0, 18),
			TextSize = Theme.sizes.textTiny,
			TextColor3 = Theme.modal.subtext,
			Text = "",
			ZIndex = 7,
			Parent = row,
		})
		local button = Button.new({
			name = "Pick",
			text = "Place",
			style = "primary",
			size = UDim2.fromOffset(78, 38),
			anchorPoint = Vector2.new(1, 0.5),
			position = UDim2.new(1, -6, 0.5, 0),
			textSize = Theme.sizes.textSmall,
			parent = row,
			zIndex = 7,
			onClick = function()
				local uid = self._placing
				if uid then
					self._callbacks.placeCat(uid, spot.id)
					self._placing = nil
					self._spotPicker.Visible = false
				end
			end,
		})
		table.insert(
			self._spotRows,
			{ frame = row, label = label, sub = sub, button = button, def = spot }
		)
	end
end

function CatCollection.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	self:_buildBook()
	self:_buildSpots()
	self._dirty = true
end

-- One row per owned cat instance. Rows are keyed by uid and rebuilt only when the set of uids changes.
function CatCollection._syncRoomRows(self: any, state: Types.PlayerState)
	local cats = state.cats or {}
	local seen = {} :: { [string]: boolean }
	local order = {} :: { Types.CatInstance }
	for _, instance in cats do
		table.insert(order, instance)
	end
	table.sort(order, function(a, b)
		local defA = self._catById[a.catId]
		local defB = self._catById[b.catId]
		local rarityA = if defA then rarityIndex(defA.rarity) else 0
		local rarityB = if defB then rarityIndex(defB.rarity) else 0
		if rarityA ~= rarityB then
			return rarityA > rarityB
		end
		if a.catId ~= b.catId then
			return a.catId < b.catId
		end
		return a.uid < b.uid
	end)

	for index, instance in order do
		seen[instance.uid] = true
		local row = self._roomRows[instance.uid]
		if not row then
			row = self:_makeRoomRow(instance)
			self._roomRows[instance.uid] = row
		end
		row.frame.LayoutOrder = index
	end
	for uid, row in self._roomRows do
		if not seen[uid] then
			row.place:destroy()
			row.remove:destroy()
			row.sell:destroy()
			row.frame:Destroy()
			self._roomRows[uid] = nil
		end
	end
end

function CatCollection._makeRoomRow(self: any, instance: Types.CatInstance)
	local def: Types.CatDef? = self._catById[instance.catId]
	local rarity = if def then def.rarity else "Common"
	local frame: Frame = Create("Frame", {
		Name = instance.uid,
		BackgroundColor3 = Theme.modal.card,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, ROOM_ROW),
		Parent = self._roomList,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = Theme.rarityColor(rarity), Thickness = Theme.sizes.stroke }),
	})
	Create("Frame", {
		Name = "Art",
		BackgroundColor3 = if def then catColor(def) else Theme.colors.line,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 14),
		Size = UDim2.fromOffset(48, 48),
		Parent = frame,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local name = text({
		Name = "Name",
		Position = UDim2.fromOffset(72, 10),
		Size = UDim2.new(1, -360, 0, 24),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		Text = if def then def.name else instance.catId,
		Parent = frame,
	})
	local status = text({
		Name = "Status",
		Position = UDim2.fromOffset(72, 36),
		Size = UDim2.new(1, -360, 0, 18),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.subtext,
		Text = "",
		Parent = frame,
	})
	local place = Button.new({
		name = "Place",
		text = "Place",
		style = "secondary",
		size = UDim2.fromOffset(84, 40),
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, -196, 0.5, 0),
		textSize = Theme.sizes.textSmall,
		parent = frame,
		onClick = function()
			self._confirmSell = nil
			self._placing = instance.uid
			self._spotPicker.Visible = true
			if self._lastState then
				self:_renderSpots(self._lastState)
			end
		end,
	})
	local remove = Button.new({
		name = "Remove",
		text = "Rest",
		style = "ghost",
		size = UDim2.fromOffset(84, 40),
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, -104, 0.5, 0),
		textSize = Theme.sizes.textSmall,
		parent = frame,
		onClick = function()
			if self._confirmSell == instance.uid then
				self._confirmSell = nil
				if self._lastState then
					self:render(self._lastState)
				end
				return
			end
			self._callbacks.unplaceCat(instance.uid)
		end,
	})
	local sell = Button.new({
		name = "Sell",
		text = "Sell",
		style = "danger",
		size = UDim2.fromOffset(84, 40),
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, -12, 0.5, 0),
		textSize = Theme.sizes.textSmall,
		parent = frame,
		onClick = function()
			local needsConfirm = rarityIndex(rarity) >= CONFIRM_SELL_FROM
			if needsConfirm and self._confirmSell ~= instance.uid then
				self._confirmSell = instance.uid
				if self._lastState then
					self:render(self._lastState)
				end
				return
			end
			self._confirmSell = nil
			self._callbacks.sellCat(instance.uid)
		end,
	})
	return {
		frame = frame,
		name = name,
		status = status,
		place = place,
		remove = remove,
		sell = sell,
		instance = instance,
		def = def,
	}
end

function CatCollection._renderSpots(self: any, state: Types.PlayerState)
	local occupied = {} :: { [string]: string }
	if state.cats then
		for _, instance in state.cats :: { [string]: Types.CatInstance } do
			if instance.spotId then
				occupied[instance.spotId :: string] = instance.catId
			end
		end
	end
	local placingDef: Types.CatDef? = nil
	if self._placing and state.cats then
		local instance = (state.cats :: { [string]: Types.CatInstance })[self._placing]
		if instance then
			placingDef = self._catById[instance.catId]
		end
	end
	for _, row in self._spotRows do
		local spot: Types.SpotDef = row.def
		local open = state.cafeLevel >= spot.cafeLevel
		local occupant = occupied[spot.id]
		local favorite = placingDef ~= nil
			and (placingDef :: Types.CatDef).favoriteSpot == spot.spotType
		row.label.Text = spot.spotType:sub(1, 1):upper()
			.. spot.spotType:sub(2)
			.. " "
			.. (spot.id:match("%d+$") or "")
		if not open then
			row.sub.Text = "Opens at cafe " .. Format.level(spot.cafeLevel)
			row.button:setText("Locked")
			row.button:setEnabled(false)
		elseif occupant then
			local occDef: Types.CatDef? = self._catById[occupant]
			row.sub.Text = "Taken by " .. (if occDef then occDef.name else occupant)
			row.button:setText("Taken")
			row.button:setEnabled(false)
		else
			row.sub.Text = if favorite then "Favorite spot, 1.5x tips" else "Empty"
			row.button:setText(if favorite then "Place ★" else "Place")
			row.button:setStyle(if favorite then "gold" else "primary")
			row.button:setEnabled(true)
		end
	end
end

function CatCollection.render(self: any, state: Types.PlayerState)
	self._lastState = state
	if not self.frame.Visible then
		self._dirty = true
		return
	end
	self._dirty = false
	local catalog: Types.Catalog? = self._catalog
	local total = if catalog then #catalog.cats else 0

	-- found = in collection map, else owned
	local foundCount = 0
	local found = {} :: { [string]: boolean }
	for catId in state.catsOwned do
		found[catId] = true
	end
	if state.collection then
		for catId in state.collection :: { [string]: number } do
			found[catId] = true
		end
	end
	for _ in found do
		foundCount += 1
	end
	self._panel:setTitle("Cat collection", ("%d / %d found"):format(foundCount, total))

	-- room tab only when the engineer sends cat instances
	local hasRoom = state.cats ~= nil
	self._roomTab.instance.Visible = hasRoom
	if not hasRoom and self._tab == "Room" then
		self:showTab("Book")
		return
	end

	if self._tab == "Book" then
		for catId, cell in self._cells do
			local def: Types.CatDef = cell.def
			local isFound = found[catId] == true
			local owned = state.catsOwned[catId]
			cell.art.BackgroundColor3 = if isFound then catColor(def) else Theme.colors.line
			cell.glyph.Text = if isFound then def.name:sub(1, 1) else "?"
			cell.name.Text = if isFound then def.name else "???"
			cell.name.TextColor3 = if isFound then Theme.modal.text else Theme.modal.subtext
			if owned and owned.count > 1 then
				cell.count.Text = ("x%d"):format(owned.count)
			elseif owned then
				cell.count.Text = "in your cafe"
			elseif isFound then
				cell.count.Text = "found"
			else
				cell.count.Text = def.rarity
			end
		end
		for rarity, section in self._sections do
			local foundHere = 0
			for catId, cell in self._cells do
				if cell.def.rarity == rarity and found[catId] then
					foundHere += 1
				end
			end
			section.header.Text = ("%s  %d / %d"):format(rarity, foundHere, section.count)
		end
		if self._selected then
			self:_select(self._selected)
		end
	else
		self:_syncRoomRows(state)
		local spotsById = {} :: { [string]: Types.SpotDef }
		if catalog and catalog.spots then
			for _, spot in catalog.spots :: { Types.SpotDef } do
				spotsById[spot.id] = spot
			end
		end
		local placed = 0
		local resting = 0
		for _, row in self._roomRows do
			local instance: Types.CatInstance = (state.cats :: { [string]: Types.CatInstance })[row.instance.uid]
				or row.instance
			row.instance = instance
			local def: Types.CatDef? = row.def
			local rate = if def then def.incomePerSecond else 0
			if instance.spotId then
				placed += 1
				local spot = spotsById[instance.spotId :: string]
				local favorite = def ~= nil
					and spot ~= nil
					and (def :: Types.CatDef).favoriteSpot == spot.spotType
				row.status.Text = ("On %s  ·  %s%s"):format(
					instance.spotId :: string,
					Format.rate(rate * (if favorite then 1.5 else 1)),
					if favorite then "  ·  favorite spot" else ""
				)
				row.place:setText("Move")
				row.remove:setEnabled(true)
				row.remove:setText("Rest")
			else
				resting += 1
				row.status.Text = "Resting in the back  ·  " .. Format.rate(rate) .. " when placed"
				row.place:setText("Place")
				row.remove:setEnabled(false)
				row.remove:setText("Rest")
			end
			row.place:setEnabled(catalog ~= nil and catalog.spots ~= nil)
			-- Sell confirmation: Sell turns into "Sell $150" and the middle button becomes an equal-sized Cancel
			if self._confirmSell == instance.uid then
				local value = if def then (RARITY_SELL_VALUE[def.rarity] or 0) else 0
				row.sell:setText(if value > 0 then "Sell " .. Format.money(value) else "Confirm")
				row.sell:setStyle("gold")
				row.remove:setText("Cancel")
				row.remove:setStyle("ghost")
				row.remove:setEnabled(true)
				row.confirming = true
			else
				row.sell:setText("Sell")
				row.sell:setStyle("danger")
				if row.confirming then
					row.confirming = false
					row.remove:setText("Rest")
					row.remove:setStyle("ghost")
					row.remove:setEnabled(instance.spotId ~= nil)
				end
			end
		end
		self._roomHint.Text = ("%d placed, %d resting. Placed cats earn, resting cats wait in the back."):format(
			placed,
			resting
		)
		if self._spotPicker.Visible then
			self:_renderSpots(state)
		end
	end
end

function CatCollection.destroy(self: any)
	for _, cell in self._cells do
		cell.connection:Disconnect()
	end
	for _, row in self._roomRows do
		row.place:destroy()
		row.remove:destroy()
		row.sell:destroy()
	end
	for _, row in self._spotRows do
		row.button:destroy()
	end
	for _, button in self._buttons do
		button:destroy()
	end
	self._bookTab:destroy()
	self._roomTab:destroy()
	self._panel:destroy()
end

return CatCollection
