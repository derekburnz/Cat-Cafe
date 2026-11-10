--!strict
-- #2651 part 4 (late-stations.md): the two late-game camp stations. Pure rules for the server (LateStationService)
-- and the client (the cards and the cannon picker's lines):
--   Oasis Spa (Desert camp, Tier 6): a cat soaking earns one level per Config.SpaSeconds of real time (offline too),
--     up to Config.SpaMaxHours levels and never past CatMaxLevel (#2904), its XP toward the next level kept. One slot is free; slots 2 and 3 are bought once, in order, for
--     Config.SpaSlotPrices golden fish. A cat with a level earned waits in its slot until collected, so it never lands
--     mid-trade; collect takes every slot with one. Taking one out before its first level gives nothing. A spa cat earns nothing and no XP (CatStats.atSpa guards the rest).
--   Relic Museum (Ruins camp, Tier 7): one exhibit per area cat (the Index's cats: no shop, starter, Bellhop or spare
--     cat). Giving a copy fills its exhibit for good; the copy leaves the save like a sale that pays nothing, and the
--     Index keeps it as found. A copy can be given only when another copy of that cat stays, it is unlocked and it is
--     not at the spa. Each finished room (an area's every exhibit) adds Config.MuseumRoomTipBonus to the tips-forever
--     total (IndexRewards.totals).
-- Nothing here is sold, sped up or refilled for Robux, and nothing changes catch, luck, gold or rainbow odds.
-- Requires no Economy or IndexRewards (IndexRewards reads the museum's bonus from here).

local CatStats = require(script.Parent.CatStats)
local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local LateStations = {}

LateStations.SPA = "spa"
LateStations.MUSEUM = "museum"
LateStations.SPA_AREA = "desert"
LateStations.MUSEUM_AREA = "ruins"
LateStations.TAG = "LateStation" -- the placed models, with attributes StationId and Area
LateStations.PROMPT = "LateStationPrompt" -- each model's ProximityPrompt, at its PromptAnchor

-- The stations as WorldBuilder places them and the cards name them. Model-Agent's art (late-stations.md sections 1
-- and 2); a plain block stands in until it is in the AssetRegistry.
LateStations.stations = {
	{
		id = LateStations.SPA,
		area = LateStations.SPA_AREA,
		name = "Oasis Spa",
		model = "CatCafe_Camp_Desert_OasisSpa",
	},
	{
		id = LateStations.MUSEUM,
		area = LateStations.MUSEUM_AREA,
		name = "Relic Museum",
		model = "CatCafe_Camp_Ruins_RelicMuseum",
	},
}

LateStations.Messages = {
	atSpa = "This cat is at the spa",
	spaShut = "The Oasis Spa opens at Tier 6",
	museumShut = "The Relic Museum opens at Tier 7",
	comingSoon = "Coming soon",
	notOwned = "That cat isn't yours",
	slotShut = "Open this slot first",
	slotTaken = "That slot already has a cat",
	slotEmpty = "That slot is empty",
	maxLevel = "That cat is already at the top level",
	inTrade = "Finish your trade first",
	notNext = "Open the slots in order",
	allOpen = "Every slot is open",
	fish = "Not enough golden fish",
	nothingReady = "No cat is ready yet",
	noExhibit = "That cat has no exhibit",
	filled = "That exhibit is already filled",
	locked = "Unlock this cat first",
	lastCopy = "Keep one: you need another copy of this cat to give one",
}

-- The Museum's rooms in Catalog.areas order, each its area's exhibits (catIds in Catalog.cats order).
export type Room = { area: string, name: string, cats: { string } }
LateStations.rooms = {} :: { Room }
LateStations.exhibitArea = {} :: { [string]: string } -- catId -> its room's area
do
	local byArea: { [string]: Room } = {}
	for _, area in Catalog.areas do
		local room: Room = { area = area.id, name = area.name, cats = {} }
		byArea[area.id] = room
		table.insert(LateStations.rooms, room)
	end
	for _, def in Catalog.cats do
		local room = byArea[def.area]
		if room ~= nil and def.exclusive ~= true then
			table.insert(room.cats, def.id)
			LateStations.exhibitArea[def.id] = def.area
		end
	end
end

-- #2908 (Derek2 2026-11-10: "let you see the exhibits being filled"): the Museum model's attachment where exhibit
-- `catId` stands, ExhibitSpot_<area>_<n> with n its place in its room (Model-Agent's #2918: 10 a room, spot 1 at the
-- museum end), or nil for a cat with no exhibit.
function LateStations.exhibitSpot(catId: string): string?
	local area = LateStations.exhibitArea[catId]
	if area == nil then
		return nil
	end
	for _, room in LateStations.rooms do
		if room.area == area then
			local index = table.find(room.cats, catId)
			return if index ~= nil then string.format("ExhibitSpot_%s_%d", area, index) else nil
		end
	end
	return nil
end

local function exhibitTotal(): number
	local total = 0
	for _ in LateStations.exhibitArea do
		total += 1
	end
	return total
end
LateStations.EXHIBITS = exhibitTotal()

-- The tier that opens a station (its area's), 0 for an unknown id.
function LateStations.tierOf(stationId: string): number
	local areaId = if stationId == LateStations.SPA
		then LateStations.SPA_AREA
		elseif stationId == LateStations.MUSEUM then LateStations.MUSEUM_AREA
		else nil
	local area = if areaId ~= nil then Catalog.getArea(areaId) else nil
	return if area ~= nil then area.tier else 0
end

function LateStations.isOpen(stationId: string, tier: number): boolean
	local need = LateStations.tierOf(stationId)
	return need > 0 and tier >= need
end

-- Saves ----------------------------------------------------------------------------------------------------

function LateStations.freshSpa(): Types.SpaSave
	return { slots = 1, soaking = {} }
end

function LateStations.freshMuseum(): Types.MuseumSave
	return {}
end

local function whole(x: unknown): number?
	if type(x) == "number" and x == x and math.abs(x) < 2 ^ 40 then
		return math.floor(x)
	end
	return nil
end

-- A saved spa made whole at `now`: 1 to #SpaSlotPrices slots, each soaking entry in an open slot holding a cat the
-- save owns (each cat in one slot at most) and a start no later than now. Anything else is dropped; the cat stays in
-- the cat room.
function LateStations.sanitizeSpa(
	raw: unknown,
	cats: { [string]: Types.CatInstance },
	now: number
): Types.SpaSave
	local spa = LateStations.freshSpa()
	if type(raw) ~= "table" then
		return spa
	end
	local value = raw :: any
	spa.slots = math.clamp(whole(value.slots) or 1, 1, #Config.SpaSlotPrices)
	if type(value.soaking) ~= "table" then
		return spa
	end
	local seen: { [string]: boolean } = {}
	for slot = 1, spa.slots do
		local soak = value.soaking[tostring(slot)]
		if type(soak) ~= "table" then
			continue
		end
		local uid, at = soak.uid, whole(soak.at)
		if type(uid) == "string" and cats[uid] ~= nil and not seen[uid] and at ~= nil then
			seen[uid] = true
			spa.soaking[tostring(slot)] = { uid = uid, at = math.min(at, now) }
		end
	end
	return spa
end

local COATS = { base = true, gold = true, rainbow = true }

-- A saved museum with known exhibits only, each with a known coat.
function LateStations.sanitizeMuseum(raw: unknown): Types.MuseumSave
	local museum = LateStations.freshMuseum()
	if type(raw) ~= "table" then
		return museum
	end
	for catId, coat in raw :: any do
		if
			type(catId) == "string"
			and LateStations.exhibitArea[catId] ~= nil
			and type(coat) == "string"
			and COATS[coat]
		then
			museum[catId] = coat
		end
	end
	return museum
end

-- The spa and museum of a profile, fresh for one without them (a test fixture).
local function spaOf(profile: Types.PlayerProfile): Types.SpaSave
	local spa = (profile :: any).spa
	if type(spa) ~= "table" then
		spa = LateStations.freshSpa();
		(profile :: any).spa = spa
	end
	return spa
end

local function museumOf(profile: Types.PlayerProfile): Types.MuseumSave
	local museum = (profile :: any).museum
	if type(museum) ~= "table" then
		museum = LateStations.freshMuseum();
		(profile :: any).museum = museum
	end
	return museum
end

-- Oasis Spa --------------------------------------------------------------------------------------------------

-- When a cat that went in at `at` has its first level (and can be collected).
function LateStations.doneAt(at: number): number
	return at + Config.SpaSeconds
end

-- When a cat that went in at `at` stops earning: SpaMaxHours levels in (#2904).
function LateStations.fullAt(at: number): number
	return at + Config.SpaSeconds * Config.SpaMaxHours
end

-- #2904: the levels a cat at `level` that went in at `at` has earned by `now`: one per full SpaSeconds, at most
-- SpaMaxHours, never past CatMaxLevel, and never below 0 (a clock that went back).
function LateStations.levelsEarned(level: number, at: number, now: number): number
	local hours = math.floor((now - at) / Config.SpaSeconds)
	return math.clamp(
		math.min(hours, Config.SpaMaxHours, Config.CatMaxLevel - level),
		0,
		Config.SpaMaxHours
	)
end

-- The slot that `uid` soaks in, or nil.
function LateStations.slotOf(profile: Types.PlayerProfile, uid: string): number?
	for key, soak in spaOf(profile).soaking do
		if soak.uid == uid then
			return tonumber(key)
		end
	end
	return nil
end

-- The uids at the spa, as a set (the Collector's pick skips them).
function LateStations.spaUids(profile: Types.PlayerProfile): { [string]: boolean }
	local uids: { [string]: boolean } = {}
	for _, soak in spaOf(profile).soaking do
		uids[soak.uid] = true
	end
	return uids
end

-- Why the cat `uid` cannot go into spa slot `slot` now, or nil. `trading` is whether the player has an open trade.
function LateStations.putBlocker(
	profile: Types.PlayerProfile,
	tier: number,
	slot: number,
	uid: string,
	trading: boolean
): string?
	if not LateStations.isOpen(LateStations.SPA, tier) then
		return LateStations.Messages.spaShut
	end
	local spa = spaOf(profile)
	local instance = profile.cats[uid]
	if instance == nil then
		return LateStations.Messages.notOwned
	end
	if slot < 1 or slot > spa.slots then
		return LateStations.Messages.slotShut
	end
	if spa.soaking[tostring(slot)] ~= nil then
		return LateStations.Messages.slotTaken
	end
	if LateStations.slotOf(profile, uid) ~= nil then
		return LateStations.Messages.atSpa
	end
	if CatStats.level(instance) >= Config.CatMaxLevel then
		return LateStations.Messages.maxLevel
	end
	if trading then
		return LateStations.Messages.inTrade
	end
	return nil
end

-- Puts the cat in (the caller checked putBlocker): it leaves its role and soaks from `now`.
function LateStations.put(profile: Types.PlayerProfile, slot: number, uid: string, now: number)
	local instance = profile.cats[uid]
	if instance ~= nil then
		instance.spotId = nil
	end
	spaOf(profile).soaking[tostring(slot)] = { uid = uid, at = now }
end

-- Takes the cat out of `slot` with no level gained; returns its uid, or nil for an empty slot.
function LateStations.takeOut(profile: Types.PlayerProfile, slot: number): string?
	local spa = spaOf(profile)
	local soak = spa.soaking[tostring(slot)]
	if soak == nil then
		return nil
	end
	spa.soaking[tostring(slot)] = nil
	return soak.uid
end

-- `levels` (default 1) up for a soaked cat, never past CatMaxLevel, its XP toward the next level kept (none at the
-- top). Returns the level before and after.
function LateStations.levelUp(instance: Types.CatInstance, levels: number?): (number, number)
	local before = CatStats.level(instance)
	local after = math.min(before + math.max(levels or 1, 0), Config.CatMaxLevel)
	instance.level = after
	instance.xp = if after >= Config.CatMaxLevel then 0 else CatStats.xp(instance)
	instance.charm = CatStats.charm(instance)
	return before, after
end

export type Relaxed = { uid: string, catId: string, from: number, to: number }

-- Collects every slot at `now` that is past its first level: each cat gains the levels it earned (levelsEarned) and
-- goes back to the cat room. Such a slot whose cat is gone (sold before a fix, say) just empties. Returns what each cat gained, in slot order.
function LateStations.collect(profile: Types.PlayerProfile, now: number): { Relaxed }
	local spa = spaOf(profile)
	local relaxed: { Relaxed } = {}
	for slot = 1, #Config.SpaSlotPrices do
		local key = tostring(slot)
		local soak = spa.soaking[key]
		if soak == nil or now < LateStations.doneAt(soak.at) then
			continue
		end
		spa.soaking[key] = nil
		local instance = profile.cats[soak.uid]
		if instance ~= nil then
			local from, to = LateStations.levelUp(
				instance,
				LateStations.levelsEarned(CatStats.level(instance), soak.at, now)
			)
			table.insert(relaxed, { uid = soak.uid, catId = instance.catId, from = from, to = to })
		end
	end
	return relaxed
end

-- How many slots are finished at `now`.
function LateStations.readyCount(profile: Types.PlayerProfile, now: number): number
	local ready = 0
	for _, soak in spaOf(profile).soaking do
		if now >= LateStations.doneAt(soak.at) then
			ready += 1
		end
	end
	return ready
end

-- The price of the next slot to open, or nil when all are open.
function LateStations.nextSlotPrice(profile: Types.PlayerProfile): number?
	return Config.SpaSlotPrices[spaOf(profile).slots + 1]
end

-- Why slot `slot` cannot be bought now, or nil (then its price is nextSlotPrice). `fish` is the balance.
function LateStations.buyBlocker(
	profile: Types.PlayerProfile,
	tier: number,
	slot: number,
	fish: number
): string?
	if not LateStations.isOpen(LateStations.SPA, tier) then
		return LateStations.Messages.spaShut
	end
	local spa = spaOf(profile)
	local price = LateStations.nextSlotPrice(profile)
	if price == nil then
		return LateStations.Messages.allOpen
	end
	if slot ~= spa.slots + 1 then
		return LateStations.Messages.notNext
	end
	if fish < price then
		return LateStations.Messages.fish
	end
	return nil
end

-- Relic Museum ---------------------------------------------------------------------------------------------------

-- The copies of `catId` the player could give, weakest first (lowest level, then lowest charm, then uid): unlocked,
-- not at the spa, and only while another copy stays (any copy counts as the one kept). Empty when the cat has no
-- exhibit or it is filled.
function LateStations.donatable(profile: Types.PlayerProfile, catId: string): { Types.CatInstance }
	local out: { Types.CatInstance } = {}
	if LateStations.exhibitArea[catId] == nil or museumOf(profile)[catId] ~= nil then
		return out
	end
	local copies = 0
	for _, instance in profile.cats do
		if instance.catId == catId then
			copies += 1
			if instance.locked ~= true and not CatStats.atSpa(profile, instance.uid) then
				table.insert(out, instance)
			end
		end
	end
	if copies < 2 then
		return {}
	end
	table.sort(out, function(a: Types.CatInstance, b: Types.CatInstance): boolean
		local la, lb = CatStats.level(a), CatStats.level(b)
		if la ~= lb then
			return la < lb
		end
		local ca, cb = CatStats.charm(a), CatStats.charm(b)
		if ca ~= cb then
			return ca < cb
		end
		return a.uid < b.uid
	end)
	return out
end

-- Why the copy `uid` cannot be given now, or nil. `trading` is whether the player has an open trade.
function LateStations.donateBlocker(
	profile: Types.PlayerProfile,
	tier: number,
	uid: string,
	trading: boolean
): string?
	if not LateStations.isOpen(LateStations.MUSEUM, tier) then
		return LateStations.Messages.museumShut
	end
	local instance = profile.cats[uid]
	if instance == nil then
		return LateStations.Messages.notOwned
	end
	if LateStations.exhibitArea[instance.catId] == nil then
		return LateStations.Messages.noExhibit
	end
	if museumOf(profile)[instance.catId] ~= nil then
		return LateStations.Messages.filled
	end
	if instance.locked == true then
		return LateStations.Messages.locked
	end
	if CatStats.atSpa(profile, uid) then
		return LateStations.Messages.atSpa
	end
	if trading then
		return LateStations.Messages.inTrade
	end
	local copies = 0
	for _, other in profile.cats do
		if other.catId == instance.catId then
			copies += 1
		end
	end
	if copies < 2 then
		return LateStations.Messages.lastCopy
	end
	return nil
end

-- True when every exhibit of `room` is filled.
function LateStations.roomDone(museum: Types.MuseumSave, room: Room): boolean
	if #room.cats == 0 then
		return false
	end
	for _, catId in room.cats do
		if museum[catId] == nil then
			return false
		end
	end
	return true
end

-- The areas whose rooms are complete, in room order.
function LateStations.roomsDone(museum: Types.MuseumSave?): { string }
	local done: { string } = {}
	if museum == nil then
		return done
	end
	for _, room in LateStations.rooms do
		if LateStations.roomDone(museum, room) then
			table.insert(done, room.area)
		end
	end
	return done
end

-- The museum's tips-forever share: MuseumRoomTipBonus a finished room (IndexRewards.totals adds it).
function LateStations.museumBonus(museum: Types.MuseumSave?): number
	return #LateStations.roomsDone(museum) * Config.MuseumRoomTipBonus
end

-- Gives the copy (the caller checked donateBlocker): fills its exhibit with its coat and takes it out of the save.
-- Returns the catId and the room's area when this gift finished the room.
function LateStations.donate(profile: Types.PlayerProfile, uid: string): (string, string?)
	local instance = profile.cats[uid]
	local museum = museumOf(profile)
	local area = LateStations.exhibitArea[instance.catId]
	museum[instance.catId] = if COATS[instance.variant] then instance.variant else "base"
	profile.cats[uid] = nil
	for _, room in LateStations.rooms do
		if room.area == area and LateStations.roomDone(museum, room) then
			return instance.catId, area
		end
	end
	return instance.catId, nil
end

-- How many empty exhibits the player has a copy to give for (the "!" and the picker line).
function LateStations.canFill(profile: Types.PlayerProfile): number
	local museum = museumOf(profile)
	local spaUids = LateStations.spaUids(profile)
	local copies: { [string]: number } = {}
	local giveable: { [string]: boolean } = {}
	for _, instance in profile.cats do
		local catId = instance.catId
		if LateStations.exhibitArea[catId] == nil or museum[catId] ~= nil then
			continue
		end
		copies[catId] = (copies[catId] or 0) + 1
		if instance.locked ~= true and not spaUids[instance.uid] then
			giveable[catId] = true
		end
	end
	local count = 0
	for catId in giveable do
		if copies[catId] >= 2 then
			count += 1
		end
	end
	return count
end

-- State --------------------------------------------------------------------------------------------------------

function LateStations.view(
	profile: Types.PlayerProfile,
	tier: number,
	now: number
): Types.LateStationsState
	local spa = spaOf(profile)
	local soaking: { Types.SpaSlotView } = {}
	for slot = 1, spa.slots do
		local soak = spa.soaking[tostring(slot)]
		local instance = if soak ~= nil then profile.cats[soak.uid] else nil
		table.insert(soaking, {
			slot = slot,
			uid = if soak ~= nil then soak.uid else nil,
			catId = if instance ~= nil then instance.catId else nil,
			doneAt = if soak ~= nil then LateStations.doneAt(soak.at) else nil,
			fullAt = if soak ~= nil then LateStations.fullAt(soak.at) else nil,
			levels = if soak ~= nil and instance ~= nil
				then LateStations.levelsEarned(CatStats.level(instance), soak.at, now)
				else nil,
		})
	end
	local museum = museumOf(profile)
	local count = 0
	for _ in museum do
		count += 1
	end
	local museumOpen = LateStations.isOpen(LateStations.MUSEUM, tier)
	return {
		live = Config.LateStationsOpen,
		spa = {
			open = LateStations.isOpen(LateStations.SPA, tier),
			slots = spa.slots,
			nextPrice = LateStations.nextSlotPrice(profile),
			soaking = soaking,
			ready = LateStations.readyCount(profile, now),
		},
		museum = {
			open = museumOpen,
			filled = table.clone(museum),
			count = count,
			total = LateStations.EXHIBITS,
			canFill = if museumOpen then LateStations.canFill(profile) else 0,
			rooms = LateStations.roomsDone(museum),
			bonus = LateStations.museumBonus(museum),
		},
	}
end

-- The cannon picker's line for a station (late-stations.md sections 1 and 2).
function LateStations.pickerLine(stationId: string, state: Types.LateStationsState): string
	if stationId == LateStations.SPA then
		local busy, levels = 0, 0
		for _, slot in state.spa.soaking do
			if slot.uid ~= nil then
				busy += 1
				levels += slot.levels or 0
			end
		end
		if busy == 0 then
			return "Oasis Spa: empty"
		end
		local relaxing = busy - state.spa.ready
		local parts: { string } = {}
		if relaxing > 0 then
			table.insert(parts, string.format("%d relaxing", relaxing))
		end
		if state.spa.ready > 0 then
			-- #2904: the levels waiting, "+1 level ready !" or "+7 levels ready !"
			local word = if levels == 1 then "level" else "levels"
			table.insert(parts, string.format("+%d %s ready !", levels, word))
		end
		return "Oasis Spa: " .. table.concat(parts, " · ")
	end
	local line = string.format("Relic Museum: %d/%d", state.museum.count, state.museum.total)
	if state.museum.canFill > 0 then
		line ..= string.format(" · %d can be filled !", state.museum.canFill)
	end
	return line
end

return LateStations
