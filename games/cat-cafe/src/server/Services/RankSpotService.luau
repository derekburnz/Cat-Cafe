--!strict
-- #3555: the server's word on the first rank up's walk-through (shared/RankSpot). Once a second it sets each
-- player's RankSpotlight attribute: true only while the switch is on, the cafe is Tier 1, Economy.rankUpBlocker
-- would let the rank up through, the walk-through has not been put away (tipsSeen) and the player stands outside
-- every catching area. The client shows nothing without it. Telemetry: rank_up_ready_first the first time a Tier 1
-- cafe is ready this session, rank_up_pressed_first with the seconds from then to the rank up.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Layout = require(script.Parent.Parent.World.Layout)
local LiveFlagService = require(script.Parent.LiveFlagService)
local PlotService = require(script.Parent.PlotService)
local RankFirst = require(ReplicatedStorage.Shared.RankFirst)
local RankSpot = require(ReplicatedStorage.Shared.RankSpot)
local Telemetry = require(script.Parent.Telemetry)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local RankSpotService = {}

local TICK = 1

local readyAt: { [Player]: number } = {} -- os.clock() a Tier 1 cafe was first seen ready this session
local pressed: { [Player]: boolean } = {}

local function watch(player: Player, on: boolean)
	local profile = DataService.get(player)
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if profile == nil or root == nil or not root:IsA("BasePart") then
		player:SetAttribute(RankSpot.ATTRIBUTE, nil)
		return
	end
	local tier = Economy.tier(profile)
	local blocker = if tier == 1 then Economy.rankUpBlocker(profile) else nil
	if tier == 1 and blocker == nil and readyAt[player] == nil then
		readyAt[player] = os.clock()
		-- the Nov 16 drop-off read (148 of 431 ready players never pressed): the second field says where the player
		-- stood when Tier 2 got ready, "safe" (cafes and Town Square, where the walk-through shows) or the area id
		local zone = WorldBuilder.areaAt(PlotService.world(), (root :: BasePart).Position)
		Telemetry.custom(
			player,
			"rank_up_ready_first",
			1,
			{ Telemetry.device(player) or "unknown", zone or "safe" }
		)
	elseif tier >= 2 and readyAt[player] ~= nil and not pressed[player] then
		pressed[player] = true
		Telemetry.custom(
			player,
			"rank_up_pressed_first",
			math.floor(os.clock() - readyAt[player]),
			{ Telemetry.device(player) or "unknown" }
		)
	end
	local seen = profile.tipsSeen[RankSpot.SEEN] == true
	local due = false
	local stay = LiveFlagService.on(RankFirst.STAY_FLAG) -- #5516
	if RankSpot.due(on, tier, seen, blocker, nil, stay) then
		-- the area last, and only when everything else holds
		local at = (root :: BasePart).Position
		local area = WorldBuilder.areaAt(PlotService.world(), at)
		-- #4847 (Derek 2026-11-16: "the rank up doesn't get pointed to when ready unless the player teleports
		-- somewhere else"): an area's camp is a safe zone too. Bowl first readies Tier 2 at the Alleyway camp, where
		-- the third cat is checked in, so the walk-through shows there at once
		if area ~= nil and Layout.campAt(at.X, at.Z) ~= nil then
			area = nil
		end
		due = RankSpot.due(on, tier, seen, blocker, area, stay)
	end
	player:SetAttribute(RankSpot.ATTRIBUTE, if due then true else nil)
end

function RankSpotService.start()
	Players.PlayerRemoving:Connect(function(player: Player)
		readyAt[player] = nil
		pressed[player] = nil
	end)
	task.spawn(function()
		while true do
			local on = true -- #4654 batch 6: the `rankUpSpotlight` switch is retired (on live since launch week)
			for _, player in Players:GetPlayers() do
				watch(player, on)
			end
			task.wait(TICK)
		end
	end)
end

return RankSpotService
