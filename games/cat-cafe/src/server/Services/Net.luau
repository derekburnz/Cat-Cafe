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
-- Three layers: one bucket for everything a player sends (the ceiling), one per remote, and slower buckets for
-- remotes that do real work per call (a grab or rescue attempt, a full profile serialize, a claim, a tutorial step).
local globalLimiter = RateLimiter.new(Config.RemoteRateLimitPerSecond * 3, 1)
local defaultLimiter = RateLimiter.new(Config.RemoteRateLimitPerSecond, 1)
local slowLimiters: { [string]: RateLimiter.RateLimiter } = {
	GrabBegin = RateLimiter.new(1, Config.GrabRateLimitSeconds),
	RescueBegin = RateLimiter.new(1, 1),
	RescueCancel = RateLimiter.new(1, 1),
	DropCat = RateLimiter.new(1, 1),
	RequestSync = RateLimiter.new(1, 2),
	ClaimOffline = RateLimiter.new(1, 2),
	EquipBest = RateLimiter.new(1, 2), -- sorts, solves, rebuilds the plot and sends a full sync
	UnequipAll = RateLimiter.new(1, 2), -- rebuilds the plot and sends a full sync, like EquipBest
	RankUp = RateLimiter.new(1, 2), -- data-model section 15: 1 per 2 s
	TutorialAdvance = RateLimiter.new(1, 1),
	Travel = RateLimiter.new(1, 1), -- a flood guard; TravelService answers TravelCooldownSeconds with a reason
	BuyDealerFood = RateLimiter.new(2, 1), -- recomputes the stock and answers with DealerStock every time
	UseLure = RateLimiter.new(1, 1), -- rolls a cat and rebuilds the bowl
	ResolveBait = RateLimiter.new(1, 1), -- the card retries after 6 s at most
	ClaimRichTip = RateLimiter.new(1, 1), -- the Collect button waits 3 s for an answer
	Bump = RateLimiter.new(2, 1), -- a flood guard; ShoveService answers BumpCooldownSeconds with a reason
	RenameCat = RateLimiter.new(1, 1), -- a flood guard; NameService answers RenameCooldownSeconds with a reason
	TelemetryReport = RateLimiter.new(10, 60), -- data-model section 15: 10 a minute
	SetSetting = RateLimiter.new(4, 1), -- a toggle tap; each call sends a full sync
	ClaimTipJar = RateLimiter.new(1, 1), -- data-model section 15: 1 a second
	ClaimIndexReward = RateLimiter.new(1, 1), -- data-model section 15: 1 a second
	SpinWheel = RateLimiter.new(2, 1), -- SpinService also holds each player to SpinCooldownSeconds between spins
}
local overLimitLog: { [number]: number } = {} -- userId -> last warn time

local function limiterFor(name: string): RateLimiter.RateLimiter
	return slowLimiters[name] or defaultLimiter
end

-- Logged at most once a second per player so a fuzzing client cannot fill the server log.
local function logOnce(player: Player, message: string)
	local now = os.clock()
	if (overLimitLog[player.UserId] or 0) + 1 < now then
		overLimitLog[player.UserId] = now
		warn(message)
	end
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
		local key = tostring(player.UserId)
		globalLimiter:forget(key)
		for name in events do
			defaultLimiter:forget(key .. name)
		end
		for name, limiter in slowLimiters do
			limiter:forget(key .. name)
		end
		overLimitLog[player.UserId] = nil
	end)
end

-- Connects a client -> server handler behind the rate limiter. Over the limit: dropped silently, logged once a second.
function Net.on(name: string, handler: (player: Player, ...any) -> ())
	local event: RemoteEvent? = events[name]
	if event == nil then
		error("[Net] unknown remote " .. name)
	end
	event.OnServerEvent:Connect(function(player: Player, ...: any)
		local key = tostring(player.UserId)
		if not (globalLimiter:allow(key) and limiterFor(name):allow(key .. name)) then
			logOnce(
				player,
				string.format("[Net] rate limit hit: user %d on %s", player.UserId, name)
			)
			return
		end
		local ok, err = xpcall(function(...: any)
			handler(player, ...)
			return nil :: any
		end, function(message: any): string
			return debug.traceback(tostring(message), 2)
		end, ...)
		if not ok then
			logOnce(
				player,
				string.format(
					"[Net] %s handler failed for user %d: %s",
					name,
					player.UserId,
					tostring(err)
				)
			)
		end
	end)
end

function Net.fire(player: Player, name: string, ...: any)
	local event: RemoteEvent? = events[name]
	if event == nil then
		error("[Net] unknown remote " .. name)
	end
	event:FireClient(player, ...)
end

function Net.fireAll(name: string, ...: any)
	local event: RemoteEvent? = events[name]
	if event == nil then
		error("[Net] unknown remote " .. name)
	end
	event:FireAllClients(...)
end

function Net.toast(player: Player, text: string, kind: Types.ToastKind?)
	Net.fire(player, "Toast", text, kind or "info")
end

return Net
