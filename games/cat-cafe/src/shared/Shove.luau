--!strict
-- Shove, a Tackle since v0.11 (data-model section 10c: the F29 carry bumps, v0.5 F41, v0.5.1 and v0.11 F74). Pure:
-- times are server time, the caller measures positions and looks up areas, so the specs can walk every protection
-- without a world. The code keeps the Shove and Bump names; players see the word Tackle.
--
-- A press lunges TackleLungeStuds straight ahead. It is refused (spending nothing) unless the tackler stands inside a
-- catching area their tier opens, the areas are open, they carry no cat, hold no catch or rescue lock (N85) and are
-- off TackleCooldownSeconds, which starts at the press, hit or miss. For the lunge plus TackleHitGraceSeconds the
-- server hits the first player in reach (inReach) who could be shoved (targetRefusal): in the same area, outside
-- their safe zone (their plot and BumpSafeRadiusStuds round both of their doors), in no minigame, not shoved by
-- anyone for ShoveTargetImmuneSeconds (S45) and not by this tackler for BumpSameTargetSeconds. A hit pushes the
-- target ShoveKnockbackStuds. If the target carries a cat and is BumpGraceSeconds into the carry, BumpChance (1.0
-- since v0.8 F56) knocks it loose: the cat lands where they stood as a Dropped stray with no circles that anyone
-- picks up with PickUpCat, the tackler and the old carrier included, and at dusk it is checked in for that carrier
-- (v0.9, F66).

local Clock = require(script.Parent.Clock)
local Config = require(script.Parent.Config)

local Shove = {}

Shove.RANGE_SLACK = 2 -- studs on top of GrabRangeStuds for a pick up, as for every check on client-owned positions
Shove.HELD_IMMUNE_SECONDS = 3 -- after "It held on tight!" (only when BumpChance is tuned below 1) no knock loose

-- What the server knows when a Tackle press arrives. Times since are nil when it never happened.
export type TackleCheck = {
	carrying: boolean,
	busy: boolean, -- the tackler holds a catch or rescue lock (N85)
	area: string?, -- the catching area the tackler stands in, nil outside every area
	areaUnlocked: boolean, -- the tackler's tier opens `area`
	areasClosed: boolean, -- night: the catching areas are closed (v0.9, F66)
	sinceTackle: number?, -- since this tackler's last press that was not refused
}

-- What the server knows about one player in the lunge's reach.
export type TargetCheck = {
	self: boolean, -- the tackler
	sameArea: boolean, -- standing in the tackler's catching area
	targetBusy: boolean, -- holds a catch or rescue lock
	targetSafe: boolean, -- on its own plot or near one of its doors
	sinceShoveTarget: number?, -- since this tackler last hit this player
	sinceTargetShoved: number?, -- since anyone last hit this player (S45)
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

-- Why this press is refused, in words for the tackler, or nil when it lunges. A refusal spends no cooldown.
function Shove.tackleRefusal(check: TackleCheck): string?
	if check.carrying then
		return "Check in the cat you are carrying first"
	end
	if check.busy then
		return "Finish what you are doing first"
	end
	if check.area == nil then
		return "You can only tackle inside a catching area"
	end
	if not check.areaUnlocked then
		return "This area opens at a higher tier"
	end
	if check.areasClosed then
		return Clock.CLOSED_TEXT
	end
	if check.sinceTackle ~= nil and check.sinceTackle < Config.TackleCooldownSeconds then
		return "Catch your breath before the next tackle"
	end
	return nil
end

-- Why the lunge passes through this player, or nil when it hits them. The words are for Studio and the specs.
function Shove.targetRefusal(check: TargetCheck): string?
	if check.self then
		return "That's you"
	end
	if not check.sameArea then
		return "They're not in this area"
	end
	if check.targetBusy then
		return "They're busy catching a cat"
	end
	if check.targetSafe then
		return "They're safe by their own cafe"
	end
	if check.sinceShoveTarget ~= nil and check.sinceShoveTarget < Config.BumpSameTargetSeconds then
		return "Give them a break"
	end
	if
		check.sinceTargetShoved ~= nil
		and check.sinceTargetShoved < Config.ShoveTargetImmuneSeconds
	then
		return "They were just tackled"
	end
	return nil
end

-- Seconds after the press reaches the server during which the lunge can hit.
function Shove.window(): number
	return Config.TackleLungeSeconds + Config.TackleHitGraceSeconds
end

-- Whether a player standing at `target` is hit by a lunge that started at `start` facing `facing` (flat, unit) with
-- the tackler now at `at`: within TackleHitRadiusStuds plus TackleHitSlackStuds of the tackler and not behind the
-- start. A tackler the server sees farther than TackleLungeStuds plus the slack from the start reaches nobody, so a
-- teleport cannot reach far.
function Shove.inReach(start: Vector3, facing: Vector3, at: Vector3, target: Vector3): boolean
	local slack = Config.TackleHitSlackStuds
	if (at - start).Magnitude > Config.TackleLungeStuds + slack then
		return false
	end
	if (target - at).Magnitude > Config.TackleHitRadiusStuds + slack then
		return false
	end
	local ahead = Vector3.new(target.X - start.X, 0, target.Z - start.Z)
	return ahead:Dot(Vector3.new(facing.X, 0, facing.Z)) >= 0
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
