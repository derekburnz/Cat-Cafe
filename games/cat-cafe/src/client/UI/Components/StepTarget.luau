--!strict
-- #2697 (Derek2 11-09: "HIGHTLIGHT/FLASH EVERYTHING make it insanely clear what to click with arrows and flashing
-- highlights around buttons for tutorial steps"): the one step-target highlight every tutorial step uses.
--   StepTarget.ui(target, on)   a button on screen: the pulsing gold ring (Components/TutorialGlow) and the big
--                               bouncing arrow at it (Components/TutorialArrow); off takes both away
--   StepTarget.new(parent)      the world half, one per client:
--     :show(target)             a thing in the world (the Bait bowl, the cannon, the alley's stray spot): a flashing
--                               gold Highlight round it and, while it is off screen, the big arrow at the screen's
--                               edge pointing toward it. The marker over it (Components/WorldMarker) says what it is
--                               and how far. Calling it again with the same target is free.
--     :hide(), :destroy()
-- The Highlight goes round the target's model when that model is one thing (StepTargetLogic.small), else round the
-- part alone, and never round a see-through spot. With Roblox's Reduce Motion on, the Highlight holds steady and the
-- arrow does not bob.
--
-- Roblox terms: a Highlight draws a coloured fill and outline round its Adornee (a model or a part); AlwaysOnTop shows
-- it through walls, so the bowl behind the cafe still shows where it is. It is made by this client, so no other player
-- sees it. WorldToViewportPoint turns a world position into a screen pixel and a depth.

local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Scale = require(script.Parent.Parent.Scale)
local StepTargetLogic = require(script.Parent.StepTargetLogic)
local Theme = require(script.Parent.Parent.Theme)
local TutorialArrow = require(script.Parent.TutorialArrow)
local TutorialGlow = require(script.Parent.TutorialGlow)

local StepTarget = {}
StepTarget.__index = StepTarget

StepTarget.NAME = "CatCafeStepTarget"
local ARROW = 64 -- design px, the size of TutorialArrow's
local FLASH_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local FILL_DIM, FILL_BRIGHT = 0.85, 0.45
local LOOK_SECONDS = 0.05 -- the edge arrow follows the camera at 20 Hz

export type Target = BasePart | Attachment | Vector3

export type StepTarget = {
	show: (self: StepTarget, target: Target) -> (),
	hide: (self: StepTarget) -> (),
	destroy: (self: StepTarget) -> (),
}

function StepTarget.ui(target: GuiObject?, on: boolean)
	TutorialGlow.set(target, on)
end

-- What the Highlight goes round: the target's model when it is one small thing, else the part, nil for a spot that
-- cannot be seen (a see-through marker part, a bare position).
local function adornee(target: Target): Instance?
	if typeof(target) ~= "Instance" then
		return nil
	end
	local part: BasePart? = nil
	if target:IsA("BasePart") then
		part = target
	elseif target:IsA("Attachment") and target.Parent and target.Parent:IsA("BasePart") then
		part = target.Parent :: BasePart
	end
	if part == nil then
		return nil
	end
	local model = part:FindFirstAncestorOfClass("Model")
	if
		model ~= nil
		and model ~= (Workspace :: Instance)
		and StepTargetLogic.small(model:GetExtentsSize())
	then
		return model
	end
	if part.Transparency >= 0.95 then
		return nil
	end
	return part
end

local function position(target: Target): Vector3?
	if typeof(target) == "Vector3" then
		return target
	elseif typeof(target) == "Instance" then
		if target:IsA("BasePart") then
			return target.Position
		elseif target:IsA("Attachment") then
			return target.WorldPosition
		end
	end
	return nil
end

function StepTarget.new(parent: Instance): StepTarget
	local self = setmetatable({}, StepTarget) :: any
	self._target = nil :: Target?
	self._loop = nil :: RBXScriptConnection?
	self._flash = nil :: Tween?
	local gui = Instance.new("ScreenGui")
	gui.Name = StepTarget.NAME
	gui.IgnoreGuiInset = true -- WorldToViewportPoint's pixels are the whole screen's
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4 -- under the windows, so an open window covers it
	gui.Enabled = false
	gui.Parent = parent
	self._gui = gui
	local arrow = TutorialArrow.make("EdgeArrow")
	arrow.Parent = gui
	self._arrow = arrow
	local highlight = Instance.new("Highlight")
	highlight.Name = "StepTargetHighlight"
	highlight.FillColor = Theme.colors.gold
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = FILL_BRIGHT
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Enabled = false
	highlight.Parent = gui
	self._highlight = highlight
	return self :: StepTarget
end

function StepTarget._place(self: any)
	local target: Target? = self._target
	local arrow: Frame = self._arrow
	local camera = Workspace.CurrentCamera
	local at = if target ~= nil then position(target) else nil
	if camera == nil or at == nil then
		arrow.Visible = false
		return
	end
	local px = ARROW * Scale.get()
	local point = camera:WorldToViewportPoint(at)
	local place = StepTargetLogic.edge(point, camera.ViewportSize, px)
	if place == nil then
		arrow.Visible = false
		return
	end
	arrow.Size = UDim2.fromOffset(px, px)
	arrow.Position = UDim2.fromOffset(place.x, place.y)
	arrow.Rotation = place.rotation
	local head = arrow:FindFirstChild("Head", true)
	if head and head:IsA("TextLabel") then
		(head :: TextLabel).TextSize = px
	end
	arrow.Visible = true
end

function StepTarget.show(self: any, target: Target)
	if self._target == target and self._gui.Enabled then
		return
	end
	self:hide()
	self._target = target
	local highlight: Highlight = self._highlight
	local around = adornee(target)
	highlight.Adornee = around
	highlight.Enabled = around ~= nil
	highlight.FillTransparency = FILL_BRIGHT
	if around ~= nil and not GuiService.ReducedMotionEnabled then
		local flash = TweenService:Create(highlight, FLASH_INFO, {
			FillTransparency = FILL_DIM,
			OutlineTransparency = 0.4,
		})
		flash:Play()
		self._flash = flash
	end
	self._gui.Enabled = true
	local clock = 0
	self._loop = RunService.Heartbeat:Connect(function(dt: number)
		clock += dt
		if clock < LOOK_SECONDS then
			return
		end
		clock = 0
		local part = if typeof(target) == "Instance" then target else nil
		if part ~= nil and part.Parent == nil then
			self:hide() -- streamed out or gone: the next step names a new target
			return
		end
		self:_place()
	end)
	self:_place()
end

function StepTarget.hide(self: any)
	local loop: RBXScriptConnection? = self._loop
	if loop then
		loop:Disconnect()
		self._loop = nil
	end
	local flash: Tween? = self._flash
	if flash then
		flash:Cancel()
		self._flash = nil
	end
	self._target = nil
	self._highlight.Enabled = false
	self._highlight.Adornee = nil
	self._arrow.Visible = false
	self._gui.Enabled = false
end

-- The edge arrow while it shows, or nil (the UI gate's scenes read it).
function StepTarget.edgeArrow(self: any): Frame?
	local arrow: Frame = self._arrow
	return if self._gui.Enabled and arrow.Visible then arrow else nil
end

function StepTarget.destroy(self: any)
	self:hide()
	self._gui:Destroy()
end

return StepTarget
