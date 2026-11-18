--!strict
-- The cat follower on the server (#5172, the rules are shared/Follower; switch `catFollower`, off by default).
--   SetFollower(uid: string)  C -> S  2 a second: "" sends the follower home; else one of the player's own cats
--     (Follower.blocker: the switch, Tier 2, owning it, no running trade). The window so far is settled first, since
--     a Money follower changes the pay.
--   SetFollowerBoost(boost: "money" | "luck")  C -> S  2 a second and one switch each Follower.SWITCH_SECONDS.
-- The following cat shows to everyone through the player's attributes FollowerUid, FollowerCat (the catId) and
-- FollowerVariant ("gold", "rainbow" or nil), which the client's FollowerController walks. A loop every
-- REFRESH_SECONDS keeps them true when the cat is traded away or sold, the tier changes or the switch flips.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CafeService = require(script.Parent.CafeService)
local ClockService = require(script.Parent.ClockService)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Follower = require(ReplicatedStorage.Shared.Follower)
local Guard = require(script.Parent.Parent.Util.Guard)
local Net = require(script.Parent.Net)
local TradeService = require(script.Parent.TradeService)

local FollowerService = {}

FollowerService.REFRESH_SECONDS = 2
FollowerService.SWITCH_AT = "FollowerSwitchAt" -- Player attribute: os.time() of the last boost switch

local BOOSTS = { "money", "luck" }

local lastSwitch: { [Player]: number } = {} -- os.clock() of each player's last boost switch

-- Puts the following cat (or none) on the player's attributes for every client.
function FollowerService.refresh(player: Player)
	local profile = DataService.get(player)
	local cat = if profile ~= nil then Follower.cat(profile) else nil
	local uid = if cat ~= nil then cat.uid else nil
	if player:GetAttribute("FollowerUid") ~= uid then
		player:SetAttribute("FollowerUid", uid)
	end
	local catId = if cat ~= nil then cat.catId else nil
	if player:GetAttribute("FollowerCat") ~= catId then
		player:SetAttribute("FollowerCat", catId)
	end
	local variant = if cat ~= nil then cat.variant else nil
	if player:GetAttribute("FollowerVariant") ~= variant then
		player:SetAttribute("FollowerVariant", variant)
	end
end

local function onSet(player: Player, rawUid: unknown)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	local home = rawUid == Follower.HOME
	local uid = if home then Follower.HOME else Guard.id(rawUid)
	if uid == nil then
		return
	end
	if not home then
		local reason = Follower.blocker(profile, uid, TradeService.isTrading(player))
		if reason ~= nil then
			Net.toast(player, reason, "info")
			return
		end
	end
	if profile.follower.uid == uid then
		return
	end
	Economy.settle(profile, os.time(), ClockService.epoch()) -- the window so far at its own rate
	profile.follower.uid = uid
	FollowerService.refresh(player)
	CafeService.sync(player)
end

local function onBoost(player: Player, rawBoost: unknown)
	local profile = DataService.get(player)
	local boost = Guard.oneOf(rawBoost, BOOSTS)
	if profile == nil or boost == nil or not Follower.on() then
		return
	end
	if profile.follower.boost == boost then
		return
	end
	local now = os.clock()
	local last = lastSwitch[player]
	if last ~= nil and now - last < Follower.SWITCH_SECONDS then
		Net.toast(
			player,
			string.format("Switch again in %ds", math.ceil(Follower.SWITCH_SECONDS - (now - last))),
			"info"
		)
		return
	end
	lastSwitch[player] = now
	player:SetAttribute(FollowerService.SWITCH_AT, os.time())
	Economy.settle(profile, os.time(), ClockService.epoch())
	profile.follower.boost = if boost == "luck" then "luck" else "money"
	CafeService.sync(player)
end

function FollowerService.start()
	Net.on("SetFollower", onSet)
	Net.on("SetFollowerBoost", onBoost)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastSwitch[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(FollowerService.REFRESH_SECONDS)
			for _, player in Players:GetPlayers() do
				FollowerService.refresh(player)
			end
		end
	end)
end

return FollowerService
