--!strict
-- Paw prints for a guide trail (#3554: "Paw prints only. No arrows, no timer"). UI's GuideTrail lays flat gold dots
-- from the player to a target. #4940 (Derek 2026-11-16: "make the paw trails pointing to stuff in tutorial steps"):
-- every tutorial step's trail is paws now, whatever the folder's `Paws` attribute says (UI still sets it for the Park
-- walk and the carry; it no longer gates anything). Each dot is drawn as a paw print instead: a pad and four toes,
-- toes towards the target, left and right in turn like a cat's steps. The dot itself is hidden on this client
-- (LocalTransparencyModifier, which GuideTrail never writes), and each paw fades with its dot, so GuideTrail's
-- comet of light still runs along the trail and Reduce Motion still holds it lit and still, but never fades past
-- `faintest`, and a soft dark rim keeps them clear on pale floors by day (they glow on their own at night).
-- GuideTrail is untouched. The folder leaving the Workspace takes the prints with it. On this client only; listening
-- only. Numbers in Presets.pawTrail.
--
-- Design 2026-11-17 (the top Effects cost in the Alleyway, with one 14 ms frame when a trail first showed):
-- each print is a part, a SurfaceGui and ten frames, so building a whole trail's worth in one frame was the spike.
-- Prints are now built ahead up to `pool` (GuideTrail's most dots), kept switched off when a dot goes away and handed
-- to the next dot instead of destroyed, and no more than `buildsPerFrame` are built in a frame. A print is only moved
-- when its dot or the dot it faces moved.
-- #4601 (Review-QA: 48 prints, about 600 instances, on every client from start, even for players who never see a
-- trail): the building ahead starts with the first trail, `buildsPerFrame` a frame, and a dot whose print is not
-- built yet is hidden like the rest, so its print shows up a frame or two later instead of a gold dot first.
--
-- Roblox terms: a SurfaceGui is 2D UI drawn on one face of a part, here an invisible flat part lying on the ground.
-- A CanvasGroup is a frame whose children fade together with one number.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Presets = require(script.Parent.Presets)

local PawTrail = {}

type Paw = {
	part: Part,
	gui: SurfaceGui,
	group: CanvasGroup,
	pad: { Frame },
	shown: number,
	colour: Color3,
	here: Vector3?, -- the dot's position and the point it faced when the print was last placed
	toward: Vector3?,
}

local started = false
local folders: { [Instance]: boolean } = {}
local prints: { [BasePart]: Paw } = {}
local home: Folder? = nil
local spare: { Paw } = {} -- built and switched off, for the next dot
local built = 0 -- prints built this frame
local warm = 0 -- prints built so far, ahead or for a dot
local trailSeen = false -- a trail has shown on this client: build the pool ahead from then on

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

-- How see-through a print is for its dot's `transparency`: the comet's tail never fades it past `faintest`; a dot
-- put fully out stays out. Pure.
function PawTrail.faded(transparency: number, faintest: number): number
	return if transparency >= 0.99 then 1 else math.min(transparency, faintest)
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
	local rim = Presets.pawTrail.rim
	local stroke = Instance.new("UIStroke")
	stroke.Color = rim.colour
	stroke.Thickness = rim.pixels
	stroke.Transparency = rim.transparency
	stroke.Parent = frame
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
	return {
		part = part,
		gui = gui,
		group = group,
		pad = pad,
		shown = -1,
		colour = Color3.new(),
		here = nil,
		toward = nil,
	}
end

-- A switched off print for a new dot: a spare one, else a new one while this frame has builds left, else nil.
local function take(): Paw?
	while #spare > 0 do
		local paw = table.remove(spare) :: Paw
		if paw.part.Parent ~= nil then
			paw.here, paw.toward = nil, nil
			return paw
		end
		paw.part:Destroy() -- its folder was taken away
	end
	if built >= Presets.pawTrail.buildsPerFrame then
		return nil
	end
	built += 1
	warm += 1
	local paw = make()
	paw.gui.Enabled = false
	return paw
end

local function drop(dot: BasePart)
	local paw = prints[dot]
	if paw ~= nil then
		prints[dot] = nil
		if #spare < Presets.pawTrail.pool and paw.part.Parent ~= nil then
			paw.gui.Enabled = false
			table.insert(spare, paw)
		else
			paw.part:Destroy()
		end
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
		local here = dot.Position
		local found: Paw? = prints[dot]
		if found == nil then
			found = take()
			if found == nil then
				last = here
				dot.LocalTransparencyModifier = 1 -- its print comes in a frame or two
				continue
			end
		end
		local paw = found :: Paw
		prints[dot] = paw
		local nextDot: BasePart? = dots[index + 1]
		local toward = if nextDot ~= nil
			then nextDot.Position
			elseif last ~= nil then here + (here - last)
			else here
		if paw.here ~= here or paw.toward ~= toward then
			paw.here, paw.toward = here, toward
			local at, forward = PawTrail.place(index, here, toward, p.offset)
			paw.part.CFrame = if forward ~= nil
				then CFrame.lookAt(at, at + forward)
				else CFrame.new(at)
		end
		if not paw.gui.Enabled then
			paw.gui.Enabled = true
		end
		last = here
		dot.LocalTransparencyModifier = 1
		local shown = PawTrail.faded(dot.Transparency, p.faintest)
		if shown ~= paw.shown then
			paw.shown = shown
			paw.group.GroupTransparency = shown
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
		trailSeen = true
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
		built = 0
		for folder in folders do
			if folder.Parent == nil then
				clear(folder)
				folders[folder] = nil
			else
				draw(folder)
			end
		end
		-- once a trail has shown, the rest of the pool is built ahead with what is left of this frame's builds
		local p = Presets.pawTrail
		while trailSeen and warm < p.pool and built < p.buildsPerFrame do
			built += 1
			warm += 1
			local paw = make()
			paw.gui.Enabled = false
			table.insert(spare, paw)
		end
	end)
end

return PawTrail
