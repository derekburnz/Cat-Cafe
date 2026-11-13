--!strict
-- The Decor Index (F53, golden-fish.md section 4): the Collection's Decor tab. A page per crate (Alley, Park,
-- Neighbourhood, Woods, Sewer, Classic) with its pieces (twelve since F80 added a door set and a cat flap), rarest
-- last, as "?" tiles until owned and then with their name, rarity, kind and tip bonus. Above them the page's reward
-- strip (Screens/IndexStrip) pays 25 golden fish at 5 pieces (decor5) and +5% tips forever at all of them (decor10,
-- whose `needs` the catalog sets, 12 since F80), which also puts a gold frame on the page. The
-- page tabs carry a red badge when a reward is waiting. Counts come from state.decorOwned (Components/DecorPieces).
-- #1766 (Derek2 couldn't tell whether the Rally set exists): the Rally page, whose crate is never sold, opens with
-- "From the Rescue Rally, every weekend", and a Rally piece not owned yet reads "Rally Crate" in place of "???".

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
local Sound = require(script.Parent.Parent.Components.Sound)
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

type Chip = {
	pool: string,
	name: string,
	color: Color3,
	frame: TextButton,
	border: UIStroke,
	label: TextLabel,
	count: TextLabel,
	dot: Frame,
	dotCount: TextLabel,
	connection: RBXScriptConnection,
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
local CHIP_HEIGHT = 46
-- #2675: a page tab is never narrower than this (design px), so "Neighbourhood" keeps a 9 px name on a phone; with
-- more pages than fit, the row scrolls sideways
local TAB_MIN = 100
-- #3931 (Derek 2026-11-13: "the decor menu side gets cut off for the new areas"): when the tabs would go under TAB_MIN
-- in one row they wrap into rows of equal tabs, up to TAB_ROWS, each at least TAB_WRAP_MIN, so every area shows
local TAB_ROWS = 3
local TAB_WRAP_MIN = 84
-- #3931 (Review-QA): on a short screen (a phone held sideways) the rows of tabs left no decor in view, so there the
-- tabs stand in a column down the left side, RAIL_W wide, scrolling when they do not fit, with the page beside them
local RAIL_W = 112
local TAB_PAD = 3 -- room for a tab's outline inside the clipping row
local TAB_BADGE = 4 -- and more above and right of the tabs for a page's red count badge, which sits over the corner
local TAB_BAR = 4 -- the row's scroll bar, under the tabs
local PROGRESS_HEIGHT = 28
local RALLY_POOL = "rally" -- shared Catalog.RALLY_POOL: the Rescue Rally's own crate, never sold (F101)
local RALLY_SOURCE = "From the Rescue Rally, every weekend"
local RALLY_LOCKED = "Rally Crate"
local RALLY_TAB_SHORT = "Rally (weekends)" -- #3931: the Rally tab in the short screen's column, with RALLY_SOURCE's news
local FULL_MILESTONE = "decor10" -- the whole page's milestone (all 12 since F80), whose claim puts on the gold frame

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

-- A page's tab name: its plain crate's name without " Crate" ("Alley"), else the area's name.
local function poolName(catalog: Types.Catalog, pool: string): string
	local crates: { Types.CrateDef } = catalog.crates or {}
	for _, crate in crates do
		if not crate.golden and crate.area == pool then
			return (crate.name:gsub(" Crate$", ""))
		end
	end
	return Format.areaName(pool)
end

function DecorIndex.new(parent: Instance, callbacks: Callbacks): DecorIndex
	local self = setmetatable({}, DecorIndex) :: any
	self._callbacks = callbacks
	self._catalog = nil :: Types.Catalog?
	self._chips = {} :: { Chip }
	self._cells = {} :: { [string]: { Cell } } -- pool -> its page's cells
	-- #3722: pages whose cells are not built yet; a page is built the first time it shows, not at start-up
	self._unbuilt = {} :: { [string]: boolean }
	self._pool = nil :: string? -- the open page
	self._state = nil :: Types.PlayerState?

	local gap = Theme.sizes.gap
	-- a finger's 44 px on every touch screen (the UI gate's tap check), the page chips' 46 with a mouse
	local chipHeight = Scale.tapHeight(CHIP_HEIGHT)
	self._chipHeight = chipHeight
	-- the scrolling row clips, so it keeps room round the tabs for their outlines and under them for its bar
	local barHeight = chipHeight + TAB_PAD * 2 + TAB_BADGE + TAB_BAR
	self.frame = Create("Frame", {
		Name = "DecorIndex",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	})
	self._chipBar = Create("ScrollingFrame", {
		Name = "Pages",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, barHeight),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = TAB_BAR,
		ScrollBarImageColor3 = Theme.colors.caramel,
		Parent = self.frame,
	}, {
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, TAB_PAD),
			PaddingRight = UDim.new(0, TAB_PAD + TAB_BADGE),
			PaddingTop = UDim.new(0, TAB_PAD + TAB_BADGE),
		}),
		Create("UIGridLayout", {
			Name = "Tabs",
			FillDirection = Enum.FillDirection.Horizontal,
			CellPadding = UDim2.fromOffset(gap, gap),
			CellSize = UDim2.fromOffset(TAB_MIN, chipHeight),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._tabGrid = self._chipBar:FindFirstChild("Tabs") :: UIGridLayout
	self._tabRows = 1

	self._rail = false
	self._resized = self.frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_sizeTabs()
	end)

	-- the open page's completion: name, bar, count and percent
	local progressTop = barHeight + gap
	local progress: Frame = Create("Frame", {
		Name = "Progress",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, progressTop),
		Size = UDim2.new(1, 0, 0, PROGRESS_HEIGHT),
		Parent = self.frame,
	})
	self._progress = progress
	self._progressName = text({
		Name = "Page",
		Size = UDim2.new(0, 190, 1, 0),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextColor3 = Theme.colors.white,
		Parent = progress,
	})
	Outline.text(self._progressName, 2)
	local track: Frame = Create("Frame", {
		Name = "Track",
		BackgroundColor3 = CARD.line,
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

	-- the page: the reward strip and the pieces scroll together; a full page wears a gold frame
	local pageTop = progressTop + PROGRESS_HEIGHT + gap
	local page: Frame = Create("Frame", {
		Name = "Page",
		BackgroundColor3 = Theme.colors.gold,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, pageTop),
		Size = UDim2.new(1, 0, 1, -pageTop),
		Parent = self.frame,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	self._frameStroke = Create("UIStroke", {
		Color = Theme.colors.gold,
		Thickness = 4,
		Enabled = false,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = page,
	})
	self._page = page
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
		Parent = page,
	}, {
		Create(
			"UIListLayout",
			{ Padding = UDim.new(0, gap), SortOrder = Enum.SortOrder.LayoutOrder }
		),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		}),
	})
	-- #1766: where the Rally page's pieces come from, over its reward strip
	self._source = text({
		Name = "Source",
		LayoutOrder = -1,
		Size = UDim2.new(1, 0, 0, 24),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.colors.gold,
		Text = RALLY_SOURCE,
		Visible = false,
		Parent = self._grid,
	})
	self._strip = IndexStrip.new(self._grid, { claim = callbacks.claim })
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
	self._empty = text({
		Name = "Empty",
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 40),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = PAL.subtext,
		Text = "The pieces arrive with the next update. Open crates at the Golden Fish Market.",
		Visible = false,
		Parent = self._grid,
	})
	return self :: DecorIndex
