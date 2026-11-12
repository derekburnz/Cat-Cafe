--!strict
-- #3573 (Derek 2026-11-12: "2x rewards while afk in cafe and cats earn offline ... so we can have people afk the game
-- more"): resting in your own cafe. A player who stands still with no input for Config.AfkCafeSeconds inside their own
-- cafe, or on its doorstep (within DOORSTEP_STUDS of where a trip home lands), is resting, and while resting their
-- cats' cafe pay is doubled. Behind the `afkCafe` switch (LiveFlags, off by default).
--   The 2x sits in the Cafe Event's money slot (Economy.settle): the pay runs at the larger of the event's money and
--     Config.AfkCafeMoney, so it never goes above Config.EventMoneyMax and adds nothing during a 2x party. Tips,
--     rich tips, the Tip Jar, golden fish and offline pay are untouched (they never read it).
--   The client reports only that it has had no input (AfkIdle); the server decides: the zone, a character that has
--     not moved, nothing carried, no trade (AfkCafeService).
--   Roblox's own disconnect after 20 minutes without input stays as it is (Derek 2026-11-12: no automatic rejoin),
--     so no words here say or suggest a player will not be disconnected.
-- Pure.

local Config = require(script.Parent.Config)

local AfkCafe = {}

AfkCafe.FLAG = "afkCafe"
AfkCafe.ATTRIBUTE = "CafeRest" -- on the Player while resting, for the HUD's chip (Components/RestChip): true when the
-- rest doubles the pay, false when a 2x party already does; nil when not resting
AfkCafe.DOORSTEP_STUDS = 12
AfkCafe.MOVE_STUDS = 1.5 -- a character further than this from where it stood has moved
AfkCafe.TICK_SECONDS = 1

-- The once a visit line (design section 5.2) and the line on coming back (5.3).
AfkCafe.LINE =
	"Rest here any time. Cats earn 2x while you're AFK in your cafe, and they keep earning while you're offline."
-- During a 2x party the rest adds nothing, so the line does not say 2x (as the chip, afk-cafe.md).
AfkCafe.PARTY_LINE =
	"Rest here any time. Your cats keep earning while you're AFK in your cafe and while you're offline."

function AfkCafe.line(doubled: boolean): string
	return if doubled then AfkCafe.LINE else AfkCafe.PARTY_LINE
end

function AfkCafe.welcome(amount: string): string
	return string.format("Welcome back! Your cats earned %s while you rested 💤", amount)
end

-- Whether a character at `at` (the plot's own space: X along the width, Z along the depth) is in the rest zone:
-- inside the cafe's footprint, or within DOORSTEP_STUDS of `doorstep`, the home landing in the same space.
function AfkCafe.inZone(at: Vector3, doorstep: Vector3?, width: number, depth: number): boolean
	if at.Y <= -4 or at.Y >= 30 then
		return false
	end
	if math.abs(at.X) <= width / 2 and math.abs(at.Z) <= depth / 2 then
		return true
	end
	if doorstep ~= nil then
		local dx, dz = at.X - doorstep.X, at.Z - doorstep.Z
		return dx * dx + dz * dz <= AfkCafe.DOORSTEP_STUDS * AfkCafe.DOORSTEP_STUDS
	end
	return false
end

-- Whether the player is resting: the client says idle, the server has seen the character still for the whole wait,
-- it stands in the zone and the player is not busy (carrying a cat or trading).
function AfkCafe.resting(
	idle: boolean,
	stillSeconds: number,
	inZone: boolean,
	busy: boolean
): boolean
	return idle and inZone and not busy and stillSeconds >= Config.AfkCafeSeconds
end

-- The money multiplier on a player's cafe pay: the running event's, or the rest's when that is larger; never above
-- EventMoneyMax.
function AfkCafe.money(eventMoney: number, resting: boolean): number
	local rest = if resting then Config.AfkCafeMoney else 1
	return math.clamp(math.max(eventMoney, rest), 1, Config.EventMoneyMax)
end

-- Whether the rest really doubles the pay right now (false in a 2x party): the chip names "2x" only while it is true.
function AfkCafe.doubled(eventMoney: number): boolean
	return AfkCafe.money(eventMoney, true) > eventMoney
end

return AfkCafe
