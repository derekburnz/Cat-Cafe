--!strict
-- Chunky rounded button with a darker bottom edge, press squash and hover brighten (mouse only).
-- Works with mouse, touch and gamepad through GuiButton.Activated.

local UserInputService = game:GetService("UserInputService")

local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Tween)

export type Style = "primary" | "secondary" | "gold" | "ghost" | "danger"

export type Props = {
	text: string?,
	style: Style?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	textSize: number?,
	font: Font?,
	parent: Instance?,
	layoutOrder: number?,
	enabled: boolean?,
	onClick: (() -> ())?,
	name: string?,
	zIndex: number?,
}

export type Button = {
	instance: Frame,
	face: TextButton,
	label: TextLabel,
	setText: (self: Button, text: string) -> (),
	setStyle: (self: Button, style: Style) -> (),
	setEnabled: (self: Button, enabled: boolean) -> (),
	destroy: (self: Button) -> (),
}

local STYLES: { [string]: { face: Color3, depth: Color3, text: Color3 } } = {
	primary = {
		face = Theme.colors.good,
		depth = Theme.colors.goodDark,
		text = Theme.colors.goodText,
	},
	secondary = {
		face = Theme.colors.sky,
		depth = Theme.colors.skyDark,
		text = Theme.colors.skyText,
	},
	gold = { face = Theme.colors.gold, depth = Theme.colors.goldDark, text = Theme.colors.goldText },
	ghost = { face = Theme.colors.paper, depth = Theme.colors.line, text = Theme.colors.cocoa },
	danger = { face = Theme.colors.warn, depth = Theme.colors.warnDark, text = Theme.colors.paper },
	disabled = {
		face = Theme.colors.disabled,
		depth = Theme.colors.disabledDark,
		text = Theme.colors.disabledText,
	},
}

local Button = {}
Button.__index = Button

local function brighten(color: Color3, amount: number): Color3
	return color:Lerp(Theme.colors.white, amount)
end

function Button.new(props: Props): Button
	local depth = Theme.sizes.buttonDepth
	local style: Style = props.style or "primary"
	local enabled = if props.enabled == nil then true else props.enabled :: boolean

	local root: Frame = Create("Frame", {
		Name = props.name or "Button",
		BackgroundTransparency = 1,
		Size = props.size or UDim2.fromOffset(140, 44),
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchorPoint or Vector2.new(),
		LayoutOrder = props.layoutOrder or 0,
		ZIndex = props.zIndex or 1,
	})

	local depthFrame: Frame = Create("Frame", {
		Name = "Depth",
		BackgroundColor3 = STYLES[style].depth,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, depth),
		Size = UDim2.new(1, 0, 1, -depth),
		ZIndex = props.zIndex or 1,
		Parent = root,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })

	local face: TextButton = Create("TextButton", {
		Name = "Face",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = STYLES[style].face,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -depth),
		ZIndex = (props.zIndex or 1) + 1,
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
	})

	local label: TextLabel = Create("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		FontFace = props.font or Theme.fonts.display,
		TextSize = props.textSize or Theme.sizes.textBody,
		TextColor3 = STYLES[style].text,
		Text = props.text or "",
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = (props.zIndex or 1) + 2,
		Parent = face,
	})

	local uiScale: UIScale = Create("UIScale", { Parent = root })

	local self = setmetatable({}, Button) :: any
	self.instance = root
	self.face = face
	self.label = label
	self._depth = depthFrame
	self._scale = uiScale
	self._style = style
	self._enabled = enabled
	self._connections = {} :: { RBXScriptConnection }
	self._onClick = props.onClick

	local function applyStyle()
		local colors = STYLES[if self._enabled then self._style else "disabled"]
		face.BackgroundColor3 = colors.face
		depthFrame.BackgroundColor3 = colors.depth
		label.TextColor3 = colors.text
	end
	self._applyStyle = applyStyle
	applyStyle()

	local pressed = false
	local function setPressed(down: boolean)
		if pressed == down then
			return
		end
		pressed = down
		Tween.press(uiScale, down)
		Tween.to(
			face,
			Tween.FAST,
			{ Position = UDim2.fromOffset(0, if down then depth - 1 else 0) }
		)
	end

	table.insert(
		self._connections,
		face.InputBegan:Connect(function(input: InputObject)
			if not self._enabled then
				return
			end
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				setPressed(true)
			end
		end)
	)
	table.insert(
		self._connections,
		face.InputEnded:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				setPressed(false)
			end
		end)
	)
	table.insert(
		self._connections,
		face.MouseEnter:Connect(function()
			if self._enabled and UserInputService.MouseEnabled then
				face.BackgroundColor3 = brighten(STYLES[self._style].face, 0.12)
			end
		end)
	)
	table.insert(
		self._connections,
		face.MouseLeave:Connect(function()
			setPressed(false)
			applyStyle()
		end)
	)
	table.insert(
		self._connections,
		face.Activated:Connect(function()
			if not self._enabled then
				return
			end
			local onClick = self._onClick
			if onClick then
				onClick()
			end
		end)
	)

	if props.parent then
		root.Parent = props.parent
	end
	return self :: Button
end

function Button.setText(self: any, text: string)
	self.label.Text = text
end

function Button.setStyle(self: any, style: Style)
	self._style = style
	self._applyStyle()
end

function Button.setEnabled(self: any, enabled: boolean)
	self._enabled = enabled
	self.face.Active = enabled
	self._applyStyle()
end

function Button.destroy(self: any)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	self.instance:Destroy()
end

return Button
