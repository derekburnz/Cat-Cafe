--!strict
-- Rescue traps (data-model section 10b, F27): some days a cat is stuck at a trap, and a short minigame frees it.
-- NightService empties the traps at dusk and fills them at sunrise (v0.9, F66); since #2240 each sunrise also picks which
-- of the area's pool of spots hold traps that day (RescuePick).
-- RescueBegin locks the trap to one player and sends the challenge; RescuePress carries the press's own server-clock
-- time, which the server keeps within half the player's ping (plus Rescue.PRESS_SLACK) of arrival (#2241; with no
-- time it stamps the press on arrival and takes off half the ping); enough hits free the cat into the player's arms, out
-- of paws, out of time, walking away, Give up, dying or leaving ends the attempt and the cat stays stuck. A failed
-- attempt never loses the cat. The cat's charm and gold roll stay here until it is free (reviewer N30).
-- F93 (catch-rework.md section 4): every hit makes the marker faster, and each RescueResult carries the bar as it now
-- runs (Types.RescueBar). Derek 2026-11-03: a zone stays until it is hit (only a miss costs a paw), and a tree frees
-- its cat on the last shake unless Config.RescueTreeCircle brings back the falling cat's catch circle.
-- F92 (playing-together.md section 3): Team Rescue. While a trap is locked to a rescuer, one other player within
-- TeamRescueRangeStuds who is not carrying can join with RescueHelp: they get the same bar as it runs now
-- (Rescue.helperChallenge), the attempt gets TeamRescueExtraSeconds, either player's hit counts and the helper's miss
-- costs no paw. The cat always goes to the rescuer; the helper gets Rescue.helperTip (twice between pals) at most once
-- per TeamRescueTipCooldown, and both get TeamRescue for the pop. The trap's model carries HelpedBy (0, or the
-- helper's user id until the attempt ends), so each client can show "Help" only where a helper is still wanted.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AssetRegistry = require(script.Parent.Parent.World.AssetRegistry)
local CafeService = require(script.Parent.CafeService)
local CatService = require(script.Parent.CatService)
local CatStats = require(ReplicatedStorage.Shared.CatStats)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Catching = require(ReplicatedStorage.Shared.Catching)
local Clock = require(ReplicatedStorage.Shared.Clock)
local ClockService = require(script.Parent.ClockService)
local Config = require(ReplicatedStorage.Shared.Config)
local Cooldown = require(ReplicatedStorage.Shared.Cooldown)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Guard = require(script.Parent.Parent.Util.Guard)
local IndexRewards = require(ReplicatedStorage.Shared.IndexRewards)
local Layout = require(script.Parent.Parent.World.Layout)
local LiveFlagService = require(script.Parent.LiveFlagService)
local Luck = require(ReplicatedStorage.Shared.Luck)
local Net = require(script.Parent.Net)
local NetSwing = require(ReplicatedStorage.Shared.NetSwing)
local PalService = require(script.Parent.PalService)
local Payout = require(script.Parent.Payout)
local RallyService = require(script.Parent.RallyService)
local Rescue = require(ReplicatedStorage.Shared.Rescue)
local RescuePick = require(ReplicatedStorage.Shared.RescuePick)
local StationPerks = require(ReplicatedStorage.Shared.StationPerks)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local RescueService = {}
-- #2335: the trap prompt's HoldDuration: 0, one press starts a rescue
RescueService.PROMPT_HOLD_SECONDS = 0

-- A player more than this far from the trap ends their attempt (data-model section 10b).
local LEAVE_RANGE_STUDS = 14

