--!strict
-- The potion bag (F64, data-model section 12b; the quest potions of F73 join it, quests.md section 4). Opened from
-- the Potions tile (key P) or a tap on a HUD potion timer. One row per potion the player has or is drinking (Derek
-- 2026-11-03: "it only shows use on potions you have and disappear when used"), kept brief (Derek 2026-10-28: "keep
-- the info brief and simple"): a round tile in the potion's colour with how many are in the bag,
-- the name, one short line on what it does and for how long, the time left while it runs ("8:12 left"), and a Use
-- button. A running potion with none left in the bag has no Use. Use reads "Full" when another would take the timer
-- past PotionMaxMinutes (60). A pressed Use reads "..." for a moment; the server's answer is the next ProfileSync, and
-- a refusal is the server's toast. The drink sound plays when the bag's count drops, which is the server accepting.
-- Timers pause while the player is away, so a rejoin shows what was left. Rows and sums: Components/PotionLogic.
--
-- The Bag (corner-shop-v2.md section 3, #1181): this window is the Bag, with two tabs. Potions is the potion bag
-- above; Cat Food lists each food the player has (picture, name, "+2,000 XP", "x3" and a green Feed). Feed shows the
-- player's cats as a grid of picture tiles (#1404), highest level first: the cat in a tile of its rarity colour, its
-- name and "Lv 23" ("Max" at the cap, greyed); a tap feeds that cat one (FeedCat) and the server's FeedResult toasts
-- the XP. Nothing opens on buy any more. Words and lists: Components/BagLogic.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BagLogic = require(script.Parent.Parent.Components.BagLogic)
local Button = require(script.Parent.Parent.Components.Button)
local CatPortrait = require(script.Parent.Parent.Components.CatPortrait)
local CornerShopLogic = require(script.Parent.Parent.Components.CornerShopLogic)
local Create = require(script.Parent.Parent.Components.Create)
local IconArt = require(script.Parent.Parent.Components.IconArt)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local PotionLogic = require(script.Parent.Parent.Components.PotionLogic)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

-- the dark window palette (#1028), in place of Theme.modal
local PAL = Theme.dark

export type Callbacks = {
	use: (potionId: string) -> (),
	feed: ((foodId: string, catUid: string) -> ())?, -- #1181: one food to one cat (FeedCat)
	close: () -> (),
}

export type Tab = "Potions" | "Food"

export type Potions = {
	frame: Frame,
	setCatalog: (self: Potions, catalog: Types.Catalog) -> (),
	render: (self: Potions, state: Types.PlayerState) -> (),
	showTab: (self: Potions, tab: Tab) -> (),
	destroy: (self: Potions) -> (),
}

local ROW_H = 76
local TILE = 56
local USE_W = 104
local TAB_H = 40
local FOOD_W = 104 -- the Feed button
local PENDING_SECONDS = 1 -- a pressed Use waits this long for the server before it can be pressed again

-- One cat in the feed grid (#1404).
type CatTile = {
	frame: TextButton,
	portrait: CatPortrait.CatPortrait,
	connection: RBXScriptConnection,
}

local CAT_TILE = Vector2.new(112, 136)
local CAT_PICTURE = 76

type Row = {
	frame: Frame,
	tile: Frame,
	count: TextLabel,
	name: TextLabel,
	effect: TextLabel,
	left: TextLabel,
	use: Button.Button,
}

local Potions = {}
Potions.__index = Potions

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

function Potions.new(callbacks: Callbacks): Potions
	local self = setmetatable({}, Potions) :: any
	self._callbacks = callbacks
	self._catalog = nil :: Types.Catalog?
	self._state = nil :: Types.PlayerState?
	self._rows = {} :: { [string]: Row }
	self._counts = nil :: { [string]: number }? -- the bag at the last render, to hear a drink land
	self._pending = {} :: { [string]: number } -- potion id -> os.clock() of the press

	local panel = Panel.new({
		dark = true, -- #1028
		name = "Potions",
		title = "Bag",
		subtitle = "Potions for a boost, cat food for XP",
		color = Theme.colors.berry,
		icon = Theme.icons.potion,
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = Vector2.new(600, 520), Parent = panel.frame })
	self._panel = panel
	self.frame = panel.frame

	self._tab = "Potions" :: Tab
	self._foodRows = {} :: { [string]: { frame: Frame, count: TextLabel, feed: Button.Button } }
	self._catRows = {} :: { CatTile }
	self._feeding = nil :: string? -- the food whose cat list shows
	local tabs: Frame = Create("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, TAB_H),
		Parent = panel.content,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._tabButtons = {
		Potions = Button.new({
			name = "PotionsTab",
			text = "Potions",
			icon = Theme.icons.potion,
			style = "berry",
			size = UDim2.fromOffset(150, TAB_H - 4),
			textSize = Theme.sizes.textBody,
			layoutOrder = 1,
			parent = tabs,
			sound = "uiTab",
			onClick = function()
				self:showTab("Potions")
			end,
		}),
		Food = Button.new({
			name = "FoodTab",
			text = "Cat Food",
			icon = "🍪",
			style = "ghost",
			size = UDim2.fromOffset(150, TAB_H - 4),
			textSize = Theme.sizes.textBody,
			layoutOrder = 2,
			parent = tabs,
			sound = "uiTab",
			onClick = function()
				self:showTab("Food")
			end,
		}),
	}

	self._list = Create("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, TAB_H + 6),
		Size = UDim2.new(1, 0, 1, -(TAB_H + 6)),
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
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
	})
	-- with an empty bag, one line on where potions come from, under the rows
	self._hint = text({
		Name = "Hint",
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		Text = "No potions yet. Mystery visitors, gifts and codes give them.",
		LayoutOrder = 1000,
		Visible = false,
		Parent = self._list,
	})

	self._foodList = (self._list :: ScrollingFrame):Clone()
	self._foodList.Name = "FoodList"
	for _, child in self._foodList:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	self._foodList.Visible = false
	self._foodList.Parent = panel.content
	self._foodHint = text({
		Name = "Hint",
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		Text = "Cat food comes from the Daily Treat, rescues, catches and the Corner Shop.",
		LayoutOrder = 1000,
		Visible = false,
		Parent = self._foodList,
	})
	-- Feed's cat list: a heading with Back, then a row per cat
	self._catList = (self._list :: ScrollingFrame):Clone()
	self._catList.Name = "CatList"
	for _, child in self._catList:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	self._catList.Visible = false
	self._catList.Parent = panel.content
	self._catTitle = text({
		Name = "Title",
		Size = UDim2.new(1, -110, 0, 36),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		LayoutOrder = 0,
		Parent = self._catList,
	})
	self._back = Button.new({
		name = "Back",
		text = "Back",
		style = "ghost",
		size = UDim2.fromOffset(100, 34),
		textSize = Theme.sizes.textBody,
		layoutOrder = 0,
		parent = self._catList,
		onClick = function()
			self:_pickFood(nil)
		end,
	})
	self._catGrid = Create("Frame", {
		Name = "Cats",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 1,
		Parent = self._catList,
	}, {
		Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(CAT_TILE.X, CAT_TILE.Y),
			CellPadding = UDim2.fromOffset(Theme.sizes.gap, Theme.sizes.gap),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- once a second while open, so the times left count down
	local clock = 0
	self._tick = RunService.Heartbeat:Connect(function(dt: number)
		clock += dt
		if clock < 1 then
			return
		end
		clock = 0
		if self.frame.Visible then
			self:_refresh()
		end
	end)
	return self :: Potions
end

function Potions.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	self:_refresh()
end

function Potions.render(self: any, state: Types.PlayerState)
	-- a count that dropped is the server taking a UsePotion: the drink sound (sound list 5.11)
	local counts: { [string]: number } = state.potions or {}
	local before: { [string]: number }? = self._counts
	if before then
		for id, count in before do
			if (counts[id] or 0) < count then
				Sound.play("potionDrink")
				self._pending[id] = nil
				break
			end
		end
	end
	self._counts = table.clone(counts)
	self._state = state
	self:_refresh()
end

function Potions.showTab(self: any, tab: Tab)
	self._tab = tab
	self._feeding = nil
	for name, button in self._tabButtons do
		button:setStyle(
			if name == tab then (if tab == "Food" then "primary" else "berry") else "ghost"
		)
	end
	self:_refreshFood()
end

-- Feed on a food row: the cat list for that food; nil goes back to the foods.
function Potions._pickFood(self: any, foodId: string?)
	self._feeding = foodId
	self:_refreshFood()
end

function Potions._refreshFood(self: any)
	local food = self._tab == "Food"
	self._list.Visible = not food
	self._foodList.Visible = food and self._feeding == nil
	self._catList.Visible = food and self._feeding ~= nil
	local state: Types.PlayerState? = self._state
	if state == nil or not food then
		return
	end
	local catalog: any = self._catalog
	local foods = BagLogic.foods(if catalog then catalog.catFood else nil, (state :: any).catFood)
	local shown: { [string]: boolean } = {}
	local feeding: BagLogic.Food? = nil
	for order, entry in foods do
		shown[entry.id] = true
		if entry.id == self._feeding then
			feeding = entry
		end
		local row = self._foodRows[entry.id] or self:_foodRow(entry)
		self._foodRows[entry.id] = row
		row.frame.LayoutOrder = order
		row.count.Text = "x" .. entry.count
	end
	for id, row in self._foodRows do
		if not shown[id] then
			row.feed:destroy()
			row.frame:Destroy()
			self._foodRows[id] = nil
		end
	end
	self._foodHint.Visible = #foods == 0
	if self._feeding ~= nil and feeding == nil then
		-- the last of that food went: back to the foods
		self._feeding = nil
		self._foodList.Visible = true
		self._catList.Visible = false
		return
	end
	if feeding then
		self:_renderCats(feeding)
	end
end

function Potions._foodRow(self: any, entry: BagLogic.Food)
	local frame: Frame = Create("Frame", {
		Name = entry.id,
		BackgroundColor3 = PAL.card,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, ROW_H),
		Parent = self._foodList,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = PAL.cardStroke, Thickness = Theme.sizes.stroke }),
	})
	local tile: Frame = Create("Frame", {
		Name = "Tile",
		BackgroundColor3 = Theme.colors.cream,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(TILE, TILE),
		Parent = frame,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(tile, 2)
	local glyph = text({
		Name = "Glyph",
		Size = UDim2.fromScale(1, 1),
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "🍪",
		Parent = tile,
	})
	local picture = ShopIcons.catFood(entry.id)
	if picture then
		IconArt.setImage(glyph, picture, 0.92)
	end
	local count = text({
		Name = "Count",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 6, 1, 4),
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.colors.ink,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.colors.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		ZIndex = 2,
		Parent = tile,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = count })
	Create(
		"UIPadding",
		{ PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = count }
	)
	local textLeft = TILE + 24
	local textRight = FOOD_W + 20
	text({
		Name = "FoodName",
		Position = UDim2.fromOffset(textLeft, 12),
		Size = UDim2.new(1, -(textLeft + textRight), 0, 26),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 3,
		Text = entry.name,
		Parent = frame,
	})
	text({
		Name = "Xp",
		Position = UDim2.fromOffset(textLeft, 40),
		Size = UDim2.new(1, -(textLeft + textRight), 0, 22),
		TextSize = Theme.sizes.textSmall + 1,
		TextColor3 = PAL.good,
		Text = BagLogic.xpLine(entry.xp) .. " for one cat",
		Parent = frame,
	})
	local feed = Button.new({
		name = "Feed",
		text = "Feed",
		style = "primary",
		size = UDim2.fromOffset(FOOD_W, 38),
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, -10, 0.5, 0),
		textSize = Theme.sizes.textBody + 1,
		parent = frame,
		onClick = function()
			self:_pickFood(entry.id)
		end,
	})
	return { frame = frame, count = count, feed = feed }
end

-- The cats to feed `food` to, highest level first; a tap feeds that cat one.
function Potions._renderCats(self: any, food: BagLogic.Food)
	for _, tile in self._catRows do
		tile.connection:Disconnect()
		tile.portrait:destroy()
		tile.frame:Destroy()
	end
	table.clear(self._catRows)
	local state: any = self._state
	self._catTitle.Text = ("Feed a %s (x%d) · %s"):format(
		food.name,
		food.count,
		BagLogic.xpLine(food.xp)
	)
	local catalog: any = self._catalog
	local names: { [string]: string } = {}
	local defs: { any } = (if catalog then catalog.cats else nil) or {}
	for _, def in defs do
		if type(def) == "table" and def.id and def.name then
			names[def.id] = def.name
		end
	end
	local cats = CornerShopLogic.catsByLevel(state.cats, names)
	for order, cat in cats do
		local tile: CatTile = self:_catTile(food, cat, order)
		table.insert(self._catRows, tile)
	end
end

-- A cat's tile in the feed grid: its picture on its rarity colour, its name and "Lv 20"; greyed at the top level.
function Potions._catTile(
	self: any,
	food: BagLogic.Food,
	cat: CornerShopLogic.CatEntry,
	order: number
): CatTile
	local state: any = self._state
	local catalog: any = self._catalog
	local def: any = nil
	for _, each in (if catalog then catalog.cats else nil) or {} do
		if type(each) == "table" and each.id == cat.catId then
			def = each
		end
	end
	local instance = (state.cats or {})[cat.uid]
	local gold = type(instance) == "table" and instance.variant == "gold"
	local open = BagLogic.canFeed(cat.level)
	local rarity = if def then def.rarity else nil
	local tile: TextButton = Create("TextButton", {
		Name = cat.uid,
		Text = "",
		AutoButtonColor = open,
		BackgroundColor3 = if open then Theme.rarityColor(rarity) else Theme.colors.disabled,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = self._catGrid,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	Outline.border(tile, Theme.sizes.outline)
	Outline.shade(tile, 0.3)
	local portrait = CatPortrait.new({
		parent = tile,
		size = UDim2.fromOffset(CAT_PICTURE, CAT_PICTURE),
		anchorPoint = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, 4),
		still = true, -- a grid of cats costs no frames
		zIndex = 2,
	})
	portrait:set(def, gold)
	local name = text({
		Name = "Name",
		Position = UDim2.fromOffset(4, CAT_PICTURE + 8),
		Size = UDim2.new(1, -8, 0, 22),
		FontFace = Theme.fonts.display,
		TextScaled = true,
		TextColor3 = Theme.colors.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = cat.name or cat.catId,
		ZIndex = 3,
		Parent = tile,
	})
	Create("UITextSizeConstraint", {
		MaxTextSize = Theme.sizes.textBody,
		MinTextSize = 9,
		Parent = name,
	})
	Outline.text(name, 2)
	local level = text({
		Name = "Level",
		Position = UDim2.fromOffset(4, CAT_PICTURE + 30),
		Size = UDim2.new(1, -8, 0, 20),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall + 1,
		TextColor3 = Theme.colors.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = BagLogic.levelChip(cat.level),
		ZIndex = 3,
		Parent = tile,
	})
	Outline.text(level, 2)
	local connection = tile.Activated:Connect(function()
		local feed: ((string, string) -> ())? = self._callbacks.feed
		if open and feed then
			Sound.play("uiTab")
			feed(food.id, cat.uid)
		end
	end)
	return { frame = tile, portrait = portrait, connection = connection }
end

function Potions._row(self: any, potionId: string): Row
	local frame: Frame = Create("Frame", {
		Name = potionId,
		BackgroundColor3 = PAL.card,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, ROW_H),
		Parent = self._list,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = PAL.cardStroke, Thickness = Theme.sizes.stroke }),
	})
	local tile: Frame = Create("Frame", {
		Name = "Tile",
		BackgroundColor3 = Theme.potionColor(potionId),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(TILE, TILE),
		Parent = frame,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(tile, 2)
	local glyph = text({
		Name = "Glyph",
		Size = UDim2.fromScale(1, 1),
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = Theme.icons.potion,
		Parent = tile,
	})
	-- the potion's own bottle (Model-Agent's icons), else the drawn potion glyph
	local bottles = ShopIcons.potionAll(potionId)
	if #bottles > 0 then
		IconArt.setImages(glyph, bottles, 0.92)
	else
		IconArt.set(glyph, Theme.icons.potion, 0.8)
	end
	-- how many are in the bag, a small dark pill on the tile's corner
	local count = text({
		Name = "Count",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 6, 1, 4),
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.colors.ink,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.colors.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		ZIndex = 2,
		Parent = tile,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = count })
	Create("UIPadding", {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		Parent = count,
	})
	local textLeft = TILE + 24
	local textRight = USE_W + 20
	local name = text({
		Name = "PotionName",
		Position = UDim2.fromOffset(textLeft, 12),
		Size = UDim2.new(1, -(textLeft + textRight), 0, 26),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 3,
		Parent = frame,
	})
	local effect = text({
		Name = "Effect",
		Position = UDim2.fromOffset(textLeft, 40),
		Size = UDim2.new(1, -(textLeft + textRight), 0, 22),
		TextSize = Theme.sizes.textSmall + 1,
		TextColor3 = PAL.subtext,
		Parent = frame,
	})
	-- "8:12 left" over the Use button while it runs
	local left = text({
		Name = "Left",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 4),
		Size = UDim2.fromOffset(USE_W, 18),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.good,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		Parent = frame,
	})
	local use = Button.new({
		name = "Use",
		text = "Use",
		style = "primary",
		size = UDim2.fromOffset(USE_W, 38),
		anchorPoint = Vector2.new(1, 1),
		position = UDim2.new(1, -10, 1, -10),
		textSize = Theme.sizes.textBody + 1,
		parent = frame,
		onClick = function()
			local pressedAt = self._pending[potionId]
			if pressedAt and os.clock() - pressedAt < PENDING_SECONDS then
				return
			end
			self._pending[potionId] = os.clock()
			self._callbacks.use(potionId)
			self:_refresh()
			task.delay(PENDING_SECONDS, function()
				if self._rows[potionId] then
					self:_refresh()
				end
			end)
		end,
	})
	return {
		frame = frame,
		tile = tile,
		count = count,
		name = name,
		effect = effect,
		left = left,
		use = use,
	}
