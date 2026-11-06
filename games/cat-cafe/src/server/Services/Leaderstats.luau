--!strict
-- The player list's leaderboard (F17; gdd "Social": money per second and cats found), the way every Roblox simulator
-- shows it: a `leaderstats` folder on the Player. Money/s is made first, so the list sorts by it; Tier is the cafe's
-- tier number, 1 to 5 (#1763, Derek2: the tier's name, "Grand Cafe", was cut off as "Grand..."). Display only:
-- CafeService rewrites it on every sync. F94 (rewards-and-shops.md section 5): the column reads Money/s (was Tips/s).

local Leaderstats = {}

local TIPS = "Money/s"
local CATS = "Cats"
local TIER = "Tier"

local function intValue(folder: Folder, name: string): IntValue
	local existing = folder:FindFirstChild(name)
	if existing ~= nil and existing:IsA("IntValue") then
		return existing :: IntValue
	end
	local created = Instance.new("IntValue")
	created.Name = name
	created.Parent = folder
	return created
end

-- The folder, its values made in column order before it is parented so the player list never sees a half set.
local function folderOf(player: Player): Folder
	local existing = player:FindFirstChild("leaderstats")
	if existing ~= nil and existing:IsA("Folder") then
		return existing :: Folder
	end
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	intValue(folder, TIPS)
	intValue(folder, CATS)
	intValue(folder, TIER)
	folder.Parent = player
	return folder
end

-- `tipsPerSecond` is what the cafe earns now (the HUD's figure), `catsFound` the book's count, `tier` the cafe's tier.
function Leaderstats.update(player: Player, tipsPerSecond: number, catsFound: number, tier: number)
	local folder = folderOf(player)
	intValue(folder, TIPS).Value = math.floor(tipsPerSecond + 0.5)
	intValue(folder, CATS).Value = catsFound
	intValue(folder, TIER).Value = tier
end

return Leaderstats
