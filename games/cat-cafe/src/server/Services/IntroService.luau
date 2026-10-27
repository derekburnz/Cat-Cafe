--!strict
-- The intro cutscene's server half (F72, docs/design/cat-cafe/intro-cutscene.md sections 1 and 3). A player whose
-- profile has not seen the intro lands just inside its own cafe's back door, facing it (Layout.plot.introSpot), when
-- the profile loads and on every spawn until then, so the fly-through ends where the first stray waits behind the
-- yard. The client freezes the character while the intro runs, so the move is never seen. IntroDone(shot, replay)
-- marks the intro seen on the first play and logs intro_cutscene (finished or skipped, the shot, first or replay)
-- for the growth thread. Replays move nobody and save nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CafeService = require(script.Parent.CafeService)
local DataService = require(script.Parent.DataService)
local Guard = require(script.Parent.Parent.Util.Guard)
local Intro = require(ReplicatedStorage.Shared.Intro)
local Layout = require(script.Parent.Parent.World.Layout)
local Net = require(script.Parent.Net)
local PlotService = require(script.Parent.PlotService)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)

local IntroService = {}

-- A replay can be sent once a second for a whole session; past this many events a player's log stops.
local MAX_EVENTS = 20
local events: { [Player]: number } = {}

-- Where a player who has not seen the intro stands: just inside its own back door, facing it (plot space: -Z faces
-- the street, so the back wall is toward +Z). Nil without a plot.
function IntroService.landing(player: Player): CFrame?
	local plot = PlotService.get(player)
	if plot == nil then
		return nil
	end
	local spot = Layout.plot.introSpot
	return plot.cframe * CFrame.new(spot.x, spot.y, spot.z) * CFrame.Angles(0, math.pi, 0)
end

-- Moves the character to the landing when the profile has not seen the intro. The spawn itself places the
-- character first, so this waits for the root and one more frame.
local function land(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root == nil then
		return
	end
	RunService.Heartbeat:Wait()
	local profile = DataService.get(player)
	local landing = IntroService.landing(player)
	if
		profile == nil
		or profile.introSeen
		or landing == nil
		or player.Character ~= character
		or character.Parent == nil
	then
		return
	end
	character:PivotTo(landing)
end

local function onLoaded(player: Player, profile: Types.PlayerProfile)
	-- deferred, so CafeService's own onLoaded has given the player a plot first
	task.defer(function()
		local character = player.Character
		if not profile.introSeen and character ~= nil then
			land(player, character)
		end
	end)
end

local function onIntroDone(player: Player, rawShot: unknown, rawReplay: unknown)
	local shot = Guard.int(rawShot, 0, Intro.SHOTS)
	local replay = Guard.bool(rawReplay)
	local profile = DataService.get(player)
	if shot == nil or replay == nil or profile == nil then
		return
	end
	if not replay and not profile.introSeen then
		profile.introSeen = true
		CafeService.sync(player)
	end
	local count = (events[player] or 0) + 1
	if count <= MAX_EVENTS then
		events[player] = count
		Telemetry.custom(player, "intro_cutscene", 1, {
			if shot == 0 then "finished" else "skipped",
			tostring(shot),
			if replay then "replay" else "first",
		})
	end
end

function IntroService.start()
	DataService.onLoaded:Connect(onLoaded)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			local profile = DataService.get(player)
			if profile ~= nil and not profile.introSeen then
				land(player, character)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		events[player] = nil
	end)
	Net.on("IntroDone", onIntroDone)
end

return IntroService
