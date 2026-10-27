--!strict
-- Fast travel (features F19): the client's top row of Home and area buttons fires Travel(destination). The server
-- checks the destination is "home" or an area this player's tier opens, that they are not carrying a cat or
-- mid catch or rescue (leaving would be a Miss, reviewer N47) and that TravelCooldownSeconds have passed, then
-- moves the character to a landing point the server built. Every answer goes back as TravelResult.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CatService = require(script.Parent.CatService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Guard = require(script.Parent.Parent.Util.Guard)
local Net = require(script.Parent.Net)
local PlotService = require(script.Parent.PlotService)
local Telemetry = require(script.Parent.Telemetry)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local TravelService = {}

local HOME_STEP_OUT = 6 -- studs out from the front door, on the street

local world: WorldBuilder.World? = nil
local lastTravel: { [Player]: number } = {}

-- Where `destination` puts this player, or nil and the reason it is refused.
local function landingFor(player: Player, destination: string): (CFrame?, string?)
	local profile = DataService.get(player)
	if profile == nil then
		return nil, "Still loading"
	end
	if destination == "home" then
		local plot = PlotService.get(player)
		if plot == nil then
			return nil, "You have no cafe yet"
		end
		-- plot space: -Z faces the street, so the street side of the door is further along -Z
		local door = plot.door.Position
		local doorLocal = plot.cframe:PointToObjectSpace(door)
		local outside =
			plot.cframe:PointToWorldSpace(Vector3.new(doorLocal.X, 3, doorLocal.Z - HOME_STEP_OUT))
		return CFrame.lookAt(outside, Vector3.new(door.X, outside.Y, door.Z)), nil
	end
	local area = Catalog.getArea(destination)
	local info = if world ~= nil then (world :: WorldBuilder.World).areas[destination] else nil
	if area == nil or info == nil then
		return nil, "Unknown place"
	end
	if Economy.tier(profile) < area.tier then
		return nil, string.format("%s opens at Tier %d", area.name, area.tier)
	end
	return info.arrival, nil
end

local function onTravel(player: Player, rawDestination: unknown)
	local destination = Guard.id(rawDestination)
	if destination == nil then
		return
	end
	local last = lastTravel[player]
	if last ~= nil and os.clock() - last < Config.TravelCooldownSeconds then
		Net.fire(player, "TravelResult", destination, false, "Catch your breath first")
		return
	end
	local landing, reason = landingFor(player, destination)
	if landing == nil then
		Net.fire(player, "TravelResult", destination, false, reason)
		Net.toast(player, reason or "You can't go there", "warn")
		return
	end
	local busy = CatService.busyReason(player)
	if busy ~= nil then
		Net.fire(player, "TravelResult", destination, false, busy)
		Net.toast(player, busy, "warn")
		return
	end
	local character = player.Character
	if character == nil or character:FindFirstChild("HumanoidRootPart") == nil then
		Net.fire(player, "TravelResult", destination, false, "Still loading")
		return
	end
	character:PivotTo(landing :: CFrame)
	lastTravel[player] = os.clock()
	Net.fire(player, "TravelResult", destination, true, nil)
	Telemetry.custom(player, "travel", 1, { destination }) -- "home" or an area id: landingFor allowed it
end

function TravelService.start(builtWorld: WorldBuilder.World)
	world = builtWorld
	Net.on("Travel", onTravel)
	-- The Square's manhole is a fast travel button in the world: the same checks, cooldown and answer.
	local manhole = builtWorld.manhole
	local prompt = if manhole ~= nil then manhole:FindFirstChild("ManholePrompt", true) else nil
	if manhole ~= nil and prompt ~= nil and prompt:IsA("ProximityPrompt") then
		local area = manhole:GetAttribute("Area")
		prompt.Triggered:Connect(function(player: Player)
			onTravel(player, area)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastTravel[player] = nil
	end)
end

return TravelService
