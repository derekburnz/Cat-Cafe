--!strict
-- Walk-up windows (#2398, Derek2 2026-11-08: "similar to how codes stand works change all the tap to opens to just if
-- you walk near the menu's pop up for cannon/day cart/fish market/spin area", and "add the night market area (only
-- when its night)"): walking up to a station opens its window and walking away closes it, as the Codes Cat's circle
-- does (shared/Codes.circleOpen). The stations' prompts stay, so a window closed by hand opens again with a press.
--   LEAVE_EXTRA                       studs past a station's radius before it counts as left, so an edge never flickers
--   RADIUS_SHARE                      the share of a prompt's MaxActivationDistance that opens its window
--   inside(was, distance, radius)     whether the character counts as at the station now
--   step(state, stations, blocked, current)  one look: the station to open (or nil) and whether to close the window
-- Pure, so the cloud spec runner checks it; Controllers/WalkUpController measures and opens.

local WalkUp = {}

WalkUp.LEAVE_EXTRA = 2
-- The prompt's pill shows from its MaxActivationDistance; the window waits until the player is most of the way in.
WalkUp.RADIUS_SHARE = 0.75

-- One station this look: its key, the window it opens (the UI's modal name), the flat studs from the character
-- (nil while streamed out or its prompt is off) and its radius.
export type Station = { key: string, window: string, distance: number?, radius: number }

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
