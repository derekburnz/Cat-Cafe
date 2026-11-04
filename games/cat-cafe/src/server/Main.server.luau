--!strict
-- Cat Cafe server bootstrap. Order matters: remotes and the world exist before any player loads.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local AssetRegistry = require(script.Parent.World.AssetRegistry)
local BaitService = require(script.Parent.Services.BaitService)
local BedtimeService = require(script.Parent.Services.BedtimeService)
local BugReportService = require(script.Parent.Services.BugReportService)
local CafeService = require(script.Parent.Services.CafeService)
local CampExtraService = require(script.Parent.Services.CampExtraService)
local CannonService = require(script.Parent.Services.CannonService)
local CatService = require(script.Parent.Services.CatService)
local ClaimAllService = require(script.Parent.Services.ClaimAllService)
local ClockService = require(script.Parent.Services.ClockService)
local CodeService = require(script.Parent.Services.CodeService)
local CollectorService = require(script.Parent.Services.CollectorService)
local DailyTreatService = require(script.Parent.Services.DailyTreatService)
local DataService = require(script.Parent.Services.DataService)
local DealerService = require(script.Parent.Services.DealerService)
local FishMarketService = require(script.Parent.Services.FishMarketService)
local GearGuardService = require(script.Parent.Services.GearGuardService)
local IndexRewardService = require(script.Parent.Services.IndexRewardService)
local IntroService = require(script.Parent.Services.IntroService)
local LawnService = require(script.Parent.Services.LawnService)
local LeaderboardService = require(script.Parent.Services.LeaderboardService)
local MysteryService = require(script.Parent.Services.MysteryService)
local NameService = require(script.Parent.Services.NameService)
local Net = require(script.Parent.Services.Net)
local NightService = require(script.Parent.Services.NightService)
local PalService = require(script.Parent.Services.PalService)
local PassService = require(script.Parent.Services.PassService)
local PlotService = require(script.Parent.Services.PlotService)
local PotionService = require(script.Parent.Services.PotionService)
local QuestService = require(script.Parent.Services.QuestService)
local RallyService = require(script.Parent.Services.RallyService)
local RareMomentService = require(script.Parent.Services.RareMomentService)
local RescueService = require(script.Parent.Services.RescueService)
local ResetSaveService = require(script.Parent.Services.ResetSaveService)
local RestartNoticeService = require(script.Parent.Services.RestartNoticeService)
local RichTipService = require(script.Parent.Services.RichTipService)
local ShoveService = require(script.Parent.Services.ShoveService)
local SpinService = require(script.Parent.Services.SpinService)
local StarterCatService = require(script.Parent.Services.StarterCatService)
local Telemetry = require(script.Parent.Services.Telemetry)
local TipJarService = require(script.Parent.Services.TipJarService)
local TipPileService = require(script.Parent.Services.TipPileService)
local TipService = require(script.Parent.Services.TipService)
local TradeService = require(script.Parent.Services.TradeService)
local TravelService = require(script.Parent.Services.TravelService)
local WorldBuilder = require(script.Parent.World.WorldBuilder)

local Config = require(ReplicatedStorage.Shared.Config)

-- The camera zooms out at most Config.CameraMaxZoomStuds (Derek 2026-11-02; Roblox's default is 128). A player takes
-- StarterPlayer's limit as they join; anyone already in (a Studio test can be) gets it here.
StarterPlayer.CameraMaxZoomDistance = Config.CameraMaxZoomStuds
for _, player in Players:GetPlayers() do
	player.CameraMaxZoomDistance = Config.CameraMaxZoomStuds
end

local started = os.clock()
local placeholders = AssetRegistry.ensurePlaceholders()
local world = WorldBuilder.build()

Net.start()
GearGuardService.start() -- #1062: no avatar gear; first, so no gear Tool is ever held
ClockService.start()
PlotService.start(world)
CafeService.start()
LawnService.start() -- F91: the front lawn's remotes
BedtimeService.start() -- F79: after CafeService, which builds the cats it walks
BaitService.start()
CatService.start(world)
RescueService.start(world)
TravelService.start(world)
NightService.start(world) -- after the cats, traps and travel: the first sunrise wave
CannonService.start(world) -- F84: after the cats, travel and the night sweep it hands landings to
DealerService.start()
RichTipService.start()
TipPileService.start()
MysteryService.start()
CollectorService.start()
QuestService.start() -- F73: after the services whose counters its quests read
PotionService.start()
ShoveService.start()
NameService.start()
TipJarService.start()
DailyTreatService.start()
IndexRewardService.start()
ClaimAllService.start() -- Claim all in the Quests window, the Index and the Tip Jar
SpinService.start()
FishMarketService.start()
CodeService.start()
StarterCatService.start() -- F96: the free Bellhop Cat
RareMomentService.start() -- F89: the toast clock
IntroService.start()
TipService.start() -- F87: context tips and feedback; before DataService so its onLoaded sees every join
BugReportService.start(world)
PassService.start() -- F95: purchases in game; DataService checks owned passes at each join
PalService.start() -- F92: pals; before Telemetry so pal_time goes out before its leave work
LeaderboardService.start() -- F98: before DataService so its onLoaded sees every join
CampExtraService.start() -- F100: before DataService so its onLoaded sees every join
RallyService.start() -- F101: before Telemetry (rally_points on leave) and DataService (RallyState on join)
RestartNoticeService.start() -- the restart countdown's warnings; before DataService so a joiner hears one
TradeService.start() -- F102: before DataService, whose joins it settles owed trades in (onLoading)
ResetSaveService.start() -- a tester's Reset my save
Telemetry.start() -- after every service that registers leave work, so its own runs last
DataService.start()

-- Studio only: the command bar and Studio MCP's execute_luau get a fresh copy of any module they require, with
-- its own empty state and unstarted services, so the Debug hooks are reached through this bridge instead. It
-- runs them on the live services in this script's thread:
--   game.ServerStorage.CatCafeDebug:Invoke("setPhase", "night")
-- A BindableFunction in ServerStorage is invisible to clients.
if RunService:IsStudio() then
	local Debug = require(script.Parent.Services.Debug) :: any
	local bridge = Instance.new("BindableFunction")
	bridge.Name = "CatCafeDebug"
	bridge.OnInvoke = function(name: unknown, ...: any): ...any
		local hook: any = if type(name) == "string" then Debug[name] else nil
		if type(hook) ~= "function" then
			error(string.format("[Debug] no hook named %s", tostring(name)), 2)
		end
		return (hook :: (...any) -> ...any)(...)
	end
	bridge.Parent = ServerStorage
end

print(
	string.format(
		"[CatCafe] server ready in %.2fs: %d plots, %d placeholder models",
		os.clock() - started,
		#world.plots,
		placeholders
	)
)
