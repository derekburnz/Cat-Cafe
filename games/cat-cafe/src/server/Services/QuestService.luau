--!strict
-- Daily quests, weekly quests and achievements (F73, quests.md section 6). Rules in shared/Quests.
-- When a profile loads, and every QuestRollCheckSeconds for players in the game, a new UTC day or Monday-start week
-- first pays every finished, unclaimed quest of the old set (and the set prize when all of them were finished, so
-- nothing is lost by missing a day), then rolls a fresh set counting from the counters' values now. A save's unknown
-- or misplaced quest gets a fresh pick for its slot.
-- ClaimQuest(kind, slot) pays a finished quest and, when it is the set's last, the set prize (potions for the bag,
-- never drunk at once). RerollQuest(kind, slot) spends the day's or week's free swap on an unfinished quest.
-- ClaimAchievement(id) pays a met achievement once. Every claim is marked before it pays, so it pays once. Nothing here
-- is sold for Robux, and nothing skips a quest.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CafeService = require(script.Parent.CafeService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Guard = require(script.Parent.Parent.Util.Guard)
local Net = require(script.Parent.Net)
local Payout = require(script.Parent.Payout)
local Quests = require(ReplicatedStorage.Shared.Quests)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)

local QuestService = {}

local rng = Random.new()

local function roll(): number
	return rng:NextNumber()
end

local function listOf(profile: Types.PlayerProfile, kind: Types.QuestKind): { Types.QuestEntry }
	return if kind == "daily" then profile.quests.daily else profile.quests.weekly
end

local function append(into: { string }, from: { string })
	for _, line in from do
		table.insert(into, line)
	end
end

