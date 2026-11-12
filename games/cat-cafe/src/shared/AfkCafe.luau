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
--   #3602 (Derek 2026-11-12: "add auto rejoin", "make sure they auto rejoin at their cafe back in the auto rejoin 2x
--     money area"): Roblox disconnects a player after 20 minutes without input. Behind the `autoRejoin` switch
--     (off by default), a resting player with no input for Config.AutoRejoinSeconds is teleported to this same place by the
--     server (AfkCafeService), which starts a new session before that disconnect. They arrive with TeleportData
--     { cafeRest = true }, land at their own front door as every returning player does (CannonService.homeArrival,
--     inside the doorstep zone) and rest again once they have stood there ARRIVAL_STILL_SECONDS, without the
--     AfkCafeSeconds wait. A client can forge that data (a client may teleport itself with any data), which gains it
--     only the skipped wait: it must still stand still in its own cafe.
-- Pure.

local Config = require(script.Parent.Config)

local AfkCafe = {}

AfkCafe.FLAG = "afkCafe"
AfkCafe.ATTRIBUTE = "CafeRest" -- on the Player while resting, for the HUD's chip (Components/RestChip): true when the
-- rest doubles the pay, false when a 2x party already does; nil when not resting
AfkCafe.DOORSTEP_STUDS = 12
AfkCafe.MOVE_STUDS = 1.5 -- a character further than this from where it stood has moved
AfkCafe.TICK_SECONDS = 1
AfkCafe.REJOIN_FLAG = "autoRejoin"
AfkCafe.ARRIVED_ATTRIBUTE = "CafeRestArrived" -- on the Player once the server has taken up the rest again after a
-- rejoin, so the client knows it counts as idle and reports its first input
AfkCafe.ARRIVAL_SECONDS = 90 -- how long after joining an arrival may take the rest up again
AfkCafe.ARRIVAL_STILL_SECONDS = 3 -- standing in the zone this long first (the landing has settled)
AfkCafe.REJOIN_RETRY_SECONDS = 30 -- a teleport that failed is tried again after this

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

-- #3602: whether a resting player is due a rejoin now: no input for `idleSeconds` (Roblox's disconnect counts from
-- the last input, not from the rest's start, and a rest may stop and start again with no input between), last
-- tried at `lastTry` (os.clock, nil when never).
function AfkCafe.rejoinDue(idleSeconds: number, lastTry: number?, now: number): boolean
	if idleSeconds < Config.AutoRejoinSeconds then
		return false
	end
	return lastTry == nil or now - lastTry >= AfkCafe.REJOIN_RETRY_SECONDS
end

-- #3602: what the rejoin teleport carries.
function AfkCafe.teleportData(): { [string]: boolean }
	return { cafeRest = true }
end

-- #3602: whether a join is a rest's rejoin: it came from this same place carrying teleportData's mark.
-- `teleportData` and `sourcePlaceId` are Player:GetJoinData()'s, of any shape.
function AfkCafe.arrivedResting(
	teleportData: unknown,
	sourcePlaceId: unknown,
	placeId: number
): boolean
	if sourcePlaceId ~= placeId or type(teleportData) ~= "table" then
		return false
	end
	return (teleportData :: any).cafeRest == true
end

-- #3602: whether an arrival takes the rest up again at this check: inside its window, in the zone, not busy and
-- still since landing.
function AfkCafe.arrivalRests(
	sinceJoin: number,
	stillSeconds: number,
	inZone: boolean,
	busy: boolean
): boolean
	return sinceJoin <= AfkCafe.ARRIVAL_SECONDS
		and inZone
		and not busy
		and stillSeconds >= AfkCafe.ARRIVAL_STILL_SECONDS
end

return AfkCafe
