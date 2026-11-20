--!strict
-- #5284 Cat Companion unlock scene (Derek 2026-11-18 16:42 UTC: "make the cat companion ... unlock at tier 2 with a
-- scene make sure it doesn't overlap other cutscenes"). About 8 s: a quick fade, and the camera stands in front of the
-- player, a little low, on a slow push in; one of the player's cats trots in from screen right and stops beside them;
-- pink hearts puff over it, then "CAT COMPANION UNLOCKED!" with the cat's name and one line; a quick fade back and
-- control returns. One tap, click, key or gamepad button skips it (after `skipAfter`). No black bars (Derek #4366).
-- Reduce Motion: no push in, and the cat is already beside the player when the scene opens. Numbers in
-- Presets.companionCut.
--
-- Gameplay-Engineer owns the trigger (Controllers/CompanionSceneController, switch companionScene): once, after the
-- first Tier 2 rank up, only while nothing else is on screen, with UI.setCutscene and UI.tips.clearStage around it.
-- It calls CompanionUnlockCut.play(catId, done). play returns false, and done is never called, when it cannot run:
-- no cat model for `catId`, no character, another script holds the camera or a cut is already playing. Then the
-- caller shows the card instead. Otherwise done(outcome) comes once, "played" or "skipped". onCat(listener) tells
-- Sound when the cat reaches the player. This client only; no remotes. The walking cat is a local copy, anchored and
-- not hit by anything, gone when the scene ends.
--
-- #5550 (switch `cutsQuick`, read as the scene starts): the quick scene of Presets.companionCut.quick, about 3 s with no
-- skip and a shorter line, over by `cap` seconds past its end whatever happens. Off keeps the scene above exactly.
-- Derek 2026-11-20 13:20 UTC then cut the scene: with `cutsQuick` on, CompanionSceneController shows its quick card
-- instead and play returns false (the caller's card), so the quick numbers stay only for a later call.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local FollowLogic = require(Shared:WaitForChild("FollowLogic"))

local Context = require(script.Parent.Context)
local CutsceneShell = require(script.Parent.CutsceneShell)
local Logic = require(script.Parent.Logic)
local Presets = require(script.Parent.Presets)
-- Pose and PetCat (which needs Cats) load at the first play, so the pure timeline loads on its own (specs, Sound)
type PoseModule = typeof(require(script.Parent.Pose))
local Pose: PoseModule = nil :: any

local CompanionUnlockCut = {}

local STEP = "EffectsCompanionUnlockCut"
local FONT_ID = "rbxasset://fonts/families/FredokaOne.json"
local QUICK_FLAG = "LiveFlag_cutsQuick"

local running = false
local catListeners: { (at: Vector3) -> () } = {}

-- Where the scene is at `t` seconds: the black fade's opacity (0 clear, 1 black), whether the camera is on the scene,
-- the push in 0 to 1, how far the cat has walked 0 to 1, and the label's opacity. Pure.
function CompanionUnlockCut.at(
	t: number,
	p: typeof(Presets.companionCut)
): (number, boolean, number, number, number)
	local fade = 0
	if t < p.fade then
		fade = t / p.fade
	elseif t < p.fade * 2 then
		fade = 1 - (t - p.fade) / p.fade
	elseif t >= p.endAt and t < p.endAt + p.fade then
		fade = (t - p.endAt) / p.fade
	elseif t >= p.endAt + p.fade then
		fade = 1 - math.min(1, (t - p.endAt - p.fade) / p.fade)
	end
	local there = t >= p.fade and t < p.endAt + p.fade
	local push = math.clamp((t - p.fade) / math.max(p.endAt - p.fade, 1e-6), 0, 1)
	local walk = math.clamp((t - p.walkAt) / math.max(p.walkSeconds, 1e-6), 0, 1)
	local label = 0
	if t >= p.labelAt and t < p.endAt then
		label = math.min(1, (t - p.labelAt) / p.labelIn)
	elseif t >= p.endAt then
		label = math.max(0, 1 - (t - p.endAt) / p.fade)
	end
	return math.clamp(fade, 0, 1), there, push, walk, label
end

-- The numbers a scene plays with: Presets.companionCut, with its `quick` fields over them when `quick`. Pure.
function CompanionUnlockCut.preset(quick: boolean): typeof(Presets.companionCut)
	local base = Presets.companionCut
	if not quick then
		return base
	end
	local out = table.clone(base) :: { [string]: any }
	for key, value in base.quick :: { [string]: any } do
		out[key] = value
	end
	return out :: any
end

-- The whole scene's length.
function CompanionUnlockCut.length(p: typeof(Presets.companionCut)): number
	return p.endAt + p.fade * 2
end

-- The line under the title for a cat called `name` (nil: no name known); `quick`, the quick scene's shorter line. Pure.
function CompanionUnlockCut.line(name: string?, quick: boolean?): string
	local p = CompanionUnlockCut.preset(quick == true)
	if name == nil or name == "" then
		return p.lineNoName
	end
	return (p.line :: string):format(name)
end

function CompanionUnlockCut.onCat(listener: (at: Vector3) -> ())
	table.insert(catListeners, listener)
end

function CompanionUnlockCut.playing(): boolean
	return running
end

-- The cat's model, scripts gone, every part anchored and out of the way of rays, touches and collisions.
local function cloneCat(catId: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets == nil then
		return nil
	end
	local ok, name = pcall(Catalog.catModelName, catId)
	if not ok or type(name) ~= "string" then
		return nil
	end
	local source = assets:FindFirstChild(name)
	if source == nil or not source:IsA("Model") then
		return nil
	end
	local copy = (source :: Model):Clone() :: Model
	for _, descendant in copy:GetDescendants() do
		if descendant:IsA("BaseScript") or descendant:IsA("ModuleScript") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	copy.Name = "CompanionUnlockCat"
	return copy
end

type Screen = { gui: ScreenGui, black: Frame, title: TextLabel, name: TextLabel, line: TextLabel }

local function label(
	parent: Instance,
	name: string,
	text: string,
	size: number,
	y: number,
	colour: Color3
): TextLabel
	local made = Instance.new("TextLabel")
	made.Name = name
	made.BackgroundTransparency = 1
	made.AnchorPoint = Vector2.new(0.5, 0.5)
	made.Position = UDim2.fromScale(0.5, y)
	made.Size = UDim2.new(0.9, 0, 0, size * 1.3)
	made.FontFace = Font.new(FONT_ID, Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	made.TextSize = size
	made.TextWrapped = true
	made.TextColor3 = colour
	made.TextTransparency = 1
	made.Text = text
	made.ZIndex = 2
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = math.max(2, size / 14)
	stroke.Color = Color3.fromRGB(60, 36, 20)
	stroke.Transparency = 1
	stroke.Parent = made
	made.Parent = parent
	return made
end

local function makeScreen(catName: string?, quick: boolean): Screen?
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return nil
	end
	local p = Presets.companionCut
	local gui = Instance.new("ScreenGui")
	gui.Name = "EffectsCompanionUnlockCut"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = p.displayOrder
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local black = Instance.new("Frame")
	black.Name = "Fade"
	black.Size = UDim2.fromScale(1, 1)
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	black.BackgroundTransparency = 1
	black.BorderSizePixel = 0
	black.ZIndex = 3
	black.Parent = gui
	local view = Workspace.CurrentCamera
	local small = view ~= nil and view.ViewportSize.Y < p.smallScreen
	local k = if small then p.smallScale else 1
	local screen = {
		gui = gui,
		black = black,
		title = label(
			gui,
			"Unlocked",
			p.title,
			math.floor(p.titleSize * k),
			p.titleY,
			Presets.palette.golden
		),
		name = label(
			gui,
			"Cat",
			catName or "",
			math.floor(p.nameSize * k),
			p.nameY,
			Color3.new(1, 1, 1)
		),
		line = label(
			gui,
			"Line",
			CompanionUnlockCut.line(catName, quick),
			math.floor(p.lineSize * k),
			p.lineY,
			Color3.new(1, 1, 1)
		),
	}
	gui.Parent = playerGui
	return screen
end

local function drawLabels(screen: Screen, a: number)
	for _, text in { screen.title, screen.name, screen.line } do
		text.TextTransparency = 1 - a
		local stroke = text:FindFirstChildOfClass("UIStroke")
		if stroke ~= nil then
			(stroke :: UIStroke).Transparency = 1 - a
		end
	end
end

-- How far the camera can stand back from `look` toward `eye` before something solid is in the way (characters, the
-- cat and see-through parts do not count).
local function clearTo(look: Vector3, eye: Vector3, skip: { Instance }): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = table.clone(skip)
	local way = eye - look
	for _ = 1, 6 do
		params.FilterDescendantsInstances = list
		local hit = Workspace:Raycast(look, way, params)
		if hit == nil then
			return way.Magnitude
		end
		if hit.Instance.Transparency < 0.8 then
			return (hit.Position - look).Magnitude
		end
		table.insert(list, hit.Instance)
	end
	return 0
end

-- Plays the scene with the cat `catId`; true when it took the camera (see the top). `done(outcome)` once at the end.
function CompanionUnlockCut.play(
	catId: string?,
	done: (outcome: "played" | "skipped") -> ()
): boolean
	if type(catId) ~= "string" or running then
		return false
	end
	if ReplicatedStorage:GetAttribute(QUICK_FLAG) == true then
		return false -- #5550: no companion scene with cutsQuick on
	end
	local camera = Workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if
		type(catId) ~= "string"
		or running
		or camera == nil
		or camera.CameraType ~= Enum.CameraType.Custom
		or root == nil
		or not root:IsA("BasePart")
	then
		return false
	end
	local model = cloneCat(catId :: string)
	if model == nil then
		return false
	end
	if Pose == nil then
		Pose = require(script.Parent.Pose) :: any
	end
	local rig = Pose.bind(model)
	if rig == nil then
		model:Destroy()
		return false
	end
	local quick = ReplicatedStorage:GetAttribute(QUICK_FLAG) == true
	local p = CompanionUnlockCut.preset(quick)
	local reduced = Context.reducedMotion()
	local rootPart = root :: BasePart
	local humanoid = (character :: Model):FindFirstChildOfClass("Humanoid")
	local feet = FollowLogic.feet(
		rootPart.Position.Y,
		rootPart.Size.Y,
		if humanoid ~= nil then humanoid.HipHeight else 2
	)
	local box, size = model:GetBoundingBox()
	local half = model:GetPivot().Position.Y - (box.Position.Y - size.Y / 2)
	local rest = Pose.rest(rig)
	local toFloor = model:GetPivot():ToObjectSpace(Pose.floor(rig))
	local def = Catalog.getCat(catId :: string)
	local catName = if def ~= nil then def.name else nil

	-- the player's own frame, flat: the camera stands in front of them, so the screen's right is the player's
	-- left; the cat comes in from the screen's right and stops on that side
	local base = rootPart.CFrame
	local forward = Vector3.new(base.LookVector.X, 0, base.LookVector.Z)
	forward = if forward.Magnitude > 1e-3 then forward.Unit else Vector3.new(0, 0, -1)
	local right = -forward:Cross(Vector3.yAxis).Unit -- yAxis x forward, written for selene
	local ground = Vector3.new(rootPart.Position.X, feet, rootPart.Position.Z)
	local stop = ground + right * p.beside
	local from = stop + right * p.walkFrom + forward * p.walkIn
	local look = ground + right * (p.beside / 2) + Vector3.new(0, p.lookUp, 0)
	local skip: { Instance } = { model }
	for _, player in Players:GetPlayers() do
		if player.Character ~= nil then
			table.insert(skip, player.Character)
		end
	end
	local far, near = p.far, p.near
	local free = clearTo(look, look + forward * far + Vector3.new(0, far * p.rise, 0), skip)
	if free < far then
		far = math.max(free - p.clearance, p.closest)
		near = math.min(near, far * p.near / p.far)
	end

	running = true
	local start = camera.CFrame
	local subject = camera.CameraSubject
	local module = CutsceneShell.controls()
	local promptsWere = ProximityPromptService.Enabled
	CutsceneShell.setControls(module, false)
	ProximityPromptService.Enabled = false
	local screen = makeScreen(catName, quick)
	model.Parent = Workspace
	local began = os.clock()
	local length = CompanionUnlockCut.length(p)
	local skipAt: number? = nil
	local arrived = false
	local finished = false
	local stride = 0
	local input: RBXScriptConnection? = nil

	local function place(at: Vector3, facing: Vector3, speed: number, t: number, dt: number)
		local pivotAt = at + Vector3.new(0, half, 0)
		local pivot = CFrame.lookAt(pivotAt, pivotAt + facing)
		model:PivotTo(pivot)
		local floor = pivot * toFloor
		Pose.holdRest(rig, rest, floor)
		local style: Logic.Style = if speed > 0.05 then "stray" else "loaf"
		local o = Logic.idle(style, t, rig.kind)
		if speed > 0.05 then
			stride += speed * dt / Logic.strideLength(speed)
			Logic.gait(o, speed, stride, 0)
		end
		Pose.draw(rig, o, -1)
	end

	local function finish(skipped: boolean)
		if finished then
			return
		end
		finished = true
		RunService:UnbindFromRenderStep(STEP)
		if input ~= nil then
			input:Disconnect()
		end
		model:Destroy()
		if screen ~= nil then
			screen.gui:Destroy()
		end
		local cam = Workspace.CurrentCamera
		if cam ~= nil then
			cam.CFrame = start
			cam.CameraType = Enum.CameraType.Custom
			if subject ~= nil and subject.Parent ~= nil then
				cam.CameraSubject = subject
			end
		end
		CutsceneShell.setControls(module, true)
		ProximityPromptService.Enabled = promptsWere
		running = false
		local outcome: "played" | "skipped" = if skipped then "skipped" else "played"
		task.spawn(done, outcome)
	end

	input = UserInputService.InputBegan:Connect(function(event: InputObject)
		local t = os.clock() - began
		if not p.skip or skipAt ~= nil or t < p.skipAfter then
			return
		end
		local kind = event.UserInputType
		if
			kind == Enum.UserInputType.Keyboard
			or kind == Enum.UserInputType.MouseButton1
			or kind == Enum.UserInputType.Touch
			or kind.Name:sub(1, 7) == "Gamepad"
		then
			skipAt = t
		end
	end)

	local last = began
	RunService:BindToRenderStep(STEP, Enum.RenderPriority.Camera.Value + 1, function()
		local cam = Workspace.CurrentCamera
		if cam == nil then
			finish(skipAt ~= nil)
			return
		end
		local now = os.clock()
		local dt = math.min(now - last, 0.1)
		last = now
		local t = now - began
		local at = skipAt
		local timeline = t
		if at ~= nil then
			timeline = math.max(t - at, 0) + p.endAt
			if t < p.fade then
				timeline = p.endAt
			end
		end
		if timeline >= length or t >= length + p.cap then
			finish(at ~= nil)
			return
		end
		local fade, there, push, walk, a = CompanionUnlockCut.at(timeline, p)
		if reduced then
			walk = 1
		end
		cam.CameraType = Enum.CameraType.Scriptable
		if there then
			local k = if reduced then 0 else Logic.easeInOut(push)
			local distance = far + (near - far) * k
			local eye = look + forward * distance + Vector3.new(0, distance * p.rise, 0)
			cam.CFrame = CFrame.lookAt(eye, look)
		else
			cam.CFrame = start
		end
		-- the cat: eases up into a trot and eases into its stop (smoothstep, so it never starts at full speed and
		-- the feet keep up), then it turns to face the camera and settles
		local eased = walk * walk * (3 - 2 * walk)
		local spot = from:Lerp(stop, eased)
		local moving = walk < 1
		local speed = if moving
			then (from - stop).Magnitude * 6 * walk * (1 - walk) / p.walkSeconds
			else 0
		local facing = if moving then (stop - from).Unit else forward
		place(spot, facing, speed, timeline, dt)
		if not moving and not arrived and timeline >= p.walkAt then
			arrived = true
			local over = stop + Vector3.new(0, size.Y + p.heartsUp, 0)
			local PetCat = require(script.Parent.PetCat) :: any
			PetCat.heartsAt(over)
			for _, listener in catListeners do
				task.spawn(listener, over)
			end
		end
		if screen ~= nil then
			screen.black.BackgroundTransparency = 1 - fade
			drawLabels(screen, a)
		end
	end)
	return true
end

return CompanionUnlockCut
