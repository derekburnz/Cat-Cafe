--!strict
-- The store page video's takes, client side (Animation-Engineer, 2026-11-03; storyboard
-- /mnt/project-files/Animation-Engineer/trailer/storyboard.md). Only in the trailer place
-- (assets/cat-cafe/anim/trailer/trailer.project.json), only in a Studio playtest. Once TrailerDirector.server.luau
-- has staged the scene, a take starts by itself after TrailerConfig.timing.autoStart seconds, or at once with T in
-- the game view; R stops it and has the scene staged again.
--
-- A take, with the game's own systems doing the work:
--   establish  a high wide shot down the Alleyway that sinks toward Rocker Cat
--   approach   the player runs down the lane to the cat (Humanoid:MoveTo; the player's own controls are off)
--   swing      the real net smack (Moments.NetSmackPress and SwingNet, as the Net button sends), then each catch
--              circle pressed at its exact time (CatchPress), so the catch succeeds; the edit cuts the circles out
--   caught     the player shows the cat in the carry, then turns for home
--   run1..3    the run home at the catch's getaway speed, with one shover diving at it each time and missing as it
--              cuts away: local copies of the server's catalog-outfit characters, tagged StagedCharacter with
--              StagedTackle, so the Effects draw their nets and the Tackle's own dive, belly slide and get up
--   home       under the arch into the camp, where the game checks the cat in by itself
--   cafe       the server sends the player home; a push in on Rocker Cat at work at its Entertainer station
--   end        the shot held for the logo
-- Each shot's start is printed to the Output, timed from the take's start, for the edit. Every screen of the game
-- but the toasts is hidden, and the Roblox menus and the mouse pointer too.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

if not RunService:IsStudio() then
	return
end

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local TrailerConfig = require(ReplicatedStorage:WaitForChild("TrailerConfig"))
local Client = script.Parent:WaitForChild("Client")
local Moments = require(Client:WaitForChild("Moments"))
local Net = require(Client:WaitForChild("Net"))

local LOG = "[Trailer]"
local STAGED = "StagedCharacter"
local RENDER_STEP = "CatCafeTrailer"
local UP = Vector3.new(0, 1, 0)
local RUN_ANIM_SPEED = 14.5 -- the R6 Animate script's run plays at speed / 14.5
local DEFAULT_ANIMATIONS =
	{ -- Roblox's R6 run and idle, for a character whose Animate script has none
		run = "rbxassetid://180426354",
		idle = "rbxassetid://180435571",
	}

local player = Players.LocalPlayer
local folder = ReplicatedStorage:WaitForChild("Trailer")
local cue = folder:WaitForChild("Cue") :: RemoteEvent
local cast = folder:WaitForChild("Cast")

-- The Alleyway's frame from the server: the name arch's line, the way in (depth) and a home runner's right (across).
local function vector(name: string): Vector3
	local value = folder:GetAttribute(name)
	return if typeof(value) == "Vector3" then value else Vector3.zero
end
local gate, inward, right, pad = vector("Gate"), vector("Inward"), vector("Right"), vector("Pad")
local floorY = (folder:GetAttribute("FloorY") :: number?) or gate.Y

local function lanePoint(depth: number, across: number): Vector3
	return gate + inward * depth + right * across
end

local function depthOf(position: Vector3): number
	return (position - gate):Dot(inward)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function flatUnit(v: Vector3, fallback: Vector3): Vector3
	local f = flat(v)
	return if f.Magnitude > 1e-4 then f.Unit else fallback
end

local function ease(k: number): number
	local t = math.clamp(k, 0, 1)
	return t * t * (3 - 2 * t)
end

-- The player's character ----------------------------------------------------------------------------------------

type Hero = { character: Model, humanoid: Humanoid, root: BasePart }

local function hero(): Hero?
	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if character == nil or humanoid == nil or root == nil or not root:IsA("BasePart") then
		return nil
	end
	return { character = character, humanoid = humanoid, root = root }
end

local function heroSpeed(h: Hero): number
	return flat(h.root.AssemblyLinearVelocity).Magnitude
end

-- The player's own controls off, so nothing but the take moves the character.
local function controlsOff()
	local scripts = player:WaitForChild("PlayerScripts")
	local module = scripts:FindFirstChild("PlayerModule")
	if module ~= nil and module:IsA("ModuleScript") then
		pcall(function()
			(require(module) :: any):GetControls():Disable()
		end)
	end
end

-- Turns the character to face `toward` (flat) at once; the client owns its character, so this replicates.
local function face(h: Hero, toward: Vector3)
	local at = h.root.Position
	local look = flatUnit(toward - at, h.root.CFrame.LookVector)
	h.root.CFrame = CFrame.lookAt(at, at + look)
end

-- The AnimationId the character's Animate script plays for `state`, or Roblox's R6 one.
local function animationId(character: Model?, state: string, name: string, fallback: string): string
	local animate = if character ~= nil then character:FindFirstChild("Animate") else nil
	local value = if animate ~= nil then animate:FindFirstChild(state) else nil
	local animation = if value ~= nil then value:FindFirstChild(name) else nil
	if animation ~= nil and animation:IsA("Animation") and animation.AnimationId ~= "" then
		return animation.AnimationId
	end
	return fallback
end

-- Screens --------------------------------------------------------------------------------------------------------

local function hideScreens()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	end)
	pcall(function()
		StarterGui:SetCore("TopbarEnabled", false)
	end)
	UserInputService.MouseIconEnabled = false
	local gui = player:FindFirstChildOfClass("PlayerGui")
	if gui == nil then
		return
	end
	for _, child in gui:GetChildren() do
		if child:IsA("ScreenGui") and not TrailerConfig.keepGuis[child.Name] then
			child.Enabled = false
		end
	end
