--!strict
-- #5551 (Derek 2026-11-20 13:04 UTC: "one for intricate details of everything in first 5 minute"; Growth's step list):
-- `first_five_v1`, every beat of the play first start's first five minutes as one ordered funnel, only for a save on
-- that start (telemetry.freeStart), its place in telemetry.firstFiveStep. A step logs once per save and fills every
-- earlier step not yet logged, as onboarding_v9 does. Field 3 reads "free" on every step (Telemetry's grouped).
-- The side events (start_time, start_side, start_miss, start_cannon, start_window) are Telemetry's; their limits are
-- here. Pure, so the spec checks it.
--   due(logged, step) -> { number }    the step numbers to log now for a save at `logged` reaching `step`
--   validStep(raw) -> number?          a saved firstFiveStep, clamped (nil when it is not a whole number in range)
--   sideBit(kind) -> number?           start_side's bit for `kind` in telemetry.startSide, nil when not a kind
--   validSide(raw) -> number?          a saved startSide, clamped

local StartFunnel = {}

StartFunnel.FUNNEL = "first_five_v1"
StartFunnel.STEPS = {
	"loaded",
	"first_move",
	"catch_started",
	"ring_try",
	"first_catch",
	"chip_catch_paid",
	"camp_ring",
	"first_home",
	"catch_2",
	"catches_3",
	"coin_chip_shown",
	"rank_ready",
	"rank_tapped",
	"tier_2",
	"cannon_glow_shown",
	"park_flight",
	"park_arrived",
	"park_catch_started",
	"park_catch",
	"park_home",
	"rank_ready_3",
	"rank_tapped_3",
	"tier_3",
} :: { string }
StartFunnel.COUNT = #StartFunnel.STEPS

StartFunnel.INDEX = {} :: { [string]: number }
for index, name in StartFunnel.STEPS do
	StartFunnel.INDEX[name] = index
end

-- start_time: the milestones that also send their seconds of play since load, once each.
StartFunnel.TIMED = {
	first_catch = true,
	first_home = true,
	catches_3 = true,
	rank_ready = true,
	tier_2 = true,
	park_arrived = true,
	park_catch = true,
	tier_3 = true,
} :: { [string]: boolean }

-- start_side: the optional things, once each, only in the first SIDE_SECONDS of play.
StartFunnel.SIDE = {
	"home_tapped",
	"bowl_walked",
	"bowl_food",
	"bait_scene_shown",
	"bait_scene_none",
	"bowl_cat_tamed",
	"upgrades_opened",
	"store_opened",
} :: { string }
-- the kinds a client may report (TelemetryReport "start_side"): what only the screen sees
StartFunnel.CLIENT_SIDE = { "bowl_walked" } :: { string }
StartFunnel.SIDE_SECONDS = 300
StartFunnel.SIDE_ALL = 2 ^ #StartFunnel.SIDE - 1

-- start_window: any window that opens in the first WINDOW_SECONDS of play (by plan there are none).
StartFunnel.WINDOW_SECONDS = 180

-- start_miss: one per miss on the first MISS_CATCHES catches in each place, at most MISS_MOST a catch.
StartFunnel.MISS_CATCHES = 3
StartFunnel.MISS_MOST = 6
StartFunnel.MISS_PLACES = { alley = "alley", park = "park" } :: { [string]: string }

function StartFunnel.due(logged: number, step: number): { number }
	local out: { number } = {}
	for index = math.max(0, logged) + 1, math.min(step, StartFunnel.COUNT) do
		table.insert(out, index)
	end
	return out
end

function StartFunnel.validStep(raw: unknown): number?
	if type(raw) ~= "number" or raw ~= raw or raw % 1 ~= 0 then
		return nil
	end
	return math.clamp(raw, 0, StartFunnel.COUNT)
end

function StartFunnel.sideBit(kind: string): number?
	local index = table.find(StartFunnel.SIDE, kind)
	return if index ~= nil then 2 ^ (index - 1) else nil
end

function StartFunnel.validSide(raw: unknown): number?
	if type(raw) ~= "number" or raw ~= raw or raw % 1 ~= 0 then
		return nil
	end
	return math.clamp(raw, 0, StartFunnel.SIDE_ALL)
end

-- Whether bit `bit` is set in `mask`.
function StartFunnel.has(mask: number?, bit: number): boolean
	return (mask or 0) // bit % 2 == 1
end

return StartFunnel