end

function Potions._refresh(self: any)
	local state: Types.PlayerState? = self._state
	if state == nil then
		return
	end
	-- only what the player has or is drinking (Derek 2026-11-03); a row goes when its last one is used and runs out
	local rows = PotionLogic.owned(self._catalog, state, Workspace:GetServerTimeNow())
	local shown: { [string]: boolean } = {}
	local any = false
	for order, view in rows do
		local potion = view.potion
		shown[potion.id] = true
		local row: Row = self._rows[potion.id] or self:_row(potion.id)
		self._rows[potion.id] = row
		row.frame.LayoutOrder = order
		row.name.Text = potion.name
		local line: { string } = {}
		if potion.effect ~= "" then
			table.insert(line, potion.effect)
		end
		if potion.minutes > 0 then
			table.insert(line, ("%d min"):format(potion.minutes))
		end
		row.effect.Text = table.concat(line, "  ·  ")
		row.count.Text = "x" .. view.count
		row.count.Visible = view.count > 0
		local running = view.secondsLeft > 0
		row.left.Visible = running
		row.left.Text = PotionLogic.clock(view.secondsLeft) .. " left"
		local pressedAt: number? = self._pending[potion.id]
		local pending = pressedAt ~= nil and os.clock() - pressedAt < PENDING_SECONDS
		local full = view.count > 0 and not view.canUse
		row.use:setText(if pending then "..." elseif full then "Full" else "Use")
		row.use:setEnabled(view.canUse and not pending)
		-- a running potion with none left in the bag: no Use, just its time left
		row.use.instance.Visible = view.count > 0
		any = true
	end
	for id, row in self._rows do
		if not shown[id] then
			row.use:destroy()
			row.frame:Destroy()
			self._rows[id] = nil
		end
	end
	self._hint.Visible = not any
	self:_refreshFood()
end

function Potions.destroy(self: any)
	self._tick:Disconnect()
	for _, row in self._foodRows do
		row.feed:destroy()
	end
	for _, tile in self._catRows do
		tile.connection:Disconnect()
		tile.portrait:destroy()
	end
	for _, button in self._tabButtons do
		button:destroy()
	end
	self._back:destroy()
	for _, row in self._rows do
		row.use:destroy()
	end
	table.clear(self._rows)
	self._panel:destroy()
end

return Potions
