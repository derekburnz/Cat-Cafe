--!strict
-- The Cafe Pass (#1644, #1645; cafe-pass.md, quests.md section 8), pure: the season clock, pass XP and levels, the
-- free and paid tracks' claims, the season roll and the view the Pass screen draws. CafePassService pays the rewards
-- and owns the remotes; the reward tables are Catalog.passSeasons.
--
-- Seasons: Config.SeasonStarts lists each season's first day as a UTC date ("2026-12-01"), oldest first. Season n runs
-- from its date to the next one's; the newest stays open until a later date is added. With no date yet the pass is
-- closed (season 0) everywhere but Studio, where a preview season 1 runs from the epoch so it can be playtested.
-- Season n uses Catalog.passSeasons[n], wrapping round when there are more dates than tables, so a later season can
-- rerun an earlier one's items (nothing is gone forever).
--
-- The save (profile.pass): { season, xp, paidSeason, claimedFree, claimedPaid, items, tag }. `season` is the season
-- its xp and claims belong to; `paidSeason` the season whose paid track was bought; `items` the paid track's named
-- items owned forever (accessories, uniform colours, decor, the tag, the frame, the season cat), never reset.
--   seasonAt(now, preview) -> (season, startsAt, endsAt?)
--   levelOf(xp) -> level 0 to PassLevels
--   roll(state, season) -> { Claim }          moves a save to `season`, returning the old season's reached, unclaimed
--                                             rewards for the caller to pay (free always, paid if it was bought)
--   claimBlocker(state, season, track, level) -> reason?
--   claimable(state, season) -> { Claim }     every reached, unclaimed reward, free first, by level
--   markClaimed(state, track, level)
--   addXp(state, season, xp)
--   view(state, season, startsAt, endsAt?) -> Types.CafePassView

local Catalog = require(script.Parent.Catalog)
local ChatTags = require(script.Parent.ChatTags)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local CafePass = {}

export type Track = "free" | "paid"
export type Claim = { season: number, track: Track, level: number }

local TRACKS: { Track } = { "free", "paid" }
table.freeze(TRACKS)
CafePass.TRACKS = TRACKS

local DAY = 86400

-- Days from 1970-01-01 to the given UTC civil date (Howard Hinnant's days_from_civil), so a date needs no os.time
-- table (whose time zone differs between Roblox and the spec runner).
local function daysFromCivil(year: number, month: number, day: number): number
	local y = if month <= 2 then year - 1 else year
	local era = (if y >= 0 then y else y - 399) // 400
	local yoe = y - era * 400
	local mp = (month + 9) % 12
	local doy = (153 * mp + 2) // 5 + day - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	return era * 146097 + doe - 719468
end

-- "2026-12-01" as Unix seconds at that day's UTC midnight, or nil for anything else.
function CafePass.dateToTime(date: unknown): number?
	if type(date) ~= "string" then
		return nil
	end
	local y, m, d = date:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
	if y == nil or m == nil or d == nil then
		return nil
	end
	local year, month, day = tonumber(y) :: number, tonumber(m) :: number, tonumber(d) :: number
	if month < 1 or month > 12 or day < 1 or day > 31 then
		return nil
	end
	return daysFromCivil(year, month, day) * DAY
end

-- Each season's start in Unix seconds, oldest first, from Config.SeasonStarts (unreadable dates dropped).
function CafePass.starts(): { number }
	local out: { number } = {}
	for _, date in Config.SeasonStarts do
		local at = CafePass.dateToTime(date)
		if at ~= nil then
			table.insert(out, at)
		end
	end
	table.sort(out)
	return out
end

-- The season running at `now`: its number (0 for none), its start and its end (nil while no later date is set).
-- `preview` (Studio) runs season 1 from the epoch when no date has started yet.
function CafePass.seasonAt(now: number, preview: boolean?): (number, number, number?)
	local starts = CafePass.starts()
	local season = 0
	for index, at in starts do
		if now >= at then
			season = index
		end
	end
	if season == 0 then
		if preview == true then
			return 1, 0, starts[1]
		end
		return 0, 0, starts[1]
	end
	return season, starts[season], starts[season + 1]
end

-- The reward tables of season `season` (wrapping round Catalog.passSeasons), or nil for season 0.
function CafePass.seasonDef(season: number): Types.PassSeasonDef?
	if season < 1 or #Catalog.passSeasons == 0 then
		return nil
	end
	return Catalog.passSeasons[(season - 1) % #Catalog.passSeasons + 1]
end

function CafePass.maxXp(): number
	return Config.PassLevels * Config.PassXpPerLevel
end

-- The level `xp` pass XP reaches, 0 to PassLevels.
function CafePass.levelOf(xp: number): number
	return math.clamp(math.floor(math.max(0, xp) / Config.PassXpPerLevel), 0, Config.PassLevels)
end

-- The reward at `level` of `track` in season `season`, or nil (the free track rewards every second level).
function CafePass.rewardOf(season: number, track: Track, level: number): Types.PassReward?
	local def = CafePass.seasonDef(season)
	if def == nil then
		return nil
	end
	local rows = if track == "free" then def.free else def.paid
	return rows[level]
end

function CafePass.fresh(season: number): Types.PassState
	return {
		season = season,
		xp = 0,
		paidSeason = 0,
		claimedFree = {},
		claimedPaid = {},
		items = {},
		tag = nil,
	}
end

local function levelList(raw: unknown): { number }
	local out: { number } = {}
	if type(raw) ~= "table" then
		return out
	end
	local seen: { [number]: boolean } = {}
	for _, level in raw :: { any } do
		if
			type(level) == "number"
			and level == math.floor(level)
			and level >= 1
			and level <= Config.PassLevels
			and not seen[level]
		then
			seen[level] = true
			table.insert(out, level)
		end
	end
	table.sort(out)
	return out
end

-- Every named item id the pass seasons can give, for sanitize.
local knownItems: { [string]: boolean } = {}
for _, def in Catalog.passSeasons do
	for _, row in def.paid do
		if row.item ~= nil then
			knownItems[row.item.id] = true
		end
	end
end

-- A saved pass made whole. A save from before the pass (nil) starts at season 0 with nothing.
function CafePass.sanitize(raw: unknown): Types.PassState
	if type(raw) ~= "table" then
		return CafePass.fresh(0)
	end
	local t = raw :: { [string]: any }
	local function whole(value: any): number
		return if type(value) == "number"
				and value == math.floor(value)
				and value >= 0
			then value
			else 0
	end
	local items: { [string]: boolean } = {}
	if type(t.items) == "table" then
		for id, owned in t.items do
			if type(id) == "string" and owned == true and knownItems[id] then
				items[id] = true
			end
		end
	end
	local xp = if type(t.xp) == "number" and t.xp == t.xp
		then math.clamp(t.xp, 0, CafePass.maxXp())
		else 0
	return {
		season = whole(t.season),
		xp = xp,
		paidSeason = whole(t.paidSeason),
		claimedFree = levelList(t.claimedFree),
		claimedPaid = levelList(t.claimedPaid),
		items = items,
		tag = if ChatTags.validPick(t.tag) then t.tag else nil, -- #1626: a tag id or "off" (ChatTags)
	}
end

local function claimedList(state: Types.PassState, track: Track): { number }
	return if track == "free" then state.claimedFree else state.claimedPaid
end

-- Whether `level` of `track` is claimed in the save's season.
function CafePass.isClaimed(state: Types.PassState, track: Track, level: number): boolean
	return table.find(claimedList(state, track), level) ~= nil
end

-- Every reached, unclaimed reward of the save's own season: free ones, then paid ones if that season's paid track
-- was bought, each by level.
local function unclaimed(state: Types.PassState): { Claim }
	local out: { Claim } = {}
	local reached = CafePass.levelOf(state.xp)
	for _, track: Track in TRACKS do
		if track == "paid" and state.paidSeason ~= state.season then
			continue
		end
		for level = 1, reached do
			if
				CafePass.rewardOf(state.season, track, level) ~= nil
				and not CafePass.isClaimed(state, track, level)
			then
				local claim: Claim = { season = state.season, track = track, level = level }
				table.insert(out, claim)
			end
		end
	end
	return out
end

-- Moves the save to season `season`. When it held an older season, that season's reached, unclaimed rewards are
-- returned for the caller to pay (cafe-pass.md section 5: they arrive on the next join), and XP and claims reset;
-- items, the tag and paidSeason stay. A save already on `season`, or season 0, changes nothing.
function CafePass.roll(state: Types.PassState, season: number): { Claim }
	if season == 0 or state.season == season then
		return {}
	end
	local owed = if state.season > 0 then unclaimed(state) else {}
	state.season = season
	state.xp = 0
	state.claimedFree = {}
	state.claimedPaid = {}
	return owed
end

-- Why `level` of `track` can't be claimed now, or nil. The save must be on the running season (roll first).
function CafePass.claimBlocker(
	state: Types.PassState,
	season: number,
	track: Track,
	level: number
): string?
	if season == 0 or state.season ~= season then
		return "The Cafe Pass isn't running right now"
	end
	if CafePass.rewardOf(season, track, level) == nil then
		return "Nothing at that level"
	end
	if level > CafePass.levelOf(state.xp) then
		return "Reach that level first"
	end
	if track == "paid" and state.paidSeason ~= season then
		return "That one is on the paid track"
	end
	if CafePass.isClaimed(state, track, level) then
		return "Already claimed"
	end
	return nil
end

-- Every reward of the running season that can be claimed now.
function CafePass.claimable(state: Types.PassState, season: number): { Claim }
	if season == 0 or state.season ~= season then
		return {}
	end
	return unclaimed(state)
end

-- #1626: unlocks the paid track of the running `season` for a save already rolled onto it, in the same step as the
-- receipt (ProductService). True when it was bought now; false with no season running, the save on another season,
-- or this season's track already bought (paidSeason stays, so a season's paid rewards are never lost).
function CafePass.buyPaid(state: Types.PassState, season: number): boolean
	if season == 0 or state.season ~= season or state.paidSeason == season then
		return false
	end
	state.paidSeason = season
	return true
end

-- Marks a claim in the save's season (and an item reward owned), in the same step the caller pays it.
function CafePass.markClaimed(state: Types.PassState, track: Track, level: number, season: number)
	local list = claimedList(state, track)
	if table.find(list, level) == nil then
		table.insert(list, level)
		table.sort(list)
	end
	local reward = CafePass.rewardOf(season, track, level)
	if reward ~= nil and reward.item ~= nil then
		state.items[reward.item.id] = true
	end
end

-- Adds quest pass XP (quests.md section 8) to the running season, up to the last level, and returns how much went
-- in (0 with no season running, or when the save is not on it yet).
function CafePass.addXp(state: Types.PassState, season: number, xp: number): number
	if season == 0 or state.season ~= season or type(xp) ~= "number" or xp <= 0 then
		return 0
	end
	local before = state.xp
	state.xp = math.min(state.xp + xp, CafePass.maxXp())
	return state.xp - before
end

-- What CafePassState sends: the season and its dates, the player's level and XP, whether the paid track is bought,
-- and the claims. The Pass screen reads the rows themselves from Catalog.passSeasons through seasonDef.
function CafePass.view(
	state: Types.PassState,
	season: number,
	startsAt: number,
	endsAt: number?
): Types.CafePassView
	local level = CafePass.levelOf(state.xp)
	return {
		season = season,
		startsAt = startsAt,
		endsAt = endsAt,
		level = level,
		xp = state.xp,
		xpPerLevel = Config.PassXpPerLevel,
		levels = Config.PassLevels,
		paid = season > 0 and state.paidSeason == season,
		claimedFree = table.clone(state.claimedFree),
		claimedPaid = table.clone(state.claimedPaid),
		claimable = #CafePass.claimable(state, season),
		items = table.clone(state.items),
		tag = state.tag,
	}
end

return CafePass
