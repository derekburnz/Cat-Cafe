--!strict
-- Daily quests, weekly quests and achievements (F73, quests.md, approved by Derek 2026-10-27 22:14). Pure rules, no
-- Roblox services: the day and week, which quests a player is given, how far each has come, what finishing one pays
-- and what an achievement measures. QuestService pays, saves and syncs.
-- A quest counts from its counter's value when it was picked (`base`), so progress is the counter less that, up to
-- `needs`. An achievement reads a lifetime value, so old saves get credit for what they did before.

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Economy = require(script.Parent.Economy)
local Types = require(script.Parent.Types)

local Quests = {}

-- Each slot's pool, in slot order: two Streets quests (never the same counter twice), a Cafe one, an Extra one and
-- the Big Request; one from each weekly pool.
Quests.DAILY_POOLS = { "streets", "streets", "cafe", "extra", "big" }
Quests.WEEKLY_POOLS = { "a", "b", "c" }

local DAY = 86400
local WEEK = 604800

-- The UTC day of `now` (os.time()), as for the free spin.
function Quests.day(now: number): number
	return math.floor(now / DAY)
end

-- The week of `now`, starting Monday 00:00 UTC.
function Quests.week(now: number): number
	return math.floor((now - Config.QuestWeekOffsetSeconds) / WEEK)
end

-- os.time() of the next new day and the next new week after `now`.
function Quests.dayEndsAt(now: number): number
	return (Quests.day(now) + 1) * DAY
end

function Quests.weekEndsAt(now: number): number
	return (Quests.week(now) + 1) * WEEK + Config.QuestWeekOffsetSeconds
end

function Quests.pools(kind: Types.QuestKind): { string }
	return if kind == "daily" then Quests.DAILY_POOLS else Quests.WEEKLY_POOLS
end

local function rowsOf(kind: Types.QuestKind, pool: string): { Types.QuestDef }
	local pools: { [string]: { Types.QuestDef } } = if kind == "daily"
		then Catalog.quests.daily
		else Catalog.quests.weekly
	return pools[pool] or {}
end

local function count(map: { [string]: any }): number
	local n = 0
	for _ in map do
		n += 1
	end
	return n
end

-- A quest counter's value now: a Stats key, "lifetimeCoins" or "distinctCats" (the entries in collection).
function Quests.value(profile: Types.PlayerProfile, stat: string): number
	if stat == "lifetimeCoins" then
		return math.floor(profile.lifetimeCoins)
	elseif stat == "distinctCats" then
		return count(profile.collection)
	end
	local value = (profile.stats :: any)[stat]
	return if type(value) == "number" then value else 0
end

-- How many cats the player has not found yet in the areas their tier has open (`w_new2` needs 2).
function Quests.uncaught(profile: Types.PlayerProfile): number
	local tier = Economy.tier(profile)
	local n = 0
	for _, def in Catalog.cats do
		local area = Catalog.getArea(def.area)
		if area ~= nil and area.tier <= tier and profile.collection[def.id] == nil then
			n += 1
		end
	end
	return n
end

-- Whether the player can do the quest now: its `requires` met (the bait bowl, a crate to open or the fish for one,
-- cats left to find). A row without `requires` always can.
function Quests.eligible(profile: Types.PlayerProfile, def: Types.QuestDef): boolean
	local requires = def.requires
	if requires == nil then
		return true
	end
	if requires.upgrade ~= nil and Economy.level(profile, requires.upgrade) < 1 then
		return false
	end
	if requires.fishOrCrate == true then
		local banked = false
		for _, n in profile.crates do
			if n > 0 then
				banked = true
				break
			end
		end
		if not banked and profile.goldenFish < Config.CratePrice then
			return false
		end
	end
	if requires.uncaught ~= nil and Quests.uncaught(profile) < requires.uncaught then
		return false
	end
	return true
end

-- What a quest needs from `dayRate` (coins a second): its count, or a coins quest's seconds of the rate, at least its
-- minimum. Never below 1.
function Quests.needsFor(def: Types.QuestDef, dayRate: number): number
	local needs = if def.needsSeconds ~= nil
		then math.max(def.needsMin or 0, math.floor(math.max(dayRate, 0) * def.needsSeconds))
		else def.needs or 1
	return math.max(1, needs)
end

-- A fresh entry for `def`, counting from now.
function Quests.entry(
	profile: Types.PlayerProfile,
	def: Types.QuestDef,
	dayRate: number
): Types.QuestEntry
	return {
		id = def.id,
		base = Quests.value(profile, def.stat),
		needs = Quests.needsFor(def, dayRate),
		claimed = false,
	}
end

