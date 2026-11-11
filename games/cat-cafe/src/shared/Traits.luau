--!strict
-- Cat traits at the Cat Trainer (#3196, docs/design/cat-cafe/trait-station.md; Derek2 2026-11-10: "re-work the
-- picnic into a station ... to add traits 1 per cat that do things like increase food bowl luck, extra money, slight
-- speed bonus etc make it cost gold fish or trait re-roll tokens", 2026-11-11: "Yes for everything ... also give 5
-- free rerolls off start"). Pure: rolls come from a passed function, so the specs are deterministic.
--
-- Each cat holds one trait at a time, `{ id, strength }` with strength 1 to 3 (I, II, III). A roll picks one of the
-- six traits evenly, then its strength at STRENGTH_ODDS (I 70%, II 25%, III 5%). The first trait and every re-roll
-- cost the same: a free starter roll while any are left (FREE_ROLLS, counted up in `traitFreeRollsUsed` so a missing
-- field never grants them again), else one Trait Token, else COST_FISH golden fish. After a re-roll the player keeps
-- the old trait or takes the new one, so a cat never gets worse.
--
-- Three traits work on their own cat (Big Tipper, Night Owl, Fast Learner). Three work cafe wide, and only from cats
-- in a staff slot, only the best `best` of them and at most `cap` (Lucky Bowl, Quick Paws, Rich Friend), so a cafe full
-- of one trait can't run away and no paid perk is undercut (spec section 5).
--
-- Trait Tokens are never sold in any Robux product and never traded or gifted, and golden fish are earned only, so a
-- roll is not a paid random item; the odds line (oddsText) shows on the card anyway.
--
-- Everything sits behind LiveFlags `traits` (FLAG, off by default). Turning it on needs the save version step and the
-- restart publish that ships the save fields (section 6), so no older server can drop a trait.

local Traits = {}

Traits.FLAG = "traits"
Traits.NAME = "Cat Trainer"
Traits.FREE_ROLLS = 5 -- Derek2 2026-11-11: once per player, used before tokens and fish
Traits.COST_FISH = 10 -- the first trait and every re-roll (Derek2 2026-11-10 23:59: "make re-rolls the same cost")
Traits.COST_TOKENS = 1
Traits.TOKEN_EVERY_SECONDS = 12 * 3600 -- the station's free token (replaces the Picnic Basket's Money Potion)
Traits.TOKEN_HOLD = 2
Traits.TOKEN_MAX = 999 -- a save's tokens are clamped here (no source comes near it)
Traits.STRENGTH_ODDS = { 70, 25, 5 } :: { number } -- I, II, III, in percent
Traits.STRENGTH_NAMES = { "I", "II", "III" } :: { string }

export type Trait = { id: string, strength: number }

export type Def = {
	id: string,
	name: string,
	what: string, -- the effect in a few words, for the card
	values: { number }, -- by strength
	cafe: boolean, -- works from the cafe's working cats (best `best`, at most `cap`), not just its own cat
	best: number,
	cap: number,
	format: "percent" | "studs",
}

local function def(
	id: string,
	name: string,
	what: string,
	values: { number },
	cafe: boolean,
	best: number,
	cap: number,
	format: "percent" | "studs"
): Def
	return {
		id = id,
		name = name,
		what = what,
		values = values,
		cafe = cafe,
		best = best,
		cap = cap,
		format = format,
	}
end

-- Spec section 2. `values` are fractions for "percent" (0.05 is +5%) and studs a second for "studs".
Traits.LIST = {
	def(
		"bigTipper",
		"Big Tipper",
		"this cat earns more money",
		{ 0.05, 0.10, 0.15 },
		false,
		1,
		0.15,
		"percent"
	),
	def(
		"nightOwl",
		"Night Owl",
		"this cat earns more at night",
		{ 0.10, 0.20, 0.30 },
		false,
		1,
		0.30,
		"percent"
	),
	def(
		"fastLearner",
		"Fast Learner",
		"this cat gains XP faster",
		{ 0.10, 0.20, 0.30 },
		false,
		1,
		0.30,
		"percent"
	),
	def(
		"luckyBowl",
		"Lucky Bowl",
		"better bait bowl luck",
		{ 0.02, 0.04, 0.06 },
		true,
		3,
		0.18,
		"percent"
	),
	def("quickPaws", "Quick Paws", "you walk faster", { 0.3, 0.6, 1.0 }, true, 1, 1.0, "studs"),
	def(
		"richFriend",
		"Rich Friend",
		"rich visitors come more often",
		{ 0.02, 0.04, 0.06 },
		true,
		2,
		0.12,
		"percent"
	),
} :: { Def }

local byId: { [string]: Def } = {}
for _, entry in Traits.LIST do
	byId[entry.id] = entry
end

function Traits.get(id: string): Def?
	return byId[id]
end

-- A saved trait as this code keeps it, or nil for none (an unknown id, a strength out of 1 to 3, anything else).
function Traits.sanitize(value: any): Trait?
	if type(value) ~= "table" or type(value.id) ~= "string" or byId[value.id] == nil then
		return nil
	end
	local strength = value.strength
	if
		type(strength) ~= "number"
		or strength ~= strength
		or strength % 1 ~= 0
		or strength < 1
		or strength > 3
	then
		return nil
	end
	return { id = value.id, strength = strength }
end

