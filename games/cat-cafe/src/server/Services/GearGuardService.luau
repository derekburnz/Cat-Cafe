--!strict
-- GearGuardService: no avatar gear in game (#1062; shared/GearGuard). Removes every Tool or HopperBin the game did
-- not make (no CatCafeTool attribute) from each player's Backpack, StarterGear and character, as each arrives: at
-- join, at every spawn, and whenever one is added later (an equip moves a Tool from the Backpack to the character,
-- and a respawn makes a new Backpack). StarterGear is cleared too, so gear is not copied back in at the next spawn.
-- Accessories and clothing are left alone. Nothing here reads the client: there is no remote.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GearGuard = require(ReplicatedStorage.Shared.GearGuard)

local GearGuardService = {}

local CONTAINERS = { Backpack = true, StarterGear = true } -- the player's own children that hold Tools

local watched: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function sweepOne(instance: Instance)
	if GearGuard.isForeign(instance) then
		-- deferred: destroying a child during its own ChildAdded can warn, and an equip may still be reparenting it
		task.defer(function()
			if instance.Parent ~= nil and GearGuard.isForeign(instance) then
				instance:Destroy()
			end
		end)
	end
end

-- Clears `container` now and whenever a child is added to it, once per container.
local function watch(container: Instance)
	if watched[container] then
		return
	end
	watched[container] = true
	for _, child in container:GetChildren() do
		sweepOne(child)
	end
	container.ChildAdded:Connect(sweepOne)
end

local function onPlayer(player: Player)
	for _, child in player:GetChildren() do
		if CONTAINERS[child.Name] then
			watch(child)
		end
	end
	player.ChildAdded:Connect(function(child: Instance)
		if CONTAINERS[child.Name] then
			watch(child)
		end
	end)
	if player.Character ~= nil then
		watch(player.Character)
	end
	player.CharacterAdded:Connect(watch)
end

function GearGuardService.start()
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return GearGuardService
