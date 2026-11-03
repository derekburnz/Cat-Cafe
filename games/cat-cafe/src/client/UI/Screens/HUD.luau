--!strict
-- Always-on overlay in the simulator layout (docs/design/cat-cafe/ui-contract.md, HUD v3):
--   bottom left   the money with the rate beside the amount, then the golden fish (F52), one row in the corner
--                 (Derek 2026-10-28); a tap on the money opens the boosts card (Components/BoostList: what lifts the
--                 cafe's money, the exact amount on top), a tap on the golden fish shows its exact amount; the potion
--                 timers sit over the row, or beside the menu's arrow tab on a short screen, led by the Luck chip (F88,
--                 Screens/LuckChip: "🍀 Luck x1.3" from the first Luck source, a tap opens its card)
--   top right     small icon buttons (Tutorial, Rewards for the gifts and the Daily Treat, Trade, Feedback, and Menu for
--                 Settings and Invite; Rewards and Menu open a short list), the day and night clock
--                 under them with the next Lucky Day under it (F88: "🍀 Lucky Day in 2 days"),
--                 the tier and next goal block (Screens/GoalCard) under that and the quest line under that (F73: the
--                 closest unfinished daily, "📜 Catch 5 cats 3/5", or "📜 2 ready to claim"; a tap opens Quests), and
--                 under it "🎡 Free spin at the Town Square" while today's free spin waits (F49)
--   Lighter HUD (Derek 2026-10-28, after a look at popular Roblox HUDs): counters, the clock and the goal are outlined
--   text with no box behind them; only things you press look like buttons, and the top centre is left clear.
--   left          square symbol tiles two to a row, three on a short screen that would need three rows (Derek
--                 2026-11-02, fewer buttons): Store (gold, once a pass is on sale), Cats, Index, Quests, Upgrades, Decor, with small key caps and red "!" dots, centred in the
--                 space over the counters, and an arrow tab under them (beside the last row on a short screen) that
--                 folds them off the edge. Quests (F73) shows once ProfileSync has quests, with a red count of what is
--                 ready to claim
--   bottom centre the gold My Cafe teleport, Alley and Areas (an arrow tab folds the row away), moved right of the
--                 counters on a narrow screen; above them the carry banner with its red Drop button, and the tutorial
--                 strip above that
--   bottom right  the Potions symbol (the bag) and, once the Bait bowl upgrade is owned, the bowl symbol
-- F87 (easy-start.md section 2f, Components/HudUnlocks): until the first loop is done only the money, the hint, Home
-- and the Alley (or the Cannon), the Tutorial tile and Settings show; each other piece appears as it unlocks, with a
-- gold "New!" on its button for NEW_SECONDS.
-- Laid out in design pixels under one UIScale from Scale.bind.
--
-- F92 (playing-together.md sections 2 and 5): the pal chip (Screens/PalChip) closes the potion timers' row while pals
-- are on the server, the boosts card gets their "Pals (2)" row, Invite sends Roblox's invite with this player's name
-- in its launch data (Components/Invite), and a joiner whose pal is out in an area sees "Sam is in the Park" over the
-- glowing Cannon (Screens/PalMarker).
--
-- Roblox terms: SocialService:PromptGameInvite opens Roblox's own invite-friends window; the game only asks.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local BoostList = require(script.Parent.Parent.Components.BoostList)
local BuffChips = require(script.Parent.BuffChips)
local Button = require(script.Parent.Parent.Components.Button)
local CannonLogic = require(script.Parent.Parent.Components.CannonLogic)
local CatPortrait = require(script.Parent.Parent.Components.CatPortrait)
local Create = require(script.Parent.Parent.Components.Create)
local FishCoin = require(script.Parent.Parent.Components.FishCoin)
local Format = require(script.Parent.Parent.Components.Format)
local GoalCard = require(script.Parent.GoalCard)
local HudUnlocks = require(script.Parent.Parent.Components.HudUnlocks)
local IndexRewards = require(script.Parent.Parent.Components.IndexRewards)
local Invite = require(script.Parent.Parent.Components.Invite)
local LuckChip = require(script.Parent.LuckChip)
local LuckLogic = require(script.Parent.Parent.Components.LuckLogic)
local MoneyFlash = require(script.Parent.Parent.Components.MoneyFlash)
local NetButtonPlace = require(script.Parent.Parent.Components.NetButtonPlace)
local NightClock = require(script.Parent.Parent.Components.NightClock)
local Notices = require(script.Parent.Parent.Notices)
local Outline = require(script.Parent.Parent.Components.Outline)
local PalChip = require(script.Parent.PalChip)
local PalMarker = require(script.Parent.PalMarker)
local QuestLogic = require(script.Parent.Parent.Components.QuestLogic)
local RankUp = require(script.Parent.RankUp)
local Scale = require(script.Parent.Parent.Scale)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local Signal = require(script.Parent.Parent.Components.Signal)
local Sound = require(script.Parent.Parent.Components.Sound)
local SpinLogic = require(script.Parent.Parent.Components.SpinLogic)
local Theme = require(script.Parent.Parent.Theme)
local TipJarLogic = require(script.Parent.Parent.Components.TipJarLogic)
local TradeLogic = require(script.Parent.Parent.Components.TradeLogic)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

export type Callbacks = {
	openScreen: (name: Types.ScreenName) -> (),
	travel: (destination: string) -> (), -- "home" or an AreaId
	openBait: () -> (), -- the bowl chip opens the bait bowl screen, or the cat waiting at the bowl
	openIndex: () -> (), -- the Index on its cat pages, or closes it
	equipBest: () -> (),
	dropCat: () -> (), -- the carry banner's Drop button
	replayIntro: () -> (), -- the Tutorial tile (F72)
	hideTutorialButton: () -> (), -- the Tutorial tile's red ×
	openFeedback: () -> (), -- the Feedback tile: the Feedback window on its Idea chip
}

