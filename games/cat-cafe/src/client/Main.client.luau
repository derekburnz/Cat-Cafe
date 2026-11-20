--!strict
-- Cat Cafe client bootstrap: sound channels first, then the UI (it needs the catalog), world touches, cosmetic
-- customers and the effects that read them.

local bootAt = os.clock() -- #4307: client_boot's start (TelemetryReport boot_ui and boot_sync)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
ReplicatedStorage:WaitForChild("Remotes")

local AdminEventController = require(script.Parent.Controllers.AdminEventController)
local AdventBoardController = require(script.Parent.Controllers.AdventBoardController)
local AfkController = require(script.Parent.Controllers.AfkController)
local AirMovesController = require(script.Parent.Controllers.AirMovesController)
local Audio = require(script.Parent.Audio)
local BackdropController = require(script.Parent.Controllers.BackdropController)
local BinController = require(script.Parent.Controllers.BinController)
local CafeGrewController = require(script.Parent.Controllers.CafeGrewController)
local CampExtrasController = require(script.Parent.Controllers.CampExtrasController)
local CannonController = require(script.Parent.Controllers.CannonController)
local ChatTagController = require(script.Parent.Controllers.ChatTagController)
local CodesController = require(script.Parent.Controllers.CodesController)
local CompanionSceneController = require(script.Parent.Controllers.CompanionSceneController)
local CustomerController = require(script.Parent.Controllers.CustomerController)
local DoorController = require(script.Parent.Controllers.DoorController)
local Effects = require(script.Parent.Effects)
local FirstCatArrowController = require(script.Parent.Controllers.FirstCatArrowController)
local FollowerController = require(script.Parent.Controllers.FollowerController)
local GoldHutController = require(script.Parent.Controllers.GoldHutController)
local IntroController = require(script.Parent.Controllers.IntroController)
local LandHoldController = require(script.Parent.Controllers.LandHoldController)
local LateStationsController = require(script.Parent.Controllers.LateStationsController)
local MemoryWatchController = require(script.Parent.Controllers.MemoryWatchController)
local Moments = require(script.Parent.Moments)
local MuseumGalleryController = require(script.Parent.Controllers.MuseumGalleryController)
local NetSwingController = require(script.Parent.Controllers.NetSwingController)
local NoClimbController = require(script.Parent.Controllers.NoClimbController)
local ParkFirstController = require(script.Parent.Controllers.ParkFirstController)
local ParkTrailController = require(script.Parent.Controllers.ParkTrailController)
local PerfSuggestController = require(script.Parent.Controllers.PerfSuggestController)
local PerfWatchController = require(script.Parent.Controllers.PerfWatchController)
local PetController = require(script.Parent.Controllers.PetController)
local RallyController = require(script.Parent.Controllers.RallyController)
local RankSpotController = require(script.Parent.Controllers.RankSpotController)
local RareCatchChatController = require(script.Parent.Controllers.RareCatchChatController)
local ShoveController = require(script.Parent.Controllers.ShoveController)
local SpaPoolController = require(script.Parent.Controllers.SpaPoolController)
local StartStallController = require(script.Parent.Controllers.StartStallController)
local StarterCatController = require(script.Parent.Controllers.StarterCatController)
local StationCutController = require(script.Parent.Controllers.StationCutController)
local StationLockController = require(script.Parent.Controllers.StationLockController)
local StyleController = require(script.Parent.Controllers.StyleController)
local TomorrowBoardController = require(script.Parent.Controllers.TomorrowBoardController)
local TradeController = require(script.Parent.Controllers.TradeController)
local UIController = require(script.Parent.Controllers.UIController)
local WalkUpController = require(script.Parent.Controllers.WalkUpController)
local WorldController = require(script.Parent.Controllers.WorldController)

do
	-- #4613: a switch the UI takes once (the menu family look, the Store's rework) would latch the defaults on a server
	-- that has not read its switches yet, so wait for that first read, a few seconds at most, usually none
	local LiveFlags = require(ReplicatedStorage.Shared.LiveFlags)
	LiveFlags.awaitReady(
		ReplicatedStorage,
		LiveFlags.CLIENT_WAIT_SECONDS,
		os.clock,
		function(seconds: number)
			task.wait(seconds)
		end
	)
end
-- #4763: the tables caps follow the tablesSpread switch, like the server's (shared/TablesSpread)
require(ReplicatedStorage.Shared.TablesSpread).follow()
require(ReplicatedStorage.Shared.TablesEight).follow() -- #5441: Tables 7 and 8 follow the tablesEight switch
-- #5171: the Spin Wheel's cat slice follows the spinCat switch, like the server's (shared/SpinCat)
require(ReplicatedStorage.Shared.SpinCat).follow()
require(ReplicatedStorage.Shared.NetTiers).follow() -- #5170: the net caps follow the netTiers switch
require(ReplicatedStorage.Shared.PerfectCatch).follow() -- #5300: the ratings shown follow the perfectCatch switch
require(ReplicatedStorage.Shared.EasyKeep).follow() -- #5311: the Dragon Keep's goals follow the easyKeep switch
require(ReplicatedStorage.Shared.BigTreats).follow() -- Derek 2026-11-18: the Daily Treat rows follow bigTreats
require(ReplicatedStorage.Shared.CheapTiers).follow() -- #5249: what Tiers 3 to 8 ask follows the cheapTiers switch
require(ReplicatedStorage.Shared.CompanionTraits).follow() -- #5303: the companion traits follow the companionTraits switch
do
	-- #5264: food lists sort by rarity first while foodByRarity is on (read before the UI builds its lists; a list
	-- already built keeps its order until it is built again)
	local FoodOrder = require(script.Parent.UI.Components.FoodOrder)
	local LiveFlags = require(ReplicatedStorage.Shared.LiveFlags)
	local attribute = LiveFlags.ATTRIBUTE_PREFIX .. FoodOrder.FLAG
	local function apply()
		FoodOrder.setByRarity(
			LiveFlags.shown(FoodOrder.FLAG, ReplicatedStorage:GetAttribute(attribute))
		)
	end
	apply()
	ReplicatedStorage:GetAttributeChangedSignal(attribute):Connect(apply)
