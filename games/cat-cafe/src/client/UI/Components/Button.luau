--!strict
-- Chunky rounded button in the Roblox simulator style (Derek 2026-10-27: "copy the ui button background from the
-- popular games"): a dark outline round a face that runs from a light top colour to a deeper bottom one over a
-- darker lip, with faint tile marks, a light inner rim and a gloss on its top half (Theme.button), a white label
-- with a thick dark outline and an optional icon, press squash and hover grow (mouse only).
-- Works with mouse, touch and gamepad through GuiButton.Activated. A press plays uiClick (or the `sound` prop's cue);
-- a press on a greyed button plays uiError so the player hears why nothing happened.

local UserInputService = game:GetService("UserInputService")

local CatEars = require(script.Parent.CatEars)
local Create = require(script.Parent.Create)
local Outline = require(script.Parent.Outline)
local Sound = require(script.Parent.Sound)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Tween)

export type Style = "primary" | "secondary" | "gold" | "berry" | "ghost" | "danger" | "close"

-- "row": icon then text on one line. "tile": a big icon above a short label (the HUD menu squares).
-- A row with `iconSize` draws its icon as its own picture that size at the left, then the text (the HUD's pills).
export type Layout = "row" | "tile"

export type Props = {
	text: string?,
	icon: string?,
	iconSize: number?, -- row layout: the icon's own size in px, bigger than the text (default: inline with the text)
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
	-- cue played on press; default "uiClick", false when the action already sounds (a modal's open or close swish)
	sound: (string | false)?,
	name: string?,
	zIndex: number?,
	ears: boolean?, -- two cat ears in the face colour poke up from behind the top edge (the HUD's menu pills)
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

-- Each style's colours come from Theme.button. `outlined` labels are white with a dark outline (coloured
-- buttons); the light ghost button keeps dark text. Berry (pink) is for Equip Best and other "make my team
-- better" buttons.
type Look = { top: Color3, bottom: Color3, depth: Color3, text: Color3, outlined: boolean }

local function look(name: string, text: Color3, outlined: boolean): Look
	local fill = Theme.button[name]
	return {
		top = fill.top,
		bottom = fill.bottom,
		depth = fill.depth,
		text = text,
		outlined = outlined,
	}
end

local STYLES: { [string]: Look } = {
	primary = look("primary", Theme.colors.white, true),
	secondary = look("secondary", Theme.colors.white, true),
	gold = look("gold", Theme.colors.white, true),
	berry = look("berry", Theme.colors.white, true),
	ghost = look("ghost", Theme.colors.cocoa, false),
	danger = look("danger", Theme.colors.white, true),
	close = look("close", Theme.colors.white, true),
	disabled = look("disabled", Theme.colors.paper, true),
}

local HOVER_SCALE = 1.05
local TILE = 18 -- px between the face's tile marks
local TILE_TRANSPARENCY = 0.9
local GLOSS = NumberSequence.new(0.62, 0.94) -- the top half's shine, strongest at the top
local EAR_SIZE = 18 -- the `ears` prop: about 8 px of each ear shows above the button, inside the 8 px list gap
local EAR_INSET = 0.16

local Button = {}
Button.__index = Button

local function brighten(color: Color3, amount: number): Color3
	return color:Lerp(Theme.colors.white, amount)
end

-- The face is white under a UIGradient, so the gradient's colours are the face's colours.
local function fill(colors: Look, lighten: number): ColorSequence
	return ColorSequence.new(brighten(colors.top, lighten), brighten(colors.bottom, lighten))
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
		BackgroundColor3 = Theme.colors.white,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -depth),
		ZIndex = (props.zIndex or 1) + 1,
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
	})
	local gradient: UIGradient = Create("UIGradient", {
		Name = "Fill",
		Rotation = 90,
		Color = fill(STYLES[style], 0),
		Parent = face,
	})
	local radius = Theme.sizes.radius
	-- faint tile marks over the fill, once the texture is uploaded (Theme.textures.buttonTiles)
	local tiles = Theme.textures.buttonTiles
	if tiles ~= "" then
		Create("ImageLabel", {
			Name = "Tiles",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Image = tiles,
			ImageColor3 = Theme.colors.black,
			ImageTransparency = TILE_TRANSPARENCY,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(TILE, TILE),
			ZIndex = (props.zIndex or 1) + 1,
			Parent = face,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, radius) }) })
	end
	-- the shine on the top half and a light rim just inside the outline
	Create("Frame", {
		Name = "Gloss",
		BackgroundColor3 = Theme.colors.white,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(4, 3),
		Size = UDim2.new(1, -8, 0.42, 0),
		ZIndex = (props.zIndex or 1) + 1,
		Parent = face,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, math.max(2, radius - 3)) }),
		Create("UIGradient", { Rotation = 90, Transparency = GLOSS }),
	})
	Create("Frame", {
		Name = "Rim",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		ZIndex = (props.zIndex or 1) + 1,
		Parent = face,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, math.max(2, radius - 2)) }),
		Create("UIStroke", {
			Color = Theme.colors.white,
			Thickness = 1.5,
			Transparency = 0.6,
		}),
	})

	local isTile = layout == "tile"
	local iconSize: number? = if not isTile and props.icon then props.iconSize else nil
	local iconLeft = if iconSize then 6 + iconSize + 4 else 8 -- where a row's text starts
	-- the icon sits in the text unless it is drawn on its own (tiles, and rows with iconSize)
	local inlineIcon = props.icon ~= nil and not isTile and iconSize == nil
	local textSize = props.textSize or Theme.sizes.textBody
	local label: TextLabel = Create("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		AnchorPoint = if isTile then Vector2.new(0, 1) else Vector2.new(),
		Size = if isTile
			then UDim2.new(1, -8, 0, textSize + 6)
			else UDim2.new(1, -(iconLeft + (if iconSize then 6 else 8)), 1, 0),
		Position = if isTile then UDim2.new(0, 4, 1, -4) else UDim2.fromOffset(iconLeft, 0),
		FontFace = props.font or Theme.fonts.display,
		TextSize = textSize,
		TextColor3 = STYLES[style].text,
		Text = if inlineIcon
			then (props.icon :: string) .. " " .. (props.text or "")
			else props.text or "",
		TextTruncate = Enum.TextTruncate.AtEnd,
		-- next to a big icon the text reads from the icon and shrinks or wraps rather than cut off ("Walk it home")
		TextXAlignment = if iconSize then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
		TextScaled = iconSize ~= nil,
		ZIndex = (props.zIndex or 1) + 2,
		Parent = face,
	})
	if iconSize then
		Create("UITextSizeConstraint", { MaxTextSize = textSize, MinTextSize = 10, Parent = label })
	end
	local textOutline = Outline.text(label, if textSize >= 20 then 3 else 2)

	-- Tiles carry a big icon above the label; rows with iconSize a big icon left of it.
	local icon: TextLabel? = nil
	if iconSize then
		icon = Create("TextLabel", {
			Name = "Icon",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6, 0.5, 0),
			Size = UDim2.fromOffset(iconSize, iconSize),
			FontFace = Theme.fonts.display,
			TextScaled = true,
			TextColor3 = Theme.colors.white,
			Text = props.icon,
			ZIndex = (props.zIndex or 1) + 2,
			Parent = face,
		})
	elseif isTile and props.icon then
		icon = Create("TextLabel", {
			Name = "Icon",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 2),
			Size = UDim2.new(1, -4, 1, -(textSize + 6)),
			FontFace = Theme.fonts.display,
			TextScaled = true,
			TextColor3 = Theme.colors.white,
			Text = props.icon,
			ZIndex = (props.zIndex or 1) + 2,
			Parent = face,
		})
	end

	-- behind the depth frame, so only the tips show above the button; they squash and grow with it
	local ears: { Frame }? = if props.ears
		then CatEars.add(root, STYLES[style].top, {
			size = EAR_SIZE,
			inset = EAR_INSET,
			y = 5,
			zIndex = (props.zIndex or 1) - 1,
		})
		else nil

	local uiScale: UIScale = Create("UIScale", { Parent = root })

	local self = setmetatable({}, Button) :: any
	self.instance = root
	self.face = face
	self.label = label
	self.icon = icon
	self._icon = props.icon
	self._inlineIcon = inlineIcon
	self._textOutline = textOutline
	self._depth = depthFrame
	self._scale = uiScale
	self._style = style
	self._enabled = enabled
	self._connections = {} :: { RBXScriptConnection }
	self._onClick = props.onClick
	self._sound = if props.sound == nil then "uiClick" else props.sound

	local function applyStyle()
		local colors = STYLES[if self._enabled then self._style else "disabled"]
		gradient.Color = fill(colors, 0)
		depthFrame.BackgroundColor3 = colors.depth
		label.TextColor3 = colors.text
		textOutline.Enabled = colors.outlined
		if ears then
			CatEars.setColor(ears, colors.top)
		end
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
				gradient.Color = fill(STYLES[self._style], 0.12)
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
			-- A greyed button stays Active so a tap on it bonks; a drag that starts on it (a phone scroll) never
			-- fires Activated, so scrolling past "can't afford" rows stays quiet (reviewer N57).
			if not self._enabled then
				Sound.play("uiError")
				return
			end
			local sound = self._sound
			if sound then
				Sound.play(sound)
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
	self.label.Text = if self._inlineIcon then self._icon .. " " .. text else text
end

function Button.setStyle(self: any, style: Style)
	self._style = style
	self._applyStyle()
end

function Button.setEnabled(self: any, enabled: boolean)
	self._enabled = enabled
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
