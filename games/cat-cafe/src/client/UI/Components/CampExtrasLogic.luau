--!strict
-- The camp extras on the UI (F100, camp-extras.md sections 1 to 3), pure so the cloud spec runner checks them. The
-- rules and the words of the picker line are the server half's (shared/CampExtras); this shapes them for the cards:
--   icon(extraId)                    the extra's glyph: 🧺 Picnic Basket, 🏷️ Yard Sale, 🎣 Fish Pond, 📦 Lost and Found
--   pickerLine(state, areaId, now)   the Cat Cannon card's line under "7/10 cats" (section 3): the extra's icon, its
--                                    name and what waits ("1 ready", "14 fish", "Next in 2 h 10 m"), with `ready`
--                                    for the card's red "!" dot (the Yard Sale's free crate too, #1051), or nil for
--                                    an area with no extra, a shut one or no state yet
--   binLine(areaId, nextAt, now, on) the Rummage Bin's line on the Alleyway's card: "Ready" with the dot, or "Empty
--                                    for now"; withBin(station, bin) picks which of the two lines a card shows
--   yardRows(view, fish)             the Yard Sale card's crates in stock order: id, price, bought, and whether this
--                                    player's golden fish cover it
--   yardButton(row, pending)         a crate's button: "Take", "Taken" once taken, "..." while a take is out
--   yardFooter(view, now)            when the next crate comes: "New crate in 3 h 10 m"
--   yardOddsLines(odds)              the card's Odds lines (#1051, crate-prices.md section 5): "Common  60%" per
--                                    rarity the crate can give, Common first
--   prizeTitle(extraId, paid)        the prize toast's line: "Fish Pond: +14 golden fish"
--   bangShows(state, extraId)        whether a station's red "!" (ReadyBang, camp-stations.md section 1) shows: the
--                                    extra is open and holds something to claim; BANG_EXTRAS lists the stations
--   bubbleLift(anchorY, modelTop)   #2096: studs to lift a bubble from its anchor so it clears its station's top
--   bubble(state, extraId, now)      #1614: the bubble always over an open station (ReadyBang): the picker's line for
--                                    that station's area, so it reads "14 fish" or "Next in 2 h 10 m"; nil while shut

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CampExtras = require(Shared:WaitForChild("CampExtras")) :: any
local Catalog = require(Shared:WaitForChild("Catalog")) :: any
local RummageBin = require(Shared:WaitForChild("RummageBin")) :: any
local SharedTypes = require(Shared:WaitForChild("Types"))

local MarketLogic = require(script.Parent:WaitForChild("MarketLogic"))

export type Line = {
	extraId: string,
	icon: string,
	name: string,
	state: string, -- "1 ready", "New crates", "14 fish", "2 to claim", "Next in 2 h 10 m", "Sold out"
	ready: boolean,
}

export type YardRow = {
	crateId: string,
	price: number,
	bought: boolean,
	afford: boolean,
}

local CampExtrasLogic = {}

CampExtrasLogic.YARD_SALE = "yardSale"

local ICONS: { [string]: string } = {
	picnic = "🧺",
	yardSale = "🏷️",
	pond = "🎣",
	lostFound = "📦",
}

function CampExtrasLogic.icon(extraId: string): string
	return ICONS[extraId] or "🎁"
end

local function defForArea(areaId: string): SharedTypes.CampExtraDef?
	for _, def in Catalog.campExtras :: { SharedTypes.CampExtraDef } do
		if def.area == areaId then
			return def
		end
	end
	return nil
end

local function nameOf(extraId: string): string
	local def: SharedTypes.CampExtraDef? = Catalog.getCampExtra(extraId)
	return if def ~= nil then def.name else extraId
end

