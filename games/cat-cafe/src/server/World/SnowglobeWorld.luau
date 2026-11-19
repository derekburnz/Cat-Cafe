--!strict
-- Snowglobe Village, the world (snowglobe-village-spec sections 1 and 3). Model-Agent's set and pieces (#5326), placed
-- from the set's manifest points (assets/cat-cafe/exports/manifest.json, CatCafe_Snowglobe_Set points_roblox), far from
-- every other area. The set is round: the curved sky glass stands at radius 60 and a 30 high barrier ring at 57.8 is
-- its only wall, so the only way in is a trip through the giant snow globe in the Town Square.
--   buildPortal(parent)  the globe in the Town Square (CatCafe_Snowglobe_Portal), tagged SnowglobePortal, with an
--                        invisible SnowglobePortalTouch part across its way in. Effects/SnowglobeFx swirls and spins it.
--   buildArea(parent)    the set on an invisible Floor slab (the set's ground is paint only, like Harvest's), the Gift
--                        Stall (SnowglobeStall, with the ProximityPrompt SnowglobeStallPrompt), the StoneFireplace and
--                        FiresideRug in the lodge, the 12 patch snowflakes (SnowglobeFlake, each with an invisible
--                        Touch part), the arrival pad (SnowglobeArrival) and the village's middle (SnowglobeCentre, the
--                        part Effects/SnowglobeFx's snowfall centres on).
--   buildAdventBoard(parent, portal)  #5502: the advent calendar board (CatCafe_Square_AdventBoard, #5511) beside the
--                        globe, facing the cannon like it, on the first side whose spot is clear, tagged AdventBoard.
--                        Its doors stay anchored and unwelded: the client's Effects/AdventFx swings them.
--   landing()            where a trip in lands: the player spawn, facing the tree.
--   areaInfo(folder)     the area as CatService knows the others (WorldBuilder.AreaInfo, id "snowglobe"): the 14 stray
--                        spots and the nook (zone "rare") as invisible parts in `folder`, and five roam boxes inside
--                        the barrier ring.
-- Nothing here reads dates or saves: the event row (GE's EventArea) opens the portal and handles trips, the patch and
-- the stall. SnowglobeService builds this world once the christmasEvent switch is on.

local CollectionService = game:GetService("CollectionService")

local AssetRegistry = require(script.Parent.AssetRegistry)
local HarvestWorld = require(script.Parent.HarvestWorld)

local SnowglobeWorld = {}

SnowglobeWorld.ID = "snowglobe"
SnowglobeWorld.SET = "CatCafe_Snowglobe_Set"
SnowglobeWorld.PORTAL = "CatCafe_Snowglobe_Portal"
SnowglobeWorld.STALL = "CatCafe_Snowglobe_Stall"
SnowglobeWorld.FLAKE = "CatCafe_Snowglobe_Snowflake"
SnowglobeWorld.FIREPLACE = "CatCafe_Decor_StoneFireplace"
SnowglobeWorld.RUG = "CatCafe_Decor_FiresideRug"
SnowglobeWorld.ADVENT_BOARD = "CatCafe_Square_AdventBoard" -- #5502: 7.4 wide, 14.2 tall, pivot at the base centre
SnowglobeWorld.ADVENT_TAG = "AdventBoard" -- Controllers/AdventBoardController finds it
-- Board pivots in globe space (front -Z, toward the cannon): the globe is 26.2 wide, so 13.1 + 2 clear + 3.7 out to
-- either side, a little ahead of the globe's middle. The first spot with nothing standing in it wins.
SnowglobeWorld.ADVENT_SPOTS =
	{ Vector3.new(18.8, 0, -2), Vector3.new(-18.8, 0, -2), Vector3.new(0, 0, 16) }
SnowglobeWorld.ADVENT_BOX = Vector3.new(8.4, 14, 3)

SnowglobeWorld.PORTAL_TAG = "SnowglobePortal" -- Effects/SnowglobeFx (Presets.snowglobeFx.portalTag)
SnowglobeWorld.PORTAL_TOUCH_TAG = "SnowglobePortalTouch"
SnowglobeWorld.CENTRE_TAG = "SnowglobeCentre" -- Effects/SnowglobeFx (Presets.snowglobeFx.centreTag)
SnowglobeWorld.STALL_TAG = "SnowglobeStall"
SnowglobeWorld.FLAKE_TAG = "SnowglobeFlake"
SnowglobeWorld.ARRIVAL_TAG = "SnowglobeArrival"

-- The set's centre on its floor: north-west, the Castle's mirror (Castle at (2400, 2400), Harvest at (-2400, -2400)),
-- clear of every area.
SnowglobeWorld.CENTER = Vector3.new(-2400, 0, 2400)
-- The set is 128 x 128 (Model-Agent), ground paint only, so the area gets its own Floor slab, its top at CENTER.Y.
SnowglobeWorld.FLOOR_SIZE = Vector3.new(128, 4, 128)
SnowglobeWorld.BARRIER_RADIUS = 57.8 -- the barrier ring's middle (CatCafe_Snowglobe_Set_002_Edge_Barrier, 1.6 thick)
-- The globe stands on Harvest Hollow's arch spot (HarvestWorld.ARCH_AT; Harvest is vaulted, so the arch is never
-- built), facing the cannon, and follows it when the Town Square layout moves it (#5224 v5 put it at (-24, 35), clear
-- of the Day Cart). The globe is 26.2 wide, its way in 5.2 in front of its pivot and its back 12.8 behind.
SnowglobeWorld.PORTAL_AT = HarvestWorld.ARCH_AT
SnowglobeWorld.PORTAL_WAY_IN = Vector3.new(0, 4.45, -5.2) -- CatCafe_Snowglobe_Portal_Portal_Glow, globe space

