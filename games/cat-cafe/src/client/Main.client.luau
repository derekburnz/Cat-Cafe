--!strict
-- Cat Cafe client bootstrap: sound channels first, then the UI (it needs the catalog), world touches, cosmetic
-- customers and the effects that read them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
ReplicatedStorage:WaitForChild("Remotes")

local Audio = require(script.Parent.Audio)
local CustomerController = require(script.Parent.Controllers.CustomerController)
local Effects = require(script.Parent.Effects)
local Moments = require(script.Parent.Moments)
local ShoveController = require(script.Parent.Controllers.ShoveController)
local StyleController = require(script.Parent.Controllers.StyleController)
local UIController = require(script.Parent.Controllers.UIController)
local WorldController = require(script.Parent.Controllers.WorldController)

Audio.start()
Audio.bindMoments(Moments :: any)
UIController.start()
WorldController.start()
StyleController.start()
ShoveController.start()
CustomerController.start()
Effects.start()
