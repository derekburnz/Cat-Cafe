--!strict
-- Builds the whole graybox world from code at server start: ground, street, 8 plots, five areas and their gates.
-- Everything with a name in features.md is a named Part or a clone from AssetRegistry so art swaps in by name.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AssetRegistry = require(script.Parent.AssetRegistry)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(script.Parent.Layout)
local Types = require(ReplicatedStorage.Shared.Types)

export type Plot = {
	index: number,
	model: Model,
	cframe: CFrame, -- plot-local origin: floor top centre, -Z faces the street
	door: BasePart,
	sign: TextLabel,
	spots: { [string]: BasePart },
	spotFurniture: { [string]: Model },
	decorAnchors: { [string]: BasePart },
	tableAnchors: { BasePart },
	cats: Folder,
	decor: Folder,
	tables: Folder,
	customerEntry: BasePart,
	espresso: BasePart,
	backDoor: BasePart, -- a wall panel until expansion 1 opens
	expansions: { Model }, -- Expansions/<n>, hidden until the owner's tier opens them
}

export type AreaInfo = {
	id: string,
	model: Model,
	floorY: number,
	spawnPoints: { BasePart },
	lureSpots: { [string]: BasePart },
	rescueSpots: { [string]: BasePart }, -- rescueSpotId -> anchor where a stuck cat sits
	bounds: { minX: number, maxX: number, minZ: number, maxZ: number },
}

export type World = {
	folder: Folder,
	plots: { Plot },
	areas: { [string]: AreaInfo },
	gates: { [string]: Model }, -- area id -> its tier gate (every area but the Tier 1 alley)
}

local WorldBuilder = {}

local W = Config.World
local CREAM = Color3.fromRGB(246, 236, 214)
local CARAMEL = Color3.fromRGB(190, 135, 80)
local MINT = Color3.fromRGB(165, 214, 190)
local ASPHALT = Color3.fromRGB(70, 70, 75)
local BRICK = Color3.fromRGB(150, 85, 70)
local GRASS = Color3.fromRGB(110, 170, 90)

-- Floor and wall look per area. Areas 3 to 5 get a distinct flat palette color until their sets exist.
type AreaLook = { floor: Color3, floorMaterial: Enum.Material, wall: Color3 }
local AREA_LOOKS: { [string]: AreaLook } = {
	alley = { floor = ASPHALT, floorMaterial = Enum.Material.Asphalt, wall = BRICK },
	park = { floor = GRASS, floorMaterial = Enum.Material.Grass, wall = Color3.fromRGB(90, 70, 50) },
	neighbourhood = {
		floor = Color3.fromRGB(196, 178, 150),
		floorMaterial = Enum.Material.Pavement,
		wall = Color3.fromRGB(205, 160, 120),
	},
	woods = {
		floor = Color3.fromRGB(86, 120, 70),
		floorMaterial = Enum.Material.LeafyGrass,
		wall = Color3.fromRGB(70, 55, 40),
	},
	sewer = {
		floor = Color3.fromRGB(95, 105, 100),
		floorMaterial = Enum.Material.Slate,
		wall = Color3.fromRGB(80, 90, 85),
	},
}

local function part(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	parent: Instance?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function anchor(name: string, cframe: CFrame, parent: Instance): Part
	local p = part(name, Vector3.new(1, 1, 1), cframe, Color3.new(1, 1, 1), nil, parent)
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- An invisible box under World.Zones naming the place the player stands in: "Cafe", or an area such as "Alley".
-- The client reads it for the ambience (Audio.setZone) and the first tutorial step; the server never does.
local function zone(name: string, size: Vector3, cframe: CFrame, parent: Instance)
	local box = part(name, size, cframe, Color3.new(1, 1, 1), nil, parent)
	box.Transparency = 1
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
end

local function localCFrame(base: CFrame, p: Layout.Point): CFrame
	return base * CFrame.new(p.x, p.y, p.z) * CFrame.Angles(0, math.rad(p.rotY or 0), 0)
end

-- A manifest pose: 12 CFrame numbers, the position and then the rotation matrix by rows.
local function poseCFrame(p: { number }): CFrame
	return CFrame.new(p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8], p[9], p[10], p[11], p[12])
end

local function place(asset: string, cframe: CFrame, parent: Instance): Model
	local model = AssetRegistry.clone(asset)
	model:PivotTo(cframe)
	model.Parent = parent
	return model
end

