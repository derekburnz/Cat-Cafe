--!strict
-- The Roblox simulator look in three helpers: a dark outline round text, a dark outline round a shape,
-- and a top-to-bottom shade so flat colours read as chunky plastic.

local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)

local Outline = {}

-- Outline round the glyphs of a TextLabel or TextButton. Thicker text gets a thicker line by default.
function Outline.text(label: GuiObject, thickness: number?, color: Color3?): UIStroke
	local size = if label:IsA("TextLabel") or label:IsA("TextButton")
		then (label :: any).TextSize :: number
		else Theme.sizes.textBody
	return Create("UIStroke", {
		Name = "TextOutline",
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Color = color or Theme.colors.outline,
		LineJoinMode = Enum.LineJoinMode.Round,
		Thickness = thickness or (if size >= 20 then Theme.sizes.textOutline + 0.5 else 1.5),
		Parent = label,
	})
end

-- Outline round the box of a Frame or button (follows its UICorner).
function Outline.border(gui: GuiObject, thickness: number?, color: Color3?): UIStroke
	return Create("UIStroke", {
		Name = "Border",
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color or Theme.colors.outline,
		LineJoinMode = Enum.LineJoinMode.Round,
		Thickness = thickness or Theme.sizes.outline,
		Parent = gui,
	})
end

-- Lighter at the top, a touch darker at the bottom. UIGradient multiplies the background colour, so this
-- works on any fill without new colour tokens.
function Outline.shade(gui: GuiObject, depth: number?): UIGradient
	local bottom = 1 - (depth or 0.16)
	return Create("UIGradient", {
		Name = "Shade",
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(bottom, bottom, bottom)),
		Parent = gui,
	})
end

return Outline
