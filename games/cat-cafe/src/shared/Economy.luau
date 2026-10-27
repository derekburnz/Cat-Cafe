--!strict
-- Pure income math (data-model section 11) and purchase gates. No Roblox services.

local CatStats = require(script.Parent.CatStats)
local Catalog = require(script.Parent.Catalog)
local Catching = require(script.Parent.Catching)
local Clock = require(script.Parent.Clock)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Economy = {}

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

-- tierMultiplier in the income formula: 1.00 at Tier 1 up to 2.00 at Tier 5.
function Economy.tierMultiplier(profile: Types.PlayerProfile): number
	local def = Catalog.getTier(Economy.tier(profile))
	return if def ~= nil then def.multiplier else 1
end

-- Placed decor that a placed gold Index piece stands in for (N114): it stays out of the bonus and off the plot.
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

-- cafeMultiplier = 1 + 0.10 x tables + 0.15 x (espresso - 1) + placed decor bonuses
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
	return multiplier
end

-- Rate of one working cat before the cafe multiplier: its rating (rarity x charm x level x variant, see CatStats)
-- times the favorite role bonus (data-model section 11). Resting cats earn nothing.
function Economy.catRate(instance: Types.CatInstance): number
	local def = Catalog.getCat(instance.catId)
	if def == nil or instance.spotId == nil then
		return 0
	end
	local spot = Catalog.getSpot(instance.spotId :: string)
	if spot == nil then
		return 0
	end
	local favorite = if spot.spotType == def.favoriteRole then Config.FavoriteMultiplier else 1
	return CatStats.rating(instance) * favorite
end

function Economy.variantMultiplier(variant: string): number
	return CatStats.variantMultiplier(variant)
end

-- incomePerSecond = sum over working cats of (rating x favorite) x cafeMultiplier x tierMultiplier.
-- The whole income formula lives here, so the night multiplier and a customer-driven model change one function.
function Economy.incomePerSecond(profile: Types.PlayerProfile): number
	local total = 0
	for _, instance in profile.cats do
		total += Economy.catRate(instance)
	end
	return total * Economy.cafeMultiplier(profile) * Economy.tierMultiplier(profile)
end

-- Placed cats earn one XP per second of settled time (data-model section 4b). Only online time is settled:
-- DataService.load resets lastTick before the first settle, so the offline gap earns neither coins at the
-- online rate nor XP. Returns the number of cats that levelled up.
function Economy.grantPlacedXp(profile: Types.PlayerProfile, seconds: number): number
	if seconds <= 0 then
		return 0
	end
	local levelled = 0
	for _, instance in profile.cats do
		if instance.spotId ~= nil and Catalog.getSpot(instance.spotId :: string) ~= nil then
			if CatStats.addXp(instance, seconds * Config.CatXpPerSecondPlaced) > 0 then
				levelled += 1
			end
		end
	end
	return levelled
end

-- The share of the day rate a cafe earns in this phase: 1 by day, NightIncomeMultiplier by night (section 11).
function Economy.phaseMultiplier(phase: Types.ClockPhase): number
	return if phase == "night" then Config.NightIncomeMultiplier else 1
end

-- Lazy accounting: credit everything earned since lastTick, then grant that time as XP to the placed cats.
-- Coins use the rate from before any level-up in the window (a few seconds at most), which keeps the
-- credit simple and never overpays. Call before any read or spend.
-- `clockEpoch` is the os.time() at which the server's clock started (ClockService.epoch): the window is split at
-- phase boundaries and its night part pays NightIncomeMultiplier (section 11). Without it the whole window pays
-- the day rate, which only the specs and offline maths want.
function Economy.settle(profile: Types.PlayerProfile, now: number, clockEpoch: number?): number
	local elapsed = math.max(0, now - profile.lastTick)
	local earned = 0
	if elapsed > 0 then
		local nightSeconds = if clockEpoch ~= nil
			then math.clamp(
				Clock.nightSecondsBetween(profile.lastTick - clockEpoch, now - clockEpoch),
				0,
				elapsed
			)
			else 0
		local paidSeconds = elapsed - nightSeconds + nightSeconds * Config.NightIncomeMultiplier
		earned = Economy.incomePerSecond(profile) * paidSeconds
		profile.coins += earned
		profile.lifetimeCoins += earned
		Economy.grantPlacedXp(profile, elapsed)
	end
	profile.lastTick = now
	return earned
end

-- A rich customer's tip (section 12): RichTipSeconds of the day rate, never less than $50.
function Economy.richTipAmount(dayRate: number): number
	return math.max(50, math.floor(dayRate * Config.RichTipSeconds))
end

function Economy.offlineGain(rateAtLogout: number, lastSeen: number, now: number): (number, number)
	local seconds = math.clamp(now - lastSeen, 0, Config.OfflineCapSeconds)
	return math.floor(rateAtLogout * Config.OfflineRate * seconds), seconds
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
	if def.source == "index" then
		return "An Index reward, not for sale"
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

-- Different cats ever caught: entries in the collection (a gold cat is not a second entry).
function Economy.distinctCats(profile: Types.PlayerProfile): number
	local n = 0
	for _ in profile.collection do
		n += 1
	end
	return n
end

-- Different cats of this rarity or rarer in the collection, for the Tier 3 to 5 requirement (data-model 5b:
-- "one Epic" means one Epic or better, so a Legendary counts).
function Economy.distinctCatsAtLeast(profile: Types.PlayerProfile, rarity: Types.Rarity): number
	local n = 0
	for catId in profile.collection do
		local def = Catalog.getCat(catId)
		if def ~= nil and Catching.rarityAtLeast(def.rarity, rarity) then
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
