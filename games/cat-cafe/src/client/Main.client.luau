--!strict
-- Purr Pot client bootstrap: sound channels first, then the UI (it needs the catalog), world touches and cosmetic
-- customers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
ReplicatedStorage:WaitForChild("Remotes")

local Audio = require(script.Parent.Audio)
local CustomerController = require(script.Parent.Controllers.CustomerController)
local UIController = require(script.Parent.Controllers.UIController)
local WorldController = require(script.Parent.Controllers.WorldController)

Audio.start()
UIController.start()
WorldController.start()
CustomerController.start()
