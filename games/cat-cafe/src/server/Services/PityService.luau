--!strict
-- The global pity cat (#1572, luck-and-rare-moments.md 1h; #1946, 1i: the timers restart; the clock and pick are
-- shared/Pity).
-- - Two timers, one per kind, held in MemoryStore HashMap MAP as "next:Legendary" and "next:Mythical" (a Pity.Timer:
--   when due on the shared clock, ClockService.now, and that kind's cat number `seq`). Every server reads them on
--   start, every READ_SECONDS and at once on a Pity.TOPIC message, and sets the folder's NextLegendary, NextMythical,
--   LiveLegendary and LiveMythical for the sign and the day card. With no timers stored yet the first boot starts
--   both (Pity.first: 30 minutes and 2 hours). Until a read works the server runs 1h's fixed slots and says so in
--   the output; after one has worked it keeps the last timers it saw.
-- - When a timer's spawn time comes (Pity.spawnTime: a due time at night waits for sunrise) every server spawns its
--   cat (CatService.spawnPity, the stray's PitySlot is Pity.number), sets the folder's State "out" with its Slot,
--   Kind and Area, and tells everyone: the banner as Announce (with "(opens at Tier N)" for a player whose tier
--   hasn't opened the area) and PityAnnounce for the sign and effects. A server that starts while that cat is out
--   spawns it too, unless the claim shows it was caught already. Both kinds can be out at once.
-- - The first catch anywhere wins. CatService asks `claim` on a pity cat's catch: an UpdateAsync on MAP that sets
--   Pity.claimKey(seq, kind) only if empty (expiry a day). This server's own earlier claim also counts as won. If
--   MemoryStore fails PityClaimRetries times, the catcher keeps the cat (we never take a cat away on our own error).
-- - The cat's spawn restarts its timer (#2003, Derek2 2026-11-07: "pity timers should instantly restart after they
--   spawned"; until then a catch or the night did): each server that starts it writes Pity.restart (due a period
--   after the spawn) with UpdateAsync, and only while the stored timer still holds that cat (Pity.keepStored), so
--   every server spawning the same cat moves it once. A write that fails is tried again at the next read. The writer
--   then publishes on Pity.TOPIC and every server reads the new timer. A server that starts while that cat is out
--   finds it from the moved timer (Pity.previous). On a catch the winner publishes too, and every other server's
--   copy puffs away (CatService.removePity) with "Sam caught the pity cat!".
-- - At night every uncaught copy goes with the other strays (CatService.nightFalls) and its State clears.
-- No client remote: clients only read the folder, the stray's PityCat attribute and the clock. Analytics `pity_cat`.
-- #2486 (live-events.md 2c): a Cafe Event's rare showers ride the same path. Each shower (CafeEvents.showerTimes of
-- EventService.recent()) is a pity cat on its own claim key (CafeEvents.showerKey) with its own cat number here
-- (SHOWER_BASE up), spawned in every server when it is due (at the next sunrise if that is at night), out until dusk,
-- claimed through the same MAP and announced on the same TOPIC ({ shower = key, winner }). It never touches the pity
-- timers. A server that starts late reads the claim first, as for a pity cat. Analytics `event_shower`.

local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CafeEvents = require(ReplicatedStorage.Shared.CafeEvents)
local CatService = require(script.Parent.CatService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local ClockService = require(script.Parent.ClockService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local EventService = require(script.Parent.EventService)
local Net = require(script.Parent.Net)
local Pity = require(ReplicatedStorage.Shared.Pity)
local Telemetry = require(script.Parent.Telemetry)

local PityService = {}

local MAP = "pity"
local CLAIM_EXPIRY_SECONDS = 86400
local TIMER_EXPIRY_SECONDS = 30 * 86400 -- rewritten after every cat, so this only clears a game nobody plays
local LATE_BANNER_SECONDS = 10 -- a server that starts later than this after a spawn shows no banner for it
local READ_SECONDS = 15
local TICK_SECONDS = 1

type Claim = { job: string, userId: number, winner: string }

type Current = {
	seq: number,
	kind: Pity.Kind,
	areaId: string,
	state: Pity.State,
	winner: string?,
	wonHere: boolean,
	spawnedAt: number,
	debug: boolean, -- Studio's debugSpawn: out until night, whatever the timer says
	steps: { [number]: number }?, -- #2796: the pity_v1 step each player (by user id) has logged for this cat
}

-- A restart this server owes the store: the timer to write once cat `ended` of its kind has gone.
type Pending = { ended: number, timer: Pity.Timer }

-- Runs `fn` for each kind (a loop over a list would widen the kind to a string).
local function eachKind(fn: (Pity.Kind) -> ())
	fn("Legendary")
	fn("Mythical")
end

local folder: Folder? = nil
local currents: { [string]: Current } = {} -- each kind's cat started here, until night or the next of its kind
local timers: { [string]: Pity.Timer } = {} -- the last stored timers seen (or written) here
local fromStore = false -- a read has worked: the timers come from the store, never the fixed slots again
local failing = false -- the last read failed (logged once a run of failures)
local tried = false -- the first read has finished: until then no cat spawns, so a boot never runs a fixed slot first
local pending: { [string]: Pending } = {}
local handled: { [string]: boolean } = {} -- claim keys of cats started here, so none spawns twice
local readAt = 0 -- os.clock() of the next read
local reading = false

-- #2486: the Cafe Event showers started here, by claim key, and the cat numbers they run under
type Shower = {
	key: string,
	number: number,
	eventId: string,
	pick: CafeEvents.ShowerPick,
	state: Pity.State,
	winner: string?,
	wonHere: boolean,
	spawnedAt: number, -- ClockService.now()
}
local SHOWER_BASE = 1e9 -- far above any pity cat's number (Pity.number)
local showers: { [string]: Shower } = {}
local showerHandled: { [string]: boolean } = {}
local showerNumber = SHOWER_BASE

local function timerOf(kind: Pity.Kind, now: number): Pity.Timer
	local timer = timers[kind]
	if fromStore and timer ~= nil then
		return timer
	end
	local fixed = Pity.fixedTimer(now, kind)
	if handled[Pity.claimKey(fixed.seq, kind)] then
		-- that slot's cat has started here: the next one counts down from now (the stored path restarts at spawn)
		return Pity.fixedNext(fixed, kind)
	end
	return fixed
end

-- The folder's one status line: the latest cat started here.
local function latest(): Current?
	local best: Current? = nil
	for _, c in currents do
		if best == nil or c.spawnedAt > best.spawnedAt then
			best = c
		end
	end
	return best
end

local function publishState()
	local f = folder
	if f == nil then
		return
	end
	local c = latest()
	f:SetAttribute("Slot", if c ~= nil then c.seq else 0)
	f:SetAttribute("Kind", if c ~= nil then c.kind else "")
	f:SetAttribute("Area", if c ~= nil then c.areaId else "")
	f:SetAttribute("State", if c ~= nil then c.state else "")
	f:SetAttribute("Winner", if c ~= nil then c.winner or "" else "")
	local now = ClockService.now()
	eachKind(function(kind: Pity.Kind)
		local own = currents[kind]
		local timer = timerOf(kind, now)
		f:SetAttribute(Pity.NEXT_ATTRIBUTE[kind], Pity.spawnTime(timer.at))
		f:SetAttribute(
			Pity.LIVE_ATTRIBUTE[kind],
			if own ~= nil and own.state == "out" then own.areaId else ""
		)
	end)
end

-- A player in the server to log a server event under (none in an empty server).
local function someone(): Player?
	return DataService.loadedPlayers()[1]
end

local function log(player: Player?, c: Current, outcome: string)
	local subject = player or someone()
	if subject ~= nil then
		Telemetry.custom(subject, "pity_cat", c.seq, { c.areaId, c.kind, outcome })
	end
end

-- #2796 (retention-ideas.md 5c): logs every pity_v1 step for `player` and this cat up to `step` not logged yet, so a
-- run always reads seen, catch started, caught in order.
local PITY_SEEN_STUDS = 60
local function stepTo(player: Player, c: Current, step: number)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	local steps = c.steps or {}
	c.steps = steps
	local done = steps[player.UserId] or 0
	for n = done + 1, step do
		Telemetry.pityStep(player, profile, Pity.claimKey(c.seq, c.kind), n, c.kind, c.areaId)
	end
	steps[player.UserId] = math.max(done, step)
end

-- #2796: step 1 for every player within PITY_SEEN_STUDS of an uncaught pity cat this server runs.
local function noteSeen()
	for _, c in currents do
		if c.state ~= "out" then
			continue
		end
		local at = CatService.pityPosition(Pity.number(c.seq, c.kind))
		if at == nil then
			continue
		end
		for _, player in DataService.loadedPlayers() do
			local character = player.Character
			local root = if character ~= nil
				then character:FindFirstChild("HumanoidRootPart")
				else nil
			if
				root ~= nil
				and root:IsA("BasePart")
				and (c.steps == nil or (c.steps :: { [number]: number })[player.UserId] == nil)
				and ((root :: BasePart).Position - at).Magnitude <= PITY_SEEN_STUDS
			then
				stepTo(player, c, 1)
			end
		end
	end
end

-- The banner to every player, with the tier that opens the area for anyone who can't go there yet.
local function announceSpawn(c: Current)
	local area = Catalog.getArea(c.areaId)
	for _, player in Players:GetPlayers() do
		local profile = DataService.get(player)
		local opensAt = if area ~= nil
				and profile ~= nil
				and profile.tier < area.tier
			then area.tier
			else nil
		Net.fire(player, "Announce", Pity.spawnText(c.kind, c.areaId, opensAt), c.kind)
	end
	Net.fireAll("PityAnnounce", c.kind, c.areaId, "out", nil)
end

-- Marks cat `c` caught, once. `winner` is the catcher's name when the catch was in this server, else nil (#2567:
-- another server's catch shows no name, banner or chat line here; the sign and copy still reset).
local function markCaught(c: Current, winner: string?)
	if c.state == "caught" then
		return
	end
	c.state = "caught"
	c.winner = winner
	publishState()
	local banner = Pity.caughtBanner(winner)
	if banner ~= nil then
		Net.fireAll("Announce", banner, c.kind)
	end
	Net.fireAll("PityAnnounce", c.kind, c.areaId, "caught", winner)
end

local function hashMap(): MemoryStoreHashMap
	return MemoryStoreService:GetHashMap(MAP)
end

local function timerKey(kind: Pity.Kind): string
	return "next:" .. kind
end

local function publish(data: { [string]: any })
	data.job = game.JobId
	task.spawn(function()
		pcall(function()
			MessagingService:PublishAsync(Pity.TOPIC, data)
		end)
	end)
end

-- The claim stored under `key`, or nil when none (or the read failed).
local function readClaim(key: string): Claim?
	local ok, value = pcall(function(): any
		return hashMap():GetAsync(key)
	end)
	if
		ok
		and type(value) == "table"
		and type(value.winner) == "string"
		and type(value.job) == "string"
	then
		return value :: Claim
	end
	return nil
end

-- Writes `kind`'s owed restart (it yields). True once the store holds a timer past the cat that ended.
local function writePending(kind: Pity.Kind): boolean
	local owed = pending[kind]
	if owed == nil then
		return true
	end
	local result: Pity.Timer? = nil
	local ok, err = pcall(function()
		hashMap():UpdateAsync(timerKey(kind), function(old: any): any
			local stored = Pity.readTimer(old)
			if stored ~= nil and Pity.keepStored(stored, owed.ended) then
				result = stored
				return nil -- another server moved it already
			end
			result = owed.timer
			return owed.timer
		end, TIMER_EXPIRY_SECONDS)
	end)
	if not ok or result == nil then
		warn(`[PityService] {kind} timer restart not saved yet, trying again: {tostring(err)}`)
		return false
	end
	if pending[kind] == owed then
		pending[kind] = nil
	end
	local stored = result :: Pity.Timer
	local known = timers[kind]
	if known == nil or stored.seq >= known.seq then
		timers[kind] = stored
	end
	publishState()
	publish({ kind = kind, at = stored.at, seq = stored.seq })
	return true
end

-- Cat `c` has spawned at `at`: its timer restarts from then (#2003). A fixed slot's cat moves nothing.
local function restartTimer(c: Current, at: number)
	if c.seq <= 0 then
		return
	end
	local timer = Pity.restart(at, c.kind, c.seq)
	local known = timers[c.kind]
	if known == nil or known.seq <= c.seq then
		timers[c.kind] = timer
	end
	pending[c.kind] = { ended = c.seq, timer = timer }
	publishState()
	task.spawn(writePending, c.kind)
end

-- One read of both timers (it yields), with the first boot's start when none is stored.
local function readTimers()
	local now = ClockService.now()
	local okAll = true
	eachKind(function(kind: Pity.Kind)
		if pending[kind] ~= nil and not writePending(kind) then
			okAll = false
			return
		end
		local stored: Pity.Timer? = nil
		local ok, err = pcall(function()
			local raw = hashMap():GetAsync(timerKey(kind))
			stored = Pity.readTimer(raw)
			if stored == nil then
				hashMap():UpdateAsync(timerKey(kind), function(old: any): any
					local again = Pity.readTimer(old)
					if again ~= nil then
						stored = again
						return nil
					end
					local start = Pity.first(now, kind)
					stored = start
					return start
				end, TIMER_EXPIRY_SECONDS)
			end
		end)
		if not ok or stored == nil then
			okAll = false
			if not failing then
				warn(
					`[PityService] could not read the {kind} timer ({tostring(err)}): `
						.. if fromStore
							then "keeping the last one seen"
							else "running the fixed slots until a read works"
				)
			end
			return
		end
		local read = stored :: Pity.Timer
		local owed = pending[kind]
		if owed == nil or read.seq > owed.ended then
			timers[kind] = read
		end
	end)
	tried = true
	if okAll then
		if not fromStore then
			-- a fixed slot's timer goes for both kinds at once, so the sign never mixes the two
			fromStore = timers["Legendary"] ~= nil and timers["Mythical"] ~= nil
		end
		failing = false
	else
		failing = true
	end
	publishState()
end

-- Starts `kind`'s cat for `timer` here: it comes out (unless a server already got it), with the banner if fresh.
local function startCat(kind: Pity.Kind, timer: Pity.Timer, now: number, debug: boolean)
	local key = Pity.claimKey(timer.seq, kind)
	handled[key] = true
	local pick = Pity.pickTimer(timer, kind)
	local spawn = Pity.spawnTime(timer.at)
	local c: Current = {
		seq = timer.seq,
		kind = kind,
		areaId = pick.areaId,
		state = "out",
		winner = nil,
		wonHere = false,
		-- a cat nobody saw go (no server ran that night) comes out now
		spawnedAt = if debug or not Pity.stillOut(spawn, now) then now else spawn,
		debug = debug,
	}
	local before = currents[kind]
	if before ~= nil and before.state == "out" then
		CatService.removePity(Pity.number(before.seq, kind))
	end
	currents[kind] = c
	restartTimer(c, c.spawnedAt) -- #2003: the next of its kind counts from this spawn, caught or not
	-- a server that starts while the cat is out joins in quietly; one nobody saw (a night passed) is fresh news
	local overdue = not debug and now - spawn > LATE_BANNER_SECONDS
	local late = overdue and Pity.stillOut(spawn, now)
	if overdue then
		local claimed = readClaim(key)
		if currents[kind] ~= c then
			return
		end
		if claimed ~= nil then
			c.state = "caught"
			c.winner = claimed.winner
			publishState()
			return
		end
	end
	if CatService.spawnPity(pick.catId, pick.areaId, kind, Pity.number(timer.seq, kind)) == nil then
		warn(
			string.format(
				"[PityService] %s %d: could not spawn %s in %s",
				kind,
				timer.seq,
				pick.catId,
				pick.areaId
			)
		)
		currents[kind] = nil
		publishState()
		return
	end
	publishState()
	if not late then
		announceSpawn(c)
		log(nil, c, "spawned") -- #1888: so secured, lost, gone and expired read against the cats that came
	end
end

-- Night (or a debug jump) ended `kind`'s cat: an uncaught one is gone with the other strays (its timer restarted
-- when it spawned, #2003).
local function endCat(kind: Pity.Kind)
	local c = currents[kind]
	if c == nil then
		return
	end
	currents[kind] = nil
	if c.state == "out" then
		log(nil, c, "expired")
		Net.fireAll("PityAnnounce", c.kind, c.areaId, "gone", nil)
	end
	publishState()
end

-- #2486: the shower cats' analytics, under a player in the server.
local function logShower(player: Player?, s: Shower, outcome: string)
	local subject = player or someone()
	if subject ~= nil then
		Telemetry.custom(
			subject,
			"event_shower",
			s.pick.n,
			{ s.eventId, s.pick.areaId, s.pick.kind, outcome }
		)
	end
end

-- `winner` nil: another server's catch, so no banner here (#2567).
local function showerCaught(s: Shower, winner: string?)
	if s.state == "caught" then
		return
	end
	s.state = "caught"
	s.winner = winner
	if winner ~= nil then
		Net.fireAll("Announce", CafeEvents.showerCaughtText(winner), s.pick.kind)
	end
end

-- Spawns the n-th shower of `event` here (it may yield on a late start's claim read).
local function startShower(
	event: CafeEvents.Event,
	n: number,
	key: string,
	spawn: number,
	now: number
)
	showerHandled[key] = true
	showerNumber += 1
	local s: Shower = {
		key = key,
		number = showerNumber,
		eventId = event.id,
		pick = CafeEvents.showerPick(event, n),
		state = "out",
		winner = nil,
		wonHere = false,
		spawnedAt = spawn,
	}
	showers[key] = s
	local late = now - spawn > LATE_BANNER_SECONDS
	if late then
		local claimed = readClaim(key)
		if claimed ~= nil then
			s.state = "caught"
			s.winner = claimed.winner
			return
		end
	end
	local pick = s.pick
	if CatService.spawnPity(pick.catId, pick.areaId, pick.kind, s.number, pick.coat) == nil then
		warn(
			string.format(
				"[PityService] shower %s: could not spawn %s in %s",
				key,
				pick.catId,
				pick.areaId
			)
		)
		showers[key] = nil
		return
	end
	if late then
		return -- joins in quietly, as a late pity cat does
	end
	local area = Catalog.getArea(pick.areaId)
	for _, player in Players:GetPlayers() do
		local profile = DataService.get(player)
		local opensAt = if area ~= nil
				and profile ~= nil
				and profile.tier < area.tier
			then area.tier
			else nil
		Net.fire(player, "Announce", CafeEvents.showerText(pick, opensAt), pick.kind)
	end
	logShower(nil, s, "spawned")
end

-- Each tick: showers past dusk go, and the event's due ones start (by day only).
local function showerTick(now: number)
	for key, s in showers do
		if not Pity.stillOut(s.spawnedAt, now) then
			showers[key] = nil
			if s.state == "out" then
				logShower(nil, s, "expired")
			end
		end
	end
	local event = EventService.recent()
	if event == nil or event.effects.showers == nil or not ClockService.areasOpen() then
		return
	end
	-- the shower times are server time; the clock's t runs alongside it
	local offset = Workspace:GetServerTimeNow() - now
	for n, due in CafeEvents.showerTimes(event) do
		local key = CafeEvents.showerKey(event, n, game.JobId)
		if showerHandled[key] then
			continue
		end
		local spawn = Pity.spawnTime(due - offset)
		if now < spawn then
			break -- in time order: the rest are later
		end
		if not Pity.stillOut(spawn, now) then
			showerHandled[key] = true -- a night came since: that one went at dusk
			continue
		end
		task.spawn(startShower, event, n, key, spawn, now)
	end
end

local function showerFor(number: number): Shower?
	for _, s in showers do
		if s.number == number then
			return s
		end
	end
	return nil
end

-- A shower cat's catch (it yields), as `claim` for a pity cat: true when this catch keeps it.
local function claimShower(player: Player, s: Shower): boolean
	if s.wonHere then
		return true
	end
	if s.state == "caught" then
		Net.toast(player, Pity.LOST_TEXT, "warn")
		logShower(player, s, "lost")
		return false
	end
	local mine: Claim = { job = game.JobId, userId = player.UserId, winner = player.DisplayName }
	local stored: Claim? = nil
	for _ = 1, Config.PityClaimRetries do
		local ok = pcall(function()
			hashMap():UpdateAsync(s.key, function(old: any): any
				if type(old) == "table" and type(old.job) == "string" then
					stored = old :: Claim
					return nil
				end
				stored = mine
				return mine
			end, CLAIM_EXPIRY_SECONDS)
		end)
		if ok then
			break
		end
		stored = nil
	end
	if showers[s.key] ~= s then
		return false -- dusk came meanwhile
	end
	local winner: Claim = stored or mine -- MemoryStore failed every time: the catcher keeps it
	if winner.job == game.JobId then
		s.wonHere = true
		showerCaught(s, player.DisplayName)
		logShower(player, s, "secured")
		publish({ shower = s.key, winner = player.DisplayName })
		return true
	end
	showerCaught(s, nil)
	Net.toast(player, Pity.LOST_TEXT, "warn")
	logShower(player, s, "lost")
	return false
end

local function tick()
	local now = ClockService.now()
	eachKind(function(kind: Pity.Kind)
		local c = currents[kind]
		if c ~= nil then
			local over = if c.debug
				then not ClockService.areasOpen()
				else not Pity.stillOut(c.spawnedAt, now)
			if over then
				endCat(kind)
			end
		end
		local own = currents[kind]
		local timer = timerOf(kind, now)
		if
			tried
			and (own == nil or own.state == "caught")
			and ClockService.areasOpen()
			and now >= Pity.spawnTime(timer.at)
			and not handled[Pity.claimKey(timer.seq, kind)]
		then
			startCat(kind, timer, now, false)
		elseif own == nil and tried and fromStore and ClockService.areasOpen() then
			-- #2003: the timer already moved past a cat that is still out (another server spawned it before this one
			-- started or read): this server joins in with its copy, or shows it caught
			local before = Pity.previous(timer, kind)
			if
				before ~= nil
				and Pity.stillOut(Pity.spawnTime(before.at), now)
				and not handled[Pity.claimKey(before.seq, kind)]
			then
				startCat(kind, before, now, false)
			end
		end
	end)
	showerTick(now) -- #2486
	noteSeen() -- #2796
	publishState() -- the fixed slots' timers move on their own
	if not reading and os.clock() >= readAt then
		reading = true
		readAt = os.clock() + READ_SECONDS
		task.spawn(function()
			local ok, err = pcall(function()
				readTimers()
			end)
			if not ok then
				warn("[PityService] read: " .. tostring(err))
			end
			reading = false
		end)
	end
end

local function currentFor(number: number): Current?
	for _, c in currents do
		if Pity.number(c.seq, c.kind) == number then
			return c
		end
	end
	return nil
end

-- CatService's claim on a pity cat's catch (it yields): true when this catch keeps the cat.
local function claim(player: Player, number: number): boolean
	local shower = showerFor(number)
	if shower ~= nil then
		return claimShower(player, shower)
	end
	local c = currentFor(number)
	if c == nil then
		return true -- not a cat this server is running: nothing to claim
	end
	if c.wonHere then
		return true -- this server already holds the claim (the cat was knocked loose and caught again)
	end
	if c.state == "caught" then
		Net.toast(player, Pity.LOST_TEXT, "warn")
		log(player, c, "lost")
		return false
	end
	local key = Pity.claimKey(c.seq, c.kind)
	local mine: Claim = { job = game.JobId, userId = player.UserId, winner = player.DisplayName }
	local stored: Claim? = nil
	local failure = ""
	for _ = 1, Config.PityClaimRetries do
		local ok, err = pcall(function()
			hashMap():UpdateAsync(key, function(old: any): any
				if type(old) == "table" and type(old.job) == "string" then
					stored = old :: Claim
					return nil -- already claimed: leave it
				end
				stored = mine
				return mine
			end, CLAIM_EXPIRY_SECONDS)
		end)
		if ok then
			failure = ""
			break
		end
		failure = tostring(err)
		stored = nil
	end
	if currents[c.kind] ~= c then
		return false -- night (or the next cat of its kind) came meanwhile
	end
	local winner: Claim? = stored
	if winner == nil then
		-- MemoryStore failed every time: the catcher keeps the cat, and the log says so
		warn(
			string.format(
				"[PityService] %s: claim failed (%s), %s keeps the cat",
				key,
				failure,
				player.Name
			)
		)
		winner = mine
	end
	local won = winner ~= nil and winner.job == game.JobId
	if won then
		c.wonHere = true
		markCaught(c, player.DisplayName)
		log(player, c, "secured")
		stepTo(player, c, 3) -- #2796
		publish({ kind = c.kind, seq = c.seq, winner = player.DisplayName })
		return true
	end
	markCaught(c, nil)
	Net.toast(player, Pity.LOST_TEXT, "warn")
	log(player, c, "lost")
	return false
end

-- Another server's news: its catch got a cat (this server's copy puffs away), or a timer moved. Either way the
-- timers are read again at once.
local function onMessage(message: any)
	local data = if type(message) == "table" then message.Data else nil
	if type(data) ~= "table" or data.job == game.JobId then
		return
	end
	if type(data.shower) == "string" and type(data.winner) == "string" then
		-- #2486: another server's catch got a shower cat: this server's copy puffs away
		local s = showers[data.shower]
		if s ~= nil and not s.wonHere then
			local removed = CatService.removePity(s.number)
			if s.state == "out" then
				logShower(nil, s, if removed > 0 then "gone" else "lost")
			end
			showerCaught(s, nil)
		end
		return
	end
	local kind: Pity.Kind? = if data.kind == "Legendary"
		then "Legendary"
		elseif data.kind == "Mythical" then "Mythical"
		else nil
	if kind == nil or type(data.seq) ~= "number" then
		return
	end
	if type(data.winner) == "string" then
		local c = currents[kind]
		if c ~= nil and c.seq == data.seq and not c.wonHere then
			local removed = CatService.removePity(Pity.number(c.seq, kind))
			if c.state == "out" then
				log(nil, c, if removed > 0 then "gone" else "lost")
			end
			markCaught(c, nil)
		end
	else
		local moved = Pity.readTimer({ at = data.at, seq = data.seq })
		local known = timers[kind]
		if fromStore and moved ~= nil and (known == nil or moved.seq >= known.seq) then
			timers[kind] = moved
			publishState()
		end
	end
	readAt = 0
end

function PityService.start()
	local existing = ReplicatedStorage:FindFirstChild(Pity.FOLDER)
	if existing ~= nil and existing:IsA("Folder") then
		folder = existing :: Folder
	else
		local created = Instance.new("Folder")
		created.Name = Pity.FOLDER
		created.Parent = ReplicatedStorage
		folder = created
	end
	publishState()
	CatService.setPityClaim(claim)
	-- #2796: pity_v1's catch-started step
	CatService.setPityStarted(function(player: Player, number: number)
		local c = currentFor(number)
		if c ~= nil and c.state == "out" then
			stepTo(player, c, 2)
		end
	end)
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:SubscribeAsync(Pity.TOPIC, onMessage)
		end)
		if not ok then
			warn("[PityService] no pity messages from other servers: " .. tostring(err))
		end
	end)
	task.spawn(function()
		while true do
			-- one bad tick must not end the pity cat for the server's life
			xpcall(tick, function(err: unknown)
				warn("[PityService] tick: " .. tostring(err))
			end)
			task.wait(TICK_SECONDS)
		end
	end)
end

-- Studio-only test hook: spawns the sooner timer's cat now (QA), as if its time had come.
function PityService.debugSpawn(): string
	assert(RunService:IsStudio(), "debugSpawn is Studio only")
	local now = ClockService.now()
	local legendary, mythical = timerOf("Legendary", now), timerOf("Mythical", now)
	local kind: Pity.Kind = if Pity.spawnTime(mythical.at) < Pity.spawnTime(legendary.at)
		then "Mythical"
		else "Legendary"
	endCat(kind) -- a cat of that kind still out goes first; this one restarts the timer from now
	local timer = timerOf(kind, now)
	startCat(kind, timer, now, true)
	local c = currents[kind]
	return if c ~= nil then string.format("%s %d: in %s", kind, timer.seq, c.areaId) else "no spawn"
end

return PityService
