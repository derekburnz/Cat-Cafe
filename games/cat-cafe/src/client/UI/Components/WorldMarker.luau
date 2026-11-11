--!strict
-- A BillboardGui marker over a world target with a label and live distance ("Check in · 24 m").
-- Used for the carry indicator (own cafe door) and tutorial arrows. One marker per purpose.
-- It draws within 500 studs, or `maxDistance` when given (#1458).
-- #2697: a `flash` marker (the tutorial's) also flashes its target and points at it from the screen's edge while it is
-- off screen (Components/StepTarget), and its arrow is twice the size and bobs (still with Reduce Motion on).
-- #3055 (Derek2: "make it much smaller and less obnoxious"): a `compact` marker (the carry marker's "Bring it here" and
-- "Check in here") is one quiet line, the label and "24 m" side by side on a see-through pill with a thin outline
-- and a small arrow, 160 x 36 px (half the area of the full 180 x 64); the tutorial's flash marker keeps its size.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Create = require(script.Parent.Create)
local Outline = require(script.Parent.Outline)
local StepTarget = require(script.Parent.StepTarget)
local Theme = require(script.Parent.Parent.Theme)

export type Target = BasePart | Attachment | Vector3

export type WorldMarker = {
	show: (self: WorldMarker, target: Target, label: string, color: Color3?) -> (),
	hide: (self: WorldMarker) -> (),
	destroy: (self: WorldMarker) -> (),
}

local WorldMarker = {}
WorldMarker.__index = WorldMarker

local BIG_ARROW = 36 -- a flash marker's arrow, px
local BOB = 8 -- px it bobs down toward the target
local COMPACT_W, COMPACT_H, COMPACT_ARROW = 160, 24, 12 -- #3055: the carry marker's card and arrow, px

function WorldMarker.new(
	parent: Instance,
	name: string,
	maxDistance: number?,
	flash: boolean?,
	compact: boolean?
): WorldMarker
	local self = setmetatable({}, WorldMarker) :: any
	self._attachment = nil :: Attachment?
	self._loop = nil :: RBXScriptConnection?
	self._step = if flash then StepTarget.new(parent) else nil

	local small = compact == true and not flash
	self._compact = small
	local arrowSize = if flash then BIG_ARROW elseif small then COMPACT_ARROW else 20
	local cardH = if small then COMPACT_H else 44
	local billboard: BillboardGui = Create("BillboardGui", {
		Name = name,
		AlwaysOnTop = true,
		Size = UDim2.fromOffset(
			if small then COMPACT_W else 180,
			cardH + arrowSize + (if flash then BOB + 4 else 0)
		),
		StudsOffset = Vector3.new(0, if small then 3 else 4, 0),
		MaxDistance = maxDistance or 500,
		ResetOnSpawn = false,
		Enabled = false,
		Parent = parent,
	})
	self._billboard = billboard
	local card: Frame = Create("Frame", {
		Name = "Card",
		BackgroundColor3 = Theme.hud.panel,
		BackgroundTransparency = if small then 0.25 else Theme.hud.panelTransparency,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, cardH),
		Parent = billboard,
	}, {
		Create(
			"UICorner",
			{ CornerRadius = UDim.new(0, if small then cardH // 2 else Theme.sizes.radius) }
		),
		Create("UIStroke", { Color = Theme.colors.gold, Thickness = if small then 1 else 2 }),
	})
	self._card = card
	self._label = Create("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Position = if small then UDim2.fromOffset(9, 0) else UDim2.fromOffset(10, 4),
		Size = if small then UDim2.new(1, -52, 1, 0) else UDim2.new(1, -20, 0, 22),
		FontFace = Theme.fonts.display,
		TextSize = if small then 13 else 16,
		TextXAlignment = if small then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
		TextColor3 = Theme.hud.text,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		Parent = card,
	})
	self._distance = Create("TextLabel", {
		Name = "Distance",
		BackgroundTransparency = 1,
		Position = if small then UDim2.new(1, -44, 0, 0) else UDim2.fromOffset(10, 24),
		Size = if small then UDim2.new(0, 36, 1, 0) else UDim2.new(1, -20, 0, 16),
		FontFace = Theme.fonts.body,
		TextSize = if small then 11 else 12,
		TextXAlignment = if small then Enum.TextXAlignment.Right else Enum.TextXAlignment.Center,
		TextColor3 = Theme.hud.subtext,
		Text = "",
		Parent = card,
	})
	-- arrow under the card pointing at the target
	local arrow: TextLabel = Create("TextLabel", {
		Name = "Arrow",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, cardH),
		Size = UDim2.fromOffset(arrowSize + 4, arrowSize),
		FontFace = Theme.fonts.display,
		TextSize = arrowSize,
		TextColor3 = Theme.colors.gold,
		Text = "▼",
		Parent = billboard,
	})
	if flash then
		Outline.text(arrow, 2)
		if not GuiService.ReducedMotionEnabled then
			TweenService:Create(
				arrow,
				TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Position = UDim2.new(0.5, 0, 0, 44 + BOB) }
			):Play()
		end
	end
	return self :: WorldMarker
end

local function targetPosition(target: Target): Vector3
	if typeof(target) == "Vector3" then
		return target
	elseif typeof(target) == "Instance" then
		if target:IsA("BasePart") then
			return target.Position
		elseif target:IsA("Attachment") then
			return target.WorldPosition
		end
	end
	return Vector3.zero
end

function WorldMarker.show(self: any, target: Target, label: string, color: Color3?)
	self:_clear()
	local step: StepTarget.StepTarget? = self._step
	if step then
		step:show(target) -- free when the target is the same
	end
	local billboard: BillboardGui = self._billboard
	if typeof(target) == "Vector3" then
		local attachment = Instance.new("Attachment")
		attachment.Name = "MarkerAnchor"
		attachment.WorldPosition = target
		attachment.Parent = workspace.Terrain
		self._attachment = attachment
		billboard.Adornee = attachment
	else
		billboard.Adornee = target :: Instance
	end
	self._label.Text = label
	self._card.UIStroke.Color = color or Theme.colors.gold
	billboard.Enabled = true

	local accumulator = 0
	self._loop = RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < 0.2 then
			return
		end
		accumulator = 0
		local character = Players.LocalPlayer and Players.LocalPlayer.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if rootPart and rootPart:IsA("BasePart") then
			local distance = (rootPart.Position - targetPosition(target)).Magnitude
			local metres = math.floor(distance / 3.57 + 0.5) -- studs to metres-ish
			self._distance.Text = (if self._compact then "%d m" else "%d m away"):format(metres)
		else
			self._distance.Text = ""
		end
	end)
end

function WorldMarker.hide(self: any)
	self:_clear()
	local step: StepTarget.StepTarget? = self._step
	if step then
		step:hide()
	end
end

function WorldMarker._clear(self: any)
	local loop: RBXScriptConnection? = self._loop
	if loop then
		loop:Disconnect()
		self._loop = nil
	end
	local attachment: Attachment? = self._attachment
	if attachment then
		attachment:Destroy()
		self._attachment = nil
	end
	self._billboard.Enabled = false
	self._billboard.Adornee = nil
end

function WorldMarker.destroy(self: any)
	self:hide()
	local step: StepTarget.StepTarget? = self._step
	if step then
		step:destroy()
	end
	self._billboard:Destroy()
end

return WorldMarker
