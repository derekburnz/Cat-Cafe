--!strict
-- Snowglobe Village's world (snowglobe-village-spec section 3): once the christmasEvent switch is on, this server
-- builds the giant snow globe in the Town Square and the village (World/SnowglobeWorld), once. Off, nothing is built,
-- and switching it off later leaves what is built standing until the server restarts (the event row's dates and the
-- switch keep the portal shut). Trips, the snowflake patch, the stall and the strays are the event row's (GE's
-- EventArea), which reads SnowglobeService.area for the CatService area.

local Workspace = game:GetService("Workspace")

local LiveFlagService = require(script.Parent.LiveFlagService)
local SnowglobeWorld = require(script.Parent.Parent.World.SnowglobeWorld)

local SnowglobeService = {}

SnowglobeService.FLAG = "christmasEvent"
SnowglobeService.STEP = 30 -- seconds between switch checks until it is built

SnowglobeService.portal = nil :: Model?
SnowglobeService.folder = nil :: Folder?
SnowglobeService.area = nil :: any

local function build()
	SnowglobeService.portal = SnowglobeWorld.buildPortal(Workspace)
	local portal = SnowglobeService.portal
	if portal ~= nil then
		-- #5502: the advent calendar board beside the globe; its doors stay shut by date and switch (AdventService)
		local ok, err: any = pcall(SnowglobeWorld.buildAdventBoard, Workspace, portal)
		if not ok then
			warn("[SnowglobeService] advent board failed: " .. tostring(err))
		end
	end
	local folder, info = SnowglobeWorld.buildArea(Workspace)
	SnowglobeService.folder = folder
	SnowglobeService.area = info
end

function SnowglobeService.start()
	task.spawn(function()
		while not LiveFlagService.on(SnowglobeService.FLAG) do
			task.wait(SnowglobeService.STEP)
		end
		local ok, err: any = pcall(build)
		if not ok then
			warn("[SnowglobeService] build failed: " .. tostring(err))
		end
	end)
end

return SnowglobeService
