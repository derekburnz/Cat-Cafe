--!strict
-- The camp growth (#2687 part 2: "The camp grows: a second canopy or lantern string and a small crowd of townsfolk
-- cats around the station"). Once this player's tier opens an area, its camp grows on this client: Model-Agent's
-- CatCafe_Camp_<Area>_Growth (a stall, lanterns, a bench or the like) stands where the area's station stands, placed
-- exactly like it (the manifest's note), and a townsfolk cat (CatCafe_NPC_Townsfolk_<Name>, #2783) sits on each of its
-- Townsfolk_1..3 Attachments: the area's own first, then two from the camps after it, so a crowd is never three of
-- one cat. Other players see their own camps. Townsfolk.luau makes the cats idle and greet; the first time you come
-- into the area (Moments.StationReveal) the growth builds in with the station (StationBuild).
--
-- Source: the player's `tier` from ProfileSync, Catalog.tiers' `area` for the tier that opens each area, and the
-- area's streamed-in `CampExtra` station (its pivot is the camp's extra spot with the camp's turn, Layout.campExtraAt).
-- An area with no station yet (the Desert and the Ruins until theirs land) grows nothing. Once placed, a camp's growth
-- stays for the session (it is this client's own, so it never streams out). Listening only.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog"))
local Logic = require(script.Parent.Logic)
local Moments = require(script.Parent.Parent.Moments)
local Net = require(script.Parent.Parent.Net)
local StationBuild = require(script.Parent.StationBuild)

local CampGrowth = {}

local TAG = "CampExtra" -- shared/CampExtras.TAG
local SEATS = { "Townsfolk_1", "Townsfolk_2", "Townsfolk_3" }
-- Model-Agent's townsfolk.AREA (#2783): each area's own townsfolk cat, in tier order
local FOLK: { { area: string, name: string } } = {
	{ area = "park", name = "Picnicker" },
	{ area = "neighbourhood", name = "Neighbour" },
	{ area = "woods", name = "Camper" },
	{ area = "sewer", name = "Tinker" },
	{ area = "desert", name = "Trader" },
	{ area = "ruins", name = "Explorer" },
}

local opensAt: { [string]: number } = {} -- area id -> the tier that opens it
local tier = 0 -- this player's tier, from ProfileSync
local grown: { [string]: Model? } = {} -- area id -> its placed growth
local folder: Folder? = nil
local started = false

for _, def in Catalog.tiers do
	local area = (def :: any).area
	if type(area) == "string" and def.tier >= 2 then
		opensAt[area] = def.tier
	end
end

-- "park" -> "Park", the way the camp's art is named.
local function artName(area: string): string
	return string.upper(string.sub(area, 1, 1)) .. string.sub(area, 2)
end

-- The townsfolk cat for seat `n` (1 to 3) at `area`'s camp: its own, then the next camps' (Logic.folkAt).
function CampGrowth.folkFor(area: string, n: number): string?
	local names: { string } = {}
	local areas: { string } = {}
	for _, folk in FOLK do
		table.insert(areas, folk.area)
		table.insert(names, folk.name)
	end
	local pick = Logic.folkAt(areas, area, n)
	return if pick ~= nil then "CatCafe_NPC_Townsfolk_" .. names[pick] else nil
end

local function holder(): Folder
	if folder ~= nil and folder.Parent ~= nil then
		return folder
	end
	local made = Instance.new("Folder")
	made.Name = "CampGrowth"
	made.Parent = Workspace
	folder = made
	return made
end

local function asset(name: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local source = if assets ~= nil then assets:FindFirstChild(name) else nil
	if source == nil or not source:IsA("Model") then
		return nil
	end
	local model = (source :: Model):Clone() :: Model
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			(descendant :: BasePart).Anchored = true
		end
	end
	return model
end

-- The streamed-in station of `area`, or nil.
local function stationOf(area: string): Model?
	for _, instance in CollectionService:GetTagged(TAG) do
		if
			instance:IsA("Model")
			and instance:GetAttribute("Area") == area
			and instance:IsDescendantOf(Workspace)
		then
			return instance :: Model
		end
	end
	return nil
end

-- Grows `area`'s camp when its tier is owned, its station is here and it has not grown yet.
local function grow(area: string)
	local opens = opensAt[area]
	if grown[area] ~= nil or opens == nil or tier < opens then
		return
	end
	local station = stationOf(area)
	if station == nil then
		return
	end
	local growth = asset("CatCafe_Camp_" .. artName(area) .. "_Growth")
	if growth == nil then
		return
	end
	growth:PivotTo(station:GetPivot())
	growth.Parent = holder()
	grown[area] = growth
	for n, seat in SEATS do
		local point = growth:FindFirstChild(seat, true)
		local name = CampGrowth.folkFor(area, n)
		if point == nil or not point:IsA("Attachment") or name == nil then
			continue
		end
		local folk = asset(name)
		if folk ~= nil then
			for _, descendant in folk:GetDescendants() do
				if descendant:IsA("BasePart") then
					local part = descendant :: BasePart
					part.CanCollide = false
					part.CanQuery = false
					part.CanTouch = false
				end
			end
			folk:PivotTo((point :: Attachment).WorldCFrame)
			folk.Parent = holder() -- beside the growth, not in it, so the build-in leaves the cats to Townsfolk.luau
		end
	end
end

local function growAll()
	for area in opensAt do
		grow(area)
	end
end

function CampGrowth.start()
	if started then
		return
	end
	started = true
	Net.on("ProfileSync", function(state: unknown)
		if type(state) ~= "table" then
			return
		end
		local t = (state :: { [string]: unknown }).tier
		if type(t) == "number" and t ~= tier then
			tier = t
			growAll()
		end
	end)
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(instance: Instance)
		local area = instance:GetAttribute("Area")
		if type(area) == "string" then
			-- its parts and pivot settle a frame after the tag
			task.defer(grow, area)
		end
	end)
	-- the first time you come into the area, the camp's growth builds in with its station
	Moments.StationReveal:Connect(function(area: string)
		grow(area)
		local growth = grown[area]
		if growth ~= nil then
			StationBuild.play(growth)
		end
	end)
	growAll()
end

return CampGrowth
