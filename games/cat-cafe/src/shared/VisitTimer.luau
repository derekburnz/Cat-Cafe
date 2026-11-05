--!strict
-- Special visitors on a random timer (#1135): the rich customer, the Mystery Visitor and the Cat Collector each come
-- to a cafe when its own timer runs out, drawn uniformly from the visitor's min to max seconds, instead of a chance
-- rolled at every check (which gave back-to-back visits and long droughts). A timer counts down only while the cafe
-- could have the visitor (by day, before the dusk banner, earning, with a table, no visit of that kind open), so the
-- night and a closed cafe never use it up. When it runs out the visitor comes if the cafe is ready (the Collector also
-- needs a cat to ask for); if not, the server tries again every Config.VisitRetrySeconds. After a visit a new timer
-- is drawn. Timers live for the session only. Pure: the services hold one per player and call these.

local VisitTimer = {}

-- A fresh timer in seconds from `min` to `max`, `r` a random number in [0, 1).
function VisitTimer.draw(min: number, max: number, r: number): number
	return min + (max - min) * math.clamp(r, 0, 1)
end

-- Counts `left` down by `dt` seconds while `counting`. Returns the new time left (never below 0) and whether the
-- visitor is due now.
function VisitTimer.tick(left: number, dt: number, counting: boolean): (number, boolean)
	if not counting then
		return left, false
	end
	local after = math.max(0, left - math.max(0, dt))
	return after, after <= 0
end

return VisitTimer
