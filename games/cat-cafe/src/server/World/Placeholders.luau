--!strict
-- Builds placeholder Models out of Parts, one per asset name in features.md section 5.
-- Every placeholder uses the final name, PrimaryPart and pivot (base centre, front facing -Z) so the
-- asset thread's real models replace them by name with no code change. Each carries attribute Placeholder = true.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

local Placeholders = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function hexColor(hex: string): Color3
	local r = tonumber(hex:sub(2, 3), 16) or 255
	local g = tonumber(hex:sub(4, 5), 16) or 255
	local b = tonumber(hex:sub(6, 7), 16) or 255
	return Color3.fromRGB(r, g, b)
end

type PartSpec = {
	name: string,
	size: Vector3,
	offset: Vector3, -- centre relative to the model pivot (base centre)
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?,
	rotation: Vector3?, -- degrees
	transparency: number?,
	collide: boolean?,
}

local function addPart(model: Model, spec: PartSpec): Part
	local part = Instance.new("Part")
	part.Name = spec.name
	part.Size = spec.size
	part.Color = spec.color
	part.Material = spec.material or Enum.Material.SmoothPlastic
	part.Shape = spec.shape or Enum.PartType.Block
	part.Anchored = true
	part.CanCollide = spec.collide == true
	part.CanTouch = false
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Transparency = spec.transparency or 0
	local rot = spec.rotation or Vector3.zero
	part.CFrame = CFrame.new(spec.offset)
		* CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
	part.Parent = model
	return part
end

local function newModel(name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("Placeholder", true)
	return model
end

-- Every part was placed around the model origin, which is the base centre. A Model with a PrimaryPart takes its
-- pivot from that part and ignores WorldPivot, so the origin goes on the part's PivotOffset; without it the pivot sat
-- at the part's middle and every placeholder (strays, rescue stand-ins) stood that far into the floor (laptop
-- Studio run 2026-10-27: placeholder strays 0.85 deep, the drainpipe 4.15).
local function finish(model: Model, primary: BasePart): Model
	model.PrimaryPart = primary
	primary.PivotOffset = primary.CFrame:Inverse()
	return model
end

local WOOD = Color3.fromRGB(176, 120, 70)
local CREAM = Color3.fromRGB(246, 236, 214)
local MINT = Color3.fromRGB(165, 214, 190)
local DARK = Color3.fromRGB(60, 60, 65)
local METAL = Color3.fromRGB(190, 195, 200)
local GREEN = Color3.fromRGB(90, 160, 80)
-- Palette swatches the night parts use (style guide sections 2 and 9). These placeholders are built in their
-- day look; WorldController switches the parts named _Bulb, _Bulbs, _Pane and _Tube at night.
local LAMP_WARM = Color3.fromRGB(255, 217, 168)
local NEON_PINK = Color3.fromRGB(255, 107, 129)
local GLASS = Color3.fromRGB(207, 233, 227)

