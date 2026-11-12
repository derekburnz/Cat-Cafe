--!strict
-- #2692 (Derek2 2026-11-09: "ship night fix giving immunity to night effects during onboarding"): a new player who
-- has not checked in a first cat (tutorialStep below TutorialGuaranteedStrayStep) is untouched by the night. The
-- cannon flies them to an area their tier opens, in the dusk warning and at night; their tutorial stray still comes
-- and is not cleared at dusk; the night sweep and a night landing never send them home; they can catch, pick up and
-- swing; and their own gates and night fences stay open on their client. It ends by itself at the first check-in, so
-- it needs no save field. The server sets the NightPass player attribute for the client's gates and cannon card; the
-- server checks the save itself every time. Pure.

--
-- #3035 (Research-Agent's leave read to 2026-11-09: night is 18% of the clock and 30% of the leaves, 6 of 13 night
-- leaves a Tier 1 player in their first session): while the live switch FLAG is on, a save at MAX_TIER or below in
-- its first session (stats.sessions at MAX_SESSIONS or below, the same "first" as left_in_phase) keeps the pass
-- after its first check-in too. At Tier 1 only the Alleyway is unlocked, so that is the one area it opens. At night
-- such a player finds one Common waiting at their plot's `near` point, as a beginner does (CatService.tutorialTick),
-- not a wave. It ends at the rank up to Tier 2, with the session, or when the switch goes off; the next night sweep
-- then sends them home. No save field.

--
-- #3659 (Derek 2026-11-12: "I couldn't cannon at night even tho I was still on tutorial steps which I should be able
-- to bypass"): the walk-through's first cat now comes from the bait bowl, so the first check-in ends the beginner's
-- pass before the player has ever gone out, and the walk-through's last step then stands them in front of a cannon
-- that refuses at night. A Tier 1 save that has checked in a cat but never one caught by hand (SecondCat.caught 0: the
-- "Catch a 2nd cat" trip is still ahead) keeps the pass, in any session and whatever the switch says. At night it
-- finds one Common at its plot's `near` point, as a first-session holder does. It ends at the first check-in of a
-- cat caught by hand, or at the rank up to Tier 2. No save field.

local Config = require(script.Parent.Config)
local Economy = require(script.Parent.Economy)
local SecondCat = require(script.Parent.SecondCat)
local Types = require(script.Parent.Types)

local NightPass = {}

NightPass.ATTRIBUTE = "NightPass"
NightPass.FLAG = "nightCatch" -- the LiveFlags key
NightPass.MAX_TIER = 1
NightPass.MAX_SESSIONS = 1
NightPass.CAUGHT = "night_catch_first" -- step_time: a first-session pass holder's first night catch of the session
NightPass.LEFT_SUFFIX = "_nc" -- on left_in_phase's tier field while night catching was open to the leaver

-- Whether a save at `tutorialStep` holds the night pass.
function NightPass.has(tutorialStep: number): boolean
	return tutorialStep < Config.TutorialGuaranteedStrayStep
end

-- #3035: whether a save at cafe `tier` in its `sessions`-th session holds the first-session pass; `on` is the live
-- switch.
function NightPass.first(tier: number, sessions: number, on: boolean): boolean
	return on and tier <= NightPass.MAX_TIER and sessions <= NightPass.MAX_SESSIONS
end

-- #3659: whether a save past its first check-in is still on the walk-through's trip out: Tier 1 and no cat caught by
-- hand yet (`handCaught`: SecondCat.caught).
function NightPass.learner(tutorialStep: number, tier: number, handCaught: number): boolean
	return not NightPass.has(tutorialStep) and tier <= NightPass.MAX_TIER and handCaught < 1
end

-- Whether a save holds the pass any way: a beginner, the first session at Tier 1 while the switch is on, or (#3659,
-- when `handCaught` is given) a Tier 1 save that has not caught a cat by hand yet.
function NightPass.holds(
	tutorialStep: number,
	tier: number,
	sessions: number,
	on: boolean,
	handCaught: number?
): boolean
	return NightPass.has(tutorialStep)
		or NightPass.first(tier, sessions, on)
		or (handCaught ~= nil and NightPass.learner(tutorialStep, tier, handCaught))
end

-- NightPass.holds for a save.
function NightPass.of(profile: Types.PlayerProfile, on: boolean): boolean
	return NightPass.holds(
		profile.tutorialStep,
		Economy.tier(profile),
		profile.stats.sessions,
		on,
		SecondCat.caught(profile.stats)
	)
end

-- #3659: NightPass.learner for a save.
function NightPass.learnerOf(profile: Types.PlayerProfile): boolean
	return NightPass.learner(
		profile.tutorialStep,
		Economy.tier(profile),
		SecondCat.caught(profile.stats)
	)
end

-- Whether a save past its first check-in finds its own Common in the Alleyway at night: the first-session pass, or
-- the walk-through's (#3659).
function NightPass.nightCatOf(profile: Types.PlayerProfile, on: boolean): boolean
	return NightPass.firstOf(profile, on) or NightPass.learnerOf(profile)
end

-- NightPass.first for a save.
function NightPass.firstOf(profile: Types.PlayerProfile, on: boolean): boolean
	return NightPass.first(Economy.tier(profile), profile.stats.sessions, on)
end

-- Whether the areas are open for a player: open by the clock, or the night pass.
function NightPass.open(areasOpen: boolean, pass: boolean): boolean
	return areasOpen or pass
end

return NightPass
