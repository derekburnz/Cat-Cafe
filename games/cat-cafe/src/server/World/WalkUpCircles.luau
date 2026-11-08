--!strict
-- The glowing floor rings at the walk-up stations (#2398 follow-up; Derek2 2026-11-08: "honestly adding the circle
-- infront of the stations designed for each station might be a good idea", the cannon's "all the way around"). Each
-- ring marks where the station's window pops (Controllers/WalkUpController opens it on stepping inside), like the Codes
-- Cat's circle: a soft fill and a bright rim in the station's own colour, drawn flat on a SurfaceGui that ignores the
-- light, so it glows by day and night without Neon bloom.
--   front(model, color, range, into?)   a ring on the floor in front of the station (its -Z, which faces the cannon)
--   around(model, color, range, into?, cap?)  a ring all the way round it (the Cat Cannons), at most `cap` wide
-- `range` is the server's reach for the station's window, so the whole ring stays inside it (shared/WalkUp). The ring
-- goes in `into`, else beside the model.
--
-- Roblox terms: the ring is an invisible, non-colliding Part named WalkUp.CIRCLE beside the station's Model (not in it,
-- so code that takes a station's first part never gets the ring), with its radius in the Radius attribute; an
-- ObjectValue of the same name inside the Model points at it, and the ring goes when the Model does. A SurfaceGui on
-- its top face draws the circle with a rounded Frame and a UIStroke.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WalkUp = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WalkUp"))

local WalkUpCircles = {}

local PIXELS_PER_STUD = 24
local LIFT = 0.06 -- studs above the station's lowest point, clear of the paving so it never z-fights
local RIM = 0.3 -- studs: the bright rim
local HALO = 0.35 -- studs: the softer band inside it
local FILL = 0.82 -- the disc's see-through share
local HALO_SEEN = 0.55

-- The station's footprint in its own frame: how far its widest point reaches from the pivot along -Z (its front) and
-- in any flat direction, and the height of its lowest point.
local function footprint(model: Model): (number, number, number)
	local pivot = model:GetPivot()
	local box, size = model:GetBoundingBox()
	local front, half, bottom = 0, 0, math.huge
	for _, x in { -0.5, 0.5 } do
		for _, y in { -0.5, 0.5 } do
			for _, z in { -0.5, 0.5 } do
				local corner = box * Vector3.new(size.X * x, size.Y * y, size.Z * z)
				local here = pivot:PointToObjectSpace(corner)
				front = math.max(front, -here.Z)
				half = math.max(half, math.abs(here.X), math.abs(here.Z))
				bottom = math.min(bottom, corner.Y)
			end
		end
	end
	if bottom == math.huge then
		bottom = pivot.Position.Y
	end
	return front, half, bottom
end

local function ring(model: Model, centre: Vector3, radius: number, color: Color3, into: Instance?)
	local old = model:FindFirstChild(WalkUp.CIRCLE)
	if old ~= nil and old:IsA("ObjectValue") then
		local was = (old :: ObjectValue).Value
		if was ~= nil then
			was:Destroy()
		end
		old:Destroy()
	end
	local pivot = model:GetPivot()
	local flatLook = Vector3.new(pivot.LookVector.X, 0, pivot.LookVector.Z)
	local look = if flatLook.Magnitude > 1e-3 then flatLook.Unit else Vector3.new(0, 0, -1)
	local part = Instance.new("Part")
	part.Name = WalkUp.CIRCLE
	part.Size = Vector3.new(radius * 2, 0.05, radius * 2)
	part.CFrame = CFrame.lookAt(centre, centre + look)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part:SetAttribute("Radius", radius)

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Ring"
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.LightInfluence = 0
	gui.Brightness = 1.5
	gui.ResetOnSpawn = false
	local function circle(across: number, fill: number, stroke: number?, seen: number)
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromScale(0.5, 0.5)
		frame.Size = UDim2.fromScale(across / radius, across / radius)
		frame.BackgroundColor3 = color
		frame.BackgroundTransparency = fill
		frame.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = frame
		if stroke ~= nil then
			local line = Instance.new("UIStroke")
			line.Color = color
			line.Thickness = stroke * PIXELS_PER_STUD
			line.Transparency = seen
			line.BorderStrokePosition = Enum.BorderStrokePosition.Inner
			line.Parent = frame
		end
		frame.Parent = gui
	end
	circle(radius, FILL, RIM, 0) -- the disc and its bright rim
	circle(radius - RIM, 1, HALO, HALO_SEEN) -- the softer band just inside the rim
	gui.Parent = part
	part.Parent = into or model.Parent or model
	local link = Instance.new("ObjectValue")
	link.Name = WalkUp.CIRCLE
	link.Value = part
	link.Parent = model
	model.Destroying:Connect(function()
		part:Destroy()
	end)
end

-- A ring in front of the station, touching its front, inside `range` of its pivot.
function WalkUpCircles.front(model: Model, color: Color3, range: number, into: Instance?)
	local front, _, bottom = footprint(model)
	local radius = WalkUp.FRONT_RADIUS
	local pivot = model:GetPivot()
	local out = WalkUp.frontOffset(front, radius, range)
	local at = (pivot * CFrame.new(0, 0, -out)).Position
	ring(model, Vector3.new(at.X, bottom + LIFT, at.Z), radius, color, into)
end

-- A ring round the whole station, centred on its pivot.
function WalkUpCircles.around(
	model: Model,
	color: Color3,
	range: number,
	into: Instance?,
	cap: number?
)
	local _, half, bottom = footprint(model)
	local at = model:GetPivot().Position
	ring(
		model,
		Vector3.new(at.X, bottom + LIFT, at.Z),
		WalkUp.aroundRadius(half, range, cap),
		color,
		into
	)
end

return WalkUpCircles
