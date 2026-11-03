--!strict
-- Chunky rounded button in the Roblox simulator style (Derek 2026-10-27: "copy the ui button background from the
-- popular games"): a dark outline round a face that runs from a light top colour to a deeper bottom one over a
-- darker lip, with faint tile marks, a light inner rim and a gloss on its top half (Theme.button), a white label
-- with a thick dark outline and an optional icon, press squash and hover grow (mouse only).
-- Works with mouse, touch and gamepad through GuiButton.Activated. A press plays uiClick (or the `sound` prop's cue);
-- a press on a greyed button plays uiError so the player hears why nothing happened.
-- On a touch screen an invisible pad (Hit) over the button takes its taps and reaches out to a finger's 44 px when the
-- button is drawn smaller, so the look stays and the target grows (Derek 2026-11-02: "make sure the ui is fine for all
-- devices").

local UserInputService = game:GetService("UserInputService")

local Create = require(script.Parent.Create)
local IconArt = require(script.Parent.IconArt)
local Outline = require(script.Parent.Outline)
local Scale = require(script.Parent.Parent.Scale)
local Sound = require(script.Parent.Sound)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Tween)

export type Style =
	"primary"
	| "secondary"
	| "gold"
	| "berry"
	| "ghost"
	| "danger"
	| "close"
	| "teal"
	| "purple"
	| "sky"
	| "slate"
	| "store"

-- "row": icon then text on one line. "tile": a big icon above a short label (the HUD menu squares).
-- "clean" (Derek 2026-11-03, "Build it as shown"; assets/cat-cafe/ui/icons-clean-2026-11-03): a rounded square with
-- a bright two-colour fill, a darker lip, a thick dark outline and one bold symbol (`image`, the glyph until it
-- loads), its label under the square in white with a dark outline; `size` holds the square and the label.
-- "wide": the clean tile drawn wide, the symbol at its left and the label inside, big (the Store).
-- "tile" has the clean look too since 2026-11-03, its short label inside the square under the picture (the HUD's
-- bottom row and corner on touch screens, where the labels under would stack too high).
-- A row with `iconSize` draws its icon as its own picture that size at the left, then the text (the HUD's pills).
-- An inline icon with a whole picture in Theme.glyphImages (the golden fish on a price, F97 section 4) is drawn as that
-- picture just before the text, the two centred together, the emoji showing until the picture loads.
export type Layout = "row" | "tile" | "clean" | "wide"

export type Props = {
	text: string?,
	icon: string?,
	image: string?, -- clean and wide layouts: the symbol's uploaded picture (the icon glyph shows until it loads)
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
	teal = look("teal", Theme.colors.white, true),
	purple = look("purple", Theme.colors.white, true),
	sky = look("sky", Theme.colors.white, true),
	slate = look("slate", Theme.colors.white, true),
	store = look("store", Theme.colors.white, true),
	disabled = look("disabled", Theme.colors.paper, true),
}

local HOVER_SCALE = 1.05
local TILE = 18 -- px between the face's tile marks
local TILE_TRANSPARENCY = 0.9
local GLOSS = NumberSequence.new(0.62, 0.94) -- the top half's shine, strongest at the top
-- the clean tiles (2026-11-03 mockup): outline and depth in design px, the corner and the symbol as shares of the
-- square's side, where the darker lip starts down the face, the light bar at the top
local CLEAN_OUTLINE = 4
local CLEAN_DEPTH = 5
local CLEAN_CORNER = 0.26
local CLEAN_SYMBOL = 0.72
local CLEAN_LIP = 0.84
local CLEAN_SHINE_TRANSPARENCY = 0.6

local Button = {}
Button.__index = Button

local function brighten(color: Color3, amount: number): Color3
	return color:Lerp(Theme.colors.white, amount)
end

-- The face is white under a UIGradient, so the gradient's colours are the face's colours.
local function fill(colors: Look, lighten: number): ColorSequence
	return ColorSequence.new(brighten(colors.top, lighten), brighten(colors.bottom, lighten))
end

-- A clean tile's face: top to bottom colour, then a band of the darker depth colour along the bottom (the lip).
local function cleanFill(colors: Look, lighten: number): ColorSequence
	local lip = brighten(colors.depth, lighten)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, brighten(colors.top, lighten)),
		ColorSequenceKeypoint.new(CLEAN_LIP, brighten(colors.bottom, lighten)),
		ColorSequenceKeypoint.new(CLEAN_LIP + 0.01, lip),
		ColorSequenceKeypoint.new(1, lip),
	})
end

