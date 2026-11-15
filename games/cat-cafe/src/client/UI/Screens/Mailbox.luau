--!strict
-- #4249 (Derek 2026-11-14, mockup OK'd 18:04 UTC: Design-Agent/mailbox-2026-11-14/mailbox-mock.png): the Mailbox
-- window. Letters from Derek, each a card with its title, "From Derek · ends in 3 days", a short note, the gift chip
-- (golden fish, coins, crates with their odds line, potions, Trait Tokens) and a green Claim. A letter still to claim
-- is a cream card with a red dot; a claimed one goes cocoa with "✓ Claimed". The server decides every claim and pays
-- it once; its state push turns the card. Opened from the HUD's Mailbox tile while the `mailbox` switch is on.
--   Mailbox.new(callbacks)    callbacks.close (the X), callbacks.claim(letterId, done): the server's answer comes to
--                             done(ok, why); a refusal ("Already claimed", "This gift has ended") shows on the card
--   mailbox:setCatalog(catalog)  crate names and odds, potion names
--   mailbox:render(state)     reads state.mail; call it on open and while open

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local MailLogic = require(script.Parent.Parent.Components.MailLogic)
local MenuFamily = require(script.Parent.Parent.Components.MenuFamily)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

local PAL = MenuFamily.pal
local CARD = MenuFamily.card

export type Callbacks = {
	close: () -> (),
	claim: (letterId: string, done: (ok: boolean, why: string?) -> ()) -> (),
}

export type Mailbox = {
	frame: Frame,
	setCatalog: (self: Mailbox, catalog: Types.Catalog) -> (),
	render: (self: Mailbox, state: Types.PlayerState) -> (),
	destroy: (self: Mailbox) -> (),
}

type Card = {
	frame: Frame,
	stroke: UIStroke,
	envelope: TextLabel,
	title: TextLabel,
	from: TextLabel,
	note: TextLabel,
	chip: Frame,
	gift: TextLabel,
	odds: TextLabel,
	claim: Button.Button,
	claimed: TextLabel,
	dot: Frame,
	id: string?,
}

local MAX_SIZE = Vector2.new(560, 540)
local GAP = Theme.sizes.gap
local PAD = 12
local ENVELOPE = 40
local TITLE_Y = PAD
local FROM_Y = TITLE_Y + 28
local NOTE_Y = FROM_Y + 26
local NOTE_H = 42 -- two lines
local ROW_Y = NOTE_Y + NOTE_H + 6
local ODDS_H = 18
local CLAIM_W = 132
local CLAIM_WAIT = 8 -- seconds a pressed Claim waits for the server's answer before it can be pressed again
local WHY_SECONDS = 4 -- how long a refusal shows on the card's From line

local Mailbox = {}
Mailbox.__index = Mailbox

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

function Mailbox.new(callbacks: Callbacks): Mailbox
	local self = setmetatable({}, Mailbox) :: any
	self._callbacks = callbacks
	self._cards = {} :: { Card }
	self._mail = nil :: { MailLogic.Letter }?
	self._pressed = {} :: { [string]: number } -- letter id to when its Claim was pressed
	self._crates = {} :: { [string]: Types.CrateDef }
	self._potions = {} :: { [string]: string }
	self._lures = {} :: { [string]: string }
	self._foods = {} :: { [string]: string }
	self._rate = nil :: number?
	self._why = {} :: { [string]: { text: string, at: number } } -- a refused claim's words, by letter id
	self._buttonH = Scale.tapHeight(44, Theme.sizes.buttonDepth)

	local panel = Panel.new({
		dark = true,
		name = "Mailbox",
		title = "Mailbox",
		subtitle = MailLogic.SUBTITLE,
		color = Theme.colors.berryDark,
		icon = "✉️",
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = MAX_SIZE, Parent = panel.frame })
	self._panel = panel
	self.frame = panel.frame
	local content = panel.content

	self._list = Create("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
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
		Outline.listPadding(8),
	}) :: ScrollingFrame
	self._empty = text({
		Name = "Empty",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.new(1, -40, 0, 60),
		TextColor3 = PAL.subtext,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		Text = MailLogic.EMPTY,
		Visible = false,
		Parent = content,
	})
	return self :: Mailbox