end
Audio.start()
Audio.bindMoments(Moments :: any)
UIController.start()
do
	-- #4307: how long the UI build and the wait for the save take on this device (analytics only)
	local Net = require(script.Parent.Net)
	Net.fire("TelemetryReport", "boot_ui", math.min(os.clock() - bootAt, 300))
	local function synced()
		Net.fire("TelemetryReport", "boot_sync", math.min(os.clock() - bootAt, 300))
		PerfWatchController.synced() -- #4783: client_load's ready waits for the save too
	end
	if UIController.state ~= nil then
		synced() -- the save came while the UI was being built
	else
		local first: RBXScriptConnection? = nil
		first = Net.on("ProfileSync", function()
			if first ~= nil then
				first:Disconnect()
				first = nil
				synced()
			end
		end)
	end
end
WorldController.start()
DoorController.start()
IntroController.start() -- after the UI and the world controller, whose hooks it uses
PerfWatchController.start(bootAt) -- #4783: load time and average FPS for every player, analytics only
BackdropController.start() -- #4857: far areas' backdrop rings out of this client's Workspace, behind backdropsNear
MemoryWatchController.start() -- #3743: the client's memory at 5, 15, 30 and 60 minutes, analytics only
StyleController.start()
NoClimbController.start() -- #4073: the player's own character climbs only at the real ladders
ShoveController.start()
NetSwingController.start() -- F93: the net swing, after the UI whose Net button it listens to
AirMovesController.start() -- #4447: the Dragon Keep's Double Jump and Glide
CannonController.start() -- F84: after the UI, whose cannon picker it opens
LandHoldController.start() -- #5269: a cannon landing waits on this client for the pad floor, behind landSafe
ParkFirstController.start() -- #2915: the first Park landing toast and the stray ring, after the cannon
CafeGrewController.start() -- #4543: "Your cafe grew!" on the Rank Up card, after the UI
ParkTrailController.start() -- #3554: the goal and paw trail to a first Park catch, behind parkGateTrail
RankSpotController.start() -- #3555: the first rank up's walk-through, behind rankUpSpotlight
AdminEventController.start() -- #4195: the admin event's banner, timer and the Admin Wheel
CampExtrasController.start() -- F100: the camp extras' prompts, after the UI whose hooks it uses
BinController.start() -- #3050: the Rummage Bin's prompt and look, after the UI
GoldHutController.start() -- #1368: the Golden Pond pass's gold Fishing Hut, on its owner's client
RallyController.start() -- F101: the Rescue Rally's state for the UI's banner
TradeController.start() -- F102: trading, after the UI whose trade window it feeds
TomorrowBoardController.start() -- #5449: the Daily Treat Board on your cafe wall, after the UI
AdventBoardController.start() -- #5502: the advent calendar board's prompt and doors, after the UI
CodesController.start()
PetController.start() -- #3651: the Pet prompt on your own working cats, after the UI whose pill it uses
FollowerController.start() -- #5172: the cat that follows each player (switch catFollower)
AfkController.start() -- #3573: resting in your cafe, after the UI whose chip it shows
StationLockController.start() -- #4539: Mystery Market, Cat Arcade and Mystic Pool hidden below their tiers
StationCutController.start() -- #5112: a rank up's cut to the station it unlocks, behind stationCut
StartStallController.start() -- #5562: the play first start's stall glow (Effects/WorldGlow.stall)
FirstCatArrowController.start() -- #5594: the arrow over the nearest cat until the first catch, behind firstCatArrow
CompanionSceneController.start() -- #5284: the Cat Companion unlock scene after the Tier 2 rank up, behind companionScene
WalkUpController.start() -- #2398: the stations' windows open as you walk up, after the UI that draws them
ChatTagController.start() -- #1624: the VIP tag in chat
RareCatchChatController.start() -- #2203: rare catches here and in other servers, as chat lines
LateStationsController.start() -- #2651 part 4: the Oasis Spa and Relic Museum cards, after the UI that draws them
MuseumGalleryController.start() -- #2908: your filled exhibits on the Relic Museum's plinths
SpaPoolController.start() -- #2909: your own cats soaking in the Oasis Spa pool
StarterCatController.start() -- F96: the Bellhop Cat's stand card
CustomerController.start()
Effects.start()
PerfSuggestController.start() -- #4311: the one Low performance ask on a slow touch device
