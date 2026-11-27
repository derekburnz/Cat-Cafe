--!strict
-- #5665 part 2: Snowglobe Village's rules (snowglobe-village-spec sections 1 and 3), the Christmas Event's row of the
-- event areas (Catalog.isEventArea). Pure, so the cloud specs run it; SnowglobeService and TravelService apply it.
-- Harvest Hollow's numbers throughout (HarvestSave), with Snowflakes (profile.snowflakes, #5502) for pumpkins.
--   FLAG / AREA / TIER / OPENS_AT / CLOSES_AT  the switch (christmasEvent, off by default), the area id, the portal's
--                                       tier, and the dates: from Advent.FIRST_OPEN (Nov 29 2026 17:00 UTC) until
--                                       Advent.CLOSES (the end of Jan 3 2027)
--   open(now)                           whether the dates have the village open
--   areaBlocker(now, tier, flagOn)      why the village is shut for this player, or nil
--   fresh() / sanitize(raw)             profile.snowglobe: { visitDay = the UTC day of the last first-visit gift }.
--                                       No VERSION bump (as #5502's Snowflakes): an older server drops the field, so
--                                       the worst is a second +40 on a day
--   give(flakes, n) -> (flakes, added)  Snowflakes after adding n, capped at MAX_FLAKES
--   visit(save, flakes, now)            the day's first visit: (Snowflakes after, added), VISIT_FLAKES once a UTC day
--   catchFlakes(rarity)                 Snowflakes for a Christmas cat caught (Harvest's 1, 2, 3, 5, 10)
--   regrowSeconds(playersNear)          how long a picked snowflake takes to come back (Harvest's timings)
--   ODDS / STRAY_CAP / TOPUP_SECONDS    the strays (Harvest's)
-- Nothing is random here and nothing costs Robux.

local Advent = require(script.Parent.Advent)
local HarvestSave = require(script.Parent.HarvestSave)

local SnowglobeSave = {}

SnowglobeSave.FLAG = "christmasEvent"
SnowglobeSave.AREA = "snowglobe"
SnowglobeSave.TIER = 2
SnowglobeSave.OPENS_AT = Advent.FIRST_OPEN
SnowglobeSave.CLOSES_AT = Advent.CLOSES
SnowglobeSave.DAY = 86400
SnowglobeSave.VISIT_FLAKES = HarvestSave.VISIT_PUMPKINS -- 40
SnowglobeSave.MAX_FLAKES = 1000000000 -- ProfileSchema's cap on profile.snowflakes
SnowglobeSave.ODDS = HarvestSave.ODDS
SnowglobeSave.STRAY_CAP = HarvestSave.STRAY_CAP
SnowglobeSave.TOPUP_SECONDS = HarvestSave.TOPUP_SECONDS
SnowglobeSave.CLOSED = "Snowglobe Village is closed"

export type Save = { visitDay: number? }

function SnowglobeSave.open(now: number): boolean
	return now >= SnowglobeSave.OPENS_AT and now < SnowglobeSave.CLOSES_AT
end

function SnowglobeSave.areaBlocker(now: number, tier: number, flagOn: boolean): string?
	if not flagOn then
		return SnowglobeSave.CLOSED
	end
	if now < SnowglobeSave.OPENS_AT then
		return "Snowglobe Village opens Sun Nov 29"
	end
	if now >= SnowglobeSave.CLOSES_AT then
		return "Snowglobe Village is closed until next Christmas"
	end
	if tier < SnowglobeSave.TIER then
		return string.format("Snowglobe Village opens at Tier %d", SnowglobeSave.TIER)
	end
	return nil
end

function SnowglobeSave.fresh(): Save
	return {}
end

function SnowglobeSave.sanitize(raw: unknown): Save
	local out = SnowglobeSave.fresh()
	if type(raw) ~= "table" then
		return out
	end
	local day = (raw :: any).visitDay
	if type(day) == "number" and day == day and day >= 0 and day < 1e7 then
		out.visitDay = math.floor(day)
	end
	return out
end

function SnowglobeSave.give(flakes: number?, n: number): (number, number)
	local before = math.max(0, math.floor(flakes or 0))
	local after = math.min(SnowglobeSave.MAX_FLAKES, before + math.max(0, math.floor(n)))
	return after, after - before
end

function SnowglobeSave.visit(save: Save, flakes: number?, now: number): (number, number)
	local day = math.floor(now / SnowglobeSave.DAY)
	if save.visitDay == day then
		return math.max(0, math.floor(flakes or 0)), 0
	end
	save.visitDay = day
	return SnowglobeSave.give(flakes, SnowglobeSave.VISIT_FLAKES)
end

function SnowglobeSave.catchFlakes(rarity: string): number
	return HarvestSave.catchPumpkins(rarity)
end

function SnowglobeSave.regrowSeconds(playersNear: number): number
	return HarvestSave.regrowSeconds(playersNear)
end

return SnowglobeSave
