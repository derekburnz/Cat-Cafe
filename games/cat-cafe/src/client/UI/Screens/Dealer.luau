--!strict
-- Night dealer screen (F32, data-model section 8b), in the Grow a Garden seed shop style: "Fresh stock in
-- 4:12" across the top, then each dealer food with this window's stock and one green price button. F59:
-- every food shows, "x2 Stock" while some are left for you, "Sold out" once you bought them all and "None this time"
-- for an amount of 0; the amounts are the same on every server (Components/DealerRows). #1612 (Derek2 11-05: "no
-- need to show odds of everything everywhere"): a row is the picture with its grade badge and border (F69), the name
-- and the stock; Details opens the five-rarity odds (each rarity in its colour), the food's line, the gold chance,
-- the chance of each stock amount and the per-cat split (the growth thread's rules for random items). F82: the odds and the
-- split are the player's bowl level's (shared Bait, as the server rolls). What is for sale comes
-- only from UI.dealer.setStock (the DealerStock remote); the screen never guesses stock, and the server recomputes
-- it on every BuyDealerFood.
-- F94 (rewards-and-shops.md section 4): one stock per server per night, so the strip counts down to sunrise, when
-- the cart leaves, instead of a 5 minute restock (UIController hands the night as the window and sunrise as
-- restocksAt). F94 is live, so the pre-F94 5 minute wording and Config.DealerWindowSeconds are gone.
-- Opened by the cart's prompt (UI.dealer.open).
-- #2573 (player riverpopcorn886's idea, via Derek2): "Buy all" on the strip's right while something left fits. It opens
-- a confirm card with what it takes (DealerRows.buyAll: shared Dealer.planAll, best grade first, what fits), the total
-- and the coins left after, and "You can afford 6 of 10" when it can't take everything. Buy sends
-- callbacks.buyAll(window) (BuyDealerAll); the server plans again from its own stock and coins, toasts and sends
-- DealerStock, which ends the wait.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local DayKinds = require(script.Parent.Parent.Components.DayKinds)
local DealerRows = require(script.Parent.Parent.Components.DealerRows)
local FoodGrade = require(script.Parent.Parent.Components.FoodGrade)
local FoodOdds = require(script.Parent.Parent.Components.FoodOdds)
local Format = require(script.Parent.Parent.Components.Format)
local IndexRewards = require(script.Parent.Parent.Components.IndexRewards)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local LuckLogic = require(script.Parent.Parent.Components.LuckLogic)
local MarketLogic = require(script.Parent.Parent.Components.MarketLogic)
local MenuFamily = require(script.Parent.Parent.Components.MenuFamily)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local PotionLogic = require(script.Parent.Parent.Components.PotionLogic)
local Scale = require(script.Parent.Parent.Scale)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

-- the dark window palette (#1028), in place of Theme.modal
local PAL = MenuFamily.pal
local CARD = MenuFamily.card -- #3558: what sits on a picture card (cream in the family look)

export type Callbacks = {
	-- the food's row, the food and the window the screen showed, so a Buy that lands after a restock is refused (S42)
	buy: (index: number, lureId: string, window: number?) -> (),
	close: () -> (),
	buyAll: ((window: number?) -> ())?, -- #2573: Buy all, with the window (night) the screen showed
}

export type Dealer = {
	frame: Frame,
	setCatalog: (self: Dealer, catalog: Types.Catalog) -> (),
	render: (self: Dealer, state: Types.PlayerState) -> (),
	setStock: (self: Dealer, stock: Types.DealerStock?) -> (), -- either shape (Components/DealerRows.normalize)
	-- true at night, false by day (the cart has gone), nil when the clock is unknown
	setNight: (self: Dealer, night: boolean?) -> (),
	-- true at the cart, false away from it, nil when the cart part is unknown (the server decides)
	setNear: (self: Dealer, near: boolean?) -> (),
	destroy: (self: Dealer) -> (),
}

local STRIP_HEIGHT = 84
local ROW_HEIGHT = 108 -- #1612: the picture and its margins; the odds moved into Details
local ICON = 84
local BUTTON = Vector2.new(128, Theme.sizes.touchMin + 4)
local DETAILS_H = 42 -- a 37 px face with a mouse; Scale.tapHeight makes Buy and Details 44 px faces on a phone
local TEXT_LEFT = ICON + 28
local TEXT_RIGHT = BUTTON.X + 28
-- a Buy waits this long after it is sent for the next DealerStock before the button comes back (#2290: was 5 s)
local PENDING_SECONDS = 2
-- #2290 (Derek2: "buying items fast from shop sometimes stays too long on the ... waiting button"): the server takes
-- BuyDealerFood 2 a second and drops the rest with no DealerStock, so buys go at least this far apart
local SEND_GAP = 0.55
-- #2573: Buy all waits this long for its DealerStock (the server takes BuyDealerAll once every 2 s)
local ALL_PENDING_SECONDS = 3
local ALL_BUTTON = Vector2.new(124, 44)
-- #3961: the family look's picture cards (batch 2 mock): three across, the food's picture on top, its name, a
-- rarity chip, the stock line and the price; the odds open over the card from the small ? in its corner. Buy all
-- stays on the strip's right (the mock centres it under the cards, but a phone held sideways has no room for it)
local CARD_ICON = 64
local CARD_HINT = 32
local FAMILY_STRIP = 60 -- a slimmer strip, so a phone held sideways shows the whole card

local Dealer = {}
Dealer.__index = Dealer

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

-- a rarity's odds colour as hex, for FoodOdds.rich
local function rarityHex(rarity: string): string
	return MenuFamily.rarity(rarity):ToHex() -- light odds on the dark cards (#1028)
end

-- words that go in the rich text Details next to the coloured odds
local function plain(value: string): string
	return (value:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

function Dealer.new(callbacks: Callbacks): Dealer
	local self = setmetatable({}, Dealer) :: any
	self._callbacks = callbacks
	self._rows = {} :: { any }
	self._lureById = {} :: { [string]: Types.LureDef }
	self._catalog = nil :: Types.Catalog?
	self._state = nil :: Types.PlayerState?
	self._stock = nil :: Types.DealerStock?
	self._night = nil :: boolean?
	self._near = nil :: boolean?
	self._pending = {} :: { [string]: number } -- lureId -> os.clock() when the wait for DealerStock ends
	self._lastSent = nil :: number? -- #2290: os.clock() of the last BuyDealerFood sent (or set to go)
	self._tier = 0
	self._bowlLevel = 0 -- lure_bowl (F82): the odds rows are this level's
	self._luck = 1 -- F88: the player's Luck, in the odds rows and the split
	self._extras = "" -- the gold and charm line the Details were written with
	self._accumulator = 0
	self._allUntil = 0 -- #2573: os.clock() when Buy all's wait for DealerStock ends
	self._alive = true -- #3646: false once destroyed, for the Buy all's own repaint
	self._plan = nil :: DealerRows.BuyAll?

	local panel = Panel.new({
		dark = true, -- #1028
		name = "Dealer",
		color = Theme.colors.berry,
		icon = Theme.icons.moon,
		image = ShopIcons.hud("NightMarket"), -- #2836: the drawn badge (the emoji until it loads)
		title = "Night dealer",
		subtitle = "Rare foods for your bait bowl, sold only at night",
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = Vector2.new(720, 560), Parent = panel.frame })
	self._panel = panel
	self.frame = panel.frame

	-- Restock strip: the moon, "Fresh stock in 4:12" and a line on what to do
	local strip: Frame = Create("Frame", {
		Name = "Restock",
		BackgroundColor3 = if MenuFamily.on() then PAL.card else Theme.colors.cocoaDeep,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -10, 0, if MenuFamily.on() then FAMILY_STRIP else STRIP_HEIGHT),
		Parent = panel.content,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	Outline.border(strip, Theme.sizes.outline)
	local moon: TextLabel = text({
		Name = "Moon",
		BackgroundColor3 = Theme.colors.skyDark,
		BackgroundTransparency = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(60, 60),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 32,
		Text = Theme.icons.moon,
		Parent = strip,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = moon })
	Outline.border(moon, 2)
	local family = MenuFamily.on()
	self._family = family
	if family then
		moon.Size = UDim2.fromOffset(44, 44)
		moon.TextSize = 24
	end
	local textLeft = if family then 66 else 86
	self._stripTitle = text({
		Name = "Title",
		Position = UDim2.fromOffset(textLeft, if family then 6 else 12),
		Size = UDim2.new(1, -(textLeft + 14 + ALL_BUTTON.X), 0, 28),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextColor3 = Theme.colors.white,
		Parent = strip,
	})
	Outline.text(self._stripTitle, 2)
	self._stripSub = text({
		Name = "Sub",
		Position = UDim2.fromOffset(textLeft, if family then 34 else 42),
		Size = UDim2.new(1, -(textLeft + 14 + ALL_BUTTON.X), 0, if family then 20 else 34),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.hud.subtext,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = strip,
	})

	-- #2573: Buy all, on the strip's right
	self._allButton = Button.new({
		name = "BuyAll",
		text = if family then "BUY ALL" else "Buy all",
		style = "gold",
		size = UDim2.fromOffset(
			ALL_BUTTON.X,
			Scale.tapHeight(ALL_BUTTON.Y, Theme.sizes.buttonDepth)
		),
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, -12, 0.5, 0),
		textSize = Theme.sizes.textBody,
		parent = strip,
		onClick = function()
			self:_openConfirm()
		end,
	})
	self._allButton.instance.Visible = false
	self:_buildConfirm(panel.frame)

	local listTop = (if family then FAMILY_STRIP else STRIP_HEIGHT) + Theme.sizes.gap + 4
	local layout: Instance = if family
		then Create("UIGridLayout", {
			CellSize = UDim2.new(1 / 3, -Theme.sizes.gap, 0, self:_cardHeight()),
			CellPadding = UDim2.fromOffset(Theme.sizes.gap, Theme.sizes.gap),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
		else Create("UIListLayout", {
			Padding = UDim.new(0, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
	self._list = Create("ScrollingFrame", {
		Name = "Foods",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, listTop),
		Size = UDim2.new(1, 0, 1, -listTop),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = PAL.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel.content,
	}, {
		layout,
		Outline.listPadding(10, 6), -- #2294: room for the cards' outlines
	})
	-- before the first DealerStock arrives, or when every food in it is unknown (#3961: over the grid, not a cell of it)
	self._empty = text({
		Name = "Empty",
		Position = if family then UDim2.fromOffset(0, listTop + 10) else UDim2.new(),
		Size = UDim2.new(1, 0, 0, 60),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = PAL.subtext,
		TextWrapped = true,
		Text = "",
		Visible = false,
		Parent = if family then panel.content else self._list,
	})

	-- the countdown ticks once a second while the screen is open
	self._tick = RunService.Heartbeat:Connect(function(dt: number)
		if not self.frame.Visible then
			return
		end
		self._accumulator += dt
		if self._accumulator >= 1 then
			self._accumulator = 0
			self:_renderAll()
		end
	end)
	return self :: Dealer
end

function Dealer._clearRows(self: any)
	for _, row in self._rows do
		row.buy:destroy()
		row.details:destroy()
		row.icon:destroy()
		row.frame:Destroy()
	end
	table.clear(self._rows)
end

-- #3961: a picture card's height: its picture, name, chip and stock line, then the price button
function Dealer._cardHeight(_self: any): number
	return 8 + CARD_ICON + 70 + Scale.tapHeight(BUTTON.Y, Theme.sizes.buttonDepth) + 8
end

function Dealer._buildRows(self: any)
	self:_clearRows()
	local stock: Types.DealerStock? = self._stock
	if not stock then
		return
	end
	assert(stock, "stock")
	if self._family then
		for index, group in DealerRows.group(stock, self._lureById) do
			self:_buildCard(index, group)
		end
		self._tier = -1
		self._extras = ""
		return
	end
	-- on a phone Buy and Details grow to a 44 px face and the row with them
	local buyH = Scale.tapHeight(BUTTON.Y, Theme.sizes.buttonDepth)
	local detailsH = Scale.tapHeight(DETAILS_H, Theme.sizes.buttonDepth)
	local topHeight = math.max(ROW_HEIGHT, 12 + buyH + 10 + detailsH + 12)
	for index, group in DealerRows.group(stock, self._lureById) do
		local def = group.def
		local row: Frame = Create("Frame", {
			Name = group.lureId,
			BackgroundColor3 = CARD.card,
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = index,
			Parent = self._list,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
			-- rarity colours on borders (world-and-feel section 6 style rules): the food's grade (F69)
			Create(
				"UIStroke",
				{ Color = Theme.rarityColor(FoodGrade.of(def)), Thickness = Theme.sizes.stroke + 1 }
			),
			Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		local top: Frame = Create("Frame", {
			Name = "Top",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, topHeight),
			LayoutOrder = 1,
			Parent = row,
		})
		local icon = ItemIcon.new({
			parent = top,
			size = UDim2.fromOffset(ICON, ICON),
			position = UDim2.fromOffset(12, 12),
		})
		icon:setFood(def)
		local heading: Frame = Create("Frame", {
			Name = "Heading",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(TEXT_LEFT, 10),
			Size = UDim2.new(1, -(TEXT_LEFT + TEXT_RIGHT), 0, 26),
			Parent = top,
		}, {
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		text({
			Name = "Name",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 26),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textLarge - 2,
			Text = def.name,
			LayoutOrder = 1,
			Parent = heading,
		})
		local stockLine: Frame = Create("Frame", {
			Name = "StockLine",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(TEXT_LEFT, 38),
			Size = UDim2.new(1, -(TEXT_LEFT + TEXT_RIGHT), 0, 20),
			Parent = top,
		}, {
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		local stockText = text({
			Name = "Stock",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 20),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textSmall + 1,
			LayoutOrder = 1,
			Parent = stockLine,
		})
		local have = text({
			Name = "Have",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 20),
			TextSize = Theme.sizes.textSmall,
			TextColor3 = CARD.subtext,
			LayoutOrder = 2,
			Parent = stockLine,
		})
		local lureId = group.lureId
		local buy = Button.new({
			name = "Buy",
			text = Format.money(group.cost),
			style = "primary",
			size = UDim2.fromOffset(BUTTON.X, buyH),
			anchorPoint = Vector2.new(1, 0),
			position = UDim2.new(1, -12, 0, 12),
			textSize = Theme.sizes.textBody + 2,
			parent = top,
			onClick = function()
				self:_buy(lureId)
			end,
		})
		local details = Button.new({
			name = "Details",
			text = "Details",
			style = "ghost",
			size = UDim2.fromOffset(BUTTON.X, detailsH),
			anchorPoint = Vector2.new(1, 0),
			position = UDim2.new(1, -12, 0, 12 + buyH + 10),
			textSize = Theme.sizes.textSmall,
			parent = top,
			onClick = function()
				self:_toggleDetail(lureId)
			end,
		})
		local detail = text({
			Name = "Detail",
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			TextSize = Theme.sizes.textTiny,
			TextColor3 = CARD.subtext,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			TextYAlignment = Enum.TextYAlignment.Top,
			RichText = true, -- #1612: the odds in their colours lead Details
			Visible = false,
			LayoutOrder = 2,
			Parent = row,
		})
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 16),
			PaddingBottom = UDim.new(0, 12),
			Parent = detail,
		})
		table.insert(self._rows, {
			frame = row,
			icon = icon,
			stock = stockText,
			have = have,
			buy = buy,
			details = details,
			detail = detail,
			odds = FoodOdds.rich(def.odds, rarityHex), -- #1612: Details' first line, rich text
			split = nil :: string?, -- the per-cat split for the tier and bowl last drawn
			group = group,
		})
	end
	self._tier = -1 -- rebuild the odds and split text on the next render
	self._extras = ""
end

-- #3961: one picture card of the family look, with the same fields as a row so _renderAll paints both
function Dealer._buildCard(self: any, index: number, group: DealerRows.Row)
	local def = group.def
	local grade = FoodGrade.of(def)
	local buyH = Scale.tapHeight(BUTTON.Y, Theme.sizes.buttonDepth)
	local hintH = CARD_HINT -- a corner button; the card's whole face is not a tap target
	local card: Frame = Create("Frame", {
		Name = group.lureId,
		BackgroundColor3 = CARD.card,
		BorderSizePixel = 0,
		LayoutOrder = index,
		Parent = self._list,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create(
			"UIStroke",
			{ Color = Theme.rarityColor(grade), Thickness = Theme.sizes.stroke + 1 }
		),
	})
	local icon = ItemIcon.new({
		parent = card,
		size = UDim2.fromOffset(CARD_ICON, CARD_ICON),
		position = UDim2.new(0.5, -CARD_ICON / 2, 0, 8),
		badge = "none", -- the chip under the name says the grade
	})
	icon:setFood(def)
	local y = 8 + CARD_ICON + 2
	local name = text({
		Name = "Name",
		Position = UDim2.fromOffset(6, y),
		Size = UDim2.new(1, -12, 0, 24),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge - 4,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = def.name,
		Parent = card,
	})
	MenuFamily.outline(name, 2)
	local chipColor = Theme.rarityColor(grade)
	local chip: TextLabel = text({
		Name = "Rarity",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, y + 24),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		BackgroundTransparency = 0,
		BackgroundColor3 = chipColor,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textTiny + 1,
		TextColor3 = Theme.rarityTextColor(grade),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = FoodGrade.badge(grade),
		Parent = card,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = chip })
	Create(
		"UIPadding",
		{ PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = chip }
	)
	local stockLine: Frame = Create("Frame", {
		Name = "StockLine",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(4, y + 48),
		Size = UDim2.new(1, -8, 0, 18),
		Parent = card,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local stockText = text({
		Name = "Stock",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 18),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		LayoutOrder = 1,
		Parent = stockLine,
	})
	local have = text({
		Name = "Have",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 18),
		TextSize = Theme.sizes.textTiny,
		TextColor3 = CARD.subtext,
		LayoutOrder = 2,
		Parent = stockLine,
	})
	local lureId = group.lureId
	local buy = Button.new({
		name = "Buy",
		text = Format.money(group.cost),
		style = "primary",
		size = UDim2.new(1, -20, 0, buyH),
		anchorPoint = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -8),
		textSize = Theme.sizes.textBody + 2,
		parent = card,
		onClick = function()
			self:_buy(lureId)
		end,
	})
	-- the odds over the card's top, under its ? (the price stays in sight)
	local cover: ScrollingFrame = Create("ScrollingFrame", {
		Name = "DetailCover",
		BackgroundColor3 = CARD.card,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -(buyH + 12)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = PAL.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = false,
		ZIndex = 5,
		Parent = card,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	local detail = text({
		Name = "Detail",
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -(hintH + 8), 0, 0),
		TextSize = Theme.sizes.textTiny,
		TextColor3 = CARD.subtext,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextYAlignment = Enum.TextYAlignment.Top,
		RichText = true,
		ZIndex = 5,
		Parent = cover,
	})
	Create("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		Parent = detail,
	})
	local details = Button.new({
		name = "Details",
		text = "?",
		style = "ghost",
		size = UDim2.fromOffset(hintH, hintH),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, -6, 0, 6),
		textSize = Theme.sizes.textSmall,
		zIndex = 6,
		parent = card,
		onClick = function()
			self:_toggleDetail(lureId)
		end,
	})
	table.insert(self._rows, {
		frame = card,
		icon = icon,
		stock = stockText,
		have = have,
		buy = buy,
		details = details,
		detail = detail,
		cover = cover,
		odds = FoodOdds.rich(def.odds, rarityHex),
		split = nil :: string?,
		group = group,
	})
end

function Dealer._toggleDetail(self: any, lureId: string)
	for _, row in self._rows do
		if row.group.lureId == lureId then
			-- #3961: a card's odds open over it, and its ? turns into an X
			local shown = row.cover or row.detail
			shown.Visible = not shown.Visible
			if row.cover then
				row.details:setText(if shown.Visible then "X" else "?")
			else
				row.details:setText(if shown.Visible then "Hide details" else "Details")
			end
		end
	end
end

-- Buy sends the food and the window it was shown in, then waits for the server's next DealerStock.
function Dealer._buy(self: any, lureId: string)
	local stock: Types.DealerStock? = self._stock
	for index, row in self._rows do
		local group: DealerRows.Row = row.group
		if group.lureId == lureId and self:_canBuy(group) then
			-- #2290: a press inside SEND_GAP of the last buy goes a moment later instead of being dropped
			local now = os.clock()
			local at = MarketLogic.sendAt(self._lastSent, now, SEND_GAP)
			self._lastSent = at
			self._pending[lureId] = at + PENDING_SECONDS
			local window = if stock then stock.window else nil
			local function send()
				self._callbacks.buy(index, lureId, window)
			end
			if at <= now then
				send()
			else
				task.delay(at - now, send)
			end
			self:_renderAll()
			return
		end
	end
end

-- #2573: the confirm card over the window: what Buy all takes, the total and the coins after, Cancel and Buy.
function Dealer._buildConfirm(self: any, parent: Instance)
	local cover: TextButton = Create("TextButton", {
		Name = "BuyAllCover",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 20,
		Parent = parent,
	})
	local card: Frame = Create("Frame", {
		Name = "Card",
		BackgroundColor3 = CARD.card,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -40, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 21,
		Parent = cover,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UISizeConstraint", { MaxSize = Vector2.new(440, math.huge) }),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 16),
			PaddingTop = UDim.new(0, 14),
			PaddingBottom = UDim.new(0, 14),
		}),
		Create("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	})
	Outline.border(card, Theme.sizes.outline)
	local function line(name: string, order: number, props: { [string]: any }): TextLabel
		local label = text({
			Name = name,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = order,
			ZIndex = 22,
			Parent = card,
		})
		for key, value in props do
			(label :: any)[key] = value
		end
		return label
	end
	local title = line("Title", 1, {
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextColor3 = Theme.colors.white,
		Text = "Buy all?",
	})
	Outline.text(title, 2)
	local list = line("List", 2, { TextColor3 = CARD.text })
	local sums = line("Sums", 3, { FontFace = Theme.fonts.display, TextColor3 = Theme.colors.gold })
	local partial =
		line("Partial", 4, { TextSize = Theme.sizes.textSmall, TextColor3 = CARD.subtext })
	local height = Scale.tapHeight(ALL_BUTTON.Y, Theme.sizes.buttonDepth)
	local buttons: Frame = Create("Frame", {
		Name = "Buttons",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height),
		LayoutOrder = 5,
		ZIndex = 22,
		Parent = card,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	Button.new({
		name = "Cancel",
		text = "Cancel",
		style = "ghost",
		size = UDim2.fromOffset(ALL_BUTTON.X, height),
		textSize = Theme.sizes.textBody,
		layoutOrder = 1,
		zIndex = 23,
		parent = buttons,
		onClick = function()
			self:_closeConfirm()
		end,
	})
	Button.new({
		name = "Buy",
		text = "Buy",
		style = "gold",
		size = UDim2.fromOffset(ALL_BUTTON.X, height),
		textSize = Theme.sizes.textBody,
		layoutOrder = 2,
		zIndex = 23,
		parent = buttons,
		onClick = function()
			self:_confirmBuyAll()
		end,
	})
	self._confirm = { cover = cover, list = list, sums = sums, partial = partial }
end

-- #2573: Buy all pressed: the card with tonight's plan, or nothing when nothing fits any more.
function Dealer._openConfirm(self: any)
	local plan: DealerRows.BuyAll? = self._plan
	if plan == nil or self:_closedReason() ~= nil or os.clock() < self._allUntil then
		return
	end
	self:_fillConfirm(plan)
	self._confirm.cover.Visible = true
end

-- the card's lines from the plan (again on each render while it is up, as coins tick)
function Dealer._fillConfirm(self: any, plan: DealerRows.BuyAll)
	local confirm = self._confirm
	confirm.list.Text = plan.list
	confirm.sums.Text = ("Total %s · %s left after"):format(
		Format.money(plan.total),
		Format.money(plan.after)
	)
	confirm.partial.Text = plan.partial or ""
	confirm.partial.Visible = plan.partial ~= nil
end

function Dealer._closeConfirm(self: any)
	self._confirm.cover.Visible = false
end

-- #2573: Buy on the card: one BuyDealerAll for the night shown; the next DealerStock ends the wait.
function Dealer._confirmBuyAll(self: any)
	self:_closeConfirm()
	local send: ((number?) -> ())? = self._callbacks.buyAll
	local stock: Types.DealerStock? = self._stock
	if send == nil or self._plan == nil or self:_closedReason() ~= nil then
		return
	end
	self._allUntil = os.clock() + ALL_PENDING_SECONDS
	send(if stock then stock.window else nil)
	self:_renderAll()
	-- #3646: an unanswered Buy all leaves "Buying..." after ALL_PENDING_SECONDS on its own, as the Day Cart's does
	-- (#3340), not only at the next render
	task.delay(ALL_PENDING_SECONDS + 0.1, function()
		if self._alive then
			self:_renderAll()
		end
	end)
end

-- Why buying is closed for every row right now, or nil when it is open.
function Dealer._closedReason(self: any): string?
	local stock: Types.DealerStock? = self._stock
	if self._night == false then
		return "day"
	elseif stock == nil then
		return "loading"
	elseif (stock :: Types.DealerStock).restocksAt - Workspace:GetServerTimeNow() <= 0 then
		return "restocking"
	elseif self._near == false then
		return "away"
	end
	return nil
end

function Dealer._canBuy(self: any, group: DealerRows.Row): boolean
	local state: Types.PlayerState? = self._state
	if self:_closedReason() ~= nil or state == nil then
		return false
	end
	local pendingUntil: number? = self._pending[group.lureId]
	if pendingUntil and os.clock() < pendingUntil then
		return false
	end
	return group.left > 0 and (state :: Types.PlayerState).money >= group.cost
end

function Dealer.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	table.clear(self._lureById)
	for _, def in catalog.lures do
		self._lureById[def.id] = def
	end
	self:_buildRows()
	self:_renderAll()
end

function Dealer.setStock(self: any, stock: Types.DealerStock?)
	self._stock = DealerRows.normalize(stock)
	table.clear(self._pending) -- the server answered: its stock is the truth now
	self._allUntil = 0 -- #2573: and Buy all's wait
	self:_buildRows()
	self:_renderAll()
end

function Dealer.setNight(self: any, night: boolean?)
	if self._night == night then
		return
	end
	self._night = night
	self:_renderAll()
end

function Dealer.setNear(self: any, near: boolean?)
	if self._near == near then
		return
	end
	self._near = near
	self:_renderAll()
end

function Dealer.render(self: any, state: Types.PlayerState)
	self._state = state
	if not self.frame.Visible then
		return -- money ticks re-render every screen; this one catches up when it opens
	end
	self:_renderAll()
end

function Dealer._renderAll(self: any)
	self:_renderStrip()
	local state: Types.PlayerState? = self._state
	if not state then
		return
	end
	assert(state, "state")
	local catalog: Types.Catalog? = self._catalog
	-- the odds row and the split are the bowl level's (F82) at the player's Luck (F88), the split the tier's areas too
	local bowlLevel: number = state.upgradeLevels.lure_bowl or 0
	local playerLuck = LuckLogic.current(state, Workspace:GetServerTimeNow())
	local oddsChanged = catalog ~= nil
		and (state.tier ~= self._tier or bowlLevel ~= self._bowlLevel or playerLuck ~= self._luck)
	if catalog and oddsChanged then
		self._tier = state.tier
		self._bowlLevel = bowlLevel
		self._luck = playerLuck
		for _, row in self._rows do
			local def: Types.LureDef = row.group.def
			row.odds = FoodOdds.rich(FoodOdds.atBowl(def.odds, bowlLevel, playerLuck), rarityHex)
			row.split = FoodOdds.split(catalog, def, state.tier, bowlLevel, playerLuck)
		end
	end
	-- Details: the food's line, the gold chance with the Index's gold luck (F54) and the running potions (F73) in
	-- it, the chance of each stock amount (F59) and the split
	local luck = if catalog then IndexRewards.totals(catalog, state).goldLuck else 0
	local boosts = PotionLogic.boosts(catalog, state, Workspace:GetServerTimeNow())
	-- #1572: a Golden Day's x2 and a Rainbow Day's x3, as at the bowl
	local extras = FoodOdds.extras(luck, boosts.goldLuck, boosts.goldScale, DayKinds.current.golden)
	local rainbow = FoodOdds.rainbow(state.rainbowLuck, nil, DayKinds.current.rainbow) -- F99
	if rainbow then
		extras ..= "\n" .. rainbow
	end
	if oddsChanged or extras ~= self._extras then
		self._extras = extras
		local amounts = if catalog then catalog.dealerAmountWeights else nil
		for _, row in self._rows do
			local def: Types.LureDef = row.group.def
			local lines = { def.description, extras }
			local stockOdds = DealerRows.amountOdds(if amounts then amounts[def.id] else nil)
			if stockOdds then
				table.insert(lines, stockOdds)
			end
			table.insert(lines, row.split or "")
			row.detail.Text = row.odds .. "\n" .. plain(table.concat(lines, "\n"))
		end
	end
	for _, row in self._rows do
		local group: DealerRows.Row = row.group
		local left = group.left
		local none = group.amount == 0
		local pendingUntil: number? = self._pending[group.lureId]
		local pending = pendingUntil ~= nil and os.clock() < pendingUntil
		row.stock.Text = if none
			then "None this time"
			elseif left > 0 then ("x%d Stock"):format(left)
			else "Sold out"
		row.stock.TextColor3 = if none
			then CARD.subtext
			elseif left > 0 then Theme.colors.good
			else Theme.colors.red
		local have = state.lures[group.lureId] or 0
		row.have.Text = if have > 0
			then (if row.cover then "Have %d" else "You have %d"):format(have)
			else ""
		row.buy:setText(
			if pending
				then "Buying..."
				elseif none then "None"
				elseif left == 0 then "Sold out"
				else Format.money(group.cost)
		)
		row.buy:setEnabled(self:_canBuy(group))
	end
	-- #2573: Buy all while the cart is open and something left fits; "Buying..." while its answer is on the way
	local allPending = os.clock() < self._allUntil
	self._plan = if self:_closedReason() == nil and self._callbacks.buyAll ~= nil
		then DealerRows.buyAll(self._stock, self._lureById, state.money)
		else nil
	self._allButton.instance.Visible = self._plan ~= nil or allPending
	self._allButton:setText(
		if allPending then "Buying..." elseif self._family then "BUY ALL" else "Buy all"
	)
	self._allButton:setEnabled(self._plan ~= nil and not allPending)
	if self._plan == nil then
		self:_closeConfirm()
	elseif self._confirm.cover.Visible then
		self:_fillConfirm(self._plan)
	end
	local stock: Types.DealerStock? = self._stock
	self._empty.Visible = #self._rows == 0
	self._empty.Text = if stock == nil
		then "The dealer is unpacking his cart..."
		else "Nothing left on the cart tonight. He brings new stock tomorrow night."
end

-- The strip's states: closed by day, unpacking, restocking, away from the cart, and open with the countdown.
function Dealer._renderStrip(self: any)
	local stock: Types.DealerStock? = self._stock
	local reason = self:_closedReason()
	local title: string
	local sub: string
	if reason == "day" then
		title = "Closed until nightfall"
		sub = "The dealer packs up his cart at dawn and comes back when night falls."
	elseif reason == "loading" or stock == nil then
		title = "Opening the cart..."
		sub = "His stock shows in a moment."
	elseif reason == "restocking" then
		title = "Packing up..."
		sub = "The dealer leaves at sunrise."
	else
		-- No stock counts or restock clocks in shop windows (#1190, the friend 11-04); the server's stock rules are unchanged.
		title = "Here until sunrise"
		sub = if reason == "away"
			then "Walk back to the cart to buy."
			else "Dealer food goes in your bait bowl."
	end
	self._stripTitle.Text = title
	self._stripSub.Text = sub
end

function Dealer.destroy(self: any)
	self._alive = false
	self._tick:Disconnect()
	self:_clearRows()
	self._panel:destroy()
end

return Dealer
