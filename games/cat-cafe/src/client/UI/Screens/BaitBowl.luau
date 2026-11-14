--!strict
-- Bait bowl screen (F28, data-model section 8): what is in your bowl and every food you can put in it. A food
-- goes in with Use from anywhere, F included (Derek 2026-10-28); the cat it brings is rolled then and arrives after
-- the wait, even while you are offline, and you choose Tame or Let go when it comes. Since #1612 (Derek2 11-05: "no
-- need to show odds of everything everywhere") each food is one compact row: its picture, name, grade and "You have
-- 3", with Use and Details; Details opens the five-rarity odds in their colours, the gold chance (no charm stars
-- since F97) and the per-cat split (the growth thread's rules for random items). #1281 (corner-shop-v2.md section 1b): no Buy here; the
-- shop foods are sold at the Corner Shop, so each row says "You have 3" and Use, or a calm "Get more at the Corner
-- Shop" with none left. F69: each food's picture wears its grade badge, its card a border
-- in the grade's colour, and the grade by its name (the "Attracts" chip went in #1612); the bowl shows the food in it. F54: the gold
-- chance has the Index's gold luck in it, and the wait the Big Bowl perk and the Index's faster bait; F73 adds a
-- running Gold Rush, Lucky or Quick Bait Potion's, as the server rolls food set now. F60: food set
-- at night waits half, so by night the empty bowl's wait is the night one and a night bowl counts down behind a moon.
-- F82: the odds row, the split and the wait are the bowl level's (shared Bait, as the server rolls), and the title
-- names the bowl you have, "Comfy Bowl" up to "Royal Bowl". The foods run in rarity order, rarest first since #1609
-- (Components/FoodOrder).
-- Opened by the bowl's prompt (UI.bait.openPicker), the HUD bowl chip or F.
-- #1161 (the Second Bait Bowl pass, Derek 2026-11-04: "make sure the bowl menu works perfectly with two bowls"): with a
-- second bowl a row of two bowl tabs sits over the status card, each with its own state ("Empty", the countdown or
-- "Cat!"), and the status card, Use and "See the cat" are the chosen bowl's, so nothing is shared by accident. Without
-- the pass ("offer") bowl 2's tab is locked: choosing it shows a calm "Get a second bowl" card with the pass's
-- picture and its price from Roblox, and three short lines on what it gives (#1767: Derek2 found the seven-food odds
-- table under it "way too much bloated text"; bowl 2's odds are bowl 1's, so one line says so). The screen never opens
-- on the locked tab, so the offer only shows when the player taps it. One bowl only (nil): no tabs, as before.
-- #4266 (Derek 2026-11-14: "add an option to turn on auto claim and auto refill for bait bowl for a game pass idea ...
-- sell it in store aswell as the blank area of bait bowl menu near refill"): behind the `autoBowl` switch, the empty
-- space over Refill holds the Auto Bowl pass. Without it, a small offer card with Roblox's price (hidden until Roblox
-- answers, or off sale); with it, two switches, Auto claim and Auto refill, saved as the settings autoBowlClaim and
-- autoBowlRefill (on until the player turns one off). A switch keeps its tap until the server agrees (#2076).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BigPullLogic = require(script.Parent.Parent.Components.BigPullLogic) -- #1897: the wow cat's bowl line
local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local DayKinds = require(script.Parent.Parent.Components.DayKinds)
local FirstBait = require(script.Parent.Parent.Components.FirstBait)
local FoodGrade = require(script.Parent.Parent.Components.FoodGrade)
local FoodOdds = require(script.Parent.Parent.Components.FoodOdds)
local FoodOrder = require(script.Parent.Parent.Components.FoodOrder)
local Format = require(script.Parent.Parent.Components.Format)
local IconArt = require(script.Parent.Parent.Components.IconArt)
local IndexRewards = require(script.Parent.Parent.Components.IndexRewards)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local LateBuild = require(script.Parent.Parent.Components.LateBuild)
local LuckLogic = require(script.Parent.Parent.Components.LuckLogic)
local MenuFamily = require(script.Parent.Parent.Components.MenuFamily)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local PotionLogic = require(script.Parent.Parent.Components.PotionLogic)
local Scale = require(script.Parent.Parent.Scale)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local StepTarget = require(script.Parent.Parent.Components.StepTarget)
local Theme = require(script.Parent.Parent.Theme)
local TutorialHints = require(script.Parent.Parent.Components.TutorialHints)
local Types = require(script.Parent.Parent.Types)

-- the dark window palette (#1028), in place of Theme.modal
local PAL = MenuFamily.pal
local CARD = MenuFamily.card -- #3558: what sits on a picture card (cream in the family look)

local Bait = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Bait"))
local LiveFlags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags"))

local CART_FLAG = "cartTier6" -- shared/CornerShop.TOP_SHELF_FLAG

export type Callbacks = {
	useLure: (lureId: string, bowl: number) -> (), -- #1161: into bowl 1 or 2
	openUpgrades: () -> (),
	showCat: (bowl: number) -> (), -- reopens that bowl's Tame or Let go card
	buySecond: () -> (), -- #1161: Roblox's purchase window for the Second Bait Bowl pass
	buyAuto: (() -> ())?, -- #4266: Roblox's purchase window for the Auto Bowl pass
	setSetting: ((key: string, on: boolean) -> ())?, -- #4266: an Auto Bowl switch, as SetSetting
	close: () -> (),
}

-- What Roblox said about the Second Bait Bowl pass (as Components/StoreLogic.Price), nil until it answers.
export type PassPrice = { robux: number?, forSale: boolean }

export type BaitBowl = {
	frame: Frame,
	setCatalog: (self: BaitBowl, catalog: Types.Catalog) -> (),
	render: (self: BaitBowl, state: Types.PlayerState) -> (),
	-- `bowl` is 1 or 2 (#1161); nil is 1
	setBait: (self: BaitBowl, bait: Types.BaitView?, catWaiting: boolean, bowl: number?) -> (),
	-- #1161: "on" (the pass: bowl 2 takes food), "offer" (bowl 2 locked, with the pass card) or nil (one bowl)
	setSecond: (self: BaitBowl, kind: string?, price: PassPrice?) -> (),
	select: (self: BaitBowl, bowl: number) -> (), -- shows that bowl's tab
	selected: (self: BaitBowl) -> number,
	openOn: (self: BaitBowl) -> (), -- on open: a bowl with a cat waiting, else an empty one that takes food, else 1
	setNight: (self: BaitBowl, night: boolean) -> (),
	-- #4266: the Auto Bowl pass: owned as Roblox says (PassShop; state.autoBowl is the server's word), and Roblox's
	-- price for the offer (nil until it answers)
	setAuto: (self: BaitBowl, owned: boolean, price: PassPrice?) -> (),
	destroy: (self: BaitBowl) -> (),
}

local AUTO_FLAG = "autoBowl" -- shared/LiveFlags (#4266)
-- the switches top down, their shared/Settings keys (on until turned off), names and words. Derek 2026-11-14 ("for
-- autobowl or free foodbowl make it so it also has an option to toggle off new cat pop ups"): New cat pop-ups is free
-- for everyone; off, a new cat tamed at the bowl is a toast in place of the big Cat found card (UI.showCatFound)
local AUTO_ORDER = { "claim", "refill", "popups" }
local AUTO_KEYS: { [string]: string } =
	{ claim = "autoBowlClaim", refill = "autoBowlRefill", popups = "bowlNewCatCard" }
local AUTO_NAMES: { [string]: string } =
	{ claim = "AutoClaim", refill = "AutoRefill", popups = "NewCatPopups" }
local AUTO_WORDS: { [string]: string } =
	{ claim = "Auto claim", refill = "Auto refill", popups = "New cat pop-ups" }
local AUTO_HOLD = 5 -- SettingsList.HOLD_SECONDS: a tap holds until the server agrees
local AUTO_ROW = 36 -- a switch row, the tap height a mouse needs; touch Hit pads reach 44
local AUTO_PILL_W = 64
local AUTO_HEAD = 20
local AUTO_PAD = 8
local AUTO_OFFER_H = AUTO_PAD * 2 + 40 + AUTO_ROW -- the offer: picture and words, then the price

local STATUS_HEIGHT = 92
-- #1612 (Derek2 11-05: "just have it in a smaller line/image have the symbol the name the rarity of the food (remove
-- what it attracts) remove odds and just put that under details"): a compact row, Use and Details side by side
local BUTTON = Vector2.new(112, Theme.sizes.touchMin)
-- #3008: Refill, three quarters of the status card's 140 x 48 action button, and its food's picture beside it; the
-- two are as wide together as the action button, so they stack under it while a cat waits
local REFILL = Vector2.new(106, 36)
local REFILL_ICON = 30
local ACTION_H = Theme.sizes.touchMin + 4 -- the status card's action button
local DETAILS_W = 100
local DETAILS_H = 42 -- a 37 px face, over the 36 px a mouse needs (the UI gate's tap check)
local ICON = 52 -- the food's picture with its grade gem
local TEXT_LEFT = ICON + 24
local TAB_H = 42 -- the bowl tabs (#1161), as tall as Details
local PERK_LINE = 24 -- #1767: one of the locked bowl 2 card's three lines
-- #3961 (batch 1 mock, station-menus-batch1-3558.png): with the family look the status card is a column down the
-- left (the bowl's picture, what is in it, the wait chip, the buttons at its foot) and the foods are picture cards
-- beside it, each with a round "i" for its odds and a chunky USE
local COLUMN_W = 0.34 -- the status column's share of the window's width
local COLUMN_PICTURE = 56
-- the round "i" that opens a food's odds (its Details). Derek 2026-11-13 ("scale them down a little bit it's very
-- big when barely anyone is checking it"): drawn well under USE, the tap size a mouse needs, and on a phone the
-- button's invisible Hit pad (Components/Button) reaches out to a finger's 44 px so the look shrinks but the tap
-- does not
local INFO = 36
local INFO_TOUCH = 44
local COLUMN_USE_W = 84
-- Derek 2026-11-13 ("the little blue detail buttons overlapping other buttons"): a clean button draws its outline
-- past its box and a hover grows it round its middle (Button.OUTLINE, Button.HOVER_SCALE), so the row's two buttons
-- keep both outlines, the hover and a clear 6 px between them, and Use keeps the same clear of the card's edge
local ROW_GAP = 2 * Button.OUTLINE + math.ceil(COLUMN_USE_W * (Button.HOVER_SCALE - 1) / 2) + 6
local ROW_RIGHT = 12 + Button.OUTLINE + math.ceil(COLUMN_USE_W * (Button.HOVER_SCALE - 1) / 2)
local TITLE = "Bait bowl"
local SUBTITLE = "Put food in and a cat comes to your door"

local BaitBowl = {}
BaitBowl.__index = BaitBowl

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textBody,
		TextColor3 = CARD.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

-- a rarity's odds colour as hex, for FoodOdds.rich
local function rarityHex(rarity: string): string
	-- light odds on the dark cards (#1028); the rarity's ink on the family look's cream cards (#3558)
	return MenuFamily.rarity(rarity):ToHex()
end

-- Text that goes into a RichText label as it reads (the Details text sits under the coloured odds).
local function plain(value: string): string
	return (value:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

function BaitBowl.new(callbacks: Callbacks): BaitBowl
	local self = setmetatable({}, BaitBowl) :: any
	self._callbacks = callbacks
	self._rows = {} :: { [string]: any }
	self._foods = {} :: { Types.LureDef } -- the catalog's foods, rarest first (_buildRows)
	self._catalog = nil :: Types.Catalog?
	self._state = nil :: Types.PlayerState?
	self._baits = {} :: { [number]: Types.BaitView? } -- #1161: bowl 1's and bowl 2's
	self._waiting = { false, false } -- whether each bowl's Tame or Let go card has a cat
	self._second = nil :: string? -- "on", "offer" or nil
	self._price = nil :: PassPrice?
	self._selected = 1
	self._tabsShown = false
	self._tier = 0
	self._extras = "" -- the gold and charm line the Details were written with
	self._waitSeconds = FoodOdds.waitSeconds(0, false, 0)
	self._bowlLevel = 0 -- lure_bowl (F82): the odds and wait are this level's
	self._luck = 1 -- F88: the player's Luck, in the odds rows and the split
	self._bigBowl = false
	self._speed = 0 -- the Index's faster bait (F54) plus a running Quick Bait Potion's (F73)
	self._night = false -- the clock's phase (F60: food set at night waits half)
	self._accumulator = 0
	self._column = MenuFamily.on() -- #3961: the column layout (_layout, _placeStatus)

	local panel = Panel.new({
		dark = true, -- #1028
		name = "Bait",
		color = Theme.colors.mintDark,
		icon = Theme.upgradeIcons.lure_bowl,
		image = ShopIcons.hud("Bait"), -- #2836: the drawn badge (the emoji until it loads)
		title = TITLE,
		subtitle = SUBTITLE,
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = Vector2.new(720, 560), Parent = panel.frame })
	self._panel = panel
	self.frame = panel.frame

	-- #1161: the two bowl tabs, shown with a second bowl (_layout)
	local tabH = Scale.tapHeight(TAB_H, Theme.sizes.buttonDepth)
	self._tabH = tabH
	local tabs: Frame = Create("Frame", {
		Name = "Bowls",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -10, 0, tabH),
		Visible = false,
		Parent = panel.content,
	})
	self._tabs = tabs
	self._tabButtons = {} :: { any }
	for bowl = 1, 2 do
		self._tabButtons[bowl] = Button.new({
			name = "Bowl" .. bowl,
			text = "Bowl " .. bowl,
			style = "ghost",
			size = UDim2.new(0.5, -4, 0, tabH),
			position = UDim2.new((bowl - 1) * 0.5, if bowl == 2 then 4 else 0, 0, 0),
			textSize = Theme.sizes.textSmall,
			parent = tabs,
			onClick = function()
				self:select(bowl)
			end,
		})
	end

	-- Status card: the bowl, what is in it and the countdown
	local status: Frame = Create("Frame", {
		Name = "Status",
		BackgroundColor3 = if MenuFamily.on() then PAL.card else Theme.colors.cocoaDeep,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -10, 0, STATUS_HEIGHT),
		Parent = panel.content,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	self._status = status
	self._statusBorder = Outline.border(status, Theme.sizes.outline)
	local bowlTile: TextLabel = text({
		Name = "Bowl",
		BackgroundColor3 = Theme.colors.caramel,
		BackgroundTransparency = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(64, 64),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 34,
		Text = Theme.icons.food,
		Parent = status,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = bowlTile })
	Outline.border(bowlTile, 2)
	self._bowlTile = bowlTile
	self._bowlPicture = nil :: string? -- the picture IconArt draws on the bowl tile (#1767)
	-- F69: the food in the bowl, with its grade badge, in place of the bowl while it waits
	self._bowlFood = ItemIcon.new({
		parent = status,
		size = UDim2.fromOffset(64, 64),
		anchorPoint = Vector2.new(0, 0.5),
		position = UDim2.new(0, 12, 0.5, -4),
		name = "Food",
	})
	self._bowlFood.frame.Visible = false
	self._bowlLure = nil :: string?
	self._statusTitle = text({
		Name = "Title",
		Position = UDim2.fromOffset(90, 12),
		Size = UDim2.new(1, -250, 0, 26),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge - 2,
		TextColor3 = Theme.colors.white,
		Parent = status,
	})
	Outline.text(self._statusTitle, 2)
	self._statusSub = text({
		Name = "Sub",
		Position = UDim2.fromOffset(90, 40),
		Size = UDim2.new(1, -250, 0, 36),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.hud.subtext,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = status,
	})
	-- countdown bar along the bottom of the status card while a cat is on its way
	self._track = Create("Frame", {
		Name = "Track",
		BackgroundColor3 = if MenuFamily.on() then PAL.line else Theme.colors.cocoa,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 90, 1, -10),
		Size = UDim2.new(1, -250, 0, 8),
		Visible = false,
		Parent = status,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	self._fill = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = self._track,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	self._action = Button.new({
		name = "Action",
		text = "",
		style = "gold",
		size = UDim2.fromOffset(140, ACTION_H),
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, -12, 0.5, 0),
		textSize = Theme.sizes.textBody,
		parent = status,
		onClick = function()
			self:_pressAction()
		end,
	})
	self._actionKind = nil :: string?
	self._actionStyle = "gold"
	-- #3008 (Derek2 11-10: "make the food bowl refill button a bit smaller but always there and it refills with your
	-- best food available"): Refill is its own smaller button under the action's place, there whenever the chosen
	-- bowl takes food and greyed while it can do nothing (food in the bowl, a cat at it, or no food in the bag). The
	-- small picture beside it is the food a press puts in: the rarest the player has (FoodOrder.best). #1573's
	-- Refill was the action button, only for an empty bowl, with the food that bowl last held this session.
	self._refill = Button.new({
		name = "Refill",
		text = "Refill",
		style = "primary",
		size = UDim2.fromOffset(REFILL.X, REFILL.Y),
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, -12, 0.5, 0),
		textSize = Theme.sizes.textSmall,
		parent = status,
		onClick = function()
			self:_pressRefill()
		end,
	})
	self._refillFood = ItemIcon.new({
		parent = status,
		size = UDim2.fromOffset(REFILL_ICON, REFILL_ICON),
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, -12 - REFILL.X - 4, 0.5, 0),
		name = "RefillFood",
		badge = "none", -- too small for the grade's letter; the tile's colour says it
	})
	self._refillFood.frame.Visible = false
	self._refillLure = nil :: string? -- the food drawn beside Refill
	self._footH = 10 -- #4266: the column's foot buttons' height, under the Auto Bowl card
	self._autoOwned = false
	self._autoPrice = nil :: PassPrice?
	self._autoTaps = {} :: { [string]: { value: boolean, at: number } }
	if self._column then
		self:_placeColumn()
		self:_buildAuto()
	end

	self._list = Create("ScrollingFrame", {
		Name = "Foods",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, STATUS_HEIGHT + Theme.sizes.gap + 4),
		Size = UDim2.new(1, 0, 1, -(STATUS_HEIGHT + Theme.sizes.gap + 4)),
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
		Outline.listPadding(10, 6), -- #2294: room for the cards' outlines
	})

	-- #1161, #1767: under the locked bowl 2's card, what the pass gives in three short lines
	local oddsCard: Frame = Create("Frame", {
		Name = "SecondOdds",
		BackgroundColor3 = CARD.card,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 0,
		Visible = false,
		Parent = self._list,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = PAL.caramel, Thickness = Theme.sizes.stroke }),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 16),
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 12),
		}),
		Create("UIListLayout", {
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	text({
		Name = "Heading",
		Size = UDim2.new(1, 0, 0, 26),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge - 2,
		Text = "What you get",
		LayoutOrder = 0,
		Parent = oddsCard,
	})
	local perks: { TextLabel } = {}
	for index = 1, 3 do
		perks[index] = text({
			Name = "Perk" .. tostring(index),
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, PERK_LINE),
			FontFace = Theme.fonts.bodyBold,
			TextSize = Theme.sizes.textBody,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			RichText = true,
			Text = "",
			LayoutOrder = index,
			Parent = oddsCard,
		})
	end
	self._oddsCard = oddsCard
	self._perks = perks

	-- the countdown ticks once a second while the screen is open
	self._tick = RunService.Heartbeat:Connect(function(dt: number)
		if not self.frame.Visible or (self._baits[1] == nil and self._baits[2] == nil) then
			return
		end
		self._accumulator += dt
		if self._accumulator >= 1 then
			self._accumulator = 0
			self:_renderStatus()
		end
	end)
	self:_layout()
	return self :: BaitBowl
end

-- #1161: the tabs over the status card while there are two bowls, and the card and list below them.
function BaitBowl._layout(self: any)
	local state: Types.PlayerState? = self._state
	local shown = state ~= nil
		and (state.upgradeLevels.lure_bowl or 0) >= 1
		and (self._second ~= nil or self._baits[2] ~= nil)
	self._tabsShown = shown
	self._tabs.Visible = shown
	if not shown then
		self._selected = 1
	end
	local top = if shown then self._tabH + Theme.sizes.gap else 0
	self._status.Position = UDim2.fromOffset(0, top)
	if self._column then
		-- #3961: the status column on the left, as tall as the window, and the foods beside it
		self._status.Size = UDim2.new(COLUMN_W, -Theme.sizes.gap, 1, -top - 6)
		self._list.Position = UDim2.new(COLUMN_W, 0, 0, top)
		self._list.Size = UDim2.new(1 - COLUMN_W, 0, 1, -top)
		return
	end
	local listTop = top + STATUS_HEIGHT + Theme.sizes.gap + 4
	self._list.Position = UDim2.fromOffset(0, listTop)
	self._list.Size = UDim2.new(1, 0, 1, -listTop)
end

-- #3961: the column's insides, top down: the picture, the title, the wait chip and its bar, then the buttons at the
-- foot (the action over Refill when both show). Placed once at build; _renderRefill only stacks the buttons.
function BaitBowl._placeColumn(self: any)
	local status = self._status
	local center = Vector2.new(0.5, 0)
	self._bowlTile.AnchorPoint = center
	self._bowlTile.Position = UDim2.new(0.5, 0, 0, 8)
	self._bowlTile.Size = UDim2.fromOffset(COLUMN_PICTURE, COLUMN_PICTURE)
	self._bowlFood.frame.AnchorPoint = center
	self._bowlFood.frame.Position = UDim2.new(0.5, 0, 0, 8)
	self._bowlFood.frame.Size = UDim2.fromOffset(COLUMN_PICTURE, COLUMN_PICTURE)
	-- the title, the wait chip and its bar stack under the picture, so a two-line chip pushes the bar down
	local middle: Frame = Create("Frame", {
		Name = "Middle",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 8 + COLUMN_PICTURE + 10), -- under the food's grade ribbon
		Size = UDim2.new(1, -16, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = status,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, 4),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local title: TextLabel = self._statusTitle
	title.Size = UDim2.new(1, 0, 0, 22)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextScaled = true
	title.LayoutOrder = 1
	title.Parent = middle
	Create("UITextSizeConstraint", {
		MaxTextSize = Theme.sizes.textBody + 2,
		MinTextSize = Theme.sizes.textSmall,
		Parent = title,
	})
	-- the wait as a chip under the title, as the mock's "A cat comes by in 9 min"
	local sub: TextLabel = self._statusSub
	sub.Size = UDim2.new(1, 0, 0, 0)
	sub.AutomaticSize = Enum.AutomaticSize.Y
	sub.TextXAlignment = Enum.TextXAlignment.Center
	sub.BackgroundColor3 = PAL.line
	sub.BackgroundTransparency = 0
	sub.TextColor3 = PAL.text
	sub.FontFace = Theme.fonts.bodyBold
	-- Studio 2026-11-13: "Tame it or let it go. The food is used either way." wraps in full, never cut
	sub.TextWrapped = true
	sub.TextTruncate = Enum.TextTruncate.None
	sub.LayoutOrder = 2
	sub.Parent = middle
	Create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = sub })
	Create("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 3),
		PaddingBottom = UDim.new(0, 3),
		Parent = sub,
	})
	self._track.AnchorPoint = Vector2.zero
	self._track.Size = UDim2.new(1, -8, 0, 8)
	self._track.LayoutOrder = 3
	self._track.Parent = middle
	local wide = UDim2.new(1, -20, 0, ACTION_H)
	self._action.instance.AnchorPoint = Vector2.new(0.5, 1)
	self._action.instance.Size = wide
	self._refill.instance.AnchorPoint = Vector2.new(1, 1)
	-- Refill stays smaller than the action button (#3008), its food's picture beside it
	self._refill.instance.Size = UDim2.new(1, -(20 + REFILL_ICON + 6), 0, REFILL.Y)
	self._refillFood.frame.AnchorPoint = Vector2.new(0, 1)
end

-- #4266: the Auto Bowl card over the column's foot. Without the pass: the offer (picture, name, one line, price) over
-- the New cat pop-ups switch, which is free. With it: AUTO BOWL over its three switches.
function BaitBowl._buildAuto(self: any)
	local card: Frame = Create("Frame", {
		Name = "AutoBowl",
		BackgroundColor3 = CARD.card,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.new(1, -20, 0, 0),
		Visible = false,
		Parent = self._status,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	self._autoStroke = Create(
		"UIStroke",
		{ Color = Theme.colors.gold, Thickness = Theme.sizes.stroke, Parent = card }
	)
	self._autoCard = card
	-- the offer
	local offer: Frame = Create("Frame", {
		Name = "Offer",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, AUTO_OFFER_H),
		Parent = card,
	})
	self._autoOffer = offer
	local icon: TextLabel = text({
		Name = "Icon",
		BackgroundColor3 = Theme.colors.mintDark,
		BackgroundTransparency = 0,
		Position = UDim2.fromOffset(AUTO_PAD, AUTO_PAD),
		Size = UDim2.fromOffset(40, 40),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 24,
		Text = "🥣",
		Parent = offer,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = icon })
	Outline.border(icon, 2)
	text({
		Name = "Name",
		Position = UDim2.fromOffset(AUTO_PAD + 48, AUTO_PAD),
		Size = UDim2.new(1, -(AUTO_PAD * 2 + 48), 0, 22),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody,
		Text = "Auto Bowl",
		Parent = offer,
	})
	text({
		Name = "Line",
		Position = UDim2.fromOffset(AUTO_PAD + 48, AUTO_PAD + 22),
		Size = UDim2.new(1, -(AUTO_PAD * 2 + 48), 0, 18),
		TextSize = Theme.sizes.textTiny + 1,
		TextColor3 = CARD.subtext,
		Text = "Claims cats, refills food",
		Parent = offer,
	})
	self._autoBuy = Button.new({
		name = "BuyAuto",
		text = "",
		style = "store",
		size = UDim2.new(1, -AUTO_PAD * 2, 0, AUTO_ROW),
		anchorPoint = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, 0),
		textSize = Theme.sizes.textBody,
		parent = offer,
		onClick = function()
			local buy: (() -> ())? = self._callbacks.buyAuto
			if buy then
				buy()
			end
		end,
	})
	self._autoHeading = text({
		Name = "Heading",
		Position = UDim2.fromOffset(AUTO_PAD, AUTO_PAD - 2),
		Size = UDim2.new(1, -AUTO_PAD * 2, 0, AUTO_HEAD),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "AUTO BOWL",
		Parent = card,
	})
	-- the switches, one row each: its words on the left and an ON / OFF pill on the right
	self._autoRows = {} :: { [string]: Frame }
	self._autoPills = {} :: { [string]: Button.Button }
	for _, key in AUTO_ORDER do
		local row: Frame = Create("Frame", {
			Name = AUTO_NAMES[key] .. "Row",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -AUTO_PAD * 2, 0, AUTO_ROW),
			Parent = card,
		})
		text({
			Name = "Words",
			Size = UDim2.new(1, -(AUTO_PILL_W + 4), 1, 0),
			FontFace = Theme.fonts.bodyBold,
			TextSize = Theme.sizes.textSmall,
			Text = AUTO_WORDS[key],
			Parent = row,
		})
		self._autoRows[key] = row
		self._autoPills[key] = Button.new({
			name = AUTO_NAMES[key],
			text = "ON",
			style = "primary",
			size = UDim2.fromOffset(AUTO_PILL_W, AUTO_ROW),
			anchorPoint = Vector2.new(1, 0),
			position = UDim2.fromScale(1, 0),
			textSize = Theme.sizes.textTiny + 1,
			parent = row,
			sound = "uiToggle",
			shine = false,
			onClick = function()
				self:_tapAuto(key)
			end,
		})
	end
end

-- #4266: what a switch shows: a fresh tap until the server agrees or AUTO_HOLD pass, else the saved setting (on
-- until turned off).
function BaitBowl._autoValue(self: any, key: string): boolean
	local settingKey = AUTO_KEYS[key]
	local state: Types.PlayerState? = self._state
	local saved = state and state.settings and state.settings[settingKey]
	local server = saved ~= false
	local tap = self._autoTaps[settingKey]
	if tap then
		if tap.value == server or os.clock() - tap.at > AUTO_HOLD then
			self._autoTaps[settingKey] = nil
		else
			return tap.value
		end
	end
	return server
end

function BaitBowl._tapAuto(self: any, key: string)
	local settingKey = AUTO_KEYS[key]
	local on = not self:_autoValue(key)
	self._autoTaps[settingKey] = { value = on, at = os.clock() }
	self:_renderAuto()
	task.delay(AUTO_HOLD + 0.1, function()
		if self._autoCard and self._autoCard.Parent then
			self:_renderAuto() -- the server never agreed (refused): show the saved value again
		end
	end)
	local set: ((string, boolean) -> ())? = self._callbacks.setSetting
	if set then
		set(settingKey, on)
	end
end

function BaitBowl.setAuto(self: any, owned: boolean, price: PassPrice?)
	self._autoOwned = owned
	self._autoPrice = price
	self:_renderAuto()
end

-- #4266: the card over the foot buttons, shown with the switch on, a bowl and the chosen bowl taking food: the
-- offer only while the pass is on sale with its price. It stays off where the column has no room for it.
function BaitBowl._renderAuto(self: any)
	local card: Frame? = self._autoCard
	if card == nil then
		return
	end
	local state: Types.PlayerState? = self._state
	local price: PassPrice? = self._autoPrice
	-- owned by the server's word (state.autoBowl) or Roblox's (PassShop, at once after a purchase)
	local owned: boolean = self._autoOwned
		or (state ~= nil and state.autoBowl ~= nil and state.autoBowl.owned)
	local selling = not owned and price ~= nil and price.forSale and price.robux ~= nil
	local shown = state ~= nil
		and LiveFlags.shown(
			AUTO_FLAG,
			ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. AUTO_FLAG)
		)
		and (state.upgradeLevels.lure_bowl or 0) >= 1
		and self:_takesFood(self._selected)
	-- top down: the heading (owned) or the offer (on sale), then the rows
	local keys: { string } = if owned then AUTO_ORDER else { "popups" }
	local y = if owned then AUTO_PAD + AUTO_HEAD elseif selling then AUTO_OFFER_H + 6 else AUTO_PAD
	local height = y + #keys * AUTO_ROW + (#keys - 1) * 4 + AUTO_PAD
	if shown then
		-- room between the wait chip and the foot buttons (a phone with a cat waiting may have none)
		local scale = Scale.get()
		local k = if scale > 0 then scale else 1
		local middle = self._status:FindFirstChild("Middle") :: GuiObject?
		local top = if middle
			then (
				middle.AbsolutePosition.Y
				+ middle.AbsoluteSize.Y
				- self._status.AbsolutePosition.Y
			) / k
			else 0
		local room = self._status.AbsoluteSize.Y / k - self._footH - top - 2 * Theme.sizes.gap
		shown = room >= height
	end
	card.Visible = shown
	if not shown then
		return
	end
	card.Size = UDim2.new(1, -20, 0, height)
	card.Position = UDim2.new(0.5, 0, 1, -(self._footH + Theme.sizes.gap))
	self._autoStroke.Color = if owned
		then Theme.colors.mintDark
		elseif selling then Theme.colors.gold
		else CARD.cardStroke
	self._autoOffer.Visible = selling
	self._autoHeading.Visible = owned
	if selling and price and price.robux then
		self._autoBuy:setText(("R$%d"):format(price.robux :: number))
	end
	for key, row in self._autoRows do
		local index = table.find(keys, key)
		row.Visible = index ~= nil
		if index then
			row.Position = UDim2.fromOffset(AUTO_PAD, y + (index - 1) * (AUTO_ROW + 4))
			local on = self:_autoValue(key)
			local pill: Button.Button = self._autoPills[key]
			pill:setStyle(if on then "primary" else "slate")
			pill:setText(if on then "ON" else "OFF")
			pill.instance:SetAttribute("On", on)
		end
	end
