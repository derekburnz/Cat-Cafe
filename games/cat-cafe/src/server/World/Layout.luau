--!strict
-- Pure geometry for the world: where plots sit on the street and where everything inside a plot goes.
-- Plot-local space: X runs along the street, Z is depth, -Z faces the street, y = 0 is the floor top.
-- No Roblox globals, so tests can check the numbers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

-- zone tags a spawn point "lane" (behind a cafe) or "nook" (an end of a back alley, v3.1), or in a v3.2 side area
-- "near" (the gate half) or "deep" (the far half); Epic and rarer strays take only "nook" or "deep" points.
export type Point = { x: number, y: number, z: number, rotY: number?, zone: string? }
-- A cafe table: its point, and `lane`, the plot-local z of the walkway beside its row that customers walk along to
-- reach its chairs (Layout.plot.tables).
export type TableSpot = { x: number, y: number, z: number, lane: number }
-- An axis-aligned rectangle on the ground, world or plot space depending on where it is used.
export type Rect = { x1: number, z1: number, x2: number, z2: number }
-- An archway over an entrance (WorldBuilder.buildArch): the alley kit's `asset` when there is one.
export type Arch = { x: number, z: number, span: number, label: string, asset: string? }
-- A rescue trap: the prop stands at (x, floor, z) turned by rotY; the stuck cat sits at Layout.stuckPoses[prop].
-- A trap built into an area's kit set has no prop: the stuck cat sits right at (x, floor + y, z) turned by rotY.
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
-- A shared area in world space. A box area (no rects) is one floor with walls on three sides and an opening in its
-- near wall, the one facing the town: a Z side with gateZ (the Park, the Neighbourhood), an X side with gateX (the
-- Woods and the Sewer, v3.1). An area with rects (the Alleyway) is those floors with the listed wall footprints and
-- arches; center, halfWidth and halfDepth are then its bounding box.
export type AreaSpec = {
	floorY: number,
	center: Point,
	halfWidth: number,
	halfDepth: number,
	gateZ: number?, -- where the tier gate stands across an opening on a Z side; nil for the Tier 1 alley
	gateX: number?, -- or across an opening on an X side (the Woods and the Sewer since v3.1)
	openingHalfWidth: number?, -- half the opening of a box area; the street's half width when omitted
	nearWall: boolean?, -- false when a neighbour's wall already closes a box area's near side, opening and all
	paths: { Rect }?, -- a box area's roads and paths, laid flat on its floor
	-- The area's kit set (Model-Agent's CatCafe_<Area>_Set, assets/cat-cafe/exports/area-sets.md): when the art is
	-- there WorldBuilder places it on the floor turned by Layout.gateTurn, in place of `paths` and `props`, and hides
	-- the wall facing the town behind the set's see-through border. setLift is how far the set's own ground stands
	-- above the floor where strays walk (the Sewer's tiles).
	set: string?,
	setLift: number?,
	rects: { Rect }?,
	walls: { Rect }?, -- wall footprints for a rects area
	roam: { Rect }?, -- where strays may walk when props line the walls; the floor pieces when nil
	wallHeight: number?,
	-- archways a rects area is entered by: the alley kit's asset when it is there, else posts, beam and label
	arches: { Arch }?,
	arrival: Point?, -- where fast travel lands; a box area lands just inside its opening
	arrivalEast: Point?, -- the Alleyway's landing for a player whose cafe is on the east side (v3.1)
	spawnPoints: { Point },
	rescueSpots: { RescuePoint },
	props: { Prop },
}

local Layout = {}

