--!strict
-- Derek 2026-11-18: the areaWhole switch (shared/AreaWhole). Every AreaWhole.STEP seconds it reads the switch and,
-- when it has changed, sets every catching area's Model to PersistentPerPlayer (on) or Default (off, as WorldBuilder
-- builds it). With it on, each player is added to the one area Model they stand in (WorldBuilder.areaAt) and taken
-- off the one they held before, so their device keeps that whole area and only that one. A cannon flight calls
-- AreaWholeService.heading at launch, so the area streams in during the flight and not all at the landing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AreaWhole = require(ReplicatedStorage.Shared.AreaWhole)
local LiveFlagService = require(script.Parent.LiveFlagService)
local PlotService = require(script.Parent.PlotService)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local AreaWholeService = {}

local switchOn = false
local held: { [Player]: string } = {} -- the area each player's device is keeping whole
local flying: { [Player]: AreaWhole.Flight } = {} -- a cannon flight's destination, until they stand in it

local function areaModel(areaId: string): Model?
	local ok, world = pcall(PlotService.world)
	if not ok or world == nil then
		return nil
	end
	local info = world.areas[areaId]
	return if info ~= nil then info.model else nil
end

local function release(player: Player, areaId: string)
	local model = areaModel(areaId)
	if model ~= nil then
		pcall(function()
			model:RemovePersistentPlayer(player)
		end)
	end
end

local function keep(player: Player, areaId: string?)
	local before = held[player]
	if areaId == before then
		return
	end
	if before ~= nil then
		release(player, before)
		held[player] = nil
	end
	if areaId == nil then
		return
	end
	local model = areaModel(areaId)
	if model ~= nil and model.ModelStreamingMode == Enum.ModelStreamingMode.PersistentPerPlayer then
		local ok = pcall(function()
			model:AddPersistentPlayer(player)
		end)
		if ok then
			held[player] = areaId
		end
	end
end

local function standingIn(player: Player): string?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	local ok, world = pcall(PlotService.world)
	if not ok or world == nil then
		return nil
	end
	return WorldBuilder.areaAt(world, (root :: BasePart).Position)
end

local function apply(on: boolean)
	switchOn = on
	local ok, world = pcall(PlotService.world)
	if not ok or world == nil then
		return
	end
	if not on then
		for player, areaId in held do
			release(player, areaId)
		end
		table.clear(held)
		table.clear(flying)
	end
	local mode = AreaWhole.mode(on)
	for _, info in world.areas do
		if info.model.ModelStreamingMode ~= mode then
			info.model.ModelStreamingMode = mode
		end
	end
end

local function step()
	for _, player in Players:GetPlayers() do
		local area, flightStands =
			AreaWhole.pick(flying[player], os.clock(), standingIn(player), held[player])
		if not flightStands then
			flying[player] = nil
		end
		keep(player, area)
	end
end

-- A cannon flight to `areaId` has started (CannonService): the device gets that area during the flight. The town and
-- anything that is not a catching area are left alone.
function AreaWholeService.heading(player: Player, areaId: string)
	if not switchOn or areaModel(areaId) == nil then
		return
	end
	flying[player] = { area = areaId, untilAt = os.clock() + AreaWhole.FLIGHT_HOLD }
	keep(player, areaId)
end

-- The area this player's device is keeping whole, or nil (Debug and specs).
function AreaWholeService.heldBy(player: Player): string?
	return held[player]
end

function AreaWholeService.start()
	Players.PlayerRemoving:Connect(function(player: Player)
		held[player] = nil
		flying[player] = nil
	end)
	task.spawn(function()
		local last: boolean? = nil
		while true do
			local on = LiveFlagService.on(AreaWhole.FLAG)
			if on ~= last then
				last = on
				apply(on)
			end
			if on then
				local ok, err = pcall(step)
				if not ok then
					warn("[AreaWholeService] " .. tostring(err))
				end
			end
			task.wait(AreaWhole.STEP)
		end
	end)
end

return AreaWholeService
