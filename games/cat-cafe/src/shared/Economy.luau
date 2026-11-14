--!strict
-- Pure income math (data-model section 11) and purchase gates. No Roblox services.

local Bait = require(script.Parent.Bait)
local CatStats = require(script.Parent.CatStats)
local Catalog = require(script.Parent.Catalog)
local Catching = require(script.Parent.Catching)
local Clock = require(script.Parent.Clock)
local Config = require(script.Parent.Config)
local IndexRewards = require(script.Parent.IndexRewards)
local LateTiers = require(script.Parent.LateTiers)
local Lawn = require(script.Parent.Lawn)
local Pals = require(script.Parent.Pals)
local Pet = require(script.Parent.Pet)
local Potions = require(script.Parent.Potions)
local StationPerks = require(script.Parent.StationPerks)
local StorePacks = require(script.Parent.StorePacks)
local Traits = require(script.Parent.Traits)
local Types = require(script.Parent.Types)

local Economy = {}

-- What the player's game passes give (F95, economy-ladder.md section 6): `money` the Money pass multiplier (1, or 2,
-- 3 or 4, the highest owned), `longNap` the Long Nap pass's offline rate and cap, `slots` the extra role slots,
-- `secondBowl` the Second Bait Bowl pass (#1161; nil is not owned, and PolicyService still gates the bowl), and the
-- five store passes (#1624, economy-ladder.md section 6a): `vip`, `accessories`, `uniforms`, `cafeStyle` and `grand`
-- (nil is not owned). PassService checks ownership on the server at join and after a purchase; nothing is saved, so
-- it lives in a weak table keyed by the profile and a profile without an entry (the specs, the client) has no passes.
export type Passes = {
	money: number,
	longNap: boolean,
	slots: number,
	secondBowl: boolean?,
	vip: boolean?,
	accessories: boolean?,
	uniforms: boolean?,
	cafeStyle: boolean?,
	grand: boolean?,
	packs: { [string]: boolean }?, -- #4026: the outfit packs owned, by StorePacks key
}

local NO_PASSES: Passes = { money = 1, longNap = false, slots = 0 } -- shared; never changed
local passesByProfile: { [Types.PlayerProfile]: Passes } = setmetatable({}, { __mode = "k" }) :: any

-- Holds a copy, so the caller's table can change after. Nil clears them.
function Economy.setPasses(profile: Types.PlayerProfile, passes: Passes?)
	if passes == nil then
		passesByProfile[profile] = nil
		return
	end
	local p = passes :: Passes
	passesByProfile[profile] = {
		money = p.money,
		longNap = p.longNap,
		slots = p.slots,
		secondBowl = p.secondBowl == true or nil,
		vip = p.vip == true or nil,
		accessories = p.accessories == true or nil,
		uniforms = p.uniforms == true or nil,
		cafeStyle = p.cafeStyle == true or nil,
		grand = p.grand == true or nil,
		packs = if p.packs ~= nil and next(p.packs) ~= nil then table.clone(p.packs) else nil,
	}
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

-- The tip share the pals add (Pals.bonus): PalTipBonus with one, PalTipBonusStep more each, at most PalTipBonusMax.
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

-- The Money pass multiplier on all cafe income, 1 without one. #2850: a bought once-per-account product with a
-- prize.moneyMultiplier (the Starter Bundle's 2x) counts too; the highest one wins, they never stack.
function Economy.passMultiplier(profile: Types.PlayerProfile): number
	local best = math.max(1, Economy.passes(profile).money)
	local once = profile.onceBought
	if once ~= nil then
		for _, product in Catalog.products do
			local x = product.prize.moneyMultiplier
			if x ~= nil and x > best and once[product.id] == true then
				best = x
			end
		end
	end
	return best
end

-- #1624 (economy-ladder.md section 6a): what VIP, Cafe Style and Grand Cafe add into cafeMultiplier, 0 without them.
function Economy.passCafeBonus(profile: Types.PlayerProfile): number
	local passes = Economy.passes(profile)
	local bonus = 0
	if passes.vip == true then
		bonus += Config.VipCafeBonus
	end
	if passes.cafeStyle == true then
		bonus += Config.CafeStyleCafeBonus
	end
	if passes.grand == true then
		bonus += Config.GrandCafeBonus
	end
	return bonus
end

-- #4026: what the outfit packs owned add into cafeMultiplier while their pieces are in use (StorePacks.bonus; their
-- decor counts with the other decor). 0 without a pack.
function Economy.packBonus(profile: Types.PlayerProfile): number
	local packs = Economy.passes(profile).packs
	if packs == nil then
		return 0
	end
	return StorePacks.bonus(profile, function(key: string): boolean
		return packs[key] == true
	end)
end

-- #1624: Cat Accessories and Uniform Styles, each a multiplier on every working cat's rate (a dressed working cat
-- earns x1.3225 with both); 1 without them. Every working cat wears its role's outfit, so each one counts as dressed.
function Economy.staffMultiplier(profile: Types.PlayerProfile): number
	local passes = Economy.passes(profile)
	local multiplier = 1
	if passes.accessories == true then
		multiplier *= Config.AccessoriesStaffMultiplier
	end
	if passes.uniforms == true then
		multiplier *= Config.UniformsStaffMultiplier
	end
	return multiplier
end

-- #1624 (section 6a v2.4): how many times as often rich visitors come, 1 + Cafe Style's 0.25 + Grand Cafe's 1.0.
-- RichTipService divides each drawn wait by it.
function Economy.richRate(profile: Types.PlayerProfile): number
	local passes = Economy.passes(profile)
	local rate = 1
	if passes.cafeStyle == true then
		rate += Config.CafeStyleRichRate
	end
	if passes.grand == true then
		rate += Config.GrandRichRate
	end
	return rate + Economy.traitBonus(profile, "richRate") -- #3871: Rich Friend and the combos that hold it
end

-- #3871: a cafe-wide trait effect (bowl luck, speed, rich visitor rate) from the cats in a staff slot, the best
-- Traits.KINDS[kind].best of them, at most its cap (Traits.cafeBonus). 0 for none.
function Economy.traitBonus(profile: Types.PlayerProfile, kind: Traits.Kind): number
	local working: { Traits.Trait } = {}
	for _, instance in profile.cats do
		local trait = instance.trait
		if instance.spotId ~= nil and trait ~= nil then
			table.insert(working, trait)
		end
	end
	return if #working > 0 then Traits.cafeBonus(working, kind) else 0
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
	if def.source == "cart" then
		return def.cost -- #3462: the Day Cart's own baits cost the same at every tier
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

-- lawn-nursery.md section 6a (#1283): the money bonus of the lawn pieces and styles out, by rarity
-- (Config.LawnRarityBonus, shared/Lawn.bonusOf). A profile from before the lawn (save version 28) has none.
function Economy.lawnBonus(profile: Types.PlayerProfile): number
	local raw = profile :: any
	if
		type(raw.lawnOwned) ~= "table"
		or type(raw.lawn) ~= "table"
		or type(raw.lawnStyles) ~= "table"
	then
		return 0
	end
	return (Lawn.bonus(profile))
end

-- cafeMultiplier = 1 + 0.10 x tables + 0.15 x (espresso - 1) + placed decor bonuses, plus GoldenEspressoBonus per
-- Golden Espresso level (F53), the tips forever of every claimed Index milestone (F54, a full Decor Index page's
-- decor10 among them), the front lawn's pieces and styles out (#1283, Economy.lawnBonus) and the store passes'
-- cafe bonus (#1624, Economy.passCafeBonus)
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
	multiplier += Economy.lawnBonus(profile)
	multiplier += Economy.passCafeBonus(profile)
	multiplier += Economy.packBonus(profile)
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
	-- #2687: the Picnic Basket's Fresh Bait from Tier 2
	local speed = math.min(
		IndexRewards.totals(profile).baitSpeed + StationPerks.baitSpeed(profile.tier),
		Config.BaitSpeedMax
	)
	if now ~= nil then
		speed = math.min(speed + Potions.baitSpeed(profile, now), Config.BaitSpeedMax)
	end
	return math.floor(Economy.lureWaitSeconds(profile, night) * (1 - speed) + 1e-6)
end

-- Rate of one working cat before the cafe multiplier: its rating for an owner at `tier` (rarity x area x charm x
-- level x variant, see CatStats) times the favorite role bonus (data-model section 11) times its trait's income
-- (#3871; night income is paid on top in settle, Economy.nightTraitRate). Resting cats earn nothing.
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
	return CatStats.rating(instance, tier)
		* favorite
		* Traits.incomeMultiplier(instance.trait, false)
end

function Economy.variantMultiplier(variant: string): number
	return CatStats.variantMultiplier(variant)
end

-- incomePerSecond = sum over working cats of (rating x favorite) x staffMultiplier x cafeMultiplier x tierMultiplier
-- x passMultiplier
-- (F95). The whole income formula lives here, so the night multiplier and a customer-driven model change one
-- function. The pass multiplies whatever the potions add in settle, so 4x with a Big Money Potion is 6x, and the
-- tip piles, rich visitors and coin prizes that read the day rate scale with it.
local function cafeRate(profile: Types.PlayerProfile, total: number): number
	return total
		* Economy.staffMultiplier(profile)
		* Economy.cafeMultiplier(profile)
		* Economy.tierMultiplier(profile)
		* Economy.passMultiplier(profile)
		* StationPerks.tipMultiplier(profile.tier) -- #2687: the Relic Museum's Curator from Tier 7
end

function Economy.incomePerSecond(profile: Types.PlayerProfile): number
	local total = 0
	for _, instance in profile.cats do
		total += Economy.catRate(instance, profile.tier)
	end
	return cafeRate(profile, total)
end

-- #3871: the extra day rate a second the working cats' night income traits add while it is night (Night Owl and the
-- combos that hold it): each cat's rate without its trait x its nightIncome, through the same multipliers. settle
-- pays it over the night part of a window, at NightIncomeMultiplier like the rest of the night's pay.
function Economy.nightTraitRate(profile: Types.PlayerProfile): number
	local total = 0
	for _, instance in profile.cats do
		local extra = Traits.amount(instance.trait, "nightIncome")
		if extra > 0 then
			local rate = Economy.catRate(instance, profile.tier)
			total += rate / Traits.incomeMultiplier(instance.trait, false) * extra
		end
	end
	return if total > 0 then cafeRate(profile, total) else 0
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
	return Config.CatXpPerSecondPlaced * favorite * Traits.xpMultiplier(instance.trait) -- #3871: Fast Learner and co
end

-- Every owned cat earns XP for the settled time at its catXpRate. Only online time is settled: DataService.load
-- resets lastTick before the first settle, so the offline gap earns neither coins at the online rate nor XP. Every
-- level gained counts in stats.catLevelUps. Returns the number of levels gained.
function Economy.grantXp(profile: Types.PlayerProfile, seconds: number): number
	if seconds <= 0 then
		return 0
	end
	local gained = 0
	for uid, instance in profile.cats do
		if CatStats.atSpa(profile, uid) then
			continue -- #2651 part 4: a cat at the Oasis Spa earns no XP; it gains its level when collected
		end
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
local function nightSecondsFrom(from: number, seconds: number, clockEpoch: number?): number
	return if clockEpoch ~= nil
		then math.clamp(
			Clock.nightSecondsBetween(from - clockEpoch, from + seconds - clockEpoch),
			0,
			seconds
		)
		else 0
end

local function paidSecondsFrom(from: number, seconds: number, clockEpoch: number?): number
	local nightSeconds = nightSecondsFrom(from, seconds, clockEpoch)
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
-- #2486: the running Cafe Event's money multiplier on every player's cafe income, on top of passes (1 while none
-- runs, at most Config.EventMoneyMax). The server's EventService sets it; settle reads it.
local eventMoney = 1

function Economy.setEventMoney(multiplier: number)
	eventMoney =
		math.clamp(if multiplier == multiplier then multiplier else 1, 1, Config.EventMoneyMax)
end

function Economy.eventMoney(): number
	return eventMoney
end

-- #2486 (live-events.md section 7, event_money): the coins the event's multiplier added to each player's cafe
-- income, tips, rich tips and Tip Jar since EventService last took them.
local eventExtraByProfile: { [Types.PlayerProfile]: number } = setmetatable({}, { __mode = "k" }) :: any

-- Counts the boost's share of `total`, coins paid at `multiplier` (the event's money when it was worked out).
function Economy.noteEventExtra(profile: Types.PlayerProfile, total: number, multiplier: number)
	if multiplier > 1 and total > 0 then
		eventExtraByProfile[profile] = (eventExtraByProfile[profile] or 0)
			+ total * (1 - 1 / multiplier)
	end
end

-- The coins the boost added since the last call; resets to 0.
function Economy.takeEventExtra(profile: Types.PlayerProfile): number
	local extra = eventExtraByProfile[profile] or 0
	eventExtraByProfile[profile] = nil
	return extra
end

-- #3573 (shared/AfkCafe): the profiles whose player is resting in their own cafe; AfkCafeService sets it, after a
-- settle, so each window is paid at the rate it was earned at. A resting profile's cafe pay runs at
-- Economy.moneyFor: the event's money or Config.AfkCafeMoney, whichever is larger.
local resting: { [Types.PlayerProfile]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local restEarnedByProfile: { [Types.PlayerProfile]: number } = setmetatable({}, { __mode = "k" }) :: any

function Economy.setResting(profile: Types.PlayerProfile, on: boolean)
	(resting :: any)[profile] = if on then true else nil -- nil drops the weak entry
end

function Economy.isResting(profile: Types.PlayerProfile): boolean
	return resting[profile] == true
end

-- #3651 (shared/Pet): whether the `petCats` switch is on in this server; PetService keeps it. Off, a saved heart
-- pays nothing and is left to run out.
local petOn = false

function Economy.setPetOn(on: boolean)
	petOn = on
end

-- #3651: the happy cat's extra pay a second at money 1, before Pet.gain: its own share of incomePerSecond (its
-- catRate over every working cat's). 0 with no heart running at `at`, or with the switch off.
function Economy.petRate(profile: Types.PlayerProfile, at: number): number
	if not petOn then
		return 0
	end
	local uid = Pet.active(profile.pet, profile.cats, at)
	local cat = if uid ~= nil then profile.cats[uid] else nil
	if cat == nil then
		return 0
	end
	local total = 0
	for _, instance in profile.cats do
		total += Economy.catRate(instance, profile.tier)
	end
	if total <= 0 then
		return 0
	end
	return Economy.incomePerSecond(profile) * Economy.catRate(cat, profile.tier) / total
end

-- The money multiplier on this profile's cafe pay right now: the event's, or the rest's when larger.
function Economy.moneyFor(profile: Types.PlayerProfile): number
	if resting[profile] ~= true then
		return eventMoney
	end
	return math.clamp(math.max(eventMoney, Config.AfkCafeMoney), 1, Config.EventMoneyMax)
end

-- The coins the cafe paid while the profile rested since the last call (the whole pay, not only the rest's share),
-- for the welcome back line and afk_pay; resets to 0.
function Economy.takeRestEarned(profile: Types.PlayerProfile): number
	local earned = restEarnedByProfile[profile] or 0
	restEarnedByProfile[profile] = nil
	return earned
end

function Economy.settle(profile: Types.PlayerProfile, now: number, clockEpoch: number?): number
	local elapsed = math.max(0, now - profile.lastTick)
	local earned = 0
	if elapsed > 0 then
		local base = paidSecondsFrom(profile.lastTick, elapsed, clockEpoch)
		local paidSeconds = base + tipBonusSeconds(profile, elapsed, clockEpoch)
		-- #2486: x the running event's money; #3573: or the rest's 2x, whichever is larger
		local money = Economy.moneyFor(profile)
		local rate = Economy.incomePerSecond(profile) * money
		-- F92: the pal bonus over the whole window; the caller settled when the pal count last changed
		local palCoins = rate * base * Economy.palBonus(profile)
		-- #3871: the night income traits over the window's night seconds, paid like the night's own pay
		local nightTrait = Economy.nightTraitRate(profile)
			* money
			* nightSecondsFrom(profile.lastTick, elapsed, clockEpoch)
			* Config.NightIncomeMultiplier
		earned = rate * paidSeconds + palCoins + nightTrait
		if palCoins > 0 then
			palEarnedByProfile[profile] = (palEarnedByProfile[profile] or 0) + palCoins
		end
		profile.coins += earned
		profile.lifetimeCoins += earned
		-- the event's own share of it (the rest's 2x is not the event's doing)
		Economy.noteEventExtra(profile, earned * eventMoney / money, eventMoney)
		-- #3651: the happy cat's own pay again for the part of the window its heart ran, never above the event
		-- money cap with the slot (Pet.gain); after the event's share is noted, as it is not the event's doing
		local petCoins = Economy.petRate(profile, profile.lastTick)
			* Pet.gain(money)
			* base -- the paid seconds without the tip bonus: tips are unchanged
			* Pet.seconds(profile.pet, profile.lastTick, elapsed)
			/ elapsed
		if petCoins > 0 then
			earned += petCoins
			profile.coins += petCoins
			profile.lifetimeCoins += petCoins
		end
		Pet.prune(profile, now)
		if resting[profile] == true then
			restEarnedByProfile[profile] = (restEarnedByProfile[profile] or 0) + earned
		end
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
	if def.source == "pass" and def.pack ~= nil then
		return "Comes with the " .. def.pack .. ", not for sale" -- #1822
	end
	if def.source == "pass" then
		return "Earned on the Cafe Pass, not for sale"
	end
	if def.source == "event" then
		return "A Cafe Event reward, not for sale" -- #2486
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

-- Different cats ever caught: entries in the collection (a gold cat is not a second entry). An exclusive cat (F95,
-- F96) is not one. For quests, achievements and telemetry; rank up reads rankUpCatCount (#1141).
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

-- #1141 (Derek 2026-11-04): whether a collection entry counts toward rank up's "different cats". Every caught cat
-- does, and so does the free Bellhop Cat (exclusive with source "free", F96); a shop-only cat (F95, source "shop")
-- does not, so ranking up still needs catching. An id the catalog does not know counts, as in distinctCats. The
-- collection is "ever had", one entry per catId, so duplicates, gold coats, cats away (camp, nap, cannon), locked,
-- sold, released or traded cats change nothing. The server's rankUpBlocker and the client's RankUp.progress (the
-- rank up card, the upgrade shop button, the goal card and the gate signs) both read these, so they agree.
function Economy.countsForRankUp(catId: string): boolean
	local def = Catalog.getCat(catId)
	return def == nil or def.exclusive ~= true or def.source == "free"
end

-- Different cats toward rank up in `collection` (catId -> anything, the profile's or the client state's).
function Economy.rankUpCatCount(collection: { [string]: any }): number
	local n = 0
	for catId in collection do
		if Economy.countsForRankUp(catId) then
			n += 1
		end
	end
	return n
end

-- Of those, the ones of this rarity or rarer, for the Tier 3 to 5 requirement. An unknown id has no rarity, so it
-- never meets one.
function Economy.rankUpCatsAtLeast(collection: { [string]: any }, rarity: Types.Rarity): number
	local n = 0
	for catId in collection do
		local def = Catalog.getCat(catId)
		if
			def ~= nil
			and Economy.countsForRankUp(catId)
			and Catching.rarityAtLeast(def.rarity, rarity)
		then
			n += 1
		end
	end
	return n
end

-- Returns nil when RankUp would succeed, else a short reason for a toast (data-model section 5b). Checked in the
-- order a player works through them: cats, the rarity, then coins.
function Economy.rankUpBlocker(profile: Types.PlayerProfile): string?
	local nextTier = Catalog.getTier(Economy.tier(profile) + 1)
	-- #3997: a tier behind the `tier8` switch (shared/LateTiers) is not there yet
	if nextTier == nil or not LateTiers.tierOpen(nextTier.tier) then
		local top = math.max(Economy.tier(profile), LateTiers.topTier())
		return "Your cafe is already a " .. (Catalog.getTier(top) :: Types.TierDef).name
	end
	local cats = Economy.rankUpCatCount(profile.collection)
	if cats < nextTier.distinctCats then
		return string.format("Needs %d different cats (you have %d)", nextTier.distinctCats, cats)
	end
	local rarity: Types.Rarity? = nextTier.needsRarity
	if rarity ~= nil then
		local need = nextTier.needsRarityCount or 1
		if Economy.rankUpCatsAtLeast(profile.collection, rarity) < need then
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

-- #1624: role slots past the tier's own, one per Extra Slot pass (PassService's `slots`) and Grand Cafe's
-- GrandExtraSlots.
function Economy.extraSlots(profile: Types.PlayerProfile): number
	local passes = Economy.passes(profile)
	return math.max(0, passes.slots) + (if passes.grand == true then Config.GrandExtraSlots else 0)
end

-- Whether role slot `spotId` is open (Catalog.slotIsOpen): an extra slot opens the next tier's spot early, and at
-- Tier 5 the pass-only ones (#1624).
function Economy.spotIsOpen(profile: Types.PlayerProfile, spotId: string): boolean
	return Catalog.slotIsOpen(spotId, Economy.tier(profile), Economy.extraSlots(profile))
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