type Stuck = {
	spotId: string,
	area: string,
	trap: string, -- TrapType: "trash_bin", "garbage_bag", "tree", "trashcan" or a provisional trap
	def: Types.CatDef,
	charm: number, -- rolled at sunrise, kept here until the rescue succeeds (N30)
	variant: string, -- "base", "gold" or "rainbow" (F99), likewise hidden until then
	model: Model,
	spot: BasePart,
	lockedBy: number, -- the player whose attempt is running, else 0
	attempt: Rescue.Attempt?,
	retryAt: number, -- server time anyone may start after a failed attempt (RescueRetrySeconds)
	selfRetryAt: { [number]: number }, -- per player who failed: RescueSelfRetrySeconds
	funnel: Telemetry.CatchFunnel?, -- the lock holder's catch_attempt funnel (F16)
	helper: Player?, -- F92: the Team Rescue helper now on the bar, if any
	helperPals: boolean, -- F92: whether that helper and the rescuer were pals when they joined
	alive: boolean,
}

local world: WorldBuilder.World
local strayFolder: Instance
local stuckCats: { [string]: Stuck } = {} -- rescueSpotId -> stuck cat
-- #2240: area id -> the spots that hold traps today (RescuePick), so tomorrow's pick avoids them
local activeSpots: { [string]: { [string]: boolean } } = {}
local helperTipAt: { [Player]: number } = {} -- F92: os.clock() of each player's last helper's tip this session
-- #3049: area id -> today's starter trap (#2794), and the os.clock() it was last emptied (nil while it holds a cat)
local starterSpots: { [string]: string } = {}
local starterEmptiedAt: { [string]: number } = {}
local starterRefills: { [string]: number } = {} -- area id -> refills since sunrise (StarterRescueRefillsPerDay)
local STARTER_CHECK_SECONDS = 5
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

local function setHelpedBy(entry: Stuck, userId: number)
	entry.model:SetAttribute("HelpedBy", userId)
	entry.spot:SetAttribute("HelpedBy", userId)
end

local function setLock(entry: Stuck, userId: number)
	entry.lockedBy = userId
	if userId == 0 then
		entry.attempt = nil
		entry.helper = nil
		setHelpedBy(entry, 0)
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

-- The running attempt this player is helping (F92), if any.
local function helpingOf(player: Player): Stuck?
	for _, entry in stuckCats do
		if entry.alive and entry.helper == player and entry.attempt ~= nil then
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
	entry.helper = nil
	entry.spot:SetAttribute("Occupied", false)
	entry.spot:SetAttribute("LockedBy", 0)
	entry.spot:SetAttribute("HelpedBy", 0)
	entry.spot:SetAttribute("RetryAt", 0)
	entry.model:Destroy()
	if starterSpots[entry.area] == entry.spotId then
		starterEmptiedAt[entry.area] = os.clock() -- #3049: the refill's wait starts here
	end
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
	model:SetAttribute("HelpedBy", 0) -- F92
	CollectionService:AddTag(model, "StuckCat")

	-- #2335 (Derek2: "make rescue a one click thing instead of hold"): one press of E or one tap of the card's RESCUE
	-- button starts the minigame (HoldDuration 0; was Config.CatchHoldSeconds); the UI's card reads "Rescue".
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RescuePrompt"
	prompt.ActionText = "Rescue"
	prompt.ObjectText = def.name
	prompt.HoldDuration = RescueService.PROMPT_HOLD_SECONDS
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
	spot:SetAttribute("HelpedBy", 0)
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
		helperPals = false,
		alive = true,
	}
	stuckCats[spotId] = entry
	return entry
end

-- Rolls the cat, its charm and its coat now, at sunrise, from the area's rescue odds; the gold chance has the best
-- gold luck among the players with the area open (F54), the rainbow chance (F99, rolled first on the same roll) the
-- best rainbow luck. On a Lucky Day (F88) the traps roll at
-- LuckyDayWaveLuck, like the wave; nobody's own Luck touches them.
local function rollStuckCat(spotId: string, areaDef: Types.AreaDef, spot: BasePart): Stuck
	local luck = if ClockService.luckyDay() then Config.LuckyDayWaveLuck else 1
	local rarity: Types.Rarity =
		Catching.pickRarity(Luck.apply(Catching.rescueOdds(areaDef.odds), luck), rng:NextNumber())
	local def = Catching.pickCat(rarity, areaDef.id, rng:NextNumber())
	local charm = CatStats.rollCharm(rng:NextNumber(), rng:NextNumber())
	local variant = Catching.rollCoat(
		def,
		rng:NextNumber(),
		IndexRewards.rainbowChance(
			Clock.rainbowChance(Config.RainbowChanceRescue, ClockService.dayKinds()),
			CatService.rainbowLuckFor(areaDef.id)
		),
		IndexRewards.rollChance(
			Clock.goldChance(Config.GoldChanceRescue, ClockService.dayKinds()),
			CatService.goldLuckFor(areaDef.id)
		)
	)
	return spawnStuck(spotId, areaDef.id, spot, def, charm, variant)
