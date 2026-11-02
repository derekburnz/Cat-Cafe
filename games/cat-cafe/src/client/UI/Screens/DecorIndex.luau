--!strict
-- The Decor Index (F53, golden-fish.md section 4): the Collection's Decor tab. A page per crate (Alley, Park,
-- Neighbourhood, Woods, Sewer, Classic) with its pieces (twelve since F80 added a door set and a cat flap), rarest
-- last, as "?" tiles until owned and then with their name, rarity, kind and tip bonus. Above them the page's reward
-- strip (Screens/IndexStrip) pays 25 golden fish at 5 pieces (decor5) and +5% tips forever at all of them (decor10,
-- whose `needs` the catalog sets, 12 since F80), which also puts a gold frame on the page. The
-- page tabs carry a red badge when a reward is waiting. Counts come from state.decorOwned (Components/DecorPieces).

local Create = require(script.Parent.Parent.Components.Create)
local DecorPieces = require(script.Parent.Parent.Components.DecorPieces)
local Format = require(script.Parent.Parent.Components.Format)
local IndexRewards = require(script.Parent.Parent.Components.IndexRewards)
local IndexStrip = require(script.Parent.IndexStrip)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local Outline = require(script.Parent.Parent.Components.Outline)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

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

local CELL = Vector2.new(112, 134)
local ICON = 76
local CHIP_HEIGHT = 46
local PROGRESS_HEIGHT = 28
local FULL_MILESTONE = "decor10" -- the whole page's milestone (all 12 since F80), whose claim puts on the gold frame

local DecorIndex = {}
DecorIndex.__index = DecorIndex

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
	self._pool = nil :: string? -- the open page
	self._state = nil :: Types.PlayerState?

	local gap = Theme.sizes.gap
	self.frame = Create("Frame", {
		Name = "DecorIndex",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	})
	self._chipBar = Create("Frame", {
		Name = "Pages",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, CHIP_HEIGHT),
		Parent = self.frame,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- the open page's completion: name, bar, count and percent
	local progressTop = CHIP_HEIGHT + gap
	local progress: Frame = Create("Frame", {
		Name = "Progress",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, progressTop),
		Size = UDim2.new(1, 0, 0, PROGRESS_HEIGHT),
		Parent = self.frame,
	})
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
		ScrollBarImageColor3 = Theme.colors.caramel,
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
		TextColor3 = Theme.modal.subtext,
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
end

function DecorIndex.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	self._strip:setCatalog(catalog)
	self:_clear()
	local pools = DecorPieces.pools(catalog)
	local gap = Theme.sizes.gap
	for order, pool in pools do
		local name = poolName(catalog, pool)
		local color = Theme.areaColors[pool] or Theme.colors.caramel
		local frame: TextButton = Create("TextButton", {
			Name = pool,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Theme.modal.card,
			BorderSizePixel = 0,
			Size = UDim2.new(1 / #pools, -gap * (#pools - 1) / #pools, 1, 0),
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
		-- six tabs share the row, so a long name ("Neighbourhood") shrinks to fit a phone
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

		local cells: { Cell } = {}
		for index, def in DecorPieces.poolPieces(catalog, pool) do
			local cell = self:_buildCell(def, index)
			table.insert(cells, cell)
		end
		self._cells[pool] = cells
	end
	if self._pool == nil or self._cells[self._pool] == nil then
		self._pool = if pools[1] then pools[1] else nil
	end
end

function DecorIndex._buildCell(self: any, def: Types.DecorDef, order: number): Cell
	local frame: Frame = Create("Frame", {
		Name = def.id,
		BackgroundColor3 = Theme.modal.card,
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
		chip.frame.BackgroundColor3 = if selected then chip.color else Theme.modal.card
		chip.border.Color = if selected then Theme.colors.outline else Theme.modal.cardStroke
		chip.label.TextColor3 = if selected then Theme.colors.white else Theme.modal.text
		chip.count.Text = if have >= all and all > 0
			then "Complete!"
			else ("%d / %d"):format(have, all)
		chip.count.TextColor3 = if selected
			then Theme.colors.cream
			elseif have >= all and all > 0 then Theme.colors.goodDark
			else Theme.modal.subtext
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
				if owned then piece.rarity else nil
			)
			cell.kind.Visible = owned
			cell.name.Text = if owned then cell.def.name else "???"
			cell.name.TextColor3 = if owned then Theme.modal.text else Theme.modal.subtext
			local rarity = piece.rarity or ""
			cell.sub.Text = if owned
				then ("%s · +%s"):format(rarity, Format.percent(cell.def.bonus or 0))
				else rarity
			cell.sub.TextColor3 = if owned
				then Theme.modal.subtext
				else Theme.rarityColor(piece.rarity)
		end
	end
	self._empty.Visible = shown == 0
end

function DecorIndex.destroy(self: any)
	self:_clear()
	self._strip:destroy()
	self.frame:Destroy()
end

return DecorIndex
