--!strict
-- Decor screen: category chips across the top, a grid of cards below.
-- A card shows cost, Place or Remove depending on what the player owns.
-- F53 (golden-fish.md section 4): crate pieces the player owns join the grid under their kind's chip, with their
-- rarity and "+4% tips while in use". Between the chips and the grid a "Your cafe" strip shows the style slots
-- (the wallpaper, floor and paint in use, or "Plain"), the decor spots ("2 / 4"), then the door set and the cat flap
-- in use (F80, golden-fish.md section 4b) once the catalog has any; it scrolls sideways when it does not fit, the
-- next slot peeking at the edge. Tapping a slot filters the grid to that kind. A style card (wallpaper, floor, paint,
-- door set, cat flap) says "Use it" (it takes the place of the one in use) or "Remove"; furniture and decorations
-- say Place, Remove or "Spots full". The server checks the spots too.
-- Derek 2026-10-28: "decor menu buttons are squished a little too much", so the chips are taller and wider with more
-- room between them, and on a phone the chips and card buttons grow to a 44 px face (Scale.tapHeight).
-- F97 section 2 (Derek 2026-10-28: "make it so decor is crate find only"): a coin piece the catalog marks
-- `source = "crate"` shows only once owned and never with a price, like a crate piece, and the grid always ends
-- with "Find more decor in crates" pointing to the Golden Fish Market.
-- Equip Best (Derek 2026-10-28, server #828): a pink button right of the chips while Config.DecorEquipBest is true,
-- like the HUD's. A press fires callbacks.equipBest and holds the button grey until the next sync (at most
-- PRESS_HOLD seconds); the server puts out the best owned pieces and toasts what changed, or that nothing would.
-- F91 (front-lawn.md section 3): a "Front lawn" chip after All, shown while the lawn is live (the bound plot's
-- LawnPath attribute is set and ProfileSync has sent the lawn, Components/LawnLogic.live). Picking it swaps the strip
-- and grid for the Front lawn tab (Screens/LawnTab) and hides Equip Best, which is for the inside.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local DecorPieces = require(script.Parent.Parent.Components.DecorPieces)
local Format = require(script.Parent.Parent.Components.Format)
local IconArt = require(script.Parent.Parent.Components.IconArt)
local IndexRewards = require(script.Parent.Parent.Components.IndexRewards)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local LawnLogic = require(script.Parent.Parent.Components.LawnLogic)
local LawnTab = require(script.Parent.LawnTab)
local Panel = require(script.Parent.Parent.Components.Panel)
local Scale = require(script.Parent.Parent.Scale)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

