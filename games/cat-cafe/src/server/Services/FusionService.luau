--!strict
-- #4104 (shared/Fusion, fusion-observatory.md section 4): the Fusion Observatory's remotes, both refused while the
-- fusion switch is off or below Fusion.TIER, and each rate limited by Net:
--   StartFusion(uids, keepTraitUid?)   five free copies of one cat in one coat go into the dome (Fusion.startBlocker)
--   CollectFusion()                    the finished fusion's cat comes out, unlocked and resting
-- From anywhere for now: the dome on Summit Peak is not placed yet. Telemetry counts only, never who.

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

function FusionService.start()
	Net.on("StartFusion", onStart)
	Net.on("CollectFusion", onCollect)
end

return FusionService
