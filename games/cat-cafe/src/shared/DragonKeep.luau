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
	wing = "+1 stud/s walk speed",
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
		text = "Customers wait 10% longer before leaving.",
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
		text = "One extra customer seat in your cafe.",
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
		text = "+3% net reach (+5% total cap with the Claw set).",
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
		text = "Bait lasts 15% longer.",
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
		text = "Gold coats show a spark from further away.",
	},
	{
		id = "dragonGaze",
		name = "Dragon Gaze",
		family = "claw",
		rarity = "Legendary",
		text = "Every 30 minutes, the next catch is guaranteed to land.",
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
		text = "+0.5 stud/s walk speed.",
	},
	{
		id = "softLanding",
		name = "Soft Landing",
		family = "wing",
		rarity = "Common",
		text = "No wait after a cannon landing.",
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
		text = "Your footsteps leave a warm ember trail (look only).",
	},
	{
		id = "quickCannon",
		name = "Quick Cannon",
		family = "wing",
		rarity = "Rare",
		text = "Cannon travel is 30% faster.",
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
		text = "Claim your Tip Jar from anywhere.",
	},
	{
		id = "dragonRide",
		name = "Dragon Ride",
		family = "wing",
		rarity = "Legendary",
		text = "Once every 10 minutes, ride Cinder to any open area.",
	},
	{
		id = "wingbeat",
		name = "Wingbeat",
		family = "wing",
		rarity = "Legendary",
		text = "+1.5 stud/s and a small gust that pushes nearby loose cats toward your net.",
	},
	{
		id = "shinyPocket",
		name = "Shiny Pocket",
		family = "hoard",
		rarity = "Common",
		text = "+2 golden fish from each daily quest set.",
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
		text = "Mystery gifts show on the map.",
	},
	{
		id = "hoarder",
		name = "Hoarder",
		family = "hoard",
		rarity = "Rare",
		text = "Crates give 10% more coins.",
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
		text = "+15 golden fish at the first catch of each day.",
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
		name = "Lucky Crate",
		family = "hoard",
		rarity = "Epic",
		text = "5% chance a crate opens twice.",
	},
	{
		id = "dragonsHoard",
		name = "Dragon's Hoard",
		family = "hoard",
		rarity = "Legendary",
		text = "Every 4 hours Cinder leaves a hoard chest in the Keep (50 to 150 golden fish).",
	},
	{
		id = "rummageKing",
		name = "Rummage King",
		family = "hoard",
		rarity = "Legendary",
		text = "The Rummage Bin's best prize odds go up by a quarter (the odds shown at the bin update to match).",
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
		text = "Oasis Spa soaks take 45 minutes, not 60.",
	},
	{
		id = "happyCrew",
		name = "Happy Crew",
		family = "heart",
		rarity = "Rare",
		text = "Staff cats start the day at full mood.",
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
		text = "The first Mystic Pool roll each day is free.",
	},
	{
		id = "bigHeart",
		name = "Big Heart",
		family = "heart",
		rarity = "Epic",
		text = "The first cat in each role earns +10% (no extra slot).",
	},
	{
		id = "dragonBond",
		name = "Dragon Bond",
		family = "heart",
		rarity = "Legendary",
		text = "Your best cat wears a little dragon wing look and earns +25%.",
	},
	{
		id = "elderLore",
		name = "Elder Lore",
		family = "heart",
		rarity = "Legendary",
		text = "Fusion Observatory fusions take 25% less time.",
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
		text = "Every 60 minutes a meteor of golden fish (20 to 40) lands in your area. Only you can pick it up.",
	},
	{
		id = "royalDecree",
		name = "Royal Decree",
		family = "crown",
		rarity = "Mythic",
		text = "Once a day, choose one cat rarity to give double Warmth and tickets for an hour.",
	},
	{
		id = "dragonHeart",
		name = "Dragon Heart",
		family = "crown",
		rarity = "Mythic",
		text = "+1 Rekindle hand every 24 hours at stage 5.",
	},
	{
		id = "mythicRoar",
		name = "Mythic Roar",
		family = "crown",
		rarity = "Mythic",
		text = "Once an hour, roar to stun every loose cat near you for 3 seconds (an easy catch).",
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
						then entry.variant
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
			then instance.variant
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
		for _, card in cardsByRarity[rarity] or {} do
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
