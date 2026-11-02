--!strict
-- F102 trading (docs/design/cat-cafe/trading.md sections 2 to 4): one server's trade requests and open trades, held in
-- memory and pure (no Roblox service, no yield), so the specs walk every step and TradeService keeps one book a server.
-- TradeService checks who may ask (Trade.askRefusal) and which cat may go on offer (Trade.offerRefusal) against the
-- profiles; the book keeps the order of things:
-- - A request runs TradeRequestSeconds. Declined or run out, the asker waits TradeReaskSeconds before asking that
--   player again. One request out at a time a player.
-- - A trade's version goes up on every add or take away, which also clears both Ready and Confirm, stops the countdown
--   and marks the change (section 3, "any change resets both"). Ready and Confirm carry the version the player saw
--   and are refused for any other, so a press never lands on an offer they have not seen. Ready itself does not move
--   the version, so two Ready presses that cross never refuse each other.
-- - Both Ready: TradeCountdownSeconds, then the confirm screen. A side with a lopsided or gift warning cannot Confirm
--   until its confirmAt, TradeConfirmWaitSeconds on. Both confirmed: TradeService commits ("committing") and nothing on
--   the trade changes after that.
-- Times are the server clock TradeService passes in (Workspace:GetServerTimeNow()), so the countdown and confirmAt
-- read right on the clients.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Trade = require(ReplicatedStorage.Shared.Trade)
local Types = require(ReplicatedStorage.Shared.Types)

local TradeBook = {}

-- Why a Ready or Confirm did not take (TradeService answers each with a fresh TradeState).
TradeBook.STALE = "stale" -- for another version than the one on the table
TradeBook.PHASE = "phase" -- not now: no such trade for this player, or the wrong step
TradeBook.EMPTY = "empty" -- Ready with both offers empty
TradeBook.WAIT = "wait" -- Confirm before confirmAt

-- A press within this many seconds before confirmAt still counts: the client's "Confirm (2)" runs on its own idea of
-- the server clock.
TradeBook.CONFIRM_SLACK = 0.2

export type Phase = "offer" | "countdown" | "confirm" | "committing"

export type Request = { id: string, from: number, to: number, expiresAt: number }

export type Side = {
	userId: number,
	name: string, -- the display name, for the other player's window and the log
	cats: { string }, -- the uids on offer, in the order added
	values: { [string]: number }, -- each one's Collector value (Trade.value)
	ready: boolean,
	confirmed: boolean,
	confirmAt: number, -- when this side's Confirm counts on the confirm screen (0 before it)
}

export type OpenTrade = {
	id: string,
	version: number,
	phase: Phase,
	countdownEndsAt: number?,
	a: Side,
	b: Side,
	changed: { userId: number, uid: string, at: number }?,
}

export type Book = {
	requests: { [string]: Request },
	asking: { [number]: string }, -- the asker's userId -> their request out
	reaskAt: { [string]: number }, -- "from:to" -> when `from` may ask `to` again
	trades: { [string]: OpenTrade },
	tradeOf: { [number]: string }, -- userId -> the trade they are in
	lastSwap: { [number]: number }, -- userId -> when their last trade swapped cats
}

export type Player = { userId: number, name: string }

function TradeBook.new(): Book
	return {
		requests = {},
		asking = {},
		reaskAt = {},
		trades = {},
		tradeOf = {},
		lastSwap = {},
	}
end

local function pairKey(from: number, to: number): string
	return tostring(from) .. ":" .. tostring(to)
end

local function dropRequest(book: Book, request: Request, wait: boolean, now: number)
	book.requests[request.id] = nil
	if book.asking[request.from] == request.id then
		book.asking[request.from] = nil
	end
	if wait then
		book.reaskAt[pairKey(request.from, request.to)] = now + Config.TradeReaskSeconds
	end
end

-- Seconds until `from` may ask `to` again (0 when they may).
function TradeBook.reaskLeft(book: Book, from: number, to: number, now: number): number
	return math.max(0, (book.reaskAt[pairKey(from, to)] or 0) - now)
