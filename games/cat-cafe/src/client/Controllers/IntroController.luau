--!strict
-- The intro cutscene on this client (F72, docs/design/cat-cafe/intro-cutscene.md). It plays once when this session's
-- first ProfileSync with a plot says introSeen is false, and again whenever the UI's Tutorial tile or Settings row
-- asks (UI.events.introReplay). While it runs the character's controls and every proximity prompt are off and the
-- camera is Scriptable, flown through shared/Intro's nine shots once a frame; the UI's intro screen (UI.intro, the
-- ui-designer's) draws the bars, captions, dots, title cards, the demo ring and Skip, and hides the HUD. Everything
-- staged here is local and goes at the end: the demo cat, the strays hidden or faded, the own roof, the turning
-- wheel, the short night and the sunrise cats. The end, played out or skipped (UI.events.introSkip) or cut short
-- by a respawn, puts all of it back and sends IntroDone(shot, replay): 0 when it played out, else the shot showing.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Intro = require(Shared:WaitForChild("Intro"))
local Moments = require(script.Parent.Parent.Moments)
local Net = require(script.Parent.Parent.Net)
local Types = require(Shared:WaitForChild("Types"))
local UI = require(script.Parent.Parent.UI)
local UIController = require(script.Parent.UIController)
local WorldController = require(script.Parent.WorldController)

local IntroController = {}

local player = Players.LocalPlayer
local RENDER_STEP = "CatCafeIntro"
local POP_SECONDS = 0.2 -- a sunrise cat grows from nothing to full size
local DEMO_FADE_SECONDS = 0.4
local STREAMED_RADIUS = 40 -- a shot 5 area counts as streamed in when a part stands this close to its look point
local WHEEL_TURNS = 2

type Run = {
	replay: boolean,
	started: number, -- os.clock()
	shots: { Intro.Shot },
	plot: Intro.Plot,
	shot: number, -- the shot showing, 0 before the first
	cuts: { Intro.Cut }, -- the showing shot's cuts; shot 5's after the stream check
	cut: number, -- the cut showing, for shot 5's title cards
	character: Model?, -- the character when it started, so a respawn ends it
	staged: { Instance }, -- local clones, destroyed at the end
	hidden: { [Instance]: boolean }, -- parts and decals given a LocalTransparencyModifier, set back to 0 at the end
	tweens: { Tween },
	pops: { { model: Model, at: number } }, -- shot 8's sunrise cats and when each starts to grow
	demo: Model?,
	nearDemo: { Model }, -- real strays hidden at the tutorial stray point for shots 1 and 2
	wheel: { model: Model, base: CFrame }?,
	done: { [string]: boolean }, -- the timed beats inside a shot that have happened
	controls: any?, -- the PlayerModule's controls, disabled for the run
	promptsWere: boolean,
	cameraType: Enum.CameraType,
	ended: boolean,
}

local run: Run? = nil
local firstStarted = false -- the first play of this session has begun

-- The PlayerModule's controls, or nil when the default player scripts are not there.
local function controls(): any?
	local scripts = player:FindFirstChildOfClass("PlayerScripts")
	local module = if scripts ~= nil then scripts:FindFirstChild("PlayerModule") else nil
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local requireAny: any = require -- Roblox's own PlayerModule is not in the Rojo tree, so it has no types
	local ok, controlModule = pcall(function(): any
		return requireAny(module):GetControls()
	end)
	return if ok then controlModule else nil
end

local function rootOf(character: Model?): BasePart?
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root :: BasePart else nil
end

-- Hides (or fades over `seconds`) every part and decal of `model` on this screen only.
local function hide(r: Run, model: Instance, seconds: number?)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") or item:IsA("Decal") then
			r.hidden[item] = true
			if seconds ~= nil and seconds > 0 then
				local tween = TweenService:Create(
					item,
					TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ LocalTransparencyModifier = 1 }
				)
				table.insert(r.tweens, tween)
				tween:Play()
			else
				(item :: any).LocalTransparencyModifier = 1
			end
		end
	end
end

-- Shows a model hidden by `hide` again.
local function show(r: Run, model: Instance)
	for _, item in model:GetDescendants() do
		if r.hidden[item] then
			r.hidden[item] = nil
			(item :: any).LocalTransparencyModifier = 0
		end
	end
end

