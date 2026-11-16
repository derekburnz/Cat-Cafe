--!strict
-- #4833 (Derek 2026-11-16 15:37 UTC: "remove the pop ups like how is it so far and cafe recaps and join event all at
-- once spread them out to one every 5 minute"): one pace for every card that opens by itself. After one shows, the
-- next waits GAP_SECONDS. The ones that can wait (the slide-in asks, the favorite and like asks, the notification ask,
-- the event's Notify Me offer, the Starter Bundle card, the session recap, the Daily Treat window opening itself, a
-- Cafe Event's start card and the gift-soon card) ask `free` first; the ones that cannot (the welcome back card at
-- join, an admin event's cards) only mark the time. UI.pace holds this session's clock. Pure, so the specs check it.
--   free(lastAt, now) -> boolean   lastAt: os.clock() the last card showed, nil before any this session

local PopupPace = {}

PopupPace.GAP_SECONDS = 5 * 60

function PopupPace.free(lastAt: number?, now: number): boolean
	return lastAt == nil or now - lastAt >= PopupPace.GAP_SECONDS
end

return PopupPace
