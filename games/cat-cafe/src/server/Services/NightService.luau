--!strict
-- The short night (data-model section 9, v0.9, F66). ClockService keeps the time and sets the Clock folder's
-- AreasOpen, which closes the fences on the clients; this service does the closing and opening on the server. At
-- dusk every stray and rescue trap clears (CatService, RescueService) and anyone standing in a catching area is sent
-- home, then again every NightSweepSeconds, a carried cat checked in on arrival. A player mid catch or rescue
-- finishes it first. At sunrise each area gets its wave and its traps. The dusk warning and sunrise banners and the
-- dusk bell are the client's own, from the Clock attributes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CatService = require(script.Parent.CatService)
local Clock = require(ReplicatedStorage.Shared.Clock)
local ClockService = require(script.Parent.ClockService)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(script.Parent.Net)
local RescueService = require(script.Parent.RescueService)
local TravelService = require(script.Parent.TravelService)
local Types = require(ReplicatedStorage.Shared.Types)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local NightService = {}

local world: WorldBuilder.World
local nightNumber = 0 -- each night's sweep loop stops when a newer phase starts

-- The catching area the player's character stands in, or nil.
local function areaOf(player: Player): string?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	return WorldBuilder.areaAt(world, (root :: BasePart).Position)
end

-- Everyone in a catching area goes home, unless their catch or rescue is still running; the next sweep gets them.
local function sweep()
	for _, player in Players:GetPlayers() do
		if areaOf(player) == nil or CatService.inMinigame(player) then
			continue
		end
		if TravelService.sendHome(player) then
			Net.toast(player, Clock.SENT_HOME_TEXT, "info")
			CatService.forceCheckIn(player)
		end
	end
end

local function nightFalls()
	nightNumber += 1
	local night = nightNumber
	CatService.nightFalls()
	RescueService.nightFalls()
	task.spawn(function()
		while nightNumber == night and not ClockService.areasOpen() do
			sweep()
			task.wait(Config.NightSweepSeconds)
		end
	end)
end

local function sunrise()
	nightNumber += 1
	CatService.sunriseWave()
	RescueService.sunrise()
end

local function onPhase(phase: Types.ClockPhase)
	if phase == "night" then
		nightFalls()
	else
		sunrise()
	end
end

-- After CatService, RescueService and TravelService.
function NightService.start(builtWorld: WorldBuilder.World)
	world = builtWorld
	ClockService.changed:Connect(onPhase)
	-- ClockService published the first phase before this connected; a new server opens at sunrise (ServerStartDaySeconds)
	if ClockService.areasOpen() then
		sunrise()
	else
		nightFalls()
	end
end

return NightService
