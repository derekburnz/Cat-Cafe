--!strict
-- The Yard Sale's card (F100, camp-extras.md section 3), opened by its prompt at the Neighbourhood camp
-- (UI.campExtras.openYardSale). Since #1051 (crate-prices.md section 5) it holds one free crate a day, the zone crate
-- of the day: its picture, name, the Market's own price for comparison, an Odds button that turns the card to the
-- crate's rarity table (the crate is random, so its odds show before it is taken) and a green Take button ("Taken"
-- once taken, greyed). A press shows "..." until the next CampExtrasState or a refusal answers (refused). Under it: how many golden
-- fish the player has, when the next crate comes, and that a taken crate opens free at the Golden Fish Market, which
-- keeps the crate reel there. #3615: while the server sends the lucky pick's rows (the `yardSaleRoll` switch), the card
-- shows the pick instead: the roll board (Components/RollBoard) with one row per crate the player can win and its
-- chance, and a "Lucky pick" button; YardSalePicked(index) passes the board's light down the rows to the row the
-- server chose. A priced crate (an older server) still shows its price with the gold fish. Words and rules in Components/CampExtrasLogic; nothing is sold for Robux.

local Button = require(script.Parent.Parent.Components.Button)
local CampExtrasLogic = require(script.Parent.Parent.Components.CampExtrasLogic)
local Create = require(script.Parent.Parent.Components.Create)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local MenuFamily = require(script.Parent.Parent.Components.MenuFamily)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local RollBoard = require(script.Parent.Parent.Components.RollBoard)
local RollBoardLogic = require(script.Parent.Parent.Components.RollBoardLogic)
local Scale = require(script.Parent.Parent.Scale)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local ShortNumber = require(script.Parent.Parent.Components.ShortNumber)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

-- the dark window palette (#1028), in place of Theme.modal
local PAL = MenuFamily.pal
local CARD = MenuFamily.card -- #3558: what sits on a picture card (cream in the family look)

export type Callbacks = {
	buy: (crateId: string) -> (),
	pick: (() -> ())?, -- #3615: the Lucky pick button (YardSalePick)
	landed: ((crateId: string) -> ())?, -- #3615: the light has stopped on the crate won (the toast)
	tick: (() -> ())?, -- #3615: a row lit during the roll (its tick sound)
	close: () -> (),
	far: (() -> boolean)?, -- true once the player has walked away from the Yard Sale: the card closes
}

export type YardSale = {
	frame: Frame,
	setCatalog: (self: YardSale, catalog: Types.Catalog) -> (),
	-- the Yard Sale's view from CampExtrasState (nil before the first)
	setView: (self: YardSale, view: Types.CampExtraView?) -> (),
	render: (self: YardSale, state: Types.PlayerState) -> (),
	opened: (self: YardSale) -> (),
	closed: (self: YardSale) -> (),
	-- BuyYardSale refused: the "..." lifts and the crate's button wobbles (the server's toast says why)
	refused: (self: YardSale) -> (),
	-- #3615: YardSalePicked: the row the pick landed on; the light rolls down the board to it
	picked: (self: YardSale, index: number, crateId: string?) -> (),
	destroy: (self: YardSale) -> (),
}

type Card = {
	crateId: string,
	frame: Frame,
	icon: ItemIcon.ItemIcon,
	tile: Frame,
	status: TextLabel, -- #3953: "Free today" / "Taken"
	name: TextLabel,
	market: TextLabel,
	buy: Button.Button,
	label: string,
	enabled: boolean?,
	bought: boolean?,
}

local MAX_SIZE = Vector2.new(560, 310) -- #3953: wider (was 480), room for the pick's side card
local CARD_GAP = 14
local PICTURE = 76
local TILE = 116 -- #3953: the crate's picture tile on the wide card
local STATUS_H = 22 -- the "Free today" pill
local PILL_H = 20 -- an odds pill
local FREE_TODAY = "FREE TODAY"
local TAKEN = "TAKEN"
local SUBTITLE = "A free crate every day" -- #1051
local PICK_NOTE = "Crates you win open free at the Golden Fish Market"
local TAKE_NOTE = "Taken crates open free at the Golden Fish Market"
local PICK_GAP = 10
local PICK_BUTTON = "Lucky pick"
local PICK_TILE = 64 -- #3953: the picture on the pick's side card
local LANDED_SECONDS = 1.5 -- the light stays on the won row this long
local PENDING_SECONDS = 5 -- a buy with no answer lets the button go again after this long
local GAP = Theme.sizes.gap

