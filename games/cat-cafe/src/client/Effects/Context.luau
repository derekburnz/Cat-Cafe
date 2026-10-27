--!strict
-- What every effect asks about this client: its budget (phone or PC, or the Low performance setting), where the
-- player is, day or night, Reduce Motion and the Screen shake setting, the folder that holds parts made on this
-- client (the server never sees it) and the camera shake.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Logic = require(script.Parent.Logic)
local Presets = require(script.Parent.Presets)

local Context = {}

Context.device = "high" :: string -- Presets.Tier of this device (Logic.tier)
Context.tier = "high" :: string -- Presets.Tier effects run at: the device's, or "low" in Low performance mode
Context.budget = Presets.budget.high
Context.screenShake = true -- the Screen shake setting
Context.lowPerformance = false -- the Low performance setting

local SHAKE_STEP = "CatCafeEffectsShake"

local folder: Folder? = nil
local rng = Random.new()

local function rebudget()
	local tier, budget = Logic.budgetFor(Context.device :: Presets.Tier, Context.lowPerformance)
	Context.tier = tier
	Context.budget = budget
end

function Context.init()
	Context.device = Logic.tier(UserInputService.TouchEnabled, UserInputService.KeyboardEnabled)
	rebudget()
end

-- Follows the player's Settings switches (Effects.applySettings). Turning Screen shake off also stops a shake that
-- is running; a new budget reaches each effect at its next once a second choice.
function Context.applySettings(settings: { [string]: unknown }?)
	local shake, lowPerformance = Logic.readSettings(settings)
	Context.screenShake = shake
	Context.lowPerformance = lowPerformance
	rebudget()
	if not shake then
		RunService:UnbindFromRenderStep(SHAKE_STEP)
	end
end

-- The player's position, or the camera's focus while the character is loading.
function Context.focus(): Vector3?
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root ~= nil and root:IsA("BasePart") then
		return root.Position
	end
	local camera = Workspace.CurrentCamera
	return if camera ~= nil then camera.Focus.Position else nil
end

function Context.distance(position: Vector3): number
	local focus = Context.focus()
	return if focus ~= nil then (position - focus).Magnitude else math.huge
end

-- ReplicatedStorage.Clock Phase (data-model section 9), the same attribute WorldController follows.
function Context.isNight(): boolean
	local clock = ReplicatedStorage:FindFirstChild("Clock")
	return clock ~= nil and clock:GetAttribute("Phase") == "night"
end

-- The player's Reduce Motion setting: no camera shake or flashes, fewer confetti pieces.
function Context.reducedMotion(): boolean
	return GuiService.ReducedMotionEnabled
end

-- A short camera shake for this player (a missed catch, being shoved), fading out over `seconds`. Runs after the
-- camera scripts each frame, so the offset never piles up; a new shake replaces one still running; off with Reduce
-- Motion or the Screen shake setting off.
function Context.shake(seconds: number, studs: number)
	if Context.reducedMotion() or not Context.screenShake then
		return
	end
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local began = os.clock()
	RunService:UnbindFromRenderStep(SHAKE_STEP)
	RunService:BindToRenderStep(SHAKE_STEP, Enum.RenderPriority.Camera.Value + 1, function()
		local t = os.clock() - began
		if t >= seconds then
			RunService:UnbindFromRenderStep(SHAKE_STEP)
			return
		end
		local k = (1 - t / seconds) * studs
		camera.CFrame = camera.CFrame * CFrame.new(rng:NextNumber(-k, k), rng:NextNumber(-k, k), 0)
	end)
end

function Context.folder(): Folder
	local existing = folder
	if existing ~= nil and existing.Parent ~= nil then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "ClientEffects"
	created.Parent = Workspace
	folder = created
	return created
end

-- A part made on this client for an effect: anchored, never collides, never in a raycast, casts no shadow.
function Context.effectPart(name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

-- The pivot of any model, or nil once it has left the world.
function Context.positionOf(instance: Instance): Vector3?
	if instance.Parent == nil then
		return nil
	end
	if instance:IsA("Model") then
		return (instance :: Model):GetPivot().Position
	elseif instance:IsA("BasePart") then
		return (instance :: BasePart).Position
	elseif instance:IsA("Attachment") then
		return (instance :: Attachment).WorldPosition
	end
	return nil
end

return Context
