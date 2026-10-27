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
local bowlPrompt: ProximityPrompt? = nil -- the own bait bowl's prompt, made here so only the owner sees it
local shownBaitKey: string? = nil -- the bowl cat whose card has been shown, so each arrival pops it once
-- The rescue on screen, for the sounds: the server's count so far, so each RescueResult fires one hit or miss.
type RescueRun = {
	spotId: string,
	trap: string?,
	rarity: string?,
	needed: number,
	hits: number,
	paws: number,
}
local rescue: RescueRun? = nil

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

-- The own cafe's bait bowl anchor (F28), for the UI's range hints and the bowl prompt.
function UIController.ownBaitBowl(): BasePart?
	local plot = ownPlot()
	local bowl = if plot ~= nil then plot:FindFirstChild("BaitBowl") else nil
	return if bowl ~= nil and bowl:IsA("BasePart") then bowl :: BasePart else nil
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

-- The cat at the bowl as the bait card wants it, or nil while the bowl is empty or its cat is on the way.
local function baitCat(s: Types.PlayerState): UITypes.BaitCat?
	local bait = s.bait
	local cat = if bait ~= nil then bait.cat else nil
	if cat == nil then
		return nil
	end
	return { catId = cat.catId, variant = cat.variant, charm = cat.charm, stars = cat.stars }
end

-- The bait bowl (F28, data-model section 8): what is in it, the owner's prompt on it and the card the moment its
-- cat arrives. ProfileSync names the cat only once it has arrived, so its first appearance is the arrival.
local function refreshBait(s: Types.PlayerState)
	local bait = s.bait
	UI.bait.set(if bait ~= nil then { lureId = bait.lureId, readyAt = bait.readyAt } else nil)
	local bowl = UIController.ownBaitBowl()
	UI.bait.setBowl(bowl)

	local cat = baitCat(s)
	local owned = (s.upgradeLevels.lure_bowl or 0) >= 1
	local prompt = bowlPrompt
	if owned and bowl ~= nil then
		local float = if prompt ~= nil then prompt.Parent else nil
		if prompt == nil or float == nil or float.Parent ~= bowl then
			if prompt ~= nil then
				prompt:Destroy()
			end
			if float ~= nil and float:IsA("Attachment") then
				float:Destroy()
			end
			-- Custom: the UI's action pill, floating a little above the bowl.
			local point = Instance.new("Attachment")
			point.Name = "PromptPoint"
			point.Position = Vector3.new(0, 2.5, 0)
			point.Parent = bowl
			local made = Instance.new("ProximityPrompt")
			made.Name = "BaitPrompt"
			made.ObjectText = "Bait bowl"
			made.HoldDuration = 0
			made.MaxActivationDistance = 8
			made.RequiresLineOfSight = true -- on the back step: no pill through the back wall from inside (N91)
			made.Style = Enum.ProximityPromptStyle.Custom
			made.Triggered:Connect(function()
				local waiting = if state ~= nil then baitCat(state) else nil
				if waiting ~= nil then
					UI.bait.showReady(waiting)
				else
					UI.bait.openPicker()
				end
			end)
			made.Parent = point
			bowlPrompt = made
			prompt = made
		end
		local shown = prompt :: ProximityPrompt
		shown.ActionText = if cat ~= nil
			then "See the cat"
			elseif bait ~= nil then "Check"
			else "Add food"
	elseif prompt ~= nil then
		local float = prompt.Parent
		prompt:Destroy()
		if float ~= nil and float:IsA("Attachment") then
			float:Destroy()
		end
		bowlPrompt = nil
	end

	if cat ~= nil and bait ~= nil then
		local key = string.format("%s@%d", cat.catId, bait.readyAt)
		if key ~= shownBaitKey then
			shownBaitKey = key
			UI.bait.showReady(cat)
		end
	end
end

-- The rich tip (F31): the UI's gold marker watches the own plot, and the tip's arrival and payout are Moments for
-- the sounds. Its RichTipAmount clears both on a claim and when the tip pays itself at expiry; either way the
-- coins went into the till.
local richTipPlot: Model? = nil
local richTipConnection: RBXScriptConnection? = nil
local richTipAmount = 0

local function tipAmount(plot: Model): number
	local value = plot:GetAttribute("RichTipAmount")
	return if type(value) == "number" then value else 0
end

