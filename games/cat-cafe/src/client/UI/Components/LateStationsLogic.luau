--!strict
-- The late stations on the UI (#2651 part 4, late-stations.md sections 1 and 2): the Oasis Spa (Desert camp, Tier 6)
-- and the Relic Museum (Ruins camp, Tier 7). Pure, so the cloud spec runner checks it. The rules are the server's
-- (shared/LateStations); this shapes LateStationsState and the player's cats for the cards, the Cat Cannon picker's
-- line and the stations' bubbles:
--   spaRows(spa, cats, now)            the Spa card's three slots: a cat soaking (its levels so far and what is next),
--                                      an empty slot, the next slot to buy or a slot after it
--   spaReady(spa, cats, now)           the levels waiting for Collect, summed over the finished slots
--   spaCandidates(cats, spa)           the cats that can go in: below the top level and not soaking, best first
--   SPA_FILTERS, spaMatch(cat, query, filter)  the Spa list's search (#3136): the words typed are found in the cat's
--                                      own name or its breed, any case, and "Resting" / "Working" keep the cats
--                                      off or on a cafe spot
--   spaTitle(cat), spaSubtitle(cat)    a list row's two lines: the cat's own name (else its coat and breed), then
--                                      "Lv 12 · ★★★ · Working" (and the breed after a cat with its own name)
--   spaKey(list)                       a word that changes when the list's rows would, so the list is rebuilt only then
--   takeOutText(name)                  "Take Mochi out now? It won't level up."
--   rooms(museum, cats, spa)           the Museum card's rooms in Catalog.areas order, each exhibit with its coat
--                                      once given, how many copies the player has and which can be given
--   donatable(cats, catId, museum, spa) the copies of a cat that can be given, weakest first (as the server's rule)
--   giveWarning(variant)               "This is a gold cat. Give it anyway?" for a gold or rainbow copy, else nil
--   pickerLine(state, areaId)          the Cat Cannon card's strip for the Desert or the Ruins, as CampExtrasLogic.Line
--   bubble(state, stationId)           the bubble over a station (ReadyBang): its picker line
--   bangShows(state, stationId)        its red "!": a spa cat to collect, or an exhibit the player can fill
--   bonusText(bonus)                   "+10% tips forever"

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog")) :: any
local Config = require(Shared:WaitForChild("Config")) :: any
local LateStations = require(Shared:WaitForChild("LateStations")) :: any
local SharedTypes = require(Shared:WaitForChild("Types"))

local LateStationsLogic = {}

LateStationsLogic.SPA = "spa"
LateStationsLogic.MUSEUM = "museum"
LateStationsLogic.ICONS = { spa = "♨️", museum = "🏛️" } :: { [string]: string }
LateStationsLogic.NAMES = { spa = "Oasis Spa", museum = "Relic Museum" } :: { [string]: string }
LateStationsLogic.AREAS = { spa = "desert", museum = "ruins" } :: { [string]: string }
-- #3136: every cat that can go in is listed (it was the best 60): the list has a search box, builds its rows once
-- and loads faces only near the visible rows, so a big collection costs little
LateStationsLogic.CANDIDATES_MAX = math.huge
LateStationsLogic.SPA_FILTERS = { "All", "Resting", "Working" }

export type Line = {
	extraId: string,
	icon: string,
	name: string,
	state: string,
	ready: boolean,
}

export type SlotKind = "cat" | "empty" | "buy" | "shut"

export type SlotRow = {
	slot: number,
	kind: SlotKind,
	uid: string?,
	catId: string?,
	level: number?, -- the cat's level now (before what it earned here)
	levels: number, -- levels earned so far
	ready: boolean, -- past its first level: Collect takes it
	full: boolean, -- earning no more (24 hours in, or the top level reached)
	line: string, -- "First level in 42m", "+3 levels · next in 12m", "+24 levels · full", "Empty", "100 fish"
	price: number?, -- "buy" and "shut": the slot's golden fish price
}

export type Exhibit = {
	catId: string,
	name: string,
	rarity: string,
	coat: string?, -- "base", "gold" or "rainbow" once given
	have: number, -- copies owned
	give: { SharedTypes.CatView }, -- the copies that can be given, weakest first
	line: string, -- "Given", "You have 3", "You have 1"
}

export type RoomRow = {
	area: string,
	name: string,
	exhibits: { Exhibit },
	filled: number,
	done: boolean,
	canFill: number, -- exhibits here the player can fill now
}

local function format(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local hours = seconds // 3600
	local minutes = (seconds % 3600) // 60
	if hours > 0 then
		return string.format("%dh %dm", hours, minutes)
	elseif minutes > 0 then
		return string.format("%dm", minutes)
	end
	return string.format("%ds", seconds)
end

local function plural(n: number, word: string): string
	return string.format("%d %s%s", n, word, if n == 1 then "" else "s")
end

local function catName(catId: string?): string
	local def = if catId ~= nil then Catalog.getCat(catId) else nil
	return if def ~= nil then def.name else (catId or "Cat")
end
LateStationsLogic.catName = catName

local function spaUids(spa: SharedTypes.SpaView?): { [string]: boolean }
	local uids: { [string]: boolean } = {}
	if spa ~= nil and type(spa.soaking) == "table" then
		for _, slot in spa.soaking do
			if slot.uid ~= nil then
				uids[slot.uid] = true
			end
		end
	end
	return uids
end
LateStationsLogic.spaUids = spaUids

-- One soaking slot at `now`: the levels earned so far (worked out here, so the card moves on between states) and the
-- line under the cat.
local function soakRow(
	view: SharedTypes.SpaSlotView,
	cats: { [string]: SharedTypes.CatView }?,
	now: number
): SlotRow
	local cat = if cats ~= nil and view.uid ~= nil then cats[view.uid] else nil
	local level = if cat ~= nil then cat.level else nil
	local doneAt = view.doneAt or now
	local at = doneAt - Config.SpaSeconds
	local levels = if level ~= nil
		then LateStations.levelsEarned(level, at, now)
		else (view.levels or 0)
	local fullAt = view.fullAt or (at + Config.SpaSeconds * Config.SpaMaxHours)
	local top = level ~= nil and level + levels >= Config.CatMaxLevel
	local full = now >= fullAt or levels >= Config.SpaMaxHours or top
	local line
	if levels <= 0 then
		line = "First level in " .. format(doneAt - now)
	elseif full then
		line = string.format("+%s · full", plural(levels, "level"))
	else
		local nextAt = at + (math.floor((now - at) / Config.SpaSeconds) + 1) * Config.SpaSeconds
		line = string.format("+%s · next in %s", plural(levels, "level"), format(nextAt - now))
	end
	return {
		slot = view.slot,
		kind = "cat" :: SlotKind,
		uid = view.uid,
		catId = view.catId or (if cat ~= nil then cat.catId else nil),
		level = level,
		levels = levels,
		ready = levels > 0,
		full = full,
		line = line,
	}
end

function LateStationsLogic.spaRows(
	spa: SharedTypes.SpaView?,
	cats: { [string]: SharedTypes.CatView }?,
	now: number
): { SlotRow }
	local rows: { SlotRow } = {}
	local open = if spa ~= nil then spa.slots else 1
	local bySlot: { [number]: SharedTypes.SpaSlotView } = {}
	if spa ~= nil and type(spa.soaking) == "table" then
		for _, view in spa.soaking do
			bySlot[view.slot] = view
		end
	end
	for slot = 1, #Config.SpaSlotPrices do
		local view = bySlot[slot]
		if slot <= open and view ~= nil and view.uid ~= nil then
			table.insert(rows, soakRow(view, cats, now))
		elseif slot <= open then
			table.insert(rows, {
				slot = slot,
				kind = "empty" :: SlotKind,
				levels = 0,
				ready = false,
				full = false,
				line = "Empty",
			})
		else
			local price = Config.SpaSlotPrices[slot]
			table.insert(rows, {
				slot = slot,
				kind = (if slot == open + 1 then "buy" else "shut") :: SlotKind,
				levels = 0,
				ready = false,
				full = false,
				price = price,
				line = if slot == open + 1
					then string.format("Open for %d fish", price)
					else string.format("Open slot %d first", slot - 1),
			})
		end
	end
	return rows
end

-- The levels Collect would give now, and how many cats.
function LateStationsLogic.spaReady(
	spa: SharedTypes.SpaView?,
	cats: { [string]: SharedTypes.CatView }?,
	now: number
): (number, number)
	local levels, count = 0, 0
	for _, row in LateStationsLogic.spaRows(spa, cats, now) do
		if row.kind == "cat" and row.ready then
			levels += row.levels
			count += 1
		end
	end
	return levels, count
end

function LateStationsLogic.collectText(levels: number): string
	return if levels > 0 then "Collect +" .. plural(levels, "level") else "Collect"
end

-- The cats that can go in (late-stations.md section 1: any owned cat below the top level, working or resting, locked
-- or not), not one already soaking. Highest level first, then the best rate, at most CANDIDATES_MAX.
function LateStationsLogic.spaCandidates(
	cats: { [string]: SharedTypes.CatView }?,
	spa: SharedTypes.SpaView?
): { SharedTypes.CatView }
	local out: { SharedTypes.CatView } = {}
	if cats == nil then
		return out
	end
	local soaking = spaUids(spa)
	for uid, cat in cats do
		if not soaking[uid] and cat.level < Config.CatMaxLevel then
			table.insert(out, cat)
		end
	end
	table.sort(out, function(a: SharedTypes.CatView, b: SharedTypes.CatView): boolean
		if a.level ~= b.level then
			return a.level > b.level
		end
		if (a.rating or 0) ~= (b.rating or 0) then
			return (a.rating or 0) > (b.rating or 0)
		end
		return a.uid < b.uid
	end)
	while #out > LateStationsLogic.CANDIDATES_MAX do
		table.remove(out)
	end
	return out
end

local function coatWord(variant: string?): string
	return if variant == "rainbow" then "Rainbow " elseif variant == "gold" then "Gold " else ""
end

function LateStationsLogic.spaTitle(cat: SharedTypes.CatView): string
	if type(cat.name) == "string" and cat.name ~= "" then
		return cat.name :: string
	end
	return coatWord(cat.variant) .. catName(cat.catId)
end

function LateStationsLogic.spaSubtitle(cat: SharedTypes.CatView): string
	local line = string.format("Lv %d · %s", cat.level, string.rep("★", cat.stars or 1))
	if cat.spotId ~= nil then
		line ..= " · Working"
	end
	if type(cat.name) == "string" and cat.name ~= "" then
		line ..= " · " .. coatWord(cat.variant) .. catName(cat.catId)
	end
	return line
end

function LateStationsLogic.spaMatch(
	cat: SharedTypes.CatView,
	query: string?,
	filter: string?
): boolean
	if filter == "Resting" and cat.spotId ~= nil then
		return false
	end
	if filter == "Working" and cat.spotId == nil then
		return false
	end
	local words = string.lower(string.match(query or "", "^%s*(.-)%s*$") or "")
	if words == "" then
		return true
	end
	local hay = string.lower((cat.name or "") .. " " .. coatWord(cat.variant) .. catName(cat.catId))
	return string.find(hay, words, 1, true) ~= nil
end

function LateStationsLogic.spaKey(list: { SharedTypes.CatView }): string
	local parts = table.create(#list)
	for index, cat in list do
		parts[index] = string.format(
			"%s:%d:%d:%s:%s:%s",
			cat.uid,
			cat.level,
			cat.stars or 1,
			cat.variant or "",
			if cat.spotId ~= nil then "w" else "r",
			cat.name or ""
		)
	end
	return table.concat(parts, "|")
end

function LateStationsLogic.takeOutText(name: string): string
	return string.format("Take %s out now? It won't level up.", name)
end

-- Relic Museum ---------------------------------------------------------------------------------------------------

-- The copies of `catId` that can be given, as shared/LateStations.donatable: unlocked, not at the spa, and only while
-- another copy stays; lowest level, then lowest charm, first. Empty once the exhibit is filled.
function LateStationsLogic.donatable(
	cats: { [string]: SharedTypes.CatView }?,
	catId: string,
	filled: { [string]: string }?,
	spa: SharedTypes.SpaView?
): { SharedTypes.CatView }
	local out: { SharedTypes.CatView } = {}
	if
		cats == nil
		or LateStations.exhibitArea[catId] == nil
		or (filled ~= nil and filled[catId] ~= nil)
	then
		return out
	end
	local soaking = spaUids(spa)
	local copies = 0
	for uid, cat in cats do
		if cat.catId == catId then
			copies += 1
			if cat.locked ~= true and not soaking[uid] then
				table.insert(out, cat)
			end
		end
	end
	if copies < 2 then
		return {}
	end
	table.sort(out, function(a: SharedTypes.CatView, b: SharedTypes.CatView): boolean
		if a.level ~= b.level then
			return a.level < b.level
		end
		if a.charm ~= b.charm then
			return a.charm < b.charm
		end
		return a.uid < b.uid
	end)
	return out
end

function LateStationsLogic.rooms(
	museum: SharedTypes.MuseumView?,
	cats: { [string]: SharedTypes.CatView }?,
	spa: SharedTypes.SpaView?
): { RoomRow }
	local filled: { [string]: string } = if museum ~= nil
			and type(museum.filled) == "table"
		then museum.filled :: any
		else {}
	local have: { [string]: number } = {}
	local owned: { [string]: SharedTypes.CatView } = cats or {}
	for _, cat in owned do
		have[cat.catId] = (have[cat.catId] or 0) + 1
	end
	local out: { RoomRow } = {}
	for _, room in LateStations.rooms do
		local exhibits: { Exhibit } = {}
		local count, canFill = 0, 0
		for _, catId in room.cats do
			local def = Catalog.getCat(catId)
			local coat = filled[catId]
			local give = LateStationsLogic.donatable(cats, catId, filled, spa)
			local copies = have[catId] or 0
			if coat ~= nil then
				count += 1
			elseif #give > 0 then
				canFill += 1
			end
			table.insert(exhibits, {
				catId = catId,
				name = if def ~= nil then def.name else catId,
				rarity = if def ~= nil then def.rarity else "Common",
				coat = coat,
				have = copies,
				give = give,
				line = if coat ~= nil then "Given" else string.format("You have %d", copies),
			})
		end
		table.insert(out, {
			area = room.area,
			name = room.name,
			exhibits = exhibits,
			filled = count,
			done = #room.cats > 0 and count == #room.cats,
			canFill = canFill,
		})
	end
	return out
end

-- A gold or rainbow copy asks first (section 2): "This is a gold cat. Give it anyway?"
function LateStationsLogic.giveWarning(variant: string?): string?
	if variant == "gold" or variant == "rainbow" then
		return string.format("This is a %s cat. Give it anyway?", variant)
	end
	return nil
end

-- Why an empty exhibit can't be filled now, for its tile's note: no copy, the one copy kept, or every spare locked
-- or at the spa.
function LateStationsLogic.whyNot(exhibit: Exhibit): string
	if exhibit.coat ~= nil then
		return "Already given"
	elseif exhibit.have == 0 then
		return "Catch this cat first"
	elseif exhibit.have == 1 then
		return "You need a second copy to give one"
	end
	return "Unlock a copy, or take it out of the spa"
end

function LateStationsLogic.bonusText(bonus: number?): string
	return string.format("+%d%% tips forever", math.floor((bonus or 0) * 100 + 0.5))
end

function LateStationsLogic.roomBonusText(): string
	return string.format(
		"Each finished room: %s",
		LateStationsLogic.bonusText(Config.MuseumRoomTipBonus)
	)
end

-- Picker line and bubble -----------------------------------------------------------------------------------------

local function stationOfArea(areaId: string): string?
	for stationId, area in LateStationsLogic.AREAS do
		if area == areaId then
			return stationId
		end
	end
	return nil
end

local function stationView(state: SharedTypes.LateStationsState?, stationId: string): any
	if type(state) ~= "table" or state.live ~= true then
		return nil
	end
	local view = (state :: any)[stationId]
	return if type(view) == "table" and view.open == true then view else nil
end

-- Whether a station's "!" shows: a spa cat with a level to collect, or an exhibit the player can fill.
function LateStationsLogic.bangShows(
	state: SharedTypes.LateStationsState?,
	stationId: string
): boolean
	local view = stationView(state, stationId)
	if view == nil then
		return false
	end
	if stationId == LateStationsLogic.SPA then
		return (view.ready or 0) > 0
	end
	return (view.canFill or 0) > 0
end

-- The shared line "Oasis Spa: 1 relaxing · +7 levels ready !" as the card's strip: the name, then the rest
-- capitalised without the "!", which the red dot says.
function LateStationsLogic.bubble(state: SharedTypes.LateStationsState?, stationId: string): Line?
	if stationView(state, stationId) == nil then
		return nil
	end
	local name = LateStationsLogic.NAMES[stationId] or stationId
	local line: string = LateStations.pickerLine(stationId, state)
	local rest = line
	local prefix = name .. ": "
	if string.sub(rest, 1, #prefix) == prefix then
		rest = string.sub(rest, #prefix + 1)
	end
	rest = string.gsub(rest, "%s*!$", "")
	rest = string.upper(string.sub(rest, 1, 1)) .. string.sub(rest, 2)
	return {
		extraId = stationId,
		icon = LateStationsLogic.ICONS[stationId] or "🎁",
		name = name,
		state = rest,
		ready = LateStationsLogic.bangShows(state, stationId),
	}
end

function LateStationsLogic.pickerLine(state: SharedTypes.LateStationsState?, areaId: string): Line?
	local stationId = stationOfArea(areaId)
	return if stationId ~= nil then LateStationsLogic.bubble(state, stationId) else nil
end

return LateStationsLogic
