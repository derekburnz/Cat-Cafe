--!strict
-- Pure geometry for the world: where plots sit on the street and where everything inside a plot goes.
-- Plot-local space: X runs along the street, Z is depth, -Z faces the street, y = 0 is the floor top.
-- No Roblox globals, so tests can check the numbers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Lawn = require(ReplicatedStorage.Shared.Lawn)
local Types = require(ReplicatedStorage.Shared.Types)

-- zone tags a spawn point "lane" (behind a cafe) or "nook" (an end of a back alley, v3.1), or in a v3.2 side area
-- "near" (the gate half) or "deep" (the far half); Epic and rarer strays take only "nook" or "deep" points.
export type Point = { x: number, y: number, z: number, rotY: number?, zone: string? }
-- A cafe table: its point, and `lane`, the plot-local z of the walkway beside its row that customers walk along to
-- reach its chairs (Layout.plot.tables).
export type TableSpot = { x: number, y: number, z: number, lane: number }
-- A cat bed (F79): its id (the sleep spot's), point, turn about Y and the tier it comes with.
export type BedSpot = { id: string, x: number, y: number, z: number, rotY: number, tier: number }
-- An axis-aligned rectangle on the ground, world or plot space depending on where it is used.
export type Rect = { x1: number, z1: number, x2: number, z2: number }
-- An archway over an entrance (WorldBuilder.buildArch): the alley kit's `asset` when there is one.
-- rotY turns its front (-Z) when the area builds it (0 when omitted).
export type Arch = {
	x: number,
	z: number,
	span: number,
	label: string,
	asset: string?,
	rotY: number?,
}
-- A rescue trap: the prop stands at (x, floor, z) turned by rotY; the stuck cat sits at Layout.stuckPoses[prop].
-- A trap built into an area's kit set has no prop: the stuck cat sits at Layout.setStuckPoses[trap] on top of
-- (x, floor + y, z) turned by rotY.
-- `trap` is the TrapType (data-model section 9): a "tree" is shaken then caught, every other trap is the bar.
export type RescuePoint = {
	prop: string?,
	trap: string,
	x: number,
	y: number?,
	z: number,
	rotY: number?,
}
-- y is the height above the area floor (0 when omitted); wall props set it.
export type Prop = { asset: string, x: number, y: number?, z: number, rotY: number? }
-- A shared area in world space. A box area (no rects) is a wild area (v4, F84): one floor with walls on three sides
-- and an opening in its near wall, the one facing the hometown, where its old gate stands as the way out of its camp
-- (Layout.camps): a Z side with gateZ (the Park, the Neighbourhood), an X side with gateX (the Woods and the Sewer).
-- center, halfWidth and halfDepth are the set's floor; the camp lies outside it. An area with rects (the Alleyway) is
-- those floors with the listed wall footprints and arches; center, halfWidth and halfDepth are then its bounding box.
export type AreaSpec = {
	floorY: number,
	center: Point,
	halfWidth: number,
	halfDepth: number,
	gateZ: number?, -- where the gate stands across an opening on a Z side; nil for the Tier 1 alley
	gateX: number?, -- or across an opening on an X side (the Woods and the Sewer)
	openingHalfWidth: number?, -- half the opening of a box area; the street's half width when omitted
	nearWall: boolean?, -- false when a neighbour's wall already closes a box area's near side, opening and all
	paths: { Rect }?, -- a box area's roads and paths, laid flat on its floor
	-- The area's kit set (Model-Agent's CatCafe_<Area>_Set, assets/cat-cafe/exports/area-sets.md): when the art is
	-- there WorldBuilder places it on the floor turned by Layout.gateTurn, in place of `paths` and `props`, and hides
	-- the wall facing the town behind the set's see-through border. setLift is how far the set's own ground stands
	-- above the floor where strays walk (the Sewer's tiles).
	set: string?,
	setLift: number?,
	-- F85 (hometown-cannon.md section 6b): the suffix on a long area's camp, gate, night fence and backdrop models
	-- (`CatCafe_Camp_ParkF85`, `CatCafe_Park_GateF85`, ...), which Model-Agent made with new names beside the old
	artSuffix: string?,
	rects: { Rect }?,
	walls: { Rect }?, -- wall footprints for a rects area
	roam: { Rect }?, -- where strays may walk when props line the walls; the floor pieces when nil
	wallHeight: number?,
	-- archways a rects area is entered by: the alley kit's asset when it is there, else posts, beam and label
	arches: { Arch }?,
	arrival: Point?, -- where fast travel lands; a box area lands on its camp's landing pad
	spawnPoints: { Point },
	rescueSpots: { RescuePoint },
	props: { Prop },
}

local Layout = {}

-- Where the stuck cat's pivot sits on each rescue prop, in prop space: the stuck_pose body_cframe_roblox values
-- from assets/cat-cafe/exports/manifest.json, 12 numbers for CFrame.new(table.unpack(pose)). Plain numbers keep
-- this module free of Roblox types. Placeholders share the real props' pivots, so one set fits both.
Layout.stuckPoses = {
	-- The traps (F27), fitted by Animation-Engineer on the current models (stuck-placements.md, 2026-10-28) so
	-- the wriggles (Logic.stuckStyle, #545) read: back end out of the bin, can and bags, upside down on the tree.
	-- Nose first into the bin under the open lid: back end, back legs and tail out of the top.
	CatCafe_Alley_TrashBin = { 0, 2.55, -0.57, -1, 0, 0, 0, 0, 1, 0, 1, 0 },
	-- Nose first 60 degrees into the top of the big bag, back end up and the back legs off the ground (Animation-
	-- Engineer's refit after Derek's 14:17 note, head hidden through the wriggle).
	CatCafe_Alley_GarbageBags = { -0.45, 0.75, -0.8, -1, 0, 0, 0, 0.5, 0.866, 0, 0.866, -0.5 },
	-- Hanging upside down under the shakeable branch, all four paws round it, facing the tip.
	CatCafe_Park_RescueTree = { -2.2, 4.1, 0, 0, 0, 1, 0, -1, 0, 1, 0, 0 },
	-- Nose first into the can under the lid, back end out of the top.
	CatCafe_Park_TrashCan = { 0, 2.05, -0.65, -1, 0, 0, 0, 0, 1, 0, 1, 0 },
	-- Stand-ins for the provisional traps of the grayboxes.
	-- Clings to the low branch, rolled 20 degrees toward the trunk.
	CatCafe_Alley_StuckTree = { -1.4, 4.4, 0, 0.9397, -0.342, 0, 0.342, 0.9397, 0, 0, 0, 1 },
	-- Head inside the box, tail end out of the opening (turned 180 degrees).
	CatCafe_Alley_StuckBox = { 0, 0, -0.6, -1, 0, 0, 0, 1, 0, 0, 0, -1 },
	-- Body inside the outlet, head poking out.
	CatCafe_Alley_Drainpipe = { 0, 0, -2, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
} :: { [string]: { number } }

-- Where the stuck cat's pivot sits at a trap built into an area set (setTrap), in the spot's space: the spot at
-- (x, floor + y, z) turned by rotY, the set's turn plus the piece's. By TrapType; each fits both spots of its
-- type, since they are the same piece. `tree` only meets the Woods' tree house branch: the Park's trees are props.
-- Animation-Engineer's numbers (stuck-placements.md, 2026-10-28), 12 numbers like stuckPoses.
Layout.setStuckPoses = {
	shed = { 0, 0, 0.75, -1, 0, 0, 0, 1, 0, 0, 0, -1 }, -- head first through the jammed door (+Z), back end out
	gutter = { 0, 1.25, 0.1, -1, 0, 0, 0, -1, 0, 0, 0, 1 }, -- on its back across the gutter, head over the front edge
	hollow_log = { 3.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0 }, -- head first into the open end (+X), back end out
	-- nose first 70 degrees into the top front of the bush, back end out (refit with #581's back end wriggle)
	bramble_bush = { 0, 2.56, -1.17, -1, 0, 0, 0, 0.342, 0.9397, 0, 0.9397, -0.342 },
	tree = { 0.5, -0.55, 0, 0, 0, 1, 0, -1, 0, 1, 0, 0 }, -- hanging under the tree house branch, facing its tip
	grate = { 0, 0.45, -0.57, -1, 0, 0, 0, 0, 1, 0, 1, 0 }, -- nose down through the grate, back end up
	drain_pipe = { 0, 0.55, 0.5, -1, 0, 0, 0, 1, 0, 0, 0, -1 }, -- head first into the mouth (-Z side), back end out
} :: { [string]: { number } }

local W = Config.World

-- World position of plot `index` (1-based) and which side of the street it is on (-1 west, +1 east). Out from
-- the street: the sidewalk to |x| 18, the front garden, the front wall, the cafe floor, the back wall and the yard.
-- Layout v3 (F76): the rows pair up either side of the Town Square, a side passage from it, plots 1 and 2 south of
-- the square and 3 and 4 north of it, then 5 to 8 one row farther out the same way, so a few players all have a
-- cafe by the square and the beginner's plot 1 is a short walk from the stations.
function Layout.plotPlacement(index: number): { x: number, z: number, side: number, index: number }
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

-- The middle (z) of every side passage from the street to a back alley: the gaps between neighbouring cafes, and
-- between the inner cafes and the Town Square's gardens. The same both sides of the street.
function Layout.sidePassages(): { number }
	local passages: { number } = {}
	local north: { number } = {}
	for index = 1, W.PlotCount do
		local placement = Layout.plotPlacement(index)
		if placement.side < 0 and placement.z > 0 then
			table.insert(north, placement.z)
		end
	end
	table.sort(north)
	local edge = W.TownSquareHalfDepth -- the gardens' edge, then each cafe's far side in turn
	for _, z in north do
		local passage = (edge + z - W.PlotWidth / 2) / 2
		table.insert(passages, -passage)
		table.insert(passages, passage)
		edge = z + W.PlotWidth / 2
	end
	table.sort(passages)
	return passages
end

local halfW = W.PlotWidth / 2 -- 22
local halfD = W.PlotDepth / 2 -- 17
local yardZ1, yardZ2 = halfD + 1, halfD + 1 + W.YardDepth -- 18, 28

-- Bigger cafes (Derek 2026-11-02 21:52; Model-Agent #917, gameplay-handoff-44x34.md): the room is 44 x 34 inside, from
-- 36 x 28. Furniture, cats and decor keep their sizes and the space between them grows: a piece against a side wall
-- keeps its distance to it, the counter, espresso machine, oven, baristas and back door keep their x, and the rest
-- spreads with the room. Model-Agent's fit check found no clash at these points with every Tier 5 piece and every
-- crate decor piece at every decor spot. Saves hold spot ids, never positions.
local yardMid = (yardZ1 + yardZ2) / 2

-- Index decor spots (F48): each area's piece and its gold piece share one, since the gold one stands in for it.
local INDEX_SPOTS: { [string]: Point } = {
	-- the print, on the bare right wall facing into the room (#1187: on the back wall it hung over the back window,
	-- with decor spot 8's tall pieces in front; Model-Agent's wall_fit.py found no clash here)
	alley = { x = halfW - 0.2, y = 3.8, z = 6, rotY = 90 },
	park = { x = halfW - 1.2, y = 0, z = -2.43, rotY = 90 }, -- the bench, against the right wall facing the tables
	neighbourhood = { x = -halfW + 1.2, y = 0, z = -4.25 }, -- the planter, left wall between the window and the tank
	-- the lamp, in the back left corner (0.15 further out since #917: its cap touched the wainscot's rail)
	woods = { x = -halfW + 1.35, y = 0, z = halfD - 1.35 },
	sewer = { x = halfW - 1.4, y = 0, z = halfD - 1.4 }, -- the fountain, in the back right corner
}

-- Greeters (#1145): this far past each door jamb, so the cat clears the open leaf (a stud and a half of thickness and
-- paw room), and this far in from the front wall; each is turned to face the middle of the doorway. #1417 (the friend,
-- 11-05): 7 in (was 5), a little further into the cafe. Model-Agent's fit check: the cat (z -10.8 to -9.2) stays 2.5
-- clear of the front tables' chairs (x 8.52 out), 2.7 in front of the first row's lane (z -6.56) and 4 behind the
-- front decor spots; the aisle (x -2 to 2) is untouched.
local FRONT_DOOR = { x = 0, y = 0, z = -halfD } :: Point
local GREETER_OUT = 1.8
local GREETER_IN = 7

local function greeterSlot(side: number): Point
	local x = FRONT_DOOR.x + side * (W.DoorWidth / 2 + GREETER_OUT)
	local z = FRONT_DOOR.z + GREETER_IN
	-- a cat's front is -Z; turn it about Y until that points at the door
	local rotY = math.deg(math.atan2(x - FRONT_DOOR.x, z - FRONT_DOOR.z))
	return { x = x, y = 0, z = z, rotY = rotY }
end

Layout.plot = {
	door = FRONT_DOOR,
	entry = { x = 0, y = 0, z = -halfD - 1 - W.FrontGardenDepth - 1 } :: Point, -- customer start, on the sidewalk
	sign = { x = 0, y = 7.5, z = -halfD - 0.3 } :: Point,
	counter = { x = 0, y = 0, z = halfD - 3 } :: Point,
	-- On the counter's espresso plate (its top is 3 up); the level 3 machine fills it to the till.
	espresso = { x = 3, y = 3, z = halfD - 3 } :: Point,
	-- F90 (cats-make-orders.md section 3): the oven (CatCafe_Cafe_Oven, 3.2 wide, 2.9 deep, front -Z) against the
	-- back wall past the counter's right end, x 4.5 to 7.7 and z 10.8 to the wall, under the back wall shelf; the
	-- gap behind the counter itself is 1.5 deep. Barista 3 sits in front of it, clear of its door, and decor spots 5 and
	-- 8 moved right.
	oven = { x = 6.1, y = 0, z = halfD - 1.75 } :: Point,
	-- F90 (section 2), client only: where a made dish waits for the Waiter (on the counter top in front of the till,
	-- clear of the tip jar and the level 3 espresso machine), where the Waiter stands to take it (on the floor at the
	-- counter's front, clear of the Cat Collector) and where a swept coin bag goes (on the till's keypad).
	pass = { x = 1.2, y = 3, z = halfD - 3.75 } :: Point,
	pickup = { x = 2.6, y = 0, z = halfD - 5.15 } :: Point,
	tillStack = { x = 1.2, y = 3.45, z = halfD - 2.9 } :: Point,

	-- Where a working cat sits, per role slot: baristas at the counter, waiters between the tables, greeters inside
	-- the door, entertainers on the cat trees. A seated cat (the _Sit body) has its pivot on the point and fills from
	-- 0.6 left of it (its tail) to 0.5 right and from 0.65 in front to 0.6 behind; a Scale 1.2 cat (Maine Coon,
	-- Ragdoll) 0.75 left, 0.6 right, 0.78 in front and 0.76 behind. The counter's top (3 up) holds the pastry case
	-- (x -3.75 to -1.05), a saucer and a tip jar at the front, the till (0.7 to 1.7) and the espresso machine, so the
	-- first barista sits on the gap behind the saucer and the tip jar, and the later two on the floor at either end
	-- of the counter (Derek 2026-10-27: models sinking into each other).
	spots = {
		barista_1 = { x = -0.2, y = 3, z = halfD - 2.55 },
		barista_2 = { x = -5.2, y = 0, z = halfD - 3 },
		-- F90: in front of the oven, clear of its door's swing (hinged 0.6 up at z 11.05, 1.75 long, so open flat it
		-- reaches z 9.3; Model-Agent); was 5.2, halfD - 3
		barista_3 = { x = 6.2, y = 0, z = halfD - 5.5 },
		waiter_1 = { x = -5.5, y = 0, z = -3.04 },
		waiter_2 = { x = 5.5, y = 0, z = -3.04 },
		waiter_3 = { x = 5.5, y = 0, z = 4.25 }, -- beside the aisle, off the door to counter walk (was 0, 4.5)
		-- Derek 2026-11-04 (#1145): either side of the walkway, inside the entrance and turned toward the door, worked
		-- out from the front door's own point and width (GREETER_OUT, GREETER_IN) so they hold if the door moves. Each
		-- front leaf opens to stand across its half of the doorway, so these stand past the jambs, clear of that swing.
		greeter_1 = greeterSlot(-1),
		greeter_2 = greeterSlot(1),
		-- the cat tree's top cushion, at its sit point (-0.5, 4.47, -0.4 from the tree's pivot)
		entertainer_1 = { x = -17.61, y = 4.47, z = 9.31 },
		entertainer_2 = { x = 16.61, y = 4.47, z = 9.31 },
	} :: { [string]: Point },

	-- Station furniture under a slot, for the roles that have one (Catalog.spotFurniture)
	spotFurniture = {
		entertainer_1 = { x = -17.11, y = 0, z = 9.71 },
		entertainer_2 = { x = 17.11, y = 0, z = 9.71 },
	} :: { [string]: Point },

	decorAnchors = {
		plants = { x = 15, y = 1, z = -halfD + 0.7 }, -- on the right window's sill (its centre halfW - 7), clear of its curtain
		rug = { x = 0, y = 0, z = -2.43 },
		-- flat on the right wall over the Alleyway print (#1187: on the back wall it covered the back window); in front
		-- of the menu board it hid the menu (Derek's 10-30 playtest). The sign's back is its pivot plane
		neon_sign = { x = halfW - 0.2, y = 6.2, z = 6, rotY = 90 },
		fish_tank = { x = -halfW + 2, y = 0, z = 0, rotY = 90 },
		index_alley = INDEX_SPOTS.alley,
		index_park = INDEX_SPOTS.park,
		index_neighbourhood = INDEX_SPOTS.neighbourhood,
		index_woods = INDEX_SPOTS.woods,
		index_sewer = INDEX_SPOTS.sewer,
	} :: { [string]: Point },

	-- Decor spots (F53, golden-fish.md section 4): where crate furniture and decorations stand, filled in order, so
	-- the first two are the Tier 1 ones (DecorSpots 2, 3, 4, 5, 6 by tier, plus 2 from the Extra Decor Spot perk).
	-- Against the walls clear of the tables, the cat spots, the nap spots and the back door, facing into the room;
	-- a piece's pivot is its base centre with its front toward -Z. The F48 Index pieces keep their own spots. Since #917
	-- they stand 1.6 off their wall (the big pieces touched the wainscot rail at 1.4) and the front two sit between the
	-- door and the windows, not over the sills.
	decorSpots = {
		{ x = -7.2, y = 0, z = -halfD + 1.6, rotY = 180 }, -- front wall, between the door and the left window
		{ x = 7.2, y = 0, z = -halfD + 1.6, rotY = 180 }, -- front wall, between the door and the right window
		{ x = halfW - 1.6, y = 0, z = -7.89, rotY = 90 }, -- right wall, between the window corner and the bench
		{ x = -halfW + 1.6, y = 0, z = -9.11, rotY = -90 }, -- left wall, between the window corner and the planter
		{ x = 10.62, y = 0, z = halfD - 1.6, rotY = 0 }, -- back wall, right of the oven (F90)
		{ x = -14.6, y = 0, z = halfD - 1.6, rotY = 0 }, -- back wall, left of the back door
		{ x = -halfW + 1.6, y = 0, z = 4.86, rotY = -90 }, -- left wall, between the fish tank and the cat tree
		{ x = 15.61, y = 0, z = halfD - 1.6, rotY = 0 }, -- back wall, right of the oven beyond the first (F90)
	} :: { Point },

	-- Two columns of three, either side of the aisle from the front door to the counter (Derek 2026-10-28 01:27: the
	-- second table stood in the doorway where everyone walks): a table and its two chairs reach 3.7 either side of
	-- its x and 2.1 in front and behind, so the aisle is clear from x -8.52 to 8.52. The back left table sits half a
	-- stud further out, so the walk from the back door to the front door passes its chair a stud clear (review N237). Filled in order, two a tier: front row, middle row, back
	-- row. Each row's `lane` is the walkway between it and the next row, which customers take to the outer chair.
	tables = {
		{ x = -12.22, y = 0, z = -10.32, lane = -6.56 },
		{ x = 12.22, y = 0, z = -10.32, lane = -6.56 },
		{ x = -12.22, y = 0, z = -2.73, lane = 1.09 },
		{ x = 12.22, y = 0, z = -2.73, lane = 1.09 },
		{ x = -12.83, y = 0, z = 4.86, lane = 1.09 },
		{ x = 12.22, y = 0, z = 4.86, lane = 1.09 },
	} :: { TableSpot },
	-- How far either side of the aisle's middle customers walk to and from a lane, clear of the waiters at 5.5.
	aisleX = 2,

	-- The rich customer's coin pile (data-model section 12): on top of table 1 (2.6 tall), where the rich customer
	-- sits. The UI's gold marker floats over it and ClaimRichTip measures range from it.
	richTip = { x = -12.22, y = 2.7, z = -10.32 } :: Point,

	-- The back door, between the counter and the left cat tree, opens from Tier 1 onto the yard; the yard's gate
	-- lines up with it so the way out to the back alley is straight.
	backDoor = { x = -8, width = 6, height = 7.5 },
	-- Where a respawn outside the wild areas lands (Derek 2026-10-28 01:17, "resetting made me fully reload the
	-- game"; CannonService): just inside the back door, 3 studs in from the back wall, facing it. y is the root's
	-- height above the floor, as homeLanding's.
	respawnSpot = { x = -8, y = 3, z = halfD - 3 } :: Point,
	-- F92 (playing-together.md section 5): where a player who joined through a pal's invite or by following them
	-- first stands, on the path 2.5 studs out from that pal's front door, facing the street (CannonService). y as
	-- respawnSpot's.
	palArrival = { x = 0, y = 3, z = -halfD - 2.5 } :: Point,

	-- The front garden strip between the sidewalk and the front wall, and the path through it to the door.
	frontGarden = {
		x1 = -halfW - 1,
		z1 = -halfD - 1 - W.FrontGardenDepth,
		x2 = halfW + 1,
		z2 = -halfD - 1,
	} :: Rect,
	frontPath = { x1 = -2.5, z1 = -halfD - 1 - W.FrontGardenDepth, x2 = 2.5, z2 = -halfD - 1 } :: Rect,
	-- The Lucky Cat statue (F88, luck-and-rare-moments.md section 1): in the front garden left of the path, by the
	-- door, its front to the street. CafeService stands CatCafe_Plot_LuckyCat_<level> here, level 0 a plinth and sign.
	luckyCat = { x = -5.1, y = 0, z = -halfD - 2.1 } :: Point,
	-- The front lawn (F91, front-lawn.md section 5; Model-Agent's numbers, style guide section 13). The six lawn spots
	-- are shared (the client's rings need them too); LawnBuilder stands each spot's piece at its point. The path
	-- style lies over the shell's own path, 7 wide by 5 deep with its centre at lawnPath on the floor's level; the
	-- fence style runs along the sidewalk edge at fenceLine, both halves from the path's gap (x 3.9) to the plot's
	-- edge (x 23), its pivot the gap's centre on the grass top.
	lawnSpots = Lawn.SPOTS :: { Types.LawnSpot },
	lawnPath = { x = 0, y = 0, z = -halfD - 1 - W.FrontGardenDepth / 2 } :: Point,
	fenceLine = {
		x = 0,
		y = -0.05,
		z = -halfD - 1 - W.FrontGardenDepth + 0.15,
		gapHalfWidth = 3.9,
		halfWidth = 23,
	},

	-- The bait bowl (data-model section 8; v0.5 F44, Gavin: "The bowl sits out side of your cafe") on the back
	-- step, right of the back door and under the shell's back lamp, facing the yard gate and the Alleyway the strays
	-- come from. Clear of the door's mat, the path from the door to the gate and the Tier 4 planter; the cat stands
	-- beside it with its head over the bowl.
	baitBowl = { x = -2.6, y = 0, z = halfD + 2.6 } :: Point,
	baitCat = { x = -1, y = 0, z = halfD + 2.6, rotY = 90 } :: Point,
	-- The Second Bait Bowl (#1161) on the same step, further right, its cat on its right the same way, so the two
	-- pairs read as bowl, cat, bowl, cat from the door: 2 studs between the first cat and the second bowl.
	baitBowl2 = { x = 1, y = 0, z = halfD + 2.6 } :: Point,
	baitCat2 = { x = 2.6, y = 0, z = halfD + 2.6, rotY = 90 } :: Point,

	-- The patio yard behind the back wall, fenced. Its gate onto the back alley closed with the back alley (v4, F84);
	-- yardGate is where it stood, and the path from the back door to it stays clear of the yard's dressing.
	yard = { x1 = -halfW - 1, z1 = yardZ1, x2 = halfW + 1, z2 = yardZ2 } :: Rect,
	yardGate = { x1 = -11, x2 = -5 },
	fenceHeight = 3,

	-- Cafe expansions in the yard (data-model section 5b): expansion n opens at Tier n + 1 as a patio section.
	-- Each is a floor rectangle from (x1, z1) to (x2, z2), plot-local, so deeper is nearer the back alley.
	expansions = {
		{ x1 = -halfW, z1 = yardZ1, x2 = 0, z2 = yardMid },
		{ x1 = 0, z1 = yardZ1, x2 = halfW, z2 = yardMid },
		{ x1 = -halfW, z1 = yardMid, x2 = 0, z2 = yardZ2 },
		{ x1 = 0, z1 = yardMid, x2 = halfW, z2 = yardZ2 },
	} :: { Rect },

	-- Two seats per table, relative to the table anchor; rotY faces the chair toward the table
	seatOffsets = {
		{ x = -2.4, y = 0, z = 0, rotY = -90 },
		{ x = 2.4, y = 0, z = 0, rotY = 90 },
	} :: { Point },

	-- Where customers stand to order, in front of the counter (world-and-feel.md section 4).
	orderPoint = { x = 0, y = 0, z = halfD - 6 } :: Point,
	-- Where the Cat Collector waits (F63, data-model section 12b: "at the counter"): beside the order point, clear of
	-- the queue's 3 studs either side of it, facing into the room so the owner sees him from the door. AnswerCollector
	-- counts CollectorRangeStuds from here.
	collectorSpot = { x = 4.5, y = 0, z = halfD - 6 } :: Point,

	-- Where cats without a job nap, so the collection is on show (world-and-feel.md section 4, F37), highest rating
	-- first. Each is a cat bed in an owned cafe (Derek's 10-28 to 10-30 notes: cats slept on the floor), placed by
	-- Model-Agent's fit of 2026-11-02 clear of the shell, the F79 beds, decor spots, trees, tables and stations: under
	-- the front window left of the door, the front right window corner, beside the right cat tree and at the
	-- counter's right end. Each turns rotY degrees like the F79 beds so its front (-Z) and the cat on it face into the
	-- room. WorldBuilder stands the bed on the point and moves the nap anchor up to the bed's Sleep point.
	napSpots = {
		{ x = -13.5, y = 0, z = -15.1, rotY = 180 }, -- under the front left window (swapped with decor spot 1, #917)
		{ x = 18.9, y = 0, z = -12.9, rotY = 135 },
		{ x = 19.5, y = 0, z = 5.47, rotY = 90 },
		{ x = 12.28, y = 0, z = 12.4, rotY = 0 }, -- 0.6 further out, clear of a big piece on decor spot 5
	} :: { Point },

	-- The cat beds (F79, data-model 12c v0.13.13, Model-Agent's fit in #511): a CatCafe_Furniture_CatBed at each from
	-- its tier, out by day as furniture, turned rotY degrees so its front (-Z) faces into the room. Two at Tier 3,
	-- four at Tier 4 and six at Tier 5, exactly where the working slots outrun the cat trees' four pedestals.
	beds = {
		{ id = "bed_1", x = -20.3, y = 0, z = -15.4, rotY = -135, tier = 3 },
		{ id = "bed_2", x = 20.3, y = 0, z = -15.4, rotY = 135, tier = 3 },
		{ id = "bed_3", x = -17.6, y = 0, z = -15.4, rotY = 180, tier = 4 },
		{ id = "bed_4", x = 20.4, y = 0, z = 1.57, rotY = 90, tier = 4 }, -- past the Park bench's end
		{ id = "bed_5", x = -20.4, y = 0, z = 10.32, rotY = -90, tier = 5 },
		{ id = "bed_6", x = 20.4, y = 0, z = 10.32, rotY = 90, tier = 5 },
	} :: { BedSpot },
}

-- Shared areas, in world space. y is the floor top.

-- The Alleyway (data-model section 9, town-layout-v3.md section 7e; v4, F84, hometown-cannon.md section 6a): two 30
-- stud back alleys side by side, far out in the wild like every catching area since Derek's 2026-10-28 14:09 "no
-- alleyway should move also all locations should move". It is laid out below in lane space, the numbers the lanes
-- had behind the cafes until v4 (|x| AlleyInnerX to AlleyOuterX, AlleySouthZ to AlleyNorthZ), and moved into the
-- wild at the end (laneX, laneZ): each lane AlleyLaneShift nearer the set's middle (AlleyCenterX, AlleyCenterZ).
-- F85 (Derek 2026-11-02: "just make it one big one"): the 30 stud block of building backs that stood between the two
-- lanes went, so the Alleyway is one lane 90 wide with the buildings along both outer walls. The camp lies across its
-- north end, one way in under the street arch (AlleyWayHalfWidth either side of the middle).
local AI, AO = W.AlleyInnerX, W.AlleyOuterX
local AS, AN = W.AlleySouthZ, W.AlleyNorthZ
local MID = (AI + AO) / 2 -- the middle of a back alley's width
local AX, AZ = W.AlleyCenterX, W.AlleyCenterZ
local SHIFT = W.AlleyLaneShift

-- Lane space to world space. Everything in the set stands at |x| SHIFT or more in lane space, the block's and the
-- passage's edges included, so each side keeps its sign and a rect across the middle keeps its order.
local function laneX(x: number): number
	return AX + x - math.sign(x) * SHIFT
end
local function laneZ(z: number): number
	return AZ + z
end

-- Two lane spawn points behind every cafe's old place, in plot order (plot p's are points 2p - 1 and 2p). Then the
-- nooks, where Epic and rarer strays go, all at the far (south) end: four either side of the middle, 6 studs off the
-- south end wall (two where each old lane's dead end was, two where the passage through the block was), at least 2
-- inside the roam rect and at least 10 studs from every lane point. Then the eight `near` points just past the camp's
-- way in for the tutorial stray (data-model section 9, v0.13.18), 10 and then 16 studs into the Alleyway: 5 studs
-- right (+X for a player facing south into it) then 5 left of the middle, then the same 15 studs out (F85, one way in
-- since the block went). Plot p owns near point p, so plot 1's stray waits where the intro shows it.
local NOOKS = { { 82, -119 }, { 68, -119 }, { SHIFT + 5, AS + 6 }, { SHIFT + 11, AS + 6 } }
local NEAR_IN = { 10, 16 }
local NEAR_ACROSS = { 5, 15 }
-- An x across the whole Alleyway (0 its middle) in lane space, which has no middle: |x| SHIFT more, the same side.
local function fromMiddle(x: number): number
	return x + math.sign(x) * SHIFT
end
-- the outer lane points of the cafes nearest the camp end stop this far in, 4 or more studs clear of the near points
local LANE_NORTH_MAX = AN - NEAR_IN[2] - 3.5
-- The |z| of the v3 cafe rows (36 wide with 8 stud passages: 58 by the square, 102 one row out), which the lane points
-- keep in lane space: the Alleyway left the town in v4 and its set and dressing are laid out round those old places,
-- so the bigger cafes (#917) move nothing here.
local LANE_ROW_Z = { 58, 102 }
local function alleySpawnPoints(): { Point }
	local points: { Point } = {}
	for index = 1, W.PlotCount do
		local placement = Layout.plotPlacement(index)
		local side = placement.side
		local plotZ = math.sign(placement.z) * LANE_ROW_Z[math.floor((index - 1) / 4) + 1]
		table.insert(points, { x = side * (AI + 7), y = 0.1, z = plotZ - 7, zone = "lane" })
		local z = math.min(plotZ + 9, LANE_NORTH_MAX)
		table.insert(points, { x = side * (AO - 7), y = 0.1, z = z, zone = "lane" })
	end
	for _, side in { -1, 1 } do
		for _, xz in NOOKS do
			table.insert(points, { x = side * xz[1], y = 0.1, z = xz[2], zone = "nook" })
		end
	end
	for _, across in NEAR_ACROSS do
		for _, into in NEAR_IN do
			for _, right in { 1, -1 } do
				table.insert(points, {
					x = fromMiddle(right * across),
					y = 0.1,
					z = AN - into,
					rotY = 180,
					zone = "near",
				})
			end
		end
	end
	return points
end

-- A piece against an outer wall of the Alleyway (side -1 west, 1 east), front (-Z) turned into the lane. The
-- alley kit's building backs pivot on their back plane, so they stand right on the wall's inner face. `along` and
-- `out` move a companion prop in the piece's own space: +along is its +X, negative `out` comes off the wall.
local function onOuterWall(
	asset: string,
	side: number,
	z: number,
	along: number?,
	out: number?
): Prop
	return {
		asset = asset,
		x = side * (AO + (out or 0)),
		z = z - side * (along or 0),
		rotY = side * 90,
	}
end

-- Buildings (30.6 wide) along each back alley's outer wall, so the lane reads as a street of different buildings
-- rather than a bare wall (world-and-feel.md section 2; Model-Agent #535 made the repeated backs and the staff door
-- into eight full buildings for Derek): three either side of where the Woods or Sewer gate stood until v4, from
-- clear of the end wall's piece to clear of the gate's model (42 studs wide with its pillars), evenly spaced, and
-- since v4 a seventh in the middle, where the gate was (MIDDLE_BUILDING).
local BACK_WIDTH = 30.6
local GATE_CLEAR = 21.2
local END_CLEAR = 5 -- the end wall pieces' room (the fire escape that stood there was 5 deep); the slots stay put
local BACK_SLOTS: { number } = (function(): { number }
	local first, last = AS + END_CLEAR + BACK_WIDTH / 2, -GATE_CLEAR - BACK_WIDTH / 2
	local count = math.floor((last - first) / BACK_WIDTH) + 1
	local slots: { number } = {}
	for n = 0, count - 1 do
		table.insert(slots, first + n * (last - first) / (count - 1))
	end
	for n = count, 1, -1 do -- the north run mirrors the south one
		table.insert(slots, -slots[n])
	end
	return slots
end)()
local GATE_SLOT = #BACK_SLOTS // 2 -- the last back south of the old gate; the next one is the first north of it
local MIDDLE_BUILDING = { [-1] = "ClockHouse", [1] = "Bakery" }
-- The Warehouse's fire escape's first landing (top 9.35) is reached from the crate stack's tall column (top 7.7),
-- which stands just past the landing's open end at local x -8 (asset manifest, ledges_roblox).
local CRATES_ALONG, CRATES_OUT = -12, -2.8
-- A building pivots on its back plane with its body 3 deep, so it stands this far out over the outer wall (1 thick)
-- and its facade lands where the old backs' faces were: the back plane stays inside the wall. On the south end wall
-- it stands END_OUT out, its back plane 0.25 inside the wall the same way, not on the wall's far face where the two
-- would flicker (reviewer N255).
local BUILDING_OUT, END_OUT = 2.25, 0.75

local function building(name: string): string
	return "CatCafe_Alley_Building_" .. name
end

-- F85's low blockers as one lane (hometown-cannon.md section 6b; Model-Agent #875, area-sets.md "The Alleyway as one
-- lane"): four rows right across, each one model at the middle, its pile segments carrying their own invisible
-- _Barrier (so nobody jumps a pile) and its lamp posts at the way through, which moves from row to row: the middle,
-- the west side, the east side (the east Warehouse's crate stack stands in it, 21 left to walk) and the middle again.
-- Each row stands in a gap between buildings; the string lights hang in the other gaps.
local BLOCKER_ROWS: { { asset: string, z: number } } = {
	{ asset = "CatCafe_Alley_Blocker_RowCamp", z = 88.025 },
	{ asset = "CatCafe_Alley_Blocker_RowVan", z = 18.25 },
	{ asset = "CatCafe_Alley_Blocker_RowSkip", z = -53.675 },
	{ asset = "CatCafe_Alley_Blocker_RowFar", z = -88.025 },
}
local function blockerRowAt(z: number): boolean
	for _, row in BLOCKER_ROWS do
		if math.abs(row.z - z) < 1 then
			return true
		end
	end
	return false
end
-- the buildings across the south end, either side of the middle and in it (F85: 30.8 wide with their sills)
local END_SIDE = 31

local function alleyDressing(): { Prop }
	local props: { Prop } = {}
	local function add(prop: Prop)
		table.insert(props, prop)
	end
	-- south to north (Model-Agent's rows); the loose props and rescue spots below stand in front of windows and
	-- doors, never the Warehouse's fire escape, and no Warehouse's crates reach the middle
	local rows = {
		[-1] = { "Bakery", "Warehouse", "Townhouses", "MusicShop", "Apartments", "Grocer" },
		[1] = { "Grocer", "Warehouse", "Apartments", "NarrowHouses", "Townhouses", "MusicShop" },
	}
	for _, side in { -1, 1 } do
		for slot, z in BACK_SLOTS do
			local piece = rows[side][slot] or "Townhouses"
			add(onOuterWall(building(piece), side, z, 0, BUILDING_OUT))
			if piece == "Warehouse" then
				add(onOuterWall("CatCafe_Alley_CrateStack", side, z, CRATES_ALONG, CRATES_OUT))
			end
		end
		add(onOuterWall(building(MIDDLE_BUILDING[side]), side, 0, 0, BUILDING_OUT))
		-- a laundry line in front of a windowed back
		add({
			asset = "CatCafe_Alley_LaundryLine",
			x = side * (MID - 0.4),
			z = if side < 0 then BACK_SLOTS[5] else BACK_SLOTS[3],
		})
		-- the south end closes on a building either side, where the old lanes' staff doors stood
		add({
			asset = building(if side < 0 then "NarrowHouses" else "Grocer"),
			x = fromMiddle(side * END_SIDE),
			z = AS - END_OUT,
			rotY = 180,
		})
	end
	-- and the Clock House in the middle, where the passage through the block came out: the landmark at the end of
	-- the one lane (F85, Model-Agent)
	add({ asset = building("ClockHouse"), x = 0, z = AS - END_OUT, rotY = 180 })
	-- string lights right across in the gaps between buildings, a blocker row in the others (F85: one string, wall to
	-- wall, where each lane had its own)
	for slot = 1, #BACK_SLOTS - 1 do
		local gaps: { number } = if slot == GATE_SLOT
			then { BACK_SLOTS[slot] / 2, BACK_SLOTS[slot + 1] / 2 } -- either side of the middle building
			else { (BACK_SLOTS[slot] + BACK_SLOTS[slot + 1]) / 2 }
		for _, z in gaps do
			if not blockerRowAt(z) then
				add({ asset = "CatCafe_Alley_StringLightsWide", x = 0, z = z })
			end
		end
	end
	for _, row in BLOCKER_ROWS do
		add({ asset = row.asset, x = 0, z = row.z, rotY = 0 })
	end
	return props
end

-- A lane-space Point, Rect, Prop, RescuePoint or Arch moved into the wild.
local function lanePoint(point: Point): Point
	local moved = table.clone(point)
	moved.x, moved.z = laneX(point.x), laneZ(point.z)
	return moved
end
local function laneRect(rect: Rect): Rect
	return { x1 = laneX(rect.x1), z1 = laneZ(rect.z1), x2 = laneX(rect.x2), z2 = laneZ(rect.z2) }
end
local function laneAll<T>(list: { T }, move: (T) -> T): { T }
	local moved: { T } = {}
	for _, item in list do
		table.insert(moved, move(item))
	end
	return moved
end
local function laneProp(prop: Prop): Prop
	local moved = table.clone(prop)
	moved.x, moved.z = laneX(prop.x), laneZ(prop.z)
	return moved
end
local function laneTrap(point: RescuePoint): RescuePoint
	local moved = table.clone(point)
	moved.x, moved.z = laneX(point.x), laneZ(point.z)
	return moved
end
local function laneArch(arch: Arch): Arch
	local moved = table.clone(arch)
	moved.x, moved.z = laneX(arch.x), laneZ(arch.z)
	return moved
end

Layout.alley = {
	floorY = 0.1,
	center = { x = AX, y = 0, z = laneZ((AS + AN) / 2) },
	halfWidth = AO - SHIFT,
	halfDepth = (AN - AS) / 2,
	-- the camp's line across the north end (Layout.camps); the alley has no gate model of its own, and its one way in
	-- is the street arch's opening
	gateZ = laneZ(AN),
	openingHalfWidth = W.AlleyWayHalfWidth,
	-- one floor wall to wall (F85: the block between the old lanes went)
	rects = laneAll({ { x1 = -AO, z1 = AS, x2 = AO, z2 = AN } } :: { Rect }, laneRect),
	walls = laneAll(
		{
			-- the outer walls, up to the camp, where its own side walls carry on
			{ x1 = -AO - 1, z1 = AS - 1, x2 = -AO, z2 = AN },
			{ x1 = AO, z1 = AS - 1, x2 = AO + 1, z2 = AN },
			-- the south end wall right across
			{ x1 = -AO, z1 = AS - 1, x2 = AO, z2 = AS },
		} :: { Rect },
		laneRect
	),
	-- Strays keep off the strip along the outer walls where the buildings, the Warehouses' fire escapes and the crate
	-- stacks stand (up to 5 studs deep), 4 off the south end wall and 6 short of the camp's line (reviewer S84); the
	-- nooks stay 2 or more inside.
	roam = laneAll(
		{ { x1 = -AO + 5, z1 = AS + 4, x2 = AO - 5, z2 = AN - 6 } } :: { Rect },
		laneRect
	),
	wallHeight = 10,
	-- the name arch over the one way in from the camp, front (-Z) toward the camp (F85: one, where the two lanes'
	-- arches stood)
	arches = laneAll(
		{
			{
				x = 0,
				z = AN,
				span = 2 * W.AlleyWayHalfWidth,
				label = "THE ALLEYWAY",
				asset = "CatCafe_Alley_ArchStreet",
				rotY = 180,
			},
		} :: { Arch },
		laneArch
	),
	spawnPoints = laneAll(alleySpawnPoints(), lanePoint),
	rescueSpots = laneAll(
		{
			-- A trash bin in each back alley and the garbage bags on the west outer wall between the cafe rows, each in
			-- front of a windowed back, lid toward the lane, and 9 studs from every spawn point so a stray there never
			-- takes the rescue's prompt (reviewer N77). The bins sit 0.15 down onto the floor (QA world scan G6).
			{
				prop = "CatCafe_Alley_TrashBin",
				trap = "trash_bin",
				x = -AO + 4.5,
				y = -0.15,
				z = -36,
				rotY = -90,
			},
			{
				prop = "CatCafe_Alley_TrashBin",
				trap = "trash_bin",
				x = AO - 4.5,
				y = -0.15,
				z = -40,
				rotY = 90,
			},
			{
				prop = "CatCafe_Alley_GarbageBags",
				trap = "garbage_bag",
				x = -AO + 4.5,
				z = 80,
				rotY = -90,
			},
		} :: { RescuePoint },
		laneTrap
	),
	-- The buildings, crate stacks, lights and laundry from alleyDressing, then the loose props in front of them: clear
	-- of the buildings' fronts and the Warehouses' fire escapes, and of the lane spawn points.
	props = laneAll(
		(function(): { Prop }
			local props = alleyDressing()
			for _, prop in
				{
					-- West back alley: a dumpster corner at each end, a bin, a crate, puddles. The north dumpster sits
					-- 0.3 clear of the Grocer's window frame (QA world scan G1).
					{ asset = "CatCafe_Alley_Dumpster", x = -AO + 4.8, z = -104, rotY = 90 },
					{ asset = "CatCafe_Alley_GarbageBags", x = -AO + 4.6, z = -111, rotY = 90 },
					{ asset = "CatCafe_Alley_Dumpster", x = -AO + 3, z = AN - 7.8, rotY = 90 },
					{ asset = "CatCafe_Alley_TrashCan", x = -AO + 3.8, z = 47 },
					{ asset = "CatCafe_Alley_Crate", x = -AO + 4.5, z = 55 },
					{ asset = "CatCafe_Alley_Puddle", x = -AI - 13, z = -40 },
					{ asset = "CatCafe_Alley_Puddle", x = -AI - 11, z = 40 },
					-- East back alley: a dumpster corner at the south end, crates by the Music Shop at the north end
					-- (the last one 0.4 off its wall, QA world scan G2)
					{ asset = "CatCafe_Alley_Dumpster", x = AO - 4.8, z = -104, rotY = -90 },
					{ asset = "CatCafe_Alley_GarbageBags", x = AO - 4.6, z = -111, rotY = -90 },
					{ asset = "CatCafe_Alley_TrashCan", x = AO - 3.8, z = -28 },
					{ asset = "CatCafe_Alley_Crate", x = AO - 3.8, z = 100 },
					{ asset = "CatCafe_Alley_Crate", x = AO - 4, z = AN - 7 },
					{ asset = "CatCafe_Alley_Crate", x = AO - 2.9, z = AN - 9.5 },
					{ asset = "CatCafe_Alley_Puddle", x = AI + 17, z = -12 },
					{ asset = "CatCafe_Alley_Puddle", x = AI + 12, z = 26 },
				} :: { Prop }
			do
				table.insert(props, prop)
			end
			return props
		end)(),
		laneProp
	),
} :: AreaSpec

-- The turn (degrees about Y) that faces a gate's front toward the town, from where the gate is (Layout.gateTurn).
local function townTurn(cx: number, cz: number, gateX: number?, gateZ: number?): number
	if gateX ~= nil then
		return if gateX > cx then -90 else 90
	end
	return if gateZ ~= nil and gateZ > cz then 180 else 0
end

-- An area kit set's spots (manifest.json points_roblox: x, height above the floor and z in the set's own space) in
-- world space, for the set WorldBuilder places at (cx, floorY, cz) turned `turn` degrees: CFrame.Angles(0, rad(turn),
-- 0) takes (x, z) to (x cos + z sin, -x sin + z cos). `zone` tags them all (a v3.2 set's `near` or `deep` spots).
local function setPoints(
	cx: number,
	cz: number,
	turn: number,
	floorY: number,
	spots: { { number } },
	zone: string?
): { Point }
	local c, s = math.cos(math.rad(turn)), math.sin(math.rad(turn))
	local points: { Point } = {}
	for _, spot in spots do
		local x, z = spot[1], spot[3]
		table.insert(points, {
			x = cx + x * c + z * s,
			y = floorY + spot[2],
			z = cz - x * s + z * c,
			rotY = turn,
			zone = zone,
		})
	end
	return points
end

-- A trap built into an area kit set (a `trap_` spot): no prop of its own, the stuck cat by Layout.setStuckPoses at
-- the spot, turned with the set and by `pieceTurn`, the trap piece's own turn in the set's space (a v3.2 spot's
-- fifth number).
local function setTrap(
	cx: number,
	cz: number,
	turn: number,
	trap: string,
	spot: { number },
	pieceTurn: number?
): RescuePoint
	local point = setPoints(cx, cz, turn, 0, { spot })[1]
	return { trap = trap, x = point.x, y = spot[2], z = point.z, rotY = turn + (pieceTurn or 0) }
end

-- A rescue prop the world stands at a set's trap spot (the Park's, area-sets.md): `propTurn` turns the prop in the
-- set's own space, so in the world it turns by the set's turn as well.
local function setPropTrap(
	cx: number,
	cz: number,
	turn: number,
	prop: string,
	trap: string,
	spot: { number },
	propTurn: number
): RescuePoint
	local point = setPoints(cx, cz, turn, 0, { spot })[1]
	return {
		prop = prop,
		trap = trap,
		x = point.x,
		y = spot[2],
		z = point.z,
		rotY = (turn + propTurn) % 360,
	}
end

-- The long Park (F85, hometown-cannon.md section 6b; Model-Agent #799, area-sets.md "The Park (F85)"): a 120 x 310
-- wild part with its camp 30 more in front of the gate, so the run home with a cat is long and in view. Its set,
-- camp, gate, night fence and backdrop carry the F85 suffix (artSuffix). Four blockers cross the width with their
-- gaps on alternating sides: a box hedge, a railing, the stream (crossed by the footbridge) and a second hedge, to
-- the bandstand at the far end. Its cat spots are `near` on the camp half and `deep` on the far half, where Epic and
-- rarer strays wait (CatService). Its rescue trees and bins stand at the set's trap spots, four of the five deep and
-- none within 100 studs of the camp.
local PX, PZ = 0, W.ParkCenterZ
local PGATE = PZ + W.ParkDepth / 2 -- its north side, toward the town
local PTURN = townTurn(PX, PZ, nil, PGATE)
Layout.park = {
	floorY = 0.1,
	center = { x = PX, y = 0, z = PZ },
	halfWidth = W.ParkWidth / 2,
	halfDepth = W.ParkDepth / 2,
	gateZ = PGATE,
	openingHalfWidth = W.CampOpeningWidth / 2,
	set = "CatCafe_Park_SetF85",
	artSuffix = "F85",
	spawnPoints = (function(): { Point }
		local points = setPoints(PX, PZ, PTURN, 0.1, {
			{ -4, 0, -145 }, -- plaza
			{ 18, 0.62, -143 }, -- flowerbed
			{ 32, 0.62, -136 },
			{ 46, 0.62, -130 },
			{ 49.6, 0, -141 }, -- bench
			{ -24.56, 0, -146.96 }, -- picnic
			{ -41.17, 0, -141.91 },
			{ -45, 0.06, -124 }, -- blanket
			{ -6, 0.06, -10 },
			{ -44.5, 0, -147.5 }, -- oak (Model-Agent 11-02: moved from -44, -144, 3.5 from a picnic table's)
			{ 42, 0, -148 }, -- blossom
			{ 6, 1.2, -80 }, -- jetty
			{ -19.56, 0, -90.9 }, -- bank
			{ 2.5, 0, -62.15 },
			{ -40, 0, -98 }, -- willow
			{ 42.5, 0, -86.5 }, -- kiosk
			{ -46, 0, -60 }, -- lawn
			{ -27, 0.5, -28.3 }, -- glasshouse
			{ -33, 0.5, -28.3 },
			{ 29, 0, -37 }, -- orchard
		}, "near")
		for _, point in
			setPoints(PX, PZ, PTURN, 0.1, {
				{ 54.4, 0, 36 }, -- bench
				{ 31.31, 0, 80.06 }, -- picnic
				{ 46.56, 0, 108.04 },
				{ 24, 0.06, 100 }, -- blanket
				{ -46, 0, 50 }, -- lawn
				{ 40, 0, 66 },
				{ 50, 0, 80 },
				{ 16, 0, 20 }, -- stream
				{ -40, 0, 20 },
				{ 6, 0, 50.5 }, -- fountain
				{ 12.36, 0.57, 52.36 }, -- roses
				{ -3.05, 0, 55.05 },
				{ 20, 0, 63 }, -- topiary
				{ 44, 0, 46 }, -- sundial
				{ -44, 0, 102 }, -- swings
				{ -23, 0, 109 }, -- slide
				{ -51.5, 0.55, 89.5 }, -- sandbox
				{ -38, 0, 87 }, -- seesaw
				{ -26, 0.72, 92 }, -- roundabout
				{ -36, 0, 96 }, -- playground
				{ 5, 1.15, 130.5 }, -- bandstand
				{ 11, 1.15, 131 },
				{ 8, 1.15, 134 },
				{ 23.97, 0, 135.81 }, -- loop
				{ -7.97, 0, 135.81 },
				{ -30, 0, 146 }, -- far
				{ 40, 0, 146 },
				{ -14, 0, 132 },
			}, "deep")
		do
			table.insert(points, point)
		end
		return points
	end)(),
	-- a tree's branch points along its -X, a bin's open lid is at its back
	rescueSpots = {
		setPropTrap(PX, PZ, PTURN, "CatCafe_Park_RescueTree", "tree", { 46, 0, -24 }, 0),
		setPropTrap(PX, PZ, PTURN, "CatCafe_Park_RescueTree", "tree", { -46, 0, 30 }, 180),
		setPropTrap(PX, PZ, PTURN, "CatCafe_Park_RescueTree", "tree", { 46, 0, 98 }, 0),
		setPropTrap(PX, PZ, PTURN, "CatCafe_Park_TrashCan", "trashcan", { -8, 0, 64 }, 0),
		setPropTrap(PX, PZ, PTURN, "CatCafe_Park_TrashCan", "trashcan", { -46, 0, 140 }, 90),
	},
	props = {},
} :: AreaSpec

-- Areas 3 to 5 have their kit sets (Model-Agent #401, area-sets.md): the strays' spawn points are the sets' cat
-- spots and their traps are built into the sets. Since v3.1 (F77) the Neighbourhood opens on its -Z side at the
-- street's north end, the Woods on its +X side and the Sewer on its -X side, through the back alleys' outer walls.
--
-- The long Neighbourhood (F85, hometown-cannon.md section 6b; Model-Agent #810, area-sets.md "The Neighbourhood
-- (F85)"): a 180 x 430 wild part with its camp 30 more in front of the gate. Its set, camp, gate, night fence and
-- backdrop carry the F85 suffix (artSuffix). Five blockers cross the width with their gaps on alternating sides: the
-- first house block, the village green's fence, the road works, the second house block and the garden wall, to the
-- corner shop and the playground at the far end. Its cat spots are `near` on the camp half and `deep` on the far half;
-- its two sheds and two gutters are built into it, three of the four deep.
local NX, NZ = W.NeighbourhoodCenterX, W.NeighbourhoodCenterZ
local NGATE = NZ - W.NeighbourhoodDepth / 2 -- its south side
local NTURN = townTurn(NX, NZ, nil, NGATE)
Layout.neighbourhood = {
	floorY = 0.1,
	center = { x = NX, y = 0, z = NZ },
	halfWidth = W.NeighbourhoodWidth / 2,
	halfDepth = W.NeighbourhoodDepth / 2,
	gateZ = NGATE,
	openingHalfWidth = W.CampOpeningWidth / 2,
	set = "CatCafe_Neighbourhood_SetF85",
	artSuffix = "F85",
	spawnPoints = (function(): { Point }
		local points = setPoints(NX, NZ, NTURN, 0.1, {
			{ 5.05, 1, -166.9 }, -- porch

			{ -5.05, 1, -127.1 },
			{ 48.2, 1, -127.1 },
			{ -39.25, 0.7, -170.2 }, -- flowerbed
			{ 57.5, 0.7, -170.2 },
			{ -55.25, 0.7, -123.8 },
			{ -18, 0.62, -100 },
			{ -14.6, 1.65, -200 }, -- bus stop
			{ 16.2, 0, -196 }, -- post box
			{ -58, 0, -197.6 }, -- verge bench
			{ 56, 0, -197.6 },
			{ 44, 0, -207 }, -- bins
			{ -40, 0.34, -187 }, -- car
			{ -58.5, 0, -93 }, -- oak
			{ -40.56, 0, -99.96 }, -- picnic
			{ 44.69, 0, -99.94 },
			{ -57.66, 0, -68.55 }, -- green bench
			{ 36.5, 0, -82 }, -- birdbath
			{ -47, 0.34, -107.4 }, -- van
			{ -67.6, 0.6, -46 }, -- veg bed
			{ -25.6, 0.6, -46 },
			{ -39.6, 0.6, -8 },
			{ -72, 0.52, -11 }, -- greenhouse
			{ 27.5, 0, -41.5 }, -- scarecrow
			{ 80.5, 0, -30 }, -- compost
			{ -58.5, 0, -35.5 }, -- water butt
			{ -30, 0, -24 }, -- allotments
			{ -73.8, 0, -3.8 }, -- works hut
			-- side paths beside the end houses' islands, where the far porches were (Model-Agent #905)
			{ -74.3, 0.05, -157 },
			{ -74.3, 0.05, -137 },
			{ 75.05, 0.05, -157 },
			{ 75.05, 0.05, -137 },
		}, "near")
		for _, point in
			setPoints(NX, NZ, NTURN, 0.1, {
				{ 4.3, 1, 27.1 }, -- porch
				{ -53.8, 1, 66.9 },
				{ -5.8, 1, 66.9 },
				{ 51.3, 1, 179.1 },
				{ -44.5, 0.7, 23.8 }, -- flowerbed
				{ 27.5, 0.7, 23.8 },
				{ 51.5, 0.7, 23.8 },
				{ 38.5, 0.7, 70.2 },
				{ 6, 0.7, 96 },
				{ 76.5, 0.7, 175.8 },
				{ -60, 0, 156.8 }, -- verge bench
				{ -60, 0.34, 87 }, -- car
				{ 18.5, 0, 112 }, -- birdbath
				{ 72, 0.52, 137 }, -- greenhouse
				{ 50.5, 0, 2 }, -- sunflowers
				{ -8, 0, 0.4 }, -- allot bench
				{ 4, 0.34, 7.5 }, -- works
				{ -62, 0.34, 20.5 },
				{ -72, 1.73, 100 }, -- trampoline
				{ -60, 0, 131.5 }, -- washing
				{ -80, 0, 104.5 }, -- deckchair
				{ -46, 0, 104 }, -- gnomes
				{ -40, 0, 133 }, -- pool
				{ 57.2, 0, 103 }, -- playhouse
				{ -1.11, 0, 125.77 }, -- garden bench
				{ -84, 0, 140 }, -- garden
				{ 84, 0, 96 },
				{ 74, 0, 154.5 }, -- verge
				{ 0, 0.4, 198.3 }, -- shop step
				{ -9, 0.3, 195.1 }, -- fruit stall
				{ -12.5, 0.3, 188.3 }, -- shop bench
				{ -78.89, 0, 199.44 }, -- tyre
				{ -28, 4, 198 }, -- slide
				{ -53, 0, 200.5 }, -- swings
				{ -32.61, 0.55, 184.97 }, -- sandbox
				{ -56, 0.72, 186 }, -- roundabout
				{ -76, 0, 179.4 }, -- seesaw
				{ -40, 0, 177.4 }, -- play bench
				{ 22, 0, 180 }, -- lawn
				{ -82, 0.05, 179 }, -- far
				{ -6, 0.3, 176 },
				-- side paths beside the end houses' islands, where the porches were (Model-Agent #905)
				{ -75.05, 0.05, 37 },
				{ -75.05, 0.05, 57 },
				{ 72.05, 0.05, 37 },
				{ 72.05, 0.05, 57 },
			}, "deep")
		do
			table.insert(points, point)
		end
		return points
	end)(),
	rescueSpots = {
		-- a shed's door and a gutter's drainpipe face the piece's -Z; the gutters are on house corners, 7 up
		setTrap(NX, NZ, NTURN, "shed", { 65.4, 0, -33.3 }),
		setTrap(NX, NZ, NTURN, "shed", { 76.7, 0, 108.6 }, 90),
		setTrap(NX, NZ, NTURN, "gutter", { 37.4, 7.05, 28.5 }),
		setTrap(NX, NZ, NTURN, "gutter", { 62.4, 7.05, 180.5 }),
	},
	props = {},
} :: AreaSpec

-- The long Woods (F85, hometown-cannon.md section 6b; Model-Agent #847, area-sets.md "The Woods (F85)"): a 160 x 490
-- wild part with its camp 30 more in front of the gate, on its east side, so the set's long axis runs along world X:
-- the floor is WoodsDepth across X and WoodsWidth along Z. Its set, camp and backdrop carry the F85 suffix
-- (artSuffix); its gate and night fence are the v3.2 ones, which already span the 24 stud opening. Five blockers
-- cross the width with their gaps on alternating sides: the fallen timber, the stream with its one log bridge, the
-- tree line, the dry stone wall and the mossy boulder ridge under the Great Oak arch, to the Great Oak's clearing with
-- the tree house and the lookout tower at the far end. Its cat spots are `near` on the camp half and `deep` on the far
-- half, and the Great Oak's top nook is `rare` (Catching.RARE_ZONE: only a Rare or better waits there, and one goes
-- there first). Its hollow logs and bramble bushes are built into the set, each turned in it, four of the five traps
-- deep, and a cat can get stuck up the tree house's branch.
local WX, WZ = W.WoodsCenterX, W.WoodsCenterZ
local WGATE = WX + W.WoodsDepth / 2 -- its east side
local WTURN = townTurn(WX, WZ, WGATE, nil)
Layout.woods = {
	floorY = 0.1,
	center = { x = WX, y = 0, z = WZ },
	halfWidth = W.WoodsDepth / 2, -- world X, the set's long axis (a quarter turn)
	halfDepth = W.WoodsWidth / 2,
	gateX = WGATE,
	openingHalfWidth = W.SideGateHalfWidth,
	set = "CatCafe_Woods_SetF85",
	artSuffix = "F85",
	spawnPoints = (function(): { Point }
		local points = setPoints(WX, WZ, WTURN, 0.1, {
			{ -8.5, 0, -112.5 }, -- the log bridge (moved onto the trail since #905)
			{ 6.5, 0, -79.5 },
			{ 64, 0, -102.48 }, -- the waterfall
			{ -30, 0, -223.8 }, -- berry bushes
			{ -48, 0, -213.8 },
			{ -62, 0, -227.8 },
			{ -56, 0, -61.8 },
			{ -8, 0, -63.8 },
			{ 10, 0, -53.8 },
			{ -16, 0, -204 }, -- leaf piles
			{ 30, 0, -54 },
			{ -60, 1.66, -192 }, -- stumps
			{ -34, 1.66, -186 },
			{ 8, 1.66, -112 },
			{ -16, 1.66, -76 },
			{ 60, 0, -230 }, -- ferns
			{ 16, 0, -156 },
			{ 40, 0, -118 },
			{ -34, 0, -30 },
			{ 58.9, 0, -208.36 }, -- fallen logs
			{ -30, 0.05, -146 }, -- the mushroom ring
			{ -62, 0, -139.5 }, -- glow mushrooms
			{ 64, 2, -156 }, -- mossy rocks
			{ -64, 2, -116 },
			{ -64, 2, -40 },
			{ 64, 2, -60 },
			{ -58.05, 0, -163.38 }, -- the log pile
			{ 14, 0, -20 }, -- glades
		}, "near")
		for _, point in
			setPoints(WX, WZ, WTURN, 0.1, {
				{ 20, 0, 34.2 }, -- berry bushes
				{ -6, 0, 48.2 },
				{ -34, 0, 76.2 },
				{ 8, 0, 132.2 },
				{ 28, 0, 222.2 },
				{ -52, 0, 32 }, -- leaf piles
				{ -56, 0, 92 },
				{ 66, 0, 236 },
				{ -24, 1.66, 58 }, -- stumps
				{ 2, 1.66, 88 },
				{ 58, 0, 28 }, -- ferns
				{ 2, 0, 6 },
				{ 28, 0, 96 },
				{ -66, 0, 142 },
				{ 30, 0, 198 },
				{ 59.75, 0, 10.7 }, -- fallen logs
				{ 40, 0, 50.5 }, -- glow mushrooms
				{ -40, 0, 136.5 },
				{ -66, 0, 214.5 },
				{ 66, 2, 46 }, -- mossy rocks
				{ -40, 2, 8 },
				{ -20, 2, 132 },
				{ -64, 2, 166 },
				{ -63.33, 0, 48.34 }, -- the log pile
				{ -26, 0, 16 }, -- glades
				{ 16, 0, 56 },
				{ 54, 0, 40 }, -- the dell
				{ 49.61, 0, 101.84 }, -- the old campsite's tents
				{ 58.61, 0, 100.05 },
				{ 48, 2.06, 93 }, -- log benches
				{ 60, 2.06, 92 },
				{ -14, 2.06, 218 },
				{ -50, 2.06, 218 },
				{ -44, 2.06, 188 },
				{ 52, 0, 86.5 }, -- the campfire
				{ -38.74, 0, 206.93 }, -- in the Great Oak's roots
				{ -34.56, 0, 212.3 },
				{ -27.64, 0, 211.22 },
				{ 51.71, 10.3, 211.89 }, -- the tree house's cushion, up its ladder
				{ 42.66, 0, 206.64 }, -- at the foot of the tree house
				{ 12, 0, 230 }, -- the lookout tower
				{ -62, 0, 186 }, -- the oak's clearing
				{ -58, 0, 230 },
			}, "deep")
		do
			table.insert(points, point)
		end
		-- up the ladder inside the Great Oak to its top nook (Derek 2026-10-28 01:35: a higher rare chance there), on
		-- its cushion behind the ladder since #1461
		table.insert(points, setPoints(WX, WZ, WTURN, 0.1, { { -33.58, 18.3, 207.23 } }, "rare")[1])
		return points
	end)(),
	rescueSpots = {
		-- a hollow log's open end faces its own +X; a bramble is round
		setTrap(WX, WZ, WTURN, "hollow_log", { 62, 0, -128 }, 20),
		setTrap(WX, WZ, WTURN, "hollow_log", { -62, 0, 122 }, -20),
		setTrap(WX, WZ, WTURN, "bramble_bush", { -62, 0, 18 }),
		setTrap(WX, WZ, WTURN, "bramble_bush", { 64, 0, 176 }),
		-- up the tree house's branch (Derek 01:34), reached from its deck: shaken down and caught like a Park tree,
		-- the cat lying across the branch (which points along the piece's -X) as on a Park tree
		setTrap(WX, WZ, WTURN, "tree", { 54.16, 15.45, 215.11 }, 87.21),
	},
	props = {},
} :: AreaSpec

-- The long Sewer (F85, hometown-cannon.md section 6b; Model-Agent #860, area-sets.md "The Sewer (F85)"): a 120 x 570
-- wild part with its camp 30 more in front of the gate, on its west side, so the set's long axis runs along world X as
-- the Woods' does. Its set, camp and backdrop carry the F85 suffix (artSuffix); its gate and night fence are the v3.2
-- ones, which already span the 24 stud opening. Six blockers cross the width with their gaps on alternating sides:
-- the yard's canal under its brick bridge, the tunnel front's walk-in arch, the rubble under the cracked beam, the
-- channel's steel catwalk, the vault wall's arch into cat town and the pipe bank, to the throne room with the junk
-- throne and the pipe organ at the far end. Its cat spots are `near` up to the channel and `deep` from its catwalk on,
-- and its grates and drain pipes are built into the set, each turned in it, three of the four deep.
local SX, SZ = W.SewerCenterX, W.SewerCenterZ
local SGATE = SX - W.SewerDepth / 2 -- its west side
local STURN = townTurn(SX, SZ, SGATE, nil)
Layout.sewer = {
	floorY = 0.1,
	center = { x = SX, y = 0, z = SZ },
	halfWidth = W.SewerDepth / 2, -- world X, the set's long axis (a quarter turn)
	halfDepth = W.SewerWidth / 2,
	gateX = SGATE,
	openingHalfWidth = W.SideGateHalfWidth,
	set = "CatCafe_Sewer_SetF85",
	artSuffix = "F85",
	setLift = 0.4, -- the set's tiled slab
	spawnPoints = (function(): { Point }
		local points = setPoints(SX, SZ, STURN, 0.1, {
			{ -26, 2.8, -205 }, -- the brick bridge (at x -26 since #905)
			{ -24, 0.4, -247 }, -- the puddle
			{ 45, 0.4, -259 }, -- the barrel
			{ 32, 0.4, -264 }, -- the tyres
			{ 14, 0.4, -232 }, -- the cones
			{ -40, 0.4, -262 }, -- the crates
			{ -48, 0.4, -240.5 }, -- the suitcases
			{ -40, 0.4, -229.5 }, -- glow mushrooms
			{ 6, 0.4, -95.5 },
			{ -48, 0.4, -26.5 },
			{ 20, 0.4, -193 }, -- the canal banks
			{ -20, 0.4, -193 },
			{ -38, 0.4, -154.5 }, -- the walk-in arch
			{ -47.4, 0.4, -130 }, -- the market stalls
			{ -47.4, 0.4, -114 },
			{ 10, 0.4, -135.4 },
			{ 44.04, 2.55, -131.33 }, -- the market's crate deck
			{ -16, 0.4, -124 }, -- the market
			{ 44, 0.4, -22.35 }, -- a pipe end
			{ 51.9, 0.4, -47 }, -- the valve
			{ -14, 1.82, -12 }, -- the bathtub boat
			{ -23.5, 2.2, -14.52 }, -- the raft
			{ -20, 0.4, -44 }, -- the pump room
			{ 24, 0.4, -20 },
			{ 28, 0.4, -12 }, -- the catwalk's feet
		}, "near")
		for _, point in
			setPoints(SX, SZ, STURN, 0.1, {
				{ 24, 3.6, 0 }, -- the steel catwalk over the channel (at x 24 since #905)
				{ -46, 0.4, 273.5 }, -- the suitcases
				{ 12, 0.4, 74.5 }, -- glow mushrooms
				{ -44.5, 0.4, 24 },
				{ -8, 0.4, 104.5 },
				{ 50.5, 0.4, 172 },
				{ 16, 0.4, 272.5 },
				{ -44.5, 0.4, 206 },
				{ 19.51, 2.55, 20.46 }, -- the deck
				{ -6.35, 0.4, 166 }, -- a pipe end
				{ 20, 0.4, 12 }, -- the catwalk's feet (at x 20 since #905)
				{ 38.8, 1.88, 71.3 }, -- the sofa
				{ -14, 1, 44 }, -- the yarn trolley
				{ -52, 2.4, 70.3 }, -- the pipe hammock
				{ 0, 0.4, 40 }, -- the lost and found
				{ 34, 0.4, 50 },
				{ 20.6, 0.4, 128.49 }, -- the cat houses
				{ 39.4, 0.4, 128.49 },
				{ 20.6, 0.4, 146.51 },
				{ 39.4, 0.4, 146.51 },
				{ 30, 0.4, 132 }, -- cat town's square
				{ 26, 0.4, 143 },
				{ -50.5, 3.65, 164 }, -- the mine cart
				{ -36, 0.4, 104 }, -- cat town
				{ -4, 0.4, 156 },
				{ -40, 0.4, 172 },
				{ 34, 4.5, 270.6 }, -- the junk throne
				{ 34, 0.4, 277.7 }, -- the pipe organ
				{ 24, 0.4, 263 }, -- the dais
				{ -30, 0.4, 266 }, -- the toy pile
				{ -16, 0.4, 256 }, -- the pool
				{ 16, 0.4, 252 },
				{ 10, 0.4, 230 }, -- the throne room
				{ -20, 0.4, 212 },
				{ -42, 0.4, 194 }, -- the pipe bank
			}, "deep")
		do
			table.insert(points, point)
		end
		return points
	end)(),
	rescueSpots = {
		-- a grate is square; a drain pipe's mouth faces the piece's -Z
		setTrap(SX, SZ, STURN, "grate", { -34, 0.4, -92 }), -- in the junk market
		setTrap(SX, SZ, STURN, "grate", { -36, 0.4, 112 }), -- in cat town
		setTrap(SX, SZ, STURN, "drain_pipe", { -51.7, 0.4, 49 }, -90), -- in the lost and found
		setTrap(SX, SZ, STURN, "drain_pipe", { 51.7, 0.4, 256 }, 90), -- in the throne room
	},
	props = {},
} :: AreaSpec

-- The Town Square (F76, town-layout-v3.md section 3): paved, in the middle of the street and the safe zone, with the
-- Cat Cannon at the origin since v4 (F84, where the fountain stood) and a cross of open paving through it (the
-- street's line north to south and a lane east to west to the side arches). The four stations stand in its quarters,
-- each turned to face the middle, so nothing stands on the cross and the walk between the cafes, the arches and the
-- cannon is never blocked.
local TSW, TSD = W.TownSquareHalfWidth, W.TownSquareHalfDepth

-- rotY (degrees) that turns a model's front (-Z) from (x, z) toward (tx, tz): CFrame.Angles(0, rad(rotY), 0) has the
-- LookVector (-sin, 0, -cos).
local function facing(x: number, z: number, tx: number, tz: number): number
	return math.deg(math.atan2(-(tx - x), -(tz - z)))
end

local function station(x: number, z: number): Point
	return { x = x, y = 0.1, z = z, rotY = facing(x, z, 0, 0) }
end

Layout.townSquare = {
	floor = { x1 = -TSW, z1 = -TSD, x2 = TSW, z2 = TSD } :: Rect,
	-- the open cross: the street's line and the lane to the side arches, the lane in two halves either side of the
	-- street's line so no two marks overlap (overlapping flat parts z-fight)
	lanes = {
		{ x1 = -W.TownSquareLaneHalfWidth, z1 = -TSD, x2 = W.TownSquareLaneHalfWidth, z2 = TSD },
		{
			x1 = -TSW,
			z1 = -W.TownSquareCrossHalfWidth,
			x2 = -W.TownSquareLaneHalfWidth,
			z2 = W.TownSquareCrossHalfWidth,
		},
		{
			x1 = W.TownSquareLaneHalfWidth,
			z1 = -W.TownSquareCrossHalfWidth,
			x2 = TSW,
			z2 = W.TownSquareCrossHalfWidth,
		},
	} :: { Rect },
	-- trees and flower beds from the square out to the town's back edge, with a garden wall along it; the side
	-- arches into the back alleys that stood in the middle of each wall closed with the back alleys (v4)
	gardens = {
		{ x1 = -W.TownEdgeX, z1 = -TSD, x2 = -TSW, z2 = TSD },
		{ x1 = TSW, z1 = -TSD, x2 = W.TownEdgeX, z2 = TSD },
	} :: { Rect },
	-- the round plinth in the middle: the fountain's until v4, the Cat Cannon's since (Layout.cannons.town)
	fountainRadius = 6,
	-- The Rescue Rally's board (F101, Model-Agent #759: `CatCafe_Square_RallyBoard`, front -Z), in the north-east
	-- quarter facing the spawn, off the lane and the cannon's lines; WorldBuilder.setRally shows it while a Rally runs.
	rallyBoard = { asset = "CatCafe_Square_RallyBoard", x = 15, y = 0.1, z = 12, rotY = 30 } :: Prop,
	-- The Town Square set (Model-Agent #435): the asset manifest's placements_roblox rows for each CatCafe_Square_*
	-- piece, in world space (x, y, z, turn in degrees): the paving with its own slab, the two sign arches over the
	-- street, then the edge (Derek 10-28, Model-Agent #726): twelve lamps on the brick border, eight long buntings
	-- round the sides and two short ones over the lane's ends (each ends 0.25 inside its lamps' hook rings, so the
	-- lamps need no nudge), eight benches facing in, and the four gardens. The middle holds only the Cat Cannon
	-- (v4, placed by WorldBuilder) and its pad, and the quarters only the stations. The finger signpost south-west of
	-- the cannon came out 2026-11-03 (Derek: its tier arms no longer matched the areas). A short bunting skips until
	-- its model is in (AssetRegistry.known).
	props = {
		{ asset = "CatCafe_Square_Paving", x = 0, y = 0.1, z = 0 },
		{ asset = "CatCafe_Square_SignArch", x = 0, y = 0.1, z = -32 },
		{ asset = "CatCafe_Square_SignArch", x = 0, y = 0.1, z = 32, rotY = 180 },
		{ asset = "CatCafe_Square_Lamp", x = -47, y = 0.1, z = -31, rotY = 45 },
		{ asset = "CatCafe_Square_Lamp", x = -24.5, y = 0.1, z = -31, rotY = 90 },
		{ asset = "CatCafe_Square_Lamp", x = -47, y = 0.1, z = -8.5 },
		{ asset = "CatCafe_Square_Lamp", x = -47, y = 0.1, z = 31, rotY = 45 },
		{ asset = "CatCafe_Square_Lamp", x = -24.5, y = 0.1, z = 31, rotY = 90 },
		{ asset = "CatCafe_Square_Lamp", x = -47, y = 0.1, z = 8.5 },
		{ asset = "CatCafe_Square_Lamp", x = 47, y = 0.1, z = -31, rotY = 45 },
		{ asset = "CatCafe_Square_Lamp", x = 24.5, y = 0.1, z = -31, rotY = 90 },
		{ asset = "CatCafe_Square_Lamp", x = 47, y = 0.1, z = -8.5 },
		{ asset = "CatCafe_Square_Lamp", x = 47, y = 0.1, z = 31, rotY = 45 },
		{ asset = "CatCafe_Square_Lamp", x = 24.5, y = 0.1, z = 31, rotY = 90 },
		{ asset = "CatCafe_Square_Lamp", x = 47, y = 0.1, z = 8.5 },
		{ asset = "CatCafe_Square_Bunting", x = -35.75, y = 0.1, z = -31 },
		{ asset = "CatCafe_Square_Bunting", x = -47, y = 0.1, z = -19.75, rotY = 90 },
		{ asset = "CatCafe_Square_Bunting", x = -35.75, y = 0.1, z = 31 },
		{ asset = "CatCafe_Square_Bunting", x = -47, y = 0.1, z = 19.75, rotY = 90 },
		{ asset = "CatCafe_Square_Bunting", x = 35.75, y = 0.1, z = -31 },
		{ asset = "CatCafe_Square_Bunting", x = 47, y = 0.1, z = -19.75, rotY = 90 },
		{ asset = "CatCafe_Square_Bunting", x = 35.75, y = 0.1, z = 31 },
		{ asset = "CatCafe_Square_Bunting", x = 47, y = 0.1, z = 19.75, rotY = 90 },
		{ asset = "CatCafe_Square_BuntingShort", x = -47, y = 0.1, z = 0, rotY = 90 },
		{ asset = "CatCafe_Square_BuntingShort", x = 47, y = 0.1, z = 0, rotY = 90 },
		{ asset = "CatCafe_Square_Bench", x = -35.75, y = 0.1, z = -29.4, rotY = 180 },
		{ asset = "CatCafe_Square_Bench", x = -45.4, y = 0.1, z = -19.75, rotY = 270 },
		{ asset = "CatCafe_Square_Bench", x = -35.75, y = 0.1, z = 29.4 },
		{ asset = "CatCafe_Square_Bench", x = -45.4, y = 0.1, z = 19.75, rotY = 270 },
		{ asset = "CatCafe_Square_Bench", x = 35.75, y = 0.1, z = -29.4, rotY = 180 },
		{ asset = "CatCafe_Square_Bench", x = 45.4, y = 0.1, z = -19.75, rotY = 90 },
		{ asset = "CatCafe_Square_Bench", x = 35.75, y = 0.1, z = 29.4 },
		{ asset = "CatCafe_Square_Bench", x = 45.4, y = 0.1, z = 19.75, rotY = 90 },
		{ asset = "CatCafe_Square_Garden", x = -58.5, y = 0.1, z = -19.5, rotY = -90 },
		{ asset = "CatCafe_Square_Garden", x = -58.5, y = 0.1, z = 19.5, rotY = -90 },
		{ asset = "CatCafe_Square_Garden", x = 58.5, y = 0.1, z = -19.5, rotY = 90 },
		{ asset = "CatCafe_Square_Garden", x = 58.5, y = 0.1, z = 19.5, rotY = 90 },
		-- #1130: the bed between each side's two gardens (17 x 12, kerbs front and back), where the paving's side paths
		-- were; it spans z -8.5 to 8.5 and meets the gardens' end kerbs
		{ asset = "CatCafe_Square_GardenMid", x = -58.5, y = 0.1, z = 0, rotY = -90 },
		{ asset = "CatCafe_Square_GardenMid", x = 58.5, y = 0.1, z = 0, rotY = 90 },
	} :: { Prop },
}

-- The stations, one per quarter: the Spin Wheel (F49) and the Golden Fish Market (F53) north of the lane, the Codes
-- Cat (F65; its CodesCircle 6 studs in front, toward the fountain) and the night dealer's cart (data-model section
-- 8b, parked from dusk; the dealer stands at its +X end) south of it. #1215: the Fish Market sits back toward the
-- north-east corner, clear of the leaderboard row by 3.2 studs and the north bench by 2.9 (Model-Agent's check).
Layout.spinWheel = station(-28, 16)
Layout.fishMarket = station(33.5, 20)
Layout.codesCat = station(-28, -16)
-- #1388: the night market parks in front of the Thank You board (below), on its line to the cannon, so the board
-- stands 8.5 studs behind the cart with about 6.5 clear between them.
Layout.dealerCart = station(29.5, -16)
Layout.dealerNpc = { x = 5.4, y = 0, z = -0.4 } :: Point -- relative to the cart
-- The free Bellhop Cat's stand (F96, starter-cat.md section 2): between the Codes Cat and the Spin Wheel, at the west
-- end of the lane, which leads nowhere since the side arches closed (v4). Out at x -38 its 12 stud card stays clear
-- of the Codes circle, and its 9.2 stud dais leaves the lane open from the street to x -33. Its sign faces the cannon.
Layout.bellhopStand = station(-38, 0)

-- The leaderboards (F98, leaderboards.md section 2; Model-Agent #758): CatCafe_Town_LeaderboardRow, three chalkboards
-- in a row 23.8 long and 2.7 deep, at the lane's east end, mirroring the Bellhop stand, facing the cannon. Turned, the
-- row runs z -11.9 to 11.9 and x 38.6 to 41.4, clear of the edge lamps at x 47.
Layout.leaderboards = station(40, 0)

-- The Corner Shop (#1052, corner-shop.md section 4): beside the Golden Fish Market toward the north-east corner,
-- facing the cannon. Model-Agent's spot for CatCafe_Street_CornerShop (10.9 x 4.3, #1215; was 15, 23): clear of the
-- Fish Market by 1.95 studs, the north sign arch's post by 1.2, the bunting line by 0.8, the lamp by 4.4 and the
-- street by 7.1.
-- #1577 (day-cart.md section 3): the shop's old building, built only until the Day Cart's model arrives.
Layout.cornerShop = station(21, 24)

-- The Day Cart (#1577, day-cart.md section 3): the Corner Shop on CatCafe_Town_DayCart, in the square's south-west
-- quarter opposite the Golden Fish Market. Model-Agent's spot (#1592) keeps the walk lines and the cannon clear.
Layout.dayCart = station(-17, -24)

-- The Thank You board (#1083, idea-credits.md section 3): CatCafe_Street_ThanksBoard (12 x 1.5), facing the cannon.
-- #1388 (the friend, 11-05): moved from beside the Codes Cat to the left of the leaderboard row (its Index end, -Z),
-- with the night dealer's cart parked in front of it. Model-Agent's spot: it runs from about (34, -25) to (40, -15),
-- clear of the row's corner by 2.5 studs, the east bench behind it by 5, the south bench by 3.1 and the lane by 8.4.
Layout.thanksBoard = station(37, -20)

-- The Index Boards (F50, areas-and-stations.md; the asset manifest's `placement`): one in each camp (v4, F84,
-- hometown-cannon.md section 4), in camp space (Layout.campPoint), filled in with the camps below.
Layout.indexBoards = {} :: { [string]: Point }

-- The turn (degrees about Y) that faces a gate's front (-Z, its sign) the way players come from, which is also the
-- turn that puts an area kit's -Z side toward the town (town-layout-v3.md section 7b): none for the Neighbourhood, a
-- half turn for the Park, a quarter turn each way for the Woods and the Sewer. 0 for an area with no gate.
function Layout.gateTurn(spec: AreaSpec): number
	return townTurn(spec.center.x, spec.center.z, spec.gateX, spec.gateZ)
end

-- Where an area's gate stands: across the middle of its opening. Nil for an area with no gate.
function Layout.gatePosition(spec: AreaSpec): (number?, number?)
	if spec.gateX ~= nil then
		return spec.gateX, spec.center.z
	elseif spec.gateZ ~= nil then
		return spec.center.x, spec.gateZ
	end
	return nil, nil
end

-- Every area by id, in the order Catalog.areas lists them.
Layout.areas = {
	alley = Layout.alley,
	park = Layout.park,
	neighbourhood = Layout.neighbourhood,
	woods = Layout.woods,
	sewer = Layout.sewer,
} :: { [string]: AreaSpec }

-- Camps (v4, F84, hometown-cannon.md section 4): every wild area's camp lies across its whole width in front of its
-- gate, outside the set, CampDepth deep, with the gate as its way out into the wild part. Camp space has its origin
-- at the middle of the gate's opening on the floor, +Z running into the wild part and X across, turned by the area's
-- gateTurn: the camp is z -CampDepth to 0. `rect` is the camp's floor in world space, which is also its safe zone and
-- check-in rect, its edge the gate line. `pad` is the landing pad's centre, facing into the area (a front -Z turn),
-- `cannon` the camp cannon at the back wall, its barrel (+Z) out over the area, and `basket` the carrier basket's
-- spot beside the pad.
export type Camp = {
	area: string,
	turn: number,
	origin: Point,
	openingHalfWidth: number,
	halfAcross: number,
	rect: Rect,
	pad: Point,
	cannon: Point,
	basket: Point,
}

-- Where Model-Agent's camp sets (CatCafe_Camp_<Area>) put the pad's paw print, the camp cannon's paving and the
-- carrier basket, in camp space; a camp without its set is built to the same spots.
local CD = W.CampDepth
local CAMP_PAD = { x = 0, z = -13 }
local CAMP_CANNON = { x = 0, z = -26.5 }
local CAMP_BASKET = { x = -11, z = -13 }
local BOARD_OUT = 4 -- an Index Board stands this far beside the way out
local ALLEY_BOARD_OUT = 7 -- the Alleyway's (F85, Model-Agent): its low walls run on from the opening

-- A camp-space point (x, z) in world space: the same turn as setPoints, about the camp's origin.
function Layout.campPoint(camp: Camp, x: number, z: number): (number, number)
	local c, s = math.cos(math.rad(camp.turn)), math.sin(math.rad(camp.turn))
	return camp.origin.x + x * c + z * s, camp.origin.z - x * s + z * c
end

local function campFor(id: string, spec: AreaSpec): Camp?
	local gx, gz = Layout.gatePosition(spec)
	if gx == nil or gz == nil then
		return nil
	end
	local turn = Layout.gateTurn(spec)
	local quarter = math.abs(turn) % 180 == 90 -- the set's X runs along world Z
	local halfAcross = if quarter then spec.halfDepth else spec.halfWidth
	local camp: Camp = {
		area = id,
		turn = turn,
		origin = { x = gx, y = spec.floorY, z = gz },
		openingHalfWidth = spec.openingHalfWidth or W.StreetHalfWidth,
		halfAcross = halfAcross,
		rect = { x1 = 0, z1 = 0, x2 = 0, z2 = 0 },
		pad = { x = 0, y = spec.floorY, z = 0 },
		cannon = { x = 0, y = spec.floorY, z = 0 },
		basket = { x = 0, y = spec.floorY, z = 0 },
	}
	local ax, az = Layout.campPoint(camp, -halfAcross, -CD)
	local bx, bz = Layout.campPoint(camp, halfAcross, 0)
	camp.rect = {
		x1 = math.min(ax, bx),
		z1 = math.min(az, bz),
		x2 = math.max(ax, bx),
		z2 = math.max(az, bz),
	}
	local function point(at: { x: number, z: number }, rotY: number): Point
		local x, z = Layout.campPoint(camp, at.x, at.z)
		return { x = x, y = spec.floorY, z = z, rotY = (turn + rotY) % 360 }
	end
	camp.pad = point(CAMP_PAD, 180)
	camp.cannon = point(CAMP_CANNON, 0)
	camp.basket = point(CAMP_BASKET, 180)
	return camp
end

Layout.camps = {} :: { [string]: Camp }
for id, spec in Layout.areas do
	local camp = campFor(id, spec)
	if camp ~= nil then
		Layout.camps[id] = camp
		spec.arrival = camp.pad
		-- Beside the way out, 4 in from the gate line, its front toward the pad and turned 20 degrees toward the path:
		-- left of the opening for a player walking out. The Alleyway's (F85, one way in under the arch) stands 7 beside
		-- its opening (Model-Agent), past where its low walls begin; 4 in keeps the turned board's near post out of
		-- the low wall on the camp line, which 2.5 in put it through (worldscan).
		local out = if spec.rects ~= nil then ALLEY_BOARD_OUT else BOARD_OUT
		Layout.indexBoards[id] = { x = -(camp.openingHalfWidth + out), y = 0, z = -4, rotY = -20 }
	end
end

-- The camp extras (F100, camp-extras.md section 3; Model-Agent #750): where each model's pivot (its base centre,
-- front -Z, no turn of its own) stands in its area's set space, the space the camp set is placed in (origin the area's
-- centre on its floor, turned by the camp's turn): in the camp beside the way out, across from the Index Board.
Layout.campExtras = {
	park = { x = 19, y = 0, z = -160.5 }, -- F85: in the long camp, left of the flower bed (Model-Agent 11-02)
	neighbourhood = { x = 22, y = 0, z = -220.5 }, -- F85: in the long camp, clear of its mailbox (Model-Agent)
	woods = { x = 21.5, y = 0, z = -250 }, -- F85: the Fish Pond beside the long camp's way out (Model-Agent)
	sewer = { x = 20, y = 0, z = -289.5 }, -- F85: the Lost and Found 3.5 inside the long camp's gate line (Model-Agent)
} :: { [string]: Point }

-- Where an area's camp extra stands in the world: x, the floor's y and z, the turn about Y (the camp's), or nil for an
-- area with no extra or no camp.
function Layout.campExtraAt(areaId: string): (number?, number?, number?, number?)
	local at, spec, camp = Layout.campExtras[areaId], Layout.areas[areaId], Layout.camps[areaId]
	if at == nil or spec == nil or camp == nil then
		return nil, nil, nil, nil
	end
	local c, s = math.cos(math.rad(camp.turn)), math.sin(math.rad(camp.turn))
	return spec.center.x + at.x * c + at.z * s,
		spec.floorY,
		spec.center.z - at.x * s + at.z * c,
		camp.turn
end

-- The Garden Nursery (#1200, lawn-nursery.md section 3; Model-Agent #1332): CatCafe_Camp_Park_GardenNursery's pivot
-- (its base centre) in the Park's set space, the space Layout.campExtras uses, turned `turn` on top of the camp's
-- turn so its front (-Z) faces set -X, toward the landing pad.
Layout.lawnStall = { area = "park", x = 34, y = 0, z = -166, turn = 90 }

-- Where the Garden Nursery stands in the world: x, the floor's y and z, and its turn about Y in degrees (the camp's
-- plus its own), or nil when its area or camp is missing.
function Layout.lawnStallAt(): (number?, number?, number?, number?)
	local at = Layout.lawnStall
	local spec, camp = Layout.areas[at.area], Layout.camps[at.area]
	if spec == nil or camp == nil then
		return nil, nil, nil, nil
	end
	local c, s = math.cos(math.rad(camp.turn)), math.sin(math.rad(camp.turn))
	return spec.center.x + at.x * c + at.z * s,
		spec.floorY + at.y,
		spec.center.z - at.x * s + at.z * c,
		camp.turn + at.turn
end

-- The camp an x, z stands in, by its rect (edges included), or nil.
function Layout.campAt(x: number, z: number): string?
	for id, camp in Layout.camps do
		local rect = camp.rect
		if x >= rect.x1 and x <= rect.x2 and z >= rect.z1 and z <= rect.z2 then
			return id
		end
	end
	return nil
end

-- True when an x, z stands on the Town Square's floor (edges included). No strays roam it, so the net is put away
-- there (Derek 2026-11-03).
function Layout.inTownSquare(x: number, z: number): boolean
	local rect = Layout.townSquare.floor
	return x >= rect.x1 and x <= rect.x2 and z >= rect.z1 and z <= rect.z2
end

-- A world x, z in `camp`'s space: the inverse of campPoint.
function Layout.campLocal(camp: Camp, x: number, z: number): (number, number)
	local c, s = math.cos(math.rad(camp.turn)), math.sin(math.rad(camp.turn))
	local dx, dz = x - camp.origin.x, z - camp.origin.z
	return dx * c - dz * s, dx * s + dz * c
end

-- Where a cat dropped at x, z lands (section 4): a spot in a camp or within CampDropMarginStuds of its rect moves
-- straight out into the wild part, CampDropOutStuds past the gate line and at least 2 in from the camp's sides;
-- anywhere else stays put. The third value is the camp's id (its area's) when it moved, so the caller can put the
-- spot on that area's floor (review N279).
function Layout.outOfCamp(x: number, z: number): (number, number, string?)
	local margin = W.CampDropMarginStuds
	for id, camp in Layout.camps do
		local lx, lz = Layout.campLocal(camp, x, z)
		if math.abs(lx) <= camp.halfAcross + margin and lz >= -CD - margin and lz < margin then
			local inside = camp.halfAcross - 2
			local ox, oz =
				Layout.campPoint(camp, math.clamp(lx, -inside, inside), W.CampDropOutStuds)
			return ox, oz, id
		end
	end
	return x, z, nil
end

-- The Cat Cannons (section 3): `town` on the Town Square's plinth and one in each camp, by id (`town` or the camp's
-- area id). A cannon's barrel points along its model's +Z, so rotY turned by CFrame.Angles(0, rad(rotY), 0) fires
-- along (sin, cos): the town cannon rests pointing north and a camp cannon out over its area; since #1205 every
-- cannon's turret turns to the landing pad it fires at (Cannon.aimTurn in CannonService).
Layout.cannons = { town = { x = 0, y = 0.1, z = 0, rotY = 0 } :: Point } :: { [string]: Point }
for id, camp in Layout.camps do
	Layout.cannons[id] = camp.cannon
end

-- In front of each cannon (section 5: the Cannon button), facing it with its "Hop in" prompt in reach: in town just
-- off the plinth's south side on the landing pad, at a camp on the pad side of the cannon's paving.
local TOWN_FRONT_OUT = 1.5 -- studs past the plinth's edge
local CAMP_FRONT = { x = 0, z = CAMP_CANNON.z + 6.5 }
Layout.cannonFronts = {
	town = { x = 0, y = 0.1, z = -(Layout.townSquare.fountainRadius + TOWN_FRONT_OUT), rotY = 180 } :: Point,
} :: { [string]: Point }
for id, camp in Layout.camps do
	local x, z = Layout.campPoint(camp, CAMP_FRONT.x, CAMP_FRONT.z)
	Layout.cannonFronts[id] = { x = x, y = camp.origin.y, z = z, rotY = camp.turn % 360 }
end

-- The turn about Y (degrees) from the town cannon's rest that points its barrel at `destination`'s area: south for the
-- Park, north for the Neighbourhood, west for the Woods and east for the Sewer. 0 for anything else.
function Layout.cannonAim(destination: string): number
	local spec = Layout.areas[destination]
	if spec == nil or Layout.camps[destination] == nil then
		return 0
	end
	return math.deg(math.atan2(spec.center.x, spec.center.z))
end

-- The landing pads (section 3b): `town` at the town cannon's foot on its south side (the spawn stands on it), one on
-- each camp's pad. Each has seventeen spots tried in order: its centre, eight on a 4 stud ring, then eight on a 7
-- stud ring, each facing the way the pad faces. `area` is the rect a crowded flight lands in off the pad: the camp,
-- or in town the square.
export type LandingPad = { centre: Point, spots: { Point }, area: Rect }

local PAD_RINGS = { 4, 7 }

local function landingPad(centre: Point, area: Rect): LandingPad
	local spots: { Point } = { centre }
	for _, radius in PAD_RINGS do
		for n = 0, 7 do
			local angle = math.rad(n * 45)
			table.insert(spots, {
				x = centre.x + radius * math.sin(angle),
				y = centre.y,
				z = centre.z + radius * math.cos(angle),
				rotY = centre.rotY,
			})
		end
	end
	return { centre = centre, spots = spots, area = area }
end

Layout.landingPads = {
	town = landingPad({ x = 0, y = 0.1, z = -18, rotY = 180 }, Layout.townSquare.floor),
} :: { [string]: LandingPad }
for id, camp in Layout.camps do
	Layout.landingPads[id] = landingPad(camp.pad, camp.rect)
end

-- The welcome arches over the street's two ends (v4, section 2), where the Park and Neighbourhood gates stood, -Z
-- toward the square: the art's arch when it is there, else posts and a name board, with the end wall behind.
Layout.townEnds = {
	{
		x = 0,
		z = W.StreetSouthZ + 1,
		span = W.StreetHalfWidth * 2,
		label = "CAT CAFE TOWN",
		asset = "CatCafe_Town_WelcomeArch",
	},
	{
		x = 0,
		z = W.StreetNorthZ - 1,
		span = W.StreetHalfWidth * 2,
		label = "CAT CAFE TOWN",
		asset = "CatCafe_Town_WelcomeArch",
	},
} :: { Arch }

-- The hometown's edges (v4, section 2), so the town is closed all round: a fence behind each row of cafes' yards at
-- |x| TownEdgeX from end to end, and a wall across each end behind its welcome arch. Footprints 1 thick, just
-- outside the yards and the street's ends.
local TOWN_S, TOWN_N = W.StreetSouthZ - 1.5, W.StreetNorthZ + 1.5
Layout.townEdges = {
	{ x1 = -W.TownEdgeX - 1, z1 = TOWN_S - 1, x2 = -W.TownEdgeX, z2 = TOWN_N + 1 },
	{ x1 = W.TownEdgeX, z1 = TOWN_S - 1, x2 = W.TownEdgeX + 1, z2 = TOWN_N + 1 },
	{ x1 = -W.TownEdgeX, z1 = TOWN_S - 1, x2 = W.TownEdgeX, z2 = TOWN_S },
	{ x1 = -W.TownEdgeX, z1 = TOWN_N, x2 = W.TownEdgeX, z2 = TOWN_N + 1 },
} :: { Rect }

-- The paw paths (town-layout-v3.md section 7d, v4 section 2): from each street end along the street's line to the
-- cannon's plinth, the south one past the spawn, a print every PAW_STRIDE studs, left and right of the line like a
-- walking cat. `y` is the top of what it lies on; `rotY` turns its front (-Z) toward the cannon. `area` names the
-- path's colour ("town").
export type PawPrint = { area: string, x: number, y: number, z: number, rotY: number }

local PAW_STRIDE = 3.5
local PAW_SIDE = 0.7 -- left or right of the line
local PAW_END = 6 -- the first print's distance in from the street's end, clear of the welcome arch

-- The top of what lies at (x, z) on a paw path: the square's lane marks over its paving, the street, else the
-- gardens' grass.
local function pawSurface(x: number, z: number): number
	if math.abs(x) <= TSW and math.abs(z) <= TSD then
		return 0.12
	end
	local onStreet = math.abs(x) <= W.StreetHalfWidth and math.abs(z) <= W.StreetNorthZ
	return if onStreet then 0.1 else 0
end

function Layout.pawPrints(): { PawPrint }
	local prints: { PawPrint } = {}
	-- each path from its far end (a unit vector out from the cannon and the distance out) in to the plinth
	local paths = {
		{ ux = 0, uz = -1, from = -W.StreetSouthZ - PAW_END },
		{ ux = 0, uz = 1, from = W.StreetNorthZ - PAW_END },
	}
	local stop = Layout.townSquare.fountainRadius + 2
	for _, path in paths do
		local ux, uz = path.ux, path.uz
		local rotY = math.deg(math.atan2(ux, uz)) -- front (-Z) toward the cannon, walking in along (-ux, -uz)
		local d, k = path.from, 0
		while d >= stop do
			local side = if k % 2 == 0 then -PAW_SIDE else PAW_SIDE
			-- the line's right hand is (uz, -ux) for a walker facing (-ux, -uz)
			local x, z = ux * d + uz * side, uz * d - ux * side
			table.insert(prints, { area = "town", x = x, y = pawSurface(x, z), z = z, rotY = rotY })
			d -= PAW_STRIDE
			k += 1
		end
	end
	return prints
end

-- Player spawn in the Town Square on the street's line, looking north at the Cat Cannon (WorldBuilder turns it by
-- rotY, and a character spawns facing the way its SpawnLocation faces).
Layout.playerSpawn = { x = 0, y = 0.6, z = -14, rotY = 180 } :: Point

return Layout
