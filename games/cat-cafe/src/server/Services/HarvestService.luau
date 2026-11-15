--!strict
-- #4251 Harvest Hollow, server side part 1 (harvest-hollow-spec sections 3 and 4; shared/HarvestSave holds the rules).
-- The area is open only between HarvestHollow.OPENS_AT and CLOSES_AT, from Tier 2, while the harvestHollow switch
-- is on (on by default: it is a kill switch, the dates do the opening).
--   BuyHarvest(id): a Harvest Stall item for pumpkins, within Config.HarvestStallRange + 4 studs of a part or model
--     tagged HarvestStall (the window closes past that on the client). Saved in profile.harvest.bought.
--   The Pumpkin Patch: every BasePart (or Model) tagged HarvestPumpkin is a pickup shared by the whole server. A
--     player who touches a ready one gets +1 and it regrows after HarvestSave.regrowSeconds (45 s with 6 or more
--     players near it, else 90 s). Attributes for the client: Ready (boolean) and RegrowAt (os.time).
--   Touches count only with the player's root within TOUCH_STUDS (plus half the part's size) of the spot.
--   The arrival: touching a part tagged HarvestArrival gives the first visit of the UTC day +10.
--   HarvestService.caught(player, rarity): pumpkins for a harvest cat caught and marks the player as a Feast Pie
--     helper (wired once the harvest cats are in the Catalog).
-- Nothing is random and nothing here costs Robux.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local HarvestHollow = require(ReplicatedStorage.Shared.HarvestHollow)
local HarvestSave = require(ReplicatedStorage.Shared.HarvestSave)
local Types = require(ReplicatedStorage.Shared.Types)

local CafeService = require(script.Parent.CafeService)
local DataService = require(script.Parent.DataService)
local Guard = require(script.Parent.Parent.Util.Guard)
local LiveFlagService = require(script.Parent.LiveFlagService)
local Net = require(script.Parent.Net)
local Telemetry = require(script.Parent.Telemetry)

local HarvestService = {}

HarvestService.STALL_TAG = "HarvestStall"
HarvestService.PUMPKIN_TAG = "HarvestPumpkin"
HarvestService.ARRIVAL_TAG = "HarvestArrival"
HarvestService.NEAR_STUDS = 90 -- "players in the area" for the busy regrow: within this of the picked spot
HarvestService.TOUCH_STUDS = 12 -- a touch counts only with the player's root this close (exploit tools fire touches)
local TOUCH_GAP = 0.5 -- one pick per player per half second, whatever the touch events do

local lastTouch: { [Player]: number } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root :: BasePart else nil
end

local function positionOf(instance: Instance): Vector3?
	if instance:IsA("BasePart") then
		return (instance :: BasePart).Position
	elseif instance:IsA("Model") then
		return (instance :: Model):GetPivot().Position
	end
	return nil
end

local function shut(player: Player): (Types.PlayerProfile?, string?)
	local profile = DataService.get(player)
	if profile == nil then
		return nil, "loading"
	end
	return profile,
		HarvestSave.areaBlocker(
			os.time(),
			Economy.tier(profile),
			LiveFlagService.on(HarvestSave.FLAG)
		)
end

local function nearStall(player: Player): boolean
	local root = rootOf(player)
	if root == nil then
		return false
	end
	local range = (Config.HarvestStallRange :: number) + 4
	for _, stall in CollectionService:GetTagged(HarvestService.STALL_TAG) do
		local at = positionOf(stall)
		if at ~= nil and (at - root.Position).Magnitude <= range then
			return true
		end
	end
	return false
end

local function onBuy(player: Player, rawId: unknown)
	local id = Guard.id(rawId)
	local profile = DataService.get(player)
	if id == nil or profile == nil then
		return
	end
	local function refuse(reason: string)
		Net.toast(player, reason, "warn")
		CafeService.sync(player) -- the Stall redraws from the server's view
	end
	local save = profile.harvest
	local reason = HarvestSave.buyBlocker(
		save,
		id,
		os.time(),
		Economy.tier(profile),
		LiveFlagService.on(HarvestSave.FLAG)
	)
	if reason == nil and not nearStall(player) then
		reason = "Walk up to the Harvest Stall first"
	end
	if reason ~= nil then
		refuse(reason :: string)
		return
	end
	local item = HarvestHollow.item(id) :: HarvestHollow.Item
	local before = save.pumpkins
	if not HarvestSave.buy(save, id) then
		refuse("You need more pumpkins")
		return
	end
	Telemetry.custom(
		player,
		"harvest_buy",
		before,
		{ item.id, "T" .. tostring(Economy.tier(profile)) }
	)
	Net.toast(player, string.format("%s, yours to keep!", item.name), "good")
	CafeService.sync(player)