end

-- Whether `from` has a request out.
function TradeBook.isAsking(book: Book, from: number): boolean
	return book.asking[from] ~= nil
end

-- `from` asks `to` (TradeService has checked Trade.askRefusal).
function TradeBook.ask(book: Book, id: string, from: number, to: number, now: number): Request
	local request: Request = {
		id = id,
		from = from,
		to = to,
		expiresAt = now + Config.TradeRequestSeconds,
	}
	book.requests[id] = request
	book.asking[from] = id
	return request
end

-- The requests that ran out by `now`, taken off the book; each asker waits to ask that player again. Re-ask waits
-- that are over are forgotten here too.
function TradeBook.expire(book: Book, now: number): { Request }
	local gone: { Request } = {}
	for _, request in book.requests do
		if now >= request.expiresAt then
			table.insert(gone, request)
		end
	end
	for _, request in gone do
		dropRequest(book, request, true, now)
	end
	local over: { string } = {}
	for key, at in book.reaskAt do
		if at <= now then
			table.insert(over, key)
		end
	end
	for _, key in over do
		book.reaskAt[key] = nil
	end
	return gone
end

-- `by`'s answer to request `id`: the request when it was theirs to answer and still running, else nil. A decline (or
-- an answer after it ran out) makes the asker wait TradeReaskSeconds; after an accept TradeService checks both players
-- again and opens the trade.
function TradeBook.answer(
	book: Book,
	id: string,
	by: number,
	accept: boolean,
	now: number
): Request?
	local request = book.requests[id]
	if request == nil or request.to ~= by then
		return nil
	end
	if now >= request.expiresAt then
		dropRequest(book, request, true, now)
		return nil
	end
	dropRequest(book, request, not accept, now)
	return request
end

local function newSide(player: Player): Side
	return {
		userId = player.userId,
		name = player.name,
		cats = {},
		values = {},
		ready = false,
		confirmed = false,
		confirmAt = 0,
	}
end

-- Opens trade `id` between `a` and `b`; any requests either has out are answered by it.
function TradeBook.open(book: Book, id: string, a: Player, b: Player, now: number): OpenTrade
	for _, userId in { a.userId, b.userId } do
		local out = book.asking[userId]
		local request = if out ~= nil then book.requests[out] else nil
		if request ~= nil then
			dropRequest(book, request, false, now)
		end
	end
	local trade: OpenTrade = {
		id = id,
		version = 1,
		phase = "offer",
		countdownEndsAt = nil,
		a = newSide(a),
		b = newSide(b),
		changed = nil,
	}
	book.trades[id] = trade
	book.tradeOf[a.userId] = id
	book.tradeOf[b.userId] = id
	return trade
end

function TradeBook.tradeFor(book: Book, userId: number): OpenTrade?
	local id = book.tradeOf[userId]
	return if id ~= nil then book.trades[id] else nil
end

-- `userId`'s side of `trade` and the other one, or nil when they are not in it.
function TradeBook.sides(trade: OpenTrade, userId: number): (Side?, Side?)
	if trade.a.userId == userId then
		return trade.a, trade.b
	elseif trade.b.userId == userId then
		return trade.b, trade.a
	end
	return nil, nil
end

-- Whether `uid` is on offer in the trade `userId` is in (selling, the Collector, locking and resetting wait for it).
function TradeBook.isOffered(book: Book, userId: number, uid: string): boolean
	local trade = TradeBook.tradeFor(book, userId)
	if trade == nil then
		return false
	end
	local mine = TradeBook.sides(trade, userId)
	return mine ~= nil and table.find(mine.cats, uid) ~= nil
end

local function resetBoth(trade: OpenTrade)
	trade.phase = "offer"
	trade.countdownEndsAt = nil
	for _, side in { trade.a, trade.b } do
		side.ready = false
		side.confirmed = false
		side.confirmAt = 0
	end
end

local function changed(trade: OpenTrade, userId: number, uid: string, now: number)
	trade.version += 1
	resetBoth(trade)
	trade.changed = { userId = userId, uid = uid, at = now }
