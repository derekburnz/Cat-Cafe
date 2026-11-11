--!strict
-- #3360 (Derek2 2026-11-11: "make it so rich customers leave money bags that sit there for a while instead of they
-- themselves being the timer"; rich-money-bags.md): the rules for the money bags a rich customer leaves on table 1.
-- Pure, so the specs run it; RichTipService holds the bags and pays, the client only draws them.
--   - A bag waits Config.RichBagSeconds from the moment it drops (an account's first: FirstVisits.stay), with no
--     dusk clamp: one dropped by day waits through nightfall.
--   - Up to Config.RichBagsMax wait on a plot at once, each on its own slot beside the RichTipAnchor (SLOTS).
--   - The front bag is the one that goes first (earliest expiry, then oldest); the plot's display attributes show it.
--   - An unclaimed bag is gone at its time and pays nothing.

local Config = require(script.Parent.Config)

local RichBags = {}

export type Bag = {
	id: string, -- "b<serial>": Guard.id's letters, for ClaimRichTip(bagId)
	slot: number, -- 1 to RichBagsMax: which spot on the table
	amount: number,
	boost: number, -- the Cafe Event's money in `amount` (1 without one)
	droppedAt: number, -- os.time()
	expiresAt: number, -- os.time()
	first: boolean, -- #2792: the account's first rich customer
}

-- Each slot's offset from the RichTipAnchor along the table (studs, the anchor's own X and Z): the middle, then
-- either side, close enough to stay on table 1 and clear of each other.
RichBags.SLOTS = {
	{ x = 0, z = 0 },
	{ x = -1.3, z = 0.2 },
	{ x = 1.3, z = 0.2 },
} :: { { x: number, z: number } }

RichBags.FOLDER = "RichBags" -- the plot's folder of display records, one child per waiting bag

function RichBags.idOf(serial: number): string
	return "b" .. tostring(serial)
end

function RichBags.offset(slot: number): { x: number, z: number }
	return RichBags.SLOTS[math.clamp(slot, 1, #RichBags.SLOTS)]
end

-- The lowest slot no waiting bag is on, or nil when the plot is full (RichBagsMax, and never more than SLOTS).
function RichBags.freeSlot(bags: { Bag }): number?
	local most = math.min(Config.RichBagsMax, #RichBags.SLOTS)
	if #bags >= most then
		return nil
	end
	for slot = 1, most do
		local taken = false
		for _, bag in bags do
			if bag.slot == slot then
				taken = true
				break
			end
		end
		if not taken then
			return slot
		end
	end
	return nil
end

-- The bag that goes first: the earliest expiry, the older one on a tie. Nil with none waiting.
function RichBags.front(bags: { Bag }): Bag?
	local best: Bag? = nil
	for _, bag in bags do
		if
			best == nil
			or bag.expiresAt < best.expiresAt
			or (bag.expiresAt == best.expiresAt and bag.droppedAt < best.droppedAt)
		then
			best = bag
		end
	end
	return best
end

function RichBags.find(bags: { Bag }, id: string): Bag?
	for _, bag in bags do
		if bag.id == id then
			return bag
		end
	end
	return nil
end

-- Takes `id` out of `bags` and returns it, or nil when it is not there (so a bag is paid or missed exactly once).
function RichBags.remove(bags: { Bag }, id: string): Bag?
	for index, bag in bags do
		if bag.id == id then
			table.remove(bags, index)
			return bag
		end
	end
	return nil
end

-- The ids of the bags whose time is up at `now`.
function RichBags.expired(bags: { Bag }, now: number): { string }
	local out: { string } = {}
	for _, bag in bags do
		if now >= bag.expiresAt then
			table.insert(out, bag.id)
		end
	end
	return out
end

function RichBags.total(bags: { Bag }): number
	local sum = 0
	for _, bag in bags do
		sum += bag.amount
	end
	return sum
end

return RichBags