local function refreshRichTip()
	local plot = ownPlot()
	if plot == richTipPlot then
		return
	end
	if richTipConnection ~= nil then
		richTipConnection:Disconnect()
		richTipConnection = nil
	end
	richTipPlot = plot
	UI.richTip.bind(plot)
	if plot == nil then
		return
	end
	richTipAmount = tipAmount(plot) -- a tip already waiting when this client binds plays no arrival sound
	richTipConnection = plot:GetAttributeChangedSignal("RichTipAmount"):Connect(function()
		local amount = tipAmount(plot)
		if amount > 0 and richTipAmount <= 0 then
			Moments.RichArrive:Fire()
		elseif amount <= 0 and richTipAmount > 0 then
			Moments.RichTipClaim:Fire()
		end
		richTipAmount = amount
	end)
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
	refreshBait(s)
	refreshTutorial(s)
	refreshRichTip()
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
	-- The bait bowl (F28): Use on a food, then Tame or Let go on the card. The answer is the next ProfileSync.
	UI.events.useLure:Connect(function(lureId: string)
		Net.fire("UseLure", lureId)
	end)
	UI.events.resolveBait:Connect(function(choice: string)
		Net.fire("ResolveBait", choice)
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
	-- Collect on the rich tip marker (F31). A claim clears the plot's RichTipAmount, which the UI toasts.
	UI.events.claimRichTip:Connect(function()
		Net.fire("ClaimRichTip")
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
	-- Rescue minigames (data-model section 10b): one press on a stuck cat's prompt asks for the bar. The server
	-- answers with RescueChallenge (or a GrabResult refusal). A press or Give up sends only the trap id: the
	-- server stamps the time itself and judges where the marker was.
	UI.events.rescueBegan:Connect(function(rescueSpotId: string?, _catId: string?)
		if rescueSpotId ~= nil then
			Net.fire("RescueBegin", rescueSpotId)
		end
	end)
	UI.events.rescuePressed:Connect(function(rescueSpotId: string)
		Net.fire("RescuePress", rescueSpotId)
	end)
	UI.events.rescueCancelled:Connect(function(rescueSpotId: string)
		Net.fire("RescueCancel", rescueSpotId)
		if rescue ~= nil and rescue.spotId == rescueSpotId then
			rescue = nil -- the server's closing RescueResult plays no fail sound on top of this one
			Moments.RescueCancel:Fire(rescueSpotId)
		end
	end)
end

-- The trap type and the stuck cat's rarity for the sounds, from the trap's anchor and the cat's model.
local function rescueInfo(rescueSpotId: string): (string?, string?)
	local trap: string? = nil
	for _, spot in CollectionService:GetTagged("RescueSpot") do
		if spot:GetAttribute("RescueSpotId") == rescueSpotId then
			local value = spot:GetAttribute("TrapType")
			trap = if type(value) == "string" then value else nil
			break
		end
	end
	local rarity: string? = nil
	for _, model in CollectionService:GetTagged("StuckCat") do
		if model:GetAttribute("RescueSpotId") == rescueSpotId then
			local value = model:GetAttribute("Rarity")
			rarity = if type(value) == "string" then value else nil
			break
		end
	end
	return trap, rarity
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
		-- CatCaught comes from a check-in or a tamed bait cat, so a bump that drops the carried cat plays no
		-- check-in sound.
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
		function(strayId: string, circles: { Types.CatchCircle }, windows: Types.CatchWindows)
			-- v0.5: tries are unlimited, so no paw row (nil)
			UI.catch.showCircles(strayId, circles, windows, nil)
			Moments.CatchStart:Fire(strayId)
		end
	)
	-- Data-model section 10 step 5: grades up to and including the first Miss and the Purrfect charm bonus. The HUD
	-- shows the grades and, on a miss, that the cat got away (v0.5: it sprints off and tries are unlimited).
	Net.on(
		"CatchResult",
		function(
			strayId: string,
			grades: { Types.CircleGrade },
			success: boolean,
			charmGain: number
		)
			local allPerfect = #grades > 0
			for _, grade in grades do
				allPerfect = allPerfect and grade == "perfect"
			end
			UI.catch.showGrades(strayId, grades, success, nil, charmGain)
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
			end
		end
	)
	-- The rescue bar, or a tree's falling cat after its shakes; then the server's count after every judged press.
	Net.on("RescueChallenge", function(rescueSpotId: string, challenge: Types.RescueChallenge)
		UI.rescue.show(rescueSpotId, challenge)
		if challenge.kind == "circle" then
			Moments.RescueDrop:Fire(rescueSpotId)
			return
		end
		local trap, rarity = rescueInfo(rescueSpotId)
		rescue = {
			spotId = rescueSpotId,
			trap = trap,
			rarity = rarity,
			needed = challenge.hitsNeeded or 0,
			hits = 0,
			paws = challenge.paws or 0,
		}
		Moments.RescueStart:Fire(rescueSpotId)
	end)
	Net.on(
		"RescueResult",
		function(
			rescueSpotId: string,
			hits: number,
			pawsLeft: number,
			done: boolean,
			success: boolean
		)
			UI.rescue.update(rescueSpotId, hits, pawsLeft, done, success)
			local current = rescue
			if current == nil or current.spotId ~= rescueSpotId then
				return
			end
			if hits > current.hits then
				Moments.RescueHit:Fire(hits, current.needed, pawsLeft, current.trap)
			end
			if pawsLeft < current.paws then
				Moments.RescueMiss:Fire(pawsLeft)
			end
			current.hits = hits
			current.paws = pawsLeft
			if done then
				rescue = nil
				if success then
					Moments.RescueDone:Fire(rescueSpotId, current.rarity)
				else
					Moments.RescueFail:Fire(rescueSpotId)
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
		baitBowl = true, -- F28: the HUD's bowl chip and the Bait bowl screen replace the v0.2 lure slot
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
