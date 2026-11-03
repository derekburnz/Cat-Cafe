--!strict
-- The intro cutscene's shots (F72, docs/design/cat-cafe/intro-cutscene.md section 2, reshot for the hometown and the
-- Cat Cannon, F84): when each starts, its caption, and where the camera flies. Studs, y up. Shot 1 follows the
-- player's own plot (`x`, `z` and `side`, -1 for the west row and +1 for the east row, the street toward -side) up
-- to the Town Square's cannon, where your copy climbs in. Shots 2 to 4 and 7 are at the Alleyway's camp: the flight,
-- the catch just past its way out, the carry into the camp and its Index Board. Shot 5 is in your cafe, shot 6 at the
-- other four camps and shots 8 to 10 in the Town Square. The camps are worked out from Config as the server's
-- Layout.camps does (a test checks they match), so the client needs neither the server module nor the camps to have
-- streamed in. The positions are starting points to tune in Studio. Pure apart from Vector3.

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Economy = require(script.Parent.Economy)
local ProfileSchema = require(script.Parent.ProfileSchema)
local Types = require(script.Parent.Types)

local Intro = {}

Intro.SHOTS = 10
-- The intro_cutscene event's version: the shots moved again for the hometown and the cannon (F84), so old and new
-- drop-offs never mix (section 3).
Intro.VERSION = 3
Intro.SKIP_AFTER = 5.0 -- seconds into the first play before Skip can be pressed (its bar fills until then; Derek 00:57); a replay allows it at once
Intro.MAX_CAPTION = 46 -- characters, so a caption fits one line on a phone ("about 45")
Intro.CUT_PUSH = 0.06 -- shot 6: each camp cut pushes this share of the way toward its look point
Intro.STREAM_WAIT = 5 -- seconds the intro waits for the Alleyway's camp to stream in before it starts (section 3)

Intro.AREA = "alley" -- the camp shots 2 to 4 and 7 film, where a new player's first flight goes
Intro.CAMP_CUTS = { "park", "neighbourhood", "woods", "sewer" } -- shot 6, in order

-- The demo stray (section 2a): a Tuxedo, an Alleyway Common whose own role is waiter, so it does not read as a
-- second starter Tabby. It stands at S = g + 10u + 5r through shot 3.
Intro.DEMO_CAT = "tuxedo"
Intro.DEMO_HIDE_RADIUS = 6 -- real strays this close to the stray, the catch or the run are hidden for shots 3 and 4
Intro.STRAY_IN = 10 -- S: studs into the area from the way out
Intro.STRAY_RIGHT = 5 -- and to the right of it, facing into the area
Intro.CATCH_GAP = 3.5 -- you stand this far from the stray, toward the way out, facing it

