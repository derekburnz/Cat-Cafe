--!strict
-- Claim all (Derek 2026-10-28: "more claim all buttons needed so many reward pop ups"; ui-contract.md `claimAll`),
-- pure: which rewards one ClaimAll(what) pays, and its one toast's lines. `what` is one of KINDS: "daily", "weekly"
-- and "achievements" (the Quests window), "index" (every page of the Index window) or "tipjar" (the Tip Jar). Each
-- list is in the order its window shows, using the same checks as the single claims (Quests.claimBlocker,
-- Quests.achievementBlocker, IndexRewards.blocker, TipJar.isReady), so Claim all never pays anything a single Claim
-- would refuse. `merge` adds up the paid lines of several Payout.pay calls ("+$300" and "+$500" are "+$800").

local Catalog = require(script.Parent.Catalog)
local IndexRewards = require(script.Parent.IndexRewards)
local Quests = require(script.Parent.Quests)
local TipJar = require(script.Parent.TipJar)
local Types = require(script.Parent.Types)

local ClaimAll = {}

-- "quests" (#1073, Derek 2026-11-04): the Quests window's one Claim all, every ready daily, weekly and achievement
ClaimAll.KINDS = { "daily", "weekly", "achievements", "quests", "index", "tipjar" }
ClaimAll.NOTHING = "Nothing to claim yet"

export type IndexClaim = { areaId: string, milestoneId: string }

-- The finished, unclaimed quests of the player's daily or weekly set, by slot.
function ClaimAll.quests(profile: Types.PlayerProfile, kind: Types.QuestKind): { number }
	local ready: { number } = {}
	local list = if kind == "daily" then profile.quests.daily else profile.quests.weekly
	for slot = 1, #list do
		if Quests.claimBlocker(profile, kind, slot) == nil then
			table.insert(ready, slot)
		end
	end
	return ready
end

export type QuestsReady = {
	daily: { number },
	weekly: { number },
	achievements: { string },
	count: number,
}

-- Everything the Quests window's one Claim all pays (#1073): the ready daily and weekly slots and the met achievements,
-- with how many in all. The button shows while `count` is above 0.
function ClaimAll.questReady(profile: Types.PlayerProfile): QuestsReady
	local daily = ClaimAll.quests(profile, "daily")
	local weekly = ClaimAll.quests(profile, "weekly")
	local achievements = ClaimAll.achievements(profile)
	return {
		daily = daily,
		weekly = weekly,
		achievements = achievements,
		count = #daily + #weekly + #achievements,
	}
end

-- The met, unclaimed achievements, in Catalog order.
function ClaimAll.achievements(profile: Types.PlayerProfile): { string }
	local ready: { string } = {}
	for _, def in Catalog.achievements do
		if Quests.achievementBlocker(profile, def.id) == nil then
			table.insert(ready, def.id)
		end
	end
	return ready
end

-- The Index pages in the window's order: the areas by tier, All Cats, the Rainbow page, then the Decor pages by name.
function ClaimAll.indexPages(): { string }
	local pages: { string } = {}
	local seen: { [string]: boolean } = {}
	local function add(pageId: string)
		if Catalog.indexPrizes[pageId] ~= nil and not seen[pageId] then
			seen[pageId] = true
			table.insert(pages, pageId)
		end
	end
	for _, area in Catalog.areas do
		add(area.id)
	end
	add(IndexRewards.ALL)
	add(IndexRewards.RAINBOW)
	local rest: { string } = {}
	for pageId in Catalog.indexPrizes do
		if not seen[pageId] then
			table.insert(rest, pageId)
		end
	end
	table.sort(rest)
	for _, pageId in rest do
		add(pageId)
	end
	return pages
end

-- Every Index reward the player can claim now, page by page in `indexPages` order, each page's milestones in
-- Catalog.indexMilestones order.
function ClaimAll.index(profile: Types.PlayerProfile): { IndexClaim }
	local ready: { IndexClaim } = {}
	for _, areaId in ClaimAll.indexPages() do
		for _, milestone in Catalog.indexMilestones do
			if
				IndexRewards.prize(areaId, milestone.id) ~= nil
				and IndexRewards.blocker(profile, areaId, milestone.id) == nil
			then
				local claim: IndexClaim = { areaId = areaId, milestoneId = milestone.id }
				table.insert(ready, claim)
			end
		end
	end
	return ready
end

-- The Tip Jar steps ready and unclaimed this session at `now` (the server's clock), by step.
function ClaimAll.tipJar(claimed: { boolean }, sessionStartedAt: number, now: number): { number }
	local ready: { number } = {}
	for step, def in Catalog.tipJar do
		if not claimed[step] and TipJar.isReady(def, sessionStartedAt, now) then
			table.insert(ready, step)
		end
	end
	return ready
end

-- Adds up the lines Payout.pay returned for several prizes, in the order each first came: money, golden fish, spins,
-- "+N% <what> forever" and counted items ("2 Tuna", "1 Alley Crate") by name. A spin line that hit the cap and a tag
-- stay as they are.
function ClaimAll.merge(lines: { string }): { string }
	type Entry = { format: string, name: string?, total: number?, text: string? }
	local order: { Entry } = {}
	local byKey: { [string]: Entry } = {}
	local function add(key: string, format: string, name: string?, amount: number)
		local entry = byKey[key]
		if entry == nil then
			local fresh: Entry = { format = format, name = name, total = 0 }
			entry = fresh
			byKey[key] = fresh
			table.insert(order, fresh)
		end
		entry.total = (entry.total :: number) + amount
	end
	for _, line in lines do
		local coins = string.match(line, "^%+%$(%d+)$")
		local fish = string.match(line, "^%+(%d+) golden fish$")
		local percent, what = string.match(line, "^%+(%d+)%% (.+) forever$")
		local spins = string.match(line, "^(%d+) spins?$")
		local count, name = string.match(line, "^(%d+) (.+)$")
		if coins ~= nil then
			add("coins", "coins", nil, tonumber(coins) :: number)
		elseif fish ~= nil then
			add("fish", "fish", nil, tonumber(fish) :: number)
		elseif percent ~= nil and what ~= nil then
			add("forever " .. what, "forever", what, tonumber(percent) :: number)
		elseif spins ~= nil then
			add("spins", "spins", nil, tonumber(spins) :: number)
		elseif count ~= nil and name ~= nil and not string.find(name, "(", 1, true) then
			add("count " .. name, "count", name, tonumber(count) :: number)
		else
			local kept: Entry = { format = "text", text = line }
			table.insert(order, kept)
		end
	end
	local out: { string } = {}
	for _, entry in order do
		local total = entry.total or 0
		if entry.format == "coins" then
			table.insert(out, string.format("+$%d", total))
		elseif entry.format == "fish" then
			table.insert(out, string.format("+%d golden fish", total))
		elseif entry.format == "forever" then
			table.insert(out, string.format("+%d%% %s forever", total, entry.name :: string))
		elseif entry.format == "spins" then
			table.insert(out, string.format("%d spin%s", total, if total == 1 then "" else "s"))
		elseif entry.format == "count" then
			table.insert(out, string.format("%d %s", total, entry.name :: string))
		else
			table.insert(out, entry.text :: string)
		end
	end
	return out
end

return ClaimAll
