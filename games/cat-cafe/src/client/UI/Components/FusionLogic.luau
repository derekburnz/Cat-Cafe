--!strict
-- #4104 Fusion Observatory window (Design-Agent/notes/fusion-observatory.md section 2): what the window shows from
-- PlayerState.fusion and the player's cats. Five copies of one cat in one coat make one in the next coat. Pure apart
-- from the shared modules it reads (Catalog, CatStats, Traits), so the specs check it.
--   groups(cats, busy) -> (ready, almost)        the cats and coats with 5+ free copies, and those at 3 or 4
--   defaultPick(group) -> { string }             the best level copy and the four weakest others
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
	if instance.spotId ~= nil then
		return "Working"
	end
	if busy and busy[uid] then
		return "Busy"
	end
	return nil
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
	for uid, instance in cats or {} do
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

-- The best level copy (the strongest, last in `free`) and the four weakest others, so the new cat keeps the level the
-- player worked for and the weakest copies are the ones spent.
function FusionLogic.defaultPick(group: Group): { string }
	local free = group.free
	if #free < FusionLogic.COPIES then
		return {}
	end
	local out = { free[#free].uid }
	for index = 1, FusionLogic.COPIES - 1 do
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
	local minutes = math.max(math.ceil(seconds / 60), 1)
	if minutes >= 60 and minutes % 60 == 0 then
		return ("%d h"):format(minutes // 60)
	elseif minutes > 60 then
		return ("%d h %d min"):format(minutes // 60, minutes % 60)
	end
	return ("%d min"):format(minutes)
end

function FusionLogic.seconds(view: any, coat: string): number
	local value = if view ~= nil
		then (if coat == "rainbow" then view.rainbowSeconds else view.goldSeconds)
		else nil
	if type(value) == "number" and value > 0 then
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
	for _, instance in cats or {} do
		local per = owned[instance.catId] or {}
		local coat = coatOf(instance)
		per[coat] = (per[coat] or 0) + 1
		owned[instance.catId] = per
	end
	local fusable: { [string]: boolean } = {}
	for _, group in ready or {} do
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
