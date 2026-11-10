--!strict
-- The loading screen's count from 0 to 100 (#3109, Derek2 11-10: "a quick cute cat loading screen that instantly
-- goes up to 100 really fast then transitions to the tutorial scenes"). Pure numbers; Screens/Intro draws them.
--
-- Roblox gives no true percent for a world that streams in, so the count is a show of progress, not a measure:
--   creep(seconds)        while the game is still getting the player's save: fast at first, slower and slower, and
--                         never past CREEP_TOP, so it cannot sit at 100 while the player still waits
--   raceSeconds(shownFor) once the save is in, how long the run to 100 takes: the screen shows for SHOWN_MIN in
--                         all when the save came at once, and RACE_MIN when the player has waited that long already
--   race(from, k)         the count `k` (0 to 1) of the way through that run, easing out so the last numbers land
--   text(value)           "63%"
local LoadingCount = {}

LoadingCount.FULL = 100
LoadingCount.CREEP_TOP = 90
LoadingCount.CREEP_HALF = 0.45 -- seconds for the creep to cover half of what is left to CREEP_TOP
LoadingCount.SHOWN_MIN = 1.5 -- seconds from the screen's start to 100 when nothing holds it up
LoadingCount.RACE_MIN = 0.35 -- seconds the run to 100 takes at least, so the eye sees it get there

function LoadingCount.creep(seconds: number): number
	if seconds ~= seconds or seconds <= 0 then
		return 0
	end
	return LoadingCount.CREEP_TOP * (1 - 0.5 ^ (seconds / LoadingCount.CREEP_HALF))
end

function LoadingCount.raceSeconds(shownFor: number): number
	local shown = if shownFor ~= shownFor then 0 else math.max(shownFor, 0)
	return math.clamp(LoadingCount.SHOWN_MIN - shown, LoadingCount.RACE_MIN, LoadingCount.SHOWN_MIN)
end

function LoadingCount.race(from: number, k: number): number
	local start = math.clamp(from, 0, LoadingCount.FULL)
	local share = if k ~= k then 1 else math.clamp(k, 0, 1)
	local eased = 1 - (1 - share) * (1 - share)
	return start + (LoadingCount.FULL - start) * eased
end

function LoadingCount.text(value: number): string
	local whole = if value ~= value
		then 0
		else math.floor(math.clamp(value, 0, LoadingCount.FULL) + 0.5)
	return ("%d%%"):format(whole)
end

return LoadingCount
