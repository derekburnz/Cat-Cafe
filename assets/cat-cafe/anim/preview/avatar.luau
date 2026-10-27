--!nocheck
-- Runs the game's Tackle poses (games/cat-cafe/src/client/Effects: Avatar and Presets, unchanged) on stand-in R15
-- characters outside Roblox and writes every part's CFrame and Size per frame to JSON for render.py, like dump.luau
-- does for the cats. The stand-in is the blocky R15 shape (Roblox's own Block body, about 5 studs tall) in the
-- palette's shirt and skin swatches; in the game the poses go on each player's own avatar. The engineer's motion
-- (the lunge, the knockback) is copied from the design's numbers: a straight move at a steady speed.
--
--   lune run avatar.luau <scenario> <out.json> [<Effects folder>/]
--
-- Scenarios: miss (a tackle with nobody ahead), hit (a tackle into a player facing it, who falls on its back),
-- behind (into a player facing away, who falls on its front). Nothing here ships with the game.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local CFrame, Vector3, Color3 = roblox.CFrame, roblox.Vector3, roblox.Color3

local scenarioName, outPath = process.args[1], process.args[2]
assert(scenarioName and outPath, "usage: lune run avatar.luau <scenario> <out.json>")
local HERE = string.match(process.cwd, "^(.-)/?$") .. "/"
local EFFECTS = process.args[3] or (HERE .. "../../../../games/cat-cafe/src/client/Effects/")

-- The stand-in characters are plain tables with the few instance members Avatar.bind reads (Name, IsA,
-- FindFirstChild, GetDescendants, Part0, Part1, C0, C1, Size): Roblox hands out one value per instance, which
-- Avatar keys tables by, while Lune makes a new value on every read.
local function node(className, name, props)
	local n = props or {}
	n.ClassName, n.Name, n.children = className, name, {}
	function n:IsA(class)
		return class == className or class == "Instance" or (class == "BasePart" and className == "Part")
	end
	function n:FindFirstChild(childName)
		for _, child in self.children do
			if child.Name == childName then
				return child
			end
		end
		return nil
	end
	function n:GetDescendants()
		local out = {}
		local function walk(at)
			for _, child in at.children do
				table.insert(out, child)
				walk(child)
			end
		end
		walk(self)
		return out
	end
	return n
end
local function parent(child, to)
	table.insert(to.children, child)
end

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

local function hex(s)
	return Color3.fromRGB(tonumber(s:sub(1, 2), 16), tonumber(s:sub(3, 4), 16), tonumber(s:sub(5, 6), 16))
end
local SKIN = { light = hex("F3C9A2"), tan = hex("C98E6A") }
local SHIRT = { red = hex("D9483B"), blue = hex("3C7DD9") }
local PANTS = hex("2F3E5C") -- pants_navy
local SHOES = hex("5E4634") -- dark_wood
local EYE = hex("2B211A")

-- A blocky R15 standing with its feet at y = 0 and its root at `at`, facing -Z: parts, then the Motor6Ds named and
-- placed the way a Roblox R15 character has them (each joint in the child part, C0 and C1 axis-aligned).
local function character(name, at, shirt, skin)
	local model = node("Model", name)
	local function part(partName, size, centre, colour)
		local p = node("Part", partName, { Size = size, CFrame = CFrame.new(centre), Color = colour })
		parent(p, model)
		return p
	end
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), SKIN.light)
	local parts = {
		LowerTorso = part("LowerTorso", Vector3.new(2, 0.4, 1), Vector3.new(0, 2.2, 0), PANTS),
		UpperTorso = part("UpperTorso", Vector3.new(2, 1.6, 1), Vector3.new(0, 3.2, 0), shirt),
		Head = part("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 4.6, 0), skin),
	}
	for side, x in { Left = -1.5, Right = 1.5 } do
		parts[side .. "UpperArm"] = part(side .. "UpperArm", Vector3.new(1, 1, 1), Vector3.new(x, 3.5, 0), shirt)
		parts[side .. "LowerArm"] = part(side .. "LowerArm", Vector3.new(1, 0.75, 1), Vector3.new(x, 2.625, 0), skin)
		parts[side .. "Hand"] = part(side .. "Hand", Vector3.new(1, 0.3, 1), Vector3.new(x, 2.1, 0), skin)
		local lx = x / 3
		parts[side .. "UpperLeg"] = part(side .. "UpperLeg", Vector3.new(1, 0.9, 1), Vector3.new(lx, 1.55, 0), PANTS)
		parts[side .. "LowerLeg"] = part(side .. "LowerLeg", Vector3.new(1, 0.8, 1), Vector3.new(lx, 0.7, 0), PANTS)
		parts[side .. "Foot"] = part(side .. "Foot", Vector3.new(1, 0.3, 1.1), Vector3.new(lx, 0.15, -0.05), SHOES)
	end
	local function joint(jointName, part0, part1, at)
		parent(
			node("Motor6D", jointName, {
				Part0 = part0,
				Part1 = part1,
				C0 = CFrame.new(at - part0.CFrame.Position),
				C1 = CFrame.new(at - part1.CFrame.Position),
			}),
			part1
		)
	end
	joint("Root", root, parts.LowerTorso, Vector3.new(0, 2.2, 0))
	joint("Waist", parts.LowerTorso, parts.UpperTorso, Vector3.new(0, 2.4, 0))
	joint("Neck", parts.UpperTorso, parts.Head, Vector3.new(0, 4.0, 0))
	for side, x in { Left = -1.5, Right = 1.5 } do
		local lx = x / 3
		joint(side .. "Shoulder", parts.UpperTorso, parts[side .. "UpperArm"], Vector3.new(x, 3.75, 0))
		joint(side .. "Elbow", parts[side .. "UpperArm"], parts[side .. "LowerArm"], Vector3.new(x, 3.0, 0))
		joint(side .. "Wrist", parts[side .. "LowerArm"], parts[side .. "Hand"], Vector3.new(x, 2.25, 0))
		joint(side .. "Hip", parts.LowerTorso, parts[side .. "UpperLeg"], Vector3.new(lx, 2.0, 0))
		joint(side .. "Knee", parts[side .. "UpperLeg"], parts[side .. "LowerLeg"], Vector3.new(lx, 1.1, 0))
		joint(side .. "Ankle", parts[side .. "LowerLeg"], parts[side .. "Foot"], Vector3.new(lx, 0.3, 0))
	end
	-- a face, so the front shows: two eyes riding the head
	local eyes = {}
	for _, x in { -0.28, 0.28 } do
		local e = part("Eye", Vector3.new(0.16, 0.3, 0.05), Vector3.new(x, 4.68, -0.61), EYE)
		table.insert(eyes, { part = e, offset = parts.Head.CFrame:Inverse() * e.CFrame })
	end
	local rig = Avatar.bind(model)
	assert(rig, "Avatar.bind found no R15 rig")
	return { model = model, rig = rig, root = at, head = parts.Head, eyes = eyes }
end

-- Every part's world CFrame for this root and these Transforms (Avatar.lowest's walk, kept).
local function place(c, rootCF, transforms)
	local at = { [c.rig.root] = CFrame.identity }
	local out = {}
	for _, link in c.rig.links do
		local frame = at[link.parent] * link.c0 * (transforms[link.motor] or CFrame.identity) * link.c1
		at[link.part] = frame
		out[link.part] = rootCF * frame
	end
	for _, eye in c.eyes do
		out[eye.part] = out[c.head] * eye.offset
	end
	return out
