--!strict
-- #3883 (Derek 2026-11-13: "Have the feedback have a little pop up above it not too annoying but make it noticable
-- that says suggest new map themes to have you name be featured if picked"): when the small bubble by the Feedback
-- tile shows. Pure: no instances.
--   WORDS                         the bubble's line
--   due(step, doneAt, now, shown) true once the tutorial has been done for WAIT_SECONDS this join, and only once a join
-- Not too annoying: once a join, never during the tutorial, gone by itself after SHOW_SECONDS, and an X or a tap on
-- it (which opens Feedback on its Idea chip) puts it away for the rest of the join.

local FeedbackCalloutLogic = {}

FeedbackCalloutLogic.WORDS = "Suggest a new map theme! If we pick yours, your name gets featured."
FeedbackCalloutLogic.TUTORIAL_DONE = 5 -- the tutorial's last step (UIController.refreshTutorial)
FeedbackCalloutLogic.WAIT_SECONDS = 90 -- after the tutorial is done (or after the join, for a player done before)
FeedbackCalloutLogic.SHOW_SECONDS = 20

-- `doneAt` is the clock when this join first saw the tutorial done (nil while it is not); `shown` is whether the
-- bubble has shown this join.
function FeedbackCalloutLogic.due(
	step: number?,
	doneAt: number?,
	now: number,
	shown: boolean
): boolean
	if shown or doneAt == nil then
		return false
	end
	if (step or FeedbackCalloutLogic.TUTORIAL_DONE) < FeedbackCalloutLogic.TUTORIAL_DONE then
		return false
	end
	return now - doneAt >= FeedbackCalloutLogic.WAIT_SECONDS
end

return FeedbackCalloutLogic
