--!strict
-- The station reveal's trigger and "seen" flag (#2687 part 3). The first time a player walks or flies into an area
-- whose tier they own, after the area's camp station brings its perk (StationPerks), the client fires
-- Moments.StationReveal for the build-in beat, the sparkle, the stinger and the Unlocked card (VFX, Sound and UI), then
-- sends TipSeen(key(area)) so it never plays again for that account. The flag rides tipsSeen (Tips.seenId and
-- Tips.sanitizeSeen accept these keys), so there is no new save field: an older server drops the key on load, which
-- only shows the reveal once more.
-- Pure.

local Catalog = require(script.Parent.Catalog)
local StationPerks = require(script.Parent.StationPerks)

local StationReveal = {}

StationReveal.PREFIX = "reveal_"

-- area id -> the tier that opens it, for every area whose tier brings a station perk
local tierOfArea: { [string]: number } = {}
for _, def in Catalog.tiers do
	local area = (def :: any).area
	if type(area) == "string" and StationPerks.at(def.tier) ~= nil then
		tierOfArea[area] = def.tier
	end
end

-- The tipsSeen key for `area`'s reveal.
function StationReveal.key(area: string): string
	return StationReveal.PREFIX .. area
end

-- Whether `id` is one of these keys (an area with a station perk).
function StationReveal.isKey(id: string): boolean
	if string.sub(id, 1, #StationReveal.PREFIX) ~= StationReveal.PREFIX then
		return false
	end
	return tierOfArea[string.sub(id, #StationReveal.PREFIX + 1)] ~= nil
end

-- The perk whose reveal is due as a player at `tier`, with `seen` (tipsSeen), enters `area` (an area id, lower case),
-- or nil: none for this area, not owned yet, or already seen.
function StationReveal.due(
	tier: number?,
	seen: { [string]: boolean }?,
	area: string?
): StationPerks.Perk?
	if area == nil then
		return nil
	end
	local opens = tierOfArea[area]
	if opens == nil or (tier or 1) < opens then
		return nil
	end
	if seen ~= nil and seen[StationReveal.key(area)] == true then
		return nil
	end
	return StationPerks.at(opens)
end

return StationReveal
