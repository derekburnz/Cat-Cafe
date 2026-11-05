--!strict
-- The Store window (Derek 2026-11-02 20:01: "store still needs to be added"), opened by the gold Store tile at the
-- top of the HUD's left menu. Monetization-Agent's shop-and-pass-plan says what is sold and the rules: nothing random,
-- no coins for Robux, the price in Robux on the card before Roblox's own window, prices read from Roblox at runtime,
-- no timers, no pop-ups.
--
-- #1425 (Derek2 11-05: "rework the store menu so that it shows featured packages and multiple passes at once... if
-- people have to scroll down for the best packs they will never be bought"): a left rail of tabs (StoreLogic.TABS:
-- Featured, Passes, Cats, Potions, Cafe Pass, each shown only while it has a card) and the page beside it. The Store
-- opens on Featured: one big hero card across the top and a row of three top picks under it (StoreLogic.featured),
-- sized to fit the window with no scrolling on every screen. Every other tab is a grid of cards, 3 across (2 on a
-- narrow window) and 2 rows tall on desktop and tablet, scrolling for the rest. The rail stays on the left on a phone
-- too: phones play sideways, where height is short and width is not.
--
-- Each card shows its picture, name, what it does and one button: the price ("R$5"), "..." while the price loads or
-- "Soon" while off sale; an owned pass shows "Owned" in green in place of the button. Derek 2026-11-03 01:41 ("make
-- sure the store is good and stands out", #1020): gold-tinted cards with a bright clean picture tile and the gold
-- Store-style price button, honest for a young audience (monetization-policy): the price plainly, no timers, no sale,
-- "best value" or "limited" badges. The money ladder shows its next rung only. A line over the page says passes are
-- kept for good. buy(passId) opens Roblox's purchase window (Components/PassShop); the server turns the pass on when
-- Roblox says it was bought.

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local IconArt = require(script.Parent.Parent.Components.IconArt)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local Scale = require(script.Parent.Parent.Scale)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local StoreLogic = require(script.Parent.Parent.Components.StoreLogic)
local Theme = require(script.Parent.Parent.Theme)

export type Callbacks = {
	buy: (passId: number) -> (),
	close: () -> (),
	-- #1428: the Codes tab came into view (true) or left it (false), so the code box can start fresh or clear
	codes: ((shown: boolean) -> ())?,
}

-- the dark window palette (#1028), in place of Theme.modal
local PAL = Theme.dark

export type Store = {
	frame: Frame,
	render: (
		self: Store,
		rows: { StoreLogic.Row },
		prices: { [number]: StoreLogic.Price }
	) -> (),
	showTab: (self: Store, tab: string) -> (),
	tab: (self: Store) -> string,
	closed: (self: Store) -> (),
	codesPage: Frame, -- the Codes tab's page, where Screens/Codes mounts its box (#1428)
	destroy: (self: Store) -> (),
}

local MAX_SIZE = Vector2.new(880, 580)
local NOTE_H = 24
local GAP = Theme.sizes.gap
local RAIL_W = 150
-- the clean symbol on a pass's picture tile (the glyph shows until it loads, and for a pass without one)
local CLEAN_PICTURE: { [string]: string } = {
	money = "Bag",
}
-- #1191: a card that sells a shop-only cat shows that cat (Coordinator 11-05); each card stays hidden while its id
-- is 0 (StoreLogic)
local SHOP_CAT: { [string]: string } = {
	royalCat = "DuchessMarzipan",
	kingPack = "KingCroissant",
	starterBundle = "Sprinkles",
}
-- the picture tile's fill: the gold of the HUD Store tile and price button (Theme.button.store)
local TILE_FILL = ColorSequence.new(Theme.button.store.top, Theme.button.store.bottom)
-- #1221 (Derek 2026-11-04: the pass cards "push out past the sides" of the window and "lose their outlines"): a
-- UIStroke is drawn outside its card, and the list clips at its own edge, so the list keeps the outline's width
-- inside its edges plus an even gap on both sides. The scroll bar takes its own strip (VerticalScrollBarInset), so
-- the cards shrink when it shows and never run under it.
local CARD_STROKE = Theme.sizes.stroke + 1 -- the card's gold outline
local SCROLL_BAR = 6
local CARD_SIDE = 4 -- between a card's outline and the page's edge (and the scroll bar)
local CARD_INSET = CARD_STROKE + CARD_SIDE
local CARD_PAD = 10 -- inside a card, round its picture, words and button
-- a grid card (and a top pick): the picture and name side by side, what it does under them, the button at the foot
local TILE = 52
local EFFECT_MIN = 48 -- three small lines at least
local CELL_MAX = 230 -- a grid card no taller than this, however tall the window
local GRID_COLUMNS = 3
local NARROW = 520 -- a page narrower than this (design px) gets 2 columns
-- the hero: a big picture, the name and what you get, the price button at the right
local HERO_TILE_MAX = 132
local HERO_BUTTON_W = 150
local HERO_MIN = 100
-- On a short page (a phone held sideways) the picks drop their descriptions, so the hero and the three picks still
-- fit with no scrolling; each pick keeps its picture, name and price, and the tabs show the details.
local HERO_ROOM = 150 -- the hero wants at least this much beside the picks before they keep their words

local Store = {}
Store.__index = Store

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

function Store.new(callbacks: Callbacks): Store
	local self = setmetatable({}, Store) :: any
	self._callbacks = callbacks
	self._cards = {} :: { [string]: any } -- "hero", "pick1" to "pick3", and "grid:<key>" for the tab pages
	self._railButtons = {} :: { [string]: any }
	self._tab = "featured"
	self._rows = {} :: { StoreLogic.Row }
	self._prices = {} :: { [number]: StoreLogic.Price }
	self._actionHeight = Scale.tapHeight(Theme.sizes.touchMin, Theme.sizes.buttonDepth)
	self._cellMin = CARD_PAD + TILE + 6 + EFFECT_MIN + 6 + self._actionHeight + CARD_PAD
	self._pickCompact = CARD_PAD + TILE + 6 + self._actionHeight + CARD_PAD
	self._compact = false

	local panel = Panel.new({
		dark = true, -- #1028
		name = "Store",
		color = Theme.colors.goldDark,
		icon = Theme.icons.store,
		title = "Store",
		subtitle = "Help your cafe grow",
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = MAX_SIZE, Parent = panel.frame })
	self._panel = panel
	self.frame = panel.frame

	-- the rail: one button per tab, top to bottom, a finger tall on touch (no lip, closer together, so six fit a
	-- phone held sideways); it scrolls only on a screen too short for them all
	local touch = Scale.isTouch()
	local railButtonH = Scale.tapHeight(Theme.sizes.touchMin)
	self._rail = Create("ScrollingFrame", {
		Name = "Rail",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(0, RAIL_W, 1, 0),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = PAL.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel.content,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, if touch then 4 else GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for order, tab in StoreLogic.TABS do
		local id = tab.id
		self._railButtons[id] = Button.new({
			name = id,
			text = tab.name,
			icon = tab.icon,
			style = if id == self._tab then "gold" else "ghost",
			size = UDim2.new(1, -6, 0, railButtonH),
			textSize = Theme.sizes.textBody,
			layoutOrder = order,
			parent = self._rail,
			onClick = function()
				self:showTab(id)
			end,
		})
	end

	-- the page beside the rail, under the note
	local pageX = RAIL_W + GAP + 4
	text({
		Name = "Note",
		Position = UDim2.fromOffset(pageX, 0),
		Size = UDim2.new(1, -pageX, 0, NOTE_H),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		Text = "Passes are yours to keep. Prices are in Robux.",
		Parent = panel.content,
	})
	local pages: Frame = Create("Frame", {
		Name = "Pages",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(pageX, NOTE_H + GAP),
		Size = UDim2.new(1, -pageX, 1, -(NOTE_H + GAP)),
		Parent = panel.content,
	})
	self._pages = pages

	-- Featured: the hero over the three picks, no scrolling (the outlines kept inside its edges, #1221)
	self._featured = Create("Frame", {
		Name = "Featured",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = pages,
	}, {
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, CARD_INSET),
			PaddingRight = UDim.new(0, CARD_INSET),
			PaddingTop = UDim.new(0, CARD_STROKE),
			PaddingBottom = UDim.new(0, CARD_STROKE),
		}),
	})
	self._picks = Create("Frame", {
		Name = "Picks",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, self._cellMin),
		Parent = self._featured,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, GAP + 2 * CARD_STROKE),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._empty = text({
		Name = "Empty",
		Size = UDim2.new(1, 0, 0, 60),
		TextColor3 = PAL.subtext,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		Text = "Nothing in the Store yet. Come back soon!",
		Visible = false,
		Parent = self._featured,
	})

	-- Codes (#1428): Screens/Codes mounts its box here (UI.store.start)
	self.codesPage = Create("Frame", {
		Name = "CodesPage",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = pages,
	}, {
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, CARD_INSET),
			PaddingRight = UDim.new(0, CARD_INSET),
			PaddingTop = UDim.new(0, GAP),
		}),
	})

	-- every other tab: one grid, showing the cards of the tab picked
	self._grid = Create("UIGridLayout", {
		CellPadding = UDim2.fromOffset(GAP + 2 * CARD_STROKE, GAP + 2 * CARD_STROKE),
		CellSize = UDim2.fromOffset(200, self._cellMin),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	self._list = Create("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = SCROLL_BAR,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar, -- the bar's strip is not under the cards
		ScrollBarImageColor3 = PAL.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = false,
		Parent = pages,
	}, {
		self._grid,
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, CARD_INSET),
			PaddingRight = UDim.new(0, CARD_INSET),
			PaddingTop = UDim.new(0, CARD_STROKE),
			PaddingBottom = UDim.new(0, CARD_STROKE),
		}),
	})

	self._sizeChanged = pages:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_layout()
	end)
	return self :: Store
