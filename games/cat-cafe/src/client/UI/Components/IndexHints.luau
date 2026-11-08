--!strict
-- Where to find the missing cats (#1919, first-hour.md section 5): the Index's hint line for a cat not found yet and
-- the goal card's "Find N more cats" nudge while the Grand Opening's twelve cats step is next (#2530 took the "Park 4 /
-- 10" line off the new-cat reveal and the bait Tame card). Every line is built from data the client already has, so each is true:
-- bait picks from every open area (data-model section 8), and Epic and up are the Skittish ones (catch-rework.md 7a).
-- Nothing is sold and no odds change. Pure (no Theme, no Format), so the cloud specs load it.
--   hint(catalog, state, def) -> string?        the detail card's line for a missing cat, nil for an exclusive one
--                                               (it keeps "Not found yet")
--   nudge(catalog, state) -> Nudge?             { text = "Find 3 more cats", area = "park" } while step 7 is next
--   TWELVE_STEP, TWELVE                         the Grand Opening step and its count (the server's distinctCats >= 12)

local IndexBook = require(script.Parent.IndexBook)
local RoadmapLogic = require(script.Parent.RoadmapLogic)
local Types = require(script.Parent.Parent.Types)

export type Nudge = { text: string, area: string? }

local IndexHints = {}

IndexHints.NOT_FOUND = "Not found yet"
IndexHints.SHY = "Shy: walk up slowly."
IndexHints.TWELVE_STEP = 7
IndexHints.TWELVE = 12

local SHY_RARITIES: { [string]: boolean } = { Epic = true, Legendary = true, Mythical = true }

local function areaOf(catalog: Types.Catalog, areaId: string): Types.AreaDef?
	local areas: { Types.AreaDef } = catalog.areas or {}
	for _, area in areas do
		if area.id == areaId then
			return area
		end
	end
	return nil
end

local function nameOf(catalog: Types.Catalog, areaId: string): string
	local area = areaOf(catalog, areaId)
	if area and type(area.name) == "string" and area.name ~= "" then
		return area.name
	end
	return areaId:sub(1, 1):upper() .. areaId:sub(2)
end

local function exclusive(def: Types.CatDef): boolean
	return def.exclusive == true or def.area == IndexBook.EXCLUSIVE
end

function IndexHints.hint(
	catalog: Types.Catalog,
	state: Types.PlayerState,
	def: Types.CatDef
): string?
	if exclusive(def) then
		return nil
	end
	local areaId: string = def.area or IndexBook.FALLBACK_AREA
	local area = areaOf(catalog, areaId)
	local name = nameOf(catalog, areaId)
	local line: string
	if area and (state.tier or 1) < area.tier then
		line = ("%s. The %s opens at Tier %d."):format(IndexHints.NOT_FOUND, name, area.tier)
	else
		line = ("%s. Catch one in the %s, or it may come to your bait."):format(
			IndexHints.NOT_FOUND,
			name
		)
	end
	if SHY_RARITIES[def.rarity] then
		line ..= " " .. IndexHints.SHY
	end
	return line
end

-- The server's Economy.distinctCats: collection entries that are not exclusive (an id the catalog lacks counts).
local function distinct(catalog: Types.Catalog, state: Types.PlayerState): number
	local byId: { [string]: Types.CatDef } = {}
	for _, def in catalog.cats do
		byId[def.id] = def
	end
	local n = 0
	local collection: { [string]: number } = state.collection or {}
	for catId in collection do
		local def = byId[catId]
		if def == nil or def.exclusive ~= true then
			n += 1
		end
	end
	return n
end

function IndexHints.nudge(catalog: Types.Catalog, state: Types.PlayerState): Nudge?
	local view = RoadmapLogic.view(state :: any)
	local row = if view then view.rows[IndexHints.TWELVE_STEP] else nil
	if row == nil or not row.next then
		return nil
	end
	local need = IndexHints.TWELVE - distinct(catalog, state)
	if need <= 0 then
		return nil -- the server pays the step on its next check
	end
	-- the newest open area with the most cats still to find: sections are in tier order, so a tie goes to the later
	local best: IndexBook.Section? = nil
	for _, section in IndexBook.sections(catalog, state, "normal") do
		if section.exclusive or section.locked or (state.tier or 1) < section.tier then
			continue
		end
		local missing = section.total - section.have
		if missing > 0 and (best == nil or missing >= best.total - best.have) then
			best = section
		end
	end
	return {
		text = if need == 1 then "Find 1 more cat" else ("Find %d more cats"):format(need),
		area = if best then best.id else nil,
	}
end

return IndexHints
