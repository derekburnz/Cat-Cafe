--!strict
-- Moves a cat's body, head, tail, legs, eyes and ears on this client only. Parts are found by name (Body, Head,
-- Tail, or names ending _Body, _Head, _Tail, plus ears, eyes and legs named EarL, Eye1, LegF1 and so on, or ending
-- so), so one set of idles fits every breed. On the bodies with hinged pieces (PR #259: walking A and sitting B)
-- each piece is a Model pivoted at its joint, the eyes and ears nested in the head's, and every piece turns about
-- its own pivot: Model-Agent's piece poses (Presets.catPoses) exactly as the manifest gives them, the idles on top,
-- an eye squashed flat to blink and an ear flicked back. A working cat stood upright at its station (Pose
-- "upright", F25) turns in the floor's axes instead of its turned model's, and outfit parts ride what their
-- Follows attribute names. Two ways in, picked per model:
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

-- "body", "head", "tail", "pawFL", "pawFR", "pawBL", "pawBR", "eye1", "eye2", "earL" or "earR". A plain string
-- so it can key tables.
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
	kind: Logic.Body,
	poseTurns: { [string]: { [Group]: CFrame } }, -- each piece pose's turn per joint, in the joint's axes
	lifts: { [string]: number }, -- studs each piece pose lowers the cat, at its scale
	eyes: { number }, -- which of parts are eye parts, squashed to blink
	eyeSizes: { Vector3 },
	eyeAxes: { number }, -- the eye part's own axis that runs up the face: 1 X, 2 Y, 3 Z
	squash: number, -- the eye height last drawn, 1 open
	-- The belly filling with a breath (Offsets.belly): the body's parts swell up from the bottom of the body and
	-- out to the sides, and each piece rides up by how high its joint sits. Off for an upright cat or a Motor6D
	-- rig, which lift the whole body instead.
	canSwell: boolean,
	bellyFrame: CFrame, -- the bottom middle of the body, in the body part's own space
	bellyHeight: number, -- studs from there to the top of the body
	bellyParts: { number }, -- which of parts ride the body, moved with the swell
	bellySized: { number }, -- which of those are the body's own blocks, which also grow
	bellySizes: { Vector3 },
	bellyUp: { number }, -- each sized part's own axis that runs up the body: 1 X, 2 Y, 3 Z
	bellySide: { number }, -- and across it
	bellyRise: { [Group]: number }, -- of the rise each piece rides, 0 at the bottom of the body to 1 at the top
	swell: number, -- the swell last drawn, as a share of bellyHeight; 0 at rest
	moves: { [Group]: CFrame }, -- reused every frame, so a phone's garbage collector has less to do
	frames: { CFrame },
}

-- Pieces named for what they are, as the placeholder names them (LegF1, EarL) or as the exporter does, after
-- the object they sit in (<Cat>_LegF1, <Cat>_EarL). Body is the root, not a piece.
local PIECES: { [string]: Group } = {
	Head = "head",
	Tail = "tail",
	LegF1 = "pawFL",
	LegF2 = "pawFR",
	LegB1 = "pawBL",
	LegB2 = "pawBR",
	Eye1 = "eye1",
	Eye2 = "eye2",
	EarL = "earL",
	EarR = "earR",
}
local EAR_OUT = 0.6 -- an ear flicks out sideways this much for each bit it flicks back
-- The swell is drawn in steps of this share of the body's height (under 0.01 studs on any cat), so sizes change a
-- dozen times a second while breathing in or out and not at all at rest between breaths (review S70).
local SWELL_STEP = 0.01
local SWELL_SIZED = 0.25 -- a block of the body at least this share of its height grows with the breath
local SWELL_RIDERS: { Group } = { "head", "tail", "pawFL", "pawFR", "pawBL", "pawBR" } -- eyes and ears ride the head
local IDENTITY: CFrame = CFrame.identity -- a local, as selene's Roblox library has no methods on CFrame.identity