end

function BaitBowl._buildRows(self: any)
	for _, row in self._rows do
		row.use:destroy()
		row.details:destroy()
		row.icon:destroy()
		row.frame:Destroy()
	end
	table.clear(self._rows)
	self._bowlLure = nil -- the bowl's picture follows the new catalog's food
	local catalog: Types.Catalog? = self._catalog
	if not catalog then
		return
	end
	assert(catalog, "catalog not set; call UI.init first")
	-- every food in rarity order, the night dealer's among the shop's (F97 section 3); rarest first since #1609
	-- (Derek2 11-05), as the Bag's Bait tab
	local foods: { Types.LureDef } = FoodOrder.defs(catalog.lures, true)
	self._foods = foods
	self._ownedSignature = nil -- render puts the foods the player has first (#2323)
	-- on a phone Use and Details grow to a 44 px face and the card's top with them, as in the dealer's list
	local buttonH = Scale.tapHeight(BUTTON.Y, Theme.sizes.buttonDepth)
	local detailsH = Scale.tapHeight(DETAILS_H, Theme.sizes.buttonDepth)
	local topHeight = math.max(ICON + 16, buttonH + 16, detailsH + 16)
	local column: boolean = self._column
	-- #3961: the picture card's words take the width the round "i" leaves (narrower than Details)
	local useW = if column then COLUMN_USE_W else BUTTON.X
	local infoW = if column then (if Scale.isTouch() then INFO_TOUCH else INFO) else DETAILS_W
	local textWidth = -(TEXT_LEFT + useW + infoW + ROW_RIGHT + ROW_GAP + 6)
	if column then
		topHeight = math.max(topHeight, ICON + 22) -- the name, the grade chip and the count, one line each
	end
	for index, lure in foods do
		local dealer = lure.source == "dealer"
		local cart = lure.source == "cart" -- #3462: sold only on the Day Cart
		local row: Frame = Create("Frame", {
			Name = lure.id,
			BackgroundColor3 = CARD.card,
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = index,
			Parent = self._list,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
			-- F69: the card's border in the food's grade colour, like its badge
			Create("UIStroke", {
				Color = Theme.rarityColor(FoodGrade.of(lure)),
				Thickness = Theme.sizes.stroke + 1,
			}),
			Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		local top: Frame = Create("Frame", {
			Name = "Top",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, topHeight),
			LayoutOrder = 1,
			Parent = row,
		})
		local icon = ItemIcon.new({
			parent = top,
			size = UDim2.fromOffset(ICON, ICON),
			anchorPoint = Vector2.new(0, 0.5),
			position = UDim2.new(0, 12, 0.5, 0),
			badge = "gem",
		})
		icon:setFood(lure)
		local heading: Frame = Create("Frame", {
			Name = "Heading",
			BackgroundTransparency = 1,
			Position = UDim2.new(0, TEXT_LEFT, 0.5, if column then -31 else -24),
			Size = UDim2.new(1, textWidth, 0, 24),
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
			Size = UDim2.fromOffset(0, 24),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody + 2,
			Text = lure.name,
			LayoutOrder = 1,
			Parent = heading,
		})
		-- the food's own grade in its colour, where the "Attracts" chip was (#1612)
		local grade = FoodGrade.of(lure)
		local gradeLabel = text({
			Name = "Grade",
			Size = UDim2.fromOffset(90, 24), -- "Legendary" at full width, beside a name of any length
			FontFace = Theme.fonts.bodyBold,
			TextSize = Theme.sizes.textSmall,
			TextColor3 = MenuFamily.rarity(grade),
			TextTruncate = Enum.TextTruncate.None,
			Text = grade,
			LayoutOrder = 2,
			Parent = heading,
		})
		if column then
			-- #3961: the grade as a chip in its colour under the name, as the mock's EPIC and RARE
			gradeLabel.Parent = top
			gradeLabel.Position = UDim2.new(0, TEXT_LEFT, 0.5, -6)
			gradeLabel.Size = UDim2.fromOffset(0, 18)
			gradeLabel.AutomaticSize = Enum.AutomaticSize.X
			gradeLabel.TextXAlignment = Enum.TextXAlignment.Center
			gradeLabel.Text = string.upper(grade)
			gradeLabel.TextSize = Theme.sizes.textTiny
			gradeLabel.TextColor3 = Theme.colors.white
			gradeLabel.BackgroundColor3 = Theme.rarityInk(grade)
			gradeLabel.BackgroundTransparency = 0
			Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = gradeLabel })
			Create("UIPadding", {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				Parent = gradeLabel,
			})
		end
		local count = text({
			Name = "Count",
			Position = UDim2.new(0, TEXT_LEFT, 0.5, if column then 15 else 2),
			Size = UDim2.new(1, textWidth, 0, 18),
			TextSize = Theme.sizes.textSmall,
			TextColor3 = CARD.subtext,
			Parent = top,
		})
		-- Use on the right and Details beside it (#1612); the odds live under Details
		local use = Button.new({
			name = "Use",
			text = if column then "USE" else "Use",
			style = "primary",
			size = UDim2.fromOffset(useW, buttonH),
			anchorPoint = Vector2.new(1, 0.5),
			position = UDim2.new(1, -ROW_RIGHT, 0.5, 0),
			textSize = Theme.sizes.textBody,
			parent = top,
			onClick = function()
				self._callbacks.useLure(lure.id, self._selected)
			end,
		})
		-- #3961: a round sky "i" in the family look, for the same odds
		local details = Button.new({
			name = "Details",
			text = if column then "i" else "Details",
			style = if column then "sky" else "ghost",
			shine = not column, -- the round "i" is plain, no light bar on top (Derek 2026-11-13)
			size = if column
				then UDim2.fromOffset(infoW, infoW)
				else UDim2.fromOffset(DETAILS_W, detailsH),
			anchorPoint = Vector2.new(1, 0.5),
			position = UDim2.new(1, -(ROW_RIGHT + useW + ROW_GAP), 0.5, 0),
			textSize = Theme.sizes.textSmall,
			parent = top,
			onClick = function()
				self:_toggleDetail(lure.id)
			end,
		})
		if column then
			-- the mock's round "i": the button's corners all the way round
			for _, corner in details.instance:GetDescendants() do
				if corner:IsA("UICorner") then
					(corner :: UICorner).CornerRadius = UDim.new(1, 0)
				end
			end
		end
		local detail = text({
			Name = "Detail",
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			TextSize = Theme.sizes.textTiny,
			TextColor3 = CARD.subtext,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			TextYAlignment = Enum.TextYAlignment.Top,
			RichText = true, -- the odds in their colours, then the gold line and the split
			Text = "",
			Visible = false,
			LayoutOrder = 2,
			Parent = row,
		})
		-- Studio 2026-11-13: in the family look the odds start a clear line under the round "i" and USE
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 16),
			PaddingTop = UDim.new(0, if column then 8 else 0),
			PaddingBottom = UDim.new(0, 12),
			Parent = detail,
		})
		self._rows[lure.id] = {
			frame = row,
			icon = icon,
			count = count,
			use = use,
			details = details,
			detail = detail,
			odds = FoodOdds.rich(lure.odds, rarityHex), -- the five-rarity odds at the bowl's level, for Details
			split = nil :: string?, -- the per-cat split for the tier and bowl last drawn
			def = lure,
			dealer = dealer,
			cart = cart,
		}
	end
	self._tier = -1 -- rebuild the odds and split text on the next render
	self._extras = ""
