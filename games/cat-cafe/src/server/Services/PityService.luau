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
-- - The cat's end restarts its timer: the server that won the claim, or each server whose copy was still out at
--   night, writes Pity.restart (due a period from then) with UpdateAsync, and only while the stored timer still holds
--   that cat (Pity.keepStored), so two servers ending the same cat move it once. A write that fails is tried again
--   at the next read. The writer then publishes on Pity.TOPIC; every other server's copy of a caught cat puffs away
--   (CatService.removePity) with "Sam caught the pity cat!", and every server reads the new timer.
-- - At night every uncaught copy goes with the other strays (CatService.nightFalls) and its State clears.
-- No client remote: clients only read the folder, the stray's PityCat attribute and the clock. Analytics `pity_cat`.

local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CatService = require(script.Parent.CatService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local ClockService = require(script.Parent.ClockService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
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

local function timerOf(kind: Pity.Kind, now: number): Pity.Timer
	local timer = timers[kind]
	if fromStore and timer ~= nil then
		return timer
	end
	return Pity.fixedTimer(now, kind)
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

-- Marks cat `c` caught by `winner` and tells everyone, once.
local function markCaught(c: Current, winner: string)
	if c.state == "caught" then
		return
	end
	c.state = "caught"
	c.winner = winner
	publishState()
	Net.fireAll("Announce", Pity.caughtText(winner), c.kind)
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

-- Cat `c` has gone (caught here, or left at night): its timer restarts from now. A fixed slot's cat moves nothing.
local function restartTimer(c: Current)
	if c.seq <= 0 then
		return
	end
	local timer = Pity.restart(ClockService.now(), c.kind, c.seq)
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

-- Night (or a debug jump) ended `kind`'s cat: an uncaught one is gone with the other strays and its timer restarts.
local function endCat(kind: Pity.Kind)
	local c = currents[kind]
	if c == nil then
		return
	end
	currents[kind] = nil
	if c.state == "out" then
		log(nil, c, "expired")
		Net.fireAll("PityAnnounce", c.kind, c.areaId, "gone", nil)
		restartTimer(c)
	end
	publishState()
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
		end
	end)
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
	local c = currentFor(number)
	if c == nil then
		return true -- not a cat this server is running: nothing to claim
	end
	if c.wonHere then
		return true -- this server already holds the claim (the cat was knocked loose and caught again)
	end
	if c.state == "caught" then
		Net.toast(
			player,
			Pity.caughtText(c.winner or "Someone") .. " It puffed out of your net.",
			"warn"
		)
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
		publish({ kind = c.kind, seq = c.seq, winner = player.DisplayName })
		restartTimer(c)
		return true
	end
	local name = if winner ~= nil then winner.winner else "Someone"
	markCaught(c, name)
	Net.toast(player, Pity.caughtText(name) .. " It puffed out of your net.", "warn")
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
			local winner = string.sub(data.winner, 1, 40)
			local removed = CatService.removePity(Pity.number(c.seq, kind))
			if c.state == "out" then
				log(nil, c, if removed > 0 then "gone" else "lost")
			end
			markCaught(c, winner)
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
	endCat(kind) -- a cat of that kind still out goes first, and its timer restarts
	local timer = timerOf(kind, now)
	startCat(kind, timer, now, true)
	local c = currents[kind]
	return if c ~= nil then string.format("%s %d: in %s", kind, timer.seq, c.areaId) else "no spawn"
end

return PityService
