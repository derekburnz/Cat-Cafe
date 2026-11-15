--!strict
-- #4227: the two small count bubbles on a Cannon picker card or the HUD's Cannon button: a pink Mythical one (the
-- Mythical rarity's colour, white number) and a shiny black Secret one (near black with the Secret starlight edge
-- and a soft glow), side by side from the right; each hides at 0 (Components/RareBubbleLogic).
--   RareBubbles.new(parent, position, zIndex) -> RareBubbles   anchored at its top right
--   bubbles:set(counts)
--   bubbles.frame

local Create = require(script.Parent.Create)
local Outline = require(script.Parent.Outline)
local RareBubbleLogic = require(script.Parent.RareBubbleLogic)
local Theme = require(script.Parent.Parent.Theme)

export type RareBubbles = {
	frame: Frame,
	set: (self: RareBubbles, counts: RareBubbleLogic.Counts) -> (),
}

local SIZE = 24
local MYTHIC = Color3.fromHex("FF5E7E")
local NIGHT = Color3.fromHex("16161D")
local NIGHT_SHINE = Color3.fromHex("5A4C9E")
local STAR = Color3.fromHex("E2D6FF")

local RareBubbles = {}
RareBubbles.__index = RareBubbles

local function bubble(
	parent: Instance,
	name: string,
	order: number,
	zIndex: number
): (Frame, TextLabel)
	local frame: Frame = Create("Frame", {
		Name = name,
		BackgroundColor3 = if name == "Secret" then Theme.colors.white else MYTHIC,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(SIZE, SIZE),
		LayoutOrder = order,
		Visible = false,
		ZIndex = zIndex,
		Parent = parent,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UISizeConstraint", { MinSize = Vector2.new(SIZE, SIZE) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }),
	})
	local stroke = Outline.border(frame, 2)
	if name == "Secret" then
		-- the shine: starlight top left fading to near black
		Create("UIGradient", {
			Rotation = 45,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, NIGHT_SHINE),
				ColorSequenceKeypoint.new(0.55, NIGHT),
				ColorSequenceKeypoint.new(1, NIGHT),
			}),
			Parent = frame,
		})
		stroke.Color = STAR
	end
	local label: TextLabel = Create("TextLabel", {
		Name = "Count",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, SIZE),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = if name == "Secret" then STAR else Theme.colors.white,
		Text = "0",
		ZIndex = zIndex + 1,
		Parent = frame,
	})
	Outline.text(label, 1.5)
	return frame, label
end

function RareBubbles.new(parent: Instance, position: UDim2, zIndex: number?): RareBubbles
	local self = setmetatable({}, RareBubbles) :: any
	local z = zIndex or 5
	local frame: Frame = Create("Frame", {
		Name = "RareBubbles",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = position,
		Size = UDim2.fromOffset(0, SIZE),
		ZIndex = z,
		Parent = parent,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 3),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self.frame = frame
	self._mythic, self._mythicText = bubble(frame, "Mythical", 1, z)
	self._secret, self._secretText = bubble(frame, "Secret", 2, z)
	return self :: RareBubbles
end

function RareBubbles.set(self: any, counts: RareBubbleLogic.Counts)
	self._mythic.Visible = counts.m > 0
	self._mythicText.Text = RareBubbleLogic.text(counts.m)
	self._secret.Visible = counts.s > 0
	self._secretText.Text = RareBubbleLogic.text(counts.s)
end

return RareBubbles