-- A closed expansion is invisible and walk-through; an open one is solid floor.
function WorldBuilder.setExpansionOpen(expansion: Model, open: boolean)
	expansion:SetAttribute("Open", open)
	for _, descendant in expansion:GetDescendants() do
		if descendant:IsA("BasePart") then
			local floor = descendant :: BasePart
			floor.Transparency = if open then 0 else 1
			floor.CanCollide = open
			floor.CanQuery = open
		end
	end
end

function WorldBuilder.setBackDoorOpen(plot: Plot, open: boolean)
	plot.backDoor.CanCollide = not open
	plot.backDoor.Transparency = if open then 1 else 0
end

local function buildPlot(index: number, parent: Instance): Plot
	local placement = Layout.plotPlacement(index)
	local origin = Vector3.new(placement.x, 0.2, placement.z)
	local cframe = CFrame.lookAt(origin, Vector3.new(0, 0.2, placement.z))

	local model = Instance.new("Model")
	model.Name = "Plot_" .. index
	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("OwnerUserId", 0)
	CollectionService:AddTag(model, "Plot")

	local halfW = W.PlotWidth / 2
	local halfD = W.PlotDepth / 2
	local wallH = W.WallHeight

	part(
		"Floor",
		Vector3.new(W.PlotWidth, 0.4, W.PlotDepth),
		cframe * CFrame.new(0, -0.2, 0),
		CARAMEL,
		Enum.Material.WoodPlanks,
		model
	)
	local walls = folder("Walls", model)
	-- The back wall has a door-sized panel that opens with the first expansion.
	local door0 = Layout.plot.backDoor
	local backLeft = door0.x - door0.width / 2 + halfW + 0.5 -- from the left corner to the door
	local backRight = halfW + 0.5 - (door0.x + door0.width / 2) -- from the door to the right corner
	part(
		"WallBackL",
		Vector3.new(backLeft, wallH, 1),
		cframe * CFrame.new(-halfW - 0.5 + backLeft / 2, wallH / 2, halfD + 0.5),
		CREAM,
		Enum.Material.SmoothPlastic,
		walls
	)
	part(
		"WallBackR",
		Vector3.new(backRight, wallH, 1),
		cframe * CFrame.new(halfW + 0.5 - backRight / 2, wallH / 2, halfD + 0.5),
		CREAM,
		Enum.Material.SmoothPlastic,
		walls
	)
	local backDoor = part(
		"BackDoor",
		Vector3.new(door0.width, wallH, 1),
		cframe * CFrame.new(door0.x, wallH / 2, halfD + 0.5),
		CREAM,
		Enum.Material.SmoothPlastic,
		walls
	)
	part(
		"WallLeft",
		Vector3.new(1, wallH, W.PlotDepth),
		cframe * CFrame.new(-halfW - 0.5, wallH / 2, 0),
		CREAM,
		Enum.Material.SmoothPlastic,
		walls
	)
	part(
		"WallRight",
		Vector3.new(1, wallH, W.PlotDepth),
		cframe * CFrame.new(halfW + 0.5, wallH / 2, 0),
		CREAM,
		Enum.Material.SmoothPlastic,
		walls
	)
	local segment = (W.PlotWidth - W.DoorWidth) / 2
	local segX = W.DoorWidth / 2 + segment / 2
	part(
		"WallFrontL",
		Vector3.new(segment, wallH, 1),
		cframe * CFrame.new(-segX, wallH / 2, -halfD - 0.5),
		CREAM,
		Enum.Material.SmoothPlastic,
		walls
	)
	part(
		"WallFrontR",
		Vector3.new(segment, wallH, 1),
		cframe * CFrame.new(segX, wallH / 2, -halfD - 0.5),
		CREAM,
		Enum.Material.SmoothPlastic,
		walls
	)
	part(
		"DoorHeader",
		Vector3.new(W.DoorWidth, 2, 1),
		cframe * CFrame.new(0, wallH - 1, -halfD - 0.5),
		MINT,
		Enum.Material.SmoothPlastic,
		walls
	)
	-- Windows either side of the door (glass)
	for _, x in { -11, 11 } do
		local glass = part(
			"Window",
			Vector3.new(6, 4, 0.3),
			cframe * CFrame.new(x, 4.5, -halfD - 0.5),
			Color3.fromRGB(180, 220, 240),
			Enum.Material.Glass,
			walls
		)
		glass.Transparency = 0.6
	end

	-- Door zone for check-in (invisible, no collision)
	local door = anchor("Door", localCFrame(cframe, Layout.plot.door), model)
	door.Size = Vector3.new(W.DoorWidth, 6, 2)
	door.CFrame = cframe * CFrame.new(0, 3, -halfD)

	-- Sign above the door
	local signPart = part(
		"Sign",
		Vector3.new(10, 2.2, 0.4),
		localCFrame(cframe, Layout.plot.sign),
		MINT,
		Enum.Material.SmoothPlastic,
		model
	)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = signPart
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(60, 50, 40)
	label.Text = "Cafe for rent"
	label.Parent = gui

	-- Counter, espresso machine, spot furniture
	place("CatCafe_Furniture_Counter", localCFrame(cframe, Layout.plot.counter), model).Name =
		"Counter"
	local espresso = anchor("EspressoAnchor", localCFrame(cframe, Layout.plot.espresso), model)

	local spotsFolder = folder("Spots", model)
	local furnitureFolder = folder("SpotFurniture", model)
	local spots: { [string]: BasePart } = {}
	local spotFurniture: { [string]: Model } = {}
	for _, def in Catalog.spots do
		local point = Layout.plot.spots[def.id]
		local spot = anchor(def.id, localCFrame(cframe, point), spotsFolder)
		spot:SetAttribute("SpotType", def.spotType)
		spot:SetAttribute("Tier", def.tier)
		spots[def.id] = spot
		local furniturePoint = Layout.plot.spotFurniture[def.id]
		local assetName = Catalog.spotFurniture[def.spotType]
		if furniturePoint ~= nil and assetName ~= nil then
			local furniture = place(assetName, localCFrame(cframe, furniturePoint), furnitureFolder)
			furniture.Name = def.id
			spotFurniture[def.id] = furniture
		end
	end

	local decorFolder = folder("DecorAnchors", model)
	local decorAnchors: { [string]: BasePart } = {}
	for _, def in Catalog.decor do
		local point = Layout.plot.decorAnchors[def.id]
		if point ~= nil then
			decorAnchors[def.id] = anchor(def.id, localCFrame(cframe, point), decorFolder)
		end
	end

	local tableFolder = folder("TableAnchors", model)
	local tableAnchors: { BasePart } = {}
	for i, point in Layout.plot.tables do
		local a = anchor("table_" .. i, localCFrame(cframe, point), tableFolder)
		table.insert(tableAnchors, a)
	end

	local expansionsFolder = folder("Expansions", model)
	local expansions: { Model } = {}
	for n, rect in Layout.plot.expansions do
		local expansion = Instance.new("Model")
		expansion.Name = tostring(n)
		local floor = part(
			"Floor",
			Vector3.new(rect.x2 - rect.x1, 0.4, rect.z2 - rect.z1),
			cframe * CFrame.new((rect.x1 + rect.x2) / 2, -0.2, (rect.z1 + rect.z2) / 2),
			if n == 3 then Color3.fromRGB(205, 200, 190) else CARAMEL,
			if n == 3 then Enum.Material.Slate else Enum.Material.WoodPlanks,
			expansion
		)
		expansion.PrimaryPart = floor
		expansion.Parent = expansionsFolder
		WorldBuilder.setExpansionOpen(expansion, false)
		table.insert(expansions, expansion)
	end

	local waypoints = folder("CustomerWaypoints", model)
	local entry = anchor("Entry", localCFrame(cframe, Layout.plot.entry), waypoints)
	anchor("Door", localCFrame(cframe, Layout.plot.door), waypoints)

	local plot: Plot = {
		index = index,
		model = model,
		cframe = cframe,
		door = door,
		sign = label,
		spots = spots,
		spotFurniture = spotFurniture,
		decorAnchors = decorAnchors,
		tableAnchors = tableAnchors,
		cats = folder("Cats", model),
		decor = folder("Decor", model),
		tables = folder("Tables", model),
		customerEntry = entry,
		espresso = espresso,
		backDoor = backDoor,
		expansions = expansions,
	}
	model.Parent = parent
	return plot
