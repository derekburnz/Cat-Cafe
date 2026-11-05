--!strict
-- The net swing's landing marker on this client (Derek 2026-11-03: "an indicator of where it's going to land ... it's
-- hard to tell"). A flat fan on the ground, NetReachStuds out and NetArcDegrees either side of the facing, drawn from
-- shared/NetSwing.landingOrigin: where the server will judge a swing pressed now. NetSwingController drives it: it
-- shows only for a moment after a press, from the swing until the net has landed (Derek2 2026-11-05: "change the
-- net outline to only show on swing", #1493), never while just walking about; cream while it would hit
-- nothing, gold while Moments.NetInReach names a stray. A press brightens it, and NetSmackDelay later, when the net
-- lands, it flashes and settles. Local parts in Effects/Context's folder with the other local effects (review N345),
-- never seen by other players.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Context = require(script.Parent.Parent.Effects.Context)
local NetSwing = require(Shared:WaitForChild("NetSwing"))

local NetMarker = {}

local SLICES = 8 -- 15 degree slices: the arc's chord sits under 0.1 studs inside the true reach
local FILL_THICK = 0.05
local EDGE_WIDTH = 0.16
local EDGE_THICK = 0.06
local LIFT = 0.07 -- above the ground, clear of floor textures
local GROUND_RAY = 9 -- studs down from the root a floor is looked for; none (mid jump off a ledge) hides the marker
local FADE_SECONDS = 0.18
local AFTER_LAND_SECONDS = 0.35 -- the landing flash settles over this
-- Opacity (1 - Transparency) of the fill and of the outline, idle and in reach, and what a press and a landing add.
local FILL = { idle = 0.16, reach = 0.26 }
local EDGE = { idle = 0.5, reach = 0.8 }
local WIND_UP = 0.12
local FLASH = 0.45
local IDLE_COLOR = Color3.fromRGB(255, 246, 225)
local REACH_COLOR = Color3.fromRGB(255, 200, 70)

local folder: Folder? = nil
local fills: { BasePart } = {}
local edges: { BasePart } = {}
local parts: { BasePart } = {}
local shapes: { CFrame } = {} -- each part's CFrame in the fan's own space, same order as `parts`
local frames: { CFrame } = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true
local rayCharacter: Model? = nil -- the character the ray leaves out, with the marker

local inReach = false
local pressedAt = -math.huge -- os.clock() of this player's last swing
local alpha = 0 -- 0 hidden to 1 shown, eased
local shownFill = -1
local shownEdge = -1
local shownGold: boolean? = nil

local function newPart(wedge: boolean, material: Enum.Material): BasePart
	local part: BasePart = if wedge then Instance.new("WedgePart") else Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Locked = true
	part.Material = material
	part.Transparency = 1
	return part
end

-- One right triangle laid flat (thickness up): the right angle at `corner`, one leg to `alongZ`, the other to
-- `alongY`. A WedgePart's right angle sits at its bottom back edge, its slope rising from front to back.
local function rightTriangle(corner: Vector3, alongZ: Vector3, alongY: Vector3): (Vector3, CFrame)
	local back = (corner - alongZ).Unit
	local up = (alongY - corner).Unit
	local right = up:Cross(back)
	local depth = (alongZ - corner).Magnitude
	local height = (alongY - corner).Magnitude
	local centre = corner + up * (height / 2) - back * (depth / 2)
	return Vector3.new(FILL_THICK, height, depth), CFrame.fromMatrix(centre, right, up, back)
end

-- A flat bar along the ground from `from` to `to`.
local function edgeBar(from: Vector3, to: Vector3): (Vector3, CFrame)
	local length = (to - from).Magnitude
	return Vector3.new(EDGE_WIDTH, EDGE_THICK, length + EDGE_WIDTH),
		CFrame.lookAt((from + to) / 2, to)
end

local function build(): Folder
	local made = Instance.new("Folder")
	made.Name = "NetMarker"
	local points = NetSwing.fanPoints(SLICES)
	local origin = Vector3.zero
	local function add(part: BasePart, size: Vector3, frame: CFrame, list: { BasePart })
		part.Size = size
		part.Parent = made
		table.insert(list, part)
		table.insert(parts, part)
		table.insert(shapes, frame)
		table.insert(frames, frame)
	end
	for index = 1, SLICES do
		local a, b = points[index], points[index + 1]
		local middle = (a + b) / 2
		for _, tip in { a, b } do
			local size, frame = rightTriangle(middle, origin, tip)
			add(newPart(true, Enum.Material.SmoothPlastic), size, frame, fills)
		end
		local size, frame = edgeBar(a, b)
		add(newPart(false, Enum.Material.Neon), size, frame, edges)
	end
	for _, tip in { points[1], points[#points] } do
		local size, frame = edgeBar(origin, tip)
		add(newPart(false, Enum.Material.Neon), size, frame, edges)
	end
	return made
end

-- How much a press adds now: a wind up while the net comes over, a flash as it lands, settling after.
local function pulse(now: number): number
	local since = now - pressedAt
	local landsAt = Config.NetSmackDelay
	if since < 0 or since > landsAt + AFTER_LAND_SECONDS then
		return 0
	end
	if since < landsAt then
		return WIND_UP * since / landsAt
	end
	return FLASH * (1 - (since - landsAt) / AFTER_LAND_SECONDS)
end

local function paint(fill: number, edge: number, gold: boolean)
	if gold ~= shownGold then
		shownGold = gold
		local color = if gold then REACH_COLOR else IDLE_COLOR
		for _, part in parts do
			part.Color = color
		end
	end
	if math.abs(fill - shownFill) > 0.004 then
		shownFill = fill
		for _, part in fills do
			part.Transparency = 1 - fill
		end
	end
	if math.abs(edge - shownEdge) > 0.004 then
		shownEdge = edge
		for _, part in edges do
			part.Transparency = 1 - edge
		end
	end
end

-- The ground under the landing origin, or nil when there is none near enough.
local function groundUnder(character: Model, made: Folder, at: Vector3): number?
	if character ~= rayCharacter then
		rayCharacter = character
		rayParams.FilterDescendantsInstances = { character, made }
	end
	local hit = Workspace:Raycast(at, Vector3.new(0, -GROUND_RAY, 0), rayParams)
	return if hit ~= nil then hit.Position.Y else nil
end

local function step(deltaTime: number, rootOf: () -> BasePart?)
	local made = folder
	if made == nil then
		return
	end
	local now = os.clock()
	local show = pulse(now) > 0
	local root = if show or alpha > 0 then rootOf() else nil
	local character = if root ~= nil then root.Parent else nil
	local ground: number? = nil
	local origin = Vector3.zero
	local look = Vector3.zero
	if root ~= nil and character ~= nil and character:IsA("Model") then
		origin = NetSwing.landingOrigin(root.Position, root.AssemblyLinearVelocity)
		local facing = root.CFrame.LookVector
		look = Vector3.new(facing.X, 0, facing.Z)
		ground = groundUnder(character :: Model, made, origin)
	end
	if ground == nil or look.Magnitude < 1e-3 then
		show = false
	end
	local target = if show then 1 else 0
	alpha = if target > alpha
		then math.min(target, alpha + deltaTime / FADE_SECONDS)
		else math.max(target, alpha - deltaTime / FADE_SECONDS)
	if alpha <= 0 then
		if made.Parent ~= nil then
			made.Parent = nil
		end
		return
	end
	if made.Parent == nil then
		made.Parent = Context.folder()
	end
	local extra = pulse(now)
	local fill = if inReach then FILL.reach else FILL.idle
	local edge = if inReach then EDGE.reach else EDGE.idle
	paint(alpha * math.min(1, fill + extra), alpha * math.min(1, edge + extra), inReach)
	if ground ~= nil then
		local at = Vector3.new(origin.X, (ground :: number) + LIFT, origin.Z)
		local base = CFrame.lookAt(at, at + look.Unit)
		for index, shape in shapes do
			frames[index] = base * shape
		end
		Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- Builds the fan and follows the root `rootOf` returns every frame.
function NetMarker.start(rootOf: () -> BasePart?)
	folder = build()
	RunService.PreRender:Connect(function(deltaTime: number)
		step(deltaTime, rootOf)
	end)
end

-- Whether a swing now would land on a stray (Moments.NetInReach named one): gold instead of cream.
function NetMarker.setInReach(on: boolean)
	inReach = on
end

-- This player pressed a swing: brighten now, flash NetSmackDelay later as the net lands.
function NetMarker.pressed()
	pressedAt = os.clock()
end

return NetMarker
