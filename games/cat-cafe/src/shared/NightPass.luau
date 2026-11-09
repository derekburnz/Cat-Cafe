--!strict
-- #2692 (Derek2 2026-11-09: "ship night fix giving immunity to night effects during onboarding"): a new player who
-- has not checked in a first cat (tutorialStep below TutorialGuaranteedStrayStep) is untouched by the night. The
-- cannon flies them to an area their tier opens, in the dusk warning and at night; their tutorial stray still comes
-- and is not cleared at dusk; the night sweep and a night landing never send them home; they can catch, pick up and
-- swing; and their own gates and night fences stay open on their client. It ends by itself at the first check-in, so
-- it needs no save field. The server sets the NightPass player attribute for the client's gates and cannon card; the
-- server checks the save itself every time. Pure.

local Config = require(script.Parent.Config)

local NightPass = {}

NightPass.ATTRIBUTE = "NightPass"

-- Whether a save at `tutorialStep` holds the night pass.
function NightPass.has(tutorialStep: number): boolean
	return tutorialStep < Config.TutorialGuaranteedStrayStep
end

-- Whether the areas are open for a player: open by the clock, or the night pass.
function NightPass.open(areasOpen: boolean, pass: boolean): boolean
	return areasOpen or pass
end

return NightPass
