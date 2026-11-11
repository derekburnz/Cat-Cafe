--!strict
-- The Cat Cannon's rules (F84, docs/design/cat-cafe/hometown-cannon.md sections 3 and 7), pure so the specs can
-- drive them: why a LaunchCannon is refused, which landing spot a flight takes and where a crowded flight lands off
-- the pad. server/Services/CannonService runs the flights; the beats are Config's CannonLaunchSeconds,
-- CannonTeleportAtSeconds, CloudHopSeconds and CloudHopMoveAtSeconds, which the client's effects read too.

local Clock = require(script.Parent.Clock)
local Config = require(script.Parent.Config)
local Cooldown = require(script.Parent.Cooldown)

local Cannon = {}

Cannon.TOWN = "town" -- the Town Square cannon's id, and the destination that lands at its foot
Cannon.RANGE_SLACK = 2 -- studs on top of CannonRangeStuds, as for every check on a client-owned position
Cannon.CARRY_TEXT = "Bring your cat to the camp first"
Cannon.DUSK_TEXT = "Night is coming. The areas close soon."
Cannon.OFF_PAD_STEP = 2 -- studs between the points tried off a full pad
Cannon.DOWN_TEXT = "Get back on your feet first"
-- #2913, #2915: a first flight into the Alleyway (and the first into the Park) comes down this far short of a waiting
-- stray, on its side toward the landing pad, instead of on the pad 23 to 32 studs away
Cannon.BESIDE_STRAY_STUDS = 7
Cannon.BESIDE_STRAY_RISE = 4 -- studs: a stray this much higher or lower than the pad (a tree top) is skipped

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
		return Cooldown.text(Config.CannonCooldownSeconds - check.sinceLanded) -- #2324
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

-- #2913, #2915: where a first flight lands beside the stray at `stray`: `gap` studs (BESIDE_STRAY_STUDS) from it
-- toward the landing pad's centre `pad`, at the pad's height. nil when the stray is already that close to the pad
-- (the pad does) or stands well above or below it.
function Cannon.besideStray(stray: Vector3, pad: Vector3, gap: number?): Vector3?
	local studs = gap or Cannon.BESIDE_STRAY_STUDS
	if math.abs(stray.Y - pad.Y) > Cannon.BESIDE_STRAY_RISE then
		return nil
	end
	local flat = Vector3.new(pad.X - stray.X, 0, pad.Z - stray.Z)
	if flat.Magnitude <= studs then
		return nil
	end
	local at = stray + flat.Unit * studs
	return Vector3.new(at.X, pad.Y, at.Z)
end

-- #3198 (Derek2 2026-11-10: "now when cannoning into park it lands you over the fence and not in the proper area"):
-- the Park's waiting strays stand past the camp's fence, so the spot beside one was behind a stretch of fence, out in
-- the wild part. A first Park flight now lands beside its stray only where the landing reads as the camp: inside the
-- camp's fence, or in its open gateway. Anywhere else the flight lands on the pad, turned toward the stray.
--   GATEWAY_DEPTH   how far past the fence line, inside the opening, still counts as the gateway
--   GATEWAY_INSET   studs kept from the opening's posts, the fence and the camp's edges
-- `x`, `z` are the spot in camp space (Layout.camps: origin the middle of the opening, +Z into the wild part, X
-- across); `yard` is the camp: half its width, its depth, and half its opening.
Cannon.GATEWAY_DEPTH = 12
Cannon.GATEWAY_INSET = 2
-- The Alleyway keeps #2913's landing beside the beginner's stray wherever it waits: the alley is one open floor from
-- its camp's line on, and that landing is the first catch's.
Cannon.OPEN_AREA = "alley"

export type Yard = { halfAcross: number, depth: number, openingHalfWidth: number }

function Cannon.inCampReach(x: number, z: number, yard: Yard): boolean
	local inset = Cannon.GATEWAY_INSET
	if z <= -inset then
		return z >= -yard.depth + inset and math.abs(x) <= yard.halfAcross - inset
	end
	return z <= Cannon.GATEWAY_DEPTH and math.abs(x) <= yard.openingHalfWidth - inset
end

-- #3072 (Derek2 2026-11-10: "you spawn with camera inside cannon when rejoining put yourself infront of your cafe"):
-- a returning player's first character of a session moves from the Town Square spawn to the street outside their own
-- front door, facing it (CannonService.homeArrival), and their camera starts behind them (CannonController).
--   HOME_WAIT_SECONDS   how long the move waits for the save and the cafe to be ready after the character spawns
--   HOME_SPAWN_STUDS    a character further than this from the spawn has walked off already and is left alone
--   HOME_ATTRIBUTE      the Player attribute the server sets to the landing's position once it has moved them
--   HOME_CAMERA         how far behind and above the character the camera starts, and how high it looks
Cannon.HOME_WAIT_SECONDS = 20
Cannon.HOME_SPAWN_STUDS = 10
Cannon.HOME_ATTRIBUTE = "HomeArrival"
Cannon.HOME_CAMERA = table.freeze({ back = 14, up = 7, look = 2 })

-- Whether a join starts at home. A player whose intro is still to play stays at the Town Square, where the intro
-- starts (`introPlays`: Config.IntroAutoPlay), and so does one who has not caught their first cat yet
-- (`tutorialStep` below `doneStep`, Config.TutorialGuaranteedStrayStep): the walk-through leads from the cannon.
function Cannon.joinsAtHome(
	introSeen: boolean?,
	introPlays: boolean,
	tutorialStep: number?,
	doneStep: number
): boolean
	if introPlays and introSeen ~= true then
		return false
	end
	return (tutorialStep or 0) >= doneStep
end

-- Whether a character at `at` still stands at the spawn `spawn` (flat distance), so moving it surprises nobody.
function Cannon.stillAtSpawn(at: Vector3, spawn: Vector3): boolean
	local dx, dz = at.X - spawn.X, at.Z - spawn.Z
	return math.sqrt(dx * dx + dz * dz) <= Cannon.HOME_SPAWN_STUDS
end

-- The camera's place and what it looks at for a character whose root is at `at`, facing `facing`: behind and above
-- it, looking the way it faces. The game's camera starts looking north whichever way a character spawns, which at the
-- Town Square put it inside the Cat Cannon.
function Cannon.cameraBehind(at: Vector3, facing: Vector3): (Vector3, Vector3)
	local flat = Vector3.new(facing.X, 0, facing.Z)
	local look = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
	local focus = at + Vector3.new(0, Cannon.HOME_CAMERA.look, 0)
	local from = at - look * Cannon.HOME_CAMERA.back + Vector3.new(0, Cannon.HOME_CAMERA.up, 0)
	return from, focus
end

return Cannon