-- CatCafe_Snowglobe_Set points_roblox (set space, front -Z): x, y, z, and for the stall, fireplace and rug a fourth
-- value, the turn in degrees as Model-Agent's Blender script writes it (a Blender yaw: 90 faces +X). Roblox's yaw runs
-- the other way, so `turned` uses minus the turn; the stall then faces the lamp lane (+X) from its west side.
local POINTS = {
	playerSpawn = Vector3.new(0, 0, -50),
	stall = { at = Vector3.new(-15, 0, -22), turn = 90 },
	fireplace = { at = Vector3.new(39, 0.15, 31.6), turn = 0 },
	rug = { at = Vector3.new(39, 0.15, 27.6), turn = 0 },
	nook = Vector3.new(26.9, 0, 38.76),
	spawns = {
		Vector3.new(14, 0, -30),
		Vector3.new(-16, 0, -30),
		Vector3.new(30, 0, -6),
		Vector3.new(-31.5, 0, -36),
		Vector3.new(44, 0, 2),
		Vector3.new(18, 0, 28),
		Vector3.new(-20, 0, 8),
		Vector3.new(38, 0, -36),
		Vector3.new(-12, 0, 36),
		Vector3.new(2, 0, 42),
		Vector3.new(-24, 0, -4),
		Vector3.new(-36, 0, 38),
		Vector3.new(36, 0, 24),
		Vector3.new(28.05, 0, -42.57),
	},
	flakes = {
		Vector3.new(-27, 0.12, 18),
		Vector3.new(-33, 0.12, 18),
		Vector3.new(-39, 0.12, 18),
		Vector3.new(-45, 0.12, 18),
		Vector3.new(-27, 0.12, 24),
		Vector3.new(-33, 0.12, 24),
		Vector3.new(-39, 0.12, 24),
		Vector3.new(-48.66, 0, 16.33),
		Vector3.new(-27, 0.12, 30),
		Vector3.new(-33, 0.12, 30),
		Vector3.new(-39, 0.12, 30),
		Vector3.new(-42.67, 0, 31.88),
	},
}

local function world(point: Vector3): Vector3
	return SnowglobeWorld.CENTER + point
end

-- A Roblox yaw's front: CFrame.Angles(0, yaw, 0).LookVector, pure for the specs (their shim has no CFrame).
function SnowglobeWorld.front(yaw: number): Vector3
	return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
end

local function yawOf(turn: number): number
	return math.rad(-turn)
end

local function turned(spot: { at: Vector3, turn: number }): CFrame
	return CFrame.new(world(spot.at)) * CFrame.Angles(0, yawOf(spot.turn), 0)
end

SnowglobeWorld.spawns = table.freeze((function()
	local out = {}
	for _, point in POINTS.spawns do
		table.insert(out, world(point))
	end
	return out
end)() :: { Vector3 })
SnowglobeWorld.flakes = table.freeze((function()
	local out = {}
	for _, point in POINTS.flakes do
		table.insert(out, world(point))
	end
	return out
end)() :: { Vector3 })
SnowglobeWorld.nook = world(POINTS.nook)
SnowglobeWorld.flakeCount = #POINTS.flakes
SnowglobeWorld.stallYaw = yawOf(POINTS.stall.turn)

-- Where a trip in lands: just over the player spawn, facing the tree and the lodge (+Z, into the village).
function SnowglobeWorld.landingPoint(): Vector3
	return world(POINTS.playerSpawn) + Vector3.new(0, 3, 0)
end

function SnowglobeWorld.landing(): CFrame
	return CFrame.new(SnowglobeWorld.landingPoint()) * CFrame.Angles(0, math.pi, 0) -- LookVector (0, 0, 1)
end

