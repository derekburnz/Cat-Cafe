--!strict
-- The Spin Wheel's rules (F49, data-model section 11c), shared so the Spin window's spin count and free spin
-- countdown agree with what SpinService allows. No Roblox services: times are os.time() readings (UTC seconds;
-- the client passes Workspace:GetServerTimeNow()).
-- One free spin a UTC day (missed days do not stack) plus banked spins up to SpinBankCap; a spin uses the free one
-- first.

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
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

-- The slice a roll in [0, 1) lands on, walking the weights in wheel order.
function Spin.pick(roll: number): Types.SpinSlice
	local total = 0
	for _, row in Catalog.spinWheel do
		total += row.weight
	end
	local target = math.clamp(roll, 0, 1) * total
	for _, row in Catalog.spinWheel do
		target -= row.weight
		if target < 0 then
			return row
		end
	end
	return Catalog.spinWheel[#Catalog.spinWheel]
end

-- What a slice pays at `dayRate` (the day income per second at spin time): coins for a coins slice, else the
-- number of foods.
function Spin.amount(row: Types.SpinSlice, dayRate: number): number
	if row.kind == "coins" then
		return math.max(row.minCoins or 0, math.floor(math.max(dayRate, 0) * (row.seconds or 0)))
	end
	return row.count or 1
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
