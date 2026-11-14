--!strict
-- #4104 (Design-Agent's fusion-observatory.md, for #4027; Derek 2026-11-13: "5 mythic normals make 1 gold of that
-- mythic, 5 gold mythics makes 1 rainbow of that mythic but for all tiers"): the Snowy Mountain's Fusion Observatory.
-- Five copies of one cat in one coat become one copy of the next coat (base to gold, gold to rainbow) after a wait in
-- the dome. Nothing is sold, sped up or random, and it never touches catch, luck, gold or rainbow odds.
--   Fusion.startBlocker(...)   why five uids cannot start now, or nil
--   Fusion.start(...)          the five leave the save and the dome holds the result (the caller checked the blocker)
--   Fusion.collect(...)        the result back into the save once it is done
--   Fusion.sanitize(raw)       the save field, from anything
--   Fusion.view(save, ...)     PlayerState.fusion
-- Pure, so the window and the specs read the same rules.

local CatStats = require(script.Parent.CatStats)
local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Traits = require(script.Parent.Traits)
local Types = require(script.Parent.Types)

local Fusion = {}

Fusion.FLAG = "fusion" -- the live switch; it goes on with the Snowy Mountain update's restart (save version 50)
Fusion.TIER = Config.FusionTier
Fusion.COPIES = Config.FusionCopies
Fusion.ELDER_LORE = "elderLore" -- the Dragon Keep card that takes ELDER_LORE_CUT off every fusion
Fusion.ELDER_LORE_CUT = 0.25
Fusion.COATS = table.freeze({ "gold", "rainbow" })

-- The coat five copies in `variant` make, or nil at the top coat (rainbow) or for an unknown one.
function Fusion.nextCoat(variant: string?): string?
	if variant == nil or variant == "base" then
		return "gold"
	elseif variant == "gold" then
		return "rainbow"
	end
	return nil
end

function Fusion.open(tier: number): boolean
	return tier >= Fusion.TIER
end

-- Whether a cat can be fused at all: every cat but the shop-only ones, which have no gold or rainbow look.
function Fusion.fusable(catId: string): boolean
	local def = Catalog.getCat(catId)
	return def ~= nil and def.exclusive ~= true
end

-- How long a fusion into `coat` takes, with the Elder Lore card slotted or not.
function Fusion.seconds(coat: string, elderLore: boolean?): number
	local base = if coat == "rainbow" then Config.FusionRainbowSeconds else Config.FusionGoldSeconds
	return math.floor(base * (if elderLore == true then 1 - Fusion.ELDER_LORE_CUT else 1) + 0.5)
end

-- Whether the Dragon Keep's Elder Lore card sits in one of Cinder's slots.
function Fusion.hasElderLore(profile: Types.PlayerProfile): boolean
	local dragon = (profile :: any).dragon
	return type(dragon) == "table"
		and type(dragon.slots) == "table"
		and table.find(dragon.slots, Fusion.ELDER_LORE) ~= nil
end

Fusion.Messages = table.freeze({
	shut = "The Fusion Observatory opens at Tier 8",
	busy = "The dome is busy",
	count = string.format("Pick exactly %d cats", Config.FusionCopies),
	notOwned = "That cat is not yours",
	mixed = "Pick copies of one cat in one coat",
	top = "Rainbow is the top coat",
	cannot = "That cat cannot be fused",
	locked = "Unlock that cat first",
	working = "Take that cat off its job first",
	atSpa = "That cat is at the Oasis Spa",
	pending = "Choose that cat's new trait first",
	inTrade = "Finish your trade first",
	trait = "Pick a trait from the five",
	notReady = "The fusion is not done yet",
	empty = "The dome is empty",
})

-- Why `uid` cannot go in, or nil. Trades are checked by the caller (`trading`).
function Fusion.busyReason(profile: Types.PlayerProfile, uid: string): string?
	local instance = profile.cats[uid]
	if instance == nil then
		return Fusion.Messages.notOwned
	end
	if instance.locked == true then
		return Fusion.Messages.locked
	end
	if instance.spotId ~= nil then
		return Fusion.Messages.working
	end
	if CatStats.atSpa(profile, uid) then
		return Fusion.Messages.atSpa
	end
	local pending = profile.traits.pending
	if pending ~= nil and pending.uid == uid then
		return Fusion.Messages.pending
	end
	return nil
end