-- Whether a point is inside the barrier ring (a stud of slack), at the floor's height band.
function SnowglobeWorld.inArea(position: Vector3): boolean
	local offset = position - SnowglobeWorld.CENTER
	return math.sqrt(offset.X * offset.X + offset.Z * offset.Z) <= SnowglobeWorld.BARRIER_RADIUS + 1
		and offset.Y > -10
		and offset.Y < 70
end

-- The roam boxes: a cross of two 100 x 40 bands and four corner squares 20 to 37 out, every corner of them 54 or less
-- from the middle, so a stray keeps 3 or more studs inside the barrier's inner face.
local BAND, ARM, CORNER = 20, 50, 37
SnowglobeWorld.roamBoxes = table.freeze({
	{ x1 = -ARM, z1 = -BAND, x2 = ARM, z2 = BAND },
	{ x1 = -BAND, z1 = -ARM, x2 = BAND, z2 = ARM },
	{ x1 = BAND, z1 = BAND, x2 = CORNER, z2 = CORNER },
	{ x1 = -CORNER, z1 = BAND, x2 = -BAND, z2 = CORNER },
	{ x1 = BAND, z1 = -CORNER, x2 = CORNER, z2 = -BAND },
	{ x1 = -CORNER, z1 = -CORNER, x2 = -BAND, z2 = -BAND },
} :: { { x1: number, z1: number, x2: number, z2: number } })

-- The area for CatService: a WorldBuilder.AreaInfo (not required here, so the specs can read this module) with its
-- spawn points as parts under `folder`. Unused until the event row adds it.
function SnowglobeWorld.areaInfo(folder: Instance, model: Model): any
	local points: { BasePart } = {}
	local function spot(name: string, at: Vector3, zone: string?)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = Vector3.new(1, 1, 1)
		p.CFrame = CFrame.new(at + Vector3.new(0, 0.5, 0))
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		if zone ~= nil then
			p:SetAttribute("Zone", zone)
		end
		p.Parent = folder
		table.insert(points, p)
	end
	for index, at in SnowglobeWorld.spawns do
		spot(string.format("SnowglobeSpawn%02d", index), at)
	end
	spot("SnowglobeNook", SnowglobeWorld.nook, "rare")
	local c = SnowglobeWorld.CENTER
	local rects = {}
	for _, box in SnowglobeWorld.roamBoxes do
		table.insert(
			rects,
			{ x1 = c.X + box.x1, z1 = c.Z + box.z1, x2 = c.X + box.x2, z2 = c.Z + box.z2 }
		)
	end
	return {
		id = SnowglobeWorld.ID,
		model = model,
		floorY = c.Y,
		spawnPoints = points,
		rescueSpots = {},
		rescueMix = {},
		bounds = { minX = c.X - ARM, maxX = c.X + ARM, minZ = c.Z - ARM, maxZ = c.Z + ARM },
		rects = rects,
		roam = rects,
		arrival = SnowglobeWorld.landing(),
		camp = nil,
	}
end

local function invisible(name: string, size: Vector3, cframe: CFrame, parent: Instance): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = true
	part.Transparency = 1
	part.Parent = parent
	return part
end

-- A ProximityPrompt (the "press E" / tap button Roblox shows near an object) on the model's PrimaryPart or first part.
local function prompt(name: string, action: string, object: string, model: Model)
	local parent: Instance = model.PrimaryPart
		or model:FindFirstChildWhichIsA("BasePart", true)
		or model
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = object
	p.RequiresLineOfSight = false
	p.MaxActivationDistance = 10
	p.Parent = parent
end

local function place(asset: string, cframe: CFrame, parent: Instance): Model?
	if not AssetRegistry.known(asset) then
		warn(string.format("[SnowglobeWorld] %s is not in the assets", asset))
		return nil
	end
	local model = AssetRegistry.clone(asset)
	model:PivotTo(cframe)
	model.Parent = parent
	return model
end

-- The globe's turn in the Town Square: its front (-Z, LookVector (-sin r, 0, -cos r)) faces the cannon at the origin.
function SnowglobeWorld.portalYaw(): number
	local at = SnowglobeWorld.PORTAL_AT
	return math.atan2(at.X, at.Z)
end

-- The globe in the Town Square, with its touch part across the way in.
function SnowglobeWorld.buildPortal(parent: Instance): Model?
	local cframe = CFrame.new(SnowglobeWorld.PORTAL_AT)
		* CFrame.Angles(0, SnowglobeWorld.portalYaw(), 0)
	local portal = place(SnowglobeWorld.PORTAL, cframe, parent)
	if portal == nil then
		return nil
	end
	local touch = invisible(
		"SnowglobePortalTouch",
		Vector3.new(8, 9, 3),
		cframe * CFrame.new(SnowglobeWorld.PORTAL_WAY_IN + Vector3.new(0, 0, -0.5)),
		portal
	)
	CollectionService:AddTag(touch, SnowglobeWorld.PORTAL_TOUCH_TAG)
	CollectionService:AddTag(portal, SnowglobeWorld.PORTAL_TAG)
	return portal
