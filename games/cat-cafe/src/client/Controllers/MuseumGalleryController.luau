--!strict
-- #2908 (Derek2 2026-11-10: "let you see the exhibits being filled"): each exhibit the player has filled stands in
-- the Relic Museum as that cat's model on its plinth, at the model's ExhibitSpot_<area>_<n> attachment
-- (LateStations.exhibitSpot; Model-Agent's #2918), gold or rainbow when the copy given was. Drawn on this client
-- only, from LateStationsState: every player sees their own museum. A new exhibit appears as it is given.
--
-- Roblox terms: a model made on one client exists only there; the copies are anchored and take no touches, clicks
-- or collisions. The museum model can stream in and out, so a look every LOOK_SECONDS puts the exhibits back.
--
-- #2897: each copy carries the CatCafeExhibit tag, and one given since the first state this session is Fresh, so
-- Effects/StationMotion drops it onto its plinth. One put back after streaming, or there when you join, just stands.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local GoldTone = require(Shared:WaitForChild("GoldTone"))
local LateStations = require(Shared:WaitForChild("LateStations"))
local Net = require(script.Parent.Parent.Net)

local MuseumGalleryController = {}

local LOOK_SECONDS = 2
local CAT_SCALE = 0.6 -- a sitting cat on a plinth (Model-Agent, #2918)
local TAG = "CatCafeExhibit" -- Effects/StationMotion.EXHIBIT_TAG

type Shown = { coat: string, copy: Model, museum: Model }

local wanted: { [string]: string } = {} -- catId -> the coat given, from the last LateStationsState
local shown: { [string]: Shown } = {}
local fresh: { [string]: boolean } = {} -- given since the last state, not yet placed
local stated = false -- a state has come this session
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

-- The model to copy for a cat in `coat`, and whether the copy must be toned gold (#4133, shared/GoldTone).
local function template(catId: string, coat: string): (Model?, boolean)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets == nil then
		return nil, false
	end
	local names = { Catalog.catModelName(catId) }
	local tone = false
	if coat == "gold" then
		names, tone = GoldTone.names(Catalog.goldModelName(catId), Catalog.catModelName(catId))
	end
	for _, name in names do
		local found = assets:FindFirstChild(name)
		if found ~= nil and found:IsA("Model") then
			return found :: Model, tone
		end
	end
	return nil, false
end

local function quiet(model: Instance)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			local part = item :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		elseif item:IsA("LuaSourceContainer") then -- scripts and ModuleScripts alike
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
	local source, tone = template(catId, coat)
	if spot == nil or not spot:IsA("Attachment") or source == nil then
		return -- no plinth yet (before #2918) or no model: the card still shows it
	end
	local copy = source:Clone() :: Model
	if tone then
		GoldTone.apply(copy)
	end
	copy.Name = "Exhibit_" .. catId
	quiet(copy)
	pcall(function()
		copy:ScaleTo(CAT_SCALE)
	end)
	copy:PivotTo((spot :: Attachment).WorldCFrame)
	if fresh[catId] then
		fresh[catId] = nil
		copy:SetAttribute("Fresh", true)
	end
	CollectionService:AddTag(copy, TAG)
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
	local before = table.clone(wanted)
	table.clear(wanted)
	local museum = if type(state) == "table" and state.live == true then state.museum else nil
	if type(museum) == "table" and type(museum.filled) == "table" then
		for catId, coat in museum.filled do
			if type(catId) == "string" and type(coat) == "string" then
				wanted[catId] = coat
				if stated and before[catId] == nil then
					fresh[catId] = true
				end
			end
		end
	end
	if type(museum) == "table" then
		stated = true -- a state with no museum (not live yet) does not count, so the first real one never drops
	end
	for catId in fresh do
		if wanted[catId] == nil then
			fresh[catId] = nil
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
