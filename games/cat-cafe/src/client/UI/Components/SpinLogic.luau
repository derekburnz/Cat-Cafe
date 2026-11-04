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

-- The row's share of all the weights, in percent (0 to 100).
function SpinLogic.share(rows: { Row }, row: Row): number
	local total = 0
	for _, each in rows do
		total += math.max(0, each.weight)
	end
	if total <= 0 then
		return 0
	end
	return math.max(0, row.weight) / total * 100
end

-- The row's chance in percent, from its weight over all the weights: "30%", "2.5%".
function SpinLogic.chance(rows: { Row }, row: Row): string
	local percent = SpinLogic.share(rows, row)
	local rounded = math.floor(percent * 10 + 0.5) / 10
	if rounded == math.floor(rounded) then
		return ("%d%%"):format(rounded)
	end
	return ("%.1f%%"):format(rounded)
end

-- The rows likeliest first, for the Odds list (F69); equal chances keep their order round the wheel.
function SpinLogic.byChance(rows: { Row }): { Row }
	local list = table.clone(rows)
	table.sort(list, function(a: Row, b: Row): boolean
		if a.weight ~= b.weight then
			return a.weight > b.weight
		end
		return a.slice < b.slice
	end)
	return list
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

-- The big button under the chances (Derek 2026-10-30: "Add a skip to the wheel spin for free"). While the wheel
-- turns it is a free Skip that lands it at once, after a short beat so a double tap on Spin does not skip by
-- mistake; once it has landed it waits out the server's cooldown with a countdown, then reads Spin! again.
export type ButtonView = {
	turning: boolean, -- the wheel is turning
	skippable: boolean, -- the turn is past SKIP_AFTER
	waiting: boolean, -- a pressed Spin waits for SpinResult
	readyIn: number, -- seconds until the server takes the next spin (0 once it does)
	spins: number, -- SpinLogic.spins
	rows: number, -- slices on the wheel
}
export type ButtonState = { text: string, enabled: boolean, skip: boolean }

SpinLogic.SKIP_AFTER = 0.4

function SpinLogic.button(view: ButtonView): ButtonState
	if view.turning then
		return if view.skippable
			then { text = "Skip", enabled = true, skip = true }
			else { text = "Spinning...", enabled = false, skip = false }
	elseif view.waiting then
		return { text = "...", enabled = false, skip = false }
	elseif view.spins <= 0 or view.rows <= 0 then
		return { text = "No spins", enabled = false, skip = false }
	elseif view.readyIn > 0 then
		return {
			text = ("Spin in %ds"):format(math.max(1, math.ceil(view.readyIn - 1e-6))),
			enabled = false,
			skip = false,
		}
	end
	return { text = "Spin!", enabled = true, skip = false }
end

-- Why a refused spin was refused, as far as the client can tell.
function SpinLogic.refusal(spin: Spin?, now: number): string
	if SpinLogic.spins(spin, now) <= 0 then
		return "Next free spin in " .. SpinLogic.wait(SpinLogic.nextFreeIn(spin, now))
	end
	return "Walk up to the wheel and try again"
end

-- #1078 Use all spins (Gameplay-Engineer #1098): SpinAllResult's totals, { kind, id, amount }, as one prize for the
-- results card's PrizeChips. Kinds: "coins", "fish", "lure" (id = lureId), "crate" (id = crate key).
export type Total = { kind: string, id: string?, amount: number }

function SpinLogic.totalsPrize(totals: { Total }): Types.IndexPrize
	local prize: Types.IndexPrize = {}
	for _, total in totals do
		local amount = total.amount
		if type(amount) ~= "number" or amount <= 0 then
			continue
		end
		if total.kind == "coins" then
			prize.coins = (prize.coins or 0) + amount
		elseif total.kind == "fish" then
			prize.fish = (prize.fish or 0) + amount
		elseif total.kind == "lure" and total.id then
			local lures = prize.lures or {}
			lures[total.id] = (lures[total.id] or 0) + amount
			prize.lures = lures
		elseif total.kind == "crate" and total.id then
			local crates = prize.crates or {}
			crates[total.id] = (crates[total.id] or 0) + amount
			prize.crates = crates
		end
	end
	return prize
end

-- The Use all button's words: "Use all 5"; it shows only with two or more spins to use.
function SpinLogic.allText(spins: number, cap: number?): string
	local n = if cap then math.min(spins, cap) else spins
	return ("Use all %d"):format(n)
end

return SpinLogic
