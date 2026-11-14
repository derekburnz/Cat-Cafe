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
-- #3420 (the 2026-11-12 launch gift): the gift shows as a banner (Effects/EventBanner) in place of the toast, and a
-- notice banner shows once in the NOTICE_SECONDS before `from`. The server sends UpdateGiftNotice(kind, fish, spins,
-- secondsLeft) and the client builds the words here; the toast stays the fallback when no banner can show.
--   soon(redeemed, gift, now) -> number?   seconds until an unpaid gift, while inside the notice window; else nil
--   banner(kind, fish, spins, secondsLeft) -> Banner?   the banner's title and lines; nil for bad arguments

-- #3535 (Derek 2026-11-12, the Friday 2026-11-13 update: "instead of golden fish giveaway 3 different golden
-- crates"): a gift may carry `crates` (crate id -> count, banked for the Golden Fish Market like any prize's). The
-- id "highest_golden" is the golden crate of the best area the player's tier has opened; when that is a crate the
-- gift already names (a Tier 1 player's is the Alleyway's), it becomes a Classic Golden Crate instead, so nobody is
-- handed a crate of an area they cannot open. Config.UpdateGiftNext is the gift after Config.UpdateGift: the one
-- before keeps paying until the next one's `from`, then the next takes over (`pick`), with nothing carried over.
--   pick(gift, nextGift, now) -> (Gift?, Gift?)   the gift that pays at `now`, and the one whose notice may show
--   crateCount(gift) -> number                     how many crates it carries in all

local Prizes = require(script.Parent.Prizes)
local Types = require(script.Parent.Types)

local UpdateGift = {}

UpdateGift.PREFIX = "gift"
UpdateGift.SPARE_CRATE = "classic_golden_crate" -- in place of a "highest_golden" the gift already names

-- #3779: `to` (os.time(), optional) ends a gift: from then on it pays nobody new and gives no notice. The launch gift
-- had no end, so every account that joined for the first time since kept getting its 100 fish.
export type Gift = {
	id: string,
	from: number,
	fish: number,
	spins: number,
	crates: { [string]: number }?,
	to: number?,
	traitTokens: number?, -- Config.Giveaways only: Trait Tokens banked for the Mystic Pool (PlaytimeGiftService)
}

-- The gift that pays at `now` and the gift whose "a gift is coming" notice may show: `nextGift` for both once its
-- `from` has come, else `gift` pays and `nextGift` (when there is one) gives notice.
-- #3497: both gifts may lie ahead (Friday's crates, then Saturday's weekly gift, set in one publish so the servers
-- of Friday's restart already know Saturday's). Until `gift` starts, the notice is its own.
function UpdateGift.pick(gift: Gift?, nextGift: Gift?, now: number): (Gift?, Gift?)
	if nextGift == nil then
		return gift, gift
	elseif now >= nextGift.from then
		return nextGift, nextGift
	elseif gift ~= nil and now < gift.from then
		return gift, gift
	end
	return gift, nextGift
end

function UpdateGift.crateCount(gift: Gift): number
	local count = 0
	if gift.crates ~= nil then
		for _, n in gift.crates do
			count += n
		end
	end
	return count
end

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
	if gift.to ~= nil and now >= gift.to then
		return false -- #3779: the gift is over
	end
	return redeemed[UpdateGift.key(gift.id)] == nil
end

UpdateGift.NOTICE_SECONDS = 300
UpdateGift.MAX_FISH = 1000 -- a banner never shows more than this (the client checks what it is sent)
UpdateGift.MAX_SPINS = 10
UpdateGift.MAX_CRATES = 10

export type NoticeKind = "soon" | "paid"
export type Banner = { title: string, lines: { string } }

function UpdateGift.soon(redeemed: { [string]: number }, gift: Gift?, now: number): number?
	if gift == nil or type(gift.id) ~= "string" or gift.id == "" then
		return nil
	end
	local left = gift.from - now
	if gift.to ~= nil and gift.to <= gift.from then
		return nil -- #3779: a gift that ends before it starts never pays, so it promises nothing
	end
	if
		left <= 0
		or left > UpdateGift.NOTICE_SECONDS
		or redeemed[UpdateGift.key(gift.id)] ~= nil
	then
		return nil
	end
	return left
end

local function whole(value: unknown, most: number): number?
	if
		type(value) ~= "number"
		or value ~= value
		or value ~= math.floor(value)
		or value < 0
		or value > most
	then
		return nil
	end
	return value
end

-- `crates` is how many golden crates the gift carries (#3535); nil, an older call's, reads as none.
function UpdateGift.banner(
	kind: unknown,
	fish: unknown,
	spins: unknown,
	secondsLeft: unknown,
	crates: unknown?
): Banner?
	local fishCount = whole(fish, UpdateGift.MAX_FISH)
	local spinCount = whole(spins, UpdateGift.MAX_SPINS)
	local crateCount = if crates == nil then 0 else whole(crates, UpdateGift.MAX_CRATES)
	if
		fishCount == nil
		or spinCount == nil
		or crateCount == nil
		or fishCount + spinCount + crateCount == 0
	then
		return nil
	end
	local parts: { string } = {}
	if fishCount > 0 then
		table.insert(parts, tostring(fishCount) .. " golden fish")
	end
	if spinCount > 0 then
		table.insert(parts, tostring(spinCount) .. (if spinCount == 1 then " spin" else " spins"))
	end
	if crateCount > 0 then
		table.insert(
			parts,
			tostring(crateCount) .. (if crateCount == 1 then " golden crate" else " golden crates")
		)
	end
	local what = table.concat(parts, " + ")
	if kind == "paid" then
		return { title = "A gift for everyone!", lines = { "+" .. what, "Thanks for playing!" } }
	end
	if kind ~= "soon" then
		return nil
	end
	if type(secondsLeft) ~= "number" or secondsLeft ~= secondsLeft then
		return nil
	end
	if secondsLeft <= 0 or secondsLeft > UpdateGift.NOTICE_SECONDS then
		return nil
	end
	local minutes = math.max(1, math.ceil(secondsLeft / 60))
	return {
		title = "A gift is coming!",
		lines = {
			what .. " for everyone",
			string.format("in %d minute%s", minutes, if minutes == 1 then "" else "s"),
		},
	}
end

-- What it pays a player at cafe tier `tier` (1 when not given: a gift without crates pays the same at any tier).
function UpdateGift.prize(gift: Gift, tier: number?): Types.IndexPrize
	local prize: Types.IndexPrize = {}
	if gift.fish > 0 then
		prize.fish = gift.fish
	end
	if gift.spins > 0 then
		prize.spins = gift.spins
	end
	if gift.crates ~= nil and next(gift.crates) ~= nil then
		local crates: { [string]: number } = {}
		for id, count in gift.crates do
			if id ~= Prizes.HIGHEST_GOLDEN then
				crates[id] = (crates[id] or 0) + count
			end
		end
		local best = gift.crates[Prizes.HIGHEST_GOLDEN]
		if best ~= nil and best > 0 then
			local id = Prizes.crateFor(Prizes.HIGHEST_GOLDEN, tier or 1)
			if id == nil or gift.crates[id] ~= nil then
				id = UpdateGift.SPARE_CRATE
			end
			crates[id :: string] = (crates[id :: string] or 0) + best
		end
		prize.crates = crates
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
	local crates = UpdateGift.crateCount(gift)
	if crates > 0 then
		table.insert(
			parts,
			tostring(crates) .. (if crates == 1 then " golden crate" else " golden crates")
		)
	end
	return "Update gift! " .. table.concat(parts, " + ")
end

return UpdateGift
