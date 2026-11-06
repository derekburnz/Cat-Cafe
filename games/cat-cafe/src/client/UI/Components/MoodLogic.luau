--!strict
-- Catch v3 moods (catch-rework.md 7a): what the small icon over a stray's head shows for its Mood attribute, and which
-- way a Skittish cat's view arc points on screen. Pure, so the specs can check it (no Theme: hex colours).
--   MoodLogic.look(mood)              { glyph, color, arc } for "Sleepy", "Curious" or "Skittish", else nil
--   MoodLogic.range()                 Config.MoodIconStuds (20): the icon shows within this many studs
--   MoodLogic.arcAngle(dx, dy, last)  the arc's rotation in degrees from the cat's facing in screen pixels (y down);
--                                     keeps `last` when the cat faces almost straight at or away from the camera

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

export type Look = {
	glyph: string,
	color: string, -- hex, no #
	arc: boolean, -- Skittish: the 90 degree front arc it watches
}

local MoodLogic = {}

local LOOKS: { [string]: Look } = {
	Sleepy = { glyph = "zZ", color = "8C7BD9", arc = false }, -- a soft lavender
	Curious = { glyph = "?", color = "3BA0E6", arc = false }, -- sky blue
	Skittish = { glyph = "!", color = "E5484D", arc = true }, -- the paw ring's red
}

local DEFAULT_RANGE = 20
local MIN_PIXELS = 3 -- shorter than this on screen, the facing is toward or away from the camera: keep the last angle

function MoodLogic.look(mood: any): Look?
	if type(mood) ~= "string" then
		return nil
	end
	return LOOKS[mood]
end

function MoodLogic.range(): number
	local studs = (Config :: any).MoodIconStuds
	return if type(studs) == "number" and studs > 0 then studs else DEFAULT_RANGE
end

function MoodLogic.arcAngle(dx: number, dy: number, last: number?): number
	if dx ~= dx or dy ~= dy or dx * dx + dy * dy < MIN_PIXELS * MIN_PIXELS then
		return last or 90 -- no facing yet: point down, toward the player
	end
	return math.deg(math.atan2(dy, dx))
end

return MoodLogic
