--!strict
-- #2908 (Derek2 2026-11-10: "let you see the exhibits being filled"): each exhibit the player has filled stands in
-- the Relic Museum as that cat's model on its plinth, at the model's ExhibitSpot_<area>_<n> attachment
-- (LateStations.exhibitSpot; Model-Agent's #2918), gold or rainbow when the copy given was. Drawn on this client
-- only, from LateStationsState: every player sees their own museum. A new exhibit appears as it is given.
--
-- Roblox terms: a model made on one client exists only there; the copies are anchored and take no touches, clicks
-- or collisions. The museum model can stream in and out, so a look every LOOK_SECONDS puts the exhibits back.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local LateStations = require(Shared:WaitForChild("LateStations"))
local Net = require(script.Parent.Parent.Net)

local MuseumGalleryController = {}

local LOOK_SECONDS = 2
local CAT_SCALE = 0.6 -- a sitting cat on a plinth (Model-Agent, #2918)

type Shown = { coat: string, copy: Model, museum: Model }

local wanted: { [string]: string } = {} -- catId -> the coat given, from the last LateStationsState
local shown: { [string]: Shown } = {}
local folder: Folder? = nil

local function museumModel(): Model?
	for _, model in CollectionService:GetTagged(LateStations.TAG) do
		if
			model:IsA("Model")
			and model:GetAttribute("StationId") == LateStations.MUSEUM
			and model:IsDescendantOf(Workspace)
		then
			return model :: Model
		end
	end
	return nil
end

local function holder(): Folder
	if folder == nil or folder.Parent == nil then
		local made = Instance.new("Folder")
		made.Name = "MuseumExhibits"
		made.Parent = Workspace
		folder = made
	end
	return folder :: Folder
end

local function template(catId: string, coat: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets == nil then
		return nil
	end
	local names = { Catalog.catModelName(catId) }
	if coat == "gold" then
		table.insert(names, 1, Catalog.goldModelName(catId))
	end
	for _, name in names do
		local found = assets:FindFirstChild(name)
		if found ~= nil and found:IsA("Model") then
			return found :: Model
		end
	end
	return nil
end

local function quiet(model: Instance)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			local part = item :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		elseif item:IsA("Script") or item:IsA("LocalScript") then
			item:Destroy()
		end
	end
end

local function clear(catId: string)
	local entry = shown[catId]
	if entry ~= nil then
		shown[catId] = nil
		entry.copy:Destroy()
	end
end

local function place(catId: string, coat: string, museum: Model)
	local name = LateStations.exhibitSpot(catId)
	local spot = if name ~= nil then museum:FindFirstChild(name, true) else nil
	local source = template(catId, coat)
	if spot == nil or not spot:IsA("Attachment") or source == nil then
		return -- no plinth yet (before #2918) or no model: the card still shows it
	end
	local copy = source:Clone() :: Model
	copy.Name = "Exhibit_" .. catId
	quiet(copy)
	pcall(function()
		copy:ScaleTo(CAT_SCALE)
	end)
	copy:PivotTo((spot :: Attachment).WorldCFrame)
	copy.Parent = holder()
	shown[catId] = { coat = coat, copy = copy, museum = museum }
end

local function refresh()
	local museum = museumModel()
	for catId, entry in shown do
		if
			museum == nil
			or entry.museum ~= museum
			or wanted[catId] ~= entry.coat
			or entry.copy.Parent == nil
		then
			clear(catId)
		end
	end
	if museum == nil then
		return
	end
	for catId, coat in wanted do
		if shown[catId] == nil then
			place(catId, coat, museum)
		end
	end
end

local function onState(state: any)
	table.clear(wanted)
	local museum = if type(state) == "table" and state.live == true then state.museum else nil
	if type(museum) == "table" and type(museum.filled) == "table" then
		for catId, coat in museum.filled do
			if type(catId) == "string" and type(coat) == "string" then
				wanted[catId] = coat
			end
		end
	end
	refresh()
end

function MuseumGalleryController.start()
	Net.on("LateStationsState", onState)
	task.spawn(function()
		while true do
			task.wait(LOOK_SECONDS)
			refresh()
		end
	end)
end

return MuseumGalleryController
