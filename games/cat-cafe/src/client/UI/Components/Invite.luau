--!strict
-- Roblox's invite window with this player's name in it (F92, playing-together.md section 5): the HUD's Invite tile
-- and the one invite ask call `Invite.prompt()`. The invite carries `ExperienceInviteOptions.LaunchData` from shared
-- Pals.inviteData ("pal:<userId>"), so whoever joins through it spawns at this player's front door and counts as a
-- pal. Nothing is sent to the game's server: Roblox runs the window, and the join reads the launch data.
--
-- Roblox terms: SocialService:PromptGameInvite opens Roblox's own invite-friends window; CanSendGameInviteAsync says
-- whether this player may send invites at all (some accounts cannot), and it yields, so the prompt runs in its own
-- thread.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Pals = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pals")) :: any

local Invite = {}

local busy = false -- one window at a time, however often the button is pressed

function Invite.prompt()
	if busy then
		return
	end
	busy = true
	task.spawn(function()
		local player = Players.LocalPlayer
		local ok, canInvite = pcall(function()
			return SocialService:CanSendGameInviteAsync(player)
		end)
		if ok and canInvite then
			local sent = pcall(function()
				local options = Instance.new("ExperienceInviteOptions")
				options.LaunchData = Pals.inviteData(player.UserId)
				SocialService:PromptGameInvite(player, options)
			end)
			if not sent then
				-- the plain window still invites, and a friend who joins counts as a pal anyway
				pcall(function()
					SocialService:PromptGameInvite(player)
				end)
			end
		end
		busy = false
	end)
end

return Invite
