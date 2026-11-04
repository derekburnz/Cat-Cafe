--!strict
-- The Cat Cannon flight on every character this client can see (F84, hometown-cannon.md section 3b): the hop into
-- the barrel, the ball rolling once out of it and opening into a superhero soar along a long climb that bends towards
-- the landing pad, gone into the clouds, then back from the sky behind the pad, feet first along a curve, and a hero
-- landing on one knee (Avatar.flight, Presets.cannonPose). The engineer's server holds the character's root anchored
-- at the barrel's seat and later on the pad, and sets `Launching`, `CannonLaunchAt` (server time) and
-- `CannonHeading` (the flat way to the pad) on the character; the body moves away from that root through the Root
-- joint, so every client draws every flight
-- itself and nothing replicates. The hop starts from where the root last stood before the launch, as this client
-- saw it. Tackle.luau asks for the frames each step and lays them over everything else, at any distance, since a
-- flight is rare and seen across the town. A launch the server calls off before the drop (`Launching` cleared) lets
-- go at once; one it clears at the end of the flight still lands. `CannonGlide.body` says where the body is, for
-- VFX-Agent's sparkle trail and sky puff.
-- The cloud cutscene (Derek 2026-10-28 13:56: "make the cloud cutscene a little better"): while the clouds cover the
-- launching player's screen, their own character flies through them (Avatar.glide, Presets.cannonGlide), a copy of
-- it posed in a ViewportFrame that VFX-Agent's cloud tunnel lays between its clouds (`CannonGlide.mount`).
-- The launching player's camera (section 7): it follows the hop, chases the flyer out of the barrel, waits under the
-- clouds, follows it down onto the pad from further out than the player's own view and settles in to that view,
-- then hands back to the game's camera at the end of the flight (Presets.cannonCamera). Everyone else keeps their own
-- camera.
-- Listening only: nothing here fires a remote.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Avatar = require(script.Parent.Avatar)
local Presets = require(script.Parent.Presets)

local CannonGlide = {}

type Flight = {
	root: BasePart,
	free: CFrame?, -- where the root stood last frame while not launching, in the world
	launchAt: number?, -- the CannonLaunchAt being drawn
	from: CFrame?, -- where the root stood just before that launch, in the world
	done: number?, -- a CannonLaunchAt already drawn to its end, so a late clear does not play it again
	centre: CFrame?, -- the body's middle this frame in the root's frame, nil while hidden or not flying
}

local flights: { [Model]: Flight } = {}
local started = false

local function smooth(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

-- The flight's joint Transforms for `character` at `now` (server time) and how much of them shows; nil while it is
-- not flying.
function CannonGlide.frames(
	character: Model,
	rig: Avatar.Rig,
	now: number
): ({ [Avatar.Joint]: CFrame }?, number)
	local f: Flight = flights[character]
		or { root = rig.root, free = nil, launchAt = nil, from = nil, done = nil, centre = nil }
	flights[character] = f
	f.root = rig.root
	f.centre = nil
	local c = Presets.cannonPose
	local root = rig.root.CFrame
	local at = character:GetAttribute("CannonLaunchAt")
	local launching = character:GetAttribute("Launching") == true and type(at) == "number"
	if launching and at ~= f.launchAt and at ~= f.done then
		f.launchAt, f.from = at :: number, f.free
	elseif not launching and f.launchAt ~= nil and now < f.launchAt + c.drop then
		f.launchAt, f.from = nil, nil -- called off
	end
	local launchAt = f.launchAt
	if launchAt == nil then
		if not launching then
			f.free = root
		end
		return nil, 0
	end
	local from = if f.from ~= nil then root:Inverse() * f.from else nil
	local heading = character:GetAttribute("CannonHeading")
	local frames, weight, centre = Avatar.cannon(
		rig,
		now - launchAt,
		from,
		if typeof(heading) == "Vector3" then root:VectorToObjectSpace(heading) else nil
	)
	if frames == nil then
		f.done, f.launchAt, f.from = launchAt, nil, nil
	end
	f.centre = centre
	return frames, weight
end

-- A staged copy's flight (the intro's copy of you, tagged StagedCharacter): the pose alone, since the intro moves and
-- spins the copy's root itself. The intro sets `StagedFlight` to "hop" with `StagedFlightAt` the server time the hop
-- into the barrel starts, to "ball" at the BOOM, and to "land" with `StagedFlightAt` the server time its feet touch the
-- pad (Avatar.stagedCannon). Nil and 0 without one.
function CannonGlide.staged(
	model: Model,
	rig: Avatar.Rig,
	now: number
): ({ [Avatar.Joint]: CFrame }?, number)
	local phase = model:GetAttribute("StagedFlight")
	if type(phase) ~= "string" then
		return nil, 0
	end
	local at = model:GetAttribute("StagedFlightAt")
	return Avatar.stagedCannon(rig, phase, if type(at) == "number" then now - at else 0)
