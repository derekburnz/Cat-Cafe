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
local Config = require(
	game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config")
) :: any
local Create = require(script.Parent.Parent.Components.Create)
local DealLogic = require(script.Parent.Parent.Components.DealLogic)
local FitText = require(script.Parent.Parent.Components.FitText)
local IconArt = require(script.Parent.Parent.Components.IconArt)
local LiveFlags =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("LiveFlags"))
local MenuFamily = require(script.Parent.Parent.Components.MenuFamily)
local MysticPoolLogic = require(script.Parent.Parent.Components.MysticPoolLogic)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local Scale = require(script.Parent.Parent.Scale)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local StoreBurst = require(script.Parent.Parent.Parent.Effects.StoreBurst)
local StoreLogic = require(script.Parent.Parent.Components.StoreLogic)
local StoreMotion = require(script.Parent.Parent.Parent.Effects.StoreMotion)
local Theme = require(script.Parent.Parent.Theme)

export type Callbacks = {
	buy: (passId: number) -> (),
	close: () -> (),
	-- #1428: the Codes tab came into view (true) or left it (false), so the code box can start fresh or clear
	codes: ((shown: boolean) -> ())?,
	-- #1823 §4: a tab with a New dot came into view, so the server can save it as seen
	seen: ((tab: string) -> ())?,
	-- #1888: every tab shown, the first on open included (the Store funnel's tab_viewed)
	tabShown: ((tab: string) -> ())?,
	-- #3996: Today's Deal's R$25 pressed: the server checks it and opens Roblox's prompt (PromptDeal)
	deal: ((productId: string) -> ())?,
}

