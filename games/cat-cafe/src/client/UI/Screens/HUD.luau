--!strict
-- Always-on overlay: money and income (top left), cafe tier pill and the Cafe, Alley and Areas travel row
-- (top centre), cat count and the day and night clock chip (top right), menu tiles (left), equipped lure slot
-- with an odds picker (bottom right), carry banner and tutorial strip (bottom centre). Laid out in design
-- pixels under one UIScale from Scale.bind.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local Format = require(script.Parent.Parent.Components.Format)
local GoalCard = require(script.Parent.GoalCard)
local Notices = require(script.Parent.Parent.Notices)
local Outline = require(script.Parent.Parent.Components.Outline)
local RankUp = require(script.Parent.RankUp)
local Scale = require(script.Parent.Parent.Scale)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

export type Callbacks = {
	openScreen: (name: Types.ScreenName) -> (),
	travel: (destination: string) -> (), -- "home" or an AreaId
	buyLure: (lureId: string) -> (),
	equipLure: (lureId: string) -> (),
}

export type HUD = {
	screenGui: ScreenGui,
	setCatalog: (self: HUD, catalog: Types.Catalog) -> (),
	render: (self: HUD, state: Types.PlayerState) -> (),
	setCarrying: (self: HUD, info: Types.CarryInfo?) -> (),
	setTutorial: (self: HUD, text: string?) -> (),
	setClock: (self: HUD, clock: Types.ClockState?) -> (),
	togglePicker: (self: HUD) -> (),
	pressTravel: (self: HUD, destination: string) -> boolean,
	travelResult: (self: HUD, destination: string, ok: boolean) -> (),
	isCarrying: (self: HUD) -> boolean,
	setCatching: (self: HUD, active: boolean) -> (),
	screenOpened: (self: HUD, name: string?) -> (),
	setVisible: (self: HUD, visible: boolean) -> (),
	destroy: (self: HUD) -> (),
}

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local MARGIN = 16
local MENU_TILE = 84
local CAFE_HEIGHT = 56
local TRAVEL_W = 120
local TRAVEL_H = 46
-- F19: the server allows one trip per 3 s; the row greys for the same time so a double tap is not refused
local TRAVEL_COOLDOWN: number = (Config :: any).TravelCooldownSeconds or 3
local LURE_ROW = 70
-- right column: cats pill (52), clock chip (40), then the next goal card; the night tips chip pushes it down
local CLOCK_TOP = MARGIN + 52 + Theme.sizes.gap
local GOAL_TOP = CLOCK_TOP + 40 + Theme.sizes.gap
local NIGHT_CHIP = 24 + 4
-- data-model NightIncomeMultiplier (0.6): tips pay this share at night. The server only applies it once it
-- is in Config (F31), so the chip stays hidden until then instead of promising a cut that is not paid.
local NIGHT_TIPS: number? = (Config :: any).NightIncomeMultiplier

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
	local frame: Frame = Create("Frame", merged, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
	})
	Outline.border(frame, Theme.sizes.outline, Theme.hud.stroke)
	return frame
end

-- HUD text is the chunky display font with a dark outline, so it reads over any world colour. Wrapped
-- paragraphs (odds details) skip the outline, which muddies small multi-line text.
local function label(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.hud.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	local text: TextLabel = Create("TextLabel", merged)
	if not text.TextWrapped then
		Outline.text(text)
	end
	return text
end

local function keycap(parent: Instance, text: string, position: UDim2, anchor: Vector2?): TextLabel
	local key: TextLabel = Create("TextLabel", {
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
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 6) }) })
	Outline.border(key, 2)
	return key
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

