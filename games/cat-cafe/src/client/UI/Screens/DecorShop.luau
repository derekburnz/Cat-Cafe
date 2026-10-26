--!strict
-- Decor screen: category chips across the top, a grid of cards below.
-- A card shows cost, Place or Remove depending on what the player owns.

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local Format = require(script.Parent.Parent.Components.Format)
local Panel = require(script.Parent.Parent.Components.Panel)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

export type Callbacks = {
	buyDecor: (decorId: string) -> (),
	toggleDecor: (decorId: string, placed: boolean) -> (),
	close: () -> (),
}

export type DecorShop = {
	frame: Frame,
	setCatalog: (self: DecorShop, catalog: Types.Catalog) -> (),
	render: (self: DecorShop, state: Types.PlayerState) -> (),
	destroy: (self: DecorShop) -> (),
}

local CARD = Vector2.new(164, 196)
local CHIP_HEIGHT = 36

-- Placeholder art colour per category until the asset thread delivers images.
local CATEGORY_COLORS: { [string]: Color3 } = {
	Plants = Color3.fromHex("5FB85A"),
	Floor = Color3.fromHex("D97B4B"),
	Wall = Color3.fromHex("E8A0A0"),
	Furniture = Color3.fromHex("8FD3C1"),
	Toys = Color3.fromHex("FFC94D"),
}

local DecorShop = {}
DecorShop.__index = DecorShop

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

function DecorShop.new(callbacks: Callbacks): DecorShop
	local self = setmetatable({}, DecorShop) :: any
	self._callbacks = callbacks
	self._cards = {} :: { [string]: any }
	self._chips = {} :: { any }
	self._filter = "All"
	self._catalog = nil :: Types.Catalog?
	self._dirty = true

	local panel = Panel.new({
		name = "Decor",
		title = "Decor",
		subtitle = "Make the cafe yours",
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = Vector2.new(760, 560), Parent = panel.frame })
	self._panel = panel
	self.frame = panel.frame

	self._chipRow = Create("ScrollingFrame", {
		Name = "Chips",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, CHIP_HEIGHT),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		Parent = panel.content,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	self._grid = Create("ScrollingFrame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, CHIP_HEIGHT + Theme.sizes.gap),
		Size = UDim2.new(1, 0, 1, -(CHIP_HEIGHT + Theme.sizes.gap)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.colors.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel.content,
	}, {
		Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(CARD.X, CARD.Y),
			CellPadding = UDim2.fromOffset(Theme.sizes.gap, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
		}),
		Create("UIPadding", { PaddingRight = UDim.new(0, 10) }),
	})

	return self :: DecorShop
end

function DecorShop._setFilter(self: any, category: string)
	self._filter = category
	for _, chip in self._chips do
		chip.button:setStyle(if chip.category == category then "gold" else "ghost")
	end
	for _, card in self._cards do
		card.frame.Visible = category == "All" or card.def.category == category
	end
end