end

-- #2240: today's traps in `area`, RescuePick's choice of the area's mix from its pool of spots, away from yesterday's.
-- #2794: with `starter`, the pool's spot nearest the camp's pad is picked every day and returned second.
local function pickTraps(
	areaId: string,
	area: WorldBuilder.AreaInfo,
	starter: boolean
): ({ string }, string?)
	local pool: { RescuePick.Candidate } = {}
	for spotId, spot in area.rescueSpots do
		local trap = spot:GetAttribute("TrapType")
		table.insert(pool, {
			id = spotId,
			trap = if type(trap) == "string" then trap else "",
			position = spot.Position,
		})
	end
	local keep: string? = nil
	local camp = Layout.camps[areaId]
	if starter and camp ~= nil then
		keep = RescuePick.nearest(pool, camp.pad.x, camp.pad.z)
	end
	local ids = RescuePick.pick(
		pool,
		area.rescueMix,
		activeSpots[areaId] or {},
		Config.RescueSpotSpacingStuds,
		function(n: number): number
			return rng:NextInteger(1, n)
		end,
		keep
	)
	local active: { [string]: boolean } = {}
	for _, spotId in ids do
		active[spotId] = true
	end
	activeSpots[areaId] = active
	for _, spotId in ids do
		if spotId == keep then
			return ids, spotId
		end
	end
	return ids, nil
end

