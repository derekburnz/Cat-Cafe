--!strict
-- Rounded window with a coloured header, outlined title, red X close button and a content frame, in the
-- simulator style (thick dark outline, shaded header). Used by every modal screen so they all share one look.
-- Cat cafe dress (UI plan 2026-10-27): two cat ears poke up from behind the header in its colour, a round icon
-- badge sits over the top-left corner, and faint paw prints dot the body behind the content. Each screen picks
-- its header colour and icon, so a window is known at a glance (Upgrades red, Decor gold, Cats sky).
--
-- Roblox terms: `frame` is a see-through holder that does not clip, so the ears and badge can stick out of the
-- window; the window itself is its child `Body`, which clips the content to the rounded corners. A child
-- GuiObject turns with its parent's Rotation, so each ear is one square turned 45 degrees with its pink inside.

local Button = require(script.Parent.Button)
local CatEars = require(script.Parent.CatEars)
local Create = require(script.Parent.Create)
local Outline = require(script.Parent.Outline)
local Theme = require(script.Parent.Parent.Theme)

export type Props = {
	title: string,
	subtitle: string?,
	size: UDim2?,
	parent: Instance?,
	onClose: (() -> ())?,
	name: string?,
	color: Color3?, -- the header and ears (default Theme.modal.header, caramel)
	icon: string?, -- an emoji on the round badge over the top-left corner; no badge when nil
}

export type Panel = {
	frame: Frame,
	body: Frame,
	content: Frame,
	setTitle: (self: Panel, title: string, subtitle: string?) -> (),
	destroy: (self: Panel) -> (),
}

local HEADER_HEIGHT = 56
local HEADER_SHADE = 0.86
local EAR_SIZE = 46 -- the square before it turns; about 26 px pokes above the window
local EAR_X = 0.17 -- each ear's centre, from either side
local BADGE_SIZE = 60
local BADGE_OVERHANG = 12 -- how far the badge sticks out past the window's top and left edges
-- faint paw prints behind the content: x and y scale, rotation
local PAWS: { { number } } = {
	{ 0.06, 0.3, -20 },
	{ 0.2, 0.62, 15 },
	{ 0.36, 0.9, -10 },
	{ 0.55, 0.4, 25 },
	{ 0.7, 0.75, -25 },
	{ 0.9, 0.22, 10 },
	{ 0.94, 0.92, -15 },
}

local Panel = {}
Panel.__index = Panel

