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
--   FRONT_FIT_LEAST, BOARD_RADIUS     the camp stations' fitted front rings and the Index Boards' smaller one (#3113)
--   fitRing(radius, blocks, most, least, keep?)  where that ring moves, and how small it gets, to clear what stands
--                                     in it while still holding the station's base
--   promptReach(hasRing, reach)       how far a station's click prompt reaches: nothing once the station has a ring
--                                     (#3114), so the ring is the only way in; its own reach while it has none
-- Pure, so the cloud spec runner checks it; Controllers/WalkUpController measures and opens, World/WalkUpCircles
-- lays the rings.

local WalkUp = {}

WalkUp.LEAVE_EXTRA = 2
-- The prompt's pill shows from its MaxActivationDistance; the window waits until the player is most of the way in.
WalkUp.RADIUS_SHARE = 0.75

-- The ring's part inside a station's model (World/WalkUpCircles): a flat part `radius` studs across each way from
-- its centre, with its radius in the Radius attribute. The window opens on stepping inside it.
WalkUp.CIRCLE = "WalkUpCircle"
WalkUp.FRONT_RADIUS = 6 -- as the Codes Cat's circle (Config.CodesCircleRadius); #3112 (Derek2: "make the circles infront of the stations bigger"): 4 to 6
-- #2449: a station's icon in its ring (World/WalkUpCircles): the stand-in card this share of the ring's width (its
-- corners stay inside the rim even tilted), the art at most this share across
WalkUp.ICON_SHARE = 0.42
WalkUp.ICON_ART_SHARE = 0.6
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
WalkUp.FIT_CLEAR = 0.02
-- #3113 (Derek2: "circle pads to walk into for all area stations also and big enough"): a camp station's front ring
-- is FRONT_RADIUS like the town's, slid or shrunk off what stands in it (World/WalkUpCircles.frontFit), never under
-- FRONT_FIT_LEAST. An Index Board's is BOARD_RADIUS: it stands beside the way out, where a town-sized ring would lie
-- across the path from the landing pad to the opening and open the Index on everyone walking out.
WalkUp.FRONT_FIT_LEAST = 4.5
WalkUp.BOARD_RADIUS = 4.5

-- #2433 (Laptop-Tester on #2432: each camp's cannon ring ran up to 1.1 studs under the camp's low side wall): a ring of
-- `radius` round a station, with `blocks` the flat points (from the station's pivot) where something stands on its
-- floor, and `keep` the points of the station's own base that the ring must hold (Laptop-Tester on #2435: sliding off
-- the wall alone left the cannon's base trim 0.73 studs past the rim). It slides away from the blocks while it still
-- holds `keep`, at most `most` studs, then shrinks to clear what is left, never below `least` and never so far that
-- `keep` pokes out. Where both can't be had, the station stays inside. Kept points past `radius` from the pivot are
-- left out. Returns the slide and the radius.
function WalkUp.fitRing(
	radius: number,
	blocks: { Vector2 },
	most: number,
	least: number,
	keep: { Vector2 }?
): (Vector2, number)
	local shift = Vector2.zero
	local limit = math.max(0, most)
	-- only what the ring holds where it starts: a base wider than the ring could never be held, and chasing it would
	-- throw the ring about
	local hold: { Vector2 } = {}
	local given: { Vector2 } = keep or {}
	for _, point in given do
		if point.Magnitude <= radius then
			table.insert(hold, point)
		end
	end
	-- each pass moves by the average of every push (off a block) and pull (back over a kept point), so pushes on
	-- opposite sides cancel instead of bouncing, and a wall and the station's own base meet in the middle
	for _ = 1, 60 do
		local push = Vector2.zero
		local count = 0
		for _, block in blocks do
			local away = block - shift
			local gap = radius + WalkUp.FIT_CLEAR - away.Magnitude
			if gap > 1e-4 and away.Magnitude > 1e-3 then
				push -= away.Unit * gap
				count += 1
			end
		end
		for _, point in hold do
			local away = point - shift
			local over = away.Magnitude - radius
			if over > 1e-4 then
				push += away.Unit * over
				count += 1
			end
		end
		if count == 0 or push.Magnitude / count < 1e-4 then
			break
		end
		shift += push / count
		if shift.Magnitude > limit then
			shift = if limit > 0 then shift.Unit * limit else Vector2.zero
		end
	end
	-- then the station's base wins: pull back until every kept point is inside, if the wall and the base can't both
	-- be had
	for _ = 1, 60 do
		local worst: Vector2? = nil
		local over = 1e-4
		for _, point in hold do
			local beyond = (point - shift).Magnitude - radius
			if beyond > over then
				over = beyond
				worst = point
			end
		end
		if worst == nil then
			break
		end
		shift += ((worst :: Vector2) - shift).Unit * over
	end
	local fitted = radius
	for _, block in blocks do
		local room = (block - shift).Magnitude - WalkUp.FIT_CLEAR
		if room < fitted - 1e-3 then
			fitted = room
		end
	end
	local reach = 0
	for _, point in hold do
		reach = math.max(reach, (point - shift).Magnitude)
	end
	return shift, math.min(radius, math.max(math.min(least, radius), reach, fitted))
end

-- #3114 (Derek2: "remove all \"one click to open menu\" buttons in game for stations etc but make sure they each have
-- a circle area to open menus first"): a station with a floor ring gets no click prompt: its prompt's reach
-- (MaxActivationDistance) goes to SILENT_REACH, so its pill never shows and no key or tap presses it. The prompt
-- itself stays in the model, as its Enabled still says whether the station is open (a flight, a closed stall). A
-- station without a ring keeps its prompt, so nothing is ever left with no way in.
WalkUp.SILENT_REACH = 0

function WalkUp.promptReach(hasRing: boolean, reach: number): number
	return if hasRing then WalkUp.SILENT_REACH else reach
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