end

function BaitBowl._toggleDetail(self: any, lureId: string)
	local row = self._rows[lureId]
	if not row then
		return
	end
	row.detail.Visible = not row.detail.Visible
	if self._column then
		row.details:setStyle(if row.detail.Visible then "gold" else "sky") -- the "i" lit while its odds show
	else
		row.details:setText(if row.detail.Visible then "Hide details" else "Details")
	end
end

BaitBowl.BUILD_AFTER = 8 -- #3722: seconds after the catalog arrives

function BaitBowl.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	-- #3722: the food rows are built after start-up, or at once when the window opens first
	self._lateBuild = self._lateBuild
		or LateBuild.new(BaitBowl.BUILD_AFTER, function()
			self:_buildRows()
		end, function()
			local last: Types.PlayerState? = self._state
			if last then
				self:render(last)
			end
		end)
	self._lateBuild:queue()
	local state: Types.PlayerState? = self._state
	if state then
		self:render(state)
	end
end

function BaitBowl.setBait(self: any, bait: Types.BaitView?, catWaiting: boolean, bowl: number?)
	local index = if bowl == 2 then 2 else 1
	self._baits[index] = bait
	self._waiting[index] = catWaiting
	self:_layout()
	local state: Types.PlayerState? = self._state
	if state then
		self:render(state)
	end
