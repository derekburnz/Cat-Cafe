--!strict
-- A player character's tackle poses (design v0.11, F74; Derek 2026-10-27: the Shove becomes a Tackle): the dive, the
-- stumble to a stop after a hit, the belly slide and get up after a miss, and a tackled player's fall and get up.
-- `Avatar.at` says which pose a character is in at a moment from its tackle times, `Avatar.bind` reads an R15 rig's
-- joints and `Avatar.solve` turns a pose into Motor6D Transforms, lowered so the lowest part rests on the floor.
-- No services and nothing written: Tackle.luau applies the Transforms every frame, and the preview tool
-- (assets/cat-cafe/anim/preview) runs these same functions outside Roblox.

local Presets = require(script.Parent.Presets)

local Avatar = {}

-- Degrees about each R15 joint, in the joint's own axes (the character faces -Z, +X is its right).
export type Pose = {
	lean: number, -- the whole body tips forward about the hips (negative: backwards)
	roll: number, -- and over to its right
	air: number, -- studs from the floor to the lowest part
	waist: number, -- bent forward at the waist
	neck: number, -- chin up
	shL: number, -- arm raised forward from hanging down (180: straight up)
	shR: number,
	spL: number, -- arm out to the side
	spR: number,
	elL: number, -- elbow bent
	elR: number,
	hipL: number, -- thigh forward (negative: back)
	hipR: number,
	knL: number, -- knee bent
	knR: number,
}

-- Server times of one character's tackle moves; any may be missing.
export type Times = {
	tackleAt: number?, -- it pressed Tackle (TackleAt, or on its own screen the press itself)
	hitAt: number?, -- its tackle landed (the target's ShovedAt)
	missAt: number?, -- its tackle missed (TackleMissAt)
	shovedAt: number?, -- it was tackled (ShovedAt)
	fallForward: boolean?, -- the tackle hit it from behind, so it falls on its front
	side: number?, -- -1 to 1: how much the tackle pushed it towards its right
}

-- The engineer's timers, seconds (Presets.tacklePose has the design's numbers).
export type Timing = {
	lunge: number,
	grace: number,
	hitRecover: number,
	missRecover: number,
	push: number,
	down: number,
}

type Link = {
	motor: Motor6D,
	parent: BasePart,
	part: BasePart,
	c0: CFrame,
	c1: CFrame, -- C1:Inverse()
	size: Vector3,
}

export type Rig = {
	root: BasePart, -- HumanoidRootPart
	joints: { [string]: Motor6D }, -- the posed R15 joints by name
	links: { Link }, -- every Motor6D out from the root, parents first
	restLow: number, -- the lowest point standing, in the root's frame
}

local FIELDS = {
	"lean",
	"roll",
	"air",
	"waist",
	"neck",
	"shL",
	"shR",
	"spL",
	"spR",
	"elL",
	"elR",
	"hipL",
	"hipR",
	"knL",
	"knR",
}
-- The R15 joints a pose moves (each Motor6D sits in the child part and is named after the joint).
local JOINTS: { [string]: string } = {
	Root = "LowerTorso",
	Waist = "UpperTorso",
	Neck = "Head",
	LeftShoulder = "LeftUpperArm",
	RightShoulder = "RightUpperArm",
	LeftElbow = "LeftLowerArm",
	RightElbow = "RightLowerArm",
	LeftHip = "LeftUpperLeg",
	RightHip = "RightUpperLeg",
	LeftKnee = "LeftLowerLeg",
	RightKnee = "RightLowerLeg",
}

-- A full pose from a Presets.tacklePose key: `sh`, `sp`, `el`, `hip` and `kn` set both sides, the L and R keys one.
function Avatar.pose(spec: { [string]: number }): Pose
	local function side(key: string, name: string): number
		return spec[key] or spec[name] or 0
	end
	return {
		lean = spec.lean or 0,
		roll = spec.roll or 0,
		air = spec.air or 0,
		waist = spec.waist or 0,
		neck = spec.neck or 0,
		shL = side("shL", "sh"),
		shR = side("shR", "sh"),
		spL = side("spL", "sp"),
		spR = side("spR", "sp"),
		elL = side("elL", "el"),
		elR = side("elR", "el"),
		hipL = side("hipL", "hip"),
		hipR = side("hipR", "hip"),
		knL = side("knL", "kn"),
		knR = side("knR", "kn"),
	}
