--!strict
-- #4001 (Derek 2026-11-13: the short intro and its 50/50 test, a priority): the intro arm a Creator Hub Experiment
-- puts a player in, read as the `introMode` value of the player's own config (Roblox ConfigService) as they join:
-- "full" plays today's intro, "short" the short one (shared/Intro.SHORT_CAPTIONS) and "none" no scene. A player outside any
-- experiment, a failed read or another value gives nil, and the save keeps the older split (shared/IntroSplit).
-- Only new saves read it in the end (Telemetry.introJoin waits for it then, never longer than WAIT_SECONDS).
--
-- Roblox terms: ConfigService:GetConfigForPlayerAsync(player) yields and gives a ConfigSnapshot of the experience's
-- config values with the player's experiment arm applied; GetValue(key) reads one.

local Players = game:GetService("Players")

local IntroModeService = {}

IntroModeService.KEY = "introMode"
IntroModeService.WAIT_SECONDS = 2

local modes: { [Player]: string } = {}
local pending: { [Player]: boolean } = {}

local function fetch(player: Player)
	pending[player] = true
	local ok, value = pcall(function()
		local snapshot = (game:GetService("ConfigService") :: any):GetConfigForPlayerAsync(player)
		return snapshot:GetValue(IntroModeService.KEY)
	end)
	pending[player] = nil
	if ok and type(value) == "string" and player.Parent ~= nil then
		modes[player] = value
	end
end

-- The player's introMode value ("short", "none" or whatever the config says), or nil. Waits up to WAIT_SECONDS for a
-- read still on its way.
function IntroModeService.get(player: Player): string?
	local waited = 0
	while pending[player] and waited < IntroModeService.WAIT_SECONDS do
		waited += task.wait(0.1)
	end
	return modes[player]
end

function IntroModeService.start()
	Players.PlayerAdded:Connect(fetch)
	for _, player in Players:GetPlayers() do
		task.spawn(fetch, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		modes[player] = nil
		pending[player] = nil
	end)
end

return IntroModeService
