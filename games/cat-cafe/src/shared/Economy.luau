--!strict
-- Pure income math (data-model section 11) and purchase gates. No Roblox services.

local CatStats = require(script.Parent.CatStats)
local Catalog = require(script.Parent.Catalog)
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

function Economy.cafeLevel(profile: Types.PlayerProfile): number
	return Economy.level(profile, "cafe_level")
end

-- cafeMultiplier = 1 + 0.10 x tables + 0.15 x (espresso - 1) + placed decor bonuses
function Economy.cafeMultiplier(profile: Types.PlayerProfile): number
	local multiplier = 1 + Config.TableBonus * Economy.level(profile, "tables")
	multiplier += Config.EspressoBonus * math.max(0, Economy.level(profile, "espresso") - 1)
	for decorId, placed in profile.decorPlaced do
		local def = Catalog.getDecor(decorId)
		if placed and def ~= nil and profile.decorOwned[decorId] then
			multiplier += def.bonus
		end
	end
	return multiplier
end

-- Rate of one placed cat before the cafe multiplier: its rating (rarity x charm x level x variant, see
-- CatStats) times the favorite spot bonus. Resting cats earn nothing.
function Economy.catRate(instance: Types.CatInstance): number
	local def = Catalog.getCat(instance.catId)
	if def == nil or instance.spotId == nil then
		return 0
	end
	local spot = Catalog.getSpot(instance.spotId :: string)
	if spot == nil then
		return 0
	end
	local favorite = if spot.spotType == def.favoriteSpot then Config.FavoriteMultiplier else 1
	return CatStats.rating(instance) * favorite
end

function Economy.variantMultiplier(variant: string): number
	return CatStats.variantMultiplier(variant)
end

-- Renovate (rebirth) seam: 1.0 until the feature ships, then 1 + RenovateBonus per Renovate.
-- The whole income formula lives in incomePerSecond, so a customer-driven model later replaces one function.
function Economy.prestigeMultiplier(profile: Types.PlayerProfile): number
	local renovations = profile.renovations
	-- type guard for version 1 saves and fixtures that predate the field; the NaN and sign guards for bad data
	if type(renovations) ~= "number" or renovations ~= renovations or renovations < 0 then
		return 1
	end
	return 1 + Config.RenovateBonus * math.floor(renovations)
end

-- incomePerSecond = sum over placed cats of (rating x favorite) x cafeMultiplier x prestigeMultiplier
function Economy.incomePerSecond(profile: Types.PlayerProfile): number
	local total = 0
	for _, instance in profile.cats do
		total += Economy.catRate(instance)
	end
	return total * Economy.cafeMultiplier(profile) * Economy.prestigeMultiplier(profile)
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

-- Lazy accounting: credit everything earned since lastTick, then grant that time as XP to the placed cats.
-- Coins use the rate from before any level-up in the window (a few seconds at most), which keeps the
-- credit simple and never overpays. Call before any read or spend.
function Economy.settle(profile: Types.PlayerProfile, now: number): number
	local elapsed = math.max(0, now - profile.lastTick)
	local earned = 0
	if elapsed > 0 then
		earned = Economy.incomePerSecond(profile) * elapsed
		profile.coins += earned
		profile.lifetimeCoins += earned
		Economy.grantPlacedXp(profile, elapsed)
	end
	profile.lastTick = now
	return earned
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
	local cafe = Economy.cafeLevel(profile)
	if def.requiresCafeLevel ~= nil and cafe < def.requiresCafeLevel then
		return string.format("Needs cafe level %d", def.requiresCafeLevel)
	end
	local perLevel = def.requiresCafeLevelAtLevel
	if perLevel ~= nil and perLevel[nextLevel] ~= nil and cafe < perLevel[nextLevel] then
		return string.format("Needs cafe level %d", perLevel[nextLevel])
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
	if profile.decorOwned[decorId] then
		return "Already owned"
	end
	if def.requiresCafeLevel ~= nil and Economy.cafeLevel(profile) < def.requiresCafeLevel then
		return string.format("Needs cafe level %d", def.requiresCafeLevel)
	end
	if not Economy.canAfford(profile, def.cost) then
		return "Not enough coins"
	end
	return nil
end

function Economy.spotIsOpen(profile: Types.PlayerProfile, spotId: string): boolean
	local spot = Catalog.getSpot(spotId)
	return spot ~= nil and Economy.cafeLevel(profile) >= spot.cafeLevel
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