end

-- Where `character`'s body is mid flight, in the world: its middle, turned as it rolls. Nil while it is not flying
-- or waits out of sight above the clouds.
function CannonGlide.body(character: Model): CFrame?
	local f = flights[character]
	local centre = if f ~= nil then f.centre else nil
	if f == nil or centre == nil then
		return nil
	end
	return f.root.CFrame * centre
end

-- Lets go of a character that left or was rebuilt.
function CannonGlide.forget(character: Model)
	flights[character] = nil
end

-- A copy of `character` that nothing simulates: no scripts, sounds or labels, every joint off and every part
-- anchored, so each part goes exactly where it is put.
local function copy(character: Model): Model?
	local archivable = character.Archivable
	character.Archivable = true -- a player's character does not clone otherwise
	local clone = character:Clone() :: Model?
	character.Archivable = archivable
	if clone == nil then
		return nil
	end
	for _, d in clone:GetDescendants() do
		if
			d:IsA("LuaSourceContainer")
			or d:IsA("Sound")
			or d:IsA("BillboardGui")
			or d:IsA("ForceField")
			or d:IsA("Highlight")
		then
			d:Destroy()
		end
	end
	local humanoid = clone:FindFirstChildOfClass("Humanoid") :: Humanoid?
	if humanoid ~= nil then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	return clone
end

-- What each part of the copy that is not one of the rig's own (hats, hair, a tool) is fastened to, and where on it:
-- followed through welds, weld constraints and rigid constraints from the rig's parts outwards.
local function fastened(
	clone: Model,
	rig: Avatar.Rig
): { { part: BasePart, to: BasePart, offset: CFrame } }
	local placed: { [BasePart]: boolean } = { [rig.root] = true }
	for _, link in rig.links do
		placed[link.part] = true
	end
	local joined: { { BasePart } } = {}
	for _, d in clone:GetDescendants() do
		local a: Instance?, b: Instance? = nil, nil
		if d:IsA("JointInstance") then
			a, b = (d :: JointInstance).Part0, (d :: JointInstance).Part1
		elseif d:IsA("WeldConstraint") then
			a, b = (d :: WeldConstraint).Part0, (d :: WeldConstraint).Part1
		elseif d:IsA("RigidConstraint") then
			local c = d :: RigidConstraint
			a = if c.Attachment0 ~= nil then c.Attachment0.Parent else nil
			b = if c.Attachment1 ~= nil then c.Attachment1.Parent else nil
		end
		if a ~= nil and b ~= nil and a:IsA("BasePart") and b:IsA("BasePart") then
			table.insert(joined, { a :: BasePart, b :: BasePart })
		end
	end
	local out = {}
	local grew = true
	while grew do
		grew = false
		for _, pair in joined do
			local to, part = pair[1], pair[2]
			if placed[part] and not placed[to] then
				to, part = part, to
			elseif not placed[to] or placed[part] then
				continue
			end
			placed[part] = true
			grew = true
			table.insert(out, { part = part, to = to, offset = to.CFrame:Inverse() * part.CFrame })
		end
	end
	return out
end

