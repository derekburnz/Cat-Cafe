--!strict
-- The Trades page (F102, trading.md section 5): the last 20 trades from ProfileSync's tradeLog, newest first, so a
-- player or a parent can see what happened. Each card says who it was with ("With Sam", their display name at the
-- time), when ("3h ago") and both sides as small cat cards ("Gave" and "Got", "Nothing" for an empty side). Opened
-- from the Trades row in Settings; Back returns there. View only. #1574: decor and lawn pieces that changed hands
-- follow the cats on their line, in the trade window's piece look (TradeItemTile); #2745: then the crates ("x3")
-- and the golden fish (its amount at the foot).
--   TradeLog.new(callbacks)   callbacks.close (the X), callbacks.back (Back, to Settings)
--   log:setCatalog(catalog)   the cat pictures
--   log:render(state)         reads state.tradeLog; call it on open and while open only, since it builds the cards

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local MenuFamily = require(script.Parent.Parent.Components.MenuFamily)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local Scale = require(script.Parent.Parent.Scale)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local Theme = require(script.Parent.Parent.Theme)
local TradeItemTile = require(script.Parent.Parent.Components.TradeItemTile)
local TradeLogic = require(script.Parent.Parent.Components.TradeLogic)
local TradeTile = require(script.Parent.Parent.Components.TradeTile)
local Types = require(script.Parent.Parent.Types)

-- the shared trade rules: a piece's name for its letter until the picture loads (#1574)
local SharedTrade = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Trade")) :: any

-- the dark window palette (#1028), in place of Theme.modal
local PAL = MenuFamily.pal
local CARD = MenuFamily.card -- #3558: what sits on a picture card (cream in the family look)

export type Callbacks = {
	close: () -> (),
	back: () -> (),
}

export type TradeLog = {
	frame: Frame,
	setCatalog: (self: TradeLog, catalog: Types.Catalog) -> (),
	render: (self: TradeLog, state: Types.PlayerState) -> (),
	destroy: (self: TradeLog) -> (),
}

type Line = {
	scroll: ScrollingFrame,
	nothing: TextLabel,
	tiles: { TradeTile.TradeTile },
	pieces: { TradeItemTile.TradeItemTile }, -- #1574
}

type Card = { frame: Frame, partner: TextLabel, when: TextLabel, gave: Line, got: Line }

local MAX_SIZE = Vector2.new(600, 460)
local GAP = Theme.sizes.gap
local TILE = 40 -- the cats on a card; not buttons, so no touch minimum
local PAD = 8
local LEFT_W = 132 -- the partner and the time
local LABEL_W = 44 -- "Gave" and "Got"
local CARD_H = PAD * 2 + TILE * 2 + 4
local PIECE_ORDER = 1000 -- #1574: a line's pieces sit after its cats

local TradeLog = {}
TradeLog.__index = TradeLog

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

function TradeLog.new(callbacks: Callbacks): TradeLog
	local self = setmetatable({}, TradeLog) :: any
	self._callbacks = callbacks
	self._catById = {} :: { [string]: Types.CatDef }
	self._crateNames = {} :: { [string]: string } -- #2745: a crate's name for its letter until the picture loads
	self._cards = {} :: { Card }
	self._log = nil :: { Types.TradeLogEntry }?

	local panel = Panel.new({
		dark = true, -- #1028
		name = "TradeLog",
		title = "Trades",
		subtitle = string.format("Your last %d trades", TradeLogic.LOG_MAX),
		color = Theme.colors.mintDark,
		icon = "📜",
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = MAX_SIZE, Parent = panel.frame })
	self._panel = panel
	self.frame = panel.frame
	local content = panel.content

	local buttonH = Scale.tapHeight(44, Theme.sizes.buttonDepth)
	self._list = Create("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -(buttonH + GAP)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = PAL.caramel,
		Parent = content,
	}, {
		Create(
			"UIListLayout",
			{ Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder }
		),
		Outline.listPadding(8), -- #2294: room for the cards' outlines
	}) :: ScrollingFrame
	self._empty = text({
		Name = "Empty",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -(buttonH + GAP) / 2),
		Size = UDim2.new(1, -40, 0, 60),
		TextColor3 = PAL.subtext,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		Text = string.format(
			"No trades yet. Tap %s Trade at the top to swap cats with other players.",
			TradeLogic.ICON
		),
		Visible = false,
		Parent = content,
	})
	self._back = Button.new({
		name = "Back",
		text = "Back",
		style = "secondary",
		size = UDim2.fromOffset(140, buttonH),
		anchorPoint = Vector2.new(0, 1),
		position = UDim2.fromScale(0, 1),
		textSize = Theme.sizes.textLarge,
		parent = content,
		onClick = function()
			callbacks.back()
		end,
	})
	return self :: TradeLog
end

function TradeLog._line(_self: any, card: Frame, name: string, title: string, y: number): Line
	text({
		Name = name .. "Label",
		Position = UDim2.fromOffset(LEFT_W, y),
		Size = UDim2.fromOffset(LABEL_W, TILE),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = CARD.subtext,
		Text = title,
		Parent = card,
	})
	-- #2294: the strip reaches Outline.ROOM past the tiles on every side and pads them back, so the tiles sit where
	-- they did with their rings whole
	local room = Outline.ROOM
	local scroll: ScrollingFrame = Create("ScrollingFrame", {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(LEFT_W + LABEL_W - room, y - room),
		Size = UDim2.new(1, -(LEFT_W + LABEL_W + PAD) + room * 2, 0, TILE + room * 2),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 0,
		Parent = card,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Outline.listPadding(),
	})
	local nothing = text({
		Name = name .. "Nothing",
		Position = UDim2.fromOffset(LEFT_W + LABEL_W, y),
		Size = UDim2.new(1, -(LEFT_W + LABEL_W + PAD), 0, TILE),
		TextColor3 = CARD.subtext,
		Text = "Nothing",
		Visible = false,
		Parent = card,
	})
	return { scroll = scroll, nothing = nothing, tiles = {}, pieces = {} }
