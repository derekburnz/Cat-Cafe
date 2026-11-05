--!strict
-- The Cat Collector (F63, data-model section 12b, round 3 Q6). Pure rules, no Roblox services: which cat he asks
-- for, the value he puts on it, the offer that value reaches and what a trade pays. CollectorService runs the visits.

local CatStats = require(script.Parent.CatStats)
local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Collector = {}

-- True when he may ask for `instance`: an area cat (section 3: never a spare), resting in the cat room (no role slot)
-- and not locked. A cat being carried is not in the cafe yet, so it is never in profile.cats to ask for.
function Collector.askable(instance: Types.CatInstance): boolean
	local def = Catalog.getCat(instance.catId)
	return def ~= nil
		and Catalog.getArea(def.area) ~= nil
		and instance.spotId == nil
		and instance.locked ~= true
end

-- The cat he wants from `cats`: a catId among the distinct catIds of the askable cats, so a pile of Tabbies does not
-- crowd out the rest, weighted by its rarity's Config.CollectorAskWeight (#1144: a player's few rarer resting cats get
-- asked for often, not one time in many), then that catId's askable cat with the lowest rating for an owner at `tier`
-- (the lowest uid on a tie). `roll` returns 0 to 1. Nil when no cat is askable.
function Collector.pickCat(
	cats: { [string]: Types.CatInstance },
	roll: () -> number,
	tier: number?
): Types.CatInstance?
	local byId: { [string]: { Types.CatInstance } } = {}
	local ids: { string } = {}
	for _, instance in cats do
		if not Collector.askable(instance) then
			continue
		end
		local list = byId[instance.catId]
		if list == nil then
			list = {}
			byId[instance.catId] = list
			table.insert(ids, instance.catId)
		end
		table.insert(list :: { Types.CatInstance }, instance)
	end
	if #ids == 0 then
		return nil
	end
	table.sort(ids) -- the same pick for the same roll, whatever order the save's map comes out in
	local weights: { number } = {}
	local total = 0
	for index, id in ids do
		local def = Catalog.getCat(id) :: Types.CatDef
		local weight = math.max(0, Config.CollectorAskWeight[def.rarity] or 1)
		weights[index] = weight
		total += weight
	end
	local catId = ids[#ids]
	local pick = math.clamp(roll(), 0, 1) * total
	for index, id in ids do
		if pick < weights[index] then
			catId = id
			break
		end
		pick -= weights[index]
	end
	local best: Types.CatInstance? = nil
	local bestRating = math.huge
	for _, instance in byId[catId] do
		local rating = CatStats.rating(instance, tier)
		if
			best == nil
			or rating < bestRating
			or (rating == bestRating and instance.uid < (best :: Types.CatInstance).uid)
		then
			best, bestRating = instance, rating
		end
	end
	return best
end

-- The value he puts on `instance`: CollectorValue by its rarity, times CollectorGoldMultiplier for a gold cat (or
-- CollectorRainbowMultiplier for a rainbow one, F99), times
-- `roll` (0 to 1) laid over CollectorRollMin to CollectorRollMax, so the same cat can get a better offer another
-- time. 0 for an unknown cat.
function Collector.value(instance: Types.CatInstance, roll: number): number
	local def = Catalog.getCat(instance.catId)
	if def == nil then
		return 0
	end
	local base = Config.CollectorValue[def.rarity] or 0
	local gold = if instance.variant == "rainbow"
		then Config.CollectorRainbowMultiplier
		elseif instance.variant == "gold" then Config.CollectorGoldMultiplier
		else 1
	local scale = Config.CollectorRollMin
		+ math.clamp(roll, 0, 1) * (Config.CollectorRollMax - Config.CollectorRollMin)
	return base * gold * scale
end

-- The best Catalog.collectorOffers row whose value is at most `value`, else the first row.
function Collector.offerFor(value: number): Types.CollectorOffer
	local chosen = Catalog.collectorOffers[1]
	for _, row in Catalog.collectorOffers do
		if row.value <= value and row.value >= chosen.value then
			chosen = row
		end
	end
	return chosen
end

-- What a trade pays, in the Index prize shape Payout.pay takes: the zone crate is `area`'s crate and the golden
-- crate its golden one. Spins go to the bank up to SpinBankCap like any prize's.
function Collector.prize(offer: Types.CollectorOffer, area: string): Types.IndexPrize
	local lures: { [string]: number }? = if offer.lures ~= nil
		then table.clone(offer.lures)
		else nil
	local crates: { [string]: number }? = nil
	local offered = offer.crates
	if offered ~= nil then
		local paid: { [string]: number } = {}
		if (offered.zone or 0) > 0 then
			paid[area .. "_crate"] = offered.zone :: number
		end
		if (offered.golden or 0) > 0 then
			paid[area .. "_golden_crate"] = offered.golden :: number
		end
		crates = paid
	end
	local catFood: { [string]: number }? = if offer.catFood ~= nil
		then table.clone(offer.catFood)
		else nil
	return {
		fish = offer.fish,
		spins = offer.spins,
		lures = lures,
		crates = crates,
		catFood = catFood,
	}
end

return Collector
