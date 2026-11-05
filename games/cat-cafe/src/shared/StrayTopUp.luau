--!strict
-- Daytime stray top-ups (#1159). The sunrise wave still fills each area; then, while an area's live strays are under
-- its floor, one more stray arrives each time a timer drawn from StrayTopUpMinSeconds to StrayTopUpMaxSeconds runs
-- out, at a far point (a "deep" point in the long areas, a "nook" in the Alleyway) when one is free, so the back of
-- the area is never left bare. The floor grows with the players who have the area open, so a full server finds about
-- as many strays each as a lone player, and it never passes StrayLiveMax live cats in one area. A top-up rolls its
-- rarity from the area's normal odds, so the rare odds per stray are unchanged. Pure: CatService runs it.
-- Since Derek2's "no cats start of sewer" (2026-11-05) a gated area also keeps Config.StrayEntryFloor strays within
-- Config.StrayEntryStuds of its gate: the commonest of each wave land there (`waveEntry`), and while fewer stand there
-- one more arrives at an entry point every StrayEntryTopUpSeconds (`entryShort`, `entryPool`).

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

-- True when (x, z) is within Config.StrayEntryStuds of the gate at (gateX, gateZ), on the ground plane.
function StrayTopUp.nearGate(x: number, z: number, gateX: number, gateZ: number): boolean
	local dx, dz = x - gateX, z - gateZ
	return dx * dx + dz * dz <= Config.StrayEntryStuds * Config.StrayEntryStuds
end

-- The points of `pool` near the gate (`near[index]` true), or the whole pool when none is.
function StrayTopUp.entryPool(pool: { number }, near: { [number]: boolean }): { number }
	local entry: { number } = {}
	for _, index in pool do
		if near[index] then
			table.insert(entry, index)
		end
	end
	return if #entry > 0 then entry else pool
end

-- True while an area with `nearGate` live strays near its gate and `live` in all wants an entry top-up.
function StrayTopUp.entryShort(nearGate: number, live: number): boolean
	return nearGate < Config.StrayEntryFloor and live < Config.StrayLiveMax
end

-- Whether the `place`-th stray placed from a wave of `size` (rarest first) goes near the gate: the last
-- StrayEntryFloor placed, the commonest.
function StrayTopUp.waveEntry(place: number, size: number): boolean
	return place > size - Config.StrayEntryFloor
end

return StrayTopUp