-- the dark window palette (#1028), in place of Theme.modal
local PAL = MenuFamily.pal
local CARD = MenuFamily.card -- #3558: what sits on a picture card (cream in the family look)
local SALE_ROOM = 24 -- #3572: a tile's Sale badge line above its button (the badge is 20 px tall)

export type Store = {
	frame: Frame,
	render: (
		self: Store,
		rows: { StoreLogic.Row },
		prices: { [number]: StoreLogic.Price }
	) -> (),
	showTab: (self: Store, tab: string) -> (),
	setBag: (self: Store, bag: { StoreLogic.BagEntry }) -> (),
	setNew: (self: Store, tabs: { [string]: true }) -> (),
	-- #3996: PlayerState.dailyDeal (false or nil: no card); the next render shows it
	setDeal: (self: Store, view: any) -> (),
	hasNew: (self: Store) -> boolean,
	tab: (self: Store) -> string,
	closed: (self: Store) -> (),
	codesPage: Frame, -- the Codes tab's page, where Screens/Codes mounts its box (#1428)
	destroy: (self: Store) -> (),
}

local MAX_SIZE = Vector2.new(880, 580)
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
local GLYPH_PAD = 0.18 -- the emoji's inset top and bottom in its tile
local PICTURE_SCALE = 1.4 -- #1738: a picture over its whole tile, past its clear margin (art about 85% of the tile)
local EFFECT_MIN = 48 -- three small lines at least
local PERK_H = 20 -- #2147: the gold "+15% money" chip over a card's words
local PERK_BROWN = Color3.fromHex("4A2E12") -- dark words on gold, as the Pity cat tag
local EFFECT_MIN_TEXT = 12 -- a card's contents shrink no smaller than this (9 px on a phone) to fit
local CELL_MAX = 230 -- a grid card no taller than this, however tall the window
local GRID_COLUMNS = 3
local NARROW = 520 -- a page narrower than this (design px) gets 2 columns
-- #3572 (the `storeRework` switch, Model-Agent's OK'd mock): a tab's cards two across, each a wide card with its
-- picture at the left and the name, what it does and the price button beside it, about three rows in view
local WIDE_TILE = 76
local WIDE_NAME_H = 24
local WIDE_EFFECT_MIN = 30 -- two small lines at least
local WIDE_MAX = 170
local BAG_H = 40 -- #3572: the Potions tab's "In your bag now" strip over its cards
local BAG_ICON = 28
-- the hero: a big picture, the name and what you get, the price button at the right
local HERO_TILE_MAX = 132
local HERO_BUTTON_W = 150
local HERO_MIN = 100
-- On a short page (a phone held sideways) the picks drop their descriptions, so the hero and the three picks still
-- fit with no scrolling; each pick keeps its picture, name and price, and the tabs show the details.
local HERO_ROOM = 150 -- the hero wants at least this much beside the picks before they keep their words

-- #4026: an outfit pack's card on the Packs tab: its 2:1 art across the top with the white i at its corner, then the
-- name, the gold "Up to +100% money" chip, the short line and the price button
local PACK_PAD = 8
local PACK_NAME_H = 24
local PACK_LINE_H = 32 -- two small lines
local PACK_INFO = 36 -- the white i (and the sheet's X), a thumb's tap on touch
local PACK_MIN_W = 300 -- a pack card no narrower than this, else one a row
-- the art: the lower 352 of the 1024 x 512 render, where the cats sit close up (the sign's top is cut)
local ART_RECT_OFFSET = Vector2.new(0, 160)
local ART_RECT_SIZE = Vector2.new(1024, 352)
local ART_RATIO = ART_RECT_SIZE.X / ART_RECT_SIZE.Y
local PACK_SHEET_W = 460
local PACK_LINE_ROW = 30
local SHEET_PAD = 12
local SHEET_TITLE_H = 30
local SHEET_HOOK_H = 20
local SALE_ROW_H = 26 -- #4026: Featured's Sale row under the picks
local SALE_MOST = 3
local INK = Color3.fromHex("2C1642") -- the family kit's ink, the i's letter and ring

local PRELOAD_AFTER = 3 -- #2500: seconds after the Store is built (at join) before its pictures are fetched
local PRELOAD_BATCH = 8 -- pictures asked for at once
local PRELOAD_GAP = 0.25 -- seconds between batches
local QUIET_SECONDS = 2.5 -- a card's picture this long to load before its emoji shows

local Store = {}
Store.__index = Store

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

-- A card's contents at the biggest size up to `maxSize` whose wrapped lines fit the label's box, so a short phone
-- shows all of it smaller rather than losing the last line (Monetization-Agent 11-05: the King Cat Pack's "Can't be
-- traded" and Long Nap's "up to 24 h" were cut off). Never under EFFECT_MIN_TEXT.
local function fitText(label: TextLabel, maxSize: number)
	label.TextSize = maxSize
	if label.AbsoluteSize.X <= 0 or label.AbsoluteSize.Y <= 0 then
		return
	end
	-- TextFits reads the wrapped text against the box in the label's own font, at any UI scale
	while label.TextSize > EFFECT_MIN_TEXT and not label.TextFits do
		label.TextSize -= 1
	end
end

-- #3572: a wide card's words, fitted; when even the smallest size runs past its one line (a phone's narrow card),
-- they drop the worth line and stop at the line's end with "...", so nothing runs on under the price button.
-- #3930: a grid card does the same in its wrapped box: the worth line goes first, then the last line that fits
-- ends with "..."
local function fitEffect(entry: any)
	local effect = entry.effect :: TextLabel
	if effect.AbsoluteSize.X <= 0 or effect.AbsoluteSize.Y <= 0 then
		return -- no box yet (or a card mid-pop from nothing): keep the last fit until it has one
	end
	effect.Text = entry.fullText or effect.Text
	effect.TextWrapped = true
	effect.TextTruncate = Enum.TextTruncate.None
	fitText(effect, entry.effectMax)
	if effect.TextFits then
		return
	end
	effect.Text = entry.shortText or effect.Text
	if entry.wide then
		effect.TextWrapped = false
	else
		fitText(effect, entry.effectMax)
		if effect.TextFits then
			return
		end
	end
	effect.TextTruncate = Enum.TextTruncate.AtEnd
end

function Store.new(callbacks: Callbacks): Store
	local self = setmetatable({}, Store) :: any
	-- #2500 (Derek2: "lots of store images when first opening store take a second to load and show old default
	-- images"): fetch every Store picture in the background a little after joining, a few at a time
	task.delay(PRELOAD_AFTER, function()
		local list = ShopIcons.storeImages()
		for start = 1, #list, PRELOAD_BATCH do
			IconArt.preload(
				table.move(list, start, math.min(start + PRELOAD_BATCH - 1, #list), 1, {})
			)
			task.wait(PRELOAD_GAP)
		end
	end)
	self._callbacks = callbacks
	self._cards = {} :: { [string]: any } -- "hero", "pick1" to "pick3", and "grid:<key>" for the tab pages
	self._railButtons = {} :: { [string]: any }
	self._newDots = {} :: { [string]: Frame } -- #1823 §4: a pink dot per rail button
	self._new = {} :: { [string]: true } -- the tabs whose dot shows
	self._marked = {} :: { [string]: true } -- the tabs sent as seen this session, until the server's word comes back
	self._tab = "featured"
	self._rows = {} :: { StoreLogic.Row }
	self._deal = nil :: any -- #3996: PlayerState.dailyDeal
	self._seen = {} :: StoreLogic.Seen -- #1823: each card's pass and Owned at the last render, for the thank-you burst
	-- #1870: true until the first render after the window opens; that render only notes what is owned, so a pass
	-- bought while the Store was shut doesn't pop and burst on opening (and the cards are measured at rest)
	self._fresh = true
	self._prices = {} :: { [number]: StoreLogic.Price }
	self._ownedIds = {} :: { [number]: boolean }
	self._actionHeight = Scale.tapHeight(Theme.sizes.touchMin, Theme.sizes.buttonDepth)
	self._cellMin = CARD_PAD + TILE + 6 + EFFECT_MIN + 6 + self._actionHeight + CARD_PAD
	-- #3572: read once, when the Store is built at join, so a flip never changes a window under a player
	local reworkAttribute = LiveFlags.ATTRIBUTE_PREFIX .. StoreLogic.REWORK_FLAG
	self._rework = LiveFlags.shown(
		StoreLogic.REWORK_FLAG,
		game:GetService("ReplicatedStorage"):GetAttribute(reworkAttribute)
	)
	self._wideMin = math.max(
		CARD_PAD + WIDE_NAME_H + 2 + WIDE_EFFECT_MIN + 6 + self._actionHeight + CARD_PAD,
		WIDE_TILE + 2 * CARD_PAD
	)
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
		Outline.listPadding(7), -- #2294: room for the tabs' outlines, and the scroll bar on the right
	})
	for order, tab in StoreLogic.railTabs(self._rework) do
		local id = tab.id
		self._railButtons[id] = Button.new({
			name = id,
			text = tab.name,
			icon = tab.icon,
			image = ShopIcons.storeTab(id), -- #1674: the tab's picture; the emoji shows until it loads
			style = if id == self._tab then "gold" else "ghost",
			size = UDim2.new(1, 0, 0, railButtonH),
			textSize = Theme.sizes.textBody,
			layoutOrder = order,
			parent = self._rail,
			onClick = function()
				self:showTab(id)
			end,
		})
		-- #1823 §4: the New dot, 10 px pink on the button's top right; no number, no pulse
		self._newDots[id] = Create("Frame", {
			Name = "NewDot",
			BackgroundColor3 = Theme.colors.berry,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -3, 0, 3),
			Size = UDim2.fromOffset(10, 10),
			Visible = false,
			ZIndex = 6,
			Parent = self._railButtons[id].instance,
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	end

	-- the page beside the rail, from the top (#1690: no note row; cards say "Yours to keep", prices show Robux)
	local pageX = RAIL_W + GAP + 4
	local pages: Frame = Create("Frame", {
		Name = "Pages",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(pageX, 0),
		Size = UDim2.new(1, -pageX, 1, 0),
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
	-- #4026 (the approved store-v2 draft): the Sale row names the halved cards and their prices, under the picks. Words
	-- only: the old price is on each card's own Sale badge, and there is no timer
	self._saleRow = Create("Frame", {
		Name = "SaleRow",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, SALE_ROW_H),
		Visible = false,
		Parent = self._featured,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local saleTitle = text({
		Name = "Title",
		Size = UDim2.fromOffset(0, SALE_ROW_H),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.colors.gold,
		TextTruncate = Enum.TextTruncate.None,
		Text = "On sale",
		LayoutOrder = 0,
		Parent = self._saleRow,
	})
	MenuFamily.outline(saleTitle)
	self._saleKey = ""
	self._saleCount = 0
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

	-- #4026: the Packs tab, its own page of art cards (Store._packCard), and the white i's breakdown sheet
	self._packCards = {} :: { [string]: any }
	self._packGrid = Create("UIGridLayout", {
		CellPadding = UDim2.fromOffset(GAP + 2 * CARD_STROKE, GAP + 2 * CARD_STROKE),
		CellSize = UDim2.fromOffset(PACK_MIN_W, 300),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	self._packsPage = Create("ScrollingFrame", {
		Name = "PacksPage",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = SCROLL_BAR,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ScrollBarImageColor3 = PAL.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = false,
		Parent = pages,
	}, {
		self._packGrid,
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, CARD_INSET),
			PaddingRight = UDim.new(0, CARD_INSET),
			PaddingTop = UDim.new(0, CARD_STROKE),
			PaddingBottom = UDim.new(0, CARD_STROKE),
		}),
	})
	self:_packSheet(pages)

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

	-- #3572: with the rework on, the Potions tab leads with what the bag already holds (StoreLogic.bag), filled by
	-- setBag; the list moves down under it on that tab only
	self._bag = {} :: { StoreLogic.BagEntry }
	if self._rework then
		local strip: Frame = Create("Frame", {
			Name = "BagStrip",
			BackgroundColor3 = CARD.goldCard,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(CARD_INSET, CARD_STROKE),
			Size = UDim2.new(1, -2 * CARD_INSET - SCROLL_BAR, 0, BAG_H),
			Visible = false,
			Parent = pages,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
			Create("UIStroke", { Color = Theme.colors.gold, Thickness = CARD_STROKE }),
			Create("UIPadding", {
				PaddingLeft = UDim.new(0, CARD_PAD),
				PaddingRight = UDim.new(0, CARD_PAD),
			}),
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 12),
			}),
		})
		local title = text({
			Name = "Title",
			Text = "In your bag now:",
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textSmall,
			TextTruncate = Enum.TextTruncate.None,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, BAG_H),
			LayoutOrder = 0,
			Parent = strip,
		})
		MenuFamily.outline(title)
		self._bagStrip = strip
	end

	self._sizeChanged = pages:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_layout()
	end)
	return self :: Store
end

-- #3572: the potions the bag holds, for the Potions tab's strip (rework only). One chip per potion: its flask and
-- "x3", as the OK'd mock; the pack cards under it name each potion beside the same flask.
function Store.setBag(self: any, bag: { StoreLogic.BagEntry })
	self._bag = bag
	local strip = self._bagStrip
	if strip == nil then
		return
	end
	local key = {}
	for _, entry in bag do
		table.insert(key, entry.id .. "=" .. entry.count)
	end
	local signature = table.concat(key, ",")
	if signature == self._bagSignature then
		return
	end
	self._bagSignature = signature
	for _, child in strip:GetChildren() do
		if child.Name == "Potion" then
			child:Destroy()
		end
	end
	for order, entry in bag do
		local chip: Frame = Create("Frame", {
			Name = "Potion",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, BAG_ICON),
			LayoutOrder = order,
			Parent = strip,
		}, {
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 4),
			}),
		})
		local glyph = text({
			Name = "Icon",
			Size = UDim2.fromOffset(BAG_ICON, BAG_ICON),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextScaled = true,
			Parent = chip,
		})
		local images = ShopIcons.potionAll(entry.id)
		if #images > 0 then
			IconArt.setImages(glyph, images)
		else
			IconArt.set(glyph, "🧪")
		end
		local count = text({
			Name = "Count",
			Text = "x" .. entry.count,
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody,
			TextTruncate = Enum.TextTruncate.None,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, BAG_ICON),
			Parent = chip,
		})
		MenuFamily.outline(count)
	end
	self:_placeBag()
