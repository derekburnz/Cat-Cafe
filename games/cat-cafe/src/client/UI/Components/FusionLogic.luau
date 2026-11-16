--!strict
-- #4104 Fusion Observatory window (Design-Agent/notes/fusion-observatory.md section 2): what the window shows from
-- PlayerState.fusion and the player's cats. Five copies of one cat in one coat make one in the next coat. Pure apart
-- from the shared modules it reads (Catalog, CatStats, Traits), so the specs check it.
--   groups(cats, busy) -> (ready, almost)        the cats and coats with 5+ free copies, and those at 3 or 4
--   defaultPick(group) -> { string }             the five lowest level copies (#4588)
--   allPlan(ready, cap) -> (sets, list)          #4589 Fuse all: how many sets one tap fuses, and a short list
--   allButton(sets, domeState, armed)            #4589 the Fuse all button's words and whether it can be pressed
--   madeText(made, catName) -> (name, level)     #4589 one cat on the Fuse all summary: "Gold Mochi", "Lv 12"
--   result(group, picked) -> Result              the level, name and traits the new cat may keep
--   dome(view, now) -> Dome                      the dome card: free, running with a timer, or ready
--   clock(seconds) -> string                     "6:42", "1:02:05"
--   fuseText(group, armed) -> string             "Fuse 5 → 1 Gold" or the second tap's words
--   coatTrack(cats, collection) -> { Track }     the Index tab: each cat's three coats, found and owned

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CatStats = require(Shared:WaitForChild("CatStats")) :: any
local Catalog = require(Shared:WaitForChild("Catalog")) :: any
local Traits = require(Shared:WaitForChild("Traits")) :: any

local FusionLogic = {}

FusionLogic.COPIES = 5 -- shared FusionCopies
FusionLogic.ALMOST_FROM = 3 -- copies from which a cat shows as "1 more" or "2 more"
FusionLogic.ALMOST_SHOWN = 3
FusionLogic.NEXT = { base = "gold", gold = "rainbow" } :: { [string]: string }
FusionLogic.COAT_NAMES =
	{ base = "Normal", gold = "Gold", rainbow = "Rainbow" } :: { [string]: string }
FusionLogic.ICE = Color3.fromHex("7FC8F0")

local RARITY_RANK = {
	Common = 1,
	Rare = 2,
	Epic = 3,
	Legendary = 4,
	Mythical = 5,
	Secret = 6,
} :: { [string]: number }

local function coatOf(instance: any): string
	local variant = instance.variant
	return if variant == "gold" or variant == "rainbow" then variant else "base"
end
FusionLogic.coatOf = coatOf

-- A cat that can go in: owned, not locked, not working and not busy (spa, Mystic Pool choice, trade). Returns why
-- not, for the confirm card's swap strip.
function FusionLogic.blocker(instance: any, uid: string, busy: { [string]: boolean }?): string?
	if instance.locked == true then
		return "Locked"
	end
	-- #4605: a working copy may go in (it leaves its spot; FusionLogic.working tags it)
	if busy and busy[uid] then
		return "Busy"
	end
	return nil
end

-- #4605: whether a copy is working now, for the picker's "Working" tag and the confirm card's line.
function FusionLogic.working(instance: any): boolean
	return type(instance) == "table" and instance.spotId ~= nil
end

export type Copy = {
	uid: string,
	level: number,
	charm: number,
	name: string?,
	trait: string?, -- a trait id
	instance: any,
}

export type Group = {
	key: string, -- "mochi:gold"
	catId: string,
	name: string,
	rarity: string,
	coat: string, -- "base" or "gold"
	next: string, -- "gold" or "rainbow"
	free: { Copy }, -- weakest first (level, then charm, then uid)
	total: number, -- every copy in this coat, the busy ones too
}

local function weakerFirst(a: Copy, b: Copy): boolean
	if a.level ~= b.level then
		return a.level < b.level
	end
	-- #4588: then the least XP, as the server's Fusion.defaultPick
	local xa, xb = a.instance and a.instance.xp or 0, b.instance and b.instance.xp or 0
	if xa ~= xb then
		return xa < xb
	end
	if a.charm ~= b.charm then
		return a.charm < b.charm
	end
	return a.uid < b.uid
end

local function better(a: Group, b: Group): boolean
	if a.next ~= b.next then
		return a.next == "rainbow"
	end
	local ra, rb = RARITY_RANK[a.rarity] or 0, RARITY_RANK[b.rarity] or 0
	if ra ~= rb then
		return ra > rb
	end
	if a.name ~= b.name then
		return a.name < b.name
	end
	return a.key < b.key
end

-- `ready`: the cats and coats with five or more free copies, best result first (rainbow, then rarity, then name).
-- `almost`: up to ALMOST_SHOWN more with ALMOST_FROM to four free copies, closest first.
function FusionLogic.groups(
	cats: { [string]: any }?,
	busy: { [string]: boolean }?
): ({ Group }, { Group })
	local byKey: { [string]: Group } = {}
	local all: { [string]: any } = cats or {} -- one type, for the CI luau-lsp
	for uid, instance in all do
		local coat = coatOf(instance)
		local nextCoat = FusionLogic.NEXT[coat]
		local def = Catalog.getCat(instance.catId)
		if nextCoat == nil or def == nil then
			continue
		end
		local key = instance.catId .. ":" .. coat
		local group = byKey[key]
		if group == nil then
			group = {
				key = key,
				catId = instance.catId,
				name = def.name,
				rarity = def.rarity,
				coat = coat,
				next = nextCoat,
				free = {},
				total = 0,
			}
			byKey[key] = group
		end
		group.total += 1
		if FusionLogic.blocker(instance, uid, busy) == nil then
			table.insert(group.free, {
				uid = uid,
				level = CatStats.level(instance),
				charm = CatStats.charm(instance),
				name = instance.name,
				trait = if type(instance.trait) == "table" then instance.trait.id else nil,
				instance = instance,
			})
		end
	end
	local ready: { Group } = {}
	local almost: { Group } = {}
	for _, group in byKey do
		table.sort(group.free, weakerFirst)
		if #group.free >= FusionLogic.COPIES then
			table.insert(ready, group)
		elseif #group.free >= FusionLogic.ALMOST_FROM then
			table.insert(almost, group)
		end
	end
	table.sort(ready, better)
	table.sort(almost, function(a: Group, b: Group): boolean
		if #a.free ~= #b.free then
			return #a.free > #b.free
		end
		return better(a, b)
	end)
	while #almost > FusionLogic.ALMOST_SHOWN do
		table.remove(almost)
	end
	return ready, almost
end

-- #4588 (Derek 2026-11-15: "make it so it picks the 5 lowest level copies"): the five weakest copies (first in
-- `free`), so a fusion spends the lowest levels unless the player ticks others.
function FusionLogic.defaultPick(group: Group): { string }
	local free = group.free
	if #free < FusionLogic.COPIES then
		return {}
	end
	local out = {}
	for index = 1, FusionLogic.COPIES do
		table.insert(out, free[index].uid)
	end
	return out
