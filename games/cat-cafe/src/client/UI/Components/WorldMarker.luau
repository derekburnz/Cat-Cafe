--!strict
-- A BillboardGui marker over a world target with a label and live distance ("Check in · 24 m").
-- Used for the carry indicator (own cafe door) and tutorial arrows. One marker per purpose.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)

export type Target = BasePart | Attachment | Vector3

export type WorldMarker = {
	show: (self: WorldMarker, target: Target, label: string, color: Color3?) -> (),
	hide: (self: WorldMarker) -> (),
	destroy: (self: WorldMarker) -> (),
}

local WorldMarker = {}
WorldMarker.__index = WorldMarker

function WorldMarker.new(parent: Instance, name: string): WorldMarker
	local self = setmetatable({}, WorldMarker) :: any
	self._attachment = nil :: Attachment?
	self._loop = nil :: RBXScriptConnection?

	local billboard: BillboardGui = Create("BillboardGui", {
		Name = name,
		AlwaysOnTop = true,
		Size = UDim2.fromOffset(180, 64),
		StudsOffset = Vector3.new(0, 4, 0),
		MaxDistance = 500,
		ResetOnSpawn = false,
		Enabled = false,
		Parent = parent,
	})
	self._billboard = billboard
	local card: Frame = Create("Frame", {
		Name = "Card",
		BackgroundColor3 = Theme.hud.panel,
		BackgroundTransparency = Theme.hud.panelTransparency,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 44),
		Parent = billboard,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = Theme.colors.gold, Thickness = 2 }),
	})
	self._card = card
	self._label = Create("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -20, 0, 22),
		FontFace = Theme.fonts.display,
		TextSize = 16,
		TextColor3 = Theme.hud.text,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		Parent = card,
	})
	self._distance = Create("TextLabel", {
		Name = "Distance",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 24),
		Size = UDim2.new(1, -20, 0, 16),
		FontFace = Theme.fonts.body,
		TextSize = 12,
		TextColor3 = Theme.hud.subtext,
		Text = "",
		Parent = card,
	})
	-- arrow under the card pointing at the target
	Create("TextLabel", {
		Name = "Arrow",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 44),
		Size = UDim2.fromOffset(24, 20),
		FontFace = Theme.fonts.display,
		TextSize = 20,
		TextColor3 = Theme.colors.gold,
		Text = "▼",
		Parent = billboard,
	})
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
	self:hide()
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
			self._distance.Text = ("%d m away"):format(math.floor(distance / 3.57 + 0.5)) -- studs to metres-ish
		else
			self._distance.Text = ""
		end
	end)
end

function WorldMarker.hide(self: any)
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
	self._billboard:Destroy()
end

return WorldMarker
