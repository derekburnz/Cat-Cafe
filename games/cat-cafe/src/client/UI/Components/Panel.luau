--!strict
-- Rounded window with a caramel header, title, optional close button and a content frame.
-- Used by every modal screen so they all share one look.

local Button = require(script.Parent.Button)
local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)

export type Props = {
	title: string,
	subtitle: string?,
	size: UDim2?,
	parent: Instance?,
	onClose: (() -> ())?,
	name: string?,
}

export type Panel = {
	frame: Frame,
	content: Frame,
	setTitle: (self: Panel, title: string, subtitle: string?) -> (),
	destroy: (self: Panel) -> (),
}

local HEADER_HEIGHT = 56

local Panel = {}
Panel.__index = Panel

function Panel.new(props: Props): Panel
	local frame: Frame = Create("Frame", {
		Name = props.name or "Panel",
		BackgroundColor3 = Theme.modal.panel,
		BorderSizePixel = 0,
		Size = props.size or UDim2.fromOffset(760, 520),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ClipsDescendants = true,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius + 4) }),
		Create("UIStroke", {
			Color = Theme.colors.caramelDark,
			Thickness = Theme.sizes.stroke,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})

	local header: Frame = Create("Frame", {
		Name = "Header",
		BackgroundColor3 = Theme.modal.header,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
		Parent = frame,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius + 4) }),
		-- square off the bottom corners of the header
		Create("Frame", {
			Name = "Square",
			BackgroundColor3 = Theme.modal.header,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 1, -16),
			Size = UDim2.new(1, 0, 0, 16),
		}),
	})

	local title: TextLabel = Create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(Theme.sizes.padding + 4, 0),
		Size = UDim2.new(
			1,
			-(HEADER_HEIGHT + Theme.sizes.padding * 2),
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

	local subtitle: TextLabel = Create("TextLabel", {
		Name = "Subtitle",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(Theme.sizes.padding + 4, 32),
		Size = UDim2.new(1, -(HEADER_HEIGHT + Theme.sizes.padding * 2), 0, 20),
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.headerText,
		TextTransparency = 0.15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = props.subtitle or "",
		Visible = props.subtitle ~= nil,
		Parent = header,
	})

	local closeButton: Button.Button? = nil
	if props.onClose then
		closeButton = Button.new({
			name = "Close",
			text = "X",
			style = "ghost",
			size = UDim2.fromOffset(Theme.sizes.touchMin, Theme.sizes.touchMin),
			anchorPoint = Vector2.new(1, 0.5),
			position = UDim2.new(1, -8, 0.5, -2),
			textSize = Theme.sizes.textLarge,
			onClick = props.onClose,
			parent = header,
		})
	end

	local content: Frame = Create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, HEADER_HEIGHT),
		Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT),
		Parent = frame,
	}, {
		Create("UIPadding", {
			PaddingTop = UDim.new(0, Theme.sizes.padding),
			PaddingBottom = UDim.new(0, Theme.sizes.padding),
			PaddingLeft = UDim.new(0, Theme.sizes.padding),
			PaddingRight = UDim.new(0, Theme.sizes.padding),
		}),
	})

	local self = setmetatable({}, Panel) :: any
	self.frame = frame
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
		-(HEADER_HEIGHT + Theme.sizes.padding * 2),
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
