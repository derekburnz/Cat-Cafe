--!strict
-- #5038 (Design-Agent's spec Design-Agent/dropoff-2026-11-17/park-to-tier3.md; run 44002569974: park_catch 244 to
-- tier_3 156, 36% lost, most still 3 or more new kinds short of Tier 3's 6 with under a quarter of its coins). At Tier
-- 2, behind the switch `tier3Path` (LiveFlags.OFF_BY_DEFAULT):
--   a stray of a kind the player does not own waits near the Park camp's landing for them, as SecondCat's does in the
--     Alleyway (CatService), with the first catch's slow circle; once the kinds are met and the Rares are not, a Rare
--     they do not own waits instead,
--   the goal card names the one next thing (goalLine): the kinds first, then the Rares; the coins line after that is
--     the card's own,
--   once Tier 3's kinds and Rares are met at Tier 2 the coins are topped up once by up to GIFT_MAX, never past Tier
--     3's cost (topUpFor; stats.tier3TopUp holds what was paid), shown as a gift: the price stays the real price.
-- Pure.
--   need(profile) -> Need?                     "kinds" or "rare" while one is short at Tier 2, else nil
--   kindsShort(profile), raresShort(profile)   how many of each Tier 3 still needs (0 off Tier 2)
--   fits(profile, def, variant, need) -> boolean   whether a stray may be the one that waits for that need
--   goalLine(profile, narrow?) -> string?      "Catch 2 more new kinds" ("Catch 2 new kinds" on a phone), "Catch 1
--                                              more Rare", or nil
--   spawnRarity(profile, need) -> Rarity?      the rarity of a stray to bring in, or nil when no Park kind fits
--   topUpFor(profile, on) -> number            the welcome gift to pay now, else 0
--   giftLine(gift) -> string                   the gift's toast

local Catalog = require(script.Parent.Catalog)
local Catching = require(script.Parent.Catching)
local Economy = require(script.Parent.Economy)
local ShortNumber = require(script.Parent.ShortNumber)
local Types = require(script.Parent.Types)

local Tier3Path = {}

export type Need = "kinds" | "rare"

Tier3Path.FLAG = "tier3Path"
Tier3Path.TIER = 2 -- the tier it helps from (to Tier 3)
Tier3Path.AREA = "park" -- where the stray waits
Tier3Path.SEARCH_STUDS = 120 -- a fitting free Park stray this near the landing is the one that waits
Tier3Path.SPAWN_SECONDS = 30 -- at most one stray brought in for a player this often, when none is near
Tier3Path.GIFT_MAX = 15000 -- the welcome gift's cap (Design's pick: Tier 3 still takes some play)
Tier3Path.RARITY = "Rare" :: Types.Rarity -- the rarity the Rares need asks for, and the waiting Rare's
Tier3Path.PATH_EVENT = "tier3_path" -- custom event as a stray starts waiting; field kind or rare
Tier3Path.TOPUP_EVENT = "tier3_topup" -- custom event, value the gift

local function tier3(): Types.TierDef?
	return Catalog.getTier(Tier3Path.TIER + 1)
end

function Tier3Path.kindsShort(profile: Types.PlayerProfile): number
	local def = tier3()
	if def == nil or Economy.tier(profile) ~= Tier3Path.TIER then
		return 0
	end
	return math.max(0, def.distinctCats - Economy.rankUpCats(profile.collection, profile.cats, def))
end

function Tier3Path.raresShort(profile: Types.PlayerProfile): number
	local def = tier3()
	if def == nil or Economy.tier(profile) ~= Tier3Path.TIER or def.needsRarity == nil then
		return 0
	end
	local need = def.needsRarityCount or 1
	return math.max(
		0,
		need - Economy.rankUpCatsAtLeast(profile.collection, def.needsRarity :: Types.Rarity)
	)
end

function Tier3Path.need(profile: Types.PlayerProfile): Need?
	if Tier3Path.kindsShort(profile) > 0 then
		return "kinds"
	elseif Tier3Path.raresShort(profile) > 0 then
		return "rare"
	end
	return nil
end

-- A free stray of `def` and `variant` may wait for this need: a plain coat of a kind the player has not got that
-- counts toward Tier 3, from the Park; for "rare", one of Rare or better (and never above Rare: the easy circle is
-- never handed to a Legendary).
function Tier3Path.fits(
	profile: Types.PlayerProfile,
	def: Types.CatDef,
	variant: string,
	need: Need
): boolean
	if def.area ~= Tier3Path.AREA or variant ~= "base" or profile.collection[def.id] ~= nil then
		return false
	end
	if not Economy.countsForRankUp(def.id) then
		return false
	end
	local rank = Catalog.rarityRank[def.rarity]
	local rare = Catalog.rarityRank[Tier3Path.RARITY]
	if rank == nil or rare == nil or rank > rare then
		return false
	end
	return need == "kinds" or Catching.rarityAtLeast(def.rarity, Tier3Path.RARITY)
end

-- Whether a plain Park kind of `rarity` that fits `need` is still to catch.
local function lacks(profile: Types.PlayerProfile, rarity: Types.Rarity, need: Need): boolean
	for _, def in Catalog.cats do
		if def.rarity == rarity and Tier3Path.fits(profile, def, "base", need) then
			return true
		end
	end
	return false
end

-- The rarity of the stray brought in when no fitting one is near: a Common for kinds, a Rare for the Rares. Review-QA
-- on #5049: with every Park Common owned the kinds ask a Rare (it counts as a new kind too), and with no fitting Park
-- kind left, nil (no stray is brought in; a spawned one could never fit and only filled the near points).
function Tier3Path.spawnRarity(profile: Types.PlayerProfile, need: Need): Types.Rarity?
	if need == "kinds" and lacks(profile, "Common", need) then
		return "Common"
	end
	if lacks(profile, Tier3Path.RARITY, need) then
		return Tier3Path.RARITY
	end
	return nil
end

-- The welcome gift's toast, coins with commas: "Welcome gift: +$15,000 toward Tier 3".
function Tier3Path.giftLine(gift: number): string
	return "Welcome gift: +$" .. ShortNumber.commas(gift) .. " toward Tier 3"
end

function Tier3Path.goalLine(profile: Types.PlayerProfile, narrow: boolean?): string?
	local kinds = Tier3Path.kindsShort(profile)
	if kinds > 0 then
		local more = if narrow then "" else "more "
		return string.format("Catch %d %snew kind%s", kinds, more, if kinds == 1 then "" else "s")
	end
	local rares = Tier3Path.raresShort(profile)
	if rares > 0 then
		return if rares == 1
			then "Catch 1 more Rare"
			else string.format("Catch %d more Rares", rares)
	end
	return nil
end

function Tier3Path.topUpFor(profile: Types.PlayerProfile, on: boolean): number
	local def = tier3()
	local paid: unknown = profile.stats.tier3TopUp
	if not on or def == nil or (type(paid) == "number" and paid > 0) then
		return 0
	end
	if Economy.tier(profile) ~= Tier3Path.TIER or Tier3Path.need(profile) ~= nil then
		return 0
	end
	return math.clamp(def.cost - profile.coins, 0, Tier3Path.GIFT_MAX)
end

return Tier3Path
