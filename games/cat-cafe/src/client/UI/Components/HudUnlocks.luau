--!strict
-- The small HUD of the first loop (F87, easy-start.md section 2f). Until tutorialStep reaches DONE (5) the HUD shows
-- only the money and rate, the hint with its trail, Home and the Alley (or the Cannon), the Tutorial tile and
-- Settings; the rest appears one at a time as it unlocks, each with a "New!" pop (Screens/HUD).
--   cats                                the first check-in (step 2) or a cat owned
--   upgrades                            step 2 (step 2's and 3's hints point at it)
--   quests, daily, gifts, feedback,     step 5 (the treat and the spin already wait for it)
--   invite, equipBest, clock, goal
--   decor                               step 2 with Upgrades, or the third cat (Derek 2026-11-03: it read as missing)
--   index                               the third cat
--   potions, fish                       Tier 2, or the first potion or golden fish if that comes first
--   areas                               Tier 2 (the Areas button; the Alley and the Cannon always show)
-- A state with no tutorialStep (an old client's view, the demo, the UI gate) shows everything.
--   KEYS                                every key, in a fixed order
--   view(state) -> View                 what the rules read from a PlayerState
--   shown(view) -> { [Key]: boolean }   which keys show
--   update(before, view) -> (shown, opened)   shown(view) keeping every key that showed before this session (selling
--                                       cats never hides the Index), and the keys new since before (none on the
--                                       first sync: before nil)
-- Pure, so the cloud spec runner checks it.

local HudUnlocks = {}

HudUnlocks.DONE = 5
HudUnlocks.INDEX_CATS = 3

export type Key =
	"cats"
	| "upgrades"
	| "quests"
	| "daily"
	| "gifts"
	| "feedback"
	| "invite"
	| "equipBest"
	| "clock"
	| "goal"
	| "index"
	| "decor"
	| "potions"
	| "fish"
	| "areas"

HudUnlocks.KEYS = {
	"cats",
	"upgrades",
	"quests",
	"daily",
	"gifts",
	"feedback",
	"invite",
	"equipBest",
	"clock",
	"goal",
	"index",
	"decor",
	"potions",
	"fish",
	"areas",
} :: { Key }

export type View = {
	step: number?, -- nil: show everything
	cats: number, -- cats owned
	tier: number,
	potions: number, -- potions in the bag
	fish: number, -- golden fish
}

type StateLike = {
	tutorialStep: number?,
	cats: { [string]: any }?,
	tier: number?,
	potions: { [string]: number }?,
	goldenFish: number?,
}

function HudUnlocks.view(state: StateLike): View
	local cats = 0
	local owned: { [string]: any } = state.cats or {}
	for _ in owned do
		cats += 1
	end
	local potions = 0
	local bag: { [string]: number } = state.potions or {}
	for _, count in bag do
		potions += math.max(0, count)
	end
	return {
		step = state.tutorialStep,
		cats = cats,
		tier = state.tier or 1,
		potions = potions,
		fish = state.goldenFish or 0,
	}
end

function HudUnlocks.shown(view: View): { [Key]: boolean }
	local out: { [string]: boolean } = {}
	local step = view.step
	if step == nil then
		for _, key in HudUnlocks.KEYS do
			out[key] = true
		end
		return out :: any
	end
	local done = step >= HudUnlocks.DONE
	local tier2 = view.tier >= 2
	out.cats = step >= 2 or view.cats > 0
	out.upgrades = step >= 2
	for _, key in
		{ "quests", "daily", "gifts", "feedback", "invite", "equipBest", "clock", "goal" } :: { Key }
	do
		out[key] = done
	end
	out.index = view.cats >= HudUnlocks.INDEX_CATS
	out.decor = out.upgrades or view.cats >= HudUnlocks.INDEX_CATS
	out.potions = tier2 or view.potions > 0
	out.fish = tier2 or view.fish > 0
	out.areas = tier2
	return out :: any
end

function HudUnlocks.update(before: { [Key]: boolean }?, view: View): ({ [Key]: boolean }, { Key })
	local now: { [string]: boolean } = HudUnlocks.shown(view) :: any
	local opened: { Key } = {}
	if before == nil then
		return now :: any, opened
	end
	local was: { [string]: boolean } = before :: any
	for _, key in HudUnlocks.KEYS do
		if was[key] then
			now[key] = true
		elseif now[key] then
			table.insert(opened, key)
		end
	end
	return now :: any, opened
end

return HudUnlocks
