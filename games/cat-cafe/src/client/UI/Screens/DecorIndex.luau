--!strict
-- The Decor Index (F53, golden-fish.md section 4): the Collection's Decor tab. #4265 (Derek 2026-11-14: "make the decor
-- index like the cats index in the way that you just scroll through downward through the areas of index instead of
-- how it is now with having to expand each one"): one scroll down the dark page, a section per crate (Alley, Park,
-- Neighbourhood, Woods, Sewer, Classic and the newer areas) in the catalog's order, each open, like the Cats index
-- (Screens/CatCollection). A section's header line has its name in its area's colour, "3 / 12" or "Complete!", a slim
-- bar and a Rewards button; under it its pieces, rarest last, as "?" tiles until owned and then with their name,
-- rarity, kind and tip bonus. The Rewards button opens the section's reward strip (Screens/IndexStrip) under the
-- header: 15 golden fish at 5 pieces (decor5) and +5% tips forever at all of them (decor10, whose `needs` the catalog
-- sets), which also puts a gold frame round the section's pieces. The button turns green as Claim! with a red count
-- while a reward waits. Counts come from state.decorOwned (Components/DecorPieces).
-- #1766 (Derek2 couldn't tell whether the Rally set exists): the Rally section opens with "From the Rescue Rally,
-- every weekend", and a Rally piece not owned yet reads "Rally Crate" in place of "???".
-- #3722: no cells at start-up; a section's cells are built when it first comes near view.

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local DecorPieces = require(script.Parent.Parent.Components.DecorPieces)
local Format = require(script.Parent.Parent.Components.Format)
local IndexRewards = require(script.Parent.Parent.Components.IndexRewards)
local IndexStrip = require(script.Parent.IndexStrip)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local MenuFamily = require(script.Parent.Parent.Components.MenuFamily)
local Outline = require(script.Parent.Parent.Components.Outline)
local Scale = require(script.Parent.Parent.Scale)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

-- the dark window palette (#1028), in place of Theme.modal
local PAL = MenuFamily.pal
local CARD = MenuFamily.card -- #3558: what sits on a picture card (cream in the family look)

export type Callbacks = {
	claim: (areaId: string, milestoneId: string) -> (),
}

export type DecorIndex = {
	frame: Frame,
	setCatalog: (self: DecorIndex, catalog: Types.Catalog) -> (),
	render: (self: DecorIndex, state: Types.PlayerState) -> (),
	destroy: (self: DecorIndex) -> (),
}

type Section = {
	pool: string,
	name: string,
	color: Color3,
	frame: Frame,
	count: TextLabel,
	fill: Frame,
	rewards: any, -- Button
	dot: Frame,
	dotCount: TextLabel,
	slot: Frame,
	strip: any?, -- IndexStrip, built the first time the strip opens
	expanded: boolean,
	cellsFrame: Frame,
	frameStroke: UIStroke,
	cells: { Cell },
	built: boolean,
}

type Cell = {
	def: Types.DecorDef,
	frame: Frame,
	icon: ItemIcon.ItemIcon,
	kind: TextLabel,
	name: TextLabel,
	sub: TextLabel,
}

-- #2735 (Derek2: "see which decor images to make more clear/bigger since so many players are on mobile"): on touch
-- a bigger picture in a wider, taller cell (96 px, about 65 on a phone, was about 50)
local ICON = if Scale.isTouch() then 96 else 76
local CELL = Vector2.new(112 + (ICON - 76), 134 + (ICON - 76))
local HEADER_HEIGHT = 52 -- as the Cats index's area lines (Screens/CatCollection)
local REWARDS = Vector2.new(124, 40) -- a section's Rewards button
local NAME_W = 200
local BAR_H = 10
local NEAR = 1.5 -- a section's cells are built once its top is within this many views of the visible page (#3722)
local RALLY_POOL = "rally" -- shared Catalog.RALLY_POOL: the Rescue Rally's own crate, never sold (F101)
local RALLY_SOURCE = "From the Rescue Rally, every weekend"
local RALLY_LOCKED = "Rally Crate"
local FULL_MILESTONE = "decor10" -- the whole section's milestone (all 12 since F80), whose claim puts on the gold frame

local DecorIndex = {}
DecorIndex.__index = DecorIndex

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textBody,
		TextColor3 = CARD.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

-- A section's name: its plain crate's name without " Crate" ("Alley"), else the area's name.
local function poolName(catalog: Types.Catalog, pool: string): string
	local crates: { Types.CrateDef } = catalog.crates or {}
	for _, crate in crates do
		if not crate.golden and crate.area == pool then
			return (crate.name:gsub(" Crate$", ""))
		end
	end
	return Format.areaName(pool)
end

-- The red count on a Rewards button, as on the Cats index's.
local function badge(parent: Instance): (Frame, TextLabel)
	local dot: Frame = Create("Frame", {
		Name = "Badge",
		BackgroundColor3 = Theme.colors.red,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(20, 20),
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

function DecorIndex.new(parent: Instance, callbacks: Callbacks): DecorIndex
	local self = setmetatable({}, DecorIndex) :: any
	self._callbacks = callbacks
	self._catalog = nil :: Types.Catalog?
	self._sections = {} :: { Section }
	self._state = nil :: Types.PlayerState?
	self._rewardsH = Scale.tapHeight(REWARDS.Y + 1, Theme.sizes.buttonDepth)

	local gap = Theme.sizes.gap
	self.frame = Create("Frame", {
		Name = "DecorIndex",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	})
	self._grid = Create("ScrollingFrame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = PAL.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		VerticalScrollBarInset = Enum.ScrollBarInset.Always, -- #4324: no scroll-bar width feedback loop
		Parent = self.frame,
	}, {
		Create(
			"UIListLayout",
			{ Padding = UDim.new(0, gap * 2), SortOrder = Enum.SortOrder.LayoutOrder }
		),
		-- room over the first Rewards button for its red badge, and round the cells for their outlines
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, Outline.ROOM + 2),
			PaddingRight = UDim.new(0, Outline.ROOM + 4),
			PaddingTop = UDim.new(0, Outline.ROOM + 8),
			PaddingBottom = UDim.new(0, Outline.ROOM + 4),
		}),
	})
	local grid: ScrollingFrame = self._grid
	self._scrolled = grid:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		self:_buildNear()
	end)
	self._resized = grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_fitCells()
		self:_buildNear()
	end)
	self._empty = text({
		Name = "Empty",
		LayoutOrder = 1000,
		Size = UDim2.new(1, 0, 0, 40),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = PAL.subtext,
		Text = "The pieces arrive with the next update. Open crates at the Golden Fish Market.",
		Visible = false,
		Parent = grid,
	})
	return self :: DecorIndex
