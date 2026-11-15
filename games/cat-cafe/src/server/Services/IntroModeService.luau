--!strict
-- #4001 (Derek 2026-11-13: the short intro and its 50/50 test, a priority): the intro arm a Creator Hub Experiment
-- puts a player in, read as the `introMode` value of the player's own config (Roblox ConfigService) as they join:
-- "full" plays today's intro, "short" the short one (shared/Intro.SHORT_CAPTIONS) and "none" no scene. A player outside any
-- experiment, a failed read or another value gives nil, and the save keeps the older split (shared/IntroSplit).
-- Only new saves read it in the end (Telemetry.introJoin waits for it then, never longer than WAIT_SECONDS).
-- #4314: since the short intro went to every save (#4252) introMode is no longer read; the same read now takes the
-- loading screen test's arm (loadingArm).
--
-- Roblox terms: ConfigService:GetConfigForPlayerAsync(player) yields and gives a ConfigSnapshot of the experience's
-- config values with the player's experiment arm applied; GetValue(key) reads one.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local IntroModeService = {}

IntroModeService.KEY = "introMode"
IntroModeService.WAIT_SECONDS = 2

-- #4314: the loading screen test's arm (shared/LoadingTest.KEY), read from the same config snapshot
local LOADING_KEY = "loadingScreenArm"
local loadingArms: { [Player]: string } = {}
local pending: { [Player]: boolean } = {}

-- #4074: GetValue warns "Config value not found for key" for a key the player's config does not hold, and that was
-- every join (89 in the error report) while no Experiment holds introMode. So while no read has found the key, only
-- one join per RECHECK_SECONDS is read (a probe, at most one warning per server per hour) and the rest get nil. Once a
-- read finds it (the Experiment is live, through its arms or a base value), every join is read again. The probe is a
-- per-player read on purpose: an Experiment may set the key only in its arms, which the experience-wide config lacks.
IntroModeService.RECHECK_SECONDS = 3600
local keyLive = false
local nextProbeAt = 0

local function fetch(player: Player)
	if not keyLive then
		local now = os.clock()
		if now < nextProbeAt then
			return -- no read has found the key yet: nil, the save's older split
		end
		nextProbeAt = now + IntroModeService.RECHECK_SECONDS -- set before the yield, so only one probe runs
	end
	pending[player] = true
	local ok, value = pcall(function()
		local snapshot = (game:GetService("ConfigService") :: any):GetConfigForPlayerAsync(player)
		-- #4314: only the loading test's key. introMode is no longer read (the short intro is for every save since
		-- #4252), and a second key no Experiment holds would warn on every join once this one is live (#4074).
		return snapshot:GetValue(LOADING_KEY)
	end)
	pending[player] = nil
	if ok and value ~= nil then
		keyLive = true
	end
	if ok and type(value) == "string" and player.Parent ~= nil then
		loadingArms[player] = value
	end
end

-- #4314: the player's loadingScreenArm value, or nil, waiting the same way. In Studio a Workspace attribute
-- LoadingArmTest stands in for it.
function IntroModeService.loadingArm(player: Player): string?
	if RunService:IsStudio() then
		local test = Workspace:GetAttribute("LoadingArmTest")
		if type(test) == "string" then
			return test
		end
	end
	local waited = 0
	while pending[player] and waited < IntroModeService.WAIT_SECONDS do
		waited += task.wait(0.1)
	end
	return loadingArms[player]
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
	Players.PlayerAdded:Connect(fetch)
	for _, player in Players:GetPlayers() do
		task.spawn(fetch, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		loadingArms[player] = nil
		pending[player] = nil
	end)
end

return IntroModeService
