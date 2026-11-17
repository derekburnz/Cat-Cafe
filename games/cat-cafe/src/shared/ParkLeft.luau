--!strict
-- #5034 (the Park phone leak: phones land in the Park and leave without a Park cat, 37% against 7% on PC). The
-- server's park_left event, logged as a player leaves who stood in the Park this session and still has no Park cat:
-- value the whole seconds they spent in the Park this session; fields the device, how close the nearest free Park
-- stray ever came (closestBucket) and the seconds bucket. It tells "never found a stray" from "found one and could
-- not catch it", so the parkRingEarly and tier3Path switch-ons have a before. Pure.
--   counts(tier, parkCaught) -> boolean        whether a player is watched (Tier 2 and up, no first Park catch)
--   closestBucket(studs?) -> string            "none", "lt15", "15_40", "40_100" or "100plus"
--   secondsBucket(seconds) -> string           "0-60", "60-180", "180-600" or "600+"
--   fields(device, closest?, seconds) -> {string}

local ParkLeft = {}

ParkLeft.EVENT = "park_left"
ParkLeft.AREA = "park"
ParkLeft.FROM_TIER = 2 -- the Park opens at Tier 2
ParkLeft.STRAY_RANGE = 250 -- strays further than this are not looked at (the Park is smaller)

function ParkLeft.counts(tier: number, parkCaught: boolean): boolean
	return tier >= ParkLeft.FROM_TIER and not parkCaught
end

function ParkLeft.closestBucket(studs: number?): string
	if studs == nil then
		return "none"
	elseif studs < 15 then
		return "lt15" -- in catching reach
	elseif studs < 40 then
		return "15_40"
	elseif studs < 100 then
		return "40_100"
	end
	return "100plus"
end

function ParkLeft.secondsBucket(seconds: number): string
	if seconds < 60 then
		return "0-60"
	elseif seconds < 180 then
		return "60-180"
	elseif seconds < 600 then
		return "180-600"
	end
	return "600+"
end

function ParkLeft.fields(device: string, closest: number?, seconds: number): { string }
	return { device, ParkLeft.closestBucket(closest), ParkLeft.secondsBucket(seconds) }
end

return ParkLeft
