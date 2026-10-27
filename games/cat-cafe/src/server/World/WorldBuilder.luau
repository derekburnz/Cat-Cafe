--!strict
-- Builds the whole graybox world from code at server start: ground, street, 8 plots with front gardens and patio
-- yards, the Alleyway behind them, four more areas and their gates (layout v2, data-model section 9).
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
	backDoor: BasePart, -- the back door panel: shut on an empty plot, open from Tier 1
	backDoorZone: BasePart, -- check-in works here as well as at the front door
	expansions: { Model }, -- Expansions/<n>, patio sections in the yard, hidden until the owner's tier opens them
	napSpots: { BasePart }, -- NapSpots/<n>, where cats without a job nap, best first
	dressing: Folder, -- Dressing/ForRent on an empty plot, Dressing/Tier<n> up to the owner's tier
	baitBowl: BasePart, -- BaitBowl, in the front garden: range checks, and the owner's client puts its prompt here
	baitCat: BasePart, -- BaitCat, where the cat that came to the bowl sits
	bait: Folder, -- Bait/, the bowl, its food and the cat while the owner has the Bait bowl upgrade
	richTipAnchor: BasePart, -- RichTipAnchor on table 1: the rich tip's coin pile, marker and claim range
}

export type AreaInfo = {
	id: string,
	model: Model,
	floorY: number,
	spawnPoints: { BasePart },
	rescueSpots: { [string]: BasePart }, -- rescueSpotId -> anchor where a stuck cat sits
	bounds: { minX: number, maxX: number, minZ: number, maxZ: number }, -- the bounding box, 2 studs in
	rects: { Layout.Rect }, -- the floor pieces (one zone box each)
	roam: { Layout.Rect }, -- where strays stay (WorldBuilder.clampToArea): the floors, less any dressed wall strip
	arrival: CFrame, -- where fast travel puts a player: just inside the entrance, facing in
}

export type World = {
	folder: Folder,
	plots: { Plot },
	areas: { [string]: AreaInfo },
	gates: { [string]: Model }, -- area id -> its tier gate (every area but the Tier 1 alley)
	manhole: Model?, -- the Square's way down into its area, when the art is there; its prompt is ManholePrompt
}

local WorldBuilder = {}

local W = Config.World
local CREAM = Color3.fromRGB(246, 236, 214)
local CARAMEL = Color3.fromRGB(190, 135, 80)
local MINT = Color3.fromRGB(165, 214, 190)
local ASPHALT = Color3.fromRGB(70, 70, 75)
local BRICK = Color3.fromRGB(150, 85, 70)
local GRASS = Color3.fromRGB(110, 170, 90)
local PICKET = Color3.fromRGB(250, 246, 236)
local PATH = Color3.fromRGB(214, 200, 176)
local DECK = Color3.fromRGB(205, 160, 110)
-- The cafe shell's facade pastel, by plot number (world-and-feel.md section 3).
local SHELL_COLORS = { "Mint", "Blush", "Butter", "Lilac" }

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

-- What a cafe shows from the street (F36, F38): tier 0 is an empty plot, dressed For Rent (shutters half down, the
-- sign, dust sheets and a sleeping doorstep cat); an owned cafe adds CatCafe_Plot_Tier1..n cumulatively up to its
-- tier. Pieces whose art is not in ReplicatedStorage.Assets are skipped.
function WorldBuilder.setDressing(plot: Plot, tier: number)
	local function show(name: string, asset: string, wanted: boolean)
		local existing = plot.dressing:FindFirstChild(name)
		if wanted and existing == nil and AssetRegistry.has(asset) then
			place(asset, plot.cframe, plot.dressing).Name = name
		elseif not wanted and existing ~= nil then
			existing:Destroy()
		end
	end
	show("ForRent", "CatCafe_Plot_ForRent", tier == 0)
	for n = 1, Catalog.maxTier do
		show("Tier" .. n, "CatCafe_Plot_Tier" .. n, tier >= n)
	end
end

