--!strict
-- The Corner Shop window (#1052, corner-shop.md section 4), opened from the stall's CornerShopPrompt in the Town
-- Square (UI.cornerShop.open). Coins only, open day and night. The items under a header
-- per kind ("Potions", "Cat food", "Bait", #1599), each a compact row in Catalog.cornerShop order: its picture, name,
-- what it does, "Opens at Tier 3" on a row the player's tier doesn't reach yet, else what is left this restock
-- ("x2 left", #1456; still no chances, restock clock or daily limits: #1190), and a green Buy with the coin price
-- ("Sold out", "Out of stock", "Back tomorrow" past a daily limit, #1435, "Food full"). Food goes to the Bag
-- (corner-shop-v2.md). Bait food rows (#1281) show the food's picture and grade and "You have n". No help line or
-- lawn note since #1688 and #1689: the prices and clock say it. No toasts of its own: the server's answer is a fresh CornerShopStock and,
-- when refused, its toast. Words and rules in Components/CornerShopLogic.
-- #2593 (Derek2: a Buy all for the potion, cat food and bait sections): a "Buy all" on each of those headers while
-- something in it can be bought. It opens Components/BuyAllCard with the plan (CornerShopLogic.buyAll, the shared
-- planAll the server runs), the total and the coins after; Buy sends callbacks.buyAll(kind, window) and the header
-- reads "Buying..." until the next CornerShopStock.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local BuyAllCard = require(script.Parent.Parent.Components.BuyAllCard)
local CornerShopLogic = require(script.Parent.Parent.Components.CornerShopLogic)
local Create = require(script.Parent.Parent.Components.Create)
local FitText = require(script.Parent.Parent.Components.FitText)
local GridFit = require(script.Parent.Parent.Components.GridFit)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local MenuFamily = require(script.Parent.Parent.Components.MenuFamily)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local Scale = require(script.Parent.Parent.Scale)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog")) :: any
local SharedTypes = require(Shared:WaitForChild("Types"))

-- the dark window palette (#1028)
local PAL = MenuFamily.pal
local CARD = MenuFamily.card -- #3558: what sits on a picture card (cream in the family look)

export type Callbacks = {
	buy: (itemId: string, window: number, shownPrice: number, catUid: string?) -> (),
	close: () -> (),
	far: (() -> boolean)?, -- true once the player has walked away from the stall: the window closes
	buyAll: ((kind: string, window: number) -> ())?, -- #2593: Buy all on a section, for the window shown
}

export type CornerShop = {
	frame: Frame,
	setStock: (self: CornerShop, stock: SharedTypes.CornerShopStock?) -> (),
	render: (self: CornerShop, state: Types.PlayerState) -> (),
	opened: (self: CornerShop) -> (),
	closed: (self: CornerShop) -> (),
	destroy: (self: CornerShop) -> (),
}

type Row = {
	itemId: string,
	frame: Frame,
	icon: ItemIcon.ItemIcon,
	effect: TextLabel,
	line: TextLabel,
	buy: Button.Button,
}

local MAX_SIZE = Vector2.new(620, 460)
-- #1599 (Derek2 11-05: "smaller boxes/text per item so its easiest to see a lot"): compact rows, the name and "x2
-- left" on one line, what it does under it; the Buy keeps a 44 px face on a phone (Scale.tapHeight)
local ROW_MIN_H = 50
local ROW_GAP = 4
local SECTION_H = 28
local PICTURE = 40
local BUY_W = 124
local STOCK_W = 110
local PENDING_SECONDS = 3 -- a sent buy with no answer stops counting on its row after this long (#1384)
-- The server takes BuyCornerShop 2 a second and drops the rest with no answer (Net.luau), which left a fast buyer's
-- button on "..." (#1384). Buys are spaced this far apart; presses inside the gap queue up and go in order.
-- #1820 (Derek2: "stuck in ... for like a second"): no "..." any more. A press counts on its row at once, as if the
-- server said yes ("x1 left" -> "Sold out"), and the next CornerShopStock puts right anything it refused.
local SEND_GAP = 0.55
-- #3209: the tabs over the list, one per section, in this order
local TAB_H = 36
-- #3350 (Derek2: "add symbols to them so its easier"): each with the Bag's own tab picture, the glyph until it loads
local TABS: { { kind: string, title: string, icon: string, image: string? } } = {
	{
		kind = "potion",
		title = "Potions",
		icon = Theme.icons.potion,
		image = ShopIcons.hud("Potion"),
	},
	{
		kind = "food",
		title = "Cat food",
		icon = ShopIcons.SNACK_GLYPH,
		image = ShopIcons.market("Treats"),
	},
	{ kind = "bait", title = "Bait", icon = Theme.icons.food, image = ShopIcons.hud("Bowl") },
}
local GAP = Theme.sizes.gap
-- #2593: the sections with a Buy all, the header button's width, and how long Buy all waits for its CornerShopStock
local ALL_KINDS: { [string]: boolean } = { potion = true, food = true, bait = true }
local ALL_W = 110
-- #3961: the family look's picture cards (batch 1 mock), three across under each section's header
local CARD_PICTURE = 46 -- #4007: a little smaller, four cards a row
local EFFECT_H = 42 -- #4007: three short lines on the narrower card
local MIN_CELL = 128 -- #4007: the narrowest card that still fits its name and Buy
local ALL_PENDING_SECONDS = 3

local CornerShop = {}
CornerShop.__index = CornerShop

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

local function rowOf(itemId: string): SharedTypes.CornerShopRow?
	return Catalog.cornerShopById[itemId]
end

function CornerShop.new(callbacks: Callbacks): CornerShop
	local self = setmetatable({}, CornerShop) :: any
	self._callbacks = callbacks
	self._stock = nil :: SharedTypes.CornerShopStock?
	self._state = nil :: Types.PlayerState?
	self._rows = {} :: { Row }
	self._queue = {} :: { { itemId: string, catUid: string? } } -- buys pressed and not sent yet, oldest first
	self._sent = {} :: { { itemId: string, at: number } } -- buys sent with no CornerShopStock answer yet
	self._lastSent = -math.huge -- os.clock() of the last buy sent
	self._pumping = false -- a task sends the queue SEND_GAP apart
	self._alive = true
	self._open = false
	self._tick = 0
	self._buyH = Scale.tapHeight(36, Theme.sizes.buttonDepth)
	self._rowH = math.max(ROW_MIN_H, self._buyH + 10)
	self._headers = {} :: { TextLabel }
	self._allButtons = {} :: { [string]: Button.Button } -- #2593: section kind -> its Buy all
	self._allTitles = {} :: { [string]: string }
	self._allUntil = {} :: { [string]: number } -- kind -> os.clock() its Buy all's wait ends
	self._plans = {} :: { [string]: CornerShopLogic.BuyAll }
	self._cardKind = nil :: string?
	self._allH = Scale.tapHeight(36, Theme.sizes.buttonDepth)
	self._family = MenuFamily.on()
	self._grids = {} :: { [string]: Frame } -- #3961: section kind -> its grid of cards

	local panel = Panel.new({
		dark = true,
		name = "CornerShop",
		title = CornerShopLogic.TITLE, -- "Day Cart" (#1577, day-cart.md: only the shown name changes)
		subtitle = "Coins only",
		color = Theme.colors.caramel,
		icon = "🏪",
		image = ShopIcons.hud("CornerShop"), -- #2836: the drawn badge (the emoji until it loads)
		size = UDim2.fromScale(1, 1), -- the modal's area, so a phone keeps it clear of Roblox's top bar
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = MAX_SIZE, Parent = panel.frame })
	self._panel = panel
	self.frame = panel.frame
	local content = panel.content

	-- the restock clock and the snack line
	self._clock = text({
		Name = "Clock",
		Size = UDim2.new(0.55, 0, 0, 26),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		Parent = content,
	})
	Outline.text(self._clock, 2)
	self._snack = text({
		Name = "Snacks",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 4),
		Size = UDim2.new(0.45, 0, 0, 20),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = content,
	})

	-- #3209 (Derek2: "add different section buttons at top of day cart for potions/cat food/bait"): one tab per
	-- section over the list; the list shows that section's header (with its Buy all) and rows only
	local tabH = Scale.tapHeight(TAB_H, Theme.sizes.buttonDepth)
	local tabBar: Frame = Create("Frame", {
		Name = "Tabs",
		BackgroundColor3 = PAL.panel,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, tabH),
		ZIndex = 2,
		Parent = content,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._tab = TABS[1].kind
	self._tabButtons = {} :: { [string]: Button.Button }
	for order, tab in TABS do
		self._tabButtons[tab.kind] = Button.new({
			name = tab.kind .. "Tab",
			text = tab.title,
			icon = tab.icon,
			image = tab.image,
			style = if order == 1 then "gold" else "ghost",
			size = UDim2.new(1 / #TABS, -GAP, 1, 0),
			textSize = Theme.sizes.textBody,
			layoutOrder = order,
			parent = tabBar,
			sound = "uiTab",
			onClick = function()
				self:_showTab(tab.kind)
			end,
		})
	end

	self._list = Create("ScrollingFrame", {
		Name = "Items",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		-- the whole window under the tabs (#3209) since the help line (#1688) and lawn note (#1689) went; the
		-- restock clock and snack line behind the tabs are empty since #1190 and #1255
		Position = UDim2.fromOffset(0, tabH + GAP),
		Size = UDim2.new(1, 0, 1, -(tabH + GAP)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = PAL.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = content,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, ROW_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Outline.listPadding(10, Theme.sizes.buttonDepth + 2), -- #2294: room for the rows' outlines
	})
	self._empty = text({
		Name = "Empty",
		Size = UDim2.new(1, 0, 0, 60),
		TextColor3 = PAL.subtext,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "The shop is opening…",
		Parent = self._list,
	})

	self:_buildPicker(content)
	self._card = BuyAllCard.new(panel.frame, function()
		self:_confirmAll()
	end)
	return self :: CornerShop
end

-- The snack's cat picker over the list: "Who gets the snack?", the cats highest level first, and Back.
function CornerShop._buildPicker(self: any, content: Frame)
	local picker: Frame = Create("Frame", {
		Name = "Picker",
		Active = true,
		BackgroundColor3 = PAL.panel,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 10,
		Visible = false,
		Parent = content,
	})
	self._picker = picker
	self._pickerTitle = text({
		Name = "Title",
		Size = UDim2.new(1, -110, 0, 30),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		ZIndex = 11,
		Parent = picker,
	})
	Outline.text(self._pickerTitle, 2)
	self._pickerBack = Button.new({
		name = "Back",
		text = "Back",
		style = "ghost",
		size = UDim2.fromOffset(100, self._buyH),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, 0, 0, 0),
		zIndex = 11,
		parent = picker,
		onClick = function()
			picker.Visible = false
		end,
	})
	self._pickerList = Create("ScrollingFrame", {
		Name = "Cats",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, self._buyH + GAP),
		Size = UDim2.new(1, 0, 1, -(self._buyH + GAP)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = PAL.caramel,
		ZIndex = 11,
		Parent = picker,
	}, {
		Create("UIGridLayout", {
			CellSize = UDim2.new(0.5, -6, 0, self._buyH),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Outline.listPadding(10, Theme.sizes.buttonDepth + 2), -- #2294: room for the rows' outlines
	})
	self._pickerButtons = {} :: { Button.Button }
end

function CornerShop._clearPicker(self: any)
	for _, button in self._pickerButtons do
		button:destroy()
	end
	table.clear(self._pickerButtons)
end

-- Opens the picker for a snack: a press on a cat buys the snack for it.
function CornerShop._pickCat(
	self: any,
	item: SharedTypes.CornerShopItem,
	row: SharedTypes.CornerShopRow
)
	local state: Types.PlayerState? = self._state
	self:_clearPicker()
	self._pickerTitle.Text = ("Who gets the %s?"):format(row.name)
	local names: { [string]: string } = {}
	for _, def in Catalog.cats or {} do
		names[def.id] = def.name
	end
	local cats = CornerShopLogic.catsByLevel(if state then state.cats :: any else nil, names)
	for order, cat in cats do
		local button = Button.new({
			name = cat.uid,
			text = ("%s · Lv %d"):format(cat.name or cat.catId, cat.level),
			style = "secondary",
			size = UDim2.fromScale(1, 1),
			textSize = Theme.sizes.textBody,
			layoutOrder = order,
			zIndex = 12,
			parent = self._pickerList,
			onClick = function()
				self._picker.Visible = false
				self:_send(item, cat.uid)
			end,
		})
		table.insert(self._pickerButtons, button)
	end
	self._picker.Visible = true
end

-- The stock row for `itemId`, or nil.
function CornerShop._item(self: any, itemId: string): SharedTypes.CornerShopItem?
	local stock: SharedTypes.CornerShopStock? = self._stock
	if stock == nil then
		return nil
	end
	for _, each in stock.stock do
		if each.itemId == itemId then
			return each
		end
	end
	return nil
end

-- How many buys of `itemId` are pressed but not answered yet: queued, or sent within PENDING_SECONDS.
function CornerShop._extra(self: any, itemId: string): number
	local count = 0
	for _, each in self._queue do
		if each.itemId == itemId then
			count += 1
		end
	end
	local now = os.clock()
	for _, sent in self._sent do
		if sent.itemId == itemId and now - sent.at < PENDING_SECONDS then
			count += 1
		end
	end
	return count
end

-- The row as it will be once every unanswered buy goes through (#1820).
local function withExtra(
	item: SharedTypes.CornerShopItem,
	extra: number
): SharedTypes.CornerShopItem
	if extra <= 0 then
		return item
	end
	local shown = table.clone(item :: any)
	shown.bought = (item.bought or 0) + extra
	return shown :: any
end

-- Sends one buy now, from the stock as it is now (a new window may have come while it waited).
function CornerShop._fire(self: any, itemId: string, catUid: string?)
	local stock: SharedTypes.CornerShopStock? = self._stock
	local item = self:_item(itemId)
	if stock == nil or item == nil then
		self:_paint() -- gone from the shop while it waited
		return
	end
	local now = os.clock()
	self._lastSent = now
	table.insert(self._sent, { itemId = itemId, at = now })
	self._callbacks.buy(itemId, stock.window, (item :: SharedTypes.CornerShopItem).price, catUid)
	-- an unanswered buy stops counting on its row after PENDING_SECONDS, even with the window's repaint stopped
	task.delay(PENDING_SECONDS + 0.1, function()
		if self._alive then
			self:_paint()
		end
	end)
end

-- Sends the queue in order, SEND_GAP apart, so the server's 2 a second never drops a press.
function CornerShop._pump(self: any)
	if self._pumping then
		return
	end
	self._pumping = true
	task.spawn(function()
		while self._alive and #self._queue > 0 do
			local wait = self._lastSent + SEND_GAP - os.clock()
			if wait > 0 then
				task.wait(wait)
			end
			if not self._alive then
				break
			end
			local entry = table.remove(self._queue, 1) :: { itemId: string, catUid: string? }?
			if entry then
				self:_fire(entry.itemId, entry.catUid)
			end
		end
		self._pumping = false
	end)
end

function CornerShop._press(self: any, itemId: string)
	local item = self:_item(itemId)
	if item == nil then
		return
	end
	-- the row as it will be after the buys already pressed: a press past the stock or the money does nothing
	local view = self:_view(item :: SharedTypes.CornerShopItem)
	if not view.enabled then
		return
	end
	-- Corner Shop v2 (#1181): food goes to the Bag, so no row opens the cat picker on buy
	self:_send(item :: SharedTypes.CornerShopItem, nil)
end

-- Queues one buy (for `catUid` when the picker chose a cat); it counts on its row at once.
function CornerShop._send(self: any, item: SharedTypes.CornerShopItem, catUid: string?)
	table.insert(self._queue, { itemId = item.itemId, catUid = catUid })
	self:_paint()
	self:_pump()
end

-- What spending the unanswered buys leaves of the player's money, so a press they can no longer afford greys out.
function CornerShop._coins(self: any): number
	local state: Types.PlayerState? = self._state
	local coins = if state then state.money else 0
	local stock: SharedTypes.CornerShopStock? = self._stock
	if stock == nil then
		return coins
	end
	for _, item in stock.stock do
		coins -= item.price * self:_extra(item.itemId)
	end
	return coins
end

-- A row's button as it will be once every unanswered buy goes through.
function CornerShop._view(self: any, item: SharedTypes.CornerShopItem): CornerShopLogic.ButtonView
	local stock: SharedTypes.CornerShopStock? = self._stock
	local state: Types.PlayerState? = self._state
	local room = if stock then CornerShopLogic.snackRoom(stock.snackXp) else math.huge
	local tier = if state then state.tier else 1
	return CornerShopLogic.button(
		withExtra(item, self:_extra(item.itemId)),
		rowOf(item.itemId),
		self:_coins(),
		room,
		tier
	)
end

function CornerShop._clear(self: any)
	for _, row: Row in self._rows do
		row.icon:destroy()
		row.buy:destroy()
		row.frame:Destroy()
	end
	table.clear(self._rows)
	for _, button in self._allButtons do
		button:destroy()
	end
	table.clear(self._allButtons)
	for _, header in self._headers do
		header:Destroy()
	end
	table.clear(self._headers)
	for _, grid in self._grids do
		grid:Destroy()
	end
	table.clear(self._grids)
end

-- #3209: shows one section: its tab gold, its header and rows in the list, the list back at the top.
function CornerShop._showTab(self: any, kind: string)
	self._tab = kind
	for each, button in self._tabButtons do
		button:setStyle(if each == kind then "gold" else "ghost")
	end
	for _, child in self._list:GetChildren() do
		if child:IsA("GuiObject") and child ~= self._empty then
			local name = child.Name
			local of: string? = if name:sub(1, 8) == "Section_"
				then name:sub(9)
				else (rowOf(name) or {} :: any).kind
			if of ~= nil then
				child.Visible = of == kind
			end
		end
	end
	-- #3961: the family look's grids and the cards in them
	for gridKind, grid in self._grids do
		grid.Visible = gridKind == kind
	end
	if self._family then
		for _, row: Row in self._rows do
			local def = rowOf(row.itemId)
			row.frame.Visible = (if def ~= nil then def.kind else "other") == kind
		end
	end
	self._list.CanvasPosition = Vector2.zero
end

-- #3961: a section's grid of picture cards, under its header
function CornerShop._grid(self: any, kind: string, order: number): Frame
	local layout: UIGridLayout = Create("UIGridLayout", {
		CellSize = GridFit.cell(GridFit.FEWEST, GAP, self:_cardHeight()),
		CellPadding = UDim2.fromOffset(GAP, GAP),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local grid: Frame = Create("Frame", {
		Name = "Grid_" .. kind,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		Visible = kind == self._tab,
		LayoutOrder = order,
		Parent = self._list,
	}, { layout })
	-- #4007: four a row where they fit, else three
	GridFit.fit(grid, layout, MIN_CELL, GAP, function(): number
		return self:_cardHeight()
	end)
	self._grids[kind] = grid
	return grid
end

function CornerShop._cardHeight(self: any): number
	return 8 + CARD_PICTURE + 4 + 20 + EFFECT_H + 4 + self._buyH + 8
end

-- #1599: a section's header over its rows ("Potions").
function CornerShop._header(self: any, section: CornerShopLogic.Section, order: number)
	local hasAll = ALL_KINDS[section.kind] == true and self._callbacks.buyAll ~= nil
	local header = text({
		Name = "Section_" .. section.kind,
		Visible = section.kind == self._tab, -- #3209
		Size = UDim2.new(
			1,
			0,
			0,
			if hasAll then math.max(SECTION_H, self._allH + 4) else SECTION_H
		),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		TextColor3 = PAL.caramel,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Text = section.title,
		LayoutOrder = order,
		Parent = self._list,
	})
	Outline.text(header, 1.5)
	table.insert(self._headers, header)
	if hasAll then
		-- #2593: the section's Buy all on the header's right
		local kind = section.kind
		local button = Button.new({
			name = "BuyAll",
			text = "Buy all",
			style = "gold",
			size = UDim2.fromOffset(ALL_W, self._allH),
			anchorPoint = Vector2.new(1, 0.5),
			position = UDim2.new(1, -8, 0.5, 0),
			textSize = Theme.sizes.textSmall,
			parent = header,
			onClick = function()
				self:_openAll(kind)
			end,
		})
		button.instance.Visible = false
		self._allButtons[kind] = button
		self._allTitles[kind] = section.title
	end
end

-- #2593: the stock as it will be once every unanswered single buy goes through, for Buy all's plan.
function CornerShop._shownStock(self: any): SharedTypes.CornerShopStock?
	local stock: SharedTypes.CornerShopStock? = self._stock
	if stock == nil then
		return nil
	end
	local items: { SharedTypes.CornerShopItem } = {}
	for _, item in stock.stock do
		table.insert(items, withExtra(item, self:_extra(item.itemId)))
	end
	return {
		window = stock.window,
		restocksAt = stock.restocksAt,
		stock = items,
		snackXp = stock.snackXp,
	}
end

-- #2593: each section's Buy all: shown while its plan buys something (or its answer is on the way), "Buying..." while
-- it waits, and the card's words kept up to date while it is up.
function CornerShop._paintAll(self: any)
	local state: Types.PlayerState? = self._state
	local shown = self:_shownStock()
	local coins = self:_coins()
	local held = {
		catFood = if state and state.catFood then state.catFood else {},
		lures = if state then state.lures else {},
	}
	local now = os.clock()
	for kind, button in self._allButtons do
		local plan = if state
			then CornerShopLogic.buyAll(shown, kind, state.tier, coins, held :: any)
			else nil
		self._plans[kind] = plan
		local pending = (self._allUntil[kind] or 0) > now
		button.instance.Visible = plan ~= nil or pending
		button:setText(if pending then "Buying..." else "Buy all")
		button:setEnabled(plan ~= nil and not pending)
	end
	local kind: string? = self._cardKind
	if self._card:visible() and kind ~= nil then
		local plan = self._plans[kind]
		if plan == nil then
			self._card:hide()
		else
			self:_showCard(kind, plan)
		end
	end
end

function CornerShop._showCard(self: any, kind: string, plan: CornerShopLogic.BuyAll)
	local money = CornerShopLogic.money
	self._card:show(
		("Buy all %s?"):format(string.lower(self._allTitles[kind] or "")),
		plan.list,
		("Total %s · %s left after"):format(money(plan.total), money(plan.after)),
		plan.partial
	)
end

-- #2593: Buy all pressed: the card with the section's plan.
function CornerShop._openAll(self: any, kind: string)
	local plan = self._plans[kind]
	if plan == nil or (self._allUntil[kind] or 0) > os.clock() then
		return
	end
	self._cardKind = kind
	self:_showCard(kind, plan)
end

-- #2593: Buy on the card: one BuyCornerShopAll for the section and the window shown.
function CornerShop._confirmAll(self: any)
	local kind: string? = self._cardKind
	local stock: SharedTypes.CornerShopStock? = self._stock
	local send = (self._callbacks :: Callbacks).buyAll
	if kind == nil or stock == nil or send == nil or self._plans[kind] == nil then
		return
	end
	self._allUntil[kind] = os.clock() + ALL_PENDING_SECONDS
	send(kind, stock.window)
	self:_paint()
	-- #3340 (Derek2: "sometimes the buy all gets stuck on ..."): an unanswered Buy all (a dropped send) leaves
	-- "Buying..." after ALL_PENDING_SECONDS on its own, not only on the open window's next tick
	task.delay(ALL_PENDING_SECONDS + 0.1, function()
		if self._alive then
			self:_paint()
		end
	end)
end

-- The rows under their section headers (#1599), each section in the stock's order; rebuilt only when the items
-- change. self._rows stays in the stock's order, so _paint matches it to stock.stock by index.
function CornerShop._build(self: any, stock: SharedTypes.CornerShopStock)
	self:_clear()
	local orderOf: { [number]: number } = {}
	local order = 0
	for _, section in CornerShopLogic.sections(stock.stock) do
		order += 1
		self:_header(section, order)
		if self._family then
			order += 1
			self:_grid(section.kind, order)
		end
		for _, index in section.indexes do
			order += 1
			orderOf[index] = order
		end
	end
	local rowH = self._rowH
	for index, item in stock.stock do
		local itemId = item.itemId
		local def = rowOf(itemId)
		local kind: string = if def ~= nil then def.kind else "other"
		local grid: Frame? = self._grids[kind]
		if grid ~= nil then
			self:_pictureCard(grid, index, orderOf[index] or index, item, def, kind)
			continue
		end
		local frame: Frame = Create("Frame", {
			Name = itemId,
			BackgroundColor3 = CARD.card,
			BorderSizePixel = 0,
			Visible = kind == self._tab, -- #3209: only the open tab's rows
			LayoutOrder = orderOf[index] or index,
			Size = UDim2.new(1, 0, 0, rowH),
			Parent = self._list,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }),
			Create("UIStroke", { Color = CARD.cardStroke, Thickness = Theme.sizes.stroke }),
		})
		local bait = def ~= nil and def.kind == "bait"
		local icon = ItemIcon.new({
			parent = frame,
			size = UDim2.fromOffset(PICTURE, PICTURE),
			anchorPoint = Vector2.new(0, 0.5),
			position = UDim2.new(0, 8, 0.5, 0),
			badge = if bait then "gem" else nil,
		})
		local potion = def and def.kind == "potion"
		if potion and def then
			icon:setPotion(def.potionId, "Epic")
		elseif bait and def then
			-- #1281 (corner-shop-v2.md section 1b, #1261): the bowl food's clean picture and its grade badge
			local lureId = def.lureId or itemId
			icon:setFood(Catalog.getLure(lureId), lureId)
		else
			-- #1616: a cat food's glyph, the same as in the Bag
			local food = if def and def.kind == "food" then def.foodId or itemId else nil
			icon:set(
				nil,
				if food then ShopIcons.snackGlyph(food) else Theme.icons.potion,
				"Rare",
				nil
			)
		end
		-- the name with "x2 left" at its end, and what it does under them, centred on the row
		local left = 8 + PICTURE + 10
		local right = BUY_W + 16
		local name = text({
			Name = "Name",
			Position = UDim2.new(0, left, 0.5, -19),
			Size = UDim2.new(1, -(left + right + STOCK_W), 0, 20),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody + 1,
			TextColor3 = CARD.text,
			Text = if def then def.name else itemId,
			Parent = frame,
		})
		MenuFamily.outline(name, 1.5)
		local line = text({
			Name = "Line",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -right, 0.5, -18),
			Size = UDim2.fromOffset(STOCK_W, 18),
			FontFace = Theme.fonts.bodyBold,
			TextSize = Theme.sizes.textTiny + 1,
			TextColor3 = CARD.subtext,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = frame,
		})
		local effect = text({
			Name = "Effect",
			Position = UDim2.new(0, left, 0.5, 3),
			Size = UDim2.new(1, -(left + right), 0, 16),
			TextSize = Theme.sizes.textTiny + 1,
			TextColor3 = CARD.subtext,
			Text = if def then CornerShopLogic.effect(def) else "",
			Parent = frame,
		})
		local buy = Button.new({
			name = "Buy",
			text = "Buy",
			style = "primary",
			size = UDim2.fromOffset(BUY_W, self._buyH),
			anchorPoint = Vector2.new(1, 0.5),
			position = UDim2.new(1, -8, 0.5, 0),
			textSize = Theme.sizes.textSmall,
			parent = frame,
			onClick = function()
				self:_press(itemId)
			end,
		})
		table.insert(
			self._rows,
			{ itemId = itemId, frame = frame, icon = icon, effect = effect, line = line, buy = buy }
		)
	end
end

-- #3961: one picture card of the family look: the picture on top, the name, what it does, "x2 left" and Buy, with the
-- same fields as a row so _paint fills both
function CornerShop._pictureCard(
	self: any,
	grid: Frame,
	_index: number,
	order: number,
	item: SharedTypes.CornerShopItem,
	def: SharedTypes.CornerShopRow?,
	kind: string
)
	local itemId = item.itemId
	local frame: Frame = Create("Frame", {
		Name = itemId,
		BackgroundColor3 = CARD.card,
		BorderSizePixel = 0,
		Visible = kind == self._tab,
		LayoutOrder = order,
		Parent = grid,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = CARD.cardStroke, Thickness = Theme.sizes.stroke }),
	})
	local bait = def ~= nil and def.kind == "bait"
	local icon = ItemIcon.new({
		parent = frame,
		size = UDim2.fromOffset(CARD_PICTURE, CARD_PICTURE),
		position = UDim2.new(0.5, -CARD_PICTURE / 2, 0, 8),
		badge = if bait then "gem" else nil,
	})
	if def and def.kind == "potion" then
		icon:setPotion(def.potionId, "Epic")
	elseif bait and def then
		local lureId = def.lureId or itemId
		icon:setFood(Catalog.getLure(lureId), lureId)
	else
		local food = if def and def.kind == "food" then def.foodId or itemId else nil
		icon:set(nil, if food then ShopIcons.snackGlyph(food) else Theme.icons.potion, "Rare", nil)
	end
	local y = 8 + CARD_PICTURE + 4
	local name = text({
		Name = "Name",
		Position = UDim2.fromOffset(6, y),
		Size = UDim2.new(1, -12, 0, 20),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 1,
		TextColor3 = CARD.text,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = if def then def.name else itemId,
		Parent = frame,
	})
	FitText.shrink(name) -- #4007: a long name on a narrow card shrinks a little instead of cutting off
	MenuFamily.outline(name, 1.5)
	local effect = text({
		Name = "Effect",
		Position = UDim2.fromOffset(6, y + 20),
		Size = UDim2.new(1, -12, 0, EFFECT_H),
		TextSize = Theme.sizes.textTiny,
		TextColor3 = CARD.subtext,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Text = if def then CornerShopLogic.effect(def) else "",
		Parent = frame,
	})
	-- "x2 left" (or the tier gate) as a chip in the card's top right corner
	local line = text({
		Name = "Line",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.new(0.5, -10, 0, 18),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textTiny,
		TextColor3 = CARD.subtext,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = frame,
	})
	local buy = Button.new({
		name = "Buy",
		text = "Buy",
		style = "primary",
		size = UDim2.new(1, -16, 0, self._buyH),
		anchorPoint = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -8),
		textSize = Theme.sizes.textSmall,
		parent = frame,
		onClick = function()
			self:_press(itemId)
		end,
	})
	table.insert(
		self._rows,
		{ itemId = itemId, frame = frame, icon = icon, effect = effect, line = line, buy = buy }
	)
end

function CornerShop._paint(self: any)
	local stock: SharedTypes.CornerShopStock? = self._stock
	self._empty.Visible = stock == nil
	if stock == nil then
		self._clock.Text = ""
		self._snack.Text = ""
		return
	end
	-- No stock counts or restock clocks in shop windows (#1190, the friend 11-04); the server's stock rules are unchanged.
	self._clock.Text = ""
	self._snack.Text = CornerShopLogic.snackLine(stock.snackXp)
	local state: Types.PlayerState? = self._state
	local coins = self:_coins() -- #1820: less what the unanswered buys will spend
	local room = CornerShopLogic.snackRoom(stock.snackXp)
	for index, item in stock.stock do
		local row: Row? = self._rows[index]
		if row == nil then
			continue
		end
		local def = rowOf(item.itemId)
		if def and def.kind == "bait" then
			-- #1281: how many of this food the player has, so they know when to stock up
			local lures = if state then state.lures else nil
			local lureId = def.lureId or item.itemId
			row.effect.Text = CornerShopLogic.effect(def, if lures then lures[lureId] or 0 else 0)
		end
		local tier = if state then state.tier else 1
		local gate = CornerShopLogic.gate(item, tier)
		-- the tier gate, else what is left this restock ("x2 left", #1456, the friend 11-05: "show amount in stock");
		-- still no chances or daily limits in the window (#1190): a family past its limit shows no count, only "Back at sunrise" (#1671)
		local shown = withExtra(item, self:_extra(item.itemId))
		row.line.Text = gate or CornerShopLogic.stockLine(shown)
		local view = CornerShopLogic.button(shown, def, coins, room, tier)
		row.buy:setText(view.text)
		row.buy:setEnabled(view.enabled)
	end
	self:_paintAll()
end

-- CornerShopStock: on join, every 5 minute window and after every buy (bought or refused); it ends every wait.
function CornerShop.setStock(self: any, stock: SharedTypes.CornerShopStock?)
	local old: SharedTypes.CornerShopStock? = self._stock
	self._stock = stock
	table.clear(self._allUntil) -- #2593: the answer to a Buy all, if one was waiting
	-- this answers the oldest buy sent (bought or refused); a window's own stock may answer none, so old sends
	-- also stop counting after PENDING_SECONDS (_extra)
	table.remove(self._sent, 1)
	local same = old ~= nil and stock ~= nil and #old.stock == #stock.stock
	if same and old and stock then
		for index, item in stock.stock do
			if old.stock[index].itemId ~= item.itemId then
				same = false
			end
		end
	end
	if stock and not same then
		self:_build(stock)
	elseif stock == nil then
		self:_clear()
	end
	self:_paint()
end

function CornerShop.render(self: any, state: Types.PlayerState)
	self._state = state
	self:_paint()
end

-- While open the clock moves once a second, and walking away closes the window.
function CornerShop.opened(self: any)
	self._open = true
	self._tick += 1
	local tick = self._tick
	self._picker.Visible = false
	self:_paint()
	task.spawn(function()
		while self._open and self._tick == tick do
			task.wait(1)
			if self._open and self._tick == tick then
				local far = (self._callbacks :: Callbacks).far
				if far ~= nil and far() then
					self._callbacks.close()
					return
				end
				-- #3340: one bad paint must not stop the clock (it is what ends a Buy all's "Buying...")
				local ok, err = pcall(self._paint, self)
				if not ok then
					warn("[CornerShop] a repaint failed: " .. tostring(err))
				end
			end
		end
	end)
end

function CornerShop.closed(self: any)
	self._open = false
	self._tick += 1
	self._picker.Visible = false
	self._card:hide()
end

function CornerShop.destroy(self: any)
	self._open = false
	self._alive = false
	self:_clear()
	self:_clearPicker()
	self._card:destroy()
	self._pickerBack:destroy()
	for _, button in self._tabButtons do
		button:destroy()
	end
	self._panel:destroy()
end

return CornerShop
