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
--   secondBowl(ownsPass) -> SecondBowl     "on" with the pass, "offer" (the Store shows the pass) without it
--   oddsCard(bowlLevel) -> { FoodOdds }    every shop and dealer food's odds at that level
-- The account's first bait (#1895, #2946, #3158, #3161):
--   firstWait(wait, luresUsed) -> number   its short wait
--   isFirst(placedAt, readyAt, luresUsed) -> boolean   whether the bait in the bowl is that one
--   catOutAt(placedAt, readyAt, luresUsed) -> number   when the bait's cat stands at the bowl
--   away(distance?) -> boolean             whether the player is too far from the bowl to have seen it arrive

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Bait = {}

Bait.BOWLS = 2

-- The second bowl for this player (#1161): "on" with the pass, "offer" without it (the Store shows the pass). It is
-- capacity, not a roll (Derek 2026-11-05, Monetization-Agent on #1436): Robux buys a second place to put food, the
-- food is bought with coins, coins are never sold and bowl 2 rolls exactly as bowl 1, so it is not a paid random item
-- and needs no PolicyService gate. That holds only while no Robux item sells bait food, coins or a bowl speed-up.
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

-- #1895: the wait for food going in now when the account has set `luresUsed` baits before: the account's first
-- bait waits at most FirstBaitWaitSeconds (5 seconds since #3161, so a first session sees its first bait cat), every later one
-- `wait` (Economy.baitWaitSeconds). Speed-ups only ever shorten it. No Robux buys it.
function Bait.firstWait(wait: number, luresUsed: number): number
	if luresUsed <= 0 then
		return math.min(wait, Config.FirstBaitWaitSeconds)
	end
	return wait
end

-- #3158, #3161: whether the bait in a bowl is the account's short first one (`luresUsed` counts it already): its
-- whole wait is FirstBaitWaitSeconds or less. Its cat's cutscene plays at the bowl, so the tutorial waits for that
-- cat to be tamed or let go before it moves on (BaitService), and the cat stands at the bowl early (catOutAt).
function Bait.isFirst(placedAt: number, readyAt: number, luresUsed: number): boolean
	return luresUsed <= 1 and readyAt - placedAt <= Config.FirstBaitWaitSeconds
end

-- When the bait's cat stands at the bowl for everyone to see: as its wait ends, or for the account's first bait
-- FirstBaitCatLeadSeconds sooner (never less than a second after the food went in), so the first bait's cutscene
-- shows it walking in and eating while the timer runs down (#3161). The Tame card still waits for `readyAt`.
function Bait.catOutAt(placedAt: number, readyAt: number, luresUsed: number): number
	if not Bait.isFirst(placedAt, readyAt, luresUsed) then
		return readyAt
	end
	return math.min(readyAt, math.max(placedAt + 1, readyAt - Config.FirstBaitCatLeadSeconds))
end

-- #3161: whether a player `distance` studs from their own bowl counts as away from it (nil: not known, so away), for
-- the first bait's "Your bait cat is here!" pop-up: at the bowl they have just watched the cat walk in.
Bait.AWAY_STUDS = 40

function Bait.away(distance: number?): boolean
	return distance == nil or distance > Bait.AWAY_STUDS
end

-- #1897 (first-hour.md section 2, Derek2 2026-11-06): each account's first bait (#2793, Derek2 2026-11-09: was the
-- second; an account that set baits before without one gets it on its next) brings a Rare-or-better cat once. A one-time first-session guarantee, logged in decisions.md as the exception to
-- "the same odds for everyone": the bowl's odds list is unchanged, every other roll is as it was, and bait is bought
-- with coins only, so this is not a paid random item.
Bait.WOW_EPIC_CHANCE = 0.15 -- a Common the guarantee lifts becomes Epic this often, else Rare

-- Whether the food going in now gets the guarantee: the account has not had it. #2793: from the first bait, so the
-- first "wow" lands seconds after the first food (FirstBaitWaitSeconds), before the 2 to 5 minute drop.
function Bait.wowDue(firstWow: boolean): boolean
	return not firstWow
end

-- The guaranteed roll's rarity: the bowl's normal roll, with a Common lifted to Rare (85%) or Epic (15%, `u` below
-- WOW_EPIC_CHANCE). Rare and better stay as rolled.
function Bait.wowRarity(rarity: Types.Rarity, u: number): Types.Rarity
	if rarity ~= "Common" then
		return rarity
	end
	return if u < Bait.WOW_EPIC_CHANCE then "Epic" else "Rare"
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

function Bait.secondBowl(ownsPass: boolean): SecondBowl
	return if ownsPass then "on" else "offer"
end

-- Each food's odds in a bowl of the player's level, the same Bait.oddsFor bowl 1's roll and its food cards use, so
-- the second bowl's odds are the first's (for a card that lists them all). Catalog order; each row sums to 100.
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
