--!strict
-- Sync's clip recordings (Studio only): with the Workspace attribute RecordMode set true in a Studio playtest, the
-- night holds where it is so a take is not cut short. NightService skips the dusk send-home and the night sweep, and
-- ClockService holds the clock (the phase and its countdown stand still) until the attribute is cleared. The client's
-- UI.recordMode (#5353) reads the same attribute. Live servers never read it: `on` is false outside Studio.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RecordMode = {}

RecordMode.ATTRIBUTE = "RecordMode"

function RecordMode.on(): boolean
	return RunService:IsStudio() and Workspace:GetAttribute(RecordMode.ATTRIBUTE) == true
end

return RecordMode
