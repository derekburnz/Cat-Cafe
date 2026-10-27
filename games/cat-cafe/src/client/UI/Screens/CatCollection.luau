--!strict
-- Collection screen with two tabs.
--   Index: the Pet Simulator index. A tab per area with its completion, then that area's cats as live 3D models
--         (dark silhouettes until found), rarest last; tap one for details. Above the cats, the area's reward
--         strip (Screens/IndexStrip, F48) pays at 3, 6 and 10 cats and all of them gold; a red badge on the Index
--         tab and on each area tab says a reward is waiting.
--   Decor: the Decor Index (F53, Screens/DecorIndex): a page per crate with its ten pieces and two rewards.
--   Beside the tabs, the forever bonuses the claimed rewards add up to (F54 v0.10): tips, gold luck with the gold
--   chance it gives, and faster bait, each in its track's colour (Components/IndexRewards.totals).
--   Cat room: the cats the player owns as an inventory grid under a crew strip of role slots (Screens/CatRoom).
-- Needs state.cats and catalog.spots for the cat room; without them the tab is hidden.

local Button = require(script.Parent.Parent.Components.Button)
local CatPortrait = require(script.Parent.Parent.Components.CatPortrait)
local CatRoom = require(script.Parent.CatRoom)
local CatVariant = require(script.Parent.Parent.Components.CatVariant)
local Create = require(script.Parent.Parent.Components.Create)
local DecorIndex = require(script.Parent.DecorIndex)
local DecorPieces = require(script.Parent.Parent.Components.DecorPieces)
local Format = require(script.Parent.Parent.Components.Format)
local IndexRewards = require(script.Parent.Parent.Components.IndexRewards)
local IndexStrip = require(script.Parent.IndexStrip)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local PrizeChips = require(script.Parent.Parent.Components.PrizeChips)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

export type Callbacks = {
	placeCat: (uid: string, spotId: string) -> (),
	unplaceCat: (uid: string) -> (),
	sellCat: (uid: string) -> (),
	lockCat: (uid: string, locked: boolean) -> (),
	renameCat: (uid: string, name: string) -> (),
	equipBest: () -> (),
	unequipAll: () -> (),
	claimIndexReward: (areaId: string, milestoneId: string) -> (),
	close: () -> (),
}

export type CatCollection = {
	frame: Frame,
	setCatalog: (self: CatCollection, catalog: Types.Catalog) -> (),
	render: (self: CatCollection, state: Types.PlayerState) -> (),
	showTab: (self: CatCollection, tab: Tab) -> (),
	showArea: (self: CatCollection, areaId: string) -> (),
	setNight: (self: CatCollection, night: boolean) -> (),
	currentTab: (self: CatCollection) -> Tab,
	destroy: (self: CatCollection) -> (),
}

export type Tab = "Index" | "Decor" | "Room"

local CELL = Vector2.new(112, 134)
local PORTRAIT = 84
local TAB_HEIGHT = 40
local DETAIL_HEIGHT = 92
local AREA_TAB_HEIGHT = 46
local PROGRESS_HEIGHT = 28
local PERK_HEIGHT = 26 -- a forever bonus pill beside the tabs
local FALLBACK_AREA = "alley"
local ALL_AREA = IndexRewards.ALL_AREA
local PORTRAITS_PER_FRAME = 10 -- the All Cats page clones its 50 models over a few frames

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

