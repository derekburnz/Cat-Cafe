--!strict
-- Pure geometry for the world: where plots sit on the street and where everything inside a plot goes.
-- Plot-local space: X runs along the street, Z is depth, -Z faces the street, y = 0 is the floor top.
-- No Roblox globals, so tests can check the numbers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type Point = { x: number, y: number, z: number, rotY: number? }
-- A rescue spot: the prop stands at (x, floor, z) turned by rotY; the stuck cat sits at Layout.stuckPoses[prop].
export type RescuePoint = { prop: string, x: number, z: number, rotY: number? }
-- y is the height above the area floor (0 when omitted); wall props set it.
export type Prop = { asset: string, x: number, y: number?, z: number, rotY: number? }
-- A shared area in world space. Its near wall, the one facing the street's end, has a street-wide opening.
export type AreaSpec = {
	floorY: number,
	center: Point,
	halfWidth: number,
	halfDepth: number,
	gateZ: number?, -- where the tier gate stands across the opening; nil for the Tier 1 alley
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
	-- Clings to the low branch, rolled 20 degrees toward the trunk.
	CatCafe_Alley_StuckTree = { -1.4, 4.4, 0, 0.9397, -0.342, 0, 0.342, 0.9397, 0, 0, 0, 1 },
	-- Head inside the box, tail end out of the opening (turned 180 degrees).
	CatCafe_Alley_StuckBox = { 0, 0, -0.6, -1, 0, 0, 0, 1, 0, 0, 0, -1 },
	-- Body inside the outlet, head poking out.
	CatCafe_Alley_Drainpipe = { 0, 0, -2, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
} :: { [string]: { number } }

local W = Config.World

-- World position of plot `index` (1-based) and which side of the street it is on (-1 left, +1 right).
function Layout.plotPlacement(index: number): { x: number, z: number, side: number }
	local i = index - 1
	local side = if i % 2 == 0 then -1 else 1
	local row = math.floor(i / 2)
	local rows = math.ceil(W.PlotCount / 2)
	local z = (row - (rows - 1) / 2) * (W.PlotWidth + W.PlotRowGap)
	local x = side * (W.StreetHalfWidth + 2 + W.PlotDepth / 2)
	return { x = x, z = z, side = side }
end

local halfW = W.PlotWidth / 2 -- 18
local halfD = W.PlotDepth / 2 -- 14

Layout.plot = {
	door = { x = 0, y = 0, z = -halfD } :: Point,
	entry = { x = 0, y = 0, z = -halfD - 5 } :: Point, -- customer start, out on the street
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

	-- The back door, between the counter and the left cat tree, leads out to the expansions.
	backDoor = { x = -8, width = 6 },

	-- Cafe expansions behind the back wall (data-model section 5b): expansion n opens at Tier n + 1. Each is a
	-- floor rectangle from (x1, z1) to (x2, z2); the third is the patio. Plot-local, so deeper is farther from
	-- the street.
	expansions = {
		{ x1 = -halfW, z1 = halfD + 1, x2 = 0, z2 = halfD + 11 },
		{ x1 = 0, z1 = halfD + 1, x2 = halfW, z2 = halfD + 11 },
		{ x1 = -halfW, z1 = halfD + 11, x2 = halfW, z2 = halfD + 19 },
		{ x1 = -halfW, z1 = halfD + 19, x2 = halfW, z2 = halfD + 27 },
	} :: { { x1: number, z1: number, x2: number, z2: number } },

	-- Two seats per table, relative to the table anchor; rotY faces the chair toward the table
	seatOffsets = {
		{ x = -2.4, y = 0, z = 0, rotY = -90 },
		{ x = 2.4, y = 0, z = 0, rotY = 90 },
	} :: { Point },
}

-- Shared areas, in world space. y is the floor top.
Layout.alley = {
	floorY = 0.1,
	center = { x = 0, y = 0, z = W.AlleyCenterZ },
	halfWidth = W.AlleyWidth / 2,
	halfDepth = W.AlleyDepth / 2,
	spawnPoints = {
		{ x = -6, y = 0.1, z = W.AlleyCenterZ - 13 }, -- alley_1: nearest the entrance, used for the tutorial stray
		{ x = 20, y = 0.1, z = W.AlleyCenterZ - 15 },
		{ x = -22, y = 0.1, z = W.AlleyCenterZ - 8 },
		{ x = 24, y = 0.1, z = W.AlleyCenterZ },
		{ x = -24, y = 0.1, z = W.AlleyCenterZ + 4 },
		{ x = 8, y = 0.1, z = W.AlleyCenterZ + 8 },
		{ x = -14, y = 0.1, z = W.AlleyCenterZ + 15 },
		{ x = 18, y = 0.1, z = W.AlleyCenterZ + 16 },
		{ x = 6, y = 0.1, z = W.AlleyCenterZ - 8 },
		{ x = -10, y = 0.1, z = W.AlleyCenterZ },
		{ x = 12, y = 0.1, z = W.AlleyCenterZ - 2 },
		{ x = -4, y = 0.1, z = W.AlleyCenterZ + 12 },
		{ x = 4, y = 0.1, z = W.AlleyCenterZ + 18 },
		{ x = -16, y = 0.1, z = W.AlleyCenterZ - 12 },
	} :: { Point },
	lureSpots = {
		{ x = 0, y = 0.1, z = W.AlleyCenterZ + 3 },
		{ x = 14, y = 0.1, z = W.AlleyCenterZ + 13 },
	} :: { Point },
	rescueSpots = {
		-- On the far wall's inner face, outlet toward the alley.
		{ prop = "CatCafe_Alley_Drainpipe", x = -4, z = W.AlleyCenterZ + 21.5 },
		-- Opening turned toward the middle of the alley.
		{ prop = "CatCafe_Alley_StuckBox", x = -26, z = W.AlleyCenterZ - 17, rotY = -90 },
	} :: { RescuePoint },
	props = {
		{ asset = "CatCafe_Alley_Dumpster", x = -25, z = W.AlleyCenterZ - 6, rotY = 90 },
		{ asset = "CatCafe_Alley_Dumpster", x = 26, z = W.AlleyCenterZ + 8, rotY = -90 },
		{ asset = "CatCafe_Alley_TrashCan", x = -20, z = W.AlleyCenterZ + 18 },
		{ asset = "CatCafe_Alley_TrashCan", x = 23, z = W.AlleyCenterZ - 17 },
		{ asset = "CatCafe_Alley_StreetLamp", x = -14, z = W.AlleyCenterZ - 20 },
		{ asset = "CatCafe_Alley_StreetLamp", x = 14, z = W.AlleyCenterZ - 20 },
		{ asset = "CatCafe_Alley_Crate", x = -24, z = W.AlleyCenterZ + 12 },
		{ asset = "CatCafe_Alley_Crate", x = 26, z = W.AlleyCenterZ - 10 },
		-- Night glow (style guide section 9): a lit shop window on each side wall and string lights along the
		-- far wall. Wall props sit on the wall's inner face with their front (-Z) turned into the alley.
		{
			asset = "CatCafe_Alley_ShopWindow",
			x = -29.5,
			y = 1.5,
			z = W.AlleyCenterZ + 2,
			rotY = -90,
		},
		{
			asset = "CatCafe_Alley_ShopWindow",
			x = 29.5,
			y = 1.5,
			z = W.AlleyCenterZ - 2,
			rotY = 90,
		},
		{ asset = "CatCafe_Decor_StringLights", x = -20, y = 5.6, z = W.AlleyCenterZ + 21.3 },
		{ asset = "CatCafe_Decor_StringLights", x = 6, y = 5.6, z = W.AlleyCenterZ + 21.3 },
	} :: { Prop },
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
		{ prop = "CatCafe_Alley_StuckTree", x = 36, z = W.ParkCenterZ + 26 },
		{ prop = "CatCafe_Alley_StuckTree", x = -36, z = W.ParkCenterZ - 25, rotY = 180 },
		{ prop = "CatCafe_Alley_StuckBox", x = 24, z = W.ParkCenterZ - 25, rotY = 90 },
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
-- spots become the area's traps in F27. In the alley row the opening is on the -Z side, in the park row on +Z.
local NX, NZ = W.NeighbourhoodCenterX, W.NeighbourhoodCenterZ
Layout.neighbourhood = {
	floorY = 0.1,
	center = { x = NX, y = 0, z = NZ },
	halfWidth = W.NeighbourhoodWidth / 2,
	halfDepth = W.NeighbourhoodDepth / 2,
	gateZ = W.NeighbourhoodGateZ,
	spawnPoints = around(NX, NZ, {
		{ -6, -14 },
		{ 8, -12 },
		{ -20, -12 },
		{ 22, -14 },
		{ -12, -4 },
		{ 2, -2 },
		{ 16, -4 },
		{ -24, 2 },
		{ 24, 4 },
		{ -6, 8 },
		{ 10, 8 },
		{ -18, 14 },
		{ 4, 17 },
		{ 20, 15 },
	}),
	lureSpots = {},
	rescueSpots = {
		-- Stand-ins: the box for the shed, the drainpipe for the gutter.
		{ prop = "CatCafe_Alley_StuckBox", x = NX - 26, z = NZ + 8, rotY = -90 },
		{ prop = "CatCafe_Alley_Drainpipe", x = NX + 12, z = NZ + 21.5 },
	},
	props = {
		{ asset = "CatCafe_Alley_StreetLamp", x = NX - 14, z = NZ - 19 },
		{ asset = "CatCafe_Alley_StreetLamp", x = NX + 14, z = NZ - 19 },
		{ asset = "CatCafe_Alley_TrashCan", x = NX - 26, z = NZ - 6 },
		{ asset = "CatCafe_Alley_Crate", x = NX + 26, z = NZ - 6 },
		{ asset = "CatCafe_Park_Tree", x = NX + 26, z = NZ + 12 },
		{ asset = "CatCafe_Park_Bench", x = NX - 8, z = NZ + 18, rotY = 180 },
	},
} :: AreaSpec

local WX, WZ = W.WoodsCenterX, W.WoodsCenterZ
Layout.woods = {
	floorY = 0.1,
	center = { x = WX, y = 0, z = WZ },
	halfWidth = W.WoodsWidth / 2,
	halfDepth = W.WoodsDepth / 2,
	gateZ = W.WoodsGateZ,
	spawnPoints = around(WX, WZ, {
		{ -6, 20 },
		{ 10, 18 },
		{ -22, 18 },
		{ 26, 20 },
		{ -32, 8 },
		{ -12, 10 },
		{ 4, 6 },
		{ 20, 8 },
		{ 34, 0 },
		{ -26, -4 },
		{ -6, -6 },
		{ 12, -6 },
		{ 28, -10 },
		{ -16, -16 },
		{ 2, -18 },
		{ 20, -22 },
	}),
	lureSpots = {},
	rescueSpots = {
		-- Stand-ins for the hollow log and the bramble bush; branches reach toward the middle.
		{ prop = "CatCafe_Alley_StuckTree", x = WX + 36, z = WZ - 24 },
		{ prop = "CatCafe_Alley_StuckTree", x = WX - 36, z = WZ + 22, rotY = 180 },
	},
	props = {
		{ asset = "CatCafe_Park_Tree", x = WX + 34, z = WZ + 12 },
		{ asset = "CatCafe_Park_Tree", x = WX - 34, z = WZ - 14 },
		{ asset = "CatCafe_Park_Tree", x = WX - 4, z = WZ - 26 },
		{ asset = "CatCafe_Park_Tree", x = WX - 22, z = WZ + 4 },
		{ asset = "CatCafe_Park_Tree", x = WX + 14, z = WZ - 14 },
		{ asset = "CatCafe_Park_Tree", x = WX - 26, z = WZ - 24 },
	},
} :: AreaSpec

local SX, SZ = W.SewerCenterX, W.SewerCenterZ
Layout.sewer = {
	floorY = 0.1,
	center = { x = SX, y = 0, z = SZ },
	halfWidth = W.SewerWidth / 2,
	halfDepth = W.SewerDepth / 2,
	gateZ = W.SewerGateZ,
	spawnPoints = around(SX, SZ, {
		{ -6, -14 },
		{ 8, -14 },
		{ -20, -14 },
		{ 22, -12 },
		{ -12, -6 },
		{ 2, -4 },
		{ 16, -2 },
		{ -24, -2 },
		{ 26, 6 },
		{ -6, 4 },
		{ 8, 6 },
		{ -18, 8 },
		{ 18, 12 },
		{ -24, 16 },
		{ -4, 15 },
		{ 8, 18 },
	}),
	lureSpots = {},
	rescueSpots = {
		-- Stand-ins for the drain pipe and the grate, both on the far wall.
		{ prop = "CatCafe_Alley_Drainpipe", x = SX - 12, z = SZ + 21.5 },
		{ prop = "CatCafe_Alley_Drainpipe", x = SX + 14, z = SZ + 21.5 },
	},
	props = {
		{ asset = "CatCafe_Alley_StreetLamp", x = SX - 14, z = SZ - 19 },
		{ asset = "CatCafe_Alley_StreetLamp", x = SX + 14, z = SZ - 19 },
		{ asset = "CatCafe_Alley_Crate", x = SX - 26, z = SZ - 8 },
		{ asset = "CatCafe_Alley_Crate", x = SX + 26, z = SZ - 4 },
		{ asset = "CatCafe_Alley_TrashCan", x = SX - 26, z = SZ + 10 },
	},
} :: AreaSpec

-- Every area by id, in the order Catalog.areas lists them.
Layout.areas = {
	alley = Layout.alley,
	park = Layout.park,
	neighbourhood = Layout.neighbourhood,
	woods = Layout.woods,
	sewer = Layout.sewer,
} :: { [string]: AreaSpec }

-- Player spawn on the street, between the cafes and the alley.
Layout.playerSpawn = { x = 0, y = 0.6, z = 70 } :: Point

return Layout
