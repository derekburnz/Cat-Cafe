--!strict
-- Where the touch Net and Tackle buttons sit (F93, catch-rework.md section 1).
-- Roblox draws its own jump button in screen pixels, 70 px at (W - 95, H - 90) on a small screen (the short side
-- 500 px or less) and 120 px at (W - 170, H - 210) on a bigger one (PlayerModule's TouchJump). Components/JumpButton
-- reads the live one and falls back to jump() when it is not there.
-- #2721 (Derek2 11-09: "do some research for where mobile players like their buttons and move the net/tackle to
-- where it would fit best"): Roblox's guide puts custom buttons beside the jump button, and the right thumb rests
-- on it, so its easy reach is a quarter circle around it. NET, the main action, sits just left of the jump button,
-- centres level; TACKLE sits on that arc up and left of the jump button, between the two, a little smaller.
--   jump(viewport) -> (Vector2, number)                          the jump button's top left and size by formula
--   place(viewport, jumpAt?, jumpSize?) -> (Vector2, number)     the Net button's top left and size, screen px
--   tackle(viewport, jumpAt?, jumpSize?) -> (Vector2, number)    the touch Tackle button's
-- Pure, so the cloud spec runner checks it.

local NetButtonPlace = {}

NetButtonPlace.SMALL_SCREEN = 500 -- TouchJump's cut-off on the short side
NetButtonPlace.GAP = 12 -- #2721: between the Net button's right edge and the jump button's left
-- #2525 (Derek2: "make the net and tackle buttons a little smaller take up a lot of the screen"): 54 px beside the
-- 70 px jump button, 80 px beside the 120 px one; still over the 44 px a thumb needs
NetButtonPlace.SMALL = 56 -- #3556: was 54
NetButtonPlace.BIG = 80
NetButtonPlace.TACKLE = 0.85 -- of the Net button's size; 48 px and 68 px, still over 44
NetButtonPlace.REACH = 1.4 -- the Tackle's centre, in jump widths from the jump button's centre
NetButtonPlace.ANGLE = 45 -- degrees up from the left, on the arc between Net (0) and straight up (90)

function NetButtonPlace.jump(viewport: Vector2): (Vector2, number)
	if math.min(viewport.X, viewport.Y) <= NetButtonPlace.SMALL_SCREEN then
		return Vector2.new(viewport.X - 95, viewport.Y - 90), 70
	end
	return Vector2.new(viewport.X - 170, viewport.Y - 210), 120
end

local function jumpOf(viewport: Vector2, jumpAt: Vector2?, jumpSize: number?): (Vector2, number)
	if jumpAt ~= nil and jumpSize ~= nil and jumpSize > 0 then
		return jumpAt, jumpSize
	end
	return NetButtonPlace.jump(viewport)
end

local function onScreen(viewport: Vector2, at: Vector2, size: number): Vector2
	return Vector2.new(
		math.clamp(at.X, 0, math.max(0, viewport.X - size)),
		math.clamp(at.Y, 0, math.max(0, viewport.Y - size))
	)
end

function NetButtonPlace.place(
	viewport: Vector2,
	jumpAt: Vector2?,
	jumpSize: number?
): (Vector2, number)
	local at, jump = jumpOf(viewport, jumpAt, jumpSize)
	local size = if jump <= 90 then NetButtonPlace.SMALL else NetButtonPlace.BIG
	local x = at.X - NetButtonPlace.GAP - size
	local y = at.Y + math.floor((jump - size) / 2)
	return onScreen(viewport, Vector2.new(x, y), size), size
end

function NetButtonPlace.tackle(
	viewport: Vector2,
	jumpAt: Vector2?,
	jumpSize: number?
): (Vector2, number)
	local at, jump = jumpOf(viewport, jumpAt, jumpSize)
	local _, netSize = NetButtonPlace.place(viewport, at, jump)
	local size = math.floor(netSize * NetButtonPlace.TACKLE + 0.5)
	local angle = math.rad(NetButtonPlace.ANGLE)
	local reach = jump * NetButtonPlace.REACH
	local cx = at.X + jump / 2 - math.cos(angle) * reach
	local cy = at.Y + jump / 2 - math.sin(angle) * reach
	local corner = Vector2.new(math.floor(cx - size / 2 + 0.5), math.floor(cy - size / 2 + 0.5))
	return onScreen(viewport, corner, size), size
end

return NetButtonPlace