end

-- #1161: the second bowl's kind from ProfileSync, and the pass's price for the locked tab's card.
function BaitBowl.setSecond(self: any, kind: string?, price: PassPrice?)
	self._second = if kind == "on" or kind == "offer" then kind else nil
	self._price = price
	self:_layout()
	local state: Types.PlayerState? = self._state
	if state then
		self:render(state)
	end
end

function BaitBowl.select(self: any, bowl: number)
	local index = if bowl == 2 and self._tabsShown then 2 else 1
	if self._selected == index then
		return
	end
	self._selected = index
	local state: Types.PlayerState? = self._state
	if state then
		self:render(state)
	end
end

function BaitBowl.selected(self: any): number
	return self._selected
end

-- Bowl 2 takes food only with the pass; a cat already at it can always be tamed or let go.
function BaitBowl._takesFood(self: any, bowl: number): boolean
	return bowl == 1 or self._second == "on"
end

-- The locked bowl 2: no pass and nothing in it, so its tab shows the pass card.
function BaitBowl._locked(self: any, bowl: number): boolean
	return bowl == 2 and self._second ~= "on" and self._baits[2] == nil
end

-- The tab the screen opens on: a cat waiting first, then an empty bowl that takes food, else bowl 1; never the
-- locked one, so the pass card only shows when the player taps its tab.
function BaitBowl.openOn(self: any)
	local pick = 1
	if self._tabsShown and not self._waiting[1] then
		local secondEmpty = self._baits[2] == nil and self:_takesFood(2)
		if self._waiting[2] or (self._baits[1] ~= nil and secondEmpty) then
			pick = 2
		end
	end
	self._selected = pick
