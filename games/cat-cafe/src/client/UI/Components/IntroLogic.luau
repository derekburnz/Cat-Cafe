--!strict
-- The intro cutscene's numbers (F72, docs/design/cat-cafe/intro-cutscene.md sections 2 and 4), apart from
-- Screens/Intro so the cloud spec runner can check them. Pure: no Theme.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Intro = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Intro")) :: any

export type DotLook = "past" | "now" | "next"

local IntroLogic = {}

-- one dot per shot, as many as the controller's shared/Intro has (ten since 2026-10-28)
IntroLogic.SHOTS = if type(Intro.SHOTS) == "number" then Intro.SHOTS else 10
-- #2495: a first play runs the tackling lesson's four captions after the intro's last shot, on the same screen
IntroLogic.LESSON_SHOTS = 4
IntroLogic.MAX_SHOTS = IntroLogic.SHOTS + IntroLogic.LESSON_SHOTS
IntroLogic.BAR = 0.09 -- each letterbox bar's share of the screen height
-- #2394 (Derek2: "the black bars on top and bottom of screen top is fine because it shows how far through tutorial but
-- the bottom just takes up a lot of space that could be camera"): on touch there is no lower bar; Skip and Next sit
-- this far over the bottom edge instead (clear of a phone's home bar), and the caption just over them
IntroLogic.NO_BAR_EDGE = 24
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
-- #2182 (intro-cutscene.md 2b; playtesters via Derek2 2026-11-07: "a next button or just slowing it down would
-- help"): Next, a tap outside Skip, Space, Enter or gamepad A moves on once a shot has shown this long, so a double tap
-- never skips two shots (shared/Intro's NEXT_AFTER, else 1.0)
IntroLogic.NEXT_AFTER = if type(Intro.NEXT_AFTER) == "number" then Intro.NEXT_AFTER else 1.0
IntroLogic.NEXT_GAP = 10 -- design pixels between Next and Skip on the lower bar
IntroLogic.READ_WIDTH = 220 -- the read bar under the caption, in design pixels
IntroLogic.READ_HEIGHT = 4

-- #2198: how many shots (and dots) a play has: start's `shots` for a short lesson, 1 to MAX_SHOTS (#2495: the intro
-- with the lesson's tail), else SHOTS.
function IntroLogic.shotCount(options: { shots: number? }?): number
	local given = if options then options.shots else nil
	if type(given) ~= "number" or given ~= given then
		return IntroLogic.SHOTS
	end
	return math.clamp(math.floor(given), 1, IntroLogic.MAX_SHOTS)
end

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

-- Whether the cutscene draws its lower letterbox bar: not on touch (#2394), where the screen is short.
function IntroLogic.lowerBar(touch: boolean): boolean
	return not touch
end

-- The Skip pill's height and its gap above the bottom edge, in design pixels, on a screen `screenY` real pixels
-- tall drawn at `scale`: at least TOUCH_MIN real pixels tall on touch, centred on the lower bar when it fits
-- there and never nearer than 4 to the edge when it does not; NO_BAR_EDGE over the edge with no lower bar (#2394).
function IntroLogic.skipPlace(
	screenY: number,
	scale: number,
	touch: boolean,
	noBar: boolean?
): (number, number)
	local height = IntroLogic.SKIP_HEIGHT
	if touch and scale > 0 then
		height = math.max(height, math.ceil(IntroLogic.TOUCH_MIN / scale))
	end
	if noBar then
		return height, IntroLogic.NO_BAR_EDGE
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

-- #2182: a shot's hold as the controller passed it, or nil for none (no read bar and no Next): a number above 0 and
-- not NaN or infinite.
function IntroLogic.hold(seconds: unknown): number?
	if type(seconds) ~= "number" or seconds ~= seconds or seconds <= 0 or seconds == math.huge then
		return nil
	end
	return seconds
end

-- #2182: whether a press `elapsed` seconds into a shot moves on (NEXT_AFTER or later; never for a broken clock).
function IntroLogic.canNext(elapsed: number): boolean
	return elapsed == elapsed and elapsed >= IntroLogic.NEXT_AFTER
end

-- Shot 4's job card: the four roles in the cat room's order. It shows 0.35 s into the shot, the given role lights
-- JOB_TAP later (0.6 s), the cat goes in its puff at 0.8 s and the card is gone JOB_GONE after it showed (0.9 s).
IntroLogic.ROLES = { "barista", "waiter", "greeter", "entertainer" }
IntroLogic.JOB_TAP = 0.25
IntroLogic.JOB_GONE = 0.55
-- #2242 (Derek2 11-07: "add the rare customers chance to the tutorial scene like rich customer tips"): the rich
-- visitor shot's "+$" pop over the grabbed tip bag rises TIP_RISE design pixels and is gone TIP_GONE after it showed
IntroLogic.TIP_RISE = 46
IntroLogic.TIP_FADE_FROM = 1.2
IntroLogic.TIP_GONE = 1.6

return IntroLogic
