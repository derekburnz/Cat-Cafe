--!strict
-- #5026 (Derek 2026-11-17: "make sure you only load what area your in or if in town square just that to help reduce
-- loading screen time and lag"). With streaming on (#4788), models that are Persistent go to every device wherever
-- it stands. With the areaOnly switch on, the areas' night fences and their camp cannons (Sync's census: 10 cannons
-- at 366 instances and 10 fences at about 285, on every device) stream like the rest of their area: a device far
-- from an area does not hold them. The Town Square cannon stays Persistent (the walk-through's pointer and intro
-- find it from anywhere); a camp cannon is only looked up from its own area (UIController.cannonPart, CannonGlide). The cafes' closed back doors stay Persistent (the cafes are, #4793).
-- Off (the default) everything stays as built. Services/AreaOnlyService sets the mode; the client's fence poll
-- (Controllers/WorldController) shows a fence that streams back in at night within a quarter second. Pure.
--
-- Roblox terms: a model's ModelStreamingMode decides how it streams. Persistent sends it to every client and keeps
-- it there; Atomic sends it whole once the client is near any of it, and lets it go when the client is far.

local AreaOnly = {}

AreaOnly.FLAG = "areaOnly" -- shared/LiveFlags, off by default
AreaOnly.STEP = 5 -- seconds between the service's checks of the switch

-- The streaming mode for an area's night fence with the switch on or off.
function AreaOnly.fenceMode(on: boolean): Enum.ModelStreamingMode
	return if on then Enum.ModelStreamingMode.Atomic else Enum.ModelStreamingMode.Persistent
end

-- Whether a Cat Cannon (its CannonId attribute) streams with the switch on: every camp cannon, never the town's.
function AreaOnly.cannonStreams(cannonId: unknown): boolean
	return type(cannonId) == "string" and cannonId ~= "town"
end

return AreaOnly
