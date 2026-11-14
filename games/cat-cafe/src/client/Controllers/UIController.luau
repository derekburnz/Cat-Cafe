--!strict
-- Feeds the UI (src/client/UI, ui-designer's) with catalog and state, forwards its intents to remotes,
-- predicts the coin counter between syncs, and drives the catch circles, the rescue prompt, the clock chip, the
-- carry marker and tutorial hints.

local CollectionService = game:GetService("CollectionService")
local ExperienceNotificationService = game:GetService("ExperienceNotificationService")
local GuiService = game:GetService("GuiService")
local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AfkController = require(script.Parent.AfkController)
local Arcade = require(Shared:WaitForChild("Arcade"))
local Audio = require(script.Parent.Parent.Audio)
local BigTraitCut = require(script.Parent.Parent.Effects.BigTraitCut)
local CarrySync = require(Shared:WaitForChild("CarrySync"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Catching = require(Shared:WaitForChild("Catching"))
local Clock = require(Shared:WaitForChild("Clock"))
local Config = require(Shared:WaitForChild("Config"))
local DeviceKind = require(Shared:WaitForChild("DeviceKind"))
local DragonRise = require(script.Parent.Parent.Effects.DragonRise)
local Effects = require(script.Parent.Parent.Effects)
local EventBanner = require(script.Parent.Parent.Effects.EventBanner)
local EventRsvp = require(script.Parent.Parent.UI.Components.EventRsvp)
local FeedbackStand = require(Shared:WaitForChild("FeedbackStand"))
local FirstFive = require(Shared:WaitForChild("FirstFive"))
local FirstVisitLogic = require(script.Parent.Parent.UI.Components.FirstVisitLogic)
local GrandOpening = require(Shared:WaitForChild("GrandOpening"))
local Invite = require(script.Parent.Parent.UI.Components.Invite)
local InviteCardLogic = require(script.Parent.Parent.UI.Components.InviteCardLogic)
local Jukebox = require(Shared:WaitForChild("Jukebox"))
local Luck = require(Shared:WaitForChild("Luck"))
local Moments = require(script.Parent.Parent.Moments)
local MysticPool = require(script.Parent.Parent.Effects.MysticPool)
local Net = require(script.Parent.Parent.Net)
local NewKind = require(Shared:WaitForChild("NewKind"))
local NewKindEconomy = require(Shared:WaitForChild("Economy"))
local RareMoments = require(Shared:WaitForChild("RareMoments"))
local RiftRun = require(script.Parent.Parent.Effects.RiftRun)
local SecondCat = require(Shared:WaitForChild("SecondCat"))
local Settings = require(Shared:WaitForChild("Settings"))
local ShortNumber = require(Shared:WaitForChild("ShortNumber"))
local StoreFunnel = require(Shared:WaitForChild("StoreFunnel"))
local StuckGoal = require(Shared:WaitForChild("StuckGoal"))
local Tips = require(Shared:WaitForChild("Tips"))
local Traits = require(Shared:WaitForChild("Traits"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(script.Parent.Parent.UI)
local UITypes = require(script.Parent.Parent.UI.Types)
local UpdateGift = require(Shared:WaitForChild("UpdateGift"))

local UIController = {}

local player = Players.LocalPlayer
local state: Types.PlayerState? = nil
-- #2077: every Jukebox song's cue for the Shuffle pick, once the server saves Jukebox.SHUFFLE and Audio can shuffle;
-- nil until both have landed, and the Style tab shows no Shuffle
local shuffleCues: { string }? = nil
if (Jukebox :: any).SHUFFLE ~= nil and (Audio :: any).setJukeboxShuffle ~= nil then
	local cues: { string } = {}
	for _, track in Jukebox.TRACKS do
		table.insert(cues, track.cue)
	end
	shuffleCues = table.freeze(cues)
end
local SCREEN_REPORT_SECONDS = 5 -- #1273: the open screen goes to the server at most this often
local predictedMoney = 0
-- os.clock() of the last Corner Shop buy. Its food shows up in `lures`, but every row of that shop sounds with the
-- toast pop, so the bigger purchase ding stays off for it.
local lastCornerShopBuy = -math.huge
local CORNER_SHOP_QUIET_SECONDS = 3
local lastCarrying: string? = nil
-- #3145: the newest ProfileSync's `carrying`, noted the moment the sync arrives and before anything else runs, so
-- the carry banner follows the server's latest word whatever order the syncs finish applying in (refreshCarry)
local latestCarrying: string? = nil
local shownCamp: BasePart? = nil -- #2730: the camp basket the carry marker leads to now, or nil for the door
-- #2864: the Backpack cat the marker leads home while the hands are empty (the character's PackedCatId), and its
-- camp basket now; nil when none is shown
local shownBag: string? = nil
local shownBagCamp: BasePart? = nil
local lastPushedMoney = -1
local lastTier: number? = nil
local pendingCharmGain = 0 -- the last catch's Purrfect bonus, shown on the cat reveal at check-in
-- The own bait bowls' prompts (1 and #1161's 2), made here so only the owner sees them, and the cat at each whose card
-- has been shown, so each arrival pops it once.
local bowlPrompts: { [number]: ProximityPrompt? } = {}
local shownBaitKeys: { [number]: string? } = {}
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
-- F98: the last LeaderboardSync, for a Top tab or board face that opens between syncs
UIController.leaderboards = nil :: Types.LeaderboardSync?

-- #1645: the crate pieces, then the Cafe Pass decor (Catalog.passDecor), for the UI's crateDecor list.
-- #3694: each achievement's prize with its line's item, for the Quests cards (the server pays the same).
local function achievementPrizesById(): { [string]: Types.IndexPrize }
	local out: { [string]: Types.IndexPrize } = {}
	for _, def in Catalog.achievements do
		out[def.id] = Catalog.achievementPrize(def)
	end
	return out
end

local function passAndCrateDecor(): { Types.DecorDef }
	local list: { Types.DecorDef } = table.clone(Catalog.crateDecor)
	for _, def in Catalog.passDecor do
		table.insert(list, def)
	end
	return list
end

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

-- #2730 (Derek2 2026-11-09: "when holding a cat show a bubble back to the area safe zone so people can see their way
-- back easier"): while carrying inside a catching area (a World.Zones box other than Cafe, WorldBuilder), the carry
-- marker leads to that area's camp basket (the nearest `CampBasket`, the camp being its safe zone, F84) instead of
-- the far cafe door. Checked again every CAMP_CHECK_SECONDS while carrying, so walking out of an area moves it back.
local CAMP_CHECK_SECONDS = 0.5
local POOL_SEEN_STUDS = 60 -- #3196: the Mystic Pool's roll plays at the station when the player is this near it
local POOL_FAR_STUDS = 24 -- and its card, opened at the ring, closes once the player is this far from it

local function inCatchingArea(position: Vector3): boolean
	local world = Workspace:FindFirstChild("World")
	local zones = if world ~= nil then world:FindFirstChild("Zones") else nil
	if zones == nil then
		return false
	end
	for _, box in zones:GetChildren() do
		local part = if box:IsA("BasePart") then box :: BasePart else nil
		if part ~= nil and part.Name ~= "Cafe" then
			local offset = part.CFrame:PointToObjectSpace(position)
			local half = part.Size / 2
			if
				math.abs(offset.X) <= half.X
				and math.abs(offset.Y) <= half.Y
				and math.abs(offset.Z) <= half.Z
			then
				return true
			end
		end
	end
	return false
end

-- The camp basket the carry marker leads to, or nil (outside every catching area, or no basket streamed in).
local function carryCamp(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") or not inCatchingArea(root.Position) then
		return nil
	end
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, tagged in CollectionService:GetTagged("CampBasket") do
		local basket = if tagged:IsA("Model") then tagged.PrimaryPart else nil
		if basket ~= nil then
			local distance = (basket.Position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = basket, distance
			end
		end
	end
	return best
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

-- #2751 (Laptop-Tester: on the job step no cat flashed): one of your resting cats in your cafe's Cats folder (CafeService
-- marks a cat without a role Napping), for the step's ring; nil while none has streamed in.
local function restingCat(): BasePart?
	local plot = ownPlot()
	local cats = if plot ~= nil then plot:FindFirstChild("Cats") else nil
	if cats == nil then
		return nil
	end
	for _, model in cats:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("Napping") == true then
			local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
			if part ~= nil then
				return part
			end
		end
	end
	return nil
end

-- #2912 (Nov 10 read: 21% leave between the first customer served and the second cat): the Alleyway stray nearest the
-- character that this player may catch (not another beginner's, not in someone else's catch), for step 3's ring while
-- only one cat is caught; nil while none has streamed in. #3022: the stray the server has waiting for this player
-- (shared/SecondCat, the model's WaitsFor attribute) comes before a nearer one.
local function nearestAlleyStray(): BasePart?
	local world = Workspace:FindFirstChild("World")
	local strays = if world ~= nil then world:FindFirstChild("Strays") else nil
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if strays == nil or root == nil or not root:IsA("BasePart") then
		return nil
	end
	local me = Players.LocalPlayer.UserId
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, model in strays:GetChildren() do
		local beginner = model:GetAttribute("Beginner")
		local locked = model:GetAttribute("LockedBy")
		local mine = (beginner == nil or beginner == 0 or beginner == me)
			and (locked == nil or locked == 0 or locked == me)
		if model:IsA("Model") and model:GetAttribute("Area") == "alley" and mine then
			local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
			if part ~= nil then
				if model:GetAttribute(SecondCat.ATTRIBUTE) == me then
					return part
				end
				local distance = (part.Position - root.Position).Magnitude
				if distance < bestDistance then
					best, bestDistance = part, distance
				end
			end
		end
	end
	return best
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
	for _, spot in Catalog.allSpots do
		if Catalog.slotIsOpen(spot.id, s.tier, s.extraSlots or 0) and not used[spot.id] then
			return true
		end
	end
	return false
end

-- How to swing the net on this device (F93): the UI's UI.net.hint() ("Tap NET next to a cat", "Press R2 next to a
-- cat" or "Click next to a cat", UI-Engineer #677) once it has it.
-- #2871 (console pass 2 leftover): the alley step's "then tap as each circle closes" names the input the player last
-- used, as IntroController's deviceCaption does: "press A" on a gamepad, "click" with a mouse or keyboard, "tap" on touch.
local function circleVerb(): string
	local last = UserInputService:GetLastInputType().Name
	if last:sub(1, 7) == "Gamepad" then
		return "press A"
	elseif
		last == "Touch" or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
	then
		return "tap"
	end
	return "click"
end

-- #4151: the strip's own lines on the device the player used last, from TutorialHints' keyboard, touch and gamepad
-- versions, so a phone reads "tap Upgrades" and never a letter key. `fallback` only if the id is unknown.
local function deviceLine(id: string, fallback: string): string
	local TutorialHints = require(script.Parent.Parent.UI.Components.TutorialHints) :: any
	local last = UserInputService:GetLastInputType().Name
	local device = if last:sub(1, 7) == "Gamepad"
		then "gamepad"
		elseif
			last == "Touch"
			or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
		then "touch"
		else "keyboard"
	local line: unknown = TutorialHints.lineFor(id, device)
	return if type(line) == "string" and line ~= "" then line else fallback
end

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

-- #1273, analytics only: a funnel step only this client sees (a tutorial card, the catch card), once a session each
-- as TelemetryReport("step", name); the server allowlists the names and logs each once per player.
local stepsReported: { [string]: boolean } = {}
local function reportStep(name: string)
	if not stepsReported[name] then
		stepsReported[name] = true
		Net.fire("TelemetryReport", "step", name)
	end
end

-- #2912: step 3's stray ring follows its stray; this watches it and is dropped on every refresh
local tutorialWatch: { connection: RBXScriptConnection? } = {}

-- #3238: false from dusk to sunrise (the Clock folder's AreasOpen), when the alley has no strays to send anyone to
local function areasShut(): boolean
	local clock = ReplicatedStorage:FindFirstChild("Clock")
	return clock ~= nil and clock:GetAttribute("AreasOpen") == false
end

-- #2912 (shared/StuckGoal): the stuck cat pointer after the first bait cat. `shownAt` is when it first showed this
-- session, `rescuing` while this player's rescue bar is up, `on` what the goal card was last told.
local stuckGoal = {
	shownAt = nil :: number?,
	arrived = false, -- the pointer has aimed at the cat itself once: its clock began again there
	rescuing = false,
	on = false,
	target = nil :: Instance?,
	aside = false, -- near the trap: the marker and trail are put away so the cat's own call shows (StuckGoal.aside)
}

local function stuckGoalActive(s: Types.PlayerState): boolean
	local shownAt = stuckGoal.shownAt
	return StuckGoal.active(
		s.stuckGoal,
		if shownAt ~= nil then os.clock() - shownAt else nil,
		stuckGoal.rescuing or s.carrying ~= nil
	)
end

-- The stuck cat nearest the character in the Alleyway (the starter trap is the one by the camp), nil while none has
-- streamed in.
local function alleyStuckCat(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, model in CollectionService:GetTagged("StuckCat") do
		if model:IsA("Model") and model:GetAttribute("Area") == StuckGoal.AREA then
			local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
			if part ~= nil then
				local distance = (part.Position - root.Position).Magnitude
				if distance < bestDistance then
					best, bestDistance = part, distance
				end
			end
		end
	end
	return best
end

-- The Town Square cannon's part, for the pointer from town.
local function townCannon(): BasePart?
	for _, model in CollectionService:GetTagged("CatCannon") do
		if model:IsA("Model") and model:GetAttribute("CannonId") == "town" then
			return (model :: Model).PrimaryPart
				or model:FindFirstChildWhichIsA("BasePart", true) :: BasePart?
		end
	end
	return nil
end

-- The cannon model with this CannonId ("town", or a camp's area id), for a pointer.
local function cannonPart(id: string): BasePart?
	for _, model in CollectionService:GetTagged("CatCannon") do
		if model:IsA("Model") and model:GetAttribute("CannonId") == id then
			return (model :: Model).PrimaryPart
				or model:FindFirstChildWhichIsA("BasePart", true) :: BasePart?
		end
	end
	return nil
end

-- #3529 (shared/NewKind): the five cats pointer. `idleSince` is the last catch start (or when the goal began or a
-- new kind came), `shownAt` and `shownKinds` when the trail showed and for which count of kinds (it comes back after
-- each new kind), `busy` while a catch or rescue bar is up, `goal` what the goal card was last told.
local newKind = {
	idleSince = os.clock(),
	shownAt = nil :: number?,
	shownKinds = nil :: number?,
	kinds = -1,
	busy = false,
	goal = nil :: number?,
	target = nil :: Instance?,
	where = "none" :: NewKind.Where,
	reported = {} :: { [string]: boolean },
}

-- Different kinds of cat this state owns toward rank up (the sync's own collection, not the UI's last copy).
local function kindsOf(s: Types.PlayerState): number
	return NewKindEconomy.rankUpCatCount(s.collection)
end

-- Whether five different cats is the goal now (the switch on, the Grand Opening's next milestone, under five kinds).
local function newKindGoal(s: Types.PlayerState): boolean
	if s.tutorialStep < 5 or not UI.newKind.on() then
		return false
	end
	local opening = s.grandOpening
	local current = if opening ~= nil then GrandOpening.current(opening) else nil
	local step = if current ~= nil then GrandOpening.STEPS[current] else nil
	return NewKind.goal(true, if step ~= nil then step.id else nil, kindsOf(s))
end

-- Whether the trail shows now. The stuck cat pointer (#2912) wins, and it never shows while carrying.
local function newKindTrail(s: Types.PlayerState): boolean
	if not newKindGoal(s) or stuckGoalActive(s) then
		return false
	end
	local kinds = kindsOf(s)
	local shownAt = if newKind.shownKinds == kinds then newKind.shownAt else nil
	return NewKind.trail(
		true,
		newKind.busy or s.carrying ~= nil,
		os.clock() - newKind.idleSince,
		if shownAt ~= nil then os.clock() - shownAt else nil
	)
end

-- What the trail leads to now: the nearest NEW stray in the area, the town's cannon from town, the camp's cannon
-- when the area has none and another area is open, else nothing.
local function newKindTarget(s: Types.PlayerState): (NewKind.Where, BasePart?)
	local area: string? = (UI.cannon :: any).area
	local stray = if area ~= nil then UI.newKind.nearest(area) else nil
	local open = 0
	for _, def in Catalog.areas do
		if def.tier <= s.tier then
			open += 1
		end
	end
	local where: NewKind.Where = NewKind.where(area, not areasShut(), stray ~= nil, open > 1)
	local target: BasePart? = nil
	if where == "stray" then
		target = stray
	elseif where == "cannon" then
		target = cannonPart("town")
	elseif where == "next" and area ~= nil then
		target = cannonPart(area)
	end
	return where, target
end

local function reportNewKind(kind: string)
	if not newKind.reported[kind] then
		newKind.reported[kind] = true
		Net.fire("TelemetryReport", "new_kind_trail", kind)
	end
end

-- the first catch line's wait after a carry ends (see refreshTutorial)
local CARRY_SETTLE = 0.6
local tutorialCarry = { was = false, endedAt = -math.huge }

-- #3995 (friend-join-3995.md 6, palJoin switch): a new player who joined through a friend and got the cafe next door
-- reads "Your cafe is next to Sam's: step inside 🐾" as the strip's first line, with the trail to their own door,
-- until they first stand inside it; then the tutorial goes on as normal. `pal` is the friend's user id.
local palJoin = { pal = 0, nextDoor = false, entered = false, watching = false }
local PAL_JOIN_WAIT = 5 -- seconds the joiner's note waits for the server's PalNextDoor attribute
local PAL_JOIN_CHECK = 0.5 -- seconds between the "inside your cafe yet?" checks

-- Whether this player's character stands inside their own cafe (over its Floor, under the roof).
local function insideOwnCafe(): boolean
	local plot = ownPlot()
	local floor = if plot ~= nil then plot:FindFirstChild("Floor") else nil
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if floor == nil or not floor:IsA("BasePart") or root == nil or not root:IsA("BasePart") then
		return false
	end
	local offset = (floor :: BasePart).CFrame:PointToObjectSpace((root :: BasePart).Position)
	local half = (floor :: BasePart).Size / 2
	return math.abs(offset.X) <= half.X
		and math.abs(offset.Z) <= half.Z
		and offset.Y >= -2
		and offset.Y <= 14
end

-- The strip's next-door line while it applies (true), else false and the usual first line shows.
local function palJoinLine(s: Types.PlayerState): boolean
	if not palJoin.nextDoor or palJoin.entered or s.tutorialStep >= 2 then
		return false
	end
	local PalsLogic = require(script.Parent.Parent.UI.Components.PalsLogic) :: any
	local pal = Players:GetPlayerByUserId(palJoin.pal)
	UI.tutorial.show(
		PalsLogic.nextDoorLine(if pal ~= nil then pal.DisplayName else nil),
		UIController.ownDoor(),
		"Your cafe"
	)
	return true
end

local function refreshTutorial(s: Types.PlayerState)
	if tutorialWatch.connection ~= nil then
		tutorialWatch.connection:Disconnect()
		tutorialWatch.connection = nil
	end
	newKind.target = nil -- #3529: set again below only while its trail is what shows
	newKind.where = "none"
	if s.carrying ~= nil then
		tutorialCarry.was = true
		UI.tutorial.hide()
		return
	end
	-- Review-QA's fresh join runs, 2026-11-12: as the first cat is secured the server's sync that ends the carry comes
	-- a moment before the one that moves the tutorial on, so "Follow the trail and catch the cat!" came back for
	-- about 0.2 s. The first catch line now waits CARRY_SETTLE after a carry ends; a cat that was dropped, not
	-- secured, gets its line back then.
	if tutorialCarry.was then
		tutorialCarry.was = false
		tutorialCarry.endedAt = os.clock()
	end
	if s.tutorialStep < 2 and os.clock() - tutorialCarry.endedAt < CARRY_SETTLE then
		UI.tutorial.hide()
		task.delay(CARRY_SETTLE, function()
			local current = state
			if current ~= nil and current.carrying == nil then
				refreshTutorial(current)
			end
		end)
		return
	end
	-- the cards the funnel counts: 0 (to the alley), 1 (catch the cat), 3 (a table) and 4 (the bowl and its food);
	-- card 2 shows only when the first cat found no free role
	if s.tutorialStep <= 1 or s.tutorialStep == 3 or s.tutorialStep == 4 then
		reportStep(string.format("tut_%d_shown", s.tutorialStep))
	end
	-- #2636 (onboarding_v6): the first instruction after the first check-in (card 2, 3 or 4) is on screen
	if s.tutorialStep >= 2 and s.tutorialStep <= 4 then
		reportStep("next_goal_shown")
	end
	if s.tutorialStep < 2 and palJoinLine(s) then
		return
	end
	if s.tutorialStep < 2 then
		showTutorial(
			s,
			string.format(
				"Go out your back door to the alley. %s, then %s as each circle closes",
				swingHint(),
				circleVerb()
			),
			tutorialStrayPoint(),
			"Alley"
		)
	elseif s.tutorialStep == 2 then
		if hasRestingCatAndFreeSpot(s) then
			showTutorial(
				s,
				deviceLine("job", "Open Cats and give your new cat a job"),
				restingCat(),
				"Cat"
			)
		else
			showTutorial(s, deviceLine("more", "Catch more cats, or buy a table in Upgrades"))
		end
	elseif s.tutorialStep == 3 then
		-- #2912: with one cat, ring the nearest Alleyway stray (or where the tutorial stray waits) as well as the table;
		-- a stray caught by someone else or run off picks the next one. #3022: one cat caught (stats.catsCaught): the
		-- cafe's own count was 2 after the first catch, with the starter Tabby, so this never showed
		if not SecondCat.done(s.stats) and areasShut() then
			-- #3238: at night the strays are gone and the server picks the waiting one at sunrise, so say so and
			-- point at the table instead of an empty alley
			showTutorial(s, deviceLine("secondNight", "Strays return at sunrise, or open Upgrades"))
		elseif not SecondCat.done(s.stats) then -- #3160, #3551: the bowl's cat never ends it
			local stray = nearestAlleyStray()
			showTutorial(
				s,
				deviceLine("second", "Catch another cat 🐾"), -- #4097: one ask by day
				stray or tutorialStrayPoint(),
				"Catch another cat"
			)
			if stray ~= nil then
				tutorialWatch.connection = stray.AncestryChanged:Connect(function()
					if not stray:IsDescendantOf(Workspace) then
						local current = state
						if current ~= nil then
							refreshTutorial(current)
						end
					end
				end)
			end
		else
			showTutorial(s, deviceLine("table", "Open Upgrades and buy a table: more tips per cat"))
		end
	elseif s.tutorialStep == 4 then
		-- gdd "The first ten minutes" beat 4: the bowl, then food in it (BaitService finishes the tutorial)
		-- (the HUD strip shows about 50 characters on one line, reviewer N94)
		if (s.upgradeLevels.lure_bowl or 0) < 1 then
			showTutorial(s, deviceLine("bowl", "Open Upgrades and buy the Bait bowl"))
		elseif s.bait ~= nil then
			-- #3158: the first bait holds step 4 until its cat is tamed or let go (the line is TutorialHints'
			-- "waiting", then "arrived")
			showTutorial(s, "A cat is on its way to your bowl", UIController.ownBaitBowl(), "Bowl")
		else
			showTutorial(
				s,
				deviceLine("food", "Put Kibble in your bowl on the back step"),
				UIController.ownBaitBowl(),
				"Bowl"
			)
		end
	elseif stuckGoalActive(s) then
		-- #2912: after the walk-through, to the Alleyway's stuck cat (the cannon first from town); nothing at night,
		-- when the goal card says the cats come back at sunrise
		local where = StuckGoal.where((UI.cannon :: any).area, not areasShut())
		local target: BasePart? = nil
		if where == "cat" then
			target = alleyStuckCat()
		elseif where == "cannon" then
			target = townCannon()
		end
		if target == nil then
			UI.tutorial.hide()
		else
			if stuckGoal.shownAt == nil then
				stuckGoal.shownAt = os.clock()
			end
			if where == "cat" and not stuckGoal.arrived then
				-- Review-QA on #3528: a slow new player lost the pointer at the camp, before the trap. The clock
				-- begins again once, on arrival in the Alleyway.
				stuckGoal.arrived = true
				stuckGoal.shownAt = os.clock()
			end
			if where == "cat" and stuckGoal.aside then
				UI.tutorial.hide()
			else
				showTutorial(
					s,
					if where == "cat" then StuckGoal.LINE else StuckGoal.TOWN_LINE,
					target,
					if where == "cat" then StuckGoal.LABEL else "Cannon"
				)
			end
		end
		stuckGoal.target = target
	elseif newKindTrail(s) then
		-- #3529: to the nearest stray of a kind the player has never owned, while five different cats is the goal
		local where, target = newKindTarget(s)
		if target == nil then
			UI.tutorial.hide()
		else
			local kinds = kindsOf(s)
			if newKind.shownKinds ~= kinds or newKind.shownAt == nil then
				newKind.shownKinds = kinds
				newKind.shownAt = os.clock()
			end
			reportNewKind("shown")
			showTutorial(
				s,
				if where == "stray"
					then NewKind.LINE
					elseif where == "next" then NewKind.NEXT_AREA
					else NewKind.CANNON_LINE,
				target,
				if where == "stray" then NewKind.LABEL else "Cannon"
			)
		end
		newKind.target = target
		newKind.where = where :: any -- typed NewKind.Where by newKindTarget; the checker widens it here
	else
		UI.tutorial.hide()
	end
end

-- #3995: watches for the joiner's first step inside their own cafe, then puts the strip back to the tutorial's own
-- first line. Gives up once the tutorial has moved past its first steps.
local function watchPalJoin()
	if palJoin.watching then
		return
	end
	palJoin.watching = true
	task.spawn(function()
		while not palJoin.entered do
			task.wait(PAL_JOIN_CHECK)
			local current = state
			if current ~= nil and current.tutorialStep >= 2 then
				break
			end
			if insideOwnCafe() then
				palJoin.entered = true
				local now = state
				if now ~= nil then
					refreshTutorial(now)
				end
			end
		end
		palJoin.watching = false
	end)
end

-- #3995 (friend-join-3995.md 4 to 6): PalArrived with the palJoin switch on. The joiner's note waits a moment for the
-- server's PalNextDoor attribute (it is set once the save and the plot are in), then shows; a new joiner next door
-- gets the strip's next-door line. The friend gets their note at once.
function UIController.palJoined(joinerId: number, palId: number)
	if joinerId ~= player.UserId and palId ~= player.UserId then
		return
	end
	local LiveFlags = require(Shared:WaitForChild("LiveFlags")) :: any
	local PalJoin = require(Shared:WaitForChild("PalJoin")) :: any
	local key: string = PalJoin.FLAG
	if
		not LiveFlags.shown(key, ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. key))
	then
		return
	end
	local hook: unknown = (UI :: any).palJoined
	if type(hook) ~= "function" then
		return
	end
	local show = hook :: (number, number, boolean?) -> ()
	if palId == player.UserId then
		show(joinerId, palId, nil)
		return
	end
	task.spawn(function()
		local attribute: string = PalJoin.ATTRIBUTE
		local started = os.clock()
		while player:GetAttribute(attribute) == nil and os.clock() - started < PAL_JOIN_WAIT do
			task.wait(0.25)
		end
		local nextDoor = player:GetAttribute(attribute) == true
		show(joinerId, palId, nextDoor)
		if nextDoor then
			palJoin.pal = palId
			palJoin.nextDoor = true
			local now = state
			if now ~= nil then
				refreshTutorial(now)
			end
			watchPalJoin()
		end
	end)
end

-- Role changes since the last sync, for the sounds (sound list: place and unplace): a cat newly in a role or moved
-- to another fires CatPlaced with the role, a cat taken off fires UnplaceCat. Unequip all fires one per cat.
-- (#2952's CatSold moment is unused since 2026-11-13: cats are not sold.)
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

-- Something bought since the last sync: an upgrade level, a decor item, a lawn piece or style (F91, front-lawn.md
-- section 3, which also sparkles the Tier 2 and 3 gifts) or a lure count went up.
local function boughtSomething(
	old: Types.PlayerState,
	new: Types.PlayerState,
	shopBuy: boolean
): boolean
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
	for id, owned in new.lawnOwned do
		if owned and not old.lawnOwned[id] then
			return true
		end
	end
	for id, count in new.lures do
		if not shopBuy and count > (old.lures[id] or 0) then
			return true
		end
	end
	return false
end

-- The cat at a bowl as the bait card wants it, or nil while the bowl is empty or its cat is on the way.
local function baitCat(bait: Types.BaitView?): UITypes.BaitCat?
	local cat = if bait ~= nil then bait.cat else nil
	if cat == nil then
		return nil
	end
	return { catId = cat.catId, variant = cat.variant, charm = cat.charm, stars = cat.stars }
end

-- #1161: bowl 1 is ProfileSync's bait, bowl 2 its bait2 (the Second Bait Bowl pass).
local function bowlBait(s: Types.PlayerState, index: number): Types.BaitView?
	return if index == 2 then s.bait2 else s.bait
end

-- The UI's bait API with the bowl argument (#1161). Older UI builds take one bowl and ignore the extra argument,
-- and have no setSecond, so the calls go through `any` and setSecond is looked up first.
local baitUI: any = UI.bait

-- The own cafe's bowl anchors (F28; #1161: BaitBowl2 is the second bowl).
local function ownBowlPart(index: number): BasePart?
	if index == 1 then
		return UIController.ownBaitBowl()
	end
	local plot = ownPlot()
	local bowl = if plot ~= nil then plot:FindFirstChild("BaitBowl2") else nil
	return if bowl ~= nil and bowl:IsA("BasePart") then bowl :: BasePart else nil
end

-- A bowl's window, as its prompt or its walk-up ring (#2476) opens it: the cat waiting there, else the food picker.
function UIController.openBowl(index: number)
	local waiting = if state ~= nil then baitCat(bowlBait(state, index)) else nil
	if waiting ~= nil then
		baitUI.showReady(waiting, index)
	else
		UI.bait.openPicker()
	end
end

-- #2476: the own cafe's first bowl model, whose walk-up ring the server puts beside it, and its owner prompt, for
-- WalkUpController. Nil before the Bait bowl is bought.
function UIController.ownBowlModel(): Model?
	local plot = ownPlot()
	local folder = if plot ~= nil then plot:FindFirstChild("Bait") else nil
	local bowl = if folder ~= nil then folder:FindFirstChild("Bowl") else nil
	return if bowl ~= nil and bowl:IsA("Model") then bowl :: Model else nil
end

function UIController.bowlPrompt(): ProximityPrompt?
	local prompt = bowlPrompts[1]
	return if prompt ~= nil and prompt.Parent ~= nil then prompt else nil
end

-- One bowl's owner prompt (made here so only the owner sees it): "See the cat", "Check" or "Add food". Gone while
-- `show` is false.
local function refreshBowlPrompt(
	index: number,
	part: BasePart?,
	show: boolean,
	bait: Types.BaitView?
)
	local prompt = bowlPrompts[index]
	if show and part ~= nil then
		local float = if prompt ~= nil then prompt.Parent else nil
		if prompt == nil or float == nil or float.Parent ~= part then
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
			point.Parent = part
			local made = Instance.new("ProximityPrompt")
			made.Name = "BaitPrompt"
			made.ObjectText = if index == 2 then "Bait bowl 2" else "Bait bowl"
			made.HoldDuration = 0
			made.MaxActivationDistance = 8
			made.RequiresLineOfSight = true -- on the back step: no pill through the back wall from inside (N91)
			made.Style = Enum.ProximityPromptStyle.Custom
			made.Triggered:Connect(function()
				UIController.openBowl(index)
			end)
			made.Parent = point
			bowlPrompts[index] = made
			prompt = made
		end
		local shown = prompt :: ProximityPrompt
		shown.Enabled = not (UI :: any).cutscene.on -- #4018: hidden while a cutscene plays
		shown.ActionText = if baitCat(bait) ~= nil
			then "See the cat"
			elseif bait ~= nil then "Check"
			else "Add food"
	elseif prompt ~= nil then
		local float = prompt.Parent
		prompt:Destroy()
		if float ~= nil and float:IsA("Attachment") then
			float:Destroy()
		end
		bowlPrompts[index] = nil
	end
end

-- The bait bowls (F28, data-model section 8; #1161: a second with the pass): what is in each, the owner's prompt
-- on each and the card the moment a bowl's cat arrives. ProfileSync names the cat only once it has arrived, so its
-- first appearance is the arrival. placedAt sets the fill bar's length and night (F60) the countdown's moon.
local function refreshBait(s: Types.PlayerState)
	local setSecond: ((string?) -> ())? = baitUI.setSecond
	if setSecond ~= nil then
		setSecond(s.secondBowl)
	end
	local owned = (s.upgradeLevels.lure_bowl or 0) >= 1
	for index = 1, 2 do
		local bait = bowlBait(s, index)
		baitUI.set(
			if bait ~= nil
				then {
					lureId = bait.lureId,
					readyAt = bait.readyAt,
					placedAt = bait.placedAt,
					night = bait.night,
				}
				else nil,
			index
		)
		local part = ownBowlPart(index)
		if index == 1 then
			UI.bait.setBowl(part)
		end
		-- bowl 2 shows with the pass, and while food is still in it after the pass went (the server builds it then)
		local show = owned and (index == 1 or s.secondBowl == "on" or bait ~= nil)
		refreshBowlPrompt(index, part, show, bait)

		local cat = baitCat(bait)
		if cat ~= nil and bait ~= nil then
			local key = string.format("%s@%d", cat.catId, bait.readyAt)
			if key ~= shownBaitKeys[index] then
				shownBaitKeys[index] = key
				baitUI.arrived(cat, index) -- #2014: waits while a catch or rescue runs
			end
		end
	end
end

-- The rich tip (F31): the UI's gold marker watches the own plot, and the tip's arrival and payout are Moments for
-- the sounds. Its RichTipAmount clears on a claim and when the tip is missed (expiry, nightfall); the server sets
-- RichTipOutcome just before, and only a claim plays the payout.
local richTipPlot: Model? = nil
local richTipConnection: RBXScriptConnection? = nil
local richVisitConnection: RBXScriptConnection? = nil
local richTipAmount = 0
-- #2792: the same plot's FirstVisit attribute (a new account's first special visitor at the cafe), for the UI's arrival
-- line; its connection lives here next to the rich tip's
local firstVisit = { connection = nil :: RBXScriptConnection? }

-- How far the character stands from `plot`, or nil before the character loads.
function firstVisit.distance(plot: Model): number?
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	return (root.Position - plot:GetPivot().Position).Magnitude
end

function firstVisit.bind(plot: Model?)
	if firstVisit.connection ~= nil then
		firstVisit.connection:Disconnect()
		firstVisit.connection = nil
	end
	if plot == nil then
		UI.firstVisit.changed(nil, function()
			return false
		end)
		return
	end
	local function away(): boolean
		return FirstVisitLogic.away(firstVisit.distance(plot))
	end
	firstVisit.connection = plot:GetAttributeChangedSignal("FirstVisit"):Connect(function()
		UI.firstVisit.changed(plot:GetAttribute("FirstVisit"), away)
	end)
	UI.firstVisit.changed(plot:GetAttribute("FirstVisit"), away) -- a visit already waiting at a rejoin
end

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
	if richVisitConnection ~= nil then
		richVisitConnection:Disconnect()
		richVisitConnection = nil
	end
	richTipPlot = plot
	UI.richTip.bind(plot)
	firstVisit.bind(plot)
	if plot == nil then
		return
	end
	richTipAmount = tipAmount(plot)
	-- the arrival sound is for a drop (the plot's RichVisitAt, #3360), not for the next waiting bag moving up front
	-- after a claim; one already waiting when this client binds plays nothing
	richVisitConnection = plot:GetAttributeChangedSignal("RichVisitAt"):Connect(function()
		if type(plot:GetAttribute("RichVisitAt")) == "number" then
			Moments.RichArrive:Fire()
		end
	end)
	richTipConnection = plot:GetAttributeChangedSignal("RichTipAmount"):Connect(function()
		local amount = tipAmount(plot)
		if
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

-- The carry banner, marker and door follow the server's carried cat. #3145 (Derek2 2026-11-10: the banner stayed up
-- for a cat that was gone, and Drop did nothing): set again whenever the screen has drifted from the newest sync's
-- value (shared/CarrySync), not only when that value changes; called on every sync and from the camp watch twice a
-- second, so a banner left behind by a sync applied late, or by an error part way, comes down within half a second.
local function refreshCarry()
	local want = latestCarrying
	local view: CarrySync.View = UI.carryView()
	if not CarrySync.stale(want, lastCarrying, view) then
		return
	end
	lastCarrying = want
	if want ~= nil then
		shownCamp = carryCamp()
		UI.setCarrying({ catId = want, door = UIController.ownDoor(), camp = shownCamp })
	else
		shownCamp = nil
		UI.setCarrying(nil)
	end
end

local function applyState(s: Types.PlayerState)
	local previous = state
	local shopBuy = os.clock() - lastCornerShopBuy < CORNER_SHOP_QUIET_SECONDS
	if previous ~= nil and boughtSomething(previous, s, shopBuy) then
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
		prizeRate = s.prizeRate, -- #2539: what coin prizes pay from, for the prize previews
		tier = s.tier,
		-- #2047 (Derek2: "with the extra slots it doesn't show all the working cats"): sent but never copied, so the
		-- Cats window and the Staff tab counted only the tier's slots and hid the pass-only ones with cats on them
		extraSlots = s.extraSlots or 0,
		cafeProgress = s.cafeProgress,
		cafeProgressText = s.cafeProgressText,
		tables = s.tables,
		catsOwned = s.catsOwned,
		upgradeLevels = s.upgradeLevels,
		decorOwned = s.decorOwned,
		decorPlaced = s.decorPlaced,
		decorUnlocked = s.decorUnlocked, -- #1574: the Trade window's Decor tab greys a locked piece
		lures = s.lures,
		cats = s.cats :: any, -- the UI's CatInstance has optional fields; table props are invariant in Luau
		collection = s.collection,
		goldCollection = s.goldCollection,
		rainbowCollection = s.rainbowCollection, -- F99: the Index's Rainbow tab
		rainbowLuck = s.rainbowLuck, -- F99: the food card's "Rainbow 0.5%" line, capped
		carrying = s.carrying,
		-- #3022: the goal card's "Catch a 2nd cat" (PlayerState.secondCat). Sent but never copied, so the card never
		-- showed; false once it ends, as UI.update skips a nil and the card would stay
		secondCat = if s.secondCat ~= nil then s.secondCat else false,
		-- #3188: the "Catch a 2nd cat" goal is finished, so the Daily Treat may open by itself
		secondCatDone = SecondCat.done(s.stats),
		stuckGoal = stuckGoalActive(s), -- #2912: the goal card's "Free a stuck cat" while the pointer may show
		-- #3529: the goal card's "Catch new kinds of cat 3/5" while five different cats is the goal; false otherwise
		newKindGoal = if newKindGoal(s) then kindsOf(s) else false,
		traits = if s.traits ~= nil then s.traits else false, -- #3196: the Mystic Pool's card
		tutorialStep = s.tutorialStep,
		-- #3285: what is in the first bowl, for the tutorial's food step (TutorialHints.view). Without it the HUD's
		-- Bowl ring, its dim and the Kibble row's ring kept asking for food through the wait for the cat. false while
		-- empty, as UI.update skips a nil.
		bait = if s.bait ~= nil then s.bait else false,
		introAuto = s.introAuto, -- #3666
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
		catFood = s.catFood, -- #1181: the Bag's cat food
		hideCredit = s.hideCredit, -- #1083: the Settings row "Show my name on the Thank You board" (on when false)
		buffs = s.buffs, -- F64: each running potion's endsAt in server time
		quests = s.quests :: any, -- F73: the Quests window's tabs and the HUD's quest line (the UI reads it loosely)
		achievements = s.achievements :: any, -- F73: each achievement's progress and claim
		dailyTreat = s.dailyTreat, -- F70: the Daily Treat card, whether a stamp is due and the day it pays
		-- F87 (#705): the tips seen, the one feedback ask and the help cards shown, so a tip the client finds itself
		-- (stuck_cat, codes_cat, offline), the help card and the ask never repeat each session
		tipsSeen = s.tipsSeen,
		feedbackAsked = s.feedbackAsked,
		sessionFeedbackDay = s.sessionFeedbackDay, -- #3272: the once-a-day session ask
		stuckHelpShown = s.stuckHelpShown,
		-- F88: the player's Luck and what makes it, for the HUD chip and its card (luck-and-rare-moments.md section 1)
		luck = s.luck,
		luckSources = s.luckSources,
		longNap = s.longNap, -- F95: the welcome back card's "Full pay, up to 16 hours"
		-- F91: the Front lawn tab and edit view (ui-contract.md "Front lawn tab and edit view"); the tab stays hidden
		-- until lawnStyles arrives
		lawnOwned = s.lawnOwned,
		lawn = s.lawn,
		lawnStyles = s.lawnStyles,
		-- Derek2 live 11-06 (the Starter Bundle card never showed): these were sent but never copied, so the Store,
		-- the money card's Boosts list, the Style tab's sign, theme and uniform rows and the Trades page read nil
		starterBought = s.starterBought, -- #1625: the Starter Bundle card shows while false
		-- #2555: the free Bellhop Cat's stand "!" (#2501) and its speech bubble show only while this is false
		starterCatClaimed = s.starterCatClaimed,
		storeSeen = s.storeSeen, -- #1823 §4: the Store tabs' New dots
		dailyDeal = s.dailyDeal or false, -- #3996: Today's Deal on the Store's Featured tab
		-- #2574: Juniper's Mystery Market: the items owned, the cart's "!" until the first visit, and whether buys are
		-- taken yet
		mystery = s.mystery,
		mysterySeen = s.mysterySeen,
		mysteryOpen = s.mysteryOpen,
		bagColours = s.bagColours or false, -- #3699: false for the built colours, as UI.update skips a nil
		shoeColours = s.shoeColours or false, -- #4049, the same way
		signStyles = s.signStyles, -- #1625: the Style tab's sign row
		-- #2007: "" for the plain sign, as UI.update skips a nil and the old pick stayed gold
		signStyle = s.signStyle or "",
		looks = s.looks, -- #1624: the Style tab's theme and uniform rows
		jukeboxTracks = s.jukeboxTracks, -- #1168 row 2: the Style tab's music row
		jukebox = s.jukebox or "", -- #2007: "" for the mix, as for the sign
		jukeboxShuffle = if shuffleCues ~= nil then (Jukebox :: any).SHUFFLE else nil, -- #2077
		passBoosts = s.passBoosts, -- #1624: the store passes in the money card's Boosts list
		tradeLog = s.tradeLog, -- F102: the Trades page
		-- #3686: sent since #1714 but never copied, so "Codes you've used" stayed empty in the live game
		codesRedeemed = s.codesRedeemed,
	})
	-- After the first sync, sound and Effects follow UI.settings.changed rather than each sync; the purr follows the
	-- server's carry state.
	if not audioStarted then
		audioStarted = true
		applySettings()
	end
	Audio.setCarrying(s.carrying ~= nil)
	Audio.setTutorial(s.tutorialStep, setting("tutorialButton") ~= false)
	local track = if s.jukebox ~= nil then Jukebox.get(s.jukebox) else nil
	Audio.setJukebox(if track ~= nil then track.cue else nil) -- #1875: the Jukebox pick (free)
	if shuffleCues ~= nil then -- #2077: every song in a random order
		(Audio :: any).setJukeboxShuffle(
			if s.jukebox == (Jukebox :: any).SHUFFLE then shuffleCues else nil
		)
	end
	if lastTier ~= nil and s.tier > (lastTier :: number) then
		Moments.RankUp:Fire(s.tier)
	end
	lastTier = s.tier
	refreshCarry()
	refreshBait(s)
	refreshTutorial(s)
	refreshRichTip()
end

-- The night dealer: the night of the last DealerStock (F94; the 5 minute window before), which a buy sends back when
-- the screen has none.
local dealerWindow: number? = nil

-- Team Rescue (F92, playing-together.md section 3). A stuck cat's model is tagged StuckCat and carries its trap's
-- RescueSpotId, LockedBy (the rescuer, else 0) and HelpedBy (the helper while the attempt runs, else 0).
local function stuckModel(rescueSpotId: string): Instance?
	for _, model in CollectionService:GetTagged("StuckCat") do
		if model:GetAttribute("RescueSpotId") == rescueSpotId then
			return model
		end
	end
	return nil
end

local function lockedByOther(model: Instance): boolean
	local locked = model:GetAttribute("LockedBy")
	return type(locked) == "number" and locked ~= 0 and locked ~= player.UserId
end

-- On this screen a stuck cat's prompt reads "Help" while someone else's bar runs with no helper yet, and hides once
-- a helper has joined (one an attempt); otherwise it stays "Rescue". Only this client's copy of the prompt changes.
local function bindHelpPrompts()
	local function refresh(model: Instance)
		local found = model:FindFirstChild("RescuePrompt", true)
		if found == nil or not found:IsA("ProximityPrompt") then
			return
		end
		local prompt = found :: ProximityPrompt
		local helped = model:GetAttribute("HelpedBy")
		local other = lockedByOther(model)
		prompt.ActionText = if other then "Help" else "Rescue"
		prompt.Enabled = not (
			other
			and type(helped) == "number"
			and helped ~= 0
			and helped ~= player.UserId
		)
	end
	local function watch(model: Instance)
		refresh(model)
		model:GetAttributeChangedSignal("LockedBy"):Connect(function()
			refresh(model)
		end)
		model:GetAttributeChangedSignal("HelpedBy"):Connect(function()
			refresh(model)
		end)
		model.DescendantAdded:Connect(function(added: Instance)
			if added.Name == "RescuePrompt" then
				refresh(model)
			end
		end)
	end
	for _, model in CollectionService:GetTagged("StuckCat") do
		watch(model)
	end
	CollectionService:GetInstanceAddedSignal("StuckCat"):Connect(watch)
end

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
			local current = UIController.state
			if current ~= nil then -- the Tutorial tile's x skips the tutorial music too
				Audio.setTutorial(current.tutorialStep, setting("tutorialButton") ~= false)
			end
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
	-- #1823 §4: a Store tab with a New dot opened; the server saves its version (known tabs only). The server takes
	-- two a second, so tabs tapped faster than that wait their turn here instead of being dropped.
	-- #3996: Today's Deal's R$25: the server checks it is today's, not bought yet, and opens the prompt (1 a second)
	UI.events.storeDeal:Connect(function(productId: string)
		if type(productId) == "string" then
			Net.fire("PromptDeal", productId)
		end
	end)
	local seenQueue: { string } = {}
	local seenSending = false
	UI.events.storeSeen:Connect(function(tab: string)
		if table.find(seenQueue, tab) then
			return
		end
		table.insert(seenQueue, tab)
		if seenSending then
			return
		end
		seenSending = true
		task.spawn(function()
			while #seenQueue > 0 do
				Net.fire("MarkStoreSeen", table.remove(seenQueue, 1) :: string)
				task.wait(0.6)
			end
			seenSending = false
		end)
	end)
	-- Use all on the Spin window (#1078); the server answers with SpinAllResult and a ProfileSync. Loose until
	-- UI-Engineer's button is on main, as are the Corner Shop's hooks below.
	local looseEvents: any = UI.events
	if looseEvents.spinAll ~= nil then
		looseEvents.spinAll:Connect(function()
			Net.fire("SpinAll")
		end)
	end
	-- Buy on a Corner Shop row (#1052): the window and price the row showed, and for a snack the cat picked.
	if looseEvents.buyCornerShop ~= nil then
		looseEvents.buyCornerShop:Connect(
			function(itemId: string, window: number, shownPrice: number, catUid: string?)
				lastCornerShopBuy = os.clock()
				Net.fire("BuyCornerShop", itemId, window, shownPrice, catUid)
			end
		)
	end
	-- #2574: Buy in Juniper's window, with the price it showed (the server refuses a sale that ended meanwhile), and
	-- the first open, which clears the cart's "!"
	if looseEvents.buyMystery ~= nil then
		looseEvents.buyMystery:Connect(function(itemId: string, shownPrice: number)
			Net.fire("BuyMystery", itemId, shownPrice)
		end)
	end
	if looseEvents.mysterySeen ~= nil then
		looseEvents.mysterySeen:Connect(function()
			Net.fire("MarkMysterySeen")
		end)
	end
	-- #3699: Save on the Backpack's colour picker; the server checks both ids and that the Backpack is owned
	if looseEvents.setBagColours ~= nil then
		looseEvents.setBagColours:Connect(function(main: string, trim: string, kind: string?)
			Net.fire("SetBagColours", main, trim, kind) -- #4049: kind "shoes" for the Speed Shoes
		end)
	end
	-- #2593: Buy all on a Day Cart section; the server plans from its own state and answers with CornerShopStock
	if looseEvents.buyCornerShopAll ~= nil then
		looseEvents.buyCornerShopAll:Connect(function(kind: string, window: number)
			Net.fire("BuyCornerShopAll", kind, window)
		end)
	end
	-- Feed on the Bag's Cat Food tab or a cat card (#1181): the server answers FeedResult and a ProfileSync, or a toast.
	-- Loose until UI-Engineer's Signal (friend/bag-ui) is on main.
	if looseEvents.feedCat ~= nil then
		looseEvents.feedCat:Connect(function(foodId: string, catUid: string)
			Net.fire("FeedCat", foodId, catUid)
		end)
	end
	-- Use on a potion in the bag (F64); the server answers with a ProfileSync, or a "Full" toast.
	-- #1600: Use all sends a count; the server drinks as many as fit under PotionMaxMinutes in one sync
	UI.events.usePotion:Connect(function(potionId: string, count: number?)
		Net.fire("UsePotion", potionId, count)
	end)
	-- #3326: the Bag's "Use all potions", after its confirm card; the server drinks every kind that fits
	UI.events.usePotionAll:Connect(function()
		Net.fire("UsePotionAll")
	end)
	-- #1463: Collect on the Woods card (Golden Pond pass, camp-extras.md section 4). The server checks the pass, the
	-- range and the extraId. Guarded until the UI's collectCampExtra event (PR #1472) is on main.
	local collectCampExtra = (UI.events :: any).collectCampExtra
	if collectCampExtra then
		collectCampExtra:Connect(function(extraId: string)
			Net.fire("CollectCampExtra", extraId)
		end)
	end
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
	-- Buy 5 on a Market crate card (#1051): banks five of that crate; the server answers with a toast and a ProfileSync.
	-- Loose until UI-Engineer's Signal (friend/crate-prices-ui) is on main.
	if uiEvents.buyCrateBundle ~= nil then
		uiEvents.buyCrateBundle:Connect(function(crateId: string)
			Net.fire("BuyCrateBundle", crateId)
		end)
	end
	-- #2402: Open all on a Market crate card; the server answers with CrateAllResult and a ProfileSync.
	if uiEvents.openAllCrates ~= nil then
		uiEvents.openAllCrates:Connect(function(crateId: string)
			Net.fire("OpenAllCrates", crateId)
		end)
	end
	-- Send on Report a bug; the server answers with a toast, which the window reads to close or keep the text.
	-- featureName (#1083, #3653): true for an idea (every idea may be credited; the server decides), nil otherwise.
	UI.events.reportBug:Connect(
		function(text: string, kind: string, clientErrors: { string }, featureName: boolean?)
			Net.fire("ReportBug", text, kind, clientErrors, featureName)
		end
	)
	-- Settings' "Show my name on the Thank You board" (#1083): true keeps the name off. Loose until UI-Engineer's Signal.
	if uiEvents.setHideCredit ~= nil then
		uiEvents.setHideCredit:Connect(function(hide: boolean)
			Net.fire("SetHideCredit", hide)
		end)
	end
	-- #1770 owner test mode: the server drops it from anyone but the owner's account
	UI.events.ownerGrant:Connect(function(productId: number)
		Net.fire("OwnerGrant", productId)
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
	-- The front lawn (F91): the Garden Nursery's Buy. The answer is a toast and the next ProfileSync.
	UI.events.buyLawn:Connect(function(id: string, spotId: string?)
		Net.fire("BuyLawn", id, spotId)
	end)
	UI.events.buyLure:Connect(function(lureId: string)
		Net.fire("BuyLure", lureId)
	end)
	-- The bait bowl (F28): Use on a food, then Tame or Let go on the card. The answer is the next ProfileSync.
	-- #1161: `bowl` is 1 or 2 from a UI with two bowls, nil (bowl 1) from an older one.
	UI.events.useLure:Connect(function(lureId: string, bowl: number?)
		Net.fire("UseLure", lureId, bowl)
	end)
	UI.events.resolveBait:Connect(function(choice: string, bowl: number?)
		Net.fire("ResolveBait", choice, bowl)
	end)
	UI.events.placeCat:Connect(function(uid: string, spotId: string)
		Net.fire("PlaceCat", uid, spotId)
	end)
	UI.events.unplaceCat:Connect(function(uid: string)
		Net.fire("UnplaceCat", uid)
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
	-- Equip Best on the Decor page (Derek 2026-10-28; shown once Config.DecorEquipBest is true), looked up loosely the
	-- same way: the server puts out the best owned decor and answers with a toast and a sync.
	local equipBestDecor = (UI.events :: any).equipBestDecor
	if equipBestDecor ~= nil then
		equipBestDecor:Connect(function()
			Net.fire("EquipBestDecor")
		end)
	end
	-- Reset my save (Derek's notes: for testing): the Settings row shown while the Player attribute Tester is true,
	-- after its own confirm; the server checks the tester again, then saves a fresh save and kicks.
	local resetSave = (UI.events :: any).resetSave
	if resetSave ~= nil then
		resetSave:Connect(function()
			Net.fire("ResetSave")
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
		-- #2873 (console, #2871): DPad down drops too, one cat a press like G (the hands first, then the Backpack). Not
		-- while a window is open or the UI took the press (selection mode), and the server refuses it mid catch.
		UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
			if gameProcessed or input.KeyCode ~= Enum.KeyCode.DPadDown or UI.isOpen() ~= nil then
				return
			end
			local character = player.Character
			local packedId = if character ~= nil then character:GetAttribute("PackedCatId") else nil
			if lastCarrying ~= nil or packedId ~= nil then
				dropCat:Fire()
			end
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
	-- Collect on the rich tip marker (F31), or walking into a money bag (#3360): that bag, by its id. The server
	-- sets the bag record's Outcome, which the UI floats as "+$X".
	UI.events.claimRichTip:Connect(function(bagId: string)
		Net.fire("ClaimRichTip", bagId)
	end)
	-- #3196: the Mystic Pool's card. The server checks the cat, the payment and the waiting re-roll again.
	-- The pool's own animation plays at the station when it is in the world and near (Effects/MysticPool.roll, with
	-- the rolled cat's model when its art is loaded); opened from the Cannon menu far away, the card shows the
	-- result with no animation.
	local function poolStation(): Model?
		local found = CollectionService:GetTagged(Traits.TAG)[1]
		if found ~= nil and found:IsA("Model") and found:IsDescendantOf(workspace) then
			return found :: Model
		end
		return nil
	end
	local function poolDistance(): number?
		local station = poolStation()
		local character = Players.LocalPlayer.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if station == nil or root == nil or not root:IsA("BasePart") then
			return nil
		end
		return (station:GetPivot().Position - root.Position).Magnitude
	end
	local mysticPool: any = (UI :: any).mysticPool
	mysticPool.cutting = function(): boolean -- #3846: the bait and gift cards wait while it plays
		return BigTraitCut.playing() or RiftRun.playing()
	end
	-- the Rift Run (Effects/RiftRun): toasts and shout-outs wait through it and the bowl, tip, ask, first visit and
	-- Unlocked cards hold (UI.setCutscene, #4018); the own bait bowls' prompts are hidden until it ends (from #4077)
	table.insert((UI :: any).cutscene.hooks, function(on: boolean)
		for _, prompt in bowlPrompts do
			if prompt ~= nil and prompt.Parent ~= nil then
				prompt.Enabled = not on
			end
		end
	end)
	RiftRun.onHold(UI.setCutscene)
	-- #4062: the Dragon Keep's stage-up cutscene holds them the same way
	DragonRise.onHold(UI.setCutscene)
	mysticPool.far = function(): boolean
		local distance = poolDistance()
		return distance == nil or distance > POOL_FAR_STUDS
	end
	mysticPool.play = function(uid: string, rarity: string, onReveal: () -> ()): (() -> ())?
		local station = poolStation()
		local distance = poolDistance()
		-- #3846: a Legendary or Mythic roll gets its cutscene first, at the pool or (away from it) on the screen
		local big = BigTraitCut.wanted(rarity)
		if station == nil or distance == nil or distance > POOL_SEEN_STUDS then
			return if big then BigTraitCut.screen(rarity, onReveal) else nil
		end
		local state: any = UIController.state
		local cat = if state ~= nil and type(state.cats) == "table" then state.cats[uid] else nil
		local asset: string? = if type(cat) == "table" and type(cat.catId) == "string"
			then Catalog.sitModelName(Catalog.catModelName(cat.catId))
			else nil
		local pool = station :: Model
		if big then
			return BigTraitCut.atPool(pool, rarity, function(reveal: () -> ()): () -> ()
				local lift, height = BigTraitCut.liftFor(rarity)
				return MysticPool.roll(pool, asset, rarity, reveal, lift, false, height)
			end, onReveal)
		end
		return MysticPool.roll(pool, asset, rarity, onReveal)
	end
	-- Derek 2026-11-13: a Mythic or Secret roll first runs the Rift Run with the rolled cat, then lands back in the
	-- pool for the big moment (or, far from the pool, the screen's) and the card
	local playPool: (uid: string, rarity: string, onReveal: () -> ()) -> (() -> ())? =
		mysticPool.play
	mysticPool.play = function(uid: string, rarity: string, onReveal: () -> ()): (() -> ())?
		if not RiftRun.wanted(rarity) then
			return playPool(uid, rarity, onReveal)
		end
		local state: any = UIController.state
		local cat = if state ~= nil and type(state.cats) == "table" then state.cats[uid] else nil
		local catId: string? = if type(cat) == "table" and type(cat.catId) == "string"
			then cat.catId
			else nil
		local gold = type(cat) == "table" and cat.gold == true
		return RiftRun.play(
			rarity,
			{ catId = catId, gold = gold },
			function(reveal: () -> ()): (() -> ())?
				local station = poolStation()
				local distance = poolDistance()
				if station == nil or distance == nil or distance > POOL_SEEN_STUDS then
					return BigTraitCut.screen(rarity, reveal)
				end
				local pool = station :: Model
				local asset: string? = if catId ~= nil
					then Catalog.sitModelName(Catalog.catModelName(catId :: string))
					else nil
				return BigTraitCut.atPool(pool, rarity, function(landed: () -> ()): () -> ()
					local lift, height = BigTraitCut.liftFor(rarity)
					return MysticPool.roll(pool, asset, rarity, landed, lift, true, height)
				end, reveal)
			end,
			onReveal
		)
	end
	-- Studio only: the Workspace attribute RiftRunTest ("mythic" or "secret") plays the Rift Run with this player's
	-- first cat, as if that roll had come, so it can be watched without rolling one (Review-QA)
	if RunService:IsStudio() then
		Workspace:GetAttributeChangedSignal("RiftRunTest"):Connect(function()
			local rarity = RiftRun.testRarity()
			local state: any = UIController.state
			if rarity == nil or state == nil or type(state.cats) ~= "table" then
				return
			end
			local uid = next(state.cats)
			if type(uid) == "string" then
				mysticPool.play(uid, rarity, function() end)
			end
		end)
	end
	UI.events.rollTrait:Connect(function(uid: string)
		Net.fire("RollTrait", uid)
	end)
	UI.events.chooseTrait:Connect(function(takeNew: boolean)
		Net.fire("ChooseTrait", takeNew == true)
	end)
	UI.events.collectTraitTokens:Connect(function()
		Net.fire("CollectTraitTokens")
	end)
	-- #2854: the Rewards list's Cozy gift row takes the waiting bag; the server pays it and toasts
	UI.events.takeCozy:Connect(function()
		Net.fire("TakeCozy")
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
	-- Claim all in the Quests window ("daily", "weekly", "achievements"), the Index ("index") and the Tip Jar
	-- ("tipjar"): the server pays every ready one with one toast and a sync (QuestResult, TipJarState).
	UI.events.claimAll:Connect(function(what: string)
		Net.fire("ClaimAll", what)
	end)
	-- #1646 (cafe-pass.md section 5): Claim and Claim all on the Pass window; the server checks the level, the track
	-- and the claim, pays through Payout and answers with CafePassState and a toast.
	UI.events.passClaim:Connect(function(track: string, level: number)
		Net.fire("PassClaim", track, level)
	end)
	UI.events.passClaimAll:Connect(function()
		Net.fire("PassClaimAll")
	end)
	-- #1626: the chat tag pick; the server takes one of the player's tags or "off" and answers with CafePassState
	UI.events.passSetTag:Connect(function(pick: string)
		Net.fire("PassSetTag", pick)
	end)
	-- #1624: a Style tab button. The sign's "" is the plain sign (nil); the server checks the player owns the style.
	-- Uniforms and themes only show once the server sends state.looks, which comes with SetLook.
	-- #1751: the Lawn cards' Use and Remove; LawnService (#1758) checks and toasts any refusal
	UI.events.setLawnSpot:Connect(function(spotId: string, pieceId: string)
		Net.fire("SetLawnSpot", spotId, pieceId)
	end)
	UI.events.setLawnStyle:Connect(function(kind: string, id: string)
		Net.fire("SetLawnStyle", kind, id)
	end)
	UI.events.pickStyle:Connect(function(kind: string, id: string)
		if kind == "sign" then
			Net.fire("SetSignStyle", if id == "" then nil else id)
		elseif kind == "uniform" or kind == "accessory" or kind == "theme" then -- #1708: accessory
			Net.fire("SetLook", kind, if id == "" then "default" else id)
		elseif kind == "music" then -- #1875: a Jukebox song, "default" for the day and night mix
			Net.fire("SetJukeboxTrack", if id == "" then "default" else id)
		end
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
	-- #2573: Buy all; the server plans from its own stock and coins, toasts the result and sends DealerStock
	UI.events.buyDealerAll:Connect(function(window: number?)
		Net.fire("BuyDealerAll", window or dealerWindow or -1)
	end)
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
	if events.sessionFeedback ~= nil then -- #3272: the once-a-day session ask
		events.sessionFeedback:Connect(function(answer: string)
			Net.fire("SessionFeedback", answer)
		end)
	end
	-- F87 part 3 (UI #745), analytics only: the intro's choice ("tile" or "help") and the stuck nudges ("pulse",
	-- "help_shown", "show_me") as TelemetryReport, which allowlists both with their session caps. A nudge goes once
	-- per tutorial step and kind, as the server logs it, so a repeating pulse never reaches the remote's limit.
	-- #1888: the Store funnel's tab_viewed and buy_pressed (the UI sends each once a visit; the server allowlists both)
	if events.storeReport ~= nil then
		events.storeReport:Connect(function(kind: string, value: any)
			if kind == "store_tab" or kind == "store_buy" then
				Net.fire("TelemetryReport", kind, value)
			end
		end)
	end
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
	-- #1920: the session recap card showed, and how long it stayed up; the server allowlists both
	if events.sessionRecap ~= nil then
		events.sessionRecap:Connect(function()
			Net.fire("TelemetryReport", "session_recap", true)
		end)
	end
	if events.sessionRecapClose ~= nil then
		events.sessionRecapClose:Connect(function(secondsUp: number)
			Net.fire("TelemetryReport", "session_recap_close", secondsUp)
		end)
	end
	-- #2694: how each "How is it so far?" ask ended, "answered|closed|ignored:early|late"; the server logs it as
	-- feedback_ask_end, capped at the asks shown this session
	if events.feedbackOutcome ~= nil then
		events.feedbackOutcome:Connect(function(how: string)
			Net.fire("TelemetryReport", "feedback_outcome", how)
		end)
	end
	-- #1947: the button pressed on a like or favourite gift card, "kind:button"; the server allowlists and caps it
	if events.playtimeGift ~= nil then
		events.playtimeGift:Connect(function(what: string)
			Net.fire("TelemetryReport", "playtime_gift", what)
		end)
	end
	-- #1919: the goal card's "Find N more cats" opened the Index; the server allowlists the area id
	if events.indexHintTap ~= nil then
		events.indexHintTap:Connect(function(areaId: string)
			Net.fire("TelemetryReport", "index_hint_tap", areaId)
		end)
	end
	-- #1936: a purchase prompt the store guard refused, "source:reason"; the server allowlists and caps it
	if events.storeGuardBlocked ~= nil then
		events.storeGuardBlocked:Connect(function(what: string)
			Net.fire("TelemetryReport", "store_guard_blocked", what)
		end)
	end
	-- #4176: a purchase prompt's source, "source:id"; the server allowlists it and keeps it 2 minutes for the receipt
	if events.buySource ~= nil then
		events.buySource:Connect(function(what: string)
			Net.fire("TelemetryReport", "buy_source", what)
		end)
	end
	-- Fast travel (F19): the travel row and the Areas panel; the server answers every request with TravelResult.
	UI.events.travel:Connect(function(destination: string)
		Net.fire("Travel", destination)
	end)
	-- Analytics only (F16): which screens players find at all, once per screen a session so toggling a panel never
	-- reaches the remote's rate limit (reviewer N97). The server allowlists the names.
	-- #2913 (phone players miss the first circles; is it the screen?): the viewport's short side once a session as
	-- TelemetryReport screen_short (UI/Components/ScreenShort), once the camera has its real size
	task.spawn(function()
		local began = os.clock()
		local camera = Workspace.CurrentCamera
		while (camera == nil or camera.ViewportSize.Y <= 1) and os.clock() - began < 10 do
			task.wait(0.5)
			camera = Workspace.CurrentCamera
		end
		if camera ~= nil and camera.ViewportSize.Y > 1 then
			local ScreenShort = require(script.Parent.Parent.UI.Components.ScreenShort)
			Net.fire("TelemetryReport", "screen_short", ScreenShort.bucket(camera.ViewportSize))
		end
	end)
	-- #3098 P2: health_check, once a session FirstFive.HEALTH_AT seconds in: the client's memory in MB, then its frames
	-- a second over FirstFive.HEALTH_SAMPLE seconds (the server adds the ping and keeps it to Tier 1 accounts)
	task.delay(FirstFive.HEALTH_AT, function()
		local frames = 0
		local counting = RunService.RenderStepped:Connect(function()
			frames += 1
		end)
		task.wait(FirstFive.HEALTH_SAMPLE)
		counting:Disconnect()
		local memory = math.floor(Stats:GetTotalMemoryUsageMb())
		Net.fire("TelemetryReport", "health_mem", math.clamp(memory, 0, FirstFive.MEMORY_MAX))
		Net.fire(
			"TelemetryReport",
			"health_fps",
			math.clamp(math.floor(frames / FirstFive.HEALTH_SAMPLE), 0, FirstFive.FPS_MAX)
		)
	end)
	local screensReported: { [string]: boolean } = {}
	-- #1273: the screen open now ("none" when it closes), for a new player's time markers and leave events. Sent while
	-- the first loop or Tier 1 lasts, at most once per SCREEN_REPORT_SECONDS with the latest one sent at its end.
	local screenNow = "none"
	local screenSent = "none"
	local screenWaiting = false
	local function sendScreen()
		screenWaiting = false
		if screenNow ~= screenSent then
			screenSent = screenNow
			Net.fire("TelemetryReport", "screen", screenNow)
		end
	end
	UI.events.screenOpened:Connect(function(name: string?)
		if name == "Store" then
			-- #1888: every Store visit starts a Store funnel, with where the UI said it was opened from
			Net.fire("TelemetryReport", "store_opened", StoreFunnel.takeSource())
		end
		if name ~= nil and not screensReported[name] then
			screensReported[name] = true
			Net.fire("TelemetryReport", "ui_opened", name)
		end
		local s = state
		if s == nil or (s.tutorialStep >= 5 and s.tier >= 2) then
			return
		end
		screenNow = name or "none"
		if not screenWaiting then
			screenWaiting = true
			task.delay(SCREEN_REPORT_SECONDS, sendScreen)
		end
	end)
	-- #1273: the catch card (a stray's or a stuck cat's prompt) on screen, the funnel's catch_card_opened
	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
		if stepsReported.catch_card_opened or prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			return
		end
		local model = prompt:FindFirstAncestorOfClass("Model")
		local parent = prompt.Parent
		if
			prompt:GetAttribute("CatId") ~= nil
			or (model ~= nil and model:GetAttribute("CatId") ~= nil)
			or (parent ~= nil and parent:GetAttribute("CatId") ~= nil)
		then
			reportStep("catch_card_opened")
		end
	end)
	-- #1273: the Tutorial tile's red X
	UI.events.tutorialClosed:Connect(function()
		Net.fire("TelemetryReport", "tutorial_closed", "x")
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
	-- server stamps the time itself and judges where the marker was. F92: on a trap someone else is rescuing the
	-- prompt reads "Help" and the press asks to join as their helper (RescueHelp); the bar works the same after.
	UI.events.rescueBegan:Connect(function(rescueSpotId: string?, _catId: string?)
		if rescueSpotId ~= nil then
			local model = stuckModel(rescueSpotId)
			local ask = if model ~= nil and lockedByOther(model)
				then "RescueHelp"
				else "RescueBegin"
			Net.fire(ask, rescueSpotId)
		end
	end)
	UI.events.rescuePressed:Connect(function(rescueSpotId: string)
		-- #2241: the press's own time, so ping wobble cannot move a fast Legendary or Mythical marker out of the zone
		Net.fire("RescuePress", rescueSpotId, Workspace:GetServerTimeNow())
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

-- The Spin Wheel (F49), the Golden Fish Market (F53) and the Corner Shop (#1052) in the street plaza.
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
	-- The Corner Shop (#1052): its window closes itself out of CornerShopRange, as the Market's does.
	bindStationPrompts("CornerShop", "CornerShopPrompt", function()
		local shop: any = (UI :: any).cornerShop
		if shop ~= nil and type(shop.open) == "function" then
			(shop.open :: any)()
		end
	end)
	-- #2574: Juniper's cart
	bindStationPrompts("MysteryMarket", "MysteryPrompt", function()
		UI.mystery.open()
	end)
	-- #3066: the feedback stand's post box: one press and the Feedback window is up with the cursor in its box
	bindStationPrompts(FeedbackStand.TAG, FeedbackStand.PROMPT, function()
		UI.bugReport.open(FeedbackStand.KIND, "box")
	end)
	-- #3062: the Cat Arcade's cabinet opens its card; the `arcade` switch off hides the prompt
	local arcadePrompts: { ProximityPrompt } = {}
	local function arcadeOn(): boolean
		local LiveFlags = require(Shared:WaitForChild("LiveFlags")) :: any
		return LiveFlags.shown(
			Arcade.FLAG,
			ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. Arcade.FLAG)
		)
	end
	bindStationPrompts(Arcade.TAG, Arcade.PROMPT, function()
		UI.arcade.open()
	end, function(prompt: ProximityPrompt)
		table.insert(arcadePrompts, prompt)
		prompt.Enabled = arcadeOn()
	end)
	-- #3296: `mouseDash` on makes Mouse Dash the arcade's game; `circleStreak` off vaults Circle Streak
	local function flagOn(key: string): boolean
		local LiveFlags = require(Shared:WaitForChild("LiveFlags")) :: any
		return LiveFlags.shown(
			key,
			ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. key)
		)
	end
	local function applyArcade()
		local on = arcadeOn()
		local circle = flagOn("circleStreak")
		local dash = on and flagOn("mouseDash")
		UI.arcade.setOn(on and circle, on and (circle or dash))
		UI.mouseDash.setFlags(dash, on and circle)
		for _, prompt in arcadePrompts do
			prompt.Enabled = on and (circle or dash)
		end
	end
	for _, key in { Arcade.FLAG, "mouseDash", "circleStreak" } do
		ReplicatedStorage:GetAttributeChangedSignal("LiveFlag_" .. key):Connect(applyArcade)
	end
	applyArcade()
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

-- #2681: whether this session's client logged an error line, for the feedback_env event. Sent once, after the
-- device report (so the server's telemetry session exists); an error before that waits for it.
local clientErrorSeen = false
local clientErrorReported = false
local function reportClientError()
	if clientErrorReported or not clientErrorSeen or not deviceReported then
		return
	end
	clientErrorReported = true
	Net.fire("TelemetryReport", "client_error", true)
end
LogService.MessageOut:Connect(function(_message: string, kind: Enum.MessageType)
	if kind == Enum.MessageType.MessageError and not clientErrorSeen then
		clientErrorSeen = true
		reportClientError()
	end
end)

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

-- The UI's own moment too: no window, popup (Welcome back), tip card or other ask up. The invite ask slid in under the
-- Welcome back card at join (Studio run 2026-11-07).
local function quiet(): boolean
	if inIntro or os.clock() < busyUntil or (state ~= nil and state.carrying ~= nil) then
		return false
	end
	if AfkController.rejoinQuiet() then
		return false -- #3602: away since before an automatic rejoin; asks wait for the first input
	end
	local tips: any = (UI :: any).tips
	if tips == nil or type(tips.quiet) ~= "function" then
		return true
	end
	return (tips.quiet :: () -> unknown)() == true
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
	[Tips.FAVORITE_ASK] = "Favorite Catch a Cat Cafe to find it fast next time",
	[Tips.LIKE_ASK] = "Having fun? A thumbs up helps other players find Catch a Cat Cafe.",
	[Tips.INVITE_ASK] = "Playing with a friend gives you both +10% tips. Invite one?", -- F92
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
		if id == Tips.INVITE_ASK and state ~= nil and (state :: any).invite ~= nil then
			-- #2797: a server with the invite reward has its own card (offerInvite), so the older +10% tips nudge stays
			-- quiet rather than a second invite ask; left unanswered, as below
			return
		end
		if not shown and id == Tips.INVITE_ASK then
			-- Review N320: the invite ask is only worth its card (which opens Roblox's invite prompt). Until the UI
			-- has one, leave it unanswered so the server offers it again in a later session instead of a toast
			-- using it up for good.
			return
		end
		if not shown then
			UI.toast(ASK_LINES[id] or "", "info")
		end
		Net.fire("TipSeen", id, false)
	end)
end

-- #2766: the update Event's ask (UI/Components/EventRsvp): once a session at a quiet moment, before the Event starts,
-- to a player past the tutorial who has not answered Roblox's Notify Me prompt; a busy card tries at the next sync.
-- #3450: only 3 to 10 minutes into the session (EventRsvp.window), counted from when this script started.
local eventAsk = { asked = false, started = os.clock() }
local function reportRsvp(kind: string)
	Net.fire("TelemetryReport", "event_rsvp", kind)
end
local function offerEvent()
	local id, startsAt, words = EventRsvp.next(Config.UpdateEvents, os.time())
	if
		eventAsk.asked
		or state == nil
		or state.tutorialStep < 5
		or not EventRsvp.window(os.clock() - eventAsk.started)
		or not EventRsvp.due(id, startsAt, os.time())
	then
		return
	end
	eventAsk.asked = true
	local eventId, at = id :: string, startsAt :: number
	task.spawn(function()
		while not quiet() do
			task.wait(1)
			if not EventRsvp.window(os.clock() - eventAsk.started) then
				return -- no quiet moment by minute 10: not this session
			end
		end
		if EventRsvp.status(eventId) ~= "none" or not EventRsvp.due(eventId, at, os.time()) then
			return -- answered before (or Roblox cannot say), or it has started
		end
		local asks: any = (UI :: any).asks
		local card: any = if asks ~= nil then asks.card else nil
		local shown = type(card) == "function"
			and (card :: (any) -> unknown)({
					title = words or EventRsvp.title(at, os.time()),
					choices = {
						{ id = "remind", label = EventRsvp.REMIND, style = "primary" },
						{ id = "later", label = EventRsvp.LATER, style = "ghost" },
					},
					seconds = EventRsvp.ASK_SECONDS,
					lines = 2,
					answer = function(choice: string?)
						if choice == "remind" then
							reportRsvp("remind")
							task.spawn(function()
								reportRsvp(EventRsvp.prompt(eventId) or "failed")
							end)
						elseif choice == "later" then
							reportRsvp("later")
						end
					end,
				})
				== true
		if shown then
			reportRsvp("shown")
		else
			eventAsk.asked = false -- another card was up: the next sync tries again
		end
	end)
end

-- #2797 (retention-ideas.md 5d): the one invite card with its reward (UI/Components/InviteCardLogic), once per
-- account between PlayerState.invite's cardFrom and cardBy seconds of play: at the first good moment (a Rare-or-better
-- cat caught, rescued or at the bowl, or the Grand Opening's step 4), else at cardBy, at a calm moment. InviteCard
-- reports "shown", "invite" and "notnow" (the server marks it shown); Invite opens Roblox's window after its
-- CanSendGameInviteAsync check (UI/Components/Invite).
local inviteCard = { asked = false, good = false, done = false, sent = nil :: number?, sentAt = 0 }

local function offerInvite()
	if inviteCard.asked or state == nil then
		return
	end
	local view = (state :: any).invite
	local sent = (state :: any).playSeconds
	if sent ~= inviteCard.sent then
		inviteCard.sent = if type(sent) == "number" then sent else nil
		inviteCard.sentAt = os.clock()
	end
	local played = InviteCardLogic.played(inviteCard.sent, inviteCard.sentAt, os.clock())
	if not InviteCardLogic.due(view, played, inviteCard.good) then
		return
	end
	inviteCard.asked = true
	task.spawn(function()
		local waited = 0
		while not quiet() do
			if waited >= ASK_WAIT_SECONDS then
				inviteCard.asked = false
				return
			end
			waited += task.wait(1)
		end
		local now: any = state
		if now == nil or not InviteCardLogic.due(now.invite, played, true) then
			return
		end
		local asks: any = (UI :: any).asks
		local card: any = if asks ~= nil then asks.card else nil
		local shown = type(card) == "function"
			and (card :: (any) -> unknown)({
					title = InviteCardLogic.title(now.invite),
					choices = {
						{ id = "invite", label = InviteCardLogic.INVITE, style = "primary" },
						{ id = "later", label = InviteCardLogic.NOT_NOW, style = "ghost" },
					},
					seconds = InviteCardLogic.SECONDS,
					lines = 2,
					answer = function(choice: string?)
						if choice == "invite" then
							Net.fire("InviteCard", "invite")
							Invite.prompt()
						elseif choice == "later" then
							Net.fire("InviteCard", "notnow")
						end
					end,
				})
				== true
		if shown then
			inviteCard.done = true
			Net.fire("InviteCard", "shown")
		else
			inviteCard.asked = false -- another card was up: the next check tries again
		end
	end)
end

-- The good moments, and a check every few seconds so cardBy comes without a sync.
local function trackInvite()
	local function good(rarity: string?)
		if InviteCardLogic.goodRarity(rarity) and not inviteCard.good then
			inviteCard.good = true
			offerInvite()
		end
	end
	Moments.CatchSuccess:Connect(function(_strayId: string, rarity: string?)
		good(rarity)
	end)
	Moments.RescueDone:Connect(function(_spotId: string, rarity: string?)
		good(rarity)
	end)
	task.spawn(function()
		local started = os.clock()
		while not inviteCard.done do
			task.wait(5)
			local view = if state ~= nil then (state :: any).invite else nil
			-- review: stop once it was shown, or when the server has sent no invite view for 10 minutes (a server
			-- without the reward card)
			if
				(type(view) == "table" and view.cardShown == true)
				or (view == nil and os.clock() - started > 600)
			then
				break
			end
			offerInvite()
		end
	end)
end

local function wireServerEvents()
	-- #3450: the update Event's ask does not wait for a sync once its window opens
	task.delay(EventRsvp.FROM_SECONDS + 1, function()
		offerEvent()
	end)
	Net.on("ProfileSync", function(s: Types.PlayerState)
		latestCarrying = s.carrying -- #3145: first, before anything that could hold this sync up
		applyState(s)
		offerEvent()
		offerInvite()
		reportDevice()
		reportClientError()
	end)
	Net.on("Toast", function(text: string, kind: Types.ToastKind?)
		UI.toast(text, kind)
	end)
	-- #3301: an owner's /shout from any server, in the OWNER bubble
	Net.on("OwnerShout", function(text: string)
		(UI :: any).ownerShout(text)
	end)
	-- #4227: a queued spawn line's sting plays as it shows, not as it arrives
	local hooks: any = UI
	hooks.onAnnounceShown = function(text: string, rarity: string?)
		Moments.Announce:Fire(text, rarity)
	end
	Net.on("Announce", function(text: string, rarity: string?)
		-- #2399: the sting plays only with a shout-out that shows; UI.announce says false when it drops one (it said
		-- nothing before #2426, which counts as shown)
		local shown: any = (UI :: any).announce(text, rarity)
		if shown ~= false then
			Moments.Announce:Fire(text, rarity)
		end
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
	-- F99 (rainbow-coat.md section 2): a rainbow stray spawned. Moments.RainbowSpawned for VFX's beam and Sound's
	-- shimmer; when the server marks it for the toast (once a minute), the UI's `UI.rainbowSpawned(areaId, catId)` once
	-- it has one, else an announce line in the cat's rarity colour.
	Net.on(
		"RainbowSpawned",
		function(areaId: string, catId: string, strayId: string, toast: boolean)
			Moments.RainbowSpawned:Fire(areaId, catId, strayId)
			-- #4005: the cat stays, the toast waits out a new player's quiet start
			if toast ~= true or select(2, require(Shared:WaitForChild("QuietStart")).live()) then
				return
			end
			local hook: unknown = (UI :: any).rainbowSpawned
			if type(hook) == "function" then
				(hook :: (string, string) -> ())(areaId, catId)
				return
			end
			local def = Catalog.getCat(catId)
			local area = Catalog.getArea(areaId)
			if def ~= nil and area ~= nil then
				UI.announce(Catching.rainbowSpawnText(def, area.name), def.rarity)
			end
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
	-- F98 (leaderboards.md sections 2 and 5): every list's top 50 and this player's own line, on join, after each
	-- refresh and after the player's own write. Kept on UIController.leaderboards and handed to the UI's
	-- `UI.leaderboards.sync(data)` (the town boards' faces and the Index's Top tab) once it has one.
	Net.on("LeaderboardSync", function(data: Types.LeaderboardSync)
		UIController.leaderboards = data
		local boards: any = (UI :: any).leaderboards
		if type(boards) == "table" and type(boards.sync) == "function" then
			(boards.sync :: (Types.LeaderboardSync) -> ())(data)
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
	-- F92 (playing-together.md section 5): a player arrived at a pal's front door. Moments.PalArrived on every client
	-- for the wave; the joiner's own HUD gets `UI.palArrived(palUserId, palArea)` once the UI has it (the marker and
	-- the glowing travel button), else a toast when the pal is out in an area.
	Net.on("PalArrived", function(joinerId: number, palId: number, palArea: string?)
		Moments.PalArrived:Fire(joinerId, palId)
		UIController.palJoined(joinerId, palId)
		if joinerId ~= player.UserId then
			return
		end
		local hook: unknown = (UI :: any).palArrived
		if type(hook) == "function" then
			(hook :: (number, string?) -> ())(palId, palArea)
			return
		end
		local pal = Players:GetPlayerByUserId(palId)
		local area = if palArea ~= nil then Catalog.getArea(palArea) else nil
		if pal ~= nil and area ~= nil then
			UI.toast(string.format("%s is in the %s", pal.DisplayName, area.name), "info")
		end
	end)
	-- F92 Team Rescue: a helped rescue freed its cat. Moments.TeamRescue for the pop and the chime on both screens;
	-- the UI's `UI.teamRescue(rescuerUserId, helperUserId, coins)` once it has one, else a toast with the helper's tip.
	Net.on(
		"TeamRescue",
		function(
			rescueSpotId: string,
			rescuerId: number,
			helperId: number,
			position: Vector3,
			coins: number
		)
			Moments.TeamRescue:Fire(rescueSpotId, rescuerId, helperId, position)
			local hook: unknown = (UI :: any).teamRescue
			if type(hook) == "function" then
				(hook :: (number, number, number) -> ())(rescuerId, helperId, coins)
				return
			end
			UI.toast(
				if coins > 0 then "Team Rescue! +$" .. ShortNumber.format(coins) else "Team Rescue!",
				"good"
			)
		end
	)
	Net.on("CatCaught", function(catId: string, isNew: boolean, variant: string?)
		-- F99: the coat comes with the catch, so the card says RAINBOW or GOLD without looking for the new cat
		local extra: UITypes.CatFoundExtra? = nil
		if pendingCharmGain > 0 or variant ~= nil then
			local info: UITypes.CatFoundExtra = {}
			info.charmGain = if pendingCharmGain > 0 then pendingCharmGain else nil
			info.shiny = if variant ~= nil then variant == "gold" else nil
			info.rainbow = if variant ~= nil then variant == "rainbow" else nil
			extra = info
		end
		pendingCharmGain = 0
		UI.showCatFound(catId, isNew, extra)
		-- CatCaught comes from a check-in or a tamed bait cat, so a bump that drops the carried cat plays no
		-- check-in sound.
		Moments.CheckIn:Fire()
		Moments.CatFound:Fire(catId, isNew)
	end)
	-- The Cafe Pass (#1645, #1646): the season, level, XP and claims, at join, after each claim and at a season roll.
	Net.on("CafePassState", function(view: Types.CafePassView)
		UI.pass.set(view)
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
	-- Use all (#1078): each spin's slice and amount and the prizes added up; both empty when refused.
	Net.on("SpinAllResult", function(rolls: { any }, totals: { any })
		local spin: any = UI.spin
		if type(spin.allResult) == "function" then
			(spin.allResult :: any)(rolls, totals)
		end
	end)
	-- The Thank You board (#1083): its rows, newest first, and whether this player has a credit (the Settings row shows
	-- only then); on join and at each rebuild. Loose until UI-Engineer's `UI.thanksBoard(rows, hasCredit)`.
	Net.on("ThanksBoard", function(rows: { any }, hasCredit: boolean)
		local board = (UI :: any).thanksBoard
		if type(board) == "function" then
			(board :: any)(rows, hasCredit)
		end
	end)
	-- The Corner Shop's stock (#1052): on join, at each 5 minute window and after every buy.
	Net.on("CornerShopStock", function(stock: any)
		local shop: any = (UI :: any).cornerShop
		if shop ~= nil and type(shop.setStock) == "function" then
			(shop.setStock :: any)(stock)
		end
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
	-- #2402: every piece an Open all gave, for the Market's summary card; empty when refused.
	Net.on("CrateAllResult", function(crateId: string, opened: { any })
		local market = marketUI()
		if market ~= nil then
			market.allResult(crateId, opened)
		end
	end)
	-- The fed cat's new level and XP (#1181), for the Bag's feed effect; loose until UI.bag is on main.
	Net.on("FeedResult", function(catUid: string, level: number, xp: number)
		local bag: any = (UI :: any).bag
		if type(bag) == "table" and type(bag.fed) == "function" then
			(bag.fed :: any)(catUid, level, xp)
		end
	end)
	-- What this player's opened Mystery gift held (F64): the gift card, and the ribbon pop in Effects.
	Net.on(
		"MysteryGiftResult",
		function(kind: string, id: string?, count: number, tier: string?, fish: number?)
			-- #2614: the wrap and a crate's fish for the card; UI.potions.giftResult reads them when it is ready
			local result = UI.potions.giftResult :: any
			result(kind, id, count, tier, fish)
		end
	)
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
	-- F87: a server-side context tip's moment (shared/Tips). The UI's tip queue times it and answers tipSeen; until
	-- the UI has one the tips wait unseen, so they still show once the cards land. F96: the notification and favorite
	-- asks (and F92's invite nudge) are this controller's (showAsk); the like ask goes to the queue when there is one.
	trackBusy()
	trackInvite()
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
		function(
			strayId: string,
			circles: { Types.CatchCircle },
			windows: Types.CatchWindows,
			trustStart: number?,
			trustNeed: number?
		)
			UI.catch.showCircles(strayId, circles, windows)
			-- #1884 (catch-rework.md 7b): the trust bar, for the UI once it draws one
			local trust: ((string, number, number) -> ())? = (UI.catch :: any).trust
			if trust ~= nil and type(trustStart) == "number" and type(trustNeed) == "number" then
				trust(strayId, trustStart, trustNeed)
			end
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
	-- also brings this player's retryAt (F57, review S87), when the card's "Cooling down Ns" ends.
	Net.on(
		"CatchResult",
		function(
			strayId: string,
			grades: { Types.CircleGrade },
			success: boolean,
			charmGain: number,
			retryAt: number?,
			finish: Types.CatchFinish?
		)
			local allPerfect = #grades > 0
			for _, grade in grades do
				allPerfect = allPerfect and grade == "perfect"
			end
			-- #1884 (catch-rework.md 7d): PURRFECT, GREAT, NICE or a bolt, the trust and the Purrfect streak
			local finished: ((string, Types.CatchFinish) -> ())? = (UI.catch :: any).finished
			if finished ~= nil and type(finish) == "table" then
				finished(strayId, finish)
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
	-- #1727: the server's grade for each pressed circle as it is judged, for the circles screen (UI.catch.judged once
	-- the UI has it). A Good or Perfect after this device's own Miss means the catch goes on.
	-- #1884: with the trust after it, and for an expired circle too.
	Net.on(
		"CatchJudged",
		function(strayId: string, index: number, grade: Types.CircleGrade, trust: number?)
			local judged: ((string, number, Types.CircleGrade, number?) -> ())? = (UI.catch :: any).judged
			if judged ~= nil then
				judged(strayId, index, grade, if type(trust) == "number" then trust else nil)
			end
		end
	)
	-- #3062: the Cat Arcade. Its circles sound as a catch's do (CircleAppear, CircleGrade), with Sound-Agent's
	-- ArcadeStart, ArcadeMilestone and ArcadeEnd moments when the build has them.
	local arcadeTimers: { thread } = {}
	local arcadeRun: number? = nil
	local function arcadeMoment(name: string, ...: any)
		local moment: any = (Moments :: any)[name]
		if moment ~= nil then
			moment:Fire(...)
		end
	end
	local function cancelArcadeTimers()
		for _, timer in arcadeTimers do
			pcall(task.cancel, timer)
		end
		table.clear(arcadeTimers)
	end
	Net.on("ArcadeState", function(view: any)
		UI.arcade.state(view)
	end)
	Net.on(
		"ArcadeBlock",
		function(
			run: number,
			block: number,
			circles: { Types.CatchCircle },
			windows: Types.CatchWindows,
			points: number
		)
			if arcadeRun ~= run then
				arcadeRun = run
				arcadeMoment("ArcadeStart")
			end
			UI.arcade.block(run, block, circles, windows, points)
			cancelArcadeTimers()
			for index, circle in circles do
				local shrink = circle.shrinkSeconds
				table.insert(
					arcadeTimers,
					task.delay(
						math.max(0, circle.startsAt - Workspace:GetServerTimeNow()),
						function()
							if UI.arcade.playing() then
								Moments.CircleAppear:Fire(index, shrink)
							end
						end
					)
				)
			end
		end
	)
	Net.on(
		"ArcadeJudged",
		function(
			run: number,
			block: number,
			index: number,
			grade: string,
			points: number,
			milestones: { number }
		)
			if grade == "perfect" or grade == "good" or grade == "miss" then
				Moments.CircleGrade:Fire(index, grade)
			end
			if type(milestones) == "table" and #milestones > 0 then
				arcadeMoment("ArcadeMilestone", milestones[#milestones])
			end
			UI.arcade.judged(run, block, index, grade, points, milestones)
		end
	)
	Net.on("ArcadeOver", function(run: number, result: any)
		cancelArcadeTimers()
		arcadeRun = nil
		if type(result) == "table" then
			arcadeMoment("ArcadeEnd", result.points, result.win == true)
		end
		UI.arcade.over(run, result)
	end)
	UI.events.arcadePlay:Connect(function()
		Net.fire("ArcadeStart")
	end)
	UI.events.arcadePress:Connect(function(run: number, block: number, index: number)
		Net.fire("ArcadePress", run, block, index)
		Moments.NetSwing:Fire(index)
	end)
	UI.events.arcadeQuit:Connect(function(run: number)
		Net.fire("ArcadeQuit", run)
	end)
	-- #3296: Mouse Dash. The server draws and judges everything; these only pass its answers to the window and the
	-- sound moments (Motion-FX-Agent's, played when the build has them).
	Net.on("MouseDashState", function(view: any)
		UI.mouseDash.state(view)
	end)
	Net.on("MouseDashBegan", function(run: number, hearts: number, firstAt: number, endsAt: any)
		arcadeMoment("MouseDashStart")
		UI.mouseDash.began(run, hearts, firstAt, if type(endsAt) == "number" then endsAt else nil)
	end)
	Net.on("MouseDashWave", function(run: number, index: number, pops: any, hint: string?)
		if type(pops) == "table" then
			for _, pop in pops do
				if type(pop) == "table" then
					arcadeMoment("MouseDashPop", pop.kind)
				end
			end
		end
		UI.mouseDash.wave(run, index, pops, hint)
	end)
	local dashLevel = 0
	Net.on(
		"MouseDashJudged",
		function(
			run: number,
			index: number,
			tap: any,
			points: number,
			hearts: number,
			streak: number,
			milestones: any,
			dizzyUntil: number
		)
			if type(tap) == "table" then
				if tap.outcome == "catch" then
					arcadeMoment("MouseDashCatch", points, tap.kind, streak)
				elseif tap.outcome == "kitten" or tap.outcome == "empty" then
					arcadeMoment("MouseDashMiss", tap.outcome)
				end
				if tap.heart == 1 then
					arcadeMoment("MouseDashHeart")
				end
			end
			local level = if type(points) == "number" then points // 5 else 0
			if level > dashLevel then
				arcadeMoment("MouseDashFaster", level)
			end
			dashLevel = level
			if type(milestones) == "table" and #milestones > 0 then
				arcadeMoment("MouseDashMilestone", milestones[#milestones])
			end
			UI.mouseDash.judged(run, index, tap, points, hearts, streak, milestones, dizzyUntil)
		end
	)
	Net.on("MouseDashGone", function(run: number, index: number, gone: any, hearts: number)
		if type(gone) == "table" then
			for _, entry in gone do
				-- a golden mouse or a kitten that ducks back is silent; only a grey mouse getting away sounds
				if type(entry) == "table" and entry.kind == "mouse" then
					arcadeMoment("MouseDashMiss", "escape")
				end
			end
		end
		UI.mouseDash.gone(run, index, gone, hearts)
	end)
	Net.on("MouseDashOver", function(run: number, result: any)
		dashLevel = 0
		if type(result) == "table" then
			arcadeMoment("MouseDashEnd", result.points, result.reason, result.newBest == true)
		end
		UI.mouseDash.over(run, result)
	end)
	UI.events.mouseDashPlay:Connect(function()
		Net.fire("MouseDashStart")
	end)
	UI.events.mouseDashTap:Connect(function(run: number, index: number, hole: number)
		Net.fire("MouseDashTap", run, index, hole)
	end)
	UI.events.mouseDashQuit:Connect(function(run: number)
		Net.fire("MouseDashQuit", run)
	end)
	-- #1893: a Grand Opening milestone was just paid; the ProfileSync that shows it came first. UI.roadmap.step plays
	-- the toast and confetti (and on the last, the Grand Opening) once the UI has it.
	Net.on("RoadmapStep", function(n: number)
		if n == InviteCardLogic.GOOD_STEP then
			inviteCard.good = true -- #2797: a good moment for the invite card
			task.defer(offerInvite)
		end
		local roadmap = (UI :: any).roadmap
		local step: ((number) -> ())? = if roadmap ~= nil then roadmap.step else nil
		if step ~= nil and type(n) == "number" then
			step(n)
		end
	end)
	-- #1897: the guaranteed Rare-or-better bait cat is at the bowl ("Your first Rare!" or "A Rare visitor!")
	Net.on("FirstWow", function(rarity: string, first: boolean)
		if InviteCardLogic.goodRarity(rarity) then
			inviteCard.good = true -- #2797: a Rare-or-better cat at the bowl
			task.defer(offerInvite)
		end
		local wow: ((string, boolean) -> ())? = (UI.bait :: any).wow
		if wow ~= nil and type(rarity) == "string" then
			wow(rarity, first == true)
		end
	end)
	-- #1920: this session's recap; UI.recap.show waits for the player to be idle and out of menus before the card
	Net.on("SessionRecap", function(view: Types.SessionRecapView)
		local recap = (UI :: any).recap
		local show: ((Types.SessionRecapView) -> ())? = if recap ~= nil then recap.show else nil
		if show ~= nil and type(view) == "table" then
			show(view)
		end
	end)
	-- #1955: Auto Equip moved cats; UI.autoEquip merges swaps within 2 s into one toast. Wired only once the server
	-- declares the remote, so this never waits on one that is not there.
	local serverEvents: { string } = (require(
		ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")
	) :: any).ServerToClient
	if table.find(serverEvents, "AutoEquipped") then
		Net.on("AutoEquipped", function(swaps: any)
			local auto = (UI :: any).autoEquip
			if auto ~= nil then
				auto.swapped(swaps)
			end
		end)
	end
	-- #1947: the like or favourite gift, already paid; UI.gift.show waits for the player to be idle before the card
	Net.on("PlaytimeGift", function(kind: string, paid: { string }?)
		local gift = (UI :: any).gift
		local show: ((string, { string }?) -> ())? = if gift ~= nil then gift.show else nil
		if show ~= nil then
			show(kind, paid)
		end
	end)
	-- #3420: the update gift's banners (Effects/EventBanner): "a gift is coming" and the gift paid. The words are
	-- built here from shared/UpdateGift, which refuses anything but small whole numbers; a paid gift that cannot
	-- show as a banner falls back to the toast.
	Net.on(
		"UpdateGiftNotice",
		function(
			kind: unknown,
			fish: unknown,
			spins: unknown,
			secondsLeft: unknown,
			crates: unknown
		)
			local banner = UpdateGift.banner(kind, fish, spins, secondsLeft, crates) -- #3535: crates
			if banner == nil then
				return
			end
			local shown = EventBanner.show({
				kind = if kind == "paid" then "gift" else "giftSoon",
				title = banner.title,
				lines = banner.lines,
			})
			if not shown and kind == "paid" then
				UI.toast(banner.title .. " " .. banner.lines[1], "good")
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
			hits = challenge.hits or 0, -- F92: a helper joins a bar part way through
			paws = challenge.paws or 0,
		}
		Moments.RescueStart:Fire(rescueSpotId)
	end)
	Net.on("RescueResult", function(
		rescueSpotId: string,
		hits: number,
		pawsLeft: number,
		done: boolean,
		success: boolean,
		bar: Types.RescueBar?,
		win: Types.RummageWin? -- #3050: the Rummage Bin's prize, on its winning result
	)
		-- F93: `bar` is how the marker runs and which zone to hit from now (a zone that ran out, a faster marker
		-- after a hit); a UI that does not take it yet ignores it
		local update: any = UI.rescue.update
		update(rescueSpotId, hits, pawsLeft, done, success, bar, win)
		if done and success and win ~= nil and type(win.id) == "string" then
			Moments.RummageWin:Fire(win.id, win.first == true)
		end
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
	end)
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

-- #2864 (Derek2 2026-11-09: "if you have a cat in bag it doesn't show the safe zone here bubble unless one is in
-- your hands"): with only a Backpack cat, the same marker through UI.setBagCarry, which shows it and leaves the
-- HUD's carry state alone (the "Drop bag cat" pill stays). A cat in the hands leads instead (UI.setCarrying). Looked
-- up loosely, so this lands before or after the UI build that adds it.
local function refreshBagMarker()
	local hook: unknown = (UI :: any).setBagCarry
	if type(hook) ~= "function" then
		return
	end
	local setBag = hook :: (UITypes.CarryInfo?) -> ()
	local character = Players.LocalPlayer.Character
	local packedId = if character ~= nil then character:GetAttribute("PackedCatId") else nil
	local bag = if lastCarrying == nil and type(packedId) == "string" then packedId else nil
	if bag == nil then
		if shownBag ~= nil then
			shownBag, shownBagCamp = nil, nil
			setBag(nil)
		end
		return
	end
	local camp = carryCamp()
	if bag ~= shownBag or camp ~= shownBagCamp then
		shownBag, shownBagCamp = bag, camp
		setBag({ catId = bag, door = UIController.ownDoor(), camp = camp })
	end
end

-- #2730: moves the carry marker between the area's camp basket and the cafe door as the carrier walks.
local function startCampWatch()
	task.spawn(function()
		while true do
			task.wait(CAMP_CHECK_SECONDS)
			if state ~= nil then
				refreshCarry() -- #3145: the banner against the server's newest word, whatever the last sync did
			end
			local catId = lastCarrying
			if catId ~= nil then
				local camp = carryCamp()
				if camp ~= shownCamp then
					shownCamp = camp
					UI.setCarrying({ catId = catId, door = UIController.ownDoor(), camp = camp })
				end
			end
			refreshBagMarker() -- #2864
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
-- LuckyDayWarnSeconds before a sunrise that starts a Lucky, Golden or Rainbow Day (#1572, named by the UI) (at night Day is the day that ended, so the sunrise
-- starts Day + 1), to whoever is still in the server; "start" comes when LuckyDay turns true at that sunrise. Joining
-- in the middle of one shows neither: the Luck chip and the sky say so then. The UI's own banner, `UI.luckyDay(kind,
-- line)`, once it has one, else a gold shout-out.
local function bindLuckyDay(clock: Instance)
	local function show(kind: string, line: string, coming: Clock.DayKinds?)
		local hook: unknown = (UI :: any).luckyDay
		if type(hook) == "function" then
			(hook :: (string, string, Clock.DayKinds?) -> ())(kind, line, coming)
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
				local brings = Clock.dayKinds(coming) -- #1572: warn of a Golden or Rainbow Day too, naming each
				if
					(brings.lucky or brings.golden or brings.rainbow)
					and warned ~= coming
					and left > 0
					and left <= Config.LuckyDayWarnSeconds
				then
					warned = coming
					show("warning", Luck.DAY_WARNING, brings)
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
		allSpots = (Catalog :: any).allSpots, -- #1624: with the pass-only slots (nil until the server code has them)
		tiers = Catalog.tiers,
		areas = Catalog.areas,
		rarities = Catalog.rarities,
		tipJar = Catalog.tipJar,
		indexMilestones = Catalog.indexMilestones,
		indexPrizes = Catalog.indexPrizes,
		spinWheel = Catalog.spinWheel,
		crates = Catalog.crates, -- F53: names and models for the crate prizes (review S77)
		-- F53: the crate pieces (the Decor shop keeps reading decor); #1645: the Cafe Pass decor rides along, so the Decor
		-- window lists and places it like the crate furniture (it has no crate, so no crate or Index page counts it)
		crateDecor = passAndCrateDecor(),
		fishShop = Catalog.fishShop, -- F53: what the Golden Fish Market sells
		potions = Catalog.potions, -- F64: the potion bag's rows
		catFood = Catalog.catFood, -- #1181: the Bag's Cat Food tab rows
		mysteryGift = Catalog.mysteryGift, -- F64: what a Mystery gift can hold, shown before opening
		mysteryGiftTiers = Catalog.mysteryGiftTiers, -- #2614: each wrap's own chances, for the gift prompt's line
		dealerAmountWeights = Catalog.dealerAmountWeights, -- F59: the dealer's stock odds under Details
		quests = Catalog.quests, -- F73: the quest rows (to tell a coins quest)
		questPrizes = Catalog.questPrizes, -- F73: daily, dailyBig, dailySet, weekly and weeklySet
		achievements = Catalog.achievements, -- F73: the 44 achievements in table order
		achievementPrizes = Catalog.achievementPrizes, -- F73: prizes by size
		achievementPrizesById = achievementPrizesById(), -- #3694: each one's own prize, its line's item
		dailyTreat = Catalog.dailyTreat, -- F70: the Daily Treat card's seven days and their prizes
	}
	-- #3992: the Index's milestones past 50 (and the Rainbow track's past 25) wait for the `indexTo70` switch; the UI
	-- reads catalog.indexPrizes each time, so a switch change shows at the next render
	local SharedIndexRewards = require(Shared:WaitForChild("IndexRewards")) :: any
	catalog.indexPrizes = SharedIndexRewards.shownPrizes()
	ReplicatedStorage:GetAttributeChangedSignal("LiveFlag_" .. SharedIndexRewards.LATE_FLAG)
		:Connect(function()
			catalog.indexPrizes = SharedIndexRewards.shownPrizes()
		end)
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
		-- #3238: step 3's "Catch another cat" card follows dusk and sunrise
		clock:GetAttributeChangedSignal("AreasOpen"):Connect(function()
			local current = state
			if current ~= nil then
				refreshTutorial(current)
			end
		end)
	end)
	-- #2912: the stuck cat pointer follows the player (town or the Alleyway), the cat streaming in and its own
	-- TRAIL_SECONDS; looked at once a second, and only while the save waits for its first rescue
	task.spawn(function()
		while true do
			task.wait(1)
			local current = state
			if current == nil or current.stuckGoal ~= true or current.tutorialStep < 5 then
				continue
			end
			local on = stuckGoalActive(current)
			local where = StuckGoal.where((UI.cannon :: any).area, not areasShut())
			local target: Instance? = nil
			if on and where == "cat" then
				target = alleyStuckCat()
			elseif on and where == "cannon" then
				target = townCannon()
			end
			local distance: number? = nil
			if on and where == "cat" and target ~= nil and target:IsA("BasePart") then
				local character = Players.LocalPlayer.Character
				local root = if character ~= nil
					then character:FindFirstChild("HumanoidRootPart")
					else nil
				if root ~= nil and root:IsA("BasePart") then
					distance = ((target :: any).Position - root.Position).Magnitude
				end
			end
			local aside = StuckGoal.aside(distance, stuckGoal.aside)
			if target ~= stuckGoal.target or aside ~= stuckGoal.aside then
				stuckGoal.aside = aside
				refreshTutorial(current)
			end
			if on ~= stuckGoal.on then
				stuckGoal.on = on
				UI.update({ stuckGoal = on })
			end
		end
	end)
	-- #3529: the five cats pointer and the "NEW" tags follow the player, the strays and the switch; looked at once a
	-- second, and only while the switch is on
	task.spawn(function()
		while true do
			task.wait(1)
			local current = state
			if current == nil or not UI.newKind.on() then
				if newKind.goal ~= nil then
					newKind.goal = nil
					UI.update({ newKindGoal = false })
					if current ~= nil then
						refreshTutorial(current)
					end
				end
				continue
			end
			local kinds = kindsOf(current)
			if kinds ~= newKind.kinds then
				newKind.kinds = kinds
				newKind.idleSince = os.clock() -- a new kind: the trail waits its IDLE_SECONDS again
			end
			local goal = if newKindGoal(current) then kinds else nil
			if goal ~= newKind.goal then
				if newKind.goal == nil then
					newKind.idleSince = os.clock()
				end
				newKind.goal = goal
				UI.update({ newKindGoal = goal or false })
			end
			local on = newKindTrail(current)
			local where, target: Instance? = "none" :: NewKind.Where, nil
			if on then
				where, target = newKindTarget(current)
			end
			if target ~= newKind.target or where ~= newKind.where then
				refreshTutorial(current)
			end
			-- followed: the player came to the stray the trail leads to
			if on and where == "stray" and target ~= nil and target:IsA("BasePart") then
				local character = Players.LocalPlayer.Character
				local root = if character ~= nil
					then character:FindFirstChild("HumanoidRootPart")
					else nil
				if
					root ~= nil
					and root:IsA("BasePart")
					and NewKind.followed(root.Position, (target :: BasePart).Position)
				then
					reportNewKind("followed")
				end
			end
		end
	end)
	local function newKindBusy(busy: boolean)
		newKind.busy = busy
		UI.newKind.setBusy(busy)
		if busy then
			newKind.idleSince = os.clock()
		end
	end
	Moments.CatchStart:Connect(function()
		newKindBusy(true)
	end)
	Moments.CatchSuccess:Connect(function()
		newKindBusy(false)
	end)
	Moments.CatchFail:Connect(function()
		newKindBusy(false)
	end)
	Moments.RescueStart:Connect(function()
		stuckGoal.rescuing = true
		newKindBusy(true)
	end)
	local function rescueEnded()
		stuckGoal.rescuing = false
		newKindBusy(false)
	end
	Moments.RescueDone:Connect(rescueEnded)
	Moments.RescueFail:Connect(rescueEnded)
	Moments.RescueCancel:Connect(rescueEnded)
	wireIntents()
	wireServerEvents()
	bindDealerCart()
	bindStations()
	bindHelpPrompts()
	startPrediction()
	startCampWatch()
	Net.fire("RequestSync")
	print(string.format("[CatCafe] client ready for %s", player.Name))
end

return UIController
