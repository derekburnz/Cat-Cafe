--!strict
-- Rare moments (F89, luck-and-rare-moments.md section 2), pure: which secured cats play the big pull card and which
-- the first Epic's smaller one, which secures and crate pieces toast the server, and the toast's words. "Secured" is
-- a cat checked in (carried home, at a camp, or a rescue) or a bait cat tamed. The server's RareMomentService sends
-- SecuredRare and FoundRareDecor from these; the UI, Effects, Animation and Audio play them.
--   card(rarity, variant, hadEpicOrBetter) -> Card?   "big", "first_epic" or nil
--   toasts(rarity)                                     the server-wide toast's rarities, Legendary and Mythical
--   decorToasts(rarity)                                a crate piece's toast, Mythical only
--   ownsEpicOrBetter(collection)                       for the first Epic: what the collection held before
--   how(method)                                        rare_secured's "catch", "bait" or "rescue"
--   decorText(name, decorName)                         "Sam found the Mythical Midnight Sky!"

local Catalog = require(script.Parent.Catalog)
local Types = require(script.Parent.Types)

local RareMoments = {}

-- At most one server toast a player a minute, cats and crate pieces together (sections 2a and 2b).
RareMoments.TOAST_SECONDS = 60

-- "big": the 2.4 s big pull for a Legendary, a Mythical or a gold Epic or better, and every rainbow cat (F99);
-- "first_epic": the smaller card for the first Epic a player ever secures.
export type Card = "big" | "first_epic"

local function rank(rarity: string): number
	return Catalog.rarityRank[rarity] or 0
end

function RareMoments.card(rarity: Types.Rarity, variant: string?, hadEpicOrBetter: boolean): Card?
	if variant == "rainbow" then
		return "big"
	end
	if
		rank(rarity) >= rank("Legendary") or (variant == "gold" and rank(rarity) >= rank("Epic"))
	then
		return "big"
	end
	if rarity == "Epic" and not hadEpicOrBetter then
		return "first_epic"
	end
	return nil
end

function RareMoments.toasts(rarity: Types.Rarity): boolean
	return rank(rarity) >= rank("Legendary")
end

function RareMoments.decorToasts(rarity: string): boolean
	return rarity == "Mythical"
end

-- Whether `collection` (catId -> count) holds any cat of Epic or better, gift cats included.
function RareMoments.ownsEpicOrBetter(collection: { [string]: number }): boolean
	for catId, count in collection do
		local def = Catalog.getCat(catId)
		if
			def ~= nil
			and type(count) == "number"
			and count > 0
			and rank(def.rarity) >= rank("Epic")
		then
			return true
		end
	end
	return false
end

function RareMoments.how(method: Types.CatchMethod): string
	if method == "bait" then
		return "bait"
	elseif method == "rescue" then
		return "rescue"
	end
	return "catch"
end

function RareMoments.decorText(playerName: string, decorName: string): string
	return string.format("%s found the Mythical %s!", playerName, decorName)
end

return RareMoments
