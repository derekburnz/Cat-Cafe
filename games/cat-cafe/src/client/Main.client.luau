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
local Moments = require(script.Parent.Moments)
local NetSwingController = require(script.Parent.Controllers.NetSwingController)
local PitySignController = require(script.Parent.Controllers.PitySignController)
local RallyController = require(script.Parent.Controllers.RallyController)
local ShoveController = require(script.Parent.Controllers.ShoveController)
local StarterCatController = require(script.Parent.Controllers.StarterCatController)
local StyleController = require(script.Parent.Controllers.StyleController)
local TradeController = require(script.Parent.Controllers.TradeController)
local UIController = require(script.Parent.Controllers.UIController)
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
CampExtrasController.start() -- F100: the camp extras' prompts, after the UI whose hooks it uses
PitySignController.start() -- #1753: the pity cat's countdown on the Town Square sign
GoldHutController.start() -- #1368: the Golden Pond pass's gold Fishing Hut, on its owner's client
RallyController.start() -- F101: the Rescue Rally's state for the UI's banner
TradeController.start() -- F102: trading, after the UI whose trade window it feeds
CodesController.start()
ChatTagController.start() -- #1624: the VIP tag in chat
StarterCatController.start() -- F96: the Bellhop Cat's stand card
CustomerController.start()
Effects.start()
