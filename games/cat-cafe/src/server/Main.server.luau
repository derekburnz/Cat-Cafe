--!strict
-- Cat Cafe server bootstrap. Order matters: remotes and the world exist before any player loads.

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local AssetRegistry = require(script.Parent.World.AssetRegistry)
local BaitService = require(script.Parent.Services.BaitService)
local BugReportService = require(script.Parent.Services.BugReportService)
local CafeService = require(script.Parent.Services.CafeService)
local CatService = require(script.Parent.Services.CatService)
local ClockService = require(script.Parent.Services.ClockService)
local CodeService = require(script.Parent.Services.CodeService)
local CollectorService = require(script.Parent.Services.CollectorService)
local DataService = require(script.Parent.Services.DataService)
local DealerService = require(script.Parent.Services.DealerService)
local FishMarketService = require(script.Parent.Services.FishMarketService)
local IndexRewardService = require(script.Parent.Services.IndexRewardService)
local IntroService = require(script.Parent.Services.IntroService)
local MysteryService = require(script.Parent.Services.MysteryService)
local NameService = require(script.Parent.Services.NameService)
local Net = require(script.Parent.Services.Net)
local NightService = require(script.Parent.Services.NightService)
local PlotService = require(script.Parent.Services.PlotService)
local PotionService = require(script.Parent.Services.PotionService)
local QuestService = require(script.Parent.Services.QuestService)
local RescueService = require(script.Parent.Services.RescueService)
local RichTipService = require(script.Parent.Services.RichTipService)
local ShoveService = require(script.Parent.Services.ShoveService)
local SpinService = require(script.Parent.Services.SpinService)
local Telemetry = require(script.Parent.Services.Telemetry)
local TipJarService = require(script.Parent.Services.TipJarService)
local TipPileService = require(script.Parent.Services.TipPileService)
local TravelService = require(script.Parent.Services.TravelService)
local WorldBuilder = require(script.Parent.World.WorldBuilder)

local started = os.clock()
local placeholders = AssetRegistry.ensurePlaceholders()
local world = WorldBuilder.build()

Net.start()
ClockService.start()
PlotService.start(world)
CafeService.start()
BaitService.start()
CatService.start(world)
RescueService.start(world)
TravelService.start(world)
NightService.start(world) -- after the cats, traps and travel: the first sunrise wave
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
IndexRewardService.start()
SpinService.start()
FishMarketService.start()
CodeService.start()
IntroService.start() -- after CafeService: a newcomer lands inside the back door once it has a plot
BugReportService.start(world)
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