end

-- #3572: the strip shows on the Potions tab when the bag list has a potion; the list then starts under it.
function Store._placeBag(self: any)
	local strip = self._bagStrip
	if strip == nil then
		return
	end
	local shown = self._tab == "potions" and #self._bag > 0
	strip.Visible = shown and self._list.Visible
	local top = if shown then BAG_H + CARD_STROKE + GAP else 0
	self._list.Position = UDim2.fromOffset(0, top)
	self._list.Size = UDim2.new(1, 0, 1, -top)
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
	-- #3572: with the rework on, a tab page's card is a wide one (WIDE_TILE): the Featured cards stay as they are
	local wide = self._rework and slot:sub(1, 5) == "grid:"
	local card: Frame = Create("Frame", {
		Name = slot,
		LayoutOrder = order,
		BackgroundColor3 = CARD.goldCard,
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
	local tileSize = if hero then HERO_MIN - 2 * CARD_PAD elseif wide then WIDE_TILE else TILE
	local tile: Frame = Create("Frame", {
		Name = "Tile",
		AnchorPoint = if hero or wide then Vector2.new(0, 0.5) else Vector2.new(0, 0),
		Position = if hero
			then UDim2.new(0, CARD_PAD + 4, 0.5, 0)
			elseif wide then UDim2.new(0, CARD_PAD, 0.5, 0)
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
		PaddingTop = UDim.new(GLYPH_PAD, 0),
		PaddingBottom = UDim.new(GLYPH_PAD, 0),
		Parent = glyph,
	})
	local name = text({
		Name = "Name",
		FontFace = Theme.fonts.display,
		TextSize = if hero then Theme.sizes.textTitle else Theme.sizes.textBody + 2,
		TextWrapped = not hero and not wide,
		Parent = card,
	})
	MenuFamily.outline(name)
	local effect = text({
		Name = "Effect",
		TextSize = if hero then Theme.sizes.textBody else Theme.sizes.textSmall,
		TextColor3 = CARD.subtext,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = card,
	})
	local wideLeft = CARD_PAD + WIDE_TILE + 10 -- a wide card's words and button start here
	local buttonSize = if hero
		then UDim2.fromOffset(HERO_BUTTON_W, self._actionHeight)
		elseif wide then UDim2.new(1, -(wideLeft + CARD_PAD), 0, self._actionHeight)
		else UDim2.new(1, -2 * CARD_PAD, 0, self._actionHeight)
	local buttonAnchor = if hero
		then Vector2.new(1, 0.5)
		elseif wide then Vector2.new(1, 1)
		else Vector2.new(0.5, 1)
	local buttonPosition = if hero
		then UDim2.new(1, -(CARD_PAD + 4), 0.5, 0)
		elseif wide then UDim2.new(1, -CARD_PAD, 1, -CARD_PAD)
		else UDim2.new(0.5, 0, 1, -CARD_PAD)
	-- an owned pass: the green word in place of the button (no price)
	local owned = text({
		Name = "Owned",
		AnchorPoint = buttonAnchor,
		Position = buttonPosition,
		Size = buttonSize,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextColor3 = CARD.good,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "✓ Yours", -- #1823 (store-layout-v2.md §4)
		Visible = false,
		ZIndex = 3,
		Parent = card,
	})
	MenuFamily.outline(owned)
	-- #1823 §4: an owned card stays, greyed, so nobody buys twice and nothing hides
	local dim: Frame = Create("Frame", {
		Name = "Dim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 2,
		Parent = card,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	-- #1823 §2: one badge at most, top right ("Best Value" only when the parts left are worth 1.25 x the price)
	local badge = text({
		Name = "Badge",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 0,
		BackgroundColor3 = CARD.good,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textTiny,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		Visible = false,
		ZIndex = 3,
		Parent = card,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = badge })
	Create(
		"UIPadding",
		{ PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = badge }
	)
	-- #2147 (store-pass-looks.md 7): a gold chip leading the words, "+15% money" on the two outfit passes
	local perk = text({
		Name = "Perk",
		Size = UDim2.fromOffset(0, PERK_H),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.colors.gold,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PERK_BROWN,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		Visible = false,
		Parent = card,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = perk })
	Create("UIStroke", {
		Color = Theme.colors.goldDark,
		Thickness = 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = perk,
	})
	Create(
		"UIPadding",
		{ PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = perk }
	)
	local entry: any = {
		frame = card,
		look = look,
		wide = wide,
		perk = perk,
		tile = tile,
		glyph = glyph,
		name = name,
		effect = effect,
		effectMax = effect.TextSize, -- fitText's top size (the hero's drops on a short page)
		owned = owned,
		dim = dim,
		badge = badge,
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
			local deal = entry.dealProduct
			if deal ~= nil then
				-- #3996: the server checks today's deal and opens the prompt itself
				StoreMotion.press(entry.frame :: any)
				local press = (self._callbacks :: Callbacks).deal
				if press ~= nil then
					press(deal)
				end
			elseif entry.passId ~= 0 then
				-- #1823: the card dips with the tap (the Buy button already dips through its own UIScale, so
				-- StoreMotion moves the card rather than fight that tween)
				StoreMotion.press(entry.frame :: any) -- press takes a GuiButton; it only scales the object
				self._callbacks.buy(entry.passId)
			end
		end,
	})
	-- a new box (the window or the page resized): fit the words again
	effect:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		fitEffect(entry)
	end)
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
		local lineH = entry.effectMax + 3 -- the top size, not the fitted one, so the box never shrinks after it
		local wordsH = math.min(height - 2 * CARD_PAD, nameH + 6 + 5 * lineH)
		local top = math.floor((height - wordsH) / 2)
		entry.name.Position = UDim2.fromOffset(left, top)
		entry.name.Size = UDim2.new(1, -(left + right), 0, nameH)
		entry.perk.Position = UDim2.fromOffset(left, top + nameH + 6)
		local lift = if entry.perk.Visible then PERK_H + 4 else 0 -- #2147: the chip leads the words
		entry.effect.Position = UDim2.fromOffset(left, top + nameH + 6 + lift)
		entry.effect.Size = UDim2.new(1, -(left + right), 0, math.max(wordsH - nameH - 6 - lift, 0))
	elseif entry.wide then
		-- #3572: the picture at the left, the name and what it does beside it, the button under the words. The gold
		-- chip sits on the foot of the picture, so it never pushes the one line of words under the button
		local left = CARD_PAD + WIDE_TILE + 10
		entry.name.Position = UDim2.fromOffset(left, CARD_PAD)
		entry.name.Size = UDim2.new(1, -(left + CARD_PAD), 0, WIDE_NAME_H)
		local top = CARD_PAD + WIDE_NAME_H + 2
		entry.perk.AnchorPoint = Vector2.new(0.5, 1)
		entry.perk.Position = UDim2.new(0, CARD_PAD + WIDE_TILE / 2, 0.5, WIDE_TILE / 2 + 4)
		entry.effect.Position = UDim2.fromOffset(left, top)
		local saleRoom = if entry.saleLow then SALE_ROOM else 0
		entry.effect.Size =
			UDim2.new(1, -(left + CARD_PAD), 1, -(top + 6 + saleRoom + action + CARD_PAD))
		entry.badge.AnchorPoint = if entry.saleLow then Vector2.new(0, 1) else Vector2.new(1, 0)
		entry.badge.Position = if entry.saleLow
			then UDim2.new(0, left, 1, -(CARD_PAD + action + 6))
			else UDim2.new(1, -6, 0, 6)
	else
		local left = CARD_PAD + TILE + 8
		entry.name.Position = UDim2.fromOffset(left, CARD_PAD)
		entry.name.Size = UDim2.new(1, -(left + CARD_PAD), 0, TILE)
		local top = CARD_PAD + TILE + 6
		entry.perk.Position = UDim2.fromOffset(CARD_PAD, top)
		local lift = if entry.perk.Visible then PERK_H + 4 else 0 -- #2147: the chip leads the words
		entry.effect.Position = UDim2.fromOffset(CARD_PAD, top + lift)
		-- #3572: a tile's Sale badge sits on a line of its own just above the button (the old price over the new),
		-- so it never covers the name; the words give it the room
		local saleRoom = if entry.saleLow then SALE_ROOM else 0
		entry.effect.Size =
			UDim2.new(1, -2 * CARD_PAD, 1, -(top + lift + 6 + saleRoom + action + CARD_PAD))
		entry.badge.AnchorPoint = if entry.saleLow then Vector2.new(0, 1) else Vector2.new(1, 0)
		entry.badge.Position = if entry.saleLow
			then UDim2.new(0, CARD_PAD, 1, -(CARD_PAD + action + 6))
			else UDim2.new(1, -6, 0, 6)
	end
