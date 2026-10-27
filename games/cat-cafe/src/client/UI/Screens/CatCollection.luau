--!strict
-- Collection screen with two tabs.
--   Book: the Pet Simulator index. A tab per area with its completion, then that area's cats as live 3D models
--         (dark silhouettes until found), rarest last; tap one for details.
--   Cat room: the cats the player owns (instances with a uid), Place / Move, Remove and Sell.
-- Needs state.cats and catalog.spots for the cat room; without them the tab is hidden.

local Button = require(script.Parent.Parent.Components.Button)
local CatPortrait = require(script.Parent.Parent.Components.CatPortrait)
local Create = require(script.Parent.Parent.Components.Create)
local Format = require(script.Parent.Parent.Components.Format)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

export type Callbacks = {
	placeCat: (uid: string, spotId: string) -> (),
	unplaceCat: (uid: string) -> (),
	sellCat: (uid: string) -> (),
	equipBest: () -> (),
	close: () -> (),
}

export type CatCollection = {
	frame: Frame,
	setCatalog: (self: CatCollection, catalog: Types.Catalog) -> (),
	render: (self: CatCollection, state: Types.PlayerState) -> (),
	showTab: (self: CatCollection, tab: "Book" | "Room") -> (),
	destroy: (self: CatCollection) -> (),
}

local CELL = Vector2.new(112, 134)
local PORTRAIT = 84
local TAB_HEIGHT = 40
local DETAIL_HEIGHT = 92
local AREA_TAB_HEIGHT = 46
local PROGRESS_HEIGHT = 28
local FALLBACK_AREA = "alley"
local ROOM_ROW = 76
local ROOM_ART = 64 -- the cat's own model on each cat room card, as in the Pet Simulator inventory
local ROOM_TEXT = ROOM_ART + 22
-- cards this far above or below the visible part of the list already get their cat model (reviewer N71)
local PORTRAIT_MARGIN = 240
local SPOT_ROW = 48

