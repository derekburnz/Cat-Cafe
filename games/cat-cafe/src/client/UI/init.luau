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
local BaitBowl = require(script.Screens.BaitBowl)
local BaitCard = require(script.Screens.BaitCard)
local BugReport = require(script.Screens.BugReport)
local BugReportLogic = require(script.Components.BugReportLogic)
local CafeSigns = require(script.Screens.CafeSigns)
local CatCard = require(script.Screens.CatCard)
local CatCardLogic = require(script.Components.CatCardLogic)
local CatCollection = require(script.Screens.CatCollection)
local CatVariant = require(script.Components.CatVariant)
local CatchCircles = require(script.Screens.CatchCircles)
local CatchPrompt = require(script.Screens.CatchPrompt)
local ClientErrors = require(script.Components.ClientErrors)
local Codes = require(script.Screens.Codes)
local Collector = require(script.Screens.Collector)
local Create = require(script.Components.Create)
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
local Motion = require(script.Components.Motion)
local MyCats = require(script.Screens.MyCats)
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
local Signpost = require(script.Screens.Signpost)
local Sound = require(script.Components.Sound)
local SpinWheel = require(script.Screens.SpinWheel)
local TackleBar = require(script.Screens.TackleBar)
local TackleLogic = require(script.Components.TackleLogic)
local Theme = require(script.Theme)
local TillTipsButton = require(script.Screens.TillTipsButton)
local TipJar = require(script.Screens.TipJar)
local Toasts = require(script.Screens.Toasts)
local Types = require(script.Types)
local UpgradeShop = require(script.Screens.UpgradeShop)
local Wayfinding = require(script.Components.Wayfinding)
local WorldMarker = require(script.Components.WorldMarker)
local WorldTags = require(script.Screens.WorldTags)

local UI = {}

UI.Types = Types
UI.Theme = Theme
UI.Format = Format

