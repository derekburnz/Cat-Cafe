--!strict
-- Rich customers (F31, data-model section 12; #3360, rich-money-bags.md). By day, each owned cafe that earns and has
-- a table gets a rich customer when its timer runs out (#1135: RichEveryMin to RichEveryMax seconds of open day,
-- shared/VisitTimer). The customer leaves a money bag on table 1 at once (shared/RichBags) and sits a moment for show;
-- the bag is the timer, not the customer. This service's own table holds the bags, keyed by plot, up to RichBagsMax:
--   { id, slot, amount = Economy.richTipAmount(day rate), droppedAt, expiresAt = droppedAt + RichBagSeconds, first }
-- There is no dusk clamp: a bag dropped by day waits its full time through nightfall, like a Mystery gift. Until
-- #3360 the tip's expiry stopped at dusk, so a customer arriving in the day's last 90 s had a short timer.
-- For display only, each bag is a child of the plot's RichBags folder (attributes Amount, ExpiresAt, Slot, and Outcome
-- "claimed" or "missed" just before it goes) and the front bag (the next to go) is mirrored to the plot attributes
-- RichTipAmount, RichTipExpiresAt and RichTipOutcome, which the gold marker reads; RichVisitAt (os.time()) marks each
-- drop, for the client's rich customer. Decisions read the table.
-- ClaimRichTip(bagId?) from the owner within RichTipRangeStuds of that bag (no id: the front one) before its expiry
-- pays it now. Only a claim pays (Derek 2026-10-28 01:32: "if you miss it you miss it"): at expiry or when the owner
-- leaves the bag is gone unpaid. A rich customer comes only by day before the dusk warning (data-model 12 v0.13.4),
-- and the timer keeps counting while bags wait, holding at 0 while the plot is full.
-- Owner safety (S29): every path takes the bag out of the table before it adds coins, so a bag pays exactly once.
-- #3889: with the `rareCustomers` switch on the timer stops and RareCustomerService sends the customer
-- (RichTipService.arriveRare) when an arriving customer rolls rich; the bag then waits on any open table, which the
-- plot attribute RichTable names for the client's rich customer (1 by default). A new account's first one still
-- comes at FirstVisitAt.rich, on table 1.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CafeService = require(script.Parent.CafeService)
local ClockService = require(script.Parent.ClockService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local FirstVisit = require(script.Parent.Parent.Util.FirstVisit)
local FirstVisits = require(ReplicatedStorage.Shared.FirstVisits)
local Guard = require(script.Parent.Parent.Util.Guard)
local LiveFlagService = require(script.Parent.LiveFlagService)
local Net = require(script.Parent.Net)
local PlotService = require(script.Parent.PlotService)
local RareCustomers = require(ReplicatedStorage.Shared.RareCustomers)
local RichBags = require(ReplicatedStorage.Shared.RichBags)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)
local VisitTimer = require(ReplicatedStorage.Shared.VisitTimer)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local RichTipService = {}

-- One plot's waiting bags and whose they are. `plot` is kept so a bag clears off the right model after a release.
type Held = {
	ownerUserId: number,
	plot: WorldBuilder.Plot,
	bags: { RichBags.Bag },
}

local held: { [number]: Held } = {} -- plot index -> its waiting bags
local serial = 0
local rng = Random.new()
-- After a bag goes, the plot's attributes show "no tip" with its outcome for this long before the next waiting bag
-- shows, so the client sees the claim or the miss as its own change.
local NEXT_BAG_SECONDS = 0.6

local function withinRange(player: Player, position: Vector3, range: number): boolean
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return root ~= nil
		and root:IsA("BasePart")
		and ((root :: BasePart).Position - position).Magnitude <= range
end

local function show(plot: WorldBuilder.Plot, amount: number, expiresAt: number, outcome: string?)
	plot.model:SetAttribute("RichTipOutcome", outcome)
	plot.model:SetAttribute("RichTipAmount", amount)
	plot.model:SetAttribute("RichTipExpiresAt", expiresAt)
end

-- Where a bag sits: its slot's offset from the plot's RichTipAnchor, along the table.
-- #3889: on another table, the same spot on that table (the anchor's place on table 1, moved to that table's anchor).
local function positionOf(plot: WorldBuilder.Plot, bag: RichBags.Bag): Vector3
	local offset = RichBags.offset(bag.slot)
	local base = plot.richTipAnchor.CFrame
	local index = bag.tableIndex
	local first: BasePart? = plot.tableAnchors[1]
	local other: BasePart? = if index ~= nil then plot.tableAnchors[index] else nil
	if first ~= nil and other ~= nil and index ~= 1 then
		base = other.CFrame * first.CFrame:ToObjectSpace(base)
	end
	return (base * CFrame.new(offset.x, 0, offset.z)).Position
