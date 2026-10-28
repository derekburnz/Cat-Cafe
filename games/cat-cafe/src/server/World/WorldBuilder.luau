--!strict
-- Builds the whole graybox world from code at server start: ground, street, the Town Square in its middle, 8 plots
-- with front gardens and patio yards, the Alleyway behind them, four more areas and their gates (layout v3, F76,
-- data-model section 9).
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
	decorSpots: { BasePart }, -- DecorSpots/<n>: crate furniture and decorations (F53), filled in order
	tableAnchors: { BasePart },
	cats: Folder,
	decor: Folder,
	tables: Folder,
	customerEntry: BasePart,
	counter: Model, -- Counter; out of the plot while the For Rent set's dust-sheeted counter stands in for it
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
	arrivalEast: CFrame?, -- the Alleyway's landing for a player whose cafe is on the east side (v3.1)
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
		floor = Color3.fromRGB(130, 185, 100), -- front lawns; the roads are laid on top (Layout paths)
		floorMaterial = Enum.Material.Grass,
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

-- Derek 22:43: an empty cafe has no cats. The For Rent art still has a sleeping doorstep cat and its Zzz baked in
-- (plot.py _sleeping_cat), so they come out here; harmless once the art drops them.
local function removeDoorstepCat(set: Instance)
	for _, descendant in set:GetDescendants() do
		local name = descendant.Name
		if name:find("_Cat_", 1, true) ~= nil or name:sub(-4) == "_Zzz" then
			descendant:Destroy()
		end
	end
end

-- What a cafe shows from the street (F36, F38): tier 0 is an empty plot, dressed For Rent (shutters half down, the
-- sign and dust sheets, and no cat); an owned cafe adds CatCafe_Plot_Tier1..n cumulatively up to its tier. Pieces
-- whose art is not in ReplicatedStorage.Assets are skipped.
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
	local forRent = plot.dressing:FindFirstChild("ForRent")
	if forRent ~= nil then
		removeDoorstepCat(forRent)
	end
	for n = 1, Catalog.maxTier do
		show("Tier" .. n, "CatCafe_Plot_Tier" .. n, tier >= n)
	end
	-- The For Rent set drapes its own dust sheet where the counter stands, so the real counter, whose pastry case
	-- and till would poke through the sheet, waits out of the plot until the cafe opens.
	plot.counter.Parent = if plot.dressing:FindFirstChild("ForRent") ~= nil then nil else plot.model
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

	local plotFloor = part(
		"Floor",
		Vector3.new(W.PlotWidth, 0.4, W.PlotDepth),
		cframe * CFrame.new(0, -0.2, 0),
		CARAMEL,
		Enum.Material.WoodPlanks,
		model
	)
	CollectionService:AddTag(plotFloor, "Floor") -- the crate floor in use colours it (F53, StyleController)
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
	local counter =
		place("CatCafe_Furniture_Counter", localCFrame(cframe, Layout.plot.counter), model)
	counter.Name = "Counter"
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
	for decorId, point in Layout.plot.decorAnchors do
		decorAnchors[decorId] = anchor(decorId, localCFrame(cframe, point), decorFolder)
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
	local decorSpotFolder = folder("DecorSpots", model)
	local decorSpots: { BasePart } = {}
	for n, point in Layout.plot.decorSpots do
		table.insert(decorSpots, anchor(tostring(n), localCFrame(cframe, point), decorSpotFolder))
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
		decorSpots = decorSpots,
		tableAnchors = tableAnchors,
		cats = folder("Cats", model),
		decor = folder("Decor", model),
		tables = folder("Tables", model),
		customerEntry = entry,
		counter = counter,
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

