--!strict
-- Cat traits at the Mystic Pool (#3196, docs/design/cat-cafe/trait-station.md; Derek2 2026-11-10: "re-work the
-- picnic into a station ... to add traits 1 per cat that do things like increase food bowl luck, extra money, slight
-- speed bonus etc make it cost gold fish or trait re-roll tokens", 2026-11-11: "Yes for everything ... also give 5
-- free rerolls off start", then "make the legendary / mythic traits give combinations of multiple things"). Pure:
-- rolls come from a passed function, so the specs are deterministic.
--
-- Each cat holds one trait at a time, saved as `{ id }`; the id carries its rarity and effects (LIST). A roll picks
-- the rarity first at RARITIES' odds (Common 30, Uncommon 25, Rare 18, Epic 12, Legendary 10, Mythic 5), then one trait of that
-- rarity evenly. Common, Uncommon, Rare and Epic hold the same six one-effect traits, stronger at each rarity, and Epic
-- two two-effect traits of its own (Derek 2026-11-12: "add an epic tier and some traits"); Legendary
-- holds four two-effect traits and Mythic three three-effect traits. The first trait and every re-roll cost the same:
-- a free starter roll while any are left (FREE_ROLLS, counted up in `traitFreeRollsUsed` so a missing field never
-- grants them again), else one Trait Token, else COST_FISH golden fish. After a re-roll the player keeps the old trait
-- or takes the new one, so a cat never gets worse.
--
-- Effects (KINDS): income, night income and XP work on their own cat only. Bowl luck, speed and rich visitor rate work
-- cafe wide, only from cats in a staff slot, only the best `best` of them and at most `cap` (bowl luck 3 and 0.36,
-- speed 1 and 2.5 studs/s, rich rate 2 and 0.40); a combo's effect counts like the single trait with the same effect.
-- So a cafe full of one trait can't run away and no paid perk is undercut (spec section 5).
--
-- Trait Tokens are never traded or gifted, and golden fish are earned only. #3864 (Derek 2026-11-13): tokens are sold
-- in two bundles (BUNDLES, developer products), so a roll IS a paid random item (monetization-policy section 2): the
-- offer shows the full odds (oddsText, summing to 100) before the Roblox prompt, it is never shown to a player whose
-- policy restricts paid random items or is not read yet (TraitsView.bundles), and a "No thanks" hides it.
--
-- Everything sits behind LiveFlags `traits` (FLAG, off by default). Turning it on needs the save version step and the
-- restart publish that ships the save fields (section 6), so no older server can drop a trait.

local Types = require(script.Parent.Types)

local Traits = {}

Traits.FLAG = "traits"
Traits.NAME = "Mystic Pool"
Traits.KEEPER = "Sage Sorrel"
-- #3715 (Derek 2026-11-12: "move this station into spawn so more people see it"): the pool stands in the Town Square
-- and is open to every tier, so a new player's first cats can use the five free rolls. Before, it took the Park
-- camp's Picnic Basket's spot and that extra's Tier 2 unlock.
Traits.OPEN_TIER = 1
-- The station in the world (WorldBuilder builds it at Layout.mysticPool; MysticPoolStationService shows it while
-- the switch is on): its model, its CollectionService tag and its prompt's name.
Traits.STATION_MODEL = "CatCafe_Camp_Park_MysticPool"
Traits.TAG = "MysticPool"
Traits.PROMPT = "MysticPoolPrompt"
Traits.FREE_ROLLS = 5 -- Derek2 2026-11-11: once per player, used before tokens and fish
Traits.COST_FISH = 10 -- the first trait and every re-roll (Derek2 2026-11-10 23:59: "make re-rolls the same cost")
Traits.COST_TOKENS = 1
Traits.TOKEN_EVERY_SECONDS = 12 * 3600 -- the station's free token, on its own timer
Traits.TOKEN_HOLD = 2
Traits.TOKEN_MAX = 999 -- a save's tokens are clamped here (no source comes near it)
-- #3864: the token bundles on the card once the free rolls are used, by Catalog.products id; `robux` is the price
-- set in tools/opencloud/products.json (Roblox's own prompt shows the live price before anything is paid)
Traits.BUNDLE_FLAG = "traitBundles"
Traits.BUNDLES = table.freeze({
	table.freeze({ product = "trait_tokens_20", tokens = 20, robux = 99 }),
	table.freeze({ product = "trait_tokens_50", tokens = 50, robux = 199 }),
})

export type Trait = { id: string }

export type Kind = "income" | "nightIncome" | "xp" | "bowlLuck" | "speed" | "richRate"

export type Rarity = {
	id: string,
	name: string,
	rank: number, -- 1 Common to 6 Mythic (Epic is 4 since 2026-11-12; Legendary and Mythic moved up one)
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

-- Spec section 1a: the pool's colours and section 3's odds, in roll order. Odds since 2026-11-12 (Derek on the live
-- game: "up the rates of rarer traits by a lot"); before: 55, 28, 12, 4, 1. oddsText and the Odds list read these.
-- Mythic's colour is the Mythical cat rarity's (Theme.rarity.Mythical) since the same day: "change mythic color to
-- match the mythic cat rarity color"; it was the purple #B04FE0.
Traits.RARITIES = {
	{ id = "common", name = "Common", rank = 1, odds = 30, color = "#9AA0A6" },
	{ id = "uncommon", name = "Uncommon", rank = 2, odds = 25, color = "#4CAF50" },
	{ id = "rare", name = "Rare", rank = 3, odds = 18, color = "#3F8FE0" },
	-- Epic (Derek 2026-11-12, with the odds re-split around it): the Epic cat rarity's purple (Theme.rarity.Epic)
	{ id = "epic", name = "Epic", rank = 4, odds = 12, color = "#C07CFF" },
	{ id = "legendary", name = "Legendary", rank = 5, odds = 10, color = "#F4C430" },
	{ id = "mythic", name = "Mythic", rank = 6, odds = 5, color = "#FF5E7E" },
} :: { Rarity }

local COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, MYTHIC =
	Traits.RARITIES[1],
	Traits.RARITIES[2],
	Traits.RARITIES[3],
	Traits.RARITIES[4],
	Traits.RARITIES[5],
	Traits.RARITIES[6]

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
	bowlLuck = { cafe = true, best = 3, cap = 0.50, what = "bait bowl luck", studs = false },
	speed = { cafe = true, best = 1, cap = 2.5, what = "walk and carry speed", studs = true },
	richRate = { cafe = true, best = 2, cap = 0.40, what = "rich visitor rate", studs = false },
} :: { [Kind]: KindInfo }

local function e(kind: Kind, amount: number): Effect
	return { kind = kind, amount = amount }
end

local function def(id: string, name: string, rarity: Rarity, effects: { Effect }): Def
	return { id = id, name = name, rarity = rarity, effects = effects }
end

-- Spec section 2a: the six one-effect traits, at Common, Uncommon, Rare and Epic. Ids are `<trait>_<rarity>`. An
-- Epic single sits between its Rare and the same effect inside a Legendary. Derek 2026-11-13 ("make the epic+ traits
-- wayy better", #3871): Epic, Legendary and Mythic about two to three times what they were, caps raised to match;
-- the odds did not change.
local SINGLES: { { id: string, name: string, kind: Kind, amounts: { number } } } = {
	{
		id = "bigTipper",
		name = "Big Tipper",
		kind = "income",
		amounts = { 0.05, 0.08, 0.12, 0.25 },
	},
	{
		id = "nightOwl",
		name = "Night Owl",
		kind = "nightIncome",
		amounts = { 0.10, 0.15, 0.22, 0.40 },
	},
	{
		id = "fastLearner",
		name = "Fast Learner",
		kind = "xp",
		amounts = { 0.10, 0.15, 0.22, 0.40 },
	},
	{
		id = "luckyBowl",
		name = "Lucky Bowl",
		kind = "bowlLuck",
		amounts = { 0.02, 0.03, 0.04, 0.08 },
	},
	{ id = "quickPaws", name = "Quick Paws", kind = "speed", amounts = { 0.3, 0.5, 0.7, 1.2 } },
	{
		id = "richFriend",
		name = "Rich Friend",
		kind = "richRate",
		amounts = { 0.02, 0.03, 0.04, 0.08 },
	},
}

local list: { Def } = {}
for i, rarity in { COMMON, UNCOMMON, RARE, EPIC } do
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
-- Epic's own two: two effects each, both under a Legendary's.
table.insert(
	list,
	def("treasureNose", "Treasure Nose", EPIC, { e("income", 0.20), e("bowlLuck", 0.08) })
)
table.insert(
	list,
	def("nightSprinter", "Night Sprinter", EPIC, { e("nightIncome", 0.35), e("speed", 1.2) })
)
-- Spec section 2b: Legendary, two effects.
table.insert(
	list,
	def("goldenWhiskers", "Golden Whiskers", LEGENDARY, { e("income", 0.45), e("richRate", 0.15) })
)
table.insert(
	list,
	def(
		"moonlitHunter",
		"Moonlit Hunter",
		LEGENDARY,
		{ e("nightIncome", 0.75), e("bowlLuck", 0.15) }
	)
)
table.insert(list, def("prodigy", "Prodigy", LEGENDARY, { e("xp", 0.75), e("income", 0.30) }))
table.insert(
	list,
	def("lightningTail", "Lightning Tail", LEGENDARY, { e("speed", 2.0), e("xp", 0.50) })
)
-- Spec section 2c: Mythic, three effects.
table.insert(
	list,
	def(
		"cosmicFortune",
		"Cosmic Fortune",
		MYTHIC,
		{ e("income", 1.0), e("bowlLuck", 0.25), e("richRate", 0.25) }
	)
)
table.insert(
	list,
	def(
		"eternalNight",
		"Eternal Night",
		MYTHIC,
		{ e("nightIncome", 1.5), e("xp", 1.5), e("speed", 2.5) }
	)
)
table.insert(
	list,
	def("starSage", "Star Sage", MYTHIC, { e("xp", 2.5), e("income", 0.75), e("bowlLuck", 0.20) })
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

-- Whether a player of `tier` may use the station (the `traits` switch is checked by the caller).
function Traits.openAt(tier: number): boolean
	return tier >= Traits.OPEN_TIER
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

-- 0 for no trait, else 1 (Common) to 6 (Mythic): a trait's weight in a trade's value check.
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

-- The station's own free tokens waiting to be collected at `now` (never the banked Trait Tokens, which have no cap):
-- one per TOKEN_EVERY_SECONDS since `at`, up to TOKEN_HOLD on top of `stationHeld`. Returns the new waiting count and
-- `at` (moved on by the whole periods counted, or to now once full).
function Traits.fill(stationHeld: number, at: number, now: number): (number, number)
	if stationHeld >= Traits.TOKEN_HOLD then
		return Traits.TOKEN_HOLD, now
	end
	if now <= at then
		return stationHeld, at
	end
	local periods = (now - at) // Traits.TOKEN_EVERY_SECONDS
	if periods <= 0 then
		return stationHeld, at
	end
	local total = stationHeld + periods
	if total >= Traits.TOKEN_HOLD then
		return Traits.TOKEN_HOLD, now
	end
	return total, at + periods * Traits.TOKEN_EVERY_SECONDS
end

-- The save ------------------------------------------------------------------------------------------------------

-- A new save's Mystic Pool side at `now`: no tokens, every free roll still to use, an empty station whose first free
-- token comes TOKEN_EVERY_SECONDS after the station opens (settle moves `at` while it is shut).
function Traits.fresh(now: number): Types.TraitSave
	return { tokens = 0, freeUsed = 0, held = 0, at = now, pending = nil }
end

local function whole(value: any, low: number, high: number, default: number): number
	if type(value) ~= "number" or value ~= value then
		return default
	end
	return math.clamp(math.floor(value), low, high)
end

-- The saved side as this code keeps it. Only a save from version 48 on has it (ProfileSchema), so a missing or broken
-- `freeUsed` there reads as all used (FREE_ROLLS), never as 5 more free rolls; a missing table (an older save) is
-- fresh. `pending` is kept only for a cat in `cats` (uid -> true) with a known trait. `at` is never past `now`.
function Traits.sanitizeSave(value: any, now: number, cats: { [string]: boolean }): Types.TraitSave
	if type(value) ~= "table" then
		return Traits.fresh(now)
	end
	local save: Types.TraitSave = {
		tokens = whole(value.tokens, 0, Traits.TOKEN_MAX, 0),
		freeUsed = whole(value.freeUsed, 0, Traits.FREE_ROLLS, Traits.FREE_ROLLS),
		held = whole(value.held, 0, Traits.TOKEN_HOLD, 0),
		at = whole(value.at, 0, now, now),
		pending = nil,
	}
	local pending = value.pending
	if type(pending) == "table" and type(pending.uid) == "string" and cats[pending.uid] == true then
		local trait = Traits.sanitize(pending)
		if trait ~= nil then
			local paid: string? = pending.paid
			if paid ~= "free" and paid ~= "token" and paid ~= "fish" then
				paid = nil
			end
			local kept: Types.TraitPending = { uid = pending.uid, id = trait.id, paid = paid }
			save.pending = kept
		end
	end
	return save
end

-- Brings the station's free tokens up to `now` while it is `open`; while shut the timer waits from now, so the first
-- token comes a whole period after it opens.
function Traits.settle(save: Types.TraitSave, open: boolean, now: number)
	if not open then
		save.held = 0
		save.at = now
		return
	end
	save.held, save.at = Traits.fill(save.held, save.at, now)
end

-- The card's numbers (PlayerState.traits) for a settled save.
function Traits.view(save: Types.TraitSave): Types.TraitsView
	return {
		tokens = save.tokens,
		freeLeft = Traits.freeLeft(save.freeUsed),
		held = save.held,
		nextAt = if save.held < Traits.TOKEN_HOLD
			then save.at + Traits.TOKEN_EVERY_SECONDS
			else nil,
		pending = if save.pending ~= nil then table.clone(save.pending) else nil,
	}
end

-- Pays for one roll from `save` and the golden fish `fish` (free roll, then a token, then fish), in one step with the
-- check: returns how it was paid and the fish to take (0 or COST_FISH), or nil and nothing changed. The caller takes
-- the fish (GoldenFish.trySpend) and must undo with refund() if that fails.
function Traits.pay(save: Types.TraitSave, fish: number): (Payment?, number)
	local how = Traits.payment(save.freeUsed, save.tokens, fish)
	if how == "free" then
		save.freeUsed += 1
		return how, 0
	elseif how == "token" then
		save.tokens -= Traits.COST_TOKENS
		return how, 0
	elseif how == "fish" then
		return how, Traits.COST_FISH
	end
	return nil, 0
end

-- Gives back a roll paid by `how` (the fish, if any, are the caller's to credit).
function Traits.refund(save: Types.TraitSave, how: Payment)
	if how == "free" then
		save.freeUsed = math.max(0, save.freeUsed - 1)
	elseif how == "token" then
		save.tokens = math.min(Traits.TOKEN_MAX, save.tokens + Traits.COST_TOKENS)
	end
end

-- Adds `count` Trait Tokens to the bank (a drop, the station's collect), at most TOKEN_MAX; returns how many fit.
function Traits.give(save: Types.TraitSave, count: number): number
	local room = Traits.TOKEN_MAX - save.tokens
	local added = math.clamp(math.floor(count), 0, math.max(0, room))
	save.tokens += added
	return added
end

return Traits