end

local function folderOf(plot: WorldBuilder.Plot): Folder
	local found = plot.model:FindFirstChild(RichBags.FOLDER)
	if found ~= nil and found:IsA("Folder") then
		return found :: Folder
	end
	local made = Instance.new("Folder")
	made.Name = RichBags.FOLDER
	made.Parent = plot.model
	return made
end

-- The plot's attributes show its front bag, or no tip.
local function showFront(index: number)
	local entry = held[index]
	if entry == nil then
		return
	end
	local front = RichBags.front(entry.bags)
	if front ~= nil then
		show(entry.plot, front.amount, front.expiresAt, "")
	end
end

-- Takes a bag off the plot: out of the table and off the display, with `outcome` ("claimed" or "missed") for the
-- client. Only the caller that gets it back may pay it, so no two paths can pay the same bag.
local function take(index: number, id: string, outcome: string): RichBags.Bag?
	local entry = held[index]
	if entry == nil then
		return nil
	end
	local bag = RichBags.remove(entry.bags, id)
	if bag == nil then
		return nil
	end
	local plot = entry.plot
	local record = folderOf(plot):FindFirstChild(bag.id)
	if record ~= nil then
		record:SetAttribute("Outcome", outcome)
		task.delay(NEXT_BAG_SECONDS, function()
			record:Destroy()
		end)
	end
	show(plot, 0, 0, outcome)
	if #entry.bags == 0 then
		held[index] = nil
	else
		task.delay(NEXT_BAG_SECONDS, function()
			showFront(index)
		end)
	end
	if bag.first then
		local owner = Players:GetPlayerByUserId(entry.ownerUserId)
		FirstVisit.ended(owner, plot.model, "rich", outcome, os.time() - bag.droppedAt)
	end
	return bag
end

