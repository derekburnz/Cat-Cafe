--!strict
-- Purr Pot client bootstrap: UI first (it needs the catalog), then world touches and cosmetic customers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
ReplicatedStorage:WaitForChild("Remotes")

local CustomerController = require(script.Parent.Controllers.CustomerController)
local UIController = require(script.Parent.Controllers.UIController)
local WorldController = require(script.Parent.Controllers.WorldController)

UIController.start()
WorldController.start()
CustomerController.start()
