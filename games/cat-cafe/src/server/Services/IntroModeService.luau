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
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local IntroModeService = {}

IntroModeService.KEY = "introMode"
IntroModeService.WAIT_SECONDS = 2

local modes: { [Player]: string } = {}
local pending: { [Player]: boolean } = {}

-- #4074: GetValue warns "Config value not found for key" for a key the experience's config does not hold, and that was
-- every join (89 in the error report) while no Experiment holds introMode. So the server reads the experience-wide
-- config first, once at start and then every RECHECK_SECONDS, and reads players' own configs only while the key is
-- there: at most one such warning per server per check, and none once the Experiment is live.
IntroModeService.RECHECK_SECONDS = 3600
local keyLive = false

local function checkKey()
	local ok, value = pcall(function()
		local snapshot = (game:GetService("ConfigService") :: any):GetConfigAsync()
		return snapshot:GetValue(IntroModeService.KEY)
	end)
	keyLive = ok and value ~= nil
end

local function fetch(player: Player)
	if not keyLive then
		return -- no Experiment holds the key: every player has nil, the save's older split
	end
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

-- Review-QA: ConfigService does not load in the dev place file, so in Studio only a Workspace attribute
-- IntroModeTest ("full", "short" or "none") stands in for the Experiment's arm, and the save joins the test even when
-- it is not new (Telemetry.introJoin). Never read on a live server.
IntroModeService.TEST_ATTRIBUTE = "IntroModeTest"

function IntroModeService.studioMode(): string?
	if not RunService:IsStudio() then
		return nil
	end
	local value = Workspace:GetAttribute(IntroModeService.TEST_ATTRIBUTE)
	return if type(value) == "string" then value else nil
end

function IntroModeService.start()
	checkKey()
	task.spawn(function()
		while true do
			task.wait(IntroModeService.RECHECK_SECONDS)
			checkKey()
		end
	end)
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
