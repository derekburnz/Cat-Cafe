--!strict
-- The intro cutscene on this client (F72, docs/design/cat-cafe/intro-cutscene.md). It plays once when this session's
-- first ProfileSync with a plot says introSeen is false, and again whenever the UI's Tutorial tile or Settings row
-- asks (UI.events.introReplay). While it runs the character's controls and every proximity prompt are off and the
-- camera is Scriptable, flown through shared/Intro's ten shots once a frame; the UI's intro screen (UI.intro, the
-- ui-designer's) draws the bars, captions, dots, title cards, the demo ring, the job card and Skip, and hides the HUD.
--
-- Shots 1 to 4 (section 2a): a local copy of your own character catches the demo Tuxedo behind your cafe, carries it
-- home through the yard gate and in at the back door, and the cat takes the waiter spot in its outfit with its rate
-- tag, while the real character stays hidden at the intro spot. Everything staged here is local and goes at the end:
-- your copy, the demo cat, the seated waiter, the strays and the real waiter hidden, the turning wheel, the short
-- night and the sunrise cats. The end, played out or skipped (UI.events.introSkip) or cut short by a respawn, puts
-- all of it back and sends IntroDone(shot, replay): 0 when it played out, else the shot showing.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CatDress = require(Shared:WaitForChild("CatDress"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Catching = require(Shared:WaitForChild("Catching"))
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
local DEMO_FADE_SECONDS = 0.4 -- with no copy of you to catch it, the demo cat fades at the hop instead
local STREAMED_RADIUS = 40 -- a shot 6 area counts as streamed in when a part stands this close to its look point
local WHEEL_TURNS = 2
local BLEND = 0.15 -- seconds an animation of your copy fades in or out
-- The avatar's own animations your copy plays: the Animate script's StringValue for each and its Animation's name.
local ANIMATIONS: { [string]: string } = { run = "RunAnim", idle = "Animation1" }

-- Where a carried cat rides on the carrier's root (Catching.CARRIED_POSE, the real carry's number).
local CARRIED = (function(): CFrame
	local p = Catching.CARRIED_POSE
	return CFrame.new(p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8], p[9], p[10], p[11], p[12])
end)()

-- Your local copy for shots 1 to 4: moved by its anchored root, playing the avatar's own animations.
type You = {
	model: Model,
	root: BasePart,
	height: number, -- the root's height above the ground it stands on
	tracks: { [string]: AnimationTrack }, -- "run" and "idle", the avatar's own where the Animate script names them
	playing: string?,
}

type Run = {
	replay: boolean,
	started: number, -- os.clock()
	shots: { Intro.Shot },
	plot: Intro.Plot,
	shot: number, -- the shot showing, 0 before the first
	cuts: { Intro.Cut }, -- the showing shot's cuts; shot 6's after the stream check
	cut: number, -- the cut showing, for shot 6's title cards
	character: Model?, -- the character when it started, so a respawn ends it
	staged: { Instance }, -- local clones, destroyed at the end
	hidden: { [Instance]: boolean }, -- parts and decals given a LocalTransparencyModifier, set back to 0 at the end
	tweens: { Tween },
	pops: { { model: Model, at: number } }, -- shot 9's sunrise cats and when each starts to grow
	you: You?,
	characterHidden: boolean, -- the real character is hidden (shots 1 to 4)
	demo: Model?, -- the demo Tuxedo, at the stray point and then in your arms
	hopFrom: CFrame?, -- where the demo cat's hop into your arms starts
	held: boolean, -- the demo cat rides in your arms
	nearDemo: { Model }, -- real strays hidden at the tutorial stray point for shots 1 and 2
	seated: Model?, -- shot 4's seated waiter
	waiters: { Model }, -- real cats on the waiter spot, hidden for shot 4
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

-- Hides or shows the real character. The default camera scripts write LocalTransparencyModifier on the player's
-- own character too, so while it is hidden this runs every frame (section 2a).
local function hideCharacter(r: Run, hidden: boolean)
	r.characterHidden = hidden
	local character = player.Character
	if character == nil then
		return
	end
	for _, item in character:GetDescendants() do
		if item:IsA("BasePart") or item:IsA("Decal") then
			(item :: any).LocalTransparencyModifier = if hidden then 1 else 0
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

-- A copy of ReplicatedStorage.Assets' model `name`, or nil when the asset is missing.
local function cloneAsset(name: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local asset = if assets ~= nil then assets:FindFirstChild(name) else nil
	if asset == nil or not asset:IsA("Model") then
		return nil
	end
	return (asset :: Model):Clone() :: Model
end

-- A local, still copy of the asset `name` at `at`, staged for the end, or nil when the asset is missing.
local function stageAsset(r: Run, name: string, at: CFrame): Model?
	local model = cloneAsset(name)
	if model == nil then
		return nil
	end
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

local function stageCat(r: Run, catId: string, at: CFrame): Model?
	return stageAsset(r, Catalog.catModelName(catId), at)
end

-- The AnimationId the character's Animate script plays for `state` ("run", "idle"), or nil without one.
local function animationId(character: Model, state: string, name: string): string?
	local animate = character:FindFirstChild("Animate")
	local value = if animate ~= nil then animate:FindFirstChild(state) else nil
	local animation = if value ~= nil then value:FindFirstChild(name) else nil
	if animation == nil or not animation:IsA("Animation") then
		return nil
	end
	local id = (animation :: Animation).AnimationId
	return if id ~= "" then id else nil
end

-- A local copy of this player's character (section 2a): Archivable just for the Clone, its scripts gone, its root
-- anchored and moved by CFrame, no collisions and no name over its head. Nil without a character.
local function stageYou(r: Run): You?
	local character = player.Character
	local root = rootOf(character)
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if character == nil or root == nil or humanoid == nil then
		return nil
	end
	local ids: { [string]: string } = {}
	for name, child in ANIMATIONS do
		local id = animationId(character, name, child)
		if id ~= nil then
			ids[name] = id
		end
	end
	local was = character.Archivable
	character.Archivable = true
	local ok, cloned = pcall(function(): Instance?
		return character:Clone()
	end)
	character.Archivable = was
	if not ok or cloned == nil or not cloned:IsA("Model") then
		return nil
	end
	local model = cloned :: Model
	model.Name = "IntroYou"
	local copyRoot: BasePart? = nil
	for _, item in model:GetDescendants() do
		if item:IsA("LuaSourceContainer") or item:IsA("ForceField") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			local part = item :: BasePart
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Anchored = part.Name == "HumanoidRootPart"
			if part.Anchored then
				copyRoot = part
			end
		end
	end
	local copyHumanoid = model:FindFirstChildOfClass("Humanoid")
	if copyRoot == nil or copyHumanoid == nil then
		model:Destroy()
		return nil
	end
	local h = copyHumanoid :: Humanoid
	h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	h.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	-- R15 stands its root HipHeight plus half the root above the ground; R6's legs are 2 tall under the torso
	local height = if h.RigType == Enum.HumanoidRigType.R15
		then h.HipHeight + (copyRoot :: BasePart).Size.Y / 2
		else (copyRoot :: BasePart).Size.Y / 2 + 2
	model.Parent = Workspace
	table.insert(r.staged, model)
	local you: You =
		{ model = model, root = copyRoot :: BasePart, height = height, tracks = {}, playing = nil }
	local animator = h:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = h
	for name, id in ids do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local loaded, track = pcall(function(): AnimationTrack
			return (animator :: Animator):LoadAnimation(animation)
		end)
		if loaded then
			you.tracks[name] = track
		end
	end
	return you
end

-- Plays one of your copy's animations ("run", "idle"), blending out the one before.
local function playYou(you: You, name: string)
	if you.playing == name then
		return
	end
	local before: AnimationTrack? = if you.playing ~= nil then you.tracks[you.playing] else nil
	if before ~= nil then
		before:Stop(BLEND)
	end
	you.playing = name
	local track: AnimationTrack? = you.tracks[name]
	if track ~= nil then
		track.Looped = true
		track:Play(BLEND)
	end
end

-- Stands your copy on `ground`, facing the flat way `facing`.
local function placeYou(you: You, ground: Vector3, facing: Vector3)
	local at = ground + Vector3.new(0, you.height, 0)
	you.root.CFrame = CFrame.lookAt(at, at + Vector3.new(facing.X, 0, facing.Z))
end

-- The flat way from `a` to `b`.
local function toward(a: Vector3, b: Vector3): Vector3
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	return if flat.Magnitude > 1e-6 then flat.Unit else Vector3.new(0, 0, -1)
end

-- The turn about Y whose LookVector is `facing`, and back.
local function yawOf(facing: Vector3): number
	return math.atan2(-facing.X, -facing.Z)
end

local function facingOf(yaw: number): Vector3
	return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
end

-- The own cafe's waiter spot (Spots.<JOB_SPOT>, where a real waiter sits), or where shared/Intro works it out.
local function waiterSpot(r: Run): CFrame
	local plot = UIController.ownPlot()
	local spots = if plot ~= nil then plot:FindFirstChild("Spots") else nil
	local spot = if spots ~= nil then spots:FindFirstChild(Intro.JOB_SPOT) else nil
	if spot ~= nil and spot:IsA("BasePart") then
		return (spot :: BasePart).CFrame
	end
	local point = Intro.waiterPoint(r.plot)
	return CFrame.lookAt(point, point + Vector3.new(-r.plot.side, 0, 0)) -- a spot faces the street, as plot -Z
end

-- A real cat working the waiter spot in the own cafe (a tester's replay), hidden for shot 4.
local function hideRealWaiter(r: Run)
	local plot = UIController.ownPlot()
	local cats = if plot ~= nil then plot:FindFirstChild("Cats") else nil
	if cats == nil then
		return
	end
	for _, cat in cats:GetChildren() do
		if cat:IsA("Model") and cat:GetAttribute("SpotId") == Intro.JOB_SPOT then
			hide(r, cat)
			table.insert(r.waiters, cat :: Model)
		end
	end
end

-- Shot 4's seated waiter: the demo cat's seated body (or its walking one while that is missing) at the waiter spot in
-- the waiter outfit, as CafeService and CatPose seat a real one.
local function stageSeated(r: Run): Model?
	local at = waiterSpot(r)
	local base = Catalog.catModelName(Intro.DEMO_CAT)
	local model = stageAsset(r, Catalog.sitModelName(base), at)
	local seated = model ~= nil
	if model == nil then
		model = stageAsset(r, base, at)
	end
	if model == nil then
		return nil
	end
	local cat = model :: Model
	if seated then
		cat:SetAttribute("Pose", "sit")
	end
	cat:SetAttribute("Role", Intro.JOB_ROLE)
	CatDress.dress(cat, Intro.JOB_ROLE, cloneAsset)
	return cat
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

-- Shot 9's fresh strays: the Alleyway's Common cats, one per back alley spawn point that has streamed in.
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
	if shot.cuts[1].area ~= nil then
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

	if shot.run and r.you ~= nil and r.demo ~= nil then
		r.held = true -- in your arms for the run, even when a slow frame skipped the hop
	end
	if not shot.demo then
		-- the real strays at the stray point come back, and the demo cat goes unless it is in your arms
		for _, stray in r.nearDemo do
			show(r, stray)
		end
		table.clear(r.nearDemo)
		if r.demo ~= nil and not r.held then
			(r.demo :: Model):Destroy()
			r.demo = nil
		end
	end
	local you = r.you
	if you ~= nil and shot.run then
		playYou(you, "run")
	elseif you ~= nil and shot.job then
		-- seen from inside after the cut: you step in at the back door
		local steps = Intro.stepIn(r.plot)
		placeYou(you, steps[1], toward(steps[1], steps[2]))
		playYou(you, "run")
		hideRealWaiter(r)
	end
	if not shot.you and not r.done.sceneOver then
		-- at the cut to shot 5 your copy, the demo cat and the seated waiter go and the real character shows where the
		-- copy stopped; a real waiter hidden for shot 4 comes back
		r.done.sceneOver = true
		if you ~= nil then
			you.model:Destroy()
			r.you = nil
		end
		if r.demo ~= nil then
			(r.demo :: Model):Destroy()
			r.demo = nil
			r.held = false
		end
		if r.seated ~= nil then
			(r.seated :: Model):Destroy()
			r.seated = nil
		end
		for _, waiter in r.waiters do
			show(r, waiter)
		end
		table.clear(r.waiters)
		if r.characterHidden then
			hideCharacter(r, false)
		end
	end
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
	if shot.catch then
		UI.intro.demoCatch(Intro.strayPoint(r.plot) + Vector3.new(0, 1, 0))
	end
	Moments.IntroShot:Fire(index)
end

-- Shots 1 to 4's staging, `t` seconds into the showing shot: you, the hop, the run, the steps in and the job.
local function stageScene(r: Run, shot: Intro.Shot, t: number)
	local function once(name: string, at: number): boolean
		if t >= at and not r.done[name] then
			r.done[name] = true
			return true
		end
		return false
	end
	if shot.you then
		hideCharacter(r, true)
	end
	local you = r.you
	if shot.catch then
		if you == nil then
			-- nobody to catch it: the demo cat fades, as before the carry
			if once("demoFade", Intro.HOP_FROM) and r.demo ~= nil then
				hide(r, r.demo :: Model, DEMO_FADE_SECONDS)
			end
		elseif r.demo ~= nil and t >= Intro.HOP_FROM and not r.held then
			local demo = r.demo :: Model
			if r.hopFrom == nil then
				r.hopFrom = demo:GetPivot()
			end
			local u = math.clamp((t - Intro.HOP_FROM) / Intro.HOP_SECONDS, 0, 1)
			local arc = Intro.HOP_HEIGHT * math.sin(math.pi * u)
			demo:PivotTo(
				(r.hopFrom :: CFrame):Lerp(you.root.CFrame * CARRIED, Intro.ease("Out", u))
					+ Vector3.new(0, arc, 0)
			)
			r.held = u >= 1
		end
	elseif shot.run and you ~= nil then
		local path = Intro.runPath(r.plot)
		local toStray = toward(path[1], Intro.strayPoint(r.plot))
		if t < Intro.TURN_SECONDS then
			-- turn from the stray toward the yard gate the short way round
			local from, to = yawOf(toStray), yawOf(toward(path[1], path[2]))
			local delta = (to - from + math.pi) % (2 * math.pi) - math.pi
			placeYou(
				you,
				path[1],
				facingOf(from + delta * Intro.ease("InOut", t / Intro.TURN_SECONDS))
			)
		else
			local ground, facing = Intro.along(path, (t - Intro.TURN_SECONDS) * Intro.RUN_SPEED)
			placeYou(you, ground, facing)
			if t - Intro.TURN_SECONDS >= Intro.pathSeconds(path, Intro.RUN_SPEED) then
				playYou(you, "idle")
			end
		end
	elseif shot.job then
		if you ~= nil then
			local steps = Intro.stepIn(r.plot)
			local length = (steps[2] - steps[1]).Magnitude
			local ground, facing =
				Intro.along(steps, length * math.min(1, t / Intro.STEP_IN_SECONDS))
			placeYou(you, ground, facing)
			if t >= Intro.STEP_IN_SECONDS then
				playYou(you, "idle")
			end
		end
		if once("jobCard", Intro.JOB_CARD_AT) then
			UI.intro.jobCard(waiterSpot(r).Position, Intro.JOB_ROLE)
		end
		if once("seated", Intro.JOB_SEATED_AT) then
			-- the cat leaves your arms and takes its spot; the effects can puff it from one to the other
			local from = if r.demo ~= nil
				then (r.demo :: Model):GetPivot().Position
				else waiterSpot(r).Position
			if r.demo ~= nil then
				(r.demo :: Model):Destroy()
				r.demo = nil
			end
			r.held = false
			r.seated = stageSeated(r)
			if r.seated ~= nil then
				Moments.IntroCatSeated:Fire(from, r.seated :: Model)
			end
		end
		if once("rateTag", Intro.JOB_RATE_AT) and r.seated ~= nil then
			-- the UI's rate tag shows over a working cat (WorldTags reads these)
			local seated = r.seated :: Model
			seated:SetAttribute("Rate", Intro.demoRate())
			local def = Catalog.getCat(Intro.DEMO_CAT)
			seated:SetAttribute("Rarity", if def ~= nil then def.rarity else nil)
			seated:SetAttribute("Napping", false)
			seated:SetAttribute("DisplayName", Intro.demoName())
			CollectionService:AddTag(seated, "WorkingCat")
		end
	end
	-- a cat in your arms rides there as a real carry holds it
	if r.held and you ~= nil and r.demo ~= nil then
		(r.demo :: Model):PivotTo(you.root.CFrame * CARRIED)
	end
end

-- The timed beats of shots 8 and 9, `t` seconds into the showing shot.
local function beats(r: Run, shot: Intro.Shot, t: number, elapsed: number)
	local function once(name: string, at: number): boolean
		if t >= at and not r.done[name] then
			r.done[name] = true
			return true
		end
		return false
	end
	if shot.night then
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
	stageScene(r, shot, t)
	beats(r, shot, t, elapsed)
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
	if r.characterHidden then
		hideCharacter(r, false)
	end
	if r.wheel ~= nil then
		local wheel = r.wheel :: { model: Model, base: CFrame }
		wheel.model:PivotTo(wheel.base)
	end
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
		you = nil,
		characterHidden = false,
		demo = nil,
		hopFrom = nil,
		held = false,
		nearDemo = {},
		seated = nil,
		waiters = {},
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

	-- the demo Tuxedo waits at the tutorial stray point through shots 1 and 2, facing you at the catch spot; real
	-- strays there are hidden
	local strayAt = Intro.strayPoint(plot)
	local catchAt = Intro.catchSpot(plot)
	r.nearDemo = straysNear(strayAt, Intro.DEMO_HIDE_RADIUS)
	for _, stray in r.nearDemo do
		hide(r, stray)
	end
	r.demo = stageCat(r, Intro.DEMO_CAT, CFrame.lookAt(strayAt, strayAt + toward(strayAt, catchAt)))
	r.you = stageYou(r)
	if r.you ~= nil then
		local you = r.you :: You
		placeYou(you, catchAt, toward(catchAt, strayAt))
		playYou(you, "idle")
		hideCharacter(r, true)
	end
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
