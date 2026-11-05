--!strict
-- Luck on the HUD (F88, luck-and-rare-moments.md sections 1b to 1d): the Luck chip's number and gold text, its card's rows,
-- the food and crate the card shows, the Lucky Day line under the clock and the Lucky Cat's two shop lines.
--   current(state, now) -> number          Luck now: 1 plus every source not yet ended, rounded and capped as shared/Luck
--                                          does (state.luck when ProfileSync sent no sources), so a potion that ran out
--                                          drops off before the next sync and every card shows the odds the roll uses
--   shown(state, now) -> boolean           the chip shows from the first source (spec 1d: hidden before that)
--   lucky(state, now) -> boolean           a Lucky Day runs: the chip's text turns gold
--   rows(state, now) -> { Row }            the card's sources, statue first: "Lucky Cat statue, level 3" "+0.3", "Lucky
--                                          Potion" "+0.5" "8:12", "Lucky Day" "+0.5" "3:10"
--   food(catalog, state) -> LureDef?       the food the card shows on your bowl: the rarest one in your bag, else the
--                                          first shop food (Kibble)
--   crate(catalog, state) -> CrateDef?     the crate the card shows: the first plain crate you own, else the Classic
--   crateOdds(catalog, state, crate, luck) the odds that crate opens on next (MarketLogic.nextOdds with Luck)
--   dayLine(view) -> string?               under the clock: "Lucky Day now", "Lucky Day at sunrise", "Lucky Day
--                                          tomorrow", "Lucky Day in 3 days"; nil without the Clock's attributes
--   statueLines(level, maxLevel)           the Lucky Cat's shop lines, what it gives now and next, then what Luck does
--   text(luck) -> string                   shared Luck.text: "Luck x1.3"
--   oddsRich(odds, hexOf) -> string        the card's odds for a RichText label: only the rarities that can come, a new
--                                          line before one that would pass 36 letters ("Epic 71.56%   Legendary 23.44%"
--                                          then "Mythical 5%"), each in its rarity's colour, so the 330 px card fits them
--                                          without a wrap splitting a line
-- Pure, so the cloud spec runner checks it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MarketLogic = require(script.Parent.MarketLogic)
local Types = require(script.Parent.Parent.Types)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Luck = require(Shared:WaitForChild("Luck"))

local LuckLogic = {}

