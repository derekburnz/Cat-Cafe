--!strict
-- Leaderboards (F98, leaderboards.md). Pure: what each board ranks, as the whole numbers the OrderedDataStores keep,
-- and the store names. LeaderboardService writes and reads them; the boards in town and the Index's Top tab show
-- LeaderboardSync.
--   index     Index entries found: every normal cat in the collection plus every gold and rainbow coat, exclusive
--             cats left out
--             as in the Index itself. All time.
--   playtime  minutes played (stats.playtimeSeconds plus the session so far). All time, and this week (stats.weekPlay
--             plus the session's time since the week began).
--   money     the best money per second the cafe has reached (stats.bestRate): its rate with cats, decor, tier,
--             passes and the pal bonus, never timed potions, Lucky Days or the night pause. All time, and this week
--             (stats.weekBestRate). Clamped to LeaderboardRateMax.
-- A week starts on Monday at 00:00 UTC, the weekly quests' week (Quests.week).

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Economy = require(script.Parent.Economy)
local Quests = require(script.Parent.Quests)
local Types = require(script.Parent.Types)

local Leaderboards = {}

-- A board: "index", "playtime" or "money" (BOARDS). Plain strings, since the type solver will not narrow a frozen
-- list of literals to singleton types.
export type Board = string
-- One list a server reads, a board all time or this week: the boards plus "playtime_week" and "money_week" (LISTS).
export type List = string

Leaderboards.BOARDS = table.freeze({ "index", "playtime", "money" }) :: { Board }
Leaderboards.LISTS =
	table.freeze({ "index", "playtime", "money", "playtime_week", "money_week" }) :: { List }

local WEEK_SECONDS = 604800
local STORE_NAMES: { [Board]: string } = {
	index = "CatCafe_LB_Index",
	playtime = "CatCafe_LB_Playtime",
	money = "CatCafe_LB_Money",
}

-- The board a list belongs to and whether it is the weekly one.
function Leaderboards.boardOf(list: List): (Board, boolean)
	if list == "playtime_week" then
		return "playtime", true
	elseif list == "money_week" then
		return "money", true
	end
	return list :: Board, false
end

-- The OrderedDataStore a list lives in: CatCafe_LB_<Board>, and for this week's lists CatCafe_LB_<Board>_W<week>.
function Leaderboards.storeName(list: List, week: number): string
	local board, weekly = Leaderboards.boardOf(list)
	local name = STORE_NAMES[board]
	return if weekly then string.format("%s_W%d", name, week) else name
end

function Leaderboards.week(now: number): number
	return Quests.week(now)
end

-- os.time() the week holding `now` began.
function Leaderboards.weekStartsAt(now: number): number
	return Quests.weekEndsAt(now) - WEEK_SECONDS
end

-- Index entries found: the collection's cats, the gold coats and the rainbow coats (F99), not counting exclusive cats.
function Leaderboards.indexEntries(profile: Types.PlayerProfile): number
	local n = 0
	for _, found in { profile.collection, profile.goldCollection, profile.rainbowCollection or {} } do
		for catId in found do
			local def = Catalog.getCat(catId)
			if def ~= nil and def.exclusive ~= true then
				n += 1
			end
		end
	end
	return n
end

-- The rate the Money board ranks now: the cafe's rate with the pal bonus, without potions (incomePerSecond never
-- has them) or the night pause.
function Leaderboards.moneyRate(profile: Types.PlayerProfile): number
	return Economy.incomePerSecond(profile) * (1 + Economy.palBonus(profile))
end

-- Raises stats.bestRate and this week's stats.weekBestRate to `rate` when it is higher. Called on every cafe sync.
function Leaderboards.noteRate(profile: Types.PlayerProfile, rate: number, now: number)
	if rate ~= rate or rate <= 0 then
		return
	end
	local stats = profile.stats
	if rate > stats.bestRate then
		stats.bestRate = rate
	end
	local week = Leaderboards.week(now)
	if stats.weekBestRate.week ~= week then
		stats.weekBestRate = { week = week, rate = rate }
	elseif rate > stats.weekBestRate.rate then
		stats.weekBestRate.rate = rate
	end
