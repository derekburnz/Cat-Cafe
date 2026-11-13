--!strict
-- Paw prints for a guide trail (#3554: "Paw prints only. No arrows, no timer"). UI's GuideTrail lays flat gold dots
-- from the player to a target. While its folder carries the attribute `Paws = true` (the caller sets it for the walk
-- to the Park gate and to the first Park stray), each dot is drawn as a paw print instead: a pad and four toes,
-- toes towards the target, left and right in turn like a cat's steps. The dot itself is hidden on this client
-- (LocalTransparencyModifier, which GuideTrail never writes), and each paw fades with its dot, so GuideTrail's
-- comet of light still runs along the trail and Reduce Motion still holds it lit and still. GuideTrail is untouched.
-- Clearing the attribute, or the folder leaving the Workspace, puts the dots back. On this client only; listening
-- only. Numbers in Presets.pawTrail.
--
-- Roblox terms: a SurfaceGui is 2D UI drawn on one face of a part, here an invisible flat part lying on the ground.
-- A CanvasGroup is a frame whose children fade together with one number.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Presets = require(script.Parent.Presets)

local PawTrail = {}

type Paw = { part: Part, group: CanvasGroup, pad: { Frame }, shown: number, colour: Color3 }

local started = false
local folders: { [Instance]: boolean } = {}
local prints: { [BasePart]: Paw } = {}
local home: Folder? = nil

-- Which side of the line the paw at `index` (from 1) falls on: 1 right, -1 left, in turn.
function PawTrail.side(index: number): number
	return if index % 2 == 1 then 1 else -1
end

-- Where the print for the dot at `here` lies and which way its toes point: towards `toward` (the next dot, or for
-- the last dot the way the one before it faced), `offset` studs to its side, flat on the ground. No way to face
-- (the two points one over the other) gives `here` and a nil direction.
function PawTrail.place(
	index: number,
	here: Vector3,
	toward: Vector3,
	offset: number
): (Vector3, Vector3?)
	local way = Vector3.new(toward.X - here.X, 0, toward.Z - here.Z)
	if way.Magnitude < 0.01 then
		return here, nil
	end
	local forward = way.Unit
	local right = Vector3.new(-forward.Z, 0, forward.X)
	return here + right * (PawTrail.side(index) * offset), forward
end

local function blob(parent: Instance, x: number, y: number, w: number, h: number): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(x, y)
	frame.Size = UDim2.fromScale(w, h)
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	frame.Parent = parent
	return frame
end

local function make(): Paw
	local p = Presets.pawTrail
	local folder = home
	if folder == nil or folder.Parent == nil then
		local created = Instance.new("Folder")
		created.Name = p.home
		created.Parent = Workspace
		folder = created
		home = created
	end
	local part = Instance.new("Part")
	part.Name = "PawPrint"
	part.Size = Vector3.new(p.size, 0.05, p.size)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Locked = true
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(p.pixels, p.pixels)
	gui.LightInfluence = 0
	gui.Brightness = p.brightness
	gui.Parent = part
	local group = Instance.new("CanvasGroup")
	group.BackgroundTransparency = 1
	group.Size = UDim2.fromScale(1, 1)
	group.Rotation = p.turn
	group.Parent = gui
	local pad = { blob(group, 0.5, 0.66, 0.5, 0.42) }
	for _, toe in p.toes do
		table.insert(pad, blob(group, toe[1], toe[2], toe[3], toe[4]))
	end
	part.Parent = folder
	return { part = part, group = group, pad = pad, shown = -1, colour = Color3.new() }
end

local function drop(dot: BasePart)
	local paw = prints[dot]
	if paw ~= nil then
		paw.part:Destroy()
		prints[dot] = nil
	end
	dot.LocalTransparencyModifier = 0
end

local function clear(folder: Instance)
	for dot in prints do
		if dot.Parent == folder or dot.Parent == nil then
			drop(dot)
		end
	end
end

local function draw(folder: Instance)
	local p = Presets.pawTrail
	local dots: { BasePart } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") and child.Name == Presets.trailSparkle.dot then
			table.insert(dots, child :: BasePart)
		end
	end
	local last: Vector3? = nil
	for index, dot in dots do
		local paw = prints[dot]
		if paw == nil then
			paw = make()
			prints[dot] = paw
		end
		local here = dot.Position
		local nextDot: BasePart? = dots[index + 1]
		local toward = if nextDot ~= nil
			then nextDot.Position
			elseif last ~= nil then here + (here - last)
			else here
		local at, forward = PawTrail.place(index, here, toward, p.offset)
		paw.part.CFrame = if forward ~= nil then CFrame.lookAt(at, at + forward) else CFrame.new(at)
		last = here
		dot.LocalTransparencyModifier = 1
		if dot.Transparency ~= paw.shown then
			paw.shown = dot.Transparency
			paw.group.GroupTransparency = dot.Transparency
		end
		if dot.Color ~= paw.colour then
			paw.colour = dot.Color
			for _, frame in paw.pad do
				frame.BackgroundColor3 = dot.Color
			end
		end
	end
	-- a dot GuideTrail has put away (a shorter route) loses its print
	for dot in prints do
		if dot.Parent ~= folder then
			drop(dot)
		end
	end
end

local function consider(child: Instance)
	if child:IsA("Folder") and child.Name == Presets.trailSparkle.folder then
		folders[child] = true
	end
end

function PawTrail.start()
	if started then
		return
	end
	started = true
	for _, child in Workspace:GetChildren() do
		consider(child)
	end
	Workspace.ChildAdded:Connect(consider)
	RunService.Heartbeat:Connect(function()
		for folder in folders do
			if folder.Parent == nil then
				clear(folder)
				folders[folder] = nil
			elseif folder:GetAttribute(Presets.pawTrail.attribute) == true then
				draw(folder)
			elseif next(prints) ~= nil then
				clear(folder)
			end
		end
	end)
end

return PawTrail
