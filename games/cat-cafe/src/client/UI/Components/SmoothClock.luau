--!strict
-- #3359 (Derek2 2026-11-11: "the circle does not feel as smooth and needs smoothing"): server time for drawing, steady
-- from frame to frame. Workspace:GetServerTimeNow() is corrected now and then as the client's clock sync updates, so
-- a circle drawn from it can hop back or forward a few hundredths of a second. This keeps the local os.clock() and an
-- offset to server time, and eases the offset toward each new reading instead of jumping, so time only ever moves
-- forward smoothly. A reading more than SNAP seconds away (the first one, a long hitch) is taken at once.
-- Pure apart from the default clocks, which the specs replace.
--   SmoothClock.new(serverNow?, localNow?) -> clock    clock:now() -> number (server time, smoothed)

local SmoothClock = {}

SmoothClock.EASE = 0.1 -- the share of the gap to the newest reading closed each call
SmoothClock.SNAP = 0.25 -- seconds: a reading this far off is taken at once

export type SmoothClock = {
	now: (self: SmoothClock) -> number,
}

function SmoothClock.new(serverNow: (() -> number)?, localNow: (() -> number)?): SmoothClock
	local server = serverNow or function(): number
		return workspace:GetServerTimeNow()
	end
	local localClock = localNow or os.clock
	local offset: number? = nil
	local last: number? = nil
	local self = {} :: any

	function self.now(_): number
		local here = localClock()
		local target = server() - here
		local current: number? = offset
		if current == nil or math.abs(target - current) > SmoothClock.SNAP then
			offset = target
		else
			offset = current + (target - current) * SmoothClock.EASE
		end
		local t = here + (offset :: number)
		-- never backwards: an easing step can pull the offset down by more than a frame's time passing
		local before: number? = last
		if before ~= nil and t < before then
			t = before
		end
		last = t
		return t
	end

	return self :: SmoothClock
end

return SmoothClock
