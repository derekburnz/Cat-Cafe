--!strict
-- The Trade window (F102, trading.md sections 2 and 3), modal "Trade", opened by the HUD's Trade tile and by the
-- server once a trade starts. It has two faces:
--   * the players in this server, each with their head, display name and Trade (Asked for TradeRequestSeconds after a
--     press, Busy while they trade, "Tier 3 needed" under the minimum, all off while trading rests). Trade fires
--     callbacks.request(userId); the other player gets the request card (UI.trade.asked) and the server's
--     TradeState opens the window for both.
--   * the trade itself while a TradeState is held. Offer: "You give" and "Sam gives" as two 3 x 3 grids, each with a
--     green "✓ Ready" chip and its earnings under it ("Your cats: $180/s now", "Their cats: +$240/s in your cafe"),
--     and your cats on the right, rarest first: a press adds one to your offer (or takes it back), a locked cat says
--     "Unlock it on its card to trade". A press on a cat in your grid takes it back. Any change flashes that tile
--     yellow and shows "Changed!" over its side for 2 s (the server clears both Ready). Ready, then a big countdown
--     over the grids while both are ready; Not ready stops it. Confirm: "You give" and "You get" as rows of bigger
--     cards with their names and rarities, a red line for a gift or a lopsided trade (Confirm waits 2 s then), Cancel
--     and Confirm. The words are Components/TradeLogic's; the server decides everything, and this only asks.
-- Cancel (or the X) fires callbacks.cancel(tradeId) during a trade; the window closes when TradeState goes nil.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)
local TradeLogic = require(script.Parent.Parent.Components.TradeLogic)
local TradeTile = require(script.Parent.Parent.Components.TradeTile)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

export type Callbacks = {
	close: () -> (),
	request: (userId: number) -> (),
	offer: (tradeId: string, action: "add" | "remove", uid: string) -> (),
	ready: (tradeId: string, version: number, ready: boolean) -> (),
	confirm: (tradeId: string, version: number) -> (),
	cancel: (tradeId: string) -> (),
}

export type Trade = {
	frame: Frame,
	setCatalog: (self: Trade, catalog: Types.Catalog) -> (),
	render: (self: Trade, state: Types.PlayerState) -> (),
	-- TradeState from the server; nil ends the trade face (the window shows the players again)
	setTrade: (self: Trade, trade: Types.TradeState?) -> (),
	trading: (self: Trade) -> boolean,
	opened: (self: Trade) -> (),
	closed: (self: Trade) -> (),
	destroy: (self: Trade) -> (),
}

type Row = {
	userId: number,
	frame: Frame,
	name: TextLabel,
	tier: TextLabel,
	button: Button.Button,
}

type ConfirmCard = { tile: TradeTile.TradeTile, frame: Frame, name: TextLabel, rarity: TextLabel }

local MAX_SIZE = Vector2.new(760, 420)
local GRID_GAP = 6
local CONFIRM_TILE = 60
local COLUMN_W = 220
local ROW_H = 56
local HEADER_H = 24
local TICK_SECONDS = 0.25 -- the countdown, the confirm wait and the "Changed!" flash move on
local PRESS_HOLD = 3 -- a Ready or Confirm press with no answer lets the button go again after this long
local GAP = Theme.sizes.gap

local Trade = {}
Trade.__index = Trade

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

local function chip(
	parent: Instance,
	name: string,
	label: string,
	color: Color3,
	textColor: Color3
): TextLabel
	local pill = text({
		Name = name,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		BackgroundTransparency = 0,
		BackgroundColor3 = color,
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textTiny,
		TextColor3 = textColor,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		Text = label,
		Visible = false,
		ZIndex = 4,
		Parent = parent,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = pill })
	Create(
		"UIPadding",
		{ PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = pill }
	)
	return pill
end

