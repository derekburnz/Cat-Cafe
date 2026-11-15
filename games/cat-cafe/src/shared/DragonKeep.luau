--!strict
-- #4062 Dragon Keep (Castle late station; Design-Agent/notes/ticket-booth-and-dragon-keep.md section 2, Derek's OK
-- 2026-11-13 23:53 UTC, binder change 23:54). Spare cats move into the Keep and give Cinder Warmth; Warmth grows him
-- through 5 stages, each dealing 3 perk cards to keep one into a new slot. After stage 5, every DragonRekindle Warmth
-- deals a Rekindle hand (up to DragonHandCap waiting). Every card taken stays in the binder for good; binder cards
-- swap into slots freely; owned cards are never dealt; with all 54 owned a Rekindle pays 50 golden fish instead. Set
-- bonuses count slotted cards only. The server deals every hand from `roll` and saves it before showing it, so a
-- rejoin never rerolls it. The cards' effects come in a follow-up (their numbers inside the caps of
-- Gameplay-Engineer/notes/ticket-booth-dragon-keep-check-1.md section 4). Pure.

local CatStats = require(script.Parent.CatStats)
local Catalog = require(script.Parent.Catalog)
local Traits = require(script.Parent.Traits)
local Types = require(script.Parent.Types)

local DragonKeep = {}

DragonKeep.FLAG = "dragonKeep" -- the live switch: the Keep's remotes are refused and nothing shows while off
DragonKeep.TIER = 10 -- the Castle (Snowy 8, the Water Park 9)
DragonKeep.STAGES = {
	{ name = "Hatchling", warmth = 50 },
	{ name = "Whelp", warmth = 300 },
	{ name = "Drake", warmth = 1000 },
	{ name = "Elder", warmth = 2500 },
	{ name = "Crowned", warmth = 5000 },
}
DragonKeep.MAX_STAGE = #DragonKeep.STAGES
DragonKeep.REKINDLE = 1500
DragonKeep.HAND_CAP = 3 -- Rekindle hands waiting at most
DragonKeep.HAND_SIZE = 3
DragonKeep.KEEP_FISH = 25 -- "Keep my cards" on a Rekindle hand
DragonKeep.FULL_FISH = 50 -- a Rekindle with every card owned
DragonKeep.COLOUR_STAGE = 3
DragonKeep.COLOURS = { "ruby", "sapphire", "emerald", "amethyst" }
DragonKeep.NAPPING = 12 -- cats shown napping in the Keep, the rarest first
DragonKeep.GIVE_MAX = 200 -- cats in one GiveToKeep
DragonKeep.SET_SIZE = 3

DragonKeep.WARMTH = {
	Common = 1,
	Rare = 2,
	Epic = 4,
	Legendary = 6,
	Mythical = 10,
	Secret = 25,
} :: { [string]: number }
DragonKeep.COAT_MULT = { gold = 2, rainbow = 5 } :: { [string]: number }
-- a trait's rarity id -> the Warmth it adds (a cat with a trait is worth a little more, never less)
DragonKeep.TRAIT_BONUS =
	{ rare = 1, epic = 1, legendary = 3, mythic = 3, secret = 3 } :: { [string]: number }

DragonKeep.RARITIES = { "Common", "Rare", "Epic", "Legendary", "Mythic" }
local RARITY_RANK =
	{ Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythic = 5 } :: { [string]: number }
-- percent by rarity, for the hand that a stage (1 to 5) or a Rekindle (6) deals
local ODDS = {
	early = { Common = 45, Rare = 30, Epic = 16, Legendary = 7, Mythic = 2 },
	mid = { Common = 35, Rare = 30, Epic = 20, Legendary = 11, Mythic = 4 },
	late = { Common = 25, Rare = 30, Epic = 24, Legendary = 15, Mythic = 6 },
}
DragonKeep.PITY_STAGE = 4

-- The set bonus words per family (slotted cards only); Crown has none
DragonKeep.SETS = {
	flame = "+5% money",
	claw = "+3% net reach",
	wing = "+5% money",
	hoard = "+5 golden fish a day",
	heart = "+10% cat XP",
} :: { [string]: string }

export type Card = { id: string, name: string, family: string, rarity: string, text: string }

