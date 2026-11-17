--!strict
-- Server memory grows about 97% over a server's life (Creator Hub "Server memory by age", Nov 17). The place does not
-- turn on Workspace.PlayerCharacterDestroyBehavior (a Properties-window setting no script can set), so a character
-- that respawns and a player who leaves are only taken out of the game, not destroyed: every connection made to them
-- or their parts keeps them in memory for the server's life. With the leaveCleanup switch on (the default) the server
-- destroys an old character CHARACTER_SECONDS after it is replaced or its player leaves, and the Player object
-- PLAYER_SECONDS after the player leaves, well after the save is released (DataService releases at once on leave).
-- Off brings back the old behaviour. Pure.

local LeaveCleanup = {}

LeaveCleanup.FLAG = "leaveCleanup" -- shared/LiveFlags, on unless switched off
LeaveCleanup.CHARACTER_SECONDS = 5
LeaveCleanup.PLAYER_SECONDS = 30

-- Whether an old character may go: it has left the game (no parent) and is not the player's character any more.
function LeaveCleanup.characterGone(parent: Instance?, isCurrent: boolean): boolean
	return parent == nil and not isCurrent
end

return LeaveCleanup
