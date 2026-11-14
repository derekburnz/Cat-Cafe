--!strict
-- #4174 (Derek 2026-11-14: suggest the Starter Bundle on screen once after 10 to 15 minutes of play, with no UI
-- issues on any device; Growth-Agent's monetization-and-home-recs-2026-11-14.md). Behind the `starterSuggest` switch.
--   * Once a session, at a random moment MIN_SECONDS to MAX_SECONDS into it, the slide-in card (Screens/AskCard)
--     names the Starter Bundle with its live Robux price and one Buy button; its X shows from the first frame and it
--     slides away by itself after SHOW_SECONDS.
--   * Never for a player who owns it, inside the account's quiet start (shared/QuietStart.ATTRIBUTE), before the
--     tutorial's end, or while anything else is over the screen (a catch, a rescue, a cutscene, a window, an ask, a
--     toast); it waits for a clear moment until the session ends.
--   * A close, a run out, a buy or a declined prompt ends it for the session. No countdown, no "only X left".
-- Pure, so the cloud specs check it; the client reads the switch, the clocks and the screen.

local StarterSuggest = {}

StarterSuggest.FLAG = "starterSuggest"
StarterSuggest.MIN_SECONDS = 600
StarterSuggest.MAX_SECONDS = 900
StarterSuggest.SHOW_SECONDS = 6
StarterSuggest.SOURCE = "starter_suggest" -- PassShop.prompt's source, so purchase_source counts its buys (#4176)
StarterSuggest.TELEMETRY = "starter_suggest" -- TelemetryReport name; values OUTCOMES
-- shown, then one of: closed (the X), ignored (it ran out), buy (Buy pressed), hidden (something took the card)
StarterSuggest.OUTCOMES = { "shown", "closed", "ignored", "buy", "hidden" }
StarterSuggest.TITLE = "Starter Bundle: a head start for your cafe"

-- The session second the card is due at, for a roll in [0, 1).
function StarterSuggest.dueAt(roll: number): number
	local r = math.clamp(roll, 0, 1)
	return math.floor(
		StarterSuggest.MIN_SECONDS + r * (StarterSuggest.MAX_SECONDS - StarterSuggest.MIN_SECONDS)
	)
end

export type Moment = {
	on: boolean, -- the switch
	done: boolean, -- already shown (or ended) this session
	played: number, -- seconds into this session
	dueAt: number, -- StarterSuggest.dueAt's answer for this session
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
	if m.played < m.dueAt then
		return false
	end
	if type(m.quietUntil) == "number" and m.now < m.quietUntil then
		return false
	end
	return m.tutorialDone and m.clear
end

-- The Buy button's words for a price in Robux.
function StarterSuggest.buyLabel(robux: number): string
	return "Buy  R$ " .. tostring(math.floor(robux))
end

return StarterSuggest
