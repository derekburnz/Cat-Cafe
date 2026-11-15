--!strict
-- #4062 (shared/DragonKeep): the Dragon Keep's remotes, all refused while the dragonKeep switch is off or below
-- DragonKeep.TIER, and each rate limited by Net:
--   GiveToKeep(uids, confirmed)   cats move in (DragonKeep.giveBlocker); working ones leave their role and Equip Best
--                                 refills it; stage ups queue hands, and the first is dealt and saved at once
--   PickDragonCard(index, slot?)  takes a card of the hand showing; the next waiting hand is dealt
--   KeepCards()                   a Rekindle hand's "Keep my cards": DragonKeep.KEEP_FISH golden fish
--   SlotDragonCard(cardId, slot)  a binder card into an open slot, free, any time
--   SetDragonColour(colour)       Cinder's scales from stage 3, free
-- Fires DragonStage(stage) to the owner for each stage up (the cutscene, client/Effects/DragonRise). From anywhere for
-- now: the Castle and its Keep are not placed yet. The cards' effects come in a follow-up.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DragonKeep = require(ReplicatedStorage.Shared.DragonKeep)
local Economy = require(ReplicatedStorage.Shared.Economy)
local GoldenFish = require(ReplicatedStorage.Shared.GoldenFish)
local Types = require(ReplicatedStorage.Shared.Types)

local CafeService = require(script.Parent.CafeService)
local ClockService = require(script.Parent.ClockService)
local DataService = require(script.Parent.DataService)
local Guard = require(script.Parent.Parent.Util.Guard)
local LiveFlagService = require(script.Parent.LiveFlagService)
local Net = require(script.Parent.Net)
local Telemetry = require(script.Parent.Telemetry)
local TradeService = require(script.Parent.TradeService)

local DragonKeepService = {}

local random = Random.new()
local function roll(): number
	return random:NextNumber()
end

local function ready(player: Player): Types.PlayerProfile?
	local profile = DataService.get(player)
	if
		profile == nil
		or not LiveFlagService.on(DragonKeep.FLAG)
		or not DragonKeep.open(Economy.tier(profile))
	then
		return nil
	end
	return profile
end

local function refuse(player: Player, reason: string)
	Net.toast(player, reason, "warn")
	CafeService.sync(player)
end

-- Deals the next waiting hand (saved in the profile before the sync shows it), paying the fish for a Rekindle with
-- every card owned.
local function deal(player: Player, profile: Types.PlayerProfile)
	local fish = DragonKeep.dealNext(profile.dragon, roll)
	if fish > 0 then
		GoldenFish.credit(profile, fish)
		Telemetry.fishSource(player, profile, fish, "Gameplay", "dragon_full_binder")
		Net.toast(player, string.format("Every card is yours! +%d golden fish", fish), "good")
	end
end

local function onGive(player: Player, rawUids: unknown, rawConfirmed: unknown)
	local profile = ready(player)
	if profile == nil or type(rawUids) ~= "table" then
		return
	end
	local uids: { string } = {}
	local seen: { [string]: boolean } = {}
	for index, raw in rawUids :: { any } do
		if type(index) ~= "number" or #uids >= DragonKeep.GIVE_MAX then
			return -- not a plain list, or too long: refused whole
		end
		local uid = Guard.id(raw)
		if uid == nil then
			return
		end
		if not seen[uid] then
			seen[uid] = true
			table.insert(uids, uid)
		end
	end
	if #uids == 0 then
		return
	end
	local offered = false
	for _, uid in uids do
		offered = offered or CafeService.isOffered(player, uid)
	end
	local blocker = DragonKeep.giveBlocker(
		profile,
		Economy.tier(profile),
		uids,
		TradeService.isTrading(player) or offered,
		Guard.bool(rawConfirmed) == true
	)
	if blocker ~= nil then
		refuse(player, blocker)
		return
	end
	local working = false
	for _, uid in uids do
		working = working or profile.cats[uid].spotId ~= nil
	end
	-- earnings so far at the old rate, before the working cats leave
	Economy.settle(profile, os.time(), ClockService.epoch())
	local before = profile.dragon.stage
	local warmth, raised = DragonKeep.give(profile, uids)
	Telemetry.custom(
		player,
		"dragon_give",
		#uids,
		{ tostring(warmth), tostring(profile.dragon.stage) }
	)
	deal(player, profile)
	for stage = before + 1, before + raised do
		Net.fire(player, "DragonStage", stage)
		Telemetry.custom(player, "dragon_stage", stage, { "T" .. tostring(Economy.tier(profile)) })
	end
	Net.toast(
		player,
		string.format(
			"%d cat%s moved into the Keep, +%d Warmth",
			#uids,
			if #uids == 1 then "" else "s",
			warmth
		),
		"good"
	)
	if working then
		CafeService.requestAutoEquip(player)
	end
	CafeService.refreshPlot(player)
	CafeService.sync(player)
