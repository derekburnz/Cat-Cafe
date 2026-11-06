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

local CafeService = require(script.Parent.CafeService)
local DataService = require(script.Parent.DataService)
local Guard = require(script.Parent.Parent.Util.Guard)
local IdeaCredits = require(ReplicatedStorage.Shared.IdeaCredits)
local Net = require(script.Parent.Net)
local Products = require(ReplicatedStorage.Shared.Products)
local Types = require(ReplicatedStorage.Shared.Types)

local IdeaCreditsService = {}

local NAME_BATCH = 100 -- user ids per GetUserInfosByUserIdsAsync call
local KEY_PAGE = 100
local SCAN_KEYS = 2000 -- the most key names one rebuild lists under a prefix (20 list requests)
local MIRROR_SECONDS = 30 -- the most often one player's hide/<userId> key is written

local credits: { IdeaCredits.Credit } = {}
local names: { [number]: string } = {}
local hidden: { [number]: boolean } = {}
local supporters: { [number]: boolean } = {} -- #1168 row 4: Thank You Badge buyers (SUPPORTER_PREFIX keys and players here)
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

-- The newest `limit` credits' stored values. The lead's idea-credits.yml names each key
-- credit/<10 digits of 9999999999 - addedAt>-<report key>, so with the time inverted a DataStore's ascending listing
-- gives the newest first: only the first `limit` names are listed and read.
local function newestCredits(limit: number): { unknown }
	local names = keyNames(IdeaCredits.CREDIT_PREFIX, limit)
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
	rows = IdeaCredits.rows(credits, names, hidden, supporters)
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
	local backers: { [number]: boolean } = {}
	for _, key in keyNames(IdeaCredits.SUPPORTER_PREFIX, SCAN_KEYS) do
		local userId = tonumber(string.sub(key, #IdeaCredits.SUPPORTER_PREFIX + 1))
		if userId ~= nil then
			backers[userId] = true
		end
	end
	-- a player here who keeps their name off counts even if their hide key failed to save, and a supporter here
	-- counts even if their supporter key did
	for _, player in Players:GetPlayers() do
		local profile = DataService.get(player)
		if profile ~= nil and profile.hideCredit == true then
			hide[player.UserId] = true
		end
		if profile ~= nil and Products.isSupporter(profile) then
			backers[player.UserId] = true
		end
	end
	credits, hidden, supporters, names = fresh, hide, backers, lookUp(ids)
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

-- #1168 row 4: notes a Thank You Badge buyer for the board (a supporter/<userId> key, written once, so the heart
-- shows by their name while they are in no server) and marks them on their Player for any client view. Called at a
-- supporter's join and on the purchase.
function IdeaCreditsService.markSupporter(player: Player, profile: Types.PlayerProfile)
	if not Products.isSupporter(profile) then
		return
	end
	player:SetAttribute(Products.SUPPORTER_ATTRIBUTE, true)
	local userId = player.UserId
	if supporters[userId] then
		return
	end
	supporters[userId] = true
	task.spawn(function()
		local ok, err = pcall(function()
			store():SetAsync(IdeaCredits.SUPPORTER_PREFIX .. tostring(userId), true, { userId })
		end)
		if not ok then
			warn("[IdeaCredits] supporter save failed: " .. tostring(err))
		end
	end)
	buildRows()
	sendAll()
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
	CafeService.sync(player) -- the Settings row reads hideCredit from ProfileSync
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
		IdeaCreditsService.markSupporter(player, profile) -- #1168 row 4: a new supporter here resends the board
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
