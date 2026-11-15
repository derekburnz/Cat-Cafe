--!strict
-- The Cat Collector (F63, data-model section 12b, round 3 Q6). By day, each owned cafe that earns, has a table, has
-- more than one cat and has a resting, unlocked area cat gets him when its timer runs out (#1135: CollectorEveryMin to
-- CollectorEveryMax seconds of open day, shared/VisitTimer), outside the last DuskWarningSeconds. A hit picks the cat he wants and his offer now (shared/Collector) and he waits at the
-- counter's CollectorSpot for CollectorStaySeconds. The plot attributes CollectorUntil and CollectorCatId are display
-- only: every client stands him there from them (CustomerController) and Audio plays his arrival. The owner gets
-- CollectorOffer(catUid, offer, endsAt) for the card, and CollectorOffer("") when the visit ends.
-- AnswerCollector(accept) from the owner, from anywhere (#3216: his banner or tag opens the card): No thanks ends the visit. Trade checks the
-- cat is still theirs, resting, unlocked and not their last (else a toast says why and he waits on), then takes the
-- visit, removes the cat (collection and goldCollection keep it, so the Index never goes back) and pays the offer.
-- The timeout, nightfall, the owner leaving, or the cat being locked, put to work or sold ends the visit and nothing
-- is lost. Neither he nor his offer is ever sold, sped up or called with Robux.
-- Owner safety: the visit comes out of the table before the cat goes and the offer pays, so a trade happens once.
-- #3889: with the `rareCustomers` switch on the timer stops and RareCustomerService sends him
-- (CollectorService.arriveRare) when an arriving customer rolls Collector. A new account's first one still comes at
-- FirstVisitAt.collector, retrying every VisitRetrySeconds until there is a cat to ask for.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CafeService = require(script.Parent.CafeService)
local CatStats = require(ReplicatedStorage.Shared.CatStats)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local ClockService = require(script.Parent.ClockService)
local Collector = require(ReplicatedStorage.Shared.Collector)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local FirstVisit = require(script.Parent.Parent.Util.FirstVisit)
local FirstVisits = require(ReplicatedStorage.Shared.FirstVisits)
local Guard = require(script.Parent.Parent.Util.Guard)
local LateStations = require(ReplicatedStorage.Shared.LateStations)
local LiveFlagService = require(script.Parent.LiveFlagService)
local Net = require(script.Parent.Net)
local Payout = require(script.Parent.Payout)
local PlotService = require(script.Parent.PlotService)
local ProfileSchema = require(ReplicatedStorage.Shared.ProfileSchema)
local RareCustomers = require(ReplicatedStorage.Shared.RareCustomers)
local Telemetry = require(script.Parent.Telemetry)
local Trade = require(ReplicatedStorage.Shared.Trade)
local Types = require(ReplicatedStorage.Shared.Types)
local VisitTimer = require(ReplicatedStorage.Shared.VisitTimer)
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
	first: boolean, -- #2792: the account's first Collector, who stays FirstVisitStaySeconds and offers his top roll
	arrivedAt: number, -- os.time()
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
	FirstVisit.clear(visit.plot.model, "collector")
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
	if visit.first then
		FirstVisit.ended(
			player,
			visit.plot.model,
			"collector",
			outcome,
			os.time() - visit.arrivedAt
		)
	end
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
	elseif CatStats.atSpa(profile, visit.catUid) then
		return string.format("Your %s is at the spa.", name) -- #2651 part 4
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
	-- #3216 (Derek2: "accept cat collector trade through banner not needing to be beside it"): no range check; the
	-- visit is the owner's own and live, the remote is rate-limited, and Trade keeps every check on the cat below
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
	-- F102: a cat on offer in an open trade waits for the trade
	local why = blocker(profile, visit)
		or (if CafeService.isOffered(player, visit.catUid) then Trade.Messages.catInTrade else nil)
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
	now: number,
	first: boolean
): Visit
	take(plot.index)
	local visit: Visit = {
		ownerUserId = player.UserId,
		plot = plot,
		catUid = instance.uid,
		catId = instance.catId,
		variant = instance.variant,
		-- #2792: his first visit to an account offers the top of his roll
		offer = Collector.offerFor(Collector.value(instance, if first then 1 else roll())),
		endsAt = now + FirstVisits.stay(first, Config.CollectorStaySeconds),
		first = first,
		arrivedAt = now,
	}
	visits[plot.index] = visit
	show(plot, visit.endsAt, visit.catId)
	Net.fire(player, "CollectorOffer", visit.catUid, visit.offer, visit.endsAt, nil)
	-- #3132: no toast; the client's banner shows the cat's face, name and rarity from CollectorOffer
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
	return Collector.pickCat(profile.cats, roll, profile.tier, LateStations.spaUids(profile))
