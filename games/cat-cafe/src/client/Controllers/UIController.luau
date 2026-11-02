--!strict
-- Feeds the UI (src/client/UI, ui-designer's) with catalog and state, forwards its intents to remotes,
-- predicts the coin counter between syncs, and drives the catch circles, the rescue prompt, the clock chip, the
-- carry marker and tutorial hints.

local CollectionService = game:GetService("CollectionService")
local ExperienceNotificationService = game:GetService("ExperienceNotificationService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Audio = require(script.Parent.Parent.Audio)
local Catalog = require(Shared:WaitForChild("Catalog"))
local Clock = require(Shared:WaitForChild("Clock"))
local Config = require(Shared:WaitForChild("Config"))
local DeviceKind = require(Shared:WaitForChild("DeviceKind"))
local Effects = require(script.Parent.Parent.Effects)
local Luck = require(Shared:WaitForChild("Luck"))
local Moments = require(script.Parent.Parent.Moments)
local Net = require(script.Parent.Parent.Net)
local RareMoments = require(Shared:WaitForChild("RareMoments"))
local Settings = require(Shared:WaitForChild("Settings"))
local Tips = require(Shared:WaitForChild("Tips"))
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

-- This player's cafe under World.Plots, or nil before it has one (the intro fades its roof, F72).
function UIController.ownPlot(): Model?
	return ownPlot()
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

-- The Alleyway spawn point where this cafe's tutorial stray waits: plot p owns the p-th point of zone `near` by
-- Index, just past the camp's way out (v4, F84; CatService.tutorialPoints). F87: it was alley point 2p - 1 before the
-- cannon world, which is now a lane point, so the trail led to the wrong spot.
local function tutorialStrayPoint(): BasePart?
	local plotIndex = if state ~= nil then state.plotIndex else 0
	if plotIndex == 0 then
		return nil
	end
	local world = Workspace:FindFirstChild("World")
	local alley = if world ~= nil then world:FindFirstChild("Alley") else nil
	local points = if alley ~= nil then alley:FindFirstChild("SpawnPoints") else nil
	if points == nil then
		return nil
	end
	local near: { BasePart } = {}
	for _, child in points:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("Zone") == "near" then
			table.insert(near, child :: BasePart)
		end
	end
	table.sort(near, function(a: BasePart, b: BasePart): boolean
		local ia, ib = a:GetAttribute("Index"), b:GetAttribute("Index")
		return (if type(ia) == "number" then ia else 0) < (if type(ib) == "number" then ib else 0)
	end)
	return near[plotIndex]
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

-- How to swing the net on this device (F93): the UI's UI.net.hint() ("Tap NET next to a cat", "Press R2 next to a
-- cat" or "Click next to a cat", UI-Engineer #677) once it has it.
local function swingHint(): string
	local net: any = (UI :: any).net
	local hint: unknown = if net ~= nil then net.hint else nil
	if type(hint) == "function" then
		local text = (hint :: () -> unknown)()
		if type(text) == "string" then
			return text
		end
	end
	return "Click next to a cat"
end

-- The tutorial strip's line for this step and device (F87, easy-start.md section 2e): the UI's
-- UI.tutorial.hint(s) once it has it (no letter keys on touch), nil keeping the line here. The trail's target and
-- label stay this controller's.
local function tutorialLine(s: Types.PlayerState, line: string): string
	local tutorial: any = UI.tutorial
	local hint: unknown = if tutorial ~= nil then tutorial.hint else nil
	if type(hint) == "function" then
		local text = (hint :: (Types.PlayerState) -> unknown)(s)
		if type(text) == "string" and text ~= "" then
			return text
		end
	end
	return line
end

local function showTutorial(
	s: Types.PlayerState,
	line: string,
	target: (BasePart | Attachment | Vector3)?,
	label: string?
)
	UI.tutorial.show(tutorialLine(s, line), target, label)
end

local function refreshTutorial(s: Types.PlayerState)
	if s.carrying ~= nil then
		UI.tutorial.hide()
		return
	end
	if s.tutorialStep < 2 then
		showTutorial(
			s,
			string.format(
				"Go out your back door to the alley. %s, then tap as each circle closes",
				swingHint()
			),
			tutorialStrayPoint(),
			"Alley"
		)
	elseif s.tutorialStep == 2 then
		if hasRestingCatAndFreeSpot(s) then
			showTutorial(s, "Open the Collection (C) and give your new cat a role")
		else
			showTutorial(s, "Catch more cats in the alley, or buy a table in Upgrades (U)")
		end
	elseif s.tutorialStep == 3 then
		showTutorial(s, "Buy your first table in Upgrades (U): more money from every cat")
	elseif s.tutorialStep == 4 then
		-- gdd "The first ten minutes" beat 4: the bowl, then food in it (BaitService finishes the tutorial)
		-- (the HUD strip shows about 50 characters on one line, reviewer N94)
		if (s.upgradeLevels.lure_bowl or 0) < 1 then
			showTutorial(s, "Buy the Bait bowl in Upgrades (U)")
		elseif s.bait ~= nil then
			-- baited before the first table on an older save: the server moved new ones to 5 (S48)
			showTutorial(s, "A cat is on its way to your bowl", UIController.ownBaitBowl(), "Bowl")
		else
			showTutorial(
				s,
				"Put Kibble in your bowl on the back step (F)",
				UIController.ownBaitBowl(),
				"Bowl"
			)
		end
	else
		UI.tutorial.hide()
	end
end

-- Role changes since the last sync, for the sounds (sound list: place and unplace): a cat newly in a role or moved
-- to another fires CatPlaced with the role, a cat taken off fires UnplaceCat. Unequip all fires one per cat.
local function firePlacements(old: Types.PlayerState, new: Types.PlayerState)
	for uid, cat in new.cats do
		local before = old.cats[uid]
		local was = if before ~= nil then before.spotId else nil
		local spotId = cat.spotId
		if spotId ~= nil and spotId ~= was then
			local spot = Catalog.getSpot(spotId)
			Moments.CatPlaced:Fire(uid, if spot ~= nil then spot.spotType :: string else spotId)
		elseif spotId == nil and was ~= nil then
			Moments.UnplaceCat:Fire(uid)
		end
	end
end

-- Index rewards claimed since the last sync (F48), one IndexReward each.
local function fireIndexRewards(old: Types.PlayerState, new: Types.PlayerState)
	for areaId, claims in new.indexRewards do
		local before = old.indexRewards[areaId]
		for milestoneId in claims do
			if before == nil or not before[milestoneId] then
				Moments.IndexReward:Fire(areaId, milestoneId)
			end
		end
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
-- cat arrives. ProfileSync names the cat only once it has arrived, so its first appearance is the arrival. placedAt
-- sets the fill bar's length and night (F60) the countdown's moon.
local function refreshBait(s: Types.PlayerState)
	local bait = s.bait
	UI.bait.set(if bait ~= nil
		then {
			lureId = bait.lureId,
			readyAt = bait.readyAt,
			placedAt = bait.placedAt,
			night = bait.night,
		}
		else nil)
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
-- the sounds. Its RichTipAmount clears on a claim and when the tip is missed (expiry, nightfall); the server sets
-- RichTipOutcome just before, and only a claim plays the payout.
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
		elseif
			amount <= 0
			and richTipAmount > 0
			and plot:GetAttribute("RichTipOutcome") == "claimed"
		then
			Moments.RichTipClaim:Fire()
		end
		richTipAmount = amount
	end)
end

-- Every key of shared/Settings reads as the Settings screen shows it: a tap or a drag step at once, then the
-- server's saved value, and back to it if the server dropped the change (ui-contract Settings, reviews N111 and
-- N139). UI.update hands the screen each sync's saved values, so the first read after the first sync matches the save.
local audioStarted = false -- Audio waits for the first ProfileSync, so a muted player never hears music start