-- rich_tip: the amount, with the outcome, the tier and (#3360) the whole seconds the bag waited.
local function logBag(
	player: Player,
	profile: Types.PlayerProfile,
	bag: RichBags.Bag,
	outcome: string
)
	Telemetry.custom(player, "rich_tip", bag.amount, {
		outcome,
		tostring(Economy.tier(profile)),
		tostring(math.max(0, os.time() - bag.droppedAt)),
	})
end

local function pay(player: Player, bag: RichBags.Bag)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	Economy.credit(profile, bag.amount)
	Economy.noteEventExtra(profile, bag.amount, bag.boost)
	Telemetry.source(player, profile, bag.amount, "Gameplay", "rich_tip")
	logBag(player, profile, bag, "claimed")
	CafeService.sync(player)
end

-- A bag nobody claimed: gone, no coins (analytics rich_tip "missed"). `profile` when the caller has it already.
local function miss(index: number, id: string, profile: Types.PlayerProfile?)
	local entry = held[index]
	local ownerUserId = if entry ~= nil then entry.ownerUserId else nil
	local bag = take(index, id, "missed")
	if bag == nil or ownerUserId == nil then
		return
	end
	local owner = Players:GetPlayerByUserId(ownerUserId)
	local ownerProfile = profile or (if owner ~= nil then DataService.get(owner) else nil)
	if owner ~= nil and ownerProfile ~= nil then
		logBag(owner, ownerProfile, bag, "missed")
	end
end

-- #3632: display records on the plot that no bag in the table stands behind go, as missed. The marker reads the
-- records, so one left over (a plot's earlier owner, a table and its records come apart) shows a bag nobody can
-- collect and a Collect button that only spins.
local function clearOrphans(plot: WorldBuilder.Plot)
	local folder = plot.model:FindFirstChild(RichBags.FOLDER)
	if folder == nil then
		return
	end
	local entry = held[plot.index]
	local bags: { RichBags.Bag } = if entry ~= nil and entry.plot == plot then entry.bags else {}
	local names: { string } = {}
	for _, record in folder:GetChildren() do
		if record:GetAttribute("Outcome") == nil then
			table.insert(names, record.Name)
		end
	end
	for _, name in RichBags.orphans(names, bags) do
		local record = folder:FindFirstChild(name)
		if record ~= nil then
			record:SetAttribute("Outcome", "missed")
			task.delay(NEXT_BAG_SECONDS, function()
				record:Destroy()
			end)
		end
	end
end

-- #3632: a claim the server will not pay is answered, never dropped in silence: the client's Collect reads
-- "Collecting..." until the bag's record changes, so a silent refusal is a button that spins. The refusal clears
-- any record with no bag behind it and is written to the log (one line a player every 10 s at most).
local refusedAt: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any

local function refuse(player: Player, plot: WorldBuilder.Plot?, why: string)
	if plot ~= nil then
		clearOrphans(plot)
	end
	local now = os.clock()
	if (refusedAt[player] or -math.huge) + 10 < now then
		refusedAt[player] = now
		warn("[RichTipService] claim refused: " .. why)
	end
end

local function onClaimRichTip(player: Player, rawBagId: unknown)
	-- #3360: no id is the front bag (the gold marker's Collect); an id must be an id (Guard) before any lookup
	local bagId: string? = nil
	if rawBagId ~= nil then
		bagId = Guard.id(rawBagId)
		if bagId == nil then
			return
		end
	end
	local plot = PlotService.get(player)
	if plot == nil then
		return
	end
	local entry = held[plot.index]
	if entry == nil or entry.ownerUserId ~= player.UserId or entry.plot ~= plot then
		if entry ~= nil then
			held[plot.index] = nil -- the plot is this player's (PlotService): an earlier owner's entry is stale
		end
		refuse(player, plot, if entry == nil then "no bags held" else "bags held for another owner")
		return
	end
	local bag: RichBags.Bag? = if bagId ~= nil
		then RichBags.find(entry.bags, bagId)
		else RichBags.front(entry.bags)
	if bag == nil then
		refuse(player, plot, "no such bag")
		return
	end
	if os.time() >= bag.expiresAt then
		miss(plot.index, bag.id) -- its time is up: gone now, not at the next expiry check
		return
	end
	-- the device checks RichTipRangeStuds from the HumanoidRootPart; 2 studs of slack for movement in flight
	if not withinRange(player, positionOf(plot, bag), Config.RichTipRangeStuds + 2) then
		Net.toast(player, "Walk closer to collect the money bag", "info")
		return
	end
	local taken = take(plot.index, bag.id, "claimed")
	if taken ~= nil then
		pay(player, taken)
	end
end

-- Clears every bag whose time is up, unpaid.
local function checkExpiries()
	local now = os.time()
	for index, entry in held do
		for _, id in RichBags.expired(entry.bags, now) do
			miss(index, id)
		end
	end
end

-- Drops a bag on the plot: the whole rich payout, waiting `seconds` from now (RichBagSeconds, or the first visit's
-- longer stay). Nil when the plot is full.
local function drop(
	player: Player,
	plot: WorldBuilder.Plot,
	dayRate: number,
	now: number,
	first: boolean,
	seconds: number?,
	tableIndex: number?
): RichBags.Bag?
	local existing = held[plot.index]
	local entry: Held
	if existing ~= nil and existing.ownerUserId == player.UserId and existing.plot == plot then
		entry = existing
	else
		-- none yet (a stale one never blocks the plot's new owner; release clears them, belt and braces)
		entry = { ownerUserId = player.UserId, plot = plot, bags = {} }
		held[plot.index] = entry
		clearOrphans(plot) -- #3632: and no record of an earlier bag is left for the new owner's marker
	end
	local slot = RichBags.freeSlot(entry.bags)
	if slot == nil then
		return nil
	end
	serial += 1
	local bag: RichBags.Bag = {
		id = RichBags.idOf(serial),
		slot = slot,
		amount = Economy.richTipAmount(dayRate * Economy.eventMoney()), -- #2486: x a running Cafe Event's money
		boost = Economy.eventMoney(),
		droppedAt = now,
		expiresAt = now + (seconds or FirstVisits.stay(first, Config.RichBagSeconds)),
		first = first,
		tableIndex = tableIndex,
	}
	table.insert(entry.bags, bag)
	local record = Instance.new("Configuration")
	record.Name = bag.id
	record:SetAttribute("Amount", bag.amount)
	record:SetAttribute("ExpiresAt", bag.expiresAt)
	record:SetAttribute("Slot", bag.slot)
	record:SetAttribute("Position", positionOf(plot, bag))
	record.Parent = folderOf(plot)
	plot.model:SetAttribute("RichTable", tableIndex or 1) -- #3889: before RichVisitAt, so the customer sits there
	plot.model:SetAttribute("RichVisitAt", now) -- the client's rich customer walks in for this drop
	showFront(plot.index)
	return bag
end

local function bagCount(index: number): number
	local entry = held[index]
	return if entry ~= nil then #entry.bags else 0
end

-- Each cafe's rich-customer timer (#1135, shared/VisitTimer): seconds of open day left until the next one.
local timers: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any

-- Every second, `dt` the time since the last: by day only, before the last DuskWarningSeconds, each owned cafe that
-- earns and has a table for the rich customer to sit at counts its timer down, and when it runs out the rich customer
-- comes, leaves a bag and a new timer is drawn. #3360: the timer counts while bags wait; with RichBagsMax waiting it
-- holds at 0 and the next customer comes when a bag goes. A Tip Potion running when the visitor comes adds its share
-- to the bag (F64).
local function tickTimers(dt: number)
	local now = os.time()
	local dusk = math.floor(ClockService.phaseEndsAt())
	local open_ = not ClockService.isNight() and dusk - now > Config.DuskWarningSeconds
	local byChance = LiveFlagService.on(RareCustomers.FLAG) -- #3889: RareCustomerService sends them
	for _, player in DataService.loadedPlayers() do
		local plot = PlotService.get(player)
		local profile = DataService.get(player)
		if plot == nil or profile == nil then
			continue
		end
		local dayRate = Economy.incomePerSecond(profile)
		local counting = open_ and dayRate > 0 and Economy.level(profile, "tables") >= 1
		-- the timer counts while bags wait; with RichBagsMax waiting it holds at 0 and the customer comes when one goes
		local ready = counting and bagCount(plot.index) < Config.RichBagsMax
		-- #1624: Cafe Style and Grand Cafe bring rich visitors more often (Economy.richRate)
		local left = timers[player]
			or VisitTimer.draw(Config.RichEveryMin, Config.RichEveryMax, rng:NextNumber())
				/ Economy.richRate(profile)
		local due: boolean
		left, due = VisitTimer.tick(left, dt, counting and not byChance)
		due = due and ready
		-- #2792: a new account's first rich customer comes at FirstVisitAt.rich seconds of play, timer or not
		if ready and not due and FirstVisit.due(player, profile, "rich") then
			due = true
		end
		if due then
			local first = FirstVisit.arrive(player, profile, plot.model, "rich")
			drop(player, plot, dayRate * Economy.tipMultiplier(profile, now), now, first)
			left = VisitTimer.draw(Config.RichEveryMin, Config.RichEveryMax, rng:NextNumber())
				/ Economy.richRate(profile)
		end
		timers[player] = left
	end
end

-- #3889: an arriving customer rolled rich (RareCustomerService, `rareCustomers` on, the cafe open). The bag waits on
-- one of the cafe's open tables. False when the cafe cannot take one now (no income, no table, RichBagsMax waiting).
function RichTipService.arriveRare(player: Player, u: number): boolean
	local plot = PlotService.get(player)
	local profile = DataService.get(player)
	if plot == nil or profile == nil then
		return false
	end
	local dayRate = Economy.incomePerSecond(profile)
	local tables = math.min(Economy.level(profile, "tables"), #plot.tableAnchors)
	if dayRate <= 0 or tables < 1 or bagCount(plot.index) >= Config.RichBagsMax then
		return false
	end
	local now = os.time()
	local first = FirstVisit.arrive(player, profile, plot.model, "rich")
	local bag = drop(
		player,
		plot,
		dayRate * Economy.tipMultiplier(profile, now),
		now,
		first,
		nil,
		RareCustomers.tableFor(tables, u)
	)
	return bag ~= nil
end

function RichTipService.start()
	Net.on("ClaimRichTip", onClaimRichTip)
	-- leaving: every waiting bag is missed, like any other unclaimed one, and its display goes with it
	DataService.beforeRelease(function(player, profile)
		for index, entry in held do
			if entry.ownerUserId == player.UserId then
				local ids: { string } = {}
				for _, bag in entry.bags do
					table.insert(ids, bag.id)
				end
				for _, id in ids do
					miss(index, id, profile)
				end
				folderOf(entry.plot):ClearAllChildren()
				entry.plot.model:SetAttribute("RichVisitAt", nil)
			end
		end
	end)
	-- #3360: nightfall no longer takes the bags; they wait their full time
	task.spawn(function()
		local last = os.clock()
		local loopWarnedAt = -math.huge
		while true do
			task.wait(1)
			-- #3632: one error must not end the loop: with it go every expiry and every later rich customer on
			-- this server
			local nowClock = os.clock()
			local dt = nowClock - last
			last = nowClock
			local ok, problem = pcall(function()
				checkExpiries()
				return nil :: any
			end)
			local ok2, problem2 = pcall(function()
				tickTimers(dt)
				return nil :: any
			end)
			if not (ok and ok2) and loopWarnedAt + 60 < nowClock then
				loopWarnedAt = nowClock
				warn(
					"[RichTipService] loop step failed: "
						.. tostring(if not ok then problem else problem2)
				)
			end
		end
	end)
end

-- Studio-only test hook: drops a money bag at the player's cafe now, whatever the clock and the roll, waiting
-- `staySeconds` (RichBagSeconds by default). Returns the amount, or 0 when the player has no cafe or it is full.
function RichTipService.debugOpen(player: Player, staySeconds: number?): number
	assert(RunService:IsStudio(), "debugOpen is Studio only")
	local plot = PlotService.get(player)
	local profile = DataService.get(player)
	if plot == nil or profile == nil then
		return 0
	end
	local bag = drop(player, plot, Economy.incomePerSecond(profile), os.time(), false, staySeconds)
	return if bag ~= nil then bag.amount else 0
end

return RichTipService
