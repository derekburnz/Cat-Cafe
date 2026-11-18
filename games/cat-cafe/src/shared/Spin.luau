--!strict
-- The Spin Wheel's rules (F49, data-model section 11c), shared so the Spin window's spin count and free spin
-- countdown agree with what SpinService allows. No Roblox services: times are os.time() readings (UTC seconds;
-- the client passes Workspace:GetServerTimeNow()).
-- One free spin a UTC day (missed days do not stack) plus banked spins up to SpinBankCap; a spin uses the free one
-- first.

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Prizes = require(script.Parent.Prizes)
local Types = require(script.Parent.Types)

local Spin = {}

local DAY = 86400

export type Kind = "free" | "banked"

-- The UTC day number of `now`.
function Spin.day(now: number): number
	return math.floor(now / DAY)
end

function Spin.freeDue(spin: Types.SpinState, now: number): boolean
	return Spin.day(now) > spin.lastFreeDay
end

-- Spins the player can use right now: the free one if due, plus the banked ones.
function Spin.available(spin: Types.SpinState, now: number): number
	return (if Spin.freeDue(spin, now) then 1 else 0) + spin.banked
end

-- When the next free spin is due: `now` if it already is, else the next 00:00 UTC.
function Spin.nextFreeAt(spin: Types.SpinState, now: number): number
	if Spin.freeDue(spin, now) then
		return now
	end
	return (spin.lastFreeDay + 1) * DAY
end

-- Uses one spin, the free one first, and says which; nil when there is none.
function Spin.take(spin: Types.SpinState, now: number): Kind?
	if Spin.freeDue(spin, now) then
		spin.lastFreeDay = Spin.day(now)
		return "free"
	elseif spin.banked >= 1 then
		spin.banked -= 1
		return "banked"
	end
	return nil
end

-- Banks up to `count` spins without passing SpinBankCap; returns how many went in (0 means "Spins full").
function Spin.bank(spin: Types.SpinState, count: number): number
	local added = math.clamp(Config.SpinBankCap - spin.banked, 0, math.max(count, 0))
	spin.banked += added
	return added
end

