--!strict
-- Pure geometry for the world: where plots sit on the street and where everything inside a plot goes.
-- Plot-local space: X runs along the street, Z is depth, -Z faces the street, y = 0 is the floor top.
-- No Roblox globals, so tests can check the numbers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

-- zone tags a spawn point "lane" (behind a cafe) or "square" (the Alley Square); rarer strays take only "square".
export type Point = { x: number, y: number, z: number, rotY: number?, zone: string? }
-- An axis-aligned rectangle on the ground, world or plot space depending on where it is used.
export type Rect = { x1: number, z1: number, x2: number, z2: number }
-- A rescue trap: the prop stands at (x, floor, z) turned by rotY; the stuck cat sits at Layout.stuckPoses[prop].
-- `trap` is the TrapType (data-model section 9): a "tree" is shaken then caught, every other trap is the bar.
export type RescuePoint = { prop: string, trap: string, x: number, z: number, rotY: number? }
-- y is the height above the area floor (0 when omitted); wall props set it.
export type Prop = { asset: string, x: number, y: number?, z: number, rotY: number? }
-- A shared area in world space. A box area (no rects) is one floor with walls on three sides and a street-wide
-- opening in its near wall, the one facing the street's end. An area with rects (the Alleyway) is those floors
-- with the listed wall footprints and arches; center, halfWidth and halfDepth are then its bounding box.
export type AreaSpec = {
	floorY: number,
	center: Point,
	halfWidth: number,
	halfDepth: number,
	gateZ: number?, -- where the tier gate stands across the opening; nil for the Tier 1 alley
	openingHalfWidth: number?, -- half the opening of a box area; the street's half width when omitted
	rects: { Rect }?,
	walls: { Rect }?, -- wall footprints for a rects area
	roam: { Rect }?, -- where strays may walk when props line the walls; the floor pieces when nil
	wallHeight: number?,
	-- archways a rects area is entered by: the alley kit's asset when it is there, else posts, beam and label
	arches: { { x: number, z: number, span: number, label: string, asset: string? } }?,
	arrival: Point?, -- where fast travel lands; a box area lands just inside its opening
	spawnPoints: { Point },
	lureSpots: { Point },
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
	-- Along the shakeable branch, head toward the trunk.
	CatCafe_Park_RescueTree = { -1.7, 4, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0 },
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

-- World position of plot `index` (1-based) and which side of the street it is on (-1 left, +1 right). Out from
-- the street: the sidewalk to |x| 14, the front garden, the front wall, the cafe floor, the back wall and the yard.
function Layout.plotPlacement(index: number): { x: number, z: number, side: number }
	local i = index - 1
	local side = if i % 2 == 0 then -1 else 1
	local row = math.floor(i / 2)
	local rows = math.ceil(W.PlotCount / 2)
	local z = (row - (rows - 1) / 2) * (W.PlotWidth + W.PlotRowGap)
	local x = side * (W.StreetHalfWidth + 2 + W.FrontGardenDepth + 1 + W.PlotDepth / 2)
	return { x = x, z = z, side = side }
end

local halfW = W.PlotWidth / 2 -- 18
local halfD = W.PlotDepth / 2 -- 14
local yardZ1, yardZ2 = halfD + 1, halfD + 1 + W.YardDepth -- 15, 25
local yardMid = (yardZ1 + yardZ2) / 2

Layout.plot = {
	door = { x = 0, y = 0, z = -halfD } :: Point,
	entry = { x = 0, y = 0, z = -halfD - 1 - W.FrontGardenDepth - 1 } :: Point, -- customer start, on the sidewalk
	sign = { x = 0, y = 7.5, z = -halfD - 0.3 } :: Point,
	counter = { x = 0, y = 0, z = halfD - 3 } :: Point,
	espresso = { x = 2.6, y = 3.1, z = halfD - 3 } :: Point,

	-- Where a working cat stands, per role slot: baristas on the counter, waiters between the tables, greeters
	-- inside the door, entertainers on the cat trees. The role stations and upright poses come with the roles.
	spots = {
		barista_1 = { x = -2, y = 3.1, z = halfD - 3 },
		barista_2 = { x = -3.4, y = 3.1, z = halfD - 3 },
		barista_3 = { x = 0.4, y = 3.1, z = halfD - 3 },
		waiter_1 = { x = -4.5, y = 0, z = -2.5 },
		waiter_2 = { x = 4.5, y = 0, z = -2.5 },
		waiter_3 = { x = 0, y = 0, z = 4.5 },
		greeter_1 = { x = -4, y = 0, z = -halfD + 2.5 },
		greeter_2 = { x = 4, y = 0, z = -halfD + 2.5 },
		entertainer_1 = { x = -14, y = 4.65, z = 8 },
		entertainer_2 = { x = 14, y = 4.65, z = 8 },
	} :: { [string]: Point },

	-- Station furniture under a slot, for the roles that have one (Catalog.spotFurniture)
	spotFurniture = {
		entertainer_1 = { x = -14, y = 0, z = 8 },
		entertainer_2 = { x = 14, y = 0, z = 8 },
	} :: { [string]: Point },

	decorAnchors = {
		plants = { x = 13, y = 1.2, z = -halfD + 0.7 },
		rug = { x = 0, y = 0, z = -2 },
		neon_sign = { x = 0, y = 5.5, z = halfD - 0.7 },
		fish_tank = { x = -halfW + 2, y = 0, z = 0, rotY = 90 },
	} :: { [string]: Point },

	tables = {
		{ x = -9, y = 0, z = -6 },
		{ x = 0, y = 0, z = -6 },
		{ x = 9, y = 0, z = -6 },
		{ x = -9, y = 0, z = 1 },
		{ x = 0, y = 0, z = 1 },
		{ x = 9, y = 0, z = 1 },
	} :: { Point },

	-- The rich customer's coin pile (data-model section 12): on top of table 1 (2.6 tall), where the rich customer
	-- sits. The UI's gold marker floats over it and ClaimRichTip measures range from it.
	richTip = { x = -9, y = 2.7, z = -6 } :: Point,

	-- The back door, between the counter and the left cat tree, opens from Tier 1 onto the yard; the yard's gate
	-- lines up with it so the way out to the back alley is straight.
	backDoor = { x = -8, width = 6, height = 7.5 },

	-- The front garden strip between the sidewalk and the front wall, and the path through it to the door.
	frontGarden = {
		x1 = -halfW - 1,
		z1 = -halfD - 1 - W.FrontGardenDepth,
		x2 = halfW + 1,
		z2 = -halfD - 1,
	} :: Rect,
	frontPath = { x1 = -2.5, z1 = -halfD - 1 - W.FrontGardenDepth, x2 = 2.5, z2 = -halfD - 1 } :: Rect,

	-- The bait bowl (data-model section 8) just inside the garden fence, right of the path, so the street sees
	-- the cat that comes to eat. Clear of the shells' pots, flowers and fence posts and of the Tier 2 bench; the
	-- cat stands beside it with its head over the bowl.
	baitBowl = { x = 9, y = 0, z = -halfD - W.FrontGardenDepth } :: Point,
	baitCat = { x = 10.6, y = 0, z = -halfD - W.FrontGardenDepth, rotY = 90 } :: Point,

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

-- The Alleyway (layout v2, data-model section 9): a 30 stud back alley behind each row of cafes, from the south
-- end of the street to the Alley Square that spans the whole width at the north end. Every cafe's yard gate and
-- the side passages between cafes open onto a back alley; the street runs into the Square under an arch.
local AI, AO = W.AlleyInnerX, W.AlleyOuterX
local SQ1, SQ2 = W.SquareSouthZ, W.SquareNorthZ
local SH = W.StreetHalfWidth + 2 -- the street and its sidewalks
local NH = W.NeighbourhoodWidth / 2 -- the Neighbourhood's near wall closes the middle of the Square's north side

-- Two lane spawn points behind every cafe, in plot order: plot p owns alley points 2p - 1 and 2p, so the tutorial
-- stray waits right outside a beginner's own yard gate. Then eight in the Square, where Epic and rarer strays go.
local function alleySpawnPoints(): { Point }
	local points: { Point } = {}
	for index = 1, W.PlotCount do
		local placement = Layout.plotPlacement(index)
		local side = placement.side
		table.insert(points, { x = side * (AI + 7), y = 0.1, z = placement.z - 7, zone = "lane" })
		table.insert(points, { x = side * (AO - 7), y = 0.1, z = placement.z + 9, zone = "lane" })
	end
	for _, xz in
		{
			{ -72, 104 },
			{ -44, 128 },
			{ -18, 142 },
			{ 8, 112 },
			{ 32, 138 },
			{ 58, 106 },
			{ 76, 130 },
			{ -66, 140 },
		}
	do
		table.insert(points, { x = xz[1], y = 0.1, z = xz[2], zone = "square" })
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

-- Six building backs (30.6 wide) along each back alley's outer wall, from the Woods and Sewer gates north to the
-- Square, so the lane reads as the backs of buildings rather than a bare wall (world-and-feel.md section 2).
local BACK_SLOTS = { -84.7, -53.7, -22.7, 8.3, 39.3, 70.3 }
-- The fire escape's first landing (top 9.35) is reached from the crate stack's tall column (top 7.7), which
-- stands just past the landing's open end at local x -8 (asset manifest, ledges_roblox).
local CRATES_ALONG, CRATES_OUT = -12, -2.8

local function alleyDressing(): { Prop }
	local props: { Prop } = {}
	local function add(prop: Prop)
		table.insert(props, prop)
	end
	local rows = {
		[-1] = { "WallWindows", "WallDoor", "WallWindows", "FireEscape", "WallWindows", "WallDoor" },
		[1] = { "WallDoor", "WallWindows", "FireEscape", "WallWindows", "WallDoor", "WallWindows" },
	}
	for _, side in { -1, 1 } do
		for slot, piece in rows[side] do
			local z = BACK_SLOTS[slot]
			add(onOuterWall("CatCafe_Alley_" .. piece, side, z))
			if piece == "FireEscape" then
				add(onOuterWall("CatCafe_Alley_CrateStack", side, z, CRATES_ALONG, CRATES_OUT))
			end
		end
		-- String lights across the lane in the gaps between buildings, a laundry line in front of a windowed back.
		for _, z in { -69.2, -38.2, 23.8, 54.8 } do
			add({ asset = "CatCafe_Alley_StringLightsLong", x = side * (AI + AO) / 2, z = z })
		end
		add({
			asset = "CatCafe_Alley_LaundryLine",
			x = side * ((AI + AO) / 2 - 0.4),
			z = if side < 0 then BACK_SLOTS[5] else BACK_SLOTS[2],
		})
	end
	-- The Square: the mural faces the street arch, a staff door beside it, a fire escape with its crates on the
	-- west wall and windows on the east.
	add({ asset = "CatCafe_Alley_Mural", x = -67, z = SQ2 })
	add({ asset = "CatCafe_Alley_WallDoor", x = 67, z = SQ2 })
	local squareMid = (SQ1 + SQ2) / 2
	add(onOuterWall("CatCafe_Alley_FireEscape", -1, squareMid))
	add(onOuterWall("CatCafe_Alley_CrateStack", -1, squareMid, CRATES_ALONG, CRATES_OUT))
	add(onOuterWall("CatCafe_Alley_WallWindows", 1, squareMid))
	add({ asset = "CatCafe_Alley_StringLightsLong", x = -40, z = SQ1 + 30, rotY = 90 })
	add({ asset = "CatCafe_Alley_StringLightsLong", x = 40, z = SQ1 + 30, rotY = 90 })
	return props
end

Layout.alley = {
	floorY = 0.1,
	center = { x = 0, y = 0, z = (W.AlleySouthZ + SQ2) / 2 },
	halfWidth = AO,
	halfDepth = (SQ2 - W.AlleySouthZ) / 2,
	rects = {
		{ x1 = -AO, z1 = W.AlleySouthZ, x2 = -AI, z2 = SQ1 }, -- west back alley
		{ x1 = AI, z1 = W.AlleySouthZ, x2 = AO, z2 = SQ1 }, -- east back alley
		{ x1 = -AO, z1 = SQ1, x2 = AO, z2 = SQ2 }, -- the Alley Square
	},
	walls = {
		{ x1 = -AO - 1, z1 = W.AlleySouthZ, x2 = -AO, z2 = SQ2 + 1 }, -- west outer wall
		{ x1 = AO, z1 = W.AlleySouthZ, x2 = AO + 1, z2 = SQ2 + 1 }, -- east outer wall
		{ x1 = -AO, z1 = SQ2, x2 = -NH, z2 = SQ2 + 1 }, -- north wall, west of the Neighbourhood
		{ x1 = NH, z1 = SQ2, x2 = AO, z2 = SQ2 + 1 }, -- north wall, east of the Neighbourhood
		{ x1 = -AI, z1 = SQ1 - 1, x2 = -SH, z2 = SQ1 }, -- south wall between the west alley and the street
		{ x1 = SH, z1 = SQ1 - 1, x2 = AI, z2 = SQ1 }, -- south wall between the street and the east alley
	},
	-- Strays keep off the strip along the outer walls where the building backs, fire escapes and crate stacks
	-- stand (up to 5 studs deep), and off the Square's north wall with its mural and staff door.
	roam = {
		{ x1 = -AO + 5, z1 = W.AlleySouthZ, x2 = -AI, z2 = SQ1 },
		{ x1 = AI, z1 = W.AlleySouthZ, x2 = AO - 5, z2 = SQ1 },
		{ x1 = -AO + 5, z1 = SQ1, x2 = AO - 5, z2 = SQ2 - 3.5 },
	},
	wallHeight = 10,
	arches = {
		{
			x = 0,
			z = SQ1 - 0.5,
			span = SH * 2,
			label = "THE ALLEYWAY",
			asset = "CatCafe_Alley_ArchStreet",
		},
		{
			x = -(AI + AO) / 2,
			z = SQ1 - 0.5,
			span = AO - AI,
			label = "ALLEY SQUARE",
			asset = "CatCafe_Alley_Arch",
		},
		{
			x = (AI + AO) / 2,
			z = SQ1 - 0.5,
			span = AO - AI,
			label = "ALLEY SQUARE",
			asset = "CatCafe_Alley_Arch",
		},
	},
	arrival = { x = 0, y = 0.1, z = SQ1 + 6, rotY = 180 }, -- just inside the street arch, facing into the Square
	spawnPoints = alleySpawnPoints(),
	lureSpots = {
		{ x = -30, y = 0.1, z = SQ1 + 14 },
		{ x = 30, y = 0.1, z = SQ1 + 14 },
	} :: { Point },
	rescueSpots = {
		-- A trash bin in each back alley against the outer wall, lid toward the lane, and the garbage bags in the
		-- Square against the north wall (data-model section 9). The east bin keeps 9 studs from plot 6's lane
		-- spawn point (82, 31), so a stray there never takes the rescue's prompt (reviewer N77).
		{ prop = "CatCafe_Alley_TrashBin", trap = "trash_bin", x = -AO + 4.5, z = -30, rotY = -90 },
		{ prop = "CatCafe_Alley_TrashBin", trap = "trash_bin", x = AO - 4.5, z = 22, rotY = 90 },
		-- between the mural and the Neighbourhood
		{ prop = "CatCafe_Alley_GarbageBags", trap = "garbage_bag", x = -49, z = SQ2 - 1.6 },
	} :: { RescuePoint },
	-- The building backs, crate stacks, lights and laundry from alleyDressing, then the loose props in front of
	-- them: clear of the backs' depth (2.7 windows, 3.4 door canopy, 5 fire escape) and of the lane spawn points.
	props = (function(): { Prop }
		local props = alleyDressing()
		for _, prop in
			{
				-- West back alley: a dumpster corner with bags, a bin by the windows, a crate by the staff door
				{ asset = "CatCafe_Alley_Dumpster", x = -AO + 4.8, z = -80, rotY = 90 },
				{ asset = "CatCafe_Alley_GarbageBags", x = -AO + 4.6, z = -73, rotY = 90 },
				{ asset = "CatCafe_Alley_TrashCan", x = -AO + 3.8, z = 30 },
				{ asset = "CatCafe_Alley_Crate", x = -AO + 4.5, z = 60 },
				{ asset = "CatCafe_Alley_Puddle", x = -72, z = -40 },
				{ asset = "CatCafe_Alley_Puddle", x = -70, z = 46 },
				-- East back alley
				{ asset = "CatCafe_Alley_Dumpster", x = AO - 4.8, z = 64, rotY = -90 },
				{ asset = "CatCafe_Alley_GarbageBags", x = AO - 4.6, z = 57, rotY = -90 },
				{ asset = "CatCafe_Alley_TrashCan", x = AO - 3.8, z = -45 },
				{ asset = "CatCafe_Alley_Crate", x = AO - 3.8, z = -62 },
				{ asset = "CatCafe_Alley_Puddle", x = 76, z = -12 },
				{ asset = "CatCafe_Alley_Puddle", x = 71, z = 26 },
				-- The Square: a dumpster corner, crates, lamps either side of the street arch, puddles that shine
				{ asset = "CatCafe_Alley_Dumpster", x = -AO + 3, z = SQ2 - 8, rotY = 90 },
				{ asset = "CatCafe_Alley_Crate", x = AO - 4, z = SQ2 - 4 },
				{ asset = "CatCafe_Alley_Crate", x = AO - 2.5, z = SQ2 - 6.5 },
				{ asset = "CatCafe_Alley_TrashCan", x = 40, z = SQ2 - 2 },
				{ asset = "CatCafe_Alley_StreetLamp", x = -SH - 4, z = SQ1 + 4 },
				{ asset = "CatCafe_Alley_StreetLamp", x = SH + 4, z = SQ1 + 4 },
				{ asset = "CatCafe_Alley_Puddle", x = -26, z = SQ1 + 22 },
				{ asset = "CatCafe_Alley_Puddle", x = 20, z = SQ1 + 40 },
			} :: { Prop }
		do
			table.insert(props, prop)
		end
		return props
	end)(),
} :: AreaSpec

Layout.park = {
	floorY = 0.1,
	center = { x = 0, y = 0, z = W.ParkCenterZ },
	halfWidth = W.ParkWidth / 2,
	halfDepth = W.ParkDepth / 2,
	gateZ = W.ParkGateZ,
	spawnPoints = {
		{ x = -14, y = 0.1, z = W.ParkCenterZ + 20 },
		{ x = 16, y = 0.1, z = W.ParkCenterZ + 18 },
		{ x = -30, y = 0.1, z = W.ParkCenterZ + 10 },
		{ x = 32, y = 0.1, z = W.ParkCenterZ + 6 },
		{ x = -20, y = 0.1, z = W.ParkCenterZ - 4 },
		{ x = 22, y = 0.1, z = W.ParkCenterZ - 6 },
		{ x = -34, y = 0.1, z = W.ParkCenterZ - 14 },
		{ x = 34, y = 0.1, z = W.ParkCenterZ - 18 },
		{ x = -8, y = 0.1, z = W.ParkCenterZ - 22 },
		{ x = 10, y = 0.1, z = W.ParkCenterZ - 24 },
		{ x = 0, y = 0.1, z = W.ParkCenterZ + 18 },
		{ x = -14, y = 0.1, z = W.ParkCenterZ },
		{ x = 12, y = 0.1, z = W.ParkCenterZ - 2 },
		{ x = 0, y = 0.1, z = W.ParkCenterZ - 14 },
	} :: { Point },
	lureSpots = {
		{ x = -12, y = 0.1, z = W.ParkCenterZ + 6 },
		{ x = 12, y = 0.1, z = W.ParkCenterZ - 12 },
		{ x = 28, y = 0.1, z = W.ParkCenterZ + 22 },
	} :: { Point },
	rescueSpots = {
		-- Branches reach toward the middle of the park (a tree's branch points along its -X).
		{ prop = "CatCafe_Park_RescueTree", trap = "tree", x = 36, z = W.ParkCenterZ + 26 },
		{
			prop = "CatCafe_Park_RescueTree",
			trap = "tree",
			x = -36,
			z = W.ParkCenterZ - 25,
			rotY = 180,
		},
		{
			prop = "CatCafe_Park_TrashCan",
			trap = "trashcan",
			x = 24,
			z = W.ParkCenterZ - 25,
			rotY = 90,
		},
	} :: { RescuePoint },
	props = {
		{ asset = "CatCafe_Park_Fountain", x = 0, z = W.ParkCenterZ },
		{ asset = "CatCafe_Park_Tree", x = -26, z = W.ParkCenterZ + 18 },
		{ asset = "CatCafe_Park_Tree", x = 28, z = W.ParkCenterZ + 14 },
		{ asset = "CatCafe_Park_Tree", x = -30, z = W.ParkCenterZ - 8 },
		{ asset = "CatCafe_Park_Tree", x = 30, z = W.ParkCenterZ - 10 },
		{ asset = "CatCafe_Park_Tree", x = -14, z = W.ParkCenterZ - 20 },
		{ asset = "CatCafe_Park_Bench", x = -8, z = W.ParkCenterZ + 10, rotY = 180 },
		{ asset = "CatCafe_Park_Bench", x = 8, z = W.ParkCenterZ + 10, rotY = 180 },
		{ asset = "CatCafe_Park_Bench", x = 20, z = W.ParkCenterZ - 16, rotY = 90 },
	} :: { Prop },
} :: AreaSpec

-- Points at (dx, dz) from an area's center, on its floor.
local function around(cx: number, cz: number, offsets: { { number } }): { Point }
	local points: { Point } = {}
	for _, offset in offsets do
		table.insert(points, { x = cx + offset[1], y = 0.1, z = cz + offset[2] })
	end
	return points
end

-- Areas 3 to 5 are grayboxes (features section 3): flat ground, walls, a gate, spawn points and rescue spots.
-- The rescue props and the scenery reuse alley and park models until each area gets its own set; the rescue
-- spots become the area's traps in F27. The Neighbourhood opens on its -Z side into the Alley Square; the Woods
-- and the Sewer open on their +Z side onto the south ends of the back alleys.
local NX, NZ = W.NeighbourhoodCenterX, W.NeighbourhoodCenterZ
local NHD = W.NeighbourhoodDepth / 2
Layout.neighbourhood = {
	floorY = 0.1,
	center = { x = NX, y = 0, z = NZ },
	halfWidth = W.NeighbourhoodWidth / 2,
	halfDepth = NHD,
	gateZ = W.NeighbourhoodGateZ,
	spawnPoints = around(NX, NZ, {
		{ -8, -18 },
		{ 10, -16 },
		{ -26, -16 },
		{ 28, -18 },
		{ -14, -6 },
		{ 2, -2 },
		{ 20, -6 },
		{ -34, 2 },
		{ 34, 4 },
		{ -8, 10 },
		{ 12, 10 },
		{ -24, 18 },
		{ 4, 21 },
		{ 26, 19 },
	}),
	lureSpots = {},
	rescueSpots = {
		-- Stand-ins: the box for the shed, the drainpipe for the gutter.
		{ prop = "CatCafe_Alley_StuckBox", trap = "shed", x = NX - 41, z = NZ + 8, rotY = -90 },
		{ prop = "CatCafe_Alley_Drainpipe", trap = "gutter", x = NX + 12, z = NZ + NHD - 0.5 },
	},
	props = {
		{ asset = "CatCafe_Alley_StreetLamp", x = NX - 16, z = NZ - NHD + 3 },
		{ asset = "CatCafe_Alley_StreetLamp", x = NX + 16, z = NZ - NHD + 3 },
		{ asset = "CatCafe_Alley_TrashCan", x = NX - 40, z = NZ - 6 },
		{ asset = "CatCafe_Alley_Crate", x = NX + 40, z = NZ - 6 },
		{ asset = "CatCafe_Park_Tree", x = NX + 36, z = NZ + 16 },
		{ asset = "CatCafe_Park_Tree", x = NX - 32, z = NZ + 20 },
		{ asset = "CatCafe_Park_Bench", x = NX - 8, z = NZ + 22, rotY = 180 },
	},
} :: AreaSpec

local WX, WZ = W.WoodsCenterX, W.WoodsCenterZ
local WHW, WHD = W.WoodsWidth / 2, W.WoodsDepth / 2
Layout.woods = {
	floorY = 0.1,
	center = { x = WX, y = 0, z = WZ },
	halfWidth = WHW,
	halfDepth = WHD,
	gateZ = W.WoodsGateZ,
	openingHalfWidth = (AO - AI) / 2, -- the whole back alley's width opens into it
	spawnPoints = around(WX, WZ, {
		{ -5, 24 },
		{ 8, 22 },
		{ -18, 22 },
		{ 22, 24 },
		{ -26, 10 },
		{ -10, 12 },
		{ 4, 7 },
		{ 16, 10 },
		{ 27, 0 },
		{ -21, -5 },
		{ -5, -7 },
		{ 10, -7 },
		{ 23, -12 },
		{ -13, -19 },
		{ 2, -22 },
		{ 16, -26 },
	}),
	lureSpots = {},
	rescueSpots = {
		-- Stand-ins for the hollow log and the bramble bush; branches reach toward the middle.
		{ prop = "CatCafe_Alley_StuckTree", trap = "hollow_log", x = WX + WHW - 4, z = WZ - 26 },
		{
			prop = "CatCafe_Alley_StuckTree",
			trap = "bramble_bush",
			x = WX - WHW + 4,
			z = WZ + 18,
			rotY = 180,
		},
	},
	props = {
		{ asset = "CatCafe_Park_Tree", x = WX + 27, z = WZ + 14 },
		{ asset = "CatCafe_Park_Tree", x = WX - 27, z = WZ - 16 },
		{ asset = "CatCafe_Park_Tree", x = WX - 3, z = WZ - 29 },
		{ asset = "CatCafe_Park_Tree", x = WX - 18, z = WZ + 5 },
		{ asset = "CatCafe_Park_Tree", x = WX + 11, z = WZ - 16 },
		{ asset = "CatCafe_Park_Tree", x = WX - 21, z = WZ - 28 },
	},
} :: AreaSpec

local SX, SZ = W.SewerCenterX, W.SewerCenterZ
local SHW, SHD = W.SewerWidth / 2, W.SewerDepth / 2
Layout.sewer = {
	floorY = 0.1,
	center = { x = SX, y = 0, z = SZ },
	halfWidth = SHW,
	halfDepth = SHD,
	gateZ = W.SewerGateZ,
	openingHalfWidth = (AO - AI) / 2, -- the whole back alley's width opens into it
	spawnPoints = around(SX, SZ, {
		{ -5, 18 },
		{ 6, 18 },
		{ -16, 18 },
		{ 18, 16 },
		{ -10, 8 },
		{ 2, 5 },
		{ 13, 3 },
		{ -20, 3 },
		{ 21, -7 },
		{ -5, -5 },
		{ 6, -7 },
		{ -15, -10 },
		{ 15, -15 },
		{ -20, -20 },
		{ -3, -19 },
		{ 6, -23 },
	}),
	lureSpots = {},
	rescueSpots = {
		-- Stand-ins for the drain pipe and the grate, both on the far wall, outlets toward the opening.
		{
			prop = "CatCafe_Alley_Drainpipe",
			trap = "drain_pipe",
			x = SX - 12,
			z = SZ - SHD + 0.5,
			rotY = 180,
		},
		{
			prop = "CatCafe_Alley_Drainpipe",
			trap = "grate",
			x = SX + 14,
			z = SZ - SHD + 0.5,
			rotY = 180,
		},
	},
	props = {
		{ asset = "CatCafe_Alley_StreetLamp", x = SX - 16, z = SZ + SHD - 3 },
		{ asset = "CatCafe_Alley_StreetLamp", x = SX + 16, z = SZ + SHD - 3 },
		{ asset = "CatCafe_Alley_Crate", x = SX - 27, z = SZ + 10 },
		{ asset = "CatCafe_Alley_Crate", x = SX + 27, z = SZ + 5 },
		{ asset = "CatCafe_Alley_TrashCan", x = SX - 27, z = SZ - 12 },
	},
} :: AreaSpec

-- The night dealer's cart (data-model section 8b) parks mid-street between the middle rows of cafes, along the
-- street with its display side (-Z of the model) toward the west row. The dealer stands at the cart's +X end.
Layout.dealerCart = { x = 0, y = 0.1, z = 0, rotY = 90 } :: Point
Layout.dealerNpc = { x = 5.4, y = 0, z = -0.4 } :: Point -- relative to the cart

-- The manhole in the middle of the Alley Square (world-and-feel.md section 2: "the Sewer down a manhole in the
-- middle of the Square"): a shortcut into the Sewer once it opens, alongside its gate at the east back alley's
-- south end. Its sign (-Z) faces the street arch.
Layout.manhole = { area = "sewer", x = 0, y = 0.1, z = (SQ1 + SQ2) / 2 + 4 }

-- Every area by id, in the order Catalog.areas lists them.
Layout.areas = {
	alley = Layout.alley,
	park = Layout.park,
	neighbourhood = Layout.neighbourhood,
	woods = Layout.woods,
	sewer = Layout.sewer,
} :: { [string]: AreaSpec }

-- Player spawn on the street, near the arch into the Alley Square.
Layout.playerSpawn = { x = 0, y = 0.6, z = 70 } :: Point

return Layout
