--!strict
-- #2880 (Derek2 11-09: "the pop ups for things like hows the game and invite friends are too early and too often"):
-- one pace for every slide-in ask card (the "How is it so far?" faces, the invite card and nudge, the Notify Me ask).
-- None shows in a session's first FIRST_SECONDS, and after one shows the next waits GAP_SECONDS, so a new player plays
-- before being asked anything and never gets two asks back to back. An ask held back is offered again later by
-- whoever timed it. Pure, so the cloud specs check it.
--   allow(played, lastAt) -> boolean   played: seconds of this session; lastAt: the session second the last ask showed

local AskPacing = {}

AskPacing.FIRST_SECONDS = 8 * 60
AskPacing.GAP_SECONDS = 10 * 60

function AskPacing.allow(played: number, lastAt: number?): boolean
	if played < AskPacing.FIRST_SECONDS then
		return false
	end
	return lastAt == nil or played - lastAt >= AskPacing.GAP_SECONDS
end

return AskPacing
