--!strict
-- The intro cutscene's shots (F72, docs/design/cat-cafe/intro-cutscene.md section 2, reshot for the hometown and the
-- Cat Cannon, F84): when each starts, its caption, and where the camera flies. Studs, y up. Shot 1 follows the
-- player's own plot (`x`, `z` and `side`, -1 for the west row and +1 for the east row, the street toward -side) up
-- to the Town Square's cannon, where your copy climbs in. Shots 2 to 4 are at the Alleyway's camp: the flight, the catch
-- just past its way out and the carry into the camp. Shots 5 and 6 (the rich visitor, #2242) are in your cafe and
-- shots 7 and 8 in the Town Square (#1542, Derek 2026-11-05, took out the old shot 6's cuts over the other camps; #1782, Derek2 2026-11-06, took out the
-- cut back to the Alleyway camp's Index Board after the cafe). The camps are
-- worked out from Config as the server's Layout.camps does (a test checks they match), so the client needs neither
-- the server module nor the camps to have streamed in. The positions are starting points to tune in Studio. Pure apart from Vector3.

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Economy = require(script.Parent.Economy)
local ProfileSchema = require(script.Parent.ProfileSchema)
local Types = require(script.Parent.Types)

local Intro = {}

Intro.SHOTS = 8
-- The intro_cutscene event's version, so old and new drop-offs never mix (section 3): 3 for the hometown and the
-- cannon (F84), 4 since #1542 took out the camp cuts, 5 since #1782 took out the Index Board shot, 6 since #2113
-- put the night (now shot 7) before the free spin and codes (now shot 8), 7 since #2182 gave each shot a reading hold
-- and Next, 8 since #2242 put the rich visitor in as shot 6, 9 since #2357 (Derek2: "showing the cat waiting in
-- alleyway at the end scene is not needed") took out the last shot, "Your first cat is waiting in the Alleyway!", 10
-- since #2626 (Derek2: "make tutorial slightly faster 20% roughly") read faster and dropped the tackling lesson's tail.
Intro.VERSION = 10
Intro.SKIP_AFTER = 0 -- #3168 (Derek2: "no delay on clicking through scenes in tutorial so impatient people can instantly
-- click through it"): Skip works from the first second (it was 5.0 s, its bar filling until then)
Intro.MAX_CAPTION = 46 -- characters, so a caption fits one line on a phone ("about 45")
-- #2961 (Derek2 11-10: "don't make intro skip those slides ... just wait up to a couple seconds for loading"): the
-- most shot 1 holds on its fuse for the camp's ground before the cut to the camp. #3109 (Derek2 11-10: "start the
-- cutscene right after dont even check if the alleyway catching scenes are ready"): nothing waits before shot 1 any
-- more (STREAM_WAIT, 5 s, and this wait a second time are gone), so the camp has the loading screen and shot 1 to come
Intro.CAMP_WAIT = 2.5

-- #2182 (section 2b, two playtesters: the captions go by too fast to read): each shot shows for its hold, its section
-- 2 length or CAPTION_BASE plus CAPTION_PER_WORD a word of its caption, whichever is longer. The action runs on its
-- section 2 timings, then the camera eases to a stop over SETTLE_SECONDS and the scene idles until the hold ends.
-- From NEXT_AFTER into a shot, Next moves on at once. #2626 (Derek2: "make tutorial slightly faster 20% roughly"):
-- 0.8 + 0.32 s a word, a fifth off the 1.0 + 0.4 s every caption-bound hold had (about 31 s down to 25 s).
Intro.CAPTION_BASE = 0.8
Intro.CAPTION_PER_WORD = 0.32

-- #4001 (Derek 2026-11-13: the short intro and its 50/50 test; Design-Agent's cut on the issue): the short intro is
-- three shots to the eye, today's 1, 3 and 4 as one (the catch and the carry under one caption) and 5, read at the
-- pre-#2626 pace of 1.0 + 0.4 s a word. Its intro_cutscene version is SHORT_VERSION. In the catch the character turns
-- to the camera with the cat in its arms (Derek 19:27 UTC) over FACE_CAMERA_SECONDS once the cat has hopped in.
Intro.SHORT_VERSION = 11
Intro.SHORT_BASE = 1.0
Intro.SHORT_PER_WORD = 0.4
Intro.SHORT_CAPTIONS = {
	[1] = "Fly the Cat Cannon to catch cats!",
	[3] = "Tap the circles, then carry it to camp!",
	[4] = "Tap the circles, then carry it to camp!",
	[5] = "Give cats a job to earn money!",
} :: { [number]: string }
-- the dot each kept shot lights (the catch and the carry share one)
Intro.SHORT_DOTS = { [1] = 1, [3] = 2, [4] = 2, [5] = 3 } :: { [number]: number }
Intro.SHORT_DOT_COUNT = 3
Intro.FACE_CAMERA_SECONDS = 0.4
-- Review-QA (Studio, 2026-11-13): the turn needs time on screen. The short catch holds until this far in, about a
-- second and a half of you facing the camera with the cat in your arms before the carry.
Intro.SHORT_CATCH_HOLD = 3.4
-- Review-QA (Studio, f9293840): facing the camera by the root showed the back, so the turn aimed the other way.
-- #4019: the back showed because the copy was still curled in the cannon's ball pose (the short intro has no
-- landing to end it); it now stands up for the catch, so the root's own facing is right and the flip is off.
Intro.FACE_FLIP = false
Intro.NEXT_AFTER = 0 -- #3168: was 1.0, then 0.2; spam clicks go straight through (the screen takes one Next a shot)
Intro.SETTLE_SECONDS = 0.3

Intro.AREA = "alley" -- the camp shots 2 to 4 film, where a new player's first flight goes
-- Smoother cuts between places (#958, Derek 2026-11-03: "make the locations cuts smoother"): a cut or shot boundary
-- whose next camera place is more than JUMP_STUDS from the last is a jump, and Moments.IntroCut fires CUT_LEAD
-- before it for Effects' cloud dip. None inside or into the cannon flight shot, which has its own clouds.
Intro.JUMP_STUDS = 60
Intro.CUT_LEAD = 0.2

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
	richTip = { x = -12.22, y = 2.7, z = -10.32 }, -- #2242: Layout.plot.richTip, the RichTipAnchor on table 1
	-- #2395: table 1 (Layout.plot.tables[1]), its first chair (Layout.plot.seatOffsets[1]) and the aisle's half width
	-- (Layout.plot.aisleX), for shot 6 in a new cafe that has no table yet
	table1 = { x = -12.22, z = -10.32, lane = -6.56 },
	seat1 = { x = -2.4, rotY = -90 },
	aisleX = 2,
}

-- Shot 6 (#2242, Derek2 2026-11-07: "add the rare customers chance to the tutorial scene like rich customer tips"), in
-- seconds into the shot, in your cafe: a rich visitor walks in from the door to table 1's chair from RICH_WALK_AT, sits
-- at RICH_SIT_AT, and leaves the gold coin pile on the RichTipAnchor at RICH_TIP_AT. Your copy walks in from the door
-- from RICH_GRAB_FROM and grabs it at RICH_GRAB_AT, where the "+$" pop shows Intro.richTip(). Local only.
Intro.RICH_WALK_AT = 0.1
Intro.RICH_SIT_AT = 1.0
Intro.RICH_TIP_AT = 1.15
Intro.RICH_GRAB_FROM = 1.3
Intro.RICH_GRAB_AT = 2.3
Intro.RICH_ASSET = "CatCafe_NPC_Customer_Rich" -- CustomerController's rich customer, with its `_Sit` twin
Intro.RICH_REACH = 2.6 -- your copy stops this far short of the coin pile, on the door's side

-- Shot 7 (#2113; it was 7, then 6 until #2242), in seconds into the shot: dusk, a short night and sunrise on this
-- screen only.
Intro.NIGHT_FROM = 0.35
Intro.NIGHT_TO = 0.95
Intro.SUNRISE_FROM = 1.8
Intro.SUNRISE_TO = 2.3

-- Shot 9 lands this far behind and above the character, looking at its head.
Intro.FOLLOW_BACK = 12
Intro.FOLLOW_UP = 6
Intro.HEAD_UP = 1.5

Intro.CODES_CAPTION = "Free spin every day. Codes at the Codes Cat!"
Intro.SPIN_CAPTION = "Spin the wheel for a free prize every day!" -- shot 8 before a Codes Cat stands in the world
Intro.RICH_CAPTION = "Rich visitors leave big tips. Grab them fast!"

export type Ease = "InOut" | "Out" | "Linear"
export type Plot = { x: number, z: number, side: number, index: number }
-- One camera place: where it is and what it looks at.
export type Key = { position: Vector3, look: Vector3 }
-- One continuous move. `via` bends it through a third place halfway.
export type Cut = { from: Key, to: Key, via: Key?, seconds: number }
export type Shot = {
	index: number, -- its number in section 2, which Skip reports, also when the fallback leaves shots out
	starts: number, -- on the section 2 timings (the shots' `seconds` back to back)
	seconds: number, -- its section 2 length: when its action and camera move end
	hold: number, -- #2182: how long it shows when nobody presses Next (Intro.hold)
	caption: string,
	ease: Ease,
	cuts: { Cut },
	you: boolean?, -- shots 1 to 4: your local copy plays the scene and the real character is hidden
	camp: boolean?, -- shots 3 and 4 need the Alleyway's camp and are left out when it has not streamed in
	cannon: boolean?, -- shots 1 and 2: the town cannon is turned toward the Alleyway and uncovered on this screen
	launch: boolean?, -- shot 1: you climb into the cannon, it turns, the fuse fizzes
	flight: boolean?, -- shot 2: the BOOM, the arc, the clouds and the landing on the Alleyway's pad
	catch: boolean?, -- shot 3: the demo ring, then the cat hops into your arms
	run: boolean?, -- shot 4: you run it into the camp, where it checks in
	job: boolean?, -- shot 5: the cat takes the waiter spot in its outfit
	rich: boolean?, -- shot 6 (#2242): a rich visitor leaves a big tip and your copy grabs it
	spinWheel: boolean?, -- shot 8 (#2113): the world wheel turns two spins on this screen
	night: boolean?, -- shot 7 (#2113): night falls and the sun rises on this screen
	follow: boolean?, -- the last cut ends behind the character (Intro.follow), not at `to` (no shot since #2357)
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
local BOARD_IN = -7 -- as Layout.indexBoards (#3349): 7 in at a gated area, 4 at the Alleyway
local ALLEY_BOARD_IN = -4
local BOARD_OUT = 11 -- #3628: 4 until the boards moved off the carrier baskets
local BOARD_OUT_FOR: { [string]: number } = { woods = 9 }
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
	elseif area == "desert" then
		-- #2651: the Desert's camp on its north end (toward the town), a half turn like the Park
		ox, oz, turn, opening =
			W.DesertCenterX, W.DesertCenterZ + W.DesertDepth / 2, 180, W.CampOpeningWidth / 2
	elseif area == "ruins" then
		-- #2651: the Ruins' camp on its south end (toward the town), no turn like the Neighbourhood
		ox, oz, turn, opening =
			W.RuinsCenterX, W.RuinsCenterZ - W.RuinsDepth / 2, 0, W.CampOpeningWidth / 2
	elseif area == "snowy" then
		-- #3997: the Snowy Mountain's camp on its south side (toward the town), no turn like the Ruins
		ox, oz, turn, opening =
			W.SnowyCenterX, W.SnowyCenterZ - W.SnowyDepth / 2, 0, W.CampOpeningWidth / 2
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
	-- every board beside the opening, on the left of it, 7 in; the Alleyway's 4 in and further out, past its low walls (F85)
	local board = point(
		-(opening + if area == "alley" then ALLEY_BOARD_OUT else (BOARD_OUT_FOR[area] or BOARD_OUT)),
		if area == "alley" then ALLEY_BOARD_IN else BOARD_IN
	)
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

-- The turn about Y (degrees) from the town cannon's rest that points it at the Alleyway's landing pad, as
-- Layout.cannonAim does (#2651: the pad, not the area's middle).
function Intro.cannonAim(): number
	local camp = Intro.camp("alley") :: Camp
	return math.deg(math.atan2(camp.pad.X, camp.pad.Z))
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

-- #2961: the ground the camp shots film, which must have streamed in before they play: the pad (shot 2 lands on it),
-- the catch spot and the stray (shot 3). The Alleyway's ground and set are big parts with their middles far down the
-- area, so `middle` is the area's middle, asked for too so they come in with the props by the camp.
function Intro.campGround(): { points: { Vector3 }, middle: Vector3 }
	local camp = alleyCamp()
	local W = Config.World
	return {
		points = { camp.pad, Intro.catchSpot(), Intro.strayPoint() },
		middle = v(W.AlleyCenterX, AREA_FLOOR, W.AlleyCenterZ),
	}
end

-- #3303 (Laptop-Tester 11-11: shot 2 "Boom! Every area starts at a safe camp" showed only flat orange ground in
-- Studio): the floor streams in before the camp's set, so the floor alone let the cut land on bare ground. The camp
-- counts as in only once its own Cat Cannon (CAMP_CANNON_STUDS behind the pad, at the back wall) has streamed in too.
-- campSetNear(cannons, pad): any of `cannons` (positions of streamed-in Cat Cannon parts) within SET_RADIUS of `pad`.
Intro.SET_RADIUS = 20
Intro.CANNON_TAG = "CatCannon" -- WorldBuilder's tag on every Cat Cannon (TutorialMoves.CANNON_TAG)

function Intro.campSetNear(cannons: { Vector3 }, pad: Vector3): boolean
	for _, at in cannons do
		local flat = Vector3.new(at.X - pad.X, 0, at.Z - pad.Z)
		if flat.Magnitude <= Intro.SET_RADIUS then
			return true
		end
	end
	return false
end

-- #2961: whether a downward ray's hit at height `y` is the area's floor (a few studs either way), not a roof or a
-- prop's top far above it.
function Intro.floorHit(y: number): boolean
	return y >= AREA_FLOOR - 3 and y <= AREA_FLOOR + 3
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

-- #2242: shot 6's coin pile in the world (where the plot's RichTipAnchor stands), and the door your copy and the rich
-- visitor walk in by, on the cafe floor.
function Intro.richTipPoint(plot: Plot): Vector3
	local tip = Intro.cafe.richTip
	return Intro.plotPoint(plot, tip.x, tip.y, tip.z)
end

function Intro.doorPoint(plot: Plot): Vector3
	return Intro.plotPoint(plot, 0, 0, -Config.World.PlotDepth / 2 + 1.5)
end

-- #2395: the rich visitor's way to table 1's first chair, after the door, as CafeService gives a chair's Aisle and
-- Approach: beside the aisle at the table's lane, then on the lane in line with the chair, so it walks round the
-- tables instead of through them. In the world, on the cafe floor.
function Intro.richRoute(plot: Plot): { Vector3 }
	local spot = Intro.cafe.table1
	local x = spot.x + Intro.cafe.seat1.x
	local side = if x < 0 then -1 else 1
	return {
		Intro.plotPoint(plot, side * Intro.cafe.aisleX, 0, spot.lane),
		Intro.plotPoint(plot, x, 0, spot.lane),
	}
end

-- #2395: the point `k` (0 to 1) of the way along `points` by distance, and the flat way it heads there. One point
-- (or none of length) stays put, facing -Z.
function Intro.alongPath(points: { Vector3 }, k: number): (Vector3, Vector3)
	local total = 0
	for i = 2, #points do
		total += (points[i] - points[i - 1]).Magnitude
	end
	local heading = Vector3.new(0, 0, -1)
	if #points == 0 then
		return Vector3.zero, heading
	end
	local left = math.clamp(k, 0, 1) * total
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		local step = (b - a).Magnitude
		local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		if flat.Magnitude > 1e-6 then
			heading = flat.Unit
		end
		if left <= step and step > 1e-6 then
			return a:Lerp(b, left / step), heading
		end
		left -= step
	end
	return points[#points], heading
end

-- #2242: where your copy stops to grab the tip at `tip` coming in from `door`: RICH_REACH short of it, on the floor.
function Intro.grabSpot(door: Vector3, tip: Vector3): Vector3
	local flat = Vector3.new(door.X - tip.X, 0, door.Z - tip.Z)
	local back = if flat.Magnitude > 1e-6 then flat.Unit else Vector3.new(0, 0, -1)
	local at = tip + back * Intro.RICH_REACH
	return Vector3.new(at.X, door.Y, at.Z)
end

-- #2242: the "+$" shot 6 shows: a rich tip (Economy.richTipAmount, at least $50) on the day rate of a new cafe whose
-- one cat is the demo waiter, at Tier 1. Nothing is paid.
function Intro.richTip(): number
	return Economy.richTipAmount(Intro.demoRate())
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

-- #2182: the words in a caption, runs of non-space characters.
function Intro.words(caption: string): number
	local count = 0
	for _ in string.gmatch(caption, "%S+") do
		count += 1
	end
	return count
end

-- #2182: how long a shot of section 2 length `seconds` showing `caption` holds: long enough to read the caption.
function Intro.hold(seconds: number, caption: string): number
	return math.max(seconds, Intro.CAPTION_BASE + Intro.CAPTION_PER_WORD * Intro.words(caption))
end

-- #4001: a short intro caption's reading time, 1.0 s plus 0.4 s a word.
function Intro.shortHold(caption: string): number
	return Intro.SHORT_BASE + Intro.SHORT_PER_WORD * Intro.words(caption)
end

-- #2182: the time on the shot's camera moves `t` seconds into a shot. Up to SETTLE_SECONDS before its moves end it is
-- `t`; from there it slows evenly to a stop at the moves' end, SETTLE_SECONDS after it, and stays there through the
-- rest of the hold. A shot with no time to spare keeps its moves as they were.
function Intro.cameraTime(shot: Shot, t: number): number
	local settle = math.min(Intro.SETTLE_SECONDS, shot.hold - shot.seconds, shot.seconds)
	local from = shot.seconds - settle
	if settle <= 0 or t <= from then
		return math.min(t, shot.seconds)
	end
	local u = math.min(t - from, 2 * settle)
	return from + u - u * u / (4 * settle)
end

-- #2182: shot 1's time `t` seconds in. Once your copy is in the barrel it waits there through the extra hold, so the
-- turn, the wiggle and the fuse come at the end and the BOOM still starts shot 2.
function Intro.launchTime(shot: Shot, t: number): number
	local inBarrel = Intro.CLIMB_AT + Intro.CLIMB_SECONDS
	if t <= inBarrel then
		return t
	end
	return math.min(shot.seconds, math.max(inBarrel, t - (shot.hold - shot.seconds)))
end

-- #2182: the time into shot 1 at which its fuse fizzes (Intro.launchTime), where Next takes it.
function Intro.fuseAt(shot: Shot): number
	return Intro.FUSE_AT + (shot.hold - shot.seconds)
end

-- The nine shots for this plot. `codesCat` is false until a Codes Cat station stands in the Workspace (F65);
-- `alleyStreamed` false leaves out the shots at the Alleyway's camp (3 and 4) and holds shot 2 in the clouds.
function Intro.shots(
	plot: Plot,
	codesCat: boolean,
	alleyStreamed: boolean?,
	short: boolean?
): { Shot }
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
	local cannonEnd = key(v(10, 8, -18), v(0, 6, 0)) -- shot 1's last frame, from the square's south east side
	local launchTilt = key(v(10, 7, -18), v(-6, 14, -6))
	local town = v(0, 0, -20) -- shot 7 looks up the whole town from the south
	-- shot 6 (#2242): from inside the front wall right of the door, across the door to table 1's coin pile
	local richLook = local3(-6, 2.5, -halfD + 4)
	-- #2644: the Codes Cat moved to the south-west corner (-41, -25) in #2643, so the shot ends further east and looks
	-- along the bisector between it and the Spin Wheel (-28, 16): each about 27 degrees off the axis, in frame on a phone,
	-- and high enough (18) to see the Codes Cat over Juniper's cart, which stands near that line of sight
	-- between the Spin Wheel and the Codes Cat; #2707's roomier square put them 38 studs apart (-28, 22 and -29, -16),
	-- so the camera stands back east of the cannon to fit both on a phone; #3001's 120 x 110 square and #3000's Codes
	-- spot put them at (-35, 27.5) and (-45, -20), further out and 48 apart, so the shot looks further west along
	-- z = 5 (28 and 25 degrees off the axis) from a little nearer the cannon; #3070's 120 x 140 square put them at
	-- (-35, 35) and (-45, -25.5), 60 apart, so the camera stands 12 further east and 4 higher to keep the same angles
	-- (29 and 25 degrees) and still look over the cannon; #3454's four corners put them at (-26, 54) and (-44, -23),
	-- 79 apart, so the camera stands 14 further east and 4 higher and looks at the point between them (29 degrees
	-- off the axis each)
	local stations = v(-35, 3, 15.5)
	local stationsCam = v(34, 28, 0)
	local shotFrom = key(v(px - (halfD + 16) * s, 9, pz - 6), v(px - (halfD + 0.3) * s, 7, pz))
	local streamed = alleyStreamed ~= false
	local all: { Shot } = {
		{
			index = 1,
			starts = 0,
			hold = 0,
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
			hold = 0,
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
			hold = 0,
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
			hold = 0,
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
			hold = 0,
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
			hold = 0,
			seconds = 3,
			caption = Intro.RICH_CAPTION,
			ease = "InOut",
			rich = true,
			cuts = {
				{
					from = key(local3(7, 7, -halfD + 2.5), richLook),
					to = key(local3(5.5, 6.5, -halfD + 3.5), richLook),
					seconds = 3,
				},
			},
		},
		{
			index = 7,
			starts = 0,
			hold = 0,
			seconds = 3,
			-- #2113 (Derek2): night and its fresh cats before the free spin and the codes
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
			index = 8,
			starts = 0,
			hold = 0,
			seconds = 2.7,
			caption = if codesCat then Intro.CODES_CAPTION else Intro.SPIN_CAPTION,
			ease = "InOut",
			spinWheel = true,
			cuts = {
				{
					-- down into the Town Square from its south side until the Spin Wheel and the Codes Cat are in frame
					from = key(v(0, 24, -36), v(0, 5, 0)),
					to = key(stationsCam, stations),
					seconds = 2.7,
				},
			},
		},
	}
	local shots: { Shot } = {}
	local at = 0
	for _, shot in all do
		local shortCaption = Intro.SHORT_CAPTIONS[shot.index]
		if (streamed or not shot.camp) and (short ~= true or shortCaption ~= nil) then
			shot.starts = at
			if short == true then
				shot.caption = shortCaption :: string
				-- the catch and the carry share one caption: the pair holds its reading time between them
				shot.hold = if shot.index == 3
					then math.max(
						shot.seconds,
						Intro.SHORT_CATCH_HOLD,
						Intro.shortHold(shot.caption) - all[4].seconds
					)
					elseif shot.index == 4 then shot.seconds
					else math.max(shot.seconds, Intro.shortHold(shot.caption))
			else
				shot.hold = Intro.hold(shot.seconds, shot.caption)
			end
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

-- True when the camera goes from `from` to `to` across a cut: a jump between places (more than JUMP_STUDS apart),
-- which Effects covers with a cloud dip (#958).
function Intro.jump(from: Key, to: Key): boolean
	return (to.position - from.position).Magnitude > Intro.JUMP_STUDS
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

-- Shot 9's end: FOLLOW_BACK behind and FOLLOW_UP above a character standing at `root`, looking at its head.
function Intro.follow(rootPosition: Vector3, facing: Vector3): Key
	local flat = Vector3.new(facing.X, 0, facing.Z)
	local back = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
	return {
		position = rootPosition - back * Intro.FOLLOW_BACK + Vector3.new(0, Intro.FOLLOW_UP, 0),
		look = rootPosition + Vector3.new(0, Intro.HEAD_UP, 0),
	}
end

return Intro
