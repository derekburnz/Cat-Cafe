--!strict
-- #2797 (retention-ideas.md 5d, shared/Invites): the invite reward. A brand-new player who joins through an invite
-- (Roblox's ReferredByPlayerId) is linked to the inviter on load. Every few seconds the server pays the joiner
-- InviteRewardFish on their first catch, and sends the inviter's reward once the joiner has played
-- InviteQualifySeconds or caught a cat: paid at once when the inviter is on this server, else added to the inviter's
-- pending key (CatCafe_InvitePending, i_<userId>), which the inviter's server takes at their load and every
-- InvitePendingCheckSeconds. Each joiner pays an inviter once, at most InviteDailyMax a UTC day; sending an invite pays
-- nothing. The client's invite card reports InviteCard("shown" | "invite" | "notnow") for analytics, and "shown"
-- keeps it from coming back.
-- Studio without API access keeps the pending keys in memory. DataStore failures warn with the operation's name only
-- (keys hold user ids, and CI logs are public).
--
-- Roblox terms: Player:GetJoinData() describes how a player arrived; ReferredByPlayerId is the user id of the player
-- whose invite (or shared link) brought them, 0 or missing otherwise. A DataStore keeps values by key across servers;
-- UpdateAsync reads and writes one key atomically.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CafeService = require(script.Parent.CafeService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Invites = require(ReplicatedStorage.Shared.Invites)
local Net = require(script.Parent.Net)
local Payout = require(script.Parent.Payout)
local PlayTime = require(script.Parent.Parent.Util.PlayTime)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)

local InviteService = {}

InviteService.PENDING = "CatCafe_InvitePending"
local CHECK_SECONDS = 5
local PENDING_MAX = 50 -- joiner ids waiting in one inviter's key; more than a day's cap many times over
local SUFFIX = if RunService:IsStudio() then "_dev" else ""

local memory: { [string]: { number } } = {}
local lastPull: { [Player]: number } = {} -- os.clock() of the last pending pickup

local function live(): boolean
	return not RunService:IsStudio() or DataService.saves()
end

local function pendingKey(userId: number): string
	return "i_" .. tostring(userId)
end

local function warnFailed(what: string, err: unknown)
	local text = string.sub(string.gsub(tostring(err), "%d%d%d%d%d+", "#"), 1, 120)
	warn(string.format("[InviteService] %s failed: %s", what, text))
end

local function idList(raw: unknown): { number }
	local out: { number } = {}
	if type(raw) == "table" then
		for _, id in raw :: any do
			if
				type(id) == "number"
				and id > 0
				and id == math.floor(id)
				and table.find(out, id) == nil
			then
				table.insert(out, id)
			end
		end
	end
	while #out > PENDING_MAX do
		table.remove(out, 1)
	end
	return out
end

-- Adds `joinerId` to `inviterId`'s pending key. True once it is stored.
local function addPending(inviterId: number, joinerId: number): boolean
	local key = pendingKey(inviterId)
	if not live() then
		local list = idList(memory[key])
		if table.find(list, joinerId) == nil then
			table.insert(list, joinerId)
		end
		memory[key] = idList(list)
		return true
	end
	local ok, err = pcall(function()
		DataStoreService:GetDataStore(InviteService.PENDING .. SUFFIX)
			:UpdateAsync(key, function(old: any): any
				local list = idList(old)
				if table.find(list, joinerId) == nil then
					table.insert(list, joinerId)
				end
				return idList(list)
			end)
	end)
	if not ok then
		warnFailed("addPending", err)
	end
	return ok
end

-- Takes every joiner id waiting in `userId`'s pending key, leaving it empty.
local function takePending(userId: number): { number }
	local key = pendingKey(userId)
	if not live() then
		local list = idList(memory[key])
		memory[key] = nil
		return list
	end
	local taken: { number } = {}
	local ok, err = pcall(function()
		DataStoreService:GetDataStore(InviteService.PENDING .. SUFFIX)
			:UpdateAsync(key, function(old: any): any
				taken = idList(old)
				if #taken == 0 then
					return nil -- nothing to change: no write
				end
				return {}
			end)
	end)
	if not ok then
		warnFailed("takePending", err)
		return {}
	end
	return taken
end

-- Pays `inviter` for `joinerId` if their save allows it (once per joiner, InviteDailyMax a day).
local function payInviter(inviter: Player, profile: Types.PlayerProfile, joinerId: number)
	local now = os.time()
	local why = Invites.creditBlocker(profile.invites, joinerId, now)
	if why ~= nil then
		Telemetry.custom(
			inviter,
			"invite_join",
			1,
			{ if why == "daily" then "inviter_capped" else "inviter_repeat" }
		)
		return
	end
	Invites.credit(profile.invites, joinerId, now)
	Payout.pay(inviter, profile, { fish = Config.InviteRewardFish }, "invite_reward")
	Telemetry.custom(inviter, "invite_join", 1, { "inviter_paid" })
	Net.toast(
		inviter,
		string.format("A friend you invited is playing! +%d golden fish", Config.InviteRewardFish),
		"good"
	)
	CafeService.sync(inviter)
end

local function pullPending(player: Player, profile: Types.PlayerProfile)
	lastPull[player] = os.clock()
	for _, joinerId in takePending(player.UserId) do
		if DataService.get(player) ~= profile then
			return -- left while the store answered; the ids are gone, which loses at most this pickup
		end
		payInviter(player, profile, joinerId)
	end
end

local function inviterOf(player: Player): number?
	local ok, data = pcall(function()
		return player:GetJoinData()
	end)
	if not ok or type(data) ~= "table" then
		return nil
	end
	local referred = (data :: any).ReferredByPlayerId
	return if type(referred) == "number" and referred > 0 then referred else nil
end

local function onLoaded(player: Player, profile: Types.PlayerProfile)
	local inviterId = inviterOf(player)
	if Invites.links(profile, player.UserId, inviterId, profile.stats.playtimeSeconds) then
		profile.referredBy = { userId = inviterId :: number, paid = false, queued = false }
		Telemetry.custom(player, "invite_join", 1, { "linked" })
	end
	task.spawn(pullPending, player, profile)
end

local function check(player: Player)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	local link = profile.referredBy
	if link ~= nil and Invites.joinerDue(profile) then
		link.paid = true -- marked before paying, so a failure inside never pays it twice
		Payout.pay(player, profile, { fish = Config.InviteRewardFish }, "invite_reward")
		Telemetry.custom(player, "invite_join", 1, { "joiner_paid" })
		Net.toast(
			player,
			string.format(
				"Welcome! Thanks for joining your friend: +%d golden fish",
				Config.InviteRewardFish
			),
			"good"
		)
		CafeService.sync(player)
	end
	if link ~= nil and Invites.inviterDue(profile, PlayTime.seconds(player, profile)) then
		link.queued = true
		local inviter = Players:GetPlayerByUserId(link.userId)
		local inviterProfile = if inviter ~= nil then DataService.get(inviter) else nil
		if inviter ~= nil and inviterProfile ~= nil then
			payInviter(inviter, inviterProfile, player.UserId)
		elseif not addPending(link.userId, player.UserId) then
			link.queued = false -- try again next check
			return
		end
		Telemetry.custom(player, "invite_join", 1, { "inviter_sent" })
	end
	local last = lastPull[player]
	if last ~= nil and os.clock() - last >= Config.InvitePendingCheckSeconds then
		task.spawn(pullPending, player, profile)
	end
end

local function onInviteCard(player: Player, rawAction: unknown)
	local action = Invites.cardAction(rawAction)
	local profile = DataService.get(player)
	if action == nil or profile == nil then
		return
	end
	if action == "shown" then
		if profile.invites.cardShown then
			return -- logged once
		end
		profile.invites.cardShown = true
		CafeService.sync(player)
	end
	Telemetry.custom(
		player,
		"invite_card",
		math.floor(PlayTime.seconds(player, profile) / 60),
		{ action }
	)
end

function InviteService.start()
	Net.on("InviteCard", onInviteCard)
	DataService.onLoaded:Connect(onLoaded)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastPull[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			for _, player in DataService.loadedPlayers() do
				local ok, err = pcall(function()
					check(player)
				end)
				if not ok then
					warn("[InviteService] " .. tostring(err))
				end
			end
		end
	end)
end

-- Studio-only test hooks: links `player` to `inviterId` as a fresh invited joiner, and reads the pending key.
function InviteService.debugLink(player: Player, inviterId: number): boolean
	assert(RunService:IsStudio(), "debugLink is Studio only")
	local profile = DataService.get(player)
	if profile == nil then
		return false
	end
	profile.referredBy = { userId = inviterId, paid = false, queued = false }
	return true
end

function InviteService.debugPending(userId: number): { number }
	assert(RunService:IsStudio(), "debugPending is Studio only")
	return idList(memory[pendingKey(userId)])
end

return InviteService
