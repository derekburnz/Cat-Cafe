--!strict
-- The Yard Sale's card (F100, camp-extras.md section 3), opened by its prompt at the Neighbourhood camp
-- (UI.campExtras.openYardSale). Today's two crates side by side, the Classic Crate and the zone crate of the day, each
-- with its picture, name, the Market's own price for comparison and a Buy button with the gold fish and the Yard Sale
-- price (40). A crate taken today reads "Bought" and greys; one the player's golden fish do not cover greys too. A
-- press shows "..." until the next CampExtrasState or a refusal answers (refused). Under them: how many golden fish
-- the player has, when the next crates come, and that a bought crate opens free at the Golden Fish Market, which
-- keeps the crate reel there. Words and rules in Components/CampExtrasLogic; nothing is sold for Robux.

local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local CampExtrasLogic = require(script.Parent.Parent.Components.CampExtrasLogic)
local Create = require(script.Parent.Parent.Components.Create)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local Panel = require(script.Parent.Parent.Components.Panel)
local Scale = require(script.Parent.Parent.Scale)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local ShortNumber = require(script.Parent.Parent.Components.ShortNumber)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

export type Callbacks = {
	buy: (crateId: string) -> (),
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
	destroy: (self: YardSale) -> (),
}

type Card = {
	crateId: string,
	frame: Frame,
	icon: ItemIcon.ItemIcon,
	name: TextLabel,
	market: TextLabel,
	buy: Button.Button,
	label: string,
	enabled: boolean?,
}

local MAX_SIZE = Vector2.new(480, 310)
local CARD_W = 200
local CARD_GAP = 14
local PICTURE = 76
local PENDING_SECONDS = 5 -- a buy with no answer lets the button go again after this long
local GAP = Theme.sizes.gap

local YardSale = {}
YardSale.__index = YardSale

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.modal.text,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
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
		name = "YardSale",
		title = "Yard Sale",
		subtitle = "Two crates a day for golden fish",
		color = Theme.colors.berry,
		icon = CampExtrasLogic.icon(CampExtrasLogic.YARD_SALE),
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
	self._have = text({
		Name = "Have",
		Position = UDim2.fromOffset(0, cardH + GAP),
		Size = UDim2.new(1, 0, 0, 20),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall,
		Parent = content,
	})
	self._note = text({
		Name = "Note",
		Position = UDim2.fromOffset(0, cardH + GAP + 20),
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = Theme.sizes.textTiny,
		TextColor3 = Theme.modal.subtext,
		Text = "Bought crates open free at the Golden Fish Market",
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

-- One card per crate in today's stock; rebuilt when the stock's crates change (a new day, a rank up).
function YardSale._build(self: any, rows: { CampExtrasLogic.YardRow })
	self:_clear()
	for index, row in rows do
		local crateId = row.crateId
		local crate = self:_crate(crateId)
		local frame: Frame = Create("Frame", {
			Name = crateId,
			BackgroundColor3 = Theme.modal.card,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Size = UDim2.fromOffset(CARD_W, self._cardH),
			Parent = self._row,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
			Create("UIStroke", { Color = Theme.modal.cardStroke, Thickness = Theme.sizes.stroke }),
		})
		local icon = ItemIcon.new({
			parent = frame,
			size = UDim2.fromOffset(PICTURE, PICTURE),
			anchorPoint = Vector2.new(0.5, 0),
			position = UDim2.new(0.5, 0, 0, 8),
		})
		icon:set(
			if crate ~= nil then (crate :: any).asset or ShopIcons.crateModel(crateId) else nil,
			Theme.icons.crate,
			if crate ~= nil and crate.golden then "Legendary" else "Rare",
			ShopIcons.crate(crateId)
		)
		local name = text({
			Name = "Name",
			Position = UDim2.fromOffset(6, PICTURE + 14),
			Size = UDim2.new(1, -12, 0, 22),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody + 1,
			Text = if crate ~= nil then crate.name else crateId,
			Parent = frame,
		})
		local marketPrice: number? = if crate ~= nil then crate.price else nil
		local market = text({
			Name = "Market",
			Position = UDim2.fromOffset(6, PICTURE + 36),
			Size = UDim2.new(1, -12, 0, 18),
			FontFace = Theme.fonts.bodyBold,
			TextSize = Theme.sizes.textSmall,
			TextColor3 = Theme.modal.subtext,
			Text = if marketPrice ~= nil then ("%d at the Market"):format(marketPrice) else "",
			Parent = frame,
		})
		local buy = Button.new({
			name = "Buy",
			text = tostring(row.price),
			icon = Theme.icons.goldenFish,
			style = "primary",
			size = UDim2.new(1, -16, 0, self._buyH),
			anchorPoint = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -8),
			textSize = Theme.sizes.textBody + 1,
			parent = frame,
			onClick = function()
				self:_press(crateId)
			end,
		})
		table.insert(self._cards, {
			crateId = crateId,
			frame = frame,
			icon = icon,
			name = name,
			market = market,
			buy = buy,
			label = tostring(row.price),
			enabled = nil,
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

function YardSale._paint(self: any)
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
			fish.Visible = not row.bought and not pending
		end
		local enabled = not row.bought and row.afford and self._pending == nil
		if card.enabled ~= enabled then
			card.enabled = enabled
			card.buy:setEnabled(enabled)
		end
		local faded = if row.bought then 0.5 else 0
		card.name.TextTransparency = faded
		card.market.TextTransparency = faded
	end
	local now = Workspace:GetServerTimeNow()
	self._have.Text = ("You have %s golden fish · %s"):format(
		ShortNumber.format(self._fish),
		CampExtrasLogic.yardFooter(self._view, now)
	)
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
	self:_clear()
	self._panel:destroy()
end

return YardSale
