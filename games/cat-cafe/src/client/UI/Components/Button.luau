--!strict
-- Chunky rounded button in the Roblox simulator style: dark outline, shaded face over a darker bottom edge,
-- white outlined label with an optional icon, press squash and hover grow (mouse only).
-- Works with mouse, touch and gamepad through GuiButton.Activated.

local UserInputService = game:GetService("UserInputService")

local Create = require(script.Parent.Create)
local Outline = require(script.Parent.Outline)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Tween)

export type Style = "primary" | "secondary" | "gold" | "ghost" | "danger" | "close"

-- "row": icon then text on one line. "tile": a big icon above a short label (the HUD menu squares).
export type Layout = "row" | "tile"

export type Props = {
	text: string?,
	icon: string?,
	layout: Layout?,
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
	icon: TextLabel?,
	setText: (self: Button, text: string) -> (),
	setStyle: (self: Button, style: Style) -> (),
	setEnabled: (self: Button, enabled: boolean) -> (),
	destroy: (self: Button) -> (),
}

-- `outlined` labels are white with a dark outline (coloured buttons); the light ghost button keeps dark text.
local STYLES: { [string]: { face: Color3, depth: Color3, text: Color3, outlined: boolean } } = {
	primary = {
		face = Theme.colors.good,
		depth = Theme.colors.goodDark,
		text = Theme.colors.white,
		outlined = true,
	},
	secondary = {
		face = Theme.colors.sky,
		depth = Theme.colors.skyDark,
		text = Theme.colors.white,
		outlined = true,
	},
	gold = {
		face = Theme.colors.gold,
		depth = Theme.colors.goldDark,
		text = Theme.colors.white,
		outlined = true,
	},
	ghost = {
		face = Theme.colors.paper,
		depth = Theme.colors.line,
		text = Theme.colors.cocoa,
		outlined = false,
	},
	danger = {
		face = Theme.colors.warn,
		depth = Theme.colors.warnDark,
		text = Theme.colors.white,
		outlined = true,
	},
	close = {
		face = Theme.colors.red,
		depth = Theme.colors.redDark,
		text = Theme.colors.white,
		outlined = true,
	},
	disabled = {
		face = Theme.colors.disabled,
		depth = Theme.colors.disabledDark,
		text = Theme.colors.paper,
		outlined = true,
	},
}

local HOVER_SCALE = 1.05

local Button = {}
Button.__index = Button

local function brighten(color: Color3, amount: number): Color3
	return color:Lerp(Theme.colors.white, amount)
end

function Button.new(props: Props): Button
	local depth = Theme.sizes.buttonDepth
	local style: Style = props.style or "primary"
	local layout: Layout = props.layout or "row"
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

	-- The depth frame spans the whole button so its outline wraps the face and the bottom edge together.
	local depthFrame: Frame = Create("Frame", {
		Name = "Depth",
		BackgroundColor3 = STYLES[style].depth,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = props.zIndex or 1,
		Parent = root,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	Outline.border(depthFrame)

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
	Outline.shade(face)

	local isTile = layout == "tile"
	local textSize = props.textSize or Theme.sizes.textBody
	local label: TextLabel = Create("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		AnchorPoint = if isTile then Vector2.new(0, 1) else Vector2.new(),
		Size = if isTile then UDim2.new(1, -8, 0, textSize + 6) else UDim2.new(1, -16, 1, 0),
		Position = if isTile then UDim2.new(0, 4, 1, -4) else UDim2.fromOffset(8, 0),
		FontFace = props.font or Theme.fonts.display,
		TextSize = textSize,
		TextColor3 = STYLES[style].text,
		Text = if props.icon and not isTile
			then props.icon .. " " .. (props.text or "")
			else props.text or "",
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = (props.zIndex or 1) + 2,
		Parent = face,
	})
	local textOutline = Outline.text(label)

	-- Tiles carry a big icon above the label.
	local icon: TextLabel? = nil
	if isTile and props.icon then
		icon = Create("TextLabel", {
			Name = "Icon",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 4),
			Size = UDim2.new(1, -8, 1, -(textSize + 12)),
			FontFace = Theme.fonts.display,
			TextScaled = true,
			TextColor3 = Theme.colors.white,
			Text = props.icon,
			ZIndex = (props.zIndex or 1) + 2,
			Parent = face,
		})
	end

	local uiScale: UIScale = Create("UIScale", { Parent = root })

	local self = setmetatable({}, Button) :: any
	self.instance = root
	self.face = face
	self.label = label
	self.icon = icon
	self._icon = props.icon
	self._isTile = isTile
	self._textOutline = textOutline
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
		textOutline.Enabled = colors.outlined
		if icon then
			icon.TextTransparency = if self._enabled then 0 else 0.45
		end
	end
	self._applyStyle = applyStyle
	applyStyle()

	local pressed = false
	local hovered = false
	local function setPressed(down: boolean)
		if pressed == down then
			return
		end
		pressed = down
		if down or not hovered then
			Tween.press(uiScale, down)
		else
			Tween.to(uiScale, Tween.FAST, { Scale = HOVER_SCALE })
		end
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
				hovered = true
				face.BackgroundColor3 = brighten(STYLES[self._style].face, 0.12)
				if not pressed then
					Tween.to(uiScale, Tween.FAST, { Scale = HOVER_SCALE })
				end
			end
		end)
	)
	table.insert(
		self._connections,
		face.MouseLeave:Connect(function()
			hovered = false
			setPressed(false)
			Tween.to(uiScale, Tween.FAST, { Scale = 1 })
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
	self.label.Text = if self._icon and not self._isTile then self._icon .. " " .. text else text
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
