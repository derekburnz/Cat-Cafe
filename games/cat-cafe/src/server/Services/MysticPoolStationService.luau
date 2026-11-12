--!strict
-- #3196 (trait-station.md section 1): which of the two stations stands on the Park camp's picnic spot. WorldBuilder
-- builds both, the Picnic Basket and the Mystic Pool, each with its floor ring. While the `traits` switch is on the
-- pool stands there and the basket waits in ServerStorage; off, the other way round. The switch is read every
-- CHECK_SECONDS, so turning it on or off swaps the station in every running server with no publish and no restart.
-- A station that is put away is not in the world for any client, so its ring, prompt and "!" go with it.
-- Without the pool's art (WorldBuilder built none) the basket always stays.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CampExtras = require(ReplicatedStorage.Shared.CampExtras)
local LiveFlagService = require(script.Parent.LiveFlagService)
local Traits = require(ReplicatedStorage.Shared.Traits)
local WalkUp = require(ReplicatedStorage.Shared.WalkUp)

local MysticPoolStationService = {}

local CHECK_SECONDS = 2
local STORE = "MysticPoolSwap"

type Station = { model: Model, ring: Instance?, home: Instance }

local pool: Station? = nil
local basket: Station? = nil
local shown: boolean? = nil -- whether the pool is the one standing; nil before the first pass

local function store(): Folder
	local found = ServerStorage:FindFirstChild(STORE)
	if found ~= nil and found:IsA("Folder") then
		return found :: Folder
	end
	local made = Instance.new("Folder")
	made.Name = STORE
	made.Parent = ServerStorage
	return made
end

local function stationOf(model: Instance): Station?
	local home = model.Parent
	if not model:IsA("Model") or home == nil then
		return nil
	end
	local link = model:FindFirstChild(WalkUp.CIRCLE)
	local ring = if link ~= nil and link:IsA("ObjectValue") then link.Value else nil
	return { model = model :: Model, ring = ring, home = home }
end

-- Finds the two stations once; false until both are built.
local function find(): boolean
	if pool == nil then
		local tagged = CollectionService:GetTagged(Traits.TAG)[1]
		if tagged ~= nil then
			pool = stationOf(tagged)
		end
	end
	if basket == nil then
		for _, model in CollectionService:GetTagged(CampExtras.TAG) do
			if model:GetAttribute("ExtraId") == Traits.STATION_EXTRA then
				basket = stationOf(model)
				break
			end
		end
	end
	return pool ~= nil and basket ~= nil
end

local function put(station: Station, standing: boolean)
	local parent: Instance = if standing then station.home else store()
	station.model.Parent = parent
	local ring = station.ring
	if ring ~= nil then
		ring.Parent = parent
	end
end

-- One pass: the pool stands while the switch is on. Returns whether the pool is the one standing.
function MysticPoolStationService.apply(): boolean
	if not find() then
		return false
	end
	local on = LiveFlagService.on(Traits.FLAG)
	if shown ~= on then
		shown = on
		put(pool :: Station, on)
		put(basket :: Station, not on)
	end
	return on
end

-- Whether the pool is the station standing right now. False while the switch is off, and also when the pool was
-- never built (no art), so the basket keeps working then (CampExtraService asks this).
function MysticPoolStationService.standing(): boolean
	return shown == true
end

function MysticPoolStationService.start()
	task.spawn(function()
		while true do
			local ok, err = pcall(MysticPoolStationService.apply)
			if not ok then
				warn("[MysticPoolStationService] " .. tostring(err))
			end
			task.wait(CHECK_SECONDS)
		end
	end)
end

return MysticPoolStationService
