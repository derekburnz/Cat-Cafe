--!strict
-- #4311 (Derek 2026-11-14: "I know their is a low quality mode just make it better"; Review-QA's census: 423 night
-- Light objects on at once, in every area, while the player stood in the Park): at night only the COUNT lights
-- nearest the camera and within RANGE studs are on; the rest keep their Neon glow with the Light off. Every device,
-- whether or not Low performance is on (which still turns them all off). Behind the live switch FLAG (on by
-- default; off brings back every light at night). Controllers/WorldController picks again every STEP seconds. Pure.
--   FLAG, COUNT, RANGE, STEP
--   nearest(points, origin, count, range)   the indexes of `points` to light, as a set

local NightLights = {}

NightLights.FLAG = "nearLights"
NightLights.COUNT = 16
NightLights.RANGE = 160 -- studs
NightLights.STEP = 1 -- seconds between picks

function NightLights.nearest(
	points: { Vector3 },
	origin: Vector3,
	count: number,
	range: number
): { [number]: boolean }
	type Near = { index: number, distance: number }
	local inRange: { Near } = {}
	for index, point in points do
		local distance = (point - origin).Magnitude
		if distance <= range then
			table.insert(inRange, { index = index, distance = distance })
		end
	end
	table.sort(inRange, function(a: Near, b: Near): boolean
		if a.distance == b.distance then
			return a.index < b.index
		end
		return a.distance < b.distance
	end)
	local out: { [number]: boolean } = {}
	for i = 1, math.min(count, #inRange) do
		out[inRange[i].index] = true
	end
	return out
end

return NightLights
