--!strict
-- Walk-up windows (#2398, Derek2 2026-11-08: "similar to how codes stand works change all the tap to opens to just if
-- you walk near the menu's pop up for cannon/day cart/fish market/spin area", and "add the night market area (only
-- when its night)"): walking up to a station opens its window and walking away closes it, as the Codes Cat's circle
-- does (shared/Codes.circleOpen). The stations' prompts stay, so a window closed by hand opens again with a press.
--   LEAVE_EXTRA                       studs past a station's radius before it counts as left, so an edge never flickers
--   RADIUS_SHARE                      the share of a prompt's MaxActivationDistance that opens its window
--   inside(was, distance, radius)     whether the character counts as at the station now
--   step(state, stations, blocked, current)  one look: the station to open (or nil) and whether to close the window
--   CIRCLE, FRONT_RADIUS, AROUND_PAD  the glowing floor ring that marks where a window opens (Derek2 2026-11-08: "adding
--                                     the circle infront of the stations designed for each station"; the cannon's goes
--                                     all the way around it)
--   frontOffset(front, radius, range) how far in front of a station's pivot its ring's centre sits
--   aroundRadius(half, range)         the radius of a ring all the way round a station
--   fitRing(radius, blocks, most, least)  where that ring moves, and how small it gets, to clear what stands in it
-- Pure, so the cloud spec runner checks it; Controllers/WalkUpController measures and opens, World/WalkUpCircles
-- lays the rings.

local WalkUp = {}

WalkUp.LEAVE_EXTRA = 2
-- The prompt's pill shows from its MaxActivationDistance; the window waits until the player is most of the way in.
WalkUp.RADIUS_SHARE = 0.75

-- The ring's part inside a station's model (World/WalkUpCircles): a flat part `radius` studs across each way from
-- its centre, with its radius in the Radius attribute. The window opens on stepping inside it.
WalkUp.CIRCLE = "WalkUpCircle"
WalkUp.FRONT_RADIUS = 4 -- as the Codes Cat's circle (Config.CodesCircleRadius)
WalkUp.AROUND_PAD = 2.5 -- studs of floor between a station's widest point and a ring all the way round it
WalkUp.EDGE_SLACK = 2 -- the ring's far edge stays this far inside the server's range for the window
-- A camp cannon's ring at most this wide, so it stays on the camp's paving (Laptop-Tester on #2427: 7.3 ran under the
-- camp walls and over the ground beyond)
WalkUp.CAMP_RING_MAX = 5.5

-- Studs from a station's pivot to its front ring's centre, along its front: the ring just touches the station's front
-- (`front` studs out from the pivot), pulled in until its far edge is EDGE_SLACK inside `range`, the server's reach
-- from the pivot for that window, and never behind the pivot.
function WalkUp.frontOffset(front: number, radius: number, range: number): number
	local touching = math.max(0, front) + radius
	return math.max(0, math.min(touching, range - WalkUp.EDGE_SLACK - radius))
end

-- The radius of a ring round a station whose widest point is `half` studs from its pivot: AROUND_PAD clear of it,
-- at most EDGE_SLACK inside `range` and at most `cap` when given.
function WalkUp.aroundRadius(half: number, range: number, cap: number?): number
	local most = math.min(range - WalkUp.EDGE_SLACK, cap or math.huge)
	return math.max(1, math.min(math.max(0, half) + WalkUp.AROUND_PAD, most))
end

-- How far a ring may slide off its station's pivot to clear a wall (#2433), and the floor kept between its rim and
-- what it clears.
WalkUp.FIT_SHIFT_MAX = 1.5
WalkUp.FIT_CLEAR = 0.15

