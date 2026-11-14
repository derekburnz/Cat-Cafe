--!strict
-- The Admin Wheel on the server (#4195; shared/AdminWheel for the rules). While an admin event with the `wheel`
-- effect runs (EventService.admin(), behind the adminEvents switch), AdminWheelSpin() spins it for the caller: once
-- per account per event, with the server's own Random and nothing read from the client. The spin is marked in the
-- save (codesRedeemed, AdminWheel.key) before anything is paid, the prize is paid at once, so leaving mid-animation
-- keeps it, and AdminWheelResult(slice, prizeId, paid) tells the window where to land. A refused spin answers
-- AdminWheelResult(0, "", {}). PlayerState.adminWheel (CafeService.buildState) says which wheel is up and whether
-- this account has spun it; every player is synced when the wheel comes up or goes.
-- A test event (`/admin wheel` in Studio or a private server) pays only in Studio and to an owner, as a test Cafe
-- Event's reward does (EventRewardService), and logs no analytics. Analytics: admin_wheel, value 1, the prize id,
-- the player's tier and the event id.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AdminWheel = require(ReplicatedStorage.Shared.AdminWheel)
local CafeEvents = require(ReplicatedStorage.Shared.CafeEvents)
local CafeService = require(script.Parent.CafeService)
local CatStats = require(ReplicatedStorage.Shared.CatStats)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local EventService = require(script.Parent.EventService)
local LiveFlagService = require(script.Parent.LiveFlagService)
local Net = require(script.Parent.Net)
local OwnerTest = require(ReplicatedStorage.Shared.OwnerTest)
local Payout = require(script.Parent.Payout)
local PotionService = require(script.Parent.PotionService)
local Telemetry = require(script.Parent.Telemetry)
local Traits = require(ReplicatedStorage.Shared.Traits)
local Types = require(ReplicatedStorage.Shared.Types)

local AdminWheelService = {}

local SKU = "admin_wheel"

local random = Random.new()
local forcedPrize: { [Player]: string } = {} -- Studio only (debugForce): the prize this player's next spin lands on

-- The wheel that is up, or nil: the switch on and a running admin event with the wheel.
local function wheelUp(): CafeEvents.AdminEvent?
	if not LiveFlagService.on("adminEvents") then
		return nil
	end
	local event = EventService.admin()
	return if event ~= nil and event.effects.wheel then event else nil
end

-- A test event pays only in Studio or to an owner.
local function pays(player: Player, event: CafeEvents.AdminEvent): boolean
	return not event.test or RunService:IsStudio() or OwnerTest.isOwnerPlayer(player)
end

-- Pays the slice and returns what it paid, as short lines for the result card.
local function pay(
	player: Player,
	profile: Types.PlayerProfile,
	prize: AdminWheel.Prize
): { string }
	local paid: { string } = {}
	local tokens = prize.tokens
	if tokens ~= nil and tokens > 0 then
		local added = Traits.give(profile.traits, tokens)
		table.insert(
			paid,
			if added < tokens
				then string.format("%d of %d Trait Rerolls (bank full)", added, tokens)
				else string.format("%d Trait Rerolls", tokens)
		)
	end
	if prize.prize ~= nil then
		for _, line in Payout.pay(player, profile, prize.prize, SKU) do
			table.insert(paid, line)
		end
	end
	if prize.boost ~= nil then
		local running = PotionService.give(player, profile, prize.boost)
		table.insert(paid, if running then prize.name else prize.name .. " (in your Bag)")
	end
	if prize.cat ~= nil then
		local def = AdminWheel.catFor(
			prize,
			Economy.tier(profile),
			LiveFlagService.on("secretCats"),
			random:NextNumber()
		)
		if def ~= nil then
			CafeService.addGiftCat(player, profile, def, CatStats.DEFAULT_CHARM)
			table.insert(paid, string.format("%s (%s cat)", def.name, def.rarity))
		end
	end
	return paid
end

local function onSpin(player: Player)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	local event = wheelUp()
	if event == nil or not pays(player, event) or AdminWheel.spun(profile.codesRedeemed, event) then
		Net.fire(player, "AdminWheelResult", 0, "", {})
		return
	end
	-- marked before anything is paid, so no error or second call can pay twice
	profile.codesRedeemed[AdminWheel.key(event)] = os.time()
	local forced = forcedPrize[player]
	forcedPrize[player] = nil
	local prize, slice = AdminWheel.pick(random:NextNumber())
	if forced ~= nil then
		local forcedRow, forcedSlice = AdminWheel.get(forced)
		if forcedRow ~= nil and forcedSlice ~= nil then
			prize, slice = forcedRow, forcedSlice
		end
	end
	local paid = pay(player, profile, prize)
	print(`[AdminWheelService] {player.UserId} spun {event.id}: {prize.id}`)
	if not event.test then
		Telemetry.custom(
			player,
			"admin_wheel",
			1,
			{ prize.id, tostring(Economy.tier(profile)), event.id }
		)
	end
	Net.fire(player, "AdminWheelResult", slice, prize.id, paid)
	CafeService.sync(player)
end

function AdminWheelService.start()
	Net.on("AdminWheelSpin", onSpin)
	Players.PlayerRemoving:Connect(function(player)
		forcedPrize[player] = nil
	end)
	-- the wheel came up or went: every player's adminWheel changes
	local last: CafeEvents.AdminEvent? = wheelUp()
	EventService.adminChanged:Connect(function()
		local now = wheelUp()
		if (now ~= nil) ~= (last ~= nil) or (now ~= nil and last ~= nil and now.id ~= last.id) then
			for _, player in Players:GetPlayers() do
				CafeService.sync(player)
			end
		end
		last = now
	end)
end

-- Studio-only test hook: this player's next spin lands on the prize `prizeId` (AdminWheel.PRIZES) and pays it, with
-- every other check as normal; nil goes back to the random pick. Returns the prize set.
function AdminWheelService.debugForce(player: Player, prizeId: string?): string?
	if prizeId == nil then
		forcedPrize[player] = nil
		return nil
	end
	assert(RunService:IsStudio(), "Studio only")
	assert(AdminWheel.get(prizeId) ~= nil, "no such prize")
	forcedPrize[player] = prizeId
	return prizeId
end

return AdminWheelService
