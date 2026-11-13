--!strict
-- The welcome back gift (#3772, come-back-tomorrow.md section 2a): once per account, on the first join on a later UTC
-- day than the account's first day, a golden crate of the best open area. It never expires. Only accounts first seen
-- on or after Config.ReturnGiftFromDay can get it, so players from before it shipped are not all paid at once.
-- Behind the switch FLAG (LiveFlags.OFF_BY_DEFAULT). Pure, so the specs load it.
-- No new save field and no save version step (Gameplay-Engineer's advice on #3772): the gift paid is marked in the
-- save's codesRedeemed under KEY, which every server since version 9 keeps as it is, so a player hopping servers
-- during a rollout can never take it twice. KEY starts with UpdateGift.PREFIX ("gift"), so the Store's "Codes you've
-- used" list leaves it out (CodeEntry.used), and it has letters where an update gift's key has only a date's digits
-- (UpdateGift.key), so the two never meet. No code in Catalog.codes starts with "gift".
--   due(profile, now) -> boolean       pay it now: eligible, and today is a later UTC day than the first day
--   waiting(profile, now) -> boolean   eligible and still the first day, so tomorrow it pays (the recap's line)
--   daysSince(profile, now) -> number  whole UTC days since the first day, for return_gift_paid

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local ReturnGift = {}

ReturnGift.FLAG = "returnGift"
ReturnGift.KEY = "giftreturn"
ReturnGift.REASON = "return_gift" -- Payout's reason
ReturnGift.TOAST = "Welcome back gift! " -- ToastRules.KEEP lets this green toast through

local DAY_SECONDS = 86400

-- A golden crate of the best open area, resolved at payout (Prizes.crateFor), banked like any crate.
function ReturnGift.prize(): Types.IndexPrize
	return { crates = { highest_golden = 1 } }
end

local function eligible(profile: Types.PlayerProfile): boolean
	local first = profile.telemetry.firstDay
	return first > 0
		and first >= Config.ReturnGiftFromDay
		and profile.codesRedeemed[ReturnGift.KEY] == nil
end

function ReturnGift.due(profile: Types.PlayerProfile, now: number): boolean
	return eligible(profile) and now // DAY_SECONDS > profile.telemetry.firstDay
end

function ReturnGift.waiting(profile: Types.PlayerProfile, now: number): boolean
	return eligible(profile) and now // DAY_SECONDS == profile.telemetry.firstDay
end

function ReturnGift.daysSince(profile: Types.PlayerProfile, now: number): number
	return math.max(0, now // DAY_SECONDS - profile.telemetry.firstDay)
end

return ReturnGift
