--!strict
-- The Rift Run (Derek 2026-11-13: "making the animation/vfx/moddeling for pulling a mythic+ trait much better like a
-- whole cutscene with the cat you have ... cut to a scene of a different realm A rift opens and your cat jumps
-- through it running away while dodging meteors coming flash Common/Flash uncommon/flash rare ... with increasing
-- vfx/animation for each tier"; storyboard Motion-FX-Agent/for-derek-2026-11-13/rift-run, OK'd "build" 20:09 UTC).
-- The server has already rolled; this only shows a Mythic or Secret roll:
--   1. The screen goes white over the pool (letterbox bars slide in, every window, banner and pop-up hides).
--   2. Cut to the Rift Realm, built on this client far off the map (Presets.riftRun.origin): a floating stone path
--      in a violet sky, islands, stars and, far ahead, the rift as a thin slit. The rolled cat drops onto the path.
--   3. It runs, faster and faster, with the camera low behind it. Meteors fall beside it and it hops aside from
--      each (nothing ever hits it). One gate a tier rises out of the void and lights as it passes, Common up to the
--      rolled tier, each with a bigger flare, shockwave, sparkles, word and note than the last.
--      A Secret: after the Mythic gate the realm goes black, a cat of stars draws itself in the sky and the white
--      Secret gate rises out of the dark.
--   4. The rift tears open and the cat leaps off the path's end into it, slowed right down; the screen goes pink,
--      then white.
--   5. Back at the pool (`back`, the controller's BigTraitCut.atPool with the pool's landing), or on the screen when
--      the pool is far: the trait card follows. Windows and pop-ups come back only as the card shows.
--
--   local skip = RiftRun.play("mythic", { catId = "tabby", gold = false }, back, onReveal)
--
-- Not skippable by a tap (MysticPoolLogic.canSkip); `skip()` is only for the card closing mid scene and ends it at
-- once. onReveal runs exactly once, whatever happens, and a hard cap (Presets.riftRun.cap) always gives the camera,
-- controls, prompts and windows back. Nothing random, no near miss (the gates only go up to the rolled tier, and
-- each rises only as the cat nears it), nothing flashes faster than about once a second. Reduce Motion: no Rift Run
-- (wanted is false). Model-Agent's kit (ReplicatedStorage.Assets.RiftRun, CatCafe_RiftRun_*) is used when it is
-- there, else the same pieces are drawn here. Switch `riftRun` (shared/LiveFlags); in Studio the Workspace attribute
-- RiftRunTest ("mythic" or "secret") plays it with the switch off. Client only; it sends nothing.

local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog"))
local LiveFlags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags"))

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local MysticPool = require(script.Parent.MysticPool)
local Particles = require(script.Parent.Particles)
local Pose = require(script.Parent.Pose)
local Presets = require(script.Parent.Presets)

local RiftRun = {}

-- The beats, for the sounds (Audio followRiftRun): "hush" as it starts and "done" as the card shows (the music
-- ducks between), "flare" as the screen goes white over the pool, "cut" into the realm, "land" as the cat lands on the path, "gate" with the gate's number (1 Common
-- up) and tier, "meteor" as one lands, "dark" for a Secret's dark, "tear" as the rift tears open, "leap" off the
-- path and "back" at the hand back. Listeners only listen.
export type Beat =
	"hush"
	| "flare"
	| "cut"
	| "land"
	| "gate"
	| "meteor"
	| "dark"
	| "tear"
	| "leap"
	| "back"
	| "done"
local listeners: { (beat: Beat, step: number, tier: string) -> () } = {}
local holds: { (on: boolean) -> () } = {}

local SWITCH = "riftRun"
local TEST_ATTRIBUTE = "RiftRunTest"
local STEP = "EffectsRiftRun"
local KIT = "RiftRun"
-- the cutscene's own ScreenGuis, which stay up while every other window, marker and label hides
local OURS = {
	EffectsRiftRun = true,
	EffectsBigTraitCut = true,
	EffectsBigTraitScene = true,
	EffectsBigTraitLadder = true,
}
local FONT = Font.new(
	"rbxasset://fonts/families/FredokaOne.json",
	Enum.FontWeight.Regular,
	Enum.FontStyle.Normal
)
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local running = false

function RiftRun.onBeat(listener: (beat: Beat, step: number, tier: string) -> ())
	table.insert(listeners, listener)
end

-- Calls `listener(true)` as the cutscene starts and `listener(false)` as the card shows: the controller holds the
-- pop-ups (UI.setRollBusy, later UI.setCutscene) in between.
function RiftRun.onHold(listener: (on: boolean) -> ())
	table.insert(holds, listener)
end

local function beat(name: Beat, step: number, tier: string)
	for _, listener in listeners do
		task.spawn(listener, name, step, tier)
	end
end

local function hold(on: boolean)
	for _, listener in holds do
		task.spawn(listener, on)
	end
end

-- Studio only: the RiftRunTest attribute's rarity, or nil.
function RiftRun.testRarity(): string?
	if not RunService:IsStudio() then
		return nil
	end
	local value = Workspace:GetAttribute(TEST_ATTRIBUTE)
	return if value == "mythic" or value == "secret" then value else nil
end

local function switchOn(): boolean
	if RiftRun.testRarity() ~= nil then
		return true
	end
	return LiveFlags.shown(
		SWITCH,
		ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. SWITCH)
	)
end

-- Whether a roll of `rarity` gets the Rift Run now: Mythic or Secret, the switch on, not under Reduce Motion, and
-- not while one is already running.
function RiftRun.wanted(rarity: string): boolean
	return Logic.riftPlan(rarity) ~= nil
		and switchOn()
		and not Context.reducedMotion()
		and not running
end

-- Whether the Rift Run holds the screen now (the realm or its hand back).
function RiftRun.playing(): boolean
	return running
end

local function colourOf(tier: string): Color3
	if tier == "secret" then
		return Presets.riftRun.secretColour
	end
	return MysticPool.colourOf(tier)
end

-- Building -------------------------------------------------------------------------------------------------------

local function plain(name: string, size: Vector3, colour: Color3, material: Enum.Material?): Part
	local part = Context.effectPart(name, size, colour)
	part.Material = material or Enum.Material.SmoothPlastic
	return part
end

