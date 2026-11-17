--!strict
-- Destroys old characters and Players who left (shared/LeaveCleanup), behind the leaveCleanup switch.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LeaveCleanup = require(ReplicatedStorage.Shared.LeaveCleanup)
local LiveFlagService = require(script.Parent.LiveFlagService)

local LeaveCleanupService = {}

local function on(): boolean
	return LiveFlagService.on(LeaveCleanup.FLAG)
end

local function destroyCharacterLater(player: Player, character: Model)
	task.delay(LeaveCleanup.CHARACTER_SECONDS, function()
		if on() and LeaveCleanup.characterGone(character.Parent, player.Character == character) then
			character:Destroy()
		end
	end)
end

local function watch(player: Player)
	player.CharacterRemoving:Connect(function(character: Model)
		destroyCharacterLater(player, character)
	end)
end

function LeaveCleanupService.start()
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		local character = player.Character
		if character ~= nil then
			destroyCharacterLater(player, character)
		end
		task.delay(LeaveCleanup.PLAYER_SECONDS, function()
			if on() and player.Parent == nil then
				player:Destroy()
			end
		end)
	end)
end

return LeaveCleanupService