end

function DecorIndex._clear(self: any)
	for _, section: Section in self._sections do
		for _, cell: Cell in section.cells do
			cell.icon:destroy()
		end
		if section.strip then
			section.strip:destroy()
		end
		section.rewards:destroy()
		section.frame:Destroy()
	end
	table.clear(self._sections)
end

-- One section: its header line (name, count, bar, Rewards), the Rally's source line, the reward strip's slot and the
-- frame its cells go in (empty until _buildCells).
function DecorIndex._buildSection(
	self: any,
	catalog: Types.Catalog,
	pool: string,
	order: number
): Section
	local gap = Theme.sizes.gap
	local name = poolName(catalog, pool)
	local color = Theme.areaColors[pool] or Theme.colors.caramel
	local frame: Frame = Create("Frame", {
		Name = pool,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = order,
		Parent = self._grid,
	}, {
		Create(
			"UIListLayout",
			{ Padding = UDim.new(0, gap), SortOrder = Enum.SortOrder.LayoutOrder }
		),
	})
	local rewardsH: number = self._rewardsH
	local header: Frame = Create("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, math.max(HEADER_HEIGHT, rewardsH + 4)),
		LayoutOrder = 1,
		Parent = frame,
	})
	local title = text({
		Name = "Area",
		Size = UDim2.new(0, NAME_W, 0, 30),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge + 2,
		TextColor3 = color,
		Text = name,
		Parent = header,
	})
	Outline.text(title, 2.5)
	local count = text({
		Name = "Count",
		Position = UDim2.fromOffset(NAME_W + 8, 2),
		Size = UDim2.new(1, -(NAME_W + 8 + REWARDS.X + 12), 0, 28),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		TextColor3 = Theme.index.text,
		Parent = header,
	})
	Outline.text(count, 1.5)
	local track: Frame = Create("Frame", {
		Name = "Track",
		BackgroundColor3 = Theme.index.track,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, -(REWARDS.X + 12), 0, BAR_H),
		Parent = header,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(track, 2)
	local fill: Frame = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.shade(fill, 0.2)
	if pool == RALLY_POOL then
		text({
			Name = "Source",
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 24),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody,
			TextColor3 = Theme.colors.gold,
			Text = RALLY_SOURCE,
			Parent = frame,
		})
	end
	local slot: Frame = Create("Frame", {
		Name = "Rewards",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 3,
		Visible = false,
		Parent = frame,
	})
	local cellsFrame: Frame = Create("Frame", {
		Name = "Cells",
		BackgroundColor3 = Theme.colors.gold,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 4,
		Parent = frame,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(CELL.X, CELL.Y),
			CellPadding = UDim2.fromOffset(gap, gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	-- a full section wears a gold frame round its pieces
	local frameStroke: UIStroke = Create("UIStroke", {
		Color = Theme.colors.gold,
		Thickness = 4,
		Enabled = false,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = cellsFrame,
	})
	local section: Section = {
		pool = pool,
		name = name,
		color = color,
		frame = frame,
		count = count,
		fill = fill,
		rewards = nil :: any,
		dot = nil :: any,
		dotCount = nil :: any,
		slot = slot,
		strip = nil,
		expanded = false,
		cellsFrame = cellsFrame,
		frameStroke = frameStroke,
		cells = {},
		built = false,
	}
	section.rewards = Button.new({
		name = "Rewards",
		text = "Rewards",
		style = "ghost",
		size = UDim2.fromOffset(REWARDS.X, rewardsH),
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, 0, 0.5, 0),
		textSize = Theme.sizes.textSmall + 1,
		parent = header,
		sound = "uiTab",
		onClick = function()
			self:_toggleRewards(section)
		end,
	})
	section.dot, section.dotCount = badge(section.rewards.instance)
	return section
end

-- Opens or shuts a section's reward strip; the strip is built the first time it opens.
function DecorIndex._toggleRewards(self: any, section: Section)
	section.expanded = not section.expanded
	if section.expanded and section.strip == nil then
		local strip = IndexStrip.new(section.slot, { claim = self._callbacks.claim })
		local catalog: Types.Catalog? = self._catalog
		if catalog then
			strip:setCatalog(catalog)
		end
		section.strip = strip
	end
	section.slot.Visible = section.expanded
	local state: Types.PlayerState? = self._state
	if state then
		self:render(state)
	end
end

function DecorIndex.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	self:_clear()
	for order, pool in DecorPieces.pools(catalog) do
		local section: Section = self:_buildSection(catalog, pool, order)
		table.insert(self._sections, section)
	end
end

-- As the Cats grid (#3961): as many CELL-wide columns as fit, each widened to share the leftover room, so no empty
-- strip is left at the right. The page's own scale is read off a Rewards button (REWARDS.X design px).
function DecorIndex._fitCells(self: any)
	local first: Section? = self._sections[1]
	if first == nil then
		return
	end
	local scale = first.rewards.instance.AbsoluteSize.X / REWARDS.X
	local width = first.cellsFrame.AbsoluteSize.X
	if scale <= 0 or width <= 0 then
		return
	end
	local gap = Theme.sizes.gap
	local columns = math.max(1, math.floor((width / scale + gap) / (CELL.X + gap)))
	local size = UDim2.new(1 / columns, -math.ceil(gap * (columns - 1) / columns), 0, CELL.Y)
	for _, section: Section in self._sections do
		local layout = section.cellsFrame:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout?
		if layout then
			layout.CellSize = size
		end
	end
end

-- #3722: a section's cells, built once.
function DecorIndex._buildCells(self: any, section: Section)
	local catalog: Types.Catalog? = self._catalog
	if catalog == nil or section.built then
		return
	end
	section.built = true
	for index, def in DecorPieces.poolPieces(catalog, section.pool) do
		local cell: Cell = self:_buildCell(section.cellsFrame, def, index)
		table.insert(section.cells, cell)
	end
end

-- Whether the page shows: it and every GuiObject over it visible (the Collection's other tabs hide it).
local function shown(gui: Instance): boolean
	local node: Instance? = gui
	while node ~= nil and node:IsA("GuiObject") do
		if not (node :: GuiObject).Visible then
			return false
		end
		node = node.Parent
	end
	return true
end

-- #3722: builds the cells of every section whose top is in view or within NEAR views under it, then paints them.
-- Only once the page has been drawn (render) and while it shows.
function DecorIndex._buildNear(self: any)
	local grid: ScrollingFrame = self._grid
	local height = grid.AbsoluteSize.Y
	if self._state == nil or height <= 0 or not shown(grid) then
		return
	end
	local reach = grid.AbsolutePosition.Y + height * (1 + NEAR)
	local any = false
	for _, section: Section in self._sections do
		if not section.built and section.frame.AbsolutePosition.Y <= reach then
			self:_buildCells(section)
			any = true
		end
	end
	local state: Types.PlayerState? = self._state
	if any and state then
		self:_paintCells(state)
	end
end

function DecorIndex._buildCell(
	self: any,
	parent: Instance,
	def: Types.DecorDef,
	order: number
): Cell
	local frame: Frame = Create("Frame", {
		Name = def.id,
		BackgroundColor3 = CARD.card,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = parent,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	Outline.border(frame, Theme.sizes.outline + 1, Theme.rarityColor(DecorPieces.info(def).rarity))
	local icon = ItemIcon.new({
		parent = frame,
		size = UDim2.fromOffset(ICON, ICON),
		anchorPoint = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, 6),
	})
	-- the kind as a small glyph in the top left corner: wallpaper, floor, paint, door, cat flap, furniture or decoration
	local kind = text({
		Name = "Kind",
		Position = UDim2.fromOffset(4, 2),
		Size = UDim2.fromOffset(24, 24),
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		Text = DecorPieces.kindIcon(DecorPieces.info(def).kind, ""),
		ZIndex = 3,
		Parent = frame,
	})
	local name = text({
		Name = "Name",
		Position = UDim2.fromOffset(6, ICON + 10),
		Size = UDim2.new(1, -12, 0, 20),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall + 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "???",
		Parent = frame,
	})
	local sub = text({
		Name = "Sub",
		Position = UDim2.fromOffset(6, ICON + 30),
		Size = UDim2.new(1, -12, 0, 18),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textTiny,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = frame,
	})
	return { def = def, frame = frame, icon = icon, kind = kind, name = name, sub = sub }
end

function DecorIndex.render(self: any, state: Types.PlayerState)
	self._state = state
	local catalog: Types.Catalog? = self._catalog
	if catalog == nil then
		return
	end
	local ready = IndexRewards.claimable(catalog, state)
	for _, section: Section in self._sections do
		local have, all = DecorPieces.pageCounts(catalog, state, section.pool)
		local full = all > 0 and have >= all
		local area = DecorPieces.areaOf(section.pool)
		section.count.Text = if full then "Complete!" else ("%d / %d"):format(have, all)
		section.count.TextColor3 = if full then Theme.colors.gold else Theme.index.text
		section.fill.Size = UDim2.fromScale(if all > 0 then have / all else 0, 1)
		section.fill.BackgroundColor3 = if full then Theme.colors.gold else section.color
		local waiting = ready[area] or 0
		section.dot.Visible = waiting > 0 and not section.expanded
		section.dotCount.Text = tostring(waiting)
		local prizes = catalog.indexPrizes and catalog.indexPrizes[area]
		section.rewards.instance.Visible = prizes ~= nil
		section.rewards:setText(
			if section.expanded then "Hide" elseif waiting > 0 then "Claim!" else "Rewards"
		)
		section.rewards:setStyle(
			if waiting > 0 and not section.expanded then "primary" else "ghost"
		)
		if section.strip then
			section.strip:render(state, area)
		end
		-- the gold frame comes with the all-twelve reward (or with a full section when the catalog has no reward)
		local hasReward = prizes ~= nil and prizes[FULL_MILESTONE] ~= nil
		section.frameStroke.Enabled = full
			and (IndexRewards.isClaimed(state, area, FULL_MILESTONE) or not hasReward)
		section.cellsFrame.BackgroundTransparency = if section.frameStroke.Enabled then 0.85 else 1
	end
	self._empty.Visible = #self._sections == 0
	self:_fitCells()
	self:_buildNear()
	self:_paintCells(state)
end

-- Each built cell: "?" until owned, then its picture, name, rarity and bonus.
function DecorIndex._paintCells(self: any, state: Types.PlayerState)
	for _, section: Section in self._sections do
		local rally = section.pool == RALLY_POOL
		for _, cell: Cell in section.cells do
			local piece = DecorPieces.info(cell.def)
			local owned = state.decorOwned[cell.def.id] == true
			cell.icon:set(
				if owned then cell.def.asset else nil,
				if owned then DecorPieces.kindIcon(piece.kind, Theme.icons.decor) else "?",
				if owned then piece.rarity else nil,
				if owned then ShopIcons.decor(cell.def.id) else nil
			)
			cell.kind.Visible = owned
			cell.name.Text = if owned then cell.def.name elseif rally then RALLY_LOCKED else "???"
			cell.name.TextColor3 = if owned then CARD.text else CARD.subtext
			local rarity = piece.rarity or ""
			cell.sub.Text = if owned
				then ("%s · +%s"):format(rarity, Format.percent(cell.def.bonus or 0))
				else rarity
			cell.sub.TextColor3 = if owned then CARD.subtext else Theme.rarityColor(piece.rarity)
		end
	end
end

function DecorIndex.destroy(self: any)
	self._scrolled:Disconnect()
	self._resized:Disconnect()
	self:_clear()
	self.frame:Destroy()
end

return DecorIndex
