--!strict
-- The Relic Museum's room names glow gold (#3129; Derek2 2026-11-10: "have the title of the area glow gold when its
-- completed"). Each shelf row of the gallery has a name plaque (ALLEYWAY, PARK and so on), its letters a child Model
-- `..._Plaque_<area>` of the museum (Model's campstations.py). Once every exhibit of a room is filled, that room's
-- letters turn Neon in the room-complete gold (Presets.palette.golden, as LateStationFx's burst) and breathe slowly
-- between it and a brighter gold. An unfinished room's letters keep their modelled pale gold.
--
-- On this client only, from the server's LateStationsState, so every player sees their own finished rooms, like the
-- exhibits themselves (MuseumGalleryController). It shows as soon as the first state arrives, and again whenever
-- the museum streams back in. Reduce Motion and Low performance get the steady gold with no breathing; past
-- animRadius the letters hold steady too. Listening only: nothing here talks to the server.
--
-- Roblox terms: Neon is a part material that glows by itself. A property set on a part by a client is seen only
-- by that client.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local LateStations = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LateStations"))
local Logic = require(script.Parent.Logic)
local Presets = require(script.Parent.Presets)

local MuseumPlaques = {}

local TAG = "LateStation"

type Was = { color: Color3, material: Enum.Material }

local started = false
local done: { [string]: boolean } = {} -- area -> its room is full, from the last state
local was: { [BasePart]: Was } = {} -- each lit letter's modelled look, to put back
local lit: { [string]: { BasePart } } = {} -- area -> its lit letters, for the breathing

local function museumModel(): Model?
	for _, instance in CollectionService:GetTagged(TAG) do
		if
			instance:IsA("Model")
			and instance:IsDescendantOf(Workspace)
			and instance:GetAttribute("StationId") == LateStations.MUSEUM
		then
			return instance :: Model
		end
	end
	return nil
end

-- The letters of `area`'s plaque in `museum`: the parts of its `..._Plaque_<area>` Model.
local function lettersOf(museum: Model, area: string): { BasePart }
	local suffix = Presets.museumPlaques.suffix .. area
	local found: { BasePart } = {}
	for _, child in museum:GetChildren() do
		if child:IsA("Model") and child.Name:sub(-#suffix) == suffix then
			for _, item in child:GetDescendants() do
				if item:IsA("BasePart") then
					table.insert(found, item :: BasePart)
				end
			end
		end
	end
	return found
end

local function paint(letters: { BasePart }, color: Color3)
	for _, letter in letters do
		letter.Color = color
	end
end

-- Lights the finished rooms' letters and puts the others back, on the museum as it stands now.
local function apply()
	local museum = museumModel()
	table.clear(lit)
	for letter in was do
		if not letter:IsDescendantOf(Workspace) then
			was[letter] = nil -- streamed out: a new copy comes back with its modelled look
		end
	end
	if museum == nil then
		return
	end
	local p = Presets.museumPlaques
	for _, room in LateStations.rooms do
		local letters = lettersOf(museum, room.area)
		if done[room.area] then
			for _, letter in letters do
				if was[letter] == nil then
					was[letter] = { color = letter.Color, material = letter.Material }
					letter.Material = Enum.Material.Neon
					letter.Color = p.gold
				end
			end
			lit[room.area] = letters
		else
			for _, letter in letters do
				local before = was[letter]
				if before ~= nil then
					letter.Material = before.material
					letter.Color = before.color
					was[letter] = nil
				end
			end
		end
	end
end

local function onState(state: unknown)
	table.clear(done)
	local museum = if type(state) == "table" and (state :: any).live == true
		then (state :: any).museum
		else nil
	local filled = if type(museum) == "table" then (museum :: any).filled else nil
	if type(filled) == "table" then
		for _, area in LateStations.roomsDone(filled :: any) do
			done[area] = true
		end
	end
	apply()
end

-- The breathing: every lit letter between the gold and the brighter gold, out of step room by room.
local function breathe(now: number)
	local p = Presets.museumPlaques
	local calm = Context.reducedMotion() or Context.lowPerformance
	for area, letters in lit do
		local first = letters[1]
		if first == nil or not first:IsDescendantOf(Workspace) then
			continue
		end
		local still = calm or Context.distance(first.Position) > Context.budget.animRadius
		local level = Logic.plaqueGlow(now + Logic.phaseOf(area) * p.every, p.every, still)
		paint(letters, p.gold:Lerp(p.bright, level))
	end
end

function MuseumPlaques.start()
	if started then
		return
	end
	started = true
	Context.whenRemote("LateStationsState", function(remote: RemoteEvent)
		remote.OnClientEvent:Connect(onState)
	end)
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function()
		task.defer(apply)
	end)
	local look, step = 0, 0
	RunService.Heartbeat:Connect(function(dt: number)
		look -= dt
		step -= dt
		if look <= 0 then
			look = Presets.museumPlaques.lookSeconds
			apply() -- the museum streams in and out; its letters come back unlit
		end
		if step <= 0 then
			step = Presets.museumPlaques.rate
			if next(lit) ~= nil then
				breathe(os.clock())
			end
		end
	end)
end

return MuseumPlaques
