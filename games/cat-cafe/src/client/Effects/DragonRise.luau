--!strict
-- The Dragon Keep's stage-up cutscene (#4062; Design-Agent/notes/ticket-booth-and-dragon-keep.md 2.5; Derek asked for
-- rank-up animation, VFX and sound, "maybe even whole cutscenes"). The server has already raised Cinder a stage;
-- this only shows it, on this client:
--   1. Letterbox bars slide in, every window, banner and pop-up hides, and the camera swings to the Keep.
--   2. He curls up and an ember ball grows round him, heating from orange to white-gold with a low rumble.
--   3. The ball cracks with one bright flash, its shards fly, and he unfurls in his new look.
--   4. A happy roar. Every stage adds to it: 1 sparks, 2 smoke rings, 3 an ember ring and a light column, 4 gold
--      coins up the column, 5 flame confetti. Before its roar, stage 5 (Crowned) flies one lap of the castle and
--      lands on the tower, crown glinting.
--   5. The camera swings back to the player and everything is given back. Then the caller deals the cards.
-- About 7 s (12 s for stage 5), skippable by a tap after 1 s. Reduce Motion: a 2 s soft fade with the new look and
-- the roar, no shake, no flying.
--
--   local skip = DragonRise.play({ stage = 3, keep = yard.CFrame, colour = "ruby", dragon = cinder }, onDone)
--
-- `keep` is the yard centre on the ground, its LookVector out the gate (where the camera stands). `dragon` is the
-- owner's live Cinder, hidden on this client while the scene's own copies play and shown again after onDone (by
-- then the caller has swapped it to the new look). onDone runs exactly once, whatever happens, and a hard cap
-- (the plan's total plus Presets.dragonRise.cap) always gives the camera, controls, prompts and windows back.
-- Nothing random, and nothing flashes but the one crack. Model-Agent's dragons (ReplicatedStorage.Assets.Dragon,
-- CatCafe_Dragon_<Stage>, #4081: joints are child Models pivoted at their hinge, named ending _Neck, _Head, _Jaw,
-- _Tail1 to 3, _WingL, _WingR and four legs; `_Scale` parts take the scale colour) are used when they are there, else a stand-in with the same joints is drawn here. Switch
-- `dragonKeep` (shared/LiveFlags, Gameplay-Engineer's); in Studio the Workspace attribute DragonRiseTest (1 to 5)
-- plays it in front of you with the switch off. Client only; it sends nothing.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LiveFlags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags"))

local Context = require(script.Parent.Context)
local CutsceneShell = require(script.Parent.CutsceneShell)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local DragonRise = {}

-- The beats, for the sounds (Audio followDragonRise): "hush" as it starts and "done" as it ends (the music ducks
-- between), "swing" as the camera sets off, "curl" as the ember ball starts, "crack", "unfurl", "lap" and "land"
-- (stage 5), "roar" and "back". Listeners only listen.
export type Beat =
	"hush"
	| "swing"
	| "curl"
	| "crack"
	| "unfurl"
	| "lap"
	| "land"
	| "roar"
	| "back"
	| "done"
export type Info = {
	stage: number, -- the stage he has reached, 1 (Hatchling) to 5 (Crowned)
	keep: CFrame,
	colour: string?, -- the scale colour picked at stage 3 (a Presets.dragonRise.scales key)
	dragon: Model?,
	tower: CFrame?, -- stage 5: where he lands
	cheer: { Model }?, -- the Keep's cats, who hop while he changes
}

local listeners: { (beat: Beat, stage: number) -> () } = {}
local holds: { (on: boolean) -> () } = {}

local SWITCH = "dragonKeep"
local TEST_ATTRIBUTE = "DragonRiseTest"
local STEP = "EffectsDragonRise"
local KIT = "Dragon"
local JOINTS = {
	"Neck",
	"Head",
	"Jaw",
	"Tail1",
	"Tail2",
	"Tail3",
	"WingL",
	"WingR",
	"LegFL",
	"LegFR",
	"LegBL",
	"LegBR",
}
local FONT = Font.new(
	"rbxasset://fonts/families/FredokaOne.json",
	Enum.FontWeight.Regular,
	Enum.FontStyle.Normal
)
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local running = false

function DragonRise.onBeat(listener: (beat: Beat, stage: number) -> ())
	table.insert(listeners, listener)
end

-- Calls `listener(true)` as the cutscene starts and `listener(false)` as it ends: the controller holds the pop-ups
-- (UI.setCutscene) in between.
function DragonRise.onHold(listener: (on: boolean) -> ())
	table.insert(holds, listener)
end

local function beat(name: Beat, stage: number)
	for _, listener in listeners do
		task.spawn(listener, name, stage)
	end
end

local function hold(on: boolean)
	for _, listener in holds do
		task.spawn(listener, on)
	end
end

-- Studio only: the DragonRiseTest attribute's stage, or nil.
function DragonRise.testStage(): number?
	if not RunService:IsStudio() then
		return nil
	end
	local value = Workspace:GetAttribute(TEST_ATTRIBUTE)
	local stage = if type(value) == "number" then value else tonumber(value)
	return if stage ~= nil and Logic.dragonPlan(stage, false) ~= nil then stage else nil
end

-- Whether a stage up gets its cutscene now: the Keep's switch on (or the Studio test) and none already running.
function DragonRise.wanted(): boolean
	if running then
		return false
	end
	if DragonRise.testStage() ~= nil then
		return true
	end
	-- on only when the switch says so: before the key exists in LiveFlags an unset switch must not count as on
	return ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. SWITCH) == true
end

function DragonRise.playing(): boolean
	return running
end