DragonKeep.CARDS = {
	{
		id = "warmTips",
		name = "Warm Tips",
		family = "flame",
		rarity = "Common",
		text = "+4% tips.",
	},
	{
		id = "toastyTables",
		name = "Toasty Tables",
		family = "flame",
		rarity = "Common",
		text = "+3% money.",
	},
	{
		id = "emberTips",
		name = "Ember Tips",
		family = "flame",
		rarity = "Rare",
		text = "+8% tips.",
	},
	{
		id = "nightGlow",
		name = "Night Glow",
		family = "flame",
		rarity = "Rare",
		text = "+12% night income.",
	},
	{
		id = "hotSeats",
		name = "Hot Seats",
		family = "flame",
		rarity = "Rare",
		text = "+5% money.",
	},
	{
		id = "smokeSignal",
		name = "Smoke Signal",
		family = "flame",
		rarity = "Epic",
		text = "Rich visitors come 15% more often.",
	},
	{
		id = "dragonCoin",
		name = "Dragon Coin",
		family = "flame",
		rarity = "Epic",
		text = "Every 10th customer pays double.",
	},
	{
		id = "furnace",
		name = "Furnace",
		family = "flame",
		rarity = "Epic",
		text = "Tip piles grow 20% faster.",
	},
	{
		id = "goldenBreath",
		name = "Golden Breath",
		family = "flame",
		rarity = "Legendary",
		text = "Every 10 minutes Cinder breathes gold over your cafe, paying 1 minute of income.",
	},
	{
		id = "treasureTax",
		name = "Treasure Tax",
		family = "flame",
		rarity = "Legendary",
		text = "+15% money from cats in staff slots.",
	},
	{
		id = "sharpEye",
		name = "Sharp Eye",
		family = "claw",
		rarity = "Common",
		text = "+3% bowl luck, within the luck cap.",
	},
	{
		id = "quickPaws",
		name = "Quick Paws",
		family = "claw",
		rarity = "Common",
		text = "Catch circles move 5% slower.",
	},
	{
		id = "steadyClaw",
		name = "Steady Claw",
		family = "claw",
		rarity = "Rare",
		text = "The first miss in each catch is forgiven.",
	},
	{
		id = "emberNet",
		name = "Ember Net",
		family = "claw",
		rarity = "Rare",
		text = "Nets swing 8% faster.",
	},
	{
		id = "baitWhisperer",
		name = "Bait Whisperer",
		family = "claw",
		rarity = "Rare",
		text = "Bait cats come 15% sooner.",
	},
	{
		id = "luckyScale",
		name = "Lucky Scale",
		family = "claw",
		rarity = "Epic",
		text = "+5% bowl luck, within the luck cap.",
	},
	{
		id = "doubleCatch",
		name = "Double Catch",
		family = "claw",
		rarity = "Epic",
		text = "4% chance a caught Common or Rare brings a friend (a second copy).",
	},
	{
		id = "glintSpotter",
		name = "Glint Spotter",
		family = "claw",
		rarity = "Epic",
		text = "+0.05 gold luck, within the gold cap.",
	},
	{
		id = "dragonGaze",
		name = "Dragon Gaze",
		family = "claw",
		rarity = "Legendary",
		text = "+8% bowl luck, within the luck cap.",
	},
	{
		id = "goldFever",
		name = "Gold Fever",
		family = "claw",
		rarity = "Legendary",
		text = "+0.10 gold luck, within the gold cap.",
	},
	{
		id = "lightStep",
		name = "Light Step",
		family = "wing",
		rarity = "Common",
		text = "+4% tips.",
	},
	{
		id = "softLanding",
		name = "Soft Landing",
		family = "wing",
		rarity = "Common",
		text = "+3% money.",
	},
	{
		id = "glide",
		name = "Glide",
		family = "wing",
		rarity = "Rare",
		text = "Hold jump to glide down slowly.",
	},
	{
		id = "fireTrail",
		name = "Fire Trail",
		family = "wing",
		rarity = "Rare",
		text = "+5% tips, and your footsteps leave a warm ember trail.",
	},
	{
		id = "quickCannon",
		name = "Lucky Wings",
		family = "wing",
		rarity = "Rare",
		text = "+4% bowl luck, within the luck cap.",
	},
	{
		id = "doubleJump",
		name = "Double Jump",
		family = "wing",
		rarity = "Epic",
		text = "Jump once more in the air.",
	},
	{
		id = "skyMail",
		name = "Sky Mail",
		family = "wing",
		rarity = "Epic",
		text = "Tip piles pay 10% more.",
	},
	{
		id = "dragonRide",
		name = "Dragon Ride",
		family = "wing",
		rarity = "Legendary",
		text = "+10% money.",
	},
	{
		id = "wingbeat",
		name = "Wingbeat",
		family = "wing",
		rarity = "Legendary",
		text = "Rich visitors come 15% more often.",
	},
	{
		id = "shinyPocket",
		name = "Shiny Pocket",
		family = "hoard",
		rarity = "Common",
		text = "Tip piles pay 10% more.",
	},
	{
		id = "coinSniffer",
		name = "Coin Sniffer",
		family = "hoard",
		rarity = "Common",
		text = "5% chance a tip pile drops 1 golden fish.",
	},
	{
		id = "treasureNose",
		name = "Treasure Nose",
		family = "hoard",
		rarity = "Rare",
		text = "Rich visitors come 10% more often.",
	},
	{
		id = "hoarder",
		name = "Hoarder",
		family = "hoard",
		rarity = "Rare",
		text = "Crate repeats give 25% more fish.",
	},
	{
		id = "fishScale",
		name = "Fish Scale",
		family = "hoard",
		rarity = "Rare",
		text = "Repeat Epic or better catches give +1 golden fish.",
	},
	{
		id = "gemHoard",
		name = "Gem Hoard",
		family = "hoard",
		rarity = "Epic",
		text = "+6% money.",
	},
	{
		id = "ticketDragon",
		name = "Ticket Dragon",
		family = "hoard",
		rarity = "Epic",
		text = "+25% Ticket Booth tickets.",
	},
	{
		id = "luckyCrate",
		name = "Lucky Charm",
		family = "hoard",
		rarity = "Epic",
		text = "+5% bowl luck, within the luck cap.",
	},
	{
		id = "dragonsHoard",
		name = "Dragon's Hoard",
		family = "hoard",
		rarity = "Legendary",
		text = "Tip piles pay 25% more.",
	},
	{
		id = "rummageKing",
		name = "Rummage King",
		family = "hoard",
		rarity = "Legendary",
		text = "+0.10 gold luck, within the gold cap.",
	},
	{
		id = "cosyNap",
		name = "Cosy Nap",
		family = "heart",
		rarity = "Common",
		text = "Resting cats gain 10% more XP.",
	},
	{
		id = "patPat",
		name = "Pat Pat",
		family = "heart",
		rarity = "Common",
		text = "Petting lasts 15 minutes longer.",
	},
	{
		id = "fastLearner",
		name = "Fast Learner",
		family = "heart",
		rarity = "Rare",
		text = "+10% cat XP.",
	},
	{
		id = "spaDay",
		name = "Spa Day",
		family = "heart",
		rarity = "Rare",
		text = "+10% cat XP.",
	},
	{
		id = "happyCrew",
		name = "Happy Crew",
		family = "heart",
		rarity = "Rare",
		text = "+5% money.",
	},
	{
		id = "kindred",
		name = "Kindred",
		family = "heart",
		rarity = "Epic",
		text = "Cats in the Keep add +0.1% money each, up to +10%.",
	},
	{
		id = "traitSpark",
		name = "Trait Spark",
		family = "heart",
		rarity = "Epic",
		text = "+15% cat XP.",
	},
	{
		id = "bigHeart",
		name = "Big Heart",
		family = "heart",
		rarity = "Epic",
		text = "+8% money.",
	},
	{
		id = "dragonBond",
		name = "Dragon Bond",
		family = "heart",
		rarity = "Legendary",
		text = "+12% money.",
	},
	{
		id = "elderLore",
		name = "Elder Lore",
		family = "heart",
		rarity = "Legendary",
		text = "+20% cat XP.",
	},
	{
		id = "crownOfEmbers",
		name = "Crown of Embers",
		family = "crown",
		rarity = "Mythic",
		text = "+20% money, and the crown shows over your cafe sign.",
	},
	{
		id = "skyfire",
		name = "Skyfire",
		family = "crown",
		rarity = "Mythic",
		text = "+10% bowl luck, within the luck cap.",
	},
	{
		id = "royalDecree",
		name = "Royal Decree",
		family = "crown",
		rarity = "Mythic",
		text = "+0.15 gold luck, within the gold cap.",
	},
	{
		id = "dragonHeart",
		name = "Dragon Heart",
		family = "crown",
		rarity = "Mythic",
		text = "+15% money.",
	},
	{
		id = "mythicRoar",
		name = "Mythic Roar",
		family = "crown",
		rarity = "Mythic",
		text = "Rich visitors come 25% more often.",
	},
} :: { Card }

