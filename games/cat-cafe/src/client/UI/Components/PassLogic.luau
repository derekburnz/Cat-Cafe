--!strict
-- The Cafe Pass screen's rules (#1646, cafe-pass.md sections 1 to 5), pure so the specs can check them. The server's
-- CafePassState (Types.CafePassView) says the season, level, XP, whether the paid track is bought and what is claimed;
-- the rows come from Catalog.passSeasons through shared CafePass.seasonDef.
--   PassLogic.columns(view, def)   one column per level: its free reward (every second level) and its paid reward,
--                                   each "ready", "claimed", "ahead" (not reached yet) or "locked" (paid, not bought)
--   PassLogic.progress(view)       the level, the XP bar's share and its words ("320 / 800 XP", "Max level")
--   PassLogic.endText(view)        "Season 1 ends 3 January", a plain date and never a countdown (section 1)
--   PassLogic.subtitle(view, name) the window's subtitle: "Season 1: Maple · ends 3 January"
--   PassLogic.readyCount(columns)  the rewards Claim all would take
--   PassLogic.focus(columns, level)  the column to scroll to: the first ready one, else the next to reach
--   PassLogic.shows(view)          whether the HUD's Pass tile shows (a season is running)
--   PassLogic.itemGlyph(kind)      a named item's symbol until its picture is drawn
--   PassLogic.paidContents(def)    the paid track's exact contents in words, for the Store card (monetization policy)

local Types = require(script.Parent.Parent.Types)

export type Track = "free" | "paid"
export type CellState = "ready" | "claimed" | "ahead" | "locked"
export type Cell = {
	track: Track,
	level: number,
	reward: Types.PassReward,
	state: CellState,
}
export type Column = {
	level: number,
	reached: boolean,
	free: Cell?,
	paid: Cell?,
}
export type Progress = {
	level: number,
	levels: number,
	fraction: number, -- 0 to 1 of the way to the next level
	text: string,
	max: boolean,
}

local PassLogic = {}

local MONTHS = {
	"January",
	"February",
	"March",
	"April",
	"May",
	"June",
	"July",
	"August",
	"September",
	"October",
	"November",
	"December",
}

local ITEM_GLYPHS: { [string]: string } = {
	tag = "🏷️",
	accessory = "🎀",
	uniform = "👕",
	decor = "🪴",
	frame = "🖼️",
	cat = "🐱",
}

local function listed(list: { number }?, level: number): boolean
	local levels: { number } = list or {}
	for _, claimed in levels do
		if claimed == level then
			return true
		end
	end
	return false
end

local function cell(
	view: Types.CafePassView,
	track: Track,
	level: number,
	reward: Types.PassReward?
): Cell?
	if reward == nil then
		return nil
	end
	local claimed = listed(if track == "free" then view.claimedFree else view.claimedPaid, level)
	local state: CellState = if claimed
		then "claimed"
		elseif track == "paid" and not view.paid then "locked"
		elseif level > view.level then "ahead"
		else "ready"
	return { track = track, level = level, reward = reward, state = state }
end

-- Every level from 1 to view.levels with its two rewards; a level with no free reward has free = nil.
function PassLogic.columns(view: Types.CafePassView?, def: Types.PassSeasonDef?): { Column }
	local out: { Column } = {}
	if view == nil or def == nil or view.season <= 0 then
		return out
	end
	for level = 1, view.levels do
		table.insert(out, {
			level = level,
			reached = level <= view.level,
			free = cell(view, "free", level, def.free[level]),
			paid = cell(view, "paid", level, def.paid[level]),
		})
	end
	return out
end

function PassLogic.progress(view: Types.CafePassView): Progress
	local per = math.max(1, view.xpPerLevel)
	local level = math.clamp(view.level, 0, view.levels)
	if level >= view.levels then
		return { level = level, levels = view.levels, fraction = 1, text = "Max level", max = true }
	end
	local into = math.clamp(view.xp - level * per, 0, per)
	return {
		level = level,
		levels = view.levels,
		fraction = into / per,
		text = ("%d / %d XP"):format(into, per),
		max = false,
	}
end

-- A UTC day number as (year, month, day): Howard Hinnant's civil_from_days, so no time zone comes in.
local function civil(days: number): (number, number, number)
	local z = days + 719468
	local era = (if z >= 0 then z else z - 146096) // 146097
	local doe = z - era * 146097
	local yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
	local doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
	local mp = (5 * doy + 2) // 153
	local day = doy - (153 * mp + 2) // 5 + 1
	local month = if mp < 10 then mp + 3 else mp - 9
	local year = yoe + era * 400 + (if month <= 2 then 1 else 0)
	return year, month, day
end

