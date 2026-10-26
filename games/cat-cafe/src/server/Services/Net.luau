--!strict
-- Owns the RemoteEvents. Creates them from the shared list, rate limits every client -> server call,
-- and gives services typed-ish helpers to fire. Handlers get already rate-limited calls; they still validate args.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local Net = {}

local events: { [string]: RemoteEvent } = {}
local defaultLimiter = RateLimiter.new(Config.RemoteRateLimitPerSecond, 1)
local grabLimiter = RateLimiter.new(1, Config.GrabRateLimitSeconds)
local overLimitLog: { [number]: number } = {} -- userId -> last warn time

local function limiterFor(name: string)
	if name == "GrabBegin" then
		return grabLimiter
	end
	return defaultLimiter
end

function Net.start()
	local folder = ReplicatedStorage:FindFirstChild(Remotes.FolderName)
	if folder == nil then
		local created = Instance.new("Folder")
		created.Name = Remotes.FolderName
		created.Parent = ReplicatedStorage
		folder = created
	end
	for _, list in { Remotes.ClientToServer, Remotes.ServerToClient } do
		for _, name in list do
			local existing = (folder :: Folder):FindFirstChild(name)
			if existing == nil then
				local event = Instance.new("RemoteEvent")
				event.Name = name
				event.Parent = folder
				existing = event
			end
			events[name] = existing :: RemoteEvent
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		for name in events do
			defaultLimiter:forget(tostring(player.UserId) .. name)
		end
		grabLimiter:forget(player.UserId)
		overLimitLog[player.UserId] = nil
	end)
end

-- Connects a client -> server handler behind the rate limiter. Over the limit: dropped silently, logged once a second.
function Net.on(name: string, handler: (player: Player, ...any) -> ())
	local event = events[name]
	if event == nil then
		error("[Net] unknown remote " .. name)
	end
	event.OnServerEvent:Connect(function(player: Player, ...: any)
		local limiter = limiterFor(name)
		local key = if name == "GrabBegin" then player.UserId else tostring(player.UserId) .. name
		if not limiter:allow(key) then
			local now = os.clock()
			if (overLimitLog[player.UserId] or 0) + 1 < now then
				overLimitLog[player.UserId] = now
				warn(string.format("[Net] rate limit hit: user %d on %s", player.UserId, name))
			end
			return
		end
		handler(player, ...)
	end)
end

function Net.fire(player: Player, name: string, ...: any)
	local event = events[name]
	if event == nil then
		error("[Net] unknown remote " .. name)
	end
	event:FireClient(player, ...)
end

function Net.fireAll(name: string, ...: any)
	local event = events[name]
	if event == nil then
		error("[Net] unknown remote " .. name)
	end
	event:FireAllClients(...)
end

function Net.toast(player: Player, text: string, kind: Types.ToastKind?)
	Net.fire(player, "Toast", text, kind or "info")
end

return Net
