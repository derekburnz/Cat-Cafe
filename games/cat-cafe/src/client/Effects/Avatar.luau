--!strict
-- A player character's tackle poses (design v0.11, F74; Derek 2026-10-27: the Shove becomes a Tackle): the dive, the
-- stumble to a stop after a hit, the belly slide and get up after a miss, and a tackled player's fall and get up.
-- `Avatar.at` says which pose a character is in at a moment from its tackle times, `Avatar.bind` reads an R15 rig's
-- joints and `Avatar.solve` turns a pose into joint Transforms, lowered so the lowest part rests on the floor. An R15
-- or R6 character, with Motor6D joints or the newer AnimationConstraint ones; R6 has no waist, elbows or knees, so
-- those parts of a pose are left out on it.
-- The net hold (Derek 2026-10-28): the right arm holding the player's net upright and leaning ahead while it walks
-- a catching area; `Avatar.holdNet` poses that arm only and `Avatar.netHand` says where in the hand the net goes.
-- The carry (Derek 2026-10-28): arms crossed in front of the chest with the caught cat on them; `Avatar.carryArms`
-- poses the upper body only, so the legs keep walking, and `Avatar.cradle` says where on the arms the cat rests.
-- The Cat Cannon flight (F84): the hop into the barrel, the curled ball rolling through the air and the crouch
-- landing with a bounce; `Avatar.flight` says where the body is and how it is posed at a moment of the flight and
-- `Avatar.cannon` turns that into joint Transforms, the body's move from the anchored root included. `Avatar.glide`
-- and `Avatar.glideFrames` do the same for the character flying through the cloud cutscene.
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
	twL: number, -- upper arm turned in about its own length, so a bent elbow brings the forearm across the body
	twR: number,
	elL: number, -- elbow bent
	elR: number,
	hipL: number, -- thigh forward (negative: back)
	hipR: number,
	knL: number, -- knee bent
	knR: number,
	lgL: number, -- thigh out to the side
	lgR: number,
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

-- A joint the Animator drives: a Motor6D, or an AnimationConstraint on avatars with the newer joints. Both take a
-- Transform between the parent part's joint frame and the child's.
export type Joint = Motor6D | AnimationConstraint

type Link = {
	motor: Joint,
	parent: BasePart,
	part: BasePart,
	c0: CFrame, -- the joint's frame in the parent part (C0, or Attachment0's CFrame)
	c1: CFrame, -- and the inverse of its frame in the child part
	size: Vector3,
}

export type Rig = {
	root: BasePart, -- HumanoidRootPart
	joints: { [string]: Joint }, -- the posed joints by their R15 name (an R6 rig has fewer)
	axes: { [string]: CFrame }, -- each posed joint's frame in its parent part, turned only
	parts: { [string]: BasePart }, -- the part each posed joint moves
	links: { Link }, -- every joint out from the root, parents first
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
	"twL",
	"twR",
	"elL",
	"elR",
	"hipL",
	"hipR",
	"knL",
	"knR",
	"lgL",
	"lgR",
}
-- The joints a pose moves, by the parts each joins (parent, child): found that way rather than by the joint's own
-- name or class, which differ between rigs.
local R15: { [string]: { string } } = {
	Root = { "HumanoidRootPart", "LowerTorso" },
	Waist = { "LowerTorso", "UpperTorso" },
	Neck = { "UpperTorso", "Head" },
	LeftShoulder = { "UpperTorso", "LeftUpperArm" },
	RightShoulder = { "UpperTorso", "RightUpperArm" },
	LeftElbow = { "LeftUpperArm", "LeftLowerArm" },
	RightElbow = { "RightUpperArm", "RightLowerArm" },
	RightWrist = { "RightLowerArm", "RightHand" },
	LeftHip = { "LowerTorso", "LeftUpperLeg" },
	RightHip = { "LowerTorso", "RightUpperLeg" },
	LeftKnee = { "LeftUpperLeg", "LeftLowerLeg" },
	RightKnee = { "RightUpperLeg", "RightLowerLeg" },
}
local R6: { [string]: { string } } = {
	Root = { "HumanoidRootPart", "Torso" },
	Neck = { "Torso", "Head" },
	LeftShoulder = { "Torso", "Left Arm" },
	RightShoulder = { "Torso", "Right Arm" },
	LeftHip = { "Torso", "Left Leg" },
	RightHip = { "Torso", "Right Leg" },
}

