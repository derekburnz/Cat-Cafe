--!strict
-- Luck (F88, luck-and-rare-moments.md section 1), pure. One number from x1.0 that adds up every source the player
-- has now, at most Config.LuckMax: the Lucky Cat statue (LuckPerStatueLevel a lucky_cat level), a running Lucky
-- Potion (LuckyPotionLuck) and a Lucky Day (LuckyDayPlayerLuck, the day phase of a Lucky Day, #1572 Clock.dayKinds, of a
-- server, shared/Clock). On a roll it multiplies the Epic, Legendary and Mythical chances; Rare keeps its chance and
-- Common takes the difference, so the odds keep their total.
--   sources(profile, now, luckyDay) -> { Source }   what adds Luck now, in a fixed order (statue, potion, day)
--   of(profile, now, luckyDay) -> number             1 plus the sources, at most LuckMax
--   apply(odds, luck) -> LureOdds                    the odds a roll uses at that Luck
--   text(luck) -> string                             "Luck x1.3", as the HUD chip shows it

local Config = require(script.Parent.Config)
local Potions = require(script.Parent.Potions)
local Types = require(script.Parent.Types)

local Luck = {}

Luck.UPGRADE = "lucky_cat"

-- The Lucky Day's two lines (section 1c): the warning LuckyDayWarnSeconds before its sunrise, the banner at sunrise.
Luck.DAY_WARNING = "A Lucky Day starts at sunrise!"
Luck.DAY_BANNER = "Lucky Day! Rare cats are twice as likely until night"

-- A source of Luck: "statue", "potion" or "lucky_day", and what it adds.
export type SourceId = "statue" | "potion" | "lucky_day"
export type Source = { id: SourceId, value: number }

local function statueLevel(profile: Types.PlayerProfile): number
	local level = profile.upgradeLevels[Luck.UPGRADE]
	return if type(level) == "number" then math.max(0, math.floor(level)) else 0
end

function Luck.sources(profile: Types.PlayerProfile, now: number, luckyDay: boolean): { Source }
	local out: { Source } = {}
	local function add(id: SourceId, value: number)
		local source: Source = { id = id, value = value }
		table.insert(out, source)
	end
	local level = statueLevel(profile)
	if level > 0 then
		add("statue", level * Config.LuckPerStatueLevel)
	end
	if Potions.running(profile, Potions.LUCKY, now) then
		add("potion", Config.LuckyPotionLuck)
	end
	if luckyDay then
		add("lucky_day", Config.LuckyDayPlayerLuck)
	end
	return out
end

-- Rounded to a hundredth so 1 + 0.1 + 0.1 + 0.1 reads 1.3 everywhere, cards and rolls alike.
local function round(luck: number): number
	return math.floor(luck * 100 + 0.5) / 100
end

function Luck.of(profile: Types.PlayerProfile, now: number, luckyDay: boolean): number
	local luck = 1
	for _, source in Luck.sources(profile, now, luckyDay) do
		luck += source.value
	end
	return math.clamp(round(luck), 1, Config.LuckMax)
end

-- Epic, Legendary and Mythical times `luck`, Rare as it was and Common the rest of the same total; if Common would
-- go below 0 the rest comes off Rare. A table with no Common chance gives the rest to Rare, so a rarity it never had
-- never appears, and if the three rare ones alone reach the total they are scaled to fill it. Kibble on a level 1
-- bowl, 70 / 25 / 4 / 0.9 / 0.1, at x1.5: 67.5 / 25 / 6 / 1.35 / 0.15. Luck at or below 1 leaves the odds as they are.
function Luck.apply(odds: Types.LureOdds, luck: number): Types.LureOdds
	local common, rare = odds.Common, odds.Rare
	local epic, legendary, mythical = odds.Epic, odds.Legendary, odds.Mythical
	if luck <= 1 then
		return {
			Common = common,
			Rare = rare,
			Epic = epic,
			Legendary = legendary,
			Mythical = mythical,
		}
	end
	local total = common + rare + epic + legendary + mythical
	epic, legendary, mythical = epic * luck, legendary * luck, mythical * luck
	local top = epic + legendary + mythical
	if top >= total or (common <= 0 and rare <= 0) then
		local scale = if top > 0 then total / top else 0
		return {
			Common = 0,
			Rare = 0,
			Epic = epic * scale,
			Legendary = legendary * scale,
			Mythical = mythical * scale,
		}
	end
	local rest = total - top
	if common > 0 then
		common = rest - rare
		if common < 0 then
			rare, common = rest, 0
		end
	else
		rare = rest
	end
	return { Common = common, Rare = rare, Epic = epic, Legendary = legendary, Mythical = mythical }
end

-- The same for a crate's odds table (rarity -> percent; a missing rarity reads as 0).
function Luck.applyMap(odds: { [string]: number }, luck: number): { [string]: number }
	local applied = Luck.apply({
		Common = odds.Common or 0,
		Rare = odds.Rare or 0,
		Epic = odds.Epic or 0,
		Legendary = odds.Legendary or 0,
		Mythical = odds.Mythical or 0,
	}, luck)
	return {
		Common = applied.Common,
		Rare = applied.Rare,
		Epic = applied.Epic,
		Legendary = applied.Legendary,
		Mythical = applied.Mythical,
	}
end

-- #1776 (luck-and-rare-moments.md section 1d): how much more likely Luck makes each of Epic, Legendary and Mythical,
-- in whole percent, since apply multiplies those three by it: x1.3 is 30, x2.0 is 100, x1 or below 0.
function Luck.boostPercent(luck: number): number
	return math.max(0, math.floor((round(luck) - 1) * 100 + 0.5))
end

-- One decimal, two when a hundredth shows: "Luck x1.0", "Luck x1.3", "Luck x1.25".
function Luck.text(luck: number): string
	local value = round(luck)
	local tenths = math.floor(value * 10 + 0.5) / 10
	return string.format(
		if math.abs(value - tenths) < 1e-9 then "Luck x%.1f" else "Luck x%.2f",
		value
	)
end

return Luck