-- Sell asks for confirmation from this rarity up (data-model: Rare and above).
local CONFIRM_SELL_FROM = 2
-- Shown on the confirm button so the player sees the price before agreeing (data-model section 2).
local RARITY_SELL_VALUE: { [string]: number } =
	{ Common = 25, Rare = 150, Epic = 600, Legendary = 3000, Mythical = 12000 }

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
	self._areaChips = {} :: { any }
	self._area = nil :: string? -- the book's open area tab
	self._detailId = nil :: string? -- the cat in the detail strip's portrait
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
		sound = "uiTab",
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
		sound = "uiTab",
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
	self._detailArt = CatPortrait.new({
		parent = detail,
		size = UDim2.fromOffset(DETAIL_HEIGHT - 16, DETAIL_HEIGHT - 16),
		position = UDim2.fromOffset(8, 8),
		still = true,
	})
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

	-- area tabs, one per area like the index's world tabs
	local gap = Theme.sizes.gap
	local areaTop = DETAIL_HEIGHT + gap
	self._areaBar = Create("Frame", {
		Name = "Areas",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, areaTop),
		Size = UDim2.new(1, 0, 0, AREA_TAB_HEIGHT),
		Parent = self._book,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- the open area's completion: name, bar, count and percent
	local progressTop = areaTop + AREA_TAB_HEIGHT + gap
	local progress: Frame = Create("Frame", {
		Name = "Progress",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, progressTop),
		Size = UDim2.new(1, 0, 0, PROGRESS_HEIGHT),
		Parent = self._book,
	})
	self._progressName = text({
		Name = "Area",
		Size = UDim2.new(0, 190, 1, 0),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextColor3 = Theme.colors.white,
		Parent = progress,
	})
	Outline.text(self._progressName, 2)
	local track: Frame = Create("Frame", {
		Name = "Track",
		BackgroundColor3 = Theme.colors.line,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 196, 0.5, 0),
		Size = UDim2.new(1, -196 - 130, 0, 16),
		Parent = progress,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(track, 2)
	self._progressFill = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.colors.mint,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.shade(self._progressFill, 0.2)
	self._progressCount = text({
		Name = "Count",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 124, 1, 0),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = progress,
	})

	local gridTop = progressTop + PROGRESS_HEIGHT + gap
	self._grid =
		scroller("Grid", self._book, UDim2.fromOffset(0, gridTop), UDim2.new(1, 0, 1, -gridTop))
	self._cellsFrame = Create("Frame", {
		Name = "Cells",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		Parent = self._grid,
	}, {
		Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(CELL.X, CELL.Y),
			CellPadding = UDim2.fromOffset(gap, gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- Cat room: list of owned cats; the role picker slides in on Assign
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
		Size = UDim2.new(1, -150, 0, 36),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.subtext,
		TextWrapped = true,
		Text = "Working cats earn. Resting cats wait in the cat room.",
		Parent = self._room,
	})
	-- Equip best: the server picks the highest-rated cats for the open role slots (cat stats thread)
	self._equipBest = Button.new({
		name = "EquipBest",
		text = "Equip best",
		style = "gold",
		size = UDim2.fromOffset(140, 36),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, 0, 0, 0),
		textSize = Theme.sizes.textSmall + 1,
		parent = self._room,
		onClick = function()
			self._callbacks.equipBest()
		end,
	})
	self._roomList = scroller("List", self._room, UDim2.fromOffset(0, 44), UDim2.new(1, 0, 1, -44))
	self._roomScroll = self._roomList:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		self:_loadPortraits()
	end)

	self._spotPicker = Create("Frame", {
		Name = "SpotPicker",
		BackgroundColor3 = Theme.modal.card,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 44),
		Size = UDim2.new(0, 280, 1, -44),
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
		Text = "Pick a role",
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
	assert(def, "cat definition missing")
	local found = false
	if state then
		found = (state.collection and state.collection[catId] ~= nil)
			or state.catsOwned[catId] ~= nil
	end
	-- render calls this on every state push while a cat is selected, so the model is cloned once per pick
	if self._detailId ~= catId then
		self._detailId = catId
		self._detailArt:set(def)
	end
	self._detailArt:setSilhouette(not found)
	self._detailName.Text = if found then def.name else "Not found yet"
	local meta = {}
	table.insert(meta, Format.rate(def.incomePerSecond))
	if def.favoriteRole then
		table.insert(meta, "loves " .. Format.roleName(def.favoriteRole))
	end
	if def.area then
		table.insert(meta, "found in the " .. Format.areaName(def.area))
	end
	self._detailMeta.Text = table.concat(meta, "  ·  ")
	self._detailDesc.Text = if found
		then (def.description or "")
		else "Keep looking in the " .. Format.areaName(def.area or "alley") .. "."
	self._detailPill.Visible = true
	self._detailPill.Text = def.rarity
	self._detailPill.BackgroundColor3 = Theme.rarityColor(def.rarity)
	self._detailPill.TextColor3 = Theme.rarityTextColor(def.rarity)
end

-- The book's areas in tier order: the catalog's areas, else the areas the cats name in catalog order.
type BookArea = { id: string, name: string, tier: number }

local function bookAreas(catalog: Types.Catalog): { BookArea }
	local list: { BookArea } = {}
	local seen: { [string]: boolean } = {}
	local areas: { Types.AreaDef } = catalog.areas or {}
	for _, area in areas do
		seen[area.id] = true
		table.insert(list, { id = area.id, name = area.name, tier = area.tier })
	end
	table.sort(list, function(a: BookArea, b: BookArea): boolean
		return a.tier < b.tier
	end)
	for _, def in catalog.cats do
		local areaId: string = def.area or FALLBACK_AREA
		if not seen[areaId] then
			seen[areaId] = true
			table.insert(list, { id = areaId, name = Format.areaName(areaId), tier = 0 })
		end
	end
	return list
end

function CatCollection._buildBook(self: any)
	for _, cell in self._cells do
		cell.connection:Disconnect()
		cell.portrait:destroy()
		cell.frame:Destroy()
	end
	table.clear(self._cells)
	for _, chip in self._areaChips do
		chip.connection:Disconnect()
		chip.frame:Destroy()
	end
	table.clear(self._areaChips)
	table.clear(self._catById)

	local catalog: Types.Catalog? = self._catalog
	if not catalog then
		return
	end
	assert(catalog, "catalog not set; call UI.init first")

	local areas = bookAreas(catalog)
	local gap = Theme.sizes.gap
	for order, area in areas do
		local color = Theme.areaColors[area.id] or Theme.colors.caramel
		local chip: TextButton = Create("TextButton", {
			Name = area.id,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Theme.modal.card,
			BorderSizePixel = 0,
			Size = UDim2.new(1 / #areas, -gap * (#areas - 1) / #areas, 1, 0),
			LayoutOrder = order,
			Parent = self._areaBar,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
		local border = Outline.border(chip, Theme.sizes.outline)
		local name = text({
			Name = "Name",
			Position = UDim2.fromOffset(6, 3),
			Size = UDim2.new(1, -12, 0, 22),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textSmall + 1,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = area.name,
			Parent = chip,
		})
		local count = text({
			Name = "Count",
			Position = UDim2.fromOffset(6, 24),
			Size = UDim2.new(1, -12, 0, 16),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textTiny,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = chip,
		})
		local entry = {
			id = area.id,
			name = area.name,
			tier = area.tier,
			color = color,
			frame = chip,
			border = border,
			label = name,
			count = count,
			connection = nil :: RBXScriptConnection?,
		}
		entry.connection = chip.Activated:Connect(function()
			if self._area == area.id then
				return
			end
			Sound.play("uiTab")
			self._area = area.id
			self._grid.CanvasPosition = Vector2.zero
			local state: Types.PlayerState? = self._lastState
			if state then
				self:render(state)
			end
		end)
		table.insert(self._areaChips, entry)
	end

	for index, def in catalog.cats do
		self._catById[def.id] = def
		local rarity = def.rarity
		local cell: TextButton = Create("TextButton", {
			Name = def.id,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Theme.modal.card,
			BorderSizePixel = 0,
			LayoutOrder = rarityIndex(rarity) * 1000 + index,
			Visible = false,
			Parent = self._cellsFrame,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
		Outline.border(cell, Theme.sizes.outline + 1, Theme.rarityColor(rarity))
		-- a soft disc in the rarity colour behind the cat, like the index's rarity backdrop
		local glow: Frame = Create("Frame", {
			Name = "Glow",
			BackgroundColor3 = Theme.rarityColor(rarity),
			BackgroundTransparency = 0.7,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 8),
			Size = UDim2.fromOffset(PORTRAIT - 8, PORTRAIT - 8),
			Parent = cell,
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		local portrait = CatPortrait.new({
			parent = cell,
			size = UDim2.fromOffset(PORTRAIT, PORTRAIT),
			anchorPoint = Vector2.new(0.5, 0),
			position = UDim2.new(0.5, 0, 0, 4),
			still = true,
			zIndex = 2,
		})
		local name = text({
			Name = "Name",
			Position = UDim2.fromOffset(6, PORTRAIT + 6),
			Size = UDim2.new(1, -12, 0, 20),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textSmall + 1,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = "???",
			Parent = cell,
		})
		local sub = text({
			Name = "Sub",
			Position = UDim2.fromOffset(6, PORTRAIT + 26),
			Size = UDim2.new(1, -12, 0, 18),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textTiny,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = cell,
		})
		local shiny = pill(
			cell,
			"Shiny",
			Theme.colors.gold,
			Theme.colors.goldText,
			UDim2.new(1, -4, 0, 4),
			Vector2.new(1, 0)
		)
		shiny.ZIndex = 3
		shiny.Visible = false
		local connection = cell.Activated:Connect(function()
			Sound.play("uiTab")
			self:_select(def.id)
		end)
		self._cells[def.id] = {
			frame = cell,
			glow = glow,
			portrait = portrait,
			loaded = false,
			name = name,
			sub = sub,
			shiny = shiny,
			def = def,
			connection = connection,
		}
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
	assert(catalog, "catalog not set; call UI.init first")
	-- One row per role (F25): Assign picks the first free open slot of that role, so the player chooses
	-- the job and never a slot number.
	local slotsByRole: { [string]: { Types.SpotDef } } = {}
	local roles: { string } = {}
	for _, spot in catalog.spots :: { Types.SpotDef } do
		local list = slotsByRole[spot.spotType]
		if not list then
			list = {}
			slotsByRole[spot.spotType] = list
			table.insert(roles, spot.spotType)
		end
		table.insert(list, spot)
	end
	for index, role in roles do
		local entry: { [string]: any } = { role = role, slots = slotsByRole[role], freeSlot = nil }
		local row: Frame = Create("Frame", {
			Name = role,
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
			Text = Format.roleName(role),
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
			text = "Assign",
			style = "primary",
			size = UDim2.fromOffset(78, 38),
			anchorPoint = Vector2.new(1, 0.5),
			position = UDim2.new(1, -6, 0.5, 0),
			textSize = Theme.sizes.textSmall,
			parent = row,
			zIndex = 7,
			onClick = function()
				local uid = self._placing
				local spotId: string? = entry.freeSlot
				if uid and spotId then
					self._callbacks.placeCat(uid, spotId)
					self._placing = nil
					self._spotPicker.Visible = false
				end
			end,
		})
		entry.frame = row
		entry.label = label
		entry.sub = sub
		entry.button = button
		table.insert(self._spotRows, entry)
	end
end

function CatCollection.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	self:_buildBook()
	self:_buildSpots()
	self._dirty = true
end

-- The open area's page: chips with each area's count, the progress strip, and that area's cells. Each cell's
-- model is cloned the first time its area opens, and again on later renders until Assets has it.
function CatCollection._renderBook(
	self: any,
	state: Types.PlayerState,
	found: { [string]: boolean }
)
	local totals: { [string]: number } = {}
	local foundIn: { [string]: number } = {}
	for catId, cell in self._cells do
		local areaId: string = cell.def.area or FALLBACK_AREA
		totals[areaId] = (totals[areaId] or 0) + 1
		if found[catId] then
			foundIn[areaId] = (foundIn[areaId] or 0) + 1
		end
	end

	-- first open: the first area the player can reach that still has cats to find
	if self._area == nil then
		for _, chip in self._areaChips do
			if state.tier >= chip.tier and (foundIn[chip.id] or 0) < (totals[chip.id] or 0) then
				self._area = chip.id
				break
			end
		end
		local first = self._areaChips[1]
		if self._area == nil and first then
			self._area = first.id
		end
	end
	local open: string? = self._area

	for _, chip in self._areaChips do
		local selected = chip.id == open
		local locked = state.tier < chip.tier
		local have, all = foundIn[chip.id] or 0, totals[chip.id] or 0
		chip.frame.BackgroundColor3 = if selected then chip.color else Theme.modal.card
		chip.border.Color = if selected then Theme.colors.outline else Theme.modal.cardStroke
		chip.label.TextColor3 = if selected then Theme.colors.white else Theme.modal.text
		chip.count.Text = if locked and have == 0
			then "Tier " .. tostring(chip.tier)
			elseif have >= all and all > 0 then "Complete!"
			else ("%d / %d"):format(have, all)
		chip.count.TextColor3 = if selected
			then Theme.colors.cream
			elseif have >= all and all > 0 then Theme.colors.goodDark
			else Theme.modal.subtext
		if selected then
			local fraction = if all > 0 then have / all else 0
			self._progressName.Text = chip.name
			self._progressName.TextColor3 = chip.color
			self._progressFill.BackgroundColor3 = if have >= all
				then Theme.colors.gold
				else chip.color
			self._progressFill.Size = UDim2.fromScale(fraction, 1)
			self._progressCount.Text = ("%d / %d  ·  %s"):format(
				have,
				all,
				Format.percent(fraction)
			)
		end
	end

	local shinies: { [string]: number } = state.shinyCollection or {}
	for catId, cell in self._cells do
		local def: Types.CatDef = cell.def
		local inArea = (def.area or FALLBACK_AREA) == open
		cell.frame.Visible = inArea
		if not inArea then
			continue
		end
		if not cell.loaded then
			cell.portrait:set(def)
			cell.loaded = cell.portrait:hasModel()
		end
		local isFound = found[catId] == true
		local owned = state.catsOwned[catId]
		cell.portrait:setSilhouette(not isFound)
		cell.glow.BackgroundColor3 = if isFound
			then Theme.rarityColor(def.rarity)
			else Theme.colors.line
		cell.name.Text = if isFound then def.name else "???"
		cell.name.TextColor3 = if isFound then Theme.modal.text else Theme.modal.subtext
		cell.sub.TextColor3 = Theme.modal.subtext
		if owned and owned.count > 1 then
			cell.sub.Text = ("x%d"):format(owned.count)
		elseif owned then
			cell.sub.Text = "in your cafe"
		elseif isFound then
			cell.sub.Text = "found"
		else
			cell.sub.Text = def.rarity
			cell.sub.TextColor3 = Theme.rarityColor(def.rarity)
		end
		cell.shiny.Visible = shinies[catId] ~= nil
	end
end

-- One row per owned cat instance. Rows are keyed by uid and rebuilt only when the set of uids changes.
function CatCollection._syncRoomRows(self: any, state: Types.PlayerState)
	local cats: { [string]: Types.CatInstance } = state.cats or {}
	local seen: { [string]: boolean } = {}
	local order: { Types.CatInstance } = {}
	for _, instance in cats do
		table.insert(order, instance)
	end
	local function ratingOf(instance: Types.CatInstance): number
		if instance.rating then
			return instance.rating :: number
		end
		local def: Types.CatDef? = self._catById[instance.catId]
		return if def then def.incomePerSecond else 0
	end
	table.sort(order, function(a: Types.CatInstance, b: Types.CatInstance): boolean
		local defA = self._catById[a.catId]
		local defB = self._catById[b.catId]
		local rarityA = if defA then rarityIndex(defA.rarity) else 0
		local rarityB = if defB then rarityIndex(defB.rarity) else 0
		if rarityA ~= rarityB then
			return rarityA > rarityB
		end
		local ratingA, ratingB = ratingOf(a), ratingOf(b)
		if ratingA ~= ratingB then
			return ratingA > ratingB
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
			row.portrait:destroy()
			row.frame:Destroy()
			self._roomRows[uid] = nil
		end
	end
end

function CatCollection._makeRoomRow(self: any, instance: Types.CatInstance)
	local def: Types.CatDef? = self._catById[instance.catId]
	local rarity = if def then def.rarity else "Common"
	local shiny = instance.variant == "shiny"
	local frame: Frame = Create("Frame", {
		Name = instance.uid,
		BackgroundColor3 = Theme.modal.card,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, ROOM_ROW),
		Parent = self._roomList,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		-- a shiny cat's card has a thicker gold edge, so it stands out in a long list
		Create("UIStroke", {
			Color = if shiny then Theme.colors.gold else Theme.rarityColor(rarity),
			Thickness = Theme.sizes.stroke + (if shiny then 1 else 0),
		}),
	})
	-- the cat's own model on a soft disc in its rarity colour (the book's look), held still so a long list is free
	Create("Frame", {
		Name = "Glow",
		BackgroundColor3 = Theme.rarityColor(rarity),
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 0),
		Size = UDim2.fromOffset(ROOM_ART - 8, ROOM_ART - 8),
		Parent = frame,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local portrait = CatPortrait.new({
		parent = frame,
		size = UDim2.fromOffset(ROOM_ART, ROOM_ART),
		anchorPoint = Vector2.new(0, 0.5),
		position = UDim2.new(0, 10, 0.5, 0),
		still = true,
		zIndex = 2,
	})
	if shiny then
		local badge = pill(
			frame,
			"✨",
			Theme.colors.gold,
			Theme.colors.goldText,
			UDim2.fromOffset(ROOM_ART - 2, 4),
			Vector2.new(1, 0)
		)
		badge.Name = "Shiny"
		badge.ZIndex = 3
	end
	local name = text({
		Name = "Name",
		Position = UDim2.fromOffset(ROOM_TEXT, 10),
		Size = UDim2.new(1, -(ROOM_TEXT + 288), 0, 24),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		Text = if def then def.name else instance.catId,
		Parent = frame,
	})
	local status = text({
		Name = "Status",
		Position = UDim2.fromOffset(ROOM_TEXT, 36),
		Size = UDim2.new(1, -(ROOM_TEXT + 288), 0, 18),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.subtext,
		Text = "",
		Parent = frame,
	})
	-- Favorite role tag (F25): a small pill under the status, gold while the cat works that role
	local favorite = text({
		Name = "FavoriteRole",
		Position = UDim2.fromOffset(ROOM_TEXT, 56),
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.modal.panel,
		TextSize = Theme.sizes.textTiny,
		TextColor3 = Theme.modal.subtext,
		TextTruncate = Enum.TextTruncate.None,
		Text = if def then "Loves " .. Format.roleName(def.favoriteRole) else "",
		Visible = def ~= nil,
		Parent = frame,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = favorite })
	Create(
		"UIPadding",
		{ PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = favorite }
	)
	local place = Button.new({
		name = "Place",
		text = "Assign",
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
		portrait = portrait,
		loaded = false, -- the model is cloned by _loadPortraits once the card is near the visible window
		name = name,
		status = status,
		favorite = favorite,
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
		local role: string = row.role
		local open, free = 0, 0
		local firstFree: string? = nil
		local nextTier: number? = nil
		for _, spot in row.slots :: { Types.SpotDef } do
			if state.tier >= spot.tier then
				open += 1
				if not occupied[spot.id] then
					free += 1
					firstFree = firstFree or spot.id
				end
			elseif nextTier == nil or spot.tier < (nextTier :: number) then
				nextTier = spot.tier
			end
		end
		row.freeSlot = firstFree
		local favorite = placingDef ~= nil and (placingDef :: Types.CatDef).favoriteRole == role
		row.label.Text = Format.roleName(role) .. (if favorite then "  ★ 1.5x" else "")
		row.label.TextColor3 = if favorite then Theme.colors.caramelDark else Theme.modal.text
		row.button:setStyle(if favorite then "gold" else "primary")
		if open == 0 then
			row.sub.Text = "Opens at " .. Format.tier(nextTier or 1)
			row.button:setText("Locked")
			row.button:setEnabled(false)
		elseif free == 0 then
			row.sub.Text = ("All %d taken"):format(open)
				.. (if nextTier then ", more at " .. Format.tier(nextTier :: number) else "")
			row.button:setText("Full")
			row.button:setEnabled(false)
		else
			row.sub.Text = ("%d of %d free"):format(free, open)
			row.button:setText("Assign")
			row.button:setEnabled(true)
		end
	end
end

-- N71: a cat room card clones its cat model only once it scrolls near the visible part of the list, so a big
-- collection pays for the cards on screen. A card whose model is not in Assets yet tries again on the next pass.
function CatCollection._loadPortraits(self: any)
	local list: ScrollingFrame = self._roomList
	if self._tab ~= "Room" or not self.frame.Visible then
		return
	end
	local top = list.AbsolutePosition.Y - PORTRAIT_MARGIN
	local bottom = list.AbsolutePosition.Y + list.AbsoluteSize.Y + PORTRAIT_MARGIN
	for _, row in self._roomRows do
		if row.loaded then
			continue
		end
		local y = row.frame.AbsolutePosition.Y
		if y + row.frame.AbsoluteSize.Y >= top and y <= bottom then
			row.portrait:set(row.def)
			row.loaded = row.portrait:hasModel()
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
	self._panel:setTitle(
		"Cat collection",
		("%d / %d found  ·  %s"):format(
			foundCount,
			total,
			Format.percent(if total > 0 then foundCount / total else 0)
		)
	)

	-- room tab only when the engineer sends cat instances
	local hasRoom = state.cats ~= nil
	self._roomTab.instance.Visible = hasRoom
	if not hasRoom and self._tab == "Room" then
		self:showTab("Book")
		return
	end

	if self._tab == "Book" then
		self:_renderBook(state, found)
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
			-- the player's name for the cat (filtered by the server), with the breed after it
			local custom: string? = instance.name
			local breed = if def then def.name else instance.catId
			row.name.Text = if custom and custom ~= ""
				then ("%s  (%s)"):format(custom, breed)
				else breed
			local rate = if instance.rating
				then instance.rating :: number
				elseif def then def.incomePerSecond
				else 0
			-- "Lv 3  ★★★★☆  $3.4/s" when the server sends stats, else just the rate
			local statBits = {}
			if instance.level then
				table.insert(statBits, Format.level(instance.level :: number))
			end
			if instance.stars then
				table.insert(statBits, Format.stars(instance.stars :: number))
			end
			local stats = table.concat(statBits, "  ")
			if instance.spotId then
				placed += 1
				local spot = spotsById[instance.spotId :: string]
				local favorite = def ~= nil
					and spot ~= nil
					and (def :: Types.CatDef).favoriteRole == spot.spotType
				local slotName = if spot
					then Format.roleName(spot.spotType) .. " " .. (spot.id:match("%d+$") or "")
					else instance.spotId :: string
				row.status.Text = ("%s%s  ·  %s%s"):format(
					if stats ~= "" then stats .. "  " else "",
					Format.rate(rate * (if favorite then 1.5 else 1)),
					slotName,
					if favorite then "  ·  favorite role" else ""
				)
				row.favorite.BackgroundColor3 = if favorite
					then Theme.colors.gold
					else Theme.modal.panel
				row.favorite.TextColor3 = if favorite
					then Theme.colors.goldText
					else Theme.modal.subtext
				row.place:setText("Move")
				row.remove:setEnabled(true)
				row.remove:setText("Rest")
			else
				resting += 1
				row.status.Text = ("%s%s when working  ·  Resting"):format(
					if stats ~= "" then stats .. "  " else "",
					Format.rate(rate)
				)
				row.favorite.BackgroundColor3 = Theme.modal.panel
				row.favorite.TextColor3 = Theme.modal.subtext
				row.place:setText("Assign")
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
		-- after the list layout has placed new cards
		task.defer(function()
			if self.frame.Parent ~= nil then
				self:_loadPortraits()
			end
		end)
	end
end

function CatCollection.destroy(self: any)
	for _, cell in self._cells do
		cell.connection:Disconnect()
		cell.portrait:destroy()
	end
	for _, chip in self._areaChips do
		chip.connection:Disconnect()
	end
	self._detailArt:destroy()
	self._roomScroll:Disconnect()
	for _, row in self._roomRows do
		row.place:destroy()
		row.remove:destroy()
		row.sell:destroy()
		row.portrait:destroy()
	end
	for _, row in self._spotRows do
		row.button:destroy()
	end
	for _, button in self._buttons do
		button:destroy()
	end
	self._bookTab:destroy()
	self._roomTab:destroy()
	self._equipBest:destroy()
	self._panel:destroy()
end

return CatCollection