function Placeholders.cat(def: Types.CatDef): Model
	local model = newModel(Catalog.catModelName(def.id))
	local fur = rgb(def.color)
	local body = addPart(model, {
		name = "Body",
		size = Vector3.new(1, 1.1, 2.2),
		offset = Vector3.new(0, 0.85, 0.2),
		color = fur,
	})
	addPart(model, {
		name = "Head",
		size = Vector3.new(0.9, 0.9, 0.9),
		offset = Vector3.new(0, 1.2, -1.25),
		color = fur,
	})
	addPart(model, {
		name = "EarL",
		size = Vector3.new(0.25, 0.3, 0.15),
		offset = Vector3.new(-0.3, 1.75, -1.3),
		color = fur,
	})
	addPart(model, {
		name = "EarR",
		size = Vector3.new(0.25, 0.3, 0.15),
		offset = Vector3.new(0.3, 1.75, -1.3),
		color = fur,
	})
	addPart(model, {
		name = "Tail",
		size = Vector3.new(0.18, 0.18, 1.0),
		offset = Vector3.new(0, 1.15, 1.6),
		color = fur,
		rotation = Vector3.new(-35, 0, 0),
	})
	for i, x in { -0.3, 0.3 } do
		addPart(model, {
			name = "LegF" .. i,
			size = Vector3.new(0.25, 0.35, 0.25),
			offset = Vector3.new(x, 0.18, -0.6),
			color = fur,
		})
		addPart(model, {
			name = "LegB" .. i,
			size = Vector3.new(0.25, 0.35, 0.25),
			offset = Vector3.new(x, 0.18, 0.9),
			color = fur,
		})
	end
	local eyeColor = if def.rarity == "Legendary"
		then Color3.fromRGB(255, 190, 60)
		else Color3.fromRGB(20, 20, 20)
	local eyeMaterial = if def.rarity == "Legendary"
		then Enum.Material.Neon
		else Enum.Material.SmoothPlastic
	for i, x in { -0.22, 0.22 } do
		addPart(model, {
			name = "Eye" .. i,
			size = Vector3.new(0.14, 0.14, 0.06),
			offset = Vector3.new(x, 1.28, -1.72),
			color = eyeColor,
			material = eyeMaterial,
		})
	end
	-- Pattern hint so placeholders are telling apart at a glance
	if def.pattern == "stripes" or def.pattern == "spots" or def.pattern == "patches" then
		addPart(model, {
			name = "Marking",
			size = Vector3.new(1.02, 0.25, 0.5),
			offset = Vector3.new(0, 1.0, 0.2),
			color = fur:Lerp(Color3.new(0, 0, 0), 0.35),
		})
	elseif def.pattern == "points" then
		addPart(model, {
			name = "Marking",
			size = Vector3.new(0.92, 0.3, 0.92),
			offset = Vector3.new(0, 1.0, -1.25),
			color = fur:Lerp(Color3.new(0, 0, 0), 0.45),
		})
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameTag"
	billboard.Size = UDim2.fromOffset(120, 28)
	billboard.StudsOffset = Vector3.new(0, 1.6, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 60
	billboard.Adornee = body
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextStrokeTransparency = 0.4
	label.TextColor3 = hexColor(Catalog.rarities[def.rarity].color)
	label.Text = def.name
	label.Parent = billboard
	billboard.Parent = body
	return finish(model, body)
end

function Placeholders.customer(variant: string): Model
	local shirts = {
		A = Color3.fromRGB(90, 140, 220),
		B = Color3.fromRGB(230, 140, 90),
		C = Color3.fromRGB(120, 190, 120),
	}
	local model = newModel("CatCafe_NPC_Customer_" .. variant)
	local skin = Color3.fromRGB(235, 200, 170)
	local legs = addPart(model, {
		name = "Legs",
		size = Vector3.new(1.6, 2, 0.9),
		offset = Vector3.new(0, 1, 0),
		color = DARK,
	})
	addPart(model, {
		name = "Torso",
		size = Vector3.new(2, 1.9, 1),
		offset = Vector3.new(0, 2.95, 0),
		color = shirts[variant] or shirts.A,
	})
	addPart(model, {
		name = "Head",
		size = Vector3.new(1.3, 1.3, 1.3),
		offset = Vector3.new(0, 4.55, 0),
		color = skin,
	})
	return finish(model, legs)
end

local function simple(name: string, parts: { PartSpec }): Model
	local model = newModel(name)
	local primary: BasePart? = nil
	for _, spec in parts do
		local part = addPart(model, spec)
		if primary == nil then
			primary = part
		end
	end
	return finish(model, primary :: BasePart)
end

-- An area gate across an opening `width` studs wide: see-through Bars (the part that blocks) under an Arch.
local function gate(name: string, color: Color3, width: number): Model
	return simple(name, {
		{
			name = "Bars",
			size = Vector3.new(width, 5, 0.5),
			offset = Vector3.new(0, 2.5, 0),
			color = color,
			material = Enum.Material.Metal,
			transparency = 0.35,
			collide = true,
		},
		{
			name = "Arch",
			size = Vector3.new(width + 2, 0.8, 1),
			offset = Vector3.new(0, 5.4, 0),
			color = color,
			material = Enum.Material.Metal,
		},
	})
end

-- The net per level (asset round 2): the pivot is the grip and the pole runs forward (-Z), longer each level.
local function net(level: number): Model
	local name = "CatCafe_Item_Net_L" .. level
	local length = 3.6 + 0.6 * level
	local hoop = 1.1 + 0.2 * level
	return simple(name, {
		{
			name = name .. "_Handle",
			size = Vector3.new(0.15, 0.15, length),
			offset = Vector3.new(0, 0, -length / 2),
			color = WOOD,
			material = Enum.Material.Wood,
		},
		{
			name = name .. "_Bag",
			size = Vector3.new(0.1, hoop, hoop),
			offset = Vector3.new(0, -hoop / 2, -length - hoop / 2),
			color = Color3.fromRGB(235, 235, 225),
			material = Enum.Material.Fabric,
			shape = Enum.PartType.Cylinder,
			rotation = Vector3.new(0, 90, 0),
			transparency = 0.35,
		},
	})
end

-- Builders for everything that is not a cat or a customer, keyed by asset name.
local builders: { [string]: () -> Model } = {
	CatCafe_Furniture_Counter = function()
		return simple("CatCafe_Furniture_Counter", {
			{
				name = "Base",
				size = Vector3.new(8, 2.8, 3),
				offset = Vector3.new(0, 1.4, 0),
				color = WOOD,
				material = Enum.Material.Wood,
				collide = true,
			},
			{
				name = "Top",
				size = Vector3.new(8.4, 0.3, 3.4),
				offset = Vector3.new(0, 2.95, 0),
				color = CREAM,
				material = Enum.Material.Marble,
				collide = true,
			},
		})
	end,
	CatCafe_Furniture_EspressoMachine_L1 = function()
		return simple("CatCafe_Furniture_EspressoMachine_L1", {
			{
				name = "Body",
				size = Vector3.new(1.5, 1.5, 1.2),
				offset = Vector3.new(0, 0.75, 0),
				color = METAL,
				material = Enum.Material.Metal,
			},
			{
				name = "Spout",
				size = Vector3.new(0.3, 0.3, 0.6),
				offset = Vector3.new(0, 0.6, -0.8),
				color = DARK,
			},
		})
	end,
	CatCafe_Furniture_EspressoMachine_L2 = function()
		return simple("CatCafe_Furniture_EspressoMachine_L2", {
			{
				name = "Body",
				size = Vector3.new(1.8, 1.7, 1.3),
				offset = Vector3.new(0, 0.85, 0),
				color = METAL,
				material = Enum.Material.Metal,
			},
			{
				name = "Trim",
				size = Vector3.new(1.9, 0.2, 1.4),
				offset = Vector3.new(0, 1.8, 0),
				color = Color3.fromRGB(230, 200, 120),
				material = Enum.Material.Metal,
			},
			{
				name = "Spout",
				size = Vector3.new(0.3, 0.3, 0.6),
				offset = Vector3.new(0, 0.6, -0.9),
				color = DARK,
			},
		})
	end,
	CatCafe_Furniture_EspressoMachine_L3 = function()
		return simple("CatCafe_Furniture_EspressoMachine_L3", {
			{
				name = "Body",
				size = Vector3.new(2.4, 1.9, 1.4),
				offset = Vector3.new(0, 0.95, 0),
				color = METAL,
				material = Enum.Material.Metal,
			},
			{
				name = "Trim",
				size = Vector3.new(2.5, 0.2, 1.5),
				offset = Vector3.new(0, 2.0, 0),
				color = Color3.fromRGB(230, 200, 120),
				material = Enum.Material.Metal,
			},
			{
				name = "BoilerL",
				size = Vector3.new(0.6, 0.6, 0.6),
				offset = Vector3.new(-0.7, 2.4, 0),
				color = Color3.fromRGB(200, 60, 60),
				material = Enum.Material.Metal,
				shape = Enum.PartType.Ball,
			},
			{
				name = "BoilerR",
				size = Vector3.new(0.6, 0.6, 0.6),
				offset = Vector3.new(0.7, 2.4, 0),
				color = Color3.fromRGB(200, 60, 60),
				material = Enum.Material.Metal,
				shape = Enum.PartType.Ball,
			},
			{
				name = "SpoutL",
				size = Vector3.new(0.3, 0.3, 0.6),
				offset = Vector3.new(-0.5, 0.6, -1.0),
				color = DARK,
			},
			{
				name = "SpoutR",
				size = Vector3.new(0.3, 0.3, 0.6),
				offset = Vector3.new(0.5, 0.6, -1.0),
				color = DARK,
			},
		})
	end,
	CatCafe_Furniture_Cushion = function()
		return simple("CatCafe_Furniture_Cushion", {
			{
				name = "Cushion",
				size = Vector3.new(0.5, 2.2, 2.2),
				offset = Vector3.new(0, 0.25, 0),
				color = Color3.fromRGB(240, 150, 170),
				material = Enum.Material.Fabric,
				shape = Enum.PartType.Cylinder,
				rotation = Vector3.new(0, 0, 90),
			},
		})
	end,
	CatCafe_Furniture_WallShelf = function()
		return simple("CatCafe_Furniture_WallShelf", {
			{
				name = "Plank",
				size = Vector3.new(3, 0.3, 1.2),
				offset = Vector3.new(0, 0.15, 0),
				color = WOOD,
				material = Enum.Material.Wood,
			},
			{
				name = "BracketL",
				size = Vector3.new(0.2, 0.8, 1.0),
				offset = Vector3.new(-1.2, -0.4, 0.1),
				color = DARK,
			},
			{
				name = "BracketR",
				size = Vector3.new(0.2, 0.8, 1.0),
				offset = Vector3.new(1.2, -0.4, 0.1),
				color = DARK,
			},
		})
	end,
	CatCafe_Furniture_CatTree = function()
		return simple("CatCafe_Furniture_CatTree", {
			{
				name = "Base",
				size = Vector3.new(2.5, 0.3, 2.5),
				offset = Vector3.new(0, 0.15, 0),
				color = CREAM,
				material = Enum.Material.Fabric,
				collide = true,
			},
			{
				name = "Post",
				size = Vector3.new(0.6, 4.2, 0.6),
				offset = Vector3.new(0, 2.4, 0),
				color = Color3.fromRGB(200, 180, 140),
				material = Enum.Material.Fabric,
				collide = true,
			},
			{
				name = "Platform",
				size = Vector3.new(2.2, 0.3, 2.2),
				offset = Vector3.new(0, 4.5, 0),
				color = CREAM,
				material = Enum.Material.Fabric,
				collide = true,
			},
		})
	end,
	CatCafe_Furniture_WindowSeat = function()
		return simple("CatCafe_Furniture_WindowSeat", {
			{
				name = "Seat",
				size = Vector3.new(3, 1.4, 1.2),
				offset = Vector3.new(0, 0.7, 0),
				color = CREAM,
				material = Enum.Material.Fabric,
				collide = true,
			},
		})
	end,
	CatCafe_Furniture_PatioBench = function()
		return simple("CatCafe_Furniture_PatioBench", {
			{
				name = "Seat",
				size = Vector3.new(4, 0.3, 1.4),
				offset = Vector3.new(0, 1.35, 0),
				color = WOOD,
				material = Enum.Material.Wood,
				collide = true,
			},
			{
				name = "LegL",
				size = Vector3.new(0.3, 1.2, 1.2),
				offset = Vector3.new(-1.6, 0.6, 0),
				color = DARK,
				collide = true,
			},
			{
				name = "LegR",
				size = Vector3.new(0.3, 1.2, 1.2),
				offset = Vector3.new(1.6, 0.6, 0),
				color = DARK,
				collide = true,
			},
		})
	end,
	CatCafe_Furniture_TableRound = function()
		return simple("CatCafe_Furniture_TableRound", {
			{
				name = "Top",
				size = Vector3.new(0.3, 3.5, 3.5),
				offset = Vector3.new(0, 2.45, 0),
				color = WOOD,
				material = Enum.Material.Wood,
				shape = Enum.PartType.Cylinder,
				rotation = Vector3.new(0, 0, 90),
				collide = true,
			},
			{
				name = "Post",
				size = Vector3.new(0.4, 2.3, 0.4),
				offset = Vector3.new(0, 1.15, 0),
				color = DARK,
				collide = true,
			},
			{
				name = "Foot",
				size = Vector3.new(0.2, 1.6, 1.6),
				offset = Vector3.new(0, 0.1, 0),
				color = DARK,
				shape = Enum.PartType.Cylinder,
				rotation = Vector3.new(0, 0, 90),
			},
		})
	end,
	CatCafe_Furniture_Chair = function()
		return simple("CatCafe_Furniture_Chair", {
			{
				name = "Seat",
				size = Vector3.new(1.5, 0.3, 1.5),
				offset = Vector3.new(0, 1.4, 0),
				color = MINT,
				material = Enum.Material.Wood,
			},
			{
				name = "Back",
				size = Vector3.new(1.5, 1.6, 0.3),
				offset = Vector3.new(0, 2.2, 0.6),
				color = MINT,
				material = Enum.Material.Wood,
			},
			{
				name = "Legs",
				size = Vector3.new(1.2, 1.3, 1.2),
				offset = Vector3.new(0, 0.65, 0),
				color = DARK,
			},
		})
	end,
	CatCafe_Decor_WindowPlants = function()
		return simple("CatCafe_Decor_WindowPlants", {
			{
				name = "Pot",
				size = Vector3.new(3, 0.8, 1),
				offset = Vector3.new(0, 0.4, 0),
				color = Color3.fromRGB(190, 110, 80),
			},
			{
				name = "Leaves",
				size = Vector3.new(2.8, 1.2, 0.9),
				offset = Vector3.new(0, 1.4, 0),
				color = GREEN,
				material = Enum.Material.Grass,
			},
		})
	end,
	CatCafe_Decor_Rug = function()
		return simple("CatCafe_Decor_Rug", {
			{
				name = "Rug",
				size = Vector3.new(8, 0.1, 6),
				offset = Vector3.new(0, 0.05, 0),
				color = Color3.fromRGB(200, 90, 90),
				material = Enum.Material.Fabric,
			},
		})
	end,
	CatCafe_Decor_NeonSign = function()
		return simple("CatCafe_Decor_NeonSign", {
			{
				name = "CatCafe_Decor_NeonSign_Board",
				size = Vector3.new(5, 2, 0.2),
				offset = Vector3.new(0, 1, 0),
				color = DARK,
			},
			{
				name = "CatCafe_Decor_NeonSign_Tube",
				size = Vector3.new(4.2, 1.2, 0.15),
				offset = Vector3.new(0, 1, -0.15),
				color = NEON_PINK,
			},
		})
	end,
	CatCafe_Decor_FishTank = function()
		return simple("CatCafe_Decor_FishTank", {
			{
				name = "Stand",
				size = Vector3.new(3.2, 2, 1.4),
				offset = Vector3.new(0, 1, 0),
				color = DARK,
				collide = true,
			},
			{
				name = "Glass",
				size = Vector3.new(3, 2, 1.2),
				offset = Vector3.new(0, 3, 0),
				color = Color3.fromRGB(120, 190, 240),
				material = Enum.Material.Glass,
				transparency = 0.5,
			},
		})
	end,
	CatCafe_Alley_Dumpster = function()
		return simple("CatCafe_Alley_Dumpster", {
			{
				name = "Body",
				size = Vector3.new(6, 3.5, 4),
				offset = Vector3.new(0, 1.75, 0),
				color = Color3.fromRGB(70, 110, 80),
				material = Enum.Material.Metal,
				collide = true,
			},
			{
				name = "Lid",
				size = Vector3.new(6.2, 0.3, 4.2),
				offset = Vector3.new(0, 3.6, 0),
				color = Color3.fromRGB(50, 80, 60),
				material = Enum.Material.Metal,
				collide = true,
			},
		})
	end,
	CatCafe_Alley_TrashCan = function()
		return simple("CatCafe_Alley_TrashCan", {
			{
				name = "Can",
				size = Vector3.new(2.4, 1.6, 1.6),
				offset = Vector3.new(0, 1.2, 0),
				color = METAL,
				material = Enum.Material.DiamondPlate,
				shape = Enum.PartType.Cylinder,
				rotation = Vector3.new(0, 0, 90),
				collide = true,
			},
		})
	end,
	CatCafe_Alley_StreetLamp = function()
		local model = simple("CatCafe_Alley_StreetLamp", {
			{
				name = "Post",
				size = Vector3.new(0.4, 9, 0.4),
				offset = Vector3.new(0, 4.5, 0),
				color = DARK,
				material = Enum.Material.Metal,
				collide = true,
			},
			{
				name = "CatCafe_Alley_StreetLamp_Bulb",
				size = Vector3.new(1.2, 0.8, 1.2),
				offset = Vector3.new(0, 9.2, 0),
				color = LAMP_WARM,
			},
		})
		return model
	end,
	-- Wall-mounted: the pivot is the bottom of the back face, the window faces -Z.
	CatCafe_Alley_ShopWindow = function()
		return simple("CatCafe_Alley_ShopWindow", {
			{
				name = "CatCafe_Alley_ShopWindow_Frame",
				size = Vector3.new(4.8, 3.7, 0.3),
				offset = Vector3.new(0, 1.85, -0.15),
				color = Color3.fromRGB(94, 70, 52),
				material = Enum.Material.Wood,
			},
			{
				name = "CatCafe_Alley_ShopWindow_Pane",
				size = Vector3.new(4.2, 3.1, 0.1),
				offset = Vector3.new(0, 1.85, -0.35),
				color = GLASS,
				material = Enum.Material.Glass,
				transparency = 0.5,
			},
		})
	end,
	-- The pivot is the strand's left end; it runs +X and the bulbs hang below it.
	CatCafe_Decor_StringLights = function()
		local parts: { PartSpec } = {
			{
				name = "CatCafe_Decor_StringLights_Wire",
				size = Vector3.new(8, 0.08, 0.08),
				offset = Vector3.new(4, -0.3, 0),
				color = DARK,
			},
		}
		for i = 1, 8 do
			table.insert(parts, {
				name = "CatCafe_Decor_StringLights_Bulbs",
				size = Vector3.new(0.3, 0.4, 0.3),
				offset = Vector3.new(i - 0.5, -0.55 - 0.15 * math.sin(math.pi * (i - 0.5) / 8), 0),
				color = LAMP_WARM,
			})
		end
		return simple("CatCafe_Decor_StringLights", parts)
	end,
	CatCafe_Alley_Crate = function()
		return simple("CatCafe_Alley_Crate", {
			{
				name = "Crate",
				size = Vector3.new(2.5, 2.5, 2.5),
				offset = Vector3.new(0, 1.25, 0),
				color = WOOD,
				material = Enum.Material.WoodPlanks,
				collide = true,
			},
		})
	end,
	CatCafe_Park_Bench = function()
		return simple("CatCafe_Park_Bench", {
			{
				name = "Seat",
				size = Vector3.new(4, 0.3, 1.4),
				offset = Vector3.new(0, 1.35, 0),
				color = WOOD,
				material = Enum.Material.Wood,
				collide = true,
			},
			{
				name = "Back",
				size = Vector3.new(4, 1.2, 0.2),
				offset = Vector3.new(0, 2.1, 0.6),
				color = WOOD,
				material = Enum.Material.Wood,
			},
			{
				name = "Legs",
				size = Vector3.new(3.4, 1.2, 1.0),
				offset = Vector3.new(0, 0.6, 0),
				color = DARK,
				collide = true,
			},
		})
	end,
	CatCafe_Park_Tree = function()
		return simple("CatCafe_Park_Tree", {
			{
				name = "Trunk",
				size = Vector3.new(1, 5, 1),
				offset = Vector3.new(0, 2.5, 0),
				color = Color3.fromRGB(110, 75, 45),
				material = Enum.Material.Wood,
				collide = true,
			},
			{
				name = "Leaves",
				size = Vector3.new(6, 6, 6),
				offset = Vector3.new(0, 7, 0),
				color = GREEN,
				material = Enum.Material.Grass,
				shape = Enum.PartType.Ball,
			},
		})
	end,
	CatCafe_Park_Fountain = function()
		return simple("CatCafe_Park_Fountain", {
			{
				name = "Basin",
				size = Vector3.new(1, 7, 7),
				offset = Vector3.new(0, 0.5, 0),
				color = Color3.fromRGB(200, 200, 205),
				material = Enum.Material.Concrete,
				shape = Enum.PartType.Cylinder,
				rotation = Vector3.new(0, 0, 90),
				collide = true,
			},
			{
				name = "Water",
				size = Vector3.new(0.2, 6.2, 6.2),
				offset = Vector3.new(0, 1.05, 0),
				color = Color3.fromRGB(100, 170, 230),
				material = Enum.Material.Glass,
				shape = Enum.PartType.Cylinder,
				rotation = Vector3.new(0, 0, 90),
				transparency = 0.3,
			},
			{
				name = "Spout",
				size = Vector3.new(0.8, 3, 0.8),
				offset = Vector3.new(0, 2.5, 0),
				color = Color3.fromRGB(200, 200, 205),
				material = Enum.Material.Concrete,
			},
		})
	end,
	-- The Town Square's fountain (F76): a low rim players can sit on, radius 6, and a cat statue on a plinth.
	CatCafe_Square_Fountain = function()
		local stone = Color3.fromRGB(214, 206, 196)
		return simple("CatCafe_Square_Fountain", {
			{
				name = "Rim",
				size = Vector3.new(1.5, 12, 12),
				offset = Vector3.new(0, 0.75, 0),
				color = stone,
				material = Enum.Material.Concrete,
				shape = Enum.PartType.Cylinder,
				rotation = Vector3.new(0, 0, 90),
				collide = true,
			},
			{
				name = "Water",
				size = Vector3.new(0.2, 10.8, 10.8),
				offset = Vector3.new(0, 1.35, 0),
				color = Color3.fromRGB(100, 170, 230),
				material = Enum.Material.Glass,
				shape = Enum.PartType.Cylinder,
				rotation = Vector3.new(0, 0, 90),
				transparency = 0.3,
			},
			{
				name = "Plinth",
				size = Vector3.new(2.4, 3, 2.4),
				offset = Vector3.new(0, 1.5, 0),
				color = stone,
				material = Enum.Material.Concrete,
				collide = true,
			},
			{
				name = "StatueBody",
				size = Vector3.new(1.6, 1.8, 2.2),
				offset = Vector3.new(0, 3.9, 0),
				color = stone,
				material = Enum.Material.Marble,
			},
			{
				name = "StatueHead",
				size = Vector3.new(1.4, 1.4, 1.4),
				offset = Vector3.new(0, 5.3, -0.6),
				color = stone,
				material = Enum.Material.Marble,
				shape = Enum.PartType.Ball,
			},
		})
	end,
	CatCafe_Park_Gate = function()
		return gate("CatCafe_Park_Gate", DARK, Config.World.StreetHalfWidth * 2)
	end,
	CatCafe_Neighbourhood_Gate = function()
		return gate(
			"CatCafe_Neighbourhood_Gate",
			Color3.fromRGB(150, 110, 80),
			Config.World.StreetHalfWidth * 2
		)
	end,
	CatCafe_Woods_Gate = function()
		return gate("CatCafe_Woods_Gate", Color3.fromRGB(70, 55, 40), 30)
	end,
	CatCafe_Sewer_Gate = function()
		return gate("CatCafe_Sewer_Gate", Color3.fromRGB(60, 75, 70), 30)
	end,
	-- The Spin Wheel station (F49, areas-and-stations B3) until the art is synced: a striped booth, a six-slice
	-- wheel facing -Z on two posts, a paw pointer on top and rim lights. Wheel is a Model pivoted at the hub that
	-- turns about its own Z axis, with its Face inside; PromptAnchor sits at the front, 3 studs up. At rest slice 1 is
	-- under the pointer and the rest follow clockwise seen from the front (toward -X), in Catalog.spinWheel order.
	CatCafe_Street_SpinWheel = function()
		local model = newModel("CatCafe_Street_SpinWheel")
		local booth = addPart(model, {
			name = "Booth",
			size = Vector3.new(7, 3, 4),
			offset = Vector3.new(0, 1.5, 0),
			color = CREAM,
			collide = true,
		})
		local anchor = Instance.new("Attachment")
		anchor.Name = "PromptAnchor"
		anchor.Position = Vector3.new(0, 1.5, -2.3) -- relative to the booth's centre: the front, 3 studs up
		anchor.Parent = booth
		for _, x in { -2.6, 2.6 } do
			addPart(model, {
				name = "Post",
				size = Vector3.new(0.6, 5, 0.6),
				offset = Vector3.new(x, 5.5, 0.6),
				color = WOOD,
				collide = true,
			})
		end
		local hub = Vector3.new(0, 7.6, 0)
		local wheel = Instance.new("Model")
		wheel.Name = "Wheel"
		local disc = addPart(model, {
			name = "Disc",
			size = Vector3.new(0.5, 8, 8),
			offset = hub,
			rotation = Vector3.new(0, 90, 0),
			color = CREAM,
		})
		disc.Parent = wheel
		local face = addPart(model, {
			name = "Face",
			size = Vector3.new(0.1, 7.6, 7.6),
			offset = hub + Vector3.new(0, 0, -0.3),
			rotation = Vector3.new(0, 90, 0),
			color = CREAM,
		})
		face.Parent = wheel
		local sliceColors =
			{ MINT, LAMP_WARM, NEON_PINK, GLASS, Color3.fromRGB(200, 170, 230), WOOD }
		for index, color in sliceColors do
			local angle = (index - 1) * 60
			local slice = addPart(model, {
				name = "Slice" .. index,
				size = Vector3.new(1.4, 3.4, 0.12),
				offset = hub + Vector3.new(
					-math.sin(math.rad(angle)) * 1.9,
					math.cos(math.rad(angle)) * 1.9,
					-0.4
				),
				rotation = Vector3.new(0, 0, angle),
				color = color,
			})
			slice.Parent = wheel
		end
		-- A Model with a PrimaryPart takes its pivot from that part, so the hub pivot goes on the Disc: axis-aligned
		-- at the hub, its Z along the axle (VFX-Agent: WorldPivot left the pivot turned with the Disc, and the turn
		-- about its Z flipped the wheel over in the intro).
		wheel.PrimaryPart = disc
		disc.PivotOffset = disc.CFrame:Inverse() * CFrame.new(hub)
		wheel.Parent = model
		addPart(model, {
			name = "Pointer",
			size = Vector3.new(0.9, 1.1, 0.4),
			offset = hub + Vector3.new(0, 4.4, -0.5),
			color = NEON_PINK,
		})
		for index = 1, 8 do
			local angle = math.rad((index - 1) * 45 + 22.5)
			addPart(model, {
				name = "RimLight",
				size = Vector3.new(0.35, 0.35, 0.35),
				offset = hub + Vector3.new(math.sin(angle) * 4.35, math.cos(angle) * 4.35, 0),
				color = LAMP_WARM,
				material = Enum.Material.Neon,
				shape = Enum.PartType.Ball,
			})
		end
		return finish(model, booth)
	end,
	-- Stand-ins for the night dealer's cart and the dealer (section 8b) until the art is synced.
	CatCafe_Street_DealerCart = function()
		return simple("CatCafe_Street_DealerCart", {
			{
				name = "Cart",
				size = Vector3.new(6, 2.4, 3),
				offset = Vector3.new(0, 1.6, 0),
				color = Color3.fromRGB(95, 75, 130),
				material = Enum.Material.Wood,
			},
			{
				name = "Awning",
				size = Vector3.new(6.6, 0.3, 3.8),
				offset = Vector3.new(0, 5.5, 0),
				color = Color3.fromRGB(240, 205, 110),
			},
		})
	end,
	CatCafe_NPC_Dealer = function()
		return simple("CatCafe_NPC_Dealer", {
			{
				name = "Body",
				size = Vector3.new(2, 5, 1.2),
				offset = Vector3.new(0, 2.5, 0),
				color = Color3.fromRGB(70, 60, 110),
			},
		})
	end,
	CatCafe_Item_FoodBowl = function()
		return simple("CatCafe_Item_FoodBowl", {
			{
				name = "Bowl",
				size = Vector3.new(0.4, 1.2, 1.2),
				offset = Vector3.new(0, 0.2, 0),
				color = Color3.fromRGB(230, 230, 235),
				shape = Enum.PartType.Cylinder,
				rotation = Vector3.new(0, 0, 90),
			},
			{
				name = "Food",
				size = Vector3.new(0.15, 0.9, 0.9),
				offset = Vector3.new(0, 0.45, 0),
				color = Color3.fromRGB(200, 140, 80),
				shape = Enum.PartType.Cylinder,
				rotation = Vector3.new(0, 0, 90),
			},
		})
	end,
	CatCafe_Item_FoodBowl_Premium = function()
		return simple("CatCafe_Item_FoodBowl_Premium", {
			{
				name = "Bowl",
				size = Vector3.new(0.4, 1.2, 1.2),
				offset = Vector3.new(0, 0.2, 0),
				color = Color3.fromRGB(255, 200, 80),
				material = Enum.Material.Metal,
				shape = Enum.PartType.Cylinder,
				rotation = Vector3.new(0, 0, 90),
			},
			{
				name = "Food",
				size = Vector3.new(0.15, 0.9, 0.9),
				offset = Vector3.new(0, 0.45, 0),
				color = Color3.fromRGB(240, 120, 110),
				shape = Enum.PartType.Cylinder,
				rotation = Vector3.new(0, 0, 90),
			},
		})
	end,
	CatCafe_Item_Kibble = function()
		return simple("CatCafe_Item_Kibble", {
			{
				name = "Pile",
				size = Vector3.new(0.9, 0.3, 0.9),
				offset = Vector3.new(0, 0.5, 0),
				color = Color3.fromRGB(190, 130, 70),
				material = Enum.Material.Pebble,
			},
		})
	end,
	CatCafe_Item_TunaCan = function()
		return simple("CatCafe_Item_TunaCan", {
			{
				name = "Can",
				size = Vector3.new(0.5, 0.9, 0.9),
				offset = Vector3.new(0, 0.6, 0),
				color = METAL,
				material = Enum.Material.Metal,
				shape = Enum.PartType.Cylinder,
				rotation = Vector3.new(0, 0, 90),
			},
		})
	end,
	CatCafe_Item_Salmon = function()
		return simple("CatCafe_Item_Salmon", {
			{
				name = "Fish",
				size = Vector3.new(0.5, 0.3, 1.3),
				offset = Vector3.new(0, 0.5, 0),
				color = Color3.fromRGB(240, 120, 100),
				material = Enum.Material.SmoothPlastic,
			},
		})
	end,
	CatCafe_Item_Net_L1 = function()
		return net(1)
	end,
	CatCafe_Item_Net_L2 = function()
		return net(2)
	end,
	CatCafe_Item_Net_L3 = function()
		return net(3)
	end,
	-- Rescue props (features.md 8b), shaped to the asset round 2 bounds with the real props' pivots (front -Z),
	-- so Layout.stuckPoses fits both. The tree's low branch reaches along -X; the box lies on its side with the
	-- opening toward -Z; the drainpipe hangs on a wall (pivot at the back-bottom of its plate) with its outlet
	-- toward -Z at floor level.
	CatCafe_Alley_StuckBox = function()
		local cardboard = Color3.fromRGB(196, 150, 100)
		return simple("CatCafe_Alley_StuckBox", {
			{
				name = "Back",
				size = Vector3.new(2.29, 2.1, 0.15),
				offset = Vector3.new(0.3, 1.05, 1.4),
				color = cardboard,
				material = Enum.Material.Cardboard,
				collide = true,
			},
			{
				name = "SideL",
				size = Vector3.new(0.15, 2.1, 2.19),
				offset = Vector3.new(-0.78, 1.05, 0.38),
				color = cardboard,
				material = Enum.Material.Cardboard,
				collide = true,
			},
			{
				name = "SideR",
				size = Vector3.new(0.15, 2.1, 2.19),
				offset = Vector3.new(1.37, 1.05, 0.38),
				color = cardboard,
				material = Enum.Material.Cardboard,
				collide = true,
			},
			{
				name = "Top",
				size = Vector3.new(2.29, 0.15, 2.19),
				offset = Vector3.new(0.3, 2.03, 0.38),
				color = cardboard:Lerp(DARK, 0.1),
				material = Enum.Material.Cardboard,
				collide = true,
			},
		})
	end,
	CatCafe_Alley_Drainpipe = function()
		local pipe = METAL:Lerp(DARK, 0.3)
		return simple("CatCafe_Alley_Drainpipe", {
			{
				name = "Plate",
				size = Vector3.new(2.6, 8.3, 0.06),
				offset = Vector3.new(0, 4.15, -0.03),
				color = DARK,
				material = Enum.Material.Metal,
			},
			{
				name = "Riser",
				size = Vector3.new(1, 6.6, 1),
				offset = Vector3.new(0, 5, -0.7),
				color = pipe,
				material = Enum.Material.Metal,
				collide = true,
			},
			{
				name = "Outlet",
				size = Vector3.new(1.6, 1.7, 2.9),
				offset = Vector3.new(0, 0.85, -1.5),
				color = pipe,
				material = Enum.Material.Metal,
				collide = true,
			},
		})
	end,
	CatCafe_Alley_StuckTree = function()
		local bark = Color3.fromRGB(110, 75, 45)
		return simple("CatCafe_Alley_StuckTree", {
			{
				name = "Trunk",
				size = Vector3.new(1.2, 7.2, 1.2),
				offset = Vector3.new(0, 3.6, 0),
				color = bark,
				material = Enum.Material.Wood,
				collide = true,
			},
			{
				name = "Branch",
				size = Vector3.new(3.1, 0.5, 0.6),
				offset = Vector3.new(-1.55, 4.0, 0),
				color = bark,
				material = Enum.Material.Wood,
				collide = true,
			},
			{
				name = "Leaves",
				size = Vector3.new(4, 2.4, 2.9),
				offset = Vector3.new(1.2, 6.9, 0),
				color = GREEN,
				material = Enum.Material.Grass,
			},
		})
	end,
}

-- Index decor (F48) until the asset thread models it: each piece is a rough stand-in at its final footprint, and
-- the gold piece is the same shape in gold. The print hangs from its base like the neon sign, face toward -Z.
local INDEX_GOLD = Color3.fromRGB(232, 184, 64)
local INDEX_DECOR: { [string]: { PartSpec } } = {
	MuralPrint = {
		{
			name = "Frame",
			size = Vector3.new(3.6, 2.6, 0.2),
			offset = Vector3.new(0, 1.3, 0),
			color = WOOD,
		},
		{
			name = "Print",
			size = Vector3.new(3.2, 2.2, 0.05),
			offset = Vector3.new(0, 1.3, -0.12),
			color = Color3.fromRGB(120, 90, 160),
		},
	},
	ParkBench = {
		{
			name = "Seat",
			size = Vector3.new(4, 0.3, 1.2),
			offset = Vector3.new(0, 1.1, -0.1),
			color = WOOD,
		},
		{
			name = "Back",
			size = Vector3.new(4, 1, 0.2),
			offset = Vector3.new(0, 1.9, 0.6),
			color = WOOD,
		},
		{
			name = "Legs",
			size = Vector3.new(3.6, 0.95, 1),
			offset = Vector3.new(0, 0.475, 0),
			color = DARK,
		},
	},
	MailboxPlanter = {
		{
			name = "Post",
			size = Vector3.new(0.3, 1.6, 0.3),
			offset = Vector3.new(0, 0.8, 0),
			color = WOOD,
		},
		{
			name = "Box",
			size = Vector3.new(1.2, 0.9, 1.4),
			offset = Vector3.new(0, 2.05, 0),
			color = MINT,
		},
		{
			name = "Flowers",
			size = Vector3.new(1, 0.5, 1.2),
			offset = Vector3.new(0, 2.75, 0),
			color = NEON_PINK,
			material = Enum.Material.Grass,
		},
	},
	MushroomLamp = {
		{
			name = "Stem",
			size = Vector3.new(0.6, 2.2, 0.6),
			offset = Vector3.new(0, 1.1, 0),
			color = CREAM,
		},
		{
			name = "Cap",
			size = Vector3.new(1.6, 1, 1.6),
			offset = Vector3.new(0, 2.7, 0),
			color = Color3.fromRGB(214, 80, 70),
			material = Enum.Material.Neon,
		},
	},
	PipeFountain = {
		{
			name = "Basin",
			size = Vector3.new(2.2, 0.8, 2.2),
			offset = Vector3.new(0, 0.4, 0),
			color = METAL,
		},
		{
			name = "Water",
			size = Vector3.new(1.9, 0.1, 1.9),
			offset = Vector3.new(0, 0.75, 0),
			color = GLASS,
			transparency = 0.3,
		},
		{
			name = "Pipe",
			size = Vector3.new(0.4, 1.6, 0.4),
			offset = Vector3.new(0, 1.6, 0),
			color = METAL,
		},
	},
}
for piece, parts in INDEX_DECOR do
	local name = "CatCafe_Decor_" .. piece
	builders[name] = function()
		return simple(name, parts)
	end
	builders[name .. "_Gold"] = function()
		local gold = table.clone(parts)
		for i, spec in gold do
			gold[i] = table.clone(spec)
			gold[i].color = INDEX_GOLD
			gold[i].material = Enum.Material.Metal
		end
		return simple(name .. "_Gold", gold)
	end
end

-- Cafe Crate furniture and decorations (F53) until the asset thread models them: a block in the piece's rarity colour
-- at a rough footprint, furniture low and wide, a decoration tall and thin, with its name on a little board on the
-- front (-Z). The F48 Index pieces among them have their own stand-ins above.
for _, def in Catalog.crateDecor do
	if (def.kind ~= "furniture" and def.kind ~= "decoration") or builders[def.asset] ~= nil then
		continue
	end
	local name, rarity = def.asset, def.rarity or "Common"
	local furniture = def.kind == "furniture"
	local size = if furniture then Vector3.new(4, 2.4, 2.4) else Vector3.new(1.6, 4, 1.6)
	builders[name] = function()
		local model = simple(name, {
			{
				name = "Body",
				size = size,
				offset = Vector3.new(0, size.Y / 2, 0),
				color = hexColor(Catalog.rarities[rarity].color),
				collide = furniture,
			},
		})
		local board = addPart(model, {
			name = "NameBoard",
			size = Vector3.new(math.max(size.X, 2.4), 0.8, 0.1),
			offset = Vector3.new(0, size.Y + 0.5, -size.Z / 2),
			color = CREAM,
		})
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = DARK
		label.Text = def.name
		label.Parent = gui
		gui.Parent = board
		return model
	end
end

-- The Golden Fish Market (F53, golden-fish.md section 3) until the art is synced: a fishmonger's counter under a
-- striped awning, a crate of golden fish on top and a sign, front toward -Z. PromptAnchor sits at the front, 3 up.
builders.CatCafe_Street_FishMarket = function()
	local model = newModel("CatCafe_Street_FishMarket")
	local counter = addPart(model, {
		name = "Counter",
		size = Vector3.new(7, 3, 3),
		offset = Vector3.new(0, 1.5, 0),
		color = WOOD,
		material = Enum.Material.WoodPlanks,
		collide = true,
	})
	local anchor = Instance.new("Attachment")
	anchor.Name = "PromptAnchor"
	anchor.Position = Vector3.new(0, 1.5, -1.8) -- relative to the counter's centre: the front, 3 studs up
	anchor.Parent = counter
	addPart(model, {
		name = "FishCrate",
		size = Vector3.new(3, 0.8, 1.6),
		offset = Vector3.new(0, 3.4, 0),
		color = INDEX_GOLD,
		material = Enum.Material.Metal,
	})
	for _, x in { -3.2, 3.2 } do
		addPart(model, {
			name = "Post",
			size = Vector3.new(0.4, 6.5, 0.4),
			offset = Vector3.new(x, 3.25, 1.2),
			color = CREAM,
			collide = true,
		})
	end
	for index = 1, 5 do
		addPart(model, {
			name = "Awning",
			size = Vector3.new(1.4, 0.2, 3.6),
			offset = Vector3.new(-2.8 + (index - 1) * 1.4, 6.6, -0.2),
			rotation = Vector3.new(-12, 0, 0),
			color = if index % 2 == 1 then Color3.fromRGB(64, 170, 180) else CREAM,
		})
	end
	local sign = addPart(model, {
		name = "Sign",
		size = Vector3.new(6, 1.2, 0.2),
		offset = Vector3.new(0, 7.6, 1.2),
		color = CREAM,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = DARK
	label.Text = "Golden Fish Market"
	label.Parent = gui
	gui.Parent = sign
	return finish(model, counter)
end

-- Every asset name the game can ask for.
-- The Codes Cat (F65, data-model section 11d) until the art is synced: a booth with a "Codes" sign and the cat on
-- top, and the CodesCircle (a flat Neon disc, radius CodesCircleRadius) 6 studs in front, as in the asset.
builders.CatCafe_Street_CodesCat = function()
	local model = newModel("CatCafe_Street_CodesCat")
	local booth = addPart(model, {
		name = "Booth",
		size = Vector3.new(6, 3.5, 3),
		offset = Vector3.new(0, 1.75, 0.6),
		color = WOOD,
		material = Enum.Material.WoodPlanks,
		collide = true,
	})
	local anchor = Instance.new("Attachment")
	anchor.Name = "PromptAnchor"
	anchor.Position = Vector3.new(0, 1.25, -2) -- relative to the booth's centre: (0, 3, -1.4) from the pivot
	anchor.Parent = booth
	addPart(model, {
		name = "Cat",
		size = Vector3.new(1.4, 1.8, 1.8),
		offset = Vector3.new(0, 4.4, 0.6),
		color = Color3.fromRGB(235, 160, 90),
	})
	local sign = addPart(model, {
		name = "Sign",
		size = Vector3.new(5, 1.2, 0.2),
		offset = Vector3.new(0, 6.4, 1.8),
		color = CREAM,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = DARK
	label.Text = "Codes"
	label.Parent = gui
	gui.Parent = sign
	addPart(model, {
		name = "CodesCircle",
		size = Vector3.new(0.1, Config.CodesCircleRadius * 2, Config.CodesCircleRadius * 2),
		offset = Vector3.new(0, 0.05, -6),
		rotation = Vector3.new(0, 0, 90),
		color = Color3.fromRGB(255, 214, 120),
		material = Enum.Material.Neon,
		shape = Enum.PartType.Cylinder,
		transparency = 0.4,
	})
	return finish(model, booth)
end

function Placeholders.names(): { string }
	local names: { string } = {}
	for _, def in Catalog.cats do
		table.insert(names, Catalog.catModelName(def.id))
	end
	for _, variant in { "A", "B", "C" } do
		table.insert(names, "CatCafe_NPC_Customer_" .. variant)
	end
	for name in builders do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

function Placeholders.build(name: string): Model?
	local builder = builders[name]
	if builder ~= nil then
		return builder()
	end
	local catDef = Catalog.catsByModelName[name]
	if catDef ~= nil then
		return Placeholders.cat(catDef)
	end
	local variant = name:match("^CatCafe_NPC_Customer_(%u)$")
	if variant ~= nil then
		return Placeholders.customer(variant)
	end
	return nil
end

Placeholders.hexColor = hexColor

return Placeholders