local cardsById: { [string]: Card } = {}
local cardsByRarity: { [string]: { Card } } = {}
for _, card in DragonKeep.CARDS do
	cardsById[card.id] = card
	local list = cardsByRarity[card.rarity]
	if list == nil then
		list = {}
		cardsByRarity[card.rarity] = list
	end
	table.insert(list :: { Card }, card)
end

function DragonKeep.card(id: string): Card?
	return cardsById[id]
end

-- The hand odds for a hand of `kind` dealt at `stage`.
function DragonKeep.odds(stage: number, kind: string): { [string]: number }
	if kind == "rekindle" or stage >= 5 then
		return ODDS.late
	elseif stage >= 3 then
		return ODDS.mid
	end
	return ODDS.early
end

function DragonKeep.fresh(): Types.DragonSave
	return {
		warmth = 0,
		stage = 0,
		slots = {},
		binder = {},
		hand = {},
		queue = {},
		rekindled = 0,
		kept = 0,
		napping = {},
	}
end

local function whole(value: unknown, max: number): number
	if type(value) == "number" and value == value and value >= 0 and value < 1e12 then
		return math.min(math.floor(value), max)
	end
	return 0
end

-- A save's dragon made whole: known cards only, slots only up to the stage, no slotted card outside the binder.
function DragonKeep.sanitize(raw: unknown): Types.DragonSave
	local out = DragonKeep.fresh()
	if type(raw) ~= "table" then
		return out
	end
	local d = raw :: any
	out.warmth = whole(d.warmth, 1e12)
	out.stage = whole(d.stage, DragonKeep.MAX_STAGE)
	out.rekindled = whole(d.rekindled, 1e9)
	out.kept = whole(d.kept, 1e9)
	if type(d.binder) == "table" then
		for id, value in d.binder do
			if type(id) == "string" and cardsById[id] ~= nil and value == true then
				out.binder[id] = true
			end
		end
	end
	if type(d.slots) == "table" then
		local seen: { [string]: boolean } = {}
		for slot = 1, out.stage do
			local id = d.slots[slot]
			if type(id) == "string" and out.binder[id] == true and not seen[id] then
				out.slots[slot] = id
				seen[id] = true
			else
				out.slots[slot] = ""
			end
		end
	end
	for slot = #out.slots + 1, out.stage do
		out.slots[slot] = ""
	end
	if type(d.hand) == "table" then
		for _, id in d.hand do
			if
				type(id) == "string"
				and cardsById[id] ~= nil
				and #out.hand < DragonKeep.HAND_SIZE
			then
				table.insert(out.hand, id)
			end
		end
	end
	if type(d.queue) == "table" then
		for _, kind in d.queue do
			if
				(kind == "stage" or kind == "rekindle")
				and #out.queue < DragonKeep.MAX_STAGE + DragonKeep.HAND_CAP
			then
				table.insert(out.queue, kind)
			end
		end
	end
	if #out.hand > 0 and #out.queue == 0 then
		out.hand = {} -- a hand with no kind cannot be picked; the next deal replaces it
	end
	if type(d.colour) == "string" and table.find(DragonKeep.COLOURS, d.colour) ~= nil then
		out.colour = d.colour
	end
	if type(d.napping) == "table" then
		for _, entry in d.napping do
			if
				type(entry) == "table"
				and type(entry.id) == "string"
				and #out.napping < DragonKeep.NAPPING
			then
				table.insert(out.napping, {
					id = entry.id,
					variant = if entry.variant == "gold" or entry.variant == "rainbow"
						then entry.variant :: string
						else nil,
				})
			end
		end
	end
	return out
end

function DragonKeep.open(tier: number): boolean
	return tier >= DragonKeep.TIER
end

-- The Warmth one cat gives.
function DragonKeep.warmthOf(instance: Types.CatInstance): number
	local def = Catalog.getCat(instance.catId)
	if def == nil then
		return 0
	end
	local base = DragonKeep.WARMTH[def.rarity] or 0
	local coat = DragonKeep.COAT_MULT[instance.variant or ""] or 1
	local bonus = 0
	if instance.trait ~= nil then
		local trait = Traits.get(instance.trait.id)
		if trait ~= nil then
			bonus = DragonKeep.TRAIT_BONUS[trait.rarity.id] or 0
		end
	end
	return base * coat + bonus