end

-- The picture, words and button for `row` (nil hides the card).
function Store._fill(self: any, entry: any, row: StoreLogic.Row?)
	if row == nil then
		entry.frame.Visible = false
		entry.passId = 0
		entry.key = ""
		entry.rowKey = ""
		return
	end
	entry.frame.Visible = true
	entry.passId = row.passId
	entry.dealProduct = nil -- #3996: the hero was Today's Deal
	entry.owned.Text = "✓ Yours"
	entry.rowKey = row.key -- #1823: the thank-you burst finds a bought row's cards by this
	entry.name.Text = row.name
	-- #1822: a bundle adds its "Worth R$X bought apart" line once every part's price is in
	local worth = StoreLogic.worthLine(row, self._prices, self._ownedIds)
	-- #3572: a wide card has room for one short line, so it keeps the first line of what the item does
	local firstLine = string.match(row.effect, "^[^\n]+") or row.effect
	local effect = if entry.wide then firstLine else row.effect
	entry.fullText = if worth then effect .. "\n" .. worth else effect
	entry.shortText = effect
	entry.effect.Text = entry.fullText
	-- #2147: the gold chip, placed before the words are fitted under it
	local perkText = row.perk or ""
	local perkShown = perkText ~= "" and not entry.compact
	if entry.perk.Text ~= perkText or entry.perk.Visible ~= perkShown then
		entry.perk.Text = perkText
		entry.perk.Visible = perkShown
		self:_place(entry)
	end
	fitEffect(entry)
	-- the money card's rung is part of its picture (2x, 3x and 4x each have one)
	local art = row.key .. (if row.multiplier then tostring(row.multiplier) else "")
	if entry.key ~= art then
		entry.key = art
		entry.glyph.Text = row.icon
		-- the card's own Store picture first (Tools-Agent 11-05), then the older stand-ins while it loads or if it
		-- fails: the clean symbol, the shop-only cat, and for a potion pack the Potions flask (#1256)
		local images: { string } = {}
		local function add(image: string?)
			if image then
				table.insert(images, image)
			end
		end
		add(ShopIcons.store(row.key, row.multiplier))
		local picture = CLEAN_PICTURE[row.key]
		add(
			if picture
				then ShopIcons.clean(picture)
				elseif SHOP_CAT[row.key] then ShopIcons.shopCat(SHOP_CAT[row.key])
				elseif row.product then ShopIcons.hud("Potion")
				else nil
		)
		-- #1738 (Derek2 11-06: "increase all the sizes of the pass images inside their bubble"): every store picture
		-- keeps a clear margin so it survives Roblox's circle crop (icons.STORE_PAD), so a picture drops the emoji's
		-- padding and draws a little over the tile: about 85% of it is art. The emoji keeps its padding.
		local padding = entry.glyph:FindFirstChildOfClass("UIPadding")
		local inset = if #images > 0 then 0 else GLYPH_PAD
		if padding then
			padding.PaddingTop = UDim.new(inset, 0)
			padding.PaddingBottom = UDim.new(inset, 0)
		end
		if #images > 0 then
			-- #2500: no old emoji flashing while the picture first loads (it shows only if the picture never comes)
			IconArt.quietWait(entry.glyph, QUIET_SECONDS)
			IconArt.setImages(entry.glyph, images, PICTURE_SCALE)
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
	entry.dim.Visible = row.owned
	-- one badge at most: #3572's Sale (red, with the true old price struck through) before Best Value
	local was = StoreLogic.saleWas(row, self._prices[row.passId], Config, os.time())
	local badge = if was
		then StoreLogic.saleBadge(was)
		else StoreLogic.badge(row, self._prices, self._ownedIds)
	entry.badge.Visible = badge ~= nil
	entry.badge.RichText = was ~= nil
	entry.badge.BackgroundColor3 = if was then Theme.colors.redDark else PAL.good
	entry.badge.Text = badge or ""
	local low = was ~= nil and entry.look ~= "hero"
	if (entry.saleLow == true) ~= low then
		entry.saleLow = low
		self:_place(entry)
	end
end

-- #3996: PlayerState.dailyDeal for the next render (false or nil: no card).
function Store.setDeal(self: any, view: any)
	self._deal = if type(view) == "table" then view else nil
end

-- #3996: Today's Deal on the hero card (nil hides it): the deal's picture, "Today's Deal", what is in it, the value line, the
-- Tomorrow line and the plain change line, and the R$25 button; once bought the button goes and the card says so.
function Store._fillDeal(self: any, entry: any, card: DealLogic.Card?)
	entry.dealProduct = nil
	if card == nil then
		entry.frame.Visible = false
		entry.key = ""
		return
	end
	entry.frame.Visible = true
	entry.passId = 0
	entry.rowKey = ""
	entry.name.Text = card.title
	entry.fullText = card.full
	entry.shortText = card.short
	entry.effect.Text = card.full
	entry.perk.Visible = false
	entry.badge.Visible = false
	entry.dim.Visible = false
	fitEffect(entry)
	local art = "deal:" .. card.kind .. ":" .. (card.potion or "")
	if entry.key ~= art then
		entry.key = art
		local images: { string } = {}
		if card.kind == "token" then
			local token = MysticPoolLogic.TOKEN_IMAGE
			if token ~= nil then
				table.insert(images, token)
			end
		else
			for _, image in ShopIcons.potionAll(card.potion) do
				table.insert(images, image)
			end
			local flask = ShopIcons.hud("Potion")
			if flask ~= nil then
				table.insert(images, flask)
			end
		end
		entry.glyph.Text = if card.kind == "token" then "🪙" else "🧪"
		local padding = entry.glyph:FindFirstChildOfClass("UIPadding")
		local inset = if #images > 0 then 0 else GLYPH_PAD
		if padding then
			padding.PaddingTop = UDim.new(inset, 0)
			padding.PaddingBottom = UDim.new(inset, 0)
		end
		if #images > 0 then
			IconArt.quietWait(entry.glyph, QUIET_SECONDS)
			IconArt.setImages(entry.glyph, images, PICTURE_SCALE)
		else
			IconArt.setImage(entry.glyph, nil)
			IconArt.set(entry.glyph, entry.glyph.Text)
		end
	end
	entry.button.instance.Visible = not card.bought
	entry.owned.Visible = card.bought
	if card.bought then
		entry.owned.Text = DealLogic.BOUGHT
	else
		entry.dealProduct = card.product
		entry.button:setText(card.price)
		entry.button:setStyle("store")
		entry.button:setEnabled(true)
	end
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
	-- #4026: the Sale row takes its strip at the foot of Featured, only where the hero and the picks keep their words
	local saleShown = self._saleCount > 0
		and height - SALE_ROW_H - 2 * spacing - self._cellMin >= HERO_ROOM
	self._saleRow.Visible = saleShown
	local saleH = if saleShown then SALE_ROW_H + spacing else 0
	self._picks.Position = UDim2.new(0, 0, 1, -saleH)
	height -= saleH
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
			entry.compact = compact -- #2147: no room for the perk chip either
			entry.perk.Visible = not compact and entry.perk.Text ~= ""
			self:_place(entry)
		end
	end
	local hero = self._cards.hero
	if hero then
		hero.frame.Size = UDim2.new(1, 0, 0, heroH)
		hero.effectMax = if compact then Theme.sizes.textSmall else Theme.sizes.textBody
		hero.effect.TextSize = hero.effectMax
		self:_place(hero)
	end
	-- the grid: 3 across (2 on a narrow page), 2 rows in view when there is room. A tab with one card (the Cafe Pass)
	-- gives it the whole width, so its long contents keep readable text on a phone.
	local single = #StoreLogic.tabRows(self._rows, self._tab) == 1
	local columns = if single then 1 elseif width < NARROW or self._rework then 2 else GRID_COLUMNS
	local cellW = math.floor((width - SCROLL_BAR - (columns - 1) * spacing) / columns)
	local cellH = if self._rework
		then math.clamp(math.floor((height - 2 * spacing) / 3), self._wideMin, WIDE_MAX)
		else math.clamp(math.floor((height - spacing) / 2), self._cellMin, CELL_MAX)
	self._grid.CellSize = UDim2.fromOffset(cellW, cellH)
	-- #4026: pack cards two a row where each keeps PACK_MIN_W, else one; the art is the lower part of the 2:1 render
	-- (the cats close up), ART_RATIO wide
	local packColumns = if width - SCROLL_BAR >= 2 * PACK_MIN_W + spacing then 2 else 1
	local packW = math.floor((width - SCROLL_BAR - (packColumns - 1) * spacing) / packColumns)
	local artH = math.floor((packW - 2 * PACK_PAD) / ART_RATIO)
	local packH = PACK_PAD
		+ artH
		+ 4
		+ PACK_NAME_H
		+ PACK_LINE_H
		+ 4
		+ self._actionHeight
		+ PACK_PAD
	self._packGrid.CellSize = UDim2.fromOffset(packW, packH)
	for _, entry in self._packCards do
		entry.art.Size = UDim2.new(1, -2 * PACK_PAD, 0, artH)
		local y = PACK_PAD + artH + 4
		entry.name.Position = UDim2.fromOffset(PACK_PAD + 2, y)
		entry.effect.Position = UDim2.fromOffset(PACK_PAD + 2, y + PACK_NAME_H)
	end
	self:_placePackSheet(height)
end

-- #4026: the Sale row's chips, one per card on sale ("Royal Cat R$299"), rebuilt only when the list changes
function Store._fillSale(self: any, list: { StoreLogic.SaleEntry })
	local parts: { string } = {}
	for _, entry in list do
		table.insert(parts, entry.key .. "=" .. entry.robux)
	end
	local key = table.concat(parts, ",")
	self._saleCount = #list
	if key == self._saleKey then
		return
	end
	self._saleKey = key
	for _, child in self._saleRow:GetChildren() do
		if child:IsA("TextLabel") and child.Name ~= "Title" then
			child:Destroy()
		end
	end
	for index, entry in list do
		local chip = text({
			Name = "Sale_" .. entry.key,
			Size = UDim2.fromOffset(0, SALE_ROW_H - 4),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 0,
			BackgroundColor3 = CARD.card,
			TextSize = Theme.sizes.textSmall,
			TextTruncate = Enum.TextTruncate.None,
			RichText = true,
			Text = ("%s  <b>R$%d</b>"):format(entry.name, entry.robux),
			LayoutOrder = index,
			Parent = self._saleRow,
		})
		Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = chip })
		Create("UIStroke", {
			Color = Theme.colors.redDark,
			Thickness = 1.5,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = chip,
		})
		Create(
			"UIPadding",
			{ PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = chip }
		)
	end