-- How far an entry has come: its counter less its base, from 0 to its needs. 0 for an unknown id.
function Quests.progress(profile: Types.PlayerProfile, entry: Types.QuestEntry): number
	local def = Catalog.getQuest(entry.id)
	if def == nil then
		return 0
	end
	return math.clamp(Quests.value(profile, def.stat) - entry.base, 0, entry.needs)
end

function Quests.done(profile: Types.PlayerProfile, entry: Types.QuestEntry): boolean
	return Catalog.getQuest(entry.id) ~= nil and Quests.progress(profile, entry) >= entry.needs
end

-- Picks a row for slot `slot` of `kind` with `roll` in [0, 1): an eligible row of the slot's pool whose id is not in
-- `taken` (this set's other ids) or, for the Streets slots, whose counter another Streets slot already has; rows
-- in `avoid` (yesterday's or the one rerolled away) only when nothing else is left. Nil when the pool has nothing.
function Quests.pick(
	profile: Types.PlayerProfile,
	kind: Types.QuestKind,
	slot: number,
	taken: { Types.QuestEntry },
	avoid: { [string]: boolean },
	roll: number
): Types.QuestDef?
	local pools = Quests.pools(kind)
	local pool = pools[slot]
	if pool == nil then
		return nil
	end
	local usedIds: { [string]: boolean } = {}
	local usedStats: { [string]: boolean } = {}
	for i, entry in taken do
		usedIds[entry.id] = true
		local def = Catalog.getQuest(entry.id)
		if i ~= slot and pools[i] == pool and def ~= nil then
			usedStats[def.stat] = true
		end
	end
	local fresh: { Types.QuestDef } = {}
	local stale: { Types.QuestDef } = {}
	for _, def in rowsOf(kind, pool) do
		if usedIds[def.id] or usedStats[def.stat] or not Quests.eligible(profile, def) then
			continue
		end
		table.insert(if avoid[def.id] then stale else fresh, def)
	end
	local rows = if #fresh > 0 then fresh else stale
	if #rows == 0 then
		return nil
	end
	return rows[math.clamp(math.floor(roll * #rows) + 1, 1, #rows)]
end

-- A new set of `kind` for the player, one entry per slot, skipping the ids in `avoid` where it can. A slot whose pool
-- has nothing eligible is left out, so the list may be short; every pool has a row with no requirement.
function Quests.rollSet(
	profile: Types.PlayerProfile,
	kind: Types.QuestKind,
	dayRate: number,
	avoid: { [string]: boolean },
	roll: () -> number
): { Types.QuestEntry }
	local set: { Types.QuestEntry } = {}
	for slot in Quests.pools(kind) do
		local def = Quests.pick(profile, kind, slot, set, avoid, roll())
		if def ~= nil then
			table.insert(set, Quests.entry(profile, def, dayRate))
		end
	end
	return set
end

-- A save's set brought back to its slots: an entry with an unknown id or from the wrong pool for its slot gets a
-- fresh pick (quests.md section 6), and missing slots are filled. Returns true when anything changed.
function Quests.repair(
	profile: Types.PlayerProfile,
	kind: Types.QuestKind,
	dayRate: number,
	roll: () -> number
): boolean
	local quests = profile.quests
	local list: { Types.QuestEntry } = if kind == "daily" then quests.daily else quests.weekly
	local pools = Quests.pools(kind)
	local changed = false
	local kept: { Types.QuestEntry } = {}
	for slot, entry in list do
		if slot > #pools then
			changed = true
			break
		end
		if Catalog.questPools[entry.id] ~= pools[slot] then
			local def = Quests.pick(profile, kind, slot, kept, {}, roll())
			if def == nil then
				changed = true
				break
			end
			entry = Quests.entry(profile, def, dayRate)
			changed = true
		end
		table.insert(kept, entry)
	end
	for slot = #kept + 1, #pools do
		local def = Quests.pick(profile, kind, slot, kept, {}, roll())
		if def == nil then
			break
		end
		table.insert(kept, Quests.entry(profile, def, dayRate))
		changed = true
	end
	if changed then
		if kind == "daily" then
			quests.daily = kept
		else
			quests.weekly = kept
		end
	end
	return changed
end

-- What finishing slot `slot` of `kind` pays: the Big Request pays more.
function Quests.prize(kind: Types.QuestKind, slot: number): Types.IndexPrize
	if kind == "weekly" then
		return Catalog.questPrizes.weekly
	end
	return if Quests.DAILY_POOLS[slot] == "big"
		then Catalog.questPrizes.dailyBig
		else Catalog.questPrizes.daily
end

function Quests.setPrize(kind: Types.QuestKind): Types.IndexPrize
	return if kind == "daily" then Catalog.questPrizes.dailySet else Catalog.questPrizes.weeklySet
end

-- Why ClaimQuest refuses, or nil: no such slot, already claimed, or not finished.
function Quests.claimBlocker(
	profile: Types.PlayerProfile,
	kind: Types.QuestKind,
	slot: number
): string?
	local list = if kind == "daily" then profile.quests.daily else profile.quests.weekly
	local entry = list[slot]
	if entry == nil then
		return "No such quest"
	elseif entry.claimed then
		return "Already claimed"
	elseif not Quests.done(profile, entry) then
		return "Not finished yet"
	end
	return nil
end

-- Why RerollQuest refuses, or nil: the free reroll is spent, or the quest is finished or claimed.
function Quests.rerollBlocker(
	profile: Types.PlayerProfile,
	kind: Types.QuestKind,
	slot: number
): string?
	local quests = profile.quests
	local list = if kind == "daily" then quests.daily else quests.weekly
	local used = if kind == "daily" then quests.dailyReroll else quests.weeklyReroll
	local entry = list[slot]
	if entry == nil then
		return "No such quest"
	elseif used then
		return if kind == "daily"
			then "You've used today's free swap"
			else "You've used this week's free swap"
	elseif entry.claimed or Quests.done(profile, entry) then
		return "That quest is done"
	end
	return nil
end

-- Whether every slot of a full set is claimed.
function Quests.allClaimed(list: { Types.QuestEntry }, slots: number): boolean
	if #list < slots then
		return false
	end
	for _, entry in list do
		if not entry.claimed then
			return false
		end
	end
	return true
end

-- An achievement's measure now (quests.md section 6): a Stats key, "lifetimeCoins", "tier", "distinctCats",
-- "goldCats", "mythicalCats", "decorOwned", "topCatLevel" or "upgrade:<id>".
function Quests.measure(profile: Types.PlayerProfile, measure: string): number
	if string.sub(measure, 1, 8) == "upgrade:" then
		return Economy.level(profile, string.sub(measure, 9))
	elseif measure == "tier" then
		return Economy.tier(profile)
	elseif measure == "goldCats" then
		return count(profile.goldCollection)
	elseif measure == "mythicalCats" then
		local n = 0
		for catId in profile.collection do
			local def = Catalog.getCat(catId)
			if def ~= nil and def.rarity == "Mythical" then
				n += 1
			end
		end
		return n
	elseif measure == "decorOwned" then
		local n = 0
		for _, owned in profile.decorOwned do
			if owned then
				n += 1
			end
		end
		return n
	elseif measure == "topCatLevel" then
		local top = 0
		for _, instance in profile.cats do
			top = math.max(top, instance.level)
		end
		return top
	end
	return Quests.value(profile, measure)
end

-- An achievement's progress, capped at its needs.
function Quests.achievementProgress(profile: Types.PlayerProfile, def: Types.AchievementDef): number
	return math.min(Quests.measure(profile, def.measure), def.needs)
end

-- Why ClaimAchievement refuses, or nil.
function Quests.achievementBlocker(profile: Types.PlayerProfile, achievementId: string): string?
	local def = Catalog.getAchievement(achievementId)
	if def == nil then
		return "Unknown"
	elseif profile.achievements[achievementId] == true then
		return "Already claimed"
	elseif Quests.achievementProgress(profile, def) < def.needs then
		return "Not there yet"
	end
	return nil
end

function Quests.achievementPrize(def: Types.AchievementDef): Types.IndexPrize
	return Catalog.achievementPrizes[def.size]
end

-- ProfileSync's quests at `now`.
function Quests.view(profile: Types.PlayerProfile, now: number): Types.QuestsView
	local function rows(list: { Types.QuestEntry }): { Types.QuestView }
		local out: { Types.QuestView } = {}
		for _, entry in list do
			local def = Catalog.getQuest(entry.id)
			table.insert(out, {
				id = entry.id,
				text = if def ~= nil then def.text else entry.id,
				progress = Quests.progress(profile, entry),
				needs = entry.needs,
				claimed = entry.claimed,
			})
		end
		return out
	end
	local quests = profile.quests
	return {
		daily = rows(quests.daily),
		weekly = rows(quests.weekly),
		dailyResetsAt = Quests.dayEndsAt(now),
		weeklyResetsAt = Quests.weekEndsAt(now),
		dailyRerollUsed = quests.dailyReroll,
		weeklyRerollUsed = quests.weeklyReroll,
		dailySetClaimed = quests.dailySet,
		weeklySetClaimed = quests.weeklySet,
	}
end

-- ProfileSync's achievements: every one's progress and claim.
function Quests.achievementsView(profile: Types.PlayerProfile): { [string]: Types.AchievementView }
	local out: { [string]: Types.AchievementView } = {}
	for _, def in Catalog.achievements do
		out[def.id] = {
			progress = Quests.achievementProgress(profile, def),
			claimed = profile.achievements[def.id] == true,
		}
	end
	return out
end

return Quests