end

-- The shovers ----------------------------------------------------------------------------------------------------

type ActorState = "wait" | "charge" | "dive" | "slide" | "down"

type Actor = {
	spec: TrailerConfig.Shover,
	model: Model,
	root: BasePart,
	height: number, -- the root's height over the floor
	tracks: { [string]: AnimationTrack },
	playing: string?,
	state: ActorState,
	start: Vector3, -- where it waits, on the floor
	line: number, -- the runner's across before its cut for this dodge
	cut: number,
	clock: number, -- os.clock() its current state began
	from: Vector3, -- where its lunge or slide began, on the floor
	dir: Vector3, -- the way it dives
	slideSpeed: number,
}

local actors: { Actor } = {}

local function place(actor: Actor, ground: Vector3, look: Vector3)
	local at = Vector3.new(ground.X, floorY + actor.height, ground.Z)
	actor.root.CFrame = CFrame.lookAt(at, at + flatUnit(look, actor.root.CFrame.LookVector))
end

local function play(actor: Actor, name: string, speed: number?)
	local track: AnimationTrack? = actor.tracks[name]
	if actor.playing ~= name then
		local before: AnimationTrack? = if actor.playing ~= nil
			then actor.tracks[actor.playing]
			else nil
		if before ~= nil then
			before:Stop(0.15)
		end
		actor.playing = name
		if track ~= nil then
			track.Looped = true
			track:Play(0.15)
		end
	end
	if track ~= nil and speed ~= nil then
		track:AdjustSpeed(speed)
	end
end

local function clearActors()
	for _, actor in actors do
		actor.model:Destroy()
	end
	table.clear(actors)
end

