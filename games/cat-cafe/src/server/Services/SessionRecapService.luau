--!strict
-- The session recap (#1920, first-hour.md section 6): once a second, a loaded player who has played
-- Config.RecapAfterSeconds this session with the sessionRecap setting on is sent SessionRecap(view) once. The
-- session starts when the profile is first seen loaded and ends on leave; a rejoin is a new session.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataService = require(script.Parent.DataService)
local LiveFlagService = require(script.Parent.LiveFlagService)
local Net = require(script.Parent.Net)
local ReturnGift = require(ReplicatedStorage.Shared.ReturnGift)
local SessionRecap = require(ReplicatedStorage.Shared.SessionRecap)

local SessionRecapService = {}

local CHECK_SECONDS = 1

local starts: { [Player]: SessionRecap.Start } = {}

-- #3772: whether the recap's Tomorrow line names the welcome back gift: the switch is on and it pays tomorrow
local function giftTomorrow(profile: any, now: number): boolean
	return LiveFlagService.on(ReturnGift.FLAG) and ReturnGift.waiting(profile, now)
end

-- true when the recap was sent this tick
local function check(player: Player): boolean
	local profile = DataService.get(player)
	if profile == nil then
		return false
	end
	local now = os.time()
	local start = starts[player]
	if start == nil then
		starts[player] = SessionRecap.start(profile, now)
		return false
	end
	if SessionRecap.due(start, now, profile.settings.sessionRecap ~= false) then
		start.sent = true
		Net.fire(
			player,
			"SessionRecap",
			SessionRecap.view(start, profile, now, giftTomorrow(profile, now))
		)
		return true
	end
	return false
end

-- Studio-only test hook (Desktop-Tester, #2243): sends this session's recap now, as if RecapAfterSeconds had passed,
-- whatever the setting says. The once-a-session send is marked, so the timed one does not come again. False when the
-- profile is not loaded.
function SessionRecapService.debugSendNow(player: Player): boolean
	assert(RunService:IsStudio(), "debugSendNow is Studio only")
	local profile = DataService.get(player)
	if profile == nil then
		return false
	end
	local now = os.time()
	local start = starts[player] or SessionRecap.start(profile, now - 60)
	starts[player] = start
	start.sent = true
	Net.fire(
		player,
		"SessionRecap",
		SessionRecap.view(start, profile, now, giftTomorrow(profile, now))
	)
	return true
end

function SessionRecapService.start()
	Players.PlayerRemoving:Connect(function(player: Player)
		starts[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			for _, player in DataService.loadedPlayers() do
				local ok, err = pcall(check, player)
				if not ok then
					warn("[SessionRecapService] " .. tostring(err))
				end
			end
		end
	end)
end

return SessionRecapService
