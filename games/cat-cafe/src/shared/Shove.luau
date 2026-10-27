--!strict
-- Shove (data-model section 10c: the F29 carry bumps, v0.5 F41 and v0.5.1). Pure: times are server time, the caller
-- measures positions and looks up areas, so the specs can walk every protection without a world. The remote and the
-- constants keep their Bump names; players see the word Shove.
--
-- Any player may shove another while both stand inside one catching area the shover has unlocked, within
-- BumpRangeStuds, outside the target's safe zone (its plot and BumpSafeRadiusStuds round both of its doors), with
-- neither holding a catch or rescue lock (N85). The shover waits BumpCooldownSeconds between shoves and
-- BumpSameTargetSeconds before shoving the same player again; nobody may shove a player for
-- ShoveTargetImmuneSeconds after a shove lands on them (S45). A landed shove pushes the target ShoveKnockbackStuds.
-- If the target carries a cat, is not immune and is BumpGraceSeconds into the carry, BumpChance knocks it loose:
-- the cat drops as a stray only its old carrier can catch for DropOwnerPrioritySeconds, the shover never can, and
-- it survives a night wave that starts within DroppedMinStaySeconds of the drop.

local Config = require(script.Parent.Config)

local Shove = {}

Shove.RANGE_SLACK = 2 -- studs on top of BumpRangeStuds, as for every range check on client-owned positions
Shove.HELD_IMMUNE_SECONDS = 3 -- after "It held on tight!" the carrier cannot be knocked loose (section 10c)
Shove.SCURRY_MIN = 6 -- a knocked-loose cat scurries this far, rolled, from where it dropped
Shove.SCURRY_MAX = 10

-- What the server knows when a Bump arrives. Times since are nil when it never happened.
export type Check = {
	self: boolean, -- the target is the shover
	shoverCarrying: boolean,
	shoverBusy: boolean, -- the shover holds a catch or rescue lock (N85)
	shoverArea: string?, -- the catching area each stands in, nil outside every area
	targetArea: string?,
	areaUnlocked: boolean, -- the shover's tier opens shoverArea
	distance: number?, -- nil when either has no character
	targetBusy: boolean, -- the target holds a catch or rescue lock
	targetSafe: boolean, -- on its own plot or near one of its doors
	sinceShove: number?, -- since this shover's last landed shove
	sinceShoveTarget: number?, -- since this shover last shoved this target
	sinceTargetShoved: number?, -- since anyone last shoved this target (S45)
}

-- A shove on a carrier who can be knocked loose: the cat drops, or "It held on tight!".
export type KnockResult = "loose" | "held"

-- The carry a knock-loose roll looks at.
export type CarryState = {
	startedAt: number, -- server time the carry began
	immune: boolean, -- the whole carry: a re-catch of a knocked-loose cat
	immuneUntil: number, -- after a held roll
}

-- The server's record of a knocked-loose cat (S25). `shover` is 0 when nobody did it (Studio's hook).
export type Drop = {
	owner: number,
	shover: number,
	droppedAt: number,
	ownerUntil: number,
}

-- Why this shove is refused, in words for the shover, or nil when it lands. Checked in the order of section 10c.
function Shove.refusal(check: Check): string?
	if check.self then
		return "You can't shove yourself"
	end
	if check.shoverCarrying then
		return "Check in the cat you are carrying first"
	end
	if check.shoverBusy then
		return "Finish what you are doing first"
	end
	if check.shoverArea == nil or check.shoverArea ~= check.targetArea then
		return "You can only shove inside a catching area"
	end
	if not check.areaUnlocked then
		return "This area opens at a higher tier"
	end
	if check.distance == nil or check.distance > Config.BumpRangeStuds + Shove.RANGE_SLACK then
		return "Too far away"
	end
	if check.targetBusy then
		return "They're busy catching a cat"
	end
	if check.targetSafe then
		return "They're safe by their own cafe"
	end
	if check.sinceShove ~= nil and check.sinceShove < Config.BumpCooldownSeconds then
		return "Catch your breath before the next shove"
	end
	if check.sinceShoveTarget ~= nil and check.sinceShoveTarget < Config.BumpSameTargetSeconds then
		return "Give them a break"
	end
	if
		check.sinceTargetShoved ~= nil
		and check.sinceTargetShoved < Config.ShoveTargetImmuneSeconds
	then
		return "They were just shoved"
	end
	return nil
end

-- True when a shove on this carrier rolls BumpChance: carrying, not immune, past the grace.
function Shove.canKnockLoose(carry: CarryState?, now: number): boolean
	if carry == nil then
		return false
	end
	return not carry.immune
		and now >= carry.immuneUntil
		and now - carry.startedAt >= Config.BumpGraceSeconds
end

-- roll is in [0, 1).
function Shove.landsLoose(roll: number): boolean
	return roll < Config.BumpChance
end

function Shove.scurryStuds(roll: number): number
	return Shove.SCURRY_MIN + math.clamp(roll, 0, 1) * (Shove.SCURRY_MAX - Shove.SCURRY_MIN)
end

-- The flat unit direction from the shover to the target, or `fallback` when they stand on top of each other.
function Shove.direction(shover: Vector3, target: Vector3, fallback: Vector3): Vector3
	local flat = Vector3.new(target.X - shover.X, 0, target.Z - shover.Z)
	if flat.Magnitude < 0.05 then
		return fallback
	end
	return flat.Unit
end

function Shove.newDrop(owner: number, shover: number, now: number): Drop
	return {
		owner = owner,
		shover = shover,
		droppedAt = now,
		ownerUntil = now + Config.DropOwnerPrioritySeconds,
	}
end

-- Why `userId` may not start a catch on a knocked-loose cat, and whether its prompt should stay (retry), or nil.
function Shove.grabRefusal(drop: Drop?, userId: number, now: number): (string?, boolean)
	if drop == nil then
		return nil, true
	end
	if drop.shover ~= 0 and userId == drop.shover then
		return "You knocked this one loose, so it won't come to you", false
	end
	if userId ~= drop.owner and now < drop.ownerUntil then
		return "Its owner gets the first try", true
	end
	return nil, true
end

-- A missed knocked-loose cat sits still while its owner window runs (N86); after that it sprints like any stray.
function Shove.sprintsAfterMiss(drop: Drop?, now: number): boolean
	return drop == nil or now >= drop.ownerUntil
end

-- A night wave clears last night's strays, but a knocked-loose cat only once DroppedMinStaySeconds have passed (S32).
function Shove.leavesWithWave(drop: Drop?, now: number): boolean
	return drop == nil or now - drop.droppedAt >= Config.DroppedMinStaySeconds
end

return Shove
