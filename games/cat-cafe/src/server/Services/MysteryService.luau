--!strict
-- The Mystery Visitor (F64, data-model section 12b). By day, every MysteryCheckSeconds, each owned cafe that earns
-- and has a table rolls MysteryChance, outside the last DuskWarningSeconds so a visitor never sits down only to
-- leave. A hit seats a hooded visitor for MysteryStaySeconds and puts a wrapped gift on the cafe's last table, rolled
-- now (shared/Potions.rollGift). The plot attributes MysteryVisitorUntil and MysteryGiftAt are display only: each
-- client builds the visitor and the gift from them (CustomerController) and the effects follow their tags;
-- MysteryTable names the gift's table.
-- The gift's anchor, MysteryGiftAnchor on the table top, carries the hold E GiftPrompt (Custom style: the UI draws
-- the pill with the gift's chances and turns it off for anyone but the owner). The owner opens it with the prompt or
-- OpenMysteryGift() within MysteryRangeStuds. Only an opening pays (Derek 2026-10-28 01:32: "if you miss it you miss
-- it"): an unopened gift is gone after MysteryGiftKeepSeconds or when its owner leaves, never opened for them.
-- Nightfall sends the visitor home; the gift stays on the table until it is opened or its time is up.
-- Owner safety: the gift comes out of the visit before it is paid, so a gift pays once.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CafeService = require(script.Parent.CafeService)
local ClockService = require(script.Parent.ClockService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Net = require(script.Parent.Net)
local Payout = require(script.Parent.Payout)
local PlotService = require(script.Parent.PlotService)
local Potions = require(ReplicatedStorage.Shared.Potions)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local MysteryService = {}

-- The gift's anchor on its table: a 1 stud box resting on the 2.6 stud table top, 0.8 toward the table's +x chair
-- (Chair_2), where the client seats the visitor, so it clears the rich tip's coin pile in the middle of table 1.
local GIFT_OFFSET = CFrame.new(0.8, 3.1, 0)

type Visit = {
	ownerUserId: number,
	plot: WorldBuilder.Plot,
	visitorUntil: number, -- os.time() the visitor leaves; 0 once it has
	gift: Potions.Gift?, -- nil once opened or gone
	giftUntil: number, -- os.time() an unopened gift is gone
	anchor: BasePart?, -- MysteryGiftAnchor while the gift waits
}

local visits: { [number]: Visit } = {} -- plot index -> its visit, one at a time
local rng = Random.new()

local function withinRange(player: Player, position: Vector3, range: number): boolean
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return root ~= nil
		and root:IsA("BasePart")
		and ((root :: BasePart).Position - position).Magnitude <= range
end

-- The visit is over once the visitor has left and the gift is gone.
local function forgetIfDone(index: number, visit: Visit)
	if visit.visitorUntil == 0 and visit.gift == nil and visits[index] == visit then
		visits[index] = nil
	end
end

local function sendHome(index: number)
	local visit = visits[index]
	if visit == nil or visit.visitorUntil == 0 then
		return
	end
	visit.visitorUntil = 0
	visit.plot.model:SetAttribute("MysteryVisitorUntil", 0)
	forgetIfDone(index, visit)
end

-- Takes the gift off the table: out of the visit, MysteryGiftAt cleared and the anchor gone. Only the caller that
-- gets it back may pay it.
local function takeGift(index: number): Potions.Gift?
	local visit = visits[index]
	local gift = if visit ~= nil then visit.gift else nil
	if visit == nil or gift == nil then
		return nil
	end
	visit.gift = nil
	visit.plot.model:SetAttribute("MysteryGiftAt", 0)
	if visit.anchor ~= nil then
		visit.anchor:Destroy()
		visit.anchor = nil
	end
	forgetIfDone(index, visit)
	return gift
end

local function logGift(
	player: Player,
	profile: Types.PlayerProfile,
	gift: Potions.Gift,
	outcome: string
)
	Telemetry.custom(
		player,
		"mystery_gift",
		gift.count,
		{ outcome, gift.kind, gift.id or "", tostring(Economy.tier(profile)) }
	)
end

-- A gift nobody opened: gone, nothing paid. `profile` when the caller has it already.
local function missGift(index: number, profile: Types.PlayerProfile?)
	local visit = visits[index]
	local gift = takeGift(index)
	if visit == nil or gift == nil then
		return
	end
	local owner = Players:GetPlayerByUserId(visit.ownerUserId)
	local ownerProfile = profile or (if owner ~= nil then DataService.get(owner) else nil)
	if owner ~= nil and ownerProfile ~= nil then
		logGift(owner, ownerProfile, gift, "missed")
	end
end

local function onOpen(player: Player)
	local plot = PlotService.get(player)
	if plot == nil then
		return
	end
	local visit = visits[plot.index]
	if
		visit == nil
		or visit.gift == nil
		or visit.ownerUserId ~= player.UserId
		or visit.plot ~= plot
	then
		return
	end
	if os.time() >= visit.giftUntil or visit.anchor == nil then
		return -- gone; the expiry check clears it within a second
	end
	-- the prompt shows from MysteryRangeStuds of the anchor; 2 studs of slack for movement in flight
	if
		not withinRange(player, (visit.anchor :: BasePart).Position, Config.MysteryRangeStuds + 2)
	then
		Net.toast(player, "Walk closer to open the gift", "info")
		return
	end
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	local gift = takeGift(plot.index)
	if gift == nil then
		return
	end
	Payout.pay(player, profile, Potions.giftPrize(gift), "mystery_gift")
	profile.stats.mysteryGifts = (profile.stats.mysteryGifts or 0) + 1
	logGift(player, profile, gift, "opened")
	Net.fire(player, "MysteryGiftResult", gift.kind, gift.id, gift.count)
	CafeService.sync(player)
end

local function arrive(
	player: Player,
	plot: WorldBuilder.Plot,
	tableIndex: number,
	now: number
): Visit
	takeGift(plot.index)
	local anchor = Instance.new("Part")
	anchor.Name = "MysteryGiftAnchor"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CFrame = plot.tableAnchors[tableIndex].CFrame * GIFT_OFFSET
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GiftPrompt"
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.ActionText = "Open"
	prompt.ObjectText = "Mystery gift"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = Config.MysteryRangeStuds
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(onOpen) -- onOpen checks the owner and the range itself
	prompt.Parent = anchor
	anchor.Parent = plot.model
	local visit: Visit = {
		ownerUserId = player.UserId,
		plot = plot,
		visitorUntil = now + Config.MysteryStaySeconds,
		gift = Potions.rollGift(function()
			return rng:NextNumber()
		end),
		giftUntil = now + Config.MysteryGiftKeepSeconds,
		anchor = anchor,
	}
	visits[plot.index] = visit
	-- both at once: the gift goes on the table as the visitor sits down (v0.10.1). MysteryTable says which table
	-- (table_<n>), so a client that only streams the cafe in later still seats the visitor at the gift's table.
	plot.model:SetAttribute("MysteryTable", tableIndex)
	plot.model:SetAttribute("MysteryVisitorUntil", visit.visitorUntil)
	plot.model:SetAttribute("MysteryGiftAt", now)
	return visit
end

-- By day only, before the last DuskWarningSeconds: each owned cafe that earns, has a table and no visit rolls
-- MysteryChance.
local function roll()
	local now = os.time()
	local dusk = math.floor(ClockService.phaseEndsAt())
	if ClockService.isNight() or dusk - now <= Config.DuskWarningSeconds then
		return
	end
	for _, player in DataService.loadedPlayers() do
		local plot = PlotService.get(player)
		local profile = DataService.get(player)
		if plot == nil or profile == nil or visits[plot.index] ~= nil then
			continue
		end
		local tables = math.min(Economy.level(profile, "tables"), #plot.tableAnchors)
		if Economy.incomePerSecond(profile) <= 0 or tables < 1 then
			continue
		end
		if rng:NextNumber() < Config.MysteryChance then
			arrive(player, plot, tables, now)
		end
	end
end

local function checkExpiries()
	local now = os.time()
	for index, visit in visits do
		if visit.visitorUntil > 0 and now >= visit.visitorUntil then
			sendHome(index)
		end
		if visit.gift ~= nil and now >= visit.giftUntil then
			missGift(index)
		end
	end
end

function MysteryService.start()
	Net.on("OpenMysteryGift", onOpen)
	-- leaving: the visitor goes home and an unopened gift is gone with its owner
	DataService.beforeRelease(function(player, profile)
		for index, visit in visits do
			if visit.ownerUserId == player.UserId then
				missGift(index, profile)
				sendHome(index)
			end
		end
	end)
	-- nightfall: the cafe closes and the visitor goes home; the gift waits (a debug jump to night lands here too)
	ClockService.changed:Connect(function(phase)
		if phase == "night" then
			for index in visits do
				sendHome(index)
			end
		end
	end)
	task.spawn(function()
		local nextRoll = os.clock() + Config.MysteryCheckSeconds
		while true do
			task.wait(1)
			checkExpiries()
			if os.clock() >= nextRoll then
				nextRoll = os.clock() + Config.MysteryCheckSeconds
				roll()
			end
		end
	end)
end

-- Studio-only test hook: a Mystery Visitor sits down at the player's cafe now, whatever the clock and the roll, with
-- `kind` ("potion", "lure", "fish" or "spin") when given. Returns what the gift holds, or nil without a cafe or a
-- table.
function MysteryService.debugArrive(player: Player, kind: string?): Potions.Gift?
	assert(RunService:IsStudio(), "debugArrive is Studio only")
	local plot = PlotService.get(player)
	local profile = DataService.get(player)
	if plot == nil or profile == nil then
		return nil
	end
	local tables = math.min(Economy.level(profile, "tables"), #plot.tableAnchors)
	if tables < 1 then
		return nil
	end
	sendHome(plot.index)
	local visit = arrive(player, plot, tables, os.time())
	for _ = 1, 200 do -- rerolls until the kind asked for; an unknown kind keeps the first roll
		if kind == nil or visit.gift == nil or (visit.gift :: Potions.Gift).kind == kind then
			break
		end
		visit.gift = Potions.rollGift(function()
			return rng:NextNumber()
		end)
	end
	return visit.gift
end

return MysteryService
