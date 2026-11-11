--!strict
-- The Cat Arcade's leaderboard (#3338, Derek2 2026-11-11: the arcade was "missing the leaderboard button"). Each
-- player's best (Arcade.score of their save's best and bestCircles) goes to the OrderedDataStore Arcade.BOARD_STORE,
-- keyed by user id, when their arcade save is read and after a game that beats it, and only when it changed since
-- this server last wrote it. Never in Studio or with Config.LeaderboardWrites off, as the other boards
-- (LeaderboardService). Every Config.LeaderboardRefreshSeconds the top Arcade.TOP x 2 are read, names looked up in
-- batches and cached for the server's life; the players in this server are put in at their bests now
-- (Leaderboards.withPresent), so the board is right between reads and in Studio. Owner accounts
-- (Config.OwnerTestUserIds, #3321) are never written and never shown. ArcadeService sends the board in ArcadeState.
-- Every value comes from the server's own arcade saves; a client never sends one. Nothing here prints an id or name.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserService = game:GetService("UserService")

local Arcade = require(ReplicatedStorage.Shared.Arcade)
local Config = require(ReplicatedStorage.Shared.Config)
local Leaderboards = require(ReplicatedStorage.Shared.Leaderboards)
local Types = require(ReplicatedStorage.Shared.Types)

local ArcadeBoard = {}

local READ_COUNT = Arcade.TOP * 2 -- owners and unknown keys dropped still leave TOP
local NAME_BATCH = 100

local read: { Types.LeaderboardRow } = {} -- as last read from the store
local written: { [number]: number } = {} -- user id -> the score this server last wrote
local names: { [number]: string } = {}

local function owners(): { [number]: boolean }
	local out: { [number]: boolean } = {}
	for _, id in Config.OwnerTestUserIds do
		out[id] = true
	end
	return out
end

local function canWrite(): boolean
	return Config.LeaderboardWrites and not RunService:IsStudio()
end

-- Writes `player`'s best when it changed since this server last wrote it. Yields, so callers spawn it.
local function write(userId: number, value: number)
	local ok = pcall(function()
		DataStoreService:GetOrderedDataStore(Arcade.BOARD_STORE):SetAsync(tostring(userId), value)
	end)
	if ok then
		written[userId] = value
	else
		warn("[ArcadeBoard] a write failed; it is tried again after the next game")
	end
end

-- After the arcade save is read and after each game: puts the player's best on the board.
function ArcadeBoard.note(player: Player, best: number, bestCircles: number)
	local userId = player.UserId
	if best <= 0 or owners()[userId] or not canWrite() then
		return
	end
	local value = Arcade.score(best, bestCircles)
	if written[userId] == value then
		return
	end
	task.spawn(write, userId, value)
end

local function lookUpNames(ids: { number })
	local missing: { number } = {}
	for _, id in ids do
		if names[id] == nil then
			local here = Players:GetPlayerByUserId(id)
			if here ~= nil then
				names[id] = here.DisplayName
			else
				table.insert(missing, id)
			end
		end
	end
	for from = 1, #missing, NAME_BATCH do
		local batch = table.move(missing, from, math.min(from + NAME_BATCH - 1, #missing), 1, {})
		local ok, infos = pcall(function()
			return UserService:GetUserInfosByUserIdsAsync(batch)
		end)
		if ok and type(infos) == "table" then
			for _, info in infos :: { any } do
				if
					type(info) == "table"
					and type(info.Id) == "number"
					and type(info.DisplayName) == "string"
				then
					names[info.Id] = info.DisplayName
				end
			end
		end
	end
end

local function nameOf(userId: number): string
	return names[userId] or "Player"
end

-- One read of the store's top; a failed read keeps the last one.
local function refresh()
	local ok, entries = pcall(function()
		local pages = DataStoreService:GetOrderedDataStore(Arcade.BOARD_STORE)
			:GetSortedAsync(false, READ_COUNT)
		return pages:GetCurrentPage()
	end)
	if not ok or type(entries) ~= "table" then
		return
	end
	local ids: { number } = {}
	for _, entry in entries :: { any } do
		local id = if type(entry) == "table" then tonumber(entry.key) else nil
		if id ~= nil then
			table.insert(ids, id)
		end
	end
	lookUpNames(ids)
	read = Leaderboards.rows(entries :: { any }, owners(), nameOf)
end

-- The board for `viewer`: as last read, with `present` (the players in this server with an arcade best, as
-- { userId, name, value = Arcade.score }) put in at their bests now, owners left out.
function ArcadeBoard.top(present: { Leaderboards.Present }, viewer: number?): { Arcade.Row }
	return Arcade.topRows(Leaderboards.withPresent(read, present, owners()), viewer)
end

-- Starts the read loop; `refreshed` runs after each read (ArcadeService sends everyone their window's state).
function ArcadeBoard.start(refreshed: () -> ())
	Players.PlayerRemoving:Connect(function(player: Player)
		local userId = player.UserId
		task.delay(30, function()
			if Players:GetPlayerByUserId(userId) == nil then
				written[userId] = nil
			end
		end)
	end)
	task.spawn(function()
		while true do
			refresh()
			refreshed()
			task.wait(Config.LeaderboardRefreshSeconds)
		end
	end)
end

return ArcadeBoard
