--!strict
-- Station perks (#2687 part 1, Derek2 2026-11-09: "make unlocking the stations inside new areas more impactful so it
-- feels like you are actually unlocking progress"; Design-Agent's table). Each area's camp station brings one lasting
-- perk that works everywhere from the moment the player owns that area's tier. Perks come from the tier alone, never
-- from a save field, so every save has the ones its tier earns with no save change. None is sold, and none touches
-- Luck, walk speed or rarity odds.
--
--   tier  station          perk          what it does                                   read by
--   2     Picnic Basket    Fresh Bait    bait cats arrive 10% sooner (adds to baitSpeed)  Economy.baitWaitSeconds
--   3     Yard Sale        Haggler       rich customers' money bags pay 10% more         RichTipService (bag amount)
--   4     Fish Pond        Lucky Line    +1 golden fish on a new cat type's first catch  CafeService check-in
--   5     Lost and Found   Homing Bell   your own dropped cats walk home twice as fast   CatService walkHome
--   6     Oasis Spa        Warm Paws     rescue zones 10% wider                          RescueService (Rescue)
--   7     Relic Museum     Curator       +5% tips                                        Economy.incomePerSecond
--   8     Cocoa Stand      Cocoa Break   +10% money for 10 min, free every 2 hours       the Cocoa Stand (to build)
--
-- Pure, so the client shows the same numbers (the Unlocked card and the "Your perks" list are UI-Engineer's).

local StationPerks = {}

export type Perk = {
	id: string,
	tier: number, -- owned from this tier on
	station: string, -- the camp station's name
	name: string, -- the perk's name
	text: string, -- one line on what it does, for the Unlocked card and the perks list
}

StationPerks.LIST = table.freeze({
	table.freeze({
		id = "fresh_bait",
		tier = 2,
		station = "Picnic Basket",
		name = "Fresh Bait",
		text = "Bait cats arrive 10% sooner",
	}),
	table.freeze({
		id = "haggler",
		tier = 3,
		station = "Yard Sale",
		name = "Haggler",
		-- 2026-11-13: was "+10% coins when you sell a cat"; cats are not sold any more (Derek: "remove sell from game")
		text = "Rich customers' money bags pay 10% more",
	}),
	table.freeze({
		id = "lucky_line",
		tier = 4,
		station = "Fish Pond",
		name = "Lucky Line",
		text = "+1 golden fish on the first catch of each new cat",
	}),
	table.freeze({
		id = "homing_bell",
		tier = 5,
		station = "Lost and Found",
		name = "Homing Bell",
		text = "Your dropped cats walk home twice as fast",
	}),
	table.freeze({
		id = "warm_paws",
		tier = 6,
		station = "Oasis Spa",
		name = "Warm Paws",
		text = "Rescue zones are 10% wider",
	}),
	table.freeze({
		id = "curator",
		tier = 7,
		station = "Relic Museum",
		name = "Curator",
		text = "+5% tips",
	}),
	-- #3997 (tier8-snowy-mountain.md section 5): the Cocoa Stand's free cocoa, a timed money boost rather than a lasting
	-- one. Design calls it Warm Paws, a name the Oasis Spa's perk already has, so here it is Cocoa Break.
	table.freeze({
		id = "cocoa_break",
		tier = 8,
		station = "Cocoa Stand",
		name = "Cocoa Break",
		text = "Free cocoa every 2 hours: +10% money for 10 minutes",
	}),
} :: { Perk })

StationPerks.BAIT_SPEED = 0.10 -- Fresh Bait: added to the Index's and potions' baitSpeed
StationPerks.RICH_BAG_MULTIPLIER = 1.10 -- Haggler
StationPerks.FIRST_CATCH_FISH = 1 -- Lucky Line
StationPerks.HOMING_SPEED = 2 -- Homing Bell: times Config.DropReturnWalkSpeed
StationPerks.RESCUE_ZONE_SCALE = 1.10 -- Warm Paws: times Config.RescueZoneWidth
StationPerks.TIP_MULTIPLIER = 1.05 -- Curator

local byId: { [string]: Perk } = {}
for _, perk in StationPerks.LIST do
	byId[perk.id] = perk
end

function StationPerks.get(id: string): Perk?
	return byId[id]
end

-- Whether a player at `tier` has perk `id`; false for an unknown id.
function StationPerks.has(tier: number?, id: string): boolean
	local perk = byId[id]
	return perk ~= nil and (tier or 1) >= perk.tier
end

-- The perks a player at `tier` has, in tier order.
function StationPerks.owned(tier: number?): { Perk }
	local list = {}
	for _, perk in StationPerks.LIST do
		if (tier or 1) >= perk.tier then
			table.insert(list, perk)
		end
	end
	return list
end

-- The next perk after `tier`, or nil once every one is owned (the rank-up teaser and the perks list's silhouette).
function StationPerks.nextAfter(tier: number?): Perk?
	for _, perk in StationPerks.LIST do
		if (tier or 1) < perk.tier then
			return perk
		end
	end
	return nil
end

-- The perk a player gets on reaching exactly `tier`, or nil.
function StationPerks.at(tier: number): Perk?
	for _, perk in StationPerks.LIST do
		if perk.tier == tier then
			return perk
		end
	end
	return nil
end

function StationPerks.baitSpeed(tier: number?): number
	return if StationPerks.has(tier, "fresh_bait") then StationPerks.BAIT_SPEED else 0
end

-- What a rich customer's money bag worth `value` pays at `tier`, a whole number (Haggler from Tier 3).
function StationPerks.richBag(value: number, tier: number?): number
	if StationPerks.has(tier, "haggler") then
		return math.floor(value * StationPerks.RICH_BAG_MULTIPLIER + 0.5)
	end
	return value
end

function StationPerks.firstCatchFish(tier: number?): number
	return if StationPerks.has(tier, "lucky_line") then StationPerks.FIRST_CATCH_FISH else 0
end

function StationPerks.homingSpeed(tier: number?): number
	return if StationPerks.has(tier, "homing_bell") then StationPerks.HOMING_SPEED else 1
end

function StationPerks.rescueZoneScale(tier: number?): number
	return if StationPerks.has(tier, "warm_paws") then StationPerks.RESCUE_ZONE_SCALE else 1
end

function StationPerks.tipMultiplier(tier: number?): number
	return if StationPerks.has(tier, "curator") then StationPerks.TIP_MULTIPLIER else 1
end

return StationPerks
