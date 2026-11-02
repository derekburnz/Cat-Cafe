--!strict
-- Cat Cafe client bootstrap: sound channels first, then the UI (it needs the catalog), world touches, cosmetic
-- customers and the effects that read them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
ReplicatedStorage:WaitForChild("Remotes")

local Audio = require(script.Parent.Audio)
local CannonController = require(script.Parent.Controllers.CannonController)
local CodesController = require(script.Parent.Controllers.CodesController)
local CustomerController = require(script.Parent.Controllers.CustomerController)
local DoorController = require(script.Parent.Controllers.DoorController)
local Effects = require(script.Parent.Effects)
local IntroController = require(script.Parent.Controllers.IntroController)
local Moments = require(script.Parent.Moments)
local NetSwingController = require(script.Parent.Controllers.NetSwingController)
local ShoveController = require(script.Parent.Controllers.ShoveController)
local StarterCatController = require(script.Parent.Controllers.StarterCatController)
local StyleController = require(script.Parent.Controllers.StyleController)
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
CodesController.start()
StarterCatController.start() -- F96: the Bellhop Cat's stand card
CustomerController.start()
Effects.start()