end

-- A gold card: `look` "hero" (wide, the button at the right) or "tile" (a grid card or top pick, the button at the
-- foot). Its picture, words and button are filled by _fill.
function Store._makeCard(
	self: any,
	slot: string,
	look: string,
	parent: Instance,
	order: number
): any
	local hero = look == "hero"
	local card: Frame = Create("Frame", {
		Name = slot,
		LayoutOrder = order,
		BackgroundColor3 = PAL.goldCard,
		BorderSizePixel = 0,
		Size = if hero then UDim2.new(1, 0, 0, HERO_MIN) else UDim2.new(1, 0, 1, 0),
		Parent = parent,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", {
			Color = Theme.colors.gold,
			Thickness = CARD_STROKE,
		}),
		-- a soft light along the top, so the card reads as a lit gold panel rather than a flat row
		Create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205)),
		}),
	})
	local tileSize = if hero then HERO_MIN - 2 * CARD_PAD else TILE
	local tile: Frame = Create("Frame", {
		Name = "Tile",
		AnchorPoint = if hero then Vector2.new(0, 0.5) else Vector2.new(0, 0),
		Position = if hero
			then UDim2.new(0, CARD_PAD + 4, 0.5, 0)
			else UDim2.fromOffset(CARD_PAD, CARD_PAD),
		Size = UDim2.fromOffset(tileSize, tileSize),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = card,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0.26, 0) }),
		Create("UIGradient", { Rotation = 90, Color = TILE_FILL }),
	})
	Outline.border(tile, if hero then 4 else 3)
	local glyph = text({
		Name = "Icon",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextScaled = true,
		Parent = tile,
	})
	Create("UIPadding", {
		PaddingTop = UDim.new(0.18, 0),
		PaddingBottom = UDim.new(0.18, 0),
		Parent = glyph,
	})
	local name = text({
		Name = "Name",
		FontFace = Theme.fonts.display,
		TextSize = if hero then Theme.sizes.textTitle else Theme.sizes.textBody + 2,
		TextWrapped = not hero,
		Parent = card,
	})
	Outline.text(name)
	local effect = text({
		Name = "Effect",
		TextSize = if hero then Theme.sizes.textBody else Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = card,
	})
	local buttonSize = if hero
		then UDim2.fromOffset(HERO_BUTTON_W, self._actionHeight)
		else UDim2.new(1, -2 * CARD_PAD, 0, self._actionHeight)
	local buttonAnchor = if hero then Vector2.new(1, 0.5) else Vector2.new(0.5, 1)
	local buttonPosition = if hero
		then UDim2.new(1, -(CARD_PAD + 4), 0.5, 0)
		else UDim2.new(0.5, 0, 1, -CARD_PAD)
	-- an owned pass: the green word in place of the button (no price)
	local owned = text({
		Name = "Owned",
		AnchorPoint = buttonAnchor,
		Position = buttonPosition,
		Size = buttonSize,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextColor3 = PAL.good,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Owned ✓",
		Visible = false,
		Parent = card,
	})
	Outline.text(owned)
	local entry: any = {
		frame = card,
		look = look,
		tile = tile,
		glyph = glyph,
		name = name,
		effect = effect,
		owned = owned,
		passId = 0,
		key = "",
	}
	entry.button = Button.new({
		name = "Buy",
		text = "...",
		style = "ghost",
		size = buttonSize,
		anchorPoint = buttonAnchor,
		position = buttonPosition,
		textSize = if hero then Theme.sizes.textLarge else Theme.sizes.textBody,
		enabled = false,
		parent = card,
		onClick = function()
			if entry.passId ~= 0 then
				self._callbacks.buy(entry.passId)
			end
		end,
	})
	self:_place(entry)
	self._cards[slot] = entry
	return entry
