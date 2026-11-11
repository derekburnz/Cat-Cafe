--!strict
-- Cat traits at the Mystic Pool (#3196, docs/design/cat-cafe/trait-station.md; Derek2 2026-11-10: "re-work the
-- picnic into a station ... to add traits 1 per cat that do things like increase food bowl luck, extra money, slight
-- speed bonus etc make it cost gold fish or trait re-roll tokens", 2026-11-11: "Yes for everything ... also give 5
-- free rerolls off start", then "make the legendary / mythic traits give combinations of multiple things"). Pure:
-- rolls come from a passed function, so the specs are deterministic.
--
-- Each cat holds one trait at a time, saved as `{ id }`; the id carries its rarity and effects (LIST). A roll picks
-- the rarity first at RARITIES' odds (Common 55, Uncommon 28, Rare 12, Legendary 4, Mythic 1), then one trait of that
-- rarity evenly. Common, Uncommon and Rare hold the same six one-effect traits, stronger at each rarity; Legendary
-- holds four two-effect traits and Mythic three three-effect traits. The first trait and every re-roll cost the same:
-- a free starter roll while any are left (FREE_ROLLS, counted up in `traitFreeRollsUsed` so a missing field never
-- grants them again), else one Trait Token, else COST_FISH golden fish. After a re-roll the player keeps the old trait
-- or takes the new one, so a cat never gets worse.
--
-- Effects (KINDS): income, night income and XP work on their own cat only. Bowl luck, speed and rich visitor rate work
-- cafe wide, only from cats in a staff slot, only the best `best` of them and at most `cap` (bowl luck 3 and 0.36,
-- speed 1 and 1.5 studs/s, rich rate 2 and 0.24); a combo's effect counts like the single trait with the same effect.
-- So a cafe full of one trait can't run away and no paid perk is undercut (spec section 5).
--
-- Trait Tokens are never sold in any Robux product and never traded or gifted, and golden fish are earned only, so a
-- roll is not a paid random item; the odds line (oddsText) shows on the card anyway.
--
-- Everything sits behind LiveFlags `traits` (FLAG, off by default). Turning it on needs the save version step and the
-- restart publish that ships the save fields (section 6), so no older server can drop a trait.

local Traits = {}

Traits.FLAG = "traits"
Traits.NAME = "Mystic Pool"
Traits.KEEPER = "Sage Sorrel"
Traits.FREE_ROLLS = 5 -- Derek2 2026-11-11: once per player, used before tokens and fish
Traits.COST_FISH = 10 -- the first trait and every re-roll (Derek2 2026-11-10 23:59: "make re-rolls the same cost")
Traits.COST_TOKENS = 1
Traits.TOKEN_EVERY_SECONDS = 12 * 3600 -- the station's free token (replaces the Picnic Basket's Money Potion)
Traits.TOKEN_HOLD = 2
Traits.TOKEN_MAX = 999 -- a save's tokens are clamped here (no source comes near it)

export type Trait = { id: string }

export type Kind = "income" | "nightIncome" | "xp" | "bowlLuck" | "speed" | "richRate"

export type Rarity = {
	id: string,
	name: string,
	rank: number, -- 1 Common to 5 Mythic
	odds: number, -- percent of rolls
	color: string, -- hex, the pool's and the card's colour (Color3.fromHex on the client)
}

export type Effect = { kind: Kind, amount: number }

export type Def = {
	id: string,
	name: string,
	rarity: Rarity,
	effects: { Effect },
}

-- Spec section 1a: the pool's colours and section 3's odds, in roll order.
Traits.RARITIES = {
	{ id = "common", name = "Common", rank = 1, odds = 55, color = "#9AA0A6" },
	{ id = "uncommon", name = "Uncommon", rank = 2, odds = 28, color = "#4CAF50" },
	{ id = "rare", name = "Rare", rank = 3, odds = 12, color = "#3F8FE0" },
	{ id = "legendary", name = "Legendary", rank = 4, odds = 4, color = "#F4C430" },
	{ id = "mythic", name = "Mythic", rank = 5, odds = 1, color = "#B04FE0" },
} :: { Rarity }

local COMMON, UNCOMMON, RARE, LEGENDARY, MYTHIC =
	Traits.RARITIES[1],
	Traits.RARITIES[2],
	Traits.RARITIES[3],
	Traits.RARITIES[4],
	Traits.RARITIES[5]

