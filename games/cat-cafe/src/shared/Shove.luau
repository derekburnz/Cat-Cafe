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
-- If the target carries a cat and is BumpGraceSeconds into the carry, BumpChance (1.0 since v0.8 F56) knocks it
-- loose: the cat lands where they stood as a Dropped stray with no circles that anyone picks up with PickUpCat,
-- the shover and the old carrier included, and at dusk it is checked in for that carrier (v0.9, F66).

local Clock = require(script.Parent.Clock)
local Config = require(script.Parent.Config)

local Shove = {}

Shove.RANGE_SLACK = 2 -- studs on top of BumpRangeStuds, as for every range check on client-owned positions
Shove.HELD_IMMUNE_SECONDS = 3 -- after "It held on tight!" (only when BumpChance is tuned below 1) no knock loose

-- What the server knows when a Bump arrives. Times since are nil when it never happened.
export type Check = {
	self: boolean, -- the target is the shover
	shoverCarrying: boolean,
	shoverBusy: boolean, -- the shover holds a catch or rescue lock (N85)
	shoverArea: string?, -- the catching area each stands in, nil outside every area
	targetArea: string?,
	areaUnlocked: boolean, -- the shover's tier opens shoverArea
	areasClosed: boolean, -- night: the catching areas are closed (v0.9, F66)
	distance: number?, -- nil when either has no character
	targetBusy: boolean, -- the target holds a catch or rescue lock
	targetSafe: boolean, -- on its own plot or near one of its doors
	sinceShove: number?, -- since this shover's last landed shove
	sinceShoveTarget: number?, -- since this shover last shoved this target
	sinceTargetShoved: number?, -- since anyone last shoved this target (S45)
}

-- A shove on a carrier who can be knocked loose: the cat drops, or "It held on tight!" (BumpChance below 1 only).
export type KnockResult = "loose" | "held"

-- The carry a knock-loose roll looks at. A picked-up cat's carry is like any other (v0.8 F56: no BumpImmune).
export type CarryState = {
	startedAt: number, -- server time the carry began
	immuneUntil: number, -- after a held roll
}

-- The server's record of a Dropped stray (S25): its last carrier, who gets it at dusk, and the shover, for the
-- drop_outcome analytics only. `shover` is 0 for a Drop (or Studio's hook).
export type Drop = {
	owner: number,
	shover: number,
	droppedAt: number,
}

-- What the server knows when a PickUpCat arrives (v0.8 F56, section 10c).
export type PickUpCheck = {
	dropped: boolean, -- the stray is Dropped
	carrying: boolean, -- the caller carries a cat
	busy: boolean, -- the caller holds a catch or rescue lock
	areaUnlocked: boolean, -- the caller's tier opens the stray's area
	areasClosed: boolean, -- night (v0.9, F66)
	distance: number?, -- from the caller to the cat; nil without a character
	sinceGrab: number?, -- since the caller last started a catch or a pick up
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
	if check.areasClosed then
		return Clock.CLOSED_TEXT
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

-- True when a shove on this carrier rolls BumpChance: carrying, past the grace and any held immunity.
function Shove.canKnockLoose(carry: CarryState?, now: number): boolean
	if carry == nil then
		return false
	end
	return now >= carry.immuneUntil and now - carry.startedAt >= Config.BumpGraceSeconds
end

-- roll is in [0, 1).
function Shove.landsLoose(roll: number): boolean
	return roll < Config.BumpChance
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
	}
end

-- Why this PickUpCat is refused, in words for the caller, or nil when it starts the carry. Anyone may pick up a
-- Dropped stray, the shover and the old carrier included, with no owner window (v0.8 F56, section 10c).
function Shove.pickUpRefusal(check: PickUpCheck): string?
	if not check.dropped then
		return "Catch this one with the circles"
	end
	if check.carrying then
		return "Check in the cat you are carrying first"
	end
	if check.busy then
		return "Finish what you are doing first"
	end
	if not check.areaUnlocked then
		return "This area opens at a higher tier"
	end
	if check.areasClosed then
		return Clock.CLOSED_TEXT
	end
	if check.distance == nil or check.distance > Config.GrabRangeStuds + Shove.RANGE_SLACK then
		return "Too far away"
	end
	if check.sinceGrab ~= nil and check.sinceGrab < Config.GrabCooldownSeconds then
		return "Give it a moment"
	end
	return nil
end

return Shove