-- A local copy of the server's character for shover `index`: scripts out, the root anchored and moved by CFrame, no
-- collisions and no name over its head, tagged for the Effects.
local function stageActor(
	index: number,
	spec: TrailerConfig.Shover,
	line: number,
	cut: number,
	ids: { [string]: string }
)
	local source = cast:FindFirstChild("Shover" .. index)
	if source == nil or not source:IsA("Model") then
		warn(LOG, "no character for shover", index)
		return
	end
	local model = source:Clone()
	for _, item in model:GetDescendants() do
		if item:IsA("LuaSourceContainer") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
			item.Anchored = item.Name == "HumanoidRootPart"
		end
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if root == nil or not root:IsA("BasePart") or humanoid == nil then
		model:Destroy()
		return
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	local d = TrailerConfig.dodge
	local start = if spec.side == 0
		then lanePoint(spec.depth - d.headOnStart, line - cut * 1.5)
		else lanePoint(spec.depth - 6, line + spec.side * d.sideStart)
	local actor: Actor = {
		spec = spec,
		model = model,
		root = root,
		height = root.Size.Y / 2 + 2, -- R6: the legs are 2 tall under the torso
		tracks = {},
		playing = nil,
		state = "wait",
		start = start,
		line = line,
		cut = cut,
		clock = os.clock(),
		from = start,
		dir = inward,
		slideSpeed = 0,
	}
	model:SetAttribute("NetLevel", spec.look.net)
	model:SetAttribute("StagedTackle", true)
	model:SetAttribute("TackleAt", nil)
	model:SetAttribute("TackleMissAt", nil)
	place(actor, start, lanePoint(spec.depth, line) - start)
	CollectionService:AddTag(model, STAGED)
	model.Parent = Workspace
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	for name, id in ids do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, track = pcall(function(): AnimationTrack
			return (animator :: Animator):LoadAnimation(animation)
		end)
		if ok then
			actor.tracks[name] = track
		end
	end
	play(actor, "idle")
	table.insert(actors, actor)
end

-- Where a lunge has got to, 0 to 1 of its length at `u` of its time: a beat of coil on the spot, the push off, and
-- still moving at the end (a quarter of the average speed) for the belly slide to carry on from.
local function lungeAt(u: number): number
	local k = math.clamp((u - 0.1) / 0.9, 0, 1)
	return 0.75 * (1 - (1 - k) ^ 2) + 0.25 * k
end

local function dive(actor: Actor, h: Hero)
	local lunge = Config.TackleLungeSeconds
	-- toward where the runner would be at the lunge's end had it kept to its line; it has begun its cut
	local ahead = depthOf(h.root.Position) - math.max(heroSpeed(h), 12) * lunge
	local target = lanePoint(ahead, actor.line)
	local at = flat(actor.root.Position) + Vector3.new(0, floorY, 0)
	actor.from = at
	actor.dir = flatUnit(target - at, -inward)
	actor.state = "dive"
	actor.clock = os.clock()
	actor.slideSpeed = 0.25 * Config.TackleLungeStuds / (0.9 * lunge)
	play(actor, "idle")
	local model = actor.model
	local now = Workspace:GetServerTimeNow()
	model:SetAttribute("TackleAt", now)
	model:SetAttribute("TackleMissAt", nil)
	-- the miss lands when the server would have called it: the lunge and its hit grace with nobody hit
	task.delay(lunge + Config.TackleHitGraceSeconds, function()
		if model.Parent ~= nil and model:GetAttribute("TackleAt") == now then
			model:SetAttribute("TackleMissAt", Workspace:GetServerTimeNow())
		end
	end)
end

