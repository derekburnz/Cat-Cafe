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
--                                                     (a refused buy) still shows. #2729: also every line on CUT
--   oneLine(kind) -> boolean                           #2729: good and info toasts keep to one row and end in "…";
--                                                     a warning and a shout-out wrap so every word shows

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

-- #2729 (Derek2 11-09: "look through the pop up bubbles and remove all the extra ones wayy to much clutter"): the
-- lines that only repeat what the screen already shows, or nudge, as Lua patterns. The rule: a toast stays when the
-- player has to act on it, or it is the only word on a refusal, a reward, a purchase or an unlock.
ToastRules.CUT = {
	"^New quest: ", -- QuestService: the goal card and the Quests tile show it
	" at the Fish Market!$", -- "A cheap X at the Fish Market!" and its kin: the Market tile's dot says it
	"Night bait! Food in your bowl", -- a tip; the night banner says it
	"^Bait food is at the Corner Shop now", -- an old move notice
	" is on its way to your cafe!$", -- the cannon's check-in (#2727): the flight shows it
	"^You dropped [^%.]+%.$", -- the cat leaving your arms shows it ("... It's walking home." stays)
	" ran back to the ", -- the same
	"^You got tackled!$", -- nothing happened to you
}

-- #2600 (Derek2: "remove all the bought pop ups they just add more clutter"): the servers' "Bought ..." toasts from
-- the Day Cart, the Night Dealer (and its Buy all) and the Fish Market. #2729: and every line on CUT.
function ToastRules.quiet(text: string, kind: string?): boolean
	if kind == "warn" then
		return false
	end
	if string.sub(text, 1, 7) == "Bought " then
		return true
	end
	for _, pattern in ToastRules.CUT do
		if string.find(text, pattern) ~= nil then
			return true
		end
	end
	return false
end

-- #2729 (Derek2 11-09: "big claims of index and quests cap at one line and put … explaining ads too much clutter"):
-- a good or info toast (a claim, a reward, a reply) is one row that ends in "…"; the whole list stays on its card in
-- the Index, Quests or Pass window. A warning says why a press failed and a shout-out names a player, so those wrap.
function ToastRules.oneLine(kind: string?): boolean
	return kind == nil or kind == "good" or kind == "info"
end

return ToastRules
