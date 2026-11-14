--!strict
-- Cat Cafe server bootstrap. Order matters: remotes and the world exist before any player loads.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local AfkCafeService = require(script.Parent.Services.AfkCafeService)
local ArcadeCabinetService = require(script.Parent.Services.ArcadeCabinetService)
local ArcadeService = require(script.Parent.Services.ArcadeService)
local AssetRegistry = require(script.Parent.World.AssetRegistry)
local AwayNotifyService = require(script.Parent.Services.AwayNotifyService)
local BadgeAwardService = require(script.Parent.Services.BadgeAwardService)
local BaitService = require(script.Parent.Services.BaitService)
local BedtimeService = require(script.Parent.Services.BedtimeService)
local BinService = require(script.Parent.Services.BinService)
local BugReportService = require(script.Parent.Services.BugReportService)
local CafePassService = require(script.Parent.Services.CafePassService)
local CafeService = require(script.Parent.Services.CafeService)
local CampExtraService = require(script.Parent.Services.CampExtraService)
local CannonService = require(script.Parent.Services.CannonService)
local CatService = require(script.Parent.Services.CatService)
local ClaimAllService = require(script.Parent.Services.ClaimAllService)
local ClockService = require(script.Parent.Services.ClockService)
local CodeService = require(script.Parent.Services.CodeService)
local CollectorService = require(script.Parent.Services.CollectorService)
local CornerShopService = require(script.Parent.Services.CornerShopService)
local CozyService = require(script.Parent.Services.CozyService)
local DailyTreatService = require(script.Parent.Services.DailyTreatService)
local DataService = require(script.Parent.Services.DataService)
local DealerService = require(script.Parent.Services.DealerService)
local EventRewardService = require(script.Parent.Services.EventRewardService)
local EventService = require(script.Parent.Services.EventService)
local FallCatchService = require(script.Parent.Services.FallCatchService)
local FeedService = require(script.Parent.Services.FeedService)
local FishMarketService = require(script.Parent.Services.FishMarketService)
local FishStoreService = require(script.Parent.Services.FishStoreService)
local GlobalCatchService = require(script.Parent.Services.GlobalCatchService)
local GrandOpeningService = require(script.Parent.Services.GrandOpeningService)
local IdeaCreditsService = require(script.Parent.Services.IdeaCreditsService)
local IndexRewardService = require(script.Parent.Services.IndexRewardService)
local IntroModeService = require(script.Parent.Services.IntroModeService)
local IntroService = require(script.Parent.Services.IntroService)
local InviteService = require(script.Parent.Services.InviteService)
local LateStationService = require(script.Parent.Services.LateStationService)
local LawnService = require(script.Parent.Services.LawnService)
local LeaderboardService = require(script.Parent.Services.LeaderboardService)
local LiveFlagService = require(script.Parent.Services.LiveFlagService)
local MouseDashService = require(script.Parent.Services.MouseDashService)
local MysteryMarketService = require(script.Parent.Services.MysteryMarketService)
local MysteryService = require(script.Parent.Services.MysteryService)
local MysticPoolStationService = require(script.Parent.Services.MysticPoolStationService)
local NameService = require(script.Parent.Services.NameService)
local Net = require(script.Parent.Services.Net)
local NightService = require(script.Parent.Services.NightService)
local OwnerTestService = require(script.Parent.Services.OwnerTestService)
local PalService = require(script.Parent.Services.PalService)
local PassService = require(script.Parent.Services.PassService)
local PetService = require(script.Parent.Services.PetService)
local PityService = require(script.Parent.Services.PityService)
local PlaytimeGiftService = require(script.Parent.Services.PlaytimeGiftService)
local PlotService = require(script.Parent.Services.PlotService)
local PotionService = require(script.Parent.Services.PotionService)
local ProductService = require(script.Parent.Services.ProductService)
local QuestService = require(script.Parent.Services.QuestService)
local QuietStartService = require(script.Parent.Services.QuietStartService)
local RallyService = require(script.Parent.Services.RallyService)
local RankSpotService = require(script.Parent.Services.RankSpotService)
local RareCatsTabService = require(script.Parent.Services.RareCatsTabService)
local RareCustomerService = require(script.Parent.Services.RareCustomerService)
local RareMomentService = require(script.Parent.Services.RareMomentService)
local RescueService = require(script.Parent.Services.RescueService)
local ResetSaveService = require(script.Parent.Services.ResetSaveService)
local RestartNoticeService = require(script.Parent.Services.RestartNoticeService)
local RichTipService = require(script.Parent.Services.RichTipService)
local SessionRecapService = require(script.Parent.Services.SessionRecapService)
local ShopCatService = require(script.Parent.Services.ShopCatService)
local ShoveService = require(script.Parent.Services.ShoveService)
local SpinService = require(script.Parent.Services.SpinService)
local StarterCatService = require(script.Parent.Services.StarterCatService)
local StuckGoalService = require(script.Parent.Services.StuckGoalService)
local Telemetry = require(script.Parent.Services.Telemetry)
local TicketBoothService = require(script.Parent.Services.TicketBoothService)
local TipJarService = require(script.Parent.Services.TipJarService)
local TipPileService = require(script.Parent.Services.TipPileService)
local TipService = require(script.Parent.Services.TipService)
local TradeService = require(script.Parent.Services.TradeService)
local TraitService = require(script.Parent.Services.TraitService)
local TravelService = require(script.Parent.Services.TravelService)
local TutorialMoveService = require(script.Parent.Services.TutorialMoveService)
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
-- #3743: the area sets and backdrops leave ReplicatedStorage before anyone joins, so no client is sent them
local stowed = AssetRegistry.stowServerOnly()
local world = WorldBuilder.build()

