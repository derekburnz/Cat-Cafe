--!strict
-- Decor screen: category chips across the top, a grid of cards below.
-- A card shows cost, Place or Remove depending on what the player owns.
-- F53 (golden-fish.md section 4): crate pieces the player owns join the grid under their kind's chip, with their
-- rarity and "+4% tips while in use". #1751 (Derek2 11-06: "remove this second bar ... have it like lawn"): the
-- "Your cafe" strip of style slots is gone; every chip has one line on top like the Lawn tab's, "Plants: 3 in use
-- · Decor spots 5 / 8", then its cards, highest rarity first (DecorPieces.byRarity). A style card (wallpaper, floor, paint,
-- door set, cat flap) says "Use it" (it takes the place of the one in use) or "Remove"; furniture and decorations
-- say Place, Remove or "Spots full". The server checks the spots too.
-- Derek 2026-10-28: "decor menu buttons are squished a little too much", so the chips are taller and wider with more
-- room between them, and on a phone the chips and card buttons grow to a 44 px face (Scale.tapHeight).
-- #1120 (the 11-04 mockup, "Decor menu chips: fewer, roomier"): five chips at most, All, Lawn, Plants, Floor and
-- Walls (DecorPieces.chip folds each kind and category into them), sharing the row's width in 16 px words.
-- F97 section 2 (Derek 2026-10-28: "make it so decor is crate find only"): a coin piece the catalog marks
-- `source = "crate"` shows only once owned and never with a price, like a crate piece, and the grid always ends
-- with "Find more decor in crates" pointing to the Golden Fish Market.
-- Equip Best (Derek 2026-10-28, server #828): a pink button right of the chips while Config.DecorEquipBest is true,
-- like the HUD's. A press fires callbacks.equipBest and holds the button grey until the next sync (at most
-- PRESS_HOLD seconds); the server puts out the best owned pieces and toasts what changed, or that nothing would.
-- F91 (front-lawn.md section 3): a Lawn chip after All, shown while the lawn is live (the bound plot's LawnPath
-- attribute is set and ProfileSync has sent the lawn, Components/LawnLogic.live). Picking it swaps the strip and grid
-- for the Lawn cards (Screens/LawnTab). Since #1283 (lawn-nursery.md section 6e) it is a plain category like Plants,
-- Floor and Walls: no Edit lawn, and Equip Best stays.
-- #1624 (store-pass-looks.md, the cafe's Style panel): a "Style" chip at the end, shown while the player owns a sign
-- style, uniform style or theme to pick (Components/StyleLogic.shows). Picking it swaps the strip and grid for the
-- Style tab (Screens/StyleTab) the same way.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local DecorPieces = require(script.Parent.Parent.Components.DecorPieces)
local FitText = require(script.Parent.Parent.Components.FitText)
local Format = require(script.Parent.Parent.Components.Format)
local IconArt = require(script.Parent.Parent.Components.IconArt)
local IndexRewards = require(script.Parent.Parent.Components.IndexRewards)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local LawnLogic = require(script.Parent.Parent.Components.LawnLogic)
local LawnTab = require(script.Parent.LawnTab)
local MenuFamily = require(script.Parent.Parent.Components.MenuFamily)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local Scale = require(script.Parent.Parent.Scale)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local StyleLogic = require(script.Parent.Parent.Components.StyleLogic)
local StyleTab = require(script.Parent.StyleTab)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