end

function TradeLog._card(self: any, index: number): Card
	local existing: Card? = self._cards[index]
	if existing then
		return existing
	end
	local frame: Frame = Create("Frame", {
		Name = "Trade" .. index,
		BackgroundColor3 = CARD.card,
		BorderSizePixel = 0,
		LayoutOrder = index,
		Size = UDim2.new(1, 0, 0, CARD_H),
		Parent = self._list,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = CARD.cardStroke, Thickness = Theme.sizes.stroke }),
	})
	local partner = text({
		Name = "Partner",
		Position = UDim2.fromOffset(PAD + 2, PAD + 4),
		Size = UDim2.fromOffset(LEFT_W - PAD * 2, 26),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 1,
		Parent = frame,
	})
	local when = text({
		Name = "When",
		Position = UDim2.fromOffset(PAD + 2, PAD + 32),
		Size = UDim2.fromOffset(LEFT_W - PAD * 2, 20),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = CARD.subtext,
		Parent = frame,
	})
	local card: Card = {
		frame = frame,
		partner = partner,
		when = when,
		gave = self:_line(frame, "Gave", "Gave", PAD),
		got = self:_line(frame, "Got", "Got", PAD + TILE + 4),
	}
	self._cards[index] = card
	return card
end

-- #1574: what a line shows after its cats as item tiles: each piece (its picture and rarity, "Lawn" or a foot left
-- off at this size), then (#2745) each crate kind with "x3", then the golden fish with the amount at the foot.
local function itemViews(
	self: any,
	pieces: { TradeLogic.LogPiece },
	crates: { TradeLogic.LogCrate },
	fish: number
): { TradeItemTile.View }
	local views: { TradeItemTile.View } = {}
	for _, piece in pieces do
		local info = SharedTrade.piece(piece.id)
		table.insert(views, {
			id = piece.id,
			name = if info ~= nil then info.name else piece.id,
			rarity = piece.rarity,
			image = ShopIcons.decor(piece.id),
		})
	end
	for _, crate in crates do
		local name: string? = self._crateNames[crate.id]
		table.insert(views, {
			id = crate.id,
			name = name or crate.id,
			rarity = "Common",
			image = ShopIcons.crate(crate.id),
			badge = TradeLogic.countText(crate.count),
		})
	end
	if fish > 0 then
		table.insert(views, {
			id = "fish",
			name = "Golden fish",
			rarity = "Golden",
			image = Theme.textures.fishCoin,
			foot = tostring(fish),
		})
	end
	return views
end

function TradeLog._fill(
	self: any,
	line: Line,
	cats: { TradeLogic.LogCat },
	items: { TradeItemTile.View }
)
	local shown = 0
	for _, cat in cats do
		local def: Types.CatDef? = self._catById[cat.catId]
		if def then
			shown += 1
			local tile = line.tiles[shown]
			if tile == nil then
				tile = TradeTile.new({
					parent = line.scroll,
					size = TILE,
					layoutOrder = shown,
					name = "Cat" .. shown,
				})
				line.tiles[shown] = tile
			end
			tile.frame.Visible = true
			tile:set({ def = def, variant = cat.variant }) -- no level: its badge would cover a card this small
		end
	end
	for index = shown + 1, #line.tiles do
		line.tiles[index].frame.Visible = false
	end
	for index, view in items do
		local tile = line.pieces[index]
		if tile == nil then
			tile = TradeItemTile.new({
				parent = line.scroll,
				size = TILE,
				layoutOrder = PIECE_ORDER + index,
				name = "Piece" .. index,
			})
			line.pieces[index] = tile
		end
		tile:set(view)
	end
	for index = #items + 1, #line.pieces do
		line.pieces[index]:set(nil)
	end
	line.nothing.Visible = shown == 0 and #items == 0
end

function TradeLog._renderLog(self: any)
	local rows = TradeLogic.logRows(self._log, os.time())
	for index, row in rows do
		local card = self:_card(index)
		card.frame.Visible = true
		card.partner.Text = row.partner
		card.when.Text = row.when
		self:_fill(
			card.gave,
			row.gave,
			itemViews(self, row.gaveDecor, row.gaveCrates, row.gaveFish)
		)
		self:_fill(card.got, row.got, itemViews(self, row.gotDecor, row.gotCrates, row.gotFish))
	end
	for index = #rows + 1, #self._cards do
		self._cards[index].frame.Visible = false
	end
	self._empty.Visible = #rows == 0
end

function TradeLog.setCatalog(self: any, catalog: Types.Catalog)
	table.clear(self._catById)
	for _, def in catalog.cats do
		self._catById[def.id] = def
	end
	table.clear(self._crateNames)
	local crates: { Types.CrateDef } = catalog.crates or {}
	for _, def in crates do
		self._crateNames[def.id] = def.name
	end
	self:_renderLog()
end

function TradeLog.render(self: any, state: Types.PlayerState)
	self._log = state.tradeLog
	self:_renderLog()
end

function TradeLog.destroy(self: any)
	for _, card in self._cards do
		for _, line in { card.gave, card.got } do
			for _, tile in line.tiles do
				tile:destroy()
			end
			for _, piece in line.pieces do
				piece:destroy()
			end
		end
	end
	self._back:destroy()
	self._panel:destroy()
end

return TradeLog