-- Shot 1, in seconds into the shot: your copy hops from the ladder's foot into the barrel, the barrel turns toward the
-- Alleyway and wiggles, the fuse fizzes from FUSE_AT, BOOM_LEAD before the BOOM that starts shot 2.
Intro.CLIMB_AT = 1.4
Intro.CLIMB_SECONDS = 0.4 -- until Animation-Engineer's hop in lands, a plain hop up to the cannon's Seat
Intro.CLIMB_HEIGHT = 1.5 -- the top of the hop's arc above the straight line
Intro.AIM_FROM = 1.8
Intro.AIM_TO = 2.0 -- turned by the fuse, so the BOOM's smoke ring starts at the turned muzzle
Intro.WIGGLE_TO = 2.3
Intro.WIGGLE_DEGREES = 4
Intro.FUSE_AT = 2.0
Intro.BOOM_LEAD = 0.5 -- Effects/Cannon's fuse fizz before the BOOM
Intro.CARD_LEAD = 0.9 -- UI.cannon.flight's launchAt this far before the BOOM puts its card up 0.7 to 1.1 s into shot 2
Intro.CARD_HOLD = 0.4
-- the town cannon's muzzle and the ball's start without a cannon model (section 2's fallbacks)
Intro.NO_CANNON_MUZZLE = Vector3.new(0, 9, -2)

-- Shot 2, in seconds into the shot (Presets.cannon.introStage's beats): the ball arcs up from the muzzle and goes in
-- a cloud puff ARC_UP studs up at PUFF_AT, the cut to the camp at CUT_AT under the clouds, then the drop from
-- DROP_HEIGHT onto the pad, the landing (with the dust poof) at LAND_AT, a crouch and standing by STAND_AT.
Intro.PUFF_AT = 0.55
Intro.CUT_AT = 0.7
Intro.ARC_UP = 32 -- studs above the ground at the puff
Intro.ARC_OUT = 14 -- studs out along the aim at the puff
Intro.DROP_FROM = 1.25
Intro.LAND_AT = 1.55
Intro.STAND_AT = 2.05 -- Animation-Engineer's hero landing (one knee, then up) takes 0.5 s
Intro.DROP_HEIGHT = 14 -- the root holds at 0 from LAND_AT: the landing crouch is Animation-Engineer's StagedFlight pose

-- Shot 3's demo catch, in seconds into the shot: the ring closes to PERFECT, then the cat hops into your arms.
Intro.DEMO_PERFECT = 1.3
Intro.HOP_FROM = 1.5 -- PERFECT plus 0.2
Intro.HOP_SECONDS = 0.4
Intro.HOP_HEIGHT = 1.5 -- the top of the hop's arc above the straight line

-- Shot 4: a turn toward the way out, the run at the rush speed after a real catch, through the way out to STOP_IN
-- studs inside the camp; the cat checks in as you cross the camp line, and you turn to watch it go.
Intro.TURN_SECONDS = 0.25
Intro.RUN_SPEED = Config.CatchRushWalkSpeed
Intro.STOP_IN = 4
Intro.WATCH_SECONDS = 0.25

-- Shot 5, in seconds into the shot: the cat appears seated at the waiter spot, the job card shows beside it, the
-- outfit pops on, then its rate tag shows.
Intro.JOB_SEATED_AT = 0.2
Intro.JOB_CARD_AT = 0.35
Intro.JOB_DRESS_AT = 0.8
Intro.JOB_RATE_AT = 1.1
Intro.JOB_ROLE = "waiter"
Intro.JOB_SPOT = "waiter_1"

-- The plot-local waiter spot shot 5 films (x across the plot, z toward the back), the same numbers as the server's
-- Layout.cafe.spots (a test checks). FLOOR_Y is the plot floor's top in the world.
Intro.FLOOR_Y = 0.2
Intro.cafe = {
	waiterSpot = { x = -5.5, z = -3.04 }, -- the bigger cafes' (#917)
}

-- Shot 9, in seconds into the shot: dusk, a short night and sunrise on this screen only.
Intro.NIGHT_FROM = 0.35
Intro.NIGHT_TO = 0.95
Intro.SUNRISE_FROM = 1.8
Intro.SUNRISE_TO = 2.3

-- Shot 10 lands this far behind and above the character, looking at its head.
Intro.FOLLOW_BACK = 12
Intro.FOLLOW_UP = 6
Intro.HEAD_UP = 1.5

Intro.CODES_CAPTION = "Free spin every day. Codes at the Codes Cat!"
Intro.SPIN_CAPTION = "Spin the wheel for a free prize every day!" -- shot 8 before a Codes Cat stands in the world

export type Ease = "InOut" | "Out" | "Linear"
export type Plot = { x: number, z: number, side: number, index: number }
-- One camera place: where it is and what it looks at.
export type Key = { position: Vector3, look: Vector3 }
-- One continuous move. `via` bends it through a third place halfway; `area` names the camp a shot 6 cut shows,
-- which is skipped when that camp has not streamed in.
export type Cut = { from: Key, to: Key, via: Key?, seconds: number, title: string?, area: string? }
export type Shot = {
	index: number, -- its number in section 2, which Skip reports, also when the fallback leaves shots out
	starts: number,
	seconds: number,
	caption: string,
	ease: Ease,
	cuts: { Cut },
	you: boolean?, -- shots 1 to 4: your local copy plays the scene and the real character is hidden
	camp: boolean?, -- shots 3, 4 and 7 need the Alleyway's camp and are left out when it has not streamed in
	cannon: boolean?, -- shots 1 and 2: the town cannon is turned toward the Alleyway and uncovered on this screen
	launch: boolean?, -- shot 1: you climb into the cannon, it turns, the fuse fizzes
	flight: boolean?, -- shot 2: the BOOM, the arc, the clouds and the landing on the Alleyway's pad
	catch: boolean?, -- shot 3: the demo ring, then the cat hops into your arms
	run: boolean?, -- shot 4: you run it into the camp, where it checks in
	job: boolean?, -- shot 5: the cat takes the waiter spot in its outfit
	spinWheel: boolean?, -- shot 8: the world wheel turns two spins on this screen
	night: boolean?, -- shot 9: night falls and the sun rises on this screen
	follow: boolean?, -- shot 10: the last cut ends behind the character (Intro.follow), not at `to`
	fallback: Key?, -- shot 6: where it holds when none of its camps has streamed in
}

-- A camp the intro films (Layout.camps, hometown-cannon.md section 4), in the world. `origin` is the middle of the
-- area's gate on the camp line, `u` the flat way from the camp into the area and `r` = u × up, the right hand as you
-- face into it. `wayOut` is g, the middle of the way out the intro uses: the middle of the gate's opening (the
-- Alleyway's one way in since F85). `pad` is P, `basket` K, `board` B with `boardFacing` f, the way its face looks.
export type Camp = {
	area: string,
	turn: number,
	origin: Vector3,
	u: Vector3,
	r: Vector3,
	wayOut: Vector3,
	pad: Vector3,
	basket: Vector3,
	board: Vector3,
	boardFacing: Vector3,
}

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local function key(position: Vector3, look: Vector3): Key
	return { position = position, look = look }
end

-- a × up for a flat `a`: the right hand as you face along it
local function rightOf(a: Vector3): Vector3
	return Vector3.new(-a.Z, 0, a.X)
end
local AREA_FLOOR = 0.1 -- every area's floor top (Layout's floorY)
-- Where Layout puts the pad, the carrier basket and an Index Board in camp space (x across, z toward the area).
local CAMP_PAD_Z = -13
local CAMP_BASKET = { x = -11, z = -13 }
local BOARD_IN = -4
local BOARD_OUT = 4
local ALLEY_BOARD_OUT = 7

-- Where Layout.camps puts `area`'s camp, or nil for an area without one.
function Intro.camp(area: string): Camp?
	local W = Config.World
	local ox: number, oz: number, turn: number, opening: number = 0, 0, 0, 0
	if area == "alley" then
		-- the camp's line across the north end, a half turn like the Park, its one way in under the street arch (F85)
		ox, oz, turn, opening =
			W.AlleyCenterX, W.AlleyCenterZ + W.AlleyNorthZ, 180, W.AlleyWayHalfWidth
	elseif area == "park" then
		-- F85: the long Park's camp opens CampOpeningWidth wide
		ox, oz, turn, opening = 0, W.ParkCenterZ + W.ParkDepth / 2, 180, W.CampOpeningWidth / 2
	elseif area == "neighbourhood" then
		-- F85: the long Neighbourhood's camp opens CampOpeningWidth wide too
		ox, oz, turn, opening =
			W.NeighbourhoodCenterX,
			W.NeighbourhoodCenterZ - W.NeighbourhoodDepth / 2,
			0,
			W.CampOpeningWidth / 2
	elseif area == "woods" then
		-- F85: the long Woods' depth runs along world X, its camp on its east side
		ox, oz, turn, opening =
			W.WoodsCenterX + W.WoodsDepth / 2, W.WoodsCenterZ, -90, W.SideGateHalfWidth
	elseif area == "sewer" then
		-- F85: the long Sewer's depth runs along world X too, its camp on its west side
		ox, oz, turn, opening =
			W.SewerCenterX - W.SewerDepth / 2, W.SewerCenterZ, 90, W.SideGateHalfWidth
	else
		return nil
	end
	local c, s = math.cos(math.rad(turn)), math.sin(math.rad(turn))
	local origin = v(ox, AREA_FLOOR, oz)
	local across = v(c, 0, -s) -- camp-space +X
	local u = v(s, 0, c) -- camp-space +Z
	local function point(x: number, z: number): Vector3
		return origin + across * x + u * z
	end
	-- every board beside the opening, on the left of it, 4 in; the Alleyway's further out, past its low walls (F85)
	local board =
		point(-(opening + if area == "alley" then ALLEY_BOARD_OUT else BOARD_OUT), BOARD_IN)
	return {
		area = area,
		turn = turn,
		origin = origin,
		u = u,
		r = rightOf(u),
		wayOut = origin,
		pad = point(0, CAMP_PAD_Z),
		basket = point(CAMP_BASKET.x, CAMP_BASKET.z),
		board = board,
		boardFacing = -u, -- its front looks back toward the pad
	}
end

local function alleyCamp(): Camp
	return Intro.camp(Intro.AREA) :: Camp
end

-- The turn about Y (degrees) from the town cannon's rest that points it at the Alleyway, as Layout.cannonAim does.
function Intro.cannonAim(): number
	local W = Config.World
	return math.deg(
		math.atan2(W.AlleyCenterX, W.AlleyCenterZ + (W.AlleySouthZ + W.AlleyNorthZ) / 2)
	)
end

-- Where plot `index` (1-based) stands: the same numbers as the server's Layout.plotPlacement (a test checks they
-- match), so the client needs neither the server module nor the plot to have streamed in.
function Intro.plot(index: number): Plot
	local W = Config.World
	local i = index - 1
	local side = if i % 2 == 0 then -1 else 1
	local pair = math.floor(i / 2)
	local north = if pair % 2 == 0 then -1 else 1
	local ring = math.floor(pair / 2)
	local z = north
		* (
			W.TownSquareHalfDepth
			+ W.PlotRowGap
			+ W.PlotWidth / 2
			+ ring * (W.PlotWidth + W.PlotRowGap)
		)
	local x = side * (W.StreetHalfWidth + 2 + W.FrontGardenDepth + 1 + W.PlotDepth / 2)
	return { x = x, z = z, side = side, index = index }