-- Why the five `uids` cannot start a fusion now, or nil. `trading` an open trade or one of them offered.
function Fusion.startBlocker(
	profile: Types.PlayerProfile,
	tier: number,
	uids: { string },
	keepTraitUid: string?,
	trading: boolean
): string?
	if not Fusion.open(tier) then
		return Fusion.Messages.shut
	end
	if profile.fusion.running ~= nil then
		return Fusion.Messages.busy
	end
	if #uids ~= Fusion.COPIES then
		return Fusion.Messages.count
	end
	if trading then
		return Fusion.Messages.inTrade
	end
	local seen: { [string]: boolean } = {}
	local catId: string? = nil
	local variant: string? = nil
	local keepFound = keepTraitUid == nil
	for _, uid in uids do
		if seen[uid] then
			return Fusion.Messages.count
		end
		seen[uid] = true
		local reason = Fusion.busyReason(profile, uid)
		if reason ~= nil then
			return reason
		end
		local instance = profile.cats[uid]
		local coat = instance.variant or "base"
		if catId == nil then
			catId, variant = instance.catId, coat
		elseif instance.catId ~= catId or coat ~= variant then
			return Fusion.Messages.mixed
		end
		if uid == keepTraitUid then
			keepFound = instance.trait ~= nil
		end
	end
	if Fusion.nextCoat(variant) == nil then
		return Fusion.Messages.top
	end
	if catId == nil or not Fusion.fusable(catId) then
		return Fusion.Messages.cannot
	end
	if not keepFound then
		return Fusion.Messages.trait
	end
	return nil
end

-- The copy whose level, XP and name the result keeps: the best level, then the most XP, then the best charm, then uid.
local function better(a: Types.CatInstance, b: Types.CatInstance): boolean
	local la, lb = CatStats.level(a), CatStats.level(b)
	if la ~= lb then
		return la > lb
	end
	if (a.xp or 0) ~= (b.xp or 0) then
		return (a.xp or 0) > (b.xp or 0)
	end
	if CatStats.charm(a) ~= CatStats.charm(b) then
		return CatStats.charm(a) > CatStats.charm(b)
	end
	return a.uid < b.uid
end

-- The window's default pick for `catId` in `variant` (section 1): the best copy plus the four weakest others, among
-- the free copies (`free(uid)` false skips a busy one). Fewer than COPIES when there are not enough.
function Fusion.defaultPick(
	profile: Types.PlayerProfile,
	catId: string,
	variant: string,
	free: ((string) -> boolean)?
): { string }
	local list: { Types.CatInstance } = {}
	for uid, instance in profile.cats do
		if
			instance.catId == catId
			and (instance.variant or "base") == variant
			and Fusion.busyReason(profile, uid) == nil
			and (free == nil or free(uid))
		then
			table.insert(list, instance)
		end
	end
	if #list < Fusion.COPIES then
		local out = {}
		for _, instance in list do
			table.insert(out, instance.uid)
		end
		return out
	end
	table.sort(list, better)
	local out = { list[1].uid }
	for index = #list, 2, -1 do
		if #out >= Fusion.COPIES then
			break
		end
		table.insert(out, list[index].uid)
	end
	return out
end

-- The trait the result keeps: `keepTraitUid`'s, or with none named the rarest of the five (none when none has one).
local function keptTrait(
	profile: Types.PlayerProfile,
	uids: { string },
	keepTraitUid: string?
): Types.TraitData?
	if keepTraitUid ~= nil then
		local chosen = profile.cats[keepTraitUid]
		return if chosen ~= nil and chosen.trait ~= nil then { id = chosen.trait.id } else nil
	end
	local best: Types.TraitData? = nil
	for _, uid in uids do
		local trait = profile.cats[uid].trait
		if trait ~= nil and Traits.rank(trait) > Traits.rank(best) then
			best = { id = trait.id }
		end
	end
	return best
end

-- Starts the fusion (the caller checked startBlocker): the five leave the save and the dome holds the result.
-- Returns the result's coat.
function Fusion.start(
	profile: Types.PlayerProfile,
	uids: { string },
	keepTraitUid: string?,
	now: number,
	elderLore: boolean?
): string
	local best = profile.cats[uids[1]]
	for _, uid in uids do
		if better(profile.cats[uid], best) then
			best = profile.cats[uid]
		end
	end
	local coat = Fusion.nextCoat(best.variant) :: string
	local trait = keptTrait(profile, uids, keepTraitUid)
	profile.fusion.running = {
		catId = best.catId,
		coat = coat,
		startedAt = now,
		doneAt = now + Fusion.seconds(coat, elderLore),
		level = CatStats.level(best),
		xp = best.xp or 0,
		charm = CatStats.charm(best),
		name = best.name,
		trait = trait,
	}
	for _, uid in uids do
		profile.cats[uid] = nil
	end
	return coat
