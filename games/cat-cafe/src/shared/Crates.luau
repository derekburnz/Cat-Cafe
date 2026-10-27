--!strict
-- Cafe Crates (F53, golden-fish.md section 4), pure, so the Market window and the server agree. A crate rolls a
-- rarity from its odds and then one of that rarity's pieces, each equally likely. The lucky twentieth: after
-- CrateLuckyEvery - 1 opens of one pool with nothing Epic or better, the next opens on the golden odds. A piece the
-- player owns already pays CrateDuplicateRefund golden fish instead. The cafe has one wallpaper, one floor and one
-- paint in use; furniture and decorations in use are capped by decor spots (DecorSpots by tier plus the Extra Decor
-- Spot perk). A Decor Index page with all ten pieces adds DecorIndexBonus to every tip.

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Crates = {}

local EPIC_RANK = Catalog.rarityRank.Epic

-- The odds a golden crate and a lucky twentieth use (every golden crate has the same).
local GOLDEN_ODDS: { [string]: number } = {}
for _, def in Catalog.crates do
	if def.golden then
		GOLDEN_ODDS = def.odds
		break
	end
end

-- Wallpaper, floor and paint: one of each in use at a time.
function Crates.isStyle(kind: Types.DecorKind?): boolean
	return kind == "wallpaper" or kind == "floor" or kind == "paint"
end

-- Furniture and decorations: each in use takes a decor spot.
function Crates.takesSpot(def: Types.DecorDef): boolean
	return def.kind == "furniture" or def.kind == "decoration"
end

-- True when this open of `crate` is the lucky twentieth: `luck` is the pool's opens since its last Epic or better.
function Crates.isLucky(crate: Types.CrateDef, luck: number): boolean
	return not crate.golden and luck >= Config.CrateLuckyEvery - 1
end

-- The rarity odds this open uses, in percent.
function Crates.oddsFor(crate: Types.CrateDef, luck: number): { [string]: number }
	return if Crates.isLucky(crate, luck) then GOLDEN_ODDS else crate.odds
end

-- Each piece's chance in percent under `odds`: its rarity's share split equally among that rarity's pieces. The
-- crate card shows these before it opens (monetization-policy section 2).
function Crates.pieceChances(
	crate: Types.CrateDef,
	odds: { [string]: number }
): { [string]: number }
	local count: { [string]: number } = {}
	for _, decorId in crate.pieces do
		local def = Catalog.getDecor(decorId)
		if def ~= nil and def.rarity ~= nil then
			count[def.rarity] = (count[def.rarity] or 0) + 1
		end
	end
	local chances: { [string]: number } = {}
	for _, decorId in crate.pieces do
		local def = Catalog.getDecor(decorId)
		local rarity = if def ~= nil then def.rarity else nil
		if rarity ~= nil then
			chances[decorId] = (odds[rarity] or 0) / count[rarity]
		end
	end
	return chances
end

