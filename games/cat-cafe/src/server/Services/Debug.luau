--!strict
-- Studio-only hooks for automated playtests (QA request, docs/decisions.md). Every function errors outside Studio.
-- From the command bar or Studio MCP execute_luau while playing:
--   local Debug = require(game.ServerScriptService.Server.Services.Debug)
--   Debug.setCoins(game.Players:GetPlayers()[1], 5000)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CafeService = require(script.Parent.CafeService)
local CatService = require(script.Parent.CatService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local ClockService = require(script.Parent.ClockService)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local ProfileSchema = require(ReplicatedStorage.Shared.ProfileSchema)
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
	Economy.settle(profile, os.time())
	return CafeService.buildState(p, profile)
end

function Debug.setCoins(player: (Player | number | string)?, coins: number)
	local p = resolve(player)
	local profile = profileOf(p)
	Economy.settle(profile, os.time())
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

-- Gives the player a cat as if checked in (skips the alley). `rescued` true gives it the rescued tips bonus.
function Debug.giveCat(
	player: (Player | number | string)?,
	catId: string,
	rescued: boolean?
): Types.CatInstance
	local p = resolve(player)
	profileOf(p)
	local def = Catalog.getCat(catId)
	assert(def ~= nil, "unknown cat id " .. catId)
	local instance = CafeService.addCaughtCat(p, def :: Types.CatDef, true, nil, nil, rescued)
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

-- Spawns a stray of the given cat in an area ("alley" or "park"). Returns its StrayId.
function Debug.spawnStray(catId: string, areaId: string?): string
	guard()
	return CatService.debugSpawnStray(catId, areaId or "alley")
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

-- Puts a stuck cat at a rescue spot ("rescue_alley_1" when none is given). Returns the rescueSpotId.
function Debug.spawnStuckCat(catId: string, rescueSpotId: string?): string
	guard()
	return CatService.debugSpawnStuck(catId, rescueSpotId)
end

-- Number of strays in an area and of stuck cats across all rescue spots.
function Debug.counts(areaId: string?): { strays: number, stuck: number }
	guard()
	return { strays = CatService.strayCount(areaId or "alley"), stuck = CatService.stuckCount() }
end

function Debug.dataSaves(): boolean
	guard()
	return DataService.saves()
end

return Debug