end

local STAND = Avatar.pose({})
local keys: { [string]: Pose } = {}
local function key(name: string): Pose
	local pose = keys[name]
	if pose == nil then
		pose = Avatar.pose(Presets.tacklePose.poses[name])
		keys[name] = pose
	end
	return pose
end

function Avatar.mix(a: Pose, b: Pose, k: number): Pose
	local out = {} :: { [string]: number }
	for _, field in FIELDS do
		local from = (a :: any)[field] :: number
		out[field] = from + ((b :: any)[field] - from) * k
	end
	return (out :: any) :: Pose
end

local function smooth(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

-- Through key poses at fractions `at` of a move, easing between each pair. Always a new table, so a caller may add
-- to it.
local function through(steps: { { at: number, pose: Pose } }, alpha: number): Pose
	for i = 2, #steps do
		local a, b = steps[i - 1], steps[i]
		if alpha < b.at then
			return Avatar.mix(a.pose, b.pose, smooth((alpha - a.at) / (b.at - a.at)))
		end
	end
	local last = steps[#steps].pose
	return Avatar.mix(last, last, 0)
end

-- The dive, `alpha` 0 to 1 of the lunge: a quick crouch, the push off and a flat dive, arms out ahead.
function Avatar.dive(alpha: number): Pose
	return through({
		{ at = 0, pose = STAND },
		{ at = 0.15, pose = key("coil") },
		{ at = 0.45, pose = key("launch") },
		{ at = 1, pose = key("fly") },
	}, alpha)
end

-- The diver after its lunge, `seconds` in, until the server says hit or miss: it comes down onto its belly.
function Avatar.landing(seconds: number): Pose
	return Avatar.mix(key("fly"), key("belly"), smooth(seconds / Presets.tacklePose.land))
end

-- A miss, `alpha` 0 to 1 of the stand-up time: it slides on its belly with a wobble that dies away, pushes up onto
-- its hands and knees, gets its feet under it and stands.
function Avatar.missed(alpha: number): Pose
	local pose = through({
		{ at = 0, pose = key("belly") },
		{ at = 0.5, pose = key("belly") },
		{ at = 0.7, pose = key("allFours") },
		{ at = 0.86, pose = key("crouch") },
		{ at = 1, pose = STAND },
	}, alpha)
	local s = Presets.tacklePose.slide
	local fade = math.clamp(1 - alpha / 0.5, 0, 1)
	if fade > 0 then
		local swing = math.sin(alpha * Presets.tacklePose.missRecover * s.hz * 2 * math.pi) * fade
		pose.neck += s.neck * swing
		pose.knL += s.kick * swing
		pose.knR -= s.kick * swing
		pose.roll += s.roll * swing
	end
	return pose
end

-- A hit, `alpha` 0 to 1 of the stand-up time, from wherever the dive had got to: it catches itself on one foot,
-- arms flung out, and straightens up.
function Avatar.stumble(from: Pose, alpha: number): Pose
	return through({
		{ at = 0, pose = from },
		{ at = 0.25, pose = key("stumble") },
		{ at = 1, pose = STAND },
	}, alpha)
end

-- Tackled, `alpha` 0 to 1 of the push and the time down: knocked off its feet onto its back (or its front when hit
-- from behind), a moment down, then up again. `side` tips it towards a push from the side.
function Avatar.tackled(alpha: number, forward: boolean, side: number): Pose
	local pose = if forward
		then through({
			{ at = 0, pose = STAND },
			{ at = 0.1, pose = key("recoilForward") },
			{ at = 0.3, pose = key("belly") },
			{ at = 0.55, pose = key("belly") },
			{ at = 0.75, pose = key("allFours") },
			{ at = 0.88, pose = key("crouch") },
			{ at = 1, pose = STAND },
		}, alpha)
		else through({
			{ at = 0, pose = STAND },
			{ at = 0.1, pose = key("recoil") },
			{ at = 0.3, pose = key("back") },
			{ at = 0.55, pose = key("back") },
			{ at = 0.75, pose = key("sit") },
			{ at = 0.88, pose = key("crouch") },
			{ at = 1, pose = STAND },
		}, alpha)
	-- the tip towards the push lasts while it is off its feet
	local over = if alpha < 0.3
		then smooth(alpha / 0.3)
		elseif alpha < 0.75 then 1
		else smooth((1 - alpha) / 0.25)
	pose.roll += math.clamp(side, -1, 1) * Presets.tacklePose.sideRoll * over
	return pose
end

-- Which pose a character with these times is in at `now` (server time), how much of it shows (0 to 1, easing in
-- from and out to whatever the character was playing), the time the move began (a key that tells one move from the
-- next) and the time from which the character should be standing still, held by the engineer's timers. Nil when it
-- is in no tackle move. A move begun later wins: a diver tackled mid-lunge falls.
function Avatar.at(times: Times, now: number, timing: Timing): (Pose?, number, number, number)
	local t = Presets.tacklePose
	local function weight(began: number, ends: number): number
		return math.min(smooth((now - began) / t.blendIn), smooth((ends - now) / t.blendOut))
	end

	local shovedAt = times.shovedAt
	local tackleAt = times.tackleAt
	local tackledEnds = if shovedAt ~= nil then shovedAt + timing.push + timing.down else -math.huge
	local tackled = shovedAt ~= nil and now >= shovedAt and now < tackledEnds
	if tackled and shovedAt ~= nil and (tackleAt == nil or shovedAt >= tackleAt) then
		local pose = Avatar.tackled(
			(now - shovedAt) / (timing.push + timing.down),
			times.fallForward == true,
			times.side or 0
		)
		return pose, weight(shovedAt, tackledEnds), shovedAt, shovedAt + timing.push
	end
	if tackleAt == nil or now < tackleAt then
		return nil, 0, 0, 0
	end

	local windowEnds = tackleAt + timing.lunge + timing.grace
	local hitAt = times.hitAt
	if hitAt ~= nil and hitAt >= tackleAt - 0.1 and hitAt <= windowEnds + 0.5 then
		if now < hitAt then
			return Avatar.dive((now - tackleAt) / timing.lunge),
				weight(tackleAt, math.huge),
				tackleAt,
				hitAt
		end
		local ends = hitAt + timing.hitRecover
		if now >= ends then
			return nil, 0, 0, 0
		end
		local since = hitAt - tackleAt
		local from = if since < timing.lunge
			then Avatar.dive(since / timing.lunge)
			else Avatar.landing(since - timing.lunge)
		return Avatar.stumble(from, (now - hitAt) / timing.hitRecover),
			weight(tackleAt, ends),
			tackleAt,
			hitAt
	end

	-- A miss counts from TackleMissAt; one that never arrives counts from a little after the window.
	local missAt = times.missAt
	if missAt == nil or missAt < tackleAt or missAt > windowEnds + t.lost + 1 then
		missAt = if now >= windowEnds + t.lost then windowEnds else nil
	end
	if missAt ~= nil and now >= missAt then
		local ends = missAt + timing.missRecover
		if now >= ends then
			return nil, 0, 0, 0
		end
		return Avatar.missed((now - missAt) / timing.missRecover),
			weight(tackleAt, ends),
			tackleAt,
			tackleAt + timing.lunge
	end
	local held = tackleAt + timing.lunge
	if now < held then
		return Avatar.dive((now - tackleAt) / timing.lunge),
			weight(tackleAt, math.huge),
			tackleAt,
			held
	end
	return Avatar.landing(now - held), weight(tackleAt, math.huge), tackleAt, held
end

-- Every Motor6D under an R15 character, out from its HumanoidRootPart; nil for anything else (an R6 character has
-- no LowerTorso Root joint and keeps its own animation).
function Avatar.bind(character: Model): Rig?
	local root = character:FindFirstChild("HumanoidRootPart")
	local lower = character:FindFirstChild("LowerTorso")
	if root == nil or not root:IsA("BasePart") or lower == nil then
		return nil
	end
	local byParent: { [BasePart]: { Motor6D } } = {}
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") then
			local motor = descendant :: Motor6D
			local part0, part1 = motor.Part0, motor.Part1
			if part0 ~= nil and part1 ~= nil then
				local list = byParent[part0] or {}
				table.insert(list, motor)
				byParent[part0] = list
			end
		end
	end
	local links: { Link } = {}
	local queue: { BasePart } = { root :: BasePart }
	local seen: { [BasePart]: boolean } = { [root :: BasePart] = true }
	local head = 1
	while head <= #queue do
		local part = queue[head]
		head += 1
		local motors = byParent[part]
		if motors == nil then
			continue
		end
		for _, motor in motors do
			local child = motor.Part1 :: BasePart
			if not seen[child] then
				seen[child] = true
				table.insert(queue, child)
				table.insert(links, {
					motor = motor,
					parent = part,
					part = child,
					c0 = motor.C0,
					c1 = motor.C1:Inverse(),
					size = child.Size,
				})
			end
		end
	end
	local joints: { [string]: Motor6D } = {}
	for name, partName in JOINTS do
		local part = character:FindFirstChild(partName)
		local motor = if part ~= nil then part:FindFirstChild(name) else nil
		if motor ~= nil and motor:IsA("Motor6D") then
			joints[name] = motor :: Motor6D
		end
	end
	local rootJoint: Motor6D? = joints.Root
	if rootJoint == nil then
		return nil
	end
	local rig: Rig = { root = root :: BasePart, joints = joints, links = links, restLow = 0 }
	rig.restLow = Avatar.lowest(rig, {})
	return rig
end

-- The lowest point of the rig's parts in the root's frame, with these Transforms (the rest pose where none).
function Avatar.lowest(rig: Rig, transforms: { [Motor6D]: CFrame }): number
	local at: { [BasePart]: CFrame } = { [rig.root] = CFrame.identity }
	local low = math.huge
	for _, link in rig.links do
		local frame = at[link.parent]
			* link.c0
			* (transforms[link.motor] or CFrame.identity)
			* link.c1
		at[link.part] = frame
		local _, y, _, _, _, _, r10, r11, r12 = frame:GetComponents()
		local s = link.size
		low = math.min(
			low,
			y - 0.5 * (math.abs(r10) * s.X + math.abs(r11) * s.Y + math.abs(r12) * s.Z)
		)
	end
	return low
end

-- The Transforms that put the rig in `pose`, its lowest part `pose.air` studs above where its feet rest standing.
function Avatar.solve(rig: Rig, pose: Pose): { [Motor6D]: CFrame }
	local out: { [Motor6D]: CFrame } = {}
	local j = rig.joints
	local function set(name: string, frame: CFrame)
		local motor: Motor6D? = j[name]
		if motor ~= nil then
			out[motor] = frame
		end
	end
	local rad = math.rad
	local turn = CFrame.Angles(rad(-pose.lean), 0, rad(-pose.roll))
	set("Root", turn)
	set("Waist", CFrame.Angles(rad(-pose.waist), 0, 0))
	set("Neck", CFrame.Angles(rad(pose.neck), 0, 0))
	set("LeftShoulder", CFrame.Angles(rad(pose.shL), 0, rad(-pose.spL)))
	set("RightShoulder", CFrame.Angles(rad(pose.shR), 0, rad(pose.spR)))
	set("LeftElbow", CFrame.Angles(rad(pose.elL), 0, 0))
	set("RightElbow", CFrame.Angles(rad(pose.elR), 0, 0))
	set("LeftHip", CFrame.Angles(rad(pose.hipL), 0, 0))
	set("RightHip", CFrame.Angles(rad(pose.hipR), 0, 0))
	set("LeftKnee", CFrame.Angles(rad(-pose.knL), 0, 0))
	set("RightKnee", CFrame.Angles(rad(-pose.knR), 0, 0))
	-- Down (or up) so the lowest part sits `air` above the floor; the drop is along the root's up, in Root's C0 axes.
	local drop = rig.restLow + pose.air - Avatar.lowest(rig, out)
	local root = j.Root
	out[root] = CFrame.new(root.C0.Rotation:Inverse() * Vector3.new(0, drop, 0)) * turn
	return out
end

return Avatar
