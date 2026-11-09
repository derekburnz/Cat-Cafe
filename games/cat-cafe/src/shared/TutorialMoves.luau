--!strict
-- #2697 part 2 (Derek2 2026-11-09: "after food bowl teleport them infront of cannon and foodbowl for the proper
-- steps"): as the tutorial reaches the bait bowl step (4, after the first table) the player is moved to stand in front
-- of their own bowl, facing it, and as it reaches the cannon step (5, the bowl baited; the cannon's wrap-up hint) in
-- front of the Town Square cannon, facing it. The steps only ever move forward, so each move happens once an account
-- with no save field. Pure; TutorialMoveService does the move, never mid catch, carrying or in flight.

local TutorialMoves = {}

export type Target = "bowl" | "cannon"

TutorialMoves.BOWL_STEP = 4
TutorialMoves.CANNON_STEP = 5
TutorialMoves.BOWL_STUDS = 4 -- stand this far out from the bowl (BaitService's prompt reaches it)
TutorialMoves.CANNON_STUDS = 7 -- and this far from the cannon, inside Config.World.CannonRangeStuds (10)
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
