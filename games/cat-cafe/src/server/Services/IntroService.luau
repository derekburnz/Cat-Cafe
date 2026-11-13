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

-- #3773: the most seconds an intro_skip reports; a longer number is a paused or stuck client, so it is dropped
local SKIP_SECONDS_MAX = 600

local function onIntroDone(
	player: Player,
	rawShot: unknown,
	rawReplay: unknown,
	rawSeconds: unknown
)
	local shot = Guard.int(rawShot, 0, Intro.SHOTS)
	local replay = Guard.bool(rawReplay)
	local profile = DataService.get(player)
	if shot == nil or replay == nil or profile == nil then
		return
	end
	local firstSeen = not replay and not profile.introSeen
	local version = if replay or Telemetry.introShort(profile)
		then Intro.SHORT_VERSION
		else Intro.VERSION
	if firstSeen then
		profile.introSeen = true
		CafeService.sync(player)
	end
	-- #2495: the tackling lesson is the intro's last steps on the client (IntroController), saved by its TipSeen;
	-- since #2544 nothing else sends it, so nothing is sent from here
	local count = (events[player] or 0) + 1
	if count <= MAX_EVENTS then
		events[player] = count
		-- the shot carries the intro's version, "3:4", since the shots moved (intro-cutscene.md section 3); #4001:
		-- the short intro (every replay, and a first play in the test's "short" arm) is Intro.SHORT_VERSION
		Telemetry.custom(player, "intro_cutscene", 1, {
			if shot == 0 then "finished" else "skipped",
			tostring(version) .. ":" .. tostring(shot),
			if replay then "replay" else "first",
		})
	end
	-- #3773: how long a first play ran before Skip, once a save (introSeen is set just above)
	local seconds = Guard.int(rawSeconds, 0, SKIP_SECONDS_MAX)
	if firstSeen and shot ~= 0 and seconds ~= nil then
		Telemetry.custom(player, "intro_skip", seconds, {
			tostring(version) .. ":" .. tostring(shot),
			Telemetry.device(player) or "unknown",
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
