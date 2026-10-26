--!strict
-- Strays: spawning per area, the grab (lock, hold, roll), carrying a caught cat home, check-in, and lures.
-- Server authoritative: the client only reports when it pressed and released; distance, locks and odds live here.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AssetRegistry = require(script.Parent.Parent.World.AssetRegistry)
local CafeService = require(script.Parent.CafeService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Catching = require(ReplicatedStorage.Shared.Catching)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Guard = require(script.Parent.Parent.Util.Guard)
local Mover = require(ReplicatedStorage.Shared.Mover)
local Net = require(script.Parent.Net)
local PlotService = require(script.Parent.PlotService)
local Types = require(ReplicatedStorage.Shared.Types)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local CatService = {}

type Stray = {
	id: string,
	def: Types.CatDef,
	area: string,
	model: Model,
	body: BasePart,
	prompt: ProximityPrompt,
	spawnedAt: number,
	pointIndex: number?, -- spawn point it occupies, nil for lured strays
	lureSpotId: string?,
	home: Vector3,
	lockedBy: number,
	lockAt: number,
	reservedFor: number,
	calm: boolean,
	alive: boolean,
}

type Carry = { def: Types.CatDef, model: Model? }
type ActiveLure = {
	spotId: string,
	area: string,
	player: Player,
	lure: Types.LureDef,
	bowl: Model?,
	strayId: string?,
}

local world: WorldBuilder.World
local straysFolder: Folder
local strays: { [string]: Stray } = {}
local occupiedPoints: { [string]: { [number]: string } } = {} -- area -> point index -> stray id
local carrying: { [Player]: Carry } = {}
local activeLures: { [string]: ActiveLure } = {} -- lureSpotId -> lure
local lureByPlayer: { [Player]: string } = {} -- player -> lureSpotId
local rng = Random.new()
local nextStrayNumber = 0

-- Helpers -------------------------------------------------------------------------------------------------

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root ~= nil and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

local function withinRange(player: Player, position: Vector3, range: number): boolean
	local root = rootPosition(player)
	return root ~= nil and (root - position).Magnitude <= range
end

local function areaUnlocked(profile: Types.PlayerProfile, areaId: string): boolean
	local area = Catalog.getArea(areaId)
	if area == nil then
		return false
	end
	return area.unlock == nil or Economy.level(profile, area.unlock :: string) >= 1
end

local function countStrays(areaId: string): number
	local n = 0
	for _, stray in strays do
		if stray.area == areaId and stray.alive then
			n += 1
		end
	end
	return n
end

local function setLock(stray: Stray, userId: number)
	stray.lockedBy = userId
	stray.lockAt = os.clock()
	stray.model:SetAttribute("LockedBy", userId)
end

local function lockExpired(stray: Stray): boolean
	return os.clock() - stray.lockAt > Config.GrabLockSeconds
end

-- Spawning ------------------------------------------------------------------------------------------------

local function despawn(stray: Stray)
	if not stray.alive then
		return
	end
	stray.alive = false
	strays[stray.id] = nil
	if stray.pointIndex ~= nil then
		local points = occupiedPoints[stray.area]
		if points ~= nil and points[stray.pointIndex :: number] == stray.id then
			points[stray.pointIndex :: number] = nil
		end
	end
	if stray.lureSpotId ~= nil then
		local active = activeLures[stray.lureSpotId :: string]
		if active ~= nil and active.strayId == stray.id then
			activeLures[stray.lureSpotId :: string] = nil
			lureByPlayer[active.player] = nil
		end
	end
	stray.model:Destroy()
end

local function wander(stray: Stray)
	local area = world.areas[stray.area]
	local alive = function()
		return stray.alive and stray.lockedBy == 0
	end
	while stray.alive do
		task.wait(rng:NextNumber(3, 7))
		if not stray.alive or stray.lockedBy ~= 0 then
			continue
		end
		local radius = Config.StrayWanderRadius
		local target = stray.home
			+ Vector3.new(rng:NextNumber(-radius, radius), 0, rng:NextNumber(-radius, radius))
		local bounds = area.bounds
		target = Vector3.new(
			math.clamp(target.X, bounds.minX, bounds.maxX),
			area.floorY,
			math.clamp(target.Z, bounds.minZ, bounds.maxZ)
		)
		Mover.walkTo(stray.model, target, Config.StrayWanderSpeed, alive)
	end
end

local function spawnStray(
	def: Types.CatDef,
	areaId: string,
	position: Vector3,
	pointIndex: number?,
	lureSpotId: string?,
	calm: boolean,
	reservedFor: number,
	lifetime: number
): Stray
	nextStrayNumber += 1
	local id = string.format("stray_%d_%d", os.time() % 100000, nextStrayNumber)
	local model = AssetRegistry.clone(Catalog.catModelName(def.id))
	model.Name = id
	local body = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart") :: BasePart
	model:SetAttribute("StrayId", id)
	model:SetAttribute("CatId", def.id)
	model:SetAttribute("CatName", def.name)
	model:SetAttribute("Rarity", def.rarity)
	model:SetAttribute("Area", areaId)
	model:SetAttribute("LockedBy", 0)
	model:SetAttribute("ReservedFor", reservedFor)
	model:SetAttribute("SpawnedAt", os.time())
	model:SetAttribute("Calm", calm)
	CollectionService:AddTag(model, "Stray")

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GrabPrompt"
	prompt.ActionText = "Grab"
	prompt.ObjectText = def.name
	prompt.HoldDuration = Config.GrabHoldSeconds
	prompt.MaxActivationDistance = Config.GrabRangeStuds
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt:SetAttribute("CatId", def.id)
	prompt:SetAttribute("CatName", def.name)
	prompt:SetAttribute("Rarity", def.rarity)
	prompt:SetAttribute("StrayId", id)
	prompt.Parent = body

	model:PivotTo(CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	model.Parent = straysFolder

	local stray: Stray = {
		id = id,
		def = def,
		area = areaId,
		model = model,
		body = body,
		prompt = prompt,
		spawnedAt = os.clock(),
		pointIndex = pointIndex,
		lureSpotId = lureSpotId,
		home = position,
		lockedBy = 0,
		lockAt = 0,
		reservedFor = reservedFor,
		calm = calm,
		alive = true,
	}
	strays[id] = stray
	if pointIndex ~= nil then
		occupiedPoints[areaId] = occupiedPoints[areaId] or {}
		occupiedPoints[areaId][pointIndex] = id
	end

	task.spawn(wander, stray)
	task.delay(lifetime, function()
		-- Give a player mid-grab a moment, then leave.
		while stray.alive and stray.lockedBy ~= 0 and not lockExpired(stray) do
			task.wait(0.5)
		end
		if stray.alive then
			if lureSpotId ~= nil then
				local active = activeLures[lureSpotId]
				if active ~= nil and active.strayId == id and active.player.Parent == Players then
					local profile = DataService.get(active.player)
					if profile ~= nil then
						profile.lures[active.lure.id] = (profile.lures[active.lure.id] or 0) + 1
						Net.toast(
							active.player,
							string.format(
								"The %s wandered off. %s refunded.",
								def.name,
								active.lure.name
							),
							"info"
						)
						CafeService.sync(active.player)
					end
				end
			end
			despawn(stray)
		end
	end)
	return stray
end

local function freeSpawnPoint(areaId: string): number?
	local area = world.areas[areaId]
	local occupied = occupiedPoints[areaId] or {}
	local free: { number } = {}
	for i = 1, #area.spawnPoints do
		if occupied[i] == nil then
			table.insert(free, i)
		end
	end
	if #free == 0 then
		return nil
	end
	return free[rng:NextInteger(1, #free)]
end

local function spawnAt(areaId: string, pointIndex: number, rarity: Types.Rarity?)
	local areaDef = Catalog.getArea(areaId) :: Types.AreaDef
	local area = world.areas[areaId]
	local picked = rarity or Catching.pickRarity(areaDef.odds, rng:NextNumber())
	local def = Catching.pickCat(picked, areaId, rng:NextNumber())
	local point = area.spawnPoints[pointIndex]
	spawnStray(
		def,
		areaId,
		Vector3.new(point.Position.X, area.floorY, point.Position.Z),
		pointIndex,
		nil,
		false,
		0,
		areaDef.despawnAfter
	)
end

local function anyPlayerInTutorial(): boolean
	for _, player in DataService.loadedPlayers() do
		local profile = DataService.get(player)
		if profile ~= nil and profile.tutorialStep < Config.TutorialGuaranteedStrayStep then
			return true
		end
	end
	return false
end

local function tutorialTick()
	-- A beginner always finds a Common stray at alley point 1.
	if not anyPlayerInTutorial() then
		return
	end
	local occupied = occupiedPoints.alley or {}
	if occupied[1] ~= nil then
		return
	end
	for _, stray in strays do
		if stray.area == "alley" and stray.def.rarity == "Common" and stray.alive then
			return
		end
	end
	spawnAt("alley", 1, "Common")
end

local function runArea(areaDef: Types.AreaDef)
	-- First strays appear quickly so the alley is never empty on join.
	task.wait(2)
	for _ = 1, math.min(3, areaDef.maxStrays) do
		local point = freeSpawnPoint(areaDef.id)
		if point ~= nil then
			spawnAt(areaDef.id, point)
		end
	end
	while true do
		task.wait(areaDef.spawnInterval)
		if countStrays(areaDef.id) < areaDef.maxStrays then
			local point = freeSpawnPoint(areaDef.id)
			if point ~= nil then
				spawnAt(areaDef.id, point)
			end
		end
	end
end

-- Carrying ------------------------------------------------------------------------------------------------

local function attachHeldCat(player: Player, carry: Carry)
	local character = player.Character
	if character == nil then
		return
	end
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if torso == nil or not torso:IsA("BasePart") then
		return
	end
	if carry.model ~= nil then
		carry.model:Destroy()
	end
	local model = AssetRegistry.clone(Catalog.catModelName(carry.def.id))
	model.Name = "HeldCat"
	model:SetAttribute("CatId", carry.def.id)
	local body = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart") :: BasePart
	local nameTag = body:FindFirstChild("NameTag")
	if nameTag ~= nil then
		nameTag:Destroy()
	end
	model:PivotTo(torso.CFrame * CFrame.new(0, 0.4, -1.3) * CFrame.Angles(0, math.pi, 0))
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.Massless = true
			if part ~= body then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = body
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end
	local hold = Instance.new("WeldConstraint")
	hold.Name = "HoldWeld"
	hold.Part0 = torso
	hold.Part1 = body
	hold.Parent = body
	model.Parent = character
	carry.model = model
	if humanoid ~= nil then
		humanoid.WalkSpeed = Config.CarryWalkSpeed
	end
end

local function startCarry(player: Player, def: Types.CatDef)
	local carry: Carry = { def = def, model = nil }
	carrying[player] = carry
	attachHeldCat(player, carry)
	CafeService.setCarrying(player, def.id)
	Net.toast(player, string.format("You caught a %s! Walk it home to check in.", def.name), "good")
end

local function endCarry(player: Player): Types.CatDef?
	local carry = carrying[player]
	if carry == nil then
		return nil
	end
	carrying[player] = nil
	if carry.model ~= nil then
		carry.model:Destroy()
	end
	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid ~= nil then
		humanoid.WalkSpeed = Config.NormalWalkSpeed
	end
	return carry.def
end

-- Remote handlers -----------------------------------------------------------------------------------------

local function onGrabBegin(player: Player, rawStrayId: unknown)
	local strayId = Guard.id(rawStrayId)
	local profile = DataService.get(player)
	if strayId == nil or profile == nil then
		return
	end
	local stray = strays[strayId]
	if stray == nil or not stray.alive then
		return
	end
	if carrying[player] ~= nil then
		Net.toast(player, "Check in the cat you are carrying first.", "warn")
		return
	end
	if not areaUnlocked(profile, stray.area) then
		Net.toast(player, "You need the Park pass to catch cats here.", "warn")
		return
	end
	if stray.reservedFor ~= 0 and stray.reservedFor ~= player.UserId then
		Net.toast(player, "Someone else lured this cat.", "warn")
		return
	end
	if stray.lockedBy ~= 0 and stray.lockedBy ~= player.UserId and not lockExpired(stray) then
		Net.fire(player, "GrabResult", strayId, false, "Someone else is grabbing it", true)
		return
	end
	if not withinRange(player, stray.body.Position, Config.GrabRangeStuds + 2) then
		return
	end
	setLock(stray, player.UserId)
	profile.stats.grabsAttempted += 1
	local lockAt = stray.lockAt
	task.delay(Config.GrabLockSeconds, function()
		if stray.alive and stray.lockedBy == player.UserId and stray.lockAt == lockAt then
			setLock(stray, 0)
		end
	end)
end

local function onGrabEnd(player: Player, rawStrayId: unknown, rawRing: unknown)
	local strayId = Guard.id(rawStrayId)
	local ring = Guard.oneOf(rawRing, { "perfect", "good", "miss" }) :: Types.RingResult?
	local profile = DataService.get(player)
	if strayId == nil or ring == nil or profile == nil then
		return
	end
	local stray = strays[strayId]
	if stray == nil or not stray.alive or stray.lockedBy ~= player.UserId then
		return
	end
	if lockExpired(stray) then
		setLock(stray, 0)
		Net.fire(player, "GrabResult", strayId, false, "Too slow", true)
		return
	end
	if not withinRange(player, stray.body.Position, Config.GrabRangeStuds + 2) then
		setLock(stray, 0)
		Net.fire(player, "GrabResult", strayId, false, "Too far away", true)
		return
	end
	-- The ring result is client reported (its bonus is capped at 15%). A release faster than any human
	-- could time it is treated as a miss.
	if os.clock() - stray.lockAt < Config.GrabMinHoldSeconds then
		ring = "miss"
	end
	local lured = stray.calm and stray.reservedFor == player.UserId
	local chance = Catching.chance(stray.def.rarity, Economy.level(profile, "gloves"), lured, ring)
	local success = Catching.succeeds(chance, rng:NextNumber())
	setLock(stray, 0)

	if success then
		profile.stats.grabsSucceeded += 1
		local def = stray.def
		despawn(stray)
		Net.fire(player, "GrabResult", strayId, true, "caught", false)
		startCarry(player, def)
		return
	end

	if Catching.fleesOnMiss(stray.def.rarity) and not lured then
		Net.fire(player, "GrabResult", strayId, false, "It got away", false)
		Net.toast(player, "It got away", "warn")
		despawn(stray)
	else
		Net.fire(player, "GrabResult", strayId, false, "It slipped free, try again", true)
	end
end

local function finishCheckIn(player: Player, notify: boolean)
	local def = endCarry(player)
	if def == nil then
		return
	end
	local _, isNew = CafeService.addCaughtCat(player, def, notify)
	if notify then
		Net.fire(player, "CatCaught", def.id, isNew)
		if Catching.rarityAtLeast(def.rarity, Config.AnnounceMinRarity) then
			Net.fireAll(
				"Announce",
				string.format("%s caught a %s %s!", player.DisplayName, def.rarity, def.name)
			)
		end
	end
end

local function onCheckIn(player: Player)
	local carry = carrying[player]
	local plot = PlotService.get(player)
	if carry == nil or plot == nil then
		return
	end
	if not withinRange(player, plot.door.Position, Config.CheckInRangeStuds) then
		return
	end
	finishCheckIn(player, true)
end

local function onUseLure(player: Player, rawSpotId: unknown)
	local spotId = Guard.id(rawSpotId)
	local profile = DataService.get(player)
	if spotId == nil or profile == nil then
		return
	end
	local spotPart: BasePart? = nil
	local areaId: string? = nil
	for id, area in world.areas do
		local candidate = area.lureSpots[spotId]
		if candidate ~= nil then
			spotPart = candidate
			areaId = id
		end
	end
	if spotPart == nil or areaId == nil then
		return
	end
	if not areaUnlocked(profile, areaId) then
		Net.toast(player, "You need the Park pass to lure here.", "warn")
		return
	end
	if lureByPlayer[player] ~= nil then
		Net.toast(player, "You already have a lure out.", "warn")
		return
	end
	if activeLures[spotId] ~= nil then
		Net.toast(player, "That bowl is in use.", "warn")
		return
	end
	if not withinRange(player, (spotPart :: BasePart).Position, Config.GrabRangeStuds + 2) then
		return
	end
	local lure, reason = CafeService.consumeEquippedLure(player)
	if lure == nil then
		Net.toast(player, reason or "Cannot lure", "warn")
		return
	end

	local bowlAsset = if lure.id == "salmon"
		then "CatCafe_Item_FoodBowl_Premium"
		else "CatCafe_Item_FoodBowl"
	local bowl = AssetRegistry.clone(bowlAsset)
	bowl:PivotTo(CFrame.new((spotPart :: BasePart).Position))
	bowl.Parent = straysFolder
	local food = AssetRegistry.clone(lure.asset)
	food.Name = "Food"
	food:PivotTo(CFrame.new((spotPart :: BasePart).Position))
	food.Parent = bowl
	local active: ActiveLure =
		{ spotId = spotId, area = areaId, player = player, lure = lure, bowl = bowl, strayId = nil }
	activeLures[spotId] = active
	lureByPlayer[player] = spotId
	Net.toast(
		player,
		string.format(
			"%s is out. A cat will come in %d seconds.",
			lure.name,
			Config.LureWaitSeconds
		),
		"info"
	)

	task.delay(Config.LureWaitSeconds, function()
		if activeLures[spotId] ~= active then
			return
		end
		if bowl ~= nil then
			bowl:Destroy()
			active.bowl = nil
		end
		local rarity = Catching.pickRarity(lure.odds, rng:NextNumber())
		local def = Catching.pickCat(rarity, areaId :: string, rng:NextNumber())
		local area = world.areas[areaId :: string]
		local position = Vector3.new(
			(spotPart :: BasePart).Position.X,
			area.floorY,
			(spotPart :: BasePart).Position.Z
		)
		local stray = spawnStray(
			def,
			areaId :: string,
			position,
			nil,
			spotId,
			true,
			player.UserId,
			Config.LureDespawnSeconds
		)
		active.strayId = stray.id
		if player.Parent == Players then
			Net.toast(player, string.format("A %s came for the %s!", def.name, lure.name), "good")
		end
	end)
end

-- Lifecycle -----------------------------------------------------------------------------------------------

function CatService.start(builtWorld: WorldBuilder.World)
	world = builtWorld
	local folder = Instance.new("Folder")
	folder.Name = "Strays"
	folder.Parent = Workspace:FindFirstChild("World") or Workspace
	straysFolder = folder

	Net.on("GrabBegin", onGrabBegin)
	Net.on("GrabEnd", onGrabEnd)
	Net.on("CheckIn", onCheckIn)
	Net.on("UseLure", onUseLure)

	-- A player who leaves mid-carry keeps the cat.
	DataService.beforeRelease(function(player)
		if carrying[player] ~= nil then
			finishCheckIn(player, false)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			local carry = carrying[player]
			if carry ~= nil then
				attachHeldCat(player, carry)
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		carrying[player] = nil
		local spotId = lureByPlayer[player]
		if spotId ~= nil then
			lureByPlayer[player] = nil
			local active = activeLures[spotId]
			if active ~= nil and active.strayId == nil then
				if active.bowl ~= nil then
					active.bowl:Destroy()
				end
				activeLures[spotId] = nil
			end
		end
		for _, stray in strays do
			if stray.lockedBy == player.UserId then
				setLock(stray, 0)
			end
		end
	end)

	for _, areaDef in Catalog.areas do
		task.spawn(runArea, areaDef)
	end
	task.spawn(function()
		while true do
			task.wait(5)
			tutorialTick()
		end
	end)
end

function CatService.strayCount(areaId: string): number
	return countStrays(areaId)
end

return CatService