end

local function buildArea(
	id: string,
	spec: Layout.AreaSpec,
	look: AreaLook,
	parent: Instance
): AreaInfo
	local floorColor, floorMaterial, wallColor = look.floor, look.floorMaterial, look.wall
	local model = Instance.new("Model")
	model.Name = id:sub(1, 1):upper() .. id:sub(2)
	model:SetAttribute("Area", id)

	local cx, cz = spec.center.x, spec.center.z
	local hw, hd = spec.halfWidth, spec.halfDepth
	part(
		"Floor",
		Vector3.new(hw * 2, 0.2, hd * 2),
		CFrame.new(cx, 0, cz),
		floorColor,
		floorMaterial,
		model
	)

	local walls = folder("Walls", model)
	local wallH = 6
	-- Three closed sides; the side facing the street has an opening as wide as the street.
	local openingHalf = W.StreetHalfWidth
	local streetSide = if cz > 0 then -1 else 1 -- which Z edge faces the street
	local farZ = cz - streetSide * hd
	local nearZ = cz + streetSide * hd
	part(
		"WallFar",
		Vector3.new(hw * 2 + 1, wallH, 1),
		CFrame.new(cx, wallH / 2, farZ),
		wallColor,
		Enum.Material.Brick,
		walls
	)
	part(
		"WallLeft",
		Vector3.new(1, wallH, hd * 2),
		CFrame.new(cx - hw, wallH / 2, cz),
		wallColor,
		Enum.Material.Brick,
		walls
	)
	part(
		"WallRight",
		Vector3.new(1, wallH, hd * 2),
		CFrame.new(cx + hw, wallH / 2, cz),
		wallColor,
		Enum.Material.Brick,
		walls
	)
	local seg = hw - openingHalf
	part(
		"WallNearL",
		Vector3.new(seg, wallH, 1),
		CFrame.new(cx - openingHalf - seg / 2, wallH / 2, nearZ),
		wallColor,
		Enum.Material.Brick,
		walls
	)
	part(
		"WallNearR",
		Vector3.new(seg, wallH, 1),
		CFrame.new(cx + openingHalf + seg / 2, wallH / 2, nearZ),
		wallColor,
		Enum.Material.Brick,
		walls
	)

	local props = folder("Props", model)
	for _, prop in spec.props do
		place(
			prop.asset,
			CFrame.new(prop.x, spec.floorY + (prop.y or 0), prop.z)
				* CFrame.Angles(0, math.rad(prop.rotY or 0), 0),
			props
		)
	end

	local spawnFolder = folder("SpawnPoints", model)
	local spawnPoints: { BasePart } = {}
	for i, point in spec.spawnPoints do
		local sp = anchor(id .. "_" .. i, CFrame.new(point.x, point.y, point.z), spawnFolder)
		sp:SetAttribute("Area", id)
		sp:SetAttribute("Index", i)
		CollectionService:AddTag(sp, "SpawnPoint")
		table.insert(spawnPoints, sp)
	end

	local lureFolder = folder("LureSpots", model)
	local lureSpots: { [string]: BasePart } = {}
	for i, point in spec.lureSpots do
		local name = "lure_" .. id .. "_" .. i
		local ring = part(
			name,
			Vector3.new(0.1, 3, 3),
			CFrame.new(point.x, point.y, point.z) * CFrame.Angles(0, 0, math.rad(90)),
			MINT,
			Enum.Material.Neon,
			lureFolder
		)
		ring.Shape = Enum.PartType.Cylinder
		ring.Transparency = 0.5
		ring.CanCollide = false
		ring:SetAttribute("Area", id)
		ring:SetAttribute("LureSpotId", name)
		CollectionService:AddTag(ring, "LureSpot")
		lureSpots[name] = ring
	end

	-- Rescue spots (data-model section 13): the prop is always there, the stuck cat only some nights.
	local rescueFolder = folder("RescueSpots", model)
	local rescueSpots: { [string]: BasePart } = {}
	for i, point in spec.rescueSpots do
		local name = "rescue_" .. id .. "_" .. i
		local base = CFrame.new(point.x, spec.floorY, point.z)
			* CFrame.Angles(0, math.rad(point.rotY or 0), 0)
		place(point.prop, base, props)
		local pose = Layout.stuckPoses[point.prop]
		local catAt = if pose ~= nil then base * poseCFrame(pose) else base
		local spot = anchor(name, catAt, rescueFolder)
		spot:SetAttribute("Area", id)
		spot:SetAttribute("RescueSpotId", name)
		spot:SetAttribute("Occupied", false)
		spot:SetAttribute("LockedBy", 0)
		CollectionService:AddTag(spot, "RescueSpot")
		rescueSpots[name] = spot
	end

	model.Parent = parent
	return {
		id = id,
		model = model,
		floorY = spec.floorY,
		spawnPoints = spawnPoints,
		lureSpots = lureSpots,
		rescueSpots = rescueSpots,
		bounds = { minX = cx - hw + 2, maxX = cx + hw - 2, minZ = cz - hd + 2, maxZ = cz + hd - 2 },
	}