-- Derek 2026-11-15 (the Dragon Keep's Lucky Spin, keep-luck-cards spec): the rare slices whose weight spin luck
-- multiplies (the crate, the golden crate and the 60 fish jackpot); slice 1, the commonest coins, gives up the
-- difference, so the wheel's total stays the same.
Spin.LUCKY_SLICES = { [6] = true, [7] = true, [8] = true } :: { [number]: boolean }
Spin.GIVER_SLICE = 1
Spin.LUCK_MAX = 0.30 -- spin luck at most (DragonKeep.LUCK_KIND_CAP)

-- #5171 (switch spinCat, shared/SpinCat): the cat slice while SpinCat.follow has put one on the wheel, else nil.
Spin.catRow = nil :: Types.SpinSlice?
local withCat: { Types.SpinSlice }? = nil

-- Puts the cat slice `row` on the wheel after the eight, with slice 1 (GIVER_SLICE) giving up its weight so every
-- other prize keeps its chance; nil takes it off again (the wheel is Catalog.spinWheel exactly).
function Spin.setCat(row: Types.SpinSlice?)
	Spin.catRow = row
	if row == nil then
		withCat = nil
		return
	end
	local list = table.clone(Catalog.spinWheel)
	for index, each in list do
		if each.slice == Spin.GIVER_SLICE then
			local giver: Types.SpinSlice = table.clone(each)
			giver.weight = math.max(0, giver.weight - row.weight)
			table.freeze(giver :: any)
			list[index] = giver
		end
	end
	table.insert(list, row)
	withCat = table.freeze(list)
end

-- The wheel's slices in order round it: Catalog.spinWheel, or with the cat slice on it (Spin.setCat) a frozen copy
-- with a ninth. The same table until the cat changes, so the window can tell when to draw again.
function Spin.wheel(): { Types.SpinSlice }
	return withCat or Catalog.spinWheel
end

-- The slice numbered `slice` on the wheel now, or nil.
function Spin.slice(slice: number): Types.SpinSlice?
	for _, row in Spin.wheel() do
		if row.slice == slice then
			return row
		end
	end
	return nil
end

-- The wheel's slices with spin luck `luck` (0.10 is +10%) in their weights: Spin.wheel() itself with none, else
-- copies. The server picks with these and the wheel's Odds list shows them (SpinLogic.share and chance). The cat
-- slice (#5171) is not a lucky slice: its chance is the same for everyone.
function Spin.rows(luck: number?): { Types.SpinSlice }
	local wheel = Spin.wheel()
	if type(luck) ~= "number" or luck <= 0 then
		return wheel
	end
	local boost = 1 + math.min(luck, Spin.LUCK_MAX)
	local out: { Types.SpinSlice } = {}
	local added = 0
	for _, row in wheel do
		local copy = table.clone(row)
		if Spin.LUCKY_SLICES[copy.slice] then
			local weight = copy.weight * boost
			added += weight - copy.weight
			copy.weight = weight
		end
		table.insert(out, copy)
	end
	for _, row in out do
		if row.slice == Spin.GIVER_SLICE then
			row.weight = math.max(0, row.weight - added)
		end
	end
	return out
end

-- The slice a roll in [0, 1) lands on, walking the weights in wheel order (with spin luck `luck`, Spin.rows).
function Spin.pick(roll: number, luck: number?): Types.SpinSlice
	local rows = Spin.rows(luck)
	local total = 0
	for _, row in rows do
		total += row.weight
	end
	local target = math.clamp(roll, 0, 1) * total
	for _, row in rows do
		target -= row.weight
		if target < 0 then
			return Spin.slice(row.slice) or row
		end
	end
	return Catalog.spinWheel[#Catalog.spinWheel]
end

-- What a slice pays at `dayRate` (the day income per second at spin time): coins for a coins slice, else the
-- number of foods, golden fish, crates or (#5171) cats.
function Spin.amount(row: Types.SpinSlice, dayRate: number): number
	if row.kind == "coins" then
		return Prizes.coins(row.minCoins, row.seconds, dayRate)
	end
	return row.count or 1
end

-- #1500 (rewards-and-shops.md section 2b v2): the winner's toast for a jackpot slice, nil for any other. `crateId`
-- is the crate it paid (Prizes.crateFor of the slice's crate), for its name.
function Spin.jackpotText(row: Types.SpinSlice, amount: number, crateId: string?): string?
	if row.jackpot ~= true then
		return nil
	end
	if row.kind == "fish" then
		return string.format("Jackpot! %d golden fish", amount)
	elseif row.kind == "cat" then
		local cat = if row.catId ~= nil then Catalog.getCat(row.catId) else nil
		return if cat ~= nil
			then string.format("Jackpot! %s joins your cafe", cat.name)
			else "Jackpot! A Secret cat"
	end
	local crate = if crateId ~= nil then Catalog.getCrate(crateId) else nil
	if crate ~= nil then
		return "Jackpot! A " .. crate.name
	end
	return "Jackpot!"
end

export type SpinRoll = { slice: number, amount: number }
export type SpinTotal = { kind: string, id: string?, amount: number }

-- Use all spins (#1078): the prizes of several spins added up for the one results card, in wheel order of each
-- prize's first slice: coins together, golden fish together, each food by its lure id and each crate kind by its
-- slice's `crate`. Unknown slices are left out.
function Spin.summarize(rolls: { SpinRoll }): { SpinTotal }
	local totals: { SpinTotal } = {}
	local byKey: { [string]: SpinTotal } = {}
	for _, roll in rolls do
		local row = Spin.slice(roll.slice)
		if row == nil then
			continue
		end
		local id: string? = if row.kind == "lure"
			then row.lureId
			elseif row.kind == "crate" then row.crate
			elseif row.kind == "cat" then row.catId
			else nil
		local key = row.kind .. ":" .. (id or "")
		local total = byKey[key]
		if total == nil then
			local fresh: SpinTotal = { kind = row.kind, id = id, amount = 0 }
			total = fresh
			byKey[key] = fresh
			table.insert(totals, fresh)
		end
		total.amount += roll.amount
	end
	return totals
end

-- A save's spin table made valid: whole numbers, `lastFreeDay` from 0 to today (a day in the future would hold
-- back every free spin until then), `banked` from 0 to SpinBankCap.
function Spin.sanitize(raw: unknown, now: number): Types.SpinState
	local spin: Types.SpinState = { lastFreeDay = 0, banked = 0 }
	if type(raw) == "table" then
		local lastFreeDay = (raw :: any).lastFreeDay
		local banked = (raw :: any).banked
		if type(lastFreeDay) == "number" and lastFreeDay == lastFreeDay then
			spin.lastFreeDay = math.clamp(math.floor(lastFreeDay), 0, Spin.day(now))
		end
		if type(banked) == "number" and banked == banked then
			spin.banked = math.clamp(math.floor(banked), 0, Config.SpinBankCap)
		end
	end
	return spin
end

return Spin
