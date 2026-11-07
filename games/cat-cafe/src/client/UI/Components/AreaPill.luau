--!strict
-- #1919 (first-hour.md section 5): the small "Park 4 / 10" pill in the area's colour at the top left of the new-cat
-- reveal and the bait Tame card. Components/IndexHints.areaLine gives the words; nil hides the pill.
--   AreaPill.new(parent, position, zIndex) -> TextLabel
--   AreaPill.set(pill, line)

local Create = require(script.Parent.Create)
local IndexHints = require(script.Parent.IndexHints)
local Outline = require(script.Parent.Outline)
local Theme = require(script.Parent.Parent.Theme)

local AreaPill = {}

function AreaPill.new(parent: Instance, position: UDim2, zIndex: number): TextLabel
	local pill: TextLabel = Create("TextLabel", {
		Name = "AreaCount",
		BackgroundColor3 = Theme.colors.caramel,
		BorderSizePixel = 0,
		Position = position,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 24),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.colors.white,
		Text = "",
		Visible = false,
		ZIndex = zIndex,
		Parent = parent,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
	})
	Outline.text(pill, 1.5)
	Outline.border(pill, 2)
	return pill
end

function AreaPill.set(pill: TextLabel, line: IndexHints.Line?)
	pill.Visible = line ~= nil
	if line then
		pill.Text = line.text
		pill.BackgroundColor3 = Theme.areaColors[line.area] or Theme.colors.caramel
	end
end

return AreaPill