end

-- A plot-local place (x across, y above the floor top, z toward the back) in the world. WorldBuilder turns each plot
-- with CFrame.lookAt toward the street, so plot -Z points at the street and plot +X runs along -Z on the east side
-- (+1), +Z on the west side (-1).
function Intro.plotPoint(plot: Plot, x: number, y: number, z: number): Vector3
	return v(plot.x + plot.side * z, Intro.FLOOR_Y + y, plot.z - plot.side * x)
end

-- S: where the demo stray stands, just past the Alleyway camp's way out (section 2), on the floor.
function Intro.strayPoint(): Vector3
	local camp = alleyCamp()
	return camp.wayOut + camp.u * Intro.STRAY_IN + camp.r * Intro.STRAY_RIGHT
end

-- Where you stand for the catch (shot 3): CATCH_GAP from the stray toward the way out, so the run sets off straight.
function Intro.catchSpot(): Vector3
	local stray = Intro.strayPoint()
	local camp = alleyCamp()
	return stray + (camp.wayOut - stray).Unit * Intro.CATCH_GAP
end

-- Shot 4's run (ground points): from the catch spot through the middle of the way out to STOP_IN inside the camp.
function Intro.runPath(): { Vector3 }
	local camp = alleyCamp()
	return { Intro.catchSpot(), camp.wayOut, camp.wayOut - camp.u * Intro.STOP_IN }
