--!strict
-- Daily quests, weekly quests and achievements as the Quests window and the HUD show them (F73, quests.md sections 1
-- and 7):
--   done(quest) -> boolean                       its progress reached its needs
--   prize(catalog, kind, slot) -> IndexPrize?    what one quest pays: the fifth daily is the Big Request
--   setPrize(catalog, kind) -> IndexPrize?       what finishing all of them pays (dailySet, weeklySet)
--   doneCount(quests) -> number                  finished ones, claimed or not ("3 of 5 done")
--   claimable(state, catalog) -> number          quests and achievements ready to claim: the Quests pill's dot
--   isCoins(catalog, id) -> boolean              a coins quest, whose progress reads as money
--   resetText(seconds) -> string                 "New quests in 5 h"
--   achievementRows(catalog, views) -> rows      ready to claim first, then the closest to done, claimed last
--   claimedCount(catalog, views) -> number       achievements claimed ("12 of 44")
--   tracker(quests) -> QuestView?                the closest unfinished, unclaimed daily for the HUD's quest line
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

local function readyQuests(quests: { Types.QuestView }?): number
	local count = 0
	local list: { Types.QuestView } = quests or {}
	for _, quest in list do
		if not quest.claimed and QuestLogic.done(quest) then
			count += 1
		end
	end
	return count
end

function QuestLogic.claimable(state: Types.PlayerState, catalog: Types.Catalog?): number
	local count = 0
	local quests = state.quests
	if quests then
		count += readyQuests(quests.daily) + readyQuests(quests.weekly)
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

function QuestLogic.tracker(quests: Types.QuestsView?): Types.QuestView?
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
	return best
end

return QuestLogic