local function stepActor(actor: Actor, h: Hero?, dt: number)
	local d = TrailerConfig.dodge
	local spec = actor.spec
	local at = flat(actor.root.Position) + Vector3.new(0, floorY, 0)
	local runner = if h ~= nil then h.root.Position else at
	local runnerDepth = depthOf(runner)
	if actor.state == "wait" then
		place(actor, at, runner - at)
		local lead = if spec.side == 0 then d.headOnChargeLead else d.chargeLead
		if h ~= nil and runnerDepth <= spec.depth + lead then
			actor.state = "charge"
			actor.clock = os.clock()
		end
	elseif actor.state == "charge" then
		-- into the spot its lunge starts from, on its own side of where the dive lands, by the time it dives
		local land = lanePoint(spec.depth - 2, actor.line)
		local from = land + flatUnit(actor.start - land, inward) * Config.TackleLungeStuds
		local toGo = flat(from - at)
		local speed = if h ~= nil then math.max(heroSpeed(h), 8) else 16
		local eta = math.max((runnerDepth - (spec.depth + d.diveLead)) / speed, 0.05)
		local pace = math.clamp(toGo.Magnitude / eta, d.chargeSpeed[1], d.chargeSpeed[2])
		local step = math.min(pace * dt, toGo.Magnitude)
		local moved = if toGo.Magnitude > 1e-3 then at + toGo.Unit * step else at
		place(actor, moved, runner - moved)
		if step > 1e-3 then
			play(actor, "run", pace / RUN_ANIM_SPEED)
		else
			play(actor, "idle")
		end
		if h ~= nil and runnerDepth <= spec.depth + d.diveLead then
			dive(actor, h)
		end
	elseif actor.state == "dive" then
		local lunge = Config.TackleLungeSeconds
		local u = (os.clock() - actor.clock) / lunge
		place(actor, actor.from + actor.dir * Config.TackleLungeStuds * lungeAt(u), actor.dir)
		if u >= 1 then
			actor.state = "slide"
			actor.clock = os.clock()
			actor.from = actor.from + actor.dir * Config.TackleLungeStuds
		end
	elseif actor.state == "slide" then
		local t = math.min(os.clock() - actor.clock, d.slideSeconds)
		local v = actor.slideSpeed
		place(actor, actor.from + actor.dir * (v * t - v / (2 * d.slideSeconds) * t * t), actor.dir)
		if t >= d.slideSeconds then
			actor.state = "down"
			actor.clock = os.clock()
		end
	elseif actor.state == "down" then
		-- the Tackle effect gets it up from its belly; once up it turns to watch the runner go
		if os.clock() - actor.clock > Config.TackleMissRecoverSeconds then
			place(actor, at, runner - at)
		end
	end
end

-- The take -------------------------------------------------------------------------------------------------------

type Waypoint = { depth: number, across: number }
type Dodge = { spec: TrailerConfig.Shover, index: number, line: number, cut: number }

-- The run home: straight at each shover's dive, the cut away, running on past it; then through the arch to the pad.
-- Each shover's line is the runner's across before its cut.
local function plan(): ({ Waypoint }, { Dodge })
	local d = TrailerConfig.dodge
	local order: { Dodge } = {}
	for index, spec in TrailerConfig.shovers do
		table.insert(order, { spec = spec, index = index, line = 0, cut = 0 })
	end
	table.sort(order, function(a, b)
		return a.spec.depth > b.spec.depth
	end)
	local points: { Waypoint } = {}
	local across = 0
	for _, item in order do
		local spec = item.spec
		local cut = spec.cut or (if spec.side == 0 then 1 else -math.sign(spec.side))
		item.line, item.cut = across, cut
		table.insert(points, { depth = spec.depth + 10, across = across })
		table.insert(
			points,
			{ depth = spec.depth - 3, across = math.clamp(across + cut * d.cutStuds, -30, 30) }
		)
		across = math.clamp(across + cut * d.settleStuds, -30, 30)
		table.insert(points, { depth = spec.depth - 14, across = across })
	end
	table.insert(points, { depth = 10, across = 0 })
	table.insert(points, { depth = depthOf(pad), across = (pad - gate):Dot(right) })
	return points, order
end

type Shot = {
	name: string,
	began: number, -- os.clock()
	track: boolean, -- a tracking shot eases after the runner; a still or scripted one is placed exactly
	frame: (dt: number) -> (CFrame?, number?),
}

local shot: Shot? = nil
local takeToken = 0
local running = false
local takeStarted = 0
local marks: { string } = {}
local heading = -inward
local camCFrame: CFrame? = nil