-- The Closed sign with its moon (v0.5 F44) hangs in an owned cafe's front door at night: Dressing/ClosedSign at
-- the plot pivot like the tier sets, nothing on it collides, and its _Moon_Bulb glows with the street's night parts.
-- Skipped while its art is not in ReplicatedStorage.Assets.
function WorldBuilder.setClosedSign(plot: Plot, shown: boolean)
	local existing = plot.dressing:FindFirstChild("ClosedSign")
	if shown and existing == nil and AssetRegistry.has("CatCafe_Plot_ClosedSign") then
		local sign = place("CatCafe_Plot_ClosedSign", plot.cframe, plot.dressing)
		sign.Name = "ClosedSign"
		for _, descendant in sign:GetDescendants() do
			if descendant:IsA("BasePart") then
				local signPart = descendant :: BasePart
				signPart.CanCollide = false
				signPart.CanTouch = false
			end
		end
	elseif not shown and existing ~= nil then
		existing:Destroy()
	end
end

-- The nearest point to `position` on the area's floor, at least `margin` studs inside one of its rects, so a stray
-- that wanders or jumps back never leaves the area (or lands in a cafe yard beside the back alley). With `from`,
-- the point stays in the rect `from` stands in: a rect is convex, so the straight walk there never crosses a wall
-- (reviewer N54: near the back alley and Square junction the nearest rect can lie across the Square's south wall).
function WorldBuilder.clampToArea(
	info: AreaInfo,
	position: Vector3,
	margin: number,
	from: Vector3?
): Vector3
	local rects = info.roam
	if from ~= nil then
		local start = from :: Vector3
		for _, rect in info.roam do
			if
				start.X >= rect.x1
				and start.X <= rect.x2
				and start.Z >= rect.z1
				and start.Z <= rect.z2
			then
				rects = { rect }
				break
			end
		end
	end
	local best = Vector3.new(position.X, info.floorY, position.Z)
	local bestDistance = math.huge
	for _, rect in rects do
		local x =
			math.clamp(position.X, rect.x1 + margin, math.max(rect.x1 + margin, rect.x2 - margin))
		local z =
			math.clamp(position.Z, rect.z1 + margin, math.max(rect.z1 + margin, rect.z2 - margin))
		local distance = (x - position.X) ^ 2 + (z - position.Z) ^ 2
		if distance < bestDistance then
			bestDistance = distance
			best = Vector3.new(x, info.floorY, z)
		end
	end
	return best
end

-- The catching area whose floor `position` stands over (the same boxes as World.Zones: a floor rect, up to 30 studs
-- above it), or nil on the street, in a cafe or in a yard.
function WorldBuilder.areaAt(world: World, position: Vector3): string?
	for id, info in world.areas do
		if position.Y < info.floorY - 2 or position.Y > info.floorY + 30 then
			continue
		end
		for _, rect in info.rects do
			if
				position.X >= rect.x1
				and position.X <= rect.x2
				and position.Z >= rect.z1
				and position.Z <= rect.z2
			then
				return id
			end
		end
	end
	return nil
end

-- True on the plot itself (front garden to the back of its yard) or within `radius` studs of either of its doors:
-- where its owner cannot be shoved (data-model section 10c).
function WorldBuilder.inSafeZone(plot: Plot, position: Vector3, radius: number): boolean
	local offset = plot.cframe:PointToObjectSpace(position)
	local halfW = W.PlotWidth / 2 + 1
	local back = W.PlotDepth / 2 + 1 + W.YardDepth
	if
		math.abs(offset.X) <= halfW
		and offset.Z >= Layout.plot.frontGarden.z1
		and offset.Z <= back
	then
		return true
	end
	local flat = Vector3.new(position.X, 0, position.Z)
	for _, door in { plot.door, plot.backDoorZone } do
		local at = door.Position
		if (flat - Vector3.new(at.X, 0, at.Z)).Magnitude <= radius then
			return true
		end
	end
	return false
end

local function buildPlot(index: number, parent: Instance): Plot
	local placement = Layout.plotPlacement(index)
	local origin = Vector3.new(placement.x, 0.2, placement.z)
	local cframe = CFrame.lookAt(origin, Vector3.new(0, 0.2, placement.z))

	local model = Instance.new("Model")
	model.Name = "Plot_" .. index
	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("OwnerUserId", 0)
	model:SetAttribute("RichTipAmount", 0) -- display only; RichTipService keeps the tip itself
	model:SetAttribute("RichTipExpiresAt", 0)
	model.WorldPivot = cframe -- GetPivot is the plot's own frame: -Z faces the street
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
	-- The front garden strip and its path to the door, a little below the cafe floor.
	local gardenRect, pathRect = Layout.plot.frontGarden, Layout.plot.frontPath
	part(
		"FrontGarden",
		Vector3.new(gardenRect.x2 - gardenRect.x1, 0.4, gardenRect.z2 - gardenRect.z1),
		cframe
			* CFrame.new(
				(gardenRect.x1 + gardenRect.x2) / 2,
				-0.25,
				(gardenRect.z1 + gardenRect.z2) / 2
			),
		GRASS,
		Enum.Material.Grass,
		model
	)
	-- The cafe shell (F36): the asset-artist's storefront in one of four pastels by plot number, plus the interior
	-- dressing. Its roof is the child Model <name>_Roof, which the client fades while the player is inside. Without
	-- the art, the code-built path, walls, windows and sign below stand in.
	local shellName = "CatCafe_Plot_Cafe_" .. SHELL_COLORS[(index - 1) % #SHELL_COLORS + 1]
	local shell: Model? = nil
	if AssetRegistry.has(shellName) then
		local placed = place(shellName, cframe, model)
		placed.Name = "Shell"
		shell = placed
		if AssetRegistry.has("CatCafe_Plot_Interior") then
			place("CatCafe_Plot_Interior", cframe, model).Name = "Interior"
		end
	end
	local codeBuilt = shell == nil

	if codeBuilt then
		part(
			"FrontPath",
			Vector3.new(pathRect.x2 - pathRect.x1, 0.4, pathRect.z2 - pathRect.z1),
			cframe
				* CFrame.new(
					(pathRect.x1 + pathRect.x2) / 2,
					-0.23,
					(pathRect.z1 + pathRect.z2) / 2
				),
			PATH,
			Enum.Material.Cobblestone,
			model
		)
	end

	local walls = folder("Walls", model)
	-- The back wall has a door panel that is open from Tier 1, under a header; the shell has its own wall and header
	-- around the same doorway, so only the panel is built over it.
	local door0 = Layout.plot.backDoor
	if codeBuilt then
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
		part(
			"BackDoorHeader",
			Vector3.new(door0.width, wallH - door0.height, 1),
			cframe * CFrame.new(door0.x, (wallH + door0.height) / 2, halfD + 0.5),
			CREAM,
			Enum.Material.SmoothPlastic,
			walls
		)
	end
	local backDoor = part(
		"BackDoor",
		Vector3.new(door0.width, door0.height, 0.6),
		cframe * CFrame.new(door0.x, door0.height / 2, halfD + 0.5),
		MINT,
		Enum.Material.WoodPlanks,
		walls
	)
	local backDoorZone = anchor("BackDoorZone", cframe * CFrame.new(door0.x, 3, halfD + 0.5), model)
	backDoorZone.Size = Vector3.new(door0.width, 6, 2)

	-- The patio yard's low fence: both sides and the back, with a gate gap in line with the back door.
	local yard, gate = Layout.plot.yard, Layout.plot.yardGate
	local fenceH = Layout.plot.fenceHeight
	local fence = folder("YardFence", model)
	for _, x in { yard.x1 + 0.5, yard.x2 - 0.5 } do
		part(
			"FenceSide",
			Vector3.new(0.4, fenceH, yard.z2 - yard.z1),
			cframe * CFrame.new(x, fenceH / 2, (yard.z1 + yard.z2) / 2),
			PICKET,
			Enum.Material.WoodPlanks,
			fence
		)
	end
	for _, span in { { yard.x1, gate.x1 }, { gate.x2, yard.x2 } } do
		part(
			"FenceBack",
			Vector3.new(span[2] - span[1], fenceH, 0.4),
			cframe * CFrame.new((span[1] + span[2]) / 2, fenceH / 2, yard.z2 - 0.2),
			PICKET,
			Enum.Material.WoodPlanks,
			fence
		)
	end
	if codeBuilt then
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
	end

	-- Door zone for check-in (invisible, no collision)
	local door = anchor("Door", localCFrame(cframe, Layout.plot.door), model)
	door.Size = Vector3.new(W.DoorWidth, 6, 2)
	door.CFrame = cframe * CFrame.new(0, 3, -halfD)
	CollectionService:AddTag(door, "CafeDoor") -- the client's Audio rings the door bell here

	-- The name sign: the street face of the shell's SignBoard, or a code-built board above the door.
	local board = if shell ~= nil then shell:FindFirstChild("SignBoard", true) else nil
	local signPart: BasePart
	if board ~= nil and board:IsA("BasePart") then
		signPart = board :: BasePart
	else
		signPart = part(
			"Sign",
			Vector3.new(10, 2.2, 0.4),
			localCFrame(cframe, Layout.plot.sign),
			MINT,
			Enum.Material.SmoothPlastic,
			model
		)
	end
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
			DECK,
			Enum.Material.WoodPlanks,
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
	anchor("Order", localCFrame(cframe, Layout.plot.orderPoint), waypoints)

	-- The bait bowl's anchors (data-model section 8). CafeService puts the bowl, the food and the cat in Bait/;
	-- the owner's client makes the bowl's prompt itself, so nobody else sees one at this cafe.
	local baitBowl = anchor("BaitBowl", localCFrame(cframe, Layout.plot.baitBowl), model)
	local baitCat = anchor("BaitCat", localCFrame(cframe, Layout.plot.baitCat), model)
	local richTipAnchor = anchor("RichTipAnchor", localCFrame(cframe, Layout.plot.richTip), model)

	local napFolder = folder("NapSpots", model)
	local napSpots: { BasePart } = {}
	for n, point in Layout.plot.napSpots do
		table.insert(napSpots, anchor(tostring(n), localCFrame(cframe, point), napFolder))
	end

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
		backDoorZone = backDoorZone,
		expansions = expansions,
		napSpots = napSpots,
		dressing = folder("Dressing", model),
		baitBowl = baitBowl,
		baitCat = baitCat,
		bait = folder("Bait", model),
		richTipAnchor = richTipAnchor,
	}
	WorldBuilder.setDressing(plot, 0)
	model.Parent = parent
	return plot
end

-- An archway over an entrance (the street and both back alleys into the Alley Square). The alley kit's arch when
-- its art is there (pivot at the base centre of the opening, -Z toward the street or the back alley, its own name
-- boards); otherwise two brick posts, a beam and a name board facing both ways.
local function buildArch(
	x: number,
	z: number,
	span: number,
	label: string,
	asset: string?,
	color: Color3,
	parent: Instance
)
	if asset ~= nil and AssetRegistry.has(asset) then
		place(asset, CFrame.new(x, 0.1, z), parent).Name = "Arch"
		return
	end
	local arch = Instance.new("Model")
	arch.Name = "Arch"
	local height = 12
	for _, side in { -1, 1 } do
		part(
			"Post",
			Vector3.new(2, height, 2),
			CFrame.new(x + side * (span / 2 + 1), height / 2, z),
			color,
			Enum.Material.Brick,
			arch
		)
	end
	part(
		"Beam",
		Vector3.new(span + 4, 1.5, 2),
		CFrame.new(x, height + 0.75, z),
		color,
		Enum.Material.Brick,
		arch
	)
	local board = part(
		"NameBoard",
		Vector3.new(math.min(span, 18), 2.4, 0.4),
		CFrame.new(x, height - 1.6, z),
		Color3.fromRGB(60, 50, 45),
		Enum.Material.Wood,
		arch
	)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(255, 214, 120)
		text.Text = label
		text.Parent = gui
		gui.Parent = board
	end
	arch.Parent = parent
end

-- Safe zone markings (Derek 2026-10-27: the catching alleys are sectioned off from the cafes, and the cafe side is
-- safe). A shove only lands inside a catching area (Shove.refusal), so the line is the edge of an area's floor
-- where the cafe district meets it: a red stripe on the area side, and SAFE ZONE painted on the cafe side.
local SAFE_RED = Color3.fromRGB(226, 72, 72)
local SAFE_WORDS = Color3.fromRGB(255, 255, 255)
local SAFE_OUTLINE = Color3.fromRGB(120, 40, 40)

local function flatMark(name: string, size: Vector3, cframe: CFrame, parent: Instance): Part
	local mark = part(name, size, cframe, SAFE_RED, Enum.Material.SmoothPlastic, parent)
	mark.CanCollide = false
	mark.CanQuery = false
	mark.CanTouch = false
	mark.CastShadow = false
	return mark
end

local function safeStripe(from: Vector3, to: Vector3, parent: Instance)
	local length = (to - from).Magnitude
	local mid = (from + to) / 2
	flatMark("SafeLine", Vector3.new(0.5, 0.05, length), CFrame.lookAt(mid, to), parent)
end

-- SAFE ZONE in paint, `width` studs wide, at `at` (its top surface) and reading the right way up for a player
-- walking along `walking` into the safe zone. A SurfaceGui on a part's Top face reads up toward the part's +Z, so
-- the plate's +Z points along `walking`.
local function safeWords(at: Vector3, walking: Vector3, width: number, parent: Instance)
	local flat = Vector3.new(walking.X, 0, walking.Z).Unit
	local centre = at - Vector3.new(0, 0.025, 0)
	local plate = flatMark(
		"SafeZoneWords",
		Vector3.new(width, 0.05, width * 0.2),
		CFrame.lookAt(centre, centre - flat),
		parent
	)
	plate.Transparency = 1
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = SAFE_WORDS
	text.TextStrokeColor3 = SAFE_OUTLINE
	text.TextStrokeTransparency = 0
	text.Text = "SAFE ZONE"
	text.Parent = gui
	gui.Parent = plate
end

-- Every way from the cafe district into a catching area: the back alleys' inner edges (yard gates and the side
-- passages between cafes), the street's arch into the Alley Square, and the Park gate at the street's south end.
local function buildSafeZoneMarks(parent: Instance)
	local marks = folder("SafeZone", parent)
	local alleyTop = Layout.alley.floorY + 0.03
	local streetTop = 0.13 -- the street's surface is at 0.1
	local groundTop = 0.03 -- grass in the side passages
	for _, side in { -1, 1 } do
		local x = side * (W.AlleyInnerX + 0.3)
		safeStripe(
			Vector3.new(x, alleyTop, W.AlleySouthZ),
			Vector3.new(x, alleyTop, W.SquareSouthZ - 1),
			marks
		)
		-- the side passages between neighbouring cafes, at their alley end
		local rows = math.ceil(W.PlotCount / 2)
		for row = 1, rows - 1 do
			local z = (row - rows / 2) * (W.PlotWidth + W.PlotRowGap)
			safeWords(
				Vector3.new(side * (W.AlleyInnerX - 2.5), groundTop, z),
				Vector3.new(-side, 0, 0),
				W.PlotRowGap - 3, -- inside the gap between two yard fences
				marks
			)
		end
	end
	local street = W.StreetHalfWidth + 2
	safeStripe(
		Vector3.new(-street, alleyTop, W.SquareSouthZ + 0.3),
		Vector3.new(street, alleyTop, W.SquareSouthZ + 0.3),
		marks
	)
	safeWords(Vector3.new(0, streetTop, W.SquareSouthZ - 4), Vector3.new(0, 0, -1), 12, marks)
	-- On the Park floor just inside its near wall (1 stud thick, centred on the area's edge), so the stripe is on
	-- the area side like the others (reviewer S54); the gate is as wide as the street it closes (24 studs).
	local parkHalf = W.StreetHalfWidth
	local parkEdge = W.ParkCenterZ + W.ParkDepth / 2 - 0.8
	local parkTop = Layout.park.floorY + 0.03
	safeStripe(
		Vector3.new(-parkHalf, parkTop, parkEdge),
		Vector3.new(parkHalf, parkTop, parkEdge),
		marks
	)
	safeWords(Vector3.new(0, streetTop, W.ParkGateZ + 4), Vector3.new(0, 0, 1), 12, marks)
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
	local walls = folder("Walls", model)
	local rects: { Layout.Rect }
	local arrival: CFrame
	local specRects = spec.rects
	if specRects ~= nil then
		-- The Alleyway: its floor pieces, wall footprints and archways as listed.
		rects = specRects
		for n, rect in specRects do
			part(
				"Floor" .. n,
				Vector3.new(rect.x2 - rect.x1, 0.2, rect.z2 - rect.z1),
				CFrame.new((rect.x1 + rect.x2) / 2, 0, (rect.z1 + rect.z2) / 2),
				floorColor,
				floorMaterial,
				model
			)
		end
		local wallH = spec.wallHeight or 6
		local wallRects: { Layout.Rect } = spec.walls or {}
		for _, rect in wallRects do
			part(
				"Wall",
				Vector3.new(rect.x2 - rect.x1, wallH, rect.z2 - rect.z1),
				CFrame.new((rect.x1 + rect.x2) / 2, wallH / 2, (rect.z1 + rect.z2) / 2),
				wallColor,
				Enum.Material.Brick,
				walls
			)
		end
		local arches: { { x: number, z: number, span: number, label: string, asset: string? } } = spec.arches
			or {}
		for _, arch in arches do
			buildArch(arch.x, arch.z, arch.span, arch.label, arch.asset, wallColor, model)
		end
		local at = spec.arrival or spec.center
		arrival = CFrame.new(at.x, spec.floorY + 3, at.z)
			* CFrame.Angles(0, math.rad(at.rotY or 0), 0)
	else
		rects = { { x1 = cx - hw, z1 = cz - hd, x2 = cx + hw, z2 = cz + hd } }
		part(
			"Floor",
			Vector3.new(hw * 2, 0.2, hd * 2),
			CFrame.new(cx, 0, cz),
			floorColor,
			floorMaterial,
			model
		)
		local wallH = 6
		-- Three closed sides; the side facing the street's end has an opening as wide as the street, or as the back
		-- alley for the Woods and the Sewer.
		local openingHalf = spec.openingHalfWidth or W.StreetHalfWidth
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
		arrival = CFrame.lookAt(
			Vector3.new(cx, spec.floorY + 3, nearZ - streetSide * 6),
			Vector3.new(cx, spec.floorY + 3, cz)
		)
	end

	local props = folder("Props", model)
	for _, prop in spec.props do
		if not AssetRegistry.known(prop.asset) then
			-- Dressing only: a piece whose art has not landed is left out rather than stopping the world build.
			warn(
				string.format(
					"[WorldBuilder] %s: no model or placeholder for %s, skipped",
					id,
					prop.asset
				)
			)
			continue
		end
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
		if point.zone ~= nil then
			sp:SetAttribute("Zone", point.zone)
		end
		CollectionService:AddTag(sp, "SpawnPoint")
		table.insert(spawnPoints, sp)
	end

	-- Rescue traps (data-model sections 10b and 13): the trap is always there, the stuck cat only some nights.
	-- The trap model sits next to its anchor as "<rescueSpotId>_Trap", so a client can find a tree's branch.
	local rescueFolder = folder("RescueSpots", model)
	local rescueSpots: { [string]: BasePart } = {}
	for i, point in spec.rescueSpots do
		local name = "rescue_" .. id .. "_" .. i
		local base = CFrame.new(point.x, spec.floorY, point.z)
			* CFrame.Angles(0, math.rad(point.rotY or 0), 0)
		local trap = place(point.prop, base, rescueFolder)
		trap.Name = name .. "_Trap"
		local pose = Layout.stuckPoses[point.prop]
		local catAt = if pose ~= nil then base * poseCFrame(pose) else base
		local spot = anchor(name, catAt, rescueFolder)
		spot:SetAttribute("Area", id)
		spot:SetAttribute("RescueSpotId", name)
		spot:SetAttribute("TrapType", point.trap)
		spot:SetAttribute("RetryAt", 0)
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
		rescueSpots = rescueSpots,
		bounds = { minX = cx - hw + 2, maxX = cx + hw - 2, minZ = cz - hd + 2, maxZ = cz + hd - 2 },
		rects = rects,
		roam = spec.roam or rects,
		arrival = arrival,
	}