end

export type TraitChoice = { uid: string, id: string, name: string, rarity: string, rank: number }

export type Result = {
	level: number,
	name: string?, -- the kept copy's own name, nil for the catalog name
	traits: { TraitChoice }, -- rarest first; the first is the default
}

function FusionLogic.result(group: Group, picked: { string }): Result
	local set: { [string]: boolean } = {}
	for _, uid in picked do
		set[uid] = true
	end
	local best: Copy? = nil
	local traits: { TraitChoice } = {}
	for _, copy in group.free do
		if not set[copy.uid] then
			continue
		end
		if best == nil or not weakerFirst(copy, best) then
			best = copy
		end
		local def: any = if copy.trait then Traits.get(copy.trait) else nil
		if def ~= nil then
			table.insert(traits, {
				uid = copy.uid,
				id = copy.trait :: string,
				name = def.name,
				rarity = if def.rarity then def.rarity.name else "",
				rank = Traits.rank({ id = copy.trait }),
			})
		end
	end
	table.sort(traits, function(a: TraitChoice, b: TraitChoice): boolean
		if a.rank ~= b.rank then
			return a.rank > b.rank
		end
		return a.uid < b.uid
	end)
	return {
		level = if best then best.level else 1,
		name = if best then best.name else nil,
		traits = traits,
	}
end

-- "6:42", "1:02:05"
function FusionLogic.clock(seconds: number): string
	local whole = math.max(math.ceil(seconds), 0)
	local hours = whole // 3600
	local minutes = (whole % 3600) // 60
	local secs = whole % 60
	if hours > 0 then
		return ("%d:%02d:%02d"):format(hours, minutes, secs)
	end
	return ("%d:%02d"):format(minutes, secs)
