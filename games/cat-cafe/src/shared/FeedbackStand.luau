--!strict
-- The feedback stand in the Town Square (#3066, Derek2 2026-11-10: "make a feedback stand with a mailbox and maybe
-- postie cat there in the town square for people to leave feedback", "make it instantly give them a box to type in
-- so it's not hard"). The stand is a walk-up station (shared/WalkUp): stepping into its floor ring, or one press of
-- its prompt, opens the Feedback window straight on its text box (the Idea chip), with no faces page first. What is
-- typed goes where the HUD's Feedback tile sends it (ReportBug: the same filter, length limit and rate limit), so
-- nothing here is new on the server but the model and its prompt. Postie Cat on the stand is decoration.
--   TAG, PROMPT        the placed model's CollectionService tag and its ProximityPrompt's name
--   WINDOW, KIND       the UI's window (its modal name) and the chip it opens on
--   RANGE              studs from the stand's pivot its floor ring must stay inside (WalkUp.frontOffset)
--   PROMPT_RANGE       how close the prompt's pill shows
--   STILL_LOOKS        looks (WalkUpController's, 0.15 s each) a keyboard player stands still in the ring before the
--                      cursor goes into the box: walking in with W held never types "www" into it
--   focusNow(still, focused, keyboard)  whether the ring's window takes the cursor on this look

local FeedbackStand = {}

FeedbackStand.ASSET = "CatCafe_Town_FeedbackStand"
FeedbackStand.TAG = "FeedbackStand"
FeedbackStand.PROMPT = "FeedbackPrompt"
FeedbackStand.WINDOW = "BugReport"
FeedbackStand.KIND = "idea"
FeedbackStand.NAME = "Feedback"
FeedbackStand.ACTION = "Write to us"
FeedbackStand.RANGE = 12
FeedbackStand.PROMPT_RANGE = 8
FeedbackStand.STILL_LOOKS = 3

-- Whether the window the ring opened takes the cursor now: once, for a player on a keyboard who has stood still for
-- STILL_LOOKS looks. A phone's keyboard waits for a tap on the box (it covers half the screen), a gamepad's too.
function FeedbackStand.focusNow(still: number, focused: boolean, keyboard: boolean): boolean
	return keyboard and not focused and still >= FeedbackStand.STILL_LOOKS
end

return FeedbackStand