end

-- #4026: one outfit pack's card (Store._fillPack fills it), as the approved draft: the art with the gold "Up to +100%
-- money" chip on its top left and the white i on its top right, then the name, one short line and the price button
-- (or "Yours" once owned)
function Store._packCard(self: any, key: string): any
	local card: Frame = Create("Frame", {
		Name = "Pack_" .. key,
		BackgroundColor3 = CARD.goldCard,
		BorderSizePixel = 0,
		Parent = self._packsPage,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = Theme.colors.gold, Thickness = CARD_STROKE }),
	})
	local art: ImageLabel = Create("ImageLabel", {
		Name = "Art",
		Position = UDim2.fromOffset(PACK_PAD, PACK_PAD),
		Size = UDim2.new(1, -2 * PACK_PAD, 0, 100),
		BackgroundColor3 = CARD.card,
		BorderSizePixel = 0,
		ImageRectOffset = ART_RECT_OFFSET,
		ImageRectSize = ART_RECT_SIZE,
		Parent = card,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius - 2) }),
		Create("UIStroke", { Color = Theme.colors.goldDark, Thickness = 2 }),
	})
	-- the white i: a white disc with an ink ring and letter, a thumb's tap on a touch screen
	local infoSize = Scale.tapHeight(PACK_INFO)
	local info: TextButton = Create("TextButton", {
		Name = "Info",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(infoSize, infoSize),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		AutoButtonColor = true,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextColor3 = INK,
		Text = "i",
		ZIndex = 3,
		Parent = art,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create(
			"UIStroke",
			{ Color = INK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }
		),
	})
	local perk = text({
		Name = "Perk",
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.fromOffset(0, PERK_H),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.colors.gold,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PERK_BROWN,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		ZIndex = 3,
		Parent = art,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = perk })
	Create("UIStroke", {
		Color = Theme.colors.goldDark,
		Thickness = 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = perk,
	})
	Create(
		"UIPadding",
		{ PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = perk }
	)
	local name = text({
		Name = "Name",
		Size = UDim2.new(1, -2 * PACK_PAD - 4, 0, PACK_NAME_H),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 4,
		Parent = card,
	})
	MenuFamily.outline(name)
	local effect = text({
		Name = "Effect",
		Size = UDim2.new(1, -2 * PACK_PAD - 4, 0, PACK_LINE_H),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = CARD.subtext,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = card,
	})
	local buttonSize = UDim2.new(1, -2 * PACK_PAD, 0, self._actionHeight)
	local buttonPosition = UDim2.new(0.5, 0, 1, -PACK_PAD)
	local owned = text({
		Name = "Owned",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = buttonPosition,
		Size = buttonSize,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextColor3 = CARD.good,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "✓ Yours",
		Visible = false,
		Parent = card,
	})
	MenuFamily.outline(owned)
	local entry: any = {
		frame = card,
		art = art,
		info = info,
		name = name,
		perk = perk,
		effect = effect,
		owned = owned,
		passId = 0,
		rowKey = key,
		key = key,
	}
	entry.button = Button.new({
		name = "Buy",
		text = "...",
		style = "ghost",
		size = buttonSize,
		anchorPoint = Vector2.new(0.5, 1),
		position = buttonPosition,
		textSize = Theme.sizes.textBody,
		enabled = false,
		parent = card,
		onClick = function()
			if entry.passId ~= 0 then
				StoreMotion.press(entry.frame :: any)
				self._callbacks.buy(entry.passId)
			end
		end,
	})
	info.Activated:Connect(function()
		self:_showPack(entry.rowKey)
	end)
	effect:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		fitText(effect, Theme.sizes.textSmall)
	end)
	self._packCards[key] = entry
	self:_layout()
	return entry
