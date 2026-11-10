--!strict
-- Cat Cafe client bootstrap: sound channels first, then the UI (it needs the catalog), world touches, cosmetic
-- customers and the effects that read them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
ReplicatedStorage:WaitForChild("Remotes")

local Audio = require(script.Parent.Audio)
local CampExtrasController = require(script.Parent.Controllers.CampExtrasController)
local CannonController = require(script.Parent.Controllers.CannonController)
local ChatTagController = require(script.Parent.Controllers.ChatTagController)
local CodesController = require(script.Parent.Controllers.CodesController)
local CustomerController = require(script.Parent.Controllers.CustomerController)
local DoorController = require(script.Parent.Controllers.DoorController)
local Effects = require(script.Parent.Effects)
local GoldHutController = require(script.Parent.Controllers.GoldHutController)
local IntroController = require(script.Parent.Controllers.IntroController)
local LateStationsController = require(script.Parent.Controllers.LateStationsController)
local Moments = require(script.Parent.Moments)
local MuseumGalleryController = require(script.Parent.Controllers.MuseumGalleryController)
local NetSwingController = require(script.Parent.Controllers.NetSwingController)
local ParkFirstController = require(script.Parent.Controllers.ParkFirstController)
local RallyController = require(script.Parent.Controllers.RallyController)
local RareCatchChatController = require(script.Parent.Controllers.RareCatchChatController)
local ShoveController = require(script.Parent.Controllers.ShoveController)
local SpaPoolController = require(script.Parent.Controllers.SpaPoolController)
local StarterCatController = require(script.Parent.Controllers.StarterCatController)
local StyleController = require(script.Parent.Controllers.StyleController)
local TradeController = require(script.Parent.Controllers.TradeController)
local UIController = require(script.Parent.Controllers.UIController)
local WalkUpController = require(script.Parent.Controllers.WalkUpController)
local WorldController = require(script.Parent.Controllers.WorldController)

Audio.start()
Audio.bindMoments(Moments :: any)
UIController.start()
WorldController.start()
DoorController.start()
IntroController.start() -- after the UI and the world controller, whose hooks it uses
StyleController.start()
ShoveController.start()
NetSwingController.start() -- F93: the net swing, after the UI whose Net button it listens to
CannonController.start() -- F84: after the UI, whose cannon picker it opens
ParkFirstController.start() -- #2915: the first Park landing toast and the stray ring, after the cannon
CampExtrasController.start() -- F100: the camp extras' prompts, after the UI whose hooks it uses
GoldHutController.start() -- #1368: the Golden Pond pass's gold Fishing Hut, on its owner's client
RallyController.start() -- F101: the Rescue Rally's state for the UI's banner
TradeController.start() -- F102: trading, after the UI whose trade window it feeds
CodesController.start()
WalkUpController.start() -- #2398: the stations' windows open as you walk up, after the UI that draws them
ChatTagController.start() -- #1624: the VIP tag in chat
RareCatchChatController.start() -- #2203: rare catches here and in other servers, as chat lines
LateStationsController.start() -- #2651 part 4: the Oasis Spa and Relic Museum cards, after the UI that draws them
MuseumGalleryController.start() -- #2908: your filled exhibits on the Relic Museum's plinths
SpaPoolController.start() -- #2909: your own cats soaking in the Oasis Spa pool
StarterCatController.start() -- F96: the Bellhop Cat's stand card
CustomerController.start()
Effects.start()