-- Where the stuck cat's pivot sits on each rescue prop, in prop space: the stuck_pose body_cframe_roblox values
-- from assets/cat-cafe/exports/manifest.json, 12 numbers for CFrame.new(table.unpack(pose)). Plain numbers keep
-- this module free of Roblox types. Placeholders share the real props' pivots, so one set fits both.
Layout.stuckPoses = {
	-- The traps (F27). Head first into the bin, back legs and tail out of the top.
	CatCafe_Alley_TrashBin = { 0, 2.05, -0.8, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
	-- Wedged between the bags, front half showing.
	CatCafe_Alley_GarbageBags = { -0.45, 0, 0.4, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
	-- Draped across the shakeable branch between the trunk and the leaf tuft at its tip, facing the tree's front.
	-- The manifest's pose (along the branch, head toward the trunk) put the longer cats' heads and tails in the
	-- trunk and the leaves.
	CatCafe_Park_RescueTree = { -2.35, 3.96, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
	-- Head first into the can under the lid.
	CatCafe_Park_TrashCan = { 0, 1.75, -0.8, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
	-- Stand-ins for the provisional traps of the grayboxes.
	-- Clings to the low branch, rolled 20 degrees toward the trunk.
	CatCafe_Alley_StuckTree = { -1.4, 4.4, 0, 0.9397, -0.342, 0, 0.342, 0.9397, 0, 0, 0, 1 },
	-- Head inside the box, tail end out of the opening (turned 180 degrees).
	CatCafe_Alley_StuckBox = { 0, 0, -0.6, -1, 0, 0, 0, 1, 0, 0, 0, -1 },
	-- Body inside the outlet, head poking out.
	CatCafe_Alley_Drainpipe = { 0, 0, -2, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
} :: { [string]: { number } }

local W = Config.World

-- World position of plot `index` (1-based) and which side of the street it is on (-1 west, +1 east). Out from
-- the street: the sidewalk to |x| 18, the front garden, the front wall, the cafe floor, the back wall and the yard.
-- Layout v3 (F76): the rows pair up either side of the Town Square, a side passage from it, plots 1 and 2 south of
-- the square and 3 and 4 north of it, then 5 to 8 one row farther out the same way, so a few players all have a
-- cafe by the square and the beginner's plot 1 is a short walk from the stations.
function Layout.plotPlacement(index: number): { x: number, z: number, side: number }
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

local halfW = W.PlotWidth / 2 -- 18
local halfD = W.PlotDepth / 2 -- 14
local yardZ1, yardZ2 = halfD + 1, halfD + 1 + W.YardDepth -- 15, 25
local yardMid = (yardZ1 + yardZ2) / 2

-- Index decor spots (F48): each area's piece and its gold piece share one, since the gold one stands in for it.
local INDEX_SPOTS: { [string]: Point } = {
	alley = { x = 13, y = 3.8, z = halfD - 0.2 }, -- the print, on the back wall right of the counter, above the wall rail
	park = { x = halfW - 1.2, y = 0, z = -2, rotY = 90 }, -- the bench, against the right wall facing the tables
	neighbourhood = { x = -halfW + 1.2, y = 0, z = -3.5 }, -- the planter, left wall between the window and the tank
	woods = { x = -halfW + 1.2, y = 0, z = halfD - 1.2 }, -- the lamp, in the back left corner
	sewer = { x = halfW - 1.4, y = 0, z = halfD - 1.4 }, -- the fountain, in the back right corner
}

Layout.plot = {
	door = { x = 0, y = 0, z = -halfD } :: Point,
	entry = { x = 0, y = 0, z = -halfD - 1 - W.FrontGardenDepth - 1 } :: Point, -- customer start, on the sidewalk
	sign = { x = 0, y = 7.5, z = -halfD - 0.3 } :: Point,
	counter = { x = 0, y = 0, z = halfD - 3 } :: Point,
	-- On the counter's espresso plate (its top is 3 up); the level 3 machine fills it to the till.
	espresso = { x = 3, y = 3, z = halfD - 3 } :: Point,

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
		barista_3 = { x = 5.2, y = 0, z = halfD - 3 },
		waiter_1 = { x = -4.5, y = 0, z = -2.5 },
		waiter_2 = { x = 4.5, y = 0, z = -2.5 },
		waiter_3 = { x = 4.5, y = 0, z = 3.5 }, -- beside the aisle, off the door to counter walk (was 0, 4.5)
		greeter_1 = { x = -4, y = 0, z = -halfD + 2.5 },
		greeter_2 = { x = 4, y = 0, z = -halfD + 2.5 },
		-- the cat tree's top cushion, at its sit point (-0.5, 4.47, -0.4 from the tree's pivot)
		entertainer_1 = { x = -14.5, y = 4.47, z = 7.6 },
		entertainer_2 = { x = 13.5, y = 4.47, z = 7.6 },
	} :: { [string]: Point },

	-- Station furniture under a slot, for the roles that have one (Catalog.spotFurniture)
	spotFurniture = {
		entertainer_1 = { x = -14, y = 0, z = 8 },
		entertainer_2 = { x = 14, y = 0, z = 8 },
	} :: { [string]: Point },

	decorAnchors = {
		plants = { x = 11, y = 1, z = -halfD + 0.7 }, -- on the right window's sill, clear of its curtain
		rug = { x = 0, y = 0, z = -2 },
		neon_sign = { x = 0, y = 5.5, z = halfD - 0.7 },
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
	-- a piece's pivot is its base centre with its front toward -Z. The F48 Index pieces keep their own spots.
	decorSpots = {
		{ x = -9.5, y = 0, z = -halfD + 1.4, rotY = 180 }, -- front wall, left of the door
		{ x = 9.5, y = 0, z = -halfD + 1.4, rotY = 180 }, -- front wall, right of the door
		{ x = halfW - 1.4, y = 0, z = -6.5, rotY = 90 }, -- right wall, between the window corner and the bench
		{ x = -halfW + 1.4, y = 0, z = -7.5, rotY = -90 }, -- left wall, between the window corner and the planter
		{ x = 8, y = 0, z = halfD - 1.4, rotY = 0 }, -- back wall, right of the counter
		{ x = -12.6, y = 0, z = halfD - 1.4, rotY = 0 }, -- back wall, left of the back door
		{ x = -halfW + 1.4, y = 0, z = 4, rotY = -90 }, -- left wall, between the fish tank and the cat tree
		{ x = 11.5, y = 0, z = halfD - 1.4, rotY = 0 }, -- back wall, right of the counter beyond the first
	} :: { Point },

	-- Two columns of three, either side of the aisle from the front door to the counter (Derek 2026-10-28 01:27: the
	-- second table stood in the doorway where everyone walks): a table and its two chairs reach 3.7 either side of
	-- its x and 2.1 in front and behind, so the aisle is clear from x -6.3 to 6.3. The back left table sits half a
	-- stud further out, so the walk from the back door to the front door passes its chair a stud clear (review N237). Filled in order, two a tier: front row, middle row, back
	-- row. Each row's `lane` is the walkway between it and the next row, which customers take to the outer chair.
	tables = {
		{ x = -10, y = 0, z = -8.5, lane = -5.4 },
		{ x = 10, y = 0, z = -8.5, lane = -5.4 },
		{ x = -10, y = 0, z = -2.25, lane = 0.9 },
		{ x = 10, y = 0, z = -2.25, lane = 0.9 },
		{ x = -10.5, y = 0, z = 4, lane = 0.9 },
		{ x = 10, y = 0, z = 4, lane = 0.9 },
	} :: { TableSpot },
	-- How far either side of the aisle's middle customers walk to and from a lane, clear of the waiters at 4.5.
	aisleX = 2,

	-- The rich customer's coin pile (data-model section 12): on top of table 1 (2.6 tall), where the rich customer
	-- sits. The UI's gold marker floats over it and ClaimRichTip measures range from it.
	richTip = { x = -10, y = 2.7, z = -8.5 } :: Point,

	-- The back door, between the counter and the left cat tree, opens from Tier 1 onto the yard; the yard's gate
	-- lines up with it so the way out to the back alley is straight.
	backDoor = { x = -8, width = 6, height = 7.5 },
	-- Where a player who has not seen the intro lands (F72, intro-cutscene.md section 1): just inside the back
	-- door, 3 studs in from the back wall, facing it. y is the root's height above the floor, as homeLanding's.
	introSpot = { x = -8, y = 3, z = halfD - 3 } :: Point,

	-- The front garden strip between the sidewalk and the front wall, and the path through it to the door.
	frontGarden = {
		x1 = -halfW - 1,
		z1 = -halfD - 1 - W.FrontGardenDepth,
		x2 = halfW + 1,
		z2 = -halfD - 1,
	} :: Rect,
	frontPath = { x1 = -2.5, z1 = -halfD - 1 - W.FrontGardenDepth, x2 = 2.5, z2 = -halfD - 1 } :: Rect,

	-- The bait bowl (data-model section 8; v0.5 F44, Gavin: "The bowl sits out side of your cafe") on the back
	-- step, right of the back door and under the shell's back lamp, facing the yard gate and the Alleyway the strays
	-- come from. Clear of the door's mat, the path from the door to the gate and the Tier 4 planter; the cat stands
	-- beside it with its head over the bowl.
	baitBowl = { x = -2.6, y = 0, z = halfD + 2.6 } :: Point,
	baitCat = { x = -1, y = 0, z = halfD + 2.6, rotY = 90 } :: Point,

	-- The patio yard behind the back wall, fenced, with a gate in its back fence onto the back alley.
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

	-- Where cats without a job nap, so the collection is on show (world-and-feel.md section 4, F37): the two
	-- front window corners, beside the right cat tree and at the counter's right end. Highest rating first.
	napSpots = {
		{ x = -15.5, y = 0, z = -10, rotY = 45 },
		{ x = 15.5, y = 0, z = -10, rotY = -45 },
		{ x = 15.5, y = 0, z = 3.5, rotY = -90 },
		{ x = 11, y = 0, z = 11, rotY = 180 },
	} :: { Point },
}

-- Shared areas, in world space. y is the floor top.

-- The Alleyway (data-model section 9, town-layout-v3.md section 7e): a 30 stud back alley behind each row of cafes,
-- closed at both ends since v3.1 took the Alley Square away. Every cafe's yard gate, the side passages between cafes
-- and the Town Square's side arches open onto it, and the Woods and Sewer gates stand in its outer walls straight
-- across from the side arches.
local AI, AO = W.AlleyInnerX, W.AlleyOuterX
local AS, AN = W.AlleySouthZ, W.AlleyNorthZ
local MID = (AI + AO) / 2 -- the middle of a back alley's width
local GH = W.SideGateHalfWidth -- the Woods and Sewer gate openings, z -GH to GH in the outer walls

-- Two lane spawn points behind every cafe, in plot order: plot p owns alley points 2p - 1 and 2p, so the tutorial
-- stray waits right outside a beginner's own yard gate. Then two nooks at each end of each back alley (s = -1 west,
-- 1 east), where Epic and rarer strays go: 6.5 studs off the south end walls and 8.5 off the north ones (the east
-- north end's fire escape is 5 deep), so at least 2 inside the roam rects, and at least 10 studs from every lane
-- point (town-layout-v3.md 7e's suggested points, moved out from the end walls).
local NOOKS = { { 70, 117 }, { 76, 117 }, { 82, -119 }, { 68, -119 } }
local function alleySpawnPoints(): { Point }
	local points: { Point } = {}
	for index = 1, W.PlotCount do
		local placement = Layout.plotPlacement(index)
		local side = placement.side
		table.insert(points, { x = side * (AI + 7), y = 0.1, z = placement.z - 7, zone = "lane" })
		table.insert(points, { x = side * (AO - 7), y = 0.1, z = placement.z + 9, zone = "lane" })
	end
	for _, side in { -1, 1 } do
		for _, xz in NOOKS do
			table.insert(points, { x = side * xz[1], y = 0.1, z = xz[2], zone = "nook" })
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

-- A piece against a back alley's end wall (side -1 west, 1 east; north 1 for the north end, -1 the south), front
-- (-Z) turned down the alley; `along` and `out` as for onOuterWall.
local function onEndWall(
	asset: string,
	side: number,
	north: number,
	along: number?,
	out: number?
): Prop
	return {
		asset = asset,
		x = side * MID + north * (along or 0),
		z = if north > 0 then AN + (out or 0) else AS - (out or 0),
		rotY = if north > 0 then 0 else 180,
	}
end

-- Building backs (30.6 wide) along each back alley's outer wall, so the lane reads as the backs of buildings rather
-- than a bare wall (world-and-feel.md section 2): three either side of the Woods or Sewer gate, from clear of the
-- end wall's piece to clear of the gate's model (42 studs wide with its pillars), evenly spaced.
local BACK_WIDTH = 30.6
local GATE_CLEAR = 21.2
local END_CLEAR = 5 -- the deepest end wall piece, the fire escape
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
local GATE_SLOT = #BACK_SLOTS // 2 -- the last back south of the gate; the next one is the first north of it
-- The fire escape's first landing (top 9.35) is reached from the crate stack's tall column (top 7.7), which
-- stands just past the landing's open end at local x -8 (asset manifest, ledges_roblox).
local CRATES_ALONG, CRATES_OUT = -12, -2.8

local function alleyDressing(): { Prop }
	local props: { Prop } = {}
	local function add(prop: Prop)
		table.insert(props, prop)
	end
	-- south to north; the loose props and rescue spots below stand in front of windows and doors, never a fire
	-- escape, and no fire escape's crates reach the gate
	local rows = {
		[-1] = { "WallWindows", "FireEscape", "WallWindows", "WallDoor", "WallWindows", "WallDoor" },
		[1] = {
			"WallWindows",
			"FireEscape",
			"WallWindows",
			"WallDoor",
			"FireEscape",
			"WallWindows",
		},
	}
	for _, side in { -1, 1 } do
		for slot, z in BACK_SLOTS do
			local piece = rows[side][slot] or "WallWindows"
			add(onOuterWall("CatCafe_Alley_" .. piece, side, z))
			if piece == "FireEscape" then
				add(onOuterWall("CatCafe_Alley_CrateStack", side, z, CRATES_ALONG, CRATES_OUT))
			end
		end
		-- String lights across the lane in the gaps between buildings, a laundry line in front of a windowed back.
		for slot = 1, #BACK_SLOTS - 1 do
			if slot ~= GATE_SLOT then
				add({
					asset = "CatCafe_Alley_StringLightsLong",
					x = side * MID,
					z = (BACK_SLOTS[slot] + BACK_SLOTS[slot + 1]) / 2,
				})
			end
		end
		add({
			asset = "CatCafe_Alley_LaundryLine",
			x = side * (MID - 0.4),
			z = if side < 0 then BACK_SLOTS[5] else BACK_SLOTS[3],
		})
		-- the south dead ends: a staff door
		add(onEndWall("CatCafe_Alley_WallDoor", side, -1))
	end
	-- The north dead ends take what stood in the Alley Square: the mural on the west, the fire escape with its
	-- crates on the east (its crates reach the east alley's inner edge, the landing's open end being on that side).
	add(onEndWall("CatCafe_Alley_Mural", -1, 1))
	add(onEndWall("CatCafe_Alley_FireEscape", 1, 1))
	add(onEndWall("CatCafe_Alley_CrateStack", 1, 1, CRATES_ALONG, CRATES_OUT))
	return props
end

Layout.alley = {
	floorY = 0.1,
	center = { x = 0, y = 0, z = (AS + AN) / 2 },
	halfWidth = AO,
	halfDepth = (AN - AS) / 2,
	rects = {
		{ x1 = -AO, z1 = AS, x2 = -AI, z2 = AN }, -- west back alley
		{ x1 = AI, z1 = AS, x2 = AO, z2 = AN }, -- east back alley
	},
	walls = {
		-- the outer walls, open for the Woods and Sewer gates
		{ x1 = -AO - 1, z1 = AS - 1, x2 = -AO, z2 = -GH },
		{ x1 = -AO - 1, z1 = GH, x2 = -AO, z2 = AN + 1 },
		{ x1 = AO, z1 = AS - 1, x2 = AO + 1, z2 = -GH },
		{ x1 = AO, z1 = GH, x2 = AO + 1, z2 = AN + 1 },
		-- the end walls, carried on to the Park's and the Neighbourhood's side walls so the town is closed between
		-- them (the area walls are 1 thick on their edges)
		{ x1 = -AO, z1 = AS - 1, x2 = -W.ParkWidth / 2 - 0.5, z2 = AS },
		{ x1 = W.ParkWidth / 2 + 0.5, z1 = AS - 1, x2 = AO, z2 = AS },
		{ x1 = -AO, z1 = AN, x2 = -W.NeighbourhoodWidth / 2 - 0.5, z2 = AN + 1 },
		{ x1 = W.NeighbourhoodWidth / 2 + 0.5, z1 = AN, x2 = AO, z2 = AN + 1 },
	},
	-- Strays keep off the strip along the outer walls where the building backs, fire escapes and crate stacks stand
	-- (up to 5 studs deep), 4 off the south end walls (a staff door) and 6 off the north ones, clear of the east
	-- north end's fire escape and its crates (reviewer S84); the nooks stay 2 or more inside.
	roam = {
		{ x1 = -AO + 5, z1 = AS + 4, x2 = -AI, z2 = AN - 6 },
		{ x1 = AI, z1 = AS + 4, x2 = AO - 5, z2 = AN - 6 },
	},
	wallHeight = 10,
	arches = {}, -- entered through the Town Square's side arches (Layout.townSquare.arches), the yards and passages
	-- Fast travel lands just inside the side arch on the side of the player's own cafe, facing along the alley: the
	-- west one with no cafe, arrivalEast for a cafe on the east side (TravelService).
	arrival = { x = -(AI + 9), y = 0.1, z = -8, rotY = 180 },
	arrivalEast = { x = AI + 9, y = 0.1, z = -8, rotY = 180 },
	spawnPoints = alleySpawnPoints(),
	rescueSpots = {
		-- A trash bin in each back alley and the garbage bags on the west outer wall between the cafe rows, each in
		-- front of a windowed back, lid toward the lane, and 9 studs from every spawn point so a stray there never
		-- takes the rescue's prompt (reviewer N77).
		{ prop = "CatCafe_Alley_TrashBin", trap = "trash_bin", x = -AO + 4.5, z = -36, rotY = -90 },
		{ prop = "CatCafe_Alley_TrashBin", trap = "trash_bin", x = AO - 4.5, z = -40, rotY = 90 },
		{
			prop = "CatCafe_Alley_GarbageBags",
			trap = "garbage_bag",
			x = -AO + 4.5,
			z = 80,
			rotY = -90,
		},
	} :: { RescuePoint },
	-- The building backs, crate stacks, lights and laundry from alleyDressing, then the loose props in front of
	-- them: clear of the backs' depth (2.7 windows, 3.4 door canopy, 5 fire escape) and of the lane spawn points.
	props = (function(): { Prop }
		local props = alleyDressing()
		for _, prop in
			{
				-- West back alley: a dumpster corner at each end, a bin by the staff door, a crate, puddles
				{ asset = "CatCafe_Alley_Dumpster", x = -AO + 4.8, z = -104, rotY = 90 },
				{ asset = "CatCafe_Alley_GarbageBags", x = -AO + 4.6, z = -111, rotY = 90 },
				{ asset = "CatCafe_Alley_Dumpster", x = -AO + 3, z = AN - 7.5, rotY = 90 },
				{ asset = "CatCafe_Alley_TrashCan", x = -AO + 3.8, z = 47 },
				{ asset = "CatCafe_Alley_Crate", x = -AO + 4.5, z = 55 },
				{ asset = "CatCafe_Alley_Puddle", x = -AI - 13, z = -40 },
				{ asset = "CatCafe_Alley_Puddle", x = -AI - 11, z = 40 },
				-- East back alley: a dumpster corner at the south end, crates by the fire escape at the north end
				{ asset = "CatCafe_Alley_Dumpster", x = AO - 4.8, z = -104, rotY = -90 },
				{ asset = "CatCafe_Alley_GarbageBags", x = AO - 4.6, z = -111, rotY = -90 },
				{ asset = "CatCafe_Alley_TrashCan", x = AO - 3.8, z = -28 },
				{ asset = "CatCafe_Alley_Crate", x = AO - 3.8, z = 100 },
				{ asset = "CatCafe_Alley_Crate", x = AO - 4, z = AN - 7 },
				{ asset = "CatCafe_Alley_Crate", x = AO - 2.5, z = AN - 9.5 },
				{ asset = "CatCafe_Alley_Puddle", x = AI + 17, z = -12 },
				{ asset = "CatCafe_Alley_Puddle", x = AI + 12, z = 26 },
			} :: { Prop }
		do
			table.insert(props, prop)
		end
		return props
	end)(),
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

-- A trap built into an area kit set (a `trap_` spot): no prop of its own, the stuck cat at the spot, turned with
-- the set and by `pieceTurn`, the trap piece's own turn in the set's space (a v3.2 spot's fifth number).
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

-- The Park at its v3.2 size (F81, town-layout-v3.md section 8): Model-Agent's set (#460, area-sets.md "The Park
-- (v3.2)") fills the 160 x 120 floor and brings its own fountain, trees and benches. The way in winds past two hedge
-- rows to the bandstand. Its cat spots are `near` on the gate half and `deep` on the far half, where Epic and rarer
-- strays wait (CatService). Its rescue trees and bins stand at the set's trap spots, three of the five deep.
local PX, PZ = 0, W.ParkCenterZ
local PTURN = townTurn(PX, PZ, nil, W.ParkGateZ)
Layout.park = {
	floorY = 0.1,
	center = { x = PX, y = 0, z = PZ },
	halfWidth = W.ParkWidth / 2,
	halfDepth = W.ParkDepth / 2,
	gateZ = W.ParkGateZ,
	set = "CatCafe_Park_Set",
	spawnPoints = (function(): { Point }
		local points = setPoints(PX, PZ, PTURN, 0.1, {
			{ -3.5, 0, -49.5 }, -- the plaza
			{ 18, 0.62, -48.5 }, -- the flower beds
			{ 30, 0.62, -45.5 },
			{ 45, 0.62, -41 },
			{ 51.6, 0, -42 }, -- the bench
			{ -28.56, 0, -50.96 }, -- the picnic tables
			{ -45.17, 0, -53.91 },
			{ -42, 0.06, -40 }, -- a picnic blanket
			{ -35, 0, -48.5 }, -- oaks
			{ -34, 0, -29.5 },
			{ 62, 0, -50.5 }, -- the blossom tree
			{ 10, 1.2, -8 }, -- the jetty, on its boards
			{ -15.56, 0, -18.9 }, -- the pond bank
			{ -42, 0, -16 }, -- the willow
			{ 46.5, 0, -16.5 }, -- the kiosk
			{ -60, 0, -12 }, -- lawns
		}, "near")
		for _, point in
			setPoints(PX, PZ, PTURN, 0.1, {
				{ 26, 0, 8 }, -- oaks
				{ 6.5, 0, 9.85 }, -- the pond bank
				{ -50, 0, 10 }, -- lawns
				{ 50, 0, 6 },
				{ 56, 0, 14 },
				{ -60, 0, 24 }, -- by the second hedge row
				{ -3, 1.15, 40.5 }, -- the bandstand
				{ 3, 1.15, 41 },
				{ 0, 1.15, 44 },
				{ -9.75, 0, 53.93 }, -- the loop path
				{ -15.97, 0, 45.81 },
				{ -27, 0, 52 }, -- the slide
				{ -46, 0, 45 }, -- the swings
				{ -63.5, 0.55, 46.5 }, -- the sandbox
				{ -44, 0, 30 }, -- the seesaw
				{ -60, 0.72, 33 }, -- the roundabout
				{ -36, 0, 39 }, -- the playground
				{ 46, 0, 35.5 }, -- the fountain
				{ 46, 0.57, 48.6 }, -- the rose beds
				{ 56.74, 0, 33.8 },
				{ 62.5, 0, 48 }, -- the topiary
				{ 31, 0, 50 }, -- the flower garden
				{ -40, 0, 54 }, -- the far end
				{ 6, 0, 55 },
			}, "deep")
		do
			table.insert(points, point)
		end
		return points
	end)(),
	-- a tree's branch points along its -X, a bin's open lid is at its back
	rescueSpots = {
		setPropTrap(PX, PZ, PTURN, "CatCafe_Park_RescueTree", "tree", { -28, 0, -16 }, 180),
		setPropTrap(PX, PZ, PTURN, "CatCafe_Park_RescueTree", "tree", { -18, 0, 27 }, 180),
		setPropTrap(PX, PZ, PTURN, "CatCafe_Park_RescueTree", "tree", { 20, 0, 53 }, -90),
		setPropTrap(PX, PZ, PTURN, "CatCafe_Park_TrashCan", "trashcan", { 10, 0, -38.5 }, 0),
		setPropTrap(PX, PZ, PTURN, "CatCafe_Park_TrashCan", "trashcan", { -14, 0, 23.5 }, 90),
	},
	props = {},
} :: AreaSpec

-- Areas 3 to 5 have their kit sets (Model-Agent #401, area-sets.md): the strays' spawn points are the sets' cat
-- spots and the Woods' and Sewer's traps are built into the sets. The graybox paths and props below stand in only
-- while a set's art is missing. Since v3.1 (F77) the Neighbourhood opens on its -Z side at the street's north end,
-- the Woods on its +X side and the Sewer on its -X side, through the back alleys' outer walls.
local NX, NZ = W.NeighbourhoodCenterX, W.NeighbourhoodCenterZ
local NHW, NHD = W.NeighbourhoodWidth / 2, W.NeighbourhoodDepth / 2
-- The Neighbourhood (areas-and-stations.md, design #240): the gate opens onto Whisker Lane, which runs 58 studs
-- north to a square loop road around the playground hub; five houses ring the loop and two back gardens sit in the
-- far corners. Offsets below are from the area's center.
local HUB = 18 -- the hub's center, north of the area's center
local LOOP, ROAD = 30, 8 -- the loop road's outer half size and its width
local LS, LN = NZ + HUB - LOOP, NZ + HUB + LOOP -- the loop's south and north edges
local NTURN = townTurn(NX, NZ, nil, W.NeighbourhoodGateZ)
Layout.neighbourhood = {
	floorY = 0.1,
	center = { x = NX, y = 0, z = NZ },
	halfWidth = NHW,
	halfDepth = NHD,
	gateZ = W.NeighbourhoodGateZ,
	paths = {
		{ x1 = NX - 5, z1 = NZ - NHD, x2 = NX + 5, z2 = LS }, -- Whisker Lane
		{ x1 = NX - LOOP, z1 = LS, x2 = NX + LOOP, z2 = LS + ROAD }, -- the loop, south
		{ x1 = NX - LOOP, z1 = LN - ROAD, x2 = NX + LOOP, z2 = LN }, -- north
		{ x1 = NX - LOOP, z1 = LS + ROAD, x2 = NX - LOOP + ROAD, z2 = LN - ROAD }, -- west
		{ x1 = NX + LOOP - ROAD, z1 = LS + ROAD, x2 = NX + LOOP, z2 = LN - ROAD }, -- east
	},
	set = "CatCafe_Neighbourhood_Set",
	-- The set's cat spots, all but the shed (the trap) and the three flower beds under 4 studs from their porches.
	spawnPoints = setPoints(NX, NZ, NTURN, 0.1, {
		-- porch steps
		{ 19.6, 1.0, -58.8 },
		{ -19.6, 1.0, -53.2 },
		{ 19.6, 1.0, -33.3 },
		{ -19.6, 1.0, -23.2 },
		{ 7.3, 1.0, 54.6 },
		{ -24.71, 1.0, 44.39 },
		{ 28.3, 1.0, 40.1 },
		{ -34.56, 1.0, 16.75 },
		{ 32.81, 1.0, 6.8 },
		-- flower beds
		{ 16.3, 0.7, -62.5 },
		{ -16.3, 0.7, -49.5 },
		{ -16.3, 0.7, -19.5 },
		{ -19.8, 0.7, 45.1 },
		{ 28.16, 0.7, 35.14 },
		{ -31.95, 0.7, 20.97 },
		-- the hub: the tyre, under the slide, the sandpit
		{ -7.65, 0.32, 24.1 },
		{ 9.68, 0.32, 23.12 },
		{ 8.39, 0.87, 12.97 },
		-- the back gardens
		{ -60.5, 1.73, 58 },
		{ 58, 0, 56 },
		-- driveways, the bins and the ice cream van
		{ -18, 0, -41.5 },
		{ 16, 0, -41.5 },
		{ -16, 0, -11.5 },
		{ 16, 0, -11.5 },
		{ -30.6, 0.3, -12.5 },
		{ -22.41, 0.24, 14.08 },
	}),
	rescueSpots = {
		-- The set's jammed shed door, and the gutter's stand-in drainpipe in front of the far gardens' hedge.
		setTrap(NX, NZ, NTURN, "shed", { 59.2, 0, 40 }),
		{ prop = "CatCafe_Alley_Drainpipe", trap = "gutter", x = NX + 16, z = NZ + 62 },
	},
	props = {
		{ asset = "CatCafe_Alley_StreetLamp", x = NX - 16, z = NZ - NHD + 3 },
		{ asset = "CatCafe_Alley_StreetLamp", x = NX + 16, z = NZ - NHD + 3 },
		{ asset = "CatCafe_Alley_TrashCan", x = NX - 40, z = NZ - 60 }, -- the recycling bins
		{ asset = "CatCafe_Alley_Crate", x = NX + 40, z = NZ - 60 },
		{ asset = "CatCafe_Park_Tree", x = NX, z = NZ + HUB }, -- the big oak in the hub
		{ asset = "CatCafe_Park_Tree", x = NX - 56, z = NZ + 20 },
		{ asset = "CatCafe_Park_Tree", x = NX + 56, z = NZ + 20 },
		{ asset = "CatCafe_Park_Bench", x = NX - 14, z = NZ + 6, rotY = 90 },
	},
} :: AreaSpec

-- The Woods and the Sewer keep their v3 graybox props, planned facing the town on their +Z side, turned a quarter so
-- that side faces the town (town-layout-v3.md section 7f): an offset (dx, dz) becomes (dz, -dx) for the Woods
-- (quarter 1, the town toward +X) and (-dz, dx) for the Sewer (quarter -1), and a turn rotY becomes rotY + 90 x
-- quarter. Their kit sets bring their own cat spots and traps.
local function quarterTurn(quarter: number, dx: number, dz: number): (number, number)
	return quarter * dz, -quarter * dx
end

local function propTurned(
	cx: number,
	cz: number,
	quarter: number,
	asset: string,
	dx: number,
	dz: number
): Prop
	local x, z = quarterTurn(quarter, dx, dz)
	return { asset = asset, x = cx + x, z = cz + z, rotY = 90 * quarter }
end

-- The Woods at its v3.2 size (F81, town-layout-v3.md section 8): Model-Agent's CatCafe_Woods_SetV32 (#470, area-sets.md
-- "The Woods (v3.2)") fills the 240 x 240 floor, its trail winding through the one gap in the tree line, over the one
-- log bridge and through the one gap in the rock ridge to the Great Oak. Its cat spots are `near` on the gate half and
-- `deep` on the far half, and the Great Oak's top nook is `rare` (Catching.RARE_ZONE: only a Rare or better waits
-- there, and one goes there first). Its hollow logs and bramble bushes are built into the set, each turned in it, two
-- of the four deep, and a cat can get stuck up the tree house's branch.
local WX, WZ = W.WoodsCenterX, W.WoodsCenterZ
local WTURN = townTurn(WX, WZ, W.WoodsGateX, nil)
Layout.woods = {
	floorY = 0.1,
	center = { x = WX, y = 0, z = WZ },
	halfWidth = W.WoodsWidth / 2,
	halfDepth = W.WoodsDepth / 2,
	gateX = W.WoodsGateX,
	openingHalfWidth = GH,
	set = "CatCafe_Woods_SetV32",
	spawnPoints = (function(): { Point }
		local points = setPoints(WX, WZ, WTURN, 0.1, {
			{ -43.5, 0, -22.5 }, -- the log bridge
			{ 104, 0, -23.51 }, -- the waterfall
			{ 75.61, 0, -103.84 }, -- the tents
			{ 84.61, 0, -102.05 },
			{ 74, 2.06, -95 }, -- log benches
			{ 86, 2.06, -94 },
			{ 80.5, 0, -88.5 }, -- the campfire
			{ -30, 0, -99.8 }, -- berry bushes
			{ -48, 0, -107.8 },
			{ -62, 0, -93.8 },
			{ 100, 0, -79.8 },
			{ -16, 0, -84 }, -- leaf piles
			{ -100, 0, -42 },
			{ -82, 1.66, -100 }, -- stumps
			{ -40, 1.66, -80 },
			{ 86, 1.66, -58 },
			{ -94, 2, -82 }, -- mossy rocks
			{ 66, 2, -38 },
			{ -70, 2, -30 },
			{ -72, 0, -76 }, -- ferns
			{ 24, 0, -30 },
			{ -22, 0, -50 },
			{ 90, 0, -48 },
			{ -93.1, 0, -106.36 }, -- fallen logs
			{ 61.56, 0, -56.89 },
			{ 0, 0.05, -56 }, -- the mushroom ring
		}, "near")
		for _, point in
			setPoints(WX, WZ, WTURN, 0.1, {
				{ -32.5, 0, 10.5 }, -- the log bridge
				{ -20, 2.06, 100 }, -- log benches
				{ -56, 2.06, 100 },
				{ -24, 2.06, 72 },
				{ -14, 0, 30.2 }, -- berry bushes
				{ 6, 0, 35.2 },
				{ 22, 0, 22.2 },
				{ -30, 0, 28.2 },
				{ 104, 0, 76.2 },
				{ 34, 0, 14 }, -- leaf piles
				{ 28, 0, 84 },
				{ -104, 1.66, 34 }, -- stumps
				{ 44, 1.66, 100 },
				{ 70, 2, 34 }, -- mossy rocks
				{ -96, 2, 10 },
				{ 64, 2, 80 },
				{ 96, 2, 66 },
				{ 100, 0, 6 }, -- ferns
				{ -50, 0, 36 },
				{ 8, 0, 14 },
				{ 80, 0, 100 },
				{ 52, 0, 66 },
				{ 83.49, 0, 81.87 }, -- fallen logs
				{ 50, 0, 18.5 }, -- glow mushrooms
				{ -98, 0, 88.5 },
				{ 66, 0, 100.5 },
				{ -60.05, 0, 14.62 }, -- the log pile
				{ -78, 0, 6 }, -- glades
				{ -6, 0, 18 },
				{ -44.71, 0, 86.88 }, -- in the Great Oak's roots
				{ -42.32, 0, 93.25 },
				{ -35.39, 0, 94.28 },
				{ -87.22, 10.3, 71.77 }, -- the tree house's cushion, up its ladder
				{ -79.64, 0, 78.98 }, -- at the foot of the tree house
				{ 2, 0, 102 }, -- the lookout tower
				{ -58, 0, 64 }, -- the oak's clearing
				{ -78, 0, 104 },
				{ 84, 0, 54 }, -- the dell
			}, "deep")
		do
			table.insert(points, point)
		end
		-- up the ladder inside the Great Oak to its top nook (Derek 2026-10-28 01:35: a higher rare chance there)
		table.insert(points, setPoints(WX, WZ, WTURN, 0.1, { { -36.31, 18.3, 87.37 } }, "rare")[1])
		return points
	end)(),
	rescueSpots = {
		-- a hollow log's open end faces its own +X; a bramble is round
		setTrap(WX, WZ, WTURN, "hollow_log", { 78, 0, -40 }, 20),
		setTrap(WX, WZ, WTURN, "hollow_log", { 92, 0, 26 }, -20),
		setTrap(WX, WZ, WTURN, "bramble_bush", { -84, 0, -50 }),
		setTrap(WX, WZ, WTURN, "bramble_bush", { -86, 0, 30 }),
		-- up the tree house's branch (Derek 01:34), reached from its deck: shaken down and caught like a Park tree,
		-- the cat lying across the branch (which points along the piece's -X) as on a Park tree
		setTrap(WX, WZ, WTURN, "tree", { -88.85, 15.45, 68.06 }, -106.26),
	},
	props = {},
} :: AreaSpec

local SX, SZ = W.SewerCenterX, W.SewerCenterZ
local SHD = W.SewerWidth / 2 -- the plan's depth runs along X once turned
local STURN = townTurn(SX, SZ, W.SewerGateX, nil)
Layout.sewer = {
	floorY = 0.1,
	center = { x = SX, y = 0, z = SZ },
	halfWidth = W.SewerWidth / 2,
	halfDepth = W.SewerDepth / 2,
	gateX = W.SewerGateX,
	openingHalfWidth = GH,
	set = "CatCafe_Sewer_Set",
	setLift = 0.4, -- the set's tiled slab
	spawnPoints = setPoints(SX, SZ, STURN, 0.1, {
		{ 3, 3.5, -24 }, -- the catwalk
		{ 21.97, 3.3, 23.91 }, -- the junk throne
		{ 13, 0.4, 30 }, -- the toy pile
		{ -31.8, 0.4, 42.8 }, -- the valve
		{ -28, 3.65, 30 }, -- the mine cart
		{ 37.6, 0.4, 38 }, -- a pipe end
		{ 18.6, 0.4, -7 }, -- the market stalls
		{ 18.6, 0.4, 0 },
		{ 18.6, 0.4, 7 },
		{ -15.4, 0.4, 2.27 }, -- the rat houses
		{ -16.51, 0.4, 12.35 },
		{ -13.94, 0.4, -4.57 },
		{ -20.3, 0.4, 6.89 },
		{ 34.12, 1.88, -30.44 }, -- the sofa
		{ 30.6, 2.55, -11.7 }, -- the decks
		{ -30.49, 2.55, -31.54 },
		{ -21, 1.6, -16 }, -- the boat
		{ -11.6, 2.35, -16.6 }, -- the raft
		{ 18, 1, -24 }, -- the trolley
		{ 37, 2.4, 25 }, -- the hammock
	}),
	rescueSpots = {
		setTrap(SX, SZ, STURN, "grate", { -31, 0.4, 2 }),
		setTrap(SX, SZ, STURN, "drain_pipe", { -40, 0.4, -35 }),
	},
	props = {
		-- lamps either side of the opening, then crates and a bin
		propTurned(SX, SZ, -1, "CatCafe_Alley_StreetLamp", -16, SHD - 3),
		propTurned(SX, SZ, -1, "CatCafe_Alley_StreetLamp", 16, SHD - 3),
		propTurned(SX, SZ, -1, "CatCafe_Alley_Crate", -27, 10),
		propTurned(SX, SZ, -1, "CatCafe_Alley_Crate", 27, 5),
		propTurned(SX, SZ, -1, "CatCafe_Alley_TrashCan", -27, -12),
	},
} :: AreaSpec

-- The Town Square (F76, town-layout-v3.md section 3): paved, in the middle of the street and the safe zone, with a
-- fountain at the origin and a cross of open paving through it (the street's line north to south and a lane east to
-- west to the side arches). The four stations stand in its quarters, each turned to face the fountain, so nothing
-- stands on the cross and the walk between the cafes, the arches and the gates is never blocked.
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
	-- trees and flower beds from the square out to the back alleys, a garden wall along the alley with an arch in
	-- the middle of each side
	gardens = {
		{ x1 = -AI, z1 = -TSD, x2 = -TSW, z2 = TSD },
		{ x1 = TSW, z1 = -TSD, x2 = AI, z2 = TSD },
	} :: { Rect },
	-- the side arches into the back alleys, on the gardens' outer edge; `span` is the opening
	arches = {
		{
			x = -AI + 0.5,
			z = 0,
			span = W.TownSquareArchWidth,
			label = "THE ALLEYWAY",
			asset = "CatCafe_Square_ArchAlley",
		},
		{
			x = AI - 0.5,
			z = 0,
			span = W.TownSquareArchWidth,
			label = "THE ALLEYWAY",
			asset = "CatCafe_Square_ArchAlley",
		},
	} :: { Arch },
	fountainRadius = 6, -- with a low rim players can sit on
	-- The finger signpost (v3.1, section 7d) in place of the ring's south-west bench: left of the fountain from the
	-- spawn and off the cross. Its arms point at the four gates.
	signpost = { x = -9, y = 0.1, z = -7.5 } :: Point,
	-- The Town Square set (Model-Agent #435): the asset manifest's placements_roblox rows for each CatCafe_Square_*
	-- piece, in world space (x, y, z, turn in degrees): the paving with its own slab, the fountain, the two sign
	-- arches over the street, seven benches round the fountain, four lamps, four buntings and the four gardens.
	props = {
		{ asset = "CatCafe_Square_Paving", x = 0, y = 0.1, z = 0 },
		{ asset = "CatCafe_Square_Fountain", x = 0, y = 0.1, z = 0 },
		{ asset = "CatCafe_Square_SignArch", x = 0, y = 0.1, z = -32 },
		{ asset = "CatCafe_Square_SignArch", x = 0, y = 0.1, z = 32, rotY = 180 },
		{ asset = "CatCafe_Square_Bench", x = 13.93, y = 0.1, z = 9.75, rotY = 55 },
		{ asset = "CatCafe_Square_Bench", x = 9.75, y = 0.1, z = 13.93, rotY = 35 },
		{ asset = "CatCafe_Square_Bench", x = -9.75, y = 0.1, z = 13.93, rotY = 325 },
		{ asset = "CatCafe_Square_Bench", x = -13.93, y = 0.1, z = 9.75, rotY = 305 },
		{ asset = "CatCafe_Square_Bench", x = -9.75, y = 0.1, z = -13.93, rotY = 215 },
		{ asset = "CatCafe_Square_Bench", x = 9.75, y = 0.1, z = -13.93, rotY = 145 },
		{ asset = "CatCafe_Square_Bench", x = 13.93, y = 0.1, z = -9.75, rotY = 125 },
		{ asset = "CatCafe_Square_Lamp", x = -11, y = 0.1, z = -11, rotY = 45 },
		{ asset = "CatCafe_Square_Lamp", x = -11, y = 0.1, z = 11, rotY = 45 },
		{ asset = "CatCafe_Square_Lamp", x = 11, y = 0.1, z = -11, rotY = 45 },
		{ asset = "CatCafe_Square_Lamp", x = 11, y = 0.1, z = 11, rotY = 45 },
		{ asset = "CatCafe_Square_Bunting", x = 0, y = 0.1, z = -11 },
		{ asset = "CatCafe_Square_Bunting", x = 0, y = 0.1, z = 11 },
		{ asset = "CatCafe_Square_Bunting", x = -11, y = 0.1, z = 0, rotY = 90 },
		{ asset = "CatCafe_Square_Bunting", x = 11, y = 0.1, z = 0, rotY = 90 },
		{ asset = "CatCafe_Square_Garden", x = -55.5, y = 0.1, z = -19.5, rotY = -90 },
		{ asset = "CatCafe_Square_Garden", x = -55.5, y = 0.1, z = 19.5, rotY = -90 },
		{ asset = "CatCafe_Square_Garden", x = 55.5, y = 0.1, z = -19.5, rotY = 90 },
		{ asset = "CatCafe_Square_Garden", x = 55.5, y = 0.1, z = 19.5, rotY = 90 },
	} :: { Prop },
}

-- The stations, one per quarter: the Spin Wheel (F49) and the Golden Fish Market (F53) north of the lane, the Codes
-- Cat (F65; its CodesCircle 6 studs in front, toward the fountain) and the night dealer's cart (data-model section
-- 8b, parked from dusk; the dealer stands at its +X end) south of it.
Layout.spinWheel = station(-28, 16)
Layout.fishMarket = station(28, 16)
Layout.codesCat = station(-28, -16)
Layout.dealerCart = station(28, -16)
Layout.dealerNpc = { x = 5.4, y = 0, z = -0.4 } :: Point -- relative to the cart

-- The Index Boards (F50, areas-and-stations.md; the asset manifest's `placement`): one 8 studs inside each area's
-- entrance, to the right of the path for a player walking in and turned 20 degrees toward it. In the space of the
-- area's gate, or for the Alleyway of each of the Town Square's side arches (v3.1: a board inside both), whose +Z
-- all run into the area.
Layout.indexBoards = {
	alley = { x = -9, y = 0, z = 8, rotY = -20 },
	park = { x = -7, y = 0, z = 8, rotY = -20 },
	neighbourhood = { x = -7, y = 0, z = 8, rotY = -20 },
	woods = { x = -10, y = 0, z = 8, rotY = -20 },
	sewer = { x = -10, y = 0, z = 8, rotY = -20 },
} :: { [string]: Point }

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

-- The paw paths (town-layout-v3.md section 7d): from the fountain's ring along an arm of the cross to each gated
-- area's gate and PAW_PAST studs into it, a print every PAW_STRIDE studs, left and right of the line like a walking
-- cat. A print skips the flat marks it would lie on (the SAFE ZONE words and red stripe by each side arch and street
-- gate) and the wall line at a side gate. `y` is the top of what it lies on; `rotY` turns its front (-Z) toward the
-- gate.
export type PawPrint = { area: string, x: number, y: number, z: number, rotY: number }

local PAW_STRIDE = 3.5
local PAW_PAST = 10
local PAW_SIDE = 0.7 -- left or right of the line

-- The top of what lies at (x, z) on a paw path: the square's lane marks over its paving, a box area's road, the
-- street and the alley and area floors, else the gardens' grass.
local function pawSurface(x: number, z: number, spec: AreaSpec): number
	if math.abs(x) <= TSW and math.abs(z) <= TSD then
		return 0.12
	end
	local paths: { Rect } = spec.paths or {}
	for _, rect in paths do
		if x >= rect.x1 and x <= rect.x2 and z >= rect.z1 and z <= rect.z2 then
			return spec.floorY + 0.05
		end
	end
	local onStreet = math.abs(x) <= W.StreetHalfWidth and math.abs(z) <= W.StreetNorthZ
	local inAlley = math.abs(x) >= AI and math.abs(x) <= AO
	local inArea = math.abs(x - spec.center.x) <= spec.halfWidth
		and math.abs(z - spec.center.z) <= spec.halfDepth
	return if onStreet or inAlley or inArea then 0.1 else 0
end

function Layout.pawPrints(): { PawPrint }
	local prints: { PawPrint } = {}
	for id, spec in Layout.areas do
		local gx, gz = Layout.gatePosition(spec)
		if gx == nil or gz == nil then
			continue
		end
		-- along the cross from the origin: a side gate straight out along X, a street gate along Z
		local ux, uz = 0, 0
		local gate: number
		local skips: { { number } }
		if spec.gateX ~= nil then
			ux, gate = math.sign(gx), math.abs(gx)
			skips = { { AI - 5, AI + 1 }, { AO - 0.5, gate + 2 } }
		else
			uz, gate = math.sign(gz), math.abs(gz)
			skips = { { gate - 5.5, gate + 2.5 } }
		end
		local rotY = math.deg(math.atan2(-ux, -uz))
		local d, k = Layout.townSquare.fountainRadius + 2, 0
		while d <= gate + PAW_PAST do
			local skipped = false
			for _, skip in skips do
				if d >= skip[1] and d <= skip[2] then
					skipped = true
				end
			end
			if not skipped then
				local side = if k % 2 == 0 then -PAW_SIDE else PAW_SIDE
				-- the line's right hand is (-uz, ux) for a walker facing (ux, uz)
				local x, z = ux * d - uz * side, uz * d + ux * side
				table.insert(
					prints,
					{ area = id, x = x, y = pawSurface(x, z, spec), z = z, rotY = rotY }
				)
			end
			d += PAW_STRIDE
			k += 1
		end
	end
	return prints
end

-- Player spawn in the Town Square on the street's line, looking north at the fountain (WorldBuilder turns it by
-- rotY, and a character spawns facing the way its SpawnLocation faces).
Layout.playerSpawn = { x = 0, y = 0.6, z = -14, rotY = 180 } :: Point

return Layout