end

-- A tier gate across an area's opening (data-model section 9): `CatCafe_<Area>_Gate`, named `<Area>Gate` under
-- World.Gates with `Area` and `RequiresTier`. The client makes it solid for players below the tier; the server
-- checks the tier on every catch and rescue anyway, so walking around it gains nothing.
local function buildGate(def: Types.AreaDef, x: number, z: number, parent: Instance): Model
	local pascal = def.id:sub(1, 1):upper() .. def.id:sub(2)
	local gate = place("CatCafe_" .. pascal .. "_Gate", CFrame.new(x, 0.1, z), parent)
	gate.Name = pascal .. "Gate"
	gate:SetAttribute("Area", def.id)
	gate:SetAttribute("RequiresTier", def.tier)
	CollectionService:AddTag(gate, "AreaGate")
	local bars = gate:FindFirstChild("Bars")
	if bars ~= nil and bars:IsA("BasePart") then
		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(240, 40)
		billboard.StudsOffset = Vector3.new(0, 4, 0)
		billboard.MaxDistance = 80
		local text = Instance.new("TextLabel")
		text.Name = "Label"
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.TextScaled = true
		text.Font = Enum.Font.GothamBold
		text.TextColor3 = Color3.new(1, 1, 1)
		text.TextStrokeTransparency = 0.3
		text.Text = string.format("%s: opens at Tier %d", def.name, def.tier)
		text.Parent = billboard
		billboard.Parent = bars
	end
	return gate
