--!strict
-- Always-on overlay: money and income (top left), cafe level pill (top centre), cat count (top right),
-- menu buttons (left), equipped lure slot with an odds picker (bottom right), carry banner and
-- tutorial strip (bottom centre). Laid out in design pixels under one UIScale from Scale.bind.

local UserInputService = game:GetService("UserInputService")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local Format = require(script.Parent.Parent.Components.Format)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

export type Callbacks = {
	openScreen: (name: Types.ScreenName) -> (),
	buyLure: (lureId: string) -> (),
	equipLure: (lureId: string) -> (),
}

export type HUD = {
	screenGui: ScreenGui,
	setCatalog: (self: HUD, catalog: Types.Catalog) -> (),
	render: (self: HUD, state: Types.PlayerState) -> (),
	setCarrying: (self: HUD, info: Types.CarryInfo?) -> (),
	setTutorial: (self: HUD, text: string?) -> (),
	togglePicker: (self: HUD) -> (),
	setVisible: (self: HUD, visible: boolean) -> (),
	destroy: (self: HUD) -> (),
}

local MARGIN = 16
local LURE_ROW = 70

local HUD = {}
HUD.__index = HUD

local function hudPanel(name: string, props: { [string]: any }): Frame
	local merged: { [string]: any } = {
		Name = name,
		BackgroundColor3 = Theme.hud.panel,
		BackgroundTransparency = Theme.hud.panelTransparency,
		BorderSizePixel = 0,
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("Frame", merged, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", {
			Color = Theme.hud.stroke,
			Transparency = Theme.hud.strokeTransparency,
			Thickness = Theme.sizes.stroke,
		}),
	})
end

local function label(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.hud.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

local function keycap(parent: Instance, text: string, position: UDim2, anchor: Vector2?): TextLabel
	return Create("TextLabel", {
		Name = "Key",
		BackgroundColor3 = Theme.colors.paper,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(22, 22),
		Position = position,
		AnchorPoint = anchor or Vector2.new(),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.colors.ink,
		Text = text,
		ZIndex = 5,
		Parent = parent,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 5) }) })
end

local function rarityPill(
	parent: Instance,
	rarity: string,
	position: UDim2,
	anchor: Vector2?
): TextLabel
	return Create("TextLabel", {
		Name = "Rarity",
		BackgroundColor3 = Theme.rarityColor(rarity),
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 18),
		Position = position,
		AnchorPoint = anchor or Vector2.new(),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textTiny,
		TextColor3 = Theme.rarityTextColor(rarity),
		Text = rarity,
		Parent = parent,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
	})
end

local function percent(value: number): string
	local text = string.format(if value >= 10 then "%.0f" else "%.1f", value)
	text = text:gsub("%.0$", "")
	return text .. "%"
end

