--!strict
-- The intro cutscene's shots (F72, docs/design/cat-cafe/intro-cutscene.md section 2): when each starts, its caption,
-- and where the camera flies, worked out from the player's own plot. Studs, y up. Shots 1 to 4 follow the plot
-- (`x`, `z` and `side`, -1 for the west row and +1 for the east row, the street toward -side): you catch the demo
-- Tuxedo behind your cafe, carry it home and give it the waiter job (Derek 2026-10-28 00:57). The rest follow the
-- Config.World points they look at (town layout v3, F76: intro-cutscene.md section 2b), so a layout change moves
-- them too. The positions are starting points to tune in Studio. Pure apart from Vector3.

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Economy = require(script.Parent.Economy)
local ProfileSchema = require(script.Parent.ProfileSchema)
local Types = require(script.Parent.Types)

local Intro = {}

Intro.SHOTS = 10
-- The intro_cutscene event's version: the shot numbers moved when the carry and the job came in (2026-10-28), so
-- old and new drop-offs never mix.
Intro.VERSION = 2
Intro.SKIP_AFTER = 5.0 -- seconds into the first play before Skip can be pressed (its bar fills until then; Derek 00:57); a replay allows it at once
Intro.MAX_CAPTION = 46 -- characters, so a caption fits one line on a phone ("about 45"; shot 9's is 46)
Intro.CUT_PUSH = 0.06 -- shot 6: each area cut pushes this share of the way toward its look point

-- The demo stray (section 2a): a Tuxedo, an Alleyway Common whose own role is waiter, so it does not read as a
-- second starter Tabby. It waits at the tutorial stray point through shots 1 and 2.
Intro.DEMO_CAT = "tuxedo"
Intro.DEMO_HIDE_RADIUS = 4 -- real strays this close to the demo cat are hidden for shots 1 and 2
Intro.CATCH_GAP = 3.5 -- you stand this far from the stray, on the line to your yard gate, facing it

-- Shot 2's demo catch, in seconds into the shot: the ring closes to PERFECT, then the cat hops into your arms.
Intro.DEMO_PERFECT = 1.3
Intro.HOP_FROM = 1.5 -- PERFECT plus 0.2
Intro.HOP_SECONDS = 0.4
Intro.HOP_HEIGHT = 1.5 -- the top of the hop's arc above the straight line

-- Shot 3: a turn toward the yard gate, then the run home at the rush speed after a real catch.
Intro.TURN_SECONDS = 0.25
Intro.RUN_SPEED = Config.CatchRushWalkSpeed

-- Shot 4, in seconds into the shot: you step in from the back door to the intro spot, the job card shows beside the
-- waiter spot, the cat leaves your arms and sits there in its outfit, then its rate tag shows.
Intro.STEP_IN_SECONDS = 0.35
Intro.JOB_CARD_AT = 0.35
Intro.JOB_SEATED_AT = 0.8
Intro.JOB_RATE_AT = 1.1
Intro.JOB_ROLE = "waiter"
Intro.JOB_SPOT = "waiter_1"

-- The plot-local places shots 2 to 4 use (x across the plot, z toward the back), the same numbers as the server's
-- Layout.plot (a test checks): the back door in the back wall, the middle of the yard gate in the yard's back fence,
-- the intro spot just inside the back door and the waiter spot. FLOOR_Y is the plot floor's top in the world.
Intro.FLOOR_Y = 0.2
Intro.cafe = {
	backDoor = { x = -8, z = 14 },
	yardGate = { x = -8, z = 25 },
	introSpot = { x = -8, z = 11 },
	waiterSpot = { x = -4.5, z = -2.5 },
}

-- Shot 9, in seconds into the shot: dusk, a short night and sunrise on this screen only.
Intro.NIGHT_FROM = 0.35
Intro.NIGHT_TO = 0.95
Intro.SUNRISE_FROM = 1.8
Intro.SUNRISE_TO = 2.3
Intro.STRAYS_OUT_FROM = 0.45 -- the back alleys' strays fade out
Intro.STRAYS_OUT_TO = 0.85
Intro.SUNRISE_STRAYS_AT = 2.1 -- fresh local strays pop in from here
Intro.SUNRISE_STRAYS = 10
Intro.SUNRISE_STRAY_GAP = 0.04 -- seconds between pops
Intro.STRAY_AREA = "alley" -- shot 9's strays that fade out and pop back in are this area's (v3.1: the back alleys)

-- Shot 10 lands this far behind and above the character, looking at its head.
Intro.FOLLOW_BACK = 12
Intro.FOLLOW_UP = 6
Intro.HEAD_UP = 1.5

Intro.CODES_CAPTION = "Free spin every day. Codes at the Codes Cat!"
Intro.SPIN_CAPTION = "Spin the wheel for a free prize every day!" -- shot 8 before a Codes Cat stands in the world

export type Ease = "InOut" | "Out" | "Linear"
export type Plot = { x: number, z: number, side: number }
-- One camera place: where it is and what it looks at.
export type Key = { position: Vector3, look: Vector3 }
-- One continuous move. `via` bends it through a third place halfway; `area` names the area a shot 6 cut shows,
-- which is skipped when that area has not streamed in.
export type Cut = { from: Key, to: Key, via: Key?, seconds: number, title: string?, area: string? }
export type Shot = {
	index: number,
	starts: number,
	seconds: number,
	caption: string,
	ease: Ease,
	cuts: { Cut },
	you: boolean?, -- shots 1 to 4: your local copy plays the scene and the real character is hidden
	demo: boolean?, -- shots 1 and 2: the demo cat waits at the tutorial stray point
	catch: boolean?, -- shot 2: the demo ring, then the cat hops into your arms
	run: boolean?, -- shot 3: you run it home through the yard gate and in at the back door
	job: boolean?, -- shot 4: you step in, the job card shows and the cat takes the waiter spot
	spinWheel: boolean?, -- shot 8: the world wheel turns two spins on this screen
	night: boolean?, -- shot 9: night falls and the sun rises on this screen
	follow: boolean?, -- shot 10: the last cut ends behind the character (Intro.follow), not at `to`
}

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local function key(position: Vector3, look: Vector3): Key
	return { position = position, look = look }
end

-- A shot 6 cut: from `position` toward `look`, pushing CUT_PUSH of the way.
local function push(position: Vector3, look: Vector3, title: string, area: string): Cut
	local to = position + (look - position) * Intro.CUT_PUSH
	return {
		from = key(position, look),
		to = key(to, look),
		seconds = 0.45,
		title = title,
		area = area,
	}
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
	return { x = x, z = z, side = side }
end

-- The tutorial stray point behind a plot, on the alley floor: the lane spawn point 2p - 1 (Layout's alley points).
function Intro.strayPoint(plot: Plot): Vector3
	return v((Config.World.AlleyInnerX + 7) * plot.side, 0.1, plot.z - 7)
end

-- A plot-local place (x across, y above the floor top, z toward the back) in the world. WorldBuilder turns each plot
-- with CFrame.lookAt toward the street, so plot -Z points at the street and plot +X runs along -Z on the east side
-- (+1), +Z on the west side (-1).
function Intro.plotPoint(plot: Plot, x: number, y: number, z: number): Vector3
	return v(plot.x + plot.side * z, Intro.FLOOR_Y + y, plot.z - plot.side * x)
end

-- Where you stand for the catch (shots 1 and 2): on the alley floor CATCH_GAP from the stray, toward the middle of
-- your yard gate, so the run home sets off straight.
function Intro.catchSpot(plot: Plot): Vector3
	local stray = Intro.strayPoint(plot)
	local gate = Intro.plotPoint(plot, Intro.cafe.yardGate.x, 0, Intro.cafe.yardGate.z)
	local flat = v(gate.X - stray.X, 0, gate.Z - stray.Z)
	return stray + flat.Unit * Intro.CATCH_GAP
end

-- Shot 3's run (ground points): from the catch spot through the middle of the yard gate and in at the back door to
-- the intro spot, out of sight inside at about 1.4 s.
function Intro.runPath(plot: Plot): { Vector3 }
	local cafe = Intro.cafe
	return {
		Intro.catchSpot(plot),
		Intro.plotPoint(plot, cafe.yardGate.x, 0, cafe.yardGate.z),
		Intro.plotPoint(plot, cafe.backDoor.x, 0, cafe.backDoor.z),
		Intro.plotPoint(plot, cafe.introSpot.x, 0, cafe.introSpot.z),
	}
end

-- Shot 4's steps in, seen from inside after the cut: from the back door to the intro spot, where the real character
-- stands, in STEP_IN_SECONDS.
function Intro.stepIn(plot: Plot): { Vector3 }
	local cafe = Intro.cafe
	return {
		Intro.plotPoint(plot, cafe.backDoor.x, 0, cafe.backDoor.z),
		Intro.plotPoint(plot, cafe.introSpot.x, 0, cafe.introSpot.z),
	}
end

-- How long a path takes at `speed` studs a second.
function Intro.pathSeconds(points: { Vector3 }, speed: number): number
	local length = 0
	for i = 2, #points do
		length += (points[i] - points[i - 1]).Magnitude
	end
	return length / speed
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

-- The waiter spot your demo cat takes in shot 4, in the world, on the cafe floor.
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
	return Economy.catRate(cat) * Economy.cafeMultiplier(profile) * Economy.tierMultiplier(profile)
end

-- The demo cat's name on its rate tag.
function Intro.demoName(): string
	local def = Catalog.getCat(Intro.DEMO_CAT)
	return if def ~= nil then def.name else "Tuxedo"
end

-- The ten shots for this plot. `codesCat` is false until a Codes Cat station stands in the Workspace (F65).
function Intro.shots(plot: Plot, codesCat: boolean): { Shot }
	local W = Config.World
	local px, pz, s = plot.x, plot.z, plot.side
	local lane = W.AlleyInnerX -- the back alley's inner edge
	local stray = v((lane + 7) * s, 1, pz - 7)
	-- the catch: midway between you and the stray, 1.5 up
	local you = Intro.catchSpot(plot)
	local catch = v((you.X + stray.X) / 2, 1.6, (you.Z + stray.Z) / 2)
	local cafe = Intro.cafe
	local function local3(x: number, y: number, z: number): Vector3
		return Intro.plotPoint(plot, x, y, z)
	end
	local backDoor = local3(cafe.backDoor.x, 3.5, cafe.backDoor.z)
	-- shot 4's view up the middle aisle toward the back door, past the waiter spot (section 2, #436)
	local aisle = local3(-6, 2, 6)
	-- the west Alleyway Index Board, 8 inside the Town Square's west side arch (intro-cutscene.md 2c, v3.1)
	local board = v(-(lane + 8), 4, -9)
	local town = v(0, 0, -20) -- shot 9 looks up the whole town from the south, both back alleys in frame
	local parkGate = W.ParkGateZ
	-- the Town Square sits at the origin: the fountain, and the west quarters' Spin Wheel and Codes Cat
	local fountain = v(0, 2, 0)
	local stations = v(-28, 4, 0)
	local shots: { Shot } = {
		{
			index = 1,
			starts = 0,
			seconds = 3.5,
			caption = "Catch stray cats behind your cafe!",
			ease = "InOut",
			you = true,
			demo = true,
			cuts = {
				{
					-- one crane from the street over the roof into the alley, onto you facing the stray
					from = key(v(px - 30 * s, 9, pz - 6), v(px - 14.3 * s, 7, pz)),
					via = key(v(px, 38, pz - 10), v(px + 20 * s, 0, pz - 7)),
					to = key(v((lane + 1) * s, 7, pz - 17), stray),
					seconds = 3.5,
				},
			},
		},
		{
			index = 2,
			starts = 3.5,
			seconds = 2.5,
			caption = "Tap as each circle closes!",
			ease = "Linear",
			you = true,
			demo = true,
			catch = true,
			cuts = {
				{
					from = key(v((lane + 2) * s, 4.5, pz - 15), catch),
					to = key(v((lane + 4) * s, 3.2, pz - 12), catch),
					seconds = 2.5,
				},
			},
		},
		{
			index = 3,
			starts = 6,
			seconds = 2,
			caption = "Carry it home to your cafe!",
			ease = "Linear",
			you = true,
			run = true,
			cuts = {
				{
					-- a hard cut to the alley behind you, holding on the back door
					from = key(local3(-8, 6, 40), backDoor),
					to = key(local3(-8, 5, 34), backDoor),
					seconds = 2,
				},
			},
		},
		{
			index = 4,
			starts = 8,
			seconds = 2.8,
			caption = "Give it a job. Working cats earn tips!",
			ease = "InOut",
			you = true,
			job = true,
			cuts = {
				{
					-- inside your cafe with its roof on, just inside the front wall left of the front door
					from = key(local3(-2, 7, -12.5), aisle),
					to = key(local3(-2, 6.5, -10), aisle),
					seconds = 2.8,
				},
			},
		},
		{
			index = 5,
			starts = 10.8,
			seconds = 2.7,
			caption = "Rank up your cafe to open new areas",
			ease = "InOut",
			cuts = {
				{
					from = key(v(0, 45, parkGate + 111), v(0, 0, parkGate + 61)),
					to = key(v(0, 12, parkGate + 19), v(0, 4, parkGate - 1)),
					seconds = 2.7,
				},
			},
		},
		{
			index = 6,
			starts = 13.5,
			seconds = 1.8,
			caption = "Every area has its own cats",
			ease = "Linear",
			cuts = {
				push(v(0, 40, parkGate + 6), v(0, 0, W.ParkCenterZ - 2), "THE PARK", "park"),
				push(
					v(W.NeighbourhoodCenterX, 60, W.NeighbourhoodGateZ + 8.5),
					v(W.NeighbourhoodCenterX, 0, W.NeighbourhoodCenterZ + 5.5),
					"THE NEIGHBOURHOOD",
					"neighbourhood"
				),
				-- v3.1: the Woods and the Sewer lie west and east, seen from just outside their side gates
				push(
					v(W.WoodsGateX + 5, 45, W.WoodsCenterZ),
					v(W.WoodsCenterX + 5, 0, W.WoodsCenterZ),
					"THE WOODS",
					"woods"
				),
				push(
					v(W.SewerGateX - 5, 40, W.SewerCenterZ),
					v(W.SewerCenterX - 4, 0, W.SewerCenterZ),
					"THE SEWER",
					"sewer"
				),
			},
		},
		{
			index = 7,
			starts = 15.3,
			seconds = 2.5,
			caption = "Find all 50 cats for Index rewards",
			ease = "Out",
			cuts = {
				{
					-- from the square's east to west lane, through the west side arch at the board, clear of its south pillar
					from = key(v(-(lane - 3), 5, -1), board),
					to = key(v(-(lane + 1.5), 4.5, -6.5), board),
					seconds = 2.5,
				},
			},
		},
		{
			index = 8,
			starts = 17.8,
			seconds = 2.7,
			caption = if codesCat then Intro.CODES_CAPTION else Intro.SPIN_CAPTION,
			ease = "InOut",
			spinWheel = true,
			cuts = {
				{
					-- a hard cut, then down into the Town Square from its south side until the Spin Wheel and the
					-- Codes Cat are both in frame
					from = key(v(0, 24, -(W.TownSquareHalfDepth + 4)), fountain),
					to = key(v(-8, 10, 0), stations),
					seconds = 2.7,
				},
			},
		},
		{
			index = 9,
			starts = 20.5,
			seconds = 3,
			caption = "Night closes the areas. Fresh cats at sunrise!",
			ease = "Linear",
			night = true,
			cuts = {
				{
					from = key(v(0, 80, -150), town),
					to = key(v(0, 76, -144), town),
					seconds = 3,
				},
			},
		},
		{
			index = 10,
			starts = 23.5,
			seconds = 2,
			caption = "Go catch your first cat!",
			ease = "InOut",
			follow = true,
			cuts = {
				{
					-- `to` becomes the follow point at play time (Intro.follow); the swoop to a north row cafe, up to
					-- about 250 studs, bends through a point over the square
					from = key(v(0, 76, -144), town),
					via = if pz > 0 then key(v(0, 45, 0), v(0, 2, 0)) else nil,
					to = key(v(0, 76, -144), town),
					seconds = 2,
				},
			},
		},
	}
	return shots
end

-- The whole intro's length: where the last shot ends.
function Intro.length(shots: { Shot }): number
	local last = shots[#shots]
	return last.starts + last.seconds
end

-- The shot showing `elapsed` seconds in, or 0 once the last one has ended.
function Intro.shotAt(shots: { Shot }, elapsed: number): number
	for i = #shots, 1, -1 do
		if elapsed >= shots[i].starts then
			return if elapsed < shots[i].starts + shots[i].seconds then i else 0
		end
	end
	return 1
end

-- Shot 6's cuts that `streamed` says are there, sharing the shot's whole time between them, so a skipped area
-- gives its time to the others. With none streamed in, all four play anyway.
function Intro.keepCuts(shot: Shot, streamed: (Cut) -> boolean): { Cut }
	local kept: { Cut } = {}
	for _, cut in shot.cuts do
		if streamed(cut) then
			table.insert(kept, cut)
		end
	end
	if #kept == 0 then
		kept = table.clone(shot.cuts)
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