end

function Fusion.collectBlocker(save: Types.FusionSave, now: number): string?
	local running = save.running
	if running == nil then
		return Fusion.Messages.empty
	end
	if now < running.doneAt then
		return Fusion.Messages.notReady
	end
	return nil
end

-- Collects the result (the caller checked collectBlocker) as a new instance with `uid`, unlocked and resting. Its
-- coat counts as found in the Index. Returns the instance and whether the coat was new for this cat.
function Fusion.collect(
	profile: Types.PlayerProfile,
	uid: string,
	now: number
): (Types.CatInstance, boolean)
	local running = profile.fusion.running :: Types.FusionRunning
	local instance = CatStats.newInstance(uid, running.catId, now, running.charm)
	instance.variant = running.coat
	instance.level = running.level
	instance.xp = running.xp
	instance.name = running.name
	instance.trait = running.trait
	profile.cats[uid] = instance
	local book = if running.coat == "rainbow"
		then profile.rainbowCollection
		else profile.goldCollection
	local first = book[running.catId] == nil
	if first then
		book[running.catId] = now
	end
	if profile.collection[running.catId] == nil then
		profile.collection[running.catId] = now -- never the case for a fusion's own cat, kept for safety
	end
	local made = profile.fusion.made
	if running.coat == "rainbow" then
		made.rainbow += 1
	else
		made.gold += 1
	end
	profile.fusion.running = nil
	return instance, first
end

function Fusion.fresh(): Types.FusionSave
	return { running = nil, made = { gold = 0, rainbow = 0 } }
end

local function count(value: any): number
	if type(value) ~= "number" or value ~= value or value < 0 or value == math.huge then
		return 0
	end
	return math.floor(value)
end

-- The save field from anything. A running fusion stays only with a known cat, a known coat and a doneAt no later than
-- the longest fusion after its start; otherwise it is dropped. `name` passes through `cleanName`.
function Fusion.sanitize(raw: any, cleanName: ((any) -> string?)?): Types.FusionSave
	local save = Fusion.fresh()
	if type(raw) ~= "table" then
		return save
	end
	if type(raw.made) == "table" then
		save.made.gold = count(raw.made.gold)
		save.made.rainbow = count(raw.made.rainbow)
	end
	local running = raw.running
	if
		type(running) == "table"
		and type(running.catId) == "string"
		and Catalog.getCat(running.catId) ~= nil
		and table.find(Fusion.COATS, running.coat) ~= nil
		and type(running.startedAt) == "number"
		and running.startedAt == running.startedAt
		and type(running.doneAt) == "number"
		and running.doneAt == running.doneAt
		and running.doneAt
			<= running.startedAt + math.max(Config.FusionGoldSeconds, Config.FusionRainbowSeconds)
	then
		local probe = { level = running.level, charm = running.charm } :: any
		save.running = {
			catId = running.catId,
			coat = running.coat,
			startedAt = running.startedAt,
			doneAt = running.doneAt,
			level = CatStats.level(probe),
			xp = count(running.xp),
			charm = CatStats.charm(probe),
			name = if cleanName ~= nil then cleanName(running.name) else nil,
			trait = Traits.sanitize(running.trait),
		}
	end
	return save
end

-- PlayerState.fusion: the dome and the times after Elder Lore.
function Fusion.view(save: Types.FusionSave, now: number, elderLore: boolean?): Types.FusionView
	local running = save.running
	local shown: any = nil
	if running ~= nil then
		local rarity = Traits.rarity(running.trait)
		shown = {
			catId = running.catId,
			coat = running.coat,
			doneAt = running.doneAt,
			level = running.level,
			name = running.name,
			trait = if running.trait ~= nil and rarity ~= nil
				then { id = running.trait.id, rarity = rarity.id }
				else nil,
		}
	end
	return {
		running = shown,
		ready = running ~= nil and now >= running.doneAt,
		goldSeconds = Fusion.seconds("gold", elderLore),
		rainbowSeconds = Fusion.seconds("rainbow", elderLore),
		made = { gold = save.made.gold, rainbow = save.made.rainbow },
	}
end

return Fusion
