--!strict
-- Rare customers by chance (#3889; Derek 2026-11-13: "make it so rich customers and gifts can spawn at any table and
-- make it a % chance per customer walking in instead of it being a set time"). Pure, so the specs are deterministic.
--
-- With the LiveFlags `rareCustomers` switch on, every open cafe gets a customer every Config.RareCustomerSeconds
-- (RareCustomerService), and each customer is at most one rare kind, rolled here: a rich customer, a Mystery Visitor
-- or the Cat Collector, else an everyday one. Config.RareChance holds each kind's chance; they keep the averages of the
-- old timers (480, 1250 and 300 seconds). The working cats' "rare customer chance" traits (Traits kind rareCustomer,
-- best 2, at most 0.40) raise all three by the same share; the Cafe Style and Grand Cafe passes still raise the rich
-- one only (Economy.richRate holds both for the rich customer). A rare customer sits at any open table (tableFor).

local Config = require(script.Parent.Config)

local RareCustomers = {}

RareCustomers.FLAG = "rareCustomers"

export type Kind = "rich" | "mystery" | "collector"
export type Chances = { rich: number, mystery: number, collector: number }

local KINDS: { Kind } = { "rich", "mystery", "collector" }
RareCustomers.KINDS = table.freeze(KINDS)

-- Each kind's chance for one arriving customer. `richRate` is Economy.richRate (1 plus the passes plus the trait);
-- `traitBonus` is the trait part alone (Economy.traitBonus(profile, "rareCustomer")). The three together never pass
-- 1, so a customer is at most one of them.
function RareCustomers.chances(richRate: number, traitBonus: number): Chances
	local base = Config.RareChance :: { [string]: number }
	local boost = 1 + math.max(0, traitBonus)
	local rich = (base.rich or 0) * math.max(1, richRate)
	local mystery = (base.mystery or 0) * boost
	local collector = (base.collector or 0) * boost
	local total = rich + mystery + collector
	if total > 1 then
		rich, mystery, collector = rich / total, mystery / total, collector / total
	end
	return { rich = rich, mystery = mystery, collector = collector }
end

-- The kind an arriving customer is for a roll `u` in [0, 1), or nil for an everyday customer.
function RareCustomers.pick(chances: Chances, u: number): Kind?
	local at = chances.rich
	if u < at then
		return "rich"
	end
	at += chances.mystery
	if u < at then
		return "mystery"
	end
	at += chances.collector
	if u < at then
		return "collector"
	end
	return nil
end

-- How many customers arrive over `seconds` more of open day, with `carried` seconds left over from before: the count
-- and the seconds carried on (always under RareCustomerSeconds).
function RareCustomers.arrivals(carried: number, seconds: number): (number, number)
	local every = Config.RareCustomerSeconds
	local total = math.max(0, carried) + math.max(0, seconds)
	local count = math.floor(total / every)
	return count, total - count * every
end

-- The table a rare customer sits at: any of the cafe's `tables` open tables, from a roll `u` in [0, 1). 1 with none.
function RareCustomers.tableFor(tables: number, u: number): number
	local open = math.max(1, math.floor(tables))
	return math.clamp(math.floor(u * open) + 1, 1, open)
end

-- A chance as the card reads it: "1.3%" (one decimal, "0.5%" for half a percent).
function RareCustomers.percent(chance: number): string
	return string.format("%.1f%%", math.floor(chance * 1000 + 0.5) / 10)
end

return RareCustomers