end

function DecorIndex._clear(self: any)
	for _, chip: Chip in self._chips do
		chip.connection:Disconnect()
		chip.frame:Destroy()
	end
	table.clear(self._chips)
	for _, cells in self._cells do
		for _, cell: Cell in cells do
			cell.icon:destroy()
			cell.frame:Destroy()
		end
	end
	table.clear(self._cells)
	table.clear(self._unbuilt)
end

function DecorIndex.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	self._strip:setCatalog(catalog)
	self:_clear()
	local pools = DecorPieces.pools(catalog)
	for order, pool in pools do
		local name = poolName(catalog, pool)
		local color = Theme.areaColors[pool] or Theme.colors.caramel
		local frame: TextButton = Create("TextButton", {
			Name = pool,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = CARD.card,
			BorderSizePixel = 0,
			Size = UDim2.new(0, TAB_MIN, 0, self._chipHeight),
			LayoutOrder = order,
			Parent = self._chipBar,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
		local border = Outline.border(frame, Theme.sizes.outline)
		local dot: Frame = Create("Frame", {
			Name = "Badge",
			BackgroundColor3 = Theme.colors.red,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(20, 20),
			Visible = false,
			ZIndex = 6,
			Parent = frame,
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		Outline.border(dot, 2)
		local dotCount = text({
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
		-- the tabs share the row (TAB_MIN each at least), so a long name ("Neighbourhood") shrinks to fit a phone
		local label = text({
			Name = "Name",
			Position = UDim2.fromOffset(4, 3),
			Size = UDim2.new(1, -8, 0, 22),
			FontFace = Theme.fonts.display,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = name,
			Parent = frame,
		})
		Create("UITextSizeConstraint", {
			MaxTextSize = Theme.sizes.textSmall + 1,
			MinTextSize = 9,
			Parent = label,
		})
		local count = text({
			Name = "Count",
			Position = UDim2.fromOffset(6, 24),
			Size = UDim2.new(1, -12, 0, 16),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textTiny,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = frame,
		})
		local connection = frame.Activated:Connect(function()
			if self._pool == pool then
				return
			end
			Sound.play("uiTab")
			self._pool = pool
			self._grid.CanvasPosition = Vector2.zero
			local state: Types.PlayerState? = self._state
			if state then
				self:render(state)
			end
		end)
		table.insert(self._chips, {
			pool = pool,
			name = name,
			color = color,
			frame = frame,
			border = border,
			label = label,
			count = count,
			dot = dot,
			dotCount = dotCount,
			connection = connection,
		})

		-- #3722: the cells (an icon each) are built when the page first shows (_buildPage), not here inside UI.init
		self._cells[pool] = {}
		self._unbuilt[pool] = true
	end
	if self._pool == nil or self._cells[self._pool] == nil then
		self._pool = if pools[1] then pools[1] else nil
	end
	self:_sizeTabs()
end

-- #3722: one page's cells, built the first time the page shows.
function DecorIndex._buildPage(self: any, pool: string)
	local catalog: Types.Catalog? = self._catalog
	if catalog == nil or not self._unbuilt[pool] then
		return
	end
	self._unbuilt[pool] = nil
	local cells: { Cell } = self._cells[pool]
	for index, def in DecorPieces.poolPieces(catalog, pool) do
		local cell: Cell = self:_buildCell(def, index)
		table.insert(cells, cell)
	end
end

-- Each page tab gets an equal share of its row. One row while that share is at least TAB_MIN, else the fewest rows
-- (up to TAB_ROWS) whose share is at least TAB_WRAP_MIN (#3931); only past TAB_ROWS does the row scroll. The
-- completion line and the page move down under the rows. On a short screen, where rows would leave no decor in
-- view, more than one row becomes the left column (RAIL_W) instead, the page beside it (the completion line hides there: the open tab shows the page's count).
function DecorIndex._sizeTabs(self: any)
	local count = #self._chips
	if count == 0 then
		return
	end
	local gap = Theme.sizes.gap
	local width = self.frame.AbsoluteSize.X / math.max(Scale.get(), 0.01) - TAB_PAD * 2 - TAB_BADGE
	local rows, tab = TAB_ROWS, TAB_WRAP_MIN
	for tryRows = 1, TAB_ROWS do
		local perRow = math.ceil(count / tryRows)
		local share = math.floor((width - gap * (perRow - 1)) / perRow)
		if share >= (if tryRows == 1 then TAB_MIN else TAB_WRAP_MIN) then
			rows, tab = tryRows, share
			break
		end
	end
	local rail = rows > 1 and Scale.isShort()
	if rail then
		tab = RAIL_W
	end
	local chipHeight = self._chipHeight
	local grid: UIGridLayout = self._tabGrid
	grid.CellSize = UDim2.fromOffset(tab, chipHeight)
	for _, chip: Chip in self._chips do
		chip.frame.Size = UDim2.new(0, tab, 0, chipHeight)
	end
	if rows == self._tabRows and rail == self._rail and self._laidOut then
		return
	end
	self._tabRows = rows
	self._rail = rail
	self._laidOut = true
	local bar: ScrollingFrame = self._chipBar
	if rail then
		local railWidth = RAIL_W + TAB_PAD * 2 + TAB_BADGE + TAB_BAR
		bar.Size = UDim2.new(0, railWidth, 1, 0)
		bar.AutomaticCanvasSize = Enum.AutomaticSize.Y
		bar.ScrollingDirection = Enum.ScrollingDirection.Y
		bar.CanvasPosition = Vector2.zero
		-- the completion line goes: the open tab in the column already shows the page's "3 / 12"
		local left = railWidth + gap
		self._progress.Visible = false
		self._page.Position = UDim2.fromOffset(left, 0)
		self._page.Size = UDim2.new(1, -left, 1, 0)
		return
	end
	local barHeight = rows * chipHeight + (rows - 1) * gap + TAB_PAD * 2 + TAB_BADGE + TAB_BAR
	bar.Size = UDim2.new(1, 0, 0, barHeight)
	bar.AutomaticCanvasSize = Enum.AutomaticSize.X
	bar.ScrollingDirection = Enum.ScrollingDirection.X
	local progressTop = barHeight + gap
	self._progress.Visible = true
	self._progress.Position = UDim2.fromOffset(0, progressTop)
	local pageTop = progressTop + PROGRESS_HEIGHT + gap
	self._page.Position = UDim2.fromOffset(0, pageTop)
	self._page.Size = UDim2.new(1, 0, 1, -pageTop)
end

function DecorIndex._buildCell(self: any, def: Types.DecorDef, order: number): Cell
	local frame: Frame = Create("Frame", {
		Name = def.id,
		BackgroundColor3 = CARD.card,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Visible = false,
		Parent = self._cellsFrame,
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
	local open: string? = self._pool
	for _, chip: Chip in self._chips do
		local selected = chip.pool == open
		local have, all = DecorPieces.pageCounts(catalog, state, chip.pool)
		chip.frame.BackgroundColor3 = if selected then chip.color else CARD.card
		chip.border.Color = if selected then Theme.colors.outline else CARD.cardStroke
		chip.label.TextColor3 = if selected then Theme.colors.white else CARD.text
		chip.label.Text = if self._rail and chip.pool == RALLY_POOL
			then RALLY_TAB_SHORT
			else chip.name
		chip.count.Text = if have >= all and all > 0
			then "Complete!"
			else ("%d / %d"):format(have, all)
		chip.count.TextColor3 = if selected
			then Theme.colors.cream
			elseif have >= all and all > 0 then CARD.good
			else CARD.subtext
		local waiting = ready[DecorPieces.areaOf(chip.pool)] or 0
		chip.dot.Visible = waiting > 0
		chip.dotCount.Text = tostring(waiting)
		if selected then
			local fraction = if all > 0 then have / all else 0
			local full = all > 0 and have >= all
			self._progressName.Text = chip.name
			self._progressName.TextColor3 = chip.color
			self._progressFill.BackgroundColor3 = if full then Theme.colors.gold else chip.color
			self._progressFill.Size = UDim2.fromScale(fraction, 1)
			self._progressCount.Text = ("%d / %d  ·  %s"):format(
				have,
				all,
				Format.percent(fraction)
			)
			-- the gold frame comes with the all-ten reward (or with a full page when the catalog has no reward)
			local area = DecorPieces.areaOf(chip.pool)
			local prizes = catalog.indexPrizes and catalog.indexPrizes[area]
			local hasReward = prizes ~= nil and prizes[FULL_MILESTONE] ~= nil
			self._frameStroke.Enabled = full
				and (IndexRewards.isClaimed(state, area, FULL_MILESTONE) or not hasReward)
			self._page.BackgroundTransparency = if self._frameStroke.Enabled then 0.85 else 1
		end
	end

	self._strip:render(state, if open then DecorPieces.areaOf(open) else nil)
	if open ~= nil then
		self:_buildPage(open)
	end
	local rally = open == RALLY_POOL
	-- #3931: beside the short screen's tab column the line would push the Rally's pieces out of view; the Rally tab
	-- says "weekends" there instead
	self._source.Visible = rally and not self._rail
	local shown = 0
	for pool, cells in self._cells do
		local onPage = pool == open
		for _, cell: Cell in cells do
			cell.frame.Visible = onPage
			if not onPage then
				continue
			end
			shown += 1
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
	self._empty.Visible = shown == 0
end

function DecorIndex.destroy(self: any)
	self._resized:Disconnect()
	self:_clear()
	self._strip:destroy()
	self.frame:Destroy()
end

return DecorIndex
