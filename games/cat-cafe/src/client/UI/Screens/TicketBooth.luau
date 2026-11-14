--!strict
-- #4061 The Ticket Booth window (Water Park late station; Design-Agent/notes/ticket-booth-and-dragon-keep.md 1.4, the
-- station menus picture Derek OK'd 2026-11-14 00:43 UTC): the cocoa station look, the ticket count big at the top
-- right, the day's Ticket Rush line beside it, and the fixed prizes as picture cards, 4 a row on a wide window (3 on a
-- narrow one, GridFit), scrolling for the rest. Each card: its picture, name, the limit left ("4 left today"), the
-- price in tickets and one green BUY. Short of the price, BUY reads SAVE UP and a thin bar shows "1,240 / 3,000". At
-- 1,000 tickets and over, the first tap turns BUY into "Tap again" for 3 seconds. Nothing random and nothing sold for
-- Robux. The server decides every buy (BuyTicketPrize) and answers with a toast and a sync.
--   TicketBooth.new(callbacks)   built hidden; the UI registers its frame as the "TicketBooth" modal
--   :setView(view) :opened() :closed() :destroy()

local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
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
local TicketBoothLogic = require(script.Parent.Parent.Components.TicketBoothLogic)
local Types = require(script.Parent.Parent.Types)

local PAL = MenuFamily.pal
local CARD = MenuFamily.card

export type Callbacks = {
	buy: (prizeId: string) -> (),
	close: () -> (),
}

export type TicketBooth = {
	frame: Frame,
	setView: (self: TicketBooth, view: Types.TicketBoothView?) -> (),
	opened: (self: TicketBooth) -> (),
	closed: (self: TicketBooth) -> (),
	destroy: (self: TicketBooth) -> (),
}

local MAX_SIZE = Vector2.new(780, 540)
local GAP = Theme.sizes.gap
local TOP_H = 34 -- the Rush line and the ticket count
local COUNT_W = 132
local PICTURE = 52
local NAME_H = 22
local CHIP_H = 16
local SAVED_H = 18 -- the bar and its "1,240 / 3,000"
local PRICE_H = 22
local CELL_MIN = 140 -- a card no narrower than this (design px), so four fit only where their words do
local STROKE = 2
local EDGE = Color3.fromHex("F29A3A") -- the booth's ticket orange on its cards' edge (the station menus picture)
local TICK_SECONDS = 15 -- the Rush line's minutes while the window is up

-- a prize id's picture: the glyph and, once loaded, its image
local PICTURES: { [string]: { glyph: string, rarity: string, image: (() -> string?)?, potion: string? } } =
	{
		fish25 = {
			glyph = Theme.icons.goldenFish,
			rarity = "Rare",
			image = function()
				return Theme.textures.fishCoin
			end,
		},
		traitToken = {
			glyph = "🔮",
			rarity = "Epic",
			image = function()
				return ShopIcons.hud("TraitToken")
			end,
		},
		goldenCrate = {
			glyph = "📦",
			rarity = "Legendary",
			image = function()
				return ShopIcons.crate("classic_golden_crate")
			end,
		},
		bigGoldRush = { glyph = "💰", rarity = "Epic", potion = "big_gold_rush_potion" },
		bigLucky = { glyph = "🍀", rarity = "Epic", potion = "big_lucky_potion" },
		swiftPaws = { glyph = "👟", rarity = "Rare", potion = "swift_potion_big" },
	}

local TicketBooth = {}
TicketBooth.__index = TicketBooth

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textBody,
		TextColor3 = CARD.text,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

