--!strict
-- #4539 (Derek 2026-11-15, playtester: the Town Square is too cluttered; "lock things like mystery market / cat arcade
-- / trait pool behind tiers 2/3/4"): three stations open only from a cafe tier. Below it the station is hidden on that
-- player's screen (Controllers/StationLockController), its ring and prompt do not open (WalkUpController) and the
-- server refuses its actions (MysteryMarketService, ArcadeService, MouseDashService, TraitService). Players already at
-- or past the tier keep everything. The order (coordinator 2026-11-15): the Mystery Market is a shop and comes first,
-- the Cat Arcade next, the Mystic Pool's traits last since they need a few cats to be worth it.
-- `stationTiers` (LiveFlags, on by default) false opens all three at every tier again, as before.
-- Pure, so the server, the client and the specs read the same table.

local StationTiers = {}

StationTiers.FLAG = "stationTiers"

-- The tier each station opens at, by its CollectionService tag (the tags WalkUpController's KINDS use).
StationTiers.BY_TAG = table.freeze({
	MysteryMarket = 2,
	ArcadeCabinet = 3, -- shared/Arcade.TAG
	MysticPool = 4, -- shared/Traits.TAG
	-- Design-Agent 2026-11-17: codes already need Tier 2, and the stand cluttered Tier 1's Town Square
	CodesCat = 2, -- shared/Codes.TAG
	BellhopStand = 2, -- shared/StarterCat.TAG: Derek 2026-11-17, the free cat never stands in for the Alleyway catch
} :: { [string]: number })

-- The tier a tag's station opens at, or nil for a station that is always open.
function StationTiers.tierOf(tag: string): number?
	return StationTiers.BY_TAG[tag]
end

-- Whether the station with `tag` is shut for a player at `tier`; `on` is the stationTiers switch.
function StationTiers.locked(tag: string, tier: unknown, on: boolean): boolean
	if not on then
		return false
	end
	local need = StationTiers.BY_TAG[tag]
	if need == nil then
		return false
	end
	local have = if type(tier) == "number" and tier == tier then tier else 1
	return have < need
end

-- The small sign over a shut station, and the refusal toast for its actions.
function StationTiers.sign(tag: string): string?
	local need = StationTiers.BY_TAG[tag]
	return if need ~= nil then string.format("🔒 Unlocks at Tier %d", need) else nil
end

StationTiers.NAMES = table.freeze({
	MysteryMarket = "Juniper's cart",
	ArcadeCabinet = "The Cat Arcade",
	MysticPool = "The Mystic Pool",
	CodesCat = "The Codes Cat",
	BellhopStand = "The Bellhop Cat",
} :: { [string]: string })

function StationTiers.refusal(tag: string): string
	local need = StationTiers.BY_TAG[tag] or 1
	return string.format("%s opens at Tier %d", StationTiers.NAMES[tag] or "This station", need)
end

return StationTiers
