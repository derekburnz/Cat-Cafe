--!strict
-- The potion bag (F64, data-model section 12b; the quest potions of F73 join it, quests.md section 4). Opened from
-- the Potions tile (key P) or a tap on a HUD potion timer. One row per potion the player has or is drinking (Derek
-- 2026-11-03: "it only shows use on potions you have and disappear when used"), kept brief (Derek 2026-10-28: "keep
-- the info brief and simple"): a round tile in the potion's colour with how many are in the bag,
-- the name, one short line on what it does and for how long, the time left while it runs ("8:12 left"), and a Use
-- button. A running potion with none left in the bag has no Use. Use reads "Full" when another would take the timer
-- past PotionMaxMinutes (60). A pressed Use reads "..." for a moment; the server's answer is the next ProfileSync, and
-- a refusal is the server's toast. The drink sound plays when the bag's count drops, which is the server accepting.
-- #1600: beside Use, "Use x4" drinks as many as fit under PotionMaxMinutes in one press (UsePotion with a count);
-- it shows only while two or more would fit.
-- Timers pause while the player is away, so a rejoin shows what was left. Rows and sums: Components/PotionLogic.
--
-- The Bag (corner-shop-v2.md section 3, #1181): this window is the Bag, with two tabs. Potions is the potion bag
-- above; Cat Food lists each food the player has (picture, name, "+2,000 XP", "x3" and a green Feed). Feed shows the
-- player's cats, highest level first ("Level 23 · 1,400 XP to 24"); a tap feeds that cat one (FeedCat) and the
-- server's FeedResult toasts the XP. Nothing opens on buy any more. Words and lists: Components/BagLogic.
-- #1281 (corner-shop-v2.md section 1b) adds a third tab, Bait: each bowl food the player has (its picture with the
-- grade badge, name and count). It has no Use, since bait goes in at the bowl.
-- #1771 (Derek2: "bag has a lot of the old ui images/buttons"): the tabs draw the HUD's own Potions and Bait pictures
-- and the Market's treat, and the chosen tab is gold, as in the Store and the Fish Market. #1773 (Derek2: the blue
-- feeding list should "show what cat is being fed much easier"): Feed's cat list is a card per cat with its head in
-- its rarity's colour, its gold or rainbow coat on the edge and name, "Epic · Level 24" and a bar toward the next
-- level, and a green Feed.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BagLogic = require(script.Parent.Parent.Components.BagLogic)
local Button = require(script.Parent.Parent.Components.Button)
local CatPortrait = require(script.Parent.Parent.Components.CatPortrait)
local CatVariant = require(script.Parent.Parent.Components.CatVariant)
local CornerShopLogic = require(script.Parent.Parent.Components.CornerShopLogic)
local Create = require(script.Parent.Parent.Components.Create)
local IconArt = require(script.Parent.Parent.Components.IconArt)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local PotionLogic = require(script.Parent.Parent.Components.PotionLogic)
local Rainbow = require(script.Parent.Parent.Components.Rainbow)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

-- the dark window palette (#1028), in place of Theme.modal
local PAL = Theme.dark

export type Callbacks = {
	use: (potionId: string, count: number?) -> (), -- count: #1600's Use all, nil for one
	feed: ((foodId: string, catUid: string) -> ())?, -- #1181: one food to one cat (FeedCat)
	close: () -> (),
}

export type Tab = "Potions" | "Food" | "Bait"

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
local TAB_W = 136 -- three tabs fit the small phone's window
local FOOD_W = 104 -- the Feed button
local PENDING_SECONDS = 1 -- a pressed Use waits this long for the server before it can be pressed again
local CAT_CARD_H = 68 -- #1773: a cat card in Feed's list
local CAT_HEAD = 56 -- its head picture on the rarity's colour
local CAT_FEED_W = 92
local CAT_TITLE_H = 36 -- the cat list's heading; its drawn height over this is the window's UI scale
local CAT_BUFFER = 4 -- #2196: cards made past each edge of the list, so a flick finds them ready
local CAT_VIEW = 520 -- the list's height while it has none yet (the window's MaxSize)

