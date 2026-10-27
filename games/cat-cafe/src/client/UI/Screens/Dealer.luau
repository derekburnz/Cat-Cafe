--!strict
-- Night dealer screen (F32, data-model section 8b), in the Grow a Garden seed shop style: "Fresh stock in
-- 4:12" across the top, then each food the dealer has for you this window with its stock, its odds and one
-- green price button. A food in two slots shows once as "x2 Stock" (Components/DealerRows). Odds, the shiny
-- chance and the charm star odds sit on every row before Buy (the growth thread's rules for random items), with
-- the per-cat split under Details. What is for sale comes only from UI.dealer.setStock (the DealerStock remote);
-- the screen never guesses stock, and the server recomputes it on every BuyDealerFood.
-- Opened by the cart's prompt (UI.dealer.open).

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local DealerRows = require(script.Parent.Parent.Components.DealerRows)
local FoodOdds = require(script.Parent.Parent.Components.FoodOdds)
local Format = require(script.Parent.Parent.Components.Format)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

export type Callbacks = {
	buy: (slot: number, lureId: string) -> (), -- the food too, so a Buy that lands after a restock is refused (S42)
	close: () -> (),
}

export type Dealer = {
	frame: Frame,
	setCatalog: (self: Dealer, catalog: Types.Catalog) -> (),
	render: (self: Dealer, state: Types.PlayerState) -> (),
	setStock: (self: Dealer, stock: Types.DealerStock?) -> (),
	-- true at night, false by day (the cart has gone), nil when the clock is unknown
	setNight: (self: Dealer, night: boolean?) -> (),
	-- true at the cart, false away from it, nil when the cart part is unknown (the server decides)
	setNear: (self: Dealer, near: boolean?) -> (),
	destroy: (self: Dealer) -> (),
}

local STRIP_HEIGHT = 84
local ROW_HEIGHT = 132
local ICON = 84
local BUTTON = Vector2.new(128, Theme.sizes.touchMin + 4)
local TEXT_LEFT = ICON + 28
local TEXT_RIGHT = BUTTON.X + 28
-- a Buy waits this long for the next DealerStock before the button comes back
local PENDING_SECONDS = 5

local Dealer = {}
Dealer.__index = Dealer

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

local function pill(parent: Instance, rarity: string, order: number): TextLabel
	return Create("TextLabel", {
		Name = "Rarity",
		BackgroundColor3 = Theme.rarityColor(rarity),
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textTiny,
		TextColor3 = Theme.rarityTextColor(rarity),
		Text = rarity .. " food",
		LayoutOrder = order,
		Parent = parent,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
	})
end

function Dealer.new(callbacks: Callbacks): Dealer
	local self = setmetatable({}, Dealer) :: any
	self._callbacks = callbacks
	self._rows = {} :: { any }
	self._lureById = {} :: { [string]: Types.LureDef }
	self._catalog = nil :: Types.Catalog?
	self._state = nil :: Types.PlayerState?
	self._stock = nil :: Types.DealerStock?
	self._night = nil :: boolean?
	self._near = nil :: boolean?
	self._pending = {} :: { [string]: number } -- lureId -> os.clock() when the wait for DealerStock ends
	self._tier = 0
	self._accumulator = 0

	local panel = Panel.new({
		name = "Dealer",
		title = "Night dealer",
		subtitle = "Rare foods for your bait bowl, sold only at night",
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = Vector2.new(720, 560), Parent = panel.frame })
	self._panel = panel
	self.frame = panel.frame

	-- Restock strip: the moon, "Fresh stock in 4:12" and a line on what to do
	local strip: Frame = Create("Frame", {
		Name = "Restock",
		BackgroundColor3 = Theme.colors.cocoaDeep,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -10, 0, STRIP_HEIGHT),
		Parent = panel.content,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	Outline.border(strip, Theme.sizes.outline)
	local moon: TextLabel = text({
		Name = "Moon",
		BackgroundColor3 = Theme.colors.skyDark,
		BackgroundTransparency = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(60, 60),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 32,
		Text = Theme.icons.moon,
		Parent = strip,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = moon })
	Outline.border(moon, 2)
	self._stripTitle = text({
		Name = "Title",
		Position = UDim2.fromOffset(86, 12),
		Size = UDim2.new(1, -100, 0, 28),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextColor3 = Theme.colors.white,
		Parent = strip,
	})
	Outline.text(self._stripTitle, 2)
	self._stripSub = text({
		Name = "Sub",
		Position = UDim2.fromOffset(86, 42),
		Size = UDim2.new(1, -100, 0, 34),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.hud.subtext,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = strip,
	})

	self._list = Create("ScrollingFrame", {
		Name = "Foods",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, STRIP_HEIGHT + Theme.sizes.gap + 4),
		Size = UDim2.new(1, 0, 1, -(STRIP_HEIGHT + Theme.sizes.gap + 4)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.colors.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel.content,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Create("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 6) }),
	})
	-- before the first DealerStock arrives, or when every food in it is unknown
	self._empty = text({
		Name = "Empty",
		Size = UDim2.new(1, 0, 0, 60),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.modal.subtext,
		TextWrapped = true,
		Text = "",
		Visible = false,
		Parent = self._list,
	})

	-- the countdown ticks once a second while the screen is open
	self._tick = RunService.Heartbeat:Connect(function(dt: number)
		if not self.frame.Visible then
			return
		end
		self._accumulator += dt
		if self._accumulator >= 1 then
			self._accumulator = 0
			self:_renderAll()
		end
	end)
	return self :: Dealer
end

function Dealer._clearRows(self: any)
	for _, row in self._rows do
		row.buy:destroy()
		row.details:destroy()
		row.icon:destroy()
		row.frame:Destroy()
	end
	table.clear(self._rows)
end

function Dealer._buildRows(self: any)
	self:_clearRows()
	local stock: Types.DealerStock? = self._stock
	if not stock then
		return
	end
	assert(stock, "stock")
	for index, group in DealerRows.group(stock, self._lureById) do
		local def = group.def
		local row: Frame = Create("Frame", {
			Name = group.lureId,
			BackgroundColor3 = Theme.modal.card,
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = index,
			Parent = self._list,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
			-- rarity colours on borders (world-and-feel section 6 style rules)
			Create(
				"UIStroke",
				{ Color = Theme.rarityColor(def.attracts), Thickness = Theme.sizes.stroke + 1 }
			),
			Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		local top: Frame = Create("Frame", {
			Name = "Top",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			LayoutOrder = 1,
			Parent = row,
		})
		local icon = ItemIcon.new({
			parent = top,
			size = UDim2.fromOffset(ICON, ICON),
			position = UDim2.fromOffset(12, 12),
		})
		icon:set(def.asset, Theme.foodIcons[def.id] or Theme.icons.food, def.attracts)
		local heading: Frame = Create("Frame", {
			Name = "Heading",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(TEXT_LEFT, 10),
			Size = UDim2.new(1, -(TEXT_LEFT + TEXT_RIGHT), 0, 26),
			Parent = top,
		}, {
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		text({
			Name = "Name",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 26),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textLarge - 2,
			Text = def.name,
			LayoutOrder = 1,
			Parent = heading,
		})
		pill(heading, def.attracts, 2)
		local stockLine: Frame = Create("Frame", {
			Name = "StockLine",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(TEXT_LEFT, 38),
			Size = UDim2.new(1, -(TEXT_LEFT + TEXT_RIGHT), 0, 20),
			Parent = top,
		}, {
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		local stockText = text({
			Name = "Stock",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 20),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textSmall + 1,
			LayoutOrder = 1,
			Parent = stockLine,
		})
		local have = text({
			Name = "Have",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 20),
			TextSize = Theme.sizes.textSmall,
			TextColor3 = Theme.modal.subtext,
			LayoutOrder = 2,
			Parent = stockLine,
		})
		text({
			Name = "Odds",
			Position = UDim2.fromOffset(TEXT_LEFT, 60),
			Size = UDim2.new(1, -(TEXT_LEFT + TEXT_RIGHT), 0, ROW_HEIGHT - 66),
			TextSize = Theme.sizes.textTiny,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = FoodOdds.line(def.odds) .. "\n" .. FoodOdds.extras(),
			Parent = top,
		})
		local lureId = group.lureId
		local buy = Button.new({
			name = "Buy",
			text = Format.money(group.cost),
			style = "primary",
			size = UDim2.fromOffset(BUTTON.X, BUTTON.Y),
			anchorPoint = Vector2.new(1, 0),
			position = UDim2.new(1, -12, 0, 12),
			textSize = Theme.sizes.textBody + 2,
			parent = top,
			onClick = function()
				self:_buy(lureId)
			end,
		})
		local details = Button.new({
			name = "Details",
			text = "Details",
			style = "ghost",
			size = UDim2.fromOffset(BUTTON.X, 34),
			anchorPoint = Vector2.new(1, 0),
			position = UDim2.new(1, -12, 0, 12 + BUTTON.Y + 10),
			textSize = Theme.sizes.textSmall,
			parent = top,
			onClick = function()
				self:_toggleDetail(lureId)
			end,
		})
		local detail = text({
			Name = "Detail",
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			TextSize = Theme.sizes.textTiny,
			TextColor3 = Theme.modal.subtext,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			TextYAlignment = Enum.TextYAlignment.Top,
			Visible = false,
			LayoutOrder = 2,
			Parent = row,
		})
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 16),
			PaddingBottom = UDim.new(0, 12),
			Parent = detail,
		})
		table.insert(self._rows, {
			frame = row,
			icon = icon,
			stock = stockText,
			have = have,
			buy = buy,
			details = details,
			detail = detail,
			group = group,
		})
	end
	self._tier = -1 -- rebuild the split text on the next render
end

function Dealer._toggleDetail(self: any, lureId: string)
	for _, row in self._rows do
		if row.group.lureId == lureId then
			row.detail.Visible = not row.detail.Visible
			row.details:setText(if row.detail.Visible then "Hide details" else "Details")
		end
	end
end

-- Buy sends the first slot of this food not bought yet, then waits for the server's next DealerStock.
function Dealer._buy(self: any, lureId: string)
	for _, row in self._rows do
		local group: DealerRows.Row = row.group
		if group.lureId == lureId and #group.open > 0 and self:_canBuy(group) then
			self._pending[lureId] = os.clock() + PENDING_SECONDS
			self._callbacks.buy(group.open[1], lureId)
			self:_renderAll()
			return
		end
	end
end

-- Why buying is closed for every row right now, or nil when it is open.
function Dealer._closedReason(self: any): string?
	local stock: Types.DealerStock? = self._stock
	if self._night == false then
		return "day"
	elseif stock == nil then
		return "loading"
	elseif (stock :: Types.DealerStock).restocksAt - Workspace:GetServerTimeNow() <= 0 then
		return "restocking"
	elseif self._near == false then
		return "away"
	end
	return nil
end

function Dealer._canBuy(self: any, group: DealerRows.Row): boolean
	local state: Types.PlayerState? = self._state
	if self:_closedReason() ~= nil or state == nil then
		return false
	end
	local pendingUntil: number? = self._pending[group.lureId]
	if pendingUntil and os.clock() < pendingUntil then
		return false
	end
	return #group.open > 0 and (state :: Types.PlayerState).money >= group.cost
end

function Dealer.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	table.clear(self._lureById)
	for _, def in catalog.lures do
		self._lureById[def.id] = def
	end
	self:_buildRows()
	self:_renderAll()
end

function Dealer.setStock(self: any, stock: Types.DealerStock?)
	self._stock = stock
	table.clear(self._pending) -- the server answered: its stock is the truth now
	self:_buildRows()
	self:_renderAll()
end

function Dealer.setNight(self: any, night: boolean?)
	if self._night == night then
		return
	end
	self._night = night
	self:_renderAll()
end

function Dealer.setNear(self: any, near: boolean?)
	if self._near == near then
		return
	end
	self._near = near
	self:_renderAll()
end

function Dealer.render(self: any, state: Types.PlayerState)
	self._state = state
	if not self.frame.Visible then
		return -- money ticks re-render every screen; this one catches up when it opens
	end
	self:_renderAll()
end

function Dealer._renderAll(self: any)
	self:_renderStrip()
	local state: Types.PlayerState? = self._state
	if not state then
		return
	end
	assert(state, "state")
	local catalog: Types.Catalog? = self._catalog
	if catalog and state.tier ~= self._tier then
		self._tier = state.tier
		for _, row in self._rows do
			local def: Types.LureDef = row.group.def
			row.detail.Text = def.description .. "\n" .. FoodOdds.split(catalog, def, state.tier)
		end
	end
	for _, row in self._rows do
		local group: DealerRows.Row = row.group
		local left = #group.open
		local pendingUntil: number? = self._pending[group.lureId]
		local pending = pendingUntil ~= nil and os.clock() < pendingUntil
		row.stock.Text = if left > 0 then ("x%d Stock"):format(left) else "Sold out"
		row.stock.TextColor3 = if left > 0 then Theme.colors.good else Theme.colors.red
		local have = state.lures[group.lureId] or 0
		row.have.Text = if have > 0 then ("You have %d"):format(have) else ""
		row.buy:setText(
			if pending
				then "Buying..."
				elseif left == 0 then "Sold out"
				else Format.money(group.cost)
		)
		row.buy:setEnabled(self:_canBuy(group))
	end
	local stock: Types.DealerStock? = self._stock
	self._empty.Visible = #self._rows == 0
	self._empty.Text = if stock == nil
		then "The dealer is unpacking his cart..."
		else "Nothing left on the cart this time. Fresh stock is on the way."
end

-- The strip's states: closed by day, unpacking, restocking, away from the cart, and open with the countdown.
function Dealer._renderStrip(self: any)
	local stock: Types.DealerStock? = self._stock
	local reason = self:_closedReason()
	local title: string
	local sub: string
	if reason == "day" then
		title = "Closed until nightfall"
		sub = "The dealer packs up his cart at dawn and comes back when night falls."
	elseif reason == "loading" or stock == nil then
		title = "Opening the cart..."
		sub = "His stock shows in a moment."
	elseif reason == "restocking" then
		title = "Fresh stock coming..."
		sub = "The dealer is restocking. New foods show in a moment."
	else
		local current = stock :: Types.DealerStock
		title = "Fresh stock in "
			.. DealerRows.clock(current.restocksAt - Workspace:GetServerTimeNow())
		sub = if reason == "away"
			then "Walk back to the cart to buy."
			else "Each slot sells once per stock. Dealer food goes in your bait bowl like any food."
	end
	self._stripTitle.Text = title
	self._stripSub.Text = sub
end

function Dealer.destroy(self: any)
	self._tick:Disconnect()
	self:_clearRows()
	self._panel:destroy()
end

return Dealer
