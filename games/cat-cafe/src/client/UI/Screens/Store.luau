--!strict
-- The Store window (Derek 2026-11-02 20:01: "store still needs to be added"), opened by the gold Store tile at the
-- top of the HUD's left menu. Monetization-Agent's shop-and-pass-plan says what is sold and the rules: nothing random,
-- no coins for Robux, the price in Robux on the card before Roblox's own window, prices read from Roblox at runtime,
-- no timers, no pop-ups.
--
-- A card per pass that exists (Components/StoreLogic.rows): its picture, name, what it does and one button, the price
-- ("R$5"), "..." while the price loads or "Soon" while the pass is off sale; an owned pass shows "Owned" in green in
-- place of the button. Derek 2026-11-03 01:41 ("make sure the store is good and stands out", #1020): each pass is a
-- gold-tinted card with a bright clean picture tile and the gold Store-style price button, honest for a young
-- audience (monetization-policy): the price plainly, no timers, no sale or "limited" badges. The money ladder shows its next
-- rung only. A line under the title says passes are kept for good. buy(passId) opens Roblox's purchase window
-- (Components/PassShop); the server turns the pass on when Roblox says it was bought.

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local IconArt = require(script.Parent.Parent.Components.IconArt)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local Scale = require(script.Parent.Parent.Scale)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local StoreLogic = require(script.Parent.Parent.Components.StoreLogic)
local Theme = require(script.Parent.Parent.Theme)

export type Callbacks = {
	buy: (passId: number) -> (),
	close: () -> (),
}

-- the dark window palette (#1028), in place of Theme.modal
local PAL = Theme.dark

export type Store = {
	frame: Frame,
	render: (
		self: Store,
		rows: { StoreLogic.Row },
		prices: { [number]: StoreLogic.Price }
	) -> (),
	destroy: (self: Store) -> (),
}

local NOTE_H = 24
local ICON = 64
-- the clean symbol on a pass's picture tile (the glyph shows until it loads, and for a pass without one)
local CLEAN_PICTURE: { [string]: string } = {
	money = "Bag",
}
-- the picture tile's fill: the gold of the HUD Store tile and price button (Theme.button.store)
local TILE_FILL = ColorSequence.new(Theme.button.store.top, Theme.button.store.bottom)
local BUTTON_W = 116 -- #1176 live: "the buttons overlap and are too big"
-- #1221 (Derek 2026-11-04: the pass cards "push out past the sides" of the window and "lose their outlines"): a
-- UIStroke is drawn outside its card, and the list clips at its own edge, so the list keeps the outline's width
-- inside its edges plus an even gap on both sides. The scroll bar takes its own strip (VerticalScrollBarInset), so
-- the cards shrink when it shows and never run under it.
local CARD_STROKE = Theme.sizes.stroke + 1 -- the card's gold outline
local SCROLL_BAR = 6
local CARD_SIDE = 8 -- between a card's outline and the window's inner edge (and the scroll bar)
local CARD_INSET = CARD_STROKE + CARD_SIDE
local CARD_FOOT = 12 -- under a long description that wraps onto more lines than the card's height holds

local Store = {}
Store.__index = Store

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

function Store.new(callbacks: Callbacks): Store
	local self = setmetatable({}, Store) :: any
	self._callbacks = callbacks
	self._cards = {} :: { [string]: any }
	self._actionHeight = Scale.tapHeight(Theme.sizes.touchMin, Theme.sizes.buttonDepth)
	self._rowHeight = math.max(ICON + 28, self._actionHeight + 24)

	local panel = Panel.new({
		dark = true, -- #1028
		name = "Store",
		color = Theme.colors.goldDark,
		icon = Theme.icons.store,
		title = "Store",
		subtitle = "Help your cafe grow",
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = Vector2.new(640, 520), Parent = panel.frame })
	self._panel = panel
	self.frame = panel.frame

	text({
		Name = "Note",
		Size = UDim2.new(1, 0, 0, NOTE_H),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		Text = "Passes are yours to keep. Prices are in Robux.",
		Parent = panel.content,
	})
	self._list = Create("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, NOTE_H + Theme.sizes.gap),
		Size = UDim2.new(1, 0, 1, -(NOTE_H + Theme.sizes.gap)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = SCROLL_BAR,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar, -- the bar's strip is not under the cards
		ScrollBarImageColor3 = PAL.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel.content,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		-- the first and last cards' outlines show at the top and bottom too
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, CARD_INSET),
			PaddingRight = UDim.new(0, CARD_INSET),
			PaddingTop = UDim.new(0, CARD_STROKE),
			PaddingBottom = UDim.new(0, CARD_STROKE),
		}),
	})
	self._empty = text({
		Name = "Empty",
		Size = UDim2.new(1, 0, 0, 60),
		TextColor3 = PAL.subtext,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		Text = "Nothing in the Store yet. Come back soon!",
		Visible = false,
		Parent = self._list,
	})

	return self :: Store