-- Building -------------------------------------------------------------------------------------------------------

-- A dragon as Model-Agent builds them (#4081) and as the stand-in is drawn: the root Model is the body, pivoted at
-- its feet and facing -Z, and every joint is a child Model pivoted at its hinge (Neck > Head > Jaw, Tail1 > Tail2 >
-- Tail3, the wings and the legs), named ending _<Joint>. All parts are anchored; a joint is turned with PivotTo.
type Joint = { name: string, model: Model, parent: number, rest: CFrame } -- `rest`: its pivot from its parent's
type Rig = {
	model: Model,
	joints: { Joint }, -- parents before children; `parent` 0 is the root
	height: number,
	head: Model?,
	glints: { BasePart },
}

local function plain(name: string, size: Vector3, colour: Color3, material: Enum.Material?): Part
	local part = Context.effectPart(name, size, colour)
	part.Material = material or Enum.Material.SmoothPlastic
	return part
end

-- A round piece: a part drawn as an ellipsoid of its size, its middle at `at`, in `parent`.
local function round(
	parent: Instance,
	name: string,
	size: Vector3,
	colour: Color3,
	at: CFrame,
	material: Enum.Material?
): Part
	local part = plain(name, size, colour, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	part.CFrame = at
	part.Parent = parent
	return part
end

local function scaleColour(stage: number, colour: string?): Color3
	local scales = Presets.dragonRise.scales :: { [string]: Color3 }
	if stage >= 3 and colour ~= nil and scales[colour] ~= nil then
		return scales[colour]
	end
	return scales.pastel
end

local function endsWith(name: string, suffix: string): boolean
	return string.sub(name, -#suffix) == suffix
end

-- Reads a dragon's joints: every Model under it named ending _<Joint>, parents first.
local function bind(model: Model): Rig
	local joints: { Joint } = {}
	local function walk(parent: Instance, parentIndex: number, parentPivot: CFrame)
		for _, child in parent:GetChildren() do
			if not child:IsA("Model") then
				continue
			end
			local found: string? = nil
			for _, name in JOINTS do
				if endsWith(child.Name, "_" .. name) then
					found = name
					break
				end
			end
			if found ~= nil then
				local pivot = (child :: Model):GetPivot()
				table.insert(joints, {
					name = found,
					model = child :: Model,
					parent = parentIndex,
					rest = parentPivot:ToObjectSpace(pivot),
				})
				walk(child, #joints, pivot)
			else
				walk(child, parentIndex, parentPivot) -- a _Scale group and the like: its joints hang off ours
			end
		end
	end
	walk(model, 0, model:GetPivot())
	local glints: { BasePart } = {}
	for _, d in model:GetDescendants() do
		if
			d:IsA("BasePart") and (endsWith(d.Name, "Crown_Glow") or endsWith(d.Name, "Chest_Glow"))
		then
			table.insert(glints, d :: BasePart)
		end
	end
	local head: Model? = nil
	for _, joint in joints do
		if joint.name == "Head" then
			head = joint.model
		end
	end
	local _, size = model:GetBoundingBox()
	return { model = model, joints = joints, height = size.Y, head = head, glints = glints }
end

-- A child Model of `parent` named ..._<name>, pivoted at `hinge`.
local function group(parent: Instance, name: string, hinge: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "DragonRiseStandIn_" .. name
	model.WorldPivot = CFrame.new(hinge)
	model.Parent = parent
	return model
end

-- The stand-in for stage `stage`, standing on the origin and facing -Z: a round, big-headed little dragon with the
-- kit's joints, wings from the Whelp up, horns that grow, the Hatchling's shell cap and the Crowned's crown.
local function drawnDragon(stage: number, colour: Color3): Rig
	local d = Presets.dragonRise
	local h: number = d.stages[stage].height
	local function v(x: number, y: number, z: number): Vector3
		return Vector3.new(x, y, z) * h
	end
	local model = Instance.new("Model")
	model.Name = "DragonRiseStandIn"
	model.WorldPivot = CFrame.new()

	local bodyAt = v(0, 0.42, 0)
	round(model, "Body_Scale", v(0.55, 0.5, 0.78), colour, CFrame.new(bodyAt))
	round(model, "Belly", v(0.44, 0.4, 0.6), d.belly, CFrame.new(bodyAt + v(0, -0.07, -0.05)))
	local chest = round(
		model,
		"Chest_Glow",
		v(0.2, 0.2, 0.1),
		d.chest,
		CFrame.new(bodyAt + v(0, -0.02, -0.36)),
		Enum.Material.Neon
	)
	chest.Transparency = if stage >= 3 then 0.1 else 0.6

	local neck = group(model, "Neck", v(0, 0.56, -0.28))
	round(neck, "Neck_Scale", v(0.26, 0.32, 0.26), colour, CFrame.new(v(0, 0.66, -0.31)))
	local head = group(neck, "Head", v(0, 0.8, -0.33))
	local headAt = v(0, 0.92, -0.39)
	round(head, "Head_Scale", v(0.44, 0.4, 0.46), colour, CFrame.new(headAt))
	round(head, "Snout_Scale", v(0.28, 0.2, 0.24), colour, CFrame.new(headAt + v(0, -0.03, -0.24)))
	local jawHinge = headAt + v(0, -0.11, -0.14)
	local jaw = group(head, "Jaw", jawHinge)
	round(jaw, "Jaw", v(0.24, 0.08, 0.22), d.belly, CFrame.new(jawHinge + v(0, -0.02, -0.1)))
	for _, side in { -1, 1 } do
		round(
			head,
			"Eye",
			v(0.09, 0.11, 0.05),
			Color3.fromRGB(40, 28, 30),
			CFrame.new(headAt + v(side * 0.11, 0.05, -0.2))
		)
		round(
			head,
			"EyeShine",
			v(0.035, 0.04, 0.03),
			WHITE,
			CFrame.new(headAt + v(side * 0.1, 0.075, -0.225)),
			Enum.Material.Neon
		)
		if stage >= 2 then
			round(
				head,
				"Horn",
				v(0.07, 0.1 + 0.05 * stage, 0.07),
				d.horn,
				CFrame.new(headAt + v(side * 0.13, 0.2, 0.06))
					* CFrame.Angles(-0.35, 0, -side * 0.25)
			)
		end
	end
	if stage == 1 then
		round(
			head,
			"ShellCap",
			v(0.34, 0.16, 0.34),
			d.egg,
			CFrame.new(headAt + v(0, 0.19, 0.02)) * CFrame.Angles(0, 0, 0.12)
		)
	elseif stage == #d.stages then
		local crown = plain("Crown_Glow", v(0.09, 0.26, 0.26), d.gold, Enum.Material.Neon)
		crown.Shape = Enum.PartType.Cylinder
		crown.CFrame = CFrame.new(headAt + v(0, 0.23, 0.02)) * CFrame.Angles(0, 0, math.pi / 2)
		crown.Parent = head
	end

	local parent: Instance = model
	local hinge = bodyAt + v(0, -0.04, 0.34)
	for i = 1, 3 do
		local length = 0.34 - 0.06 * i
		local thick = 0.24 - 0.05 * i
		local tail = group(parent, "Tail" .. i, hinge)
		local middle = hinge + v(0, 0, length * 0.42)
		round(tail, "Tail" .. i .. "_Scale", v(thick, thick, length), colour, CFrame.new(middle))
		if i == 3 and stage >= 2 then
			round(
				tail,
				"TailTip",
				v(0.12, 0.12, 0.16),
				d.chest,
				CFrame.new(middle + v(0, 0, 0.1)),
				Enum.Material.Neon
			)
		end
		parent = tail
		hinge = middle + v(0, 0, length * 0.42)
	end

	for _, leg in
		{
			{ name = "LegFL", x = -1, z = -1 },
			{ name = "LegFR", x = 1, z = -1 },
			{ name = "LegBL", x = -1, z = 1 },
			{ name = "LegBR", x = 1, z = 1 },
		}
	do
		local at = bodyAt + v(leg.x * 0.2, -0.14, leg.z * 0.22)
		local piece = group(model, leg.name, at)
		round(
			piece,
			leg.name .. "_Scale",
			v(0.17, 0.3, 0.2),
			colour,
			CFrame.new(at + v(0, -0.13, 0))
		)
	end

	if stage >= 2 then
		local span: number = ({ 0, 0.34, 0.6, 0.78, 0.95 })[stage]
		for _, side in { -1, 1 } do
			local name = if side < 0 then "WingL" else "WingR"
			local at = bodyAt + v(side * 0.16, 0.2, -0.02)
			local wing = group(model, name, at)
			local middle = at + v(side * span / 2, 0, span * 0.12)
			local bone = plain(name .. "_Scale", v(span, 0.03, span * 0.62), colour)
			bone.CFrame = CFrame.new(middle)
			bone.Parent = wing
			local skin = plain("WingSkin", v(span * 0.8, 0.02, span * 0.44), d.belly)
			skin.CFrame = CFrame.new(middle + v(side * span * 0.04, -0.012, span * 0.1))
			skin.Parent = wing
		end
	end
	return bind(model)
end

-- Model-Agent's dragon for stage `stage`, made ready for this client: anchored, no collisions, no scripts, and the
-- `_Scale` parts in the scale colour. Nil when the kit has none.
local function kitDragon(stage: number, colour: Color3): Rig?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = if assets ~= nil then assets:FindFirstChild(KIT) else nil
	local name = "CatCafe_Dragon_" .. Presets.dragonRise.stages[stage].name
	local found = if folder ~= nil then folder:FindFirstChild(name) else nil
	if found == nil or not found:IsA("Model") then
		return nil
	end
	local model = (found :: Model):Clone() :: Model
	for _, d in model:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			local part = d :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			-- a part named ..._Scale, or any part of a ..._Scale group
			local group_ = part.Parent
			if
				endsWith(part.Name, "_Scale")
				or (group_ ~= nil and group_:IsA("Model") and endsWith(group_.Name, "_Scale"))
			then
				part.Color = colour
			end
		end
	end
	return bind(model)
end

-- The Hatchling's egg (what stage 1 hatches from): one spotted egg, with no joints.
local function drawnEgg(): Rig
	local d = Presets.dragonRise
	local h: number = d.stages[1].height * 0.9
	local model = Instance.new("Model")
	model.Name = "DragonRiseEgg"
	model.WorldPivot = CFrame.new()
	round(model, "Egg", Vector3.new(0.72, 1, 0.72) * h, d.egg, CFrame.new(0, 0.5 * h, 0))
	for i = 1, 5 do
		local a = i * 1.9
		local y = (0.25 + 0.12 * i) * h
		local r = 0.33 * h * math.sin(math.pi * (0.2 + 0.13 * i))
		round(
			model,
			"Spot",
			Vector3.new(0.14, 0.14, 0.05) * h,
			d.eggSpots,
			CFrame.lookAt(Vector3.new(math.cos(a) * r, y, math.sin(a) * r), Vector3.new(0, y, 0))
		)
	end
	return bind(model)
end

local function makeRig(stage: number, colour: string?): Rig
	if stage < 1 then
		return drawnEgg()
	end
	local tint = scaleColour(stage, colour)
	return kitDragon(stage, tint) or drawnDragon(stage, tint)
end

-- Stands a dragon at `at` (its feet) in a pose: the body leans about its middle and every joint turns about its own
-- hinge, parents first. With no `turns` it stands as built.
local function stand(rig: Rig, at: CFrame, turns: { [string]: Vector3 }?)
	local lean = if turns ~= nil then turns.Body else nil
	local root = at
	if lean ~= nil then
		local middle = CFrame.new(0, rig.height * 0.4, 0)
		root = at * middle * CFrame.Angles(lean.X, lean.Y, lean.Z) * middle:Inverse()
	end
	rig.model:PivotTo(root)
	local placed: { CFrame } = {}
	for i, joint in rig.joints do
		local from = if joint.parent == 0 then root else placed[joint.parent]
		local frame = from * joint.rest
		local turn = if turns ~= nil then turns[joint.name] else nil
		if turn ~= nil then
			frame *= CFrame.Angles(turn.X, turn.Y, turn.Z)
		end
		placed[i] = frame
		joint.model:PivotTo(frame)
	end
end

-- The front of his mouth, for the roar's sparks and smoke rings.
local function mouthOf(rig: Rig): CFrame?
	local head = rig.head
	if head == nil then
		return nil
	end
	local frame, size = head:GetBoundingBox()
	return CFrame.new(frame.Position)
		* head:GetPivot().Rotation
		* CFrame.new(0, -size.Y * 0.1, -size.Z * 0.55)
end

-- The screen: the bars, the one flash, the stage's name and the skip hint ---------------------------------------

type Screen = {
	gui: ScreenGui,
	flash: Frame,
	bars: { Frame },
	word: TextLabel,
	wordScale: UIScale,
	wordInk: UIStroke,
	sub: TextLabel,
	skip: TextLabel,
}

local function label(name: string, at: UDim2, size: UDim2, most: number): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.AnchorPoint = Vector2.new(0.5, 0.5)
	text.Position = at
	text.Size = size
	text.FontFace = FONT
	text.Text = ""
	text.TextScaled = true
	text.TextTransparency = 1
	text.TextColor3 = Presets.dragonRise.wordColour
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = most
	limit.MinTextSize = 12
	limit.Parent = text
	return text
end

local function makeScreen(): Screen?
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return nil
	end
	local d = Presets.dragonRise
	local gui = Instance.new("ScreenGui")
	gui.Name = "EffectsDragonRise"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = d.displayOrder

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

	local word = label("Word", UDim2.fromScale(0.5, 0.24), UDim2.new(0.9, 0, 0, 96), d.wordSize)
	local ink = Instance.new("UIStroke")
	ink.Color = d.wordInk
	ink.Thickness = 4
	ink.Transparency = 1
	ink.Parent = word
	local wordScale = Instance.new("UIScale")
	wordScale.Parent = word
	word.Parent = gui

	local sub = label("Sub", UDim2.fromScale(0.5, 0.345), UDim2.new(0.9, 0, 0, 34), 26)
	sub.TextColor3 = WHITE
	local subInk = Instance.new("UIStroke")
	subInk.Color = d.wordInk
	subInk.Thickness = 2
	subInk.Parent = sub
	sub.Parent = gui

	local skip = label("Skip", UDim2.fromScale(0.5, 0.955), UDim2.new(0.5, 0, 0, 22), 16)
	skip.TextColor3 = WHITE
	skip.Text = "Tap to skip"
	skip.Parent = gui

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
		wordInk = ink,
		sub = sub,
		skip = skip,
	}
end

-- Playing --------------------------------------------------------------------------------------------------------

type Flying = {
	part: BasePart,
	from: Vector3,
	velocity: Vector3,
	spin: Vector3,
	born: number,
	life: number,
}
type SmokeRing = { puffs: { BasePart }, frame: CFrame, born: number, size: number }
type Coin = { part: BasePart, born: number, index: number }

-- See the top of this file. Returns the skip, which ends the scene at once (after the plan's skipAfter a tap does
-- the same).
function DragonRise.play(info: Info, onDone: () -> ()): () -> ()
	local reduced = Context.reducedMotion()
	local plan = Logic.dragonPlan(info.stage, reduced)
	local camera = Workspace.CurrentCamera
	if plan == nil or running or camera == nil then
		task.spawn(onDone)
		return function() end
	end
	local d = Presets.dragonRise
	local c = d.camera
	local stage = plan.stage
	local st: any = d.stages[stage]
	local lite = Context.lite or Context.tier == "low"
	local keep = info.keep
	running = true
	hold(true)
	beat("hush", stage)

	local screen = makeScreen()
	local putBack = CutsceneShell.hideWindows()
	local module: any? = CutsceneShell.controls()
	CutsceneShell.setControls(module, false)
	local promptsWere = ProximityPromptService.Enabled
	ProximityPromptService.Enabled = false

	-- the scene's own copies: the look he had, and the one he has now (out of sight until the crack)
	local old = makeRig(stage - 1, info.colour)
	local new = makeRig(stage, info.colour)
	local far = CFrame.new(0, -500, 0)
	old.model.Parent = Context.folder()
	new.model.Parent = Context.folder()
	stand(old, if reduced then far else keep, nil)
	stand(new, far, nil)
	local tall = math.max(old.height, new.height)

	-- the live Cinder steps aside for them
	local hidden: { [BasePart]: number } = {}
	local function showLive(on: boolean)
		local live = info.dragon
		if live == nil then
			return
		end
		if on then
			for part, was in hidden do
				if part.Parent ~= nil then
					part.LocalTransparencyModifier = was
				end
			end
			table.clear(hidden)
			return
		end
		for _, descendant in live:GetDescendants() do
			if descendant:IsA("BasePart") then
				local part = descendant :: BasePart
				hidden[part] = part.LocalTransparencyModifier
				part.LocalTransparencyModifier = 1
			end
		end
	end
	if not reduced then
		showLive(false)
	end

	-- the ember ball
	local ballAt = keep.Position + Vector3.new(0, old.height * 0.45, 0)
	local ballSize = d.ball.size * math.max(old.height, new.height * 0.85)
	local ball = plain("EmberBall", Vector3.new(0.1, 0.1, 0.1), d.ball.cool, Enum.Material.Neon)
	ball.Shape = Enum.PartType.Ball
	ball.Transparency = 1
	ball.CFrame = CFrame.new(ballAt)
	ball.Parent = Context.folder()
	local ballLight = Instance.new("PointLight")
	ballLight.Color = d.ball.cool
	ballLight.Brightness = 0
	ballLight.Range = ballSize * 3
	ballLight.Shadows = false
	ballLight.Parent = ball
	local embers = Particles.make(Presets.emitters.ember, nil)
	embers.Rate = 0
	embers.Enabled = true
	embers.Parent = ball

	local tower = if info.tower ~= nil
		then keep:PointToObjectSpace(info.tower.Position)
		else d.crowned.tower
	local cheerHomes: { CFrame } = {}
	for i, cat in info.cheer or {} do
		cheerHomes[i] = cat:GetPivot()
	end

	local start = camera.CFrame
	local subject = camera.CameraSubject
	local typeWas = camera.CameraType
	local fovWas = camera.FieldOfView
	local began = os.clock()
	local finished = false
	local swung = false
	local curled = false
	local rumbled = 0
	local cracked = false
	local unfurled = false
	local lapping = false
	local landed = false
	local roared = false
	local backing = false
	local wordAt: number? = nil
	local backFrom: CFrame = start
	local lookAt = keep.Position + Vector3.new(0, tall * c.lookUp, 0)
	local shards: { Flying } = {}
	local rings: { SmokeRing } = {}
	local coins: { Coin } = {}
	local ringsLeft = 0
	local nextRing = 0
	local skipInput: RBXScriptConnection? = nil

	local function finish()
		if finished then
			return
		end
		finished = true
		RunService:UnbindFromRenderStep(STEP)
		if skipInput ~= nil then
			skipInput:Disconnect()
		end
		old.model:Destroy()
		new.model:Destroy()
		ball:Destroy()
		for _, shard in shards do
			shard.part:Destroy()
		end
		for _, ring in rings do
			for _, puff in ring.puffs do
				puff:Destroy()
			end
		end
		for _, coin in coins do
			coin.part:Destroy()
		end
		for i, cat in info.cheer or {} do
			if cat.Parent ~= nil then
				cat:PivotTo(cheerHomes[i])
			end
		end
		local cam = Workspace.CurrentCamera
		if cam ~= nil then
			cam.CameraType = if typeWas == Enum.CameraType.Scriptable
				then Enum.CameraType.Custom
				else typeWas
			cam.CFrame = start
			cam.FieldOfView = fovWas
			if subject ~= nil and subject.Parent ~= nil then
				cam.CameraSubject = subject
			end
		end
		CutsceneShell.setControls(module, true)
		ProximityPromptService.Enabled = promptsWere
		putBack()
		if screen ~= nil then
			screen.gui:Destroy()
			screen = nil
		end
		running = false
		hold(false)
		beat("done", stage)
		-- the caller swaps the live Cinder to his new look in onDone, so he is only shown again after it
		pcall(onDone)
		showLive(true)
	end

	-- where the standing dragon looks from: out by the gate, a little to one side, low
	local function shot(height: number, push: number, drift: number): (Vector3, Vector3)
		local distance = math.max(c.minDistance, c.distance * height + 4) * push
		local eye = keep:PointToWorldSpace(
			Vector3.new(c.side * distance + drift * height, c.up * height + 1.5, -distance)
		)
		return eye, keep.Position + Vector3.new(0, height * c.lookUp, 0)
	end

	local function crack(now: number, ground: Vector3)
		cracked = true
		ball.Transparency = 1
		ballLight.Brightness = 0
		embers.Rate = 0
		stand(old, far, nil)
		beat("crack", stage)
		if reduced then
			return
		end
		local k = d.crack
		local count = k.shards + k.shardsGrow * (stage - 1)
		if lite then
			count = math.ceil(count / 2)
		end
		for i = 1, count do
			local way = Logic.dragonShard(i, count)
			local shard = plain(
				"Shard",
				Vector3.new(0.12, 0.5, 0.4) * (ballSize / 4),
				d.ball.hot:Lerp(d.ball.cool, (i % 3) / 2),
				Enum.Material.Neon
			)
			shard.Parent = Context.folder()
			table.insert(shards, {
				part = shard :: BasePart,
				from = ballAt + way * (ballSize * 0.4),
				velocity = way * k.shardSpeed * math.max(1, ballSize / 5),
				spin = Vector3.new(4 + i % 3, 3 + i % 4, 2 + i % 5),
				born = now,
				life = k.shardSeconds,
			})
		end
		Particles.ring(
			ground + Vector3.new(0, 0.15, 0),
			d.ball.hot,
			k.ring + k.ringGrow * (stage - 1),
			0.7
		)
		Particles.burst("catchSparkle", ballAt, 24, d.flame[2])
		Particles.burst("riftSpark", ballAt, 16, nil)
		Context.shake(0.35, k.shake)
	end

	local function smokeRing(now: number)
		local frame = mouthOf(new)
		if frame == nil then
			return
		end
		local puffs: { BasePart } = {}
		local count = if lite then math.ceil(d.roar.smokeRingPuffs / 2) else d.roar.smokeRingPuffs
		for _ = 1, count do
			local size = new.height * 0.07
			local puff =
				plain("SmokeRing", Vector3.new(size, size, size), Color3.fromRGB(236, 232, 228))
			puff.Shape = Enum.PartType.Ball
			puff.Transparency = 0.35
			puff.Parent = Context.folder()
			table.insert(puffs, puff :: BasePart)
		end
		table.insert(
			rings,
			{ puffs = puffs, frame = frame :: CFrame, born = now, size = new.height * 0.1 }
		)
	end

	local function roar(now: number, ground: Vector3)
		roared = true
		beat("roar", stage)
		wordAt = now
		local shown = screen
		if shown ~= nil then
			shown.word.Text = string.upper(st.name) .. "!"
			shown.sub.Text = "Stage " .. stage .. " of " .. #d.stages
		end
		if reduced then
			return
		end
		local front = mouthOf(new)
		local mouth = if front ~= nil
			then front.Position
			else ground + Vector3.new(0, new.height, 0)
		Particles.burst("catchSparkle", mouth, st.sparks, d.flame[2])
		Particles.burst("riftSpark", mouth, math.floor(st.sparks / 2), nil)
		Context.shake(0.5, d.roar.shake + d.roar.shakeGrow * (stage - 1))
		ringsLeft = st.smokeRings or 0
		nextRing = now + 0.1
		if st.emberRing ~= nil then
			Particles.ring(ground + Vector3.new(0, 0.15, 0), d.flame[1], st.emberRing, 0.9)
			task.delay(0.22, function()
				if not finished then
					Particles.ring(ground + Vector3.new(0, 0.15, 0), d.gold, st.emberRing * 1.25, 1)
				end
			end)
		end
		if st.column ~= nil then
			Particles.beam(ground, d.chest, 3, st.column, 1.6)
		end
		if st.coins ~= nil then
			local count: number = if lite then math.ceil(st.coins / 2) else st.coins
			for i = 1, count do
				local coin = plain("Coin", Vector3.new(0.12, 0.7, 0.7), d.gold, Enum.Material.Neon)
				coin.Shape = Enum.PartType.Cylinder
				coin.Parent = Context.folder()
				table.insert(coins, { part = coin :: BasePart, born = now, index = i })
			end
		end
		if st.confetti ~= nil then
			Particles.confetti(ground + Vector3.new(0, new.height + 2, 0), st.confetti, d.flame)
			for _, side in { -1, 1 } do
				Particles.beam(
					ground + keep.RightVector * (side * new.height * 0.8),
					d.flame[1],
					2,
					st.column or 30,
					1.6
				)
			end
		end
		for _, glint in new.glints do
			Particles.burst("crownGlint", glint.Position, 6, nil)
		end
	end

	local function step()
		local now = os.clock()
		local t = now - began
		local character = Players.LocalPlayer.Character
		local cam = Workspace.CurrentCamera
		if t >= plan.total or character == nil or character.Parent == nil or cam == nil then
			finish()
			return
		end

		-- the screen
		local shown = screen
		if shown ~= nil then
			shown.flash.BackgroundTransparency = 1 - Logic.dragonFlash(plan, t)
			local bars = Logic.smoothstep01(t / 0.4)
				* (1 - Logic.smoothstep01((t - plan.backAt) / (plan.total - plan.backAt)))
			for _, bar in shown.bars do
				bar.Size = UDim2.fromScale(1, 0.09 * bars)
			end
			local skippable = t >= plan.skipAfter and t < plan.backAt
			shown.skip.TextTransparency = if skippable then 0.35 else 1
			local since = if wordAt ~= nil then now - wordAt else -1
			if since >= 0 and since < d.wordSeconds then
				local pop = if reduced
					then 1
					elseif since < 0.14 then 0.4 + 0.8 * Logic.smoothstep01(since / 0.14)
					elseif since < 0.28 then 1.2 - 0.2 * Logic.smoothstep01(
						(since - 0.14) / 0.14
					)
					else 1
				shown.wordScale.Scale = pop
				local fade = math.max(
					1 - Logic.smoothstep01(since / 0.2),
					Logic.smoothstep01((since - (d.wordSeconds - 0.4)) / 0.4)
				)
				shown.word.TextTransparency = fade
				shown.wordInk.Transparency = fade
				shown.sub.TextTransparency = fade
			else
				shown.word.TextTransparency = 1
				shown.wordInk.Transparency = 1
				shown.sub.TextTransparency = 1
			end
		end

		if not swung then
			swung = true
			beat("swing", stage)
		end

		-- where he stands: the yard, or (stage 5, from the lap on) in the air and then on the tower
		local lapAt, landAt = plan.lapAt, plan.landAt
		local flying = lapAt ~= nil and landAt ~= nil and t > lapAt and t < landAt
		local home = keep
		local flap = 0
		if lapAt ~= nil and landAt ~= nil and t > lapAt then
			local cr = d.crowned
			local at = Logic.dragonLap(plan, t, cr.lapRadius, cr.lapHeight, tower)
			if flying then
				local ahead = Logic.dragonLap(plan, t + 0.06, cr.lapRadius, cr.lapHeight, tower)
				local way = ahead - at
				local frame = if way.Magnitude > 1e-3
					then CFrame.lookAt(at, at + Vector3.new(way.X, way.Y * 0.5, way.Z))
					else CFrame.new(at)
				home = keep * frame * CFrame.Angles(0, 0, -0.3)
				flap = math.sin(2 * math.pi * cr.flapHz * (t - lapAt)) * cr.flap
			else
				home = keep * CFrame.new(at)
			end
			if not lapping then
				lapping = true
				beat("lap", stage)
			end
			if not landed and t >= landAt then
				landed = true
				beat("land", stage)
				local ground = home.Position
				Particles.ring(ground + Vector3.new(0, 0.15, 0), d.gold, 14, 0.6)
				Particles.burst("dust", ground + Vector3.new(0, 0.4, 0), 10, nil)
				Context.shake(0.3, 0.08)
			end
		end
		local ground = home.Position

		-- the ember ball and its crack
		local curl = Logic.dragonCurl(plan, t)
		local roarK = Logic.dragonRoar(plan, t)
		if not cracked then
			local grow, heat = Logic.dragonBall(plan, t)
			if grow > 0 then
				if not curled then
					curled = true
					beat("curl", stage)
				end
				local size = ballSize * (0.15 + 0.85 * grow) * (1 + 0.03 * math.sin(t * 5))
				ball.Size = Vector3.new(size, size, size)
				ball.CFrame = CFrame.new(ballAt)
				ball.Color = d.ball.cool:Lerp(d.ball.hot, heat)
				ball.Transparency = d.ball.transparency
					+ (d.ball.solid - d.ball.transparency) * math.max(heat, grow * 0.3)
				ballLight.Color = ball.Color
				ballLight.Brightness = d.ball.light * (0.3 * grow + 0.7 * heat)
				embers.Rate = d.ball.embers * grow * (if lite then 0.5 else 1)
			end
			-- a low rumble while it heats, in two swells
			local heatFrom = plan.crackAt - d.heatSeconds
			if not reduced and rumbled < 2 and t >= heatFrom + rumbled * d.heatSeconds / 2 then
				rumbled += 1
				Context.shake(d.heatSeconds / 2, d.ball.rumble * rumbled)
			end
			if t >= plan.crackAt then
				crack(now, ground)
			end
		end
		if cracked and not unfurled and t >= plan.unfurlEnd then
			unfurled = true
			beat("unfurl", stage)
		end
		if not roared and t >= plan.roarAt then
			roar(now, ground)
		end

		-- the two looks
		local sway = math.sin(t * 1.7)
		if not cracked then
			if #old.joints > 0 then
				local turns, drop =
					Logic.dragonPose(curl, 0, 0.25 * (1 - curl), 0, sway * (1 - curl))
				stand(old, keep * CFrame.new(0, -drop * old.height, 0), turns)
			else
				-- the egg rocks as it warms
				stand(old, keep * CFrame.Angles(0, 0, math.sin(t * 7) * 0.09 * curl), nil)
			end
		else
			local spread = if flying then 1 else (1 - curl) * (0.55 + 0.45 * roarK)
			local turns, drop = Logic.dragonPose(curl, roarK, spread, flap, sway * (1 - curl))
			local hop = if reduced
				then 0
				else d.roar.hop * new.height * math.sin(
					math.pi * math.clamp((t - plan.roarAt) / 0.5, 0, 1)
				)
			stand(new, home * CFrame.new(0, hop - drop * new.height, 0), turns)
		end

		-- the Keep's cats hop while he changes
		if not reduced and t > plan.curlAt and t < plan.roarAt + d.roarSeconds then
			for i, cat in info.cheer or {} do
				if cat.Parent ~= nil then
					local up = math.abs(math.sin((t - plan.curlAt) * 4 + i)) * 0.6
					cat:PivotTo(cheerHomes[i] + Vector3.new(0, up, 0))
				end
			end
		end

		-- shards, smoke rings and coins
		for i = #shards, 1, -1 do
			local shard = shards[i]
			local age = now - shard.born
			if age >= shard.life then
				shard.part:Destroy()
				table.remove(shards, i)
			else
				local at = shard.from + shard.velocity * age + Vector3.new(0, -14 * age * age, 0)
				shard.part.CFrame = CFrame.new(at)
					* CFrame.Angles(shard.spin.X * age, shard.spin.Y * age, shard.spin.Z * age)
				shard.part.Transparency = Logic.smoothstep01(age / shard.life)
			end
		end
		if ringsLeft > 0 and now >= nextRing then
			ringsLeft -= 1
			nextRing = now + 0.28
			smokeRing(now)
		end
		for i = #rings, 1, -1 do
			local ring = rings[i]
			local k = (now - ring.born) / d.roar.smokeRingSeconds
			if k >= 1 then
				for _, puff in ring.puffs do
					puff:Destroy()
				end
				table.remove(rings, i)
			else
				local e = 1 - (1 - k) * (1 - k)
				local radius = new.height * (0.08 + 0.3 * e)
				local frame = ring.frame
					* CFrame.new(0, new.height * 0.1 * e, -new.height * 0.9 * e)
				for j, puff in ring.puffs do
					local a = j / #ring.puffs * 2 * math.pi + k
					puff.CFrame = frame * CFrame.new(math.cos(a) * radius, math.sin(a) * radius, 0)
					local size = ring.size * (1 + 1.6 * e)
					puff.Size = Vector3.new(size, size, size)
					puff.Transparency = 0.35 + 0.65 * k
				end
			end
		end
		for i = #coins, 1, -1 do
			local coin = coins[i]
			local k = (now - coin.born - coin.index * 0.03) / d.roar.coinSeconds
			if k >= 1 then
				coin.part:Destroy()
				table.remove(coins, i)
			elseif k > 0 then
				-- up the column in a widening spiral, turning as they go
				local a = coin.index * 2.4 + k * 6
				local radius = new.height * 0.5 * (0.4 + 0.6 * k)
				local rise = 1 + (st.column or 30) * 0.4 * k
				coin.part.CFrame = CFrame.new(
					ground + Vector3.new(math.cos(a) * radius, rise, math.sin(a) * radius)
				) * CFrame.Angles(k * 9, k * 7 + coin.index, 0)
				coin.part.Transparency = Logic.smoothstep01((k - 0.7) / 0.3)
			else
				coin.part.Transparency = 1
			end
		end

		-- the camera
		if reduced then
			-- cut to the Keep under the white, and back under the white at the end
			local r = d.reduced
			local half = (plan.total - r.outAt) / 2
			if t >= r.fadeSeconds and t < r.outAt + half then
				if not cracked then
					crack(now, ground)
				end
				local eye, look = shot(new.height, 1, 0)
				cam.CameraType = Enum.CameraType.Scriptable
				cam.CFrame = CFrame.lookAt(eye, look)
				cam.FieldOfView = c.fov
				showLive(false)
			elseif t >= r.outAt + half then
				cam.CameraType = Enum.CameraType.Custom
				cam.CFrame = start
				cam.FieldOfView = fovWas
			end
			return
		end
		local wantEye: Vector3
		local wantLook: Vector3
		local fov = c.fov
		if not cracked then
			local drift = c.drift * math.clamp((t - plan.swing) / (plan.crackAt - plan.swing), 0, 1)
			wantEye, wantLook = shot(tall, 1, drift)
		elseif flying or (landAt ~= nil and t >= landAt) then
			local into = Logic.smoothstep01((t - (lapAt :: number)) / 0.7)
			local yardEye, _ = shot(new.height, c.push, c.drift)
			local lapEye = keep:PointToWorldSpace(c.lapEye)
			wantEye = yardEye:Lerp(lapEye, into)
			wantLook = ground + Vector3.new(0, new.height * 0.5, 0)
			fov = c.fov + (c.lapFov - c.fov) * into
			if landAt ~= nil and t >= landAt then
				-- low out front, looking up at him on the tower
				local settle = Logic.smoothstep01((t - landAt) / 0.8)
				local distance = math.max(c.minDistance, c.distance * new.height + 4)
				local towerEye = keep:PointToWorldSpace(
					Vector3.new(
						tower.X * 0.5,
						math.max(3, tower.Y * 0.35),
						tower.Z - distance * 1.5
					)
				)
				wantEye = lapEye:Lerp(towerEye, settle)
				fov = c.lapFov + (c.fov - c.lapFov) * settle
			end
		else
			-- one slow push in on the new look
			local push = Logic.smoothstep01(
				(t - plan.crackAt) / math.max(plan.roarAt + 0.5 - plan.crackAt, 1e-3)
			)
			wantEye, wantLook =
				shot(tall + (new.height - tall) * push, 1 + (c.push - 1) * push, c.drift)
		end
		lookAt = lookAt:Lerp(wantLook, 0.2)
		local scene = CFrame.lookAt(wantEye, lookAt)
		local frame: CFrame
		if t < plan.swing then
			frame = start:Lerp(scene, Logic.smoothstep01(t / plan.swing))
			fov = fovWas + (c.fov - fovWas) * Logic.smoothstep01(t / plan.swing)
		elseif t >= plan.backAt then
			if not backing then
				backing = true
				backFrom = cam.CFrame
				beat("back", stage)
				-- he is back in the yard for the hand over, in his new look (the caller's live one takes over)
			end
			local k = Logic.smoothstep01((t - plan.backAt) / (plan.total - plan.backAt))
			frame = backFrom:Lerp(start, k)
			fov = fov + (fovWas - fov) * k
		else
			frame = scene
		end
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = frame
		cam.FieldOfView = fov
	end

	RunService:BindToRenderStep(STEP, Enum.RenderPriority.Camera.Value, step)
	skipInput = UserInputService.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		local tap = kind == Enum.UserInputType.MouseButton1
			or kind == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA
			or input.KeyCode == Enum.KeyCode.Space
			or input.KeyCode == Enum.KeyCode.Return
		if tap and os.clock() - began >= plan.skipAfter then
			finish()
		end
	end)
	task.delay(plan.total + d.cap, finish)
	return finish
end

-- Studio only: the Workspace attribute DragonRiseTest (1 to 5, or "3,ruby" for a scale colour) plays that stage up
-- 30 studs in front of you, facing you, with the switch off (Review-QA).
if RunService:IsStudio() then
	Workspace:GetAttributeChangedSignal(TEST_ATTRIBUTE):Connect(function()
		local value = Workspace:GetAttribute(TEST_ATTRIBUTE)
		local text = if type(value) == "number" then tostring(value) else value
		if type(text) ~= "string" then
			return
		end
		local parts = string.split(text, ",")
		local stage = tonumber(parts[1])
		local character = Players.LocalPlayer.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if stage == nil or root == nil or not root:IsA("BasePart") or running then
			return
		end
		local frame = (root :: BasePart).CFrame
		local flat = Vector3.new(frame.LookVector.X, 0, frame.LookVector.Z)
		if flat.Magnitude < 1e-3 then
			flat = Vector3.new(0, 0, -1)
		end
		local feet = frame.Position - Vector3.new(0, 3, 0)
		local yard = feet + flat.Unit * 30
		DragonRise.play({
			stage = stage,
			keep = CFrame.lookAt(yard, Vector3.new(feet.X, yard.Y, feet.Z)),
			colour = parts[2],
		}, function() end)
	end)
end

return DragonRise