end

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
		box = { { -1, 0, -15 }, { 1, 5, 2 } },
		people = { { name = "Tackler", z = 0, face = 0, shirt = "red" } },
	},
	hit = {
		seconds = 2.4,
		camera = "profile",
		box = { { -1, 0, -21 }, { 1, 5, 2 } },
		people = {
			{ name = "Tackler", z = 0, face = 0, shirt = "red" },
			{ name = "Target", z = -9, face = 180, shirt = "blue", skin = "tan" },
		},
	},
	behind = {
		seconds = 2.4,
		camera = "profile",
		box = { { -1, 0, -21 }, { 1, 5, 2 } },
		people = {
			{ name = "Tackler", z = 0, face = 0, shirt = "red" },
			{ name = "Target", z = -9, face = 0, shirt = "blue", skin = "tan" },
		},
	},
}
local scenario = assert(scenarios[scenarioName], "no scenario " .. scenarioName)

local people = {}
for _, spec in scenario.people do
	local c = character(spec.name, nil, SHIRT[spec.shirt], SKIN[spec.skin or "light"])
	c.spec = spec
	c.pos = Vector3.new(0, 3, spec.z)
	c.yaw = math.rad(spec.face)
	c.times = {}
	table.insert(people, c)
end
local tackler, target = people[1], people[2]
tackler.times.tackleAt = PRESS

local fps = 24
local frames = {}
local info = {}
local order = {}
for _, c in people do
	for _, d in c.model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			table.insert(order, { c = c, part = d })
			local colour = d.Color
			table.insert(info, {
				name = c.spec.name .. "_" .. d.Name,
				shape = "Block",
				color = { colour.R, colour.G, colour.B },
				material = "SmoothPlastic",
				transparency = 0,
			})
		end
	end
end

local count = math.floor(scenario.seconds * fps + 0.5)
local hitAt = nil
for f = 0, count - 1 do
	local now = f / fps
	local dt = 1 / fps
	-- the engineer's motion: the lunge until it ends or hits, the target's push after a hit
	if now >= PRESS and now < PRESS + T.lunge and hitAt == nil then
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
	if target == nil and now >= PRESS + T.lunge + T.grace and tackler.times.missAt == nil then
		tackler.times.missAt = PRESS + T.lunge + T.grace
	end
	local frame = { t = now, pivot = { 0, 0, 0 }, parts = {} }
	local placed = {}
	for _, c in people do
		local pose, weight = Avatar.at(c.times, now, timing)
		local transforms = {}
		if pose ~= nil and weight > 0 then
			for motor, cf in Avatar.solve(c.rig, pose) do
				transforms[motor] = CFrame.identity:Lerp(cf, weight)
			end
		end
		placed[c] = place(c, CFrame.new(c.pos) * CFrame.Angles(0, c.yaw, 0), transforms)
	end
	for i, entry in order do
		local cf = placed[entry.c][entry.part]
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
		local s = entry.part.Size
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
