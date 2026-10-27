--!strict
-- The Spin Wheel's sums (F49, data-model section 11c): the slices' chances, how many spins the player has, when the
-- next free one comes and where the wheel stops. Pure: no Theme, so the cloud spec runner can load it.
--
-- Catalog.spinWheel holds six rows in order round the wheel, clockwise from the top: { slice, kind = "coins" |
-- "lure" | "fish" | "crate", seconds?, minCoins?, lureId?, count?, crate?, weight } (F54 made slice 5 four golden
-- fish and slice 6 a crate, crate = "highest"). The weights add up to 100. state.spin is
-- { lastFreeDay, banked }: one free spin is due when the UTC day (floor(serverTime / 86400)) is past lastFreeDay,
-- missed days do not stack, and banked spins come from the Tip Jar. The server's check at spin time is final.

local Types = require(script.Parent.Parent.Types)

export type Row = Types.SpinRow
export type Spin = Types.SpinState

local SpinLogic = {}

SpinLogic.DAY = 86400

local function day(now: number): number
	return math.floor(now / SpinLogic.DAY)
end

-- A missing spin state reads as a new player's: nothing banked, today's free spin waiting.
local function spinOf(spin: Spin?): Spin
	return spin or { lastFreeDay = 0, banked = 0 }
end

function SpinLogic.freeDue(spin: Spin?, now: number): boolean
	return day(now) > spinOf(spin).lastFreeDay
end

-- Spins the player can use now: the banked ones plus today's free one.
function SpinLogic.spins(spin: Spin?, now: number): number
	local state = spinOf(spin)
	return math.max(0, math.floor(state.banked)) + (if SpinLogic.freeDue(state, now) then 1 else 0)
end

-- Seconds until the next free spin: 0 while one is waiting, else until 00:00 UTC.
function SpinLogic.nextFreeIn(spin: Spin?, now: number): number
	if SpinLogic.freeDue(spin, now) then
		return 0
	end
	return math.max(0, (day(now) + 1) * SpinLogic.DAY - now)
end

-- "5h 12m", "12m 30s", "45s"
function SpinLogic.wait(seconds: number): string
	local total = math.max(0, math.ceil(seconds))
	local hours = total // 3600
	local minutes = (total % 3600) // 60
	if hours > 0 then
		return ("%dh %dm"):format(hours, minutes)
	elseif minutes > 0 then
		return ("%dm %ds"):format(minutes, total % 60)
	end
	return ("%ds"):format(total)
end

-- The row's chance in percent, from its weight over all the weights: "30%", "2.5%".
function SpinLogic.chance(rows: { Row }, row: Row): string
	local total = 0
	for _, each in rows do
		total += math.max(0, each.weight)
	end
	if total <= 0 then
		return "0%"
	end
	local percent = math.max(0, row.weight) / total * 100
	local rounded = math.floor(percent * 10 + 0.5) / 10
	if rounded == math.floor(rounded) then
		return ("%d%%"):format(rounded)
	end
	return ("%.1f%%"):format(rounded)
end

-- A coins row's estimate for this player: max(minCoins, floor(dayRate * seconds)), as the server pays it.
function SpinLogic.coins(row: Row, dayRate: number): number
	return math.max(row.minCoins or 0, math.floor(math.max(0, dayRate) * (row.seconds or 0)))
end

-- The position of the row with this slice number in the list, or nil.
function SpinLogic.indexOf(rows: { Row }, slice: number): number?
	for index, row in rows do
		if row.slice == slice then
			return index
		end
	end
	return nil
end

-- The wheel's rotation, in degrees clockwise, that puts the middle of slot `index` (1 at the top, then clockwise)
-- under the pointer after at least `turns` full turns from `from`. Always the middle, never an edge (N127).
function SpinLogic.landing(from: number, index: number, count: number, turns: number): number
	local centre = (index - 1) * 360 / math.max(1, count)
	local base = from + turns * 360
	local delta = (-centre - base) % 360
	return base + delta
end

-- The slot under the pointer at this rotation, for the tick as each slice passes.
function SpinLogic.slotAt(rotation: number, count: number): number
	local size = 360 / math.max(1, count)
	local angle = (-rotation + size / 2) % 360
	return math.floor(angle / size) % count + 1
end

-- Why a refused spin was refused, as far as the client can tell.
function SpinLogic.refusal(spin: Spin?, now: number): string
	if SpinLogic.spins(spin, now) <= 0 then
		return "Next free spin in " .. SpinLogic.wait(SpinLogic.nextFreeIn(spin, now))
	end
	return "Walk up to the wheel and try again"
end

return SpinLogic
