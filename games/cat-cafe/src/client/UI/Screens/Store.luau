--!strict
-- The Store window (Derek 2026-11-02 20:01: "store still needs to be added"), opened by the gold Store tile at the
-- top of the HUD's left menu. Monetization-Agent's shop-and-pass-plan says what is sold and the rules: nothing random,
-- no coins for Robux, the price in Robux on the card before Roblox's own window, prices read from Roblox at runtime,
-- no timers, no pop-ups.
--
-- A card per pass that exists (Components/StoreLogic.rows): its picture, name, what it does and one button, the price
-- ("R$5"), "Owned", "..." while the price loads or "Soon" while the pass is off sale. The money ladder shows its next
-- rung only. A line under the title says passes are kept for good. buy(passId) opens Roblox's purchase window
-- (Components/PassShop); the server turns the pass on when Roblox says it was bought.

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local IconArt = require(script.Parent.Parent.Components.IconArt)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local Scale = require(script.Parent.Parent.Scale)
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
local BUTTON_W = 150

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
	self._actionHeight = Scale.tapHeight(Theme.sizes.touchMin + 4, Theme.sizes.buttonDepth)
	self._rowHeight = math.max(ICON + 28, self._actionHeight + 24)

	local panel = Panel.new({
		dark = true, -- #1028
		name = "Store",
		color = Theme.colors.goldDark,
		icon = "🛍️",
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
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = PAL.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel.content,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Create("UIPadding", { PaddingRight = UDim.new(0, 10) }),
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
		BackgroundColor3 = PAL.card,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, self._rowHeight),
		Parent = self._list,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = PAL.cardStroke, Thickness = Theme.sizes.stroke }),
	})
	local tile: Frame = Create("Frame", {
		Name = "Tile",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(ICON, ICON),
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		Parent = card,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	Outline.border(tile, 2)
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
	local effect = text({
		Name = "Effect",
		Position = UDim2.fromOffset(left, 40),
		Size = UDim2.new(1, -(left + right), 1, -48),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = card,
	})
	local entry: any = { frame = card, glyph = glyph, name = name, effect = effect, passId = 0 }
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
		IconArt.set(entry.glyph, row.icon)
		local button = StoreLogic.button(row, prices[row.passId])
		entry.button:setText(button.text)
		entry.button:setStyle(button.style :: any)
		entry.button:setEnabled(button.enabled)
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