-- #2433 (Laptop-Tester on #2432: each camp's cannon ring ran up to 1.1 studs under the camp's low side wall): a ring of
-- `radius` round a station, with `blocks` the flat points (from the ring's centre) where something stands on its
-- floor. It slides away from them, at most `most` studs, and then shrinks to clear what is left, never below
-- `least`. Returns the slide and the radius.
function WalkUp.fitRing(
	radius: number,
	blocks: { Vector2 },
	most: number,
	least: number
): (Vector2, number)
	local shift = Vector2.zero
	local limit = math.max(0, most)
	-- each pass moves by the average of every block's push, so blocks on opposite sides cancel instead of bouncing
	for _ = 1, 24 do
		local push = Vector2.zero
		local count = 0
		for _, block in blocks do
			local away = block - shift
			local gap = radius + WalkUp.FIT_CLEAR - away.Magnitude
			if gap > 1e-3 and away.Magnitude > 1e-3 then
				push -= away.Unit * gap
				count += 1
			end
		end
		if count == 0 or push.Magnitude / count < 1e-3 then
			break
		end
		shift += push / count
		if shift.Magnitude > limit then
			shift = if limit > 0 then shift.Unit * limit else Vector2.zero
		end
	end
	local fitted = radius
	for _, block in blocks do
		local room = (block - shift).Magnitude - WalkUp.FIT_CLEAR
		if room < fitted - 1e-3 then
			fitted = room
		end
	end
	return shift, math.max(math.min(least, radius), fitted)
end

-- One station this look: its key, the window it opens (the UI's modal name), the flat studs from the character
-- (nil while streamed out or its prompt is off) and its radius.
-- `off` while its prompt is off (a flight, a closed stall): the character still counts as at it or not, but stepping
-- in opens nothing, so a landing inside a ring opens nothing once the prompt is back.
export type Station = {
	key: string,
	window: string,
	distance: number?,
	radius: number,
	off: boolean?,
}

-- What the controller keeps between looks: whether the character was at each station (nil before the first look at
-- it), and the station whose window a walk-up opened (nil after it closed it, or when nothing was opened).
export type State = { inside: { [string]: boolean }, opened: string?, openedWindow: string? }

function WalkUp.new(): State
	return { inside = {}, opened = nil, openedWindow = nil }
end

function WalkUp.inside(was: boolean, distance: number?, radius: number): boolean
	if distance == nil or distance ~= distance then
		return false
	end
	if was then
		return distance <= radius + WalkUp.LEAVE_EXTRA
	end
	return distance <= radius
end

-- One look. `blocked` is true while the player cannot be interrupted (a catch, a rescue, carrying, flying, the intro).
-- `current` is the window open now (UI.isOpen), or nil. Returns the station key to open, or nil, and whether to close
-- the window a walk-up opened (only when that window is still the one showing). Only stepping in opens a window, so
-- one closed by hand, or blocked on the way in, waits until the player walks away and back; and only from a look that
-- saw the player outside, so spawning, landing or a cart arriving next to the player opens nothing. Mutates `state`.
function WalkUp.step(
	state: State,
	stations: { Station },
	blocked: boolean,
	current: string?
): (string?, boolean)
	local entered: Station? = nil
	local seen: { [string]: boolean } = {}
	for _, station in stations do
		seen[station.key] = true
		local was = state.inside[station.key]
		local now = WalkUp.inside(was == true, station.distance, station.radius)
		state.inside[station.key] = now
		if
			now
			and was == false
			and station.off ~= true
			and (
				entered == nil
				or (station.distance :: number) < ((entered :: Station).distance :: number)
			)
		then
			entered = station
		end
	end
	for key in state.inside do
		if not seen[key] then
			state.inside[key] = nil -- a station gone (the night market leaves at sunrise) counts as left
		end
	end
	local close = false
	local opened = state.opened
	if opened ~= nil and state.inside[opened] ~= true then
		close = current ~= nil and current == state.openedWindow
		state.opened, state.openedWindow = nil, nil
	end
	if entered ~= nil and not blocked and (current == nil or close) then
		local station = entered :: Station
		state.opened, state.openedWindow = station.key, station.window
		return station.key, close
	end
	return nil, close
end

return WalkUp