-- A red count badge on a tab's top right corner, hidden until something is waiting (F48).
local function badge(parent: Instance, size: number): (Frame, TextLabel)
	local dot: Frame = Create("Frame", {
		Name = "Badge",
		BackgroundColor3 = Theme.colors.red,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(size, size),
		Visible = false,
		ZIndex = 6,
		Parent = parent,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(dot, 2)
	local mark = text({
		Name = "Count",
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textTiny,
		TextColor3 = Theme.colors.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		ZIndex = 7,
		Parent = dot,
	})
	return dot, mark
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
	self._area = nil :: string? -- the Index's open area tab
	self._areaRank = {} :: { [string]: number } -- each area's place in the tab row, for the All Cats page's order
	self._loadToken = 0 -- the latest portrait queue's, so an older one stops
	self._detailId = nil :: string? -- the cat in the detail strip's portrait
	self._tab = "Index"
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
	self._indexTab = Button.new({
		name = "IndexTab",
		text = "Index",
		style = "gold",
		size = UDim2.fromOffset(120, TAB_HEIGHT),
		textSize = Theme.sizes.textBody,
		layoutOrder = 1,
		parent = tabs,
		sound = "uiTab",
		onClick = function()
			self:showTab("Index")
		end,
	})
	self._indexBadge, self._indexBadgeCount = badge(self._indexTab.instance, 24)
	self._decorTab = Button.new({
		name = "DecorTab",
		text = "Decor",
		style = "ghost",
		size = UDim2.fromOffset(120, TAB_HEIGHT),
		textSize = Theme.sizes.textBody,
		layoutOrder = 2,
		parent = tabs,
		sound = "uiTab",
		onClick = function()
			self:showTab("Decor")
		end,
	})
	self._decorTab.instance.Visible = false
	self._decorBadge, self._decorBadgeCount = badge(self._decorTab.instance, 24)
	self._roomTab = Button.new({
		name = "RoomTab",
		text = "Cat room",
		style = "ghost",
		size = UDim2.fromOffset(120, TAB_HEIGHT),
		textSize = Theme.sizes.textBody,
		layoutOrder = 3,
		parent = tabs,
		sound = "uiTab",
		onClick = function()
			self:showTab("Room")
		end,
	})

	-- the forever bonuses, right of the tabs; shrinks to fit the room the tabs leave on a narrow screen
	local perks: Frame = Create("Frame", {
		Name = "Forever",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, TAB_HEIGHT),
		Visible = false,
		Parent = panel.content,
	})
	local perksLayout: UIListLayout = Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = perks,
	})
	local perksScale: UIScale = Create("UIScale", { Parent = perks })
	text({
		Name = "Caption",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, PERK_HEIGHT),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.subtext,
		TextTruncate = Enum.TextTruncate.None,
		Text = "Forever",
		Parent = perks,
	})
	self._perks = perks
	self._perkPills = {} :: { [string]: TextLabel }
	for order, perk in IndexRewards.PERKS do
		local label: TextLabel =
			pill(perks, "", PrizeChips.perkColor(perk), Theme.colors.white, UDim2.new())
		label.Name = perk
		label.LayoutOrder = order
		label.Size = UDim2.fromOffset(0, PERK_HEIGHT)
		label.TextSize = Theme.sizes.textSmall
		label.Visible = false
		Outline.border(label, 2)
		Outline.text(label, 1.5)
		self._perkPills[perk] = label
	end
	local tabsLayout = tabs:FindFirstChildOfClass("UIListLayout")
	local function fitPerks()
		-- AbsoluteContentSize already includes the UIScale, so divide it back out for the row's own width
		local natural = perksLayout.AbsoluteContentSize.X / math.max(perksScale.Scale, 0.01)
		local used = if tabsLayout then tabsLayout.AbsoluteContentSize.X else 0
		local room = panel.content.AbsoluteSize.X - used - Theme.sizes.gap
		perksScale.Scale = if room > 0 and natural > room then room / natural else 1
	end
	perksLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fitPerks)
	panel.content:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitPerks)
	if tabsLayout then
		tabsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fitPerks)
	end

	-- Index: detail strip + grid of sections
	local indexTop = TAB_HEIGHT + Theme.sizes.gap
	self._index = Create("Frame", {
		Name = "Index",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, indexTop),
		Size = UDim2.new(1, 0, 1, -indexTop),
		Parent = panel.content,
	})
	local detail: Frame = Create("Frame", {
		Name = "Detail",
		BackgroundColor3 = Theme.modal.card,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, DETAIL_HEIGHT),
		Parent = self._index,
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
		Parent = self._index,
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
		Parent = self._index,
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
		scroller("Grid", self._index, UDim2.fromOffset(0, gridTop), UDim2.new(1, 0, 1, -gridTop))
	-- the area's reward strip scrolls with the cats, so the grid keeps its height
	self._strip = IndexStrip.new(self._grid, { claim = callbacks.claimIndexReward })
	self._cellsFrame = Create("Frame", {
		Name = "Cells",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 1,
		Parent = self._grid,
	}, {
		Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(CELL.X, CELL.Y),
			CellPadding = UDim2.fromOffset(gap, gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- Decor Index: a page per crate (Screens/DecorIndex)
	self._decor = Create("Frame", {
		Name = "Decor",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, indexTop),
		Size = UDim2.new(1, 0, 1, -indexTop),
		Visible = false,
		Parent = panel.content,
	})
	self._decorIndex = DecorIndex.new(self._decor, { claim = callbacks.claimIndexReward })

	-- Cat room: the inventory grid and the crew strip (Screens/CatRoom)
	self._room = Create("Frame", {
		Name = "Room",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, indexTop),
		Size = UDim2.new(1, 0, 1, -indexTop),
		Visible = false,
		Parent = panel.content,
	})
	self._catRoom = CatRoom.new(self._room, {
		placeCat = callbacks.placeCat,
		unplaceCat = callbacks.unplaceCat,
		sellCat = callbacks.sellCat,
		lockCat = callbacks.lockCat,
		renameCat = callbacks.renameCat,
		equipBest = callbacks.equipBest,
		unequipAll = callbacks.unequipAll,
	})

	return self :: CatCollection
end

function CatCollection.currentTab(self: any): Tab
	return self._tab
end

function CatCollection.showTab(self: any, tab: Tab)
	self._tab = tab
	self._index.Visible = tab == "Index"
	self._decor.Visible = tab == "Decor"
	self._room.Visible = tab == "Room"
	self._indexTab:setStyle(if tab == "Index" then "gold" else "ghost")
	self._decorTab:setStyle(if tab == "Decor" then "gold" else "ghost")
	self._roomTab:setStyle(if tab == "Room" then "gold" else "ghost")
	self._catRoom:reset()
	if self._lastState then
		self._dirty = true
		self:render(self._lastState)
	end
end

-- The Index tab on an area's page (an Index Board's prompt, F50).
function CatCollection.showArea(self: any, areaId: string)
	self._area = areaId
	self._grid.CanvasPosition = Vector2.zero
	self:showTab("Index")
end

-- The reward strip prices prizes that grow with the cafe from the day rate (the synced income drops after dark).
function CatCollection.setNight(self: any, night: boolean)
	self._strip:setNight(night)
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

-- The Index's areas in tier order: the catalog's areas, else the areas the cats name in catalog order.
type IndexArea = { id: string, name: string, tier: number }

local function indexAreas(catalog: Types.Catalog): { IndexArea }
	local list: { IndexArea } = {}
	local seen: { [string]: boolean } = {}
	local areas: { Types.AreaDef } = catalog.areas or {}
	for _, area in areas do
		seen[area.id] = true
		table.insert(list, { id = area.id, name = area.name, tier = area.tier })
	end
	table.sort(list, function(a: IndexArea, b: IndexArea): boolean
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

function CatCollection._buildIndex(self: any)
	self._loadToken += 1 -- the queued portraits are about to go
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

	local areas = indexAreas(catalog)
	-- the All Cats page last (F54, golden-fish.md 5b): every area's cats together, never locked
	table.insert(areas, { id = ALL_AREA, name = Format.areaName(ALL_AREA), tier = 0 })
	table.clear(self._areaRank)
	local gap = Theme.sizes.gap
	for order, area in areas do
		self._areaRank[area.id] = order
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
		local dot, dotCount = badge(chip, 20)
		-- six tabs share the row, so a long name ("Neighbourhood") shrinks to fit a phone (N162)
		local name = text({
			Name = "Name",
			Position = UDim2.fromOffset(4, 3),
			Size = UDim2.new(1, -8, 0, 22),
			FontFace = Theme.fonts.display,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = area.name,
			Parent = chip,
		})
		Create("UITextSizeConstraint", {
			MaxTextSize = Theme.sizes.textSmall + 1,
			MinTextSize = 9,
			Parent = name,
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
			dot = dot,
			dotCount = dotCount,
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
			"Gold",
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
			order = rarityIndex(rarity) * 1000 + index,
			connection = connection,
		}
	end
end

function CatCollection.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	self:_buildIndex()
	self._catRoom:setCatalog(catalog)
	self._strip:setCatalog(catalog)
	self._decorIndex:setCatalog(catalog)
	-- the Decor tab shows once the catalog has crates to fill its pages
	self._decorTab.instance.Visible = #DecorPieces.pools(catalog) > 0
	self._dirty = true
end

-- The open area's page: chips with each area's count, the progress strip, and that area's cells. Each cell's
-- model is cloned the first time its page opens (a few per frame, _loadPortraits), and again on later renders
-- until Assets has it. The All Cats page shows every cat, grouped by area in tab order and rarest last in each.
function CatCollection._renderIndex(
	self: any,
	state: Types.PlayerState,
	found: { [string]: boolean },
	ready: { [string]: number }
)
	local totals: { [string]: number } = {}
	local foundIn: { [string]: number } = {}
	for catId, cell in self._cells do
		local areaId: string = cell.def.area or FALLBACK_AREA
		totals[areaId] = (totals[areaId] or 0) + 1
		totals[ALL_AREA] = (totals[ALL_AREA] or 0) + 1
		if found[catId] then
			foundIn[areaId] = (foundIn[areaId] or 0) + 1
			foundIn[ALL_AREA] = (foundIn[ALL_AREA] or 0) + 1
		end
	end

	-- first open: the first area the player can reach that still has cats to find
	if self._area == nil then
		for _, chip in self._areaChips do
			if
				chip.id ~= ALL_AREA
				and state.tier >= chip.tier
				and (foundIn[chip.id] or 0) < (totals[chip.id] or 0)
			then
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
		local waiting = ready[chip.id] or 0
		chip.dot.Visible = waiting > 0
		chip.dotCount.Text = tostring(waiting)
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

	if open then
		self._strip:render(state, open)
	end

	local shinies: { [string]: number } = CatVariant.collection(state)
	local all = open == ALL_AREA
	local toLoad = {}
	for catId, cell in self._cells do
		local def: Types.CatDef = cell.def
		local areaId: string = def.area or FALLBACK_AREA
		local onPage = all or areaId == open
		cell.frame.Visible = onPage
		if not onPage then
			continue
		end
		cell.frame.LayoutOrder = if all
			then (self._areaRank[areaId] or 0) * 100000 + cell.order
			else cell.order
		if not cell.loaded then
			table.insert(toLoad, cell)
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
	self:_loadPortraits(toLoad)
end

-- Clones the page's missing cat models in grid order, PORTRAITS_PER_FRAME now and as many each frame after, so
-- the All Cats page does not clone 50 models in one frame. A newer render or page takes over the queue.
function CatCollection._loadPortraits(self: any, cells: { any })
	table.sort(cells, function(a: any, b: any): boolean
		return a.frame.LayoutOrder < b.frame.LayoutOrder
	end)
	self._loadToken += 1
	local token = self._loadToken
	local function load(first: number)
		for index = first, math.min(first + PORTRAITS_PER_FRAME - 1, #cells) do
			local cell = cells[index]
			if not cell.loaded and cell.frame.Visible then
				cell.portrait:set(cell.def)
				cell.loaded = cell.portrait:hasModel()
			end
		end
	end
	load(1)
	if #cells <= PORTRAITS_PER_FRAME then
		return
	end
	task.spawn(function()
		for first = PORTRAITS_PER_FRAME + 1, #cells, PORTRAITS_PER_FRAME do
			task.wait()
			if self._loadToken ~= token then
				return
			end
			load(first)
		end
	end)
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

	-- the Index and Decor tabs' badges count rewards waiting on their pages, whichever tab is open
	local ready: { [string]: number } = {}
	if catalog then
		ready = IndexRewards.claimable(catalog, state)
	end
	local waiting, decorWaiting = 0, 0
	for areaId, count in ready do
		if DecorPieces.poolOf(areaId) then
			decorWaiting += count
		else
			waiting += count
		end
	end
	if waiting > 0 and not self._indexBadge.Visible then
		Tween.popIn(self._indexBadge, 0.5)
	end
	self._indexBadge.Visible = waiting > 0
	self._indexBadgeCount.Text = tostring(waiting)
	if decorWaiting > 0 and not self._decorBadge.Visible then
		Tween.popIn(self._decorBadge, 0.5)
	end
	self._decorBadge.Visible = decorWaiting > 0
	self._decorBadgeCount.Text = tostring(decorWaiting)
	self:_renderPerks(state)

	-- room tab only when the engineer sends cat instances
	local hasRoom = state.cats ~= nil
	self._roomTab.instance.Visible = hasRoom
	if not hasRoom and self._tab == "Room" then
		self:showTab("Index")
		return
	end

	if self._tab == "Index" then
		self:_renderIndex(state, found, ready)
		if self._selected then
			self:_select(self._selected)
		end
	elseif self._tab == "Decor" then
		self._decorIndex:render(state)
	else
		self._catRoom:render(state)
	end
end

-- The forever bonuses beside the tabs, on the Index and Decor tabs, once the player has any.
function CatCollection._renderPerks(self: any, state: Types.PlayerState)
	local catalog: Types.Catalog? = self._catalog
	local any = false
	if catalog then
		local totals = IndexRewards.totals(catalog, state)
		for _, perk in IndexRewards.PERKS do
			local label = IndexRewards.perkLabel(perk, (totals :: any)[perk] or 0)
			local pillLabel: TextLabel = self._perkPills[perk]
			pillLabel.Visible = label ~= nil
			pillLabel.Text = label or ""
			any = any or label ~= nil
		end
	end
	self._perks.Visible = any and self._tab ~= "Room"
end

function CatCollection.destroy(self: any)
	self._loadToken += 1
	for _, cell in self._cells do
		cell.connection:Disconnect()
		cell.portrait:destroy()
	end
	for _, chip in self._areaChips do
		chip.connection:Disconnect()
	end
	self._detailArt:destroy()
	self._catRoom:destroy()
	self._strip:destroy()
	self._decorIndex:destroy()
	self._indexTab:destroy()
	self._decorTab:destroy()
	self._roomTab:destroy()
	self._panel:destroy()
end

return CatCollection
