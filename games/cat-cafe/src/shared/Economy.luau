--!strict
-- Pure income math (data-model section 11) and purchase gates. No Roblox services.

local Bait = require(script.Parent.Bait)
local CatStats = require(script.Parent.CatStats)
local Catalog = require(script.Parent.Catalog)
local Catching = require(script.Parent.Catching)
local Clock = require(script.Parent.Clock)
local Config = require(script.Parent.Config)
local IndexRewards = require(script.Parent.IndexRewards)
local Pals = require(script.Parent.Pals)
local Potions = require(script.Parent.Potions)
local Types = require(script.Parent.Types)

local Economy = {}

-- What the player's game passes give (F95, economy-ladder.md section 6): `money` the Money pass multiplier (1, or 2,
-- 3 or 4, the highest owned), `longNap` the Long Nap pass's offline rate and cap, `slots` the extra role slots.
-- PassService checks ownership on the server at join and after a purchase; nothing is saved, so it lives in a
-- weak table keyed by the profile and a profile without an entry (the specs, the client) has no passes.
export type Passes = { money: number, longNap: boolean, slots: number }

local NO_PASSES: Passes = { money = 1, longNap = false, slots = 0 } -- shared; never changed
local passesByProfile: { [Types.PlayerProfile]: Passes } = setmetatable({}, { __mode = "k" }) :: any

-- Holds a copy, so the caller's table can change after. Nil clears them.
function Economy.setPasses(profile: Types.PlayerProfile, passes: Passes?)
	if passes == nil then
		passesByProfile[profile] = nil
		return
	end
	local p = passes :: Passes
	passesByProfile[profile] = { money = p.money, longNap = p.longNap, slots = p.slots }
end

function Economy.passes(profile: Types.PlayerProfile): Passes
	return passesByProfile[profile] or NO_PASSES
end

-- Pals on the server (F92, playing-together.md section 2), from PalService, held per profile for the session like
-- the passes (worked out each session, never saved). The caller settles before the count changes, so a window pays
-- one count throughout. `palEarned` keeps the coins the bonus added since Telemetry last took them (pal_bonus).
local palsByProfile: { [Types.PlayerProfile]: number } = setmetatable({}, { __mode = "k" }) :: any
local palEarnedByProfile: { [Types.PlayerProfile]: number } = setmetatable({}, { __mode = "k" }) :: any

function Economy.setPals(profile: Types.PlayerProfile, count: number)
	if count > 0 then
		palsByProfile[profile] = math.floor(count)
	else
		palsByProfile[profile] = nil
	end
end

function Economy.pals(profile: Types.PlayerProfile): number
	return palsByProfile[profile] or 0
end

-- The tip share the pals add: PalTipBonus with one, PalTipBonusMax with two or more.
function Economy.palBonus(profile: Types.PlayerProfile): number
	return Pals.bonus(Economy.pals(profile))
end

-- The coins the pal bonus paid since the last call, for Telemetry's pal_bonus source; resets to 0.
function Economy.takePalEarned(profile: Types.PlayerProfile): number
	local earned = palEarnedByProfile[profile] or 0
	palEarnedByProfile[profile] = nil
	return earned
end

-- Everything on top of the cafe's rate at `now`: the running tip potions (Potions.tipMultiplier, at most
-- TimedTipsMax) plus the pal bonus. Income, the tip piles and rich visitors use it; offline pay does not.
function Economy.tipMultiplier(profile: Types.PlayerProfile, now: number): number
	return Potions.tipMultiplier(profile, now) + Economy.palBonus(profile)
end

-- The Money pass multiplier on all cafe income, 1 without one.
function Economy.passMultiplier(profile: Types.PlayerProfile): number
	return math.max(1, Economy.passes(profile).money)
end

function Economy.level(profile: Types.PlayerProfile, upgradeId: string): number
	local def = Catalog.getUpgrade(upgradeId)
	local lvl = profile.upgradeLevels[upgradeId]
	if lvl ~= nil then
		return lvl
	end
	return if def ~= nil then def.startLevel else 0
end

-- The cafe tier, 1 to Catalog.maxTier (data-model section 5b). Nil-safe for fixtures that predate the field.
function Economy.tier(profile: Types.PlayerProfile): number
	local tier = (profile :: any).tier
	if type(tier) ~= "number" or tier ~= tier then
		return 1
	end
	return math.clamp(math.floor(tier), 1, Catalog.maxTier)
end

