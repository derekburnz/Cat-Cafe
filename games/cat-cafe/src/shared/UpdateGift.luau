--!strict
-- The Saturday update gift (#2997, retention-ideas.md section 5f; Derek2 2026-11-10 said yes to idea 12). Content
-- updates publish on Saturdays at 17:00 UTC, and each one carries Config.UpdateGift with a new id: every player gets
-- its golden fish and spin once, paid on their first join (or the next second, if they are already in) from `from`
-- on. No claim button and no countdown.
-- Kept with no new save field, so it needed no save version step or restart (Derek2 2026-11-11: no restarts): the
-- gift paid is marked in the save's codesRedeemed under key(id), "gift" and the id's digits ("gift20261114"), which
-- every server since version 9 keeps as it is. The Store's "Codes you've used" list leaves these keys out
-- (CodeEntry.used), and no code in Catalog.codes starts with PREFIX, so a real code can never be taken for one.
--   key(id) -> string               the codesRedeemed key the gift `id` ("2026-11-14") is marked under
--   due(redeemed, gift, now) -> bool  the gift is live at `now` (os.time()) and not paid to this account yet
--   prize(gift) -> IndexPrize        what it pays
--   words(gift) -> string            the toast: "Update gift! 🐟 15 + 1 spin"

local Types = require(script.Parent.Types)

local UpdateGift = {}

UpdateGift.PREFIX = "gift"

export type Gift = { id: string, from: number, fish: number, spins: number }

function UpdateGift.key(id: string): string
	return UpdateGift.PREFIX .. string.gsub(id, "%W", "")
end

function UpdateGift.isKey(id: unknown): boolean
	return type(id) == "string" and string.sub(id, 1, #UpdateGift.PREFIX) == UpdateGift.PREFIX
end

function UpdateGift.due(redeemed: { [string]: number }, gift: Gift?, now: number): boolean
	if gift == nil or type(gift.id) ~= "string" or gift.id == "" or now < gift.from then
		return false
	end
	return redeemed[UpdateGift.key(gift.id)] == nil
end

function UpdateGift.prize(gift: Gift): Types.IndexPrize
	local prize: Types.IndexPrize = {}
	if gift.fish > 0 then
		prize.fish = gift.fish
	end
	if gift.spins > 0 then
		prize.spins = gift.spins
	end
	return prize
end

function UpdateGift.words(gift: Gift): string
	local parts: { string } = {}
	if gift.fish > 0 then
		table.insert(parts, "🐟 " .. tostring(gift.fish))
	end
	if gift.spins > 0 then
		table.insert(parts, tostring(gift.spins) .. (if gift.spins == 1 then " spin" else " spins"))
	end
	return "Update gift! " .. table.concat(parts, " + ")
end

return UpdateGift
