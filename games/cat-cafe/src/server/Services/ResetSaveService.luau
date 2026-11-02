--!strict
-- A tester's "Reset my save" (Derek's 10-28 to 10-30 notes: "reset character (wipe save) option for testing"), so a
-- tester can play the new player's path again on the live game. Only testers see or use it: in Studio anyone; live,
-- the experience's owner (the creator of a user-owned game, rank ResetSaveGroupRank or higher in the owning group
-- once the game moves to a group). No user id is written anywhere: the check reads game.CreatorType and CreatorId.
-- The Player attribute Tester tells the UI to show the Settings row. ResetSave() is refused mid flight, carry, catch
-- or rescue (CatService.busyReason); otherwise DataService saves a fresh save in place of this one as the session
-- ends, after every leave hook has run on the old one, and the player is kicked with a note to join again, so every
-- service lets go of the old state the normal way.
--
-- Roblox terms: Player:Kick ends the player's session with a message on their screen; GetRankInGroup asks Roblox
-- for the player's rank (0 to 255, 255 the group's owner) and can fail, so it runs in pcall.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CatService = require(script.Parent.CatService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net)

local ResetSaveService = {}

ResetSaveService.KICK_TEXT = "Your save was reset for testing. Join again to start fresh."

local testers: { [Player]: boolean } = {}

-- Whether `player` may reset their save; asks Roblox for a group rank, so it can yield.
local function checkTester(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, rank = pcall(function(): number
		return player:GetRankInGroup(game.CreatorId)
	end)
	return ok and type(rank) == "number" and rank >= Config.ResetSaveGroupRank
end

local function onJoin(player: Player)
	local tester = checkTester(player)
	if player.Parent == nil then
		return
	end
	testers[player] = tester
	player:SetAttribute("Tester", tester)
end

local function onResetSave(player: Player)
	if not testers[player] then
		return -- not a tester, or the check has not answered yet: the row is not shown either
	end
	if DataService.get(player) == nil then
		return -- still loading
	end
	local busy = CatService.busyReason(player)
	if busy ~= nil then
		Net.toast(player, busy, "warn")
		return
	end
	DataService.resetOnLeave(player)
	player:Kick(ResetSaveService.KICK_TEXT)
end

function ResetSaveService.isTester(player: Player): boolean
	return testers[player] == true
end

function ResetSaveService.start()
	Players.PlayerAdded:Connect(onJoin)
	for _, player in Players:GetPlayers() do
		task.spawn(onJoin, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		testers[player] = nil
	end)
	Net.on("ResetSave", onResetSave)
end

return ResetSaveService
