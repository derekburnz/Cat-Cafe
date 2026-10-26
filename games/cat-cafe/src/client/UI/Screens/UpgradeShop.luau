--!strict
-- Upgrades screen: one row per upgrade with level pips, description and a Buy button.
-- Rows are built once per catalog and only their text and button state change on render.

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local Format = require(script.Parent.Parent.Components.Format)
local Panel = require(script.Parent.Parent.Components.Panel)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

export type UpgradeShop = {
	frame: Frame,
	setCatalog: (self: UpgradeShop, catalog: Types.Catalog) -> (),
	render: (self: UpgradeShop, state: Types.PlayerState) -> (),
	destroy: (self: UpgradeShop) -> (),
}

local ROW_HEIGHT = 88
local MAX_PIPS = 8

local UpgradeShop = {}
UpgradeShop.__index = UpgradeShop

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

function UpgradeShop.new(onBuy: (upgradeId: string) -> (), onClose: () -> ()): UpgradeShop
	local self = setmetatable({}, UpgradeShop) :: any
	self._onBuy = onBuy
	self._rows = {} :: { [string]: any }
	self._catalog = nil :: Types.Catalog?
	self._dirty = true
	self._lastState = nil :: Types.PlayerState?

	local panel = Panel.new({
		name = "Upgrades",
		title = "Upgrades",
		subtitle = "Cafe Lv 1",
		size = UDim2.fromScale(1, 1),
		onClose = onClose,
	})
	Create("UISizeConstraint", { MaxSize = Vector2.new(760, 560), Parent = panel.frame })
	self._panel = panel
	self.frame = panel.frame

	self._list = Create("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
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
		Create("UIPadding", { PaddingRight = UDim.new(0, 10) }),
	})

	return self :: UpgradeShop
end

function UpgradeShop._buildRows(self: any)
	for _, row in self._rows do
		row.buy:destroy()
		row.frame:Destroy()
	end
	table.clear(self._rows)
	local catalog: Types.Catalog? = self._catalog
	if not catalog then
		return
	end
	assert(catalog)

	for index, upgrade in catalog.upgrades do
		local row: Frame = Create("Frame", {
			Name = upgrade.id,
			BackgroundColor3 = Theme.modal.card,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			LayoutOrder = index,
			Parent = self._list,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
			Create("UIStroke", { Color = Theme.modal.cardStroke, Thickness = Theme.sizes.stroke }),
		})

		local name = text({
			Name = "Name",
			Position = UDim2.fromOffset(16, 10),
			Size = UDim2.new(1, -200, 0, 26),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textLarge - 2,
			Text = upgrade.name,
			Parent = row,
		})
		local level = text({
			Name = "Level",
			Position = UDim2.fromOffset(16, 38),
			Size = UDim2.new(1, -200, 0, 18),
			TextSize = Theme.sizes.textSmall,
			TextColor3 = Theme.modal.subtext,
			Text = "",
			Parent = row,
		})
		local description = text({
			Name = "Description",
			Position = UDim2.fromOffset(16, 58),
			Size = UDim2.new(1, -200, 0, 20),
			TextSize = Theme.sizes.textSmall,
			TextColor3 = Theme.modal.subtext,
			Text = upgrade.description,
			Parent = row,
		})

		-- level pips, right of the name
		local pipCount = math.min(upgrade.maxLevel, MAX_PIPS)
		local pips: Frame = Create("Frame", {
			Name = "Pips",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -164, 0, 14),
			Size = UDim2.fromOffset(pipCount * 14, 10),
			Parent = row,
		}, {
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		local pipFrames = {}
		for pip = 1, pipCount do
			table.insert(
				pipFrames,
				Create("Frame", {
					Name = "Pip",
					BackgroundColor3 = Theme.colors.line,
					BorderSizePixel = 0,
					Size = UDim2.fromOffset(10, 10),
					LayoutOrder = pip,
					Parent = pips,
				}, { Create("UICorner", { CornerRadius = UDim.new(0, 3) }) })
			)
		end

		local buy = Button.new({
			name = "Buy",
			text = "",
			style = "primary",
			size = UDim2.fromOffset(136, Theme.sizes.touchMin + 4),
			anchorPoint = Vector2.new(1, 0.5),
			position = UDim2.new(1, -12, 0.5, 0),
			textSize = Theme.sizes.textBody,
			parent = row,
			onClick = function()
				self._onBuy(upgrade.id)
			end,
		})

		self._rows[upgrade.id] = {
			frame = row,
			name = name,
			level = level,
			description = description,
			pips = pipFrames,
			buy = buy,
			def = upgrade,
		}
	end
end

function UpgradeShop.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	self:_buildRows()
	self._dirty = true
end

function UpgradeShop.render(self: any, state: Types.PlayerState)
	self._lastState = state
	if not self.frame.Visible then
		self._dirty = true
		return
	end
	self._dirty = false
	local cafeLevel = state.cafeLevel
	self._panel:setTitle(
		"Upgrades",
		"Cafe " .. Format.level(cafeLevel) .. "  ·  " .. Format.money(state.coins)
	)

	for upgradeId, row in self._rows do
		local def: Types.UpgradeDef = row.def
		local level = state.upgradeLevels[upgradeId] or 0
		local isMax = level >= def.maxLevel
		local nextCost = if isMax then nil else def.costs[level + 1]
		local locked = def.requiresCafeLevel ~= nil
			and cafeLevel < (def.requiresCafeLevel :: number)

		if isMax then
			row.level.Text = Format.level(level) .. "  ·  Max"
		elseif level == 0 then
			row.level.Text = "Not bought yet"
		else
			row.level.Text = Format.level(level) .. "  →  " .. Format.level(level + 1)
		end

		for pipIndex, pip in row.pips do
			local filled = pipIndex <= level
			pip.BackgroundColor3 = if filled then Theme.colors.good else Theme.colors.line
		end

		if isMax then
			row.buy:setText("Max")
			row.buy:setEnabled(false)
		elseif locked then
			row.buy:setText("Cafe " .. Format.level(def.requiresCafeLevel :: number))
			row.buy:setEnabled(false)
		elseif nextCost == nil then
			row.buy:setText("—")
			row.buy:setEnabled(false)
		else
			row.buy:setText(Format.money(nextCost))
			row.buy:setStyle("primary")
			row.buy:setEnabled(state.coins >= nextCost)
		end
	end
end

function UpgradeShop.destroy(self: any)
	for _, row in self._rows do
		row.buy:destroy()
	end
	self._panel:destroy()
end

return UpgradeShop
