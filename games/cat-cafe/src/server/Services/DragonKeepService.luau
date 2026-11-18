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
-- now: the Castle and its Keep are not placed yet. The cards' effects (#4447) are read where each one acts; Golden
-- Breath's timed pay runs here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DragonKeep = require(ReplicatedStorage.Shared.DragonKeep)
local EasyKeep = require(ReplicatedStorage.Shared.EasyKeep)
local Economy = require(ReplicatedStorage.Shared.Economy)
local GoldenFish = require(ReplicatedStorage.Shared.GoldenFish)
local LiveFlags = require(ReplicatedStorage.Shared.LiveFlags)
local NetSwing = require(ReplicatedStorage.Shared.NetSwing)
local Types = require(ReplicatedStorage.Shared.Types)

local CafeService = require(script.Parent.CafeService)
local CatService = require(script.Parent.CatService)
local ClockService = require(script.Parent.ClockService)
local DataService = require(script.Parent.DataService)
local Guard = require(script.Parent.Parent.Util.Guard)
local LiveFlagService = require(script.Parent.LiveFlagService)
local Net = require(script.Parent.Net)
local ShortNumber = require(ReplicatedStorage.Shared.ShortNumber)
local Telemetry = require(script.Parent.Telemetry)
local TradeService = require(script.Parent.TradeService)

local DragonKeepService = {}

local BREATH_TICK = 15 -- seconds between Golden Breath checks
local breathAt: { [Player]: number } = {} -- os.clock() of each player's last breath (or its first chance)

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

-- #4447: the net's extra reach (the Long Net and the reach cards) as NetExtraStuds, for the client's reach glow
-- (MysteryMarketService sets it the same way at join and on a Long Net buy), the time between swings as
-- NetCooldown, for the client's own wait (nil at the Config one), and the walk speed again for the wing cards.
local function applyReach(player: Player, profile: Types.PlayerProfile)
	local extra = NetSwing.extraForProfile(profile)
	player:SetAttribute("NetExtraStuds", if extra > 0 then extra else nil)
	local cooldown = NetSwing.cooldownFor(profile)
	player:SetAttribute("NetCooldown", if cooldown < Config.NetSwingCooldown then cooldown else nil)
	CatService.refreshSpeed(player) -- the wing cards' walk speed
	local fx = DragonKeep.of(profile) -- the air cards, for client/Controllers/AirMovesController
	player:SetAttribute("DoubleJump", if fx.doubleJump then true else nil)
	player:SetAttribute("Glide", if fx.glide then true else nil)
	-- #4558: Fire Trail is a look only; every client draws the embers off this attribute (client/Effects/FireTrail)
	local trail = LiveFlagService.on(DragonKeep.FLAG)
		and table.find(profile.dragon.slots, "fireTrail") ~= nil
	player:SetAttribute("FireTrail", if trail then true else nil)
	-- #4569: the lit sets for their looks (client Effects): "flame5,claw3", nil with none or the switch off
	player:SetAttribute(
		"DragonSets",
		if LiveFlagService.on(DragonKeep.FLAG) then DragonKeep.setsTag(profile.dragon) else nil
	)
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
	applyReach(player, profile)
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
	applyReach(player, profile)
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
	if profile ~= nil then
		applyReach(player, profile) -- #4447: the swing cards' NetCooldown (the reach is also set by the Market)
	end
	if profile ~= nil and LiveFlagService.on(DragonKeep.FLAG) and #profile.dragon.hand == 0 then
		deal(player, profile)
	end
end

-- #4447: Golden Breath: every BREATH_EVERY seconds of play with the card slotted, BREATH_SECONDS of the cafe's
-- income now (the phase's pay and a running event's money with it). The clock starts when the card is first seen.
local function breathe(now: number)
	for _, player in DataService.loadedPlayers() do
		local profile = DataService.get(player)
		if profile == nil or not DragonKeep.of(profile).breath then
			breathAt[player] = nil
			continue
		end
		local last = breathAt[player]
		if last == nil then
			breathAt[player] = now
			continue
		end
		if now - last < DragonKeep.BREATH_EVERY then
			continue
		end
		breathAt[player] = now
		Economy.settle(profile, os.time(), ClockService.epoch())
		local amount = math.floor(
			Economy.incomePerSecond(profile)
				* Economy.phaseMultiplier(ClockService.phase())
				* Economy.moneyFor(profile)
				* DragonKeep.BREATH_SECONDS
		)
		if amount <= 0 then
			continue
		end
		Economy.credit(profile, amount)
		Telemetry.source(player, profile, amount, "Gameplay", "dragon_golden_breath")
		Net.toast(
			player,
			"Cinder breathed gold over your cafe! +$" .. ShortNumber.format(amount),
			"good"
		)
		CafeService.sync(player)
	end
end

function DragonKeepService.start()
	Net.on("GiveToKeep", onGive)
	Net.on("PickDragonCard", onPick)
	Net.on("KeepCards", onKeep)
	Net.on("SlotDragonCard", onSlot)
	Net.on("SetDragonColour", onColour)
	DataService.onLoaded:Connect(onLoaded)
	-- #5311: with the easyKeep switch on mid-session, a Keep whose Warmth already reaches a lowered goal gets that
	-- stage and its hand now (a join does it in DragonKeep.sanitize). EasyKeep.follow sets the goals first.
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. EasyKeep.FLAG)
		:Connect(function()
			if not EasyKeep.on() then
				return
			end
			DragonKeep.setEasy(true) -- signal order is not promised, so the goals are set before the grow
			for _, player in DataService.loadedPlayers() do
				local profile = DataService.get(player)
				if profile ~= nil and DragonKeep.regrow(profile.dragon) then
					if LiveFlagService.on(DragonKeep.FLAG) and #profile.dragon.hand == 0 then
						deal(player, profile)
					end
					CafeService.sync(player)
				end
			end
		end)
	DataService.beforeRelease(function(player)
		breathAt[player] = nil
	end)
	-- the Fire Trail and set looks (and the air cards) follow the dragonKeep switch the moment it flips, not at each
	-- player's next card or rejoin
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. DragonKeep.FLAG)
		:Connect(function()
			for _, player in Players:GetPlayers() do
				local profile = DataService.get(player)
				if profile ~= nil then
					applyReach(player, profile)
				end
			end
		end)
	task.spawn(function()
		while true do
			task.wait(BREATH_TICK)
			breathe(os.clock())
		end
	end)
end

return DragonKeepService