local Workspace = game:GetService("Workspace")

local YardSale = {}
YardSale.__index = YardSale

-- Ink words on a light fill (gold, sky), white on a deep one, as the Mystic Pool's trait pills (#3950)
local function inkOn(fill: Color3): Color3
	local lum = 0.2126 * fill.R + 0.7152 * fill.G + 0.0722 * fill.B
	return if lum > 0.45 then Theme.colors.ink else Theme.colors.white
end

local function text(props: { [string]: any }, children: { Instance }?): TextLabel
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
	return Create("TextLabel", merged, children)
end

function YardSale.new(callbacks: Callbacks): YardSale
	local self = setmetatable({}, YardSale) :: any
	self._callbacks = callbacks
	self._catalog = nil :: Types.Catalog?
	self._view = nil :: Types.CampExtraView?
	self._fish = 0
	self._cards = {} :: { Card }
	self._pending = nil :: string? -- the crate a buy is out for
	self._pendingToken = 0
	self._open = false
	self._tick = 0
	self._buyH = Scale.tapHeight(44, Theme.sizes.buttonDepth)

	local panel = Panel.new({
		dark = true, -- #1028
		name = "YardSale",
		title = "Yard Sale",
		subtitle = SUBTITLE,
		color = Theme.colors.berry,
		icon = CampExtrasLogic.icon(CampExtrasLogic.YARD_SALE),
		image = ShopIcons.hud("YardSale"), -- #2836: the drawn badge (the emoji until it loads)
		size = UDim2.new(1, 0, 0, MAX_SIZE.Y + (self._buyH - 44)),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", {
		MaxSize = Vector2.new(MAX_SIZE.X, MAX_SIZE.Y + (self._buyH - 44)),
		Parent = panel.frame,
	})
	panel.frame.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.frame.Position = UDim2.fromScale(0.5, 0.5)
	self._panel = panel
	self.frame = panel.frame
	local content = panel.content

	local cardH = PICTURE + 70 + self._buyH
	self._row = Create("Frame", {
		Name = "Crates",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, cardH),
		Parent = content,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, CARD_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._cardH = cardH
	-- #3615: the lucky pick: the board in a scrolling box on the left, the button and its line on the right
	self._picking = false
	self._rolling = false
	self._rollToken = 0
	self._pickFrame = Create("Frame", {
		Name = "Pick",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, cardH),
		Visible = false,
		Parent = content,
	})
	self._pickScroll = Create("ScrollingFrame", {
		Name = "Board",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(0, RollBoard.WIDTH + 12, 1, 0),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = PAL.subtext,
		Parent = self._pickFrame,
	}, {
		-- room for the board's 3 px edge inside the clip
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 3),
			PaddingBottom = UDim.new(0, 3),
			PaddingLeft = UDim.new(0, 3),
		}),
	})
	local board = RollBoard.new(self._pickScroll)
	board.frame.AnchorPoint = Vector2.zero
	board.frame.Position = UDim2.new()
	self._board = board
	-- #3953: the side is a cream card as the crate card: the Yard Sale's picture on a gold tile with a "FREE" pill,
	-- the line in ink (white words sat on the dark body before and could not be read), the wide Lucky pick button
	local side: Frame = Create("Frame", {
		Name = "Side",
		BackgroundColor3 = CARD.card,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -3, 0, 3),
		Size = UDim2.new(1, -(RollBoard.WIDTH + 12 + PICK_GAP + 3), 1, -6),
		Parent = self._pickFrame,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = CARD.cardStroke, Thickness = Theme.sizes.stroke }),
	})
	local pickTile: Frame = Create("Frame", {
		Name = "Tile",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = CARD.goldCard,
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(PICK_TILE, PICK_TILE),
		Parent = side,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = CARD.cardStroke, Thickness = 2 }),
	})
	self._pickIcon = ItemIcon.new({
		parent = pickTile,
		size = UDim2.fromOffset(PICK_TILE - 10, PICK_TILE - 10),
		anchorPoint = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
	})
	self._pickIcon:set(nil, Theme.icons.crate, "Rare", ShopIcons.hud("YardSale"))
	local free: TextLabel = text({
		Name = "Free",
		AutomaticSize = Enum.AutomaticSize.X,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.colors.goodDark,
		Position = UDim2.new(0.5, 0, 0, 8 + PICK_TILE),
		Size = UDim2.fromOffset(0, STATUS_H),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textTiny + 1,
		TextColor3 = Theme.colors.white,
		TextTruncate = Enum.TextTruncate.None,
		Text = "FREE",
		ZIndex = 2,
		Parent = side,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
		Create("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = CARD.cardStroke,
			Thickness = 2,
		}),
	})
	Outline.text(free, 1)
	self._pickFree = free
	self._pickLine = text({
		Name = "Line",
		Position = UDim2.fromOffset(8, 8 + PICK_TILE + STATUS_H / 2 + 2),
		Size = UDim2.new(1, -16, 1, -(8 + PICK_TILE + STATUS_H / 2 + 2 + self._buyH + 12)),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		Parent = side,
	})
	self._pickLabel = PICK_BUTTON
	self._pickEnabled = nil :: boolean?
	self._pickButton = Button.new({
		name = "LuckyPick",
		text = PICK_BUTTON,
		style = "primary",
		size = UDim2.new(1, -16, 0, self._buyH),
		anchorPoint = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -8),
		textSize = Theme.sizes.textBody + 2,
		parent = side,
		onClick = function()
			self:_pressPick()
		end,
	})
	self._have = text({
		Name = "Have",
		Position = UDim2.fromOffset(0, cardH + GAP),
		Size = UDim2.new(1, 0, 0, 20),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.text,
		Parent = content,
	})
	self._note = text({
		Name = "Note",
		Position = UDim2.fromOffset(0, cardH + GAP + 20),
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = Theme.sizes.textTiny,
		TextColor3 = PAL.subtext,
		Text = TAKE_NOTE,
		Parent = content,
	})
	return self :: YardSale