function CampExtrasLogic.pickerLine(
	state: SharedTypes.CampExtrasState?,
	areaId: string,
	now: number
): Line?
	if state == nil then
		return nil
	end
	local def = defForArea(areaId)
	if def == nil then
		return nil
	end
	local line: string?, ready: boolean = CampExtras.pickerLine(state, areaId, now)
	if line == nil then
		return nil
	end
	-- the shared line is "Picnic Basket: 1 ready !": the card shows the name, the rest under it and a red dot
	local rest = line
	local prefix = def.name .. ": "
	if string.sub(rest, 1, #prefix) == prefix then
		rest = string.sub(rest, #prefix + 1)
	elseif rest == def.name then
		rest = ""
	end
	rest = string.gsub(rest, "%s*!$", "")
	rest = string.upper(string.sub(rest, 1, 1)) .. string.sub(rest, 2)
	return {
		extraId = def.id,
		icon = CampExtrasLogic.icon(def.id),
		name = def.name,
		state = rest,
		ready = ready, -- the Yard Sale's free crate lights the dot too since #1051
	}
end

-- Derek 2026-11-12 ("the rummage bin ... doesn't show in cannon menu like it should"): the Rummage Bin's line on its
-- area's Cat Cannon card. `nextAt` is the player's BinNextAt attribute (anything but a number: full), `on` the
-- `alleyBin` switch. "Ready" with the red dot while it is full, else "Empty for now": never a countdown, like the
-- bin's own prompt (#3050). nil on another area's card or while the bin is switched off.
CampExtrasLogic.BIN = "bin"
CampExtrasLogic.BIN_ICON = "🗑️"
CampExtrasLogic.BIN_READY = "Ready"
CampExtrasLogic.BIN_EMPTY = "Empty for now"

function CampExtrasLogic.binLine(areaId: string, nextAt: unknown, now: number, on: boolean): Line?
	if not on or areaId ~= RummageBin.AREA then
		return nil
	end
	local full = type(nextAt) ~= "number" or now >= (nextAt :: number)
	return {
		extraId = CampExtrasLogic.BIN,
		icon = CampExtrasLogic.BIN_ICON,
		name = RummageBin.NAME,
		state = if full then CampExtrasLogic.BIN_READY else CampExtrasLogic.BIN_EMPTY,
		ready = full,
	}
end

-- A card has room for one line: the station's own line keeps it unless only the bin has something waiting.
function CampExtrasLogic.withBin(station: Line?, bin: Line?): Line?
	if station == nil then
		return bin
	elseif bin ~= nil and bin.ready and not station.ready then
		return bin
	end
	return station
end

function CampExtrasLogic.yardRows(view: SharedTypes.CampExtraView?, fish: number?): { YardRow }
	local rows: { YardRow } = {}
	if view == nil or not view.open then
		return rows
	end
	local have = if type(fish) == "number" then fish else 0
	local stock: { SharedTypes.YardSaleCrate } = view.stock or {}
	for _, crate in stock do
		table.insert(rows, {
			crateId = crate.crateId,
			price = crate.price,
			bought = crate.bought == true,
			afford = have >= crate.price,
		})
	end
	return rows
end

-- The card's button (#1051, crate-prices.md section 5): "Take" for today's free crate, "Taken" once taken; a priced
-- crate (an older server) still shows its price.
function CampExtrasLogic.yardButton(row: YardRow, pending: boolean): string
	if row.bought then
		return if row.price <= 0 then "Taken" else "Bought"
	elseif pending then
		return "..."
	end
	return if row.price <= 0 then "Take" else tostring(row.price)
end

-- The Odds lines on a Yard Sale crate (#1051): the crate's own rarity table as the Market shows it. The take is free,
-- but the crate is random, so its odds show before it is taken (monetization-policy section 2, the Market's rule).
function CampExtrasLogic.yardOddsLines(
	odds: { [string]: number }?
): { { rarity: string, text: string } }
	local lines = {}
	for _, row in MarketLogic.rarityRows(odds or {}) do
		table.insert(lines, { rarity = row.rarity, text = MarketLogic.percent(row.percent) })
	end
	return lines
end

function CampExtrasLogic.yardFooter(view: SharedTypes.CampExtraView?, now: number): string
	if view == nil or not view.open then
		return string.format("Opens at Tier %d", CampExtras.tierOf(CampExtrasLogic.YARD_SALE) or 3)
	end
	-- #1154 (save version 33): a crate every 4 h from the last take, so no nextAt means one is waiting now
	if view.nextAt == nil then
		return if view.held > 0 then "A free crate is waiting" else "New crate soon"
	end
	return "New crate in " .. (CampExtras.waitText(view.nextAt - now) :: string)
end

function CampExtrasLogic.prizeTitle(extraId: string, paid: { string }?): string
	local name = nameOf(extraId)
	local words: { string } = {}
	local lines: { string } = if type(paid) == "table" then paid else {}
	for _, line in lines do
		if type(line) == "string" and line ~= "" then
			table.insert(words, line)
		end
	end
	if #words == 0 then
		return name
	end
	return name .. ": " .. table.concat(words, ", ")
end

-- The camp stations with a red "!" over them (camp-stations.md section 1); the Lost and Found keeps its card only.
-- The Golden Pond pass's Player attribute (the server sets it for an owner). #3093: the pass doubles the owner's pond
-- fish, which the server's numbers already carry. Until #3082 it also gave the Woods strip its Collect button (#1463).
CampExtrasLogic.GOLD_POND_ATTRIBUTE = "GoldenPondPass" -- shared/CampExtras.GOLD_POND_ATTRIBUTE
CampExtrasLogic.POND = "pond"

-- #3082 (Derek2 2026-11-10: "be able to claim/open from cannon menu any stations you have unlocked so you dont have
-- to always travel", "make claiming stations from anywhere free"): what the button on a Cat Cannon card's strip does
-- for `line`. "collect" while the Picnic Basket, Fish Pond or Lost and Found holds something (CollectCampExtra,
-- from anywhere); "open" for a station with a card of its own (the Yard Sale, the Oasis Spa, the Relic Museum); nil
-- for no button. A strip only shows for a station the player's tier has opened.
export type RemoteAction = "collect" | "open"
CampExtrasLogic.REMOTE_COLLECT =
	{ picnic = true, pond = true, lostFound = true } :: { [string]: boolean }
CampExtrasLogic.REMOTE_WORDS = { collect = "Collect", open = "Open" } :: { [string]: string }

function CampExtrasLogic.remoteAction(line: Line?): RemoteAction?
	if line == nil or line.extraId == CampExtrasLogic.BIN then
		return nil -- the Rummage Bin is played at the bin: no button, the red dot says it is full
	end
	if CampExtrasLogic.REMOTE_COLLECT[line.extraId] then
		return if line.ready then "collect" else nil
	end
	return "open"
end

CampExtrasLogic.BANG_EXTRAS = { "picnic", "yardSale", "pond", "lostFound" } -- lostFound: #1733
-- studs from the camera (a BillboardGui's MaxDistance). Was 150 (camp-stations.md section 5, ReadyBangRange). #2730
-- (Derek2 11-09: "remove the obnoxious highlighting from stations in areas unless close by"): 40 from the camera is
-- about 25 from the player at the usual zoom, the same "close by" as Wayfinding's NEAR; the HUD dot and the Cat Cannon
-- picker still say something waits from further off
CampExtrasLogic.BANG_RANGE = 40
-- #2096: studs from a station bubble's middle to just under it (half its 1.8 studs, plus its 18 px at a typical
-- distance and a little air), so a bubble lifted by bubbleLift sits clear over its station
CampExtrasLogic.BUBBLE_CLEAR = 1.8

-- #2096 (the Picnic Basket's "!" hid behind its parasol): how many studs to lift a station's bubble from its
-- BangAnchor (at `anchorY`) so it clears the top of the station model (`modelTop`); 0 when it already does.
function CampExtrasLogic.bubbleLift(anchorY: number, modelTop: number): number
	return math.max(0, modelTop + CampExtrasLogic.BUBBLE_CLEAR - anchorY)
end

-- #1614 (Derek2 11-05: "when in the area with the stations example fish pond to always have a bubble up for whatever
-- station is in that area"): the bubble over station `extraId`, the Cat Cannon picker's line for its area (icon,
-- name, what waits and `ready` for its red "!"), or nil before the first state or while the extra is shut.
function CampExtrasLogic.bubble(state: unknown, extraId: string, now: number): Line?
	if type(state) ~= "table" then
		return nil
	end
	local def: SharedTypes.CampExtraDef? = Catalog.getCampExtra(extraId)
	if def == nil then
		return nil
	end
	local view = (state :: any)[extraId]
	if type(view) ~= "table" or view.open ~= true or type(view.held) ~= "number" then
		return nil
	end
	return CampExtrasLogic.pickerLine(state :: any, def.area, now)
end

-- Whether `extraId`'s "!" shows for this CampExtrasState: the extra is open and holds something to claim (`held > 0`,
-- the same state the Cat Cannon picker's dot reads), so it hides the moment it's claimed and while it refills.
function CampExtrasLogic.bangShows(state: unknown, extraId: string): boolean
	if type(state) ~= "table" then
		return false
	end
	local view = (state :: any)[extraId]
	if type(view) ~= "table" or view.open ~= true then
		return false
	end
	local held = view.held
	return type(held) == "number" and held > 0
end

return CampExtrasLogic
