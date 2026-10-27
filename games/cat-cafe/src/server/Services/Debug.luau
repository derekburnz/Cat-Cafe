--!strict
-- Studio-only hooks for automated playtests (QA request, docs/decisions.md). Every function errors outside Studio.
-- From the command bar (Server view) or Studio MCP execute_luau while playing, go through the bridge that
-- Main.server.luau sets up, never require this module directly: a direct require gets a fresh copy whose
-- services never started ("profile not loaded", a clock nobody runs).
--   local D = game.ServerStorage.CatCafeDebug
--   D:Invoke("setCoins", nil, 5000)   -- nil means the first player in the server
--   D:Invoke("setPhase", "night")
--   D:Invoke("baitReady")              -- the bowl's cat arrives now
--   D:Invoke("richTip", nil, 20)       -- a rich customer's tip at your cafe that pays itself in 20 s
--   D:Invoke("knockLoose")             -- your carried cat drops as a knocked-loose stray (stand in an area)
--   D:Invoke("shove", "Player1", "Player2", "loose")  -- a real shove with every check, the roll forced
--   D:Invoke("telemetry", 20)          -- the last 20 analytics events, oldest first
--   D:Invoke("renameCat", nil, "Mochi")              -- RenameCat on your first working cat (or a uid as 4th arg)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CafeService = require(script.Parent.CafeService)
local CatService = require(script.Parent.CatService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local ClockService = require(script.Parent.ClockService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Layout = require(script.Parent.Parent.World.Layout)
local NameService = require(script.Parent.NameService)
local Net = require(script.Parent.Net)
local ProfileSchema = require(ReplicatedStorage.Shared.ProfileSchema)
local RescueService = require(script.Parent.RescueService)
local RichTipService = require(script.Parent.RichTipService)
local Shove = require(ReplicatedStorage.Shared.Shove)
local ShoveService = require(script.Parent.ShoveService)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)

local Debug = {}

local function guard()
	if not RunService:IsStudio() then
		error("[Debug] only available in Studio")
	end
end

local function profileOf(player: Player): Types.PlayerProfile
	guard()
	local profile = DataService.get(player)
	assert(profile ~= nil, "profile not loaded for " .. player.Name)
	return profile
end

local function resolve(player: Player | number | string | nil): Player
	if typeof(player) == "Instance" then
		return player :: Player
	end
	if type(player) == "number" then
		local found = Players:GetPlayerByUserId(player)
		assert(found ~= nil, "no player with that user id")
		return found :: Player
	end
	if type(player) == "string" then
		local found = Players:FindFirstChild(player)
		assert(found ~= nil and found:IsA("Player"), "no player named " .. player)
		return found :: Player
	end
	local first = Players:GetPlayers()[1]
	assert(first ~= nil, "no players in the server")
	return first
end

-- Authoritative state as the server sees it (settled first).
function Debug.snapshot(player: (Player | number | string)?): Types.PlayerState
	local p = resolve(player)
	local profile = profileOf(p)
	Economy.settle(profile, os.time(), ClockService.epoch())
	return CafeService.buildState(p, profile)
end

function Debug.setCoins(player: (Player | number | string)?, coins: number)
	local p = resolve(player)
	local profile = profileOf(p)
	Economy.settle(profile, os.time(), ClockService.epoch())
	profile.coins = coins
	CafeService.sync(p)
end

-- Pretend the player has been away: rewinds lastTick so the next settle credits `seconds` of income.
function Debug.setLastTick(player: (Player | number | string)?, secondsAgo: number)
	local p = resolve(player)
	local profile = profileOf(p)
	profile.lastTick = os.time() - secondsAgo
	CafeService.sync(p)
end

-- Wipes the profile back to the starting state (in memory; saved on leave like any other change).
function Debug.resetProfile(player: (Player | number | string)?)
	local p = resolve(player)
	local profile = profileOf(p)
	local fresh = ProfileSchema.template(os.time())
	for key, value in fresh :: any do
		(profile :: any)[key] = value
	end
	for key in profile :: any do
		if (fresh :: any)[key] == nil then
			(profile :: any)[key] = nil
		end
	end
	CafeService.refreshPlot(p)
	CafeService.sync(p)
end

-- Sets the cafe tier (1 to 5) without RankUp's checks or cost, for testing areas, slots, caps and expansions.
function Debug.setTier(player: (Player | number | string)?, tier: number)
	local p = resolve(player)
	local profile = profileOf(p)
	Economy.settle(profile, os.time(), ClockService.epoch())
	profile.tier = math.clamp(math.floor(tier), 1, Catalog.maxTier)
	CafeService.refreshPlot(p)
	CafeService.sync(p)
end

-- Adds `count` of a food (shop or dealer) to the player's lures.
function Debug.giveLure(player: (Player | number | string)?, lureId: string, count: number?)
	local p = resolve(player)
	local profile = profileOf(p)
	assert(Catalog.getLure(lureId) ~= nil, "unknown lure " .. lureId)
	profile.lures[lureId] = (profile.lures[lureId] or 0) + math.max(1, math.floor(count or 1))
	CafeService.sync(p)
end

-- Brings the cat at the bait bowl now instead of after LureWaitSeconds (F28). Errors when the bowl is empty.
-- Returns the rolled cat id, so a test can check what the card shows.
function Debug.baitReady(player: (Player | number | string)?): string
	local p = resolve(player)
	local profile = profileOf(p)
	local bait = profile.bait
	assert(bait ~= nil, "the bait bowl is empty")
	bait.placedAt = os.time() - Config.LureWaitSeconds
	CafeService.refreshPlot(p)
	CafeService.sync(p)
	return bait.catId
end

-- Opens a rich tip at the player's cafe now, whatever the clock and the roll (F31). `staySeconds` shortens the wait
-- before it pays itself (RichTipStaySeconds by default). Returns the amount.
function Debug.richTip(player: (Player | number | string)?, staySeconds: number?): number
	guard()
	return RichTipService.debugOpen(resolve(player), staySeconds)
end

-- Pretends the player rejoined after `secondsAgo` away: sets the unclaimed offline earnings to what that gap
-- pays at the current day rate and shows the popup. Returns the amount.
function Debug.setLastSeen(player: (Player | number | string)?, secondsAgo: number): number
	local p = resolve(player)
	profileOf(p)
	local amount = DataService.debugSetAway(p, math.max(0, secondsAgo))
	local pending, seconds = DataService.peekPendingOffline(p)
	if pending > 0 then
		Net.fire(p, "OfflineEarnings", pending, seconds)
	end
	return amount
end

-- Marks the in-memory profile as written by a newer version, so it saves that way on leave and the next join hits
-- the newer-save guard (kicked, data untouched). The dev profile then stays unloadable: clear it from the command
-- bar with game:GetService("DataStoreService"):GetDataStore("CatCafeProfiles_dev"):RemoveAsync("p_" .. userId).
function Debug.setSaveVersion(player: (Player | number | string)?, version: number)
	local p = resolve(player)
	local profile = profileOf(p)
	profile.version = math.floor(version)
end

-- Gives the player a cat as if checked in (skips the alley). `rescued` true marks it as rescued.
function Debug.giveCat(
	player: (Player | number | string)?,
	catId: string,
	rescued: boolean?
): Types.CatInstance
	local p = resolve(player)
	profileOf(p)
	local def = Catalog.getCat(catId)
	assert(def ~= nil, "unknown cat id " .. catId)
	local instance = CafeService.addCaughtCat(
		p,
		def :: Types.CatDef,
		true,
		nil,
		nil,
		if rescued then "rescue" else nil
	)
	return instance
end

function Debug.setUpgrade(player: (Player | number | string)?, upgradeId: string, level: number)
	local p = resolve(player)
	local profile = profileOf(p)
	local def = Catalog.getUpgrade(upgradeId)
	assert(def ~= nil, "unknown upgrade " .. upgradeId)
	profile.upgradeLevels[upgradeId] =
		math.clamp(level, (def :: Types.UpgradeDef).startLevel, (def :: Types.UpgradeDef).maxLevel)
	CafeService.refreshPlot(p)
	CafeService.sync(p)
end

-- Spawns a stray of the given cat in an area (any Catalog.areas id, "alley" by default), gold when `gold` is
-- true. Returns its StrayId.
function Debug.spawnStray(catId: string, areaId: string?, gold: boolean?): string
	guard()
	return CatService.debugSpawnStray(catId, areaId or "alley", gold)
end

-- Drops the player's carried cat where they stand as a shove would, whatever the grace or immunity, with nobody
-- barred as the shover: only they can catch it for DropOwnerPrioritySeconds. Stand in a catching area. Returns
-- the new StrayId.
function Debug.knockLoose(player: (Player | number | string)?): string
	guard()
	return CatService.debugKnockLoose(resolve(player))
end

-- `shover` shoves `target` through every section 10c check (the two must stand together in an area: teleport
-- both). `outcome` "loose" or "held" forces the roll on a carrier that can be knocked loose; nil rolls BumpChance.
function Debug.shove(
	shover: (Player | number | string)?,
	target: Player | number | string,
	outcome: string?
)
	guard()
	assert(
		outcome == nil or outcome == "loose" or outcome == "held",
		"outcome is loose, held or nil"
	)
	local forced: Shove.KnockResult? = if outcome == "loose"
		then "loose"
		elseif outcome == "held" then "held"
		else nil
	ShoveService.debugShove(resolve(shover), resolve(target), forced)
end

-- RenameCat as if the player sent it, with every check and the real filter (F33). `uid` defaults to a working cat,
-- else any cat. Returns the uid.
function Debug.renameCat(player: (Player | number | string)?, name: string, uid: string?): string
	local who = resolve(player)
	local profile = profileOf(who)
	local chosen = uid
	if chosen == nil then
		for catUid, instance in profile.cats do
			if chosen == nil or instance.spotId ~= nil then
				chosen = catUid
			end
			if instance.spotId ~= nil then
				break
			end
		end
	end
	assert(chosen ~= nil, "no cat to rename")
	NameService.debugRename(who, chosen :: string, name)
	return chosen :: string
end

-- Moves the player's character onto an area's first spawn point, past its gate whatever their tier, so a
-- playtest can check that a locked area refuses catches (F23).
function Debug.teleport(player: (Player | number | string)?, areaId: string)
	guard()
	local spec = Layout.areas[areaId]
	assert(spec ~= nil, "no area " .. tostring(areaId))
	local character = resolve(player).Character
	assert(character ~= nil, "no character")
	local point = spec.spawnPoints[1]
	character:PivotTo(CFrame.new(point.x + 3, spec.floorY + 4, point.z))
end

-- Jumps the server clock to the start of "day" or "night" at full length. Night rolls a wave and the rescue
-- spots at once, so a playtest does not wait two minutes for the first night.
function Debug.setPhase(phase: Types.ClockPhase)
	guard()
	assert(phase == "day" or phase == "night", "phase is day or night")
	ClockService.debugSetPhase(phase)
end

-- The clock as the server sees it: phase, server time it ends at, and seconds left.
function Debug.clock(): { phase: Types.ClockPhase, endsAt: number, secondsLeft: number }
	guard()
	local endsAt = ClockService.phaseEndsAt()
	return {
		phase = ClockService.phase(),
		endsAt = endsAt,
		secondsLeft = endsAt - Workspace:GetServerTimeNow(),
	}
end

-- Puts a stuck cat at a rescue trap ("rescue_alley_1" when none is given; the park's trees are rescue_park_1 and
-- rescue_park_2). `gold` true forces the hidden gold roll. Returns the rescueSpotId.
function Debug.spawnStuckCat(catId: string, rescueSpotId: string?, gold: boolean?): string
	guard()
	return RescueService.debugSpawnStuck(catId, rescueSpotId, gold)
end

-- Number of strays in an area and of stuck cats across all rescue traps.
function Debug.counts(areaId: string?): { strays: number, stuck: number }
	guard()
	return { strays = CatService.strayCount(areaId or "alley"), stuck = RescueService.stuckCount() }
end

function Debug.dataSaves(): boolean
	guard()
	return DataService.saves()
end

-- The last `count` analytics events this server logged (all of them, 200 at most, when nil), oldest first, one line
-- each: "onboarding first_catch 3", "sink tables 100 [1, day, 1]". Studio sends nothing to Roblox, so this is the
-- place to check the funnel order (F16).
function Debug.telemetry(count: number?): { string }
	guard()
	local lines: { string } = {}
	for _, entry in Telemetry.recent(count) do
		local fields = if #entry.fields > 0
			then " [" .. table.concat(entry.fields, ", ") .. "]"
			else ""
		table.insert(
			lines,
			string.format(
				"%d %s %s %s%s",
				entry.userId,
				entry.kind,
				entry.name,
				tostring(entry.value),
				fields
			)
		)
	end
	return lines
end

-- The player's onboarding funnel state: the last step logged and the steps held back until it catches up.
function Debug.onboarding(player: (Player | number | string)?): { step: number, held: { string } }
	guard()
	local profile = profileOf(resolve(player))
	local held: { string } = {}
	for key in profile.telemetry.achieved do
		table.insert(held, key)
	end
	table.sort(held, function(a, b)
		return (tonumber(a) or 0) < (tonumber(b) or 0)
	end)
	return { step = profile.telemetry.onboardingStep, held = held }
end

return Debug
