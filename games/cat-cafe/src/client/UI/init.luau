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
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Areas = require(script.Screens.Areas)
local CatCollection = require(script.Screens.CatCollection)
local CatchCircles = require(script.Screens.CatchCircles)
local CatchPrompt = require(script.Screens.CatchPrompt)
local Create = require(script.Components.Create)
local DecorShop = require(script.Screens.DecorShop)
local Format = require(script.Components.Format)
local GateSigns = require(script.Screens.GateSigns)
local HUD = require(script.Screens.HUD)
local Modal = require(script.Components.Modal)
local Popups = require(script.Screens.Popups)
local RankUp = require(script.Screens.RankUp)
local Scale = require(script.Scale)
local Signal = require(script.Components.Signal)
local Sound = require(script.Components.Sound)
local Theme = require(script.Theme)
local Toasts = require(script.Screens.Toasts)
local Types = require(script.Types)
local UpgradeShop = require(script.Screens.UpgradeShop)
local WorldMarker = require(script.Components.WorldMarker)

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
	rescueBegan = Signal.new(), -- (rescueSpotId, catId)   hold began on a prompt with Rescue = true
	rescueEnded = Signal.new(), -- (rescueSpotId, catId, completed)  completed after the full hold: send RescueEnd
	screenOpened = Signal.new(), -- (name or nil)
	-- design v0.3
	catchPressed = Signal.new(), -- (strayId, index)   a press on circle `index`: forward as CatchPress
	rankUp = Signal.new(), -- ()   Rank up pressed on the card with every requirement met: forward as RankUp
	travel = Signal.new(), -- (destination)   "home" or an AreaId from the travel row or Areas panel: forward as Travel
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
local rankUpScreen: RankUp.RankUp? = nil
local areasScreen: Areas.Areas? = nil
local gateSigns: GateSigns.GateSigns? = nil
local toasts: Toasts.Toasts? = nil
local popups: Popups.Popups? = nil
local carryMarker: WorldMarker.WorldMarker? = nil
local tutorialMarker: WorldMarker.WorldMarker? = nil
local parentGui: Instance? = nil

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
end

local function setCatalog(newCatalog: Types.Catalog)
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
	modalInstance.changed:Connect(function(name: string?)
		hudInstance:screenOpened(name)
		UI.events.screenOpened:Fire(name)
	end)

	catch = CatchPrompt.new(parent)
	circles = CatchCircles.new(parent)
	toasts = Toasts.new(parent)
	popups = Popups.new(parent)
	carryMarker = WorldMarker.new(parent, "CatCafeCarryMarker")
	tutorialMarker = WorldMarker.new(parent, "CatCafeTutorialMarker")
	-- signs over every gate tagged AreaGate, including gates that stream in later
	gateSigns = GateSigns.new(parent)

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
	if rankUpScreen then
		rankUpScreen:destroy()
	end
	if areasScreen then
		areasScreen:destroy()
	end
	if gateSigns then
		gateSigns:destroy()
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
	hud, upgrades, decor, collection, modal, catch, toasts, popups =
		nil, nil, nil, nil, nil, nil, nil, nil
	carryMarker, tutorialMarker = nil, nil
	circles, rankUpScreen, areasScreen, gateSigns = nil, nil, nil, nil
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

-- Server-wide announcement (Epic and Legendary catches). Gold toast.
function UI.announce(text: string)
	UI.toast(text, "announce")
end

function UI.showCatFound(catId: string, isNew: boolean?)
	local def = lookupCat(catId)
	if def and popups then
		popups:showCatFound(def, isNew)
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

-- One line at the bottom of the screen and, if a target is given, a marker in the world.
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
end

function UI.tutorial.hide()
	if hud then
		hud:setTutorial(nil)
	end
	if tutorialMarker then
		tutorialMarker:hide()
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
end

----------------------------------------------------------------------------------------------------
-- Catch prompt, closing circles and the rescue hold
----------------------------------------------------------------------------------------------------

UI.catch = {}

local activePrompt: ProximityPrompt? = nil
local activeInfo: Types.CatchInfo? = nil
local holdOpen = false
local holdSerial = 0 -- bumps on every hold begin so a deferred hold end cannot act on a later hold
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
	}
	if catch then
		catch:show(activeInfo :: Types.CatchInfo)
	end
end

-- Rescue prompt (F21): a bar fills over the hold. bindProximityPrompts drives this itself for prompts whose
-- model has Rescue = true and a hold duration; the rescue minigames replace it.
function UI.catch.startRescue(duration: number?)
	if catch then
		catch:startRescue(duration)
	end
end

function UI.catch.stopRescue(completed: boolean)
	if catch then
		catch:stopRescue(completed)
	end
end

-- retry = true keeps the prompt open (Commons, lured strays, a rescue turned down for now). Otherwise it
-- flashes and hides (the cat fled). A fail that lands while a rescue hold is still down (the server turned
-- down RescueBegin) closes that hold: the server holds no lock, so its release or full length sends nothing
-- and the card keeps the server's reason instead of "Rescued!". Hold again to retry.
function UI.catch.fail(reason: string?, retry: boolean?)
	holdOpen = false
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

