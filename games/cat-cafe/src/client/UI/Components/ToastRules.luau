--!strict
-- #2399 (Derek2 11-08: "there are way too many bubble pop ups in the middle top of screen especially for mobile like
-- got this much money/ someone caught this cat/you found or claimed this/ you caught this cat"): which toasts and
-- shout-outs still show. Pure, so the specs load it.
--   announce(rarity, now, lastAt, touch) -> boolean   a server shout-out: Legendary and better only, and on touch
--                                                     one every ANNOUNCE_GAP seconds below Mythical; one with no
--                                                     rarity (a rank up) or an unknown kind always shows
--   isRepeat(kind, now, lastAt) -> boolean            the same words again within REPEAT_SECONDS: dropped, except a
--                                                     warning (a refused press says why every time)
--   maxVisible(touch) -> number                        toasts on screen at once
--   quiet(text, kind) -> boolean                       #2600: a purchase confirmation ("Bought Tuna (40)"): dropped;
--                                                     the shop's button, the counts and the money say it. A warning
--                                                     (a refused buy) still shows

local ToastRules = {}

ToastRules.ANNOUNCE_MIN = "Legendary"
ToastRules.ANNOUNCE_GAP = 30
ToastRules.REPEAT_SECONDS = 10

local RANK: { [string]: number } = { Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythical = 5 }

function ToastRules.announce(rarity: string?, now: number, lastAt: number?, touch: boolean): boolean
	local rank = if rarity then RANK[rarity] else nil
	if rank == nil then
		return true
	end
	if rank < RANK[ToastRules.ANNOUNCE_MIN] then
		return false
	end
	if
		touch
		and rank < RANK.Mythical
		and lastAt ~= nil
		and now - lastAt < ToastRules.ANNOUNCE_GAP
	then
		return false
	end
	return true
end

function ToastRules.isRepeat(kind: string?, now: number, lastAt: number?): boolean
	if kind == "warn" or lastAt == nil then
		return false
	end
	return now - lastAt < ToastRules.REPEAT_SECONDS
end

function ToastRules.maxVisible(touch: boolean): number
	return if touch then 2 else 3
end

-- #2600 (Derek2: "remove all the bought pop ups they just add more clutter"): the servers' "Bought ..." toasts from
-- the Day Cart, the Night Dealer (and its Buy all) and the Fish Market.
function ToastRules.quiet(text: string, kind: string?): boolean
	return kind ~= "warn" and string.sub(text, 1, 7) == "Bought "
end

return ToastRules