local function isNamed(instance: Instance, name: string): boolean
	local text = instance.Name
	return text == name or (#text > #name + 1 and text:sub(-(#name + 1)) == "_" .. name)
end

local function pieceGroup(instance: Instance): Group?
	for name, group in PIECES do
		if isNamed(instance, name) then
			return group
		end
	end
	return nil
end

local function isLeg(group: Group): boolean
	return string.sub(group, 1, 3) == "paw"
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
	local named: Group? = pieceGroup(part)
	if named ~= nil then
		return named
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
		kind = "parts",
		poseTurns = {},
		lifts = {},
		eyes = {},
		eyeSizes = {},
		eyeAxes = {},
		squash = 1,
		canSwell = false,
		bellyFrame = CFrame.identity,
		bellyHeight = 0,
		bellyParts = {},
		bellySized = {},
		bellySizes = {},
		bellyUp = {},
		bellySide = {},
		bellyRise = {},
		swell = 0,
		moves = {},
		frames = {},
	}
end

-- Which body a cat has: "walk" with hinged back legs (body A), "sit" with hinged front legs only (body B), or
-- "parts" with no hinged pieces (the placeholder and older Part cats). The pieces are the model's own children.
function Pose.kindOf(model: Model): Logic.Body
	local front = false
	for _, child in model:GetChildren() do
		if child:IsA("Model") then
			if isNamed(child, "LegB1") then
				return "walk"
			elseif isNamed(child, "LegF1") then
				front = true
			end
		end
	end
	return if front then "sit" else "parts"
end

-- Whether a part can be squashed to blink: a block or a mesh. A ball or cylinder keeps its proportions.
local function squashable(part: BasePart): boolean
	if part:IsA("Part") then
		return (part :: Part).Shape == Enum.PartType.Block
	end
	return part:IsA("MeshPart")
end

-- The part's own axis that lines up best with `up`: 1 X, 2 Y, 3 Z.
local function axisAlong(frame: CFrame, up: Vector3): number
	local x = math.abs(frame.RightVector:Dot(up))
	local y = math.abs(frame.UpVector:Dot(up))
	local z = math.abs(frame.LookVector:Dot(up))
	if y >= x and y >= z then
		return 2
	end
	return if x >= z then 1 else 3
end

-- How far a part reaches up and down the body from its middle, in the body part's own space.
local function halfHeight(inBody: CFrame, size: Vector3): number
	return math.abs(inBody.RightVector.Y) * size.X / 2
		+ math.abs(inBody.UpVector.Y) * size.Y / 2
		+ math.abs(inBody.LookVector.Y) * size.Z / 2
end

