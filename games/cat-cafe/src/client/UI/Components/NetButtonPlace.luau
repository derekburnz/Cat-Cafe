--!strict
-- Where the touch Net button sits (F93, catch-rework.md section 1: "placed just above and left of the jump button").
-- Roblox draws its own jump button in screen pixels, 70 px at (W - 95, H - 90) on a small screen (the short side
-- 500 px or less) and 120 px at (W - 170, H - 210) on a bigger one (PlayerModule's TouchJump). The Net button goes
-- up and left of it, its right edge a little in from the jump button's left edge so one thumb rolls between them.
--   jump(viewport) -> (Vector2, number)      the jump button's top left corner and size, in screen pixels
--   place(viewport) -> (Vector2, number)     the Net button's top left corner and size, in screen pixels
--   tackle(viewport) -> (Vector2, number)    #2510: the touch Tackle button's, left of the Net button at its height,
--                                            the same size, so the thumb rolls Jump, Net, Tackle
-- Pure, so the cloud spec runner checks it.

local NetButtonPlace = {}

NetButtonPlace.SMALL_SCREEN = 500 -- TouchJump's cut-off on the short side
NetButtonPlace.GAP = 8 -- between the Net button's bottom and the jump button's top
-- #2525 (Derek2: "make the net and tackle buttons a little smaller take up a lot of the screen"): 54 px beside the
-- 70 px jump button (was 64), 80 px beside the 120 px one (was 96); still over the 44 px a thumb needs
NetButtonPlace.SMALL = 54
NetButtonPlace.BIG = 80
NetButtonPlace.TUCK = 0.3 -- of the Net button's size, how far its right edge reaches past the jump button's left

function NetButtonPlace.jump(viewport: Vector2): (Vector2, number)
	if math.min(viewport.X, viewport.Y) <= NetButtonPlace.SMALL_SCREEN then
		return Vector2.new(viewport.X - 95, viewport.Y - 90), 70
	end
	return Vector2.new(viewport.X - 170, viewport.Y - 210), 120
end

function NetButtonPlace.place(viewport: Vector2): (Vector2, number)
	local jumpAt, jumpSize = NetButtonPlace.jump(viewport)
	local size = if jumpSize <= 70 then NetButtonPlace.SMALL else NetButtonPlace.BIG
	local right = jumpAt.X + math.floor(size * NetButtonPlace.TUCK)
	local bottom = jumpAt.Y - NetButtonPlace.GAP
	return Vector2.new(right - size, bottom - size), size
end

function NetButtonPlace.tackle(viewport: Vector2): (Vector2, number)
	local netAt, size = NetButtonPlace.place(viewport)
	return Vector2.new(netAt.X - NetButtonPlace.GAP - size, netAt.Y), size
end

return NetButtonPlace
