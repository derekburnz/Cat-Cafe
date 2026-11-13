--!strict
-- #4005: a new player's quiet start (shared/QuietStart). At load the player gets the QuietUntil attribute, the server
-- time their account's first QuietStart.SECONDS of play end; past them there is none. The switch (`quietStart`) is
-- read when a pop up goes out, so turning it off lets every pop up through at once.
--   start()                          sets the attributes on every load (and QuietFirstDay, for the Daily Treat)
--   quiet(player) -> boolean         the switch is on and the player is still in their quiet start
--   fireAll(actor, name, ...)        Net.fireAll for other players' pop ups: everyone but quiet players gets it, and
--                                    the actor (whose own moment it is, nil for none) always does

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DataService = require(script.Parent.DataService)
local LiveFlagService = require(script.Parent.LiveFlagService)
local Net = require(script.Parent.Net)
local QuietStart = require(ReplicatedStorage.Shared.QuietStart)

local QuietStartService = {}

function QuietStartService.quiet(player: Player): boolean
	return QuietStart.quiet(
		LiveFlagService.on(QuietStart.FLAG),
		player:GetAttribute(QuietStart.ATTRIBUTE),
		Workspace:GetServerTimeNow()
	)
end

function QuietStartService.fireAll(actor: Player?, name: string, ...: any)
	if not LiveFlagService.on(QuietStart.FLAG) then
		Net.fireAll(name, ...)
		return
	end
	for _, player in Players:GetPlayers() do
		if player == actor or not QuietStartService.quiet(player) then
			Net.fire(player, name, ...)
		end
	end
end

function QuietStartService.start()
	DataService.onLoaded:Connect(function(player: Player, profile)
		local untilAt =
			QuietStart.untilAt(Workspace:GetServerTimeNow(), profile.stats.playtimeSeconds)
		player:SetAttribute(QuietStart.ATTRIBUTE, untilAt)
		player:SetAttribute(QuietStart.DAY_ATTRIBUTE, profile.telemetry.firstDay)
	end)
end

return QuietStartService
