--!nocheck
-- Runs the game's Tackle poses (games/cat-cafe/src/client/Effects: Avatar and Presets, unchanged) on stand-in R15
-- characters outside Roblox and writes every part's CFrame and Size per frame to JSON for render.py, like dump.luau
-- does for the cats. The stand-in (standin.luau) is the blocky R15 shape in the palette's shirt and skin swatches;
-- in the game the poses go on each player's own avatar. The engineer's motion (the lunge, the knockback) is copied
-- from the design's numbers: a straight move at a steady speed.
--
--   lune run avatar.luau <scenario> <out.json> [<Effects folder>/] [<assets.rbxm>]
--
-- Scenarios: miss (a tackle with nobody ahead), hit (a tackle into a player facing it, who falls on its back),
-- behind (into a player facing away, who falls on its front); net (three players holding the level 1, 2 and 3
-- nets, standing and then walking: Avatar.holdNet and Avatar.netHand, the net pivoted by its Grip as NetHold.luau
-- does; the nets come from the rbxm that `rojo build preview.project.json` makes). The Cat Cannon flight (F84):
-- cannon (the hop into a stand-in cannon and the shot out of it), cannonLand (the drop onto a stand-in pad and the
-- landing) and cannonGlide (the flyer of the cloud cutscene through its ViewportFrame's camera, white puffs standing
-- in for VFX-Agent's tunnel), with a sitting Tabby from the rbxm for scale where there is ground. Nothing here ships
-- with the game.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local CFrame, Vector3, Color3 = roblox.CFrame, roblox.Vector3, roblox.Color3

local scenarioName, outPath, rbxmPath = process.args[1], process.args[2], process.args[4]
assert(scenarioName and outPath, "usage: lune run avatar.luau <scenario> <out.json>")
local HERE = string.match(process.cwd, "^(.-)/?$") .. "/"
-- an empty Effects argument keeps the default, so the rbxm can follow it
local EFFECTS = if process.args[3] ~= nil and process.args[3] ~= ""
	then process.args[3]
	else HERE .. "../../../../games/cat-cafe/src/client/Effects/"

local modules = {}
local env
local function load(name)
	if modules[name] == nil then
		modules[name] = luau.load(fs.readFile(EFFECTS .. name .. ".luau"), { debugName = name, environment = env })()
	end
	return modules[name]
end
env = setmetatable({
	CFrame = CFrame,
	Vector3 = Vector3,
	Vector2 = roblox.Vector2,
	Color3 = Color3,
	ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	NumberRange = roblox.NumberRange,
	UDim2 = roblox.UDim2,
	Enum = roblox.Enum,
	script = { Parent = setmetatable({}, {
		__index = function(_, name)
			return name
		end,
	}) },
	require = load,
}, { __index = _G })
local Avatar = load("Avatar")
local Presets = load("Presets")

local Standin = luau.load(fs.readFile(HERE .. "standin.luau"), { debugName = "standin" })()(roblox, Avatar)
local character, place = Standin.character, Standin.place

local T = Presets.tacklePose
local LUNGE_SPEED = 12 / T.lunge -- TackleLungeStuds in TackleLungeSeconds
local PUSH_SPEED = 10 / T.push -- ShoveKnockbackStuds in the push
local timing = {
	lunge = T.lunge,
	grace = T.grace,
	hitRecover = T.hitRecover,
	missRecover = T.missRecover,
	push = T.push,
	down = T.down,
}

-- Each scenario: the characters and their start, the press time and, for a hit, who is hit.
local PRESS = 0.5
local scenarios = {
	miss = {
		seconds = 3.2,
		camera = "profile",
		box = { { -1, 0, -17.5 }, { 1, 5, 2.5 } }, -- the outstretched arms reach about 16.4 studs out
		people = { { name = "Tackler", z = 0, face = 0, shirt = "red" } },
	},
	hit = {
		seconds = 2.4,
		camera = "profile",
		box = { { -1, 0, -23.5 }, { 1, 5, 2.5 } },
		people = {
			{ name = "Tackler", z = 0, face = 0, shirt = "red" },
			{ name = "Target", z = -9, face = 180, shirt = "blue", skin = "tan" },
		},
	},
	behind = {
		seconds = 2.4,
		camera = "profile",
		box = { { -1, 0, -23.5 }, { 1, 5, 2.5 } },
		people = {
			{ name = "Tackler", z = 0, face = 0, shirt = "red" },
			{ name = "Target", z = -9, face = 0, shirt = "blue", skin = "tan" },
		},
	},
	-- standing `still` seconds, then walking at the default 16 studs a second; the camera follows
	net = {
		seconds = 4,
		still = 1.5,
		speed = 16,
		camera = "three",
		box = { { -7, 0, -3 }, { 7, 9, 2 } },
		people = {
			{ name = "Basic", x = -5, z = 0, face = 0, shirt = "red", net = 1 },
			{ name = "Pro", x = 0, z = 0, face = 0, shirt = "blue", skin = "tan", net = 2 },
			{ name = "Master", x = 5, z = 0, face = 0, shirt = "red", net = 3 },
		},
	},
}
-- The flight scenarios: `from` and `to` are seconds from CannonLaunchAt, played at `slow` times real speed; `seat`
-- is where the server holds the root (the barrel's seat, or the landing pad), `stand` where the player stood before.
scenarios.cannon = {
	flight = true,
	from = -0.3,
	to = 1.0,
	slow = 0.5,
	camera = "profile",
	box = { { -7, 0, -9 }, { 7, 13, 9 } },
	seat = { 0, 4.5, 0 },
	stand = { 0, 3, 7 },
	cat = { -4, 0, 6, 210 },
	props = "cannon",
}
scenarios.cannonLand = {
	flight = true,
	from = 2.3,
	to = 3.3,
	slow = 0.5,
	camera = "three",
	box = { { -4, 0, -4 }, { 4, 8, 4 } },
	seat = { 0, 3.25, 0 },
	cat = { 5, 0.25, -2, 230 },
	props = "pad",
}
scenarios.cannonGlide = { flight = true, glide = true, from = 1.35, to = 2.45, slow = 1 }
local scenario = assert(scenarios[scenarioName], "no scenario " .. scenarioName)

if scenario.flight then
	local fps = 24
	local c = Presets.cannonPose
	local person = character("Player", Standin.SHIRT.red, Standin.SKIN.light)
	local seat = if scenario.seat then CFrame.new(table.unpack(scenario.seat)) else CFrame.identity
	local stood = if scenario.stand then CFrame.new(table.unpack(scenario.stand)) else seat
	local info, order = Standin.partInfo(person, "Player")
	local still = {} -- parts that do not move: { cf, size }
	local moving = {} -- the stand-in clouds: { at, size, speed }
	local function add(name, shape, colour, cf, size, transparency)
		table.insert(info, {
			name = name,
			shape = shape,
			color = { colour.R, colour.G, colour.B },
			material = "SmoothPlastic",
			transparency = transparency or 0,
		})
		table.insert(still, { cf = cf, size = size })
	end
	local cream, teal, gold = Color3.fromRGB(255, 244, 228), Color3.fromRGB(64, 160, 160), Color3.fromRGB(230, 184, 74)
	if scenario.props == "cannon" then
		-- a stand-in for CatCafe_Square_Cannon: the plinth, a turntable and the barrel 50 degrees up, its breech round
		-- the ball where the seat holds it
		local up = CFrame.Angles(0, 0, math.rad(90))
		add("Plinth", "Cylinder", cream, CFrame.new(0, 0.75, 0) * up, Vector3.new(1.5, 12, 12))
		add("Turntable", "Cylinder", teal, CFrame.new(0, 1.7, 0.5) * up, Vector3.new(0.4, 6, 6))
		local tilt = math.rad(c.tilt)
		local axis = Vector3.new(0, math.sin(tilt), -math.cos(tilt))
		local middle = seat.Position + Vector3.new(0, -1.7, -0.3)
		local along = CFrame.lookAt(Vector3.zero, axis) * CFrame.Angles(0, math.rad(90), 0)
		local function along3(at)
			return CFrame.new(middle + axis * at) * along
		end
		add("Barrel", "Cylinder", teal, along3(3.4), Vector3.new(10, 3.9, 3.9), 0.55)
		add("Band1", "Cylinder", gold, along3(-1.2), Vector3.new(0.5, 4.2, 4.2), 0.3)
		add("Band2", "Cylinder", gold, along3(8.1), Vector3.new(0.6, 4.4, 4.4))
		add("Steps", "Block", cream, CFrame.new(0, 0.4, 6.8), Vector3.new(4, 0.8, 2))
	elseif scenario.props == "pad" then
		add(
			"Pad",
			"Cylinder",
			cream,
			CFrame.new(0, 0.125, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Vector3.new(0.25, 16, 16)
		)
		add(
			"PadPaw",
			"Cylinder",
			teal,
			CFrame.new(0, 0.26, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Vector3.new(0.05, 5, 5)
		)
	end
	if scenario.cat then
		assert(rbxmPath, "the cannon scenarios need the assets rbxm for the Tabby")
		local folder = roblox.deserializeModel(fs.readFile(rbxmPath))[1]
		local cat = assert(folder:FindFirstChild("CatCafe_Cat_Tabby_Sit"), "no CatCafe_Cat_Tabby_Sit")
		local primary = cat.PrimaryPart -- the model's pivot, as dump.luau reads it
		local pivot = if primary then primary.CFrame * primary.PivotOffset else CFrame.identity
		local x, y, z, turn = table.unpack(scenario.cat)
		local place = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(turn), 0)
		for _, d in cat:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 1 then
				local mesh = d:FindFirstChildWhichIsA("SpecialMesh")
				local sphere = mesh and mesh.MeshType.Name == "Sphere"
				local shape = if sphere then "Ellipsoid" elseif d.ClassName == "Part" then d.Shape.Name else "Block"
				add(
					"Cat_" .. d.Name,
					shape,
					d.Color,
					place * pivot:Inverse() * d.CFrame,
					if sphere then d.Size * mesh.Scale else d.Size,
					d.Transparency
				)
			end
		end
	end
	if scenario.glide then
		-- puffs rushing past the camera, as VFX-Agent's tunnel will
		local seed = 7
		local rng = {}
		function rng:NextNumber(lo, hi) -- a fixed sequence, so every render has the same sky
			seed = (seed * 1103515245 + 12345) % 2147483648
			return lo + (hi - lo) * seed / 2147483648
		end
		for i = 1, 26 do
			local size = rng:NextNumber(4, 9)
			table.insert(info, {
				name = "Cloud" .. i,
				shape = "Ellipsoid",
				color = { 1, 1, 1 },
				material = "SmoothPlastic",
				transparency = 0.15,
			})
			local angle = rng:NextNumber(0, 2 * math.pi)
			local r = rng:NextNumber(6, 14)
			table.insert(moving, {
				at = Vector3.new(math.cos(angle) * r * 1.4, math.sin(angle) * r - 1, rng:NextNumber(-60, 10)),
				size = Vector3.new(size * 1.6, size, size * 1.2),
				speed = rng:NextNumber(70, 100),
			})
		end
	end

	local frames = {}
	local count = math.floor((scenario.to - scenario.from) / scenario.slow * fps + 0.5)
	for f = 0, count - 1 do
		local t = scenario.from + f / fps * scenario.slow
		local transforms, rootCF = {}, seat
		if scenario.glide then
			transforms, rootCF = Avatar.glideFrames(person.rig, t) or {}, CFrame.identity
		elseif t < 0 then
			rootCF = stood -- standing where it will hop from, before the launch
		else
			local out, weight = Avatar.cannon(person.rig, t, if scenario.stand then seat:Inverse() * stood else nil)
			for motor, cf in out or {} do
				transforms[motor] = CFrame.identity:Lerp(cf, weight)
			end
		end
		local partsAt = place(person, rootCF, transforms)
		local frame = { t = t, pivot = { 0, 0, 0 }, parts = {} }
		local function put(cf, size)
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
			table.insert(
				frame.parts,
				{ cf = { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 }, size = { size.X, size.Y, size.Z } }
			)
		end
		for _, part in order do
			put(partsAt[part], part.Size)
		end
		for _, piece in still do
			put(piece.cf, piece.size)
		end
		for _, cloud in moving do
			local z = (cloud.at.Z + cloud.speed * (t - scenario.from) + 60) % 75 - 60
			put(CFrame.new(cloud.at.X, cloud.at.Y, z), cloud.size)
		end
		table.insert(frames, frame)
	end
	local g = Presets.cannonGlide
	fs.writeFile(
		outPath,
		serde.encode("json", {
			model = scenarioName,
			fps = fps,
			camera = scenario.camera,
			parts = info,
			frames = frames,
			box = scenario.box,
			checker = not scenario.glide,
			sky = if scenario.glide then { 0.62, 0.8, 0.95 } else nil,
			cam = if scenario.glide
				then {
					at = { g.camera.X, g.camera.Y, g.camera.Z },
					look = { g.look.X, g.look.Y, g.look.Z },
					fov = g.fov,
				}
				else nil,
		})
	)
	print(string.format("%s: %d frames of %d parts -> %s", scenarioName, #frames, #info, outPath))
	return
end

local people = {}
for _, spec in scenario.people do
	local c = character(spec.name, Standin.SHIRT[spec.shirt], Standin.SKIN[spec.skin or "light"])
	c.spec = spec
	c.pos = Vector3.new(spec.x or 0, 3, spec.z)
	c.yaw = math.rad(spec.face)
	c.times = {}
	table.insert(people, c)
end
local tackler, target = people[1], people[2]
if scenario.still == nil then
	tackler.times.tackleAt = PRESS
end

-- A held net: the level's model from the rbxm, each visible part kept as its frame from the net's Grip, so it can be
-- put in the hand as NetHold.luau pivots it there.
local function netParts(level)
	assert(rbxmPath, "the net scenario needs the assets rbxm (rojo build preview.project.json)")
	local folder = roblox.deserializeModel(fs.readFile(rbxmPath))[1]
	local net = assert(folder:FindFirstChild("CatCafe_Item_Net_L" .. level), "no net L" .. level)
	local grip = assert(net:FindFirstChild("Grip", true), "net L" .. level .. " has no Grip")
	local gripWorld = grip.Parent.CFrame * grip.CFrame
	local out = {}
	for _, d in net:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local colour = d.Color
			table.insert(out, {
				part = d,
				offset = gripWorld:Inverse() * d.CFrame,
				info = {
					name = "Net_" .. d.Name,
					shape = if d.ClassName == "Part" then d.Shape.Name else "Block",
					color = { colour.R, colour.G, colour.B },
					material = d.Material.Name,
					transparency = d.Transparency,
				},
			})
		end
	end
	return out
end
for _, c in people do
	if c.spec.net then
		c.net = netParts(c.spec.net)
	end
end

local fps = 24
local frames = {}
local info = {}
local order = {}
for _, c in people do
	local partInfo, partOrder = Standin.partInfo(c, c.spec.name)
	for i, entry in partInfo do
		table.insert(info, entry)
		table.insert(order, { c = c, part = partOrder[i] })
	end
	for _, piece in c.net or {} do
		table.insert(info, piece.info)
		table.insert(order, { c = c, net = piece })
	end
end
local travelled = Vector3.zero

local count = math.floor(scenario.seconds * fps + 0.5)
local hitAt = nil
for f = 0, count - 1 do
	local now = f / fps
	local dt = 1 / fps
	-- the engineer's motion: the lunge until it ends or hits, the target's push after a hit
	if scenario.still == nil and now >= PRESS and now < PRESS + T.lunge and hitAt == nil then
		tackler.pos += Vector3.new(0, 0, -LUNGE_SPEED * dt)
		if target ~= nil and (target.pos - tackler.pos).Magnitude <= 3 then
			hitAt = now
			tackler.times.hitAt = now
			target.times.shovedAt = now
			local push = (target.pos - tackler.pos).Unit
			target.push = push
			local facing = CFrame.Angles(0, target.yaw, 0)
			local mine = facing:VectorToObjectSpace(push)
			target.times.fallForward = -mine.Z > 0.3
			target.times.side = mine.X
		end
	end
	if target ~= nil and hitAt ~= nil and now >= hitAt and now < hitAt + T.push then
		target.pos += target.push * PUSH_SPEED * dt
	end
	if scenario.still == nil and target == nil and now >= PRESS + T.lunge + T.grace and tackler.times.missAt == nil then
		tackler.times.missAt = PRESS + T.lunge + T.grace
	end
	local speed = if scenario.still ~= nil and now >= scenario.still then scenario.speed else 0
	travelled += Vector3.new(0, 0, -speed * dt)
	local frame = { t = now, pivot = { travelled.X, travelled.Y, travelled.Z }, parts = {} }
	local placed = {}
	for _, c in people do
		local pose, weight = Avatar.at(c.times, now, timing)
		local transforms = {}
		if pose ~= nil and weight > 0 then
			for motor, cf in Avatar.solve(c.rig, pose) do
				transforms[motor] = CFrame.identity:Lerp(cf, weight)
			end
		end
		if c.net then
			-- a walk as the Animator would play it (the preview has no copy of it): legs and the free arm swinging
			-- with the distance covered, then the hold's arm over it
			c.stride = (c.stride or 0) + speed * dt / 4.5
			local swing = math.sin(c.stride * 2 * math.pi) * math.rad(28) * math.min(speed / 8, 1)
			local joints = c.rig.joints
			transforms[joints.LeftHip] = CFrame.Angles(swing, 0, 0)
			transforms[joints.RightHip] = CFrame.Angles(-swing, 0, 0)
			transforms[joints.LeftKnee] = CFrame.Angles(-math.max(0, -swing) * 1.2, 0, 0)
			transforms[joints.RightKnee] = CFrame.Angles(-math.max(0, swing) * 1.2, 0, 0)
			transforms[joints.LeftShoulder] = CFrame.Angles(-swing * 0.8, 0, 0)
			for motor, cf in Avatar.holdNet(c.rig) do
				transforms[motor] = cf
			end
		end
		local partsAt = place(c, CFrame.new(c.pos + travelled) * CFrame.Angles(0, c.yaw, 0), transforms)
		if c.net then
			local hand, grip = Avatar.netHand(c.rig)
			local gripAt = partsAt[hand] * grip
			for _, piece in c.net do
				partsAt[piece] = gripAt * piece.offset
			end
		end
		placed[c] = partsAt
	end
	for i, entry in order do
		local cf = placed[entry.c][entry.net or entry.part]
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
		local s = (entry.net and entry.net.part or entry.part).Size
		frame.parts[i] = { cf = { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 }, size = { s.X, s.Y, s.Z } }
	end
	table.insert(frames, frame)
end

fs.writeFile(
	outPath,
	serde.encode("json", {
		model = scenarioName,
		fps = fps,
		camera = scenario.camera,
		parts = info,
		frames = frames,
		-- frame the whole run, not just the first frame, and show the floor's squares
		box = scenario.box,
		checker = true,
	})
)
print(string.format("%s: %d frames of %d parts -> %s", scenarioName, #frames, #info, outPath))
