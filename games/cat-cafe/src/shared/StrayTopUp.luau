--!strict
-- Daytime stray top-ups (#1159). The sunrise wave still fills each area; then, while an area's live strays are under
-- its floor, one more stray arrives each time a timer drawn from StrayTopUpMinSeconds to StrayTopUpMaxSeconds runs
-- out, at a far point (a "deep" point in the long areas, a "nook" in the Alleyway) when one is free, so the back of
-- the area is never left bare. The floor grows with the players who have the area open, so a full server finds about
-- as many strays each as a lone player, and it never passes StrayLiveMax live cats in one area. A top-up rolls its
-- rarity from the area's normal odds, so the rare odds per stray are unchanged. Pure: CatService runs it.

local Config = require(script.Parent.Config)

local StrayTopUp = {}

StrayTopUp.FAR_ZONES = table.freeze({ deep = true, nook = true }) :: { [string]: boolean }

-- The live strays an area keeps by day with `players` players who have it open (a lone player counts as one).
function StrayTopUp.floor(players: number): number
	local extra = math.max(0, math.floor(players) - 1)
	return math.min(Config.StrayLiveMax, Config.StrayFloorBase + Config.StrayFloorPerPlayer * extra)
end

-- Seconds until the next top-up, `r` a random number in [0, 1).
function StrayTopUp.wait(r: number): number
	local min, max = Config.StrayTopUpMinSeconds, Config.StrayTopUpMaxSeconds
	return min + (max - min) * math.clamp(r, 0, 1)
end

-- The far points of `pool` (indexes into `zones`, each point's zone or nil), or the whole pool when none is far.
function StrayTopUp.farPool(pool: { number }, zones: { string? }): { number }
	local far: { number } = {}
	for _, index in pool do
		local zone = zones[index]
		if zone ~= nil and StrayTopUp.FAR_ZONES[zone] then
			table.insert(far, index)
		end
	end
	return if #far > 0 then far else pool
end

return StrayTopUp
