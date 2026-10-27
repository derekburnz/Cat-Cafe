--!strict
-- What a prize row is worth when it pays (F54, golden-fish.md sections 5, 6 and 8), shared by the Index rewards
-- and the Spin Wheel so the screens and the server agree. Pure.

local Catalog = require(script.Parent.Catalog)

local Prizes = {}

-- A crate prize may name "highest" instead of a crate id.
Prizes.HIGHEST = "highest"

-- Coins at `dayRate` (day income per second): `seconds` of it, never less than `minCoins`.
function Prizes.coins(minCoins: number?, seconds: number?, dayRate: number): number
	return math.max(minCoins or 0, math.floor(math.max(dayRate, 0) * (seconds or 0)))
end

-- The crate id a prize pays. "highest" is the plain crate of the highest-tier zone the player's tier has opened,
-- the first in Catalog.areas order on a tie (the UI's CrateLogic.resolve does the same); nil for an unknown id.
function Prizes.crateFor(crateId: string, tier: number): string?
	if crateId ~= Prizes.HIGHEST then
		return if Catalog.getCrate(crateId) ~= nil then crateId else nil
	end
	local best: string? = nil
	local bestTier = -math.huge
	for _, area in Catalog.areas do
		if area.tier > tier or area.tier <= bestTier then
			continue
		end
		local id = area.id .. "_crate"
		if Catalog.getCrate(id) ~= nil then
			best = id
			bestTier = area.tier
		end
	end
	return best
end

return Prizes
