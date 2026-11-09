--!strict
-- Always-on overlay in the simulator layout (docs/design/cat-cafe/ui-contract.md, HUD v3):
--   bottom left   the money with the rate beside the amount, then the golden fish (F52), one row in the corner
--                 (Derek 2026-10-28); a tap on the money opens the boosts card (Components/BoostList: what lifts the
--                 cafe's money, the exact amount on top), a tap on the golden fish shows its exact amount; the potion
--                 timers sit over the row, or beside the menu's arrow tab on a short screen, led by the Luck chip (F88,
--                 Screens/LuckChip: the clean clover on a dark green circle and "Luck x1.3" (always shown, a quiet "Luck x1" at 1x), a tap opens its card)
--   top right     small icon buttons (Tutorial, Rewards for the gifts and the Daily Treat, Trade, Feedback, and Menu for
--                 Settings and Invite; Rewards and Menu open a short list), the day and night clock
--                 under them with the next Lucky Day under it (F88: the chip's clover then "Lucky Day in 2 days"),
--                 the tier and next goal block (Screens/GoalCard) under that and the quest line under that (F73: the
--                 closest unfinished daily, "📜 Catch 5 cats 3/5", or "📜 2 ready to claim"; a tap opens Quests), and
--                 under it "🎡 Free spin at the Town Square" while today's free spin waits (F49)
--   Lighter HUD (Derek 2026-10-28, after a look at popular Roblox HUDs): counters, the clock and the goal are outlined
--   text with no box behind them; only things you press look like buttons, and the top centre is left clear.
--   left          square symbol tiles two to a row, three or four on a short screen that would need three rows (Derek
--                 2026-11-02, fewer buttons): Store (gold, always; #1167), Cats, Index, Quests, Upgrades, Decor and the
--                 bait bowl (#1210), with small key caps and red "!" dots, a clear gap between them all, centred in the
--                 space over the counters, and an arrow tab under them (beside the last row on a short screen) that
--                 folds them off the edge. Quests (F73) shows once ProfileSync has quests, with a red count of what is
--                 ready to claim
--   bottom centre the gold My Cafe teleport, Alley and Areas (an arrow tab folds the row away), moved right of the
--                 counters on a narrow screen; above them the carry banner with its red Drop button, and the tutorial
--                 strip above that
--   bottom right  the Potions symbol (the bag)
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
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local BoostList = require(script.Parent.Parent.Components.BoostList)
local BuffChips = require(script.Parent.BuffChips)
local Button = require(script.Parent.Parent.Components.Button)
local CannonLogic = require(script.Parent.Parent.Components.CannonLogic)
local CatPortrait = require(script.Parent.Parent.Components.CatPortrait)
local Create = require(script.Parent.Parent.Components.Create)
local FirstBait = require(script.Parent.Parent.Components.FirstBait)
local FishCoin = require(script.Parent.Parent.Components.FishCoin)
local Format = require(script.Parent.Parent.Components.Format)
local GiftLogic = require(script.Parent.Parent.Components.GiftLogic)
local GoalCard = require(script.Parent.GoalCard)
local HudUnlocks = require(script.Parent.Parent.Components.HudUnlocks)
local IconArt = require(script.Parent.Parent.Components.IconArt)
local IndexHints = require(script.Parent.Parent.Components.IndexHints)
local IndexRewards = require(script.Parent.Parent.Components.IndexRewards)
local Invite = require(script.Parent.Parent.Components.Invite)
local LuckChip = require(script.Parent.LuckChip)
local LuckLogic = require(script.Parent.Parent.Components.LuckLogic)
local MoneyFlash = require(script.Parent.Parent.Components.MoneyFlash)
local NightClock = require(script.Parent.Parent.Components.NightClock)
local Notices = require(script.Parent.Parent.Notices)
local Outline = require(script.Parent.Parent.Components.Outline)
local PalChip = require(script.Parent.PalChip)
local PalMarker = require(script.Parent.PalMarker)
local PassShop = require(script.Parent.Parent.Components.PassShop)
local PityLogic = require(script.Parent.Parent.Components.PityLogic)
local QuestLogic = require(script.Parent.Parent.Components.QuestLogic)
local RankUp = require(script.Parent.RankUp)
local Roadmap = require(script.Parent.Roadmap)
local RoadmapLogic = require(script.Parent.Parent.Components.RoadmapLogic)
local Scale = require(script.Parent.Parent.Scale)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local Signal = require(script.Parent.Parent.Components.Signal)
local Sound = require(script.Parent.Parent.Components.Sound)
local SpinLogic = require(script.Parent.Parent.Components.SpinLogic)
local Theme = require(script.Parent.Parent.Theme)
local TipJarLogic = require(script.Parent.Parent.Components.TipJarLogic)
local TradeLogic = require(script.Parent.Parent.Components.TradeLogic)
local TutorialGlow = require(script.Parent.Parent.Components.TutorialGlow)
local TutorialHints = require(script.Parent.Parent.Components.TutorialHints)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)
local WelcomeBack = require(script.Parent.Parent.Components.WelcomeBack)

export type Callbacks = {
	openScreen: (name: Types.ScreenName) -> (),
	travel: (destination: string) -> (), -- "home" or an AreaId
	openBait: () -> (), -- the left menu's bowl tile opens the bait bowl screen, or the cat waiting at the bowl
	-- #2353: the X2 Cash pill's tap opens Roblox's purchase window for this pass (nil: it opens the Store instead)
	buyPass: ((id: number) -> ())?,
	openIndex: () -> (), -- the Index on its cat pages, or closes it
	equipBest: () -> (),
	dropCat: () -> (), -- the carry banner's Drop button
	replayIntro: () -> (), -- the Tutorial tile (F72)
	hideTutorialButton: () -> (), -- the Tutorial tile's red ×
	openFeedback: () -> (), -- the Feedback tile: the Feedback window on its Idea chip
	setSetting: ((key: string, value: boolean) -> ())?, -- #1893: the Grand Opening strip saves roadmapOpen
	-- #1919: the goal card's "Find N more cats" nudge opens the Index on this area's page (nil: its first page)
	openIndexAt: ((areaId: string?) -> ())?,
}

export type HUD = {
	screenGui: ScreenGui,
	setCatalog: (self: HUD, catalog: Types.Catalog) -> (),
	render: (self: HUD, state: Types.PlayerState) -> (),
	goalSeen: (self: HUD) -> (), -- #2331: the rank up card opened, so the goal card's ready pulse and arrow stop
	setCarrying: (self: HUD, info: Types.CarryInfo?) -> (),
	setTutorial: (self: HUD, text: string?) -> (),
	setClock: (self: HUD, clock: Types.ClockState?) -> (),
	setLuckyDay: (self: HUD, view: LuckLogic.DayView?) -> (),
	-- F101: "🏁 Rescue Rally in 5h 20m" under the clock in the last hours before a Rally, nil hides it
	setRallySoon: (self: HUD, line: string?) -> (),
	setGift: (self: HUD, tier: string?) -> (), -- #2614: a Mystery gift waits on your plot in this wrap, or nil
	setEvent: (self: HUD, lines: { string }?, kind: string?) -> (),
	-- F101: the potion timers' row (with the Luck and pal chips), which the Rally banner keeps clear of on a phone
	buffRow: (self: HUD) -> GuiObject,
	counterRow: (self: HUD) -> GuiObject, -- #2393: the money and golden fish (top middle on touch)
	luckShown: (self: HUD) -> boolean,
	setAreasOpen: (self: HUD, open: boolean) -> (),
	setBait: (self: HUD, bait: Types.BaitView?, catWaiting: boolean) -> (),
	setBowlCount: (self: HUD, count: number) -> (), -- #1161: a "2" on the bowl tile with the second bowl
	pressTravel: (self: HUD, destination: string) -> boolean,
	setCannonMode: (self: HUD, on: boolean) -> (),
	travelResult: (self: HUD, destination: string, ok: boolean) -> (),
	isCarrying: (self: HUD) -> boolean,
	bottomTop: (self: HUD) -> number,
	toastAvoid: (self: HUD) -> { Types.Box }, -- #2338: what the toasts keep clear of
	setCatching: (self: HUD, active: boolean) -> (),
	roadmapStep: (self: HUD, n: number) -> (),
	setCatchStreak: (self: HUD, streak: number) -> (),
	-- F101: fires (active) when a catch or rescue starts or ends, so the Rally banner gets out of its way
	catchingChanged: Signal.Signal,
	isCatching: (self: HUD) -> boolean,
	setMenuFolded: (self: HUD, folded: boolean) -> (),
	setTravelFolded: (self: HUD, folded: boolean) -> (),
	screenOpened: (self: HUD, name: string?) -> (),
	setTipJar: (self: HUD, summary: { ready: number, nextIn: number?, left: number }?) -> (),
	setDailyTreat: (self: HUD, shown: boolean, due: boolean) -> (),
	-- the gold Store tile at the top of the left menu, shown once init's Store block has its window (#1167)
	setStore: (self: HUD, open: (() -> ())?) -> (),
	setStoreNew: (self: HUD, shown: boolean) -> (),
	setOwnerTest: (self: HUD, label: string?) -> (), -- #1770 owner test mode
	-- #1646: the Cafe Pass tile, shown with the function that opens the Pass window while a season runs (nil hides
	-- it), and its red "!" while `ready` rewards wait
	setPass: (self: HUD, open: (() -> ())?, ready: number) -> (),
	setTutorialButton: (self: HUD, shown: boolean) -> (),
	glowTutorial: (self: HUD) -> (),
	pulseTutorial: (self: HUD) -> (),
	setVisible: (self: HUD, visible: boolean) -> (),
	setMoneyBadge: (
		self: HUD,
		badge: { text: string, owned: boolean, price: string?, quiet: boolean?, id: number? }?
	) -> (), -- #1606, #1759, #1936, #2353
	-- F92: the pals on the server (PalsChanged), for the chip and the boosts card
	setPals: (self: HUD, userIds: { number }) -> (),
	-- F92: "Sam is in the Park" over the travel button to that area, glowing; nil text takes it away
	palArrived: (self: HUD, palUserId: number, text: string?) -> (),
	destroy: (self: HUD) -> (),
}

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local StoreFunnel = require(Shared:WaitForChild("StoreFunnel")) -- #1888: where a Store open came from

local MARGIN = 16
-- the money and golden fish counters, one row in the bottom left corner with no box behind them (the lighter HUD);
-- each is as wide as its amount, the money at most MONEY_W, and MONEY_H tall
local MONEY_W = 232
-- #2194: the money amount takes the room of its shape with the widest digits ("$33.7M" takes "$88.8M"), so the golden
-- fish beside it holds still while the digits tick. #2383 (Derek2 11-08: "isn't supposed to be a big gap between the
-- money and fish"): it used to take at least 140 px, a wide gap after a short amount
local function moneyShape(text: string): string
	return (text:gsub("%d", "8"))
end
local MONEY_H = 44
local COUNTER_COIN = 36
local COUNTER_TEXT = 30
local MONEY_BADGE_H = 30 -- #1606: the money pass badge beside the money
local MONEY_BADGE_TEXT = 22
-- #1759 (Derek2 11-06: "more in your face then that slight 2x"): the not-owned badge, a rainbow "X2 Cash" pill with
-- "Only R$5" under it that pulses gently
local CASH_H = 30
local CASH_TEXT = 22
local CASH_PRICE_H = 14
local CASH_PULSE = 1.08 -- the badge's scale at the top of each pulse
local CASH_PULSE_SECONDS = 0.7 -- one way
local COUNTER_GAP = 14
-- the row's widest usual reach (the money at MONEY_W and "12.3K" golden fish): the bottom row moves right of it
local CORNER_W = MONEY_W + COUNTER_GAP + COUNTER_COIN + 8 + 90
local BUFFS_GAP = 8 -- the potion timers sit this far over the counters (F64)
local TOP_GAP = 10 -- #2447: on touch, between the top bar's ends, the counters and the Luck row
local CASH_TAG_H = 24 -- #2447: the owned Cash multiplier's small tag beside the money on touch
local BOOSTS_W = 300 -- the money's boosts card
local BOOST_ROW_H = 24
local BOOST_ROWS_TIGHT = 10 -- more rows than this draw each row shorter (#1624)
local BOOST_ROWS_SNUG = 11 -- #2147: and more than this shorter again
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
-- #1676 (Derek2 live 11-05: "the buttons became way too big and spread so they take up too much screen"): 66 on a PC
-- (was 78), its label 15, the Store 68 tall, and the gaps only the outline clear of the key caps and red dots. On a
-- phone or tablet 60 (was 64): 45 px at the smallest touch scale (Scale.TOUCH_FLOOR), still a finger's 44.
-- #2372 (Derek2 11-07: "scale down the button sizes for mobile users so it doesn't take up so much of the screen"):
-- on touch 54, drawn 40 px on a phone; Button's invisible Hit pad still takes a finger's 44 round each, and the
-- columns sit far enough apart (MENU_GAP) that the pads never overlap
local MENU_TILE = if TOUCH then 54 else 66
local MENU_TEXT = if TOUCH then Theme.sizes.textTiny + 1 else 15 -- a menu tile's label
local MENU_CELL_H = if TOUCH then MENU_TILE else MENU_TILE + MENU_TEXT + 4 -- the square and the label's strip
local STORE_H = 68 -- the Store's wide tile, two tiles wide, over the grid
local STORE_TEXT = 24
-- the Store's shine sweeps across in 0.9 s, then waits 3.5 s, for good; a still shine under reduced motion
local STORE_SHINE =
	TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, false, 3.5)
local MENU_COLUMNS = 2
-- a short screen (a phone) whose grid would run three rows deep takes three tiles a row, so the bottom row stays out
-- of Roblox's thumbstick in the bottom left (review N343: the Store tile's row put Upgrades there)
local MENU_COLUMNS_SHORT = 3
-- and four a row when three would still reach the thumbstick (a phone with the bowl in the menu, #1210)
local MENU_COLUMNS_MAX = 4
-- on a touch screen the grid also keeps out of the bottom left's last 180 px, where Roblox's thumbstick sits (the UI
-- gate's thumbstick zone), so a phone takes three tiles a row before its third row reaches down there
local THUMB_ZONE = 180
-- #1210 (Derek 2026-11-04: the Store tile sat on the Cats and Index tiles, the C key badge half under it, and the
-- rows below the same): every tile and every row keeps a clear gap of at least the outline plus the button foot
-- (#1105) between what each one draws, not between their boxes. A tile draws past its box: its outline all round,
-- the key cap on its top left corner, the red dot on its top right and, on the Store, the gold glow and its hover.
-- the empty space between two tiles' drawn edges: #1210 asked for the outline plus the button foot (9), but the clean
-- tiles draw no foot since #1105 and #1676 asks for a tighter column, so it is the outline's width (4)
local TILE_CLEAR = Button.OUTLINE
-- a key cap at (-4, -4) with its 2 px outline pokes this far past the tile's top and left; a touch screen shows none
-- (showKeys is the keyboard's), so on touch the tiles need no room for them (#2372)
local KEY_REACH = if TOUCH then 0 else 6
-- the red dot (22 px, its middle 3 px down the tile's top edge, its right edge 2 px past the side since #1176, a 2 px
-- outline) past the tile's top and its right side
local DOT_TOP = 10
local DOT_SIDE = 4
local GLOW_REACH = 6 -- the Store's gold glow round it
-- a wide Store tile grows by its hover scale round its middle (Button.HOVER_SCALE), half of it on each side
local STORE_HOVER = math.ceil(STORE_H * (Button.HOVER_SCALE - 1) / 2)
-- past a tile's sides and foot: its outline, or the Store's glow when the Store is one of the grid's squares (touch)
local SIDE_REACH = if TOUCH then math.max(Button.OUTLINE, GLOW_REACH) else Button.OUTLINE
-- a clean tile's foot is its label under the square: the text's 2 px outline, no box outline
local FOOT_REACH = if TOUCH then SIDE_REACH else Theme.sizes.textOutline
-- Between the columns: a tile's right side (its outline, or the Store's glow) and the next one's key cap keep
-- TILE_CLEAR apart, and a lit red dot on the top right keeps at least the outline from that key cap.
-- On touch a long label inside the smaller tile ("Upgrades") runs up to LABEL_REACH past its sides (#2372).
local LABEL_REACH = if TOUCH then 4 else 0
local MENU_GAP = math.max(
	SIDE_REACH + KEY_REACH + TILE_CLEAR,
	DOT_SIDE + KEY_REACH + Button.OUTLINE
) + LABEL_REACH -- 19, 14 touch
-- Under a tile whose foot reaches this far: TILE_CLEAR to the next row's key caps, the outline to its red dots.
local function rowGap(foot: number): number
	return math.max(foot + KEY_REACH + TILE_CLEAR, foot + DOT_TOP + Button.OUTLINE)
end
local ROW_GAP = rowGap(FOOT_REACH) -- between the rows (17 on a PC, 20 on touch)
local STORE_GAP = rowGap(GLOW_REACH + STORE_HOVER) -- under the wide Store tile, over the grid (23)
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
-- the Potions symbol, bottom right (left of the bottom row on touch: _placeCorner)
local SYMBOL = if TOUCH then 64 else 74 -- a little smaller on touch, level with the bottom row's tiles
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
-- #2411 (Derek2: "the X isn't obvious"): a bigger red × (it was a 20 px dot) taking bigger taps
local HIDE_DOT = if Scale.isTouch() then 28 else 24
local HIDE_HIT = if Scale.isTouch() then 42 else 36 -- the Tutorial tile's × takes taps this big round its red dot
-- #2211 (crispi_255): when the tutorial ends, the × bounces in a gold ring this long, so players see it hides the tile;
-- #2411: twice as long, with a "Hide tips" tag beside the tile
local HIDE_PULSE_SECONDS = 6
local HIDE_HINT_H = 24
local HIDE_WAIT_SECONDS = 120 -- #2411: how long the pulse waits for the HUD to be on screen and free
local HIDE_BOUNCE = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 2, true)
-- F72: the Tutorial tile's two gold pulses the first time it shows after an intro
local GLOW = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 1, false, 0.15)
local CARRY_W = 420
local CARRY_H = 56
local TUTORIAL_W = 520 -- the tutorial strip's widest box (design px), padding included
local DROP_W = 104
-- the arrow tabs that fold the left menu and the bottom row out of the way (Derek 2026-10-27: less clutter)
local FOLD_W = 44
local FOLD_H = 34
-- the arrow tab under the grid: the last row's foot, then the clear gap and the tab's own 3 px outline (#1210), and 2 px
-- more since TILE_CLEAR went down to the outline (#1676), for the two-bowl Bowl tile's count that sits a little lower
local FOLD_UNDER = FOOT_REACH + TILE_CLEAR + 5
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
local LUCKY_CLOVER = 18 -- #1258: the luck chip's circle in front of that line
local LUCKY_GAP = 8 -- #2084: between that circle and the first letter (#2416: clear of the words' outline too)
local DAY_CARD_W = 300 -- #1572: the day line's card
local DAY_CARD_Z = 20
-- The top right column (icon row, clock, tips line, tier and goal) is this wide at most. The HUD keeps clear of
-- Roblox's top bar, which left a tall empty band over that column (Derek 2026-10-27); when the bar's free stretch
-- (GuiService.TopbarInset) runs over the column, the column moves up into it. TOPBAR_SLACK is how far short of the
-- screen's right edge that stretch may stop and still count.
local RIGHT_COLUMN_W = math.max(300, ICON_ROW_W)
-- #2528 (Derek2: "remove the quest line showing a brief summary under your goal"): F73's quest line under the goal
-- card is gone (the Quests tile's count still shows what is ready); the free spin line keeps its size
local SPIN_LINE_W = 300
local SPIN_LINE_H = 24
-- F49: the Town Square's red free-spin dot went with its place bubble (Derek 2026-10-28 01:39), so the HUD says it
-- instead (Derek okayed 12:02): a gold line under the quest line, no box, not a button, since the wheel is a station
-- you walk up to
local SPIN_TEXT = Theme.icons.spin .. " Free spin at the Town Square"
local TUTORIAL_DONE = 5 -- the tutorial's last step (UIController.refreshTutorial): the quest line waits for it
local TOPBAR_SLACK = 48
local TRADE_NOTE_SECONDS = 3 -- #2462: the greyed Trade tile's "Unlocks at Tier 3" note
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

-- The red "!" in a corner, the same badge as the Rewards tile's, on whatever can be claimed (#1074).
local function claimBadge(parent: Instance, zIndex: number): Frame
	local badge: Frame = Create("Frame", {
		Name = "Claim",
		BackgroundColor3 = Theme.colors.red,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, -2), -- inside the row's right end, clear of the list's edge
		Size = UDim2.fromOffset(24, 24),
		Visible = false,
		ZIndex = zIndex,
		Parent = parent,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(badge, 2)
	local mark = label({
		Name = "Mark",
		Size = UDim2.fromScale(1, 1),
		TextSize = Theme.sizes.textSmall,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "!",
		ZIndex = zIndex + 1,
		Parent = badge,
	})
	mark.ZIndex = zIndex + 1
	return badge
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
	-- #2393 (Derek2 11-08: "the 2x money pop up, money amount/breakdown menu, golden fish, and lucky and the breakdown
	-- menu are all kind of where you want your left thumb to move around maybe make it on the top middle of the screen
	-- ... and put the 2x money advertising on the right side above potions"): on touch the counters sit at the top
	-- middle, the Luck row under them (_layoutMenu) and their cards open under that; the money badge goes over the
	-- Potions tile on the right (_placePotionTimers). A PC keeps the bottom left.
	if TOUCH then
		counters.AnchorPoint = Vector2.new(0.5, 0)
		counters.Position = UDim2.new(0.5, 0, 0, MARGIN)
	end
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
	-- the gold coin picture (Icon_Clean_CoinGold, #1253), then the amount. The rate per second shows only in the
	-- boosts card a tap opens (Derek 2026-11-02: "how much per second should be hidden until clicked also"). If the
	-- picture fails to load, the gold "$" shows instead.
	local coin: Frame = Create("Frame", {
		Name = "Coin",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(COUNTER_COIN, COUNTER_COIN),
		LayoutOrder = 1,
		Parent = money,
	})
	local coinGlyph = label({
		Size = UDim2.fromScale(1, 1),
		TextSize = 24,
		TextColor3 = Theme.colors.gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = Theme.currencySymbol,
		Parent = coin,
	})
	Outline.text(coinGlyph, 2.5)
	IconArt.setImage(coinGlyph, ShopIcons.clean("Coin"), 1)
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
		-- the amount is short (Format.money). #2194 (playtester Dread via Derek2, 11-07: "The cash at the bottom left
		-- should probably not push the 2x cash and fish"): the amount sits in the room of its shape (moneyShape), so
		-- the golden fish and the badge after it stay put while the digits tick
		Create("UISizeConstraint", {
			MaxSize = Vector2.new(MONEY_W - COUNTER_COIN - 8, MONEY_H),
		}),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 5) }),
	})
	-- the room: the amount's shape in unseen text (no outline), as wide as the widest digits; the amount on it
	local room: TextLabel = Create("TextLabel", {
		Name = "Room",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 36),
		FontFace = Theme.fonts.display,
		TextSize = COUNTER_TEXT,
		TextTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = moneyShape(Format.money(0)),
		LayoutOrder = 1,
		Parent = line,
	})
	self._moneyRoom = room
	self._moneyText = label({
		Name = "Amount",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 36),
		TextSize = COUNTER_TEXT,
		TextTruncate = Enum.TextTruncate.None,
		Text = Format.money(0),
		Parent = room,
	})

	-- Golden fish (F52): the rare currency's counter beside the money, with the gold fish (F97). Hidden until
	-- ProfileSync sends goldenFish.
	-- #2334 (Derek2: "the gold fish and money should be side by side in bottom left and the 2x cash ... should be to
	-- the right of both of those"): the row is the money, the golden fish, then the money badge.
	-- #1606: the money pass badge right of the two counters (setMoneyBadge): "2x" to "4x" in gold once a money pass is owned
	-- (a tap opens the boosts card, as the money does), or while none is (a tap opens the Store) a rainbow "X2 Cash"
	-- pill with "Only R$5" under it, pulsing (#1759). Hidden until the Store knows.
	-- the tap area is the counters' height and at least as wide (a finger's 44 px on a phone); the pill sits inside it
	local badge: TextButton = Create("TextButton", {
		Name = "MoneyBadge",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromOffset(0, counterH),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 3, -- #2334: after the golden fish
		AnchorPoint = if TOUCH then Vector2.new(1, 1) else nil, -- #2393: over the Potions tile on touch
		Visible = false,
		Parent = if TOUCH then root else counters,
	}, {
		Create("UISizeConstraint", { MinSize = Vector2.new(counterH, 0) }),
		Create("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._moneyPulse = Create("UIScale", { Parent = badge }) :: UIScale
	local pill: TextLabel = Create("TextLabel", {
		Name = "Pill",
		BackgroundColor3 = Theme.colors.berry,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, MONEY_BADGE_H),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = Theme.fonts.display,
		TextSize = MONEY_BADGE_TEXT,
		TextColor3 = Theme.colors.gold,
		Text = "",
		LayoutOrder = 1,
		Parent = badge,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
		-- #1759: the rainbow under the "X2 Cash" words while no money pass is owned
		Create("UIGradient", { Name = "Rainbow", Color = Theme.rainbow, Enabled = false }),
	})
	Outline.text(pill, 2.5)
	self._moneyPill = pill
	local price: TextLabel = Create("TextLabel", {
		Name = "Price",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, CASH_PRICE_H),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = Theme.fonts.display,
		TextSize = CASH_PRICE_H,
		TextColor3 = Theme.colors.white,
		RichText = true,
		Text = "",
		LayoutOrder = 2,
		Visible = false,
		Parent = badge,
	})
	Outline.text(price, 2)
	self._moneyPrice = price
	self._moneyBadge = badge
	self._moneyBadgeOwned = false
	self._moneyBadgeId = nil :: number?
	table.insert(
		self._connections,
		badge.Activated:Connect(function()
			local passId: number? = self._moneyBadgeId
			local buy: ((id: number) -> ())? = self._callbacks.buyPass
			if self._moneyBadgeOwned then
				self:_toggleBoosts()
			elseif passId ~= nil and buy ~= nil then
				-- #2353: the X2 Cash pill buys the pass right here; the Store's own card stays for players who browse
				buy(passId)
			else
				-- #1888: the money badge's "Get 2x" is a nudge into the Store (the quiet first 30 minutes, #1936)
				StoreFunnel.noteSource("nudge")
				self._callbacks.openScreen("Store")
			end
		end)
	)

	local fish = counter("Fish", 2, "Frame") -- #2334: right beside the money
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
	if TOUCH then
		-- #2529: the potion chips sit over the Potions tile left of the bottom row, so the carry banner and the tutorial
		-- strip rise over them while they run (_placePotionTimers, _layoutBottom)
		for _, signal in
			{
				timers:GetPropertyChangedSignal("Visible"),
				badge:GetPropertyChangedSignal("AbsoluteSize"),
			} :: { RBXScriptSignal }
		do
			table.insert(
				self._connections,
				signal:Connect(function()
					self:_placePotionTimers()
				end)
			)
		end
	end
	-- #2334: the bottom row keeps clear of the counters as they grow (the badge showing, the golden fish arriving)
	local countersResized: RBXScriptConnection = counters
		:GetPropertyChangedSignal("AbsoluteSize")
		:Connect(function()
			self:_layoutMenu()
		end)
	table.insert(self._connections, countersResized)

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
		image = ShopIcons.hud("Tutorial"),
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
		AnchorPoint = Vector2.new(1, 0.5), -- inset (#1176: "the Claim button's red ! badge hangs over into the Feedback button"): no more than 2 px past the edge
		Position = UDim2.new(1, 4, 0, 6),
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
		Size = UDim2.fromOffset(HIDE_DOT, HIDE_DOT),
		ZIndex = 8,
		Parent = hide,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(hideDot, 2)
	self._hideDot = hideDot
	label({
		Name = "Cross",
		Size = UDim2.fromScale(1, 1),
		TextSize = Theme.sizes.textBody, -- #2411: was textSmall
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
	-- (F70). "Rewards" with a red "!" while either has something waiting, else the time to the next gift. With both
	-- live a press opens a short list under the row; with one it opens that window at once.
	local rewards = Button.new({
		name = "Rewards",
		text = "Rewards",
		icon = Theme.icons.gifts,
		image = ShopIcons.hud("Rewards"),
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
		AnchorPoint = Vector2.new(1, 0.5), -- inset (#1176: "the Claim button's red ! badge hangs over into the Feedback button"): no more than 2 px past the edge
		Position = UDim2.new(1, 2, 0, 4),
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
		image = ShopIcons.hud("Feedback"),
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
		image = ShopIcons.hud("Menu"),
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
	-- lower minimum shows it too). #2462 (Derek2 11-08: "show the trade button but grayed out until unlocked and when
	-- clicked it says unlocks at Tier 3 so that it entices people to stay until Tier 3"): below it the tile shows
	-- greyed, and a tap says which tier opens it (_tradeLockedNote)
	self._tradeTile = Button.new({
		name = "Trade",
		text = "Trade",
		icon = TradeLogic.ICON,
		image = ShopIcons.clean("Trade"), -- #1024: the glyph shows until Icon_Clean_Trade is uploaded
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
		onLocked = function()
			self:_tradeLockedNote()
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
	self._popBadges = {} :: { [string]: Frame } -- each row's red "!" (#1074)

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
	-- F88 (luck-and-rare-moments.md 1c): the day line under the clock, in gold; since #1572 today's kinds from the Clock
	-- folder's LuckyDay, GoldenDay and RainbowDay (LuckLogic.dayLine, "Lucky · Golden Day"), with a card on a tap
	-- #2416 (Derek2: "the clover in the lucky day overlaps the name still"): the clover and the words are one row,
	-- right-aligned as a whole, the clover first. The words are left-aligned in their own label, so whatever the
	-- label's measured width misses (the outline, a long "Lucky · Golden · Rainbow Day" at the width cap) spills
	-- right, away from the clover, never back over it (#2084 hung the clover off a right-aligned label instead)
	local luckyRow: Frame = Create("Frame", {
		Name = "LuckyRow",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -MARGIN, 0, CLOCK_TOP + CLOCK_H),
		Size = UDim2.fromOffset(0, NIGHT_LINE),
		AutomaticSize = Enum.AutomaticSize.X,
		Visible = false,
		Parent = root,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, LUCKY_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._luckyRow = luckyRow
	self._luckyLine = label({
		Name = "LuckyDay",
		Size = UDim2.fromOffset(0, NIGHT_LINE),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.colors.gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.None,
		LayoutOrder = 2,
		Visible = false,
		Parent = luckyRow,
	})
	Create(
		"UISizeConstraint",
		{ MaxSize = Vector2.new(LUCKY_LINE_W, math.huge), Parent = self._luckyLine }
	)
	-- #1258: the luck chip's circle and clean clover in front of the right-aligned words, LUCKY_GAP left of the first
	-- letter whatever the words are
	local luckyClover = LuckChip.circle(LUCKY_CLOVER, {
		LayoutOrder = 1,
		ZIndex = self._luckyLine.ZIndex,
		Parent = luckyRow,
	})
	local luckyLine: TextLabel = self._luckyLine
	self._luckyClover = luckyClover
	self._luckyDay = nil :: LuckLogic.DayView?
	-- #1572: a tap on the day line opens its card (each kind today, what it does and how often it comes); another tap
	-- or a window opening closes it. The tap area is a finger tall over the 20 px line.
	local dayTap: TextButton = Create("TextButton", {
		Name = "Tap",
		Text = "",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		-- the words and the clover in front of them (#2084: the line is only as wide as its words now)
		Position = UDim2.new(0, -(LUCKY_CLOVER + LUCKY_GAP), 0.5, 0),
		Size = UDim2.new(1, LUCKY_CLOVER + LUCKY_GAP, 0, Scale.tapHeight(Theme.sizes.touchMin)),
		ZIndex = luckyLine.ZIndex + 1,
		Parent = luckyLine,
	})
	self._dayCard = Create("Frame", {
		Name = "DayCard",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -MARGIN, 0, CLOCK_TOP + CLOCK_H + NIGHT_LINE + 4),
		Size = UDim2.fromOffset(DAY_CARD_W, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.dark.panel,
		BorderSizePixel = 0,
		ZIndex = DAY_CARD_Z, -- over the goal card and the quest line under the clock
		Visible = false,
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }),
		Create("UIStroke", { Color = Theme.colors.gold, Thickness = 2 }),
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
		}),
		Create(
			"UIListLayout",
			{ Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }
		),
	})
	-- #1572 (luck-and-rare-moments.md 1h): under the day kinds, the pity sign's lines, ticking while the card is open
	self._dayPity = Create("TextLabel", {
		Name = "Pity",
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.colors.gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = "",
		ZIndex = DAY_CARD_Z + 1,
		Parent = self._dayCard,
	})
	self._dayCardText = Create("TextLabel", {
		Name = "Lines",
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.dark.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = "",
		ZIndex = DAY_CARD_Z + 1,
		Parent = self._dayCard,
	})
	table.insert(
		self._connections,
		dayTap.Activated:Connect(function()
			self:_toggleDayCard()
		end)
	)
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
	-- #2487 (live-events.md section 3): the Cafe Event's chip under those, "⏳ Cafe Party in 2:59" from T-3h, gold
	-- while it runs, with "next shower 9:12" on a line of its own under it (EventNext; Components/EventLogic.chip,
	-- painted from UI.cafeEvent)
	self._eventLine = label({
		Name = "EventChip",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -MARGIN, 0, CLOCK_TOP + CLOCK_H),
		Size = UDim2.fromOffset(RIGHT_COLUMN_W, NIGHT_LINE),
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.colors.white,
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = false,
		Parent = root,
	})
	self._eventNext = label({
		Name = "EventNext",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -MARGIN, 0, CLOCK_TOP + CLOCK_H + NIGHT_LINE),
		Size = UDim2.fromOffset(RIGHT_COLUMN_W, NIGHT_LINE),
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.colors.gold,
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = false,
		Parent = root,
	})
	self._event = nil :: string?

	-- Tier and next goal (right, under the clock): the tier, the next tier's requirements as slim bars; a tap opens
	-- rank up
	self._goal = GoalCard.new(root, UDim2.new(1, -MARGIN, 0, GOAL_TOP), function()
		local openAt = callbacks.openIndexAt
		if openAt and self._goal:nudging() then
			openAt(self._goalArea) -- #1919
			return
		end
		callbacks.openScreen("RankUp")
	end)
	self._goalArea = nil :: string?
	-- #1893 (first-hour.md 1b): the Grand Opening strip just under the goal card; a tap opens or closes its steps,
	-- saved as the roadmapOpen setting
	self._roadmap = Roadmap.new(root, UDim2.new(1, -MARGIN, 0, GOAL_TOP), function(open: boolean)
		self._roadmapOpen = open
		local save = callbacks.setSetting
		if save then
			save("roadmapOpen", open)
		end
		self:_layoutRight()
	end)
	-- #2358 (Derek2: "show an exclamation mark near spin when you have one"): the red "!" at the line's left, the
	-- words right-aligned after it
	local spinLine: Frame = Create("Frame", {
		Name = "FreeSpin",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(SPIN_LINE_W, SPIN_LINE_H),
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
	self._spinLine = spinLine
	-- #2614: while a Mystery gift waits on your plot, one quiet line in its wrap's colour under the spin line. Info
	-- only: no press, no pop-up (HUD:setGift from UI's plot watch)
	self._giftLine = label({
		Name = "GiftWaiting",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(SPIN_LINE_W, SPIN_LINE_H),
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.colors.cream,
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = false,
		Parent = root,
	})
	self._giftTier = nil :: string?
	local spinBang = claimBadge(spinLine, 2)
	spinBang.Size = UDim2.fromOffset(SPIN_LINE_H - 2, SPIN_LINE_H - 2)
	spinBang.LayoutOrder = 1
	spinBang.Visible = true
	self._spinText = label({
		Name = "Text",
		Size = UDim2.fromOffset(0, SPIN_LINE_H),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.colors.gold,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = SPIN_TEXT,
		LayoutOrder = 2,
		Parent = spinLine,
	})
	self._spinTimer = nil :: thread?
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
	-- leads the grid once init's Store block hands it its window (setStore); Potions moved to a symbol in the bottom right corner.
	local showKeys = UserInputService.KeyboardEnabled
	type MenuItem = {
		name: string,
		text: string?, -- the label, when it is not the name (the bowl's "Bowl")
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
		-- #1646 (cafe-pass.md): the Cafe Pass, only while a season runs (setPass); hidden, the grid closes up. #1965
		-- (Derek2: "make a better ui button for pass"): the Cafe Pass medal picture from its Store card, in place of
		-- the maple leaf emoji; the red badge says a reward waits. Its emoji, shown until the picture loads, is the
		-- medal too, as on the Store's Cafe Pass tab (#1982)
		{
			name = "Pass",
			icon = "🏅",
			style = "purple",
			open = function()
				local open: (() -> ())? = self._passOpen
				if open then
					open()
				end
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
		-- #1181 (corner-shop-v2.md section 3): the Bag in the left column, opening the Bag window (Potions and Cat Food
		-- tabs); P opens it too. The corner potion symbol stays, since the potion timers sit beside it.
		{
			name = "Bag",
			icon = "🎒",
			key = "P",
			style = "berry",
			open = function()
				callbacks.openScreen("Potions")
			end,
		},
		-- #1210 (2026-11-04: "move the food bowl button into the left menu"): the bowl, once the Bait bowl upgrade is
		-- owned, labelled "Bowl", with a red "!" while a cat waits (_renderBowl)
		{
			name = "Bowl",
			text = "Bowl", -- always the word; the timer is in the Bait bowl window (#1282)
			icon = BOWL_ICON,
			key = "F",
			style = "secondary",
			open = function()
				self._callbacks.openBait()
			end,
		},
	}
	-- placed by _layoutMenu in the space over the counters; hidden tiles leave no hole in the grid
	local menuLayout: UIGridLayout = Create("UIGridLayout", {
		CellSize = UDim2.fromOffset(MENU_TILE, MENU_CELL_H),
		CellPadding = UDim2.fromOffset(MENU_GAP, ROW_GAP),
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
			text = item.text or item.name,
			icon = item.icon,
			image = ShopIcons.hud(item.name),
			layout = if isStore then "wide" else TILE_LAYOUT,
			style = item.style,
			size = if isStore
				then UDim2.fromOffset(MENU_W, STORE_H)
				else UDim2.fromOffset(MENU_TILE, MENU_CELL_H),
			textSize = if isStore then STORE_TEXT else MENU_TEXT,
			layoutOrder = index,
			parent = if isStore then root else menu,
			sound = false, -- the modal swish is the sound (the bait screen plays uiOpen itself)
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
				AnchorPoint = Vector2.new(1, 0.5), -- inset: no more than 2 px past the tile's edge (#1176)
				Position = UDim2.new(1, 2, 0, 3),
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
		if item.name == "Upgrades" then
			self._upgradesTile = button -- #1796: glows while a tutorial step asks for an upgrade
		end
		if item.name == "Store" then
			button.instance.Visible = false -- until setStore hands it a window to open
			self._storeTile = button
			-- #1823 §4: a 10 px pink New dot on its top right while a Store tab gained an item; no number, no pulse
			self._storeNew = Create("Frame", {
				Name = "NewDot",
				BackgroundColor3 = Theme.colors.berry,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -3, 0, 3),
				Size = UDim2.fromOffset(10, 10),
				Visible = false,
				ZIndex = 6,
				Parent = button.instance,
			}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
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
				AnchorPoint = Vector2.new(1, 0.5), -- inset: no more than 2 px past the tile's edge (#1176)
				Position = UDim2.new(1, 2, 0, 3),
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
		elseif item.name == "Pass" then
			button.instance.Visible = false -- while a Cafe Pass season runs (setPass)
			self._passTile = button
			local passBadge = claimBadge(button.instance, 23)
			passBadge.AnchorPoint = Vector2.new(1, 0.5) -- inset like the Quests dot (#1176)
			passBadge.Position = UDim2.new(1, 2, 0, 3)
			passBadge.Size = UDim2.fromOffset(22, 22) -- the menu dots' size: the 24 px badge poked into the Store's glow
			self._passBadge = passBadge
		elseif item.name == "Bowl" then
			button.instance.Visible = false -- once the Bait bowl upgrade is owned (_renderBowlSlot)
			self._bowl = button
			self._bowlSlot = button.instance
			local bowlBadge = claimBadge(button.instance, 23)
			bowlBadge.AnchorPoint = Vector2.new(1, 0.5) -- inset like the Quests dot (#1176); the F key cap is top left
			bowlBadge.Position = UDim2.new(1, 2, 0, 3)
			bowlBadge.Size = UDim2.fromOffset(22, 22) -- as the Pass tile's
			self._bowlBadge = bowlBadge
			-- #1161: a small "2" at the bottom right while the cafe has two bowls (the "!" is top right). It sits on the
			-- square's own corner: on the tile's corner it covered the end of the "Bowl" label under it (Studio run
			-- 2026-11-07)
			local count: TextLabel = label({
				Name = "Count",
				BackgroundColor3 = Theme.colors.cocoaDeep,
				BackgroundTransparency = 0,
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, 2, 1, -2),
				Size = UDim2.fromOffset(20, 20),
				TextSize = Theme.sizes.textTiny,
				TextXAlignment = Enum.TextXAlignment.Center,
				Text = "2",
				Visible = false,
				ZIndex = 23,
				Parent = button.face,
			})
			Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = count })
			Outline.border(count, 2)
			self._bowlCount = count
		end
		self._pills[item.name] = button
		table.insert(self._buttons, button)
	end
	self._menu = menu
	self._storeOpen = nil :: (() -> ())?
	self._passOpen = nil :: (() -> ())?
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
	-- which to use"): the Potions symbol (the bag, with how many it holds). The bait bowl's symbol moved into the left
	-- menu on 2026-11-04 (#1210).
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
		image = ShopIcons.hud("Potion"),
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
		AnchorPoint = Vector2.new(1, 0.5), -- inset (#1176)
		Position = UDim2.new(1, 2, 0, 3),
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
			image = ShopIcons.hud("Home"),
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
			image = ShopIcons.hud("Areas"),
			style = "sky",
		},
		-- F84: shown in place of Areas once the Cat Cannon is live (setCannonMode)
		{
			key = "cannon",
			name = "Cannon",
			label = "Cannon",
			icon = Theme.icons.cannon,
			image = ShopIcons.hud("Cannon"),
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
	-- bottom anchor so the carry banner stacking is unchanged. It wraps only when setTutorial measures a line too
	-- long for one row: wrapped from the start, Roblox's AutomaticSize broke a 46 character hint over the player on
	-- a phone well short of 520 (device pass 2026-11-07).
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
		TextWrapped = false,
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
	Create("UISizeConstraint", {
		MinSize = Vector2.new(0, 40),
		MaxSize = Vector2.new(TUTORIAL_W, 64),
		Parent = self._tutorial,
	})

	self:_layoutBottom()
	self:_buildBoosts(root)
	if TOUCH then
		-- #2447: the counters' row follows the top bar again now the row under it and the boosts card are built, and
		-- whenever the amount grows or shrinks
		self:_liftTop()
		-- the amount, the Luck row and the icon row (the Tutorial tile comes and goes) all change what fits
		for _, item in { self._counters, self._buffs.frame, self._icons } :: { GuiObject } do
			table.insert(
				self._connections,
				item:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
					self:_liftTop()
				end)
			)
		end
		table.insert(
			self._connections,
			(self._buffs.frame :: Frame):GetPropertyChangedSignal("Visible"):Connect(function()
				self:_liftTop()
			end)
		)
	end
	pop.Parent = root -- the Rewards and Menu list goes in last, so it draws over the clock and the goal card
	-- F88: the Luck chip leads the potion timers' row; its card opens over the counters as the boosts card does (built
	-- after the menu, so it draws over it)
	self._luck = LuckChip.new(
		self._buffs.frame,
		root,
		UDim2.new(0, MARGIN, 1, -(MARGIN + self._counterH + BUFFS_GAP)), -- (LuckChip._place opens it under the chip at the top)
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
	-- #1962 (Derek2 11-07: "not in your face enough it should be on the side"): once a money pass is owned, a bold gold
	-- "💰 Cash x2" chip leads the row over the money in place of the small "2x" beside it; a tap opens the boosts card
	local cash: TextButton = Create("TextButton", {
		Name = "CashChip",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, Scale.tapHeight(36)),
		FontFace = Theme.fonts.display,
		TextSize = 22,
		TextColor3 = Theme.colors.white,
		Text = "",
		LayoutOrder = -1, -- before the Luck chip
		Visible = false,
		Parent = self._buffs.frame,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
	})
	if TOUCH then
		-- #2447 (Derek2 11-08: "if someone bought 4x cash make the bubble much smaller on the side of the money"): on
		-- touch the chip is a small gold tag right after the amount, in the counters' row at the top; the button
		-- around it keeps the counters' height so a finger still finds it
		cash.BackgroundTransparency = 1
		cash.Size = UDim2.fromOffset(0, self._counterH)
		cash.LayoutOrder = 2
		cash.Parent = self._counters
		self._fishPanel.LayoutOrder = 3
		local pad = cash:FindFirstChildOfClass("UIPadding")
		if pad then
			pad:Destroy()
		end
		local tag: TextLabel = Create("TextLabel", {
			Name = "Tag",
			BackgroundColor3 = Theme.colors.gold,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, CASH_TAG_H),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textSmall + 1,
			TextColor3 = Theme.colors.white,
			Text = "",
			Parent = cash,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Create("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }),
		})
		Outline.text(tag, 1.5)
		Outline.border(tag, 2)
		-- the button sizes to its tag
		tag:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			local scale = math.max(Scale.get(), 0.01)
			cash.Size = UDim2.fromOffset(
				math.max(math.ceil(tag.AbsoluteSize.X / scale), Scale.tapHeight(0)),
				self._counterH
			)
		end)
		self._cashTag = tag
	else
		Outline.text(cash, 2.5)
		Outline.border(cash, 3)
	end
	self._cashChip = cash
	table.insert(
		self._connections,
		cash.Activated:Connect(function()
			self:_toggleBoosts()
		end)
	)
	-- #1895: "🐾 A cat is coming! 1m 42s" in the potion timers' row over the money while the account's short first
	-- bait waits (Components/FirstBait), so the player stays and does something else meanwhile
	self._coming = Create("TextLabel", {
		Name = "CatComing",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 28),
		FontFace = Theme.fonts.display,
		TextSize = 18,
		TextColor3 = Theme.colors.gold,
		Text = "",
		LayoutOrder = 80, -- after the Luck chip and the potion timers, before the pals
		Visible = false,
		Parent = self._buffs.frame,
	})
	Outline.text(self._coming, 2)
	-- #2552: the size and visibility handlers above can fire while new() is still building the menu and the corner
	-- pair; the layouts wait for this flag, then run once here
	self._built = true
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
	-- #1572: the day card goes last in the root, so it draws over the goal card and the quest line however the
	-- renderer orders siblings
	self._dayCard.Parent = nil
	self._dayCard.Parent = root
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

-- #1161: the Second Bait Bowl's "2" on the tile; setBait gets the sooner bowl and "!" for either bowl's cat.
function HUD.setBowlCount(self: any, count: number)
	local badge: TextLabel = self._bowlCount
	badge.Visible = count >= 2
end

-- The bowl tile always reads "Bowl" (#1282, Derek 2026-11-04: no countdown on the tile; the Bait bowl window has the
-- timer). A red "!" shows only while a cat waits: the wait is over, or the Tame or Let go card has one. No moon or
-- "Half" either (#1210); the Bait bowl window says the night wait.
function HUD._renderBowl(self: any)
	local bait: Types.BaitView? = self._bait
	local wasReady = self._baitReady
	local ready = bait ~= nil and bait.readyAt - Workspace:GetServerTimeNow() <= 0
	self._baitReady = ready
	local waiting = ready or self._catWaiting == true
	local badge: Frame = self._bowlBadge
	if badge.Visible ~= waiting then
		badge.Visible = waiting
	end
	local style: Button.Style = if waiting then "gold" else "secondary"
	if style ~= self._bowlStyle then
		self._bowlStyle = style
		local bowl: Button.Button = self._bowl
		bowl:setStyle(style)
	end
	if ready and not wasReady and self._bowlSlot.Visible then
		Tween.popIn(self._bowlSlot, 0.9)
	end
	-- #1895: the first bait's cue, moved on with the bowl's once-a-second loop
	local coming: TextLabel? = self._coming
	if coming then
		local line = FirstBait.chip(bait, Workspace:GetServerTimeNow())
		-- #2447 (Derek2 11-08: "remove the cat is coming text from the middle top for mobile"): never on touch; the
		-- bowl's own timer still counts down
		local shown = line ~= nil and not TOUCH
		if shown and not coming.Visible then
			Tween.popIn(coming, 0.7)
		end
		coming.Text = if line then "🐾 " .. line else ""
		coming.Visible = shown
		self._buffs:setLead(shown, "coming")
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
-- #2331: the rank up card opened (from the goal card or anywhere else)
function HUD.goalSeen(self: any)
	self._goal:seen()
end

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
	if TOUCH then
		-- #2393: the catch's strip and header take the top middle while it runs, so the counters and Luck row step
		-- away (and their cards close)
		self._counters.Visible = not active
		self._buffs:setHidden(active)
		if active then
			self:_hideBoosts()
			self._luck:hide()
		end
	end
	self:_layoutBottom()
	self:_renderTutorialTile()
	if changed then
		self.catchingChanged:Fire(active)
	end
end

-- #1893: RoadmapStep(n) from the server: the strip's dot pops gold (the toast is the UI's)
function HUD.roadmapStep(self: any, n: number)
	self._roadmap:pop(n)
end

-- #2464 (Derek2 11-08: "remove the purrrfect text from top as that squishes the buttons especially mobile"): the
-- "🐾 Purrfect x3" streak label is gone, so the top row keeps its place; the PURRFECT! banner over the catch stays
function HUD.setCatchStreak(_self: any, _streak: number) end

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

-- #2211 (crispi_255: "highlight the x for tutorial/steps for a couple seconds after finishing the tutorial"): the
-- Tutorial tile's red × gets a gold ring and bounces for HIDE_PULSE_SECONDS (holding still under Reduce Motion), then
-- goes back to how it was. Once at a time.
-- #2411 (Derek2: "the highlight to remove the tutorial/tips after finishing tutorial is missing"): the tutorial often
-- ends mid-moment (a catch, a cut, a window), when the pulse played unseen or not at all; it now waits up to
-- HIDE_WAIT_SECONDS for the tile to be on screen with no catch, and a gold "Hide tips" tag beside the tile points at it.
function HUD._hideFree(self: any): boolean
	return self._tutorialTile.instance.Visible == true
		and self.screenGui.Enabled == true
		and self._catching ~= true
end

function HUD.pulseHide(self: any)
	local dot: Frame = self._hideDot
	if dot:FindFirstChild("Pulse") or self._hideWaiting then
		return
	end
	if not self:_hideFree() then
		self._hideWaiting = true
		task.spawn(function()
			local waitUntil = os.clock() + HIDE_WAIT_SECONDS
			while os.clock() < waitUntil and dot.Parent ~= nil and not self:_hideFree() do
				task.wait(0.25)
			end
			self._hideWaiting = false
			if dot.Parent ~= nil and self:_hideFree() then
				self:pulseHide()
			end
		end)
		return
	end
	local scale: UIScale = Create("UIScale", { Name = "Pulse", Parent = dot })
	local ring: Frame = Create("Frame", {
		Name = "PulseRing",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 6, 1, 6),
		ZIndex = 9,
		Parent = dot,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIStroke", { Color = Theme.colors.gold, Thickness = 3 }),
	})
	if not GuiService.ReducedMotionEnabled then
		TweenService:Create(scale, HIDE_BOUNCE, { Scale = 1.35 }):Play()
	end
	Sound.play("uiHint")
	-- #2411: a gold "Hide tips ×" tag beside the tile, pointing at the × while it pulses
	local hint: TextLabel = label({
		Name = "HideHint",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(0, -2, 0.5, 0),
		Size = UDim2.fromOffset(0, HIDE_HINT_H),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.colors.gold,
		BackgroundTransparency = 0,
		TextColor3 = Theme.colors.ink,
		TextSize = Theme.sizes.textSmall,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Hide tips with ×",
		ZIndex = 9,
		Parent = dot.Parent, -- the × button: left of the ×, on its line
	})
	Create("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = hint })
	Create(
		"UIPadding",
		{ PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = hint }
	)
	Outline.border(hint, 2)
	task.delay(HIDE_PULSE_SECONDS, function()
		scale:Destroy()
		ring:Destroy()
		hint:Destroy()
	end)
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
	-- #2211: the tutorial's last step done just now (not a player who finished it before this join): the × pulses
	local step = state.tutorialStep or TUTORIAL_DONE
	local before: number? = self._stepBefore
	self._stepBefore = step
	if before ~= nil and before < TUTORIAL_DONE and step >= TUTORIAL_DONE then
		self:pulseHide()
	end
	-- #1796: the Upgrades tile glows while the tutorial asks for a table or the Bait bowl
	-- on the square alone: round the whole tile it covered the "Upgrades" label under it (device pass 2026-11-07)
	TutorialGlow.set(
		self._upgradesTile.face,
		TutorialHints.upgrade(state.tutorialStep, state.upgradeLevels) ~= nil
	)
	-- F102: the Trade tile from the live minimum tier, with the rest of the full HUD, once TradeService runs (it sets
	-- the Workspace's TradingOn; while that is false the window says trading is resting)
	-- #2462: shown greyed below the minimum tier, so new players see what Tier 3 brings
	local tradeMin = TradeLogic.minTier(Workspace:GetAttribute("TradeMinTier"))
	self._tradeMin = tradeMin
	self._tradeTile.instance.Visible = self:_open("invite")
		and Workspace:GetAttribute("TradingOn") ~= nil
	self._tradeTile:setEnabled(TradeLogic.shown(state.tier, tradeMin))

	-- money with a little green flash for a lump (a sale, a tip, a reward), not for the steady income ticks (#1026)
	self._moneyText.Text = Format.money(state.money)
	self._moneyRoom.Text = moneyShape(self._moneyText.Text)
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
	-- #1919: "Find N more cats" while the Grand Opening's twelve cats step is next
	local nudge = if catalog then IndexHints.nudge(catalog, state) else nil
	self._goalArea = if nudge then nudge.area else nil
	self._goal:render(
		tierProgress,
		Format.tier(state.tier, if catalog then catalog.tiers else nil),
		if nudge then nudge.text else nil
	)
	if not self:_open("goal") then
		self._goal.frame.Visible = false
	end
	-- uiRankReady chimes once per tier, the first time that tier's requirements are all met
	if tierProgress and tierProgress.ready and self._chimedTier ~= tierProgress.tier then
		self._chimedTier = tierProgress.tier
		Sound.play("uiRankReady")
	end
	-- #1893: the Grand Opening strip (Components/RoadmapLogic), open as the roadmapOpen setting says
	local settings: any = state.settings
	if
		self._roadmapOpen == nil
		and type(settings) == "table"
		and type(settings.roadmapOpen) == "boolean"
	then
		self._roadmapOpen = settings.roadmapOpen
	end
	self._roadmap:render(RoadmapLogic.view(state :: any), self._roadmapOpen == true)
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
		-- #1676: its right edge 2 px past the side like the red dot, so the tighter columns keep it off the next key cap
		Position = UDim2.new(1, 2, 0, 2),
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

-- The bowl tile shows in the left menu once the Bait bowl upgrade is owned; the grid lays out again round it.
function HUD._renderBowlSlot(self: any, state: Types.PlayerState)
	local shown = (state.upgradeLevels.lure_bowl or 0) >= 1
	if self._bowlSlot.Visible ~= shown then
		self._bowlSlot.Visible = shown
		self:_layoutMenu()
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
		if self._tutorial.Text ~= text then
			self._tutorial.TextWrapped = false
			self._tutorial.Text = text
			self:_wrapTutorial(text)
		end
		self._tutorial.Visible = true
	else
		self._tutorial.Visible = false
	end
	self:_layoutBottom()
end

-- One row while the line fits the strip's widest box, two when it is longer. GetTextBoundsAsync yields, so the
-- answer lands a moment later and only while the strip still shows this line.
function HUD._wrapTutorial(self: any, text: string)
	local strip: TextLabel = self._tutorial
	task.spawn(function()
		local ok, bounds = pcall(function()
			local params = Instance.new("GetTextBoundsParams")
			params.Text = text
			params.Font = strip.FontFace
			params.Size = strip.TextSize
			params.Width = 100000 -- no wrap
			return game:GetService("TextService"):GetTextBoundsAsync(params)
		end)
		if ok and bounds and strip.Text == text then
			strip.TextWrapped = bounds.X > TUTORIAL_W - 2 * 18
			self:_layoutBottom()
		end
	end)
end

-- Bottom up: the bottom row, the carry banner, then the tutorial strip, each above the ones showing below it.
-- #2529: on touch the running potions' chips stand over the Potions tile, left of the bottom row; where they reach under
-- the carry banner (a phone), what the bottom centre stacks rises over them.
function HUD._chipsLift(self: any): number
	local buffs = self._buffs
	if not TOUCH or buffs == nil or self._corner == nil or not buffs.potions.Visible then
		return 0
	end
	local scale = Scale.get()
	local width = if scale > 0 and self._root.AbsoluteSize.X > 0
		then self._root.AbsoluteSize.X / scale
		else Scale.DESIGN.X
	local at = self._corner.Position
	local chipsRight = at.X.Scale * width + at.X.Offset
	if chipsRight + Theme.sizes.gap <= width / 2 - CARRY_W / 2 then
		return 0
	end
	return BuffChips.potionsHeight() + Theme.sizes.gap
end

function HUD._layoutBottom(self: any)
	local y = -MARGIN
	if self._travelRow.Visible and not self._travelFolded then
		y -= TRAVEL_H + Theme.sizes.gap
	end
	y -= self:_chipsLift()
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
	y -= self:_chipsLift()
	if self._carry.Visible then
		y -= CARRY_H + Theme.sizes.gap
	end
	if self._tutorial.Visible then
		y -= self._tutorial.AbsoluteSize.Y / Scale.get() + Theme.sizes.gap
	end
	return y
end

-- #2338 (Laptop-Tester, iPhone SE: the Welcome back toast lay over the menu tiles): what the toasts (Screens/Toasts) keep
-- clear of, as boxes in design pixels from the screen's top left: the left column (the menu grid, the Store tile, the
-- arrow tab and the chips beside it on a short screen), the right one (the goal card, and the quest and free spin
-- lines by their words, which sit right-aligned in wider boxes), the chips over the counters and the corner tiles over
-- the bottom right. Measured, so a folded menu or a hidden card counts as
-- nothing; none while the HUD is hidden.
function HUD.toastAvoid(self: any): { Types.Box }
	local scale = Scale.get()
	local boxes: { Types.Box } = {}
	if scale <= 0 or not self.screenGui.Enabled then
		return boxes
	end
	local origin = self._root.AbsolutePosition
	local function add(x0: number, y0: number, x1: number, y1: number)
		if x1 > x0 and y1 > y0 then
			table.insert(boxes, {
				x0 = (x0 - origin.X) / scale,
				y0 = (y0 - origin.Y) / scale,
				x1 = (x1 - origin.X) / scale,
				y1 = (y1 - origin.Y) / scale,
			})
		end
	end
	local function box(parts: { GuiObject })
		local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
		for _, part in parts do
			if part.Visible and part.AbsoluteSize.X > 0 then
				x0 = math.min(x0, part.AbsolutePosition.X)
				y0 = math.min(y0, part.AbsolutePosition.Y)
				x1 = math.max(x1, part.AbsolutePosition.X + part.AbsoluteSize.X)
				y1 = math.max(y1, part.AbsolutePosition.Y + part.AbsoluteSize.Y)
			end
		end
		add(x0, y0, x1, y1)
	end
	local left: { GuiObject } = { self._menu, self._storeTile.instance, self._menuFold.instance }
	local buffsOwn = self._buffsLow or TOUCH -- over the counters, or under them at the top middle on touch (#2393)
	if not buffsOwn then
		table.insert(left, self._buffs.frame)
	end
	box(left)
	if buffsOwn then
		box({ self._buffs.frame })
	end
	if TOUCH then
		box({ self._counters }) -- #2393: the top middle
		box({ self._moneyBadge }) -- under the money (#2533)
	end
	box({ self._goal.frame })
	box({ self._corner }) -- the Potions tile, bottom right (left of the bottom row on touch, #2529)
	-- a line's words: each label's text, from its right edge when right-aligned
	for _, line in { self._spinLine } :: { GuiObject } do
		if line.Visible then
			local labels: { Instance } = line:GetDescendants()
			table.insert(labels, line)
			for _, label in labels do
				if
					(label:IsA("TextLabel") or label:IsA("TextButton"))
					and label.Visible
					and label.Text ~= ""
				then
					local x1 = label.AbsolutePosition.X + label.AbsoluteSize.X
					local x0 = if label.TextXAlignment == Enum.TextXAlignment.Right
						then x1 - label.TextBounds.X
						else label.AbsolutePosition.X
					add(
						x0,
						label.AbsolutePosition.Y,
						x1,
						label.AbsolutePosition.Y + label.AbsoluteSize.Y
					)
				end
			end
		end
	end
	return boxes
end

-- Day and night clock. nil hides it. The countdown runs on Workspace:GetServerTimeNow(), the server's
-- synchronised epoch clock, so it compares with the server's os.time() in PhaseEndsAt and never trusts
-- the device clock (data-model section 1, reviewer S16). In the last DUSK_SECONDS of a day it reads "Night in 0:12"
-- in orange (F66). F60: when night falls on an empty bowl, the bowl tile pops beside the night bait toast.
function HUD.setClock(self: any, clock: Types.ClockState?)
	self:_stopClock()
	self._clockState = clock
	if not clock then
		self._clock.Visible = false
		self._nightTips.Visible = false
		self._luckyLine.Visible = false
		self._luckyRow.Visible = false
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

-- "Lucky Day in 2 days" after the luck chip's clover under the clock while the clock shows; the phase is the clock's own.
function HUD._renderLuckyLine(self: any)
	local view: LuckLogic.DayView? = self._luckyDay
	local clock: Types.ClockState? = self._clockState
	local line: string? = nil
	if view ~= nil and clock ~= nil then
		local today: LuckLogic.DayView = {
			day = view.day,
			luckyDay = view.luckyDay,
			goldenDay = view.goldenDay,
			rainbowDay = view.rainbowDay,
			phase = clock.phase,
		}
		line = LuckLogic.dayLine(today)
		self._dayCardText.Text = table.concat(LuckLogic.dayCard(today), "\n")
	end
	self._luckyLine.Text = line or "" -- the clover is the circle in front (LuckChip.circle) on a Lucky Day
	self._luckyClover.Visible = view ~= nil and view.luckyDay == true
	self._luckyLine.Visible = line ~= nil and self._clock.Visible
	self._luckyRow.Visible = self._luckyLine.Visible
	if not self._luckyLine.Visible then
		self._dayCard.Visible = false
	end
end

-- #1572: the day line's card, open or shut.
function HUD._toggleDayCard(self: any)
	self._dayCard.Visible = not self._dayCard.Visible and self._luckyLine.Visible
	if not self._dayCard.Visible then
		return
	end
	-- #1572: the pity lines count down each second while the card stays open
	local token = {}
	self._pityToken = token
	self:_paintPity()
	task.spawn(function()
		while true do
			task.wait(1)
			if
				self._pityToken ~= token
				or not self._dayCard.Visible
				or self._dayCard.Parent == nil
			then
				return
			end
			self:_paintPity()
		end
	end)
end

function HUD._paintPity(self: any)
	local t = Workspace:GetServerTimeNow() - Config.ClockEpoch
	self._dayPity.Text = table.concat(PityLogic.lines(PityLogic.view(t, PityLogic.current())), "\n")
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

-- #2487: the Cafe Event chip's lines (EventLogic.chip), nil to hide it; kind "running" paints it gold.
function HUD.setEvent(self: any, lines: { string }?, kind: string?)
	local text = if lines ~= nil and #lines > 0 then table.concat(lines, "\n") else nil
	local key = if text ~= nil then (kind or "") .. "|" .. text else nil
	if key == self._event then
		return
	end
	self._event = key
	local line: TextLabel = self._eventLine
	local nextLine: TextLabel = self._eventNext
	line.Text = if lines ~= nil and lines[1] ~= nil then lines[1] else ""
	line.TextColor3 = if kind == "running" then Theme.colors.gold else Theme.colors.white
	-- #2539 (Laptop-Tester): not tied to the clock, which the small HUD hides until tutorial step 5, so a new player
	-- sees the event too
	line.Visible = text ~= nil
	nextLine.Text = if lines ~= nil and lines[2] ~= nil then lines[2] else ""
	nextLine.Visible = line.Visible and nextLine.Text ~= ""
	self:_layoutRight()
end

-- F101: the potion timers' row. On a phone it sits level with the menu's top, where a long row (Luck, potions,
-- pals) can reach the top centre; the Rally banner moves down under it then.
function HUD.buffRow(self: any): GuiObject
	return self._buffs.frame
end

function HUD.counterRow(self: any): GuiObject
	return self._counters
end

-- F88: the Luck chip shows with luck above 1x (the chip itself always shows since #1150, so the first boost), for
-- the `luck` context tip.
function HUD.luckShown(self: any): boolean
	return self._luck:isShown() and self._luck:isBoosted()
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
	self._luckyRow.Position = UDim2.new(1, -MARGIN, 0, top - 6 - lift)
	self._dayCard.Position = UDim2.new(1, -MARGIN, 0, top - 6 - lift + NIGHT_LINE + 4)
	if self._luckyLine.Visible then
		top += NIGHT_LINE
	end
	-- F101: the Rescue Rally countdown under those
	self._rallyLine.Position = UDim2.new(1, -MARGIN, 0, top - 6 - lift)
	if self._rallyLine.Visible then
		top += NIGHT_LINE
	end
	-- #2487: the Cafe Event chip under those, and its next shower line
	self._eventLine.Position = UDim2.new(1, -MARGIN, 0, top - 6 - lift)
	if self._eventLine.Visible then
		top += NIGHT_LINE
	end
	self._eventNext.Position = UDim2.new(1, -MARGIN, 0, top - 6 - lift)
	if self._eventNext.Visible then
		top += NIGHT_LINE
	end
	self._goal.frame.Position = UDim2.new(1, -MARGIN, 0, top - lift)
	local goal = self._goal.frame
	local lineTop = if goal.Visible then top + goal.Size.Y.Offset + Theme.sizes.gap else top
	-- #1893: the Grand Opening strip under the goal card, the free spin line under it
	local roadmap: TextButton = self._roadmap.frame
	local stripTop = lineTop - lift
	if roadmap.Visible and self._roadmapOpen == true then
		-- open on a short screen (a phone turned sideways): the list rises over the goal card so all eight steps fit
		local parent = roadmap.Parent
		local screenH = if parent and parent:IsA("GuiObject")
			then parent.AbsoluteSize.Y / math.max(Scale.get(), 0.01)
			else math.huge
		local room = screenH - MARGIN - roadmap.Size.Y.Offset
		stripTop = math.max(MARGIN, math.min(stripTop, room))
	end
	roadmap.Position = UDim2.new(1, -MARGIN, 0, stripTop)
	if roadmap.Visible then
		lineTop += self._roadmap:closedHeight() + Theme.sizes.gap
	end
	self._spinLine.Position = UDim2.new(1, -MARGIN, 0, lineTop - lift)
	local giftTop = if self._spinLine.Visible then lineTop + SPIN_LINE_H + 2 else lineTop
	self._giftLine.Position = UDim2.new(1, -MARGIN, 0, giftTop - lift)
	if TOUCH and self._corner ~= nil then
		self:_placePotionTimers() -- #2393: the money badge keeps clear of the column
	end
end

-- #2614: a Mystery gift waits on this player's plot in the `tier` wrap ("common", "rare", "super"), or nil when none
-- does. The line takes the wrap's colour; it pops in once when a gift appears.
local GIFT_COLOR: { [string]: Color3 } = {
	common = Theme.colors.cream,
	rare = Theme.colors.sky,
	super = Theme.colors.gold,
}
function HUD.setGift(self: any, tier: string?)
	if tier == self._giftTier then
		return
	end
	local was = self._giftTier
	self._giftTier = tier
	local line: TextLabel = self._giftLine
	if tier == nil then
		line.Visible = false
		return
	end
	line.Text = Theme.icons.gifts .. " " .. GiftLogic.chip(tier)
	line.TextColor3 = GIFT_COLOR[GiftLogic.tier(tier)]
	line.Visible = true
	if was == nil then
		Tween.popIn(line, 0.8)
	end
	self:_layoutRight()
end

-- F73: the Quests pill (shown once ProfileSync has quests) with its count of what is ready to claim.
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
end

-- F49: the free spin line shows while today's free spin waits (SpinLogic.freeDue), once ProfileSync has the spin
-- state and the tutorial is done. Spinning sends a new state, which hides it; a timer shows it again at 00:00 UTC.
-- #2358: and while banked spins wait ("🎡 3 spins at the Town Square", SpinLogic.line), with the red "!" in front.
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
	local line = SpinLogic.line(spin, now)
	local due = line ~= nil
	if line ~= nil then
		self._spinText.Text = Theme.icons.spin .. " " .. line
	end
	-- #2397 (Derek2 11-08: "for mobile remove the free spin at town square"): never on touch; the wheel's own "!"
	-- still shows in the world
	local shown = due and not TOUCH
	if shown and not self._spinLine.Visible then
		Tween.popIn(self._spinLine, 0.8)
	end
	self._spinLine.Visible = shown
	if not SpinLogic.freeDue(spin, now) then
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
	self:_liftTop()
end

-- #2447 (Derek2 11-08: "move all the other ui you put in the middle of screen to be against the top of screen the
-- money/gold fish/luck", 15:17: "it should just be able to move these into this little bar between chat and
-- tutorial"): on touch the counters (top middle since #2393) and the Luck and pal row go side by side into Roblox's top
-- bar, centred in its free stretch between Roblox's chat button and the HUD's icon row. When the pair doesn't fit
-- there (a narrow phone, a long amount), they keep #2393's place: the counters at the top middle, the row under them.
function HUD._counterTop(self: any): number
	return self._counterY or MARGIN
end

function HUD._liftTop(self: any)
	if not TOUCH then
		return
	end
	local counters: GuiObject = self._counters
	local root: Frame = self._root
	local inset = GuiService.TopbarInset
	local scale = Scale.get()
	local buffs = self._buffs
	local row: GuiObject? = if buffs ~= nil then buffs.frame else nil
	local rowW = if row ~= nil and row.Visible then row.AbsoluteSize.X else 0
	local fits, alone = false, false
	local x, top = 0, MARGIN
	if scale > 0 and inset.Height > 0 and root.AbsoluteSize.X > 0 then
		-- in screen pixels: the root's left edge (GUI space starts under the top bar inset), the free stretch from
		-- Roblox's buttons to the icon row
		local origin = root.AbsolutePosition.X + GuiService:GetGuiInset().X
		local icons: GuiObject = self._icons
		local left = inset.Min.X + TOP_GAP * scale
		local right = math.min(inset.Max.X, icons.AbsolutePosition.X + GuiService:GetGuiInset().X)
			- TOP_GAP * scale
		local gap = if rowW > 0 then TOP_GAP * scale else 0
		local width = counters.AbsoluteSize.X + gap + rowW
		if width <= right - left then
			fits = true
			x = (left + (right - left - width) / 2 - origin) / scale
			-- the bar sits over the root's top, so the counters are centred in it at a negative Y
			top = -(inset.Max.Y / scale + self._counterH) / 2
		elseif counters.AbsoluteSize.X <= right - left then
			-- #2712 (Derek2 11-09: "fix this reoccuring issue of currencys being shoved down on mobile"): a chip that
			-- makes the pair too wide no longer takes the counters out of the bar; they stay, and the row goes under them
			alone = true
			x = (left + (right - left - counters.AbsoluteSize.X) / 2 - origin) / scale
			top = -(inset.Max.Y / scale + self._counterH) / 2
		end
	end
	self._counterY = top
	local under = top + self._counterH + BUFFS_GAP -- the boosts card's top, and the row's when it is not beside
	if alone then
		counters.AnchorPoint = Vector2.new(0, 0)
		counters.Position = UDim2.fromOffset(x, top)
		local middle = x + counters.AbsoluteSize.X / scale / 2
		if buffs ~= nil then
			buffs:place(UDim2.fromOffset(middle, under), Vector2.new(0.5, 0))
		end
		local boosts: GuiObject? = self._boosts
		if boosts then
			boosts.Position = UDim2.fromOffset(middle, under)
		end
		self:_placeMoneyBadge()
		return
	end
	if fits then
		counters.AnchorPoint = Vector2.new(0, 0)
		counters.Position = UDim2.fromOffset(x, top)
		if buffs ~= nil then
			local rowH = if row ~= nil then row.AbsoluteSize.Y / scale else self._counterH
			buffs:place(
				UDim2.fromOffset(
					x + (counters.AbsoluteSize.X + TOP_GAP * scale) / scale,
					top + (self._counterH - rowH) / 2
				),
				Vector2.new(0, 0)
			)
		end
	else
		counters.AnchorPoint = Vector2.new(0.5, 0)
		counters.Position = UDim2.new(0.5, 0, 0, top)
		if buffs ~= nil then
			buffs:place(UDim2.new(0.5, 0, 0, under), Vector2.new(0.5, 0))
		end
	end
	local boosts: GuiObject? = self._boosts
	if boosts then
		boosts.Position = UDim2.new(0.5, 0, 0, under)
	end
	self:_placeMoneyBadge()
end

-- #2533 (Derek2: "move the 2x cash below the money on mobile/ipad even if its slightly towards middle of your screen
-- where it currently is is too close to net/takcle button"): on touch the money badge hangs right under the money, left
-- edges level, under the Luck row too when that sits under the counters (_liftTop). It was under the goal card (#2499)
-- or over the Potions tile (#2393), both near the Net and Tackle buttons.
function HUD._placeMoneyBadge(self: any)
	local badge: GuiObject? = self._moneyBadge
	local counters: GuiObject? = self._counters
	local scale = Scale.get()
	if not TOUCH or badge == nil or counters == nil or scale <= 0 then
		return
	end
	local root: Frame = self._root
	local left = (counters.AbsolutePosition.X - root.AbsolutePosition.X) / scale
	if counters.AnchorPoint.X > 0 then
		-- centred at the top middle: work it out from the position just set, in case the frame has not moved yet
		left = root.AbsoluteSize.X / scale / 2 - counters.AbsoluteSize.X / scale / 2
	elseif counters.Position.X.Scale == 0 then
		left = counters.Position.X.Offset
	end
	local top = self:_counterTop() + self._counterH + BUFFS_GAP
	local buffs = self._buffs
	local row: GuiObject? = if buffs ~= nil then buffs.frame else nil
	if row ~= nil and row.Visible and row.AnchorPoint.X > 0 then
		-- the Luck row under the counters (they did not fit in Roblox's top bar)
		top += row.AbsoluteSize.Y / scale + BUFFS_GAP
	end
	badge.AnchorPoint = Vector2.new(0, 0)
	badge.Position = UDim2.fromOffset(math.floor(left), math.floor(top))
end

-- Red dots: a screen's dot shows while it has a key the player has not seen on that screen. Keys seen while
-- the screen is open count as seen, so buying the next level in the shop does not light the dot again. Since #2345
-- the Upgrades dot is simpler: it shows while any upgrade's next level can be bought (Components/UpgradeReady).
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
		-- #2345 (Derek2: "add an exclamation mark to the upgrades if something is available to buy that you can
		-- afford"): the Upgrades "!" stays while any next level is affordable, opened or not
		local show = if screen == "Collection"
			then indexReady > 0
			elseif screen == "Upgrades" then #keys > 0
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

-- The Rewards tile: shown while it holds anything; "Rewards" and a red "!" of what waits (gifts ready, plus one for
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
	-- "Rewards" with the red "!" while anything waits (Derek's 11-04 HUD mockup, #1176), else the time to the next gift
	local text = if ready > 0
		then "Rewards"
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
	-- a red "!" rather than a count (#1074, Derek: "should show a red exclamation mark as it's easier")
	self._rewardsCount.Text = "!"
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

-- #2462: a tap on the greyed Trade tile says which tier opens it, in a small dark pill under the tile for
-- TRADE_NOTE_SECONDS; a second tap restarts it.
function HUD._tradeLockedNote(self: any)
	local tile: GuiObject = self._tradeTile.instance
	local root: Frame = self._root
	local old: Instance? = root:FindFirstChild("LockedNote")
	if old then
		old:Destroy()
	end
	-- on the root, over the goal card under the icon row, centred under the tile
	local scale = math.max(Scale.get(), 0.01)
	local x = (tile.AbsolutePosition.X + tile.AbsoluteSize.X / 2 - root.AbsolutePosition.X) / scale
	local y = (tile.AbsolutePosition.Y + tile.AbsoluteSize.Y - root.AbsolutePosition.Y) / scale + 4
	local note: TextLabel = Create("TextLabel", {
		Name = "LockedNote",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(x, y),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 26),
		BackgroundColor3 = Theme.colors.ink,
		BackgroundTransparency = 0.1,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall + 1,
		TextColor3 = Theme.colors.gold,
		Text = TradeLogic.lockedText(self._tradeMin or TradeLogic.minTier(nil)),
		ZIndex = 30,
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
	})
	Outline.text(note, 1.5)
	Tween.popIn(note, 0.8)
	task.delay(TRADE_NOTE_SECONDS, function()
		if note.Parent ~= nil then
			note:Destroy()
		end
	end)
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
		-- a gift waiting shows the red "!" on the row (#1074), not "1 ready"
		return if summary and summary.ready > 0
			then "Gifts"
			elseif nextIn ~= nil then "Next gift " .. TipJarLogic.clock(nextIn)
			else "Gifts"
	elseif id == "Daily" then
		return "Daily treat"
	elseif id == "Invite" then
		return "Invite friends"
	end
	return id
end

-- Whether a list row has something to claim: it wears the red "!" (#1074).
function HUD._popReady(self: any, id: string): boolean
	if id == "Gifts" then
		local summary: { ready: number, nextIn: number?, left: number }? = self._gift
		return summary ~= nil and summary.ready > 0
	elseif id == "Daily" then
		return self._dailyDue == true
	end
	return false
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
		local badge = claimBadge(button.instance, 23)
		badge.Visible = self:_popReady(row.id)
		self._popBadges[row.id] = badge
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
		local badge: Frame? = self._popBadges[id]
		if badge then
			badge.Visible = self:_popReady(id)
		end
	end
end

function HUD._closePop(self: any)
	self._popFor = nil
	self._pop.Visible = false
	for _, button in self._popRows do
		button:destroy()
	end
	table.clear(self._popRows)
	table.clear(self._popBadges)
end

-- #1770 owner test mode: a small calm label at the top middle for the owner's account only (the text from
-- shared/OwnerTest.LABEL), so a screenshot or a playtest never mistakes a free grant for a real purchase; nil hides it.
function HUD.setOwnerTest(self: any, label: string?)
	local tag: TextLabel? = self._ownerTag
	if label == nil then
		if tag then
			tag.Visible = false
		end
		return
	end
	if tag == nil then
		local made: TextLabel = Create("TextLabel", {
			Name = "OwnerTest",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 4),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 22),
			BackgroundColor3 = Theme.colors.cocoaDeep,
			BackgroundTransparency = 0.2,
			FontFace = Theme.fonts.bodyBold,
			TextSize = Theme.sizes.textSmall,
			TextColor3 = Theme.colors.gold,
			ZIndex = 5,
			Parent = self._root,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
		})
		self._ownerTag = made
		tag = made
	end
	local shown = tag :: TextLabel
	shown.Text = label
	shown.Visible = true
end

-- The gold Store tile at the top of the left menu (Derek 2026-11-02: "store still needs to be added"): shown with
-- the function that opens the Store window, hidden with nil. init's Store block calls it as soon as the window exists,
-- passes on sale or not (#1167); hidden, the grid closes up (review N341: moved here).
function HUD.setStore(self: any, open: (() -> ())?)
	self._storeOpen = open
	local tile: Button.Button = self._storeTile
	local shown = open ~= nil
	if tile.instance.Visible ~= shown then
		tile.instance.Visible = shown
		self:_layoutMenu()
	end
end

-- #1823 §4: the Store tile's New dot, while any Store tab has one (init's Store block, Screens/Store.hasNew).
function HUD.setStoreNew(self: any, shown: boolean)
	local dot: Frame = self._storeNew
	dot.Visible = shown
end

-- #1646: the Cafe Pass tile in the left menu, shown with the function that opens the Pass window while a season runs
-- and hidden with nil (the grid closes up), with a red "!" while rewards are ready to claim. No badge for the season's
-- end (cafe-pass.md section 1).
function HUD.setPass(self: any, open: (() -> ())?, ready: number)
	self._passOpen = open
	local tile: Button.Button = self._passTile
	local shown = open ~= nil
	if tile.instance.Visible ~= shown then
		tile.instance.Visible = shown
		self:_layoutMenu()
	end
	local badge: Frame = self._passBadge
	badge.Visible = shown and ready > 0
end

-- From the modal's changed signal: opening a screen marks what it shows as seen and clears its dot. The Index has
-- no keys (its dot is the waiting rewards, in _renderDots), so it is left alone here.
function HUD.screenOpened(self: any, name: string?)
	self._openScreen = name
	if name then
		self:_hideBoosts() -- a window over the world closes the money's card
		self._luck:hide() -- and the Luck card (F88)
		self._dayCard.Visible = false -- and the day line's card (#1572)
		self:_closePop() -- and the Rewards or Menu list
	end
	local candidates: Notices.Candidates? = self._candidates
	if name and candidates and (candidates :: any)[name] then
		Notices.markSeen((candidates :: any)[name], self._seen[name])
		local dot: Frame? = self._dots[name]
		if dot and name ~= "Upgrades" then -- #2345: Upgrades' "!" goes when nothing is affordable, not when opened
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

-- #1606: the money pass badge (StoreLogic.moneyBadge): "3x" in gold once owned, a berry "Get 2x" pill while not, or
-- hidden with nil. #1936: a quiet badge (the first 30 minutes of play) has no price line and does not pulse.
function HUD.setMoneyBadge(
	self: any,
	badge: {
		text: string,
		owned: boolean,
		price: string?,
		quiet: boolean?,
		id: number?,
	}?
)
	local button: TextButton = self._moneyBadge
	self._moneyBadgeId = if badge ~= nil and not badge.owned then badge.id else nil
	-- #1962: an owned multiplier shows as the side chip, not beside the money
	local chip: TextButton = self._cashChip
	local owned = badge ~= nil and badge.owned
	chip.Visible = owned
	if badge ~= nil and owned then
		local said = (badge.text:gsub("^(%d+)x$", "x%1"))
		local tag: TextLabel? = self._cashTag
		if tag then
			tag.Text = "💰 " .. said -- #2447: the small tag beside the money on touch
		else
			chip.Text = "💰 Cash " .. said
		end
	end
	self._buffs:setLead(owned and not TOUCH, "cash")
	button.Visible = badge ~= nil and not owned
	-- #2254 (Derek2 11-07: "gold fish is hovering wrong now if you did already buy the 2x/3x/4x money"): the golden
	-- fish sits a normal gap after the amount with or without the badge (since #2383 the money's room is its shape's)
	if badge == nil or owned then
		self:_pulseMoneyBadge(false)
		return
	end
	self._moneyBadgeOwned = badge.owned
	local pill: TextLabel = self._moneyPill
	local sell = not badge.owned
	pill.Text = badge.text
	pill.Size = UDim2.fromOffset(0, if sell then CASH_H else MONEY_BADGE_H)
	pill.TextSize = if sell then CASH_TEXT else MONEY_BADGE_TEXT
	pill.TextColor3 = if sell then Theme.colors.white else Theme.colors.gold
	-- #1759: a rainbow pill (white under the gradient) while for sale, bare gold words once owned
	pill.BackgroundColor3 = Theme.colors.white
	pill.BackgroundTransparency = if sell then 0 else 1
	local rainbow = pill:FindFirstChild("Rainbow") :: UIGradient?
	if rainbow then
		rainbow.Enabled = sell
	end
	local price: TextLabel = self._moneyPrice
	local line = if sell and not badge.quiet then badge.price else nil
	price.Visible = line ~= nil
	if line ~= nil then
		-- "Only" in green, the price in white, as in Derek2's reference
		price.Text = (line:gsub("^Only", '<font color="#7CFC6A">Only</font>'))
	end
	self:_pulseMoneyBadge(sell and not badge.quiet)
end

-- #1759: the for-sale badge grows and shrinks a little, over and over; it holds still once owned or with Reduce
-- Motion on.
function HUD._pulseMoneyBadge(self: any, on: boolean)
	local want = on and not GuiService.ReducedMotionEnabled
	local tween: Tween? = self._moneyPulseTween
	if want == (tween ~= nil) then
		return
	end
	if tween then
		tween:Cancel()
		self._moneyPulseTween = nil
		self._moneyPulse.Scale = 1
		return
	end
	local info = TweenInfo.new(
		CASH_PULSE_SECONDS,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut,
		-1,
		true
	)
	local made = TweenService:Create(self._moneyPulse, info, { Scale = CASH_PULSE })
	made:Play()
	self._moneyPulseTween = made
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
		-- over the counters, or under them at the top middle on touch (#2393)
		AnchorPoint = if TOUCH then Vector2.new(0.5, 0) else Vector2.new(0, 1),
		Position = if TOUCH
			then UDim2.new(0.5, 0, 0, self:_counterTop() + self._counterH + BUFFS_GAP)
			else UDim2.new(0, MARGIN, 1, -(MARGIN + self._counterH + BUFFS_GAP)),
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
	-- #2621 (Derek2: "make the cats earning offline obvious ... without it being to obnoxious"): one quiet line on what
	-- time away pays, the Long Nap pass's when owned
	-- one line; on touch it takes the place of "Tap to close", so the card is no taller under the counters (#2393)
	self._boostsAway = label({
		Name = "Away",
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.colors.gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = WelcomeBack.away(nil),
		LayoutOrder = 5,
		ZIndex = 6,
		Parent = list,
	})
	label({
		Name = "Hint",
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = Theme.sizes.textTiny,
		TextColor3 = Theme.hud.subtext,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Tap to close",
		Visible = not TOUCH,
		LayoutOrder = 6,
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

-- #1151 (Derek 11-04: "a very small symbol beside each boost"): each row's picture from the clean set, so the big
-- boosts are easy to spot; no new uploads. A row with no picture (the total) has none.
local BOOST_GLYPH: { [string]: string } = {
	tables = "💺", -- #2015: 💺 and 🌿, as 🪑 and 🪴 draw blank
	espresso = "☕",
	golden_espresso = "☕",
	decor = "🌿",
	index = "📖",
	tier = "⭐",
	pals = "👋",
	passes = "⭐", -- #1624: VIP and the cafe theme passes
	outfits = "🎀", -- #1624: Cat Accessories and Uniform Styles
	outfit_accessories = "🎀", -- #2147: each outfit pass by name
	outfit_uniforms = "👕",
	moneyPass = "💰",
}
local function boostPicture(key: string): string?
	if key == "tables" then
		return ShopIcons.hud("Home")
	elseif key == "espresso" then
		return ShopIcons.menu("coffee")
	elseif key == "golden_espresso" then
		return Theme.textures.fishCoin -- a Golden Fish Market perk
	elseif key == "decor" then
		return ShopIcons.hud("Decor")
	elseif key == "index" then
		return ShopIcons.hud("Index")
	elseif key == "tier" then
		return ShopIcons.hud("Upgrades")
	elseif key == "pals" then
		return ShopIcons.clean("Invite")
	end
	return ShopIcons.potion(key) -- a running money potion's row is keyed by its potion id
end

function HUD._renderBoosts(self: any)
	local state: Types.PlayerState? = self._state
	if state == nil then
		return
	end
	self._boostsExact.Text = Theme.currencySymbol .. Format.commas(math.floor(state.money))
	self._boostsRate.Text = Format.rate(state.incomePerSecond)
	self._boostsAway.Text = WelcomeBack.away((state :: any).longNap == true)
	-- the money ticks five times a second while income flows (UIController's prediction), and each tick renders the
	-- HUD; the rows are made again only when what they say changed
	-- #2147: which outfit passes Roblox says are owned, so the money card names each one
	local ownedPasses = PassShop.owned()
	local outfits: BoostList.Outfits = {
		accessories = ownedPasses[Config.CatAccessoriesPassId or 0] == true,
		uniforms = ownedPasses[Config.UniformStylesPassId or 0] == true,
	}
	local rows =
		BoostList.rows(self._catalog, state, Workspace:GetServerTimeNow(), #self._palIds, outfits)
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
	-- #1624: the pass rows make a long list, so past BOOST_ROWS_TIGHT rows the grey +0% rows go and each row is a
	-- little shorter, and the card stays clear of Roblox's buttons at the top of a phone
	local tight = #rows > BOOST_ROWS_TIGHT
	if tight then
		local kept = {}
		for _, row in rows do
			if row.active then
				table.insert(kept, row)
			end
		end
		rows = kept
	end
	-- #2147: each outfit pass has its own row now, so the longest list (every pass, potions and pals) is one row
	-- longer; past BOOST_ROWS_SNUG rows each row gives up two more pixels so the card still clears Roblox's buttons
	local rowH = if #rows > BOOST_ROWS_SNUG
		then BOOST_ROW_H - 7
		elseif tight then BOOST_ROW_H - 5
		else BOOST_ROW_H
	for order, row in rows do
		local total = row.kind == "total"
		local frame: Frame = Create("Frame", {
			Name = row.key,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, if total then rowH + 8 else rowH),
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
		local picture = if total then nil else boostPicture(row.key)
		local iconW = if total then 0 else rowH
		if not total then
			local icon = label({
				Name = "Icon",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 0, 1, 0),
				Size = UDim2.fromOffset(rowH - 2, rowH - 2),
				TextSize = Theme.sizes.textSmall,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTransparency = if row.active then 0 else 0.4,
				Text = BOOST_GLYPH[row.key] or (if picture then "" else "•"),
				ZIndex = 6,
				Parent = frame,
			})
			if picture then
				IconArt.setImage(icon, picture, 1.1)
				IconArt.setTransparency(icon, if row.active then 0 else 0.4)
			end
		end
		label({
			Name = "Name",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, iconW + 2, 1, 0),
			Size = UDim2.new(0.68, -(iconW + 2), 0, rowH),
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
			Size = UDim2.new(0.32, 0, 0, rowH),
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
-- counters when the screen is too narrow for it to sit in the middle; and the Potions symbol.
function HUD._layoutMenu(self: any)
	if not self._built then
		return -- #2552: still being built (new() lays it out once it is)
	end
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
	local storeH = if store.Visible and not TOUCH then STORE_H + STORE_GAP else 0 -- on touch it is in the grid
	self._menuFold.instance.Visible = shown > 0 or store.Visible -- no tab to fold an empty menu (F87)
	local foldUnder = FOLD_UNDER + FOLD_H
	local bandBottom = height - MARGIN - self._counterH - gap
	local buffsH = BuffChips.rowHeight()
	-- (the zone is screen pixels; the layout is design units, so it is divided by the scale)
	local thumbTop = height - THUMB_ZONE / (if scale > 0 then scale else 1)
	-- the grid's height with this many tiles a row, the Store over it and ROW_GAP between the rows (#1210)
	local function gridH(columns: number): number
		local rows = math.ceil(shown / columns)
		return storeH + rows * MENU_CELL_H + math.max(0, rows - 1) * ROW_GAP
	end
	local columns = MENU_COLUMNS
	local roomy = bandBottom - (buffsH + BUFFS_GAP) - MARGIN >= gridH(columns) + foldUnder
	if TOUCH and MARGIN + gridH(columns) > thumbTop then
		roomy = false
	end
	if not roomy and math.ceil(shown / columns) >= 3 then
		-- a short screen keeps the gaps and takes more tiles a row instead (it used to close the gaps, and the tiles'
		-- outlines and key caps ran into each other, #1210): three, then four while the grid would reach the
		-- counters, or the thumbstick on touch
		columns = MENU_COLUMNS_SHORT
		while
			columns < MENU_COLUMNS_MAX
			and math.ceil(shown / (columns + 1)) < math.ceil(shown / columns)
			and (
				MARGIN + gridH(columns) > bandBottom
				or (TOUCH and MARGIN + gridH(columns) > thumbTop)
			)
		do
			columns += 1
		end
	end
	local rows = math.ceil(shown / columns)
	local spaces = math.max(0, rows - 1)
	self._menuLayout.FillDirectionMaxCells = columns
	local menuW = menuWidth(columns)
	if roomy then
		if not TOUCH then
			self._buffs:place(
				UDim2.new(0, MARGIN, 1, -(MARGIN + self._counterH + BUFFS_GAP)),
				Vector2.new(0, 1)
			)
		end
		bandBottom -= buffsH + BUFFS_GAP
	end
	local band = bandBottom - MARGIN
	local menuH = rows * MENU_CELL_H + spaces * ROW_GAP -- the grid alone, under the Store
	self._menu.Size = UDim2.fromOffset(menuW, menuH)
	local block = storeH + menuH + (if roomy then foldUnder else 0)
	-- a short screen (a phone) keeps the grid up at the top, clear of Roblox's thumbstick in the bottom left
	self._menuTop = if roomy then MARGIN + math.max(0, math.floor((band - block) / 2)) else MARGIN
	self._gridTop = self._menuTop + storeH
	self._foldBeside = not roomy
	-- the luck, potion and pal chips stay just over the counters on a short screen too, when they fit under the grid
	-- (Derek 2026-11-02: "the luck on mobile should be moved somewhere better"); else they go beside the arrow tab
	self._buffsLow = roomy or MARGIN + storeH + menuH + gap <= bandBottom - (buffsH + BUFFS_GAP)
	if TOUCH then
		-- #2393: under the counters at the top middle, wherever the menu goes
		self:_liftTop()
	elseif self._buffsLow and not roomy then
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
	-- #2334: the money badge sits after the golden fish now, so the counters' measured width counts too (the badge
	-- ran under My Cafe on a small phone); CORNER_W keeps the row still while the money grows
	local row: Frame? = self._travelRow
	if row then
		local rowW = row.Size.X.Offset
		local counters: Frame = self._counters
		local reach = if scale > 0
			then math.max(CORNER_W, counters.AbsoluteSize.X / scale)
			else CORNER_W
		if TOUCH then
			-- #2529: on touch the counters are at the top; the Potions tile and the arrow tab sit left of the row
			reach = SYMBOL + TRAVEL_GAP + FOLD_W
		end
		self._travelShift = math.max(0, MARGIN + reach + gap - (width / 2 - rowW / 2))
		row.Position = UDim2.new(
			0.5,
			self._travelShift,
			1,
			if self._travelFolded then TRAVEL_H + 24 else -MARGIN
		)
		self._travelFold.instance.Position = if TOUCH
			then UDim2.new(0.5, self._travelShift - rowW / 2 - TRAVEL_GAP - FOLD_W, 1, -MARGIN)
			else UDim2.new(0.5, self._travelShift + rowW / 2 + TRAVEL_GAP, 1, -MARGIN)
	end
	self:_placeCorner()
end

-- The Potions symbol sits in the bottom right corner on a PC (the bowl moved to the left menu, #1210).
-- #2529 (Derek2: "move potions and the dropdown menu to the left of the my cafe button on mobile so more space for
-- moving screen around on right side"): on touch it sits on the bottom edge left of the bottom row's arrow tab, which
-- sits left of My Cafe, so the bottom right is left to the thumb that turns the camera (and to jump, Net and Tackle).
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
	local row: Frame? = self._travelRow
	if not TOUCH or row == nil then
		holder.Position = UDim2.new(1, -MARGIN, 1, -MARGIN)
		return
	end
	-- the arrow tab's left edge (_layoutMenu), whether the row is folded or not: the tab stays put
	local right = -row.Size.X.Offset / 2 + self._travelShift - TRAVEL_GAP - FOLD_W - TRAVEL_GAP
	holder.Position = UDim2.new(0.5, math.floor(right), 1, -MARGIN)
end

-- The running potions' chips (#963, Derek 2026-11-03: "can show active like this screenshot"): beside the Potions
-- tile, left of the corner pair with their tops level with its squares; when that would run into the bottom row (the
-- pair on the bottom edge of a narrow screen) they sit over the pair instead, right edges level.
function HUD._placePotionTimers(self: any)
	if not self._built then
		return -- #2552: still being built (_layoutMenu places them once it is)
	end
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
	local tiles = false
	for _, child in holder:GetChildren() do
		if child:IsA("GuiObject") and child.Visible then
			tiles = true
		end
	end
	-- #2396: with no tile showing yet (the Potions tile comes later) the chips take its place, right edges level
	local left = if tiles then right - holder.Size.X.Offset - CORNER_GAP else right
	local timersW = if scale > 0 then timers.AbsoluteSize.X / scale else 0
	local beside = true
	local row: Frame? = self._travelRow
	if row and row.Visible and not self._travelFolded then
		local rowRight = width / 2 + self._travelShift + row.Size.X.Offset / 2 + TRAVEL_GAP + FOLD_W
		local rowTop = height - MARGIN - TRAVEL_H
		local low = top + BuffChips.potionsHeight() > rowTop
		beside = not low or left - timersW >= rowRight + Theme.sizes.gap
	end
	if TOUCH then
		-- #2529: over the Potions tile left of the bottom row, right edges level (in its place before it shows)
		beside = not tiles
	end
	if beside then
		timers.AnchorPoint = Vector2.new(1, 0)
		timers.Position = UDim2.fromOffset(math.floor(left), math.floor(top))
	else
		timers.AnchorPoint = Vector2.new(1, 1)
		timers.Position = UDim2.fromOffset(math.floor(right), math.floor(top - Theme.sizes.gap))
	end
	if TOUCH then
		self:_placeMoneyBadge()
		if self._carry ~= nil and self._tutorial ~= nil then
			self:_layoutBottom() -- #2529: the carry banner over the chips while they run
		end
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
		local x = if self._menuFolded then MARGIN else MARGIN + self._menu.Size.X.Offset + MENU_GAP
		local middle = self._gridTop + menuH - MENU_CELL_H / 2
		fold.Position = UDim2.fromOffset(x, middle - FOLD_H / 2)
		if not self._buffsLow and not TOUCH then
			self._buffs:place(UDim2.fromOffset(x + FOLD_W + 12, middle), Vector2.new(0, 0.5))
		end
	else
		fold.Position = UDim2.fromOffset(MARGIN, self._gridTop + menuH + FOLD_UNDER)
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
