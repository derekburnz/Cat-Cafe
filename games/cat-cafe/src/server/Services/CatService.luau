--!strict
-- Strays: night waves per area, the net (lock, closing circles, roll), rescue spots, carrying a caught cat home,
-- check-in, and bait (lures in code). Server authoritative: the client only says which circle it pressed for;
-- distance, locks, the schedule, the press times and odds live here.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AssetRegistry = require(script.Parent.Parent.World.AssetRegistry)
local CafeService = require(script.Parent.CafeService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Catching = require(ReplicatedStorage.Shared.Catching)
local Circles = require(ReplicatedStorage.Shared.Circles)
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
	lockUntil: number, -- server time the lock lapses on its own; 0 when unlocked
	attempt: Circles.Attempt?, -- the circles of the lock holder's catch in progress
	retryUserId: number, -- the player whose catch just failed waits until retryUntil (server time) on this stray
	retryUntil: number,
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
local circleHistory: { [Player]: { boolean } } = {} -- last judged circles per player, true for Perfect (S23)
local lastCatchStart: { [Player]: number } = {} -- server time of the player's last GrabBegin that started circles
local rng = Random.new()
local nextStrayNumber = 0

local MAX_CIRCLES = 1 -- the most circles any rarity has; bounds the CatchPress index
for _, rarity in Catalog.rarities do
	MAX_CIRCLES = math.max(MAX_CIRCLES, rarity.circles)
end

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
	return Economy.tier(profile) >= area.tier
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

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

-- Locks a stray to a player until `untilTime` (server time), or unlocks it (userId 0), dropping any attempt.
local function setLock(stray: Stray, userId: number, untilTime: number?)
	stray.lockedBy = userId
	stray.lockUntil = if userId ~= 0 then untilTime or 0 else 0
	if userId == 0 then
		stray.attempt = nil
	end
	stray.model:SetAttribute("LockedBy", userId)
end

local function lockExpired(stray: Stray): boolean
	return serverNow() > stray.lockUntil
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
	prompt.HoldDuration = 0 -- one press starts the circles (data-model section 10)
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
		lockUntil = 0,
		attempt = nil,
		retryUserId = 0,
		retryUntil = 0,
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

-- The carried pose from the asset manifest (poses.carried.body_cframe_roblox): cradled across the chest, facing
-- the character's left so the camera behind the player sees the cat side on. Relative to the HumanoidRootPart.
local CARRIED_POSE = CFrame.new(0, -0.4, -1.05, 0, 0, 1, 0, 1, 0, -1, 0, 0)

local function attachHeldCat(player: Player, carry: Carry)
	local character = player.Character
	if character == nil then
		return
	end
	local rootInstance = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid?
	if rootInstance == nil or not rootInstance:IsA("BasePart") then
		return
	end
	local root = rootInstance :: BasePart
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
	model:PivotTo(root.CFrame * CARRIED_POSE)
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
	hold.Part0 = root
	hold.Part1 = body
	hold.Parent = body
	model.Parent = character
	carry.model = model
	if humanoid ~= nil then
		humanoid.WalkSpeed = Config.CarryWalkSpeed
	end
end

-- "an Epic Maine Coon", "a Tabby": the article for the word that follows it.
local function withArticle(phrase: string): string
	return (if phrase:match("^[AEIOUaeiou]") then "an " else "a ") .. phrase
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
		string.format("You %s %s! Walk it home to check in.", verb, withArticle(def.name)),
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
	-- the cafe's copy feeds ProfileSync.carrying; while it is set the client keeps the walk-home banner and door
	-- marker up and holds back tutorial hints
	CafeService.setCarrying(player, nil)
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

local function logCircle(player: Player, strayId: string, attempt: Circles.Attempt, index: number)
	-- Studio only: QA reads what the server scored; live servers stay quiet.
	if not RunService:IsStudio() then
		return
	end
	local err = attempt.errors[index]
	print(
		string.format(
			"[Catch] %d %s circle %d/%d: %s, error %s",
			player.UserId,
			strayId,
			index,
			#attempt.circles,
			attempt.grades[index],
			if err ~= nil
				then string.format("%+d ms", math.floor(err * 1000 + 0.5))
				else "none (expired)"
		)
	)
end

-- Records judged circles in the player's history and flags the profile when the last 50 look scripted (S23).
-- The flag is for review only; nothing is taken away.
local function recordCircles(player: Player, profile: Types.PlayerProfile, attempt: Circles.Attempt)
	local history = circleHistory[player]
	if history == nil then
		history = {}
		circleHistory[player] = history
	end
	for _, grade in attempt.grades do
		Circles.pushHistory(history, grade == "perfect")
	end
	profile.stats.circlesTotal += #attempt.grades
	profile.stats.perfectCircles += Circles.perfectCount(attempt)
	if not profile.flags.autoPress and Circles.looksScripted(history) then
		profile.flags.autoPress = true
		warn(
			string.format(
				"[CatService] %d flagged autoPress: over 95%% Perfect in the last 50 circles",
				player.UserId
			)
		)
	end
end

-- Ends a catch once every circle is judged: chance is the mean score, one roll decides it (data-model section 10).
-- The schedule and the press times are the server's own, so a scripted client can only press on time.
local function finishCatch(player: Player, stray: Stray, attempt: Circles.Attempt)
	if stray.attempt ~= attempt or not stray.alive then
		return -- already finished, or the lock was dropped
	end
	stray.attempt = nil
	local profile = DataService.get(player)
	if profile == nil or player.Parent ~= Players then
		setLock(stray, 0)
		return
	end
	Circles.expire(attempt, serverNow())
	recordCircles(player, profile, attempt)
	-- Walking out of range, or finishing a rescue mid-catch (reviewer S21: the carried cat wins), is a failed
	-- catch with no roll, never a retry: otherwise stepping away before the last circle dodges a rare cat's
	-- flee (reviewer S33).
	local forfeit: string? = nil
	if carrying[player] ~= nil then
		forfeit = "Check in the cat you are carrying first"
	elseif not withinRange(player, stray.body.Position, Config.GrabRangeStuds + 2) then
		forfeit = "Too far away"
	end
	local chance = Circles.chance(attempt.scores)
	local success = forfeit == nil and Catching.succeeds(chance, rng:NextNumber())
	local lured = stray.calm and stray.reservedFor == player.UserId
	local flees = not success and Catching.fleesOnFail(stray.def.rarity) and not lured
	setLock(stray, 0)
	-- `stayed` tells the UI whether to offer the prompt again; it cannot tell from the rarity (reviewer N39).
	Net.fire(
		player,
		"CatchResult",
		stray.id,
		attempt.scores,
		chance,
		success,
		not success and not flees
	)
	if forfeit ~= nil then
		Net.toast(player, forfeit, "warn")
	end

	if success then
		profile.stats.grabsSucceeded += 1
		local def = stray.def
		despawn(stray)
		startCarry(player, def, false)
		return
	end
	if flees then
		Net.toast(player, "It got away", "warn")
		despawn(stray)
		return
	end
	-- The stray stays; the player who just failed waits GrabRetrySeconds before trying it again (reviewer N37).
	stray.retryUserId = player.UserId
	stray.retryUntil = serverNow() + Config.GrabRetrySeconds
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
		Net.toast(player, "This area opens at a higher tier. Rank up to catch cats here.", "warn")
		return
	end
	if stray.reservedFor ~= 0 and stray.reservedFor ~= player.UserId then
		Net.toast(player, "Someone else baited this cat.", "warn")
		return
	end
	if stray.lockedBy ~= 0 and not lockExpired(stray) then
		-- Busy, including the player's own catch in progress: a second GrabBegin never restarts the circles.
		local reason = if stray.lockedBy == player.UserId
			then "Keep going, the circles are coming"
			else "Someone else is catching it"
		Net.fire(player, "GrabResult", strayId, false, reason, true)
		return
	end
	if not withinRange(player, stray.body.Position, Config.GrabRangeStuds + 2) then
		Net.fire(player, "GrabResult", strayId, false, "Too far away", true)
		return
	end
	local now = serverNow()
	if stray.retryUserId == player.UserId and now < stray.retryUntil then
		Net.fire(player, "GrabResult", strayId, false, "Give it a moment", true)
		return
	end
	local last = lastCatchStart[player]
	if last ~= nil and now - last < Config.GrabCooldownSeconds then
		Net.fire(player, "GrabResult", strayId, false, "Give it a moment", true)
		return
	end
	-- One catch at a time: a script must not run circles on two strays at once.
	for _, other in strays do
		if other.attempt ~= nil and other.lockedBy == player.UserId and not lockExpired(other) then
			Net.fire(player, "GrabResult", strayId, false, "Finish this catch first", true)
			return
		end
	end
	lastCatchStart[player] = now

	local windows = Circles.windows(Economy.level(profile, "net"))
	local circles = Circles.schedule(
		stray.def.rarity,
		Economy.level(profile, "net"),
		now,
		function()
			return rng:NextNumber()
		end
	)
	local attempt = Circles.newAttempt(circles, windows)
	setLock(stray, player.UserId, Circles.lockUntil(circles, windows))
	stray.attempt = attempt
	profile.stats.grabsAttempted += 1
	Net.fire(player, "CatchSchedule", strayId, circles, Circles.publicWindows(windows))

	-- Circles nobody presses for score 0 at their deadline; after the last one the catch resolves on its own.
	task.delay(math.max(0, Circles.endsAt(circles, windows) - now) + 0.05, function()
		if stray.attempt == attempt then
			finishCatch(player, stray, attempt)
		end
	end)
	-- Whatever happens, the lock never outlives its schedule.
	task.delay(math.max(0, stray.lockUntil - now) + 0.05, function()
		if stray.alive and stray.lockedBy == player.UserId and lockExpired(stray) then
			setLock(stray, 0)
		end
	end)
end

-- One press for circle `index`. The client sends no time: the press is stamped on arrival and half the player's
-- ping (capped) is taken off. Out-of-order, repeated and early presses are ignored (Circles.press).
local function onCatchPress(player: Player, rawStrayId: unknown, rawIndex: unknown)
	local strayId = Guard.id(rawStrayId)
	local index = Guard.int(rawIndex, 1, MAX_CIRCLES)
	if strayId == nil or index == nil then
		return
	end
	local stray = strays[strayId]
	if stray == nil or not stray.alive or stray.lockedBy ~= player.UserId then
		return
	end
	local attempt = stray.attempt
	if attempt == nil then
		return
	end
	local arrival = serverNow()
	local pressTime = arrival - Circles.latency(player:GetNetworkPing())
	local before = attempt.nextIndex
	local grade = Circles.press(attempt, index, pressTime, arrival)
	for judged = before, attempt.nextIndex - 1 do
		logCircle(player, strayId, attempt, judged)
	end
	if grade ~= nil and Circles.isDone(attempt) then
		finishCatch(player, stray, attempt)
	end
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
				string.format(
					"%s caught %s!",
					player.DisplayName,
					withArticle(def.rarity .. " " .. def.name)
				)
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
		rejectRescue(
			player,
			spotId,
			"This area opens at a higher tier. Rank up to rescue cats here"
		)
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
	-- A holder who presses again within RESCUE_TENURE_SECONDS of their last press continues the same run,
	-- whether the lock is still theirs, lapsed or dropped by a short RescueEnd, so timing a press just after
	-- each lapse does not start a fresh run (reviewer N25). A run past RESCUE_TENURE_SECONDS ends, and that
	-- player waits RescueLockSeconds on this spot so someone else can step in (reviewer S20).
	local continuing = entry.lastHolder == player.UserId
		and now - entry.holdAt <= RESCUE_TENURE_SECONDS
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
		Net.toast(player, "This area opens at a higher tier. Rank up to set bait here.", "warn")
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
	Net.on("CatchPress", onCatchPress)
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
		circleHistory[player] = nil
		lastCatchStart[player] = nil
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
