--!strict
-- #5517 (Growth's Nov 19 read: 22 to 27% of Tier 3 players never arrive in the Neighbourhood, and those who catch
-- there reach Tier 4 82 to 84% of the time): the stops between Tier 3 and the first Neighbourhood landing, behind the
-- log switch `tier3TripLog` (LiveFlags.OFF_BY_DEFAULT). Each stop is logged once per account as the custom event
-- `tier3_trip` (value 1; fields the stop, the device, and "day" or "night" by whether areas are open, or for
-- "refused" the refusal's words in their place), while the account is at Tier 3 and has not landed there yet. The account's stops
-- are a bit mask in profile.telemetry.tier3Trip (optional, no save version: an older server dropping it can only log
-- a stop twice). A session that ends at Tier 3 before the landing logs `tier3_left` (value the seconds in game this
-- session; fields the furthest stop or "none", the device, "day" or "night").
-- AreaVisit (#4544) already logs each pick and landing as a journey; these steps add what it does not have: the
-- Cannon menu opened, a refused pick and the session end, all for the Tier 3 to Neighbourhood trip only. Pure.

local Tier3Trip = {}

Tier3Trip.FLAG = "tier3TripLog"
Tier3Trip.TIER = 3
Tier3Trip.AREA = "neighbourhood"
Tier3Trip.EVENT = "tier3_trip"
Tier3Trip.LEFT_EVENT = "tier3_left"
Tier3Trip.MASK_MAX = 15

-- In trip order; the bit is 2^(index - 1)
Tier3Trip.STOPS = { "cannon_open", "refused", "picked", "landed" }
local BIT: { [string]: number } = {}
for index, stop in Tier3Trip.STOPS do
	BIT[stop] = 2 ^ (index - 1)
end
table.freeze(BIT)

local function has(mask: number, bit: number): boolean
	return math.floor(mask / bit) % 2 == 1
end

function Tier3Trip.sanitize(raw: unknown): number?
	if type(raw) ~= "number" or raw ~= raw or raw < 1 then
		return nil
	end
	return math.min(math.floor(raw), Tier3Trip.MASK_MAX)
end

-- Whether `stop` is due to log: the account at Tier 3, not yet landed in the Neighbourhood, and the stop not logged.
function Tier3Trip.due(mask: number?, stop: string, tier: number): boolean
	local bit = BIT[stop]
	if bit == nil or tier ~= Tier3Trip.TIER then
		return false
	end
	local m = mask or 0
	if has(m, bit) then
		return false
	end
	return not has(m, BIT.landed)
end

function Tier3Trip.mark(mask: number?, stop: string): number
	local bit = BIT[stop]
	local m = mask or 0
	if bit == nil or has(m, bit) then
		return m
	end
	return m + bit
end

-- The furthest stop logged before the landing, or "none", for tier3_left
function Tier3Trip.furthest(mask: number?): string
	local m = mask or 0
	local best = "none"
	for index = 1, 3 do
		if has(m, 2 ^ (index - 1)) then
			best = Tier3Trip.STOPS[index]
		end
	end
	return best
end

-- #5517 (hoodTrail): whether the account has landed in the Neighbourhood (the HoodLanded attribute)
function Tier3Trip.landed(mask: number?): boolean
	return has(mask or 0, BIT.landed)
end

-- Whether a session ending now logs tier3_left: at Tier 3 and the landing not logged
function Tier3Trip.leftDue(mask: number?, tier: number): boolean
	return tier == Tier3Trip.TIER and not has(mask or 0, BIT.landed)
end

return Tier3Trip
