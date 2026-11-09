--!strict
-- #2240 (Derek2 2026-11-07: "change rescue spots not always the same"): which of an area's rescue spots hold traps
-- today. Each area has a pool of spots (Layout's rescuePool, about three times its trap count, every spot taking one
-- trap type) and a mix, how many traps of each type are active a day (today's rescueSpots). Each sunrise the server
-- picks that mix from the pool: yesterday's spots only when a type has too few others, and at least
-- Config.RescueSpotSpacingStuds between picks where the pool allows. Without a pool the pool is the mix itself, so
-- every spot is picked, as before. Pure: `rand(n)` returns a whole number from 1 to n, so the specs can drive it.

local RescuePick = {}

export type Candidate = {
	id: string,
	trap: string, -- TrapType
	position: Vector3,
}

-- How many traps of each type `traps` holds: { tree = 3, trashcan = 2 } for the Park.
function RescuePick.mix(traps: { string }): { [string]: number }
	local counts: { [string]: number } = {}
	for _, trap in traps do
		counts[trap] = (counts[trap] or 0) + 1
	end
	return counts
end

local function shuffled<T>(list: { T }, rand: (number) -> number): { T }
	local out = table.clone(list)
	for i = #out, 2, -1 do
		local j = rand(i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end

local function clearOf(position: Vector3, picked: { Candidate }, spacing: number): boolean
	for _, other in picked do
		if (other.position - position).Magnitude < spacing then
			return false
		end
	end
	return true
end

-- #2794: the id of the spot in `pool` nearest (x, z) on the ground plane, ties to the lower id; nil for an empty pool.
function RescuePick.nearest(pool: { Candidate }, x: number, z: number): string?
	local best: string? = nil
	local bestD = math.huge
	for _, spot in pool do
		local dx, dz = spot.position.X - x, spot.position.Z - z
		local d = dx * dx + dz * dz
		if d < bestD or (d == bestD and best ~= nil and spot.id < best) then
			best, bestD = spot.id, d
		end
	end
	return best
end

-- Today's active spot ids, sorted: `mix[trap]` spots of each type from `pool` (or every spot of that type when the
-- pool has fewer), spots in `avoid` (yesterday's) last, and none closer than `spacing` to another pick unless the
-- type cannot be filled otherwise. Types with the fewest spots pick first, so a scarce type is not crowded out.
-- `keep` (#2794: the Alleyway's and the Park's trap nearest the camp) is picked every day, yesterday or not, and
-- counts toward its type; ignored when it is not in the pool or its type is not in the mix.
function RescuePick.pick(
	pool: { Candidate },
	mix: { [string]: number },
	avoid: { [string]: boolean },
	spacing: number,
	rand: (number) -> number,
	keep: string?
): { string }
	local byTrap: { [string]: { Candidate } } = {}
	local types: { string } = {}
	for _, spot in pool do
		if (mix[spot.trap] or 0) > 0 then
			local list = byTrap[spot.trap]
			if list == nil then
				list = {}
				byTrap[spot.trap] = list
				table.insert(types, spot.trap)
			end
			table.insert(list :: { Candidate }, spot)
		end
	end
	for _, list in byTrap do
		table.sort(list, function(a: Candidate, b: Candidate): boolean
			return a.id < b.id
		end)
	end
	table.sort(types, function(a, b)
		local na, nb = #byTrap[a], #byTrap[b]
		if na ~= nb then
			return na < nb
		end
		return a < b
	end)

	local picked: { Candidate } = {}
	local kept: Candidate? = nil
	for _, spot in pool do
		if spot.id == keep and (mix[spot.trap] or 0) > 0 then
			kept = spot
			table.insert(picked, spot)
		end
	end
	for _, trap in types do
		local fresh: { Candidate } = {}
		local stale: { Candidate } = {}
		for _, spot in byTrap[trap] do
			table.insert(if avoid[spot.id] then stale else fresh, spot)
		end
		local order = shuffled(fresh, rand)
		for _, spot in shuffled(stale, rand) do
			table.insert(order, spot)
		end
		local want = math.min(mix[trap], #order)
		local taken: { [string]: boolean } = {}
		local got = 0
		if kept ~= nil and kept.trap == trap then
			taken[kept.id] = true
			got = 1
		end
		-- first pass keeps the spacing, the second fills what the spacing left short
		for pass = 1, 2 do
			for _, spot in order do
				if got >= want then
					break
				end
				if
					not taken[spot.id] and (pass == 2 or clearOf(spot.position, picked, spacing))
				then
					taken[spot.id] = true
					table.insert(picked, spot)
					got += 1
				end
			end
		end
	end

	local ids: { string } = {}
	for _, spot in picked do
		table.insert(ids, spot.id)
	end
	table.sort(ids)
	return ids
end

return RescuePick
