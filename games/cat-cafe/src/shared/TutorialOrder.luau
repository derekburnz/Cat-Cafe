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

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LiveFlags = require(script.Parent.LiveFlags)

local TutorialOrder = {}

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

-- Whether the walk-through runs bowl first: the switch stored false. Read from ReplicatedStorage's copy, so it is the
-- same answer on both sides.
function TutorialOrder.bowlFirst(): boolean
	return not LiveFlags.shown(
		TutorialOrder.FLAG,
		ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. TutorialOrder.FLAG)
	)
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
