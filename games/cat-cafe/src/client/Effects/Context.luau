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

local LiveFlags = require(ReplicatedStorage.Shared.LiveFlags)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Logic = require(script.Parent.Logic)
local Presets = require(script.Parent.Presets)

local Context = {}

Context.device = "high" :: string -- Presets.Tier of this device (Logic.tier)
Context.tier = "high" :: string -- Presets.Tier effects run at: the device's, or "low" in Low performance mode
Context.budget = Presets.budget.high
Context.screenShake = true -- the Screen shake setting
Context.lowPerformance = false -- the Low performance setting
Context.console = false -- an Xbox or PlayStation (a ten-foot screen): Presets.budget.console (#2871)
Context.lite = false -- #3794: the lighter budget (Logic.wantsLite): a phone or graphics quality 1 to 3, switch on
local LITE_FLAG = "fxLite"

local SHAKE_STEP = "CatCafeEffectsShake"

local folder: Folder? = nil
local rng = Random.new()

-- The graphics quality the player set (1 to 10), or 0 for Automatic or when it cannot be read.
local function savedQuality(): number
	local ok, level = pcall(function(): number
		local saved = UserSettings():GetService("UserGameSettings").SavedQualityLevel
		return saved.Value
	end)
	return if ok and type(level) == "number" then level else 0
end

local function rebudget()
	Context.lite = Logic.wantsLite(
		LiveFlags.shown(
			LITE_FLAG,
			ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. LITE_FLAG)
		),
		Context.device :: Presets.Tier,
		savedQuality()
	)
	local tier, budget = Logic.budgetFor(
		Context.device :: Presets.Tier,
		Context.lowPerformance,
		Context.console,
		Context.lite
	)
	Context.tier = tier
	Context.budget = budget
end

function Context.init()
	Context.device = Logic.tier(UserInputService.TouchEnabled, UserInputService.KeyboardEnabled)
	Context.console = GuiService:IsTenFootInterface()
	rebudget()
	-- #3794: the switch and the graphics quality can change mid session; effects pick the budget up within a second
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. LITE_FLAG)
		:Connect(rebudget)
	pcall(function()
		local userSettings = UserSettings():GetService("UserGameSettings")
		userSettings:GetPropertyChangedSignal("SavedQualityLevel"):Connect(rebudget)
	end)
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

-- Calls `connect` with the RemoteEvent `name` as soon as it exists, now or whenever the server adds it: Net.on waits
-- with no end, and a feature's remotes only exist once the server has that feature.
function Context.whenRemote(name: string, connect: (RemoteEvent) -> ())
	task.spawn(function()
		local remotes = Remotes.folder()
		local function hook(child: Instance): boolean
			if child.Name ~= name or not child:IsA("RemoteEvent") then
				return false
			end
			connect(child :: RemoteEvent)
			return true
		end
		local existing = remotes:FindFirstChild(name)
		if existing ~= nil and hook(existing) then
			return
		end
		local waiting: RBXScriptConnection? = nil
		waiting = remotes.ChildAdded:Connect(function(child: Instance)
			if hook(child) and waiting ~= nil then
				waiting:Disconnect()
			end
		end)
	end)
end

return Context
