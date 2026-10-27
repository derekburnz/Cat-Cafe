--!strict
-- Moves a cat's body, head, tail and front paws on this client only. Parts are found by name (Body, Head, Tail,
-- or names ending _Body, _Head, _Tail, plus ears, eyes and legs named EarL, Eye1, LegF1 and so on, or ending so),
-- so one set of idles fits every breed. A working cat stood upright at its station (Pose "upright", F25) turns in
-- the floor's axes instead of its turned model's, and outfit parts ride what their Follows attribute names. Two
-- ways in, picked per model:
-- - Anchored parts (the placeholder cats and today's Part cats): each part is drawn at its server CFrame times a
--   small turn around its joint. The server's CFrame is read again whenever it changes, so a walking stray keeps
--   walking and only the turn is ours. A client's write to a server part stays on that client.
-- - A Motor6D rig (animation-vfx skill section 3), once the engineer builds one: the same turns go into each
--   Motor6D's Transform, which does not replicate either.
--
-- Roblox terms: a CFrame is a position plus a rotation, and `a * b` applies b inside a's frame, so
-- `J * R * J:Inverse()` turns something by R around the point and axes of J (a joint).

local Workspace = game:GetService("Workspace")

local Logic = require(script.Parent.Logic)
local Presets = require(script.Parent.Presets)

local Pose = {}

-- "body", "head", "tail", "pawFL", "pawFR", "pawBL" or "pawBR". A plain string so it can key tables.
export type Group = string

export type Rig = {
	model: Model,
	body: BasePart,
	bodyIndex: number,
	parts: { BasePart },
	groups: { Group },
	base: { CFrame }, -- the server's CFrame for each part
	written: { CFrame }, -- what this client last drew, read back, to spot the server moving a part
	joints: { [Group]: CFrame }, -- each joint in the body's own space, with the model's axes
	motors: { [Group]: Motor6D },
	usesMotors: boolean,
	lastBody: Vector3,
	jump: Vector3, -- the latest server move longer than motion.hiss.jumpStuds, and when it landed here
	jumpAt: number,
	shift: Vector3, -- a server jump still being drawn as travel during a hiss hop
	shiftFrom: number,
	jumped: boolean, -- read saw a jump that draw has not handled yet
	speed: number, -- studs a second the server is moving the cat across the ground, smoothed
	stride: number, -- leg cycles covered, counted from the distance moved
	lastAt: number,
	restDrop: number, -- studs the body drops to lie on its belly (Offsets.sink = 1); 0 for an upright cat
	moves: { [Group]: CFrame }, -- reused every frame, so a phone's garbage collector has less to do
	frames: { CFrame },
}

local LEGS: { [string]: Group } =
	{ LegF1 = "pawFL", LegF2 = "pawFR", LegB1 = "pawBL", LegB2 = "pawBR" }
local HEAD_PIECES: { [string]: boolean } = { EarL = true, EarR = true, Eye1 = true, Eye2 = true }

local function isNamed(instance: Instance, name: string): boolean
	local text = instance.Name
	return text == name or (#text > #name + 1 and text:sub(-(#name + 1)) == "_" .. name)
end

-- Pieces named for what they are, as the placeholder names them (LegF1, EarL) or as the exporter does, after
-- the object they sit in (<Cat>_LegF1, <Cat>_EarL).
local function namedLeg(part: BasePart): Group?
	for name, group in LEGS do
		if isNamed(part, name) then
			return group
		end
	end
	return nil
end

local function isHeadPiece(part: BasePart): boolean
	for name in HEAD_PIECES do
		if isNamed(part, name) then
			return true
		end
	end
	return false
end

local function findPart(model: Model, name: string): BasePart?
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and isNamed(descendant, name) then
			return descendant :: BasePart
		end
	end
	return nil
end

-- Which joint a part rides on. A `Follows` attribute ("Body", "Head" or "Tail") wins, then names, then nearness:
-- a part closer to the head than to the body, inside the head's size, belongs to the head (a points marking).
local function groupOf(part: BasePart, body: BasePart, head: BasePart?): Group
	local follows = part:GetAttribute("Follows")
	if follows == "Head" then
		return "head"
	elseif follows == "Tail" then
		return "tail"
	elseif follows == "Body" or part == body then
		return "body"
	end
	if isNamed(part, "Tail") then
		return "tail"
	end
	if isNamed(part, "Head") or isHeadPiece(part) then
		return "head"
	end
	local leg: Group? = namedLeg(part)
	if leg ~= nil then
		return leg
	end
	if head ~= nil then
		local toHead = (part.Position - head.Position).Magnitude
		if toHead < (part.Position - body.Position).Magnitude and toHead < head.Size.Magnitude then
			return "head"
		end
	end
	return "body"
end

-- A part's hinge when the asset sets one, else nil: the part's own pivot, or the pivot of the object Model it
-- sits in (the asset exporter gives each object, such as Head or Tail, a Model pivoted at its joint).
local function hingeOf(part: BasePart, model: Model): Vector3?
	if part.PivotOffset ~= CFrame.identity then
		return part:GetPivot().Position
	end
	local own: Instance = model
	local holder = part.Parent
	if holder ~= nil and holder ~= own and holder:IsA("Model") then
		return (holder :: Model):GetPivot().Position
	end
	return nil
end

-- The neck: the back of the head, low down, unless the head carries its own hinge.
local function neckOf(head: BasePart, axes: CFrame, model: Model): Vector3
	local hinge = hingeOf(head, model)
	if hinge ~= nil then
		return hinge
	end
	local size = head.Size
	return head.Position + axes:VectorToWorldSpace(Vector3.new(0, -0.3 * size.Y, 0.4 * size.Z))
end

-- The tail root: the end of the tail's long axis nearest the body.
local function tailRootOf(tail: BasePart, body: BasePart, model: Model): Vector3
	local hinge = hingeOf(tail, model)
	if hinge ~= nil then
		return hinge
	end
	local size = tail.Size
	local frame = tail.CFrame
	local axis: Vector3 = frame.RightVector * (size.X / 2)
	if size.Z >= size.X and size.Z >= size.Y then
		axis = frame.LookVector * (size.Z / 2)
	elseif size.Y >= size.X then
		axis = frame.UpVector * (size.Y / 2)
	end
	local a = tail.Position + axis
	local b = tail.Position - axis
	return if (a - body.Position).Magnitude < (b - body.Position).Magnitude then a else b
end

local function hipOf(leg: BasePart): Vector3
	return leg.Position + leg.CFrame.UpVector * (leg.Size.Y / 2)
end

-- The leg a part of the body is, or nil (Logic.legOf), worked out in the body part's own axes: a cat stood
-- upright has its whole model turned, legs and all, so the world's up says nothing about which part is a leg.
local function legOf(part: BasePart, body: BasePart): Group?
	return Logic.legOf(body.CFrame:PointToObjectSpace(part.Position), part.Size, body.Size)
end

-- The axes an upright cat's idles turn in (Pose "upright", F25: the server stands the body on its back legs by
-- turning the whole model about its X axis). Up is the world's up and right is the body's right, so a bob still
-- lifts the cat, a sway still rocks it side to side and a nod still dips its head. Nil if the model is turned
-- some other way.
local function standing(pivot: CFrame): CFrame?
	local right = pivot.RightVector
	local flat = right - Vector3.yAxis * right.Y
	if flat.Magnitude < 0.5 then
		return nil
	end
	return CFrame.fromMatrix(Vector3.zero, flat.Unit, Vector3.yAxis)
end

-- The floor under a body part: straight down from its centre by its height as it stands in the world.
local function floorUnder(body: BasePart): Vector3
	local frame = body.CFrame
	local size = body.Size
	local half = math.abs(frame.RightVector.Y) * size.X / 2
		+ math.abs(frame.UpVector.Y) * size.Y / 2
		+ math.abs(frame.LookVector.Y) * size.Z / 2
	return body.Position - Vector3.new(0, half, 0)
end

local function motorsOf(model: Model): { [Group]: Motor6D }
	local motors: { [Group]: Motor6D } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			local motor = descendant :: Motor6D
			local part1 = motor.Part1
			if part1 ~= nil then
				if isNamed(part1, "Body") then
					motors.body = motor
				elseif isNamed(part1, "Head") then
					motors.head = motor
				elseif isNamed(part1, "Tail") then
					motors.tail = motor
				end
			end
		end
	end
	return motors
end

local function newRig(model: Model, body: BasePart): Rig
	return {
		model = model,
		body = body,
		bodyIndex = 0,
		parts = {},
		groups = {},
		base = {},
		written = {},
		joints = {},
		motors = {},
		usesMotors = false,
		lastBody = body.Position,
		jump = Vector3.zero,
		jumpAt = -math.huge,
		shift = Vector3.zero,
		shiftFrom = 0,
		jumped = false,
		speed = 0,
		stride = 0,
		lastAt = os.clock(),
		restDrop = 0,
		moves = {},
		frames = {},
	}
end

-- Reads a cat model once. Nil when it has no body yet (its parts are still streaming in), or when its body is
-- welded to something that is not ours to move (the held cat rides its holder's arms); Cats tries again later.
function Pose.bind(model: Model): Rig?
	local body = model.PrimaryPart or findPart(model, "Body")
	if body == nil then
		return nil
	end
	local motors = motorsOf(model)
	if not body.Anchored then
		if next(motors) == nil then
			return nil
		end
		local rig = newRig(model, body)
		rig.motors = motors
		rig.usesMotors = true
		return rig
	end

	local rig = newRig(model, body)
	local head = findPart(model, "Head")
	local tail = findPart(model, "Tail")
	local pivot = model:GetPivot()
	local bodyFrame = body.CFrame
	local function hipY(leg: BasePart): number -- the top of a leg, up the body's own axes
		return bodyFrame:PointToObjectSpace(hipOf(leg)).Y
	end
	local legs: { [Group]: BasePart } = {} -- the highest part of each leg, whose top is the hip
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and (descendant :: BasePart).Anchored then
			local part = descendant :: BasePart
			local group = groupOf(part, body, head)
			-- An outfit piece says what it rides (Follows), so only an unmarked part of the body can be a leg.
			if group == "body" and part ~= body and part:GetAttribute("Follows") == nil then
				group = legOf(part, body) or group
			end
			table.insert(rig.parts, part)
			table.insert(rig.groups, group)
			table.insert(rig.base, part.CFrame)
			table.insert(rig.written, part.CFrame)
			if part == body then
				rig.bodyIndex = #rig.parts
			end
			if string.sub(group, 1, 3) == "paw" then
				local highest: BasePart? = legs[group]
				if highest == nil or hipY(part) > hipY(highest) then
					legs[group] = part
				end
			end
		end
	end
	if rig.bodyIndex == 0 then
		return nil
	end

	-- How far the body drops to lie down, up the body's own axes from the floor at the model pivot: the hips come
	-- down to half a leg's thickness off the floor, or with no legs found most of the gap under the body.
	local floorY = bodyFrame:PointToObjectSpace(pivot.Position).Y
	local hips, count, thickness = 0, 0, math.huge
	for _, leg in legs do
		hips += hipY(leg) - floorY
		count += 1
		thickness = math.min(thickness, leg.Size.X, leg.Size.Z)
	end
	if count > 0 then
		rig.restDrop = math.max(0, hips / count - thickness / 2)
	else
		rig.restDrop = math.max(0, (-body.Size.Y / 2 - floorY) * 0.8)
	end

	-- A cat seated at its station (Pose "sit", PR #260: the sitting body, in the floor's own axes) never lies down,
	-- so a nap style cannot sink it into the counter.
	if model:GetAttribute("Pose") == "sit" then
		rig.restDrop = 0
	end
	-- A cat stood upright turns in the floor's axes about the floor under its body, and never lies down: at night
	-- it dozes on its feet, so even a nap style cannot sink it into the counter.
	local axes = pivot.Rotation
	local floor = pivot.Position
	local upright = if model:GetAttribute("Pose") == "upright" then standing(pivot) else nil
	if upright ~= nil then
		rig.restDrop = 0
		axes = upright
		floor = floorUnder(body)
	end
	local bodyBase = bodyFrame
	local function joint(position: Vector3): CFrame
		local relative: CFrame = (bodyBase:ToObjectSpace(CFrame.new(position) * axes))
		return relative
	end
	rig.joints.body = joint(floor)
	if head ~= nil then
		rig.joints.head = joint(neckOf(head, axes, model))
	end
	if tail ~= nil then
		rig.joints.tail = joint(tailRootOf(tail, body, model))
	end
	for group, leg in legs do
		rig.joints[group] = joint(hipOf(leg))
	end
	return rig
end

-- A turn by `rotation` around one of the rig's joints, in world space; none when the cat has no such joint.
local function around(
	joints: { [Group]: CFrame },
	bodyBase: CFrame,
	group: Group,
	rotation: CFrame
): CFrame
	local joint: CFrame? = joints[group]
	if joint == nil then
		return CFrame.identity
	end
	local world = bodyBase * joint
	return world * rotation * world:Inverse()
end

local function applyMotors(rig: Rig, o: Logic.Offsets)
	local motors = rig.motors
	local body: Motor6D? = motors.body
	if body ~= nil then
		body.Transform = CFrame.new(0, o.bodyY - o.sink * rig.restDrop, 0)
			* CFrame.Angles(o.bodyPitch, 0, o.bodyRoll)
	end
	local head: Motor6D? = motors.head
	if head ~= nil then
		head.Transform = CFrame.Angles(o.headPitch, o.headYaw, o.headRoll)
	end
	local tail: Motor6D? = motors.tail
	if tail ~= nil then
		tail.Transform = CFrame.Angles(-o.tailPitch, o.tailYaw, 0)
	end
end

-- How fast the server is moving the cat and how many leg cycles that covers. A jump (a teleport) is not walking.
local function track(rig: Rig, moved: Vector3, now: number)
	local dt = now - rig.lastAt
	rig.lastAt = now
	if dt <= 0 then
		return
	end
	if moved.Magnitude > Presets.motion.hiss.jumpStuds then
		rig.jump = moved
		rig.jumpAt = now
		rig.jumped = true
		return
	end
	local ground = Vector3.new(moved.X, 0, moved.Z).Magnitude
	rig.speed += (ground / dt - rig.speed) * math.min(1, dt * 10)
	rig.stride += ground / Logic.strideLength(rig.speed)
end

-- Reads where the server has the cat this frame: re-reads any part the server moved and updates the speed and
-- stride. False once the cat has gone or lost a part (Cats then drops the rig and binds the cat afresh).
function Pose.read(rig: Rig): boolean
	if rig.model.Parent == nil or rig.body.Parent == nil then
		return false
	end
	local now = os.clock()
	if rig.usesMotors then
		local position = rig.body.Position
		track(rig, position - rig.lastBody, now)
		rig.lastBody = position
		return true
	end
	local base = rig.base
	local written = rig.written
	for i, part in rig.parts do
		if part.Parent == nil then
			return false -- a part streamed out or was removed
		end
		local frame = part.CFrame
		if frame ~= written[i] then
			base[i] = frame
		end
	end
	local position = base[rig.bodyIndex].Position
	track(rig, position - rig.lastBody, now)
	rig.lastBody = position
	return true
end

-- Draws one frame of offsets on what read found. `hopAlpha` is the hiss progress (0 to 1), or -1 when no hiss
-- plays: a server jump that lands during a hiss is drawn as the hop's travel instead of a snap.
function Pose.draw(rig: Rig, o: Logic.Offsets, hopAlpha: number)
	if rig.usesMotors then
		applyMotors(rig, o)
		return
	end
	local parts = rig.parts
	local base = rig.base
	local written = rig.written
	local bodyBase = base[rig.bodyIndex]
	local hopping = hopAlpha >= 0 and hopAlpha < 1
	if rig.jumped then
		rig.jumped = false
		if hopping then
			rig.shift = -rig.jump
			rig.shiftFrom = hopAlpha
		end
	end
	if not hopping then
		rig.shift = Vector3.zero
	end
	local shift = Vector3.zero
	if hopping and rig.shift ~= Vector3.zero then
		local left = math.max(1 - rig.shiftFrom, 0.05)
		shift = rig.shift * Logic.landing((hopAlpha - rig.shiftFrom) / left)
	end

	local joints = rig.joints
	local bodyMove = CFrame.new(shift)
		* around(
			joints,
			bodyBase,
			"body",
			CFrame.new(0, o.bodyY - o.sink * rig.restDrop, 0)
				* CFrame.Angles(o.bodyPitch, 0, o.bodyRoll)
		)
	local moves = rig.moves
	moves.body = bodyMove
	moves.head = bodyMove
		* around(joints, bodyBase, "head", CFrame.Angles(o.headPitch, o.headYaw, o.headRoll))
	moves.tail = bodyMove
		* around(joints, bodyBase, "tail", CFrame.Angles(-o.tailPitch, o.tailYaw, 0))
	moves.pawFL = bodyMove * around(joints, bodyBase, "pawFL", CFrame.Angles(o.pawFL, 0, 0))
	moves.pawFR = bodyMove * around(joints, bodyBase, "pawFR", CFrame.Angles(o.pawFR, 0, 0))
	moves.pawBL = bodyMove * around(joints, bodyBase, "pawBL", CFrame.Angles(o.pawBL, 0, 0))
	moves.pawBR = bodyMove * around(joints, bodyBase, "pawBR", CFrame.Angles(o.pawBR, 0, 0))

	local frames = rig.frames
	for i, group in rig.groups do
		frames[i] = moves[group] * base[i]
	end
	Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	for i, part in parts do
		written[i] = part.CFrame
	end
end

-- Starts a hiss hop. A server jump that landed just before the hiss arrived is drawn as the hop's travel too.
function Pose.startHop(rig: Rig)
	if os.clock() - rig.jumpAt < 0.3 then
		rig.shift = -rig.jump
		rig.shiftFrom = 0
	end
end

-- The floor under the cat with the model's axes (-Z is the way it faces), for props that play with it.
function Pose.floor(rig: Rig): CFrame
	if rig.usesMotors or rig.bodyIndex == 0 then
		return rig.model:GetPivot()
	end
	local joint: CFrame? = rig.joints.body
	local bodyBase = rig.base[rig.bodyIndex]
	return if joint ~= nil then bodyBase * joint else bodyBase
end

-- Puts every part back where the server has it.
function Pose.release(rig: Rig)
	if rig.usesMotors then
		for _, motor in rig.motors do
			motor.Transform = CFrame.identity
		end
		return
	end
	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	for i, part in rig.parts do
		if part.Parent ~= nil and part.CFrame == rig.written[i] then
			table.insert(parts, part)
			table.insert(frames, rig.base[i])
		end
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

return Pose
