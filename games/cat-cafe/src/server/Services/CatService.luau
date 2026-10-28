--!strict
-- Strays: sunrise waves per area, the net (lock, closing circles, the chase after a miss), carrying a caught or rescued
-- cat home and check-in. The bait bowl is BaitService; NightService closes the areas at night and calls nightFalls,
-- sunriseWave and forceCheckIn (v0.9, F66). Server authoritative: the client only says which circle it pressed for;
-- distance, locks, the schedule, the press times, the chase and odds live here.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AssetRegistry = require(script.Parent.Parent.World.AssetRegistry)
local CafeService = require(script.Parent.CafeService)
local CatStats = require(ReplicatedStorage.Shared.CatStats)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Catching = require(ReplicatedStorage.Shared.Catching)
local Circles = require(ReplicatedStorage.Shared.Circles)
local Clock = require(ReplicatedStorage.Shared.Clock)
local ClockService = require(script.Parent.ClockService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Guard = require(script.Parent.Parent.Util.Guard)
local IndexRewards = require(ReplicatedStorage.Shared.IndexRewards)
local Mover = require(ReplicatedStorage.Shared.Mover)
local Net = require(script.Parent.Net)
local PlotService = require(script.Parent.PlotService)
local Shove = require(ReplicatedStorage.Shared.Shove)
local Telemetry = require(script.Parent.Telemetry)
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
	pointIndex: number?, -- spawn point it occupies
	home: Vector3,
	lockedBy: number,
	lockUntil: number, -- server time the lock lapses on its own; 0 when unlocked
	attempt: Circles.Attempt?, -- the circles of the lock holder's catch in progress
	-- v0.5 (data-model section 10 step 5): server time the sprint after a miss and the breather end; nobody starts
	-- a catch before it. Tries are unlimited, so there is no per-player table.
	fleeingUntil: number,
	-- server time each player who missed may try again: StraySelfRetrySeconds after it stops (reviewer S44)
	selfRetryAt: { [number]: number },
	jumping: boolean, -- sprinting or catching its breath: no wandering
	charm: number, -- rolled at spawn (section 4b); a net catch adds the Perfect bonus
	variant: string, -- "gold" (GoldChanceNet with gold luck, rolled at spawn and shown as a sparkle) or "base"
	method: Types.CatchMethod, -- "net", or what a Dropped cat was before it fell (its rescued flag, 10c)
	-- set on a Dropped stray (section 10c, S25): a shove knocked it out of someone's arms or they let it go. It has
	-- no circles: anyone picks it up with PickUpCat (v0.8 F56).
	drop: Shove.Drop?,
	funnel: Telemetry.CatchFunnel?, -- the lock holder's catch_attempt funnel (F16)
	alive: boolean,
}

-- variant is "gold" for a gold cat (a rescue rolls it at night start, data-model section 4); nil is the base.
-- startedAt and immuneUntil are the shove protections (section 10c); the character mirrors them.
type Carry = {
	def: Types.CatDef,
	model: Model?,
	method: Types.CatchMethod,
	charm: number?,
	variant: string?,
	startedAt: number, -- server time
	immuneUntil: number, -- server time; after "It held on tight!" (BumpChance below 1 only)
	funnel: Telemetry.CatchFunnel?, -- the catch_attempt funnel this cat came from (F16)
	rushUntil: number?, -- server time the Catch Rush ends (F55); nil for a picked-up cat
}

-- What a Dropped cat keeps from the arms it fell out of (section 10c): charm, gold and rescued flag.
type Kept = {
	charm: number?,
	variant: string?,
	method: Types.CatchMethod,
	drop: Shove.Drop,
}

local world: WorldBuilder.World
local straysFolder: Folder
local strays: { [string]: Stray } = {}
local occupiedPoints: { [string]: { [number]: string } } = {} -- area -> point index -> stray id
local carrying: { [Player]: Carry } = {}
local circleHistory: { [Player]: { boolean } } = {} -- last judged circles per player, true for Perfect (S23)
local lastCatchStart: { [Player]: number } = {} -- server time of the player's last GrabBegin that started circles
local rng = Random.new()
local nextStrayNumber = 0
-- RescueService's answer to "is this player in a rescue attempt?", so a catch cannot start during one.
local inRescue: (Player) -> boolean = function(_player: Player): boolean
	return false
end

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

-- The gold luck a stray or a rescue trap in the area rolls with (F54, golden-fish.md section 5): the highest among
-- the players in the server whose tier has the area open, 0 when nobody has. The coat shows from the spawn, the
-- same for everyone.
function CatService.goldLuckFor(areaId: string): number
	return (CatService.goldLuckSource(areaId))
end

-- The same gold luck and the player it comes from (nil when it is 0), for the area's Index Board.
function CatService.goldLuckSource(areaId: string): (number, Player?)
	local area = Catalog.getArea(areaId)
	if area == nil then
		return 0, nil
	end
	local players: { Player } = {}
	local profiles: { Types.PlayerProfile } = {}
	for _, player in DataService.loadedPlayers() do
		local profile = DataService.get(player)
		if profile ~= nil then
			table.insert(players, player)
			table.insert(profiles, profile)
		end
	end
	local luck, from = IndexRewards.luckiest(profiles, area.tier, Economy.tier)
	return luck, if from ~= nil then players[from] else nil
end

