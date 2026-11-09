--!strict
-- Client side of the remotes: thin wrappers so controllers never touch RemoteEvent instances directly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Net = {}

-- Remotes the server takes once a second (Net's RateLimiter.new(1, 1)) that a player can press twice by accident: a
-- double tap on Collect at a camp extra, or Travel twice. A repeat this soon would only be dropped there and logged
-- as "rate limit hit" (Derek2's dev console, 2026-11-07), so it is dropped here instead.
-- #2630 (the live Error Report's rate-limit rows: RescueBegin 20, EquipBest 9, OpenAllCrates 7, EquipBestDecor 5,
-- LaunchCannon 4, ...): the same for the other one-at-a-time presses, each spaced by its server limiter's window a
-- call (services/Net.luau) plus a tenth for the trip there.
local SPACED: { [string]: number } = {
	CollectCampExtra = 1.05,
	Travel = 1.05,
	RescueBegin = 1.1, -- 1 a second
	LaunchCannon = 1.1, -- 1 a second
	ClaimIndexReward = 1.1, -- 1 a second
	SpinAll = 1.1, -- 1 a second
	EquipBest = 2.2, -- 1 every 2 s
	UnequipAll = 2.2, -- 1 every 2 s
	EquipBestDecor = 2.2, -- 1 every 2 s
	OpenAllCrates = 2.2, -- 1 every 2 s
}
-- #2630: remotes where every call matters (two tips answered in the same second): a call inside the gap waits its
-- turn instead of being dropped, one a gap, in order.
local QUEUED: { [string]: number } = {
	TipSeen = 1.1, -- 1 a second
}
local lastFired: { [string]: number } = {}
local waiting: { [string]: { { n: number, [number]: any } } } = {}

local function flush(name: string)
	local queue = waiting[name]
	if queue == nil or #queue == 0 then
		waiting[name] = nil
		return
	end
	local args = table.remove(queue, 1) :: { n: number, [number]: any }
	lastFired[name] = os.clock()
	Remotes.event(name):FireServer(table.unpack(args, 1, args.n))
	if #queue == 0 then
		waiting[name] = nil
	else
		task.delay(QUEUED[name], flush, name)
	end
end

function Net.fire(name: string, ...: any)
	local now = os.clock()
	local wait = QUEUED[name]
	if wait ~= nil then
		local queue = waiting[name]
		if queue ~= nil then
			table.insert(queue, table.pack(...))
			return
		end
		local since = now - (lastFired[name] or -math.huge)
		if since < wait then
			waiting[name] = { table.pack(...) }
			task.delay(wait - since, flush, name)
			return
		end
		lastFired[name] = now
		Remotes.event(name):FireServer(...)
		return
	end
	local gap = SPACED[name]
	if gap ~= nil then
		if now - (lastFired[name] or -math.huge) < gap then
			return
		end
		lastFired[name] = now
	end
	Remotes.event(name):FireServer(...)
end

function Net.on(name: string, handler: (...any) -> ()): RBXScriptConnection
	return Remotes.event(name).OnClientEvent:Connect(handler)
end

return Net
