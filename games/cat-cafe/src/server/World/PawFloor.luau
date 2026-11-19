--!strict
-- #5471 (Derek 2026-11-19: "the paws should just be built into the floor so it doesn't render seprate period"),
-- switch `pawsInFloor` (shared/TownGround.FLOOR_FLAG, read by Services/TownGroundService): every print of the Town
-- Square's paw path (WorldBuilder.buildPawPaths' PawPaths) is drawn on the top face of the floor part under it (the
-- square's lane strip, the street halves) as a pad and four round toes in a SurfaceGui on that part, and the
-- PawPaths parts go see-through (Transparency 1) on every device. A print is then part of its floor: it streams in
-- and out with it and never shows up on its own. Off, the drawings go and the parts come back as built.
--
-- Roblox terms: a SurfaceGui draws 2D UI flat on one face of a part; here PixelsPerStud fixes its size to the part's.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TownGround = require(ReplicatedStorage.Shared.TownGround)

local PawFloor = {}

local LIFT = 1 -- studs over a print the ray down to its floor starts
local hidden: { [BasePart]: number } = {} -- each PawPaths part made see-through, with its Transparency before

local function paths(): Instance?
	local world = Workspace:FindFirstChild("World")
	return if world ~= nil then world:FindFirstChild(TownGround.PATHS_NAME) else nil
end

local function guiOn(floor: BasePart): SurfaceGui
	local found = floor:FindFirstChild(TownGround.FLOOR_GUI)
	if found ~= nil and found:IsA("SurfaceGui") then
		return found :: SurfaceGui
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = TownGround.FLOOR_GUI
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = TownGround.PIXELS
	gui.LightInfluence = 1
	gui.ClipsDescendants = true
	gui.Parent = floor
	return gui
end

local function round(parent: Instance, diameter: number, x: number, z: number, colour: Color3)
	local px = TownGround.PIXELS
	local half = TownGround.BOX / 2
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromOffset((x + half) * px, (z + half) * px)
	dot.Size = UDim2.fromOffset(diameter * px, diameter * px)
	dot.BackgroundColor3 = colour
	dot.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = dot
	dot.Parent = parent
end

-- Draws the print whose pad is `pad` on the floor under it; false when there is no flat floor there.
local function draw(pad: BasePart, skip: { Instance }): boolean
	-- the pad is laid flat by a quarter turn about Z; undo it for the print's own frame
	local frame = pad.CFrame * CFrame.Angles(0, 0, math.rad(-90))
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = skip
	local from = frame.Position + Vector3.new(0, LIFT, 0)
	local hit = Workspace:Raycast(from, Vector3.new(0, -LIFT - 1, 0), params)
	if hit == nil or hit.Normal.Y < 0.9 or not hit.Instance:IsA("BasePart") then
		return false
	end
	local floor = hit.Instance :: BasePart
	if math.abs(floor.CFrame.UpVector.Y) < 0.99 then
		return false -- a tilted floor's Top canvas is not flat under the print
	end
	local here = floor.CFrame:PointToObjectSpace(frame.Position)
	local look = floor.CFrame:VectorToObjectSpace(frame.LookVector)
	local x, y = TownGround.pixel(here.X, here.Z, floor.Size.X, floor.Size.Z, TownGround.PIXELS)
	local box = Instance.new("Frame")
	box.Name = "Paw"
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromOffset(x, y)
	box.Size =
		UDim2.fromOffset(TownGround.BOX * TownGround.PIXELS, TownGround.BOX * TownGround.PIXELS)
	box.BackgroundTransparency = 1
	box.Rotation = TownGround.canvasTurn(TownGround.turnOf(look.X, look.Z))
	round(box, TownGround.PAD, 0, 0, pad.Color)
	for _, toe in TownGround.TOES do
		round(box, TownGround.TOE, toe[1], toe[2], pad.Color)
	end
	box.Parent = guiOn(floor)
	return true
end

-- Draws every print into its floor and hides the parts (on) or takes the drawings away and gives the parts back.
function PawFloor.apply(on: boolean)
	local model = paths()
	if not on then
		for part, was in hidden do
			if part.Parent ~= nil then
				part.Transparency = was
			end
		end
		table.clear(hidden)
		for _, item in Workspace:GetDescendants() do
			if item.Name == TownGround.FLOOR_GUI and item:IsA("SurfaceGui") then
				item:Destroy()
			end
		end
		return
	end
	if model == nil or next(hidden) ~= nil then
		return
	end
	local skip: { Instance } = { model }
	for _, player in game:GetService("Players"):GetPlayers() do
		if player.Character ~= nil then
			table.insert(skip, player.Character :: Model)
		end
	end
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") and item.Name == "PawPad" then
			local pad = item :: BasePart
			if draw(pad, skip) then
				-- this print is in its floor now: its pad and toes (the four parts built right after it) go
				hidden[pad] = pad.Transparency
				pad.Transparency = 1
			end
		end
	end
	-- the toes of every drawn print: those within a print's box of a hidden pad
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") and item.Name == "PawToe" then
			local toe = item :: BasePart
			for pad in hidden do
				if
					pad.Name == "PawPad"
					and (pad.Position - toe.Position).Magnitude <= TownGround.BOX
				then
					hidden[toe] = toe.Transparency
					toe.Transparency = 1
					break
				end
			end
		end
	end
end

return PawFloor
