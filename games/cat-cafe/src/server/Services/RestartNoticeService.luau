--!strict
-- The restart warning on this server (shared/RestartNotice; decisions.md 2026-11-01). Subscribes to MessagingService
-- topic RestartNotice.TOPIC, which only the Open Cloud key can publish to (restart-countdown.sh, run by publish.yml
-- and restart-servers.yml), and shows every player in the server RestartNotice.text as a warning toast. A player who
-- joins while a restart is coming is told how long is left once their profile loads. A subscribe that fails (a
-- Studio place that was never published) is tried three times, then left with one warning in the log: nothing else
-- depends on it.

local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net)
local RestartNotice = require(ReplicatedStorage.Shared.RestartNotice)

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
	local text = RestartNotice.text(seconds)
	for _, player in Players:GetPlayers() do
		Net.toast(player, text, "warn")
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
		if at ~= nil and at - os.clock() > 0 then
			Net.toast(player, RestartNotice.text(at - os.clock()), "warn")
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
-- same parse and toasts. Returns the text shown, or nil when the message would be ignored.
function RestartNoticeService.debugNotice(seconds: unknown): string?
	local parsed = RestartNotice.parse({ kind = "restart", seconds = seconds }, decode)
	if parsed == nil then
		return nil
	end
	lastSeconds = nil
	warnAll(parsed)
	return RestartNotice.text(parsed)
end

return RestartNoticeService
