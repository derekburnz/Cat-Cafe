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

local Config = require(script.Parent.Config)
local Economy = require(script.Parent.Economy)
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

-- Whether a save holds the pass either way: a beginner, or the first session at Tier 1 while the switch is on.
function NightPass.holds(tutorialStep: number, tier: number, sessions: number, on: boolean): boolean
	return NightPass.has(tutorialStep) or NightPass.first(tier, sessions, on)
end

-- NightPass.holds for a save.
function NightPass.of(profile: Types.PlayerProfile, on: boolean): boolean
	return NightPass.holds(profile.tutorialStep, Economy.tier(profile), profile.stats.sessions, on)
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
