--!strict
-- Leaderboards (F98, leaderboards.md section 4; shared/Leaderboards for the values and store names).
--   Writes: each player's five values (Index entries, minutes played all time and this week, best money per second
--     all time and this week) go to one OrderedDataStore per list, keyed by user id, on join, every
--     LeaderboardWriteSeconds, on a rank up and on leave, each only when it changed since this server last wrote it.
--     Never in Studio or with Config.LeaderboardWrites off, so playtests never land on the live boards.
--   Reads: every LeaderboardRefreshSeconds the top LeaderboardSize of every list, spread across the period, names
--     from UserService in batches (cached for the server's life), the hidden list (DataStore key
--     CatCafe_LB_Hidden) dropped. Then every player gets LeaderboardSync with their own line, and the crowns are set:
--     attribute Crown on the Player and on their cafe's name sign while they are in the top LeaderboardCrownRank of
--     any all-time board.
-- Every value comes from the server's own profile and clock; a client never sends one. Nothing here prints a user id
-- or a name, since the CI logs are public.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserService = game:GetService("UserService")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Leaderboards = require(ReplicatedStorage.Shared.Leaderboards)
local Net = require(script.Parent.Net)
local PlotService = require(script.Parent.PlotService)
local Types = require(ReplicatedStorage.Shared.Types)

local LeaderboardService = {}

local HIDDEN_STORE = "CatCafe_LB"
local HIDDEN_KEY = "CatCafe_LB_Hidden"
local NAME_BATCH = 100 -- ids per GetUserInfosByUserIdsAsync call (its limit is 200)

type List = Leaderboards.List
type Row = Types.LeaderboardRow

local written: { [Player]: { [string]: number } } = {} -- store name -> the value this server last wrote
local lists: { [List]: { Row } } = {}
local listWeek = 0 -- the week the weekly lists were read for
local names: { [number]: string } = {}
local hidden: { [number]: boolean } = {}
local crowned: { [number]: boolean } = {}

-- A list as last read, or no rows before its first read.
local function listOf(list: List): { Row }
	local rows = lists[list]
	if rows == nil then
		return {}
	end
	return rows
end

local function canWrite(): boolean
	return Config.LeaderboardWrites and not RunService:IsStudio()
end

local function valuesOf(
	player: Player,
	profile: Types.PlayerProfile,
	now: number
): { [List]: number }
	return Leaderboards.values(profile, DataService.joinedAt(player) or now, now)
end

-- Writes the lists whose value changed since this server last wrote them. Yields; `values` taken by the caller so a
-- leave can write after the profile is gone.
local function writeValues(player: Player, values: { [List]: number }, week: number)
	local mine = written[player] or {}
	written[player] = mine
	for list, value in values do
		local name = Leaderboards.storeName(list, week)
		-- review N321: nothing on a list yet (a first join, under a minute played) is no entry, not a write of 0
		if value <= 0 or mine[name] == value then
			continue
		end
		local ok = pcall(function()
			DataStoreService:GetOrderedDataStore(name):SetAsync(tostring(player.UserId), value)
		end)
		if ok then
			mine[name] = value
		else
			warn("[LeaderboardService] a write failed; it is tried again next time")
		end
	end
end

-- The player's own line on each board: their rank on the list read (nil off it) and their value now.
local function meOf(player: Player): { [string]: any }
	local profile = DataService.get(player)
	local me: { [string]: any } = {}
	if profile == nil then
		return me
	end
	local values = valuesOf(player, profile, os.time())
	for _, board in Leaderboards.BOARDS do
		local line: { [string]: any } = {
			rank = Leaderboards.rankOf(listOf(board), player.UserId),
			value = values[board],
		}
		local weekly = (board .. "_week") :: List
		if values[weekly] ~= nil then
			line.weekRank = Leaderboards.rankOf(listOf(weekly), player.UserId)
			line.weekValue = values[weekly]
		end
		me[board] = line
	end
	return me
end

local function syncOf(player: Player): Types.LeaderboardSync
	local boards: { [string]: { allTime: { Row }, week: { Row }? } } = {}
	for _, board in Leaderboards.BOARDS do
		local week: { Row }? = nil
		if board ~= "index" then
			week = listOf((board .. "_week") :: List)
		end
		boards[board] = { allTime = listOf(board), week = week }
	end
	return { boards = boards, me = meOf(player) :: any, week = listWeek }
end

local function send(player: Player)
	if DataService.get(player) ~= nil then
		Net.fire(player, "LeaderboardSync", syncOf(player))
	end
end

-- Writes the player's values now (join, the timer, a rank up) and sends them their own line.
local function writeNow(player: Player)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	if canWrite() then
		local now = os.time()
		writeValues(player, valuesOf(player, profile, now), Leaderboards.week(now))
	end
	send(player)
