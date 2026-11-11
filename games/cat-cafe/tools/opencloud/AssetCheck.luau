-- Asset load check, run by tools/opencloud/run-luau.sh (run-luau.yml): does each id below load from Roblox yet?
-- A sound or picture still in moderation (or rejected) fails to fetch, so this tells a thread whether a fresh
-- upload is safe to ship. Read-only. The first two rows are controls: a sound known to be approved and an id
-- that does not exist. Edit IDS on your branch and run the workflow from that branch.

local ContentProvider = game:GetService("ContentProvider")
local MarketplaceService = game:GetService("MarketplaceService")
local ServerStorage = game:GetService("ServerStorage")

local GROUP_ID = 107520049 -- Creampuff Games; the log is public, so it says "ours" and never prints a creator name
local IDS: { { name: string, id: number, kind: string } } = {
	{ name = "control: strayCall (approved)", id = 115966888994390, kind = "Sound" },
	{ name = "control: no such asset", id = 1, kind = "Sound" },
	{ name = "CatCafe_Sheet_Pool", id = 86210298933711, kind = "Sound" },
}

local lines = {}
for _, row in IDS do
	local url = "rbxassetid://" .. row.id
	local instance: Instance
	if row.kind == "Sound" then
		local sound = Instance.new("Sound")
		sound.SoundId = url
		instance = sound
	else
		local label = Instance.new("ImageLabel")
		label.Image = url
		instance = label
	end
	-- a Sound needs a parent to load; ServerStorage keeps it away from any players. The label preloads unparented
	if instance:IsA("Sound") then
		instance.Parent = ServerStorage
	end
	local status = "no callback"
	local okPreload, errPreload = pcall(function()
		ContentProvider:PreloadAsync({ instance }, function(_, fetchStatus)
			status = fetchStatus.Name
		end)
	end)
	if not okPreload then
		status = "preload error: " .. tostring(errPreload)
	end
	local extra = ""
	if instance:IsA("Sound") then
		local waited = 0
		while not instance.IsLoaded and waited < 5 do
			waited += task.wait(0.25)
		end
		extra = string.format(
			" IsLoaded=%s TimeLength=%.2f",
			tostring(instance.IsLoaded),
			instance.TimeLength
		)
	end
	local okInfo, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, row.id)
	local infoText = if okInfo
		then string.format(
			"name=%q ours=%s",
			tostring(info.Name),
			tostring(info.Creator ~= nil and info.Creator.CreatorTargetId == GROUP_ID)
		)
		else "info error: " .. tostring(info)
	table.insert(
		lines,
		string.format("%-32s %d  fetch=%s%s  %s", row.name, row.id, status, extra, infoText)
	)
	instance:Destroy()
end

local report = table.concat(lines, "\n")
print(report)
return report
