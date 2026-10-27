--!strict
-- Two cat ears poking up from behind a window or a button (UI plan 2026-10-27: Derek asked for menus that are
-- "obviously cat cafe themed"). Each ear is a square turned 45 degrees, its top corner the tip, with a smaller
-- pink square toward that tip for the inside. Put them in the same parent as the thing they sit behind, with a
-- lower ZIndex, so only the tips show.
--
-- Roblox terms: a child GuiObject turns with its parent's Rotation, so the pink inside needs no Rotation of its own.

local Create = require(script.Parent.Create)
local Outline = require(script.Parent.Outline)
local Theme = require(script.Parent.Parent.Theme)

export type Options = {
	size: number, -- the square before it turns, in pixels
	inset: number, -- each ear's centre from either side, as a share of the parent's width
	y: number, -- the ears' centre in pixels below the parent's top edge; the tips reach 0.7 * size above it
	outline: number?,
	zIndex: number?,
}

local CatEars = {}

function CatEars.add(parent: GuiObject, color: Color3, options: Options): { Frame }
	local radius = math.max(3, math.floor(options.size * 0.17))
	local ears: { Frame } = {}
	for _, x in { options.inset, 1 - options.inset } do
		local ear: Frame = Create("Frame", {
			Name = "Ear",
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(x, 0, 0, options.y),
			Size = UDim2.fromOffset(options.size, options.size),
			Rotation = 45,
			ZIndex = options.zIndex or 1,
			Parent = parent,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, radius) }),
			Create("Frame", {
				Name = "Inside",
				BackgroundColor3 = Theme.colors.pink,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.38, 0.38),
				Size = UDim2.fromScale(0.5, 0.5),
				ZIndex = options.zIndex or 1,
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, math.max(2, radius - 3)) }),
			}),
		})
		Outline.border(ear, options.outline or Theme.sizes.outline)
		table.insert(ears, ear)
	end
	return ears
end

-- Recolours the ears, for a button whose style changes.
function CatEars.setColor(ears: { Frame }, color: Color3)
	for _, ear in ears do
		ear.BackgroundColor3 = color
	end
end

return CatEars