local function setting(key: string): any
	if Settings.kinds[key] == "volume" then
		return UI.settings.volume(key)
	end
	return UI.settings.value(key)
end

-- Audio's channels and volumes and the Effects switches, from the settings above. Both skip what has not changed.
local function applySettings()
	Audio.applySettings({
		music = setting("music"),
		sfx = setting("sfx"),
		musicVolume = setting("musicVolume"),
		sfxVolume = setting("sfxVolume"),
	})
	Effects.applySettings({
		screenShake = setting("screenShake"),
		lowPerformance = setting("lowPerformance"),
	})
end

local function applyState(s: Types.PlayerState)
	local previous = state
	if previous ~= nil and boughtSomething(previous, s) then
		Moments.Purchase:Fire()
	end
	if previous ~= nil then
		firePlacements(previous, s)
		fireIndexRewards(previous, s)
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
		goldCollection = s.goldCollection,
		carrying = s.carrying,
		tutorialStep = s.tutorialStep,
		introSeen = s.introSeen, -- F72: the Tutorial tile and its Settings rows wait for this
		settings = s.settings :: any, -- the UI reads it as a map of switches
		indexRewards = s.indexRewards, -- F48: which Index rewards are claimed, so a claimed one shows as done
		spin = s.spin, -- F49: the free spin and the banked ones, for the Spin window
		goldenFish = s.goldenFish, -- F52: the HUD's fish counter
		crates = s.crates, -- F53: unopened crates, crate luck and Market perks
		crateLuck = s.crateLuck,
		fishPerks = s.fishPerks,
		goldLuck = s.goldLuck, -- F54: the Index's gold luck and faster bait, capped
		baitSpeed = s.baitSpeed,
		potions = s.potions, -- F64: the potion bag
		buffs = s.buffs, -- F64: each running potion's endsAt in server time
		quests = s.quests :: any, -- F73: the Quests window's tabs and the HUD's quest line (the UI reads it loosely)
		achievements = s.achievements :: any, -- F73: each achievement's progress and claim
		dailyTreat = s.dailyTreat, -- F70: the Daily Treat card, whether a stamp is due and the day it pays
		-- F87 (#705): the tips seen, the one feedback ask and the help cards shown, so a tip the client finds itself
		-- (stuck_cat, codes_cat, offline), the help card and the ask never repeat each session
		tipsSeen = s.tipsSeen,
		feedbackAsked = s.feedbackAsked,
		stuckHelpShown = s.stuckHelpShown,
		-- F88: the player's Luck and what makes it, for the HUD chip and its card (luck-and-rare-moments.md section 1)
		luck = s.luck,
		luckSources = s.luckSources,
		longNap = s.longNap, -- F95: the welcome back card's "Full pay, up to 16 hours"
	})
	-- After the first sync, sound and Effects follow UI.settings.changed rather than each sync; the purr follows the
	-- server's carry state.
	if not audioStarted then
		audioStarted = true
		applySettings()
	end
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

