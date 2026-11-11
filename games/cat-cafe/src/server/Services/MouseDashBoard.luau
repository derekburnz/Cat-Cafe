--!strict
-- Mouse Dash's leaderboard (#3296, mouse-dash.md section 3), built as the Cat Arcade's (ArcadeBoard, #3338) on its
-- own OrderedDataStore, MouseDash.BOARD_STORE: each player's best (MouseDash.score of their best and bestSeconds),
-- keyed by user id, written when their save is read and after a game that beats it, and only when it changed since
-- this server last wrote it. Never in Studio or with Config.LeaderboardWrites off. Every
-- Config.LeaderboardRefreshSeconds the top MouseDash.TOP x 2 are read and names looked up; the players in this
-- server are put in at their bests now. Owner accounts (#3321) and the main boards' hide list are never written or
-- shown. A copy of ArcadeBoard on purpose: Circle Streak's board is due to freeze into a Hall of Fame page if Mouse
-- Dash takes over (spec section 8), so the two are kept apart.
-- Every value comes from the server's own saves; a client never sends one. Nothing here prints an id or name.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserService = game:GetService("UserService")

local Config = require(ReplicatedStorage.Shared.Config)
local Leaderboards = require(ReplicatedStorage.Shared.Leaderboards)
local MouseDash = require(ReplicatedStorage.Shared.MouseDash)
local Types = require(ReplicatedStorage.Shared.Types)

local MouseDashBoard = {}

local READ_COUNT = MouseDash.TOP * 2 -- owners, hidden players and unknown keys dropped still leave TOP
local NAME_BATCH = 100
-- the main boards' moderation hide list (LeaderboardService's HIDDEN_STORE and HIDDEN_KEY), read here too so a player
-- hidden there is hidden on the arcade's board (Review-Agent on #3352)
local HIDDEN_STORE = "CatCafe_LB"
local HIDDEN_KEY = "CatCafe_LB_Hidden"

local read: { Types.LeaderboardRow } = {} -- as last read from the store
local written: { [number]: number } = {} -- user id -> the score this server last wrote
local names: { [number]: string } = {}
local hiddenIds: { [number]: boolean } = {} -- the hide list as last read; a failed read keeps the last one

-- Who never shows: the owner accounts (#3321) and the main boards' hide list.
local function hidden(): { [number]: boolean }
	local out: { [number]: boolean } = table.clone(hiddenIds)
	for _, id in Config.OwnerTestUserIds do
		out[id] = true
	end
	return out
end

local function readHidden()
	local ok, value = pcall(function()
		return DataStoreService:GetDataStore(HIDDEN_STORE):GetAsync(HIDDEN_KEY)
	end)
	if not ok then
		return
	end
	local fresh: { [number]: boolean } = {}
	if type(value) == "table" then
		for _, id in value :: { any } do
			if type(id) == "number" then
				fresh[id] = true
			end
		end
	end
	hiddenIds = fresh
end

local function canWrite(): boolean
	return Config.LeaderboardWrites and not RunService:IsStudio()
end

-- Writes `player`'s best when it changed since this server last wrote it. Yields, so callers spawn it.
local function write(userId: number, value: number)
	local ok = pcall(function()
		DataStoreService:GetOrderedDataStore(MouseDash.BOARD_STORE)
			:SetAsync(tostring(userId), value)
	end)
	if ok then
		written[userId] = value
	else
		warn("[MouseDashBoard] a write failed; it is tried again after the next game")
	end
end

-- After the Mouse Dash save is read and after each game: puts the player's best on the board.
function MouseDashBoard.note(player: Player, best: number, bestSeconds: number)
	local userId = player.UserId
	if best <= 0 or hidden()[userId] or not canWrite() then
		return
	end
	local value = MouseDash.score(best, bestSeconds)
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
	readHidden()
	local ok, entries = pcall(function()
		local pages = DataStoreService:GetOrderedDataStore(MouseDash.BOARD_STORE)
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
	read = Leaderboards.rows(entries :: { any }, hidden(), nameOf)
end

-- The board for `viewer`: as last read, with `present` (the players in this server with a Mouse Dash best, as
-- { userId, name, value = MouseDash.score }) put in at their bests now, owners and hidden players left out.
function MouseDashBoard.top(present: { Leaderboards.Present }, viewer: number?): { MouseDash.Row }
	return MouseDash.topRows(Leaderboards.withPresent(read, present, hidden()), viewer)
end

-- Starts the read loop; `refreshed` runs after each read (MouseDashService sends everyone their window's state).
function MouseDashBoard.start(refreshed: () -> ())
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

return MouseDashBoard
