--!strict
-- The session recap (#1920, first-hour.md section 6): once a second, a loaded player who has played
-- Config.RecapAfterSeconds this session with the sessionRecap setting on is sent SessionRecap(view) once. The
-- session starts when the profile is first seen loaded and ends on leave; a rejoin is a new session.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net)
local SessionRecap = require(ReplicatedStorage.Shared.SessionRecap)

local SessionRecapService = {}

local CHECK_SECONDS = 1

local starts: { [Player]: SessionRecap.Start } = {}

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
		Net.fire(player, "SessionRecap", SessionRecap.view(start, profile, now))
		return true
	end
	return false
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
