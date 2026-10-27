--!strict
-- Pure day and night math (data-model section 9). Pure: no Roblox services, so tests can require it.
-- `t` is seconds since the server started. The server starts in day with ServerStartDaySeconds left, then
-- loops night (NightLengthSeconds) and day (DayLengthSeconds) forever.

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Clock = {}

-- The phase at time t and how many seconds of it are left.
function Clock.phaseAt(t: number): (Types.ClockPhase, number)
	local time = math.max(0, t)
	if time < Config.ServerStartDaySeconds then
		return "day", Config.ServerStartDaySeconds - time
	end
	local cycle = Config.NightLengthSeconds + Config.DayLengthSeconds
	local into = (time - Config.ServerStartDaySeconds) % cycle
	if into < Config.NightLengthSeconds then
		return "night", Config.NightLengthSeconds - into
	end
	return "day", cycle - into
end

-- Seconds of night between clock times t0 and t1 (t0 <= t1), for settling income across phase boundaries
-- (data-model section 11). The first stretch of day before the first night counts as day.
function Clock.nightSecondsBetween(t0: number, t1: number): number
	local function nightBefore(t: number): number
		local time = math.max(0, t - Config.ServerStartDaySeconds)
		local cycle = Config.NightLengthSeconds + Config.DayLengthSeconds
		local full = math.floor(time / cycle)
		return full * Config.NightLengthSeconds
			+ math.min(time - full * cycle, Config.NightLengthSeconds)
	end
	if t1 <= t0 then
		return 0
	end
	return nightBefore(t1) - nightBefore(t0)
end

-- Seconds since the server started at which a phase begins its first full run (used to jump the clock).
function Clock.startOf(phase: Types.ClockPhase): number
	if phase == "night" then
		return Config.ServerStartDaySeconds
	end
	return Config.ServerStartDaySeconds + Config.NightLengthSeconds
end

return Clock
