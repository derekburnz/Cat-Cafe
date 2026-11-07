--!strict
-- The catch strip's window of pips (#2332): a catch can hold 20 to 35 rings now that only the heart bar ends it, and
-- one pip each ran about 800 px wide on a Mythical. The strip shows at most MAX pips: the first MAX at the start,
-- then it slides so the ring after the last one judged stays the rightmost.

local PipWindow = {}

PipWindow.MAX = 10

-- The first and last pip to show for `count` rings when ring `upTo` is the newest one in play (1 before any is
-- judged). Returns 1, 0 when there are none.
function PipWindow.range(count: number, upTo: number, max: number?): (number, number)
	local most = max or PipWindow.MAX
	if count <= 0 then
		return 1, 0
	end
	local last = math.clamp(upTo, math.min(count, most), count)
	return math.max(1, last - most + 1), last
end

return PipWindow
