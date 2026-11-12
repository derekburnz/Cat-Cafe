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
	-- #3478 (the Creator Hub error list of 2026-11-12: RankUp 7 drops in a day)
	RankUp = 2.2, -- 1 every 2 s
}
-- #2630: remotes where every call matters (two tips answered in the same second): a call inside the gap waits its
-- turn instead of being dropped, one a gap, in order.
local QUEUED: { [string]: number } = {
	TipSeen = 1.1, -- 1 a second
	-- #3478 (ClaimAchievement 19, InviteCard 16, FeedCat 6, ClaimQuest 6 drops in a day): quick taps down a list of
	-- claims or cats, and the invite card's "shown" then its answer, where a dropped call is a tap that did nothing.
	-- Each gap is the server limiter's refill time for one call plus a little for the trip.
	ClaimQuest = 0.55, -- 2 a second
	ClaimAchievement = 0.55, -- 2 a second
	FeedCat = 0.28, -- 4 a second
	InviteCard = 2.1, -- 1 every 2 s
	-- #3646: the Day Cart's three sections share this remote and the server takes 3 per 2 s. Spaced at 2.2 s here
	-- (#3478), a second section's Buy all inside that time was dropped on the device, so the server never answered
	-- and the button sat on "Buying..." with nothing bought and no word. It now waits its turn and is sent.
	BuyCornerShopAll = 0.75, -- 3 every 2 s
}
-- #3478: at most this many calls wait per remote; a tap past that is dropped, as the server would have dropped it
-- before, so a burst of taps never keeps playing out long after the player stopped.
local QUEUE_MOST = 8
-- for the spec: which remotes are dropped inside their gap and which wait their turn
Net.SPACED = SPACED
Net.QUEUED = QUEUED
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
			if #queue < QUEUE_MOST then
				table.insert(queue, table.pack(...))
			end
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
