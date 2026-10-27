--!strict
-- Cat cafe UI entry point. Public API for the engineer's client controller.
-- See docs/design/cat-cafe/ui-contract.md. The UI is a view: it renders the state it is given and raises
-- events for what the player tapped. It never changes money or ownership and never fires remotes.
--
--   local UI = require(script.Parent.UI) -- from the client controller
--   UI.init({ catalog = Catalog })
--   UI.update(partialState)
--   UI.events.buyUpgrade:Connect(function(upgradeId) Remotes.BuyUpgrade:FireServer(upgradeId) end)

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local ActionPill = require(script.Screens.ActionPill)
local AreaTitle = require(script.Screens.AreaTitle)
local Areas = require(script.Screens.Areas)
local BaitBowl = require(script.Screens.BaitBowl)
local BaitCard = require(script.Screens.BaitCard)
local CafeSigns = require(script.Screens.CafeSigns)
local CatCollection = require(script.Screens.CatCollection)
local CatchCircles = require(script.Screens.CatchCircles)
local CatchPrompt = require(script.Screens.CatchPrompt)
local Create = require(script.Components.Create)
local Dealer = require(script.Screens.Dealer)
local DecorShop = require(script.Screens.DecorShop)
local Format = require(script.Components.Format)
local GateSigns = require(script.Screens.GateSigns)
local GuideTrail = require(script.Components.GuideTrail)
local HUD = require(script.Screens.HUD)
local Modal = require(script.Components.Modal)
local Popups = require(script.Screens.Popups)
local RankUp = require(script.Screens.RankUp)
local RescueBar = require(script.Screens.RescueBar)
local RichTip = require(script.Screens.RichTip)
local Scale = require(script.Scale)
local Signal = require(script.Components.Signal)
local SlotLabels = require(script.Screens.SlotLabels)
local Sound = require(script.Components.Sound)
local Theme = require(script.Theme)
local Toasts = require(script.Screens.Toasts)
local Types = require(script.Types)
local UpgradeShop = require(script.Screens.UpgradeShop)
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
	equipLure = Signal.new(), -- (lureId)
	placeCat = Signal.new(), -- (uid, spotId)
	unplaceCat = Signal.new(), -- (uid)
	sellCat = Signal.new(), -- (uid)
	equipBest = Signal.new(), -- ()   server places the highest-rated cats on the open spots
	claimOffline = Signal.new(), -- ()
	grabBegan = Signal.new(), -- (strayId, catId)   via catch.bindProximityPrompts
	rescueBegan = Signal.new(), -- (rescueSpotId, catId)   a press on a stuck cat's prompt: forward as RescueBegin
	rescuePressed = Signal.new(), -- (rescueSpotId)   a press on the rescue bar or its catch circle: forward as RescuePress (F27)
	rescueCancelled = Signal.new(), -- (rescueSpotId)   Give up on the rescue bar: forward as RescueCancel (F27)
	screenOpened = Signal.new(), -- (name or nil)
	-- design v0.3
	catchPressed = Signal.new(), -- (strayId, index, grade)   a press on circle `index` with this device's grade: forward strayId and index as CatchPress
	rankUp = Signal.new(), -- ()   Rank up pressed on the card with every requirement met: forward as RankUp
	travel = Signal.new(), -- (destination)   "home" or an AreaId from the travel row or Areas panel: forward as Travel
	useLure = Signal.new(), -- (lureId)   Use on a food in the Bait bowl screen: forward as UseLure (F28)
	resolveBait = Signal.new(), -- (choice)   "tame" or "letgo" from the bait card: forward as ResolveBait
	buyDealerFood = Signal.new(), -- (slot, lureId)   Buy on the night dealer screen: forward both as BuyDealerFood (F32)
	claimRichTip = Signal.new(), -- ()   Collect on the rich tip marker over your cafe: forward as ClaimRichTip (F31)
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
local collection: CatCollection.CatCollection? = nil
local catch: CatchPrompt.CatchPrompt? = nil
local circles: CatchCircles.CatchCircles? = nil
local rescueBar: RescueBar.RescueBar? = nil
local rankUpScreen: RankUp.RankUp? = nil
local areasScreen: Areas.Areas? = nil
local gateSigns: GateSigns.GateSigns? = nil
local areaTitle: AreaTitle.AreaTitle? = nil
local cafeSigns: CafeSigns.CafeSigns? = nil
local worldTags: WorldTags.WorldTags? = nil
local actionPills: ActionPill.ActionPill? = nil -- custom prompts that are not cats (bowl, cart, manhole, Bump)
local richTipScreen: RichTip.RichTip? = nil -- the gold marker over your cafe's rich tip (UI.richTip.bind)
local slotLabels: SlotLabels.SlotLabels? = nil -- free and locked role slots in your own cafe
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

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
-- data-model section 8: UseLure within BaitBowlRangeStuds of the bowl, ResolveBait within 20 studs
local BOWL_RANGE: number = Config.BaitBowlRangeStuds
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