-- A food's price in coins at `tier` (F97, notes-10-28-to-10-30.md section 3): its Catalog base times
-- FoodTierPriceFactor at that tier, so Kibble is 100 at Tiers 1 and 2 and 1,600 at Tier 5. 0 for an unknown food.
function Economy.foodPrice(lureId: string, tier: number): number
	local def = Catalog.getLure(lureId)
	if def == nil then
		return 0
	end
	local factors = Config.FoodTierPriceFactor
	return def.cost * factors[math.clamp(math.floor(tier), 1, #factors)]
end

-- tierMultiplier in the income formula: 1.00 at Tier 1 up to 2.00 at Tier 5.
function Economy.tierMultiplier(profile: Types.PlayerProfile): number
	local def = Catalog.getTier(Economy.tier(profile))
	return if def ~= nil then def.multiplier else 1
end

-- Placed decor that another placed piece stands in for (N114): it stays out of the bonus and off the plot. Empty
-- since F54 retired the gold Index pieces, the only ones with `replaces`; kept so a future stand-in works the same.
function Economy.replacedDecor(profile: Types.PlayerProfile): { [string]: boolean }
	local replaced: { [string]: boolean } = {}
	for decorId, placed in profile.decorPlaced do
		local def = Catalog.getDecor(decorId)
		if placed and def ~= nil and def.replaces ~= nil and profile.decorOwned[decorId] then
			replaced[def.replaces] = true
		end
	end
	return replaced
end

-- cafeMultiplier = 1 + 0.10 x tables + 0.15 x (espresso - 1) + placed decor bonuses, plus GoldenEspressoBonus per
-- Golden Espresso level (F53) and the tips forever of every claimed Index milestone (F54, a full Decor Index
-- page's decor10 among them)
function Economy.cafeMultiplier(profile: Types.PlayerProfile): number
	local multiplier = 1 + Config.TableBonus * Economy.level(profile, "tables")
	multiplier += Config.EspressoBonus * math.max(0, Economy.level(profile, "espresso") - 1)
	local replaced = Economy.replacedDecor(profile)
	for decorId, placed in profile.decorPlaced do
		local def = Catalog.getDecor(decorId)
		if placed and def ~= nil and profile.decorOwned[decorId] and not replaced[decorId] then
			multiplier += def.bonus
		end
	end
	multiplier += Config.GoldenEspressoBonus * (profile.fishPerks.golden_espresso or 0)
	multiplier += IndexRewards.totals(profile).bonus
	return multiplier
end

-- How long the bait bowl's cat takes to come (data-model section 8): the bowl level's wait (F82: 600 down to 480), a
-- BigBowlWaitCutSeconds off with the Big Bowl perk (F53; F95: 2 minutes), and for food set at night LureWaitSecondsNight's share of it (F60: half).
function Economy.lureWaitSeconds(profile: Types.PlayerProfile, night: boolean?): number
	return Bait.waitSeconds(
		Economy.level(profile, "lure_bowl"),
		(profile.fishPerks.big_bowl or 0) >= 1,
		night
	)
end

-- The wait for food going in now: lureWaitSeconds less the Index's bait speed (F54, golden-fish.md section 5),
-- whole seconds. UseLure fixes it in the bowl's readyAt. The summed percents carry float error (the full All Cats
-- track is 0.38000000000000012), so a hair is added before flooring: 372 s, not 371 (QA, 2026-10-27). `night` is
-- the server's phase as the food goes in (F60). With `now`, a running Quick Bait Potion's speed adds to the Index's,
-- the two together inside BaitSpeedMax (F73).
function Economy.baitWaitSeconds(
	profile: Types.PlayerProfile,
	night: boolean?,
	now: number?
): number
	local speed = IndexRewards.totals(profile).baitSpeed
	if now ~= nil then
		speed = math.min(speed + Potions.baitSpeed(profile, now), Config.BaitSpeedMax)
	end
	return math.floor(Economy.lureWaitSeconds(profile, night) * (1 - speed) + 1e-6)
end

-- Rate of one working cat before the cafe multiplier: its rating for an owner at `tier` (rarity x area x charm x
-- level x variant, see CatStats) times the favorite role bonus (data-model section 11). Resting cats earn nothing.
function Economy.catRate(instance: Types.CatInstance, tier: number?): number
	local def = Catalog.getCat(instance.catId)
	if def == nil or instance.spotId == nil then
		return 0
	end
	local spot = Catalog.getSpot(instance.spotId :: string)
	if spot == nil then
		return 0
	end
	local favorite = if spot.spotType == def.favoriteRole then Config.FavoriteMultiplier else 1
	return CatStats.rating(instance, tier) * favorite
end

function Economy.variantMultiplier(variant: string): number
	return CatStats.variantMultiplier(variant)
end

-- incomePerSecond = sum over working cats of (rating x favorite) x cafeMultiplier x tierMultiplier x passMultiplier
-- (F95). The whole income formula lives here, so the night multiplier and a customer-driven model change one
-- function. The pass multiplies whatever the potions add in settle, so 4x with a Big Money Potion is 6x, and the
-- tip piles, rich visitors and coin prizes that read the day rate scale with it.
function Economy.incomePerSecond(profile: Types.PlayerProfile): number
	local total = 0
	for _, instance in profile.cats do
		total += Economy.catRate(instance, profile.tier)
	end
	return total
		* Economy.cafeMultiplier(profile)
		* Economy.tierMultiplier(profile)
		* Economy.passMultiplier(profile)
end

-- A Corner Shop row's coin price (corner-shop.md section 2, #1052): `row.seconds` of `dayRate` (incomePerSecond: the
-- cats, the cafe and the money pass in, running potions out), never under `row.atLeast`. The server and the window
-- show the same number.
function Economy.cornerPrice(row: Types.CornerShopRow, dayRate: number): number
	return math.max(row.atLeast, math.floor(row.seconds * math.max(dayRate, 0)))
end

-- XP a second for one owned cat (data-model section 4b, v0.12 F75): a working cat earns CatXpPerSecondPlaced, times
-- CatXpFavoriteMultiplier in its favorite role, and a resting cat CatXpPerSecondResting. Rarity does not change it,
-- and night does not either (a napping working cat still counts as working).
function Economy.catXpRate(instance: Types.CatInstance): number
	local spot = if instance.spotId ~= nil then Catalog.getSpot(instance.spotId :: string) else nil
	if spot == nil then
		return Config.CatXpPerSecondResting
	end
	local def = Catalog.getCat(instance.catId)
	local favorite = if def ~= nil and spot.spotType == def.favoriteRole
		then Config.CatXpFavoriteMultiplier
		else 1
	return Config.CatXpPerSecondPlaced * favorite
end

-- Every owned cat earns XP for the settled time at its catXpRate. Only online time is settled: DataService.load
-- resets lastTick before the first settle, so the offline gap earns neither coins at the online rate nor XP. Every
-- level gained counts in stats.catLevelUps. Returns the number of levels gained.
function Economy.grantXp(profile: Types.PlayerProfile, seconds: number): number
	if seconds <= 0 then
		return 0
	end
	local gained = 0
	for _, instance in profile.cats do
		gained += CatStats.addXp(instance, seconds * Economy.catXpRate(instance))
	end
	if gained > 0 then
		profile.stats.catLevelUps = (profile.stats.catLevelUps or 0) + gained
	end
	return gained
end

-- The share of the day rate a cafe earns in this phase: 1 by day, NightIncomeMultiplier by night (section 11).
function Economy.phaseMultiplier(phase: Types.ClockPhase): number
	return if phase == "night" then Config.NightIncomeMultiplier else 1
end

-- Seconds of [from, from + seconds] weighted by the phase pay: a night second counts NightIncomeMultiplier.
local function paidSecondsFrom(from: number, seconds: number, clockEpoch: number?): number
	local nightSeconds = if clockEpoch ~= nil
		then math.clamp(
			Clock.nightSecondsBetween(from - clockEpoch, from + seconds - clockEpoch),
			0,
			seconds
		)
		else 0
	return seconds - nightSeconds + nightSeconds * Config.NightIncomeMultiplier
end

-- The extra paid seconds the running tip potions add to a window of `elapsed` from lastTick: each potion's `tips` over
-- the start it covers, split where each ends, the running sum capped at TimedTipsMax.
local function tipBonusSeconds(
	profile: Types.PlayerProfile,
	elapsed: number,
	clockEpoch: number?
): number
	type Span = { seconds: number, tips: number }
	local spans: { Span } = {}
	local total = 0
	for _, def in Catalog.potions do
		local tips = def.tips
		if tips ~= nil then
			local seconds = math.min(elapsed, Potions.left(profile, def.id, profile.lastTick))
			if seconds > 0 then
				table.insert(spans, { seconds = seconds, tips = tips })
				total += tips
			end
		end
	end
	table.sort(spans, function(a: Span, b: Span): boolean
		return a.seconds < b.seconds
	end)
	local bonus, from = 0, 0
	for _, span in spans do
		if span.seconds > from then
			bonus += math.min(total, Config.TimedTipsMax) * paidSecondsFrom(
				profile.lastTick + from,
				span.seconds - from,
				clockEpoch
			)
			from = span.seconds
		end
		total -= span.tips
	end
	return bonus
end

-- Lazy accounting: credit everything earned since lastTick, then grant that time as XP to the owned cats.
-- Coins use the rate from before any level-up in the window (a few seconds at most), which keeps the
-- credit simple and never overpays. Call before any read or spend.
-- `clockEpoch` is the os.time() at which the server's clock started (ClockService.epoch): the window is split at
-- phase boundaries and its night part pays NightIncomeMultiplier (section 11). Without it the whole window pays
-- the day rate, which only the specs and offline maths want.
-- F64: a running Tip Potion pays TipPotionBonus more over the start of the window it covers, split where it ends
-- like a phase change, and every potion timer counts down by the window (play time only: DataService.load resets
-- lastTick, so time away settles nothing and the timers pause). F73: every potion with `tips` (the Big Tip Potion
-- too) pays its own share the same way, the shares together at most TimedTipsMax at any moment. F92: with pals on
-- the server the window pays palBonus more on top, counted for Telemetry's pal_bonus.
function Economy.settle(profile: Types.PlayerProfile, now: number, clockEpoch: number?): number
	local elapsed = math.max(0, now - profile.lastTick)
	local earned = 0
	if elapsed > 0 then
		local base = paidSecondsFrom(profile.lastTick, elapsed, clockEpoch)
		local paidSeconds = base + tipBonusSeconds(profile, elapsed, clockEpoch)
		local rate = Economy.incomePerSecond(profile)
		-- F92: the pal bonus over the whole window; the caller settled when the pal count last changed
		local palCoins = rate * base * Economy.palBonus(profile)
		earned = rate * paidSeconds + palCoins
		if palCoins > 0 then
			palEarnedByProfile[profile] = (palEarnedByProfile[profile] or 0) + palCoins
		end
		profile.coins += earned
		profile.lifetimeCoins += earned
		Economy.grantXp(profile, elapsed)
		Potions.tick(profile, elapsed)
	end
	profile.lastTick = now
	return earned
end

-- A rich customer's tip (section 12): RichTipSeconds of the day rate, never less than $50.
function Economy.richTipAmount(dayRate: number): number
	return math.max(50, math.floor(dayRate * Config.RichTipSeconds))
end

-- One tip pile (F61, section 12): TipPileRateSeconds of the day rate, never less than $5.
function Economy.tipPileAmount(dayRate: number): number
	return math.max(5, math.floor(dayRate * Config.TipPileRateSeconds))
end

-- Offline pay at join (F95, economy-ladder.md section 5): the day rate at logout (no potions, the Money pass in)
-- times OfflineRate for up to OfflineCapSeconds away, or with the Long Nap pass OfflineRatePass for up to
-- OfflineCapPassSeconds. Returns the coins and the seconds counted.
function Economy.offlineGain(
	rateAtLogout: number,
	lastSeen: number,
	now: number,
	longNap: boolean?
): (number, number)
	local rate = if longNap then Config.OfflineRatePass else Config.OfflineRate
	local cap = if longNap then Config.OfflineCapPassSeconds else Config.OfflineCapSeconds
	local seconds = math.clamp(now - lastSeen, 0, cap)
	return math.floor(rateAtLogout * rate * seconds), seconds
end

function Economy.canAfford(profile: Types.PlayerProfile, cost: number): boolean
	return cost >= 0 and profile.coins >= cost
end

-- Spends if affordable. Returns false and leaves coins alone otherwise.
function Economy.trySpend(profile: Types.PlayerProfile, cost: number): boolean
	if not Economy.canAfford(profile, cost) then
		return false
	end
	profile.coins -= cost
	return true
end

function Economy.credit(profile: Types.PlayerProfile, amount: number)
	profile.coins += amount
	profile.lifetimeCoins += amount
end

-- Cost of the next level of an upgrade, or nil when maxed.
function Economy.nextUpgradeCost(profile: Types.PlayerProfile, upgradeId: string): number?
	local def = Catalog.getUpgrade(upgradeId)
	if def == nil then
		return nil
	end
	local lvl = Economy.level(profile, upgradeId)
	if lvl >= def.maxLevel then
		return nil
	end
	return def.costs[lvl + 1]
end

-- Returns nil when the upgrade can be bought, else a short reason for a toast.
function Economy.upgradeBlocker(profile: Types.PlayerProfile, upgradeId: string): string?
	local def = Catalog.getUpgrade(upgradeId)
	if def == nil then
		return "Unknown upgrade"
	end
	local lvl = Economy.level(profile, upgradeId)
	if lvl >= def.maxLevel then
		return "Already maxed"
	end
	local nextLevel = lvl + 1
	local tier = Economy.tier(profile)
	if def.requiresTier ~= nil and tier < def.requiresTier then
		return string.format("Needs Tier %d", def.requiresTier)
	end
	local perLevel = def.requiresTierAtLevel
	if perLevel ~= nil and perLevel[nextLevel] ~= nil and tier < perLevel[nextLevel] then
		return string.format("Needs Tier %d", perLevel[nextLevel])
	end
	if not Economy.canAfford(profile, def.costs[nextLevel]) then
		return "Not enough coins"
	end
	return nil
end

function Economy.decorBlocker(profile: Types.PlayerProfile, decorId: string): string?
	local def = Catalog.getDecor(decorId)
	if def == nil then
		return "Unknown decor"
	end
	if def.source == "crate" then
		return "Found in Cafe Crates, not for sale"
	end
	if profile.decorOwned[decorId] then
		return "Already owned"
	end
	if def.requiresTier ~= nil and Economy.tier(profile) < def.requiresTier then
		return string.format("Needs Tier %d", def.requiresTier)
	end
	if not Economy.canAfford(profile, def.cost) then
		return "Not enough coins"
	end
	return nil
end

-- Different cats ever caught: entries in the collection (a gold cat is not a second entry). A shop-only cat
-- (`exclusive`, F95) is not one, so ranking up still needs catching.
function Economy.distinctCats(profile: Types.PlayerProfile): number
	local n = 0
	for catId in profile.collection do
		local def = Catalog.getCat(catId)
		if def == nil or def.exclusive ~= true then
			n += 1
		end
	end
	return n
end

-- Different cats of this rarity or rarer in the collection, for the Tier 3 to 5 requirement (data-model 5b:
-- "one Epic" means one Epic or better, so a Legendary counts).
function Economy.distinctCatsAtLeast(profile: Types.PlayerProfile, rarity: Types.Rarity): number
	local n = 0
	for catId in profile.collection do
		local def = Catalog.getCat(catId)
		if def ~= nil and def.exclusive ~= true and Catching.rarityAtLeast(def.rarity, rarity) then
			n += 1
		end
	end
	return n
end

-- Returns nil when RankUp would succeed, else a short reason for a toast (data-model section 5b). Checked in the
-- order a player works through them: cats, the rarity, then coins.
function Economy.rankUpBlocker(profile: Types.PlayerProfile): string?
	local nextTier = Catalog.getTier(Economy.tier(profile) + 1)
	if nextTier == nil then
		return "Your cafe is already a " .. (Catalog.getTier(Catalog.maxTier) :: Types.TierDef).name
	end
	local cats = Economy.distinctCats(profile)
	if cats < nextTier.distinctCats then
		return string.format("Needs %d different cats (you have %d)", nextTier.distinctCats, cats)
	end
	local rarity: Types.Rarity? = nextTier.needsRarity
	if rarity ~= nil then
		local need = nextTier.needsRarityCount or 1
		if Economy.distinctCatsAtLeast(profile, rarity) < need then
			return if need == 1
				then string.format("Needs one cat, %s or better", rarity)
				else string.format("Needs %d different cats, %s or better", need, rarity)
		end
	end
	if not Economy.canAfford(profile, nextTier.cost) then
		return "Not enough coins"
	end
	return nil
end

function Economy.spotIsOpen(profile: Types.PlayerProfile, spotId: string): boolean
	local spot = Catalog.getSpot(spotId)
	return spot ~= nil and Economy.tier(profile) >= spot.tier
end

function Economy.catOnSpot(profile: Types.PlayerProfile, spotId: string): Types.CatInstance?
	for _, instance in profile.cats do
		if instance.spotId == spotId then
			return instance
		end
	end
	return nil
end

function Economy.seats(profile: Types.PlayerProfile): number
	return Config.SeatsPerTable * Economy.level(profile, "tables")
end

-- Counts per catId for the UI's catsOwned.
function Economy.countsByCat(profile: Types.PlayerProfile): { [string]: { count: number } }
	local counts: { [string]: { count: number } } = {}
	for _, instance in profile.cats do
		local entry = counts[instance.catId]
		if entry == nil then
			counts[instance.catId] = { count = 1 }
		else
			entry.count += 1
		end
	end
	return counts
end

return Economy
