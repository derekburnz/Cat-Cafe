--!strict
-- Bedtime (F79, data-model section 12c), pure: the sleep spots' fill order, who sleeps where, the way up a cat tree
-- and the arc of one hop. BedtimeService walks the cats; World/SleepSpots reads the spots off the art.
-- Spot ids: tree_<n>_top and tree_<n>_shelf on the two cat trees (n 1 is entertainer_1's, on the left),
-- decor_<decor spot>_<k> for a decor cat tree's Sleep_<k>, and bed_<n>.

local Bedtime = {}

-- The stations whose furniture is a cat tree, in tree order.
Bedtime.TREES = { "entertainer_1", "entertainer_2" }

Bedtime.HOP_HEIGHT = 0.8 -- how far over the straight line a hop's arc peaks

-- Where a spot comes in the fill order: tree tops, then tree shelves, then decor cat trees by decor spot and their
-- own order, then beds, then anything else by name.
local function key(id: string): (number, number, number)
	local tree = tonumber(id:match("^tree_(%d+)_top$"))
	if tree ~= nil then
		return 1, tree, 0
	end
	tree = tonumber(id:match("^tree_(%d+)_shelf$"))
	if tree ~= nil then
		return 2, tree, 0
	end
	local spot, k = id:match("^decor_(%d+)_(%d+)$")
	if spot ~= nil and k ~= nil then
		return 3, tonumber(spot) :: number, tonumber(k) :: number
	end
	local bed = tonumber(id:match("^bed_(%d+)$"))
	if bed ~= nil then
		return 4, bed, 0
	end
	return 5, 0, 0
end

-- Whether spot `a` fills before spot `b`.
function Bedtime.before(a: string, b: string): boolean
	local a1, a2, a3 = key(a)
	local b1, b2, b3 = key(b)
	if a1 ~= b1 then
		return a1 < b1
	elseif a2 ~= b2 then
		return a2 < b2
	elseif a3 ~= b3 then
		return a3 < b3
	end
	return a < b
end

-- `ids` sorted into fill order (a new table).
function Bedtime.order(ids: { string }): { string }
	local sorted = table.clone(ids)
	table.sort(sorted, Bedtime.before)
	return sorted
end

-- Who sleeps where: `cats` (uids, best rating first) take `spots` (ids in fill order). A cat in `held` keeps its spot
-- while that spot is still there and nobody earlier kept it; the rest take the first free spots in order. A cat
-- left without a spot is not in the result.
function Bedtime.assign(
	cats: { string },
	spots: { string },
	held: { [string]: string }
): { [string]: string }
	local exists: { [string]: boolean } = {}
	for _, id in spots do
		exists[id] = true
	end
	local taken: { [string]: boolean } = {}
	local out: { [string]: string } = {}
	for _, uid in cats do
		local spot = held[uid]
		if spot ~= nil and exists[spot] and not taken[spot] then
			taken[spot] = true
			out[uid] = spot
		end
	end
	local nextIndex = 1
	for _, uid in cats do
		if out[uid] == nil then
			while nextIndex <= #spots and taken[spots[nextIndex]] do
				nextIndex += 1
			end
			if nextIndex > #spots then
				break
			end
			taken[spots[nextIndex]] = true
			out[uid] = spots[nextIndex]
		end
	end
	return out
end

-- The way up one piece of furniture to `target` (Model-Agent #511's hop rule): every Hop_ and Sleep_ point lower than
-- the target, lowest first, then the target. `heights` maps each point's name to its height over the floor; the
-- piece's Foot is where the climb starts and is not in it. Empty for a target the piece does not have.
function Bedtime.hopChain(heights: { [string]: number }, target: string): { string }
	local top = heights[target]
	if top == nil then
		return {}
	end
	local below: { string } = {}
	for name, height in heights do
		if
			name ~= target
			and height < top
			and (name:match("^Hop_") ~= nil or name:match("^Sleep") ~= nil)
		then
			table.insert(below, name)
		end
	end
	table.sort(below, function(a: string, b: string): boolean
		if heights[a] ~= heights[b] then
			return heights[a] < heights[b]
		end
		return a < b
	end)
	table.insert(below, target)
	return below
end

-- The highest single climb along `heights` (the floor first), so a chain can be checked against HopMaxRise.
function Bedtime.highestRise(heights: { number }): number
	local rise = 0
	for i = 2, #heights do
		rise = math.max(rise, heights[i] - heights[i - 1])
	end
	return rise
end

-- Where a hop from `from` to `to` is at `t` (0 to 1): along the straight line, lifted by an arc that peaks
-- HOP_HEIGHT over it halfway.
function Bedtime.arc(from: Vector3, to: Vector3, t: number): Vector3
	local u = math.clamp(t, 0, 1)
	return from + (to - from) * u + Vector3.new(0, Bedtime.HOP_HEIGHT * 4 * u * (1 - u), 0)
end

return Bedtime
