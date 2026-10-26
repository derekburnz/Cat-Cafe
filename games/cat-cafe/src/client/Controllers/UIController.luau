--!strict
-- Feeds the UI (src/client/UI, ui-designer's) with catalog and state, forwards its intents to remotes,
-- predicts the coin counter between syncs, and drives the catch prompt, carry marker and tutorial hints.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Config = require(Shared:WaitForChild("Config"))
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
		if s.cafeLevel >= spot.cafeLevel and not used[spot.id] then
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
			"Walk to the alley at the end of the street and hold E on a cat to grab it",
			alleyEntrance(),
			"Alley"
		)
	elseif s.tutorialStep == 2 then
		if hasRestingCatAndFreeSpot(s) then
			UI.tutorial.show("Open the Collection (C) and place your new cat on a spot")
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
		cafeLevel = s.cafeLevel,
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
	UI.events.claimOffline:Connect(function()
		Net.fire("ClaimOffline")
	end)
	UI.events.grabBegan:Connect(function(strayId: string?)
		if strayId ~= nil then
			Net.fire("GrabBegin", strayId)
		end
	end)
	UI.events.grabEnded:Connect(function(strayId: string?, result: Types.RingResult)
		if strayId ~= nil then
			Net.fire("GrabEnd", strayId, result)
		end
	end)
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
	Net.on("GrabResult", function(_strayId: string, ok: boolean, reason: string, retry: boolean)
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
	-- Same shapes as UI/Types.luau, but our catalogs use literal unions (rarity, area, spot type) where the
	-- UI declares string; Luau table properties are invariant, so the catalog is handed over as any.
	local catalog: any = {
		cats = Catalog.cats,
		upgrades = Catalog.upgrades,
		decor = Catalog.decor,
		lures = Catalog.lures,
		spots = Catalog.spots,
	}
	UI.init({ catalog = catalog, keybinds = true })
	UI.catch.bindProximityPrompts()
	wireIntents()
	wireServerEvents()
	startPrediction()
	Net.fire("RequestSync")
	print(
		string.format(
			"[PurrPot] client ready for %s (hold %.1fs to grab)",
			player.Name,
			Config.GrabHoldSeconds
		)
	)
end

return UIController