local function cutTo(name: string, track: boolean, frame: (dt: number) -> (CFrame?, number?))
	shot = { name = name, began = os.clock(), track = track, frame = frame }
	camCFrame = nil -- a hard cut
	local line = string.format("%6.2f  %s", os.clock() - takeStarted, name)
	table.insert(marks, line)
	print(LOG, line)
end

-- A tracking framing in the runner's own space (x right, y up, z behind), its x flipped for a cut to the left.
local function tracking(
	framing: TrailerConfig.Framing,
	flip: number
): (dt: number) -> (CFrame?, number?)
	return function(_dt: number): (CFrame?, number?)
		local h = hero()
		if h == nil then
			return nil, nil
		end
		local at = h.root.Position
		local frame = CFrame.lookAt(at, at + heading)
		local from = frame:PointToWorldSpace(
			Vector3.new(framing.from.X * flip, framing.from.Y, framing.from.Z)
		)
		local look =
			frame:PointToWorldSpace(Vector3.new(framing.at.X * flip, framing.at.Y, framing.at.Z))
		return CFrame.lookAt(from, look), framing.fov
	end
end

local function still(from: Vector3, look: Vector3, fov: number): (dt: number) -> (CFrame?, number?)
	local cframe = CFrame.lookAt(from, look)
	return function(_dt: number): (CFrame?, number?)
		return cframe, fov
	end
end

local function laneFrom(spot: { depth: number, across: number, up: number }): Vector3
	return lanePoint(spot.depth, spot.across) + UP * spot.up
end

local function alive(token: number): boolean
	return token == takeToken
end

-- Waits `seconds`, false when the take was stopped meanwhile.
local function hold(token: number, seconds: number): boolean
	local ends = os.clock() + seconds
	while os.clock() < ends do
		task.wait()
		if not alive(token) then
			return false
		end
	end
	return true
end

local function strayModel(): Model?
	local id = folder:GetAttribute("StrayId")
	for _, model in CollectionService:GetTagged("Stray") do
		if
			model:IsA("Model")
			and model:GetAttribute("StrayId") == id
			and model:IsDescendantOf(Workspace)
		then
			return model
		end
	end
	return nil
end

local function starAtWork(): Model?
	for _, model in CollectionService:GetTagged("WorkingCat") do
		if
			model:IsA("Model")
			and model:GetAttribute("OwnerUserId") == player.UserId
			and model:GetAttribute("CatId") == TrailerConfig.star
			and model:GetAttribute("SpotId") == TrailerConfig.starSpot
		then
			return model
		end
	end
	return nil
end

local function carrying(h: Hero): boolean
	return h.character:GetAttribute("CarryingCatId") ~= nil
end

-- The catch circles answered at their exact times while a take swings at its star (the edit cuts them out).
local schedule: string? = nil
local catchFailed = false
Net.on("CatchSchedule", function(strayId: unknown, circles: unknown)
	if not running or type(strayId) ~= "string" or strayId ~= folder:GetAttribute("StrayId") then
		return
	end
	if type(circles) ~= "table" then
		return
	end
	schedule = strayId
	for index, circle in circles :: { any } do
		local target = (circle.startsAt :: number) + (circle.shrinkSeconds :: number)
		task.delay(math.max(0, target - Workspace:GetServerTimeNow()), function()
			Net.fire("CatchPress", strayId, index)
		end)
	end
end)
Net.on("CatchResult", function(strayId: unknown, _grades: unknown, succeeded: unknown)
	if running and strayId == folder:GetAttribute("StrayId") and succeeded ~= true then
		catchFailed = true
	end
end)

