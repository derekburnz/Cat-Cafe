--!strict
-- Moves a cat's body, head, tail and front paws on this client only. Parts are found by name (Body, Head, Tail,
-- or names ending _Body, _Head, _Tail, plus the placeholder's ears, eyes and legs), so one set of idles fits every
-- breed. Two ways in, picked per model:
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
}

local LEGS: { [string]: Group } =
	{ LegF1 = "pawFL", LegF2 = "pawFR", LegB1 = "pawBL", LegB2 = "pawBR" }
local HEAD_PIECES: { [string]: boolean } = { EarL = true, EarR = true, Eye1 = true, Eye2 = true }

local function isNamed(instance: Instance, name: string): boolean
	local text = instance.Name
	return text == name or (#text > #name + 1 and text:sub(-(#name + 1)) == "_" .. name)
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
	if isNamed(part, "Head") or HEAD_PIECES[part.Name] == true then
		return "head"
	end
	local leg: Group? = LEGS[part.Name]
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

-- A part's own pivot when its model sets one (the asset thread's hinge points), else nil.
local function hingeOf(part: BasePart): Vector3?
	if part.PivotOffset ~= CFrame.identity then
		return part:GetPivot().Position
	end
	return nil
end

-- The neck: the back of the head, low down, unless the head carries its own hinge.
local function neckOf(head: BasePart, axes: CFrame): Vector3
	local hinge = hingeOf(head)
	if hinge ~= nil then
		return hinge
	end
	local size = head.Size
	return head.Position + axes:VectorToWorldSpace(Vector3.new(0, -0.3 * size.Y, 0.4 * size.Z))
end

-- The tail root: the end of the tail's long axis nearest the body.
local function tailRootOf(tail: BasePart, body: BasePart): Vector3
	local hinge = hingeOf(tail)
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
	}
end

-- Reads a cat model once. Nil when it has no body, or when its body is welded to something that is not ours
-- to move (the held cat rides its holder's arms).
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
	local legs: { [Group]: BasePart } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and (descendant :: BasePart).Anchored then
			local part = descendant :: BasePart
			local group = groupOf(part, body, head)
			table.insert(rig.parts, part)
			table.insert(rig.groups, group)
			table.insert(rig.base, part.CFrame)
			table.insert(rig.written, part.CFrame)
			if part == body then
				rig.bodyIndex = #rig.parts
			end
			local legGroup: Group? = LEGS[part.Name]
			if legGroup ~= nil then
				legs[group] = part
			end
		end
	end
	if rig.bodyIndex == 0 then
		return nil
	end

	local pivot = model:GetPivot()
	local axes = pivot.Rotation
	local bodyBase = body.CFrame
	local function joint(position: Vector3): CFrame
		local relative: CFrame = (bodyBase:ToObjectSpace(CFrame.new(position) * axes))
		return relative
	end
	rig.joints.body = joint(pivot.Position)
	if head ~= nil then
		rig.joints.head = joint(neckOf(head, axes))
	end
	if tail ~= nil then
		rig.joints.tail = joint(tailRootOf(tail, body))
	end
	for group, leg in legs do
		rig.joints[group] = joint(hipOf(leg))
	end
	return rig
end

local function applyMotors(rig: Rig, o: Logic.Offsets)
	local motors = rig.motors
	local body: Motor6D? = motors.body
	if body ~= nil then
		body.Transform = CFrame.new(0, o.bodyY, 0) * CFrame.Angles(o.bodyPitch, 0, o.bodyRoll)
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

-- Draws one frame of offsets. `hopAlpha` is the hiss progress (0 to 1), or -1 when no hiss plays: a server jump
-- that lands during a hiss is drawn as the hop's travel instead of a snap. False once the cat has gone.
function Pose.apply(rig: Rig, o: Logic.Offsets, hopAlpha: number): boolean
	if rig.model.Parent == nil or rig.body.Parent == nil then
		return false
	end
	if rig.usesMotors then
		applyMotors(rig, o)
		return true
	end

	local parts = rig.parts
	local base = rig.base
	local written = rig.written
	for i, part in parts do
		local now = part.CFrame
		if now ~= written[i] then
			base[i] = now
		end
	end

	local bodyBase = base[rig.bodyIndex]
	local moved = bodyBase.Position - rig.lastBody
	rig.lastBody = bodyBase.Position
	local hopping = hopAlpha >= 0 and hopAlpha < 1
	if moved.Magnitude > Presets.motion.hiss.jumpStuds then
		rig.jump = moved
		rig.jumpAt = os.clock()
		if hopping then
			rig.shift = -moved
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
	local function around(group: Group, rotation: CFrame): CFrame
		local joint: CFrame? = joints[group]
		if joint == nil then
			return CFrame.identity
		end
		local world = bodyBase * joint
		return world * rotation * world:Inverse()
	end
	local bodyMove = CFrame.new(shift)
		* around("body", CFrame.new(0, o.bodyY, 0) * CFrame.Angles(o.bodyPitch, 0, o.bodyRoll))
	local moves: { [Group]: CFrame } = {
		body = bodyMove,
		head = bodyMove * around("head", CFrame.Angles(o.headPitch, o.headYaw, o.headRoll)),
		tail = bodyMove * around("tail", CFrame.Angles(-o.tailPitch, o.tailYaw, 0)),
		pawFL = bodyMove * around("pawFL", CFrame.Angles(o.pawFL, 0, 0)),
		pawFR = bodyMove * around("pawFR", CFrame.Angles(o.pawFR, 0, 0)),
		pawBL = bodyMove,
		pawBR = bodyMove,
	}

	local frames: { CFrame } = {}
	for i, group in rig.groups do
		frames[i] = moves[group] * base[i]
	end
	Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	for i, part in parts do
		written[i] = part.CFrame
	end
	return true
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