end

-- F60: by night the empty bowl promises the night wait; a bowl already filling keeps its own readyAt.
function BaitBowl.setNight(self: any, night: boolean)
	if self._night == night then
		return
	end
	self._night = night
	self._waitSeconds = FoodOdds.waitSeconds(self._bowlLevel, self._bigBowl, self._speed, night)
	if self.frame.Visible then
		self:_renderStatus()
	end
end

local function ownsBowl(state: Types.PlayerState): boolean
	return (state.upgradeLevels.lure_bowl or 0) >= 1
end

function BaitBowl.render(self: any, state: Types.PlayerState)
	self._state = state
	self:_layout()
	if not self.frame.Visible then
		return -- money ticks re-render every screen; this one catches up when it opens
	end
	if self._lateBuild ~= nil then
		self._lateBuild:ensure()
	end
	local catalog: Types.Catalog? = self._catalog
	-- the odds row and the split are the bowl level's (F82) at the player's Luck (F88), the split the tier's areas too
	local bowlLevel: number = state.upgradeLevels.lure_bowl or 0
	local luck = LuckLogic.current(state, Workspace:GetServerTimeNow())
	local oddsChanged = catalog ~= nil
		and (state.tier ~= self._tier or bowlLevel ~= self._bowlLevel or luck ~= self._luck)
	self._bowlLevel = bowlLevel
	if catalog and oddsChanged then
		self._tier = state.tier
		self._luck = luck
		self._panel:setTitle(if bowlLevel >= 1 then Bait.bowlName(bowlLevel) else TITLE, SUBTITLE)
		for _, row in self._rows do
			row.odds = FoodOdds.rich(FoodOdds.atBowl(row.def.odds, bowlLevel, luck), rarityHex)
			row.split = FoodOdds.split(catalog, row.def, state.tier, bowlLevel, luck)
		end
	end
	local totals = if catalog then IndexRewards.totals(catalog, state) else nil
	local boosts = PotionLogic.boosts(catalog, state, Workspace:GetServerTimeNow())
	local fishPerks: { [string]: number } = state.fishPerks or {}
	self._bigBowl = (fishPerks.big_bowl or 0) >= 1
	self._speed = (if totals then totals.baitSpeed else 0) + boosts.baitSpeed
	self._waitSeconds = FoodOdds.waitSeconds(bowlLevel, self._bigBowl, self._speed, self._night)
	-- #1895: the account's first bait waits at most FirstBaitWaitSeconds (shared Bait.firstWait), so the empty bowl
	-- promises that
	self._waitSeconds = FirstBait.firstWait((state :: any).firstBait, self._waitSeconds)
	-- Details: the gold chance with the Index's gold luck (F54) and the running potions (F73) in it and the charm
	-- stars, then the split
	local extras = FoodOdds.extras(
		if totals then totals.goldLuck else 0,
		boosts.goldLuck,
		boosts.goldScale,
		DayKinds.current.golden -- #1572: a Golden Day's x2
	)
	-- F99: under the gold line once rainbow rolls exist; #1572 a Rainbow Day's x3
	local rainbow = FoodOdds.rainbow(state.rainbowLuck, nil, DayKinds.current.rainbow)
	if rainbow then
		extras ..= "\n" .. rainbow
	end
	if oddsChanged or extras ~= self._extras then
		self._extras = extras
		for _, row in self._rows do
			row.detail.Text = row.odds .. "\n" .. plain(extras .. "\n" .. (row.split or ""))
		end
	end
	local owned = ownsBowl(state)
	local selected: number = self._selected
	local empty = self._baits[selected] == nil
	local takes = self:_takesFood(selected)
	local locked = self:_locked(selected)
	self._oddsCard.Visible = locked
	if locked then
		self:_renderPerks(luck)
	end
	-- #2323: the foods the player has first, rarest at the top, then the rest; rows move only when that set changes
	local mine: { string } = {}
	for _, lure in self._foods do
		if (state.lures[lure.id] or 0) > 0 then
			table.insert(mine, lure.id)
		end
	end
	local signature = table.concat(mine, ",")
	if signature ~= self._ownedSignature then
		self._ownedSignature = signature
		for index, lure in FoodOrder.ownedFirst(self._foods, state.lures) do
			local row = self._rows[lure.id]
			if row then
				row.frame.LayoutOrder = index
			end
		end
	end
	-- #3462: the Day Cart's own foods stay off the list until its Tier 6 shelf is open (the `cartTier6` switch)
	local cartOpen = LiveFlags.shown(
		CART_FLAG,
		ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. CART_FLAG)
	)
	for lureId, row in self._rows do
		local have = state.lures[lureId] or 0
		-- the locked tab shows what bowl 2 gives in place of the foods
		row.frame.Visible = not locked and FoodOrder.listed(row.def, have, cartOpen)
		-- #1281: where to get more, in calm grey, with none left: the night dealer's cart or the Corner Shop
		if have > 0 then
			row.count.Text = ("You have %d"):format(have)
		elseif row.dealer then
			row.count.Text = "Sold by the night dealer's cart"
		elseif row.cart then
			row.count.Text = "Sold on the Day Cart from Tier 6"
		else
			row.count.Text = "Get more at the Corner Shop"
		end
		row.use:setEnabled(owned and takes and empty and have > 0)
		-- #2697: while the tutorial asks for food in the bowl, the Kibble row's Use rings
		StepTarget.ui(
			row.use.face,
			lureId == TutorialHints.KIBBLE
				and owned
				and takes
				and empty
				and have > 0
				and TutorialHints.ask(
						TutorialHints.view(state, if catalog then catalog.spots else nil)
					)
					== "food"
		)
	end
	self:_renderStatus()