function DecorShop._build(self: any)
	for _, chip in self._chips do
		chip.button:destroy()
	end
	table.clear(self._chips)
	for _, card in self._cards do
		card.action:destroy()
		card.frame:Destroy()
	end
	table.clear(self._cards)

	local catalog: Types.Catalog? = self._catalog
	if not catalog then
		return
	end
	assert(catalog)

	-- chips: All + each category in catalog order
	local categories = { "All" }
	for _, decor in catalog.decor do
		if not table.find(categories, decor.category) then
			table.insert(categories, decor.category)
		end
	end
	for index, category in categories do
		local button = Button.new({
			name = category,
			text = category,
			style = "ghost",
			size = UDim2.fromOffset(math.max(84, #category * 11 + 28), CHIP_HEIGHT),
			textSize = Theme.sizes.textSmall,
			layoutOrder = index,
			parent = self._chipRow,
			onClick = function()
				self:_setFilter(category)
			end,
		})
		table.insert(self._chips, { category = category, button = button })
	end

	for index, decor in catalog.decor do
		local card: Frame = Create("Frame", {
			Name = decor.id,
			BackgroundColor3 = Theme.modal.card,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Parent = self._grid,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
			Create("UIStroke", { Color = Theme.modal.cardStroke, Thickness = Theme.sizes.stroke }),
		})

		-- art: image when provided, otherwise a coloured block with the first letter
		local art: Frame = Create("Frame", {
			Name = "Art",
			BackgroundColor3 = CATEGORY_COLORS[decor.category] or Theme.colors.mint,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.new(1, -20, 0, 76),
			Parent = card,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }) })
		if decor.imageId then
			Create("ImageLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Image = decor.imageId,
				ScaleType = Enum.ScaleType.Fit,
				Parent = art,
			})
		else
			text({
				Size = UDim2.fromScale(1, 1),
				FontFace = Theme.fonts.display,
				TextSize = 34,
				TextColor3 = Theme.colors.paper,
				TextXAlignment = Enum.TextXAlignment.Center,
				Text = decor.name:sub(1, 1),
				Parent = art,
			})
		end
		local owned = text({
			Name = "Owned",
			BackgroundColor3 = Theme.colors.good,
			BackgroundTransparency = 0,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -16, 0, 16),
			Size = UDim2.fromOffset(56, 20),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textTiny,
			TextColor3 = Theme.colors.goodText,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = "Owned",
			Visible = false,
			Parent = card,
		})
		Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = owned })

		text({
			Name = "Name",
			Position = UDim2.fromOffset(10, 92),
			Size = UDim2.new(1, -20, 0, 22),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody,
			Text = decor.name,
			Parent = card,
		})
		text({
			Name = "Effect",
			Position = UDim2.fromOffset(10, 114),
			Size = UDim2.new(1, -20, 0, 18),
			TextSize = Theme.sizes.textTiny,
			TextColor3 = Theme.modal.subtext,
			Text = decor.effect or decor.description or "",
			Parent = card,
		})

		local action = Button.new({
			name = "Action",
			text = Format.money(decor.cost),
			style = "primary",
			size = UDim2.new(1, -20, 0, Theme.sizes.touchMin),
			position = UDim2.new(0, 10, 1, -(Theme.sizes.touchMin + 10)),
			textSize = Theme.sizes.textSmall + 1,
			parent = card,
			onClick = function()
				local entry = self._cards[decor.id]
				if entry.mode == "buy" then
					self._callbacks.buyDecor(decor.id)
				elseif entry.mode == "place" then
					self._callbacks.toggleDecor(decor.id, true)
				elseif entry.mode == "remove" then
					self._callbacks.toggleDecor(decor.id, false)
				end
			end,
		})

		self._cards[decor.id] =
			{ frame = card, owned = owned, action = action, def = decor, mode = "buy" }
	end
	self:_setFilter("All")
end

function DecorShop.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	self:_build()
	self._dirty = true
end

function DecorShop.render(self: any, state: Types.PlayerState)
	if not self.frame.Visible then
		self._dirty = true
		return
	end
	self._dirty = false
	local placedCount = 0
	for _, placed in state.decorPlaced do
		if placed then
			placedCount += 1
		end
	end
	self._panel:setTitle(
		"Decor",
		("%d placed  ·  %s"):format(placedCount, Format.money(state.coins))
	)

	for decorId, card in self._cards do
		local def: Types.DecorDef = card.def
		local isOwned = state.decorOwned[decorId] == true
		local isPlaced = state.decorPlaced[decorId] == true
		local locked = def.requiresCafeLevel ~= nil
			and state.cafeLevel < (def.requiresCafeLevel :: number)
		card.owned.Visible = isOwned
		if isOwned and isPlaced then
			card.mode = "remove"
			card.action:setText("Remove")
			card.action:setStyle("ghost")
			card.action:setEnabled(true)
		elseif isOwned then
			card.mode = "place"
			card.action:setText("Place")
			card.action:setStyle("secondary")
			card.action:setEnabled(true)
		elseif locked then
			card.mode = "locked"
			card.action:setText("Cafe " .. Format.level(def.requiresCafeLevel :: number))
			card.action:setEnabled(false)
		else
			card.mode = "buy"
			card.action:setText(Format.money(def.cost))
			card.action:setStyle("primary")
			card.action:setEnabled(state.coins >= def.cost)
		end
	end
end

function DecorShop.destroy(self: any)
	for _, chip in self._chips do
		chip.button:destroy()
	end
	for _, card in self._cards do
		card.action:destroy()
	end
	self._panel:destroy()
end

return DecorShop