function Trade.new(callbacks: Callbacks): Trade
	local self = setmetatable({}, Trade) :: any
	self._callbacks = callbacks
	self._catById = {} :: { [string]: Types.CatDef }
	self._state = nil :: Types.PlayerState?
	self._trade = nil :: Types.TradeState?
	self._open = false
	self._alive = true
	self._asked = {} :: { [number]: number } -- userId -> os.clock() when the Asked wears off
	self._rows = {} :: { [number]: Row }
	self._pickTiles = {} :: { [string]: TradeTile.TradeTile }
	self._picks = {} :: { TradeLogic.Pick }
	self._confirmSince = nil :: number? -- os.clock() when this version's confirm screen showed
	self._confirmKey = ""
	self._flashKey = ""
	self._pressed = nil :: number? -- os.clock() of a Ready or Confirm press not answered yet
	self._hint = nil :: string?
	self._hintUntil = 0
	self._tile = Scale.tapHeight(58)
	self._buttonH = Scale.tapHeight(44, Theme.sizes.buttonDepth)
	self._rowButtonH = Scale.tapHeight(44, Theme.sizes.buttonDepth)

	local panel = Panel.new({
		name = "Trade",
		title = TradeLogic.TITLE,
		subtitle = "Swap cats with players in this server",
		color = Theme.colors.mintDark,
		icon = TradeLogic.ICON,
		size = UDim2.fromScale(1, 1),
		onClose = function()
			self:_close()
		end,
	})
	Create("UISizeConstraint", { MaxSize = MAX_SIZE, Parent = panel.frame })
	panel.frame.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.frame.Position = UDim2.fromScale(0.5, 0.5)
	self._panel = panel
	self.frame = panel.frame
	local content = panel.content

	self:_buildPlayers(content)
	self:_buildOffer(content)
	self:_buildConfirm(content)

	-- the bottom row, shared by the offer and confirm faces: Cancel on the left, Ready or Confirm on the right
	local buttons: Frame = Create("Frame", {
		Name = "Buttons",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, self._buttonH),
		Visible = false,
		Parent = content,
	})
	self._buttons = buttons
	self._cancel = Button.new({
		name = "Cancel",
		text = "Cancel",
		style = "ghost",
		size = UDim2.fromOffset(150, self._buttonH),
		textSize = Theme.sizes.textBody,
		parent = buttons,
		onClick = function()
			local trade: Types.TradeState? = self._trade
			if trade then
				callbacks.cancel(trade.tradeId)
			end
		end,
	})
	self._go = Button.new({
		name = "Go",
		text = "Ready",
		style = "primary",
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.fromScale(1, 0),
		size = UDim2.fromOffset(200, self._buttonH),
		textSize = Theme.sizes.textBody,
		parent = buttons,
		onClick = function()
			self:_pressGo()
		end,
	})
	-- the two totals between the buttons: what your offer earns now, and what theirs would earn in your cafe
	for index, key in { "me", "them" } do
		local total: TextLabel = self._side[key].total
		total.AnchorPoint = Vector2.new(0.5, 0.5)
		total.Position = UDim2.new(0.5, 0, 0.5, if index == 1 then -10 else 10)
		total.Size = UDim2.new(1, -(150 + 200 + 2 * GAP), 0, 20)
		total.TextWrapped = false
		total.TextTruncate = Enum.TextTruncate.AtEnd
		total.TextYAlignment = Enum.TextYAlignment.Center
		total.Parent = buttons
	end

	task.spawn(function()
		while self._alive do
			task.wait(TICK_SECONDS)
			if self._alive and self._open then
				self:_tick()
			end
		end
	end)
	return self :: Trade
end

-- The players face: a scroll of rows, a line when nobody can be asked, and the rule under them.
function Trade._buildPlayers(self: any, content: Frame)
	local players: Frame = Create("Frame", {
		Name = "Players",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = content,
	})
	self._playersFace = players
	local list: ScrollingFrame = Create("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -44),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.modal.subtext,
		Parent = players,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Create("UIPadding", { PaddingRight = UDim.new(0, 10) }),
	})
	self._list = list
	self._empty = text({
		Name = "Empty",
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 44),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		TextColor3 = Theme.modal.subtext,
		Text = "Nobody else is in this server yet. Invite a friend to trade with!",
		Visible = false,
		Parent = players,
	})
	self._rule = text({
		Name = "Rule",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 36),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.subtext,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		Text = "Cats only. Locked cats stay home until you unlock them on their card.",
		Parent = players,
	})
end