-- "Odds: 70% Common · 26% Rare · 3.5% Epic · 0.5% Legendary" (the growth thread's rule: labelled, never an icon)
local function oddsText(odds: Types.LureOdds?): string
	if not odds then
		return "Odds: not set"
	end
	assert(odds)
	return ("Odds: %s Common · %s Rare · %s Epic · %s Legendary"):format(
		percent(odds.Common),
		percent(odds.Rare),
		percent(odds.Epic),
		percent(odds.Legendary)
	)
end

-- Per-cat split, derived from the catalog: every cat of a rarity in an area has the same chance.
-- "Alley · Rare 42%: Calico 21%, Siamese 21%"
local function oddsDetail(catalog: Types.Catalog, lure: Types.LureDef): string
	local odds = lure.odds
	if not odds then
		return "Odds not set for this food yet."
	end
	assert(odds)
	local areas = { "alley", "park" }
	local lines = { "Same chance for every cat of a rarity in the area:" }
	for _, area in areas do
		for _, rarity in Theme.rarityOrder do
			local share = (odds :: any)[rarity]
			if type(share) ~= "number" or share <= 0 then
				continue
			end
			local names = {}
			for _, def in catalog.cats do
				if
					def.rarity == rarity
					and (def.area == nil or def.area == "both" or def.area == area)
				then
					table.insert(names, def.name)
				end
			end
			if #names == 0 then
				continue
			end
			local each = share / #names
			local parts = {}
			for _, name in names do
				table.insert(parts, ("%s %s"):format(name, percent(each)))
			end
			table.insert(
				lines,
				("%s · %s %s: %s"):format(
					area:sub(1, 1):upper() .. area:sub(2),
					rarity,
					percent(share),
					table.concat(parts, ", ")
				)
			)
		end
	end
	return table.concat(lines, "\n")
end

function HUD.new(parent: Instance, callbacks: Callbacks): HUD
	local self = setmetatable({}, HUD) :: any
	self._callbacks = callbacks
	self._connections = {} :: { RBXScriptConnection }
	self._buttons = {} :: { any }
	self._lureRows = {} :: { [string]: any }
	self._catalog = nil :: Types.Catalog?
	self._pickerOpen = false
	self._lastMoney = nil :: number?

	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeHUD",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10,
	})
	self.screenGui = screenGui

	local root: Frame = Create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui,
	})
	self._root = root
	self._uiScale = Scale.bind(root)

	-- Money panel (top left)
	local money = hudPanel("Money", {
		Position = UDim2.fromOffset(MARGIN, MARGIN),
		Size = UDim2.fromOffset(276, 80),
		Parent = root,
	})
	Create("Frame", {
		Name = "Coin",
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.fromOffset(40, 40),
		Parent = money,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIStroke", { Color = Theme.colors.goldDark, Thickness = 3 }),
		label({
			Size = UDim2.fromScale(1, 1),
			FontFace = Theme.fonts.display,
			TextSize = 22,
			TextColor3 = Theme.colors.goldText,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = Theme.currencySymbol,
		}),
	})
	self._moneyText = label({
		Name = "Amount",
		Position = UDim2.fromOffset(66, 10),
		Size = UDim2.new(1, -78, 0, 34),
		FontFace = Theme.fonts.display,
		TextSize = 28,
		Text = Format.money(0),
		Parent = money,
	})
	self._incomeText = label({
		Name = "Income",
		Position = UDim2.fromOffset(66, 46),
		Size = UDim2.new(1, -78, 0, 22),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.hud.income,
		Text = "",
		Parent = money,
	})

	-- Cafe pill (top centre)
	local cafe = hudPanel("Cafe", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, MARGIN),
		Size = UDim2.fromOffset(340, 52),
		Parent = root,
	})
	self._cafeTitle = label({
		Name = "Title",
		Position = UDim2.fromOffset(16, 6),
		Size = UDim2.new(1, -32, 0, 24),
		FontFace = Theme.fonts.display,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Cafe Lv 1",
		Parent = cafe,
	})
	self._cafeSub = label({
		Name = "Sub",
		Position = UDim2.fromOffset(16, 28),
		Size = UDim2.new(1, -32, 0, 16),
		TextSize = Theme.sizes.textTiny,
		TextColor3 = Theme.hud.subtext,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
		Parent = cafe,
	})
	local track: Frame = Create("Frame", {
		Name = "Progress",
		BackgroundColor3 = Theme.colors.paper,
		BackgroundTransparency = 0.8,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 16, 1, -8),
		Size = UDim2.new(1, -32, 0, 4),
		Visible = false,
		Parent = cafe,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	self._cafeTrack = track
	self._cafeFill = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.colors.mint,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })

	-- Cats pill (top right)
	local cats = hudPanel("Cats", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -MARGIN, 0, MARGIN),
		Size = UDim2.fromOffset(250, 52),
		Parent = root,
	})
	self._catsText = label({
		Name = "Count",
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -140, 1, 0),
		FontFace = Theme.fonts.display,
		TextSize = 18,
		Text = "Cats 0 / 0",
		Parent = cats,
	})
	table.insert(
		self._buttons,
		Button.new({
			name = "Collection",
			text = "Collection",
			style = "secondary",
			size = UDim2.fromOffset(110, 36),
			anchorPoint = Vector2.new(1, 0.5),
			position = UDim2.new(1, -8, 0.5, 0),
			textSize = Theme.sizes.textSmall,
			parent = cats,
			onClick = function()
				callbacks.openScreen("Collection")
			end,
		})
	)

	-- Menu stack (left, vertically centred)
	local menu: Frame = Create("Frame", {
		Name = "Menu",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, MARGIN, 0.5, 0),
		Size = UDim2.fromOffset(124, 3 * 56 + 2 * Theme.sizes.gap),
		Parent = root,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local showKeys = UserInputService.KeyboardEnabled
	type MenuItem = { label: string, screen: Types.ScreenName, key: string, style: Button.Style }
	local menuItems: { MenuItem } = {
		{ label = "Upgrades", screen = "Upgrades", key = "U", style = "primary" },
		{ label = "Decor", screen = "Decor", key = "B", style = "gold" },
		{ label = "Cats", screen = "Collection", key = "C", style = "secondary" },
	}
	for index, item in menuItems do
		local button = Button.new({
			name = item.label,
			text = item.label,
			style = item.style,
			size = UDim2.fromOffset(124, 56),
			textSize = Theme.sizes.textBody + 2,
			layoutOrder = index,
			parent = menu,
			onClick = function()
				callbacks.openScreen(item.screen)
			end,
		})
		if showKeys then
			keycap(button.face, item.key, UDim2.new(1, -4, 0, 4), Vector2.new(1, 0))
		end
		table.insert(self._buttons, button)
	end

	-- Lure slot (bottom right)
	local lureSlot: TextButton = Create("TextButton", {
		Name = "LureSlot",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.hud.panel,
		BackgroundTransparency = Theme.hud.panelTransparency,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -MARGIN, 1, -MARGIN),
		Size = UDim2.fromOffset(150, 64),
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", {
			Color = Theme.hud.stroke,
			Transparency = Theme.hud.strokeTransparency,
			Thickness = Theme.sizes.stroke,
		}),
	})
	self._lureSlot = lureSlot
	self._lureName = label({
		Name = "Name",
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 22),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody,
		Text = "No lure",
		Parent = lureSlot,
	})
	self._lureCount = label({
		Name = "Count",
		Position = UDim2.fromOffset(12, 32),
		Size = UDim2.new(1, -24, 0, 20),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.hud.subtext,
		Text = "Tap to choose",
		Parent = lureSlot,
	})
	if showKeys then
		keycap(lureSlot, "F", UDim2.new(1, -6, 0, 6), Vector2.new(1, 0))
	end
	table.insert(
		self._connections,
		lureSlot.Activated:Connect(function()
			self:togglePicker()
		end)
	)

	-- Lure picker (pops up above the slot). Odds are printed on every row, before any purchase.
	local picker = hudPanel("LurePicker", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -MARGIN, 1, -(MARGIN + 64 + Theme.sizes.gap)),
		Size = UDim2.fromOffset(420, 60),
		Visible = false,
		Parent = root,
	})
	self._picker = picker
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, Theme.sizes.gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = picker,
	})
	Create("UIPadding", {
		PaddingTop = UDim.new(0, Theme.sizes.padding),
		PaddingBottom = UDim.new(0, Theme.sizes.padding),
		PaddingLeft = UDim.new(0, Theme.sizes.padding),
		PaddingRight = UDim.new(0, Theme.sizes.padding),
		Parent = picker,
	})
	label({
		Name = "Heading",
		Size = UDim2.new(1, 0, 0, 20),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody,
		Text = "Lure food",
		LayoutOrder = 0,
		Parent = picker,
	})

	-- Carry banner (bottom centre)
	local carry = hudPanel("Carry", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -MARGIN),
		Size = UDim2.fromOffset(380, 56),
		Visible = false,
		Parent = root,
	})
	self._carry = carry
	self._carryArt = Create("Frame", {
		Name = "Art",
		BackgroundColor3 = Theme.colors.line,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(36, 36),
		Parent = carry,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	self._carryTitle = label({
		Name = "Title",
		Position = UDim2.fromOffset(56, 8),
		Size = UDim2.new(1, -68, 0, 22),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 1,
		Text = "Carrying a cat",
		Parent = carry,
	})
	self._carrySub = label({
		Name = "Sub",
		Position = UDim2.fromOffset(56, 30),
		Size = UDim2.new(1, -68, 0, 18),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.hud.subtext,
		Text = "Walk home and check in at your door",
		Parent = carry,
	})

	-- Tutorial strip (bottom centre, above the carry banner when both show)
	self._tutorial = label({
		Name = "Tutorial",
		BackgroundColor3 = Theme.colors.gold,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -MARGIN),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 40),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.colors.goldText,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
		Visible = false,
		Parent = root,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = self._tutorial })
	Create(
		"UIPadding",
		{ PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18), Parent = self._tutorial }
	)
	Create("UISizeConstraint", { MaxSize = Vector2.new(520, 40), Parent = self._tutorial })

	if parent then
		screenGui.Parent = parent
	end
	return self :: HUD