LuckLogic.UPGRADE = "lucky_cat"
LuckLogic.ICON = "🍀" -- Theme.icons.luck; IconArt draws it as the clean clover (CleanGlyphs, #1258)
LuckLogic.SUBTITLE = "Rarer cats from your bait and crates"

local LUCK_MAX: number = (Config :: any).LuckMax or 3
local PER_LEVEL: number = (Config :: any).LuckPerStatueLevel or 0.1
local LUCKY_EVERY: number = (Config :: any).CrateLuckyEvery or 20
local RARITIES: { string } = { "Common", "Rare", "Epic", "Legendary", "Mythical" }
local LINE_CHARS = 36 -- letters a line of the card's odds holds at textSmall in its 302 px
local NBSP = utf8.char(0xA0) -- a no-break space, as FoodOdds.rich joins a name to its share

export type Row = {
	id: string, -- "statue" | "potion" | "lucky_day"
	name: string,
	value: string, -- "+0.3"
	time: string?, -- what is left of a timed source, "8:12"
}

export type DayView = {
	day: number?, -- the Clock's Day: the day running, or at night the day that ended
	nextLuckyDay: number?, -- the Clock's NextLuckyDay
	luckyDay: boolean?, -- the Clock's LuckyDay, true from sunrise to dusk on one
	phase: string?, -- "day" | "night"
}

local NAMES: { [string]: string } = {
	statue = "Lucky Cat statue",
	potion = "Lucky Potion",
	lucky_day = "Lucky Day",
}

-- shared/Luck's rounding: to a hundredth, so 1 + 0.1 + 0.1 + 0.1 reads 1.3
local function round(value: number): number
	return math.floor(value * 100 + 0.5) / 100
end

-- The sources still running at `now` (a timed one ends at its endsAt).
local function running(state: Types.PlayerState, now: number): { Types.LuckSource }
	local out: { Types.LuckSource } = {}
	local sources: { Types.LuckSource } = state.luckSources or {}
	for _, source in sources do
		local endsAt = source.endsAt
		if
			type(source.value) == "number"
			and source.value > 0
			and (endsAt == nil or endsAt > now)
		then
			table.insert(out, source)
		end
	end
	return out
end

function LuckLogic.current(state: Types.PlayerState, now: number): number
	if state.luckSources == nil then
		local luck = state.luck
		return if type(luck) == "number" then math.clamp(luck, 1, LUCK_MAX) else 1
	end
	local luck = 1
	for _, source in running(state, now) do
		luck += source.value
	end
	return math.clamp(round(luck), 1, LUCK_MAX)
end

-- "Luck x1" at a plain 1x (#1150), else Luck.text's "Luck x1.3".
function LuckLogic.text(luck: number): string
	if luck <= 1 then
		return "Luck x1"
	end
	return Luck.text(luck)
end

-- The chip always shows (#1150), so a new player sees luck exists and watches it climb.
function LuckLogic.shown(_state: Types.PlayerState, _now: number): boolean
	return true
end

-- Whether anything lifts luck above 1x: the chip is quieter when nothing does.
function LuckLogic.boosted(state: Types.PlayerState, now: number): boolean
	return LuckLogic.current(state, now) > 1
end

function LuckLogic.lucky(state: Types.PlayerState, now: number): boolean
	for _, source in running(state, now) do
		if source.id == "lucky_day" then
			return true
		end
	end
	return false
end

-- 0.3 -> "+0.3", 0.25 -> "+0.25", 0.5 -> "+0.5"
local function plus(value: number): string
	local text = string.format("%.2f", round(value)):gsub("0+$", ""):gsub("%.$", "")
	return "+" .. text
end

-- 492 -> "8:12", rounded up so the last second still shows "0:01"
local function clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return ("%d:%02d"):format(whole // 60, whole % 60)
end

function LuckLogic.rows(state: Types.PlayerState, now: number): { Row }
	local rows: { Row } = {}
	for _, source in running(state, now) do
		local name = NAMES[source.id] or source.id
		if source.id == "statue" then
			local level = state.upgradeLevels[LuckLogic.UPGRADE]
			if type(level) ~= "number" or level < 1 then
				level = math.floor(source.value / PER_LEVEL + 0.5)
			end
			name = ("%s, level %d"):format(name, level :: number)
		end
		local endsAt = source.endsAt
		table.insert(rows, {
			id = source.id,
			name = name,
			value = plus(source.value),
			time = if endsAt ~= nil then clock(endsAt - now) else nil,
		})
	end
	return rows
end

local function rank(rarity: string?): number
	return table.find(RARITIES, rarity or "Common") or 1
end

function LuckLogic.food(catalog: Types.Catalog?, state: Types.PlayerState): Types.LureDef?
	if catalog == nil then
		return nil
	end
	local best: Types.LureDef? = nil
	local first: Types.LureDef? = nil
	local lures: { Types.LureDef } = catalog.lures or {}
	for _, lure in lures do
		if lure.odds == nil then
			continue
		end
		if first == nil and lure.source ~= "dealer" then
			first = lure
		end
		if (state.lures[lure.id] or 0) > 0 then
			local current = best
			if current == nil or rank(lure.attracts) >= rank(current.attracts) then
				best = lure
			end
		end
	end
	return best or first
end

function LuckLogic.crate(catalog: Types.Catalog?, state: Types.PlayerState): Types.CrateDef?
	if catalog == nil then
		return nil
	end
	local classic: Types.CrateDef? = nil
	local owned: { [string]: number } = state.crates or {}
	local crates: { Types.CrateDef } = catalog.crates or {}
	for _, crate in crates do
		if crate.golden then
			continue
		end
		if (owned[crate.id] or 0) > 0 then
			return crate
		end
		if classic == nil and crate.area == MarketLogic.CLASSIC then
			classic = crate
		end
	end
	return classic
end

-- The odds `crate` opens on next at Luck `luck`: the golden odds on the lucky twentieth, else its own with Luck in.
function LuckLogic.crateOdds(
	catalog: Types.Catalog?,
	state: Types.PlayerState,
	crate: Types.CrateDef,
	luck: number
): { [string]: number }
	local golden: { [string]: number }? = nil
	local crates: { Types.CrateDef } = if catalog then catalog.crates or {} else {}
	for _, other in crates do
		if other.golden and other.area == crate.area then
			golden = other.odds
			break
		end
	end
	local opens = if state.crateLuck then state.crateLuck[crate.area] else nil
	return MarketLogic.nextOdds(crate :: any, opens, LUCKY_EVERY, golden, luck)
end

function LuckLogic.dayLine(view: DayView): string?
	local day, nextDay = view.day, view.nextLuckyDay
	if view.luckyDay == true and view.phase ~= "night" then
		return "Lucky Day now"
	end
	if type(day) ~= "number" or type(nextDay) ~= "number" then
		return nil
	end
	-- sunrises until it starts: at night Day is the day that ended, so the next sunrise starts Day + 1 either way
	local away = math.floor(nextDay - day)
	if away <= 0 then
		return nil
	elseif away == 1 then
		return if view.phase == "night" then "Lucky Day at sunrise" else "Lucky Day tomorrow"
	end
	return ("Lucky Day in %d days"):format(away)
end

-- #1153 (Derek 11-04: the odds blocks were hard to read): whole percents, one decimal below 1% ("42%", "0.6%").
function LuckLogic.percent(value: number): string
	if value >= 1 then
		return ("%d%%"):format(math.floor(value + 0.5))
	end
	local tenths = math.floor(value * 10 + 0.5) / 10
	if tenths <= 0 then
		return "<0.1%"
	end
	return ("%s%%"):format(tostring(tenths))
end

-- `before`, the same odds without Luck: a rarity Luck makes more likely gets a small ↑ (#1153: "show what luck does").
function LuckLogic.oddsRich(
	odds: { [string]: number }?,
	hexOf: (rarity: string) -> string,
	before: { [string]: number }?
): string
	if odds == nil then
		return ""
	end
	local lines: { string } = {}
	local line: { string } = {}
	local letters = 0
	for _, rarity in RARITIES do
		local share = odds[rarity]
		if type(share) == "number" and share > 0 then
			local was = if before then before[rarity] else nil
			local up = type(was) == "number" and share > was + 0.05
			local shown = LuckLogic.percent(share) .. (if up then "↑" else "")
			local width = #rarity + 1 + (utf8.len(shown) or #shown) -- the ↑ is one letter wide
			if #line > 0 and letters + 3 + width > LINE_CHARS then
				table.insert(lines, table.concat(line, "   "))
				line = {}
				letters = 0
			end
			letters += (if #line > 0 then 3 else 0) + width
			table.insert(
				line,
				('<font color="#%s">%s</font>'):format(hexOf(rarity), rarity .. NBSP .. shown)
			)
		end
	end
	if #line > 0 then
		table.insert(lines, table.concat(line, "   "))
	end
	return table.concat(lines, "\n")
end

-- Level 0: "A beckoning cat by your front door" then "Each level: Luck +0.1, rarer bait cats and crate finds".
-- Level 2 of 5: "Luck +0.2 now, +0.3 next level". At the top: "Luck +0.5, the most it gives".
function LuckLogic.statueLines(level: number, maxLevel: number): (string, string)
	local what = "Rarer bait cats and crate finds"
	if level < 1 then
		return "A beckoning cat by your front door",
			("Each level: Luck %s, rarer bait cats and crate finds"):format(plus(PER_LEVEL))
	elseif level >= maxLevel then
		return ("Luck %s, the most it gives"):format(plus(level * PER_LEVEL)), what
	end
	return ("Luck %s now, %s next level"):format(
		plus(level * PER_LEVEL),
		plus((level + 1) * PER_LEVEL)
	),
		what
end

return LuckLogic
