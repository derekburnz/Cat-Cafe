--!strict
-- Decor screen: category chips across the top, a grid of cards below.
-- A card shows cost, Place or Remove depending on what the player owns.
-- F53 (golden-fish.md section 4): crate pieces the player owns join the grid under their kind's chip, with their
-- rarity and "+4% tips while in use". Between the chips and the grid a "Your cafe" strip shows the three style
-- slots (the wallpaper, floor and paint in use, or "Plain") and the decor spots ("2 / 4"); tapping one filters the
-- grid to that kind. A wallpaper, floor or paint card says "Use it" (it takes the place of the one in use) or "In
-- use"; furniture and decorations say Place, Remove or "Spots full". The server checks the spots too.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local DecorPieces = require(script.Parent.Parent.Components.DecorPieces)
local Format = require(script.Parent.Parent.Components.Format)
local IndexRewards = require(script.Parent.Parent.Components.IndexRewards)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local Panel = require(script.Parent.Parent.Components.Panel)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any

export type Callbacks = {
	buyDecor: (decorId: string) -> (),
	toggleDecor: (decorId: string, placed: boolean) -> (),
	close: () -> (),
}

export type DecorShop = {
	frame: Frame,
	setCatalog: (self: DecorShop, catalog: Types.Catalog) -> (),
	render: (self: DecorShop, state: Types.PlayerState) -> (),
	destroy: (self: DecorShop) -> (),
}

local CARD = Vector2.new(164, 196)
local CHIP_HEIGHT = 36
local STRIP_HEIGHT = 58
local SLOT_WIDTH = 168
local SPOTS_BY_TIER: { number } = Config.DecorSpots or DecorPieces.SPOTS_BY_TIER

-- Placeholder art colour per category until the asset thread delivers images.
local CATEGORY_COLORS: { [string]: Color3 } = {
	Plants = Color3.fromHex("5FB85A"),
	Floor = Color3.fromHex("D97B4B"),
	Wall = Color3.fromHex("E8A0A0"),
	Furniture = Color3.fromHex("8FD3C1"),
	Toys = Color3.fromHex("FFC94D"),
}

local DecorShop = {}
DecorShop.__index = DecorShop

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

