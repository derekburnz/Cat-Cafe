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
-- Shots 1 to 4 (section 2a): a local copy of your own character, tagged StagedCharacter so Effects pose its carry (and
-- IntroNoNet, so it holds no net, #1252), climbs into the Town Square's cannon, flies to the Alleyway camp's pad on
-- Effects/Cannon's staged flight, catches the demo Tuxedo just past the way out and carries it into the camp, where it
-- hops into the basket. The real character stays at the spawn the whole time, hidden on this screen until shot 5. In
-- shot 5 the cat takes the waiter spot in your cafe in its outfit with its rate tag. Everything staged here is local
-- and goes at the end: your copy, the demo cat, the seated waiter, the strays and the real waiter hidden, the cannon's
-- turn and moon cover, the turning wheel and the short night. The end, played out or skipped (UI.events.introSkip) or
-- cut short by a respawn, puts all of it back and sends IntroDone(shot, replay): 0 when it played out, else the shot
-- showing.
-- #2495 (Derek2: "instead of playing the tackle cutscene right after finish tutorial to make it part of the actual
-- tutorial just the last steps"): on every play, a replay from the Tutorial tile or Settings too (#2522, Derek2:
-- "Tackling still seems to not be added to tutorial cutscenes"), the tackling lesson's four captions are the intro's
-- last steps on the same screen (dots Intro.SHOTS + 1 to + 4, Next and Skip as for any shot), staged
-- by stageTackle once the intro's own shots are put back. Played out on a first play, the lesson is saved as seen
-- (TipSeen; a replay saves nothing, as for the intro); a Skip
-- ends both. Since #2544 the lesson never plays on its own anywhere else. #2626 turned the tail off (TAIL_ON): the
-- lesson is the UI's context tip again, the first time the player is safe after being tackled. It needs the screen's dots past
-- Intro.SHOTS (IntroLogic.MAX_SHOTS, UI-Engineer); without them it doesn't play.

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
local Config = require(Shared:WaitForChild("Config"))
local HeldCat = require(Shared:WaitForChild("HeldCat"))
local Intro = require(Shared:WaitForChild("Intro"))
local UserInputService = game:GetService("UserInputService")
local Moments = require(script.Parent.Parent.Moments)
local Net = require(script.Parent.Parent.Net)
local Presets = require(script.Parent.Parent.Effects.Presets)
local TackleStage = require(Shared:WaitForChild("TackleStage"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(script.Parent.Parent.UI)
local UIController = require(script.Parent.UIController)
local WorldController = require(script.Parent.WorldController)

local IntroController = {}

-- #2495: the tackling lesson as the intro's last steps; one table, as the module is short of locals
local Tail = {
	Logic = require(script.Parent.Parent.UI.Components.TackleLessonLogic),
	IntroLogic = require(script.Parent.Parent.UI.Components.IntroLogic) :: any,
	TipQueue = require(script.Parent.Parent.UI.Components.TipQueue),
	Scale = require(script.Parent.Parent.UI.Scale),
	shown = 0, -- the lesson step showing, 0 while no tail runs
	save = false, -- a first play's tail: played out, it saves the lesson as seen
	lines = {} :: { string },
	device = "keyboard" :: any,
	show = nil :: ((index: number) -> ())?,
	stop = nil :: ((played: boolean) -> ())?,
}

local player = Players.LocalPlayer
local RENDER_STEP = "CatCafeIntro"
local DEMO_FADE_SECONDS = 0.4 -- with no copy of you to catch it, the demo cat fades at the hop instead
local LESSON_IN = 3 -- #2446: the tackling lesson's viewpoint, this far into the Alleyway past the middle of its way in
local LESSON_CLEAR = 4 -- real strays this much further out than the intro's DEMO_HIDE_RADIUS are hidden for it
local LESSON_CAMERA_BACK = 60 -- studs: the lesson's end puts back the view it started with only this near the player
local STREAMED_RADIUS = 40 -- a camp counts as streamed in when a part stands this close to the point checked
local CAMP_ASK_EVERY = 2 -- seconds between asks for the camp's ground while the intro plays (#2961)
local CAMP_POLL = 0.1 -- seconds between looks for the camp's ground while play() waits for it (#2961)
local FUSE_HOLD_EARLY = 0.001 -- shot 1 holds this short of its fuse, so the fuse waits with it (#2961)
local WHEEL_TURNS = 2
local BLEND = 0.15 -- seconds an animation of your copy fades in or out
local SPIN_TURNS = 2 -- the ball's tumbles on the way up
local NO_LADDER = Vector3.new(0, 0.1, -7.5) -- the foot of the town cannon's south steps without its Climb part
local STAGED = "StagedCharacter" -- Tackle.luau poses a model with this tag (and no player) like a character
local NO_NET = "IntroNoNet" -- Effects/NetHold.luau shows no net on a staged copy with this set (#1252)
-- The attributes a copy of the character must not keep from it: no carry, no flight, no camp.
local COPY_CLEARS = {
	"CarryingCatId",
	"NetHidden",
	"Launching",
	"CannonLaunchAt",
	"CannonFrom",
	"CannonTo",
	"CannonHeading",
	"CloudHopAt",
	"CloudHopTo",
	"Camp",
}
-- The avatar's own animations your copy plays: the Animate script's StringValue for each and its Animation's name.
local ANIMATIONS: { [string]: string } = { run = "RunAnim", idle = "Animation1" }

-- Your local copy for shots 1 to 4: moved by its anchored root, playing the avatar's own animations.
type You = {
	model: Model,
	root: BasePart,
	height: number, -- the root's height above the ground it stands on
	tracks: { [string]: AnimationTrack }, -- "run" and "idle", the avatar's own where the Animate script names them
	playing: string?,
	shown: boolean,
}

-- Shot 6 (#2242): where it plays in your cafe and what it has staged.
type Rich = {
	door: Vector3, -- where the visitor and your copy come in (the plot's Door waypoint), at the visitor's pivot height
	tip: Vector3, -- the coin pile's anchor (the plot's RichTipAnchor)
	seat: CFrame?, -- table 1's chair, where the visitor sits
	route: { Vector3 }, -- #2395: the door, then round the tables to the chair (or the grab spot), at the door's height
	furniture: { Model }, -- #2395: table 1 and its chairs, staged in a new cafe that has no table yet
	visitor: Model?, -- walking, then its seated twin
	coins: Model?,
	you: You?,
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
	shotStarted: number, -- os.clock() when the showing shot began (#2182: each shot runs for its hold, or to Next)
	shots: { Intro.Shot },
	plot: Intro.Plot,
	camp: Intro.Camp, -- the Alleyway's
	alleyStreamed: boolean,
	shot: number, -- the position in `shots` of the shot showing, 0 before the first
	cuts: { Intro.Cut }, -- the showing shot's cuts (the last shot's ends at the character)
	cut: number, -- the cut showing
	jumpFired: number, -- the last place change Moments.IntroCut went out for, as position * 100 + cut (#958)
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
	rich: Rich?, -- shot 6's rich visitor, coin pile and your copy (#2242)
	wheel: { model: Model, base: CFrame }?,
	done: { [string]: boolean }, -- the timed beats inside a shot that have happened
	campHeld: number, -- #2961: seconds shot 1 has held before its fuse for the camp's ground to stream in
	controls: any?, -- the PlayerModule's controls, disabled for the run
	promptsWere: boolean,
	cameraType: Enum.CameraType,
	ended: boolean,
	tail: boolean, -- #2495: the tackling lesson follows as the last steps
}

local run: Run? = nil
local starting = false -- a play is waiting for the camp to stream in
local firstStarted = false -- the first play of this session has begun
-- #2759: from the client's start to the first spawn, and through play()'s stream wait, the camera holds still on the
-- town square (parked). The default camera sits inside the town cannon until then: a yellow screen on a slow phone.
-- over the cannon from the square's north side, toward the south row's cafes (plots 1 and 2, the beginner's), all near
-- the spawn so streamed in first (Laptop-Tester: from the south side the first frame looked out at the hills)
local LOADING_VIEW: Intro.Key = { position = Vector3.new(0, 16, 16), look = Vector3.new(0, 6, -50) }
local PARK_GIVE_UP = 20 -- seconds: after this a spawn hands the camera back even without a ProfileSync
local parked = false
local parkedAt: Intro.Key = LOADING_VIEW
local parkBound = false
local PARK_STEP = "CatCafeIntroPark"
local synced = false -- the first ProfileSync has come, so it is known whether the intro plays
local gaveUp = false

-- The PlayerModule's controls, or nil when the default player scripts are not there.
-- #2967 (console pass 2): a caption that opens with "Tap" ("Tap as each circle closes!") names the input the player
-- last used: "Press A" on a gamepad, "Click" with a mouse or keyboard, "Tap" on touch.
local function deviceCaption(caption: string?): string?
	if caption == nil or caption:sub(1, 4) ~= "Tap " then
		return caption
	end
	local last = UserInputService:GetLastInputType().Name
	if last:sub(1, 7) == "Gamepad" then
		return "Press A " .. caption:sub(5)
	elseif
		last == "Touch" or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
	then
		return caption
	end
	return "Click " .. caption:sub(5)
end

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
	-- no shot of intro-cutscene.md shows a net (the shot 3 catch is the timing circle), so the copy holds none and
	-- keeps its arm down for the whole intro (#1252); the real character keeps its own net
	model:SetAttribute(NO_NET, true)
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
-- for shot 6's night, #2113), remembering each part's replicated Transparency for coverBack.
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

-- #2961: true when a ray straight down at `point` finds the area's floor (not this character, nor anything staged).
local function floorAt(point: Vector3, staged: { Instance }?): boolean
	local params = RaycastParams.new()
	local skip: { Instance } = if staged ~= nil then table.clone(staged) else {}
	if player.Character ~= nil then
		table.insert(skip, player.Character :: Model)
	end
	params.FilterDescendantsInstances = skip
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = Workspace:Raycast(point + Vector3.new(0, 30, 0), Vector3.new(0, -60, 0), params)
	return hit ~= nil and Intro.floorHit(hit.Position.Y)
end

-- #2961: the Alleyway's camp is in when the floor under the pad, the catch spot and the stray has streamed in. A prop
-- or wall by the pad alone let the camp shots play over an empty sky (Derek2 11-10, slides 2 and 3).
local function campReady(staged: { Instance }?): boolean
	for _, point in Intro.campGround().points do
		if not floorAt(point, staged) then
			return false
		end
	end
	return true
end

-- #2961: asks again for the camp's ground: the filmed spots and the area's middle, where the big ground and set
-- parts stand.
local function streamCamp()
	local ground = Intro.campGround()
	for _, point in ground.points do
		streamAround(point)
	end
	streamAround(ground.middle)
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

-- The demo cat into your copy's arms as its HeldCat, welded there asleep like the real carry (HeldCat, #1964).
local function holdDemo(r: Run, you: You, demo: Model)
	r.held = true
	r.demoName, r.demoParent = demo.Name, demo.Parent
	HeldCat.attach(demo, you.model, you.root)
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
	HeldCat.release(demo)
	demo.Name = r.demoName
	demo.Parent = r.demoParent or Workspace
end

-- Everything a shot starts with. Called once per shot, in order; a shot the frame rate skipped still starts.
-- #2242: shot 6's places in your cafe: its Door waypoint (where customers walk in), the RichTipAnchor and table 1's
-- first chair, else where shared/Intro works them out.
local function richPlace(r: Run): Rich
	local plot = UIController.ownPlot()
	local waypoints = if plot ~= nil then plot:FindFirstChild("CustomerWaypoints") else nil
	local doorPart = if waypoints ~= nil then waypoints:FindFirstChild("Door") else nil
	local anchor = if plot ~= nil then plot:FindFirstChild("RichTipAnchor") else nil
	local door = if doorPart ~= nil and doorPart:IsA("BasePart")
		then (doorPart :: BasePart).Position
		else Intro.doorPoint(r.plot)
	local tip = if anchor ~= nil and anchor:IsA("BasePart")
		then (anchor :: BasePart).Position
		else Intro.richTipPoint(r.plot)
	local seat: CFrame? = nil
	local between: { Vector3 } = {}
	local furniture: { Model } = {}
	local tables = if plot ~= nil then plot:FindFirstChild("Tables") else nil
	local group = if tables ~= nil then tables:FindFirstChild("table_1") else nil
	if group ~= nil then
		local chair = group:FindFirstChild("Chair_1")
		if chair ~= nil and chair:IsA("Model") then
			seat = (chair :: Model):GetPivot()
			-- CafeService's way to the chair, round the tables
			for _, name in { "Aisle", "Approach" } do
				local point = chair:GetAttribute(name)
				if typeof(point) == "Vector3" then
					table.insert(between, point)
				end
			end
		end
	else
		-- #2395 (Derek2: "doesn't go to the first table location"): a new cafe has no table yet, so table 1 and its
		-- chairs are staged on its anchor for the shot, as CafeService builds them
		local anchors = if plot ~= nil then plot:FindFirstChild("TableAnchors") else nil
		local spot = if anchors ~= nil then anchors:FindFirstChild("table_1") else nil
		if spot ~= nil and spot:IsA("BasePart") then
			local at = (spot :: BasePart).CFrame
			local tableModel = stageAsset(r, "CatCafe_Furniture_TableRound", at)
			if tableModel ~= nil then
				table.insert(furniture, tableModel)
			end
			for index, offset in
				{ Intro.cafe.seat1, { x = -Intro.cafe.seat1.x, rotY = -Intro.cafe.seat1.rotY } }
			do
				local chairAt = at
					* CFrame.new(offset.x, 0, 0)
					* CFrame.Angles(0, math.rad(offset.rotY), 0)
				local chair = stageAsset(r, "CatCafe_Furniture_Chair", chairAt)
				if chair ~= nil then
					table.insert(furniture, chair)
					if index == 1 then
						seat = chairAt
					end
				end
			end
			if seat ~= nil then
				between = Intro.richRoute(r.plot)
			end
		end
	end
	local route = { door }
	for _, point in between do
		table.insert(route, Vector3.new(point.X, door.Y, point.Z))
	end
	-- #2395 (Derek2: "floats into the ground"): the walk stays at the door's height, as CustomerController's does
	table.insert(
		route,
		if seat ~= nil
			then Vector3.new((seat :: CFrame).X, door.Y, (seat :: CFrame).Z)
			else Intro.grabSpot(door, tip)
	)
	return {
		door = door,
		tip = tip,
		seat = seat,
		route = route,
		furniture = furniture,
		visitor = nil,
		coins = nil,
		you = nil,
	}
end

local function clearRich(r: Run)
	local rich = r.rich
	r.rich = nil
	if rich == nil then
		return
	end
	for _, model in { rich.visitor, rich.coins, if rich.you ~= nil then rich.you.model else nil } do
		if model ~= nil then
			model:Destroy()
		end
	end
	for _, model in rich.furniture do
		model:Destroy()
	end
	UI.richTip.preview(nil)
end

-- The rich tip's gold coins on `tip` (CustomerController's pile: two stacks, 4 and 2), local, staged.
local function stageCoins(r: Run, tip: Vector3): Model
	local pile = Instance.new("Model")
	pile.Name = "IntroRichTipCoins"
	local top = tip.Y - 0.6 -- the table top under the anchor, as CustomerController reads it
	for _, stack in { { x = -0.35, z = 0.1, coins = 4 }, { x = 0.4, z = -0.15, coins = 2 } } do
		for n = 1, stack.coins do
			local coin = Instance.new("Part")
			coin.Name = "Coin"
			coin.Shape = Enum.PartType.Cylinder
			coin.Size = Vector3.new(0.14, 0.7, 0.7)
			coin.Color = Color3.fromRGB(255, 196, 56)
			coin.Material = Enum.Material.Metal
			coin.Anchored = true
			coin.CanCollide = false
			coin.CanQuery = false
			coin.CanTouch = false
			coin.CastShadow = false
			coin.CFrame = CFrame.new(tip.X + stack.x, top + 0.07 + (n - 1) * 0.14, tip.Z + stack.z)
				* CFrame.Angles(0, 0, math.rad(90))
			coin.Parent = pile
		end
	end
	pile.Parent = Workspace
	table.insert(r.staged, pile)
	return pile
end

local function enterShot(r: Run, position: number)
	local shot = r.shots[position]
	r.shot = position
	r.cut = 1
	r.cuts = shot.cuts
	if shot.follow then
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
	if shot.rich and r.rich == nil then
		r.rich = richPlace(r)
	elseif not shot.rich and r.rich ~= nil then
		clearRich(r) -- the visitor, the coins and your copy go at the cut to the night
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

	-- #2182: the hold fills the caption's read bar (UI-Engineer's fourth argument; the UI ignores it until then)
	(UI.intro :: any).setShot(shot.index, deviceCaption(shot.caption), nil, shot.hold)
	Moments.IntroShot:Fire(shot.index)
	Net.fire("TelemetryReport", "intro_shot", shot.index) -- #3098: quit_scene's shot and first_scene (analytics only)
end

-- #2759 (Derek2 11-09: on a phone emulation the catch steps were "just a yellow screen"): a slow phone can miss
-- the Alleyway's camp in play()'s STREAM_WAIT, and then shot 2 holds in the clouds and the camp shots (3 and 4) drop
-- out. play() keeps asking for the camp through shot 1, and at the fuse this looks again: streamed in by then, the
-- shots are rebuilt with the camp shots and the demo cat is staged, so the flight lands and the catch plays.
-- #2961: "in" means the floor under the filmed spots (campReady). step() holds shot 1 just short of the fuse up to
-- Intro.CAMP_WAIT for it first (Derek2: wait, don't skip); only a camp still missing after that (or one that was in
-- at the start and has streamed back out) drops the camp shots.
local function lateStream(r: Run)
	if not r.alleyStreamed and not campReady(r.staged) then
		return
	end
	if r.alleyStreamed then
		if campReady(r.staged) then
			return
		end
		-- #2961: in at the start but gone again (streamed back out): the clouds fallback, not an empty sky
		r.alleyStreamed = false
		r.shots = Intro.shots(r.plot, hasCodesCat(), false)
		if r.demo ~= nil then
			(r.demo :: Model):Destroy()
			r.demo = nil
		end
		return
	end
	r.alleyStreamed = true
	r.shots = Intro.shots(r.plot, hasCodesCat(), true)
	if r.demo == nil then
		local strayAt, catchAt = Intro.strayPoint(), Intro.catchSpot()
		r.demo =
			stageCat(r, Intro.DEMO_CAT, CFrame.lookAt(strayAt, strayAt + toward(strayAt, catchAt)))
	end
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
		lateStream(r) -- #2759: the camp may have streamed in during shot 1
		local flight = r.shots[r.shot + 1]
		local stage = if r.alleyStreamed or flight == nil then nil else heldStage(flight.hold)
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
		(r.hopFrom :: CFrame):Lerp(HeldCat.target(demo, you.model, you.root), Intro.ease("Out", u))
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

-- Shot 6 (#2242), `t` seconds in: the rich visitor walks from the door to table 1's chair and sits, its gold coins
-- show on the RichTipAnchor, your copy walks in from the door and grabs them with the UI's "+$" pop. Nothing is paid.
local function stageRich(r: Run, t: number)
	local rich = r.rich
	if rich == nil then
		return
	end
	local function once(name: string, at: number): boolean
		if t >= at and not r.done[name] then
			r.done[name] = true
			return true
		end
		return false
	end
	if once("richIn", Intro.RICH_WALK_AT) then
		local _, heading = Intro.alongPath(rich.route, 0)
		rich.visitor =
			stageAsset(r, Intro.RICH_ASSET, CFrame.lookAt(rich.door, rich.door + heading))
	end
	if rich.visitor ~= nil and t < Intro.RICH_SIT_AT then
		local k =
			math.clamp((t - Intro.RICH_WALK_AT) / (Intro.RICH_SIT_AT - Intro.RICH_WALK_AT), 0, 1)
		local at, heading = Intro.alongPath(rich.route, Intro.ease("InOut", k))
		local visitor = rich.visitor :: Model
		visitor:PivotTo(CFrame.lookAt(at, at + heading))
	end
	if once("richSit", Intro.RICH_SIT_AT) and rich.visitor ~= nil and rich.seat ~= nil then
		local seated = stageAsset(r, Intro.RICH_ASSET .. "_Sit", rich.seat :: CFrame)
		if seated ~= nil then
			(rich.visitor :: Model):Destroy()
			rich.visitor = seated
		end
	end
	if once("richTip", Intro.RICH_TIP_AT) then
		rich.coins = stageCoins(r, rich.tip)
		-- #2395 (Derek2: "doesn't show the rich tip bubble like it would in game"): the game's gold bubble over it
		UI.richTip.preview(rich.tip, Intro.richTip())
	end
	local floor = Vector3.new(rich.door.X, Intro.FLOOR_Y, rich.door.Z)
	local grab = Intro.grabSpot(floor, rich.tip)
	if once("richYou", Intro.RICH_GRAB_FROM) then
		rich.you = stageYou(r)
		if rich.you ~= nil then
			playYou(rich.you :: You, "run")
		end
	end
	local you = rich.you
	if you ~= nil and t >= Intro.RICH_GRAB_FROM then
		local k = math.clamp(
			(t - Intro.RICH_GRAB_FROM) / (Intro.RICH_GRAB_AT - Intro.RICH_GRAB_FROM),
			0,
			1
		)
		placeYou(
			you,
			floor:Lerp(grab, k),
			if k < 1 then toward(floor, grab) else toward(grab, rich.tip)
		)
	end
	if once("richGrab", Intro.RICH_GRAB_AT) then
		if you ~= nil then
			playYou(you, "idle")
		end
		if rich.coins ~= nil then
			(rich.coins :: Model):Destroy()
			rich.coins = nil
		end
		local intro: any = UI.intro
		intro.tipPop(rich.tip + Vector3.new(0, 1, 0), Intro.richTip())
		UI.richTip.preview(nil) -- the bubble goes as the "+$" pops, as a claimed tip's does
	end
end

-- The timed beats of shots 7 and 8, `t` seconds into the showing shot.
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

-- #958 (Derek 2026-11-03: "make the locations cuts smoother"): CUT_LEAD before the camera jumps to a far place
-- (Intro.jump), at the end of a cut or a shot, Moments.IntroCut(at, nextSeconds) tells Effects to dip through the
-- clouds: `at` the os.clock() of the jump, `nextSeconds` how long the next cut lasts. Never inside or into the
-- cannon flight shot, which has its own clouds.
local function aheadOfJump(
	r: Run,
	position: number,
	shot: Intro.Shot,
	cut: number,
	cutStart: number,
	camera: number,
	t: number
)
	local id = position * 100 + cut
	if r.jumpFired == id or shot.flight then
		return
	end
	local last = cut == #r.cuts
	-- #2182: the last cut ends with the shot's hold; one before it where the camera's moves say
	local left = if last then shot.hold - t else cutStart + r.cuts[cut].seconds - camera
	if left > Intro.CUT_LEAD then
		return
	end
	r.jumpFired = id
	local nextCut: Intro.Cut? = nil
	if not last then
		nextCut = r.cuts[cut + 1]
	else
		local following = r.shots[position + 1]
		if following ~= nil and not following.flight and following.cuts[1] ~= nil then
			nextCut = following.cuts[1]
		end
	end
	if nextCut ~= nil and Intro.jump(r.cuts[cut].to, nextCut.from) then
		Moments.IntroCut:Fire(os.clock() + left, nextCut.seconds)
	end
end

local finish: (finished: boolean) -> ()

-- The showing shot's action `t` seconds in. #2182: the action keeps its section 2 timings and holds its last frame
-- through the rest of the hold; shot 1 waits in the barrel instead (Intro.launchTime), so the BOOM starts shot 2.
local function stage(r: Run, shot: Intro.Shot, t: number)
	local action = math.min(t, shot.seconds)
	if shot.launch then
		stageLaunch(r, Intro.launchTime(shot, t))
	elseif shot.flight then
		stageFlight(r, action)
	elseif shot.catch then
		stageCatch(r, action)
	elseif shot.run then
		stageRun(r, action)
	elseif shot.job then
		stageJob(r, action)
	elseif shot.rich then
		stageRich(r, action)
	end
	beats(r, shot, action)
end

local function step()
	local r = run
	if r == nil or r.ended then
		return
	end
	if r.shot == 0 then
		r.shotStarted = os.clock()
		enterShot(r, 1)
	end
	local shot = r.shots[r.shot]
	local t = os.clock() - r.shotStarted
	if shot.launch and not r.done.fuse then
		-- #2961: just before the fuse, shot 1 holds (the cannon loaded, you in the barrel) up to CAMP_WAIT while the
		-- camp's ground streams in, so the flight lands on it and the catch plays (Derek2 11-10: wait, don't skip)
		local fuse = Intro.fuseAt(shot) - FUSE_HOLD_EARLY
		if t >= fuse and r.campHeld < Intro.CAMP_WAIT and not campReady(r.staged) then
			r.campHeld += t - fuse
			r.shotStarted += t - fuse
			t = fuse
		end
	end
	while t >= shot.hold do
		if r.shot >= #r.shots then
			finish(true)
			return
		end
		r.shotStarted += shot.hold
		enterShot(r, r.shot + 1)
		shot = r.shots[r.shot]
		t = os.clock() - r.shotStarted
	end
	local position = r.shot
	-- the cut showing and how far through it, on the camera's time (#2182: it eases to a stop, then holds)
	local camera = Intro.cameraTime(shot, t)
	local cutStart = 0
	local cut = #r.cuts
	for i, c in r.cuts do
		if camera < cutStart + c.seconds or i == #r.cuts then
			cut = i
			break
		end
		cutStart += c.seconds
	end
	r.cut = cut
	local c = r.cuts[cut]
	setCamera(Intro.at(c, shot.ease, (camera - cutStart) / c.seconds))
	aheadOfJump(r, position, shot, cut, cutStart, camera, t)
	if shot.you then
		hideCharacter(r, true)
	end
	stage(r, shot, t)
end

-- #2182 (section 2b): Next, from Intro.NEXT_AFTER into a shot (the UI drops earlier presses too). The shot's beats
-- run to their end first, so nothing it started is left half done (the short night's sunrise), then the next shot
-- shows at once; on the last shot it ends the intro as a finish. In shot 1 it goes on to the fuse instead, since the
-- BOOM BOOM_LEAD later starts shot 2.
local function nextShot()
	local tailShow = Tail.show
	if Tail.shown > 0 and tailShow ~= nil then
		tailShow(Tail.shown + 1) -- #2495: the screen lets one Next through a step, from NEXT_AFTER
		return
	end
	local r = run
	if r == nil or r.ended or r.shot == 0 then
		return
	end
	local shot = r.shots[r.shot]
	local t = os.clock() - r.shotStarted
	if t < Intro.NEXT_AFTER then
		return
	end
	if shot.launch then
		local fuse = Intro.fuseAt(shot)
		if t < fuse then
			r.shotStarted = os.clock() - fuse
		end
		return
	end
	stage(r, shot, shot.seconds)
	if r.shot >= #r.shots then
		finish(true)
		return
	end
	r.shotStarted = os.clock()
	enterShot(r, r.shot + 1)
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
	clearRich(r) -- #2395: and the rich tip's bubble, on a skip mid-shot
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

	-- #2495: played out, the screen stays up for the tackling lesson's steps
	local tailing = finished and r.tail and Tail.show ~= nil
	if not tailing then
		UI.intro.finish()
	end
	local showing = r.shots[r.shot]
	Net.fire(
		"IntroDone",
		if finished then 0 else (if showing ~= nil then showing.index else 1),
		r.replay
	)
	run = nil
	local tailShow = Tail.show
	if tailing and tailShow ~= nil then
		Tail.device =
			Tail.TipQueue.device(UserInputService:GetLastInputType().Name, Tail.Scale.isTouch())
		Tail.lines = Tail.Logic.lines(Tail.device)
		Tail.save = not r.replay
		tailShow(1)
	else
		Moments.IntroEnd:Fire()
	end
end

-- The tackling lesson's stage (#2312, Derek2: "the cut scene for explaining tackling doesn't actually take control of
-- your camera like tutorial so it doesn't show you it properly"): UI's lesson (Screens/TackleLesson) calls
-- stageTackle(shot) as each caption shows and stageTackle(0) at its end. In front of the player (shared/TackleStage) a
-- copy of you carries a cat across, another copy (StagedTackle, so Effects/Tackle dives it) lunges and knocks it back,
-- the cat drops; over the tackler's shoulder it happens again and the tackler takes the cat (#2469); last the knocked
-- copy pins a new cat with its net, the "!" over it, alone (#2495, Derek2: "remove the second random player holding
-- a cat in the last part": the tackler and its cat are off the stage for that shot). The camera is this screen's while it
-- plays and the controls and prompts are off; everything is local and goes at the end, the camera back as it was.
type Lesson = {
	r: any, -- staged, hidden and tweens, like a Run's, for stageYou
	scene: TackleStage.Scene,
	carrier: You?,
	tackler: You?,
	cat: Model?,
	holder: You?, -- who has the cat in its arms: the carrier, the tackler once it took it (#2469), or nobody
	catch: Model?, -- shot 4's cat, pinned by the knocked copy's net (#2469)
	swung: boolean,
	pinned: boolean,
	shot: number,
	shotAt: number, -- os.clock() the showing shot began
	cameraFrom: CFrame, -- where the camera was when the shot began, for the glide
	knocked: boolean,
	cameraWas: CFrame,
	cameraTypeWas: Enum.CameraType,
	controls: any?,
	promptsWere: boolean,
	character: Model?,
}

local LESSON_STEP = "CatCafeTackleLesson"
local LESSON_GLIDE = 0.6 -- seconds the camera glides to each shot's view
local KNOCK_SECONDS = 0.25
local lesson: Lesson? = nil

local function lessonDrop(l: Lesson, at: Vector3)
	local holder, cat = l.holder, l.cat
	if cat == nil or holder == nil then
		return
	end
	l.holder = nil
	holder.model:SetAttribute("CarryingCatId", nil)
	HeldCat.release(cat)
	cat.Parent = Workspace
	cat:PivotTo(CFrame.lookAt(at, at + l.scene.forward))
end

-- The cat into `who`'s arms, out of anyone else's.
local function lessonHold(l: Lesson, who: You?)
	local cat = l.cat
	if who == nil or cat == nil or l.holder == who then
		return
	end
	lessonDrop(l, who.root.Position)
	l.holder = who
	HeldCat.attach(cat, who.model, who.root)
	cat.Parent = who.model
	who.model:SetAttribute("CarryingCatId", Intro.DEMO_CAT)
end

-- Shot 4's catch, `t` seconds in (#2469): the knocked copy holds its net up, swings at SWING_AT and from PIN_AT the
-- net is down on the cat with its "!" (NetDown on a StagedStray, as the server sets it on a stray being caught), the
-- hand empty as a real catcher's is.
local function lessonCatch(l: Lesson, t: number)
	local carrier, cat = l.carrier, l.catch
	if carrier == nil or cat == nil then
		return
	end
	if t >= TackleStage.SWING_AT and not l.swung then
		l.swung = true
		carrier.model:SetAttribute(TackleStage.SWING_ATTRIBUTE, Workspace:GetServerTimeNow())
	end
	if t >= TackleStage.PIN_AT and not l.pinned then
		l.pinned = true
		cat:SetAttribute("NetDown", true)
		carrier.model:SetAttribute(NO_NET, true)
	end
end

local function lessonStep()
	local l = lesson
	if l == nil then
		return
	end
	local t = os.clock() - l.shotAt
	local scene = l.scene
	local carrier, tackler = l.carrier, l.tackler
	local landed = TackleStage.LUNGE_AT + TackleStage.LUNGE_SECONDS
	local tackling = l.shot == 2 or l.shot == 3 -- #2469: shot 3 is you tackling, not only the camera over you
	local walking = l.shot ~= 4
	local carrierAt = TackleStage.walkAt(scene.walkFrom, scene.walkTo, t)
	local carrierFacing = scene.right
	if tackling and t >= landed then
		if not l.knocked then
			l.knocked = true
			lessonDrop(l, scene.drop)
			Moments.Shove:Fire("bystander", scene.hit)
			Moments.BumpLoose:Fire("bystander", scene.hit)
		end
		carrierAt = scene.hit
			+ scene.knock
				* TackleStage.KNOCK_STUDS
				* math.clamp((t - landed) / KNOCK_SECONDS, 0, 1)
		walking = false
	elseif l.shot == 4 then
		carrierAt = scene.knocked
		carrierFacing = toward(scene.knocked, scene.catchAt)
		lessonCatch(l, t)
	end
	if carrier ~= nil then
		local moving = walking and (carrierAt - scene.walkTo).Magnitude > 0.05
		placeYou(carrier, carrierAt, carrierFacing)
		playYou(carrier, if moving then "run" else "idle")
	end
	if tackler ~= nil and tackler.model.Parent ~= nil then -- #2495: off the stage in shot 4
		local at, facing, moving = scene.tackler, toward(scene.tackler, carrierAt), false
		if l.shot == 2 then
			at = TackleStage.lungeAt(scene, t)
			facing = toward(at, carrierAt)
		elseif l.shot == 3 then
			local taken
			at, taken = TackleStage.pickupAt(scene, t)
			local from = TackleStage.pickupTimes(scene)
			facing = if t < from then toward(at, carrierAt) else toward(at, scene.drop)
			moving = t >= from and not taken
			if taken and l.knocked then
				lessonHold(l, tackler)
			end
		end
		placeYou(tackler, at, facing)
		playYou(tackler, if moving then "run" else "idle")
	end
	local camera = Workspace.CurrentCamera
	local key = scene.cameras[l.shot]
	if camera ~= nil and key ~= nil then
		local target = CFrame.lookAt(key.position, key.look)
		local k = math.clamp(t / LESSON_GLIDE, 0, 1)
		k = k * k * (3 - 2 * k)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = l.cameraFrom:Lerp(target, k)
	end
end

local function lessonEnd()
	local l = lesson
	if l == nil then
		return
	end
	lesson = nil
	RunService:UnbindFromRenderStep(LESSON_STEP)
	for _, tween in l.r.tweens do
		tween:Cancel()
	end
	for item in l.r.hidden do
		(item :: any).LocalTransparencyModifier = 0
	end
	for _, model in l.r.staged do
		model:Destroy()
	end
	if l.cat ~= nil then
		l.cat:Destroy()
	end
	local camera = Workspace.CurrentCamera
	if camera ~= nil then
		-- the camera goes back to following the player (Laptop-Tester on #2452: right after the intro the type saved
		-- at the lesson's start can still be Fixed, which left the view down the Alleyway, far from the player)
		local character = player.Character
		local humanoid = if character ~= nil
			then character:FindFirstChildOfClass("Humanoid") :: Humanoid?
			else nil
		camera.CameraType = Enum.CameraType.Custom
		if humanoid ~= nil then
			camera.CameraSubject = humanoid
		end
		-- the view it had, when that was near the player; otherwise the follow camera finds the player itself
		local root = rootOf(character)
		if
			root ~= nil
			and (l.cameraWas.Position - root.Position).Magnitude <= LESSON_CAMERA_BACK
		then
			camera.CFrame = l.cameraWas
		end
	end
	if l.controls ~= nil then
		pcall(function()
			l.controls:Enable()
		end)
	end
	ProximityPromptService.Enabled = l.promptsWere
end

local function lessonBegin(): Lesson?
	local character = player.Character
	local root = rootOf(character)
	local camera = Workspace.CurrentCamera
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if root == nil or camera == nil or humanoid == nil or run ~= nil then
		return nil
	end
	local r: any = { staged = {}, hidden = {}, tweens = {} }
	-- #2446 (Derek2: "show the tackling scene in an actual area using a cat instead of at spawn inside of the
	-- cannon"): the lesson follows the starting tutorial, when the player is usually at spawn on the town cannon, so
	-- it is staged in the Alleyway, where the intro's catch is filmed: LESSON_IN studs past the middle of its way in,
	-- facing into the lane (90 wide, so the whole scene is on open floor). The camera glides there and back; the
	-- player stays put. Without the camp (no Alleyway in this place) it falls back to the player's feet.
	local camp = Intro.camp(Intro.AREA)
	local scene: TackleStage.Scene
	if camp ~= nil then
		scene = TackleStage.scene(camp.wayOut + camp.u * LESSON_IN, camp.u)
		streamAround(scene.centre)
		-- real strays wandering through the shots are hidden on this screen, as in the intro's catch
		local points = { scene.walkFrom, scene.walkTo, scene.tackler, scene.centre, scene.catchAt }
		for _, real in straysNear(points, Intro.DEMO_HIDE_RADIUS + LESSON_CLEAR) do
			hide(r, real)
		end
	else
		local feet = (root :: BasePart).Position
			- Vector3.new(0, (humanoid :: Humanoid).HipHeight + (root :: BasePart).Size.Y / 2, 0)
		scene = TackleStage.scene(feet, (root :: BasePart).CFrame.LookVector)
	end
	local l: Lesson = {
		r = r,
		scene = scene,
		carrier = stageYou(r),
		tackler = stageYou(r),
		cat = stageCat(r, Intro.DEMO_CAT, CFrame.new(scene.walkFrom)),
		holder = nil,
		catch = nil,
		swung = false,
		pinned = false,
		shot = 0,
		shotAt = os.clock(),
		cameraFrom = camera.CFrame,
		knocked = false,
		cameraWas = camera.CFrame,
		cameraTypeWas = camera.CameraType,
		controls = controls(),
		promptsWere = ProximityPromptService.Enabled,
		character = character,
	}
	if l.cat ~= nil then
		-- held, it is the carrier's, not the stage's: lessonEnd destroys it on its own
		local index = table.find(r.staged, l.cat)
		if index ~= nil then
			table.remove(r.staged, index)
		end
		(l.cat :: Model).Name = "HeldCat"
	end
	local tackler = l.tackler
	if tackler ~= nil then
		tackler.model.Name = "LessonTackler"
		tackler.model:SetAttribute("StagedTackle", true)
	end
	if l.carrier ~= nil then
		(l.carrier :: You).model.Name = "LessonCarrier"
	end
	if l.controls ~= nil then
		pcall(function()
			l.controls:Disable()
		end)
	end
	ProximityPromptService.Enabled = false
	lesson = l
	RunService:BindToRenderStep(LESSON_STEP, Enum.RenderPriority.Camera.Value + 2, lessonStep)
	return l
end

-- Stages shot `shot` (1 to TackleStage.SHOTS) of the tackling lesson, starting it on the first call; 0 or nil ends
-- it and puts everything back. Does nothing while the intro plays.
local lessonReported = false -- #2391: tackle_lesson_shown goes out once a session

function IntroController.stageTackle(shot: number?)
	if shot == nil or shot <= 0 or shot > TackleStage.SHOTS then
		lessonEnd()
		return
	end
	if shot == 1 and not lessonReported then
		-- #2391: the funnel's tackle_lesson_shown (Onboarding.REPORTABLE), as the lesson's first shot is staged
		lessonReported = true
		Net.fire("TelemetryReport", "step", "tackle_lesson_shown")
	end
	local l = lesson or lessonBegin()
	if l == nil then
		return
	end
	local camera = Workspace.CurrentCamera
	l.shot = shot
	l.shotAt = os.clock()
	l.cameraFrom = if camera ~= nil then camera.CFrame else l.cameraFrom
	local tackler = l.tackler
	if shot <= 3 then
		-- the walk again, the cat back in the carrier's arms and the tackler back on its spot
		l.knocked = false
		if tackler ~= nil and tackler.model.Parent == nil then
			tackler.model.Parent = Workspace
		end
		lessonHold(l, l.carrier)
		if tackler ~= nil then
			tackler.model:SetAttribute("TackleAt", nil)
			tackler.model:SetAttribute("TackleMissAt", nil)
		end
	end
	if (shot == 2 or shot == 3) and tackler ~= nil then
		-- the dive (Effects/Tackle, StagedTackle) from LUNGE_AT; in shot 3 it is you, over your shoulder (#2469)
		local model = tackler.model
		task.delay(TackleStage.LUNGE_AT, function()
			if lesson == l and l.shot == shot and model.Parent ~= nil then
				model:SetAttribute("TackleAt", Workspace:GetServerTimeNow())
			end
		end)
	elseif shot == 4 then
		-- shot 3 played out, even when Next cut it short: the carrier knocked; the tackler and the cat it took leave
		-- the stage (#2495), so only the catcher and its new cat are in the shot
		l.knocked = true
		local cat = l.cat
		if cat ~= nil then
			lessonDrop(l, l.scene.drop)
			cat.Parent = nil -- lessonEnd destroys it
		end
		if tackler ~= nil then
			tackler.model.Parent = nil
		end
		local carrier = l.carrier
		if carrier ~= nil and l.catch == nil then
			carrier.model:SetAttribute(NO_NET, nil) -- its net up for the swing (#2469)
			local at = l.scene.catchAt
			local cat = stageCat(l.r, Intro.DEMO_CAT, CFrame.lookAt(at, at + l.scene.right))
			if cat ~= nil then
				cat.Name = "LessonStray"
				CollectionService:AddTag(cat, TackleStage.STRAY_TAG)
				l.catch = cat
			end
		end
	end
end

-- #2495: whether this play ends with the tackling lesson's steps: every play, first or replay (#2522), once the
-- screen can show its dots. #2626 (Derek2: "make tackle lesson removed from tutorial for now so less people leave"):
-- off for now; UI plays the lesson the first time the player is back on the safe street after being tackled.
local TAIL_ON = false
local function tailWanted(): boolean
	if not TAIL_ON then
		return false
	end
	local most = Tail.IntroLogic.MAX_SHOTS
	return type(most) == "number" and most >= Intro.SHOTS + TackleStage.SHOTS
end

-- Ends the lesson's steps and the screen; `played` saves the lesson as seen.
Tail.stop = function(played: boolean)
	if Tail.shown == 0 then
		return
	end
	Tail.shown = 0
	UI.intro.tackleCue(nil)
	IntroController.stageTackle(0)
	if UI.intro.playing() then
		UI.intro.finish()
	end
	if played and Tail.save then
		Net.fire("TipSeen", Tail.Logic.TIP, false)
	end
	Moments.IntroEnd:Fire()
end

-- Step `index` of the lesson (TackleLesson.play's captions and holds), past the last one the end.
Tail.show = function(index: number)
	local stop = Tail.stop :: (boolean) -> ()
	if index > #Tail.lines then
		stop(true)
		return
	end
	if index > 1 and (Tail.shown ~= index - 1 or not UI.intro.playing()) then
		stop(false) -- a stale timer, or the screen ended some other way
		return
	end
	Tail.shown = index
	IntroController.stageTackle(index)
	if not IntroController.stagingTackle() then
		stop(false) -- nowhere to stage it (no character): the first check-in plays it instead
		return
	end
	local caption = Tail.lines[index]
	local hold = Tail.Logic.hold(caption)
	local screen: any = UI.intro
	screen.setShot(Intro.SHOTS + index, caption, nil, hold)
	UI.intro.tackleCue(
		if index == Tail.Logic.CUE_SHOT then Tail.Logic.cueKey(Tail.device) else nil,
		TackleStage.LUNGE_AT
	)
	task.delay(hold, function()
		if Tail.shown == index then
			(Tail.show :: (number) -> ())(index + 1)
		end
	end)
end

-- Whether the tackling lesson's stage is up.
function IntroController.stagingTackle(): boolean
	return lesson ~= nil
end

-- #2759: hold the camera still on `at` until unpark() or a run takes it.
local function park(at: Intro.Key)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	parked = true
	parkedAt = at
	camera.CameraType = Enum.CameraType.Scriptable
	setCamera(at)
	-- a spawn resets the camera to follow the character (Laptop-Tester: 5 s behind the cannon before the intro), so
	-- the park holds it each frame until unpark() or a run
	if not parkBound then
		parkBound = true
		RunService:BindToRenderStep(PARK_STEP, Enum.RenderPriority.Camera.Value + 1, function()
			local held = Workspace.CurrentCamera
			if not parked or held == nil then
				return
			end
			if held.CameraType ~= Enum.CameraType.Scriptable then
				held.CameraType = Enum.CameraType.Scriptable
			end
			setCamera(parkedAt)
		end)
	end
end

local function unbindPark()
	if parkBound then
		parkBound = false
		RunService:UnbindFromRenderStep(PARK_STEP)
	end
end

-- Hands a parked camera back to the character, once there is one and no intro has it.
local function unpark()
	local character = player.Character
	if not parked or run ~= nil or starting or character == nil then
		return
	end
	parked = false
	unbindPark()
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	camera.CameraType = Enum.CameraType.Custom
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid?
	if humanoid ~= nil then
		camera.CameraSubject = humanoid
	end
end

-- Plays the intro from the first shot. `replay` is a replay from the Tutorial tile or Settings: Skip shows at once
-- and the server saves nothing. Does nothing while one is playing or without a plot. Yields up to STREAM_WAIT while
-- the Alleyway's camp streams in.
function IntroController.play(replay: boolean)
	local state = UIController.state
	if run ~= nil or starting or state == nil or state.plotIndex == 0 then
		unpark()
		return
	end
	starting = true
	local camp = Intro.camp(Intro.AREA) :: Intro.Camp
	-- #2759: shot 1's first frame while the camp streams in, not the inside of the cannon
	local cameraWas = if Workspace.CurrentCamera ~= nil
		then (Workspace.CurrentCamera :: Camera).CameraType
		else Enum.CameraType.Custom
	local first = Intro.shots(Intro.plot(state.plotIndex), hasCodesCat(), false)[1]
	if first ~= nil and first.cuts[1] ~= nil then
		park(first.cuts[1].from)
	end
	-- with streaming on the camps are far from the spawn this client holds: ask for the Alleyway's pad and wait
	streamCamp() -- #2961: the area's middle too, where its big ground and set parts stand
	pcall(function()
		player:RequestStreamAroundAsync(camp.pad, Intro.STREAM_WAIT)
	end)
	-- #2961: the ground under the filmed spots can come after the pad; up to CAMP_WAIT more for it, still parked
	local waitUntil = os.clock() + Intro.CAMP_WAIT
	while not campReady() and os.clock() < waitUntil do
		task.wait(CAMP_POLL)
	end
	starting = false
	state = UIController.state
	if run ~= nil or state == nil or state.plotIndex == 0 then
		unpark()
		return
	end
	-- the Alleyway's board streams in during shots 1 to 4 (#1542: the other camps are no longer filmed)
	streamAround(camp.board)
	local alleyStreamed = streamedNear(camp.pad) and campReady()
	local plot = Intro.plot(state.plotIndex)
	local camera = Workspace.CurrentCamera
	local r: Run = {
		replay = replay,
		shotStarted = os.clock(),
		shots = Intro.shots(plot, hasCodesCat(), alleyStreamed),
		plot = plot,
		camp = camp,
		alleyStreamed = alleyStreamed,
		shot = 0,
		cuts = {},
		cut = 1,
		jumpFired = 0,
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
		rich = nil,
		wheel = nil,
		done = {},
		campHeld = 0,
		controls = controls(),
		promptsWere = ProximityPromptService.Enabled,
		cameraType = cameraWas, -- from before the park; finish() turns Scriptable into Custom
		ended = false,
		tail = tailWanted(),
	}
	run = r
	parked = false -- the run has the camera now; finish() hands it back as Custom
	unbindPark()
	-- #2961: keep asking for the camp's ground until the cut to shot 5, so it streams in late on a slow phone (the
	-- fuse looks again) and nothing streams back out under the camp shots
	task.spawn(function()
		while run == r and not r.ended and not r.done.sceneOver do
			streamCamp()
			task.wait(CAMP_ASK_EVERY)
		end
	end)

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

	UI.intro.start({
		skipAfter = if replay then 0 else Intro.SKIP_AFTER,
		replay = replay,
		shots = if r.tail then Intro.SHOTS + TackleStage.SHOTS else nil, -- #2495: the lesson's steps last
	})
	Moments.IntroStart:Fire(replay)
	-- at Camera priority, under Effects/Cannon's BOOM shake at Camera + 1
	RunService:BindToRenderStep(RENDER_STEP, Enum.RenderPriority.Camera.Value, step)
end

function IntroController.playing(): boolean
	return run ~= nil
end

function IntroController.start()
	-- #2759: hold on the town square until the first spawn, or the intro if this sync starts one
	if player.Character == nil then
		park(LOADING_VIEW)
		task.delay(PARK_GIVE_UP, function()
			gaveUp = true
			if parked and run == nil and not starting then
				unpark()
			end
		end)
	end
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
		if not synced then
			synced = true
			if not firstStarted then
				unpark() -- no intro: the spawn's own view, if it has come
			end
		end
	end)
	UI.events.introSkip:Connect(function()
		if Tail.shown > 0 then
			(Tail.stop :: (boolean) -> ())(false) -- #2495: Skip on the lesson's steps
			return
		end
		finish(false) -- the UI sends the shot; this side knows it already
	end)
	-- #2182: UI-Engineer's Next (the pill, a tap, Space, Enter or gamepad A), once the UI has it
	local introNext = (UI.events :: any).introNext
	if introNext ~= nil then
		introNext:Connect(nextShot)
	end
	UI.events.introReplay:Connect(function()
		local state = UIController.state
		if state ~= nil and state.carrying == nil then
			IntroController.play(true)
		end
	end)
	-- #2312: UI's tackling lesson stages its shots here, once UI-Engineer's hook is in (UI can't require controllers)
	local setStager: any = (UI.intro :: any).setTackleStager
	if type(setStager) == "function" then
		(setStager :: any)(IntroController.stageTackle)
	end
	player.CharacterAdded:Connect(function(character)
		if parked and run == nil and not starting and (synced or gaveUp) then
			task.defer(unpark) -- #2759: the first spawn, and no intro has the camera (a play that gave up included)
		end
		if Tail.shown > 0 and lesson ~= nil and lesson.character ~= character then
			(Tail.stop :: (boolean) -> ())(false) -- #2495: a respawn ends the lesson's steps
		end
		if lesson ~= nil and lesson.character ~= character then
			lessonEnd() -- a respawn ends the lesson's stage
		end
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