-- the dark window palette (#1028), in place of Theme.modal
local PAL = Theme.dark

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any

export type Callbacks = {
	buyDecor: (decorId: string) -> (),
	toggleDecor: (decorId: string, placed: boolean) -> (),
	close: () -> (),
	equipBest: (() -> ())?, -- Equip Best on the chips row; no button without it
	-- F91: the Front lawn tab's requests (Screens/LawnTab)
	buyLawn: (id: string, spotId: string?) -> (),
	setLawnSpot: (spotId: string, pieceId: string) -> (),
	setLawnStyle: (kind: Types.LawnStyleKind, id: string) -> (),
	editLawn: () -> (),
}

export type DecorShop = {
	frame: Frame,
	setCatalog: (self: DecorShop, catalog: Types.Catalog) -> (),
	render: (self: DecorShop, state: Types.PlayerState) -> (),
	-- F91: the player's own plot, whose LawnPath attribute says the lawn is live; nil stops watching
	bindPlot: (self: DecorShop, plot: Instance?) -> (),
	showLawn: (self: DecorShop) -> (), -- the Front lawn chip picked, when the lawn is live
	destroy: (self: DecorShop) -> (),
}

local CARD_WIDTH = 164
local CARD_TOP = 152 -- the card above its button: art, name, effect
local CHIP_HEIGHT = 44 -- was 36 with a 31 px face (Derek 2026-10-28: "squished")
local CHIP_MIN_WIDTH = 96
local CHIP_PAD = 40 -- px round a chip's words
local CHIP_GAP = 10
local EQUIP_W = 156 -- Equip Best, right of the chips
local PRESS_HOLD = 3 -- seconds Equip Best stays grey after a press when no sync comes
local FOOTER_HEIGHT = 56
local STRIP_HEIGHT = 58
local SLOT_WIDTH = 150 -- four slots fit a full-width window with the fifth peeking, so the strip reads as scrollable
-- the strip's slots left to right: the first four as before F80, then the door set and the cat flap
local STRIP_ORDER = { "wallpaper", "floor", "paint", "spots", "door", "catflap" }
local LATE_KINDS: { [string]: boolean } = { door = true, catflap = true } -- shown once the catalog has one
local SPOTS_BY_TIER: { number } = Config.DecorSpots or DecorPieces.SPOTS_BY_TIER
local LAWN_CHIP = "Front lawn" -- F91: the chip that shows the Front lawn tab (the filter key)
local LAWN_TEXT = "Lawn" -- its words on the chip, short so the row is roomier (#964)
-- the "Your cafe" slots' clean symbols and light tiles (#964, the sheet in assets/cat-cafe/ui/icons-clean-2026-11-03):
-- drawn while a slot is Plain, and always for the decor spots. Until a symbol is uploaded its kind's glyph shows.
local SLOT_LOOK: { [string]: { picture: string, tint: Color3 } } = {
	wallpaper = { picture = "Wallpaper", tint = Color3.fromHex("D6ECFF") },
	floor = { picture = "Floor", tint = Color3.fromHex("FFE6C2") },
	paint = { picture = "Paint", tint = Color3.fromHex("FFD9EA") },
	spots = { picture = "Spots", tint = Color3.fromHex("CFF3EA") },
	door = { picture = "Door", tint = Color3.fromHex("E6DCFF") },
	catflap = { picture = "Catflap", tint = Color3.fromHex("FFF2C2") },
}

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

function DecorShop.new(callbacks: Callbacks): DecorShop
	local self = setmetatable({}, DecorShop) :: any
	self._callbacks = callbacks
	self._cards = {} :: { [string]: any }
	self._chips = {} :: { any }
	self._slots = {} :: { any } -- the "Your cafe" strip's style slots and the spots card
	self._decor = {} :: { Types.DecorDef } -- Catalog.decor and Catalog.crateDecor
	self._filter = "All"
	self._catalog = nil :: Types.Catalog?
	self._plot = nil :: Instance?
	self._plotConnection = nil :: RBXScriptConnection?
	self._lawnLive = false
	self._state = nil :: Types.PlayerState?
	self._dirty = true
	-- a phone's buttons grow to a 44 px face
	self._chipHeight = Scale.tapHeight(CHIP_HEIGHT, Theme.sizes.buttonDepth)
	self._actionHeight = Scale.tapHeight(Theme.sizes.touchMin, Theme.sizes.buttonDepth)
	local chipHeight = self._chipHeight

	local panel = Panel.new({
		dark = true, -- #1028
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

	local equipBest = if Config.DecorEquipBest == true then callbacks.equipBest else nil
	-- the chips get the full width: Equip Best sits in the header, left of the X (#964, Derek: "buttons on the top row
	-- feels too squished and cluttered")
	self._chipRow = Create("ScrollingFrame", {
		Name = "Chips",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, chipHeight),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		Parent = panel.content,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, CHIP_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	self._bestPressed = nil :: number? -- os.clock() of an Equip Best press not answered yet
	if equipBest then
		self._equipBest = Button.new({
			name = "EquipBest",
			text = Theme.icons.equipBest .. " Equip Best",
			style = "berry", -- the HUD's Equip Best pink, apart from the gold chip that is picked
			size = UDim2.fromOffset(EQUIP_W, chipHeight),
			anchorPoint = Vector2.new(1, 0.5),
			-- on the window frame, not the header, so a phone's taller button is not clipped by the body
			position = UDim2.new(1, -(panel.closeReach + 8), 0, panel.headerHeight / 2 - 2),
			textSize = Theme.sizes.textBody,
			zIndex = 4,
			parent = panel.frame,
			onClick = function()
				local at = os.clock()
				self._bestPressed = at
				self:_renderBest()
				equipBest()
				task.delay(PRESS_HOLD, function()
					if self._bestPressed == at then
						self._bestPressed = nil
						self:_renderBest()
					end
				end)
			end,
		})
	end

	-- "Your cafe": the style slots and the decor spots, shown once the catalog has crate pieces
	self._strip = Create("ScrollingFrame", {
		Name = "YourCafe",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, chipHeight + Theme.sizes.gap),
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
		Position = UDim2.fromOffset(0, chipHeight + Theme.sizes.gap),
		Size = UDim2.new(1, 0, 1, -(chipHeight + Theme.sizes.gap)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = PAL.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel.content,
	}, {
		Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(CARD_WIDTH, CARD_TOP + self._actionHeight),
			CellPadding = UDim2.fromOffset(Theme.sizes.gap, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
		}),
		Create("UIPadding", { PaddingRight = UDim.new(0, 10) }),
	})
	-- F97: no shop; the last cell says where decor comes from now. A grid cell, so it sits after the last card.
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
		Size = UDim2.fromOffset(FOOTER_HEIGHT, FOOTER_HEIGHT),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = Theme.icons.crate,
		Parent = footer,
	})
	text({
		Name = "Title",
		Position = UDim2.fromOffset(10, FOOTER_HEIGHT + 26),
		Size = UDim2.new(1, -20, 0, 22),
		FontFace = Theme.fonts.display,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Find more in crates",
		Parent = footer,
	})
	text({
		Name = "Where",
		Position = UDim2.fromOffset(10, FOOTER_HEIGHT + 50),
		Size = UDim2.new(1, -20, 0, 18),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Golden Fish Market",
		Parent = footer,
	})
	self._footer = footer

	-- F91: the Front lawn tab, in place of the strip and grid while its chip is picked
	local lawnTab = LawnTab.new(panel.content, {
		buyLawn = callbacks.buyLawn,
		setLawnSpot = callbacks.setLawnSpot,
		setLawnStyle = callbacks.setLawnStyle,
		editLawn = callbacks.editLawn,
	})
	lawnTab.frame.Position = UDim2.fromOffset(0, chipHeight + Theme.sizes.gap)
	lawnTab.frame.Size = UDim2.new(1, 0, 1, -(chipHeight + Theme.sizes.gap))
	self._lawnTab = lawnTab

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
	-- F91: the Front lawn tab takes the strip's and grid's place, and Equip Best (for the inside) steps aside
	local lawn = category == LAWN_CHIP
	self._lawnTab.frame.Visible = lawn
	self._grid.Visible = not lawn
	self._strip.Visible = not lawn and self._hasPieces == true
	local equipBest: Button.Button? = self._equipBest
	if equipBest then
		equipBest.instance.Visible = not lawn
	end
	if lawn and self._state then
		self._lawnTab:render(self._state)
	end
	self:_applyVisible()
end

-- F91: whether the Front lawn chip shows; off with its tab picked goes back to All.
function DecorShop._renderLawnLive(self: any)
	local plot: Instance? = self._plot
	local live =
		LawnLogic.live(self._state, if plot ~= nil then plot:GetAttribute("LawnPath") else nil)
	self._lawnLive = live
	for _, chip in self._chips do
		if chip.category == LAWN_CHIP then
			chip.button.instance.Visible = live
		end
	end
	if not live and self._filter == LAWN_CHIP then
		self:_setFilter("All")
	end
end

function DecorShop.bindPlot(self: any, plot: Instance?)
	if plot == self._plot then
		return
	end
	local connection: RBXScriptConnection? = self._plotConnection
	if connection then
		connection:Disconnect()
		self._plotConnection = nil
	end
	self._plot = plot
	if plot ~= nil then
		self._plotConnection = plot:GetAttributeChangedSignal("LawnPath"):Connect(function()
			self:_renderLawnLive()
		end)
	end
	self:_renderLawnLive()
end

function DecorShop.showLawn(self: any)
	if self._lawnLive then
		self:_setFilter(LAWN_CHIP)
	end
end

-- A card shows when its chip is picked; a crate piece, or a coin piece that now comes from crates (F97), only once
-- the player owns it (the Decor Index shows the rest).
function DecorShop._applyVisible(self: any)
	local state: Types.PlayerState? = self._state
	for _, card in self._cards do
		local owned = state ~= nil and state.decorOwned[card.def.id] == true
		card.frame.Visible = (self._filter == "All" or card.chip == self._filter)
			and (not card.crateOnly or owned)
	end
end

-- The strip's slots: Wallpaper, Floor and Paint (the piece in use, or "Plain"), the decor spots, then Door and Cat
-- flap when the catalog has pieces of those kinds.
function DecorShop._buildStrip(self: any)
	for _, slot in self._slots do
		slot.icon:destroy()
		slot.connection:Disconnect()
		slot.frame:Destroy()
	end
	table.clear(self._slots)
	local present: { [string]: boolean } = {}
	for _, def in self._decor do
		local kind = DecorPieces.info(def).kind
		if kind then
			present[kind] = true
		end
	end
	local kinds: { string } = {}
	for _, kind in STRIP_ORDER do
		if not LATE_KINDS[kind] or present[kind] then
			table.insert(kinds, kind)
		end
	end
	for order, kind in kinds do
		local frame: TextButton = Create("TextButton", {
			Name = kind,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = PAL.card,
			BorderSizePixel = 0,
			LayoutOrder = order,
			Size = UDim2.fromOffset(SLOT_WIDTH, STRIP_HEIGHT),
			Parent = self._strip,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
			Create("UIStroke", { Color = PAL.cardStroke, Thickness = Theme.sizes.stroke }),
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
			TextColor3 = PAL.subtext,
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
		local look = SLOT_LOOK[slot.kind]
		local picture = if look then ShopIcons.clean(look.picture) else nil
		if slot.kind == "spots" then
			slot.icon:set(
				nil,
				DecorPieces.kindIcon("furniture", Theme.icons.decor),
				nil,
				picture,
				if look then look.tint else nil
			)
			slot.value.Text = ("%d / %d"):format(used, spots)
			slot.value.TextColor3 = if used >= spots then PAL.red else PAL.text
			continue
		end
		local def = DecorPieces.inUse(self._decor, state.decorPlaced, slot.kind)
		local piece = DecorPieces.info(def)
		-- the piece in use, else (Plain) the kind's clean symbol on its light tile
		slot.icon:set(
			if def then def.asset else nil,
			DecorPieces.kindIcon(slot.kind, Theme.icons.decor),
			piece.rarity,
			if def then nil else picture,
			if def or not look then nil else look.tint
		)
		slot.value.Text = if def then def.name else "Plain"
		slot.value.TextColor3 = if def then PAL.text else PAL.subtext
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
	self._hasPieces = hasPieces
	self._strip.Visible = hasPieces
	local gridTop = self._chipHeight
		+ Theme.sizes.gap
		+ (if hasPieces then STRIP_HEIGHT + Theme.sizes.gap else 0)
	self._grid.Position = UDim2.fromOffset(0, gridTop)
	self._grid.Size = UDim2.new(1, 0, 1, -gridTop)
	if hasPieces then
		self:_buildStrip()
	end

	-- chips: All + each category (a piece's kind) in catalog order
	local categories = { "All" }
	if #LawnLogic.pieces() > 0 then
		table.insert(categories, LAWN_CHIP) -- F91: shown while the lawn is live
	end
	for _, decor in all do
		local chip = chipOf(decor)
		if not table.find(categories, chip) then
			table.insert(categories, chip)
		end
	end
	for index, category in categories do
		local lawn = category == LAWN_CHIP
		local button = Button.new({
			name = if lawn then "FrontLawn" else category,
			text = if lawn then LAWN_TEXT else category,
			style = "ghost",
			size = UDim2.fromOffset(
				math.max(CHIP_MIN_WIDTH, #(if lawn then LAWN_TEXT else category) * 11 + CHIP_PAD),
				self._chipHeight
			),
			textSize = Theme.sizes.textSmall,
			layoutOrder = index,
			parent = self._chipRow,
			sound = "uiTab",
			onClick = function()
				self:_setFilter(category)
			end,
		})
		button.instance.Visible = not lawn or self._lawnLive
		table.insert(self._chips, { category = category, button = button })
	end

	for index, decor in all do
		local piece = DecorPieces.info(decor)
		local card: Frame = Create("Frame", {
			Name = decor.id,
			BackgroundColor3 = PAL.card,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Parent = self._grid,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
			Create("UIStroke", { Color = PAL.cardStroke, Thickness = Theme.sizes.stroke }),
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
				piece.rarity,
				ShopIcons.decor(decor.id)
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
			-- the piece's clean picture (#1072) on its coloured block; the first letter stands in until it loads
			-- (DecorDef.asset names the 3D model, not an image)
			local letter = text({
				Size = UDim2.fromScale(1, 1),
				FontFace = Theme.fonts.display,
				TextSize = 34,
				TextColor3 = Theme.colors.paper,
				TextXAlignment = Enum.TextXAlignment.Center,
				Text = decor.name:sub(1, 1),
				Parent = art,
			})
			local picture = ShopIcons.decor(decor.id)
			if picture then
				IconArt.setImage(letter, picture, 0.86)
			end
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
			TextColor3 = PAL.subtext,
			Text = if piece.kind
				then ("+%s money while in use"):format(Format.percent(decor.bonus or 0))
				else decor.effect or decor.description or "",
			Parent = card,
		})

		local action = Button.new({
			name = "Action",
			text = Format.money(decor.cost),
			style = "primary",
			size = UDim2.new(1, -20, 0, self._actionHeight),
			position = UDim2.new(0, 10, 1, -(self._actionHeight + 10)),
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
			crateOnly = piece.kind ~= nil or decor.source == "crate", -- F97: never sold for coins
			kind = piece.kind,
			mode = "buy",
		}
	end
	self:_setFilter(if self._filter == LAWN_CHIP and self._lawnLive then LAWN_CHIP else "All")
end

function DecorShop.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	self:_build()
	self._dirty = true
end

-- Equip Best: grey while a press waits for the server, or with no decor owned at all.
function DecorShop._renderBest(self: any)
	local button: Button.Button? = self._equipBest
	if button == nil then
		return
	end
	local state: Types.PlayerState? = self._state
	local owned = false
	if state then
		for _, isOwned in state.decorOwned do
			if isOwned then
				owned = true
				break
			end
		end
	end
	button:setEnabled(owned and self._bestPressed == nil)
end

function DecorShop.render(self: any, state: Types.PlayerState)
	self._state = state
	self._bestPressed = nil -- the sync the server sends after Equip Best
	self:_renderBest()
	self:_renderLawnLive()
	if not self.frame.Visible then
		self._dirty = true
		return
	end
	self._dirty = false
	if self._filter == LAWN_CHIP then
		self._lawnTab:render(state)
	end
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
		-- crate pieces say when they are in use; coin decor says it is owned
		card.owned.Visible = if card.piece then isPlaced else isOwned
		card.owned.Text = if card.piece then "In use" else "Owned"
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
			-- a wallpaper, floor, paint, door set or cat flap: one in use of each kind; Use it swaps it in, Remove
			-- brings back the plain look or the cafe's own doors (reviewer N171)
			card.mode = if isPlaced then "remove" else "use"
			card.action:setText(if isPlaced then "Remove" else "Use it")
			card.action:setStyle(if isPlaced then "ghost" else "primary")
			card.action:setEnabled(isOwned)
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
		elseif card.crateOnly then
			-- F97: crate find only (hidden until owned, so this only shows for a moment after a trade or a reset)
			card.mode = "crate"
			card.action:setText(Theme.icons.crate .. " From crates")
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
	local equipBest: Button.Button? = self._equipBest
	if equipBest then
		equipBest:destroy()
	end
	local connection: RBXScriptConnection? = self._plotConnection
	if connection then
		connection:Disconnect()
	end
	self._lawnTab:destroy()
	self._panel:destroy()
end

return DecorShop
