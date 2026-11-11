--!strict
-- The pure half of Components/TutorialArrow (#2314): which side of its target the big arrow sits on, where, which
-- way it turns, when it shows, and the spotlight round its target (#3153). No instances here, so the spec can check it.

local TutorialArrowLogic = {}

TutorialArrowLogic.GAP = 6 -- px between the arrow's tip and the target's edge

export type Side = string -- "top", "left", "right" or "bottom"

export type Placement = {
	side: Side,
	x: number, -- the arrow's centre, in the target's ScreenGui pixels
	y: number,
	rotation: number, -- the arrow is drawn pointing down; this turns it toward the target
}

export type Rect = { min: Vector2, max: Vector2 }

-- the arrow comes from above when it can, then from the left, the right, and below
local ORDER: { Side } = { "top", "left", "right", "bottom" }
local ROTATION: { [Side]: number } = { top = 0, left = -90, right = 90, bottom = 180 }

local function overlap(a: Rect, b: Rect): number
	local w = math.min(a.max.X, b.max.X) - math.max(a.min.X, b.min.X)
	local h = math.min(a.max.Y, b.max.Y) - math.max(a.min.Y, b.min.Y)
	return if w > 0 and h > 0 then w * h else 0
end

-- The arrow's centre on `side` of the target, kept whole on the screen.
local function centreOn(
	side: Side,
	position: Vector2,
	size: Vector2,
	screen: Vector2,
	arrow: number,
	top: number
): Vector2
	local half = arrow / 2
	local x = position.X + size.X / 2
	local y = position.Y + size.Y / 2
	if side == "top" then
		y = position.Y - TutorialArrowLogic.GAP - half
	elseif side == "bottom" then
		y = position.Y + size.Y + TutorialArrowLogic.GAP + half
	elseif side == "left" then
		x = position.X - TutorialArrowLogic.GAP - half
	else
		x = position.X + size.X + TutorialArrowLogic.GAP + half
	end
	return Vector2.new(
		math.clamp(x, half, math.max(half, screen.X - half)),
		math.clamp(y, half - top, math.max(half - top, screen.Y - half))
	)
end

-- Where an arrow `arrow` px square points at the target box (position and size in px) on a `screen` px area. Of
-- the sides with room for it, the one that covers the least of `others` (the other buttons on screen, so it doesn't
-- sit on the Store tile), in ORDER on a tie; with room nowhere, the side with the most. #3154: an arrow under a
-- target up in Roblox's top bar (the Tutorial tile's ×, `top` px over the ScreenGui's origin) may reach up into
-- that bar, so it stays close under the target instead of being pushed down; it never comes from above there.
function TutorialArrowLogic.place(
	position: Vector2,
	size: Vector2,
	screen: Vector2,
	arrow: number,
	others: { Rect }?,
	top: number?
): Placement
	local over = top or 0
	local need = arrow + TutorialArrowLogic.GAP
	local room: { [Side]: number } = {
		top = position.Y, -- not up into the top bar: Roblox's own buttons are there
		bottom = screen.Y - (position.Y + size.Y),
		left = position.X,
		right = screen.X - (position.X + size.X),
	}
	local blockers: { Rect } = others or {}
	local side: Side? = nil
	local least = math.huge
	for _, candidate in ORDER do
		if room[candidate] >= need then
			local centre = centreOn(candidate, position, size, screen, arrow, over)
			local box = {
				min = centre - Vector2.new(arrow, arrow) / 2,
				max = centre + Vector2.new(arrow, arrow) / 2,
			}
			local covered = 0
			for _, other in blockers do
				covered += overlap(box, other)
			end
			if covered < least then
				least = covered
				side = candidate
			end
		end
	end
	local chosen: Side = "top"
	if side ~= nil then
		chosen = side
	else
		local best = -math.huge
		for _, candidate in ORDER do
			if room[candidate] > best then
				best = room[candidate]
				chosen = candidate
			end
		end
	end
	local centre = centreOn(chosen, position, size, screen, arrow, over)
	return { side = chosen, x = centre.X, y = centre.Y, rotation = ROTATION[chosen] }
end

-- True while the arrow shows, `elapsed` seconds after its target started to glow. #3153 (Derek2: "the one pointing to
-- upgrades randomly disapears"): it used to show SHOW_SECONDS, hide AGAIN_SECONDS and come back; it now stays for as
-- long as the step waits, and goes with the glow.
function TutorialArrowLogic.showing(elapsed: number): boolean
	return elapsed >= 0
end

-- #3153: true when a target box (position and size in px) has its centre on a `screen` px area. The HUD's menu can
-- fold off the left edge with its tiles still Visible, which left the arrow pinned to the left edge pointing at
-- nothing ("the arrow points randomly on the left"). `top` px above the ScreenGui's origin still count: a ScreenGui
-- that keeps clear of Roblox's top bar starts under it, and the HUD's top row sits up in that bar.
function TutorialArrowLogic.onScreen(
	position: Vector2,
	size: Vector2,
	screen: Vector2,
	top: number?
): boolean
	local centre = position + size / 2
	return centre.X >= 0
		and centre.X <= screen.X
		and centre.Y >= -(top or 0)
		and centre.Y <= screen.Y
end

-- #3153 (Derek2: "your screen should darken"): the spotlight. The screen darkens round the target the arrow points
-- at, leaving a hole SPOT_PAD px round it. Dark (SPOT_STRONG) for SPOT_STRONG_SECONDS once the target starts, then
-- lighter (SPOT_SOFT) for as long as the step waits, so the game behind it stays playable.
TutorialArrowLogic.SPOT_PAD = 10
TutorialArrowLogic.SPOT_STRONG = 0.35 -- the dim's BackgroundTransparency: 0 is black, 1 is none
TutorialArrowLogic.SPOT_SOFT = 0.7
TutorialArrowLogic.SPOT_STRONG_SECONDS = 4
TutorialArrowLogic.SPOT_FADE_SECONDS = 0.6
TutorialArrowLogic.SPOT_BLEED = 200 -- px the dim reaches past the screen's edges (the top bar, a notch)

-- The dim's transparency `elapsed` seconds after the target started: fading in to strong, holding, easing to soft.
function TutorialArrowLogic.dim(elapsed: number): number
	local fade = TutorialArrowLogic.SPOT_FADE_SECONDS
	local strong, soft = TutorialArrowLogic.SPOT_STRONG, TutorialArrowLogic.SPOT_SOFT
	if elapsed < 0 then
		return 1
	elseif elapsed < fade then
		return 1 + (strong - 1) * (elapsed / fade)
	elseif elapsed < TutorialArrowLogic.SPOT_STRONG_SECONDS then
		return strong
	elseif elapsed < TutorialArrowLogic.SPOT_STRONG_SECONDS + fade then
		local t = (elapsed - TutorialArrowLogic.SPOT_STRONG_SECONDS) / fade
		return strong + (soft - strong) * t
	end
	return soft
end

-- The four dark boxes round the hole (top, bottom, left, right) that together cover the screen and SPOT_BLEED past
-- it, all but the target box grown by SPOT_PAD. Boxes never come out with a negative size.
function TutorialArrowLogic.holes(position: Vector2, size: Vector2, screen: Vector2): { Rect }
	local pad, bleed = TutorialArrowLogic.SPOT_PAD, TutorialArrowLogic.SPOT_BLEED
	local outerMin = Vector2.new(-bleed, -bleed)
	local outerMax = screen + Vector2.new(bleed, bleed)
	local function clampV(v: Vector2): Vector2
		return Vector2.new(
			math.clamp(v.X, outerMin.X, outerMax.X),
			math.clamp(v.Y, outerMin.Y, outerMax.Y)
		)
	end
	local holeMin = clampV(position - Vector2.new(pad, pad))
	local holeMax = clampV(position + size + Vector2.new(pad, pad))
	return {
		{ min = outerMin, max = Vector2.new(outerMax.X, holeMin.Y) },
		{ min = Vector2.new(outerMin.X, holeMax.Y), max = outerMax },
		{ min = Vector2.new(outerMin.X, holeMin.Y), max = Vector2.new(holeMin.X, holeMax.Y) },
		{ min = Vector2.new(holeMax.X, holeMin.Y), max = Vector2.new(outerMax.X, holeMax.Y) },
	}
end

return TutorialArrowLogic
