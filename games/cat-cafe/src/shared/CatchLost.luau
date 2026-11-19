--!strict
-- #5500 part 1 (Derek 2026-11-19: the catch feels fine on his phone and iPad, so read before any rule change): why a
-- started net catch ended with no cat, so the funnel can tell a bad ring from a lost connection or a cat that left.
-- CatService logs the custom event catch_lost (value the rings judged; reason, device, area) behind the switch
-- `catchLostLog` (LiveFlags.OFF_BY_DEFAULT). Reasons:
--   missed_early, missed_late, missed_none   the first missed ring was pressed early, late or not at all
--   missed                                   no ring missed but the trust bar fell short (Catch v3)
--   too_far                                  walked out of reach before the last ring
--   carrying                                 picked up another cat mid-catch
--   left                                     the player left the server mid-catch
--   gone                                     the cat went mid-catch (night sweep or the area clearing)
--   other_player                             someone else caught it mid-catch
--   pity_lost                                the pity cat was caught on another server first
--   timeout                                  the lock ran out with no result
-- Pure.
--   FLAG, REASONS
--   missReason(forfeit?, firstMiss?) -> string   the reason for a judged catch that failed

local CatchLost = {}

CatchLost.FLAG = "catchLostLog"
CatchLost.EVENT = "catch_lost"
CatchLost.REASONS = table.freeze({
	missed_early = true,
	missed_late = true,
	missed_none = true,
	missed = true,
	too_far = true,
	carrying = true,
	left = true,
	gone = true,
	other_player = true,
	pity_lost = true,
	timeout = true,
}) :: { [string]: boolean }

-- `forfeit` is "too_far" or "carrying" when the catch was given up, else nil; `firstMiss` is Circles.firstMiss.
function CatchLost.missReason(forfeit: string?, firstMiss: string?): string
	if forfeit ~= nil and CatchLost.REASONS[forfeit] then
		return forfeit
	end
	if firstMiss ~= nil and CatchLost.REASONS[firstMiss] then
		return firstMiss
	end
	return "missed"
end

return CatchLost
