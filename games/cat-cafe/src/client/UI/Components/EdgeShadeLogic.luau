--!strict
-- Numbers for Components/EdgeShade (#3702): the four strips of the screen's edge shade. Each strip is anchored to
-- its edge and covers `size` of the screen; its gradient runs from the edge (rotation turns it to face inward) to
-- clear. Top and bottom are a little deeper than the sides, so on a wide screen the shade reads as an even frame.
-- The middle of the screen is never covered: opposite strips together stay under the whole.

local EdgeShadeLogic = {}

EdgeShadeLogic.FADE = 0.3 -- seconds in and out; slow enough that nothing flashes
EdgeShadeLogic.EDGE_TRANSPARENCY = 0.45 -- at the very edge of the screen
EdgeShadeLogic.MID_TRANSPARENCY = 0.82 -- halfway into the strip
EdgeShadeLogic.DISPLAY_ORDER = 21 -- just over the modal layer (20), under toasts
-- The hint ("Tap to skip") is a small dark pill, so it reads over anything, and sits HINT_AT of the way down the
-- screen: under the animation in the middle and above the HUD's bottom row of tiles, where it was drawn over
-- their labels at first (Review-QA's Studio look at #3708).
-- #3858 (Review-QA's Studio look at #3849): on a new save the see-through pill sat over the tutorial strip's Buy
-- buttons and a gift card's Close and was hard to read, so it is now nearly solid, bold and ringed in white.
EdgeShadeLogic.HINT_SIZE = 20
EdgeShadeLogic.HINT_AT = 0.74
EdgeShadeLogic.HINT_FILL = 0.08 -- the pill's transparency
EdgeShadeLogic.HINT_RING = 2 -- the white ring's thickness

export type Edge = { name: string, anchor: Vector2, size: Vector2, rotation: number }

-- A UIGradient runs left to right at rotation 0, so its start (the dark end) is the left. Rotation 90 starts at the
-- top, 180 at the right, 270 at the bottom.
EdgeShadeLogic.EDGES = {
	{ name = "Left", anchor = Vector2.new(0, 0), size = Vector2.new(0.2, 1), rotation = 0 },
	{ name = "Top", anchor = Vector2.new(0, 0), size = Vector2.new(1, 0.26), rotation = 90 },
	{ name = "Right", anchor = Vector2.new(1, 0), size = Vector2.new(0.2, 1), rotation = 180 },
	{ name = "Bottom", anchor = Vector2.new(0, 1), size = Vector2.new(1, 0.26), rotation = 270 },
} :: { Edge }

-- The share of the screen's width and height left wholly clear in the middle.
function EdgeShadeLogic.clear(): (number, number)
	local wide, tall = 1, 1
	for _, edge in EdgeShadeLogic.EDGES do
		if edge.size.X < 1 then
			wide -= edge.size.X
		end
		if edge.size.Y < 1 then
			tall -= edge.size.Y
		end
	end
	return wide, tall
end

return EdgeShadeLogic
