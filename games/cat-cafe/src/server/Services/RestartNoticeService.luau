--!strict
-- The restart warning on this server (shared/RestartNotice; decisions.md 2026-11-01). Subscribes to MessagingService
-- topic RestartNotice.TOPIC, which only the Open Cloud key can publish to (restart-countdown.sh, run by publish.yml
-- and restart-servers.yml), and shows every player in the server RestartNotice.text as a warning toast. A player who
-- joins while a restart is coming is told how long is left once their profile loads. A subscribe that fails (a
-- Studio place that was never published) is tried three times, then left with one warning in the log: nothing else
-- depends on it.
-- #2720: only the marks RestartNotice.shows are shown (the others still set when the restart comes), as
-- RestartNotice.kind, and each player shown one is told to Telemetry.restartWarned (left_after_restart_warning).

local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net)
local RestartNotice = require(ReplicatedStorage.Shared.RestartNotice)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)

local RestartNoticeService = {}

local SUBSCRIBE_WAITS = { 5, 15 } -- seconds before the second and third tries

local restartAt: number? = nil -- os.clock() of the coming restart
local lastSeconds: number? = nil
local lastShownAt = -math.huge

local function decode(text: string): unknown
	return HttpService:JSONDecode(text)
end

-- Shows the warning to every player and remembers when the restart comes.
local function warnAll(seconds: number)
	local now = os.clock()
	if seconds == lastSeconds and now - lastShownAt < RestartNotice.REPEAT_SECONDS then
		return
	end
	lastSeconds, lastShownAt = seconds, now
	restartAt = now + seconds
	if not RestartNotice.shows(seconds) then
		return
	end
	local text = RestartNotice.text(seconds, os.time())
	local kind: Types.ToastKind = RestartNotice.kind(seconds)
	for _, player in Players:GetPlayers() do
		Net.toast(player, text, kind)
		Telemetry.restartWarned(player, seconds)
	end
end

local function onMessage(message: any)
	local data = if type(message) == "table" then message.Data else nil
	local seconds = RestartNotice.parse(data, decode)
	if seconds ~= nil then
		warnAll(seconds)
	end
end

function RestartNoticeService.start()
	DataService.onLoaded:Connect(function(player: Player)
		local at = restartAt
		local left = if at ~= nil then at - os.clock() else 0
		if left > 0 then
			Net.toast(player, RestartNotice.text(left, os.time()), RestartNotice.kind(left))
			Telemetry.restartWarned(player, left)
		end
	end)
	task.spawn(function()
		local lastError = ""
		for attempt = 1, #SUBSCRIBE_WAITS + 1 do
			local ok, err = pcall(function()
				MessagingService:SubscribeAsync(RestartNotice.TOPIC, onMessage)
			end)
			if ok then
				return
			end
			lastError = tostring(err)
			local wait = SUBSCRIBE_WAITS[attempt]
			if wait ~= nil then
				task.wait(wait)
			end
		end
		warn("[RestartNotice] no restart warnings on this server: " .. lastError)
	end)
end

-- Studio-only test hook (Debug.restartNotice): a restart warning as if the countdown sent `seconds`, through the
-- same parse and toasts. Returns the text shown, or nil when the message would be ignored or is a mark not shown (#2720).
function RestartNoticeService.debugNotice(seconds: unknown): string?
	local parsed = RestartNotice.parse({ kind = "restart", seconds = seconds }, decode)
	if parsed == nil then
		return nil
	end
	lastSeconds = nil
	warnAll(parsed)
	return if RestartNotice.shows(parsed) then RestartNotice.text(parsed) else nil
end

return RestartNoticeService
