--!strict
-- The night dealer's stock (data-model section 8b, v0.5 F43): three slots, each a dealer food rolled from
-- DealerSlotWeights. The roll is seeded only from the global dealer window, so every player on every server sees
-- the same three foods and a rejoin or a server hop cannot reroll; it uses its own generator so every server and the
-- specs agree. Each player's bought marks stay their own.

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

-- The window's seed, the same on every server. Every product stays under 2^53, so it is exact.
function Dealer.seed(window: number): number
	local hash = (7 * 1000003 + math.floor(window) % MODULUS) % MODULUS
	-- two more rounds so neighbouring windows do not start the generator at neighbouring states
	for _ = 1, 2 do
		hash = (hash * MULTIPLIER) % MODULUS
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

-- The three foods everyone sees in `window`, by slot.
function Dealer.stock(window: number): { string }
	local state = Dealer.seed(window)
	local foods: { string } = {}
	for _ = 1, Dealer.SLOTS do
		state = (state * MULTIPLIER) % MODULUS
		table.insert(foods, Dealer.pick(Catalog.dealerSlotWeights, state / MODULUS))
	end
	return foods
end

-- True while this server's window is behind the one the saved marks belong to (a hop to a server whose clock
-- is a second behind at a window edge). Every slot then counts as bought until the window catches up, so a
-- food bought in the newer window cannot be bought again from the older one (reviewer N32).
function Dealer.behind(state: Types.DealerState, window: number): boolean
	return window < state.window
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