end

function Mailbox._card(self: any, index: number): Card
	local existing: Card? = self._cards[index]
	if existing then
		return existing
	end
	local buttonH: number = self._buttonH
	local frame: Frame = Create("Frame", {
		Name = "Letter" .. index,
		BackgroundColor3 = CARD.card,
		BorderSizePixel = 0,
		LayoutOrder = index,
		Size = UDim2.new(1, 0, 0, ROW_Y + buttonH + PAD),
		Parent = self._list,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
	})
	local stroke: UIStroke = Create(
		"UIStroke",
		{ Color = CARD.cardStroke, Thickness = Theme.sizes.stroke, Parent = frame }
	)
	local envelope = text({
		Name = "Envelope",
		Position = UDim2.fromOffset(PAD, TITLE_Y),
		Size = UDim2.fromOffset(ENVELOPE, ENVELOPE),
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		Text = "✉️",
		Parent = frame,
	})
	local left = PAD + ENVELOPE + 8
	local title = text({
		Name = "Title",
		Position = UDim2.fromOffset(left, TITLE_Y),
		Size = UDim2.new(1, -(left + PAD + 14), 0, 26),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		Parent = frame,
	})
	local from = text({
		Name = "From",
		Position = UDim2.fromOffset(left, FROM_Y),
		Size = UDim2.new(1, -(left + PAD), 0, 20),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = CARD.subtext,
		Parent = frame,
	})
	local note = text({
		Name = "Note",
		Position = UDim2.fromOffset(PAD, NOTE_Y),
		Size = UDim2.new(1, -PAD * 2, 0, NOTE_H),
		TextSize = Theme.sizes.textSmall + 1,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = frame,
	})
	local chip: Frame = Create("Frame", {
		Name = "Gift",
		BackgroundColor3 = CARD.goldCard,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(PAD, ROW_Y),
		Size = UDim2.new(1, -(CLAIM_W + PAD * 3), 0, buttonH),
		Parent = frame,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 10) }),
		Create("UIStroke", { Color = CARD.gold, Thickness = 2 }),
	})
	local gift = text({
		Name = "Words",
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -20, 1, 0),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall + 1,
		TextColor3 = CARD.gold,
		TextWrapped = true,
		Parent = chip,
	})
	local odds = text({
		Name = "Odds",
		Position = UDim2.fromOffset(PAD, ROW_Y + buttonH + 2),
		Size = UDim2.new(1, -PAD * 2, 0, ODDS_H),
		TextSize = Theme.sizes.textSmall - 1,
		TextColor3 = CARD.subtext,
		Visible = false,
		Parent = frame,
	})
	local card: Card
	local claim = Button.new({
		name = "Claim",
		text = "Claim",
		style = "primary",
		size = UDim2.fromOffset(CLAIM_W, buttonH),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, -PAD, 0, ROW_Y),
		textSize = Theme.sizes.textLarge,
		parent = frame,
		onClick = function()
			local id = card.id
			if id == nil then
				return
			end
			local at = os.clock()
			self._pressed[id] = at
			self._why[id] = nil
			card.claim:setEnabled(false)
			card.claim:setText("…")
			self._callbacks.claim(id, function(ok: boolean, why: string?)
				if self._pressed[id] ~= at then
					return
				end
				self._pressed[id] = nil
				if not ok then
					local shown = { text = why or "Try again in a moment", at = os.clock() }
					self._why[id] = shown
					task.delay(WHY_SECONDS, function()
						if self._why[id] == shown then
							self._why[id] = nil
							self:_renderMail()
						end
					end)
				end
				self:_renderMail()
			end)
			task.delay(CLAIM_WAIT, function()
				if self._pressed[id] == at then
					self._pressed[id] = nil
					self:_renderMail()
				end
			end)
		end,
	})
	local claimed = text({
		Name = "Claimed",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -PAD, 0, ROW_Y),
		Size = UDim2.fromOffset(CLAIM_W, buttonH),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textLarge,
		TextColor3 = PAL.good,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "✓ Claimed",
		Visible = false,
		Parent = frame,
	})
	local dot: Frame = Create("Frame", {
		Name = "Dot",
		BackgroundColor3 = Theme.colors.red,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(16, 16),
		Parent = frame,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(dot, 2)
	card = {
		frame = frame,
		stroke = stroke,
		envelope = envelope,
		title = title,
		from = from,
		note = note,
		chip = chip,
		gift = gift,
		odds = odds,
		claim = claim,
		claimed = claimed,
		dot = dot,
		id = nil :: string?,
	}
	self._cards[index] = card
	return card
end

function Mailbox._paint(self: any, card: Card, row: MailLogic.Row)
	local buttonH: number = self._buttonH
	local colours = if row.claimed then PAL else CARD
	card.id = row.id
	card.frame.Visible = true
	card.frame.BackgroundColor3 = colours.card
	card.stroke.Color = colours.cardStroke
	card.envelope.TextTransparency = if row.claimed then 0.4 else 0
	card.title.Text = row.title
	card.title.TextColor3 = colours.text
	local why = self._why[row.id]
	card.from.Text = if why and not row.claimed then why.text else row.from
	card.from.TextColor3 = if why and not row.claimed then CARD.red else colours.subtext
	card.note.Text = row.note
	card.note.TextColor3 = if row.claimed then PAL.subtext else CARD.text
	card.gift.Text = row.gift.glyph .. " " .. row.gift.text
	card.gift.TextColor3 = colours.gold
	card.chip.BackgroundColor3 = colours.goldCard
	local odds = row.gift.odds
	card.odds.Visible = odds ~= nil and not row.claimed
	card.odds.Text = odds or ""
	card.odds.TextColor3 = colours.subtext
	card.frame.Size =
		UDim2.new(1, 0, 0, ROW_Y + buttonH + PAD + (if card.odds.Visible then ODDS_H else 0))
	card.claimed.Visible = row.claimed
	card.dot.Visible = not row.claimed
	local pressed = self._pressed[row.id] ~= nil and not row.claimed
	card.claim.instance.Visible = not row.claimed
	card.claim:setEnabled(not pressed)
	card.claim:setText(if pressed then "…" else "Claim")
	if row.claimed then
		self._pressed[row.id] = nil
	end
end

function Mailbox._names(self: any): MailLogic.Names
	return {
		crate = function(id: string): (string?, { [string]: number }?)
			local def: Types.CrateDef? = self._crates[id]
			if def == nil then
				return nil, nil
			end
			return def.name, def.odds
		end,
		potion = function(id: string): string?
			return self._potions[id]
		end,
		lure = function(id: string): string?
			return self._lures[id]
		end,
		food = function(id: string): string?
			return self._foods[id]
		end,
		rate = self._rate,
	}
end

function Mailbox._renderMail(self: any)
	local rows = MailLogic.rows(self._mail, os.time(), self:_names())
	for index, row in rows do
		self:_paint(self:_card(index), row)
	end
	for index = #rows + 1, #self._cards do
		self._cards[index].frame.Visible = false
		self._cards[index].id = nil
	end
	self._empty.Visible = #rows == 0
end

function Mailbox.setCatalog(self: any, catalog: Types.Catalog)
	table.clear(self._crates)
	local crates: { Types.CrateDef } = catalog.crates or {}
	for _, def in crates do
		self._crates[def.id] = def
	end
	for _, kind in
		{
			{ into = self._potions, from = (catalog.potions or {}) :: { any } },
			{ into = self._lures, from = catalog.lures :: { any } },
			{ into = self._foods, from = (catalog.catFood or {}) :: { any } },
		} :: { { into: any, from: { any } } }
	do
		table.clear(kind.into)
		for _, def in kind.from :: { any } do
			kind.into[def.id] = def.name
		end
	end
	self:_renderMail()
end

function Mailbox.render(self: any, state: Types.PlayerState)
	self._mail = state.mail
	self._rate = state.prizeRate or state.incomePerSecond
	self:_renderMail()
end

function Mailbox.destroy(self: any)
	for _, card in self._cards do
		card.claim:destroy()
	end
	self._panel:destroy()
end

return Mailbox