end

-- Puts `uid` (Collector value `value`) on `userId`'s side: false when they are not in the trade, it is committing,
-- the cat is on offer already or the side is full. TradeService checks Trade.offerRefusal first (theirs, unlocked,
-- not exclusive).
function TradeBook.add(
	trade: OpenTrade,
	userId: number,
	uid: string,
	value: number,
	now: number
): boolean
	local mine = TradeBook.sides(trade, userId)
	if
		mine == nil
		or trade.phase == "committing"
		or table.find(mine.cats, uid) ~= nil
		or #mine.cats >= Config.TradeMaxCats
	then
		return false
	end
	table.insert(mine.cats, uid)
	mine.values[uid] = value
	changed(trade, userId, uid, now)
	return true
end

-- Takes `uid` off `userId`'s side: false when it was not there or the trade is committing.
function TradeBook.remove(trade: OpenTrade, userId: number, uid: string, now: number): boolean
	local mine = TradeBook.sides(trade, userId)
	if mine == nil or trade.phase == "committing" then
		return false
	end
	local index = table.find(mine.cats, uid)
	if index == nil then
		return false
	end
	table.remove(mine.cats, index)
	mine.values[uid] = nil
	changed(trade, userId, uid, now)
	return true
end

local function sideValue(side: Side): number
	local total = 0
	for _, uid in side.cats do
		total += side.values[uid] or 0
	end
	return total
end