-- Marks slot `slot` claimed and pays it, then the set prize when it was the set's last unclaimed quest. Returns what
-- was paid. The caller has checked that it is finished and unclaimed. `auto` when a reset pays it.
local function payQuest(
	player: Player,
	profile: Types.PlayerProfile,
	kind: Types.QuestKind,
	slot: number,
	auto: boolean
): { string }
	local quests = profile.quests
	local list = listOf(profile, kind)
	local entry = list[slot]
	entry.claimed = true
	local sku = if kind == "daily" then "quest_daily" else "quest_weekly"
	local paid = Payout.pay(player, profile, Quests.prize(kind, slot), sku)
	if kind == "daily" then
		profile.stats.dailyQuestsDone += 1
	else
		profile.stats.weeklyQuestsDone += 1
	end
	-- three fields at most (Telemetry's customFields): a reset's payment marks the slot field "<slot> auto"
	local slotField = if auto then tostring(slot) .. " auto" else tostring(slot)
	Telemetry.custom(player, "quest_claimed", 1, { kind :: string, entry.id, slotField })
	local setPaid = if kind == "daily" then quests.dailySet else quests.weeklySet
	if not setPaid and Quests.allClaimed(list, #Quests.pools(kind)) then
		if kind == "daily" then
			quests.dailySet = true
			profile.stats.dailySetsDone += 1
		else
			quests.weeklySet = true
			profile.stats.weeklySetsDone += 1
		end
		append(paid, (Payout.pay(player, profile, Quests.setPrize(kind), sku)))
		Telemetry.custom(player, "quest_set", 1, { kind :: string })
	end
	return paid
end

-- A new day or week: pays the old set's finished quests, then rolls the new one, away from the old ids where it can.
local function renew(
	player: Player,
	profile: Types.PlayerProfile,
	kind: Types.QuestKind,
	period: number,
	dayRate: number
): { string }
	local paid: { string } = {}
	local avoid: { [string]: boolean } = {}
	for slot, entry in listOf(profile, kind) do
		avoid[entry.id] = true
		if not entry.claimed and Quests.done(profile, entry) then
			append(paid, payQuest(player, profile, kind, slot, true))
		end
	end
	local quests = profile.quests
	local set = Quests.rollSet(profile, kind, dayRate, avoid, roll)
	if kind == "daily" then
		quests.day, quests.daily, quests.dailyReroll, quests.dailySet = period, set, false, false
	else
		quests.week, quests.weekly, quests.weeklyReroll, quests.weeklySet =
			period, set, false, false
	end
	return paid
end

-- Brings the player's quests up to `now`: a new day or week renews that set, and a save's broken slots get fresh
-- picks. Returns true when anything changed. What a reset paid is toasted.
local function refresh(player: Player, profile: Types.PlayerProfile, now: number): boolean
	local quests = profile.quests
	local dayRate = Economy.incomePerSecond(profile)
	local changed = false
	local paid: { string } = {}
	local day, week = Quests.day(now), Quests.week(now)
	if quests.day ~= day then
		append(paid, renew(player, profile, "daily", day, dayRate))
		changed = true
	elseif Quests.repair(profile, "daily", dayRate, roll) then
		changed = true
	end
	if quests.week ~= week then
		append(paid, renew(player, profile, "weekly", week, dayRate))
		changed = true
	elseif Quests.repair(profile, "weekly", dayRate, roll) then
		changed = true
	end
	if #paid > 0 then
		Net.toast(
			player,
			"Finished quests from last time paid: " .. table.concat(paid, ", "),
			"good"
		)
	end
	return changed
end

-- The answer to a claim: the toast with what it paid, QuestResult for the window and a sync.
local function answer(player: Player, title: string, paid: { string })
	Net.toast(player, string.format("%s: %s", title, table.concat(paid, ", ")), "good")
	Net.fire(player, "QuestResult", paid)
	CafeService.sync(player)
end

local function refuse(player: Player, why: string)
	Net.toast(player, why, "warn")
	CafeService.sync(player)
end

type Slot = { kind: Types.QuestKind, slot: number }

-- The kind and slot of a ClaimQuest or RerollQuest, or nil.
local function slotOf(rawKind: unknown, rawSlot: unknown): Slot?
	local kind: Types.QuestKind = if rawKind == "daily" then "daily" else "weekly"
	if rawKind ~= kind then
		return nil
	end
	local slot = Guard.int(rawSlot, 1, #Quests.pools(kind))
	if slot == nil then
		return nil
	end
	local asked: Slot = { kind = kind, slot = slot }
	return asked
end

local function onClaimQuest(player: Player, rawKind: unknown, rawSlot: unknown)
	local asked = slotOf(rawKind, rawSlot)
	local profile = DataService.get(player)
	if asked == nil or profile == nil then
		return
	end
	local kind: Types.QuestKind, slot: number = asked.kind, asked.slot
	refresh(player, profile, os.time())
	local why = Quests.claimBlocker(profile, kind, slot)
	if why ~= nil then
		refuse(player, why)
		return
	end
	local entry = listOf(profile, kind)[slot]
	local def = Catalog.getQuest(entry.id)
	local paid = payQuest(player, profile, kind, slot, false)
	answer(player, if def ~= nil then def.text else "Quest done", paid)
end

local function onRerollQuest(player: Player, rawKind: unknown, rawSlot: unknown)
	local asked = slotOf(rawKind, rawSlot)
	local profile = DataService.get(player)
	if asked == nil or profile == nil then
		return
	end
	local kind: Types.QuestKind, slot: number = asked.kind, asked.slot
	refresh(player, profile, os.time())
	local why = Quests.rerollBlocker(profile, kind, slot)
	if why ~= nil then
		refuse(player, why)
		return
	end
	local list = listOf(profile, kind)
	local def = Quests.pick(profile, kind, slot, list, {}, roll())
	if def == nil then
		refuse(player, "No other quest to swap in")
		return
	end
	list[slot] = Quests.entry(profile, def, Economy.incomePerSecond(profile))
	if kind == "daily" then
		profile.quests.dailyReroll = true
	else
		profile.quests.weeklyReroll = true
	end
	Net.toast(player, "New quest: " .. def.text, "info")
	CafeService.sync(player)
end

local function onClaimAchievement(player: Player, rawId: unknown)
	local achievementId = Guard.id(rawId)
	local profile = DataService.get(player)
	if achievementId == nil or profile == nil then
		return
	end
	local why = Quests.achievementBlocker(profile, achievementId)
	if why ~= nil then
		refuse(player, why)
		return
	end
	local def = Catalog.getAchievement(achievementId) :: Types.AchievementDef
	profile.achievements[achievementId] = true
	local paid = Payout.pay(player, profile, Quests.achievementPrize(def), "achievement")
	Telemetry.custom(player, "achievement_claimed", 1, { def.id, def.size })
	answer(player, "Achievement " .. def.name, paid)
end

function QuestService.start()
	Net.on("ClaimQuest", onClaimQuest)
	Net.on("RerollQuest", onRerollQuest)
	Net.on("ClaimAchievement", onClaimAchievement)
	DataService.onLoaded:Connect(function(player: Player, profile: Types.PlayerProfile)
		if refresh(player, profile, os.time()) then
			CafeService.sync(player)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Config.QuestRollCheckSeconds)
			local now = os.time()
			for _, player in DataService.loadedPlayers() do
				local profile = DataService.get(player)
				if profile ~= nil and refresh(player, profile, now) then
					CafeService.sync(player)
				end
			end
		end
	end)
end

-- Studio-only test hook: rolls the player's quests as if a new day and week began now, paying the old sets' finished
-- quests first. Returns the new daily and weekly ids.
function QuestService.debugRenew(player: Player): ({ string }, { string })
	assert(game:GetService("RunService"):IsStudio(), "debugRenew is Studio only")
	local profile = DataService.get(player)
	if profile == nil then
		return {}, {}
	end
	profile.quests.day, profile.quests.week = -1, -1
	refresh(player, profile, os.time())
	CafeService.sync(player)
	local daily, weekly = {}, {}
	for _, entry in profile.quests.daily do
		table.insert(daily, entry.id)
	end
	for _, entry in profile.quests.weekly do
		table.insert(weekly, entry.id)
	end
	return daily, weekly
end

return QuestService
