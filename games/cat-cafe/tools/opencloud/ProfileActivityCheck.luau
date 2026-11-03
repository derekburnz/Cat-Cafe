-- Profile activity check (issue #941): has anyone played the live game since the leaderboards went live? The live
-- leaderboard stores are empty (LeaderboardCheck, 2026-11-03 01:58 UTC), so either nobody has finished a live session
-- since F98 or the writes fail. Reads up to MAX_KEYS saved profiles and prints counts only, never a key, user id or
-- name (the CI logs are public). Read only: no SetAsync, UpdateAsync or session. Run with the run-luau workflow.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Leaderboards = require(ReplicatedStorage.Shared.Leaderboards)

local SINCE = 1793613600 -- 2026-11-02 10:00 UTC: F98 merged at 09:36, so live from about here
local MAX_KEYS = 50

local store = DataStoreService:GetDataStore(Config.ProfileStoreName)
local okList, pages = pcall(function()
	return store:ListKeysAsync(nil, 50)
end)
if not okList then
	print("profile list FAILED: " .. tostring(pages))
	return
end

local total, unreadable, recent, recentIndex, recentPlay = 0, 0, 0, 0, 0
local newest = 0
while total < MAX_KEYS do
	for _, info in pages:GetCurrentPage() do
		if total >= MAX_KEYS then
			break
		end
		total += 1
		local okGet, value = pcall(function()
			return store:GetAsync(info.KeyName)
		end)
		local data = nil
		if okGet and type(value) == "table" then
			data = if type(value.Data) == "table" then value.Data else value
		end
		if data == nil or type(data.lastSeen) ~= "number" then
			unreadable += 1
			continue
		end
		newest = math.max(newest, data.lastSeen)
		if data.lastSeen >= SINCE then
			recent += 1
			local okIndex, entries = pcall(Leaderboards.indexEntries, data)
			if okIndex and entries > 0 then
				recentIndex += 1
			end
			local stats = data.stats
			if type(stats) == "table" and type(stats.playtimeSeconds) == "number" and stats.playtimeSeconds >= 60 then
				recentPlay += 1
			end
		end
	end
	if pages.IsFinished then
		break
	end
	pages:AdvanceToNextPageAsync()
end

print(string.format("store %s: %d profiles read (%d unreadable)", Config.ProfileStoreName, total, unreadable))
print(
	string.format(
		"last seen since 2026-11-02 10:00 UTC: %d; of them with Index entries: %d; with a minute or more played: %d",
		recent,
		recentIndex,
		recentPlay
	)
)
print("newest lastSeen: " .. (if newest > 0 then os.date("!%Y-%m-%d %H:%M UTC", newest) else "none"))
