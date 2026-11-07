--!strict
-- #2214 add-on (Derek2 11-07: "show exclamation mark when someone is doing a rescue also"): what the "!" over a rescue
-- spot (Components/RescueBang) says, pure so the cloud specs check it. The server's RescueService sets the spot's
-- LockedBy (the rescuer's UserId, 0 when free) and HelpedBy (a Team Rescue helper's, F92).
--   line(lockedBy, helpedBy, me)   the bubble's words, or nil when nobody is rescuing there or this player is the
--                                  rescuer or the helper (they have the bar already)

local RescueBangLogic = {}

RescueBangLogic.OPEN = "🆘 Rescue on! Come help"
RescueBangLogic.FULL = "🐾 Team Rescue on!"

function RescueBangLogic.line(lockedBy: unknown, helpedBy: unknown, me: number): string?
	local rescuer = if type(lockedBy) == "number" then lockedBy else 0
	local helper = if type(helpedBy) == "number" then helpedBy else 0
	if rescuer == 0 or rescuer == me or (helper ~= 0 and helper == me) then
		return nil
	end
	return if helper ~= 0 then RescueBangLogic.FULL else RescueBangLogic.OPEN
end

return RescueBangLogic
