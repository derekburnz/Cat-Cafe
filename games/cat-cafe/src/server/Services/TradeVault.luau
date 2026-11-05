--!strict
-- F102 trading (docs/design/cat-cafe/trading.md section 4): the DataStores that make a trade happen exactly once, even
-- when a server stops in the middle of one. TradeService and the join-time recovery are the only callers.
-- - CatCafe_Trades, one key per trade id: both players, both sides' full cats, and `state`: "pending" when written,
--   then "commit" or "void". `decide` moves pending on with UpdateAsync, so exactly one of the swapping server
--   ("commit") and a recovering server ("void") wins, and a trade decided "commit" is never undone.
-- - CatCafe_TradePending, key p_<userId>: the trade ids that may still owe this player their side. Written before the
--   decision, cleared only after a profile save holds the trade id (TradeService), so a crash between the decision
--   and the saves leaves a pointer for the next join to finish from.
-- - CatCafe_Flags: `trading` (false turns trading off everywhere) and `tradeMinTier` (a live minimum tier), read every
--   TradeFlagCheckSeconds; a missing key keeps the default.
-- Studio playtests use the _dev stores, and without "Enable Studio Access to API Services" (DataService.saves() false)
-- a table in memory, so trading works there and nothing persists. Every call is in pcall with up to TRIES attempts;
-- a failure is warned with the operation's name only (DataStore keys hold user ids, and CI logs are public).
--
-- Roblox terms: a DataStore keeps values by key across servers. UpdateAsync reads and writes one key atomically
-- through a transform function (which must not yield); GetAsync with UseCache false skips the 4 second read cache.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataService = require(script.Parent.DataService)
local Types = require(ReplicatedStorage.Shared.Types)

local TradeVault = {}

TradeVault.TRADES = "CatCafe_Trades"
TradeVault.PENDING = "CatCafe_TradePending"
TradeVault.FLAGS = "CatCafe_Flags"
TradeVault.TRIES = 3
TradeVault.POINTERS_MAX = 20 -- more open pointers than this means something is badly wrong; the oldest go

export type RecordSide = {
	userId: number,
	name: string, -- the display name at the time, for the other player's log
	cats: { Types.CatInstance }, -- the cats this side gives, as they were
	decor: { string }?, -- #1574: the decor and lawn piece ids this side gives (nil in records from before)
}

export type Record = {
	id: string,
	at: number, -- os.time()
	state: string, -- "pending", "commit" or "void"
	a: RecordSide,
	b: RecordSide,
}

export type Flags = { trading: boolean?, tradeMinTier: number? }

local SUFFIX = if RunService:IsStudio() then "_dev" else ""

local memory = {
	trades = {} :: { [string]: any },
	pending = {} :: { [string]: any },
	flags = {} :: { [string]: any },
}

local function live(): boolean
	return not RunService:IsStudio() or DataService.saves()
end

local function copy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, inner in value do
		out[key] = copy(inner)
	end
	return out
end

local function pointerKey(userId: number): string
	return "p_" .. tostring(userId)
end

-- Runs `fn` up to TRIES times; (true, its result) or (false, nil) after warning `what` once.
local function try(what: string, fn: () -> any): (boolean, any)
	local lastError: any = nil
	for attempt = 1, TradeVault.TRIES do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastError = result
		if attempt < TradeVault.TRIES then
			task.wait(0.5 * 2 ^ (attempt - 1))
		end
	end
	-- long digit runs could be a user id in a key, so they are masked
	local text = string.sub(string.gsub(tostring(lastError), "%d%d%d%d%d+", "#"), 1, 120)
	warn(string.format("[TradeVault] %s failed: %s", what, text))
	return false, nil
end

local function store(name: string): DataStore
	return DataStoreService:GetDataStore(name .. SUFFIX)
end

local function fresh(): DataStoreGetOptions
	local options = Instance.new("DataStoreGetOptions")
	options.UseCache = false
	return options
end

local function idList(raw: any): { string }
	local out: { string } = {}
	if type(raw) == "table" then
		for _, id in raw do
			if type(id) == "string" and table.find(out, id) == nil then
				table.insert(out, id)
			end
		end
	end
	while #out > TradeVault.POINTERS_MAX do
		table.remove(out, 1)
	end
	return out
