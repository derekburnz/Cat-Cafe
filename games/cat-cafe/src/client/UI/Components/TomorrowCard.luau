--!strict
-- #3951 (Design-Agent's spec of 2026-11-14 on the issue; Growth's Nov 17 read: day 1 return was 6.54%, 4.70% and
-- 2.74% for Nov 12, 13 and 14, under the 6% line, so it is built): the come back tomorrow card. Most new players are
-- gone by minute 5 and the minute 6 line (#4626, Components/ReturnHookLine) is a 6 s toast that is easy to miss, so a
-- new account's first UTC day gets one small card that says tomorrow's welcome back golden crate is waiting.
--   * Behind the tomorrowCard switch (ReturnHook.CARD_FLAG, off by default).
--   * Only on the account's first UTC day (QuietStart.DAY_ATTRIBUTE is today) and only while the server's early
--     pick (PlayerState.tomorrowHook) is "gift", the one thing that is certain tomorrow for a first-day player.
--   * Once a session, at the first calm second after the walk-through and the first 5 minutes hold ends
--     (UI.firstCat.tutorial, QuietStart.EARLY_SECONDS) and at least SETTLE_SECONDS into the session; one pop-up
--     every 5 minutes (UI.popPace). Never over a window, a card, a catch, a cutscene or a roll.
--   * The slide-in ask card with the Classic golden crate's picture, the reason as its title (a phone hides the
--     line, so the title carries it on two lines), one OK button and the X, no timer, nothing to buy.
--   * Shown, the minute 6 line is left out that session (same words twice is noise). The recap at minute 8 stays.
-- Pure, so the specs load it.
--   due(moment) -> boolean   whether the card shows now

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReturnHook = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ReturnHook"))

local TomorrowCard = {}

TomorrowCard.FLAG = ReturnHook.CARD_FLAG
TomorrowCard.OUTCOMES = ReturnHook.CARD_OUTCOMES
TomorrowCard.KIND = "gift" -- the only early pick it names
TomorrowCard.SETTLE_SECONDS = 30 -- seconds into a session first, so a same-day rejoin is not met by it at once
TomorrowCard.DAY_SECONDS = 86400
TomorrowCard.TITLE = "Golden crate tomorrow!" -- short: on a phone it sits right of the picture
TomorrowCard.LINE = "Come back tomorrow and it is yours." -- desktop and tablet only (a phone leaves the line out)
TomorrowCard.BUTTON = "OK!"
TomorrowCard.PICTURE = "rbxassetid://115785859034580" -- ShopIcons Crate_Classic_Gold (never the banned wooden crate)

export type Moment = {
	on: boolean, -- the switch
	shown: boolean, -- the card (or the minute 6 line) already showed this session
	kind: string?, -- PlayerState.tomorrowHook's kind (ReturnHookLine.kind), nil with none
	firstDay: unknown, -- the player's QuietStart.DAY_ATTRIBUTE
	now: number, -- the server's clock
	played: number, -- seconds into this session
	held: boolean, -- the walk-through, first cat or first 5 minutes hold is on
	busy: boolean, -- something is over the screen, or the 5 minute pop-up pace is used
}

-- Whether the account was first seen today (UTC).
function TomorrowCard.firstDay(firstDay: unknown, now: number): boolean
	return type(firstDay) == "number"
		and firstDay > 0
		and math.floor(now / TomorrowCard.DAY_SECONDS) == firstDay
end

function TomorrowCard.due(m: Moment): boolean
	return m.on
		and not m.shown
		and m.kind == TomorrowCard.KIND
		and TomorrowCard.firstDay(m.firstDay, m.now)
		and m.played >= TomorrowCard.SETTLE_SECONDS
		and not m.held
		and not m.busy
end

return TomorrowCard