-- v0.3 net (F26, data-model section 10). CatchSchedule(strayId, circles, windows) -> showCircles: the
-- prompt card makes way for the circles and every press fires events.catchPressed(strayId, index).
-- CatchResult(strayId, scores, chance, success, stayed) -> showResult: each circle shows the server's grade,
-- then the chance and the outcome, and the overlay closes after 1.6 s. A stray that stayed gets its card back
-- while the player is still in range. Call nothing else for a CatchResult; catch.fail stays for refusals.
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
	holdOpen = false
	if catch then
		catch:hide() -- activePrompt and activeInfo stay so the card can come back
	end
	screen:show(circleList, windows, header, function(index: number)
		UI.events.catchPressed:Fire(strayId, index)
	end)
end

-- stayed is the server's word on whether a failed catch left the stray in place (reviewer N39: a lured or
-- dropped stray can stay whatever its rarity). Without it, only a Common stays (data-model section 2).
function UI.catch.showResult(
	strayId: string,
	scores: { number },
	chance: number,
	success: boolean,
	stayed: boolean?
)
	local screen = circles
	if not screen then
		return
	end
	local info = activeInfo
	local rarity: string? = if info and info.strayId == strayId then info.rarity else nil
	local stays = if stayed ~= nil then stayed else rarity == "Common"
	screen:showResult(
		scores,
		chance,
		success,
		if stays then "Missed, try again" else "It got away",
		function()
			local current = activeInfo
			local card = catch
			if not success and stays and activePrompt ~= nil and current ~= nil and card ~= nil then
				card:show(current)
			end
		end
	)
end

function UI.catch.hideCircles()
	if circles then
		circles:hide()
	end
end

function UI.catch.circlesActive(): boolean
	return circles ~= nil and (circles :: CatchCircles.CatchCircles):isActive()
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
	return {
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

local function activeIsRescue(): boolean
	local info = activeInfo
	return info ~= nil and info.kind == "rescue"
end

local function finishRescue(completed: boolean)
	if not holdOpen then
		return
	end
	holdOpen = false
	local info = activeInfo
	local screen = catch
	if screen then
		screen:stopRescue(completed)
	end
	UI.events.rescueEnded:Fire(
		if info then info.rescueSpotId else nil,
		if info then info.catId else nil,
		completed
	)
end

-- Drives the prompt UI from every ProximityPrompt with Style = Custom and a CatId attribute
-- (on the prompt, its model, or its parent). A stray's prompt has HoldDuration 0: one press fires
-- events.grabBegan and the server answers with catch.showCircles or catch.fail. A rescue prompt with a hold
-- fires events.rescueBegan on hold begin and events.rescueEnded on release or after the full hold.
function UI.catch.bindProximityPrompts()
	if #promptConnections > 0 or not catch then
		return
	end
	local catchScreen = catch :: CatchPrompt.CatchPrompt

	table.insert(
		promptConnections,
		ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
			if not isCatPrompt(prompt) then
				return
			end
			activePrompt = prompt
			holdOpen = false
			UI.catch.show(infoFromPrompt(prompt))
		end)
	)
	table.insert(
		promptConnections,
		ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
			if prompt ~= activePrompt then
				return
			end
			if holdOpen then
				finishRescue(false)
			end
			activePrompt = nil
			UI.catch.hide()
		end)
	)
	table.insert(
		promptConnections,
		ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt: ProximityPrompt)
			-- only the v0.2 rescue still holds; a press prompt is handled in PromptTriggered
			local info = activeInfo
			if
				prompt ~= activePrompt
				or prompt.HoldDuration <= 0
				or not info
				or info.kind ~= "rescue"
			then
				return
			end
			holdOpen = true
			holdSerial += 1
			catchScreen:startRescue(prompt.HoldDuration)
			UI.events.rescueBegan:Fire(info.rescueSpotId, info.catId)
		end)
	)
	table.insert(
		promptConnections,
		ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt: ProximityPrompt)
			if prompt ~= activePrompt then
				return
			end
			-- A full hold fires PromptTriggered and PromptButtonHoldEnded in the same frame, in either
			-- order (reviewer S12). Decide one frame later: if PromptTriggered closed the hold, the hold ran
			-- its full length and was already sent.
			local serial = holdSerial
			task.defer(function()
				if not holdOpen or holdSerial ~= serial or not activeIsRescue() then
					return
				end
				-- released before the hold ran out: the bar resets, there is no fail state
				finishRescue(false)
			end)
		end)
	)
	table.insert(
		promptConnections,
		ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
			if prompt ~= activePrompt then
				return
			end
			if prompt.HoldDuration <= 0 then
				-- v0.3 press prompt: one press asks the server to start. GrabBegin answers with the circles
				-- (catch.showCircles), RescueBegin with the minigame, a refusal with catch.fail.
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
				return
			end
			if activeIsRescue() then
				-- the rescue hold ran its full length: the controller sends RescueEnd, the server moves
				-- the player to carry and the controller then calls showCatFound or hide
				finishRescue(true)
			end
		end)
	)
	-- the mobile CATCH button drives the real prompt, a press or the rescue hold, so nothing changes server side
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
	holdOpen = false
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
end

function UI.clock.clear()
	if hud then
		hud:setClock(nil)
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