-- Sets up the breath's swell (Rig.canSwell): the bottom and height of the body from its own blocks (the parts
-- named Body), the parts that ride the body, and how high up the body each piece's joint is. Only the big blocks
-- grow (at least SWELL_SIZED of the body's height); stripes, patches and other small markings just ride the swell,
-- so a breathing cat sets a few sizes rather than every part's (review S70).
-- Also returns the bottom of the body, in the body's axes (math.huge with no body blocks).
local function bindBelly(rig: Rig, bodyBase: CFrame): number
	local low, high = math.huge, -math.huge
	local blocks: { number } = {}
	local heights: { number } = {}
	for i, part in rig.parts do
		if rig.groups[i] == "body" then
			table.insert(rig.bellyParts, i)
			if isNamed(part, "Body") then
				local inBody = bodyBase:ToObjectSpace(rig.base[i])
				local half = halfHeight(inBody, part.Size)
				low = math.min(low, inBody.Y - half)
				high = math.max(high, inBody.Y + half)
				if squashable(part) then
					table.insert(blocks, i)
					table.insert(heights, 2 * half)
				end
			end
		end
	end
	if high - low < 0.05 then
		return low
	end
	rig.canSwell = true
	rig.bellyFrame = CFrame.new(0, low, 0)
	rig.bellyHeight = high - low
	for k, i in blocks do
		if heights[k] >= SWELL_SIZED * rig.bellyHeight then
			local up = axisAlong(rig.base[i], bodyBase.UpVector)
			local side = axisAlong(rig.base[i], bodyBase.RightVector)
			table.insert(rig.bellySized, i)
			table.insert(rig.bellySizes, rig.parts[i].Size)
			table.insert(rig.bellyUp, up)
			table.insert(rig.bellySide, if side == up then 0 else side)
		end
	end
	for _, group in SWELL_RIDERS do
		local joint: CFrame? = rig.joints[group]
		if joint ~= nil then
			rig.bellyRise[group] = math.clamp((joint.Y - low) / (high - low), 0, 1)
		end
	end
	return low
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
	local pieces: { [Group]: Model } = {} -- the hinged pieces, each pivoted at its joint
	local faces: { [Group]: BasePart } = {} -- an eye or ear part, for one with no hinge of its own
	local namedLegs = false
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Model") then
			local group = pieceGroup(descendant)
			local found: Model? = if group ~= nil then pieces[group] else nil
			if group ~= nil and found == nil then
				pieces[group] = descendant :: Model
			end
		elseif descendant:IsA("BasePart") then
			local group = pieceGroup(descendant)
			if group ~= nil and isLeg(group) then
				namedLegs = true
			end
		end
	end
	rig.kind = Pose.kindOf(model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and (descendant :: BasePart).Anchored then
			local part = descendant :: BasePart
			local group = groupOf(part, body, head)
			-- An outfit piece says what it rides (Follows), so only an unmarked part of the body can be a leg, and
			-- only on a cat whose legs are not named (the exported cats before PR #259 named every part like the body).
			if
				group == "body"
				and not namedLegs
				and part ~= body
				and part:GetAttribute("Follows") == nil
			then
				group = legOf(part, body) or group
			end
			if (group == "eye1" or group == "eye2") and squashable(part) then
				table.insert(rig.eyes, #rig.parts + 1)
				table.insert(rig.eyeSizes, part.Size)
			end
			if group == "eye1" or group == "eye2" or group == "earL" or group == "earR" then
				faces[group] = faces[group] or part
			end
			table.insert(rig.parts, part)
			table.insert(rig.groups, group)
			table.insert(rig.base, part.CFrame)
			table.insert(rig.written, part.CFrame)
			if part == body then
				rig.bodyIndex = #rig.parts
			end
			if isLeg(group) then
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

	-- A seated cat (the sitting body, or Pose "sit" at its station, PR #260) never lies down either.
	if rig.kind == "sit" or model:GetAttribute("Pose") == "sit" then
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
	-- A hinged piece turns about its own pivot; an eye or ear with none, about its middle.
	for group, piece in pieces do
		rig.joints[group] = joint(piece:GetPivot().Position)
	end
	for group, part in faces do
		local hinged: CFrame? = rig.joints[group]
		if hinged == nil then
			rig.joints[group] = joint(hingeOf(part, model) or part.Position)
		end
	end
	for k, index in rig.eyes do
		rig.eyeAxes[k] = axisAlong(rig.base[index], axes.UpVector)
	end
	local clearance = math.huge -- how high the bottom of the body stands off the floor
	if upright == nil then
		clearance = bindBelly(rig, bodyBase) - floorY
	end

	-- Model-Agent's piece poses, each turn put into its joint's axes once here. The manifest turns a piece in its
	-- own axes (its pivot's), which can lean away from the model's, as the tail's do.
	local attribute = model:GetAttribute("Scale")
	local scale = (if type(attribute) == "number" then attribute else 1) * model:GetScale()
	for name, pose in Presets.catPoses do
		if pose.body ~= rig.kind then
			continue -- a sitting cat cannot take the walking body's poses, nor the other way round
		end
		local turns: { [Group]: CFrame } = {}
		for pieceName, angles in pose.turns do
			local group: Group? = PIECES[pieceName]
			local at: CFrame? = if group ~= nil then rig.joints[group] else nil
			if group ~= nil and at ~= nil then
				local piece: Model? = pieces[group]
				local own = if piece ~= nil
					then (bodyBase * at):ToObjectSpace(piece:GetPivot()).Rotation
					else CFrame.identity
				local turn =
					CFrame.Angles(math.rad(angles[1]), math.rad(angles[2]), math.rad(angles[3]))
				turns[group] = own * turn * own:Inverse()
			end
		end
		rig.poseTurns[name] = turns
		-- The manifest lowers every cat by the same amount at its scale, but a short-legged cat (Munchkin) stands
		-- lower: never drop the body further than to just above the floor.
		rig.lifts[name] =
			math.min(pose.lift * scale, math.max(0, clearance - Presets.motion.lieGap * scale))
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

-- How far into a piece pose the cat is (Offsets.sleep, loaf and lick).
local function weightOf(o: Logic.Offsets, name: string): number
	if name == "sleep" then
		return o.sleep
	elseif name == "loaf" then
		return o.loaf
	elseif name == "lick" then
		return o.lick
	end
	return 0
end

-- The idle's turn at a joint with the piece poses inside it, each blended by how far into it the cat is.
local function posed(rig: Rig, o: Logic.Offsets, group: Group, rotation: CFrame): CFrame
	local out = rotation
	for name, turns in rig.poseTurns do
		local weight = weightOf(o, name)
		local turn: CFrame? = turns[group]
		if weight > 0 and turn ~= nil then
			out *= if weight >= 1 then turn else IDENTITY:Lerp(turn, weight)
		end
	end
	return out
end

local function liftOf(rig: Rig, o: Logic.Offsets): number
	local drop = 0
	for name, lift in rig.lifts do
		drop += lift * weightOf(o, name)
	end
	return drop
end

-- Squashes each eye towards its middle, up and down, to `squash` of its height (1 puts it back). Positions go into
-- frames; sizes are set only when the squash changes.
local function squashEyes(rig: Rig, squash: number, bodyBase: CFrame)
	local resize = squash ~= rig.squash
	rig.squash = squash
	local frames = rig.frames
	for k, index in rig.eyes do
		local group = rig.groups[index]
		local joint: CFrame? = rig.joints[group]
		if joint ~= nil and squash < 1 then
			local centre = rig.moves[group] * bodyBase * joint
			local inEye = centre:ToObjectSpace(frames[index])
			local at = inEye.Position
			frames[index] = centre * CFrame.new(at.X, at.Y * squash, at.Z) * inEye.Rotation
		end
		if resize then
			local size = rig.eyeSizes[k]
			local axis = rig.eyeAxes[k]
			rig.parts[index].Size = Vector3.new(
				if axis == 1 then size.X * squash else size.X,
				if axis == 2 then size.Y * squash else size.Y,
				if axis == 3 then size.Z * squash else size.Z
			)
		end
	end
end

-- Spreads the parts riding the body away from its bottom middle (`bottom`, in world space): up by the swell and
-- out to the sides by motion.belly.side of it.
local function swellBody(rig: Rig, frames: { CFrame }, bottom: CFrame, swell: number)
	local up = 1 + swell
	local side = 1 + swell * Presets.motion.belly.side
	for _, index in rig.bellyParts do
		local inBody = bottom:ToObjectSpace(frames[index])
		local at = inBody.Position
		frames[index] = bottom * CFrame.new(at.X * side, at.Y * up, at.Z) * inBody.Rotation
	end
end

-- Grows the body's own blocks by the swell (0 puts them back), along their axes that run up and across the body.
local function resizeBody(rig: Rig, swell: number)
	rig.swell = swell
	local up = 1 + swell
	local side = 1 + swell * Presets.motion.belly.side
	for k, index in rig.bellySized do
		local part = rig.parts[index]
		if part.Parent ~= nil then
			local size = rig.bellySizes[k]
			local alongUp, across = rig.bellyUp[k], rig.bellySide[k]
			part.Size = Vector3.new(
				size.X * (if alongUp == 1 then up elseif across == 1 then side else 1),
				size.Y * (if alongUp == 2 then up elseif across == 2 then side else 1),
				size.Z * (if alongUp == 3 then up elseif across == 3 then side else 1)
			)
		end
	end
end

local function applyMotors(rig: Rig, o: Logic.Offsets)
	local motors = rig.motors
	local body: Motor6D? = motors.body
	if body ~= nil then
		body.Transform = CFrame.new(0, o.bodyY + o.belly - o.sink * rig.restDrop, 0)
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
	-- A body that cannot swell (an upright cat) lifts whole with the breath instead.
	local swell = 0
	local lift = o.bodyY - o.sink * rig.restDrop - liftOf(rig, o)
	if rig.canSwell then
		swell = math.floor(math.max(o.belly, 0) / rig.bellyHeight / SWELL_STEP + 0.5) * SWELL_STEP
	else
		lift += o.belly
	end
	local bodyMove = CFrame.new(shift)
		* around(
			joints,
			bodyBase,
			"body",
			CFrame.new(0, lift, 0) * CFrame.Angles(o.bodyPitch, 0, o.bodyRoll)
		)
	local moves = rig.moves
	moves.body = bodyMove
	moves.head = bodyMove
		* around(
			joints,
			bodyBase,
			"head",
			posed(rig, o, "head", CFrame.Angles(o.headPitch, o.headYaw, o.headRoll))
		)
	moves.tail = bodyMove
		* around(
			joints,
			bodyBase,
			"tail",
			posed(rig, o, "tail", CFrame.Angles(-o.tailPitch, o.tailYaw, 0))
		)
	moves.pawFL = bodyMove
		* around(joints, bodyBase, "pawFL", posed(rig, o, "pawFL", CFrame.Angles(o.pawFL, 0, 0)))
	moves.pawFR = bodyMove
		* around(joints, bodyBase, "pawFR", posed(rig, o, "pawFR", CFrame.Angles(o.pawFR, 0, 0)))
	moves.pawBL = bodyMove
		* around(joints, bodyBase, "pawBL", posed(rig, o, "pawBL", CFrame.Angles(o.pawBL, 0, 0)))
	moves.pawBR = bodyMove
		* around(joints, bodyBase, "pawBR", posed(rig, o, "pawBR", CFrame.Angles(o.pawBR, 0, 0)))
	local bottom: CFrame = IDENTITY
	if swell > 0 then
		-- each piece rides the swell by how high up the body its joint is
		bottom = bodyMove * bodyBase * rig.bellyFrame
		local rise = bottom.UpVector * (swell * rig.bellyHeight)
		for group, share in rig.bellyRise do
			moves[group] = CFrame.new(rise * share) * moves[group]
		end
	end
	-- the eyes and ears ride the head; an ear flicks back and out about its base
	moves.eye1 = moves.head
	moves.eye2 = moves.head
	moves.earL = moves.head
		* around(joints, bodyBase, "earL", CFrame.Angles(o.earL, 0, o.earL * EAR_OUT))
	moves.earR = moves.head
		* around(joints, bodyBase, "earR", CFrame.Angles(o.earR, 0, -o.earR * EAR_OUT))

	local frames = rig.frames
	for i, group in rig.groups do
		frames[i] = moves[group] * base[i]
	end
	if swell > 0 then
		swellBody(rig, frames, bottom, swell)
	end
	if swell ~= rig.swell then
		resizeBody(rig, swell)
	end
	local squash = 1 - (1 - Presets.motion.blink.squash) * math.clamp(o.blink, 0, 1)
	if #rig.eyes > 0 and (squash < 1 or rig.squash < 1) then
		squashEyes(rig, squash, bodyBase)
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
	if rig.swell ~= 0 then
		resizeBody(rig, 0)
	end
	if rig.squash < 1 then
		rig.squash = 1
		for k, index in rig.eyes do
			local part = rig.parts[index]
			if part.Parent ~= nil then
				part.Size = rig.eyeSizes[k]
			end
		end
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
