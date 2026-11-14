--!strict
-- Cat Storm (#4195 part 3, Derek 2026-11-14: "Strays rain over every area, Mythical and better 10x as likely", 10
-- minutes), pure. An admin event's `catStorm` effect (shared/CafeEvents) is the boost; while it runs, by day,
-- CatService drops extra strays into every area somebody has open, each rolled on the area's own odds with the
-- Mythical weight times the boost. A Secret cat is a Mythical that turned (CatService.spawnAt), so "and better"
-- rides along. Nothing is sold and nothing here touches a player's own Luck.
--   odds(areaOdds, boost) -> odds      the storm's odds: Mythical's weight times `boost`, the rest as they are
--   share(odds, rarity) -> number      that rarity's share of a roll, 0 to 1 (for the spec and the tuning notes)
--   total(waveSize) -> number          how many strays one area gets over a whole storm
--   gap(seconds, waveSize) -> number   seconds between two strays in one area, for a storm `seconds` long
--   offset(index, count, gap)          the first stray's delay in the index-th area, so the areas never all get
--                                      one in the same second
--   room(live, waveSize) -> boolean    whether an area with `live` strays standing takes another
-- The numbers: a storm adds WAVES sunrise waves' worth of strays to an area, spread evenly over its length (never
-- closer than GAP_MIN), and an area holding LIVE_WAVES waves' worth already waits until some are caught.

local Types = require(script.Parent.Types)

local CatStorm = {}

CatStorm.ATTRIBUTE = "StormCat" -- on a storm stray's model, for the client's falling streak (Effects/CatStorm)
CatStorm.BOOST_MAX = 10
CatStorm.WAVES = 2
CatStorm.LIVE_WAVES = 2
CatStorm.GAP_MIN = 5

function CatStorm.odds(areaOdds: Types.LureOdds, boost: number): Types.LureOdds
	local out = table.clone(areaOdds)
	if boost ~= boost or boost <= 1 then
		return out
	end
	out.Mythical = (areaOdds.Mythical or 0) * math.min(boost, CatStorm.BOOST_MAX)
	return out
end

function CatStorm.share(odds: Types.LureOdds, rarity: string): number
	local sum = 0
	for _, weight in odds :: any do
		if type(weight) == "number" and weight > 0 then
			sum += weight
		end
	end
	local mine = (odds :: any)[rarity]
	if sum <= 0 or type(mine) ~= "number" or mine <= 0 then
		return 0
	end
	return mine / sum
end

function CatStorm.total(waveSize: number): number
	return math.max(1, math.floor(waveSize)) * CatStorm.WAVES
end

function CatStorm.gap(seconds: number, waveSize: number): number
	return math.max(CatStorm.GAP_MIN, seconds / CatStorm.total(waveSize))
end

function CatStorm.offset(index: number, count: number, gap: number): number
	if count <= 1 then
		return 0
	end
	return (index - 1) % count / count * math.min(gap, CatStorm.GAP_MIN * 2)
end

function CatStorm.room(live: number, waveSize: number): boolean
	return live < math.max(1, math.floor(waveSize)) * CatStorm.LIVE_WAVES
end

return CatStorm