-- "3 January" for Unix seconds (UTC), the day the next season starts.
function PassLogic.dateText(at: number): string
	local _, month, day = civil(at // 86400)
	return ("%d %s"):format(day, MONTHS[month])
end

-- The season's end as a plain date, or just its number while no later season is set.
function PassLogic.endText(view: Types.CafePassView): string
	local endsAt = view.endsAt
	if endsAt == nil or endsAt <= 0 then
		return ("Season %d"):format(view.season)
	end
	return ("Season %d ends %s"):format(view.season, PassLogic.dateText(endsAt))
end

-- The season's name and its end as a plain date, or the end line alone when the season has no name.
function PassLogic.subtitle(view: Types.CafePassView, name: string?): string
	if name == nil or name == "" then
		return PassLogic.endText(view)
	end
	local endsAt = view.endsAt
	if endsAt == nil or endsAt <= 0 then
		return name
	end
	return ("%s  ·  ends %s"):format(name, PassLogic.dateText(endsAt))
end

function PassLogic.readyCount(columns: { Column }): number
	local count = 0
	for _, column in columns do
		if column.free and column.free.state == "ready" then
			count += 1
		end
		if column.paid and column.paid.state == "ready" then
			count += 1
		end
	end
	return count
end

-- The column the track scrolls to when the window opens: the first with a reward ready, else the next level.
function PassLogic.focus(columns: { Column }, level: number): number
	for index, column in columns do
		if
			(column.free ~= nil and column.free.state == "ready")
			or (column.paid ~= nil and column.paid.state == "ready")
		then
			return index
		end
	end
	return math.clamp(level + 1, 1, math.max(1, #columns))
end

function PassLogic.shows(view: Types.CafePassView?): boolean
	return view ~= nil and view.season > 0
end

function PassLogic.itemGlyph(kind: string): string
	return ITEM_GLYPHS[kind] or "🎁"
end

-- The words under a named item: its name without the kind the picture already shows ("Uniform colour: Pumpkin" reads
-- "Pumpkin uniform", "Season 1 chat tag [Maple]" reads "[Maple] chat tag").
function PassLogic.itemText(item: Types.PassItem): string
	local name = item.name
	if item.kind == "uniform" then
		local colour = name:match("^Uniform colour: (.+)$")
		return if colour then colour .. " uniform" else name
	elseif item.kind == "tag" then
		local tag = name:match("(%[.-%])")
		return if tag then tag .. " chat tag" else name
	elseif item.kind == "frame" then
		local frame = name:match("^Name plate frame: (.+)$")
		return if frame then frame .. " sign frame" else name
	elseif item.kind == "cat" then
		local cat = name:match("^Season cat: (.+)$")
		return cat or name
	end
	return name
end

-- How each kind of named item is counted on the Store card: one word, and its plural
local KIND_WORDS: { { kind: string, one: string, many: string } } = {
	{ kind = "uniform", one = "a uniform colour", many = "%d uniform colours" },
	{ kind = "accessory", one = "an accessory", many = "%d accessories" },
	{ kind = "decor", one = "a decor piece", many = "%d decor pieces" },
	{ kind = "frame", one = "a sign frame", many = "%d sign frames" },
}

-- "Season cat Maple Muffin, [Maple] chat tag, 4 uniform colours, 5 accessories, 6 decor pieces, a sign frame and
-- 15 potions": every paid reward of the season, the cat and the tag by name, the rest counted.
function PassLogic.paidContents(def: Types.PassSeasonDef?): string
	if def == nil then
		return ""
	end
	local parts: { string } = {}
	local counts: { [string]: number } = {}
	local named: { string } = {}
	local potions = 0
	for level = 1, 100 do
		local reward = def.paid[level]
		if reward == nil then
			continue
		end
		local item = reward.item
		if item then
			if item.kind == "cat" then
				table.insert(named, 1, "Season cat " .. PassLogic.itemText(item))
			elseif item.kind == "tag" then
				table.insert(named, PassLogic.itemText(item))
			else
				counts[item.kind] = (counts[item.kind] or 0) + 1
			end
		end
		local prize = reward.prize
		local bottles: { [string]: number } = if prize and prize.potions then prize.potions else {}
		for _, count in bottles do
			potions += count
		end
	end
	for _, name in named do
		table.insert(parts, name)
	end
	for _, words in KIND_WORDS do
		local count = counts[words.kind] or 0
		if count == 1 then
			table.insert(parts, words.one)
		elseif count > 1 then
			table.insert(parts, words.many:format(count))
		end
	end
	if potions > 0 then
		table.insert(parts, if potions == 1 then "a potion" else ("%d potions"):format(potions))
	end
	if #parts == 0 then
		return ""
	elseif #parts == 1 then
		return parts[1]
	end
	local last = table.remove(parts) :: string
	return table.concat(parts, ", ") .. " and " .. last
end

return PassLogic
