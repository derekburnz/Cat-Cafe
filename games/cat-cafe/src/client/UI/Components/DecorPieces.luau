--!strict
-- Crate cosmetics (F53, golden-fish.md section 4): what kind a piece is, which crate it comes from, the style slots
-- (one wallpaper, one floor and one paint in use) and the decor spots that furniture and decorations stand on, and
-- the Decor Index's pages (area ids "decor_alley" to "decor_classic"). A piece is a DecorDef with `crate` (its
-- pool), `rarity` and `kind`; those are read loosely until SharedTypes.DecorDef has them. The crate pieces live in
-- Catalog.crateDecor, and the five F48 Index pieces in Catalog.decor are their zones' Epics, so `all` reads both.
-- Pure: no Theme, so the cloud spec runner can load it.

local Types = require(script.Parent.Parent.Types)

export type Kind = "wallpaper" | "floor" | "paint" | "furniture" | "decoration"

export type Piece = {
	pool: string?, -- the crate's zone id or "classic"
	rarity: string?,
	kind: Kind?,
}

local DecorPieces = {}

DecorPieces.AREA_PREFIX = "decor_" -- a Decor Index page's area id is this plus the pool
DecorPieces.STYLE_KINDS = { "wallpaper", "floor", "paint" } :: { Kind }
DecorPieces.KINDS = { "wallpaper", "floor", "paint", "furniture", "decoration" } :: { Kind }
DecorPieces.SPOTS_BY_TIER = { 2, 3, 4, 5, 6 } -- DecorSpots until Config has it
DecorPieces.EXTRA_SPOT_PERK = "extra_decor_spot"

local KIND_INFO: { [string]: { name: string, icon: string } } = {
	wallpaper = { name = "Wallpaper", icon = "🖼️" },
	floor = { name = "Floor", icon = "🟫" },
	paint = { name = "Paint", icon = "🎨" },
	furniture = { name = "Furniture", icon = "🪑" },
	decoration = { name = "Decoration", icon = "🪴" },
}

local RARITY_RANK: { [string]: number } =
	{ Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythical = 5 }

-- Each catalog's pages, sorted once (reviewer N172): pageCounts runs per chip and per Index page on every sync. Keyed
-- weakly by the catalog table, so a new catalog table starts afresh and an old one is let go.
type Pages = { [string]: { Types.DecorDef } }
local pageCache: { [Types.Catalog]: Pages } = setmetatable({}, { __mode = "k" }) :: any

-- Every decor item: Catalog.decor, then the crate pieces in Catalog.crateDecor that are not already in it.
function DecorPieces.all(catalog: Types.Catalog): { Types.DecorDef }
	local list: { Types.DecorDef } = table.clone(catalog.decor)
	local pieces: { Types.DecorDef } = catalog.crateDecor or {}
	if #pieces == 0 then
		return list
	end
	local seen: { [string]: boolean } = {}
	for _, def in list do
		seen[def.id] = true
	end
	for _, def in pieces do
		if not seen[def.id] then
			seen[def.id] = true
			table.insert(list, def)
		end
	end
	return list
end

-- A piece's pool, rarity and kind; all nil for coin decor.
function DecorPieces.info(def: Types.DecorDef?): Piece
	if def == nil then
		return {}
	end
	local loose = def :: any
	local kind: Kind? = if type(loose.kind) == "string" and KIND_INFO[loose.kind]
		then loose.kind :: Kind
		else nil
	return {
		pool = if type(loose.crate) == "string" then loose.crate else nil,
		rarity = if type(loose.rarity) == "string" then loose.rarity else nil,
		kind = kind,
	}
end

-- Whether a decor item is a crate piece (it has a kind), so it is never bought with coins.
function DecorPieces.isPiece(def: Types.DecorDef?): boolean
	return DecorPieces.info(def).kind ~= nil
end

-- Wallpaper, floor and paint: one of each in use at a time; the rest stand on decor spots.
function DecorPieces.isStyle(kind: string?): boolean
	return kind == "wallpaper" or kind == "floor" or kind == "paint"
end

function DecorPieces.kindName(kind: string?): string
	local info = if kind then KIND_INFO[kind] else nil
	return if info then info.name else "Cosmetic"
end

function DecorPieces.kindIcon(kind: string?, fallback: string): string
	local info = if kind then KIND_INFO[kind] else nil
	return if info then info.icon else fallback
end

