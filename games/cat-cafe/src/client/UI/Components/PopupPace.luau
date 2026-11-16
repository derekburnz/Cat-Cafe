--!strict
-- #4833 (Derek 2026-11-16 15:37 UTC: "remove the pop ups like how is it so far and cafe recaps and join event all at
-- once spread them out to one every 5 minute"): one pace for every card that opens by itself. After one shows, the
-- next waits GAP_SECONDS. The ones that can wait (the slide-in asks, the favorite and like asks, the notification ask,
-- the event's Notify Me offer, the Starter Bundle card, the session recap, the Daily Treat window opening itself, a
-- Cafe Event's start card and the gift-soon card) ask `free` first; the ones that cannot (the welcome back card at
-- join, an admin event's cards) only mark the time. UI.pace holds this session's clock. Pure, so the specs check it.
--   free(lastAt, now) -> boolean   lastAt: os.clock() the last card showed, nil before any this session
--   early(startedAt, now, tutorial) -> boolean   #4848/#4854: the session's first EARLY_SECONDS, or the walk-through

local PopupPace = {}

PopupPace.GAP_SECONDS = 5 * 60

function PopupPace.free(lastAt: number?, now: number): boolean
	return lastAt == nil or now - lastAt >= PopupPace.GAP_SECONDS
end

-- #4848 (Derek 2026-11-16: "in the first 5 minutes don't show the afk in your cafe for 2x money") and #4854 ("stop
-- showing things like how is game, invite a friend, favourite game, etc during first 5 min or tutorial"): no social
-- ask and no cafe rest banner in a session's first EARLY_SECONDS, nor while the walk-through runs.
PopupPace.EARLY_SECONDS = 5 * 60

function PopupPace.early(startedAt: number, now: number, tutorial: boolean): boolean
	return tutorial or now - startedAt < PopupPace.EARLY_SECONDS
end

return PopupPace
