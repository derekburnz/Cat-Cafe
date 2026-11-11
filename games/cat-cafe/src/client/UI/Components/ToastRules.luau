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
--                                                     (a refused buy) still shows. #2729: also every line on CUT.
--                                                     #3080: and every green ("good") toast that is not on KEEP
--   oneLine(kind, text) -> boolean                     #2729: good and info toasts keep to one row and end in "…";
--                                                     a warning and a shout-out wrap so every word shows. #3205: so
--                                                     does a line with one of WRAP's phrases (the restart warning)

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

-- #3080 (Derek2 11-10: "way too much green bubble pop ups ITS ANNOYING AND BLOAT remove pretty much all of them left
-- catching cats rewards dropped etc") and #3054 ("whenever claiming something no need for a bubble saying exactly
-- what you claimed this goes for all types of rewards"): the rule turns round for the green ("good") toasts. Until
-- now one showed unless it was cut; now none shows unless its words are on this list, as Lua patterns. What stays is
-- the only word the player gets that something they paid for or sent really landed, and the one call to come
-- home. A catch, a claim, a reward, a drop, a level up, a placed piece and the like say nothing: the counters, the
-- cards and the world show them.
ToastRules.KEEP = {
	"^Thank you! ", -- ProductService: the receipt after a Robux purchase (a product, the Cafe Pass paid track)
	"^King Cat Pack: ", -- ShopCatService: the same, for the pack's game pass
	"Your working cats now earn ", -- StoreLogic.outfitThanks: the same, for the outfit passes
	"^Thanks! Your report was sent%.$", -- BugReport.Messages.sent: the report window only closes
	"^Trade done!", -- TradeLogic.doneLine: the trade window only closes, as it does for a cancelled trade
	"^New piece: ", -- FishMarket: a crate's result that landed with the window closed, so no reveal played
	" again: %+", -- the same, for a piece owned already
	"^Opened %d+ crates: ", -- the same, for Open all
	"^Your bait cat is here!", -- BaitService: a cat waits at the bowl while the player is out; they have to walk home
	"^It dropped! ", -- ShoveService: a shoved player dropped their cat; the shover has seconds to pick it up
	"^Owner test mode: ", -- OwnerTestService: the owner's own test grants, which nobody else sees
	"^Golden find! ", -- #3222 LawnService.giveDrop: a drop-only Golden lawn piece from a freed cat
	-- #3106 (Derek2 11-10, after two new players left in the tutorial: "maybe add those two buttons back"): a new
	-- player's first delivery and first cat. Each comes once: the server sends the second on the first check-in
	-- only, and UI.cannon.checkedIn sends the first only while the first walk-through is not done
	" is on its way to your cafe!$",
	"^Your first cat! ",
}

function ToastRules.kept(text: string): boolean
	for _, pattern in ToastRules.KEEP do
		if string.find(text, pattern) ~= nil then
			return true
		end
	end
	return false
end

-- #2600 (Derek2: "remove all the bought pop ups they just add more clutter"): the servers' "Bought ..." toasts from
-- the Day Cart, the Night Dealer (and its Buy all) and the Fish Market. #2729: and every line on CUT.
function ToastRules.quiet(text: string, kind: string?): boolean
	if kind == "warn" then
		return false
	end
	if kind == "good" then
		return not ToastRules.kept(text)
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
-- #3205 (Derek2 11-11: "the quick update in ... gets cut off"): the restart warning's early marks are calm info
-- toasts (#2720), and one row dropped their last words, "your cafe is saved". A line with one of these phrases
-- (plain, any case) wraps whatever its kind. shared/RestartNotice.text ends every warning with the first.
-- #3212: and an owner command's reply ("Owner test mode: Cafe Party started on all servers for 10 minutes").
ToastRules.WRAP = { "your cafe is saved", "owner test mode:" }

function ToastRules.oneLine(kind: string?, text: string?): boolean
	if text ~= nil then
		local lower = string.lower(text)
		for _, phrase in ToastRules.WRAP do
			if string.find(lower, phrase, 1, true) ~= nil then
				return false
			end
		end
	end
	return kind == nil or kind == "good" or kind == "info"
end

return ToastRules
