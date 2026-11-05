--!strict
-- Pure day and night math (data-model section 9). Pure: no Roblox services, so tests can require it.
-- `t` is seconds since Config.ClockEpoch (#1437: one global clock for every server; before it, since the server
-- started). The clock starts in day with ServerStartDaySeconds left, then loops night (NightLengthSeconds) and day
-- (DayLengthSeconds) forever, so each sunrise falls on a whole number of cycles from the start.

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Clock = {}

-- v0.9 (F66): what Travel, a catch, a rescue and a shove answer while the catching areas are closed at night, and
-- the toast for the sweep home. The dusk and sunrise banners are the client's, from the Clock attributes.
Clock.CLOSED_TEXT = "The areas are closed at night. They open at sunrise."
Clock.SENT_HOME_TEXT = "Night fell, so you headed home."

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

-- F88 (luck-and-rare-moments.md 1c): the number of the day at time t, counting the server's first day as 1; at night
-- it is the day that just ended.
function Clock.dayAt(t: number): number
	local time = math.max(0, t)
	if time < Config.ServerStartDaySeconds + Config.NightLengthSeconds then
		return 1
	end
	local cycle = Config.NightLengthSeconds + Config.DayLengthSeconds
	return 2 + math.floor((time - Config.ServerStartDaySeconds - Config.NightLengthSeconds) / cycle)
end

-- Seconds since the server started at which day `day` begins: 0 for the first, a sunrise for every later one.
function Clock.sunriseOf(day: number): number
	if day <= 1 then
		return 0
	end
	local cycle = Config.NightLengthSeconds + Config.DayLengthSeconds
	return Config.ServerStartDaySeconds + Config.NightLengthSeconds + (math.floor(day) - 2) * cycle
end

-- #1572 (luck-and-rare-moments.md 1g): a day's kinds, each rolled on its own from the global day number with its
-- own salt (the Park-Miller fold of CornerShop.seed), so every server has the same day and the kinds don't move
-- together. Day 0 and before (the clock before ClockEpoch) is a plain day.
export type DayKinds = { lucky: boolean, golden: boolean, rainbow: boolean }

local MODULUS = 2147483647
local MULTIPLIER = 48271
local SALTS = { lucky = 0x6C75636B, golden = 0x676F6C64, rainbow = 0x7261696E } -- "luck", "gold", "rain"

-- A number in [0, 1) for `day` and `salt`, the same everywhere.
local function dayRoll(day: number, salt: number): number
	local hash = (salt + math.floor(day) % MODULUS) % MODULUS
	for _ = 1, 3 do
		hash = (hash * MULTIPLIER) % MODULUS
		hash = bit32.bxor(hash, bit32.rshift(hash, 13))
	end
	hash = (hash * MULTIPLIER) % MODULUS
	return hash / MODULUS
end

function Clock.dayKinds(day: number): DayKinds
	if day < 1 then
		return { lucky = false, golden = false, rainbow = false }
	end
	return {
		lucky = dayRoll(day, SALTS.lucky) < Config.LuckyDayChance,
		golden = dayRoll(day, SALTS.golden) < Config.GoldenDayChance,
		rainbow = dayRoll(day, SALTS.rainbow) < Config.RainbowDayChance,
	}
end

-- Whether `day` rolls lucky: Clock.dayKinds(day).lucky without the table (Pace and the HUD ask often).
function Clock.isLuckyDay(day: number): boolean
	return day >= 1 and dayRoll(day, SALTS.lucky) < Config.LuckyDayChance
end

-- The next Lucky Day after `day`. #1572 drops the countdown (the days are random now); the Clock folder still carries
-- it until the HUD stops reading it. Looks at most 200 days ahead (a Lucky Day 1 in 3).
function Clock.nextLuckyDay(day: number): number
	local from = math.max(math.floor(day), 0)
	for next = from + 1, from + 200 do
		if Clock.isLuckyDay(next) then
			return next
		end
	end
	return from + 200
end

-- The gold chance `chance` on a day of `kinds`: x GoldenDayGoldMultiplier on a Golden Day.
function Clock.goldChance(chance: number, kinds: DayKinds?): number
	return if kinds ~= nil and kinds.golden then chance * Config.GoldenDayGoldMultiplier else chance
end

-- The rainbow chance `chance` on a day of `kinds`: x RainbowDayMultiplier on a Rainbow Day (rainbow luck on top).
function Clock.rainbowChance(chance: number, kinds: DayKinds?): number
	return if kinds ~= nil and kinds.rainbow then chance * Config.RainbowDayMultiplier else chance
end

-- Seconds since the server started at which a phase begins its first full run (used to jump the clock).
function Clock.startOf(phase: Types.ClockPhase): number
	if phase == "night" then
		return Config.ServerStartDaySeconds
	end
	return Config.ServerStartDaySeconds + Config.NightLengthSeconds
end

return Clock