function Panel.new(props: Props): Panel
	local color = props.color or Theme.modal.header
	local frame: Frame = Create("Frame", {
		Name = props.name or "Panel",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = props.size or UDim2.fromOffset(760, 520),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
	})

	-- behind the body, so only the top half of each ear shows
	CatEars.add(frame, color, {
		size = EAR_SIZE,
		inset = EAR_X,
		y = 6,
		outline = Theme.sizes.outline + 1,
	})

	local body: Frame = Create("Frame", {
		Name = "Body",
		BackgroundColor3 = Theme.modal.panel,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = frame,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius + 4) }),
	})
	Outline.border(body, Theme.sizes.outline + 1)

	for _, paw in PAWS do
		Create("TextLabel", {
			Name = "Paw",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(paw[1], paw[2]),
			Size = UDim2.fromOffset(40, 40),
			Rotation = paw[3],
			Text = "🐾",
			TextSize = 30,
			TextTransparency = 0.9,
			Parent = body,
		})
	end

	local header: Frame = Create("Frame", {
		Name = "Header",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
		ZIndex = 2,
		Parent = body,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius + 4) }),
		-- lighter at the top; the bottom 30% is flat so the square-off strip below matches it
		Create("UIGradient", {
			Name = "Shade",
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(
					0.7,
					Color3.new(HEADER_SHADE, HEADER_SHADE, HEADER_SHADE)
				),
				ColorSequenceKeypoint.new(1, Color3.new(HEADER_SHADE, HEADER_SHADE, HEADER_SHADE)),
			}),
		}),
		-- square off the bottom corners of the header
		Create("Frame", {
			Name = "Square",
			BackgroundColor3 = color:Lerp(Theme.colors.black, 1 - HEADER_SHADE),
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 1, -16),
			Size = UDim2.new(1, 0, 0, 16),
		}),
		-- dark rule between the header and the body
		Create("Frame", {
			Name = "Rule",
			BackgroundColor3 = Theme.colors.outline,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 1, -2),
			Size = UDim2.new(1, 0, 0, Theme.sizes.outline),
			ZIndex = 2,
		}),
	})

	-- the title starts right of the badge when there is one
	local textLeft = if props.icon
		then BADGE_SIZE - BADGE_OVERHANG + Theme.sizes.gap
		else Theme.sizes.padding + 4
	local title: TextLabel = Create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(textLeft, 0),
		Size = UDim2.new(
			1,
			-(textLeft + HEADER_HEIGHT + Theme.sizes.padding),
			0,
			if props.subtitle then 34 else HEADER_HEIGHT
		),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textTitle,
		TextColor3 = Theme.modal.headerText,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = if props.subtitle
			then Enum.TextYAlignment.Bottom
			else Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = props.title,
		Parent = header,
	})
	Outline.text(title, Theme.sizes.textOutline + 0.5)

	local subtitle: TextLabel = Create("TextLabel", {
		Name = "Subtitle",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(textLeft, 32),
		Size = UDim2.new(1, -(textLeft + HEADER_HEIGHT + Theme.sizes.padding), 0, 20),
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.headerText,
		TextTransparency = 0,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = props.subtitle or "",
		Visible = props.subtitle ~= nil,
		Parent = header,
	})
	Outline.text(subtitle, 1.5)

	local closeButton: Button.Button? = nil
	if props.onClose then
		closeButton = Button.new({
			name = "Close",
			text = "X",
			style = "close",
			size = UDim2.fromOffset(Theme.sizes.touchMin, Theme.sizes.touchMin),
			anchorPoint = Vector2.new(1, 0.5),
			position = UDim2.new(1, -8, 0.5, -2),
			textSize = Theme.sizes.textLarge + 2,
			sound = false, -- the modal's close swish is the sound
			onClick = props.onClose,
			parent = header,
		})
	end

	local content: Frame = Create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, HEADER_HEIGHT),
		Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT),
		ZIndex = 2,
		Parent = body,
	}, {
		Create("UIPadding", {
			PaddingTop = UDim.new(0, Theme.sizes.padding),
			PaddingBottom = UDim.new(0, Theme.sizes.padding),
			PaddingLeft = UDim.new(0, Theme.sizes.padding),
			PaddingRight = UDim.new(0, Theme.sizes.padding),
		}),
	})

	-- over the corner, above the body, tilted a little like a sticker
	if props.icon then
		local badge: Frame = Create("Frame", {
			Name = "Badge",
			BackgroundColor3 = color:Lerp(Theme.colors.white, 0.35),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(-BADGE_OVERHANG, -BADGE_OVERHANG),
			Size = UDim2.fromOffset(BADGE_SIZE, BADGE_SIZE),
			Rotation = -8,
			ZIndex = 3,
			Parent = frame,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			Create("TextLabel", {
				Name = "Icon",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = props.icon,
				TextSize = 32,
			}),
		})
		Outline.border(badge, Theme.sizes.outline + 1)
		Outline.shade(badge, 0.2)
	end

	local self = setmetatable({}, Panel) :: any
	self.frame = frame
	self.body = body
	self.content = content
	self._title = title
	self._subtitle = subtitle
	self._close = closeButton

	if props.parent then
		frame.Parent = props.parent
	end
	return self :: Panel
end

function Panel.setTitle(self: any, title: string, subtitle: string?)
	self._title.Text = title
	self._subtitle.Text = subtitle or ""
	self._subtitle.Visible = subtitle ~= nil
	self._title.Size = UDim2.new(
		1,
		-(self._title.Position.X.Offset + HEADER_HEIGHT + Theme.sizes.padding),
		0,
		if subtitle then 34 else HEADER_HEIGHT
	)
	self._title.TextYAlignment = if subtitle
		then Enum.TextYAlignment.Bottom
		else Enum.TextYAlignment.Center
end

function Panel.destroy(self: any)
	if self._close then
		self._close:destroy()
	end
	self.frame:Destroy()
end

return Panel