end

-- #1767: the locked bowl 2's three lines; the odds are bowl 1's, so they get one line, not a table per food.

function BaitBowl._renderPerks(self: any, luck: number)
	-- the plus in the card's good green (dark on the family look's cream card)
	local PERK_MARK = ('<font color="#%s">+</font> '):format(
		(if MenuFamily.on() then CARD.good else Color3.fromHex("7CFC6A")):ToHex()
	)
	local perks: { TextLabel } = self._perks
	perks[1].Text = PERK_MARK .. "A second bowl by your door"
	perks[2].Text = PERK_MARK .. "Two baits at once: two cats on the way"
	perks[3].Text = PERK_MARK
		.. (
			if luck > 1
				then ("Same odds as bowl 1, and your %s helps both"):format(
					plain(LuckLogic.text(luck))
				)
				else "Same foods and odds as bowl 1"
		)
end

-- #1161: each tab's state, "Bowl 1 · 4m 10s", "Bowl 2 · Empty" or "Bowl 2 · Cat!", the chosen one in gold.
function BaitBowl._renderTabs(self: any)
	if not self._tabsShown then
		return
	end
	local now = Workspace:GetServerTimeNow()
	for bowl, button in self._tabButtons do
		local bait: Types.BaitView? = self._baits[bowl]
		local label: string
		if self:_locked(bowl) then
			label = Theme.icons.lock .. " Bowl 2"
		elseif bait == nil then
			label = ("Bowl %d · Empty"):format(bowl)
		elseif bait.readyAt - now <= 0 then
			label = ("Bowl %d · Cat!"):format(bowl)
		else
			label = ("Bowl %d · %s"):format(bowl, Format.duration(math.ceil(bait.readyAt - now)))
		end
		button:setText(label)
		button:setStyle(if bowl == self._selected then "gold" else "ghost")
	end