-- The strays in the Workspace within `radius` studs (flat) of `point`.
local function straysNear(point: Vector3, radius: number): { Model }
	local found: { Model } = {}
	for _, stray in CollectionService:GetTagged("Stray") do
		if stray:IsA("Model") and stray:IsDescendantOf(Workspace) then
			local at = (stray :: Model):GetPivot().Position
			if Vector2.new(at.X - point.X, at.Z - point.Z).Magnitude <= radius then
				table.insert(found, stray :: Model)
			end
		end
	end
	return found
end

-- A local, still copy of a cat's model from ReplicatedStorage.Assets at `at`, or nil when the asset is missing.
local function stageCat(r: Run, catId: string, at: CFrame): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local asset = if assets ~= nil then assets:FindFirstChild(Catalog.catModelName(catId)) else nil
	if asset == nil or not asset:IsA("Model") then
		return nil
	end
	local model = (asset :: Model):Clone() :: Model
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			local part = item :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		elseif item:IsA("ProximityPrompt") or item:IsA("Script") or item:IsA("LocalScript") then
			item:Destroy()
		end
	end
	model:PivotTo(at)
	model.Parent = Workspace
	table.insert(r.staged, model)
	return model
end

-- Asks the server to stream the world around `point` in before a shot needs it. Never yields the caller.
local function streamAround(point: Vector3)
	task.spawn(function()
		pcall(function()
			player:RequestStreamAroundAsync(point, 2)
		end)
	end)
end

-- True when some part (not this character's) has streamed in near `point`.
local function streamedNear(point: Vector3): boolean
	local params = OverlapParams.new()
	local character = player.Character
	if character ~= nil then
		params.FilterDescendantsInstances = { character }
		params.FilterType = Enum.RaycastFilterType.Exclude
	end
	return #Workspace:GetPartBoundsInRadius(point, STREAMED_RADIUS, params) > 0
end

-- The Spin Wheel station's turning part (a Model named Wheel or ..._Wheel, the Effects Wheel's own lookup).
local function findWheel(): Model?
	for _, station in CollectionService:GetTagged("SpinWheel") do
		if station:IsDescendantOf(Workspace) then
			for _, item in station:GetDescendants() do
				if
					item:IsA("Model") and (item.Name == "Wheel" or item.Name:sub(-6) == "_Wheel")
				then
					return item :: Model
				end
			end
		end
	end
	return nil
end

local function hasCodesCat(): boolean
	for _, station in CollectionService:GetTagged("CodesCat") do
		if station:IsDescendantOf(Workspace) then
			return true
		end
	end
	return false
end