-- The night dealer: the night of the last DealerStock (F94; the 5 minute window before), which a buy sends back when
-- the screen has none.
local dealerWindow: number? = nil
-- The Fresh Catch shelf (F94): the window of the last FreshCatchStock, which a buy sends back when the screen has none.
local freshWindow: number? = nil

local function wireIntents()
	UI.events.setSetting:Connect(function(key: string, value: any)
		if Settings.clean(key, value) ~= nil then
			Net.fire("SetSetting", key, value)
		end
	end)
	-- Live while a volume drags, so the slider's tick plays at the new volume.
	UI.settings.changed:Connect(function()
		if audioStarted then
			applySettings()
		end
	end)
	-- An Index reward's Claim (F48); the server answers with a toast and a ProfileSync.
	UI.events.claimIndexReward:Connect(function(areaId: string, milestoneId: string)
		Net.fire("ClaimIndexReward", areaId, milestoneId)
	end)
	UI.events.claimTipJar:Connect(function(step: number)
		Net.fire("ClaimTipJar", step)
	end)
	-- Spin on the Spin window (F49); the server answers with SpinResult and a ProfileSync.
	UI.events.spinWheel:Connect(function()
		Net.fire("SpinWheel")
	end)
	-- Use on a potion in the bag (F64); the server answers with a ProfileSync, or a "Full" toast.
	UI.events.usePotion:Connect(function(potionId: string)
		Net.fire("UsePotion", potionId)
	end)
	-- Open on a Market crate card and Buy on a Market row (F53); the server answers with CrateResult or a toast, and
	-- a ProfileSync.
	local uiEvents: any = UI.events
	if uiEvents.openCrate ~= nil then
		uiEvents.openCrate:Connect(function(crateId: string)
			Net.fire("OpenCrate", crateId)
		end)
		uiEvents.buyFishItem:Connect(function(itemId: string)
			Net.fire("BuyFishItem", itemId)
		end)
	end
	-- Send on Report a bug; the server answers with a toast, which the window reads to close or keep the text.
	UI.events.reportBug:Connect(function(text: string, kind: string, clientErrors: { string })
		Net.fire("ReportBug", text, kind, clientErrors)
	end)
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
	-- Unequip all on the cat inventory (UI thread). Looked up loosely like equip best below; the UI shows the
	-- button only once something is connected to the signal.
	local unequipAll = (UI.events :: any).unequipAll
	if unequipAll ~= nil then
		unequipAll:Connect(function()
			Net.fire("UnequipAll")
		end)
	end
	-- Equip best button on the cat room tab (UI thread). Looked up loosely so an older UI build without the
	-- signal still loads; the server validates the request like any other.
	local equipBest = (UI.events :: any).equipBest
	if equipBest ~= nil then
		equipBest:Connect(function()
			Net.fire("EquipBest")
		end)
	end
	-- Drop cat: the carry banner's Drop button and the G key (UI thread, reviewer S53). Looked up loosely the same
	-- way, so this lands before or after the UI build that adds the signal.
	local dropCat = (UI.events :: any).dropCat
	if dropCat ~= nil then
		dropCat:Connect(function()
			local character = player.Character
			local root = if character ~= nil
				then character:FindFirstChild("HumanoidRootPart")
				else nil
			if lastCarrying ~= nil and root ~= nil and root:IsA("BasePart") then
				Moments.CatDrop:Fire((root :: BasePart).Position)
			end
			Net.fire("DropCat")
		end)
	end
	UI.events.rankUp:Connect(function()
		Net.fire("RankUp")
	end)
	UI.events.claimOffline:Connect(function()
		Net.fire("ClaimOffline")
	end)
	-- Rename in the cat room (F33): the server validates, filters and answers with a toast and a sync. The UI adds
	-- events.renameCat with its Rename dialog (ui-contract "Planned"); until then there is nothing to forward.
	local renameCat = (UI.events :: any).renameCat
	if renameCat ~= nil then
		renameCat:Connect(function(uid: string, name: string)
			Net.fire("RenameCat", uid, name)
		end)
	end
	-- Collect on the rich tip marker (F31). A claim clears the plot's RichTipAmount, which the UI toasts.
	UI.events.claimRichTip:Connect(function()
		Net.fire("ClaimRichTip")
	end)
	-- The Lock row on a cat (F62): a locked cat cannot be sold or traded; the next ProfileSync shows the new lock.
	UI.events.lockCat:Connect(function(uid: string, locked: boolean)
		Net.fire("LockCat", uid, locked)
	end)
	-- Trade or No thanks on the Cat Collector's card (F63). The server checks the range and the cat and answers with
	-- CollectorOffer("") when the visit ends, or a toast when the cat cannot go yet.
	UI.events.answerCollector:Connect(function(accept: boolean)
		Net.fire("AnswerCollector", accept)
	end)
	-- Quests and achievements (F73): the server checks each claim and swap and answers with a toast, QuestResult on a
	-- payment and a sync.
	UI.events.claimQuest:Connect(function(kind: string, slot: number)
		Net.fire("ClaimQuest", kind, slot)
	end)
	UI.events.rerollQuest:Connect(function(kind: string, slot: number)
		Net.fire("RerollQuest", kind, slot)
	end)
	UI.events.claimAchievement:Connect(function(achievementId: string)
		Net.fire("ClaimAchievement", achievementId)
	end)
	-- The Daily Treat (F70): the server stamps the card when a stamp is due and answers with a toast and a sync.
	UI.events.claimDailyTreat:Connect(function()
		Net.fire("ClaimDailyTreat")
	end)
	-- The night dealer (F32): the server answers every buy with DealerStock, bought or refused. A buy names the food
	-- and the night the screen showed (else the last one sent; the screen calls it its window), so a buy sent for
	-- another night is refused (S42).
	UI.events.buyDealerFood:Connect(function(_index: number, lureId: string, window: number?)
		Net.fire("BuyDealerFood", lureId, window or dealerWindow or -1)
	end)
	-- The Fresh Catch tab (F94), once the UI has it: (itemId, window) the row and the window the tab showed; the server
	-- answers every buy with FreshCatchStock, bought or refused.
	local buyFreshCatch = (UI.events :: any).buyFreshCatch
	if buyFreshCatch ~= nil then
		buyFreshCatch:Connect(function(itemId: string, window: number?)
			Net.fire("BuyFreshCatch", itemId, window or freshWindow or -1)
		end)
	end
	-- F87 context tips and feedback (easy-start.md sections 3 and 4), once the UI has them: a tip or ask shown (skipped
	-- true when a camera cut was skipped), Settings' "Show tips again", and a face with an optional chip.
	local events = UI.events :: any
	if events.tipSeen ~= nil then
		events.tipSeen:Connect(function(id: string, skipped: boolean?)
			Net.fire("TipSeen", id, skipped == true)
		end)
	end
	if events.clearTips ~= nil then
		events.clearTips:Connect(function()
			Net.fire("ClearTips")
		end)
	end
	if events.sendFeedback ~= nil then
		events.sendFeedback:Connect(function(face: string, chip: string?)
			Net.fire("SendFeedback", face, chip)
		end)
	end
	-- F87 part 3 (UI #745), analytics only: the intro's choice ("tile" or "help") and the stuck nudges ("pulse",
	-- "help_shown", "show_me") as TelemetryReport, which allowlists both with their session caps. A nudge goes once
	-- per tutorial step and kind, as the server logs it, so a repeating pulse never reaches the remote's limit.
	if events.introChoice ~= nil then
		events.introChoice:Connect(function(from: string)
			Net.fire("TelemetryReport", "intro_choice", from)
		end)
	end
	if events.stuckNudge ~= nil then
		local nudged: { [string]: boolean } = {}
		events.stuckNudge:Connect(function(kind: string)
			local key = string.format(
				"%s:%s",
				tostring(if state ~= nil then state.tutorialStep else nil),
				kind
			)
			if not nudged[key] then
				nudged[key] = true
				Net.fire("TelemetryReport", "stuck_nudge", kind)
			end
		end)
	end
	-- Fast travel (F19): the travel row and the Areas panel; the server answers every request with TravelResult.
	UI.events.travel:Connect(function(destination: string)
		Net.fire("Travel", destination)
	end)
	-- Analytics only (F16): which screens players find at all, once per screen a session so toggling a panel never
	-- reaches the remote's rate limit (reviewer N97). The server allowlists the names.
	local screensReported: { [string]: boolean } = {}
	UI.events.screenOpened:Connect(function(name: string?)
		if name ~= nil and not screensReported[name] then
			screensReported[name] = true
			Net.fire("TelemetryReport", "ui_opened", name)
		end
	end)
	-- The net (data-model section 10): since F93 a swing starts the circles or picks a Dropped cat up
	-- (Controllers/NetSwingController); the server answers with CatchSchedule, and each press on a circle sends only
	-- its index, since the server stamps the time itself.
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

