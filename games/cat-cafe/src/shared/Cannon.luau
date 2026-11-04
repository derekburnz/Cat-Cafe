--!strict
-- The Cat Cannon's rules (F84, docs/design/cat-cafe/hometown-cannon.md sections 3 and 7), pure so the specs can
-- drive them: why a LaunchCannon is refused, which landing spot a flight takes and where a crowded flight lands off
-- the pad. server/Services/CannonService runs the flights; the beats are Config's CannonLaunchSeconds,
-- CannonTeleportAtSeconds, CloudHopSeconds and CloudHopMoveAtSeconds, which the client's effects read too.

local Clock = require(script.Parent.Clock)
local Config = require(script.Parent.Config)

local Cannon = {}

Cannon.TOWN = "town" -- the Town Square cannon's id, and the destination that lands at its foot
Cannon.RANGE_SLACK = 2 -- studs on top of CannonRangeStuds, as for every check on a client-owned position
Cannon.CARRY_TEXT = "Bring your cat to the camp first"
Cannon.DUSK_TEXT = "Night is coming. The areas close soon."
Cannon.OFF_PAD_STEP = 2 -- studs between the points tried off a full pad
Cannon.DOWN_TEXT = "Get back on your feet first"

-- The refusal for a player a tackle knocked down within TackledDownSeconds, or nil. LaunchCannon uses it, and so do
-- the HUD's Home and Cannon buttons (TravelService), so a downed player cannot hop out of a chase (review N281,
-- hometown-cannon.md section 5). `sinceTackled` is nil when no tackle ever hit the player.
function Cannon.downRefusal(sinceTackled: number?): string?
	if sinceTackled ~= nil and sinceTackled < Config.TackledDownSeconds then
		return Cannon.DOWN_TEXT
	end
	return nil
end

-- What the server knows when a LaunchCannon arrives. Times since are nil when it never happened.
export type LaunchCheck = {
	cannonId: string, -- `town` or a camp's area id, as sent
	destination: string, -- `town` or an area id, as sent
	knownCannon: boolean, -- a built cannon has this id
	knownDestination: boolean, -- `town`, or an area with a camp
	destinationName: string?, -- the area's name, for the tier lock's words
	destinationTier: number?, -- the area's tier; nil for `town`
	tier: number,
	areasOpen: boolean, -- day (F66)
	duskWarning: boolean, -- the last DuskWarningSeconds of the day (section 3a)
	distance: number?, -- from the caller's root to the cannon's pivot; nil without a character
	carrying: boolean,
	busy: boolean, -- holds a catch or rescue lock
	flying: boolean, -- already in a flight or a cloud hop
	sinceTackled: number?, -- since a tackle last hit the caller
	sinceLanded: number?, -- since the caller's last flight ended
}

-- Why this launch is refused, in words for the caller's toast, or nil when it flies (section 7).
function Cannon.launchRefusal(check: LaunchCheck): string?
	if not check.knownCannon then
		return "That cannon isn't here"
	end
	if not check.knownDestination or check.destination == check.cannonId then
		return "The cannon can't fly there"
	end
	if check.flying then
		return "You're already flying"
	end
	if check.carrying then
		return Cannon.CARRY_TEXT
	end
	if check.busy then
		return "Finish what you are doing first"
	end
	local down = Cannon.downRefusal(check.sinceTackled)
	if down ~= nil then
		return down
	end
	if
		check.distance == nil
		or check.distance > Config.World.CannonRangeStuds + Cannon.RANGE_SLACK
	then
		return "Get closer to the cannon"
	end
	if check.destination ~= Cannon.TOWN then
		local needs = check.destinationTier or math.huge
		if check.tier < needs then
			return string.format("%s opens at Tier %d", check.destinationName or "That area", needs)
		end
		if not check.areasOpen then
			return Clock.CLOSED_TEXT
		end
		if check.duskWarning then
			return Cannon.DUSK_TEXT
		end
	end
	if check.sinceLanded ~= nil and check.sinceLanded < Config.CannonCooldownSeconds then
		return "Catch your breath first"
	end
	return nil
end

-- True when no one in `others` stands within LandingClearStuds of `spot` (flat distance).
function Cannon.isClear(spot: Vector3, others: { Vector3 }): boolean
	local clear = Config.World.LandingClearStuds
	for _, other in others do
		local dx, dz = other.X - spot.X, other.Z - spot.Z
		if dx * dx + dz * dz < clear * clear then
			return false
		end
	end
	return true
end

export type Area = { x1: number, z1: number, x2: number, z2: number }

-- Where a flight lands (section 3b): the first of the pad's `spots` (centre, the 4 stud ring, the 7 stud ring)
-- with no one in `others` within LandingClearStuds; with all seventeen taken, the clear point of `area` off the pad
-- (beyond LandingPadRadius from `spots[1]`, 2 studs in from its edges) nearest the pad's centre; with none clear,
-- the pad's centre. The second result is the index of the spot taken, 0 off the pad.
function Cannon.landingSpot(spots: { Vector3 }, others: { Vector3 }, area: Area): (Vector3, number)
	for index, spot in spots do
		if Cannon.isClear(spot, others) then
			return spot, index
		end
	end
	local centre = spots[1]
	local radius = Config.World.LandingPadRadius
	local step = Cannon.OFF_PAD_STEP
	local best: Vector3? = nil
	local bestDistance = math.huge
	local x = area.x1 + step
	while x <= area.x2 - step do
		local z = area.z1 + step
		while z <= area.z2 - step do
			local dx, dz = x - centre.X, z - centre.Z
			local distance = dx * dx + dz * dz
			if distance > radius * radius and distance < bestDistance then
				local point = Vector3.new(x, centre.Y, z)
				if Cannon.isClear(point, others) then
					best, bestDistance = point, distance
				end
			end
			z += step
		end
		x += step
	end
	return best or centre, 0
end

-- True in the last DuskWarningSeconds of a day, given the phase and the server time it ends.
function Cannon.inDuskWarning(phase: string, phaseEndsAt: number, now: number): boolean
	return phase == "day" and phaseEndsAt - now <= Config.DuskWarningSeconds
end

-- The way a flight heads on the ground plane (the character's CannonHeading, Derek 2026-11-03), for the flight's
-- arc: a unit Vector3 from the cannon at `from` toward the landing pad's centre `to`, or `facing` (the barrel's look)
-- flattened when the pad is under the cannon or unknown, or -Z when even that is straight up.
function Cannon.heading(from: Vector3, to: Vector3?, facing: Vector3): Vector3
	local flat = if to ~= nil then Vector3.new(to.X - from.X, 0, to.Z - from.Z) else Vector3.zero
	if flat.Magnitude < 1 then
		flat = Vector3.new(facing.X, 0, facing.Z)
	end
	return if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
end

-- The AimTurn (degrees about Y from the cannon's rest) that points a cannon resting at `fireTurn` along `heading`
-- (#1205): WorldBuilder.cannonSeat then faces fireTurn + AimTurn, the heading, so the client's bend from the barrel's
-- look to CannonHeading is 0 and the flight is one arc with no turn in the air.
function Cannon.aimTurn(heading: Vector3, fireTurn: number): number
	return math.deg(math.atan2(heading.X, heading.Z)) - fireTurn
end

return Cannon
