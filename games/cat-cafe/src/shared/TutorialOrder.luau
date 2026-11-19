--!strict
-- #4518 (Derek 2026-11-15 15:24 UTC: "food bowl first (can start earning money for rank up early also) into cannon to
-- alleyway for 2 catches (not mandatory to be a rescue) and showing rankup to click right after that's ready ... then
-- they can walk into cannon beside where they just secured the 3rd cat in safezone and go to park and that ends
-- tutorial steps"): the walk-through's order, behind the `catchFirst` live switch.
--   catchFirst on (the default): today's order, the first catch, then the bowl, then the second cat.
--   catchFirst false: bowl first. A new player puts food in the bowl they start with and claims its cat, the game
--     moves them in front of the Town Square cannon, they fly to the Alleyway for two catches by hand (any route: net
--     or rescue), the Rank Up shows as soon as it is ready, and a cannon at the camp takes them to the Park, which
--     ends the walk-through. The bowl cat no longer counts toward the two (SecondCat.progress and done).
-- The switch is copied to ReplicatedStorage (LiveFlags.ATTRIBUTE_PREFIX), so the client and the server read it the
-- same way; `bowlFirst` reads it there.
-- #5498 (Derek 2026-11-19: "maybe do an A/B test with catch first vs bowl first but make sure tutorial steps work with
-- whatever one they get"; "go with whatever recommended"): with the switch `orderSplit` on (LiveFlags.OFF_BY_DEFAULT),
-- a new save joins the order test once, on its first session before its first step, and keeps its arm for good:
-- order_catch (today's catch first order) or order_bowl (bowl first), half each from the account number. The arm is
-- saved in the telemetry record (orderGroup), put on the Player as the attribute TutorialOrder (GROUP_ATTR) so both
-- sides read the same answer, and carried as custom field 3 on the funnel steps. A save in no arm reads the
-- catchFirst switch as before, so switching orderSplit off again moves nobody already in the test.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LiveFlags = require(script.Parent.LiveFlags)

local TutorialOrder = {}

-- The client's own player, nil on the server (and in the cloud spec runner, whose Players is a stub)
local localPlayer: Player? = nil
pcall(function()
	localPlayer = Players.LocalPlayer
end)

TutorialOrder.FLAG = "catchFirst"
TutorialOrder.BOWL_STEP_BELOW = 2 -- the bowl part runs before the first check-in (tutorialStep 0 and 1)
-- #4674 (Review-QA and Growth-Agent 2026-11-16): bowl first skips tut_0_shown and tut_1_shown while the bowl part
-- runs, so its three strip lines are reported instead, each once a session, as step_time events
-- (TelemetryReport("bowl_step", key), Telemetry): the food ask, the cat on its way, the cat at the bowl.
TutorialOrder.REPORT = "bowl_step"
TutorialOrder.BOWL_STEPS = {
	food = "tut_bowl_food",
	waiting = "tut_bowl_waiting",
	arrived = "tut_bowl_arrived",
	rankCue = "tut_rank_cue", -- onboarding_v9: the strip and ring point at YOUR GOAL (#5108)
} :: { [string]: string }

TutorialOrder.SPLIT_FLAG = "orderSplit"
TutorialOrder.GROUP_ATTR = "TutorialOrder"
TutorialOrder.CATCH = "order_catch"
TutorialOrder.BOWL = "order_bowl"
TutorialOrder.EVENT = "order_group" -- Telemetry.custom, once as a save joins the test (field 1: the arm)

-- The arm an account falls in: the account number's second bit, so it does not line up with IntroSplit's halves.
function TutorialOrder.group(userId: number): string
	return if math.floor(userId / 2) % 2 == 0 then TutorialOrder.CATCH else TutorialOrder.BOWL
end

-- A saved arm made safe, or nil.
function TutorialOrder.valid(raw: unknown): string?
	if raw == TutorialOrder.CATCH or raw == TutorialOrder.BOWL then
		return raw :: string
	end
	return nil
end

-- Whether a loading save joins the test now: the switch on, no arm yet, its first session, the walk-through not begun.
function TutorialOrder.joins(
	on: boolean,
	sessions: number,
	tutorialStep: number,
	group: string?
): boolean
	return on and group == nil and sessions <= 1 and tutorialStep == 0
end

-- Bowl first for a save in `group`: the arm when it has one, else the catchFirst switch stored false. The switch is
-- read from ReplicatedStorage's copy, so it is the same answer on both sides. Pure but for that read.
function TutorialOrder.fromGroup(group: string?): boolean
	if group == TutorialOrder.CATCH then
		return false
	elseif group == TutorialOrder.BOWL then
		return true
	end
	return not LiveFlags.shown(
		TutorialOrder.FLAG,
		ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. TutorialOrder.FLAG)
	)
end

-- Whether the walk-through runs bowl first for `player` (the local player on a client when nil): their arm in the
-- order test, else the switch. On the server with no player it is the switch alone.
function TutorialOrder.bowlFirst(player: Player?): boolean
	local who = player or localPlayer
	local group = if who ~= nil
		then TutorialOrder.valid(who:GetAttribute(TutorialOrder.GROUP_ATTR))
		else nil
	return TutorialOrder.fromGroup(group)
end

-- Bowl first: the bowl part is still to do, from what the save holds: before the first check-in, and no food has
-- gone in yet (`luresUsed` 0) or the first food's cat waits at the bowl (`baited`). Pure.
function TutorialOrder.bowlPending(
	tutorialStep: number,
	luresUsed: number,
	baited: boolean
): boolean
	return tutorialStep < TutorialOrder.BOWL_STEP_BELOW and (luresUsed == 0 or baited)
end

return TutorialOrder