-- Spec section 2d: how each effect is counted. `cafe` effects count only the best `best` working cats, at most `cap`.
-- `what` is the card's words; "studs" amounts are studs a second, the rest fractions (0.05 is +5%).
export type KindInfo = { cafe: boolean, best: number, cap: number, what: string, studs: boolean }
Traits.KINDS = {
	income = { cafe = false, best = 1, cap = math.huge, what = "this cat's income", studs = false },
	nightIncome = {
		cafe = false,
		best = 1,
		cap = math.huge,
		what = "this cat's night income",
		studs = false,
	},
	xp = { cafe = false, best = 1, cap = math.huge, what = "this cat's XP", studs = false },
	bowlLuck = { cafe = true, best = 3, cap = 0.36, what = "bait bowl luck", studs = false },
	speed = { cafe = true, best = 1, cap = 1.5, what = "walk and carry speed", studs = true },
	richRate = { cafe = true, best = 2, cap = 0.24, what = "rich visitor rate", studs = false },
} :: { [Kind]: KindInfo }

local function e(kind: Kind, amount: number): Effect
	return { kind = kind, amount = amount }
end

local function def(id: string, name: string, rarity: Rarity, effects: { Effect }): Def
	return { id = id, name = name, rarity = rarity, effects = effects }
end

-- Spec section 2a: the six one-effect traits, at Common, Uncommon and Rare. Ids are `<trait>_<rarity>`.
local SINGLES: { { id: string, name: string, kind: Kind, amounts: { number } } } = {
	{ id = "bigTipper", name = "Big Tipper", kind = "income", amounts = { 0.05, 0.08, 0.12 } },
	{ id = "nightOwl", name = "Night Owl", kind = "nightIncome", amounts = { 0.10, 0.15, 0.22 } },
	{ id = "fastLearner", name = "Fast Learner", kind = "xp", amounts = { 0.10, 0.15, 0.22 } },
	{ id = "luckyBowl", name = "Lucky Bowl", kind = "bowlLuck", amounts = { 0.02, 0.03, 0.04 } },
	{ id = "quickPaws", name = "Quick Paws", kind = "speed", amounts = { 0.3, 0.5, 0.7 } },
	{ id = "richFriend", name = "Rich Friend", kind = "richRate", amounts = { 0.02, 0.03, 0.04 } },
}

local list: { Def } = {}
for i, rarity in { COMMON, UNCOMMON, RARE } do
	for _, single in SINGLES do
		table.insert(
			list,
			def(
				single.id .. "_" .. rarity.id,
				single.name,
				rarity,
				{ e(single.kind, single.amounts[i]) }
			)
		)
	end
end
-- Spec section 2b: Legendary, two effects.
table.insert(
	list,
	def("goldenWhiskers", "Golden Whiskers", LEGENDARY, { e("income", 0.18), e("richRate", 0.06) })
)
table.insert(
	list,
	def(
		"moonlitHunter",
		"Moonlit Hunter",
		LEGENDARY,
		{ e("nightIncome", 0.30), e("bowlLuck", 0.06) }
	)
)
table.insert(list, def("prodigy", "Prodigy", LEGENDARY, { e("xp", 0.30), e("income", 0.10) }))
table.insert(
	list,
	def("lightningTail", "Lightning Tail", LEGENDARY, { e("speed", 1.0), e("xp", 0.20) })
)
-- Spec section 2c: Mythic, three effects.
table.insert(
	list,
	def(
		"cosmicFortune",
		"Cosmic Fortune",
		MYTHIC,
		{ e("income", 0.40), e("bowlLuck", 0.12), e("richRate", 0.12) }
	)
)
table.insert(
	list,
	def(
		"eternalNight",
		"Eternal Night",
		MYTHIC,
		{ e("nightIncome", 0.60), e("xp", 0.75), e("speed", 1.5) }
	)
)
table.insert(
	list,
	def("starSage", "Star Sage", MYTHIC, { e("xp", 1.0), e("income", 0.25), e("bowlLuck", 0.10) })
)
Traits.LIST = list

local byId: { [string]: Def } = {}
local byRarity: { [string]: { Def } } = {}
for _, entry in list do
	byId[entry.id] = entry
	local group = byRarity[entry.rarity.id]
	if group == nil then
		group = {}
		byRarity[entry.rarity.id] = group
	end
	table.insert(group, entry)
end

function Traits.get(id: string): Def?
	return byId[id]
end

-- The traits of a rarity (by its id), in LIST order.
function Traits.ofRarity(rarityId: string): { Def }
	return byRarity[rarityId] or {}
end

-- A saved trait as this code keeps it, or nil for none (an unknown id or anything else).
function Traits.sanitize(value: any): Trait?
	if type(value) ~= "table" or type(value.id) ~= "string" or byId[value.id] == nil then
		return nil
	end
	return { id = value.id }
end

-- The rarity of `trait`, nil for none.
function Traits.rarity(trait: Trait?): Rarity?
	local entry = if trait then byId[trait.id] else nil
	return if entry then entry.rarity else nil
end

