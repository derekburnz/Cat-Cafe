--!strict
-- #3272 (Derek2 11-11, after the second dislike): Roblox does not tell a game who liked or disliked it, so the
-- closest thing is asking. Once a UTC day, at a calm moment of a session that has run MIN_PLAY_SECONDS (as the Roblox
-- menu closes, or after IDLE_SECONDS with no input), the faces card (thumbs up, a plain face, thumbs down; the ids
-- love, ok and no) asks "Enjoying Catch a Cat Cafe?". Closing it or letting it time out counts as skipped. The answer
-- goes up once (SessionFeedback remote) and the server logs it with who is asking: device, session length, furthest
-- tutorial step, cats owned, the screen open and the build. No reward, no free text. Pure, so the cloud specs check it.
--   ANSWERS                                 the values the server takes
--   day(now) -> number                      the UTC day number (os.time() / 86400)
--   due(played, idle, lastDay, now, quiet, menuClosed) -> boolean
--   sessionBucket(seconds), catsBucket(count) -> string

local SessionFeedback = {}

SessionFeedback.ANSWERS = table.freeze({ "love", "ok", "no", "skipped" })
SessionFeedback.MIN_PLAY_SECONDS = 5 * 60 -- of this session (Derek's "never in the first 3 minutes", with room)
SessionFeedback.IDLE_SECONDS = 60 -- no input this long counts as a natural stop
SessionFeedback.ASK_SECONDS = 12 -- the card stays this long before it counts as skipped
SessionFeedback.TITLE = "Enjoying Catch a Cat Cafe?"

local DAY = 86400

function SessionFeedback.day(now: number): number
	return math.floor(math.max(0, now) / DAY)
end

-- Whether the card may show now: the session has run long enough, the save's last answer day (0 when never) is not
-- today, nothing else is going on (`quiet`), and it is a natural stop: the Roblox menu just closed, or the player has
-- been idle IDLE_SECONDS.
function SessionFeedback.due(
	played: number,
	idle: number,
	lastDay: number?,
	now: number,
	quiet: boolean,
	menuClosed: boolean
): boolean
	if played < SessionFeedback.MIN_PLAY_SECONDS or not quiet then
		return false
	end
	if (lastDay or 0) >= SessionFeedback.day(now) then
		return false
	end
	return menuClosed or idle >= SessionFeedback.IDLE_SECONDS
end

function SessionFeedback.sessionBucket(seconds: number): string
	local minutes = math.max(0, seconds) / 60
	if minutes < 10 then
		return "5-10"
	elseif minutes < 20 then
		return "10-20"
	elseif minutes < 40 then
		return "20-40"
	elseif minutes < 90 then
		return "40-90"
	end
	return "90+"
end

function SessionFeedback.catsBucket(count: number): string
	if count <= 1 then
		return "0-1"
	elseif count <= 3 then
		return "2-3"
	elseif count <= 9 then
		return "4-9"
	elseif count <= 24 then
		return "10-24"
	end
	return "25+"
end

return SessionFeedback
