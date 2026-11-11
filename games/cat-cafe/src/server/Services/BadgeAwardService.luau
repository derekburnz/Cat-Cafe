--!strict
-- Roblox badges (#1934, release.md section 1): the server awards each loaded player every badge they have earned
-- (shared/Badges, read from the profile alone) and do not own yet. Nothing waits on Roblox and nothing reaches the
-- client: Roblox shows its own notice for an award.
-- * On join the player's owned badges are looked up once (CheckUserBadgesAsync, LOOKUP_BATCH ids a call, the batch
--   form of UserHasBadgeAsync). A lookup that fails is tried again after LOOKUP_RETRY_SECONDS, and nothing is
--   awarded until one works, so an owned badge is never awarded twice.
-- * Every CHECK_SECONDS the due badges are awarded in turn (AwardBadgeAsync in a pcall). A failed award goes on the
--   retry list: it waits RETRY_SECONDS, doubling up to RETRY_MAX_SECONDS, and is tried again at the next check after
--   that, or on the next join.
-- * The first pass after the lookup is the catch-up: badges earned before this join (or made after they were
--   earned) are awarded quietly and logged as "catchup"; later ones are "live" (Telemetry badge_awarded).
-- A badge whose Config.Badges id is 0 is not made yet and is skipped.
-- #3324: while the owner's account (Config.OwnerUserIds) is in the server, every other loaded player is due Met the
-- Owner: everyone already here when the owner joins, and anyone who joins while the owner stays.

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Badges = require(ReplicatedStorage.Shared.Badges)
local ChatTags = require(ReplicatedStorage.Shared.ChatTags)
local DataService = require(script.Parent.DataService)
local PlayTime = require(script.Parent.Parent.Util.PlayTime)
local Telemetry = require(script.Parent.Telemetry)

local BadgeAwardService = {}

local CHECK_SECONDS = 3
local LOOKUP_BATCH = 10 -- CheckUserBadgesAsync takes at most 10 badge ids a call
local LOOKUP_RETRY_SECONDS = 60
local RETRY_SECONDS = 60
local RETRY_MAX_SECONDS = 900

type State = {
	owned: { [number]: boolean }, -- badge id -> true, filled by the lookup
	ready: boolean, -- a lookup has worked
	lookupAt: number, -- os.clock() when the next lookup may run
	busy: boolean, -- a lookup or awards are running
	caughtUp: boolean, -- the first pass after the lookup has run
	catchup: { [string]: boolean }, -- keys due in that first pass (a retry keeps the label)
	waitUntil: { [string]: number }, -- the retry list: key -> os.clock() of the next try
	retryDelay: { [string]: number },
}

local states: { [Player]: State } = {}

-- Every made badge's id, in Badges.LIST order.
local function madeIds(): { number }
	local ids: { number } = {}
	for _, badge in Badges.LIST do
		local id = Badges.id(badge.key)
		if id ~= 0 then
			table.insert(ids, id)
		end
	end
	return ids
end

-- The made badges the player owns, or nil when Roblox could not say.
local function lookup(player: Player): { [number]: boolean }?
	local ids = madeIds()
	local owned: { [number]: boolean } = {}
	for first = 1, #ids, LOOKUP_BATCH do
		local batch = table.move(ids, first, math.min(first + LOOKUP_BATCH - 1, #ids), 1, {})
		local ok, result = pcall(function()
			return BadgeService:CheckUserBadgesAsync(player.UserId, batch)
		end)
		if not ok or type(result) ~= "table" then
			warn(
				"[BadgeAwardService] badge lookup failed, trying again later: " .. tostring(result)
			)
			return nil
		end
		for _, id in result do
			if type(id) == "number" then
				owned[id] = true
			end
		end
	end
	return owned
end

local function award(player: Player, state: State, key: string)
	local id = Badges.id(key)
	local ok, result = pcall(function()
		return BadgeService:AwardBadgeAsync(player.UserId, id)
	end)
	if states[player] ~= state then
		return -- left meanwhile
	end
	if ok and result == true then
		state.owned[id] = true
		state.waitUntil[key] = nil
		state.retryDelay[key] = nil
		local profile = DataService.get(player)
		if profile ~= nil then
			local minutes = math.floor(PlayTime.seconds(player, profile) / 60)
			Telemetry.custom(
				player,
				"badge_awarded",
				minutes,
				{ key, if state.catchup[key] then "catchup" else "live" }
			)
		end
		return
	end
	local delay = state.retryDelay[key]
	if delay == nil then
		delay = RETRY_SECONDS
		warn(`[BadgeAwardService] award of {key} failed, on the retry list: {tostring(result)}`)
	end
	state.waitUntil[key] = os.clock() + delay
	state.retryDelay[key] = math.min(delay * 2, RETRY_MAX_SECONDS)
end

-- #3324: whether the owner's account is in this server now.
local function ownerHere(): boolean
	for _, other in Players:GetPlayers() do
		if ChatTags.isOwner(other.UserId) then
			return true
		end
	end
	return false
end

local function check(player: Player, owner: boolean)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	local state: State
	local known = states[player]
	if known ~= nil then
		state = known
	else
		state = {
			owned = {},
			ready = false,
			lookupAt = 0,
			busy = false,
			caughtUp = false,
			catchup = {},
			waitUntil = {},
			retryDelay = {},
		}
		states[player] = state
	end
	if state.busy then
		return
	end
	local now = os.clock()
	if not state.ready then
		if now < state.lookupAt then
			return
		end
		state.busy = true
		task.spawn(function()
			local found = lookup(player)
			if found == nil then
				state.lookupAt = os.clock() + LOOKUP_RETRY_SECONDS
			else
				state.owned = found
				state.ready = true
			end
			state.busy = false
		end)
		return
	end
	local extra = if owner and not ChatTags.isOwner(player.UserId) then { metOwner = true } else nil
	local due = Badges.due(profile, state.owned, state.waitUntil, now, extra)
	if not state.caughtUp then
		state.caughtUp = true
		for _, key in due do
			state.catchup[key] = true
		end
	end
	if #due == 0 then
		return
	end
	state.busy = true
	task.spawn(function()
		for _, key in due do
			if states[player] ~= state then
				return
			end
			award(player, state, key)
		end
		state.busy = false
	end)
end

function BadgeAwardService.start()
	Players.PlayerRemoving:Connect(function(player: Player)
		states[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			local owner = ownerHere()
			for _, player in DataService.loadedPlayers() do
				local ok, err = pcall(function()
					check(player, owner)
				end)
				if not ok then
					warn("[BadgeAwardService] " .. tostring(err))
				end
			end
		end
	end)
end

return BadgeAwardService
