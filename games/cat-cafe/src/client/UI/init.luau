--!strict
-- Cat cafe UI entry point. Public API for the engineer's client controller.
-- See docs/design/cat-cafe/ui-contract.md. The UI is a view: it renders the state it is given and raises
-- events for what the player tapped. It never changes money or ownership and never fires remotes.
--
--   local UI = require(script.Parent.UI) -- from the client controller
--   UI.init({ catalog = Catalog })
--   UI.update(partialState)
--   UI.events.buyUpgrade:Connect(function(upgradeId) Remotes.BuyUpgrade:FireServer(upgradeId) end)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ActionPill = require(script.Screens.ActionPill)
local AreaTitle = require(script.Screens.AreaTitle)
local Areas = require(script.Screens.Areas)
local AskCard = require(script.Screens.AskCard)
local BaitBowl = require(script.Screens.BaitBowl)
local BaitCard = require(script.Screens.BaitCard)
local BugReport = require(script.Screens.BugReport)
local BugReportLogic = require(script.Components.BugReportLogic)
local CafeSigns = require(script.Screens.CafeSigns)
local Cannon = require(script.Screens.Cannon)
local CannonCard = require(script.Screens.CannonCard)
local CannonLogic = require(script.Components.CannonLogic)
local CatCard = require(script.Screens.CatCard)
local CatCollection = require(script.Screens.CatCollection)
local CatVariant = require(script.Components.CatVariant)
local CatWhistle = require(script.Components.CatWhistle)
local CatchCircles = require(script.Screens.CatchCircles)
local CatchPrompt = require(script.Screens.CatchPrompt)
local ClientErrors = require(script.Components.ClientErrors)
local Codes = require(script.Screens.Codes)
local Collector = require(script.Screens.Collector)
local Create = require(script.Components.Create)
local DailyTreat = require(script.Screens.DailyTreat)
local DailyTreatLogic = require(script.Components.DailyTreatLogic)
local Dealer = require(script.Screens.Dealer)
local DecorShop = require(script.Screens.DecorShop)
local FishMarket = require(script.Screens.FishMarket)
local Format = require(script.Components.Format)
local FreshCatchBoard = require(script.Screens.FreshCatchBoard)
local FreshCatchLogic = require(script.Components.FreshCatchLogic)
local GateSigns = require(script.Screens.GateSigns)
local GuideTrail = require(script.Components.GuideTrail)
local HUD = require(script.Screens.HUD)
local IndexBoards = require(script.Screens.IndexBoards)
local Intro = require(script.Screens.Intro)
local IntroLogic = require(script.Components.IntroLogic)
local LocationMarkers = require(script.Screens.LocationMarkers)
local Modal = require(script.Components.Modal)
local Moments = require(script.Parent.Moments)
local Motion = require(script.Components.Motion)
local MyCats = require(script.Screens.MyCats)
local NetButton = require(script.Screens.NetButton)
local NetGlow = require(script.Components.NetGlow)
local NightClock = require(script.Components.NightClock)
local Popups = require(script.Screens.Popups)
local PotionLogic = require(script.Components.PotionLogic)
local Potions = require(script.Screens.Potions)
local Quests = require(script.Screens.Quests)
local RankUp = require(script.Screens.RankUp)
local RescueBar = require(script.Screens.RescueBar)
local RichTip = require(script.Screens.RichTip)
local Scale = require(script.Scale)
local Settings = require(script.Screens.Settings)
local SettingsList = require(script.Components.SettingsList)
local Signal = require(script.Components.Signal)
local Sound = require(script.Components.Sound)
local SpinWheel = require(script.Screens.SpinWheel)
local TackleBar = require(script.Screens.TackleBar)
local TackleLogic = require(script.Components.TackleLogic)
local Theme = require(script.Theme)
local TillTipsButton = require(script.Screens.TillTipsButton)
local TipCard = require(script.Screens.TipCard)
local TipJar = require(script.Screens.TipJar)
local TipQueue = require(script.Components.TipQueue)
local Toasts = require(script.Screens.Toasts)
local Types = require(script.Types)
local UpgradeShop = require(script.Screens.UpgradeShop)
local Wayfinding = require(script.Components.Wayfinding)
local WorldMarker = require(script.Components.WorldMarker)
local WorldTags = require(script.Screens.WorldTags)

local UI = {}
UI.together = {} -- F92 playing together, filled at the end of the file
UI.campExtras = {} -- F100 camp extras, filled at the end of the file
UI.rally = {} -- F101 Rescue Rally, filled at the end of the file
UI.trade = {} -- F102 trading, filled at the end of the file
UI.lawn = {} -- F91 the front lawn's edit view, filled at the end of the file
UI.nursery = {} -- #1200 the Garden Nursery's window, filled at the end of the file
UI.store = {} -- the Store window behind the HUD's Store tile, filled at the end of the file

UI.Types = Types
UI.Theme = Theme
UI.Format = Format

