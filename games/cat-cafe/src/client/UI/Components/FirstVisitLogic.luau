--!strict
-- #2792 (retention-ideas.md section 2, Derek2: "make it obvious when he visits"): a new account's first rich customer,
-- Mystery Visitor and Cat Collector, which the server names in the own plot's FirstVisit attribute while it is at the
-- cafe. At the cafe it is a toast; away from it, the slide-in ask card with "Go to my cafe" (the travel row's home
-- trip) and Later. Derek2: nothing new takes much of a phone's screen, so it is the ask card's one line, not a new
-- window. Pure, so the cloud specs check it.
--   kind(raw) -> string?             "rich", "mystery" or "collector" from the attribute, else nil
--   away(distance) -> boolean        farther than AWAY_STUDS from the cafe; nil (no character yet) is not away
--   holds(step, away, hint) -> boolean  the call waits: the player is away and the tutorial is under way or its
--                                    last cannon line (`hint`) is still up
--   show(kind, away) -> (how?, text) "card" or "toast" and the line; nil for the Collector at the cafe, whom the
--                                    server already toasts ("The Cat Collector is at your cafe! ...")

local FirstVisitLogic = {}

-- each line fits the ask card's one title line on a small phone
FirstVisitLogic.LINES = {
	rich = "💰 A rich customer is at your cafe!",
	mystery = "🎁 A visitor left you a gift!",
	collector = "🐱 The Cat Collector is at your cafe!",
} :: { [string]: string }

FirstVisitLogic.AWAY_STUDS = 60 -- a plot is 44 studs wide: past its walls and the street in front
FirstVisitLogic.CARD_SECONDS = 20
FirstVisitLogic.GO = "Go to my cafe"
FirstVisitLogic.LATER = "Later"

function FirstVisitLogic.kind(raw: unknown): string?
	if type(raw) == "string" and FirstVisitLogic.LINES[raw] ~= nil then
		return raw
	end
	return nil
end

function FirstVisitLogic.away(distance: number?): boolean
	return distance ~= nil and distance == distance and distance > FirstVisitLogic.AWAY_STUDS
end

-- Review-QA's fresh join runs, 2026-11-12: the card ("Go to my cafe / Later") sat over the tutorial's "Hop in the
-- cannon to catch more cats!", two opposite pulls for a new player. While the tutorial is under way (`step` below
-- TUTORIAL_DONE) and the player is away from the cafe, the call waits; at the cafe its toast still shows.
FirstVisitLogic.TUTORIAL_DONE = 5

-- Review-QA's retest: the save is already at TUTORIAL_DONE while the walk-through's last line, "Hop in the cannon to
-- catch more cats!", still shows (until the next flight), so `hint` (that line is up) holds the call as well.
function FirstVisitLogic.holds(step: unknown, away: boolean, hint: boolean?): boolean
	if not away then
		return false
	end
	return hint == true or (type(step) == "number" and step < FirstVisitLogic.TUTORIAL_DONE)
end

function FirstVisitLogic.show(kind: string, away: boolean): (string?, string)
	local line = FirstVisitLogic.LINES[kind]
	if line == nil then
		return nil, ""
	end
	if away then
		return "card", line
	end
	if kind == "collector" then
		return nil, line
	end
	return "toast", line
end

return FirstVisitLogic