function Trade._row(self: any, player: Player): Row
	local existing: Row? = self._rows[player.UserId]
	if existing then
		return existing
	end
	local frame: Frame = Create("Frame", {
		Name = "Player" .. player.UserId,
		BackgroundColor3 = Theme.modal.card,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, math.max(ROW_H, self._rowButtonH + 12)),
		Parent = self._list,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }) })
	local head: ImageLabel = Create("ImageLabel", {
		Name = "Head",
		BackgroundColor3 = Theme.colors.cream,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(40, 40),
		Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48"):format(player.UserId),
		Parent = frame,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(head, 2)
	local name = text({
		Name = "Name",
		Position = UDim2.new(0, 58, 0.5, -19),
		Size = UDim2.new(1, -230, 0, 22),
		FontFace = Theme.fonts.bodyBold,
		Text = player.DisplayName,
		Parent = frame,
	})
	local tier = text({
		Name = "Tier",
		Position = UDim2.new(0, 58, 0.5, 3),
		Size = UDim2.new(1, -230, 0, 18),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.subtext,
		Parent = frame,
	})
	local userId = player.UserId
	local button = Button.new({
		name = "Ask",
		text = "Trade",
		style = "primary",
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, -8, 0.5, 0),
		size = UDim2.fromOffset(150, self._rowButtonH),
		textSize = Theme.sizes.textSmall,
		parent = frame,
		onClick = function()
			self._asked[userId] = os.clock() + TradeLogic.REQUEST_SECONDS
			self._callbacks.request(userId)
			self:_renderPlayers()
		end,
	})
	local row: Row = { userId = userId, frame = frame, name = name, tier = tier, button = button }
	self._rows[userId] = row
	return row
end

-- The offer face: the two grids with their headers and totals, your cats on the right, the countdown over the grids.
function Trade._buildOffer(self: any, content: Frame)
	local offer: Frame = Create("Frame", {
		Name = "Offer",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -(self._buttonH + GAP)),
		Visible = false,
		Parent = content,
	})
	self._offerFace = offer
	local tile = self._tile
	local gridW = 3 * tile + 2 * GRID_GAP
	local function column(
		name: string,
		x: number,
		title: string
	): (Frame, TextLabel, TextLabel, TextLabel, Frame, TextLabel)
		local frame: Frame = Create("Frame", {
			Name = name,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.new(0, math.max(COLUMN_W, gridW), 1, 0),
			Parent = offer,
		})
		local header: Frame = Create("Frame", {
			Name = "Header",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, HEADER_H),
			Parent = frame,
		})
		local label = text({
			Name = "Title",
			Size = UDim2.new(1, -70, 1, 0),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody + 1,
			Text = title,
			Parent = header,
		})
		local ready = chip(header, "Ready", "✓ Ready", Theme.colors.good, Theme.colors.white)
		local changed =
			chip(header, "Changed", "Changed!", Theme.colors.gold, Theme.colors.goldText)
		local grid: Frame = Create("Frame", {
			Name = "Grid",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, HEADER_H + 4),
			Size = UDim2.fromOffset(gridW, gridW),
			Parent = frame,
		}, {
			Create("UIGridLayout", {
				CellSize = UDim2.fromOffset(tile, tile),
				CellPadding = UDim2.fromOffset(GRID_GAP, GRID_GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		local total = text({
			Name = "Total",
			Position = UDim2.fromOffset(0, HEADER_H + 4 + gridW + 4),
			Size = UDim2.new(1, 0, 0, 36),
			FontFace = Theme.fonts.bodyBold,
			TextSize = Theme.sizes.textSmall,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			Parent = frame,
		})
		return frame, label, ready, changed, grid, total
	end
	local columnW = math.max(COLUMN_W, gridW)
	local _mine, mineTitle, mineReady, mineChanged, mineGrid, mineTotal =
		column("Mine", 0, "You give")
	local _theirs, theirsTitle, theirsReady, theirsChanged, theirsGrid, theirsTotal =
		column("Theirs", columnW + 16, "They give")
	self._side = {
		me = {
			title = mineTitle,
			ready = mineReady,
			changed = mineChanged,
			total = mineTotal,
			tiles = {},
		},
		them = {
			title = theirsTitle,
			ready = theirsReady,
			changed = theirsChanged,
			total = theirsTotal,
			tiles = {},
		},
	}
	for index = 1, TradeLogic.MAX_CATS do
		table.insert(
			self._side.me.tiles,
			TradeTile.new({
				parent = mineGrid,
				size = tile,
				layoutOrder = index,
				name = "Slot" .. index,
				onClick = function()
					self:_pressMine(index)
				end,
			})
		)
		table.insert(
			self._side.them.tiles,
			TradeTile.new({
				parent = theirsGrid,
				size = tile,
				layoutOrder = index,
				name = "Slot" .. index,
			})
		)
	end
	-- your cats, on the right
	local picksX = 2 * (columnW + 16)
	local picks: Frame = Create("Frame", {
		Name = "Picks",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(picksX, 0),
		Size = UDim2.new(1, -picksX, 1, 0),
		Parent = offer,
	})
	text({
		Name = "Title",
		Size = UDim2.new(1, 0, 0, HEADER_H),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 1,
		Text = "Your cats",
		Parent = picks,
	})
	local scroll: ScrollingFrame = Create("ScrollingFrame", {
		Name = "List",
		BackgroundColor3 = Theme.modal.card,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, HEADER_H + 4),
		Size = UDim2.new(1, 0, 1, -(HEADER_H + 4 + 26)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.modal.subtext,
		Parent = picks,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }),
		Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(tile, tile),
			CellPadding = UDim2.fromOffset(5, 5),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 5),
			PaddingLeft = UDim.new(0, 5),
			PaddingRight = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 5),
		}),
	})
	self._picksList = scroll
	self._picksEmpty = text({
		Name = "Empty",
		Position = UDim2.fromOffset(0, HEADER_H + 20),
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.subtext,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		Text = "No cats to trade yet",
		Visible = false,
		Parent = picks,
	})
	self._hintLabel = text({
		Name = "Hint",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 22),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.subtext,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "Tap a cat to add it",
		Parent = picks,
	})
	-- the countdown, big over the two grids
	local count = text({
		Name = "Count",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(columnW + 8, HEADER_H + 4 + gridW / 2),
		Size = UDim2.fromOffset(120, 96),
		FontFace = Theme.fonts.display,
		TextSize = 80,
		TextColor3 = Theme.colors.gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		ZIndex = 9,
		Parent = offer,
	})
	Outline.text(count, 4)
	self._count = count