end

function YardSale._crate(self: any, crateId: string): Types.CrateDef?
	local catalog: Types.Catalog? = self._catalog
	local crates: { Types.CrateDef } = if catalog and catalog.crates then catalog.crates else {}
	for _, crate in crates do
		if crate.id == crateId then
			return crate
		end
	end
	return nil
end

function YardSale._clear(self: any)
	for _, card: Card in self._cards do
		card.icon:destroy()
		card.buy:destroy()
		card.frame:Destroy()
	end
	table.clear(self._cards)
end

-- One card per crate in today's stock; rebuilt when the stock's crates change (a new day, a rank up). #3953: a wide
-- picture card as the station menus mock: the crate's picture on a gold tile at the left with a "Free today"
-- (or "Taken") pill on the tile's edge; at the right the crate's name in the display font, the Market's price and the crate's odds as coloured
-- rarity pills, always in view (the take is free but the crate is random: monetization-policy section 2); the wide
-- Take button along the bottom.
function YardSale._build(self: any, rows: { CampExtrasLogic.YardRow })
	self:_clear()
	local count = math.max(#rows, 1)
	for index, row in rows do
		local crateId = row.crateId
		local crate = self:_crate(crateId)
		local frame: Frame = Create("Frame", {
			Name = crateId,
			BackgroundColor3 = CARD.card,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Size = UDim2.new(
				1 / count,
				-math.floor(CARD_GAP * (count - 1) / count),
				0,
				self._cardH
			),
			Parent = self._row,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
			Create("UIStroke", { Color = CARD.cardStroke, Thickness = Theme.sizes.stroke }),
		})
		local top = self._cardH - self._buyH - 8 -- the room over the Take button
		local tileSize = math.min(TILE, top - 8 - math.ceil(STATUS_H / 2) - 4)
		local tile: Frame = Create("Frame", {
			Name = "Tile",
			BackgroundColor3 = CARD.goldCard,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(10, 8),
			Size = UDim2.fromOffset(tileSize, tileSize),
			Parent = frame,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
			Create("UIStroke", { Color = CARD.cardStroke, Thickness = 2 }),
		})
		local icon = ItemIcon.new({
			parent = tile,
			size = UDim2.fromOffset(tileSize - 12, tileSize - 12),
			anchorPoint = Vector2.new(0.5, 0.5),
			position = UDim2.fromScale(0.5, 0.5),
		})
		icon:set(
			if crate ~= nil then (crate :: any).asset or ShopIcons.crateModel(crateId) else nil,
			Theme.icons.crate,
			if crate ~= nil and crate.golden then "Legendary" else "Rare",
			ShopIcons.crate(crateId)
		)
		-- "Free today" / "Taken" on the tile's bottom edge
		local status: TextLabel = text({
			Name = "Status",
			AutomaticSize = Enum.AutomaticSize.X,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(10 + math.floor(tileSize / 2), 8 + tileSize),
			ZIndex = 2,
			BackgroundTransparency = 0,
			BackgroundColor3 = Theme.colors.goodDark,
			Size = UDim2.fromOffset(0, STATUS_H),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textTiny + 1,
			TextColor3 = Theme.colors.white,
			TextTruncate = Enum.TextTruncate.None,
			Text = FREE_TODAY,
			Parent = frame,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
			Create("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = CARD.cardStroke,
				Thickness = 2,
			}),
		})
		Outline.text(status, 1)
		local left = 10 + tileSize + 12
		local info: Frame = Create("Frame", {
			Name = "Info",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(left, 8),
			Size = UDim2.new(1, -(left + 10), 0, top - 8),
			Parent = frame,
		})
		local name = text({
			Name = "Name",
			Size = UDim2.new(1, 0, 0, 28),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textTitle - 2,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = if crate ~= nil then crate.name else crateId,
			Parent = info,
		})
		local marketPrice: number? = if crate ~= nil then crate.price else nil
		local market = text({
			Name = "Market",
			Position = UDim2.fromOffset(0, 28),
			Size = UDim2.new(1, 0, 0, 18),
			FontFace = Theme.fonts.bodyBold,
			TextSize = Theme.sizes.textSmall,
			TextColor3 = CARD.subtext,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = if marketPrice ~= nil
				then ("%d golden fish at the Market"):format(marketPrice)
				else "",
			Parent = info,
		})
		-- the odds as pills, two to a row (#3953; #1051's Odds sheet folded into the card)
		local pills: Frame = Create("Frame", {
			Name = "Odds",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 50),
			Size = UDim2.new(1, 0, 0, PILL_H * 3 + 8),
			Parent = info,
		}, {
			Create("UIGridLayout", {
				CellPadding = UDim2.fromOffset(4, 4),
				CellSize = UDim2.new(0.5, -2, 0, PILL_H),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		local odds: { [string]: number }? = if crate ~= nil then crate.odds else nil
		for order, line in CampExtrasLogic.yardOddsLines(odds) do
			local fill = Theme.rarityColor(line.rarity)
			local pill: TextLabel = text({
				Name = line.rarity,
				LayoutOrder = order,
				BackgroundTransparency = 0,
				BackgroundColor3 = fill,
				FontFace = Theme.fonts.bodyBold,
				TextScaled = true,
				TextColor3 = inkOn(fill),
				TextTruncate = Enum.TextTruncate.None,
				Text = string.upper(line.rarity) .. " " .. line.text,
				Parent = pills,
			}, {
				Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Create(
					"UIPadding",
					{ PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }
				),
				Create("UIStroke", {
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Color = CARD.cardStroke,
					Thickness = 2,
				}),
				Create(
					"UITextSizeConstraint",
					{ MaxTextSize = Theme.sizes.textTiny, MinTextSize = 9 }
				),
			})
			pill.Name = line.rarity
		end
		local buy = Button.new({
			name = "Buy",
			text = tostring(row.price),
			icon = Theme.icons.goldenFish,
			style = "primary",
			size = UDim2.new(1, -16, 0, self._buyH),
			anchorPoint = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -8),
			textSize = Theme.sizes.textBody + 2,
			parent = frame,
			onClick = function()
				self:_press(crateId)
			end,
		})
		table.insert(self._cards, {
			crateId = crateId,
			frame = frame,
			icon = icon,
			tile = tile,
			status = status,
			name = name,
			market = market,
			buy = buy,
			label = tostring(row.price),
			enabled = nil,
			bought = nil,
		})
	end
end

function YardSale._press(self: any, crateId: string)
	if self._pending ~= nil then
		return
	end
	for _, row in CampExtrasLogic.yardRows(self._view, self._fish) do
		if row.crateId == crateId and not row.bought and row.afford then
			self._pending = crateId
			self._pendingToken += 1
			local token = self._pendingToken
			task.delay(PENDING_SECONDS, function()
				if self._pendingToken == token and self._pending ~= nil then
					self._pending = nil
					self:_paint()
				end
			end)
			self:_paint()
			self._callbacks.buy(crateId)
			return
		end
	end
end

-- #3615: the Lucky pick button. One press is out at a time, and none while the light is rolling.
function YardSale._pressPick(self: any)
	local callbacks: Callbacks = self._callbacks
	local view: Types.CampExtraView? = self._view
	if self._pending ~= nil or self._rolling or callbacks.pick == nil or view == nil then
		return
	end
	if view.nextAt ~= nil and Workspace:GetServerTimeNow() < view.nextAt then
		return
	end
	self._pending = "pick"
	self._pendingToken += 1
	local token = self._pendingToken
	task.delay(PENDING_SECONDS, function()
		if self._pendingToken == token and self._pending ~= nil then
			self._pending = nil
			self:_paint()
		end
	end)
	self:_paint()
	callbacks.pick()
end

-- #3615: the card as the lucky pick. True when it painted (the server sent the pick's rows), so the crate cards hide.
function YardSale._paintPick(self: any): boolean
	local view: Types.CampExtraView? = self._view
	local rows = if view ~= nil and view.open then view.pick else nil
	local picking = rows ~= nil and #rows > 0
	if self._picking ~= picking then
		self._picking = picking
		self._pickFrame.Visible = picking
		self._row.Visible = not picking
		self._note.Text = if picking then PICK_NOTE else TAKE_NOTE
		self._panel:setTitle(
			"Yard Sale",
			if picking then "A free lucky pick. " .. RollBoardLogic.yardLine() else SUBTITLE
		)
	end
	if rows == nil or view == nil or not picking then
		return false
	end
	local now = Workspace:GetServerTimeNow()
	local made = RollBoardLogic.yard({
		rows = rows,
		nextAt = view.nextAt,
		now = now,
		rolling = self._rolling,
	})
	self._board:set(made)
	local waiting = view.nextAt ~= nil and now < view.nextAt
	local pending = self._pending == "pick"
	local label = if pending then "..." else PICK_BUTTON
	if self._pickLabel ~= label then
		self._pickLabel = label
		self._pickButton:setText(label)
	end
	local enabled = not waiting and not pending and not self._rolling
	if self._pickEnabled ~= enabled then
		self._pickEnabled = enabled
		self._pickButton:setEnabled(enabled)
	end
	local free: TextLabel = self._pickFree
	free.Text = if waiting then "SOON" else "FREE"
	free.BackgroundColor3 = if waiting then Theme.colors.disabledDark else Theme.colors.goodDark
	self._pickLine.Text = if self._rolling
		then RollBoardLogic.YARD_ROLLING
		elseif waiting then made.line
		else "Free. Every pick wins a crate."
	return true
end

-- Keeps the lit row inside the scrolling box, measured on screen (the board is drawn smaller on a phone), with EDGE
-- px of room for the lit row's edge, which the box's clip would cut at the very top or bottom.
function YardSale._showRow(self: any, index: number)
	local scroll: ScrollingFrame = self._pickScroll
	local row = self._board.frame:FindFirstChild("Row" .. index)
	if row == nil or not row:IsA("GuiObject") then
		return
	end
	local EDGE = 4
	local y = scroll.CanvasPosition.Y
	local top = (row :: GuiObject).AbsolutePosition.Y - scroll.AbsolutePosition.Y + y
	local bottom = top + (row :: GuiObject).AbsoluteSize.Y
	local room = scroll.AbsoluteWindowSize.Y
	if top - EDGE < y then
		y = top - EDGE
	elseif bottom + EDGE > y + room then
		y = bottom + EDGE - room
	end
	scroll.CanvasPosition = Vector2.new(0, math.max(0, y))
end

function YardSale.picked(self: any, index: number, crateId: string?)
	self._pending = nil
	self._pendingToken += 1
	local view: Types.CampExtraView? = self._view
	local rows = if view ~= nil then view.pick else nil
	-- the server names the crate: the rows here may have changed since the press (a rank up opens an area)
	if rows ~= nil and type(crateId) == "string" then
		index = RollBoardLogic.rowOf(rows, crateId) or index
	end
	if rows == nil or not self._picking or index < 1 or index > #rows then
		self:_paint()
		-- no board to roll: the prize is still told
		local known: Callbacks = self._callbacks
		if type(crateId) == "string" and known.landed ~= nil then
			known.landed(crateId)
		end
		return
	end
	self._rollToken += 1
	local token = self._rollToken
	self._rolling = true
	self:_paint()
	task.spawn(function()
		for _, step in RollBoardLogic.rollSteps(#rows, index) do
			if self._rollToken ~= token then
				return
			end
			-- a closed card skips to the end: the crate is already banked
			if self._open then
				self._board:light(step.index)
				self:_showRow(step.index)
				local ticking: Callbacks = self._callbacks
				if ticking.tick ~= nil then
					ticking.tick()
				end
				task.wait(step.rest)
			end
		end
		if self._rollToken ~= token then
			return
		end
		self._board:light(index)
		self:_showRow(index)
		local callbacks: Callbacks = self._callbacks
		if callbacks.landed ~= nil then
			callbacks.landed(rows[index].crateId)
		end
		if self._open then
			task.wait(LANDED_SECONDS)
		end
		if self._rollToken == token then
			self._rolling = false
			self._board:light(nil)
			self:_paint()
		end
	end)
end

function YardSale._paint(self: any)
	self._have.Text = ("You have %s golden fish"):format(ShortNumber.format(self._fish))
	if self:_paintPick() then
		return
	end
	local rows = CampExtrasLogic.yardRows(self._view, self._fish)
	local same = #rows == #self._cards
	if same then
		for index, row in rows do
			if self._cards[index].crateId ~= row.crateId then
				same = false
			end
		end
	end
	if not same then
		self:_build(rows)
	end
	for index, row in rows do
		local card: Card = self._cards[index]
		local pending = self._pending == row.crateId
		local label = CampExtrasLogic.yardButton(row, pending)
		if card.label ~= label then
			card.label = label
			card.buy:setText(label)
		end
		local fish: TextLabel? = card.buy.icon
		if fish then
			fish.Visible = not row.bought and not pending and row.price > 0
		end
		local enabled = not row.bought and row.afford and self._pending == nil
		if card.enabled ~= enabled then
			card.enabled = enabled
			card.buy:setEnabled(enabled)
		end
		if card.bought ~= row.bought then
			card.bought = row.bought
			card.status.Text = if row.bought
				then TAKEN
				elseif row.price > 0 then "TODAY"
				else FREE_TODAY
			card.status.BackgroundColor3 = if row.bought
				then Theme.colors.disabledDark
				else Theme.colors.goodDark
			local faded = if row.bought then 0.5 else 0
			card.name.TextTransparency = faded
			card.market.TextTransparency = faded
			card.tile.BackgroundTransparency = faded
		end
	end
	-- No stock counts or restock clocks in shop windows (#1190, the friend 11-04); the server's stock rules are unchanged.
	self._have.Text = ("You have %s golden fish"):format(ShortNumber.format(self._fish))
end

function YardSale.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	self:_clear()
	self:_paint()
end

function YardSale.setView(self: any, view: Types.CampExtraView?)
	-- a new state answers the buy that was out
	self._view = view
	self._pending = nil
	self._pendingToken += 1
	self:_paint()
end

function YardSale.render(self: any, state: Types.PlayerState)
	local fish: number = state.goldenFish or 0
	if fish ~= self._fish then
		self._fish = fish
		self:_paint()
	end
end

-- While open the "New crates in" countdown moves once a second, and walking away closes the card.
function YardSale.opened(self: any)
	self._open = true
	self._tick += 1
	local tick = self._tick
	self:_paint()
	task.spawn(function()
		while self._open and self._tick == tick do
			task.wait(1)
			if self._open and self._tick == tick then
				local callbacks: Callbacks = self._callbacks
				local far = callbacks.far
				if far ~= nil and far() then
					self._callbacks.close()
					return
				end
				self:_paint()
			end
		end
	end)
end

function YardSale.closed(self: any)
	self._open = false
	self._tick += 1
end

function YardSale.refused(self: any)
	local crateId = self._pending
	self._pending = nil
	self._pendingToken += 1
	self:_paint()
	for _, card: Card in self._cards do
		if card.crateId == crateId then
			local button: Frame = card.buy.instance
			button.Rotation = -8
			Tween.to(
				button,
				TweenInfo.new(0.45, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
				{ Rotation = 0 }
			)
		end
	end
end

function YardSale.destroy(self: any)
	self._open = false
	self._tick += 1
	self._rollToken += 1
	self._pickButton:destroy()
	self._pickIcon:destroy()
	self._board:destroy()
	self:_clear()
	self._panel:destroy()
end

return YardSale