end

-- "10 min", "1 h", "45 min" (the confirm card's time line, after Elder Lore)
function FusionLogic.duration(seconds: number): string
	-- #4556 (Derek 2026-11-15: "make the dome take no time and be instant"): a fusion with no wait says so
	if seconds <= 0 then
		return "Instant"
	end
	local minutes = math.max(math.ceil(seconds / 60), 1)
	if minutes >= 60 and minutes % 60 == 0 then
		return ("%d h"):format(minutes // 60)
	elseif minutes > 60 then
		return ("%d h %d min"):format(minutes // 60, minutes % 60)
	end
	return ("%d min"):format(minutes)
end

-- #4590: the server's 0 means instant (Config, #4556), so only a missing value falls back to the old times
function FusionLogic.seconds(view: any, coat: string): number
	local value = if view ~= nil
		then (if coat == "rainbow" then view.rainbowSeconds else view.goldSeconds)
		else nil
	if type(value) == "number" and value >= 0 then
		return value
	end
	return if coat == "rainbow" then 3600 else 600
end

local function catName(catId: string, own: string?): string
	if type(own) == "string" and own ~= "" then
		return own
	end
	local def = Catalog.getCat(catId)
	return if def then def.name else catId
end

export type Dome = {
	state: string, -- "free", "running" or "ready"
	title: string,
	line: string,
	catId: string?,
	coat: string?,
	share: number, -- 0 to 1, the timer's bar
}

function FusionLogic.dome(view: any, now: number): Dome
	local running = if view ~= nil then view.running else nil
	if type(running) ~= "table" then
		return {
			state = "free",
			title = "The dome is free",
			line = "Pick a cat below to fuse",
			share = 0,
		}
	end
	local coatName = FusionLogic.COAT_NAMES[running.coat] or "Gold"
	local name = coatName .. " " .. catName(running.catId, running.name)
	local left = (running.doneAt or now) - now
	if view.ready == true or left <= 0 then
		return {
			state = "ready",
			title = name .. " is ready",
			line = ("Lv %d · tap Collect"):format(running.level or 1),
			catId = running.catId,
			coat = running.coat,
			share = 1,
		}
	end
	local total = FusionLogic.seconds(view, running.coat)
	return {
		state = "running",
		title = name .. " · " .. FusionLogic.clock(left),
		line = "Fusing in the dome",
		catId = running.catId,
		coat = running.coat,
		share = math.clamp(1 - left / math.max(total, 1), 0, 1),
	}
end

function FusionLogic.fuseText(group: Group, armed: boolean): string
	local coat = FusionLogic.COAT_NAMES[group.next] or "Gold"
	if armed then
		return ("Tap again: %d %s become 1 %s %s"):format(
			FusionLogic.COPIES,
			group.name,
			coat,
			group.name
		)
	end
	return ("Fuse %d → 1 %s"):format(FusionLogic.COPIES, coat)
end

-- "Mochi ×7", "Gold Mochi ×5"
function FusionLogic.countText(group: Group): string
	local prefix = if group.coat == "base" then "" else (FusionLogic.COAT_NAMES[group.coat] .. " ")
	return ("%s%s ×%d"):format(prefix, group.name, #group.free)
end

function FusionLogic.almostText(group: Group): string
	local more = FusionLogic.COPIES - #group.free
	return ("%s · %d more"):format(FusionLogic.countText(group), more)
end

-- #4589 Fuse all: the sets one tap would fuse (every set of five free copies, weakest first, at most `cap`, as the
-- server's Fusion.allSets) and a short list of them: "Mochi ×2, Gold Biscuit, +3 more".
function FusionLogic.allPlan(ready: { Group }, cap: number): (number, string)
	local sets = 0
	local parts: { string } = {}
	local more = 0
	for _, group in ready do
		local room = cap - sets
		if room <= 0 then
			break
		end
		local count = math.min(math.floor(#group.free / FusionLogic.COPIES), room)
		if count <= 0 then
			continue
		end
		sets += count
		local prefix = if group.coat == "base"
			then ""
			else (FusionLogic.COAT_NAMES[group.coat] .. " ")
		if #parts < 3 then
			table.insert(
				parts,
				prefix .. group.name .. (if count > 1 then (" ×%d"):format(count) else "")
			)
		else
			more += 1
		end
	end
	if more > 0 then
		table.insert(parts, ("+%d more"):format(more))
	end
	return sets, table.concat(parts, ", ")
end

-- The Fuse all button's words and whether it can be pressed: grey with the reason when it can't.
function FusionLogic.allButton(sets: number, domeState: string, armed: boolean): (string, boolean)
	if domeState == "running" then
		return "Dome busy", false
	end
	if sets <= 0 then
		return "Needs 5", false
	end
	if armed then
		return "Tap again", true
	end
	return "Fuse all", true
end

-- One made cat on the summary: its name ("Gold Mochi") and its level line ("Lv 12").
export type Made = { catId: string, coat: string, level: number, name: string?, newCoat: boolean }

function FusionLogic.madeText(made: Made, catName: string): (string, string)
	local coat = FusionLogic.COAT_NAMES[made.coat] or "Gold"
	return ("%s %s"):format(coat, made.name or catName), ("Lv %d"):format(made.level)
end

export type Track = {
	catId: string,
	name: string,
	found: { [string]: boolean }, -- base, gold, rainbow
	owned: { [string]: number },
	canFuse: boolean,
}

-- The Index tab: every catalogue cat with a coat track (not Secret ones still unfound), in catalogue order.
-- `collection` = { base = state.collection, gold = state.goldCollection, rainbow = state.rainbowCollection }.
function FusionLogic.coatTrack(
	cats: { [string]: any }?,
	collection: { [string]: { [string]: any }? },
	ready: { Group }?
): { Track }
	local owned: { [string]: { [string]: number } } = {}
	local all: { [string]: any } = cats or {} -- one type, for the CI luau-lsp
	for _, instance in all do
		local per = owned[instance.catId] or {}
		local coat = coatOf(instance)
		per[coat] = (per[coat] or 0) + 1
		owned[instance.catId] = per
	end
	local fusable: { [string]: boolean } = {}
	local groups: { Group } = ready or {}
	for _, group in groups do
		fusable[group.catId] = true
	end
	local out: { Track } = {}
	for _, def in Catalog.cats do
		if def.area == "spare" then
			continue
		end
		local found: { [string]: boolean } = {
			base = (collection.base or {})[def.id] ~= nil,
			gold = (collection.gold or {})[def.id] ~= nil,
			rainbow = (collection.rainbow or {})[def.id] ~= nil,
		}
		if def.area == "secret" and not found.base then
			continue
		end
		table.insert(out, {
			catId = def.id,
			name = def.name,
			found = found,
			owned = owned[def.id] or {},
			canFuse = fusable[def.id] == true,
		})
	end
	return out
end

-- #4104: the Snowy Mountain card's strip in the Cannon picker (the Observatory's way in until its dome has a prompt):
-- the dome's state and Open, which brings up the window from anywhere; the red dot while a fusion waits to be
-- collected. Nil on other cards and while the Observatory is shut (PlayerState.fusion unset: switch off or below
-- Tier 8). The shape is CampExtrasLogic.Line.
FusionLogic.AREA = "snowy"
FusionLogic.STATION = "fusion"
FusionLogic.ICON = "🔭"

function FusionLogic.cannonLine(
	view: any,
	areaId: string,
	now: number
): {
	extraId: string,
	icon: string,
	name: string,
	state: string,
	ready: boolean,
}?
	if areaId ~= FusionLogic.AREA or type(view) ~= "table" then
		return nil
	end
	local dome = FusionLogic.dome(view, now)
	return {
		extraId = FusionLogic.STATION,
		icon = FusionLogic.ICON,
		name = "Observatory",
		state = dome.title,
		ready = dome.state == "ready",
	}
end

-- The cannon picker's line and the station's "!" (section 2).
function FusionLogic.pickerLine(view: any, readyCount: number, now: number): (string, boolean)
	local dome = FusionLogic.dome(view, now)
	if dome.state == "ready" then
		return "Observatory: " .. (string.gsub(dome.title, " is ready$", "")) .. " ready !", true
	elseif dome.state == "running" then
		local running = view.running
		local coatName = FusionLogic.COAT_NAMES[running.coat] or "Gold"
		local left = math.max(math.ceil(((running.doneAt or now) - now) / 60), 1)
		return ("Observatory: %s %s %d min"):format(
			coatName,
			catName(running.catId, running.name),
			left
		),
			false
	elseif readyCount > 0 then
		return ("Observatory: %d can fuse !"):format(readyCount), true
	end
	return "Observatory: free", false
end

return FusionLogic