end

function Store._fillPack(self: any, entry: any, row: StoreLogic.Row)
	entry.row = row
	entry.passId = row.passId
	entry.name.Text = row.name
	entry.perk.Text = row.perk or ""
	entry.perk.Visible = row.perk ~= nil
	entry.effect.Text = string.match(row.effect, "^[^\n]+") or row.effect
	fitText(entry.effect, Theme.sizes.textSmall)
	local art = ShopIcons.packArt(row.key) or ""
	if entry.art.Image ~= art then
		entry.art.Image = art
	end
	local button = StoreLogic.button(row, self._prices[row.passId])
	entry.button:setText(button.text)
	entry.button:setStyle(button.style :: any)
	entry.button:setEnabled(button.enabled)
	entry.button.instance.Visible = not row.owned
	entry.owned.Visible = row.owned
	if self._packShown == row.key then
		self:_showPack(row.key) -- the open sheet follows a price or Owned change
	end
end

-- #4026: the white i's sheet over the Packs page, as the approved draft: the pack's name and hook with an X, each
-- piece with where it goes and its bonus, the set bonus, the total, and the price button. Plain facts: no timers,
-- no struck-out prices.
function Store._packSheet(self: any, pages: Frame)
	local shade: TextButton = Create("TextButton", {
		Name = "PackInfo",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		ZIndex = 20,
		Parent = pages,
	})
	shade.Activated:Connect(function()
		self:_showPack(nil)
	end)
	local sheet: Frame = Create("Frame", {
		Name = "Sheet",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -2 * CARD_INSET, 1, -2 * CARD_STROKE),
		BackgroundColor3 = CARD.card,
		BorderSizePixel = 0,
		Active = true, -- a tap on the sheet itself stays on it (only the shade round it closes)
		ZIndex = 21,
		Parent = shade,
	}, {
		Create("UISizeConstraint", { MaxSize = Vector2.new(PACK_SHEET_W, math.huge) }),
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = Theme.colors.gold, Thickness = CARD_STROKE }),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, SHEET_PAD),
			PaddingRight = UDim.new(0, SHEET_PAD),
			PaddingTop = UDim.new(0, SHEET_PAD),
			PaddingBottom = UDim.new(0, SHEET_PAD),
		}),
	})
	local closeSize = Scale.tapHeight(PACK_INFO)
	local title = text({
		Name = "Title",
		Size = UDim2.new(1, -(closeSize + 6), 0, SHEET_TITLE_H),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		ZIndex = 22,
		Parent = sheet,
	})
	MenuFamily.outline(title)
	local close = Button.new({
		name = "Close",
		text = "X",
		style = "close",
		size = UDim2.fromOffset(closeSize, closeSize),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.fromScale(1, 0),
		textSize = Theme.sizes.textBody,
		zIndex = 22,
		parent = sheet,
		onClick = function()
			self:_showPack(nil)
		end,
	})
	local hook = text({
		Name = "Hook",
		Position = UDim2.fromOffset(0, SHEET_TITLE_H),
		Size = UDim2.new(1, -(closeSize + 6), 0, SHEET_HOOK_H),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = CARD.subtext,
		ZIndex = 22,
		Parent = sheet,
	})
	FitText.shrink(hook)
	local lines: Frame = Create("Frame", {
		Name = "Lines",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, SHEET_TITLE_H + SHEET_HOOK_H + 4),
		Size = UDim2.new(1, 0, 0, 0),
		ZIndex = 22,
		Parent = sheet,
	}, {
		Create(
			"UIListLayout",
			{ Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }
		),
	})
	local buy = Button.new({
		name = "Buy",
		text = "...",
		style = "ghost",
		size = UDim2.new(1, 0, 0, self._actionHeight),
		anchorPoint = Vector2.new(0.5, 1),
		position = UDim2.fromScale(0.5, 1),
		textSize = Theme.sizes.textBody,
		enabled = false,
		zIndex = 22,
		parent = sheet,
		onClick = function()
			local info = self._packInfo
			if info and info.passId ~= 0 then
				self._callbacks.buy(info.passId)
			end
		end,
	})
	self._packInfo = {
		shade = shade,
		sheet = sheet,
		title = title,
		hook = hook,
		lines = lines,
		close = close,
		buy = buy,
		passId = 0,
		rowH = PACK_LINE_ROW,
	}