end

function HUD.togglePicker(self: any)
	self._pickerOpen = not self._pickerOpen
	self._picker.Visible = self._pickerOpen
	if self._pickerOpen then
		Tween.popIn(self._picker, 0.94)
	end
end

function HUD._buildLureRows(self: any)
	for _, row in self._lureRows do
		row.equip:destroy()
		row.buy:destroy()
		row.details:destroy()
		row.frame:Destroy()
	end
	table.clear(self._lureRows)
	local catalog: Types.Catalog? = self._catalog
	if not catalog then
		return
	end
	assert(catalog)
	for index, lure in catalog.lures do
		local row: Frame = Create("Frame", {
			Name = lure.id,
			BackgroundColor3 = Theme.colors.paper,
			BackgroundTransparency = 0.92,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, LURE_ROW),
			LayoutOrder = index,
			Parent = self._picker,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }) })
		label({
			Name = "Name",
			Position = UDim2.fromOffset(10, 6),
			Size = UDim2.new(1, -260, 0, 20),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody,
			Text = lure.name,
			Parent = row,
		})
		local countLabel = label({
			Name = "Count",
			Position = UDim2.fromOffset(10, 26),
			Size = UDim2.new(1, -180, 0, 18),
			TextSize = Theme.sizes.textTiny,
			TextColor3 = Theme.hud.subtext,
			Text = "",
			Parent = row,
		})
		label({
			Name = "Odds",
			Position = UDim2.fromOffset(10, 46),
			Size = UDim2.new(1, -100, 0, 18),
			TextSize = Theme.sizes.textTiny,
			TextColor3 = Theme.hud.text,
			Text = oddsText(lure.odds),
			Parent = row,
		})
		rarityPill(row, lure.attracts, UDim2.new(1, -176, 0, 7), Vector2.new(1, 0))
		local detail = label({
			Name = "Detail",
			Position = UDim2.fromOffset(10, LURE_ROW),
			Size = UDim2.new(1, -20, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextSize = Theme.sizes.textTiny,
			TextColor3 = Theme.hud.subtext,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = oddsDetail(catalog, lure),
			Visible = false,
			Parent = row,
		})
		-- "Details" is a labelled control, not an icon (Roblox paid random items guidance, growth thread)
		local details = Button.new({
			name = "Details",
			text = "Details",
			style = "ghost",
			size = UDim2.fromOffset(78, 32),
			anchorPoint = Vector2.new(1, 0),
			position = UDim2.new(1, -6, 0, 48),
			textSize = Theme.sizes.textTiny,
			parent = row,
			onClick = function()
				self:_toggleDetail(lure.id)
			end,
		})
		-- Equip and Buy are the same size and weight on purpose (growth thread: no nudging toward the spend)
		local equip = Button.new({
			name = "Equip",
			text = "Equip",
			style = "secondary",
			size = UDim2.fromOffset(78, 40),
			anchorPoint = Vector2.new(1, 0),
			position = UDim2.new(1, -92, 0, 4),
			textSize = Theme.sizes.textSmall,
			parent = row,
			onClick = function()
				self._callbacks.equipLure(lure.id)
			end,
		})
		local buy = Button.new({
			name = "Buy",
			text = Format.money(lure.cost),
			style = "primary",
			size = UDim2.fromOffset(78, 40),
			anchorPoint = Vector2.new(1, 0),
			position = UDim2.new(1, -6, 0, 4),
			textSize = Theme.sizes.textSmall,
			parent = row,
			onClick = function()
				self._callbacks.buyLure(lure.id)
			end,
		})
		self._lureRows[lure.id] = {
			frame = row,
			count = countLabel,
			equip = equip,
			buy = buy,
			details = details,
			detail = detail,
			expanded = false,
			def = lure,
		}
	end
	self:_resizePicker()
end

function HUD._resizePicker(self: any)
	local height = Theme.sizes.padding * 2 + 20
	for _, row in self._lureRows do
		local extra = if row.expanded
			then row.detail.AbsoluteSize.Y / math.max(Scale.get(), 0.01) + 8
			else 0
		row.frame.Size = UDim2.new(1, 0, 0, LURE_ROW + extra)
		height += LURE_ROW + extra + Theme.sizes.gap
	end
	self._picker.Size = UDim2.fromOffset(420, height)
end

function HUD._toggleDetail(self: any, lureId: string)
	local row = self._lureRows[lureId]
	if not row then
		return
	end
	row.expanded = not row.expanded
	row.detail.Visible = row.expanded
	row.details:setText(if row.expanded then "Hide" else "Details")
	-- AutomaticSize settles next frame; resize then
	task.defer(function()
		if row.frame.Parent then
			self:_resizePicker()
		end
	end)
end

function HUD.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	self:_buildLureRows()
end

function HUD.render(self: any, state: Types.PlayerState)
	local catalog: Types.Catalog? = self._catalog

	-- money with a little green flash when it goes up
	self._moneyText.Text = Format.money(state.money)
	if self._lastMoney and state.money > self._lastMoney then
		self._moneyText.TextColor3 = Theme.hud.income
		Tween.to(self._moneyText, Tween.RISE, { TextColor3 = Theme.hud.text })
	end
	self._lastMoney = state.money

	local catCount = 0
	local distinct = 0
	for _, owned in state.catsOwned do
		catCount += owned.count
		distinct += 1
	end
	if state.collection then
		distinct = 0
		for _ in state.collection :: { [string]: number } do
			distinct += 1
		end
	end
	self._incomeText.Text = ("%s from %d cat%s"):format(
		Format.rate(state.incomePerSecond),
		catCount,
		if catCount == 1 then "" else "s"
	)

	self._cafeTitle.Text = "Cafe " .. Format.level(state.cafeLevel)
	local parts = {}
	if state.tables then
		table.insert(
			parts,
			("%d table%s"):format(state.tables, if state.tables == 1 then "" else "s")
		)
	end
	if state.customers then
		table.insert(
			parts,
			("%d customer%s"):format(state.customers, if state.customers == 1 then "" else "s")
		)
	end
	if state.cafeProgressText then
		table.insert(parts, state.cafeProgressText)
	end
	self._cafeSub.Text = table.concat(parts, "  ·  ")
	self._cafeSub.Visible = #parts > 0
	if state.cafeProgress then
		self._cafeTrack.Visible = true
		self._cafeFill.Size = UDim2.fromScale(math.clamp(state.cafeProgress, 0, 1), 1)
	else
		self._cafeTrack.Visible = false
	end

	local total = if catalog then #catalog.cats else 0
	self._catsText.Text = ("Cats %d / %d"):format(distinct, total)

	-- lure slot and picker
	local equippedDef: Types.LureDef? = nil
	if catalog and state.equippedLure then
		for _, lure in catalog.lures do
			if lure.id == state.equippedLure then
				equippedDef = lure
			end
		end
	end
	if equippedDef then
		local count = state.lures[equippedDef.id] or 0
		self._lureName.Text = equippedDef.name
		self._lureCount.Text = if count > 0
			then ("x%d  ·  %s cats"):format(count, equippedDef.attracts)
			else "None left"
	else
		self._lureName.Text = "No lure"
		self._lureCount.Text = "Tap to choose"
	end
	for lureId, row in self._lureRows do
		local count = state.lures[lureId] or 0
		row.count.Text = if count > 0 then ("You have %d"):format(count) else "None yet"
		local isEquipped = state.equippedLure == lureId
		row.equip:setText(if isEquipped then "Using" else "Equip")
		row.equip:setEnabled(not isEquipped and count > 0)
		row.buy:setEnabled(state.money >= row.def.cost)
	end
end

function HUD.setCarrying(self: any, info: Types.CarryInfo?)
	if info then
		assert(info)
		local rarity: string = info.rarity or "Common"
		self._carry.Visible = true
		self._carryArt.BackgroundColor3 = Theme.rarityColor(rarity)
		self._carryTitle.Text = "Carrying " .. (info.catName or "a cat")
		self._carryTitle.TextColor3 = Theme.hud.text
		self._carry.UIStroke.Color = Theme.rarityColor(rarity)
		self._carry.UIStroke.Transparency = 0.1
		Tween.popIn(self._carry, 0.92)
	else
		self._carry.Visible = false
	end
	self:_layoutBottom()
end

function HUD.setTutorial(self: any, text: string?)
	if text and text ~= "" then
		self._tutorial.Text = text
		self._tutorial.Visible = true
		Tween.popIn(self._tutorial, 0.92)
	else
		self._tutorial.Visible = false
	end
	self:_layoutBottom()
end

-- Carry banner sits at the bottom; the tutorial strip stacks above it when both are visible.
function HUD._layoutBottom(self: any)
	local y = -MARGIN
	if self._carry.Visible then
		self._carry.Position = UDim2.new(0.5, 0, 1, y)
		y -= 56 + Theme.sizes.gap
	end
	self._tutorial.Position = UDim2.new(0.5, 0, 1, y)
end

function HUD.setVisible(self: any, visible: boolean)
	self.screenGui.Enabled = visible
end

function HUD.destroy(self: any)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	for _, button in self._buttons do
		button:destroy()
	end
	for _, row in self._lureRows do
		row.equip:destroy()
		row.buy:destroy()
		row.details:destroy()
	end
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return HUD
