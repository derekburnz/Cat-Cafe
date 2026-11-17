--!strict
-- #4783 (phone players leave early: about 32% wait over 10 s to start, phones about 49 FPS against 86 on PC, read
-- from health_check, which is Tier 1 only and one 2 s sample): measures both on every client. Analytics only, pure:
-- Controllers/PerfWatchController sends, Telemetry checks and logs.
--   client_load: once a session, the join to the world ready on the client (game loaded, first ProfileSync, own
--     character in); the client reports its own part (READY, seconds from its first script line)
--   client_fps: the average frames a second over each window up to a mark (0 to 1, 1 to 3 and 3 to 10 minutes);
--     a report is one number, `encode(markIndex, quality, fps)`, with Roblox's graphics quality (0 is Automatic)
--   MARKS, MAX_FPS, MAX_QUALITY, MAX_READY, FPS, READY, GAP_SECONDS
--   encode(markIndex, quality, fps) -> number     decode(value) -> (markIndex, quality, fps)?
--   average(frames, seconds) -> number             loadBucket(seconds) -> string

local PerfWatch = {}

PerfWatch.MARKS = table.freeze({ 1, 3, 10 }) -- minutes into the session; each window runs from the mark before
PerfWatch.MAX_FPS = 240
PerfWatch.MAX_QUALITY = 10 -- Enum.SavedQualitySetting: 0 Automatic, 1 to 10
PerfWatch.MAX_READY = 600 -- seconds; a client part above it is dropped
PerfWatch.FPS = "fps_avg" -- TelemetryReport names
PerfWatch.READY = "load_ready"
-- a frame that took longer than this (the app in the background, a phone call) is left out of the average, so a
-- paused app does not read as a slow one
PerfWatch.GAP_SECONDS = 1

local MARK_SCALE = 100000
local QUALITY_SCALE = 1000

function PerfWatch.encode(markIndex: number, quality: number, fps: number): number
	local q = math.clamp(math.floor(quality), 0, PerfWatch.MAX_QUALITY)
	local f = math.clamp(math.floor(fps + 0.5), 0, PerfWatch.MAX_FPS)
	return markIndex * MARK_SCALE + q * QUALITY_SCALE + f
end

-- The mark's index, the quality and the fps a report packs, or nil for anything that is not one.
function PerfWatch.decode(value: unknown): (number?, number?, number?)
	if type(value) ~= "number" or value ~= value or value ~= math.floor(value) or value < 0 then
		return nil, nil, nil
	end
	local n = value :: number
	local markIndex = n // MARK_SCALE
	local quality = (n % MARK_SCALE) // QUALITY_SCALE
	local fps = n % QUALITY_SCALE
	if
		PerfWatch.MARKS[markIndex] == nil
		or quality > PerfWatch.MAX_QUALITY
		or fps > PerfWatch.MAX_FPS
	then
		return nil, nil, nil
	end
	return markIndex, quality, fps
end

-- Frames a second over `seconds` of counted frames; 0 when nothing was counted.
function PerfWatch.average(frames: number, seconds: number): number
	if seconds <= 0 or frames <= 0 then
		return 0
	end
	return math.min(frames / seconds, PerfWatch.MAX_FPS)
end

-- client_load's bucket for the client's own part (finer than FirstFive.bootBucket past 10 s, where phones sit).
function PerfWatch.loadBucket(seconds: number): string
	if seconds ~= seconds or seconds < 3 then
		return "lt3"
	elseif seconds < 6 then
		return "3-6"
	elseif seconds < 10 then
		return "6-10"
	elseif seconds < 20 then
		return "10-20"
	elseif seconds < 40 then
		return "20-40"
	end
	return "40+"
end

return PerfWatch