-- The piece one open gives: `rarityRoll` picks the rarity by its odds (rarest last, as Catalog.rarityOrder), then
-- `pieceRoll` one of that rarity's pieces. Both rolls are in [0, 1). Also whether it was the lucky twentieth.
function Crates.roll(
	crate: Types.CrateDef,
	luck: number,
	rarityRoll: number,
	pieceRoll: number
): (string, boolean)
	local lucky = Crates.isLucky(crate, luck)
	local odds = Crates.oddsFor(crate, luck)
	local total = 0
	for _, rarity in Catalog.rarityOrder do
		total += odds[rarity] or 0
	end
	local target = math.clamp(rarityRoll, 0, 0.999999) * total
	local picked: Types.Rarity = "Common"
	local acc = 0
	for _, rarity: Types.Rarity in Catalog.rarityOrder do
		local weight = odds[rarity] or 0
		if weight > 0 then
			picked = rarity
			acc += weight
			if target < acc then
				break
			end
		end
	end
	local pieces: { string } = {}
	for _, decorId in crate.pieces do
		local def = Catalog.getDecor(decorId)
		if def ~= nil and def.rarity == picked then
			table.insert(pieces, decorId)
		end
	end
	local index =
		math.clamp(math.floor(math.clamp(pieceRoll, 0, 0.999999) * #pieces) + 1, 1, #pieces)
	return pieces[index], lucky
end

-- The pool's count after an open that gave `rarity`: back to 0 on Epic or better, else one more, capped so a long
-- run never overflows the saved value.
function Crates.luckAfter(luck: number, rarity: Types.Rarity): number
	if Catalog.rarityRank[rarity] >= EPIC_RANK then
		return 0
	end
	return math.min(luck + 1, Config.CrateLuckyEvery - 1)
end

-- Golden fish back for a duplicate piece.
function Crates.refund(rarity: Types.Rarity): number
	return Config.CrateDuplicateRefund[rarity] or 0
end

-- Decor spots for furniture and decorations: DecorSpots at the tier, plus one per Extra Decor Spot level.
function Crates.spotCap(tier: number, extraSpots: number): number
	local spots = Config.DecorSpots
	return spots[math.clamp(tier, 1, #spots)] + math.max(0, extraSpots)
end

-- Furniture and decorations in use (owned and placed; a gold Index piece's normal piece is out, as in the bonus).
function Crates.spotsUsed(profile: Types.PlayerProfile, replaced: { [string]: boolean }): number
	local used = 0
	for decorId, placed in profile.decorPlaced do
		local def = Catalog.getDecor(decorId)
		if
			placed
			and def ~= nil
			and Crates.takesSpot(def)
			and profile.decorOwned[decorId]
			and not replaced[decorId]
		then
			used += 1
		end
	end
	return used
end

-- The style piece of `kind` in use, or nil.
function Crates.styleInUse(profile: Types.PlayerProfile, kind: Types.DecorKind): string?
	for decorId, placed in profile.decorPlaced do
		local def = Catalog.getDecor(decorId)
		if placed and def ~= nil and def.kind == kind and profile.decorOwned[decorId] then
			return decorId
		end
	end
	return nil
end

-- Pieces of `pool` the player owns, out of its ten.
function Crates.pageCount(profile: Types.PlayerProfile, pool: string): number
	local n = 0
	for _, def in Catalog.crateDecor do
		if def.crate == pool and profile.decorOwned[def.id] then
			n += 1
		end
	end
	return n
end

-- Decor Index pages with every piece found.
function Crates.fullPages(profile: Types.PlayerProfile): number
	local owned: { [string]: number } = {}
	local size: { [string]: number } = {}
	for _, def in Catalog.crateDecor do
		local pool = def.crate :: string
		size[pool] = (size[pool] or 0) + 1
		if profile.decorOwned[def.id] then
			owned[pool] = (owned[pool] or 0) + 1
		end
	end
	local full = 0
	for pool, n in size do
		if owned[pool] == n then
			full += 1
		end
	end
	return full
end

-- Why `crateId` cannot be opened now, or nil (the Market's range and cooldown are the server's). `tier` opens the
-- zone crates (the Classic Crate is open from Tier 1); a banked crate is used before fish.
function Crates.openBlocker(profile: Types.PlayerProfile, tier: number, crateId: string): string?
	local crate = Catalog.getCrate(crateId)
	if crate == nil then
		return "Unknown crate"
	end
	if crate.area ~= "classic" then
		local area = Catalog.getArea(crate.area)
		if area == nil or tier < area.tier then
			return "Unlock this zone first"
		end
	end
	if (profile.crates[crateId] or 0) > 0 then
		return nil
	end
	local price = crate.price
	if price == nil then
		return "Golden crates come from the Index"
	end
	if profile.goldenFish < price then
		return "Not enough golden fish"
	end
	return nil
end

-- What one BuyFishItem of `row` costs at the player's level, or nil and why not. Crates open through OpenCrate.
function Crates.buyCost(profile: Types.PlayerProfile, row: Types.FishShopRow): (number?, string?)
	local cost: number? = row.cost
	if row.kind == "crate" then
		return nil, "Open crates at the Market"
	elseif row.kind == "perk" then
		local level = profile.fishPerks[row.id] or 0
		if level >= (row.maxLevel or 1) then
			return nil, "Already at the top level"
		end
		cost = if row.costs ~= nil then row.costs[level + 1] else nil
	end
	if cost == nil then
		return nil, "Not for sale"
	end
	if profile.goldenFish < cost then
		return nil, "Not enough golden fish"
	end
	return cost, nil
end

return Crates
