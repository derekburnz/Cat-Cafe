--!strict
-- The restart warning (Derek 2026-10-29: "send an announcement in game for all servers that servers will be
-- restarting in 5min, 3min, 1min, now and then publish"; decisions.md 2026-11-01), pure. tools/opencloud's
-- restart-countdown.sh publishes JSON text {"kind":"restart","seconds":N} on MessagingService topic TOPIC at 600,
-- 300, 180, 60, 10 and 0 seconds before a restart (Derek 2026-11-08); every server reads it with `parse` and toasts
-- its players `text(seconds)`.
-- Anything that is not such a message, or whose seconds are not a whole number from 0 to MAX_SECONDS, is ignored.
-- #2720 (Derek2 2026-11-09: "make the restart warnings pop up less, looks like it scares players into leaving"): a
-- server shows only the marks in SHOWN (`shows`), the early ones as calm "info" and the last minute as "warn" (`kind`),
-- in calmer words. With the script's marks today players see 10 minutes, 1 minute and now; with WARNINGS
-- "600 120 30 0" (the lead's half of #2720) 10 minutes, 2 minutes, 30 seconds and now.

local RestartNotice = {}

RestartNotice.TOPIC = "CatCafeAnnounce" -- restart-countdown.sh's TOPIC
RestartNotice.MAX_SECONDS = 600
RestartNotice.REPEAT_SECONDS = 20 -- the same warning again this soon (a retried publish) is not shown twice
RestartNotice.SHOWN = { 600, 120, 60, 30, 0 } -- #2720: the marks a server shows; the rest are only remembered
RestartNotice.WARN_SECONDS = 60 -- #2720: from this close the notice is a "warn" toast; before it, "info"

local shown: { [number]: boolean } = {}
for _, seconds in RestartNotice.SHOWN do
	shown[seconds] = true
end

-- #2720: whether a server shows players the countdown's mark `seconds` (it still remembers when the restart comes).
function RestartNotice.shows(seconds: number): boolean
	return shown[seconds] == true
end

-- #2720: the toast kind for a notice `seconds` before the restart: calm "info" early, "warn" in the last minute.
function RestartNotice.kind(seconds: number): "info" | "warn"
	return if seconds <= RestartNotice.WARN_SECONDS then "warn" else "info"
end

-- The seconds to the restart in a message's Data (the JSON text, or a table already decoded), or nil. `decode` turns
-- JSON text into a value and may error (the server passes HttpService:JSONDecode).
function RestartNotice.parse(data: unknown, decode: (string) -> unknown): number?
	local value: unknown = data
	if type(data) == "string" then
		if #data > 200 then
			return nil
		end
		local ok, decoded = pcall(decode, data)
		if not ok then
			return nil
		end
		value = decoded
	end
	if type(value) ~= "table" then
		return nil
	end
	local message = value :: { [string]: unknown }
	local seconds = message.seconds
	if
		message.kind ~= "restart"
		or type(seconds) ~= "number"
		or seconds ~= seconds
		or seconds ~= math.floor(seconds)
		or seconds < 0
		or seconds > RestartNotice.MAX_SECONDS
	then
		return nil
	end
	return seconds
end

-- What players read `seconds` before the restart (#2720's calmer words): "A quick update is coming in 10 minutes, then
-- a 30-minute event! Keep playing, your cafe is saved." #3736 (Derek 2026-11-12): every forced restart is followed by
-- a 30 minute event (10 minutes before that), scheduled with events.yml for the moment servers come back, and the
-- warning says so, so people stay.
RestartNotice.EVENT_LINE = "then a 30-minute event!"
-- #3420, #3424: the restart of the Thursday 2026-11-12 launch (22:00 UTC) is followed by the 1 hour Update Party
-- and the 100 golden fish gift, so a warning shown from an hour before it to half an hour after says so. Outside
-- that window, and whenever `now` (os.time()) is not given, the words are the usual ones, with no later publish.
RestartNotice.LAUNCH_AT = 1794520800 -- 2026-11-12 22:00 UTC
RestartNotice.LAUNCH_LINE = "then a 1-hour party and a gift!"
-- #3535: the Friday 2026-11-13 update (22:00 UTC) has the same party and a gift of its own, so the same words
RestartNotice.LAUNCHES = { RestartNotice.LAUNCH_AT, 1794607200 }
local LAUNCH_BEFORE, LAUNCH_AFTER = 3600, 1800
-- #4195 (Derek 2026-11-14: "announce admin abuse events in coming after update before you restart servers"): the
-- Saturday 2026-11-14 22:00 UTC and Sunday 2026-11-15 20:00 UTC update restarts are followed by an admin event block
-- (2x money, the lucky, golden and rainbow days as Golden Hour, Mythical and rainbow Legendary showers), so their
-- warnings name it instead of the party line.
-- Saturday 2026-11-21 20:00 UTC (the 10 Secret cats update, Growth-Agent's secrets-update-event-plan) joins them.
RestartNotice.ADMIN_LAUNCHES = { 1794693600, 1794772800, 1795291200 }
RestartNotice.ADMIN_LINE = "then ADMIN EVENTS: 2x money, Golden Hour and cat showers!"
RestartNotice.ADMIN_AFTER = "ADMIN EVENTS: 2x money, Golden Hour and cat showers!"
-- A launch whose update has its own headline says it first (Growth-Agent's copy, 2026-11-14): { line, at zero }.
-- One not listed here uses ADMIN_LINE and ADMIN_AFTER.
RestartNotice.ADMIN_WORDS = {
	[1794772800] = { "then 3 NEW WORLDS and ADMIN EVENTS!", "3 NEW WORLDS and ADMIN EVENTS!" },
	[1795291200] = { "then 10 SECRET CATS and ADMIN EVENTS!", "10 SECRET CATS and ADMIN EVENTS!" },
} :: { [number]: { string } }

-- the promise a warning shown at `now` ends on, and what the event is called at zero
local function promise(now: number?): (string, string)
	for _, at in RestartNotice.ADMIN_LAUNCHES do
		if now ~= nil and now >= at - LAUNCH_BEFORE and now <= at + LAUNCH_AFTER then
			local words = RestartNotice.ADMIN_WORDS[at]
			if words ~= nil then
				return words[1], words[2]
			end
			return RestartNotice.ADMIN_LINE, RestartNotice.ADMIN_AFTER
		end
	end
	for _, at in RestartNotice.LAUNCHES do
		if now ~= nil and now >= at - LAUNCH_BEFORE and now <= at + LAUNCH_AFTER then
			return RestartNotice.LAUNCH_LINE, "a 1-hour party and a gift!"
		end
	end
	return RestartNotice.EVENT_LINE, "a 30-minute event!"
end

function RestartNotice.text(seconds: number, now: number?): string
	local line, after = promise(now)
	if seconds <= 0 then
		return "Updating now. Join again for " .. after .. " Your cafe is saved."
	end
	if seconds < 60 then
		local whole = math.ceil(seconds)
		return string.format(
			"Quick update in %d second%s, %s Your cafe is saved.",
			whole,
			if whole == 1 then "" else "s",
			line
		)
	end
	local minutes = math.ceil(seconds / 60)
	return string.format(
		"A quick update is coming in %d minute%s, %s Keep playing, your cafe is saved.",
		minutes,
		if minutes == 1 then "" else "s",
		line
	)
end

return RestartNotice