-- A full pose from a Presets.tacklePose key: `sh`, `sp`, `tw`, `el`, `hip`, `kn` and `lg` set both sides, the L and
-- R keys one.
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
		twL = side("twL", "tw"),
		twR = side("twR", "tw"),
		elL = side("elL", "el"),
		elR = side("elR", "el"),
		hipL = side("hipL", "hip"),
		hipR = side("hipR", "hip"),
		knL = side("knL", "kn"),
		knR = side("knR", "kn"),
		lgL = side("lgL", "lg"),
		lgR = side("lgR", "lg"),
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

-- One joint's parts and frames: a Motor6D's Part0, Part1, C0 and C1, or an AnimationConstraint's attachments.
local function jointParts(joint: Instance): (BasePart?, BasePart?, CFrame, CFrame)
	if joint:IsA("Motor6D") then
		local motor = joint :: Motor6D
		return motor.Part0, motor.Part1, motor.C0, motor.C1
	elseif joint:IsA("AnimationConstraint") then
		local constraint = joint :: AnimationConstraint
		local a0, a1 = constraint.Attachment0, constraint.Attachment1
		if a0 ~= nil and a1 ~= nil then
			local p0, p1 = a0.Parent, a1.Parent
			if p0 ~= nil and p0:IsA("BasePart") and p1 ~= nil and p1:IsA("BasePart") then
				return p0 :: BasePart, p1 :: BasePart, a0.CFrame, a1.CFrame
			end
		end
	end
	return nil, nil, CFrame.identity, CFrame.identity
end