function TicketBooth.new(callbacks: Callbacks): TicketBooth
	local self = setmetatable({}, TicketBooth) :: any
	self._callbacks = callbacks
	self._view = nil :: Types.TicketBoothView?
	self._cards = {} :: { [string]: any }
	self._armed = nil :: string?
	self._open = false
	self._tick = 0
	self._buyH = Scale.tapHeight(40, Theme.sizes.buttonDepth)

	local panel = Panel.new({
		dark = true,
		name = "TicketBooth",
		title = "Ticket Booth",
		subtitle = "Every cat you catch drops tickets",
		color = Theme.colors.redDark,
		icon = TicketBoothLogic.TICKET,
		image = ShopIcons.hud("TicketBooth"),
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = MAX_SIZE, Parent = panel.frame })
	panel.frame.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.frame.Position = UDim2.fromScale(0.5, 0.5)
	self._panel = panel
	self.frame = panel.frame
	local content = panel.content

	-- the top row: the Rush line at the left, the ticket count at the right
	self._rush = text({
		Name = "Rush",
		Size = UDim2.new(1, -(COUNT_W + GAP), 0, TOP_H),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = content,
	})
	FitText.shrink(self._rush)
	local count: Frame = Create("Frame", {
		Name = "Tickets",
		BackgroundColor3 = PAL.card,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(COUNT_W, TOP_H),
		Parent = content,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIStroke", { Color = EDGE, Thickness = STROKE }),
	})
	self._count = text({
		Name = "Count",
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		TextColor3 = PAL.gold,
		Text = TicketBoothLogic.ticketText(0),
		Parent = count,
	})
	FitText.shrink(self._count)
	Outline.text(self._count, 1.5)

	-- the prize cards
	local grid: ScrollingFrame = Create("ScrollingFrame", {
		Name = "Prizes",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, TOP_H + GAP),
		Size = UDim2.new(1, 0, 1, -(TOP_H + GAP)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = PAL.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		Parent = content,
	}, {
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, STROKE + 2),
			PaddingRight = UDim.new(0, STROKE + 2),
			PaddingTop = UDim.new(0, STROKE + 2),
			PaddingBottom = UDim.new(0, STROKE + 2),
		}),
	})
	local layout: UIGridLayout = Create("UIGridLayout", {
		CellPadding = UDim2.fromOffset(GAP, GAP),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	self._grid = grid
	self._cardH = 8 + PICTURE + 4 + NAME_H + CHIP_H + 2 + SAVED_H + PRICE_H + 4 + self._buyH + 8
	GridFit.fit(grid, layout, CELL_MIN, GAP, function()
		return self._cardH
	end)
	return self :: TicketBooth
end

-- One prize card, made the first time its prize shows.
function TicketBooth._card(self: any, id: string, order: number): any
	local entry = self._cards[id]
	if entry then
		entry.frame.LayoutOrder = order
		return entry
	end
	local frame: Frame = Create("Frame", {
		Name = "Prize_" .. id,
		BackgroundColor3 = CARD.card,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = self._grid,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = CARD.cardStroke, Thickness = STROKE }),
	})
	local picture = PICTURES[id]
	local icon = ItemIcon.new({
		parent = frame,
		size = UDim2.fromOffset(PICTURE, PICTURE),
		anchorPoint = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, 8),
	})
	if picture and picture.potion then
		icon:setPotion(picture.potion, picture.rarity)
	elseif picture then
		icon:set(nil, picture.glyph, picture.rarity, if picture.image then picture.image() else nil)
	else
		icon:set(nil, TicketBoothLogic.TICKET, "Common", nil)
	end
	local y = 8 + PICTURE + 4
	local name = text({
		Name = "Name",
		Position = UDim2.fromOffset(6, y),
		Size = UDim2.new(1, -12, 0, NAME_H),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody,
		Parent = frame,
	})
	FitText.shrink(name)
	y += NAME_H
	local chip = text({
		Name = "Chip",
		Position = UDim2.fromOffset(6, y),
		Size = UDim2.new(1, -12, 0, CHIP_H),
		TextSize = Theme.sizes.textTiny + 1,
		TextColor3 = CARD.subtext,
		Parent = frame,
	})
	FitText.shrink(chip)
	y += CHIP_H + 2
	-- the bar of tickets saved and its numbers, while short of the price
	local saved: Frame = Create("Frame", {
		Name = "Saved",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, y),
		Size = UDim2.new(1, -20, 0, SAVED_H),
		Visible = false,
		Parent = frame,
	})
	local track: Frame = Create("Frame", {
		Name = "Track",
		BackgroundColor3 = CARD.line,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 5),
		Parent = saved,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local fill: Frame = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local numbers = text({
		Name = "Numbers",
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, SAVED_H - 6),
		TextSize = Theme.sizes.textTiny,
		TextColor3 = CARD.subtext,
		Parent = saved,
	})
	FitText.shrink(numbers)
	y += SAVED_H
	local price = text({
		Name = "Price",
		Position = UDim2.fromOffset(6, y),
		Size = UDim2.new(1, -12, 0, PRICE_H),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 1,
		TextColor3 = MenuFamily.onCard(Theme.colors.goldDark),
		Parent = frame,
	})
	FitText.shrink(price)
	local made: any = {}
	made.buy = Button.new({
		name = "Buy",
		text = "BUY",
		style = "primary",
		size = UDim2.new(1, -16, 0, self._buyH),
		anchorPoint = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -8),
		textSize = Theme.sizes.textBody,
		parent = frame,
		onClick = function()
			self:_press(id)
		end,
	})
	made.frame = frame
	made.icon = icon
	made.name = name
	made.chip = chip
	made.saved = saved
	made.fill = fill
	made.numbers = numbers
	made.price = price
	self._cards[id] = made
	return made
