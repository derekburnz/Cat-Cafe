--!strict
-- The Golden Fish Market's sums (F53, golden-fish.md sections 3 and 4): which crates a player can open, the lucky
-- twentieth countdown and the odds that apply to the next crate, each rarity's and each piece's chance, and what
-- the next perk level costs. Pure: no Theme, so the cloud spec runner can load it. The server rolls and pays; this
-- only says what the window shows.

-- The fields of a crate (SharedTypes.CrateDef) the sums read.
export type Crate = {
	id: string,
	area: string, -- a zone id or "classic"
	golden: boolean,
	price: number?,
	odds: { [string]: number },
}

-- The part of a Market row (SharedTypes.FishShopRow) that sets its price.
export type ShopRow = { cost: number?, costs: { number }?, maxLevel: number? }

export type Area = { id: string, tier: number }

export type RarityRow = { rarity: string, percent: number }

export type PieceChance = { id: string, rarity: string, percent: number }

type Known = { id: string, rarity: string, order: number }

local MarketLogic = {}

MarketLogic.RARITIES = { "Common", "Rare", "Epic", "Legendary", "Mythical" }
MarketLogic.CLASSIC = "classic" -- the Classic Crate's pool, open from Tier 1

local RANK: { [string]: number } = {}
for index, rarity in MarketLogic.RARITIES do
	RANK[rarity] = index
end

-- Crates of this pool to open before the lucky one, counting it: 20 after an Epic or better, 1 when the next crate
-- opens on the golden odds. `luck` is state.crateLuck[pool], the opens since the last Epic or better (0 to 19).
function MarketLogic.luckLeft(luck: number?, every: number): number
	return math.clamp(every - math.floor(luck or 0), 1, every)
end

-- "Epic or better in 4 more crates", or "Your next crate is Epic or better!" when it is the lucky one.
function MarketLogic.luckText(left: number): string
	if left <= 1 then
		return "Your next crate is Epic or better!"
	end
	return ("Epic or better in %d more crates"):format(left)
end

-- The odds the next crate of this kind opens on: a golden crate's own, the golden odds on the lucky twentieth,
-- else the crate's.
function MarketLogic.nextOdds(
	crate: Crate,
	luck: number?,
	every: number,
	goldenOdds: { [string]: number }?
): { [string]: number }
	local own = crate.odds
	if crate.golden or goldenOdds == nil then
		return own
	end
	return if MarketLogic.luckLeft(luck, every) <= 1 then goldenOdds else own
end

-- The rarities with a chance, Common first: { rarity, percent }.
function MarketLogic.rarityRows(odds: { [string]: number }): { RarityRow }
	local rows: { RarityRow } = {}
	for _, rarity in MarketLogic.RARITIES do
		local percent = odds[rarity] or 0
		if percent > 0 then
			table.insert(rows, { rarity = rarity, percent = percent })
		end
	end
	return rows
end

-- Each piece's chance: its rarity's odds split equally among that rarity's pieces, rarest first and in catalog
-- order within a rarity. `rarityOf` names a piece's rarity (nil leaves it out).
function MarketLogic.pieceChances(
	pieces: { string },
	rarityOf: (string) -> string?,
	odds: { [string]: number }
): { PieceChance }
	local count: { [string]: number } = {}
	local known: { Known } = {}
	for order, id in pieces do
		local rarity = rarityOf(id)
		if rarity ~= nil and RANK[rarity] ~= nil then
			count[rarity] = (count[rarity] or 0) + 1
			table.insert(known, { id = id, rarity = rarity, order = order })
		end
	end
	table.sort(known, function(a: Known, b: Known): boolean
		if a.rarity ~= b.rarity then
			return RANK[a.rarity] > RANK[b.rarity]
		end
		return a.order < b.order
	end)
	local out: { PieceChance } = {}
	for _, piece in known do
		table.insert(out, {
			id = piece.id,
			rarity = piece.rarity,
			percent = (odds[piece.rarity] or 0) / count[piece.rarity],
		})
	end
	return out
end

-- 15 -> "15%", 2.5 -> "2.5%", 26.6667 -> "26.67%", 0.05 -> "0.05%": at most two decimals, trailing zeros dropped.
function MarketLogic.percent(value: number): string
	local text = ("%.2f"):format(value):gsub("0+$", ""):gsub("%.$", "")
	return text .. "%"
end

-- A zone crate opens with its zone, the Classic Crate from Tier 1. An area the catalog does not list stays open.
function MarketLogic.isOpen(crate: Crate, tier: number, areas: { Area }?): boolean
	local area = crate.area
	if area == MarketLogic.CLASSIC then
		return true
	end
	local list: { Area } = areas or {}
	for _, def in list do
		if def.id == area then
			return def.tier <= tier
		end
	end
	return true
end

-- The tier a crate's zone opens at, for "Opens at Tier 3"; nil when it is open from the start.
function MarketLogic.openTier(crate: Crate, areas: { Area }?): number?
	local list: { Area } = areas or {}
	for _, def in list do
		if def.id == crate.area then
			return def.tier
		end
	end
	return nil
end

-- What the next buy of a row costs, or nil when a perk is at its last level. A crate or food has one `cost`.
function MarketLogic.cost(row: ShopRow, level: number?): number?
	if row.costs then
		local next = math.floor(level or 0) + 1
		if row.maxLevel and next > row.maxLevel then
			return nil
		end
		return row.costs[next]
	end
	return row.cost
end

return MarketLogic
