--!strict
-- #4174 (Derek 2026-11-14: suggest the Starter Bundle on screen once after 10 to 15 minutes of play, with no UI
-- issues on any device; Growth-Agent's monetization-and-home-recs-2026-11-14.md). Behind the `starterSuggest` switch.
--   * #4438 (zero-sales dig, Derek 2026-11-15: 4,688 of about 5,300 sessions started at Tier 1, minutes into a first
--     visit): no longer on a 10 to 15 minute timer. It comes at one of two moments: RANK_SETTLE seconds after the
--     player ranks up to Tier 2 or higher in this session, or RETURN_SETTLE seconds into a session on a later UTC day
--     than the account's first (QuietStart.DAY_ATTRIBUTE). A Tier 1 first-day player never sees it.
--   * Once a session, at that moment, the slide-in card (Screens/AskCard)
--     names the Starter Bundle with its picture, a line, its live Robux price and one Buy button; its X shows from the
--     first frame and it stays until Buy or the X (Derek 2026-11-14: "stays forever on screen until X"), no timer.
--   * Never for a player who owns it, inside the account's quiet start (shared/QuietStart.ATTRIBUTE), before the
--     tutorial's end, or while anything else is over the screen (a catch, a rescue, a cutscene, a window, an ask, a
--     toast); it waits for a clear moment until the session ends.
--   * A close, a run out, a buy or a declined prompt ends it for the session. No countdown, no "only X left".
-- Pure, so the cloud specs check it; the client reads the switch, the clocks and the screen.

local StarterSuggest = {}

StarterSuggest.FLAG = "starterSuggest"
StarterSuggest.RANK_SETTLE = 45 -- #4438: seconds after a rank up (past its spotlight and toasts)
StarterSuggest.RANK_TIER = 2 -- #4438: the rank up that counts reaches this tier or higher
StarterSuggest.RETURN_SETTLE = 120 -- #4438: seconds into a session on a later day than the account's first
StarterSuggest.DAY_SECONDS = 86400
StarterSuggest.PICTURE = "rbxassetid://125781962090599" -- Design-Agent's card art (#4194)
StarterSuggest.LINE = "Epic cat Sprinkles, 2x Money and 20 potions" -- fits every phone (Design-Agent)
StarterSuggest.SOURCE = "starter_suggest" -- PassShop.prompt's source, so purchase_source counts its buys (#4176)
StarterSuggest.TELEMETRY = "starter_suggest" -- TelemetryReport name; values OUTCOMES
-- shown, then one of: closed (the X), ignored (kept for old reports; it no longer runs out), buy (Buy pressed),
-- hidden (something took the card)
StarterSuggest.OUTCOMES = { "shown", "closed", "ignored", "buy", "hidden" }
StarterSuggest.TITLE = "Starter Bundle" -- Design-Agent: beside the picture on a phone only the short title fits

export type Moment = {
	on: boolean, -- the switch
	done: boolean, -- already shown (or ended) this session
	played: number, -- seconds into this session
	rankedAt: number?, -- #4438: `played` when the player ranked up to RANK_TIER or higher this session, nil before
	firstDay: unknown, -- #4438: the player's QuietStart.DAY_ATTRIBUTE (UTC day number of the account's first join)
	owned: boolean?, -- the server's word that the bundle is bought; nil (no word yet) counts as owned
	quietUntil: unknown, -- the player's QuietStart.ATTRIBUTE
	now: number, -- the server's clock
	tutorialDone: boolean,
	clear: boolean, -- nothing else over the screen (the tips' quiet moment, no purchase prompt)
	priced: boolean, -- Roblox's price is known and it is for sale
}

-- Whether the card shows now.
function StarterSuggest.due(m: Moment): boolean
	if not m.on or m.done or m.owned ~= false or not m.priced then
		return false
	end
	local ranked = m.rankedAt ~= nil
		and m.played >= (m.rankedAt :: number) + StarterSuggest.RANK_SETTLE
	local day = math.floor(m.now / StarterSuggest.DAY_SECONDS)
	local returned = type(m.firstDay) == "number"
		and m.firstDay > 0
		and day > m.firstDay
		and m.played >= StarterSuggest.RETURN_SETTLE
	if not ranked and not returned then
		return false
	end
	if type(m.quietUntil) == "number" and m.now < m.quietUntil then
		return false
	end
	return m.tutorialDone and m.clear
end

-- The Buy button's words for a price in Robux.
function StarterSuggest.buyLabel(robux: number): string
	return "Buy R$" .. tostring(math.floor(robux)) -- as the money button writes R$25
end

return StarterSuggest