end

-- Writes `record` (state "pending"). True when it is stored.
function TradeVault.write(record: Record): boolean
	if not live() then
		memory.trades[record.id] = copy(record)
		return true
	end
	local ok = try("write", function()
		return store(TradeVault.TRADES):SetAsync(
			record.id,
			record,
			{ record.a.userId, record.b.userId }
		)
	end)
	return ok
end

-- Moves trade `id` from "pending" to `to` ("commit" or "void"); a trade already decided stays as it is. Returns
-- (true, the record as it stands after) or (true, nil) when there is no such trade, and (false, nil) when the
-- DataStore could not be reached, so the caller does not know.
function TradeVault.decide(id: string, to: string): (boolean, Record?)
	if not live() then
		local record = memory.trades[id]
		if record ~= nil and record.state == "pending" then
			record.state = to
		end
		return true, copy(record)
	end
	local seen: any = nil
	local ok = try("decide", function()
		store(TradeVault.TRADES):UpdateAsync(id, function(old: any): any
			seen = old
			if type(old) ~= "table" or old.state ~= "pending" then
				return nil -- nothing written: missing, or decided already
			end
			local decided = copy(old)
			decided.state = to
			seen = decided
			return decided
		end)
		return nil
	end)
	if not ok then
		return false, nil
	end
	return true, if type(seen) == "table" then seen else nil
end

-- Adds trade `id` to `userId`'s pointers. True when it is stored.
function TradeVault.point(userId: number, id: string): boolean
	if not live() then
		local list = idList(memory.pending[pointerKey(userId)])
		if table.find(list, id) == nil then
			table.insert(list, id)
		end
		memory.pending[pointerKey(userId)] = list
		return true
	end
	local ok = try("point", function()
		store(TradeVault.PENDING):UpdateAsync(pointerKey(userId), function(old: any): any
			local list = idList(old)
			if table.find(list, id) == nil then
				table.insert(list, id)
			end
			return list, { userId }
		end)
		return nil
	end)
	return ok
end

-- Takes trade `id` off `userId`'s pointers. True when done (or it was not there).
function TradeVault.unpoint(userId: number, id: string): boolean
	if not live() then
		local list = idList(memory.pending[pointerKey(userId)])
		local index = table.find(list, id)
		if index ~= nil then
			table.remove(list, index)
		end
		memory.pending[pointerKey(userId)] = list
		return true
	end
	local ok = try("unpoint", function()
		store(TradeVault.PENDING):UpdateAsync(pointerKey(userId), function(old: any): any
			local list = idList(old)
			local index = table.find(list, id)
			if index == nil then
				return nil -- nothing to write
			end
			table.remove(list, index)
			return list, { userId }
		end)
		return nil
	end)
	return ok
end

-- `userId`'s pointers: (true, ids) or (false, nil) when the DataStore could not be reached.
function TradeVault.pointers(userId: number): (boolean, { string }?)
	if not live() then
		return true, idList(memory.pending[pointerKey(userId)])
	end
	local ok, raw = try("pointers", function()
		return store(TradeVault.PENDING):GetAsync(pointerKey(userId), fresh())
	end)
	if not ok then
		return false, nil
	end
	return true, idList(raw)
end

-- The kill switch and live minimum tier: (true, flags) or (false, nil). A key that is missing or not the right type
-- is nil in `flags`.
function TradeVault.flags(): (boolean, Flags?)
	local trading: any, minTier: any
	if not live() then
		trading, minTier = memory.flags.trading, memory.flags.tradeMinTier
	else
		local ok, raw = try("flags", function()
			local flags = store(TradeVault.FLAGS)
			return { flags:GetAsync("trading", fresh()), flags:GetAsync("tradeMinTier", fresh()) }
		end)
		if not ok or type(raw) ~= "table" then
			return false, nil
		end
		trading, minTier = raw[1], raw[2]
	end
	return true,
		{
			trading = if type(trading) == "boolean" then trading else nil,
			tradeMinTier = if type(minTier) == "number" and minTier == minTier
				then math.clamp(math.floor(minTier), 0, 99)
				else nil,
		}
end

return TradeVault
