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
local Arcade = require(script.Screens.Arcade)
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
local PicnicTreats = require(script.Screens.PicnicTreats)
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
local SpotlightGuide = require(script.Components.SpotlightGuide) -- #3555
local StationInfo = require(script.Screens.StationInfo)
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
UI.lateStations = {} -- #2651 part 4 the Oasis Spa and Relic Museum cards, filled at the end of the file
UI.mysticPool = {} -- #3196 the Mystic Pool's card (traits), filled at the end of the file
UI.mouseDash = {} -- #3296 the arcade's Mouse Dash window, filled at the end of the file
UI.rally = {} -- F101 Rescue Rally, filled at the end of the file
UI.rest = {} -- #3573: the rest chip, filled at the end of the file
UI.cafeEvent = {} -- #2487 Cafe Events' chip, banner and board, filled at the end of the file
UI.trade = {} -- F102 trading, filled at the end of the file
UI.newKind = {} -- #3529 the "NEW" tag over kinds not owned, filled at the end of the file
UI.nursery = {} -- #1200 the Garden Nursery's window, filled at the end of the file
UI.store = {} -- the Store window behind the HUD's Store tile, filled at the end of the file
UI.pass = {} -- #1646 the Cafe Pass window behind the HUD's Pass tile, filled at the end of the file

UI.Types = Types
UI.Theme = Theme
UI.Format = Format