end

local function playerFromHit(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	return if model ~= nil then Players:GetPlayerFromCharacter(model :: Model) else nil
end

local function touchedOk(player: Player): boolean
	local now = os.clock()
	local last = lastTouch[player]
	if last ~= nil and now - last < TOUCH_GAP then
		return false
	end
	lastTouch[player] = now
	return true
end

-- Whether the player stands at `instance` (its pivot or any of its parts within TOUCH_STUDS of the root).
local function standsAt(player: Player, instance: Instance): boolean
	local root = rootOf(player)
	local at = positionOf(instance)
	if root == nil or at == nil then
		return false
	end
	local reach = HarvestService.TOUCH_STUDS
	if instance:IsA("BasePart") then
		reach += (instance :: BasePart).Size.Magnitude / 2
	end
	return (root.Position - at).Magnitude <= reach
end

local function playersNear(at: Vector3): number
	local count = 0
	for _, other in Players:GetPlayers() do
		local root = rootOf(other)
		if root ~= nil and (root.Position - at).Magnitude <= HarvestService.NEAR_STUDS then
			count += 1
		end
	end
	return count
end

local function pick(spot: Instance, player: Player)
	if
		spot:GetAttribute("Ready") == false
		or not standsAt(player, spot)
		or not touchedOk(player)
	then
		return
	end
	local profile, reason = shut(player)
	if profile == nil or reason ~= nil then
		return
	end
	local at = positionOf(spot)
	if at == nil then
		return
	end
	spot:SetAttribute("Ready", false) -- before anything that yields, so two touches cannot both pick it
	local wait = HarvestSave.regrowSeconds(playersNear(at))
	spot:SetAttribute("RegrowAt", os.time() + wait)
	local added = HarvestSave.give(profile.harvest, 1)
	if added > 0 then
		Net.toast(player, "+1 pumpkin", "good")
		CafeService.sync(player)
	end
	task.delay(wait, function()
		if spot.Parent ~= nil then
			spot:SetAttribute("Ready", true)
			spot:SetAttribute("RegrowAt", nil)
		end
	end)
end

local function arrive(arrival: Instance, player: Player)
	if not standsAt(player, arrival) or not touchedOk(player) then
		return
	end
	local profile, reason = shut(player)
	if profile == nil or reason ~= nil then
		return
	end
	local added = HarvestSave.visit(profile.harvest, os.time())
	if added > 0 then
		Net.toast(player, string.format("Welcome to Harvest Hollow! +%d pumpkins", added), "good")
		CafeService.sync(player)
	end
end

local function touchPartsOf(instance: Instance): { BasePart }
	if instance:IsA("BasePart") then
		return { instance :: BasePart }
	end
	local parts: { BasePart } = {}
	for _, child in instance:GetDescendants() do
		if child:IsA("BasePart") then
			table.insert(parts, child :: BasePart)
		end
	end
	return parts
end

local function watchTag(tag: string, onTouch: (instance: Instance, player: Player) -> ())
	local function hook(instance: Instance)
		if tag == HarvestService.PUMPKIN_TAG and instance:GetAttribute("Ready") == nil then
			instance:SetAttribute("Ready", true)
		end
		for _, part in touchPartsOf(instance) do
			part.Touched:Connect(function(hit: BasePart)
				local player = playerFromHit(hit)
				if player ~= nil then
					onTouch(instance, player)
				end
			end)
		end
	end
	for _, instance in CollectionService:GetTagged(tag) do
		hook(instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(hook)
end

-- #4251: a harvest cat caught. Gives its pumpkins (Common 1 to Mythical 10) and marks the player as a Feast Pie
-- helper. Returns the pumpkins given (0 while the area is shut for this player).
function HarvestService.caught(player: Player, rarity: string): number
	local profile, reason = shut(player)
	if profile == nil or reason ~= nil then
		return 0
	end
	profile.harvest.helped = true
	return HarvestSave.give(profile.harvest, HarvestSave.catchPumpkins(rarity))
end

function HarvestService.start()
	Net.on("BuyHarvest", onBuy)
	watchTag(HarvestService.PUMPKIN_TAG, pick)
	watchTag(HarvestService.ARRIVAL_TAG, arrive)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastTouch[player] = nil
	end)
end

return HarvestService