-- Shot 8's fresh strays: the Alleyway's Common cats, one per back alley spawn point that has streamed in.
local function sunriseCats(r: Run, elapsed: number)
	local kinds: { string } = {}
	for _, cat in Catalog.cats do
		if cat.area == "alley" and cat.rarity == "Common" then
			table.insert(kinds, cat.id)
		end
	end
	if #kinds == 0 then
		return
	end
	local count = 0
	for _, point in CollectionService:GetTagged("SpawnPoint") do
		if count >= Intro.SUNRISE_STRAYS then
			break
		end
		if
			point:IsA("BasePart")
			and point:GetAttribute("Area") == Intro.STRAY_AREA
			and point:IsDescendantOf(Workspace)
		then
			local at = (point :: BasePart).Position
			count += 1
			local model = stageCat(
				r,
				kinds[(count - 1) % #kinds + 1],
				CFrame.new(at.X, at.Y, at.Z) * CFrame.Angles(0, count * 2.4, 0)
			)
			if model ~= nil then
				model:ScaleTo(0.05)
				table.insert(
					r.pops,
					{ model = model, at = elapsed + (count - 1) * Intro.SUNRISE_STRAY_GAP }
				)
			end
		end
	end
end

local function setCamera(at: Intro.Key)
	local camera = Workspace.CurrentCamera
	if camera ~= nil then
		camera.CFrame = CFrame.lookAt(at.position, at.look)
	end
end

-- Everything a shot starts with. Called once per shot, in order; a shot the frame rate skipped still starts.
local function enterShot(r: Run, index: number)
	local shot = r.shots[index]
	r.shot = index
	r.cut = 1
	r.cuts = shot.cuts
	if index == 5 then
		r.cuts = Intro.keepCuts(shot, function(cut: Intro.Cut): boolean
			return streamedNear(cut.to.look)
		end)
	elseif shot.follow then
		local root = rootOf(player.Character)
		if root ~= nil then
			local last = table.clone(shot.cuts[1])
			last.to = Intro.follow(root.Position, root.CFrame.LookVector)
			r.cuts = { last }
		end
	end
	-- the next shot's places stream in while this one plays
	local following = r.shots[index + 1]
	if following ~= nil then
		for _, cut in following.cuts do
			streamAround(cut.to.look)
		end
	end

	if not shot.demo and r.demo ~= nil then
		r.demo:Destroy()
		r.demo = nil
		for _, stray in r.nearDemo do
			show(r, stray)
		end
		table.clear(r.nearDemo)
	end
	WorldController.holdRoofOpen(if shot.roof then UIController.ownPlot() else nil)
	if shot.spinWheel and r.wheel == nil then
		local wheel = findWheel()
		if wheel ~= nil then
			r.wheel = { model = wheel, base = wheel:GetPivot() }
		end
	elseif not shot.spinWheel and r.wheel ~= nil then
		local wheel = r.wheel :: { model: Model, base: CFrame }
		wheel.model:PivotTo(wheel.base)
		r.wheel = nil
	end
	if shot.follow then
		WorldController.endPreview(shot.seconds) -- the real sky comes back during the swoop
	end

	UI.intro.setShot(index, shot.caption, r.cuts[1].title)
	if shot.demo and index == 2 then
		UI.intro.demoCatch(Intro.strayPoint(r.plot) + Vector3.new(0, 1, 0))
	end
	Moments.IntroShot:Fire(index)
end

-- The timed beats inside shots 2 and 8, `t` seconds into the showing shot.
local function beats(r: Run, t: number, elapsed: number)
	local function once(name: string, at: number): boolean
		if t >= at and not r.done[name] then
			r.done[name] = true
			return true
		end
		return false
	end
	if r.shot == 2 and once("demoFade", Intro.DEMO_FADE) and r.demo ~= nil then
		hide(r, r.demo :: Model, DEMO_FADE_SECONDS)
	elseif r.shot == 8 then
		if once("dusk", Intro.NIGHT_FROM) then
			WorldController.previewPhase("night", Intro.NIGHT_TO - Intro.NIGHT_FROM)
		end
		if once("straysOut", Intro.STRAYS_OUT_FROM) then
			for _, stray in CollectionService:GetTagged("Stray") do
				if
					stray:IsA("Model")
					and stray:IsDescendantOf(Workspace)
					and stray:GetAttribute("Area") == Intro.STRAY_AREA
				then
					hide(r, stray :: Model, Intro.STRAYS_OUT_TO - Intro.STRAYS_OUT_FROM)
				end
			end
		end
		if once("sunrise", Intro.SUNRISE_FROM) then
			WorldController.previewPhase("day", Intro.SUNRISE_TO - Intro.SUNRISE_FROM)
		end
		if once("sunriseCats", Intro.SUNRISE_STRAYS_AT) then
			sunriseCats(r, elapsed)
		end
	end
	if r.wheel ~= nil then
		local wheel = r.wheel :: { model: Model, base: CFrame }
		local shot = r.shots[r.shot]
		local turn = Intro.ease("Out", t / shot.seconds) * WHEEL_TURNS * 2 * math.pi
		wheel.model:PivotTo(wheel.base * CFrame.Angles(0, 0, -turn))
	end
	for _, pop in r.pops do
		if elapsed >= pop.at and pop.model.Parent ~= nil then
			pop.model:ScaleTo(math.max(0.05, Intro.ease("Out", (elapsed - pop.at) / POP_SECONDS)))
		end
	end
end

local finish: (finished: boolean) -> ()

local function step()
	local r = run
	if r == nil or r.ended then
		return
	end
	local elapsed = os.clock() - r.started
	local index = Intro.shotAt(r.shots, elapsed)
	if index == 0 then
		finish(true)
		return
	end
	while r.shot < index do
		enterShot(r, r.shot + 1)
	end
	local shot = r.shots[index]
	local t = elapsed - shot.starts
	-- the cut showing and how far through it
	local cutStart = 0
	local cut = #r.cuts
	for i, c in r.cuts do
		if t < cutStart + c.seconds or i == #r.cuts then
			cut = i
			break
		end
		cutStart += c.seconds
	end
	if cut ~= r.cut then
		r.cut = cut
		UI.intro.setShot(index, shot.caption, r.cuts[cut].title)
	end
	local c = r.cuts[cut]
	setCamera(Intro.at(c, shot.ease, (t - cutStart) / c.seconds))
	beats(r, t, elapsed)
end

finish = function(finished: boolean)
	local r = run
	if r == nil or r.ended then
		return
	end
	r.ended = true
	RunService:UnbindFromRenderStep(RENDER_STEP)
	for _, tween in r.tweens do
		tween:Cancel()
	end
	for item in r.hidden do
		if item.Parent ~= nil then
			(item :: any).LocalTransparencyModifier = 0
		end
	end
	for _, item in r.staged do
		item:Destroy()
	end
	if r.wheel ~= nil then
		local wheel = r.wheel :: { model: Model, base: CFrame }
		wheel.model:PivotTo(wheel.base)
	end
	WorldController.holdRoofOpen(nil)
	WorldController.endPreview()

	local camera = Workspace.CurrentCamera
	if camera ~= nil then
		camera.CameraType = if r.cameraType == Enum.CameraType.Scriptable
			then Enum.CameraType.Custom
			else r.cameraType
		local character = player.Character
		local humanoid = if character ~= nil
			then character:FindFirstChildOfClass("Humanoid") :: Humanoid?
			else nil
		if humanoid ~= nil then
			camera.CameraSubject = humanoid
		end
	end
	if r.controls ~= nil then
		pcall(function()
			r.controls:Enable()
		end)
	end
	ProximityPromptService.Enabled = r.promptsWere

	UI.intro.finish()
	Net.fire("IntroDone", if finished then 0 else math.max(r.shot, 1), r.replay)
	run = nil
	Moments.IntroEnd:Fire()
end

-- Plays the intro from the first shot. `replay` is a replay from the Tutorial tile or Settings: Skip shows at once
-- and the server saves nothing. Does nothing while one is playing or without a plot.
function IntroController.play(replay: boolean)
	local state = UIController.state
	if run ~= nil or state == nil or state.plotIndex == 0 then
		return
	end
	local plot = Intro.plot(state.plotIndex)
	local camera = Workspace.CurrentCamera
	local r: Run = {
		replay = replay,
		started = os.clock(),
		shots = Intro.shots(plot, hasCodesCat()),
		plot = plot,
		shot = 0,
		cuts = {},
		cut = 1,
		character = player.Character,
		staged = {},
		hidden = {},
		tweens = {},
		pops = {},
		demo = nil,
		nearDemo = {},
		wheel = nil,
		done = {},
		controls = controls(),
		promptsWere = ProximityPromptService.Enabled,
		cameraType = if camera ~= nil then camera.CameraType else Enum.CameraType.Custom,
		ended = false,
	}
	run = r

	if r.controls ~= nil then
		pcall(function()
			r.controls:Disable()
		end)
	end
	ProximityPromptService.Enabled = false
	if camera ~= nil then
		camera.CameraType = Enum.CameraType.Scriptable
	end

	-- the demo cat waits at the tutorial stray point through shots 1 and 2; real strays there are hidden
	local strayAt = Intro.strayPoint(plot)
	r.nearDemo = straysNear(strayAt, Intro.DEMO_HIDE_RADIUS)
	for _, stray in r.nearDemo do
		hide(r, stray)
	end
	r.demo = stageCat(r, "tabby", CFrame.new(strayAt)) -- which way it faces is one to tune in Studio
	for _, cut in r.shots[1].cuts do
		streamAround(cut.to.look)
	end

	UI.intro.start({ skipAfter = if replay then 0 else Intro.SKIP_AFTER, replay = replay })
	Moments.IntroStart:Fire(replay)
	RunService:BindToRenderStep(RENDER_STEP, Enum.RenderPriority.Camera.Value + 1, step)
end

function IntroController.playing(): boolean
	return run ~= nil
end

function IntroController.start()
	Net.on("ProfileSync", function(s: Types.PlayerState)
		if not firstStarted and s.introSeen == false and s.plotIndex ~= 0 then
			firstStarted = true
			-- after UIController has applied this sync, so play() reads the same state
			task.defer(IntroController.play, false)
		end
	end)
	UI.events.introSkip:Connect(function()
		finish(false) -- the UI sends the shot; this side knows it already
	end)
	UI.events.introReplay:Connect(function()
		local state = UIController.state
		if state ~= nil and state.carrying == nil then
			IntroController.play(true)
		end
	end)
	player.CharacterAdded:Connect(function(character)
		local r = run
		if r == nil then
			return
		elseif r.character == nil then
			r.character = character -- the first spawn after the intro began
		else
			finish(false) -- a respawn mid-intro ends it
		end
	end)
end

return IntroController