end

-- The confirm face: "You give" and "You get" as rows of cards with names, and the red warning line.
function Trade._buildConfirm(self: any, content: Frame)
	local confirm: Frame = Create("Frame", {
		Name = "Confirm",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -(self._buttonH + GAP)),
		Visible = false,
		Parent = content,
	})
	self._confirmFace = confirm
	local cardH = CONFIRM_TILE + 34
	local function row(name: string, y: number, title: string): (ScrollingFrame, TextLabel)
		text({
			Name = name .. "Title",
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, 0, 0, 22),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody + 1,
			Text = title,
			Parent = confirm,
		})
		local scroll: ScrollingFrame = Create("ScrollingFrame", {
			Name = name,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, y + 24),
			Size = UDim2.new(1, 0, 0, cardH + 8),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			ScrollingDirection = Enum.ScrollingDirection.X,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = Theme.modal.subtext,
			Parent = confirm,
		}, {
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		local nothing = text({
			Name = "Nothing",
			Position = UDim2.fromOffset(0, y + 24),
			Size = UDim2.new(1, 0, 0, cardH),
			TextColor3 = Theme.modal.subtext,
			Text = "Nothing",
			Visible = false,
			Parent = confirm,
		})
		return scroll, nothing
	end
	local give, giveNothing = row("Give", 0, "You give")
	local get, getNothing = row("Get", cardH + 36, "You get")
	self._confirmRows = {
		give = { scroll = give, nothing = giveNothing, cards = {} :: { ConfirmCard } },
		get = { scroll = get, nothing = getNothing, cards = {} :: { ConfirmCard } },
	}
	self._warning = text({
		Name = "Warning",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 24),
		FontFace = Theme.fonts.bodyBold,
		TextColor3 = Theme.colors.red,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		Parent = confirm,
	})
end