end

-- Where a card's words go for its current size: a tile card's are fixed, the hero's follow its height.
function Store._place(self: any, entry: any)
	local action = self._actionHeight
	if entry.look == "hero" then
		local height = entry.frame.Size.Y.Offset
		local side = math.min(height - 2 * CARD_PAD, HERO_TILE_MAX)
		entry.tile.Size = UDim2.fromOffset(side, side)
		local left = CARD_PAD + 4 + side + 16
		local right = HERO_BUTTON_W + CARD_PAD + 4 + 16
		local nameH = Theme.sizes.textTitle + 8
		local lineH = entry.effect.TextSize + 3
		local wordsH = math.min(height - 2 * CARD_PAD, nameH + 6 + 5 * lineH)
		local top = math.floor((height - wordsH) / 2)
		entry.name.Position = UDim2.fromOffset(left, top)
		entry.name.Size = UDim2.new(1, -(left + right), 0, nameH)
		entry.effect.Position = UDim2.fromOffset(left, top + nameH + 6)
		entry.effect.Size = UDim2.new(1, -(left + right), 0, math.max(wordsH - nameH - 6, 0))
	else
		local left = CARD_PAD + TILE + 8
		entry.name.Position = UDim2.fromOffset(left, CARD_PAD)
		entry.name.Size = UDim2.new(1, -(left + CARD_PAD), 0, TILE)
		local top = CARD_PAD + TILE + 6
		entry.effect.Position = UDim2.fromOffset(CARD_PAD, top)
		entry.effect.Size = UDim2.new(1, -2 * CARD_PAD, 1, -(top + 6 + action + CARD_PAD))
	end
