--!strict
-- The leaderboards' rows and words (F98, leaderboards.md), pure. Screens/LeaderboardBoards draws the three boards in
-- town and the Index's Top tab draws the same rows, both from the server's LeaderboardSync:
--   { boards = { [board] = { allTime = { Row }, week = { Row }? } }, me = { [board] = Me }, week = number }
-- where a Row is { rank, userId, name, value, crown } and Me is { rank: number?, value: number } for the all time
-- list (weekRank and weekValue when the server sends them).
--   BOARDS, info(board)                   the three boards in order, with their name, icon and colour
--   hasWeek(board)                        Playtime and Money have a This week list; Index is all time only
--   value(board, value)                   "68 cats", "41 h 12 m", "$12.4K/s"
--   rows(sync, board, window, limit?)     a window's rows, in rank order, at most `limit`
--   meLine(sync, board, window, userId)   "You: #23", "You: 41 h 12 m" or "You: not on this week's list yet"
--   faceWindow(board, now, swap)          which list a board's face shows now: it swaps every `swap` seconds
--   medal(rank)                           "gold", "silver" or "bronze" for the top three
--   headshot(userId)                      the player's head picture

local ShortNumber = require(script.Parent.ShortNumber)

local LeaderboardLogic = {}

export type Board = "index" | "playtime" | "money"
export type Window = "allTime" | "week"
export type Row = { rank: number, userId: number, name: string, value: number, crown: boolean? }
export type Me = { rank: number?, value: number, weekRank: number?, weekValue: number? }
export type Sync = {
	boards: { [string]: { allTime: { Row }?, week: { Row }? } }?,
	me: { [string]: Me }?,
	week: number?,
}
export type Info = { id: Board, name: string, icon: string }
export type Medal = "gold" | "silver" | "bronze"

LeaderboardLogic.BOARDS = { "index", "playtime", "money" } :: { Board }
LeaderboardLogic.CROWN = "👑"
LeaderboardLogic.BOARD_ROWS = 10 -- Config.LeaderboardBoardRows
LeaderboardLogic.SWAP_SECONDS = 15 -- Config.LeaderboardFaceSwapSeconds

local INFO: { [string]: Info } = {
	index = { id = "index", name = "Index", icon = "📖" },
	playtime = { id = "playtime", name = "Playtime", icon = "🕐" },
	money = { id = "money", name = "Money", icon = "💰" },
}

function LeaderboardLogic.info(board: string): Info
	return INFO[board] or INFO.index
end

function LeaderboardLogic.hasWeek(board: string): boolean
	return board == "playtime" or board == "money"
end

-- Index: entries found; Playtime: whole minutes played; Money: the best money per second, rounded down.
function LeaderboardLogic.value(board: string, value: number?): string
	local n = math.max(0, math.floor(if type(value) == "number" then value else 0))
	if board == "playtime" then
		local hours, minutes = n // 60, n % 60
		if hours > 0 then
			return string.format("%d h %d m", hours, minutes)
		end
		return string.format("%d m", minutes)
	elseif board == "money" then
		return "$" .. ShortNumber.format(n) .. "/s"
	end
	return if n == 1 then "1 cat" else ShortNumber.format(n) .. " cats"
end

local function list(sync: Sync?, board: string, window: Window): { Row }
	local boards = if sync ~= nil then sync.boards else nil
	local entry = if type(boards) == "table" then boards[board] else nil
	if type(entry) ~= "table" then
		return {}
	end
	local rows = if window == "week" then entry.week else entry.allTime
	return if type(rows) == "table" then rows else {}
end

function LeaderboardLogic.rows(sync: Sync?, board: string, window: Window, limit: number?): { Row }
	local out: { Row } = {}
	for _, row in list(sync, board, window) do
		if type(row) == "table" and type(row.rank) == "number" and type(row.userId) == "number" then
			table.insert(out, row)
		end
	end
	table.sort(out, function(a: Row, b: Row): boolean
		return a.rank < b.rank
	end)
	if limit ~= nil then
		for index = #out, limit + 1, -1 do
			out[index] = nil
		end
	end
	return out
end

function LeaderboardLogic.meLine(
	sync: Sync?,
	board: string,
	window: Window,
	userId: number
): string?
	local me = if sync ~= nil and type(sync.me) == "table" then sync.me[board] else nil
	if window == "week" then
		for _, row in list(sync, board, "week") do
			if type(row) == "table" and row.userId == userId and type(row.rank) == "number" then
				return ("You: #%d"):format(row.rank)
			end
		end
		if me ~= nil and type(me.weekRank) == "number" then
			return ("You: #%d"):format(me.weekRank)
		elseif me ~= nil and type(me.weekValue) == "number" then
			return "You: " .. LeaderboardLogic.value(board, me.weekValue)
		end
		return "You: not on this week's list yet"
	end
	if me == nil then
		return nil
	end
	if type(me.rank) == "number" then
		return ("You: #%d"):format(me.rank)
	end
	return "You: " .. LeaderboardLogic.value(board, me.value)
end

function LeaderboardLogic.faceWindow(board: string, now: number, swap: number?): Window
	if not LeaderboardLogic.hasWeek(board) then
		return "allTime"
	end
	local every = swap or LeaderboardLogic.SWAP_SECONDS
	return if math.floor(now / every) % 2 == 1 then "week" else "allTime"
end

function LeaderboardLogic.medal(rank: number): Medal?
	if rank == 1 then
		return "gold"
	elseif rank == 2 then
		return "silver"
	elseif rank == 3 then
		return "bronze"
	end
	return nil
end

function LeaderboardLogic.headshot(userId: number): string
	return ("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48"):format(userId)
end

return LeaderboardLogic
