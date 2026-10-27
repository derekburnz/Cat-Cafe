--!strict
-- Collection screen with two tabs.
--   Book: the Pet Simulator index. A tab per area with its completion, then that area's cats as live 3D models
--         (dark silhouettes until found), rarest last; tap one for details.
--   Cat room: the cats the player owns as an inventory grid under a crew strip of role slots (Screens/CatRoom).
-- Needs state.cats and catalog.spots for the cat room; without them the tab is hidden.

local Button = require(script.Parent.Parent.Components.Button)
local CatPortrait = require(script.Parent.Parent.Components.CatPortrait)
local CatRoom = require(script.Parent.CatRoom)
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
	renameCat: (uid: string, name: string) -> (),
	equipBest: () -> (),
	unequipAll: () -> (),
	close: () -> (),
}

export type CatCollection = {
	frame: Frame,
	setCatalog: (self: CatCollection, catalog: Types.Catalog) -> (),
	render: (self: CatCollection, state: Types.PlayerState) -> (),
	showTab: (self: CatCollection, tab: "Book" | "Room") -> (),
	currentTab: (self: CatCollection) -> "Book" | "Room",
	destroy: (self: CatCollection) -> (),
}

local CELL = Vector2.new(112, 134)
local PORTRAIT = 84
local TAB_HEIGHT = 40
local DETAIL_HEIGHT = 92
local AREA_TAB_HEIGHT = 46
local PROGRESS_HEIGHT = 28
local FALLBACK_AREA = "alley"

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
	self._tab = "Book"
	self._selected = nil :: string?
	self._dirty = true
	self._lastState = nil :: Types.PlayerState?

	local panel = Panel.new({
		name = "Collection",
		color = Theme.colors.sky,
		icon = Theme.icons.cats,
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

	-- Cat room: the inventory grid and the crew strip (Screens/CatRoom)
	self._room = Create("Frame", {
		Name = "Room",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, bookTop),
		Size = UDim2.new(1, 0, 1, -bookTop),
		Visible = false,
		Parent = panel.content,
	})
	self._catRoom = CatRoom.new(self._room, {
		placeCat = callbacks.placeCat,
		unplaceCat = callbacks.unplaceCat,
		sellCat = callbacks.sellCat,
		renameCat = callbacks.renameCat,
		equipBest = callbacks.equipBest,
		unequipAll = callbacks.unequipAll,
	})

	return self :: CatCollection
end

function CatCollection.currentTab(self: any): "Book" | "Room"
	return self._tab
end

function CatCollection.showTab(self: any, tab: "Book" | "Room")
	self._tab = tab
	self._book.Visible = tab == "Book"
	self._room.Visible = tab == "Room"
	self._bookTab:setStyle(if tab == "Book" then "gold" else "ghost")
	self._roomTab:setStyle(if tab == "Room" then "gold" else "ghost")
	self._catRoom:reset()
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

function CatCollection.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	self:_buildBook()
	self._catRoom:setCatalog(catalog)
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
		self._catRoom:render(state)
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
	self._catRoom:destroy()
	self._bookTab:destroy()
	self._roomTab:destroy()
	self._panel:destroy()
end

return CatCollection