export type HUD = {
	screenGui: ScreenGui,
	setCatalog: (self: HUD, catalog: Types.Catalog) -> (),
	render: (self: HUD, state: Types.PlayerState) -> (),
	setCarrying: (self: HUD, info: Types.CarryInfo?) -> (),
	setTutorial: (self: HUD, text: string?) -> (),
	setClock: (self: HUD, clock: Types.ClockState?) -> (),
	setLuckyDay: (self: HUD, view: LuckLogic.DayView?) -> (),
	-- F101: "🏁 Rescue Rally in 5h 20m" under the clock in the last hours before a Rally, nil hides it
	setRallySoon: (self: HUD, line: string?) -> (),
	-- F101: the potion timers' row (with the Luck and pal chips), which the Rally banner keeps clear of on a phone
	buffRow: (self: HUD) -> GuiObject,
	luckShown: (self: HUD) -> boolean,
	setAreasOpen: (self: HUD, open: boolean) -> (),
	setBait: (self: HUD, bait: Types.BaitView?, catWaiting: boolean) -> (),
	pressTravel: (self: HUD, destination: string) -> boolean,
	setCannonMode: (self: HUD, on: boolean) -> (),
	travelResult: (self: HUD, destination: string, ok: boolean) -> (),
	isCarrying: (self: HUD) -> boolean,
	bottomTop: (self: HUD) -> number,
	setCatching: (self: HUD, active: boolean) -> (),
	-- F101: fires (active) when a catch or rescue starts or ends, so the Rally banner gets out of its way
	catchingChanged: Signal.Signal,
	isCatching: (self: HUD) -> boolean,
	setMenuFolded: (self: HUD, folded: boolean) -> (),
	setTravelFolded: (self: HUD, folded: boolean) -> (),
	screenOpened: (self: HUD, name: string?) -> (),
	setTipJar: (self: HUD, summary: { ready: number, nextIn: number?, left: number }?) -> (),
	setDailyTreat: (self: HUD, shown: boolean, due: boolean) -> (),
	-- the gold Store tile at the top of the left menu, hidden until a pass is on sale (init's Store block)
	setStore: (self: HUD, open: (() -> ())?) -> (),
	setTutorialButton: (self: HUD, shown: boolean) -> (),
	glowTutorial: (self: HUD) -> (),
	pulseTutorial: (self: HUD) -> (),
	setVisible: (self: HUD, visible: boolean) -> (),
	-- F92: the pals on the server (PalsChanged), for the chip and the boosts card
	setPals: (self: HUD, userIds: { number }) -> (),
	-- F92: "Sam is in the Park" over the travel button to that area, glowing; nil text takes it away
	palArrived: (self: HUD, palUserId: number, text: string?) -> (),
	destroy: (self: HUD) -> (),
}

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local MARGIN = 16
-- the money and golden fish counters, one row in the bottom left corner with no box behind them (the lighter HUD);
-- each is as wide as its amount, the money at most MONEY_W, and MONEY_H tall
local MONEY_W = 232
local MONEY_H = 44
local COUNTER_COIN = 36
local COUNTER_TEXT = 30
local COUNTER_GAP = 14
-- the row's widest usual reach (the money at MONEY_W and "12.3K" golden fish): the bottom row moves right of it
local CORNER_W = MONEY_W + COUNTER_GAP + COUNTER_COIN + 8 + 90
local BUFFS_GAP = 8 -- the potion timers sit this far over the counters (F64)
local BOOSTS_W = 300 -- the money's boosts card
local BOOST_ROW_H = 24
-- F66: in the last DUSK_SECONDS of a day the clock turns orange and counts to night; CLOSED_TEXT is the Alley
-- button while the areas are shut for the night
local DUSK_SECONDS: number = (Config :: any).DuskWarningSeconds or 15
local CLOSED_TEXT = Theme.icons.moon .. " Closed"
local STORE_ICON = "🛍️" -- the Store tile's glyph, under its clean treasure chest picture until that loads
local BOWL_ICON = "🥣" -- the bait bowl symbol's glyph, under the Big Bowl perk's picture
-- Fewer buttons (Derek 2026-11-02: "find a way to group some of the buttons into less screen clutter"; "changing
-- some buttons into just symbols"): the left menu is a two-column grid of square symbol tiles, not wide pills.
-- Since 2026-11-03 (Derek: "Build it as shown") they are clean tiles, the label under each square, and the Store is
-- one wide gold tile over the grid ("make sure the store is good and stands out as thats how we will make robux").
-- On a touch screen the label sits inside each tile (Button layout "tile") and the Store is the grid's first square,
-- so the grid stays up at the top, clear of Roblox's thumbstick on a small phone.
local TOUCH = Scale.isTouch()
local TILE_LAYOUT: Button.Layout = if TOUCH then "tile" else "clean"
local MENU_TILE = if TOUCH then 64 else 78
local MENU_TEXT = if TOUCH then Theme.sizes.textTiny + 1 else 17 -- a menu tile's label
local MENU_CELL_H = if TOUCH then MENU_TILE else MENU_TILE + MENU_TEXT + 4 -- the square and the label's strip
local STORE_H = 80 -- the Store's wide tile, two tiles wide, over the grid
local STORE_TEXT = 27
-- the Store's shine sweeps across in 0.9 s, then waits 3.5 s, for good; a still shine under reduced motion
local STORE_SHINE =
	TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, false, 3.5)
local MENU_COLUMNS = 2
-- a short screen (a phone) whose grid would run three rows deep takes three tiles a row, so the bottom row stays out
-- of Roblox's thumbstick in the bottom left (review N343: the Store tile's row put Upgrades there)
local MENU_COLUMNS_SHORT = 3
-- on a touch screen the grid also keeps out of the bottom left's last 180 px, where Roblox's thumbstick sits (the UI
-- gate's thumbstick zone), so a phone takes three tiles a row before its third row reaches down there
local THUMB_ZONE = 180
local MENU_GAP = 14 -- between the columns, so a tile's red dot clears its neighbour's key letter
local function menuWidth(columns: number): number
	return columns * MENU_TILE + (columns - 1) * MENU_GAP
end
local MENU_W = menuWidth(MENU_COLUMNS)
local TRAVEL_ICON = 28 -- the pictures on the Rewards and Menu lists' rows
-- the bottom row is clean tiles since 2026-11-03 (Derek: "cafe and cannon button redo", then "Build it as shown"):
-- a square each with its label under it, a little apart so a long label ("Walk it home") clears its neighbours. On a
-- touch screen the label sits inside the tile (Button layout "tile"), so the row stays low and the corner pair and
-- the right column keep their room on a small phone.
local TRAVEL_W = if TOUCH then 80 else 82
local TRAVEL_TEXT = if TOUCH then Theme.sizes.textTiny + 1 else 17
local TRAVEL_GAP = 14
-- the potion and bait bowl symbols, bottom right (moved clear of Roblox's jump button on a phone: _placeCorner)
local SYMBOL = if TOUCH then 64 else 74 -- a little smaller on touch, where the pair may move (_placeCorner)
local SYMBOL_TEXT = if TOUCH then Theme.sizes.textTiny else 16
local SYMBOL_H = if TOUCH then SYMBOL else SYMBOL + SYMBOL_TEXT + 4 -- the square, and its label under it
local CORNER_GAP = 14
local SYMBOL_ROW_W = 2 * SYMBOL + CORNER_GAP
-- every bottom row tile the same, My Cafe too (Derek 2026-10-27 22:26)
local TRAVEL_H = if TOUCH then 64 else TRAVEL_W + TRAVEL_TEXT + 4
local TRAVEL_ROW_W = 3 * TRAVEL_W + 2 * TRAVEL_GAP
-- top right icon buttons; on a phone a little bigger, so each face reaches a finger's 44 px under its lip (F102 took
-- them out of the UI gate's baseline)
local ICON = Scale.tapHeight(60)
local ICON_TEXT = Theme.sizes.textSmall -- the label under each top right tile
local ICON_H = ICON + ICON_TEXT + 4
-- Tutorial, Gifts, Daily (F70), Feedback, Settings, Trade (F102, from TradeMinTier) and Invite
local ICON_ROW_W = 5 * ICON + 4 * Theme.sizes.gap -- Tutorial, Rewards, Trade, Feedback, Menu
-- the Rewards and Menu tiles open a short list under the icon row when they hold more than one thing
local POP_W = 220
local POP_ROW_H = Scale.tapHeight(44, Theme.sizes.buttonDepth)
local POP_PAD = 8
local HIDE_HIT = 30 -- the Tutorial tile's × takes taps this big round its 20 px red dot
-- F72: the Tutorial tile's two gold pulses the first time it shows after an intro
local GLOW = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 1, false, 0.15)
local CARRY_W = 420
local CARRY_H = 56
local DROP_W = 104
-- the arrow tabs that fold the left menu and the bottom row out of the way (Derek 2026-10-27: less clutter)
local FOLD_W = 44
local FOLD_H = 34
local function menuFoldedX(width: number): number
	return -(width + 40) -- past the left edge, dots too
end
local HOME_TEXT = "My Cafe"
local HOME_CARRYING_TEXT = "Walk it home" -- the server refuses trips while carrying, so the button says why
local HOME_CAMP_TEXT = "Camp first" -- the same with the Cat Cannon live: a carried cat is checked in at a camp (F84)
local CARRY_SUB = "Walk home and check in at your door"
-- F19: the server allows one trip per 3 s; the row greys for the same time so a double tap is not refused
local TRAVEL_COOLDOWN: number = Config.TravelCooldownSeconds
-- right column: icon row (58), the clock line, then the tier and next goal block; the night tips line pushes it down
local CLOCK_TOP = MARGIN + ICON_H + Theme.sizes.gap
local CLOCK_H = 30
local CLOCK_W = 200
local GOAL_TOP = CLOCK_TOP + CLOCK_H + 6
local NIGHT_LINE = 20
local LUCKY_LINE_W = 260 -- F88: the Lucky Day line under the clock
-- The top right column (icon row, clock, tips line, tier and goal) is this wide at most. The HUD keeps clear of
-- Roblox's top bar, which left a tall empty band over that column (Derek 2026-10-27); when the bar's free stretch
-- (GuiService.TopbarInset) runs over the column, the column moves up into it. TOPBAR_SLACK is how far short of the
-- screen's right edge that stretch may stop and still count.
local RIGHT_COLUMN_W = math.max(300, ICON_ROW_W)
local QUEST_LINE_W = 300 -- F73: the quest line under the goal card
local QUEST_LINE_H = 24
-- F49: the Town Square's red free-spin dot went with its place bubble (Derek 2026-10-28 01:39), so the HUD says it
-- instead (Derek okayed 12:02): a gold line under the quest line, no box, not a button, since the wheel is a station
-- you walk up to
local SPIN_TEXT = Theme.icons.spin .. " Free spin at the Town Square"
local TUTORIAL_DONE = 5 -- the tutorial's last step (UIController.refreshTutorial): the quest line waits for it
local TOPBAR_SLACK = 48
-- F87: a newly unlocked button's gold "New!" stays this long
local NEW_SECONDS = 6
-- the left menu tiles each small HUD key shows (F87; Quests has its own rule too, Potions is the corner symbol)
local PILL_KEYS: { [string]: HudUnlocks.Key } = {
	Cats = "cats",
	Index = "index",
	Upgrades = "upgrades",
	Decor = "decor",
}
-- data-model NightIncomeMultiplier: tips pay this share at night (F31: 0.6; F60: 1, full pay, so no line)
local NIGHT_TIPS: number = Config.NightIncomeMultiplier

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

-- A counter or the clock: no box (the lighter HUD), just the outlined text and its coin or sun.
local function bare(name: string, props: { [string]: any }, children: { Instance }?): Frame
	local merged: { [string]: any } = {
		Name = name,
		BackgroundTransparency = 1,
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("Frame", merged, children)
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

function HUD.new(parent: Instance, callbacks: Callbacks): HUD
	local self = setmetatable({}, HUD) :: any
	self._callbacks = callbacks
	self._connections = {} :: { RBXScriptConnection }
	self._clockConnection = nil :: RBXScriptConnection?
	self._buttons = {} :: { any }
	self._catalog = nil :: Types.Catalog?
	self._lastMoney = nil :: number?
	self._lastFish = nil :: number?
	self._areasOpen = true -- F66: false from dusk to sunrise (the Clock folder's AreasOpen)
	self._night = false -- the clock's phase is night (F60: night bait waits half)
	self._alleyClosed = false -- what the Alley button shows now
	self._cannonMode = false -- F84: Cannon in place of Areas, no Alley button, the carry banner points at the camp
	-- red dots on the menu tiles: keys seen when each screen was last open (Notices)
	self._dots = {} :: { [string]: Frame }
	self._seen = { Upgrades = {}, Decor = {} } :: { [string]: { [string]: boolean } }
	self._candidates = nil :: Notices.Candidates?
	self._indexReady = 0 -- Index rewards waiting to be claimed (F48)
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

	-- Money and golden fish (bottom left, Derek 2026-10-28: "The money and coins should be displayed in bottom left"):
	-- one row in the corner, each counter a button that sizes itself to its amount. A tap on the money opens the boosts
	-- card (what lifts the cafe's money, Components/BoostList); a tap on the golden fish shows the exact amount.
	local counters: Frame = Create("Frame", {
		Name = "Counters",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, MARGIN, 1, -MARGIN),
		Size = UDim2.fromOffset(0, MONEY_H),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = root,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, COUNTER_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._counters = counters
	-- a phone's finger needs 44 px, so the counters' tap areas grow there (the amounts stay the same size)
	local counterH = Scale.tapHeight(MONEY_H)
	self._counterH = counterH
	counters.Size = UDim2.fromOffset(0, counterH)
	-- the money is a button (it opens the boosts card); the golden fish is a plain frame, since a tap on it does
	-- nothing (Derek 2026-11-03: "The golden fish shouldn't do anything when clicked")
	local function counter(name: string, order: number, className: string): GuiObject
		local props: { [string]: any } = {
			Name = name,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(0, counterH),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = order,
			Parent = counters,
		}
		if className == "TextButton" then
			props.Text = ""
			props.AutoButtonColor = false
		end
		return Create(className, props, {
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
	end
	local money = counter("Money", 1, "TextButton") :: TextButton
	-- the gold coin badge, then the amount. The rate per second shows only in the boosts card a tap opens (Derek
	-- 2026-11-02: "how much per second should be hidden until clicked also").
	local coin: Frame = Create("Frame", {
		Name = "Coin",
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(COUNTER_COIN, COUNTER_COIN),
		LayoutOrder = 1,
		Parent = money,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		label({
			Size = UDim2.fromScale(1, 1),
			TextSize = 22,
			TextColor3 = Theme.colors.white,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = Theme.currencySymbol,
		}),
	})
	Outline.border(coin, 2.5)
	Outline.shade(coin, 0.2)
	local line: Frame = Create("Frame", {
		Name = "Line",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, MONEY_H),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		Parent = money,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		-- no clip, so the last letter and its dark outline always show whole ("$1.23B" was cut, Derek 2026-11-02);
		-- the amount is short (Format.money), and the golden fish keeps clear of the widest one
		Create("UISizeConstraint", { MaxSize = Vector2.new(MONEY_W - COUNTER_COIN - 8, MONEY_H) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 5) }),
	})
	self._moneyText = label({
		Name = "Amount",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 36),
		TextSize = COUNTER_TEXT,
		TextTruncate = Enum.TextTruncate.None,
		Text = Format.money(0),
		LayoutOrder = 1,
		Parent = line,
	})

	-- Golden fish (F52): the rare currency's counter beside the money, with the gold fish (F97). Hidden until
	-- ProfileSync sends goldenFish.
	local fish = counter("Fish", 2, "Frame")
	fish.Visible = false
	self._fishPanel = fish
	FishCoin.new({
		parent = fish,
		size = COUNTER_COIN,
		name = "Coin",
	}).LayoutOrder = 1
	self._fishText = label({
		Name = "Amount",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, MONEY_H),
		TextSize = COUNTER_TEXT,
		TextTruncate = Enum.TextTruncate.None,
		TextColor3 = Theme.fish.text,
		Text = "0",
		LayoutOrder = 2,
		Parent = fish,
	})

	-- Potion timers (F64): a chip per running potion beside the Potions tile (_placePotionTimers), and the Luck and pal
	-- chips' row over the counters (beside the menu's arrow tab on a short screen); a tap on a potion opens the bag
	self._buffs = BuffChips.new(root, MARGIN, function()
		callbacks.openScreen("Potions")
	end)
	local timers: Frame = self._buffs.potions
	local timersResized: RBXScriptConnection = timers
		:GetPropertyChangedSignal("AbsoluteSize")
		:Connect(function()
			self:_placePotionTimers()
		end)
	table.insert(self._connections, timersResized)

	-- The boosts card over the counters (built last, so it draws over the menu): a tap on the money opens and closes
	-- it, a tap on the card closes it, and any window opening closes it.
	table.insert(
		self._connections,
		money.Activated:Connect(function()
			self:_toggleBoosts()
		end)
	)

	-- Icon row (top right): small square buttons like the calendar, mail and gear icons of popular simulators.
	-- Tutorial replays the intro (F72), Gifts opens the Tip Jar (F47) and counts down to the next playtime gift,
	-- Daily opens the Daily Treat card (F70), Feedback the Feedback window on its Idea chip (2026-11-01: an easy,
	-- visible way to send feedback, where Settings > Help hid it), the gear opens Settings, Invite opens Roblox's own
	-- invite window. Since 2026-11-02 (fewer buttons) Gifts and Daily share the Rewards tile and Settings and Invite
	-- the Menu tile, each opening a short list (_openPop); Feedback stays its own tile (the ads list needs it seen).
	local icons: Frame = Create("Frame", {
		Name = "Icons",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -MARGIN, 0, MARGIN),
		Size = UDim2.fromOffset(ICON_ROW_W, ICON_H),
		Parent = root,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._icons = icons
	self._lift = 0 -- design px the top right column sits higher, up in the top bar's free stretch
	-- Tutorial (F72): purple with a "?", a small red × in its corner hides it (Settings brings it back). Hidden until
	-- the intro is live (UI.intro, state.introSeen) and while the Tutorial button setting is off; greyed while
	-- carrying or during a catch or rescue.
	local tutorial = Button.new({
		name = "Tutorial",
		text = "Tutorial",
		icon = Theme.icons.tutorial,
		image = ShopIcons.clean("Tutorial"),
		layout = "clean",
		textSize = ICON_TEXT,
		style = "purple",
		size = UDim2.fromOffset(ICON, ICON_H),
		layoutOrder = 1,
		parent = icons,
		onClick = function()
			callbacks.replayIntro()
		end,
	})
	tutorial.instance.Visible = false
	if tutorial.icon then
		Outline.text(tutorial.icon, 3) -- the white "?" glyph, until the clean picture loads, needs the dark outline
	end
	table.insert(self._buttons, tutorial)
	self._tutorialTile = tutorial
	self._tutorialEnabled = true
	self._catching = false
	self.catchingChanged = Signal.new()
	local hide: TextButton = Create("TextButton", {
		Name = "Hide",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(HIDE_HIT, HIDE_HIT),
		ZIndex = 8,
		Parent = tutorial.instance,
	})
	local hideDot: Frame = Create("Frame", {
		Name = "Dot",
		BackgroundColor3 = Theme.colors.red,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(20, 20),
		ZIndex = 8,
		Parent = hide,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(hideDot, 2)
	label({
		Name = "Cross",
		Size = UDim2.fromScale(1, 1),
		TextSize = Theme.sizes.textSmall,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "×",
		ZIndex = 9,
		Parent = hideDot,
	})
	table.insert(
		self._connections,
		hide.Activated:Connect(function()
			Sound.play("uiClose")
			callbacks.hideTutorialButton()
		end)
	)

	-- Rewards (Derek 2026-11-02, fewer buttons): one tile for the Tip Jar's playtime gifts (F47) and the Daily Treat
	-- (F70). "Claim!" with a red count while either has something waiting, else the time to the next gift. With both
	-- live a press opens a short list under the row; with one it opens that window at once.
	local rewards = Button.new({
		name = "Rewards",
		text = "Rewards",
		icon = Theme.icons.gifts,
		image = ShopIcons.clean("Rewards"),
		layout = "clean",
		textSize = ICON_TEXT,
		style = "close",
		size = UDim2.fromOffset(ICON, ICON_H),
		layoutOrder = 2,
		parent = icons,
		sound = false, -- the list or the modal swish is the sound
		onClick = function()
			self:_pressRewards()
		end,
	})
	rewards.instance.Visible = false -- until the first TipJarState or Daily Treat card
	table.insert(self._buttons, rewards)
	self._rewards = rewards
	self._rewardsText = "Rewards"
	self._gift = nil :: { ready: number, nextIn: number?, left: number }?
	self._dailyDue = false
	-- red count of what is ready to claim, on the tile's top right corner
	local rewardsDot: Frame = Create("Frame", {
		Name = "Dot",
		BackgroundColor3 = Theme.colors.red,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(24, 24),
		Visible = false,
		ZIndex = 6,
		Parent = rewards.instance,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(rewardsDot, 2)
	self._rewardsDot = rewardsDot
	self._rewardsCount = label({
		Name = "Count",
		Size = UDim2.fromScale(1, 1),
		TextSize = Theme.sizes.textSmall,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
		ZIndex = 7,
		Parent = rewardsDot,
	})
	self._feedbackTile = Button.new({
		name = "Feedback",
		text = "Feedback",
		icon = Theme.icons.feedback,
		image = ShopIcons.clean("Feedback"),
		layout = "clean",
		textSize = ICON_TEXT,
		style = "sky",
		size = UDim2.fromOffset(ICON, ICON_H),
		layoutOrder = 4,
		parent = icons,
		sound = false, -- the modal swish is the sound
		onClick = function()
			callbacks.openFeedback()
		end,
	})
	table.insert(self._buttons, self._feedbackTile)
	-- Menu (Derek 2026-11-02, fewer buttons): Settings and Invite behind one gear. Once Invite is unlocked a press
	-- opens the short list; before that it opens Settings.
	self._menuTile = Button.new({
		name = "Menu",
		text = "Menu",
		icon = Theme.icons.settings,
		image = ShopIcons.clean("Menu"),
		layout = "clean",
		textSize = ICON_TEXT,
		style = "slate",
		size = UDim2.fromOffset(ICON, ICON_H),
		layoutOrder = 7,
		parent = icons,
		sound = false, -- the list's click or the Settings swish is the sound
		onClick = function()
			self:_pressMenu()
		end,
	})
	table.insert(self._buttons, self._menuTile)
	-- F102 (trading.md section 3): the Trade window, from TradeMinTier (Workspace's live value, so a test server's
	-- lower minimum shows it too); hidden below it
	self._tradeTile = Button.new({
		name = "Trade",
		text = "Trade",
		icon = TradeLogic.ICON,
		layout = "clean",
		textSize = ICON_TEXT,
		style = "teal",
		size = UDim2.fromOffset(ICON, ICON_H),
		layoutOrder = 6,
		parent = icons,
		sound = false, -- the modal swish is the sound
		onClick = function()
			callbacks.openScreen("Trade")
		end,
	})
	self._tradeTile.instance.Visible = false
	table.insert(self._buttons, self._tradeTile)
	-- The short list the Rewards and Menu tiles open under the icon row (_openPop): a dark card of full-width rows.
	local pop = hudPanel("Pop", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -MARGIN, 0, MARGIN + ICON_H + 6),
		Size = UDim2.fromOffset(POP_W, POP_ROW_H + 2 * POP_PAD),
		Visible = false,
		ZIndex = 20,
	})
	Create("UIPadding", {
		PaddingTop = UDim.new(0, POP_PAD),
		PaddingBottom = UDim.new(0, POP_PAD),
		PaddingLeft = UDim.new(0, POP_PAD),
		PaddingRight = UDim.new(0, POP_PAD),
		Parent = pop,
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = pop,
	})
	self._pop = pop
	self._popFor = nil :: string?
	self._popRows = {} :: { [string]: Button.Button }

	-- Clock (top right, under the icon row): the sun or moon and the time to the next phase (F20), right-aligned
	-- outlined text with no chip behind it ("☀ Day 3:29")
	local clock = bare("Clock", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -MARGIN, 0, CLOCK_TOP),
		Size = UDim2.fromOffset(CLOCK_W, CLOCK_H),
		Visible = false,
		Parent = root,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._clock = clock
	local sky: Frame = Create("Frame", {
		Name = "Sky",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(26, 26),
		LayoutOrder = 1,
		Parent = clock,
	})
	self._sun = Create("Frame", {
		Name = "Sun",
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(22, 22),
		Parent = sky,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIStroke", { Color = Theme.colors.outline, Thickness = 2.5 }),
	})
	-- the crescent glyph: the old drawn crescent cut its shape with a disc of the chip's colour, which needs a chip
	self._moon = Create("TextLabel", {
		Name = "Moon",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.fonts.display,
		TextSize = 24,
		Text = Theme.icons.moon,
		Visible = false,
		Parent = sky,
	})
	self._clockText = label({
		Name = "Phase",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, CLOCK_H),
		TextSize = 22,
		TextTruncate = Enum.TextTruncate.None,
		Text = "",
		LayoutOrder = 2,
		Parent = clock,
	})
	-- v0.3 (F31): tips pay less at night, so a line under the clock says by how much; hidden while night pays in
	-- full (F60)
	self._nightTips = label({
		Name = "NightTips",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -MARGIN, 0, CLOCK_TOP + CLOCK_H),
		Size = UDim2.fromOffset(CLOCK_W, NIGHT_LINE),
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.colors.sky,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "Money " .. Format.percent(NIGHT_TIPS), -- F94 section 5: "money", not "tips"
		Visible = false,
		Parent = root,
	})
	-- F88 (luck-and-rare-moments.md 1c): the next Lucky Day under the clock, in gold, from the Clock folder's Day,
	-- NextLuckyDay and LuckyDay (LuckLogic.dayLine); shown with the clock
	self._luckyLine = label({
		Name = "LuckyDay",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -MARGIN, 0, CLOCK_TOP + CLOCK_H),
		Size = UDim2.fromOffset(LUCKY_LINE_W, NIGHT_LINE),
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.colors.gold,
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = false,
		Parent = root,
	})
	self._luckyDay = nil :: LuckLogic.DayView?
	-- F101 (rescue-rally.md section 1): the Friday countdown to the Rescue Rally, under the Lucky Day line
	self._rallyLine = label({
		Name = "RallySoon",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -MARGIN, 0, CLOCK_TOP + CLOCK_H),
		Size = UDim2.fromOffset(LUCKY_LINE_W, NIGHT_LINE),
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.colors.white,
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = false,
		Parent = root,
	})
	self._rallySoon = nil :: string?

	-- Tier and next goal (right, under the clock): the tier, the next tier's requirements as slim bars; a tap opens
	-- rank up
	self._goal = GoalCard.new(root, UDim2.new(1, -MARGIN, 0, GOAL_TOP), function()
		callbacks.openScreen("RankUp")
	end)
	-- F73: one outlined line under it, the closest unfinished daily quest or what is ready to claim; a tap opens Quests
	local questLine: TextButton = Create("TextButton", {
		Name = "QuestLine",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -MARGIN, 0, GOAL_TOP),
		Size = UDim2.fromOffset(QUEST_LINE_W, QUEST_LINE_H),
		Visible = false,
		Parent = root,
	})
	self._questLine = questLine
	self._spinLine = label({
		Name = "FreeSpin",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(QUEST_LINE_W, QUEST_LINE_H),
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.colors.gold,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = SPIN_TEXT,
		Visible = false,
		Parent = root,
	})
	self._spinTimer = nil :: thread?
	self._questText = label({
		Name = "Text",
		Size = UDim2.fromScale(1, 1),
		TextSize = Theme.sizes.textBody,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = questLine,
	})
	table.insert(
		self._connections,
		questLine.Activated:Connect(function()
			Sound.play("uiClick")
			callbacks.openScreen("Quests")
		end)
	)
	-- the column follows the top bar as Roblox's menu opens and closes and as the window resizes
	table.insert(
		self._connections,
		GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function()
			self:_liftRight()
		end)
	)
	self._scaleConnection = Scale.changed:Connect(function()
		self:_liftRight()
	end)
	self:_liftRight()

	-- Menu (left, vertically centred): square symbol tiles two to a row, the "Shop / Index" grid of popular
	-- simulators (Derek 2026-11-02: "group some of the buttons into less screen clutter"; they were wide pills). A small
	-- key cap shows the keyboard shortcut and a red "!" dot says the screen has something new. The gold Store tile
	-- leads the grid once a pass is on sale (setStore); Potions moved to a symbol in the bottom right corner.
	local showKeys = UserInputService.KeyboardEnabled
	type MenuItem = {
		name: string,
		icon: string,
		key: string?,
		style: Button.Style,
		dot: Types.ScreenName?, -- the Notices screen whose news lights this pill's dot
		open: () -> (),
	}
	local menuItems: { MenuItem } = {
		{
			name = "Store",
			icon = STORE_ICON,
			style = "store",
			open = function()
				local open: (() -> ())? = self._storeOpen
				if open then
					open()
				end
			end,
		},
		{
			name = "Cats",
			icon = Theme.icons.cats,
			key = "C",
			style = "secondary",
			open = function()
				callbacks.openScreen("Cats")
			end,
		},
		{
			name = "Index",
			icon = Theme.icons.collection,
			style = "primary",
			dot = "Collection",
			open = function()
				callbacks.openIndex()
			end,
		},
		{
			name = "Quests",
			icon = Theme.icons.quests,
			key = "J",
			style = "gold",
			open = function()
				callbacks.openScreen("Quests")
			end,
		},
		{
			name = "Upgrades",
			icon = Theme.icons.upgrades,
			key = "U",
			style = "danger",
			dot = "Upgrades",
			open = function()
				callbacks.openScreen("Upgrades")
			end,
		},
		{
			name = "Decor",
			icon = Theme.icons.decor,
			key = "B",
			style = "teal",
			dot = "Decor",
			open = function()
				callbacks.openScreen("Decor")
			end,
		},
	}
	-- placed by _layoutMenu in the space over the counters; hidden tiles leave no hole in the grid
	local menuLayout: UIGridLayout = Create("UIGridLayout", {
		CellSize = UDim2.fromOffset(MENU_TILE, MENU_CELL_H),
		CellPadding = UDim2.fromOffset(MENU_GAP, Theme.sizes.gap),
		FillDirection = Enum.FillDirection.Horizontal,
		FillDirectionMaxCells = MENU_COLUMNS,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	self._menuLayout = menuLayout
	local menu: Frame = Create("Frame", {
		Name = "Menu",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(MARGIN, MARGIN),
		Size = UDim2.fromOffset(MENU_W, MENU_CELL_H),
		Parent = root,
	}, { menuLayout :: Instance })
	self._pills = {} :: { [string]: Button.Button }
	for index, item in menuItems do
		-- the Store is its own wide tile over the grid (placed by _layoutMenu), the rest are the grid's squares
		local isStore = item.name == "Store" and not TOUCH
		local button = Button.new({
			name = item.name,
			text = item.name,
			icon = item.icon,
			image = ShopIcons.clean(item.name),
			layout = if isStore then "wide" else TILE_LAYOUT,
			style = item.style,
			size = if isStore
				then UDim2.fromOffset(MENU_W, STORE_H)
				else UDim2.fromOffset(MENU_TILE, MENU_CELL_H),
			textSize = if isStore then STORE_TEXT else MENU_TEXT,
			layoutOrder = index,
			parent = if isStore then root else menu,
			sound = false, -- the modal swish is the sound
			onClick = item.open,
		})
		local key = item.key
		if showKeys and key then
			keycap(button.face, key, UDim2.fromOffset(-4, -4))
		end
		local screen = item.dot
		if screen then
			-- red "!" dot on the tile's top right corner when the screen has something new
			local dot: Frame = Create("Frame", {
				Name = "Dot",
				BackgroundColor3 = Theme.colors.red,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(1, -3, 0, 3),
				Size = UDim2.fromOffset(22, 22),
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
			self._dots[screen] = dot
		end
		if item.name == "Store" then
			button.instance.Visible = false -- until setStore hands it a window to open
			self._storeTile = button
			-- it stands out (Derek 2026-11-03: "make sure the store is good and stands out"): a soft gold glow round
			-- it and a white shine that sweeps across now and then. Decoration only: no timer, no sale badge.
			local corner = math.floor((if TOUCH then MENU_TILE else STORE_H) * 0.26) -- Button's corner for its height
			Create("Frame", {
				Name = "Glow",
				BackgroundColor3 = Theme.colors.gold,
				BackgroundTransparency = 0.45,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(-6, -6),
				Size = UDim2.new(1, 12, 1, 12),
				ZIndex = 0,
				Parent = button.instance,
			}, { Create("UICorner", { CornerRadius = UDim.new(0, corner + 6) }) })
			local sweep: Frame = Create("Frame", {
				Name = "Sweep",
				BackgroundColor3 = Theme.colors.white,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 2, -- over the fill, under the chest and the word
				Parent = button.face,
			}, { Create("UICorner", { CornerRadius = UDim.new(0, corner) }) })
			local band: UIGradient = Create("UIGradient", {
				Rotation = 20,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.42, 1),
					NumberSequenceKeypoint.new(0.5, 0.4),
					NumberSequenceKeypoint.new(0.58, 1),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Offset = Vector2.new(if GuiService.ReducedMotionEnabled then 0.12 else -1, 0),
				Parent = sweep,
			})
			if not GuiService.ReducedMotionEnabled then
				self._storeShine = Tween.to(band, STORE_SHINE, { Offset = Vector2.new(1, 0) })
			end
		elseif item.name == "Quests" then
			-- F73: hidden until ProfileSync has quests; a red count of quests and achievements ready to claim
			button.instance.Visible = false
			self._questsPill = button
			local dot: Frame = Create("Frame", {
				Name = "Dot",
				BackgroundColor3 = Theme.colors.red,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(1, -3, 0, 3),
				Size = UDim2.fromOffset(22, 22),
				Visible = false,
				ZIndex = 6,
				Parent = button.instance,
			}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
			Outline.border(dot, 2)
			self._questCount = label({
				Name = "Mark",
				Size = UDim2.fromScale(1, 1),
				TextSize = Theme.sizes.textSmall,
				TextXAlignment = Enum.TextXAlignment.Center,
				Text = "",
				ZIndex = 7,
				Parent = dot,
			})
			self._questDot = dot
		end
		self._pills[item.name] = button
		table.insert(self._buttons, button)
	end
	self._menu = menu
	self._storeOpen = nil :: (() -> ())?
	self._menuFolded = false
	-- The arrow tab under the tiles folds them off the left edge and back. Key binds still open every screen while
	-- they are folded, and the tab carries a red dot whenever a folded pill has one, so news is never hidden.
	local menuFold = Button.new({
		name = "MenuFold",
		text = "◀",
		style = "ghost",
		size = UDim2.fromOffset(FOLD_W, FOLD_H),
		textSize = Theme.sizes.textBody,
		parent = root,
		onClick = function()
			self:setMenuFolded(not self._menuFolded)
		end,
	})
	table.insert(self._buttons, menuFold)
	self._menuFold = menuFold
	self._menuTop = MARGIN
	self._gridTop = MARGIN
	self._foldBeside = false
	self._buffsLow = true -- the potion row sits over the counters (_layoutMenu), not beside the arrow tab
	self._travelShift = 0
	local foldDot: Frame = Create("Frame", {
		Name = "Dot",
		BackgroundColor3 = Theme.colors.red,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(18, 18),
		Visible = false,
		ZIndex = 6,
		Parent = menuFold.instance,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(foldDot, 2)
	self._menuFoldDot = foldDot

	-- Bottom right corner (Derek 2026-11-02: "a clean potion symbol bottom right and then clicking it opens the menu of
	-- which to use"): two symbol tiles side by side, Potions (the bag, with how many it holds) and, once the Bait bowl
	-- upgrade is owned, the bowl (F28) with its state under the picture: "Add food", the time to the cat, "Cat!" on gold.
	local corner: Frame = Create("Frame", {
		Name = "Corner",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -MARGIN, 1, -MARGIN),
		Size = UDim2.fromOffset(SYMBOL_ROW_W, SYMBOL_H),
		Parent = root,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, CORNER_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._corner = corner
	local potions = Button.new({
		name = "Potions",
		text = "Potions",
		icon = Theme.icons.potion,
		image = ShopIcons.clean("Potion"),
		layout = TILE_LAYOUT,
		textSize = SYMBOL_TEXT,
		style = "purple",
		size = UDim2.fromOffset(SYMBOL, SYMBOL_H),
		layoutOrder = 1,
		parent = corner,
		sound = false, -- the modal swish is the sound
		onClick = function()
			callbacks.openScreen("Potions")
		end,
	})
	table.insert(self._buttons, potions)
	self._potionsTile = potions
	if showKeys then
		keycap(potions.face, "P", UDim2.fromOffset(-4, -4))
	end
	-- how many potions are in the bag (F64), a paper pill on the top right corner (white, not red: it is a count, not
	-- news); hidden with none
	local potionCount: TextLabel = Create("TextLabel", {
		Name = "Count",
		BackgroundColor3 = Theme.colors.paper,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -5, 0, 3),
		Size = UDim2.fromOffset(28, 22),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.colors.ink,
		Text = "",
		Visible = false,
		ZIndex = 6,
		Parent = potions.instance,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(potionCount, 2)
	self._potionCount = potionCount
	local bowl = Button.new({
		name = "Bowl",
		text = "Add food",
		icon = BOWL_ICON,
		image = ShopIcons.clean("Bowl"),
		layout = TILE_LAYOUT,
		textSize = SYMBOL_TEXT,
		style = "secondary",
		size = UDim2.fromOffset(SYMBOL, SYMBOL_H),
		layoutOrder = 2,
		parent = corner,
		sound = false, -- the bait screen plays uiOpen itself
		onClick = function()
			self._callbacks.openBait()
		end,
	})
	if showKeys then
		keycap(bowl.face, "F", UDim2.fromOffset(-4, -4))
	end
	bowl.instance.Visible = false -- once the Bait bowl upgrade is owned (_renderBowlSlot)
	table.insert(self._buttons, bowl)
	self._bowl = bowl
	self._bowlSlot = bowl.instance
	self._bowlText = "Add food"
	self._bowlStyle = "secondary" :: Button.Style
	self._bait = nil :: Types.BaitView?
	self._catWaiting = false
	self._baitLoop = nil :: RBXScriptConnection?
	self._baitReady = false

	-- Bottom row (bottom centre): the My Cafe teleport, Alley and Areas (the Cannon once it is live), where Grow a Garden
	-- puts its teleport buttons (features.md F19), as clean tiles since 2026-11-03: My Cafe orange, Cannon red, Areas
	-- sky. Equip Best left the row on 2026-11-02 (fewer buttons); it stays in the Cats window. The travel tiles grey
	-- out while carrying a cat, since walking it home is the loop and the server refuses those trips, and for the trip
	-- cooldown.
	local travelRow: Frame = Create("Frame", {
		Name = "Travel",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -MARGIN),
		Size = UDim2.fromOffset(TRAVEL_ROW_W, TRAVEL_H),
		Parent = root,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, TRAVEL_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._travelRow = travelRow
	self._travelButtons = {} :: { [string]: Button.Button }
	self._travelEnabled = {} :: { [string]: boolean }
	self._travelUntil = 0
	self._carryBanner = false
	self._carryState = false
	self._homeCarrying = false
	type TravelItem = {
		key: string,
		name: string,
		label: string,
		icon: string,
		image: string?,
		style: Button.Style,
	}
	local travelItems: { TravelItem } = {
		{
			key = "home",
			name = "Cafe",
			label = HOME_TEXT,
			icon = Theme.icons.home,
			image = ShopIcons.clean("Home"),
			style = "danger",
		},
		{
			key = "alley",
			name = "Alley",
			label = "Alley",
			icon = Theme.icons.alley,
			style = "secondary",
		},
		{
			key = "areas",
			name = "Areas",
			label = "Areas",
			icon = Theme.icons.travel,
			image = ShopIcons.clean("Areas"),
			style = "sky",
		},
		-- F84: shown in place of Areas once the Cat Cannon is live (setCannonMode)
		{
			key = "cannon",
			name = "Cannon",
			label = "Cannon",
			icon = Theme.icons.cannon,
			image = ShopIcons.clean("Cannon"),
			style = "close",
		},
	}
	for index, item in travelItems do
		local home = item.key == "home"
		local button = Button.new({
			name = item.name,
			text = item.label,
			icon = item.icon,
			image = item.image,
			layout = TILE_LAYOUT,
			style = item.style,
			size = UDim2.fromOffset(TRAVEL_W, TRAVEL_H),
			textSize = TRAVEL_TEXT,
			layoutOrder = index + 1,
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
		if showKeys and home then
			keycap(button.face, "H", UDim2.fromOffset(-4, -4))
		end
		self._travelButtons[item.key] = button
		table.insert(self._buttons, button)
	end
	self._travelButtons.cannon.instance.Visible = false
	-- the arrow tab right of the row folds it below the screen edge and back; it stays where it is
	self._travelFolded = false
	local travelFold = Button.new({
		name = "TravelFold",
		text = "▼",
		style = "ghost",
		size = UDim2.fromOffset(FOLD_W, FOLD_H),
		anchorPoint = Vector2.new(0, 1),
		position = UDim2.new(0.5, TRAVEL_ROW_W / 2 + TRAVEL_GAP, 1, -MARGIN),
		textSize = Theme.sizes.textBody,
		parent = root,
		onClick = function()
			self:setTravelFolded(not self._travelFolded)
		end,
	})
	table.insert(self._buttons, travelFold)
	self._travelFold = travelFold

	-- Carry banner (bottom centre, above the bottom row): the cat you carry and a red Drop button (G)
	local carry = hudPanel("Carry", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -(MARGIN + TRAVEL_H + Theme.sizes.gap)),
		Size = UDim2.fromOffset(CARRY_W, CARRY_H),
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
	-- the carried cat's head in the rarity circle (Derek 2026-11-03: "the symbol for what carrying is showing just a
	-- plain circle")
	self._carryPortrait = CatPortrait.new({
		parent = self._carryArt,
		size = UDim2.fromScale(1.15, 1.15),
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
		still = true,
		head = true,
	})
	self._carryTitle = label({
		Name = "Title",
		Position = UDim2.fromOffset(56, 8),
		Size = UDim2.new(1, -(68 + DROP_W), 0, 22),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 1,
		Text = "Carrying a cat",
		Parent = carry,
	})
	self._carrySub = label({
		Name = "Sub",
		Position = UDim2.fromOffset(56, 30),
		Size = UDim2.new(1, -(68 + DROP_W), 0, 18),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.hud.subtext,
		Text = CARRY_SUB,
		Parent = carry,
	})
	local drop = Button.new({
		name = "Drop",
		text = "Drop",
		icon = Theme.icons.drop,
		iconSize = 26,
		style = "close",
		size = UDim2.fromOffset(DROP_W, 44), -- a 36 px face at the desktop's 0.9 scale (the UI gate's tap check)
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, -8, 0.5, 0),
		textSize = Theme.sizes.textBody,
		parent = carry,
		onClick = function()
			callbacks.dropCat()
		end,
	})
	if showKeys then
		keycap(drop.face, "G", UDim2.new(1, -4, 0, 4), Vector2.new(1, 0))
	end
	table.insert(self._buttons, drop)

	-- Tutorial strip (bottom centre, above the carry banner when both show). It grows to 520 px wide, then wraps
	-- onto a second line (reviewer N94: the step hints run to about 100 characters), growing upwards from the
	-- bottom anchor so the carry banner stacking is unchanged.
	self._tutorial = label({
		Name = "Tutorial",
		BackgroundColor3 = Theme.colors.gold,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -MARGIN),
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 1,
		TextColor3 = Theme.colors.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		Visible = false,
		Parent = root,
	})
	Outline.text(self._tutorial) -- label() skips the outline on wrapped text
	Create("UICorner", { CornerRadius = UDim.new(0, 20), Parent = self._tutorial })
	Create("UIPadding", {
		PaddingLeft = UDim.new(0, 18),
		PaddingRight = UDim.new(0, 18),
		PaddingTop = UDim.new(0, 9),
		PaddingBottom = UDim.new(0, 9),
		Parent = self._tutorial,
	})
	-- one line is 40 px tall; two lines stop at 64, and a longer hint truncates there
	Create(
		"UISizeConstraint",
		{ MinSize = Vector2.new(0, 40), MaxSize = Vector2.new(520, 64), Parent = self._tutorial }
	)

	self:_layoutBottom()
	self:_buildBoosts(root)
	pop.Parent = root -- the Rewards and Menu list goes in last, so it draws over the clock and the goal card
	-- F88: the Luck chip leads the potion timers' row; its card opens over the counters as the boosts card does (built
	-- after the menu, so it draws over it)
	self._luck = LuckChip.new(
		self._buffs.frame,
		root,
		UDim2.new(0, MARGIN, 1, -(MARGIN + self._counterH + BUFFS_GAP)),
		function(shown: boolean)
			self._buffs:setLead(shown)
		end,
		function()
			self:_hideBoosts()
		end
	)
	-- F92: the pal chip closes the potion timers' row; a tap opens the boosts card with the pals' row
	self._palIds = {} :: { number }
	self._pals = PalChip.new(self._buffs.frame, function(shown: boolean)
		self._buffs:setLead(shown, "pals")
	end, function()
		self:_toggleBoosts()
	end)
	self._palMarker = PalMarker.new()
	self:_layoutMenu()
	-- the left side follows the screen's size (a phone turned, a window resized)
	table.insert(
		self._connections,
		root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:_layoutMenu()
		end)
	)

	if parent then
		screenGui.Parent = parent
	end
	return self :: HUD
end

-- What is in the bowl: nil when empty. catWaiting is true while the Tame or Let go card has a cat to show.
function HUD.setBait(self: any, bait: Types.BaitView?, catWaiting: boolean)
	self._bait = bait
	self._catWaiting = catWaiting
	self:_renderBowl()
	local loop: RBXScriptConnection? = self._baitLoop
	if bait == nil or self._baitReady then
		if loop then
			loop:Disconnect()
			self._baitLoop = nil
		end
		return
	end
	if loop then
		return
	end
	local accumulator = 0
	self._baitLoop = RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < 1 then
			return
		end
		accumulator = 0
		self:_renderBowl()
		if self._baitReady or self._bait == nil then
			local running: RBXScriptConnection? = self._baitLoop
			if running then
				running:Disconnect()
			end
			self._baitLoop = nil
		end
	end)
end

-- The bowl symbol's line under its picture: "Add food" when empty, the time to the cat ("7:42"), then "Cat!" on a
-- gold tile. F60: food set at night counts down behind a moon ("🌙 3:42"), and an empty bowl at night reads
-- "🌙 Half", since food set then comes in half the time. The Bait bowl window has the food's name and the rest.
function HUD._renderBowl(self: any)
	local bait: Types.BaitView? = self._bait
	local wasReady = self._baitReady
	local ready = false
	local text = if self._night then Theme.icons.moon .. " Half" else "Add food"
	if bait then
		local left = bait.readyAt - Workspace:GetServerTimeNow()
		ready = left <= 0
		text = if ready
			then "Cat!"
			else (if bait.night then Theme.icons.moon .. " " else "") .. TipJarLogic.clock(
				left
			)
	end
	self._baitReady = ready
	local bowl: Button.Button = self._bowl
	if text ~= self._bowlText then
		self._bowlText = text
		bowl:setText(text)
	end
	local style: Button.Style = if ready then "gold" else "secondary"
	if style ~= self._bowlStyle then
		self._bowlStyle = style
		bowl:setStyle(style)
	end
	if ready and not wasReady and self._bowlSlot.Visible then
		Tween.popIn(self._bowlSlot, 0.9)
	end
end

-- Fires the travel callback unless the row is greyed (carrying, or inside the trip cooldown). True when it fired.
function HUD.pressTravel(self: any, destination: string): boolean
	if self:isCarrying() or os.clock() < self._travelUntil then
		return false
	end
	-- the Cannon button works at night too: the picker shows the sunrise countdown (F84)
	if destination ~= "home" and destination ~= "cannon" and not self._areasOpen then
		self:travelResult(destination, false) -- shut for the night (F66): wobble, as the server would refuse it
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

-- F84 (hometown-cannon.md section 5): with the Cat Cannon live, Cannon takes the Areas button's place and moves the
-- player at once to the front of the nearest cannon, and the Alley button goes, since every catching area is a
-- cannon area now. The carry banner points at the camp and Home reads "Camp first" while carrying.
function HUD.setCannonMode(self: any, on: boolean)
	if self._cannonMode == on then
		return
	end
	self._cannonMode = on
	self._travelButtons.cannon.instance.Visible = on
	self._travelButtons.areas.instance.Visible = not on and self:_open("areas")
	self._travelButtons.alley.instance.Visible = not on
	self:_sizeTravelRow()
	self:_layoutMenu() -- the row and its arrow tab, kept clear of the counters
	self._carrySub.Text = if on then CannonLogic.CARRY_SUB else CARRY_SUB
	self._homeCarrying = nil -- the next render writes Home's text for the new mode
	self:_renderTravel()
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

-- The server refuses a trip mid catch (N47) and the circles need the screen, so the bottom row steps aside
-- until the catch ends.
function HUD.setCatching(self: any, active: boolean)
	local changed = self._catching ~= active
	self._catching = active
	self._travelRow.Visible = not active
	self._travelFold.instance.Visible = not active
	self:_layoutBottom()
	self:_renderTutorialTile()
	if changed then
		self.catchingChanged:Fire(active)
	end
end

function HUD.isCatching(self: any): boolean
	return self._catching == true
end

-- The arrow tabs (Derek 2026-10-27): fold the left pills off the edge, or the bottom row below it, and back.
function HUD.setMenuFolded(self: any, folded: boolean)
	self._menuFolded = folded
	self._menuFold:setText(if folded then "▶" else "◀")
	Tween.to(self._menu, Tween.POP, {
		Position = UDim2.new(
			0,
			if folded then menuFoldedX(self._menu.Size.X.Offset) else MARGIN,
			0,
			self._gridTop
		),
	})
	if not TOUCH then
		Tween.to(self._storeTile.instance, Tween.POP, {
			Position = UDim2.new(
				0,
				if folded then menuFoldedX(MENU_W) else MARGIN,
				0,
				self._menuTop
			),
		})
	end
	self:_placeMenuFold()
	self:_renderFoldDot()
end

function HUD.setTravelFolded(self: any, folded: boolean)
	self._travelFolded = folded
	self._travelFold:setText(if folded then "▲" else "▼")
	Tween.to(self._travelRow, Tween.POP, {
		Position = UDim2.new(0.5, self._travelShift, 1, if folded then TRAVEL_H + 24 else -MARGIN),
	})
	self:_layoutBottom()
	self:_placePotionTimers()
end

-- The menu tab's red dot: lit while the pills are folded and one of them has a dot.
function HUD._renderFoldDot(self: any)
	local any = false
	if self._menuFolded then
		for _, dot in self._dots do
			if dot.Visible then
				any = true
				break
			end
		end
		any = any or self._questDot.Visible
	end
	if any and not self._menuFoldDot.Visible then
		Tween.popIn(self._menuFoldDot, 0.5)
	end
	self._menuFoldDot.Visible = any
end

function HUD._renderTravel(self: any)
	local carrying = self:isCarrying()
	local cooling = os.clock() < self._travelUntil
	for key, button in self._travelButtons do
		-- render runs on every state push, so only touch buttons whose state changed (keeps hover colour)
		local enabled = not carrying
			and (key == "areas" or not cooling)
			and (key ~= "alley" or self._areasOpen)
		if self._travelEnabled[key] ~= enabled then
			self._travelEnabled[key] = enabled
			button:setEnabled(enabled)
		end
	end
	local closed = not self._areasOpen
	if self._alleyClosed ~= closed then
		self._alleyClosed = closed
		self._travelButtons.alley:setText(if closed then CLOSED_TEXT else "Alley")
	end
	if self._homeCarrying ~= carrying then
		self._homeCarrying = carrying
		local carryingText = if self._cannonMode then HOME_CAMP_TEXT else HOME_CARRYING_TEXT
		self._travelButtons.home:setText(if carrying then carryingText else HOME_TEXT)
	end
	self:_renderTutorialTile()
end

-- The Tutorial tile greys while carrying or during a catch or rescue; a press then plays uiError.
function HUD._renderTutorialTile(self: any)
	local enabled = not self:isCarrying() and not self._catching
	if self._tutorialEnabled ~= enabled then
		self._tutorialEnabled = enabled
		self._tutorialTile:setEnabled(enabled)
	end
end

-- Shows or hides the Tutorial tile (F72): shown once the intro is live and while the setting is on.
function HUD.setTutorialButton(self: any, shown: boolean)
	self._tutorialTile.instance.Visible = shown
end

-- Two pulses spreading out from round `target`, gold unless `color` says.
local function glow(target: GuiObject, color: Color3?)
	local ring: Frame = Create("Frame", {
		Name = "Glow",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 10,
		Parent = target,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius + 4) }) })
	local stroke: UIStroke =
		Create("UIStroke", { Color = color or Theme.colors.gold, Thickness = 5, Parent = ring })
	Tween.to(ring, GLOW, { Size = UDim2.new(1, 26, 1, 26) })
	Tween.to(stroke, GLOW, { Transparency = 1 }).Completed:Once(function()
		ring:Destroy()
	end)
	Sound.play("uiHint")
end

-- Two gold pulses round the Tutorial tile, so a new player sees where the intro replays (F72; F87 section 2a: on
-- the first join, since the intro no longer plays by itself).
function HUD.glowTutorial(self: any)
	local tile: Frame = self._tutorialTile.instance
	if tile.Visible then
		glow(tile)
	end
end

-- F87 section 2g: the tutorial strip pops and pulses when its step has not moved for StuckNudgeSeconds.
function HUD.pulseTutorial(self: any)
	local strip: GuiObject = self._tutorial
	if strip.Visible then
		Tween.popIn(strip, 0.85)
		glow(strip, Theme.colors.white) -- the strip itself is gold
	end
end

function HUD.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	self:_renderBowl()
	self._buffs:setCatalog(catalog)
	self._luck:setCatalog(catalog)
end

function HUD.render(self: any, state: Types.PlayerState)
	local catalog: Types.Catalog? = self._catalog
	-- F102: the Trade tile from the live minimum tier, with the rest of the full HUD, once TradeService runs (it sets
	-- the Workspace's TradingOn; while that is false the window says trading is resting)
	self._tradeTile.instance.Visible = self:_open("invite")
		and Workspace:GetAttribute("TradingOn") ~= nil
		and TradeLogic.shown(state.tier, TradeLogic.minTier(Workspace:GetAttribute("TradeMinTier")))

	-- money with a little green flash for a lump (a sale, a tip, a reward), not for the steady income ticks (#1026)
	self._moneyText.Text = Format.money(state.money)
	if MoneyFlash.shouldFlash(self._lastMoney, state.money, state.incomePerSecond) then
		self._moneyText.TextColor3 = Theme.hud.income
		Tween.to(self._moneyText, Tween.RISE, { TextColor3 = Theme.hud.text })
	end
	self._lastMoney = state.money
	-- golden fish, with a white flash when they go up
	-- the small HUD's pieces first, so everything below reads this state's unlocks (F87)
	self:_renderUnlocks(state)
	local fish = state.goldenFish
	self._fishPanel.Visible = fish ~= nil and self:_open("fish")
	if fish then
		self._fishText.Text = Format.short(fish)
		if self._lastFish and fish > self._lastFish then
			self._fishText.TextColor3 = Theme.colors.white
			Tween.to(self._fishText, Tween.RISE, { TextColor3 = Theme.fish.text })
		end
	end
	self._lastFish = fish
	-- the potion timers over the counters, and the bag's count on its pill (F64)
	self._buffs:render(state)
	self._luck:render(state) -- F88: the Luck chip at the row's start, and its card when open
	if self._boosts.Visible then
		self:_renderBoosts()
	end
	local potions = 0
	local bag: { [string]: number } = state.potions or {}
	for _, count in bag do
		potions += math.max(0, count)
	end
	self._potionCount.Text = tostring(potions)
	self._potionCount.Visible = potions > 0
	self._state = state
	self._carryState = state.carrying ~= nil
	self:_renderTravel()

	-- the tier and next goal block: "Tier 1 · Corner Cafe", then the next tier's requirements, or the tier alone
	local tierProgress: RankUp.Progress? = nil
	if catalog and catalog.tiers and state.tier then
		tierProgress = RankUp.progress(catalog, state)
	end
	self._goal:render(tierProgress, Format.tier(state.tier, if catalog then catalog.tiers else nil))
	if not self:_open("goal") then
		self._goal.frame.Visible = false
	end
	-- uiRankReady chimes once per tier, the first time that tier's requirements are all met
	if tierProgress and tierProgress.ready and self._chimedTier ~= tierProgress.tier then
		self._chimedTier = tierProgress.tier
		Sound.play("uiRankReady")
	end
	self:_renderQuests(state, catalog)
	self:_renderFreeSpin()
	self:_layoutRight()
	if catalog then
		self:_renderDots(catalog, state)
	end
	self:_renderBowlSlot(state)
end

-- F87 (easy-start.md section 2f): whether a piece of the small HUD shows yet; everything before the first state.
function HUD._open(self: any, key: HudUnlocks.Key): boolean
	local unlocks: { [HudUnlocks.Key]: boolean }? = self._unlocks
	return unlocks == nil or unlocks[key] == true
end

-- The pieces this state unlocks (Components/HudUnlocks). Nothing changes while the unlocks stay the same; each piece
-- that opens after the first state pops in with a gold "New!".
function HUD._renderUnlocks(self: any, state: Types.PlayerState)
	if state.tutorialStep == nil then
		-- no step (the demo, the UI gate's sample player): everything shows, and nothing sticks for a later state
		if self._unlocks ~= nil then
			self._unlocks = nil
			self:_applyUnlocks()
		end
		return
	end
	local before: { [HudUnlocks.Key]: boolean }? = self._unlocks
	local now, opened = HudUnlocks.update(before, HudUnlocks.view(state :: any))
	if before ~= nil and #opened == 0 then
		return -- update keeps what showed, so no new key means no change
	end
	self._unlocks = now
	self:_applyUnlocks()
	for _, key in opened do
		self:_popNew(key)
	end
	if #opened > 0 then
		Sound.play("uiHint")
	end
end

-- Shows or hides every gated piece for the current unlocks, then lays the menu, the bottom row and the right column
-- out again. The fish counter and the goal card follow in render.
function HUD._applyUnlocks(self: any)
	for name, key in PILL_KEYS do
		self._pills[name].instance.Visible = self:_open(key)
	end
	self._questsPill.instance.Visible = self._questsLive == true and self:_open("quests")
	self:_renderRewards()
	self._feedbackTile.instance.Visible = self:_open("feedback")
	self._potionsTile.instance.Visible = self:_open("potions")
	self:_closePop() -- a list made under the old unlocks may hold a row that is gone
	self._travelButtons.areas.instance.Visible = not self._cannonMode and self:_open("areas")
	self:_sizeTravelRow()
	self:setClock(self._clockState) -- the clock and the night tips line
	self:_layoutMenu()
	self:_layoutBottom()
end

-- The bottom row as wide as the buttons it shows (Equip Best and Areas wait for their unlocks; the Cannon takes the
-- Alley's and Areas' place, F84).
function HUD._sizeTravelRow(self: any)
	local count = 0
	for _, child in self._travelRow:GetChildren() do
		if child:IsA("GuiObject") and child.Visible then
			count += 1
		end
	end
	local width = count * TRAVEL_W + math.max(0, count - 1) * TRAVEL_GAP
	self._travelRow.Size = UDim2.fromOffset(width, TRAVEL_H)
end

-- The piece a small HUD key shows, for its pop, and whether it is a button.
function HUD._unlockTarget(self: any, key: HudUnlocks.Key): (GuiObject?, boolean)
	local pill: Button.Button? = nil
	for name, pillKey in PILL_KEYS do
		if pillKey == key then
			pill = self._pills[name]
		end
	end
	local button: Button.Button? = pill
		or (
			if key == "quests"
				then self._questsPill
				elseif key == "gifts" or key == "daily" then self._rewards
				elseif key == "feedback" then self._feedbackTile
				elseif key == "invite" then self._menuTile
				elseif key == "potions" then self._potionsTile
				elseif key == "areas" then self._travelButtons.areas
				else nil
		)
	if button ~= nil then
		return button.instance, true
	end
	local piece: GuiObject? = if key == "clock"
		then self._clock
		elseif key == "goal" then self._goal.frame
		elseif key == "fish" then self._fishPanel
		else nil
	return piece, false
end

-- A newly unlocked piece pops in; a button also wears a gold "New!" on its top right corner for NEW_SECONDS.
function HUD._popNew(self: any, key: HudUnlocks.Key)
	local target, isButton = self:_unlockTarget(key)
	if target == nil or not target.Visible then
		return
	end
	if not isButton then
		Tween.popIn(target, 0.85) -- the clock, the goal card and the fish counter have no button to mark
		return
	end
	local old = target:FindFirstChild("New")
	if old then
		old:Destroy()
	end
	local badge: TextLabel = Create("TextLabel", {
		Name = "New",
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 6, 0, 2),
		Size = UDim2.fromOffset(52, 24),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.colors.white,
		Text = "New!",
		ZIndex = 12,
		Parent = target,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(badge, 2)
	Outline.text(badge, 2)
	Tween.popIn(target, 0.85)
	Tween.popIn(badge, 0.5)
	task.delay(NEW_SECONDS, function()
		if badge.Parent ~= nil then
			badge:Destroy()
		end
	end)
end

-- The bowl chip shows once the Bait bowl upgrade is owned.
function HUD._renderBowlSlot(self: any, state: Types.PlayerState)
	local shown = (state.upgradeLevels.lure_bowl or 0) >= 1
	if self._bowlSlot.Visible ~= shown then
		self._bowlSlot.Visible = shown
		self:_placeCorner()
	end
	self:_renderBowl()
end

function HUD.setCarrying(self: any, info: Types.CarryInfo?)
	self._carryBanner = info ~= nil
	self._carryState = info ~= nil -- render agrees on the next state push, since UI.setCarrying clears state too
	self:_renderTravel()
	if info then
		assert(info, "carry info missing")
		local rarity: string = info.rarity or "Common"
		self._carry.Visible = true
		self._carryArt.BackgroundColor3 = Theme.rarityColor(rarity)
		local catalog: Types.Catalog? = self._catalog
		local def: Types.CatDef? = nil
		if catalog and info.catId then
			for _, cat in catalog.cats do
				if cat.id == info.catId then
					def = cat
					break
				end
			end
		end
		self._carryPortrait:set(def)
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
		-- only a new line chimes and pops; the same line again (a sync, a zone change) stays still
		if not self._tutorial.Visible or self._tutorial.Text ~= text then
			Sound.play("uiHint")
			Tween.popIn(self._tutorial, 0.92)
		end
		self._tutorial.Text = text
		self._tutorial.Visible = true
	else
		self._tutorial.Visible = false
	end
	self:_layoutBottom()
end

-- Bottom up: the bottom row, the carry banner, then the tutorial strip, each above the ones showing below it.
function HUD._layoutBottom(self: any)
	local y = -MARGIN
	if self._travelRow.Visible and not self._travelFolded then
		y -= TRAVEL_H + Theme.sizes.gap
	end
	if self._carry.Visible then
		self._carry.Position = UDim2.new(0.5, 0, 1, y)
		y -= CARRY_H + Theme.sizes.gap
	end
	self._tutorial.Position = UDim2.new(0.5, 0, 1, y)
end

-- Just above whatever the bottom centre stacks (the bottom row, the carry banner, the tutorial strip), in design
-- pixels from the screen's bottom edge, for the Tackle bar (Screens/TackleBar) to sit on.
function HUD.bottomTop(self: any): number
	local y = -MARGIN
	if self._travelRow.Visible and not self._travelFolded then
		y -= TRAVEL_H + Theme.sizes.gap
	end
	if self._carry.Visible then
		y -= CARRY_H + Theme.sizes.gap
	end
	if self._tutorial.Visible then
		y -= self._tutorial.AbsoluteSize.Y / Scale.get() + Theme.sizes.gap
	end
	return y
end

-- Day and night clock. nil hides it. The countdown runs on Workspace:GetServerTimeNow(), the server's
-- synchronised epoch clock, so it compares with the server's os.time() in PhaseEndsAt and never trusts
-- the device clock (data-model section 1, reviewer S16). In the last DUSK_SECONDS of a day it reads "Night in 0:12"
-- in orange (F66). F60: when night falls on an empty bowl, the bowl chip pops so the half wait is seen.
function HUD.setClock(self: any, clock: Types.ClockState?)
	self:_stopClock()
	self._clockState = clock
	if not clock then
		self._clock.Visible = false
		self._nightTips.Visible = false
		self._luckyLine.Visible = false
		self._rallyLine.Visible = false
		self._night = false
		self._clockSeen = false
		self:_renderBowl()
		self:_layoutRight()
		return
	end
	local current: Types.ClockState = clock
	local isNight = current.phase == "night"
	local nightfall = isNight and not self._night and self._clockSeen == true -- not the first clock
	self._night = isNight
	self._clockSeen = true
	self:_renderBowl()
	if nightfall and self._bait == nil and self._bowlSlot.Visible then
		Tween.popIn(self._bowlSlot, 0.9)
	end
	self._sun.Visible = not isNight
	self._moon.Visible = isNight
	local shown = self:_open("clock") -- the small HUD keeps it hidden until step 5 (F87)
	self._clock.Visible = shown
	self._nightTips.Visible = shown and isNight and NIGHT_TIPS < 1
	self:_renderLuckyLine()
	self._rallyLine.Visible = self._rallySoon ~= nil and shown
	self:_layoutRight()
	local function tick()
		local remaining = current.phaseEndsAt - Workspace:GetServerTimeNow()
		self._clockText.Text = NightClock.chipText(current.phase, remaining, DUSK_SECONDS)
		self._clockText.TextColor3 = if isNight
			then Theme.colors.sky
			elseif NightClock.isDusk(current.phase, remaining, DUSK_SECONDS) then Theme.colors.warn
			else Theme.hud.text
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

-- F88 (luck-and-rare-moments.md 1c): the Clock folder's Day, NextLuckyDay and LuckyDay, for the line under the
-- clock. nil hides it.
function HUD.setLuckyDay(self: any, view: LuckLogic.DayView?)
	self._luckyDay = view
	self:_renderLuckyLine()
	self:_layoutRight()
end

-- "🍀 Lucky Day in 2 days" under the clock while the clock shows; the phase is the clock's own.
function HUD._renderLuckyLine(self: any)
	local view: LuckLogic.DayView? = self._luckyDay
	local clock: Types.ClockState? = self._clockState
	local line: string? = nil
	if view ~= nil and clock ~= nil then
		line = LuckLogic.dayLine({
			day = view.day,
			nextLuckyDay = view.nextLuckyDay,
			luckyDay = view.luckyDay,
			phase = clock.phase,
		})
	end
	self._luckyLine.Text = if line then LuckLogic.ICON .. " " .. line else ""
	self._luckyLine.Visible = line ~= nil and self._clock.Visible
end

-- F101: the Rescue Rally countdown under the clock (RallyLogic.soon), shown with the clock; nil hides it.
function HUD.setRallySoon(self: any, line: string?)
	if line == self._rallySoon then
		return
	end
	self._rallySoon = line
	self._rallyLine.Text = if line ~= nil then "🏁 " .. line else ""
	self._rallyLine.Visible = line ~= nil and self._clock.Visible
	self:_layoutRight()
end

-- F101: the potion timers' row. On a phone it sits level with the menu's top, where a long row (Luck, potions,
-- pals) can reach the top centre; the Rally banner moves down under it then.
function HUD.buffRow(self: any): GuiObject
	return self._buffs.frame
end

-- F88: the Luck chip shows (its first source came), for the `luck` context tip.
function HUD.luckShown(self: any): boolean
	return self._luck:isShown()
end

-- F66: the catching areas close from dusk to sunrise. The Alley button greys and reads "🌙 Closed", and a key bind
-- or Go to an area wobbles instead of asking the server.
function HUD.setAreasOpen(self: any, open: boolean)
	if self._areasOpen == open then
		return
	end
	self._areasOpen = open
	self:_renderTravel()
end

-- How far the top right column can move up into Roblox's top bar: its height in design px when the bar's free
-- stretch covers the column, else 0 (the bar holds Roblox buttons there, or the device has no top bar).
local function topbarLift(): number
	local inset = GuiService.TopbarInset
	local camera = Workspace.CurrentCamera
	local scale = Scale.get()
	if camera == nil or scale <= 0 or inset.Height <= 0 then
		return 0
	end
	local width = camera.ViewportSize.X
	local columnLeft = width - (MARGIN + RIGHT_COLUMN_W) * scale
	if inset.Max.X < width - TOPBAR_SLACK or inset.Min.X > columnLeft then
		return 0
	end
	return inset.Max.Y / scale
end

-- The top right column, top down: the icon row, the clock, the night tips line when it shows, the tier and goal.
function HUD._layoutRight(self: any)
	local lift = self._lift
	self._icons.Position = UDim2.new(1, -MARGIN, 0, MARGIN - lift)
	self._pop.Position = UDim2.new(1, -MARGIN, 0, MARGIN + ICON_H + 6 - lift)
	self._clock.Position = UDim2.new(1, -MARGIN, 0, CLOCK_TOP - lift)
	self._nightTips.Position = UDim2.new(1, -MARGIN, 0, CLOCK_TOP + CLOCK_H - lift)
	local top = if self._clock.Visible then GOAL_TOP else CLOCK_TOP
	if self._nightTips.Visible then
		top += NIGHT_LINE
	end
	-- F88: the Lucky Day line under the clock (and under the night tips line when that shows)
	self._luckyLine.Position = UDim2.new(1, -MARGIN, 0, top - 6 - lift)
	if self._luckyLine.Visible then
		top += NIGHT_LINE
	end
	-- F101: the Rescue Rally countdown under those
	self._rallyLine.Position = UDim2.new(1, -MARGIN, 0, top - 6 - lift)
	if self._rallyLine.Visible then
		top += NIGHT_LINE
	end
	self._goal.frame.Position = UDim2.new(1, -MARGIN, 0, top - lift)
	local goal = self._goal.frame
	local lineTop = if goal.Visible then top + goal.Size.Y.Offset + Theme.sizes.gap else top
	self._questLine.Position = UDim2.new(1, -MARGIN, 0, lineTop - lift)
	local spinTop = if self._questLine.Visible then lineTop + QUEST_LINE_H + 2 else lineTop
	self._spinLine.Position = UDim2.new(1, -MARGIN, 0, spinTop - lift)
end

-- F73: the Quests pill (shown once ProfileSync has quests) with its count of what is ready to claim, and the quest
-- line under the goal card once the tutorial is done.
function HUD._renderQuests(self: any, state: Types.PlayerState, catalog: Types.Catalog?)
	local pill = self._questsPill
	local live = state.quests ~= nil
	self._questsLive = live
	local shown = live and self:_open("quests")
	if pill.instance.Visible ~= shown then
		pill.instance.Visible = shown
		self:_layoutMenu()
	end
	local ready = if live then QuestLogic.claimable(state, catalog) else 0
	if ready > 0 and not self._questDot.Visible then
		Tween.popIn(self._questDot, 0.5)
	end
	self._questDot.Visible = ready > 0
	self._questCount.Text = tostring(ready)
	self:_renderFoldDot()

	local line: string? = nil
	if live and (state.tutorialStep or TUTORIAL_DONE) >= TUTORIAL_DONE then
		local quest = QuestLogic.tracker(state.quests)
		if ready > 0 then
			line = ("%s %d ready to claim"):format(Theme.icons.quests, ready)
		elseif quest then
			local needs = math.max(1, quest.needs)
			local progress = math.clamp(quest.progress, 0, needs)
			local count = if QuestLogic.isCoins(catalog, quest.id)
				then Format.money(progress) .. "/" .. Format.money(needs)
				else ("%d/%d"):format(math.floor(progress), math.floor(needs))
			line = ("%s %s  %s"):format(Theme.icons.quests, quest.text, count)
		end
	end
	self._questLine.Visible = line ~= nil
	self._questText.Text = line or ""
	self._questText.TextColor3 = if ready > 0 then Theme.colors.gold else Theme.hud.text
end

-- F49: the free spin line shows while today's free spin waits (SpinLogic.freeDue), once ProfileSync has the spin
-- state and the tutorial is done. Spinning sends a new state, which hides it; a timer shows it again at 00:00 UTC.
function HUD._renderFreeSpin(self: any)
	local timer: thread? = self._spinTimer
	if timer then
		task.cancel(timer)
		self._spinTimer = nil
	end
	local state: Types.PlayerState? = self._state
	local spin = if state then state.spin else nil
	if state == nil or spin == nil or (state.tutorialStep or TUTORIAL_DONE) < TUTORIAL_DONE then
		self._spinLine.Visible = false
		return
	end
	local now = Workspace:GetServerTimeNow()
	local due = SpinLogic.freeDue(spin, now)
	if due and not self._spinLine.Visible then
		Tween.popIn(self._spinLine, 0.8)
	end
	self._spinLine.Visible = due
	if not due then
		self._spinTimer = task.delay(SpinLogic.nextFreeIn(spin, now) + 1, function()
			self._spinTimer = nil
			self:_renderFreeSpin()
			self:_layoutRight()
		end)
	end
end

function HUD._liftRight(self: any)
	local lift = topbarLift()
	if lift ~= self._lift then
		self._lift = lift
		self:_layoutRight()
	end
end

-- Red dots: a screen's dot shows while it has a key the player has not seen on that screen. Keys seen while
-- the screen is open count as seen, so buying the next level in the shop does not light the dot again.
function HUD._renderDots(self: any, catalog: Types.Catalog, state: Types.PlayerState)
	local candidates = Notices.candidates(catalog, state)
	self._candidates = candidates
	local open: string? = self._openScreen
	if open and (candidates :: any)[open] then
		Notices.markSeen((candidates :: any)[open], self._seen[open])
	end
	-- the Index's dot shows only while an Index reward waits to be claimed (F48), even after the Index is opened
	local _, indexReady = IndexRewards.claimable(catalog, state)
	self._indexReady = indexReady
	local lit = false
	for screen, dot in self._dots do
		local keys: { string } = (candidates :: any)[screen] or {}
		local show = if screen == "Collection"
			then indexReady > 0
			else Notices.hasNew(keys, self._seen[screen] or {})
		if show and not dot.Visible then
			Tween.popIn(dot, 0.5)
			lit = true
		end
		dot.Visible = show
	end
	-- one uiBadge however many dots light, and none for the dots the first state already lights
	if lit and self._dotsRendered then
		Sound.play("uiBadge")
	end
	self._dotsRendered = true
	self:_renderFoldDot()
end

-- The Tip Jar's playtime gifts (F47) on the Rewards tile: nil hides them. uiGiftReady plays when another gift
-- becomes ready, never for the gifts the first TipJarState already has.
function HUD.setTipJar(self: any, summary: { ready: number, nextIn: number?, left: number }?)
	self._giftsWanted = summary ~= nil
	self._gift = summary
	if summary ~= nil then
		local before: number? = self._giftReady
		self._giftReady = summary.ready
		if before ~= nil and summary.ready > before then
			Sound.play("uiGiftReady")
		end
	end
	self:_renderRewards()
end

-- The Daily Treat card (F70) on the Rewards tile: shown once ProfileSync has it, due while a stamp waits.
function HUD.setDailyTreat(self: any, shown: boolean, due: boolean)
	self._dailyWanted = shown
	self._dailyDue = shown and due
	self:_renderRewards()
end

-- What the Rewards tile holds now: the gifts and the Daily Treat, each once it is live and unlocked (F87).
function HUD._rewardParts(self: any): (boolean, boolean)
	return self._giftsWanted == true and self:_open("gifts"),
		self._dailyWanted == true and self:_open("daily")
end

-- The Rewards tile: shown while it holds anything; "Claim!" and a red count of what waits (gifts ready, plus one for
-- a due stamp), else the time to the next gift, "Daily" with only the card, or "Rewards".
function HUD._renderRewards(self: any)
	local tile: Button.Button = self._rewards
	local gifts, daily = self:_rewardParts()
	tile.instance.Visible = gifts or daily
	local summary: { ready: number, nextIn: number?, left: number }? = if gifts
		then self._gift
		else nil
	local ready = (if summary then summary.ready else 0)
		+ (if daily and self._dailyDue then 1 else 0)
	local nextIn: number? = if summary then summary.nextIn else nil
	local text = if ready > 0
		then "Claim!"
		elseif nextIn ~= nil then TipJarLogic.clock(nextIn)
		elseif daily and not gifts then "Daily"
		else "Rewards"
	if text ~= self._rewardsText then
		self._rewardsText = text
		tile:setText(text)
	end
	if ready > 0 and not self._rewardsDot.Visible then
		Tween.popIn(self._rewardsDot, 0.5)
	end
	self._rewardsDot.Visible = ready > 0
	self._rewardsCount.Text = tostring(ready)
	if self._popFor == "rewards" then
		self:_fillPop() -- the open list's lines follow the countdown and the claims
	end
end

-- The Rewards tile's press: the list when both parts are live, else the one window it holds.
function HUD._pressRewards(self: any)
	local gifts, daily = self:_rewardParts()
	if gifts and daily then
		self:_togglePop("rewards")
	elseif gifts then
		self._callbacks.openScreen("TipJar")
	elseif daily then
		self._callbacks.openScreen("DailyTreat")
	end
end

-- The Menu tile's press: the list (Settings, Invite) once Invite is unlocked, else Settings at once.
function HUD._pressMenu(self: any)
	if self:_open("invite") then
		self:_togglePop("menu")
	else
		self._callbacks.openScreen("Settings")
	end
end

-- The rows a list holds now, in order: id, icon, style and what pressing it does.
type PopRow = { id: string, icon: string, style: Button.Style, press: () -> () }
function HUD._popRowsFor(self: any, kind: string): { PopRow }
	local rows: { PopRow } = {}
	local callbacks: Callbacks = self._callbacks
	if kind == "rewards" then
		local gifts, daily = self:_rewardParts()
		if gifts then
			table.insert(rows, {
				id = "Gifts",
				icon = Theme.icons.gifts,
				style = "berry" :: Button.Style,
				press = function()
					callbacks.openScreen("TipJar")
				end,
			})
		end
		if daily then
			table.insert(rows, {
				id = "Daily",
				icon = Theme.icons.daily,
				style = "primary" :: Button.Style,
				press = function()
					callbacks.openScreen("DailyTreat")
				end,
			})
		end
	else
		table.insert(rows, {
			id = "Settings",
			icon = Theme.icons.settings,
			style = "ghost" :: Button.Style,
			press = function()
				callbacks.openScreen("Settings")
			end,
		})
		if self:_open("invite") then
			table.insert(rows, {
				id = "Invite",
				icon = Theme.icons.invite,
				style = "secondary" :: Button.Style,
				press = function()
					Invite.prompt() -- F92: with this player's name in the launch data
				end,
			})
		end
	end
	return rows
end

-- A row's words: what it opens and, for the rewards, what waits there ("Gifts: 2 ready", "Next gift 3:20",
-- "Daily treat: Claim!").
function HUD._popText(self: any, id: string): string
	if id == "Gifts" then
		local summary: { ready: number, nextIn: number?, left: number }? = self._gift
		local nextIn: number? = if summary then summary.nextIn else nil
		return if summary and summary.ready > 0
			then ("Gifts: %d ready"):format(summary.ready)
			elseif nextIn ~= nil then "Next gift " .. TipJarLogic.clock(nextIn)
			else "Gifts"
	elseif id == "Daily" then
		return if self._dailyDue then "Daily treat: Claim!" else "Daily treat"
	elseif id == "Invite" then
		return "Invite friends"
	end
	return id
end

-- Opens the kind's list, or closes it when it is already open; another kind's list gives way.
function HUD._togglePop(self: any, kind: string)
	if self._popFor == kind then
		self:_closePop()
		return
	end
	self:_closePop()
	self:_hideBoosts()
	self._luck:hide()
	local rows = self:_popRowsFor(kind)
	local pop: Frame = self._pop
	local width = POP_W - 2 * POP_PAD
	for order, row in rows do
		local button = Button.new({
			name = row.id,
			text = self:_popText(row.id),
			icon = row.icon,
			iconSize = TRAVEL_ICON,
			style = row.style,
			size = UDim2.fromOffset(width, POP_ROW_H),
			textSize = Theme.sizes.textBody,
			layoutOrder = order,
			zIndex = 21,
			parent = pop,
			sound = false, -- the window's swish (or Roblox's invite window) follows
			onClick = function()
				self:_closePop()
				row.press()
			end,
		})
		self._popRows[row.id] = button
	end
	pop.Size = UDim2.fromOffset(POP_W, #rows * POP_ROW_H + math.max(0, #rows - 1) * 6 + 2 * POP_PAD)
	self._popFor = kind
	pop.Visible = true
	Tween.popIn(pop, 0.9)
	Sound.play("uiClick")
end

-- The open list's rows say what they say now (the gift countdown ticks while it is open).
function HUD._fillPop(self: any)
	for id, button in self._popRows do
		button:setText(self:_popText(id))
	end
end

function HUD._closePop(self: any)
	self._popFor = nil
	self._pop.Visible = false
	for _, button in self._popRows do
		button:destroy()
	end
	table.clear(self._popRows)
end

-- The gold Store tile at the top of the left menu (Derek 2026-11-02: "store still needs to be added"): shown with
-- the function that opens the Store window, hidden with nil. init's Store block calls it once Roblox says a pass is on
-- sale, or while the Workspace has StoreOpen for a preview; hidden, the grid closes up (review N341: moved here).
function HUD.setStore(self: any, open: (() -> ())?)
	self._storeOpen = open
	local tile: Button.Button = self._storeTile
	local shown = open ~= nil
	if tile.instance.Visible ~= shown then
		tile.instance.Visible = shown
		self:_layoutMenu()
	end
end

-- From the modal's changed signal: opening a screen marks what it shows as seen and clears its dot. The Index has
-- no keys (its dot is the waiting rewards, in _renderDots), so it is left alone here.
function HUD.screenOpened(self: any, name: string?)
	self._openScreen = name
	if name then
		self:_hideBoosts() -- a window over the world closes the money's card
		self._luck:hide() -- and the Luck card (F88)
		self:_closePop() -- and the Rewards or Menu list
	end
	local candidates: Notices.Candidates? = self._candidates
	if name and candidates and (candidates :: any)[name] then
		Notices.markSeen((candidates :: any)[name], self._seen[name])
		local dot: Frame? = self._dots[name]
		if dot then
			dot.Visible = false
		end
		self:_renderFoldDot()
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

-- The money's boosts card (Derek 2026-10-28: "clicking on it should show all active multipliers ... in a quick clean
-- list"): over the counters, the exact money and rate, then one row per source from Components/BoostList, the empty
-- ones grey, and "All together" at the foot. The whole card is a button that closes it.
function HUD._buildBoosts(self: any, root: Frame)
	self._boostsSaid = nil :: string? -- what the rows last said (_renderBoosts)
	local card = hudPanel("Boosts", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, MARGIN, 1, -(MARGIN + self._counterH + BUFFS_GAP)),
		Size = UDim2.fromOffset(BOOSTS_W, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		ZIndex = 6,
		Parent = root,
	})
	Create("UIPadding", {
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		Parent = card,
	})
	local list: Frame = Create("Frame", {
		Name = "List",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 6,
		Parent = card,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	label({
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 26),
		TextSize = Theme.sizes.textBody + 2,
		TextColor3 = Theme.colors.gold,
		Text = "Money boosts",
		LayoutOrder = 1,
		ZIndex = 6,
		Parent = list,
	})
	self._boostsExact = label({
		Name = "Exact",
		Size = UDim2.new(1, 0, 0, 26),
		TextSize = 22,
		LayoutOrder = 2,
		ZIndex = 6,
		Parent = list,
	})
	self._boostsRate = label({
		Name = "Rate",
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = Theme.sizes.textSmall + 1,
		TextColor3 = Theme.hud.income,
		LayoutOrder = 3,
		ZIndex = 6,
		Parent = list,
	})
	self._boostsRows = Create("Frame", {
		Name = "Rows",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 4,
		ZIndex = 6,
		Parent = list,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Create("UIPadding", { PaddingTop = UDim.new(0, 6) }),
	})
	label({
		Name = "Hint",
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = Theme.sizes.textTiny,
		TextColor3 = Theme.hud.subtext,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Tap to close",
		LayoutOrder = 5,
		ZIndex = 6,
		Parent = list,
	})
	-- the card's whole content takes the closing tap; sized by scale alone, so the card's AutomaticSize stays put
	local close: TextButton = Create("TextButton", {
		Name = "Close",
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 8,
		Parent = card,
	})
	table.insert(
		self._connections,
		close.Activated:Connect(function()
			self:_hideBoosts()
		end)
	)
	self._boosts = card
end

function HUD._toggleBoosts(self: any)
	if self._boosts.Visible then
		self:_hideBoosts()
		return
	end
	if self._state == nil then
		return
	end
	self._luck:hide()
	self:_renderBoosts()
	self._boosts.Visible = true
	Tween.popIn(self._boosts, 0.9)
	Sound.play("uiClick")
end

function HUD._hideBoosts(self: any)
	self._boosts.Visible = false
end

function HUD._renderBoosts(self: any)
	local state: Types.PlayerState? = self._state
	if state == nil then
		return
	end
	self._boostsExact.Text = Theme.currencySymbol .. Format.commas(math.floor(state.money))
	self._boostsRate.Text = Format.rate(state.incomePerSecond)
	-- the money ticks five times a second while income flows (UIController's prediction), and each tick renders the
	-- HUD; the rows are made again only when what they say changed
	local rows = BoostList.rows(self._catalog, state, Workspace:GetServerTimeNow(), #self._palIds)
	local said: { string } = {}
	for _, row in rows do
		table.insert(
			said,
			("%s=%s=%s=%s"):format(row.key, row.name, row.value, tostring(row.active))
		)
	end
	local text = table.concat(said, ";")
	if text == self._boostsSaid then
		return
	end
	self._boostsSaid = text
	local holder: Frame = self._boostsRows
	for _, child in holder:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for order, row in rows do
		local total = row.kind == "total"
		local frame: Frame = Create("Frame", {
			Name = row.key,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, if total then BOOST_ROW_H + 8 else BOOST_ROW_H),
			LayoutOrder = order,
			ZIndex = 6,
			Parent = holder,
		})
		local color = if total
			then Theme.colors.gold
			elseif row.active then Theme.hud.text
			else Theme.hud.subtext
		if total then
			-- a thin line over the sum
			Create("Frame", {
				Name = "Rule",
				BackgroundColor3 = Theme.hud.subtext,
				BackgroundTransparency = 0.6,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, 3),
				Size = UDim2.new(1, 0, 0, 1),
				ZIndex = 6,
				Parent = frame,
			})
		end
		label({
			Name = "Name",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(0.68, 0, 0, BOOST_ROW_H),
			TextSize = if total then Theme.sizes.textBody + 1 else Theme.sizes.textSmall + 1,
			TextColor3 = color,
			TextTransparency = if row.active then 0 else 0.25,
			Text = row.name,
			ZIndex = 6,
			Parent = frame,
		})
		label({
			Name = "Value",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(1, 1),
			Size = UDim2.new(0.32, 0, 0, BOOST_ROW_H),
			TextSize = if total then Theme.sizes.textBody + 2 else Theme.sizes.textBody,
			TextColor3 = if total
				then Theme.colors.gold
				elseif row.active then Theme.hud.income
				else Theme.hud.subtext,
			TextTransparency = if row.active then 0 else 0.25,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = row.value,
			ZIndex = 6,
			Parent = frame,
		})
	end
end

-- The left side, laid out for the screen's height: the counters in the bottom left corner; the potion timers over
-- them when there is room for those and the whole menu with its arrow tab under it, else (a phone) beside the
-- menu's last row with the arrow tab; the menu grid centred in what is left above; the bottom row moved right of the
-- counters when the screen is too narrow for it to sit in the middle; and the potion and bowl symbols.
function HUD._layoutMenu(self: any)
	local scale = Scale.get()
	local size = self._root.AbsoluteSize
	local width, height = Scale.DESIGN.X, Scale.DESIGN.Y - 58
	if scale > 0 and size.Y > 0 then
		width, height = size.X / scale, size.Y / scale
	end
	local gap = Theme.sizes.gap
	local shown = 0
	for _, child in self._menu:GetChildren() do
		if child:IsA("GuiObject") and child.Visible then
			shown += 1
		end
	end
	-- the Store's wide tile heads the column once it has a window to open (setStore)
	local store: GuiObject = self._storeTile.instance
	local storeH = if store.Visible and not TOUCH then STORE_H + gap else 0 -- on touch it is in the grid
	self._menuFold.instance.Visible = shown > 0 or store.Visible -- no tab to fold an empty menu (F87)
	local columns = MENU_COLUMNS
	local rows = math.ceil(shown / columns)
	local spaces = math.max(0, rows - 1)
	local pills = storeH + rows * MENU_CELL_H
	local foldUnder = gap + 4 + FOLD_H
	local bandBottom = height - MARGIN - self._counterH - gap
	local buffsH = BuffChips.rowHeight()
	local roomy = bandBottom - (buffsH + BUFFS_GAP) - MARGIN >= pills + spaces * gap + foldUnder
	-- (the zone is screen pixels; the layout is design units, so it is divided by the scale)
	if
		TOUCH
		and MARGIN + pills + spaces * gap
			> height - THUMB_ZONE / (if scale > 0 then scale else 1)
	then
		roomy = false
	end
	if not roomy and rows >= 3 then
		columns = MENU_COLUMNS_SHORT
		rows = math.ceil(shown / columns)
		spaces = math.max(0, rows - 1)
		pills = storeH + rows * MENU_CELL_H
	end
	self._menuLayout.FillDirectionMaxCells = columns
	local menuW = menuWidth(columns)
	if roomy then
		self._buffs:place(
			UDim2.new(0, MARGIN, 1, -(MARGIN + self._counterH + BUFFS_GAP)),
			Vector2.new(0, 1)
		)
		bandBottom -= buffsH + BUFFS_GAP
	end
	local band = bandBottom - MARGIN
	-- a short screen closes the gaps between the rows a little before anything overlaps
	local padding = gap
	if not roomy and spaces > 0 and pills + spaces * gap > band then
		padding = math.max(4, math.floor((band - pills) / spaces))
	end
	self._menuLayout.CellPadding = UDim2.fromOffset(MENU_GAP, padding)
	local menuH = rows * MENU_CELL_H + spaces * padding -- the grid alone, under the Store
	self._menu.Size = UDim2.fromOffset(menuW, menuH)
	local block = storeH + menuH + (if roomy then foldUnder else 0)
	-- a short screen (a phone) keeps the grid up at the top, clear of Roblox's thumbstick in the bottom left
	self._menuTop = if roomy then MARGIN + math.max(0, math.floor((band - block) / 2)) else MARGIN
	self._gridTop = self._menuTop + storeH
	self._foldBeside = not roomy
	-- the luck, potion and pal chips stay just over the counters on a short screen too, when they fit under the grid
	-- (Derek 2026-11-02: "the luck on mobile should be moved somewhere better"); else they go beside the arrow tab
	self._buffsLow = roomy or MARGIN + storeH + menuH + gap <= bandBottom - (buffsH + BUFFS_GAP)
	if self._buffsLow and not roomy then
		self._buffs:place(
			UDim2.new(0, MARGIN, 1, -(MARGIN + self._counterH + BUFFS_GAP)),
			Vector2.new(0, 1)
		)
	end

	self._menu.Position =
		UDim2.new(0, if self._menuFolded then menuFoldedX(menuW) else MARGIN, 0, self._gridTop)
	if not TOUCH then
		store.Position =
			UDim2.new(0, if self._menuFolded then menuFoldedX(MENU_W) else MARGIN, 0, self._menuTop)
	end
	self:_placeMenuFold()

	-- the bottom row (and its arrow tab) keeps clear of the counters
	local row: Frame? = self._travelRow
	if row then
		local rowW = row.Size.X.Offset
		self._travelShift = math.max(0, MARGIN + CORNER_W + gap - (width / 2 - rowW / 2))
		row.Position = UDim2.new(
			0.5,
			self._travelShift,
			1,
			if self._travelFolded then TRAVEL_H + 24 else -MARGIN
		)
		self._travelFold.instance.Position =
			UDim2.new(0.5, self._travelShift + rowW / 2 + TRAVEL_GAP, 1, -MARGIN)
	end
	self:_placeCorner()
end

-- The potion and bowl symbols sit in the bottom right corner, except where Roblox's touch jump button would cover
-- them (a phone: the jump button is drawn in screen pixels, Components/NetButtonPlace). There they move up and left,
-- their right edge left of where the Net button shows and their foot over the bottom row, so a thumb on jump or Net
-- never lands on them. A tablet's bigger jump button sits higher, over the corner, so the corner stays.
function HUD._placeCorner(self: any)
	self:_placeCornerPair()
	self:_placePotionTimers()
end

function HUD._placeCornerPair(self: any)
	local holder: Frame = self._corner
	local shown = 0
	for _, child in holder:GetChildren() do
		if child:IsA("GuiObject") and child.Visible then
			shown += 1
		end
	end
	local rowW = shown * SYMBOL + math.max(0, shown - 1) * CORNER_GAP
	holder.Size = UDim2.fromOffset(math.max(rowW, SYMBOL), SYMBOL_H)
	local corner = UDim2.new(1, -MARGIN, 1, -MARGIN)
	local camera = Workspace.CurrentCamera
	local root: Frame = self._root
	local scale = Scale.get()
	if shown == 0 or not TOUCH or camera == nil or scale <= 0 or root.AbsoluteSize.Y <= 0 then
		holder.Position = corner
		return
	end
	-- the root's corner in screen pixels (GUI space starts under the top bar inset)
	local inset = GuiService:GetGuiInset()
	local left = root.AbsolutePosition.X + inset.X
	local top = root.AbsolutePosition.Y + inset.Y
	local width = root.AbsoluteSize.X / scale
	local height = root.AbsoluteSize.Y / scale
	local viewport = camera.ViewportSize
	local jumpAt, jumpSize = NetButtonPlace.jump(viewport)
	local rowX = left + (width - MARGIN - rowW) * scale
	local rowY = top + (height - MARGIN - SYMBOL_H) * scale
	local covered = rowX < jumpAt.X + jumpSize
		and rowX + rowW * scale > jumpAt.X
		and rowY < jumpAt.Y + jumpSize
		and rowY + SYMBOL_H * scale > jumpAt.Y
	if not covered then
		holder.Position = corner
		return
	end
	local netAt = NetButtonPlace.place(viewport)
	local right = (netAt.X - NetButtonPlace.GAP - left) / scale -- design px from the root's left edge
	-- down on the bottom edge when the bottom row and its arrow tab end left of the pair, so the pair stays clear of
	-- the right column's lines; else over the bottom row
	local foot = height - MARGIN - TRAVEL_H - Theme.sizes.gap
	local row: Frame? = self._travelRow
	if row then
		local rowRight = width / 2 + self._travelShift + row.Size.X.Offset / 2 + TRAVEL_GAP + FOLD_W
		if not row.Visible or rowRight + Theme.sizes.gap <= right - rowW then
			foot = height - MARGIN
		end
	end
	holder.Position = UDim2.fromOffset(math.floor(right), math.floor(foot))
end

-- The running potions' chips (#963, Derek 2026-11-03: "can show active like this screenshot"): beside the Potions
-- tile, left of the corner pair with their tops level with its squares; when that would run into the bottom row (the
-- pair on the bottom edge of a narrow screen) they sit over the pair instead, right edges level.
function HUD._placePotionTimers(self: any)
	local timers: Frame = self._buffs.potions
	local holder: Frame = self._corner
	local scale = Scale.get()
	local size = self._root.AbsoluteSize
	local width, height = Scale.DESIGN.X, Scale.DESIGN.Y - 58
	if scale > 0 and size.Y > 0 then
		width, height = size.X / scale, size.Y / scale
	end
	local at = holder.Position
	local right = at.X.Scale * width + at.X.Offset -- the pair's right edge and foot, design px from the root's corner
	local top = at.Y.Scale * height + at.Y.Offset - SYMBOL_H
	local left = right - holder.Size.X.Offset - CORNER_GAP
	local timersW = if scale > 0 then timers.AbsoluteSize.X / scale else 0
	local beside = true
	local row: Frame? = self._travelRow
	if row and row.Visible and not self._travelFolded then
		local rowRight = width / 2 + self._travelShift + row.Size.X.Offset / 2 + TRAVEL_GAP + FOLD_W
		local rowTop = height - MARGIN - TRAVEL_H
		local low = top + BuffChips.potionsHeight() > rowTop
		beside = not low or left - timersW >= rowRight + Theme.sizes.gap
	end
	if beside then
		timers.AnchorPoint = Vector2.new(1, 0)
		timers.Position = UDim2.fromOffset(math.floor(left), math.floor(top))
	else
		timers.AnchorPoint = Vector2.new(1, 1)
		timers.Position = UDim2.fromOffset(math.floor(right), math.floor(top - Theme.sizes.gap))
	end
end

-- The menu's arrow tab: under the menu, or beside its last row on a short screen; at the edge once folded.
-- On a short screen the luck, potion and pal chips sit just over the counters as on a PC when they fit under the
-- grid (Derek 2026-11-02: "the luck on mobile should be moved somewhere better"; it sat by the Cats pill at the top,
-- on its own), else they follow the tab, clear of the jump and Net buttons and the right column.
function HUD._placeMenuFold(self: any)
	local fold = self._menuFold.instance
	local menuH = self._menu.Size.Y.Offset
	if self._foldBeside then
		local x = if self._menuFolded
			then MARGIN
			else MARGIN + self._menu.Size.X.Offset + Theme.sizes.gap
		local middle = self._gridTop + menuH - MENU_CELL_H / 2
		fold.Position = UDim2.fromOffset(x, middle - FOLD_H / 2)
		if not self._buffsLow then
			self._buffs:place(UDim2.fromOffset(x + FOLD_W + 12, middle), Vector2.new(0, 0.5))
		end
	else
		fold.Position = UDim2.fromOffset(MARGIN, self._gridTop + menuH + Theme.sizes.gap + 4)
	end
end

-- F92 (playing-together.md section 2): the pals on the server, cleaned (Components/PalsLogic.list). The chip shows
-- their faces and the bonus; an open boosts card gets their row; a marker for a pal who left goes.
function HUD.setPals(self: any, userIds: { number })
	self._palIds = table.clone(userIds)
	self._pals:set(userIds)
	if self._boosts.Visible then
		self:_renderBoosts()
	end
	local marked: number? = self._palMarker:palId()
	if marked ~= nil and not table.find(userIds, marked) then
		self._palMarker:hide()
	end
end

-- F92 (section 5): the joiner's marker, over the button that travels there (the Cannon, or Areas before the cannon),
-- which glows until it is pressed. Nil text takes the marker away.
function HUD.palArrived(self: any, palUserId: number, text: string?)
	if text == nil then
		self._palMarker:hide()
		return
	end
	local button = if self._cannonMode
		then self._travelButtons.cannon
		else self._travelButtons.areas
	self._palMarker:show(text, palUserId, button.instance)
end

function HUD.destroy(self: any)
	self:_stopClock()
	local shine: Tween? = self._storeShine
	if shine then
		shine:Cancel()
	end
	self._carryPortrait:destroy()
	self.catchingChanged:DisconnectAll()
	local spinTimer: thread? = self._spinTimer
	if spinTimer then
		task.cancel(spinTimer)
	end
	local baitLoop: RBXScriptConnection? = self._baitLoop
	if baitLoop then
		baitLoop:Disconnect()
	end
	for _, connection in self._connections do
		connection:Disconnect()
	end
	for _, button in self._buttons do
		button:destroy()
	end
	self._goal:destroy()
	self._luck:destroy()
	self._palMarker:destroy()
	self._pals:destroy()
	self._buffs:destroy()
	self._scaleConnection:Disconnect()
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return HUD