function Trade._confirmCard(_self: any, row: any, index: number): ConfirmCard
	local existing: ConfirmCard? = row.cards[index]
	if existing then
		return existing
	end
	local frame: Frame = Create("Frame", {
		Name = "Card" .. index,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(CONFIRM_TILE + 30, CONFIRM_TILE + 34), -- room for a name like "Garbage Bag Cat"
		LayoutOrder = index,
		Parent = row.scroll,
	})
	local holder: Frame = Create("Frame", {
		Name = "Picture",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(CONFIRM_TILE, CONFIRM_TILE),
		Parent = frame,
	})
	local tile = TradeTile.new({ parent = holder, size = CONFIRM_TILE })
	local name = text({
		Name = "CatName",
		Position = UDim2.fromOffset(0, CONFIRM_TILE + 2),
		Size = UDim2.new(1, 0, 0, 16),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textTiny,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = frame,
	})
	local rarity = text({
		Name = "Rarity",
		Position = UDim2.fromOffset(0, CONFIRM_TILE + 17),
		Size = UDim2.new(1, 0, 0, 15),
		TextSize = Theme.sizes.textTiny,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = frame,
	})
	local card: ConfirmCard = { tile = tile, frame = frame, name = name, rarity = rarity }
	row.cards[index] = card
	return card
end

function Trade.setCatalog(self: any, catalog: Types.Catalog)
	table.clear(self._catById)
	for _, def in catalog.cats do
		self._catById[def.id] = def
	end
	self:_renderAll()
end

function Trade.render(self: any, state: Types.PlayerState)
	self._state = state
	if self._open and self._trade ~= nil then
		self:_renderPicks()
	end
end

function Trade.trading(self: any): boolean
	return self._trade ~= nil
end

function Trade.setTrade(self: any, trade: Types.TradeState?)
	local before: Types.TradeState? = self._trade
	self._trade = trade
	self._pressed = nil
	if trade == nil then
		self._confirmSince = nil
		self._confirmKey = ""
	elseif before == nil or before.tradeId ~= trade.tradeId then
		self._hint = nil
	end
	self:_renderAll()
end

function Trade.opened(self: any)
	self._open = true
	self:_renderAll()
end

function Trade.closed(self: any)
	self._open = false
end

function Trade._close(self: any)
	local trade: Types.TradeState? = self._trade
	if trade then
		-- the X during a trade cancels it; the window closes when the server's nil TradeState comes
		self._callbacks.cancel(trade.tradeId)
		return
	end
	self._callbacks.close()
end

function Trade._renderAll(self: any)
	local trade: Types.TradeState? = self._trade
	local confirming = trade ~= nil and trade.phase == "confirm"
	self._playersFace.Visible = trade == nil
	self._offerFace.Visible = trade ~= nil and not confirming
	self._confirmFace.Visible = confirming
	self._buttons.Visible = trade ~= nil
	if trade ~= nil then
		local give, get = TradeLogic.totals(trade)
		self._side.me.total.Text = give
		self._side.them.total.Text = get
		self._side.them.total.TextColor3 = Theme.colors.goodDark
	end
	if trade == nil then
		self._panel:setTitle(TradeLogic.TITLE, "Swap cats with players in this server")
		self:_renderPlayers()
		return
	end
	if confirming then
		local key = trade.tradeId .. ":" .. trade.version
		if key ~= self._confirmKey then
			self._confirmKey = key
			self._confirmSince = os.clock()
		end
		self:_renderConfirm(trade)
	else
		self._confirmKey = ""
		self:_renderOffer(trade)
		self:_renderPicks()
	end
	self:_tick()
end

function Trade._renderPlayers(self: any)
	if not self._open then
		return
	end
	local minTier = TradeLogic.minTier(Workspace:GetAttribute("TradeMinTier"))
	local resting = Workspace:GetAttribute("TradingOn") == false
	local now = os.clock()
	local seen: { [number]: boolean } = {}
	local others: { Player } = {}
	for _, player in Players:GetPlayers() do
		if player ~= Players.LocalPlayer then
			table.insert(others, player)
		end
	end
	table.sort(others, function(a: Player, b: Player): boolean
		return a.DisplayName:lower() < b.DisplayName:lower()
	end)
	for index, player in others do
		local row = self:_row(player)
		seen[player.UserId] = true
		row.frame.LayoutOrder = index
		row.name.Text = player.DisplayName
		local tier = player:GetAttribute("Tier")
		row.tier.Text = if type(tier) == "number" then string.format("Tier %d", tier) else ""
		local view = TradeLogic.playerButton({
			tier = if type(tier) == "number" then tier else nil,
			trading = player:GetAttribute("Trading") == true,
			asked = (self._asked[player.UserId] or 0) > now,
		}, minTier)
		row.button:setText(view.text)
		row.button:setStyle(view.style)
		row.button:setEnabled(view.enabled and not resting)
	end
	for userId, row in self._rows do
		if not seen[userId] then
			row.button:destroy()
			row.frame:Destroy()
			self._rows[userId] = nil
		end
	end
	self._empty.Visible = #others == 0
	self._rule.Text = if resting
		then "Trading is resting for now. Try again later!"
		else "Cats only. Locked cats stay home until you unlock them on their card."
	self._rule.TextColor3 = if resting then Theme.colors.red else Theme.modal.subtext