-- An archway over an entrance (the street and both back alleys into the Alley Square, the Town Square's side arches
-- into the back alleys). The art's arch when it is there (pivot at the base centre of the opening, -Z toward the
-- street or the back alley, its own name boards), turned `rotY` degrees; otherwise two brick posts, a beam and a
-- name board facing both ways.
local function buildArch(
	x: number,
	z: number,
	span: number,
	label: string,
	asset: string?,
	color: Color3,
	parent: Instance,
	rotY: number?
)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(rotY or 0), 0)
	if asset ~= nil and AssetRegistry.has(asset) then
		place(asset, base + Vector3.new(0, 0.1, 0), parent).Name = "Arch"
		return
	end
	local arch = Instance.new("Model")
	arch.Name = "Arch"
	local height = 12
	for _, side in { -1, 1 } do
		part(
			"Post",
			Vector3.new(2, height, 2),
			base * CFrame.new(side * (span / 2 + 1), height / 2, 0),
			color,
			Enum.Material.Brick,
			arch
		)
	end
	part(
		"Beam",
		Vector3.new(span + 4, 1.5, 2),
		base * CFrame.new(0, height + 0.75, 0),
		color,
		Enum.Material.Brick,
		arch
	)
	local board = part(
		"NameBoard",
		Vector3.new(math.min(span, 18), 2.4, 0.4),
		base * CFrame.new(0, height - 1.6, 0),
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

-- Every way from the cafe district into a catching area: the back alleys' inner edges (yard gates, the side
-- passages between cafes and the Town Square's side arches), and the Park and Neighbourhood gates at the street's
-- ends (v3.1). The Woods and Sewer gates are reached only through the back alleys, which are already outside.
local function buildSafeZoneMarks(parent: Instance)
	local marks = folder("SafeZone", parent)
	local alleyTop = Layout.alley.floorY + 0.03
	local streetTop = 0.13 -- the street's surface is at 0.1
	local groundTop = 0.03 -- grass in the side passages
	for _, side in { -1, 1 } do
		local x = side * (W.AlleyInnerX + 0.3)
		safeStripe(
			Vector3.new(x, alleyTop, W.AlleySouthZ),
			Vector3.new(x, alleyTop, W.AlleyNorthZ),
			marks
		)
		-- the side passages between neighbouring cafes (and beside the Town Square's gardens), at their alley end
		for _, z in Layout.sidePassages() do
			safeWords(
				Vector3.new(side * (W.AlleyInnerX - 2.5), groundTop, z),
				Vector3.new(-side, 0, 0),
				W.PlotRowGap - 3, -- inside the gap between two yard fences
				marks
			)
		end
		-- the Town Square's side arch, on the garden side, over the garden path's stones (their tops at 0.12)
		safeWords(
			Vector3.new(side * (W.AlleyInnerX - 3.5), streetTop, 0),
			Vector3.new(-side, 0, 0),
			W.TownSquareArchWidth - 3,
			marks
		)
	end
	-- On each end area's floor just inside its near wall (1 stud thick, centred on the area's edge), so the stripe
	-- is on the area side like the others (reviewer S54); each gate is as wide as the street it closes (32 studs).
	local half = W.StreetHalfWidth
	for _, spec in { Layout.park, Layout.neighbourhood } do
		local toward = if spec.center.z < 0 then 1 else -1 -- from the area toward the street
		local edge = spec.center.z + toward * (spec.halfDepth - 0.8)
		local top = spec.floorY + 0.03
		safeStripe(Vector3.new(-half, top, edge), Vector3.new(half, top, edge), marks)
		local gateZ = spec.gateZ :: number
		safeWords(
			Vector3.new(0, streetTop, gateZ + toward * 4),
			Vector3.new(0, 0, toward),
			12,
			marks
		)
	end
end

-- The Alleyway has no tier gate, so at night (v0.9, F66) a fence closes it along the same lines as the safe zone
-- stripes. This plain one stands in while the night fence art is missing (buildNightFences): both back alleys'
-- inner edges, the bars across each side arch carrying a "Closed until sunrise" sign toward the square (v3.1).
-- `AlleyNightFence` under World.Gates, `Area` alley and `RequiresTier` 1, but no AreaGate tag (no gate sign or
-- unlock effect): the client treats its Bars like a gate's and closes them while the Clock's AreasOpen is false.
-- CanCollide stays off here, so the server's rays and the strays never meet it.
local NIGHT_FENCE_WOOD = Color3.fromRGB(92, 64, 51)
local NIGHT_FENCE_HEIGHT = 8 -- over a default jump
local NIGHT_FENCE_SEGMENT = 8 -- studs along the line per CatCafe_Alley_NightFenceSegment (8.1 wide, posts overlap)

local function nightFenceBars(from: Vector3, to: Vector3, parent: Instance): Part
	local length = (to - from).Magnitude
	local mid = (from + to) / 2 + Vector3.new(0, NIGHT_FENCE_HEIGHT / 2, 0)
	local bars = part(
		"Bars",
		Vector3.new(0.4, NIGHT_FENCE_HEIGHT, length),
		CFrame.lookAt(mid, Vector3.new(to.X, mid.Y, to.Z)),
		NIGHT_FENCE_WOOD,
		Enum.Material.WoodPlanks,
		parent
	)
	bars.CanCollide = false
	bars.CanQuery = false
	bars.CanTouch = false
	return bars
end

local function buildAlleyNightFence(parent: Instance): Model
	local fence = Instance.new("Model")
	fence.Name = "AlleyNightFence"
	fence.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- never streams back in with its day look (N165)
	fence:SetAttribute("Area", "alley")
	fence:SetAttribute("RequiresTier", 1)
	local floor = Layout.alley.floorY
	local arch = W.TownSquareArchWidth / 2
	for _, side in { -1, 1 } do
		local x = side * (W.AlleyInnerX + 0.3)
		nightFenceBars(Vector3.new(x, floor, W.AlleySouthZ), Vector3.new(x, floor, -arch), fence)
		nightFenceBars(Vector3.new(x, floor, arch), Vector3.new(x, floor, W.AlleyNorthZ), fence)
		local across =
			nightFenceBars(Vector3.new(x, floor, -arch), Vector3.new(x, floor, arch), fence)
		-- the bars' own faces are Left and Right as built; the sign reads from the square on either
		for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
			local gui = Instance.new("SurfaceGui")
			gui.Name = "ClosedSign"
			gui.Face = face
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 20
			gui.LightInfluence = 0
			local text = Instance.new("TextLabel")
			text.AnchorPoint = Vector2.new(0.5, 0.5)
			text.Position = UDim2.fromScale(0.5, 0.5)
			text.Size = UDim2.fromScale(0.9, 0.35)
			text.BackgroundTransparency = 1
			text.Font = Enum.Font.FredokaOne
			text.TextScaled = true
			text.TextColor3 = SAFE_WORDS
			text.TextStrokeColor3 = NIGHT_FENCE_WOOD
			text.TextStrokeTransparency = 0
			text.Text = "Closed until sunrise"
			text.Parent = gui
			gui.Parent = across
		end
	end
	fence.Parent = parent
	return fence
end

-- The night fence art (F66, Model-Agent #318): models tagged NightFence that show only while the areas are closed.
-- Each is built hidden and walk-through here, with every part's own look and collision kept in attributes
-- (NightTransparency, NightCollide; NightEnabled on lights, GUIs, emitters, beams and trails), and the client shows
-- it while the Clock's AreasOpen is false (WorldController). The server never makes them solid, so strays and the
-- server's rays never meet them, as with the gates' Bars.
local function hideForDay(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local piece = descendant :: BasePart
			piece:SetAttribute("NightTransparency", piece.Transparency)
			piece:SetAttribute("NightCollide", piece.CanCollide)
			piece.Transparency = 1
			piece.CanCollide = false
			piece.CanQuery = false
			piece.CanTouch = false
		elseif descendant:IsA("Decal") then
			local decal = descendant :: Decal
			decal:SetAttribute("NightTransparency", decal.Transparency)
			decal.Transparency = 1
		elseif descendant:IsA("Light") then
			local light = descendant :: Light
			light:SetAttribute("NightEnabled", light.Enabled)
			light.Enabled = false
		elseif descendant:IsA("LayerCollector") then
			local gui = descendant :: LayerCollector
			gui:SetAttribute("NightEnabled", gui.Enabled)
			gui.Enabled = false
		elseif
			descendant:IsA("ParticleEmitter")
			or descendant:IsA("Beam")
			or descendant:IsA("Trail")
		then
			local effect = descendant :: any
			effect:SetAttribute("NightEnabled", effect.Enabled)
			effect.Enabled = false
		end
	end
end

local function placeNightFence(asset: string, cframe: CFrame, parent: Instance): Model
	local model = place(asset, cframe, parent)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- never streams back in with its night look
	CollectionService:AddTag(model, "NightFence")
	hideForDay(model)
	return model
end

-- Every night fence: one behind each area gate's Bars, segments tiled along both back alleys' inner edges (front
-- toward the cafes, across the Town Square's side arches too), and a closed back door in each plot (the client shows
-- that one only on an owned cafe, whose back door is open by day). False when the Alleyway's segment art is missing,
-- so the code-built AlleyNightFence closes it instead. v3.1 took away the street arch the Alleyway's big night
-- fence stood in, so CatCafe_Alley_NightFence is no longer placed.
local function buildNightFences(
	gates: { [string]: Model },
	plots: { Plot },
	parent: Instance
): boolean
	for areaId, gate in gates do
		local asset = "CatCafe_" .. areaId:sub(1, 1):upper() .. areaId:sub(2) .. "_NightFence"
		if AssetRegistry.has(asset) then
			placeNightFence(asset, gate:GetPivot(), parent).Name = asset
		end
	end
	if AssetRegistry.has("CatCafe_Plot_BackDoorClosed") then
		for _, plot in plots do
			placeNightFence("CatCafe_Plot_BackDoorClosed", plot.cframe, plot.model).Name =
				"BackDoorClosed"
		end
	end
	if not AssetRegistry.has("CatCafe_Alley_NightFenceSegment") then
		return false
	end
	local floor = Layout.alley.floorY
	-- the end posts clear the end walls' pieces (Model-Agent, after #375)
	local from, to = W.AlleySouthZ + 2.1, W.AlleyNorthZ - 2.1
	local count = math.ceil((to - from) / NIGHT_FENCE_SEGMENT)
	local step = (to - from) / count
	for _, side in { -1, 1 } do
		local x = side * (W.AlleyInnerX + 0.3)
		local turn = math.rad(90 * side) -- the front (-Z) toward the cafes, which lie toward x = 0
		for n = 1, count do
			local z = from + (n - 0.5) * step
			placeNightFence(
				"CatCafe_Alley_NightFenceSegment",
				CFrame.new(x, floor, z) * CFrame.Angles(0, turn, 0),
				parent
			).Name =
				"CatCafe_Alley_NightFenceSegment"
		end
	end
	return true
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
	local arrivalEast: CFrame? = nil
	-- The area's kit set when its art is there (Layout.AreaSpec.set): it brings the ground dressing, buildings and
	-- trees, so the graybox paths and props stay out.
	local set = spec.set
	local hasSet = set ~= nil and AssetRegistry.known(set)
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
		local arches: { Layout.Arch } = spec.arches or {}
		for _, arch in arches do
			buildArch(arch.x, arch.z, arch.span, arch.label, arch.asset, wallColor, model)
		end
		local at = spec.arrival or spec.center
		arrival = CFrame.new(at.x, spec.floorY + 3, at.z)
			* CFrame.Angles(0, math.rad(at.rotY or 0), 0)
		local east = spec.arrivalEast
		if east ~= nil then
			arrivalEast = CFrame.new(east.x, spec.floorY + 3, east.z)
				* CFrame.Angles(0, math.rad(east.rotY or 0), 0)
		end
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
		local function wall(name: string, x1: number, z1: number, x2: number, z2: number)
			part(
				name,
				Vector3.new(x2 - x1, wallH, z2 - z1),
				CFrame.new((x1 + x2) / 2, wallH / 2, (z1 + z2) / 2),
				wallColor,
				Enum.Material.Brick,
				walls
			)
		end
		-- Three closed sides; the side facing the town has an opening as wide as the street, or as the gate for the
		-- Woods and the Sewer, whose town side is an X side since v3.1. Walls are 1 thick, centred on the edges.
		local openingHalf = spec.openingHalfWidth or W.StreetHalfWidth
		local gateX = spec.gateX
		if gateX ~= nil then
			local townSide = if gateX > cx then 1 else -1 -- which X edge faces the town
			local farX, nearX = cx - townSide * hw, cx + townSide * hw
			wall("WallFar", farX - 0.5, cz - hd - 0.5, farX + 0.5, cz + hd + 0.5)
			wall("WallLeft", cx - hw, cz - hd - 0.5, cx + hw, cz - hd + 0.5)
			wall("WallRight", cx - hw, cz + hd - 0.5, cx + hw, cz + hd + 0.5)
			if spec.nearWall ~= false then
				wall("WallNearL", nearX - 0.5, cz - hd, nearX + 0.5, cz - openingHalf)
				wall("WallNearR", nearX - 0.5, cz + openingHalf, nearX + 0.5, cz + hd)
			end
			arrival = CFrame.lookAt(
				Vector3.new(nearX - townSide * 6, spec.floorY + 3, cz),
				Vector3.new(cx, spec.floorY + 3, cz)
			)
		else
			local streetSide = if cz > 0 then -1 else 1 -- which Z edge faces the street
			local farZ, nearZ = cz - streetSide * hd, cz + streetSide * hd
			wall("WallFar", cx - hw - 0.5, farZ - 0.5, cx + hw + 0.5, farZ + 0.5)
			wall("WallLeft", cx - hw - 0.5, cz - hd, cx - hw + 0.5, cz + hd)
			wall("WallRight", cx + hw - 0.5, cz - hd, cx + hw + 0.5, cz + hd)
			if spec.nearWall ~= false then
				wall("WallNearL", cx - hw, nearZ - 0.5, cx - openingHalf, nearZ + 0.5)
				wall("WallNearR", cx + openingHalf, nearZ - 0.5, cx + hw, nearZ + 0.5)
			end
			arrival = CFrame.lookAt(
				Vector3.new(cx, spec.floorY + 3, nearZ - streetSide * 6),
				Vector3.new(cx, spec.floorY + 3, cz)
			)
		end
		if set ~= nil and hasSet then
			-- Pivot at the area's centre on the floor's top, its gate side (-Z) turned toward the town. The wall
			-- facing the town still blocks but is hidden: the set's see-through border stands there.
			place(
				set,
				CFrame.new(cx, spec.floorY, cz)
					* CFrame.Angles(0, math.rad(Layout.gateTurn(spec)), 0),
				model
			).Name =
				"Set"
			for _, name in { "WallNearL", "WallNearR" } do
				local near = walls:FindFirstChild(name)
				if near ~= nil and near:IsA("BasePart") then
					local nearPart = near :: BasePart
					nearPart.Transparency = 1
					nearPart.CastShadow = false
				end
			end
		end
		-- Roads and paths sit 0.05 above the floor, so their tops never fight with it.
		local paths: { Layout.Rect } = if hasSet then {} else spec.paths or {}
		for n, rect in paths do
			part(
				"Path" .. n,
				Vector3.new(rect.x2 - rect.x1, 0.2, rect.z2 - rect.z1),
				CFrame.new((rect.x1 + rect.x2) / 2, 0.05, (rect.z1 + rect.z2) / 2),
				ASPHALT,
				Enum.Material.Asphalt,
				model
			)
		end
	end

	local props = folder("Props", model)
	local areaProps: { Layout.Prop } = if hasSet then {} else spec.props
	for _, prop in areaProps do
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
		local base = CFrame.new(point.x, spec.floorY + (point.y or 0), point.z)
			* CFrame.Angles(0, math.rad(point.rotY or 0), 0)
		-- A trap built into the area's set has no prop: the stuck cat sits right at the spot.
		local prop = point.prop
		local catAt = base
		if prop ~= nil then
			place(prop, base, rescueFolder).Name = name .. "_Trap"
			local pose = Layout.stuckPoses[prop]
			if pose ~= nil then
				catAt = base * poseCFrame(pose)
			end
		end
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
		floorY = spec.floorY + (if hasSet then spec.setLift or 0 else 0), -- where strays walk
		spawnPoints = spawnPoints,
		rescueSpots = rescueSpots,
		bounds = { minX = cx - hw + 2, maxX = cx + hw - 2, minZ = cz - hd + 2, maxZ = cz + hd - 2 },
		rects = rects,
		roam = spec.roam or rects,
		arrival = arrival,
		arrivalEast = arrivalEast,
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

-- The Index Boards (F50): CatCafe_<Area>_IndexBoard inside each area's entrance at Layout.indexBoards, in the
-- space of the area's gate or, for the Alleyway, of each of the Town Square's side arches (v3.1), turned as
-- buildTownSquare turns them. The model comes tagged IndexBoard with Area; the UI draws that area's Index on its
-- Screen part and adds its own hold-E prompt. It streams whole (Atomic, as cats do: reviewer S37), so the Screen
-- never arrives without its board. Skipped while an asset is missing.
local function buildIndexBoards(gates: { [string]: Model }, parent: Instance)
	for areaId, at in Layout.indexBoards do
		local pascal = areaId:sub(1, 1):upper() .. areaId:sub(2)
		local asset = "CatCafe_" .. pascal .. "_IndexBoard"
		local hosts: { CFrame } = {}
		local gate: Model? = gates[areaId]
		if gate ~= nil then
			table.insert(hosts, gate:GetPivot())
		elseif areaId == "alley" then
			for _, arch in Layout.townSquare.arches do
				local side = if arch.x < 0 then -1 else 1
				table.insert(
					hosts,
					CFrame.new(arch.x, 0.1, arch.z) * CFrame.Angles(0, math.rad(side * 90), 0)
				)
			end
		end
		if not AssetRegistry.has(asset) then
			continue
		end
		for n, host in hosts do
			local board = place(asset, localCFrame(host, at), parent)
			board.Name = pascal .. "IndexBoard" .. (if #hosts > 1 then tostring(n) else "")
			board.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
			board:SetAttribute("Area", areaId)
			CollectionService:AddTag(board, "IndexBoard")
		end
	end
end

-- The Spin Wheel station (F49) in the Town Square (Layout.spinWheel), tagged SpinWheel: SpinService measures its
-- range from the pivot and sets LastSpinAt, which turns the Wheel on every client. Its hold-E "Spin" prompt (Custom:
-- the UI's action pill) sits at the model's PromptAnchor and opens the Spin window. Persistent, so the square's
-- place marker and the prompt find it from anywhere on the street.
local function buildSpinWheel(parent: Instance): Model
	local spec = Layout.spinWheel
	local model = place(
		"CatCafe_Street_SpinWheel",
		CFrame.new(spec.x, spec.y, spec.z) * CFrame.Angles(0, math.rad(spec.rotY or 0), 0),
		parent
	)
	model.Name = "SpinWheel"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model:SetAttribute("LastSpinAt", 0)
	model:SetAttribute("LastSlice", 1)
	CollectionService:AddTag(model, "SpinWheel")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SpinPrompt"
	prompt.ActionText = "Spin"
	prompt.ObjectText = "Spin Wheel"
	prompt.HoldDuration = 0.5
	-- measured from the anchor, a few studs in front of the pivot that SpinStationRange is measured from
	prompt.MaxActivationDistance = Config.SpinStationRange - 4
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	local anchor = model:FindFirstChild("PromptAnchor", true)
	if anchor ~= nil and anchor:IsA("Attachment") then
		prompt.Parent = anchor
	else
		local found = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
		if found ~= nil then
			local float = Instance.new("Attachment")
			float.Name = "PromptAnchor"
			float.Parent = found
			float.WorldPosition = (model:GetPivot() * CFrame.new(0, 3, -2.5)).Position
			prompt.Parent = float
		end
	end
	return model
end

-- The Golden Fish Market (F53): `CatCafe_Street_FishMarket` tagged FishMarket; its prompt opens the Market window
-- on the client, and FishMarketService measures FishMarketRange from the pivot.
local function buildFishMarket(parent: Instance): Model
	local spec = Layout.fishMarket
	local model = place(
		"CatCafe_Street_FishMarket",
		CFrame.new(spec.x, spec.y, spec.z) * CFrame.Angles(0, math.rad(spec.rotY or 0), 0),
		parent
	)
	model.Name = "FishMarket"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	CollectionService:AddTag(model, "FishMarket")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MarketPrompt"
	prompt.ActionText = "Shop"
	prompt.ObjectText = "Golden Fish Market"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = Config.FishMarketRange - 4 -- from the counter's front, a few studs off the pivot
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	local anchor = model:FindFirstChild("PromptAnchor", true)
	if anchor ~= nil and anchor:IsA("Attachment") then
		prompt.Parent = anchor
	else
		local found = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
		if found ~= nil then
			local float = Instance.new("Attachment")
			float.Name = "PromptAnchor"
			float.Parent = found
			float.WorldPosition = (model:GetPivot() * CFrame.new(0, 3, -2)).Position
			prompt.Parent = float
		end
	end
	return model
end

-- The Codes Cat (F65): `CatCafe_Street_CodesCat` tagged CodesCat with its CodesCircle on the ground in front.
-- Walking into the circle opens the code box on the client (no prompt, v0.10); CodeService measures CodesCatRange
-- from the pivot. A model without a circle gets a plain one where the asset's would be.
local function buildCodesCat(parent: Instance): Model
	local spec = Layout.codesCat
	local model = place(
		"CatCafe_Street_CodesCat",
		CFrame.new(spec.x, spec.y, spec.z) * CFrame.Angles(0, math.rad(spec.rotY or 0), 0),
		parent
	)
	model.Name = "CodesCat"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	CollectionService:AddTag(model, "CodesCat")
	if model:FindFirstChild("CodesCircle", true) == nil then
		local circle = Instance.new("Part")
		circle.Name = "CodesCircle"
		circle.Shape = Enum.PartType.Cylinder
		circle.Size = Vector3.new(0.1, Config.CodesCircleRadius * 2, Config.CodesCircleRadius * 2)
		circle.CFrame = model:GetPivot()
			* CFrame.new(0, 0.05, -6)
			* CFrame.Angles(0, 0, math.rad(90))
		circle.Material = Enum.Material.Neon
		circle.Color = Color3.fromRGB(255, 214, 120)
		circle.Transparency = 0.4
		circle.Anchored = true
		circle.CanCollide = false
		circle.CanQuery = false
		circle.CanTouch = false
		circle.Parent = model
	end
	return model
end

local SQUARE_PAVING = "CatCafe_Square_Paving"

-- The Town Square (F76, Layout.townSquare): its paving and the lighter open cross, the gardens' wall along each
-- back alley with an arch in the middle into it, and the dressing Layout lists (art the AssetRegistry has, or its
-- placeholder). The stations stand in its quarters (buildSpinWheel and the rest); the square is street, so it is
-- safe (no catching area covers it).
local function buildTownSquare(parent: Instance)
	local square = folder("TownSquare", parent)
	local spec = Layout.townSquare
	local floor = spec.floor
	-- The paving art brings its own slab and stones; the plain floor and lane marks would share their planes and
	-- flicker, so they stand in only while it is missing.
	local pavingArt = AssetRegistry.known(SQUARE_PAVING)
	if not pavingArt then
		part(
			"Paving",
			Vector3.new(floor.x2 - floor.x1, 0.2, floor.z2 - floor.z1),
			CFrame.new((floor.x1 + floor.x2) / 2, 0, (floor.z1 + floor.z2) / 2),
			PATH,
			Enum.Material.Pavement,
			square
		)
	end
	for n, lane in if pavingArt then {} else spec.lanes do
		local mark = part(
			"Lane" .. n,
			Vector3.new(lane.x2 - lane.x1, 0.02, lane.z2 - lane.z1),
			CFrame.new((lane.x1 + lane.x2) / 2, 0.11, (lane.z1 + lane.z2) / 2),
			CREAM,
			Enum.Material.Pavement,
			square
		)
		mark.CanCollide = false
		mark.CanQuery = false
		mark.CanTouch = false
	end
	local wallHeight = 5
	for _, arch in spec.arches do
		local side = if arch.x < 0 then -1 else 1
		local x = arch.x
		-- the garden wall either side of the arch's opening, along the gardens' alley edge
		for _, half in { -1, 1 } do
			local near = arch.z + half * arch.span / 2
			local far = half * floor.z2
			part(
				"GardenWall",
				Vector3.new(1, wallHeight, math.abs(far - near)),
				CFrame.new(x, wallHeight / 2, (near + far) / 2),
				BRICK,
				Enum.Material.Brick,
				square
			)
		end
		-- -Z toward the square: turned a quarter so it faces +X on the west side and -X on the east
		buildArch(x, arch.z, arch.span, arch.label, arch.asset, BRICK, square, side * 90)
	end
	for _, prop in spec.props do
		if AssetRegistry.known(prop.asset) then
			place(
				prop.asset,
				CFrame.new(prop.x, prop.y or 0.1, prop.z)
					* CFrame.Angles(0, math.rad(prop.rotY or 0), 0),
				square
			).Name =
				prop.asset
		end
	end
end

-- The finger signpost by the fountain (town-layout-v3.md section 7d, Layout.townSquare.signpost), tagged
-- TownSignpost: each client draws its arms' names, icons and tier locks (ui-contract.md "Town signpost"). The art
-- when the AssetRegistry has it, placed with no turn so the arms it aims are in world space; until then a post and
-- an arm for each gated area, a board along its own X with the area's id in its Area attribute, aimed at the gate.
local SIGNPOST_ASSET = "CatCafe_Square_Signpost"
local SIGNPOST_WOOD = Color3.fromRGB(150, 105, 65)

local function buildSignpost(parent: Instance)
	local at = Layout.townSquare.signpost
	local base = CFrame.new(at.x, at.y, at.z)
	local model: Model
	if AssetRegistry.known(SIGNPOST_ASSET) then
		model = place(SIGNPOST_ASSET, base, parent)
	else
		model = Instance.new("Model")
		model.PrimaryPart = part(
			"Post",
			Vector3.new(0.6, 7, 0.6),
			base * CFrame.new(0, 3.5, 0),
			SIGNPOST_WOOD,
			Enum.Material.Wood,
			model
		)
		local height = 6.3
		for _, def in Catalog.areas do
			local gx, gz = Layout.gatePosition(Layout.areas[def.id])
			if gx == nil or gz == nil then
				continue
			end
			local from = Vector3.new(at.x, at.y + height, at.z)
			local toward = (Vector3.new(gx, from.Y, gz) - from).Unit
			local middle = from + toward * 2.55
			-- lookAt aims -Z at the gate; a quarter turn puts the board's X there instead
			local arm = part(
				"Arm_" .. def.name,
				Vector3.new(4.5, 0.9, 0.2),
				CFrame.lookAt(middle, middle + toward) * CFrame.Angles(0, math.rad(90), 0),
				PICKET,
				Enum.Material.Wood,
				model
			)
			arm.CanCollide = false
			arm:SetAttribute("Area", def.id)
			height -= 0.75
		end
	end
	model.Name = "Signpost"
	CollectionService:AddTag(model, "TownSignpost")
	model.Parent = parent
end

-- The paw paths (Layout.pawPrints): each print a pad and four toes, flat on what it lies on, in its area's colour.
local PAW_COLORS = {
	park = Color3.fromRGB(104, 196, 92), -- leaf green
	neighbourhood = Color3.fromRGB(240, 150, 64), -- warm orange
	woods = Color3.fromRGB(38, 112, 64), -- deep green
	sewer = Color3.fromRGB(86, 110, 150), -- slate blue
} :: { [string]: Color3 }
local PAW_TOES = { { -0.55, -0.5 }, { -0.2, -0.78 }, { 0.2, -0.78 }, { 0.55, -0.5 } }

-- `sets` are the area kit sets in place: a print over one sits on the set's own ground (a road, the Sewer's tiles)
-- when that stands up to PAW_LIFT above the floor Layout gave it, never on a canopy or a roof higher up.
local PAW_LIFT = 1.5
local function buildPawPaths(parent: Instance, sets: { Instance })
	local paths = folder("PawPaths", parent)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = sets
	for _, paw in Layout.pawPrints() do
		local color = PAW_COLORS[paw.area] or CREAM
		local y = paw.y
		if #sets > 0 then
			local hit = Workspace:Raycast(
				Vector3.new(paw.x, paw.y + PAW_LIFT, paw.z),
				Vector3.new(0, -PAW_LIFT - 0.1, 0),
				params
			)
			if hit ~= nil and hit.Position.Y > y then
				y = hit.Position.Y
			end
		end
		local at = CFrame.new(paw.x, y + 0.015, paw.z) * CFrame.Angles(0, math.rad(paw.rotY), 0)
		local function pad(name: string, diameter: number, x: number, z: number)
			-- a cylinder's axis is its X: a quarter turn about Z lays it flat
			local p = part(
				name,
				Vector3.new(0.03, diameter, diameter),
				at * CFrame.new(x, 0, z) * CFrame.Angles(0, 0, math.rad(90)),
				color,
				Enum.Material.SmoothPlastic,
				paths
			)
			p.Shape = Enum.PartType.Cylinder
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
		end
		pad("PawPad", 0.95, 0, 0)
		for _, toe in PAW_TOES do
			pad("PawToe", 0.38, toe[1], toe[2])
		end
	end
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
	-- The street runs from the Park gate to the Neighbourhood gate, in two halves either side of the Town Square,
	-- which paves the middle.
	for _, half in { -1, 1 } do
		local from = half * W.TownSquareHalfDepth
		local to = if half < 0 then W.StreetSouthZ else W.StreetNorthZ
		local length = math.abs(to - from)
		local midZ = (from + to) / 2
		part(
			"Street",
			Vector3.new(W.StreetHalfWidth * 2, 0.2, length),
			CFrame.new(0, 0, midZ),
			ASPHALT,
			Enum.Material.Asphalt,
			root
		)
		for _, x in { -W.StreetHalfWidth - 1, W.StreetHalfWidth + 1 } do
			part(
				"Sidewalk",
				Vector3.new(2, 0.3, length),
				CFrame.new(x, 0.05, midZ),
				Color3.fromRGB(200, 200, 195),
				Enum.Material.Concrete,
				root
			)
		end
	end
	buildTownSquare(root)
	buildSignpost(root)

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
		-- The gate's front (-Z, its sign) faces the way players come from (alley kit notes, reviewer N68).
		local gateX, gateZ = Layout.gatePosition(spec)
		if gateX ~= nil and gateZ ~= nil then
			gates[def.id] =
				buildGate(def, gateX, gateZ, math.rad(Layout.gateTurn(spec)), gatesFolder)
		end
	end
	-- after the areas, so the prints inside them sit on the sets' ground
	local sets: { Instance } = {}
	for _, info in areas do
		local set = info.model:FindFirstChild("Set")
		if set ~= nil then
			table.insert(sets, set)
		end
	end
	buildPawPaths(root, sets)
	buildIndexBoards(gates, folder("IndexBoards", root))
	if not buildNightFences(gates, plots, folder("NightFences", root)) then
		buildAlleyNightFence(gatesFolder)
	end
	buildSafeZoneMarks(root)
	buildSpinWheel(root)
	buildFishMarket(root)
	buildCodesCat(root)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlayerSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(Layout.playerSpawn.x, Layout.playerSpawn.y, Layout.playerSpawn.z)
		* CFrame.Angles(0, math.rad(Layout.playerSpawn.rotY or 0), 0)
	spawn.Anchored = true
	-- Invisible and walk-through (Derek 2026-10-28 00:48: the pad in the square need not be there): players still
	-- spawn on it and drop the stud onto the paving.
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.CanTouch = false
	spawn.CastShadow = false
	spawn.Duration = 0
	spawn.Parent = root

	return { folder = root, plots = plots, areas = areas, gates = gates }
end

return WorldBuilder