-- A copy of `character` flying in a full-size, see-through ViewportFrame laid into `parent` at `zIndex`, posed each
-- frame by `seconds()` (the flight's seconds from CannonLaunchAt) and `span` (Avatar.glide's), which takes itself
-- away once it has dived out. Nothing when the character cannot be copied.
local function fly(
	parent: GuiObject,
	zIndex: number,
	character: Model,
	seconds: () -> number,
	span: number?
)
	local clone = copy(character)
	local rig = if clone ~= nil then Avatar.bind(clone) else nil
	if clone == nil or rig == nil then
		return
	end
	local extras = fastened(clone, rig)
	for _, d in clone:GetDescendants() do
		if d:IsA("BasePart") then
			(d :: BasePart).Anchored = true
		elseif d:IsA("JointInstance") then
			(d :: JointInstance).Enabled = false
		elseif d:IsA("Constraint") then
			(d :: Constraint).Enabled = false
		elseif d:IsA("WeldConstraint") then
			(d :: WeldConstraint).Enabled = false
		end
	end

	local g = Presets.cannonGlide
	local frame = Instance.new("ViewportFrame")
	frame.Name = "CannonGlide"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = zIndex
	frame.Ambient = Color3.fromRGB(190, 185, 180)
	frame.LightColor = Color3.fromRGB(255, 248, 235)
	frame.LightDirection = Vector3.new(-1, -1.5, -1)
	local camera = Instance.new("Camera")
	camera.FieldOfView = g.fov
	camera.CFrame = CFrame.lookAt(g.camera, g.look)
	camera.Parent = frame
	frame.CurrentCamera = camera
	clone.Parent = frame
	frame.Parent = parent

	local connection: RBXScriptConnection? = nil
	local function step()
		local transforms = Avatar.glideFrames(rig, seconds(), span)
		if transforms == nil or frame.Parent == nil then
			if connection ~= nil then
				connection:Disconnect()
			end
			frame:Destroy()
			return
		end
		local at = Avatar.partFrames(rig, transforms, CFrame.identity)
		for part, cf in at do
			part.CFrame = cf
		end
		for _, extra in extras do
			local base = at[extra.to] or extra.to.CFrame
			at[extra.part] = base * extra.offset
			extra.part.CFrame = at[extra.part]
		end
	end
	step()
	connection = RunService.RenderStepped:Connect(step)
end

-- Lays the cloud cutscene's flyer into `parent` (VFX-Agent's tunnel, at `zIndex` between its clouds): a copy of
-- `character` rising into view from cannonPose's `gone` after `launchAt` and diving out at its `drop`.
function CannonGlide.mount(parent: GuiObject, zIndex: number, character: Model, launchAt: number)
	fly(parent, zIndex, character, function()
		return Workspace:GetServerTimeNow() - launchAt
	end)
end