-- 0 for no trait, else 1 (Common) to 5 (Mythic): a trait's weight in a trade's value check.
function Traits.rank(trait: Trait?): number
	local rarity = Traits.rarity(trait)
	return if rarity then rarity.rank else 0
end

-- `trait`'s amount of one effect kind, 0 when it has none.
function Traits.amount(trait: Trait?, kind: Kind): number
	local entry = if trait then byId[trait.id] else nil
	if entry == nil then
		return 0
	end
	local sum = 0
	for _, effect in entry.effects do
		if effect.kind == kind then
			sum += effect.amount
		end
	end
	return sum
end

-- "Big Tipper", "Cosmic Fortune" (the card shows the rarity's name and colour beside it)
function Traits.title(trait: Trait): string
	local entry = byId[trait.id]
	return if entry then entry.name else trait.id
end

-- "Rare Big Tipper"
function Traits.fullTitle(trait: Trait): string
	local entry = byId[trait.id]
	return if entry then entry.rarity.name .. " " .. entry.name else trait.id
end

-- One line per effect: "+12% this cat's income", "+0.7 studs/s walk and carry speed".
function Traits.effectLines(trait: Trait): { string }
	local entry = byId[trait.id]
	local lines: { string } = {}
	if entry == nil then
		return lines
	end
	for _, effect in entry.effects do
		local info = Traits.KINDS[effect.kind]
		local shown = if info.studs
			then string.format("+%s studs/s", tostring(effect.amount))
			else string.format("+%d%%", math.floor(effect.amount * 100 + 0.5))
		table.insert(lines, shown .. " " .. info.what)
	end
	return lines
end

-- The odds line every card shows, and the Odds button's list.
function Traits.oddsText(): string
	local parts: { string } = {}
	for _, rarity in Traits.RARITIES do
		table.insert(parts, string.format("%s %d%%", rarity.name, rarity.odds))
	end
	return table.concat(parts, ", ") .. ". Each trait inside a rarity is equally likely."
end

-- One roll: the rarity first, then a trait of that rarity evenly. `random(n)` returns a whole number from 1 to n
-- (Random:NextInteger(1, n) on the server).
function Traits.roll(random: (number) -> number): Trait
	local total = 0
	for _, rarity in Traits.RARITIES do
		total += rarity.odds
	end
	local pick = math.clamp(random(total), 1, total)
	local chosen = Traits.RARITIES[#Traits.RARITIES]
	local run = 0
	for _, rarity in Traits.RARITIES do
		run += rarity.odds
		if pick <= run then
			chosen = rarity
			break
		end
	end
	local group = byRarity[chosen.id]
	local index = math.clamp(random(#group), 1, #group)
	return { id = group[index].id }
end

-- The pool's colour steps for a rolled trait (spec section 1a): grey up to its rarity's colour, never past it.
function Traits.poolSteps(trait: Trait): { string }
	local steps: { string } = {}
	local rank = Traits.rank(trait)
	for _, rarity in Traits.RARITIES do
		if rarity.rank <= rank then
			table.insert(steps, rarity.color)
		end
	end
	return steps
end

-- The server-wide line for a Mythic roll (display names only), nil for any other rarity.
function Traits.announceText(displayName: string, trait: Trait): string?
	if Traits.rank(trait) < MYTHIC.rank then
		return nil
	end
	return string.format("%s's cat got a Mythic trait!", displayName)
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

-- A cat's own income multiplier from its trait: its income effect, plus its night income effect while `night`.
function Traits.incomeMultiplier(trait: Trait?, night: boolean): number
	local bonus = Traits.amount(trait, "income")
	if night then
		bonus += Traits.amount(trait, "nightIncome")
	end
	return 1 + bonus
end

-- A cat's own level XP multiplier (never Cafe Pass XP).
function Traits.xpMultiplier(trait: Trait?): number
	return 1 + Traits.amount(trait, "xp")
end

-- A cafe-wide effect's bonus from the working cats' traits (any order, single and combo alike): the best `best`
-- amounts added up, at most `cap`. 0 for a kind that is not cafe wide.
function Traits.cafeBonus(working: { Trait }, kind: Kind): number
	local info = Traits.KINDS[kind]
	if info == nil or not info.cafe then
		return 0
	end
	local amounts: { number } = {}
	for _, trait in working do
		local amount = Traits.amount(trait, kind)
		if amount > 0 then
			table.insert(amounts, amount)
		end
	end
	table.sort(amounts, function(a: number, b: number): boolean
		return a > b
	end)
	local sum = 0
	for i = 1, math.min(info.best, #amounts) do
		sum += amounts[i]
	end
	-- a float sum can land a hair over the cap (0.12 * 3)
	return math.min(math.floor(sum * 1000 + 0.5) / 1000, info.cap)
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
