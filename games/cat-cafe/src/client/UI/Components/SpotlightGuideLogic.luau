--!strict
-- The pure part of Components/SpotlightGuide (#3555): where the words go round a lit button and whether a press
-- landed outside it. No instances, so it runs in the cloud tests.

local SpotlightGuideLogic = {}

SpotlightGuideLogic.GAP = 10 -- px between the lit button and the words
SpotlightGuideLogic.MARGIN = 8 -- px the words keep from the screen's edge
SpotlightGuideLogic.PAD = 6 -- px round the button that still count as on it

-- The top left corner of words `caption` px big for a button at `position`, `size` px, on a `screen` px screen.
-- Under the button when there is room (the tutorial's arrow comes from above when it can), else over it, else as
-- low as the screen allows; centred on the button and kept `MARGIN` px inside the screen's sides.
function SpotlightGuideLogic.captionAt(
	position: Vector2,
	size: Vector2,
	screen: Vector2,
	caption: Vector2
): Vector2
	local gap, margin = SpotlightGuideLogic.GAP, SpotlightGuideLogic.MARGIN
	local x = position.X + size.X / 2 - caption.X / 2
	x = math.clamp(x, margin, math.max(margin, screen.X - caption.X - margin))
	local under = position.Y + size.Y + gap
	if under + caption.Y + margin <= screen.Y then
		return Vector2.new(x, under)
	end
	local over = position.Y - gap - caption.Y
	if over >= margin then
		return Vector2.new(x, over)
	end
	return Vector2.new(x, math.max(margin, screen.Y - caption.Y - margin))
end

-- Whether a press at `point` landed outside the lit button (with `PAD` px of grace round it): a press on the dim.
function SpotlightGuideLogic.outside(point: Vector2, position: Vector2, size: Vector2): boolean
	local pad = SpotlightGuideLogic.PAD
	return point.X < position.X - pad
		or point.Y < position.Y - pad
		or point.X > position.X + size.X + pad
		or point.Y > position.Y + size.Y + pad
end

return SpotlightGuideLogic
