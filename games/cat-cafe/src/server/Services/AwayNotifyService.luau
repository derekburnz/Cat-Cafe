--!strict
-- The server half of the away notification (#2768, shared/AwayNotify): at logout, note in a MemoryStore sorted map
-- when this player's "your cats earned X while you were away" message is due and what X is; at the next join, take
-- the note out. Nothing is sent from here: tools/opencloud/away-notify.sh (a scheduled workflow) sends the due notes.
--
-- Roblox terms: a MemoryStore sorted map is a small shared table every server (and Open Cloud) can read, kept in
-- memory with an expiry on each item, sorted by a sort key. Here the sort key is the due time, so the sender reads
-- the earliest notes first, and a note nobody sent expires by itself.
--
-- Every call is best effort in the background: a failed write means one player gets no message, never a failed
-- save or a slower leave. Studio never writes (a test run should not queue a real message).
local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AwayNotify = require(ReplicatedStorage.Shared.AwayNotify)
local Types = require(ReplicatedStorage.Shared.Types)

local DataService = require(script.Parent.DataService)

local AwayNotifyService = {}

local function map(): MemoryStoreSortedMap
	return MemoryStoreService:GetSortedMap(AwayNotify.MAP)
end

local function note(player: Player, profile: Types.PlayerProfile)
	local plan = AwayNotify.plan(profile, os.time())
	if plan == nil then
		return
	end
	local key = AwayNotify.key(player.UserId)
	task.spawn(function()
		pcall(function()
			map():SetAsync(key, plan.text, plan.ttl, plan.dueAt)
		end)
	end)
end

local function clear(player: Player)
	local key = AwayNotify.key(player.UserId)
	task.spawn(function()
		pcall(function()
			map():RemoveAsync(key)
		end)
	end)
end

function AwayNotifyService.start()
	if RunService:IsStudio() then
		return
	end
	DataService.beforeRelease(note)
	DataService.onLoaded:Connect(clear)
end

return AwayNotifyService
