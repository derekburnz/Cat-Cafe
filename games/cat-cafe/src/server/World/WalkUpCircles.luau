--!strict
-- The glowing floor rings at the walk-up stations (#2398 follow-up; Derek2 2026-11-08: "honestly adding the circle
-- infront of the stations designed for each station might be a good idea", the cannon's "all the way around"). Each
-- ring marks where the station's window pops (Controllers/WalkUpController opens it on stepping inside), like the Codes
-- Cat's circle: a soft fill and a bright rim in the station's own colour, drawn flat on a SurfaceGui that ignores the
-- light, so it glows by day and night without Neon bloom.
--   front(model, color, range, into?, icon?)  a ring on the floor in front of the station (its -Z, which faces the
--                                         cannon), with `icon` lying in its middle (#2449)
--   around(model, color, range, into?, cap?)  a ring all the way round it (the Cat Cannons), at most `cap` wide, slid
--                                         off a wall on its floor (#2433)
-- `range` is the server's reach for the station's window, so the whole ring stays inside it (shared/WalkUp). The ring
-- goes in `into`, else beside the model.
--
-- Roblox terms: the ring is an invisible, non-colliding Part named WalkUp.CIRCLE beside the station's Model (not in it,
-- so code that takes a station's first part never gets the ring), with its radius in the Radius attribute; an
-- ObjectValue of the same name inside the Model points at it, and the ring goes when the Model does. A SurfaceGui on
-- its top face draws the circle with a rounded Frame and a UIStroke.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AssetRegistry = require(script.Parent.AssetRegistry)
local WalkUp = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WalkUp"))

local WalkUpCircles = {}

local PIXELS_PER_STUD = 24
local LIFT = 0.06 -- studs above the station's lowest point, clear of the paving so it never z-fights
local RIM = 0.3 -- studs: the bright rim
local HALO = 0.35 -- studs: the softer band inside it
local FILL = 0.82 -- the disc's see-through share
local HALO_SEEN = 0.55
-- #2433: what stands on a round ring's floor is found by PROBES flat rays out from its centre, PROBE_UP studs over the
-- station's lowest point (low enough to meet a camp's 0.3-stud side wall), and the ring slides off it
local PROBES = 48
local PROBE_UP = 0.15
local BASE_UP = 1.5 -- studs over its lowest point that count as the station's base, which the ring must hold

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

-- #2449 (Derek2: "add cute images in the circles infront of the stations similar to how codes cat has a coupon with a
-- paw on it"): a station's icon in its ring. `art` is a flat decor model in ReplicatedStorage.Assets (Model-Agent's
-- CatCafe_Street_<Station>_RingIcon_Decor, like the Codes Cat's ticket), laid in the middle and shrunk to fit; until
-- it is in, `emoji` on a little cream card with a paw stamp, drawn on the ring's own surface.
export type Icon = { emoji: string, art: string? }

local CARD = Color3.fromRGB(255, 246, 228)
local CARD_TILT = -8 -- degrees, a card dropped on the floor
local CARD_EDGE = 0.12 -- studs: the card's outline, in the station's colour
local ICON_LIFT = 0.01 -- studs above the ring, so the art never z-fights its fill (Model-Agent, #2455)

-- The stand-in: the card, its emoji and the paw stamp, on the ring's SurfaceGui (which spans the ring's width).
local function card(gui: SurfaceGui, icon: Icon, color: Color3)
	local frame = Instance.new("Frame")
	frame.Name = "Icon"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(WalkUp.ICON_SHARE, WalkUp.ICON_SHARE)
	frame.Rotation = CARD_TILT
	frame.BackgroundColor3 = CARD
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = frame
	local edge = Instance.new("UIStroke")
	edge.Color = color
	edge.Thickness = CARD_EDGE * PIXELS_PER_STUD
	edge.Parent = frame
	local function glyph(name: string, text: string, size: number, x: number, y: number)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(x, y)
		label.Size = UDim2.fromScale(size, size)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = color
		label.Parent = frame
	end
	glyph("Emoji", icon.emoji, 0.72, 0.5, 0.47)
	glyph("Paw", "🐾", 0.3, 0.8, 0.8)
	frame.Parent = gui
end

-- The art, laid flat in the ring's middle, at most ICON_ART_SHARE of its width across; false when it is not in.
local function art(part: BasePart, icon: Icon, radius: number): boolean
	local name = icon.art
	if name == nil or not AssetRegistry.has(name) then
		return false
	end
	local decor = AssetRegistry.clone(name)
	local size = decor:GetExtentsSize()
	local across = math.max(size.X, size.Z)
	local most = radius * 2 * WalkUp.ICON_ART_SHARE
	if across > most and across > 0 then
		decor:ScaleTo(decor:GetScale() * most / across)
	end
	for _, piece in decor:GetDescendants() do
		if piece:IsA("BasePart") then
			piece.Anchored = true
			piece.CanCollide = false
			piece.CanQuery = false
			piece.CanTouch = false
			piece.CastShadow = false
		elseif piece:IsA("Script") or piece:IsA("LocalScript") then
			piece:Destroy() -- decor carries no code (rule 7)
		end
	end
	decor.Name = "Icon"
	decor:PivotTo(part.CFrame * CFrame.new(0, part.Size.Y / 2 + ICON_LIFT, 0))
	decor.Parent = part
	return true
end

local function ring(
	model: Model,
	centre: Vector3,
	radius: number,
	color: Color3,
	into: Instance?,
	icon: Icon?
)
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
	if icon ~= nil and not art(part, icon, radius) then
		card(gui, icon, color)
	end
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

-- A ring in front of the station, touching its front, inside `range` of its pivot, with `icon` in its middle.
function WalkUpCircles.front(
	model: Model,
	color: Color3,
	range: number,
	into: Instance?,
	icon: Icon?
)
	local front, _, bottom = footprint(model)
	local radius = WalkUp.FRONT_RADIUS
	local pivot = model:GetPivot()
	local out = WalkUp.frontOffset(front, radius, range)
	local at = (pivot * CFrame.new(0, 0, -out)).Position
	ring(model, Vector3.new(at.X, bottom + LIFT, at.Z), radius, color, into, icon)
end

-- The flat points, from `centre`, where something other than the station stands on the floor within `reach`.
local function blocksAround(model: Model, centre: Vector3, reach: number): { Vector2 }
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	params.IgnoreWater = true
	params.RespectCanCollide = true -- walls and props, not the see-through trigger volumes that walk through
	local found: { Vector2 } = {}
	for index = 1, PROBES do
		local angle = (index - 1) / PROBES * math.pi * 2
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local hit = Workspace:Raycast(centre, direction * reach, params)
		if hit ~= nil then
			table.insert(found, Vector2.new(hit.Position.X - centre.X, hit.Position.Z - centre.Z))
		end
	end
	return found
end

-- The flat corners, from `centre`, of the station's visible parts that start within BASE_UP of its lowest point: its
-- base on the floor, which a fitted ring still holds (Laptop-Tester on #2435).
local function baseOf(model: Model, centre: Vector3, bottom: number): { Vector2 }
	local found: { Vector2 } = {}
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") and piece.Transparency < 1 then
			local half = piece.Size / 2
			local corners: { Vector3 } = {}
			local low = math.huge
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						local corner = piece.CFrame
							* Vector3.new(half.X * x, half.Y * y, half.Z * z)
						low = math.min(low, corner.Y)
						table.insert(corners, corner)
					end
				end
			end
			if low <= bottom + BASE_UP then
				for _, corner in corners do
					table.insert(found, Vector2.new(corner.X - centre.X, corner.Z - centre.Z))
				end
			end
		end
	end
	return found
end

-- A ring round the whole station, centred on its pivot, slid off (and if need be shrunk to clear) anything standing
-- on its floor, such as a camp's low side wall (#2433), while it still holds the station's own base.
function WalkUpCircles.around(
	model: Model,
	color: Color3,
	range: number,
	into: Instance?,
	cap: number?
)
	local _, half, bottom = footprint(model)
	local at = model:GetPivot().Position
	local radius = WalkUp.aroundRadius(half, range, cap)
	local most = math.min(WalkUp.FIT_SHIFT_MAX, range - WalkUp.EDGE_SLACK - radius)
	local reach = radius + WalkUp.FIT_CLEAR + math.max(0, most)
	local blocks = blocksAround(model, Vector3.new(at.X, bottom + PROBE_UP, at.Z), reach)
	local shift, fitted = WalkUp.fitRing(radius, blocks, most, 1, baseOf(model, at, bottom))
	ring(model, Vector3.new(at.X + shift.X, bottom + LIFT, at.Z + shift.Y), fitted, color, into)
end

return WalkUpCircles