Net.start()
ClockService.start()
EventService.start() -- #2486: Cafe Events, after the clock whose days they force
EventRewardService.start() -- #2486: the event reward (badge, free piece) for a secure, or at an early end
PlotService.start(world)
CafeService.start()
LawnService.start() -- F91: the front lawn's remotes
BedtimeService.start() -- F79: after CafeService, which builds the cats it walks
BaitService.start()
CatService.start(world)
RescueService.start(world)
TravelService.start(world)
NightService.start(world) -- after the cats, traps and travel: the first sunrise wave
PityService.start() -- #1572: the global pity cat, after the cats it spawns and the clock it counts on
CannonService.start(world) -- F84: after the cats, travel and the night sweep it hands landings to
TutorialMoveService.start(world) -- #2697: the bowl and cannon moves, after the cats and the cannons
FallCatchService.start() -- #2651: the Ruins' mist catch, after the cannon whose pads it lands you on
DealerService.start()
RankSpotService.start() -- #3555: when the first rank up's walk-through may show, behind rankUpSpotlight
RichTipService.start()
TipPileService.start()
MysteryService.start()
CollectorService.start()
RareCustomerService.start() -- #3889: after the three it sends visits to
QuestService.start() -- F73: after the services whose counters its quests read
PotionService.start()
ShoveService.start()
QuietStartService.start() -- #4005: a new player's quiet start, before DataService (onLoaded)
NameService.start()
TipJarService.start()
DailyTreatService.start()
IndexRewardService.start()
ClaimAllService.start() -- Claim all in the Quests window, the Index and the Tip Jar
SpinService.start()
FishMarketService.start()
TraitService.start() -- #3196: the Mystic Pool, refused while the `traits` switch is off
MysticPoolStationService.start() -- #3196: the pool stands in the Picnic Basket's place while the switch is on
MysteryMarketService.start() -- #2565: Juniper's Mystery Market
FishStoreService.start() -- #4055: Store passes for golden fish
TicketBoothService.start() -- #4061: the Water Park's Ticket Booth
CornerShopService.start() -- #1052: the coins-only Corner Shop
FeedService.start() -- #1181: cat food from the Bag (FeedCat)
LiveFlagService.start() -- #2119: the live switches (codes, rally) from CatCafe_Flags
CodeService.start()
StarterCatService.start() -- F96: the free Bellhop Cat
ShopCatService.start() -- #1447: the Royal and King cats on their passes
RareMomentService.start() -- F89: the toast clock
GlobalCatchService.start() -- #2203: rare catches from other servers, as chat lines
RareCatsTabService.start() -- #3053: the chat's Rare Cats tab, behind the rareCatsTab switch (off)
IntroService.start()
IntroModeService.start() -- #4001: the short intro test arm, read as each player joins
TipService.start() -- F87: context tips and feedback; before DataService so its onLoaded sees every join
BugReportService.start(world)
IdeaCreditsService.start() -- #1083: the Thank You board's credits
PassService.start() -- F95: purchases in game; DataService checks owned passes at each join
ProductService.start() -- #1182: developer product receipts (ProcessReceipt)
OwnerTestService.start() -- #1770: owner test mode (OwnerGrant, the OwnerTest attribute)
PalService.start() -- F92: pals; before Telemetry so pal_time goes out before its leave work
LeaderboardService.start() -- F98: before DataService so its onLoaded sees every join
CampExtraService.start() -- F100: before DataService so its onLoaded sees every join
LateStationService.start() -- #2651 part 4: the Oasis Spa and Relic Museum, before DataService (onLoaded)
StuckGoalService.start() -- #2912: the stuck cat pointer, after RescueService
BinService.start() -- #3050: the Rummage Bin, after RescueService (its bar's remotes) and before DataService
InviteService.start() -- #2797: the invite reward, before DataService (onLoaded links an invited new player)
CafePassService.start() -- #1645: the Cafe Pass, before DataService so its onLoaded sees every join
GrandOpeningService.start() -- #1893: the Grand Opening roadmap's checks and payouts
SessionRecapService.start() -- #1920: the session recap after about 40 minutes of play
BadgeAwardService.start() -- #1934: Roblox badges, awarded from the profile with retries and a catch-up on join
ArcadeService.start() -- #3062: the Cat Arcade, before DataService so its onLoaded sees every join
MouseDashService.start() -- #3296: the arcade's Mouse Dash, before DataService for the same reason
ArcadeCabinetService.start() -- #3443: the cabinet and its ring are in the world only while the arcade has a game on
PlaytimeGiftService.start() -- #1947: the like and favourite gifts at 10 and 30 minutes of play
CozyService.start() -- #2798: Cozy Cafe, the gift bags for staying in your cafe
PetService.start() -- #3651: pet a cat, the happy cat pays double for an hour (switch petCats)
AfkCafeService.start() -- #3573: resting in your own cafe pays the cats' cafe pay double
AwayNotifyService.start() -- #2768: notes who is due an away notification, before DataService (onLoaded)
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
		"[CatCafe] server ready in %.2fs: %d plots, %d placeholder models, %d server-only templates",
		os.clock() - started,
		#world.plots,
		placeholders,
		stowed
	)
)
