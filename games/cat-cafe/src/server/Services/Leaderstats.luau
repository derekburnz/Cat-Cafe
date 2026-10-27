--!strict
-- The player list's leaderboard (F17; gdd "Social": tips per second and cats found), the way every Roblox simulator
-- shows it: a `leaderstats` folder on the Player. Tips/s is made first, so the list sorts by it; Cafe is the tier's
-- name, which reads "Grand Cafe" at Tier 5. Display only: CafeService rewrites it on every sync.

local Leaderstats = {}

local TIPS = "Tips/s"
local CATS = "Cats"
local CAFE = "Cafe"

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

local function stringValue(folder: Folder, name: string): StringValue
	local existing = folder:FindFirstChild(name)
	if existing ~= nil and existing:IsA("StringValue") then
		return existing :: StringValue
	end
	local created = Instance.new("StringValue")
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
	stringValue(folder, CAFE)
	folder.Parent = player
	return folder
end

-- `tipsPerSecond` is what the cafe earns now (the HUD's figure), `catsFound` the book's count.
function Leaderstats.update(
	player: Player,
	tipsPerSecond: number,
	catsFound: number,
	cafeName: string
)
	local folder = folderOf(player)
	intValue(folder, TIPS).Value = math.floor(tipsPerSecond + 0.5)
	intValue(folder, CATS).Value = catsFound
	stringValue(folder, CAFE).Value = cafeName
end

return Leaderstats