end

-- The picture, words and button for `row` (nil hides the card).
function Store._fill(self: any, entry: any, row: StoreLogic.Row?)
	if row == nil then
		entry.frame.Visible = false
		entry.passId = 0
		entry.key = ""
		return
	end
	entry.frame.Visible = true
	entry.passId = row.passId
	entry.name.Text = row.name
	entry.effect.Text = row.effect
	if entry.key ~= row.key then
		entry.key = row.key
		entry.glyph.Text = row.icon
		local picture = CLEAN_PICTURE[row.key]
		-- a potion pack shows the Potions flask picture (#1256) until it has a pack picture of its own
		local image = if picture
			then ShopIcons.clean(picture)
			elseif SHOP_CAT[row.key] then ShopIcons.shopCat(SHOP_CAT[row.key])
			elseif row.product then ShopIcons.hud("Potion")
			else nil
		if image then
			IconArt.setImage(entry.glyph, image, 1.3)
		else
			IconArt.setImage(entry.glyph, nil)
			IconArt.set(entry.glyph, row.icon)
		end
	end
	local button = StoreLogic.button(row, self._prices[row.passId])
	entry.button:setText(button.text)
	entry.button:setStyle(button.style :: any)
	entry.button:setEnabled(button.enabled)
	entry.button.instance.Visible = not row.owned
	entry.owned.Visible = row.owned
end

-- Sizes the hero, the picks and the grid's cells to the page (design px; the window's UIScale shrinks it all).
function Store._layout(self: any)
	local scale = math.max(Scale.get(), 0.01)
	local width = self._pages.AbsoluteSize.X / scale - 2 * CARD_INSET
	local height = self._pages.AbsoluteSize.Y / scale - 2 * CARD_STROKE
	if width <= 0 or height <= 0 then
		return
	end
	local spacing = GAP + 2 * CARD_STROKE
	-- Featured: the picks as tall as a grid card needs, the hero takes the rest (never under HERO_MIN); on a short
	-- page the picks drop their words first
	local compact = height - spacing - self._cellMin < HERO_ROOM
	local pickMin = if compact then self._pickCompact else self._cellMin
	local picksH = math.clamp(math.floor(height * 0.5), pickMin, CELL_MAX)
	local heroH = math.max(height - picksH - spacing, HERO_MIN)
	picksH = math.max(height - heroH - spacing, pickMin)
	self._picks.Size = UDim2.new(1, 0, 0, picksH)
	self._compact = compact
	local pickW = math.floor((width - (StoreLogic.PICKS - 1) * spacing) / StoreLogic.PICKS)
	for index = 1, StoreLogic.PICKS do
		local entry = self._cards["pick" .. index]
		if entry then
			entry.frame.Size = UDim2.new(0, pickW, 1, 0)
			entry.effect.Visible = not compact
		end
	end
	local hero = self._cards.hero
	if hero then
		hero.frame.Size = UDim2.new(1, 0, 0, heroH)
		hero.effect.TextSize = if compact then Theme.sizes.textSmall else Theme.sizes.textBody
		self:_place(hero)
	end
	-- the grid: 3 across (2 on a narrow page), 2 rows in view when there is room
	local columns = if width < NARROW then 2 else GRID_COLUMNS
	local cellW = math.floor((width - SCROLL_BAR - (columns - 1) * spacing) / columns)
	local cellH = math.clamp(math.floor((height - spacing) / 2), self._cellMin, CELL_MAX)
	self._grid.CellSize = UDim2.fromOffset(cellW, cellH)