-- Sunrise: the area's traps for the day are picked from its pool (#2240), each drops any cat still in it and rolls
-- RescueSpawnChance for a new one, and an area where no trap rolled a cat gets RescueMinStuck anyway, so a new player
-- always meets a rescue on the first day. A trap someone is mid-attempt on keeps its cat (dusk emptied the rest, so
-- that only happens after Studio's setPhase), and a cat at a spot not picked today is cleared.
-- #2794: a starting area (`starterRescue`, the Alleyway and the Park) keeps its trap nearest the camp out every day
-- and always puts a cat in it, and its own `rescueMinStuck` replaces RescueMinStuck.
local function rollRescues(areaDef: Types.AreaDef)
	local area = world.areas[areaDef.id]
	local stuck = 0
	local free: { string } = {}
	-- sorted, so a spec or a Studio session can predict the guarantee
	local ids, starter = pickTraps(areaDef.id, area, areaDef.starterRescue == true)
	starterSpots[areaDef.id] = starter :: string -- nil for an area without one
	starterRefills[areaDef.id] = 0
	local today: { [string]: boolean } = {}
	for _, spotId in ids do
		today[spotId] = true
	end
	for spotId in area.rescueSpots do
		local current = stuckCats[spotId]
		if not today[spotId] and current ~= nil and current.attempt == nil then
			clearStuck(current)
		end
	end
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
		if spotId == starter or rng:NextNumber() < Config.RescueSpawnChance then
			rollStuckCat(spotId, areaDef, spot)
			stuck += 1
		else
			table.insert(free, spotId)
		end
	end
	while stuck < (areaDef.rescueMinStuck or Config.RescueMinStuck) and #free > 0 do
		local spotId = table.remove(free, rng:NextInteger(1, #free)) :: string
		rollStuckCat(spotId, areaDef, area.rescueSpots[spotId])
		stuck += 1
	end
end

-- #3049: a starting area's camp trap, emptied during the day (rescued, or its cat cleared), gets a new cat
-- StarterRescueRefillSeconds later while someone in the server has the area open and has never rescued, so a new
-- player who joins after others took the day's cats still finds the rescue the tutorial points at. Rolled like any
-- stuck cat. Off at dusk and at night, with the starterRefill switch off, when only veterans are in, and after
-- StarterRescueRefillsPerDay refills in that area since sunrise.
local function refillStarters()
	for _, areaDef in Catalog.areas do
		local spotId = starterSpots[areaDef.id]
		local emptiedAt = starterEmptiedAt[areaDef.id]
		local area = world.areas[areaDef.id]
		if spotId == nil or emptiedAt == nil or area == nil or stuckCats[spotId] ~= nil then
			continue
		end
		local spot: BasePart? = area.rescueSpots[spotId]
		local waiting, first = 0, nil :: Player?
		for _, player in DataService.loadedPlayers() do
			local profile = DataService.get(player)
			if
				profile ~= nil
				and Rescue.waitsForFirst(profile.stats.rescues, Economy.tier(profile), areaDef.tier)
			then
				waiting += 1
				first = first or player
			end
		end
		if
			spot ~= nil
			and first ~= nil
			and Rescue.starterRefill(
				LiveFlagService.on("starterRefill"),
				ClockService.phase(),
				ClockService.phaseEndsAt() - Workspace:GetServerTimeNow(),
				os.clock() - emptiedAt,
				waiting,
				starterRefills[areaDef.id] or 0
			)
		then
			starterEmptiedAt[areaDef.id] = nil
			starterRefills[areaDef.id] = (starterRefills[areaDef.id] or 0) + 1
			rollStuckCat(spotId, areaDef, spot)
			-- how often it fires, by area and how many were waiting (counts only)
			Telemetry.custom(first, "rescue_refill", 1, { areaDef.id, tostring(waiting) })
		end
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
		done and attempt.success,
		Rescue.barState(attempt)
	)
end

-- The bar's count to the rescuer and to the helper on it (F92).
local function sendAll(player: Player, entry: Stuck, attempt: Rescue.Attempt)
	sendResult(player, entry, attempt)
	local helper = entry.helper
	if helper ~= nil and helper.Parent == Players then
		sendResult(helper, entry, attempt)
	end
end

-- The helper leaves the bar (F92): Give up, walking away, dying or leaving. The attempt runs on for the rescuer and
-- keeps its later deadline; nobody else may join it (one helper an attempt). The helper's bar closes with a done
-- RescueResult that is not a success, and `reason` is a toast for an end the bar does not show.
local function dropHelper(entry: Stuck, attempt: Rescue.Attempt, reason: string?)
	local helper = entry.helper
	if helper == nil then
		return
	end
	entry.helper = nil
	if helper.Parent ~= Players then
		return
	end
	Net.fire(
		helper,
		"RescueResult",
		entry.spotId,
		attempt.hits,
		attempt.paws,
		true,
		false,
		Rescue.barState(attempt)
	)
	if reason ~= nil then
		Net.toast(helper, reason, "warn")
	end
end

-- A helped attempt freed its cat (F92): the helper's tip (Rescue.helperTip, twice between pals) unless they had one
-- within TeamRescueTipCooldown, then TeamRescue to both for the pop: (rescueSpotId, rescuerUserId, helperUserId,
-- position, coins this player got).
local function teamRescued(rescuer: Player, helper: Player, entry: Stuck, pals: boolean)
	local profile = if helper.Parent == Players then DataService.get(helper) else nil
	local tip = 0
	if profile ~= nil then
		local now = os.clock()
		if Rescue.helperTipReady(helperTipAt[helper], now) then
			tip = Rescue.helperTip(Economy.incomePerSecond(profile), pals)
			if tip > 0 then
				helperTipAt[helper] = now
				Economy.credit(profile, tip)
				Telemetry.source(helper, profile, tip, "Gameplay", "helper_tip")
				CafeService.sync(helper)
			end
		end
	end
	if profile ~= nil then
		RallyService.score(helper, "teamRescue") -- F101: the helper's points; the rescuer scores at check-in
		profile.stats.teamRescuesHelped += 1 -- #1934: the Helping Paw badge
	end
	local position = entry.spot.Position
	Net.fire(rescuer, "TeamRescue", entry.spotId, rescuer.UserId, helper.UserId, position, 0)
	if profile ~= nil then
		Net.fire(helper, "TeamRescue", entry.spotId, rescuer.UserId, helper.UserId, position, tip)
	end
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
	local helper = entry.helper -- F92: still on the bar at the end
	local pals = entry.helperPals
	setLock(entry, 0)
	if present then
		sendResult(player, entry, attempt)
	end
	if helper ~= nil and helper.Parent == Players then
		sendResult(helper, entry, attempt)
	end
	if attempt.helped == true then
		local fields: { string } = {
			entry.def.rarity :: string,
			if success then "yes" else "no",
			if pals then "yes" else "no",
		}
		Telemetry.custom(player, "team_rescue", 1, fields)
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
			Telemetry.onboarding(player, profile, "first_rescue_done")
			-- #1181 (corner-shop-v2.md section 3): a Small Snack into the Bag for every cat rescued
			local paid = Payout.pay(
				player,
				profile,
				{ catFood = { [Config.RescueSnack] = 1 } },
				"rescue_snack"
			)
			if #paid > 0 then
				Net.toast(player, paid[1] .. " in your Bag", "good")
			end
		end
		-- the spot it was stuck at, so a Drop walks it back near the trap (F67)
		CatService.startCarry(player, def, "rescue", charm, variant, funnel, entry.spot.Position)
		if helper ~= nil then
			teamRescued(player, helper, entry, pals)
		end
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

-- The stage after a press or a tick moved it on. A call, so the checker does not keep the stage it narrowed before.
local function stageOf(attempt: Rescue.Attempt): Rescue.Stage
	return attempt.stage
end

-- Watches an attempt until it ends: its deadline, the player walking more than LEAVE_RANGE_STUDS away or dying.
local function watch(player: Player, entry: Stuck, attempt: Rescue.Attempt)
	task.spawn(function()
		while entry.attempt == attempt do
			task.wait(0.2)
			if entry.attempt ~= attempt then
				return
			end
			local now = serverNow()
			if Rescue.expire(attempt, now) then
				finish(player, entry, attempt, nil) -- out of time: the bar shows it on its own clock
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
			local helper = entry.helper
			if helper ~= nil then
				if helper.Parent ~= Players or not alive(helper) then
					dropHelper(entry, attempt, nil)
				elseif not withinRange(helper, entry.spot.Position, LEAVE_RANGE_STUDS) then
					dropHelper(entry, attempt, "You walked away from the rescue")
				end
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
	if CatService.inFlight(player) then
		return -- mid flight or hop (F84)
	end
	if CatService.campOf(player) ~= nil then
		refuse(player, spotId, "Step out of the camp to rescue it")
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
	if attemptOf(player) ~= nil or helpingOf(player) ~= nil then
		refuse(player, spotId, "Finish this rescue first")
		return
	end
	local now = serverNow()
	local selfRetry = entry.selfRetryAt[player.UserId]
	if selfRetry ~= nil and now < selfRetry then
		refuse(player, spotId, Cooldown.text(selfRetry - now)) -- #2324
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

	-- #2687: the Oasis Spa's Warm Paws widens the zones from Tier 6; #2786: the first two areas' bars are easier;
	-- #3120: this account's first rescues are wider; #3135: a gold or rainbow cat's zone is a little narrower
	local zoneScale = StationPerks.rescueZoneScale(Economy.tier(profile))
		* Rescue.zoneScale(profile.stats.rescues, entry.variant)
	local challenge = Rescue.newChallenge(entry.def.rarity, entry.trap, now, function()
		return rng:NextNumber()
	end, zoneScale, entry.area)
	local attempt = Rescue.newAttempt(challenge, entry.def.rarity)
	entry.attempt = attempt
	setLock(entry, player.UserId)
	profile.stats.rescueAttempts += 1
	Net.fire(player, "RescueChallenge", spotId, challenge)
	entry.funnel = Telemetry.catchEngaged(player, entry.def.rarity, "rescue", entry.area)
	Telemetry.onboarding(player, profile, "first_rescue_started")
	watch(player, entry, attempt)
end

-- F92: RescueHelp joins someone else's running bar as its one helper.
local function onRescueHelp(player: Player, rawSpotId: unknown)
	local spotId = Guard.id(rawSpotId)
	local profile = DataService.get(player)
	if spotId == nil or profile == nil then
		return
	end
	local entry = stuckCats[spotId]
	if entry == nil or not entry.alive then
		return
	end
	local attempt = entry.attempt
	if attempt == nil or entry.lockedBy == 0 then
		-- the attempt ended while the Help press was on its way: the trap is free, so this is a plain rescue now
		-- (review N317), with all of RescueBegin's checks and waits
		onRescueBegin(player, spotId)
		return
	end
	if entry.lockedBy == player.UserId or entry.helper == player then
		refuse(player, spotId, "Keep going, the bar is up")
		return
	end
	if attempt.helped == true then
		refuse(player, spotId, "Someone is already helping")
		return
	end
	if attempt.stage ~= "bar" then
		refuse(player, spotId, "Almost free, no help needed")
		return
	end
	if CatService.isCarrying(player) then
		refuse(player, spotId, "Check in the cat you are carrying first")
		return
	end
	if CatService.inFlight(player) then
		return
	end
	if CatService.campOf(player) ~= nil then
		refuse(player, spotId, "Step out of the camp to help")
		return
	end
	if not areaUnlocked(profile, entry.area) then
		refuse(player, spotId, "This area opens at a higher tier. Rank up to help here")
		return
	end
	if not ClockService.areasOpen() then
		refuse(player, spotId, Clock.CLOSED_TEXT)
		return
	end
	if CatService.inCatch(player) then
		refuse(player, spotId, "Finish this catch first")
		return
	end
	if attemptOf(player) ~= nil or helpingOf(player) ~= nil then
		refuse(player, spotId, "Finish this rescue first")
		return
	end
	-- 2 studs of slack for movement in flight, as for RescueBegin
	if not withinRange(player, entry.spot.Position, Config.TeamRescueRangeStuds + 2) then
		refuse(player, spotId, "Too far away")
		return
	end
	local rescuer = Players:GetPlayerByUserId(entry.lockedBy)
	if rescuer == nil or not Rescue.addHelper(attempt) then
		return
	end
	entry.helper = player
	entry.helperPals = PalService.arePals(player, rescuer)
	setHelpedBy(entry, player.UserId)
	Net.fire(player, "RescueChallenge", spotId, Rescue.helperChallenge(attempt))
	sendResult(rescuer, entry, attempt) -- the rescuer's bar learns the later deadline (RescueBar.endsAt)
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

local judge: (Player, Stuck, Rescue.Attempt, Player, boolean, number, number) -> ()

local function onRescuePress(player: Player, rawSpotId: unknown, rawPressedAt: unknown)
	local spotId = Guard.id(rawSpotId)
	if spotId == nil then
		return
	end
	local entry = stuckCats[spotId]
	if entry == nil or not entry.alive then
		return
	end
	-- F92: a helper's press counts like the rescuer's on the bar, but its miss costs no paw, and the tree's falling
	-- cat is the rescuer's alone. Whatever it ends goes through the rescuer, who gets the cat.
	local helping = entry.helper == player and entry.lockedBy ~= player.UserId
	if entry.lockedBy ~= player.UserId and not helping then
		return
	end
	local attempt = entry.attempt
	if attempt == nil then
		return
	end
	local rescuer = if helping then Players:GetPlayerByUserId(entry.lockedBy) else player
	if rescuer == nil then
		return -- the rescuer is leaving; PlayerRemoving ends the attempt
	end
	local arrival = serverNow()
	local pressTime = Rescue.pressedAt(arrival, player:GetNetworkPing(), rawPressedAt)
	judge(player, entry, attempt, rescuer, helping, pressTime, arrival)
end

-- One press judged at `pressTime` (arrived at `arrival`) and everything it ends or sends.
function judge(
	player: Player,
	entry: Stuck,
	attempt: Rescue.Attempt,
	rescuer: Player,
	helping: boolean,
	pressTime: number,
	arrival: number
)
	local spotId = entry.spotId
	local stage = stageOf(attempt)
	if stage == "bar" then
		local result = Rescue.pressBar(attempt, pressTime, helping)
		if result == "ignored" then
			-- too early, or arriving after the deadline: end it now rather than at the next watch tick
			if stageOf(attempt) == "done" or Rescue.expire(attempt, arrival) then
				finish(rescuer, entry, attempt, nil)
			end
			return
		end
		local judged = attempt.lastPressAt
		local zone = if result == "hit"
			then (attempt.challenge.zones or {})[attempt.zone - 1]
			else Rescue.currentZone(attempt)
		-- a hit restarts the marker from the spot it was judged at, so this is where the server saw it either way
		logPress(player, entry, result, Rescue.marker(attempt, judged), zone)
		local after = stageOf(attempt)
		if after == "falling" then
			-- The last shake: the bar's count first, then the falling cat's circle, the rescuer's to catch.
			sendAll(rescuer, entry, attempt)
			local circle = Rescue.startCircle(attempt, serverNow(), function()
				return rng:NextNumber()
			end)
			Net.fire(rescuer, "RescueChallenge", spotId, circle)
		elseif after == "done" then
			finish(rescuer, entry, attempt, nil)
		else
			sendAll(rescuer, entry, attempt)
		end
	elseif stage == "circle" and not helping then
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
	if entry == nil or not entry.alive then
		return
	end
	local attempt = entry.attempt
	if attempt ~= nil and entry.helper == player and entry.lockedBy ~= player.UserId then
		dropHelper(entry, attempt, nil) -- F92: the helper's Give up leaves the rescuer to it
		return
	end
	if entry.lockedBy ~= player.UserId then
		return
	end
	if attempt ~= nil then
		finish(player, entry, attempt, nil, true)
	end
end

-- Lifecycle ---------------------------------------------------------------------------------------------------

-- #2341 (Derek2: "make the rescue also start if you swing your net at them instead of holding button"): a net swing
-- that landed on no stray (CatService's landSwing) takes the nearest stuck cat in the swing's reach, as NetSwing.pick
-- judges a stray, and does what its prompt would: Help on someone else's running bar, else RescueBegin with all its
-- checks (a refusal shows as for the prompt). False when no stuck cat is in reach.
local function swingAt(player: Player, origin: Vector3, look: Vector3): boolean
	local targets: { NetSwing.Target } = {}
	for spotId, entry in stuckCats do
		if entry.alive and entry.model.Parent ~= nil then
			table.insert(targets, { id = spotId, position = entry.model:GetPivot().Position })
		end
	end
	local picked = NetSwing.pick(origin, look, targets)
	if picked == nil then
		return false
	end
	local entry = stuckCats[picked.id]
	if entry.lockedBy ~= 0 and entry.lockedBy ~= player.UserId then
		onRescueHelp(player, picked.id)
	else
		onRescueBegin(player, picked.id)
	end
	return true
end

function RescueService.start(builtWorld: WorldBuilder.World)
	world = builtWorld
	strayFolder = CatService.strayFolder()

	Net.on("RescueBegin", onRescueBegin)
	CatService.setSwingRescue(swingAt) -- #2341
	Net.on("RescuePress", onRescuePress)
	Net.on("RescueCancel", onRescueCancel)
	Net.on("RescueHelp", onRescueHelp)

	-- A catch cannot start while this player's rescue runs, and fast travel waits for it (CatService.busyReason).
	-- F92: helping counts as in a rescue too.
	CatService.setRescueCheck(function(player: Player): boolean
		return attemptOf(player) ~= nil or helpingOf(player) ~= nil
	end)

	Players.PlayerRemoving:Connect(function(player)
		local entry = attemptOf(player)
		if entry ~= nil and entry.attempt ~= nil then
			finish(player, entry, entry.attempt, nil)
		end
		local helped = helpingOf(player)
		if helped ~= nil and helped.attempt ~= nil then
			dropHelper(helped, helped.attempt, nil)
		end
		helperTipAt[player] = nil
	end)
	task.spawn(function() -- #3049
		while true do
			task.wait(STARTER_CHECK_SECONDS)
			refillStarters()
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

-- Studio-only test hook (Desktop-Tester, 2026-11-07: presses over MCP arrive 2 to 4 s late, too late to time): a
-- bar press for `player`'s running rescue (or the one they help) that `kind` "hit" or "miss" says, judged as a real
-- press through the same path, at the last moment since their last press when the marker sat on the live zone's
-- centre (a hit) or at the bar's end furthest from it (a miss). Returns "hit hits=2/6 paws=3", or why it did nothing.
function RescueService.debugPress(player: Player, kind: string): string
	assert(RunService:IsStudio(), "debugPress is Studio only")
	local entry = attemptOf(player)
	local helping = false
	if entry == nil or entry.attempt == nil then
		entry = helpingOf(player)
		helping = true
	end
	if entry == nil or entry.attempt == nil then
		return "no rescue running"
	end
	local attempt = entry.attempt :: Rescue.Attempt
	if stageOf(attempt) ~= "bar" then
		return "not on the bar: " .. tostring(stageOf(attempt))
	end
	local centre = Rescue.currentZone(attempt)
	if centre == nil then
		return "no zone left"
	end
	local rescuer = if helping then Players:GetPlayerByUserId(entry.lockedBy) else player
	if rescuer == nil then
		return "the rescuer is leaving"
	end
	local now = serverNow()
	local x = if kind == "hit" then centre elseif centre > 0.5 then 0 else 1
	judge(player, entry, attempt, rescuer, helping, Rescue.lastTimeAt(attempt, x, now), now)
	return string.format(
		"%s hits=%d/%d paws=%d stage=%s",
		kind,
		attempt.hits,
		attempt.challenge.hitsNeeded or 0,
		attempt.paws,
		tostring(stageOf(attempt))
	)
end

-- Studio-only test hook (Laptop-Tester, 2026-11-07): ends `player`'s rescue as Give up does, or drops them as a
-- helper. Returns what the server had: "rescuing <spotId>", "helping <spotId>" or "none" (then any rescue screen on
-- that client is the client's alone).
function RescueService.debugCancel(player: Player): string
	assert(RunService:IsStudio(), "debugCancel is Studio only")
	local own = attemptOf(player)
	if own ~= nil and own.attempt ~= nil then
		finish(player, own, own.attempt, nil, true)
		return "rescuing " .. own.spotId
	end
	local helped = helpingOf(player)
	if helped ~= nil and helped.attempt ~= nil then
		dropHelper(helped, helped.attempt, nil)
		return "helping " .. helped.spotId
	end
	return "none"
end

-- Studio-only test hook: puts a stuck cat at a trap (the first trap of the alley when none is given), replacing
-- any cat already there. `coat` forces the hidden roll: "gold" (or true) or "rainbow" (F99). Returns the
-- rescueSpotId.
function RescueService.debugSpawnStuck(
	catId: string,
	spotId: string?,
	coat: (boolean | string)?
): string
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
				if coat == true or coat == "gold"
					then "gold"
					elseif coat == "rainbow" then "rainbow"
					else "base"
			)
			return wanted
		end
	end
	error("unknown rescue spot " .. wanted)
end

return RescueService
