--!strict
-- Pure geometry for the world: where plots sit on the street and where everything inside a plot goes.
-- Plot-local space: X runs along the street, Z is depth, -Z faces the street, y = 0 is the floor top.
-- No Roblox globals, so tests can check the numbers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type Point = { x: number, y: number, z: number, rotY: number? }
-- A rescue spot: the prop stands at (x, floor, z) turned by rotY; `cat` is where the stuck cat sits, in prop space.
export type RescuePoint = { prop: string, x: number, z: number, rotY: number?, cat: Point }

local Layout = {}

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

	-- Where a placed cat sits (on top of the furniture)
	spots = {
		counter_1 = { x = -2, y = 3.1, z = halfD - 3 },
		window_1 = { x = -13, y = 1.4, z = -halfD + 3 },
		cushion_1 = { x = 12, y = 0.5, z = 4 },
		shelf_1 = { x = halfW - 1.7, y = 5.3, z = 6 },
		cattree_1 = { x = -14, y = 4.65, z = 8 },
		patio_1 = { x = -8, y = 1.5, z = -halfD - 3.5 },
		patio_2 = { x = 8, y = 1.5, z = -halfD - 3.5 },
	} :: { [string]: Point },

	-- Furniture under each spot (counter_1 uses the counter itself)
	spotFurniture = {
		window_1 = { x = -13, y = 0, z = -halfD + 3 },
		cushion_1 = { x = 12, y = 0, z = 4 },
		shelf_1 = { x = halfW - 1.7, y = 5, z = 6, rotY = 90 },
		cattree_1 = { x = -14, y = 0, z = 8 },
		patio_1 = { x = -8, y = 0, z = -halfD - 3.5, rotY = 180 },
		patio_2 = { x = 8, y = 0, z = -halfD - 3.5, rotY = 180 },
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
	} :: { Point },
	lureSpots = {
		{ x = 0, y = 0.1, z = W.AlleyCenterZ + 3 },
		{ x = 14, y = 0.1, z = W.AlleyCenterZ + 13 },
	} :: { Point },
	rescueSpots = {
		{
			prop = "CatCafe_Alley_Drainpipe",
			x = -4,
			z = W.AlleyCenterZ + 19,
			cat = { x = 3.6, y = 0, z = 0, rotY = -90 },
		},
		{
			prop = "CatCafe_Alley_StuckBox",
			x = -26,
			z = W.AlleyCenterZ - 17,
			cat = { x = 0, y = 5, z = 0 },
		},
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
	} :: { { asset: string, x: number, z: number, rotY: number? } },
}

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
	} :: { Point },
	lureSpots = {
		{ x = -12, y = 0.1, z = W.ParkCenterZ + 6 },
		{ x = 12, y = 0.1, z = W.ParkCenterZ - 12 },
		{ x = 28, y = 0.1, z = W.ParkCenterZ + 22 },
	} :: { Point },
	rescueSpots = {
		{
			prop = "CatCafe_Alley_StuckTree",
			x = 36,
			z = W.ParkCenterZ + 26,
			rotY = 180,
			cat = { x = 1.8, y = 5.2, z = 0, rotY = 90 },
		},
		{
			prop = "CatCafe_Alley_StuckTree",
			x = -36,
			z = W.ParkCenterZ - 25,
			cat = { x = 1.8, y = 5.2, z = 0, rotY = 90 },
		},
		{
			prop = "CatCafe_Alley_StuckBox",
			x = 24,
			z = W.ParkCenterZ - 25,
			cat = { x = 0, y = 5, z = 0 },
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
	} :: { { asset: string, x: number, z: number, rotY: number? } },
}

-- Player spawn on the street, between the cafes and the alley.
Layout.playerSpawn = { x = 0, y = 0.6, z = 70 } :: Point

return Layout