end

-- The status card's states: no bowl yet, empty, a cat on its way, a cat at the bowl, and (#1161) the locked bowl 2.
function BaitBowl._renderStatus(self: any)
	local state: Types.PlayerState? = self._state
	if not state then
		return
	end
	self:_renderTabs()
	local selected: number = self._selected
	local bait: Types.BaitView? = self._baits[selected]
	local title: string
	local sub: string
	local action: string? = nil
	local ready = false
	local picture: string? = nil -- #1767: the pass's own picture on the locked bowl 2's card
	self._track.Visible = false
	if not ownsBowl(state) then
		title = "No bait bowl yet"
		sub = "Buy the Bait bowl in Upgrades, then put food in it to bring a cat to your door."
		action = "upgrades"
	elseif self:_locked(selected) then
		title = "Get a second bowl"
		sub = "Two baits at once, so twice the cats come to your door."
		action = "buy"
		picture = ShopIcons.store("secondBowl")
	elseif bait == nil then
		title = if self._tabsShown
			then ("Bowl %d is empty"):format(selected)
			else "Your bowl is empty"
		local wait = Format.duration(self._waitSeconds)
		-- #1693: just the wait; the Refill and Use buttons explain themselves
		sub = if not self:_takesFood(selected)
			then "Bowl 2 takes new food with the Second Bait Bowl pass."
			elseif self._night then ("%s Night bait: a cat comes by in %s"):format(
				Theme.icons.moon,
				wait
			)
			else "A cat comes by in " .. wait
	else
		local left = bait.readyAt - Workspace:GetServerTimeNow()
		local foodName = bait.lureId
		local food: Types.LureDef? = nil
		for _, row in self._rows do
			if row.def.id == bait.lureId then
				foodName = row.def.name
				food = row.def
			end
		end
		if self._bowlLure ~= bait.lureId then
			self._bowlLure = bait.lureId
			self._bowlFood:setFood(food, bait.lureId)
		end
		if left > 0 then
			title = if bait.wow == true
				then BigPullLogic.WOW_LINE -- #1897: the first wow cat on its way (the food shows in the picture)
				elseif self._tabsShown then foodName .. " is in bowl " .. tostring(selected)
				else foodName .. " is in the bowl"
			local inTime = Format.duration(math.ceil(left))
			sub = if bait.night
				then ("%s Night bait: a cat comes by in %s"):format(Theme.icons.moon, inTime)
				elseif FirstBait.coming(bait) then "A cat is coming! "
					.. inTime -- #1895: the short first wait
				else "A cat comes by in " .. inTime
			-- the bowl's own wait from placedAt, else today's for its phase
			local total = if bait.placedAt
				then bait.readyAt - bait.placedAt
				else FoodOdds.waitSeconds(
					self._bowlLevel,
					self._bigBowl,
					self._speed,
					bait.night
				)
			self._track.Visible = true
			self._fill.Size = UDim2.fromScale(math.clamp(1 - left / math.max(total, 1), 0, 1), 1)
		else
			ready = true
			local waiting = self._waiting[selected] == true
			title = if self._tabsShown
				then ("A cat is at bowl %d!"):format(selected)
				else "A cat is at your bowl!"
			sub = if waiting
				then "Tame it or let it go. The food is used either way."
				else "It is sitting down at your bowl now."
			if waiting then
				action = "cat"
			end
		end
	end
	self._bowlFood.frame.Visible = bait ~= nil and ownsBowl(state)
	self._bowlTile.Visible = not self._bowlFood.frame.Visible
	if picture ~= self._bowlPicture then
		self._bowlPicture = picture
		IconArt.setImage(self._bowlTile, picture)
	end
	self._statusTitle.Text = title
	self._statusTitle.TextColor3 = if ready then Theme.colors.gold else Theme.colors.white
	self._statusSub.Text = sub
	self._statusBorder.Color = if ready then Theme.colors.gold else Theme.colors.outline
	self._actionKind = action
	self._action.instance.Visible = action ~= nil
	local style = "gold"
	local enabled = true
	if action == "upgrades" then
		self._action:setText("Upgrades")
	elseif action == "cat" then
		self._action:setText("See the cat")
	elseif action == "buy" then
		-- the price from Roblox, never from here (shop-and-pass-plan section 1): "..." until it answers, Soon off sale
		local price: PassPrice? = self._price
		if price == nil then
			self._action:setText("...")
			style, enabled = "ghost", false
		elseif not price.forSale or price.robux == nil then
			self._action:setText("Soon")
			style, enabled = "ghost", false
		else
			self._action:setText(("R$%d"):format(price.robux :: number))
			style = "store"
		end
	end
	if style ~= self._actionStyle then
		self._actionStyle = style
		self._action:setStyle(style :: any)
	end
	self._action:setEnabled(enabled)
	self:_renderRefill(state, action)
	self:_renderAuto()