end

-- Whether a cat asks once before it goes (gold, rainbow, Legendary or better).
function DragonKeep.special(instance: Types.CatInstance): boolean
	if instance.variant == "gold" or instance.variant == "rainbow" then
		return true
	end
	local def = Catalog.getCat(instance.catId)
	return def ~= nil
		and (Catalog.rarityRank[def.rarity] or 0) >= (Catalog.rarityRank.Legendary or 99)
end

DragonKeep.Messages = {
	shut = "The Dragon Keep opens with the Castle",
	notOwned = "That cat is not yours",
	locked = "Unlock that cat first",
	atSpa = "That cat is at the Oasis Spa",
	inTrade = "Finish your trade first",
	lastCat = "Keep at least one cat",
	confirm = "Confirm the special cats first",
	pending = "Choose that cat's new trait first",
}

-- Why the cats `uids` cannot all move in, or nil. `trading` an open trade or offer. `confirmed` the player's yes to a
-- gold, rainbow or Legendary and better cat in the set. Duplicate uids count once.
function DragonKeep.giveBlocker(
	profile: Types.PlayerProfile,
	tier: number,
	uids: { string },
	trading: boolean,
	confirmed: boolean
): string?
	if not DragonKeep.open(tier) then
		return DragonKeep.Messages.shut
	end
	if trading then
		return DragonKeep.Messages.inTrade
	end
	local seen: { [string]: boolean } = {}
	local count = 0
	for _, uid in uids do
		if not seen[uid] then
			seen[uid] = true
			count += 1
			local instance = profile.cats[uid]
			if instance == nil then
				return DragonKeep.Messages.notOwned
			end
			if instance.locked == true then
				return DragonKeep.Messages.locked
			end
			if CatStats.atSpa(profile, uid) then
				return DragonKeep.Messages.atSpa
			end
			-- Review-QA on #4089: a paid Mystic Pool re-roll waiting on this cat is never lost
			local pending = profile.traits.pending
			if pending ~= nil and pending.uid == uid then
				return DragonKeep.Messages.pending
			end
			if not confirmed and DragonKeep.special(instance) then
				return DragonKeep.Messages.confirm
			end
		end
	end
	local total = 0
	for _ in profile.cats do
		total += 1
	end
	if total - count < 1 then
		return DragonKeep.Messages.lastCat
	end
	return nil
end

