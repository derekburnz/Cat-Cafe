--!strict
-- Purr Pot client bootstrap: sound channels first, then the UI (it needs the catalog), world touches, cosmetic
-- customers and the effects that read them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
ReplicatedStorage:WaitForChild("Remotes")

local Audio = require(script.Parent.Audio)
local CustomerController = require(script.Parent.Controllers.CustomerController)
local Effects = require(script.Parent.Effects)
local UIController = require(script.Parent.Controllers.UIController)
local WorldController = require(script.Parent.Controllers.WorldController)

Audio.start()
UIController.start()
WorldController.start()
CustomerController.start()
Effects.start()