-- The same flyer on a staged timeline (the intro's shot 2, Cannon.playStaged): a copy of `model` rising into view at
-- server time `from` and diving out `seconds` later, the rise, opening and dive squeezed to fit (Avatar.glide).
function CannonGlide.mountStaged(
	rider: GuiObject,
	zIndex: number,
	model: Model,
	from: number,
	seconds: number
)
	local gone = Presets.cannonPose.gone
	fly(rider, zIndex, model, function()
		return gone + Workspace:GetServerTimeNow() - from
	end, seconds)
end

-- The launching player's view, from the frame its flight began.
type View = {
	launchAt: number,
	offset: Vector3, -- the camera from the body, as the player had it
	look: Vector3,
	focus: Vector3, -- the camera's focus from the root, as the player had it
	distance: number, -- and how far the camera was from it
	pitch: number, -- radians, negative looking down
	body: Vector3, -- the body's middle when last seen
	last: CFrame,
}
local view: View? = nil

-- The camera for this player's own flight, after the game's camera has had its turn each frame.
local function track()
	local camera = Workspace.CurrentCamera
	local me = Players.LocalPlayer.Character
	local f = if me ~= nil then flights[me] else nil
	local launchAt = if f ~= nil then f.launchAt else nil
	if camera == nil or me == nil or f == nil or launchAt == nil then
		if view ~= nil and camera ~= nil then
			camera.CameraType = Enum.CameraType.Custom -- the game's camera again, from where this left it
		end
		view = nil
		return
	end
	local c, k = Presets.cannonPose, Presets.cannonCamera
	local seconds = Workspace:GetServerTimeNow() - launchAt
	local root = f.root.CFrame
	local body = CannonGlide.body(me)
	local current: View? = view
	if current == nil or current.launchAt ~= launchAt then
		local at = if body ~= nil then body.Position else root.Position
		local stood = if f.from ~= nil then f.from.Position else root.Position
		local focus = camera.Focus.Position
		current = {
			launchAt = launchAt,
			offset = camera.CFrame.Position - at,
			look = camera.CFrame.LookVector,
			focus = focus - stood,
			distance = math.max((camera.CFrame.Position - focus).Magnitude, 4),
			pitch = math.asin(math.clamp(camera.CFrame.LookVector.Y, -1, 1)),
			body = at,
			last = camera.CFrame,
		}
		camera.CameraType = Enum.CameraType.Scriptable
	end
	local v = current :: View
	view = v
	local before = v.body
	if body ~= nil then
		v.body = body.Position
	end

	local tilt = math.rad(c.tilt)
	local barrel = root.LookVector * math.cos(tilt) + root.UpVector * math.sin(tilt)
	local launch = CFrame.lookAt(root:PointToWorldSpace(k.launch), root.Position + barrel * k.ahead)
	local target: CFrame
	if seconds < c.boom then
		-- from the player's own view, carried along with the hop, round to behind the cannon
		local own = v.body + v.offset
		target = CFrame.lookAt(own, own + v.look):Lerp(launch, smooth(seconds / c.boom))
	elseif seconds < c.gone then
		-- after the flyer from behind and to its right, level with the way it goes over the ground, so it shows side on
		local moved = v.body - before
		local flat = Vector3.new(moved.X, 0, moved.Z)
		local heading = if flat.Magnitude > 1e-3
			then flat.Unit
			else Vector3.new(barrel.X, 0, barrel.Z).Unit
		local chase = CFrame.lookAt(v.body, v.body + heading):PointToWorldSpace(k.chase)
		target = launch:Lerp(CFrame.lookAt(chase, v.body), smooth((seconds - c.boom) / k.catch))
	elseif seconds < c.drop - k.over then
		target = v.last -- under the clouds
	else
		-- behind the flyer as it comes down onto the pad, as the player had the camera but `wide` times as far, closing
		-- in to `land` times as far by the touch
		local fall = smooth((seconds - c.drop) / (c.touch - c.drop))
		local rest = root.Position + v.focus
		local coming = if body ~= nil
			then v.body
			else root:PointToWorldSpace(Vector3.new(0, c.height, c.back)) -- where it comes back into sight
		local focus = if seconds < c.touch
			then coming:Lerp(rest, smooth((seconds - (c.touch - c.open)) / c.open))
			else rest
		local look = root.LookVector * math.cos(v.pitch) + Vector3.yAxis * math.sin(v.pitch)
		-- `wide` times the player's distance down to `land` times it at the touch, then a slow settle onto the
		-- player's own distance by the hand back at `ends` (#1081: the close-in read as too much zoom)
		local settle = smooth((seconds - c.touch) / (c.ends - c.touch))
		local scale = if seconds < c.touch
			then k.land + (k.wide - k.land) * (1 - fall)
			else 1 + (k.land - 1) * (1 - settle)
		local distance = v.distance * scale
		target = CFrame.lookAt(focus - look * distance, focus)
	end
	v.last = target
	camera.CFrame = target
end

-- Starts the launching player's camera; Tackle.luau starts it with the rest. It runs at the game camera's own
-- priority (which leaves a Scriptable camera alone), so Cannon.luau's boom shake (Context.shake, one step later, off
-- with Screen shake or Reduced Motion) lands on top of it.
function CannonGlide.start()
	if started then
		return
	end
	started = true
	RunService:BindToRenderStep("CannonCamera", Enum.RenderPriority.Camera.Value, track)
end

return CannonGlide
