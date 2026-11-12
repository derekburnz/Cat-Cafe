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
local LiveFlags = require(ReplicatedStorage.Shared.LiveFlags)
local PlotService = require(script.Parent.PlotService)
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
		Telemetry.custom(
			player,
			"rank_up_ready_first",
			1,
			{ Telemetry.device(player) or "unknown" }
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
	local area = WorldBuilder.areaAt(PlotService.world(), (root :: BasePart).Position)
	local due = RankSpot.due(on, tier, profile.tipsSeen[RankSpot.SEEN] == true, blocker, area)
	player:SetAttribute(RankSpot.ATTRIBUTE, if due then true else nil)
end

function RankSpotService.start()
	Players.PlayerRemoving:Connect(function(player: Player)
		readyAt[player] = nil
		pressed[player] = nil
	end)
	task.spawn(function()
		while true do
			local on = LiveFlags.shown(
				RankSpot.FLAG,
				ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. RankSpot.FLAG)
			)
			for _, player in Players:GetPlayers() do
				watch(player, on)
			end
			task.wait(TICK)
		end
	end)
end

return RankSpotService
