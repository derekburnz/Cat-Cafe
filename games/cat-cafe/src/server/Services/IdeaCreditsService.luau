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
local SCAN_KEYS = 2000 -- the most key names one rebuild lists under a prefix (20 list requests)
local MIRROR_SECONDS = 30 -- the most often one player's hide/<userId> key is written

local credits: { IdeaCredits.Credit } = {}
local names: { [number]: string } = {}
local hidden: { [number]: boolean } = {}
local rows: { IdeaCredits.Row } = {}
local pendingMirror: { [number]: boolean } = {} -- each player's hide choice not yet mirrored to the store
local mirroredAt: { [number]: number } = {} -- os.clock() of each player's last mirror write

local function store(): DataStore
	return DataStoreService:GetDataStore(IdeaCredits.STORE)
end

-- The names of the keys under `prefix`, at most `scan` of them (listing costs one request a page and reads no
-- values). Empty when the store cannot be read (a Studio place with no API access, or an outage), so the board keeps
-- "no ideas yet" rather than failing.
local function keyNames(prefix: string, scan: number): { string }
	local names: { string } = {}
	local ok, err = pcall(function()
		local pages = store():ListKeysAsync(prefix, KEY_PAGE)
		while #names < scan do
			for _, entry in pages:GetCurrentPage() do
				table.insert(names, (entry :: DataStoreKey).KeyName)
			end
			if pages.IsFinished then
				break
			end
			pages:AdvanceToNextPageAsync()
		end
	end)
	if not ok then
		warn("[IdeaCredits] list failed: " .. tostring(err))
	end
	return names
end

-- The newest `limit` credits' stored values. The lead's idea-credits.yml names each key credit/<yyyymmddhhmmss>-<report
-- key> (UTC time first), so the highest key names are the newest; a DataStore lists keys only in ascending order, so
-- the names are sorted here and only the newest are read.
local function newestCredits(limit: number): { unknown }
	local names = keyNames(IdeaCredits.CREDIT_PREFIX, SCAN_KEYS)
	table.sort(names, function(a: string, b: string): boolean
		return a > b
	end)
	local values: { unknown } = {}
	for i = 1, math.min(limit, #names) do
		local ok, value = pcall(function()
			return store():GetAsync(names[i])
		end)
		if ok then
			table.insert(values, value)
		end
	end
	return values
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
	for _, raw in newestCredits(IdeaCredits.MAX_ROWS * 2) do
		local credit = IdeaCredits.sanitize(raw)
		if credit ~= nil then
			table.insert(fresh, credit)
		end
	end
	local hide: { [number]: boolean } = {}
	for _, key in keyNames(IdeaCredits.HIDE_PREFIX, SCAN_KEYS) do
		local userId = tonumber(string.sub(key, #IdeaCredits.HIDE_PREFIX + 1))
		if userId ~= nil then
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

-- The hide/<userId> mirror, written at most once every MIRROR_SECONDS for each player and once more on leave, so a
-- player toggling (or a script firing SetHideCredit at its 1 a second) cannot drain the server's DataStore write
-- budget that profile saves share (review). The profile holds the truth meanwhile, and rebuild() reads it for
-- everyone in the server.
local function writeMirror(userId: number, hide: boolean)
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
end

local function flushMirror(userId: number)
	local wanted = pendingMirror[userId]
	if wanted == nil then
		return
	end
	pendingMirror[userId] = nil
	mirroredAt[userId] = os.clock()
	task.spawn(writeMirror, userId, wanted)
end

local function onSetHideCredit(player: Player, rawHide: unknown)
	local hide = Guard.bool(rawHide)
	local profile = DataService.get(player)
	if hide == nil or profile == nil then
		return
	end
	if (profile.hideCredit == true) == hide then
		return -- nothing changes: no write and no new board
	end
	profile.hideCredit = if hide then true else nil
	local userId = player.UserId
	if hide then
		hidden[userId] = true
	else
		hidden[userId] = nil
	end
	pendingMirror[userId] = hide
	local last = mirroredAt[userId]
	if last == nil or os.clock() - last >= MIRROR_SECONDS then
		flushMirror(userId)
	end
	buildRows()
	sendAll()
end

function IdeaCreditsService.start()
	Net.on("SetHideCredit", onSetHideCredit)
	Players.PlayerRemoving:Connect(function(player: Player)
		flushMirror(player.UserId)
		mirroredAt[player.UserId] = nil
	end)
	-- writes any choice that waited out a player's MIRROR_SECONDS
	task.spawn(function()
		while true do
			task.wait(MIRROR_SECONDS)
			for userId in pendingMirror do
				flushMirror(userId)
			end
		end
	end)
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
