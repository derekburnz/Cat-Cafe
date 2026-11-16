--!strict
-- #4104 (shared/Fusion, fusion-observatory.md section 4): the Fusion Observatory's remotes, both refused while the
-- fusion switch is off or below Fusion.TIER, and each rate limited by Net:
--   StartFusion(uids, keepTraitUid?)   five free copies of one cat in one coat go into the dome (Fusion.startBlocker)
--   CollectFusion()                    the finished fusion's cat comes out, unlocked and resting
--   FuseAll()                          #4589: every set of five free copies (Fusion.allSets) fused and collected at once
-- From anywhere for now: the dome on Summit Peak is not placed yet. Telemetry counts only, never who.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Fusion = require(ReplicatedStorage.Shared.Fusion)
local Types = require(ReplicatedStorage.Shared.Types)

local CafeService = require(script.Parent.CafeService)
local ClockService = require(script.Parent.ClockService)
local DataService = require(script.Parent.DataService)
local Guard = require(script.Parent.Parent.Util.Guard)
local LiveFlagService = require(script.Parent.LiveFlagService)
local Net = require(script.Parent.Net)
local Telemetry = require(script.Parent.Telemetry)
local TradeService = require(script.Parent.TradeService)

local FusionService = {}

local function ready(player: Player): Types.PlayerProfile?
	local profile = DataService.get(player)
	if
		profile == nil
		or not LiveFlagService.on(Fusion.FLAG)
		or not Fusion.open(Economy.tier(profile))
	then
		return nil
	end
	return profile
end

local function refuse(player: Player, reason: string)
	Net.toast(player, reason, "warn")
	CafeService.sync(player)
end

local function rarityOf(catId: string): string
	local def = Catalog.getCat(catId)
	return if def ~= nil then def.rarity else "?"
end

-- #4605: the spot a started fusion's result takes on Collect, per player, this server only (not saved: a fusion
-- collected after a rejoin rests, as before).
local spotFor: { [Player]: string? } = {}

-- #4605: the collected cat takes over `spot` (the strongest working copy's, Fusion.workSpot) when no cat holds it now.
local function handOver(profile: Types.PlayerProfile, instance: Types.CatInstance, spot: string?)
	if spot == nil then
		return
	end
	for _, other in profile.cats do
		if other.spotId == spot then
			return
		end
	end
	instance.spotId = spot
end

local function onStart(player: Player, rawUids: unknown, rawKeep: unknown)
	local profile = ready(player)
	if profile == nil or type(rawUids) ~= "table" then
		return
	end
	local uids: { string } = {}
	for index, raw in rawUids :: { any } do
		if type(index) ~= "number" or #uids >= Fusion.COPIES then
			refuse(player, Fusion.Messages.count) -- not a plain list, or too long: refused whole
			return
		end
		local uid = Guard.id(raw)
		if uid == nil then
			return
		end
		table.insert(uids, uid)
	end
	local keep: string? = nil
	if rawKeep ~= nil then
		keep = Guard.id(rawKeep)
		if keep == nil then
			return
		end
	end
	local offered = false
	for _, uid in uids do
		offered = offered or CafeService.isOffered(player, uid)
	end
	local blocker = Fusion.startBlocker(
		profile,
		Economy.tier(profile),
		uids,
		keep,
		TradeService.isTrading(player) or offered
	)
	if blocker ~= nil then
		refuse(player, blocker)
		return
	end
	-- settle first, so the cats leaving never change a rate mid-span
	Economy.settle(profile, os.time(), ClockService.epoch())
	local catId = profile.cats[uids[1]].catId
	-- #4605: a working copy leaves its spot with the others; the result takes the strongest one's spot on collect
	spotFor[player] = Fusion.workSpot(profile, uids)
	local coat = Fusion.start(profile, uids, keep, os.time(), Fusion.hasElderLore(profile))
	Telemetry.custom(player, "fusion_start", 1, { coat, rarityOf(catId) })
	local def = Catalog.getCat(catId)
	Net.toast(
		player,
		string.format(
			"The dome is fusing a %s %s",
			if coat == "rainbow" then "Rainbow" else "Gold",
			if def ~= nil then def.name else "cat"
		),
		"good"
	)
	CafeService.refreshPlot(player)
	CafeService.sync(player)