end

function WorldBuilder.build(): World
	local existing = Workspace:FindFirstChild("World")
	if existing ~= nil then
		existing:Destroy()
	end
	local root = folder("World", Workspace)

	local ground = part(
		"Ground",
		Vector3.new(W.GroundSize, 1, W.GroundSize),
		CFrame.new(0, -0.5, 0),
		GRASS,
		Enum.Material.Grass,
		root
	)
	ground.Name = "Ground"
	part(
		"Street",
		Vector3.new(W.StreetHalfWidth * 2, 0.2, W.StreetLength + 10),
		CFrame.new(0, 0, 0),
		ASPHALT,
		Enum.Material.Asphalt,
		root
	)
	for _, x in { -W.StreetHalfWidth - 1, W.StreetHalfWidth + 1 } do
		part(
			"Sidewalk",
			Vector3.new(2, 0.3, W.StreetLength + 10),
			CFrame.new(x, 0.05, 0),
			Color3.fromRGB(200, 200, 195),
			Enum.Material.Concrete,
			root
		)
	end

	-- A Model set to Persistent so streaming never drops a far zone the client checks against.
	local zones = Instance.new("Model")
	zones.Name = "Zones"
	zones.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	zones.Parent = root

	local plotsFolder = folder("Plots", root)
	local plots: { Plot } = {}
	for i = 1, W.PlotCount do
		local plot = buildPlot(i, plotsFolder)
		table.insert(plots, plot)
		zone(
			"Cafe",
			Vector3.new(W.PlotWidth, W.WallHeight, W.PlotDepth),
			plot.cframe * CFrame.new(0, W.WallHeight / 2, 0),
			zones
		)
	end

	local areas: { [string]: AreaInfo } = {}
	local gates: { [string]: Model } = {}
	local gatesFolder = folder("Gates", root)
	for _, def in Catalog.areas do
		local spec = Layout.areas[def.id]
		assert(spec ~= nil, "no layout for area " .. def.id)
		assert(
			#spec.spawnPoints == def.spawnPoints,
			string.format(
				"%s: Layout has %d spawn points, Catalog says %d",
				def.id,
				#spec.spawnPoints,
				def.spawnPoints
			)
		)
		areas[def.id] = buildArea(def.id, spec, AREA_LOOKS[def.id], root)
		zone(
			def.id:sub(1, 1):upper() .. def.id:sub(2),
			Vector3.new(spec.halfWidth * 2, 30, spec.halfDepth * 2),
			CFrame.new(spec.center.x, spec.floorY + 15, spec.center.z),
			zones
		)
		if spec.gateZ ~= nil then
			gates[def.id] = buildGate(def, spec.center.x, spec.gateZ, gatesFolder)
		end
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlayerSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(Layout.playerSpawn.x, Layout.playerSpawn.y, Layout.playerSpawn.z)
	spawn.Anchored = true
	spawn.Color = MINT
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Duration = 0
	spawn.Parent = root

	return { folder = root, plots = plots, areas = areas, gates = gates }
end

return WorldBuilder
