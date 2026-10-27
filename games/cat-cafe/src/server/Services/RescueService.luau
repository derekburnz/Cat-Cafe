--!strict
-- Rescue traps (data-model section 10b, F27): some days a cat is stuck at a trap, and a short minigame frees it.
-- NightService empties the traps at dusk and fills them at sunrise (v0.9, F66).
-- RescueBegin locks the trap to one player and sends the challenge; RescuePress presses carry no time, the server
-- stamps them on arrival and takes off half the player's ping; enough hits free the cat into the player's arms, out
-- of paws, out of time, walking away, Give up, dying or leaving ends the attempt and the cat stays stuck. A failed
-- attempt never loses the cat. The cat's charm and gold roll stay here until it is free (reviewer N30).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AssetRegistry = require(script.Parent.Parent.World.AssetRegistry)
local CatService = require(script.Parent.CatService)
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
local Net = require(script.Parent.Net)
local Rescue = require(ReplicatedStorage.Shared.Rescue)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local RescueService = {}

-- A player more than this far from the trap ends their attempt (data-model section 10b).
local LEAVE_RANGE_STUDS = 14

type Stuck = {
	spotId: string,
	area: string,
	trap: string, -- TrapType: "trash_bin", "garbage_bag", "tree", "trashcan" or a provisional trap
	def: Types.CatDef,
	charm: number, -- rolled at sunrise, kept here until the rescue succeeds (N30)
	variant: string, -- "base" or "gold", likewise hidden until then
	model: Model,
	spot: BasePart,
	lockedBy: number, -- the player whose attempt is running, else 0
	attempt: Rescue.Attempt?,
	retryAt: number, -- server time anyone may start after a failed attempt (RescueRetrySeconds)
	selfRetryAt: { [number]: number }, -- per player who failed: RescueSelfRetrySeconds
	funnel: Telemetry.CatchFunnel?, -- the lock holder's catch_attempt funnel (F16)
	alive: boolean,
}

local world: WorldBuilder.World
local strayFolder: Instance
local stuckCats: { [string]: Stuck } = {} -- rescueSpotId -> stuck cat
local rng = Random.new()

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root ~= nil and root:IsA("BasePart") then
		return (root :: BasePart).Position
	end
	return nil
end

local function withinRange(player: Player, position: Vector3, range: number): boolean
	local root = rootPosition(player)
	return root ~= nil and (root - position).Magnitude <= range
end

local function alive(player: Player): boolean
	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	return humanoid ~= nil and (humanoid :: Humanoid).Health > 0
end

local function setLock(entry: Stuck, userId: number)
	entry.lockedBy = userId
	if userId == 0 then
		entry.attempt = nil
	end
	entry.model:SetAttribute("LockedBy", userId)
	entry.spot:SetAttribute("LockedBy", userId)
end

local function attemptOf(player: Player): Stuck?
	for _, entry in stuckCats do
		if entry.alive and entry.lockedBy == player.UserId and entry.attempt ~= nil then
			return entry
		end
	end
	return nil
end

-- Stuck cats --------------------------------------------------------------------------------------------------

local function clearStuck(entry: Stuck)
	if not entry.alive then
		return
	end
	entry.alive = false
	entry.attempt = nil
	if stuckCats[entry.spotId] == entry then
		stuckCats[entry.spotId] = nil
	end
	entry.spot:SetAttribute("Occupied", false)
	entry.spot:SetAttribute("LockedBy", 0)
	entry.spot:SetAttribute("RetryAt", 0)
	entry.model:Destroy()
end

local function spawnStuck(
	spotId: string,
	areaId: string,
	spot: BasePart,
	def: Types.CatDef,
	charm: number,
	variant: string
): Stuck
	local model = AssetRegistry.clone(Catalog.catModelName(def.id))
	model.Name = "Stuck_" .. spotId
	local body = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart") :: BasePart
	local trap = spot:GetAttribute("TrapType")
	local trapType = if type(trap) == "string" then trap else "trash_bin"
	-- The stray attributes (section 13) minus StrayId, Charm, Stars and Gold, plus Rescue, RescueSpotId and
	-- TrapType for the UI and the sounds.
	model:SetAttribute("Rescue", true)
	model:SetAttribute("RescueSpotId", spotId)
	model:SetAttribute("TrapType", trapType)
	model:SetAttribute("CatId", def.id)
	model:SetAttribute("CatName", def.name)
	model:SetAttribute("Rarity", def.rarity)
	model:SetAttribute("Area", areaId)
	model:SetAttribute("LockedBy", 0)
	CollectionService:AddTag(model, "StuckCat")

	-- Holding E starts the minigame, as on a stray (Config.CatchHoldSeconds); the UI's card reads "Rescue".
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RescuePrompt"
	prompt.ActionText = "Rescue"
	prompt.ObjectText = def.name
	prompt.HoldDuration = Config.CatchHoldSeconds
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
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- a cat streams in whole (reviewer S37)
	model.Parent = strayFolder
	spot:SetAttribute("Occupied", true)
	spot:SetAttribute("LockedBy", 0)
	spot:SetAttribute("RetryAt", 0)

	local entry: Stuck = {
		spotId = spotId,
		area = areaId,
		trap = trapType,
		def = def,
		charm = charm,
		variant = variant,
		model = model,
		spot = spot,
		lockedBy = 0,
		attempt = nil,
		retryAt = 0,
		selfRetryAt = {},
		alive = true,
	}
	stuckCats[spotId] = entry
	return entry