end

local function onCollect(player: Player)
	local profile = ready(player)
	if profile == nil then
		return
	end
	local now = os.time()
	local blocker = Fusion.collectBlocker(profile.fusion, now)
	if blocker ~= nil then
		refuse(player, blocker)
		return
	end
	Economy.settle(profile, now, ClockService.epoch())
	local instance, first = Fusion.collect(profile, CafeService.newUid(), now)
	handOver(profile, instance, spotFor[player])
	spotFor[player] = nil
	Telemetry.custom(
		player,
		"fusion_collect",
		1,
		{ instance.variant, rarityOf(instance.catId), if first then "first" else "repeat" }
	)
	local def = Catalog.getCat(instance.catId)
	Net.toast(
		player,
		string.format(
			"%s %s joined your cafe!",
			if instance.variant == "rainbow" then "Rainbow" else "Gold",
			if def ~= nil then def.name else "cat"
		),
		"good"
	)
	CafeService.refreshPlot(player)
	CafeService.sync(player)
end

export type Made = { catId: string, coat: string, level: number, name: string?, newCoat: boolean }

-- #4589 (Derek 2026-11-15: "add a fuse all possible for the observatory"): fusion is instant (0 seconds), so every set
-- is started and collected in this one call. The server picks the sets (the five weakest free copies of each cat and
-- coat, in fives, Fusion.allSets), so the client sends nothing to check. A finished fusion in the dome comes out first;
-- one still running (an old save's timer) refuses the tap. A set that is blocked is skipped, not the whole tap, and a
-- fusion that would take time stays in the dome and ends the run.
local function onFuseAll(player: Player)
	local profile = ready(player)
	if profile == nil then
		return
	end
	if TradeService.isTrading(player) then
		refuse(player, Fusion.Messages.inTrade)
		return
	end
	local now = os.time()
	local tier = Economy.tier(profile)
	-- settle first, so the cats leaving never change a rate mid-span
	Economy.settle(profile, now, ClockService.epoch())
	local made: { Made } = {}
	local function collectOne(spot: string?): boolean
		if Fusion.collectBlocker(profile.fusion, now) ~= nil then
			return false
		end
		local instance, first = Fusion.collect(profile, CafeService.newUid(), now)
		handOver(profile, instance, spot) -- #4605
		local coat = instance.variant or "gold"
		table.insert(made, {
			catId = instance.catId,
			coat = coat,
			level = instance.level or 1,
			name = instance.name,
			newCoat = first,
		})
		Telemetry.custom(
			player,
			"fusion_collect",
			1,
			{ coat, rarityOf(instance.catId), if first then "first" else "repeat" }
		)
		return true
	end
	if profile.fusion.running ~= nil then
		if not collectOne(spotFor[player]) then
			refuse(player, Fusion.Messages.busy)
			return
		end
		spotFor[player] = nil
	end
	local sets = Fusion.allSets(profile, function(uid: string): boolean
		return not CafeService.isOffered(player, uid)
	end)
	for _, set in sets do
		if Fusion.startBlocker(profile, tier, set, nil, false) ~= nil then
			continue
		end
		local catId = profile.cats[set[1]].catId
		local spot = Fusion.workSpot(profile, set) -- #4605
		local coat = Fusion.start(profile, set, nil, now, Fusion.hasElderLore(profile))
		Telemetry.custom(player, "fusion_start", 1, { coat, rarityOf(catId) })
		if not collectOne(spot) then
			spotFor[player] = spot
			break -- it takes time: it stays in the dome
		end
	end
	if #made == 0 then
		refuse(player, Fusion.Messages.noneReady)
		return
	end
	Net.fire(player, "FusionSummary", made)
	Net.toast(
		player,
		if #made == 1 then "Fused 1 new cat!" else string.format("Fused %d new cats!", #made),
		"good"
	)
	CafeService.refreshPlot(player)
	CafeService.sync(player)
end

function FusionService.start()
	Net.on("StartFusion", onStart)
	Net.on("CollectFusion", onCollect)
	Net.on("FuseAll", onFuseAll)
	Players.PlayerRemoving:Connect(function(player: Player)
		spotFor[player] = nil
	end)
end

return FusionService
