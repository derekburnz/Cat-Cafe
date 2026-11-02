--!strict
-- The restart warning (Derek 2026-10-29: "send an announcement in game for all servers that servers will be
-- restarting in 5min, 3min, 1min, now and then publish"; decisions.md 2026-11-01), pure. tools/opencloud's
-- restart-countdown.sh publishes JSON text {"kind":"restart","seconds":N} on MessagingService topic TOPIC at 300,
-- 180, 60 and 0 seconds before a restart; every server reads it with `parse` and toasts its players `text(seconds)`.
-- Anything that is not such a message, or whose seconds are not a whole number from 0 to MAX_SECONDS, is ignored.

local RestartNotice = {}

RestartNotice.TOPIC = "CatCafeAnnounce" -- restart-countdown.sh's TOPIC
RestartNotice.MAX_SECONDS = 600
RestartNotice.REPEAT_SECONDS = 20 -- the same warning again this soon (a retried publish) is not shown twice

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

-- What players read `seconds` before the restart: "Servers restart for an update in 5 minutes. Your cafe is saved."
function RestartNotice.text(seconds: number): string
	local saved = "Your cafe is saved."
	if seconds <= 0 then
		return "Servers restart for an update now. " .. saved .. " Join again in a moment."
	end
	if seconds < 60 then
		local whole = math.ceil(seconds)
		return string.format(
			"Servers restart for an update in %d second%s. %s",
			whole,
			if whole == 1 then "" else "s",
			saved
		)
	end
	local minutes = math.ceil(seconds / 60)
	return string.format(
		"Servers restart for an update in %d minute%s. %s",
		minutes,
		if minutes == 1 then "" else "s",
		saved
	)
end

return RestartNotice