end

-- #3008: Refill and its food's picture. There whenever the player has a bowl and the chosen one takes food; greyed
-- unless the bowl is empty and the bag holds a food. Alone it sits where the action button does; under "See the cat"
-- when both show.
function BaitBowl._renderRefill(self: any, state: Types.PlayerState, action: string?)
	local selected: number = self._selected
	local shown = ownsBowl(state) and self:_takesFood(selected)
	self._refill.instance.Visible = shown
	local stacked = action ~= nil
	if self._column then
		-- #3961: Refill at the column's foot with its food beside it, the action over it when both show. Studio
		-- 2026-11-13: with no bowl yet (no Refill) the Upgrades button still sits at the column's foot, inside it
		local gap = Theme.sizes.gap
		self._action.instance.Position =
			UDim2.new(0.5, 0, 1, if stacked and shown then -(10 + REFILL.Y + gap) else -10)
		self._refill.instance.Position = UDim2.new(1, -10, 1, -10)
		self._refillFood.frame.Position = UDim2.new(0, 10, 1, -10 - (REFILL.Y - REFILL_ICON) / 2)
		self._footH = 10
			+ (if shown then REFILL.Y else 0)
			+ (if stacked and shown then gap else 0)
			+ (if stacked then ACTION_H else 0)
	end
	if not shown then
		self._refillFood.frame.Visible = false
		return
	end
	local food: Types.LureDef? = FoodOrder.best(self._foods or {}, state.lures)
	local y = if stacked then (STATUS_HEIGHT - REFILL.Y) / 2 - 2 else 0
	if not self._column then
		self._action.instance.Position =
			UDim2.new(1, -12, 0.5, if stacked then -(STATUS_HEIGHT - ACTION_H) / 2 + 2 else 0)
		self._refill.instance.Position = UDim2.new(1, -12, 0.5, y)
		self._refillFood.frame.Position = UDim2.new(1, -12 - REFILL.X - 4, 0.5, y)
	end
	self._refillFood.frame.Visible = food ~= nil
	local lureId = if food then food.id else nil
	if lureId ~= self._refillLure then
		self._refillLure = lureId
		if food then
			self._refillFood:setFood(food, food.id)
		end
		self._refill:setText(if food then "Refill" else "No food")
	end
	self._refill:setEnabled(food ~= nil and self._baits[selected] == nil)
end

function BaitBowl._pressRefill(self: any)
	local state: Types.PlayerState? = self._state
	local selected: number = self._selected
	if state == nil or not ownsBowl(state) or not self:_takesFood(selected) then
		return
	end
	if self._baits[selected] ~= nil then
		return
	end
	local food = FoodOrder.best(self._foods or {}, state.lures)
	if food then
		self._callbacks.useLure(food.id, selected)
	end
end

function BaitBowl._pressAction(self: any)
	if self._actionKind == "upgrades" then
		self._callbacks.openUpgrades()
	elseif self._actionKind == "cat" then
		self._callbacks.showCat(self._selected)
	elseif self._actionKind == "buy" then
		self._callbacks.buySecond()
	end
end

function BaitBowl.destroy(self: any)
	self._tick:Disconnect()
	for _, row in self._rows do
		row.use:destroy()
		row.details:destroy()
		row.icon:destroy()
	end
	self._action:destroy()
	self._refill:destroy()
	self._refillFood:destroy()
	if self._autoBuy then
		self._autoBuy:destroy()
		for _, pill in self._autoPills do
			pill:destroy()
		end
	end
	for _, button in self._tabButtons do
		button:destroy()
	end
	self._bowlFood:destroy()
	self._panel:destroy()
end

return BaitBowl
