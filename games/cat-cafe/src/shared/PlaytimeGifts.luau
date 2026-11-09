--!strict
-- The like and favourite gifts (like-prompts.md section 2, #1947 with Set 10 Q3), pure: two thank-you gifts for time
-- played on the account (stats.playtimeSeconds plus the session), once each per account. The gift is for playing,
-- never for liking or favouriting: it is paid when the card is sent, before any button, and Close keeps it.
--   like at Config.LikeGiftMinutes: LikeGiftIncomeMinutes of the cafe's income and a Tip Potion
--   fav at Config.FavGiftMinutes: FavGiftIncomeMinutes of income and a Tip, a Lucky and a Swift Potion
-- The like comes first. A save past both marks pays the like, then the favourite GAP_SECONDS later in the session,
-- so the two cards never stack.
--   due(profile, played) -> Kind?    the gift to pay now, if any
--   prize(kind) -> IndexPrize        what it pays (Payout)
--   mark(profile, kind)              paid: never again on this account
--   report(raw) -> (Kind?, button?)  a playtime_gift report "<kind>:<button>" read, analytics only

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local PlaytimeGifts = {}

export type Kind = "like" | "fav"

local KINDS: { Kind } = { "like", "fav" }
table.freeze(KINDS)
PlaytimeGifts.KINDS = KINDS
PlaytimeGifts.BUTTONS = table.freeze({ "like", "favourite", "close", "gotit" }) :: { string } -- playtime_gift's buttons
-- (#2705: "gotit" is the like card's one button on touch, where Roblox has no in-game like prompt)
PlaytimeGifts.GAP_SECONDS = 60

-- The gift due at `played` seconds of play on the account, like before fav, or nil.
function PlaytimeGifts.due(profile: Types.PlayerProfile, played: number): Kind?
	local due: Kind? = nil
	if not profile.likeGift then
		if played >= Config.LikeGiftMinutes * 60 then
			due = "like"
		end
	elseif not profile.favGift and played >= Config.FavGiftMinutes * 60 then
		due = "fav"
	end
	return due
end

function PlaytimeGifts.prize(kind: Kind): Types.IndexPrize
	if kind == "like" then
		return { coinSeconds = Config.LikeGiftIncomeMinutes * 60, potions = { tip_potion = 1 } }
	end
	return {
		coinSeconds = Config.FavGiftIncomeMinutes * 60,
		potions = { tip_potion = 1, lucky_potion = 1, swift_potion = 1 },
	}
end

function PlaytimeGifts.mark(profile: Types.PlayerProfile, kind: Kind)
	if kind == "like" then
		profile.likeGift = true
	else
		profile.favGift = true
	end
end

-- A playtime_gift report's value read: (kind, button) when both are known, else nil.
function PlaytimeGifts.report(raw: unknown): (Kind?, string?)
	if type(raw) ~= "string" or #raw > 16 then
		return nil, nil
	end
	local kind, button = string.match(raw, "^(%a+):(%a+)$")
	if kind ~= "like" and kind ~= "fav" then
		return nil, nil
	end
	if button == nil or table.find(PlaytimeGifts.BUTTONS, button) == nil then
		return nil, nil
	end
	local read: Kind = if kind == "like" then "like" else "fav"
	return read, button
end

return PlaytimeGifts