end

-- #4026: the sheet's rows fit the page: as tall as PACK_LINE_ROW, shorter on a short page (never under 20), and the
-- hook line goes first when even that does not fit
function Store._placePackSheet(self: any, pageH: number)
	local info = self._packInfo
	if info == nil then
		return
	end
	local count = 6 -- four pieces, the set and the total
	local fixed = 2 * SHEET_PAD + SHEET_TITLE_H + 4 + 6 + self._actionHeight
	local rowH =
		math.floor((pageH - 2 * CARD_STROKE - fixed - SHEET_HOOK_H - (count - 1) * 2) / count)
	local hookShown = rowH >= 22
	if not hookShown then
		rowH = math.floor((pageH - 2 * CARD_STROKE - fixed - (count - 1) * 2) / count)
	end
	rowH = math.clamp(rowH, 20, PACK_LINE_ROW)
	info.rowH = rowH
	info.hook.Visible = hookShown
	info.lines.Position =
		UDim2.fromOffset(0, SHEET_TITLE_H + (if hookShown then SHEET_HOOK_H else 0) + 4)
	info.lines.Size = UDim2.new(1, 0, 0, count * rowH + (count - 1) * 2)
	for _, child in info.lines:GetChildren() do
		if child:IsA("Frame") then
			child.Size = UDim2.new(1, 0, 0, rowH)
		end
	end
end

-- #4026: opens the white i's sheet for a pack card (its Row key, "packWinter"), or closes it (nil)
function Store._showPack(self: any, key: string?)
	local info = self._packInfo
	if info == nil then
		return
	end
	local entry = if key then self._packCards[key] else nil
	local row: StoreLogic.Row? = entry and entry.row
	local pack = if row and row.pack then StoreLogic.PACKS[row.pack] else nil
	info.shade.Visible = pack ~= nil
	self._packShown = if pack then key else nil
	if pack == nil or row == nil or row.pack == nil then
		info.passId = 0
		return
	end
	info.passId = row.passId
	info.title.Text = pack.title
	info.hook.Text = string.match(row.effect, "^[^\n]+") or row.effect
	local button = StoreLogic.button(row, self._prices[row.passId])
	info.buy:setText(if row.owned then "✓ Yours" else button.text)
	info.buy:setStyle(if row.owned then "ghost" else button.style :: any)
	info.buy:setEnabled(button.enabled and not row.owned)
	for _, child in info.lines:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local list = StoreLogic.packLines(row.pack)
	for index, line in list do
		local last = index == #list
		local rowFrame: Frame = Create("Frame", {
			Name = "Line" .. index,
			BackgroundTransparency = 0,
			BackgroundColor3 = if last then CARD.goldCard else Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, info.rowH),
			LayoutOrder = index,
			ZIndex = 22,
			Parent = info.lines,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, 6) }),
			Create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
		})
		local left = text({
			Name = "Piece",
			Size = UDim2.new(0.68, 0, 1, 0),
			FontFace = if last then Theme.fonts.display else Theme.fonts.body,
			TextSize = Theme.sizes.textSmall + (if last then 2 else 0),
			Text = line.left,
			ZIndex = 23,
			Parent = rowFrame,
		})
		FitText.shrink(left)
		local right = text({
			Name = "Bonus",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0.32, 0, 1, 0),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textSmall + (if last then 2 else 0),
			TextColor3 = CARD.good,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = line.right,
			ZIndex = 23,
			Parent = rowFrame,
		})
		FitText.shrink(right)
	end
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
	if was ~= self._tab then
		self:_layout() -- a one-card tab takes the whole width
	end
	for id, button in self._railButtons do
		button:setStyle(if id == self._tab then "gold" else "ghost")
	end
	if self._rework then
		-- #3572: the tab's header line
		self._panel:setTitle("Store", StoreLogic.subtitle(self._tab))
	end
	-- #1823 §4: opening a tab clears its New dot, and the server saves it once
	if self._new[self._tab] then
		self._new[self._tab] = nil
		self._marked[self._tab] = true
		self._newDots[self._tab].Visible = false
		local onSeen: ((string) -> ())? = self._callbacks.seen
		if onSeen then
			onSeen(self._tab)
		end
	end
	local onShown: ((string) -> ())? = self._callbacks.tabShown
	if onShown then
		onShown(self._tab)
	end
	local featured = self._tab == "featured"
	local codes = self._tab == "codes"
	local packs = self._tab == "packs"
	self._featured.Visible = featured
	self._list.Visible = not featured and not codes and not packs
	self._packsPage.Visible = packs
	if not packs then
		self:_showPack(nil)
	end
	self:_placeBag()
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
		self._packsPage.CanvasPosition = Vector2.zero
	end