end

local function onPick(player: Player, rawIndex: unknown, rawSlot: unknown)
	local profile = ready(player)
	local index = Guard.int(rawIndex, 1, DragonKeep.HAND_SIZE)
	local slot = if rawSlot == nil then nil else Guard.int(rawSlot, 1, DragonKeep.MAX_STAGE)
	if profile == nil or index == nil or (rawSlot ~= nil and slot == nil) then
		return
	end
	local save = profile.dragon
	local blocker = DragonKeep.pickBlocker(save, index, slot)
	if blocker ~= nil then
		refuse(player, blocker)
		return
	end
	Economy.settle(profile, os.time(), ClockService.epoch()) -- a card can change the rate (follow-up effects)
	local kind = save.queue[1]
	local id = DragonKeep.pick(save, index, slot)
	Telemetry.custom(player, "dragon_card", save.stage, { id, kind })
	deal(player, profile)
	CafeService.sync(player)
end

local function onKeep(player: Player)
	local profile = ready(player)
	if profile == nil then
		return
	end
	if not DragonKeep.keepCards(profile.dragon) then
		refuse(player, "Pick one of these cards")
		return
	end
	GoldenFish.credit(profile, DragonKeep.KEEP_FISH)
	Telemetry.fishSource(player, profile, DragonKeep.KEEP_FISH, "Gameplay", "dragon_keep_cards")
	Net.toast(
		player,
		string.format("Kept your cards, +%d golden fish", DragonKeep.KEEP_FISH),
		"good"
	)
	deal(player, profile)
	CafeService.sync(player)
end

local function onSlot(player: Player, rawId: unknown, rawSlot: unknown)
	local profile = ready(player)
	local id = Guard.id(rawId)
	local slot = Guard.int(rawSlot, 1, DragonKeep.MAX_STAGE)
	if profile == nil or id == nil or slot == nil then
		return
	end
	local blocker = DragonKeep.slotBlocker(profile.dragon, id, slot)
	if blocker ~= nil then
		refuse(player, blocker)
		return
	end
	Economy.settle(profile, os.time(), ClockService.epoch())
	DragonKeep.slot(profile.dragon, id, slot)
	CafeService.sync(player)
end

local function onColour(player: Player, rawColour: unknown)
	local profile = ready(player)
	local colour = Guard.oneOf(rawColour, DragonKeep.COLOURS)
	if profile == nil or colour == nil or profile.dragon.stage < DragonKeep.COLOUR_STAGE then
		return
	end
	profile.dragon.colour = colour
	CafeService.sync(player)
end

-- A hand that waits from an earlier session but was never dealt (a stopped server) is dealt at join.
local function onLoaded(player: Player)
	local profile = DataService.get(player)
	if profile ~= nil and LiveFlagService.on(DragonKeep.FLAG) and #profile.dragon.hand == 0 then
		deal(player, profile)
	end
end

function DragonKeepService.start()
	Net.on("GiveToKeep", onGive)
	Net.on("PickDragonCard", onPick)
	Net.on("KeepCards", onKeep)
	Net.on("SlotDragonCard", onSlot)
	Net.on("SetDragonColour", onColour)
	DataService.onLoaded:Connect(onLoaded)
end

return DragonKeepService