end

-- Display names for ids not cached yet, in batches; a failed lookup leaves them to the next refresh.
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

local function readHidden()
	local ok, value = pcall(function()
		return DataStoreService:GetDataStore(HIDDEN_STORE):GetAsync(HIDDEN_KEY)
	end)
	if not ok then
		return -- keep the last list
	end
	local fresh: { [number]: boolean } = {}
	if type(value) == "table" then
		for _, id in value :: { any } do
			if type(id) == "number" then
				fresh[id] = true
			end
		end
	end
	hidden = fresh
end

-- Reads one list's top LeaderboardSize; a failed read keeps the last one.
local function readList(list: List, week: number)
	local ok, entries = pcall(function()
		local pages = DataStoreService:GetOrderedDataStore(Leaderboards.storeName(list, week))
			:GetSortedAsync(false, Config.LeaderboardSize)
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
	lists[list] = Leaderboards.rows(entries :: { any }, hidden, nameOf)
end

-- Crown on the player and on their cafe's name sign, from the last refresh's lists.
local function wearCrown(player: Player)
	local wears = crowned[player.UserId] == true
	player:SetAttribute("Crown", wears)
	local plot = PlotService.get(player)
	local sign = if plot ~= nil then plot.sign:FindFirstAncestorWhichIsA("BasePart") else nil
	if sign ~= nil then
		sign:SetAttribute("Crown", wears)
	end
end

-- The crown on every row and every player here: top LeaderboardCrownRank of any all-time board.
local function crown()
	local fresh: { [number]: boolean } = {}
	for _, board in Leaderboards.BOARDS do
		for _, row in listOf(board) do
			if row.rank <= Config.LeaderboardCrownRank then
				fresh[row.userId] = true
			end
		end
	end
	crowned = fresh
	for _, list in Leaderboards.LISTS do
		for _, row in listOf(list) do
			row.crown = crowned[row.userId] == true
		end
	end
	for _, player in Players:GetPlayers() do
		wearCrown(player)
	end
end

-- One refresh: the hidden list, then each list a step apart across LeaderboardRefreshSeconds, then everyone's sync.
local function refresh()
	readHidden()
	local week = Leaderboards.week(os.time())
	local step = Config.LeaderboardRefreshSeconds / (#Leaderboards.LISTS + 1)
	if week ~= listWeek then
		-- a new week: last week's lists are not this week's
		lists.playtime_week = {}
		lists.money_week = {}
	end
	for _, list in Leaderboards.LISTS do
		readList(list, week)
		task.wait(step)
	end
	listWeek = week
	crown()
	for _, player in Players:GetPlayers() do
		send(player)
	end
end

-- Studio only (Debug.leaderboardHide): adds a user id to the hidden list, or takes it off with `show`. Writes the
-- live DataStore when Studio has API access. Returns the list's size.
function LeaderboardService.debugHide(userId: number, show: boolean?): number
	assert(RunService:IsStudio(), "debugHide is Studio only")
	local count = 0
	DataStoreService:GetDataStore(HIDDEN_STORE):UpdateAsync(HIDDEN_KEY, function(old: any)
		local ids: { number } = {}
		if type(old) == "table" then
			for _, id in old :: { any } do
				if type(id) == "number" and id ~= userId then
					table.insert(ids, id)
				end
			end
		end
		if not show then
			table.insert(ids, userId)
		end
		count = #ids
		return ids
	end)
	readHidden()
	return count
end

-- A rank up writes at once (section 4).
function LeaderboardService.rankedUp(player: Player)
	task.spawn(writeNow, player)
end

function LeaderboardService.start()
	DataService.onLoaded:Connect(function(player: Player)
		wearCrown(player) -- review N322: a top player joining between refreshes wears it at once
		task.spawn(writeNow, player)
	end)
	-- On leave: the values as they stand at the end of the session, written after the profile is gone.
	DataService.beforeRelease(function(player: Player, profile: Types.PlayerProfile)
		if not canWrite() then
			return
		end
		local now = os.time()
		local values = valuesOf(player, profile, now)
		task.spawn(writeValues, player, values, Leaderboards.week(now))
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		task.delay(30, function()
			written[player] = nil -- after the leave's write had its turn
		end)
	end)
	task.spawn(function()
		while true do
			task.wait(Config.LeaderboardWriteSeconds)
			for _, player in DataService.loadedPlayers() do
				task.spawn(writeNow, player)
			end
		end
	end)
	task.spawn(function()
		while true do
			refresh()
			task.wait(Config.LeaderboardRefreshSeconds / (#Leaderboards.LISTS + 1))
		end
	end)
end

return LeaderboardService