end

-- #1823 §4: the tabs with a New dot (StoreLogic.newTabs). A tab already sent as seen stays clear while the server's
-- save is on its way back, and is forgotten once the server's word says it is seen.
function Store.setNew(self: any, tabs: { [string]: true })
	for id in self._marked do
		if not tabs[id] then
			self._marked[id] = nil
		end
	end
	local new: { [string]: true } = {}
	for id in tabs do
		if not self._marked[id] then
			new[id] = true
		end
	end
	self._new = new
	for id, dot in self._newDots do
		dot.Visible = new[id] == true
	end
end

-- Whether any tab's New dot shows, for the HUD's Store tile.
function Store.hasNew(self: any): boolean
	return next(self._new) ~= nil
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
	self._fresh = true
	self:_showPack(nil)
end

function Store.render(self: any, rows: { StoreLogic.Row }, prices: { [number]: StoreLogic.Price })
	self._rows = rows
	self._prices = prices
	-- #1823 §4: the passes owned, so a bundle's worth counts only the parts still to buy
	local ownedIds: { [number]: boolean } = {}
	for _, row in rows do
		if row.owned then
			ownedIds[row.passId] = true
		end
	end
	self._ownedIds = ownedIds
	-- the rail: Featured and each tab with a card
	local visibleTabs: { [string]: boolean } = {}
	for _, tab in StoreLogic.tabs(rows) do
		visibleTabs[tab.id] = true
	end
	for id, button in self._railButtons do
		button.instance.Visible = visibleTabs[id] == true
	end
	-- Featured
	local featured = StoreLogic.featured(rows, prices) -- #3562: off sale cards never lead
	local hero = self._cards.hero or self:_makeCard("hero", "hero", self._featured, 0)
	-- #3996 (todays-deal-3996.md section 4): while Today's Deal shows it is the hero, since a pick on a phone has room
	-- for one line and the deal's lines (the token deal's odds above all) must be on the card itself. The usual hero
	-- leads the picks and the last pick waits for tomorrow. Once bought it needs only its name and "Bought today", so
	-- it steps down to the first pick and the hero is the usual one again.
	local deal = DealLogic.card(self._deal, os.time(), MysticPoolLogic.oddsLine())
	local picks: { StoreLogic.Row } = featured.picks
	local dealPick = deal ~= nil and deal.bought
	if deal ~= nil and not deal.bought then
		self:_fillDeal(hero, deal)
		picks = {}
		if featured.hero then
			table.insert(picks, featured.hero)
		end
		for _, pick in featured.picks do
			if #picks < StoreLogic.PICKS then
				table.insert(picks, pick)
			end
		end
	else
		self:_fill(hero, featured.hero)
	end
	for index = 1, StoreLogic.PICKS do
		local slot = "pick" .. index
		local entry = self._cards[slot] or self:_makeCard(slot, "tile", self._picks, index)
		if dealPick and index == 1 then
			self:_fillDeal(entry, deal)
		else
			self:_fill(entry, picks[if dealPick then index - 1 else index])
		end
	end
	self._picks.Visible = #picks > 0
	local onFeatured: { [string]: boolean } = {}
	if featured.hero then
		onFeatured[featured.hero.key] = true
	end
	for _, pick in picks do
		onFeatured[pick.key] = true
	end
	self:_fillSale(StoreLogic.saleList(rows, prices, Config, os.time(), SALE_MOST, onFeatured))
	self._empty.Visible = #rows == 0
	-- the grid: a card per row, kept for the next render
	local shown: { [string]: boolean } = {}
	-- #3572: with the rework on, each tab cheapest first (StoreLogic.cheapestFirst); the cards are ordered, not moved
	local gridRows: { StoreLogic.Row } = if self._rework
		then StoreLogic.cheapestFirst(rows, prices)
		else rows
	local packOrder = 0
	for _, row in rows do
		if row.pack ~= nil then
			packOrder += 1
			local entry = self._packCards[row.key] or self:_packCard(row.key)
			entry.frame.LayoutOrder = packOrder
			self:_fillPack(entry, row)
			shown["pack:" .. row.key] = true
		end
	end
	for key, entry in self._packCards do
		entry.frame.Visible = shown["pack:" .. key] == true
	end
	for order, row in gridRows do
		if row.pack ~= nil then
			continue -- #4026: the Packs tab draws its own cards
		end
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
	self:_thank(rows)
end

-- #1823: a pass the server has just confirmed (Roblox's ownership answer, never the prompt) gets VFX's thank-you
-- burst on its card while the window is open; StoreBurst skips a card that is off screen.
function Store._thank(self: any, rows: { StoreLogic.Row })
	local bought, seen = StoreLogic.justBought(self._seen, rows)
	self._seen = seen
	local fresh = self._fresh
	self._fresh = false
	if fresh or #bought == 0 or not self.frame.Visible then
		return
	end
	for _, key in bought do
		for _, entry in self._cards do
			if entry.rowKey == key and entry.frame.Visible then
				StoreMotion.bought(entry.frame) -- Animation's pop and flash (#1840) under VFX's burst
				StoreBurst.play(entry.frame, "pass")
			end
		end
	end
end

function Store.destroy(self: any)
	self._sizeChanged:Disconnect()
	for _, entry in self._cards do
		entry.button:destroy()
	end
	for _, button in self._railButtons do
		button:destroy()
	end
	for _, entry in self._packCards do
		entry.button:destroy()
	end
	if self._packInfo then
		self._packInfo.close:destroy()
		self._packInfo.buy:destroy()
	end
	self._panel:destroy()
end

return Store
