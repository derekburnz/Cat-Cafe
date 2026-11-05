--!strict
-- The Corner Shop window (#1052, corner-shop.md section 4), opened from the stall's CornerShopPrompt in the Town
-- Square (UI.cornerShop.open). Coins only, open day and night. On top the help line; then the items under a header
-- per kind ("Potions", "Cat food", "Bait", #1599), each a compact row in Catalog.cornerShop order: its picture, name,
-- what it does, "Opens at Tier 3" on a row the player's tier doesn't reach yet, else what is left this restock
-- ("x2 left", #1456; still no chances, restock clock or daily limits: #1190), and a green Buy with the coin price
-- ("Sold out", "None", "Back tomorrow" past a daily limit, #1435, "Food full"). Food goes to the Bag
-- (corner-shop-v2.md). Bait food rows (#1281) show the food's picture and grade and "You have n". Under the list:
-- "Lawn pieces are in Decor, Front lawn". No toasts of its own: the server's answer is a fresh CornerShopStock and,
-- when refused, its toast. Words and rules in Components/CornerShopLogic.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local CornerShopLogic = require(script.Parent.Parent.Components.CornerShopLogic)
local Create = require(script.Parent.Parent.Components.Create)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
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
local PAL = Theme.dark

export type Callbacks = {
	buy: (itemId: string, window: number, shownPrice: number, catUid: string?) -> (),
	close: () -> (),
	far: (() -> boolean)?, -- true once the player has walked away from the stall: the window closes
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
local TOP_H = 20 -- the help line (#1577); the restock clock and snack line are empty since #1190 and #1255
local NOTE_H = 22
-- #1599 (Derek2 11-05: "smaller boxes/text per item so its easiest to see a lot"): compact rows, the name and "x2
-- left" on one line, what it does under it; the Buy keeps a 44 px face on a phone (Scale.tapHeight)
local ROW_MIN_H = 50
local ROW_GAP = 4
local SECTION_H = 28
local PICTURE = 40
local BUY_W = 124
local STOCK_W = 110
local PENDING_SECONDS = 3 -- a buy with no answer lets the button go again after this long (#1384)
-- The server takes BuyCornerShop 2 a second and drops the rest with no answer (Net.luau), which left a fast buyer's
-- button on "..." (#1384). Buys are spaced this far apart; a press inside the gap waits its turn instead.
local SEND_GAP = 0.55
local GAP = Theme.sizes.gap

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
	self._pending = {} :: { [string]: number } -- itemId -> os.clock() of a buy with no answer yet
	self._lastSent = -math.huge -- os.clock() of the last buy sent
	self._queued = false -- a press inside SEND_GAP waits to be sent (one at a time)
	self._alive = true
	self._open = false
	self._tick = 0
	self._buyH = Scale.tapHeight(36, Theme.sizes.buttonDepth)
	self._rowH = math.max(ROW_MIN_H, self._buyH + 10)
	self._headers = {} :: { TextLabel }

	local panel = Panel.new({
		dark = true,
		name = "CornerShop",
		title = CornerShopLogic.TITLE, -- "Day Cart" (#1577, day-cart.md: only the shown name changes)
		subtitle = "Coins only",
		color = Theme.colors.caramel,
		icon = "🏪",
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
	-- #1577 (day-cart.md): the help line, "Coins only. New stock at sunrise. The same cart for everyone."
	text({
		Name = "Same",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		Text = CornerShopLogic.HELP,
		Parent = content,
	})
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

	self._list = Create("ScrollingFrame", {
		Name = "Items",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, TOP_H + GAP),
		Size = UDim2.new(1, 0, 1, -(TOP_H + GAP + NOTE_H + GAP)),
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
		Create("UIPadding", {
			PaddingRight = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, Theme.sizes.buttonDepth + 2),
		}),
	})
	self._empty = text({
		Name = "Empty",
		Size = UDim2.new(1, 0, 0, 60),
		TextColor3 = PAL.subtext,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "The shop is opening…",
		Parent = self._list,
	})
	text({
		Name = "Lawn",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, NOTE_H),
		TextSize = Theme.sizes.textTiny + 1,
		TextColor3 = PAL.subtext,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Lawn pieces are in Decor, Front lawn",
		Parent = content,
	})

	self:_buildPicker(content)
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
		Create("UIPadding", {
			PaddingRight = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, Theme.sizes.buttonDepth + 2),
		}),
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

-- Sends one buy now, from the stock as it is now (a new window may have come while it waited).
function CornerShop._fire(self: any, itemId: string, catUid: string?)
	local stock: SharedTypes.CornerShopStock? = self._stock
	local item: SharedTypes.CornerShopItem? = nil
	if stock ~= nil then
		for _, each in stock.stock do
			if each.itemId == itemId then
				item = each
			end
		end
	end
	if stock == nil or item == nil then
		self._pending[itemId] = nil -- gone from the shop while it waited
		self:_paint()
		return
	end
	local price: number = (item :: SharedTypes.CornerShopItem).price
	local now = os.clock()
	self._lastSent = now
	self._pending[itemId] = now -- the wait runs from the send
	self._callbacks.buy(itemId, stock.window, price, catUid)
	-- the "..." always lets go, even with the window's own repaint stopped (#1384)
	task.delay(PENDING_SECONDS + 0.1, function()
		if self._alive then
			self:_paint()
		end
	end)
	self:_paint()
end

function CornerShop._send(self: any, item: SharedTypes.CornerShopItem, catUid: string?)
	if self._stock == nil then
		return
	end
	local itemId = item.itemId
	local wait = self._lastSent + SEND_GAP - os.clock()
	if wait <= 0 then
		self:_fire(itemId, catUid)
		return
	end
	if self._queued then
		return -- one buy already waits its turn; this press is too fast to send
	end
	self._queued = true
	self._pending[itemId] = os.clock()
	self:_paint()
	task.delay(wait, function()
		self._queued = false
		if self._alive then
			self:_fire(itemId, catUid)
		end
	end)
end

function CornerShop._press(self: any, itemId: string)
	local stock: SharedTypes.CornerShopStock? = self._stock
	if stock == nil then
		return
	end
	local pressedAt = self._pending[itemId]
	if pressedAt and os.clock() - pressedAt < PENDING_SECONDS then
		return
	end
	for _, item in stock.stock do
		if item.itemId == itemId then
			-- Corner Shop v2 (#1181): food goes to the Bag, so no row opens the cat picker on buy
			self:_send(item, nil)
			return
		end
	end
end

function CornerShop._clear(self: any)
	for _, row: Row in self._rows do
		row.icon:destroy()
		row.buy:destroy()
		row.frame:Destroy()
	end
	table.clear(self._rows)
	for _, header in self._headers do
		header:Destroy()
	end
	table.clear(self._headers)
end

-- #1599: a section's header over its rows ("Potions").
function CornerShop._header(self: any, section: CornerShopLogic.Section, order: number)
	local header = text({
		Name = "Section_" .. section.kind,
		Size = UDim2.new(1, 0, 0, SECTION_H),
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
		for _, index in section.indexes do
			order += 1
			orderOf[index] = order
		end
	end
	local rowH = self._rowH
	for index, item in stock.stock do
		local itemId = item.itemId
		local def = rowOf(itemId)
		local frame: Frame = Create("Frame", {
			Name = itemId,
			BackgroundColor3 = PAL.card,
			BorderSizePixel = 0,
			LayoutOrder = orderOf[index] or index,
			Size = UDim2.new(1, 0, 0, rowH),
			Parent = self._list,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }),
			Create("UIStroke", { Color = PAL.cardStroke, Thickness = Theme.sizes.stroke }),
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
			Text = if def then def.name else itemId,
			Parent = frame,
		})
		Outline.text(name, 1.5)
		local line = text({
			Name = "Line",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -right, 0.5, -18),
			Size = UDim2.fromOffset(STOCK_W, 18),
			FontFace = Theme.fonts.bodyBold,
			TextSize = Theme.sizes.textTiny + 1,
			TextColor3 = PAL.subtext,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = frame,
		})
		local effect = text({
			Name = "Effect",
			Position = UDim2.new(0, left, 0.5, 3),
			Size = UDim2.new(1, -(left + right), 0, 16),
			TextSize = Theme.sizes.textTiny + 1,
			TextColor3 = PAL.subtext,
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
	local coins = if state then state.money else 0
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
		row.line.Text = gate or CornerShopLogic.stockLine(item)
		local pressedAt = self._pending[item.itemId]
		local waiting = pressedAt ~= nil and os.clock() - pressedAt < PENDING_SECONDS
		local view = CornerShopLogic.button(item, def, coins, room, tier)
		row.buy:setText(if waiting then "..." else view.text)
		row.buy:setEnabled(view.enabled and not waiting)
	end
end

-- CornerShopStock: on join, every 5 minute window and after every buy (bought or refused); it ends every wait.
function CornerShop.setStock(self: any, stock: SharedTypes.CornerShopStock?)
	local old: SharedTypes.CornerShopStock? = self._stock
	self._stock = stock
	table.clear(self._pending)
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
				self:_paint()
			end
		end
	end)
end

function CornerShop.closed(self: any)
	self._open = false
	self._tick += 1
	self._picker.Visible = false
end

function CornerShop.destroy(self: any)
	self._open = false
	self._alive = false
	self:_clear()
	self:_clearPicker()
	self._pickerBack:destroy()
	self._panel:destroy()
end

return CornerShop
