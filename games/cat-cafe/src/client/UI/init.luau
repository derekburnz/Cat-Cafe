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

local CatCollection = require(script.Screens.CatCollection)
local CatchPrompt = require(script.Screens.CatchPrompt)
local Create = require(script.Components.Create)
local DecorShop = require(script.Screens.DecorShop)
local Format = require(script.Components.Format)
local HUD = require(script.Screens.HUD)
local Modal = require(script.Components.Modal)
local Popups = require(script.Screens.Popups)
local Scale = require(script.Scale)
local Signal = require(script.Components.Signal)
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
	grabEnded = Signal.new(), -- (strayId, ringHint, catId)  hint only: the server scores the hold time
	screenOpened = Signal.new(), -- (name or nil)
}

local state: Types.PlayerState = {
	money = 0,
	incomePerSecond = 0,
	cafeLevel = 1,
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
end

-- Fill in fields the engineer may not send: cafeLevel and tables from upgrade levels, catsOwned from cats.
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
		local cafeLevel: number? = levels.cafe_level
		if partial.cafeLevel == nil and cafeLevel ~= nil then
			state.cafeLevel = cafeLevel
		end
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
	})

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
	modalInstance.changed:Connect(function(name: string?)
		UI.events.screenOpened:Fire(name)
	end)

	catch = CatchPrompt.new(parent)
	toasts = Toasts.new(parent)
	popups = Popups.new(parent)
	carryMarker = WorldMarker.new(parent, "CatCafeCarryMarker")
	tutorialMarker = WorldMarker.new(parent, "CatCafeTutorialMarker")

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
	Scale.stop()
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
-- Catch prompt and timing ring
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
	}
	if catch then
		catch:show(activeInfo :: Types.CatchInfo)
	end
end

function UI.catch.startRing(config: Types.RingConfig?)
	if catch then
		catch:startRing(config)
	end
end

function UI.catch.stopRing(): Types.RingResult
	if catch then
		return catch:stopRing()
	end
	return "miss"
end

-- The hold ran its full length with no release: miss flash, send nothing, wait for the server.
function UI.catch.expire()
	if catch then
		catch:expire()
	end
end

function UI.catch.setProgress(alpha: number)
	if catch then
		catch:setProgress(alpha)
	end
end

-- retry = true keeps the prompt open (Commons, lured strays). Otherwise it flashes and hides (the cat fled).
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
	return {
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

local function finishHold(result: Types.RingResult)
	if not holdOpen then
		return
	end
	holdOpen = false
	local info = activeInfo
	UI.events.grabEnded:Fire(
		if info then info.strayId else nil,
		result,
		if info then info.catId else nil
	)
end

-- Drives the prompt UI from every ProximityPrompt with Style = Custom and a CatId attribute
-- (on the prompt, its model, or its parent). Fires events.grabBegan on hold begin and events.grabEnded
-- on release with the ring hint. A hold that runs its full length fires nothing (data-model section 10):
-- the server resolves it as a ring miss and the controller then calls catch.fail or showCatFound.
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
				finishHold(catchScreen:stopRing())
			end
			activePrompt = nil
			UI.catch.hide()
		end)
	)
	table.insert(
		promptConnections,
		ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt: ProximityPrompt)
			if prompt ~= activePrompt then
				return
			end
			holdOpen = true
			holdSerial += 1
			catchScreen:startRing({ duration = prompt.HoldDuration })
			local info = activeInfo
			UI.events.grabBegan:Fire(
				if info then info.strayId else nil,
				if info then info.catId else nil
			)
		end)
	)
	table.insert(
		promptConnections,
		ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt: ProximityPrompt)
			if prompt ~= activePrompt then
				return
			end
			-- A full hold fires PromptTriggered and PromptButtonHoldEnded in the same frame, in either
			-- order (reviewer S12). Decide one frame later: if PromptTriggered closed the hold, or the
			-- ring already collapsed, the hold ran its full length and nothing is sent.
			local serial = holdSerial
			task.defer(function()
				if not holdOpen or holdSerial ~= serial then
					return
				end
				if not catchScreen:isRinging() then
					holdOpen = false
					catchScreen:expire()
					return
				end
				finishHold(catchScreen:stopRing())
			end)
		end)
	)
	table.insert(
		promptConnections,
		ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
			-- the hold ran the full duration with no release. Send no GrabEnd: the server would score it
			-- as a 1.5 s release. Close the hold, flash the miss and wait for the server's result.
			if prompt ~= activePrompt then
				return
			end
			holdOpen = false
			catchScreen:expire()
		end)
	)
	-- mobile GRAB button drives the real prompt so the server sees an ordinary hold
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
-- Demo
----------------------------------------------------------------------------------------------------

-- Runs the UI with a fake catalog and a pretend server so it can be seen in Studio before the
-- real client controller exists. Returns a stop function. Not for production.
function UI.demo(): () -> ()
	local Demo = require(script.Demo) :: any
	return Demo.run(UI)
end

return UI