function DecorShop.new(callbacks: Callbacks): DecorShop
	local self = setmetatable({}, DecorShop) :: any
	self._callbacks = callbacks
	self._cards = {} :: { [string]: any }
	self._chips = {} :: { any }
	self._slots = {} :: { any } -- the "Your cafe" strip's three style slots and the spots card
	self._decor = {} :: { Types.DecorDef } -- Catalog.decor and Catalog.crateDecor
	self._filter = "All"
	self._catalog = nil :: Types.Catalog?
	self._state = nil :: Types.PlayerState?
	self._dirty = true

	local panel = Panel.new({
		name = "Decor",
		color = Theme.colors.goldDark,
		icon = Theme.icons.decor,
		title = "Decor",
		subtitle = "Make the cafe yours",
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = Vector2.new(760, 560), Parent = panel.frame })
	self._panel = panel
	self.frame = panel.frame

	self._chipRow = Create("ScrollingFrame", {
		Name = "Chips",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, CHIP_HEIGHT),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		Parent = panel.content,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- "Your cafe": the style slots and the decor spots, shown once the catalog has crate pieces
	self._strip = Create("ScrollingFrame", {
		Name = "YourCafe",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, CHIP_HEIGHT + Theme.sizes.gap),
		Size = UDim2.new(1, 0, 0, STRIP_HEIGHT),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		Visible = false,
		Parent = panel.content,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	self._grid = Create("ScrollingFrame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, CHIP_HEIGHT + Theme.sizes.gap),
		Size = UDim2.new(1, 0, 1, -(CHIP_HEIGHT + Theme.sizes.gap)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.colors.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel.content,
	}, {
		Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(CARD.X, CARD.Y),
			CellPadding = UDim2.fromOffset(Theme.sizes.gap, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
		}),
		Create("UIPadding", { PaddingRight = UDim.new(0, 10) }),
	})
	self._hint = text({
		Name = "Hint",
		LayoutOrder = 100000,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextColor3 = Theme.modal.subtext,
		Text = "Open crates at the Golden Fish Market to find more.",
		Visible = false,
		Parent = self._grid,
	})

	return self :: DecorShop
end

-- A card's chip: a crate piece's kind ("Wallpaper"), else the decor's category.
local function chipOf(def: Types.DecorDef): string
	local kind = DecorPieces.info(def).kind
	return if kind then DecorPieces.kindName(kind) else def.category
end

function DecorShop._setFilter(self: any, category: string)
	self._filter = category
	for _, chip in self._chips do
		chip.button:setStyle(if chip.category == category then "gold" else "ghost")
	end
	self:_applyVisible()
end

-- A card shows when its chip is picked; a crate piece only once the player owns it (the Decor Index shows the rest).
function DecorShop._applyVisible(self: any)
	local state: Types.PlayerState? = self._state
	local shown = 0
	for _, card in self._cards do
		local owned = state ~= nil and state.decorOwned[card.def.id] == true
		local visible = (self._filter == "All" or card.chip == self._filter)
			and (not card.piece or owned)
		card.frame.Visible = visible
		if visible then
			shown += 1
		end
	end
	self._hint.Visible = shown == 0
end

-- The strip's slots: Wallpaper, Floor and Paint (the piece in use, or "Plain"), then the decor spots.
function DecorShop._buildStrip(self: any)
	for _, slot in self._slots do
		slot.icon:destroy()
		slot.connection:Disconnect()
		slot.frame:Destroy()
	end
	table.clear(self._slots)
	local kinds: { string } = {}
	for _, kind in DecorPieces.STYLE_KINDS do
		table.insert(kinds, kind)
	end
	table.insert(kinds, "spots")
	for order, kind in kinds do
		local frame: TextButton = Create("TextButton", {
			Name = kind,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Theme.modal.card,
			BorderSizePixel = 0,
			LayoutOrder = order,
			Size = UDim2.fromOffset(SLOT_WIDTH, STRIP_HEIGHT),
			Parent = self._strip,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
			Create("UIStroke", { Color = Theme.modal.cardStroke, Thickness = Theme.sizes.stroke }),
		})
		local icon = ItemIcon.new({
			parent = frame,
			size = UDim2.fromOffset(STRIP_HEIGHT - 12, STRIP_HEIGHT - 12),
			anchorPoint = Vector2.new(0, 0.5),
			position = UDim2.new(0, 6, 0.5, 0),
		})
		local spots = kind == "spots"
		text({
			Name = "Kind",
			Position = UDim2.fromOffset(STRIP_HEIGHT, 7),
			Size = UDim2.new(1, -(STRIP_HEIGHT + 6), 0, 16),
			FontFace = Theme.fonts.bodyBold,
			TextSize = Theme.sizes.textTiny,
			TextColor3 = Theme.modal.subtext,
			Text = if spots then "Decor spots" else DecorPieces.kindName(kind),
			Parent = frame,
		})
		local value = text({
			Name = "Value",
			Position = UDim2.fromOffset(STRIP_HEIGHT, 24),
			Size = UDim2.new(1, -(STRIP_HEIGHT + 6), 0, 24),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody,
			Parent = frame,
		})
		local chip = if spots then DecorPieces.kindName("furniture") else DecorPieces.kindName(kind)
		local connection = frame.Activated:Connect(function()
			self:_setFilter(if self._filter == chip then "All" else chip)
		end)
		table.insert(self._slots, {
			kind = kind,
			frame = frame,
			icon = icon,
			value = value,
			connection = connection,
		})
	end
end

-- The style slots and the spots from the state: "Brick Wall" or "Plain"; "2 / 4", red when every spot is used.
function DecorShop._renderStrip(self: any, state: Types.PlayerState, used: number, spots: number)
	local catalog: Types.Catalog? = self._catalog
	if catalog == nil then
		return
	end
	for _, slot in self._slots do
		if slot.kind == "spots" then
			slot.icon:set(nil, DecorPieces.kindIcon("furniture", Theme.icons.decor), nil)
			slot.value.Text = ("%d / %d"):format(used, spots)
			slot.value.TextColor3 = if used >= spots then Theme.colors.red else Theme.modal.text
			continue
		end
		local def = DecorPieces.inUse(self._decor, state.decorPlaced, slot.kind)
		local piece = DecorPieces.info(def)
		slot.icon:set(
			if def then def.asset else nil,
			DecorPieces.kindIcon(slot.kind, Theme.icons.decor),
			piece.rarity
		)
		slot.value.Text = if def then def.name else "Plain"
		slot.value.TextColor3 = if def then Theme.modal.text else Theme.modal.subtext
	end
end

function DecorShop._build(self: any)
	for _, chip in self._chips do
		chip.button:destroy()
	end
	table.clear(self._chips)
	for _, card in self._cards do
		card.action:destroy()
		if card.icon then
			card.icon:destroy()
		end
		card.frame:Destroy()
	end
	table.clear(self._cards)

	local catalog: Types.Catalog? = self._catalog
	if not catalog then
		return
	end
	assert(catalog, "catalog not set; call UI.init first")

	-- the "Your cafe" strip and room for it when the catalog has crate pieces
	-- the shop's and the Index's decor plus the crate pieces (Catalog.crateDecor)
	local all = DecorPieces.all(catalog)
	self._decor = all
	local hasPieces = false
	for _, decor in all do
		if DecorPieces.isPiece(decor) then
			hasPieces = true
			break
		end
	end
	self._strip.Visible = hasPieces
	local gridTop = CHIP_HEIGHT
		+ Theme.sizes.gap
		+ (if hasPieces then STRIP_HEIGHT + Theme.sizes.gap else 0)
	self._grid.Position = UDim2.fromOffset(0, gridTop)
	self._grid.Size = UDim2.new(1, 0, 1, -gridTop)
	if hasPieces then
		self:_buildStrip()
	end

	-- chips: All + each category (a piece's kind) in catalog order
	local categories = { "All" }
	for _, decor in all do
		local chip = chipOf(decor)
		if not table.find(categories, chip) then
			table.insert(categories, chip)
		end
	end
	for index, category in categories do
		local button = Button.new({
			name = category,
			text = category,
			style = "ghost",
			size = UDim2.fromOffset(math.max(84, #category * 11 + 28), CHIP_HEIGHT),
			textSize = Theme.sizes.textSmall,
			layoutOrder = index,
			parent = self._chipRow,
			sound = "uiTab",
			onClick = function()
				self:_setFilter(category)
			end,
		})
		table.insert(self._chips, { category = category, button = button })
	end

	for index, decor in all do
		local piece = DecorPieces.info(decor)
		local card: Frame = Create("Frame", {
			Name = decor.id,
			BackgroundColor3 = Theme.modal.card,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Parent = self._grid,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
			Create("UIStroke", { Color = Theme.modal.cardStroke, Thickness = Theme.sizes.stroke }),
		})

		-- art
		local art: Frame = Create("Frame", {
			Name = "Art",
			BackgroundColor3 = CATEGORY_COLORS[decor.category] or Theme.colors.mint,
			BackgroundTransparency = if piece.kind then 1 else 0,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.new(1, -20, 0, 76),
			Parent = card,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }) })
		local icon: ItemIcon.ItemIcon? = nil
		if piece.kind then
			-- a crate piece: its model (or its kind's glyph) on a tile in its rarity colour, and the rarity
			local pieceIcon = ItemIcon.new({
				parent = art,
				size = UDim2.fromOffset(76, 76),
				anchorPoint = Vector2.new(0.5, 0),
				position = UDim2.fromScale(0.5, 0),
			})
			pieceIcon:set(
				decor.asset,
				DecorPieces.kindIcon(piece.kind, Theme.icons.decor),
				piece.rarity
			)
			icon = pieceIcon
			local rarity = text({
				Name = "Rarity",
				BackgroundTransparency = 0,
				BackgroundColor3 = Theme.rarityColor(piece.rarity),
				Position = UDim2.fromOffset(16, 16),
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 20),
				FontFace = Theme.fonts.display,
				TextSize = Theme.sizes.textTiny,
				TextColor3 = Theme.rarityTextColor(piece.rarity),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTruncate = Enum.TextTruncate.None,
				Text = piece.rarity or "",
				ZIndex = 3,
				Parent = card,
			})
			Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = rarity })
			Create("UIPadding", {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				Parent = rarity,
			})
		else
			-- placeholder art until decor renders exist: a coloured block with the first letter (DecorDef.asset
			-- names the 3D model, not an image)
			text({
				Size = UDim2.fromScale(1, 1),
				FontFace = Theme.fonts.display,
				TextSize = 34,
				TextColor3 = Theme.colors.paper,
				TextXAlignment = Enum.TextXAlignment.Center,
				Text = decor.name:sub(1, 1),
				Parent = art,
			})
		end
		-- Index decor (F48): a dark ribbon over the art says which Index milestone wins it, until it is claimed
		local unlock: TextLabel? = nil
		if IndexRewards.isIndexDecor(decor) then
			unlock = text({
				Name = "Unlock",
				BackgroundColor3 = Theme.colors.outline,
				BackgroundTransparency = 0.25,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, 32),
				FontFace = Theme.fonts.bodyBold,
				TextSize = Theme.sizes.textTiny,
				TextColor3 = Theme.colors.white,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextWrapped = true,
				TextTruncate = Enum.TextTruncate.None,
				ZIndex = 2,
				Parent = art,
			})
			Create(
				"UICorner",
				{ CornerRadius = UDim.new(0, Theme.sizes.radiusSmall), Parent = unlock }
			)
			Create("UIPadding", {
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
				Parent = unlock,
			})
		end
		local owned = text({
			Name = "Owned",
			BackgroundColor3 = Theme.colors.good,
			BackgroundTransparency = 0,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -16, 0, 16),
			Size = UDim2.fromOffset(56, 20),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textTiny,
			TextColor3 = Theme.colors.goodText,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = "Owned",
			Visible = false,
			Parent = card,
		})
		Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = owned })

		text({
			Name = "Name",
			Position = UDim2.fromOffset(10, 92),
			Size = UDim2.new(1, -20, 0, 22),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody,
			Text = decor.name,
			Parent = card,
		})
		text({
			Name = "Effect",
			Position = UDim2.fromOffset(10, 114),
			Size = UDim2.new(1, -20, 0, 18),
			TextSize = Theme.sizes.textTiny,
			TextColor3 = Theme.modal.subtext,
			Text = if piece.kind
				then ("+%s tips while in use"):format(Format.percent(decor.bonus or 0))
				else decor.effect or decor.description or "",
			Parent = card,
		})

		local action = Button.new({
			name = "Action",
			text = Format.money(decor.cost),
			style = "primary",
			size = UDim2.new(1, -20, 0, Theme.sizes.touchMin),
			position = UDim2.new(0, 10, 1, -(Theme.sizes.touchMin + 10)),
			textSize = Theme.sizes.textSmall + 1,
			parent = card,
			onClick = function()
				local entry = self._cards[decor.id]
				if entry.mode == "buy" then
					self._callbacks.buyDecor(decor.id)
				elseif entry.mode == "place" or entry.mode == "use" then
					self._callbacks.toggleDecor(decor.id, true)
				elseif entry.mode == "remove" then
					self._callbacks.toggleDecor(decor.id, false)
				end
			end,
		})

		self._cards[decor.id] = {
			frame = card,
			owned = owned,
			action = action,
			unlock = unlock,
			icon = icon,
			def = decor,
			chip = chipOf(decor),
			piece = piece.kind ~= nil,
			kind = piece.kind,
			mode = "buy",
		}
	end
	self:_setFilter("All")