-- Walks the player to within TrailerConfig.swingStuds of the cat, re-aiming as it wanders; false on a timeout.
local function approach(token: number, h: Hero): boolean
	local ends = os.clock() + 12
	while os.clock() < ends do
		if not alive(token) then
			return false
		end
		local cat = strayModel()
		if cat == nil then
			return false
		end
		local at = cat:GetPivot().Position
		local offset = flat(at - h.root.Position)
		if offset.Magnitude <= TrailerConfig.swingStuds + 0.5 then
			h.humanoid:MoveTo(h.root.Position)
			return true
		end
		h.humanoid:MoveTo(at - offset.Unit * TrailerConfig.swingStuds)
		task.wait(0.1)
	end
	return false
end

local function swingShot(h: Hero): (dt: number) -> (CFrame?, number?)
	local cat = strayModel()
	local catAt = if cat ~= nil
		then cat:GetPivot().Position
		else h.root.Position + h.root.CFrame.LookVector * 4
	local middle = (h.root.Position + Vector3.new(catAt.X, h.root.Position.Y, catAt.Z)) / 2
	local side = h.root.CFrame.RightVector -- the net hand's side
	local c = TrailerConfig.camera
	return still(middle + flat(side) * c.swingSide + UP * c.swingUp, middle - UP * 0.8, c.swingFov)
end