end

-- The tab the rail shows: its button gold, its page up (Featured, or the grid with that tab's cards).
function Store.showTab(self: any, tab: string)
	local shown = false
	for _, entry in StoreLogic.tabs(self._rows) do
		if entry.id == tab then
			shown = true
		end
	end
	local was = self._tab
	self._tab = if shown then tab else "featured"
	for id, button in self._railButtons do
		button:setStyle(if id == self._tab then "gold" else "ghost")
	end
	local featured = self._tab == "featured"
	local codes = self._tab == "codes"
	self._featured.Visible = featured
	self._list.Visible = not featured and not codes
	self.codesPage.Visible = codes
	local onCodes: ((boolean) -> ())? = self._callbacks.codes
	if (was == "codes") ~= codes and onCodes then
		onCodes(codes)
	end
	for slot, entry in self._cards do
		if slot:sub(1, 5) == "grid:" then
			local row = entry.row
			entry.frame.Visible = row ~= nil and row.tab == self._tab
		end
	end
	-- a new tab starts at the top; render calls this again on every state change while open, which snapped a
	-- scrolled list back up (#1605, Derek2 11-05), so the same tab keeps its place
	if not featured and not codes and was ~= self._tab then
		self._list.CanvasPosition = Vector2.zero
	end
end

function Store.tab(self: any): string
	return self._tab
end

-- The window closed: the Codes tab is out of view (its box clears), and the next open starts on Featured.
function Store.closed(self: any)
	local onCodes: ((boolean) -> ())? = self._callbacks.codes
	if self._tab == "codes" and onCodes then
		onCodes(false)
	end
	self._tab = "featured"
end

function Store.render(self: any, rows: { StoreLogic.Row }, prices: { [number]: StoreLogic.Price })
	self._rows = rows
	self._prices = prices
	-- the rail: Featured and each tab with a card
	local visibleTabs: { [string]: boolean } = {}
	for _, tab in StoreLogic.tabs(rows) do
		visibleTabs[tab.id] = true
	end
	for id, button in self._railButtons do
		button.instance.Visible = visibleTabs[id] == true
	end
	-- Featured
	local featured = StoreLogic.featured(rows)
	local hero = self._cards.hero or self:_makeCard("hero", "hero", self._featured, 0)
	self:_fill(hero, featured.hero)
	for index = 1, StoreLogic.PICKS do
		local slot = "pick" .. index
		local entry = self._cards[slot] or self:_makeCard(slot, "tile", self._picks, index)
		self:_fill(entry, featured.picks[index])
	end
	self._picks.Visible = #featured.picks > 0
	self._empty.Visible = #rows == 0
	-- the grid: a card per row, kept for the next render
	local shown: { [string]: boolean } = {}
	for order, row in rows do
		local slot = "grid:" .. row.key
		local entry = self._cards[slot] or self:_makeCard(slot, "tile", self._list, order)
		entry.frame.LayoutOrder = order
		entry.row = row
		self:_fill(entry, row)
		shown[slot] = true
	end
	for slot, entry in self._cards do
		if slot:sub(1, 5) == "grid:" and not shown[slot] then
			entry.row = nil
			entry.frame.Visible = false
		end
	end
	self:_layout()
	self:showTab(self._tab)
end

function Store.destroy(self: any)
	self._sizeChanged:Disconnect()
	for _, entry in self._cards do
		entry.button:destroy()
	end
	for _, button in self._railButtons do
		button:destroy()
	end
	self._panel:destroy()
end

return Store