-- Each area's Index Board shows whose gold luck its strays and traps roll with ("Gold luck +40% from Sam", F54):
-- GoldLuck (the fraction) and GoldLuckFrom (that player's DisplayName), both cleared when nobody's luck applies.
-- Checked every LUCK_BOARD_SECONDS, which covers joins, leaves, claims and rank ups.
local LUCK_BOARD_SECONDS = 3

local function refreshLuckBoards()
	for _, board in CollectionService:GetTagged("IndexBoard") do
		local areaId = board:GetAttribute("Area")
		if board:IsDescendantOf(Workspace) and type(areaId) == "string" then
			local luck, from = CatService.goldLuckSource(areaId)
			board:SetAttribute("GoldLuck", if luck > 0 then luck else nil)
			board:SetAttribute(
				"GoldLuckFrom",
				if luck > 0 and from ~= nil then from.DisplayName else nil
			)
		end
	end
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
	if userId ~= 0 and stray.model:GetAttribute("Napping") == true then
		stray.model:SetAttribute("Napping", false) -- a catch wakes a napping stray at once
	end
end

local function lockExpired(stray: Stray): boolean
	return serverNow() > stray.lockUntil
end

-- `to`, or the point short of it where a prop or wall would block a cat running there from `from` (reviewer N84).
-- The ray runs a stud above the floor and ignores characters and the cats themselves.
local function clearPath(from: Vector3, to: Vector3): Vector3
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if flat.Magnitude < 0.1 then
		return to
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true -- decoration a player walks through never cuts a run short (reviewer N87)
	local ignore: { Instance } = { straysFolder }
	for _, player in Players:GetPlayers() do
		if player.Character ~= nil then
			table.insert(ignore, player.Character :: Model)
		end
	end
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(from + Vector3.new(0, 1, 0), flat, params)
	if hit == nil then
		return to
	end
	local reach = math.max(0, (hit.Position - (from + Vector3.new(0, 1, 0))).Magnitude - 1.5)
	return Vector3.new(from.X, to.Y, from.Z) + flat.Unit * reach
end

-- Spawning ------------------------------------------------------------------------------------------------

-- `catcher` is the player who just caught it, nil when it leaves. A knocked-loose cat logs who ended up with it
-- (drop_outcome, F16): against the catcher, or its old carrier when nobody caught it.
local function despawn(stray: Stray, catcher: Player?)
	if not stray.alive then
		return
	end
	stray.alive = false
	local drop = stray.drop
	-- shover 0 is a voluntary Drop (or Studio's hook), not a shove: kept out of the shove outcomes (reviewer N100)
	if drop ~= nil and drop.shover ~= 0 then
		local by = if catcher == nil
			then "nobody"
			elseif catcher.UserId == drop.owner then "carrier"
			elseif catcher.UserId == drop.shover then "shover"
			else "other"
		local subject = catcher or Players:GetPlayerByUserId(drop.owner)
		if subject ~= nil then
			Telemetry.custom(subject, "drop_outcome", 1, { by, stray.def.rarity, stray.area })
		end
	end
	strays[stray.id] = nil
	if stray.pointIndex ~= nil then
		local points = occupiedPoints[stray.area]
		if points ~= nil and points[stray.pointIndex :: number] == stray.id then
			points[stray.pointIndex :: number] = nil
		end
	end
	stray.model:Destroy()
end

-- Reviewer S35: every wander step moves every part of the cat and replicates to every client, so a stray only
-- wanders while a player is close enough to see it.
local WANDER_WATCH_STUDS = 80

local function anyoneNear(position: Vector3): boolean
	for _, player in Players:GetPlayers() do
		if withinRange(player, position, WANDER_WATCH_STUDS) then
			return true
		end
	end
	return false
end

-- Whether a stray may walk somewhere now: alive, not caught or being caught, not running from a miss, not Dropped
-- (it stays where it fell for anyone to pick up, v0.8 F56), and in sight of a player.
local function canWander(stray: Stray): boolean
	return stray.alive
		and stray.lockedBy == 0
		and not stray.jumping
		and stray.drop == nil
		and anyoneNear(stray.home)
end

-- Strays nap by day too, not only at night (Derek 2026-10-27: "sleeping doesnt just have to be night it can be idle
-- also"): a wander pause turns into a nap at NAP_CHANCE, for NAP_MIN to NAP_MAX seconds. Waking, the cat gets up on
-- all fours and stretches (the client's get-up and stretch, StretchAt) for STRETCH_SECONDS before it walks off.
local NAP_CHANCE = 1 / 3
local NAP_MIN, NAP_MAX = 20, 45
local STRETCH_SECONDS = 3.6

-- A nap on a wander pause (Napping = true, which the client plays as sleeping and loafing on all fours). It lasts
-- its time and then until the cat may walk again, so it only gets up to go somewhere (Derek 2026-10-27: "no need to
-- wake up if not moving around"). Then Napping goes false and StretchAt (server time) tells the client to play the
-- get-up and stretch, which STRETCH_SECONDS waits out. A catch wakes it with Napping alone (setLock), so no stretch
-- plays then. True when it may walk off; false when a catch woke it or it is gone.
local function nap(stray: Stray): boolean
	local model = stray.model
	model:SetAttribute("Napping", true)
	local wakeAt = os.clock() + rng:NextNumber(NAP_MIN, NAP_MAX)
	repeat
		task.wait(1)
		if not stray.alive or model:GetAttribute("Napping") ~= true then
			return false
		end
	until os.clock() >= wakeAt and canWander(stray)
	model:SetAttribute("StretchAt", serverNow())
	model:SetAttribute("Napping", false)
	task.wait(STRETCH_SECONDS)
	return canWander(stray)
end

local function wander(stray: Stray)
	local area = world.areas[stray.area]
	local alive = function()
		return stray.alive and stray.lockedBy == 0
	end
	while stray.alive do
		task.wait(rng:NextNumber(3, 7))
		if not canWander(stray) then
			continue
		end
		if rng:NextNumber() < NAP_CHANCE and not nap(stray) then
			continue
		end
		local radius = Config.StrayWanderRadius
		local target = WorldBuilder.clampToArea(
			area,
			stray.home
				+ Vector3.new(rng:NextNumber(-radius, radius), 0, rng:NextNumber(-radius, radius)),
			2,
			stray.model:GetPivot().Position
		)
		Mover.walkTo(stray.model, target, Config.StrayWanderSpeed, alive)
	end
end

local function spawnStray(
	def: Types.CatDef,
	areaId: string,
	position: Vector3,
	pointIndex: number?,
	lifetime: number?, -- nil: stays until the next dusk clears it
	forceGold: boolean?, -- Studio's debug hook
	kept: Kept? -- a Dropped cat keeps its charm, gold and rescued flag
): Stray
	local variant = if kept ~= nil
		then kept.variant or "base"
		elseif forceGold == true or rng:NextNumber() < IndexRewards.goldChance(
			Config.GoldChanceNet,
			CatService.goldLuckFor(areaId)
		) then "gold"
		else "base"
	nextStrayNumber += 1
	local id = string.format("stray_%d_%d", os.time() % 100000, nextStrayNumber)
	local model = AssetRegistry.cloneCat(def.id, variant)
	model.Name = id
	local body = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart") :: BasePart
	model:SetAttribute("StrayId", id)
	model:SetAttribute("CatId", def.id)
	model:SetAttribute("CatName", def.name)
	model:SetAttribute("Rarity", def.rarity)
	model:SetAttribute("Area", areaId)
	model:SetAttribute("LockedBy", 0)
	model:SetAttribute("SpawnedAt", os.time())
	model:SetAttribute("FleeingUntil", 0) -- v0.5: server time a missed stray stops running (display only)
	-- A net stray's gold is no secret (data-model section 4): the sparkle and the catch header show it.
	model:SetAttribute("Gold", variant == "gold")
	-- Display only (section 13); the drop record itself stays in the server's table below (S25, N29). A Dropped
	-- stray's card reads Pick up, with no circles (v0.8 F56, ui-contract "Pick up").
	model:SetAttribute("Dropped", kept ~= nil)
	model:SetAttribute("PickUp", kept ~= nil)
	CollectionService:AddTag(model, "Stray")

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GrabPrompt"
	prompt.ActionText = if kept ~= nil then "Pick up" else "Catch"
	prompt.ObjectText = def.name
	prompt.HoldDuration = Config.CatchHoldSeconds -- holding E starts the circles (Derek 2026-10-27)
	prompt.MaxActivationDistance = Config.GrabRangeStuds
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt:SetAttribute("CatId", def.id)
	prompt:SetAttribute("CatName", def.name)
	prompt:SetAttribute("Rarity", def.rarity)
	prompt:SetAttribute("StrayId", id)
	prompt:SetAttribute("Gold", variant == "gold")
	prompt.Parent = body

	model:PivotTo(CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- a cat streams in whole (reviewer S37)
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
		home = position,
		lockedBy = 0,
		lockUntil = 0,
		attempt = nil,
		fleeingUntil = 0,
		selfRetryAt = {},
		jumping = false,
		charm = if kept ~= nil and kept.charm ~= nil
			then kept.charm
			else CatStats.rollCharm(rng:NextNumber(), rng:NextNumber()),
		variant = variant,
		method = if kept ~= nil then kept.method else "net",
		drop = if kept ~= nil then kept.drop else nil,
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
			despawn(stray)
		end
	end)
	return stray
end

-- A free spawn point in the area, spread from the strays already there (Catching.spreadPick), or nil. Epic and
-- rarer strays take only points tagged "nook" when one is free (data-model section 9 and town-layout-v3.md 7e: the
-- exciting cats wait at the back alleys' ends, so no cafe's lane is the lucky one).
local function freeSpawnPoint(areaId: string, rarity: Types.Rarity?): number?
	local area = world.areas[areaId]
	local occupied = occupiedPoints[areaId] or {}
	local free: { number } = {}
	local nooks: { number } = {}
	local hasNook = false
	for i, point in area.spawnPoints do
		local inNook = point:GetAttribute("Zone") == "nook"
		hasNook = hasNook or inNook
		if occupied[i] == nil then
			table.insert(free, i)
			if inNook then
				table.insert(nooks, i)
			end
		end
	end
	-- Epic and rarer spawn only in a nook, never in a back alley lane (F35, v3.1); with every nook full that stray
	-- waits for the next wave. spawnWave places the rarer strays first, so this is rare.
	local pool: { number } = free
	if rarity ~= nil and Catching.rarityAtLeast(rarity, "Epic") and hasNook then
		pool = nooks
	end
	-- Spread out (Derek 22:38): away from every stray already in the area, StraySpawnSpacingStuds apart when it can.
	local points: { Vector3 } = {}
	for _, index in pool do
		table.insert(points, area.spawnPoints[index].Position)
	end
	local taken: { Vector3 } = {}
	for _, stray in strays do
		if stray.alive and stray.area == areaId then
			table.insert(taken, stray.model:GetPivot().Position)
		end
	end
	local pick = Catching.spreadPick(points, taken, rng:NextNumber())
	return if pick ~= nil then pool[pick] else nil
end

local function spawnAt(areaId: string, pointIndex: number, rarity: Types.Rarity)
	local area = world.areas[areaId]
	local def = Catching.pickCat(rarity, areaId, rng:NextNumber())
	local point = area.spawnPoints[pointIndex]
	spawnStray(
		def,
		areaId,
		Vector3.new(point.Position.X, area.floorY, point.Position.Z),
		pointIndex,
		nil
	)
end

-- A beginner always finds a Common stray waiting in the back alley right outside their own yard gate: plot p's
-- lane points are alley points 2p - 1 and 2p (Layout.alley).
local function tutorialTick()
	if not ClockService.areasOpen() then
		return -- nothing spawns at night (v0.9, F66); the beginner's stray comes with the sunrise
	end
	local occupied = occupiedPoints.alley or {}
	for _, player in DataService.loadedPlayers() do
		local profile = DataService.get(player)
		local plot = PlotService.get(player)
		if
			profile == nil
			or plot == nil
			or profile.tutorialStep >= Config.TutorialGuaranteedStrayStep
		then
			continue
		end
		local lane = { 2 * plot.index - 1, 2 * plot.index }
		local waiting = false
		local freePoint: number? = nil
		for _, pointIndex in lane do
			local strayId = occupied[pointIndex]
			local stray = if strayId ~= nil then strays[strayId] else nil
			if stray ~= nil and stray.alive and stray.def.rarity == "Common" then
				waiting = true
			elseif strayId == nil and freePoint == nil then
				freePoint = pointIndex
			end
		end
		if not waiting and freePoint ~= nil then
			spawnAt("alley", freePoint :: number, "Common")
		end
	end
end

-- Sunrise (data-model section 9, v0.9): a full wave arrives at once. Dusk already cleared the area, so this only
-- fills free points; a cat let go during night is still there and keeps its point.
local function spawnWave(areaDef: Types.AreaDef)
	-- Roll the whole wave, then place the rarest first so Epic and rarer always find a Square point.
	local rarities: { Types.Rarity } = {}
	for _ = 1, areaDef.waveSize do
		table.insert(rarities, Catching.pickRarity(areaDef.odds, rng:NextNumber()))
	end
	table.sort(rarities, function(a, b)
		return Catalog.rarityRank[a] > Catalog.rarityRank[b]
	end)
	for _, rarity: Types.Rarity in rarities do
		local point = freeSpawnPoint(areaDef.id, rarity)
		if point ~= nil then
			spawnAt(areaDef.id, point, rarity)
		end
	end
end

-- Runs `after` once nobody holds the stray's lock: at once when it is free, else when the catch in progress ends
-- (the catch wins a stray it lands, which leaves it dead here).
local function whenUnlocked(stray: Stray, after: (Stray) -> ())
	if stray.lockedBy == 0 or lockExpired(stray) then
		after(stray)
		return
	end
	task.spawn(function()
		while stray.alive and stray.lockedBy ~= 0 and not lockExpired(stray) do
			task.wait(0.5)
		end
		if stray.alive then
			after(stray)
		end
	end)
end

-- Carrying ------------------------------------------------------------------------------------------------

-- The carried pose from the asset manifest (poses.carried.body_cframe_roblox): cradled across the chest, facing
-- the character's left so the camera behind the player sees the cat side on. Relative to the HumanoidRootPart.
local CARRIED_POSE = CFrame.new(0, -0.4, -1.05, 0, 0, 1, 0, 1, 0, -1, 0, 0)

-- The carrier's character attributes (section 13): CarryingCatId, CarryStartedAt (server time) and BumpImmune (the
-- held window). Display only; the shove checks read the carry record. nil clears them.
local function showCarry(player: Player, carry: Carry?)
	local character = player.Character
	if character == nil then
		return
	end
	character:SetAttribute("CarryingCatId", if carry ~= nil then carry.def.id else nil)
	character:SetAttribute("CarryStartedAt", if carry ~= nil then carry.startedAt else nil)
	character:SetAttribute(
		"BumpImmune",
		if carry ~= nil then serverNow() < carry.immuneUntil else nil
	)
end

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
	local model = AssetRegistry.cloneCat(carry.def.id, carry.variant)
	model.Name = "HeldCat"
	model:SetAttribute("CatId", carry.def.id)
	model:SetAttribute("Gold", carry.variant == "gold") -- a rescued gold shows its sparkle from here
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
	showCarry(player, carry)
end

-- "an Epic Maine Coon", "a Tabby": the article for the word that follows it.
local function withArticle(phrase: string): string
	return (if phrase:match("^[AEIOUaeiou]") then "an " else "a ") .. phrase
end

-- The getaway after a net catch or a rescue (v0.8 F55, data-model section 10c). Every other player within
-- CatchBurstRadiusStuds is pushed CatchBurstStuds straight away from the catcher by their own client (CatchBurst, the
-- shove's push without its hold), unless they are in a catch or rescue, so nobody is pushed into a miss. It is not a
-- shove: nothing drops and no shove table or cooldown changes. The catcher walks at CatchRushWalkSpeed for
-- CatchRushSeconds, then at carry speed if still carrying this cat. `RushUntil` on the catcher and `PushedAt` on each
-- pushed player are for the ring, the speed lines, the skid and the getaway sound (data-model section 13).
local function getaway(player: Player, carry: Carry)
	local character = player.Character
	local rootInstance = if character ~= nil
		then character:FindFirstChild("HumanoidRootPart")
		else nil
	if character == nil or rootInstance == nil or not rootInstance:IsA("BasePart") then
		return
	end
	local root = rootInstance :: BasePart
	local now = serverNow()
	carry.rushUntil = now + Config.CatchRushSeconds
	character:SetAttribute("RushUntil", carry.rushUntil)
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid?
	if humanoid ~= nil then
		humanoid.WalkSpeed = Config.CatchRushWalkSpeed
	end
	task.delay(Config.CatchRushSeconds, function()
		local current = player.Character
		local nowHumanoid = if current ~= nil
			then current:FindFirstChildOfClass("Humanoid") :: Humanoid?
			else nil
		if carrying[player] == carry and nowHumanoid ~= nil then
			nowHumanoid.WalkSpeed = Config.CarryWalkSpeed
		end
	end)
	local facing = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	local fallback = if facing.Magnitude > 0.05 then facing.Unit else Vector3.new(0, 0, -1)
	for _, other in Players:GetPlayers() do
		local at = if other ~= player then rootPosition(other) else nil
		if at ~= nil and Shove.inBurst(root.Position, at) and not CatService.inMinigame(other) then
			local otherCharacter = other.Character
			if otherCharacter ~= nil then
				otherCharacter:SetAttribute("PushedAt", now)
			end
			Net.fire(other, "CatchBurst", Shove.direction(root.Position, at, fallback))
		end
	end
end

-- Callers check carrying first; the refusal here keeps one carry per player whatever path calls it. `method` is
-- "net" or "rescue"; `variant` "gold" shows on the held cat and in the toast. `pickedUp` is a Dropped cat taken
-- with PickUpCat (v0.8 F56): only the toast says so, the carry is like any other.
local function startCarry(
	player: Player,
	def: Types.CatDef,
	method: Types.CatchMethod,
	charm: number?,
	variant: string?,
	pickedUp: boolean?,
	funnel: Telemetry.CatchFunnel?
): boolean
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
	local carry: Carry = {
		def = def,
		model = nil,
		method = method,
		charm = charm,
		variant = variant,
		startedAt = serverNow(),
		immuneUntil = 0,
		funnel = funnel,
	}
	carrying[player] = carry
	attachHeldCat(player, carry)
	if pickedUp ~= true then
		getaway(player, carry) -- a net catch or a rescue; picking up a dropped cat gives neither (F55)
	end
	CafeService.setCarrying(player, def.id)
	local profile = DataService.get(player)
	if profile ~= nil then
		-- a catch is out in an area, so it stands in for the alley step when TutorialAdvance 1 never came
		Telemetry.onboarding(player, profile, "saw_alley")
		Telemetry.onboarding(player, profile, "first_catch")
	end
	if funnel ~= nil then
		Telemetry.catchCaught(player, funnel)
	end
	local verb = if pickedUp == true
		then "picked up"
		elseif method == "rescue" then "rescued"
		else "caught"
	local name = if variant == "gold" then "gold " .. def.name else def.name
	Net.toast(
		player,
		string.format("You %s %s! Walk it home to check in.", verb, withArticle(name)),
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
	showCarry(player, nil)
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
	if character ~= nil and carry.rushUntil ~= nil and carry.rushUntil > serverNow() then
		character:SetAttribute("RushUntil", 0) -- checked in or knocked loose mid-rush: the speed lines stop (F55)
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

-- Records judged circles in the player's history and flags the profile when the last 50 look scripted (S23), or
-- clears the flag when a full 50 look honest again (v0.4, reviewer N46). While flagged the player gets no Perfect
-- charm bonus; nothing else is taken away, and Derek reviews flagged accounts.
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
		Telemetry.custom(player, "autopress_flag", 1, { "set" })
		warn(
			string.format(
				"[CatService] autopress_flag set for %d: over %d%% Perfect in the last %d circles",
				player.UserId,
				math.floor(Circles.AUTO_PRESS_RATE * 100 + 0.5),
				Circles.AUTO_PRESS_WINDOW
			)
		)
	elseif profile.flags.autoPress and Circles.looksHonest(history) then
		profile.flags.autoPress = false
		Telemetry.custom(player, "autopress_flag", 1, { "cleared" })
		warn(string.format("[CatService] autopress_flag cleared for %d", player.UserId))
	end
end

-- After a miss the stray hisses (HissAt, so every nearby client plays it) and sprints its rarity's fleeStuds straight
-- away from the player at StrayFleeSpeed, kept inside its area, then catches its breath for StrayRestSeconds
-- (v0.5, data-model section 10 step 5). Nobody can start a catch on it until FleeingUntil.
local function flee(stray: Stray, player: Player)
	local at = stray.model:GetPivot().Position
	local from = rootPosition(player)
	local away = if from ~= nil then Vector3.new(at.X - from.X, 0, at.Z - from.Z) else Vector3.zero
	if away.Magnitude < 0.1 then
		local angle = rng:NextNumber(0, math.pi * 2)
		away = Vector3.new(math.cos(angle), 0, math.sin(angle))
	end
	local area = world.areas[stray.area]
	local target = clearPath(
		at,
		WorldBuilder.clampToArea(area, at + away.Unit * Catching.fleeStuds(stray.def.rarity), 2, at)
	)
	local now = serverNow()
	local sprint = Vector3.new(target.X - at.X, 0, target.Z - at.Z).Magnitude
	stray.fleeingUntil = Catching.fleeUntil(now, sprint)
	stray.selfRetryAt[player.UserId] = stray.fleeingUntil + Config.StraySelfRetrySeconds
	stray.model:SetAttribute("HissAt", now)
	stray.model:SetAttribute("FleeingUntil", stray.fleeingUntil)
	stray.jumping = true
	stray.home = target -- it wanders from where it stopped, not back toward whoever missed (reviewer N52)
	task.spawn(function()
		Mover.walkTo(stray.model, target, Config.StrayFleeSpeed, function()
			return stray.alive and stray.lockedBy == 0
		end)
		task.wait(math.max(0, stray.fleeingUntil - serverNow()))
		stray.jumping = false
	end)
end

-- Ends a catch at its first Miss or after its last circle (data-model section 10 step 5, v0.4): every circle Good
-- or Perfect is a sure catch, anything else sends the stray running (v0.5). The schedule and the press times are the
-- server's own, so a scripted client can only press on time.
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
	-- Walking out of range, or finishing a rescue mid-catch (reviewer S21: the carried cat wins), is a Miss, so
	-- stepping away before a hard circle never dodges the cost (reviewer S33).
	local forfeit: string? = nil
	if carrying[player] ~= nil then
		forfeit = "Check in the cat you are carrying first"
	elseif not withinRange(player, stray.body.Position, Config.GrabRangeStuds + 2) then
		forfeit = "Too far away"
	end
	setLock(stray, 0)
	local funnel = stray.funnel
	stray.funnel = nil
	local succeeded = forfeit == nil and Circles.succeeded(attempt)
	local perfect = Circles.perfectCount(attempt)
	local rarity: string = stray.def.rarity
	local result: string = if not succeeded
		then (if forfeit ~= nil then "forfeit" else "missed")
		elseif perfect == #attempt.circles then "purrfect"
		else "caught"
	Telemetry.custom(
		player,
		"catch_circles",
		perfect,
		{ rarity, tostring(Economy.level(profile, "net")), result }
	)

	if succeeded then
		-- no Perfect bonus for a scripted-looking profile, nor on a Dropped cat, which already has its charm
		-- (reviewer S36: two friends could shove and re-catch it up to 100). Since v0.8 F56 a Dropped stray refuses
		-- GrabBegin, so this is only a guard.
		local gain = if profile.flags.autoPress or stray.drop ~= nil
			then 0
			else Circles.charmGain(attempt)
		Net.fire(player, "CatchResult", stray.id, attempt.grades, true, gain)
		profile.stats.grabsSucceeded += 1
		local method: Types.CatchMethod = stray.method
		local def, variant = stray.def, stray.variant
		local charm = math.min(100, stray.charm + gain)
		despawn(stray, player)
		startCarry(player, def, method, charm, variant, nil, funnel)
		return
	end

	-- The stray moves first, so its FleeingUntil reaches the client ahead of the result (QA on #130).
	flee(stray, player)
	Net.fire(player, "CatchResult", stray.id, attempt.grades, false, 0)
	-- The catch HUD says the cat got away (UI.catch.showGrades); only a forfeit needs words from here (reviewer S39).
	if forfeit ~= nil then
		Net.toast(player, forfeit, "warn")
	end
end

-- Shove (section 10c) --------------------------------------------------------------------------------------

-- The carried cat drops as a Dropped stray that keeps its charm, gold and rescued flag: where the target stands
-- (a shove, v0.8 F56: no scurry), or `ahead` studs in front of them (the Drop button). Anyone picks it up with
-- PickUpCat. `shoverUserId` is 0 for a Drop or Studio's hook. Nil when the target has no character to drop it
-- from, in which case the carry stays.
local function knockLoose(
	target: Player,
	shoverUserId: number,
	areaId: string,
	ahead: number?
): Stray?
	local root = rootPosition(target)
	local area = world.areas[areaId]
	local character = target.Character
	if root == nil or area == nil or character == nil or carrying[target] == nil then
		return nil
	end
	local carry = endCarry(target) :: Carry
	local spot = root
	if ahead ~= nil then
		local look = character:GetPivot().LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.01 then
			spot = clearPath(root, root + flat.Unit * ahead)
		end
	end
	local feet = WorldBuilder.clampToArea(area, spot, 2, root)
	return spawnStray(carry.def, areaId, feet, nil, nil, nil, {
		charm = carry.charm,
		variant = carry.variant,
		method = carry.method,
		drop = Shove.newDrop(target.UserId, shoverUserId, serverNow()),
	})
end

-- Remote handlers -----------------------------------------------------------------------------------------

-- True while the player's catch circles are running (CatService.inCatch).
local function holdsCatch(player: Player): boolean
	for _, stray in strays do
		if stray.lockedBy == player.UserId and stray.attempt ~= nil and not lockExpired(stray) then
			return true
		end
	end
	return false
end

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
	if inRescue(player) then
		Net.fire(player, "GrabResult", strayId, false, "Finish this rescue first", true)
		return
	end
	if not areaUnlocked(profile, stray.area) then
		Net.toast(player, "This area opens at a higher tier. Rank up to catch cats here.", "warn")
		return
	end
	if not ClockService.areasOpen() then
		-- a stray still waiting out someone's catch at dusk, or a modified client past the fence (v0.9, F66)
		Net.toast(player, Clock.CLOSED_TEXT, "warn")
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
	if now < stray.fleeingUntil then
		Net.fire(player, "GrabResult", strayId, false, "It's running!", true)
		return
	end
	local selfRetryAt = stray.selfRetryAt[player.UserId]
	if selfRetryAt ~= nil and now < selfRetryAt then
		Net.fire(player, "GrabResult", strayId, false, "Catch your breath, then try again", true)
		return
	end
	if stray.drop ~= nil then
		-- v0.8 F56: a Dropped stray has no circles; its card fires PickUpCat
		Net.fire(player, "GrabResult", strayId, false, "Hold to pick it up", true)
		return
	end
	local last = lastCatchStart[player]
	if last ~= nil and now - last < Config.GrabCooldownSeconds then
		Net.fire(player, "GrabResult", strayId, false, "Give it a moment", true)
		return
	end
	-- One catch at a time: a script must not run circles on two strays at once.
	if holdsCatch(player) then
		Net.fire(player, "GrabResult", strayId, false, "Finish this catch first", true)
		return
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
	stray.funnel = Telemetry.catchEngaged(
		player,
		stray.def.rarity,
		if stray.drop ~= nil then "net_dropped" else "net",
		stray.area
	)

	-- A circle nobody presses is a Miss at its deadline, which ends the catch; so is walking out of range.
	task.spawn(function()
		while stray.attempt == attempt do
			local deadline = Circles.nextDeadline(attempt)
			if deadline == nil then
				return
			end
			task.wait(math.max(0, deadline - serverNow()) + 0.05)
			if stray.attempt ~= attempt then
				return
			end
			Circles.expire(attempt, serverNow())
			if
				Circles.isDone(attempt)
				or not withinRange(player, stray.body.Position, Config.GrabRangeStuds + 2)
			then
				finishCatch(player, stray, attempt)
				return
			end
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
-- ping (capped) is taken off. Out-of-order, repeated and early presses are ignored (Circles.press). A Miss or the
-- last circle ends the catch at once.
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
	Circles.press(attempt, index, pressTime, arrival)
	for judged = before, attempt.nextIndex - 1 do
		logCircle(player, strayId, attempt, judged)
	end
	if Circles.isDone(attempt) then
		finishCatch(player, stray, attempt)
	end
end

-- PickUpCat (v0.8 F56, data-model section 10c): anyone takes a Dropped stray with the hold and no circles, the
-- shover and its last carrier included, with no owner window. The first valid call wins. The cat keeps its catId,
-- gold, charm and rescued flag and gains no charm (S36), with no rush or burst; the carry is like any other, so
-- BumpGraceSeconds runs from here and the last carrier can shove back once it passes.
local function onPickUpCat(player: Player, rawStrayId: unknown)
	local strayId = Guard.id(rawStrayId)
	local profile = DataService.get(player)
	if strayId == nil or profile == nil then
		return
	end
	local stray = strays[strayId]
	if stray == nil or not stray.alive then
		return
	end
	local root = rootPosition(player)
	local now = serverNow()
	local last = lastCatchStart[player]
	local reason = Shove.pickUpRefusal({
		dropped = stray.drop ~= nil,
		carrying = carrying[player] ~= nil,
		busy = inRescue(player) or holdsCatch(player),
		areaUnlocked = areaUnlocked(profile, stray.area),
		areasClosed = not ClockService.areasOpen(),
		distance = if root ~= nil then (root - stray.body.Position).Magnitude else nil,
		sinceGrab = if last ~= nil then now - last else nil,
	})
	if reason ~= nil then
		Net.fire(player, "GrabResult", strayId, false, reason, true)
		return
	end
	lastCatchStart[player] = now
	profile.stats.pickups += 1
	local method: Types.CatchMethod = stray.method
	local def, charm, variant = stray.def, stray.charm, stray.variant
	despawn(stray, player) -- logs drop_outcome against the player who ended up with it
	startCarry(player, def, method, charm, variant, true, nil)
end

-- Adds the cat to the player's cafe and, with `notify`, tells them and the server (CatCaught, the shout-out). The
-- carry has already ended, or never began: dusk checks a Dropped stray in for its last carrier this way.
local function checkIn(player: Player, carry: Carry, notify: boolean, profile: Types.PlayerProfile?)
	local def = carry.def
	local instance, isNew = CafeService.addCaughtCat(
		player,
		def,
		notify,
		profile,
		carry.charm,
		carry.method,
		carry.variant
	)
	if notify then
		local current = DataService.get(player)
		if current ~= nil then
			Telemetry.onboarding(player, current, "first_checkin")
		end
		if carry.funnel ~= nil then
			Telemetry.catchCheckedIn(player, carry.funnel, instance.uid, instance.spotId ~= nil)
		end
		Net.fire(player, "CatCaught", def.id, isNew)
		local verb = if carry.method == "rescue" then "rescued" else "caught"
		local text = Catching.shoutOut(player.DisplayName, verb, def, carry.variant)
		if text ~= nil then
			Net.fireAll("Announce", text, def.rarity) -- the shout-out chime rises with rarity
		end
	end
end

-- `profile` is passed on the save-on-leave path, where the session is closing and a lookup must not race it.
local function finishCheckIn(player: Player, notify: boolean, profile: Types.PlayerProfile?)
	local carry = endCarry(player)
	if carry ~= nil then
		checkIn(player, carry, notify, profile)
	end
end

-- Dusk (data-model section 9, v0.9): a Dropped stray goes to its last carrier while they are in the server, checked
-- in as if they had walked it home, so a shove or a Drop never loses a cat; every other stray just leaves.
local function leaveAtDusk(stray: Stray)
	local drop = stray.drop
	local owner = if drop ~= nil then Players:GetPlayerByUserId(drop.owner) else nil
	if owner == nil or DataService.get(owner) == nil then
		despawn(stray)
		return
	end
	local carry: Carry = {
		def = stray.def,
		model = nil,
		method = stray.method,
		charm = stray.charm,
		variant = stray.variant,
		startedAt = serverNow(),
		immuneUntil = 0,
		funnel = nil,
	}
	despawn(stray, owner)
	checkIn(owner, carry, true)
	Net.toast(owner, string.format("%s followed you home at dusk.", carry.def.name), "good")
end

local function onCheckIn(player: Player)
	local carry = carrying[player]
	local plot = PlotService.get(player)
	if carry == nil or plot == nil then
		return
	end
	-- Either door works (layout v2): the back door is the short way in from the back alley.
	if
		not withinRange(player, plot.door.Position, Config.CheckInRangeStuds)
		and not withinRange(player, plot.backDoorZone.Position, Config.CheckInRangeStuds)
	then
		return
	end
	finishCheckIn(player, true)
end

-- The Drop button (Derek 2026-10-27): lets go of the carried cat. In a catching area it lands DROP_AHEAD_STUDS in
-- front of the player; anywhere else (the street, a cafe, a yard) it runs back to a free spot in its own area.
-- Either way it is a Dropped stray with the player as its last carrier and no shover, which anyone picks up with
-- PickUpCat (v0.8 F56) and which gains no charm, so drop and pick up is no charm loop (as S36).
local DROP_AHEAD_STUDS = 3

local function onDropCat(player: Player)
	local carry = carrying[player]
	local character = player.Character
	local root = rootPosition(player)
	if carry == nil or character == nil or root == nil then
		return
	end
	local name = carry.def.name
	local here = WorldBuilder.areaAt(world, root)
	if here ~= nil then
		if knockLoose(player, 0, here, DROP_AHEAD_STUDS) ~= nil then
			Net.toast(player, string.format("You let %s go.", name), "info")
		end
		return
	end
	local homeId = carry.def.area
	local area = world.areas[homeId]
	if area == nil or #area.spawnPoints == 0 then
		return -- nowhere to send it, so the player keeps it (reviewer N99)
	end
	endCarry(player)
	local pointIndex = freeSpawnPoint(homeId, nil)
	local point = area.spawnPoints[pointIndex or rng:NextInteger(1, #area.spawnPoints)]
	spawnStray(
		carry.def,
		homeId,
		Vector3.new(point.Position.X, area.floorY, point.Position.Z),
		pointIndex,
		nil,
		nil,
		{
			charm = carry.charm,
			variant = carry.variant,
			method = carry.method,
			drop = Shove.newDrop(player.UserId, 0, serverNow()),
		}
	)
	local areaDef = Catalog.getArea(homeId)
	Net.toast(
		player,
		string.format(
			"%s ran back to the %s.",
			name,
			if areaDef ~= nil then areaDef.name else "alley"
		),
		"info"
	)
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
	Net.on("CheckIn", onCheckIn)
	Net.on("DropCat", onDropCat)
	Net.on("PickUpCat", onPickUpCat)
	task.spawn(function()
		while true do
			-- one bad board or profile must not end the loop for the server's life (review N185)
			xpcall(refreshLuckBoards, function(err: unknown)
				warn("[CatService] luck boards: " .. tostring(err))
			end)
			task.wait(LUCK_BOARD_SECONDS)
		end
	end)

	-- A player who leaves mid-carry keeps the cat. The finalizer runs before the session closes and is handed
	-- the profile, so it never depends on a lookup that is about to go nil.
	DataService.beforeRelease(function(player, profile)
		if carrying[player] ~= nil then
			finishCheckIn(player, false, profile)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			task.wait(0.2)
			local carry = carrying[player]
			if carry ~= nil then
				attachHeldCat(player, carry)
				return
			end
			local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid?
			if humanoid ~= nil then
				humanoid.WalkSpeed = Config.NormalWalkSpeed
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		-- endCarry (via the finalizer above) clears the carry record; this only mops up when the profile is
		-- already gone, so the handler order between services does not matter.
		if carrying[player] ~= nil and DataService.get(player) == nil then
			carrying[player] = nil
		end
		circleHistory[player] = nil
		lastCatchStart[player] = nil
		for _, stray in strays do
			if stray.lockedBy == player.UserId then
				setLock(stray, 0)
			end
		end
	end)

	-- No trickle by day: every stray arrives with the sunrise wave (NightService), the tutorial rule or bait.
	task.spawn(function()
		while true do
			task.wait(5)
			tutorialTick()
		end
	end)
end

-- Dusk (v0.9, F66): every stray leaves, a Dropped one to its last carrier (leaveAtDusk). A stray someone is catching
-- goes once that catch ends, unless the catch lands it.
function CatService.nightFalls()
	local leaving: { Stray } = {}
	for _, stray in strays do
		table.insert(leaving, stray)
	end
	for _, stray in leaving do
		whenUnlocked(stray, leaveAtDusk)
	end
end

-- Sunrise (v0.9, F66): every area gets its wave of WaveSize strays at once, whether or not anyone has it unlocked.
function CatService.sunriseWave()
	for _, areaDef in Catalog.areas do
		spawnWave(areaDef)
	end
end

-- Checks in the cat the player carries, wherever they are: NightService sends a carrier home at dusk and the cat
-- is checked in on arrival (CatCaught as usual).
function CatService.forceCheckIn(player: Player)
	if carrying[player] ~= nil then
		finishCheckIn(player, true)
	end
end

-- True while the player's catch circles are running.
function CatService.inCatch(player: Player): boolean
	return holdsCatch(player)
end

-- True while the player holds a catch or rescue lock: they can neither shove nor be shoved (section 10c, N85).
function CatService.inMinigame(player: Player): boolean
	return CatService.inCatch(player) or inRescue(player)
end

-- A landed shove on `target` (ShoveService). When the carry can be knocked loose (carrying, past BumpGraceSeconds
-- and any held window) it rolls BumpChance, 1.0 since v0.8 F56: "loose" drops the cat where the target stood as a
-- Dropped stray in `areaId` (knockLoose), "held" (only when BumpChance is tuned below 1) makes the carrier immune for
-- Shove.HELD_IMMUNE_SECONDS. Nil when there was nothing to roll. `forced` is Studio's hook.
function CatService.tryKnockLoose(
	target: Player,
	shoverUserId: number,
	areaId: string,
	forced: Shove.KnockResult?
): Shove.KnockResult?
	local carry = carrying[target]
	local now = serverNow()
	if carry == nil or not Shove.canKnockLoose(carry, now) then
		return nil
	end
	local loose = if forced ~= nil then forced == "loose" else Shove.landsLoose(rng:NextNumber())
	if loose and knockLoose(target, shoverUserId, areaId) ~= nil then
		return "loose"
	end
	carry.immuneUntil = now + Shove.HELD_IMMUNE_SECONDS
	showCarry(target, carry)
	task.delay(Shove.HELD_IMMUNE_SECONDS + 0.05, function()
		if carrying[target] == carry then
			showCarry(target, carry)
		end
	end)
	return "held"
end

function CatService.isCarrying(player: Player): boolean
	return carrying[player] ~= nil
end

-- Studio-only test hook: knocks the player's carried cat loose where they stand, as a shove from nobody would,
-- whatever the grace or immunity: a Dropped stray anyone picks up. Errors outside a catching area. Returns the new
-- StrayId.
function CatService.debugKnockLoose(player: Player): string
	assert(RunService:IsStudio(), "debugKnockLoose is Studio only")
	assert(carrying[player] ~= nil, "not carrying a cat")
	local root = rootPosition(player)
	local areaId = if root ~= nil then WorldBuilder.areaAt(world, root) else nil
	assert(areaId ~= nil, "stand in a catching area first")
	local stray = knockLoose(player, 0, areaId :: string)
	assert(stray ~= nil, "no character to drop it from")
	return (stray :: Stray).id
end

-- Puts a freed cat in the player's arms (RescueService). False when they already carry one.
function CatService.startCarry(
	player: Player,
	def: Types.CatDef,
	method: Types.CatchMethod,
	charm: number?,
	variant: string?,
	funnel: Telemetry.CatchFunnel?
): boolean
	return startCarry(player, def, method, charm, variant, nil, funnel)
end

-- RescueService registers how to tell whether a player's rescue attempt is running.
function CatService.setRescueCheck(check: (Player) -> boolean)
	inRescue = check
end

-- Where strays and stuck cats live in the world (Workspace.World.Strays).
function CatService.strayFolder(): Folder
	return straysFolder
end

-- Why the player cannot leave by fast travel right now, or nil: carrying a cat (walking it home is the loop and
-- bumps depend on it), or in the middle of a catch or a rescue.
function CatService.busyReason(player: Player): string?
	if carrying[player] ~= nil then
		return "Walk your cat home first"
	end
	if CatService.inCatch(player) then
		return "Finish this catch first"
	end
	if inRescue(player) then
		return "Finish this rescue first"
	end
	return nil
end

function CatService.strayCount(areaId: string): number
	return countStrays(areaId)
end

-- Studio-only test hook: spawns a given cat at a free spawn point of the area (or point 1 if all are taken),
-- gold when `gold` is true and rolled as usual otherwise.
function CatService.debugSpawnStray(catId: string, areaId: string, gold: boolean?): string
	assert(RunService:IsStudio(), "debugSpawnStray is Studio only")
	local def = Catalog.getCat(catId)
	local areaDef = Catalog.getArea(areaId)
	assert(def ~= nil and areaDef ~= nil, "unknown cat or area")
	local area = world.areas[areaId]
	local pointIndex = freeSpawnPoint(areaId, def.rarity) or 1
	local point = area.spawnPoints[pointIndex]
	local stray = spawnStray(
		def :: Types.CatDef,
		areaId,
		Vector3.new(point.Position.X, area.floorY, point.Position.Z),
		pointIndex,
		Config.StrayDespawnSeconds,
		gold
	)
	return stray.id
end

return CatService