-- The Golden Fish Market window (F53) and its two events come with UI #312. Until that is on main the UI module may
-- not have them, so they are reached loosely and skipped when missing. Drop the casts once #312 merges.
local function marketUI(): any
	return (UI :: any).market
end

-- A street station's prompt opens its window, which closes itself when the player walks out of range. The station is
-- the server's, tagged and Persistent; a prompt that streams in after its model is bound too, and each prompt only
-- once. `found`, when given, hears of each prompt as it is bound.
local function bindStationPrompts(
	tag: string,
	promptName: string,
	open: () -> (),
	found: ((ProximityPrompt) -> ())?
)
	local bound: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	local function bindPrompt(instance: Instance)
		if
			bound[instance]
			or instance.Name ~= promptName
			or not instance:IsA("ProximityPrompt")
		then
			return
		end
		bound[instance] = true
		local prompt = instance :: ProximityPrompt
		prompt.Triggered:Connect(function()
			open()
		end)
		if found ~= nil then
			found(prompt)
		end
	end
	local function station(instance: Instance)
		for _, descendant in instance:GetDescendants() do
			bindPrompt(descendant)
		end
		instance.DescendantAdded:Connect(bindPrompt)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(station)
	for _, instance in CollectionService:GetTagged(tag) do
		station(instance)
	end
