--!strict
-- Which cat's speech bubble shows (#1079, docs/design/cat-cafe/cat-bubbles.md section 2). Pure, so the cloud spec
-- runner checks it; Screens/CatBubbles calls `step` four times a second with the stations whose line may show.
--
--   Proximity: a bubble may start within SHOW_STUDS of the player and keeps showing out to HIDE_STUDS, so standing
--   at the edge does not flicker.
--   One at a time: only the nearest station in range shows. A nearer one that may start takes over.
--   Not every time: a bubble that stops showing (walked away, swapped, or hidden by a window, a catch or a carry)
--   keeps that station quiet for REPEAT_SECONDS.
--
-- The three numbers are the spec's CatBubbleShowStuds, CatBubbleHideStuds and CatBubbleRepeatSeconds. They live
-- here and not in shared/Config, since nothing on the server reads them.

local CatBubblesLogic = {}

CatBubblesLogic.SHOW_STUDS = 12
CatBubblesLogic.HIDE_STUDS = 16
CatBubblesLogic.REPEAT_SECONDS = 60
CatBubblesLogic.STEP_SECONDS = 0.25 -- section 3: the distance check runs on a 0.25 s step, not every frame

-- Bubble size in studs: TEXT_STUDS tall text, about CHAR_STUDS per character, PAD_STUDS round it.
CatBubblesLogic.TEXT_STUDS = 0.55
CatBubblesLogic.HEIGHT_STUDS = 1
CatBubblesLogic.CHAR_STUDS = 0.29
CatBubblesLogic.PAD_STUDS = 0.9
-- Closer than FULL_STUDS the bubble shrinks with the distance (to MIN_SCALE), so it never grows to cover the
-- screen when the player walks right up to the cat.
CatBubblesLogic.FULL_STUDS = 8
CatBubblesLogic.MIN_SCALE = 0.35

export type Memory = {
	current: any?, -- the station showing, nil for none
	quiet: { [any]: number }, -- station to the time it may show again
}

function CatBubblesLogic.newMemory(): Memory
	return { current = nil, quiet = {} }
end

-- Whether a line's `when` (Components/CatBubbleLines) holds. `claimed` is ProfileSync's starterCatClaimed (nil
-- until the first sync, which shows nothing so a player who has the Bellhop Cat never sees its line); `here` is
-- whether the dealer's cart is open or the Collector is visiting this player.
function CatBubblesLogic.allowed(when: string, claimed: boolean?, here: boolean): boolean
	if when == "always" then
		return true
	elseif when == "unclaimedBellhop" then
		return claimed == false
	elseif when == "dealerHere" or when == "collectorVisiting" then
		return here
	end
	return false
end

-- One step. keys[1..count] are the stations whose line may show now and distances[1..count] their flat distance
-- to the player in studs (the arrays are reused by the caller; entries past count are ignored). `blocked` is true
-- while no bubble may show. Returns the station to show (nil for none) and the one that just stopped (nil if
-- none). Updates memory in place.
function CatBubblesLogic.step(
	memory: Memory,
	keys: { any },
	distances: { number },
	count: number,
	now: number,
	blocked: boolean
): (any?, any?)
	local current = memory.current
	local quiet = memory.quiet
	local currentDistance: number? = nil
	local nearest: any? = nil
	local nearestDistance = math.huge
	for i = 1, count do
		local key = keys[i]
		local distance = distances[i]
		if key == current then
			currentDistance = distance
		end
		local quietUntil = quiet[key]
		if
			distance <= CatBubblesLogic.SHOW_STUDS
			and distance < nearestDistance
			and (quietUntil == nil or quietUntil <= now)
		then
			nearest, nearestDistance = key, distance
		end
	end

	if current ~= nil and not blocked and currentDistance ~= nil then
		local keep = currentDistance <= CatBubblesLogic.HIDE_STUDS
		if keep and nearest ~= nil and nearest ~= current and nearestDistance < currentDistance then
			keep = false -- a nearer cat takes over
		end
		if keep then
			return current, nil
		end
	end

	local stopped = current
	if stopped ~= nil then
		for key, untilTime in quiet do
			if untilTime <= now then
				quiet[key] = nil
			end
		end
		quiet[stopped] = now + CatBubblesLogic.REPEAT_SECONDS
	end
	if blocked or nearest == stopped then
		memory.current = nil
		return nil, stopped
	end
	memory.current = nearest
	return nearest, stopped
end

-- The bubble's full size in studs for a line.
function CatBubblesLogic.size(text: string): (number, number)
	return #text * CatBubblesLogic.CHAR_STUDS + CatBubblesLogic.PAD_STUDS,
		CatBubblesLogic.HEIGHT_STUDS
end

-- The bubble's scale at `distance` studs, in steps of 0.05 so the size only changes now and then.
function CatBubblesLogic.closeScale(distance: number): number
	local scale = math.clamp(distance / CatBubblesLogic.FULL_STUDS, CatBubblesLogic.MIN_SCALE, 1)
	return math.floor(scale * 20 + 0.5) / 20
end

return CatBubblesLogic
