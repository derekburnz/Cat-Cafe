--!strict
-- #3997: Tier 8 (the Summit Cafe and the Snowy Mountain) waits for the `tier8` live switch, and each later tier for its
-- own (Tier 9, the Water Park, for `tier9`). A switch goes on only once its area is built and no server older than the
-- publish that added the tier is running, since an older server's save check clamps a saved tier to the last one it
-- knows and drops a cat or decor id it does not know. Until then nobody ranks up past the tier before it, and the pity
-- cats and event showers never pick its area. A tier is open only when every switch up to its own is on, so Tier 9
-- never opens ahead of Tier 8. Read from each switch's ReplicatedStorage attribute, which LiveFlagService sets on the
-- server for both sides; specs set it here.
local Catalog = require(script.Parent.Catalog)
local LiveFlags = require(script.Parent.LiveFlags)

local LateTiers = {}

LateTiers.FLAG = "tier8"
LateTiers.FIRST = 8 -- the first tier behind a switch
-- each tier's own switch, from FIRST up with no gap; a tier past the list has none and opens with the last one
LateTiers.FLAGS = table.freeze({
	[8] = "tier8",
	[9] = "tier9",
} :: { [number]: string })

-- Specs: true opens every tier, false none, a number every tier up to it, nil goes back to the switches.
local override: (boolean | number)? = nil
function LateTiers.setOpen(open: (boolean | number)?)
	override = open
end

local function flagOn(flag: string): boolean
	return game:GetService("ReplicatedStorage"):GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. flag)
		== true
end

-- The highest tier the switches let a player reach now (FIRST - 1 while the first one is off), whatever the catalog holds.
local function openThrough(): number
	if override == true then
		return math.huge
	elseif override == false then
		return LateTiers.FIRST - 1
	elseif type(override) == "number" then
		return math.max(override, LateTiers.FIRST - 1)
	end
	local tier = LateTiers.FIRST
	while LateTiers.FLAGS[tier] ~= nil do
		if not flagOn(LateTiers.FLAGS[tier]) then
			return tier - 1
		end
		tier += 1
	end
	return math.huge
end

-- Whether Tier 8 is open (the first switch).
function LateTiers.open(): boolean
	return openThrough() >= LateTiers.FIRST
end

-- Whether a player can reach `tier` now.
function LateTiers.tierOpen(tier: number): boolean
	return tier <= openThrough()
end

-- Whether an area's tier is open now (an unknown area is not).
function LateTiers.areaOpen(areaId: string): boolean
	local area = Catalog.getArea(areaId)
	return area ~= nil and LateTiers.tierOpen(area.tier)
end

-- The highest tier a player can reach now.
function LateTiers.topTier(): number
	return math.min(Catalog.maxTier, openThrough())
end

return LateTiers