-- A copy of a kit piece from ReplicatedStorage.Assets.RiftRun, anchored, walk-through, shadowless and with no
-- scripts, or nil.
local function kit(name: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = if assets ~= nil then assets:FindFirstChild(KIT) else nil
	local found = if folder ~= nil then folder:FindFirstChild(name) else nil
	if found == nil or not found:IsA("Model") then
		return nil
	end
	local copy = (found :: Model):Clone() :: Model
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			local part = d :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
		elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then
			d:Destroy()
		end
	end
	return copy
end

local function kitIslands(): { Model }
	local out: { Model } = {}
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = if assets ~= nil then assets:FindFirstChild(KIT) else nil
	if folder == nil then
		return out
	end
	for _, child in folder:GetChildren() do
		if child:IsA("Model") and string.sub(child.Name, 1, 22) == "CatCafe_RiftRun_Island" then
			local copy = kit(child.Name)
			if copy ~= nil then
				table.insert(out, copy)
			end
		end
	end
	table.sort(out, function(a: Model, b: Model): boolean
		return a.Name < b.Name
	end)
	return out
end

-- Every Neon part whose name ends _Glow under `root` (the kit's lights), or every Neon part for a drawn piece.
local function glowsOf(root: Instance): { BasePart }
	local out: { BasePart } = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and (string.sub(d.Name, -5) == "_Glow") then
			table.insert(out, d :: BasePart)
		end
	end
	return out
end

type Gate = {
	model: Model,
	home: CFrame, -- where it stands once risen
	glows: { BasePart },
	light: PointLight,
	tier: string,
	colour: Color3,
	z: number,
	at: number,
	risen: boolean,
	riseAt: number?,
	passed: boolean,
	flareAt: number?,
}

type Island = { model: Model, home: CFrame, phase: number }

type Meteor = {
	plan: Logic.RiftMeteor,
	rock: Model?,
	start: Vector3,
	land: Vector3,
	landed: boolean,
	landedAt: number,
	emitter: ParticleEmitter?,
}

type Realm = {
	root: Model,
	origin: Vector3,
	gates: { Gate },
	islands: { Island },
	sky: { BasePart },
	skyBase: { Color3 },
	glow: { BasePart }, -- path edges and crystals, dimmed in a Secret's dark
	glowBase: { Color3 },
	stars: { BasePart },
	ringParts: { BasePart },
	ringKit: Model?,
	ringKitHome: CFrame?,
	core: Part,
	coreMesh: SpecialMesh,
	coreLight: PointLight,
	ringCentre: Vector3,
	constellation: { BasePart },
}

-- One gate arch of `tier`, standing at `at` (its base centre on the path's top), drawn when the kit has none.
local function drawnGate(tier: string, colour: Color3): Model
	local r = Presets.riftRun
	local model = Instance.new("Model")
	model.Name = "RiftGate_" .. tier
	local half = r.gateWidth / 2 + 0.7
	local base = plain(
		"Base",
		Vector3.new(r.gateWidth + 4, 0.6, 2.4),
		Presets.riftRun.rock,
		Enum.Material.Slate
	)
	base.CFrame = CFrame.new(0, -0.3, 0)
	base.Parent = model
	for _, side in { -1, 1 } do
		local pillar =
			plain("Pillar", Vector3.new(1.6, r.gateHeight, 1.6), r.rock, Enum.Material.Slate)
		pillar.CFrame = CFrame.new(side * half, r.gateHeight / 2, 0)
		pillar.Parent = model
		local inner =
			plain("Inner_Glow", Vector3.new(0.4, r.gateHeight - 1, 1.7), colour, Enum.Material.Neon)
		inner.CFrame = CFrame.new(side * (half - 0.75), r.gateHeight / 2, 0)
		inner.Parent = model
		local cap = plain("Cap_Glow", Vector3.new(1.2, 1.2, 1.2), colour, Enum.Material.Neon)
		cap.Shape = Enum.PartType.Ball
		cap.CFrame = CFrame.new(side * half, r.gateHeight + 2.2, 0)
		cap.Parent = model
	end
	local lintel =
		plain("Lintel", Vector3.new(r.gateWidth + 4.4, 1.6, 1.6), r.rock, Enum.Material.Slate)
	lintel.CFrame = CFrame.new(0, r.gateHeight + 0.8, 0)
	lintel.Parent = model
	local under =
		plain("Lintel_Glow", Vector3.new(r.gateWidth, 0.4, 1.7), colour, Enum.Material.Neon)
	under.CFrame = CFrame.new(0, r.gateHeight - 0.05, 0)
	under.Parent = model
	-- the tier's gem over the middle
	local gem = plain("Gem_Glow", Vector3.new(1.6, 1.6, 1.6), colour, Enum.Material.Neon)
	gem.CFrame = CFrame.new(0, r.gateHeight + 2.4, 0) * CFrame.Angles(0, 0, math.rad(45))
	gem.Parent = model
	model.PrimaryPart = base
	model.WorldPivot = CFrame.new()
	return model
end

local function drawnIsland(size: number, index: number): Model
	local r = Presets.riftRun
	local model = Instance.new("Model")
	model.Name = "RiftIsland"
	local top =
		plain("Top", Vector3.new(2, size, size), Color3.fromRGB(104, 78, 156), Enum.Material.Slate)
	top.Shape = Enum.PartType.Cylinder
	top.CFrame = CFrame.new(0, -1, 0) * CFrame.Angles(0, 0, math.pi / 2)
	top.Parent = model
	local layers = 3
	for i = 1, layers do
		local k = 1 - i / (layers + 1)
		local chunk = plain(
			"Under",
			Vector3.new(size * k, size * 0.32, size * k),
			r.rock,
			Enum.Material.Basalt
		)
		chunk.CFrame = CFrame.new(0, -2 - (i - 0.5) * size * 0.28, 0)
			* CFrame.Angles(0, math.rad(37 * i + index * 11), 0)
		chunk.Parent = model
	end
	local count = if size >= 20 then 4 else if size >= 14 then 3 else 2
	for i = 1, count do
		local a = (i / count) * math.pi * 2 + index
		local crystal = plain(
			"Crystal_Glow",
			Vector3.new(0.9, 2.4 + (i % 2) * 1.6, 0.9),
			r.crystal[(i + index) % #r.crystal + 1],
			Enum.Material.Neon
		)
		crystal.CFrame = CFrame.new(math.cos(a) * size * 0.28, 0.9, math.sin(a) * size * 0.28)
			* CFrame.Angles(math.rad(12), a, math.rad(14))
		crystal.Parent = model
	end
	model.WorldPivot = CFrame.new()
	return model
end

-- The sky: thin Neon walls in bands, top to bottom through Presets.riftRun.sky, round the whole run.
local function drawSky(parent: Instance, origin: Vector3, sky: { BasePart }, base: { Color3 })
	local r = Presets.riftRun
	local colours = r.sky
	local bands: { Color3 } = {}
	for i = 1, #colours - 1 do
		for j = 0, 2 do
			table.insert(bands, colours[i]:Lerp(colours[i + 1], j / 3))
		end
	end
	table.insert(bands, colours[#colours])
	local height = r.skyUp + r.skyDown
	local band = height / #bands
	local long = r.skyAhead + r.skyBehind
	local midZ = -(r.skyAhead - r.skyBehind) / 2
	local function add(name: string, size: Vector3, at: Vector3, colour: Color3)
		local part = plain(name, size, colour, Enum.Material.Neon)
		part.CFrame = CFrame.new(origin + at)
		part.Parent = parent
		table.insert(sky, part)
		table.insert(base, colour)
	end
	for i, colour in bands do
		local y = r.skyUp - (i - 0.5) * band
		add(
			"SkyAhead",
			Vector3.new(r.skyHalf * 2, band + 0.2, 1),
			Vector3.new(0, y, -r.skyAhead),
			colour
		)
		add(
			"SkyBehind",
			Vector3.new(r.skyHalf * 2, band + 0.2, 1),
			Vector3.new(0, y, r.skyBehind),
			colour
		)
		add("SkyLeft", Vector3.new(1, band + 0.2, long), Vector3.new(-r.skyHalf, y, midZ), colour)
		add("SkyRight", Vector3.new(1, band + 0.2, long), Vector3.new(r.skyHalf, y, midZ), colour)
	end
	add("SkyTop", Vector3.new(r.skyHalf * 2, 1, long), Vector3.new(0, r.skyUp, midZ), colours[1])
	add(
		"SkyUnder",
		Vector3.new(r.skyHalf * 2, 1, long),
		Vector3.new(0, -r.skyDown, midZ),
		colours[#colours]
	)
end

local function drawStars(parent: Instance, origin: Vector3, count: number, stars: { BasePart })
	local r = Presets.riftRun
	local rng = Random.new(1113) -- the same sky every time
	for _ = 1, count do
		local wall = rng:NextInteger(1, 4)
		local at: Vector3
		if wall == 1 or wall == 2 then -- ahead, the most seen
			at = Vector3.new(
				rng:NextNumber(-r.skyHalf + 4, r.skyHalf - 4),
				rng:NextNumber(-10, r.skyUp - 4),
				-r.skyAhead + 2
			)
		elseif wall == 3 then
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			at = Vector3.new(
				side * (r.skyHalf - 2),
				rng:NextNumber(-10, r.skyUp - 4),
				rng:NextNumber(-r.skyAhead + 4, r.skyBehind - 4)
			)
		else
			at = Vector3.new(
				rng:NextNumber(-r.skyHalf + 4, r.skyHalf - 4),
				r.skyUp - 2,
				rng:NextNumber(-r.skyAhead + 4, r.skyBehind - 4)
			)
		end
		local size = rng:NextNumber(0.5, 1.4)
		local star = plain("Star", Vector3.new(size, size, size), r.starColour, Enum.Material.Neon)
		star.Shape = Enum.PartType.Ball
		star.CFrame = CFrame.new(origin + at)
		star:SetAttribute("Phase", rng:NextNumber(0, math.pi * 2))
		star.Parent = parent
		table.insert(stars, star)
	end
end

-- The rift: a ring of Neon pieces round the core, its width `open` (0 a slit, 1 a circle) of its height.
local function drawRing(parent: Instance, count: number): { BasePart }
	local r = Presets.riftRun
	local out: { BasePart } = {}
	for i = 1, count do
		local k = (i - 1) / count
		local piece = plain(
			"RingPiece",
			Vector3.new(1.3, 1.3, 3),
			r.ringColour:Lerp(Color3.fromRGB(150, 110, 255), 0.5 + 0.5 * math.cos(k * math.pi * 2)),
			Enum.Material.Neon
		)
		piece.Parent = parent
		table.insert(out, piece)
	end
	return out
end

local function placeRing(realm: Realm, open: number)
	local r = Presets.riftRun
	local radius = r.ringDiameter / 2
	local centre = realm.ringCentre
	local width = math.max(open, 0.03)
	local kitRing = realm.ringKit
	if kitRing ~= nil and realm.ringKitHome ~= nil then
		kitRing:ScaleTo(math.max(open, 0.05))
		local home = realm.ringKitHome :: CFrame
		-- the kit's pivot is its base centre: scaled about it, so lift it to keep the middle where it is
		kitRing:PivotTo(home + Vector3.new(0, radius * (1 - math.max(open, 0.05)), 0))
	end
	local parts = realm.ringParts
	local n = #parts
	if n > 0 then
		local frames: { CFrame } = {}
		for i = 1, n do
			local a0 = (i - 1) / n * math.pi * 2
			local a1 = i / n * math.pi * 2
			local p0 = centre + Vector3.new(math.cos(a0) * radius * width, math.sin(a0) * radius, 0)
			local p1 = centre + Vector3.new(math.cos(a1) * radius * width, math.sin(a1) * radius, 0)
			local length = (p1 - p0).Magnitude
			parts[i].Size = Vector3.new(1.3, 1.3, length + 0.5)
			frames[i] = CFrame.lookAt((p0 + p1) / 2, p1)
		end
		Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
	local inner = r.ringDiameter - 2.4
	realm.coreMesh.Scale = Vector3.new(inner * width, inner, 0.4)
	realm.core.Transparency = 0.55 - 0.3 * open
	realm.coreLight.Brightness = 1 + 4 * open
	realm.coreLight.Range = 12 + 28 * open
end

local function buildRealm(plan: Logic.RiftPlan, lite: boolean): Realm
	local r = Presets.riftRun
	local origin = r.origin
	local root = Instance.new("Model")
	root.Name = "EffectsRiftRealm"
	local sky: { BasePart } = {}
	local skyBase: { Color3 } = {}
	drawSky(root, origin, sky, skyBase)
	local stars: { BasePart } = {}
	drawStars(root, origin, if lite then r.stars.low else r.stars.high, stars)
	for _, cloud in r.nebula do
		local blob = plain(
			"Nebula",
			Vector3.new(cloud.size, cloud.size * 0.6, cloud.size * 0.2),
			cloud.colour,
			Enum.Material.Neon
		)
		blob.Shape = Enum.PartType.Ball
		blob.Transparency = r.nebulaSeen
		blob.CFrame = CFrame.new(origin + cloud.at)
		blob.Parent = root
		table.insert(sky, blob)
		table.insert(skyBase, cloud.colour)
	end

	-- the path
	local glow: { BasePart } = {}
	local glowBase: { Color3 } = {}
	local path = kit("CatCafe_RiftRun_Path")
	if path ~= nil then
		path:PivotTo(CFrame.new(origin))
		path.Parent = root
		for _, part in glowsOf(path) do
			table.insert(glow, part)
			table.insert(glowBase, part.Color)
		end
	else
		local tiles = math.ceil(r.pathLength / r.tileLength)
		for i = 1, tiles do
			local tile = plain(
				"Tile",
				Vector3.new(r.pathWidth, 1.2, r.tileLength - 0.15),
				r.stone[(i % 2) + 1],
				Enum.Material.Slate
			)
			tile.CFrame = CFrame.new(
				origin + Vector3.new(0, -0.6 + (i % 3) * 0.03, -(i - 0.5) * r.tileLength)
			)
			tile.Parent = root
			if i % 2 == 0 then
				local chunk = plain(
					"Underside",
					Vector3.new(r.pathWidth * 0.8, 5 + (i % 3), r.tileLength * 2),
					r.rock,
					Enum.Material.Basalt
				)
				chunk.CFrame = CFrame.new(
					origin + Vector3.new((i % 3 - 1) * 0.8, -3.4, -(i - 0.5) * r.tileLength)
				) * CFrame.Angles(math.rad(8 * ((i % 4) - 1.5)), 0, math.rad(6 * ((i % 3) - 1)))
				chunk.Parent = root
			end
		end
		for _, side in { -1, 1 } do
			local edge = plain(
				"Edge_Glow",
				Vector3.new(0.35, 0.25, r.pathLength),
				r.edge,
				Enum.Material.Neon
			)
			edge.CFrame = CFrame.new(
				origin + Vector3.new(side * (r.pathWidth / 2 - 0.25), 0.1, -r.pathLength / 2)
			)
			edge.Parent = root
			table.insert(glow, edge)
			table.insert(glowBase, r.edge)
		end
	end

	-- the islands
	local islands: { Island } = {}
	local kitted = kitIslands()
	local wantIslands = if lite then math.min(2, #r.islands) else #r.islands
	for i = 1, wantIslands do
		local spot = r.islands[i]
		local model = if #kitted > 0
			then kitted[(i - 1) % #kitted + 1]
			else drawnIsland(spot.size, i)
		if #kitted > 0 and i > #kitted then
			model = kit(kitted[(i - 1) % #kitted + 1].Name) or model
		end
		local home = CFrame.new(origin + spot.at) * CFrame.Angles(0, i * 1.3, 0)
		model:PivotTo(home)
		model.Parent = root
		for _, part in glowsOf(model) do
			table.insert(glow, part)
			table.insert(glowBase, part.Color)
		end
		table.insert(islands, { model = model, home = home, phase = i * 1.7 })
	end

	-- the gates, out of sight under the path until each rises
	local gates: { Gate } = {}
	for i, tier in plan.gates do
		local colour = colourOf(tier)
		local name = "CatCafe_RiftRun_Gate_"
			.. string.upper(string.sub(tier, 1, 1))
			.. string.sub(tier, 2)
		local model = kit(name) or drawnGate(tier, colour)
		local home = CFrame.new(origin + Vector3.new(0, 0, -plan.gateZ[i]))
		model:PivotTo(home - Vector3.new(0, r.gateHeight + 20, 0))
		local glows = glowsOf(model)
		for _, part in glows do
			part.Color = colour
		end
		local holder = model.PrimaryPart or glows[1]
		local light = Instance.new("PointLight")
		light.Color = colour
		light.Brightness = 0
		light.Range = 18
		light.Shadows = false
		light.Parent = holder
		-- parented as it rises (so it is never seen under the path first)
		table.insert(gates, {
			model = model,
			home = home,
			glows = glows,
			light = light,
			tier = tier,
			colour = colour,
			z = plan.gateZ[i],
			at = plan.gateAt[i],
			risen = false,
			riseAt = nil,
			passed = false,
			flareAt = nil,
		})
	end

	-- the rift
	local ringCentre = origin + Vector3.new(0, r.ringLift, -(r.pathLength + r.ringBeyond))
	local ringKit = kit("CatCafe_RiftRun_Ring")
	local ringKitHome: CFrame? = nil
	local ringParts: { BasePart } = {}
	if ringKit ~= nil then
		local home = CFrame.new(ringCentre - Vector3.new(0, r.ringLift, 0))
		ringKitHome = home
		ringKit:PivotTo(home)
		ringKit.Parent = root
	else
		ringParts = drawRing(root, r.ringSegments)
	end
	local core = plain("RiftCore", Vector3.new(1, 1, 1), r.ringCore, Enum.Material.Neon)
	core.CFrame = CFrame.new(ringCentre + Vector3.new(0, 0, -0.4))
	local coreMesh = Instance.new("SpecialMesh")
	coreMesh.MeshType = Enum.MeshType.Sphere
	coreMesh.Parent = core
	local coreLight = Instance.new("PointLight")
	coreLight.Color = r.ringColour
	coreLight.Shadows = false
	coreLight.Parent = core
	core.Parent = root
	local swirl = Particles.make(Presets.emitters.riftSwirl, nil)
	swirl.Rate = Presets.emitters.riftSwirl.rate * Context.budget.rateScale
	swirl.Enabled = true
	swirl.Parent = core

	local realm: Realm = {
		root = root,
		origin = origin,
		gates = gates,
		islands = islands,
		sky = sky,
		skyBase = skyBase,
		glow = glow,
		glowBase = glowBase,
		stars = stars,
		ringParts = ringParts,
		ringKit = ringKit,
		ringKitHome = ringKitHome,
		core = core,
		coreMesh = coreMesh,
		coreLight = coreLight,
		ringCentre = ringCentre,
		constellation = {},
	}
	placeRing(realm, Logic.riftOpen(plan, 0))
	return realm
end

-- The rolled cat on its walking body (the gold coat's when it is gold), anchored and walk-through, or nil.
local function makeCat(catId: string?, gold: boolean?): Model?
	if catId == nil then
		return nil
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets == nil then
		return nil
	end
	local names = { Catalog.catModelName(catId) }
	if gold == true then
		table.insert(names, 1, Catalog.goldModelName(catId))
	end
	for _, name in names do
		local found = assets:FindFirstChild(name)
		if found ~= nil and found:IsA("Model") then
			local copy = (found :: Model):Clone() :: Model
			copy.Name = "RiftRunCat"
			copy:SetAttribute("CatId", catId)
			copy:SetAttribute("Gold", gold == true)
			for _, d in copy:GetDescendants() do
				if d:IsA("BasePart") then
					local part = d :: BasePart
					part.Anchored = true
					part.CanCollide = false
					part.CanTouch = false
					part.CanQuery = false
				elseif d:IsA("Script") or d:IsA("LocalScript") then
					d:Destroy()
				end
			end
			return copy
		end
	end
	return nil
end

-- The screen: the flash, the letterbox bars, the tier's word and the row of tiers passed ----------------------------

type Screen = {
	gui: ScreenGui,
	flash: Frame,
	bars: { Frame },
	word: TextLabel,
	wordScale: UIScale,
	wordSize: UITextSizeConstraint,
	wordInk: UIStroke,
	ladder: Frame,
}

local function makeScreen(): Screen?
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return nil
	end
	local r = Presets.riftRun
	local gui = Instance.new("ScreenGui")
	gui.Name = "EffectsRiftRun"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = r.displayOrder

	local bars: { Frame } = {}
	for _, top in { true, false } do
		local bar = Instance.new("Frame")
		bar.Name = if top then "BarTop" else "BarBottom"
		bar.BackgroundColor3 = BLACK
		bar.BorderSizePixel = 0
		bar.AnchorPoint = Vector2.new(0, if top then 0 else 1)
		bar.Position = UDim2.fromScale(0, if top then 0 else 1)
		bar.Size = UDim2.fromScale(1, 0)
		bar.Parent = gui
		table.insert(bars, bar)
	end

	local edge = if GuiService:IsTenFootInterface() then 0.05 else 0
	local word = Instance.new("TextLabel")
	word.Name = "Word"
	word.BackgroundTransparency = 1
	word.AnchorPoint = Vector2.new(0.5, 0.5)
	word.Position = UDim2.fromScale(0.5, 0.3 + edge)
	word.Size = UDim2.new(0.9, 0, 0, 96)
	word.FontFace = FONT
	word.Text = ""
	word.TextScaled = true
	word.TextTransparency = 1
	local size = Instance.new("UITextSizeConstraint")
	size.MaxTextSize = 80
	size.MinTextSize = 24
	size.Parent = word
	local ink = Instance.new("UIStroke")
	ink.Color = r.wordInk
	ink.Thickness = 4
	ink.Transparency = 1
	ink.Parent = word
	local wordScale = Instance.new("UIScale")
	wordScale.Parent = word
	word.Parent = gui

	-- the tiers passed so far, a chip each, at the bottom above the bar
	local ladder = Instance.new("Frame")
	ladder.Name = "Ladder"
	ladder.BackgroundTransparency = 1
	ladder.AnchorPoint = Vector2.new(0.5, 1)
	ladder.Position = UDim2.fromScale(0.5, 0.86 - edge)
	ladder.Size = UDim2.new(0.94, 0, 0, 28)
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.HorizontalAlignment = Enum.HorizontalAlignment.Center
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, 6)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = ladder
	ladder.Parent = gui

	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.BackgroundColor3 = WHITE
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 10
	flash.Parent = gui

	gui.Parent = playerGui
	return {
		gui = gui,
		flash = flash,
		bars = bars,
		word = word,
		wordScale = wordScale,
		wordSize = size,
		wordInk = ink,
		ladder = ladder,
	}
end

local function addChip(screen: Screen, i: number, tier: string, colour: Color3)
	local r = Presets.riftRun
	local chip = Instance.new("TextLabel")
	chip.Name = "Chip" .. i
	chip.LayoutOrder = i
	chip.BackgroundColor3 = colour
	chip.BackgroundTransparency = 0.1
	chip.BorderSizePixel = 0
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.Size = UDim2.new(0, 0, 1, 0)
	chip.FontFace = FONT
	chip.Text = (r.words :: { [string]: string })[tier] or string.upper(tier)
	chip.TextColor3 = WHITE
	chip.TextSize = 14
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = chip
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = chip
	local ink = Instance.new("UIStroke")
	ink.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	ink.Color = r.wordInk
	ink.Thickness = 2
	ink.Parent = chip
	chip.Parent = screen.ladder
end

-- The windows ------------------------------------------------------------------------------------------------------

-- Hides every ScreenGui of this player's but ours (and any that turns up meanwhile). Returns the putting back.
local function hideWindows(): () -> ()
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return function() end
	end
	-- Review-QA on #4029: the HUD's pointer arrow (a marker drawn over the world) showed through, so billboards in
	-- the PlayerGui hide too, at any depth
	-- and one whose own code switches it back on (the arrow did for its first second in the realm) is switched off
	-- again at once
	local hidden: { LayerCollector } = {}
	local watches: { RBXScriptConnection } = {}
	local function hide(child: Instance)
		if not (child:IsA("ScreenGui") or child:IsA("BillboardGui")) then
			return
		end
		local gui = child :: LayerCollector
		if gui.Enabled and not OURS[gui.Name] then
			gui.Enabled = false
			table.insert(hidden, gui)
			table.insert(
				watches,
				gui:GetPropertyChangedSignal("Enabled"):Connect(function()
					if gui.Enabled then
						gui.Enabled = false
					end
				end)
			)
		end
	end
	for _, child in playerGui:GetDescendants() do
		hide(child)
	end
	local added = playerGui.DescendantAdded:Connect(hide)
	local back = false
	return function()
		if back then
			return
		end
		back = true
		added:Disconnect()
		for _, watch in watches do
			watch:Disconnect()
		end
		for _, gui in hidden do
			if gui.Parent ~= nil then
				gui.Enabled = true
			end
		end
	end
end

-- The PlayerModule's controls, or nil without the default player scripts (as BigTraitCut).
local function controls(): any?
	local scripts = Players.LocalPlayer:FindFirstChildOfClass("PlayerScripts")
	local module = if scripts ~= nil then scripts:FindFirstChild("PlayerModule") else nil
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local requireAny: any = require -- Roblox's own PlayerModule is not in the Rojo tree
	local ok, controlModule = pcall(function(): any
		return requireAny(module):GetControls()
	end)
	return if ok then controlModule else nil
end

local function setControls(module: any?, on: boolean)
	if module == nil then
		return
	end
	pcall(function()
		if on then
			module:Enable()
		else
			module:Disable()
		end
	end)
end

-- Playing --------------------------------------------------------------------------------------------------------

export type CatInfo = { catId: string?, gold: boolean? }

-- See the top of this file. `back(reveal)` starts what follows the realm (the pool's landing and big moment, or the
-- screen's) with `reveal` as its onReveal, and returns its skip (or nil). Returns the skip for the whole cutscene.
function RiftRun.play(
	rarity: string,
	cat: CatInfo?,
	back: (reveal: () -> ()) -> (() -> ())?,
	onReveal: () -> ()
): () -> ()
	local plan = Logic.riftPlan(rarity)
	local camera = Workspace.CurrentCamera
	if plan == nil or running or camera == nil then
		task.spawn(onReveal)
		return function() end
	end
	local r = Presets.riftRun
	local c = r.camera
	local lite = Context.lite or Context.tier == "low"
	running = true
	hold(true)
	beat("hush", 0, rarity)

	local revealed = false
	local putBack: () -> () = function() end
	local screen = makeScreen()
	-- the card: windows and pop-ups come back with it
	local function reveal()
		if revealed then
			return
		end
		revealed = true
		putBack()
		if screen ~= nil then
			screen.gui:Destroy()
			screen = nil
		end
		running = false
		hold(false)
		beat("done", 0, rarity)
		task.spawn(onReveal)
	end

	local realm = buildRealm(plan, lite)
	local catModel = makeCat(cat and cat.catId, cat and cat.gold)
	local rig: Pose.Rig? = nil
	local rest: { CFrame } = {}
	if catModel ~= nil then
		catModel:PivotTo(CFrame.new(realm.origin + Vector3.new(0, r.dropHeight + 20, 0)))
		catModel.Parent = Context.folder() -- in the world now so Pose can bind it; far off and out of sight
		local bound = Pose.bind(catModel)
		rig = if bound ~= nil and not bound.usesMotors then bound else nil
		if rig ~= nil then
			-- drawn from the pose as bound every frame (as CafeWalk, #2329): a part read back a hair off is never
			-- taken as where the cat is, so it cannot drift away
			rest = Pose.rest(rig :: Pose.Rig)
		end
	end
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "EffectsRiftRun"
	grade.Enabled = false
	grade.Parent = Lighting

	-- streaks rushing past the camera and motes drifting round the cat
	local camPart = plain("RiftRunCamera", Vector3.new(0.2, 0.2, 0.2), WHITE)
	camPart.Transparency = 1
	camPart.Parent = realm.root
	local streaks = Particles.make(Presets.emitters.riftStreak, nil)
	streaks.Rate = 0
	streaks.EmissionDirection = Enum.NormalId.Back -- toward the camera, rushing past it
	streaks.Enabled = true
	streaks.Parent = camPart

	local meteors: { Meteor } = {}
	for _, m in Logic.riftMeteors(plan.leapAt) do
		local land = realm.origin
			+ Vector3.new(m.lane, 0, -(Logic.riftDistance(plan, m.at) + r.meteorAhead))
		local from = r.meteorFrom
		table.insert(meteors, {
			plan = m,
			rock = nil,
			start = land + Vector3.new(from.X * m.from, from.Y, from.Z),
			land = land,
			landed = false,
			landedAt = 0,
			emitter = nil,
		})
	end

	local start = camera.CFrame
	local subject = camera.CameraSubject
	local fovWas = camera.FieldOfView
	local module: any? = nil
	local promptsWere = ProximityPromptService.Enabled
	local began = os.clock()
	local cut = false
	local handed = false
	local landed = false
	local leapt = false
	local tore = false
	local darkened = false
	local lastDark = -1
	local passed = 0
	local kickAt = -10
	local kickSize = 0
	local wordAt = -10
	local eye = realm.origin + c.introEye
	local lastZ = 0
	local stride = 0
	local leapSide = 0
	local lastT = 0
	local afterSkip: (() -> ())? = nil
	local stopped = false

	local function stopRealm()
		if stopped then
			return
		end
		stopped = true
		RunService:UnbindFromRenderStep(STEP)
		local boundRig = rig
		if boundRig ~= nil then
			Pose.release(boundRig)
		end
		realm.root:Destroy()
		for _, gate in realm.gates do
			gate.model:Destroy() -- one not risen yet is not under the root
		end
		if catModel ~= nil then
			catModel:Destroy()
		end
		grade:Destroy()
		local cam = Workspace.CurrentCamera
		if cam ~= nil and cut then
			cam.CameraType = Enum.CameraType.Custom
			cam.CFrame = start
			cam.FieldOfView = fovWas
			if subject ~= nil and subject.Parent ~= nil then
				cam.CameraSubject = subject
			end
		end
		setControls(module, true)
		ProximityPromptService.Enabled = promptsWere
	end

	-- the white is up: hand over to the pool (or the screen), the white fading off over it
	local function handBack()
		if handed then
			return
		end
		handed = true
		stopRealm()
		beat("back", 0, rarity)
		local shown = screen
		if shown ~= nil then
			for _, bar in shown.bars do
				bar.Size = UDim2.fromScale(1, 0)
			end
			shown.word.TextTransparency = 1
			shown.ladder.Visible = false
			local fadeFrom = os.clock()
			local fade: RBXScriptConnection
			fade = RunService.RenderStepped:Connect(function()
				local k = (os.clock() - fadeFrom) / r.backOut
				if screen == nil or k >= 1 then
					fade:Disconnect()
					if screen ~= nil then
						(screen :: Screen).flash.BackgroundTransparency = 1
					end
					return
				end
				shown.flash.BackgroundColor3 = WHITE
				shown.flash.BackgroundTransparency = Logic.smoothstep01(k)
			end)
		end
		local ok, skip = pcall(back, reveal)
		if not ok or skip == nil then
			reveal()
			return
		end
		afterSkip = skip
	end

	local function passGate(gate: Gate, i: number, now: number)
		gate.passed = true
		gate.flareAt = now
		local scale = Logic.riftGateScale(i)
		local centre = gate.home.Position + Vector3.new(0, r.gateHeight / 2, 0)
		Particles.burst(
			"catchSparkle",
			centre,
			math.floor(r.gateSparkles + r.gateSparklesGrow * (i - 1)),
			gate.colour
		)
		Particles.burst("catchSparkle", centre, math.floor(r.gateSparkles * 0.6), WHITE)
		-- the upright shockwave through the arch
		local shock = plain(
			"Shock",
			Vector3.new(0.2, r.shockFrom, r.shockFrom),
			gate.colour,
			Enum.Material.Neon
		)
		shock.Shape = Enum.PartType.Cylinder
		shock.Transparency = 0.25
		shock.CFrame = CFrame.new(centre) * CFrame.Angles(0, math.pi / 2, 0)
		shock.Parent = realm.root
		local shockFrom = now
		local diameter = r.shockTo + r.shockGrow * (i - 1)
		local grow: RBXScriptConnection
		grow = RunService.Heartbeat:Connect(function()
			local k = (os.clock() - shockFrom) / r.shockSeconds
			if k >= 1 or shock.Parent == nil then
				grow:Disconnect()
				shock:Destroy()
				return
			end
			local e = 1 - (1 - k) * (1 - k)
			local d = r.shockFrom + (diameter - r.shockFrom) * e
			shock.Size = Vector3.new(0.2, d, d)
			shock.Transparency = 0.25 + 0.75 * k
		end)
		if i >= r.confettiFrom then
			local palette = if gate.tier == "mythic"
				then Presets.mysticPool.mythicColours
				elseif gate.tier == "secret" then Presets.bigTrait.secretColours
				else { gate.colour, Presets.palette.sparkle, Presets.palette.offwhite }
			Particles.confetti(centre + Vector3.new(0, 3, 0), math.floor(20 * scale), palette)
		end
		if i >= r.beamsFrom then
			for _, side in { -1, 1 } do
				Particles.beam(
					gate.home.Position + Vector3.new(side * (r.gateWidth / 2 + 0.7), 0, 0),
					gate.colour,
					2,
					30 + 6 * (i - r.beamsFrom),
					1.6
				)
			end
		end
		kickAt = now
		kickSize = c.fovKick * scale
		Context.shake(0.25, 0.03 * scale)
		wordAt = now
		local shown = screen
		if shown ~= nil then
			shown.word.Text = (
				(r.words :: { [string]: string })[gate.tier] or string.upper(gate.tier)
			) .. "!"
			shown.word.TextColor3 = gate.colour
			shown.wordSize.MaxTextSize = r.wordSize + r.wordGrow * (i - 1)
			addChip(shown, i, gate.tier, gate.colour)
		end
		beat("gate", i, gate.tier)
	end

	local function launch(m: Meteor)
		local rock = kit("CatCafe_RiftRun_Meteor")
		if rock == nil then
			local made = Instance.new("Model")
			made.Name = "RiftMeteor"
			local core = plain(
				"Rock",
				Vector3.new(r.meteorSize, r.meteorSize, r.meteorSize),
				Color3.fromRGB(70, 40, 36),
				Enum.Material.Basalt
			)
			core.Shape = Enum.PartType.Ball
			core.Parent = made
			local shell = plain(
				"Shell_Glow",
				Vector3.new(r.meteorSize * 1.15, r.meteorSize * 1.15, r.meteorSize * 1.15),
				Color3.fromRGB(255, 130, 60),
				Enum.Material.Neon
			)
			shell.Shape = Enum.PartType.Ball
			shell.Transparency = 0.55
			shell.Parent = made
			made.PrimaryPart = core
			rock = made
		end
		local model = rock :: Model
		local holder = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
		if holder ~= nil then
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 140, 70)
			light.Brightness = 3
			light.Range = 16
			light.Shadows = false
			light.Parent = holder
			local trail = Particles.make(Presets.emitters.riftMeteorFire, nil)
			trail.Rate = trail.Rate * (if lite then 0.5 else 1)
			trail.Enabled = true
			trail.Parent = holder
			m.emitter = trail
		end
		model:PivotTo(CFrame.new(m.start))
		model.Parent = realm.root
		m.rock = model
	end

	local function impact(m: Meteor, now: number)
		m.landed = true
		m.landedAt = now
		local emitter = m.emitter
		if emitter ~= nil then
			emitter.Enabled = false
		end
		Particles.burst("riftSpark", m.land + Vector3.new(0, 0.5, 0), r.meteorSparks, nil)
		Particles.burst(
			"smokePuff",
			m.land + Vector3.new(0, 0.8, 0),
			8,
			Color3.fromRGB(120, 100, 140)
		)
		Particles.ring(m.land + Vector3.new(0, 0.15, 0), Color3.fromRGB(255, 150, 80), 9, 0.5)
		Context.shake(0.3, r.meteorShake)
		beat("meteor", 0, rarity)
	end

	local function dark(k: number)
		if math.abs(k - lastDark) < 0.01 then
			return
		end
		lastDark = k
		for i, part in realm.sky do
			part.Color = realm.skyBase[i]:Lerp(BLACK, 0.92 * k)
		end
		for i, part in realm.glow do
			part.Color = realm.glowBase[i]:Lerp(BLACK, 0.8 * k)
		end
		local d = r.dark
		local g = r.grade
		grade.Brightness = g.brightness + (d.brightness - g.brightness) * k
		grade.Saturation = g.saturation + (d.saturation - g.saturation) * k
		grade.TintColor = g.tint:Lerp(d.tint, k)
	end

	-- a Secret's cat of stars over the rift, a star at a time
	local function drawConstellation()
		local b = Presets.bigTrait
		-- Review-QA on #4029: over the rift it was out of the low camera's view; it now draws in the dark ahead,
		-- just past the white Secret gate, where the cat runs toward it
		local centre = realm.origin
			+ Vector3.new(
				0,
				r.starCatHeight,
				-(r.gateFirst + r.gateGap * (#plan.gates - 1) + r.starCatBeyond)
			)
		for i, point in Logic.CAT_CONSTELLATION do
			task.delay((i - 1) * b.starGap, function()
				if stopped then
					return
				end
				local at = centre
					+ Vector3.new(point.X * r.starCatScale, point.Y * r.starCatScale, 0)
				local star =
					plain("StarCat", Vector3.new(1.8, 1.8, 1.8), r.secretColour, Enum.Material.Neon)
				star.Shape = Enum.PartType.Ball
				star.CFrame = CFrame.new(at)
				star.Parent = realm.root
				table.insert(realm.constellation, star)
				Particles.burst("catchSparkle", at, b.starSparkles, r.secretColour)
			end)
		end
	end

	local function step()
		local now = os.clock()
		local t = now - began
		local dt = math.clamp(t - lastT, 0, 0.1)
		lastT = t
		local character = Players.LocalPlayer.Character
		if t >= r.cap or character == nil or character.Parent == nil then
			handBack()
			return
		end
		local cam = Workspace.CurrentCamera
		if cam == nil then
			handBack()
			return
		end

		-- the screen
		local white, pink = Logic.riftFlash(plan, t)
		local shown = screen
		if shown ~= nil then
			shown.flash.BackgroundColor3 = WHITE:Lerp(r.flashPink, pink)
			shown.flash.BackgroundTransparency = 1 - white
			local barK = Logic.smoothstep01(t / r.flareIn)
			for _, bar in shown.bars do
				bar.Size = UDim2.fromScale(1, 0.1 * barK)
			end
			local w = now - wordAt
			if w < r.wordSeconds then
				local pop = if w < 0.12
					then 0.45 + 0.75 * Logic.smoothstep01(w / 0.12)
					elseif w < 0.24 then 1.2 - 0.2 * Logic.smoothstep01((w - 0.12) / 0.12)
					else 1
				shown.wordScale.Scale = pop
				local fade = Logic.smoothstep01((w - (r.wordSeconds - 0.3)) / 0.3)
				shown.word.TextTransparency = fade
				shown.wordInk.Transparency = fade
			else
				shown.word.TextTransparency = 1
				shown.wordInk.Transparency = 1
			end
		end

		if t >= plan.total then
			handBack()
			return
		end

		-- the cut into the realm, under the white
		if not cut then
			if t < r.flareIn then
				return
			end
			cut = true
			putBack = hideWindows()
			module = controls()
			setControls(module, false)
			ProximityPromptService.Enabled = false
			realm.root.Parent = Context.folder()
			grade.Enabled = true
			grade.Brightness = r.grade.brightness
			grade.Contrast = r.grade.contrast
			grade.Saturation = r.grade.saturation
			grade.TintColor = r.grade.tint
			beat("cut", 0, rarity)
		end

		-- the cat
		local origin = realm.origin
		local z = Logic.riftDistance(plan, t)
		local side, hop = Logic.riftDodge(t)
		local speed = if dt > 0 then (z - lastZ) / dt else 0
		lastZ = z
		local at: Vector3
		local tilt = 0
		if t < r.dropAt then
			at = origin + Vector3.new(0, r.dropHeight + 20, 0) -- out of sight above
		elseif t < r.dropAt + r.dropSeconds then
			local k = (t - r.dropAt) / r.dropSeconds
			at = origin + Vector3.new(0, r.dropHeight * (1 - k * k), 0)
		elseif t < plan.leapAt then
			at = origin + Vector3.new(side, hop, -z)
			leapSide = side
		else
			local k = (t - plan.leapAt) / r.leapSeconds
			local offset, nose = Logic.riftLeap(leapSide, k)
			at = origin + offset
			tilt = nose
			speed = 0
		end
		if not landed and t >= r.dropAt + r.dropSeconds then
			landed = true
			Particles.ring(origin + Vector3.new(0, 0.15, 0), r.edge, 7, 0.45)
			Particles.burst("dust", origin + Vector3.new(0, 0.3, 0), 10, r.stone[1])
			beat("land", 0, rarity)
		end
		if not leapt and t >= plan.leapAt then
			leapt = true
			Particles.burst("catchSparkle", at, 24, r.ringColour)
			beat("leap", 0, rarity)
		end
		local model = catModel
		if model ~= nil then
			-- leans into each hop aside and faces down the path (-Z); the leap's nose comes level by the rift
			local ahead = Logic.riftDodge(t + 0.05)
			local lean = if t < plan.leapAt
				then math.clamp((ahead - side) * -0.6, -0.35, 0.35)
				else 0
			local floor = CFrame.new(at) * CFrame.Angles(tilt, lean * 0.6, lean)
			local boundRig = rig
			if boundRig ~= nil and Pose.read(boundRig) then
				stride += math.max(speed, 0) * dt / Logic.strideLength(math.max(speed, 1))
				local o = Logic.idle("stray", t, boundRig.kind)
				if t >= plan.leapAt then
					Logic.gait(o, 16, 0.3) -- legs out, held mid stride through the air
				elseif hop > 0.05 then
					Logic.gait(o, math.max(speed, 6), stride)
					Logic.pullHopPose(o, 0.5)
				else
					Logic.gait(o, speed, stride)
				end
				Pose.holdRest(boundRig, rest, floor)
				Pose.draw(boundRig, o, -1)
			else
				model:PivotTo(floor)
			end
		end

		-- the gates rise as the cat nears and light as it passes
		for i, gate in realm.gates do
			if not gate.risen and gate.riseAt == nil and t >= gate.at - 1.5 then
				gate.riseAt = now
				gate.model.Parent = realm.root
				Particles.burst(
					"catchSparkle",
					gate.home.Position + Vector3.new(0, 2, 0),
					8,
					gate.colour
				)
			end
			local riseAt = gate.riseAt
			if riseAt ~= nil and not gate.risen then
				local k = math.clamp((now - riseAt) / 0.6, 0, 1)
				local e = 1 - (1 - k) ^ 3
				gate.model:PivotTo(gate.home - Vector3.new(0, (r.gateHeight + 20) * (1 - e), 0))
				gate.light.Brightness = 1.5 * e
				if k >= 1 then
					gate.risen = true
				end
			end
			if not gate.passed and t >= gate.at then
				passed = i
				passGate(gate, i, now)
			end
			local flareAt = gate.flareAt
			if flareAt ~= nil then
				local k = (now - flareAt) / r.gateFlare
				if k <= 1.2 then
					local colour = WHITE:Lerp(gate.colour, math.clamp(k, 0, 1))
					for _, part in gate.glows do
						part.Color = colour
					end
					gate.light.Brightness = 1.5 + 4 * math.max(0, 1 - k)
				end
			end
		end

		-- meteors
		for _, m in meteors do
			if m.rock == nil and not m.landed and t >= m.plan.at - r.meteorFall then
				launch(m)
			end
			local rock = m.rock
			if rock ~= nil then
				if not m.landed then
					local k = (t - (m.plan.at - r.meteorFall)) / r.meteorFall
					rock:PivotTo(
						CFrame.new(
							Logic.riftFall(
								m.start,
								m.land + Vector3.new(0, r.meteorSize * 0.4, 0),
								k
							)
						) * CFrame.Angles(t * 3, t * 2, 0)
					)
					if k >= 1 then
						impact(m, now)
					end
				else
					local k = (now - m.landedAt) / r.meteorStay
					if k >= 1 then
						rock:Destroy()
						m.rock = nil
					else
						rock:PivotTo(
							CFrame.new(
								m.land + Vector3.new(0, r.meteorSize * (0.4 - 0.9 * k * k), 0)
							)
						)
					end
				end
			end
		end

		-- a Secret's dark
		if plan.darkAt ~= nil then
			if not darkened and t >= (plan.darkAt :: number) + 0.25 then
				darkened = true
				beat("dark", 0, rarity)
				drawConstellation()
			end
			dark(Logic.riftDark(plan, t))
		end

		-- the rift
		placeRing(realm, Logic.riftOpen(plan, t))
		if not tore and t >= plan.leapAt - r.ringTear then
			tore = true
			Particles.burst("catchSparkle", realm.ringCentre, 40, r.ringCore)
			Particles.confetti(realm.ringCentre, 30, Presets.mysticPool.mythicColours)
			Context.shake(0.6, 0.06)
			beat("tear", 0, rarity)
		end

		-- the islands bob, the stars twinkle (slowly: well under once a second)
		for _, island in realm.islands do
			island.model:PivotTo(
				island.home + Vector3.new(0, math.sin(t * 0.7 + island.phase) * r.islandBob, 0)
			)
		end
		for _, star in realm.stars do
			local phase = star:GetAttribute("Phase")
			star.Transparency = 0.15
				+ 0.35
					* (0.5 + 0.5 * math.sin(
						t * 1.3 + (if type(phase) == "number" then phase else 0)
					))
		end

		-- the camera
		local catAt = at
		local wantEye: Vector3
		local wantLook: Vector3
		-- the camera half follows the cat across its lanes (offsets from the path's middle line)
		local across = catAt.X - origin.X
		local chaseEye =
			Vector3.new(origin.X + across * 0.5, origin.Y + c.up + hop * 0.3, catAt.Z + c.back)
		local chaseLook =
			Vector3.new(origin.X + across * 0.3, origin.Y + c.lookUp, catAt.Z - c.ahead)
		if t < r.runStart + 0.6 then
			local k = Logic.smoothstep01((t - r.dropAt) / (r.runStart + 0.6 - r.dropAt))
			wantEye = (origin + c.introEye):Lerp(chaseEye, k)
			wantLook = (origin + c.introLook):Lerp(chaseLook, k)
			eye = wantEye
		elseif t < plan.leapAt then
			wantEye = chaseEye
			wantLook = chaseLook
			eye = eye:Lerp(wantEye, math.min(1, dt * c.follow))
		else
			local k = Logic.smoothstep01((t - plan.leapAt) / r.leapSeconds)
			local leapEye = origin
				+ Vector3.new(c.leapEye.X, c.leapEye.Y, -r.leapFrom + c.leapEye.Z)
			wantEye = leapEye:Lerp(realm.ringCentre + Vector3.new(0, 0, 14), k * k)
			wantLook = catAt:Lerp(realm.ringCentre, k)
			eye = eye:Lerp(wantEye, math.min(1, dt * c.follow))
		end
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = CFrame.lookAt(eye, wantLook)
		local run = math.clamp(z / r.leapFrom, 0, 1)
		local kick = kickSize * math.max(0, 1 - (now - kickAt) / c.kickSeconds)
		cam.FieldOfView = c.fov + (c.fovEnd - c.fov) * run + kick
		camPart.CFrame = cam.CFrame * CFrame.new(0, 0, -14)
		streaks.Rate = (
			if t < plan.leapAt then r.streaks * math.clamp(speed / r.endSpeed, 0, 1.2) else 0
		) * (if lite then 0.5 else 1)
	end

	RunService:BindToRenderStep(STEP, Enum.RenderPriority.Camera.Value, step)
	beat("flare", 0, rarity) -- the whoosh into white over the pool
	task.delay(r.cap + 2, function()
		if not handed then
			handBack()
		end
		if not revealed then
			reveal()
		end
	end)

	return function()
		if revealed then
			return
		end
		if not handed then
			handed = true
			stopRealm()
			reveal()
			return
		end
		local skip: (() -> ())? = afterSkip
		afterSkip = nil
		if skip ~= nil then
			(skip :: () -> ())()
		end
		reveal()
	end
end

return RiftRun
