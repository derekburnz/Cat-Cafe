--!strict
-- The cannon flight's clock (#4933 follow-up, first 5 minutes priority): the server can run a flight faster than
-- Config.CannonLaunchSeconds by setting the character attribute `CannonFlightScale` (a number, the flight's length
-- as a share of the usual one: 2/3 for a new player's first flight) just before `CannonLaunchAt`, clearing it after
-- the landing; nil means 1. Every client beat (Presets.cannon, cannonPose, cannonCamera, cannonGlide, the clouds and
-- the flight's sounds) stays written in the usual flight's seconds, and is read through `seconds`, so a shorter
-- flight plays every beat in step with the server's. The scale is kept per CannonLaunchAt, so the clear after the
-- landing (or an attribute that arrives a moment after the launch time) never jumps the clock.

local Logic = require(script.Parent.Logic)

local FlightClock = {}

FlightClock.ATTRIBUTE = "CannonFlightScale"
FlightClock.MIN = 0.25 -- the same bounds as the server's shared Cannon.scaleOf (#4936)
FlightClock.MAX = 1

type Kept = { at: number, scale: number }

local kept: { [Model]: Kept } = setmetatable({}, { __mode = "k" }) :: any

-- The scale from the attribute's value: a sane number, else 1. Pure.
function FlightClock.scaleFrom(value: unknown): number
	if type(value) ~= "number" or value ~= value then
		return 1
	end
	return math.clamp(value :: number, FlightClock.MIN, FlightClock.MAX)
end

-- `character`'s scale for the flight launched at `launchAt`: the attribute while it is set, else what was seen for
-- this same launch, else 1.
function FlightClock.scale(character: Model, launchAt: number): number
	local value = character:GetAttribute(FlightClock.ATTRIBUTE)
	local had = kept[character]
	if type(value) == "number" then
		local scale = FlightClock.scaleFrom(value)
		kept[character] = { at = launchAt, scale = scale }
		return scale
	end
	if had ~= nil and had.at == launchAt then
		return had.scale
	end
	return 1
end

-- Seconds into the usual flight's beats: real seconds since `launchAt` over the scale. Pure.
function FlightClock.toBeats(elapsed: number, scale: number): number
	return elapsed / (if scale > 0 then scale else 1)
end

-- The usual flight's seconds that `character`'s flight launched at `launchAt` has reached at server time `now`.
function FlightClock.seconds(character: Model, launchAt: number, now: number): number
	return FlightClock.toBeats(now - launchAt, FlightClock.scale(character, launchAt))
end

-- A beat `beat` seconds into the usual flight, as real seconds from the launch. Pure.
function FlightClock.realAt(beat: number, scale: number): number
	return beat * scale
end

-- `plan` (the cloud cutscene's beats in the usual flight's seconds) for a flight at `scale`. Pure.
function FlightClock.clouds(plan: Logic.CloudPlan, scale: number): Logic.CloudPlan
	if scale == 1 then
		return plan
	end
	return {
		coverFrom = plan.coverFrom * scale,
		coverTo = plan.coverTo * scale,
		partFrom = plan.partFrom * scale,
		partTo = plan.partTo * scale,
		tintFrom = plan.tintFrom * scale,
		tintTo = plan.tintTo * scale,
	}
end

return FlightClock