-- Every joint under a character, out from its HumanoidRootPart, and the ones a pose moves; nil when it has no root
-- joint yet (still loading) or is neither an R15 nor an R6 rig.
function Avatar.bind(character: Model): Rig?
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	-- the joints out of each part; an AnimationConstraint first, so it wins over a Motor6D left beside it
	local byParent: { [BasePart]: { { joint: Joint, child: BasePart, c0: CFrame, c1: CFrame } } } =
		{}
	for _, descendant in character:GetDescendants() do
		local isMotor = descendant:IsA("Motor6D")
		if isMotor or descendant:IsA("AnimationConstraint") then
			local part0, part1, c0, c1 = jointParts(descendant)
			if part0 ~= nil and part1 ~= nil then
				local list = byParent[part0] or {}
				local entry =
					{ joint = (descendant :: any) :: Joint, child = part1, c0 = c0, c1 = c1 }
				table.insert(list, if isMotor then #list + 1 else 1, entry)
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
		local found = byParent[part]
		if found == nil then
			continue
		end
		for _, entry in found do
			local child = entry.child
			if not seen[child] then
				seen[child] = true
				table.insert(queue, child)
				table.insert(links, {
					motor = entry.joint,
					parent = part,
					part = child,
					c0 = entry.c0,
					c1 = entry.c1:Inverse(),
					size = child.Size,
				})
			end
		end
	end
	local names: { [string]: { string } } = if character:FindFirstChild("LowerTorso") ~= nil
		then R15
		else R6
	local joints: { [string]: Joint } = {}
	local axes: { [string]: CFrame } = {}
	local parts: { [string]: BasePart } = {}
	for name, pair in names do
		for _, link in links do
			if link.parent.Name == pair[1] and link.part.Name == pair[2] then
				joints[name] = link.motor
				axes[name] = link.c0.Rotation
				parts[name] = link.part
				break
			end
		end
	end
	if joints.Root == nil then
		return nil
	end
	local rig: Rig = {
		root = root :: BasePart,
		joints = joints,
		axes = axes,
		parts = parts,
		links = links,
		restLow = 0,
	}
	rig.restLow = Avatar.lowest(rig, {})
	return rig
end

-- The lowest point of the rig's parts in the root's frame, with these Transforms (the rest pose where none).
function Avatar.lowest(rig: Rig, transforms: { [Joint]: CFrame }): number
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

-- Puts a turn given in the character's axes into each joint's own (an R15 joint's are the same; an R6 one's are not)
-- and writes it to `out` for that joint, when the rig has it.
local function setter(rig: Rig, out: { [Joint]: CFrame }): (string, CFrame) -> ()
	return function(name: string, frame: CFrame)
		local motor: Joint? = rig.joints[name]
		local axes: CFrame? = rig.axes[name]
		if motor ~= nil and axes ~= nil then
			out[motor] = axes:Inverse() * frame * axes
		end
	end
end

-- The waist, neck, shoulder and elbow Transforms for a pose, through `set(jointName, transform)`.
local function upper(set: (string, CFrame) -> (), pose: Pose)
	local rad = math.rad
	set("Waist", CFrame.Angles(rad(-pose.waist), 0, 0))
	set("Neck", CFrame.Angles(rad(pose.neck), 0, 0))
	set("LeftShoulder", CFrame.Angles(rad(pose.shL), rad(-pose.twL), rad(-pose.spL)))
	set("RightShoulder", CFrame.Angles(rad(pose.shR), rad(pose.twR), rad(pose.spR)))
	set("LeftElbow", CFrame.Angles(rad(pose.elL), 0, 0))
	set("RightElbow", CFrame.Angles(rad(pose.elR), 0, 0))
end

-- The Transforms that put the rig in `pose`, its lowest part `pose.air` studs above where its feet rest standing.
function Avatar.solve(rig: Rig, pose: Pose): { [Joint]: CFrame }
	local out: { [Joint]: CFrame } = {}
	local set = setter(rig, out)
	local rad = math.rad
	local turn = CFrame.Angles(rad(-pose.lean), 0, rad(-pose.roll))
	set("Root", turn)
	upper(set, pose)
	set("LeftHip", CFrame.Angles(rad(pose.hipL), 0, rad(-pose.lgL)))
	set("RightHip", CFrame.Angles(rad(pose.hipR), 0, rad(pose.lgR)))
	set("LeftKnee", CFrame.Angles(rad(-pose.knL), 0, 0))
	set("RightKnee", CFrame.Angles(rad(-pose.knR), 0, 0))
	-- Down (or up) so the lowest part sits `air` above the floor; the drop is along the root's up, in Root's C0 axes.
	local drop = rig.restLow + pose.air - Avatar.lowest(rig, out)
	local root = rig.joints.Root
	local axes = rig.axes.Root
	out[root] = CFrame.new(axes:Inverse() * Vector3.new(0, drop, 0)) * out[root]
	return out
end

-- The net hold's right arm (Presets.netHold): raised and bent so the forearm points ahead, the wrist kept straight
-- so the pole stays steady while the character walks. The rest of the body stays the character's own.
function Avatar.holdNet(rig: Rig): { [Joint]: CFrame }
	local h = Presets.netHold
	local rad = math.rad
	local out: { [Joint]: CFrame } = {}
	local set = setter(rig, out)
	if rig.joints.RightElbow ~= nil then
		set("RightShoulder", CFrame.Angles(rad(h.sh), rad(h.tw), rad(h.sp)))
		set("RightElbow", CFrame.Angles(rad(h.el), 0, 0))
		set("RightWrist", CFrame.identity)
	else
		set("RightShoulder", CFrame.Angles(rad(h.sh6), 0, rad(h.sp)))
	end
	return out
end

-- Whether a character holds its net: standing in a catching area (a World.Zones box other than the Cafe; nil is the
-- street), alive and with no cat in its arms (`CarryingCatId`).
function Avatar.holdsNet(zone: string?, carrying: unknown, alive: boolean): boolean
	return zone ~= nil and zone ~= "Cafe" and carrying == nil and alive
end

-- Which net model a player's `NetLevel` shows, 1 to 3: the Basic net (level 0) and the Sturdy net (1) share the
-- first, and a missing or odd value is the Basic net.
function Avatar.netModel(level: unknown): number
	local n = if type(level) == "number" and level == level then math.floor(level) else 0
	return math.clamp(n, 1, 3)
end

-- The hold's weight `dt` seconds on, easing towards 1 while it holds and 0 while it does not, over the blend times
-- of `blend` (Presets.netHold when not given).
function Avatar.holdWeight(
	weight: number,
	holding: boolean,
	dt: number,
	blend: { blendIn: number, blendOut: number }?
): number
	local h = blend or Presets.netHold
	if holding then
		return math.min(1, weight + dt / h.blendIn)
	end
	return math.max(0, weight - dt / h.blendOut)
end

-- The hand that holds the net (the RightHand on R15, the Right Arm on R6) and where the net's Grip goes in that
-- part's space: its RightGripAttachment's spot, or Presets.netHold's, with the pole tipped forward and the hoop
-- turned to open forward.
function Avatar.netHand(rig: Rig): (BasePart?, CFrame)
	local h = Presets.netHold
	local r15 = rig.joints.RightElbow ~= nil
	local hand: BasePart? = if r15 then rig.parts.RightWrist else rig.parts.RightShoulder
	if hand == nil then
		return nil, CFrame.identity
	end
	local attachment = hand:FindFirstChild("RightGripAttachment")
	local spot = if attachment ~= nil and attachment:IsA("Attachment")
		then (attachment :: Attachment).Position
		elseif r15 then h.grip
		else h.grip6
	return hand,
		CFrame.new(spot)
			* CFrame.Angles(math.rad(if r15 then h.tilt else h.tilt6), 0, 0)
			* CFrame.Angles(0, 0, math.rad(h.roll))
end

-- Whether a character carries a cat in its arms: a `CarryingCatId` (CatService sets it while the HeldCat is on) and
-- alive.
function Avatar.carrying(carryingCatId: unknown, alive: boolean): boolean
	return type(carryingCatId) == "string" and carryingCatId ~= "" and alive
end

-- The carry's upper body (Presets.carryPose): arms folded across the chest, the left forearm under the right, the
-- head tipped down to the cat; on R6, with no elbows, both arms reach forward and in. The hips, legs and root stay
-- the character's own, so it walks and stands as it would.
function Avatar.carryArms(rig: Rig): { [Joint]: CFrame }
	local c = Presets.carryPose
	local out: { [Joint]: CFrame } = {}
	upper(setter(rig, out), Avatar.pose(if rig.joints.LeftElbow ~= nil then c.arms else c.arms6))
	return out
end

-- Where a carried cat's floor goes (Pose.hold), from where the arms are this frame: on top of the higher forearm
-- (the whole arm on R6), halfway between the two, level with the chest's up, the cat's front towards the character's
-- left for a loaf (lying across the arms) and ahead for a sit (Presets.carryPose). `frameOf` gives a part's CFrame
-- (BasePart.CFrame in the game, the preview's own frames outside it). nil on a rig with no chest or arms.
function Avatar.cradle(rig: Rig, held: string, frameOf: (BasePart) -> CFrame): CFrame?
	local chest: BasePart? = rig.parts.Waist or rig.parts.Root -- the UpperTorso, or R6's Torso
	local leftArm: BasePart? = rig.parts.LeftElbow or rig.parts.LeftShoulder
	local rightArm: BasePart? = rig.parts.RightElbow or rig.parts.RightShoulder
	if chest == nil or leftArm == nil or rightArm == nil then
		return nil
	end
	local torso = frameOf(chest)
	local function top(arm: BasePart): Vector3
		local frame = torso:ToObjectSpace(frameOf(arm))
		local _, _, _, _, _, _, r10, r11, r12 = frame:GetComponents()
		local s = arm.Size
		return frame.Position
			+ Vector3.yAxis
				* 0.5
				* (math.abs(r10) * s.X + math.abs(r11) * s.Y + math.abs(r12) * s.Z)
	end
	local a, b = top(leftArm), top(rightArm)
	local c = Presets.carryPose
	local sit = held == "sit"
	local spot = Vector3.new(
		(a.X + b.X) / 2 + (if sit then c.sitSide else c.loafSide),
		math.max(a.Y, b.Y) + c.gap,
		(a.Z + b.Z) / 2 + c.forward
	)
	return torso
		* CFrame.new(spot)
		* CFrame.Angles(0, math.rad(if sit then c.sitTurn else c.loafTurn), 0)
end

-- The Cat Cannon flight's key poses (Presets.cannonPose), read once.
local cannonKeys: { [string]: Pose } = {}
local function cannonKey(name: string): Pose
	local pose = cannonKeys[name]
	if pose == nil then
		pose = Avatar.pose(Presets.cannonPose.poses[name])
		cannonKeys[name] = pose
	end
	return pose
end

-- Where the hop is, `k` (0 to 1) of the way through the air from `from` to the seat (the root's own frame): along
-- the line between the two, lifted in an arc hopHeight over the higher end, and how far it is still turned from the
-- barrel's heading, `yaw` radians at the start, the short way round.
local function hopPlace(from: Vector3, yaw: number, k: number): (Vector3, number)
	local lift = 4 * (Presets.cannonPose.hopHeight + math.abs(from.Y) / 2) * k * (1 - k)
	local turn = (yaw + math.pi) % (2 * math.pi) - math.pi
	return from:Lerp(Vector3.zero, k) + Vector3.new(0, lift, 0), turn * (1 - smooth(k))
end

-- The flight `seconds` after CannonLaunchAt: the pose; where the body is from the root (which the server holds at
-- the barrel's seat, then on the landing pad), in the root's frame; how far it is turned about the up axis from the
-- root's heading and how far it has rolled forward about its middle (radians); and how much of it shows, easing
-- back to the character's own animation after the landing. `from` and `fromYaw` are where the root stood just before
-- the launch and its heading, in the root's frame now (nil when this client never saw it: the hop starts at the
-- seat). Nil outside the flight. Plain numbers and vectors, so the tests run without CFrame.
function Avatar.flight(
	seconds: number,
	from: Vector3?,
	fromYaw: number?
): (Pose?, Vector3, number, number, number)
	local c = Presets.cannonPose
	if seconds < 0 or seconds >= c.ends + c.blendOut then
		return nil, Vector3.zero, 0, 0, 0
	end
	local ball = cannonKey("ball")
	local roll = 2 * math.pi * c.spin
	if seconds < c.hop then
		-- a crouch where it stood, then up into the barrel, curling into the ball on the way down
		local pose = through({
			{ at = 0, pose = STAND },
			{ at = c.hopCrouch, pose = cannonKey("hopCrouch") },
			{ at = c.hopCrouch + (c.hop - c.hopCrouch) * 0.3, pose = cannonKey("hopUp") },
			{ at = c.hop, pose = ball },
		}, seconds)
		local air = math.max(0, (seconds - c.hopCrouch) / (c.hop - c.hopCrouch))
		local at, yaw = hopPlace(from or Vector3.zero, fromYaw or 0, air)
		return pose, at, yaw, 0, 1
	end
	if seconds < c.boom then
		return Avatar.mix(ball, ball, 0), Vector3.zero, 0, 0, 1
	end
	if seconds < c.gone then
		-- out along the barrel, rising in a high arc and still climbing when it meets the cloud
		local t = seconds - c.boom
		local tilt = math.rad(c.tilt)
		local out = Vector3.new(0, math.sin(tilt), -math.cos(tilt)) * (c.speed * t)
			- Vector3.new(0, 0.5 * c.gravity * t * t, 0)
		return Avatar.mix(ball, ball, 0), out, 0, roll * t, 1
	end
	if seconds < c.drop then
		return Avatar.mix(ball, ball, 0), Vector3.new(0, c.hidden, 0), 0, 0, 1
	end
	if seconds < c.touch then
		-- falling faster and faster onto the pad, opening at the last moment and upright as its feet arrive
		local k = (seconds - c.drop) / (c.touch - c.drop)
		local open = smooth((seconds - (c.touch - c.open)) / c.open)
		return Avatar.mix(ball, cannonKey("land"), open),
			Vector3.new(0, c.dropHeight * (1 - (0.6 * k + 0.4 * k * k)), 0),
			0,
			roll * (seconds - c.touch),
			1
	end
	-- down into a crouch, deeper, a little bounce and up standing
	local span = c.ends - c.touch
	local pose = through({
		{ at = c.touch, pose = cannonKey("land") },
		{ at = c.touch + span * 0.25, pose = cannonKey("squash") },
		{ at = c.touch + span * 0.55, pose = cannonKey("bounce") },
		{ at = c.touch + span * 0.85, pose = cannonKey("settle") },
		{ at = c.ends, pose = STAND },
	}, seconds)
	local b = (seconds - (c.touch + span * 0.25)) / (span * 0.6)
	if b > 0 and b < 1 then
		pose.air += c.bounce * math.sin(math.pi * b)
	end
	local weight = if seconds <= c.ends then 1 else smooth(1 - (seconds - c.ends) / c.blendOut)
	return pose, Vector3.zero, 0, 0, weight
end

-- The middle of the rig's parts in the root's frame, with these Transforms: what the ball rolls about.
function Avatar.middle(rig: Rig, transforms: { [Joint]: CFrame }): Vector3
	local at: { [BasePart]: CFrame } = { [rig.root] = CFrame.identity }
	local sum, count = Vector3.zero, 0
	for _, link in rig.links do
		local frame = at[link.parent]
			* link.c0
			* (transforms[link.motor] or CFrame.identity)
			* link.c1
		at[link.part] = frame
		sum += frame.Position
		count += 1
	end
	return if count > 0 then sum / count else Vector3.zero
end

-- `pose`'s joint Transforms with the whole body moved from the root through the Root joint: to `at`, turned `yaw`
-- about the up axis, then rolled `roll` forward and banked `bank` towards its right about its middle (radians). Also
-- the body's middle, turned with it, in the root's frame.
local function moved(
	rig: Rig,
	pose: Pose,
	at: Vector3,
	yaw: number,
	roll: number,
	bank: number
): ({ [Joint]: CFrame }, CFrame)
	local out = Avatar.solve(rig, pose)
	local middle = Avatar.middle(rig, out)
	local centre = CFrame.new(at)
		* CFrame.Angles(0, yaw, 0)
		* CFrame.new(middle)
		* CFrame.Angles(-roll, 0, -bank)
	local root = rig.joints.Root
	for _, link in rig.links do
		if link.motor == root then
			local move = centre * CFrame.new(-middle)
			out[root] = link.c0:Inverse() * move * link.c0 * (out[root] or CFrame.identity)
			break
		end
	end
	return out, centre
end

-- The flight's joint Transforms `seconds` after CannonLaunchAt and how much of them shows (Avatar.flight): the pose,
-- with the whole body moved from the anchored root and rolled about its middle. Also where the body's middle is in
-- the root's frame, nil while it waits out of sight above the clouds. `from` is where the root stood before the
-- launch, in the root's frame now. Nil outside the flight.
function Avatar.cannon(
	rig: Rig,
	seconds: number,
	from: CFrame?
): ({ [Joint]: CFrame }?, number, CFrame?)
	local fromYaw = nil
	if from ~= nil then
		local look = from.LookVector
		fromYaw = math.atan2(-look.X, -look.Z)
	end
	local pose, at, yaw, roll, weight =
		Avatar.flight(seconds, if from ~= nil then from.Position else nil, fromYaw)
	if pose == nil then
		return nil, 0, nil
	end
	local out, centre = moved(rig, pose, at, yaw, roll, 0)
	local c = Presets.cannonPose
	local hidden = seconds >= c.gone and seconds < c.drop
	return out, weight, if hidden then nil else centre
end

-- The cloud cutscene's flyer `seconds` after CannonLaunchAt (Presets.cannonGlide), in its ViewportFrame's space: the
-- pose, where the body is, its heading, its forward roll and its bank (radians). Before the clouds it waits below the
-- frame as the ball; nil from cannonPose's `drop`, when the clouds part and the flyer is done.
function Avatar.glide(seconds: number): (Pose?, Vector3, number, number, number)
	local c = Presets.cannonPose
	local g = Presets.cannonGlide
	if seconds >= c.drop then
		return nil, Vector3.zero, 0, 0, 0
	end
	local s = math.max(seconds, c.gone)
	local ball, glide = cannonKey("ball"), cannonKey("spread")
	local heading = math.rad(g.heading)
	local roll = 2 * math.pi * c.spin
	local opened = c.gone + g.rise + g.open
	local tuck = c.drop - g.dive
	if s < opened then
		-- up into view still rolling, opening out flat as the roll comes round upright
		local up = smooth((s - c.gone) / g.rise)
		local open = smooth((s - (opened - g.open)) / g.open)
		return Avatar.mix(ball, glide, open),
			Vector3.new(0, -g.below * (1 - up), 0),
			heading,
			roll * (s - opened),
			0
	end
	local function sway(t: number): (number, number)
		return math.sin(2 * math.pi * g.bobHz * t) * g.bob,
			math.rad(g.bank) * math.sin(2 * math.pi * g.bankHz * t)
	end
	if s < tuck then
		local t = s - opened
		local pose = Avatar.mix(glide, glide, 0)
		local flutter = math.sin(2 * math.pi * g.flutterHz * t) * g.flutter
		pose.knL += flutter
		pose.knR -= flutter
		pose.hipL -= flutter * 0.4
		pose.hipR += flutter * 0.4
		local bob, bank = sway(t)
		return pose, Vector3.new(0, bob, 0), heading, 0, bank
	end
	-- tucked back into the ball and diving out of the bottom
	local k = (s - tuck) / g.dive
	local bob, bank = sway(tuck - opened)
	return Avatar.mix(glide, ball, smooth(k * 2)),
		Vector3.new(0, bob - g.below * k * k, 0),
		heading,
		roll * (s - tuck),
		bank * (1 - smooth(k))
end

-- The flyer's joint Transforms `seconds` after CannonLaunchAt (Avatar.glide), its root at the frame's origin; nil
-- once it is done.
function Avatar.glideFrames(rig: Rig, seconds: number): { [Joint]: CFrame }?
	local pose, at, yaw, roll, bank = Avatar.glide(seconds)
	if pose == nil then
		return nil
	end
	return (moved(rig, pose, at, yaw, roll, bank))
end

-- Every rig part's CFrame with these Transforms and the root at `root`, as the joints would put them: for a copy of
-- a character that nothing simulates (a ViewportFrame's).
function Avatar.partFrames(
	rig: Rig,
	transforms: { [Joint]: CFrame },
	root: CFrame
): { [BasePart]: CFrame }
	local at: { [BasePart]: CFrame } = { [rig.root] = root }
	for _, link in rig.links do
		at[link.part] = at[link.parent]
			* link.c0
			* (transforms[link.motor] or CFrame.identity)
			* link.c1
	end
	return at
end

return Avatar