end

local function tileView(self: any, tile: Types.TradeTile, good: boolean): TradeTile.View?
	local def: Types.CatDef? = self._catById[tile.catId]
	if def == nil then
		return nil
	end
	return {
		def = def,
		variant = tile.variant,
		level = tile.level,
		rate = TradeLogic.rate(tile.rateForMe, good),
		good = good,
	}
end

function Trade._renderOffer(self: any, trade: Types.TradeState)
	for _, key in { "me", "them" } do
		local side = self._side[key]
		local data: Types.TradeSide = if key == "me" then trade.me else trade.them
		side.title.Text = if key == "me" then "You give" else string.format("%s gives", data.name)
		side.ready.Visible = data.ready
		for index, tile in side.tiles do
			local cat: Types.TradeTile? = data.cats[index]
			tile:set(if cat then tileView(self, cat, key == "them") else nil)
		end
	end
	local ready = TradeLogic.readyButton(trade)
	self._go:setText(ready.text)
	self._go:setStyle(ready.style)
	self._go:setEnabled(ready.enabled and self._pressed == nil)
	self._cancel:setText("Cancel")
end

function Trade._offered(self: any): { [string]: boolean }
	local offered: { [string]: boolean } = {}
	local trade: Types.TradeState? = self._trade
	if trade then
		for _, tile in trade.me.cats do
			offered[tile.uid] = true
		end
	end
	return offered
end

function Trade._renderPicks(self: any)
	local trade: Types.TradeState? = self._trade
	if trade == nil then
		return
	end
	local state: Types.PlayerState? = self._state
	local defOf = function(catId: string): any
		return self._catById[catId]
	end
	local picks =
		TradeLogic.myCats(if state then state.cats :: any else nil, defOf, self:_offered())
	self._picks = picks
	local seen: { [string]: boolean } = {}
	for index, pick in picks do
		seen[pick.uid] = true
		local tile: TradeTile.TradeTile? = self._pickTiles[pick.uid]
		if tile == nil then
			local uid = pick.uid
			local made = TradeTile.new({
				parent = self._picksList,
				size = self._tile,
				name = "Cat",
				onClick = function()
					self:_pressPick(uid)
				end,
			})
			self._pickTiles[uid] = made
			tile = made
		end
		local shown = tile :: TradeTile.TradeTile
		shown.frame.LayoutOrder = index
		local def: Types.CatDef? = self._catById[pick.catId]
		if def then
			shown:set({
				def = def,
				variant = pick.variant,
				level = pick.level,
				rate = TradeLogic.rate(pick.rating, false),
				status = if pick.status == "offered"
					then "offered"
					elseif pick.status == "ok" then nil
					else "locked",
			})
		end
	end
	for uid, tile in self._pickTiles do
		if not seen[uid] then
			tile:destroy()
			self._pickTiles[uid] = nil
		end
	end
	self._picksEmpty.Visible = #picks == 0
end

function Trade._renderConfirm(self: any, trade: Types.TradeState)
	self._panel:setTitle(
		string.format("Trade with %s", trade.them.name),
		TradeLogic.headline(trade, 0)
	)
	for _, key in { "give", "get" } do
		local row = self._confirmRows[key]
		local cats: { Types.TradeTile } = if key == "give" then trade.me.cats else trade.them.cats
		for index, cat in cats do
			local card = self:_confirmCard(row, index)
			card.frame.Visible = true
			local def: Types.CatDef? = self._catById[cat.catId]
			card.tile:set(if def then tileView(self, cat, key == "get") else nil)
			card.name.Text = if def then def.name else cat.catId
			card.rarity.Text = (
				if cat.variant == "rainbow"
					then "Rainbow "
					elseif cat.variant == "gold" then "Gold "
					else ""
			) .. cat.rarity
			card.rarity.TextColor3 = Theme.rarityTextColor(cat.rarity)
		end
		for index = #cats + 1, #row.cards do
			row.cards[index].frame.Visible = false
		end
		row.nothing.Visible = #cats == 0
		row.nothing.TextColor3 = if key == "get" and #cats == 0
			then Theme.colors.red
			else Theme.modal.subtext
	end
	local warning = TradeLogic.warning(trade)
	self._warning.Text = warning or ""
	self._warning.Visible = warning ~= nil
