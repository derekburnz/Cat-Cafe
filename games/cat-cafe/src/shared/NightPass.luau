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
--
-- #4494 (Derek 2026-11-15 14:01 UTC: "during tutorial steps should be immune to not being able to cannon during
-- night that is not the case for the second cat catch fix asap"): the walk-through's first catch is by hand again
-- (the tutorial stray), so #3659's pass ended there and the "Catch a 2nd cat" trip was refused at night. The
-- walk-through's pass now lasts until LEARNER_CATS cats are caught by hand (SecondCat.CATS: the first catch and
-- the second cat), or the rank up to Tier 2.

-- #4916 (Derek 2026-11-16 18:18 UTC: "if someone is in tutorial steps they should be able to cannon during night even to
-- park , also it doesn't point towards a cat in alleyway if its night"): the walk-through runs on past the second cat
-- (bowl first: two catches by hand, the rank up to Tier 2, then a cannon to the Park ends it), and #4494's pass ended
-- at the second catch by hand (sooner when the intro's catch counted), so the rank up and the Park flight were refused
-- at night, and with no pass no Alleyway cat came, so the tutorial had nothing to point at. The walk's pass (`walk`)
-- now lasts while the cafe is at WALK_TIER or below and no Park cat is in the collection: the whole walk-through,
-- whatever the order, switch or session. At Tier 1 it brings the night Common at the plot's `near` point (nightCatOf),
-- so the tutorial's Alleyway catch always has a cat; at Tier 2 the cannon flies to the Park, where arriving ends the
-- walk-through. No save field.

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Economy = require(script.Parent.Economy)
local SecondCat = require(script.Parent.SecondCat)
local Types = require(script.Parent.Types)

local NightPass = {}

NightPass.WALK_TIER = 2 -- #4916: the walk-through's pass lasts up to the Park, which opens at Tier 2
NightPass.PARK_AREA = "park"
NightPass.LEARNER_CATS = SecondCat.CATS -- #4494: cats caught by hand that end the walk-through's pass

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

-- #3659: whether a save past its first check-in is still on the walk-through's trip out: Tier 1 and (#4494) fewer
-- than LEARNER_CATS cats caught by hand (`handCaught`: SecondCat.caught), so the second cat's trip flies at night too.
function NightPass.learner(tutorialStep: number, tier: number, handCaught: number): boolean
	return not NightPass.has(tutorialStep)
		and tier <= NightPass.MAX_TIER
		and handCaught < NightPass.LEARNER_CATS
end

-- #4916: whether a save is still on the walk-through: its cafe at WALK_TIER or below and `parkCats`
-- (NightPass.parkCats) 0.
function NightPass.walk(tier: number, parkCats: number): boolean
	return tier <= NightPass.WALK_TIER and parkCats == 0
end

-- #4916: how many Park kinds a collection holds.
function NightPass.parkCats(collection: { [string]: any }?): number
	local count = 0
	local held: { [string]: any } = collection or {} -- one type: luau-lsp refused to iterate the union (CI)
	for catId in held do
		local def = Catalog.getCat(catId)
		if def ~= nil and def.area == NightPass.PARK_AREA then
			count += 1
		end
	end
	return count
end

-- Whether a save holds the pass any way: a beginner, the first session at Tier 1 while the switch is on, or (#3659,
-- when `handCaught` is given) a Tier 1 save that has not caught a cat by hand yet.
function NightPass.holds(
	tutorialStep: number,
	tier: number,
	sessions: number,
	on: boolean,
	handCaught: number?,
	parkCats: number? -- #4916: given, the walk-through's pass counts too
): boolean
	return NightPass.has(tutorialStep)
		or NightPass.first(tier, sessions, on)
		or (handCaught ~= nil and NightPass.learner(tutorialStep, tier, handCaught))
		or (parkCats ~= nil and NightPass.walk(tier, parkCats))
end

-- NightPass.holds for a save.
function NightPass.of(profile: Types.PlayerProfile, on: boolean): boolean
	return NightPass.holds(
		profile.tutorialStep,
		Economy.tier(profile),
		profile.stats.sessions,
		on,
		SecondCat.caught(profile.stats),
		NightPass.parkCats(profile.collection) -- #4916
	)
end

-- #4916: NightPass.walk for a save.
function NightPass.walkOf(profile: Types.PlayerProfile): boolean
	return NightPass.walk(Economy.tier(profile), NightPass.parkCats(profile.collection))
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
-- #4916: and a Tier 1 save on the walk-through, so its Alleyway catches always have a cat at night.
function NightPass.nightCatOf(profile: Types.PlayerProfile, on: boolean): boolean
	return NightPass.firstOf(profile, on)
		or NightPass.learnerOf(profile)
		or (Economy.tier(profile) <= NightPass.MAX_TIER and NightPass.walkOf(profile))
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