-- One take, start to end. Returns early (printing why) when it is stopped or something does not happen.
local function runTake(token: number)
	local timing = TrailerConfig.timing
	local c = TrailerConfig.camera
	local h = hero()
	if h == nil then
		warn(LOG, "no character")
		return
	end
	takeStarted = os.clock()
	table.clear(marks)
	clearActors()
	schedule, catchFailed = nil, false
	local start = lanePoint(TrailerConfig.heroDepth, TrailerConfig.heroAcross) + UP * 3
	h.root.AssemblyLinearVelocity = Vector3.zero
	h.root.CFrame = CFrame.lookAt(start, start + inward)
	h.humanoid:MoveTo(start)
	heading = inward

	-- 1: establish, the crane down the lane
	local a, b = c.establishFrom, c.establishTo
	cutTo("establish", false, function(_dt: number): (CFrame?, number?)
		local k = ease((os.clock() - (shot :: Shot).began) / timing.establish)
		local from = laneFrom(a):Lerp(laneFrom(b), k)
		local look = lanePoint(a.lookDepth, 0):Lerp(lanePoint(b.lookDepth, 0), k)
		return CFrame.lookAt(from, look), c.establishFov
	end)
	if not hold(token, timing.establish) then
		return
	end

	-- 2 and 3: approach and swing, tried again if the swing does not start a catch
	local tries = 0
	while schedule == nil do
		tries += 1
		if tries > 3 then
			warn(LOG, "the swing never started a catch; press R for another take")
			return
		end
		cutTo("approach", true, tracking(c.approach, 1))
		if not approach(token, h) then
			warn(LOG, "could not reach the cat; press R for another take")
			return
		end
		local cat = strayModel()
		if cat ~= nil then
			face(h, cat:GetPivot().Position)
		end
		cutTo("swing", false, swingShot(h))
		if not hold(token, timing.settle) then
			return
		end
		Moments.NetSmackPress:Fire()
		Net.fire("SwingNet")
		local ends = os.clock() + 1.5
		while schedule == nil and os.clock() < ends do
			if not hold(token, 0.05) then
				return
			end
		end
		if schedule == nil and not hold(token, Config.NetSwingCooldown) then
			return
		end
	end
	local ends = os.clock() + 15
	while not carrying(h) do
		if catchFailed or os.clock() > ends then
			warn(LOG, "the catch did not land; press R for another take")
			return
		end
		if not hold(token, 0.05) then
			return
		end
	end

	-- 4: caught, shown off, then the turn for home
	local points, order = plan()
	local ids = {
		run = animationId(h.character, "run", "RunAnim", DEFAULT_ANIMATIONS.run),
		idle = animationId(h.character, "idle", "Animation1", DEFAULT_ANIMATIONS.idle),
	}
	for _, item in order do
		stageActor(item.index, item.spec, item.line, item.cut, ids)
	end
	-- the turn about Y the short way round (a lerp of two opposite facings would pass through nothing)
	local fromLook = flatUnit(h.root.CFrame.LookVector, inward)
	local yawFrom = math.atan2(-fromLook.X, -fromLook.Z)
	local yawTo = math.atan2(inward.X, inward.Z) -- the yaw that faces -inward
	local turn = (yawTo - yawFrom + math.pi) % (2 * math.pi) - math.pi
	local turnStart = os.clock()
	while os.clock() - turnStart < 0.35 do
		local yaw = yawFrom + turn * ease((os.clock() - turnStart) / 0.35)
		h.root.CFrame = CFrame.new(h.root.Position) * CFrame.Angles(0, yaw, 0)
		task.wait()
		if not alive(token) then
			return
		end
	end
	face(h, h.root.Position - inward)
	heading = -inward
	cutTo("caught", false, tracking(c.caught, 1))
	if not hold(token, timing.caught) then
		return
	end

	-- 5: the run home past the three shovers, a camera for each dodge, then 6 under the arch
	local runFramings = { c.run1, c.run2, c.run3 }
	local dodge = 0
	local homeShot = false
	for index, point in points do
		local target = lanePoint(point.depth, point.across)
		local last = index == #points
		local nextMove = 0
		while true do
			if not alive(token) then
				return
			end
			local depth = depthOf(h.root.Position)
			-- which shot the runner is in: each dodge's from the last one's run on, then the arch
			if not homeShot and depth <= c.homeCut then
				homeShot = true
				cutTo("home", false, still(laneFrom(c.homeFrom), laneFrom(c.homeAt), c.homeFov))
			elseif not homeShot then
				local due = 0
				for i = 1, #order do
					if depth <= (if i == 1 then math.huge else order[i - 1].spec.depth - 14) then
						due = i
					end
				end
				if due > dodge and due <= #runFramings then
					dodge = due
					cutTo("run" .. due, true, tracking(runFramings[due], order[due].cut))
				end
			end
			if os.clock() >= nextMove then
				h.humanoid:MoveTo(target)
				nextMove = os.clock() + 1
			end
			if last then
				if flat(target - h.root.Position).Magnitude < 3 or not carrying(h) then
					break
				end
			elseif depth <= point.depth + 1.5 then
				break
			end
			task.wait()
		end
	end
	-- the camp checks the cat in by itself as the runner comes in under the arch
	local checkInBy = os.clock() + 6
	while carrying(h) do
		if os.clock() > checkInBy then
			warn(LOG, "no check-in at the camp; press R for another take")
			return
		end
		if not hold(token, 0.05) then
			return
		end
	end
	h.humanoid:MoveTo(h.root.Position)
	if not hold(token, timing.homeHold) then
		return
	end

	-- 7: the cafe, Rocker Cat at work
	cue:FireServer("home")
	local star: Model? = nil
	local findBy = os.clock() + 10
	while star == nil do
		star = starAtWork()
		if os.clock() > findBy then
			warn(LOG, "Rocker Cat is not at its station; press R for another take")
			return
		end
		if not hold(token, 0.1) then
			return
		end
	end
	if not hold(token, timing.travelWait) then
		return
	end
	local pivot = (star :: Model):GetPivot()
	local catAt = pivot.Position
	local function fromCat(offset: Vector3): Vector3
		return catAt
			+ pivot.RightVector * offset.X
			+ UP * offset.Y
			+ flat(pivot.LookVector).Unit * offset.Z
	end
	local look = catAt + UP * c.cafeAt
	cutTo("cafe", false, function(_dt: number): (CFrame?, number?)
		local k = ease((os.clock() - (shot :: Shot).began) / timing.cafe)
		return CFrame.lookAt(fromCat(c.cafeFrom):Lerp(fromCat(c.cafeTo), k), look), c.cafeFov
	end)
	if not hold(token, timing.cafe) then
		return
	end
	local endFrame = CFrame.lookAt(fromCat(c.cafeTo), look)
	cutTo("end", false, function(_dt: number): (CFrame?, number?)
		return endFrame, c.cafeFov
	end)
	if not hold(token, timing.endHold) then
		return
	end
	print(LOG, "take done; shots from its start, in seconds:\n" .. table.concat(marks, "\n"))
