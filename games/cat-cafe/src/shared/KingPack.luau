--!strict
-- The King Cat Pack bundle (#1822, pure): what the pack holds, what the Store card's "worth" line adds up, and the
-- one-time gift of its potions and booth. The pack (Config.KingPackPassId) gives:
--   the King Cat (King Croissant)        ShopCats, given at join and on purchase while it is not home
--   the Royal Crest sign                 SignStyles (passKey), looked up each session
--   the Grand look                       Looks (the Grand theme's alsoKey), a look only: the Grand Cafe pass's money
--                                        and job slot stay on GrandThemePassId (Economy)
--   the Royal Velvet Booth               Catalog.passDecor (pack "King Cat Pack"): looks only, can't be bought,
--                                        traded or sold, counts for no quest or Index page
--   Potion Pack M's set                  5 Big Tip, 3 Swift, 2 Steady, given once (gift)
-- Everything is fixed (nothing random) and untradeable. The booth and potions are given once per account by
-- ShopCatService, at join and when PassService learns of the pass, so players who bought the pack before it held
-- them get them on their next join; profile.onceBought[MARK] records it (kept by Products.sanitizeOnce).
-- The worth line counts only what is also sold alone: the King Cat alone pass and Potion Pack M, with their prices
-- read at runtime (MarketplaceService), so it never claims a value for the looks-only pieces.
--   contents() -> { Item }           the card's list, in order
--   worthRefs() -> ({ Ref }, ready)  what to price for the worth line; ready is false while one is not made (0)
--   due(profile, ownsPack) -> bool   whether the gift is still owed
--   gift(profile) -> potions?        marks the gift given and owns the booth; the potions to pay, nil if not due

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local KingPack = {}

export type ItemKind = "cat" | "sign" | "theme" | "decor" | "potions"
export type Item = { kind: ItemKind, id: string, name: string }
export type Ref = { infoType: "GamePass" | "Product", id: number }

KingPack.PASS_KEY = "KingPackPassId"
KingPack.MARK = "king_cat_pack" -- the onceBought key for the gift
KingPack.CAT = "king_croissant"
KingPack.SIGN = "royal_crest"
KingPack.THEME = "grand"
KingPack.DECOR = "decor_royal_velvet_booth"
KingPack.POTION_PRODUCT = "potion_pack_m" -- the pack's potions are this product's set, and its price is in the worth

local CONTENTS: { Item } = {
	{ kind = "cat", id = KingPack.CAT, name = "King Croissant" },
	{ kind = "sign", id = KingPack.SIGN, name = "Royal Crest sign" },
	{ kind = "theme", id = KingPack.THEME, name = "Grand look" },
	{ kind = "decor", id = KingPack.DECOR, name = "Royal Velvet Booth" },
	{ kind = "potions", id = KingPack.POTION_PRODUCT, name = "Potion Pack M" },
}
for _, item in CONTENTS do
	table.freeze(item)
end
table.freeze(CONTENTS)

function KingPack.passId(): number
	local id = (Config :: any)[KingPack.PASS_KEY]
	return if type(id) == "number" then id else 0
end

function KingPack.contents(): { Item }
	return CONTENTS
end

-- The potions the gift pays: Potion Pack M's set, copied.
function KingPack.potions(): { [string]: number }
	local product = Catalog.getProduct(KingPack.POTION_PRODUCT)
	return if product ~= nil then table.clone(product.prize.potions) else {}
end

-- What the worth line prices: the King Cat alone pass and the Potion Pack M product. `ready` is false while either
-- is not made (id 0), and the card then shows no worth line.
function KingPack.worthRefs(): ({ Ref }, boolean)
	local catId = (Config :: any).KingCatPassId
	local potionId = Config.ProductIds[KingPack.POTION_PRODUCT]
	local refs: { Ref } = {}
	local ready = true
	if type(catId) == "number" and catId ~= 0 then
		local ref: Ref = { infoType = "GamePass", id = catId :: number }
		table.insert(refs, ref)
	else
		ready = false
	end
	if type(potionId) == "number" and potionId ~= 0 then
		local ref: Ref = { infoType = "Product", id = potionId }
		table.insert(refs, ref)
	else
		ready = false
	end
	return refs, ready
end

-- Whether the gift is still owed: the player owns the pack and it has not been given.
function KingPack.due(profile: Types.PlayerProfile, ownsPack: boolean): boolean
	return ownsPack and KingPack.passId() ~= 0 and profile.onceBought[KingPack.MARK] ~= true
end

-- Gives the booth and marks the gift, in one step, and returns the potions the caller pays now (no yield between),
-- or nil when nothing is owed. The booth is owned, not placed; the cafe shows it on a decor spot like the Cafe Pass
-- decor once the player puts it in use.
function KingPack.gift(profile: Types.PlayerProfile, ownsPack: boolean): { [string]: number }?
	if not KingPack.due(profile, ownsPack) then
		return nil
	end
	profile.onceBought[KingPack.MARK] = true
	profile.decorOwned[KingPack.DECOR] = true
	return KingPack.potions()
end

return KingPack
