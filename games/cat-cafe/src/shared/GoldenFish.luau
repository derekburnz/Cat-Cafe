--!strict
-- Golden fish (F52, golden-fish.md sections 1 and 2): the rare currency beside coins. Earned only, from hard things:
-- a cat new to the Index, its first gold, Epic and better repeat catches by net or rescue, rank ups, the Tip Jar's
-- last step and (F54) the Index and the wheel. No Robux path reaches them, and coins never turn into fish. Pure.

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local GoldenFish = {}

-- Fish for one cat added to the cafe. `isNew` when its id was not in the Index yet, `firstGold` when it is the
-- first gold one of that id (both can be true: a first catch that is gold fills both pages and pays both). A cat
-- already in the Index pays only for Epic and better and only by net or rescue: bait never pays a repeat, so food
-- bought with coins cannot be farmed into fish.
function GoldenFish.forCatch(
	rarity: string,
	isNew: boolean,
	firstGold: boolean,
	method: Types.CatchMethod
): number
	local first = Config.FishFirstCatch[rarity] or 0
	local fish = 0
	if isNew then
		fish += first
	end
	if firstGold then
		fish += 2 * first
	end
	if fish == 0 and (method == "net" or method == "rescue") then
		fish = Config.FishRepeatCatch[rarity] or 0
	end
	return fish
end

-- Fish for reaching `tier` (2 to 5); 0 for any other tier.
function GoldenFish.forRankUp(tier: number): number
	return Config.FishRankUp[tier - 1] or 0
end

-- Adds earned fish: the wallet, the lifetime count and stats.fishEarned. Whole fish only; nothing for 0 or less.
function GoldenFish.credit(profile: Types.PlayerProfile, amount: number)
	local n = math.floor(amount)
	if n <= 0 then
		return
	end
	profile.goldenFish += n
	profile.lifetimeGoldenFish += n
	profile.stats.fishEarned += n
end

-- Spends `cost` fish when the wallet holds that many. False (and nothing spent) otherwise.
function GoldenFish.trySpend(profile: Types.PlayerProfile, cost: number): boolean
	if cost < 0 or profile.goldenFish < cost then
		return false
	end
	profile.goldenFish -= cost
	return true
end

return GoldenFish
