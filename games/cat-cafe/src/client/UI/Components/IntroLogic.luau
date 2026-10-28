--!strict
-- The intro cutscene's numbers (F72, docs/design/cat-cafe/intro-cutscene.md sections 2 and 4), apart from
-- Screens/Intro so the cloud spec runner can check them. Pure: no Theme.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Intro = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Intro")) :: any

export type DotLook = "past" | "now" | "next"

local IntroLogic = {}

-- one dot per shot, as many as the controller's shared/Intro has (ten since 2026-10-28)
IntroLogic.SHOTS = if type(Intro.SHOTS) == "number" then Intro.SHOTS else 10
IntroLogic.BAR = 0.09 -- each letterbox bar's share of the screen height
IntroLogic.OUT_SECONDS = 0.45 -- the bars slide out this long at the end while the HUD comes back
-- Skip's bar fills this long into a first play before a press counts (Derek 2026-10-28: "make it 5 seconds"); a
-- replay starts full
IntroLogic.FIRST_SKIP = 5.0
IntroLogic.MAX_CAPTION = 45 -- characters a caption fits on one line at full size; a longer one shrinks to fit
IntroLogic.SKIP_HEIGHT = 40 -- the Skip pill, in design pixels
IntroLogic.TOUCH_MIN = 44 -- real pixels a finger needs (Theme.sizes.touchMin)
IntroLogic.SKIP_FALLBACK = 1.5 -- after a Skip, the screen ends itself if the controller has not called finish
-- shot 2's demo ring: the circle closes onto its ring in CLOSE seconds, PERFECT pops then, the sparkle runs to END
IntroLogic.RING_RADIUS = 46 -- as Screens/CatchCircles draws the real ones
IntroLogic.START_RADIUS = 138
IntroLogic.CLOSE = 1.3
IntroLogic.FADE_FROM = 1.8
IntroLogic.END = 2.0

-- How long Skip's bar takes to fill: the controller's skipAfter, else at once on a replay and FIRST_SKIP on a first
-- play.
function IntroLogic.skipAfter(options: { skipAfter: number?, replay: boolean? }?): number
	local given = if options then options.skipAfter else nil
	if type(given) == "number" and given == given and given < math.huge then
		return math.max(0, given)
	end
	return if options and options.replay then 0 else IntroLogic.FIRST_SKIP
end

-- The demo ring's closing circle `t` seconds in: from START_RADIUS to RING_RADIUS at a steady speed, as the
-- real circles close, then resting on the ring.
function IntroLogic.closerRadius(t: number): number
	local share = math.clamp(t / IntroLogic.CLOSE, 0, 1)
	return IntroLogic.START_RADIUS + (IntroLogic.RING_RADIUS - IntroLogic.START_RADIUS) * share
end

-- The Skip pill's height and its gap above the bottom edge, in design pixels, on a screen `screenY` real pixels
-- tall drawn at `scale`: at least TOUCH_MIN real pixels tall on touch, centred on the lower bar when it fits
-- there and never nearer than 4 to the edge when it does not.
function IntroLogic.skipPlace(screenY: number, scale: number, touch: boolean): (number, number)
	local height = IntroLogic.SKIP_HEIGHT
	if touch and scale > 0 then
		height = math.max(height, math.ceil(IntroLogic.TOUCH_MIN / scale))
	end
	local bar = if scale > 0 then screenY * IntroLogic.BAR / scale else 0
	return height, math.max(4, (bar - height) / 2)
end

-- How shot dot `index` looks while shot `current` plays: done, the gold one, or still to come.
function IntroLogic.dot(index: number, current: number): DotLook
	if index == current then
		return "now"
	end
	return if index < current then "past" else "next"
end

-- The shot a Skip reports: the one showing, and 1 before the first shot has been set (0 means it played to the end).
function IntroLogic.skipShot(current: number): number
	return math.clamp(math.floor(current), 1, IntroLogic.SHOTS)
end

-- How full Skip's bar is `elapsed` seconds into a play whose bar takes `wait` seconds: 0 to 1, filling steadily,
-- and full at once with no wait.
function IntroLogic.skipFill(elapsed: number, wait: number): number
	if wait ~= wait or wait <= 0 then
		return 1
	end
	if elapsed ~= elapsed then
		return 0
	end
	return math.clamp(elapsed / wait, 0, 1)
end

-- Shot 4's job card: the four roles in the cat room's order. It shows 0.35 s into the shot, the given role lights
-- JOB_TAP later (0.6 s), the cat goes in its puff at 0.8 s and the card is gone JOB_GONE after it showed (0.9 s).
IntroLogic.ROLES = { "barista", "waiter", "greeter", "entertainer" }
IntroLogic.JOB_TAP = 0.25
IntroLogic.JOB_GONE = 0.55

return IntroLogic
