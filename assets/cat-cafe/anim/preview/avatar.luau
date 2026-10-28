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
-- does; the nets come from the rbxm that `rojo build preview.project.json` makes). Nothing here ships with the game.

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
	script = { Parent = setmetatable({}, { __index = function(_, name)
		return name
	end }) },
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
local scenario = assert(scenarios[scenarioName], "no scenario " .. scenarioName)

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