function Button.new(props: Props): Button
	local style: Style = props.style or "primary"
	local layout: Layout = props.layout or "row"
	local enabled = if props.enabled == nil then true else props.enabled :: boolean
	local textSize = props.textSize or Theme.sizes.textBody
	local square = layout == "clean" or layout == "wide" -- the symbol drawn by the clean code below
	local clean = square or layout == "tile"
	local depth = if clean then CLEAN_DEPTH else Theme.sizes.buttonDepth
	local band = if layout == "clean" then textSize + 4 else 0 -- the label's strip under a clean square
	local size = props.size or UDim2.fromOffset(140, 44)
	local radius = Theme.sizes.radius
	local side = math.min(size.X.Offset, size.Y.Offset - band) -- a clean square's side (the wide tile's height)
	if clean and side > 0 then
		radius = math.floor(side * CLEAN_CORNER)
	end
	local paint: (Look, number) -> ColorSequence = if clean then cleanFill else fill

	local root: Frame = Create("Frame", {
		Name = props.name or "Button",
		BackgroundTransparency = 1,
		Size = size,
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchorPoint or Vector2.new(),
		LayoutOrder = props.layoutOrder or 0,
		ZIndex = props.zIndex or 1,
	})

	-- The depth frame spans the whole button so its outline wraps the face and the bottom edge together. A clean
	-- tile's bottom edge is the outline's own dark colour, a thicker outline along the foot.
	local depthFrame: Frame = Create("Frame", {
		Name = "Depth",
		BackgroundColor3 = if clean then Theme.colors.outline else STYLES[style].depth,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -band),
		ZIndex = props.zIndex or 1,
		Parent = root,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, radius) }) })
	Outline.border(depthFrame, if clean then CLEAN_OUTLINE else nil)

	local face: TextButton = Create("TextButton", {
		Name = "Face",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.colors.white,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -(band + depth)),
		ZIndex = (props.zIndex or 1) + 1,
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, radius) }),
	})
	local gradient: UIGradient = Create("UIGradient", {
		Name = "Fill",
		Rotation = 90,
		Color = paint(STYLES[style], 0),
		Parent = face,
	})
	-- faint tile marks over the fill, once the texture is uploaded (Theme.textures.buttonTiles); clean tiles have none
	local tiles = Theme.textures.buttonTiles
	if clean then
		-- the light bar along the top of a clean face
		Create("Frame", {
			Name = "Shine",
			BackgroundColor3 = Theme.colors.white,
			BackgroundTransparency = CLEAN_SHINE_TRANSPARENCY,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 3),
			Size = UDim2.new(1, -math.floor(radius * 1.2), 0, 5),
			ZIndex = (props.zIndex or 1) + 1,
			Parent = face,
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	elseif tiles ~= "" then
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
	-- the shine on the top half and a light rim just inside the outline (the older look; clean tiles have the bar)
	if not clean then
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
	end

	local isTile = layout == "tile"
	local iconSize: number? = if not isTile
			and not clean
			and props.icon
		then props.iconSize
		else nil
	local iconLeft = if iconSize then 6 + iconSize + 4 else 8 -- where a row's text starts
	-- the icon sits in the text unless it is drawn on its own (tiles, clean tiles and rows with iconSize)
	local inlineIcon = props.icon ~= nil and not isTile and not clean and iconSize == nil
	local faceH = side - depth -- a clean face's height
	local symbol = math.max(8, math.floor(faceH * (if layout == "wide" then 0.9 else CLEAN_SYMBOL)))
	-- an inline glyph with a whole picture: the picture and the text side by side in a centred row
	local inlinePicture = if inlineIcon then Theme.glyphImages[props.icon :: string] else nil
	local pictureRow: Frame? = nil
	if inlinePicture and inlinePicture ~= "" then
		inlineIcon = false
		pictureRow = Create("Frame", {
			Name = "Row",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -16, 1, 0),
			Position = UDim2.fromOffset(8, 0),
			ZIndex = (props.zIndex or 1) + 2,
			Parent = face,
		}, {
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
	end
	local label: TextLabel = Create("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		AnchorPoint = if isTile
			then Vector2.new(0, 1)
			elseif layout == "clean" then Vector2.new(0.5, 1)
			else Vector2.new(),
		Size = if isTile
			then UDim2.new(1, -8, 0, textSize + 6)
			elseif
				layout == "clean"
			then UDim2.new(1, 28, 0, band) -- a long word may pass the square's sides
			elseif layout == "wide" then UDim2.new(1, -(symbol + 18), 1, 0)
			elseif pictureRow then UDim2.fromScale(0, 1)
			else UDim2.new(1, -(iconLeft + (if iconSize then 6 else 8)), 1, 0),
		AutomaticSize = if pictureRow then Enum.AutomaticSize.X else Enum.AutomaticSize.None,
		LayoutOrder = 2,
		Position = if isTile
			then UDim2.new(0, 4, 1, -4)
			elseif layout == "clean" then UDim2.fromScale(0.5, 1)
			elseif layout == "wide" then UDim2.fromOffset(symbol + 12, 0)
			elseif pictureRow then UDim2.new()
			else UDim2.fromOffset(iconLeft, 0),
		FontFace = props.font or Theme.fonts.display,
		TextSize = textSize,
		TextColor3 = STYLES[style].text,
		Text = if inlineIcon
			then (props.icon :: string) .. " " .. (props.text or "")
			else props.text or "",
		-- beside a picture the label sizes itself to its text, so nothing to cut
		TextTruncate = if pictureRow or layout == "clean"
			then Enum.TextTruncate.None
			else Enum.TextTruncate.AtEnd,
		-- next to a big icon the text reads from the icon and shrinks or wraps rather than cut off ("Walk it home")
		TextXAlignment = if iconSize or layout == "wide"
			then Enum.TextXAlignment.Left
			else Enum.TextXAlignment.Center,
		TextScaled = iconSize ~= nil,
		ZIndex = (props.zIndex or 1) + 2,
		-- a clean square's label sits under it on the button itself, so it stays put while the face presses down
		Parent = if layout == "clean" then root else pictureRow or face,
	})
	if iconSize then
		Create("UITextSizeConstraint", { MaxTextSize = textSize, MinTextSize = 10, Parent = label })
	elseif pictureRow then
		Create("UIPadding", { PaddingRight = UDim.new(0, 2), Parent = label }) -- room for the text outline
	end
	local textOutline = Outline.text(label, if square or textSize >= 20 then 3 else 2)

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
	elseif pictureRow then
		local side = math.floor(textSize * 1.3)
		icon = Create("TextLabel", {
			Name = "Icon",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(side, side),
			FontFace = Theme.fonts.display,
			TextScaled = true,
			TextColor3 = Theme.colors.white,
			Text = props.icon,
			LayoutOrder = 1,
			ZIndex = (props.zIndex or 1) + 2,
			Parent = pictureRow,
		})
	elseif square and props.icon then
		-- the one bold symbol: centred in a clean square, at the left of the wide tile
		icon = Create("TextLabel", {
			Name = "Icon",
			BackgroundTransparency = 1,
			AnchorPoint = if layout == "wide" then Vector2.new(0, 0.5) else Vector2.new(0.5, 0.5),
			Position = if layout == "wide"
				then UDim2.new(0, 8, 0.5, 0)
				else UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(symbol, symbol),
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

	if icon then
		IconArt.set(icon, props.icon) -- the drawn picture from the icon sheet, when it has one for this glyph
		if clean and props.image then
			IconArt.setImage(icon, props.image)
		end
	end

	local uiScale: UIScale = Create("UIScale", { Parent = root })

	-- The thing a finger presses: the face, or on a touch screen the pad over the whole button. The pad reaches a
	-- finger's 44 real px at the screen's UI scale on each side the button is sized in design px (a side sized as a
	-- share of its parent, a third of a card, is wide already), never smaller than the button; it follows the scale
	-- and the button's Size, not its size on screen, so it costs nothing while the button squashes or a window pops.
	-- The face stops taking input so the pad is the one button there.
	local connections: { RBXScriptConnection } = {}
	local target: GuiButton = face
	if Scale.isTouch() then
		local pad: TextButton = Create("TextButton", {
			Name = "Hit",
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			ZIndex = (props.zIndex or 1) + 3,
			Parent = root,
		})
		face.Interactable = false
		local function fit()
			local reach = (Scale.TAP + 1) / math.max(Scale.get(), 0.01)
			local size = root.Size
			local function grow(side: UDim): number
				return if side.Scale == 0 then math.max(0, math.ceil(reach - side.Offset)) else 0
			end
			pad.Size = UDim2.new(1, grow(size.X), 1, grow(size.Y))
		end
		table.insert(connections, root:GetPropertyChangedSignal("Size"):Connect(fit))
		local scaled = Scale.changed:Connect(fit)
		table.insert(
			connections,
			root.Destroying:Connect(function()
				scaled:Disconnect()
			end)
		)
		table.insert(connections, scaled :: any)
		fit()
		target = pad
	end

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
	self._connections = connections
	self._onClick = props.onClick
	self._sound = if props.sound == nil then "uiClick" else props.sound

	local function applyStyle()
		local colors = STYLES[if self._enabled then self._style else "disabled"]
		gradient.Color = paint(colors, 0)
		depthFrame.BackgroundColor3 = if clean then Theme.colors.outline else colors.depth
		label.TextColor3 = colors.text
		textOutline.Enabled = colors.outlined
		if icon then
			IconArt.setTransparency(icon, if self._enabled then 0 else 0.45)
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
		target.InputBegan:Connect(function(input: InputObject)
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
		target.InputEnded:Connect(function(input: InputObject)
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
		target.MouseEnter:Connect(function()
			if self._enabled and UserInputService.MouseEnabled then
				hovered = true
				gradient.Color = paint(STYLES[self._style], 0.12)
				if not pressed then
					Tween.to(uiScale, Tween.FAST, { Scale = HOVER_SCALE })
				end
			end
		end)
	)
	table.insert(
		self._connections,
		target.MouseLeave:Connect(function()
			hovered = false
			setPressed(false)
			Tween.to(uiScale, Tween.FAST, { Scale = 1 })
			applyStyle()
		end)
	)
	table.insert(
		self._connections,
		target.Activated:Connect(function()
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
