--!strict
-- #3661 (Derek 2026-11-12: "the games servers feel a bit laggier causing slight delays to teleport etc"): Creator Hub
-- shows the servers' health but no ping, so one net_ping event a session says what players' connections look like:
-- value the ping in milliseconds SAMPLE_SECONDS after the save loaded, fields the device and the band. Counts only,
-- never who. Pure.

local NetPing = {}

NetPing.EVENT = "net_ping"
NetPing.SAMPLE_SECONDS = 60 -- after the save loads: the join's own traffic has settled by then
NetPing.MAX_MS = 5000 -- a reading above this (or not a number) is logged as this

-- The band's upper edges in milliseconds and their names, best first; anything slower is LAST.
NetPing.BANDS = table.freeze({
	table.freeze({ under = 80, name = "under_80" }),
	table.freeze({ under = 150, name = "80_150" }),
	table.freeze({ under = 300, name = "150_300" }),
})
NetPing.LAST = "300_up"

-- Roblox's reading (seconds, Player:GetNetworkPing) as whole milliseconds from 0 to MAX_MS.
function NetPing.ms(seconds: unknown): number
	if type(seconds) ~= "number" or seconds ~= seconds then
		return NetPing.MAX_MS
	end
	return math.clamp(math.floor(seconds * 1000 + 0.5), 0, NetPing.MAX_MS)
end

function NetPing.band(ms: number): string
	for _, band in NetPing.BANDS do
		if ms < band.under then
			return band.name
		end
	end
	return NetPing.LAST
end

return NetPing