-- Intents from the player. The controller forwards them to remotes; the server validates.
UI.events = {
	buyUpgrade = Signal.new(), -- (upgradeId)
	buyDecor = Signal.new(), -- (decorId)
	toggleDecor = Signal.new(), -- (decorId, placed: boolean)
	-- F91 front lawn (front-lawn.md section 3): forward as BuyLawn, SetLawnSpot and SetLawnStyle
	buyLawn = Signal.new(), -- (id, spotId?)  a piece or style; a piece onto spotId, else the first free spot
	setLawnSpot = Signal.new(), -- (spotId, pieceId)  "" clears the spot
	setLawnStyle = Signal.new(), -- (kind: "path" | "fence", id)  "" lays Grey Slabs or takes the fence down
	buyLure = Signal.new(), -- (lureId)
	placeCat = Signal.new(), -- (uid, spotId)
	unplaceCat = Signal.new(), -- (uid)
	sellCat = Signal.new(), -- (uid)
	lockCat = Signal.new(), -- (uid, locked)   the Lock row in the cat room: forward as LockCat (F62)
	renameCat = Signal.new(), -- (uid, name)   Rename in the cat room, trimmed and checked with Shared.CatName: forward as RenameCat (F33)
	equipBest = Signal.new(), -- ()   server places the highest-rated cats on the open spots
	equipBestDecor = Signal.new(), -- ()   Equip Best on the Decor page: forward as EquipBestDecor (#828)
	unequipAll = Signal.new(), -- ()   Unequip All in the cat room: every working cat rests; forward as UnequipAll
	claimOffline = Signal.new(), -- ()
	grabBegan = Signal.new(), -- (strayId, catId)   via catch.bindProximityPrompts
	rescueBegan = Signal.new(), -- (rescueSpotId, catId)   a press on a stuck cat's prompt: forward as RescueBegin
	-- (strayId, catId)   the hold on a dropped cat's Pick up prompt (PickUp = true): forward as PickUpCat (v0.8 F56,
	-- v0.10 F67)
	pickUpBegan = Signal.new(),
	rescuePressed = Signal.new(), -- (rescueSpotId)   a press on the rescue bar or its catch circle: forward as RescuePress (F27)
	rescueCancelled = Signal.new(), -- (rescueSpotId)   Give up on the rescue bar: forward as RescueCancel (F27)
	screenOpened = Signal.new(), -- (name or nil)
	-- design v0.3
	catchPressed = Signal.new(), -- (strayId, index, grade?)   a press on circle `index` with this device's grade (nil after its first Miss): forward strayId and index as CatchPress
	rankUp = Signal.new(), -- ()   Rank up pressed on the card with every requirement met: forward as RankUp
	travel = Signal.new(), -- (destination)   "home" or an AreaId from the travel row or Areas panel: forward as Travel
	-- (lureId, bowl)   Use on a food in the Bait bowl screen: forward as UseLure (F28); bowl 1 or 2 (#1161)
	useLure = Signal.new(),
	-- (choice, bowl)   "tame" or "letgo" from the bait card: forward as ResolveBait, for that bowl's cat (#1161)
	resolveBait = Signal.new(),
	-- (index, lureId, window)   Buy on the night dealer screen (F32): forward lureId and window as BuyDealerFood (F59);
	-- index is the food's row, unused since F59, and window the DealerStock's the screen showed (nil if none came)
	buyDealerFood = Signal.new(),
	claimRichTip = Signal.new(), -- ()   Collect on the rich tip marker over your cafe: forward as ClaimRichTip (F31)
	-- design v0.5
	tackle = Signal.new(), -- ()   the Tackle button or Q: lunge and forward as Tackle (F74, no target)
	netSwing = Signal.new(), -- ()   the Net button on a touch screen (F93): swing, as a click in the world or R2 (NetSwingController)
	-- 2026-10-27 HUD v3
	dropCat = Signal.new(), -- ()   Drop on the carry banner or G while carrying: forward as DropCat
	-- 2026-10-27 wave 2
	claimTipJar = Signal.new(), -- (step)   Claim on a ready Tip Jar gift: forward as ClaimTipJar (F47)
	claimIndexReward = Signal.new(), -- (areaId, milestoneId)   Claim on an Index reward card: forward as ClaimIndexReward (F48)
	spinWheel = Signal.new(), -- ()   Spin on the Spin Wheel window: forward as SpinWheel (F49)
	spinAll = Signal.new(), -- ()   Use all on the Spin window (#1078): forward as SpinAll
	openCrate = Signal.new(), -- (crateId)   Open on a Golden Fish Market crate card: forward as OpenCrate (F53)
	buyCrateBundle = Signal.new(), -- (crateId)   Buy 5 on a Market crate card: forward as BuyCrateBundle (#1051)
	buyFishItem = Signal.new(), -- (itemId)   Buy on a Market treat or perk row: forward as BuyFishItem (F53)
	buyFreshCatch = Signal.new(), -- (itemId, window?)   Buy on a Fresh Catch row: forward as BuyFreshCatch (F94)
	setSetting = Signal.new(), -- (key, value)   a Settings switch (boolean) or volume (0 to 1, on release): forward as SetSetting (Audio follows UI.settings.changed)
	reportBug = Signal.new(), -- (text, kind, clientErrors)   Send on Report a bug (trimmed text, "bug" | "stuck" | "idea", up to 3 client error lines): forward all three as ReportBug
	redeemCode = Signal.new(), -- (code)   Redeem in the code box (letters and digits, at most CodeMaxLength): forward as RedeemCode (F65)
	-- F72 intro: (shot)   Skip or gamepad B, once per play, with the shot showing (1 to Intro.SHOTS); end the intro, call
	-- UI.intro.finish and fire IntroDone(shot, replay)
	introSkip = Signal.new(),
	-- ()   the HUD's Tutorial tile or Settings' Replay tutorial: play the intro again with UI.intro.start({ replay = true })
	introReplay = Signal.new(),
	-- F64
	usePotion = Signal.new(), -- (potionId)   Use on a potion in the potion bag: forward as UsePotion
	-- F61
	collectTips = Signal.new(), -- ()   the till's Collect (F61); unbound since F97 pays tip piles on arrival
	-- F73
	claimQuest = Signal.new(), -- (kind, slot)   Claim on a finished quest, kind "daily" or "weekly": forward as ClaimQuest
	rerollQuest = Signal.new(), -- (kind, slot)   Swap on an unfinished quest (the free reroll): forward as RerollQuest
	claimAchievement = Signal.new(), -- (achievementId)   Claim on a met achievement: forward as ClaimAchievement
	claimAll = Signal.new(), -- (what)   Claim all: "quests" (all three Quests tabs, #1073; or "daily", "weekly", "achievements"; Config.QuestClaimAll), "index" (the Index window, Config.IndexClaimAll) or "tipjar" (the Tip Jar, Config.TipJarClaimAll): forward as ClaimAll
	-- F63
	answerCollector = Signal.new(), -- (accept)   Trade (true) or No thanks (false) on the Cat Collector's card: forward as AnswerCollector
	-- F70
	claimDailyTreat = Signal.new(), -- ()   Claim on the Daily Treat card's day that is due: forward as ClaimDailyTreat
	-- F84
	launchCannon = Signal.new(), -- (cannonId, destination)   Launch on a Cat Cannon card: forward as LaunchCannon
	collectCampExtra = Signal.new(), -- (extraId)   #1463: Collect on the cannon picker's pond strip (Golden Pond
	-- owners): forward as CollectCampExtra
	-- F87 (easy-start.md sections 3 and 6): a context tip shown (skipped true when its camera cut was skipped), and
	-- Settings' "Show tips again"
	tipSeen = Signal.new(), -- (id, skipped?)   a shared/Tips id (or like_ask) shown: forward as TipSeen
	clearTips = Signal.new(), -- ()   Show tips again in Settings: forward as ClearTips
	sendFeedback = Signal.new(), -- (face, chip?)   one answer on the feedback faces (Tips.FACES, Tips.CHIPS): forward as SendFeedback
	-- F87 (easy-start.md sections 2g and 5), analytics only: where the intro was played from, and each stuck nudge
	tutorialClosed = Signal.new(), -- ()   #1273: the Tutorial tile's red X, analytics only: forward as TelemetryReport("tutorial_closed")
	introChoice = Signal.new(), -- (from)   "tile" (the Tutorial tile) or "help" (Show me on Need a hand?): forward as TelemetryReport("intro_choice", from)
	stuckNudge = Signal.new(), -- (kind)   "pulse", "help_shown" or "show_me": forward as TelemetryReport("stuck_nudge", kind)
	-- F96 (starter-cat.md section 2): the Bellhop Cat's stand card
	claimStarterCat = Signal.new(), -- ()   Take me home: forward as ClaimStarterCat
	joinGroup = Signal.new(), -- ()   Join the group (only once the game has a group): GroupService:PromptJoinAsync(Config.GroupId)
	-- F100 (camp-extras.md section 3)
	buyYardSale = Signal.new(), -- (crateId)   Buy on the Yard Sale card: forward as BuyYardSale
	-- (itemId, window, shownPrice, catUid?)   Buy in the Corner Shop (#1052): forward as BuyCornerShop
	buyCornerShop = Signal.new(),
	-- (foodId, catUid)   #1181: Feed a cat from the Bag's Cat Food tab: forward as FeedCat; FeedResult calls UI.bag.fed
	feedCat = Signal.new(),
	-- (hide)   #1083: Settings' "Show my name on the Thank You board" off (true) or on: forward as SetHideCredit
	setHideCredit = Signal.new(),
	-- F102 (trading.md section 6): the client only asks; TradeState answers
	requestTrade = Signal.new(), -- (userId)   Trade on a players list row: forward as TradeRequest
	respondTrade = Signal.new(), -- (requestId, accept)   Accept or Decline on the request card: forward as TradeRespond
	tradeOffer = Signal.new(), -- (tradeId, "add" | "remove", catUid)   forward as TradeOffer
	tradeReady = Signal.new(), -- (tradeId, version, ready)   forward as TradeReady
	tradeConfirm = Signal.new(), -- (tradeId, version)   forward as TradeConfirm
	tradeCancel = Signal.new(), -- (tradeId)   Cancel or the X during a trade: forward as TradeCancel
	-- testers (Derek's notes): Reset on the confirm card of Settings' Reset my save, shown only while the Player
	-- attribute Tester is true
	resetSave = Signal.new(), -- ()   forward as ResetSave; the server checks the tester again, then kicks or toasts
}

local state: Types.PlayerState = {
	money = 0,
	incomePerSecond = 0,
	tier = 1,
	catsOwned = {},
	upgradeLevels = {},
	decorOwned = {},
	decorPlaced = {},
	lures = {},
}

local catById: { [string]: Types.CatDef } = {}
local initialized = false
local visible = true
local connections: { RBXScriptConnection } = {}
local reachConnection: any = nil -- Moments.NetInReach (F93), once NetSwingController fires it

local hud: HUD.HUD? = nil
local modal: Modal.Modal? = nil
local upgrades: UpgradeShop.UpgradeShop? = nil
local decor: DecorShop.DecorShop? = nil
local collection: CatCollection.CatCollection? = nil -- the Index and the Decor Index
local myCats: MyCats.MyCats? = nil -- the Cats screen, its own window since 2026-10-27
local catch: CatchPrompt.CatchPrompt? = nil
local circles: CatchCircles.CatchCircles? = nil
local rescueBar: RescueBar.RescueBar? = nil
local rankUpScreen: RankUp.RankUp? = nil
local areasScreen: Areas.Areas? = nil
local cannonScreen: Cannon.Cannon? = nil -- the Cat Cannon picker (F84, UI.cannon.open)
local cannonCard: CannonCard.CannonCard? = nil -- the destination's name card in the clouds (UI.cannon.flight)
-- F84: the cannon is live (UI.cannon.setEnabled), the player is in a wild area (setWild), the Town Square cannon's
-- part for the hint arrow (setCannon), whether they have flown this session, and the area a rank up to Tier 2
-- opened, hinted until their next flight
local cannonOn = false
local cannonWild = false
local cannonPart: BasePart? = nil
local cannonLaunched = false
local cannonOpened: string? = nil
local hintTier: number? = nil -- the tier in the last update that carried one, to see the rank up to Tier 2
local hintShown: string? = nil -- the cannon hint on screen, so render only redraws the line when it changes
local gateSigns: GateSigns.GateSigns? = nil
local indexBoards: IndexBoards.IndexBoards? = nil -- each area's Index Board (F50), drawn from this player's Index
local areaTitle: AreaTitle.AreaTitle? = nil
local locationMarkers: LocationMarkers.LocationMarkers? = nil -- My Cafe, area and dealer icons that fade up close
local currentZone: string? = nil -- the World.Zones name from UI.setZone, for the dusk banner (F66)
local cafeSigns: CafeSigns.CafeSigns? = nil
local worldTags: WorldTags.WorldTags? = nil
local catCard: CatCard.CatCard? = nil -- the hover card over a cat in any cafe (F75)
local actionPills: ActionPill.ActionPill? = nil -- custom prompts that are not cats (bowl, cart, manhole, Bump)
local richTipScreen: RichTip.RichTip? = nil -- the gold marker over your cafe's rich tip (UI.richTip.bind)
local tillTips: TillTipsButton.TillTipsButton? = nil -- the till's Collect for tip piles (F61, UI.richTip.bind)
local tackleBar: TackleBar.TackleBar? = nil -- the Tackle inside catching areas (UI.shove, F74)
local netButton: NetButton.NetButton? = nil -- the touch Net button inside catching areas (UI.net, F93)
local currentCatalog: Types.Catalog? = nil
local toasts: Toasts.Toasts? = nil
local popups: Popups.Popups? = nil
local carryMarker: WorldMarker.WorldMarker? = nil
local tutorialMarker: WorldMarker.WorldMarker? = nil
local tutorialTrail: GuideTrail.GuideTrail? = nil
local parentGui: Instance? = nil
local baitScreen: BaitBowl.BaitBowl? = nil
local baitCard: BaitCard.BaitCard? = nil
-- The bait bowls (#1161: bowl 1, and bowl 2 with the Second Bait Bowl pass): what is in each (UI.bait.set), the cat at
-- each (UI.bait.showReady) until it is resolved, the bowl the Tame or Let go card shows, and the second bowl's kind
-- ("on", "offer" or nil, UI.bait.setSecond).
local bowls = {
	views = {} :: { [number]: Types.BaitView? },
	cats = {} :: { [number]: Types.BaitCat? },
	card = 1,
	second = nil :: string?,
}
local dealerScreen: Dealer.Dealer? = nil
local cartPart: BasePart? = nil -- the night dealer's cart (UI.dealer.setCart), for the range hint
local settingsScreen: Settings.Settings? = nil -- sound switches and volumes, screen shake and the like (gear in the HUD)
local tipJarScreen: TipJar.TipJar? = nil -- the playtime gifts (F47), opened from the HUD's Gifts tile
local spinScreen: SpinWheel.SpinWheel? = nil -- the Spin Wheel window (F49), opened from the plaza station's prompt
local marketScreen: FishMarket.FishMarket? = nil -- the Golden Fish Market (F53), opened from the stall's prompt
local freshBoard: FreshCatchBoard.FreshCatchBoard? = nil -- the Fresh Catch chalkboard on the stall (F94)
local freshStock: FreshCatchLogic.Stock? = nil -- the last FreshCatchStock, nil at night (F94)
local bugReportScreen: BugReport.BugReport? = nil -- the Feedback window, from the HUD's Feedback tile
local codesScreen: Codes.Codes? = nil -- the code box (F65), opened by walking into the Codes Cat's circle
local potionsScreen: Potions.Potions? = nil -- the potion bag (F64), from the Potions pill, P or a HUD timer
local bagFed: { [string]: number } = {} -- #1181: cat uid -> its level when fed, so FeedResult can tell a level up
local questsScreen: Quests.Quests? = nil -- the Quests window (F73), from the Quests pill, J or the HUD's quest line
local collectorScreen: Collector.Collector? = nil -- the Cat Collector's card and tag (F63, UI.collector.offer)
local dailyTreatScreen: DailyTreat.DailyTreat? = nil -- the Daily Treat card (F70), from the HUD's Daily tile
-- F70: nil until the first Daily Treat card arrives, then whether the window still opens by itself this session (only a
-- stamp due on joining opens it; one that comes due mid-session lights the Daily tile)
local dailyAutoOpen: boolean? = nil
local introScreen: Intro.Intro? = nil -- the intro cutscene's bars, captions and Skip (F72, UI.intro)
local introLive = false -- the intro exists on this server: state.introSeen arrived or UI.intro.start ran
local introGlowed = false -- the Tutorial tile has had its two pulses after a first play
local tutorialButtonOn = true -- the Tutorial button setting as shown (F72)
local tutorialTarget: (BasePart | Attachment | Vector3)? = nil -- UI.tutorial.show's, put back after an intro
local tutorialLabel: string? = nil
local tutorialText: string? = nil -- UI.tutorial.show's line, nil once hidden
local applyTutorial: () -> ()
local tipCard: TipCard.TipCard? = nil -- a context tip's card (F87, UI.tips)
-- the clocks on the Heartbeat (one table, as the module is short of locals): the tip queue and the client-found tips
-- (with UI.tips), and the hint's input switch and the stuck nudges (F87 section 2g)
local ticks: { tips: (dt: number) -> (), nudges: (dt: number) -> () } = {} :: any
local tipsHeldUntil = 0 -- os.clock() until which no tip shows (a cannon flight and its landing)
local askCard: AskCard.AskCard? = nil -- the slide-in asks: the feedback faces (F87 section 4) and Need a hand? (2g)

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
-- data-model section 8: UseLure, Tame and Let go work from anywhere (Derek 2026-10-28: "tame or let go from anywhere";
-- the server dropped BaitResolveRangeStuds in #720), so the bait card's buttons never grey for distance
-- data-model section 8b: BuyDealerFood within 12 studs of the cart
local CART_RANGE: number = Config.DealerRangeStuds

-- Studs from the player's character to a part (their bait bowl, the dealer's cart), or nil when either is unknown.
local function distanceTo(part: BasePart?): number?
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if part == nil or part.Parent == nil or root == nil or not root:IsA("BasePart") then
		return nil
	end
	return ((root :: BasePart).Position - part.Position).Magnitude
end

local function lookupCat(catId: string?): Types.CatDef?
	if not catId then
		return nil
	end
	return catById[catId]
end

local function catalogAreas(): { Types.AreaDef }
	local catalog = currentCatalog
	local areas: { Types.AreaDef }? = if catalog then catalog.areas else nil
	return areas or {}
end

-- F84 (hometown-cannon.md 3a): the cannon hint, from what the UI knows now (Components/CannonLogic.hint).
local function cannonHint(): string?
	local first: string? = nil
	for _, area in catalogAreas() do
		if area.tier <= 1 then
			first = area.name
			break
		end
	end
	return CannonLogic.hint({
		on = cannonOn,
		wild = cannonWild,
		intro = introScreen ~= nil and introScreen:playing(),
		launched = cannonLaunched,
		tier = state.tier or 1,
		tutorialStep = state.tutorialStep or math.huge,
		told = tutorialText ~= nil,
		opened = cannonOpened,
		first = first,
	})
end

-- The tutorial strip, marker and trail: the cannon hint with its arrow at the cannon when it applies, else the
-- controller's onboarding line (UI.tutorial.show). The marker and trail wait out the intro. With the Tutorial tile's
-- × pressed (its setting off) none of them show (Derek 2026-11-03: "Tips from the tutorial still showing even though
-- X is clicked"); the tip cards wait too (pumpTips).
function applyTutorial()
	local hint = cannonHint()
	hintShown = hint
	local text: string? = tutorialText
	local target: (BasePart | Attachment | Vector3)? = tutorialTarget
	local label: string? = tutorialLabel
	if hint ~= nil then
		text, target, label = hint, cannonPart, "Cannon"
	end
	if not tutorialButtonOn then
		text, target = nil, nil
	end
	if hud then
		hud:setTutorial(text)
	end
	if introScreen ~= nil and introScreen:playing() then
		return -- the marker and trail come back when the intro ends
	end
	if tutorialMarker then
		if target ~= nil then
			tutorialMarker:show(target :: any, label or "Go here", Theme.colors.gold)
		else
			tutorialMarker:hide()
		end
	end
	if tutorialTrail then
		if target ~= nil then
			tutorialTrail:show(target :: any)
		else
			tutorialTrail:hide()
		end
	end
end

-- F72: the Tutorial tile shows once the intro is live and while its setting is on; the Settings rows once live.
local function renderTutorialButton()
	if hud then
		hud:setTutorialButton(introLive and tutorialButtonOn)
	end
	if settingsScreen then
		settingsScreen:showTutorial(introLive)
	end
end

-- The intro's end (F72): the HUD, toasts, place icons and popups come back, the tutorial marker and trail return to
-- their target, and after a first play the Tutorial tile glows twice once the bars are out.
local function introEnded(replay: boolean)
	UI.setVisible(true)
	if popups then
		popups:setHeld(false) -- on only if a card waits; never the bare dimmed backdrop
	end
	applyTutorial()
	if not replay and not introGlowed then
		introGlowed = true
		task.delay(IntroLogic.OUT_SECONDS, function()
			if hud then
				hud:glowTutorial()
			end
		end)
	end
end

-- Replaying the intro waits while carrying or during a catch or rescue (the HUD tile greys then too).
local function introBlocked(): boolean
	return (hud ~= nil and hud:isCarrying()) or UI.catch.circlesActive() or UI.rescue.isActive()
end

-- F70: the Daily Treat window opens by itself once when the player joins with a stamp due, after the tutorial and the
-- intro, while no other window is open and nothing is being carried, caught or rescued.
local function autoOpenDailyTreat()
	if dailyAutoOpen == false or state.dailyTreat == nil then
		return
	end
	local view = DailyTreatLogic.view(state.dailyTreat)
	local now = Workspace:GetServerTimeNow()
	if not DailyTreatLogic.due(view, now) then
		dailyAutoOpen = false
		return
	end
	dailyAutoOpen = true
	local windows = modal
	if
		not DailyTreatLogic.autoOpen(view, now, state.tutorialStep)
		or not visible
		or windows == nil
		or windows:current() ~= nil
		or UI.intro.playing()
		or introBlocked()
	then
		return
	end
	dailyAutoOpen = false
	windows:open("DailyTreat")
end

local function render()
	if not initialized then
		return
	end
	if not introLive and state.introSeen ~= nil then
		introLive = true
		renderTutorialButton()
		-- F87 section 2a: the intro no longer plays by itself, so a first join glows the tile that plays it
		if state.introSeen == false and not Config.IntroAutoPlay and not introGlowed then
			introGlowed = true
			task.delay(IntroLogic.OUT_SECONDS, function()
				if hud then
					hud:glowTutorial()
				end
			end)
		end
	end
	if hud then
		hud:render(state)
	end
	if upgrades then
		upgrades:render(state)
	end
	if decor then
		decor:render(state)
	end
	if collection then
		collection:render(state)
	end
	if myCats then
		myCats:render(state)
	end
	if catCard then
		catCard:render(state)
	end
	if rankUpScreen then
		rankUpScreen:render(state)
	end
	if areasScreen and hud then
		areasScreen:render(state, hud:isCarrying())
	end
	if cannonScreen and hud then
		cannonScreen:render(state, hud:isCarrying())
	end
	UI.campExtras.render(state)
	UI.cornerShop.render(state)
	UI.trade.render(state)
	UI.lawn.render(state)
	UI.nursery.render(state)
	UI.store.render()
	if cannonHint() ~= hintShown then
		applyTutorial()
	end
	if gateSigns then
		gateSigns:render(state)
	end
	if indexBoards then
		indexBoards:render(state)
	end
	if locationMarkers and hud then
		locationMarkers:setCarrying(hud:isCarrying())
	end
	if baitScreen then
		baitScreen:render(state)
	end
	if dealerScreen then
		dealerScreen:render(state)
	end
	if settingsScreen then
		settingsScreen:render(state)
		settingsScreen:showTrading(Workspace:GetAttribute("TradingOn") ~= nil) -- F102: once TradeService runs
	end
	if tipJarScreen then
		tipJarScreen:render(state)
	end
	if spinScreen then
		spinScreen:render(state)
	end
	if marketScreen then
		marketScreen:render(state)
	end
	if codesScreen then
		codesScreen:render(state)
	end
	if potionsScreen then
		potionsScreen:render(state)
	end
	if questsScreen then
		questsScreen:render(state)
	end
	if collectorScreen then
		collectorScreen:render(state)
	end
	if dailyTreatScreen then
		dailyTreatScreen:render(state)
	end
	autoOpenDailyTreat()
end

local function setCatalog(newCatalog: Types.Catalog)
	currentCatalog = newCatalog
	table.clear(catById)
	for _, def in newCatalog.cats do
		catById[def.id] = def
	end
	if hud and upgrades and decor and collection then
		hud:setCatalog(newCatalog)
		upgrades:setCatalog(newCatalog)
		decor:setCatalog(newCatalog)
		collection:setCatalog(newCatalog)
	end
	if myCats then
		myCats:setCatalog(newCatalog)
	end
	if rankUpScreen then
		rankUpScreen:setCatalog(newCatalog)
	end
	if areasScreen then
		areasScreen:setCatalog(newCatalog)
	end
	if cannonScreen then
		cannonScreen:setCatalog(newCatalog)
	end
	if gateSigns then
		gateSigns:setCatalog(newCatalog)
	end
	if indexBoards then
		indexBoards:setCatalog(newCatalog)
	end
	if baitScreen then
		baitScreen:setCatalog(newCatalog)
	end
	if dealerScreen then
		dealerScreen:setCatalog(newCatalog)
	end
	if tipJarScreen then
		tipJarScreen:setCatalog(newCatalog)
	end
	if spinScreen then
		spinScreen:setCatalog(newCatalog)
	end
	if marketScreen then
		marketScreen:setCatalog(newCatalog)
	end
	if codesScreen then
		codesScreen:setCatalog(newCatalog)
	end
	if potionsScreen then
		potionsScreen:setCatalog(newCatalog)
	end
	if questsScreen then
		questsScreen:setCatalog(newCatalog)
	end
	if collectorScreen then
		collectorScreen:setCatalog(newCatalog)
	end
	if dailyTreatScreen then
		dailyTreatScreen:setCatalog(newCatalog)
	end
	if popups then
		popups:setCatalog(newCatalog)
	end
	if catCard then
		catCard:setCatalog(newCatalog)
	end
	if toasts then
		toasts:setCatalog(newCatalog) -- the prize toast's pictures
	end
	-- cast: the old solver reads UI.campExtras before its block at the end of the file fills it
	local tradeUi: any = UI.trade -- F102, filled at the end of the file
	tradeUi.setCatalog(newCatalog);
	(UI.campExtras :: any).setCatalog(newCatalog)
end

-- Fill in fields the engineer may not send: tables from upgrade levels, catsOwned from cats.
local function deriveState(partial: Types.PartialState)
	if partial.cats and not partial.catsOwned then
		local counts: { [string]: Types.OwnedCat } = {}
		for _, instance in partial.cats :: { [string]: Types.CatInstance } do
			local entry = counts[instance.catId]
			if entry then
				entry.count += 1
			else
				counts[instance.catId] = { count = 1 }
			end
		end
		state.catsOwned = counts
	end
	if partial.upgradeLevels then
		local levels = partial.upgradeLevels :: { [string]: number }
		local tables: number? = levels.tables
		if partial.tables == nil and tables ~= nil then
			state.tables = tables
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------------------------------------------

function UI.init(config: Types.InitConfig)
	if initialized then
		warn("[CatCafeUI] init called twice; ignoring")
		return UI
	end
	initialized = true
	Scale.start()
	Sound.set(config.playSound)
	ClientErrors.start() -- the newest client errors ride along with a bug report
	-- F93: the stray a swing would land on glows (NetSwingController fires NetInReach; older clients have none)
	local inReach = (Moments :: any).NetInReach
	if inReach ~= nil then
		reachConnection = inReach:Connect(function(model: Model?)
			UI.net.setInReach(model)
		end)
	end

	local player = Players.LocalPlayer
	local parent: Instance = config.parent or player:WaitForChild("PlayerGui")
	parentGui = parent

	local modalInstance = Modal.new(parent)
	modal = modalInstance

	-- the bowl chip and F: a cat at a bowl comes first (bowl 1's, then bowl 2's); otherwise the food screen
	local function openBait()
		local waitingBowl = if bowls.cats[1] then 1 elseif bowls.cats[2] then 2 else nil
		if waitingBowl and baitCard and not baitCard:isShowing() then
			UI.bait.showReady(bowls.cats[waitingBowl] :: Types.BaitCat, waitingBowl)
		else
			modalInstance:toggle("Bait")
		end
	end
	hud = HUD.new(parent, {
		openScreen = function(name: Types.ScreenName)
			modalInstance:toggle(name)
		end,
		travel = function(destination: string)
			UI.events.travel:Fire(destination)
		end,
		openBait = openBait,
		-- the Index pill opens the Index on its cat pages (not the Decor tab), or closes it
		openIndex = function()
			if modalInstance:current() == "Collection" then
				modalInstance:close()
				return
			end
			if collection then
				collection:showTab("Index")
			end
			modalInstance:open("Collection")
		end,
		equipBest = function()
			UI.events.equipBest:Fire()
		end,
		dropCat = function()
			UI.events.dropCat:Fire()
		end,
		replayIntro = function()
			UI.events.introChoice:Fire("tile")
			UI.events.introReplay:Fire()
		end,
		hideTutorialButton = function()
			UI.events.tutorialClosed:Fire() -- #1273: analytics only
			tutorialButtonOn = false
			renderTutorialButton()
			applyTutorial()
			if settingsScreen then
				settingsScreen:set(SettingsList.TUTORIAL_KEY, false)
			end
			UI.toast("Tutorial and tips hidden. Turn them on in Settings.", "info")
		end,
		openFeedback = function()
			UI.bugReport.open() -- F87: the faces page first
		end,
	})
	local hudInstance = hud :: HUD.HUD

	local function closeModal()
		modalInstance:close()
	end
	upgrades = UpgradeShop.new(
		function(upgradeId: string)
			UI.events.buyUpgrade:Fire(upgradeId)
		end,
		closeModal,
		{
			openCatRoom = function()
				UI.openCatRoom()
			end,
			openRankUp = function()
				modalInstance:open("RankUp")
			end,
		}
	)
	decor = DecorShop.new({
		buyDecor = function(decorId: string)
			UI.events.buyDecor:Fire(decorId)
		end,
		toggleDecor = function(decorId: string, placed: boolean)
			UI.events.toggleDecor:Fire(decorId, placed)
		end,
		close = closeModal,
		equipBest = function()
			UI.events.equipBestDecor:Fire()
		end,
		buyLawn = function(id: string, spotId: string?)
			UI.events.buyLawn:Fire(id, spotId)
		end,
		setLawnSpot = function(spotId: string, pieceId: string)
			UI.events.setLawnSpot:Fire(spotId, pieceId)
		end,
		setLawnStyle = function(kind: Types.LawnStyleKind, id: string)
			UI.events.setLawnStyle:Fire(kind, id)
		end,
		editLawn = function()
			UI.lawn.edit()
		end,
	})
	collection = CatCollection.new({
		claimIndexReward = function(areaId: string, milestoneId: string)
			UI.events.claimIndexReward:Fire(areaId, milestoneId)
		end,
		claimAll = function()
			UI.events.claimAll:Fire("index")
		end,
		close = closeModal,
	})
	myCats = MyCats.new({
		placeCat = function(uid: string, spotId: string)
			UI.events.placeCat:Fire(uid, spotId)
		end,
		unplaceCat = function(uid: string)
			UI.events.unplaceCat:Fire(uid)
		end,
		sellCat = function(uid: string)
			UI.events.sellCat:Fire(uid)
		end,
		lockCat = function(uid: string, locked: boolean)
			UI.events.lockCat:Fire(uid, locked)
		end,
		renameCat = function(uid: string, name: string)
			UI.events.renameCat:Fire(uid, name)
		end,
		-- #1181: Feed on the cat's detail, the same FeedCat as the Bag's (its level kept for the level-up toast)
		feedCat = function(foodId: string, uid: string)
			local cat = (state.cats or {})[uid]
			bagFed[uid] = if cat and type(cat.level) == "number" then cat.level else 0
			local events: any = UI.events
			events.feedCat:Fire(foodId, uid)
		end,
		equipBest = function()
			UI.events.equipBest:Fire()
		end,
		unequipAll = function()
			UI.events.unequipAll:Fire()
		end,
		close = closeModal,
	})
	rankUpScreen = RankUp.new({
		rankUp = function()
			UI.events.rankUp:Fire()
		end,
		close = closeModal,
	})
	areasScreen = Areas.new({
		travel = function(areaId: string)
			-- the HUD owns the carrying check and the trip cooldown; close the panel once the trip is asked
			if hudInstance:pressTravel(areaId) then
				modalInstance:close()
			end
		end,
		close = closeModal,
	})
	cannonScreen = Cannon.new({
		launch = function(cannonId: string, destination: string)
			UI.events.launchCannon:Fire(cannonId, destination)
		end,
		-- #1463: a Golden Pond owner's Collect on the Woods strip (UIController sends CollectCampExtra)
		collect = function(extraId: string)
			UI.events.collectCampExtra:Fire(extraId)
		end,
		close = closeModal,
	})
	cannonCard = CannonCard.new(parent)
	-- explicit casts: Luau does not carry nil refinements into the closures below
	local upgradesScreen = upgrades :: UpgradeShop.UpgradeShop
	local decorScreen = decor :: DecorShop.DecorShop
	local collectionScreen = collection :: CatCollection.CatCollection
	local catsScreen = myCats :: MyCats.MyCats
	modalInstance:register("Upgrades", {
		frame = upgradesScreen.frame,
		onOpen = function()
			upgradesScreen:render(state)
		end,
	})
	modalInstance:register("Decor", {
		frame = decorScreen.frame,
		onOpen = function()
			decorScreen:render(state)
		end,
	})
	modalInstance:register("Collection", {
		frame = collectionScreen.frame,
		onOpen = function()
			collectionScreen:render(state)
		end,
	})
	modalInstance:register("Cats", {
		frame = catsScreen.frame,
		onOpen = function()
			catsScreen:reset()
			catsScreen:render(state)
		end,
	})
	local rankUpView = rankUpScreen :: RankUp.RankUp
	modalInstance:register("RankUp", {
		frame = rankUpView.frame,
		onOpen = function()
			rankUpView:render(state)
		end,
	})
	local areasView = areasScreen :: Areas.Areas
	modalInstance:register("Areas", {
		frame = areasView.frame,
		onOpen = function()
			areasView:render(state, hudInstance:isCarrying())
		end,
	})
	local cannonView = cannonScreen :: Cannon.Cannon
	modalInstance:register("Cannon", {
		frame = cannonView.frame,
		onOpen = function()
			cannonView:render(state, hudInstance:isCarrying())
			cannonView:opened()
		end,
		onClose = function()
			cannonView:closed()
		end,
	})
	baitScreen = BaitBowl.new({
		useLure = function(lureId: string, bowl: number)
			UI.events.useLure:Fire(lureId, bowl)
		end,
		openUpgrades = function()
			modalInstance:open("Upgrades")
		end,
		showCat = function(bowl: number)
			local cat = bowls.cats[bowl]
			if cat then
				UI.bait.showReady(cat, bowl)
			end
		end,
		buySecond = function()
			local api: any = UI.bait -- defined further down
			api.buySecond()
		end,
		close = closeModal,
	})
	local baitBowlView = baitScreen :: BaitBowl.BaitBowl
	modalInstance:register("Bait", {
		frame = baitBowlView.frame,
		onOpen = function()
			baitBowlView:openOn() -- #1161: the bowl with a cat, else an empty one
			baitBowlView:render(state)
		end,
	})
	baitCard = BaitCard.new(parent, {
		resolve = function(choice: Types.BaitChoice)
			UI.events.resolveBait:Fire(choice, bowls.card) -- #1161: the bowl whose cat the card shows
		end,
	})
	dealerScreen = Dealer.new({
		buy = function(index: number, lureId: string, window: number?)
			UI.events.buyDealerFood:Fire(index, lureId, window)
		end,
		close = closeModal,
	})
	local dealerView = dealerScreen :: Dealer.Dealer
	modalInstance:register("Dealer", {
		frame = dealerView.frame,
		onOpen = function()
			dealerView:render(state)
		end,
	})
	settingsScreen = Settings.new({
		setSetting = function(key: string, value: boolean | number)
			UI.events.setSetting:Fire(key, value)
		end,
		changed = function(key: string, value: boolean | number)
			if key == "markers" and locationMarkers then
				locationMarkers:setEnabled(value == true)
			elseif key == "screenShake" then
				Motion.screenShake = value == true
			elseif key == SettingsList.TUTORIAL_KEY then
				tutorialButtonOn = value == true
				renderTutorialButton()
				applyTutorial()
			end
			UI.settings.changed:Fire(key, value)
		end,
		close = closeModal,
		openFeedback = function()
			UI.bugReport.open()
		end,
		-- F102: the Trading section, saved as settings.tradeRequests through SetSetting (Gameplay 2026-11-02)
		setTradeRequests = function(mode: string)
			UI.events.setSetting:Fire(SettingsList.TRADE_REQUESTS_KEY, mode)
		end,
		openTrades = function()
			UI.open("TradeLog")
		end,
		-- #1083: "Show my name on the Thank You board"; UIController forwards it as SetHideCredit
		setHideCredit = function(hide: boolean)
			local events: any = UI.events
			events.setHideCredit:Fire(hide)
		end,
		showTipsAgain = function()
			UI.tips.reset()
			UI.events.clearTips:Fire()
			UI.toast("Tips will show again as you play.", "good")
		end,
		replayTutorial = function()
			if introBlocked() then
				Sound.play("uiError")
				UI.toast("Finish carrying or catching first.", "warn")
				return
			end
			modalInstance:close()
			UI.events.introReplay:Fire()
		end,
		resetSave = function()
			UI.events.resetSave:Fire()
		end,
	})
	local settingsView = settingsScreen :: Settings.Settings
	Motion.screenShake = settingsView:value("screenShake")
	tutorialButtonOn = settingsView:value(SettingsList.TUTORIAL_KEY)
	renderTutorialButton()
	modalInstance:register("Settings", {
		frame = settingsView.frame,
		onOpen = function()
			settingsView:render(state)
		end,
		onClose = function()
			settingsView:cancelReset()
		end,
	})
	-- the Testers section follows the Player attribute Tester (ResetSaveService sets it once its check answers)
	local function renderTester()
		settingsView:showTester(player:GetAttribute("Tester") == true)
	end
	table.insert(connections, player:GetAttributeChangedSignal("Tester"):Connect(renderTester))
	renderTester()
	bugReportScreen = BugReport.new({
		send = function(text: string, kind: string, featureName: boolean?)
			UI.events.reportBug:Fire(text, kind, ClientErrors.recent(), featureName)
		end,
		back = closeModal,
		close = closeModal,
		feedback = function(face: string, chip: string?)
			-- an answer here counts as the one ask too (the server sets feedbackAsked), so it never slides in after
			(state :: any).feedbackAsked = true
			UI.events.sendFeedback:Fire(face, chip)
		end,
	})
	local bugReportView = bugReportScreen :: BugReport.BugReport
	modalInstance:register("BugReport", {
		frame = bugReportView.frame,
		onOpen = function()
			bugReportView:onOpen()
		end,
		onClose = function()
			bugReportView:onClose()
		end,
	})
	tipJarScreen = TipJar.new({
		claim = function(step: number)
			UI.events.claimTipJar:Fire(step)
		end,
		claimAll = function()
			UI.events.claimAll:Fire("tipjar")
		end,
		status = function(summary)
			hudInstance:setTipJar(summary)
		end,
		close = closeModal,
	})
	local tipJarView = tipJarScreen :: TipJar.TipJar
	modalInstance:register("TipJar", {
		frame = tipJarView.frame,
		onOpen = function()
			tipJarView:render(state)
		end,
	})
	spinScreen = SpinWheel.new({
		spin = function()
			UI.events.spinWheel:Fire()
		end,
		spinAll = function()
			UI.events.spinAll:Fire()
		end,
		toast = function(text: string)
			if toasts then
				toasts:show(text, "good")
			end
		end,
		close = closeModal,
	})
	local spinView = spinScreen :: SpinWheel.SpinWheel
	modalInstance:register("Spin", {
		frame = spinView.frame,
		onOpen = function()
			spinView:render(state)
		end,
	})
	marketScreen = FishMarket.new({
		openCrate = function(crateId: string)
			UI.events.openCrate:Fire(crateId)
		end,
		buyCrateBundle = function(crateId: string)
			UI.events.buyCrateBundle:Fire(crateId)
		end,
		buyItem = function(itemId: string)
			UI.events.buyFishItem:Fire(itemId)
		end,
		useDecor = function(decorId: string)
			UI.events.toggleDecor:Fire(decorId, true)
		end,
		toast = function(text: string)
			if toasts then
				toasts:show(text, "good")
			end
		end,
		close = closeModal,
		buyFresh = function(itemId: string, window: number?)
			UI.events.buyFreshCatch:Fire(itemId, window)
		end,
		bigPull = function(decorId: string, onUse: (() -> ())?)
			UI.bigPull.piece(decorId, onUse)
		end,
	})
	freshBoard = FreshCatchBoard.new(parent)
	local marketView = marketScreen :: FishMarket.FishMarket
	modalInstance:register("Market", {
		frame = marketView.frame,
		onOpen = function()
			marketView:render(state)
		end,
	})
	codesScreen = Codes.new({
		redeem = function(code: string)
			UI.events.redeemCode:Fire(code)
		end,
		close = closeModal,
	})
	local codesView = codesScreen :: Codes.Codes
	modalInstance:register("Codes", {
		frame = codesView.frame,
		onOpen = function()
			codesView:render(state)
			codesView:onOpen()
		end,
		onClose = function()
			codesView:onClose()
		end,
	})
	potionsScreen = Potions.new({
		use = function(potionId: string)
			UI.events.usePotion:Fire(potionId)
		end,
		feed = function(foodId: string, catUid: string)
			local cat = (state.cats or {})[catUid]
			bagFed[catUid] = if cat and type(cat.level) == "number" then cat.level else 0
			local events: any = UI.events
			events.feedCat:Fire(foodId, catUid)
		end,
		close = closeModal,
	})
	local potionsView = potionsScreen :: Potions.Potions
	modalInstance:register("Potions", {
		frame = potionsView.frame,
		onOpen = function()
			potionsView:render(state)
		end,
	})
	questsScreen = Quests.new({
		claimQuest = function(kind: string, slot: number)
			UI.events.claimQuest:Fire(kind, slot)
		end,
		rerollQuest = function(kind: string, slot: number)
			UI.events.rerollQuest:Fire(kind, slot)
		end,
		claimAchievement = function(achievementId: string)
			UI.events.claimAchievement:Fire(achievementId)
		end,
		claimAll = function(what: string)
			UI.events.claimAll:Fire(what)
		end,
		close = closeModal,
	})
	local questsView = questsScreen :: Quests.Quests
	modalInstance:register("Quests", {
		frame = questsView.frame,
		onOpen = function()
			questsView:render(state)
			questsView:onOpen()
		end,
		onClose = function()
			questsView:onClose()
		end,
	})
	dailyTreatScreen = DailyTreat.new({
		claim = function()
			UI.events.claimDailyTreat:Fire()
		end,
		status = function(shown: boolean, due: boolean)
			hudInstance:setDailyTreat(shown, due)
		end,
		close = closeModal,
	})
	local dailyTreatView = dailyTreatScreen :: DailyTreat.DailyTreat
	modalInstance:register("DailyTreat", {
		frame = dailyTreatView.frame,
		onOpen = function()
			dailyTreatView:render(state)
		end,
	})
	collectorScreen = Collector.new(parent, {
		answer = function(accept: boolean)
			UI.events.answerCollector:Fire(accept)
		end,
		-- walking up to him opens it only when no other window is open; a tap on his tag opens it anyway
		open = function(force: boolean)
			if force or modalInstance:current() == nil then
				modalInstance:open("Collector")
			end
		end,
		close = function()
			if modalInstance:current() == "Collector" then
				modalInstance:close()
			end
		end,
	})
	local collectorView = collectorScreen :: Collector.Collector
	modalInstance:register("Collector", {
		frame = collectorView.frame,
		onOpen = function()
			collectorView:render(state)
			collectorView:onOpen()
		end,
		onClose = function()
			collectorView:onClose()
		end,
	})
	-- range hints: Tame or Let go need the bowl within 20 studs, buying at the cart its range (data-model 8, 8b)
	local nearClock = 0
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function(dt: number)
			nearClock += dt
			if nearClock < 0.25 then
				return
			end
			nearClock = 0
			if dealerScreen then
				local cart = distanceTo(cartPart)
				dealerScreen:setNear(if cart then cart <= CART_RANGE else nil)
			end
		end)
	)
	modalInstance.changed:Connect(function(name: string?)
		hudInstance:screenOpened(name)
		UI.events.screenOpened:Fire(name)
	end)

	catch = CatchPrompt.new(parent)
	circles = CatchCircles.new(parent)
	rescueBar = RescueBar.new(parent)
	actionPills = ActionPill.new(parent)
	richTipScreen = RichTip.new(parent, {
		collect = function()
			UI.events.claimRichTip:Fire()
		end,
		-- only a claimed tip pays (data-model 12 v0.13.4); a missed one leaves with nothing
		collected = function(amount: number, position: Vector3?)
			if position then
				UI.floatText(
					position + Vector3.new(0, 2, 0),
					"+" .. Format.money(amount),
					Theme.colors.gold
				)
			end
			UI.toast("Rich tip! +" .. Format.money(amount), "good")
		end,
		missed = function()
			UI.toast("Rich tip missed", "info")
		end,
	})
	tillTips = TillTipsButton.new(parent, {
		collect = function()
			UI.events.collectTips:Fire()
		end,
	})
	tackleBar = TackleBar.new(parent, {
		tackle = function()
			UI.events.tackle:Fire()
		end,
		-- hidden while carrying or during the circles or the rescue bar (reviewer N85)
		blocked = function()
			return hudInstance:isCarrying() or UI.catch.circlesActive() or UI.rescue.isActive()
		end,
		lift = function()
			return hudInstance:bottomTop()
		end,
	})
	netButton = NetButton.new(parent, {
		swing = function()
			UI.events.netSwing:Fire()
		end,
		blocked = function()
			return UI.catch.circlesActive() or UI.rescue.isActive()
		end,
	})
	toasts = Toasts.new(parent)
	popups = Popups.new(parent)
	tipCard = TipCard.new(parent)
	askCard = AskCard.new(parent, {
		lift = function()
			return hudInstance:bottomTop() - Theme.sizes.gap
		end,
	})
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function(dt: number)
			ticks.tips(dt)
			ticks.nudges(dt)
		end)
	)
	introScreen = Intro.new(parent, {
		skip = function(shot: number)
			UI.events.introSkip:Fire(shot)
		end,
		ended = introEnded,
	})
	carryMarker = WorldMarker.new(parent, "CatCafeCarryMarker")
	tutorialMarker = WorldMarker.new(parent, "CatCafeTutorialMarker")
	-- the Cat Whistle (corner-shop-v2.md section 4): a paw over the nearest stray while its buff runs
	CatWhistle.new(
		WorldMarker.new(parent, "CatCafeWhistleMarker", CatWhistle.REACH),
		function(): boolean
			local buffs: { [string]: number }? = state.buffs
			local endsAt = if buffs then buffs.cat_whistle else nil
			return type(endsAt) == "number" and endsAt > Workspace:GetServerTimeNow()
		end
	)
	tutorialTrail = GuideTrail.new("CatCafeTutorialTrail")
	-- signs over every gate tagged AreaGate, including gates that stream in later
	gateSigns = GateSigns.new(parent)
	-- every area's Index Board, including boards that stream in later; its prompt opens that area's Index page
	require(script.Screens.ThanksBoard).new(parent) -- #1083: the Thank You board's face (no local: init is at Luau's 200)
	indexBoards = IndexBoards.new(parent, {
		open = function(areaId: string)
			UI.openIndex(areaId)
		end,
	})
	-- the icon over My Cafe, fading out up close and smaller far away (the other places' went 2026-10-28)
	local markers = LocationMarkers.new(parent)
	markers:setEnabled(settingsView:value("markers")) -- the map icons switch (My Cafe, Night Market)
	locationMarkers = markers
	areaTitle = AreaTitle.new(parent)
	-- the name sign over every cafe door, rate tags over working cats and order bubbles over customers
	cafeSigns = CafeSigns.new(parent)
	UI.leaderboards.start(parent) -- the town boards' faces and the crowns over heads (F98)
	UI.together.start(parent) -- the Team Rescue pop and the pal chip (F92)
	UI.campExtras.start(parent) -- the Yard Sale card, the Cannon picker's strips and the stations' "!" (F100)
	UI.cornerShop.start() -- the Corner Shop window (#1052)
	UI.rally.start(parent) -- the Rescue Rally banner, the board's face and the clock line (F101)
	UI.trade.start() -- the Trade window in the modal (F102)
	UI.lawn.start(parent) -- the front lawn's edit view (F91)
	UI.nursery.start() -- the Garden Nursery window, opened from its stall's prompt (#1200)
	UI.store.start() -- the Store window and the HUD's Store tile (shown on sale or not, #1167)
	worldTags = WorldTags.new()
	UI.bubbles.start(parent) -- the one-line speech bubbles over the town's key cats (#1079)
	-- the hover card over cats: mouse hover, a tap, or the nearest own cat on gamepad (F75)
	catCard = CatCard.new(parent, {
		blocked = function()
			return not visible or modalInstance:current() ~= nil
		end,
	})

	setCatalog(config.catalog)

	if config.keybinds ~= false then
		table.insert(
			connections,
			UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
				if gameProcessed or not visible then
					return
				end
				local key = input.KeyCode
				if key == Enum.KeyCode.U then
					modalInstance:toggle("Upgrades")
				elseif key == Enum.KeyCode.B then
					modalInstance:toggle("Decor")
				elseif key == Enum.KeyCode.C then
					modalInstance:toggle("Cats")
				elseif key == Enum.KeyCode.P then
					modalInstance:toggle("Potions")
				elseif key == Enum.KeyCode.J and state.quests ~= nil then
					modalInstance:toggle("Quests")
				elseif key == Enum.KeyCode.F then
					openBait()
				elseif key == Enum.KeyCode.H then
					if cannonOn and hudInstance:isCarrying() then
						UI.toast(CannonLogic.CARRY_REFUSED, "info") -- the greyed Home says it too (F84)
					end
					hudInstance:pressTravel("home")
				elseif key == Enum.KeyCode.G and hudInstance:isCarrying() then
					UI.events.dropCat:Fire()
				elseif key == Enum.KeyCode.ButtonB then
					modalInstance:close()
				end
			end)
		)
	end

	render()
	return UI
end

function UI.isInitialized(): boolean
	return initialized
end

-- Merge a partial state and re-render. Pass whole maps (catsOwned, upgradeLevels...) when they change.
function UI.update(partial: Types.PartialState)
	for key, value in partial :: { [string]: any } do
		(state :: any)[key] = value
	end
	-- F84: the first time the tier passes CannonLogic.HINT_TIER this session, hint at the area it opened. The first
	-- update with a tier only records it, so joining at Tier 4 is no rank up.
	local tier: number? = partial.tier
	if tier ~= nil then
		local before = hintTier
		hintTier = tier
		if before ~= nil and before < CannonLogic.HINT_TIER and tier >= CannonLogic.HINT_TIER then
			for _, area in catalogAreas() do
				if area.tier == CannonLogic.HINT_TIER then
					local opened = area.name
					cannonOpened = opened
					-- the hint and its trail go by themselves after a while; a flight clears them sooner
					task.delay(CannonLogic.OPENED_HINT_SECONDS, function()
						if cannonOpened == opened then
							cannonOpened = nil
							applyTutorial()
						end
					end)
					break
				end
			end
		end
	end
	deriveState(partial)
	render()
end

function UI.getState(): Types.PlayerState
	return table.clone(state)
end

function UI.setCatalog(newCatalog: Types.Catalog)
	setCatalog(newCatalog)
	render()
end

function UI.destroy()
	if not initialized then
		return
	end
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	UI.catch.unbindProximityPrompts()
	UI.clock.unbind()
	UI.bigPull.reset()
	UI.leaderboards.reset()
	UI.together.reset()
	UI.campExtras.reset()
	UI.rally.reset()
	UI.trade.reset()
	UI.lawn.reset()
	UI.nursery.reset()
	UI.store.reset()
	UI.bubbles.reset()
	if hud then
		hud:destroy()
	end
	if baitScreen then
		baitScreen:destroy()
	end
	if baitCard then
		baitCard:destroy()
	end
	baitScreen, baitCard = nil, nil
	table.clear(bowls.views)
	table.clear(bowls.cats)
	bowls.card, bowls.second = 1, nil
	if dealerScreen then
		dealerScreen:destroy()
	end
	dealerScreen, cartPart = nil, nil
	if settingsScreen then
		settingsScreen:destroy()
	end
	settingsScreen = nil
	if tipJarScreen then
		tipJarScreen:destroy()
	end
	tipJarScreen = nil
	if spinScreen then
		spinScreen:destroy()
	end
	spinScreen = nil
	if marketScreen then
		marketScreen:destroy()
	end
	marketScreen = nil
	if freshBoard then
		freshBoard:destroy()
	end
	freshBoard, freshStock = nil, nil
	if codesScreen then
		codesScreen:destroy()
	end
	codesScreen = nil
	if potionsScreen then
		potionsScreen:destroy()
	end
	potionsScreen = nil
	if questsScreen then
		questsScreen:destroy()
	end
	questsScreen = nil
	if collectorScreen then
		collectorScreen:destroy()
	end
	collectorScreen = nil
	if dailyTreatScreen then
		dailyTreatScreen:destroy()
	end
	dailyTreatScreen = nil
	dailyAutoOpen = nil
	if introScreen then
		introScreen:destroy()
	end
	introScreen, introLive, introGlowed, tutorialButtonOn = nil, false, false, true
	tutorialTarget, tutorialLabel = nil, nil
	if bugReportScreen then
		bugReportScreen:destroy()
	end
	bugReportScreen = nil
	ClientErrors.stop()
	if upgrades then
		upgrades:destroy()
	end
	if decor then
		decor:destroy()
	end
	if collection then
		collection:destroy()
	end
	if myCats then
		myCats:destroy()
	end
	myCats = nil
	if modal then
		modal:destroy()
	end
	if catch then
		catch:destroy()
	end
	if circles then
		circles:destroy()
	end
	if rescueBar then
		rescueBar:destroy()
	end
	rescueBar = nil
	if rankUpScreen then
		rankUpScreen:destroy()
	end
	if areasScreen then
		areasScreen:destroy()
	end
	if cannonScreen then
		cannonScreen:destroy()
	end
	if cannonCard then
		cannonCard:destroy()
	end
	cannonScreen, cannonCard, cannonPart, cannonOpened, hintTier, hintShown =
		nil, nil, nil, nil, nil, nil
	cannonOn, cannonWild, cannonLaunched = false, false, false
	if gateSigns then
		gateSigns:destroy()
	end
	if indexBoards then
		indexBoards:destroy()
	end
	indexBoards = nil
	if areaTitle then
		areaTitle:destroy()
	end
	if locationMarkers then
		locationMarkers:destroy()
	end
	if cafeSigns then
		cafeSigns:destroy()
	end
	if worldTags then
		worldTags:destroy()
	end
	if catCard then
		catCard:destroy()
	end
	if actionPills then
		actionPills:destroy()
	end
	if richTipScreen then
		richTipScreen:destroy()
	end
	if tillTips then
		tillTips:destroy()
	end
	if tackleBar then
		tackleBar:destroy()
	end
	if netButton then
		netButton:destroy()
	end
	NetGlow.set(nil)
	if reachConnection ~= nil then
		reachConnection:Disconnect()
		reachConnection = nil
	end
	if toasts then
		toasts:destroy()
	end
	if popups then
		popups:destroy()
	end
	if tipCard then
		tipCard:destroy()
	end
	tipCard = nil
	if askCard then
		askCard:destroy()
	end
	askCard = nil
	UI.tips.reset()
	if carryMarker then
		carryMarker:destroy()
	end
	if tutorialMarker then
		tutorialMarker:destroy()
	end
	if tutorialTrail then
		tutorialTrail:destroy()
	end
	hud, upgrades, decor, collection, modal, catch, toasts, popups =
		nil, nil, nil, nil, nil, nil, nil, nil
	carryMarker, tutorialMarker, tutorialTrail = nil, nil, nil
	locationMarkers = nil
	circles, rankUpScreen, areasScreen, gateSigns, areaTitle = nil, nil, nil, nil, nil
	cafeSigns, worldTags, actionPills, richTipScreen, tillTips = nil, nil, nil, nil, nil
	catCard = nil
	tackleBar, netButton = nil, nil
	Scale.stop()
	Sound.set(nil)
	initialized = false
end

----------------------------------------------------------------------------------------------------
-- Screens
----------------------------------------------------------------------------------------------------

function UI.open(name: Types.ScreenName)
	if modal then
		modal:open(name)
	end
end

function UI.close()
	if modal then
		modal:close()
	end
end

function UI.isOpen(): string?
	if modal then
		return modal:current()
	end
	return nil
end

-- Opens the Index on an area's page (an Index Board's prompt, F50).
function UI.openIndex(areaId: string)
	if collection then
		collection:showArea(areaId)
	end
	UI.open("Collection")
end

-- The Cats screen (a free crew slot's "+" in Upgrades, tutorial step 3).
function UI.openCatRoom()
	UI.open("Cats")
end

function UI.setVisible(isVisible: boolean)
	visible = isVisible
	if hud then
		hud:setVisible(isVisible)
	end
	if toasts then
		toasts.screenGui.Enabled = isVisible
	end
	-- cast: the old solver reads UI.rally before its block at the end of the file fills it
	(UI.rally :: any).setVisible(isVisible)
	if locationMarkers then
		locationMarkers:setVisible(isVisible)
	end
	if not isVisible then
		UI.close()
		if catch then
			catch:hide()
		end
		if circles then
			circles:hide()
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Messages
----------------------------------------------------------------------------------------------------

function UI.toast(text: string, kind: Types.ToastKind?)
	-- a bug report waiting on the server: its "Thanks!" closes the window, its refusals keep the words, and any
	-- other toast leaves the report waiting (review N151)
	if bugReportScreen and bugReportScreen:pending() then
		local answer = BugReportLogic.answer(text)
		if answer ~= nil then
			bugReportScreen:result(answer)
		end
	end
	if toasts then
		toasts:show(text, kind)
	end
end

-- Server-wide shout-out (Epic and better catches), Announce(text, rarity?). The rarity colours it; without it the
-- last rarity named as a whole word in the text decides. Silent: Audio plays the sting from the remote.
function UI.announce(text: string, rarity: string?)
	if toasts then
		toasts:announce(text, rarity)
	end
end

-- `extra` is optional: { stars, shiny, rainbow, charmGain }. Missing stars, shiny and rainbow are read from the newest copy of the
-- cat in state.cats when ProfileSync already carries it (caught in the last 30 s).
function UI.showCatFound(catId: string, isNew: boolean?, extra: Types.CatFoundExtra?)
	local def = lookupCat(catId)
	if def and popups then
		local info: Types.CatFoundExtra = {
			stars = extra and extra.stars,
			shiny = extra and extra.shiny,
			rainbow = extra and extra.rainbow,
			charmGain = extra and extra.charmGain,
			banner = extra and extra.banner,
			line = extra and extra.line,
			rate = extra and extra.rate,
		}
		local cats: { [string]: Types.CatInstance } = state.cats or {}
		local newest: Types.CatInstance? = nil
		for _, instance in cats do
			local caughtAt = instance.caughtAt
			if
				instance.catId == catId
				and caughtAt ~= nil
				and os.time() - caughtAt <= 30
				and (newest == nil or caughtAt > ((newest :: Types.CatInstance).caughtAt or 0))
			then
				newest = instance
			end
		end
		if newest then
			info.stars = info.stars or newest.stars
			if info.shiny == nil then
				info.shiny = CatVariant.isGold(newest.variant)
			end
			if info.rainbow == nil then
				info.rainbow = CatVariant.isRainbow(newest.variant)
			end
		end
		popups:showCatFound(def, isNew, info)
	else
		UI.toast("Caught a cat!", "good")
	end
end

----------------------------------------------------------------------------------------------------
-- Cat levels (F75)
----------------------------------------------------------------------------------------------------

-- From the engineer's CatLevelUp(uid, level), the owner only. No toast since 2026-11-02 (Derek 2026-10-28: "the
-- levelup notifications for cats are a little spammy no need for that"): the cat's hover card shows its level and
-- XP bar, which the next ProfileSync moves. Kept so the controller's call stays valid.
function UI.catLevelUp(_uid: string, _level: number) end

-- F87: the first return after Tips.OFFLINE_SECONDS or more away puts the `offline` tip's line on the card's top.
-- F95: the welcome back card says what time away pays, the Long Nap pass's line when state.longNap.
-- Collect plays Sound-Agent's offlineClaim cue once per claim (the card hands its callback out once).
function UI.showOfflineEarnings(amount: number, seconds: number)
	if popups then
		local note = require(script.Components.WelcomeBack).note(state.longNap)
		popups:showOffline(amount, seconds, function()
			Sound.play("offlineClaim")
			UI.events.claimOffline:Fire()
		end, UI.tips.offlineLine(seconds), note)
	end
end

-- Rising text at a world point ("+$8"). Cheap enough for customers' coin pops. #1562 (Derek2: "the money pop-up ticks
-- show at any distance"): only within FLOAT_DISTANCE studs of the camera, like the till tips button. One farther away
-- is not made at all, and MaxDistance hides one the camera moves away from while it rises.
local FLOAT_DISTANCE = 80
function UI.floatText(worldPosition: Vector3, text: string, color: Color3?)
	local parent = parentGui
	if not parent then
		return
	end
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - worldPosition).Magnitude > FLOAT_DISTANCE then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = worldPosition
	attachment.Parent = workspace.Terrain
	local billboard: BillboardGui = Create("BillboardGui", {
		Name = "FloatText",
		Adornee = attachment,
		AlwaysOnTop = true,
		MaxDistance = FLOAT_DISTANCE,
		Size = UDim2.fromOffset(120, 36),
		StudsOffset = Vector3.new(0, 1, 0),
		Parent = parent,
	}, {
		Create("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			FontFace = Theme.fonts.display,
			TextSize = 22,
			TextColor3 = color or Theme.hud.income,
			TextStrokeTransparency = 0.5,
			TextStrokeColor3 = Theme.colors.ink,
			Text = text,
		}),
	})
	local tween = TweenService:Create(
		billboard,
		TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ StudsOffset = Vector3.new(0, 3.5, 0) }
	)
	tween:Play()
	tween.Completed:Once(function()
		billboard:Destroy()
		attachment:Destroy()
	end)
end

----------------------------------------------------------------------------------------------------
-- Bait bowl (F28, data-model section 8)
----------------------------------------------------------------------------------------------------

-- Settings as the switches show them: a tap at once, then the server's saved value, and back to it if the server
-- drops the tap. Apply music and sfx to Audio from `changed` rather than from state.settings, so a sync sent
-- before the server saw the tap cannot flip the music back during the hold (review N111).
UI.settings = {}
UI.settings.changed = Signal.new() -- (key, value)   whenever a key's shown value moves, live while a volume drags;
-- read value(key) and volume(key) once after UI.init

-- A switch as shown (music, sfx, screenShake, lowPerformance, showOtherCats, markers).
function UI.settings.value(key: string): boolean
	if settingsScreen then
		return settingsScreen:value(key)
	end
	return SettingsList.default(key) == true
end

-- A volume as shown, 0 to 1 (musicVolume, sfxVolume).
function UI.settings.volume(key: string): number
	if settingsScreen then
		return settingsScreen:volume(key)
	end
	local default = SettingsList.default(key)
	return if type(default) == "number" then default else 1
end

-- One bowl by your door: Use puts a food in (events.useLure), the cat it rolled arrives after the wait, and
-- the bait card offers Tame or Let go (events.resolveBait). The HUD's bowl chip shows once the Bait bowl upgrade
-- is owned. #1161: with the Second Bait Bowl pass there are two, and set, showReady and hideReady take the bowl (1 or
-- 2, nil is 1) as ProfileSync's bait and bait2; useLure and resolveBait fire with it as their second argument, for
-- UseLure(lureId, bowl) and ResolveBait(choice, bowl). setSecond takes ProfileSync's secondBowl.
UI.bait = {}