end

-- Each cafe's Collector timer (#1135, shared/VisitTimer): seconds of open day left until he next comes.
local timers: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any

-- Every second, `dt` the time since the last: by day only, before the last DuskWarningSeconds, each owned cafe
-- without a visit counts its timer down. When it runs out he comes if the cafe has a cat for him to ask for
-- (wantedAt) and a new timer is drawn; with none, he tries again in VisitRetrySeconds.
local function tickTimers(dt: number)
	local now = os.time()
	local dusk = math.floor(ClockService.phaseEndsAt())
	local open_ = not ClockService.isNight() and dusk - now > Config.DuskWarningSeconds
	local byChance = LiveFlagService.on(RareCustomers.FLAG) -- #3889: RareCustomerService sends him
	for _, player in DataService.loadedPlayers() do
		local plot = PlotService.get(player)
		if plot == nil then
			continue
		end
		local left = timers[player]
			or VisitTimer.draw(Config.CollectorEveryMin, Config.CollectorEveryMax, rng:NextNumber())
		local due: boolean
		-- #3889: by chance the timer only counts a first visit's retry wait down, and its end is never a visit itself
		local retrying = left <= Config.VisitRetrySeconds
		left, due = VisitTimer.tick(
			left,
			dt,
			open_ and visits[plot.index] == nil and (not byChance or retrying)
		)
		if byChance and due then
			due = false
			left = Config.VisitRetrySeconds + 1 -- the first visit's check below may run again
		end
		-- #2792: a new account's first Collector comes at FirstVisitAt.collector seconds of play, timer or not, and
		-- waits for a cat to ask for (VisitRetrySeconds) as a timed one does
		local profile = DataService.get(player)
		if
			not due
			and open_
			and visits[plot.index] == nil
			and profile ~= nil
			and left > Config.VisitRetrySeconds
			and FirstVisit.due(player, profile, "collector")
		then
			due = true
		end
		if due then
			local instance = wantedAt(player, plot)
			if instance ~= nil and profile ~= nil then
				arrive(
					player,
					plot,
					instance,
					now,
					FirstVisit.arrive(player, profile, plot.model, "collector")
				)
				left = VisitTimer.draw(
					Config.CollectorEveryMin,
					Config.CollectorEveryMax,
					rng:NextNumber()
				)
			else
				left = Config.VisitRetrySeconds
			end
		end
		timers[player] = left
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
			if
				instance == nil or not Collector.askable(instance, LateStations.spaUids(profile))
			then
				local gone = take(index)
				if gone ~= nil then
					logVisit(owner, gone, "withdrawn")
				end
			end
		end
	end
end

-- #3889: an arriving customer rolled Collector (RareCustomerService, `rareCustomers` on, the cafe open). False when he
-- cannot come now (a visit already on, or no cat for him to ask for).
function CollectorService.arriveRare(player: Player): boolean
	local plot = PlotService.get(player)
	local profile = DataService.get(player)
	if plot == nil or profile == nil or visits[plot.index] ~= nil then
		return false
	end
	local instance = wantedAt(player, plot)
	if instance == nil then
		return false
	end
	arrive(
		player,
		plot,
		instance,
		os.time(),
		FirstVisit.arrive(player, profile, plot.model, "collector")
	)
	return true
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
		local last = os.clock()
		while true do
			task.wait(1)
			checkVisits()
			local nowClock = os.clock()
			tickTimers(nowClock - last)
			last = nowClock
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
	local instance = if uid ~= nil
		then profile.cats[uid]
		else Collector.pickCat(profile.cats, roll, profile.tier, LateStations.spaUids(profile))
	if instance == nil or not Collector.askable(instance, LateStations.spaUids(profile)) then
		return nil, nil
	end
	local visit = arrive(player, plot, instance, os.time(), false)
	if valueRoll ~= nil then
		visit.offer = Collector.offerFor(Collector.value(instance, valueRoll))
		Net.fire(player, "CollectorOffer", visit.catUid, visit.offer, visit.endsAt, nil)
	end
	return visit.catUid, visit.offer
end

return CollectorService
