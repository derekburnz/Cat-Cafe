--!strict
-- The Golden Pond pass's gold Fishing Hut (#1368, camp-stations.md section 4). The Woods hut is one shared world model
-- (WorldBuilder's camp extras, tagged CampExtra with ExtraId "pond"), so a pass owner's look is a swap on their own
-- client only: when the server has set CampExtras.GOLD_POND_ATTRIBUTE on this player (PassService), each part of the
-- shared hut takes the Color and Material of its twin in Model-Agent's CatCafe_Camp_Woods_FishingHut_Gold
-- (ReplicatedStorage.Assets; #1351: the same parts and attachments, only those two differ). Twins are matched by where
-- they sit from the model's pivot and their size, so the hut's prompt, glow, rod cast and collisions stay the shared
-- model's own. Other players keep seeing the plain hut. Listening only; nothing is sent to the server.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CampExtras = require(Shared:WaitForChild("CampExtras"))

local GoldHutController = {}

local POND = "pond" -- the hut's ExtraId (Catalog.campExtras)

type Look = { color: Color3, material: Enum.Material }

local looks: { [string]: Look }? = nil -- the gold model's parts by key, read once
local recoloured: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function round(value: number): number
	return math.floor(value * 100 + 0.5)
end

-- Where a part sits from the model's pivot, which way it faces, and its size, to the hundredth of a stud.
local function key(pivot: CFrame, part: BasePart): string
	local at = pivot:ToObjectSpace(part.CFrame)
	local p, look, size = at.Position, at.LookVector, part.Size
	return table.concat({
		round(p.X),
		round(p.Y),
		round(p.Z),
		round(look.X),
		round(look.Y),
		round(look.Z),
		round(size.X),
		round(size.Y),
		round(size.Z),
	}, ",")
end

local function goldLooks(): { [string]: Look }?
	if looks ~= nil then
		return looks
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local gold = if assets ~= nil
		then assets:FindFirstChild(CampExtras.GOLD_HUT_MODEL, true)
		else nil
	if gold == nil or not gold:IsA("Model") then
		return nil
	end
	local pivot = (gold :: Model):GetPivot()
	local found: { [string]: Look } = {}
	for _, descendant in gold:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			found[key(pivot, part)] = { color = part.Color, material = part.Material }
		end
	end
	looks = found
	return found
end

local function owns(): boolean
	return Players.LocalPlayer:GetAttribute(CampExtras.GOLD_POND_ATTRIBUTE) == true
end

-- Gives the shared hut the gold look on this client, once, when this player owns the pass.
local function recolour(instance: Instance)
	if
		recoloured[instance]
		or not owns()
		or not instance:IsA("Model")
		or instance:GetAttribute("ExtraId") ~= POND
		or not instance:IsDescendantOf(Workspace)
	then
		return
	end
	local map = goldLooks()
	if map == nil then
		return
	end
	local pivot = (instance :: Model):GetPivot()
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			local look = map[key(pivot, part)]
			if look ~= nil then
				part.Color = look.color
				part.Material = look.material
			end
		end
	end
	recoloured[instance] = true
end

local function recolourAll()
	for _, instance in CollectionService:GetTagged(CampExtras.TAG) do
		recolour(instance)
	end
end

function GoldHutController.start()
	-- the hut streams in whole (Atomic); deferred so its parts are in place before they are read
	CollectionService:GetInstanceAddedSignal(CampExtras.TAG):Connect(function(instance: Instance)
		task.defer(recolour, instance)
	end)
	Players.LocalPlayer
		:GetAttributeChangedSignal(CampExtras.GOLD_POND_ATTRIBUTE)
		:Connect(recolourAll)
	recolourAll()
end

return GoldHutController