-- The effect of `trait` (a fraction or studs a second), 0 for none.
function Traits.value(trait: Trait?): number
	if trait == nil then
		return 0
	end
	local entry = byId[trait.id]
	if entry == nil then
		return 0
	end
	return entry.values[trait.strength] or 0
end

-- "Big Tipper II"
function Traits.title(trait: Trait): string
	local entry = byId[trait.id]
	local name = if entry then entry.name else trait.id
	return name .. " " .. (Traits.STRENGTH_NAMES[trait.strength] or "")
end

-- "+10% · this cat earns more money", "+0.6 studs/s · you walk faster"
function Traits.effectText(trait: Trait): string
	local entry = byId[trait.id]
	if entry == nil then
		return ""
	end
	local amount = Traits.value(trait)
	local shown = if entry.format == "studs"
		then string.format("+%s studs/s", tostring(amount))
		else string.format("+%d%%", math.floor(amount * 100 + 0.5))
	return shown .. " · " .. entry.what
end

-- The odds line every card shows.
function Traits.oddsText(): string
	return string.format(
		"Each of the %d traits is equally likely. Strength: I %d%%, II %d%%, III %d%%.",
		#Traits.LIST,
		Traits.STRENGTH_ODDS[1],
		Traits.STRENGTH_ODDS[2],
		Traits.STRENGTH_ODDS[3]
	)
end

-- One roll. `random(n)` returns a whole number from 1 to n (Random:NextInteger(1, n) on the server).
function Traits.roll(random: (number) -> number): Trait
	local index = math.clamp(random(#Traits.LIST), 1, #Traits.LIST)
	local total = 0
	for _, weight in Traits.STRENGTH_ODDS do
		total += weight
	end
	local pick = math.clamp(random(total), 1, total)
	local strength = #Traits.STRENGTH_ODDS
	local run = 0
	for i, weight in Traits.STRENGTH_ODDS do
		run += weight
		if pick <= run then
			strength = i
			break
		end
	end
	return { id = Traits.LIST[index].id, strength = strength }
end

-- How a roll is paid: a free starter roll while any are left, else a token, else golden fish, else nil (refused).
export type Payment = "free" | "token" | "fish"
function Traits.payment(freeUsed: number, tokens: number, fish: number): Payment?
	if freeUsed < Traits.FREE_ROLLS then
		return "free"
	end
	if tokens >= Traits.COST_TOKENS then
		return "token"
	end
	if fish >= Traits.COST_FISH then
		return "fish"
	end
	return nil
end

function Traits.freeLeft(freeUsed: number): number
	return math.clamp(Traits.FREE_ROLLS - freeUsed, 0, Traits.FREE_ROLLS)
end

-- The Roll button's words for what the next roll costs.
function Traits.rollText(freeUsed: number, tokens: number, hasTrait: boolean): string
	local verb = if hasTrait then "Re-roll" else "Roll"
	local free = Traits.freeLeft(freeUsed)
	if free > 0 then
		return string.format("Free roll (%d left)", free)
	end
	if tokens >= Traits.COST_TOKENS then
		return verb .. " · 1 Trait Token"
	end
	return string.format("%s · %d golden fish", verb, Traits.COST_FISH)
end

-- A cat's own multiplier from its trait: Big Tipper on income (Night Owl too while `night`), Fast Learner on XP.
function Traits.incomeMultiplier(trait: Trait?, night: boolean): number
	if trait == nil then
		return 1
	end
	if trait.id == "bigTipper" or (trait.id == "nightOwl" and night) then
		return 1 + Traits.value(trait)
	end
	return 1
end

function Traits.xpMultiplier(trait: Trait?): number
	if trait ~= nil and trait.id == "fastLearner" then
		return 1 + Traits.value(trait)
	end
	return 1
end

-- A cafe-wide trait's bonus from the working cats' traits (any order): the best `best` of that trait
-- added up, at most `cap`. 0 for a trait that is not cafe wide.
function Traits.cafeBonus(working: { Trait }, id: string): number
	local entry = byId[id]
	if entry == nil or not entry.cafe then
		return 0
	end
	local values: { number } = {}
	for _, trait in working do
		if trait.id == id then
			table.insert(values, Traits.value(trait))
		end
	end
	table.sort(values, function(a: number, b: number): boolean
		return a > b
	end)
	local sum = 0
	for i = 1, math.min(entry.best, #values) do
		sum += values[i]
	end
	-- a float sum can land a hair over the cap (0.06 * 3)
	return math.min(math.floor(sum * 1000 + 0.5) / 1000, entry.cap)
end

-- Tokens the station holds at `now`: one per TOKEN_EVERY_SECONDS since `at`, up to TOKEN_HOLD on top of `held`.
-- Returns the new `held` and `at` (moved on by the whole periods counted, or to now once full).
function Traits.fill(held: number, at: number, now: number): (number, number)
	if held >= Traits.TOKEN_HOLD then
		return Traits.TOKEN_HOLD, now
	end
	if now <= at then
		return held, at
	end
	local periods = (now - at) // Traits.TOKEN_EVERY_SECONDS
	if periods <= 0 then
		return held, at
	end
	local total = held + periods
	if total >= Traits.TOKEN_HOLD then
		return Traits.TOKEN_HOLD, now
	end
	return total, at + periods * Traits.TOKEN_EVERY_SECONDS
end

return Traits
