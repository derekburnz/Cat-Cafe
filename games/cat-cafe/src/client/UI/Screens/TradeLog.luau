--!strict
-- The Trades page (F102, trading.md section 5): the last 20 trades from ProfileSync's tradeLog, newest first, so a
-- player or a parent can see what happened. Each card says who it was with ("With Sam", their display name at the
-- time), when ("3h ago") and both sides as small cat cards ("Gave" and "Got", "Nothing" for an empty side). Opened
-- from the Trades row in Settings; Back returns there. View only.
--   TradeLog.new(callbacks)   callbacks.close (the X), callbacks.back (Back, to Settings)
--   log:setCatalog(catalog)   the cat pictures
--   log:render(state)         reads state.tradeLog; call it on open and while open only, since it builds the cards

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local Panel = require(script.Parent.Parent.Components.Panel)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)
local TradeLogic = require(script.Parent.Parent.Components.TradeLogic)
local TradeTile = require(script.Parent.Parent.Components.TradeTile)
local Types = require(script.Parent.Parent.Types)

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

type Line = { scroll: ScrollingFrame, nothing: TextLabel, tiles: { TradeTile.TradeTile } }

type Card = { frame: Frame, partner: TextLabel, when: TextLabel, gave: Line, got: Line }

local MAX_SIZE = Vector2.new(600, 460)
local GAP = Theme.sizes.gap
local TILE = 40 -- the cats on a card; not buttons, so no touch minimum
local PAD = 8
local LEFT_W = 132 -- the partner and the time
local LABEL_W = 44 -- "Gave" and "Got"
local CARD_H = PAD * 2 + TILE * 2 + 4

local TradeLog = {}
TradeLog.__index = TradeLog

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

function TradeLog.new(callbacks: Callbacks): TradeLog
	local self = setmetatable({}, TradeLog) :: any
	self._callbacks = callbacks
	self._catById = {} :: { [string]: Types.CatDef }
	self._cards = {} :: { Card }
	self._log = nil :: { Types.TradeLogEntry }?

	local panel = Panel.new({
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
		ScrollBarImageColor3 = Theme.colors.caramel,
		Parent = content,
	}, {
		Create(
			"UIListLayout",
			{ Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder }
		),
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 4),
			PaddingLeft = UDim.new(0, 2),
			PaddingRight = UDim.new(0, 8),
		}),
	}) :: ScrollingFrame
	self._empty = text({
		Name = "Empty",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -(buttonH + GAP) / 2),
		Size = UDim2.new(1, -40, 0, 60),
		TextColor3 = Theme.modal.subtext,
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
		TextColor3 = Theme.modal.subtext,
		Text = title,
		Parent = card,
	})
	local scroll: ScrollingFrame = Create("ScrollingFrame", {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(LEFT_W + LABEL_W, y),
		Size = UDim2.new(1, -(LEFT_W + LABEL_W + PAD), 0, TILE),
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
	})
	local nothing = text({
		Name = name .. "Nothing",
		Position = UDim2.fromOffset(LEFT_W + LABEL_W, y),
		Size = UDim2.new(1, -(LEFT_W + LABEL_W + PAD), 0, TILE),
		TextColor3 = Theme.modal.subtext,
		Text = "Nothing",
		Visible = false,
		Parent = card,
	})
	return { scroll = scroll, nothing = nothing, tiles = {} }
end

function TradeLog._card(self: any, index: number): Card
	local existing: Card? = self._cards[index]
	if existing then
		return existing
	end
	local frame: Frame = Create("Frame", {
		Name = "Trade" .. index,
		BackgroundColor3 = Theme.modal.card,
		BorderSizePixel = 0,
		LayoutOrder = index,
		Size = UDim2.new(1, 0, 0, CARD_H),
		Parent = self._list,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = Theme.modal.cardStroke, Thickness = Theme.sizes.stroke }),
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
		TextColor3 = Theme.modal.subtext,
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

function TradeLog._fill(self: any, line: Line, cats: { TradeLogic.LogCat })
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
	line.nothing.Visible = shown == 0
end

function TradeLog._renderLog(self: any)
	local rows = TradeLogic.logRows(self._log, os.time())
	for index, row in rows do
		local card = self:_card(index)
		card.frame.Visible = true
		card.partner.Text = row.partner
		card.when.Text = row.when
		self:_fill(card.gave, row.gave)
		self:_fill(card.got, row.got)
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
		end
	end
	self._back:destroy()
	self._panel:destroy()
end

return TradeLog