end

function TicketBooth.setView(self: any, view: Types.TicketBoothView?)
	self._view = view
	self:_paint()
end

function TicketBooth._paint(self: any)
	local view: Types.TicketBoothView? = self._view
	local now = Workspace:GetServerTimeNow()
	local tickets = if view then view.tickets else 0
	self._count.Text = TicketBoothLogic.ticketText(tickets)
	self._rush.Text = if view
		then TicketBoothLogic.rushLine(view.rushEndsAt, view.rushUsedToday, now)
		else ""
	local shown: { [string]: boolean } = {}
	for order, row in (if view then view.prizes else {}) do
		local entry = self:_card(row.id, order)
		shown[row.id] = true
		entry.frame.Visible = true
		local card = TicketBoothLogic.card(row :: any, tickets, self._armed == row.id)
		entry.name.Text = row.name
		entry.chip.Text = card.chip
		entry.price.Text = TicketBoothLogic.ticketText(row.price)
		entry.saved.Visible = card.progress ~= nil
		entry.fill.Size = UDim2.fromScale(card.progress or 0, 1)
		entry.numbers.Text = card.saved or ""
		entry.buy:setText(card.button)
		entry.buy:setStyle(card.style :: any)
		entry.buy:setEnabled(card.enabled)
		entry.action = card.action
	end
	for id, entry in self._cards do
		if not shown[id] then
			entry.frame.Visible = false
		end
	end
end

-- A BUY tap: under CONFIRM_AT it buys; at it and over the first tap arms "Tap again" for ARM_SECONDS.
function TicketBooth._press(self: any, id: string)
	local entry = self._cards[id]
	if entry == nil then
		return
	end
	if entry.action == "arm" then
		self._armed = id
		self:_paint()
		task.delay(TicketBoothLogic.ARM_SECONDS, function()
			if self._armed == id then
				self._armed = nil
				self:_paint()
			end
		end)
		return
	end
	if entry.action ~= "buy" then
		return
	end
	self._armed = nil
	self._callbacks.buy(id)
	self:_paint()
end

function TicketBooth.opened(self: any)
	self._open = true
	self._armed = nil
	self:_paint()
	self._tick += 1
	local tick = self._tick
	task.spawn(function()
		while self._open and self._tick == tick do
			task.wait(TICK_SECONDS)
			if self._open and self._tick == tick then
				self:_paint()
			end
		end
	end)
end

function TicketBooth.closed(self: any)
	self._open = false
	self._armed = nil
	self._tick += 1
end

function TicketBooth.destroy(self: any)
	self._open = false
	self._tick += 1
	self._panel:destroy()
end

return TicketBooth
