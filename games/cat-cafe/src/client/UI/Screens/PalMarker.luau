--!strict
-- The pal arrived marker (F92, playing-together.md section 5): a player who joins through a pal's invite or by
-- following them spawns at the pal's front door, and when the pal is out in an area the joiner's HUD shows a bubble
-- "Sam is in the Park" with the pal's headshot over the travel button that gets them there (the Cannon, or Areas
-- before the cannon), and that button glows with a gold ring that breathes (steady with Roblox's Reduce Motion).
-- A tap on the bubble, a press of the button, MARKER_SECONDS or the pal leaving the server takes both away.
--   show(text, userId, button)  the bubble over `button` (a travel button's instance) and its ring
--   hide()
--   palId() -> number?          whose marker is up

local GuiService = game:GetService("GuiService")

local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local PalsLogic = require(script.Parent.Parent.Components.PalsLogic)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)

export type PalMarker = {
	show: (self: PalMarker, text: string, userId: number, button: GuiObject) -> (),
	hide: (self: PalMarker) -> (),
	palId: (self: PalMarker) -> number?,
	destroy: (self: PalMarker) -> (),
}

local MARKER_SECONDS = 45
local FACE = 30
local BUBBLE_H = Scale.tapHeight(42) -- a tap closes it, so it is a full tap tall on a phone
local POINTER = 12
local BREATHE = TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

local PalMarker = {}
PalMarker.__index = PalMarker

function PalMarker.new(): PalMarker
	local self = setmetatable({}, PalMarker) :: any
	self._token = 0
	self._palId = nil :: number?
	self._pulse = nil :: Tween?
	self._pressed = nil :: RBXScriptConnection?

	local bubble: TextButton = Create("TextButton", {
		Name = "PalMarker",
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -(POINTER + 2)),
		Size = UDim2.fromOffset(0, BUBBLE_H),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.hud.panel,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 12,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	Outline.border(bubble, Theme.sizes.outline, Theme.colors.gold)
	-- the face and the words in a row of their own, so the pointer stays out of the row's layout
	local row: Frame = Create("Frame", {
		Name = "Row",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, BUBBLE_H),
		ZIndex = 13,
		Parent = bubble,
	}, {
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 14),
		}),
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._face = Create("ImageLabel", {
		Name = "Face",
		BackgroundColor3 = Theme.colors.cream,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(FACE, FACE),
		LayoutOrder = 1,
		ZIndex = 13,
		Parent = row,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) }) :: ImageLabel
	self._text = Create("TextLabel", {
		Name = "Line",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, BUBBLE_H),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 1,
		TextColor3 = Theme.hud.text,
		Text = "",
		LayoutOrder = 2,
		ZIndex = 13,
		Parent = row,
	}) :: TextLabel
	-- the little pointer under the bubble, down at the button
	self._pointer = Create("Frame", {
		Name = "Pointer",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(POINTER, POINTER),
		Rotation = 45,
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		ZIndex = 11,
		Parent = bubble,
	})
	self._bubble = bubble
	-- the ring round the button, a little wider than it
	local ring: Frame = Create("Frame", {
		Name = "PalGlow",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 10, 1, 10),
		Visible = false,
		ZIndex = 10,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius + 4) }) })
	self._stroke =
		Create("UIStroke", { Color = Theme.colors.gold, Thickness = 4, Parent = ring }) :: UIStroke
	self._ring = ring
	bubble.Activated:Connect(function()
		self:hide()
	end)
	bubble:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_keepOnScreen()
	end)
	return self :: PalMarker
end

function PalMarker.palId(self: any): number?
	return self._palId
end

function PalMarker.show(self: any, text: string, userId: number, button: GuiObject)
	self:hide()
	self._token += 1
	local token = self._token
	self._palId = userId
	self._face.Image = PalsLogic.headshot(userId)
	self._text.Text = text
	self._bubble.Parent = button
	self._bubble.Visible = true
	Tween.popIn(self._bubble, 0.7)
	self._ring.Parent = button
	self._ring.Visible = true
	self._stroke.Transparency = 0
	if not GuiService.ReducedMotionEnabled then
		local pulse = Tween.to(self._stroke, BREATHE, { Transparency = 0.7 })
		self._pulse = pulse
	end
	self:_keepOnScreen()
	-- pressing the button it points at is the point: the marker goes. On a touch screen a Components/Button's face
	-- takes no input (its Hit pad does), so the first button that takes input is the one.
	local target: GuiButton? = nil
	if button:IsA("GuiButton") and button.Interactable then
		target = button :: GuiButton
	else
		for _, piece in button:GetDescendants() do
			if piece:IsA("GuiButton") and piece.Interactable then
				target = piece :: GuiButton
				break
			end
		end
	end
	if target then
		self._pressed = target.Activated:Connect(function()
			self:hide()
		end)
	end
	task.delay(MARKER_SECONDS, function()
		if self._token == token then
			self:hide()
		end
	end)
end

-- Centred over its button, slid sideways as far as it takes to stay 6 px inside the screen (a small phone, the Cannon
-- button near the right edge); the pointer slides back the other way so it still points at the button.
function PalMarker._keepOnScreen(self: any)
	local bubble: TextButton = self._bubble
	local button = bubble.Parent
	local gui = bubble:FindFirstAncestorWhichIsA("LayerCollector")
	if not (button and button:IsA("GuiObject") and gui) then
		return
	end
	local scale = math.max(Scale.get(), 0.01)
	local margin = 6
	local centre = button.AbsolutePosition.X + button.AbsoluteSize.X / 2
	local half = bubble.AbsoluteSize.X / 2
	local width = gui.AbsoluteSize.X
	local shift = 0
	if centre + half + margin > width then
		shift = width - margin - (centre + half)
	elseif centre - half - margin < 0 then
		shift = margin - (centre - half)
	end
	local offset = math.floor(shift / scale + 0.5)
	bubble.Position = UDim2.new(0.5, offset, 0, -(POINTER + 2))
	self._pointer.Position = UDim2.new(0.5, -offset, 1, 0)
end

function PalMarker.hide(self: any)
	self._token += 1
	self._palId = nil
	local pulse: Tween? = self._pulse
	if pulse then
		pulse:Cancel()
		self._pulse = nil
	end
	local pressed: RBXScriptConnection? = self._pressed
	if pressed then
		pressed:Disconnect()
		self._pressed = nil
	end
	self._bubble.Visible = false
	self._ring.Visible = false
end

function PalMarker.destroy(self: any)
	self:hide()
	self._bubble:Destroy()
	self._ring:Destroy()
end

return PalMarker
