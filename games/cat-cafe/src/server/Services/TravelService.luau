--!strict
-- Fast travel (features F19; v4, F84, hometown-cannon.md section 5): the HUD's Home and Cannon buttons fire
-- Travel(destination). "home" goes to the player's front door from anywhere, as a cloud hop from a wild area;
-- "cannon" goes at once to the front of the nearest Cat Cannon, facing it: the Town Square's in town, the camp's in
-- a wild area. Area travel is by cannon only (CannonService). The server checks the player is not carrying a cat,
-- mid catch or rescue (leaving would be a Miss, reviewer N47), in a flight or knocked down by a tackle (the same
-- TackledDownSeconds refusal as the cannon, N281), and that TravelCooldownSeconds have passed. Every answer goes back as TravelResult. At night NightService sends anyone in a wild area home with
-- sendHome, the same cloud hop.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Cannon = require(ReplicatedStorage.Shared.Cannon)
local CatService = require(script.Parent.CatService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Guard = require(script.Parent.Parent.Util.Guard)
local Layout = require(script.Parent.Parent.World.Layout)
local Net = require(script.Parent.Net)
local PlotService = require(script.Parent.PlotService)
local Telemetry = require(script.Parent.Telemetry)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local TravelService = {}

local HOME_STEP_OUT = 6 -- studs out from the front door, on the street

local world: WorldBuilder.World? = nil
local lastTravel: { [Player]: number } = {}

-- On the street outside the player's front door, facing it; nil without a cafe.
local function homeLanding(player: Player): CFrame?
	local plot = PlotService.get(player)
	if plot == nil then
		return nil
	end
	-- plot space: -Z faces the street, so the street side of the door is further along -Z
	local door = plot.door.Position
	local doorLocal = plot.cframe:PointToObjectSpace(door)
	local outside =
		plot.cframe:PointToWorldSpace(Vector3.new(doorLocal.X, 3, doorLocal.Z - HOME_STEP_OUT))
	return CFrame.lookAt(outside, Vector3.new(door.X, outside.Y, door.Z))
end

-- The wild area the player's character stands in (its camp included), or nil in the hometown.
local function wildAreaOf(player: Player): string?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if world == nil or root == nil or not root:IsA("BasePart") then
		return nil
	end
	return WorldBuilder.areaAt(world :: WorldBuilder.World, (root :: BasePart).Position)
end

-- In front of the nearest cannon, facing it (section 5): the town's, or the camp cannon of the wild area `areaId`.
local function cannonFront(areaId: string?): CFrame?
	local id = if areaId ~= nil and Layout.cannonFronts[areaId] ~= nil then areaId else "town"
	local front, cannon = Layout.cannonFronts[id], Layout.cannons[id]
	if front == nil or cannon == nil then
		return nil
	end
	local at = Vector3.new(front.x, front.y + 3, front.z)
	return CFrame.lookAt(at, Vector3.new(cannon.x, at.Y, cannon.z))
end

-- Where `destination` puts this player, or nil and the reason it is refused.
local function landingFor(player: Player, destination: string): (CFrame?, string?)
	local profile = DataService.get(player)
	if profile == nil then
		return nil, "Still loading"
	end
	if destination == "home" then
		local home = homeLanding(player)
		return home, if home == nil then "You have no cafe yet" else nil
	end
	if destination == "cannon" then
		local front = cannonFront(wildAreaOf(player))
		return front, if front == nil then "Still loading" else nil
	end
	if Catalog.getArea(destination) ~= nil or destination == "alley" then
		return nil, "Hop in the Cat Cannon to fly there"
	end
	return nil, "Unknown place"
end

-- A cloud hop (section 5): CloudHopAt (server time) and CloudHopTo ("home") on the character for CloudHopSeconds,
-- so every client plays the clouds, with the move to `landing` at CloudHopMoveAtSeconds and `arrived` after it.
-- Nothing happens if the character is gone or replaced by then.
local function cloudHop(player: Player, landing: CFrame, arrived: (() -> ())?)
	local character = player.Character
	if character == nil then
		return
	end
	local startedAt = Workspace:GetServerTimeNow()
	character:SetAttribute("CloudHopAt", startedAt)
	character:SetAttribute("CloudHopTo", "home")
	local function current(): boolean
		return player.Character == character
			and character.Parent ~= nil
			and character:GetAttribute("CloudHopAt") == startedAt
	end
	task.delay(Config.CloudHopMoveAtSeconds, function()
		if current() then
			character:PivotTo(landing)
			if arrived ~= nil then
				arrived()
			end
		end
	end)
	task.delay(Config.CloudHopSeconds, function()
		if current() then
			character:SetAttribute("CloudHopAt", nil)
			character:SetAttribute("CloudHopTo", nil)
		end
	end)
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
	-- ShovedAt is the server time a tackle last hit this character (ShoveService, server set)
	local shovedAt = character:GetAttribute("ShovedAt")
	local down = Cannon.downRefusal(
		if type(shovedAt) == "number" then Workspace:GetServerTimeNow() - shovedAt else nil
	)
	if down ~= nil then
		Net.fire(player, "TravelResult", destination, false, down)
		Net.toast(player, down, "warn")
		return
	end
	lastTravel[player] = os.clock()
	if destination == "home" and wildAreaOf(player) ~= nil then
		cloudHop(player, landing :: CFrame)
	else
		character:PivotTo(landing :: CFrame)
	end
	Net.fire(player, "TravelResult", destination, true, nil)
	Telemetry.custom(player, "travel", 1, { destination }) -- "home" or "cannon": landingFor allowed it
end

function TravelService.start(builtWorld: WorldBuilder.World)
	world = builtWorld
	Net.on("Travel", onTravel)
	Players.PlayerRemoving:Connect(function(player)
		lastTravel[player] = nil
	end)
end

-- Night's sweep (v0.9, F66; v4, F84): the same move as Travel("home"), a cloud hop from a wild area, or to the
-- street spawn without a cafe; `arrived` runs once the character is there. No cooldown and no busy check, since
-- NightService waits for a catch or rescue to end and skips flights. False when there is no character.
function TravelService.sendHome(player: Player, arrived: (() -> ())?): boolean
	local character = player.Character
	if character == nil or character:FindFirstChild("HumanoidRootPart") == nil then
		return false
	end
	local spawn = Layout.playerSpawn
	local landing = homeLanding(player) or CFrame.new(spawn.x, spawn.y + 3, spawn.z)
	Net.fire(player, "TravelResult", "home", true, nil)
	if wildAreaOf(player) ~= nil then
		cloudHop(player, landing, arrived)
	else
		character:PivotTo(landing)
		if arrived ~= nil then
			arrived()
		end
	end
	return true
end

return TravelService
