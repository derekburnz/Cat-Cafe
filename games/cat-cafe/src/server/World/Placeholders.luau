--!strict
-- Builds placeholder Models out of Parts, one per asset name in features.md section 5.
-- Every placeholder uses the final name, PrimaryPart and pivot (base centre, front facing -Z) so the
-- asset thread's real models replace them by name with no code change. Each carries attribute Placeholder = true.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
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

local function finish(model: Model, primary: BasePart): Model
	model.PrimaryPart = primary
	model.WorldPivot = CFrame.new(0, 0, 0)
	return model
end

local WOOD = Color3.fromRGB(176, 120, 70)
local CREAM = Color3.fromRGB(246, 236, 214)
local MINT = Color3.fromRGB(165, 214, 190)
local DARK = Color3.fromRGB(60, 60, 65)
local METAL = Color3.fromRGB(190, 195, 200)
local GREEN = Color3.fromRGB(90, 160, 80)

function Placeholders.cat(def: Types.CatDef): Model
	local model = newModel(Catalog.catModelName(def.id))
	local fur = rgb(def.color)
	local body = addPart(
		model,
		{
			name = "Body",
			size = Vector3.new(1, 1.1, 2.2),
			offset = Vector3.new(0, 0.85, 0.2),
			color = fur,
		}
	)
	addPart(
		model,
		{
			name = "Head",
			size = Vector3.new(0.9, 0.9, 0.9),
			offset = Vector3.new(0, 1.2, -1.25),
			color = fur,
		}
	)
	addPart(
		model,
		{
			name = "EarL",
			size = Vector3.new(0.25, 0.3, 0.15),
			offset = Vector3.new(-0.3, 1.75, -1.3),
			color = fur,
		}
	)
	addPart(
		model,
		{
			name = "EarR",
			size = Vector3.new(0.25, 0.3, 0.15),
			offset = Vector3.new(0.3, 1.75, -1.3),
			color = fur,
		}
	)
	addPart(
		model,
		{
			name = "Tail",
			size = Vector3.new(0.18, 0.18, 1.0),
			offset = Vector3.new(0, 1.15, 1.6),
			color = fur,
			rotation = Vector3.new(-35, 0, 0),
		}
	)
	for i, x in { -0.3, 0.3 } do
		addPart(
			model,
			{
				name = "LegF" .. i,
				size = Vector3.new(0.25, 0.35, 0.25),
				offset = Vector3.new(x, 0.18, -0.6),
				color = fur,
			}
		)
		addPart(
			model,
			{
				name = "LegB" .. i,
				size = Vector3.new(0.25, 0.35, 0.25),
				offset = Vector3.new(x, 0.18, 0.9),
				color = fur,
			}
		)
	end
	local eyeColor = if def.rarity == "Legendary"
		then Color3.fromRGB(255, 190, 60)
		else Color3.fromRGB(20, 20, 20)
	local eyeMaterial = if def.rarity == "Legendary"
		then Enum.Material.Neon
		else Enum.Material.SmoothPlastic
	for i, x in { -0.22, 0.22 } do
		addPart(
			model,
			{
				name = "Eye" .. i,
				size = Vector3.new(0.14, 0.14, 0.06),
				offset = Vector3.new(x, 1.28, -1.72),
				color = eyeColor,
				material = eyeMaterial,
			}
		)
	end
	-- Pattern hint so placeholders are telling apart at a glance
	if def.pattern == "stripes" or def.pattern == "spots" or def.pattern == "patches" then
		addPart(
			model,
			{
				name = "Marking",
				size = Vector3.new(1.02, 0.25, 0.5),
				offset = Vector3.new(0, 1.0, 0.2),
				color = fur:Lerp(Color3.new(0, 0, 0), 0.35),
			}
		)
	elseif def.pattern == "points" then
		addPart(
			model,
			{
				name = "Marking",
				size = Vector3.new(0.92, 0.3, 0.92),
				offset = Vector3.new(0, 1.0, -1.25),
				color = fur:Lerp(Color3.new(0, 0, 0), 0.45),
			}
		)
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
	local legs = addPart(
		model,
		{
			name = "Legs",
			size = Vector3.new(1.6, 2, 0.9),
			offset = Vector3.new(0, 1, 0),
			color = DARK,
		}
	)
	addPart(
		model,
		{
			name = "Torso",
			size = Vector3.new(2, 1.9, 1),
			offset = Vector3.new(0, 2.95, 0),
			color = shirts[variant] or shirts.A,
		}
	)
	addPart(
		model,
		{
			name = "Head",
			size = Vector3.new(1.3, 1.3, 1.3),
			offset = Vector3.new(0, 4.55, 0),
			color = skin,
		}
	)
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
		local model = simple("CatCafe_Decor_NeonSign", {
			{
				name = "Sign",
				size = Vector3.new(5, 2, 0.3),
				offset = Vector3.new(0, 1, 0),
				color = Color3.fromRGB(255, 110, 180),
				material = Enum.Material.Neon,
			},
		})
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 110, 180)
		light.Range = 14
		light.Brightness = 1.5
		light.Parent = model.PrimaryPart
		return model
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
				name = "Lamp",
				size = Vector3.new(1.2, 0.8, 1.2),
				offset = Vector3.new(0, 9.2, 0),
				color = Color3.fromRGB(255, 230, 170),
				material = Enum.Material.Neon,
			},
		})
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 225, 160)
		light.Range = 22
		light.Brightness = 1.2
		light.Parent = model:FindFirstChild("Lamp")
		return model
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
	CatCafe_Park_Gate = function()
		return simple("CatCafe_Park_Gate", {
			{
				name = "Bars",
				size = Vector3.new(24, 5, 0.5),
				offset = Vector3.new(0, 2.5, 0),
				color = DARK,
				material = Enum.Material.Metal,
				transparency = 0.35,
				collide = true,
			},
			{
				name = "Arch",
				size = Vector3.new(26, 0.8, 1),
				offset = Vector3.new(0, 5.4, 0),
				color = DARK,
				material = Enum.Material.Metal,
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
	CatCafe_Item_Gloves = function()
		return simple("CatCafe_Item_Gloves", {
			{
				name = "Glove",
				size = Vector3.new(0.8, 0.3, 1),
				offset = Vector3.new(0, 0.15, 0),
				color = Color3.fromRGB(120, 90, 60),
				material = Enum.Material.Fabric,
			},
		})
	end,
}

-- Every asset name the game can ask for.
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
	local catId = name:match("^CatCafe_Cat_(%w+)$")
	if catId ~= nil then
		local def = Catalog.getCat(catId:lower())
		if def ~= nil then
			return Placeholders.cat(def)
		end
	end
	local variant = name:match("^CatCafe_NPC_Customer_(%u)$")
	if variant ~= nil then
		return Placeholders.customer(variant)
	end
	return nil
end

Placeholders.hexColor = hexColor

return Placeholders