-- How many decor spots the cafe has: DecorSpots for the tier (the last entry past the end) plus one per Extra Decor
-- Spot level.
function DecorPieces.spots(tier: number, perks: { [string]: number }?, byTier: { number }?): number
	local list = byTier or DecorPieces.SPOTS_BY_TIER
	local index = math.clamp(math.floor(tier), 1, math.max(#list, 1))
	local extra = if perks then perks[DecorPieces.EXTRA_SPOT_PERK] or 0 else 0
	return (list[index] or 0) + math.max(0, math.floor(extra))
end

-- Placed furniture and decoration pieces: the spots in use. Coin-shop decor has no kind and keeps its own place.
-- `replaced` (IndexRewards.replacedBy) leaves out a normal Index piece while its gold piece is placed, as the
-- server does.
function DecorPieces.spotsUsed(
	decor: { Types.DecorDef },
	placed: { [string]: boolean },
	replaced: { [string]: string }?
): number
	local used = 0
	for _, def in decor do
		local kind = DecorPieces.info(def).kind
		local skipped = replaced ~= nil and replaced[def.id] ~= nil
		if
			kind ~= nil
			and not DecorPieces.isStyle(kind)
			and placed[def.id] == true
			and not skipped
		then
			used += 1
		end
	end
	return used
end

-- The placed piece of a style kind, or nil when the cafe shows its plain look.
function DecorPieces.inUse(
	decor: { Types.DecorDef },
	placed: { [string]: boolean },
	kind: string
): Types.DecorDef?
	for _, def in decor do
		if placed[def.id] == true and DecorPieces.info(def).kind == kind then
			return def
		end
	end
	return nil
end

-- "decor_alley" -> "alley"; nil for any other area id.
function DecorPieces.poolOf(areaId: string): string?
	local prefix = DecorPieces.AREA_PREFIX
	if areaId:sub(1, #prefix) == prefix and #areaId > #prefix then
		return areaId:sub(#prefix + 1)
	end
	return nil
end

function DecorPieces.areaOf(pool: string): string
	return DecorPieces.AREA_PREFIX .. pool
end

-- The Decor Index's pools in Market order: each plain crate's pool, then any pool only the pieces name.
function DecorPieces.pools(catalog: Types.Catalog): { string }
	local list: { string } = {}
	local seen: { [string]: boolean } = {}
	local crates: { Types.CrateDef } = catalog.crates or {}
	for _, crate in crates do
		if not crate.golden and not seen[crate.area] then
			seen[crate.area] = true
			table.insert(list, crate.area)
		end
	end
	for _, def in DecorPieces.all(catalog) do
		local pool = DecorPieces.info(def).pool
		if pool and not seen[pool] then
			seen[pool] = true
			table.insert(list, pool)
		end
	end
	return list
end

-- A page's pieces: the plain crate's `pieces` when it lists any, else every piece whose `crate` is the pool. Sorted
-- by rarity (rarest last, as the cat Index) and then in that order. Unknown ids are left out. The list is worked out
-- once per catalog table and shared, so callers must not change it.
function DecorPieces.poolPieces(catalog: Types.Catalog, pool: string): { Types.DecorDef }
	local pages: Pages? = pageCache[catalog]
	if pages == nil then
		local fresh: Pages = {}
		pageCache[catalog] = fresh
		pages = fresh
	end
	assert(pages, "pages")
	local cached = pages[pool]
	if cached then
		return cached
	end
	local decor = DecorPieces.all(catalog)
	local byId: { [string]: Types.DecorDef } = {}
	for _, def in decor do
		byId[def.id] = def
	end
	local ids: { string } = {}
	local crates: { Types.CrateDef } = catalog.crates or {}
	for _, crate in crates do
		if not crate.golden and crate.area == pool and #crate.pieces > 0 then
			ids = crate.pieces
			break
		end
	end
	if #ids == 0 then
		for _, def in decor do
			if DecorPieces.info(def).pool == pool then
				table.insert(ids, def.id)
			end
		end
	end
	local order: { [string]: number } = {}
	local list: { Types.DecorDef } = {}
	for index, id in ids do
		local def = byId[id]
		if def and order[id] == nil then
			order[id] = index
			table.insert(list, def)
		end
	end
	table.sort(list, function(a: Types.DecorDef, b: Types.DecorDef): boolean
		local rankA = RARITY_RANK[DecorPieces.info(a).rarity or ""] or 0
		local rankB = RARITY_RANK[DecorPieces.info(b).rarity or ""] or 0
		if rankA ~= rankB then
			return rankA < rankB
		end
		return order[a.id] < order[b.id]
	end)
	table.freeze(list)
	pages[pool] = list
	return list
end

-- A page's pieces owned and in all.
function DecorPieces.pageCounts(
	catalog: Types.Catalog,
	state: Types.PlayerState,
	pool: string
): (number, number)
	local pieces = DecorPieces.poolPieces(catalog, pool)
	local owned = 0
	for _, def in pieces do
		if state.decorOwned[def.id] == true then
			owned += 1
		end
	end
	return owned, #pieces
end

return DecorPieces
