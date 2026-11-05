--!strict
-- The bait bowl's levels (F82, data-model section 8, v0.13.15). Each lure_bowl level shortens the day wait
-- (BowlWaitSeconds) and adds bowl luck (BowlLuck): that share of every rarity's chance moves up one rarity before
-- the roll, Mythical keeping its own. Pure, so UseLure's roll and every food card read the same odds and waits.
--   oddsFor(odds, bowlLevel) -> LureOdds   a food's odds in a bowl of that level, adding to the same total
--   luck(bowlLevel) -> number              the bowl's luck, 0 for level 1 or no bowl
--   waitSeconds(bowlLevel, bigBowl, night?) -> number   the day wait by level, 2 minutes off with the Big Bowl perk
--                                          (BigBowlWaitCutSeconds, F95), the LureWaitSecondsNight share of it at night;
--                                          the Index's and potions' baitSpeed come off after (Economy.baitWaitSeconds)
--   bowlName(bowlLevel) -> string          "Bait Bowl" to "Royal Bowl"
-- The Second Bait Bowl pass (#1161): a second bowl at the same level, its own food, wait and cat, in profile.bait2.
--   BOWLS                                  2, the most bowls a cafe has
--   stateOf(profile, bowl) -> BaitState?   bowl 1's or bowl 2's bait
--   setState(profile, bowl, state?)        puts or clears it
--   secondBowl(ownsPass, allowed) -> SecondBowl   "on", "offer" (the pass card shows) or "hidden" (no card, no bowl 2)
--   oddsCard(bowlLevel) -> { FoodOdds }    every shop and dealer food's odds at that level, for the pass card

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Bait = {}

Bait.BOWLS = 2

-- The second bowl for this player (#1161): "on" with the pass, "offer" without it (the shop shows the pass card),
-- "hidden" where Roblox restricts paid random items for the player or the PolicyService answer is not in (yet or
-- at all): the second bowl doubles the random cats, so it is a paid random item (Derek 2026-11-05, monetization-
-- policy section 2).
export type SecondBowl = Types.SecondBowl

-- A food's odds at a bowl level, as the pass card lists them.
export type FoodOdds = { lureId: string, name: string, odds: Types.LureOdds }

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
		wait = math.max(0, wait - Config.BigBowlWaitCutSeconds)
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

-- Bowl 1's bait is profile.bait (every save since version 3) and bowl 2's profile.bait2 (version 34).
function Bait.stateOf(profile: Types.PlayerProfile, bowl: number): Types.BaitState?
	return if bowl == 2 then profile.bait2 else profile.bait
end

function Bait.setState(profile: Types.PlayerProfile, bowl: number, state: Types.BaitState?)
	if bowl == 2 then
		profile.bait2 = state
	else
		profile.bait = state
	end
end

-- `allowed` is true only once PolicyService has answered and paid random items are not restricted for the player.
function Bait.secondBowl(ownsPass: boolean, allowed: boolean): SecondBowl
	if not allowed then
		return "hidden"
	end
	return if ownsPass then "on" else "offer"
end

-- The odds the pass card shows before purchase (monetization-policy section 2): each food's odds in a bowl of the
-- player's level, the same Bait.oddsFor bowl 1's roll and its food cards use, so the second bowl's odds are the
-- first's. Catalog order; each row sums to 100.
function Bait.oddsCard(bowlLevel: number): { FoodOdds }
	local rows: { FoodOdds } = {}
	for _, lure in Catalog.lures do
		table.insert(
			rows,
			{ lureId = lure.id, name = lure.name, odds = Bait.oddsFor(lure.odds, bowlLevel) }
		)
	end
	return rows
end

return Bait
