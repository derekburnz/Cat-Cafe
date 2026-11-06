--!strict
-- The global pity cat (#1572, luck-and-rare-moments.md 1h; the clock and pick are shared/Pity). Every server runs the
-- same slots on the shared clock (ClockService.now), so each spawns the same cat in the same area at the same time
-- with no shared store:
-- - At a slot's spawn (Pity.spawnAt) the server spawns the cat (CatService.spawnPity), sets ReplicatedStorage.Pity's
--   State "out" with its Slot, Kind and Area, and tells everyone: the banner as Announce (with "(opens at Tier N)"
--   for a player whose tier hasn't opened the area) and PityAnnounce for the sign and effects. A server that starts
--   while a slot's cat is out spawns it too, unless the claim shows it was caught already.
-- - The first catch anywhere wins. CatService asks `claim` on a pity cat's catch: an UpdateAsync on
--   MemoryStore HashMap MAP that sets Pity.claimKey(slot) only if empty (expiry a day). This server's own earlier
--   claim also counts as won. The winner publishes on MessagingService topic Pity.TOPIC, and every other server's
--   copy puffs away (CatService.removePity) with "Sam caught the pity cat!". A catch that loses the claim puffs out of
--   the net with the same banner; there's no consolation prize. If MemoryStore fails PityClaimRetries times, the
--   catcher keeps the cat (we never take a cat away on our own error) and the output says so.
-- - At night every uncaught copy goes with the other strays (CatService.nightFalls) and the State clears.
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

local MAP = "PityClaims"
local CLAIM_EXPIRY_SECONDS = 86400
local LATE_BANNER_SECONDS = 10 -- a server that starts later than this after a spawn shows no banner for it
local TICK_SECONDS = 1

type Claim = { job: string, userId: number, winner: string }

type Current = {
	slot: number,
	kind: Pity.Kind,
	areaId: string,
	state: Pity.State,
	winner: string?,
	wonHere: boolean,
	debug: boolean, -- Studio's debugSpawn: out until night, whatever the slot clock says
}

local folder: Folder? = nil
local current: Current? = nil -- the slot being handled, nil when none is out
local handled = 0 -- the last slot started here, so it never spawns twice

local function publishState()
	local f = folder
	if f == nil then
		return
	end
	local c = current
	f:SetAttribute("Slot", if c ~= nil then c.slot else 0)
	f:SetAttribute("Kind", if c ~= nil then c.kind else "")
	f:SetAttribute("Area", if c ~= nil then c.areaId else "")
	f:SetAttribute("State", if c ~= nil then c.state else "")
	f:SetAttribute("Winner", if c ~= nil then c.winner or "" else "")
end

-- A player in the server to log a server event under (none in an empty server).
local function someone(): Player?
	return DataService.loadedPlayers()[1]
end

local function log(player: Player?, c: Current, outcome: string)
	local subject = player or someone()
	if subject ~= nil then
		Telemetry.custom(subject, "pity_cat", c.slot, { c.areaId, c.kind, outcome })
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

-- Marks the current slot caught by `winner` and tells everyone, once.
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

-- The claim stored for `slot`, or nil when none (or the read failed).
local function readClaim(slot: number): Claim?
	local ok, value = pcall(function(): any
		return hashMap():GetAsync(Pity.claimKey(slot))
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

-- Starts slot `slot` here: its cat comes out (unless a server already got it), with the banner if it is fresh.
local function startSlot(slot: number)
	local pick = Pity.pick(slot)
	local c: Current = {
		slot = slot,
		kind = pick.kind,
		areaId = pick.areaId,
		state = "out",
		winner = nil,
		wonHere = false,
		debug = false,
	}
	current = c
	local late = ClockService.now() - Pity.spawnAt(slot) > LATE_BANNER_SECONDS
	if late then
		local claimed = readClaim(slot)
		if claimed ~= nil then
			c.state = "caught"
			c.winner = claimed.winner
			publishState()
			return
		end
	end
	if CatService.spawnPity(pick.catId, pick.areaId, pick.kind, slot) == nil then
		warn(
			string.format(
				"[PityService] slot %d: could not spawn %s in %s",
				slot,
				pick.catId,
				pick.areaId
			)
		)
		current = nil
		publishState()
		return
	end
	publishState()
	if not late then
		announceSpawn(c)
	end
end

-- Night (or a debug jump) ended the slot: an uncaught cat is gone with the other strays.
local function endSlot()
	local c = current
	if c == nil then
		return
	end
	current = nil
	if c.state == "out" then
		log(nil, c, "expired")
		Net.fireAll("PityAnnounce", c.kind, c.areaId, "gone", nil)
	end
	publishState()
end

local function tick()
	local live = Pity.live(ClockService.now())
	local c = current
	if c ~= nil and live ~= c.slot and not (c.debug and ClockService.areasOpen()) then
		endSlot()
	end
	if live ~= nil and live > handled and ClockService.areasOpen() then
		handled = live
		startSlot(live)
	end
end

-- CatService's claim on a pity cat's catch (it yields): true when this catch keeps the cat.
local function claim(player: Player, slot: number): boolean
	local c = current
	if c == nil or c.slot ~= slot then
		return true -- not the slot this server is running (a debug spawn): nothing to claim
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
	local mine: Claim = { job = game.JobId, userId = player.UserId, winner = player.DisplayName }
	local stored: Claim? = nil
	local failure = ""
	for _ = 1, Config.PityClaimRetries do
		local ok, err = pcall(function()
			hashMap():UpdateAsync(Pity.claimKey(slot), function(old: any): any
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
	if current ~= c then
		return false -- night came meanwhile
	end
	local winner: Claim? = stored
	if winner == nil then
		-- MemoryStore failed every time: the catcher keeps the cat, and the log says so
		warn(
			string.format(
				"[PityService] slot %d: claim failed (%s), %s keeps the cat",
				slot,
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
		task.spawn(function()
			pcall(function()
				MessagingService:PublishAsync(
					Pity.TOPIC,
					{ slot = slot, winner = player.DisplayName, job = game.JobId }
				)
			end)
		end)
		return true
	end
	local name = if winner ~= nil then winner.winner else "Someone"
	markCaught(c, name)
	Net.toast(player, Pity.caughtText(name) .. " It puffed out of your net.", "warn")
	log(player, c, "lost")
	return false
end

-- Another server's catch got the cat: this server's copy puffs away.
local function onMessage(message: any)
	local data = if type(message) == "table" then message.Data else nil
	if type(data) ~= "table" or type(data.slot) ~= "number" or type(data.winner) ~= "string" then
		return
	end
	if data.job == game.JobId then
		return
	end
	local c = current
	if c == nil or c.slot ~= data.slot or c.wonHere then
		return
	end
	local winner = string.sub(data.winner, 1, 40)
	local removed = CatService.removePity(c.slot)
	if c.state == "out" then
		log(nil, c, if removed > 0 then "gone" else "lost")
	end
	markCaught(c, winner)
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

-- Studio-only test hook: spawns the next slot's cat now (QA), as if its time had come.
function PityService.debugSpawn(): string
	assert(RunService:IsStudio(), "debugSpawn is Studio only")
	local _, slot = Pity.nextAt(ClockService.now())
	endSlot()
	handled = math.max(handled, slot)
	startSlot(slot)
	local c = current
	if c ~= nil then
		c.debug = true
	end
	return if c ~= nil
		then string.format("slot %d: %s in %s", slot, c.kind, c.areaId)
		else "no spawn"
end

return PityService
