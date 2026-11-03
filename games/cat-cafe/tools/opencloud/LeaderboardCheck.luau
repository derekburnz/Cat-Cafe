-- Leaderboard check (issue #941): reads the live leaderboard stores the way LeaderboardService does and prints only
-- counts and yes/no answers, never a user id or a name (the CI logs are public). Run with tools/opencloud/run-luau.sh
-- against the live place version. Read only: no SetAsync, no UpdateAsync.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Leaderboards = require(ReplicatedStorage.Shared.Leaderboards)

local owner = if game.CreatorType == Enum.CreatorType.User then game.CreatorId else 0
local week = Leaderboards.week(os.time())
print(string.format("week %d, experience owned by a %s", week, tostring(game.CreatorType)))

local hiddenIds: { [number]: boolean } = {}
local okHidden, hidden = pcall(function()
	return DataStoreService:GetDataStore("CatCafe_LB"):GetAsync("CatCafe_LB_Hidden")
end)
if not okHidden then
	print("hidden list: read FAILED: " .. tostring(hidden))
else
	local size, ownerHidden = 0, false
	if type(hidden) == "table" then
		for _, id in hidden do
			size += 1
			ownerHidden = ownerHidden or id == owner
			if type(id) == "number" then
				hiddenIds[id] = true
			end
		end
	end
	print(string.format("hidden list: %s, %d ids, owner hidden: %s", typeof(hidden), size, tostring(ownerHidden)))
end

for _, list in Leaderboards.LISTS do
	local name = Leaderboards.storeName(list, week)
	local ok, entries = pcall(function()
		return DataStoreService:GetOrderedDataStore(name):GetSortedAsync(false, 50):GetCurrentPage()
	end)
	if not ok then
		print(string.format("%-14s %s: read FAILED: %s", list, name, tostring(entries)))
		continue
	end
	local count, hiddenCount, ownerRank, top, low = 0, 0, nil, nil, nil
	for i, entry in entries do
		count += 1
		if hiddenIds[tonumber(entry.key) or 0] then
			hiddenCount += 1
		end
		top = top or entry.value
		low = entry.value
		if tonumber(entry.key) == owner then
			ownerRank = i
		end
	end
	print(
		string.format(
			"%-14s %s: %d entries (%d of them hidden), top %s, lowest %s, owner rank %s",
			list,
			name,
			count,
			hiddenCount,
			tostring(top),
			tostring(low),
			tostring(ownerRank)
		)
	)
end
