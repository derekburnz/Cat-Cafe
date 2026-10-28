--!strict
-- Potions (F64, data-model sections 12b and 13). UsePotion drinks one from the bag (the rules are shared/Potions),
-- and the character attribute ActivePotions names the running ones, oldest drink first, for the glow everyone
-- nearby sees. The effects are read where they apply: Economy.settle and CafeService's rate (Tip), RichTipService
-- (Tip), BaitService (Lucky) and CatService's walk speeds (Swift) and circles (Steady). Timers count play time only:
-- Economy.settle counts them down and DataService.load resets lastTick, so time away runs none of them down.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CafeService = require(script.Parent.CafeService)
local CatService = require(script.Parent.CatService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local ClockService = require(script.Parent.ClockService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Net = require(script.Parent.Net)
local Potions = require(ReplicatedStorage.Shared.Potions)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)

local PotionService = {}

-- Each player's running potions in drink order, oldest first. Not saved: a join orders them by time left, least
-- first (data-model 13).
local order: { [Player]: { string } } = {}

local function showActive(player: Player)
	local character = player.Character
	if character ~= nil then
		character:SetAttribute("ActivePotions", table.concat(order[player] or {}, ","))
	end
end

-- Takes the potions that ran out off the player's drink order. Returns the ids taken off.
local function prune(player: Player, profile: Types.PlayerProfile, now: number): { string }
	local list = order[player]
	local ended: { string } = {}
	if list == nil then
		return ended
	end
	local kept: { string } = {}
	for _, id in list do
		table.insert(if Potions.running(profile, id, now) then kept else ended, id)
	end
	order[player] = kept
	return ended
end

local function onUsePotion(player: Player, rawId: unknown)
	if type(rawId) ~= "string" then
		return
	end
	local def = Catalog.getPotion(rawId)
	local profile = DataService.get(player)
	if def == nil or profile == nil then
		return
	end
	local now = os.time()
	-- the time so far is paid at the old multipliers before this potion starts
	Economy.settle(profile, now, ClockService.epoch())
	local blocker = Potions.useBlocker(profile, def.id, now)
	if blocker == "Full" then
		Net.toast(
			player,
			string.format("%s is full: up to %d minutes at once", def.name, Config.PotionMaxMinutes),
			"warn"
		)
		return
	elseif blocker ~= nil then
		return -- none in the bag: the bag's Use button is grey, so only a stale or forged call lands here
	end
	Potions.use(profile, def.id, now)
	local list = order[player] or {}
	local at = table.find(list, def.id)
	if at ~= nil then
		table.remove(list, at) -- a kind already running moves to the end, as the newest drink
	end
	table.insert(list, def.id)
	order[player] = list
	showActive(player)
	if def.id == Potions.SWIFT then
		CatService.refreshSpeed(player)
	end
	Telemetry.custom(player, "potion_used", 1, { def.id, tostring(Economy.tier(profile)) })
	CafeService.sync(player)
end

-- Once a second: potions that ran out leave ActivePotions, a Swift Potion's speed goes and the rate is synced, so
-- the HUD never shows a Tip Potion's income past its end.
local function checkExpiries()
	local now = os.time()
	for player in order do
		local profile = DataService.get(player)
		if profile == nil then
			continue
		end
		local ended = prune(player, profile, now)
		if #ended > 0 then
			showActive(player)
			if table.find(ended, Potions.SWIFT) ~= nil then
				CatService.refreshSpeed(player)
			end
			CafeService.sync(player)
		end
	end
end

-- A join with time left on some potions (they paused while away): they show again, least time left first, and a
-- Swift Potion's speed comes back.
local function onLoaded(player: Player, profile: Types.PlayerProfile)
	order[player] = Potions.runningIds(profile, os.time())
	showActive(player)
	if table.find(order[player], Potions.SWIFT) ~= nil then
		CatService.refreshSpeed(player)
	end
end

function PotionService.start()
	Net.on("UsePotion", onUsePotion)
	DataService.onLoaded:Connect(onLoaded)
	local function watch(player: Player)
		-- a respawn shows the running potions again (CatService sets the speed on every spawn)
		player.CharacterAdded:Connect(function()
			showActive(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		order[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			checkExpiries()
		end
	end)
end

return PotionService
