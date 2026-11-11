--!strict
-- The Trade window (F102, trading.md sections 2 and 3), modal "Trade", opened by the HUD's Trade tile and by the
-- server once a trade starts. It has two faces:
--   * the players in this server, each with their head, display name and Trade (Asked after a press until the ask is
--     declined or runs out, then REASK_SECONDS more, #2550; Busy while they trade, "Tier 3 needed" under the
--     minimum, all off while trading rests). Trade fires callbacks.request(userId); the other player gets the request card (UI.trade.asked) and the server's
--     TradeState opens the window for both.
--   * the trade itself while a TradeState is held. Offer: "You give" and "Sam gives" as two 3 x 3 grids, each with a
--     green "✓ Ready" chip and its earnings under it ("Your cats: $180/s now", "Their cats: +$240/s in your cafe"),
--     and your cats on the right, rarest first: a press adds one to your offer (or takes it back), a locked cat says
--     "Unlock it on its card to trade". A press on a cat in your grid takes it back. Any change flashes that tile
--     yellow and shows "Changed!" over its side for 2 s (the server clears both Ready). Ready, then a big countdown
--     over the grids while both are ready; Not ready stops it. Confirm: "You give" and "You get" as rows of bigger
--     cards with their names and rarities, a red line for a gift or a lopsided trade (Confirm waits 2 s then), Cancel
--     and Confirm. The words are Components/TradeLogic's; the server decides everything, and this only asks.
--   * #1574 (section 1b): Cats and Decor tabs over the list on the right. Decor lists your crate decor and lawn
--     pieces (Components/TradeItemTile): a press adds one (or takes it back); a locked one says "Unlock it on its card
--     to trade", one the other player owns is greyed with "They already have this". Pieces on offer follow the cats
--     in both grids (each scrolls past 9) and on the confirm face, with their rarity and tip bonus.
--   * #2745 (section 1c): a Crates tab beside them while the server's cratesOn says so: your banked crates (never a
--     golden one) with "x3" banked. A tap adds one; a long press opens a picker from 1 to what you can add, which
--     sends the difference. One the other player can't open yet is greyed with the server's reason. Crates on offer
--     follow the pieces with their count; a tap on yours takes one back.
--   * #2745 (section 1d): golden fish while the server's fishOn says so, as one 🐟 card in each grid after the
--     crates (yours shows "Add" at 0). A press on yours opens the same picker as an amount: − and +, 10, 50 and Max
--     (within your wallet, TradeMaxFish and the other player's room today, said under the title), sent as one "set".
--     The design (trading.md 1d) has a row under each grid; a phone has about 37 px there, under a 44 px tap, so the
--     amount sits in the grid like a crate and its controls in the picker. The confirm face shows it after the crates.
-- Cancel (or the X) fires callbacks.cancel(tradeId) during a trade; the window closes when TradeState goes nil.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local Scale = require(script.Parent.Parent.Scale)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local Theme = require(script.Parent.Parent.Theme)
local TradeItemTile = require(script.Parent.Parent.Components.TradeItemTile)
local TradeLogic = require(script.Parent.Parent.Components.TradeLogic)
local TradeTile = require(script.Parent.Parent.Components.TradeTile)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

-- the shared trade rules: which pieces can be traded, their names, rarities and bonuses (#1574)
local SharedTrade = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Trade")) :: any

-- the dark window palette (#1028), in place of Theme.modal
local PAL = Theme.dark

export type Callbacks = {
	close: () -> (),
	request: (userId: number) -> (),
	-- `kind` "decor" offers a piece id instead of a cat uid (#1574), "crate" `count` of a crate id (#2745); nil is a cat
	offer: (
		tradeId: string,
		action: "add" | "remove" | "set", -- "set" is for fish only (#2745)
		uid: string,
		kind: ("decor" | "crate" | "fish")?,
		count: number?
	) -> (),
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
	-- #2550: the server's TradeAskEnded for this player's ask to userId
	askEnded: (self: Trade, userId: number, now: boolean?) -> (),
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
type PieceCard = {
	tile: TradeItemTile.TradeItemTile,
	frame: Frame,
	name: TextLabel,
	rarity: TextLabel,
}

type Tab = "cats" | "decor" | "crates"
local TABS: { { id: Tab, label: string } } = {
	{ id = "cats", label = "Cats" },
	{ id = "decor", label = "Decor" },
	{ id = "crates", label = "Crates" }, -- #2745: shown while the server's cratesOn says so
}
local TAB_W = 70
local PIECE_ORDER = 100 -- pieces follow the cats in a grid or a confirm row
local CRATE_ORDER = 150 -- #2745: crates follow the pieces
local FISH_ORDER = 190 -- #2745: then the golden fish
local SLOT_ORDER = 200 -- and the empty slots follow them all
local FISH = "fish" -- #2745: the picker's key and the uid TradeOffer takes for golden fish

local MAX_SIZE = Vector2.new(760, 420)
local GRID_GAP = 6
local CONFIRM_TILE = 60
local CONFIRM_TITLE_W = 76 -- "You give" beside its row on the confirm face
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
	self._pieceTiles = {} :: { [string]: TradeItemTile.TradeItemTile } -- #1574: the Decor tab's pieces by id
	self._pieces = {} :: { TradeLogic.PiecePick }
	self._tab = "cats" :: Tab
	self._tabH = Scale.tapHeight(36) -- taller than the grids' titles: a full tap with a mouse or a thumb
	self._tabButtons = {} :: { [Tab]: TextButton }
	self._crateById = {} :: { [string]: TradeLogic.CrateInfo } -- #2745: Catalog.crates by id
	self._crateTiles = {} :: { [string]: TradeItemTile.TradeItemTile } -- the Crates tab's kinds by id
	self._crates = {} :: { TradeLogic.CratePick }
	self._pickerFor = nil :: string? -- the crate id the count picker is open for, or FISH (#2745)
	self._pickerCount = 1
	self._pickerMin = 1 -- 0 for fish (#2745)
	self._pickerMax = 1
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
		dark = true, -- #1028
		name = "Trade",
		title = TradeLogic.TITLE,
		subtitle = "Swap cats with players in this server",
		color = Theme.colors.mintDark,
		icon = TradeLogic.ICON,
		image = ShopIcons.clean("Trade"), -- #2836: the drawn badge (the emoji until it loads)
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
		ScrollBarImageColor3 = PAL.subtext,
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
		TextColor3 = PAL.subtext,
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
		TextColor3 = PAL.subtext,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		Text = "Locked cats can't be traded.",
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
		BackgroundColor3 = PAL.card,
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
		TextColor3 = PAL.subtext,
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
			-- #2550: Asked while the request is open; askEnded shortens it once it is declined or runs out
			self._asked[userId] = os.clock() + TradeLogic.REQUEST_SECONDS + TradeLogic.REASK_SECONDS
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
	local tabH = self._tabH
	local gridW = 3 * tile + 2 * GRID_GAP
	local function column(
		name: string,
		x: number,
		title: string
	): (Frame, TextLabel, TextLabel, TextLabel, ScrollingFrame, TextLabel)
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
		-- #1574: the cats, then the pieces; past 9 it scrolls. It reaches Outline.ROOM past the cards on every side
		-- and pads them back, so the cards sit where they did with their edges whole (#2294).
		local room = Outline.ROOM
		local grid: ScrollingFrame = Create("ScrollingFrame", {
			Name = "Grid",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, HEADER_H + 4 - room),
			Size = UDim2.fromOffset(gridW + 2 * room, gridW + 2 * room),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = PAL.subtext,
			Parent = frame,
		}, {
			Create("UIGridLayout", {
				CellSize = UDim2.fromOffset(tile, tile),
				CellPadding = UDim2.fromOffset(GRID_GAP, GRID_GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Create("UIPadding", {
				PaddingLeft = UDim.new(0, room),
				PaddingRight = UDim.new(0, room),
				PaddingTop = UDim.new(0, room),
				PaddingBottom = UDim.new(0, room),
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
			grid = mineGrid,
			pieces = {} :: { TradeItemTile.TradeItemTile },
			crates = {} :: { TradeItemTile.TradeItemTile },
		},
		them = {
			title = theirsTitle,
			ready = theirsReady,
			changed = theirsChanged,
			total = theirsTotal,
			tiles = {},
			grid = theirsGrid,
			pieces = {} :: { TradeItemTile.TradeItemTile },
			crates = {} :: { TradeItemTile.TradeItemTile },
		},
	}
	-- #2745: each side's golden fish card, after the crates; yours opens the picker
	self._side.me.fish = TradeItemTile.new({
		parent = mineGrid,
		size = tile,
		layoutOrder = FISH_ORDER,
		name = "Fish",
		onClick = function()
			self:_openFishPicker()
		end,
	})
	self._side.them.fish = TradeItemTile.new({
		parent = theirsGrid,
		size = tile,
		layoutOrder = FISH_ORDER,
		name = "Fish",
	})
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
	-- #1574: Cats and Decor tabs over the list
	local tabs: Frame = Create("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, tabH),
		Parent = picks,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for order, tab in TABS do
		local id = tab.id
		local button: TextButton = Create("TextButton", {
			Name = tab.label,
			AutoButtonColor = false,
			BackgroundColor3 = PAL.card,
			BorderSizePixel = 0,
			Size = UDim2.new(0, TAB_W, 1, 0),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody,
			TextColor3 = PAL.text,
			Text = tab.label,
			LayoutOrder = order,
			Visible = id ~= "crates", -- #2745: until a TradeState says cratesOn
			Parent = tabs,
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		button.Activated:Connect(function()
			self:_setTab(id)
		end)
		self._tabButtons[id] = button
	end
	local scroll: ScrollingFrame = Create("ScrollingFrame", {
		Name = "List",
		BackgroundColor3 = PAL.card,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, tabH + 4),
		Size = UDim2.new(1, 0, 1, -(tabH + 4 + 26)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = PAL.subtext,
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
		Position = UDim2.fromOffset(0, tabH + 20),
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
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
		TextColor3 = PAL.subtext,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "Tap a cat to add it",
		Parent = picks,
	})
	self:_buildPicker(picks)
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

-- #2745: the Crates tab's count picker, over the foot of the list after a long press on a crate: its name, − n +,
-- and Cancel and Done. Done sends the difference from what is on offer now.
function Trade._buildPicker(self: any, picks: Frame)
	local buttonH = Scale.tapHeight(36, Theme.sizes.buttonDepth)
	self._pickerButtonH = buttonH
	local picker: Frame = Create("Frame", {
		Name = "CratePicker",
		BackgroundColor3 = PAL.panel,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 22 + 2 * buttonH + 3 * GAP),
		Visible = false,
		ZIndex = 10,
		Parent = picks,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }),
		Create("UIStroke", { Color = Theme.colors.gold, Thickness = Theme.sizes.stroke }),
	})
	self._picker = picker
	self._pickerTitle = text({
		Name = "Title",
		Position = UDim2.fromOffset(GAP, 2),
		Size = UDim2.new(1, -2 * GAP, 0, 20),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 11,
		Parent = picker,
	})
	-- #2745: the fish picker's line under the title, the other player's room today
	self._pickerRoom = text({
		Name = "Room",
		Position = UDim2.fromOffset(GAP, 20),
		Size = UDim2.new(1, -2 * GAP, 0, 16),
		TextSize = Theme.sizes.textTiny,
		TextColor3 = PAL.subtext,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		ZIndex = 11,
		Parent = picker,
	})
	local function button(
		name: string,
		label: string,
		style: any,
		x: UDim,
		w: UDim,
		onClick: () -> ()
	)
		return Button.new({
			name = name,
			text = label,
			style = style,
			position = UDim2.new(x.Scale, x.Offset, 0, 0),
			size = UDim2.new(w.Scale, w.Offset, 0, buttonH),
			textSize = Theme.sizes.textBody,
			zIndex = 12,
			parent = picker,
			onClick = onClick,
		})
	end
	local third = UDim.new(1 / 3, -GAP)
	self._pickerLess = button("Less", "−", "ghost", UDim.new(0, GAP / 2), third, function()
		self:_pickerStep(-1)
	end)
	self._pickerCountLabel = text({
		Name = "Count",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.new(1 / 3, -GAP, 0, buttonH),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 4,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 11,
		Parent = picker,
	})
	self._pickerMore = button("More", "+", "ghost", UDim.new(2 / 3, GAP / 2), third, function()
		self:_pickerStep(1)
	end)
	-- #2745: the fish picker's quick amounts
	self._pickerQuick = {}
	for index, quick in { 10, 50, "max" } :: { number | "max" } do
		local label = if quick == "max" then "Max" else tostring(quick)
		table.insert(
			self._pickerQuick,
			button(
				"Quick" .. label,
				label,
				"secondary",
				UDim.new((index - 1) / 3, GAP / 2),
				third,
				function()
					self:_pickerQuickPress(quick)
				end
			)
		)
	end
	local half = UDim.new(0.5, -GAP * 1.5)
	self._pickerClose = button("Close", "Cancel", "ghost", UDim.new(0, GAP), half, function()
		self:_closePicker()
	end)
	self._pickerDoneButton = button(
		"Done",
		"Done",
		"primary",
		UDim.new(0.5, GAP / 2),
		half,
		function()
			self:_pickerDone()
		end
	)
	self:_layoutPicker(false)
end

-- #2745: the picker's rows: − n +, then Cancel and Done; the fish picker adds the room line and 10, 50 and Max.
function Trade._layoutPicker(self: any, fish: boolean)
	local buttonH: number = self._pickerButtonH
	local y = if fish then 22 + 16 else 22 + GAP
	local function place(button: any, rowY: number)
		local frame: Frame = button.instance
		frame.Position = UDim2.new(frame.Position.X.Scale, frame.Position.X.Offset, 0, rowY)
	end
	place(self._pickerLess, y)
	place(self._pickerMore, y)
	local count: TextLabel = self._pickerCountLabel
	count.Position = UDim2.new(0.5, 0, 0, y)
	y += buttonH + GAP
	self._pickerRoom.Visible = fish
	for _, quick in self._pickerQuick do
		quick.instance.Visible = fish
		place(quick, y)
	end
	if fish then
		y += buttonH + GAP
	end
	place(self._pickerClose, y)
	place(self._pickerDoneButton, y)
	local picker: Frame = self._picker
	picker.Size = UDim2.new(1, 0, 0, y + buttonH + GAP)
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
	-- each row's title sits on its left, so both rows and the red line fit the phone's short panel
	local function row(name: string, y: number, title: string): (ScrollingFrame, TextLabel)
		text({
			Name = name .. "Title",
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.fromOffset(CONFIRM_TITLE_W - GAP, cardH),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody + 1,
			TextWrapped = true,
			Text = title,
			Parent = confirm,
		})
		-- #2294: the strip reaches Outline.ROOM past the cards at the left and top and pads them back, so the cards
		-- sit where they did with their rings whole
		local room = Outline.ROOM
		local scroll: ScrollingFrame = Create("ScrollingFrame", {
			Name = name,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(CONFIRM_TITLE_W - room, y - room),
			Size = UDim2.new(1, -CONFIRM_TITLE_W + room, 0, cardH + 8 + room),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			ScrollingDirection = Enum.ScrollingDirection.X,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = PAL.subtext,
			Parent = confirm,
		}, {
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Create(
				"UIPadding",
				{ PaddingLeft = UDim.new(0, room), PaddingTop = UDim.new(0, room) }
			),
		})
		local nothing = text({
			Name = "Nothing",
			Position = UDim2.fromOffset(CONFIRM_TITLE_W, y),
			Size = UDim2.new(1, -CONFIRM_TITLE_W, 0, cardH),
			TextColor3 = PAL.subtext,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "Nothing",
			Visible = false,
			Parent = confirm,
		})
		return scroll, nothing
	end
	local give, giveNothing = row("Give", 0, "You give")
	local get, getNothing = row("Get", cardH + 12, "You get")
	self._confirmRows = {
		give = {
			scroll = give,
			nothing = giveNothing,
			cards = {} :: { ConfirmCard },
			pieces = {} :: { PieceCard },
			crates = {} :: { PieceCard },
		},
		get = {
			scroll = get,
			nothing = getNothing,
			cards = {} :: { ConfirmCard },
			pieces = {} :: { PieceCard },
			crates = {} :: { PieceCard },
		},
	}
	self._warning = text({
		Name = "Warning",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 24),
		FontFace = Theme.fonts.bodyBold,
		TextColor3 = PAL.red,
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
		TextTruncate = Enum.TextTruncate.AtEnd,
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

-- #1574: a piece's card on the confirm face, after the cats: its picture, name, and rarity with its bonus.
function Trade._pieceCard(_self: any, row: any, index: number): PieceCard
	local existing: PieceCard? = row.pieces[index]
	if existing then
		return existing
	end
	local frame: Frame = Create("Frame", {
		Name = "Piece" .. index,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(CONFIRM_TILE + 30, CONFIRM_TILE + 34),
		LayoutOrder = PIECE_ORDER + index,
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
	local tile = TradeItemTile.new({ parent = holder, size = CONFIRM_TILE })
	local name = text({
		Name = "PieceName",
		Position = UDim2.fromOffset(0, CONFIRM_TILE + 2),
		Size = UDim2.new(1, 0, 0, 16),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textTiny,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})
	local rarity = text({
		Name = "Rarity",
		Position = UDim2.fromOffset(0, CONFIRM_TILE + 17),
		Size = UDim2.new(1, 0, 0, 15),
		TextSize = Theme.sizes.textTiny,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextScaled = true, -- "Uncommon · +2%" fits the card
		Parent = frame,
	})
	Create("UITextSizeConstraint", { MaxTextSize = Theme.sizes.textTiny, Parent = rarity })
	local card: PieceCard = { tile = tile, frame = frame, name = name, rarity = rarity }
	row.pieces[index] = card
	return card
end

-- #1574: what a piece on offer shows (TradeDecorTile from the server).
local function pieceView(
	piece: Types.TradeDecorTile,
	status: ("locked" | "offered" | "theyHave")?
): TradeItemTile.View
	return {
		id = piece.id,
		name = piece.name,
		rarity = piece.rarity,
		image = ShopIcons.decor(piece.id),
		badge = if piece.kind == "lawn" then "Lawn" else nil,
		foot = TradeLogic.bonusText(piece.bonus),
		status = status,
	}
end

-- #1574: the light colour of a piece's rarity on a dark card, the lawn's rungs too.
local function pieceLight(rarity: string): Color3
	return TradeItemTile.color(rarity):Lerp(Theme.colors.white, 0.25)
end

-- #2745: a crate kind's card on the confirm face, after the pieces (a PieceCard in its own list).
function Trade._crateCard(self: any, row: any, index: number): PieceCard
	local existing: PieceCard? = row.crates[index]
	if existing then
		return existing
	end
	local holder = { pieces = row.crates, scroll = row.scroll }
	local card = self:_pieceCard(holder, index)
	card.frame.Name = "Crate" .. index
	card.frame.LayoutOrder = CRATE_ORDER + index
	return card
end

-- #2745 (section 1d): a confirm row's golden fish card (a PieceCard of its own), made on first use.
function Trade._fishCard(self: any, row: any): PieceCard
	local existing: PieceCard? = row.fish
	if existing then
		return existing
	end
	local holder = { pieces = {}, scroll = row.scroll }
	local card = self:_pieceCard(holder, 1)
	card.frame.Name = "Fish"
	card.frame.LayoutOrder = FISH_ORDER
	row.fish = card
	return card
end

-- #2745: one side's crates (TradeCrateTile: id, name, area, count), {} before the server sends them.
local function cratesOf(side: any): { any }
	return if type(side) == "table" and type(side.crates) == "table" then side.crates else {}
end

-- #2745 (section 1d): the golden fish card: the fish picture with the amount at its foot, gold once there are some,
-- "Add" on a plain card at 0.
local function fishView(fish: number): TradeItemTile.View
	return {
		id = FISH,
		name = "Golden fish",
		rarity = if fish > 0 then "Golden" else "Common",
		image = Theme.textures.fishCoin,
		foot = if fish > 0 then tostring(fish) else "Add",
	}
end

-- #2745: what a crate kind on offer shows: its picture, name and "x3".
local function crateView(crate: any, status: ("offered" | "blocked")?): TradeItemTile.View
	return {
		id = crate.id,
		name = crate.name,
		rarity = "Common",
		image = ShopIcons.crate(crate.id),
		badge = TradeLogic.countText(crate.count),
		status = status,
	}
end

function Trade.setCatalog(self: any, catalog: Types.Catalog)
	table.clear(self._catById)
	for _, def in catalog.cats do
		self._catById[def.id] = def
	end
	table.clear(self._crateById)
	local crates: { Types.CrateDef } = catalog.crates or {}
	for order, def in crates do
		self._crateById[def.id] = { name = def.name, golden = def.golden, order = order }
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
		self._tab = "cats" -- a new trade opens on Cats
		table.clear(self._asked) -- #3211: a trade opened, so no ask is out; the list says Trade again after it
	end
	if trade == nil or trade.phase ~= "offer" then
		self:_closePicker() -- #2745: no count picker past the offer
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
		self._side.them.total.TextColor3 = PAL.good
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
		else "Locked cats can't be traded."
	self._rule.TextColor3 = if resting then PAL.red else PAL.subtext
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
		-- #1574: the cats, then the pieces, then (#2745) the crates, then empty slots up to 9
		local decor: { Types.TradeDecorTile } = data.decor or {}
		local crates = cratesOf(data)
		-- #2745: the fish card, always on your side while fishOn (to add some), on theirs when they offer some
		local fish = TradeLogic.fishOf(data)
		local fishShown = (trade :: any).fishOn == true and (key == "me" or fish > 0)
		side.fish:set(if fishShown then fishView(fish) else nil)
		local slots = math.max(
			0,
			TradeLogic.MAX_CATS - #data.cats - #decor - #crates - (if fishShown then 1 else 0)
		)
		for index, tile in side.tiles do
			local cat: Types.TradeTile? = data.cats[index]
			tile:set(if cat then tileView(self, cat, key == "them") else nil)
			tile.frame.LayoutOrder = if cat then index else SLOT_ORDER + index
			tile.frame.Visible = cat ~= nil or index - #data.cats <= slots
		end
		for index, piece in decor do
			local made: TradeItemTile.TradeItemTile? = side.pieces[index]
			if made == nil then
				made = TradeItemTile.new({
					parent = side.grid,
					size = self._tile,
					layoutOrder = PIECE_ORDER + index,
					name = "Piece" .. index,
					onClick = if key == "me"
						then function()
							self:_pressMinePiece(index)
						end
						else nil,
				})
				side.pieces[index] = made
			end
			(made :: TradeItemTile.TradeItemTile):set(pieceView(piece, nil))
		end
		for index = #decor + 1, #side.pieces do
			side.pieces[index]:set(nil)
		end
		for index, crate in crates do
			local made: TradeItemTile.TradeItemTile? = side.crates[index]
			if made == nil then
				made = TradeItemTile.new({
					parent = side.grid,
					size = self._tile,
					layoutOrder = CRATE_ORDER + index,
					name = "Crate" .. index,
					onClick = if key == "me"
						then function()
							self:_pressMineCrate(index)
						end
						else nil,
				})
				side.crates[index] = made
			end
			(made :: TradeItemTile.TradeItemTile):set(crateView(crate, nil))
		end
		for index = #crates + 1, #side.crates do
			side.crates[index]:set(nil)
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

-- #1574: the piece ids on my side.
function Trade._offeredPieces(self: any): { [string]: boolean }
	local offered: { [string]: boolean } = {}
	local trade: Types.TradeState? = self._trade
	if trade then
		local decor: { Types.TradeDecorTile } = trade.me.decor or {}
		for _, piece in decor do
			offered[piece.id] = true
		end
	end
	return offered
end

-- #1574: Cats or Decor over the list on the right.
function Trade._setTab(self: any, tab: Tab)
	if self._tab == tab then
		return
	end
	self._tab = tab
	self._hint = nil
	self:_closePicker()
	self._picksList.CanvasPosition = Vector2.zero
	self:_renderPicks()
	self:_tick()
end

-- #1574: the Decor tab's pieces: every owned crate decor and lawn piece that can be traded.
function Trade._renderPieces(self: any, show: boolean): number
	local trade: Types.TradeState? = self._trade
	local state: Types.PlayerState? = self._state
	local pieces: { TradeLogic.PiecePick } = {}
	if show and trade ~= nil and state ~= nil then
		-- the crate decor and the lawn pieces owned, in one map
		local owned: { [string]: boolean } = table.clone(state.decorOwned or {})
		local lawnOwned: { [string]: boolean } = state.lawnOwned or {}
		for id, yes in lawnOwned do
			owned[id] = yes
		end
		pieces = TradeLogic.myPieces(
			owned,
			state.decorUnlocked,
			SharedTrade.piece,
			self:_offeredPieces(),
			trade.theyHave
		)
	end
	self._pieces = pieces
	local seen: { [string]: boolean } = {}
	for index, pick in pieces do
		seen[pick.id] = true
		local tile: TradeItemTile.TradeItemTile? = self._pieceTiles[pick.id]
		if tile == nil then
			local id = pick.id
			local made = TradeItemTile.new({
				parent = self._picksList,
				size = self._tile,
				name = "Piece",
				onClick = function()
					self:_pressPiece(id)
				end,
			})
			self._pieceTiles[id] = made
			tile = made
		end
		local shown = tile :: TradeItemTile.TradeItemTile
		shown.frame.LayoutOrder = index
		shown:set({
			id = pick.id,
			name = pick.name,
			rarity = pick.rarity,
			image = ShopIcons.decor(pick.id),
			badge = if pick.kind == "lawn" then "Lawn" else nil,
			foot = TradeLogic.bonusText(pick.bonus),
			status = if pick.status == "ok" then nil else pick.status,
		})
	end
	for id, tile in self._pieceTiles do
		if not seen[id] then
			tile:destroy()
			self._pieceTiles[id] = nil
		end
	end
	return #pieces
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
	-- #2745: the Crates tab only while the server's cratesOn says so
	local cratesOn = (trade :: any).cratesOn == true
	if self._tab == "crates" and not cratesOn then
		self._tab = "cats"
		self:_closePicker()
	end
	if self._pickerFor == FISH and (trade :: any).fishOn ~= true then
		self:_closePicker() -- #2745: fish switched off mid-trade
	end
	local catsTab = self._tab == "cats"
	for id, button in self._tabButtons do
		local on = id == self._tab
		button.Visible = id ~= "crates" or cratesOn
		button.BackgroundColor3 = if on then Theme.colors.mintDark else PAL.card
		button.TextColor3 = if on then Theme.colors.white else PAL.subtext
	end
	local picks: { TradeLogic.Pick } = if catsTab
		then TradeLogic.myCats(if state then state.cats :: any else nil, defOf, self:_offered())
		else {}
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
	local pieces = self:_renderPieces(self._tab == "decor")
	local crates = self:_renderCrates(self._tab == "crates")
	self._picksEmpty.Text = if catsTab
		then "No cats to trade yet"
		elseif self._tab == "decor" then "No decor to trade yet"
		else "No crates to trade yet"
	self._picksEmpty.Visible = if catsTab
		then #picks == 0
		elseif self._tab == "decor" then pieces == 0
		else crates == 0
end

-- #2745: the crate ids on my side and how many of each.
function Trade._offeredCrates(self: any): { [string]: number }
	local offered: { [string]: number } = {}
	local trade: Types.TradeState? = self._trade
	if trade then
		for _, crate in cratesOf(trade.me) do
			offered[crate.id] = crate.count
		end
	end
	return offered
end

-- #2745: the Crates tab: your banked crates that can be traded, "x3" banked, greyed when the other player can't take
-- them yet, ticked once every one is on offer.
function Trade._renderCrates(self: any, show: boolean): number
	local trade: Types.TradeState? = self._trade
	local state: Types.PlayerState? = self._state
	local crates: { TradeLogic.CratePick } = {}
	if show and trade ~= nil and state ~= nil then
		crates = TradeLogic.myCrates(state.crates, function(id: string): TradeLogic.CrateInfo?
			return self._crateById[id]
		end, self:_offeredCrates(), (trade :: any).crateBlocked)
	end
	self._crates = crates
	local seen: { [string]: boolean } = {}
	for index, pick in crates do
		seen[pick.id] = true
		local tile: TradeItemTile.TradeItemTile? = self._crateTiles[pick.id]
		if tile == nil then
			local id = pick.id
			local made = TradeItemTile.new({
				parent = self._picksList,
				size = self._tile,
				name = "Crate",
				onClick = function()
					self:_pressCrate(id)
				end,
				onHold = function()
					self:_openPicker(id)
				end,
			})
			self._crateTiles[id] = made
			tile = made
		end
		local shown = tile :: TradeItemTile.TradeItemTile
		shown.frame.LayoutOrder = index
		local status: ("offered" | "blocked")? = if pick.status == "blocked"
			then "blocked"
			elseif pick.status == "offered" then "offered"
			else nil
		local view: TradeItemTile.View = {
			id = pick.id,
			name = pick.name,
			rarity = "Common",
			image = ShopIcons.crate(pick.id),
			badge = TradeLogic.countText(pick.banked),
			foot = if pick.offered > 0 then string.format("%d on", pick.offered) else nil,
			status = status,
		}
		shown:set(view)
	end
	for id, tile in self._crateTiles do
		if not seen[id] then
			tile:destroy()
			self._crateTiles[id] = nil
		end
	end
	if self._pickerFor ~= nil and self._pickerFor ~= FISH and not seen[self._pickerFor] then
		self:_closePicker()
	end
	return #crates
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
			card.rarity.TextColor3 = Theme.rarityLight(cat.rarity) -- the light rarity colour that reads on a dark card (#1028)
		end
		for index = #cats + 1, #row.cards do
			row.cards[index].frame.Visible = false
		end
		-- #1574: the pieces after the cats
		local side: Types.TradeSide = if key == "give" then trade.me else trade.them
		local decor: { Types.TradeDecorTile } = side.decor or {}
		for index, piece in decor do
			local card = self:_pieceCard(row, index)
			card.frame.Visible = true
			card.tile:set(pieceView(piece, nil))
			card.name.Text = piece.name
			card.rarity.Text = TradeLogic.pieceRarity(piece.rarity, piece.bonus)
			card.rarity.TextColor3 = pieceLight(piece.rarity)
		end
		for index = #decor + 1, #row.pieces do
			row.pieces[index].frame.Visible = false
		end
		-- #2745: the crates after the pieces
		local crates = cratesOf(side)
		for index, crate in crates do
			local card = self:_crateCard(row, index)
			card.frame.Visible = true
			card.tile:set(crateView(crate, nil))
			card.name.Text = crate.name
			card.rarity.Text = TradeLogic.countText(crate.count)
			card.rarity.TextColor3 = PAL.subtext
		end
		for index = #crates + 1, #row.crates do
			row.crates[index].frame.Visible = false
		end
		-- #2745 (section 1d): the golden fish after the crates
		local fish = TradeLogic.fishOf(side)
		if fish > 0 then
			local card = self:_fishCard(row)
			card.frame.Visible = true
			local view = fishView(fish)
			view.foot = nil -- the amount is the line under it
			card.tile:set(view)
			card.name.Text = "Golden fish"
			card.rarity.Text = tostring(fish)
			card.rarity.TextColor3 = Theme.colors.gold
		elseif row.fish ~= nil then
			row.fish.frame.Visible = false
		end
		local nothing = #cats + #decor + #crates == 0 and fish == 0
		row.nothing.Visible = nothing
		row.nothing.TextColor3 = if key == "get" and nothing then PAL.red else PAL.subtext
	end
	local warning = TradeLogic.warning(trade)
	self._warning.Text = warning or ""
	self._warning.Visible = warning ~= nil
end

-- #2550: the server says the ask to `userId` was declined or ran out; the row says Trade again after REASK_SECONDS.
-- #3211 (Derek2 11-11: "still gets stuck on asked"): `now` when the ask never went out or could not open: no wait.
function Trade.askEnded(self: any, userId: number, now: boolean?)
	if self._asked[userId] ~= nil then
		self._asked[userId] = TradeLogic.askedUntil(os.clock(), now == true)
		self:_renderPlayers()
	end
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
			TradeLogic.confirmButton(trade, os.clock() - (self._confirmSince or os.clock()), now)
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
			local decor: { Types.TradeDecorTile } = data.decor or {}
			for index, piece in decor do
				local tile: TradeItemTile.TradeItemTile? = self._side[changed.side].pieces[index]
				if piece.id == changed.uid and tile ~= nil then
					tile:flash()
				end
			end
			for index, crate in cratesOf(data) do
				local tile: TradeItemTile.TradeItemTile? = self._side[changed.side].crates[index]
				if crate.id == changed.uid and tile ~= nil then
					tile:flash()
				end
			end
		end
	end
	local hint: string? = if os.clock() < self._hintUntil then self._hint else nil
	local tab: Tab = self._tab
	local crateCount = 0
	for _, crate in cratesOf(trade.me) do
		crateCount += crate.count
	end
	local full = if tab == "cats"
		then #trade.me.cats >= TradeLogic.MAX_CATS
		elseif tab == "decor" then #(trade.me.decor or {}) >= TradeLogic.MAX_DECOR
		else crateCount >= TradeLogic.MAX_CRATES
	self._hintLabel.Text = hint
		or (
			if full
				then "Your offer is full"
				elseif tab == "cats" then "Tap a cat to add it"
				elseif tab == "decor" then "Tap a piece to add it"
				else "Tap to add one, hold to pick how many"
		)
	self._hintLabel.TextColor3 = if hint then PAL.warn else PAL.subtext
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
		self._callbacks.ready(trade.tradeId, trade.version, ready.ready == true)
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
				self:_refuse(hint, self._pickTiles[uid])
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

-- #1574: a press on a piece in my grid takes it back.
function Trade._pressMinePiece(self: any, index: number)
	local trade: Types.TradeState? = self._trade
	if trade == nil or trade.phase == "confirm" then
		return
	end
	local piece = (trade.me.decor or {})[index]
	if piece then
		self._callbacks.offer(trade.tradeId, "remove", piece.id, "decor")
	end
end

-- #1574: a press on a piece in the Decor tab adds it (or takes it back), else says why not with a wobble.
function Trade._pressPiece(self: any, id: string)
	local trade: Types.TradeState? = self._trade
	if trade == nil or trade.phase == "confirm" then
		return
	end
	for _, pick in self._pieces do
		if pick.id == id then
			local full = #(trade.me.decor or {}) >= TradeLogic.MAX_DECOR
			local hint = TradeLogic.pieceHint(pick, full)
			if hint then
				self:_refuse(hint, self._pieceTiles[id])
			else
				self._callbacks.offer(
					trade.tradeId,
					if pick.status == "offered" then "remove" else "add",
					id,
					"decor"
				)
			end
			return
		end
	end
end

-- #2745: a press on a crate in my grid takes one back.
function Trade._pressMineCrate(self: any, index: number)
	local trade: Types.TradeState? = self._trade
	if trade == nil or trade.phase == "confirm" then
		return
	end
	local crate = cratesOf(trade.me)[index]
	if crate then
		self._callbacks.offer(trade.tradeId, "remove", crate.id, "crate", 1)
	end
end

-- #2745: the Crates tab's pick for crate `id`, or nil.
function Trade._cratePick(self: any, id: string): TradeLogic.CratePick?
	for _, pick in self._crates do
		if pick.id == id then
			return pick
		end
	end
	return nil
end

-- #2745: a tap on a crate in the Crates tab adds one, else says why not with a wobble.
function Trade._pressCrate(self: any, id: string)
	local trade: Types.TradeState? = self._trade
	local pick = self:_cratePick(id)
	if trade == nil or trade.phase == "confirm" or pick == nil then
		return
	end
	local hint = TradeLogic.crateHint(pick, trade.me)
	if hint then
		self:_refuse(hint, self._crateTiles[id])
		return
	end
	self._callbacks.offer(trade.tradeId, "add", id, "crate", 1)
end

-- #2745: a long press on a crate opens the count picker from 1 to what can go (or says why none can).
function Trade._openPicker(self: any, id: string)
	local trade: Types.TradeState? = self._trade
	local pick = self:_cratePick(id)
	if trade == nil or trade.phase == "confirm" or pick == nil then
		return
	end
	local most = TradeLogic.crateMax(pick, trade.me)
	if pick.status == "blocked" or most < 1 then
		self:_refuse(
			TradeLogic.crateHint(pick, trade.me) or "You don't have that many",
			self._crateTiles[id]
		)
		return
	end
	self._pickerFor = id
	self._pickerMin = 1
	self._pickerMax = most
	self._pickerCount = math.clamp(math.max(pick.offered, 1), 1, most)
	self._pickerTitle.Text = string.format("How many %s?", pick.name)
	self:_layoutPicker(false)
	self._picker.Visible = true
	self:_pickerStep(0)
end

-- #2745 (section 1d): a press on your fish card opens the picker as an amount from 0 (take them all back) to what can
-- go, or says why none can.
function Trade._openFishPicker(self: any)
	local trade: Types.TradeState? = self._trade
	local state: Types.PlayerState? = self._state
	if trade == nil or trade.phase ~= "offer" or (trade :: any).fishOn ~= true then
		return
	end
	local wallet: number? = if state ~= nil then state.goldenFish else nil
	local room: number? = (trade :: any).fishRoom
	local offered = TradeLogic.fishOf(trade.me)
	local hint = TradeLogic.fishHint(wallet, room, offered)
	if hint then
		self:_refuse(hint, self._side.me.fish)
		return
	end
	self._pickerFor = FISH
	self._pickerMin = 0
	self._pickerMax = math.max(offered, TradeLogic.fishMax(wallet, room))
	self._pickerCount = math.clamp(if offered > 0 then offered else 10, 0, self._pickerMax)
	self._pickerTitle.Text = "How many golden fish?"
	self._pickerRoom.Text = TradeLogic.fishRoomLine(room)
	self:_layoutPicker(true)
	self._picker.Visible = true
	self:_pickerStep(0)
end

function Trade._pickerQuickPress(self: any, quick: number | "max")
	self._pickerCount = TradeLogic.fishQuick(quick, self._pickerMax)
	self:_pickerStep(0)
end

function Trade._pickerStep(self: any, by: number)
	local least: number = self._pickerMin or 1
	self._pickerCount = math.clamp(self._pickerCount + by, least, math.max(least, self._pickerMax))
	self._pickerCountLabel.Text = tostring(self._pickerCount)
	self._pickerLess:setEnabled(self._pickerCount > least)
	self._pickerMore:setEnabled(self._pickerCount < self._pickerMax)
end

function Trade._closePicker(self: any)
	self._pickerFor = nil
	if self._picker ~= nil then
		self._picker.Visible = false
	end
end

-- Done: the difference from what is on offer now, as one add or one remove; for fish (#2745) the amount as one set.
function Trade._pickerDone(self: any)
	local trade: Types.TradeState? = self._trade
	local id: string? = self._pickerFor
	if id == FISH then
		self:_closePicker()
		if
			trade ~= nil
			and trade.phase == "offer"
			and self._pickerCount ~= TradeLogic.fishOf(trade.me)
		then
			self._callbacks.offer(trade.tradeId, "set", FISH, "fish", self._pickerCount)
		end
		return
	end
	local pick = if id ~= nil then self:_cratePick(id) else nil
	self:_closePicker()
	if trade == nil or trade.phase == "confirm" or pick == nil then
		return
	end
	local action, count = TradeLogic.crateChange(pick.offered, self._pickerCount)
	if action ~= nil then
		self._callbacks.offer(trade.tradeId, action, pick.id, "crate", count)
	end
end

-- Why a press did nothing, under the list for 3 s, and the card's wobble.
function Trade._refuse(self: any, hint: string, tile: any)
	self._hint = hint
	self._hintUntil = os.clock() + 3
	if tile ~= nil then
		local frame: Frame = tile.frame
		frame.Rotation = -6
		Tween.to(
			frame,
			TweenInfo.new(0.45, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
			{ Rotation = 0 }
		)
	end
	self:_tick()
end

function Trade.destroy(self: any)
	self._alive = false
	for _, tile in self._pickTiles do
		tile:destroy()
	end
	for _, tile in self._pieceTiles do
		tile:destroy()
	end
	for _, tile in self._crateTiles do
		tile:destroy()
	end
	self._panel:destroy()
end

return Trade
