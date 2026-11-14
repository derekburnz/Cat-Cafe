--!strict
-- The Royal Cat Pack (#4261, Derek 2026-11-14: "make the cat king pack/royal cat (make it a pack) ... 199 for royal",
-- pure). The Royal Cat pass (Config.RoyalCatPassId) became a pack. It gives:
--   the Royal Cat (Duchess Marzipan)   ShopCats, given at join and on purchase while it is not home
--   Potion Pack S's set                3 Big Tip, 1 Swift, 1 Steady, given once (gift)
-- Everything is fixed (nothing random) and untradeable. The potions are given once per account by ShopCatService, at
-- join and when PassService learns of the pass, so players who bought the Royal Cat before it became a pack get them
-- on their next join; profile.onceBought[MARK] records it (kept by Products.sanitizeOnce). As KingPack.
--   contents() -> { Item }            the card's list, in order
--   due(profile, ownsPack) -> bool    whether the gift is still owed
--   gift(profile, ownsPack) -> potions?   marks the gift given; the potions to pay, nil if not due

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local RoyalPack = {}

export type Item = { kind: "cat" | "potions", id: string, name: string }

RoyalPack.PASS_KEY = "RoyalCatPassId"
RoyalPack.MARK = "royal_cat_pack" -- the onceBought key for the gift
RoyalPack.CAT = "duchess_marzipan"
RoyalPack.POTION_PRODUCT = "potion_pack_s"
RoyalPack.NAME = "Royal Cat Pack"

local CONTENTS: { Item } = {
	{ kind = "cat", id = RoyalPack.CAT, name = "Duchess Marzipan" },
	{ kind = "potions", id = RoyalPack.POTION_PRODUCT, name = "Potion Pack S" },
}
for _, item in CONTENTS do
	table.freeze(item)
end
table.freeze(CONTENTS)

function RoyalPack.passId(): number
	local id = (Config :: any)[RoyalPack.PASS_KEY]
	return if type(id) == "number" then id else 0
end

function RoyalPack.contents(): { Item }
	return CONTENTS
end

-- The potions the gift pays: Potion Pack S's set, copied.
function RoyalPack.potions(): { [string]: number }
	local product = Catalog.getProduct(RoyalPack.POTION_PRODUCT)
	return if product ~= nil then table.clone(product.prize.potions) else {}
end

-- Whether the gift is still owed: the player owns the pack and it has not been given.
function RoyalPack.due(profile: Types.PlayerProfile, ownsPack: boolean): boolean
	return ownsPack and RoyalPack.passId() ~= 0 and profile.onceBought[RoyalPack.MARK] ~= true
end

-- Marks the gift and returns the potions the caller pays now (no yield between), or nil when nothing is owed.
function RoyalPack.gift(profile: Types.PlayerProfile, ownsPack: boolean): { [string]: number }?
	if not RoyalPack.due(profile, ownsPack) then
		return nil
	end
	profile.onceBought[RoyalPack.MARK] = true
	return RoyalPack.potions()
end

return RoyalPack
