--!strict
-- The Cat Collector (F63, data-model section 12b, round 3 Q6). By day, every CollectorCheckSeconds, each owned cafe
-- that earns, has a table, has more than one cat and has a resting, unlocked area cat rolls CollectorChance, outside
-- the last DuskWarningSeconds. A hit picks the cat he wants and his offer now (shared/Collector) and he waits at the
-- counter's CollectorSpot for CollectorStaySeconds. The plot attributes CollectorUntil and CollectorCatId are display
-- only: every client stands him there from them (CustomerController) and Audio plays his arrival. The owner gets
-- CollectorOffer(catUid, offer, endsAt) for the card, and CollectorOffer("") when the visit ends.
-- AnswerCollector(accept) from the owner within CollectorRangeStuds of him: No thanks ends the visit. Trade checks the
-- cat is still theirs, resting, unlocked and not their last (else a toast says why and he waits on), then takes the
-- visit, removes the cat (collection and goldCollection keep it, so the Index never goes back) and pays the offer.
-- The timeout, nightfall, the owner leaving, or the cat being locked, put to work or sold ends the visit and nothing
-- is lost. Neither he nor his offer is ever sold, sped up or called with Robux.
-- Owner safety: the visit comes out of the table before the cat goes and the offer pays, so a trade happens once.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CafeService = require(script.Parent.CafeService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local ClockService = require(script.Parent.ClockService)
local Collector = require(ReplicatedStorage.Shared.Collector)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Guard = require(script.Parent.Parent.Util.Guard)
local Net = require(script.Parent.Net)
local Payout = require(script.Parent.Payout)
local PlotService = require(script.Parent.PlotService)
local ProfileSchema = require(ReplicatedStorage.Shared.ProfileSchema)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local CollectorService = {}

type Visit = {
	ownerUserId: number,
	plot: WorldBuilder.Plot,
	catUid: string,
	catId: string,
	variant: string,
	offer: Types.CollectorOffer,
	endsAt: number, -- os.time() he leaves
}

local visits: { [number]: Visit } = {} -- plot index -> its visit, one at a time
local rng = Random.new()

local function roll(): number
	return rng:NextNumber()
end

local function catName(catId: string): string
	local def = Catalog.getCat(catId)
	return if def ~= nil then def.name else catId
end

-- Where he stands: the plot's CollectorSpot, else the order point's line.
local function spotOf(plot: WorldBuilder.Plot): Vector3
	local spot = plot.model:FindFirstChild("CollectorSpot")
	if spot ~= nil and spot:IsA("BasePart") then
		return (spot :: BasePart).Position
	end
	return plot.customerEntry.Position
end

local function withinRange(player: Player, position: Vector3, range: number): boolean
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return root ~= nil
		and root:IsA("BasePart")
		and ((root :: BasePart).Position - position).Magnitude <= range
end

local function show(plot: WorldBuilder.Plot, endsAt: number, catId: string)
	plot.model:SetAttribute("CollectorUntil", endsAt)
	plot.model:SetAttribute("CollectorCatId", catId)
end

-- Takes the plot's visit out of the table and off the attributes, and tells the owner his card is gone. Only the
-- caller that gets it back may trade on it.
local function take(index: number, traded: boolean?): Visit?
	local visit = visits[index]
	if visit == nil then
		return nil
	end
	visits[index] = nil
	show(visit.plot, 0, "")
	local owner = Players:GetPlayerByUserId(visit.ownerUserId)
	if owner ~= nil then
		Net.fire(owner, "CollectorOffer", "", nil, 0, traded == true)
	end
	return visit
end

local function logVisit(player: Player, visit: Visit, outcome: string)
	-- three positional fields, as the Mystery gift's: the outcome, catId:variant and the offer row's value
	Telemetry.custom(
		player,
		"collector_visit",
		1,
		{ outcome, visit.catId .. ":" .. visit.variant, tostring(visit.offer.value) }
	)
end

-- Why the cat he asks for cannot be traded now, or nil when it can.
local function blocker(profile: Types.PlayerProfile, visit: Visit): string?
	local instance = profile.cats[visit.catUid]
	local name = catName(visit.catId)
	if instance == nil then
		return string.format("Your %s is not in your cafe any more.", name)
	elseif instance.spotId ~= nil then
		return string.format("Your %s is working. Take it off its job to trade it.", name)
	elseif instance.locked == true then
		return string.format("Your %s is locked. Unlock it to trade it.", name)
	elseif ProfileSchema.catCount(profile) <= 1 then
		return "You cannot trade your last cat."
	end
	return nil
end

local function onAnswer(player: Player, rawAccept: unknown)
	local accept = Guard.bool(rawAccept)
	local plot = PlotService.get(player)
	if accept == nil or plot == nil then
		return
	end
	local visit = visits[plot.index]
	if visit == nil or visit.ownerUserId ~= player.UserId or visit.plot ~= plot then
		return
	end
	if os.time() >= visit.endsAt then
		return -- gone; the expiry check ends it within a second
	end
	-- his card opens at CollectorRangeStuds; 2 studs of slack for movement in flight
	if not withinRange(player, spotOf(plot), Config.CollectorRangeStuds + 2) then
		Net.toast(player, "Walk over to the Cat Collector to answer him", "info")
		return
	end
	if not accept then
		local declined = take(plot.index)
		if declined ~= nil then
			logVisit(player, declined, "declined")
		end
		return
	end
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	local why = blocker(profile, visit)
	if why ~= nil then
		Net.toast(player, why, "warn")
		return
	end
	local traded = take(plot.index, true)
	if traded == nil then
		return
	end
	local instance = profile.cats[traded.catUid] :: Types.CatInstance
	local def = Catalog.getCat(instance.catId)
	if def == nil then
		return
	end
	profile.cats[traded.catUid] = nil -- the Index keeps it: collection and goldCollection are not touched
	local paid =
		Payout.pay(player, profile, Collector.prize(traded.offer, def.area), "collector_trade")
	profile.stats.collectorTrades = (profile.stats.collectorTrades or 0) + 1
	logVisit(player, traded, "traded")
	Net.toast(
		player,
		string.format("Traded %s to the Cat Collector for %s", def.name, table.concat(paid, ", ")),
		"good"
	)
	CafeService.refreshPlot(player)
	CafeService.sync(player)
end

local function arrive(
	player: Player,
	plot: WorldBuilder.Plot,
	instance: Types.CatInstance,
	now: number
): Visit
	take(plot.index)
	local visit: Visit = {
		ownerUserId = player.UserId,
		plot = plot,
		catUid = instance.uid,
		catId = instance.catId,
		variant = instance.variant,
		offer = Collector.offerFor(Collector.value(instance, roll())),
		endsAt = now + Config.CollectorStaySeconds,
	}
	visits[plot.index] = visit
	show(plot, visit.endsAt, visit.catId)
	Net.fire(player, "CollectorOffer", visit.catUid, visit.offer, visit.endsAt, nil)
	Net.toast(
		player,
		string.format("The Cat Collector is at your cafe! He wants your %s.", catName(visit.catId)),
		"info"
	)
	logVisit(player, visit, "arrived")
	return visit
end

-- Whether `player`'s cafe can host him now, and the cat he would ask for.
local function wantedAt(player: Player, plot: WorldBuilder.Plot): Types.CatInstance?
	local profile = DataService.get(player)
	if profile == nil or ProfileSchema.catCount(profile) <= 1 then
		return nil
	end
	local tables = math.min(Economy.level(profile, "tables"), #plot.tableAnchors)
	if Economy.incomePerSecond(profile) <= 0 or tables < 1 then
		return nil
	end
	return Collector.pickCat(profile.cats, roll)
end

-- By day only, before the last DuskWarningSeconds: each eligible cafe without a visit rolls CollectorChance.
local function rollVisits()
	local now = os.time()
	local dusk = math.floor(ClockService.phaseEndsAt())
	if ClockService.isNight() or dusk - now <= Config.DuskWarningSeconds then
		return
	end
	for _, player in DataService.loadedPlayers() do
		local plot = PlotService.get(player)
		if
			plot == nil
			or visits[plot.index] ~= nil
			or rng:NextNumber() >= Config.CollectorChance
		then
			continue
		end
		local instance = wantedAt(player, plot)
		if instance ~= nil then
			arrive(player, plot, instance, now)
		end
	end
end

-- Every second: his time is up, or the cat he asks for has been locked, put to work, sold or traded away.
local function checkVisits()
	local now = os.time()
	for index, visit in visits do
		local owner = Players:GetPlayerByUserId(visit.ownerUserId)
		local profile = if owner ~= nil then DataService.get(owner) else nil
		if now >= visit.endsAt then
			local gone = take(index)
			if owner ~= nil and gone ~= nil then
				logVisit(owner, gone, "timeout")
			end
		elseif owner == nil or profile == nil then
			take(index)
		else
			local instance = profile.cats[visit.catUid]
			if instance == nil or not Collector.askable(instance) then
				local gone = take(index)
				if gone ~= nil then
					logVisit(owner, gone, "withdrawn")
				end
			end
		end
	end
end

function CollectorService.start()
	Net.on("AnswerCollector", onAnswer)
	-- leaving: he goes too, nothing traded
	DataService.beforeRelease(function(player)
		for index, visit in visits do
			if visit.ownerUserId == player.UserId then
				take(index)
			end
		end
	end)
	-- nightfall: the cafe closes and he goes home (a debug jump to night lands here too)
	ClockService.changed:Connect(function(phase)
		if phase == "night" then
			for index in visits do
				take(index)
			end
		end
	end)
	task.spawn(function()
		local nextRoll = os.clock() + Config.CollectorCheckSeconds
		while true do
			task.wait(1)
			checkVisits()
			if os.clock() >= nextRoll then
				nextRoll = os.clock() + Config.CollectorCheckSeconds
				rollVisits()
			end
		end
	end)
end

-- The visit at `player`'s cafe, for tests and the debug hook: the cat's uid, the offer and when he leaves.
function CollectorService.visit(player: Player): (string?, Types.CollectorOffer?, number)
	local plot = PlotService.get(player)
	local visit = if plot ~= nil then visits[plot.index] else nil
	if visit == nil or visit.ownerUserId ~= player.UserId then
		return nil, nil, 0
	end
	return visit.catUid, visit.offer, visit.endsAt
end

-- Studio-only test hook: the Cat Collector arrives at the player's cafe now, whatever the clock, the roll and the
-- income, asking for the cat `uid` when given (it must still be askable) and with his value roll forced to `valueRoll`
-- (0 to 1) when given. Returns the uid he asks for and his offer, or nil without a cafe or an askable cat.
function CollectorService.debugArrive(
	player: Player,
	uid: string?,
	valueRoll: number?
): (string?, Types.CollectorOffer?)
	assert(RunService:IsStudio(), "debugArrive is Studio only")
	local plot = PlotService.get(player)
	local profile = DataService.get(player)
	if plot == nil or profile == nil then
		return nil, nil
	end
	local instance = if uid ~= nil then profile.cats[uid] else Collector.pickCat(profile.cats, roll)
	if instance == nil or not Collector.askable(instance) then
		return nil, nil
	end
	local visit = arrive(player, plot, instance, os.time())
	if valueRoll ~= nil then
		visit.offer = Collector.offerFor(Collector.value(instance, valueRoll))
		Net.fire(player, "CollectorOffer", visit.catUid, visit.offer, visit.endsAt, nil)
	end
	return visit.catUid, visit.offer
end

return CollectorService