-- Intents from the player. The controller forwards them to remotes; the server validates.
UI.events = {
	buyUpgrade = Signal.new(), -- (upgradeId)
	buyDecor = Signal.new(), -- (decorId)
	toggleDecor = Signal.new(), -- (decorId, placed: boolean)
	-- F91 front lawn (front-lawn.md section 3): forward as BuyLawn
	buyLawn = Signal.new(), -- (id, spotId?)  a piece or style; a piece onto spotId, else the first free spot
	-- #1751 (back with #1758): the Lawn cards' Use and Remove
	setLawnSpot = Signal.new(), -- (spotId, pieceId)  forward as SetLawnSpot; pieceId "" takes the spot's piece in
	setLawnStyle = Signal.new(), -- (kind, id)  forward as SetLawnStyle; id "" for Grey Slabs or no fence
	buyLure = Signal.new(), -- (lureId)
	placeCat = Signal.new(), -- (uid, spotId)
	unplaceCat = Signal.new(), -- (uid)
	lockCat = Signal.new(), -- (uid, locked)   the Lock square in the cat room: forward as LockCat (F62)
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
	-- #3062 (the Cat Arcade): Play on its card, a press on circle `index` of the game's block, and Close mid game:
	-- forward as ArcadeStart, ArcadePress(run, block, index) and ArcadeQuit(run)
	arcadePlay = Signal.new(),
	arcadePress = Signal.new(),
	arcadeQuit = Signal.new(),
	-- #3296 (Mouse Dash): Play, a tap on a hole while wave `index` is up, and Close mid game: forward as
	-- MouseDashStart, MouseDashTap(run, index, hole) and MouseDashQuit(run)
	mouseDashPlay = Signal.new(),
	mouseDashTap = Signal.new(),
	mouseDashQuit = Signal.new(),
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
	buyDealerAll = Signal.new(), -- (window)   #2573: Buy all on the night dealer screen: forward as BuyDealerAll
	claimRichTip = Signal.new(), -- (bagId)   Collect on the rich tip marker over a money bag: forward as ClaimRichTip (F31, #3360)
	takeCozy = Signal.new(), -- ()   #2854: the Rewards list's "Cozy gift waiting!" row: forward as TakeCozy
	-- design v0.5
	tackle = Signal.new(), -- ()   the Tackle button or Q: lunge and forward as Tackle (F74, no target)
	netSwing = Signal.new(), -- ()   the Net button on a touch screen (F93): swing, as a click in the world or R2 (NetSwingController)
	-- 2026-10-27 HUD v3
	dropCat = Signal.new(), -- ()   Drop on the carry banner or G while carrying: forward as DropCat
	-- 2026-10-27 wave 2
	claimTipJar = Signal.new(), -- (step)   Claim on a ready Tip Jar gift: forward as ClaimTipJar (F47)
	claimIndexReward = Signal.new(), -- (areaId, milestoneId)   Claim on an Index reward card: forward as ClaimIndexReward (F48)
	spinWheel = Signal.new(), -- ()   Spin on the Spin Wheel window: forward as SpinWheel (F49)
	storeSeen = Signal.new(), -- (tab)   a Store tab with a New dot opened: forward as MarkStoreSeen (#1823 §4)
	-- (kind, value)   #1888 the Store funnel: "store_tab" (a tab id, once a visit) or "store_buy" (the pass or product
	-- id, once a visit), forward as TelemetryReport(kind, value) after the visit's store_opened
	storeReport = Signal.new(),
	spinAll = Signal.new(), -- ()   Use all on the Spin window (#1078): forward as SpinAll
	openCrate = Signal.new(), -- (crateId)   Open on a Golden Fish Market crate card: forward as OpenCrate (F53)
	buyCrateBundle = Signal.new(), -- (crateId)   Buy 5 on a Market crate card: forward as BuyCrateBundle (#1051)
	openAllCrates = Signal.new(), -- (crateId)   Open all on a Market crate card: forward as OpenAllCrates (#2402)
	buyFishItem = Signal.new(), -- (itemId)   Buy on a Market treat or perk row: forward as BuyFishItem (F53)
	setSetting = Signal.new(), -- (key, value)   a Settings switch (boolean) or volume (0 to 1, on release): forward as SetSetting (Audio follows UI.settings.changed)
	reportBug = Signal.new(), -- (text, kind, clientErrors)   Send on Report a bug (trimmed text, "bug" | "stuck" | "idea", up to 3 client error lines): forward all three as ReportBug
	redeemCode = Signal.new(), -- (code)   Redeem in the code box (letters and digits, at most CodeMaxLength): forward as RedeemCode (F65)
	-- F72 intro: (shot)   Skip or gamepad B, once per play, with the shot showing (1 to Intro.SHOTS); end the intro, call
	-- UI.intro.finish and fire IntroDone(shot, replay)
	introSkip = Signal.new(),
	-- #2182 (intro-cutscene.md 2b): (shot)   Next, a tap outside Skip, Space, Enter or gamepad A, once a shot and from
	-- Intro.NEXT_AFTER into it; cut to the next shot, or on the last one end the intro as a finish (IntroDone(0, replay))
	introNext = Signal.new(),
	-- ()   the HUD's Tutorial tile or Settings' Replay tutorial: play the intro again with UI.intro.start({ replay = true })
	introReplay = Signal.new(),
	-- F64
	usePotion = Signal.new(), -- (potionId, count?)   Use (or #1600's Use all) in the potion bag: forward as UsePotion
	usePotionAll = Signal.new(), -- ()   #3326: the Bag's "Use all potions", confirmed: forward as UsePotionAll
	-- F61
	collectTips = Signal.new(), -- ()   the till's Collect (F61); unbound since F97 pays tip piles on arrival
	-- F73
	claimQuest = Signal.new(), -- (kind, slot)   Claim on a finished quest, kind "daily" or "weekly": forward as ClaimQuest
	rerollQuest = Signal.new(), -- (kind, slot)   Swap on an unfinished quest (the free reroll): forward as RerollQuest
	claimAchievement = Signal.new(), -- (achievementId)   Claim on a met achievement: forward as ClaimAchievement
	claimAll = Signal.new(), -- (what)   Claim all: "quests" (all three Quests tabs, #1073; or "daily", "weekly", "achievements"; Config.QuestClaimAll), "index" (the Index window, Config.IndexClaimAll) or "tipjar" (the Tip Jar, Config.TipJarClaimAll): forward as ClaimAll
	-- F63
	answerCollector = Signal.new(), -- (accept)   Trade (true) or No thanks (false) on the Cat Collector's card: forward as AnswerCollector
	-- #1646 (cafe-pass.md section 5)
	passClaim = Signal.new(), -- (track, level)   Claim on a Cafe Pass reward, track "free" or "paid": forward as PassClaim
	passClaimAll = Signal.new(), -- ()   Claim all on the Pass window: forward as PassClaimAll
	passSetTag = Signal.new(), -- (pick)   #1626: the Bag's Titles tab (was the Pass's chat tag button), a ChatTags id or "off": forward as PassSetTag
	-- #1624 (store-pass-looks.md)
	pickStyle = Signal.new(), -- (kind, id)   a Style tab button: kind "sign" forwards as SetSignStyle(id or nil), "uniform" or "theme" as SetLook(kind, id)
	-- F70
	claimDailyTreat = Signal.new(), -- ()   Claim on the Daily Treat card's day that is due: forward as ClaimDailyTreat
	-- F84
	launchCannon = Signal.new(), -- (cannonId, destination)   Launch on a Cat Cannon card: forward as LaunchCannon
	collectCampExtra = Signal.new(), -- (extraId)   #3082: Collect on a cannon picker card's strip (every player;
	-- #1463 had it for Golden Pond owners): forward as CollectCampExtra
	-- F87 (easy-start.md sections 3 and 6): a context tip shown (skipped true when its camera cut was skipped), and
	-- Settings' "Show tips again"
	tipSeen = Signal.new(), -- (id, skipped?)   a shared/Tips id (or like_ask) shown: forward as TipSeen
	clearTips = Signal.new(), -- ()   Show tips again in Settings: forward as ClearTips
	sendFeedback = Signal.new(), -- (face, chip?)   one answer on the feedback faces (Tips.FACES, Tips.CHIPS): forward as SendFeedback
	sessionFeedback = Signal.new(), -- (answer)   #3272: the once-a-day session ask's face or "skipped": forward as SessionFeedback
	-- F87 (easy-start.md sections 2g and 5), analytics only: where the intro was played from, and each stuck nudge
	tutorialClosed = Signal.new(), -- ()   #1273: the Tutorial tile's red X, analytics only: forward as TelemetryReport("tutorial_closed")
	introChoice = Signal.new(), -- (from)   "tile" (the Tutorial tile) or "help" (Show me on Need a hand?): forward as TelemetryReport("intro_choice", from)
	stuckNudge = Signal.new(), -- (kind)   "pulse", "help_shown" or "show_me": forward as TelemetryReport("stuck_nudge", kind)
	-- #1920 (first-hour.md section 6), analytics only: the session recap card showed, then went after this many seconds
	sessionRecap = Signal.new(), -- ()   forward as TelemetryReport("session_recap"); the server adds the minutes and step
	sessionRecapClose = Signal.new(), -- (secondsUp)   forward as TelemetryReport("session_recap_close", secondsUp)
	-- #1919 (first-hour.md section 5), analytics only: the goal card's "Find N more cats" opened the Index on this area
	indexHintTap = Signal.new(), -- (areaId)   forward as TelemetryReport("index_hint_tap", areaId)
	-- #1947 (like-prompts.md section 3), analytics only: the button pressed on a like or favourite gift card, once a
	-- card ("like:like", "fav:favourite", "like:close"); a card left alone sends nothing
	playtimeGift = Signal.new(), -- (what)   forward as TelemetryReport("playtime_gift", what)
	feedbackOutcome = Signal.new(), -- (how)   #2694: "answered|closed|ignored:early|late", forward as TelemetryReport("feedback_outcome", how)
	-- #1936 (release.md section 3), analytics only: a purchase prompt refused with no tap or during a catch, rescue or
	-- cutscene, "source:reason" (bait, store or cafePass; no_tap or busy)
	storeGuardBlocked = Signal.new(), -- (what)   forward as TelemetryReport("store_guard_blocked", what)
	-- F96 (starter-cat.md section 2): the Bellhop Cat's stand card
	claimStarterCat = Signal.new(), -- ()   Take me home: forward as ClaimStarterCat
	joinGroup = Signal.new(), -- ()   Join the group (only once the game has a group): GroupService:PromptJoinAsync(Config.GroupId)
	-- F100 (camp-extras.md section 3)
	buyYardSale = Signal.new(), -- (crateId)   Buy on the Yard Sale card: forward as BuyYardSale
	yardSalePick = Signal.new(), -- ()   #3615: Lucky pick on the Yard Sale card: forward as YardSalePick
	pickPicnicTreat = Signal.new(), -- (treatId)   #3715: Pick on the Picnic Treats card: forward as PickPicnicTreat
	yardSaleLanded = Signal.new(), -- (crateId)   #3615: the card's board landed on the picked crate
	-- #2651 part 4: (remote, ...)   a press on the Oasis Spa or Relic Museum card: forward as that remote (SpaPut,
	-- SpaTakeOut, SpaCollect, SpaBuySlot, MuseumDonate or MuseumFill) with its arguments
	lateStation = Signal.new(),
	-- #3196 (the Mystic Pool's card): forward as RollTrait(uid), ChooseTrait(takeNew) and CollectTraitTokens()
	rollTrait = Signal.new(), -- (uid)
	chooseTrait = Signal.new(), -- (takeNew)
	collectTraitTokens = Signal.new(), -- ()
	-- (itemId, window, shownPrice, catUid?)   Buy in the Corner Shop (#1052): forward as BuyCornerShop
	buyCornerShop = Signal.new(),
	buyMystery = Signal.new(), -- #2574: (itemId, shownPrice), forwarded as BuyMystery
	mysterySeen = Signal.new(), -- #2574: Juniper's window opened, forwarded as MarkMysterySeen
	setBagColours = Signal.new(), -- #3699: (main, trim) from the Backpack's colour picker, forwarded as SetBagColours
	buyCornerShopAll = Signal.new(), -- (kind, window)   #2593: Buy all on a Day Cart section: forward as BuyCornerShopAll
	-- (foodId, catUid)   #1181: Feed a cat from the Bag's Cat Food tab: forward as FeedCat; FeedResult calls UI.bag.fed
	feedCat = Signal.new(),
	-- (hide)   #1083: Settings' "Show my name on the Thank You board" off (true) or on: forward as SetHideCredit
	setHideCredit = Signal.new(),
	-- (productId)  #1770 owner test mode: a product's buy button on the owner's account; forward as OwnerGrant
	ownerGrant = Signal.new(),
	-- F102 (trading.md section 6): the client only asks; TradeState answers
	requestTrade = Signal.new(), -- (userId)   Trade on a players list row: forward as TradeRequest
	respondTrade = Signal.new(), -- (requestId, accept)   Accept or Decline on the request card: forward as TradeRespond
	tradeOffer = Signal.new(), -- (tradeId, "add" | "remove" | "set", id, kind?, count?)   forward as TradeOffer (kind
	-- "decor", "crate", "fish")
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
local replayTidy: Signal.Connection? = nil -- #2157: UI.events.introReplay, cleared at destroy
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
local bugReportScreen: BugReport.BugReport? = nil -- the Feedback window, from the HUD's Feedback tile
local arcadeScreen: Arcade.Arcade? = nil -- #3062: the Cat Arcade window (the cabinet and the Menu list open it)
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
-- #2759: a fresh save's intro on its way: begun once one started this session; the strip waits LIMIT seconds from
-- the UI's start at most (a field, as the module has no local registers to spare)
UI._introWait = { begun = false, LIMIT = 30, startedAt = os.clock(), timed = false }
UI._baitNudged = false -- #2775: the first bait's tip card was queued this session (UI.bait.set)
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
-- #3666: whether the intro plays itself for this player; the server says (the intro test), else Config. A field,
-- as the module has no local registers to spare
function UI._introAuto(): boolean
	if state.introAuto ~= nil then
		return state.introAuto
	end
	return Config.IntroAutoPlay
end
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
		wrapUp = UI.cannon.wrapUp.on,
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
	-- #3893 (Review-QA's Studio run, 2026-11-14): after the Park's "is open" hint has had its time, the walk to the Park
	-- keeps a line on the strip, at home, in the square and in the Alley, until the Park is reached
	-- (Review-QA's re-test: the generic "Hop in the cannon to catch more cats!" took the line over after the "is open"
	-- hint, so it gives way to the Park line too; the arrow stays on the cannon, the way to the Park)
	local cards: any = UI -- UI.parkTrail is built further down
	local park = cards.parkTrail
	if
		(text == nil or hint == CannonLogic.WRAP_UP_HINT)
		and park.goal ~= nil
		and not park.reached
	then
		text = park.STRIP
	end
	-- #2411: the × hides the strip only once the first walk-through is done; before that it still guides. #3893
	-- (Derek 2026-11-13: "still show the tips all the way up to going to park"): and only once the Park is reached
	if
		not tutorialButtonOn
		and (state.tutorialStep or math.huge) >= CannonLogic.WALKTHROUGH_STEP
		and UI.parkTrail.reached
	then
		text, target = nil, nil
	end
	-- #2759: a fresh save's intro is on its way (it waits for the camp to stream in): no strip, glow or arrow over the
	-- loading view. At most UI._introWait.LIMIT seconds from the UI's start, should no intro come.
	local waited = os.clock() - UI._introWait.startedAt
	local introPending = UI._introAuto()
		and not UI._introWait.begun
		and state.introSeen == false
		and waited < UI._introWait.LIMIT
	if introPending then
		text, target = nil, nil
		if not UI._introWait.timed then
			UI._introWait.timed = true
			task.delay(UI._introWait.LIMIT - waited + 0.1, function()
				if hud ~= nil and not UI._introWait.begun then
					applyTutorial()
				end
			end)
		end
	end
	if hud then
		hud:holdTutorial(introPending)
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
	UI.parkTrail.tutorial = target ~= nil
	UI.parkTrail.apply(target)
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
	if hud then
		hud:holdBanner("intro", false)
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
-- #3188: and only once the "Catch a 2nd cat" goal is finished and the player is at their cafe (UI.giftWait.atCafe;
-- its once-a-second look also runs this, so the window opens as they arrive).
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
		not DailyTreatLogic.autoOpen(
			view,
			now,
			state.tutorialStep,
			(state :: any).secondCatDone -- (UIController's; the HUD's own state type has no use for it)
		)
		or not visible
		or windows == nil
		or windows:current() ~= nil
		or UI.intro.playing()
		or introBlocked()
		-- #3155 (Derek2: "daily treat pop up should also wait until after tutorial steps are done"): the step's
		-- strip and the cannon walk-through after it go first
		or tutorialText ~= nil
		or hintShown ~= nil
		-- #4005: on the account's first day the "!" on its button is enough
		or not (function(): boolean
			local QuietStart =
				require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("QuietStart")) :: any
			local firstDay = Players.LocalPlayer:GetAttribute(QuietStart.DAY_ATTRIBUTE)
			return QuietStart.treatOpensItself(
				(QuietStart.live()),
				firstDay,
				now // QuietStart.DAY_SECONDS
			)
		end)()
		-- #3188: last, so the plot is only looked up when everything else is ready (defined further down the module)
		or not DailyTreatLogic.autoOpen(view, now, nil, nil, (UI.giftWait :: any).atCafe())
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
		if state.introSeen == false and not UI._introAuto() and not introGlowed then
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
	UI.campExtras.crates(state.crates) -- #2214: the "!" over the Fish Market
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
	UI.arcade.render(state)
	UI.mouseDash.render(state)
	UI.lateStations.render(state)
	UI.mysticPool.render(state)
	UI.cornerShop.render(state)
	UI.mystery.render(state)
	UI.trade.render(state)
	UI.nursery.render(state)
	UI.store.render()
	UI.pass.render()
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
			-- #2710: on touch the Bag holds the potions, so the potion chip (and the Bag) open it on its Potions tab
			if
				name == "Potions"
				and potionsScreen
				and Scale.isTouch()
				and modalInstance:current() ~= name
			then
				potionsScreen:showTab("Potions")
			end
			modalInstance:toggle(name)
			if name == "Store" and modalInstance:current() ~= "Store" then
				-- #1888: the tap closed the Store, so a noted source tags no open
				local funnel: any =
					require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StoreFunnel"))
				funnel.takeSource()
			end
		end,
		travel = function(destination: string)
			UI.events.travel:Fire(destination)
		end,
		openBait = openBait,
		takeCozy = function()
			UI.events.takeCozy:Fire()
		end,
		-- #2353: the X2 Cash pill opens Roblox's window for the 2x pass, through the Store's tap guard (#1936)
		buyPass = function(id: number)
			local PassShop = require(script.Components.PassShop)
			PassShop.prompt(id, "store")
		end,
		-- #1919: the goal card's nudge opens the Index on the newest open area with the most cats to find
		openIndexAt = function(areaId: string?)
			if collection then
				if areaId then
					collection:showArea(areaId)
				else
					collection:showTab("Index")
				end
			end
			if modalInstance:current() ~= "Collection" then
				modalInstance:open("Collection")
			end
			UI.events.indexHintTap:Fire(areaId or "none")
		end,
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
		-- #2912: the tutorial strip's Buy button, the same request as the Upgrades row's Buy
		buyUpgrade = function(upgradeId: string)
			UI.events.buyUpgrade:Fire(upgradeId)
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
			UI.toast(
				-- Review-QA's Studio run (2026-11-14): short enough for a 667 px phone's toast
				if (state.tutorialStep or math.huge) < CannonLogic.WALKTHROUGH_STEP
					then "Tips hidden. Your first steps still show."
					elseif
						not UI.parkTrail.reached
					then "Tips hidden. The way to the Park still shows."
					else "Tutorial and tips hidden. Turn them on in Settings.",
				"info"
			)
		end,
		setSetting = function(key: string, value: boolean)
			UI.events.setSetting:Fire(key, value) -- #1893: the Grand Opening strip's roadmapOpen
		end,
		openFeedback = function()
			UI.bugReport.open() -- F87: the faces page first
		end,
		openIdea = function()
			UI.bugReport.open("idea") -- #3883: the map theme bubble
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
		-- #1624: the Style tab; the sign goes to SetSignStyle, uniforms and themes to SetLook
		pickStyle = function(kind: string, id: string)
			UI.events.pickStyle:Fire(kind, id)
		end,
		setLawnSpot = function(spotId: string, pieceId: string)
			UI.events.setLawnSpot:Fire(spotId, pieceId)
		end,
		setLawnStyle = function(kind: string, id: string)
			UI.events.setLawnStyle:Fire(kind, id)
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
		setAutoEquip = function(on: boolean)
			UI.events.setSetting:Fire("autoEquip", on) -- #1955
		end,
		close = closeModal,
	})
	rankUpScreen = RankUp.new({
		rankUp = function()
			UI.events.rankUp:Fire()
		end,
		fly = function()
			UI.cannon.flyToPark() -- #2915
		end,
		close = closeModal,
		perks = function()
			-- #2687: "Your perks" over the window
			if UI.perks.card then
				UI.perks.card:showList(
					state.tier,
					require(script.Components.PerkCardLogic).poolStands()
				)
			end
		end,
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
		-- #3082: Collect on a card's strip, from anywhere (UIController sends CollectCampExtra; #1463 had it for a
		-- Golden Pond owner's pond)
		collect = function(extraId: string)
			-- #3715: with Picnic Treats on, the basket's button opens its pick card instead
			if extraId == "picnic" and UI.campExtras.treats() then
				UI.campExtras.openPicnic()
				return
			end
			-- #3955: the Lost and Found's button opens its card, where the find is revealed
			if extraId == "lostFound" then
				UI.campExtras.openLostFound(true)
				return
			end
			UI.events.collectCampExtra:Fire(extraId)
		end,
		-- #3082: Open on a card's strip: the station's own card takes the picker's place
		open = function(stationId: string)
			-- #3213: opened from the Cannon, the card stays open wherever the player stands (no walk-away close)
			if stationId == "yardSale" then
				UI.campExtras.openYardSale(nil, true)
			elseif stationId == "mysticPool" then
				UI.mysticPool.open(true) -- #3196
			else
				UI.lateStations.open(stationId, true)
			end
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
			hudInstance:goalSeen() -- #2331: the goal card stops pointing at the rank up
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
		buyAll = function(window: number?)
			UI.events.buyDealerAll:Fire(window)
		end,
		close = closeModal,
	})
	local dealerView = dealerScreen :: Dealer.Dealer
	modalInstance:register("Dealer", {
		frame = dealerView.frame,
		onOpen = function()
			dealerView:render(state)
			UI.dealer.seen() -- #3195: the "!" over the cart goes for the rest of the night
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
			elseif key == "catIncome" and worldTags ~= nil then
				worldTags:setRates(value == true) -- #2551: a tap, or the saved value from a sync
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
			UI.toast("Tips will show again as you play.", "info") -- #3080: the press's only answer
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
		openAllCrates = function(crateId: string)
			UI.events.openAllCrates:Fire(crateId)
		end,
		buyItem = function(itemId: string)
			UI.events.buyFishItem:Fire(itemId)
		end,
		useDecor = function(decorId: string)
			UI.events.toggleDecor:Fire(decorId, true)
		end,
		toast = function(text: string, kind: Types.ToastKind?)
			if toasts then
				toasts:show(text, kind or "good")
			end
		end,
		close = closeModal,
		bigPull = function(decorId: string, onUse: (() -> ())?)
			UI.bigPull.piece(decorId, onUse)
		end,
		seen = function(tab: string)
			UI.events.storeSeen:Fire(tab) -- #2571: the Treats tab opened, forwarded as MarkStoreSeen
		end,
	})
	local marketView = marketScreen :: FishMarket.FishMarket
	modalInstance:register("Market", {
		frame = marketView.frame,
		onOpen = function()
			marketView:render(state)
		end,
	})
	arcadeScreen = Arcade.new({
		play = function()
			UI.events.arcadePlay:Fire()
		end,
		press = function(run: number, block: number, index: number)
			UI.events.arcadePress:Fire(run, block, index)
		end,
		quit = function(run: number)
			UI.events.arcadeQuit:Fire(run)
		end,
		close = closeModal,
	})
	local arcadeView = arcadeScreen :: Arcade.Arcade
	modalInstance:register("Arcade", {
		frame = arcadeView.frame,
		onOpen = function()
			arcadeView:setFish(state.goldenFish or 0)
			arcadeView:onOpen()
		end,
		onClose = function()
			arcadeView:onClose()
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
		use = function(potionId: string, count: number?)
			UI.events.usePotion:Fire(potionId, count)
		end,
		useEvery = function()
			UI.events.usePotionAll:Fire()
		end,
		feed = function(foodId: string, catUid: string)
			local cat = (state.cats or {})[catUid]
			bagFed[catUid] = if cat and type(cat.level) == "number" then cat.level else 0
			local events: any = UI.events
			events.feedCat:Fire(foodId, catUid)
		end,
		setTitle = function(pick: string)
			UI.events.passSetTag:Fire(pick) -- the server checks the pick (ChatTags.choices) and sends CafePassState
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
		-- #3132: his arrival as a short banner with the cat's face in the toast stack
		announce = function(def: Types.CatDef?, shiny: boolean, line: string, tap: () -> ())
			if toasts then
				local CollectorLogic = require(script.Components.CollectorLogic)
				toasts:cat({
					def = def,
					shiny = shiny,
					title = CollectorLogic.BANNER_TITLE,
					line = line,
					seconds = CollectorLogic.BANNER_SECONDS,
					onTap = tap,
				})
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
		-- Derek 2026-11-13: no pop-up bubbles while playing the arcade or rerolling traits (Toasts.setBusy)
		-- (required here, not at the top: the file is at the 200 local limit)
		local view = toasts
		if view then
			local dashWindow = require(script.Components.MouseDashLogic).WINDOW
			local poolWindow = require(script.Components.MysticPoolLogic).WINDOW
			UI.rollBusy.window = name == dashWindow or name == "Arcade" or name == poolWindow
			view:setBusy(UI.rollBusy.window or UI.rollBusy.on or UI.cutscene.on)
		end
		-- Derek 2026-11-13: and the event and day strip steps aside while Mouse Dash or the Mystic Pool is open
		hudInstance:holdBanner("window", UI.rollBusy.window)
	end)

	catch = CatchPrompt.new(parent)
	circles = CatchCircles.new(parent)
	rescueBar = RescueBar.new(parent)
	actionPills = ActionPill.new(parent)
	richTipScreen = RichTip.new(parent, {
		collect = function(bagId: string)
			UI.events.claimRichTip:Fire(bagId)
		end,
		-- only a claimed tip pays (data-model 12 v0.13.4); a missed one leaves with nothing
		collected = function(amount: number, position: Vector3?)
			-- #2399: the gold "+$" over the tip says it; the toast only when there is no spot to float it over
			if position then
				UI.floatText(
					position + Vector3.new(0, 2, 0),
					"+" .. Format.money(amount),
					Theme.colors.gold
				)
			else
				UI.toast("Rich tip! +" .. Format.money(amount), "good")
			end
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
		-- hidden while carrying or during the circles or the rescue bar (reviewer N85), and while the intro's screen
		-- plays: the tackle lesson draws its own pressed Tackle bar over the caption (#2474, Laptop-Tester: two bars)
		blocked = function()
			return hudInstance:isCarrying()
				or UI.catch.circlesActive()
				or UI.rescue.isActive()
				or UI.intro.playing()
		end,
		lift = function()
			return hudInstance:tackleTop() -- #3119: under the Drop off touch
		end,
	})
	netButton = NetButton.new(parent, {
		swing = function()
			UI.events.netSwing:Fire()
		end,
		blocked = function()
			-- #2409: the catch prompt's touch button takes the Net button's spot while it shows
			local prompt = catch
			return UI.catch.circlesActive()
				or UI.rescue.isActive()
				or (prompt ~= nil and prompt:grabShowing())
		end,
	})
	local toastsInstance = Toasts.new(parent)
	toasts = toastsInstance
	-- #2724/#2727: toasts that come while the catch circles or the rescue bar run wait for the end (the HUD steps aside
	-- then too, HUD._applyFocus)
	hudInstance.catchingChanged:Connect(function(active: boolean)
		toastsInstance:setFocus(active)
		local pills = actionPills -- #3861: and the action pills step away from the bar
		if pills then
			pills:setQuiet(active)
		end
	end)
	toastsInstance:avoid(
		function() -- #2338: clear of the HUD's menu column and goal card on a phone
			return hudInstance:toastAvoid()
		end,
		function()
			return hudInstance:bottomTop()
		end
	)
	-- #4152: the tutorial's edge arrow keeps off the HUD (the money pill, the menu column, the goal card)
	require(script.Components.StepTarget).setAvoid(function()
		return hudInstance:edgeAvoid()
	end)
	popups = Popups.new(parent)
	-- #2157 (Desktop-Tester on #2128): a replay waits before the intro hides the UI (for the camp to stream in then;
	-- since #3109 for the loading screen's run to 100), so the window it was asked from stayed up about 1.5 s, and a Welcome back card that was up or
	-- waiting came back after the replay. At the ask: the window closes, and the earnings are collected (the server
	-- credits them anyway at the next save), so the card never comes back
	replayTidy = UI.events.introReplay:Connect(function()
		UI.close()
		if popups and popups:dropOffline() then
			UI.events.claimOffline:Fire()
		end
	end)
	-- #2393: on a phone the card comes down under the counters and the Luck row at the top centre
	tipCard = TipCard.new(parent, function(): { GuiObject }
		local current = hud
		if current == nil then
			return {}
		end
		return { current:buffRow(), current:counterRow() }
	end)
	UI.recap.card = require(script.Screens.RecapCard).new(parent) -- #1920
	UI.gift.card = require(script.Screens.GiftCard).new(parent) -- #1947
	UI.loot.card = require(script.Screens.LootCard).new(parent) -- #3464
	UI.perks.card = require(script.Screens.PerkCard).new(parent) -- #2687
	local stationReveal = (Moments :: any).StationReveal
	if stationReveal then
		UI.perks.reveal = stationReveal:Connect(function(_area: string, perkId: string)
			UI.perks.unlock(perkId)
		end)
	end
	-- #1947: every press counts for the gift card's idle wait, so it never shows on an old reading
	UI.gift.inputs = UserInputService.InputBegan:Connect(function()
		UI.recap.lastInput = os.clock()
	end)
	askCard = AskCard.new(parent, {
		-- #2694: a clear gap over the bottom row, so the ask never sits on it
		lift = function()
			return hudInstance:bottomTop() - Theme.sizes.gap * 2
		end,
	})
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function(dt: number)
			ticks.tips(dt)
			ticks.nudges(dt)
			UI.giftLadder.tick(dt)
		end)
	)
	introScreen = Intro.new(parent, {
		skip = function(shot: number)
			UI.events.introSkip:Fire(shot)
		end,
		ended = introEnded,
		nextShot = function(shot: number)
			UI.events.introNext:Fire(shot)
		end,
	})
	carryMarker = WorldMarker.new(parent, "CatCafeCarryMarker", nil, false, true) -- #3055: the small, quiet one
	tutorialMarker = WorldMarker.new(parent, "CatCafeTutorialMarker", nil, true) -- #2697: flashes its target
	tutorialTrail = GuideTrail.new("CatCafeTutorialTrail")
	-- signs over every gate tagged AreaGate, including gates that stream in later
	gateSigns = GateSigns.new(parent)
	-- every area's Index Board, including boards that stream in later; its prompt opens that area's Index page
	require(script.Screens.ThanksBoard).new(parent) -- #1083: the Thank You board's face (no local: init is at Luau's 200)
	require(script.Screens.PitySign).new(parent) -- #1572: the pity cat sign's countdowns (no local, as above)
	indexBoards = IndexBoards.new(parent, {
		open = function(areaId: string)
			UI.openIndex(areaId)
		end,
	})
	-- the icon over My Cafe, fading out up close and smaller far away (the other places' went 2026-10-28)
	local markers = LocationMarkers.new(parent)
	markers:setEnabled(settingsView:value("markers")) -- the map icons switch (My Cafe, Night Market)
	locationMarkers = markers
	UI.dealer.startBang(parent) -- #3195: the "!" over the Night Market until it is opened tonight
	areaTitle = AreaTitle.new(parent)
	-- the name sign over every cafe door, rate tags over working cats and order bubbles over customers
	cafeSigns = CafeSigns.new(parent)
	UI.leaderboards.start(parent) -- the town boards' faces and the crowns over heads (F98)
	UI.together.start(parent) -- the Team Rescue pop and the pal chip (F92)
	UI.campExtras.start(parent) -- the Yard Sale card, the Cannon picker's strips and the stations' "!" (F100)
	UI.lateStations.start() -- the Oasis Spa and Relic Museum cards (#2651 part 4)
	UI.mysticPool.start() -- the Mystic Pool's card (#3196)
	UI.mouseDash.start() -- the arcade's Mouse Dash window (#3296)
	UI.giftWait.start() -- #2614: the HUD's line while a Mystery gift waits on your plot
	UI.cornerShop.start() -- the Corner Shop window (#1052)
	UI.mystery.start(parent) -- Juniper's Mystery Market window and the cart's "!" (#2574)
	UI.rally.start(parent) -- the Rescue Rally banner, the board's face and the clock line (F101)
	UI.cafeEvent.start(parent) -- the Cafe Event chip, its start banner and the square's board face (#2487)
	UI.trade.start() -- the Trade window in the modal (F102)
	UI.nursery.start() -- the Garden Nursery window, opened from its stall's prompt (#1200)
	UI.store.start() -- the Store window and the HUD's Store tile (shown on sale or not, #1167)
	UI.pass.start() -- the Cafe Pass window; its HUD tile shows while a season runs (#1646)
	worldTags = WorldTags.new(UI.settings.value("catIncome")) -- #2551: the Cat income switch as it stands now
	-- Catch v3 (catch-rework.md 7a): the mood icon over each stray within 20 studs (inline: the module is short of locals)
	local catchUI: any = UI.catch
	catchUI.moods = require(script.Screens.MoodIcons).new()
	catchUI.pity = require(script.Screens.PityTags).new() -- #2099: the "Pity cat" tag over a pity stray
	catchUI.secret = require(script.Screens.SecretTags).new() -- #3470: the "SECRET" tag over a Secret stray
	catchUI.mark = require(script.Screens.CatchMark).new() -- #2005: the "!" over a stray being caught (NetDown)
	UI.newKind.start() -- #3529: the "NEW" tag over strays of kinds not owned (off with its switch)
	UI.bubbles.start(parent) -- the one-line speech bubbles over the town's key cats (#1079)
	-- the hover card over cats: mouse hover, a tap, or the nearest own cat on gamepad (F75)
	catCard = CatCard.new(parent, {
		blocked = function()
			return not visible or modalInstance:current() ~= nil
		end,
	})

	setCatalog(config.catalog)

	if config.keybinds ~= false then
		-- #2872 (console): the selection ring, and Select starts on the menu grid instead of Roblox's own pick
		UI.gamepadStart(parent)
		table.insert(
			connections,
			UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
				-- #2872: the gamepad's menu keys come before gameProcessed, which is true while a button is selected
				if visible and input.KeyCode == Enum.KeyCode.ButtonSelect then
					UI.gamepadSelect()
					return
				elseif
					visible
					and input.KeyCode == Enum.KeyCode.ButtonB
					and modalInstance:current() ~= nil
				then
					modalInstance:close()
					return
				end
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
				elseif
					key == Enum.KeyCode.G and (hudInstance:isCarrying() or hudInstance:isPacked())
				then
					UI.events.dropCat:Fire()
				end
			end)
		)
	end

	render()
	return UI
end

-- #2872 (console): the selection ring in `parent`, and Roblox's own pick on Select off (UI.gamepadSelect starts on the
-- menu grid instead).
function UI.gamepadStart(parent: Instance)
	local nav = require(script.Components.GamepadNav)
	nav.highlight(parent)
	local guiService = game:GetService("GuiService")
	guiService.AutoSelectGuiEnabled = false
end

-- #2872 (console): Select (the View button) on a gamepad. With a button selected it lets go, so the sticks walk
-- again; otherwise it selects the open window's first button, or the HUD's Store tile and menu grid.
function UI.gamepadSelect()
	local guiService = game:GetService("GuiService")
	if guiService.SelectedObject ~= nil then
		guiService.SelectedObject = nil
		return
	end
	local open = if modal ~= nil and modal:current() ~= nil then modal.container else nil
	local target: GuiObject? = if open ~= nil
		then require(script.Components.GamepadNav).first(open)
		elseif hud ~= nil then hud:gamepadMenu()
		else nil
	if target ~= nil then
		require(script.Components.GamepadNav).select(target) -- #3839: never a hidden or taken out button
	end
end

function UI.isInitialized(): boolean
	return initialized
end

-- Merge a partial state and re-render. Pass whole maps (catsOwned, upgradeLevels...) when they change.
function UI.update(partial: Types.PartialState)
	for key, value in partial :: { [string]: any } do
		(state :: any)[key] = value
	end
	if partial.collection ~= nil then
		UI.newKind.refresh() -- #3529: a kind just caught loses its "NEW" tag at once
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
					-- #2915: the rank-up card's button reads "Fly to the Park" until the next flight
					local parkFirst = require(script.Components.ParkFirstLogic)
					local card = rankUpScreen
					if area.id == parkFirst.AREA and card ~= nil then
						card:setFly(parkFirst.FLY_TEXT)
					end
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
	-- #2477 (Derek2: "the tutorial should guide you to cannon after bait bowl"): the walk-through ending in this
	-- session (tutorialStep from under WALKTHROUGH_STEP to it) points the cannon hint at the cannon until the next
	-- flight, even if the player flew earlier. The first update with a step only records it, so a rejoin never does.
	local step: number? = partial.tutorialStep
	if step ~= nil then
		local wrap = UI.cannon.wrapUp
		local before = wrap.step
		wrap.step = step
		if
			before ~= nil
			and before < CannonLogic.WALKTHROUGH_STEP
			and step >= CannonLogic.WALKTHROUGH_STEP
		then
			wrap.on = true
			cannonLaunched = false
		end
	end
	deriveState(partial)
	render()
	UI.giftLadder.refresh() -- #2791
end

-- #3883: the map theme bubble under the Feedback tile now (the UI gate's picture; the HUD shows it by itself)
function UI.feedbackCallout()
	local view = hud
	if view then
		view:showCallout()
	end
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
	if replayTidy then
		replayTidy:Disconnect()
		replayTidy = nil
	end
	table.clear(connections)
	UI.catch.unbindProximityPrompts()
	UI.clock.unbind()
	UI.bigPull.reset()
	UI.leaderboards.reset()
	UI.together.reset()
	UI.campExtras.reset()
	UI.lateStations.reset()
	UI.mysticPool.reset()
	UI.mouseDash.reset()
	UI.mystery.reset()
	UI.giftWait.reset()
	UI.rally.reset()
	UI.cafeEvent.reset()
	UI.trade.reset()
	UI.nursery.reset()
	UI.store.reset()
	UI.pass.reset()
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
	UI.cannon.wrapUp.step, UI.cannon.wrapUp.on = nil, false
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
	UI.dealer.stopBang()
	if cafeSigns then
		cafeSigns:destroy()
	end
	if worldTags then
		worldTags:destroy()
	end
	local catchUI: any = UI.catch
	if catchUI.moods then
		catchUI.moods:destroy()
		catchUI.moods = nil
	end
	if catchUI.pity then
		catchUI.pity:destroy()
		catchUI.pity = nil
	end
	if catchUI.secret then
		catchUI.secret:destroy()
		catchUI.secret = nil
	end
	if catchUI.mark then
		catchUI.mark:destroy()
		catchUI.mark = nil
	end
	UI.newKind.stop()
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
	if UI.recap.card then
		UI.recap.card:destroy()
		UI.recap.card = nil
	end
	UI.recap.waiting = nil
	if UI.loot.card then
		UI.loot.card:destroy()
		UI.loot.card = nil
	end
	if UI.gift.card then
		UI.gift.card:destroy()
		UI.gift.card = nil
	end
	if UI.perks.reveal then
		UI.perks.reveal:Disconnect()
		UI.perks.reveal = nil
	end
	if UI.perks.card then
		UI.perks.card:destroy()
		UI.perks.card = nil
	end
	UI.perks.token += 1
	if UI.gift.inputs then
		UI.gift.inputs:Disconnect()
		UI.gift.inputs = nil
	end
	table.clear(UI.gift.queue)
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

-- #3640: the server moved this player (the tutorial's move to the cannon): a new cat's card still up closes, so
-- the Cat Cannon window does not open over it.
function UI.closeCatCard()
	if popups then
		popups:dismissCat()
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

-- `seconds` (optional) keeps the toast up that long in place of the usual 2.4 s.
function UI.toast(text: string, kind: Types.ToastKind?, seconds: number?)
	-- a bug report waiting on the server: its "Thanks!" closes the window, its refusals keep the words, and any
	-- other toast leaves the report waiting (review N151). #3080: read before the rules below, so the window gets
	-- its answer whether or not the words show
	if bugReportScreen and bugReportScreen:pending() then
		local answer = BugReportLogic.answer(text)
		if answer ~= nil then
			bugReportScreen:result(answer)
		end
	end
	-- #2600: no "Bought ..." pop-ups, #3080: nor any green one off the keep list (ToastRules.quiet); init.luau is at
	-- the 200-local limit, so it loads here
	if require(script.Components.ToastRules).quiet(text, kind) then
		return
	end
	if toasts then
		toasts:show(text, kind, nil, seconds)
	end
end

-- Server-wide shout-out (Epic and better catches), Announce(text, rarity?). The rarity colours it; without it the
-- last rarity named as a whole word in the text decides. Silent: Audio plays the sting from the remote.
-- #2399: only Legendary and better show, and on touch one every ToastRules.ANNOUNCE_GAP seconds below Mythical
-- (ToastRules.announce); true when it showed.
-- (init.luau is at Luau's 200 locals a scope, so the rules load here and the time lives on UI.shoutout)
UI.shoutout = { at = nil :: number? }
-- Review-QA on #3904: a shout-out slid across the Rummage Bin's board mid-roll. While a roll or reveal plays
-- (BinController) the pop-ups wait, as on a busy window (Toasts.setBusy); `window` is the open window's own part.
-- Review-QA on #4002 (Studio): after Give up the rich customer's card came up half a second later over the board's
-- next roll (the pad starts the next try by itself). The cards (not the toasts) also wait CALM seconds after a roll
-- or its bar ends: `held()`.
-- Review-QA (b9e3f2523, Studio): the card then came over the bin's result board once the bar and the calm were past.
-- `board` is BinController's: true while a Rummage Bin board is up for this player (they stand at the bin), and the
-- cards wait the whole time it is, then CALM more.
UI.rollBusy = { on = false, window = false, board = false, offAt = nil :: number?, CALM = 5 }
function UI.rollBusy.held(): boolean
	if UI.rollBusy.board then
		UI.rollBusy.offAt = os.clock()
		return true
	end
	-- Review-QA (ea186f64): the roll's show ends when the bar comes, so the bar (and the board after it) count too:
	-- while a bar is up the calm starts again
	local rescue: any = (UI :: any).rescue
	if rescue ~= nil and rescue.isActive() then
		UI.rollBusy.offAt = os.clock()
		return true
	end
	local offAt = UI.rollBusy.offAt
	return UI.rollBusy.on or (offAt ~= nil and os.clock() - offAt < UI.rollBusy.CALM)
end
function UI.setRollBusy(on: boolean)
	if UI.rollBusy.on == on then
		return
	end
	UI.rollBusy.on = on
	if not on then
		UI.rollBusy.offAt = os.clock()
	end
	local view = toasts
	if view then
		view:setBusy(UI.rollBusy.window or on or UI.cutscene.on)
	end
end
-- #4018 (Derek OK'd the Mythic and up trait pull cutscene, 2026-11-13: every banner and pop-up muted while it plays,
-- the food bowl's above all): while a cutscene runs (Motion-FX's scenes call UI.setCutscene), toasts wait in the toast
-- view's busy queue, shout-outs wait here (the last CUTSCENE_KEEP, in order) and come out one by one afterwards, and
-- the food bowl cards (UI.bait.busy), tips, ask and first visit cards (tipMoment) and the "Unlocked!" card wait too.
-- The scene hides the HUD itself.
-- `hooks`: callers that hide their own pieces too (UIController's bait bowl prompts, from #4077)
UI.cutscene = {
	on = false,
	queue = {} :: { { text: string, rarity: string? } },
	hooks = {} :: { (on: boolean) -> () },
	KEEP = 3,
	GAP = 1.5,
}
function UI.setCutscene(on: boolean)
	local cut = UI.cutscene
	if cut.on == on then
		return
	end
	cut.on = on
	for _, hook in cut.hooks do
		task.spawn(hook, on)
	end
	local view = toasts
	if view then
		view:setBusy(UI.rollBusy.window or UI.rollBusy.on or on)
	end
	-- the event strip steps aside too (HUD.holdBanner, #4032)
	if hud ~= nil then
		hud:holdBanner("cutscene", on)
	end
	if on then
		return
	end
	local waiting = cut.queue
	cut.queue = {}
	for index, item in waiting do
		task.delay((index - 1) * cut.GAP, function()
			if not UI.cutscene.on then
				UI.announce(item.text, item.rarity)
			end
		end)
	end
	-- Derek 2026-11-13: the event and day strip stays down through the roll too
	local board = hud
	if board then
		board:holdBanner("roll", on)
	end
end
function UI.announce(text: string, rarity: string?): boolean
	local ToastRules = require(script.Components.ToastRules)
	local now = os.clock()
	local cut = UI.cutscene
	if cut.on then
		table.insert(cut.queue, { text = text, rarity = rarity })
		if #cut.queue > cut.KEEP then
			table.remove(cut.queue, 1)
		end
		return false
	end
	-- Derek 2026-11-13: dropped, sting and all, while Mouse Dash or the Mystic Pool is open (Toasts.setBusy)
	local view = toasts
	if view and view:isBusy() then
		return false
	end
	if not ToastRules.announce(rarity, now, UI.shoutout.at, Scale.isTouch()) then
		return false
	end
	if rarity ~= nil then
		UI.shoutout.at = now
	end
	if toasts then
		toasts:announce(text, rarity)
	end
	return true
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
		-- #2833 (Derek2: "only do the double pop-up if its a legendary+ or any new cat"): a repeat below Legendary
		-- gets no big card (Components/CatFoundLogic), and #2844 no "joined your cafe" toast either ("it just adds
		-- bloat"): the catch's own small pop-up already said it
		local CatFoundLogic = require(script.Components.CatFoundLogic) :: any
		if not CatFoundLogic.big(def.rarity, isNew, info) then
			return
		end
		-- #4005: before Tier 2 a new kind below Epic is a toast; the tutorial's catches and any coat, banner or line
		-- keep the card
		local QuietStart =
			require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("QuietStart")) :: any
		local plain = not (info.shiny or info.rainbow or info.banner ~= nil or info.line ~= nil)
		local Onboarding =
			require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Onboarding")) :: any
		local tutorial = (state.tutorialStep or math.huge) < Onboarding.NEW_PLAYER_STEP
		if
			plain and QuietStart.foundToast((QuietStart.live()), state.tier, def.rarity, tutorial)
		then
			UI.toast(string.format("New cat: %s!", def.name), "good")
			return
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
-- F95: the welcome back card says what time away pays, the Long Nap pass's line when state.longNap. #2123: and one
-- line on what is waiting today (WelcomeBack.hookLine of state.returnHook).
-- Collect plays Sound-Agent's offlineClaim cue once per claim (the card hands its callback out once).
function UI.showOfflineEarnings(amount: number, seconds: number)
	if popups then
		local WelcomeBack = require(script.Components.WelcomeBack)
		local note = WelcomeBack.note(state.longNap)
		-- #2123: the reason to play today, from Gameplay's ReturnHook pick (nil: no line)
		local hook = WelcomeBack.hookLine((state :: any).returnHook)
		-- #2916: with no pick, Gameplay's nearest goal (the one the last session's recap led with)
		if hook == nil then
			hook = require(script.Components.ReturnGoalWords).welcomeLine(
				(state :: any).returnGoals,
				Format.money
			)
		end
		popups:showOffline(amount, seconds, function()
			Sound.play("offlineClaim")
			UI.events.claimOffline:Fire()
		end, UI.tips.offlineLine(seconds), note, hook)
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
	-- #2775: the account's short first bait (Components/FirstBait) brings one tip card saying to go catch another
	-- cat meanwhile, at the next free moment (after the Bait window closes)
	if bait ~= nil and not UI._baitNudged then
		local FirstBait = require(script.Components.FirstBait)
		if FirstBait.coming(bait) then
			UI._baitNudged = true
			UI.tips.nudge(function(): string?
				return FirstBait.nudge(bowls.views[index], Workspace:GetServerTimeNow())
			end, FirstBait.NUDGE_ICON)
		end
	end
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
			PassShop.prompt(id, "bait")
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
		-- #1161: with two bowls the banner names the bowl
		local two = bowls.second == "on" or bowls.views[2] ~= nil
		baitCard:show(
			def :: Types.CatDef,
			cat,
			if lureId then foodName(lureId) else nil,
			if two then index else nil,
			state.tutorialStep == 4 -- #3815: the first bowl cat, which the tutorial's last step waits on (#3158)
		)
	end
	renderBait()
end

-- #2014 (Derek2: "food bowl cats wait until not mid catch to pop up on screen"): a cat the server says came to a bowl
-- (BaitReady). Its card shows at once unless a catch or rescue is running; then the cat waits at its bowl (the chip
-- shows it) and the card comes a moment after the catch or rescue ends. A cat resolved or replaced in the meantime,
-- or a card already up, drops it. A tap on the bowl chip or prompt (showReady) still shows the card at once.
UI.bait.SETTLE = 0.8 -- seconds of calm after a catch or rescue before the card shows
UI.bait.cutting = nil :: (() -> boolean)? -- #2946: Effects/FirstBaitCut.playing, so the cards wait for the cutscene

-- #2412 (Derek2: "make food bowl cat pop ups never appear mid catch or while holding a cat"): carrying a cat counts
-- as busy too, and the first wow card (UI.bait.wow) waits the same way
function UI.bait.busy(): boolean
	local catch: any, rescue: any = UI.catch, UI.rescue
	local circles, rescuing = catch.circlesActive, rescue.isActive
	return (type(circles) == "function" and (circles :: () -> unknown)() == true)
		or (type(rescuing) == "function" and (rescuing :: () -> unknown)() == true)
		or (hud ~= nil and hud:isCarrying())
		or (UI.bait.cutting ~= nil and (UI.bait.cutting :: () -> boolean)()) -- #2946: the first bait's cutscene
		or UI.bigTraitCutting() -- #3846: a Legendary or Mythic trait roll's cutscene
		or UI.bait.away() -- #4035: out catching in an area
		or UI.cutscene.on -- #4018: any cutscene (UI.setCutscene)
end

-- #4035 (Derek 2026-11-13: "remove all food bowl pop ups etc until your back in town square way too many annoying
-- popups when out looking for and catching cats"): with the quietAway switch on, the bowl cards wait while the
-- player's net is out (the server's NetHidden is clear only in a catching area's wild part, outside its camp), and
-- come one at a time once they are back in town, a cafe or a camp. The bowl chip still shows its "!" meanwhile.
function UI.bait.away(): boolean
	local LiveFlags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags"))
	if
		not LiveFlags.shown(
			"quietAway",
			ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. "quietAway")
		)
	then
		return false
	end
	local character = Players.LocalPlayer.Character
	-- NetHidden is off in an area's wild part outside its camp, and on while carrying (CatService.markCamps), so a
	-- carry counts as away too: the run back to camp stays quiet (review of #4040)
	return character ~= nil
		and (
			character:GetAttribute("NetHidden") ~= true
			or character:GetAttribute("CarryingCatId") ~= nil
		)
end

-- #3846: Effects/BigTraitCut.playing, set by the controller as UI.mysticPool.cutting: pop-up cards (bait, gift) wait
-- while a Legendary or Mythic trait roll's cutscene holds the camera.
function UI.bigTraitCutting(): boolean
	local pool: any = UI.mysticPool
	local cutting = if type(pool) == "table" then pool.cutting else nil
	return type(cutting) == "function" and cutting() == true
end

-- Runs `show` once the player has been calm (not busy) for SETTLE seconds, unless `wanted` turns false first.
function UI.bait.whenCalm(wanted: () -> boolean, show: () -> ())
	task.spawn(function()
		local calm: number? = nil
		while wanted() do
			if UI.bait.busy() then
				calm = nil
			elseif calm == nil then
				calm = os.clock()
			elseif os.clock() - (calm :: number) >= UI.bait.SETTLE then
				show()
				return
			end
			task.wait(0.2)
		end
	end)
end

function UI.bait.arrived(cat: Types.BaitCat, bowl: number?)
	local index = if bowl == 2 then 2 else 1
	if not UI.bait.busy() then
		UI.bait.showReady(cat, index)
		return
	end
	bowls.cats[index] = cat
	renderBait()
	UI.bait.whenCalm(function()
		return bowls.cats[index] == cat
	end, function()
		if baitCard ~= nil and baitCard:isShowing() then
			return
		end
		UI.bait.showReady(cat, index)
	end)
end

-- #1897: FirstWow(rarity, first) from the server: the first wow cat came to the bowl (UI.bigPull.wow plays it). The
-- card's portrait is the cat at a bowl with that rarity (BaitReady comes first), unless the server names it.
function UI.bait.wow(rarity: string, first: boolean?, catId: string?)
	if UI.bait.busy() then
		-- #2412: after the catch or the carry; gone if the bowl's cat left meanwhile
		UI.bait.whenCalm(function()
			return bowls.cats[1] ~= nil or bowls.cats[2] ~= nil
		end, function()
			UI.bait.wow(rarity, first, catId)
		end)
		return
	end
	local id = catId
	if id == nil then
		for _, cat in bowls.cats do
			local catAt: Types.BaitCat? = cat
			if catAt then
				local def = lookupCat(catAt.catId)
				if def and def.rarity == rarity then
					id = catAt.catId
				end
			end
		end
	end
	UI.bigPull.wow(rarity, first, id)
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

-- #3195 (Derek2: a "!" over the Night Market so nobody misses it): the red "!" and "🌙 Rare foods tonight!" over the
-- dealer's cart (Components/MarketBang on the DealerCart tag) from nightfall until this player opens the market that
-- night; then it stays gone until the next night. Only this player sees theirs.
UI.dealer.bang = nil :: any
UI.dealer.night = false
UI.dealer.opened = false
UI.dealer.BANG_LINE = "🌙 Rare foods tonight!"

function UI.dealer.bangLine(): string?
	return if UI.dealer.night and not UI.dealer.opened then UI.dealer.BANG_LINE else nil
end

function UI.dealer.startBang(into: Instance)
	UI.dealer.stopBang()
	local MarketBang = require(script.Components.MarketBang)
	local bang = MarketBang.new(into, {
		tag = "DealerCart",
		name = "CatCafeNightMarketBang",
		line = function(): string?
			return UI.dealer.bangLine()
		end,
	})
	bang:update(nil)
	UI.dealer.bang = bang
end

function UI.dealer.stopBang()
	local bang = UI.dealer.bang
	if bang then
		bang:destroy()
	end
	UI.dealer.bang = nil
end

-- The clock's phase: a new night brings the "!" back, daylight resets it for the next night.
function UI.dealer.setNight(night: boolean)
	if night ~= UI.dealer.night then
		UI.dealer.night = night
		UI.dealer.opened = false
	end
	local bang = UI.dealer.bang
	if bang then
		bang:update(nil)
	end
end

function UI.dealer.seen()
	UI.dealer.opened = true
	local bang = UI.dealer.bang
	if bang then
		bang:update(nil)
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

-- #2402: from CrateAllResult(crateId, opened): one summary card for every piece an Open all gave, by rarity. Empty
-- when refused: the Open all button frees up and the server's toast says why.
function UI.market.allResult(crateId: string, opened: { any })
	if marketScreen then
		marketScreen:allResult(crateId, opened)
	end
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
-- #2614: `tier` is the wrap's ("Common", "Rare", "Super"), for the card's heading; `fish` a Super crate's golden fish.
-- Coins are seconds of income, priced at the cafe's rate, and a "highest" crate shows the crate of the top open area.
function UI.potions.giftResult(
	kind: string,
	id: string?,
	count: number,
	tier: string?,
	fish: number?
)
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
	if type(fish) == "number" and fish > 0 then
		title ..= (" + %d golden fish"):format(fish)
	end
	local GiftLogic = require(script.Components.GiftLogic)
	popups:showGift(title, PotionLogic.giftPrize(kind, id, count, fish), GiftLogic.title(tier), {
		tier = state.tier,
		dayRate = state.prizeRate or state.incomePerSecond,
	})
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
-- The Cat Arcade (#3062, Screens/Arcade; the rules are shared/Arcade)
----------------------------------------------------------------------------------------------------

UI.arcade = {}

-- Opens the arcade's card (the cabinet's prompt, the Menu list's Arcade row). A window already up stays open.
-- #3296: with the `mouseDash` switch on the arcade's game is Mouse Dash, so its card opens instead.
function UI.arcade.open()
	local dash: any = (UI :: any).mouseDash -- filled later in the file
	if dash.isMain() then
		dash.open()
		return
	end
	if modal and arcadeScreen and (modal:current() == nil or modal:current() == "Arcade") then
		modal:open("Arcade")
	end
end

-- The golden fish on the card's Play line.
function UI.arcade.render(newState: Types.PlayerState)
	if arcadeScreen then
		arcadeScreen:setFish(newState.goldenFish or 0)
	end
end

-- ArcadeState: the records and today's paid prizes.
function UI.arcade.state(view: any)
	if arcadeScreen and type(view) == "table" then
		arcadeScreen:setState(view)
	end
end

-- The `arcade` live switch: off greys Play (a game running finishes). `row` was the Settings list's Arcade row,
-- gone since 2026-11-13 (Derek: "remove the old cat arcade icon from settings"); callers may still pass it.
function UI.arcade.setOn(on: boolean, _row: boolean?)
	if arcadeScreen then
		arcadeScreen:setOn(on)
	end
end

-- ArcadeBlock, ArcadeJudged and ArcadeOver, straight to the window.
function UI.arcade.block(run: number, block: number, circles: any, windows: any, points: number)
	if arcadeScreen then
		arcadeScreen:block(run, block, circles, windows, points)
	end
end

function UI.arcade.judged(
	run: number,
	block: number,
	index: number,
	grade: any,
	points: number,
	milestones: any
)
	if arcadeScreen then
		arcadeScreen:judged(run, block, index, grade, points, milestones)
	end
end

function UI.arcade.over(run: number, result: any)
	if arcadeScreen then
		arcadeScreen:over(run, result)
	end
end

-- Whether a game is running on the board (the net and other taps stay out of its way).
function UI.arcade.playing(): boolean
	local dash: any = (UI :: any).mouseDash -- filled later in the file
	return (arcadeScreen ~= nil and (arcadeScreen :: Arcade.Arcade):playing())
		or dash.playing() == true
end

----------------------------------------------------------------------------------------------------
-- Codes and the Codes Cat (F65, data-model section 11d)
----------------------------------------------------------------------------------------------------

UI.codes = {}

-- Opens the Store on Featured, its Codes tab one tap away (#1633): call it when this character walks into the Codes
-- Cat's circle (within CodesCircleRadius, flat). No key press and no prompt. A window the player has open (the Market
-- stall is near) stays open instead (review N182).
function UI.codes.open()
	-- the code box lives in the Store's Codes tab (#1428); the circle opens the Store on Featured (#1633)
	local store: any = UI.store -- defined further down
	if store.openAtBench() then
		return
	end
	if modal and modal:current() == nil then
		modal:open("Codes")
	end
end

-- Closes the Store the circle opened (on any tab; the code box clears with it): call it once the character is past
-- CodesCircleRadius + 1. A window the player opened meanwhile stays open.
function UI.codes.close()
	local store: any = UI.store
	if modal and (modal:current() == "Codes" or store.benchShowing()) then
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
-- #3066: `focus` is the feedback stand's: "none" (its floor ring) opens without the cursor in the box, "box" (a press
-- of its prompt) with it, a phone's keyboard included. Without it a PC's cursor goes in the box and a phone waits
-- for a tap, as ever.
function UI.bugReport.open(kind: string?, focus: ("none" | "box")?)
	if modal then
		if bugReportScreen and kind then
			bugReportScreen:setKind(kind)
		elseif bugReportScreen then
			bugReportScreen:showFaces()
		end
		if bugReportScreen and focus ~= nil then
			if modal:current() == "BugReport" then
				if focus == "box" then
					bugReportScreen:focusBox() -- already up: only the cursor moves
				end
			else
				bugReportScreen:focusNext(focus)
			end
		end
		modal:open("BugReport")
	end
end

-- #3066: the cursor into the Feedback window's box now, when its report page is up (the stand's ring, once a
-- keyboard player stands still).
function UI.bugReport.focus()
	if bugReportScreen then
		bugReportScreen:focusBox()
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

-- Your own plot model: a gold marker over the nearest of its waiting money bags (the plot's RichBags records, #3360),
-- with Collect firing events.claimRichTip(bagId) within 12 studs; walking into a bag fires it too. When a bag's
-- record reads "claimed", "+$X" rises from where it sat, so the server needs no Notify for it; a missed one only
-- toasts "Rich tip missed".
-- F63: the same plot's CollectorSpot, where the Cat Collector's tag and card follow UI.collector.offer.
-- Call it again when the player gets a new plot; nil stops watching.
-- #2395: the intro's staged rich tip: the same gold bubble over `position` with `amount`, Collect inert; nil hides it.
function UI.richTip.preview(position: Vector3?, amount: number?)
	if richTipScreen then
		richTipScreen:preview(position, amount)
	end
end

function UI.richTip.bind(plot: Instance?)
	if richTipScreen then
		richTipScreen:bind(plot)
	end
	UI.cozy.plot = plot -- #2798: the same plot's Cozy attributes, read each second (UI.cozy.refresh)
	UI.cozy.refresh()
	-- F91: the same plot's LawnPath says the Lawn chip is live
	if decor then
		decor:bindPlot(plot)
	end
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
	UI.carryMarker.hand = resolved
	UI.carryMarker.apply()
end

-- #3145: what the screen holds for a carried cat (shared/CarrySync.View), so UIController can set it again when it
-- has drifted from the server's: the HUD and marker exist, the cat this state names, and whether the banner is up.
function UI.carryView(): { built: boolean, catId: string?, banner: boolean }
	local hudScreen = hud
	return {
		built = hudScreen ~= nil and carryMarker ~= nil,
		catId = (state :: any).carrying,
		banner = hudScreen ~= nil and hudScreen:carryShown(),
	}
end

-- #2864 (Derek2: a Backpack cat alone showed no way home): the carry marker follows a cat in the hands first, else one
-- packed in the Backpack (UI.setBagCarry), which leaves state.carrying and the HUD's carry banner alone, so the "Drop
-- bag cat" pill stays.
UI.carryMarker = { hand = nil :: Types.CarryInfo?, bag = nil :: Types.CarryInfo? }

function UI.carryMarker.apply()
	local marker = carryMarker
	if not marker then
		return
	end
	local shown: Types.CarryInfo? = UI.carryMarker.hand or UI.carryMarker.bag
	if shown and shown.camp then
		marker:show(shown.camp :: BasePart, "Bring it here", Theme.rarityColor(shown.rarity))
	elseif shown and shown.door then
		marker:show(shown.door :: BasePart, "Check in here", Theme.rarityColor(shown.rarity))
	else
		marker:hide()
	end
end

-- #2864: the Backpack's cat while the hands are empty ({ catId, door, camp }), or nil once the bag is empty or a cat
-- in the hands takes over (UIController rechecks every 0.5 s). UI.setCarrying's cat wins while both are set.
function UI.setBagCarry(info: Types.CarryInfo?)
	local resolved: Types.CarryInfo? = nil
	if info then
		local def = if info.catId then lookupCat(info.catId) else nil
		resolved = {
			catId = info.catId,
			catName = info.catName or (if def then def.name else nil),
			rarity = info.rarity or (if def then def.rarity else nil),
			door = info.door,
			camp = info.camp,
		}
	end
	UI.carryMarker.bag = resolved
	UI.carryMarker.apply()
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
	UI._introWait.begun = true
	UI.setVisible(false)
	if popups then
		popups:setHeld(true)
	end
	-- Review-QA's Studio run: the event and day strip ("Lucky Day! Golden Day!", "+50% Luck") stays off the intro
	if hud then
		hud:holdBanner("intro", true)
	end
	if areaTitle then
		areaTitle:clear() -- a day banner already up goes; the day banners wait out the intro (UI.intro.playing)
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
-- #2182: `hold` is the shot's seconds on screen (Intro's caption reading time): the gold read bar under the caption
-- fills over it and Next shows (events.introNext); nil shows neither.
function UI.intro.setShot(index: number, caption: string, _titleCard: string?, hold: number?)
	if introScreen then
		introScreen:setShot(index, caption, nil, hold)
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

-- #2242: the rich visitor shot's grab, a big gold "+$<amount>" over the tip bag at `worldPosition`, rising and gone
-- by 1.6 s. `amount` is the tip at Tier 1 rates (the controller's sum); nothing is paid.
function UI.intro.tipPop(worldPosition: Vector3, amount: number)
	if introScreen then
		introScreen:tipPop(worldPosition, amount)
	end
end

-- The end, after the last shot or on Skip: the bars slide out over 0.45 s and everything hidden comes back.
function UI.intro.finish()
	if introScreen then
		introScreen:finish()
	end
end

-- #3105: the loading screen while the camera is held still: before the first spawn, and before a play's first
-- shot (IntroController's park and unpark). A play starting slides it away.
-- #3179 (Derek2 11-10: "remove the loading screen honestly I think that would make people leave faster then
-- before"): it shows only with the `loadingScreen` live switch on (off unless set to true), so by default the wait
-- is the still picture alone and the intro starts the moment the save is in (race() is 0 with no screen up).
function UI.intro.waiting(on: boolean)
	if on then
		local LiveFlags =
			require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags")) :: any
		local key = "loadingScreen"
		if
			not LiveFlags.shown(
				key,
				ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. key)
			)
		then
			return
		end
	end
	if introScreen then
		introScreen:waiting(on)
	end
end

-- #3109: the load is over: the loading screen's count runs to 100. Returns the seconds that takes (0 with no
-- loading screen up); IntroController starts the intro then, which slides the screen away.
function UI.intro.race(): number
	local screen = introScreen
	return if screen ~= nil then screen:race() else 0
end

function UI.intro.playing(): boolean
	local screen = introScreen
	return screen ~= nil and screen:playing()
end

-- #2469: the tackling lesson's Tackle bar over the caption, its key cap `key` ("" on touch), pressed `pressIn` seconds
-- on as the staged lunge starts; nil clears it (Screens/Intro.tackleCue)
function UI.intro.tackleCue(key: string?, pressIn: number?)
	if introScreen then
		introScreen:tackleCue(key, pressIn)
	end
end

-- #2312: IntroController's stageTackle(shot), which takes the camera for the tackling lesson: 1 to 4 stage that
-- shot, 0 ends it and gives the camera, controls and prompts back. The controller hands it over at start; the lesson
-- (Screens/TackleLesson) calls it through `stage`.
UI.intro.tackleStager = nil :: ((shot: number) -> ())?
function UI.intro.setTackleStager(stager: ((shot: number) -> ())?)
	UI.intro.tackleStager = stager
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
-- #2477: the tutorialStep in the last update that carried one, and whether the walk-through ended this session (the
-- bait bowl step), so the cannon hint points at the cannon until the next flight. On UI.cannon, as init's main chunk
-- is at Luau's 200 locals.
UI.cannon.wrapUp = { step = nil :: number?, on = false }
-- #2915: "Fly to the Park" on the rank-up card (flyToPark). `ring` is the area whose picker card is ringed, `travel`
-- that the trip to the cannon is under way (UI.travel.result opens the picker when it lands), `token` the newest press.
UI.cannon.fly = { ring = nil :: string?, travel = false, token = 0 }
-- The wild area the character is in (setWild), and the cannon the character stands by (CannonController sets it).
UI.cannon.area = nil :: string?

-- #3554: the walk to a first Park catch (Controllers/ParkTrailController, Components/ParkTrailLogic). The tutorial's
-- trail is the one trail: a tutorial target has it as gold dots; with none, the Park target has it as paw prints
-- (the folder's Paws attribute, Effects/PawTrail). `set` also gives the goal card its line (nil: the tier goal).
UI.parkTrail = {
	target = nil :: BasePart?,
	goal = nil :: string?,
	tutorial = false, -- a tutorial target has the trail
	reached = false, -- #3893: the player has reached the Park (been in it, or owns a Park cat)
	STRIP = "Visit the Park: follow the paws to a cannon 🐾", -- #3893: the strip's line while the walk is on
}

-- #3893: ParkTrailController says when the first steps are done, up to the Park; the tutorial X's hold on the
-- strip lets go then
function UI.parkTrail.reach(reached: boolean)
	if UI.parkTrail.reached == reached then
		return
	end
	UI.parkTrail.reached = reached
	applyTutorial()
end

function UI.parkTrail.apply(tutorialTarget: any)
	local trail = tutorialTrail
	if trail == nil then
		return
	end
	local park: BasePart? = UI.parkTrail.target
	if park ~= nil and park.Parent == nil then
		park = nil -- the stray was caught or went away; the controller picks the next one
	end
	trail:mark("Paws", tutorialTarget == nil and park ~= nil)
	local to = if tutorialTarget ~= nil then tutorialTarget else park
	if to ~= nil then
		trail:show(to)
	else
		trail:hide()
	end
end

function UI.parkTrail.set(target: BasePart?, goal: string?)
	local changed = UI.parkTrail.target ~= target
	UI.parkTrail.target = target
	if UI.parkTrail.goal ~= goal and hud ~= nil then
		UI.parkTrail.goal = goal
		hud:setParkGoal(goal)
		applyTutorial() -- #3893: the strip's Park line comes and goes with the walk
	end
	if changed and not UI.parkTrail.tutorial then
		UI.parkTrail.apply(nil)
	end
end
UI.cannon.nearest = nil :: (() -> string?)?

-- #3555: the first rank up's walk-through (Components/SpotlightGuide on the goal card, then on the rank up window's
-- button). `set` shows a phase and returns whether its button was there to light; `onOutside` runs on a press on the
-- dim. `moment` is set where the tips' own free-moment rule lives.
UI.rankSpot = {
	close = nil :: (() -> ())?,
	moment = nil :: any,
}

-- #3683: the HUD day clock's box on screen in viewport px (left, right, bottom), nil while it is not showing. For
-- the Rummage Bin's board, which comes down from under it (BinController).
function UI.clockBox(): (number?, number?, number?)
	local frame: GuiObject? = if hud ~= nil then hud:clockFrame() else nil
	if frame == nil then
		return nil, nil, nil
	end
	local inset = if hud ~= nil and hud.screenGui.IgnoreGuiInset
		then 0
		else game:GetService("GuiService"):GetGuiInset().Y
	local at, size = frame.AbsolutePosition, frame.AbsoluteSize
	return at.X, at.X + size.X, at.Y + size.Y + inset
end

function UI.rankSpot.set(phase: string, words: string?, onOutside: (() -> ())?): boolean
	local close = UI.rankSpot.close
	if close ~= nil then
		UI.rankSpot.close = nil
		close()
	end
	local target: GuiObject? = nil
	if phase == "button" and hud ~= nil then
		target = hud:goalButton()
	elseif phase == "confirm" and rankUpScreen ~= nil then
		target = rankUpScreen:button()
	end
	if target == nil then
		return false
	end
	-- the goal card's lines start at its edge: its ring goes round it, not over the first letters
	UI.rankSpot.close = SpotlightGuide.show(target, words or "", onOutside, phase == "button")
	return true
end

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
	UI.cannon.area = areaId
	if cannonWild == (areaId ~= nil) then
		return
	end
	cannonWild = areaId ~= nil
	applyTutorial()
end

-- #2915: "Fly to the Park" pressed on the rank-up card. The window closes and the picker opens with the Park ringed:
-- at once by a cannon, else after the Cannon button's trip to the nearest one. The ring waits PICKER_RING_SECONDS for
-- a picker opened later; any flight ends it and puts the rank-up button back.
function UI.cannon.flyToPark()
	local parkFirst = require(script.Components.ParkFirstLogic)
	local fly = UI.cannon.fly
	fly.token += 1
	local token = fly.token
	fly.ring = parkFirst.AREA
	if cannonScreen then
		cannonScreen:setRing(parkFirst.AREA)
	end
	task.delay(parkFirst.PICKER_RING_SECONDS, function()
		if fly.token == token and fly.ring ~= nil then
			fly.ring, fly.travel = nil, false
			if cannonScreen then
				cannonScreen:setRing(nil)
			end
		end
	end)
	if modal then
		modal:close()
	end
	local nearest = UI.cannon.nearest
	local near = if nearest ~= nil then nearest() else nil
	if near ~= nil then
		UI.cannon.open(near)
	elseif hud then
		fly.travel = hud:pressTravel("cannon")
	end
end

-- Ends "Fly to the Park": the rank-up button is Rank up again and the picker's ring goes.
function UI.cannon.clearFly()
	local fly = UI.cannon.fly
	fly.token += 1
	fly.ring, fly.travel = nil, false
	if cannonScreen then
		cannonScreen:setRing(nil)
	end
	if rankUpScreen then
		rankUpScreen:setFly(nil)
	end
end

-- After the trip flyToPark asked for: the picker of the cannon the character now stands by. The move reaches this
-- client a moment after TravelResult, so it looks twice.
function UI.cannon.openAfterTravel()
	local fly = UI.cannon.fly
	if not fly.travel then
		return
	end
	fly.travel = false
	local token = fly.token
	local function look(again: boolean)
		if fly.token ~= token or fly.ring == nil then
			return
		end
		local nearest = UI.cannon.nearest
		local near = if nearest ~= nil then nearest() else nil
		if near ~= nil then
			UI.cannon.open(near)
		elseif again then
			task.delay(1, look, false)
		end
	end
	task.delay(0.4, look, true)
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
		UI.cannon.wrapUp.on = false
		applyTutorial()
		UI.cannon.clearFly() -- #2915: a flight ends "Fly to the Park" and its ring
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
-- #3080 cut it with the other green pop-ups; #3106 (Derek2 11-10: "maybe add those two buttons back") brings it back
-- for a new player's first delivery only: once a session, while the first walk-through is not done. After that the
-- basket and the camp chime say it.
function UI.cannon.checkedIn(catName: string?)
	local cannon: any = UI.cannon
	if
		cannon._deliverySaid
		or (state.tutorialStep or math.huge) >= CannonLogic.WALKTHROUGH_STEP
	then
		return
	end
	cannon._deliverySaid = true
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
	if destination == "cannon" then
		if ok then
			UI.cannon.openAfterTravel() -- #2915
		else
			UI.cannon.fly.travel = false
		end
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
		-- #3035: a night pass holder is told they can stay
		NightClock.duskLine(
			Players.LocalPlayer ~= nil and Players.LocalPlayer:GetAttribute("NightPass")
		),
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
-- nil or "Cafe" on the safe street and in the cafes, else the area ("Alley"). It times the dusk warning, sets the net
-- button and hides the My Cafe marker away from the cafe area (#1620).
-- The "Safe zone" chip went on 2026-10-28 (Derek: "no need for 'safe zone' or danger zone bubble its just clutter")
-- and the "Safe zone: no tackling here" toast on 2026-11-02 (Derek 2026-10-28: "no need for the safe area reached
-- banner either").
function UI.setZone(zone: string?)
	currentZone = zone
	showDusk() -- walking into an area during the dusk warning
	if netButton then
		netButton:setInArea(not Wayfinding.isSafe(zone))
	end
	if locationMarkers then
		locationMarkers:setZone(zone) -- #1620: the My Cafe marker only in the cafe area
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
-- #2315: PromptShown said the active cat prompt is pressed by touch (a field: bindProximityPrompts's scope is at
-- Luau's 200 local limit)
UI.catch.promptTouch = false
-- #3464 (Derek 2026-11-12: "show the loot obtained from rummage also"): the Rummage Bin's loot card
-- (Screens/LootCard). It lists the server's items; since #3885 it shows as the prize lands in the hands.
local LOOT_AFTER_POP_SECONDS = 0.9 -- #3885: as the prize's picture lands in the hands (Presets.binRoll.prize)
UI.loot = { card = nil :: any, token = 0 }
function UI.loot.show(win: unknown, after: number?, hint: string?)
	UI.loot.token += 1
	local token = UI.loot.token
	local function show()
		if UI.loot.token == token and UI.loot.card ~= nil then
			UI.loot.card:show(win, hint)
		end
	end
	if after ~= nil and after > 0 then
		task.delay(after, show)
	else
		show()
	end
end

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
			touch = info.touch,
			shiny = info.shiny,
			rainbow = info.rainbow,
			fleeingUntil = info.fleeingUntil,
			retryAt = info.retryAt or retryAtFor(info.strayId, info.fleeingUntil),
			ownerTurnUntil = info.ownerTurnUntil,
			newKind = info.newKind, -- #3529
		}
		if catch then
			catch:show(activeInfo :: Types.CatchInfo)
		end
	end

	-- retry = true keeps the prompt open (Commons, lured strays, a rescue turned down for now). Otherwise it
	-- flashes and hides (the cat fled).
	function UI.catch.fail(reason: string?, retry: boolean?)
		if catch and catch.screenGui.Enabled then
			catch:fail(reason, retry)
		elseif type(reason) == "string" and reason ~= "" then
			-- #2341/#2351: a net swing at a stuck cat starts its rescue with no card up, so a refusal says why here
			UI.toast(reason, "warn")
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
	-- Catch v3 (#1884): UIController's hooks with CatchSchedule's trust (UI.catch.trust) and CatchResult's finish
	-- (UI.catch.finished), kept by stray in UI.catch.v3 (no locals left here) until the circles or the grades use them
	UI.catch.v3 = {
		trust = {} :: { [string]: { start: number, need: number } },
		finish = {} :: { [string]: CatchCircles.Finish },
	}
	function UI.catch.strayModel(strayId: string): Model?
		for _, instance in CollectionService:GetTagged("Stray") do
			if instance:GetAttribute("StrayId") == strayId and instance:IsA("Model") then
				return instance :: Model
			end
		end
		return nil
	end
	-- CatchSchedule's trustStart and trustNeed, before or after the circles show: the rings go round the stray's head,
	-- with the trust bar over it, and a Miss only costs trust (Screens/CatchCircles)
	function UI.catch.trust(strayId: string, trustStart: number?, trustNeed: number?)
		if type(trustNeed) ~= "number" or trustNeed <= 0 then
			return
		end
		local start = if type(trustStart) == "number" then trustStart else 0
		local screen = circles
		table.clear(UI.catch.v3.trust)
		if screen and screen:isActive() and screen:strayId() == strayId then
			screen:setTrust(start, trustNeed, UI.catch.strayModel(strayId))
		else
			UI.catch.v3.trust[strayId] = { start = start, need = trustNeed }
		end
	end
	-- CatchResult's finish ({ trust, trustNeed, finish, streak }), just before its grades: the banner word, the bar's
	-- last trust and the HUD's "Purrfect x3" (from the second in a row)
	function UI.catch.finished(strayId: string, finish: unknown)
		if type(finish) ~= "table" then
			return
		end
		local ending: CatchCircles.Finish = finish :: any
		table.clear(UI.catch.v3.finish)
		UI.catch.v3.finish[strayId] = ending
		if hud then
			hud:setCatchStreak(if type(ending.streak) == "number" then ending.streak else 0)
		end
	end

	-- trustStart and trustNeed may come here too (the UI gate's scenes); else from UI.catch.trust
	function UI.catch.showCircles(
		strayId: string,
		circleList: { Types.CatchCircle },
		windows: Types.CatchWindows,
		trustStart: number?,
		trustNeed: number?
	)
		local screen = circles
		if not screen then
			return
		end
		local info = activeInfo
		local header: CatchCircles.Header? = nil
		local early = UI.catch.v3.trust[strayId]
		UI.catch.v3.trust[strayId] = nil
		if early ~= nil and trustNeed == nil then
			trustStart = early.start
			trustNeed = early.need
		end
		local v3 = type(trustNeed) == "number" and trustNeed > 0
		local model: Model? = if v3 then UI.catch.strayModel(strayId) else nil
		if info == nil or info.strayId ~= strayId then
			-- #3224 (Derek2 11-11: the card "just shows cat on top instead of what it is"): a catch that began with the
			-- net swing has no prompt card up for this stray, and the card read "Cat" and "Common". The stray says what
			-- it is itself (CatService's attributes on its model).
			local stray = model or UI.catch.strayModel(strayId)
			local named =
				require(script.Components.CatchHeader).fromStray(strayId, stray, lookupCat)
			if named ~= nil then
				info = named :: any
			end
		end
		if info and info.strayId == strayId then
			local rarity: string? = info.rarity
			local built: CatchCircles.Header = {
				catName = info.catName,
				rarity = rarity,
				stars = info.stars,
				shiny = info.shiny,
				rainbow = info.rainbow,
				title = nil,
				trustStart = if v3 then trustStart else nil,
				trustNeed = if v3 then trustNeed else nil,
				model = model,
			}
			header = built
		elseif v3 then
			local bare: CatchCircles.Header =
				{ trustStart = trustStart, trustNeed = trustNeed, model = model }
			header = bare
		end
		if catch then
			catch:hide() -- activePrompt and activeInfo stay so the card can come back
		end
		if hud then
			hud:setCatching(true)
		end
		screen:show(circleList, windows, header, function(index: number, grade: Types.CircleGrade?)
			UI.events.catchPressed:Fire(strayId, index, grade)
		end, strayId)
	end

	-- #1727: CatchJudged, the server's grade for one of this player's presses, as it is judged
	function UI.catch.judged(
		strayId: string,
		index: number,
		grade: Types.CircleGrade,
		trust: number?
	)
		if circles then
			circles:judged(strayId, index, grade, if type(trust) == "number" then trust else nil)
		end
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
		-- #3078 (Derek2 11-10: "the ui after catch still takes a second to pop back up should be instant"): the HUD
		-- comes back the moment the result arrives. It waited for the result word before (0.4 s, and 0.6 s more for
		-- the net wrap on a catch); the word still flashes over it.
		if hud then
			hud:setCatching(false)
		end
		screen:showResult(outcome, function()
			local info = activeInfo
			local card = catch
			if not outcome.success and activePrompt ~= nil and info ~= nil and card ~= nil then
				card:show(info)
			end
		end)
	end

	-- CatchResult. grades run up to and including the first Miss; charmGain is 0 on a miss. retryAt (F57, miss only) is
	-- the server time this player may try the stray again; the card reads "Cooling down Ns" until then (#2324).
	-- Catch v3 (#1884): the finish UI.catch.finished kept for this stray (or given here, as the UI gate does) picks
	-- the banner
	function UI.catch.showGrades(
		strayId: string,
		grades: { Types.CircleGrade },
		success: boolean,
		charmGain: number?,
		retryAt: number?,
		finish: CatchCircles.Finish?
	)
		local ending: CatchCircles.Finish? = UI.catch.v3.finish[strayId]
		UI.catch.v3.finish[strayId] = nil
		if type(finish) == "table" then
			ending = finish
			UI.catch.finished(strayId, finish)
			UI.catch.v3.finish[strayId] = nil
		end
		finishCatch(strayId, {
			grades = grades,
			success = success,
			charmGain = charmGain,
			finish = ending,
		}, retryAt)
		-- #2282: the first catch whose Perfects added Charm says what Charm is for, once an account (the tip card
		-- waits until the catch is over, as every tip does)
		if success and type(charmGain) == "number" and charmGain > 0 and state.tipsSeen ~= nil then
			local tips: any = (UI :: any).tips -- filled later in the file
			tips.show("perfect")
		end
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

	local RummageBin = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RummageBin")) -- #3050
	local rescueTarget: string? = nil -- the trap of the attempt on screen
	local rescueOnCircle = false -- a tree's falling cat is on the catch circles, not the bar

	-- After the attempt: the travel row comes back, and on a fail the prompt card returns while the player is still
	-- at the trap (the server makes them wait RescueSelfRetrySeconds before the next try).
	local function endRescue(success: boolean)
		rescueTarget = nil
		-- Review-QA Studio on #4002: the bar's result ("MISS", "Try again!") clears here, so the pop-ups' 5 s calm
		-- starts now, even when nothing asked UI.rollBusy.held() while the bar was up
		UI.rollBusy.offAt = os.clock()
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
		-- #3050: the Rummage Bin's bar is the same bar with its own name and closing words
		-- #3611: with the prize rolled first (`binRoll`), the bar names what is being rummaged for
		local function binBarName(): string
			local LiveFlags =
				require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags"))
			local waiting =
				RummageBin.rollRow(Players.LocalPlayer:GetAttribute(RummageBin.PRIZE_ATTRIBUTE))
			if
				waiting == nil
				or not LiveFlags.shown(
					RummageBin.ROLL_FLAG,
					ReplicatedStorage:GetAttribute(
						LiveFlags.ATTRIBUTE_PREFIX .. RummageBin.ROLL_FLAG
					)
				)
			then
				return RummageBin.NAME
			end
			-- #3683: the prize alone ("Rummage for: Golden Alley Crate" was cut on the bar); the board over the bin
			-- reads "Rummage for" above the same prize
			return RummageBin.rowTitle(waiting)
		end
		local header: RescueBar.Header = if rescueSpotId == RummageBin.SPOT
			then {
				catName = binBarName(),
				words = {
					slow = "Too slow! Try again",
					gaveUp = "Maybe later",
					won = "Got it!",
					win = "Found something!",
					-- the prize is picked before the bar, so no "So close!" near-miss words (Review-QA, #3885)
					lose = "Try again!",
					loseDetail = "",
				},
			}
			else { catName = catName, rarity = rarity }
		bar:show(challenge, header, {
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
		bar: Types.RescueBar?,
		win: { id: string, first: boolean }? -- #3050: the Rummage Bin's prize, on its winning result
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
			if hud then
				hud:setCatching(false) -- #3078: at once, as a catch's result does; endRescue does the rest after the word
			end
			screen:showResult({ grades = { grade }, success = success }, function()
				endRescue(success)
			end)
			return
		end
		if rescueBar then
			-- #3885 (Derek 2026-11-13: "drop the ui from rummage bin minigame as soon as its completed"): a Rummage Bin
			-- win closes the bar at once, with no win banner over it. The prize's picture pops out of the bin into the
			-- player's hands (BinController, Effects/BinRoll) and the loot card names what it was as it lands.
			if win ~= nil and type(win.id) == "string" and done and success then
				rescueBar:hide()
				endRescue(true)
				-- the banner's line ("Put it in your bowl", "Open it at the Golden Fish Market") goes on the loot card
				local _, hint =
					RummageBin.winWords(win.id, win.first == true, (win :: any).rolled == true)
				UI.loot.show(win, LOOT_AFTER_POP_SECONDS, hint)
				return
			end
			rescueBar:update(hits, pawsLeft, done, success, bar, nil)
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

	local PET_PROMPT = "PetPrompt"
	local function isCatPrompt(prompt: ProximityPrompt): boolean
		-- #3651: a working cat's Pet prompt (shared/Pet's PROMPT) sits in a cat model and is no stray
		return prompt.Style == Enum.ProximityPromptStyle.Custom
			and prompt.Name ~= PET_PROMPT
			and promptAttribute(prompt, "CatId") ~= nil
	end

	-- Every other custom prompt (bait bowl, dealer cart, manhole, Bump) gets an action pill
	local function isActionPrompt(prompt: ProximityPrompt): boolean
		return prompt.Style == Enum.ProximityPromptStyle.Custom
			and (prompt.Name == PET_PROMPT or promptAttribute(prompt, "CatId") == nil)
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
		-- #2614: the chances of the wrap on the table (its MysteryGiftTier), not every wrap's
		local tier = if plot then plot:GetAttribute("MysteryGiftTier") else nil
		return true,
			PotionLogic.giftLine(
				PotionLogic.giftRows(currentCatalog, if type(tier) == "string" then tier else nil),
				foodName
			)
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
			touch = prompt == activePrompt and UI.catch.promptTouch == true,
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
			gamepadKeyCode = prompt.GamepadKeyCode, -- #2874: the cap reads X on a gamepad
			-- #3529: "New kind! 3/5 for Cozy Cafe" when the player has never owned this kind (a net catch or a rescue)
			newKind = if pickUp then nil else (UI.newKind :: any).line(catId, rarity),
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
				if note == nil then
					-- #3050: a prompt's own note (the Rummage Bin's chances, set by WorldBuilder)
					local own = prompt:GetAttribute("Note")
					note = if type(own) == "string" and own ~= "" then own else nil
				end
				if show and actionPills then
					actionPills:show(prompt, inputType, note)
				end
				return
			end
			if not isCatPrompt(prompt) then
				return
			end
			activePrompt = prompt
			UI.catch.promptTouch = inputType == Enum.ProximityPromptInputType.Touch
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
	-- Review-QA on #3854: the day's banners stay off a busy window too (Toasts.setBusy)
	if
		previous == "night"
		and phase == "day"
		and areaTitle
		and not (toasts and toasts:isBusy())
		and not UI.intro.playing()
	then
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
						-- #1737 (Derek2 11-06): the Night Market's own cart picture, as on its map marker, not the moon
						-- (required here: this file is at Luau's 200-local limit)
						local picture: string? =
							require(script.Components.ShopIcons).hud("NightMarket")
						banner:banner(
							"night_market",
							if picture
								then "The Night Market is open!"
								else Theme.icons.moon .. " The Night Market is open!",
							"Rare foods tonight at the dealer's cart in town.",
							Theme.colors.berry,
							6,
							picture
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
	UI.dealer.setNight(phase == "night") -- #3195
	if tipJarScreen then
		tipJarScreen:setNight(phase == "night")
	end
	UI.pass.setNight(phase == "night")
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
	-- #1572 (required here: the main chunk is at Luau's 200 locals)
	local DayKinds = require(script.Components.DayKinds)
	local LuckLogic = require(script.Components.LuckLogic)
	DayKinds.bound = false -- the clock's first read is a join, not a sunrise, so it shows no day banner
	local function read()
		local phase = clock:GetAttribute("Phase")
		local endsAt = clock:GetAttribute("PhaseEndsAt")
		if (phase == "day" or phase == "night") and type(endsAt) == "number" then
			UI.clock.set(phase :: Types.ClockPhase, endsAt)
		else
			UI.clock.clear()
		end
		UI.clock.setAreasOpen(NightClock.areasOpen(clock:GetAttribute("AreasOpen")))
		-- F88, #1572: today's kinds under the clock (Lucky, Golden, Rainbow), and the odds cards' gold and rainbow lines
		local day = clock:GetAttribute("Day")
		local kinds: DayKinds.Kinds = {
			lucky = clock:GetAttribute("LuckyDay") == true,
			golden = clock:GetAttribute("GoldenDay") == true,
			rainbow = clock:GetAttribute("RainbowDay") == true,
		}
		local before = DayKinds.current
		local began = (kinds.lucky and not before.lucky)
			or (kinds.golden and not before.golden)
			or (kinds.rainbow and not before.rainbow)
		if DayKinds.set(kinds) then
			render() -- the bowl and dealer odds show the day's gold and rainbow chances
		end
		local view: LuckLogic.DayView = {
			day = if type(day) == "number" then day else nil,
			luckyDay = kinds.lucky,
			goldenDay = kinds.golden,
			rainbowDay = kinds.rainbow,
			phase = if type(phase) == "string" then phase else nil,
		}
		if hud then
			hud:setLuckyDay(view)
		end
		-- the sunrise banner names every kind of the day at once ("Lucky Day! Golden Day!"), after the sunrise's own
		-- (not on a join: a day already running only shows on the line)
		if began and DayKinds.bound then
			local title, line = LuckLogic.dayBanner(view)
			if title then
				task.delay(SUNRISE_HOLD + 0.4, function()
					if
						areaTitle
						and not (toasts and toasts:isBusy())
						and not UI.intro.playing()
					then
						areaTitle:banner("lucky_day", title, line, Theme.colors.gold, 4)
					end
				end)
			end
		end
		DayKinds.bound = true
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
	for _, name in
		{ "Phase", "PhaseEndsAt", "AreasOpen", "Day", "LuckyDay", "GoldenDay", "RainbowDay" }
	do
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
-- #1572: a warning with `coming` (tomorrow's Clock.dayKinds) names every kind it brings (LuckLogic.warnBanner).
function UI.luckyDay(
	kind: string,
	line: string,
	coming: { lucky: boolean?, golden: boolean?, rainbow: boolean? }?
)
	if type(line) ~= "string" then
		return
	end
	if kind == "warning" then
		local title: string?, said: string? = "Lucky Day soon!", line
		if type(coming) == "table" then
			title, said = (require(script.Components.LuckLogic) :: any).warnBanner(coming)
		end
		if
			areaTitle
			and title ~= nil
			and not (toasts and toasts:isBusy())
			and not UI.intro.playing()
		then
			areaTitle:banner("lucky_warning", title, said or line, Theme.colors.gold, 4)
		end
		return
	end
	-- "start": #1572 the clock read banners every kind of the day at once (LuckLogic.dayBanner), so nothing here
end

-- #1893 (first-hour.md 1b): UIController's hook for RoadmapStep(n), the server's word that milestone n was done and
-- paid. The strip's dot pops gold, a small toast slides in ("Grand Opening 4/8: Tier 2! +10 golden fish") with a
-- short confetti puff off the strip (Effects/StoreBurst), and step 8 plays the Grand Opening banner once. The strip
-- itself follows the next ProfileSync.
UI.roadmap = {}
function UI.roadmap.step(n: number)
	if type(n) ~= "number" then
		return
	end
	local RoadmapLogic = require(script.Components.RoadmapLogic)
	if hud then
		hud:roadmapStep(n)
		local strip = hud.screenGui:FindFirstChild("GrandOpening", true)
		if strip and strip:IsA("GuiObject") and strip.Visible then
			local Burst = require(script.Parent.Effects.StoreBurst) :: any
			Burst.play(strip, if n >= #RoadmapLogic.STEPS then "bundle" else "pass")
		end
	end
	if toasts then
		toasts:show(RoadmapLogic.toast(n), "good")
	end
	if n >= #RoadmapLogic.STEPS and areaTitle then
		areaTitle:banner(
			"grand_opening",
			RoadmapLogic.BANNER,
			RoadmapLogic.BANNER_LINE,
			Theme.colors.gold,
			5
		)
	end
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
	local TackleLessonLogic = require(script.Components.TackleLessonLogic) -- #2198
	local TackleTry = require(script.Components.TackleTry) -- #2302

	local cutSeconds: number = math.min(3, (Config :: any).TipCutMaxSeconds or 4)
	-- one table, as the module is short of locals
	local TIP = {
		GAP = ((Config :: any).TipGapSeconds or 60) :: number,
		TUTORIAL_DONE = 5, -- #3156: tutorialStep at the tutorial's end
		start = 0, -- #3156: os.clock() at the tips' start
		joinedNew = nil :: boolean?,
		held = function(): boolean
			return false
		end,
		CUT_SECONDS = cutSeconds,
		CUT_TIMEOUT = cutSeconds + 3, -- a cut whose done never comes frees the queue after this
		STUCK_RANGE = 30, -- studs from a stuck cat (section 3: "within 30 studs")
		CODES_RANGE = 20,
		CODES_TAG = "CodesCat", -- shared/Codes.TAG, the Codes Cat's station
		PUMP_EVERY = 0.25,
		LOOK_EVERY = 1,
		-- #2198: the server's `tackle` tip came and plays as the tackling lesson (Screens/TackleLesson) at the next free
		-- moment, not as a card
		lessonDue = false,
		-- #2626: another player's tackle landed on this player this session; the lesson plays once they are safe again
		tackled = false,
		-- #2775: a one-off card ahead of the queue (UI.tips.nudge); line() is asked again as it shows
		nudge = nil :: { line: () -> string?, icon: string }?,
	}
	Moments.Shove:Connect(function(role: string)
		if role == "target" then
			TIP.tackled = true
		end
	end)

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

	-- #3156: whether tip cards wait (TipQueue.held): a tutorial step on screen, or a new player's first minutes
	-- (in TIP, as the module is short of locals: TIP.start, and TIP.joinedNew whether this session began before the
	-- tutorial's end, from the first state)
	TIP.start = os.clock()
	TIP.held = function(): boolean
		if TIP.joinedNew == nil and state.tutorialStep ~= nil then
			TIP.joinedNew = state.tutorialStep < TIP.TUTORIAL_DONE
		end
		return TipQueue.held({
			guiding = tutorialText ~= nil or hintShown ~= nil,
			newPlayer = TIP.joinedNew == true,
			played = os.clock() - TIP.start,
		})
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
				or UI.cutscene.on -- #4018: tips, ask and first visit cards wait through a cutscene
				or (popups ~= nil and popups:isShowing())
				or (baitCard ~= nil and baitCard:isShowing())
				or (askCard ~= nil and askCard:isShowing()),
			hidden = not visible,
			duskLeft = duskLeft,
			toastAgo = if toasts ~= nil and toasts:lastShown() ~= nil
				then os.clock() - (toasts:lastShown() :: number)
				else nil,
		}
	end

	-- Shows the next waiting tip when the moment is free and the gap has run.
	local function pumpTips()
		-- #2198 (Derek2: "a forced cut scene after first catch ... people will turn tips off with the X pretty fast"):
		-- the tackling lesson waits only for a free moment, not for the gap or the Tutorial tile's ×; it is saved as
		-- seen when it ends, so leaving mid-way plays it again next time
		if
			TIP.lessonDue
			and not tipBusy
			and initialized
			and introScreen ~= nil
			-- #3206: and only somewhere safe; out in a catching area it stays due
			and TackleLessonLogic.canStart(
				TipQueue.free(tipMoment()),
				Wayfinding.isSafe(currentZone)
			)
		then
			TIP.lessonDue = false
			tipBusy = true
			tipQueue:shown(os.clock())
			local lessonTip: string = TackleLessonLogic.TIP
			require(script.Screens.TackleLesson).play(
				{
					start = UI.intro.start,
					setShot = UI.intro.setShot,
					finish = UI.intro.finish,
					playing = UI.intro.playing,
					cue = UI.intro.tackleCue,
					stage = function(shot: number)
						local stager = UI.intro.tackleStager
						if stager then
							stager(shot)
						end
					end,
				},
				tipDevice(),
				function()
					tipBusy = false
					answerTip(lessonTip, false)
				end
			)
			return
		end
		local card = tipCard
		local nudge = TIP.nudge
		if
			nudge ~= nil
			and card ~= nil
			and not tipBusy
			and initialized
			and tutorialButtonOn
			and not TIP.held()
			and TipQueue.free(tipMoment())
		then
			TIP.nudge = nil
			local line = nudge.line()
			if line ~= nil then
				tipBusy = true
				tipQueue:shown(os.clock())
				card:show(line, nudge.icon, TipQueue.CARD_SECONDS, function()
					tipBusy = false
				end)
			end
			return
		end
		-- the Tutorial tile's × (its setting off) holds the tip cards back too (Derek 2026-11-03)
		if
			card == nil
			or tipBusy
			or not initialized
			or not tutorialButtonOn
			or tipQueue:size() == 0
			or TIP.held() -- #3156
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
				UI.tips.clearStage(false)
				answerTip(id, skipped == true)
			end
			tipBusy = true
			local ok, played = pcall(play, id, caption, TIP.CUT_SECONDS, done)
			if ok and played == true then
				if not finished then
					UI.tips.clearStage(true)
				end
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
		if id == TackleTry.TIP and tackleBar ~= nil then
			tackleBar:pulse() -- #2302: the bar the card talks about
		end
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

	-- Derek 2026-11-13: the account's first pet of its own cat says what petting does, once (the card waits for a
	-- free moment like every tip)
	Moments.CatPetted:Connect(function(userId: number)
		if
			userId == Players.LocalPlayer.UserId
			and state.tipsSeen ~= nil
			and not tipKnown("pet")
		then
			local tips: any = (UI :: any).tips -- show is filled in further down this block
			tips.show("pet")
		end
	end)

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
		-- #2626: the tackling lesson, the first time the player is back on the safe street after being tackled
		if
			TackleLessonLogic.contextDue({
				tackled = TIP.tackled,
				safe = Wayfinding.isSafe(currentZone),
				seen = tipKnown(TackleLessonLogic.TIP),
				step = state.tutorialStep,
			})
		then
			TIP.tackled = false
			UI.tips.show(TackleLessonLogic.TIP)
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
		-- #2302: after the tackling lesson, the first time a tackle could land on someone carrying a cat
		local bar = tackleBar
		if
			bar ~= nil
			and TackleTry.due({
				lessonSeen = tipKnown(TackleLessonLogic.TIP), -- #2409: the lesson's own id
				tried = tipKnown(TackleTry.TIP),
				ready = bar:ready(),
				from = from,
				reach = (Config :: any).TackleLungeStuds or 12,
				others = TackleTry.carriers(
					Players:GetPlayers(),
					Players.LocalPlayer,
					Workspace:GetServerTimeNow()
				),
			})
		then
			UI.tips.show(TackleTry.TIP)
		end
	end

	-- #3555: for the first rank up's walk-through (Controllers/RankSpotController). `moment` says whether nothing
	-- else is going on (no catch, rescue, carry, cutscene or flight, the UI showing) and names the open window: the
	-- modal's, or "other" for a popup, the bait card, an ask or the gift, tip or recap card.
	function UI.rankSpot.moment(): (boolean, string?)
		local at = tipMoment()
		local free = not (
			at.catching
			or at.rescuing
			or at.carrying
			or at.intro
			or at.flying
			or at.hidden
			or tipBusy
		)
		local window: string? = if modal ~= nil then modal:current() else nil
		-- (any: UI.gift and UI.recap are filled further down this file, and the CI type check loses the whole UI
		-- table's shape when they are read here by their own types)
		local cards: any = UI
		if
			window == nil
			and (
				(popups ~= nil and popups:isShowing())
				or (baitCard ~= nil and baitCard:isShowing())
				or (askCard ~= nil and askCard:isShowing())
				-- the gift, tip and recap cards too: a press on their Close is not a press on the dim
				or (cards.gift.card ~= nil and cards.gift.card:isShowing())
				or (tipCard ~= nil and tipCard:isShowing())
				or (cards.recap.card ~= nil and cards.recap.card:isShowing())
			)
		then
			window = "other"
		end
		return free, window
	end

	-- Nothing else is going on and no tip is showing: the one feedback ask may slide in.
	function UI.tips.quiet(): boolean
		return not tipBusy and TipQueue.free(tipMoment())
	end

	-- #3701: nothing is over the screen (a catch, a rescue, the intro, a window) and the UI is not hidden: the cafe
	-- rest banner may show. Looser than quiet: a toast or the dusk warning does not hold it.
	function UI.tips.calm(): boolean
		local moment = tipMoment()
		if moment.catching or moment.rescuing or moment.intro then
			return false
		end
		return not (moment.window or moment.hidden)
	end

	ticks.tips = function(dt: number)
		-- #3752: the catch and rescue card stays over the Tackle bar while both show
		local card, bar = catch, tackleBar
		if card ~= nil and card:isVisible() then
			card:setClear(if bar ~= nil then bar:top() else nil)
		end
		-- an ask already up steps aside while a popup (Welcome back, a cat found) shows over the screen
		local ask = askCard
		if ask ~= nil and popups ~= nil then
			ask.screenGui.Enabled = not popups:isShowing()
		end
		if ask ~= nil then
			ask:follow()
		end
		clocks.pump += dt
		clocks.look += dt
		if clocks.look >= TIP.LOOK_EVERY then
			clocks.look = 0
			lookForTips()
			local tips: any = UI.tips -- lookForAsk is set by the ask's block below
			tips.lookForAsk()
		end
		if clocks.pump >= TIP.PUMP_EVERY then
			clocks.pump = 0
			pumpTips()
		end
	end

	-- #2775: one card ahead of the queue at the next free moment, with line() asked as it shows (nil skips it); a
	-- newer nudge replaces one still waiting. The Tutorial tile's × holds it back like the other tips.
	function UI.tips.nudge(line: () -> string?, icon: string)
		TIP.nudge = { line = line, icon = icon }
	end

	-- A tip's moment came: ShowTip from the server, or the client's own finds. Queued and timed; unknown ids, the two
	-- asks the UI times itself (feedback_ask, stuck_help) and tips already seen are left alone.
	function UI.tips.show(id: string)
		if
			type(id) ~= "string"
			or (Tips.get(id) == nil and id ~= Tips.LIKE_ASK and id ~= TackleLessonLogic.TIP)
		then
			return
		end
		if tipKnown(id) or tipQueue:has(id) then
			return
		end
		-- #4005: the extras wait for Tier 2, the tackle try for the quiet start, and the rank up cut goes beside the
		-- walk through. Never marked seen, so the server sends it again later.
		local shared = ReplicatedStorage:WaitForChild("Shared")
		local QuietStart = require(shared:WaitForChild("QuietStart")) :: any
		local LiveFlags = require(shared:WaitForChild("LiveFlags")) :: any
		local on, quiet = QuietStart.live()
		local spotlight = LiveFlags.shown(
			"rankUpSpotlight",
			ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. "rankUpSpotlight")
		)
		local now: any = UI.getState()
		if QuietStart.holdsTip(on, id, if now ~= nil then now.tier else nil, quiet, spotlight) then
			return
		end
		if id == TackleLessonLogic.TIP then
			TIP.lessonDue = true -- #2198: the lesson, not a card
		else
			tipQueue:push(id)
		end
		pumpTips()
	end

	-- F96 (starter-cat.md section 3): the favorite and like asks on the tip card, with a star or a thumb. UIController's
	-- showAsk calls it at a quiet moment and answers TipSeen itself, so this does not fire tipSeen; it shows the card
	-- and says true, or false (a tip or another card is up, or the id is not one of the two) for the toast instead.
	-- The ask counts as this session's tip for the gap. The notification ask is Roblox's prompt, never this.
	-- F92: the invite ask is the slide-in card with an Invite button instead (UI.together.inviteAsk).
	-- #2766: an ask the controllers time themselves (the update Event's Notify Me ask) on the slide-in card, when it is
	-- free; true when it shows. The card answers through the ask's own answer.
	-- #2880: `news` is a card that tells of something happening now (a first visitor at the cafe, #2792), not an ask
	-- for something: it skips the pace and does not hold the next ask back.
	function UI.asks.card(ask: any, news: boolean?): boolean
		local card = askCard
		local pace: any = UI.asks -- #2880: paced and shown are set further down the file
		if card == nil or not initialized or card:isShowing() or not (news or pace.paced()) then
			return false -- #2880: too soon after the last ask, or too early in the session; offered again later
		end
		-- Review-QA (Studio, 667x375): the rich customer's card came up over a Rummage Bin roll and covered Give up;
		-- no ask card while a roll or its reveal plays (UI.rollBusy)
		if UI.rollBusy.held() then
			return false
		end
		card:show(ask)
		if not news then
			pace.shown()
		end
		return true
	end

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

	-- #2408 (Derek2: "because of so many pop ups on cafe tier up its hard to see the cutscene showing next place
	-- unlocked"): while a camera cut plays (the rank up's look at the next area, and the other context cuts) the HUD
	-- steps aside as for the intro, and new toasts and popups wait; they show when the cut ends. A cut only starts at a
	-- free moment (TipQueue.free: the HUD showing, no window), so its end puts the HUD back.
	UI.tips.staged = false
	function UI.tips.clearStage(on: boolean)
		if UI.tips.staged == on then
			return
		end
		UI.tips.staged = on
		if toasts then
			toasts:setHeld(on)
		end
		if popups then
			popups:setHeld(on)
		end
		UI.setVisible(not on)
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
		TIP.nudge = nil
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
-- not nil). #2681: a player never asked gets it once earlier (FeedbackLogic.earlyDue: 4 minutes, or once a cat has
-- served customers); it is saved as asked, but left unanswered the FeedbackAskMinutes one still comes this session.
-- #2880 (Derek2: "too early and too often"): the early ask is at 8 minutes and the only one a session, and every
-- slide-in ask keeps AskPacing's pace (UI.asks.paced: none in the first 8 minutes, 10 minutes between two).
-- Its own block, as the module is short of locals.
do
	local AskPacing = require(script.Components.AskPacing)
	local FeedbackLogic = require(script.Components.FeedbackLogic)
	local Tips = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tips")) :: any
	local sessionStart = os.clock()
	local asked = false -- this session
	-- #2681: the early ask this session (shown, and whether a face came back), and since when a cat has held a role
	local early = {
		shown = false,
		at = 0,
		answered = false,
		workingSince = nil :: number?,
		lastAsk = nil :: number?, -- #2880: the session second the last slide-in ask showed
	}

	-- #2880: true when a slide-in ask may show now (AskPacing), false while it is too soon
	function UI.asks.paced(): boolean
		return AskPacing.allow(os.clock() - sessionStart, early.lastAsk)
	end

	-- #2880: a slide-in ask just showed, so the next one waits AskPacing.GAP_SECONDS
	function UI.asks.shown()
		early.lastAsk = os.clock() - sessionStart
	end

	-- #2880: the pace as if the session had run long enough with no ask yet (QA in Studio and the UI gate)
	function UI.asks.skipPace()
		sessionStart = os.clock() - AskPacing.FIRST_SECONDS
		early.lastAsk = nil
	end

	local function openAsk(card: AskCard.AskCard)
		local first = not early.shown and not asked and state.feedbackAsked == false
		if first then
			early.shown = true
			early.at = os.clock() - sessionStart
		else
			asked = true
		end
		local faces: { AskCard.Choice } = {}
		for _, face in FeedbackLogic.FACES do
			table.insert(faces, { id = face.id, label = face.label, icon = face.glyph })
		end
		card:show({
			title = "How is it so far?",
			choices = faces,
			seconds = FeedbackLogic.ASK_SECONDS,
			thanks = "Thanks!",
			-- #2694: how it ended ("answered", "closed", "ignored", "hidden" or "replaced"); the first three go to
			-- the funnel once each ask, after the answer's SendFeedback
			ended = function(how: string)
				if how == "answered" or how == "closed" or how == "ignored" then
					UI.events.feedbackOutcome:Fire(
						how .. ":" .. (if first then "early" else "late")
					)
				end
			end,
			answer = function(face: string?)
				if face == nil then
					return
				end
				early.answered = true
				(state :: any).feedbackAsked = true
				local reasons = FeedbackLogic.reasons(face)
				if #reasons == 0 then
					UI.events.sendFeedback:Fire(face, nil)
					return
				end
				-- #3657: the same card asks why; the face is sent once, with the chip tapped or alone
				local chips: { AskCard.Choice } = {}
				for _, reason in reasons do
					table.insert(
						chips,
						{ id = reason.id, label = reason.label, icon = reason.glyph }
					)
				end
				table.insert(chips, { id = FeedbackLogic.SKIP, label = "Skip" })
				card:show({
					title = FeedbackLogic.REASON_TITLE,
					choices = chips,
					rows = 2,
					seconds = FeedbackLogic.REASON_SECONDS,
					thanks = "Thanks!",
					answer = function(reason: string?)
						UI.events.sendFeedback:Fire(face, FeedbackLogic.reasonChip(reason))
					end,
				})
			end,
		})
		local saved: any = state
		saved.feedbackAsked = true
		UI.events.tipSeen:Fire(Tips.FEEDBACK_ASK, false)
		UI.asks.shown()
	end

	-- #3272: the once-a-day session ask (shared/SessionFeedback) at a natural stop: as the Roblox menu closes (the card
	-- cannot show over the menu itself) or after a minute with no input, once the session has run 5 minutes. Closed
	-- or left to time out it is sent as "skipped"; hidden by another card, it may come again.
	local GuiService = game:GetService("GuiService")
	local SessionFeedback =
		require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SessionFeedback")) :: any
	local calm = { inputAt = os.clock(), menuClosedAt = -math.huge, sent = false }
	UserInputService.InputBegan:Connect(function()
		calm.inputAt = os.clock()
	end)
	GuiService.MenuClosed:Connect(function()
		calm.menuClosedAt = os.clock()
		calm.inputAt = os.clock()
	end)

	-- one answer a day: a face, or "skipped" when the card was closed or ran out
	local function sendSession(answer: string)
		if calm.sent then
			return
		end
		calm.sent = true
		local saved: any = state
		saved.sessionFeedbackDay = SessionFeedback.day(os.time())
		UI.events.sessionFeedback:Fire(answer)
	end

	local function openSessionAsk(card: AskCard.AskCard)
		local faces: { AskCard.Choice } = {}
		for _, face in FeedbackLogic.FACES do
			table.insert(faces, { id = face.id, label = face.label, icon = face.glyph })
		end
		card:show({
			title = SessionFeedback.TITLE,
			choices = faces,
			seconds = SessionFeedback.ASK_SECONDS,
			thanks = "Thanks!",
			answer = function(face: string?)
				if face ~= nil then
					sendSession(face)
				end
			end,
			ended = function(how: string)
				if how == "closed" or how == "ignored" then
					sendSession("skipped")
				end
			end,
		})
		UI.asks.shown()
	end

	local function lookForSessionAsk(card: AskCard.AskCard): boolean
		if calm.sent or state.sessionFeedbackDay == nil then
			return false
		end
		local now = os.clock()
		local menuClosed = now - calm.menuClosedAt <= 5
		if
			not SessionFeedback.due(
				now - sessionStart,
				now - calm.inputAt,
				state.sessionFeedbackDay,
				os.time(),
				UI.tips.quiet(),
				menuClosed
			) or not UI.asks.paced()
		then
			return false
		end
		calm.menuClosedAt = -math.huge
		openSessionAsk(card)
		return true
	end

	-- From the tips clock, once a second.
	function UI.tips.lookForAsk()
		local card = askCard
		if card == nil or card:isShowing() then
			return
		end
		if lookForSessionAsk(card) then
			return
		end
		if asked then
			return
		end
		local played = os.clock() - sessionStart
		local working = false
		for _, cat in (state.cats or {}) :: { [string]: any } do
			if cat.spotId ~= nil then
				working = true
				break
			end
		end
		if not working then
			early.workingSince = nil
		elseif early.workingSince == nil then
			early.workingSince = os.clock()
		end
		local since = early.workingSince
		local worked = if since ~= nil then os.clock() - since else 0
		local quiet = UI.tips.quiet()
		-- earlyDue holds whenever askDue does, so a player never asked gets this one first; an early ask left
		-- unanswered brings the usual one, once, at FeedbackAskMinutes (it is saved as asked already)
		local firstDue = not early.shown
			and FeedbackLogic.earlyDue(state.feedbackAsked, played, worked, quiet)
		-- #2880: one ask a session, so an unanswered early ask no longer comes back at FeedbackAskMinutes
		if firstDue and UI.asks.paced() then
			openAsk(card)
		end
	end

	-- #3272: the session ask now, whatever the clock says (QA in Studio and the UI gate); its answer is sent as usual.
	-- It takes the card over from any ask already on it (AskCard.show ends that one as "replaced"): on a slow run the
	-- tips clock may have put the F87 faces ask up first.
	function UI.tips.showSessionAsk()
		local card = askCard
		if card ~= nil then
			openSessionAsk(card)
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

	-- #3865: the strip follows a new input only once it has held a moment (TipQueue.settle)
	local settle = TipQueue.newSettle()
	local function inputDevice(): TipQueue.Device
		local now = TipQueue.device(UserInputService:GetLastInputType().Name, Scale.isTouch())
		return TipQueue.settle(settle, now, os.clock())
	end

	local function hintFor(s: any, device: TipQueue.Device): string?
		local catalog = currentCatalog
		-- #3238: step 3 says the strays come back at sunrise while the areas are shut
		local clock = ReplicatedStorage:FindFirstChild("Clock")
		local areasOpen: boolean? = nil
		if clock ~= nil then
			areasOpen = clock:GetAttribute("AreasOpen") :: boolean?
		end
		return TutorialHints.line(
			TutorialHints.view(s, if catalog then catalog.spots else nil, device, areasOpen)
		)
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
-- First visitors (#2792, retention-ideas.md section 2)
----------------------------------------------------------------------------------------------------

-- A new account's first rich customer, Mystery Visitor and Cat Collector: the server names the one at the cafe in the
-- own plot's FirstVisit attribute, and UIController hands each change here with a check of whether the player is away
-- from the cafe. At a free moment (UI.tips.quiet: no catch, rescue, window or other ask) it toasts at the cafe, or away
-- puts the slide-in ask card up with "Go to my cafe" (events.travel "home") and Later (Components/FirstVisitLogic).
-- The card goes when the visit ends. Its own block, as the module is short of locals.
UI.firstVisit = { kind = nil :: string?, token = 0, carded = false }
do
	local FirstVisitLogic = require(script.Components.FirstVisitLogic)

	-- #3620: a window or the "Unlocked!" perk card is up. (any: UI.perks is filled further down this file, and the CI
	-- type check loses the whole UI table's shape when it is read here by its own type)
	local function busy(): boolean
		local cards: any = UI
		local perkCard = cards.perks.card
		-- a roll or its reveal (UI.rollBusy) takes the screen as a window does
		return UI.rollBusy.held()
			or FirstVisitLogic.yields(
				if modal ~= nil then modal:current() else nil,
				perkCard ~= nil and perkCard:isShowing()
			)
	end

	local function present(token: number, away: () -> boolean)
		local visit = UI.firstVisit
		local kind = visit.kind
		if visit.token ~= token or kind == nil then
			return -- the visit ended, or another came, while it waited
		end
		if not initialized or not UI.tips.quiet() or busy() then
			task.delay(1, present, token, away)
			return
		end
		local now: any = UI.getState()
		local wrapHint = UI.cannon.wrapUp.on and cannonHint() == CannonLogic.WRAP_UP_HINT
		local QuietStart =
			require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("QuietStart")) :: any
		if
			QuietStart.holdsFirstVisit((QuietStart.live()), if now ~= nil then now.tier else nil)
		then
			return -- #4005: the first visit calls wait for Tier 2 (Design-Agent, folding #3891's hold in)
		end
		if
			FirstVisitLogic.holds(if now ~= nil then now.tutorialStep else nil, away(), wrapHint)
		then
			task.delay(1, present, token, away) -- not over a tutorial card; it comes once the tutorial is done
			return
		end
		local how, line = FirstVisitLogic.show(kind, away())
		if how == "toast" then
			UI.toast(line, "good")
		elseif how == "card" then
			local choices: { AskCard.Choice } = {
				{
					id = "go",
					label = FirstVisitLogic.GO,
					icon = Theme.icons.home,
					style = "primary",
				},
				{ id = "later", label = FirstVisitLogic.LATER },
			}
			visit.carded = UI.asks.card({
				title = line,
				choices = choices,
				seconds = FirstVisitLogic.CARD_SECONDS,
				answer = function(id: string?)
					visit.carded = false
					if id == "go" then
						UI.events.travel:Fire("home")
					end
				end,
			}, true) -- news, not an ask: AskPacing does not hold it back (#2880)
			if not visit.carded then
				task.delay(1, present, token, away) -- the card's slot is taken (another card, or its own way out)
			else
				-- #3620: a window or the perk card that opens over the shown card takes the screen; the card
				-- steps aside and comes back when it has closed, while the visit lasts
				task.spawn(function()
					while visit.token == token and visit.carded do
						task.wait(FirstVisitLogic.YIELD_STEP)
						if visit.token == token and visit.carded and busy() then
							local card = askCard
							if card ~= nil and card:isShowing() then
								card:hide("hidden") -- its answer clears `carded`
							end
							visit.carded = false
							present(token, away)
							return
						end
					end
				end)
			end
		end
	end

	-- `raw` is the attribute's value (nil when no first visit is at the cafe); `away` says whether the player is away
	-- from the cafe right now, read again when the line shows.
	function UI.firstVisit.changed(raw: unknown, away: () -> boolean)
		local visit = UI.firstVisit
		local kind = FirstVisitLogic.kind(raw)
		if kind == visit.kind then
			return
		end
		visit.kind = kind
		visit.token += 1
		if visit.carded then
			visit.carded = false
			local card = askCard
			if card ~= nil and card:isShowing() then
				card:hide("hidden")
			end
		end
		if kind ~= nil then
			present(visit.token, away)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- The gift ladder (#2791, retention-ideas.md 5a)
----------------------------------------------------------------------------------------------------

-- The next steps of the gift ladder on the HUD's Rewards tile (HUD.setGiftLadder, Components/GiftLadderLogic): from
-- ProfileSync's giftNext and playSeconds, counted on from when playSeconds came, redrawn each second. The server pays
-- each step and toasts it. Its own table, as the module is short of locals.
UI.giftLadder = {
	played = nil :: number?, -- the last playSeconds the server sent
	playedAt = 0, -- os.clock() when it came
	clock = 0,
}

function UI.giftLadder.refresh()
	local ladder = UI.giftLadder
	local sent = (state :: any).playSeconds
	if sent ~= ladder.played then
		ladder.played = if type(sent) == "number" then sent else nil
		ladder.playedAt = os.clock()
	end
	local view = hud
	if view == nil then
		return
	end
	local played: number? = if ladder.played ~= nil
		then (ladder.played :: number) + (os.clock() - ladder.playedAt)
		else nil
	local GiftLadderLogic = require(script.Components.GiftLadderLogic)
	view:setGiftLadder(
		GiftLadderLogic.rows(
			(state :: any).giftNext,
			played,
			(state :: any).prizeRate or state.incomePerSecond
		)
	)
end

function UI.giftLadder.tick(dt: number)
	local ladder = UI.giftLadder
	ladder.clock += dt
	if ladder.clock >= 1 then
		ladder.clock = 0
		if (state :: any).giftNext ~= nil then
			UI.giftLadder.refresh()
		end
		UI.cozy.refresh()
	end
end

-- #2798 (retention-ideas.md idea 10): the Cozy Cafe line on the Rewards list (HUD.setCozy, Components/CozyLogic),
-- from the own plot's CozyActive, CozyNextAt and CozyBagAt, which the server sets. UI.richTip.bind hands it the plot.
UI.cozy = { plot = nil :: Instance? }

function UI.cozy.refresh()
	local view = hud
	if view == nil then
		return
	end
	local plot = UI.cozy.plot
	if plot == nil then
		view:setCozy(nil, false)
		return
	end
	local CozyLogic = require(script.Components.CozyLogic)
	local line, ready = CozyLogic.line(
		plot:GetAttribute("CozyActive"),
		plot:GetAttribute("CozyNextAt"),
		plot:GetAttribute("CozyBagAt"),
		Workspace:GetServerTimeNow()
	)
	view:setCozy(line, ready)
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
		-- #1897: when a first Epic card or the first wow cat's card last played (os.clock), so one cat never plays both
		firstEpicAt = nil :: number?,
		wowAt = nil :: number?,
	}
	local ONE_CAT_SECONDS = 10

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
		if card == "first_epic" then
			-- #1897: the first wow cat's own card already played for this Epic
			if pull.wowAt ~= nil and os.clock() - pull.wowAt < ONE_CAT_SECONDS then
				return
			end
			pull.firstEpicAt = os.clock()
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

	-- #1897 (first-hour.md 2): the account's first wow cat came to the bowl. The first Epic's smaller card in the
	-- rarity's colours with "YOUR FIRST RARE!" (or "A RARE VISITOR!" when the player already has one) over the cat;
	-- a toast when the cat isn't known. A first Epic's own card (SecuredRare) within seconds is the same cat, so only
	-- one of the two plays.
	function UI.bigPull.wow(rarity: string, first: boolean?, catId: string?)
		if type(rarity) ~= "string" then
			return
		end
		if pull.firstEpicAt ~= nil and os.clock() - pull.firstEpicAt < ONE_CAT_SECONDS then
			return
		end
		local def = if type(catId) == "string" then lookupCat(catId) else nil
		local screen = if def ~= nil then screenFor() else nil
		if def == nil or screen == nil then
			local view = toasts
			if view then
				view:show(BigPullLogic.wowLine(rarity, first), "good")
			end
			return
		end
		pull.wowAt = os.clock()
		screen:show({
			card = "first_epic",
			rarity = rarity,
			word = BigPullLogic.wowWord(rarity, first),
			tone = "rarity",
			name = def.name,
			cat = def,
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
	local OwnerShout = require(script.Screens.OwnerShout)
	local TAG_SECONDS = 120 -- the pal's tag on the Cannon picker card stays this long after they arrive
	local ASK_SECONDS = 14 -- the invite nudge stays up this long with no answer
	local together = {
		ids = {} :: { number },
		pop = nil :: TeamRescuePop.TeamRescuePop?,
		shout = nil :: OwnerShout.OwnerShout?, -- #3301 the owner's /shout bubble
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
		together.shout = OwnerShout.new(parent)
		if hud then
			hud:setPals(together.ids)
		end
	end

	-- #3301 OwnerShout(text): an owner's /shout, filtered by the server, in the OWNER bubble for everyone.
	function UI.ownerShout(text: string)
		local shout = together.shout
		if shout and type(text) == "string" and text ~= "" then
			shout:show(text)
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
		if card == nil or not initialized or card:isShowing() or not UI.asks.paced() then
			return false -- #2880: AskPacing holds it back
		end
		UI.asks.shown()
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
		local shout = together.shout
		if shout then
			shout:destroy()
		end
		together.shout = nil
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
			buyAll = function(kind: string, window: number)
				UI.events.buyCornerShopAll:Fire(kind, window)
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

-- Juniper's Mystery Market (#2565 mystery-market.md section 2a, #2574): the window, opened by walking into the ring in
-- front of the cart (Controllers/WalkUpController) or its prompt, and the gold "!" over the cart until the player first
-- opens it (PlayerState.mysterySeen). A Buy fires UI.events.buyMystery(itemId, shownPrice); the first open fires
-- UI.events.mysterySeen. Walking away closes it. Its own block, as the module is short of locals.
UI.mystery = {}
do
	local MysteryMarketScreen = require(script.Screens.MysteryMarket)
	local MysteryLogic = require(script.Components.MysteryLogic)
	local MarketBang = require(script.Components.MarketBang)
	local SharedConfig =
		require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any
	local CART_TAG = "MysteryMarket" -- MysteryMarketService.TAG: Juniper's cart
	local WINDOW = "MysteryMarket"
	local FAR_STUDS: number = (SharedConfig.MysteryMarketRange or 14) + 6
	local mystery = {
		view = nil :: MysteryMarketScreen.MysteryMarket?,
		bang = nil :: MarketBang.MarketBang?,
	}

	local function cartDistance(): number?
		local character = Players.LocalPlayer.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root == nil or not root:IsA("BasePart") then
			return nil
		end
		local best: number? = nil
		for _, cart in CollectionService:GetTagged(CART_TAG) do
			local at: Vector3? = if cart:IsA("Model")
				then (cart :: Model):GetPivot().Position
				elseif cart:IsA("BasePart") then (cart :: BasePart).Position
				else nil
			if at ~= nil and cart:IsDescendantOf(Workspace) then
				local distance = (at - (root :: BasePart).Position).Magnitude
				if best == nil or distance < best then
					best = distance
				end
			end
		end
		return best
	end

	function UI.mystery.start(into: Instance)
		UI.mystery.reset()
		local modalView = modal
		if modalView == nil then
			return
		end
		local view = MysteryMarketScreen.new({
			buy = function(itemId: string, shownPrice: number)
				UI.events.buyMystery:Fire(itemId, shownPrice)
			end,
			seen = function()
				UI.events.mysterySeen:Fire()
			end,
			close = function()
				if modalView:current() == WINDOW then
					modalView:close()
				end
			end,
			far = function(): boolean
				local distance = cartDistance()
				return distance ~= nil and distance > FAR_STUDS
			end,
			-- #3699: the Backpack's colour picker, behind the switch bagColours
			colours = function(): boolean
				local LiveFlags = require(
					ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags")
				) :: any
				local key = "bagColours"
				return LiveFlags.shown(
					key,
					ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. key)
				)
			end,
			saveColours = function(main: string, trim: string, kind: string?)
				UI.events.setBagColours:Fire(main, trim, kind) -- #4049: kind "shoes" for the Speed Shoes
			end,
		})
		mystery.view = view
		modalView:register(WINDOW, {
			frame = view.frame,
			onOpen = function()
				view:render(state)
				view:opened()
			end,
			onClose = function()
				view:closed()
			end,
		})
		-- the gold "!" over the cart until the first visit
		local bang = MarketBang.new(into, {
			tag = CART_TAG,
			name = "CatCafeMysteryBang",
			line = function(value: any): string?
				return MysteryLogic.bang(value)
			end,
		})
		bang:update(state)
		mystery.bang = bang
	end

	function UI.mystery.render(playerState: Types.PlayerState)
		local view = mystery.view
		if view then
			view:render(playerState)
		end
		local bang = mystery.bang
		if bang then
			bang:update(playerState)
		end
	end

	-- The cart's prompt and its walk-in ring.
	function UI.mystery.open()
		local modalView = modal
		if mystery.view == nil or modalView == nil then
			return
		end
		modalView:open(WINDOW)
	end

	function UI.mystery.close()
		local modalView = modal
		if modalView and modalView:current() == WINDOW then
			modalView:close()
		end
	end

	function UI.mystery.reset()
		local view = mystery.view
		if view then
			view:destroy()
		end
		mystery.view = nil
		local bang = mystery.bang
		if bang then
			bang:destroy()
		end
		mystery.bang = nil
	end
end

-- #2614: while a Mystery gift waits on this player's plot (its MysteryGiftAt, data-model 13), the HUD shows one quiet
-- line in the wrap's colour (the plot's MysteryGiftTier), looked at once a second. Its own block, as the module is
-- short of locals.
UI.giftWait = {}
do
	local GiftLogic = require(script.Components.GiftLogic)
	local LOOK_SECONDS = 1
	local wait = { run = 0 }

	local function myPlot(): Instance?
		local world = Workspace:FindFirstChild("World")
		local plots = if world ~= nil then world:FindFirstChild("Plots") else nil
		if plots == nil then
			return nil
		end
		for _, plot in plots:GetChildren() do
			if plot:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId then
				return plot
			end
		end
		return nil
	end

	-- What the line should say now: the wrap's tier while a gift waits, else nil.
	function UI.giftWait.look(): string?
		local plot = myPlot()
		if plot == nil or not GiftLogic.waiting(plot:GetAttribute("MysteryGiftAt")) then
			return nil
		end
		return GiftLogic.tier(plot:GetAttribute("MysteryGiftTier"))
	end

	-- #3188: whether this player stands on their own cafe plot (the box the till's Collect accepts), for the Daily
	-- Treat's own open. False with no plot or no character yet.
	function UI.giftWait.atCafe(): boolean
		local plot = myPlot()
		local character = Players.LocalPlayer.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if plot == nil or not plot:IsA("Model") or root == nil or not root:IsA("BasePart") then
			return false
		end
		local TillTips = require(script.Components.TillTips) :: any
		return TillTips.onPlot(
			(plot :: Model):GetPivot():PointToObjectSpace((root :: BasePart).Position)
		)
	end

	function UI.giftWait.start()
		wait.run += 1
		local run = wait.run
		task.spawn(function()
			while wait.run == run do
				local view = hud
				if view then
					view:setGift(UI.giftWait.look())
				end
				if initialized then
					autoOpenDailyTreat() -- #3188: it waits for the player to reach their cafe
				end
				task.wait(LOOK_SECONDS)
			end
		end)
	end

	function UI.giftWait.reset()
		wait.run += 1
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
	local LostFound = require(script.Screens.LostFound) -- #3955
	local ReadyBang = require(script.Components.ReadyBang)
	local MarketBang = require(script.Components.MarketBang)
	local RescueBang = require(script.Components.RescueBang)
	local SpinLogic = require(script.Components.SpinLogic) -- #2358
	local SharedConfig =
		require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any
	local CAMP_TAG = "CampExtra" -- shared/CampExtras.TAG: the placed models, with their ExtraId attribute
	-- the card closes once the player walks this far from the Yard Sale (its prompt's reach and some slack)
	local FAR_STUDS: number = (SharedConfig.CampExtraRangeStuds or 8) + 8
	local camp = {
		state = nil :: Types.CampExtrasState?,
		late = nil :: any, -- #2651 part 4: the last LateStationsState
		yard = nil :: YardSale.YardSale?,
		picnic = nil :: PicnicTreats.PicnicTreats?, -- #3715: the Picnic Treats pick card
		lost = nil :: LostFound.LostFound?, -- #3955: the Lost and Found's card
		lostAnywhere = false, -- #3955: opened from the Cannon menu, walking away does not close it
		info = {} :: { [string]: StationInfo.StationInfo }, -- #3938: each station's card while nothing waits
		bang = nil :: ReadyBang.ReadyBang?, -- the red "!" over each ready station (camp-stations.md section 1)
		market = nil :: MarketBang.MarketBang?, -- #2214: the "!" over the Fish Market while crates wait to open
		spin = nil :: MarketBang.MarketBang?, -- #2358: the "!" over the Spin Wheel while the player has a spin
		starter = nil :: MarketBang.MarketBang?, -- #2501: the "!" over the free Bellhop Cat's stand until it is taken
		rescue = nil :: RescueBang.RescueBang?, -- #2214: the "!" over a rescue spot while someone else rescues there
	}

	local function yardView(): Types.CampExtraView?
		local current = camp.state
		return if current ~= nil then current.yardSale else nil
	end

	-- Studs from this player's character to a camp extra's model (the Yard Sale's by default), or nil while either is
	-- streamed out.
	local function yardDistance(extraId: string?): number?
		local character = Players.LocalPlayer.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root == nil or not root:IsA("BasePart") then
			return nil
		end
		for _, model in CollectionService:GetTagged(CAMP_TAG) do
			if
				model:IsA("Model")
				and model:GetAttribute("ExtraId") == (extraId or CampExtrasLogic.YARD_SALE)
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
		local market = MarketBang.new(into)
		market:update(state.crates, (state :: any).storeSeen) -- #2571: and the Treats tab's "!"
		camp.market = market
		camp.rescue = RescueBang.new(into)
		-- #2358: the Spin Wheel's "!", "🎡 Free spin!" or "🎡 2 spins to use", read again each second for 00:00 UTC
		local spinBang = MarketBang.new(into, {
			tag = "SpinWheel", -- WorldBuilder's station tag
			line = function(spin: any): string?
				-- not synced yet, or the tutorial still running (the HUD's spin line waits for it too)
				if spin == nil or ((state :: any).tutorialStep or 5) < 5 then
					return nil
				end
				return SpinLogic.bubble(spin, Workspace:GetServerTimeNow())
			end,
		})
		spinBang:update(state.spin)
		camp.spin = spinBang
		-- #2501 (Derek2: "put an exclamation mark above the free group cat station to help entice people to go join
		-- group to take the cat"): the stand's "!" until the cat is taken; only once the sync says it isn't
		local starterBang = MarketBang.new(into, {
			tag = "BellhopStand", -- shared/StarterCat.TAG
			name = "CatCafeStarterBang",
			line = function(claimed: any): string?
				if claimed ~= false then
					return nil
				end
				return if (SharedConfig.GroupId or 0) ~= 0
					then "🐱 Free cat: join the group!"
					else "🐱 A free cat waits here!"
			end,
		})
		starterBang:update((state :: any).starterCatClaimed)
		camp.starter = starterBang
		local modalView = modal
		if modalView == nil then
			return
		end
		local yard = YardSale.new({
			buy = function(crateId: string)
				UI.events.buyYardSale:Fire(crateId)
			end,
			pick = function()
				UI.events.yardSalePick:Fire()
			end,
			tick = function()
				Moments.YardSaleTick:Fire()
			end,
			landed = function(crateId: string)
				local name = crateId
				local golden = false
				local crates: { Types.CrateDef } = if currentCatalog ~= nil
						and currentCatalog.crates ~= nil
					then currentCatalog.crates
					else {}
				for _, crate in crates do
					if crate.id == crateId then
						name = crate.name
						golden = crate.golden == true
					end
				end
				if toasts then
					toasts:prize("Lucky pick: " .. name, { crates = { [crateId] = 1 } })
				end
				-- #3615: the landing's sound and, for a golden crate, the bigger show at the stall
				Moments.YardSaleLanded:Fire(golden)
				UI.events.yardSaleLanded:Fire(crateId)
			end,
			close = function()
				if modalView:current() == "YardSale" then
					modalView:close()
				end
			end,
			far = function(): boolean
				if camp.yardAnywhere == true then
					return false -- #3213: opened from the Cannon menu
				end
				local distance = yardDistance()
				return distance ~= nil and distance > FAR_STUDS
			end,
		})
		camp.yard = yard
		-- #3715: the Picnic Treats pick card
		local picnic = PicnicTreats.new({
			pick = function(treatId: string)
				UI.events.pickPicnicTreat:Fire(treatId)
			end,
			close = function()
				if modalView:current() == "PicnicTreats" then
					modalView:close()
				end
			end,
		})
		camp.picnic = picnic
		picnic:setView(if camp.state ~= nil then camp.state.picnic else nil)
		-- #3955: the Lost and Found's card; its Claim sends the same CollectCampExtra the ring used to
		local lost = LostFound.new({
			collect = function()
				UI.events.collectCampExtra:Fire("lostFound")
			end,
			close = function()
				if modalView:current() == "LostFound" then
					modalView:close()
				end
			end,
			far = function(): boolean
				if camp.lostAnywhere then
					return false
				end
				local distance = yardDistance("lostFound")
				return distance ~= nil and distance > FAR_STUDS
			end,
		})
		camp.lost = lost
		lost:setView(if camp.state ~= nil then (camp.state :: any).lostFound else nil)
		if currentCatalog then
			lost:setCatalog(currentCatalog)
		end
		modalView:register("LostFound", {
			frame = lost.frame,
			onOpen = function()
				lost:opened()
			end,
			onClose = function()
				lost:closed()
			end,
		})
		-- #3938: a station square with nothing ready opens its card with the timer
		local SharedCatalog =
			require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog")) :: any
		for _, def in SharedCatalog.campExtras do
			local extraId: string = def.id
			local name = "StationInfo_" .. extraId
			local card = StationInfo.new(extraId, function()
				if modalView:current() == name then
					modalView:close()
				end
			end)
			card:setView(if camp.state ~= nil then (camp.state :: any)[extraId] else nil)
			camp.info[extraId] = card
			modalView:register(name, {
				frame = card.frame,
				onOpen = function()
					card:opened()
				end,
				onClose = function()
					card:closed()
				end,
			})
		end
		modalView:register("PicnicTreats", {
			frame = picnic.frame,
			onOpen = function()
				picnic:opened()
			end,
			onClose = function()
				picnic:closed()
			end,
		})
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
			cannonScreen:setLate(camp.late)
		end
		bang:updateLate(camp.late)
	end

	-- #2651 part 4: LateStationsState for the Cat Cannon picker's Desert and Ruins strips and the two stations' bubbles
	function UI.campExtras.late(late: any)
		camp.late = late
		if cannonScreen then
			cannonScreen:setLate(late)
		end
		local bang = camp.bang
		if bang then
			bang:updateLate(late)
		end
	end

	function UI.campExtras.setCatalog(catalog: Types.Catalog)
		local lost = camp.lost
		if lost then
			lost:setCatalog(catalog)
		end
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
		local picnic = camp.picnic
		if picnic then
			picnic:setView(extras.picnic)
		end
		local lost = camp.lost
		if lost then
			lost:setView((extras :: any).lostFound)
		end
		for extraId, card in camp.info do
			card:setView((extras :: any)[extraId])
		end
	end

	-- #3938: a station square with nothing ready: that station's card, its timer and what it gives
	function UI.campExtras.openInfo(extraId: string)
		local modalView = modal
		local card = camp.info[extraId]
		if card == nil or modalView == nil or modalView:current() ~= nil then
			return
		end
		card:setView(if camp.state ~= nil then (camp.state :: any)[extraId] else nil)
		modalView:open("StationInfo_" .. extraId)
	end

	-- #3938: walking off the square closes its card
	function UI.campExtras.closeInfo(extraId: string)
		local modalView = modal
		if modalView ~= nil and modalView:current() == "StationInfo_" .. extraId then
			modalView:close()
		end
	end

	-- #3715: whether the server runs Picnic Treats (the basket's view carries its treats).
	function UI.campExtras.treats(): boolean
		local current = camp.state
		return current ~= nil and current.picnic ~= nil and current.picnic.treats ~= nil
	end

	-- #3715: the Picnic Basket's ring, prompt or Cat Cannon strip: its pick card.
	function UI.campExtras.openPicnic()
		local modalView = modal
		if camp.picnic == nil or modalView == nil or not UI.campExtras.treats() then
			return
		end
		modalView:open("PicnicTreats")
	end

	-- #3955: the Lost and Found's ring or prompt (or, `anywhere`, the Cat Cannon menu): its card.
	function UI.campExtras.openLostFound(anywhere: boolean?)
		local modalView = modal
		if camp.lost == nil or modalView == nil then
			return
		end
		camp.lostAnywhere = anywhere == true
		modalView:open("LostFound")
	end

	-- The Yard Sale's prompt: its card with today's crates.
	function UI.campExtras.openYardSale(view: Types.CampExtraView?, anywhere: boolean?)
		camp.yardAnywhere = anywhere == true -- #3213: from the Cannon menu, walking away does not close it
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
		-- #3955: with its card open the Lost and Found's find shows there, large, in place of the toast
		local lost = camp.lost
		local modalView = modal
		if extraId == "lostFound" and lost and modalView and modalView:current() == "LostFound" then
			lost:found(prize, paid)
			return
		end
		if toasts then
			toasts:prize(
				CampExtrasLogic.prizeTitle(extraId, if prize ~= nil then nil else paid),
				prize
			)
		end
	end

	-- #3615: YardSalePicked: the row of the player's lucky pick rows the server landed on (already banked).
	function UI.campExtras.picked(index: number, crateId: string?)
		local yard = camp.yard
		if yard and type(index) == "number" then
			yard:picked(index, crateId)
		end
	end

	-- CampExtraResult refused: the Yard Sale's "..." lifts (the server's toast says why).
	function UI.campExtras.refused(extraId: string)
		local yard = camp.yard
		if yard and extraId == CampExtrasLogic.YARD_SALE then
			yard:refused()
		end
		local picnic = camp.picnic
		if picnic and extraId == "picnic" then
			picnic:refused()
		end
		local lost = camp.lost
		if lost and extraId == "lostFound" then
			lost:refused()
		end
	end

	-- UI.destroy: the card goes with the modal and the "!" with the UI; the state stays for the next build.
	function UI.campExtras.reset()
		local yard = camp.yard
		if yard then
			yard:destroy()
		end
		camp.yard = nil
		local picnic = camp.picnic
		if picnic then
			picnic:destroy()
		end
		camp.picnic = nil
		local lost = camp.lost
		if lost then
			lost:destroy()
		end
		camp.lost = nil
		for _, card in camp.info do
			card:destroy()
		end
		camp.info = {}
		local bang = camp.bang
		if bang then
			bang:destroy()
		end
		camp.bang = nil
		local market = camp.market
		if market then
			market:destroy()
		end
		camp.market = nil
		local rescue = camp.rescue
		if rescue then
			rescue:destroy()
		end
		camp.rescue = nil
		local spinBang = camp.spin
		if spinBang then
			spinBang:destroy()
		end
		camp.spin = nil
		local starterBang = camp.starter
		if starterBang then
			starterBang:destroy()
		end
		camp.starter = nil
	end

	-- #2214: every render, the Fish Market's "!" with the crates waiting to open
	function UI.campExtras.crates(crates: { [string]: number }?)
		local market = camp.market
		if market then
			market:update(crates, (state :: any).storeSeen) -- #2571: the Treats tab's "!" until it is opened
		end
		-- #2358: the Spin Wheel's "!" with the same render
		local spinBang = camp.spin
		if spinBang then
			spinBang:update(state.spin)
		end
		-- #2501: the free cat's stand with the same render
		local starterBang = camp.starter
		if starterBang then
			starterBang:update((state :: any).starterCatClaimed)
		end
	end
end

-- #2651 part 4 (late-stations.md sections 1 and 2): the Oasis Spa and Relic Museum cards. Controllers/
-- LateStationsController calls open(stationId) from a station's prompt, update(state) with every LateStationsState and
-- result(stationId, ok, detail) with every LateStationResult; the cards' presses go out as
-- UI.events.lateStation(remote, ...). The Cat Cannon picker's strips and the stations' bubbles read the same state
-- (UI.campExtras.late). The last state is kept, so a rebuilt UI shows it at once. Its own block, as the module is
-- short of locals.
do
	local LateStationsLogic = require(script.Components.LateStationsLogic)
	local OasisSpa = require(script.Screens.OasisSpa)
	local RelicMuseum = require(script.Screens.RelicMuseum)
	local SharedConfig =
		require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any
	local TAG = "LateStation" -- shared/LateStations.TAG: the placed models, with their StationId attribute
	local FAR_STUDS: number = (SharedConfig.CampExtraRangeStuds or 8) + 8
	local WINDOWS: { [string]: string } = { spa = "OasisSpa", museum = "RelicMuseum" }
	local late = {
		anywhere = false, -- #3213: the open card came from the Cannon menu, so walking away does not close it
		state = nil :: any,
		spa = nil :: OasisSpa.OasisSpa?,
		museum = nil :: RelicMuseum.RelicMuseum?,
	}

	-- Studs from this player's character to a station's model, or nil while either is streamed out.
	local function distance(stationId: string): number?
		local character = Players.LocalPlayer.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root == nil or not root:IsA("BasePart") then
			return nil
		end
		for _, model in CollectionService:GetTagged(TAG) do
			if
				model:IsA("Model")
				and model:GetAttribute("StationId") == stationId
				and model:IsDescendantOf(Workspace)
			then
				return ((model :: Model):GetPivot().Position - (root :: BasePart).Position).Magnitude
			end
		end
		return nil
	end

	local function far(stationId: string): () -> boolean
		return function(): boolean
			if late.anywhere then
				return false
			end
			local studs = distance(stationId)
			return studs ~= nil and studs > FAR_STUDS
		end
	end

	local function closer(name: string): () -> ()
		return function()
			local modalView = modal
			if modalView and modalView:current() == name then
				modalView:close()
			end
		end
	end

	local function send(remote: string, ...: any)
		UI.events.lateStation:Fire(remote, ...)
	end

	local function paint()
		local current = late.state
		local spa = late.spa
		if spa then
			spa:setView(if current ~= nil then current.spa else nil)
		end
		local museum = late.museum
		if museum then
			museum:setView(
				if current ~= nil then current.museum else nil,
				if current ~= nil then current.spa else nil
			)
		end
	end

	-- UI.init: both cards in the modal.
	function UI.lateStations.start()
		UI.lateStations.reset()
		local modalView = modal
		if modalView == nil then
			return
		end
		local spa = OasisSpa.new({
			put = function(slot: number, uid: string)
				send("SpaPut", slot, uid)
			end,
			takeOut = function(slot: number)
				send("SpaTakeOut", slot)
			end,
			collect = function()
				send("SpaCollect")
			end,
			buy = function(slot: number)
				send("SpaBuySlot", slot)
			end,
			close = closer(WINDOWS.spa),
			far = far(LateStationsLogic.SPA),
		})
		late.spa = spa
		modalView:register(WINDOWS.spa, {
			frame = spa.frame,
			onOpen = function()
				spa:render(state)
				spa:opened()
			end,
			onClose = function()
				spa:closed()
			end,
		})
		local museum = RelicMuseum.new({
			donate = function(uid: string)
				send("MuseumDonate", uid)
			end,
			fill = function(area: string)
				send("MuseumFill", area) -- #3130: Auto fill
			end,
			close = closer(WINDOWS.museum),
			far = far(LateStationsLogic.MUSEUM),
		})
		late.museum = museum
		modalView:register(WINDOWS.museum, {
			frame = museum.frame,
			onOpen = function()
				museum:render(state)
				museum:opened()
			end,
			onClose = function()
				museum:closed()
			end,
		})
		spa:render(state)
		museum:render(state)
		paint()
	end

	function UI.lateStations.render(playerState: Types.PlayerState)
		local spa = late.spa
		if spa then
			spa:render(playerState)
		end
		local museum = late.museum
		if museum then
			museum:render(playerState)
		end
	end

	-- LateStationsState: both cards, the picker's strips and the bubbles.
	function UI.lateStations.update(lateState: any)
		if type(lateState) ~= "table" then
			return
		end
		late.state = lateState
		paint()
		UI.campExtras.late(lateState)
	end

	-- A station's prompt: its card, or a toast while its tier is still ahead (the server refuses every press then).
	-- #3213 (Derek2: "if I open the relic museum from the menu of cannon during night it auto closes"): `anywhere` when
	-- the Cannon menu opens it (#3082), so the walk-away check (far) leaves it open; a station's own prompt passes nil.
	function UI.lateStations.open(stationId: string, anywhere: boolean?)
		late.anywhere = anywhere == true
		local name = WINDOWS[stationId]
		local modalView = modal
		if name == nil or modalView == nil then
			return
		end
		local current = late.state
		local view = if current ~= nil then current[stationId] else nil
		if view ~= nil and view.open ~= true then
			UI.toast(
				string.format(
					"The %s opens at Tier %d",
					LateStationsLogic.NAMES[stationId] or stationId,
					if stationId == LateStationsLogic.SPA then 6 else 7
				),
				"info"
			)
			return
		end
		paint()
		modalView:open(name)
	end

	-- LateStationResult: a refusal wakes the card (the server's toast says why); a gift bursts its exhibit.
	function UI.lateStations.result(stationId: string, ok: boolean, detail: any)
		if not ok then
			local card: any = if stationId == LateStationsLogic.SPA then late.spa else late.museum
			if card then
				card:refused()
			end
			return
		end
		local museum = late.museum
		if
			stationId == LateStationsLogic.MUSEUM
			and museum
			and type(detail) == "table"
			and type(detail.catId) == "string"
		then
			museum:given(detail.catId, if type(detail.room) == "string" then detail.room else nil)
		end
	end

	-- UI.destroy: the cards go with the modal; the state stays for the next build.
	function UI.lateStations.reset()
		local spa = late.spa
		if spa then
			spa:destroy()
		end
		late.spa = nil
		local museum = late.museum
		if museum then
			museum:destroy()
		end
		late.museum = nil
	end
end

----------------------------------------------------------------------------------------------------
-- The Mystic Pool (#3196, #3314, trait-station.md sections 1 and 3)
----------------------------------------------------------------------------------------------------

-- The Mystic Pool's card (Screens/MysticPool): open(anywhere, uid) from the station's ring or the Cannon menu,
-- render(state) with every state (PlayerState.traits is its numbers, false or nil while the `traits` switch is off),
-- and its presses go out as UI.events.rollTrait / chooseTrait / collectTraitTokens. `UI.mysticPool.play` and
-- `UI.mysticPool.far` are the controller's to set: the pool's animation for a roll (Effects/MysticPool.roll, which
-- returns its skip) and the walk-away check. Its own block, as the module is short of locals.
do
	local MysticPool = require(script.Screens.MysticPool)
	local MysticPoolLogic = require(script.Components.MysticPoolLogic)
	local EdgeShade = require(script.Components.EdgeShade)
	local PoolBang = require(script.Components.PoolBang)
	local pool =
		{ card = nil :: MysticPool.MysticPool?, anywhere = false, bang = nil :: PoolBang.PoolBang? }
	UI.mysticPool.play = nil :: ((uid: string, rarity: string, onReveal: () -> ()) -> (() -> ())?)?
	UI.mysticPool.far = nil :: (() -> boolean)?
	UI.mysticPool.cutting = nil :: (() -> boolean)? -- #3846: Effects/BigTraitCut.playing (UI.bigTraitCutting)

	function UI.mysticPool.start()
		UI.mysticPool.reset()
		local modalView = modal
		if modalView == nil then
			return
		end
		local card = MysticPool.new({
			roll = function(uid: string)
				UI.events.rollTrait:Fire(uid)
			end,
			choose = function(takeNew: boolean)
				UI.events.chooseTrait:Fire(takeNew)
			end,
			collect = function()
				UI.events.collectTraitTokens:Fire()
			end,
			-- #3864: a token bundle's Buy opens Roblox's own prompt; ProcessReceipt (ProductService) pays it
			buy = function(productId: number)
				pcall(function()
					game:GetService("MarketplaceService")
						:PromptProductPurchase(game:GetService("Players").LocalPlayer, productId)
				end)
			end,
			-- #3940: the list's Sort and Show chips, saved on the account
			remember = function(key: string, value: any)
				UI.events.setSetting:Fire(key, value)
			end,
			close = function()
				if modalView:current() == MysticPoolLogic.WINDOW then
					modalView:close()
				end
			end,
			play = function(uid: string, rarity: string, onReveal: () -> ()): (() -> ())?
				local play = UI.mysticPool.play
				if play == nil then
					return nil
				end
				return play(uid, rarity, onReveal)
			end,
			far = function(): boolean
				local far = UI.mysticPool.far
				return not pool.anywhere and far ~= nil and far()
			end,
			-- #3702: the card steps aside for the pool's animation, behind a soft shade at the screen's edges
			shade = function(onTap: () -> (), canSkip: boolean): () -> ()
				modalView:tuck(MysticPoolLogic.WINDOW, true)
				local lift = EdgeShade.show(
					modalView.screenGui.Parent :: Instance,
					if canSkip then "Tap to skip" else nil, -- #3943: no skip words on a Mythic or Secret roll
					onTap
				)
				return function()
					lift()
					modalView:tuck(MysticPoolLogic.WINDOW, false)
				end
			end,
		})
		pool.card = card
		pool.bang = PoolBang.new() -- #3936: the red "!" over the pool while a roll waits
		modalView:register(MysticPoolLogic.WINDOW, {
			frame = card.frame,
			onOpen = function()
				card:render(state)
				card:opened()
			end,
			onClose = function()
				card:closed()
			end,
		})
		card:render(state)
	end

	function UI.mysticPool.render(playerState: Types.PlayerState)
		if cannonScreen then
			cannonScreen:setTraits((playerState :: any).traits) -- the Park card's strip in the Cannon menu
		end
		local card = pool.card
		if card then
			card:render(playerState)
		end
		local bang = pool.bang
		if bang then
			bang:update((playerState :: any).traits)
		end
	end

	-- The station's ring, or the Cannon menu (`anywhere`: no walk-away close, as #3213). `uid` picks a cat first
	-- (the cat card's Trait row, later). False, with a toast, while the pool is shut.
	function UI.mysticPool.open(anywhere: boolean?, uid: string?): boolean
		local modalView = modal
		local card = pool.card
		if modalView == nil or card == nil then
			return false
		end
		if type((state :: any).traits) ~= "table" then
			UI.toast("The Mystic Pool is closed for now", "info")
			return false
		end
		pool.anywhere = anywhere == true
		if uid ~= nil then
			card:pick(uid)
		end
		modalView:open(MysticPoolLogic.WINDOW)
		return true
	end

	function UI.mysticPool.reset()
		local card = pool.card
		if card then
			card:destroy()
		end
		pool.card = nil
		local bang = pool.bang
		if bang then
			bang:destroy()
		end
		pool.bang = nil
	end
end

----------------------------------------------------------------------------------------------------
-- Mouse Dash (#3296, Screens/MouseDash; the rules are shared/MouseDash)
----------------------------------------------------------------------------------------------------

-- The arcade's Mouse Dash window. Controllers/UIController passes the server's events straight on (state, began,
-- wave, judged, gone, over) and the switches (setFlags); the window's presses go out as UI.events.mouseDashPlay /
-- mouseDashTap / mouseDashQuit. The last state and switches are kept, so a rebuilt UI shows them at once. Its own
-- block, as the module is short of locals.
do
	local MouseDash = require(script.Screens.MouseDash)
	local MouseDashLogic = require(script.Components.MouseDashLogic)
	local dash = {
		screen = nil :: MouseDash.MouseDash?,
		view = nil :: any,
		on = false, -- the `arcade` and `mouseDash` switches
		circle = true, -- the `circleStreak` switch: Circle Streak can still be played
	}

	local function apply()
		local screen = dash.screen
		if screen then
			screen:setOn(dash.on)
			screen:setOther(dash.circle)
		end
	end

	function UI.mouseDash.start()
		UI.mouseDash.reset()
		local modalView = modal
		if modalView == nil then
			return
		end
		local screen = MouseDash.new({
			play = function()
				UI.events.mouseDashPlay:Fire()
			end,
			tap = function(run: number, index: number, hole: number)
				UI.events.mouseDashTap:Fire(run, index, hole)
			end,
			quit = function(run: number)
				UI.events.mouseDashQuit:Fire(run)
			end,
			close = function()
				if modalView:current() == MouseDashLogic.WINDOW then
					modalView:close()
				end
			end,
			-- to Circle Streak's card, while that game is not vaulted
			other = function()
				if dash.circle and modalView:current() == MouseDashLogic.WINDOW then
					modalView:close()
					modalView:open("Arcade")
				end
			end,
		})
		dash.screen = screen
		modalView:register(MouseDashLogic.WINDOW, {
			frame = screen.frame,
			onOpen = function()
				screen:setFish(state.goldenFish or 0)
				screen:onOpen()
			end,
			onClose = function()
				screen:onClose()
			end,
		})
		if dash.view ~= nil then
			screen:setState(dash.view)
		end
		apply()
	end

	-- Whether the cabinet and the Menu row open Mouse Dash (its switch is on).
	function UI.mouseDash.isMain(): boolean
		return dash.on and dash.screen ~= nil
	end

	function UI.mouseDash.open()
		local modalView = modal
		if
			modalView
			and dash.screen
			and (modalView:current() == nil or modalView:current() == MouseDashLogic.WINDOW)
		then
			modalView:open(MouseDashLogic.WINDOW)
		end
	end

	-- The switches: `on` the arcade's and Mouse Dash's both, `circle` Circle Streak's.
	function UI.mouseDash.setFlags(on: boolean, circle: boolean)
		dash.on = on
		dash.circle = circle
		apply()
	end

	function UI.mouseDash.render(playerState: Types.PlayerState)
		local screen = dash.screen
		if screen then
			screen:setFish(playerState.goldenFish or 0)
		end
	end

	function UI.mouseDash.state(view: any)
		if type(view) ~= "table" then
			return
		end
		dash.view = view
		local screen = dash.screen
		if screen then
			screen:setState(view)
		end
	end

	function UI.mouseDash.began(run: number, hearts: number, firstAt: number, endsAt: number?)
		local screen = dash.screen
		if screen then
			UI.mouseDash.open() -- (a start always comes from the open card; this keeps the board in view)
			screen:began(run, hearts, firstAt, endsAt)
		end
	end

	function UI.mouseDash.wave(run: number, index: number, pops: any, hint: string?)
		local screen = dash.screen
		if screen then
			screen:wave(run, index, pops, hint)
		end
	end

	function UI.mouseDash.judged(
		run: number,
		index: number,
		tap: any,
		points: number,
		hearts: number,
		streak: number,
		milestones: any,
		dizzyUntil: number
	)
		local screen = dash.screen
		if screen then
			screen:judged(run, index, tap, points, hearts, streak, milestones, dizzyUntil)
		end
	end

	function UI.mouseDash.gone(run: number, index: number, gone: any, hearts: number)
		local screen = dash.screen
		if screen then
			screen:gone(run, index, gone, hearts)
		end
	end

	function UI.mouseDash.over(run: number, result: any)
		local screen = dash.screen
		if screen then
			screen:over(run, result)
		end
	end

	function UI.mouseDash.playing(): boolean
		local screen = dash.screen
		return screen ~= nil and screen:playing()
	end

	function UI.mouseDash.reset()
		local screen = dash.screen
		if screen then
			screen:destroy()
		end
		dash.screen = nil
	end
end

----------------------------------------------------------------------------------------------------
-- Rescue Rally (F101, rescue-rally.md section 4)
----------------------------------------------------------------------------------------------------

-- Controllers/RallyController calls UI.rally.update(state) on every RallyState: the banner top centre while a Rally
-- runs, the Town Square board's face and "🏁 Rescue Rally in 5h 20m" under the clock in the last 12 hours before one
-- (the Friday chip). #3691 took the Cat Cannon cards' night tag away. The pops are VFX's (Effects/Rally hooks
-- RallyPoint and finds the banner's RallyBar) and the step prizes' toasts the server's. The state is kept, so a rebuilt UI shows it at
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
		if hud then
			hud:setRallySoon(RallyLogic.soon(current, Workspace:GetServerTimeNow()))
		end
	end

	-- UI.init: the banner and the board faces, painted from the kept state.
	function UI.rally.start(parent: Instance)
		UI.rally.reset()
		-- on a phone the Luck row and the counters sit at the top centre (#2393); the banner moves under them then
		rally.banner = RallyBanner.new(parent, function(): { GuiObject }
			local current = hud
			if current == nil then
				return {}
			end
			return { current:buffRow(), current:counterRow() }
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
			offer = function(
				tradeId: string,
				action: "add" | "remove" | "set",
				uid: string,
				kind: ("decor" | "crate" | "fish")?,
				count: number?
			)
				UI.events.tradeOffer:Fire(tradeId, action, uid, kind, count)
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
		if marketScreen then
			-- #2745: a crate kind on my side of the trade can't be opened at the Market meanwhile
			local onOffer: { [string]: number } = {}
			local mine: { any } = if now ~= nil and type((now.me :: any).crates) == "table"
				then (now.me :: any).crates
				else {}
			for _, crate in mine do
				onOffer[crate.id] = crate.count
			end
			marketScreen:setTradeCrates(onOffer)
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

	function UI.trade.done(
		tradeId: string,
		_gave: { Types.TradeCat }?,
		got: { Types.TradeCat }?,
		_gaveDecor: { Types.TradeDecor }?,
		gotDecor: { Types.TradeDecor }?,
		_gaveCrates: { { id: string, count: number } }?,
		gotCrates: { { id: string, count: number } }?,
		_gaveFish: number?,
		gotFish: number? -- #2745 (section 1d)
	)
		over(tradeId)
		if toasts then
			toasts:show(TradeLogic.doneLine(got, gotDecor, gotCrates, gotFish), "good")
		end
	end

	-- TradeAskEnded (#2550): this player's ask to `toUserId` was declined or ran out, so its Asked wears off soon.
	-- #3211: `now` when the ask never went out (refused) or could not open: the row says Trade again at once.
	function UI.trade.askEnded(toUserId: number, now: boolean?)
		local screen = trading.screen
		if screen and type(toUserId) == "number" then
			screen:askEnded(toUserId, now == true)
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
		grant = nil :: Signal.Connection?, -- PassShop.ownerGrant to UI.events.ownerGrant (#1770)
		thanks = nil :: Signal.Connection?, -- #2147: PassShop.purchased to the outfit passes' toast and sparkle
		open = false, -- whether the HUD's tile shows
		bench = false, -- #1633: the Codes Cat's circle opened the Store, so walking out closes it
		tabs = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StoreTabs")) :: any, -- #1823 §4
		-- #1168 row 4: the Player attribute the server sets on a Thank You Badge buyer (Products.SUPPORTER_ATTRIBUTE)
		supporterKey = (require(
				ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Products")
			) :: any).SUPPORTER_ATTRIBUTE :: string,
		supporter = nil :: RBXScriptConnection?, -- its change hides the badge's card at once
		funnel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StoreFunnel")) :: any, -- #1888
		reported = {} :: { [string]: true }, -- #1888: this visit's tabs and buys already reported
		-- #1936: the server's PlayerState.playSeconds (total play at send time), when it came, and the timer that
		-- redraws the money badge once the first 30 minutes are up
		guard = require(script.Components.StoreGuard),
		played = nil :: number?,
		playedAt = 0,
		quietUntil = nil :: number?,
		blocked = nil :: Signal.Connection?,
	}

	-- #1936 (release.md section 3): under 30 minutes of total play the money badge has no price and does not pulse
	local function quiet(): boolean
		local sent = (state :: any).playSeconds
		if sent ~= shop.played then
			shop.played = if type(sent) == "number" then sent else nil
			shop.playedAt = os.clock()
		end
		local seconds = shop.guard.playSeconds(shop.played, shop.playedAt, os.clock())
		local calm = shop.guard.quiet(seconds)
		if calm and seconds ~= nil then
			local untilAt = os.clock() + shop.guard.QUIET_SECONDS - seconds
			if shop.quietUntil == nil or math.abs(shop.quietUntil - untilAt) > 1 then
				shop.quietUntil = untilAt
				task.delay(shop.guard.QUIET_SECONDS - seconds + 0.5, function()
					if shop.quietUntil == untilAt then
						shop.quietUntil = nil
						UI.store.render()
					end
				end)
			end
		end
		return calm
	end

	-- the potion packs' contents and names from the shared Catalog, the bag from the state (#1182)
	local SharedCatalog =
		require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog")) :: any
	local potionNames: { [string]: string } = {}
	for _, def in SharedCatalog.potions or {} do
		potionNames[def.id] = def.name
	end
	local function view(): StoreLogic.ShopView
		-- #1625: the Starter Bundle's cats by name, and the server's word on whether it is bought
		local catNames: { [string]: string } = {}
		for _, product in SharedCatalog.products or {} do
			for _, catId in (product.prize or {}).cats or {} do
				local def = SharedCatalog.getCat(catId)
				catNames[catId] = if def then def.name else nil
			end
		end
		return {
			products = SharedCatalog.products,
			potionNames = potionNames,
			catNames = catNames,
			have = state.potions,
			starterBought = (state :: any).starterBought,
			cafePass = (UI.pass :: any).offer(), -- #1646: the running season's paid track, nil while closed (defined below)
			supporter = Players.LocalPlayer:GetAttribute(shop.supporterKey) == true, -- #1168 row 4
		}
	end
	local function rows(): { StoreLogic.Row }
		return StoreLogic.rows(Config, PassShop.owned(), state.longNap, view())
	end

	-- The window's cards when it is up, and the HUD's tile when its open state changes.
	local function refresh()
		local screen = shop.screen
		if screen then
			-- #1823 §4: the New dots, on the rail and on the HUD's tile while any tab has one. The rows are built
			-- only while the window is up or a dot could show. The dots go first, so render clears the open tab's.
			local seen = (state :: any).storeSeen
			local unseen = shop.tabs.unseen(if type(seen) == "table" then seen else {})
			local up = modal ~= nil and modal:current() == "Store"
			local list = if up or next(unseen) ~= nil then rows() else nil
			screen:setNew(if list then StoreLogic.newTabs(unseen, list) else {})
			if up and list then
				-- #3572: the Potions tab's bag strip (rework only)
				screen:setBag(StoreLogic.bag(view()))
				screen:render(list, PassShop.prices())
			end
			if hud then
				hud:setStoreNew(screen:hasNew())
			end
		end
		-- #1606: the money pass badge beside the HUD's money ("2x" to "4x", or "Get 2x" while the 2x pass is on sale)
		if hud then
			local boosts = (state :: any).passBoosts
			local multiplier = if type(boosts) == "table" then boosts.money else nil
			hud:setMoneyBadge(
				StoreLogic.moneyBadge(
					Config,
					PassShop.owned(),
					PassShop.prices(),
					multiplier,
					quiet()
				)
			)
		end
		if hud then
			hud:setOwnerTest(PassShop.ownerLabel()) -- #1770: the owner's account only
		end
		local open = screen ~= nil -- the tile shows whenever there is a window for it to open
		if open ~= shop.open and hud then
			shop.open = open
			hud:setStore(if open
				then function()
					if modal then
						-- #1888: the tile with its New dot showing, or plain
						shop.funnel.noteSource(
							if screen and screen:hasNew() then "new_dot" else "hud_tile"
						)
						modal:toggle("Store")
						if modal:current() ~= "Store" then
							shop.funnel.takeSource() -- the tap closed it: no open to tag
						end
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
				-- #1888: the funnel's buy_pressed, the first buy of a visit
				local key = "buy:" .. tostring(passId)
				if not shop.reported[key] then
					shop.reported[key] = true
					UI.events.storeReport:Fire("store_buy", passId)
				end
				PassShop.prompt(passId, "store")
			end,
			tabShown = function(tab: string)
				local key = "tab:" .. tab
				if not shop.reported[key] then
					shop.reported[key] = true
					-- deferred: the open's first tab shows before the modal says the Store opened (store_opened)
					task.defer(function()
						UI.events.storeReport:Fire("store_tab", tab)
					end)
				end
			end,
			close = function()
				if modalView:current() == "Store" then
					modalView:close()
				end
			end,
			-- #1428: the code box starts fresh on the Codes tab and clears when it leaves view
			seen = function(tab: string)
				UI.events.storeSeen:Fire(tab)
			end,
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
				shop.reported = {} -- #1888: a new Store visit, a new funnel session
				screen:showTab("featured") -- #1425: the Store always opens on Featured
				-- #3572: the Potions tab's bag strip (rework only)
				screen:setBag(StoreLogic.bag(view()))
				screen:render(rows(), PassShop.prices())
				PassShop.refresh() -- a price changed in the Creator Hub shows without a rejoin
			end,
			onClose = function()
				shop.bench = false
				screen:closed()
			end,
		})
		shop.changed = PassShop.changed:Connect(refresh)
		shop.supporter =
			Players.LocalPlayer:GetAttributeChangedSignal(shop.supporterKey):Connect(refresh)
		shop.grant = PassShop.ownerGrant:Connect(function(productId: number)
			UI.events.ownerGrant:Fire(productId)
		end)
		-- #1936: no purchase window over a catch, a rescue or a cutscene, and each refusal reported
		PassShop.busy = function(): boolean
			return UI.catch.circlesActive() or UI.rescue.isActive() or UI.intro.playing()
		end
		-- #2147 (store-pass-looks.md 7.3): right after an outfit pass is bought here (never at join or a sync), the
		-- toast, and Moments.OutfitPassBought for Animation's bow sparkle over each working cat (Effects/PassThanks,
		-- which skips it on Reduce Motion or Low)
		shop.thanks = PassShop.purchased:Connect(function(passId: number)
			local which = if passId == Config.CatAccessoriesPassId
				then "accessories"
				elseif passId == Config.UniformStylesPassId then "uniforms"
				else nil
			if which == nil then
				return
			end
			UI.toast(StoreLogic.outfitThanks(which), "good")
			local outfitBought = (Moments :: any).OutfitPassBought -- on main with #2154
			if outfitBought ~= nil then
				outfitBought:Fire(which)
			end
		end)
		shop.blocked = PassShop.blocked:Connect(function(source: string, reason: string)
			UI.events.storeGuardBlocked:Fire(source .. ":" .. reason)
		end)
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

	-- The Codes Cat's circle opens the Store on Featured, like the Store tile, and the player taps Codes on the rail
	-- (#1633, Derek2 11-05: "it should open it to featured and have them go down to codes after that way they look at
	-- products"; #1428 opened it on Codes). A window already up stays open (review N182). False when there is no
	-- Store window, so the old Codes window opens instead.
	function UI.store.openAtBench(): boolean
		local modalView = modal
		if shop.screen == nil or modalView == nil then
			return false
		end
		if modalView:current() == nil then
			modalView:open("Store")
			shop.bench = modalView:current() == "Store"
		end
		return true
	end

	-- Whether the Store the circle opened is still up, on any tab (walking out closes it).
	function UI.store.benchShowing(): boolean
		return shop.bench and modal ~= nil and modal:current() == "Store"
	end

	-- Whether the Store is up on its Codes tab (a code's answer shows there, else as a toast).
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
		if shop.thanks then
			shop.thanks:Disconnect()
			shop.thanks = nil
		end
		if shop.grant then
			shop.grant:Disconnect()
			shop.grant = nil
		end
		if shop.blocked then
			shop.blocked:Disconnect()
			shop.blocked = nil
		end
		shop.quietUntil = nil
		if shop.supporter then
			shop.supporter:Disconnect()
			shop.supporter = nil
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
-- Cafe Pass (#1646)
----------------------------------------------------------------------------------------------------

-- The Cafe Pass window (Screens/CafePass, cafe-pass.md) and the HUD's Pass tile. The tile shows only while a season
-- runs (live, the pass is closed until Season 1's date is set; Studio runs a preview Season 1), with a red "!" while
-- rewards are ready. A quest's "+100 pass XP" pill shows on prize chips only while a season runs too
-- (PrizeChips.passOpen). Its own block, as the module is short of locals.
do
	local CafePass = require(script.Screens.CafePass)
	local PassLogic = require(script.Components.PassLogic)
	local PassShop = require(script.Components.PassShop)
	local SharedPass =
		require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CafePass")) :: any
	local pass = {
		screen = nil :: CafePass.CafePass?,
		view = nil :: Types.CafePassView?,
		catalog = nil :: Types.Catalog?, -- the catalog the window's chips have
		shown = false, -- whether the HUD's tile shows
		prices = nil :: Signal.Connection?, -- PassShop.changed, for the buy button's price
	}

	-- The paid track's product id (Config.ProductIds.cafe_pass, #1657), or nil while it is not made.
	local function productId(): number?
		local ids = (Config :: any).ProductIds
		local id = if type(ids) == "table" then ids.cafe_pass else nil
		return if type(id) == "number" and id ~= 0 then id else nil
	end

	-- The window's buy button: Roblox's price while the season's paid track is not bought and the product is on sale,
	-- else hidden (bought, loading or off sale).
	local function buyButton()
		local screen = pass.screen
		if screen == nil then
			return
		end
		local view = pass.view
		local id = productId()
		local price = if id then PassShop.prices()[id] else nil
		local sells = view ~= nil
			and PassLogic.shows(view)
			and not view.paid
			and SharedPass.saleOpen(Workspace:GetServerTimeNow(), view.endsAt) -- #2129
		if sells and price ~= nil and price.forSale and price.robux ~= nil then
			screen:setBuy(("Paid track  R$%d"):format(price.robux :: number))
		else
			screen:setBuy(nil)
		end
	end

	-- The HUD's tile from the last CafePassState.
	local function tile()
		local view = pass.view
		local shown = pass.screen ~= nil and PassLogic.shows(view)
		if hud == nil then
			return
		end
		pass.shown = shown
		hud:setPass(
			if shown
				then function()
					if modal then
						modal:toggle("CafePass")
					end
				end
				else nil,
			if view then view.claimable else 0
		)
	end

	-- UI.init: the window in the modal.
	function UI.pass.start()
		UI.pass.reset()
		local modalView = modal
		if modalView == nil then
			return
		end
		local screen = CafePass.new({
			claim = function(track: string, level: number)
				UI.events.passClaim:Fire(track, level)
			end,
			claimAll = function()
				UI.events.passClaimAll:Fire()
			end,
			setTag = function(pick: string)
				UI.events.passSetTag:Fire(pick)
			end,
			buy = function()
				local id = productId()
				if id then
					PassShop.prompt(id, "cafePass") -- the server's receipt unlocks the track and sends CafePassState
				end
			end,
			close = function()
				if modalView:current() == "CafePass" then
					modalView:close()
				end
			end,
		})
		pass.screen = screen
		modalView:register("CafePass", {
			frame = screen.frame,
			onOpen = function()
				UI.pass.render()
				screen:onOpen()
			end,
		})
		screen:setView(pass.view)
		if potionsScreen then
			potionsScreen:setPassView(pass.view) -- the Bag's Titles tab
		end
		pass.prices = PassShop.changed:Connect(buyButton)
		buyButton()
		UI.pass.render()
		tile()
	end

	-- From CafePassState (Types.CafePassView): at join, after each claim and at a season roll.
	function UI.pass.set(view: Types.CafePassView?)
		pass.view = view
		local screen = pass.screen
		if screen then
			screen:setView(view)
		end
		if potionsScreen then
			potionsScreen:setPassView(view) -- the Bag's Titles tab
		end
		buyButton()
		tile()
		UI.store.render() -- the Store's Cafe Pass card follows the season and the purchase
	end

	-- The running season for the Store's Cafe Pass card (StoreLogic.PassOffer), or nil while the pass is closed.
	function UI.pass.offer(): any
		local view = pass.view
		if view == nil or not PassLogic.shows(view) then
			return nil
		end
		local def = SharedPass.seasonDef(view.season)
		return {
			season = view.season,
			name = if def then def.name else ("Season %d"):format(view.season),
			paid = view.paid,
			contents = PassLogic.paidContents(def),
			saleOpen = SharedPass.saleOpen(Workspace:GetServerTimeNow(), view.endsAt), -- #2129: closed just before the season ends
		}
	end

	-- Every state update: the day rate and spin bank for the prize chips, and the catalog once it arrives.
	function UI.pass.render()
		local screen = pass.screen
		if screen == nil then
			return
		end
		local catalog = currentCatalog
		if catalog and catalog ~= pass.catalog then
			pass.catalog = catalog
			screen:setCatalog(catalog)
		end
		screen:render(state)
	end

	function UI.pass.setNight(night: boolean)
		if pass.screen then
			pass.screen:setNight(night)
		end
	end

	function UI.pass.open()
		if modal and pass.shown then
			modal:open("CafePass")
		end
	end

	-- UI.destroy.
	function UI.pass.reset()
		if pass.prices then
			pass.prices:Disconnect()
			pass.prices = nil
		end
		if pass.screen then
			pass.screen:destroy()
			pass.screen = nil
		end
		pass.catalog = nil
		if pass.shown and hud then
			hud:setPass(nil, 0)
		end
		pass.shown = false
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

----------------------------------------------------------------------------------------------------
-- Session recap (#1920, first-hour.md section 6)
----------------------------------------------------------------------------------------------------

-- UIController's hook for SessionRecap(view): Gameplay sends it once a session after RecapAfterSeconds of play with
-- view = { minutes, newCats, earned } for this session. The card waits for a calm moment (after the tutorial, not
-- catching, carrying or in a menu or card, idle RecapLogic.IDLE_SECONDS) and shows once; with the sessionRecap
-- setting off it never shows. The other lines come from what the client holds (Components/RecapLogic).
UI.recap = {
	card = nil :: any,
	waiting = nil :: { [string]: any }?,
	shown = false,
	lastInput = os.clock(),
	watching = false,
}

local function recapIdleSeconds(): number
	local player = game:GetService("Players").LocalPlayer
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.MoveDirection.Magnitude > 0.05 then
		UI.recap.lastInput = os.clock() -- walking with a held key or the thumbstick
	end
	return os.clock() - UI.recap.lastInput
end

-- #2916: Gameplay's next goals on the recap (view.goals) as the card's rows, two on a short screen.
local function recapGoals(view: { [string]: any }): { any }
	local ReturnGoalWords = require(script.Components.ReturnGoalWords)
	return ReturnGoalWords.rows(
		view.goals,
		Format.money,
		if Scale.isShort() then ReturnGoalWords.MAX_SHORT else ReturnGoalWords.MAX
	)
end

local function recapLines(view: { [string]: any }): { string }
	local RecapLogic = require(script.Components.RecapLogic)
	local catalog = currentCatalog
	local nextTier: string? = nil
	if catalog and catalog.tiers and state.tier then
		for _, tier in catalog.tiers :: { any } do
			if tier.tier == state.tier + 1 and type(tier.name) == "string" then
				nextTier = tier.name
			end
		end
	end
	local readyAt: { number } = {}
	for _, bowl in bowls.views do
		if bowl and type(bowl.readyAt) == "number" then
			table.insert(readyAt, bowl.readyAt)
		end
	end
	local longNap = state.longNap == true
	return RecapLogic.lines({
		view = view,
		state = state :: any,
		nextTier = nextTier,
		baitReadyAt = readyAt,
		now = Workspace:GetServerTimeNow(),
		offlineRate = if longNap then Config.OfflineRatePass else Config.OfflineRate,
		offlineCapSeconds = if longNap
			then Config.OfflineCapPassSeconds
			else Config.OfflineCapSeconds,
		money = Format.money,
		goals = #recapGoals(view) > 0, -- #2916: the card draws them with bars
	})
end

local function recapTry(): boolean
	local view = UI.recap.waiting
	local card = UI.recap.card
	if view == nil or card == nil or UI.recap.shown then
		return true
	end
	local RecapLogic = require(script.Components.RecapLogic)
	local settings: { [string]: any } = state.settings or {}
	if settings[RecapLogic.SETTING] == false then
		UI.recap.waiting = nil -- off: this session's card is dropped
		return true
	end
	local busy = (modal ~= nil and modal:current() ~= nil)
		or (baitCard ~= nil and baitCard:isShowing())
		or (tipCard ~= nil and tipCard:isShowing())
		or (UI.gift.card ~= nil and UI.gift.card:isShowing())
		or not visible
	if
		not RecapLogic.canShow({
			enabled = true,
			tutorialStep = state.tutorialStep,
			catching = hud ~= nil and hud:isCatching(),
			carrying = state.carrying ~= nil,
			menuOpen = busy,
			idleSeconds = recapIdleSeconds(),
		})
	then
		return false
	end
	UI.recap.shown = true
	UI.recap.waiting = nil
	card:show(recapLines(view), function(secondsUp: number)
		UI.events.sessionRecapClose:Fire(secondsUp)
	end, recapGoals(view))
	UI.events.sessionRecap:Fire()
	return true
end

function UI.recap.show(view: any)
	if type(view) ~= "table" or UI.recap.shown or UI.recap.waiting ~= nil then
		return
	end
	UI.recap.waiting = view
	if not UI.recap.watching then
		UI.recap.watching = true
		local inputs = UserInputService.InputBegan:Connect(function()
			UI.recap.lastInput = os.clock()
		end)
		task.spawn(function()
			while not recapTry() do
				task.wait(1)
			end
			inputs:Disconnect()
			UI.recap.watching = false
		end)
	end
end

-- #1947 (like-prompts.md section 2): UIController's hook for PlaytimeGift(kind, paid). The server has already paid the
-- gift, so the card only thanks: it waits until the player has been idle Config.GiftIdleSeconds, out of the catch
-- circles, the rescue bar, the intro, any window or card, and not carrying, then shows once. The favourite card comes
-- a minute or more after the like card, so they queue rather than stack.
-- #2687 part 4: the station perk card. Moments.StationReveal (WorldController, once per area per account) brings the
-- "Unlocked!" card a beat after the station's build-in (REVEAL_SECONDS, shorter with Reduce Motion, which has no camera
-- beat); the rank up window's Perks button shows "Your perks".
UI.perks = {
	card = nil :: any,
	reveal = nil :: RBXScriptConnection?,
	token = 0, -- the latest unlock's, so a teardown or a second reveal drops an older wait
	REVEAL_SECONDS = 3,
	REDUCED_SECONDS = 0.5,
	WINDOW_WAIT_SECONDS = 300,
	YIELD_STEP = 0.25, -- how often a showing card looks for a window that opened after it
}

function UI.perks.unlock(perkId: string)
	local StationPerks =
		require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StationPerks")) :: any
	local perk = StationPerks.get(perkId)
	if perk == nil then
		return
	end
	UI.perks.token += 1
	local token = UI.perks.token
	local seconds = if game:GetService("GuiService").ReducedMotionEnabled
		then UI.perks.REDUCED_SECONDS
		else UI.perks.REVEAL_SECONDS
	task.delay(seconds, function()
		-- #3585: never on top of a window (a first Park visit that walks straight onto the Mystic Pool's ring had
		-- both up at once); the card waits for the window to close, up to WINDOW_WAIT_SECONDS
		local waited = 0
		local windows = modal
		-- Review-QA's Studio pass 2026-11-13: the "Unlocked! Haggler" card came up over a Rummage Bin roll, which
		-- is not a window; a roll or its reveal (UI.rollBusy) holds the card as a window does
		local function blocked(): boolean
			return (windows ~= nil and windows:current() ~= nil) or UI.rollBusy.on or UI.cutscene.on
		end
		while UI.perks.token == token and blocked() and waited < UI.perks.WINDOW_WAIT_SECONDS do
			waited += task.wait(0.5)
		end
		if UI.perks.token ~= token or UI.perks.card == nil then
			return
		end
		-- the Mystic Pool stands on the Picnic Basket's spot while `traits` is on, so the Park's card names the pool
		local pool = require(script.Components.PerkCardLogic).poolStands()
		local card = UI.perks.card
		card:showUnlocked(perk, pool)
		-- #3585, the other direction: a window that opens while the card is up (the walk onto the pool's ring a
		-- moment after the card) takes the screen; the card steps aside and comes back when the window has closed.
		-- It comes back once: a second window or roll puts it away (Rank up's Perks lists it), so it never returns
		-- after every Rummage Bin roll.
		local returns = 0
		while UI.perks.token == token and UI.perks.card == card and card:isShowing() do
			task.wait(UI.perks.YIELD_STEP)
			if
				blocked()
				and UI.perks.token == token
				and UI.perks.card == card
				and card:isShowing()
				and card._mode == "unlocked"
			then
				card:hide()
				returns += 1
				if returns > 1 then
					return
				end
				local away = 0
				while
					UI.perks.token == token
					and blocked()
					and away < UI.perks.WINDOW_WAIT_SECONDS
				do
					away += task.wait(0.5)
				end
				if UI.perks.token ~= token or UI.perks.card ~= card then
					return
				end
				card:showUnlocked(perk, pool)
			end
		end
	end)
end

UI.gift = {
	card = nil :: any,
	queue = {} :: { { kind: string, paid: { string }? } },
	watching = false,
	inputs = nil :: RBXScriptConnection?,
}

local function giftOpen(kind: string, paid: { string }?)
	local GiftCardLogic = require(script.Components.GiftCardLogic)
	local PlaytimeGifts =
		require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PlaytimeGifts")) :: any
	local card = UI.gift.card
	local prize = GiftCardLogic.prize(PlaytimeGifts.prize(kind), paid)
	card:show(kind, prize, function(button: string?)
		if button == nil then
			return -- a card left alone or replaced reports nothing
		end
		UI.events.playtimeGift:Fire(GiftCardLogic.report(kind :: any, button))
		if button == "favourite" then
			-- Roblox's own favourite window for this place (a place is an asset); the gift is the same either way
			pcall(function()
				game:GetService("AvatarEditorService")
					:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
			end)
		end
		if button ~= GiftCardLogic.CLOSE_BUTTON then
			card:showAfter()
		end
	end)
end

local function giftTry(): boolean
	local card = UI.gift.card
	local waiting = UI.gift.queue[1]
	if waiting == nil or card == nil then
		return true
	end
	local GiftCardLogic = require(script.Components.GiftCardLogic)
	local busy = (modal ~= nil and modal:current() ~= nil)
		or (baitCard ~= nil and baitCard:isShowing())
		or (tipCard ~= nil and tipCard:isShowing())
		or (UI.recap.card ~= nil and UI.recap.card:isShowing())
		or card:isShowing()
		or not visible
		or UI.bigTraitCutting() -- #3846: never over a trait roll's cutscene
	if
		not GiftCardLogic.canShow({
			idleSeconds = recapIdleSeconds(),
			idleNeeded = (Config :: any).GiftIdleSeconds or GiftCardLogic.IDLE_SECONDS,
			catching = (hud ~= nil and hud:isCatching())
				or UI.catch.circlesActive()
				or UI.rescue.isActive(),
			carrying = state.carrying ~= nil,
			intro = UI.intro.playing(),
			menuOpen = busy,
		})
	then
		return false
	end
	table.remove(UI.gift.queue, 1)
	giftOpen(waiting.kind, waiting.paid)
	return #UI.gift.queue == 0
end

function UI.gift.show(kind: any, paid: any)
	if kind ~= "like" and kind ~= "fav" then
		return
	end
	local name: string = kind
	local lines: { string }? = if type(paid) == "table" then paid else nil
	table.insert(UI.gift.queue, { kind = name, paid = lines })
	if not UI.gift.watching then
		UI.gift.watching = true
		task.spawn(function()
			while not giftTry() do
				task.wait(1)
			end
			UI.gift.watching = false
		end)
	end
end

-- #1955 (auto-equip.md): UIController's hook for AutoEquipped(swaps). #2399 (Derek2: "auto equip bubble pop-ups are
-- also just more bloat on the screen"): no toast any more; the Cats window shows the jobs.
UI.autoEquip = {}

function UI.autoEquip.swapped(_raw: any) end

----------------------------------------------------------------------------------------------------
-- Cafe Events (#2487, live-events.md section 3)
----------------------------------------------------------------------------------------------------

-- EventService (#2486) keeps the running event, or the next one, on ReplicatedStorage's attributes; this reads them
-- every second: the HUD chip under the day clock from T-3h, a banner the first time this client sees one running,
-- and the Town Square board's face. Its own block, as the module is short of locals.
do
	local HttpService = game:GetService("HttpService")
	local EventBoards = require(script.Screens.EventBoards)
	local EventLogic = require(script.Components.EventLogic)
	local TICK_SECONDS = 1
	local events = {
		boards = nil :: EventBoards.EventBoards?,
		seen = nil :: EventLogic.Seen?, -- kept across rebuilds, so a respawn neither repeats the banner nor forgets the end
		token = 0,
	}

	-- EventEffects' JSON; the UI gate's shim has no HttpService, so its scenes put their own decoder here
	function UI.cafeEvent.decode(json: string): any
		local ok, data = pcall(HttpService.JSONDecode, HttpService, json)
		return if ok then data else nil
	end

	local function get(name: string): any
		return ReplicatedStorage:GetAttribute(name)
	end

	-- "6:00 PM": `unix` in this player's own time, for the party card (#3420)
	function UI.cafeEvent.clock12(unix: number): string
		local text = os.date("%I:%M %p", math.floor(unix)) :: string
		return (string.gsub(text, "^0", ""))
	end

	-- the headline features of party `id` that are switched on right now, in the spec's order (#3420 section 5,
	-- #3535). A switch this build does not know (its feature has not merged) counts as off.
	function UI.cafeEvent.news(id: string): { string }
		local LiveFlags =
			require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags")) :: any
		local out: { string } = {}
		local pairsOf: { { string } } = EventLogic.PARTY_NEWS[id] or {}
		for _, pair in pairsOf do
			if
				table.find(LiveFlags.KEYS, pair[1]) ~= nil
				and LiveFlags.shown(pair[1], get(LiveFlags.ATTRIBUTE_PREFIX .. pair[1]))
			then
				table.insert(out, pair[2])
			end
		end
		return out
	end

	-- #3573: the HUD's rest chip, from AfkController
	function UI.rest.set(resting: boolean, doubled: boolean?)
		local current = hud
		if current then
			(current :: any):setRest(resting, doubled)
		end
	end

	-- #3701: the cafe rest banner (Components/RestBanner), from AfkController: its state (nil hides it), whether a
	-- rest doubles the pay right now and, while it counts, the seconds left. Made the first time it is needed and
	-- kept at the head of the toasts' stack. It replaces the rest chip above.
	local restBanner: any = nil
	function UI.rest.banner(state: string?, doubled: boolean?, remaining: number?)
		if restBanner == nil then
			local stack = toasts
			if state == nil or stack == nil then
				return
			end
			restBanner = require(script.Components.RestBanner).new()
			stack:pin(restBanner.frame)
		end
		restBanner:set(state, doubled, remaining)
	end

	function UI.rest.calm(): boolean
		local tips: any = UI.tips
		return tips.calm()
	end

	-- one pass: read, follow, paint; the banner shows once per event this session
	function UI.cafeEvent.tick()
		local now = Workspace:GetServerTimeNow()
		local view = EventLogic.read(get, UI.cafeEvent.decode)
		local seen, started = EventLogic.follow(events.seen, view, now)
		events.seen = seen
		if started and view ~= nil and toasts then
			-- #3420: an Update Party starts with the party card; any other event with the toast
			local party = EventLogic.partyBanner(
				view,
				UI.cafeEvent.clock12(view.endsAt),
				UI.cafeEvent.news(view.id)
			)
			local shown = false
			if party ~= nil then
				local EventBanner = require(script.Parent.Effects.EventBanner) :: any
				shown = EventBanner.show({
					kind = "party",
					title = party.title,
					lines = party.lines,
				}) == true
				-- #3535: Friday's party is followed by the Secret cats card (queued behind the party card)
				local LiveFlags = require(
					ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags")
				) :: any
				local Catalog =
					require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog")) :: any
				local secrets = EventLogic.secretsBanner(
					view,
					LiveFlags.shown("secretCats", get(LiveFlags.ATTRIBUTE_PREFIX .. "secretCats")),
					#Catalog.secretCats
				)
				if secrets ~= nil then
					EventBanner.show({
						kind = "secrets",
						title = secrets.title,
						lines = secrets.lines,
					})
				end
			end
			if not shown then
				toasts:announce(
					EventLogic.banner(view, os.date("%H:%M", math.floor(view.endsAt)) :: string)
				)
			end
		end
		local current = hud
		if current then
			local chipLines, chipKind = EventLogic.chip(view, seen, now)
			current:setEvent(chipLines, chipKind, EventLogic.strip(view, seen, now))
			current:setEventBoost(EventLogic.moneyBoost(view, now))
		end
		local boards = events.boards
		if boards then
			boards:set(view, seen)
		end
	end

	function UI.cafeEvent.start(parent: Instance)
		UI.cafeEvent.reset()
		events.boards = EventBoards.new(parent)
		events.token += 1
		local token = events.token
		task.spawn(function()
			while events.token == token do
				UI.cafeEvent.tick()
				task.wait(TICK_SECONDS)
			end
		end)
	end

	-- the UI gate's scenes: forget the watched event, so a put-away test party is not "ended early"
	function UI.cafeEvent.forget()
		events.seen = nil
	end

	function UI.cafeEvent.reset()
		events.token += 1
		local boards = events.boards
		if boards then
			boards:destroy()
		end
		events.boards = nil
	end
end

----------------------------------------------------------------------------------------------------
-- #3529 (shared/NewKind): the "NEW" tag over strays and stuck cats of kinds this player has never owned
-- (Screens/NewKindTags), and the catch card's "New kind!" line. Behind the `newKindTag` live switch, off by default.
----------------------------------------------------------------------------------------------------

do
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local NewKind = require(Shared:WaitForChild("NewKind"))
	local kind: { tags: any, watch: RBXScriptConnection? } = { tags = nil, watch = nil }

	function UI.newKind.on(): boolean
		local LiveFlags =
			require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags")) :: any
		return LiveFlags.shown(
			NewKind.FLAG,
			ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. NewKind.FLAG)
		)
	end

	-- Different kinds owned toward rank up, from the Index the client has.
	function UI.newKind.kinds(): number
		local Economy = require(Shared:WaitForChild("Economy")) :: any
		return Economy.rankUpCatCount(state.collection or {})
	end

	function UI.newKind.refresh()
		if kind.tags ~= nil then
			kind.tags:set(UI.newKind.on(), state.collection)
		end
	end

	function UI.newKind.start()
		if kind.tags ~= nil then
			return
		end
		kind.tags = require(script.Screens.NewKindTags).new()
		local LiveFlags =
			require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags")) :: any
		kind.watch = ReplicatedStorage
			:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. NewKind.FLAG)
			:Connect(UI.newKind.refresh)
		UI.newKind.refresh()
	end

	function UI.newKind.stop()
		if kind.watch ~= nil then
			kind.watch:Disconnect()
			kind.watch = nil
		end
		if kind.tags ~= nil then
			kind.tags:destroy()
			kind.tags = nil
		end
	end

	-- This player is on a catch or rescue bar: the tags step aside.
	function UI.newKind.setBusy(busy: boolean)
		if kind.tags ~= nil then
			kind.tags:setBusy(busy)
		end
	end

	-- The nearest tagged stray's part in wild area `area`, for the five cats trail (UIController).
	function UI.newKind.nearest(area: string): BasePart?
		return if kind.tags ~= nil then kind.tags:nearest(area) else nil
	end

	-- The catch card's line for a cat of this kind, nil when the switch is off or the kind is not new.
	function UI.newKind.line(catId: unknown, rarity: unknown): string?
		if not UI.newKind.on() or not NewKind.isNew(state.collection, catId, rarity) then
			return nil
		end
		return NewKind.line(UI.newKind.kinds(), state.tier or 1)
	end
end

return UI