end

-- #5502: whether nothing but ground stands in a board's box at `cframe` (the globe left out). Ground (a part whose
-- top is under 0.6 studs above the spot) and invisible touch parts do not count.
local function clear(cframe: CFrame, portal: Instance): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { portal }
	local box = SnowglobeWorld.ADVENT_BOX
	local parts = game:GetService("Workspace")
		:GetPartBoundsInBox(cframe * CFrame.new(0, box.Y / 2 + 0.6, 0), box, params)
	for _, part in parts do
		if
			part.Transparency < 1
			and part.Position.Y + part.Size.Y / 2 > cframe.Position.Y + 0.6
		then
			return false
		end
	end
	return true
end

-- The advent calendar board beside the globe, or nil while its model is not in the assets (#5511).
function SnowglobeWorld.buildAdventBoard(parent: Instance, portal: Model): Model?
	if not AssetRegistry.known(SnowglobeWorld.ADVENT_BOARD) then
		return nil
	end
	local base = portal:GetPivot()
	local chosen = base * CFrame.new(SnowglobeWorld.ADVENT_SPOTS[1])
	for _, spot in SnowglobeWorld.ADVENT_SPOTS do
		local cframe = base * CFrame.new(spot)
		if clear(cframe, portal) then
			chosen = cframe
			break
		end
	end
	local board = AssetRegistry.clone(SnowglobeWorld.ADVENT_BOARD)
	board:PivotTo(chosen)
	for _, part in board:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true -- the doors swing by PivotTo on each client, so nothing is welded or unanchored
		end
	end
	board.Parent = parent
	CollectionService:AddTag(board, SnowglobeWorld.ADVENT_TAG)
	return board
end

-- The area: the set, its stall, lodge pieces and snowflakes, the arrival pad, the centre mark and the stray spots.
-- Returns the folder it built into and the area for CatService.
function SnowglobeWorld.buildArea(parent: Instance): (Folder, any)
	local folder = Instance.new("Folder")
	folder.Name = "SnowglobeVillage"
	local set = place(SnowglobeWorld.SET, CFrame.new(SnowglobeWorld.CENTER), folder)
	local floor = invisible(
		"Floor",
		SnowglobeWorld.FLOOR_SIZE,
		CFrame.new(SnowglobeWorld.CENTER - Vector3.new(0, SnowglobeWorld.FLOOR_SIZE.Y / 2, 0)),
		folder
	)
	floor.CanCollide = true
	floor.CanQuery = true -- raycasts for footing and the loading screen's ground check find it
	floor.CanTouch = false
	local centre = invisible(
		"SnowglobeCentre",
		Vector3.new(1, 1, 1),
		CFrame.new(SnowglobeWorld.CENTER),
		folder
	)
	centre.CanTouch = false
	CollectionService:AddTag(centre, SnowglobeWorld.CENTRE_TAG)
	local stall = place(SnowglobeWorld.STALL, turned(POINTS.stall), folder)
	if stall ~= nil then
		prompt("SnowglobeStallPrompt", "Shop", "Gift Stall", stall)
		CollectionService:AddTag(stall, SnowglobeWorld.STALL_TAG)
	end
	place(SnowglobeWorld.FIREPLACE, turned(POINTS.fireplace), folder)
	place(SnowglobeWorld.RUG, turned(POINTS.rug), folder)
	for index, at in SnowglobeWorld.flakes do
		local flake = place(SnowglobeWorld.FLAKE, CFrame.new(at), folder)
		if flake ~= nil then
			flake.Name = string.format("SnowglobeFlake%02d", index)
			-- the flake's own parts take no touches, so a touch box over it does
			invisible("Touch", Vector3.new(4, 4, 4), CFrame.new(at + Vector3.new(0, 1.5, 0)), flake)
			CollectionService:AddTag(flake, SnowglobeWorld.FLAKE_TAG)
		end
	end
	local arrival = invisible(
		"SnowglobeArrival",
		Vector3.new(14, 6, 10),
		CFrame.new(world(POINTS.playerSpawn) + Vector3.new(0, 3, 0)),
		folder
	)
	CollectionService:AddTag(arrival, SnowglobeWorld.ARRIVAL_TAG)
	local spots = Instance.new("Folder")
	spots.Name = "StraySpots"
	spots.Parent = folder
	local info = SnowglobeWorld.areaInfo(spots, set or Instance.new("Model"))
	folder.Parent = parent
	return folder, info
end

return SnowglobeWorld
