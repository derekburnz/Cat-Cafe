--!strict
-- Daily quests, weekly quests and achievements as the Quests window and the HUD show them (F73, quests.md sections 1
-- and 7):
--   done(quest) -> boolean                       its progress reached its needs
--   prize(catalog, kind, slot) -> IndexPrize?    what one quest pays: the fifth daily is the Big Request
--   setPrize(catalog, kind) -> IndexPrize?       what finishing all of them pays (dailySet, weeklySet)
--   doneCount(quests) -> number                  finished ones, claimed or not ("3 of 5 done")
--   claimable(state, catalog) -> number          quests and achievements ready to claim: the Quests pill's dot
--   readyCount(quests) -> number                 finished and unclaimed quests in one set (Claim All shows at 2)
--   rowOrder(slot, claimed) -> number            a quest row's LayoutOrder: claimed ones drop to the bottom
--   isCoins(catalog, id) -> boolean              a coins quest, whose progress reads as money
--   resetText(seconds) -> string                 "New quests in 5 h"
--   swapText(seconds) -> string                  "7h 12m": the used weekly Swap's wait (#1166)
--   swapFree(quests, used) -> boolean            a free swap waits on an unfinished quest (the Weekly tab's dot)
--   achievementRows(catalog, views) -> rows      ready to claim first, then the closest to done, claimed last
--   claimedCount(catalog, views) -> number       achievements claimed ("12 of 44")
--   tracker(quests, pin?) -> QuestView?, pinned  the HUD's quest line: the pinned quest while it is unfinished (#1573),
--                                                else the closest unfinished, unclaimed daily
--   pinKey(kind, id) -> string                   a pinned quest's key, "daily:<id>" or "weekly:<id>"
-- Pure: no Theme, Format or CFrame, so the cloud test runner checks it.

local Types = require(script.Parent.Parent.Types)

export type AchievementRow = {
	def: Types.AchievementDef,
	progress: number,
	claimed: boolean,
	ready: boolean, -- met and not claimed
}

local QuestLogic = {}

QuestLogic.BIG_SLOT = 5 -- the Big Request is the fifth daily (Quests.DAILY_POOLS)

local function number(value: any): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return 0
	end
	return value
end

function QuestLogic.done(quest: Types.QuestView): boolean
	local needs = math.max(1, number(quest.needs))
	return number(quest.progress) >= needs
end

function QuestLogic.prize(catalog: Types.Catalog?, kind: string, slot: number): Types.IndexPrize?
	local prizes = if catalog then catalog.questPrizes else nil
	if prizes == nil then
		return nil
	end
	if kind == "weekly" then
		return prizes.weekly
	end
	return if slot == QuestLogic.BIG_SLOT then prizes.dailyBig else prizes.daily
end

function QuestLogic.setPrize(catalog: Types.Catalog?, kind: string): Types.IndexPrize?
	local prizes = if catalog then catalog.questPrizes else nil
	if prizes == nil then
		return nil
	end
	return if kind == "weekly" then prizes.weeklySet else prizes.dailySet
end

function QuestLogic.doneCount(quests: { Types.QuestView }?): number
	local count = 0
	local list: { Types.QuestView } = quests or {}
	for _, quest in list do
		if quest.claimed or QuestLogic.done(quest) then
			count += 1
		end
	end
	return count
end

function QuestLogic.readyCount(quests: { Types.QuestView }?): number
	local count = 0
	local list: { Types.QuestView } = quests or {}
	for _, quest in list do
		if not quest.claimed and QuestLogic.done(quest) then
			count += 1
		end
	end
	return count
end

-- #1073: the Quests window's one Claim all counts what is ready across every tab (Daily, Weekly, Achievements) and
-- shows while that is above 0, so one claim no longer hides it while anything else waits.
function QuestLogic.claimAllCount(readyByTab: { [string]: number }?): number
	local count = 0
	if readyByTab == nil then
		return count
	end
	for _, ready in readyByTab do
		count += math.max(0, number(ready))
	end
	return count
end

-- Derek 2026-10-29: claimed quests drop to the bottom. The window's head and set strip sit at 1 and 2, the rows in
-- slot order after them, the claimed ones after all of those, still in slot order.
function QuestLogic.rowOrder(slot: number, claimed: boolean): number
	return (if claimed then 100 else 10) + slot
end

function QuestLogic.claimable(state: Types.PlayerState, catalog: Types.Catalog?): number
	local count = 0
	local quests = state.quests
	if quests then
		count += QuestLogic.readyCount(quests.daily) + QuestLogic.readyCount(quests.weekly)
	end
	local views = state.achievements
	local defs = if catalog then catalog.achievements else nil
	if views and defs then
		for _, def in defs do
			local view = views[def.id]
			if
				view
				and not view.claimed
				and number(view.progress) >= math.max(1, number(def.needs))
			then
				count += 1
			end
		end
	end
	return count
end

function QuestLogic.isCoins(catalog: Types.Catalog?, id: string): boolean
	local quests = if catalog then catalog.quests else nil
	if quests then
		for _, group in { quests.daily, quests.weekly } do
			for _, pool in group do
				for _, def in pool do
					if def.id == id then
						return def.stat == "lifetimeCoins"
					end
				end
			end
		end
	end
	return string.find(id, "coins", 1, true) ~= nil -- d_coins, d_coinsbig and w_coins before the catalog has them
end

-- "New quests in 3 d", "in 5 h", "in 42 min"; plain text that never flashes (quests.md section 1).
function QuestLogic.resetText(seconds: number): string
	local left = math.max(0, number(seconds))
	if left >= 86400 then
		return ("New quests in %d d"):format(math.floor(left / 86400))
	elseif left >= 3600 then
		return ("New quests in %d h"):format(math.floor(left / 3600))
	end
	return ("New quests in %d min"):format(math.max(1, math.ceil(left / 60)))
end

-- The weekly Swap's wait once it is used (#1166: the free weekly swap comes back every UTC day, with the dailies):
-- "7h 12m", "12m", or "1m" under a minute, short enough for the Swap button.
function QuestLogic.swapText(seconds: number): string
	local left = math.max(0, number(seconds))
	local hours = math.floor(left / 3600)
	local minutes = math.max(1, math.ceil((left - hours * 3600) / 60))
	if minutes >= 60 then
		hours += 1
		minutes = 0
	end
	if hours > 0 then
		return ("%dh %dm"):format(hours, minutes)
	end
	return ("%dm"):format(minutes)
end

-- Whether a free swap is waiting: unused, and some quest is neither done nor claimed (the Weekly tab's quiet dot).
function QuestLogic.swapFree(list: { Types.QuestView }, used: boolean): boolean
	if used then
		return false
	end
	for _, quest in list do
		if not quest.claimed and not QuestLogic.done(quest) then
			return true
		end
	end
	return false
end

function QuestLogic.achievementRows(
	catalog: Types.Catalog?,
	views: { [string]: Types.AchievementView }?
): { AchievementRow }
	local rows: { AchievementRow } = {}
	local order: { [AchievementRow]: number } = {}
	local defs: { Types.AchievementDef } = if catalog and catalog.achievements
		then catalog.achievements
		else {}
	for index, def in defs do
		local view = if views then views[def.id] else nil
		local needs = math.max(1, number(def.needs))
		local progress = math.clamp(number(if view then view.progress else 0), 0, needs)
		local claimed = view ~= nil and view.claimed == true
		local row: AchievementRow = {
			def = def,
			progress = progress,
			claimed = claimed,
			ready = not claimed and progress >= needs,
		}
		table.insert(rows, row)
		order[row] = index
	end
	local function rank(row: AchievementRow): number
		return if row.ready then 0 elseif row.claimed then 2 else 1
	end
	table.sort(rows, function(a: AchievementRow, b: AchievementRow): boolean
		local ra, rb = rank(a), rank(b)
		if ra ~= rb then
			return ra < rb
		end
		if ra == 1 then
			local fa = a.progress / math.max(1, a.def.needs)
			local fb = b.progress / math.max(1, b.def.needs)
			if fa ~= fb then
				return fa > fb
			end
		end
		return order[a] < order[b]
	end)
	return rows
end

function QuestLogic.claimedCount(
	catalog: Types.Catalog?,
	views: { [string]: Types.AchievementView }?
): number
	local count = 0
	local defs: { Types.AchievementDef } = if catalog and catalog.achievements
		then catalog.achievements
		else {}
	for _, def in defs do
		local view = if views then views[def.id] else nil
		if view and view.claimed then
			count += 1
		end
	end
	return count
end

function QuestLogic.pinKey(kind: string, id: string): string
	return kind .. ":" .. id
end

-- #1573 goal pinning (Derek, 2026-11-05: "tap a goal to pin it"): a pinned quest leads the HUD's line until it is done
-- or claimed, or a swap or the reset replaces it; then the line goes back to the closest daily.
function QuestLogic.tracker(quests: Types.QuestsView?, pin: string?): (Types.QuestView?, boolean)
	if quests and pin then
		for _, kind in { "daily", "weekly" } do
			local list: { Types.QuestView } = if kind == "daily"
				then quests.daily
				else quests.weekly
			for _, quest in list or {} do
				if
					QuestLogic.pinKey(kind, quest.id) == pin
					and not quest.claimed
					and not QuestLogic.done(quest)
				then
					return quest, true
				end
			end
		end
	end
	local best: Types.QuestView? = nil
	local bestShare = -1
	local daily: { Types.QuestView } = if quests then quests.daily else {}
	for _, quest in daily do
		if quest.claimed or QuestLogic.done(quest) then
			continue
		end
		local share = number(quest.progress) / math.max(1, number(quest.needs))
		if share > bestShare then
			best, bestShare = quest, share
		end
	end
	return best, false
end

return QuestLogic