end

-- A tier gate across an area's opening (data-model section 9): `CatCafe_<Area>_Gate`, named `<Area>Gate` under
-- World.Gates with `Area` and `RequiresTier`. The client makes its Bars solid for players below the tier; the
-- server checks the tier on every catch and rescue anyway, so walking around it gains nothing.
local function buildGate(
	def: Types.AreaDef,
	x: number,
	z: number,
	turn: number,
	parent: Instance
): Model
	local pascal = def.id:sub(1, 1):upper() .. def.id:sub(2)
	local gate = place(
		"CatCafe_" .. pascal .. "_Gate",
		CFrame.new(x, 0.1, z) * CFrame.Angles(0, turn, 0),
		parent
	)
	gate.Name = pascal .. "Gate"
	gate:SetAttribute("Area", def.id)
	gate:SetAttribute("RequiresTier", def.tier)
	CollectionService:AddTag(gate, "AreaGate") -- the UI hangs its gate sign (lock, tier, progress) on this tag
	return gate
end

-- The manhole in the Square (Layout.manhole): under World.Gates and tagged AreaGate like a gate, so the client
-- slides its _Cover off and the UI hangs the area's sign over it once the player's tier opens the area. Its prompt
-- is a fast travel button the server answers like Travel(area).
local function buildManhole(parent: Instance): Model?
	local spec = Layout.manhole
	local def = Catalog.getArea(spec.area)
	if def == nil or not AssetRegistry.has("CatCafe_Sewer_Manhole") then
		return nil
	end
	local model = place("CatCafe_Sewer_Manhole", CFrame.new(spec.x, spec.y, spec.z), parent)
	model.Name = "SewerManhole"
	model:SetAttribute("Area", def.id)
	model:SetAttribute("RequiresTier", def.tier)
	CollectionService:AddTag(model, "AreaGate")
	-- Custom: the UI's action pill, floating a little above the cover.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ManholePrompt"
	prompt.ActionText = "Climb down"
	prompt.ObjectText = def.name
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	local found = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if found ~= nil then
		local float = Instance.new("Attachment")
		float.Name = "PromptPoint"
		float.Parent = found
		float.WorldPosition = Vector3.new(spec.x, spec.y + 2.5, spec.z)
		prompt.Parent = float
	end
	return model
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
	-- The street ends where it runs into the Alley Square at its north end.
	local streetLength = W.StreetNorthZ - W.StreetSouthZ
	local streetMidZ = (W.StreetNorthZ + W.StreetSouthZ) / 2
	part(
		"Street",
		Vector3.new(W.StreetHalfWidth * 2, 0.2, streetLength),
		CFrame.new(0, 0, streetMidZ),
		ASPHALT,
		Enum.Material.Asphalt,
		root
	)
	for _, x in { -W.StreetHalfWidth - 1, W.StreetHalfWidth + 1 } do
		part(
			"Sidewalk",
			Vector3.new(2, 0.3, streetLength),
			CFrame.new(x, 0.05, streetMidZ),
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
		-- One zone box per floor piece, so the Alleyway's zone follows its back alleys and the Square.
		for _, rect in areas[def.id].rects do
			zone(
				def.id:sub(1, 1):upper() .. def.id:sub(2),
				Vector3.new(rect.x2 - rect.x1, 30, rect.z2 - rect.z1),
				CFrame.new((rect.x1 + rect.x2) / 2, spec.floorY + 15, (rect.z1 + rect.z2) / 2),
				zones
			)
		end
		if spec.gateZ ~= nil then
			-- The gate's front (-Z, its sign) faces the way players come from, so it turns round when the area
			-- lies toward -Z of it: the Park, the Woods and the Sewer (alley kit notes, reviewer N68).
			local turn = if spec.center.z < spec.gateZ then math.pi else 0
			gates[def.id] = buildGate(def, spec.center.x, spec.gateZ, turn, gatesFolder)
		end
	end
	local manhole = buildManhole(gatesFolder)
	buildSafeZoneMarks(root)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlayerSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(Layout.playerSpawn.x, Layout.playerSpawn.y, Layout.playerSpawn.z)
	spawn.Anchored = true
	spawn.Color = MINT
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Duration = 0
	spawn.Parent = root

	return { folder = root, plots = plots, areas = areas, gates = gates, manhole = manhole }
end

return WorldBuilder
