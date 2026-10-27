--!strict
-- The night dealer's stock (data-model section 8b): three slots per player, each a dealer food rolled from the
-- tier's DealerSlotWeights. The roll is seeded from the UserId, the global dealer window and the tier, so a rejoin
-- or a server hop shows the same stock, and it uses its own generator so every server and the specs agree.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

local Dealer = {}

Dealer.SLOTS = 3

local MODULUS = 2147483647 -- 2^31 - 1, the Park-Miller generator
local MULTIPLIER = 48271

-- The global stock window at server time `now` (os.time()).
function Dealer.window(now: number): number
	return math.floor(now / Config.DealerWindowSeconds)
end

-- When the stock after `window` arrives, in os.time().
function Dealer.restocksAt(window: number): number
	return (window + 1) * Config.DealerWindowSeconds
end

-- One seed from the three inputs, the same on every server. Every product stays under 2^53, so it is exact.
function Dealer.seed(userId: number, window: number, tier: number): number
	local hash = 7
	for _, value in { userId, window, tier } do
		hash = (hash * 1000003 + math.floor(value) % MODULUS) % MODULUS
	end
	return if hash == 0 then 1 else hash
end

-- The dealer food at `roll` (0 to 1) through `weights`, in catalog order. Zero weights never come up.
function Dealer.pick(weights: { [string]: number }, roll: number): string
	local total = 0
	local last: string? = nil
	for _, lure in Catalog.lures do
		local weight = if lure.source == "dealer" then weights[lure.id] or 0 else 0
		if weight > 0 then
			total += weight
			last = lure.id
		end
	end
	assert(last ~= nil, "no dealer food has a weight")
	local target = math.clamp(roll, 0, 1) * total
	for _, lure in Catalog.lures do
		local weight = if lure.source == "dealer" then weights[lure.id] or 0 else 0
		if weight > 0 then
			if target < weight then
				return lure.id
			end
			target -= weight
		end
	end
	return last :: string
end

-- The three foods this player sees in `window` at `tier`, by slot.
function Dealer.stock(userId: number, window: number, tier: number): { string }
	local rows = Catalog.dealerSlotWeights
	local weights = rows[math.clamp(math.floor(tier), 1, #rows)]
	local state = Dealer.seed(userId, window, tier)
	local foods: { string } = {}
	for _ = 1, Dealer.SLOTS do
		state = (state * MULTIPLIER) % MODULUS
		table.insert(foods, Dealer.pick(weights, state / MODULUS))
	end
	return foods
end

-- Clears the bought marks once the window has moved on. Never on a step back, because two servers' clocks can
-- differ by a second at a window edge (reviewer N32).
function Dealer.refresh(state: Types.DealerState, window: number)
	if window > state.window then
		state.window = window
		state.bought = {}
	end
end

return Dealer
