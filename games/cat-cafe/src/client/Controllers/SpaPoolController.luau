--!strict
-- #2909 (Derek2 2026-11-10: "where you can see your cats soaking in the oasis"; late-stations.md section 1): the
-- player's own soaking cats sit in the Oasis Spa pool, one at each of the model's Soak_<slot> attachments, with a
-- towel on their heads (Model-Agent's CatCafe_Camp_Desert_SpaTowel, its HeadAttach on the top of the head). Drawn on
-- this client only, from LateStationsState: other players see their own cats, or none. A cat goes when it is
-- collected or taken out.
--
-- Roblox terms: a model made on one client exists only there, so nothing here is seen by anyone else; the copies are
-- anchored and take no touches, clicks or collisions. The spa model can stream in and out, so a look every
-- LOOK_SECONDS puts the cats back when it returns.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local LateStations = require(Shared:WaitForChild("LateStations"))
local Net = require(script.Parent.Parent.Net)

local SpaPoolController = {}

local LOOK_SECONDS = 2
local CAT_SCALE = 0.6 -- a sitting cat that fits the pool (Model-Agent, #2918)
local SINK = 0.35 -- studs the cat sits below its Soak attachment, so it is in the water
local TOWEL = "CatCafe_Camp_Desert_SpaTowel"

type Shown = { catId: string, copy: Model, spa: Model }

local slotsWanted: { [number]: string } = {} -- slot -> catId, from the last LateStationsState
local shown: { [number]: Shown } = {}

local function assets(): Instance?
	return ReplicatedStorage:FindFirstChild("Assets")
end

local function spaModel(): Model?
	for _, model in CollectionService:GetTagged(LateStations.TAG) do
		if
			model:IsA("Model")
			and model:GetAttribute("StationId") == LateStations.SPA
			and model:IsDescendantOf(Workspace)
		then
			return model :: Model
		end
	end
	return nil
end

-- Makes every part of `model` a still, untouchable look.
local function quiet(model: Instance)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			local part = item :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.CastShadow = false
		elseif item:IsA("Script") or item:IsA("LocalScript") then
			item:Destroy()
		end
	end
end

-- The towel on top of `cat`: its HeadAttach on the top of the cat's Head part (or the top of the whole cat).
local function addTowel(cat: Model)
	local folder = assets()
	local template = if folder ~= nil then folder:FindFirstChild(TOWEL) else nil
	if template == nil then
		return -- no towel yet: the cat soaks bare-headed
	end
	local towel = template:Clone()
	quiet(towel)
	local head = cat:FindFirstChild("Head", true)
	local top: Vector3
	if head ~= nil and head:IsA("BasePart") then
		top = (head :: BasePart).Position + Vector3.new(0, (head :: BasePart).Size.Y / 2, 0)
	else
		local box, size = cat:GetBoundingBox()
		top = box.Position + Vector3.new(0, size.Y / 2, 0)
	end
	local facing = cat:GetPivot().Rotation
	local attach = towel:FindFirstChild("HeadAttach", true)
	local want = CFrame.new(top) * facing
	if towel:IsA("Model") then
		local model = towel :: Model
		if attach ~= nil and attach:IsA("Attachment") then
			local offset = model:GetPivot():ToObjectSpace((attach :: Attachment).WorldCFrame)
			model:PivotTo(want * offset:Inverse())
		else
			model:PivotTo(want)
		end
	elseif towel:IsA("BasePart") then
		local part = towel :: BasePart
		part.CFrame = want
	end
	towel.Parent = cat
end

local function clear(slot: number)
	local entry = shown[slot]
	if entry ~= nil then
		shown[slot] = nil
		entry.copy:Destroy()
	end
end

local function place(slot: number, catId: string, spa: Model)
	local soak = spa:FindFirstChild("Soak_" .. slot, true)
	local folder = assets()
	local template = if folder ~= nil
		then folder:FindFirstChild(Catalog.catModelName(catId))
		else nil
	if
		soak == nil
		or not soak:IsA("Attachment")
		or template == nil
		or not template:IsA("Model")
	then
		return
	end
	local copy = template:Clone() :: Model
	copy.Name = "SpaSoak_" .. slot
	quiet(copy)
	pcall(function()
		copy:ScaleTo(CAT_SCALE)
	end)
	copy:PivotTo((soak :: Attachment).WorldCFrame * CFrame.new(0, -SINK, 0))
	addTowel(copy)
	copy.Parent = Workspace
	shown[slot] = { catId = catId, copy = copy, spa = spa }
end

-- Puts the shown cats in step with slotsWanted and the spa model now standing.
local function refresh()
	local spa = spaModel()
	for slot, entry in shown do
		if
			spa == nil
			or entry.spa ~= spa
			or slotsWanted[slot] ~= entry.catId
			or entry.copy.Parent == nil
		then
			clear(slot)
		end
	end
	if spa == nil then
		return
	end
	for slot, catId in slotsWanted do
		if shown[slot] == nil then
			place(slot, catId, spa)
		end
	end
end

local function onState(state: any)
	table.clear(slotsWanted)
	if
		type(state) == "table"
		and state.live == true
		and type(state.spa) == "table"
		and type(state.spa.soaking) == "table"
	then
		for _, slot in state.spa.soaking do
			if
				type(slot) == "table"
				and type(slot.slot) == "number"
				and type(slot.catId) == "string"
			then
				slotsWanted[slot.slot] = slot.catId
			end
		end
	end
	refresh()
end

function SpaPoolController.start()
	Net.on("LateStationsState", onState)
	task.spawn(function()
		while true do
			task.wait(LOOK_SECONDS)
			refresh()
		end
	end)
end

return SpaPoolController
