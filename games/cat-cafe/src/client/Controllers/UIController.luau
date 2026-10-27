--!strict
-- Feeds the UI (src/client/UI, ui-designer's) with catalog and state, forwards its intents to remotes,
-- predicts the coin counter between syncs, and drives the catch circles, the rescue prompt, the clock chip, the
-- carry marker and tutorial hints.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Audio = require(script.Parent.Parent.Audio)
local Catalog = require(Shared:WaitForChild("Catalog"))
local Moments = require(script.Parent.Parent.Moments)
local Net = require(script.Parent.Parent.Net)
local Types = require(Shared:WaitForChild("Types"))
local UI = require(script.Parent.Parent.UI)
local UITypes = require(script.Parent.Parent.UI.Types)

local UIController = {}

local player = Players.LocalPlayer
local state: Types.PlayerState? = nil
local predictedMoney = 0
local lastCarrying: string? = nil
local lastPushedMoney = -1
local lastTier: number? = nil
local pendingCharmGain = 0 -- the last catch's Purrfect bonus, shown on the cat reveal at check-in

UIController.state = nil :: Types.PlayerState?

local function ownPlot(): Model?
	if state == nil or state.plotIndex == 0 then
		return nil
	end
	local world = Workspace:FindFirstChild("World")
	local plots = if world ~= nil then world:FindFirstChild("Plots") else nil
	local plot = if plots ~= nil then plots:FindFirstChild("Plot_" .. state.plotIndex) else nil
	return if plot ~= nil and plot:IsA("Model") then plot :: Model else nil
end

function UIController.ownDoor(): BasePart?
	local plot = ownPlot()
	local door = if plot ~= nil then plot:FindFirstChild("Door") else nil
	return if door ~= nil and door:IsA("BasePart") then door :: BasePart else nil
end

-- The own cafe's back door: check-in works there too (layout v2).
function UIController.ownBackDoor(): BasePart?
	local plot = ownPlot()
	local door = if plot ~= nil then plot:FindFirstChild("BackDoorZone") else nil
	return if door ~= nil and door:IsA("BasePart") then door :: BasePart else nil
end

-- The stray model with this id, for its rarity, or nil once it has gone.
local function strayModel(strayId: string): Instance?
	local world = Workspace:FindFirstChild("World")
	local strays = if world ~= nil then world:FindFirstChild("Strays") else nil
	if strays == nil then
		return nil
	end
	for _, model in strays:GetChildren() do
		if model:GetAttribute("StrayId") == strayId then
			return model
		end
	end
	return nil
end

-- The lane spawn point right behind the own cafe, where the tutorial stray waits (alley point 2p - 1 for plot p).
local function tutorialStrayPoint(): BasePart?
	if state == nil or state.plotIndex == 0 then
		return nil
	end
	local world = Workspace:FindFirstChild("World")
	local alley = if world ~= nil then world:FindFirstChild("Alley") else nil
	local points = if alley ~= nil then alley:FindFirstChild("SpawnPoints") else nil
	local point = if points ~= nil
		then points:FindFirstChild("alley_" .. (2 * state.plotIndex - 1))
		else nil
	return if point ~= nil and point:IsA("BasePart") then point :: BasePart else nil
end

local function hasRestingCatAndFreeSpot(s: Types.PlayerState): boolean
	local resting = false
	local used: { [string]: boolean } = {}
	for _, instance in s.cats do
		if instance.spotId == nil then
			resting = true
		else
			used[instance.spotId :: string] = true
		end
	end
	if not resting then
		return false
	end
	for _, spot in Catalog.spots do
		if s.tier >= spot.tier and not used[spot.id] then
			return true
		end
	end
	return false
end

local function refreshTutorial(s: Types.PlayerState)
	if s.carrying ~= nil then
		UI.tutorial.hide()
		return
	end
	if s.tutorialStep < 2 then
		UI.tutorial.show(
			"Go out your back door to the alley and press E on a cat, then tap as each circle closes",
			tutorialStrayPoint(),
			"Alley"
		)
	elseif s.tutorialStep == 2 then
		if hasRestingCatAndFreeSpot(s) then
			UI.tutorial.show("Open the Collection (C) and give your new cat a role")
		else
			UI.tutorial.show("Catch more cats in the alley, or buy a table in Upgrades (U)")
		end
	elseif s.tutorialStep == 3 then
		UI.tutorial.show("Buy your first table in Upgrades (U): more tips from every cat")
	else
		UI.tutorial.hide()
	end
end

-- Something bought since the last sync: an upgrade level, a decor item or a lure count went up.
local function boughtSomething(old: Types.PlayerState, new: Types.PlayerState): boolean
	for id, level in new.upgradeLevels do
		if level > (old.upgradeLevels[id] or 0) then
			return true
		end
	end
	for id, owned in new.decorOwned do
		if owned and not old.decorOwned[id] then
			return true
		end
	end
	for id, count in new.lures do
		if count > (old.lures[id] or 0) then
			return true
		end
	end
	return false
end

local function applyState(s: Types.PlayerState)
	local previous = state
	if previous ~= nil and boughtSomething(previous, s) then
		Moments.Purchase:Fire()
	end
	state = s
	UIController.state = s
	predictedMoney = s.money
	lastPushedMoney = s.money
	UI.update({
		money = s.money,
		incomePerSecond = s.incomePerSecond,
		tier = s.tier,
		cafeProgress = s.cafeProgress,
		cafeProgressText = s.cafeProgressText,
		tables = s.tables,
		catsOwned = s.catsOwned,
		upgradeLevels = s.upgradeLevels,
		decorOwned = s.decorOwned,
		decorPlaced = s.decorPlaced,
		lures = s.lures,
		equippedLure = s.equippedLure,
		cats = s.cats :: any, -- the UI's CatInstance has optional fields; table props are invariant in Luau
		collection = s.collection,
		shinyCollection = s.shinyCollection,
		carrying = s.carrying,
		tutorialStep = s.tutorialStep,
	})
	-- Music and sound toggles arrive only in ProfileSync; the purr follows the server's carry state.
	Audio.applySettings(s.settings)
	Audio.setCarrying(s.carrying ~= nil)
	if lastTier ~= nil and s.tier > (lastTier :: number) then
		Moments.RankUp:Fire(s.tier)
	end
	lastTier = s.tier
	if s.carrying ~= lastCarrying then
		lastCarrying = s.carrying
		if s.carrying ~= nil then
			UI.setCarrying({ catId = s.carrying, door = UIController.ownDoor() })
		else
			UI.setCarrying(nil)
		end
	end
	refreshTutorial(s)
end

local function wireIntents()
	UI.events.buyUpgrade:Connect(function(upgradeId: string)
		Net.fire("BuyUpgrade", upgradeId)
	end)
	UI.events.buyDecor:Connect(function(decorId: string)
		Net.fire("BuyDecor", decorId)
	end)
	UI.events.toggleDecor:Connect(function(decorId: string, placed: boolean)
		Net.fire("ToggleDecor", decorId, placed)
	end)
	UI.events.buyLure:Connect(function(lureId: string)
		Net.fire("BuyLure", lureId)
	end)
	UI.events.equipLure:Connect(function(lureId: string?)
		Net.fire("EquipLure", lureId)
	end)
	UI.events.placeCat:Connect(function(uid: string, spotId: string)
		Net.fire("PlaceCat", uid, spotId)
	end)
	UI.events.unplaceCat:Connect(function(uid: string)
		Net.fire("UnplaceCat", uid)
	end)
	UI.events.sellCat:Connect(function(uid: string)
		Net.fire("SellCat", uid)
	end)
	-- Equip best button on the cat room tab (UI thread). Looked up loosely so an older UI build without the
	-- signal still loads; the server validates the request like any other.
	local equipBest = (UI.events :: any).equipBest
	if equipBest ~= nil then
		equipBest:Connect(function()
			Net.fire("EquipBest")
		end)
	end
	UI.events.rankUp:Connect(function()
		Net.fire("RankUp")
	end)
	UI.events.claimOffline:Connect(function()
		Net.fire("ClaimOffline")
	end)
	-- The night dealer (F32): the server answers every buy with DealerStock, bought or refused.
	UI.events.buyDealerFood:Connect(function(slot: number, lureId: string)
		Net.fire("BuyDealerFood", slot, lureId)
	end)
	-- Fast travel (F19): the travel row and the Areas panel; the server answers every request with TravelResult.
	UI.events.travel:Connect(function(destination: string)
		Net.fire("Travel", destination)
	end)
	-- The net (data-model section 10): one press on the prompt asks for the circles. The server answers with
	-- CatchSchedule (or a GrabResult refusal); each press on a circle sends only its index, since the server
	-- stamps the time itself.
	UI.events.grabBegan:Connect(function(strayId: string?)
		if strayId ~= nil then
			Net.fire("GrabBegin", strayId)
		end
	end)
	-- Each press is heard the instant it lands (sound list 5.1): the swing, then this device's grade estimate.
	-- The server's own grades come back in CatchResult.
	UI.events.catchPressed:Connect(
		function(strayId: string, index: number, grade: Types.CircleGrade?)
			Net.fire("CatchPress", strayId, index)
			Moments.NetSwing:Fire(index)
			if grade ~= nil then
				Moments.CircleGrade:Fire(index, grade)
			end
		end
	)
	-- Rescue (data-model section 10): RescueBegin when the 4 s hold starts, RescueEnd only when it ran its full
	-- length. An early release sends nothing; the server's lock lapses after RescueLockSeconds. The server
	-- answers both with GrabResult, keyed by the rescue spot id.
	UI.events.rescueBegan:Connect(function(rescueSpotId: string?, _catId: string?)
		if rescueSpotId ~= nil then
			Net.fire("RescueBegin", rescueSpotId)
		end
	end)
	UI.events.rescueEnded:Connect(
		function(rescueSpotId: string?, _catId: string?, completed: boolean)
			if rescueSpotId ~= nil and completed then
				Net.fire("RescueEnd", rescueSpotId)
			end
		end
	)
end

-- The night dealer's cart (F32): the UI's range hint follows it and its prompt opens the dealer screen. The cart
-- is the server's, tagged DealerCart, there from night start to day start.
local function bindDealerCart()
	-- `cue` is false for a cart already out when this client starts, so a player who joins at night does not
	-- hear it arrive (reviewer note on #110).
	local function arrived(instance: Instance, cue: boolean)
		if not instance:IsA("Model") then
			return
		end
		local model = instance :: Model
		local found = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
		UI.dealer.setCart(if found ~= nil and found:IsA("BasePart") then found :: BasePart else nil)
		local prompt = model:FindFirstChild("DealerPrompt", true)
		if prompt ~= nil and prompt:IsA("ProximityPrompt") then
			(prompt :: ProximityPrompt).Triggered:Connect(function()
				UI.dealer.open()
			end)
		end
		if cue then
			Moments.DealerArrive:Fire()
		end
	end
	CollectionService:GetInstanceAddedSignal("DealerCart"):Connect(function(instance)
		arrived(instance, true)
	end)
	CollectionService:GetInstanceRemovedSignal("DealerCart"):Connect(function()
		UI.dealer.setCart(nil)
		Moments.DealerLeave:Fire()
	end)
	for _, instance in CollectionService:GetTagged("DealerCart") do
		arrived(instance, false)
	end
end

local function wireServerEvents()
	Net.on("ProfileSync", function(s: Types.PlayerState)
		applyState(s)
	end)
	Net.on("Toast", function(text: string, kind: Types.ToastKind?)
		UI.toast(text, kind)
	end)
	Net.on("Announce", function(text: string, rarity: string?)
		UI.announce(text, rarity)
		Moments.Announce:Fire(text, rarity)
	end)
	Net.on("CatCaught", function(catId: string, isNew: boolean)
		local extra: UITypes.CatFoundExtra? = if pendingCharmGain > 0
			then { charmGain = pendingCharmGain }
			else nil
		pendingCharmGain = 0
		UI.showCatFound(catId, isNew, extra)
		-- CatCaught comes only from a check-in, so a bump that drops the carried cat plays no check-in sound.
		Moments.CheckIn:Fire()
		Moments.CatFound:Fire(catId, isNew)
	end)
	Net.on("DealerStock", function(stock: Types.DealerStock?)
		UI.dealer.setStock(stock)
	end)
	Net.on("PlotOpened", function(position: Vector3, plotIndex: number)
		Moments.PlotOpened:Fire(position, plotIndex)
	end)
	Net.on("TravelResult", function(destination: string, ok: boolean, reason: string?)
		UI.travel.result(destination, ok, reason)
	end)
	Net.on("OfflineEarnings", function(amount: number, seconds: number)
		UI.showOfflineEarnings(amount, seconds)
	end)
	Net.on(
		"CatchSchedule",
		function(
			strayId: string,
			circles: { Types.CatchCircle },
			windows: Types.CatchWindows,
			pawsLeft: number?
		)
			UI.catch.showCircles(strayId, circles, windows, pawsLeft)
			Moments.CatchStart:Fire(strayId)
		end
	)
	-- v0.4 (data-model section 10 step 5): grades up to and including the first Miss, the paws left (nil when this
	-- player cannot run out) and the Purrfect charm bonus. The HUD shows the grades, the paw row and the
	-- "slipped away" line.
	Net.on(
		"CatchResult",
		function(
			strayId: string,
			grades: { Types.CircleGrade },
			success: boolean,
			pawsLeft: number?,
			charmGain: number
		)
			local allPerfect = #grades > 0
			for _, grade in grades do
				allPerfect = allPerfect and grade == "perfect"
			end
			UI.catch.showGrades(strayId, grades, success, pawsLeft, charmGain)
			if success then
				local model = strayModel(strayId)
				local rarity = if model ~= nil then model:GetAttribute("Rarity") else nil
				Moments.CatchSuccess:Fire(strayId, if type(rarity) == "string" then rarity else nil)
				pendingCharmGain = charmGain
				if allPerfect and charmGain > 0 then
					Moments.Purrfect:Fire(charmGain)
				end
			else
				Moments.CatchFail:Fire(strayId)
				if pawsLeft ~= nil then
					Moments.PawLost:Fire(pawsLeft)
				end
			end
		end
	)
	Net.on("GrabResult", function(id: string, ok: boolean, reason: string, retry: boolean)
		-- Strays and rescue spots share this event and the card. A late answer for a target the card has moved
		-- on from (a stray's auto-resolve landing after the next hold began) is dropped (reviewer N21).
		local prompt = UI.catch.getActivePrompt()
		if prompt ~= nil then
			local model = prompt:FindFirstAncestorOfClass("Model")
			local target = prompt:GetAttribute("StrayId") or prompt:GetAttribute("RescueSpotId")
			if target == nil and model ~= nil then
				target = model:GetAttribute("StrayId") or model:GetAttribute("RescueSpotId")
			end
			if target ~= nil and target ~= id then
				return
			end
		end
		if ok then
			UI.catch.hide()
		else
			UI.catch.fail(reason, retry)
		end
	end)
end

-- Coins tick up locally between syncs; every ProfileSync snaps the value back to the server's.
local function startPrediction()
	local accumulated = 0
	RunService.Heartbeat:Connect(function(dt: number)
		local s = state
		if s == nil then
			return
		end
		predictedMoney += s.incomePerSecond * dt
		accumulated += dt
		if accumulated >= 0.2 then
			accumulated = 0
			local shown = math.floor(predictedMoney)
			if shown ~= lastPushedMoney then
				lastPushedMoney = shown
				UI.update({ money = shown })
			end
		end
	end)
end

function UIController.start()
	-- Same shapes as UI/Types.luau, but our catalogs use literal unions (rarity, area, role) where the
	-- UI declares string; Luau table properties are invariant, so the catalog is handed over as any.
	local catalog: any = {
		cats = Catalog.cats,
		upgrades = Catalog.upgrades,
		decor = Catalog.decor,
		lures = Catalog.lures,
		spots = Catalog.spots,
		tiers = Catalog.tiers,
		areas = Catalog.areas,
	}
	-- UI cues (button clicks, popups, toasts) play through the client's Audio channels.
	UI.init({
		catalog = catalog,
		keybinds = true,
		playSound = function(cueId: string)
			return Audio.play(cueId)
		end,
	})
	UI.catch.bindProximityPrompts()
	-- The HUD clock chip reads Phase and PhaseEndsAt off the server's Clock folder and follows its changes.
	task.spawn(function()
		UI.clock.bind(ReplicatedStorage:WaitForChild("Clock"))
	end)
	wireIntents()
	wireServerEvents()
	bindDealerCart()
	startPrediction()
	Net.fire("RequestSync")
	print(string.format("[PurrPot] client ready for %s", player.Name))
end

return UIController