end

local function startTake()
	if running or folder:GetAttribute("Ready") ~= true then
		return
	end
	running = true
	takeToken += 1
	local token = takeToken
	task.spawn(function()
		runTake(token)
		if alive(token) then
			running = false
		end
	end)
end

local function stopTake()
	takeToken += 1
	running = false
	shot = nil
	clearActors()
	local camera = Workspace.CurrentCamera
	if camera ~= nil then
		camera.CameraType = Enum.CameraType.Custom
	end
	local h = hero()
	if h ~= nil then
		h.humanoid:MoveTo(h.root.Position)
	end
end

-- The game's markers and guide trail, hidden each frame (the UI turns its markers on whenever it wants them).
local function hideMarkers()
	local gui = player:FindFirstChildOfClass("PlayerGui")
	if gui ~= nil then
		for _, name in TrailerConfig.hideMarkers do
			local marker = gui:FindFirstChild(name)
			if marker ~= nil and marker:IsA("BillboardGui") then
				marker.Enabled = false
			end
		end
	end
	for _, name in TrailerConfig.hideWorld do
		local found = Workspace:FindFirstChild(name)
		if found ~= nil then
			for _, item in found:GetDescendants() do
				if item:IsA("BasePart") then
					item.LocalTransparencyModifier = 1
				end
			end
		end
	end
end

-- Every frame: the markers, the shovers, then the camera -------------------------------------------------------

local function step(dt: number)
	hideMarkers()
	local h = hero()
	if h ~= nil then
		local v = flat(h.root.AssemblyLinearVelocity)
		local want = if v.Magnitude > 2 then v.Unit else flatUnit(h.root.CFrame.LookVector, heading)
		heading = flatUnit(heading:Lerp(want, 1 - math.exp(-dt * 8)), want)
	end
	for _, actor in actors do
		stepActor(actor, h, dt)
	end
	local current = shot
	if current == nil then
		return
	end
	local camera = Workspace.CurrentCamera
	local cframe, fov = current.frame(dt)
	if camera == nil or cframe == nil then
		return
	end
	if current.track and camCFrame ~= nil then
		camCFrame = (camCFrame :: CFrame):Lerp(
			cframe,
			1 - math.exp(-dt * TrailerConfig.camera.smooth)
		)
	else
		camCFrame = cframe
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = camCFrame :: CFrame
	if fov ~= nil then
		camera.FieldOfView = fov
	end
end

RunService:BindToRenderStep(RENDER_STEP, Enum.RenderPriority.Camera.Value + 1, step)

UserInputService.InputBegan:Connect(function(input: InputObject, _processed: boolean)
	if input.KeyCode == Enum.KeyCode.T then
		startTake()
	elseif input.KeyCode == Enum.KeyCode.R then
		stopTake()
		cue:FireServer("reset")
	end
end)

-- Each staging (the first and every reset) starts its take by itself after a moment.
folder:GetAttributeChangedSignal("Take"):Connect(function()
	local take = folder:GetAttribute("Take")
	task.delay(TrailerConfig.timing.autoStart, function()
		if folder:GetAttribute("Take") == take then
			startTake()
		end
	end)
end)

controlsOff()
player.CharacterAdded:Connect(controlsOff) -- a reset's new character gets the controls back otherwise
task.spawn(function()
	while true do
		hideScreens()
		task.wait(0.5)
	end
end)
if folder:GetAttribute("Ready") == true then
	task.delay(TrailerConfig.timing.autoStart, startTake)
end
print(LOG, "camera ready: T starts a take, R stages the scene again")