-- the dark window palette (#1028), in place of Theme.modal
local PAL = MenuFamily.pal
local CARD = MenuFamily.card -- #3558: what sits on a picture card (cream in the family look)

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any

export type Callbacks = {
	buyDecor: (decorId: string) -> (),
	toggleDecor: (decorId: string, placed: boolean) -> (),
	close: () -> (),
	equipBest: (() -> ())?, -- Equip Best on the chips row; no button without it
	-- #1624: a Style tab button, kind "sign", "uniform" or "theme" and id "" for the default; no Style chip without it
	pickStyle: ((kind: string, id: string) -> ())?,
	-- #1751: the Lawn cards' Use and Remove (SetLawnSpot and SetLawnStyle)
	setLawnSpot: ((spotId: string, pieceId: string) -> ())?,
	setLawnStyle: ((kind: string, id: string) -> ())?,
}

export type DecorShop = {
	frame: Frame,
	setCatalog: (self: DecorShop, catalog: Types.Catalog) -> (),
	render: (self: DecorShop, state: Types.PlayerState) -> (),
	-- F91: the player's own plot, whose LawnPath attribute says the lawn is live; nil stops watching
	bindPlot: (self: DecorShop, plot: Instance?) -> (),
	showLawn: (self: DecorShop) -> (), -- the Front lawn chip picked, when the lawn is live
	showStyle: (self: DecorShop) -> (), -- #1624: the Style chip picked, when the player owns a style
	destroy: (self: DecorShop) -> (),
}

local CARD_WIDTH = 164
-- #2735 (Derek2 11-09: "see which decor images to make more clear/bigger since so many players are on mobile (make sure
-- they don't go out of bounds tho)"): on touch the window's scale shrinks every card, so the picture is taller there
-- (104 design px, about 70 on a phone, was about 50) and the card grows down with it; the width, and so the cards per
-- row, stays
local ART_H = if Scale.isTouch() then 104 else 76
local ART_LIFT = ART_H - 76 -- how far the name, effect and button move down
local CARD_TOP = 152 + ART_LIFT -- the card above its button: art, name, effect
local CHIP_HEIGHT = 44 -- was 36 with a 31 px face (Derek 2026-10-28: "squished")
local DECOR_BUILD_AFTER = 4 -- #3722: seconds after the catalog arrives before the quiet build of the cards starts
local DECOR_BUILD_BATCH = 4 -- cards a frame in the quiet build
local CHIP_GAP = 10 -- the chips share the row's width equally (#1120), so none is squished or scrolled off
local EQUIP_W = 156 -- Equip Best, in the header left of the X
local EQUIP_W_TOUCH = 128 -- #2403: narrower beside the X's bigger touch reach
local EQUIP_INSET = 8 -- #2403: on touch, this much shorter than the header so it sits inside it
local PRESS_HOLD = 3 -- seconds Equip Best stays grey after a press when no sync comes
local FOOTER_HEIGHT = 56
local SPOTS_BY_TIER: { number } = Config.DecorSpots or DecorPieces.SPOTS_BY_TIER
local TOTAL_HEIGHT = 28 -- #1751: "Plants: 3 in use  ·  Decor spots 5 / 8", the Lawn tab's line on every chip
local LAWN_CHIP = "Front lawn" -- F91: the chip that shows the Front lawn tab (the filter key)
local LAWN_TEXT = "Lawn" -- its words on the chip, short so the row is roomier (#964)
local STYLE_CHIP = "Style" -- #1624: the chip that shows the Style tab
-- #4278 (Derek 2026-11-14: "add little symbols beside these buttons on the top row of decor ... make sure style is
-- where outfits/things being is obvious", "maybe honestly move it infront of lawn"): a symbol before each chip's word,
-- the Style chip a shirt, and Style second, right after All
local CHIP_ICONS: { [string]: string } = {
	All = "🏠",
	Style = "👕",
	FrontLawn = "🌳",
	Plants = "🌿", -- #2015: no Unicode 12+ emoji (they draw blank in Roblox's font)
	Floor = "⬜",
	Walls = "🧱",
}
-- Placeholder art colour per category until the asset thread delivers images.
local CATEGORY_COLORS: { [string]: Color3 } = {
	Plants = Color3.fromHex("5FB85A"),
	Floor = Color3.fromHex("D97B4B"),
	Wall = Color3.fromHex("E8A0A0"),
	Furniture = Color3.fromHex("8FD3C1"),
	Toys = Color3.fromHex("FFC94D"),
}

local ART_TINT = 0.45 -- #2053: how far a rarity's colour is lightened behind a piece's picture

local DecorShop = {}
DecorShop.__index = DecorShop

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

function DecorShop.new(callbacks: Callbacks): DecorShop
	local self = setmetatable({}, DecorShop) :: any
	self._callbacks = callbacks
	self._cards = {} :: { [string]: any }
	self._chips = {} :: { any }
	self._decor = {} :: { Types.DecorDef } -- Catalog.decor and Catalog.crateDecor
	self._filter = "All"
	self._catalog = nil :: Types.Catalog?
	self._plot = nil :: Instance?
	self._plotConnection = nil :: RBXScriptConnection?
	self._lawnLive = false
	self._styleLive = false -- #1624: the player owns a style to pick
	self._state = nil :: Types.PlayerState?
	self._dirty = true
	self._cardNext = 0 -- #3722: how many of self._decor have a card so far
	self._cardsBuilt = true
	self._cardToken = 0
	self._spots = nil :: { used: number, open: number }? -- the decor spots in use and open, from the last render
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
	self._chipRow = Create("Frame", {
		Name = "Chips",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, chipHeight),
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
			text = "Equip Best",
			icon = Theme.icons.equipBest,
			image = ShopIcons.clean("EquipBest"), -- the clean sparkles (#1136)
			style = "berry", -- the HUD's Equip Best pink, apart from the gold chip that is picked
			-- #2403 (Derek2: "the equip best for decor top of banner is too big and sticking out"): on a touch screen the
			-- chips' tall tap height made it stick out past the header; it is the header's height there, and its Hit
			-- pad (Components/Button) still takes a full 44 px tap
			size = if Scale.isTouch()
				then UDim2.fromOffset(
					EQUIP_W_TOUCH,
					math.min(chipHeight, panel.headerHeight - EQUIP_INSET)
				)
				else UDim2.fromOffset(EQUIP_W, chipHeight),
			anchorPoint = Vector2.new(1, 0.5),
			-- on the window frame, not the header, so a phone's taller button is not clipped by the body
			position = UDim2.new(1, -(panel.closeReach + 8), 0, panel.headerHeight / 2 - 2),
			textSize = if Scale.isTouch() then Theme.sizes.textSmall else Theme.sizes.textBody,
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

	-- #1751: the chip's line on top, like the Lawn tab's (the "Your cafe" strip of style slots is gone)
	self._total = text({
		Name = "Total",
		Position = UDim2.fromOffset(4, chipHeight + Theme.sizes.gap),
		Size = UDim2.new(1, -8, 0, TOTAL_HEIGHT),
		FontFace = Theme.fonts.bodyBold,
		TextColor3 = PAL.text,
		Parent = panel.content,
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
		Outline.listPadding(10), -- #2294: room for the cards' outlines
	})
	-- F97: no shop; the last cell says where decor comes from now. A grid cell, so it sits after the last card.
	local footer: Frame = Create("Frame", {
		Name = "FindMore",
		LayoutOrder = 100000,
		BackgroundColor3 = CARD.card,
		BorderSizePixel = 0,
		Parent = self._grid,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = CARD.cardStroke, Thickness = Theme.sizes.stroke }),
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
		TextColor3 = CARD.subtext,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Golden Fish Market",
		Parent = footer,
	})
	self._footer = footer

	-- F91: the Lawn cards, in place of the strip and grid while its chip is picked (#1283)
	local lawnTab = LawnTab.new(panel.content, {
		setSpot = callbacks.setLawnSpot,
		setStyle = callbacks.setLawnStyle,
	})
	lawnTab.frame.Position = UDim2.fromOffset(0, chipHeight + Theme.sizes.gap)
	lawnTab.frame.Size = UDim2.new(1, 0, 1, -(chipHeight + Theme.sizes.gap))
	self._lawnTab = lawnTab

	-- #1624: the Style tab, the same way
	local pickStyle = callbacks.pickStyle
	if pickStyle then
		local styleTab = StyleTab.new(panel.content, { pick = pickStyle })
		styleTab.frame.Position = UDim2.fromOffset(0, chipHeight + Theme.sizes.gap)
		styleTab.frame.Size = UDim2.new(1, 0, 1, -(chipHeight + Theme.sizes.gap))
		self._styleTab = styleTab
	end

	return self :: DecorShop
end

-- The shown chips share the row's width equally: five with Lawn, four without it (#1120).
function DecorShop._layoutChips(self: any)
	local shown: { any } = {}
	for _, chip in self._chips do
		if chip.button.instance.Visible then
			table.insert(shown, chip)
		end
	end
	local count = math.max(#shown, 1)
	for _, chip in shown do
		chip.button.instance.Size =
			UDim2.new(1 / count, -CHIP_GAP * (count - 1) / count, 0, self._chipHeight)
	end
end

function DecorShop._setFilter(self: any, category: string)
	-- a filter with no chip (one the catalog has no piece for) falls back to All
	local known = category == "All"
	for _, chip in self._chips do
		known = known or chip.category == category
	end
	if not known then
		category = "All"
	end
	self._filter = category
	for _, chip in self._chips do
		chip.button:setStyle(if chip.category == category then "gold" else "ghost")
	end
	-- F91: the Lawn cards take the strip's and grid's place (Equip Best stays, #1283); the Style tab too (#1624), where
	-- Equip Best stays as well since #2403 (Derek2: "equip best disappears while in style menu so fix that")
	local lawn = category == LAWN_CHIP
	local style = category == STYLE_CHIP
	local tab = lawn or style
	self._lawnTab.frame.Visible = lawn
	local styleTab: StyleTab.StyleTab? = self._styleTab
	if styleTab then
		styleTab.frame.Visible = style
	end
	self._grid.Visible = not tab
	self._total.Visible = not tab
	if lawn and self._state then
		self._lawnTab:render(self._state)
	end
	if style and styleTab and self._state then
		styleTab:render(self._state)
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
	self:_layoutChips()
	if not live and self._filter == LAWN_CHIP then
		self:_setFilter("All")
	end
end

-- #1624: whether the Style chip shows; off with its tab picked goes back to All.
function DecorShop._renderStyleLive(self: any, state: Types.PlayerState)
	if self._styleTab == nil then
		return
	end
	local live = StyleLogic.shows(state)
	if live == self._styleLive then
		return
	end
	self._styleLive = live
	for _, chip in self._chips do
		if chip.category == STYLE_CHIP then
			chip.button.instance.Visible = live
		end
	end
	self:_layoutChips()
	if not live and self._filter == STYLE_CHIP then
		self:_setFilter("All")
	end
end

-- #1624: the Style chip picked, when the player owns a style.
function DecorShop.showStyle(self: any)
	if self._styleLive then
		self:_setFilter(STYLE_CHIP)
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
	local inUse = 0
	for _, card in self._cards do
		local owned = state ~= nil and state.decorOwned[card.def.id] == true
		local shown = (self._filter == "All" or card.chip == self._filter)
			and (not card.crateOnly or owned)
		card.frame.Visible = shown
		if shown and state ~= nil and state.decorPlaced[card.def.id] == true then
			inUse += 1
		end
	end
	-- #1751: "Plants: 3 in use  ·  Decor spots 5 / 8", like the Lawn tab's "Lawn: 8 out, +46% money"
	local line = ("%s: %d in use"):format(self._filter, inUse)
	local spots: { used: number, open: number }? = self._spots
	if spots then
		line ..= ("  ·  Decor spots %d / %d"):format(spots.used, spots.open)
	end
	self._total.Text = line
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

	-- the shop's and the Index's decor plus the crate pieces (Catalog.crateDecor), highest rarity first (#1751)
	local all = DecorPieces.byRarity(DecorPieces.all(catalog))
	self._decor = all
	local gridTop = self._chipHeight + Theme.sizes.gap + TOTAL_HEIGHT + Theme.sizes.gap
	self._grid.Position = UDim2.fromOffset(0, gridTop)
	self._grid.Size = UDim2.new(1, 0, 1, -gridTop)

	-- chips (#1120): All, Lawn while the lawn is live, then Plants, Floor and Walls when the catalog has a piece for them.
	-- #4278: Style right after All
	local categories = { "All" }
	if self._styleTab then
		table.insert(categories, STYLE_CHIP) -- #1624: shown while the player owns a style to pick
	end
	if #LawnLogic.pieces() > 0 then
		table.insert(categories, LAWN_CHIP) -- F91: shown while the lawn is live
	end
	local present: { [string]: boolean } = {}
	for _, decor in all do
		present[DecorPieces.chip(decor)] = true
	end
	for _, chip in DecorPieces.CHIPS do
		if present[chip] then
			table.insert(categories, chip)
		end
	end
	for index, category in categories do
		local lawn = category == LAWN_CHIP
		local button = Button.new({
			name = if lawn then "FrontLawn" else category,
			text = if lawn then LAWN_TEXT else category,
			icon = CHIP_ICONS[if lawn then "FrontLawn" else category],
			style = "ghost",
			-- a share of the row (widths from _layoutChips), so Button measures its corners from the height
			size = UDim2.new(1, 0, 0, self._chipHeight),
			textSize = Theme.sizes.textBody,
			layoutOrder = index,
			parent = self._chipRow,
			sound = "uiTab",
			onClick = function()
				self:_setFilter(category)
			end,
		})
		button.instance.Visible = if lawn
			then self._lawnLive
			elseif category == STYLE_CHIP then self._styleLive
			else true
		table.insert(self._chips, { category = category, button = button })
	end
	self:_layoutChips()

	-- #3722: the cards (about 4,000 instances) are not built here, inside UI.init's start-up run: a quiet build
	-- lays a few a frame once the game has started, and opening the window finishes the rest at once
	self:_queueCards()
end

-- #3722: one card, for the decor at `index` in self._decor (highest rarity first)
function DecorShop._makeCard(self: any, index: number, decor: Types.DecorDef)
	local piece = DecorPieces.info(decor)
	local card: Frame = Create("Frame", {
		Name = decor.id,
		BackgroundColor3 = CARD.card,
		BorderSizePixel = 0,
		LayoutOrder = index,
		Parent = self._grid,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = CARD.cardStroke, Thickness = Theme.sizes.stroke }),
	})

	-- art
	local art: Frame = Create("Frame", {
		Name = "Art",
		-- #2053 (Derek2: "fish tank background shows blue but its an epic"): a piece with a rarity sits on a soft
		-- tint of its rarity's colour, so the card reads as its pill does; one without keeps its category's colour
		BackgroundColor3 = if piece.rarity
			then Theme.rarityColor(piece.rarity):Lerp(Theme.colors.white, ART_TINT)
			else CATEGORY_COLORS[decor.category] or Theme.colors.mint,
		BackgroundTransparency = if piece.kind then 1 else 0,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 0, ART_H),
		Parent = card,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }) })
	local icon: ItemIcon.ItemIcon? = nil
	if piece.kind then
		-- a crate piece: its model (or its kind's glyph) on a tile in its rarity colour, and the rarity
		local pieceIcon = ItemIcon.new({
			parent = art,
			size = UDim2.fromOffset(ART_H, ART_H),
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
	else
		-- the piece's clean picture (#1072) on its coloured block; the first letter stands in until it loads
		-- (DecorDef.asset names the 3D model, not an image)
		local letter = text({
			Size = UDim2.fromScale(1, 1),
			FontFace = Theme.fonts.display,
			TextSize = if ART_H > 76 then 44 else 34,
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
	-- #1711: the rarity pill on every piece with a rarity, the first four Classic Crate pieces (no kind) too
	-- #1721: a Cafe Pass piece wears a "Cafe Pass" tag in its place (it is never found in crates)
	local passPiece = (decor :: any).source == "pass"
	-- #1822: a piece from a bundle names it ("King Cat Pack", Catalog.passDecor's pack), else the Cafe Pass
	local passName: string = (decor :: any).pack or "Cafe Pass"
	-- #2006 (Derek2: "make it have low boost and a rarity attached"): a pass piece with a rarity wears the rarity
	-- pill like any crate piece; its pass is named on its button ("From the Garden Decor Pack")
	local packPill = passPiece and piece.rarity == nil
	if piece.rarity or passPiece then
		local rarity = text({
			Name = "Rarity",
			BackgroundTransparency = 0,
			BackgroundColor3 = if packPill
				then Theme.colors.berry
				else Theme.rarityColor(piece.rarity),
			Position = UDim2.fromOffset(16, 16),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 20),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textTiny,
			TextColor3 = if packPill
				then Theme.colors.white
				else Theme.rarityTextColor(piece.rarity),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextTruncate = Enum.TextTruncate.None,
			Text = if packPill then passName else piece.rarity or "",
			ZIndex = 3,
			Parent = card,
		})
		Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = rarity })
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			Parent = rarity,
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
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall), Parent = unlock })
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

	-- a long name ("Watering Can Planter") shrinks to fit the card instead of ending in dots (Studio look,
	-- 2026-11-13)
	FitText.shrink(text({
		Name = "Name",
		Position = UDim2.fromOffset(10, 92 + ART_LIFT),
		Size = UDim2.new(1, -20, 0, 22),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody,
		Text = decor.name,
		Parent = card,
	}))
	text({
		Name = "Effect",
		Position = UDim2.fromOffset(10, 114 + ART_LIFT),
		-- #3961: two lines, 6 px above the button, so "+12% money, cats stare at it" is not cut off on a card
		Size = UDim2.new(1, -20, 0, 32),
		TextSize = Theme.sizes.textTiny,
		TextColor3 = CARD.subtext,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextYAlignment = Enum.TextYAlignment.Top,
		-- #2006: never "+0%": a piece with no bonus yet says where it comes from instead
		Text = if piece.kind and (decor.bonus or 0) > 0
			then ("+%s money while in use"):format(Format.percent(decor.bonus or 0))
			elseif passPiece then "From the " .. passName
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
		chip = DecorPieces.chip(decor),
		piece = piece.kind ~= nil,
		crateOnly = piece.kind ~= nil or decor.source == "crate", -- F97: never sold for coins
		kind = piece.kind,
		mode = "buy",
	}
end

-- #3722: builds up to `limit` more cards (all that are left when nil); once the last is built the filter and the
-- counts line are applied again over every card
function DecorShop._buildCards(self: any, limit: number?)
	if self._cardsBuilt then
		return
	end
	local all: { Types.DecorDef } = self._decor
	local stop = if limit ~= nil then math.min(#all, self._cardNext + limit) else #all
	for index = self._cardNext + 1, stop do
		self:_makeCard(index, all[index])
	end
	self._cardNext = stop
	if stop >= #all then
		self._cardsBuilt = true
		self:_setFilter(
			if self._filter == LAWN_CHIP and self._lawnLive
				then LAWN_CHIP
				elseif self._filter == STYLE_CHIP and self._styleLive then STYLE_CHIP
				else "All"
		)
	end
end

function DecorShop._queueCards(self: any)
	self._cardNext = 0
	self._cardsBuilt = false
	self._cardToken += 1
	local token: number = self._cardToken
	task.delay(DECOR_BUILD_AFTER, function()
		while token == self._cardToken and not self._cardsBuilt do
			self:_buildCards(DECOR_BUILD_BATCH)
			task.wait()
		end
		-- a window opened and painted before the last card is painted again in full
		if token == self._cardToken and self.frame.Visible and self._state then
			self:render(self._state)
		end
	end)
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
	self:_renderStyleLive(state)
	if not self.frame.Visible then
		self._dirty = true
		return
	end
	self._dirty = false
	self:_buildCards() -- #3722: whatever the quiet build has not reached yet
	if self._filter == LAWN_CHIP then
		self._lawnTab:render(state)
	end
	local styleTab: StyleTab.StyleTab? = self._styleTab
	if self._filter == STYLE_CHIP and styleTab then
		styleTab:render(state)
	end
	local replaced = if self._catalog then IndexRewards.replacedBy(self._catalog, state) else {}
	local used = DecorPieces.spotsUsed(self._decor, state.decorPlaced, replaced)
	local spots = DecorPieces.spots(state.tier, state.fishPerks, SPOTS_BY_TIER)
	self._spots = { used = used, open = spots }
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
			-- F97: crate find only (hidden until owned, so this only shows for a moment after a trade or a reset); a
			-- Cafe Pass piece (#1721) and a Cafe Event's free reward piece (#2534) say where they really come from
			card.mode = "crate"
			local source = (def :: any).source
			local from = Theme.icons.crate .. " From crates"
			if source == "pass" then
				from = "From the " .. ((def :: any).pack or "Cafe Pass")
			elseif source == "event" then
				from = "From a Cafe Event"
			end
			card.action:setText(from)
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
	self._cardToken += 1
	for _, chip in self._chips do
		chip.button:destroy()
	end
	for _, card in self._cards do
		card.action:destroy()
		if card.icon then
			card.icon:destroy()
		end
	end
	local equipBest: Button.Button? = self._equipBest
	if equipBest then
		equipBest:destroy()
	end
	local styleTab: StyleTab.StyleTab? = self._styleTab
	if styleTab then
		styleTab:destroy()
	end
	local connection: RBXScriptConnection? = self._plotConnection
	if connection then
		connection:Disconnect()
	end
	self._lawnTab:destroy()
	self._panel:destroy()
end

return DecorShop