-- (lopsided, gift) for `userId`'s side: Trade.warnings on the Collector values of what they give and get.
function TradeBook.warnings(trade: OpenTrade, userId: number): (boolean, boolean)
	local mine, theirs = TradeBook.sides(trade, userId)
	if mine == nil or theirs == nil then
		return false, false
	end
	return Trade.warnings(sideValue(mine), sideValue(theirs), #theirs.cats)
end

-- `userId` presses Ready (`ready` true) or takes it back on `version`: nil when it took, else STALE, PHASE or EMPTY.
-- Both Ready starts the countdown; taking Ready back stops it, or leaves the confirm screen for the offers again.
function TradeBook.ready(
	trade: OpenTrade,
	userId: number,
	version: number,
	ready: boolean,
	now: number
): string?
	local mine, theirs = TradeBook.sides(trade, userId)
	if mine == nil or theirs == nil or trade.phase == "committing" then
		return TradeBook.PHASE
	end
	if version ~= trade.version then
		return TradeBook.STALE
	end
	if not ready then
		-- on the offers or the countdown the other side keeps its Ready; back from the confirm screen both press again
		local theirsReady = theirs.ready and trade.phase ~= "confirm"
		resetBoth(trade)
		theirs.ready = theirsReady
		return nil
	end
	if trade.phase ~= "offer" then
		return TradeBook.PHASE -- counting down or confirming: Ready is pressed already
	end
	if #mine.cats == 0 and #theirs.cats == 0 then
		return TradeBook.EMPTY
	end
	mine.ready = true
	if theirs.ready then
		trade.phase = "countdown"
		trade.countdownEndsAt = now + Config.TradeCountdownSeconds
	end
	return nil
end

-- Moves a finished countdown on to the confirm screen: true when it did. A side with a warning (lopsided or gift)
-- gets confirmAt TradeConfirmWaitSeconds on; the other can confirm at once.
function TradeBook.tick(trade: OpenTrade, now: number): boolean
	local endsAt = trade.countdownEndsAt
	if trade.phase ~= "countdown" or endsAt == nil or now < endsAt then
		return false
	end
	trade.phase = "confirm"
	trade.countdownEndsAt = nil
	for _, side in { trade.a, trade.b } do
		local lopsided, gift = TradeBook.warnings(trade, side.userId)
		side.confirmAt = if lopsided or gift then now + Config.TradeConfirmWaitSeconds else now
	end
	return true
end

-- `userId` presses Confirm on `version`: nil when it took, else STALE, PHASE or WAIT.
function TradeBook.confirm(trade: OpenTrade, userId: number, version: number, now: number): string?
	local mine = TradeBook.sides(trade, userId)
	if mine == nil then
		return TradeBook.PHASE
	end
	if version ~= trade.version then
		return TradeBook.STALE
	end
	if trade.phase ~= "confirm" then
		return TradeBook.PHASE
	end
	if now + TradeBook.CONFIRM_SLACK < mine.confirmAt then
		return TradeBook.WAIT
	end
	mine.confirmed = true
	return nil
end

function TradeBook.bothConfirmed(trade: OpenTrade): boolean
	return trade.phase == "confirm" and trade.a.confirmed and trade.b.confirmed
end

-- From here the trade only ends (swapped or failed): no add, take away, Ready or Cancel takes.
function TradeBook.commit(trade: OpenTrade)
	trade.phase = "committing"
end

-- Takes `trade` off the book; `swapped` starts both players' TradeCooldownSeconds.
function TradeBook.close(book: Book, trade: OpenTrade, now: number, swapped: boolean)
	book.trades[trade.id] = nil
	for _, side in { trade.a, trade.b } do
		if book.tradeOf[side.userId] == trade.id then
			book.tradeOf[side.userId] = nil
		end
		if swapped then
			book.lastSwap[side.userId] = now
		end
	end
end

-- Seconds since `userId`'s last swap, math.huge for none on this server.
function TradeBook.sinceLastSwap(book: Book, userId: number, now: number): number
	local at = book.lastSwap[userId]
	return if at ~= nil then now - at else math.huge
end

-- `userId` left: their requests out and in go, and the trade they were in is returned for TradeService to end (it
-- stays on the book until then).
function TradeBook.leave(book: Book, userId: number, now: number): OpenTrade?
	local gone: { Request } = {}
	for _, request in book.requests do
		if request.from == userId or request.to == userId then
			table.insert(gone, request)
		end
	end
	for _, request in gone do
		dropRequest(book, request, false, now)
	end
	book.lastSwap[userId] = nil
	return TradeBook.tradeFor(book, userId)
end

-- TradeState for `userId` (shared Types.TradeStateView), or nil when they are not in `trade`. `tile(ownerId, uid)`
-- is the tile TradeService makes from the owner's profile with rateForMe for this viewer; nil leaves a cat out.
function TradeBook.view(
	trade: OpenTrade,
	userId: number,
	tile: (ownerId: number, uid: string) -> Types.TradeTile?
): Types.TradeStateView?
	local mine, theirs = TradeBook.sides(trade, userId)
	if mine == nil or theirs == nil then
		return nil
	end
	local function show(side: Side): (Types.TradeSide, number)
		local cats: { Types.TradeTile } = {}
		local rate = 0
		for _, uid in side.cats do
			local shown = tile(side.userId, uid)
			if shown ~= nil then
				table.insert(cats, shown)
				rate += shown.rateForMe
			end
		end
		return {
			userId = side.userId,
			name = side.name,
			ready = side.ready,
			confirmed = side.confirmed,
			cats = cats,
		},
			rate
	end
	local me, myRate = show(mine)
	local them, theirRate = show(theirs)
	local lopsided, gift = TradeBook.warnings(trade, userId)
	local change = trade.changed
	local confirming = trade.phase == "confirm" or trade.phase == "committing"
	local phase: string = if trade.phase == "committing" then "confirm" else trade.phase
	local view: Types.TradeStateView = {
		tradeId = trade.id,
		version = trade.version,
		phase = phase,
		countdownEndsAt = trade.countdownEndsAt,
		me = me,
		them = them,
		changed = if change ~= nil
			then {
				side = if change.userId == userId then "me" else "them",
				uid = change.uid,
				at = change.at,
			}
			else nil,
		giveValue = sideValue(mine),
		getValue = sideValue(theirs),
		lopsided = lopsided,
		gift = gift,
		myRateNow = myRate,
		theirRateForMe = theirRate,
		confirmAt = if confirming and mine.confirmAt > 0 then mine.confirmAt else nil,
	}
	return view
end

return TradeBook