end

-- How long a path takes at `speed` studs a second.
function Intro.pathSeconds(points: { Vector3 }, speed: number): number
	local length = 0
	for i = 2, #points do
		length += (points[i] - points[i - 1]).Magnitude
	end
	return length / speed
end

-- Seconds into shot 4 at which the run crosses the camp line (the check-in) and at which it stops.
function Intro.checkInAt(): number
	local path = Intro.runPath()
	return Intro.TURN_SECONDS + (path[2] - path[1]).Magnitude / Intro.RUN_SPEED
end

function Intro.stopAt(): number
	return Intro.TURN_SECONDS + Intro.pathSeconds(Intro.runPath(), Intro.RUN_SPEED)
end

-- Where a walker is `distance` studs along `points` (held at the end once it has arrived) and the flat way it faces,
-- along the leg it is on.
function Intro.along(points: { Vector3 }, distance: number): (Vector3, Vector3)
	local left = math.max(0, distance)
	local facing = v(0, 0, -1)
	for i = 2, #points do
		local leg = points[i] - points[i - 1]
		local flat = v(leg.X, 0, leg.Z)
		if flat.Magnitude > 1e-6 then
			facing = flat.Unit
		end
		local length = leg.Magnitude
		if left <= length or i == #points then
			local share = if length > 1e-6 then math.min(1, left / length) else 1
			return points[i - 1]:Lerp(points[i], share), facing
		end
		left -= length
	end
	return points[1], facing
