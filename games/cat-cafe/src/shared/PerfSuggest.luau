--!strict
-- #4311 (Derek 2026-11-14: "I know their is a low quality mode just make it better and suggest it to them"; #4307:
-- phones average 49 frames a second against 86 on a computer and leave much sooner): a touch player whose game runs
-- slow is asked once whether to turn on Low performance. Pure rules, no instances; Controllers/PerfSuggestController
-- samples the frames and shows the ask.
--   WINDOW_SECONDS, LOW_FPS, WINDOWS, SKIP_SECONDS, ASKED_KEY, TELEMETRY, OUTCOMES
--   step(run, fps, counted)   adds one window's frames a second to `run` (a count of slow windows in a row) and
--                             returns the new run; a window not `counted` (a cutscene, the intro) leaves it as it is
--   due(run, elapsed, touch, lowPerformance, asked)   whether to ask now

local PerfSuggest = {}

PerfSuggest.WINDOW_SECONDS = 20 -- frames are averaged over windows this long
PerfSuggest.LOW_FPS = 30 -- a window under this many frames a second is slow
PerfSuggest.WINDOWS = 2 -- slow windows in a row before the ask
PerfSuggest.SKIP_SECONDS = 60 -- nothing counts in the session's first minute (loading, the intro)
PerfSuggest.ASKED_KEY = "perfAsked" -- the saved setting: the ask was answered, so it never comes again
PerfSuggest.TELEMETRY = "perf_suggest" -- TelemetryReport name; values OUTCOMES
PerfSuggest.OUTCOMES = { "shown", "accepted", "declined", "ignored", "auto" }

-- #5285 A1 (Growth: phones lose about a third of their first-minute leavers before the first move, at about 49 frames
-- a second against 86): behind `phoneSmooth` (LiveFlags, off by default), a new account on a touch screen starts in
-- Smooth mode (Low performance) with no ask, saved as the ask answered, so the slow-game card never comes. Turning
-- it off in Settings keeps it off. Telemetry logs it as perf_suggest "auto".
PerfSuggest.AUTO_FLAG = "phoneSmooth"

function PerfSuggest.autoStart(
	on: boolean,
	touch: boolean,
	newAccount: boolean,
	lowPerformance: boolean,
	asked: boolean
): boolean
	return on and touch and newAccount and not lowPerformance and not asked
end

function PerfSuggest.step(run: number, fps: number, counted: boolean): number
	if not counted then
		return run
	end
	if fps ~= fps or fps >= PerfSuggest.LOW_FPS then
		return 0
	end
	return run + 1
end

function PerfSuggest.due(
	run: number,
	elapsed: number,
	touch: boolean,
	lowPerformance: boolean,
	asked: boolean
): boolean
	return touch
		and not lowPerformance
		and not asked
		and elapsed >= PerfSuggest.SKIP_SECONDS
		and run >= PerfSuggest.WINDOWS
end

return PerfSuggest