end

-- Moves on what changes with time: the subtitle, the countdown, the "Changed!" flash, the confirm wait, the hint.
function Trade._tick(self: any)
	local trade: Types.TradeState? = self._trade
	if trade == nil then
		self:_renderPlayers()
		return
	end
	local now = Workspace:GetServerTimeNow()
	local pressed: number? = self._pressed
	if pressed and os.clock() - pressed > PRESS_HOLD then
		self._pressed = nil
		pressed = nil
	end
	self._panel:setTitle(
		string.format("Trade with %s", trade.them.name),
		TradeLogic.headline(trade, now)
	)
	if trade.phase == "confirm" then
		local view =
			TradeLogic.confirmButton(trade, os.clock() - (self._confirmSince or os.clock()))
		self._go:setText(view.text)
		self._go:setStyle(view.style)
		self._go:setEnabled(view.enabled and pressed == nil)
		return
	end
	local count = TradeLogic.countdown(trade, now)
	self._count.Visible = count ~= nil
	self._count.Text = if count then tostring(count) else ""
	local changed = TradeLogic.changed(trade, now)
	for _, key in { "me", "them" } do
		self._side[key].changed.Visible = changed ~= nil and changed.side == key
		self._side[key].ready.Visible = (changed == nil or changed.side ~= key)
			and (if key == "me" then trade.me.ready else trade.them.ready)
	end
	local flashKey = if changed
		then trade.version .. ":" .. changed.side .. ":" .. changed.uid
		else ""
	if flashKey ~= self._flashKey then
		self._flashKey = flashKey
		if changed then
			local data: Types.TradeSide = if changed.side == "me" then trade.me else trade.them
			for index, cat in data.cats do
				if cat.uid == changed.uid then
					self._side[changed.side].tiles[index]:flash()
				end
			end
		end
	end
	local hint: string? = if os.clock() < self._hintUntil then self._hint else nil
	self._hintLabel.Text = hint
		or (
			if #trade.me.cats >= TradeLogic.MAX_CATS
				then "Your offer is full"
				else "Tap a cat to add it"
		)
	self._hintLabel.TextColor3 = if hint then Theme.colors.warnDark else Theme.modal.subtext
end

function Trade._pressGo(self: any)
	local trade: Types.TradeState? = self._trade
	if trade == nil or self._pressed ~= nil then
		return
	end
	self._pressed = os.clock()
	self._go:setEnabled(false)
	if trade.phase == "confirm" then
		self._callbacks.confirm(trade.tradeId, trade.version)
	else
		local ready = TradeLogic.readyButton(trade)
		self._callbacks.ready(trade.tradeId, trade.version, ready.text == "Ready")
	end
end

function Trade._pressMine(self: any, index: number)
	local trade: Types.TradeState? = self._trade
	if trade == nil or trade.phase == "confirm" then
		return
	end
	local cat = trade.me.cats[index]
	if cat then
		self._callbacks.offer(trade.tradeId, "remove", cat.uid)
	end
end

function Trade._pressPick(self: any, uid: string)
	local trade: Types.TradeState? = self._trade
	if trade == nil or trade.phase == "confirm" then
		return
	end
	for _, pick in self._picks do
		if pick.uid == uid then
			local hint = TradeLogic.pickHint(pick, #trade.me.cats >= TradeLogic.MAX_CATS)
			if hint then
				self._hint = hint
				self._hintUntil = os.clock() + 3
				local tile: TradeTile.TradeTile? = self._pickTiles[uid]
				if tile then
					tile.frame.Rotation = -6
					Tween.to(
						tile.frame,
						TweenInfo.new(0.45, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
						{ Rotation = 0 }
					)
				end
				self:_tick()
			else
				self._callbacks.offer(
					trade.tradeId,
					if pick.status == "offered" then "remove" else "add",
					uid
				)
			end
			return
		end
	end
end

function Trade.destroy(self: any)
	self._alive = false
	for _, tile in self._pickTiles do
		tile:destroy()
	end
	self._panel:destroy()
end

return Trade
