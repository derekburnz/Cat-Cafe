--!strict
-- Purr Pot server bootstrap. Order matters: remotes and the world exist before any player loads.

local AssetRegistry = require(script.Parent.World.AssetRegistry)
local CafeService = require(script.Parent.Services.CafeService)
local CatService = require(script.Parent.Services.CatService)
local DataService = require(script.Parent.Services.DataService)
local Net = require(script.Parent.Services.Net)
local PlotService = require(script.Parent.Services.PlotService)
local WorldBuilder = require(script.Parent.World.WorldBuilder)

local started = os.clock()
local placeholders = AssetRegistry.ensurePlaceholders()
local world = WorldBuilder.build()

Net.start()
PlotService.start(world)
CafeService.start()
CatService.start(world)
DataService.start()

print(
	string.format(
		"[PurrPot] server ready in %.2fs: %d plots, %d placeholder models",
		os.clock() - started,
		#world.plots,
		placeholders
	)
)
