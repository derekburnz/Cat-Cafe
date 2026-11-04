--!strict
-- The intro cutscene's server half (F72, docs/design/cat-cafe/intro-cutscene.md sections 1 and 3). IntroDone(shot,
-- replay) marks the intro seen on the first play and logs intro_cutscene (finished or skipped, the intro's version
-- and the shot, first or replay) for the growth thread; one played out is the intro funnel's intro_done (#1273).
-- Replays save nothing. Since the reshoot for the hometown and the cannon (F84, version 3) the intro starts and ends
-- at the hometown spawn, so nothing here moves anyone; where a respawn lands is CannonService's.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CafeService = require(script.Parent.CafeService)
local DataService = require(script.Parent.DataService)
local Guard = require(script.Parent.Parent.Util.Guard)
local Intro = require(ReplicatedStorage.Shared.Intro)
local Net = require(script.Parent.Net)
local Telemetry = require(script.Parent.Telemetry)

local IntroService = {}

-- A replay can be sent once a second for a whole session; past this many events a player's log stops.
local MAX_EVENTS = 20
local events: { [Player]: number } = {}

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
	-- #1273: the intro funnel's last step, once it played out (a skip's shot is in intro_cutscene below)
	if shot == 0 then
		Telemetry.intro(player, profile, "intro_done")
	end
	local count = (events[player] or 0) + 1
	if count <= MAX_EVENTS then
		events[player] = count
		-- the shot carries the intro's version, "3:4", since the shots moved (intro-cutscene.md section 3)
		Telemetry.custom(player, "intro_cutscene", 1, {
			if shot == 0 then "finished" else "skipped",
			tostring(Intro.VERSION) .. ":" .. tostring(shot),
			if replay then "replay" else "first",
		})
	end
end

function IntroService.start()
	Players.PlayerRemoving:Connect(function(player)
		events[player] = nil
	end)
	Net.on("IntroDone", onIntroDone)
end

return IntroService