-- Intents from the player. The controller forwards them to remotes; the server validates.
UI.events = {
	buyUpgrade = Signal.new(), -- (upgradeId)
	buyDecor = Signal.new(), -- (decorId)
	toggleDecor = Signal.new(), -- (decorId, placed: boolean)
	buyLure = Signal.new(), -- (lureId)
	placeCat = Signal.new(), -- (uid, spotId)
	unplaceCat = Signal.new(), -- (uid)
	sellCat = Signal.new(), -- (uid)
	lockCat = Signal.new(), -- (uid, locked)   the Lock row in the cat room: forward as LockCat (F62)
	renameCat = Signal.new(), -- (uid, name)   Rename in the cat room, trimmed and checked with Shared.CatName: forward as RenameCat (F33)
	equipBest = Signal.new(), -- ()   server places the highest-rated cats on the open spots
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
	catchPressed = Signal.new(), -- (strayId, index, grade)   a press on circle `index` with this device's grade: forward strayId and index as CatchPress
	rankUp = Signal.new(), -- ()   Rank up pressed on the card with every requirement met: forward as RankUp
	travel = Signal.new(), -- (destination)   "home" or an AreaId from the travel row or Areas panel: forward as Travel
	useLure = Signal.new(), -- (lureId)   Use on a food in the Bait bowl screen: forward as UseLure (F28)
	resolveBait = Signal.new(), -- (choice)   "tame" or "letgo" from the bait card: forward as ResolveBait
	-- (index, lureId, window)   Buy on the night dealer screen (F32): forward lureId and window as BuyDealerFood (F59);
	-- index is the food's row, unused since F59, and window the DealerStock's the screen showed (nil if none came)
	buyDealerFood = Signal.new(),
	claimRichTip = Signal.new(), -- ()   Collect on the rich tip marker over your cafe: forward as ClaimRichTip (F31)
	-- design v0.5
	tackle = Signal.new(), -- ()   the Tackle button or Q: lunge and forward as Tackle (F74, no target)
	-- 2026-10-27 HUD v3
	dropCat = Signal.new(), -- ()   Drop on the carry banner or G while carrying: forward as DropCat
	-- 2026-10-27 wave 2
	claimTipJar = Signal.new(), -- (step)   Claim on a ready Tip Jar gift: forward as ClaimTipJar (F47)
	claimIndexReward = Signal.new(), -- (areaId, milestoneId)   Claim on an Index reward card: forward as ClaimIndexReward (F48)
	spinWheel = Signal.new(), -- ()   Spin on the Spin Wheel window: forward as SpinWheel (F49)
	openCrate = Signal.new(), -- (crateId)   Open on a Golden Fish Market crate card: forward as OpenCrate (F53)
	buyFishItem = Signal.new(), -- (itemId)   Buy on a Market treat or perk row: forward as BuyFishItem (F53)
	setSetting = Signal.new(), -- (key, value)   a Settings switch (boolean) or volume (0 to 1, on release): forward as SetSetting (Audio follows UI.settings.changed)
	reportBug = Signal.new(), -- (text, kind, clientErrors)   Send on Report a bug (trimmed text, "bug" | "stuck" | "idea", up to 3 client error lines): forward all three as ReportBug
	redeemCode = Signal.new(), -- (code)   Redeem in the code box (letters and digits, at most CodeMaxLength): forward as RedeemCode (F65)
	-- F72 intro: (shot)   Skip or gamepad B, once per play, with the shot showing (1 to Intro.SHOTS, 10); end the intro, call
	-- UI.intro.finish and fire IntroDone(shot, replay)
	introSkip = Signal.new(),
	-- ()   the HUD's Tutorial tile or Settings' Replay tutorial: play the intro again with UI.intro.start({ replay = true })
	introReplay = Signal.new(),
	-- F64
	usePotion = Signal.new(), -- (potionId)   Use on a potion in the potion bag: forward as UsePotion
	-- F61
	collectTips = Signal.new(), -- ()   Collect on the till's tip button in your cafe: forward as CollectTips
	-- F73
	claimQuest = Signal.new(), -- (kind, slot)   Claim on a finished quest, kind "daily" or "weekly": forward as ClaimQuest
	rerollQuest = Signal.new(), -- (kind, slot)   Swap on an unfinished quest (the free reroll): forward as RerollQuest
	claimAchievement = Signal.new(), -- (achievementId)   Claim on a met achievement: forward as ClaimAchievement
	-- F63
	answerCollector = Signal.new(), -- (accept)   Trade (true) or No thanks (false) on the Cat Collector's card: forward as AnswerCollector
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
local gateSigns: GateSigns.GateSigns? = nil
local signpost: Signpost.Signpost? = nil -- the fountain signpost's arms with tier locks (F77)
local indexBoards: IndexBoards.IndexBoards? = nil -- each area's Index Board (F50), drawn from this player's Index
local areaTitle: AreaTitle.AreaTitle? = nil
local locationMarkers: LocationMarkers.LocationMarkers? = nil -- My Cafe, area and dealer icons that fade up close
local zoneSafe: boolean? = nil -- whether the last UI.setZone was safe, nil before the first
local safeToastAt = -math.huge -- os.clock() of the last "Safe zone" toast, so an area's open edge cannot spam it
local currentZone: string? = nil -- the World.Zones name from UI.setZone, for the dusk banner (F66)
local cafeSigns: CafeSigns.CafeSigns? = nil
local worldTags: WorldTags.WorldTags? = nil
local catCard: CatCard.CatCard? = nil -- the hover card over a cat in any cafe (F75)
local actionPills: ActionPill.ActionPill? = nil -- custom prompts that are not cats (bowl, cart, manhole, Bump)
local richTipScreen: RichTip.RichTip? = nil -- the gold marker over your cafe's rich tip (UI.richTip.bind)
local tillTips: TillTipsButton.TillTipsButton? = nil -- the till's Collect for tip piles (F61, UI.richTip.bind)
local tackleBar: TackleBar.TackleBar? = nil -- the Tackle inside catching areas (UI.shove, F74)
local currentCatalog: Types.Catalog? = nil
local toasts: Toasts.Toasts? = nil
local popups: Popups.Popups? = nil
local carryMarker: WorldMarker.WorldMarker? = nil
local tutorialMarker: WorldMarker.WorldMarker? = nil
local tutorialTrail: GuideTrail.GuideTrail? = nil
local parentGui: Instance? = nil
local baitScreen: BaitBowl.BaitBowl? = nil
local baitCard: BaitCard.BaitCard? = nil
local baitView: Types.BaitView? = nil -- what is in the bowl (UI.bait.set)
local baitCat: Types.BaitCat? = nil -- the cat at the bowl (UI.bait.showReady), until it is resolved
local bowlPart: BasePart? = nil -- the player's own BaitBowl part (UI.bait.setBowl), for the range hints
local dealerScreen: Dealer.Dealer? = nil
local cartPart: BasePart? = nil -- the night dealer's cart (UI.dealer.setCart), for the range hint
local settingsScreen: Settings.Settings? = nil -- sound switches and volumes, screen shake and the like (gear in the HUD)
local tipJarScreen: TipJar.TipJar? = nil -- the playtime gifts (F47), opened from the HUD's Gifts tile
local spinScreen: SpinWheel.SpinWheel? = nil -- the Spin Wheel window (F49), opened from the plaza station's prompt
local marketScreen: FishMarket.FishMarket? = nil -- the Golden Fish Market (F53), opened from the stall's prompt
local bugReportScreen: BugReport.BugReport? = nil -- the Report a bug window, opened from Settings > Help
local codesScreen: Codes.Codes? = nil -- the code box (F65), opened by walking into the Codes Cat's circle
local potionsScreen: Potions.Potions? = nil -- the potion bag (F64), from the Potions pill, P or a HUD timer
local questsScreen: Quests.Quests? = nil -- the Quests window (F73), from the Quests pill, J or the HUD's quest line
local collectorScreen: Collector.Collector? = nil -- the Cat Collector's card and tag (F63, UI.collector.offer)
local introScreen: Intro.Intro? = nil -- the intro cutscene's bars, captions and Skip (F72, UI.intro)
local introLive = false -- the intro exists on this server: state.introSeen arrived or UI.intro.start ran
local introGlowed = false -- the Tutorial tile has had its two pulses after a first play
local tutorialButtonOn = true -- the Tutorial button setting as shown (F72)
local tutorialTarget: (BasePart | Attachment | Vector3)? = nil -- UI.tutorial.show's, put back after an intro
local tutorialLabel: string? = nil

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
-- data-model section 8: ResolveBait within 20 studs of the bowl; UseLure works from anywhere (Derek 2026-10-28)
local RESOLVE_RANGE: number = Config.BaitResolveRangeStuds
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
	local target = tutorialTarget
	if target ~= nil then
		if tutorialMarker then
			tutorialMarker:show(target :: any, tutorialLabel or "Go here", Theme.colors.gold)
		end
		if tutorialTrail then
			tutorialTrail:show(target :: any)
		end
	end
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

local function render()
	if not initialized then
		return
	end
	if not introLive and state.introSeen ~= nil then
		introLive = true
		renderTutorialButton()
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
	if gateSigns then
		gateSigns:render(state)
	end
	if signpost then
		signpost:render(state)
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
	if gateSigns then
		gateSigns:setCatalog(newCatalog)
	end
	if signpost then
		signpost:setCatalog(newCatalog)
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
	if popups then
		popups:setCatalog(newCatalog)
	end
	if catCard then
		catCard:setCatalog(newCatalog)
	end
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

	local player = Players.LocalPlayer
	local parent: Instance = config.parent or player:WaitForChild("PlayerGui")
	parentGui = parent

	local modalInstance = Modal.new(parent)
	modal = modalInstance

	-- the bowl chip and F: a cat at the bowl comes first; otherwise the food screen
	local function openBait()
		if baitCat and baitCard and not baitCard:isShowing() then
			UI.bait.showReady(baitCat :: Types.BaitCat)
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
			UI.events.introReplay:Fire()
		end,
		hideTutorialButton = function()
			tutorialButtonOn = false
			renderTutorialButton()
			if settingsScreen then
				settingsScreen:set(SettingsList.TUTORIAL_KEY, false)
			end
			UI.toast("Tutorial hidden. Replay it from Settings.", "info")
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
	})
	collection = CatCollection.new({
		claimIndexReward = function(areaId: string, milestoneId: string)
			UI.events.claimIndexReward:Fire(areaId, milestoneId)
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
	baitScreen = BaitBowl.new({
		useLure = function(lureId: string)
			UI.events.useLure:Fire(lureId)
		end,
		buyLure = function(lureId: string)
			UI.events.buyLure:Fire(lureId)
		end,
		openUpgrades = function()
			modalInstance:open("Upgrades")
		end,
		showCat = function()
			if baitCat then
				UI.bait.showReady(baitCat :: Types.BaitCat)
			end
		end,
		close = closeModal,
	})
	local baitBowlView = baitScreen :: BaitBowl.BaitBowl
	modalInstance:register("Bait", {
		frame = baitBowlView.frame,
		onOpen = function()
			baitBowlView:render(state)
		end,
	})
	baitCard = BaitCard.new(parent, {
		resolve = function(choice: Types.BaitChoice)
			UI.events.resolveBait:Fire(choice)
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
			end
			UI.settings.changed:Fire(key, value)
		end,
		close = closeModal,
		reportBug = function()
			modalInstance:open("BugReport")
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
	})
	bugReportScreen = BugReport.new({
		send = function(text: string, kind: string)
			UI.events.reportBug:Fire(text, kind, ClientErrors.recent())
		end,
		back = function()
			modalInstance:open("Settings")
		end,
		close = closeModal,
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
	})
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
			local distance = distanceTo(bowlPart)
			if baitCard then
				baitCard:setNear(if distance then distance <= RESOLVE_RANGE else nil)
			end
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
	toasts = Toasts.new(parent)
	popups = Popups.new(parent)
	introScreen = Intro.new(parent, {
		skip = function(shot: number)
			UI.events.introSkip:Fire(shot)
		end,
		ended = introEnded,
	})
	carryMarker = WorldMarker.new(parent, "CatCafeCarryMarker")
	tutorialMarker = WorldMarker.new(parent, "CatCafeTutorialMarker")
	tutorialTrail = GuideTrail.new("CatCafeTutorialTrail")
	-- signs over every gate tagged AreaGate, including gates that stream in later
	gateSigns = GateSigns.new(parent)
	-- the arms of the signpost by the fountain, one per area, locked ones dimmed with "🔒 Tier N" (F77)
	signpost = Signpost.new(parent)
	-- every area's Index Board, including boards that stream in later; its prompt opens that area's Index page
	indexBoards = IndexBoards.new(parent, {
		open = function(areaId: string)
			UI.openIndex(areaId)
		end,
	})
	-- the icon over My Cafe, fading out up close and smaller far away (the other places' went 2026-10-28)
	local markers = LocationMarkers.new(parent)
	markers:setEnabled(settingsView:value("markers")) -- the My Cafe icon switch
	locationMarkers = markers
	areaTitle = AreaTitle.new(parent)
	-- the name sign over every cafe door, rate tags over working cats and order bubbles over customers
	cafeSigns = CafeSigns.new(parent)
	worldTags = WorldTags.new()
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
	if hud then
		hud:destroy()
	end
	if baitScreen then
		baitScreen:destroy()
	end
	if baitCard then
		baitCard:destroy()
	end
	baitScreen, baitCard, baitView, baitCat, bowlPart = nil, nil, nil, nil, nil
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
	if gateSigns then
		gateSigns:destroy()
	end
	if signpost then
		signpost:destroy()
	end
	signpost = nil
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
	if toasts then
		toasts:destroy()
	end
	if popups then
		popups:destroy()
	end
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
	locationMarkers, zoneSafe = nil, nil
	circles, rankUpScreen, areasScreen, gateSigns, areaTitle = nil, nil, nil, nil, nil
	cafeSigns, worldTags, actionPills, richTipScreen, tillTips = nil, nil, nil, nil, nil
	catCard = nil
	tackleBar = nil
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

-- `extra` is optional: { stars, shiny, charmGain }. Missing stars and shiny are read from the newest copy of the
-- cat in state.cats when ProfileSync already carries it (caught in the last 30 s).
function UI.showCatFound(catId: string, isNew: boolean?, extra: Types.CatFoundExtra?)
	local def = lookupCat(catId)
	if def and popups then
		local info: Types.CatFoundExtra = {
			stars = extra and extra.stars,
			shiny = extra and extra.shiny,
			charmGain = extra and extra.charmGain,
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
		end
		popups:showCatFound(def, isNew, info)
	else
		UI.toast("Caught a cat!", "good")
	end
end

----------------------------------------------------------------------------------------------------
-- Cat levels (F75)
----------------------------------------------------------------------------------------------------

local LEVEL_UP_GATHER = 0.6 -- seconds: level ups that land together share one toast
local levelUps: { [string]: number } = {} -- uid -> the newest level, until the toast
local levelUpOrder: { string } = {}

local function toastLevelUps()
	local list: { CatCardLogic.LevelUp } = {}
	local cats: { [string]: Types.CatInstance } = state.cats or {}
	for _, uid in levelUpOrder do
		local instance = cats[uid]
		local def = lookupCat(if instance then instance.catId else nil)
		local name = CatCardLogic.names(
			if instance then instance.name else nil,
			if def then def.name else "Your cat"
		)
		table.insert(list, { name = name, level = levelUps[uid] })
	end
	table.clear(levelUpOrder)
	table.clear(levelUps)
	local text = CatCardLogic.levelUpToast(list)
	if text and toasts then
		toasts:show(text, "good", true) -- quiet: Audio plays the level up chime from the same moment
	end
end

-- From the engineer's CatLevelUp(uid, level), the owner only: "Biscuit reached level 12!". Level ups that land
-- within LEVEL_UP_GATHER share one toast ("Biscuit and 2 more cats reached a new level!"), since a room of resting
-- cats can level together. The sparkle comes from the model's Level attribute (Effects) and the chime from Audio.
function UI.catLevelUp(uid: string, level: number)
	if type(uid) ~= "string" or type(level) ~= "number" then
		return
	end
	if levelUps[uid] == nil then
		table.insert(levelUpOrder, uid)
		if #levelUpOrder == 1 then
			task.delay(LEVEL_UP_GATHER, toastLevelUps)
		end
	end
	levelUps[uid] = math.max(levelUps[uid] or 0, level)
end

function UI.showOfflineEarnings(amount: number, seconds: number)
	if popups then
		popups:showOffline(amount, seconds, function()
			UI.events.claimOffline:Fire()
		end)
	end
end

-- Rising text at a world point ("+$8"). Cheap enough for customers' coin pops.
function UI.floatText(worldPosition: Vector3, text: string, color: Color3?)
	local parent = parentGui
	if not parent then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = worldPosition
	attachment.Parent = workspace.Terrain
	local billboard: BillboardGui = Create("BillboardGui", {
		Name = "FloatText",
		Adornee = attachment,
		AlwaysOnTop = true,
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
-- is owned.
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
	local waiting = baitCat ~= nil
	if hud then
		hud:setBait(baitView, waiting)
	end
	if baitScreen then
		baitScreen:setBait(baitView, waiting)
	end
end

-- The player's own BaitBowl part. With it, Use greys out away from the bowl and the card says where to go;
-- without it the buttons stay on and the server decides.
function UI.bait.setBowl(part: BasePart?)
	bowlPart = part
end

-- What is in the bowl: { lureId, readyAt, placedAt?, night? } with the times in server os.time(), or nil when the
-- bowl is empty. night (F60) is true for food set at night, which waits half, and the countdowns show a moon. nil
-- also forgets the cat at the bowl and closes its card (the server resolved it).
function UI.bait.set(bait: Types.BaitView?)
	baitView = bait
	if bait == nil then
		baitCat = nil
		if baitCard then
			baitCard:hide()
		end
	end
	renderBait()
end

-- Opens the Bait bowl screen: the bowl's state and every food with its odds, Use and Buy.
function UI.bait.openPicker()
	if modal then
		modal:open("Bait")
	end
end

-- From BaitReady: the cat that came to the bowl, with Tame and Let go. The X hides the card; the bowl chip
-- and the screen's "See the cat" bring it back until UI.bait.hideReady or UI.bait.set(nil).
function UI.bait.showReady(cat: Types.BaitCat)
	local def = lookupCat(cat.catId)
	if not def then
		warn(("[CatCafeUI] bait cat %q is not in the catalog"):format(tostring(cat.catId)))
		return
	end
	baitCat = cat
	if modal and modal:current() == "Bait" then
		modal:close()
	end
	if baitCard then
		local lureId = if baitView then (baitView :: Types.BaitView).lureId else nil
		baitCard:show(def :: Types.CatDef, cat, if lureId then foodName(lureId) else nil)
	end
	renderBait()
end

-- The server resolved the cat (tamed or let go): close the card and forget it.
function UI.bait.hideReady()
	baitCat = nil
	if baitCard then
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
-- Potions and the Mystery gift (F64, data-model section 12b)
----------------------------------------------------------------------------------------------------

UI.potions = {}

-- From MysteryGiftResult(kind, id, count): a card with what the gift held ("Tip Potion", "2 Salmon",
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
	if modal and modal:current() == nil then
		modal:open("Codes")
	end
end

-- Closes the code box and clears its field: call it once the character is past CodesCircleRadius + 1. A window the
-- player opened meanwhile stays open.
function UI.codes.close()
	if modal and modal:current() == "Codes" then
		modal:close()
	end
end

-- From CodeResult(ok, message, prize): the answer line ("Code redeemed!" or the refusal) and, when ok, the prize as
-- little pictures. When the box was closed first (the player walked off) the answer is a toast instead.
function UI.codes.result(ok: boolean, message: string, prize: Types.IndexPrize?)
	if codesScreen then
		codesScreen:result(ok, message, prize)
	end
	if toasts and not (modal and modal:current() == "Codes") then
		toasts:show(message, if ok then "good" else "warn")
	end
end

----------------------------------------------------------------------------------------------------
-- Report a bug (docs/playtests/bug-reports.md section 1)
----------------------------------------------------------------------------------------------------

UI.bugReport = {}

-- Opens the Report a bug window (players reach it from Settings > Help > Report).
function UI.bugReport.open()
	if modal then
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
-- F61: the same plot's tip piles too. While its TipPiles is above 0 and the player stands on the plot, a green
-- "💰 Collect $120" pill floats over the till and fires events.collectTips.
-- F63: the same plot's CollectorSpot, where the Cat Collector's tag and card follow UI.collector.offer.
-- Call it again when the player gets a new plot; nil stops watching.
function UI.richTip.bind(plot: Instance?)
	if richTipScreen then
		richTipScreen:bind(plot)
	end
	if tillTips then
		tillTips:bind(plot)
	end
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
		}
	end
	hudScreen:setCarrying(resolved)
	if areasScreen then
		areasScreen:render(state, hudScreen:isCarrying())
	end
	if resolved and resolved.door then
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
	tutorialTarget, tutorialLabel = target, markerLabel
	if hud then
		hud:setTutorial(text)
	end
	if UI.intro.playing() then
		return -- the marker and trail come back when the intro ends
	end
	if tutorialMarker then
		if target ~= nil then
			tutorialMarker:show(target :: any, markerLabel or "Go here", Theme.colors.gold)
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

function UI.tutorial.hide()
	tutorialTarget, tutorialLabel = nil, nil
	if hud then
		hud:setTutorial(nil)
	end
	if tutorialMarker then
		tutorialMarker:hide()
	end
	if tutorialTrail then
		tutorialTrail:hide()
	end
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

-- A shot begins: index 1 to Intro.SHOTS (10) lights its dot, the caption pops. In the areas shot (6) call again for
-- each cut with the next title card ("THE PARK", "THE NEIGHBOURHOOD", ...); the caption stays.
function UI.intro.setShot(index: number, caption: string, titleCard: string?)
	if introScreen then
		introScreen:setShot(index, caption, titleCard)
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
-- Fast travel (F19)
----------------------------------------------------------------------------------------------------

-- The travel row (Cafe, Alley, Areas) and the Areas panel fire events.travel(destination) with "home" or an
-- AreaId. The server answers TravelResult(destination, ok, reason?); pass it here so a refused trip lifts the
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
-- nil or "Cafe" on the safe street and in the cafes, else the area ("Alley"). Walking back to safety toasts at most
-- once in SAFE_TOAST_SECONDS (walking along an area's open edge flips the zone several times). The "Safe zone" chip
-- under the tier pill went on 2026-10-28 (Derek: "no need for 'safe zone' or danger zone bubble its just clutter").
local SAFE_TOAST_SECONDS = 20
function UI.setZone(zone: string?)
	currentZone = zone
	showDusk() -- walking into an area during the dusk warning
	local safe = Wayfinding.isSafe(zone)
	local cameBack = zoneSafe == false and safe
	zoneSafe = safe
	if cameBack and os.clock() - safeToastAt >= SAFE_TOAST_SECONDS then
		safeToastAt = os.clock()
		-- quiet: Audio plays its own zone chime from Audio.setZone
		if toasts then
			toasts:show("Safe zone: no tackling here", "good", true)
		end
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
		local tierName: string? = nil
		local tiers: { Types.TierDef } = if catalog then catalog.tiers or {} else {}
		for _, def in tiers do
			if def.tier == state.tier then
				tierName = def.name
			end
		end
		card:show("home", tierName or "Your Cafe", if tierName then "Your cafe" else nil)
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

----------------------------------------------------------------------------------------------------
-- Catch prompt and closing circles
----------------------------------------------------------------------------------------------------

UI.catch = {}

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
	screen:show(circleList, windows, header, function(index: number, grade: Types.CircleGrade)
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
	if not outcome.success then
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
	if not outcome.success and toasts then
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

UI.rescue = {}

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
		warn(("[CatCafeUI] rescue %q: circle challenge without its circle"):format(rescueSpotId))
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

-- From RescueResult(rescueSpotId, hits, pawsLeft, done, success): the server's hit count, the paws left, and
-- whether the attempt is over. A success then moves the player to carry, as after a catch.
function UI.rescue.update(
	rescueSpotId: string,
	hits: number,
	pawsLeft: number?,
	done: boolean,
	success: boolean
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
		rescueBar:update(hits, pawsLeft, done, success)
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
		rarity = if type(rarity) == "string" then rarity :: any elseif def then def.rarity else nil,
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
		and baitView == nil
		and (state.upgradeLevels.lure_bowl or 0) >= 1
	then
		UI.toast(
			Theme.icons.moon .. " Night bait! Food in your bowl now brings a cat in half the time.",
			"info"
		)
	end
	watchDusk(phase, phaseEndsAt)
	if hud then
		hud:setClock({ phase = phase, phaseEndsAt = phaseEndsAt })
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
	for _, name in { "Phase", "PhaseEndsAt", "AreasOpen" } do
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
