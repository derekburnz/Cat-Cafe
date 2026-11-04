--!strict
-- The Thank You board's credits on the server (#1083, idea-credits.md; the rules are shared/IdeaCredits). The lead's
-- idea-credits.yml writes each credit into the IdeaCredits_v1 DataStore (never the game, and never for a report
-- without the "Feature my name" tick). This reads them at server start and every REFRESH_SECONDS, looks each player's
-- display name up (UserService, never the username) and sends ThanksBoard(rows, hasCredit) to everyone; a joiner gets
-- the last build. SetHideCredit(hide) saves profile.hideCredit and mirrors it to a hide/<userId> key, because the
-- board is built for players who are not in this server too, and rebuilds the rows from what it has at once. Names
-- are never cached past one build, so a name Roblox moderates or a player changes is right on the next one.
--
-- Roblox terms: UserService:GetUserInfosByUserIdsAsync returns each user's current display name; a DataStore's
-- ListKeysAsync pages through its keys by prefix.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService("UserService")

local DataService = require(script.Parent.DataService)
local Guard = require(script.Parent.Parent.Util.Guard)
local IdeaCredits = require(ReplicatedStorage.Shared.IdeaCredits)
local Net = require(script.Parent.Net)
local Types = require(ReplicatedStorage.Shared.Types)

local IdeaCreditsService = {}

local NAME_BATCH = 100 -- user ids per GetUserInfosByUserIdsAsync call
local KEY_PAGE = 100

local credits: { IdeaCredits.Credit } = {}
local names: { [number]: string } = {}
local hidden: { [number]: boolean } = {}
local rows: { IdeaCredits.Row } = {}

local function store(): DataStore
	return DataStoreService:GetDataStore(IdeaCredits.STORE)
end

-- Every key under `prefix`, keyed by the rest of its name, with its value when `values` (else true: a hide key exists
-- only while hidden, so its name is enough and costs no read). Empty when the store cannot be read (a Studio place
-- with no API access, or an outage), so the board keeps "no ideas yet" rather than failing.
local function readAll(prefix: string, limit: number, values: boolean): { [string]: unknown }
	local out: { [string]: unknown } = {}
	local ok, err = pcall(function()
		local pages = store():ListKeysAsync(prefix, KEY_PAGE)
		local count = 0
		while count < limit do
			for _, entry in pages:GetCurrentPage() do
				local key = (entry :: DataStoreKey).KeyName
				out[string.sub(key, #prefix + 1)] = if values then store():GetAsync(key) else true
				count += 1
				if count >= limit then
					break
				end
			end
			if pages.IsFinished or count >= limit then
				break
			end
			pages:AdvanceToNextPageAsync()
		end
	end)
	if not ok then
		warn("[IdeaCredits] read failed: " .. tostring(err))
	end
	return out
end

-- Display names for `userIds`; a user the lookup misses is left out (shown as "a player").
local function lookUp(userIds: { number }): { [number]: string }
	local found: { [number]: string } = {}
	for start = 1, #userIds, NAME_BATCH do
		local batch = table.move(userIds, start, math.min(start + NAME_BATCH - 1, #userIds), 1, {})
		local ok, infos = pcall(function()
			return UserService:GetUserInfosByUserIdsAsync(batch)
		end)
		if ok and type(infos) == "table" then
			for _, info in infos :: { any } do
				if type(info.Id) == "number" and type(info.DisplayName) == "string" then
					found[info.Id] = info.DisplayName
				end
			end
		end
	end
	return found
end

local function send(player: Player)
	Net.fire(player, "ThanksBoard", rows, IdeaCredits.has(credits, player.UserId))
end

local function sendAll()
	for _, player in Players:GetPlayers() do
		send(player)
	end
end

local function buildRows()
	rows = IdeaCredits.rows(credits, names, hidden)
end

-- Reads the credits and hide keys, looks the names up afresh and tells everyone.
local function rebuild()
	local fresh: { IdeaCredits.Credit } = {}
	for _, raw in readAll(IdeaCredits.CREDIT_PREFIX, IdeaCredits.MAX_ROWS * 2, true) do
		local credit = IdeaCredits.sanitize(raw)
		if credit ~= nil then
			table.insert(fresh, credit)
		end
	end
	local hide: { [number]: boolean } = {}
	for key, value in readAll(IdeaCredits.HIDE_PREFIX, 1000, false) do
		local userId = tonumber(key)
		if userId ~= nil and value == true then
			hide[userId] = true
		end
	end
	local ids: { number } = {}
	local seen: { [number]: boolean } = {}
	for _, credit in fresh do
		if not seen[credit.userId] then
			seen[credit.userId] = true
			table.insert(ids, credit.userId)
		end
	end
	-- a player here who keeps their name off counts even if their hide key failed to save
	for _, player in Players:GetPlayers() do
		local profile = DataService.get(player)
		if profile ~= nil and profile.hideCredit == true then
			hide[player.UserId] = true
		end
	end
	credits, hidden, names = fresh, hide, lookUp(ids)
	buildRows()
	sendAll()
end

local function onSetHideCredit(player: Player, rawHide: unknown)
	local hide = Guard.bool(rawHide)
	local profile = DataService.get(player)
	if hide == nil or profile == nil then
		return
	end
	profile.hideCredit = if hide then true else nil
	local userId = player.UserId
	if hide then
		hidden[userId] = true
	else
		hidden[userId] = nil
	end
	task.spawn(function()
		local ok, err = pcall(function()
			local key = IdeaCredits.HIDE_PREFIX .. tostring(userId)
			if hide then
				store():SetAsync(key, true, { userId })
			else
				store():RemoveAsync(key)
			end
		end)
		if not ok then
			warn("[IdeaCredits] hide save failed: " .. tostring(err))
		end
	end)
	buildRows()
	sendAll()
end

function IdeaCreditsService.start()
	Net.on("SetHideCredit", onSetHideCredit)
	DataService.onLoaded:Connect(function(player: Player, profile: Types.PlayerProfile)
		if profile.hideCredit == true and not hidden[player.UserId] then
			hidden[player.UserId] = true
			buildRows()
			sendAll()
		else
			send(player)
		end
	end)
	task.spawn(function()
		while true do
			rebuild()
			task.wait(IdeaCredits.REFRESH_SECONDS)
		end
	end)
end

return IdeaCreditsService
