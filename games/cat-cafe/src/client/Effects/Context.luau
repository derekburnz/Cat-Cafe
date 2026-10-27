--!strict
-- What every effect asks about this client: its budget (phone or PC), where the player is, day or night, Reduce
-- Motion, and the folder that holds parts made on this client. The server never sees that folder.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Logic = require(script.Parent.Logic)
local Presets = require(script.Parent.Presets)

local Context = {}

Context.tier = "high" :: string -- Presets.Tier
Context.budget = Presets.budget.high

local folder: Folder? = nil

function Context.init()
	Context.tier = Logic.tier(UserInputService.TouchEnabled, UserInputService.KeyboardEnabled)
	Context.budget = Presets.budget[Context.tier]
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
