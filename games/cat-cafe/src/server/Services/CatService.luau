--!strict
-- Strays: night waves per area, the net swing (lock, hold, roll), rescue spots, carrying a caught cat home,
-- check-in, and bait (lures in code). Server authoritative: the client only reports when it pressed and released;
-- distance, locks, timing and odds live here.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AssetRegistry = require(script.Parent.Parent.World.AssetRegistry)
local CafeService = require(script.Parent.CafeService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Catching = require(ReplicatedStorage.Shared.Catching)
local ClockService = require(script.Parent.ClockService)
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

-- A cat stuck at a rescue spot (data-model section 10). Not a Stray: no wander, no swing, a 4 s hold frees it.
type Stuck = {
	spotId: string,
	area: string,
	def: Types.CatDef,
	model: Model,
	spot: BasePart,
	lockedBy: number,
	holdAt: number, -- the holder's latest RescueBegin: times the hold and the lock's RescueLockSeconds
	lastHolder: number, -- kept after the lock drops, so a holder who lets go and grabs again is not new
	lockedSince: number, -- when lastHolder's run of locks began; capped at RESCUE_TENURE_SECONDS
	coolUserId: number, -- refused on this spot until coolUntil, after the cap ended their run
	coolUntil: number,
	alive: boolean,
}

type Carry = { def: Types.CatDef, model: Model?, rescued: boolean }
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
local stuckCats: { [string]: Stuck } = {} -- rescueSpotId -> stuck cat
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

-- One player's unbroken run of rescue locks on a spot ends after this long: room for two honest tries, and
-- tapping E cannot hold a spot against everyone else (reviewer S20).
local RESCUE_TENURE_SECONDS = 2 * Config.RescueLockSeconds

local function setRescueLock(entry: Stuck, userId: number)
	entry.lockedBy = userId
	if userId ~= 0 then
		entry.holdAt = os.clock()
		entry.lastHolder = userId
	end
	entry.model:SetAttribute("LockedBy", userId)
	entry.spot:SetAttribute("LockedBy", userId)
end

local function rescueLockExpired(entry: Stuck): boolean
	return os.clock() - entry.holdAt > Config.RescueLockSeconds
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
	lifetime: number? -- nil: stays until the next night start clears it
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
	prompt.ActionText = "Swing"
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
	if lifetime == nil then
		return stray
	end
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
	local picked: Types.Rarity = rarity or Catching.pickRarity(areaDef.odds, rng:NextNumber())
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
		nil
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

-- Night start (data-model section 9): last night's leftovers leave, then a full wave arrives at once. Bait
-- strays ignore the clock. A stray someone is mid-swing on leaves once that swing is over.
local function startWave(areaDef: Types.AreaDef)
	local leaving: { Stray } = {}
	for _, stray in strays do
		if stray.area == areaDef.id and stray.lureSpotId == nil then
			table.insert(leaving, stray)
		end
	end
	for _, stray in leaving do
		if stray.lockedBy ~= 0 and not lockExpired(stray) then
			task.spawn(function()
				while stray.alive and stray.lockedBy ~= 0 and not lockExpired(stray) do
					task.wait(0.5)
				end
				despawn(stray)
			end)
		else
			despawn(stray)
		end
	end
	for _ = 1, areaDef.waveSize do
		local point = freeSpawnPoint(areaDef.id)
		if point == nil then
			break
		end
		spawnAt(areaDef.id, point)
	end
end

-- Rescue spots ------------------------------------------------------------------------------------------

local function clearStuck(entry: Stuck)
	if not entry.alive then
		return
	end
	entry.alive = false
	if stuckCats[entry.spotId] == entry then
		stuckCats[entry.spotId] = nil
	end
	entry.spot:SetAttribute("Occupied", false)
	entry.spot:SetAttribute("LockedBy", 0)
	entry.model:Destroy()
end

local function spawnStuck(spotId: string, areaId: string, spot: BasePart, def: Types.CatDef): Stuck
	local model = AssetRegistry.clone(Catalog.catModelName(def.id))
	model.Name = "Stuck_" .. spotId
	local body = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart") :: BasePart
	-- Same attributes as a stray (section 13) minus StrayId, plus Rescue and RescueSpotId for the UI.
	model:SetAttribute("Rescue", true)
	model:SetAttribute("RescueSpotId", spotId)
	model:SetAttribute("CatId", def.id)
	model:SetAttribute("CatName", def.name)
	model:SetAttribute("Rarity", def.rarity)
	model:SetAttribute("Area", areaId)
	model:SetAttribute("LockedBy", 0)
	CollectionService:AddTag(model, "StuckCat")

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RescuePrompt"
	prompt.ActionText = "Rescue"
	prompt.ObjectText = def.name
	prompt.HoldDuration = Config.RescueHoldSeconds
	prompt.MaxActivationDistance = Config.GrabRangeStuds
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt:SetAttribute("CatId", def.id)
	prompt:SetAttribute("CatName", def.name)
	prompt:SetAttribute("Rarity", def.rarity)
	prompt:SetAttribute("Rescue", true)
	prompt:SetAttribute("RescueSpotId", spotId)
	prompt.Parent = body

	model:PivotTo(spot.CFrame)
	model.Parent = straysFolder
	spot:SetAttribute("Occupied", true)
	spot:SetAttribute("LockedBy", 0)

	local entry: Stuck = {
		spotId = spotId,
		area = areaId,
		def = def,
		model = model,
		spot = spot,
		lockedBy = 0,
		holdAt = 0,
		lastHolder = 0,
		lockedSince = 0,
		coolUserId = 0,
		coolUntil = 0,
		alive = true,
	}
	stuckCats[spotId] = entry
	return entry
end

local function rollStuckCat(spotId: string, areaDef: Types.AreaDef, spot: BasePart)
	local rarity: Types.Rarity =
		Catching.pickRarity(Catching.rescueOdds(areaDef.odds), rng:NextNumber())
	local def = Catching.pickCat(rarity, areaDef.id, rng:NextNumber())
	spawnStuck(spotId, areaDef.id, spot, def)
end

-- Night start: each spot drops last night's stuck cat and rolls RescueSpawnChance for a new one. A spot
-- someone is mid-rescue on keeps its cat; it rolls again next night.
local function rollRescues(areaDef: Types.AreaDef)
	local area = world.areas[areaDef.id]
	for spotId, spot in area.rescueSpots do
		local current = stuckCats[spotId]
		if current ~= nil and current.lockedBy ~= 0 and not rescueLockExpired(current) then
			continue
		end
		if current ~= nil then
			clearStuck(current)
		end
		if rng:NextNumber() < Config.RescueSpawnChance then
			rollStuckCat(spotId, areaDef, spot)
		end
	end
end

local function onPhaseChanged(phase: Types.ClockPhase)
	if phase ~= "night" then
		return
	end
	for _, areaDef in Catalog.areas do
		startWave(areaDef)
		rollRescues(areaDef)
	end
end

-- Carrying ------------------------------------------------------------------------------------------------

local function attachHeldCat(player: Player, carry: Carry)
	local character = player.Character
	if character == nil then
		return
	end
	local torsoInstance = character:FindFirstChild("UpperTorso")
		or character:FindFirstChild("Torso")
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid?
	if torsoInstance == nil or not torsoInstance:IsA("BasePart") then
		return
	end
	local torso = torsoInstance :: BasePart
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
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
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

-- Callers check carrying first; the refusal here keeps one carry per player whatever path calls it.
local function startCarry(player: Player, def: Types.CatDef, rescued: boolean): boolean
	if carrying[player] ~= nil then
		warn(
			string.format(
				"[CatService] %s already carries a cat; %s not carried",
				player.Name,
				def.id
			)
		)
		return false
	end
	local carry: Carry = { def = def, model = nil, rescued = rescued }
	carrying[player] = carry
	attachHeldCat(player, carry)
	CafeService.setCarrying(player, def.id)
	local verb = if rescued then "rescued" else "caught"
	Net.toast(
		player,
		string.format("You %s a %s! Walk it home to check in.", verb, def.name),
		"good"
	)
	return true
end

local function endCarry(player: Player): Carry?
	local carry = carrying[player]
	if carry == nil then
		return nil
	end
	carrying[player] = nil
	if carry.model ~= nil then
		carry.model:Destroy()
	end
	local character = player.Character
	local humanoid = if character ~= nil
		then character:FindFirstChildOfClass("Humanoid") :: Humanoid?
		else nil
	if humanoid ~= nil then
		humanoid.WalkSpeed = Config.NormalWalkSpeed
	end
	return carry
end

-- Rolls the catch for a stray the player has locked and tells them the outcome. The ring result comes from the
-- server's own clock (Catching.ringResultFromHold), so a scripted client gains nothing by lying about timing.
local function resolveGrab(
	player: Player,
	profile: Types.PlayerProfile,
	stray: Stray,
	ring: Types.RingResult
)
	-- A rescue can finish while this swing is in flight (reviewer S21); the carried cat wins.
	if carrying[player] ~= nil then
		setLock(stray, 0)
		Net.fire(
			player,
			"GrabResult",
			stray.id,
			false,
			"Check in the cat you are carrying first",
			true
		)
		return
	end
	local lured = stray.calm and stray.reservedFor == player.UserId
	local chance = Catching.chance(stray.def.rarity, Economy.level(profile, "net"), lured, ring)
	local success = Catching.succeeds(chance, rng:NextNumber())
	setLock(stray, 0)

	if success then
		profile.stats.grabsSucceeded += 1
		local def = stray.def
		despawn(stray)
		Net.fire(player, "GrabResult", stray.id, true, "caught", false)
		startCarry(player, def, false)
		return
	end

	if Catching.fleesOnMiss(stray.def.rarity) and not lured then
		Net.fire(player, "GrabResult", stray.id, false, "It got away", false)
		Net.toast(player, "It got away", "warn")
		despawn(stray)
	else
		Net.fire(player, "GrabResult", stray.id, false, "It slipped free, try again", true)
	end
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
		Net.toast(player, "Someone else baited this cat.", "warn")
		return
	end
	if stray.lockedBy ~= 0 and stray.lockedBy ~= player.UserId and not lockExpired(stray) then
		Net.fire(player, "GrabResult", strayId, false, "Someone else is grabbing it", true)
		return
	end
	if not withinRange(player, stray.body.Position, Config.GrabRangeStuds + 2) then
		Net.fire(player, "GrabResult", strayId, false, "Too far away", true)
		return
	end
	setLock(stray, player.UserId)
	profile.stats.grabsAttempted += 1
	local lockAt = stray.lockAt
	-- A hold that runs to completion sends no GrabEnd (data-model section 10): once the hold plus the latency
	-- grace has passed with the lock untouched, the server resolves the attempt itself as a ring miss.
	task.delay(Config.GrabHoldSeconds + Config.RingLatencyGraceSeconds, function()
		if not (stray.alive and stray.lockedBy == player.UserId and stray.lockAt == lockAt) then
			return
		end
		local current = DataService.get(player)
		if current == nil or player.Parent ~= Players then
			setLock(stray, 0)
			return
		end
		if not withinRange(player, stray.body.Position, Config.GrabRangeStuds + 2) then
			setLock(stray, 0)
			Net.fire(player, "GrabResult", strayId, false, "Too far away", true)
			return
		end
		resolveGrab(player, current, stray, "miss")
	end)
	-- Whatever happens, the lock never outlives GrabLockSeconds.
	task.delay(Config.GrabLockSeconds, function()
		if stray.alive and stray.lockedBy == player.UserId and stray.lockAt == lockAt then
			setLock(stray, 0)
		end
	end)
end

local function onGrabEnd(player: Player, rawStrayId: unknown)
	-- Extra arguments (the old client-reported ring) are ignored: the ring is scored from the lock age.
	local strayId = Guard.id(rawStrayId)
	local profile = DataService.get(player)
	if strayId == nil or profile == nil then
		return
	end
	local stray = strays[strayId]
	if stray == nil or not stray.alive or stray.lockedBy ~= player.UserId then
		return
	end
	local ring: Types.RingResult? = Catching.ringResultFromHold(os.clock() - stray.lockAt)
	if ring == nil then
		return -- sooner than GrabMinHoldSeconds: dropped as spam, the lock and the hold timer continue
	end
	if not withinRange(player, stray.body.Position, Config.GrabRangeStuds + 2) then
		setLock(stray, 0)
		Net.fire(player, "GrabResult", strayId, false, "Too far away", true)
		return
	end
	resolveGrab(player, profile, stray, ring)
end

-- `profile` is passed on the save-on-leave path, where the session is closing and a lookup must not race it.
local function finishCheckIn(player: Player, notify: boolean, profile: Types.PlayerProfile?)
	local carry = endCarry(player)
	if carry == nil then
		return
	end
	local def = carry.def
	local _, isNew = CafeService.addCaughtCat(player, def, notify, profile, nil, carry.rescued)
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

-- Rescue: RescueBegin locks the spot to the player for RescueLockSeconds; RescueEnd after the full hold always
-- frees the cat (no ring, no roll). The hold is timed on the server's clock from RescueBegin. Every rejection
-- answers with GrabResult so the client's hold bar never waits on nothing.
local function rejectRescue(player: Player, spotId: string, reason: string)
	Net.fire(player, "GrabResult", spotId, false, reason, true)
end

local function onRescueBegin(player: Player, rawSpotId: unknown)
	local spotId = Guard.id(rawSpotId)
	local profile = DataService.get(player)
	if spotId == nil or profile == nil then
		return
	end
	local entry = stuckCats[spotId]
	if entry == nil or not entry.alive then
		return
	end
	if carrying[player] ~= nil then
		rejectRescue(player, spotId, "Check in the cat you are carrying first")
		return
	end
	if not areaUnlocked(profile, entry.area) then
		rejectRescue(player, spotId, "You need the Park pass to rescue cats here")
		return
	end
	local now = os.clock()
	if entry.coolUserId == player.UserId and now < entry.coolUntil then
		rejectRescue(player, spotId, "Give someone else a turn, then try again")
		return
	end
	if entry.lockedBy ~= 0 and entry.lockedBy ~= player.UserId and not rescueLockExpired(entry) then
		rejectRescue(player, spotId, "Someone else is rescuing it")
		return
	end
	if not withinRange(player, entry.spot.Position, Config.GrabRangeStuds + 2) then
		rejectRescue(player, spotId, "Too far away")
		return
	end
	-- A holder who presses again within the lock window, whether the lock is still theirs or they dropped it
	-- with a short RescueEnd, continues the same run. A run past RESCUE_TENURE_SECONDS ends, and that player
	-- waits RescueLockSeconds on this spot so someone else can step in (reviewer S20).
	local continuing = entry.lastHolder == player.UserId
		and now - entry.holdAt <= Config.RescueLockSeconds
	if not continuing then
		entry.lockedSince = now
	elseif now - entry.lockedSince > RESCUE_TENURE_SECONDS then
		if entry.lockedBy == player.UserId then
			setRescueLock(entry, 0)
		end
		entry.lastHolder = 0
		entry.coolUserId = player.UserId
		entry.coolUntil = now + Config.RescueLockSeconds
		rejectRescue(player, spotId, "Give someone else a turn, then try again")
		return
	end
	-- One rescue at a time per player, so nobody can hold every spot locked.
	for _, other in stuckCats do
		if other ~= entry and other.lockedBy == player.UserId then
			setRescueLock(other, 0)
		end
	end
	setRescueLock(entry, player.UserId)
	local holdAt = entry.holdAt
	task.delay(Config.RescueLockSeconds, function()
		if entry.alive and entry.lockedBy == player.UserId and entry.holdAt == holdAt then
			setRescueLock(entry, 0)
		end
	end)
end

local function onRescueEnd(player: Player, rawSpotId: unknown)
	local spotId = Guard.id(rawSpotId)
	local profile = DataService.get(player)
	if spotId == nil or profile == nil then
		return
	end
	local entry = stuckCats[spotId]
	if entry == nil or not entry.alive then
		Net.fire(player, "GrabResult", spotId, false, "Someone else got there first", false)
		return
	end
	if entry.lockedBy ~= player.UserId then
		rejectRescue(player, spotId, "Hold again to rescue it")
		return
	end
	-- RescueEnd travels later than RescueBegin by however much the two trips' latency differs; the same
	-- allowance as the swing ring's (RingLatencyGraceSeconds) keeps an honest full hold from reading as short.
	local held = os.clock() - entry.holdAt
	if held < Config.RescueHoldSeconds - Config.RingLatencyGraceSeconds then
		setRescueLock(entry, 0)
		rejectRescue(
			player,
			spotId,
			string.format("Hold for the full %g seconds", Config.RescueHoldSeconds)
		)
		return
	end
	if carrying[player] ~= nil then
		setRescueLock(entry, 0)
		rejectRescue(player, spotId, "Check in the cat you are carrying first")
		return
	end
	if not withinRange(player, entry.spot.Position, Config.GrabRangeStuds + 2) then
		setRescueLock(entry, 0)
		rejectRescue(player, spotId, "Too far away")
		return
	end
	local def = entry.def
	clearStuck(entry)
	Net.fire(player, "GrabResult", spotId, true, "rescued", false)
	startCarry(player, def, true)
end

local function findLureSpot(spotId: string): (BasePart?, string?)
	for id, area in world.areas do
		local candidate: BasePart? = area.lureSpots[spotId]
		if candidate ~= nil then
			return candidate, id
		end
	end
	return nil, nil
end

local function onUseLure(player: Player, rawSpotId: unknown)
	local spotId = Guard.id(rawSpotId)
	local profile = DataService.get(player)
	if spotId == nil or profile == nil then
		return
	end
	local foundSpot, foundArea = findLureSpot(spotId)
	if foundSpot == nil or foundArea == nil then
		return
	end
	local spotPart: BasePart = foundSpot
	local areaId: string = foundArea
	if not areaUnlocked(profile, areaId) then
		Net.toast(player, "You need the Park pass to set bait here.", "warn")
		return
	end
	if lureByPlayer[player] ~= nil then
		Net.toast(player, "You already have bait out.", "warn")
		return
	end
	if activeLures[spotId] ~= nil then
		Net.toast(player, "That bowl is in use.", "warn")
		return
	end
	if not withinRange(player, spotPart.Position, Config.GrabRangeStuds + 2) then
		return
	end
	local lure, reason = CafeService.consumeEquippedLure(player)
	if lure == nil then
		Net.toast(player, reason or "Cannot set bait", "warn")
		return
	end

	local bowlAsset = if lure.id == "salmon"
		then "CatCafe_Item_FoodBowl_Premium"
		else "CatCafe_Item_FoodBowl"
	local bowl = AssetRegistry.clone(bowlAsset)
	bowl:PivotTo(CFrame.new(spotPart.Position))
	bowl.Parent = straysFolder
	local food = AssetRegistry.clone(lure.asset)
	food.Name = "Food"
	food:PivotTo(CFrame.new(spotPart.Position))
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
		local placedBowl = active.bowl
		if placedBowl ~= nil then
			placedBowl:Destroy()
			active.bowl = nil
		end
		local rarity: Types.Rarity = Catching.pickRarity(lure.odds, rng:NextNumber())
		local def = Catching.pickCat(rarity, areaId, rng:NextNumber())
		local area = world.areas[areaId]
		local position = Vector3.new(spotPart.Position.X, area.floorY, spotPart.Position.Z)
		local stray = spawnStray(
			def,
			areaId,
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
	Net.on("RescueBegin", onRescueBegin)
	Net.on("RescueEnd", onRescueEnd)
	Net.on("CheckIn", onCheckIn)
	Net.on("UseLure", onUseLure)

	-- A player who leaves mid-carry keeps the cat. The finalizer runs before the session closes and is handed
	-- the profile, so it never depends on a lookup that is about to go nil.
	DataService.beforeRelease(function(player, profile)
		if carrying[player] ~= nil then
			finishCheckIn(player, false, profile)
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
		-- endCarry (via the finalizer above) clears the carry record; this only mops up when the profile is
		-- already gone, so the handler order between services does not matter.
		if carrying[player] ~= nil and DataService.get(player) == nil then
			carrying[player] = nil
		end
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
		for _, entry in stuckCats do
			if entry.lockedBy == player.UserId then
				setRescueLock(entry, 0)
			end
		end
	end)

	-- No trickle by day: every stray arrives with a night wave (or the tutorial rule, or bait).
	ClockService.changed:Connect(onPhaseChanged)
	if ClockService.isNight() then
		onPhaseChanged("night")
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

-- How many rescue spots hold a stuck cat right now, across all areas.
function CatService.stuckCount(): number
	local n = 0
	for _ in stuckCats do
		n += 1
	end
	return n
end

-- Studio-only test hook: spawns a given cat at a free spawn point of the area (or point 1 if all are taken).
function CatService.debugSpawnStray(catId: string, areaId: string): string
	assert(RunService:IsStudio(), "debugSpawnStray is Studio only")
	local def = Catalog.getCat(catId)
	local areaDef = Catalog.getArea(areaId)
	assert(def ~= nil and areaDef ~= nil, "unknown cat or area")
	local area = world.areas[areaId]
	local pointIndex = freeSpawnPoint(areaId) or 1
	local point = area.spawnPoints[pointIndex]
	local stray = spawnStray(
		def :: Types.CatDef,
		areaId,
		Vector3.new(point.Position.X, area.floorY, point.Position.Z),
		pointIndex,
		nil,
		false,
		0,
		Config.StrayDespawnSeconds
	)
	return stray.id
end

-- Studio-only test hook: puts a stuck cat at a rescue spot (the first spot of the alley when none is given),
-- replacing any cat already there. Returns the rescueSpotId.
function CatService.debugSpawnStuck(catId: string, spotId: string?): string
	assert(RunService:IsStudio(), "debugSpawnStuck is Studio only")
	local def = Catalog.getCat(catId)
	assert(def ~= nil, "unknown cat")
	local wanted = spotId or "rescue_alley_1"
	for areaId, area in world.areas do
		local spot: BasePart? = area.rescueSpots[wanted]
		if spot ~= nil then
			local current = stuckCats[wanted]
			if current ~= nil then
				clearStuck(current)
			end
			spawnStuck(wanted, areaId, spot, def :: Types.CatDef)
			return wanted
		end
	end
	error("unknown rescue spot " .. wanted)
end

return CatService