end

-- The card for `key` ("money", "longNap"), made the first time it shows.
function Store._card(self: any, key: string, order: number): any
	local existing = self._cards[key]
	if existing then
		existing.frame.LayoutOrder = order
		return existing
	end
	local card: Frame = Create("Frame", {
		Name = key,
		LayoutOrder = order,
		BackgroundColor3 = PAL.goldCard,
		BorderSizePixel = 0,
		-- the padded list's width; the height is a minimum and grows with a long description (AutomaticSize)
		Size = UDim2.new(1, 0, 0, self._rowHeight),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = self._list,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", {
			Color = Theme.colors.gold,
			Thickness = CARD_STROKE,
		}),
		-- a soft light along the top, so the card reads as a lit gold panel rather than a flat row
		Create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205)),
		}),
	})
	local tile: Frame = Create("Frame", {
		Name = "Tile",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(ICON, ICON),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = card,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, math.floor(ICON * 0.26)) }),
		Create("UIGradient", { Rotation = 90, Color = TILE_FILL }),
	})
	Outline.border(tile, 4)
	local glyph = text({
		Name = "Icon",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextScaled = true,
		Parent = tile,
	})
	Create("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		Parent = glyph,
	})
	local left = 12 + ICON + 14
	local right = BUTTON_W + 24
	local name = text({
		Name = "Name",
		Position = UDim2.fromOffset(left, 12),
		Size = UDim2.new(1, -(left + right), 0, 26),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		Parent = card,
	})
	Outline.text(name)
	local effect = text({
		Name = "Effect",
		Position = UDim2.fromOffset(left, 40),
		-- as wide as the space left of the button, and as tall as its lines (the card grows round it, #1221)
		Size = UDim2.new(1, -(left + right), 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = card,
	})
	Create("UIPadding", { PaddingBottom = UDim.new(0, CARD_FOOT), Parent = effect })
	-- an owned pass: the green word in place of the button (no price)
	local owned = text({
		Name = "Owned",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(BUTTON_W, self._actionHeight),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextColor3 = PAL.good,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Owned ✓",
		Visible = false,
		Parent = card,
	})
	Outline.text(owned)
	local entry: any =
		{ frame = card, glyph = glyph, name = name, effect = effect, owned = owned, passId = 0 }
	entry.button = Button.new({
		name = "Buy",
		text = "...",
		style = "ghost",
		size = UDim2.fromOffset(BUTTON_W, self._actionHeight),
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, -12, 0.5, 0),
		textSize = Theme.sizes.textBody,
		enabled = false,
		parent = card,
		onClick = function()
			if entry.passId ~= 0 then
				self._callbacks.buy(entry.passId)
			end
		end,
	})
	self._cards[key] = entry
	return entry
end

function Store.render(self: any, rows: { StoreLogic.Row }, prices: { [number]: StoreLogic.Price })
	local shown: { [string]: boolean } = {}
	for order, row in rows do
		local entry = self:_card(row.key, order)
		shown[row.key] = true
		entry.passId = row.passId
		entry.frame.Visible = true
		entry.name.Text = row.name
		entry.effect.Text = row.effect
		entry.glyph.Text = row.icon
		local picture = CLEAN_PICTURE[row.key]
		-- a potion pack shows the Potions flask picture (#1256) until it has a pack picture of its own
		local image = if picture
			then ShopIcons.clean(picture)
			elseif row.product then ShopIcons.hud("Potion")
			else nil
		if image then
			IconArt.setImage(entry.glyph, image, 1.3)
		else
			IconArt.set(entry.glyph, row.icon)
		end
		local button = StoreLogic.button(row, prices[row.passId])
		entry.button:setText(button.text)
		entry.button:setStyle(button.style :: any)
		entry.button:setEnabled(button.enabled)
		entry.button.instance.Visible = not row.owned
		entry.owned.Visible = row.owned
	end
	for key, entry in self._cards do
		if not shown[key] then
			entry.frame.Visible = false
		end
	end
	self._empty.Visible = #rows == 0
end

function Store.destroy(self: any)
	for _, entry in self._cards do
		entry.button:destroy()
	end
	self._panel:destroy()
end

return Store
