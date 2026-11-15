--!strict
-- #4314 (Derek 2026-11-14: "do an A/B test for all devices for the loading screen 50% off 50% on before the short
-- tutorial and keep track of playtime / churn at those steps ... especially for the 30second/1m/2m/3m/4m/5m marks.
-- Keep them categorized by tablet/phone/pc/console"): a Creator Hub Experiment puts a new save in an arm through the
-- player's config value KEY ("on" or "off", Roblox ConfigService, read by IntroModeService). "on" shows the loading
-- screen before the short intro whatever the loadingScreen switch says, "off" never shows it, and no arm leaves the
-- switch to decide as today. The server sets the arm as the player's ATTRIBUTE for the client and logs ab_loading at
-- every playtime_v1 step up to LAST_STEP (fields arm, step, device) and ab_loading_seen (value the whole seconds the
-- screen was up; fields arm, device). Pure.
--   KEY, ATTRIBUTE, ARMS, EVENT, SEEN_EVENT, SEEN_REPORT, SEEN_MAX, LAST_STEP
--   arm(value)                 "on" or "off" for a config value, else nil
--   joins(sessions, introSeen) whether a save is new enough to join the test
--   shows(arm, flagOn)         whether the loading screen shows

local LoadingTest = {}

LoadingTest.KEY = "loadingScreenArm"
LoadingTest.ATTRIBUTE = "LoadingArm"
LoadingTest.ARMS = { "on", "off" }
LoadingTest.EVENT = "ab_loading"
LoadingTest.SEEN_EVENT = "ab_loading_seen"
LoadingTest.SEEN_REPORT = "loading_seen" -- TelemetryReport name; value the whole seconds the screen was up
LoadingTest.SEEN_MAX = 120
LoadingTest.LAST_STEP = "played_5m"

function LoadingTest.arm(value: unknown): string?
	if value == "on" or value == "off" then
		return value :: string
	end
	return nil
end

-- A save on its first session that has not seen the intro.
function LoadingTest.joins(sessions: number, introSeen: boolean): boolean
	return sessions <= 1 and not introSeen
end

function LoadingTest.shows(arm: string?, flagOn: boolean): boolean
	if arm == "on" then
		return true
	elseif arm == "off" then
		return false
	end
	return flagOn
end

return LoadingTest
