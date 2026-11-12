--!strict
-- The Neighborhood's trampoline bounces (#3690, Derek 2026-11-12: "make the trampoline in neighborhood actually give
-- u a bounce when you on it"). When this player's character lands on the mat of a model named "..._Trampoline"
-- (Model-Agent's neighbourhood sets), it is pushed straight up to about `height` studs over the mat, the mat dips
-- and springs back, and a springy sound plays (Trampoline.onBounce; Audio). Landing on it again bounces again, any
-- number of times; walking off ends it.
--
-- On this client only, for this player's own character: no remote, nothing saved. The server sees an ordinary
-- jump's worth of height (a bounce reaches a little higher than a jump off the mat would), so it opens no way over
-- a wall that a jump from the mat did not already open. No bounce while carrying a cat (a carrier could dodge a
-- tackle with it), while sitting, or while the character is held by something else (the cannon, a cutscene).
-- Numbers in Presets.trampoline.
--
-- The mat is built with CanTouch off, so Touched never fires on it (Review-QA's Studio try). A landing is found from
-- the Humanoid instead: when its state turns to Landed (or Running, for a step up onto the mat from a prop), one
-- short ray straight down from the root part finds what the character stands on.
--
-- Roblox terms: a Humanoid's state says what the character is doing (Freefall, Landed, Running). A raycast asks the
-- world what a line hits first. AssemblyLinearVelocity is the speed of a whole welded body; setting it on the
-- character's root part moves the character.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Presets = require(script.Parent.Presets)

local Trampoline = {}

local started = false
local lastBounce = 0
local dipping: { [BasePart]: CFrame } = {}
local listeners: { (mat: BasePart) -> () } = {}

-- The speed straight up that carries a body `height` studs high under `gravity` (studs a second squared).
function Trampoline.speed(height: number, gravity: number): number
	if height <= 0 or gravity <= 0 then
		return 0
	end
	return math.sqrt(2 * gravity * height)
end

-- Whether `name` is a trampoline model's name (it ends in Presets.trampoline.suffix).
function Trampoline.named(name: string): boolean
	local suffix: string = Presets.trampoline.suffix
	return #name >= #suffix and string.sub(name, -#suffix) == suffix
end

-- Whether a part of that size is the mat: the thin wide disc, not a leg or the rim's pieces.
function Trampoline.isMat(size: Vector3): boolean
	local t = Presets.trampoline
	local thin = math.min(size.X, size.Y, size.Z)
	local wide = math.max(size.X, size.Y, size.Z)
	return thin <= t.matThin and wide >= t.matWide
end

export type Landing = {
	feetY: number, -- the height of the character's feet
	matTop: number, -- the height of the mat's top face
	away: number, -- studs from the mat's centre to the character, on the flat
	radius: number, -- the mat's radius
	sinceLast: number, -- seconds since the last bounce
	carrying: boolean,
	held: boolean, -- sitting, dead, or moved by something else
}

-- Whether that touch is a landing that bounces: from above, over the mat, not too soon after the last one.
function Trampoline.bounces(landing: Landing): boolean
	local t = Presets.trampoline
	if landing.carrying or landing.held or landing.sinceLast < t.gap then
		return false
	end
	if landing.away > landing.radius + t.edge then
		return false
	end
	return landing.feetY >= landing.matTop - t.under
end

-- `callback(mat)` runs at each bounce of this player's character (Audio's springy sound).
function Trampoline.onBounce(callback: (mat: BasePart) -> ())
	table.insert(listeners, callback)
end

local function dip(mat: BasePart)
	local t = Presets.trampoline
	local busy: CFrame? = dipping[mat]
	if Context.reducedMotion() or busy then
		return
	end
	local home = mat.CFrame
	dipping[mat] = home
	local down = TweenService:Create(
		mat,
		TweenInfo.new(t.down, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = home - Vector3.new(0, t.dip, 0) }
	)
	down.Completed:Once(function()
		local up = TweenService:Create(
			mat,
			TweenInfo.new(t.up, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ CFrame = home }
		)
		up.Completed:Once(function()
			mat.CFrame = home
			dipping[mat] = nil
		end)
		up:Play()
	end)
	down:Play()
end

local function landed(character: Model, humanoid: Humanoid)
	local root = humanoid.RootPart
	if root == nil then
		return
	end
	local reach = if humanoid.RigType == Enum.HumanoidRigType.R6 then 2 else humanoid.HipHeight
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local result = Workspace:Raycast(
		root.Position,
		Vector3.new(0, -(root.Size.Y / 2 + reach + Presets.trampoline.ray), 0),
		params
	)
	local found = if result ~= nil then result.Instance else nil
	if found == nil or not found:IsA("BasePart") then
		return
	end
	local hit = found :: BasePart
	local model = hit.Parent
	if model == nil or not Trampoline.named(model.Name) or not Trampoline.isMat(hit.Size) then
		return
	end
	local home = dipping[hit] or hit.CFrame
	local thin = math.min(hit.Size.X, hit.Size.Y, hit.Size.Z)
	local wide = math.max(hit.Size.X, hit.Size.Y, hit.Size.Z)
	local legs = if humanoid.RigType == Enum.HumanoidRigType.R6 then 2 else humanoid.HipHeight
	local flat =
		Vector3.new(root.Position.X - home.Position.X, 0, root.Position.Z - home.Position.Z)
	local state = humanoid:GetState()
	local now = os.clock()
	local lands = Trampoline.bounces({
		feetY = root.Position.Y - root.Size.Y / 2 - legs,
		matTop = home.Position.Y + thin / 2,
		away = flat.Magnitude,
		radius = wide / 2,
		sinceLast = now - lastBounce,
		carrying = character:GetAttribute("CarryingCatId") ~= nil,
		held = humanoid.Health <= 0
			or humanoid.Sit
			or root.Anchored
			or state == Enum.HumanoidStateType.Seated
			or state == Enum.HumanoidStateType.PlatformStanding
			or state == Enum.HumanoidStateType.Physics,
	})
	if not lands then
		return
	end
	lastBounce = now
	local speed = Trampoline.speed(Presets.trampoline.height, Workspace.Gravity)
	local moving = root.AssemblyLinearVelocity
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	root.AssemblyLinearVelocity = Vector3.new(moving.X, speed, moving.Z)
	dip(hit)
	for _, callback in listeners do
		task.spawn(callback, hit)
	end
end

local function follow(character: Model)
	local found = character:WaitForChild("Humanoid", 10)
	if found == nil or not found:IsA("Humanoid") then
		return
	end
	local humanoid = found :: Humanoid
	humanoid.StateChanged:Connect(
		function(_old: Enum.HumanoidStateType, new: Enum.HumanoidStateType)
			if new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
				landed(character, humanoid)
			end
		end
	)
end

function Trampoline.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(function(character: Model)
		task.spawn(follow, character)
	end)
	if player.Character ~= nil then
		task.spawn(follow, player.Character)
	end
end

return Trampoline