local function foodName(lureId: string): string?
	local catalog = currentCatalog
	if catalog then
		for _, lure in catalog.lures do
			if lure.id == lureId then
				return lure.name
			end
		end
	end
	return nil
end

local function renderBait()
	-- the HUD tile (#1161): the sooner bowl, so its "!" shows when either cat is in, and a "2" with two bowls
	local soonest: Types.BaitView? = nil
	for bowl = 1, 2 do
		local view = bowls.views[bowl]
		if view and (soonest == nil or view.readyAt < (soonest :: Types.BaitView).readyAt) then
			soonest = view
		end
	end
	local waiting = bowls.cats[1] ~= nil or bowls.cats[2] ~= nil
	if hud then
		hud:setBait(soonest, waiting)
		hud:setBowlCount(if bowls.second == "on" or bowls.views[2] ~= nil then 2 else 1)
	end
	if baitScreen then
		baitScreen:setBait(bowls.views[2], bowls.cats[2] ~= nil, 2)
		baitScreen:setBait(bowls.views[1], bowls.cats[1] ~= nil, 1)
	end
end

-- The player's own BaitBowl part. Nothing needs it since Use, Tame and Let go work from anywhere (#720); kept so
-- the controller's call stands.
function UI.bait.setBowl(_part: BasePart?) end

-- What is in the bowl: { lureId, readyAt, placedAt?, night? } with the times in server os.time(), or nil when the
-- bowl is empty. night (F60) is true for food set at night, which waits half, and the countdowns show a moon. nil
-- also forgets the cat at the bowl and closes its card (the server resolved it).
function UI.bait.set(bait: Types.BaitView?, bowl: number?)
	local index = if bowl == 2 then 2 else 1
	bowls.views[index] = bait
	if bait == nil then
		bowls.cats[index] = nil
		if baitCard and bowls.card == index then
			baitCard:hide()
		end
	end
	renderBait()
end

-- #1161: ProfileSync's secondBowl, "on" (the pass), "offer" (bowl 2's tab shows the pass card) or nil (one bowl).
-- The card's price is Roblox's (Components/PassShop), so it follows PassShop.changed.
do
	local PassShop = require(script.Components.PassShop)
	local listening: Signal.Connection? = nil
	local function push()
		local screen = baitScreen
		if screen then
			local id: number = Config.SecondBowlPassId
			screen:setSecond(bowls.second, if id ~= 0 then PassShop.prices()[id] else nil)
		end
	end
	function UI.bait.setSecond(kind: string?)
		bowls.second = if kind == "on" or kind == "offer" then kind else nil
		if listening == nil then
			listening = PassShop.changed:Connect(push)
		end
		push()
		renderBait()
	end
	-- the locked tab's buy button: Roblox's purchase window; the server turns bowl 2 on (PassService)
	function UI.bait.buySecond()
		local id: number = Config.SecondBowlPassId
		if id ~= 0 then
			PassShop.prompt(id)
		end
	end
end

-- Opens the Bait bowl screen: the bowl's state and every food with its odds, Use and Buy.
function UI.bait.openPicker()
	if modal then
		modal:open("Bait")
	end
end

-- From BaitReady: the cat that came to the bowl, with Tame and Let go. The X hides the card; the bowl chip
-- and the screen's "See the cat" bring it back until UI.bait.hideReady or UI.bait.set(nil).
function UI.bait.showReady(cat: Types.BaitCat, bowl: number?)
	local def = lookupCat(cat.catId)
	if not def then
		warn(("[CatCafeUI] bait cat %q is not in the catalog"):format(tostring(cat.catId)))
		return
	end
	local index = if bowl == 2 then 2 else 1
	bowls.cats[index] = cat
	bowls.card = index
	if modal and modal:current() == "Bait" then
		modal:close()
	end
	if baitCard then
		local view = bowls.views[index]
		local lureId = if view then view.lureId else nil
		baitCard:show(def :: Types.CatDef, cat, if lureId then foodName(lureId) else nil)
	end
	renderBait()
end

-- The server resolved the cat (tamed or let go): close its card and forget it. `bowl` is 1 or 2 (#1161), nil is 1.
function UI.bait.hideReady(bowl: number?)
	local index = if bowl == 2 then 2 else 1
	bowls.cats[index] = nil
	if baitCard and bowls.card == index then
		baitCard:hide()
	end
	renderBait()
end

----------------------------------------------------------------------------------------------------
-- Night dealer (F32, data-model section 8b)
----------------------------------------------------------------------------------------------------

UI.dealer = {}

-- The dealer's cart part. With it, Buy greys out away from the cart and the strip says to walk back; without
-- it the buttons stay on and the server decides.
function UI.dealer.setCart(part: BasePart?)
	cartPart = part
end

-- From DealerStock (F59): { window, restocksAt, stock = { { lureId, cost, amount, bought } } }, every dealer food
-- with this window's amount and this player's buys; the pre-F59 { slots = { { lureId, cost, bought } }, restocksAt }
-- still works. Send it at night start, at each window change and after every BuyDealerFood, bought or not, so the
-- rows and the countdown stay true. nil when the cart leaves at dawn: the screen closes if it is open.
function UI.dealer.setStock(stock: Types.DealerStock?)
	if dealerScreen then
		dealerScreen:setStock(stock)
	end
	if stock == nil and modal and modal:current() == "Dealer" then
		modal:close()
	end
end

-- Opens the dealer screen (the cart's prompt). It shows the last stock from setStock and "Opening the cart..."
-- until one arrives.
function UI.dealer.open()
	if modal then
		modal:open("Dealer")
	end
end

----------------------------------------------------------------------------------------------------
-- Tip Jar (F47, data-model section 11b)
----------------------------------------------------------------------------------------------------

UI.tipJar = {}

-- From TipJarState: { sessionStartedAt (Workspace:GetServerTimeNow() time), claimed = { [step] = true } }, sent
-- when the profile loads and after every ClaimTipJar. The HUD's Gifts tile appears with the first one and counts
-- down to the next gift; the screen shows every gift. nil hides the tile.
function UI.tipJar.set(jar: Types.TipJarState?)
	if tipJarScreen then
		tipJarScreen:setJar(jar)
	end
end

-- Opens the Tip Jar screen.
function UI.tipJar.open()
	if modal then
		modal:open("TipJar")
	end
end

----------------------------------------------------------------------------------------------------
-- Spin Wheel (F49, data-model section 11c)
----------------------------------------------------------------------------------------------------

UI.spin = {}

-- Opens the Spin window: call it from the station's "Spin" prompt (SpinPrompt, Triggered). It reads state.spin
-- from ProfileSync and Catalog.spinWheel; walking out of range closes it again.
function UI.spin.open()
	if modal then
		modal:open("Spin")
	end
end

-- From SpinResult(slice, amount): the wheel turns to `slice` and shows `amount` (coins paid, or the number of
-- foods). Slice 0 means refused, and the window says why. A result that lands while the window is closed is a toast.
function UI.spin.result(slice: number, amount: number)
	if spinScreen then
		spinScreen:result(slice, amount)
	end
end

-- From SpinAllResult(rolls, totals) (#1078, Gameplay-Engineer #1098): the wheel turns to the last roll and one card
-- sums every prize. Empty lists mean refused, and the window says why.
function UI.spin.allResult(rolls: { { slice: number, amount: number } }, totals: { any })
	if spinScreen then
		spinScreen:allResult(rolls, totals)
	end
end

----------------------------------------------------------------------------------------------------
-- Golden Fish Market (F53, golden-fish.md sections 3 and 4)
----------------------------------------------------------------------------------------------------

UI.market = {}

-- Opens the Market window: call it from the stall's "Market" prompt (FishMarket tag, Triggered). It reads
-- goldenFish, crates, crateLuck, fishPerks and lures from ProfileSync and Catalog.crates and Catalog.fishShop;
-- walking out of range closes it again.
function UI.market.open()
	if modal then
		modal:open("Market")
	end
end

-- From CrateResult(crateId, decorId, duplicate, refund): plays the reveal for the won piece, with "+N golden fish
-- back" for a duplicate. A refusal is CrateResult(crateId, "", false, 0): the Open button frees up and the server's
-- toast says why. A result that lands while the window is closed is a toast.
function UI.market.result(crateId: string, decorId: string, duplicate: boolean, refund: number)
	if marketScreen then
		marketScreen:result(crateId, decorId, duplicate, refund)
	end
end

----------------------------------------------------------------------------------------------------
-- The Fresh Catch shelf (F94, rewards-and-shops.md section 3)
----------------------------------------------------------------------------------------------------

UI.freshCatch = {}

-- A Fresh Catch row's name: its potion's or crate's, from the catalog.
local function freshName(itemId: string): string
	local catalog = currentCatalog
	if catalog then
		for _, potion in PotionLogic.list(catalog) do
			if potion.id == itemId then
				return potion.name
			end
		end
		local crates: { Types.CrateDef } = catalog.crates or {}
		for _, crate in crates do
			if crate.id == itemId then
				return crate.name
			end
		end
	end
	return itemId
end

-- From FreshCatchStock(stock?): this player's Fresh Catch stock by day, nil at night,
-- `{ window, restocksAt, stock = { { itemId, fish, amount, bought } } }`. It reaches the Market's Fresh Catch tab and
-- the chalkboard on the stall; the server sends it whenever it changes and after every BuyFreshCatch.
function UI.freshCatch.setStock(stock: any)
	freshStock = FreshCatchLogic.normalize(stock)
	if marketScreen then
		marketScreen:setFreshStock(freshStock)
	end
	if freshBoard then
		freshBoard:set(freshStock, freshName)
	end
end

-- From ShopAlert(itemId): the once a window heads up when the Fresh Catch stocks a Gold Rush Potion or the cheap
-- Classic Crate ("Gold Rush Potions at the Fish Market!"). The server sends it only with "Shop alerts" on.
function UI.shopAlert(itemId: string)
	if toasts == nil or type(itemId) ~= "string" then
		return
	end
	local name = freshName(itemId)
	local isCrate = string.find(itemId, "_crate$") ~= nil
	toasts:show(
		if isCrate
			then ("A cheap %s at the Fish Market!"):format(name)
			else ("%ss at the Fish Market!"):format(name),
		"info"
	)
end

----------------------------------------------------------------------------------------------------
-- Potions and the Mystery gift (F64, data-model section 12b)
----------------------------------------------------------------------------------------------------

-- The Thank You board (#1083): ThanksBoard(rows, hasCredit) from IdeaCreditsService, on join and at each rebuild.
-- `hasCredit` is for Settings' "Show my name" row, which comes with the Feedback tick in the next PR.
function UI.thanksBoard(rows: { any }, hasCredit: boolean)
	require(script.Screens.ThanksBoard).show(if type(rows) == "table" then rows else {})
	if settingsScreen then
		settingsScreen:showCredit(hasCredit == true) -- the "Show my name" row only for a credited player
	end
end

UI.potions = {}

-- The Bag's Feed (#1181): FeedResult(catUid, level, xp) from the server after a FeedCat it took. The server already
-- toasts "<cat> loved the <food>: +N XP", so this only adds a level up; the counts move with the ProfileSync after.
UI.bag = {}
function UI.bag.fed(catUid: string, level: number, _xp: number)
	local before = bagFed[catUid]
	bagFed[catUid] = nil
	if before and before > 0 and level > before then
		UI.toast(("Level up! Level %d"):format(level), "good")
	end
end

-- From MysteryGiftResult(kind, id, count): a card with what the gift held ("Money Potion", "2 Salmon",
-- "10 golden fish", "1 spin") as a picture, closing by itself, with the giftOpen sound.
function UI.potions.giftResult(kind: string, id: string?, count: number)
	if popups == nil then
		return
	end
	local function potionName(potionId: string): string?
		for _, potion in PotionLogic.list(currentCatalog) do
			if potion.id == potionId then
				return potion.name
			end
		end
		return nil
	end
	local title = PotionLogic.giftTitle(kind, id, count, foodName, potionName)
	popups:showGift(title, PotionLogic.giftPrize(kind, id, count))
end

----------------------------------------------------------------------------------------------------
-- The Cat Collector (F63, data-model section 12b)
----------------------------------------------------------------------------------------------------

UI.collector = {}

-- From CollectorOffer(catUid, offer, endsAt, traded): his visit to your cafe. A tag over his CollectorSpot shows the
-- time he has left (endsAt is server os.time()) and his card opens when you walk within 12 studs of him: the cat he
-- wants (looked up in state.cats), his offer as pictures and Trade / No thanks, which fire events.answerCollector.
-- catUid "" ends the visit and closes the card; `traded` true plays uiTrade. Needs UI.richTip.bind(plot) for the
-- spot.
function UI.collector.offer(
	catUid: string,
	offer: Types.CollectorOffer?,
	endsAt: number,
	traded: boolean?
)
	if collectorScreen then
		collectorScreen:offer(catUid, offer, endsAt, traded)
	end
end

----------------------------------------------------------------------------------------------------
-- Quests and achievements (F73, quests.md sections 1 and 7)
----------------------------------------------------------------------------------------------------

UI.quests = {}

-- From QuestResult(paid): what a quest, a full set or an achievement claim paid. The server's toast already says it,
-- so the window only plays the claim sound.
function UI.quests.result(paid: { string })
	if questsScreen then
		questsScreen:result(paid)
	end
end

----------------------------------------------------------------------------------------------------
-- Codes and the Codes Cat (F65, data-model section 11d)
----------------------------------------------------------------------------------------------------

UI.codes = {}

-- Opens the code box: call it when this character walks into the Codes Cat's circle (within CodesCircleRadius,
-- flat). No key press and no prompt. A window the player has open (the Market stall is near) stays open instead
-- (review N182).
function UI.codes.open()
	-- #1428: the code box lives in the Store's Codes tab, so the circle opens the Store there
	local store: any = UI.store -- defined further down
	if store.openCodes() then
		return
	end
	if modal and modal:current() == nil then
		modal:open("Codes")
	end
end

-- Closes the code box and clears its field: call it once the character is past CodesCircleRadius + 1. A window the
-- player opened meanwhile stays open.
function UI.codes.close()
	local store: any = UI.store
	if modal and (modal:current() == "Codes" or store.codesShowing()) then
		modal:close()
	end
end

-- From CodeResult(ok, message, prize): the answer line ("Code redeemed!" or the refusal) and, when ok, the prize as
-- little pictures. When the box was closed first (the player walked off) the answer is a toast instead.
function UI.codes.result(ok: boolean, message: string, prize: Types.IndexPrize?)
	if codesScreen then
		codesScreen:result(ok, message, prize)
	end
	local store: any = UI.store
	if toasts and not (modal and modal:current() == "Codes") and not store.codesShowing() then
		toasts:show(message, if ok then "good" else "warn")
	end
end

----------------------------------------------------------------------------------------------------
-- Report a bug (docs/playtests/bug-reports.md section 1)
----------------------------------------------------------------------------------------------------

UI.bugReport = {}

-- Opens the Feedback window, on the `kind` chip ("bug", "stuck" or "idea") unless a draft is waiting. Players reach
-- it from the HUD's Feedback tile (on Idea), the one way in since Settings lost its Report a bug row (2026-11-01).
-- With a kind ("bug", "stuck", "idea") the report page on that chip; without one (the HUD's Feedback tile, Settings'
-- Feedback row) the F87 faces page first.
function UI.bugReport.open(kind: string?)
	if modal then
		if bugReportScreen and kind then
			bugReportScreen:setKind(kind)
		elseif bugReportScreen then
			bugReportScreen:showFaces()
		end
		modal:open("BugReport")
	end
end

-- The server's answer to ReportBug, when it comes some other way than a toast: true closes the window and clears
-- the box, false keeps the words and lights Send again. The server's toasts already do this through UI.toast.
function UI.bugReport.result(ok: boolean)
	if bugReportScreen then
		bugReportScreen:result(ok)
	end
end

----------------------------------------------------------------------------------------------------
-- Rich tip (F31, data-model section 12)
----------------------------------------------------------------------------------------------------

UI.richTip = {}

-- Your own plot model: a gold marker over its RichTipAnchor whenever RichTipAmount and RichTipExpiresAt (server
-- os.time()) show a tip, with Collect firing events.claimRichTip within 12 studs. When a claimed tip clears
-- (RichTipOutcome "claimed") "+$X" rises from the coin pile and a toast says so, so the server needs no Notify for
-- it; a missed one only toasts "Rich tip missed".
-- F63: the same plot's CollectorSpot, where the Cat Collector's tag and card follow UI.collector.offer.
-- Call it again when the player gets a new plot; nil stops watching.
function UI.richTip.bind(plot: Instance?)
	if richTipScreen then
		richTipScreen:bind(plot)
	end
	-- F91: the same plot's LawnPath says the Front lawn tab is live, and its LawnSpots carry the edit view's rings
	if decor then
		decor:bindPlot(plot)
	end
	-- cast: the old solver reads UI.lawn before its block at the end of the file fills it
	(UI.lawn :: any).bind(plot)
	-- F97: tip piles pay the moment they appear (Gameplay-Engineer #714), so the till's Collect pill stays unbound
	-- until F90's Waiter gives the till a job
	if collectorScreen then
		collectorScreen:bind(plot)
	end
end

----------------------------------------------------------------------------------------------------
-- Tackle (F74, data-model section 10c v0.11; the API keeps the Shove name)
----------------------------------------------------------------------------------------------------

UI.shove = {}

-- True while the player stands inside a catching area they have unlocked and tackles are on (Config.BumpEnabled);
-- the street, the cafes and the yards are false. The button fires events.tackle() and shows its reach on the
-- ground; it hides itself while carrying, during the catch circles and during the rescue bar.
function UI.shove.setEnabled(on: boolean)
	if tackleBar then
		tackleBar:setEnabled(on)
	end
end

-- The tackler's ShoveResult: false after a refusal gives the cooldown back at once. With the outcome ("miss",
-- "shove", "loose" or "held") and the target's UserId it toasts "Missed!" or "Tackled Alex!"; both are optional.
function UI.shove.result(ok: boolean, outcome: string?, targetUserId: number?)
	if tackleBar then
		tackleBar:result(ok, outcome)
	end
	local target = if type(targetUserId) == "number" and targetUserId > 0
		then Players:GetPlayerByUserId(targetUserId)
		else nil
	local text, good = TackleLogic.toast(ok, outcome, if target then target.DisplayName else nil)
	if text then
		UI.toast(text, if good then "good" else "warn")
	end
end

----------------------------------------------------------------------------------------------------
-- The net swing (F93, catch-rework.md section 1)
----------------------------------------------------------------------------------------------------

UI.net = {}

-- From NetSwingController whenever a swing becomes possible or not (carrying, a minigame, the intro, a flight, a
-- camp). The touch Net button shows while this is on, the player stands in a catching area (UI.setZone) or has a
-- stray in reach (a dropped cat on the street, reviewer N298), and no circles or rescue bar are up; a press fires
-- events.netSwing.
function UI.net.setEnabled(on: boolean)
	if netButton then
		netButton:setEnabled(on)
	end
end

-- The stray a swing would land on right now, or nil: a soft glow on it (Moments.NetInReach calls this too).
function UI.net.setInReach(model: Model?)
	NetGlow.set(model)
	if netButton then
		netButton:setInReach(model ~= nil)
	end
end

-- One short line on how to swing on this device, for the tutorial strip and hints: "Tap NET next to a cat",
-- "Press R2 next to a cat" or "Click next to a cat".
function UI.net.hint(): string
	if Scale.isTouch() then
		return "Tap NET next to a cat"
	elseif UserInputService.GamepadEnabled and not UserInputService.MouseEnabled then
		return "Press R2 next to a cat"
	end
	return "Click next to a cat"
end

----------------------------------------------------------------------------------------------------
-- Carry indicator and tutorial hooks
----------------------------------------------------------------------------------------------------

-- info.door is the player's own cafe Door part; a marker with distance appears over it.
function UI.setCarrying(info: Types.CarryInfo?)
	-- a partial ProfileSync cannot carry a nil, so UI.update never clears state.carrying; this call does, or the
	-- HUD would keep reading "Walk it home" after a drop or a check in (engineer, 2026-10-27)
	(state :: any).carrying = if info then info.catId else nil
	local hudScreen = hud
	local marker = carryMarker
	if not hudScreen or not marker then
		return
	end
	local resolved: Types.CarryInfo? = nil
	if info then
		assert(info, "carry info missing")
		local def = lookupCat(info.catId)
		resolved = {
			catId = info.catId,
			catName = info.catName or (if def then def.name else nil),
			rarity = info.rarity or (if def then def.rarity else nil),
			door = info.door,
			camp = info.camp,
		}
	end
	hudScreen:setCarrying(resolved)
	if areasScreen then
		areasScreen:render(state, hudScreen:isCarrying())
	end
	if cannonScreen then
		cannonScreen:render(state, hudScreen:isCarrying())
	end
	if resolved and resolved.camp then
		marker:show(resolved.camp :: BasePart, "Bring it here", Theme.rarityColor(resolved.rarity))
	elseif resolved and resolved.door then
		marker:show(resolved.door :: BasePart, "Check in here", Theme.rarityColor(resolved.rarity))
	else
		marker:hide()
	end
end

UI.tutorial = {}

-- One line at the bottom of the screen and, if a target is given, a marker in the world and a glowing trail on the
-- ground leading to it (Pet Simulator 99). Calling it again with the same target keeps the trail's route.
function UI.tutorial.show(
	text: string,
	target: (BasePart | Attachment | Vector3)?,
	markerLabel: string?
)
	tutorialText, tutorialTarget, tutorialLabel = text, target, markerLabel
	applyTutorial() -- the cannon hint can come first (F84)
end

function UI.tutorial.hide()
	tutorialText, tutorialTarget, tutorialLabel = nil, nil, nil
	applyTutorial()
end

----------------------------------------------------------------------------------------------------
-- Intro cutscene (F72, docs/design/cat-cafe/intro-cutscene.md)
----------------------------------------------------------------------------------------------------

-- The controller's IntroController moves the camera; the UI draws the letterbox bars, captions, shot dots, title
-- cards, the demo catch ring, the job card and Skip (Screens/Intro).
UI.intro = {}

-- Bars in, and the HUD, toasts, place icons, the tutorial marker and trail and any popup hidden until finish.
-- Skip shows at once, dimmed, with a gold bar filling it over options.skipAfter seconds (default 5.0, or full at
-- once with options.replay); only a full Skip skips. Calling it marks the intro live, so the Tutorial tile and
-- Settings rows show afterwards.
function UI.intro.start(options: Types.IntroOptions?)
	local screen = introScreen
	if screen == nil then
		return
	end
	if not introLive then
		introLive = true
		renderTutorialButton()
	end
	UI.setVisible(false)
	if popups then
		popups:setHeld(true)
	end
	if tutorialMarker then
		tutorialMarker:hide()
	end
	if tutorialTrail then
		tutorialTrail:hide()
	end
	screen:start(options)
end

-- A shot begins: index 1 to Intro.SHOTS lights its dot, the caption pops. #1542 (Derek): the camp shot and its area
-- title cards are gone; a third argument is still taken and ignored, so the controller's calls stand until it drops it.
function UI.intro.setShot(index: number, caption: string, _titleCard: string?)
	if introScreen then
		introScreen:setShot(index, caption)
	end
end

-- Shot 2's demo catch at the stray: the ring closes over 1.3 s, PERFECT and a sparkle, gone at 2.0 s.
function UI.intro.demoCatch(worldPosition: Vector3)
	if introScreen then
		introScreen:demoCatch(worldPosition)
	end
end

-- Shot 4's job card, 0.35 s in, beside the cat taking its spot: the four role tiles in miniature, `role`'s
-- ("waiter") lit with a tap 0.25 s later, gone by 0.55 s after it showed.
function UI.intro.jobCard(worldPosition: Vector3, role: string)
	if introScreen then
		introScreen:jobCard(worldPosition, role)
	end
end

-- The end, after the last shot or on Skip: the bars slide out over 0.45 s and everything hidden comes back.
function UI.intro.finish()
	if introScreen then
		introScreen:finish()
	end
end

function UI.intro.playing(): boolean
	local screen = introScreen
	return screen ~= nil and screen:playing()
end

----------------------------------------------------------------------------------------------------
-- The Cat Cannon (F84, docs/design/cat-cafe/hometown-cannon.md)
----------------------------------------------------------------------------------------------------

-- Every catching area is reached by the Cat Cannon in the Town Square, and each has a safe camp with a cannon back.
-- Off until setEnabled(true), so the Areas button and panel work as before on a server without F84.
UI.cannon = {}

-- On: the HUD's Cannon button takes the Areas button's place and fires events.travel("cannon") (the server moves
-- the player to the front of the nearest cannon), the Alley button goes, and the carry banner reads "Bring it to the
-- camp!".
function UI.cannon.setEnabled(on: boolean)
	cannonOn = on
	if hud then
		hud:setCannonMode(on)
	end
	if on and modal and modal:current() == "Areas" then
		modal:close()
	end
	applyTutorial()
end

-- The wild area the character is in, camp included, or nil in the hometown. Hides the cannon hints out there.
function UI.cannon.setWild(areaId: string?)
	if cannonWild == (areaId ~= nil) then
		return
	end
	cannonWild = areaId ~= nil
	applyTutorial()
end

-- The Town Square cannon, for the hint's arrow and trail.
function UI.cannon.setCannon(part: BasePart?)
	cannonPart = part
	if hintShown ~= nil then
		applyTutorial()
	end
end

-- "Hop in" held at a cannon: "town" for the Town Square cannon, or a camp's area id for its cannon (Town Square first,
-- never its own area). Launch fires events.launchCannon(cannonId, destination).
function UI.cannon.open(cannonId: string?)
	local screen = cannonScreen
	local windows = modal
	if screen == nil or windows == nil then
		return
	end
	screen:setCannon(cannonId or CannonLogic.TOWN)
	windows:open("Cannon")
end

-- CannonLaunch(destination, launchAt) from the server: the picker closes, and the name card pops in at once, as it
-- closes, zips off 2.5 s after launchAt and is gone by 2.7 (CannonLogic.CHOSEN_HOLD, #1163, 2 s longer since #1444; a
-- refused Launch never comes here). Ends the first-flight and Tier 2 hints. The intro's shot 2 calls it too, for its
-- staged flight to the Alleyway, with `hold` 0.4 and launchAt 0.9 s before the shot starts: given a `hold`, the card
-- keeps the cloud schedule, from 1.6 s after launchAt (card up 0.7 to 1.1 s in); while the intro plays only the card
-- shows, so the first-flight hint still follows the intro.
function UI.cannon.flight(destination: string, launchAt: number, hold: number?)
	-- no context tip pops up in the clouds or as the player lands (F87)
	tipsHeldUntil = os.clock()
		+ math.max(0, launchAt - Workspace:GetServerTimeNow())
		+ (hold or 0)
		+ 5
	if not UI.intro.playing() then
		if modal and modal:current() == "Cannon" then
			modal:close()
		end
		cannonLaunched = true
		cannonOpened = nil
		applyTutorial()
	end
	local name = CannonLogic.TOWN_NAME
	for _, area in catalogAreas() do
		if area.id == destination then
			name = area.name
		end
	end
	if cannonCard then
		if hold ~= nil then
			cannonCard:show(destination, name, launchAt, hold) -- the intro's, in the clouds
		else
			-- counted from launchAt, so the zip lands on the BOOM whatever the lag; it still pops in on arrival
			cannonCard:show(
				destination,
				name,
				launchAt,
				CannonLogic.CHOSEN_HOLD,
				CannonLogic.CHOSEN_IN
			)
		end
	end
end

-- The player's own CampCheckIn: "Pirate Cat is on its way to your cafe!" (the camp chime is Audio's).
function UI.cannon.checkedIn(catName: string?)
	UI.toast(("🧺 %s is on its way to your cafe!"):format(catName or "Your cat"), "good")
end

-- A refused LaunchCannon: Launch comes back at once and the card's button wobbles. The server's toast says why.
function UI.cannon.result(ok: boolean, destination: string?)
	if cannonScreen then
		cannonScreen:result(ok, destination)
	end
end

----------------------------------------------------------------------------------------------------
-- Fast travel (F19)
----------------------------------------------------------------------------------------------------

-- The travel row (Cafe, Alley, Areas) and the Areas panel fire events.travel(destination) with "home" or an
-- AreaId; with the Cat Cannon live (F84), Cafe and Cannon fire "home" and "cannon". The server answers TravelResult(destination, ok, reason?); pass it here so a refused trip lifts the
-- cooldown and wobbles its button. The server's own toast gives the reason.
UI.travel = {}

function UI.travel.result(destination: string, ok: boolean, _reason: string?)
	if hud then
		hud:travelResult(destination, ok)
	end
	if ok then
		UI.showAreaTitle(destination)
	end
end

-- The short night (F66, data-model v0.9): in the last DuskWarningSeconds of a day a player in a catching area gets
-- "Night falls in 15 s! The areas close until sunrise." (once per dusk, or when they walk in during it), and at
-- sunrise everyone gets "Sunrise! Fresh cats in every area." Both are quiet: Audio rings its own dusk bell.
local DUSK_SECONDS: number = (Config :: any).DuskWarningSeconds or 15
local SUNRISE_HOLD = 3
local clockPhase: Types.ClockPhase? = nil
local duskToken = 0 -- the latest dusk timer's, so a newer clock reading cancels an older one
local duskEndsAt: number? = nil -- the day's end while the dusk warning runs, else nil
local duskShown = false

local function showDusk()
	local endsAt = duskEndsAt
	local card = areaTitle
	if endsAt == nil or duskShown or card == nil or Wayfinding.isSafe(currentZone) then
		return
	end
	local remaining = endsAt - Workspace:GetServerTimeNow()
	if remaining <= 0 then
		return
	end
	duskShown = true
	card:banner(
		"dusk",
		NightClock.duskTitle(remaining),
		"The areas close until sunrise.",
		Theme.colors.sky,
		math.min(remaining, 4)
	)
end

local function watchDusk(phase: Types.ClockPhase, phaseEndsAt: number)
	duskToken += 1
	local token = duskToken
	duskEndsAt = nil
	if phase ~= "day" then
		return
	end
	local function start()
		if duskToken == token then
			duskEndsAt = phaseEndsAt
			duskShown = false
			showDusk()
		end
	end
	local wait = phaseEndsAt - DUSK_SECONDS - Workspace:GetServerTimeNow()
	if wait > 0 then
		task.delay(wait, start)
	elseif NightClock.isDusk(phase, phaseEndsAt - Workspace:GetServerTimeNow(), DUSK_SECONDS) then
		start()
	end
end

-- The World.Zones name the player stands in, from the controller's zone check (the one that picks the ambience):
-- nil or "Cafe" on the safe street and in the cafes, else the area ("Alley"). It only times the dusk warning now:
-- the "Safe zone" chip went on 2026-10-28 (Derek: "no need for 'safe zone' or danger zone bubble its just clutter")
-- and the "Safe zone: no tackling here" toast on 2026-11-02 (Derek 2026-10-28: "no need for the safe area reached
-- banner either").
function UI.setZone(zone: string?)
	currentZone = zone
	showDusk() -- walking into an area during the dusk warning
	if netButton then
		netButton:setInArea(not Wayfinding.isSafe(zone))
	end
end

-- Area title card (F39 P1): the area's name in big letters for two seconds. Call it when the player walks into
-- an area (the same zone check that picks the ambience); a successful trip shows it already, and the same area
-- twice within 4 s shows once. `areaId` is an AreaId or "home" (the player's own cafe, named by its tier).
function UI.showAreaTitle(areaId: string)
	local card = areaTitle
	if not card then
		return
	end
	local catalog = currentCatalog
	if areaId == "home" then
		-- no card for the player's own cafe (the friend 11-04: the "Busy Cafe" pop-up is clutter); the tier's name
		-- lives in the rank card and the rank up moment
		return
	end
	local areas: { Types.AreaDef } = if catalog then catalog.areas or {} else {}
	for _, area in areas do
		if area.id == areaId then
			local color = Theme.areaColors[area.id]
			-- the name only: no spawn rates (Derek 2026-10-28: "No need to show area rates everytime you walk
			-- into it or at all")
			local tint = if color then color:Lerp(Theme.colors.white, 0.35) else nil
			card:show(area.id, area.name, nil, tint)
			return
		end
	end
end

-- The catch, rescue and prompt code is one block, so its locals do not count against the module's 200 (Luau's
-- limit for one function's locals; the module was at 196). Its tables are made out here, so every use of them
-- type checks.
UI.catch = {}
UI.rescue = {}
do
	----------------------------------------------------------------------------------------------------
	-- Catch prompt and closing circles
	----------------------------------------------------------------------------------------------------

	local activePrompt: ProximityPrompt? = nil
	local activeInfo: Types.CatchInfo? = nil
	local promptConnections: { RBXScriptConnection } = {}
	-- the active stray's FleeingUntil (v0.5), and its PickUp, Returning and Dropped (F67: a walking cat that gets home
	-- turns back into one that needs the circles)
	local strayWatch: { RBXScriptConnection } = {}
	-- v0.5.1 (reviewer S44), F57: when this player may try a stray again after their own miss. The server sends it with
	-- CatchResult (3, 6, then 10 s after the stray stops, by misses in a row; only the server knows the streak, S87).
	-- Without it (a server before F57) the wait is StraySelfRetrySeconds after the stop, from the miss time.
	local SELF_RETRY: number = Config.StraySelfRetrySeconds
	type Retry = { missedAt: number, retryAt: number? }
	local retries: { [string]: Retry } = {} -- strayId -> this player's last miss on it

	-- When this player may try the stray again, or nil when they never missed it.
	local function retryAtFor(strayId: string?, fleeingUntil: number?): number?
		local retry = if strayId then retries[strayId] else nil
		if retry == nil then
			return nil
		end
		return retry.retryAt or math.max(fleeingUntil or 0, retry.missedAt) + SELF_RETRY
	end

	function UI.catch.show(info: Types.CatchInfo)
		local def = lookupCat(info.catId)
		activeInfo = {
			catId = info.catId,
			strayId = info.strayId,
			catName = info.catName or (if def then def.name else nil),
			rarity = info.rarity or (if def then def.rarity else nil),
			holdDuration = info.holdDuration,
			actionText = info.actionText,
			keyCode = info.keyCode,
			stars = info.stars,
			charm = info.charm,
			kind = info.kind,
			rescueSpotId = info.rescueSpotId,
			press = info.press,
			shiny = info.shiny,
			rainbow = info.rainbow,
			fleeingUntil = info.fleeingUntil,
			retryAt = info.retryAt or retryAtFor(info.strayId, info.fleeingUntil),
			ownerTurnUntil = info.ownerTurnUntil,
		}
		if catch then
			catch:show(activeInfo :: Types.CatchInfo)
		end
	end

	-- retry = true keeps the prompt open (Commons, lured strays, a rescue turned down for now). Otherwise it
	-- flashes and hides (the cat fled).
	function UI.catch.fail(reason: string?, retry: boolean?)
		if catch then
			catch:fail(reason, retry)
		end
	end

	function UI.catch.hide()
		if catch then
			catch:hide()
		end
		activeInfo = nil
	end

	function UI.catch.getActivePrompt(): ProximityPrompt?
		return activePrompt
	end

	-- Net circles (F26, data-model section 10). CatchSchedule(strayId, circles, windows) -> showCircles: the prompt
	-- card makes way for the circles and every press fires events.catchPressed(strayId, index, grade).
	-- CatchResult(strayId, grades, success, charmGain, retryAt) -> showGrades: each circle shows the server's grade. A
	-- catch shows "Caught!" or "PURRFECT!" with the charm it added; a miss closes the overlay after 1 s and toasts "It
	-- got away! Chase it!" (v0.5: the cat sprints off and tries are unlimited), and the card comes back while the
	-- player is in range. Call nothing else for a CatchResult; catch.fail stays for refusals.
	function UI.catch.showCircles(
		strayId: string,
		circleList: { Types.CatchCircle },
		windows: Types.CatchWindows
	)
		local screen = circles
		if not screen then
			return
		end
		local info = activeInfo
		local header: CatchCircles.Header? = nil
		if info and info.strayId == strayId then
			local rarity: string? = info.rarity
			local built: CatchCircles.Header = {
				catName = info.catName,
				rarity = rarity,
				stars = info.stars,
				shiny = info.shiny,
				rainbow = info.rainbow,
				title = nil,
			}
			header = built
		end
		if catch then
			catch:hide() -- activePrompt and activeInfo stay so the card can come back
		end
		if hud then
			hud:setCatching(true)
		end
		screen:show(circleList, windows, header, function(index: number, grade: Types.CircleGrade?)
			UI.events.catchPressed:Fire(strayId, index, grade)
		end)
	end

	-- The toast after a miss (data-model section 10 step 5, v0.5): the cat sprints off and can be tried again
	local SLIPPED_TEXT = "It got away! Chase it!"

	-- The end of a catch: on a miss the toast, then the card comes back while the prompt is still up.
	local function finishCatch(strayId: string, outcome: CatchCircles.Outcome, retryAt: number?)
		local screen = circles
		if not screen then
			return
		end
		local current = activeInfo
		-- F87 (easy-start.md section 2b, review N301): a Miss on the local player's own tutorial stray costs nothing;
		-- the server says "Try again! Tap as the circle closes." and starts the circle again, so no "It got away!" and
		-- no wait (inline, as the module is short of locals)
		if not outcome.success then
			local me = Players.LocalPlayer
			for _, instance in CollectionService:GetTagged("Stray") do
				if instance:GetAttribute("StrayId") == strayId then
					if me ~= nil and instance:GetAttribute("Beginner") == me.UserId then
						outcome.hint = "Try again!"
					end
					break
				end
			end
		end
		if not outcome.success and outcome.hint == nil then
			local now = Workspace:GetServerTimeNow()
			for id, retry in retries do
				if now - retry.missedAt > 120 and (retry.retryAt or 0) < now then
					retries[id] = nil
				end
			end
			local given = if type(retryAt) == "number" and retryAt == retryAt then retryAt else nil
			retries[strayId] = { missedAt = now, retryAt = given }
			if current and current.strayId == strayId then
				current.retryAt = retryAtFor(strayId, current.fleeingUntil)
			end
		end
		if not outcome.success and outcome.hint == nil and toasts then
			toasts:show(SLIPPED_TEXT, "warn", true) -- quiet: the hiss is the miss sound
		end
		screen:showResult(outcome, function()
			if hud then
				hud:setCatching(false)
			end
			local info = activeInfo
			local card = catch
			if not outcome.success and activePrompt ~= nil and info ~= nil and card ~= nil then
				card:show(info)
			end
		end)
	end

	-- CatchResult. grades run up to and including the first Miss; charmGain is 0 on a miss. retryAt (F57, miss only) is
	-- the server time this player may try the stray again; the card reads "Catch your breath..." until then.
	function UI.catch.showGrades(
		strayId: string,
		grades: { Types.CircleGrade },
		success: boolean,
		charmGain: number?,
		retryAt: number?
	)
		finishCatch(strayId, {
			grades = grades,
			success = success,
			charmGain = charmGain,
		}, retryAt)
	end

	function UI.catch.hideCircles()
		if circles then
			circles:hide()
		end
		if hud then
			hud:setCatching(false)
		end
	end

	function UI.catch.circlesActive(): boolean
		return circles ~= nil and (circles :: CatchCircles.CatchCircles):isActive()
	end

	----------------------------------------------------------------------------------------------------
	-- Rescue minigames (F27, data-model section 10b)
	----------------------------------------------------------------------------------------------------

	local rescueTarget: string? = nil -- the trap of the attempt on screen
	local rescueOnCircle = false -- a tree's falling cat is on the catch circles, not the bar

	-- After the attempt: the travel row comes back, and on a fail the prompt card returns while the player is still
	-- at the trap (the server makes them wait RescueSelfRetrySeconds before the next try).
	local function endRescue(success: boolean)
		rescueTarget = nil
		rescueOnCircle = false
		if hud then
			hud:setCatching(false)
		end
		local info = activeInfo
		local card = catch
		if not success and activePrompt ~= nil and info ~= nil and card ~= nil then
			card:show(info)
		end
	end

	-- From RescueChallenge(rescueSpotId, challenge). "bar" and "shake_catch" draw the bar; "circle" (the tree's
	-- falling cat, after the shakes) draws one catch circle whose press also goes to RescuePress.
	function UI.rescue.show(rescueSpotId: string, challenge: Types.RescueChallenge)
		local bar = rescueBar
		local circleScreen = circles
		if not bar or not circleScreen then
			return
		end
		-- a "circle" challenge without its circle changes nothing, so the HUD never sticks in catching mode (N75)
		if challenge.kind == "circle" and challenge.circle == nil then
			warn(
				("[CatCafeUI] rescue %q: circle challenge without its circle"):format(rescueSpotId)
			)
			return
		end
		local info = activeInfo
		local own = info ~= nil and info.rescueSpotId == rescueSpotId
		local catName: string? = if own and info then info.catName else nil
		local rarity: string? = if own and info then info.rarity else nil
		rescueTarget = rescueSpotId
		if catch then
			catch:hide() -- activePrompt and activeInfo stay so the card can come back
		end
		if hud then
			hud:setCatching(true)
		end
		if challenge.kind == "circle" then
			local circle = challenge.circle :: Types.CatchCircle
			bar:hide()
			rescueOnCircle = true
			local header: CatchCircles.Header = {
				catName = catName,
				rarity = rarity,
				title = "Catch it as it falls!",
			}
			circleScreen:show(
				{ circle :: Types.CatchCircle },
				challenge.windows or { perfect = 0.045, good = 0.11 },
				header,
				function()
					UI.events.rescuePressed:Fire(rescueSpotId)
				end
			)
			return
		end
		rescueOnCircle = false
		bar:show(challenge, { catName = catName, rarity = rarity }, {
			press = function()
				UI.events.rescuePressed:Fire(rescueSpotId)
			end,
			cancel = function()
				UI.events.rescueCancelled:Fire(rescueSpotId)
			end,
			ended = function(success: boolean)
				if rescueTarget == rescueSpotId then
					endRescue(success)
				end
			end,
		})
	end

	-- From RescueResult(rescueSpotId, hits, pawsLeft, done, success, bar?): the server's hit count, the paws left, and
	-- whether the attempt is over. A success then moves the player to carry, as after a catch. F93: `bar` is how the
	-- marker runs and which zone to hit from now (after a hit, or a zone that ran out unhit, which also costs a paw).
	function UI.rescue.update(
		rescueSpotId: string,
		hits: number,
		pawsLeft: number?,
		done: boolean,
		success: boolean,
		bar: Types.RescueBar?
	)
		if rescueSpotId ~= rescueTarget then
			return
		end
		if rescueOnCircle then
			local screen = circles
			if not done or not screen then
				return
			end
			local guess = screen:gradeLocal(1)
			local grade: Types.CircleGrade = if not success
				then "miss"
				elseif guess == "perfect" then "perfect"
				else "good"
			screen:showResult({ grades = { grade }, success = success }, function()
				endRescue(success)
			end)
			return
		end
		if rescueBar then
			rescueBar:update(hits, pawsLeft, done, success, bar)
		end
	end

	-- Closes the bar or the circle without a result (the controller saw the attempt end some other way).
	function UI.rescue.hide()
		if rescueOnCircle and circles then
			circles:hide()
		end
		if rescueBar then
			rescueBar:hide()
		end
		if rescueTarget ~= nil then
			endRescue(false)
		end
	end

	function UI.rescue.isActive(): boolean
		return rescueTarget ~= nil
	end

	local function promptAttribute(prompt: ProximityPrompt, name: string): any
		local value = prompt:GetAttribute(name)
		if value == nil then
			local model = prompt:FindFirstAncestorOfClass("Model")
			if model then
				value = model:GetAttribute(name)
			end
		end
		if value == nil and prompt.Parent then
			value = (prompt.Parent :: Instance):GetAttribute(name)
		end
		return value
	end

	local function isCatPrompt(prompt: ProximityPrompt): boolean
		return prompt.Style == Enum.ProximityPromptStyle.Custom
			and promptAttribute(prompt, "CatId") ~= nil
	end

	-- Every other custom prompt (bait bowl, dealer cart, manhole, Bump) gets an action pill
	local function isActionPrompt(prompt: ProximityPrompt): boolean
		return prompt.Style == Enum.ProximityPromptStyle.Custom
			and promptAttribute(prompt, "CatId") == nil
	end

	-- The plot a prompt sits in (its nearest ancestor tagged Plot), or nil
	local function plotOf(prompt: ProximityPrompt): Instance?
		local node: Instance? = prompt.Parent
		while node do
			if CollectionService:HasTag(node, "Plot") then
				return node
			end
			node = node.Parent
		end
		return nil
	end

	-- GiftPrompts this client switched off on someone else's plot, each with the watch on the plot's owner that switches
	-- it back on if the plot becomes this player's (a plot keeps its prompt across owners).
	local mutedGifts: { [ProximityPrompt]: RBXScriptConnection } = {}

	local function muteGift(prompt: ProximityPrompt, plot: Instance)
		prompt.Enabled = false
		if mutedGifts[prompt] then
			return
		end
		local function release()
			local watch = mutedGifts[prompt]
			if watch then
				watch:Disconnect()
				mutedGifts[prompt] = nil
			end
		end
		mutedGifts[prompt] = plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
			if plot:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId then
				release()
				if prompt.Parent then
					prompt.Enabled = true
				end
			end
		end)
		prompt.Destroying:Once(release)
	end

	-- F64: a Mystery gift's GiftPrompt opens only for the plot's owner. On anyone else's plot this client switches the
	-- prompt off, so no pill shows and E does nothing, until the plot becomes this player's; the server checks the
	-- owner too. The owner's pill carries the gift's chances under it, shown before opening.
	local function giftNote(prompt: ProximityPrompt): (boolean, string?)
		if prompt.Name ~= "GiftPrompt" then
			return true, nil
		end
		local plot = plotOf(prompt)
		if plot and plot:GetAttribute("OwnerUserId") ~= Players.LocalPlayer.UserId then
			muteGift(prompt, plot)
			return false, nil
		end
		return true, PotionLogic.giftLine(PotionLogic.giftRows(currentCatalog), foodName)
	end

	local function infoFromPrompt(prompt: ProximityPrompt): Types.CatchInfo
		local catId = promptAttribute(prompt, "CatId")
		local def = lookupCat(if type(catId) == "string" then catId else nil)
		local catName = promptAttribute(prompt, "CatName")
		local rarity = promptAttribute(prompt, "Rarity")
		local strayId = promptAttribute(prompt, "StrayId")
		local stars = promptAttribute(prompt, "Stars")
		local charm = promptAttribute(prompt, "Charm")
		local rescue = promptAttribute(prompt, "Rescue")
		local rescueSpotId = promptAttribute(prompt, "RescueSpotId")
		local gold = promptAttribute(prompt, "Gold") -- a gold cat (was Shiny before 2026-10-27)
		local variant = promptAttribute(prompt, "Variant") -- F99: "rainbow" on a rainbow stray
		local pickUp = promptAttribute(prompt, "PickUp") == true -- v0.8 F56: no circles, the hold picks it up
		local returning = promptAttribute(prompt, "Returning") == true -- v0.10 F67: walking home
		local kind: Types.PromptKind = if rescue == true
			then "rescue"
			elseif pickUp then "pickup"
			else "swing"
		local fleeingUntil = promptAttribute(prompt, "FleeingUntil")
		-- v0.5 F41: a cat knocked loose by a shove waits for its old carrier first (reviewer N90)
		local dropOwner = promptAttribute(prompt, "DropOwner")
		local dropOwnerUntil = promptAttribute(prompt, "DropOwnerUntil")
		local player = Players.LocalPlayer
		local othersDrop = promptAttribute(prompt, "Dropped") == true
			and type(dropOwner) == "number"
			and (player == nil or dropOwner ~= player.UserId)
			and not pickUp -- v0.8 F56: a pick up has no owner window
		return {
			fleeingUntil = if type(fleeingUntil) == "number" then fleeingUntil else nil,
			ownerTurnUntil = if othersDrop and type(dropOwnerUntil) == "number"
				then dropOwnerUntil
				else nil,
			press = prompt.HoldDuration <= 0,
			shiny = gold == true,
			rainbow = variant == "rainbow",
			kind = kind,
			returning = pickUp and returning,
			rescueSpotId = if type(rescueSpotId) == "string"
				then rescueSpotId
				elseif type(strayId) == "string" then strayId
				else nil,
			stars = if type(stars) == "number" then stars else nil,
			charm = if type(charm) == "number" then charm else nil,
			catId = if type(catId) == "string" then catId else nil,
			strayId = if type(strayId) == "string" then strayId else nil,
			catName = if type(catName) == "string"
				then catName
				elseif def then def.name
				else prompt.ObjectText,
			rarity = if type(rarity) == "string"
				then rarity :: any
				elseif def then def.rarity
				else nil,
			holdDuration = prompt.HoldDuration,
			actionText = if prompt.ActionText ~= "" then prompt.ActionText else nil,
			keyCode = prompt.KeyboardKeyCode,
		}
	end

	-- Drives the prompt UI from every ProximityPrompt with Style = Custom and a CatId attribute
	-- (on the prompt, its model, or its parent). Cat prompts are held for HoldDuration (0.5 s since 2026-10-27; the
	-- card and the CATCH button fill over the hold), and the trigger fires
	-- events.grabBegan (a stray) or events.rescueBegan (a stuck cat, Rescue = true) and the server answers with
	-- catch.showCircles, UI.rescue.show or catch.fail. A dropped cat with PickUp = true fires events.pickUpBegan
	-- instead, and the carry starting (or catch.fail) is the answer. A press while the circles or the rescue bar are
	-- up is theirs, so it never asks again.
	-- Any other Style = Custom prompt (no CatId) gets an action pill (Screens/ActionPill) and raises no event: the
	-- game handles its Triggered as it would a default prompt's.
	-- v0.5: someone's miss sends the active stray running (its model's FleeingUntil changes). The card shows
	-- "It's running!" at once; during the circles or the rescue bar only the stored info changes, so the card is right
	-- when it comes back.
	-- F67: a dropped cat's PickUp, Returning and Dropped change as it walks home and arrives, so the card follows them too.
	local function watchStray(prompt: ProximityPrompt?)
		for _, connection in strayWatch do
			connection:Disconnect()
		end
		table.clear(strayWatch)
		if prompt == nil then
			return
		end
		local holder: Instance? = prompt:FindFirstAncestorOfClass("Model") or prompt.Parent
		if holder == nil then
			return
		end
		local model = holder :: Instance
		local function refresh()
			if prompt ~= activePrompt then
				return
			end
			if not UI.rescue.isActive() and not UI.catch.circlesActive() then
				UI.catch.show(infoFromPrompt(prompt))
			end
		end
		table.insert(
			strayWatch,
			model:GetAttributeChangedSignal("FleeingUntil"):Connect(function()
				if prompt ~= activePrompt then
					return
				end
				local value = model:GetAttribute("FleeingUntil")
				local info = activeInfo
				if info then
					info.fleeingUntil = if type(value) == "number" then value else nil
					info.retryAt = retryAtFor(info.strayId, info.fleeingUntil)
				end
				refresh()
			end)
		)
		for _, name in { "PickUp", "Returning", "Dropped" } do
			table.insert(strayWatch, model:GetAttributeChangedSignal(name):Connect(refresh))
		end
	end

	function UI.catch.bindProximityPrompts()
		if #promptConnections > 0 or not catch then
			return
		end
		local catchScreen = catch :: CatchPrompt.CatchPrompt

		local function onShown(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
			if isActionPrompt(prompt) then
				local show, note = giftNote(prompt)
				if show and actionPills then
					actionPills:show(prompt, inputType, note)
				end
				return
			end
			if not isCatPrompt(prompt) then
				return
			end
			activePrompt = prompt
			watchStray(prompt)
			UI.catch.show(infoFromPrompt(prompt))
		end
		table.insert(promptConnections, ProximityPromptService.PromptShown:Connect(onShown))
		table.insert(
			promptConnections,
			ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
				if actionPills then
					actionPills:hide(prompt)
				end
				if prompt ~= activePrompt then
					return
				end
				activePrompt = nil
				watchStray(nil)
				UI.catch.hide()
			end)
		)
		table.insert(
			promptConnections,
			ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt: ProximityPrompt)
				if actionPills and actionPills:isShown(prompt) then
					actionPills:holdBegan(prompt)
				elseif prompt == activePrompt then
					catchScreen:holdStart()
				end
			end)
		)
		table.insert(
			promptConnections,
			ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt: ProximityPrompt)
				if actionPills and actionPills:isShown(prompt) then
					actionPills:holdEnded(prompt)
				elseif prompt == activePrompt then
					catchScreen:holdStop()
				end
			end)
		)
		table.insert(
			promptConnections,
			ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
				if actionPills and actionPills:isShown(prompt) then
					-- the game's own Triggered handler does the work; the pill only answers the press
					actionPills:triggered(prompt)
					return
				end
				if prompt ~= activePrompt then
					return
				end
				-- E or the CATCH button while the circles or the bar are up is a press on them, not a new ask
				-- (the server would only answer "Keep going, the bar is up")
				if UI.rescue.isActive() or UI.catch.circlesActive() then
					return
				end
				-- one press asks the server to start: GrabBegin answers with the circles (catch.showCircles),
				-- RescueBegin with the minigame (UI.rescue.show), a refusal with catch.fail
				local info = activeInfo
				-- v0.5: the server would only refuse ("It's running!", or the missing player's short wait), so say it
				-- here and ask nothing
				local blocked = if info and info.kind ~= "rescue"
					then catchScreen:blockedText()
					else nil
				if blocked then
					catchScreen:fail(blocked, true)
					return
				end
				catchScreen:waiting()
				if info and info.kind == "rescue" then
					UI.events.rescueBegan:Fire(info.rescueSpotId, info.catId)
				elseif info and info.kind == "pickup" then
					UI.events.pickUpBegan:Fire(info.strayId, info.catId)
				else
					UI.events.grabBegan:Fire(
						if info then info.strayId else nil,
						if info then info.catId else nil
					)
				end
			end)
		)
		-- the mobile CATCH button drives the real prompt, so nothing changes server side
		table.insert(
			promptConnections,
			catchScreen.holdBegan:Connect(function()
				local prompt = activePrompt
				if prompt then
					prompt:InputHoldBegin()
				end
			end) :: any
		)
		table.insert(
			promptConnections,
			catchScreen.holdEnded:Connect(function()
				local prompt = activePrompt
				if prompt then
					prompt:InputHoldEnd()
				end
			end) :: any
		)
	end

	function UI.catch.unbindProximityPrompts()
		for _, connection in promptConnections do
			(connection :: any):Disconnect()
		end
		table.clear(promptConnections)
		for _, watch in mutedGifts do
			watch:Disconnect()
		end
		table.clear(mutedGifts)
		watchStray(nil)
		activePrompt = nil
	end