end

-- Shot 2's ball, `t` seconds after the BOOM (0 to PUFF_AT): out of `muzzle` along the flat `aim` and up in a high
-- arc, slowing as it rises, ARC_OUT out and ARC_UP above the ground at the puff.
function Intro.arcPoint(muzzle: Vector3, aim: Vector3, t: number): Vector3
	local k = math.clamp(t / Intro.PUFF_AT, 0, 1)
	local flat = v(aim.X, 0, aim.Z)
	local out = if flat.Magnitude > 1e-6 then flat.Unit else v(0, 0, 1)
	local rise = 1 - (1 - k) * (1 - k)
	return muzzle + out * (Intro.ARC_OUT * k) + v(0, (Intro.ARC_UP - muzzle.Y) * rise, 0)
end

-- How far above the pad your copy's feet are `t` seconds into shot 2: falling as if dropped, then 0 from LAND_AT (the
-- crouch and stand by STAND_AT are the StagedFlight "land" pose's, which lowers the body itself). Nil before the drop.
function Intro.dropHeight(t: number): number?
	if t < Intro.DROP_FROM then
		return nil
	elseif t < Intro.LAND_AT then
		local k = (t - Intro.DROP_FROM) / (Intro.LAND_AT - Intro.DROP_FROM)
		return Intro.DROP_HEIGHT * (1 - k * k)
	end
	return 0
end

-- The waiter spot your demo cat takes in shot 5, in the world, on the cafe floor.
function Intro.waiterPoint(plot: Plot): Vector3
	return Intro.plotPoint(plot, Intro.cafe.waiterSpot.x, 0, Intro.cafe.waiterSpot.z)
end

-- What the seated Tuxedo's rate tag reads: a Common waiter in its own favourite role, level 1 with even charm, in a
-- new cafe at Tier 1, worked out as the server does for a real working cat (Economy.catRate times the cafe and tier
-- multipliers).
function Intro.demoRate(): number
	local profile = ProfileSchema.template(0)
	local cat: Types.CatInstance = {
		uid = "intro",
		catId = Intro.DEMO_CAT,
		variant = "base",
		caughtAt = 0,
		spotId = Intro.JOB_SPOT,
		level = 1,
		xp = 0,
		charm = 50,
	}
	return Economy.catRate(cat, profile.tier)
		* Economy.cafeMultiplier(profile)
		* Economy.tierMultiplier(profile)
end

-- The demo cat's name on its rate tag.
function Intro.demoName(): string
	local def = Catalog.getCat(Intro.DEMO_CAT)
	return if def ~= nil then def.name else "Tuxedo"
end

