--!nocheck
-- Runs the game's own cat motion (games/cat-cafe/src/client/Effects: Logic, Presets and Pose, unchanged) on
-- the Part cats in assets/cat-cafe/rbx outside Roblox, and writes every part's CFrame and Size per frame to JSON
-- for render.py. Lune (https://lune-org.github.io) supplies Roblox's CFrame, Vector3 and Instance types; the few
-- engine calls Pose needs and Lune lacks (GetPivot, GetScale, BulkMoveTo, os.clock) are filled in below.
--
--   lune run dump.luau <cats.rbxm> <scenario name> <out.json> [<Effects folder>/]
--
-- Scenarios live in scenarios.luau. A scenario with a `carrier` puts the cat in the arms of the stand-in player
-- (standin.luau) in the carry pose (Effects/Avatar: Avatar.carryArms, Avatar.cradle) as Carry.luau does, with its
-- legs swinging the way the character's own walk would while a segment moves. Nothing here ships with the game.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local CFrame, Vector3 = roblox.CFrame, roblox.Vector3

local args = process.args
local rbxmPath, scenarioName, outPath = args[1], args[2], args[3]
assert(
	rbxmPath and scenarioName and outPath,
	"usage: lune run dump.luau <cats.rbxm> <scenario> <out.json>"
)

local HERE = string.match(process.cwd, "^(.-)/?$") .. "/"
-- A fifth argument plays another copy of the Effects folder instead, such as main's, for a before and after.
local EFFECTS = args[4] or (HERE .. "../../../../games/cat-cafe/src/client/Effects/")

-- The engine bits Pose calls that Lune has no copy of.
roblox.implementMethod("BasePart", "GetPivot", function(self)
	return self.CFrame * self.PivotOffset
end)
roblox.implementMethod("Model", "GetPivot", function(self)
	local primary = self.PrimaryPart
	return if primary then primary.CFrame * primary.PivotOffset else CFrame.identity
end)
roblox.implementMethod("Model", "GetScale", function()
	return 1
end)

local clock = 0
local workspace = {
	BulkMoveTo = function(_, parts, frames)
		for i, part in parts do
			part.CFrame = frames[i]
		end
	end,
	GetServerTimeNow = function()
		return clock
	end,
}
local game = {
	GetService = function(_, name)
		assert(name == "Workspace", "the preview only fakes Workspace, not " .. name)
		return workspace
	end,
}

-- Effects modules, loaded from their files with `script.Parent.X` pointing at each other.
local modules = {}
local parent = {}
local env
local function load(name)
	if modules[name] == nil then
		local source = fs.readFile(EFFECTS .. name .. ".luau")
		modules[name] = luau.load(source, { debugName = name, environment = env })()
	end
	return modules[name]
end
setmetatable(parent, {
	__index = function(_, name)
		return name
	end,
})
env = setmetatable({
	CFrame = CFrame,
	Vector3 = Vector3,
	Vector2 = roblox.Vector2,
	Color3 = roblox.Color3,
	ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	NumberRange = roblox.NumberRange,
	UDim2 = roblox.UDim2,
	Enum = roblox.Enum,
	game = game,
	script = { Parent = parent },
	require = load,
	os = {
		clock = function()
			return clock
		end,
		time = os.time,
	},
}, { __index = _G })

local Logic = load("Logic")
local Pose = load("Pose")

local scenarios = luau.load(
	fs.readFile(HERE .. "scenarios.luau"),
	{ debugName = "scenarios", environment = env }
)()
local scenario = scenarios[scenarioName]
assert(scenario, "no scenario " .. scenarioName)

local folder = roblox.deserializeModel(fs.readFile(rbxmPath))[1]
local model = folder:FindFirstChild(scenario.model)
assert(model, "no model " .. scenario.model)
for key, value in scenario.attributes or {} do
	model:SetAttribute(key, value)
end

-- A working cat in its role's outfit, put on the way the server's CatPose.dress does it: each piece's model pivoted
-- onto the cat's Outfit_<Piece> attachment, its parts following the Head or the Body. Pieces as Catalog.roleOutfits.
local ROLE_OUTFITS = {
	barista = { "Apron", "BaristaCap" },
	waiter = { "BowTie", "Vest" },
	greeter = { "Sash", "Boater" },
	entertainer = { "PartyHat", "Cape" },
}
local function pivotTo(piece, target)
	local move = target * piece:GetPivot():Inverse()
	for _, descendant in piece:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CFrame = move * descendant.CFrame
		end
	end
end
if scenario.role then
	local head = nil
	for _, child in model:GetChildren() do
		if child:IsA("Model") and string.sub(child.Name, -5) == "_Head" then
			head = child
		end
	end
	for _, pieceName in assert(ROLE_OUTFITS[scenario.role], "no outfit for " .. scenario.role) do
		local slot = model:FindFirstChild("Outfit_" .. pieceName, true)
		local asset = folder:FindFirstChild("CatCafe_Accessory_" .. pieceName)
		if slot and asset then
			local piece = asset:Clone()
			pivotTo(piece, slot.Parent.CFrame * slot.CFrame) -- the attachment's WorldCFrame
			local follows = if head and slot:IsDescendantOf(head) then "Head" else "Body"
			for _, descendant in piece:GetDescendants() do
				if descendant:IsA("BasePart") then
					descendant:SetAttribute("Follows", follows)
				end
			end
			piece.Parent = model
		end
	end
end

-- A stuck cat. A scenario's `trap` names a rescue prop: the prop with its pivot at the origin and the cat where the
-- server pivots it, Layout.stuckPoses[prop], read from Layout.luau itself so the two cannot drift apart. A
-- `trapSet` is a trap built into an area set instead (Layout's setTrap): `set` names the set, `spot` is the trap spot
-- in set space with the piece's turn as a fourth number, as in Layout, and the set's parts whose centres lie within
-- `radius` studs of it are drawn. Everything is seen from the spot's ground under it, turned by the piece, so the
-- cat sits at (0, y, 0) * pose, the pose the server would put at the spot. `stuckAt` tries a new pose instead, 12
-- numbers as in Layout.stuckPoses. The trap's parts follow the cat's in the JSON and never move.
local propParts = {}
if scenario.trap or scenario.trapSet then
	local numbers = scenario.stuckAt
	local trapSet = scenario.trapSet
	if trapSet then
		local set = folder:FindFirstChild(trapSet.set)
		assert(set, "no set " .. trapSet.set)
		local spot = trapSet.spot
		local ground = CFrame.new(spot[1], 0, spot[3]) * CFrame.Angles(0, math.rad(spot[4] or 0), 0)
		local toGround = ground:Inverse()
		local centre = Vector3.new(spot[1], spot[2], spot[3])
		for _, descendant in set:GetDescendants() do
			if descendant:IsA("BasePart") and descendant.Transparency < 1 then
				if (descendant.CFrame.Position - centre).Magnitude <= (trapSet.radius or 6) then
					descendant.CFrame = toGround * descendant.CFrame
					table.insert(propParts, descendant)
				end
			end
		end
		assert(numbers, "a trapSet scenario needs its stuckAt")
		pivotTo(model, CFrame.new(0, spot[2], 0) * CFrame.new(table.unpack(numbers)))
	else
		local prop = folder:FindFirstChild(scenario.trap)
		assert(prop, "no prop " .. scenario.trap)
		if numbers == nil then
			local layout =
				fs.readFile(HERE .. "../../../../games/cat-cafe/src/server/World/Layout.luau")
			local list = string.match(layout, "\n%s*" .. scenario.trap .. " = {([^}]*)}")
			assert(list, "no stuck pose for " .. scenario.trap .. " in Layout.stuckPoses")
			numbers = {}
			for number in string.gmatch(list, "[-%d%.]+") do
				table.insert(numbers, tonumber(number))
			end
		end
		pivotTo(prop, CFrame.identity)
		pivotTo(model, CFrame.new(table.unpack(numbers)))
		for _, descendant in prop:GetDescendants() do
			if descendant:IsA("BasePart") and descendant.Transparency < 1 then
				table.insert(propParts, descendant)
			end
		end
	end
end

-- Every part, with what render.py needs to draw it.
local parts = {}
for _, descendant in model:GetDescendants() do
	if descendant:IsA("BasePart") then
		table.insert(parts, descendant)
	end
end
-- A sphere mesh (a bush, a bin bag, a blossom) draws as an ellipsoid of the part's size times the mesh's Scale.
local function sphereMesh(part)
	local mesh = part:FindFirstChildWhichIsA("SpecialMesh")
	return if mesh and mesh.MeshType.Name == "Sphere" then mesh else nil
end
local function sizeOf(part)
	local mesh = sphereMesh(part)
	local size = if mesh then part.Size * mesh.Scale else part.Size
	return { size.X, size.Y, size.Z }
end
local function shapeOf(part)
	if sphereMesh(part) then
		return "Ellipsoid"
	elseif part.ClassName == "WedgePart" then
		return "Wedge"
	elseif part.ClassName == "Part" then
		return part.Shape.Name
	end
	return "Block"
end
local function cframeList(c)
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = c:GetComponents()
	return { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 }
end
local info = {}
for i, part in parts do
	local color = part.Color
	info[i] = {
		name = part.Name,
		shape = shapeOf(part),
		color = { color.R, color.G, color.B },
		material = part.Material.Name,
		transparency = part.Transparency,
	}
end
for _, part in propParts do
	local color = part.Color
	table.insert(info, {
		name = "Prop_" .. part.Name,
		shape = shapeOf(part),
		color = { color.R, color.G, color.B },
		material = part.Material.Name,
		transparency = part.Transparency,
	})
end

-- What the server would be doing: where it has each part. A walking scenario moves them all each frame.
local server = {}
for i, part in parts do
	server[i] = part.CFrame
	part.Position = part.CFrame.Position -- Lune keeps Position apart from CFrame; Pose reads it only at bind
end

local rig = Pose.bind(model)
assert(rig, "Pose.bind found no body")

-- The carrier: the stand-in player holding the cat on its folded arms, its parts after the cat's in the JSON.
local carrier = nil
if scenario.carrier then
	local Avatar = load("Avatar")
	local Standin =
		luau.load(fs.readFile(HERE .. "standin.luau"), { debugName = "standin" })()(roblox, Avatar)
	local spec = scenario.carrier
	local c = Standin.character(
		"Carrier",
		Standin.SHIRT[spec.shirt or "red"],
		Standin.SKIN[spec.skin or "light"]
	)
	local carrierInfo, carrierOrder = Standin.partInfo(c, "Carrier")
	for _, entry in carrierInfo do
		table.insert(info, entry)
	end
	carrier = { c = c, order = carrierOrder, Avatar = Avatar, Standin = Standin, stride = 0 }
end

-- The z's hang off the first part named like the head, as Cats.luau's partNamed finds it.
local zOn = nil
for i, part in parts do
	if string.sub(part.Name, -5) == "_Head" or part.Name == "Head" then
		zOn = i
		break
	end
end
local Z_STYLES = { nap = true, doze = true }

-- The same composition as Effects/Cats.luau's step: the style's idle, a settle from the last style, the gait,
-- the Balloon Cat's float (a scenario's `attributes.CatId` in motion.float.cats), the stretch (where a segment says
-- `stretch = true`, as when the server sets a stray's StretchAt). Older Effects folders without a function here
-- just skip it.
local Presets = modules.Presets
local catId = model:GetAttribute("CatId")
local floats = Logic.float ~= nil
	and type(catId) == "string"
	and Presets.motion.float.cats[catId] == true
local fps = scenario.fps or 24
local frames = {}
local style, from, changedAt = nil, nil, 0
local settleFor = Presets.motion.settle
local stretchAt = nil
local segmentStart = 0
local travelled = Vector3.zero
for _, segment in scenario.segments do
	local count = math.floor(segment.seconds * fps + 0.5)
	for f = 0, count - 1 do
		clock = segmentStart + f / fps
		if segment.style ~= style then
			if Logic.settleSeconds then
				settleFor = Logic.settleSeconds(style, segment.style)
			end
			from = style
			style = segment.style
			changedAt = clock
		end
		if segment.stretch and f == 0 then
			stretchAt = clock
		end
		local speed = segment.speed or 0
		if speed > 0 and carrier ~= nil then
			travelled += Vector3.new(0, 0, -speed / fps) -- the carrier walks; the cat rides its arms
		elseif speed > 0 then
			local step = Vector3.new(0, 0, -speed / fps) -- the cat faces -Z
			travelled += step
			for i, part in parts do
				server[i] = CFrame.new(step) * server[i]
				part.CFrame = server[i]
			end
		end
		Pose.read(rig)
		local t = clock + (scenario.phase or 0)
		local o = Logic.idle(style, t, rig.kind)
		local float = if floats then Logic.floatShare(style) else 0
		if from ~= nil then
			local k = (clock - changedAt) / settleFor
			if k >= 1 then
				from = nil
			else
				local eased = k * k * (3 - 2 * k)
				o = Logic.mix(Logic.idle(from, t, rig.kind), o, eased)
				if floats then
					local was = Logic.floatShare(from)
					float = was + (float - was) * eased
				end
			end
		end
		Logic.gait(o, rig.speed, rig.stride)
		if floats then
			Logic.float(o, t, float * (1 - Logic.runFactor(rig.speed)))
		end
		if stretchAt ~= nil and Logic.stretch then
			local alpha = (clock - stretchAt) / Presets.motion.stretch.seconds
			if alpha >= 1 then
				stretchAt = nil
			elseif alpha >= 0 then
				Logic.stretch(o, alpha, rig.kind)
			end
		end
		local placedCarrier = nil
		if carrier ~= nil then
			-- the carry's arms over the character's own walk: legs swinging with the distance covered, as a walk
			-- animation would (a stand-in for the Animator, which the preview has no copy of)
			local Avatar = carrier.Avatar
			local transforms = Avatar.carryArms(carrier.c.rig)
			carrier.stride += speed / fps / 4.5
			local swing = math.sin(carrier.stride * 2 * math.pi)
				* math.rad(28)
				* math.min(speed / 8, 1)
			local joints = carrier.c.rig.joints
			transforms[joints.LeftHip] = CFrame.Angles(swing, 0, 0)
			transforms[joints.RightHip] = CFrame.Angles(-swing, 0, 0)
			transforms[joints.LeftKnee] = CFrame.Angles(-math.max(0, -swing) * 1.2, 0, 0)
			transforms[joints.RightKnee] = CFrame.Angles(-math.max(0, swing) * 1.2, 0, 0)
			local placed = carrier.Standin.place(
				carrier.c,
				CFrame.new(travelled + Vector3.new(0, 3, 0)),
				transforms
			)
			placedCarrier = placed
			local hold = if rig.kind == "sit" then "sit" else "loaf"
			Pose.hold(
				rig,
				Avatar.cradle(carrier.c.rig, hold, function(part)
					return placed[part]
				end)
			)
		end
		Pose.draw(rig, o, -1)
		local frame = {
			t = clock,
			style = style,
			pivot = { travelled.X, travelled.Y, travelled.Z },
			parts = {},
		}
		if Z_STYLES[style] and Logic.napZ ~= nil then
			-- the same calls Cats.luau's animateNaps makes for each label
			local nap = Presets.nap
			frame.zs = {}
			for i = 1, nap.labels do
				local x, y, size, fade, tilt =
					Logic.napZ(i, nap.labels, t, Logic.breathSeconds(style))
				frame.zs[i] = {
					x = x,
					y = y,
					size = size,
					fade = fade,
					tilt = tilt,
					text = if i == nap.labels then "Z" else "z",
				}
			end
		elseif Z_STYLES[style] then
			-- an older Effects folder (before the breath and z rework), whose z's were worked out in Cats.luau: its formula
			frame.zs = {}
			for i = 1, 3 do
				local along = (t / modules.Presets.nap.riseSeconds + (i - 1) / 3) % 1
				local fade = if along < 0.15 then 1 - along / 0.15 else (along - 0.15) / 0.85
				frame.zs[i] = {
					x = 0.3 + 0.45 * along,
					y = 0.85 - 0.75 * along,
					size = 1,
					fade = fade,
					tilt = 0,
				}
			end
		end
		for i, part in parts do
			frame.parts[i] = { cf = cframeList(part.CFrame), size = sizeOf(part) }
		end
		for _, part in propParts do
			table.insert(frame.parts, { cf = cframeList(part.CFrame), size = sizeOf(part) })
		end
		if carrier ~= nil then
			for _, part in carrier.order do
				local size = part.Size
				table.insert(
					frame.parts,
					{ cf = cframeList(placedCarrier[part]), size = { size.X, size.Y, size.Z } }
				)
			end
		end
		table.insert(frames, frame)
	end
	segmentStart += count / fps
end

fs.writeFile(
	outPath,
	serde.encode("json", {
		model = scenario.model,
		fps = fps,
		camera = scenario.camera,
		box = scenario.box,
		parts = info,
		frames = frames,
		zOn = zOn,
		nap = if modules.Presets.nap.box
			then {
				box = { modules.Presets.nap.box.X, modules.Presets.nap.box.Y },
				offset = { modules.Presets.nap.offset.X, modules.Presets.nap.offset.Y },
				zSize = { modules.Presets.nap.zSize.X, modules.Presets.nap.zSize.Y },
			}
			else { box = { 1.6, 2 }, offset = { 0.5, 1.6 }, zSize = { 0.4, 0.28 } },
	})
)
print(string.format("%s: %d frames of %d parts -> %s", scenarioName, #frames, #parts, outPath))
