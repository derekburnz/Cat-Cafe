--!strict
-- #2697 part 2 (Derek2 2026-11-09: "after food bowl teleport them infront of cannon and foodbowl for the proper
-- steps"): as the tutorial reaches the bait bowl step (4, after the first table) the player is moved to stand in front
-- of their own bowl, facing it, and as it reaches the cannon step (5, the bowl baited; the cannon's wrap-up hint) in
-- front of the Town Square cannon, facing it. The steps only ever move forward, so each move happens once an account
-- with no save field. Pure; TutorialMoveService does the move, never mid catch, carrying or in flight.
-- #3158 (Derek2 2026-11-10: "the bait bowl animation doesn't even come because its interupted by foodbowl finished
-- instantly into a cannon teleport"): step 5 now comes when the first bowl cat is tamed or let go (BaitService), and
-- the move to the cannon waits CANNON_DELAY seconds after it (a beat since #3640); a player who has
-- walked more than LEFT_STUDS from where they stood by then has moved on by themselves and is left alone.
-- #4674 (Derek 2026-11-16: "then upgrade to tier 2 into park teleport"): under bowl first (shared/TutorialOrder) the
-- rank up to Tier 2 moves the player onto the Park's landing pad, PARK_DELAY seconds after it (the rank up toast first).
-- A rank up happens once a save, so this move does too.
-- #4776 / #4777 (Derek 2026-11-16: "don't teleport them to park make them walk to the cannon after rank up and do it
-- themselves", "instead of teleporting player to the cannon after food bowl have them click the cannon button with dim
-- screen and arrow"): both bowl first moves are off (PARK_MOVE, BOWL_CANNON_MOVE). The paw trail walks the player to a
-- cannon after the rank up, and the HUD's Cannon button is lit after the first bowl cat (UI init, cannon spotlight).

local TutorialMoves = {}

export type Target = "bowl" | "cannon" | "park"

TutorialMoves.BOWL_STEP = 4
TutorialMoves.CANNON_STEP = 5
TutorialMoves.BOWL_STUDS = 4 -- stand this far out from the bowl (BaitService's prompt reaches it)
-- #4097 (Derek 2026-11-14: "teleport them infront of the cannon not directly into the circle area and have them walk
-- in"): this far from the cannon, outside its walk-up ring (at most TownCannonRangeStuds 11.5 less WalkUp.EDGE_SLACK)
-- and the range, so the Cat Cannon window waits until they step in. It was 7, inside the ring, and the window opened
-- over the goal card and the strip by itself.
TutorialMoves.CANNON_STUDS = 15
-- 2 since #3640 (Derek 2026-11-12: "the cannon teleport after claiming the cat from food bowl is a bit delayed"; 6 and
-- 4 before, so the new cat's card, which closes itself after 5 seconds, was gone before the Cat Cannon window could
-- open over it). The client now closes that card as the move lands (UI.closeCatCard), so the move only waits long
-- enough to read which cat it is (Review-QA measured 0.7 to 1.1 seconds of card at a 1 second wait).
TutorialMoves.CANNON_DELAY = 2 -- seconds between the step and the move to the cannon
TutorialMoves.LEFT_STUDS = 30 -- walked this far in that time: no move
TutorialMoves.PARK_DELAY = 2 -- seconds between the rank up to Tier 2 and the move into the Park (#4674)
TutorialMoves.PARK_TIER = 2 -- the rank up that moves the player (its area is the Park)
TutorialMoves.PARK_MOVE = false -- #4776: no move into the Park after the rank up
TutorialMoves.BOWL_CANNON_MOVE = false -- #4777: no move to the cannon after bowl first's first bowl cat
-- The tags the client's step pointers (#2697 part 1) find the targets by: the bowl part in each plot (the owner's
-- plot is the Plot-tagged ancestor with OwnerUserId), and the cannons (CannonId "town" for the Town Square's).
TutorialMoves.BOWL_TAG = "BaitBowl"
TutorialMoves.CANNON_TAG = "CatCannon"

-- Where a step change from `from` to `to` moves the player, or nil. A jump over both (3 to 5: a player who baited the
-- bowl before buying the table) goes to the cannon only.
function TutorialMoves.target(from: number, to: number): Target?
	local target: Target? = nil
	if from < TutorialMoves.CANNON_STEP and to >= TutorialMoves.CANNON_STEP then
		target = "cannon"
	elseif from < TutorialMoves.BOWL_STEP and to >= TutorialMoves.BOWL_STEP then
		target = "bowl"
	end
	return target
end

-- How long after a step change the move to `target` waits: the cannon's waits CANNON_DELAY, the Park's PARK_DELAY,
-- the bowl's none.
function TutorialMoves.delay(target: Target): number
	if target == "cannon" then
		return TutorialMoves.CANNON_DELAY
	elseif target == "park" then
		return TutorialMoves.PARK_DELAY
	end
	return 0
end

-- #4674: whether a rank up to `tier` moves the player into the Park: bowl first on (`bowlFirst`) and the Tier 2 one.
function TutorialMoves.parkAfterRankUp(tier: number, bowlFirst: boolean): boolean
	return TutorialMoves.PARK_MOVE and bowlFirst and tier == TutorialMoves.PARK_TIER
end

-- Whether a player who stood at `from` when the step came and stands at `now` after the wait is still there to be
-- moved (flat distance, so a jump or a step down counts as staying).
function TutorialMoves.stayed(from: Vector3, now: Vector3): boolean
	return Vector3.new(now.X - from.X, 0, now.Z - from.Z).Magnitude <= TutorialMoves.LEFT_STUDS
end

-- Where to stand: `studs` out from `target` on the ground plane, on the side toward `toward`, at `height` above the
-- target's Y, and the flat way that faces `target`. Straight out along -Z when `toward` is right above the target.
function TutorialMoves.standAt(
	target: Vector3,
	toward: Vector3,
	studs: number,
	height: number
): (Vector3, Vector3)
	local flat = Vector3.new(toward.X - target.X, 0, toward.Z - target.Z)
	local out = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
	return Vector3.new(target.X, target.Y + height, target.Z) + out * studs, -out
end

return TutorialMoves