-- A shot 6 cut over `camp`: high over its back wall by its cannon, looking out over the pad and through the way out
-- into the area, pushing CUT_PUSH of the way.
local function campCut(camp: Camp, title: string): Cut
	local g = camp.wayOut
	local position = g - camp.u * 28 + v(0, 24, 0)
	local look = g + camp.u * 10
	return {
		from = key(position, look),
		to = key(position + (look - position) * Intro.CUT_PUSH, look),
		seconds = 0.45,
		title = title,
		area = camp.area,
	}
end

-- The ten shots for this plot. `codesCat` is false until a Codes Cat station stands in the Workspace (F65);
-- `alleyStreamed` false leaves out the shots at the Alleyway's camp (3, 4 and 7) and holds shot 2 in the clouds.
function Intro.shots(plot: Plot, codesCat: boolean, alleyStreamed: boolean?): { Shot }
	local px, pz, s = plot.x, plot.z, plot.side
	local camp = alleyCamp()
	local P, g, u, r = camp.pad, camp.wayOut, camp.u, camp.r
	-- the catch: midway between you and the stray, 1.5 above the floor
	local you, stray = Intro.catchSpot(), Intro.strayPoint()
	local catch = (you + stray) / 2 + v(0, 1.5, 0)
	-- shot 3's camera: square to the line from you to the stray, on the side away from the camp
	local line = (stray - you).Unit
	local side = rightOf(line)
	if side:Dot(u) < 0 then
		side = -side
	end
	-- shot 4's camera: on the line from g + 4u through the basket, past it, inside the camp
	local beyond = g + u * 4
	local toBasket = v(camp.basket.X - beyond.X, 0, camp.basket.Z - beyond.Z).Unit
	local basketLook = (beyond + camp.basket) / 2 + v(0, 2, 0)
	local basketCam = camp.basket + toBasket * 10 + v(0, 6, 0)
	-- shot 5: inside your cafe with its roof on, up the middle aisle past the waiter spot (section 2, #436)
	local function local3(x: number, y: number, z: number): Vector3
		return Intro.plotPoint(plot, x, y, z)
	end
	-- the cafe's half depth: the shots below keep their distance to its front wall as the cafes grow (#917)
	local halfD = Config.World.PlotDepth / 2
	local aisle = local3(-7.3, 2, 7.3)
	-- shot 7: the Alleyway camp's board from its front left
	local B, f = camp.board, camp.boardFacing
	local l = rightOf(f) -- the left hand as you face the board, along -f
	local cannonEnd = key(v(10, 8, -18), v(0, 6, 0)) -- shot 1's last frame, from the square's south east side
	local launchTilt = key(v(10, 7, -18), v(-6, 14, -6))
	local town = v(0, 0, -20) -- shot 9 looks up the whole town from the south
	local stations = v(-28, 4, 0) -- between the Spin Wheel and the Codes Cat
	local shotFrom = key(v(px - (halfD + 16) * s, 9, pz - 6), v(px - (halfD + 0.3) * s, 7, pz))
	local camps: { Cut } = {}
	local titles = { "THE PARK", "THE NEIGHBOURHOOD", "THE WOODS", "THE SEWER" }
	for i, area in Intro.CAMP_CUTS do
		local each = Intro.camp(area)
		if each ~= nil then
			table.insert(camps, campCut(each, titles[i]))
		end
	end
	local streamed = alleyStreamed ~= false
	local all: { Shot } = {
		{
			index = 1,
			starts = 0,
			seconds = 2.5,
			caption = "Fly the Cat Cannon to catch stray cats!",
			ease = "InOut",
			you = true,
			cannon = true,
			launch = true,
			cuts = {
				{
					-- one crane from your cafe front up over Cafe Street and down to the square's south east side
					from = shotFrom,
					via = key(
						v((shotFrom.position.X + 10) / 2, 30, (shotFrom.position.Z - 18) / 2),
						(shotFrom.look + cannonEnd.look) / 2
					),
					to = cannonEnd,
					seconds = 2.5,
				},
			},
		},
		{
			index = 2,
			starts = 0,
			seconds = 2.5,
			caption = "Boom! Every area starts at a safe camp",
			ease = "Out",
			you = true,
			cannon = true,
			flight = true,
			cuts = {
				-- the launch tilt after the ball, held under the clouds until the cut
				{ from = cannonEnd, to = launchTilt, seconds = Intro.PUFF_AT },
				{ from = launchTilt, to = launchTilt, seconds = Intro.CUT_AT - Intro.PUFF_AT },
				if streamed
					then {
						-- behind the pad, toward the camp cannon, looking through the way out into the wild part
						from = key(P - u * 12 - r * 7 + v(0, 8, 0), P + u * 6 + v(0, 4, 0)),
						to = key(P - u * 10 - r * 6 + v(0, 7, 0), P + u * 6 + v(0, 4, 0)),
						seconds = 2.5 - Intro.CUT_AT,
					}
					else { from = launchTilt, to = launchTilt, seconds = 2.5 - Intro.CUT_AT },
			},
		},
		{
			index = 3,
			starts = 0,
			seconds = 2.5,
			caption = "Tap as each circle closes!",
			ease = "Linear",
			you = true,
			camp = true,
			catch = true,
			cuts = {
				{
					from = key(v(catch.X, AREA_FLOOR + 4.5, catch.Z) + side * 9, catch),
					to = key(v(catch.X, AREA_FLOOR + 3.4, catch.Z) + side * 6.5, catch),
					seconds = 2.5,
				},
			},
		},
		{
			index = 4,
			starts = 0,
			seconds = 2,
			caption = "Carry it into the camp to keep it!",
			ease = "Linear",
			you = true,
			camp = true,
			run = true,
			cuts = {
				{
					from = key(basketCam, basketLook),
					to = key(basketCam - toBasket * 2, basketLook),
					seconds = 2,
				},
			},
		},
		{
			index = 5,
			starts = 0,
			seconds = 2.8,
			caption = "Give it a job. Working cats earn money!",
			ease = "InOut",
			job = true,
			cuts = {
				{
					-- inside your cafe with its roof on, just inside the front wall left of the front door
					from = key(local3(-2, 7, -halfD + 1.5), aisle),
					to = key(local3(-2, 6.5, -halfD + 4), aisle),
					seconds = 2.8,
				},
			},
		},
		{
			index = 6,
			starts = 0,
			seconds = 1.8,
			caption = "Rank up to fly to new areas!",
			ease = "Linear",
			fallback = cannonEnd,
			cuts = camps,
		},
		{
			index = 7,
			starts = 0,
			seconds = 2.5,
			caption = "Find all 50 cats for Index rewards",
			ease = "Out",
			camp = true,
			cuts = {
				{
					from = key(B + f * 11 + l * 4 + v(0, 5, 0), B + v(0, 4, 0)),
					to = key(B + f * 7 + l * 2.5 + v(0, 4.5, 0), B + v(0, 4, 0)),
					seconds = 2.5,
				},
			},
		},
		{
			index = 8,
			starts = 0,
			seconds = 2.7,
			caption = if codesCat then Intro.CODES_CAPTION else Intro.SPIN_CAPTION,
			ease = "InOut",
			spinWheel = true,
			cuts = {
				{
					-- down into the Town Square from its south side until the Spin Wheel and the Codes Cat are in frame
					from = key(v(0, 24, -36), v(0, 5, 0)),
					to = key(v(-8, 10, 0), stations),
					seconds = 2.7,
				},
			},
		},
		{
			index = 9,
			starts = 0,
			seconds = 3,
			caption = "Night closes the areas. Fresh cats at sunrise!",
			ease = "Linear",
			night = true,
			cuts = {
				{
					-- high over the welcome arch at the street's south end, the cannon in the middle
					from = key(v(0, 80, -150), town),
					to = key(v(0, 76, -144), town),
					seconds = 3,
				},
			},
		},
		{
			index = 10,
			starts = 0,
			seconds = 2,
			caption = "Your first cat is waiting in the Alleyway!",
			ease = "InOut",
			follow = true,
			cuts = {
				{
					-- `to` becomes the follow point at play time (Intro.follow): every player ends at the spawn
					from = key(v(0, 76, -144), town),
					to = key(v(0, 76, -144), town),
					seconds = 2,
				},
			},
		},
	}
	local shots: { Shot } = {}
	local at = 0
	for _, shot in all do
		if streamed or not shot.camp then
			shot.starts = at
			at += shot.seconds
			table.insert(shots, shot)
		end
	end
	return shots
end

-- The whole intro's length: where the last shot ends.
function Intro.length(shots: { Shot }): number
	local last = shots[#shots]
	return last.starts + last.seconds
end

-- The position in `shots` of the shot showing `elapsed` seconds in, or 0 once the last one has ended.
function Intro.shotAt(shots: { Shot }, elapsed: number): number
	for i = #shots, 1, -1 do
		if elapsed >= shots[i].starts then
			return if elapsed < shots[i].starts + shots[i].seconds then i else 0
		end
	end
	return 1
end

-- Shot 6's cuts that `streamed` says are there, sharing the shot's whole time between them, so a skipped camp gives
-- its time to the others. With none streamed in, the shot holds on its fallback place with the title cards.
function Intro.keepCuts(shot: Shot, streamed: (Cut) -> boolean): { Cut }
	local kept: { Cut } = {}
	for _, cut in shot.cuts do
		if streamed(cut) then
			table.insert(kept, cut)
		end
	end
	local hold = shot.fallback
	if #kept == 0 then
		for _, cut in shot.cuts do
			local copy = table.clone(cut)
			if hold ~= nil then
				copy.from, copy.to = hold, hold
			end
			table.insert(kept, copy)
		end
	end
	local out: { Cut } = {}
	for _, cut in kept do
		local copy = table.clone(cut)
		copy.seconds = shot.seconds / #kept
		table.insert(out, copy)
	end
	return out
end

-- The eased share of a move `t` (0 to 1) of the way through, the curves TweenService calls Quad.
function Intro.ease(kind: Ease, t: number): number
	t = math.clamp(t, 0, 1)
	if kind == "InOut" then
		return if t < 0.5 then 2 * t * t else 1 - (-2 * t + 2) ^ 2 / 2
	elseif kind == "Out" then
		return 1 - (1 - t) ^ 2
	end
	return t
end

-- A point `u` (0 to 1, already eased) of the way from a to c. With b it is the curve that leaves a, passes
-- through b at u = 0.5 and ends at c, so a via point bends the move without a corner.
local function along(a: Vector3, b: Vector3?, c: Vector3, u: number): Vector3
	if b == nil then
		return a:Lerp(c, u)
	end
	local control = b * 2 - (a + c) / 2
	return a * ((1 - u) * (1 - u)) + control * (2 * u * (1 - u)) + c * (u * u)
end

-- Where the camera is and looks `t` (0 to 1) of the way through a cut, with the shot's ease.
function Intro.at(cut: Cut, ease: Ease, t: number): Key
	local u = Intro.ease(ease, t)
	local via = cut.via
	return {
		position = along(
			cut.from.position,
			if via ~= nil then via.position else nil,
			cut.to.position,
			u
		),
		look = along(cut.from.look, if via ~= nil then via.look else nil, cut.to.look, u),
	}
end

-- Shot 10's end: FOLLOW_BACK behind and FOLLOW_UP above a character standing at `root`, looking at its head.
function Intro.follow(rootPosition: Vector3, facing: Vector3): Key
	local flat = Vector3.new(facing.X, 0, facing.Z)
	local back = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
	return {
		position = rootPosition - back * Intro.FOLLOW_BACK + Vector3.new(0, Intro.FOLLOW_UP, 0),
		look = rootPosition + Vector3.new(0, Intro.HEAD_UP, 0),
	}
end

return Intro
