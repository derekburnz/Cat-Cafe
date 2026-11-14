--!strict
-- The Cafe Event reward on the server (#2486; live-events.md section 2e; CafeEvents.reward for the rule). A player
-- who secures a cat while an event with a reward runs (CatService's check-in calls `secured`) gets, once per event:
-- (#4282: the "Cafe Party Guest" badge it once gave is gone, Derek 2026-11-14)
-- - the event's free piece into decorOwned, placed like a crate find (a free decor spot, else Auto Equip), or, for a
--   player who has it already, EventRepeatGiftIncomeMinutes of their cafe income (Payout, sku "event_reward").
-- An event that ends early (its record pulled, or a test stopped) pays everyone in the server at that moment, as
-- section 3 promises. A test event (one server only) pays only in Studio and to an owner (OwnerTest), so a private
-- server's test never hands its guests a reward outside a real event. Analytics: event_reward (event id, "first"
-- for the account's first event reward, else "again"), never for a test event.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CafeEvents = require(ReplicatedStorage.Shared.CafeEvents)
local CafeService = require(script.Parent.CafeService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local Crates = require(ReplicatedStorage.Shared.Crates)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local EventService = require(script.Parent.EventService)
local Net = require(script.Parent.Net)
local OwnerTest = require(ReplicatedStorage.Shared.OwnerTest)
local Payout = require(script.Parent.Payout)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)

local EventRewardService = {}

local EARLY_SECONDS = 2 -- an event that stops this long before its endsAt has ended early

-- A test event pays only in Studio or to an owner.
local function pays(player: Player, event: CafeEvents.Event): boolean
	return not event.test or RunService:IsStudio() or OwnerTest.isOwnerPlayer(player)
end

-- The new piece onto a free decor spot, else Auto Equip's swap (as a crate find, FishMarketService).
local function place(player: Player, profile: Types.PlayerProfile, decorId: string)
	local def = Catalog.getDecor(decorId)
	if def == nil then
		return
	end
	local cap = Crates.spotCap(Economy.tier(profile), profile.fishPerks.extra_decor_spot or 0)
	if
		Crates.takesSpot(def)
		and Crates.spotsUsed(profile, Economy.replacedDecor(profile)) < cap
	then
		profile.decorPlaced[decorId] = true
	else
		CafeService.autoEquipNewDecor(player, profile, decorId)
	end
	CafeService.refreshPlot(player)
end

local function pay(player: Player, event: CafeEvents.Event)
	if not pays(player, event) then
		return
	end
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	local kind, firstBadge = CafeEvents.reward(profile, event, os.time())
	if kind == nil then
		return
	end
	local cosmeticId = event.effects.reward :: string
	local def = Catalog.getDecor(cosmeticId)
	local pieceName = if def ~= nil then def.name else cosmeticId
	if kind == "first" then
		place(player, profile, cosmeticId)
		Net.toast(player, `{event.title} reward: the {pieceName}! It's in your Decor`, "good")
	elseif kind == "repeat" then
		local paid = Payout.pay(
			player,
			profile,
			{ coinSeconds = Config.EventRepeatGiftIncomeMinutes * 60 },
			"event_reward"
		)
		local coins = if #paid > 0 then " " .. table.concat(paid, ", ") else ""
		Net.toast(player, `{event.title} reward:{coins} (you have the {pieceName} already)`, "good")
	else
		warn(
			`[EventRewardService] {event.id}'s reward {cosmeticId} is no event decor: nothing to give`
		)
	end
	print(`[EventRewardService] {player.UserId} rewarded in {event.id}: {kind}`)
	if not event.test then
		Telemetry.custom(
			player,
			"event_reward",
			1,
			{ event.id, if firstBadge then "first" else "again" }
		)
	end
	CafeService.sync(player)
end

-- CatService's check-in: `player` secured a cat. Pays the running event's reward once per event.
function EventRewardService.secured(player: Player)
	local event = EventService.current()
	if event ~= nil and event.effects.reward ~= nil then
		pay(player, event)
	end
end

function EventRewardService.start()
	local last: CafeEvents.Event? = EventService.current() -- EventService.start's first pass ran already
	EventService.changed:Connect(function(event: CafeEvents.Event?)
		local was = last
		last = event
		if was == nil or was.effects.reward == nil or (event ~= nil and event.id == was.id) then
			return
		end
		if Workspace:GetServerTimeNow() < was.endsAt - EARLY_SECONDS then
			-- section 3: ended early, so everyone in the window when it ended gets the reward
			for _, player in Players:GetPlayers() do
				pay(player, was)
			end
		end
	end)
end

return EventRewardService