end

function DecorShop.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	self:_build()
	self._dirty = true
end

function DecorShop.render(self: any, state: Types.PlayerState)
	self._state = state
	if not self.frame.Visible then
		self._dirty = true
		return
	end
	self._dirty = false
	local replaced = if self._catalog then IndexRewards.replacedBy(self._catalog, state) else {}
	local used = DecorPieces.spotsUsed(self._decor, state.decorPlaced, replaced)
	local spots = DecorPieces.spots(state.tier, state.fishPerks, SPOTS_BY_TIER)
	if self._strip.Visible then
		self:_renderStrip(state, used, spots)
	end
	local placedCount = 0
	for _, placed in state.decorPlaced do
		if placed then
			placedCount += 1
		end
	end
	self._panel:setTitle(
		"Decor",
		("%d placed  ·  %s"):format(placedCount, Format.money(state.money))
	)

	for decorId, card in self._cards do
		local def: Types.DecorDef = card.def
		local isOwned = state.decorOwned[decorId] == true
		local isPlaced = state.decorPlaced[decorId] == true
		local locked = def.requiresTier ~= nil and state.tier < (def.requiresTier :: number)
		card.owned.Visible = isOwned and not card.piece
		local unlock: TextLabel? = card.unlock
		if unlock then
			-- a placed gold piece takes over from its normal piece (N117)
			local isReplaced = isOwned and isPlaced and replaced[decorId] ~= nil
			unlock.Visible = not isOwned or isReplaced
			local catalog: Types.Catalog? = self._catalog
			local areaId, milestone = nil, nil
			if catalog then
				areaId, milestone = IndexRewards.decorSource(catalog, decorId)
			end
			local label = "From the Index"
			if catalog and areaId and milestone then
				local total = IndexRewards.counts(catalog, state, areaId).total
				label = IndexRewards.unlockLabel(milestone, Format.areaName(areaId), total)
			end
			unlock.Text = if isReplaced
				then "✨ Replaced by its gold piece"
				else Theme.icons.lock .. " " .. label
		end
		if card.piece and DecorPieces.isStyle(card.kind) then
			-- a wallpaper, floor or paint: one in use of each kind; Use it swaps it in
			card.mode = if isPlaced then "inuse" else "use"
			card.action:setText(if isPlaced then "✓ In use" else "Use it")
			card.action:setStyle(if isPlaced then "ghost" else "primary")
			card.action:setEnabled(isOwned and not isPlaced)
		elseif card.piece and isOwned and not isPlaced and used >= spots then
			-- furniture or a decoration with every decor spot taken
			card.mode = "full"
			card.action:setText("Spots full")
			card.action:setStyle("ghost")
			card.action:setEnabled(false)
		elseif isOwned and isPlaced then
			card.mode = "remove"
			card.action:setText("Remove")
			card.action:setStyle("ghost")
			card.action:setEnabled(true)
		elseif isOwned then
			card.mode = "place"
			card.action:setText("Place")
			card.action:setStyle("secondary")
			card.action:setEnabled(true)
		elseif IndexRewards.isIndexDecor(def) then
			-- F48: won from the Index, never bought (BuyDecor refuses it)
			card.mode = "index"
			card.action:setText(Theme.icons.collection .. " Index reward")
			card.action:setStyle("ghost")
			card.action:setEnabled(false)
		elseif locked then
			card.mode = "locked"
			card.action:setText(Format.tier(def.requiresTier :: number))
			card.action:setEnabled(false)
		else
			card.mode = "buy"
			card.action:setText(Format.money(def.cost))
			card.action:setStyle("primary")
			card.action:setEnabled(state.money >= def.cost)
		end
	end
	self:_applyVisible()
end

function DecorShop.destroy(self: any)
	for _, chip in self._chips do
		chip.button:destroy()
	end
	for _, card in self._cards do
		card.action:destroy()
		if card.icon then
			card.icon:destroy()
		end
	end
	for _, slot in self._slots do
		slot.icon:destroy()
		slot.connection:Disconnect()
	end
	self._panel:destroy()
end

return DecorShop
