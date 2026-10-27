--!strict
-- A glowing dotted path on the ground from the player to a target (Pet Simulator 99's tutorial path, world-and-feel
-- section 6 P1). The dots follow a walkable route, so the trail bends out through the back door instead of cutting
-- through walls, and a comet of light runs along them toward the target. The trail hides near the target and while
-- there is no character. With reduced motion the dots stay lit without the comet.
--
-- Roblox terms: PathfindingService works out a walkable route around walls as a list of waypoints on the floor.
-- The dots are parts made by this client only, so other players never see your trail and the server never hears
-- about it. They do not collide, cast no shadow and are skipped by raycasts and touches.

local GuiService = game:GetService("GuiService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Theme = require(script.Parent.Parent.Theme)

export type Target = BasePart | Attachment | Vector3

export type GuideTrail = {
	show: (self: GuideTrail, target: Target, color: Color3?) -> (),
	hide: (self: GuideTrail) -> (),
	destroy: (self: GuideTrail) -> (),
}

local SPACING = 3.5 -- studs between dots
local MAX_DOTS = 48 -- about 170 studs of trail; the marker's distance covers the rest of a longer trip
local START_GAP = 3 -- the first dot sits this far ahead of the player
local ARRIVED = 10 -- studs from the target where the trail hides
local REPATH_MOVE = 5 -- studs the player moves before the route is worked out again
local REPATH_SECONDS = 0.75 -- and no more often than this
local FRAME = 1 / 30 -- the comet moves at 30 Hz
local WAVE_DOTS = 7 -- one comet every this many dots
local WAVE_SPEED = 12 -- dots per second
local LIT, DIM, STILL = 0.05, 0.75, 0.3 -- dot transparency at the comet's head, its tail, and with reduced motion
local DOT_SIZE = Vector3.new(0.15, 1.1, 1.1) -- a flat disc: a cylinder's length runs along X
local FLAT = CFrame.Angles(0, 0, math.rad(90)) -- stands the cylinder's axis upright so the disc lies flat
local LIFT = 0.12 -- studs above the floor, so the dots do not flicker into it

local GuideTrail = {}
GuideTrail.__index = GuideTrail

local function targetPosition(target: Target): Vector3?
	if typeof(target) == "Vector3" then
		return target :: Vector3
	end
	local instance = target :: Instance
	if instance.Parent == nil then
		return nil
	end
	if instance:IsA("BasePart") then
		return (instance :: BasePart).Position
	elseif instance:IsA("Attachment") then
		return (instance :: Attachment).WorldPosition
	end
	return nil
end

-- The player's feet, or nil without a character.
local function feet(): Vector3?
	local player = Players.LocalPlayer
	local character = if player then player.Character else nil
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local rootPart = root :: BasePart
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hip = if humanoid then humanoid.HipHeight else 2
	return rootPart.Position - Vector3.new(0, rootPart.Size.Y / 2 + hip, 0)
end

-- Points every SPACING studs along the polyline, starting START_GAP in and stopping before the end.
local function resample(points: { Vector3 }): { Vector3 }
	local out: { Vector3 } = {}
	local nextAt = START_GAP
	local walked = 0
	for index = 1, #points - 1 do
		local from, to = points[index], points[index + 1]
		local length = (to - from).Magnitude
		while length > 0 and nextAt <= walked + length do
			table.insert(out, from:Lerp(to, (nextAt - walked) / length))
			if #out >= MAX_DOTS then
				return out
			end
			nextAt += SPACING
		end
		walked += length
	end
	return out
end

function GuideTrail.new(name: string): GuideTrail
	local self = setmetatable({}, GuideTrail) :: any
	local folder = Instance.new("Folder")
	folder.Name = name
	self._folder = folder
	self._dots = {} :: { Part }
	self._count = 0
	self._color = Theme.colors.gold
	self._target = nil :: Target?
	self._loop = nil :: RBXScriptConnection?
	self._generation = 0
	self._computing = false
	self._lastStart = nil :: Vector3?
	self._lastPathAt = -math.huge
	return self :: GuideTrail
end

function GuideTrail._dot(self: any, index: number): Part
	local dots: { Part } = self._dots
	local dot = dots[index]
	if dot then
		return dot
	end
	local created = Instance.new("Part")
	created.Name = "Dot"
	created.Shape = Enum.PartType.Cylinder
	created.Size = DOT_SIZE
	created.Material = Enum.Material.Neon
	created.Anchored = true
	created.CanCollide = false
	created.CanQuery = false
	created.CanTouch = false
	created.CastShadow = false
	created.Locked = true
	table.insert(dots, created)
	return created
end

-- Lays the dots along the route and hides the spare ones.
function GuideTrail._lay(self: any, route: { Vector3 })
	local points = resample(route)
	for index, point in points do
		local dot = self:_dot(index)
		dot.Color = self._color
		dot.CFrame = CFrame.new(point + Vector3.new(0, LIFT, 0)) * FLAT
		dot.Parent = self._folder
	end
	for index = #points + 1, self._count do
		self._dots[index].Parent = nil
	end
	self._count = #points
end

function GuideTrail._repath(self: any, start: Vector3, finish: Vector3)
	self._computing = true
	self._lastStart = start
	self._lastPathAt = os.clock()
	local generation = self._generation
	task.spawn(function()
		local route: { Vector3 } = { start, finish }
		local path = PathfindingService:CreatePath({
			AgentRadius = 1.5,
			AgentHeight = 5,
			AgentCanJump = true,
		})
		local ok = pcall(function()
			path:ComputeAsync(start, finish)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			local waypoints = path:GetWaypoints()
			if #waypoints >= 2 then
				route = {}
				for _, waypoint in waypoints do
					table.insert(route, waypoint.Position)
				end
			end
		end
		self._computing = false
		-- a hide or a new target while the route was worked out wins
		if generation == self._generation then
			self:_lay(route)
		end
	end)
end

function GuideTrail._step(self: any)
	local target: Target? = self._target
	local finish = if target ~= nil then targetPosition(target) else nil
	local start = feet()
	if finish == nil or start == nil or (finish - start).Magnitude < ARRIVED then
		self:_lay({})
		self._lastStart = nil
		return
	end
	assert(finish and start, "trail ends")
	local last: Vector3? = self._lastStart
	local moved = last == nil or (start - last).Magnitude >= REPATH_MOVE
	if moved and not self._computing and os.clock() - self._lastPathAt >= REPATH_SECONDS then
		self:_repath(start, finish)
	end

	local dots: { Part } = self._dots
	if GuiService.ReducedMotionEnabled then
		for index = 1, self._count do
			dots[index].Transparency = STILL
		end
		return
	end
	local head = os.clock() * WAVE_SPEED
	for index = 1, self._count do
		local behind = ((head - index) % WAVE_DOTS) / WAVE_DOTS -- 0 at the comet's head, near 1 at its tail
		dots[index].Transparency = LIT + (DIM - LIT) * behind
	end
end

function GuideTrail.show(self: any, target: Target, color: Color3?)
	self._color = color or Theme.colors.gold
	for index = 1, self._count do
		self._dots[index].Color = self._color
	end
	if self._loop and self._target == target then
		return -- the tutorial refreshes on every state update; keep the route
	end
	self:hide()
	self._target = target
	self._folder.Parent = Workspace
	local accumulator = FRAME
	self._loop = RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < FRAME then
			return
		end
		accumulator = 0
		self:_step()
	end)
end

function GuideTrail.hide(self: any)
	local loop: RBXScriptConnection? = self._loop
	if loop then
		loop:Disconnect()
	end
	self._loop = nil
	self._target = nil
	self._generation += 1
	self._computing = false
	self._lastStart = nil
	self._lastPathAt = -math.huge
	self:_lay({})
	self._folder.Parent = nil
end

function GuideTrail.destroy(self: any)
	self:hide()
	self._folder:Destroy()
	for _, dot in self._dots do
		dot:Destroy()
	end
	table.clear(self._dots)
end

return GuideTrail
