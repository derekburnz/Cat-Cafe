--!strict
-- The intro cutscene on this client (F72, docs/design/cat-cafe/intro-cutscene.md, reshot for F84). It plays once when
-- this session's first ProfileSync with a plot says introSeen is false (only while Config.IntroAutoPlay is true:
-- since F87, easy-start.md section 2a, a new player starts playing at once and the Tutorial tile glows instead), and
-- again whenever the UI's Tutorial tile or
-- Settings row asks (UI.events.introReplay). Before it starts it asks the server to stream the Alleyway's camp in and
-- waits for it for up to Intro.STREAM_WAIT seconds; without it the shots there are left out (section 2's fallback).
-- While it runs the character's controls and every proximity prompt are off and the camera is Scriptable, flown
-- through shared/Intro's shots once a frame; the UI's intro screen (UI.intro, the ui-designer's) draws the bars,
-- captions, dots, title cards, the demo ring, the job card and Skip, and hides the HUD.
--
-- Shots 1 to 4 (section 2a): a local copy of your own character, tagged StagedCharacter so Effects pose its net and
-- its carry, climbs into the Town Square's cannon, flies to the Alleyway camp's pad on Effects/Cannon's staged flight,
-- catches the demo Tuxedo just past the way out and carries it into the camp, where it hops into the basket. The real
-- character stays at the spawn the whole time, hidden on this screen until shot 5. In shot 5 the cat takes the waiter
-- spot in your cafe in its outfit with its rate tag. Everything staged here is local and goes at the end: your copy,
-- the demo cat, the seated waiter, the strays and the real waiter hidden, the cannon's turn and moon cover, the
-- turning wheel and the short night. The end, played out or skipped (UI.events.introSkip) or cut short by a respawn,
-- puts all of it back and sends IntroDone(shot, replay): 0 when it played out, else the shot showing.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CannonFx = require(script.Parent.Parent.Effects.Cannon)
local CatDress = require(Shared:WaitForChild("CatDress"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Catching = require(Shared:WaitForChild("Catching"))
local Config = require(Shared:WaitForChild("Config"))
local Intro = require(Shared:WaitForChild("Intro"))
local Moments = require(script.Parent.Parent.Moments)
local Net = require(script.Parent.Parent.Net)
local Presets = require(script.Parent.Parent.Effects.Presets)
local Types = require(Shared:WaitForChild("Types"))
local UI = require(script.Parent.Parent.UI)
local UIController = require(script.Parent.UIController)
local WorldController = require(script.Parent.WorldController)

local IntroController = {}

local player = Players.LocalPlayer
local RENDER_STEP = "CatCafeIntro"
local DEMO_FADE_SECONDS = 0.4 -- with no copy of you to catch it, the demo cat fades at the hop instead
local STREAMED_RADIUS = 40 -- a camp counts as streamed in when a part stands this close to the point checked
local WHEEL_TURNS = 2
local BLEND = 0.15 -- seconds an animation of your copy fades in or out
local SPIN_TURNS = 2 -- the ball's tumbles on the way up
local NO_LADDER = Vector3.new(0, 0.1, -7.5) -- the foot of the town cannon's south steps without its Climb part
local STAGED = "StagedCharacter" -- Tackle.luau poses a model with this tag (and no player) like a character
-- The attributes a copy of the character must not keep from it: no carry, no flight, no camp, the net out.
local COPY_CLEARS = {
	"CarryingCatId",
	"NetHidden",
	"Launching",
	"CannonLaunchAt",
	"CannonFrom",
	"CannonTo",
	"CloudHopAt",
	"CloudHopTo",
	"Camp",
}
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
	shown: boolean,
}

-- The Town Square's cannon on this screen (section 2a): its turret turned and its moon cover lifted locally.
type TownCannon = {
	model: Model,
	turret: Model?,
	rest: CFrame?, -- the turret's pivot at rest, facing north
	ladder: Vector3, -- the foot of its south steps, where your copy stands in shot 1
	seat: CFrame, -- the barrel's Seat, where your copy waits for the BOOM
}

type Run = {
	replay: boolean,
	started: number, -- os.clock()
	shots: { Intro.Shot },
	plot: Intro.Plot,
	camp: Intro.Camp, -- the Alleyway's
	alleyStreamed: boolean,
	shot: number, -- the position in `shots` of the shot showing, 0 before the first
	cuts: { Intro.Cut }, -- the showing shot's cuts; shot 6's after the stream check
	cut: number, -- the cut showing, for shot 6's title cards
	character: Model?, -- the character when it started, so a respawn ends it
	staged: { Instance }, -- local clones, destroyed at the end
	hidden: { [Instance]: boolean }, -- parts and decals given a LocalTransparencyModifier, set back to 0 at the end
	covers: { [BasePart]: number }, -- moon cover parts this screen changed, and the Transparency they had
	tweens: { Tween },
	you: You?,
	characterHidden: boolean, -- the real character is hidden (shots 1 to 4)
	cannon: TownCannon?,
	flying: boolean, -- Effects/Cannon's staged flight is on your copy
	boomAt: number, -- the BOOM's Workspace:GetServerTimeNow(), set at the fuse
	muzzle: Vector3, -- where the ball leaves the barrel, at the BOOM
	aim: Vector3, -- the flat way it fires
	demo: Model?, -- the demo Tuxedo, at the stray point and then in your arms
	demoName: string,
	demoParent: Instance?,
	hopFrom: CFrame?, -- where the demo cat's hop into your arms starts
	held: boolean, -- the demo cat rides in your arms (a HeldCat of your copy)
	basket: Model?, -- the Alleyway camp's carrier basket
	nearDemo: { Model }, -- real strays hidden round the catch and the run for shots 3 and 4
	seated: Model?, -- shot 5's seated waiter
	waiters: { Model }, -- real cats on the waiter spot, hidden for shot 5
	wheel: { model: Model, base: CFrame }?,
	done: { [string]: boolean }, -- the timed beats inside a shot that have happened
	controls: any?, -- the PlayerModule's controls, disabled for the run
	promptsWere: boolean,
	cameraType: Enum.CameraType,
	ended: boolean,
}

local run: Run? = nil
local starting = false -- a play is waiting for the camp to stream in
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

-- The strays in the Workspace within `radius` studs (flat) of any of `points`.
local function straysNear(points: { Vector3 }, radius: number): { Model }
	local found: { Model } = {}
	for _, stray in CollectionService:GetTagged("Stray") do
		if stray:IsA("Model") and stray:IsDescendantOf(Workspace) then
			local at = (stray :: Model):GetPivot().Position
			for _, point in points do
				if Vector2.new(at.X - point.X, at.Z - point.Z).Magnitude <= radius then
					table.insert(found, stray :: Model)
					break
				end
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
-- anchored and moved by CFrame, no collisions and no name over its head, tagged StagedCharacter with none of the
-- character's carry or flight attributes (Animation-Engineer #631). Nil without a character.
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
	local held = model:FindFirstChild("HeldCat")
	if held ~= nil then
		held:Destroy()
	end
	for _, name in COPY_CLEARS do
		model:SetAttribute(name, nil)
	end
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
	CollectionService:AddTag(model, STAGED)
	model.Parent = Workspace
	table.insert(r.staged, model)
	local you: You = {
		model = model,
		root = copyRoot :: BasePart,
		height = height,
		tracks = {},
		playing = nil,
		shown = true,
	}
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

-- Shows or hides your copy on this screen (in the barrel, in the sky).
local function showYou(r: Run, you: You, shown: boolean)
	if you.shown == shown then
		return
	end
	you.shown = shown
	if shown then
		show(r, you.model)
	else
		hide(r, you.model)
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

-- Turns your copy from facing `from` to facing `to` the short way round, `k` (0 to 1) of the way.
local function turnYou(you: You, ground: Vector3, from: Vector3, to: Vector3, k: number)
	local a, b = yawOf(from), yawOf(to)
	local delta = (b - a + math.pi) % (2 * math.pi) - math.pi
	placeYou(you, ground, facingOf(a + delta * Intro.ease("InOut", k)))
end

-- The town cannon's turret: a child model named ..._Turret, as WorldBuilder builds and turns it.
local function turretOf(model: Model): Model?
	for _, child in model:GetChildren() do
		if child:IsA("Model") and child.Name:sub(-7) == "_Turret" then
			return child :: Model
		end
	end
	return nil
end

local function attachment(model: Instance, name: string): Attachment?
	local found = model:FindFirstChild(name, true)
	return if found ~= nil and found:IsA("Attachment") then found :: Attachment else nil
end

-- The Town Square cannon (tagged CatCannon, CannonId `town`) with its turret's rest, the foot of its ladder on the
-- south steps and its Seat, or nil without one.
local function townCannon(): TownCannon?
	for _, tagged in CollectionService:GetTagged("CatCannon") do
		if
			tagged:IsA("Model")
			and tagged:GetAttribute("CannonId") == "town"
			and tagged:IsDescendantOf(Workspace)
		then
			local model = tagged :: Model
			local turret = turretOf(model)
			local aimed = model:GetAttribute("AimTurn")
			local rest = if turret ~= nil
				then turret:GetPivot() * CFrame.Angles(
					0,
					-math.rad(if type(aimed) == "number" then aimed else 0),
					0
				)
				else nil
			-- the ladder and the Seat turn with the turret: where each is with the turret at rest, as the intro has it
			local function atRest(frame: CFrame): CFrame
				if turret ~= nil and rest ~= nil then
					return (rest :: CFrame) * (turret :: Model):GetPivot():ToObjectSpace(frame)
				end
				return frame
			end
			-- the foot of the climb on the south side, on whatever it stands on
			local ladder = NO_LADDER
			local climb: BasePart? = nil
			for _, item in model:GetDescendants() do
				if item:IsA("BasePart") and item.Name:sub(-6) == "_Climb" then
					climb = item :: BasePart
					break
				end
			end
			if climb ~= nil then
				local c = climb :: BasePart
				local at = atRest(c.CFrame).Position
				local south = Vector3.new(at.X, 0, at.Z - c.Size.Z / 2 - 1.2)
				local top = at.Y + c.Size.Y / 2
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = { c }
				local hit = Workspace:Raycast(
					Vector3.new(south.X, top, south.Z),
					Vector3.new(0, -top - 2, 0),
					params
				)
				ladder = if hit ~= nil then hit.Position else Vector3.new(south.X, 0.1, south.Z)
			end
			local seat = attachment(model, "Seat")
			local seatAt = if seat ~= nil
				then atRest(CFrame.new((seat :: Attachment).WorldPosition)).Position
				else (model:GetPivot() * CFrame.new(0, 5.4, 0)).Position
			return {
				model = model,
				turret = turret,
				rest = rest,
				ladder = ladder,
				seat = CFrame.lookAt(seatAt, seatAt + Vector3.new(0, 0, 1)),
			}
		end
	end
	return nil
end

-- Turns the town cannon's turret `turn` degrees from rest, on this screen only.
local function aimTurret(r: Run, turn: number)
	local cannon = r.cannon
	if cannon ~= nil and cannon.turret ~= nil and cannon.rest ~= nil then
		(cannon.turret :: Model):PivotTo(
			(cannon.rest :: CFrame) * CFrame.Angles(0, math.rad(turn), 0)
		)
	end
end

-- Puts the turret back where the server has it (its AimTurn, which may have changed while the intro ran).
local function restoreTurret(r: Run)
	local cannon = r.cannon
	if cannon ~= nil then
		local aimed = cannon.model:GetAttribute("AimTurn")
		aimTurret(r, if type(aimed) == "number" then aimed else 0)
	end
end

-- Covers or uncovers the town cannon's barrel on this screen only (section 2a: lifted for shots 1 and 2, dropped
-- for shot 9's night), remembering each part's replicated Transparency for coverBack.
local function cover(r: Run, covered: boolean)
	local cannon = r.cannon
	if cannon == nil then
		return
	end
	for _, item in cannon.model:GetDescendants() do
		if item:IsA("Model") and item.Name:sub(-10) == "_MoonCover" then
			for _, piece in item:GetDescendants() do
				if piece:IsA("BasePart") then
					local part = piece :: BasePart
					if r.covers[part] == nil then
						r.covers[part] = part.Transparency
					end
					local shown = part:GetAttribute("CoverTransparency")
					part.Transparency = if covered
						then (if type(shown) == "number" then shown else 0)
						else 1
				end
			end
		end
	end
end

local function coverBack(r: Run)
	for part, was in r.covers do
		part.Transparency = was
	end
	table.clear(r.covers)
end

-- The Alleyway camp's carrier basket (CampBasket), nearest its basket spot, or nil.
local function campBasket(r: Run): Model?
	local best: Model? = nil
	local bestDistance = 12
	for _, tagged in CollectionService:GetTagged("CampBasket") do
		if tagged:IsA("Model") and tagged:IsDescendantOf(Workspace) then
			local distance = ((tagged :: Model):GetPivot().Position - r.camp.basket).Magnitude
			if distance < bestDistance then
				best, bestDistance = tagged :: Model, distance
			end
		end
	end
	return best
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

-- A real cat working the waiter spot in the own cafe (a tester's replay), hidden for shot 5.
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

-- Shot 5's seated waiter: the demo cat's seated body (or its walking one while that is missing) at the waiter spot,
-- as CafeService and CatPose seat a real one; its outfit comes on later (dressSeated).
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
	if seated then
		(model :: Model):SetAttribute("Pose", "sit")
	end
	return model
end

local function dressSeated(cat: Model)
	cat:SetAttribute("Role", Intro.JOB_ROLE)
	CatDress.dress(cat, Intro.JOB_ROLE, cloneAsset)
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

-- Effects/Cannon's beats for a flight whose camp has not streamed in: the clouds hold to the end of shot 2.
local function heldStage(seconds: number): CannonFx.Stage
	local base = Presets.cannon.introStage
	local clouds = table.clone(base.clouds)
	clouds.partFrom, clouds.partTo = seconds - 0.1, seconds
	return {
		boomAt = base.boomAt,
		puffAt = base.puffAt,
		dropAt = seconds - 0.1,
		landAt = seconds - 0.05,
		endAt = seconds,
		clouds = clouds,
		glideFrom = base.glideFrom,
		glideTo = seconds - 0.1,
	}
end

local function setCamera(at: Intro.Key)
	local camera = Workspace.CurrentCamera
	if camera ~= nil then
		camera.CFrame = CFrame.lookAt(at.position, at.look)
	end
end

-- The demo cat into your copy's arms as its HeldCat, which Effects/Carry holds in the carry pose (#631).
local function holdDemo(r: Run, you: You, demo: Model)
	r.held = true
	r.demoName, r.demoParent = demo.Name, demo.Parent
	demo:PivotTo(you.root.CFrame * CARRIED)
	demo.Name = "HeldCat"
	demo.Parent = you.model
	you.model:SetAttribute("CarryingCatId", Intro.DEMO_CAT)
end

-- The demo cat out of your copy's arms, back where it was staged, for the check-in hop.
local function releaseDemo(r: Run, you: You?, demo: Model)
	r.held = false
	if you ~= nil then
		you.model:SetAttribute("CarryingCatId", nil)
	end
	demo.Name = r.demoName
	demo.Parent = r.demoParent or Workspace
end

-- Everything a shot starts with. Called once per shot, in order; a shot the frame rate skipped still starts.
local function enterShot(r: Run, position: number)
	local shot = r.shots[position]
	r.shot = position
	r.cut = 1
	r.cuts = shot.cuts
	if shot.cuts[1] ~= nil and shot.cuts[1].area ~= nil then
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
	local following = r.shots[position + 1]
	if following ~= nil then
		for _, cut in following.cuts do
			streamAround(cut.to.look)
		end
	end

	local you = r.you
	if not shot.cannon then
		-- the cannon back at rest and covered as the night has it, from the cut out of shot 2 on
		restoreTurret(r)
		coverBack(r)
	end
	if shot.catch then
		-- a hard cut to the catch spot, facing the Tuxedo; real strays round the catch and the run are hidden
		local stray, spot = Intro.strayPoint(), Intro.catchSpot()
		local points = Intro.runPath()
		table.insert(points, stray)
		r.nearDemo = straysNear(points, Intro.DEMO_HIDE_RADIUS)
		for _, real in r.nearDemo do
			hide(r, real)
		end
		if you ~= nil then
			showYou(r, you, true)
			placeYou(you, spot, toward(spot, stray))
			playYou(you, "idle")
		end
		UI.intro.demoCatch(stray + Vector3.new(0, 1, 0))
	end
	if shot.run then
		r.basket = campBasket(r)
		if you ~= nil and r.demo ~= nil and not r.held then
			holdDemo(r, you, r.demo :: Model) -- in your arms for the run, even when a slow frame skipped the hop
		end
	end
	if not shot.you and not r.done.sceneOver then
		-- at the cut to shot 5 your copy and the demo cat go and the real character shows at the spawn; the strays
		-- hidden round the catch come back
		r.done.sceneOver = true
		if you ~= nil then
			if r.flying then
				CannonFx.stopStaged(you.model)
				r.flying = false
			end
			you.model:Destroy()
			r.you = nil
		end
		if r.demo ~= nil then
			(r.demo :: Model):Destroy()
			r.demo = nil
			r.held = false
		end
		for _, stray in r.nearDemo do
			show(r, stray)
		end
		table.clear(r.nearDemo)
		if r.characterHidden then
			hideCharacter(r, false)
		end
	end
	if shot.job then
		hideRealWaiter(r)
	elseif r.seated ~= nil or #r.waiters > 0 then
		-- after shot 5 the seated waiter goes and a real one hidden for it comes back
		if r.seated ~= nil then
			(r.seated :: Model):Destroy()
			r.seated = nil
		end
		for _, waiter in r.waiters do
			show(r, waiter)
		end
		table.clear(r.waiters)
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

	UI.intro.setShot(shot.index, shot.caption, if r.cuts[1] ~= nil then r.cuts[1].title else nil)
	Moments.IntroShot:Fire(shot.index)
end

-- Shot 1, `t` seconds in: your copy at the ladder's foot, its hop into the barrel, the turn, the wiggle and the fuse.
local function stageLaunch(r: Run, t: number)
	local you, cannon = r.you, r.cannon
	local aim = Intro.cannonAim()
	if t >= Intro.AIM_FROM and t < Intro.AIM_TO then
		aimTurret(
			r,
			aim * Intro.ease("InOut", (t - Intro.AIM_FROM) / (Intro.AIM_TO - Intro.AIM_FROM))
		)
	elseif t >= Intro.AIM_TO then
		local k = math.clamp((t - Intro.AIM_TO) / (Intro.WIGGLE_TO - Intro.AIM_TO), 0, 1)
		aimTurret(r, aim + Intro.WIGGLE_DEGREES * math.sin(k * 3 * math.pi) * (1 - k))
	end
	if you == nil then
		return
	end
	local ladder = if cannon ~= nil then cannon.ladder else NO_LADDER
	local seat = if cannon ~= nil then cannon.seat else CFrame.new(Intro.NO_CANNON_MUZZLE)
	if t >= Intro.CLIMB_AT and not r.done.hop then
		-- Animation-Engineer's hop pose (crouch, arms up, curl into the ball) runs from StagedFlightAt, in server time
		r.done.hop = true
		you.model:SetAttribute(
			"StagedFlightAt",
			Workspace:GetServerTimeNow() - (t - Intro.CLIMB_AT)
		)
		you.model:SetAttribute("StagedFlight", "hop")
	end
	if t < Intro.CLIMB_AT then
		placeYou(you, ladder, toward(ladder, seat.Position))
	elseif t < Intro.CLIMB_AT + Intro.CLIMB_SECONDS then
		-- the root's path up into the barrel; the body's pose comes from StagedFlight
		local k = (t - Intro.CLIMB_AT) / Intro.CLIMB_SECONDS
		local from = ladder + Vector3.new(0, you.height, 0)
		local at = from:Lerp(seat.Position, Intro.ease("Out", k))
			+ Vector3.new(0, Intro.CLIMB_HEIGHT * math.sin(math.pi * k), 0)
		you.root.CFrame = CFrame.lookAt(at, at + toward(ladder, seat.Position))
	else
		you.root.CFrame = seat
		showYou(r, you, false) -- out of sight in the barrel
	end
	if t >= Intro.FUSE_AT and not r.done.fuse then
		-- the fuse fizzes BOOM_LEAD before the BOOM at the start of shot 2, on Effects/Cannon's staged beats
		r.done.fuse = true
		local boomAt = Workspace:GetServerTimeNow() + Intro.BOOM_LEAD
		r.boomAt = boomAt
		local flight = r.shots[r.shot + 1]
		local stage = if r.alleyStreamed or flight == nil then nil else heldStage(flight.seconds)
		CannonFx.playStaged(
			you.model,
			if cannon ~= nil then cannon.model else nil,
			Intro.AREA,
			boomAt,
			stage
		)
		r.flying = true
		UI.cannon.flight(Intro.AREA, boomAt - Intro.CARD_LEAD, Intro.CARD_HOLD)
	end
end

-- Shot 2, `t` seconds in: the ball out of the muzzle and up into the sky, then the drop onto the Alleyway's pad.
local function stageFlight(r: Run, t: number)
	local you = r.you
	if you == nil then
		return
	end
	if not r.done.boom then
		r.done.boom = true
		local cannon = r.cannon
		local muzzle = if cannon ~= nil then attachment(cannon.model, "Muzzle") else nil
		r.muzzle = if muzzle ~= nil
			then (muzzle :: Attachment).WorldPosition
			else Intro.NO_CANNON_MUZZLE
		local turn = math.rad(Intro.cannonAim())
		r.aim = Vector3.new(math.sin(turn), 0, math.cos(turn))
		you.model:SetAttribute("StagedFlight", "ball") -- curled, its middle on the root, so the spin rolls it
	end
	if t < Intro.PUFF_AT then
		showYou(r, you, true)
		local at = Intro.arcPoint(r.muzzle, r.aim, t)
		local spin = SPIN_TURNS * 2 * math.pi * (t / Intro.PUFF_AT)
		you.root.CFrame = CFrame.lookAt(at, at + r.aim) * CFrame.Angles(-spin, 0, 0)
		return
	end
	local height = Intro.dropHeight(t)
	if height == nil or not r.alleyStreamed then
		showYou(r, you, false) -- gone in the cloud puff, waiting over the pad
		placeYou(you, r.camp.pad + Vector3.new(0, Intro.DROP_HEIGHT, 0), r.camp.u)
		return
	end
	if not r.done.land then
		-- the curled fall, opening just before LAND_AT, then the crouch, bounce and stand (the pose's, not the root's)
		r.done.land = true
		you.model:SetAttribute("StagedFlightAt", r.boomAt + Intro.LAND_AT)
		you.model:SetAttribute("StagedFlight", "land")
	end
	showYou(r, you, true)
	placeYou(you, r.camp.pad + Vector3.new(0, height :: number, 0), r.camp.u)
end

-- Shot 3, `t` seconds in: PERFECT, then the cat's hop into your arms.
local function stageCatch(r: Run, t: number)
	local you = r.you
	if you == nil then
		-- nobody to catch it: the demo cat fades, as before the carry
		if t >= Intro.HOP_FROM and not r.done.demoFade and r.demo ~= nil then
			r.done.demoFade = true
			hide(r, r.demo :: Model, DEMO_FADE_SECONDS)
		end
		return
	end
	if r.demo == nil or r.held or t < Intro.HOP_FROM then
		return
	end
	local demo = r.demo :: Model
	if r.hopFrom == nil then
		r.hopFrom = demo:GetPivot()
	end
	local u = math.clamp((t - Intro.HOP_FROM) / Intro.HOP_SECONDS, 0, 1)
	if u >= 1 then
		holdDemo(r, you, demo)
		return
	end
	local arc = Intro.HOP_HEIGHT * math.sin(math.pi * u)
	demo:PivotTo(
		(r.hopFrom :: CFrame):Lerp(you.root.CFrame * CARRIED, Intro.ease("Out", u))
			+ Vector3.new(0, arc, 0)
	)
end

-- Shot 4, `t` seconds in: the turn toward the way out, the run into the camp, the check-in as you cross the camp
-- line and the turn to watch the cat go.
local function stageRun(r: Run, t: number)
	local you = r.you
	local path = Intro.runPath()
	if t >= Intro.checkInAt() and not r.done.checkIn then
		r.done.checkIn = true
		local demo = r.demo
		if demo ~= nil then
			-- the real check-in on this screen: the cat hops into the basket and puffs away (Effects/Cannon)
			releaseDemo(r, you, demo)
			CannonFx.checkInStaged(demo, r.basket)
			demo:Destroy()
			r.demo = nil
		end
	end
	if you == nil then
		return
	end
	local stopAt = Intro.stopAt()
	if t < Intro.TURN_SECONDS then
		turnYou(
			you,
			path[1],
			toward(path[1], Intro.strayPoint()),
			toward(path[1], path[2]),
			t / Intro.TURN_SECONDS
		)
	elseif t < stopAt then
		playYou(you, "run")
		local ground, facing = Intro.along(path, (t - Intro.TURN_SECONDS) * Intro.RUN_SPEED)
		placeYou(you, ground, facing)
	else
		playYou(you, "idle")
		local stop = path[#path]
		turnYou(
			you,
			stop,
			toward(path[#path - 1], stop),
			toward(stop, r.camp.basket),
			(t - stopAt) / Intro.WATCH_SECONDS
		)
	end
end

-- Shot 5, `t` seconds in: the Tuxedo in its seat, the job card, the outfit and the rate tag.
local function stageJob(r: Run, t: number)
	local function once(name: string, at: number): boolean
		if t >= at and not r.done[name] then
			r.done[name] = true
			return true
		end
		return false
	end
	if once("seated", Intro.JOB_SEATED_AT) then
		r.seated = stageSeated(r)
		if r.seated ~= nil then
			Moments.IntroCatSeated:Fire(waiterSpot(r).Position, r.seated :: Model) -- a small puff
		end
	end
	if once("jobCard", Intro.JOB_CARD_AT) then
		UI.intro.jobCard(waiterSpot(r).Position, Intro.JOB_ROLE)
	end
	if once("dressed", Intro.JOB_DRESS_AT) and r.seated ~= nil then
		dressSeated(r.seated :: Model)
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

-- The timed beats of shots 8 and 9, `t` seconds into the showing shot.
local function beats(r: Run, shot: Intro.Shot, t: number)
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
		if once("coverDown", Intro.NIGHT_TO) then
			cover(r, true)
		end
		if once("sunrise", Intro.SUNRISE_FROM) then
			WorldController.previewPhase("day", Intro.SUNRISE_TO - Intro.SUNRISE_FROM)
			cover(r, false)
		end
	end
	if r.wheel ~= nil then
		local wheel = r.wheel :: { model: Model, base: CFrame }
		local turn = Intro.ease("Out", t / shot.seconds) * WHEEL_TURNS * 2 * math.pi
		wheel.model:PivotTo(wheel.base * CFrame.Angles(0, 0, -turn))
	end
end

local finish: (finished: boolean) -> ()

local function step()
	local r = run
	if r == nil or r.ended then
		return
	end
	local elapsed = os.clock() - r.started
	local position = Intro.shotAt(r.shots, elapsed)
	if position == 0 then
		finish(true)
		return
	end
	while r.shot < position do
		enterShot(r, r.shot + 1)
	end
	local shot = r.shots[position]
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
		UI.intro.setShot(shot.index, shot.caption, r.cuts[cut].title)
	end
	local c = r.cuts[cut]
	setCamera(Intro.at(c, shot.ease, (t - cutStart) / c.seconds))
	if shot.you then
		hideCharacter(r, true)
	end
	if shot.launch then
		stageLaunch(r, t)
	elseif shot.flight then
		stageFlight(r, t)
	elseif shot.catch then
		stageCatch(r, t)
	elseif shot.run then
		stageRun(r, t)
	elseif shot.job then
		stageJob(r, t)
	end
	beats(r, shot, t)
end

finish = function(finished: boolean)
	local r = run
	if r == nil or r.ended then
		return
	end
	r.ended = true
	RunService:UnbindFromRenderStep(RENDER_STEP)
	if r.flying and r.you ~= nil then
		CannonFx.stopStaged((r.you :: You).model)
	end
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
	restoreTurret(r)
	coverBack(r)
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
	local showing = r.shots[r.shot]
	Net.fire(
		"IntroDone",
		if finished then 0 else (if showing ~= nil then showing.index else 1),
		r.replay
	)
	run = nil
	Moments.IntroEnd:Fire()
end

-- Plays the intro from the first shot. `replay` is a replay from the Tutorial tile or Settings: Skip shows at once
-- and the server saves nothing. Does nothing while one is playing or without a plot. Yields up to STREAM_WAIT while
-- the Alleyway's camp streams in.
function IntroController.play(replay: boolean)
	local state = UIController.state
	if run ~= nil or starting or state == nil or state.plotIndex == 0 then
		return
	end
	starting = true
	local camp = Intro.camp(Intro.AREA) :: Intro.Camp
	-- with streaming on the camps are far from the spawn this client holds: ask for the Alleyway's pad and wait
	pcall(function()
		player:RequestStreamAroundAsync(camp.pad, Intro.STREAM_WAIT)
	end)
	starting = false
	state = UIController.state
	if run ~= nil or state == nil or state.plotIndex == 0 then
		return
	end
	-- the other camps and the Alleyway's board stream in during shots 1 to 4
	for _, area in Intro.CAMP_CUTS do
		local other = Intro.camp(area)
		if other ~= nil then
			streamAround(other.wayOut + other.u * 10)
		end
	end
	streamAround(camp.board)
	local alleyStreamed = streamedNear(camp.pad)
	local plot = Intro.plot(state.plotIndex)
	local camera = Workspace.CurrentCamera
	local r: Run = {
		replay = replay,
		started = os.clock(),
		shots = Intro.shots(plot, hasCodesCat(), alleyStreamed),
		plot = plot,
		camp = camp,
		alleyStreamed = alleyStreamed,
		shot = 0,
		cuts = {},
		cut = 1,
		character = player.Character,
		staged = {},
		hidden = {},
		covers = {},
		tweens = {},
		you = nil,
		characterHidden = false,
		cannon = townCannon(),
		flying = false,
		boomAt = 0,
		muzzle = Intro.NO_CANNON_MUZZLE,
		aim = Vector3.new(0, 0, 1),
		demo = nil,
		demoName = "",
		demoParent = nil,
		hopFrom = nil,
		held = false,
		basket = nil,
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

	-- the demo Tuxedo waits at S through shot 3, facing the catch spot
	if alleyStreamed then
		local strayAt, catchAt = Intro.strayPoint(), Intro.catchSpot()
		r.demo =
			stageCat(r, Intro.DEMO_CAT, CFrame.lookAt(strayAt, strayAt + toward(strayAt, catchAt)))
	end
	r.you = stageYou(r)
	if r.you ~= nil then
		local you = r.you :: You
		local ladder = if r.cannon ~= nil then (r.cannon :: TownCannon).ladder else NO_LADDER
		placeYou(you, ladder, toward(ladder, Vector3.zero))
		playYou(you, "idle")
		hideCharacter(r, true)
	end
	aimTurret(r, 0) -- at rest, facing north, until it turns toward the Alleyway in shot 1
	cover(r, false) -- lifted for shots 1 and 2 when it is night

	UI.intro.start({ skipAfter = if replay then 0 else Intro.SKIP_AFTER, replay = replay })
	Moments.IntroStart:Fire(replay)
	-- at Camera priority, under Effects/Cannon's BOOM shake at Camera + 1
	RunService:BindToRenderStep(RENDER_STEP, Enum.RenderPriority.Camera.Value, step)
end

function IntroController.playing(): boolean
	return run ~= nil
end

function IntroController.start()
	Net.on("ProfileSync", function(s: Types.PlayerState)
		if
			Config.IntroAutoPlay
			and not firstStarted
			and s.introSeen == false
			and s.plotIndex ~= 0
		then
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