-- "Odds: 70% Common · 26% Rare · 3.5% Epic · 0.4% Legendary · 0.1% Mythical" (the growth thread's rule:
-- labelled, never an icon)
local function oddsText(odds: Types.LureOdds?): string
	if not odds then
		return "Odds: not set"
	end
	assert(odds, "odds not set")
	local parts = {}
	for _, rarity in Theme.rarityOrder do
		local share = (odds :: any)[rarity]
		if type(share) == "number" then
			table.insert(parts, ("%s %s"):format(percent(share), rarity))
		end
	end
	return "Odds: " .. table.concat(parts, " · ")
end

-- Per-cat split, derived from the catalog. Bait picks the cat uniformly among that rarity's cats in every
-- area the player has unlocked (data-model section 8), so the pool grows with the tier.
-- "Rare 22%: Calico 11%, Siamese 11%"
local function oddsDetail(catalog: Types.Catalog, lure: Types.LureDef, tier: number): string
	local odds = lure.odds
	if not odds then
		return "Odds not set for this food yet."
	end
	assert(odds, "odds not set")
	local unlocked: { [string]: boolean } = {}
	local areaNames = {}
	local areaList: { Types.AreaDef } = catalog.areas or {}
	for _, area in areaList do
		if area.tier <= tier then
			unlocked[area.id] = true
			table.insert(areaNames, area.name)
		end
	end
	local lines = {
		if #areaNames > 0
			then "Same chance for every cat of a rarity in " .. table.concat(areaNames, ", ") .. ":"
			else "Same chance for every cat of a rarity:",
	}
	for _, rarity in Theme.rarityOrder do
		local share = (odds :: any)[rarity]
		if type(share) ~= "number" or share <= 0 then
			continue
		end
		local names = {}
		for _, def in catalog.cats do
			if def.rarity == rarity and (#areaNames == 0 or unlocked[def.area]) then
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
		table.insert(lines, ("%s %s: %s"):format(rarity, percent(share), table.concat(parts, ", ")))
	end
	return table.concat(lines, "\n")
end

function HUD.new(parent: Instance, callbacks: Callbacks): HUD
	local self = setmetatable({}, HUD) :: any
	self._callbacks = callbacks
	self._connections = {} :: { RBXScriptConnection }
	self._clockConnection = nil :: RBXScriptConnection?
	self._buttons = {} :: { any }
	self._lureRows = {} :: { [string]: any }
	self._catalog = nil :: Types.Catalog?
	self._pickerOpen = false
	self._lastMoney = nil :: number?
	self._oddsTier = 1
	-- red dots on the menu tiles: keys seen when each screen was last open (Notices)
	self._dots = {} :: { [string]: Frame }
	self._seen =
		{ Upgrades = {}, Decor = {}, Collection = {} } :: { [string]: { [string]: boolean } }
	self._candidates = nil :: Notices.Candidates?
	self._collectionPrimed = false
	self._openScreen = nil :: string?

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
	-- big gold coin with a dark outline and a shaded face, the simulator currency badge
	local coin: Frame = Create("Frame", {
		Name = "Coin",
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(48, 48),
		Parent = money,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		label({
			Size = UDim2.fromScale(1, 1),
			TextSize = 28,
			TextColor3 = Theme.colors.white,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = Theme.currencySymbol,
		}),
	})
	Outline.border(coin, Theme.sizes.outline)
	Outline.shade(coin, 0.2)
	self._moneyText = label({
		Name = "Amount",
		Position = UDim2.fromOffset(72, 8),
		Size = UDim2.new(1, -84, 0, 38),
		TextSize = 32,
		Text = Format.money(0),
		Parent = money,
	})
	self._incomeText = label({
		Name = "Income",
		Position = UDim2.fromOffset(72, 46),
		Size = UDim2.new(1, -84, 0, 22),
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.hud.income,
		Text = "",
		Parent = money,
	})

	-- Cafe pill (top centre)
	local cafe = hudPanel("Cafe", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, MARGIN),
		Size = UDim2.fromOffset(340, CAFE_HEIGHT),
		Parent = root,
	})
	self._cafeTitle = label({
		Name = "Title",
		Position = UDim2.fromOffset(16, 4),
		Size = UDim2.new(1, -32, 0, 24),
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Cafe Lv 1",
		Parent = cafe,
	})
	self._cafeSub = label({
		Name = "Sub",
		Position = UDim2.fromOffset(16, 27),
		Size = UDim2.new(1, -32, 0, 15),
		TextSize = Theme.sizes.textTiny,
		TextColor3 = Theme.hud.subtext,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
		Parent = cafe,
	})
	-- chunky XP-style bar: dark trough with an outline, shaded mint fill
	local track: Frame = Create("Frame", {
		Name = "Progress",
		BackgroundColor3 = Theme.colors.ink,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 16, 1, -12),
		Size = UDim2.new(1, -32, 0, 8),
		Visible = false,
		Parent = cafe,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(track, 1.5)
	self._cafeTrack = track
	self._cafeFill = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.colors.mint,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.shade(self._cafeFill, 0.25)
	-- v0.3: with tiers the pill opens the rank up card, and a gold tag shows when it is ready
	local cafeButton: TextButton = Create("TextButton", {
		Name = "Open",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Active = false,
		ZIndex = 3,
		Parent = cafe,
	})
	self._cafeButton = cafeButton
	table.insert(
		self._connections,
		cafeButton.Activated:Connect(function()
			if self._tiersOn then
				callbacks.openScreen("RankUp")
			end
		end)
	)
	-- a tilted red sticker on the pill's corner, the simulator "something to claim" badge; the travel row
	-- sits right under the pill, so nothing hangs below it
	self._rankBadge = Create("TextLabel", {
		Name = "RankReady",
		BackgroundColor3 = Theme.colors.red,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -10, 0, 2),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 24),
		Rotation = 8,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.colors.white,
		Text = "Rank up!",
		Visible = false,
		ZIndex = 4,
		Parent = cafe,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
	})
	Outline.text(self._rankBadge)
	self._tiersOn = false

	-- Travel row (top centre, under the tier pill): Cafe and Alley jump straight there, Areas opens the five
	-- area cards. Grow a Garden puts its teleport buttons in the same place (features.md F19). All three
	-- grey out while carrying a cat, since walking it home is the loop, and for the trip cooldown.
	local travelRow: Frame = Create("Frame", {
		Name = "Travel",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, MARGIN + CAFE_HEIGHT + 10),
		Size = UDim2.fromOffset(3 * TRAVEL_W + 2 * Theme.sizes.gap, TRAVEL_H),
		Parent = root,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._travelRow = travelRow
	self._travelButtons = {} :: { [string]: Button.Button }
	self._travelEnabled = {} :: { [string]: boolean }
	self._travelUntil = 0
	self._carryBanner = false
	self._carryState = false
	type TravelItem = { key: string, label: string, icon: string, style: Button.Style }
	local travelItems: { TravelItem } = {
		{ key = "home", label = "Cafe", icon = Theme.icons.home, style = "gold" },
		{ key = "alley", label = "Alley", icon = Theme.icons.alley, style = "secondary" },
		{ key = "areas", label = "Areas", icon = Theme.icons.travel, style = "primary" },
	}
	for index, item in travelItems do
		local button = Button.new({
			name = item.label,
			text = item.label,
			icon = item.icon,
			style = item.style,
			size = UDim2.fromOffset(TRAVEL_W, TRAVEL_H),
			textSize = Theme.sizes.textBody + 1,
			layoutOrder = index,
			parent = travelRow,
			-- Areas only opens the panel, which swishes; Cafe and Alley click
			sound = if item.key == "areas" then false else nil,
			onClick = function()
				if item.key == "areas" then
					callbacks.openScreen("Areas")
				else
					self:pressTravel(item.key)
				end
			end,
		})
		self._travelButtons[item.key] = button
		table.insert(self._buttons, button)
	end

	-- Cats pill (top right)
	local cats = hudPanel("Cats", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -MARGIN, 0, MARGIN),
		Size = UDim2.fromOffset(272, 52),
		Parent = root,
	})
	self._catsText = label({
		Name = "Count",
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -150, 1, 0),
		TextSize = 20,
		Text = "Cats 0 / 0",
		Parent = cats,
	})
	table.insert(
		self._buttons,
		Button.new({
			name = "Collection",
			text = "Collection",
			icon = Theme.icons.collection,
			style = "secondary",
			size = UDim2.fromOffset(122, 38),
			anchorPoint = Vector2.new(1, 0.5),
			position = UDim2.new(1, -8, 0.5, 0),
			textSize = Theme.sizes.textSmall,
			parent = cats,
			sound = false, -- the modal swish is the sound
			onClick = function()
				callbacks.openScreen("Collection")
			end,
		})
	)

	-- Clock chip (top right, under the cats pill): sun or moon and the time to the next phase (F20)
	local clock = hudPanel("Clock", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -MARGIN, 0, CLOCK_TOP),
		Size = UDim2.fromOffset(150, 40),
		Visible = false,
		Parent = root,
	})
	self._clock = clock
	self._sun = Create("Frame", {
		Name = "Sun",
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.fromOffset(24, 24),
		Parent = clock,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIStroke", { Color = Theme.colors.outline, Thickness = 2 }),
	})
	self._moon = Create("Frame", {
		Name = "Moon",
		BackgroundColor3 = Theme.colors.paper,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.fromOffset(24, 24),
		ClipsDescendants = true,
		Visible = false,
		Parent = clock,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		-- a second disc offset up and right turns the paper disc into a crescent
		Create("Frame", {
			Name = "Shadow",
			BackgroundColor3 = Theme.hud.panel,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(8, -5),
			Size = UDim2.fromOffset(22, 22),
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
	})
	self._clockText = label({
		Name = "Phase",
		Position = UDim2.fromOffset(42, 0),
		Size = UDim2.new(1, -50, 1, 0),
		TextSize = 18,
		Text = "",
		Parent = clock,
	})
	-- v0.3 (F31): tips pay less at night, so the chip says by how much
	self._nightTips = hudPanel("NightTips", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -MARGIN, 0, CLOCK_TOP + 40 + 4),
		Size = UDim2.fromOffset(150, 24),
		Visible = false,
		Parent = root,
	})
	label({
		Name = "Text",
		Size = UDim2.fromScale(1, 1),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.colors.sky,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = if NIGHT_TIPS then "Tips " .. Format.percent(NIGHT_TIPS) else "",
		Parent = self._nightTips,
	})

	-- Next goal card (right, under the clock): the next tier's requirements as bars; a tap opens rank up
	self._goal = GoalCard.new(root, UDim2.new(1, -MARGIN, 0, GOAL_TOP), function()
		callbacks.openScreen("RankUp")
	end)

	-- Menu stack (left, vertically centred)
	local menu: Frame = Create("Frame", {
		Name = "Menu",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, MARGIN, 0.5, 0),
		Size = UDim2.fromOffset(MENU_TILE, 3 * MENU_TILE + 2 * Theme.sizes.gap),
		Parent = root,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local showKeys = UserInputService.KeyboardEnabled
	type MenuItem = {
		label: string,
		icon: string,
		screen: Types.ScreenName,
		key: string,
		style: Button.Style,
	}
	-- square icon tiles down the left edge, the simulator convention for shop and inventory buttons
	local menuItems: { MenuItem } = {
		{
			label = "Upgrades",
			icon = Theme.icons.upgrades,
			screen = "Upgrades",
			key = "U",
			style = "primary",
		},
		{ label = "Decor", icon = Theme.icons.decor, screen = "Decor", key = "B", style = "gold" },
		{
			label = "Cats",
			icon = Theme.icons.cats,
			screen = "Collection",
			key = "C",
			style = "secondary",
		},
	}
	for index, item in menuItems do
		local button = Button.new({
			name = item.label,
			text = item.label,
			icon = item.icon,
			layout = "tile",
			style = item.style,
			size = UDim2.fromOffset(MENU_TILE, MENU_TILE),
			textSize = Theme.sizes.textBody,
			layoutOrder = index,
			parent = menu,
			sound = false, -- the modal swish is the sound
			onClick = function()
				callbacks.openScreen(item.screen)
			end,
		})
		if showKeys then
			keycap(button.face, item.key, UDim2.new(1, -4, 0, 4), Vector2.new(1, 0))
		end
		-- red "!" dot on the tile's top left corner when the screen has something new
		local dot: Frame = Create("Frame", {
			Name = "Dot",
			BackgroundColor3 = Theme.colors.red,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.fromOffset(24, 24),
			Visible = false,
			ZIndex = 6,
			Parent = button.instance,
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		Outline.border(dot, 2)
		label({
			Name = "Mark",
			Size = UDim2.fromScale(1, 1),
			TextSize = Theme.sizes.textBody,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = "!",
			ZIndex = 7,
			Parent = dot,
		})
		self._dots[item.screen] = dot
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
	})
	Outline.border(lureSlot, Theme.sizes.outline, Theme.hud.stroke)
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
			Sound.play("uiClick")
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
		TextSize = Theme.sizes.textBody + 1,
		TextColor3 = Theme.colors.white,
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

-- Fires the travel callback unless the row is greyed (carrying, or inside the trip cooldown). True when it fired.
function HUD.pressTravel(self: any, destination: string): boolean
	if self:isCarrying() or os.clock() < self._travelUntil then
		return false
	end
	self._callbacks.travel(destination)
	self._travelUntil = os.clock() + TRAVEL_COOLDOWN
	self:_renderTravel()
	task.delay(TRAVEL_COOLDOWN, function()
		if os.clock() >= self._travelUntil then
			self:_renderTravel()
		end
	end)
	return true
end

-- The server's answer (TravelResult). A refusal lifts the cooldown at once and wobbles the button that
-- asked; area trips from the Areas panel wobble the Areas button. The server's toast says why.
function HUD.travelResult(self: any, destination: string, ok: boolean)
	local button: Button.Button? = self._travelButtons[destination] or self._travelButtons.areas
	if not button then
		return
	end
	assert(button, "travel button missing")
	if ok then
		Tween.popIn(button.instance, 0.85)
		return
	end
	self._travelUntil = 0
	self:_renderTravel()
	button.instance.Rotation = -8
	Tween.to(
		button.instance,
		TweenInfo.new(0.45, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
		{ Rotation = 0 }
	)
end

-- Carrying comes from two places: the carry banner (UI.setCarrying) and state.carrying.
function HUD.isCarrying(self: any): boolean
	return self._carryBanner or self._carryState
end

-- The catch circles' header takes the top centre during a catch, and the server refuses a trip mid catch
-- anyway (N47), so the travel row steps aside until the catch ends.
function HUD.setCatching(self: any, active: boolean)
	self._travelRow.Visible = not active
end

function HUD._renderTravel(self: any)
	local carrying = self:isCarrying()
	local cooling = os.clock() < self._travelUntil
	for key, button in self._travelButtons do
		-- render runs on every state push, so only touch buttons whose state changed (keeps hover colour)
		local enabled = not carrying and (key == "areas" or not cooling)
		if self._travelEnabled[key] ~= enabled then
			self._travelEnabled[key] = enabled
			button:setEnabled(enabled)
		end
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
	assert(catalog, "catalog not set; call UI.init first")
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
			Text = oddsDetail(catalog, lure, self._oddsTier),
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
	self._carryState = state.carrying ~= nil
	self:_renderTravel()

	-- income comes only from cats in a role slot, so with instances the count skips resting cats
	local catCount = 0
	local distinct = 0
	for _, owned in state.catsOwned do
		catCount += owned.count
		distinct += 1
	end
	if state.cats then
		catCount = 0
		for _, instance in state.cats :: { [string]: Types.CatInstance } do
			if instance.spotId then
				catCount += 1
			end
		end
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

	-- the bait pool grows as tiers open areas, so the per-cat split is rebuilt on a tier change
	if catalog and state.tier ~= self._oddsTier then
		self._oddsTier = state.tier
		for _, lureRow in self._lureRows do
			lureRow.detail.Text = oddsDetail(catalog, lureRow.def, state.tier)
		end
	end
	local tierProgress: RankUp.Progress? = nil
	if catalog and catalog.tiers and state.tier then
		tierProgress = RankUp.progress(catalog, state)
	end
	self._tiersOn = tierProgress ~= nil
	self._cafeButton.Active = tierProgress ~= nil
	self._goal:render(tierProgress)
	self:_layoutRight()
	if catalog then
		self:_renderDots(catalog, state)
	end
	if tierProgress then
		self:_renderTier(tierProgress)
		self:_renderLures(state)
		local total = if catalog then #catalog.cats else 0
		self._catsText.Text = ("Cats %d / %d"):format(distinct, total)
		return
	end
	self._rankBadge.Visible = false

	self._cafeTitle.Text = Format.tier(state.tier, if catalog then catalog.tiers else nil)
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
	self:_renderLures(state)
end

-- v0.3 top pill: "Tier 2 · Cozy Cafe", what the next tier still needs, and a gold tag when ready.
function HUD._renderTier(self: any, progress: RankUp.Progress)
	local current = progress.current
	self._cafeTitle.Text = ("Tier %d%s"):format(
		progress.tier,
		if current then "  ·  " .. current.name else ""
	)
	local nextTier = progress.nextTier
	-- the next goal card lists the requirements, so the pill only names the next tier
	local sub = "Top tier"
	if nextTier then
		sub = "Next: " .. nextTier.name
	end
	self._cafeSub.Text = sub
	self._cafeSub.Visible = true
	self._cafeTrack.Visible = nextTier ~= nil
	self._cafeFill.Size = UDim2.fromScale(math.clamp(progress.fraction, 0, 1), 1)
	self._cafeFill.BackgroundColor3 = if progress.ready
		then Theme.colors.gold
		else Theme.colors.mint
	if progress.ready then
		self._cafeSub.Text = "Rank up ready! Tap to see "
			.. (if nextTier then nextTier.name else "")
	end
	local wasVisible = self._rankBadge.Visible
	self._rankBadge.Visible = progress.ready
	if progress.ready and not wasVisible then
		Tween.popIn(self._rankBadge, 0.7)
	end
	-- uiRankReady chimes once per tier, the first time that tier's requirements are all met
	if progress.ready and self._chimedTier ~= progress.tier then
		self._chimedTier = progress.tier
		Sound.play("uiRankReady")
	end
end

function HUD._renderLures(self: any, state: Types.PlayerState)
	local catalog: Types.Catalog? = self._catalog
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
	self._carryBanner = info ~= nil
	self:_renderTravel()
	if info then
		assert(info, "carry info missing")
		local rarity: string = info.rarity or "Common"
		self._carry.Visible = true
		self._carryArt.BackgroundColor3 = Theme.rarityColor(rarity)
		self._carryTitle.Text = "Carrying " .. (info.catName or "a cat")
		self._carryTitle.TextColor3 = Theme.hud.text
		-- hudPanel's outline is the "Border" stroke from Components/Outline
		local border = self._carry:FindFirstChild("Border") :: UIStroke
		border.Color = Theme.rarityColor(rarity)
		Tween.popIn(self._carry, 0.92)
	else
		self._carry.Visible = false
	end
	self:_layoutBottom()
end

function HUD.setTutorial(self: any, text: string?)
	if text and text ~= "" then
		if not self._tutorial.Visible or self._tutorial.Text ~= text then
			Sound.play("uiHint")
		end
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

local function clockText(phase: Types.ClockPhase, remaining: number): string
	local seconds = math.max(0, math.floor(remaining + 0.5))
	return ("%s  %d:%02d"):format(
		if phase == "night" then "Night" else "Day",
		seconds // 60,
		seconds % 60
	)
end

-- Day and night chip. nil hides it. The countdown runs on Workspace:GetServerTimeNow(), the server's
-- synchronised epoch clock, so it compares with the server's os.time() in PhaseEndsAt and never trusts
-- the device clock (data-model section 1, reviewer S16).
function HUD.setClock(self: any, clock: Types.ClockState?)
	self:_stopClock()
	if not clock then
		self._clock.Visible = false
		self._nightTips.Visible = false
		self:_layoutRight()
		return
	end
	local current: Types.ClockState = clock
	local isNight = current.phase == "night"
	self._sun.Visible = not isNight
	self._moon.Visible = isNight
	self._clockText.TextColor3 = if isNight then Theme.colors.sky else Theme.hud.text
	self._clock.Visible = true
	self._nightTips.Visible = isNight and NIGHT_TIPS ~= nil
	self:_layoutRight()
	local function tick()
		self._clockText.Text =
			clockText(current.phase, current.phaseEndsAt - Workspace:GetServerTimeNow())
	end
	tick()
	local accumulated = 0
	self._clockConnection = RunService.Heartbeat:Connect(function(dt: number)
		accumulated += dt
		if accumulated >= 0.25 then
			accumulated = 0
			tick()
		end
	end)
end

-- The goal card sits under the clock, and under the night tips chip when it shows.
function HUD._layoutRight(self: any)
	local top = if self._clock.Visible then GOAL_TOP else CLOCK_TOP
	if self._nightTips.Visible then
		top += NIGHT_CHIP
	end
	self._goal.frame.Position = UDim2.new(1, -MARGIN, 0, top)
end

-- Red dots: a screen's dot shows while it has a key the player has not seen on that screen. Keys seen while
-- the screen is open count as seen, so buying the next level in the shop does not light the dot again.
function HUD._renderDots(self: any, catalog: Types.Catalog, state: Types.PlayerState)
	local candidates = Notices.candidates(catalog, state)
	self._candidates = candidates
	-- cats caught before this session are not news: the first collection we see is all seen
	if state.collection and not self._collectionPrimed then
		self._collectionPrimed = true
		Notices.markSeen(candidates.Collection, self._seen.Collection)
	end
	local open: string? = self._openScreen
	if open and (candidates :: any)[open] then
		Notices.markSeen((candidates :: any)[open], self._seen[open])
	end
	for screen, dot in self._dots do
		local keys: { string } = (candidates :: any)[screen] or {}
		local show = Notices.hasNew(keys, self._seen[screen])
		if show and not dot.Visible then
			Tween.popIn(dot, 0.5)
		end
		dot.Visible = show
	end
end

-- From the modal's changed signal: opening a screen marks what it shows as seen and clears its dot.
function HUD.screenOpened(self: any, name: string?)
	self._openScreen = name
	local candidates: Notices.Candidates? = self._candidates
	if name and candidates and (candidates :: any)[name] then
		Notices.markSeen((candidates :: any)[name], self._seen[name])
		local dot: Frame? = self._dots[name]
		if dot then
			dot.Visible = false
		end
	end
end

function HUD._stopClock(self: any)
	local connection: RBXScriptConnection? = self._clockConnection
	if connection then
		connection:Disconnect()
		self._clockConnection = nil
	end
end

function HUD.setVisible(self: any, visible: boolean)
	self.screenGui.Enabled = visible
end

function HUD.destroy(self: any)
	self:_stopClock()
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
	self._goal:destroy()
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return HUD
