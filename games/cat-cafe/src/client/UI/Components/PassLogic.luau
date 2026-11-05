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

return PassLogic