end

-- The night dealer's cart (F32): the UI's range hint follows it and its prompt opens the dealer screen. The cart
-- is the server's, tagged DealerCart, there from night start to day start. Its prompt is bound the way a station's
-- is, since it can reach this client after the cart's tag does: looking for it once when the tag arrived left E at
-- the cart doing nothing (Derek 2026-10-28). The range hint follows the part the prompt floats on, the part the
-- server measures the range from.
local function bindDealerCart()
	bindStationPrompts("DealerCart", "DealerPrompt", function()
		UI.dealer.open()
	end, function(prompt: ProximityPrompt)
		local holder = prompt.Parent
		local part = if holder ~= nil and holder:IsA("Attachment") then holder.Parent else holder
		if part ~= nil and part:IsA("BasePart") then
			UI.dealer.setCart(part :: BasePart)
		end
	end)
	-- `cue` is false for a cart already out when this client starts, so a player who joins at night does not
	-- hear it arrive (reviewer note on #110).
	local function arrived(instance: Instance, cue: boolean)
		if not instance:IsA("Model") then
			return
		end
		local model = instance :: Model
		local found = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
		if found ~= nil and found:IsA("BasePart") then
			UI.dealer.setCart(found :: BasePart)
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

-- The Spin Wheel (F49) and the Golden Fish Market (F53) in the street plaza.
local function bindStations()
	bindStationPrompts("SpinWheel", "SpinPrompt", function()
		UI.spin.open()
	end)
	bindStationPrompts("FishMarket", "MarketPrompt", function()
		local market = marketUI()
		if market ~= nil then
			market.open()
		end
	end)
end

-- Analytics only (F16): the device kind goes on the onboarding funnel's joined step and on session_end. Sent on the
-- first ProfileSync, when the server's telemetry session is sure to exist (reviewer S49).
local deviceReported = false
local function reportDevice()
	if deviceReported then
		return
	end
	deviceReported = true
	local camera = Workspace.CurrentCamera
	Net.fire(
		"TelemetryReport",
		"device",
		DeviceKind.classify({
			touch = UserInputService.TouchEnabled,
			keyboard = UserInputService.KeyboardEnabled,
			tenFoot = GuiService:IsTenFootInterface(),
			viewport = if camera ~= nil then camera.ViewportSize else Vector2.new(1920, 1080),
		})
	)
end

-- The circle sounds (sound list: circle pop): one CircleAppear per circle at its startsAt, until CatchResult or the
-- next CatchSchedule cancels the rest.
local circleTimers: { thread } = {}
local function cancelCircleTimers()
	for _, timer in circleTimers do
		if coroutine.status(timer) ~= "dead" then
			task.cancel(timer)
		end
	end
	table.clear(circleTimers)
end

local tipJarClaimed: { boolean }? = nil -- the claimed steps last shown, nil before this session's first state

-- F96 (starter-cat.md section 3): an ask waits for a quiet moment, never in a catch, a rescue, a carry or the intro.
local busyUntil = 0 -- os.clock(): a catch or rescue running, or just ended
local inIntro = false
local ASK_WAIT_SECONDS = 300 -- an ask with no quiet moment this long waits for another session
local ASK_SETTLE_SECONDS = 3 -- after a catch or rescue ends, before an ask

local function quiet(): boolean
	return not inIntro and os.clock() >= busyUntil and (state == nil or state.carrying == nil)
end

local function trackBusy()
	-- held at most this long each, in case the end never reaches this client (NetSwingController's holds)
	Moments.CatchStart:Connect(function()
		busyUntil = os.clock() + 30
	end)
	Moments.RescueStart:Connect(function()
		busyUntil = os.clock() + 60
	end)
	for _, ended in
		{
			Moments.CatchSuccess,
			Moments.CatchFail,
			Moments.RescueDone,
			Moments.RescueFail,
			Moments.RescueCancel,
		} :: { any }
	do
		ended:Connect(function()
			busyUntil = os.clock() + ASK_SETTLE_SECONDS
		end)
	end
	Moments.IntroStart:Connect(function()
		inIntro = true
	end)
	Moments.IntroEnd:Connect(function()
		inIntro = false
	end)
	player.CharacterAdded:Connect(function()
		busyUntil = 0 -- a new character has nothing running
	end)
end

-- The words of the asks that are toasts (section 3); the UI's optional UI.asks.show(id) -> boolean shows its own.
local ASK_LINES: { [string]: string } = {
	[Tips.FAVORITE_ASK] = "Favorite Cat Cafe to find it fast next time",
	[Tips.LIKE_ASK] = "Having fun? A thumbs up helps other players find Cat Cafe.",
}

-- Shows an ask at the next quiet moment and answers TipSeen: the notification ask is Roblox's own opt-in prompt
-- (players 13 and up; skipped when Roblox will not prompt), the favorite and like asks a toast or the UI's card.
local function showAsk(id: string)
	task.spawn(function()
		local waited = 0
		while not quiet() do
			if waited >= ASK_WAIT_SECONDS then
				return
			end
			waited += task.wait(1)
		end
		if id == Tips.NOTIFY_ASK then
			local ok, can = pcall(function()
				return ExperienceNotificationService:CanPromptOptInAsync()
			end)
			local prompted = ok
				and can == true
				and pcall(function()
					ExperienceNotificationService:PromptOptIn()
				end)
			Net.fire("TipSeen", id, not prompted)
			return
		end
		local asks: any = (UI :: any).asks
		local shown = false
		if asks ~= nil and type(asks.show) == "function" then
			shown = (asks.show :: (string) -> unknown)(id) == true
		end
		if not shown then
			UI.toast(ASK_LINES[id] or "", "info")
		end
		Net.fire("TipSeen", id, false)
	end)
end

local function wireServerEvents()
	Net.on("ProfileSync", function(s: Types.PlayerState)
		applyState(s)
		reportDevice()
	end)
	Net.on("Toast", function(text: string, kind: Types.ToastKind?)
		UI.toast(text, kind)
	end)
	Net.on("Announce", function(text: string, rarity: string?)
		UI.announce(text, rarity)
		Moments.Announce:Fire(text, rarity)
	end)
	-- Rare moments (F89, luck-and-rare-moments.md 2a): a big pull anywhere in the server, or this player's first Epic.
	-- The UI's card (`UI.securedRare(userId, catId, rarity, gold, variant)`, which plays the owner's card and leaves
	-- everyone else to the Announce toast) once it has one; Effects, Animation and Audio from Moments.SecuredRare.
	Net.on(
		"SecuredRare",
		function(userId: number, catId: string, rarity: string, gold: boolean, variant: string)
			local hook: unknown = (UI :: any).securedRare
			if type(hook) == "function" then
				(hook :: (number, string, string, boolean, string) -> ())(
					userId,
					catId,
					rarity,
					gold,
					variant
				)
			end
			Moments.SecuredRare:Fire(userId, catId, rarity, gold, variant)
		end
	)
	-- A Mythical crate piece (2b): the toast for everyone else (the finder has the reel and the big card), from the
	-- UI's `UI.foundRareDecor(userId, decorId)` once it has one, else a Mythical shout-out.
	Net.on("FoundRareDecor", function(userId: number, decorId: string)
		Moments.FoundRareDecor:Fire(userId, decorId)
		local hook: unknown = (UI :: any).foundRareDecor
		if type(hook) == "function" then
			(hook :: (number, string) -> ())(userId, decorId)
			return
		end
		local finder = Players:GetPlayerByUserId(userId)
		local decor = Catalog.getDecor(decorId)
		if finder ~= nil and finder ~= player and decor ~= nil then
			UI.announce(RareMoments.decorText(finder.DisplayName, decor.name), "Mythical")
		end
	end)
	-- F92 (playing-together.md 1 and 2): this player's pals on the server, for the HUD chip's headshots and "+10% with
	-- pals", once the UI has `UI.pals(userIds)`; the bonus itself is in Economy.tipMultiplier and settle.
	Net.on("PalsChanged", function(userIds: { number })
		local hook: unknown = (UI :: any).pals
		if type(hook) == "function" then
			(hook :: ({ number }) -> ())(userIds)
		end
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
	-- The Tip Jar's session start and claimed steps (F47), on profile load and after every claim.
	Net.on("TipJarState", function(jar: Types.TipJarState)
		UI.tipJar.set(jar :: any) -- the UI reads claimed as a map; the dense array indexes the same way
		-- the first state of a session sets what was already claimed; after that, each new claim plays once
		if tipJarClaimed ~= nil then
			for step, claimed in jar.claimed do
				if claimed and not tipJarClaimed[step] then
					Moments.TipJarClaim:Fire(step)
				end
			end
		end
		tipJarClaimed = table.clone(jar.claimed)
	end)
	-- The slice a spin landed on and its coins or foods; 0, 0 when the server refused it (F49).
	Net.on("SpinResult", function(slice: number, amount: number)
		UI.spin.result(slice, amount)
	end)
	-- The piece a crate gave, whether it was a duplicate and its refund; "", false, 0 when the server refused (F53).
	Net.on(
		"CrateResult",
		function(crateId: string, decorId: string, duplicate: boolean, refund: number)
			local market = marketUI()
			if market ~= nil then
				market.result(crateId, decorId, duplicate, refund)
			end
		end
	)
	-- What this player's opened Mystery gift held (F64): the gift card, and the ribbon pop in Effects.
	Net.on("MysteryGiftResult", function(kind: string, id: string?, count: number)
		UI.potions.giftResult(kind, id, count)
	end)
	-- What a quest, a set or an achievement claim paid (F73), for the Quests window's claim effect.
	Net.on("QuestResult", function(paid: { string })
		UI.quests.result(paid)
	end)
	-- The Cat Collector at this player's cafe (F63): his card and tag, or catUid "" when he leaves or a trade is done.
	Net.on(
		"CollectorOffer",
		function(catUid: string, offer: Types.CollectorOffer?, endsAt: number, traded: boolean?)
			-- the UI's own CollectorOffer reads `value` as optional, so the shared row passes as is
			UI.collector.offer(catUid, offer :: any, endsAt, traded)
		end
	)
	-- One of this player's cats reached a new level (F75): the UI gathers close ones into one toast, Audio chimes and
	-- Effects sparkles from the model's Level attribute.
	Net.on("CatLevelUp", function(uid: string, level: number)
		UI.catLevelUp(uid, level)
		Moments.CatLevelUp:Fire(uid, level)
	end)
	Net.on("DealerStock", function(stock: Types.DealerStock?)
		dealerWindow = if stock ~= nil then stock.night else nil
		-- the screen takes the amounts as they come (#492). F94: one stock a night, so the screen's window is the
		-- night and its countdown runs to sunrise, when the cart leaves
		local clock = ReplicatedStorage:FindFirstChild("Clock")
		local sunrise = if clock ~= nil then clock:GetAttribute("PhaseEndsAt") else nil
		UI.dealer.setStock(if stock ~= nil
			then {
				window = stock.night,
				restocksAt = if type(sunrise) == "number" then sunrise else 0,
				stock = stock.stock,
			}
			else nil)
	end)
	-- The Fresh Catch shelf (F94): this player's stock by day, nil at night; the UI's tab takes it once it exists.
	Net.on("FreshCatchStock", function(stock: Types.FreshCatchStock?)
		freshWindow = if stock ~= nil then stock.window else nil
		local fresh: any = (UI :: any).freshCatch
		local setStock: unknown = if fresh ~= nil then fresh.setStock else nil
		if type(setStock) == "function" then
			(setStock :: (Types.FreshCatchStock?) -> ())(stock)
		end
	end)
	-- The once a window heads up (F94): the UI's own alert once it has one, else a plain toast. The server sends it
	-- only with settings.shopAlerts on.
	Net.on("ShopAlert", function(itemId: unknown)
		local row = if type(itemId) == "string" then Catalog.getFreshCatchRow(itemId) else nil
		if row == nil then
			return
		end
		local alert: unknown = (UI :: any).shopAlert
		if type(alert) == "function" then
			(alert :: (string) -> ())(row.id)
			return
		end
		local potion = Catalog.getPotion(row.potionId or "")
		local crate = Catalog.getCrate(row.crateId or "")
		local text = if potion ~= nil
			then potion.name .. "s at the Fish Market!"
			elseif crate ~= nil then "A cheap " .. crate.name .. " at the Fish Market!"
			else "Something good at the Fish Market!"
		UI.toast(text, "info")
	end)
	-- F87: a server-side context tip's moment (shared/Tips). The UI's tip queue times it and answers tipSeen; until
	-- the UI has one the tips wait unseen, so they still show once the cards land. F96: the notification and favorite
	-- asks are this controller's (showAsk); the like ask goes to the queue when there is one.
	trackBusy()
	Net.on("ShowTip", function(id: unknown)
		if type(id) ~= "string" or not Tips.seenId(id) then
			return
		end
		local tips: any = (UI :: any).tips
		local queue = tips ~= nil and type(tips.show) == "function"
		-- the like ask is a card in the UI's tip queue (#738), which times it and answers tipSeen; the notification
		-- and favorite asks, and the like ask before the queue, are showAsk's
		if Tips.isAsk(id) and not (queue and id == Tips.LIKE_ASK) then
			showAsk(id)
			return
		end
		if queue then
			(tips.show :: (string) -> ())(id)
		end
	end)
	Net.on("PlotOpened", function(position: Vector3, plotIndex: number)
		Moments.PlotOpened:Fire(position, plotIndex)
	end)
	Net.on("TravelResult", function(destination: string, ok: boolean, reason: string?)
		UI.travel.result(destination, ok, reason)
		if ok then
			Moments.Travel:Fire(destination)
		end
	end)
	Net.on("OfflineEarnings", function(amount: number, seconds: number)
		UI.showOfflineEarnings(amount, seconds)
	end)
	Net.on(
		"CatchSchedule",
		function(strayId: string, circles: { Types.CatchCircle }, windows: Types.CatchWindows)
			UI.catch.showCircles(strayId, circles, windows)
			Moments.CatchStart:Fire(strayId)
			cancelCircleTimers()
			for index, circle in circles do
				local wait = math.max(0, circle.startsAt - Workspace:GetServerTimeNow())
				local shrink = circle.shrinkSeconds
				table.insert(
					circleTimers,
					task.delay(wait, function()
						-- a stray that despawned mid-catch sends no CatchResult (review N133)
						if strayModel(strayId) ~= nil then
							Moments.CircleAppear:Fire(index, shrink)
						end
					end)
				)
			end
		end
	)
	-- Data-model section 10 step 5: grades up to and including the first Miss and the Purrfect charm bonus. The HUD
	-- shows the grades and, on a miss, that the cat got away (v0.5: it sprints off and tries are unlimited). A miss
	-- also brings this player's retryAt (F57, review S87), when the card's "Catch your breath..." ends.
	Net.on(
		"CatchResult",
		function(
			strayId: string,
			grades: { Types.CircleGrade },
			success: boolean,
			charmGain: number,
			retryAt: number?
		)
			local allPerfect = #grades > 0
			for _, grade in grades do
				allPerfect = allPerfect and grade == "perfect"
			end
			UI.catch.showGrades(
				strayId,
				grades,
				success,
				charmGain,
				if type(retryAt) == "number" then retryAt else nil
			)
			cancelCircleTimers()
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
			success: boolean,
			bar: Types.RescueBar?
		)
			-- F93: `bar` is how the marker runs and which zone to hit from now (a zone that ran out, a faster marker
			-- after a hit); a UI that does not take it yet ignores it
			local update: any = UI.rescue.update
			update(rescueSpotId, hits, pawsLeft, done, success, bar)
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

-- F88 (luck-and-rare-moments.md 1c): a Lucky Day's two moments, read off the server's Clock folder. "warning" comes
-- LuckyDayWarnSeconds before a sunrise that starts a Lucky Day (at night Day is the day that ended, so the sunrise
-- starts Day + 1), to whoever is still in the server; "start" comes when LuckyDay turns true at that sunrise. Joining
-- in the middle of one shows neither: the Luck chip and the sky say so then. The UI's own banner, `UI.luckyDay(kind,
-- line)`, once it has one, else a gold shout-out.
local function bindLuckyDay(clock: Instance)
	local function show(kind: string, line: string)
		local hook: unknown = (UI :: any).luckyDay
		if type(hook) == "function" then
			(hook :: (string, string) -> ())(kind, line)
		else
			UI.announce(line, "Legendary")
		end
	end
	clock:GetAttributeChangedSignal("LuckyDay"):Connect(function()
		if clock:GetAttribute("LuckyDay") == true then
			show("start", Luck.DAY_BANNER)
		end
	end)
	task.spawn(function()
		local warned = 0 -- the Lucky Day already warned of
		while clock.Parent ~= nil do
			local day = clock:GetAttribute("Day")
			local endsAt = clock:GetAttribute("PhaseEndsAt")
			if
				clock:GetAttribute("Phase") == "night"
				and type(day) == "number"
				and type(endsAt) == "number"
			then
				local coming = day + 1
				local left = endsAt - Workspace:GetServerTimeNow()
				if
					Clock.isLuckyDay(coming)
					and warned ~= coming
					and left > 0
					and left <= Config.LuckyDayWarnSeconds
				then
					warned = coming
					show("warning", Luck.DAY_WARNING)
				end
			end
			task.wait(1)
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
		rarities = Catalog.rarities,
		tipJar = Catalog.tipJar,
		indexMilestones = Catalog.indexMilestones,
		indexPrizes = Catalog.indexPrizes,
		spinWheel = Catalog.spinWheel,
		crates = Catalog.crates, -- F53: names and models for the crate prizes (review S77)
		crateDecor = Catalog.crateDecor, -- F53: the 60 crate pieces (the Decor shop keeps reading decor)
		fishShop = Catalog.fishShop, -- F53: what the Golden Fish Market sells
		potions = Catalog.potions, -- F64: the potion bag's rows
		mysteryGift = Catalog.mysteryGift, -- F64: what a Mystery gift can hold, shown before opening
		dealerAmountWeights = Catalog.dealerAmountWeights, -- F59: the dealer's stock odds under Details
		quests = Catalog.quests, -- F73: the quest rows (to tell a coins quest)
		questPrizes = Catalog.questPrizes, -- F73: daily, dailyBig, dailySet, weekly and weeklySet
		achievements = Catalog.achievements, -- F73: the 44 achievements in table order
		achievementPrizes = Catalog.achievementPrizes, -- F73: prizes by size
		dailyTreat = Catalog.dailyTreat, -- F70: the Daily Treat card's seven days and their prizes
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
		local clock = ReplicatedStorage:WaitForChild("Clock")
		UI.clock.bind(clock)
		bindLuckyDay(clock)
	end)
	wireIntents()
	wireServerEvents()
	bindDealerCart()
	bindStations()
	startPrediction()
	Net.fire("RequestSync")
	print(string.format("[CatCafe] client ready for %s", player.Name))
end

return UIController
