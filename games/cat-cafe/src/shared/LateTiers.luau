--!strict
-- #3997: Tier 8 (the Summit Cafe and the Snowy Mountain) waits for the `tier8` live switch. It goes on only once the
-- area is built and no server older than the publish that added it is running, since an older server's save check
-- clamps a saved tier to 7 and drops a cat or decor id it does not know. Until then nobody ranks up past Tier 7, and
-- the pity cats and event showers never pick the Snowy Mountain. Read from the switch's ReplicatedStorage attribute,
-- which LiveFlagService sets on the server for both sides; specs set it here.
local Catalog = require(script.Parent.Catalog)
local LiveFlags = require(script.Parent.LiveFlags)

local LateTiers = {}

LateTiers.FLAG = "tier8"
LateTiers.FIRST = 8 -- the first tier behind the switch

local override: boolean? = nil
function LateTiers.setOpen(open: boolean?)
	override = open
end

function LateTiers.open(): boolean
	if override ~= nil then
		return override
	end
	return game:GetService("ReplicatedStorage")
		:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. LateTiers.FLAG) == true
end

-- Whether a player can reach `tier` now.
function LateTiers.tierOpen(tier: number): boolean
	return tier < LateTiers.FIRST or LateTiers.open()
end

-- Whether an area's tier is open now (an unknown area is not).
function LateTiers.areaOpen(areaId: string): boolean
	local area = Catalog.getArea(areaId)
	return area ~= nil and LateTiers.tierOpen(area.tier)
end

-- The highest tier a player can reach now.
function LateTiers.topTier(): number
	return if LateTiers.open()
		then Catalog.maxTier
		else math.min(Catalog.maxTier, LateTiers.FIRST - 1)
end

return LateTiers
