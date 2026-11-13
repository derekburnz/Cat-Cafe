--!strict
-- Daytime stray top-ups (#1159). The sunrise wave still fills each area; then, while an area's live strays are under
-- its floor, one more stray arrives each time a timer drawn from StrayTopUpMinSeconds to StrayTopUpMaxSeconds runs
-- out, at a far point (a "deep" point in the long areas; any free point in the Alleyway since #3170) when one is
-- free, so the back of the area is never left bare. The floor grows with the players who have the area open, so a full server finds about
-- as many strays each as a lone player, and it never passes StrayLiveMax live cats in one area. A top-up rolls its
-- rarity from the area's normal odds, so the rare odds per stray are unchanged. Pure: CatService runs it.
-- Since Derek2's "no cats start of sewer" (2026-11-05) a gated area also keeps Config.StrayEntryFloor strays within
-- Config.StrayEntryStuds of its gate: the commonest of each wave land there (`waveEntry`), and while fewer stand there
-- one more arrives at an entry point every StrayEntryTopUpSeconds (`entryShort`, `entryPool`).

local Config = require(script.Parent.Config)

local StrayTopUp = {}

-- #3170 (Derek2: "all the cats in alleyway are piled into the back"): not the Alleyway's nooks any more; a top-up
-- there takes any free point, so the back is no longer where every new stray lands
StrayTopUp.FAR_ZONES = table.freeze({ deep = true }) :: { [string]: boolean }

-- The live strays an area keeps by day with `players` players who have it open (a lone player counts as one).
-- `base` is the area's own floorBase (#2794: the Alleyway and the Park), Config.StrayFloorBase when nil.
function StrayTopUp.floor(players: number, base: number?): number
	local extra = math.max(0, math.floor(players) - 1)
	return math.min(
		Config.StrayLiveMax,
		(base or Config.StrayFloorBase) + Config.StrayFloorPerPlayer * extra
	)
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

-- True while an area with `nearGate` live strays near its gate and `live` in all wants an entry top-up. `entryFloor`
-- is the area's own (#2794), Config.StrayEntryFloor when nil.
function StrayTopUp.entryShort(nearGate: number, live: number, entryFloor: number?): boolean
	return nearGate < (entryFloor or Config.StrayEntryFloor) and live < Config.StrayLiveMax
end

-- Whether the `place`-th stray placed from a wave of `size` (rarest first) goes near the gate: the last
-- `entryFloor` (Config.StrayEntryFloor when nil) placed, the commonest.
function StrayTopUp.waveEntry(place: number, size: number, entryFloor: number?): boolean
	return place > size - (entryFloor or Config.StrayEntryFloor)
end

-- #3661: a sunrise wave is placed over time, not all in one frame (some 80 cat models at once was one 1.3 MB burst
-- to every client). `waves` is each area's strays, rarest first. Returns `now`, the ones to place at once, the first
-- `atOnce` of every area (its rarest, so a Mythical is there at sunrise), and `later`, the rest in the order to place them:
-- one area after another in turn, each area from its commonest back, since those land by the gate (`waveEntry`)
-- and the start of an area should not stay bare.
-- (a table of the two lists, not two results: the CI type check loses a generic function's second result)
function StrayTopUp.waveOrder(waves: { { any } }, atOnce: number): { now: { any }, later: { any } }
	local first = math.max(0, math.floor(atOnce))
	local now: { any } = {}
	local later: { any } = {}
	local longest = 0
	for _, wave in waves do
		for index = 1, math.min(first, #wave) do
			table.insert(now, wave[index])
		end
		longest = math.max(longest, #wave - first)
	end
	for back = 0, longest - 1 do
		for _, wave in waves do
			local index = #wave - back
			if index > first then
				table.insert(later, wave[index])
			end
		end
	end
	return { now = now, later = later }
end

-- Seconds between two of the `count` strays placed later, so the last lands `spread` seconds after sunrise; never
-- under a thirtieth of a second (a frame) and never over a second.
function StrayTopUp.waveGap(count: number, spread: number): number
	if count < 1 then
		return 0
	end
	return math.clamp(spread / count, 1 / 30, 1)
end

return StrayTopUp
