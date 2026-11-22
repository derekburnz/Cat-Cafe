--!strict
-- #5652 (Design-Agent's spec, from #5645; Growth Nov 19: 22 to 27% of Tier 3 players never land in the Neighbourhood,
-- and those who catch there reach Tier 4 82 to 84% of the time): behind the switch `hoodWelcome`
-- (LiveFlags.OFF_BY_DEFAULT). On an account's first Neighbourhood landing from Tier 3, one stray of a Neighbourhood
-- kind the player does not own waits near the camp landing (CatService, by tier3Path's waiting path). Its rarity is
-- the area's normal roll over the rarities that still have a kind the player lacks; with every kind owned none comes.
-- Its catch is the normal one (normal circle and rings, Derek #5637). One toast, no window, arrow, camera move or
-- teleport. Once per account (stats.hoodWelcome). Pure.
--   due(profile, on) -> boolean           the switch on, Tier 3 or higher and not had yet
--   rarity(collection, odds, roll) -> Rarity?   the waiting stray's rarity, or nil when every kind is owned
--   lacks(collection) -> boolean          whether a Neighbourhood kind is still missing

local Catalog = require(script.Parent.Catalog)
local Catching = require(script.Parent.Catching)
local Economy = require(script.Parent.Economy)
local Types = require(script.Parent.Types)

local HoodWelcome = {}

HoodWelcome.FLAG = "hoodWelcome"
HoodWelcome.AREA = "neighbourhood"
HoodWelcome.TIER = 3
HoodWelcome.STAT = "hoodWelcome" -- stats.hoodWelcome: 1 once shown (no save version: see ProfileSchema)
HoodWelcome.LANDED_STUDS = 60 -- the player's root this near the camp's landing counts as landed
HoodWelcome.TOAST = "A new kind is nearby"
HoodWelcome.EVENT = "hood_welcome" -- custom event; field "shown" or "caught", then the rarity

function HoodWelcome.due(profile: Types.PlayerProfile, on: boolean): boolean
	if not on or Economy.tier(profile) < HoodWelcome.TIER then
		return false
	end
	local had: unknown = (profile.stats :: any)[HoodWelcome.STAT]
	return not (type(had) == "number" and had > 0)
end

local function missing(collection: { [string]: any }, rarity: Types.Rarity): boolean
	for _, def in Catching.candidates(rarity, HoodWelcome.AREA) do
		if collection[def.id] == nil then
			return true
		end
	end
	return false
end

function HoodWelcome.lacks(collection: { [string]: any }): boolean
	for _, rarity in Catalog.rarityOrder do
		if missing(collection, rarity) then
			return true
		end
	end
	return false
end

-- The area's odds (percentages) over only the rarities with a kind still missing, rolled with `roll` (0 to 1).
function HoodWelcome.rarity(
	collection: { [string]: any },
	odds: { [string]: number },
	roll: number
): Types.Rarity?
	local open: { { rarity: Types.Rarity, weight: number } } = {}
	local total = 0
	for _, rarity in Catalog.rarityOrder do
		local weight = odds[rarity]
		if type(weight) == "number" and weight > 0 and missing(collection, rarity) then
			table.insert(open, { rarity = rarity, weight = weight })
			total += weight
		end
	end
	if total <= 0 then
		return nil
	end
	local at = math.clamp(roll, 0, 1) * total
	for _, entry in open do
		at -= entry.weight
		if at < 0 then
			return entry.rarity
		end
	end
	return open[#open].rarity
end

return HoodWelcome