end

----------------------------------------------------------------------------------------------------
-- Day and night clock (HUD chip, F20)
----------------------------------------------------------------------------------------------------

UI.clock = {}

local clockConnections: { RBXScriptConnection } = {}

-- phaseEndsAt is server os.time() seconds (the Clock folder's PhaseEndsAt). The chip counts down
-- against Workspace:GetServerTimeNow(), so nothing here reads the device clock. F60 (data-model section 8): when
-- night falls on a player with an empty bowl, one toast says night bait comes in half the time.
function UI.clock.set(phase: Types.ClockPhase, phaseEndsAt: number)
	local previous = clockPhase
	clockPhase = phase
	if previous == "night" and phase == "day" and areaTitle then
		areaTitle:banner(
			"sunrise",
			"Sunrise!",
			"Fresh cats in every area.",
			Theme.colors.gold,
			SUNRISE_HOLD
		)
	end
	if
		previous == "day"
		and phase == "night"
		and bowls.views[1] == nil
		and (state.upgradeLevels.lure_bowl or 0) >= 1
	then
		UI.toast(
			Theme.icons.moon .. " Night bait! Food in your bowl now brings a cat in half the time.",
			"info"
		)
	end
	-- #1157 (Derek 11-04: "a UI bubble pop-up at nightfall so players know there's more to do at night"): once a night,
	-- at Tier 2 and up (where the dealer's tip starts, shared/Tips), a big banner that the Night Market is open, once
	-- the cart is really out (DealerCart, Open) and nothing else is on screen: not during a catch, a rescue, a carry,
	-- the intro, a tip or an open window (UI.tips.quiet). It waits up to 2 minutes for that moment, then lets it go.
	if previous == "day" and phase == "night" and (state.tier or 1) >= 2 then
		local clock: any = UI.clock
		if clock.marketNight ~= phaseEndsAt then
			clock.marketNight = phaseEndsAt
			task.spawn(function()
				for _ = 1, 60 do
					task.wait(2)
					if clockPhase ~= "night" then
						return
					end
					local open = false
					for _, cart in CollectionService:GetTagged("DealerCart") do
						if
							cart:IsDescendantOf(Workspace)
							and cart:GetAttribute("Open") ~= false
						then
							open = true
						end
					end
					local tips: any = UI.tips
					local banner = areaTitle
					local windows = modal
					if
						open
						and banner
						and windows
						and windows:current() == nil
						and tips.quiet()
					then
						banner:banner(
							"night_market",
							Theme.icons.moon .. " The Night Market is open!",
							"Rare foods tonight at the dealer's cart in town.",
							Theme.colors.berry,
							6
						)
						return
					end
				end
			end)
		end
	end
	watchDusk(phase, phaseEndsAt)
	if hud then
		hud:setClock({ phase = phase, phaseEndsAt = phaseEndsAt })
	end
	if cannonScreen then
		cannonScreen:setClock(phase, phaseEndsAt)
	end
	if baitScreen then
		baitScreen:setNight(phase == "night")
	end
	if dealerScreen then
		dealerScreen:setNight(phase == "night")
	end
	if tipJarScreen then
		tipJarScreen:setNight(phase == "night")
	end
	if spinScreen then
		spinScreen:setNight(phase == "night")
	end
	if collection then
		collection:setNight(phase == "night")
	end
	if indexBoards then
		indexBoards:setNight(phase == "night")
	end
	if codesScreen then
		codesScreen:setNight(phase == "night")
	end
	if questsScreen then
		questsScreen:setNight(phase == "night")
	end
	if dailyTreatScreen then
		dailyTreatScreen:setNight(phase == "night")
	end
end

function UI.clock.clear()
	clockPhase = nil
	duskToken += 1
	duskEndsAt = nil
	if hud then
		hud:setClock(nil)
	end
	if baitScreen then
		baitScreen:setNight(false)
	end
	if dealerScreen then
		dealerScreen:setNight(nil)
	end
	if cannonScreen then
		cannonScreen:setClock(nil, nil)
	end
end

-- F66: false from dusk to sunrise. The Alley button and every Go in the Areas panel grey with a moon, so nobody asks
-- for a trip the server refuses. The server's fences and sends-home do the rest.
function UI.clock.setAreasOpen(open: boolean)
	if hud then
		hud:setAreasOpen(open)
	end
	if areasScreen then
		areasScreen:setAreasOpen(open)
		if hud then
			areasScreen:render(state, hud:isCarrying())
		end
	end
	if cannonScreen then
		cannonScreen:setAreasOpen(open)
	end
end

-- Reads Phase, PhaseEndsAt and AreasOpen from the Clock folder (ReplicatedStorage.Clock) and follows changes. The
-- server sets Phase and PhaseEndsAt together, so a change is read once at the end of the frame: a new Phase with
-- the old PhaseEndsAt would read as the last second of the day and show the dusk banner at sunrise.
function UI.clock.bind(clock: Instance)
	UI.clock.unbind()
	local function read()
		local phase = clock:GetAttribute("Phase")
		local endsAt = clock:GetAttribute("PhaseEndsAt")
		if (phase == "day" or phase == "night") and type(endsAt) == "number" then
			UI.clock.set(phase :: Types.ClockPhase, endsAt)
		else
			UI.clock.clear()
		end
		UI.clock.setAreasOpen(NightClock.areasOpen(clock:GetAttribute("AreasOpen")))
		-- F88: the next Lucky Day under the clock
		if hud then
			local day, nextDay = clock:GetAttribute("Day"), clock:GetAttribute("NextLuckyDay")
			hud:setLuckyDay({
				day = if type(day) == "number" then day else nil,
				nextLuckyDay = if type(nextDay) == "number" then nextDay else nil,
				luckyDay = clock:GetAttribute("LuckyDay") == true,
			})
		end
	end
	local queued = false
	local function queueRead()
		if queued then
			return
		end
		queued = true
		task.defer(function()
			queued = false
			read()
		end)
	end
	for _, name in { "Phase", "PhaseEndsAt", "AreasOpen", "Day", "NextLuckyDay", "LuckyDay" } do
		table.insert(clockConnections, clock:GetAttributeChangedSignal(name):Connect(queueRead))
	end
	read()
end

function UI.clock.unbind()
	for _, connection in clockConnections do
		connection:Disconnect()
	end
	table.clear(clockConnections)
end

-- F88 (luck-and-rare-moments.md 1c): UIController's Lucky Day moments, with shared Luck's lines. "warning" comes
-- LuckyDayWarnSeconds before its sunrise: a banner at once ("Lucky Day soon!" over the line). "start" comes as
-- LuckyDay turns true at that sunrise: the banner ("Lucky Day!" over "Rare cats are twice as likely until night")
-- waits until the sunrise banner has had its SUNRISE_HOLD, in step with Audio's chime after the sunrise sting. The
-- HUD's Luck chip glows from the server's next sync.
function UI.luckyDay(kind: string, line: string)
	if type(line) ~= "string" then
		return
	end
	if kind == "warning" then
		if areaTitle then
			areaTitle:banner("lucky_warning", "Lucky Day soon!", line, Theme.colors.gold, 4)
		end
		return
	end
	if kind ~= "start" then
		return
	end
	local title, rest = line:match("^(.-!)%s+(.+)$")
	task.delay(SUNRISE_HOLD + 0.4, function()
		if areaTitle then
			areaTitle:banner("lucky_day", title or line, rest, Theme.colors.gold, 4)
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- Context tips (F87, easy-start.md section 3)
----------------------------------------------------------------------------------------------------

-- A tip shows once per account, the first time a player meets something. The server sends ShowTip for the ones it
-- can see (UIController calls UI.tips.show); this finds the ones only the client can see: a stuck cat within
-- 30 studs (`stuck_cat`), the Codes Cat within 20 (`codes_cat`), the offline card's line after
-- Tips.OFFLINE_SECONDS away (`offline`) and F88's `luck` once the HUD's Luck chip shows (the first Luck source). Components/TipQueue times them: never
-- during a catch, rescue, carry, the intro, a flight or a window, one every TipGapSeconds, three waiting at most.
-- A card fires tipSeen as it shows; a camera cut fires it when it ends, skipped or not. The client-found tips wait
-- for ProfileSync's tipsSeen, so nothing is shown again every session before the save says what was seen.
--
-- Camera cuts are the effects code's (section 7: ContextCut). Until a cut player is set (UI.tips.setCutPlayer), a cut
-- tip shows as a card with its own line. The player is called as play(id, caption, seconds, done) and returns true
-- when it moved the camera; it freezes controls, draws the caption, takes the skip after 1 s and calls done(skipped)
-- once at the end. A false (the place has not streamed in) shows the card instead.

export type CutPlayer = (
	id: string,
	caption: string,
	seconds: number,
	done: (skipped: boolean) -> ()
) -> boolean

-- one block, so its locals do not count against the module's 200 (Luau's limit per function)
UI.tips = {}
UI.asks = {}
do
	local Tips = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tips")) :: any

	local cutSeconds: number = math.min(3, (Config :: any).TipCutMaxSeconds or 4)
	-- one table, as the module is short of locals
	local TIP = {
		GAP = ((Config :: any).TipGapSeconds or 60) :: number,
		CUT_SECONDS = cutSeconds,
		CUT_TIMEOUT = cutSeconds + 3, -- a cut whose done never comes frees the queue after this
		STUCK_RANGE = 30, -- studs from a stuck cat (section 3: "within 30 studs")
		CODES_RANGE = 20,
		CODES_TAG = "CodesCat", -- shared/Codes.TAG, the Codes Cat's station
		PUMP_EVERY = 0.25,
		LOOK_EVERY = 1,
	}

	local tipQueue = TipQueue.new(TIP.GAP)
	local tipAnswered: { [string]: boolean } = {} -- tips shown this session, before ProfileSync's tipsSeen says so
	local tipBusy = false -- a card or a cut is showing
	local cutPlayer: CutPlayer? = nil
	local clocks = { pump = 0, look = 0 }

	-- Seen on the save or shown this session.
	local function tipKnown(id: string): boolean
		local seen: { [string]: boolean }? = state.tipsSeen
		return tipAnswered[id] == true or (seen ~= nil and seen[id] == true)
	end

	local function answerTip(id: string, skipped: boolean)
		tipAnswered[id] = true
		UI.events.tipSeen:Fire(id, skipped)
	end

	local function tipDevice(): TipQueue.Device
		return TipQueue.device(UserInputService:GetLastInputType().Name, Scale.isTouch())
	end

	-- The area the next rank up opens, for rank_up's line.
	local function nextAreaName(): string?
		for _, area in catalogAreas() do
			if area.tier == state.tier + 1 then
				return area.name
			end
		end
		return nil
	end

	local function tipMoment(): TipQueue.Moment
		local duskLeft: number? = nil
		local endsAt = duskEndsAt
		if endsAt ~= nil then
			duskLeft = endsAt - Workspace:GetServerTimeNow()
		end
		return {
			catching = UI.catch.circlesActive(),
			rescuing = UI.rescue.isActive(),
			carrying = hud ~= nil and hud:isCarrying(),
			intro = UI.intro.playing(),
			flying = os.clock() < tipsHeldUntil,
			window = (modal ~= nil and modal:current() ~= nil)
				or (popups ~= nil and popups:isShowing())
				or (baitCard ~= nil and baitCard:isShowing())
				or (askCard ~= nil and askCard:isShowing()),
			hidden = not visible,
			duskLeft = duskLeft,
		}
	end

	-- Shows the next waiting tip when the moment is free and the gap has run.
	local function pumpTips()
		local card = tipCard
		-- the Tutorial tile's × (its setting off) holds the tip cards back too (Derek 2026-11-03)
		if
			card == nil
			or tipBusy
			or not initialized
			or not tutorialButtonOn
			or tipQueue:size() == 0
		then
			return
		end
		if not TipQueue.free(tipMoment()) then
			return
		end
		local now = os.clock()
		local picked = tipQueue:take(now)
		while picked ~= nil and tipKnown(picked) do
			picked = tipQueue:take(now)
		end
		if picked == nil then
			return
		end
		local id: string = picked -- closures below do not keep the refinement
		tipQueue:shown(now)
		local device: TipQueue.Device = tipDevice()
		local area = nextAreaName()
		local def = Tips.get(id)
		local play = cutPlayer
		if def ~= nil and def.kind == "cut" and play ~= nil then
			local caption = TipQueue.line(id, device, true, area) or ""
			local finished = false
			local function done(skipped: boolean)
				if finished then
					return
				end
				finished = true
				tipBusy = false
				answerTip(id, skipped == true)
			end
			tipBusy = true
			local ok, played = pcall(play, id, caption, TIP.CUT_SECONDS, done)
			if ok and played == true then
				task.delay(TIP.CUT_TIMEOUT, function()
					done(false)
				end)
				return
			end
			finished = true
			tipBusy = false
		end
		local text = TipQueue.line(id, device, false, area)
		if text == nil then
			return
		end
		tipBusy = true
		answerTip(id, false)
		card:show(text, TipQueue.icon(id), TipQueue.CARD_SECONDS, function()
			tipBusy = false
		end)
	end

	local function characterPosition(): Vector3?
		local character = Players.LocalPlayer and Players.LocalPlayer.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		return if root ~= nil and root:IsA("BasePart") then (root :: BasePart).Position else nil
	end

	-- Whether any instance with `tag` in the world stands within `range` studs of `from`.
	local function taggedNear(tag: string, from: Vector3, range: number): boolean
		for _, instance in CollectionService:GetTagged(tag) do
			if instance:IsDescendantOf(Workspace) then
				local position: Vector3? = if instance:IsA("Model")
					then (instance :: Model):GetPivot().Position
					elseif instance:IsA("BasePart") then (instance :: BasePart).Position
					else nil
				if position ~= nil and (position - from).Magnitude <= range then
					return true
				end
			end
		end
		return false
	end

	-- The client-found tips, once the save says which were seen.
	local function lookForTips()
		if state.tipsSeen == nil then
			return
		end
		-- F88 (luck-and-rare-moments.md 1d): the first Luck source lifts luck above 1x, and that shows the tip (the chip
		-- itself always shows since #1150)
		if not tipKnown("luck") and hud ~= nil and hud:luckShown() then
			UI.tips.show("luck")
		end
		local from = characterPosition()
		if from == nil then
			return
		end
		if not tipKnown("stuck_cat") and taggedNear("StuckCat", from, TIP.STUCK_RANGE) then
			UI.tips.show("stuck_cat")
		end
		if not tipKnown("codes_cat") and taggedNear(TIP.CODES_TAG, from, TIP.CODES_RANGE) then
			UI.tips.show("codes_cat")
		end
	end

	-- Nothing else is going on and no tip is showing: the one feedback ask may slide in.
	function UI.tips.quiet(): boolean
		return not tipBusy and TipQueue.free(tipMoment())
	end

	ticks.tips = function(dt: number)
		clocks.pump += dt
		clocks.look += dt
		if clocks.look >= TIP.LOOK_EVERY then
			clocks.look = 0
			lookForTips()
			local ask: any = UI.tips -- lookForAsk is set by the ask's block below
			ask.lookForAsk()
		end
		if clocks.pump >= TIP.PUMP_EVERY then
			clocks.pump = 0
			pumpTips()
		end
	end

	-- A tip's moment came: ShowTip from the server, or the client's own finds. Queued and timed; unknown ids, the two
	-- asks the UI times itself (feedback_ask, stuck_help) and tips already seen are left alone.
	function UI.tips.show(id: string)
		if type(id) ~= "string" or (Tips.get(id) == nil and id ~= Tips.LIKE_ASK) then
			return
		end
		if tipKnown(id) or tipQueue:has(id) then
			return
		end
		tipQueue:push(id)
		pumpTips()
	end

	-- F96 (starter-cat.md section 3): the favorite and like asks on the tip card, with a star or a thumb. UIController's
	-- showAsk calls it at a quiet moment and answers TipSeen itself, so this does not fire tipSeen; it shows the card
	-- and says true, or false (a tip or another card is up, or the id is not one of the two) for the toast instead.
	-- The ask counts as this session's tip for the gap. The notification ask is Roblox's prompt, never this.
	-- F92: the invite ask is the slide-in card with an Invite button instead (UI.together.inviteAsk).
	function UI.asks.show(id: string): boolean
		if id == Tips.INVITE_ASK then
			local together: any = UI.together -- filled later in the file
			return together.inviteAsk()
		end
		local card = tipCard
		if
			card == nil
			or tipBusy
			or not initialized
			or (id ~= Tips.FAVORITE_ASK and id ~= Tips.LIKE_ASK)
			or not TipQueue.free(tipMoment())
		then
			return false
		end
		local text = TipQueue.line(id, tipDevice())
		if text == nil then
			return false
		end
		tipBusy = true
		tipAnswered[id] = true -- so the queue never shows it again this session
		tipQueue:shown(os.clock())
		card:show(text, TipQueue.icon(id), TipQueue.ASK_SECONDS, function()
			tipBusy = false
		end)
		return true
	end

	-- The effects code's camera cut player (see above), or nil to show cut tips as cards.
	function UI.tips.setCutPlayer(play: CutPlayer?)
		cutPlayer = play
	end

	-- The offline card's top line (`offline`) for a return after `seconds` away, sent as seen; nil when it has been seen
	-- or the save has not said yet.
	function UI.tips.offlineLine(seconds: number): string?
		if
			state.tipsSeen == nil
			or seconds < (Tips.OFFLINE_SECONDS :: number)
			or tipKnown("offline")
		then
			return nil
		end
		answerTip("offline", false)
		return TipQueue.line("offline", tipDevice())
	end

	-- Forgets this session's tips and empties the queue (Show tips again, and UI.destroy). The server clears tipsSeen.
	function UI.tips.reset()
		table.clear(tipAnswered)
		tipQueue:clear()
		if state.tipsSeen ~= nil then
			(state :: any).tipsSeen = Tips.cleared(state.tipsSeen)
		end
		local card = tipCard
		if card ~= nil and card:isShowing() then
			card:hide()
		end
		tipBusy = false
	end
end

-- F87 section 4: the one slide-in faces ask, once per account, after FeedbackAskMinutes of this session's play and
-- only between activities (UI.tips.quiet: no tip showing either). It waits for ProfileSync's feedbackAsked (false,
-- not nil). Its own block, as the module is short of locals.
do
	local FeedbackLogic = require(script.Components.FeedbackLogic)
	local Tips = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tips")) :: any
	local sessionStart = os.clock()
	local asked = false -- this session

	local function openAsk(card: AskCard.AskCard)
		asked = true
		local faces: { AskCard.Choice } = {}
		for _, face in FeedbackLogic.FACES do
			table.insert(faces, { id = face.id, label = face.label, icon = face.glyph })
		end
		card:show({
			title = "How is it so far?",
			choices = faces,
			seconds = FeedbackLogic.ASK_SECONDS,
			thanks = "Thanks!",
			answer = function(face: string?)
				if face ~= nil then
					(state :: any).feedbackAsked = true
					UI.events.sendFeedback:Fire(face, nil)
				end
			end,
		})
		local saved: any = state
		saved.feedbackAsked = true
		UI.events.tipSeen:Fire(Tips.FEEDBACK_ASK, false)
	end

	-- From the tips clock, once a second.
	function UI.tips.lookForAsk()
		local card = askCard
		if asked or card == nil or card:isShowing() then
			return
		end
		local played = os.clock() - sessionStart
		if FeedbackLogic.askDue(state.feedbackAsked, played, UI.tips.quiet()) then
			openAsk(card)
		end
	end

	-- The slide-in faces ask now, whatever the clock says (QA in Studio and the UI gate). It is saved as shown.
	function UI.tips.showAsk()
		local card = askCard
		if card ~= nil and not card:isShowing() then
			openAsk(card)
		end
	end
end

-- F87 (easy-start.md sections 2e and 2g): the tutorial strip's device-aware words (UI.tutorial.hint), the nudges when
-- a step stalls and the "Need a hand?" card. A step's clock runs only while its hint shows and nothing else goes on
-- (UI.tips.quiet). After StuckNudgeSeconds (40) and every 40 s after, the strip pulses and the trail is drawn again
-- from where the character stands; after StuckHelpSeconds (90) the card asks once per step per account (the server
-- saves it in stuckHelpShown on TipSeen("stuck_help")). Show me plays the intro for steps 0 to 2 and opens the screen
-- of steps 3 and 4. Each nudge fires events.stuckNudge. Its own block, as the module is short of locals.
do
	local TutorialHints = require(script.Components.TutorialHints)
	local Tips = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tips")) :: any
	local NUDGE = {
		PULSE = ((Config :: any).StuckNudgeSeconds or 40) :: number,
		HELP = ((Config :: any).StuckHelpSeconds or 90) :: number,
		CARD_SECONDS = 12, -- the help card stays this long
		EVERY = 0.25,
	}
	-- the controller's last state and the line it was given, so a switch of input can say it again
	local hinted: { state: any, text: string?, device: TipQueue.Device? } = {}
	local stall = { step = -1, seconds = 0, pulses = 0, asked = false, clock = 0 }

	local function inputDevice(): TipQueue.Device
		return TipQueue.device(UserInputService:GetLastInputType().Name, Scale.isTouch())
	end

	local function hintFor(s: any, device: TipQueue.Device): string?
		local catalog = currentCatalog
		local levels: { [string]: number } = s.upgradeLevels or {}
		return TutorialHints.line({
			step = s.tutorialStep or TutorialHints.DONE,
			device = device,
			resting = TutorialHints.resting(
				s.cats,
				if catalog then catalog.spots else nil,
				s.tier or 1
			),
			bowl = (levels.lure_bowl or 0) >= 1,
			baited = s.bait ~= nil,
		})
	end

	-- UIController's tutorialLine: the strip's words for this state on the input the player used last, or nil from
	-- step 5 (the controller then keeps its own line, and hides the strip).
	function UI.tutorial.hint(s: any): string?
		local device: TipQueue.Device = inputDevice()
		local text = hintFor(s, device)
		hinted.state, hinted.text, hinted.device = s, text, device
		return text
	end

	-- The strip says its line again when the input changes (a pad picked up, a tap on a touch laptop).
	local function followInput()
		local s = hinted.state
		if s == nil or hinted.text == nil or tutorialText ~= hinted.text then
			return
		end
		local device: TipQueue.Device = inputDevice()
		if device == hinted.device then
			return
		end
		hinted.device = device
		local text = hintFor(s, device)
		if text ~= nil then
			hinted.text = text
			tutorialText = text
			applyTutorial()
		end
	end

	-- Show me on the help card.
	local function showMe(step: number)
		UI.events.stuckNudge:Fire("show_me")
		local levels: { [string]: number } = state.upgradeLevels or {}
		if step <= 2 then
			UI.events.introChoice:Fire("help")
			UI.events.introReplay:Fire()
		elseif step == 4 and (levels.lure_bowl or 0) >= 1 then
			UI.bait.openPicker()
		elseif modal ~= nil then
			modal:open("Upgrades")
		end
	end

	-- The "Need a hand?" card for this step, saved as shown at once.
	local function askHelp(step: number)
		local card = askCard
		if card == nil then
			return
		end
		stall.asked = true
		local key = tostring(math.clamp(step, 0, TutorialHints.DONE))
		local shown: { [string]: boolean } = table.clone(state.stuckHelpShown or {})
		shown[key] = true
		(state :: any).stuckHelpShown = shown
		UI.events.stuckNudge:Fire("help_shown")
		UI.events.tipSeen:Fire(Tips.STUCK_HELP, false)
		card:show({
			title = "Need a hand?",
			choices = {
				{ id = "show", label = "Show me", icon = Theme.icons.tutorial, style = "gold" },
				{ id = "ok", label = "Got it", style = "ghost" },
			},
			seconds = NUDGE.CARD_SECONDS,
			answer = function(id: string?)
				if id == "show" then
					showMe(step)
				end
			end,
		})
	end

	-- The strip pulses and the trail starts again from the character.
	local function pulse()
		stall.pulses += 1
		if hud then
			hud:pulseTutorial()
		end
		if tutorialTrail then
			tutorialTrail:hide()
		end
		applyTutorial()
		UI.events.stuckNudge:Fire("pulse")
	end

	ticks.nudges = function(dt: number)
		stall.clock += dt
		if stall.clock < NUDGE.EVERY then
			return
		end
		local elapsed = stall.clock
		stall.clock = 0
		followInput()
		local step = state.tutorialStep
		if step == nil or step >= TutorialHints.DONE or not initialized then
			return
		end
		if step ~= stall.step then
			stall.step, stall.seconds, stall.pulses, stall.asked = step, 0, 0, false
		end
		if tutorialText == nil or not UI.tips.quiet() then
			return
		end
		stall.seconds += elapsed
		if stall.seconds >= NUDGE.PULSE * (stall.pulses + 1) then
			pulse()
		end
		local seen: { [string]: boolean } = state.stuckHelpShown or {}
		if
			stall.seconds >= NUDGE.HELP
			and not stall.asked
			and state.stuckHelpShown ~= nil
			and not seen[tostring(step)]
		then
			askHelp(step)
		end
	end

	-- The help card now, for this step (QA in Studio and the UI gate). It is saved as shown.
	function UI.tutorial.showHelp()
		local step = state.tutorialStep or 0
		askHelp(math.min(step, TutorialHints.DONE - 1))
	end
end

----------------------------------------------------------------------------------------------------
-- The free Bellhop Cat (F96, starter-cat.md section 2)
----------------------------------------------------------------------------------------------------

-- The stand card (Screens/StarterCat), built the first time it opens and registered with the window manager as
-- "StarterCat". StarterCatController calls open(view) within StarterCatRangeStuds of a BellhopStand, close() a stud
-- past it, update(view) every 0.2 s while open and result(ok, reason) from StarterCatResult. A claim that works
-- closes the card and shows the claim card: the cat found card with "The Bellhop Cat joined your cafe!" (the
-- server's toast says where it went). Its own block, as the module is short of locals.
UI.starterCat = {}
do
	local StarterCatScreen = require(script.Screens.StarterCat)
	local StarterCatRules =
		require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StarterCat")) :: any
	local stand = {
		screen = nil :: StarterCatScreen.StarterCat?,
		modal = nil :: Modal.Modal?, -- the window manager it is registered with; a new UI.init makes it again
		view = nil :: StarterCatScreen.View?,
	}

	local function screenFor(): StarterCatScreen.StarterCat?
		local manager = modal
		if manager == nil then
			return nil
		end
		local screen = stand.screen
		if screen ~= nil and stand.modal == manager then
			return screen
		end
		if screen ~= nil then
			screen:destroy() -- the last UI.init's, whose windows are gone
		end
		local made = StarterCatScreen.new({
			claim = function()
				UI.events.claimStarterCat:Fire()
			end,
			join = function()
				UI.events.joinGroup:Fire()
			end,
			close = function()
				UI.starterCat.close()
			end,
		})
		manager:register("StarterCat", {
			frame = made.frame,
			onOpen = function()
				made:onOpen()
			end,
			onClose = function()
				made:onClose()
			end,
		})
		stand.screen, stand.modal = made, manager
		return made
	end

	local function paint(view: StarterCatScreen.View)
		stand.view = view
		local screen = screenFor()
		if screen ~= nil then
			screen:show(view, lookupCat(StarterCatRules.CAT_ID))
		end
	end

	-- Opens the card with this view, unless another window is open (the Codes Cat and the Spin Wheel stand near).
	function UI.starterCat.open(view: StarterCatScreen.View)
		paint(view)
		if modal ~= nil and stand.screen ~= nil and modal:current() == nil then
			modal:open("StarterCat")
		end
	end

	-- Closes the card if it is the open window.
	function UI.starterCat.close()
		if modal ~= nil and modal:current() == "StarterCat" then
			modal:close()
		end
	end

	-- The view again while open; repaints only on a change.
	function UI.starterCat.update(view: StarterCatScreen.View)
		paint(view)
	end

	-- StarterCatResult(ok, reason): ok closes the card and shows the claim card; a refusal is the card's status line,
	-- or a toast when the card was closed first.
	function UI.starterCat.result(ok: boolean, reason: string?)
		local screen = stand.screen
		if screen ~= nil then
			screen:result(ok, reason)
		end
		local open = modal ~= nil and modal:current() == "StarterCat"
		if not ok then
			if not open and reason ~= nil then
				UI.toast(reason, "warn")
			end
			return
		end
		UI.starterCat.close()
		local def = lookupCat(StarterCatRules.CAT_ID)
		local view = stand.view
		if def ~= nil and popups ~= nil then
			popups:showCatFound(def, true, {
				banner = "FREE " .. def.rarity:upper() .. " CAT!",
				line = ("The %s joined your cafe!"):format(def.name),
				rate = if view ~= nil then view.rate else nil,
			})
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Rare moments (F89)
----------------------------------------------------------------------------------------------------

-- The big pull card (luck-and-rare-moments.md 2a and 2b, Screens/BigPull), built the first time it shows in the
-- PlayerGui of the current UI.init. UIController calls securedRare from SecuredRare and foundRareDecor from
-- FoundRareDecor; the Fish Market's reveal calls bigPull.piece for a Legendary or Mythical piece. Its own block, as
-- the module is short of locals.
UI.bigPull = {}
do
	local BigPullLogic = require(script.Components.BigPullLogic)
	local BigPullScreen = require(script.Screens.BigPull)
	local DecorPieces = require(script.Components.DecorPieces)
	local RareMoments =
		require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RareMoments")) :: any
	local pull = {
		screen = nil :: BigPullScreen.BigPull?,
		parent = nil :: Instance?, -- the PlayerGui it was built in
	}

	local function screenFor(): BigPullScreen.BigPull?
		local into = parentGui
		if into == nil then
			return nil
		end
		local screen = pull.screen
		if screen ~= nil and pull.parent == into then
			return screen
		end
		if screen ~= nil then
			screen:destroy()
		end
		local made = BigPullScreen.new(into)
		pull.screen, pull.parent = made, into
		return made
	end

	local function findDecor(decorId: string): Types.DecorDef?
		local catalog = currentCatalog
		if catalog == nil then
			return nil
		end
		for _, list in { catalog.decor, catalog.crateDecor or {} } :: { { Types.DecorDef } } do
			for _, decor in list do
				if decor.id == decorId then
					return decor
				end
			end
		end
		return nil
	end

	-- SecuredRare(userId, catId, rarity, gold, variant), sent to every client: the card plays on the securing player's
	-- screen only. Everyone else has the server's Announce toast ("Sam secured a Mythical Jazz Cat!"), so nothing here.
	-- A first Epic comes to its owner alone, as a plain Epic, and gets the smaller card.
	function UI.securedRare(
		userId: number,
		catId: string,
		rarity: string,
		gold: boolean?,
		variant: string?
	)
		if not BigPullLogic.mine(userId, Players.LocalPlayer.UserId) then
			return
		end
		local card: BigPullLogic.Card? = BigPullLogic.forCat(rarity, gold, variant)
		local def = lookupCat(catId)
		if card == nil or def == nil then
			return
		end
		local screen = screenFor()
		if screen == nil then
			return
		end
		screen:show({
			card = card,
			rarity = rarity,
			word = BigPullLogic.word(card, rarity, gold, variant),
			tone = BigPullLogic.tone(gold, variant),
			name = def.name, -- the cat's kind, never its nickname
			cat = def,
			shiny = gold == true or variant == "gold",
		})
	end

	-- FoundRareDecor(userId, decorId), sent to every client for a Mythical crate piece: the finder has the reveal and
	-- the big card, so everyone else gets the shout-out toast, "Sam found the Mythical Midnight Sky!".
	function UI.foundRareDecor(userId: number, decorId: string)
		local finder = Players:GetPlayerByUserId(userId)
		local decor = findDecor(decorId)
		if finder == nil or finder == Players.LocalPlayer or decor == nil then
			return
		end
		UI.announce(RareMoments.decorText(finder.DisplayName, decor.name), "Mythical")
	end

	-- RainbowSpawned's toast (F99, rainbow-coat.md section 2), sent to everyone at most once a minute: "🌈 A Rainbow
	-- Tabby is out in the Woods!" on the cat's rarity colour with a turning rainbow edge. The beam and shimmer are
	-- VFX-Agent's and Sound-Agent's (Moments.RainbowSpawned).
	function UI.rainbowSpawned(areaId: string, catId: string)
		local def = lookupCat(catId)
		local catalog: Types.Catalog? = currentCatalog
		local areas: { Types.AreaDef } = {}
		if catalog and catalog.areas then
			areas = catalog.areas
		end
		local areaName: string? = nil
		for _, area in areas do
			if area.id == areaId then
				areaName = area.name
			end
		end
		local view = toasts
		if def == nil or view == nil then
			return
		end
		view:rainbow(
			CatVariant.spawnLine(def.name, areaName or Format.areaName(areaId)),
			def.rarity
		)
	end

	-- A Legendary or Mythical crate piece's card, with onUse for "Use it" on a new style piece; any other piece plays
	-- nothing.
	function UI.bigPull.piece(decorId: string, onUse: (() -> ())?)
		local decor = findDecor(decorId)
		local piece = DecorPieces.info(decor)
		local rarity = piece.rarity
		local card: BigPullLogic.Card? = BigPullLogic.forPiece(rarity)
		if decor == nil or rarity == nil or card == nil then
			return
		end
		local screen = screenFor()
		if screen == nil then
			return
		end
		screen:show({
			card = card,
			rarity = rarity,
			word = BigPullLogic.word(card, rarity),
			tone = "rarity",
			name = decor.name,
			piece = {
				asset = decor.asset,
				glyph = DecorPieces.kindIcon(piece.kind, Theme.icons.decor),
			},
			onUse = onUse,
		})
	end

	-- UI.destroy: the card goes with the rest of the screens.
	function UI.bigPull.reset()
		local screen = pull.screen
		if screen ~= nil then
			screen:destroy()
		end
		pull.screen, pull.parent = nil, nil
	end
end

----------------------------------------------------------------------------------------------------
-- Leaderboards (F98)
----------------------------------------------------------------------------------------------------

-- The three leaderboards (leaderboards.md): the faces on the town's boards (Screens/LeaderboardBoards) and the crown
-- over an all time top 10 player's head (Screens/Crowns); the Index's Top tab went on 2026-11-03. UI.init
-- starts the faces and crowns; UIController calls UI.leaderboards.sync with each LeaderboardSync payload. The last
-- payload is kept, so a rebuilt UI shows it at once. Its own block, as the module is short of locals.
UI.leaderboards = {}
do
	local LeaderboardBoards = require(script.Screens.LeaderboardBoards)
	local Crowns = require(script.Screens.Crowns)
	local LeaderboardLogic = require(script.Components.LeaderboardLogic)
	local boards = {
		faces = nil :: LeaderboardBoards.LeaderboardBoards?,
		crowns = nil :: Crowns.Crowns?,
		last = nil :: LeaderboardLogic.Sync?,
	}

	-- UI.init: the faces hang on every tagged board, including ones that stream in later.
	function UI.leaderboards.start(parent: Instance)
		UI.leaderboards.reset()
		local faces = LeaderboardBoards.new(parent)
		boards.faces = faces
		boards.crowns = Crowns.new()
		faces:setSync(boards.last)
	end

	-- LeaderboardSync { boards = { [board] = { allTime = rows, week = rows } }, me = { [board] = { rank?, value,
	-- weekRank?, weekValue? } }, week }: the server's top 50 lists and this player's own places.
	function UI.leaderboards.sync(payload: any)
		if type(payload) ~= "table" then
			return
		end
		local sync = payload :: LeaderboardLogic.Sync
		boards.last = sync
		local faces = boards.faces
		if faces then
			faces:setSync(sync)
		end
	end

	-- UI.destroy: the faces and crowns go with the rest of the screens.
	function UI.leaderboards.reset()
		local faces, crowns = boards.faces, boards.crowns
		if faces then
			faces:destroy()
		end
		if crowns then
			crowns:destroy()
		end
		boards.faces, boards.crowns = nil, nil
	end
end

----------------------------------------------------------------------------------------------------
-- Playing together (F92)
----------------------------------------------------------------------------------------------------

-- Pals, Team Rescue and invites (playing-together.md): UIController calls UI.pals(userIds) on every PalsChanged,
-- UI.palArrived(palUserId, palArea?) when this player joined at a pal's door, and UI.teamRescue(rescuerUserId,
-- helperUserId, coins) when a helped rescue freed its cat; UIController's showAsk shows the one invite nudge through
-- UI.asks.show("invite_ask"). The pal list is kept, so a rebuilt UI shows the chip at once. Its own block, as the
-- module is short of locals. (UI.together is declared at the top, as UI.destroy and UI.asks use it first.)
do
	local Invite = require(script.Components.Invite)
	local PalsLogic = require(script.Components.PalsLogic)
	local TeamRescuePop = require(script.Screens.TeamRescuePop)
	local TAG_SECONDS = 120 -- the pal's tag on the Cannon picker card stays this long after they arrive
	local ASK_SECONDS = 14 -- the invite nudge stays up this long with no answer
	local together = {
		ids = {} :: { number },
		pop = nil :: TeamRescuePop.TeamRescuePop?,
		tagToken = 0,
		taggedPal = nil :: number?,
	}

	local function nameOf(userId: number): string?
		local player = Players:GetPlayerByUserId(userId)
		return if player then player.DisplayName else nil
	end

	local function clearTag()
		together.tagToken += 1
		together.taggedPal = nil
		if cannonScreen then
			cannonScreen:setPal(nil, nil)
		end
	end

	-- UI.init: the pop's screen, and the chip as the last PalsChanged left it.
	function UI.together.start(parent: Instance)
		UI.together.reset()
		together.pop = TeamRescuePop.new(parent)
		if hud then
			hud:setPals(together.ids)
		end
	end

	-- PalsChanged(userIds): this player's pals on the server (never themselves); an empty list means none now.
	function UI.pals(userIds: { number })
		local ids = PalsLogic.list(userIds, Players.LocalPlayer.UserId)
		together.ids = ids
		if hud then
			hud:setPals(ids)
		end
		local tagged = together.taggedPal
		if tagged ~= nil and not table.find(ids, tagged) then
			clearTag()
		end
	end

	-- PalArrived for this player: a pal out in a catching area gets the marker "Sam is in the Park" over the glowing
	-- Cannon and a tag on that area's picker card when the area is open to this player, else a toast. A pal at the
	-- cafe this player spawned at (no area) needs neither.
	function UI.palArrived(palUserId: number, palArea: string?)
		if type(palUserId) ~= "number" or type(palArea) ~= "string" then
			return
		end
		local catalog = currentCatalog
		local areas: { Types.AreaDef } = if catalog and catalog.areas then catalog.areas else {}
		local area: Types.AreaDef? = nil
		for _, def in areas do
			if def.id == palArea then
				area = def
			end
		end
		if area == nil then
			return
		end
		local name = nameOf(palUserId)
		local text = PalsLogic.arrived(name, area.name)
		if text == nil then
			return
		end
		local open = area.tier <= (state.tier or 1)
		if open and hud then
			hud:palArrived(palUserId, text)
			if cannonScreen then
				cannonScreen:setPal(area.id, name)
			end
			together.tagToken += 1
			together.taggedPal = palUserId
			local token = together.tagToken
			task.delay(TAG_SECONDS, function()
				if together.tagToken == token then
					clearTag()
				end
			end)
		elseif toasts then
			toasts:show(text, "info")
		end
	end

	-- TeamRescue on both players' screens: the pop with both faces, the helper's tip in the helper's line.
	function UI.teamRescue(rescuerUserId: number, helperUserId: number, coins: number)
		if type(rescuerUserId) ~= "number" or type(helperUserId) ~= "number" then
			return
		end
		local line = PalsLogic.teamRescue(
			Players.LocalPlayer.UserId,
			rescuerUserId,
			helperUserId,
			if type(coins) == "number" then coins else 0,
			nameOf
		)
		local pop = together.pop
		if pop then
			pop:show(rescuerUserId, helperUserId, line)
		elseif toasts then
			toasts:show(PalsLogic.TITLE .. " " .. line, "good")
		end
	end

	-- The one invite nudge (section 5), on the slide-in ask card: the line, Invite (Roblox's invite window with this
	-- player's launch data) and Not now. False while another ask is up, so UIController offers it again later.
	function UI.together.inviteAsk(): boolean
		local card = askCard
		if card == nil or not initialized or card:isShowing() then
			return false
		end
		card:show({
			title = PalsLogic.inviteAsk(),
			choices = {
				{ id = "invite", label = "Invite", icon = Theme.icons.invite, style = "primary" },
				{ id = "later", label = "Not now" },
			},
			seconds = ASK_SECONDS,
			lines = 2,
			answer = function(choice: string?)
				if choice == "invite" then
					Invite.prompt()
				end
			end,
		})
		return true
	end

	-- UI.destroy: the pop goes with the rest of the screens; the pal list stays for the next build.
	function UI.together.reset()
		local pop = together.pop
		if pop then
			pop:destroy()
		end
		together.pop = nil
		together.tagToken += 1
		together.taggedPal = nil
	end
end

----------------------------------------------------------------------------------------------------
-- Camp extras (F100, camp-extras.md section 3)
----------------------------------------------------------------------------------------------------

-- The Corner Shop (#1052, corner-shop.md; Gameplay-Engineer #1069): the controller calls UI.cornerShop.open() from
-- the stall's CornerShopPrompt, setStock(stock) with every CornerShopStock, and close() when it wants it shut; a Buy
-- fires UI.events.buyCornerShop(itemId, window, shownPrice, catUid?). Walking away from the stall closes the window.
-- The last stock is kept, so a rebuilt UI shows it at once. Its own block, as the module is short of locals.
UI.cornerShop = {}
do
	local CornerShop = require(script.Screens.CornerShop)
	local SharedConfig =
		require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any
	local SHOP_TAG = "CornerShop" -- shared/CornerShop.TAG: the stall, CatCafe_Street_CornerShop
	local FAR_STUDS: number = (SharedConfig.CornerShopRange or 14) + 6
	local corner = {
		stock = nil :: any,
		view = nil :: CornerShop.CornerShop?,
	}

	-- Studs from this player's character to the nearest stall, or nil while either is streamed out.
	local function shopDistance(): number?
		local character = Players.LocalPlayer.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root == nil or not root:IsA("BasePart") then
			return nil
		end
		local best: number? = nil
		for _, model in CollectionService:GetTagged(SHOP_TAG) do
			if model:IsA("Model") and model:IsDescendantOf(Workspace) then
				local distance = (
					(model :: Model):GetPivot().Position - (root :: BasePart).Position
				).Magnitude
				if best == nil or distance < best then
					best = distance
				end
			end
		end
		return best
	end

	function UI.cornerShop.start()
		local modalView = modal
		if modalView == nil then
			return
		end
		local old = corner.view
		if old then
			old:destroy()
		end
		local view = CornerShop.new({
			buy = function(itemId: string, window: number, shownPrice: number, catUid: string?)
				UI.events.buyCornerShop:Fire(itemId, window, shownPrice, catUid)
			end,
			close = function()
				if modalView:current() == "CornerShop" then
					modalView:close()
				end
			end,
			far = function(): boolean
				local distance = shopDistance()
				return distance ~= nil and distance > FAR_STUDS
			end,
		})
		corner.view = view
		modalView:register("CornerShop", {
			frame = view.frame,
			onOpen = function()
				view:render(state)
				view:opened()
			end,
			onClose = function()
				view:closed()
			end,
		})
		view:setStock(corner.stock)
	end

	function UI.cornerShop.render(playerState: Types.PlayerState)
		local view = corner.view
		if view then
			view:render(playerState)
		end
	end

	-- CornerShopStock(stock): on join, every 5 minute window and after every buy.
	function UI.cornerShop.setStock(stock: any)
		if type(stock) ~= "table" then
			return
		end
		corner.stock = stock
		local view = corner.view
		if view then
			view:setStock(stock)
		end
	end

	-- The stall's prompt.
	function UI.cornerShop.open()
		local modalView = modal
		if corner.view == nil or modalView == nil then
			return
		end
		modalView:open("CornerShop")
	end

	function UI.cornerShop.close()
		local modalView = modal
		if modalView and modalView:current() == "CornerShop" then
			modalView:close()
		end
	end
end

-- Controllers/CampExtrasController calls these when present: update(state) with every CampExtrasState (the Cannon
-- picker's strips and the Yard Sale card), openYardSale(view) from the Yard Sale's prompt, collected(extraId, paid,
-- prize) after a collect or a buy (the prize toast) and refused(extraId) after a refusal, whose reason the server
-- toasts. The prompts themselves are Custom style, so the action pill draws them. The last state is kept, so a
-- rebuilt UI shows the strips at once. Its own block, as the module is short of locals.
do
	local CampExtrasLogic = require(script.Components.CampExtrasLogic)
	local YardSale = require(script.Screens.YardSale)
	local ReadyBang = require(script.Components.ReadyBang)
	local SharedConfig =
		require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any
	local CAMP_TAG = "CampExtra" -- shared/CampExtras.TAG: the placed models, with their ExtraId attribute
	-- the card closes once the player walks this far from the Yard Sale (its prompt's reach and some slack)
	local FAR_STUDS: number = (SharedConfig.CampExtraRangeStuds or 8) + 8
	local camp = {
		state = nil :: Types.CampExtrasState?,
		yard = nil :: YardSale.YardSale?,
		bang = nil :: ReadyBang.ReadyBang?, -- the red "!" over each ready station (camp-stations.md section 1)
	}

	local function yardView(): Types.CampExtraView?
		local current = camp.state
		return if current ~= nil then current.yardSale else nil
	end

	-- Studs from this player's character to the Yard Sale's model, or nil while either is streamed out.
	local function yardDistance(): number?
		local character = Players.LocalPlayer.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root == nil or not root:IsA("BasePart") then
			return nil
		end
		for _, model in CollectionService:GetTagged(CAMP_TAG) do
			if
				model:IsA("Model")
				and model:GetAttribute("ExtraId") == CampExtrasLogic.YARD_SALE
				and model:IsDescendantOf(Workspace)
			then
				return ((model :: Model):GetPivot().Position - (root :: BasePart).Position).Magnitude
			end
		end
		return nil
	end

	-- UI.init: the Yard Sale card in the modal, the stations' "!", the strips from the kept state.
	function UI.campExtras.start(into: Instance)
		UI.campExtras.reset()
		local bang = ReadyBang.new(into)
		bang:update(camp.state)
		camp.bang = bang
		local modalView = modal
		if modalView == nil then
			return
		end
		local yard = YardSale.new({
			buy = function(crateId: string)
				UI.events.buyYardSale:Fire(crateId)
			end,
			close = function()
				if modalView:current() == "YardSale" then
					modalView:close()
				end
			end,
			far = function(): boolean
				local distance = yardDistance()
				return distance ~= nil and distance > FAR_STUDS
			end,
		})
		camp.yard = yard
		modalView:register("YardSale", {
			frame = yard.frame,
			onOpen = function()
				yard:render(state)
				yard:opened()
			end,
			onClose = function()
				yard:closed()
			end,
		})
		if currentCatalog then
			yard:setCatalog(currentCatalog)
		end
		yard:setView(yardView())
		if cannonScreen then
			cannonScreen:setExtras(camp.state)
		end
	end

	function UI.campExtras.setCatalog(catalog: Types.Catalog)
		local yard = camp.yard
		if yard then
			yard:setCatalog(catalog)
			yard:setView(yardView())
		end
	end

	function UI.campExtras.render(playerState: Types.PlayerState)
		local yard = camp.yard
		if yard then
			yard:render(playerState)
		end
	end

	-- CampExtrasState: each extra's open, held, nextAt and the Yard Sale's stock today.
	function UI.campExtras.update(extras: Types.CampExtrasState)
		if type(extras) ~= "table" then
			return
		end
		camp.state = extras
		if cannonScreen then
			cannonScreen:setExtras(extras)
		end
		local bang = camp.bang
		if bang then
			bang:update(extras)
		end
		local yard = camp.yard
		if yard then
			yard:setView(extras.yardSale)
		end
	end

	-- The Yard Sale's prompt: its card with today's crates.
	function UI.campExtras.openYardSale(view: Types.CampExtraView?)
		local yard = camp.yard
		local modalView = modal
		if yard == nil or modalView == nil then
			return
		end
		yard:setView(if view ~= nil then view else yardView())
		modalView:open("YardSale")
	end

	-- CampExtraResult ok: the prize toast, the extra's name and what it paid as at most two pictures ("Fish Pond" and
	-- the gold fish "x14"); with no prize the server's words say it ("Fish Pond: +14 golden fish").
	function UI.campExtras.collected(extraId: string, paid: { string }?, prize: Types.IndexPrize?)
		if toasts then
			toasts:prize(
				CampExtrasLogic.prizeTitle(extraId, if prize ~= nil then nil else paid),
				prize
			)
		end
	end

	-- CampExtraResult refused: the Yard Sale's "..." lifts (the server's toast says why).
	function UI.campExtras.refused(extraId: string)
		local yard = camp.yard
		if yard and extraId == CampExtrasLogic.YARD_SALE then
			yard:refused()
		end
	end

	-- UI.destroy: the card goes with the modal and the "!" with the UI; the state stays for the next build.
	function UI.campExtras.reset()
		local yard = camp.yard
		if yard then
			yard:destroy()
		end
		camp.yard = nil
		local bang = camp.bang
		if bang then
			bang:destroy()
		end
		camp.bang = nil
	end
end

----------------------------------------------------------------------------------------------------
-- Rescue Rally (F101, rescue-rally.md section 4)
----------------------------------------------------------------------------------------------------

-- Controllers/RallyController calls UI.rally.update(state) on every RallyState: the banner top centre while a Rally
-- runs, the Town Square board's face, "🏁 Rescue Rally in 5h 20m" under the clock in the last 12 hours before one
-- (the Friday chip) and the Cat Cannon cards' night tag. The pops are VFX's (Effects/Rally hooks RallyPoint and finds
-- the banner's RallyBar) and the step prizes' toasts the server's. The state is kept, so a rebuilt UI shows it at
-- once. Its own block, as the module is short of locals.
do
	local RallyBanner = require(script.Screens.RallyBanner)
	local RallyBoards = require(script.Screens.RallyBoards)
	local RallyLogic = require(script.Components.RallyLogic)
	local SOON_SECONDS = 15 -- how often the clock line's countdown is worked out again
	local rally = {
		state = nil :: Types.RallyState?,
		banner = nil :: RallyBanner.RallyBanner?,
		boards = nil :: RallyBoards.RallyBoards?,
		busy = nil :: Signal.Connection?, -- HUD.catchingChanged
		token = 0,
	}

	local function paint()
		local current = rally.state
		local banner = rally.banner
		if banner then
			banner:set(current)
		end
		local boards = rally.boards
		if boards then
			boards:set(current)
		end
		if cannonScreen then
			cannonScreen:setRally(current)
		end
		if hud then
			hud:setRallySoon(RallyLogic.soon(current, Workspace:GetServerTimeNow()))
		end
	end

	-- UI.init: the banner and the board faces, painted from the kept state.
	function UI.rally.start(parent: Instance)
		UI.rally.reset()
		-- on a phone the potion timers' row can reach the top centre; the banner moves under it then
		rally.banner = RallyBanner.new(parent, function(): { GuiObject }
			local current = hud
			if current == nil then
				return {}
			end
			return { current:buffRow() }
		end)
		-- the banner steps aside while a catch or rescue runs, clear of their headers (review S113)
		local hudNow = hud
		if hudNow then
			local banner = rally.banner
			if banner then
				banner:setBusy(hudNow:isCatching())
			end
			rally.busy = hudNow.catchingChanged:Connect(function(active: boolean)
				local current = rally.banner
				if current then
					current:setBusy(active)
				end
			end)
		end
		rally.boards = RallyBoards.new(parent)
		rally.token += 1
		local token = rally.token
		task.spawn(function()
			while rally.token == token do
				task.wait(SOON_SECONDS)
				local current = hud
				if rally.token == token and current ~= nil then
					current:setRallySoon(RallyLogic.soon(rally.state, Workspace:GetServerTimeNow()))
				end
			end
		end)
		paint()
	end

	-- RallyState from the server.
	function UI.rally.update(state: Types.RallyState)
		if type(state) ~= "table" then
			return
		end
		rally.state = state
		paint()
	end

	-- UI.setVisible: the banner hides with the HUD.
	function UI.rally.setVisible(isVisible: boolean)
		local banner = rally.banner
		if banner then
			banner:setVisible(isVisible)
		end
	end

	-- UI.destroy: the banner and the faces go; the state stays for the next build.
	function UI.rally.reset()
		rally.token += 1
		local busy = rally.busy
		if busy then
			busy:Disconnect()
		end
		rally.busy = nil
		local banner = rally.banner
		if banner then
			banner:destroy()
		end
		local boards = rally.boards
		if boards then
			boards:destroy()
		end
		rally.banner = nil
		rally.boards = nil
	end
end

----------------------------------------------------------------------------------------------------
-- Trading (F102, trading.md sections 2 and 3)
----------------------------------------------------------------------------------------------------

-- The trade controller calls these when present: asked(requestId, fromUserId, fromName, expiresAt) from TradeAsked
-- (the request card), state(tradeState?) from every TradeState (nil ends it), done(tradeId, gave, got) from TradeDone
-- and ended(tradeId, reason) from TradeEnded. The window opens by itself when a trade starts and closes when it
-- ends; the cats flying home are VFX's and the ticks and chime Sound-Agent's. Its own block, as the module is short
-- of locals.
do
	local Trade = require(script.Screens.Trade)
	local TradeLog = require(script.Screens.TradeLog)
	local TradeLogic = require(script.Components.TradeLogic)
	local trading = {
		screen = nil :: Trade.Trade?,
		log = nil :: TradeLog.TradeLog?, -- the Trades page, opened from Settings
		state = nil :: Types.TradeState?,
		request = nil :: string?, -- the request card's id while it shows
	}

	-- UI.init: the window in the modal, with the kept trade.
	function UI.trade.start()
		UI.trade.reset()
		local modalView = modal
		if modalView == nil then
			return
		end
		local screen = Trade.new({
			close = function()
				if modalView:current() == "Trade" then
					modalView:close()
				end
			end,
			request = function(userId: number)
				UI.events.requestTrade:Fire(userId)
			end,
			offer = function(tradeId: string, action: "add" | "remove", uid: string)
				UI.events.tradeOffer:Fire(tradeId, action, uid)
			end,
			ready = function(tradeId: string, version: number, ready: boolean)
				UI.events.tradeReady:Fire(tradeId, version, ready)
			end,
			confirm = function(tradeId: string, version: number)
				UI.events.tradeConfirm:Fire(tradeId, version)
			end,
			cancel = function(tradeId: string)
				UI.events.tradeCancel:Fire(tradeId)
			end,
		})
		trading.screen = screen
		modalView:register("Trade", {
			frame = screen.frame,
			onOpen = function()
				screen:render(state)
				screen:opened()
			end,
			onClose = function()
				screen:closed()
			end,
		})
		if currentCatalog then
			screen:setCatalog(currentCatalog)
		end
		screen:setTrade(trading.state)

		local log = TradeLog.new({
			close = function()
				if modalView:current() == "TradeLog" then
					modalView:close()
				end
			end,
			back = function()
				UI.open("Settings")
			end,
		})
		trading.log = log
		modalView:register("TradeLog", {
			frame = log.frame,
			onOpen = function()
				log:render(state)
			end,
		})
		if currentCatalog then
			log:setCatalog(currentCatalog)
		end
	end

	function UI.trade.setCatalog(catalog: Types.Catalog)
		local screen = trading.screen
		if screen then
			screen:setCatalog(catalog)
		end
		local log = trading.log
		if log then
			log:setCatalog(catalog)
		end
	end

	function UI.trade.render(playerState: Types.PlayerState)
		local screen = trading.screen
		if screen then
			screen:render(playerState)
		end
		-- the Trades page builds its cards only while open (review S116): most players never open it, and its
		-- onOpen renders the latest state
		local log = trading.log
		local modalView = modal
		if log and modalView and modalView:current() == "TradeLog" then
			log:render(playerState)
		end
	end

	-- TradeAsked: "Sam wants to trade" with Accept and Decline until the request runs out. Letting it drain says
	-- nothing; the server times the request out itself.
	function UI.trade.asked(
		requestId: string,
		_fromUserId: number,
		fromName: string,
		expiresAt: number
	)
		local card = askCard
		if card == nil or type(requestId) ~= "string" then
			return
		end
		trading.request = requestId
		card:show({
			title = TradeLogic.askTitle(
				if type(fromName) == "string" then fromName else "A player"
			),
			choices = {
				{ id = "accept", label = "Accept", style = "primary" },
				{ id = "decline", label = "Decline" },
			},
			seconds = math.max(1, (tonumber(expiresAt) or 0) - Workspace:GetServerTimeNow()),
			answer = function(id: string?)
				if trading.request == requestId then
					trading.request = nil
				end
				if id == "accept" or id == "decline" then
					UI.events.respondTrade:Fire(requestId, id == "accept")
				end
			end,
		})
	end

	-- TradeState: the window follows it, opening when a new trade starts; nil ends it and closes the window.
	function UI.trade.state(tradeState: Types.TradeState?)
		local before = trading.state
		trading.state = if type(tradeState) == "table" then tradeState else nil
		local now = trading.state
		local screen = trading.screen
		if screen then
			screen:setTrade(now)
		end
		local modalView = modal
		if modalView == nil then
			return
		end
		if now ~= nil and (before == nil or before.tradeId ~= now.tradeId) then
			local card = askCard
			if card and trading.request ~= nil then
				card:hide() -- the request this trade answered
			end
			modalView:open("Trade")
		elseif now == nil and before ~= nil and modalView:current() == "Trade" then
			modalView:close()
		end
	end

	-- TradeDone: "Trade done! 2 new cats"; the cats fly home with VFX's effect.
	-- TradeDone and TradeEnded also close the window on that trade (review S114), should no nil TradeState follow.
	local function over(tradeId: string)
		local current = trading.state
		if current ~= nil and current.tradeId == tradeId then
			UI.trade.state(nil)
		end
	end

	function UI.trade.done(tradeId: string, _gave: { Types.TradeCat }?, got: { Types.TradeCat }?)
		over(tradeId)
		if toasts then
			toasts:show(TradeLogic.doneLine(got), "good")
		end
	end

	-- TradeEnded: the server's words ("Sam left", "Trade cancelled", "Out of the safe zone").
	function UI.trade.ended(tradeId: string, reason: string?)
		over(tradeId)
		if toasts and type(reason) == "string" and reason ~= "" then
			toasts:show(reason, "info")
		end
	end

	-- UI.destroy: the window goes with the modal; the trade stays for the next build.
	function UI.trade.reset()
		local screen = trading.screen
		if screen then
			screen:destroy()
		end
		trading.screen = nil
		local log = trading.log
		if log then
			log:destroy()
		end
		trading.log = nil
	end
end

----------------------------------------------------------------------------------------------------
-- Garden Nursery (#1200, lawn-nursery.md section 2)
--
-- The stall in the Park camp (tag LawnStall, Gameplay-Engineer's #1364) carries a Custom-style ProximityPrompt named
-- LawnStallPrompt; holding it opens the nursery window in the modal, and walking more than LawnStallRange + 4 studs
-- from the stall closes it. A Buy fires BuyLawn(id), which the server checks (tier, coins, standing at the stall).
-- Its own block, as the module is short of locals.
do
	local LawnStall = require(script.Screens.LawnStall)
	local SharedConfig =
		require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any
	local STALL_TAG = "LawnStall"
	local PROMPT_NAME = "LawnStallPrompt"
	local FAR_STUDS: number = (SharedConfig.LawnStallRange or 14) + 4
	local nursery = {
		window = nil :: LawnStall.LawnStall?,
		connections = {} :: { RBXScriptConnection },
		prompts = {} :: { [ProximityPrompt]: boolean },
	}

	-- Studs from this player's character to the nearest stall, or nil while either is streamed out.
	local function stallDistance(): number?
		local character = Players.LocalPlayer.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root == nil or not root:IsA("BasePart") then
			return nil
		end
		local best: number? = nil
		for _, stall in CollectionService:GetTagged(STALL_TAG) do
			if stall:IsA("Model") and stall:IsDescendantOf(Workspace) then
				local distance = (
					(stall :: Model):GetPivot().Position - (root :: BasePart).Position
				).Magnitude
				if best == nil or distance < best then
					best = distance
				end
			end
		end
		return best
	end

	local function open()
		local window = nursery.window
		local modalView = modal
		if window == nil or modalView == nil then
			return
		end
		window:render(state)
		modalView:open("LawnStall")
	end

	-- Picks up a placed stall's prompt (again after the model streams back in).
	local function track(stall: Instance)
		if not stall:IsDescendantOf(Workspace) then
			return
		end
		local found = stall:FindFirstChild(PROMPT_NAME, true)
		if found == nil or not found:IsA("ProximityPrompt") then
			local waiting: RBXScriptConnection
			waiting = stall.DescendantAdded:Connect(function(child: Instance)
				if child.Name == PROMPT_NAME and child:IsA("ProximityPrompt") then
					waiting:Disconnect()
					track(stall)
				end
			end)
			table.insert(nursery.connections, waiting)
			return
		end
		local prompt = found :: ProximityPrompt
		if nursery.prompts[prompt] then
			return
		end
		nursery.prompts[prompt] = true
		table.insert(nursery.connections, prompt.Triggered:Connect(open))
		table.insert(
			nursery.connections,
			prompt.AncestryChanged:Connect(function()
				if not prompt:IsDescendantOf(Workspace) then
					nursery.prompts[prompt] = nil
				end
			end)
		)
	end

	function UI.nursery.start()
		UI.nursery.reset()
		local modalView = modal
		if modalView == nil then
			return
		end
		local window = LawnStall.new({
			buy = function(id: string)
				UI.events.buyLawn:Fire(id, nil)
			end,
			close = function()
				if modalView:current() == "LawnStall" then
					modalView:close()
				end
			end,
			far = function(): boolean
				local distance = stallDistance()
				return distance ~= nil and distance > FAR_STUDS
			end,
		})
		nursery.window = window
		modalView:register("LawnStall", {
			frame = window.frame,
			onOpen = function()
				window:render(state)
				window:opened()
			end,
			onClose = function()
				window:closed()
			end,
		})
		for _, stall in CollectionService:GetTagged(STALL_TAG) do
			track(stall)
		end
		table.insert(
			nursery.connections,
			CollectionService:GetInstanceAddedSignal(STALL_TAG):Connect(track)
		)
	end

	-- The window on one tab ("pieces" by default), as the stall's prompt opens it; the UI gate's scenes call this too.
	function UI.nursery.open(tab: string?)
		local window = nursery.window
		if window and (tab == "pieces" or tab == "path" or tab == "fence") then
			window:showTab(tab)
		end
		open()
	end

	function UI.nursery.render(playerState: Types.PlayerState)
		local window = nursery.window
		if window then
			window:render(playerState)
		end
	end

	function UI.nursery.reset()
		for _, connection in nursery.connections do
			connection:Disconnect()
		end
		table.clear(nursery.connections)
		table.clear(nursery.prompts)
		local window = nursery.window
		if window then
			window:destroy()
		end
		nursery.window = nil
	end
end

-- Front lawn edit view (F91)
----------------------------------------------------------------------------------------------------

-- The Front lawn tab's Edit lawn (front-lawn.md section 3): the camera swings to the player's cafe front with a ring
-- over each lawn spot, and a ring's tap opens the picker (Screens/LawnEdit). The HUD steps aside while it is up but the
-- toasts stay, so a buy still says so; Done comes back to the Decor window on its Front lawn tab. Its own block, as
-- the module is short of locals.
do
	local LawnEdit = require(script.Screens.LawnEdit)
	local lawn = {
		edit = nil :: LawnEdit.LawnEdit?,
		plot = nil :: Instance?, -- the own plot UI.richTip.bind passed, for an edit view built after it
	}

	-- UI.init: the edit view, bound to the plot if one came first.
	function UI.lawn.start(parent: Instance)
		UI.lawn.reset()
		local edit = LawnEdit.new(parent, {
			buyLawn = function(id: string, spotId: string?)
				UI.events.buyLawn:Fire(id, spotId)
			end,
			setLawnSpot = function(spotId: string, pieceId: string)
				UI.events.setLawnSpot:Fire(spotId, pieceId)
			end,
			shown = function(editing: boolean)
				local show = visible and not editing
				if hud then
					hud:setVisible(show)
				end
				UI.rally.setVisible(show)
				if locationMarkers then
					locationMarkers:setVisible(show)
				end
			end,
			done = function()
				if decor then
					decor:showLawn()
				end
				if modal then
					modal:open("Decor")
				end
			end,
		})
		edit:bind(lawn.plot)
		edit:render(state)
		lawn.edit = edit
	end

	function UI.lawn.bind(plot: Instance?)
		lawn.plot = plot
		if lawn.edit then
			lawn.edit:bind(plot)
		end
	end

	function UI.lawn.render(playerState: Types.PlayerState)
		if lawn.edit then
			lawn.edit:render(playerState)
		end
	end

	-- Edit lawn: the Decor window closes and the camera swings to the cafe front, or a toast says why not (no plot or
	-- lawn yet, or too far from the cafe). Returns whether the view opened.
	function UI.lawn.edit(): boolean
		local edit = lawn.edit
		if edit == nil then
			return false
		end
		local ok, why = edit:canStart()
		if not ok then
			UI.toast(why or "Your lawn is not ready yet.", "info")
			return false
		end
		if modal then
			modal:close()
		end
		return edit:start()
	end

	-- The picker for a lawn spot (a ring's tap), or closed with nil.
	function UI.lawn.pick(spotId: string?)
		if lawn.edit then
			lawn.edit:pick(spotId)
		end
	end

	-- Ends the edit view; `reopen` brings the Decor window back on its Front lawn tab, as Done does.
	function UI.lawn.stop(reopen: boolean?)
		if lawn.edit then
			lawn.edit:stop(reopen == true)
		end
	end

	-- UI.destroy: the camera back and the view gone.
	function UI.lawn.reset()
		if lawn.edit then
			lawn.edit:destroy()
		end
		lawn.edit = nil
	end
end

----------------------------------------------------------------------------------------------------
-- Store
----------------------------------------------------------------------------------------------------

-- The Store window (Derek 2026-11-02: "store still needs to be added"; Monetization-Agent's shop-and-pass-plan). The
-- HUD's gold Store tile shows as soon as the window exists, on sale or not (Derek 2026-11-04, #1167: "the Store
-- UI/menu is missing"; it used to wait for a pass on sale, and every pass is off sale until launch). An off-sale
-- pass's card says "Soon". Each pass's card reads its price from Roblox and opens
-- Roblox's own purchase window (Components/PassShop); the server's PassService turns a bought pass on. Its own
-- block, as the module is short of locals.
do
	local PassShop = require(script.Components.PassShop)
	local Store = require(script.Screens.Store)
	local StoreLogic = require(script.Components.StoreLogic)
	local shop = {
		screen = nil :: Store.Store?,
		changed = nil :: Signal.Connection?,
		open = false, -- whether the HUD's tile shows
	}

	-- the potion packs' contents and names from the shared Catalog, the bag from the state (#1182)
	local SharedCatalog =
		require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog")) :: any
	local potionNames: { [string]: string } = {}
	for _, def in SharedCatalog.potions or {} do
		potionNames[def.id] = def.name
	end
	local function rows(): { StoreLogic.Row }
		return StoreLogic.rows(Config, PassShop.owned(), state.longNap, {
			products = SharedCatalog.products,
			potionNames = potionNames,
			have = state.potions,
		})
	end

	-- The window's cards when it is up, and the HUD's tile when its open state changes.
	local function refresh()
		local screen = shop.screen
		if screen and modal and modal:current() == "Store" then
			screen:render(rows(), PassShop.prices())
		end
		local open = screen ~= nil -- the tile shows whenever there is a window for it to open
		if open ~= shop.open and hud then
			shop.open = open
			hud:setStore(if open
				then function()
					if modal then
						modal:toggle("Store")
					end
				end
				else nil)
		end
	end

	-- UI.init: the window in the modal, and the passes looked up.
	function UI.store.start()
		UI.store.reset()
		local modalView = modal
		if modalView == nil then
			return
		end
		local screen = Store.new({
			buy = function(passId: number)
				PassShop.prompt(passId)
			end,
			close = function()
				if modalView:current() == "Store" then
					modalView:close()
				end
			end,
			-- #1428: the code box starts fresh on the Codes tab and clears when it leaves view
			codes = function(shown: boolean)
				local codes = codesScreen
				if codes == nil then
					return
				end
				if shown then
					codes:onOpen()
				else
					codes:onClose()
				end
			end,
		})
		shop.screen = screen
		if codesScreen then
			codesScreen:mount(screen.codesPage) -- #1428: the code box is the Store's Codes tab
		end
		modalView:register("Store", {
			frame = screen.frame,
			onOpen = function()
				screen:showTab("featured") -- #1425: the Store always opens on Featured
				screen:render(rows(), PassShop.prices())
			end,
			onClose = function()
				screen:closed()
			end,
		})
		shop.changed = PassShop.changed:Connect(refresh)
		PassShop.start(StoreLogic.passIds(Config), StoreLogic.productIds(Config))
		refresh()
	end

	-- Every state update: Long Nap from ProfileSync marks its card Owned.
	function UI.store.render()
		refresh()
	end

	function UI.store.open()
		if modal then
			modal:open("Store")
		end
	end

	-- #1428: the Codes Cat's circle opens the Store on its Codes tab, unless another window is up (review N182).
	-- False when there is no Store window, so the old Codes window opens instead.
	function UI.store.openCodes(): boolean
		local screen = shop.screen
		local modalView = modal
		if screen == nil or modalView == nil then
			return false
		end
		local current = modalView:current()
		if current == nil then
			modalView:open("Store")
			current = modalView:current()
		end
		if current == "Store" then
			screen:showTab("codes")
		end
		return true
	end

	-- Whether the Store is up on its Codes tab (the circle's walk-out closes it, and answers show there).
	function UI.store.codesShowing(): boolean
		local screen = shop.screen
		return screen ~= nil
			and modal ~= nil
			and modal:current() == "Store"
			and screen:tab() == "codes"
	end

	-- The UI gate's and a Studio preview's answers in place of Roblox's: pass id to { robux, forSale }, and pass id
	-- to true for the passes owned. preview({}, {}) clears them.
	function UI.store.preview(prices: { [number]: StoreLogic.Price }, owned: { [number]: boolean })
		PassShop.preview(prices, owned)
	end

	-- UI.destroy.
	function UI.store.reset()
		if shop.changed then
			shop.changed:Disconnect()
			shop.changed = nil
		end
		if shop.screen then
			if codesScreen then
				codesScreen:mount(nil) -- back in its own window before the Store goes
			end
			shop.screen:destroy()
			shop.screen = nil
		end
		if shop.open and hud then
			hud:setStore(nil) -- no window left for the tile to open
		end
		shop.open = false
		PassShop.stop()
	end
end

----------------------------------------------------------------------------------------------------
-- Cat speech bubbles (#1079, cat-bubbles.md)
----------------------------------------------------------------------------------------------------

-- One short line over the nearest key cat (Screens/CatBubbles), hidden while any window, pop-up or bait card is
-- open, during the catch circles or a rescue, while carrying, in the intro and while the UI is hidden. The Bellhop
-- Cat's line needs `starterCatClaimed` in UI.update (false shows it); without it that line stays quiet. Its own
-- block, as the module is short of locals.
UI.bubbles = {}
do
	local CatBubbles = require(script.Screens.CatBubbles)
	local bubbles: CatBubbles.CatBubbles? = nil

	-- UI.init. Off unless Config.CatBubblesEnabled is true (#1188, the friend 11-04: "vault the text bubble pop-ups
	-- from walking near cats/npc's"); the code stays so they can come back.
	function UI.bubbles.start(parent: Instance)
		UI.bubbles.reset()
		if (Config :: any).CatBubblesEnabled ~= true then
			return
		end
		bubbles = CatBubbles.new(parent, {
			blocked = function(): boolean
				return not visible
					or (modal ~= nil and modal:current() ~= nil)
					or (popups ~= nil and popups:isShowing())
					or (baitCard ~= nil and baitCard:isShowing())
					or (askCard ~= nil and askCard:isShowing())
					or (hud ~= nil and hud:isCarrying())
					or UI.catch.circlesActive()
					or UI.rescue.isActive()
					or UI.intro.playing()
			end,
			claimed = function(): boolean?
				local claimed = (state :: any).starterCatClaimed
				return if type(claimed) == "boolean" then claimed else nil
			end,
		})
	end

	-- UI.destroy.
	function UI.bubbles.reset()
		if bubbles then
			bubbles:destroy()
			bubbles = nil
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Demo
----------------------------------------------------------------------------------------------------

-- Runs the UI with a fake catalog and a pretend server so it can be seen in Studio before the
-- real client controller exists. Returns a stop function. Not for production.
function UI.demo(): () -> ()
	local Demo = require(script.Demo) :: any
	return Demo.run(UI)
end

return UI
