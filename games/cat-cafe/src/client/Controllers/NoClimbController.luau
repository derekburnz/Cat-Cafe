--!strict
-- No climbing (#4073). Nothing in the game needs a climb, but a character resting against anything the engine reads
-- as a ladder (thin parts stacked 1 to 3 studs apart: a railing, a board on posts, a hedge's bumps) flips between
-- Climbing and standing many times a second. Roblox's default Animate script loads the climb and idle clips afresh on
-- every flip, which ran players into "AnimationTrack limit of 64 tracks exceeded" (212,952 warnings on 2026-11-13)
-- and made avatars jitter there. The models are being smoothed one by one; this stops the cause for every spot,
-- known or not, by switching the Climbing state off on this player's own character.
--
-- Roblox terms: a Humanoid is the part of a character that walks, jumps and climbs; each of those is a "state".
-- SetStateEnabled(state, false) keeps the Humanoid from ever entering that state. A player's own character is
-- simulated on their own device, so setting it here is what counts; it sends nothing to the server.

local Players = game:GetService("Players")

local NoClimbController = {}

local function apply(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid ~= nil and humanoid:IsA("Humanoid") then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	end
end

function NoClimbController.start()
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(function(character)
		apply(character)
	end)
	local character = player.Character
	if character ~= nil then
		task.spawn(apply, character)
	end
end

return NoClimbController