end

-- Rolls the cat, its charm and its gold chance now, at sunrise, from the area's rescue odds; the gold chance has the
-- best gold luck among the players with the area open (F54).
local function rollStuckCat(spotId: string, areaDef: Types.AreaDef, spot: BasePart): Stuck
	local rarity: Types.Rarity =
		Catching.pickRarity(Catching.rescueOdds(areaDef.odds), rng:NextNumber())
	local def = Catching.pickCat(rarity, areaDef.id, rng:NextNumber())
	local charm = CatStats.rollCharm(rng:NextNumber(), rng:NextNumber())
	local chance =
		IndexRewards.goldChance(Config.GoldChanceRescue, CatService.goldLuckFor(areaDef.id))
	local variant = if rng:NextNumber() < chance then "gold" else "base"
	return spawnStuck(spotId, areaDef.id, spot, def, charm, variant)
end

-- Sunrise: each trap drops any cat still in it and rolls RescueSpawnChance for a new one, and an area where no trap
-- rolled a cat gets RescueMinStuck anyway, so a new player always meets a rescue on the first day. A trap someone is
-- mid-attempt on keeps its cat (dusk emptied the rest, so that only happens after Studio's setPhase).
local function rollRescues(areaDef: Types.AreaDef)
	local area = world.areas[areaDef.id]
	local stuck = 0
	local free: { string } = {}
	local ids: { string } = {}
	for spotId in area.rescueSpots do
		table.insert(ids, spotId)
	end
	table.sort(ids) -- the same order on every server, so a spec or a Studio session can predict the guarantee
	for _, spotId in ids do
		local spot = area.rescueSpots[spotId]
		local current = stuckCats[spotId]
		if current ~= nil and current.attempt ~= nil then
			stuck += 1
			continue
		end
		if current ~= nil then
			clearStuck(current)
		end
		if rng:NextNumber() < Config.RescueSpawnChance then
			rollStuckCat(spotId, areaDef, spot)
			stuck += 1
		else
			table.insert(free, spotId)
		end
	end
	while stuck < Config.RescueMinStuck and #free > 0 do
		local spotId = table.remove(free, rng:NextInteger(1, #free)) :: string
		rollStuckCat(spotId, areaDef, area.rescueSpots[spotId])
		stuck += 1
	end
end

-- Attempts ----------------------------------------------------------------------------------------------------

local function sendResult(player: Player, entry: Stuck, attempt: Rescue.Attempt)
	local done = attempt.stage == "done"
	Net.fire(
		player,
		"RescueResult",
		entry.spotId,
		attempt.hits,
		attempt.paws,
		done,
		done and attempt.success
	)
end

-- Ends the player's attempt on this trap. A success frees the cat into their arms; anything else unlocks the trap
-- with the retry waits and leaves the cat where it is. `reason` is a toast for an end the bar does not show
-- (walking away, a carry that started some other way). `cancelled` is true for Give up (RescueCancel).
local function finish(
	player: Player,
	entry: Stuck,
	attempt: Rescue.Attempt,
	reason: string?,
	cancelled: boolean?
)
	if entry.attempt ~= attempt then
		return -- already finished
	end
	if attempt.stage ~= "done" then
		Rescue.abandon(attempt)
	end
	local profile = DataService.get(player)
	local present = player.Parent == Players and profile ~= nil
	local success = attempt.success and present and not CatService.isCarrying(player)
	attempt.success = success
	setLock(entry, 0)
	if present then
		sendResult(player, entry, attempt)
	end
	local funnel = entry.funnel
	entry.funnel = nil
	Telemetry.custom(player, "rescue_attempt", 1, {
		entry.trap,
		entry.def.rarity,
		if success
			then "freed"
			elseif cancelled then "cancelled"
			elseif reason ~= nil then "walked_away"
			elseif attempt.paws <= 0 then "out_of_paws"
			elseif attempt.circle ~= nil then "missed_catch"
			else "too_slow",
	})
	if success then
		local def, charm, variant = entry.def, entry.charm, entry.variant
		clearStuck(entry)
		if profile ~= nil then
			profile.stats.rescues += 1
		end
		CatService.startCarry(player, def, "rescue", charm, variant, funnel)
		return
	end
	local now = serverNow()
	entry.retryAt = now + Config.RescueRetrySeconds
	entry.selfRetryAt[player.UserId] = now + Config.RescueSelfRetrySeconds
	entry.spot:SetAttribute("RetryAt", entry.retryAt)
	if present and reason ~= nil then
		Net.toast(player, reason, "warn")
	end
end

-- Watches an attempt until it ends: its deadline, the player walking more than LEAVE_RANGE_STUDS away or dying.
local function watch(player: Player, entry: Stuck, attempt: Rescue.Attempt)
	task.spawn(function()
		while entry.attempt == attempt do
			task.wait(0.2)
			if entry.attempt ~= attempt then
				return
			end
			if Rescue.expire(attempt, serverNow()) then
				finish(player, entry, attempt, nil) -- the bar shows "Too slow!" on its own clock
				return
			end
			if player.Parent ~= Players or not alive(player) then
				finish(player, entry, attempt, nil)
				return
			end
			if not withinRange(player, entry.spot.Position, LEAVE_RANGE_STUDS) then
				finish(player, entry, attempt, "You walked away. It's still stuck")
				return
			end
		end
	end)
end

local function refuse(player: Player, spotId: string, reason: string)
	-- The prompt card shows the reason and stays open, as for a stray (GrabResult).
	Net.fire(player, "GrabResult", spotId, false, reason, true)
end

local function areaUnlocked(profile: Types.PlayerProfile, areaId: string): boolean
	local area = Catalog.getArea(areaId)
	return area ~= nil and Economy.tier(profile) >= area.tier
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
	if CatService.isCarrying(player) then
		refuse(player, spotId, "Check in the cat you are carrying first")
		return
	end
	if not areaUnlocked(profile, entry.area) then
		refuse(player, spotId, "This area opens at a higher tier. Rank up to rescue cats here")
		return
	end
	if not ClockService.areasOpen() then
		refuse(player, spotId, Clock.CLOSED_TEXT) -- a trap still held by an attempt at dusk (v0.9, F66)
		return
	end
	if entry.lockedBy == player.UserId and entry.attempt ~= nil then
		refuse(player, spotId, "Keep going, the bar is up")
		return
	end
	if entry.lockedBy ~= 0 then
		refuse(player, spotId, "Someone else is rescuing it")
		return
	end
	if CatService.inCatch(player) then
		refuse(player, spotId, "Finish this catch first")
		return
	end
	if attemptOf(player) ~= nil then
		refuse(player, spotId, "Finish this rescue first")
		return
	end
	local now = serverNow()
	local selfRetry = entry.selfRetryAt[player.UserId]
	if selfRetry ~= nil and now < selfRetry then
		refuse(player, spotId, "Catch your breath, then try again")
		return
	end
	if now < entry.retryAt then
		refuse(player, spotId, "Give it a moment")
		return
	end
	if not withinRange(player, entry.spot.Position, Config.GrabRangeStuds + 2) then
		refuse(player, spotId, "Too far away")
		return
	end

	local challenge = Rescue.newChallenge(entry.def.rarity, entry.trap, now, function()
		return rng:NextNumber()
	end)
	local attempt = Rescue.newAttempt(challenge)
	entry.attempt = attempt
	setLock(entry, player.UserId)
	profile.stats.rescueAttempts += 1
	Net.fire(player, "RescueChallenge", spotId, challenge)
	entry.funnel = Telemetry.catchEngaged(player, entry.def.rarity, "rescue", entry.area)
	watch(player, entry, attempt)
end

local function logPress(player: Player, entry: Stuck, result: string, marker: number, zone: number?)
	-- Studio only: QA reads where the server saw the marker; live servers stay quiet.
	if not RunService:IsStudio() then
		return
	end
	local attempt = entry.attempt
	print(
		string.format(
			"[Rescue] %d %s %s: marker %.3f, zone %s, hits %d, paws %d",
			player.UserId,
			entry.spotId,
			result,
			marker,
			if zone ~= nil then string.format("%.3f", zone) else "none",
			if attempt ~= nil then attempt.hits else 0,
			if attempt ~= nil then attempt.paws else 0
		)
	)
end

-- The stage after a press moved it on. A call, so the checker does not keep the stage it narrowed before.
local function stageOf(attempt: Rescue.Attempt): Rescue.Stage
	return attempt.stage
end

local function onRescuePress(player: Player, rawSpotId: unknown)
	local spotId = Guard.id(rawSpotId)
	if spotId == nil then
		return
	end
	local entry = stuckCats[spotId]
	if entry == nil or not entry.alive or entry.lockedBy ~= player.UserId then
		return
	end
	local attempt = entry.attempt
	if attempt == nil then
		return
	end
	local arrival = serverNow()
	local pressTime = arrival - Circles.latency(player:GetNetworkPing())
	local stage = stageOf(attempt)
	if stage == "bar" then
		local zone = (attempt.challenge.zones or {})[attempt.hits + 1]
		local result = Rescue.pressBar(attempt, pressTime)
		if result == "ignored" then
			-- too early, or arriving after the deadline: end it now rather than at the next watch tick
			if Rescue.expire(attempt, arrival) then
				finish(player, entry, attempt, nil)
			end
			return
		end
		logPress(player, entry, result, Rescue.markerAt(attempt.challenge, pressTime), zone)
		local after = stageOf(attempt)
		if after == "falling" then
			-- The last shake: the bar's count first, then the falling cat's circle.
			sendResult(player, entry, attempt)
			local circle = Rescue.startCircle(attempt, serverNow(), function()
				return rng:NextNumber()
			end)
			Net.fire(player, "RescueChallenge", spotId, circle)
		elseif after == "done" then
			finish(player, entry, attempt, nil)
		else
			sendResult(player, entry, attempt)
		end
	elseif stage == "circle" then
		Rescue.pressCircle(attempt, pressTime, arrival)
		if stageOf(attempt) == "done" then
			finish(player, entry, attempt, nil)
		end
	end
end

local function onRescueCancel(player: Player, rawSpotId: unknown)
	local spotId = Guard.id(rawSpotId)
	if spotId == nil then
		return
	end
	local entry = stuckCats[spotId]
	if entry == nil or not entry.alive or entry.lockedBy ~= player.UserId then
		return
	end
	local attempt = entry.attempt
	if attempt ~= nil then
		finish(player, entry, attempt, nil, true)
	end
end

-- Lifecycle ---------------------------------------------------------------------------------------------------

function RescueService.start(builtWorld: WorldBuilder.World)
	world = builtWorld
	strayFolder = CatService.strayFolder()

	Net.on("RescueBegin", onRescueBegin)
	Net.on("RescuePress", onRescuePress)
	Net.on("RescueCancel", onRescueCancel)

	-- A catch cannot start while this player's rescue runs, and fast travel waits for it (CatService.busyReason).
	CatService.setRescueCheck(function(player: Player): boolean
		return attemptOf(player) ~= nil
	end)

	Players.PlayerRemoving:Connect(function(player)
		local entry = attemptOf(player)
		if entry ~= nil and entry.attempt ~= nil then
			finish(player, entry, entry.attempt, nil)
		end
	end)
end

-- Dusk (v0.9, F66): every trap empties. A trap someone is mid-attempt on empties when that attempt ends, freed into
-- their arms or not.
function RescueService.nightFalls()
	local clearing: { Stuck } = {}
	for _, entry in stuckCats do
		table.insert(clearing, entry)
	end
	for _, entry in clearing do
		if entry.attempt == nil then
			clearStuck(entry)
			continue
		end
		task.spawn(function()
			while entry.alive and entry.attempt ~= nil do
				task.wait(0.5)
			end
			clearStuck(entry)
		end)
	end
end

-- Sunrise (v0.9, F66): every area's traps roll their cats.
function RescueService.sunrise()
	for _, areaDef in Catalog.areas do
		rollRescues(areaDef)
	end
end

-- How many traps hold a stuck cat right now, across all areas.
function RescueService.stuckCount(): number
	local n = 0
	for _ in stuckCats do
		n += 1
	end
	return n
end

-- Studio-only test hook: puts a stuck cat at a trap (the first trap of the alley when none is given), replacing
-- any cat already there. `gold` forces the hidden roll. Returns the rescueSpotId.
function RescueService.debugSpawnStuck(catId: string, spotId: string?, gold: boolean?): string
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
			local charm = CatStats.rollCharm(rng:NextNumber(), rng:NextNumber())
			spawnStuck(
				wanted,
				areaId,
				spot,
				def :: Types.CatDef,
				charm,
				if gold then "gold" else "base"
			)
			return wanted
		end
	end
	error("unknown rescue spot " .. wanted)
end

return RescueService