-- The quick buttons' picks: "commons" (every Common) or "repeats" (every copy past the first of its cat), both
-- skipping locked, working, at the spa, gold, rainbow and Legendary or better cats, and the last copy of any cat.
-- Weakest first. Never the player's last cat.
function DragonKeep.quickPlan(profile: Types.PlayerProfile, kind: string): { string }
	local byCat: { [string]: { Types.CatInstance } } = {}
	local total = 0
	for _, instance in profile.cats do
		total += 1
		local list = byCat[instance.catId]
		if list == nil then
			list = {}
			byCat[instance.catId] = list
		end
		table.insert(list :: { Types.CatInstance }, instance)
	end
	local picks: { Types.CatInstance } = {}
	for catId, list in byCat do
		local def = Catalog.getCat(catId)
		if def == nil or (kind == "commons" and def.rarity ~= "Common") then
			continue
		end
		local free: { Types.CatInstance } = {}
		for _, instance in list do
			if
				instance.locked ~= true
				and instance.spotId == nil
				and not CatStats.atSpa(profile, instance.uid)
				and not DragonKeep.special(instance)
			then
				table.insert(free, instance)
			end
		end
		table.sort(free, function(a: Types.CatInstance, b: Types.CatInstance): boolean
			local la, lb = CatStats.level(a), CatStats.level(b)
			if la ~= lb then
				return la < lb
			end
			return a.uid < b.uid
		end)
		-- the last copy of any cat stays: at most #list - 1 go
		for index = 1, math.min(#free, #list - 1) do
			table.insert(picks, free[index])
		end
	end
	table.sort(picks, function(a: Types.CatInstance, b: Types.CatInstance): boolean
		local wa, wb = DragonKeep.warmthOf(a), DragonKeep.warmthOf(b)
		if wa ~= wb then
			return wa < wb
		end
		return a.uid < b.uid
	end)
	local out: { string } = {}
	for _, instance in picks do
		if #out >= math.min(DragonKeep.GIVE_MAX, total - 1) then
			break
		end
		table.insert(out, instance.uid)
	end
	return out
end

local function rarityRankOf(catId: string): number
	local def = Catalog.getCat(catId)
	return if def ~= nil then Catalog.rarityRank[def.rarity] or 0 else 0
end

-- Adds one moved-in cat to the napping list (the rarest DragonKeep.NAPPING, gold and rainbow first among equals).
local function addNapper(save: Types.DragonSave, instance: Types.CatInstance)
	table.insert(save.napping, {
		id = instance.catId,
		variant = if instance.variant == "gold" or instance.variant == "rainbow"
			then instance.variant :: string
			else nil,
	})
	local coat = { rainbow = 2, gold = 1 } :: { [string]: number }
	type Napper = { id: string, variant: string? }
	table.sort(save.napping, function(a: Napper, b: Napper): boolean
		local ra, rb = rarityRankOf(a.id), rarityRankOf(b.id)
		if ra ~= rb then
			return ra > rb
		end
		local ca, cb = coat[a.variant or ""] or 0, coat[b.variant or ""] or 0
		if ca ~= cb then
			return ca > cb
		end
		return a.id < b.id
	end)
	while #save.napping > DragonKeep.NAPPING do
		table.remove(save.napping)
	end
end

-- Queues the stage hands and Rekindle hands the Warmth has reached (Rekindle up to HAND_CAP waiting; past the cap
-- the Warmth waits too, so no hand is lost).
local function grow(save: Types.DragonSave)
	while
		save.stage < DragonKeep.MAX_STAGE
		and save.warmth >= DragonKeep.STAGES[save.stage + 1].warmth
	do
		save.stage += 1
		table.insert(save.slots, "")
		table.insert(save.queue, "stage")
	end
	if save.stage < DragonKeep.MAX_STAGE then
		return
	end
	local earned = math.floor(
		(save.warmth - DragonKeep.STAGES[DragonKeep.MAX_STAGE].warmth) / DragonKeep.REKINDLE
	)
	while save.rekindled < earned do
		local waiting = 0
		for _, kind in save.queue do
			if kind == "rekindle" then
				waiting += 1
			end
		end
		if waiting >= DragonKeep.HAND_CAP then
			break
		end
		save.rekindled += 1
		table.insert(save.queue, "rekindle")
	end
end

-- Moves the cats in (the caller checked giveBlocker): each leaves the save, its Warmth added. Returns the Warmth
-- and the stages it raised.
function DragonKeep.give(profile: Types.PlayerProfile, uids: { string }): (number, number)
	local save = profile.dragon
	local before = save.stage
	local warmth = 0
	for _, uid in uids do
		local instance = profile.cats[uid]
		if instance ~= nil then
			warmth += DragonKeep.warmthOf(instance)
			addNapper(save, instance)
			profile.cats[uid] = nil
			save.kept += 1
		end
	end
	save.warmth += warmth
	grow(save)
	return warmth, save.stage - before
end

-- Whether every card is in the binder.
function DragonKeep.allOwned(save: Types.DragonSave): boolean
	for _, card in DragonKeep.CARDS do
		if save.binder[card.id] ~= true then
			return false
		end
	end
	return true
end

-- Deals `kind`'s hand from `roll` (0 to 1): DragonKeep.HAND_SIZE different cards not owned. A rarity with every card
-- owned or taken rolls again at the shown odds among the rarities with cards left. From PITY_STAGE, a hand with no
-- Epic or better turns its third card into an Epic (or better, when every Epic is owned). Fewer cards when fewer are
-- left.
function DragonKeep.deal(save: Types.DragonSave, kind: string, roll: () -> number): { string }
	local odds = DragonKeep.odds(save.stage, kind)
	local taken: { [string]: boolean } = {}
	local function left(rarity: string): { Card }
		local out: { Card } = {}
		local cards: { Card } = cardsByRarity[rarity] or {}
		for _, card in cards do
			if save.binder[card.id] ~= true and not taken[card.id] then
				table.insert(out, card)
			end
		end
		return out
	end
	local function pickRarity(minRank: number): string?
		local total = 0
		local open: { string } = {}
		for _, rarity in DragonKeep.RARITIES do
			if RARITY_RANK[rarity] >= minRank and #left(rarity) > 0 then
				table.insert(open, rarity)
				total += odds[rarity]
			end
		end
		if #open == 0 then
			return nil
		end
		local at = roll() * total
		for _, rarity in open do
			at -= odds[rarity]
			if at < 0 then
				return rarity
			end
		end
		return open[#open]
	end
	local hand: { string } = {}
	local best = 0
	for index = 1, DragonKeep.HAND_SIZE do
		local minRank = 1
		if
			index == DragonKeep.HAND_SIZE
			and save.stage >= DragonKeep.PITY_STAGE
			and best < RARITY_RANK.Epic
		then
			minRank = RARITY_RANK.Epic
		end
		local rarity = pickRarity(minRank) or pickRarity(1)
		if rarity == nil then
			break
		end
		local pool = left(rarity)
		local card = pool[math.clamp(math.floor(roll() * #pool) + 1, 1, #pool)]
		taken[card.id] = true
		best = math.max(best, RARITY_RANK[rarity])
		table.insert(hand, card.id)
	end
	return hand
end

-- Deals the next hand when none is showing and one waits. A Rekindle with every card owned pays FULL_FISH instead
-- (returned, for the caller to credit). Returns the fish to pay.
function DragonKeep.dealNext(save: Types.DragonSave, roll: () -> number): number
	local fish = 0
	while #save.hand == 0 and #save.queue > 0 do
		local kind = save.queue[1]
		local hand = DragonKeep.deal(save, kind, roll)
		if #hand > 0 then
			save.hand = hand
			return fish
		end
		-- nothing left to deal: a Rekindle pays fish; a stage hand (cannot happen with 54 cards) is skipped
		table.remove(save.queue, 1)
		if kind == "rekindle" then
			fish += DragonKeep.FULL_FISH
		end
	end
	return fish
end

-- Why card `index` of the hand cannot be taken into `slot` (nil for the binder), or nil.
function DragonKeep.pickBlocker(save: Types.DragonSave, index: number, slot: number?): string?
	if #save.hand == 0 or #save.queue == 0 then
		return "No cards to pick"
	end
	if save.hand[index] == nil then
		return "Pick one of the cards"
	end
	if slot ~= nil and (slot < 1 or slot > #save.slots) then
		return "That slot is not open yet"
	end
	return nil
end

-- Takes card `index` (the caller checked pickBlocker) into the binder. A stage hand fills the first empty slot; a
-- Rekindle hand goes into `slot` when given (the card there stays in the binder). Returns the card id and its slot.
function DragonKeep.pick(save: Types.DragonSave, index: number, slot: number?): (string, number?)
	local id = save.hand[index]
	local kind = table.remove(save.queue, 1)
	save.hand = {}
	save.binder[id] = true
	local into: number? = nil
	if kind == "stage" then
		into = table.find(save.slots, "")
	else
		into = slot
	end
	if into ~= nil then
		save.slots[into] = id
	end
	return id, into
end

-- "Keep my cards" on a Rekindle hand: the hand goes, KEEP_FISH for the caller to pay. False for a stage hand (a
-- stage up always gives a perk) or no hand.
function DragonKeep.keepCards(save: Types.DragonSave): boolean
	if #save.hand == 0 or save.queue[1] ~= "rekindle" then
		return false
	end
	table.remove(save.queue, 1)
	save.hand = {}
	return true
end

-- Why binder card `id` cannot go into `slot`, or nil.
function DragonKeep.slotBlocker(save: Types.DragonSave, id: string, slot: number): string?
	if save.binder[id] ~= true then
		return "That card is not in your binder"
	end
	if slot < 1 or slot > #save.slots then
		return "That slot is not open yet"
	end
	if save.slots[slot] == id then
		return "That card is in that slot already"
	end
	return nil
end

-- Puts binder card `id` into `slot` (the caller checked slotBlocker). A card already slotted elsewhere swaps places
-- with the one in `slot`; otherwise the one in `slot` goes back to the binder only.
function DragonKeep.slot(save: Types.DragonSave, id: string, slot: number)
	local from = table.find(save.slots, id)
	local was = save.slots[slot]
	save.slots[slot] = id
	if from ~= nil then
		save.slots[from] = was
	end
end

-- The families with a set lit (DragonKeep.SET_SIZE slotted cards of it), in SETS order.
function DragonKeep.sets(save: Types.DragonSave): { string }
	local counts: { [string]: number } = {}
	for _, id in save.slots do
		local card = cardsById[id]
		if card ~= nil then
			counts[card.family] = (counts[card.family] or 0) + 1
		end
	end
	local out: { string } = {}
	for _, family in { "flame", "claw", "wing", "hoard", "heart" } do
		if (counts[family] or 0) >= DragonKeep.SET_SIZE then
			table.insert(out, family)
		end
	end
	return out
end

-- #4447 part 1: what the slotted cards and lit sets do (slotted cards only; binder cards do nothing). Pure, read by
-- Economy while the dragonKeep switch is on. All card money is additive into cafeMultiplier (Economy), never a
-- multiplier on top, and money plus tips is held to MONEY_CAP together (Gameplay-Engineer's check, section 4).
DragonKeep.MONEY_CAP = 0.50
-- #4569 (Derek 2026-11-15 18:27 UTC: "all cards have some value", no faster flight, no move faster after the cannon,
-- no look-only cards, no "see gold coats from further away"): every card pays a bonus that is already wired (money,
-- tips, bowl luck, gold luck, rich visitors, tip piles, cat XP). Crate, trait and spin luck and the set looks follow.
DragonKeep.MONEY = { -- card id -> what it adds into cafeMultiplier
	dragonCoin = 0.10, -- every 10th customer pays double, as a steady +10%
	treasureTax = 0.15, -- every earning cat is in a staff slot
	crownOfEmbers = 0.20,
	toastyTables = 0.03,
	hotSeats = 0.05,
	softLanding = 0.03,
	dragonRide = 0.10,
	gemHoard = 0.06,
	happyCrew = 0.05,
	bigHeart = 0.08,
	dragonBond = 0.12,
	dragonHeart = 0.15,
} :: { [string]: number }
DragonKeep.TIPS =
	{ warmTips = 0.04, emberTips = 0.08, lightStep = 0.04, fireTrail = 0.05 } :: { [string]: number } -- into Economy.tipMultiplier
DragonKeep.SET_MONEY = { flame = 0.05, wing = 0.05 } :: { [string]: number }
DragonKeep.BOWL_LUCK = { -- card id -> bowl luck (a Luck source, inside LuckMax)
	luckyScale = 0.05,
	sharpEye = 0.03,
	dragonGaze = 0.08,
	quickCannon = 0.04,
	luckyCrate = 0.05,
	skyfire = 0.10,
} :: { [string]: number }
DragonKeep.GOLD = { -- card id -> gold luck (inside GoldLuckMax with the Index's)
	goldFever = 0.10,
	glintSpotter = 0.05,
	rummageKing = 0.10,
	royalDecree = 0.15,
} :: { [string]: number }
DragonKeep.RICH_CARDS = { -- card id -> share more rich visitors (into Economy.richRate)
	smokeSignal = 0.15,
	wingbeat = 0.15,
	treasureNose = 0.10,
	mythicRoar = 0.25,
} :: { [string]: number }
DragonKeep.CAP = 0.50 -- bowl luck, rich visitors and tip piles from cards, each in total
DragonKeep.LUCK = 0.05 -- Lucky Scale: +5% bowl luck (a Luck source, inside LuckMax)
DragonKeep.GOLD_LUCK = 0.10 -- Gold Fever: +0.10 gold luck, inside GoldLuckMax with the Index's
DragonKeep.REACH = {} :: { [string]: number } -- #4569: Sharp Eye is bowl luck now -- share of NetReachStuds added to the net's reach
DragonKeep.SET_REACH = { claw = 0.03 } :: { [string]: number }
DragonKeep.REACH_CAP = 0.05 -- card reach in total, so it stays under the Long Net's +1 stud
DragonKeep.SLOW_RINGS = 0.05 -- Quick Paws: catch circles move 5% slower (their shrink time 5% longer)
DragonKeep.FRIEND_CHANCE = 0.04 -- Double Catch: a caught Common or Rare brings a second copy
DragonKeep.SWING = 0.08 -- Ember Net: nets swing 8% faster (NetSwingCooldown 8% shorter)
DragonKeep.TICKET_BONUS = 0.25 -- Ticket Dragon: +25% Ticket Booth tickets (rounded down a catch)
DragonKeep.REPEAT_FISH = 1 -- Fish Scale: a repeat Epic or better catch gives +1 golden fish
DragonKeep.WALK = {} :: { [string]: number } -- stud/s on the walk speed; #4569: no card adds walk speed now
DragonKeep.SET_WALK = {} :: { [string]: number }
DragonKeep.XP =
	{ fastLearner = 0.10, spaDay = 0.10, traitSpark = 0.15, elderLore = 0.20 } :: { [string]: number } -- share more cat XP, every cat
DragonKeep.SET_XP = { heart = 0.10 } :: { [string]: number }
DragonKeep.REST_XP = 0.10 -- Cosy Nap: resting cats (no spot) gain 10% more XP
DragonKeep.KINDRED_EACH = 0.001 -- Kindred: +0.1% money for each cat ever given to the Keep (save.kept)
DragonKeep.KINDRED_MAX = 0.10
DragonKeep.NIGHT = 0.12 -- Night Glow: +12% income at night (Economy.nightTraitRate)
DragonKeep.PET_EXTRA = 15 * 60 -- Pat Pat: a pet's happy heart lasts 15 minutes longer (inside Pet.EXTRA_MAX)
DragonKeep.RICH = 0.15 -- Smoke Signal: rich visitors come 15% more often (into Economy.richRate)
DragonKeep.PILE =
	{ furnace = 0.20, skyMail = 0.10, shinyPocket = 0.10, dragonsHoard = 0.25 } :: { [string]: number } -- share more on each tip pile
-- (Furnace's "20% faster" is paid as 20% more a pile on the same clock; Sky Mail's text since Design-Agent, Nov 15)
DragonKeep.REFUND = 0.25 -- Hoarder: a crate repeat's golden fish refund 25% more (rounded down)
DragonKeep.BAIT_SPEED = 0.15 -- Bait Whisperer: the bowl wait 15% shorter, inside Config.BaitSpeedMax
DragonKeep.PILE_FISH_CHANCE = 0.05 -- Coin Sniffer: a tip pile drops 1 golden fish
DragonKeep.BREATH_EVERY = 600 -- Golden Breath: every 10 minutes of play...
DragonKeep.BREATH_SECONDS = 60 -- ...Cinder pays 1 minute of the cafe's income
DragonKeep.WALK_CAP = 2 -- card walk speed in total, stud/s (with and without a cat)

export type Effects = {
	money: number,
	tips: number,
	tickets: number,
	repeatFish: number,
	luck: number,
	goldLuck: number,
	reach: number,
	swing: number,
	slowRings: number,
	forgive: boolean, -- Steady Claw: the first Miss in each net catch costs no trust
	friend: number, -- Double Catch's chance
	walk: number, -- stud/s added to the walk speed, inside WALK_CAP
	softLanding: boolean, -- Soft Landing: no CannonCooldownSeconds wait after a landing
	doubleJump: boolean, -- Double Jump: once more in the air (shared/AirMoves)
	glide: boolean, -- Glide: hold jump to fall slowly (shared/AirMoves)
	xp: number, -- share more cat XP for every cat (Economy.grantXp)
	restXp: number, -- share more on top for a resting cat
	night: number, -- share more income at night
	petExtra: number, -- seconds more on each pet's happy heart
	rich: number, -- added to Economy.richRate
	pile: number, -- share more on each tip pile
	pileFish: number, -- chance a tip pile drops 1 golden fish
	breath: boolean, -- Golden Breath (DragonKeepService)
	refund: number, -- share more on a crate repeat's fish refund
	baitSpeed: number, -- share off the bowl wait (Economy.baitWaitSeconds)
}

function DragonKeep.effects(save: Types.DragonSave): Effects
	local money, tips, tickets, repeatFish, luck, goldLuck, reach, swing = 0, 0, 0, 0, 0, 0, 0, 0
	local slowRings, forgive, friend, walk, softLanding = 0, false, 0, 0, false
	local doubleJump, glide, xp, restXp, night, petExtra = false, false, 0, 0, 0, 0
	local rich, pile, pileFish, breath, refund, baitSpeed = 0, 0, 0, false, 0, 0
	for _, id in save.slots do
		if cardsById[id] ~= nil then
			money += DragonKeep.MONEY[id] or 0
			tips += DragonKeep.TIPS[id] or 0
			reach += DragonKeep.REACH[id] or 0
			walk += DragonKeep.WALK[id] or 0
			xp += DragonKeep.XP[id] or 0
			pile += DragonKeep.PILE[id] or 0
			luck += DragonKeep.BOWL_LUCK[id] or 0
			goldLuck += DragonKeep.GOLD[id] or 0
			rich += DragonKeep.RICH_CARDS[id] or 0
			if id == "kindred" then
				money += math.min(save.kept * DragonKeep.KINDRED_EACH, DragonKeep.KINDRED_MAX)
			end
			if id == "ticketDragon" then
				tickets = DragonKeep.TICKET_BONUS
			elseif id == "fishScale" then
				repeatFish = DragonKeep.REPEAT_FISH
			elseif id == "emberNet" then
				swing = DragonKeep.SWING
			elseif id == "quickPaws" then
				slowRings = DragonKeep.SLOW_RINGS
			elseif id == "steadyClaw" then
				forgive = true
			elseif id == "doubleCatch" then
				friend = DragonKeep.FRIEND_CHANCE
			elseif id == "doubleJump" then
				doubleJump = true
			elseif id == "glide" then
				glide = true
			elseif id == "cosyNap" then
				restXp = DragonKeep.REST_XP
			elseif id == "nightGlow" then
				night = DragonKeep.NIGHT
			elseif id == "patPat" then
				petExtra = DragonKeep.PET_EXTRA
			elseif id == "hoarder" then
				refund = DragonKeep.REFUND
			elseif id == "baitWhisperer" then
				baitSpeed = DragonKeep.BAIT_SPEED
			elseif id == "coinSniffer" then
				pileFish = DragonKeep.PILE_FISH_CHANCE
			elseif id == "goldenBreath" then
				breath = true
			end
		end
	end
	for _, family in DragonKeep.sets(save) do
		money += DragonKeep.SET_MONEY[family] or 0
		reach += DragonKeep.SET_REACH[family] or 0
		walk += DragonKeep.SET_WALK[family] or 0
		xp += DragonKeep.SET_XP[family] or 0
	end
	luck = math.min(luck, DragonKeep.CAP)
	goldLuck = math.min(goldLuck, DragonKeep.CAP)
	rich = math.min(rich, DragonKeep.CAP)
	pile = math.min(pile, DragonKeep.CAP)
	reach = math.min(reach, DragonKeep.REACH_CAP)
	walk = math.min(walk, DragonKeep.WALK_CAP)
	money = math.min(money, DragonKeep.MONEY_CAP)
	tips = math.min(tips, DragonKeep.MONEY_CAP - money)
	return {
		money = money,
		tips = tips,
		tickets = tickets,
		repeatFish = repeatFish,
		luck = luck,
		goldLuck = goldLuck,
		reach = reach,
		swing = swing,
		slowRings = slowRings,
		forgive = forgive,
		friend = friend,
		walk = walk,
		softLanding = softLanding,
		doubleJump = doubleJump,
		glide = glide,
		xp = xp,
		restXp = restXp,
		night = night,
		petExtra = petExtra,
		rich = rich,
		pile = pile,
		pileFish = pileFish,
		breath = breath,
		refund = refund,
		baitSpeed = baitSpeed,
	}
end

-- The effects a profile has now: DragonKeep.effects of its save while the dragonKeep switch is on (its
-- ReplicatedStorage attribute, set by LiveFlagService for both sides; specs set it with setOn), else all zero.
local onOverride: boolean? = nil
function DragonKeep.setOn(on: boolean?)
	onOverride = on
end
local NONE: Effects = table.freeze({
	money = 0,
	tips = 0,
	tickets = 0,
	repeatFish = 0,
	luck = 0,
	goldLuck = 0,
	reach = 0,
	swing = 0,
	slowRings = 0,
	forgive = false,
	friend = 0,
	walk = 0,
	softLanding = false,
	doubleJump = false,
	glide = false,
	xp = 0,
	restXp = 0,
	night = 0,
	petExtra = 0,
	rich = 0,
	pile = 0,
	pileFish = 0,
	breath = false,
	refund = 0,
	baitSpeed = 0,
}) :: any
function DragonKeep.of(profile: Types.PlayerProfile): Effects
	local on = if onOverride ~= nil
		then onOverride
		else game:GetService("ReplicatedStorage"):GetAttribute("LiveFlag_" .. DragonKeep.FLAG)
			== true
	local save = (profile :: any).dragon
	if not on or type(save) ~= "table" then
		return NONE
	end
	return DragonKeep.effects(save)
end

-- Fish Scale's golden fish for one catch: a repeat (not a new Index entry) of Epic or better.
local REPEAT_RANK =
	{ Epic = true, Legendary = true, Mythical = true, Secret = true } :: { [string]: boolean }
function DragonKeep.catchFish(fx: Effects, rarity: string, isNew: boolean): number
	if isNew or not REPEAT_RANK[rarity] then
		return 0
	end
	return fx.repeatFish
end

-- Double Catch: whether a caught `rarity` cat brings a friend, for a roll in [0, 1). Common and Rare only.
function DragonKeep.bringsFriend(fx: Effects, rarity: string, roll: number): boolean
	return (rarity == "Common" or rarity == "Rare") and roll < fx.friend
end

-- Coin Sniffer's golden fish for one tip pile: 1 when `roll` (0 to 1) lands inside its chance.
function DragonKeep.pileFish(fx: Effects, roll: number): number
	return if roll < fx.pileFish then 1 else 0
end

-- Ticket Dragon's extra tickets on a catch that credited `n`.
function DragonKeep.extraTickets(fx: Effects, n: number): number
	return math.floor(n * fx.tickets)
end

-- The Warmth still to the next stage or Rekindle hand.
function DragonKeep.nextAt(save: Types.DragonSave): number
	if save.stage < DragonKeep.MAX_STAGE then
		return DragonKeep.STAGES[save.stage + 1].warmth
	end
	return DragonKeep.STAGES[DragonKeep.MAX_STAGE].warmth
		+ (save.rekindled + 1) * DragonKeep.REKINDLE
end

-- Hands waiting (the "!" and the picker line), the one showing included.
function DragonKeep.handsReady(save: Types.DragonSave): number
	return #save.queue
end

-- For the Keep window (PlayerState.dragon).
function DragonKeep.view(save: Types.DragonSave): Types.DragonView
	local napping: { { id: string, variant: string? } } = {}
	for _, entry in save.napping do
		table.insert(napping, { id = entry.id, variant = entry.variant })
	end
	return {
		warmth = save.warmth,
		stage = save.stage,
		stageName = if save.stage > 0 then DragonKeep.STAGES[save.stage].name else nil,
		nextAt = DragonKeep.nextAt(save),
		slots = table.clone(save.slots),
		binder = table.clone(save.binder),
		hand = table.clone(save.hand),
		handKind = save.queue[1],
		hands = #save.queue,
		colour = save.colour,
		sets = DragonKeep.sets(save),
		napping = napping,
		kept = save.kept,
		odds = DragonKeep.odds(save.stage, save.queue[1] or "stage"),
	}
end

return DragonKeep
