--!strict
-- The camp extras on the UI (F100, camp-extras.md sections 1 to 3), pure so the cloud spec runner checks them. The
-- rules and the words of the picker line are the server half's (shared/CampExtras); this shapes them for the cards:
--   icon(extraId)                    the extra's glyph: 🧺 Picnic Basket, 🏷️ Yard Sale, 🎣 Fish Pond, 📦 Lost and Found
--   pickerLine(state, areaId, now)   the Cat Cannon card's line under "7/10 cats" (section 3): the extra's icon, its
--                                    name and what waits ("1 ready", "14 fish", "Next in 2 h 10 m"), with `ready`
--                                    for the card's red "!" dot (the Yard Sale's free crate too, #1051), or nil for
--                                    an area with no extra, a shut one or no state yet
--   yardRows(view, fish)             the Yard Sale card's crates in stock order: id, price, bought, and whether this
--                                    player's golden fish cover it
--   yardButton(row, pending)         a crate's button: "Take", "Taken" once taken, "..." while a take is out
--   yardFooter(view, now)            when the next crate comes: "New crate in 3 h 10 m"
--   yardOddsLines(odds)              the card's Odds lines (#1051, crate-prices.md section 5): "Common  60%" per
--                                    rarity the crate can give, Common first
--   prizeTitle(extraId, paid)        the prize toast's line: "Fish Pond: +14 golden fish"

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CampExtras = require(Shared:WaitForChild("CampExtras")) :: any
local Catalog = require(Shared:WaitForChild("Catalog")) :: any
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

return CampExtrasLogic