local function render()
	if not initialized then
		return
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
	if rankUpScreen then
		rankUpScreen:render(state)
	end
	if areasScreen and hud then
		areasScreen:render(state, hud:isCarrying())
	end
	if gateSigns then
		gateSigns:render(state)
	end
	if baitScreen then
		baitScreen:render(state)
	end
	if dealerScreen then
		dealerScreen:render(state)
	end
	if slotLabels then
		slotLabels:render(state)
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
	if rankUpScreen then
		rankUpScreen:setCatalog(newCatalog)
	end
	if areasScreen then
		areasScreen:setCatalog(newCatalog)
	end
	if gateSigns then
		gateSigns:setCatalog(newCatalog)
	end
	if baitScreen then
		baitScreen:setCatalog(newCatalog)
	end
	if dealerScreen then
		dealerScreen:setCatalog(newCatalog)
	end
	if slotLabels then
		slotLabels:setCatalog(newCatalog)
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

	local player = Players.LocalPlayer
	local parent: Instance = config.parent or player:WaitForChild("PlayerGui")
	parentGui = parent

	local modalInstance = Modal.new(parent)
	modal = modalInstance

	hud = HUD.new(parent, {
		openScreen = function(name: Types.ScreenName)
			modalInstance:toggle(name)
		end,
		buyLure = function(lureId: string)
			UI.events.buyLure:Fire(lureId)
		end,
		equipLure = function(lureId: string)
			UI.events.equipLure:Fire(lureId)
		end,
		travel = function(destination: string)
			UI.events.travel:Fire(destination)
		end,
		openBait = function()
			-- a cat at the bowl comes first; otherwise the food screen
			if baitCat and baitCard and not baitCard:isShowing() then
				UI.bait.showReady(baitCat :: Types.BaitCat)
			else
				modalInstance:toggle("Bait")
			end
		end,
	})
	local hudInstance = hud :: HUD.HUD

	local function closeModal()
		modalInstance:close()
	end
	upgrades = UpgradeShop.new(function(upgradeId: string)
		UI.events.buyUpgrade:Fire(upgradeId)
	end, closeModal)
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
		placeCat = function(uid: string, spotId: string)
			UI.events.placeCat:Fire(uid, spotId)
		end,
		unplaceCat = function(uid: string)
			UI.events.unplaceCat:Fire(uid)
		end,
		sellCat = function(uid: string)
			UI.events.sellCat:Fire(uid)
		end,
		equipBest = function()
			UI.events.equipBest:Fire()
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
	if config.baitBowl then
		hudInstance:setBowlMode(true)
	end
	dealerScreen = Dealer.new({
		buy = function(slot: number, lureId: string)
			UI.events.buyDealerFood:Fire(slot, lureId)
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
	-- range hints: Use needs the bowl within 12 studs, Tame or Let go within 20 (data-model section 8)
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
			if baitScreen then
				baitScreen:setNear(if distance then distance <= BOWL_RANGE else nil)
			end
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
		-- claimed or paid into the till at expiry: the server credits it either way
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
	})
	toasts = Toasts.new(parent)
	popups = Popups.new(parent)
	carryMarker = WorldMarker.new(parent, "CatCafeCarryMarker")
	tutorialMarker = WorldMarker.new(parent, "CatCafeTutorialMarker")
	tutorialTrail = GuideTrail.new("CatCafeTutorialTrail")
	-- signs over every gate tagged AreaGate, including gates that stream in later
	gateSigns = GateSigns.new(parent)
	areaTitle = AreaTitle.new(parent)
	-- the name sign over every cafe door, rate tags over working cats and order bubbles over customers
	cafeSigns = CafeSigns.new(parent)
	worldTags = WorldTags.new()
	-- "+ Barista" over a free role slot (opens the cat room) and the next locked slot per role, own cafe only
	slotLabels = SlotLabels.new(parent, {
		openCatRoom = function()
			UI.openCatRoom()
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
					modalInstance:toggle("Collection")
				elseif key == Enum.KeyCode.F then
					if hud then
						hud:togglePicker()
					end
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
	if upgrades then
		upgrades:destroy()
	end
	if decor then
		decor:destroy()
	end
	if collection then
		collection:destroy()
	end
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
	if areaTitle then
		areaTitle:destroy()
	end
	if cafeSigns then
		cafeSigns:destroy()
	end
	if worldTags then
		worldTags:destroy()
	end
	if actionPills then
		actionPills:destroy()
	end
	if richTipScreen then
		richTipScreen:destroy()
	end
	if slotLabels then
		slotLabels:destroy()
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
	circles, rankUpScreen, areasScreen, gateSigns, areaTitle = nil, nil, nil, nil, nil
	cafeSigns, worldTags, actionPills, richTipScreen, slotLabels = nil, nil, nil, nil, nil
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

-- "Book" or "Room" tab of the Collection screen, then open it.
function UI.openCatRoom()
	if collection then
		collection:showTab("Room")
	end
	UI.open("Collection")
end

function UI.setVisible(isVisible: boolean)
	visible = isVisible
	if hud then
		hud:setVisible(isVisible)
	end
	if toasts then
		toasts.screenGui.Enabled = isVisible
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
				info.shiny = newest.variant == "shiny"
			end
		end
		popups:showCatFound(def, isNew, info)
	else
		UI.toast("Caught a cat!", "good")
	end
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

-- One bowl by your door: Use puts a food in (events.useLure), the cat it rolled arrives after the wait, and
-- the bait card offers Tame or Let go (events.resolveBait). Turn on the HUD's bowl chip with
-- UI.init({ baitBowl = true }) once the server runs the bowl instead of the v0.2 lure spots.
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

-- What is in the bowl: { lureId, readyAt } with readyAt in server os.time(), or nil when the bowl is empty.
-- nil also forgets the cat at the bowl and closes its card (the server resolved it).
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

-- From DealerStock: { slots = { { lureId, cost, bought } }, restocksAt }. Send it at night start, at each window
-- change and after every BuyDealerFood, bought or not, so the rows and the countdown stay true. nil when the cart
-- leaves at dawn: the screen closes if it is open.
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
-- Rich tip (F31, data-model section 12)
----------------------------------------------------------------------------------------------------

UI.richTip = {}

-- Your own plot model: a gold marker over its RichTipAnchor whenever RichTipAmount and RichTipExpiresAt (server
-- os.time()) show a tip, with Collect firing events.claimRichTip within 12 studs. When the tip clears, claimed
-- or paid at expiry, "+$X" rises from the coin pile and a toast says so, so the server needs no Notify for it.
-- Call it again when the player gets a new plot; nil stops watching.
function UI.richTip.bind(plot: Instance?)
	if richTipScreen then
		richTipScreen:bind(plot)
	end
end

----------------------------------------------------------------------------------------------------
-- Carry indicator and tutorial hooks
----------------------------------------------------------------------------------------------------

-- info.door is the player's own cafe Door part; a marker with distance appears over it.
function UI.setCarrying(info: Types.CarryInfo?)
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
	if hud then
		hud:setTutorial(text)
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
			card:show(
				area.id,
				area.name,
				Areas.rareShare(area),
				if color then color:Lerp(Theme.colors.white, 0.35) else nil
			)
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
		patience = info.patience,
		paws = info.paws,
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

-- Net circles (F26, data-model section 10). CatchSchedule(strayId, circles, windows, pawsLeft) -> showCircles:
-- the prompt card makes way for the circles and every press fires events.catchPressed(strayId, index, grade).
-- CatchResult(strayId, grades, success, pawsLeft, charmGain) -> showGrades (v0.4): each circle shows the
-- server's grade. A catch shows "Caught!" or "PURRFECT!" with the charm it added; a miss takes a paw, closes the
-- overlay after 1 s and toasts the paws left. The card comes back while the player still has paws and is in
-- range. Call nothing else for a CatchResult; catch.fail stays for refusals.
function UI.catch.showCircles(
	strayId: string,
	circleList: { Types.CatchCircle },
	windows: Types.CatchWindows,
	pawsLeft: number?
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
			paws = pawsLeft,
			patience = info.patience,
		}
		header = built
	elseif pawsLeft ~= nil then
		local built: CatchCircles.Header = { paws = pawsLeft }
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

-- "It slipped away! 2 paws left", "It won't trust you tonight" (data-model section 10 step 5, world-and-feel 1)
local function slippedText(pawsLeft: number?): string
	if pawsLeft == nil then
		return "It slipped away! Try again"
	elseif pawsLeft <= 0 then
		return "It won't trust you tonight"
	elseif pawsLeft == 1 then
		return "It slipped away! 1 paw left"
	end
	return ("It slipped away! %d paws left"):format(pawsLeft)
end

-- Shared end of a catch. failToast is the toast after a miss (nil for none); stays brings the card back.
local function finishCatch(
	strayId: string,
	outcome: CatchCircles.Outcome,
	failToast: string?,
	stays: boolean
)
	local screen = circles
	if not screen then
		return
	end
	local current = activeInfo
	if current and current.strayId == strayId and outcome.pawsLeft ~= nil then
		current.paws = outcome.pawsLeft
	end
	if not outcome.success and failToast and toasts then
		toasts:show(failToast, "warn", true) -- quiet: the hiss is the miss sound
	end
	screen:showResult(outcome, function()
		if hud then
			hud:setCatching(false)
		end
		local info = activeInfo
		local card = catch
		if
			not outcome.success
			and stays
			and activePrompt ~= nil
			and info ~= nil
			and card ~= nil
		then
			card:show(info)
		end
	end)
end

-- v0.4 CatchResult. grades run up to and including the first Miss; pawsLeft is nil when this player cannot
-- run out on the stray; charmGain is 0 on a miss.
function UI.catch.showGrades(
	strayId: string,
	grades: { Types.CircleGrade },
	success: boolean,
	pawsLeft: number?,
	charmGain: number?
)
	finishCatch(strayId, {
		grades = grades,
		success = success,
		pawsLeft = pawsLeft,
		charmGain = charmGain,
	}, slippedText(pawsLeft), pawsLeft ~= 0)
end

-- v0.3 CatchResult(strayId, scores, chance, success, stayed), kept until the controller calls showGrades.
-- Scores of 1, 0.5 and 0 are Perfect, Good and Miss. No toast here: until the switch the server sends the
-- slipped away toast itself (reviewer S39), and showGrades takes it over.
function UI.catch.showResult(
	strayId: string,
	scores: { number },
	_chance: number,
	success: boolean,
	stayed: boolean?
)
	local info = activeInfo
	local rarity: string? = if info and info.strayId == strayId then info.rarity else nil
	local stays = if stayed ~= nil then stayed else rarity == "Common"
	local grades: { Types.CircleGrade } = {}
	for _, score in scores do
		local grade: Types.CircleGrade = if score >= 1
			then "perfect"
			elseif score >= 0.5 then "good"
			else "miss"
		table.insert(grades, grade)
	end
	finishCatch(strayId, {
		grades = grades,
		success = success,
		pawsLeft = nil,
		charmGain = nil,
	}, nil, stays)
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
	local shiny = promptAttribute(prompt, "Shiny")
	-- v0.4: Patience is the stray's full paw count; Paws_<UserId> appears once this player has missed (nil = full)
	local patience = promptAttribute(prompt, "Patience")
	local player = Players.LocalPlayer
	local paws = if player then promptAttribute(prompt, "Paws_" .. tostring(player.UserId)) else nil
	return {
		patience = if type(patience) == "number" then patience else nil,
		paws = if type(paws) == "number"
			then paws
			elseif type(patience) == "number" then patience
			else nil,
		press = prompt.HoldDuration <= 0,
		shiny = shiny == true,
		kind = (if rescue == true then "rescue" else "swing") :: Types.PromptKind,
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
-- (on the prompt, its model, or its parent). Every cat prompt has HoldDuration 0: one press fires
-- events.grabBegan (a stray) or events.rescueBegan (a stuck cat, Rescue = true) and the server answers with
-- catch.showCircles, UI.rescue.show or catch.fail. A press while the circles or the rescue bar are up is theirs,
-- so it never asks again.
-- Any other Style = Custom prompt (no CatId) gets an action pill (Screens/ActionPill) and raises no event: the
-- game handles its Triggered as it would a default prompt's.
function UI.catch.bindProximityPrompts()
	if #promptConnections > 0 or not catch then
		return
	end
	local catchScreen = catch :: CatchPrompt.CatchPrompt

	local function onShown(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
		if isActionPrompt(prompt) then
			if actionPills then
				actionPills:show(prompt, inputType)
			end
			return
		end
		if not isCatPrompt(prompt) then
			return
		end
		activePrompt = prompt
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
			UI.catch.hide()
		end)
	)
	table.insert(
		promptConnections,
		ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt: ProximityPrompt)
			if actionPills and actionPills:isShown(prompt) then
				actionPills:holdBegan(prompt)
			end
		end)
	)
	table.insert(
		promptConnections,
		ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt: ProximityPrompt)
			if actionPills and actionPills:isShown(prompt) then
				actionPills:holdEnded(prompt)
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
			catchScreen:waiting()
			if info and info.kind == "rescue" then
				UI.events.rescueBegan:Fire(info.rescueSpotId, info.catId)
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
	activePrompt = nil
end

----------------------------------------------------------------------------------------------------
-- Day and night clock (HUD chip, F20)
----------------------------------------------------------------------------------------------------

UI.clock = {}

local clockConnections: { RBXScriptConnection } = {}

-- phaseEndsAt is server os.time() seconds (the Clock folder's PhaseEndsAt). The chip counts down
-- against Workspace:GetServerTimeNow(), so nothing here reads the device clock.
function UI.clock.set(phase: Types.ClockPhase, phaseEndsAt: number)
	if hud then
		hud:setClock({ phase = phase, phaseEndsAt = phaseEndsAt })
	end
	if dealerScreen then
		dealerScreen:setNight(phase == "night")
	end
end

function UI.clock.clear()
	if hud then
		hud:setClock(nil)
	end
	if dealerScreen then
		dealerScreen:setNight(nil)
	end
end

-- Reads Phase and PhaseEndsAt from the Clock folder (ReplicatedStorage.Clock) and follows changes.
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
	end
	table.insert(clockConnections, clock:GetAttributeChangedSignal("Phase"):Connect(read))
	table.insert(clockConnections, clock:GetAttributeChangedSignal("PhaseEndsAt"):Connect(read))
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
