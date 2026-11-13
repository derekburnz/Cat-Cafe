--!strict
-- The Mystic Pool on the server (#3196, trait-station.md; the rules are shared/Traits). Every remote is refused while
-- the `traits` switch is off or the player's tier has not opened the Park's camp extra (the station replaces the
-- Picnic Basket there). It opens from the walk-in circle and the Cannon menu alike, so there is no range check, as
-- for every other station (camp-extras.md section 3).
--   RollTrait(uid): the cat owned, no re-roll waiting, and a roll paid for (Traits.pay: a free starter roll, else a
--     Trait Token, else Traits.COST_FISH golden fish, checked and spent in one step before the roll). A cat with no trait takes
--     the roll at once; a cat with one keeps it and the roll waits in the save (`pending`) for ChooseTrait.
--   ChooseTrait(takeNew): the waiting re-roll goes on its cat (true) or is dropped (false), so a cat never gets worse.
--   CollectTraitTokens(): the station's free tokens (one each 12 h, holding 2) go to the bank.
-- Each answers with one sync (PlayerState.traits and the cats' traits). Logs trait_roll and trait_token. Nothing here
-- is sold: tokens come only from play, and golden fish are earned only.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CafeService = require(script.Parent.CafeService)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local GlobalCatchService = require(script.Parent.GlobalCatchService)
local GoldenFish = require(ReplicatedStorage.Shared.GoldenFish)
local Guard = require(script.Parent.Parent.Util.Guard)
local LiveFlagService = require(script.Parent.LiveFlagService)
local Net = require(script.Parent.Net)
local Telemetry = require(script.Parent.Telemetry)
local Trade = require(ReplicatedStorage.Shared.Trade)
local TradeService = require(script.Parent.TradeService)
local Traits = require(ReplicatedStorage.Shared.Traits)
local Types = require(ReplicatedStorage.Shared.Types)

type Profile = Types.PlayerProfile

local TraitService = {}

local rng = Random.new()

-- Whether `profile`'s player can use the station now (CafeService.traitsView reads the same).
function TraitService.open(profile: Profile): boolean
	return LiveFlagService.on(Traits.FLAG) and Traits.openAt(Economy.tier(profile))
end

-- Adds `count` Trait Tokens from `source` (a spin, the Daily Treat, a quest set, Lost and Found, a code) and logs
-- trait_token; the caller syncs. Returns how many were added (0 while the switch is off).
function TraitService.give(player: Player, profile: Profile, count: number, source: string): number
	if not LiveFlagService.on(Traits.FLAG) then
		return 0
	end
	local added = Traits.give(profile.traits, count)
	if added > 0 then
		Telemetry.custom(player, "trait_token", added, { source })
	end
	return added
end

local function refuse(player: Player, text: string)
	Net.toast(player, text, "warn")
	CafeService.sync(player)
end

-- Spec section 1a: a Mythic (or better) sends one server-wide line, display name only, through the rare-catch
-- channel (the Announce toast every client shows, in the Mythical colour). #3942: the roller's whole scene at the
-- pool plays meanwhile, so the line goes to everyone else and never spoils the roller's own reveal.
local CHAT_DELAY_SECONDS = 25 -- past the end of the Secret Rift Run (Effects/RiftRun), so the scene reveals it first

local function announce(player: Player, rolled: Traits.Trait)
	local line = Traits.announceText(player.DisplayName, rolled)
	if line == nil then
		return
	end
	local chat = Traits.chatRarity(rolled) or "Mythical"
	for _, other in Players:GetPlayers() do
		if other ~= player then
			Net.fire(other, "Announce", line, chat)
		end
	end
	-- #3908: the chat line here and on the other servers, like a Mythical catch (#2203). It waits CHAT_DELAY_SECONDS so
	-- the roller's own chat does not show it before their scene's reveal.
	task.delay(CHAT_DELAY_SECONDS, function()
		GlobalCatchService.share(line, chat)
	end)
	-- #3942: everyone near the pool sees its pillar go up (Effects/BigTraitCut.watchPool). Attributes on the station,
	-- no new remote: who rolled (so their own client skips it, it plays the scene) and the rarity, then the time last,
	-- which is what the clients watch.
	local station = CollectionService:GetTagged(Traits.TAG)[1]
	local rarity = Traits.rarity(rolled)
	if station ~= nil and rarity ~= nil and station:IsDescendantOf(Workspace) then
		station:SetAttribute(Traits.ROLL_BY_ATTRIBUTE, player.UserId)
		station:SetAttribute(Traits.ROLL_RARITY_ATTRIBUTE, rarity.id)
		station:SetAttribute(Traits.ROLL_AT_ATTRIBUTE, Workspace:GetServerTimeNow())
	end
end

local function onRoll(player: Player, rawUid: unknown)
	local uid = Guard.id(rawUid)
	local profile = DataService.get(player)
	if uid == nil or profile == nil then
		return
	end
	if not TraitService.open(profile) then
		refuse(player, "The Mystic Pool is closed for now")
		return
	end
	local cat = profile.cats[uid]
	if cat == nil then
		refuse(player, "That cat isn't yours anymore")
		return
	end
	if CafeService.isOffered(player, uid) then
		-- review: a cat on offer in an open trade keeps the trait the partner sees
		refuse(player, Trade.Messages.catInTrade)
		return
	end
	local save = profile.traits
	if save.pending ~= nil then
		refuse(player, "Pick Keep old or Take new first")
		return
	end
	-- checked and spent in one step, before the roll (no yield between)
	local how, fish = Traits.pay(save, profile.goldenFish)
	if how == nil then
		refuse(player, string.format("You need a Trait Token or %d golden fish", Traits.COST_FISH))
		return
	end
	if fish > 0 then
		local frozen = TradeService.fishSpendBlocker(player) -- #2745: fish offered in an open trade stay put
		if frozen ~= nil or not GoldenFish.trySpend(profile, fish) then
			Traits.refund(save, how :: Traits.Payment)
			refuse(player, frozen or "Not enough golden fish")
			return
		end
		Telemetry.fishSink(player, profile, fish, "Shop", "trait_roll")
	end
	local rolled = Traits.roll(function(n: number): number
		return rng:NextInteger(1, n)
	end, LiveFlagService.on(Traits.SECRET_FLAG))
	profile.stats.traitRolls += 1 -- #3694 section 3: every roll, a first or a re-roll
	local reroll = cat.trait ~= nil
	if reroll then
		save.pending = { uid = uid, id = rolled.id, paid = how :: string }
	else
		cat.trait = rolled
		Telemetry.custom(player, "trait_roll", Traits.rank(rolled), { rolled.id, how, "first" })
	end
	announce(player, rolled)
	CafeService.sync(player)
end

local function onChoose(player: Player, rawTakeNew: unknown)
	local takeNew = Guard.bool(rawTakeNew)
	local profile = DataService.get(player)
	if takeNew == nil or profile == nil then
		return
	end
	local save = profile.traits
	local pending = save.pending
	if pending == nil then
		CafeService.sync(player)
		return
	end
	local cat = profile.cats[pending.uid]
	if cat ~= nil and takeNew and CafeService.isOffered(player, pending.uid) then
		-- review: on offer in an open trade; the choice waits until the trade is over
		refuse(player, Trade.Messages.catInTrade)
		return
	end
	save.pending = nil
	local kept = "old"
	if cat ~= nil and takeNew then
		cat.trait = { id = pending.id }
		kept = "new"
	end
	Telemetry.custom(
		player,
		"trait_roll",
		Traits.rank({ id = pending.id }),
		{ pending.id, pending.paid or "unknown", "reroll_" .. kept }
	)
	CafeService.sync(player)
end

local function onCollect(player: Player)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	if not TraitService.open(profile) then
		refuse(player, "The Mystic Pool is closed for now")
		return
	end
	local save = profile.traits
	Traits.settle(save, true, os.time())
	local held = save.held
	if held <= 0 then
		CafeService.sync(player)
		return
	end
	local added = Traits.give(save, held)
	-- only what fit leaves the station (the bank's cap is far above any real count)
	save.held = held - added
	if added > 0 then
		Telemetry.custom(player, "trait_token", added, { "station" })
		Net.toast(
			player,
			if added == 1 then "Got 1 Trait Token" else string.format("Got %d Trait Tokens", added),
			"good"
		)
	end
	CafeService.sync(player)
end

function TraitService.start()
	Net.on("RollTrait", onRoll)
	Net.on("ChooseTrait", onChoose)
	Net.on("CollectTraitTokens", onCollect)
end

return TraitService