-- #2196: one card of Feed's cat list. Only the cards in view are made (Derek2 11-07: "it should only render as you
-- scroll"), and a card scrolled out is kept to show the next cat scrolled in: `key` is what it shows now (food, cat,
-- variant, level, XP), so an unchanged card is left alone, and `look` the head in its portrait (cat and coat), so a
-- card passed to another cat of the same kind keeps its 3D head.
type CatCard = {
	frame: Frame,
	portrait: CatPortrait.CatPortrait,
	feed: Button.Button,
	edge: UIStroke,
	edgeBands: UIGradient?,
	head: Frame,
	name: TextLabel,
	nameBands: UIGradient?,
	level: TextLabel,
	fill: Frame,
	key: string,
	look: string?,
	uid: string,
	foodId: string,
	open: boolean,
}

-- one cat in Feed's list, in order, whether its card is made or not
type CatEntry = {
	cat: { uid: string, catId: string, name: string?, level: number },
	def: Types.CatDef?,
	variant: string?,
	xp: number,
	key: string,
}

type Row = {
	frame: Frame,
	tile: Frame,
	count: TextLabel,
	name: TextLabel,
	effect: TextLabel,
	left: TextLabel,
	use: Button.Button,
	useAll: Button.Button, -- #1600
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
	self._fits = {} :: { [string]: number } -- #1600: potion id -> how many Use all drinks now

	local panel = Panel.new({
		dark = true, -- #1028
		name = "Potions",
		title = "Bag",
		subtitle = "Potions, cat food and bait",
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
	self._catRows = {} :: { [string]: CatCard } -- the cards made, by cat uid
	self._catSpare = {} :: { CatCard } -- #2196: cards scrolled out, hidden, for the next cats scrolled in
	self._catOrder = {} :: { CatEntry } -- every cat in the list, highest level first
	self._catFood = "" -- the food the list feeds
	self._baitRows = {} :: { [string]: { frame: Frame, icon: ItemIcon.ItemIcon, count: TextLabel } }
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
			image = ShopIcons.hud("Potion"), -- #1771: the HUD's Potions picture; the glyph shows until it loads
			style = "gold",
			size = UDim2.fromOffset(TAB_W, TAB_H - 4),
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
			icon = ShopIcons.SNACK_GLYPH,
			image = ShopIcons.market("Treats"), -- #1771: the Fish Market's treat
			style = "ghost",
			size = UDim2.fromOffset(TAB_W, TAB_H - 4),
			textSize = Theme.sizes.textBody,
			layoutOrder = 2,
			parent = tabs,
			sound = "uiTab",
			onClick = function()
				self:showTab("Food")
			end,
		}),
		Bait = Button.new({
			name = "BaitTab",
			text = "Bait",
			icon = Theme.icons.food,
			image = ShopIcons.hud("Bowl"), -- #1771: the HUD's Bowl picture
			style = "ghost",
			size = UDim2.fromOffset(TAB_W, TAB_H - 4),
			textSize = Theme.sizes.textBody,
			layoutOrder = 3,
			parent = tabs,
			sound = "uiTab",
			onClick = function()
				self:showTab("Bait")
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
	-- #1281: the Bait tab's list
	self._baitList = (self._list :: ScrollingFrame):Clone()
	self._baitList.Name = "BaitList"
	for _, child in self._baitList:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	self._baitList.Visible = false
	self._baitList.Parent = panel.content
	self._baitHint = text({
		Name = "Hint",
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		Text = "No bait yet. Kibble, Tuna and Salmon are at the Corner Shop.",
		LayoutOrder = 1000,
		Visible = false,
		Parent = self._baitList,
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
		size = UDim2.fromOffset(100, 42), -- over the 36 px a mouse needs (the UI gate's tap check)
		textSize = Theme.sizes.textBody,
		layoutOrder = 0,
		parent = self._catList,
		onClick = function()
			self:_pickFood(nil)
		end,
	})
	-- #2196: the cats above and below the made cards hold their room as two plain spacers, so the scroll bar and
	-- the canvas are as tall as every card would make them
	self._catAbove = Create("Frame", {
		Name = "CardsAbove",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 1,
		Parent = self._catList,
	})
	self._catBelow = Create("Frame", {
		Name = "CardsBelow",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 2,
		Parent = self._catList,
	})
	local function scrolled()
		if self._catList.Visible then
			self:_windowCats()
		end
	end
	self._catScroll = {
		self._catList:GetPropertyChangedSignal("CanvasPosition"):Connect(scrolled),
		self._catList:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(scrolled),
	}

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
		button:setStyle(if name == tab then "gold" else "ghost") -- #1771: as the Store's and the Market's tabs
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
	local bait = self._tab == "Bait"
	self._list.Visible = self._tab == "Potions"
	self._foodList.Visible = food and self._feeding == nil
	self._catList.Visible = food and self._feeding ~= nil
	self._baitList.Visible = bait
	local state: Types.PlayerState? = self._state
	if state ~= nil and bait then
		self:_refreshBait(state)
	end
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

-- #1281: a row per bait food the player has; the count follows the state.
function Potions._refreshBait(self: any, state: Types.PlayerState)
	local catalog: any = self._catalog
	local baits = BagLogic.baits(if catalog then catalog.lures else nil, state.lures)
	local shown: { [string]: boolean } = {}
	for order, entry in baits do
		shown[entry.id] = true
		local row = self._baitRows[entry.id] or self:_baitRow(entry)
		self._baitRows[entry.id] = row
		row.frame.LayoutOrder = order
		row.count.Text = "x" .. entry.count
	end
	for id, row in self._baitRows do
		if not shown[id] then
			row.frame:Destroy()
			self._baitRows[id] = nil
		end
	end
	self._baitHint.Visible = #baits == 0
end

function Potions._baitRow(self: any, entry: BagLogic.Bait)
	local frame: Frame = Create("Frame", {
		Name = entry.id,
		BackgroundColor3 = PAL.card,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, ROW_H),
		Parent = self._baitList,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = PAL.cardStroke, Thickness = Theme.sizes.stroke }),
	})
	local icon = ItemIcon.new({
		parent = frame,
		size = UDim2.fromOffset(TILE, TILE),
		anchorPoint = Vector2.new(0, 0.5),
		position = UDim2.new(0, 10, 0.5, 0),
		badge = "gem",
	})
	icon:setFood(entry.def, entry.id)
	local textLeft = TILE + 24
	local countW = 80
	text({
		Name = "BaitName",
		Position = UDim2.fromOffset(textLeft, 12),
		Size = UDim2.new(1, -(textLeft + countW + 20), 0, 26),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 3,
		Text = entry.name,
		Parent = frame,
	})
	text({
		Name = "Where",
		Position = UDim2.fromOffset(textLeft, 40),
		Size = UDim2.new(1, -(textLeft + countW + 20), 0, 22),
		TextSize = Theme.sizes.textSmall + 1,
		TextColor3 = PAL.subtext,
		Text = "Goes in at your bait bowl",
		Parent = frame,
	})
	local count = text({
		Name = "Count",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(countW, 30),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = frame,
	})
	Outline.text(count, 2)
	return { frame = frame, icon = icon, count = count }
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
		Text = ShopIcons.snackGlyph(entry.id), -- #1616: each size its own
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

-- The cats to feed `food` to, highest level first; a tap feeds that cat one. #2196 (playtester Tyrell via Derek2:
-- "going into the feed menu lags his game", then Derek2 11-07: "Lags the game so bad I am wondering if it renders all
-- your cats it should only render as you scroll"): this runs on every state update and once a second, and a card
-- holds a 3D head (a cloned model in a ViewportFrame), so a card per cat cost hundreds of models on a big save. Now
-- only the cards in view (and CAT_BUFFER each side) are made, a card scrolled out shows the next cat scrolled in, and
-- a card is filled again only when what it shows changed.
function Potions._renderCats(self: any, food: BagLogic.Food)
	local state: any = self._state
	self._catTitle.Text = ("Feed a %s (x%d) · %s"):format(
		food.name,
		food.count,
		BagLogic.xpLine(food.xp)
	)
	local catalog: any = self._catalog
	local names: { [string]: string } = {}
	local byId: { [string]: any } = {}
	local defs: { any } = (if catalog then catalog.cats else nil) or {}
	for _, def in defs do
		if type(def) == "table" and def.id and def.name then
			names[def.id] = def.name
			byId[def.id] = def
		end
	end
	local order: { CatEntry } = {}
	for _, cat in CornerShopLogic.catsByLevel(state.cats, names) do
		local instance = (state.cats or {})[cat.uid]
		local xp = if type(instance) == "table" and type(instance.xp) == "number"
			then instance.xp
			else 0
		local variant = if type(instance) == "table" then instance.variant else nil
		local key = table.concat({
			food.id,
			cat.catId,
			tostring(variant),
			tostring(cat.name),
			tostring(cat.level),
			tostring(xp),
			if byId[cat.catId] then "def" else "",
		}, "|")
		table.insert(
			order,
			{ cat = cat, def = byId[cat.catId], variant = variant, xp = xp, key = key }
		)
	end
	self._catOrder = order
	self._catFood = food.id
	self:_windowCats()
end

-- #2196: makes the cards for the cats in view and frees the rest, from where the list is scrolled to.
function Potions._windowCats(self: any)
	local order: { CatEntry } = self._catOrder
	local list: ScrollingFrame = self._catList
	local pitch = CAT_CARD_H + Theme.sizes.gap
	-- Absolute sizes are drawn pixels, after the window's UI scale; the heading's height gives that scale.
	local scale = self._catTitle.AbsoluteSize.Y / CAT_TITLE_H
	if scale <= 0 then
		scale = 1
	end
	local above = (list.AbsolutePosition.Y - self._catAbove.AbsolutePosition.Y) / scale
	local view = list.AbsoluteWindowSize.Y / scale
	if view <= 0 then
		view = CAT_VIEW
	end
	local first, last = BagLogic.feedWindow(#order, above, view, pitch, CAT_BUFFER)
	local wanted: { [string]: CatEntry } = {}
	for index = first, last do
		wanted[order[index].cat.uid] = order[index]
	end
	-- cards whose cat scrolled out (or left) are hidden for the next ones, or kept where they still show their cat
	for uid, card in self._catRows do
		local entry = wanted[uid]
		if entry == nil or entry.key ~= card.key then
			card.frame.Visible = false
			card.frame.Name = "Spare"
			card.key = ""
			table.insert(self._catSpare, card)
			self._catRows[uid] = nil
		end
	end
	for index = first, last do
		local entry = order[index]
		local card: CatCard? = self._catRows[entry.cat.uid]
		if card == nil then
			local made = self:_spareCard(entry) or self:_catCard()
			self:_fillCard(made, entry)
			self._catRows[entry.cat.uid] = made
			card = made
		end
		(card :: CatCard).frame.LayoutOrder = 2 + index
	end
	self._catAbove.Size = UDim2.new(1, 0, 0, math.max(0, first - 1) * pitch)
	self._catBelow.Size = UDim2.new(1, 0, 0, math.max(0, #order - last) * pitch)
	self._catBelow.LayoutOrder = 3 + #order
end

-- A hidden card for `entry`, the one already holding that cat's head if there is one (so no model is cloned).
function Potions._spareCard(self: any, entry: CatEntry): CatCard?
	local spare: { CatCard } = self._catSpare
	if #spare == 0 then
		return nil
	end
	local look = Potions._look(entry)
	local pick = #spare
	for index, card in spare do
		if card.look == look then
			pick = index
			break
		end
	end
	return table.remove(spare, pick)
end

function Potions._look(entry: CatEntry): string
	return (if entry.def then entry.def.id else "?")
		.. "|"
		.. tostring(CatVariant.isGold(entry.variant))
end

-- #1773: one card in Feed's list, empty until _fillCard: the cat's head on its rarity's colour, the name ("Gold
-- Comet" in gold, a rainbow one in the turning bands, as its edge), "Epic · Level 24 · 2,303 XP to 25" over a bar
-- toward the next level, and Feed, which feeds this cat one (Max at the top level, off).
function Potions._catCard(self: any): CatCard
	local frame: Frame = Create("Frame", {
		Name = "Spare",
		BackgroundColor3 = PAL.card,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, CAT_CARD_H),
		Parent = self._catList,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	local edge: UIStroke = Create("UIStroke", {
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = frame,
	})
	local head: Frame = Create("Frame", {
		Name = "Head",
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Size = UDim2.fromOffset(CAT_HEAD, CAT_HEAD),
		Parent = frame,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	local portrait = CatPortrait.new({
		parent = head,
		size = UDim2.fromScale(1, 1),
		still = true,
		head = true,
	})
	local left = CAT_HEAD + 16
	local right = CAT_FEED_W + 16
	local name = text({
		Name = "CatName",
		Position = UDim2.fromOffset(left, 6),
		Size = UDim2.new(1, -(left + right), 0, 24),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		Parent = frame,
	})
	local level = text({
		Name = "Level",
		Position = UDim2.fromOffset(left, 30),
		Size = UDim2.new(1, -(left + right), 0, 18),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		RichText = true,
		Parent = frame,
	})
	local track: Frame = Create("Frame", {
		Name = "XpBar",
		BackgroundColor3 = Theme.colors.cocoa,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(left, 52),
		Size = UDim2.new(1, -(left + right), 0, 8),
		Parent = frame,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local fill: Frame = Create("Frame", {
		Name = "Fill",
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local card: CatCard
	local feed = Button.new({
		name = "Feed",
		text = "Feed",
		style = "primary",
		size = UDim2.fromOffset(CAT_FEED_W, 40),
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, -8, 0.5, 0),
		textSize = Theme.sizes.textBody + 1,
		parent = frame,
		onClick = function()
			local feedCat: ((string, string) -> ())? = self._callbacks.feed
			if card.open and feedCat then
				feedCat(card.foodId, card.uid)
			end
		end,
	})
	card = {
		frame = frame,
		portrait = portrait,
		feed = feed,
		edge = edge,
		edgeBands = nil :: UIGradient?,
		head = head,
		name = name,
		nameBands = nil :: UIGradient?,
		level = level,
		fill = fill,
		key = "",
		look = nil :: string?,
		uid = "",
		foodId = "",
		open = false,
	}
	return card
end

-- Shows `entry`'s cat on `card`; its 3D head is set again only when the cat or coat changed.
function Potions._fillCard(self: any, card: CatCard, entry: CatEntry)
	local cat, def, variant, xp = entry.cat, entry.def, entry.variant, entry.xp
	local open = BagLogic.canFeed(cat.level)
	local rarity: string = if def then def.rarity else "Common"
	local gold = CatVariant.isGold(variant)
	local rainbow = CatVariant.isRainbow(variant)
	card.key = entry.key
	card.uid = cat.uid
	card.foodId = self._catFood
	card.open = open
	card.frame.Name = cat.uid
	card.frame.Visible = true
	if rainbow and card.edgeBands == nil then
		card.edgeBands = Rainbow.stroke(card.edge)
	end
	if card.edgeBands then
		card.edgeBands.Enabled = rainbow
	end
	card.edge.Color = if rainbow
		then Theme.colors.white
		elseif gold then Theme.colors.gold
		else Theme.rarityColor(rarity)
	card.edge.Thickness = if gold or rainbow then 3 else 2
	card.head.BackgroundColor3 = Theme.rarityColor(rarity)
	local look = Potions._look(entry)
	if card.look ~= look then
		card.portrait:set(def, gold)
		card.look = look
	end
	if rainbow and card.nameBands == nil then
		card.nameBands = Rainbow.text(card.name)
	end
	if card.nameBands then
		card.nameBands.Enabled = rainbow
	end
	card.name.TextColor3 = if rainbow
		then Theme.colors.white
		elseif gold then Theme.colors.gold
		else PAL.text
	card.name.Text = CatVariant.word(variant) .. (cat.name or cat.catId)
	card.level.Text = ('<font color="#%s">%s</font> · %s'):format(
		Theme.rarityLight(rarity):ToHex(),
		rarity,
		BagLogic.catLine(cat.level, xp)
	)
	card.fill.BackgroundColor3 = if open then PAL.good else Theme.colors.gold
	card.fill.Size = UDim2.fromScale(BagLogic.xpFraction(cat.level, xp), 1)
	card.feed:setText(if open then "Feed" else "Max")
	card.feed:setEnabled(open)
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
	local textRight = USE_W + 20 -- _refresh widens it while Use all shows
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
	-- one press: Use drinks one, Use all (#1600) as many as fit; the server cuts the count to what fits again
	local function press(count: number?)
		local pressedAt = self._pending[potionId]
		if pressedAt and os.clock() - pressedAt < PENDING_SECONDS then
			return
		end
		self._pending[potionId] = os.clock()
		self._callbacks.use(potionId, count)
		self:_refresh()
		task.delay(PENDING_SECONDS, function()
			if self._rows[potionId] then
				self:_refresh()
			end
		end)
	end
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
			press(nil)
		end,
	})
	local useAll = Button.new({
		name = "UseAll",
		text = "Use all",
		style = "teal",
		size = UDim2.fromOffset(USE_W, 38),
		anchorPoint = Vector2.new(1, 1),
		position = UDim2.new(1, -(USE_W + 18), 1, -10),
		textSize = Theme.sizes.textBody + 1,
		parent = frame,
		onClick = function()
			local view = self._fits[potionId]
			if view and view >= 2 then
				press(view)
			end
		end,
	})
	useAll.instance.Visible = false
	return {
		frame = frame,
		tile = tile,
		count = count,
		name = name,
		effect = effect,
		left = left,
		use = use,
		useAll = useAll,
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
		-- #1600: Use all while two or more fit, its count on the button; the words make room for it
		self._fits[potion.id] = view.fit
		local many = view.count > 0 and view.fit >= 2
		row.useAll.instance.Visible = many
		row.useAll:setText(if pending then "..." else ("Use x%d"):format(view.fit))
		row.useAll:setEnabled(many and not pending)
		local textRight = if many then 2 * USE_W + 28 else USE_W + 20
		local textLeft = TILE + 24
		row.name.Size = UDim2.new(1, -(textLeft + textRight), 0, 26)
		row.effect.Size = UDim2.new(1, -(textLeft + textRight), 0, 22)
		any = true
	end
	for id, row in self._rows do
		if not shown[id] then
			row.use:destroy()
			row.useAll:destroy()
			self._fits[id] = nil
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
	for _, connection in self._catScroll do
		connection:Disconnect()
	end
	for _, cards in { self._catRows, self._catSpare } do
		for _, card: CatCard in cards do
			card.feed:destroy()
			card.portrait:destroy()
		end
	end
	for _, button in self._tabButtons do
		button:destroy()
	end
	self._back:destroy()
	for _, row in self._rows do
		row.use:destroy()
		row.useAll:destroy()
	end
	table.clear(self._rows)
	self._panel:destroy()
end

return Potions
