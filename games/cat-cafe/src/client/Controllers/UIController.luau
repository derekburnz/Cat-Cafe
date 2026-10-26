--!strict
-- Feeds the UI (src/client/UI, ui-designer's) with catalog and state, forwards its intents to remotes,
-- predicts the coin counter between syncs, and drives the catch circles, the rescue prompt, the clock chip, the
-- carry marker and tutorial hints.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Net = require(script.Parent.Parent.Net)
local Types = require(Shared:WaitForChild("Types"))
local UI = require(script.Parent.Parent.UI)

local UIController = {}

local player = Players.LocalPlayer
local state: Types.PlayerState? = nil
local predictedMoney = 0
local lastCarrying: string? = nil
local lastPushedMoney = -1

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

local function alleyEntrance(): BasePart?
	local world = Workspace:FindFirstChild("World")
	local alley = if world ~= nil then world:FindFirstChild("Alley") else nil
	local points = if alley ~= nil then alley:FindFirstChild("SpawnPoints") else nil
	local first = if points ~= nil then points:FindFirstChild("alley_1") else nil
	return if first ~= nil and first:IsA("BasePart") then first :: BasePart else nil
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
			"Walk to the alley at the end of the street and press E on a cat, then tap as each circle closes",
			alleyEntrance(),
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

local function applyState(s: Types.PlayerState)
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
	-- The net (data-model section 10): one press on the prompt asks for the circles. The server answers with
	-- CatchSchedule (or a GrabResult refusal); each press on a circle sends only its index, since the server
	-- stamps the time itself.
	UI.events.grabBegan:Connect(function(strayId: string?)
		if strayId ~= nil then
			Net.fire("GrabBegin", strayId)
		end
	end)
	UI.events.catchPressed:Connect(function(strayId: string, index: number)
		Net.fire("CatchPress", strayId, index)
	end)
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

local function wireServerEvents()
	Net.on("ProfileSync", function(s: Types.PlayerState)
		applyState(s)
	end)
	Net.on("Toast", function(text: string, kind: Types.ToastKind?)
		UI.toast(text, kind)
	end)
	Net.on("Announce", function(text: string)
		UI.announce(text)
	end)
	Net.on("CatCaught", function(catId: string, isNew: boolean)
		UI.showCatFound(catId, isNew)
	end)
	Net.on("OfflineEarnings", function(amount: number, seconds: number)
		UI.showOfflineEarnings(amount, seconds)
	end)
	Net.on(
		"CatchSchedule",
		function(strayId: string, circles: { Types.CatchCircle }, windows: Types.CatchWindows)
			UI.catch.showCircles(strayId, circles, windows)
		end
	)
	Net.on(
		"CatchResult",
		function(strayId: string, scores: { number }, chance: number, success: boolean)
			UI.catch.showResult(strayId, scores, chance, success)
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
	UI.init({ catalog = catalog, keybinds = true })
	UI.catch.bindProximityPrompts()
	-- The HUD clock chip reads Phase and PhaseEndsAt off the server's Clock folder and follows its changes.
	task.spawn(function()
		UI.clock.bind(ReplicatedStorage:WaitForChild("Clock"))
	end)
	wireIntents()
	wireServerEvents()
	startPrediction()
	Net.fire("RequestSync")
	print(string.format("[PurrPot] client ready for %s", player.Name))
end

return UIController
