--!strict
-- Where the touch Net button sits (F93, catch-rework.md section 1: "placed just above and left of the jump button").
-- Roblox draws its own jump button in screen pixels, 70 px at (W - 95, H - 90) on a small screen (the short side
-- 500 px or less) and 120 px at (W - 170, H - 210) on a bigger one (PlayerModule's TouchJump). The Net button goes
-- up and left of it, its right edge a little in from the jump button's left edge so one thumb rolls between them.
--   jump(viewport) -> (Vector2, number)      the jump button's top left corner and size, in screen pixels
--   place(viewport) -> (Vector2, number)     the Net button's top left corner and size, in screen pixels
-- Pure, so the cloud spec runner checks it.

local NetButtonPlace = {}

NetButtonPlace.SMALL_SCREEN = 500 -- TouchJump's cut-off on the short side
NetButtonPlace.GAP = 8 -- between the Net button's bottom and the jump button's top
NetButtonPlace.TUCK = 0.3 -- of the Net button's size, how far its right edge reaches past the jump button's left

function NetButtonPlace.jump(viewport: Vector2): (Vector2, number)
	if math.min(viewport.X, viewport.Y) <= NetButtonPlace.SMALL_SCREEN then
		return Vector2.new(viewport.X - 95, viewport.Y - 90), 70
	end
	return Vector2.new(viewport.X - 170, viewport.Y - 210), 120
end

function NetButtonPlace.place(viewport: Vector2): (Vector2, number)
	local jumpAt, jumpSize = NetButtonPlace.jump(viewport)
	local size = if jumpSize <= 70 then 64 else 96
	local right = jumpAt.X + math.floor(size * NetButtonPlace.TUCK)
	local bottom = jumpAt.Y - NetButtonPlace.GAP
	return Vector2.new(right - size, bottom - size), size
end

return NetButtonPlace
