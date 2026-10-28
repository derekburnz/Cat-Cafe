--!strict
-- The bait bowl's levels (F82, data-model section 8, v0.13.15). Each lure_bowl level shortens the day wait
-- (BowlWaitSeconds) and adds bowl luck (BowlLuck): that share of every rarity's chance moves up one rarity before
-- the roll, Mythical keeping its own. Pure, so UseLure's roll and every food card read the same odds and waits.
--   oddsFor(odds, bowlLevel) -> LureOdds   a food's odds in a bowl of that level, adding to the same total
--   luck(bowlLevel) -> number              the bowl's luck, 0 for level 1 or no bowl
--   waitSeconds(bowlLevel, bigBowl, night?) -> number   the day wait by level, a fifth off with the Big Bowl perk
--                                          (BigBowlWaitMultiplier), the LureWaitSecondsNight share of it at night;
--                                          the Index's and potions' baitSpeed come off after (Economy.baitWaitSeconds)
--   bowlName(bowlLevel) -> string          "Bait Bowl" to "Royal Bowl"

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Bait = {}

local NAMES = { "Bait Bowl", "Comfy Bowl", "Fancy Bowl", "Deluxe Bowl", "Royal Bowl" }

Bait.MAX_LEVEL = #Config.BowlWaitSeconds

-- A bowl level within 1 to MAX_LEVEL: no bowl (0) reads as a level 1 bowl, so a card shows the plain odds.
local function clampLevel(bowlLevel: number): number
	return math.clamp(math.floor(bowlLevel), 1, Bait.MAX_LEVEL)
end

function Bait.luck(bowlLevel: number): number
	return Config.BowlLuck[clampLevel(bowlLevel)] or 0
end

-- odds'[Common] = odds[Common] x (1 - luck); each rarity after keeps (1 - luck) of its own and gains luck of the one
-- below; Mythical keeps all of its own. Salmon in a Royal Bowl: Legendary 8.5 x 0.84 + 30 x 0.16 = 11.94.
function Bait.oddsFor(odds: Types.LureOdds, bowlLevel: number): Types.LureOdds
	local luck = Bait.luck(bowlLevel)
	local order = Catalog.rarityOrder
	local out: { [string]: number } = {}
	local below = 0
	for index, rarity in order do
		local own = (odds :: any)[rarity]
		local weight = if type(own) == "number" then own else 0
		local kept = if index < #order then weight * (1 - luck) else weight
		out[rarity] = kept + below * luck
		below = weight
	end
	return (out :: any) :: Types.LureOdds
end

function Bait.waitSeconds(bowlLevel: number, bigBowl: boolean, night: boolean?): number
	local wait = Config.BowlWaitSeconds[clampLevel(bowlLevel)]
	if bigBowl then
		wait *= Config.BigBowlWaitMultiplier
	end
	if night then
		wait = wait * Config.LureWaitSecondsNight / Config.LureWaitSeconds
	end
	-- a hair before flooring, so a tuned multiplier's float error never costs a whole second
	return math.floor(wait + 1e-6)
end

function Bait.bowlName(bowlLevel: number): string
	return NAMES[clampLevel(bowlLevel)] or NAMES[1]
end

return Bait
