-- Asset load check, run by tools/opencloud/run-luau.sh (run-luau.yml): does each id below load from Roblox yet?
-- A sound or picture still in moderation (or rejected) fails to fetch, so this tells a thread whether a fresh
-- upload is safe to ship. Read-only. The first two rows are controls: a sound known to be approved and an id
-- that does not exist. Give the ids to check in the workflow's "ids" box (digits, split by spaces or commas);
-- run-luau.sh writes them into INPUT_IDS below. With no ids given, only the two controls run.

local ContentProvider = game:GetService("ContentProvider")
local MarketplaceService = game:GetService("MarketplaceService")
local ServerStorage = game:GetService("ServerStorage")

local GROUP_ID = 107520049 -- Creampuff Games; the log is public, so it says "ours" and never prints a creator name
local INPUT_IDS = "" -- filled in by run-luau.sh from LUAU_IDS; leave this line exactly as it is
local AUDIO_TYPE = Enum.AssetType.Audio.Value

type Row = { name: string, id: number, kind: string? }
local IDS: { Row } = {
	{ name = "control: strayCall (approved)", id = 115966888994390, kind = "Sound" },
	{ name = "control: no such asset", id = 1, kind = "Sound" },
}
for digits in string.gmatch(INPUT_IDS, "%d+") do
	local id = tonumber(digits)
	if id then
		table.insert(IDS, { name = "asked", id = id })
	end
end

local lines = {}
for _, row in IDS do
	local okInfo, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, row.id)
	local infoText = if okInfo
		then string.format(
			"name=%q ours=%s",
			tostring(info.Name),
			tostring(info.Creator ~= nil and info.Creator.CreatorTargetId == GROUP_ID)
		)
		else "info error: " .. tostring(info)
	-- an id from the box has no kind: the asset's own type says whether it is a sound; anything else loads as a picture
	local kind = row.kind
		or (if okInfo and info.AssetTypeId == AUDIO_TYPE then "Sound" else "Image")
	local url = "rbxassetid://" .. row.id
	local instance: Instance
	if kind == "Sound" then
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
	table.insert(
		lines,
		string.format(
			"%-32s %d  %s fetch=%s%s  %s",
			row.name,
			row.id,
			kind,
			status,
			extra,
			infoText
		)
	)
	instance:Destroy()
end

local report = table.concat(lines, "\n")
print(report)
return report