end

-- Seconds of a session that started at `joinedAt` played in the week holding `now`.
function Leaderboards.sessionInWeek(joinedAt: number, now: number): number
	return math.max(0, now - math.max(joinedAt, Leaderboards.weekStartsAt(now)))
end

-- At a session's end (DataService): folds its time this week into stats.weekPlay, starting the week over when the
-- saved one is older.
function Leaderboards.foldWeekPlay(profile: Types.PlayerProfile, joinedAt: number, now: number)
	local week = Leaderboards.week(now)
	local played = Leaderboards.sessionInWeek(joinedAt, now)
	local saved = profile.stats.weekPlay
	if saved.week ~= week then
		profile.stats.weekPlay = { week = week, seconds = played }
	else
		saved.seconds += played
	end
end

local function whole(value: number, max: number?): number
	if value ~= value or value <= 0 then
		return 0
	end
	return math.floor(math.min(value, max or math.huge))
end

-- What each list holds for this profile now, as whole numbers: entries, minutes played, money per second.
-- `joinedAt` is the session's start (os.time()), whose time stats.playtimeSeconds and weekPlay do not have yet.
function Leaderboards.values(
	profile: Types.PlayerProfile,
	joinedAt: number,
	now: number
): { [List]: number }
	local stats = profile.stats
	local week = Leaderboards.week(now)
	local session = math.max(0, now - joinedAt)
	local weekPlay = (if stats.weekPlay.week == week then stats.weekPlay.seconds else 0)
		+ Leaderboards.sessionInWeek(joinedAt, now)
	local weekRate = if stats.weekBestRate.week == week then stats.weekBestRate.rate else 0
	return {
		index = Leaderboards.indexEntries(profile),
		playtime = whole((stats.playtimeSeconds + session) / 60),
		money = whole(stats.bestRate, Config.LeaderboardRateMax),
		playtime_week = whole(weekPlay / 60),
		money_week = whole(weekRate, Config.LeaderboardRateMax),
	}
end

-- A list's rank for `userId` (1 is the top), or nil when they are not on it.
function Leaderboards.rankOf(rows: { Types.LeaderboardRow }, userId: number): number?
	for _, row in rows do
		if row.userId == userId then
			return row.rank
		end
	end
	return nil
end

-- Whether `userId` is in the top LeaderboardCrownRank of any all-time board.
function Leaderboards.crowned(lists: { [List]: { Types.LeaderboardRow } }, userId: number): boolean
	for _, board in Leaderboards.BOARDS do
		local rank = Leaderboards.rankOf(lists[board] or {}, userId)
		if rank ~= nil and rank <= Config.LeaderboardCrownRank then
			return true
		end
	end
	return false
end

-- Store entries ({ key, value } from GetSortedAsync, best first) as ranked rows: keys that are not a user id, hidden
-- players and anything past LeaderboardSize are dropped, and the ranks close up over them. `nameOf` gives each
-- user's display name.
function Leaderboards.rows(
	entries: { any },
	hidden: { [number]: boolean },
	nameOf: (number) -> string
): { Types.LeaderboardRow }
	local rows: { Types.LeaderboardRow } = {}
	for _, entry in entries do
		if #rows >= Config.LeaderboardSize then
			break
		end
		local userId = if type(entry) == "table" then tonumber(entry.key) else nil
		local value = if type(entry) == "table" then entry.value else nil
		if
			userId == nil
			or userId <= 0
			or userId % 1 ~= 0
			or hidden[userId] == true
			or type(value) ~= "number"
		then
			continue
		end
		table.insert(rows, {
			rank = #rows + 1,
			userId = userId,
			name = nameOf(userId),
			value = value,
			crown = false,
		})
	end
	return rows
end

return Leaderboards
