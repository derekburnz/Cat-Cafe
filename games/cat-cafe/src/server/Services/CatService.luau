--!strict
-- Strays: sunrise waves per area, the net (the swing, lock, closing circles, the chase after a miss), carrying a caught
-- or rescued cat home and check-in. The bait bowl is BaitService; NightService closes the areas at night and calls
-- nightFalls, sunriseWave and forceCheckIn (v0.9, F66). Server authoritative: the client only says that it swung
-- (F93) and which circle it pressed for; what the swing lands on, distance, locks, the schedule, the press times, the
-- chase and odds live here.

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local AssetRegistry = require(script.Parent.Parent.World.AssetRegistry)
local Badges = require(ReplicatedStorage.Shared.Badges)
local BagColours = require(ReplicatedStorage.Shared.BagColours)
local CafeService = require(script.Parent.CafeService)
local Cannon = require(ReplicatedStorage.Shared.Cannon)
local CatStats = require(ReplicatedStorage.Shared.CatStats)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Catching = require(ReplicatedStorage.Shared.Catching)
local Circles = require(ReplicatedStorage.Shared.Circles)
local Clock = require(ReplicatedStorage.Shared.Clock)
local ClockService = require(script.Parent.ClockService)
local Config = require(ReplicatedStorage.Shared.Config)
local Cooldown = require(ReplicatedStorage.Shared.Cooldown)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local EventRewardService = require(script.Parent.EventRewardService)
local Guard = require(script.Parent.Parent.Util.Guard)
local HeldCat = require(ReplicatedStorage.Shared.HeldCat)
local IndexRewards = require(ReplicatedStorage.Shared.IndexRewards)
local Layout = require(script.Parent.Parent.World.Layout)
local LiveFlagService = require(script.Parent.LiveFlagService)
local Luck = require(ReplicatedStorage.Shared.Luck)
local Moods = require(ReplicatedStorage.Shared.Moods)
local Mover = require(ReplicatedStorage.Shared.Mover)
local Net = require(script.Parent.Net)
local NetSwing = require(ReplicatedStorage.Shared.NetSwing)
local NightPass = require(ReplicatedStorage.Shared.NightPass)
local Onboarding = require(ReplicatedStorage.Shared.Onboarding)
local Payout = require(script.Parent.Payout)
local Pity = require(ReplicatedStorage.Shared.Pity)
local PlotService = require(script.Parent.PlotService)
local Potions = require(ReplicatedStorage.Shared.Potions)
local RallyService = require(script.Parent.RallyService)
local RareMomentService = require(script.Parent.RareMomentService)
local RareMoments = require(ReplicatedStorage.Shared.RareMoments)
local SecondCat = require(ReplicatedStorage.Shared.SecondCat)
local SecretBeacons = require(script.Parent.SecretBeacons)
local Shove = require(ReplicatedStorage.Shared.Shove)
local SpeedShoes = require(ReplicatedStorage.Shared.SpeedShoes)
local StationPerks = require(ReplicatedStorage.Shared.StationPerks)
local StrayTopUp = require(ReplicatedStorage.Shared.StrayTopUp)
local SwiftPaws = require(ReplicatedStorage.Shared.SwiftPaws)
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
	spawnedAt: number,
	pointIndex: number?, -- spawn point it occupies
	home: Vector3,
	lockedBy: number,
	lockUntil: number, -- server time the lock lapses on its own; 0 when unlocked
	attempt: Circles.Attempt?, -- the circles of the lock holder's catch in progress
	-- v0.5 (data-model section 10 step 5): server time the sprint after a miss and the breather end; nobody starts
	-- a catch before it. Tries are unlimited, so there is no per-player table.
	fleeingUntil: number,
	-- server time each player who missed may try again: their Catching.selfRetrySeconds after it stops (reviewer S44,
	-- F57), from their misses in a row on it
	selfRetryAt: { [number]: number },
	missStreak: { [number]: Catching.MissStreak },
	jumping: boolean, -- sprinting or catching its breath: no wandering
	charm: number, -- rolled at spawn (section 4b); a net catch adds the Perfect bonus
	-- "rainbow" (RainbowChanceNet with rainbow luck, F99) or "gold" (GoldChanceNet with gold luck), rolled at spawn
	-- and shown on the model (the Variant attribute; Gold too for a gold one), else "base"
	variant: string,
	method: Types.CatchMethod, -- "net", or what a Dropped cat was before it fell (its rescued flag, 10c)
	-- set on a Dropped stray (section 10c, S25): a shove knocked it out of someone's arms or they let it go. It has
	-- no circles: the first swing that lands on it picks it up (v0.8 F56, F93).
	drop: Shove.Drop?,
	-- F67 (section 10c v0.10): where a Dropped cat was first caught, kept through every pick up and drop, and true
	-- while one let go with the Drop button walks back there. Home again it is a normal stray whose next catch adds
	-- no charm (`recaught`, as S36).
	homePos: Vector3?,
	returning: boolean,
	recaught: boolean,
	funnel: Telemetry.CatchFunnel?, -- the lock holder's catch_attempt funnel (F16)
	knocks: number, -- F84: times tackles knocked this cat loose since it was first caught (camp_checkin)
	pity: boolean?, -- #2567: a pity or shower cat (and the cat it became when knocked loose): no cross-server line
	-- F87 (easy-start.md section 2b): the user id of the beginner this tutorial stray waits for, mirrored in the
	-- model's Beginner attribute (0 when none). Their catch is one slow circle and a Miss brings it back instead of
	-- sending the cat running. LockedBy stays the catch lock the effects read.
	-- #3181: it is no longer theirs alone. Anyone may swing at it and catch it (a beginner with the same easy catch,
	-- anyone else with a Common's own circles), and tutorialTick puts a new one at the beginner's point.
	beginner: number?,
	-- #3022 (shared/SecondCat): the user id of the player this stray waits for near the Alleyway camp's landing, from
	-- their first customer served until their second cat, mirrored in the model's WaitsFor attribute (0 when none).
	-- Anyone may catch it; for that player its catch is the first catch's one slow circle.
	waitsFor: number?,
	-- #3035: the user id of the first-session Tier 1 player whose night pass brought it (shared/NightPass), at their
	-- plot's `near` point. Not reserved: anyone out at night may catch it. It leaves by night once that player's pass
	-- ends, and is an ordinary stray from the sunrise.
	nightFor: number?,
	-- #1884 (catch-rework.md 7a): its mood, rolled at spawn (the Mood attribute); a Curious one's walk toward a
	-- player (server time, nil until it notices one) and a Skittish one's last hop (server time)
	mood: Types.CatMood,
	curiousAt: number?,
	skittishAt: number?,
	walk: number, -- bumped by every walk that starts, so an older walk stops where it is
	alive: boolean,
}

-- variant is "gold" or "rainbow" (F99) for those coats (a rescue rolls it at night start, data-model section 4); nil
-- is the base.
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
	homePos: Vector3?, -- F67: where it was caught (a rescue: the cat spot nearest its trap), for a Drop to walk back to
	knocks: number, -- F84: times tackles knocked it loose since it was first caught (camp_checkin)
	pity: boolean?, -- #2567: a pity or shower cat, so its check-in line stays in this server
	bonusXp: number?, -- #1884 (catch-rework.md 7d): a PURRFECT catch's XP, given as it checks in
}

-- What a Dropped cat keeps from the arms it fell out of (section 10c): charm, gold and rescued flag.
type Kept = {
	charm: number?,
	variant: string?,
	method: Types.CatchMethod,
	drop: Shove.Drop,
	homePos: Vector3?, -- F67: where it was caught, carried on to the next carry
	returning: boolean?, -- F67: let go with the Drop button, so it walks back to homePos
	knocks: number?, -- F84: times tackles knocked it loose so far
	pity: boolean?, -- #2567
}

local world: WorldBuilder.World
local straysFolder: Folder
local strays: { [string]: Stray } = {}
local occupiedPoints: { [string]: { [number]: string } } = {} -- area -> point index -> stray id
local carrying: { [Player]: Carry } = {}
-- #2565 (mystery-market.md section 3): a Backpack's second cat, packed on the back with the net still out. It goes in
-- first (hands free) and the next catch goes into the hands; it checks in with the held one, drops with it on a
-- tackle, a death or the Drop button's second press, and blocks the cannon and travel like a held cat (tackling only
-- since #2731, which lets a player with only a packed cat tackle).
local packed: { [Player]: Carry } = {}
local circleHistory: { [Player]: { boolean } } = {} -- last judged circles per player, true for Perfect (S23)
local snackRandom = Random.new() -- #1181: the catch's snack drop
local lastCatchStart: { [Player]: number } = {} -- server time of the player's last catch start or pick up
local startledUntil: { [Player]: number } = {} -- server time each player's Startled slow ends (F57)
local rng = Random.new()
local nextStrayNumber = 0
-- #1572: PityService's claim on a pity cat's catch (the first catch in any server wins): true to keep it. It yields.
local pityClaim: ((Player, number) -> boolean)? = nil
local pityStarted: ((Player, number) -> ())? = nil -- #2796: PityService's pity_v1 catch-started step
local pityKeeps: ((number) -> boolean)? = nil -- #3077: PityService's word on a pity cat at nightfall
local debugNextCoat: string? = nil -- Studio's debug hook: the coat the next stray spawned by a wave or refill gets
local lastRainbowToastAt: number? = nil -- os.clock() of this server's last rainbow stray toast (F99)
-- RescueService's answer to "is this player in a rescue attempt?", so a catch cannot start during one.
local inRescue: (Player) -> boolean = function(_player: Player): boolean
	return false
end
-- #4128 follow-up: the words a refusal uses while that check is true ("Finish the Rummage Bin first" on the bin's bar)
local rescueText: (Player) -> string = function(_player: Player): string
	return "Finish this rescue first"
end

local MAX_CIRCLES = Circles.maxCircles() -- #1884: the most circles any schedule holds; bounds the CatchPress index

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

-- F84: true while the player's character is in a Cat Cannon flight or a cloud hop (CannonService, TravelService set
-- these): no catch, pick up, rescue or tackle starts, and tackles pass through them.
local function inFlight(player: Player): boolean
	local character = player.Character
	return character ~= nil
		and (
			character:GetAttribute("Launching") == true
			or character:GetAttribute("CloudHopAt") ~= nil
		)
end

-- F84: the camp the player stands in (its area id), or nil. Nobody catches, picks up, rescues or tackles in a camp.
local function campOf(player: Player): string?
	local root = rootPosition(player)
	return if root ~= nil then Layout.campAt(root.X, root.Z) else nil
end

-- True while the player's character stands on the Town Square (Derek 2026-11-03: "character in town square should
-- put net away"). No strays roam it, so the net is away there as it is while a cat is in the arms.
local function inTownSquare(player: Player): boolean
	local root = rootPosition(player)
	return root ~= nil and Layout.inTownSquare(root.X, root.Z)
end

-- Whether the net is away for this player (Derek 2026-11-04, #1080: "the net should only come out inside a catching
-- area"): it shows only while the character stands in a catching area (WorldBuilder.areaAt) outside its camp, where
-- nobody catches. Everywhere else it is away: a cafe, the Town Square, the street, a warp or cannon arrival, and with
-- no character root. markCamps keeps NetHidden in step with this ten times a second; a carry hides it too.
local function netAway(player: Player): boolean
	local root = rootPosition(player)
	if root == nil then
		return true
	end
	return WorldBuilder.areaAt(world, root) == nil or campOf(player) ~= nil
end

-- F84 (section 4): a drop spot in a camp or at its edge moves out into the wild part (Layout.outOfCamp), then onto
-- that area's roam floor, since straight out from the Alleyway camp's middle can meet the building backs (N279).
local function outOfCamp(position: Vector3): Vector3
	local x, z, campId = Layout.outOfCamp(position.X, position.Z)
	local out = Vector3.new(x, position.Y, z)
	local area = if campId ~= nil then world.areas[campId] else nil
	return if area ~= nil then WorldBuilder.clampToArea(area, out, 2) else out
end

-- #2692: whether the areas are open for this player: by the clock, or by the night pass of a beginner who has not
-- checked in a first cat (shared/NightPass). #3035: or of a Tier 1 player in their first session, while the
-- nightCatch switch is on.
local function openFor(profile: Types.PlayerProfile?): boolean
	return NightPass.open(
		ClockService.areasOpen(),
		profile ~= nil and NightPass.of(profile, LiveFlagService.on(NightPass.FLAG))
	)
end

local function areaUnlocked(profile: Types.PlayerProfile, areaId: string): boolean
	local area = Catalog.getArea(areaId)
	if area == nil then
		return false
	end
	return Economy.tier(profile) >= area.tier
end

-- #3897: a rare cat's spawn banner goes only to the players who have its area open, never to the whole server.
local function announceToArea(areaId: string, text: string, rarity: Types.Rarity)
	local area = Catalog.getArea(areaId)
	for _, player in Players:GetPlayers() do
		local profile = DataService.get(player)
		if
			profile ~= nil
			and Catching.hearsSpawn(Economy.tier(profile), if area ~= nil then area.tier else nil)
		then
			Net.fire(player, "Announce", text, rarity)
		end
	end
end

-- The gold luck a stray or a rescue trap in the area rolls with (F54, golden-fish.md section 5): the highest among
-- the players in the server whose tier has the area open, a running Gold Rush Potion included (F73), 0 when nobody
-- has. The coat shows from the spawn, the
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
	local luck, from = IndexRewards.luckiest(profiles, area.tier, Economy.tier, os.time())
	return luck, if from ~= nil then players[from] else nil
end

-- The rainbow luck a stray or a rescue trap in the area rolls with (F99, rainbow-coat.md section 1): the highest
-- Index rainbow luck among the players in the server whose tier has the area open, 0 when nobody has. No potion
-- adds to it.
function CatService.rainbowLuckFor(areaId: string): number
	local area = Catalog.getArea(areaId)
	if area == nil then
		return 0
	end
	local profiles: { Types.PlayerProfile } = {}
	for _, player in DataService.loadedPlayers() do
		local profile = DataService.get(player)
		if profile ~= nil then
			table.insert(profiles, profile)
		end
	end
	return IndexRewards.bestRainbowLuck(profiles, area.tier, Economy.tier)
end

-- The coat a stray of `def` spawning in the area gets (F99): one roll, rainbow first and then gold
-- (Catching.rollCoat), each with the best luck in the server for the area.
local function rollStrayCoat(def: Types.CatDef, areaId: string): string
	local kinds = ClockService.dayKinds() -- #1572: a Golden or Rainbow Day lifts both chances until night
	return Catching.rollCoat(
		def,
		rng:NextNumber(),
		IndexRewards.rainbowChance(
			Clock.rainbowChance(Config.RainbowChanceNet, kinds),
			CatService.rainbowLuckFor(areaId)
		),
		IndexRewards.rollChance(
			Clock.goldChance(Config.GoldChanceNet, kinds),
			CatService.goldLuckFor(areaId)
		)
	)
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

-- True while the player's catch circles are running (below).
local holdsCatch: (Player) -> boolean

-- Sets a character's walk speed: `base` (normal, carry or Catch Rush) plus a running Swift Potion's
-- SwiftPotionSpeed (F64). #2052 (Derek2: walking off mid catch left the net on the ground): while the player's catch
-- circles run they stand still, with no walk and no jump, until the catch ends, fails or is dropped.
-- #3063: the Swift Paws perk's walk speed for `player` (0 while its switch is off). Only the normal walk and a carry
-- add it, never the catch rush or a Startled slow.
local function pawsBonus(player: Player): number
	local profile = DataService.get(player)
	-- #3871: plus the working cats' speed traits (Quick Paws and the combos that hold it), the best one only
	local traits = if profile ~= nil then Economy.traitBonus(profile, "speed") else 0
	return SwiftPaws.bonus(profile, LiveFlagService.on(SwiftPaws.FLAG)) + traits
end

-- #3535: the carry walk speed: CarryWalkSpeed with Swift Paws and, with the Speed Shoes owned and their switch on,
-- the shoes' bonus, which stops one short of the player's own walk speed with no cat (shared/SpeedShoes.carry).
-- Never on the catch rush or a Startled slow.
local function carrySpeed(player: Player): number
	local paws = pawsBonus(player)
	return SpeedShoes.carry(
		Config.CarryWalkSpeed + paws,
		Config.NormalWalkSpeed + paws,
		DataService.get(player),
		LiveFlagService.on(SpeedShoes.FLAG)
	)
end

local function setSpeed(player: Player, humanoid: Humanoid, base: number)
	local profile = DataService.get(player)
	local still = holdsCatch(player)
	humanoid.WalkSpeed = if still
		then 0
		else base + (if profile ~= nil then Potions.speedBonus(profile, os.time()) else 0)
	humanoid.JumpPower = if still then 0 else StarterPlayer.CharacterJumpPower
	humanoid.JumpHeight = if still then 0 else StarterPlayer.CharacterJumpHeight
end

-- #2052: sets the walk speed again for the player `userId` (0 for nobody), as a catch starts or ends.
local function refreshSpeedOf(userId: number)
	local player = if userId ~= 0 then Players:GetPlayerByUserId(userId) else nil
	if player ~= nil then
		CatService.refreshSpeed(player)
	end
end

-- Locks a stray to a player until `untilTime` (server time), or unlocks it (userId 0), dropping any attempt.
-- #2005: `NetDown` is true on the stray while it is locked, the net over it on every screen (with the "!"): the cat
-- stands still under it (its walk stops at once, set down off its bob by Mover), other swings pass it by and its
-- catcher can't be tackled (inMinigame) until the catch ends, fails or is dropped.
local function setLock(stray: Stray, userId: number, untilTime: number?)
	local before = stray.lockedBy
	stray.lockedBy = userId
	stray.lockUntil = if userId ~= 0 then untilTime or 0 else 0
	if userId == 0 then
		stray.attempt = nil
	end
	stray.model:SetAttribute("LockedBy", userId)
	stray.model:SetAttribute("NetDown", if userId ~= 0 then true else nil)
	if userId ~= 0 and stray.model:GetAttribute("Napping") == true then
		stray.model:SetAttribute("Napping", false) -- a catch wakes a napping stray at once
	end
	if before ~= userId then
		refreshSpeedOf(before) -- #2052: the catcher can walk again
	end
end

local function lockExpired(stray: Stray): boolean
	return serverNow() > stray.lockUntil
end

-- A stray's body for the path check (Model-Agent, 2026-10-28): 1.6 wide, 1.2 tall and 1.6 long, its bottom
-- 0.35 above the floor it walks on, so the floor and the paw paths are never hit but a step, a root or a fence is.
local PATH_BOX = Vector3.new(1.6, 1.2, 1.6)
local PATH_BOX_LIFT = 0.35 + PATH_BOX.Y / 2
local PATH_STOP_SHORT = 0.2

-- What a stray's casts pass through: the cats themselves and every character.
local function catsAndCharacters(): { Instance }
	local ignore: { Instance } = { straysFolder }
	for _, player in Players:GetPlayers() do
		if player.Character ~= nil then
			table.insert(ignore, player.Character :: Model)
		end
	end
	return ignore
end

-- Where a stray walking from `from` to `to` (on to's floor) stops: at `to`, or just short of the first thing its
-- body would touch (reviewer N84). Characters and the cats themselves never stop it. Any part a player can see stops it, solid or not (Derek 2026-10-28 01:30: cats clipped through
-- the area sets' fences, benches and stalls, half of which do not collide), so the cast ignores CanCollide and
-- passes only through parts nobody can see.
local function clearPath(from: Vector3, to: Vector3): Vector3
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if flat.Magnitude < 0.1 then
		return to
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = false
	local ignore = catsAndCharacters()
	local origin = Vector3.new(from.X, to.Y + PATH_BOX_LIFT, from.Z)
	local box = CFrame.lookAt(origin, origin + flat)
	for _ = 1, 4 do
		params.FilterDescendantsInstances = ignore
		local hit = Workspace:Blockcast(box, PATH_BOX, flat, params)
		if hit == nil then
			return to
		end
		local part = hit.Instance
		if
			hit.Distance < 0.05
			or (part:IsA("BasePart") and part.Transparency >= 1 and not part.CanCollide)
		then
			-- an invisible marker or zone, or a part the cat already stands in (the #433 review's playtest note): a
			-- stray against a decoration must still be able to walk away from it
			table.insert(ignore, part)
			continue
		end
		local reach = math.max(0, hit.Distance - PATH_STOP_SHORT)
		return Vector3.new(from.X, to.Y, from.Z) + flat.Unit * reach
	end
	return Vector3.new(from.X, to.Y, from.Z) -- too many invisible parts in the way: stay put
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
	if stray.def.rarity == Catalog.SECRET then
		SecretBeacons.clear(stray.id)
		-- #3470: gone with nobody holding it (dusk, or a Dropped one nobody picked up)
		local someone: Player? = if catcher == nil then DataService.loadedPlayers()[1] else nil
		if someone ~= nil then
			Telemetry.custom(
				someone,
				"secret_lost",
				1,
				{ stray.area, if drop ~= nil then "tackle" else "despawn" }
			)
		end
	end
	refreshSpeedOf(stray.lockedBy) -- #2052: a cat gone mid catch (night, another server's pity claim) frees its catcher
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

-- How far above its area's walking floor a stray's home is a perch it does not wander from: the Sewer trolley spot is
-- 0.6 up, the Neighbourhood tyre, bins and van 0.24 to 0.32 (reviewer N224).
local PERCH_ABOVE = 0.5

local function wander(stray: Stray)
	local area = world.areas[stray.area]
	-- #3545: a Secret roams fast and far and never settles for a nap
	local secret = stray.def.rarity == Catalog.SECRET
	local speed = if secret then Config.SecretWanderSpeed else Config.StrayWanderSpeed
	local radius = if secret then Config.SecretWanderRadius else Config.StrayWanderRadius
	local pause = if secret then Config.SecretWanderPauseScale else 1
	if stray.mood == "Sleepy" and not secret then
		stray.model:SetAttribute("Napping", true) -- #1884 (7a): curled up from the start
	end
	while stray.alive do
		task.wait(rng:NextNumber(3, 7) * pause)
		if not canWander(stray) then
			continue
		end
		if stray.mood == "Sleepy" and not secret then
			-- #1884 (7a): a Sleepy cat never wanders; a swing wakes it (setLock) and it curls up again after
			if stray.model:GetAttribute("Napping") ~= true then
				stray.model:SetAttribute("Napping", true)
			end
			continue
		end
		if not secret and rng:NextNumber() < NAP_CHANCE and not nap(stray) then
			continue
		end
		-- A stray spawned up on a porch, a rock or the Sewer's catwalk (the area sets' cat spots) stays there until a
		-- miss sends it running to the floor; on the floor it walks no further than the first solid thing in the way.
		if stray.home.Y > area.floorY + PERCH_ABOVE then
			continue
		end
		local at = stray.model:GetPivot().Position
		local target = WorldBuilder.clampToArea(
			area,
			stray.home
				+ Vector3.new(rng:NextNumber(-radius, radius), 0, rng:NextNumber(-radius, radius)),
			2,
			at
		)
		stray.walk += 1
		local walk = stray.walk
		Mover.walkTo(stray.model, clearPath(at, target), speed, function()
			return stray.alive and stray.lockedBy == 0 and stray.walk == walk
		end)
	end
end

local function spawnStray(
	def: Types.CatDef,
	areaId: string,
	position: Vector3,
	pointIndex: number?,
	lifetime: number?, -- nil: stays until the next dusk clears it
	forceCoat: string?, -- "gold" or "rainbow": Studio's debug hook, or a Cafe Event shower's rainbow (#2486)
	kept: Kept?, -- a Dropped cat keeps its charm, coat and rescued flag
	beginner: number? -- F87: the tutorial stray's beginner
): Stray
	if kept == nil and forceCoat == nil and debugNextCoat ~= nil then
		forceCoat, debugNextCoat = debugNextCoat, nil
	end
	local variant = if kept ~= nil
		then kept.variant or "base"
		elseif forceCoat ~= nil then forceCoat
		else rollStrayCoat(def, areaId)
	nextStrayNumber += 1
	local id = string.format("stray_%d_%d", os.time() % 100000, nextStrayNumber)
	local model = AssetRegistry.cloneCat(def.id, variant)
	model.Name = id
	-- #3843: a stray never wears an outfit (CatDress only dresses fresh clones from Assets), so its 13 to 17 empty
	-- Outfit_ slots go before it is parented, 15 to 20 percent fewer instances sent to each client
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Attachment") and string.sub(descendant.Name, 1, 7) == "Outfit_" then
			descendant:Destroy()
		end
	end
	local body = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart") :: BasePart
	model:SetAttribute("StrayId", id)
	model:SetAttribute("CatId", def.id)
	-- #3470: a Secret stray nobody has caught yet keeps its name to itself (a Dropped one was caught once)
	model:SetAttribute(
		"CatName",
		if def.rarity == Catalog.SECRET and kept == nil then Catching.SECRET_NAME else def.name
	)
	model:SetAttribute("Rarity", def.rarity)
	model:SetAttribute("Area", areaId)
	model:SetAttribute("LockedBy", 0)
	model:SetAttribute("Beginner", beginner or 0) -- F87: other clients leave a beginner's stray alone
	model:SetAttribute(SecondCat.ATTRIBUTE, 0) -- #3022: set while it waits for a player's second catch
	model:SetAttribute("SpawnedAt", os.time())
	model:SetAttribute("FleeingUntil", 0) -- v0.5: server time a missed stray stops running (display only)
	-- A net stray's gold is no secret (data-model section 4): the sparkle and the catch header show it. Its Variant
	-- ("base", "gold" or "rainbow", F99) draws the rainbow coat on every client.
	model:SetAttribute("Gold", variant == "gold")
	model:SetAttribute("Variant", variant)
	-- Display only (section 13); the drop record itself stays in the server's table below (S25, N29). A Dropped
	-- stray is picked up by the first swing that lands on it, with no circles (v0.8 F56, F93).
	model:SetAttribute("Dropped", kept ~= nil)
	model:SetAttribute("PickUp", kept ~= nil)
	model:SetAttribute("Returning", kept ~= nil and kept.returning == true) -- F67: walking home
	-- #1884 (catch-rework.md 7a): the tutorial stray is always Sleepy
	local mood: Types.CatMood = Moods.roll(def.rarity, rng:NextNumber(), beginner ~= nil)
	model:SetAttribute("Mood", mood)
	CollectionService:AddTag(model, "Stray")
	-- F93 (catch-rework.md section 1): no Catch prompt; the net swing finds the stray (SwingNet).

	model:PivotTo(CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- a cat streams in whole (reviewer S37)
	model.Parent = straysFolder

	local stray: Stray = {
		id = id,
		def = def,
		area = areaId,
		model = model,
		body = body,
		spawnedAt = os.clock(),
		pointIndex = pointIndex,
		home = position,
		lockedBy = 0,
		lockUntil = 0,
		attempt = nil,
		fleeingUntil = 0,
		selfRetryAt = {},
		missStreak = {},
		jumping = false,
		charm = if kept ~= nil and kept.charm ~= nil
			then kept.charm
			else CatStats.rollCharm(rng:NextNumber(), rng:NextNumber()),
		variant = variant,
		method = if kept ~= nil then kept.method else "net",
		drop = if kept ~= nil then kept.drop else nil,
		homePos = if kept ~= nil then kept.homePos else nil,
		returning = kept ~= nil and kept.returning == true,
		knocks = if kept ~= nil then kept.knocks or 0 else 0,
		pity = kept ~= nil and kept.pity == true,
		recaught = false,
		beginner = beginner,
		mood = mood,
		walk = 0,
		alive = true,
	}
	strays[id] = stray
	if def.rarity == Catalog.SECRET then
		-- #3470: its sky beam shows from anywhere (Effects)
		SecretBeacons.set(id, areaId, position)
		SecretBeacons.follow(id, model)
	end
	if pointIndex ~= nil then
		occupiedPoints[areaId] = occupiedPoints[areaId] or {}
		occupiedPoints[areaId][pointIndex] = id
	end
	-- F99 (rainbow-coat.md section 2): every client raises the beam over a new rainbow stray; the server's toast goes
	-- out at most once every RainbowSpawnToastSeconds. A Dropped one is not new.
	if variant == "rainbow" and kept == nil then
		local clock = os.clock()
		local toast = lastRainbowToastAt == nil
			or clock - (lastRainbowToastAt :: number) >= Config.RainbowSpawnToastSeconds
		if toast then
			lastRainbowToastAt = clock
		end
		Net.fireAll("RainbowSpawned", areaId, def.id, id, toast)
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

-- A free spawn point in the area, spread from the strays already there (Catching.spreadPick), or nil. Which points a
-- stray of `rarity` may take is Catching.spawnPool's rule: the Woods' oak top for a Rare or better first, Epic and
-- rarer only in a nook, never in a back alley lane (F35, v3.1), Mythicals only deep (F81; #2210: Epic and Legendary
-- anywhere in a side area). The Alleyway's `near`
-- points by its camp are the tutorial stray's alone (v4, F84, data-model section 9 v0.13.18), never free here.
local TUTORIAL_AREA, TUTORIAL_ZONE = "alley", "near"
local NEAR_STRAY_STUDS = 12 -- F87: funnel step near_stray, this close to the own tutorial stray
local IN_VIEW_STUDS = 40 -- #1273: funnel step first_stray_in_view, this close to it
local CARRY_STEP_SECONDS = 10 -- #1273: carrying_first_cat, the first cat still held this long after its catch
-- #1621: the area's gate on the ground plane (Layout.gatePosition), nil for the Alleyway, which has none.
local function gateOf(areaId: string): (number?, number?)
	local spec = Layout.areas[areaId]
	if spec == nil then
		return nil, nil
	end
	return Layout.gatePosition(spec)
end

-- #1621: how many live strays stand near the area's gate, and how many in all (0, live for an area with no gate).
local function nearGateCount(areaId: string): (number, number)
	local gateX, gateZ = gateOf(areaId)
	local near, live = 0, 0
	for _, stray in strays do
		if stray.alive and stray.area == areaId then
			live += 1
			if gateX ~= nil and gateZ ~= nil then
				local at = stray.model:GetPivot().Position
				near += if StrayTopUp.nearGate(at.X, at.Z, gateX, gateZ) then 1 else 0
			end
		end
	end
	return near, live
end

local function freeSpawnPoint(
	areaId: string,
	rarity: Types.Rarity?,
	far: boolean?,
	entry: boolean?
): number?
	local area = world.areas[areaId]
	local occupied = occupiedPoints[areaId] or {}
	local slots: { Catching.SpawnSlot } = {}
	local zones: { string? } = {}
	for i, point in area.spawnPoints do
		local zone = point:GetAttribute("Zone")
		local tutorialOnly = areaId == TUTORIAL_AREA and zone == TUTORIAL_ZONE
		zones[i] = if type(zone) == "string" then zone else nil
		table.insert(slots, {
			zone = zones[i],
			free = occupied[i] == nil and not tutorialOnly,
		})
	end
	local pool = Catching.spawnPool(slots, rarity)
	if far then
		pool = StrayTopUp.farPool(pool, zones) -- #1159: a top-up fills the back of the area first
	end
	local gateX, gateZ = gateOf(areaId)
	if entry and gateX ~= nil and gateZ ~= nil then
		-- #1621: the start of the area by its gate
		local near: { [number]: boolean } = {}
		for _, index in pool do
			local at = area.spawnPoints[index].Position
			near[index] = StrayTopUp.nearGate(at.X, at.Z, gateX, gateZ)
		end
		pool = StrayTopUp.entryPool(pool, near)
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

-- #3470: a wild Secret stray is out. The players with its area open (#3897) get the banner and chat line with its
-- area's name, and
-- it is logged as `secret_spawn` (a server event with no player of its own: under the first player here).
local function secretSpawned(stray: Stray)
	local areaDef = Catalog.getArea(stray.area)
	local text = Catching.waveShoutOut(
		stray.def.rarity,
		stray.variant,
		if areaDef ~= nil then areaDef.name else stray.area
	)
	if text ~= nil then
		announceToArea(stray.area, text, stray.def.rarity)
	end
	local someone: Player? = DataService.loadedPlayers()[1]
	if someone ~= nil then
		Telemetry.custom(someone, "secret_spawn", 1, { stray.area, "wild" })
	end
end

local function spawnAt(
	areaId: string,
	pointIndex: number,
	rarity: Types.Rarity,
	beginner: number?
): Stray
	local area = world.areas[areaId]
	-- #3470: a rolled Mythical turns Secret 1 time in 100 while the `secretCats` switch is on (never a beginner's
	-- stray). It takes the Mythical's point, and everyone hears the area and never the spot.
	-- (review note on #3486: the two draws are made only for a Mythical with the switch on, so a switched off build
	-- rolls exactly as before)
	local secret = if beginner == nil
			and rarity == "Mythical"
			and LiveFlagService.on(Catching.SECRET_FLAG)
		then Catching.secret(rarity, rng:NextNumber(), rng:NextNumber(), true)
		else nil
	local def = secret or Catching.pickCat(rarity, areaId, rng:NextNumber())
	local point = area.spawnPoints[pointIndex]
	local stray = spawnStray(def, areaId, point.Position, pointIndex, nil, nil, nil, beginner)
	if secret ~= nil then
		secretSpawned(stray)
	end
	return stray
end

-- The Alleyway's spawn point indices with zone `near`, in order: plot p owns the p-th (v4, F84).
local function tutorialPoints(): { number }
	local area = world.areas[TUTORIAL_AREA]
	local list: { number } = {}
	if area ~= nil then
		for i, point in area.spawnPoints do
			if point:GetAttribute("Zone") == TUTORIAL_ZONE then
				table.insert(list, i)
			end
		end
	end
	return list
end

-- F87: gives a tutorial stray to `userId`, or frees it (nil), along with its Beginner attribute.
local function reserve(stray: Stray, userId: number?)
	stray.beginner = userId
	stray.model:SetAttribute("Beginner", userId or 0)
end

-- A beginner always finds a Common stray waiting just past the Alleyway camp's way out, at their plot's own `near`
-- point (v4, F84, data-model section 9 v0.13.18: plot p owns near point p), where the intro shows it. Since F87
-- (easy-start.md section 2b) it is theirs until their first check-in (#3181: no longer theirs alone; anyone may
-- catch it, and the next tick, or the catch itself, puts a new one at the point): one that waits at their point for
-- someone who left the plot is handed over, and one whose beginner left or checked in a cat is freed.
-- #2692: nothing else spawns at night (v0.9, F66), but a beginner holds the night pass, so their stray comes at night
-- too, and one whose beginner has gone or checked in leaves at once by night instead of waiting for the sunrise.
local function tutorialTick()
	local night = not ClockService.areasOpen()
	local nightCatch = LiveFlagService.on(NightPass.FLAG)
	for _, player in DataService.loadedPlayers() do
		local profile = DataService.get(player)
		if profile ~= nil then
			local pass = NightPass.of(profile, nightCatch)
			if player:GetAttribute(NightPass.ATTRIBUTE) ~= pass then
				player:SetAttribute(NightPass.ATTRIBUTE, pass)
			end
		end
	end
	local occupied = occupiedPoints[TUTORIAL_AREA] or {}
	local near = tutorialPoints()
	local beginners: { [number]: boolean } = {}
	local nightHolders: { [number]: boolean } = {}
	for _, player in DataService.loadedPlayers() do
		local profile = DataService.get(player)
		local plot = PlotService.get(player)
		if profile == nil or plot == nil then
			continue
		end
		if profile.tutorialStep >= Config.TutorialGuaranteedStrayStep then
			-- #3035: at night a first-session Tier 1 player with the pass finds one Common at their own point too,
			-- a new one within a tick of the last being caught. Not reserved and no easy catch: the Beginner
			-- attribute would give them the tutorial's "Try again!" and swing help on the client.
			-- #3659: and so does a Tier 1 player who has not caught a cat by hand yet, in any session
			if night and NightPass.nightCatOf(profile, nightCatch) then
				nightHolders[player.UserId] = true
				local point = near[plot.index]
				if point ~= nil and occupied[point] == nil then
					spawnAt(TUTORIAL_AREA, point, "Common").nightFor = player.UserId
				end
			end
			continue
		end
		beginners[player.UserId] = true
		local own = near[plot.index]
		if own == nil then
			continue
		end
		local strayId = occupied[own]
		local stray = if strayId ~= nil then strays[strayId] else nil
		if stray ~= nil and stray.alive and stray.def.rarity == "Common" then
			-- never a Dropped cat or one walking home, which belongs to whoever picks it up (review N302)
			if
				stray.beginner ~= player.UserId
				and stray.drop == nil
				and not stray.returning
				and (stray.lockedBy == 0 or lockExpired(stray))
			then
				reserve(stray, player.UserId)
			end
			-- funnel steps first_stray_in_view and near_stray (easy-start.md section 5)
			if not Onboarding.reached(profile.telemetry, "near_stray") then
				if withinRange(player, stray.body.Position, NEAR_STRAY_STUDS) then
					Telemetry.onboarding(player, profile, "near_stray")
				elseif
					not Onboarding.reached(profile.telemetry, "first_stray_in_view")
					and withinRange(player, stray.body.Position, IN_VIEW_STUDS)
				then
					Telemetry.onboarding(player, profile, "first_stray_in_view")
				end
			end
		elseif strayId == nil then
			spawnAt(TUTORIAL_AREA, own, "Common", player.UserId)
		end
	end
	local leaving: { Stray } = {}
	for _, stray in strays do
		local beginner = stray.beginner
		if beginner ~= nil and not beginners[beginner] then
			reserve(stray, nil)
			if night then
				table.insert(leaving, stray)
			end
		end
		-- #3035: a night stray whose player's pass ended (rank up, left, the switch off) goes by night; by day it stays
		local nightFor = stray.nightFor
		if nightFor ~= nil then
			if not night then
				stray.nightFor = nil
			elseif not nightHolders[nightFor] and stray.beginner == nil then
				stray.nightFor = nil
				table.insert(leaving, stray)
			end
		end
	end
	for _, stray in leaving do
		if stray.drop == nil and (stray.lockedBy == 0 or lockExpired(stray)) then
			despawn(stray)
		end
	end
end

-- #3022 (shared/SecondCat; Derek2 2026-11-10: "A lot of people stop before catching second cat"): from a player's
-- first customer served until their second cat is checked in, a stray waits for them near the Alleyway camp's
-- landing. The free stray nearest the landing within SecondCat.SEARCH_STUDS is theirs: it turns Curious, so it walks
-- up to them, and its home moves in until its wander keeps within SecondCat.LEASH_STUDS. When none is that near, a
-- Common arrives at a free `near` point (the player's own plot's first). It is not reserved: someone else may catch
-- it, and the next tick picks another. A player carrying a cat, the night and a stray that was caught, dropped or
-- sent running all let it go. The three step_time events are logged here, once a session each.
-- One table (Second.step, tick, served, forget), as the module is short of locals.
local Second = {}
do
	local secondSteps: { [Player]: { [string]: boolean } } = {}

	function Second.step(player: Player, profile: Types.PlayerProfile, name: string)
		local seen = secondSteps[player]
		if seen == nil then
			seen = {}
			secondSteps[player] = seen
		end
		if not seen[name] then
			seen[name] = true
			Telemetry.stepTime(player, profile, name)
		end
	end

	local function secondPad(): Vector3?
		local pad = Layout.landingPads[SecondCat.AREA]
		if pad == nil then
			return nil
		end
		return Vector3.new(pad.centre.x, pad.centre.y, pad.centre.z)
	end

	-- Gives the stray to `userId` to wait for, or lets it go (nil).
	local function waitFor(stray: Stray, userId: number?, pad: Vector3?)
		stray.waitsFor = userId
		stray.model:SetAttribute(SecondCat.ATTRIBUTE, userId or 0)
		if userId == nil or pad == nil then
			return
		end
		stray.home = SecondCat.leash(stray.home, pad, Config.StrayWanderRadius)
		if stray.mood ~= "Curious" or stray.curiousAt ~= nil then
			stray.mood = "Curious"
			stray.curiousAt = nil
			stray.model:SetAttribute("Mood", "Curious")
			stray.model:SetAttribute("CuriousAt", nil)
		end
		stray.model:SetAttribute("Napping", false) -- a Sleepy one gets up
	end

	-- Whether the stray can be the one that waits: on the Alleyway's floor, nobody's catch, tutorial stray or waiting
	-- stray, not Dropped, walking home or running, and a plain Rare or below (SecondCat.fits).
	local function canWait(stray: Stray, now: number): boolean
		if not stray.alive or stray.area ~= SecondCat.AREA then
			return false
		end
		if not SecondCat.fits(stray.def.rarity, stray.variant) then
			return false
		end
		if
			stray.beginner ~= nil
			or stray.waitsFor ~= nil
			or stray.drop ~= nil
			or stray.returning
		then
			return false
		end
		if (stray.lockedBy ~= 0 and not lockExpired(stray)) or stray.jumping then
			return false
		end
		if now < stray.fleeingUntil then
			return false
		end
		local area = world.areas[stray.area]
		return area ~= nil and stray.home.Y <= area.floorY + PERCH_ABOVE
	end

	-- The stray that will wait for `player`: the nearest free one to the landing, else a Common brought to a `near` point.
	local function pickWaiting(player: Player, pad: Vector3, now: number): Stray?
		local best: Stray? = nil
		local bestDistance = math.huge
		for _, stray in strays do
			if canWait(stray, now) then
				local at = stray.body.Position
				if SecondCat.inSearch(at, pad) then
					local distance = (Vector3.new(at.X, pad.Y, at.Z) - pad).Magnitude
					if distance < bestDistance then
						best, bestDistance = stray, distance
					end
				end
			end
		end
		if best ~= nil then
			return best
		end
		local area = world.areas[TUTORIAL_AREA]
		if area == nil then
			return nil
		end
		local occupied = occupiedPoints[TUTORIAL_AREA] or {}
		local near = tutorialPoints()
		local plot = PlotService.get(player)
		local own = if plot ~= nil then near[plot.index] else nil
		local pick: number? = nil
		if own ~= nil and occupied[own] == nil then
			pick = own
		else
			local pickDistance = math.huge
			for _, index in near do
				if occupied[index] == nil then
					local distance = (area.spawnPoints[index].Position - pad).Magnitude
					if distance < pickDistance then
						pick, pickDistance = index, distance
					end
				end
			end
		end
		if pick == nil then
			return nil -- every near point is taken (by tutorial strays): the next tick looks again
		end
		return spawnAt(TUTORIAL_AREA, pick, "Common")
	end

	-- One player's part of the rule; `stray` is the one already waiting for them, if any.
	local function secondCatFor(
		player: Player,
		profile: Types.PlayerProfile,
		stray: Stray?,
		pad: Vector3
	)
		local waiting: Stray
		if stray ~= nil then
			waiting = stray
		else
			local picked = pickWaiting(player, pad, serverNow())
			if picked == nil then
				return
			end
			waitFor(picked, player.UserId, pad)
			waiting = picked
		end
		Second.step(player, profile, SecondCat.SHOWN)
		local root = rootPosition(player)
		if root ~= nil and SecondCat.followed(root, waiting.body.Position) then
			Second.step(player, profile, SecondCat.FOLLOWED)
		end
	end

	-- Whether the rule runs for the player now: their save waits for its second cat, the areas are open and their hands
	-- and Backpack are empty.
	local function secondCatDue(player: Player): Types.PlayerProfile?
		local profile = DataService.get(player)
		if
			profile == nil
			or not SecondCat.waiting(profile)
			or carrying[player] ~= nil
			or packed[player] ~= nil
			or not ClockService.areasOpen()
		then
			return nil
		end
		return profile
	end

	function Second.tick()
		local pad = secondPad()
		if pad == nil then
			return
		end
		local due: { [number]: { player: Player, profile: Types.PlayerProfile } } = {}
		for _, player in DataService.loadedPlayers() do
			local profile = secondCatDue(player)
			if profile ~= nil then
				due[player.UserId] = { player = player, profile = profile }
			end
		end
		local has: { [number]: Stray } = {}
		for _, stray in strays do
			local who = stray.waitsFor
			if who == nil then
				continue
			end
			if
				due[who] == nil
				or has[who] ~= nil
				or not stray.alive
				or stray.drop ~= nil
				or stray.returning
			then
				waitFor(stray, nil)
			else
				has[who] = stray
			end
		end
		for userId, entry in due do
			secondCatFor(entry.player, entry.profile, has[userId], pad)
		end
	end

	-- The first customer was just served: the stray waits from now, not the next tick.
	function Second.served(player: Player)
		local pad = secondPad()
		local profile = secondCatDue(player)
		if pad == nil or profile == nil then
			return
		end
		local mine: Stray? = nil
		for _, stray in strays do
			if stray.waitsFor == player.UserId and stray.alive then
				mine = stray
				break
			end
		end
		secondCatFor(player, profile, mine, pad)
	end

	function Second.forget(player: Player)
		secondSteps[player] = nil
	end
end

-- Sunrise (data-model section 9, v0.9): a full wave arrives. Dusk already cleared the area, so this only
-- fills free points; a cat let go during night is still there and keeps its point. On a Lucky Day (F88) the wave
-- rolls at LuckyDayWaveLuck; nobody's own Luck touches it.
-- #3661 (Review-QA's Studio reading: one sunrise sent every client about 1.3 MB in a single burst, some 80 cat
-- models at once, and everything else the server had to say queued behind it): the wave is rolled at once but
-- placed over time. rollWave returns the area's strays to place, rarest first, and whether a Mythical is among
-- them; sunriseWave places the first few of each area at once and the rest a few a second.
type WavePlace = {
	areaDef: Types.AreaDef,
	rarity: Types.Rarity,
	place: number,
	count: number,
	lucky: boolean,
}

local function rollWave(areaDef: Types.AreaDef, luck: number): ({ WavePlace }, boolean)
	-- Roll the whole wave, then place the rarest first so Epic and rarer always find a Square point.
	local odds = Luck.apply(areaDef.odds, luck)
	local rarities: { Types.Rarity } = {}
	for _ = 1, areaDef.waveSize do
		table.insert(rarities, Catching.pickRarity(odds, rng:NextNumber()))
	end
	-- F97 section 7: every wave has an Epic or rarer stray
	local rerolled = Catching.waveRare(rarities, rng:NextNumber())
	if rerolled ~= nil then
		-- a server event with no player of its own: logged under the first player here, none in an empty server
		local someone: Player? = DataService.loadedPlayers()[1]
		if someone ~= nil then
			Telemetry.custom(someone, "wave_rare", 1, { areaDef.id, rerolled })
		end
	end
	table.sort(rarities, function(a, b)
		return Catalog.rarityRank[a] > Catalog.rarityRank[b]
	end)
	local mythical = false
	local places: { WavePlace } = {}
	for place, rarity: Types.Rarity in rarities do
		mythical = mythical or rarity == "Mythical"
		table.insert(places, {
			areaDef = areaDef,
			rarity = rarity,
			place = place,
			count = #rarities,
			lucky = luck > 1,
		})
	end
	return places, mythical
end

local function placeWave(entry: WavePlace)
	-- (an annotated local: the CI type check widens the rarity read back from the record, or cast, to a string)
	local areaDef = entry.areaDef
	local rarity: Types.Rarity = entry.rarity :: any
	-- #1621: the commonest few land by the gate, so the start of the area is never bare at sunrise
	local point = freeSpawnPoint(
		areaDef.id,
		rarity,
		nil,
		StrayTopUp.waveEntry(entry.place, entry.count, areaDef.entryFloor)
	)
	if point ~= nil then
		local stray = spawnAt(areaDef.id, point, rarity)
		-- F58: the server hears of a wave's Mythical; since #3897 only the players with the area open (Derek:
		-- the rest were flooded with banners for places they can't go); a tutorial or bait Mythical is not a wave's
		-- #3470: one that turned Secret has had its own line (secretSpawned)
		local text = if stray.def.rarity == rarity
			then Catching.waveShoutOut(rarity, stray.variant, areaDef.name, entry.lucky)
			else nil
		if text ~= nil then
			announceToArea(stray.area, text :: string, rarity)
		end
	end
end

-- #3661: each sunrise has its own number, so a wave still being placed stops when the next dusk or sunrise comes
local waveNumber = 0

-- #1159 (shared/StrayTopUp): each area's seconds left until its next top-up, while it is under its floor.
local topUpLeft: { [string]: number } = {}
-- #1621: each gated area's seconds left until its next stray by the gate, while fewer than StrayEntryFloor stand there.
local entryLeft: { [string]: number } = {}

-- Every second, `dt` the time since the last: by day, each area with fewer live strays than its floor (by the players
-- who have it open) counts its timer down, and when it runs out one stray of the area's normal odds arrives at a far
-- free point. An area at its floor drops its timer, so the next shortfall draws a fresh one.
local function topUpTick(dt: number)
	if not ClockService.areasOpen() then
		table.clear(topUpLeft)
		table.clear(entryLeft)
		return
	end
	local open: { [string]: number } = {}
	for _, player in DataService.loadedPlayers() do
		local profile = DataService.get(player)
		if profile ~= nil then
			local tier = Economy.tier(profile)
			for _, areaDef in Catalog.areas do
				if tier >= areaDef.tier then
					open[areaDef.id] = (open[areaDef.id] or 0) + 1
				end
			end
		end
	end
	for _, areaDef in Catalog.areas do
		if world.areas[areaDef.id] == nil then
			continue
		end
		local nearGate, live = nearGateCount(areaDef.id)
		local gateX = gateOf(areaDef.id)
		if gateX ~= nil and StrayTopUp.entryShort(nearGate, live, areaDef.entryFloor) then
			-- #1621: the start of the area gets its own quicker top-up
			local wait = (entryLeft[areaDef.id] or Config.StrayEntryTopUpSeconds) - dt
			if wait <= 0 then
				local rarity: Types.Rarity = Catching.pickRarity(areaDef.odds, rng:NextNumber())
				local point = freeSpawnPoint(areaDef.id, rarity, nil, true)
				if point ~= nil then
					spawnAt(areaDef.id, point, rarity)
					live += 1
				end
				wait = Config.StrayEntryTopUpSeconds
			end
			entryLeft[areaDef.id] = wait
		else
			entryLeft[areaDef.id] = nil
		end
		if live >= StrayTopUp.floor(math.max(1, open[areaDef.id] or 0), areaDef.floorBase) then
			topUpLeft[areaDef.id] = nil
			continue
		end
		local left = (topUpLeft[areaDef.id] or StrayTopUp.wait(rng:NextNumber())) - dt
		if left <= 0 then
			local rarity: Types.Rarity = Catching.pickRarity(areaDef.odds, rng:NextNumber())
			local point = freeSpawnPoint(areaDef.id, rarity, true)
			if point ~= nil then
				spawnAt(areaDef.id, point, rarity)
			end
			left = StrayTopUp.wait(rng:NextNumber())
		end
		topUpLeft[areaDef.id] = left
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

-- The carrier's character attributes (section 13): CarryingCatId, CarryStartedAt (server time), BumpImmune (the
-- held window) and NetHidden (F93: the net is away while a cat is in the arms, on every client; also anywhere but a
-- catching area outside its camp, #1080, which markCamps keeps up to date). Display only; the shove checks read the carry record. nil clears them.
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
	character:SetAttribute("NetHidden", if carry ~= nil or netAway(player) then true else nil)
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
	model:SetAttribute("Variant", carry.variant or "base") -- F99: and a rescued rainbow its coat
	local body = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart") :: BasePart
	local nameTag = body:FindFirstChild("NameTag")
	if nameTag ~= nil then
		nameTag:Destroy()
	end
	HeldCat.attach(model, character, root) -- on the torso, curled up asleep, the same on every screen (#1964)
	model.Parent = character
	carry.model = model
	if humanoid ~= nil then
		setSpeed(player, humanoid, carrySpeed(player))
	end
	showCarry(player, carry)
end

-- "an Epic Maine Coon", "a Tabby": the article for the word that follows it.
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
		setSpeed(player, humanoid, Config.CatchRushWalkSpeed)
	end
	task.delay(Config.CatchRushSeconds, function()
		local current = player.Character
		local nowHumanoid = if current ~= nil
			then current:FindFirstChildOfClass("Humanoid") :: Humanoid?
			else nil
		if carrying[player] == carry and nowHumanoid ~= nil then
			setSpeed(player, nowHumanoid, carrySpeed(player))
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

-- #2565: whether the player owns the Backpack (Mystery Market).
local function hasBackpack(player: Player): boolean
	local profile = DataService.get(player)
	return profile ~= nil and profile.mystery.backpack == true
end

-- #3699: the worn Backpack in its owner's two colour picks (the built colours with the switch off or nothing picked).
-- The server colours the parts, so every player sees them.
local function tintBackpack(player: Player)
	local character = player.Character
	local pack = if character ~= nil then HeldCat.pack(character) else nil
	local profile = DataService.get(player)
	if pack == nil or profile == nil then
		return
	end
	BagColours.tint(
		pack,
		BagColours.picks(if LiveFlagService.on(BagColours.FLAG) then profile.bagColours else nil)
	)
end

-- #2719: the Backpack's owner wears it (HeldCat.wearPack), at spawn and after the buy; every player sees it.
local function wearBackpack(player: Player)
	local character = player.Character
	if
		character == nil
		or not hasBackpack(player)
		or HeldCat.pack(character) ~= nil
		or not AssetRegistry.has(HeldCat.PACK_ASSET)
	then
		return
	end
	local pack = AssetRegistry.clone(HeldCat.PACK_ASSET)
	if HeldCat.wearPack(pack, character) then
		pack.Parent = character
		tintBackpack(player) -- #3699
	else
		pack:Destroy()
	end
end

-- #4049: the worn Speed Shoes in their owner's two colour picks (the built colours with the switch off or nothing
-- picked). The server colours the parts, so every player sees them.
local function tintShoes(player: Player, worn: Instance?)
	local character = player.Character
	local folder = worn
		or (if character ~= nil then character:FindFirstChild(SpeedShoes.WORN) else nil)
	local profile = DataService.get(player)
	if folder == nil or profile == nil then
		return
	end
	BagColours.tint(
		folder,
		BagColours.picks(
			if LiveFlagService.on(BagColours.FLAG) then profile.shoeColours else nil,
			"shoes"
		),
		"shoes"
	)
end

-- #4050: the Speed Shoes' owner wears them (SpeedShoes.wear) while the switch is on, at spawn, after the buy and
-- whenever they came off (keepBackpack's check); every player sees them. Without them, or with the switch off, none.
local function keepShoes(player: Player)
	local character = player.Character
	if character == nil or character.Parent == nil then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return
	end
	local want = LiveFlagService.on(SpeedShoes.FLAG) and SpeedShoes.owns(DataService.get(player))
	local old = character:FindFirstChild(SpeedShoes.WORN)
	if old ~= nil and want and SpeedShoes.onFeet(old, character) then
		return
	end
	if old ~= nil then
		old:Destroy()
	end
	if want and AssetRegistry.has(SpeedShoes.ASSET) then
		local folder = SpeedShoes.wear(AssetRegistry.clone(SpeedShoes.ASSET), character)
		if folder ~= nil then
			tintShoes(player, folder) -- #4049
			folder.Parent = character
		end
	end
	local on = if want and character:FindFirstChild(SpeedShoes.WORN) ~= nil then true else nil
	if character:GetAttribute("SpeedShoes") ~= on then
		character:SetAttribute("SpeedShoes", on)
	end
end

-- #2565: the packed cat's model on the back, and the character attribute PackedCatId for the clients. #2719: in the
-- worn pack with only its head out.
local function attachPacked(player: Player, carry: Carry)
	local character = player.Character
	if character == nil then
		return
	end
	wearBackpack(player)
	if carry.model ~= nil then
		carry.model:Destroy()
		carry.model = nil
	end
	local model = AssetRegistry.cloneCat(carry.def.id, carry.variant)
	model.Name = "PackedCat"
	model:SetAttribute("CatId", carry.def.id)
	model:SetAttribute("Variant", carry.variant or "base")
	local body = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	local nameTag = if body ~= nil then body:FindFirstChild("NameTag") else nil
	if nameTag ~= nil then
		nameTag:Destroy()
	end
	if HeldCat.attachBack(model, character) == nil then
		model:Destroy()
	else
		model.Parent = character
		carry.model = model
	end
	character:SetAttribute("PackedCatId", carry.def.id)
end

-- #2856 (Derek2 2026-11-09: "make bag shown always no reason to have it go away its a good flex"): puts the worn pack
-- back when it has gone or come loose, for example when the avatar's appearance finished loading after spawn and
-- rebuilt the torso it was welded to, with the packed cat back in it. A no-op while it is held, without a Backpack,
-- or with no living character.
local PACK_CHECK_SECONDS = 2
local function keepBackpack(player: Player)
	local character = player.Character
	if
		character == nil
		or character.Parent == nil
		or not hasBackpack(player)
		or HeldCat.packHeld(character)
	then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return
	end
	local old = HeldCat.pack(character)
	if old ~= nil then
		old:Destroy()
	end
	wearBackpack(player)
	local carry = packed[player]
	if carry ~= nil and HeldCat.pack(character) ~= nil then
		attachPacked(player, carry)
	end
end

-- #3165: the cat in the hands stays in them. A carry the server still holds whose model is gone or no longer welded
-- to the character's torso (the avatar's appearance rebuilt it after a respawn, or the cat went on the root before
-- the torso was there) is put back, so the carry banner never stands over empty arms.
local function keepHeld(player: Player)
	local carry = carrying[player]
	local character = player.Character
	if carry == nil or character == nil or character.Parent == nil then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return
	end
	if not HeldCat.held(carry.model, character, root :: BasePart) then
		attachHeldCat(player, carry)
		-- the attach sets plain carry speed; a Catch Rush or a Startled slow still running keeps its own (review N247)
		CatService.refreshSpeed(player)
	end
end

-- #2565: takes the packed cat off the back (nil when none), its model gone.
local function endPacked(player: Player): Carry?
	local carry = packed[player]
	if carry == nil then
		return nil
	end
	packed[player] = nil
	if carry.model ~= nil then
		carry.model:Destroy()
		carry.model = nil
	end
	local character = player.Character
	if character ~= nil then
		character:SetAttribute("PackedCatId", nil)
		HeldCat.openPack(character, false) -- #2719
	end
	return carry
end

-- #2565: moves the packed cat into empty hands, with no getaway, so the drop, tackle and death paths that handle a
-- held cat handle it next. False when there is none or the hands are full.
-- #3145: `quiet` leaves the client's carry banner alone, for a caller that puts the cat down in the same breath
-- (the Drop button): the banner never flashes up for a cat that is already gone, and the client never has two
-- carry states to apply in one frame. That caller tells the client itself if the cat stays in the hands after all.
local function unpackCat(player: Player, quiet: boolean?): boolean
	if carrying[player] ~= nil or packed[player] == nil then
		return false
	end
	local carry = endPacked(player) :: Carry
	carrying[player] = carry
	attachHeldCat(player, carry)
	if quiet ~= true then
		CafeService.setCarrying(player, carry.def.id)
	end
	return true
end

-- #3145: after a quiet unpack whose put-down did not happen: the cat is in the hands after all, so the client hears.
local function sayHeld(player: Player)
	local carry = carrying[player]
	if carry ~= nil and CafeService.carrying(player) ~= carry.def.id then
		CafeService.setCarrying(player, carry.def.id)
	end
end

-- Callers check carrying first; the refusal here keeps one carry per player whatever path calls it. `method` is
-- "net" or "rescue"; `variant` "gold" or "rainbow" shows on the held cat and in the toast. `pickedUp` is a Dropped
-- cat taken with a swing (v0.8 F56, F93): only the toast says so, the carry is like any other.
local function startCarry(
	player: Player,
	def: Types.CatDef,
	method: Types.CatchMethod,
	charm: number?,
	variant: string?,
	pickedUp: boolean?,
	funnel: Telemetry.CatchFunnel?,
	homePos: Vector3?,
	knocks: number?,
	bonusXp: number?,
	pity: boolean?
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
	-- #3022: a catch (not a cat picked up off the ground) while the save waits for its second cat
	if pickedUp ~= true then
		local profile = DataService.get(player)
		if profile ~= nil and SecondCat.waiting(profile) then
			Second.step(player, profile, SecondCat.CAUGHT)
		end
		-- #3035: a first-session Tier 1 player's first night catch of the session (Research-Agent: do they use it)
		if
			profile ~= nil
			and not ClockService.areasOpen()
			and NightPass.firstOf(profile, LiveFlagService.on(NightPass.FLAG))
		then
			Second.step(player, profile, NightPass.CAUGHT)
		end
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
		homePos = homePos,
		knocks = knocks or 0,
		bonusXp = bonusXp,
		pity = pity,
	}
	if packed[player] == nil and hasBackpack(player) then
		-- #2565: the first cat rides in the Backpack and the net stays out; the walk speed doesn't change
		packed[player] = carry
		attachPacked(player, carry)
		if funnel ~= nil then
			Telemetry.catchCaught(player, funnel)
		end
		return true
	end
	carrying[player] = carry
	attachHeldCat(player, carry)
	if pickedUp ~= true then
		getaway(player, carry) -- a net catch or a rescue; picking up a dropped cat gives neither (F55)
	end
	CafeService.setCarrying(player, def.id)
	local profile = DataService.get(player)
	if profile ~= nil then
		-- a catch is out in an area: first_catch implies the alley step when TutorialAdvance 1 never came (#1273)
		if not Onboarding.reached(profile.telemetry, "first_catch") then
			local tries = if method == "rescue"
				then profile.stats.rescueAttempts
				else profile.stats.grabsAttempted
			Telemetry.custom(player, "first_catch_tries", math.max(1, tries), {
				if method == "rescue" then "rescue" else "net",
			})
			Telemetry.onboarding(player, profile, "first_catch")
			-- #1273: still holding it CARRY_STEP_SECONDS later (a check-in sooner implies the step)
			task.delay(CARRY_STEP_SECONDS, function()
				local current = DataService.get(player)
				-- the same carry: a cat dropped and another picked up in the meantime does not count (review)
				if current ~= nil and carrying[player] == carry then
					Telemetry.onboarding(player, current, "carrying_first_cat")
				end
			end)
		end
	end
	if funnel ~= nil then
		Telemetry.catchCaught(player, funnel)
	end
	-- #2399 (Derek2: "way too many bubble pop ups ... you caught this cat"): no "You caught X! Bring it to the camp"
	-- toast; the catch's result word, the found card and the carry portrait already say it
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
	-- through refreshSpeed, so a check-in inside a Startled slow keeps the slow (review N247)
	CatService.refreshSpeed(player)
	if character ~= nil and carry.rushUntil ~= nil and carry.rushUntil > serverNow() then
		character:SetAttribute("RushUntil", 0) -- checked in or knocked loose mid-rush: the speed lines stop (F55)
	end
	return carry
end

-- #1884 (catch-rework.md 7d): each player's PURRFECT catches in a row this session; any other result resets it.
local purrfectStreak: { [Player]: number } = {}

-- The finish CatchResult carries (#1884): the trust reached, the need, how it ended and the streak after it.
local function finishOf(
	player: Player,
	attempt: Circles.Attempt,
	finish: Types.CatchFinishKind
): Types.CatchFinish
	local streak = if finish == "purrfect" then (purrfectStreak[player] or 0) + 1 else 0
	purrfectStreak[player] = streak
	return {
		trust = attempt.trust or 0,
		trustNeed = attempt.need or 0,
		finish = finish,
		streak = streak,
	}
end

-- #1727, #1884: the server's grade and the trust after it, for every circle judged since `before` (pressed or
-- expired), to the catcher alone.
local function sendJudged(player: Player, strayId: string, attempt: Circles.Attempt, before: number)
	for judged = before, attempt.nextIndex - 1 do
		local grade = attempt.grades[judged]
		Net.fire(player, "CatchJudged", strayId, judged, grade, attempt.trust)
	end
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
	local pressed = 0
	for _, grade in attempt.grades do
		if grade ~= "left" then -- #1884: a paw ring left alone was never pressed
			Circles.pushHistory(history, grade == "perfect")
			pressed += 1
		end
	end
	profile.stats.circlesTotal += pressed
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
-- (v0.5, data-model section 10 step 5; v0.8 F57 runs twice as far). Nobody can start a catch on it until
-- FleeingUntil, and the player who missed `selfRetry` seconds more. A stray on a perch (a
-- rock, the tree house cushion, the Great Oak's top) hisses and stays put for the breather instead: the sprint aims
-- at the floor and would drop it through whatever it sits on (reviewer S86), and the climb stays worth a retry.
local function flee(stray: Stray, player: Player, selfRetry: number)
	local at = stray.model:GetPivot().Position
	if at.Y > world.areas[stray.area].floorY + PERCH_ABOVE then
		local now = serverNow()
		stray.fleeingUntil = Catching.fleeUntil(now, 0)
		stray.selfRetryAt[player.UserId] = stray.fleeingUntil + selfRetry
		stray.model:SetAttribute("HissAt", now)
		stray.model:SetAttribute("FleeingUntil", stray.fleeingUntil)
		return
	end
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
	stray.selfRetryAt[player.UserId] = stray.fleeingUntil + selfRetry
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

-- F57 (data-model section 10 step 5, v0.8): the player who missed is Startled, walking at StartledWalkSpeed for
-- StartledSeconds; `StartledUntil` on the character shows the dizzy stars (Effects/Chase).
local function startle(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	local ends = serverNow() + Config.StartledSeconds
	startledUntil[player] = ends
	character:SetAttribute("StartledUntil", ends)
	CatService.refreshSpeed(player)
	task.delay(Config.StartledSeconds, function()
		if startledUntil[player] == ends then
			startledUntil[player] = nil
			CatService.refreshSpeed(player)
		end
	end)
end

-- #2774 (Derek2 2026-11-09: "make the first players catch buffed no matter the rarity so its super easy"): until
-- their first check-in, a beginner's catch on any free stray, not only their own tutorial stray, is the tutorial's
-- one slow circle with doubled bands, and a Miss only brings the circle back.
-- #3022: so is the catch of the stray that waits for a player's second cat (shared/SecondCat), for that player.
local function easyCatch(player: Player, profile: Types.PlayerProfile, stray: Stray): boolean
	if stray.waitsFor == player.UserId and SecondCat.waiting(profile) then
		return true
	end
	-- #3662 (Derek 2026-11-12: "the first cat catch where it used to stop the circle and wait for you to click/guide
	-- you should now be for the second catch not first because first is the free one from food bowl"): the
	-- walk-through's first cat is the bait bowl's, so the first check-in comes before the player has ever swung the
	-- net. The easy catch now lasts until a cat caught by hand is checked in (SecondCat.caught), on any free stray.
	-- Only on a plain stray of SecondCat.MAX_RARITY or below (SecondCat.easyFirst), so it never hands a new save a
	-- Legendary, Mythical, Secret, gold or rainbow cat.
	if SecondCat.easyFirst(profile.stats, stray.def.rarity, stray.variant) then
		return true
	end
	-- #3181: another beginner's tutorial stray too, now that anyone may catch one
	return profile.tutorialStep < Config.TutorialGuaranteedStrayStep
end

-- startCatch, below; a beginner's Miss on their tutorial stray starts the circle again through it (F87).
local startCatch: (Player, Types.PlayerProfile, Stray, Telemetry.CatchFunnel?) -> string?

-- F87 (easy-start.md section 2b): a beginner's Miss on their own tutorial stray costs nothing. The cat stays put
-- with no hiss, sprint, wait or shaky paws, and the circle comes back by itself after TutorialRetrySeconds with
-- "Try again!", as often as it takes. Walking out of reach is said instead, and the next swing starts it again. A
-- circle that ran out with no press at all does not come back by itself either, so a beginner who walked off or
-- went idle in front of the cat does not loop catches (and catch_circles events) until the next swing.
local function tutorialMiss(
	player: Player,
	stray: Stray,
	attempt: Circles.Attempt,
	forfeit: string?,
	funnel: Telemetry.CatchFunnel?
)
	Net.fire(
		player,
		"CatchResult",
		stray.id,
		attempt.grades,
		false,
		0,
		serverNow() + Config.TutorialRetrySeconds,
		finishOf(player, attempt, "bolt")
	)
	if forfeit ~= nil then
		Net.toast(player, forfeit, "warn")
		return
	end
	Net.toast(player, "Try again! Tap as the circle closes.", "info")
	if next(attempt.errors) == nil then
		return -- no press reached the server: wait for the next swing
	end
	task.delay(Config.TutorialRetrySeconds, function()
		local profile = DataService.get(player)
		if
			profile == nil
			or player.Parent ~= Players
			or not stray.alive
			or not easyCatch(player, profile, stray)
			or stray.attempt ~= nil
		then
			return
		end
		lastCatchStart[player] = nil -- the server's own restart, not a second swing
		local reason = startCatch(player, profile, stray, funnel)
		if reason ~= nil then
			Net.toast(player, reason, "warn")
		end
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
	CatService.refreshSpeed(player) -- #2052: the circles are over, so the catcher walks again
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
	local succeeded = forfeit == nil and Circles.succeeded(attempt)
	local pitySlot = stray.model:GetAttribute(Pity.SLOT_ATTRIBUTE)
	local claim = pityClaim
	if succeeded and type(pitySlot) == "number" and claim ~= nil then
		-- #1572 (luck-and-rare-moments.md 1h): only the first catch anywhere gets the pity cat. The claim yields, so
		-- the lock is held meanwhile and nobody else starts on it.
		setLock(stray, player.UserId, serverNow() + 15)
		local kept = claim(player, pitySlot)
		if not stray.alive then
			return -- night came, or another server's catch puffed it meanwhile
		end
		if not kept then
			setLock(stray, 0)
			despawn(stray) -- puffs out of the net; PityService has told everyone who caught it
			return
		end
		if player.Parent ~= Players or carrying[player] ~= nil then
			setLock(stray, 0) -- left, or picked up another cat meanwhile: the claim stands and the cat stays out
			return
		end
	end
	setLock(stray, 0)
	local funnel = stray.funnel
	stray.funnel = nil
	local perfect = Circles.perfectCount(attempt)
	local rarity: string = stray.def.rarity
	local finishKind: Types.CatchFinishKind = if succeeded then Circles.finish(attempt) else "bolt"
	if forfeit == nil then
		-- #1934: the PURRFECT badges' counts (a forfeit is no judged catch, so it leaves the run as it is)
		Badges.noteFinish(profile.stats, finishKind == "purrfect" and not profile.flags.autoPress)
	end
	-- #2913: a miss says how its first missed ring went (early, late or no press)
	local result: string = if not succeeded
		then (if forfeit ~= nil then "forfeit" else Circles.firstMiss(attempt) or "missed")
		elseif finishKind == "purrfect" then "purrfect"
		else "caught"
	Telemetry.custom(
		player,
		"catch_circles",
		perfect,
		{ rarity, tostring(Economy.level(profile, "net")), result }
	)

	if succeeded then
		-- no Perfect bonus for a scripted-looking profile, nor on a Dropped cat, which already has its charm
		-- (reviewer S36: two friends could shove and re-catch it up to 100). Since v0.8 F56 a swing picks a Dropped
		-- stray up and never starts its circles, so this is only a guard.
		local gain = if profile.flags.autoPress
				or stray.drop ~= nil
				or stray.recaught
			then 0
			else Circles.charmGain(attempt)
		local finish = finishOf(player, attempt, finishKind)
		Net.fire(player, "CatchResult", stray.id, attempt.grades, true, gain, nil, finish)
		-- #1884: catch-rework.md 7d's finish, value the rings it took; finish, rarity, mood (PR 2)
		local fields: { string } = { finishKind, rarity, stray.mood }
		Telemetry.custom(player, "catch_finish", #attempt.grades, fields)
		profile.stats.grabsSucceeded += 1
		local method: Types.CatchMethod = stray.method
		local def, variant = stray.def, stray.variant
		local charm = math.min(100, stray.charm + gain)
		-- where it stood for the catch (it stays put while locked), on the floor or perch it lives on (F67)
		local at = stray.model:GetPivot().Position
		local homePos = Vector3.new(at.X, stray.home.Y, at.Z)
		local knocks = stray.knocks
		local pity = stray.pity
		local area = stray.area
		local waitedFor = stray.beginner -- #3181: someone else's tutorial stray
		-- #1181 (corner-shop-v2.md section 3): 1 in CatchSnackChance a stray's net catch drops a Small Snack, never a
		-- Dropped or re-caught cat's, so shoving and catching one cat again cannot farm them
		local dropsSnack = stray.drop == nil
			and not stray.recaught
			and snackRandom:NextNumber() < Config.CatchSnackChance
		despawn(stray, player)
		local bonusXp = if finishKind == "purrfect" and not profile.flags.autoPress
			then Config.CatXpBase
			else nil
		startCarry(player, def, method, charm, variant, nil, funnel, homePos, knocks, bonusXp, pity)
		if waitedFor ~= nil and waitedFor ~= player.UserId then
			-- #3181: the beginner it waited for gets a new one at their point now, not at the next 5 s tick
			task.defer(tutorialTick)
		end
		if dropsSnack then
			local paid =
				Payout.pay(player, profile, { catFood = { small_cat_snack = 1 } }, "catch_snack")
			if #paid > 0 then
				Net.toast(player, "The cat dropped a snack: " .. paid[1] .. " in your Bag", "good")
			end
		end
		if area == "park" then
			Telemetry.onboarding(player, profile, "first_park_catch")
		end
		Telemetry.caughtIn(player, profile, area) -- #3695: the clean funnel's area steps
		return
	end

	if easyCatch(player, profile, stray) then
		tutorialMiss(player, stray, attempt, forfeit, funnel)
		return
	end
	-- The stray moves first, so its FleeingUntil reaches the client ahead of the result (QA on #130). The miss costs
	-- the player who missed and nobody else (F57): a longer wait the more they miss it in a row, and shaky paws.
	local streak = Catching.nextMiss(stray.missStreak[player.UserId], serverNow())
	stray.missStreak[player.UserId] = streak
	flee(stray, player, Catching.selfRetrySeconds(streak.count))
	-- Only the server knows the streak, so the miss carries this player's own retry time (review S87).
	Net.fire(
		player,
		"CatchResult",
		stray.id,
		attempt.grades,
		false,
		0,
		stray.selfRetryAt[player.UserId],
		finishOf(player, attempt, "bolt")
	)
	Telemetry.custom(player, "catch_finish", #attempt.grades, { "bolt", rarity, stray.mood })
	startle(player)
	-- The catch HUD says the cat got away (UI.catch.showGrades); only a forfeit needs words from here (reviewer S39).
	Net.toast(player, if forfeit ~= nil then forfeit else "Your paws are shaking!", "warn")
end

-- Shove (section 10c) --------------------------------------------------------------------------------------

-- The carried cat drops where the target stands as a Dropped stray that keeps its charm, gold, rescued flag and the
-- spot it was caught at (a shove, v0.8 F56: no scurry; it stays where it fell, F67). Anyone picks it up with a
-- swing (F93). `shoverUserId` is 0 for a night death or Studio's hook. Nil when the target has no character to drop it
-- from, in which case the carry stays.
local function knockLoose(target: Player, shoverUserId: number, areaId: string): Stray?
	local root = rootPosition(target)
	local area = world.areas[areaId]
	if root == nil or area == nil or target.Character == nil or carrying[target] == nil then
		return nil
	end
	local carry = endCarry(target) :: Carry
	local feet = outOfCamp(WorldBuilder.clampToArea(area, root, 2, root))
	return spawnStray(carry.def, areaId, feet, nil, nil, nil, {
		charm = carry.charm,
		variant = carry.variant,
		method = carry.method,
		drop = Shove.newDrop(target.UserId, shoverUserId, serverNow()),
		homePos = carry.homePos,
		knocks = carry.knocks + (if shoverUserId ~= 0 then 1 else 0),
		pity = carry.pity,
	})
end

-- Remote handlers -----------------------------------------------------------------------------------------

-- True while the player's catch circles are running (CatService.inCatch).
function holdsCatch(player: Player): boolean
	for _, stray in strays do
		if stray.lockedBy == player.UserId and stray.attempt ~= nil and not lockExpired(stray) then
			return true
		end
	end
	return false
end

-- Starts the circles on `stray` for a swing that landed on it (F93: the old GrabBegin, now the server's own start):
-- the same checks, then CatchSchedule. Returns why it did not start, in words for a toast, or nil. `funnel` is the
-- catch_attempt funnel the swing opened.
function startCatch(
	player: Player,
	profile: Types.PlayerProfile,
	stray: Stray,
	funnel: Telemetry.CatchFunnel?
): string?
	if carrying[player] ~= nil then
		return "Check in the cat you are carrying first"
	end
	if inRescue(player) then
		return rescueText(player)
	end
	if inFlight(player) then
		return "Land first"
	end
	if campOf(player) ~= nil then
		return "Step out of the camp to catch it"
	end
	if not areaUnlocked(profile, stray.area) then
		return "This area opens at a higher tier. Rank up to catch cats here"
	end
	if not openFor(profile) then
		-- a stray still waiting out someone's catch at dusk (v0.9, F66); #2692: not for a night pass
		return Clock.CLOSED_TEXT
	end
	if stray.lockedBy ~= 0 and not lockExpired(stray) then
		-- busy, including the player's own catch in progress: a second start never restarts the circles
		return if stray.lockedBy == player.UserId
			then "Keep going, the circles are coming"
			else "Someone else is catching it"
	end
	if not withinRange(player, stray.body.Position, Config.GrabRangeStuds + 2) then
		return "Too far away"
	end
	local now = serverNow()
	if now < stray.fleeingUntil then
		return "It's running!"
	end
	local selfRetryAt = stray.selfRetryAt[player.UserId]
	if selfRetryAt ~= nil and now < selfRetryAt then
		return Cooldown.text(selfRetryAt - now) -- #2324
	end
	local last = lastCatchStart[player]
	if last ~= nil and now - last < Config.GrabCooldownSeconds then
		return "Give it a moment"
	end
	-- One catch at a time: a script must not run circles on two strays at once.
	if holdsCatch(player) then
		return "Finish this catch first"
	end
	lastCatchStart[player] = now

	-- a Steady Paw Potion running now plays the circles of the next net level (F64)
	local netLevel = Potions.netLevel(profile, Economy.level(profile, "net"), os.time())
	local function roll(): number
		return rng:NextNumber()
	end
	-- F87: a beginner's own tutorial stray is one slow circle with doubled bands (easy-start.md section 2b)
	local tutorial = easyCatch(player, profile, stray) -- #2774: any rarity, until the first check-in
	-- F83: the rarer the cat, the narrower its bands; CatchSchedule sends these, so the client draws the real ones
	local windows = if tutorial
		then Circles.tutorialWindows(netLevel)
		-- #2322: wider in the first area; #3135: a little narrower for a gold or rainbow coat
		-- #2913 follow-up: a little wider for a player's first few catches by hand
		else Circles.scaled(
			Circles.windowsFor(netLevel, stray.def.rarity, stray.area, stray.variant),
			Circles.earlyScale(SecondCat.caught(profile.stats))
		)
	-- #2920: a player's very first catch holds its ring on the target until the press
	-- #3662: the first catch by hand, which a bowl cat in the cafe no longer uses up
	local hold = tutorial and Config.CatchHoldFirstRing and SecondCat.caught(profile.stats) == 0
	local circles = if tutorial
		then Circles.tutorialSchedule(now, roll, hold)
		else Circles.schedule(stray.def.rarity, netLevel, now, roll, stray.area) -- #3140: quicker late on
	-- #1884 (catch-rework.md 7b): the trust bar; the tutorial stray's one ring catches on a Good or Perfect
	-- #1884 (7a): a swing landing just as a Curious cat walks up starts with CuriousTrustBonus more
	local trust = if tutorial
		then Circles.tutorialTrust()
		else Circles.trustFor(stray.def.rarity, Moods.trustBonus(stray.curiousAt, now))
	local attempt = Circles.newAttempt(circles, windows, trust)
	setLock(stray, player.UserId, Circles.lockUntil(circles, windows))
	stray.attempt = attempt
	CatService.refreshSpeed(player) -- #2052: the catcher stands still until the circles end
	profile.stats.grabsAttempted += 1
	Net.fire(
		player,
		"CatchSchedule",
		stray.id,
		circles,
		Circles.publicWindows(windows),
		trust.start,
		trust.need
	)
	stray.funnel = Telemetry.catchEngaged(player, stray.def.rarity, "net", stray.area, funnel)
	local pitySlot = stray.model:GetAttribute(Pity.SLOT_ATTRIBUTE)
	if type(pitySlot) == "number" and pityStarted ~= nil then
		pityStarted(player, pitySlot) -- #2796
	end
	-- a catch starts in reach of a stray, so catch_started implies near_stray when the tutorial stray was never the one
	-- (a player who caught another cat first would hold every later step behind it)
	Telemetry.onboarding(player, profile, "catch_started")

	-- A circle nobody presses is a Miss at its deadline (#1884: trust lost, and the catch ends only if the cat bolts);
	-- walking out of range ends it.
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
			local before = attempt.nextIndex
			Circles.expire(attempt, serverNow())
			sendJudged(player, stray.id, attempt, before)
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
	return nil
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
	-- #1727: the server's grade at once, so a device that guessed Miss on an edge press (S101) shows the rest
	sendJudged(player, strayId, attempt, before)
	for judged = before, attempt.nextIndex - 1 do
		logCircle(player, strayId, attempt, judged)
		local grade = attempt.grades[judged]
		if grade == "good" or grade == "perfect" then
			local profile = DataService.get(player)
			if profile ~= nil then
				Telemetry.onboarding(player, profile, "first_circle_hit")
			end
		end
	end
	if Circles.isDone(attempt) then
		finishCatch(player, stray, attempt)
	end
end

-- Picks up a Dropped stray a swing landed on (v0.8 F56, data-model section 10c; F93 folds PickUpCat into the swing):
-- anyone takes it with no circles, the shover and its last carrier included, with no owner window. The first swing
-- wins. The cat keeps its catId, gold, charm and rescued flag and gains no charm (S36), with no rush or burst; the
-- carry is like any other, so BumpGraceSeconds runs from here and the last carrier can shove back once it passes.
-- Returns why it was refused, in words for a toast, or nil.
local function pickUp(player: Player, profile: Types.PlayerProfile, stray: Stray): string?
	local root = rootPosition(player)
	local now = serverNow()
	local last = lastCatchStart[player]
	local reason = Shove.pickUpRefusal({
		dropped = stray.drop ~= nil,
		carrying = carrying[player] ~= nil,
		busy = inRescue(player) or holdsCatch(player) or inFlight(player),
		inCamp = campOf(player) ~= nil,
		areaUnlocked = areaUnlocked(profile, stray.area),
		areasClosed = not openFor(profile), -- #2692: the night pass picks up as by day
		distance = if root ~= nil then (root - stray.body.Position).Magnitude else nil,
		sinceGrab = if last ~= nil then now - last else nil,
	})
	if reason ~= nil then
		return reason
	end
	lastCatchStart[player] = now
	profile.stats.pickups += 1
	local method: Types.CatchMethod = stray.method
	local def, charm, variant, homePos = stray.def, stray.charm, stray.variant, stray.homePos
	local knocks, pity = stray.knocks, stray.pity
	despawn(stray, player) -- logs drop_outcome against the player who ended up with it
	startCarry(player, def, method, charm, variant, true, nil, homePos, knocks, nil, pity)
	return nil
end

-- The net swing (F93, catch-rework.md section 1) -----------------------------------------------------------

-- Server time of each player's last swing, for NetSwingCooldown.
local lastSwing: { [Player]: number } = {}
-- Clients this close to the swinger hear its NetSwung (the smack and whoosh on everyone else's screen).
local SWUNG_RANGE_STUDS = 150

-- A near miss (F93): the stray hops NetSwing.hopStuds straight away from the swinger at StrayFleeSpeed, kept inside
-- its area, then catches its breath like a miss, so the next swing cannot land on it straight away. It is no miss on
-- the cat: no hiss, no selfRetry and no streak. `HopAt` (server time) is for the sound and effects. A stray on a
-- perch stays put, as flee keeps it (S86).
local function hop(stray: Stray, player: Player, studs: number?)
	local at = stray.model:GetPivot().Position
	local area = world.areas[stray.area]
	if area == nil or at.Y > area.floorY + PERCH_ABOVE then
		return
	end
	local from = rootPosition(player)
	local away = if from ~= nil then Vector3.new(at.X - from.X, 0, at.Z - from.Z) else Vector3.zero
	if away.Magnitude < 0.1 then
		local angle = rng:NextNumber(0, math.pi * 2)
		away = Vector3.new(math.cos(angle), 0, math.sin(angle))
	end
	local target = clearPath(
		at,
		WorldBuilder.clampToArea(
			area,
			at + away.Unit * (studs or NetSwing.hopStuds(stray.def.rarity)),
			2,
			at
		)
	)
	local now = serverNow()
	local sprint = Vector3.new(target.X - at.X, 0, target.Z - at.Z).Magnitude
	stray.fleeingUntil = Catching.fleeUntil(now, sprint)
	stray.model:SetAttribute("HopAt", now)
	stray.model:SetAttribute("FleeingUntil", stray.fleeingUntil)
	stray.jumping = true
	stray.home = target
	stray.model:SetAttribute("Napping", false) -- a hop wakes a Sleepy cat (#1884)
	stray.walk += 1
	local walk = stray.walk
	task.spawn(function()
		Mover.walkTo(stray.model, target, Config.StrayFleeSpeed, function()
			return stray.alive and stray.lockedBy == 0 and stray.walk == walk
		end)
		task.wait(math.max(0, stray.fleeingUntil - serverNow()))
		stray.jumping = false
	end)
end

-- True when a swing can land on the stray: alive, not sprinting or catching its breath, not locked by anyone else
-- (catch-rework.md section 1). Everything else is startCatch's or pickUp's to refuse with words.
local function swingable(stray: Stray, player: Player, now: number): boolean
	if not stray.alive or stray.jumping or now < stray.fleeingUntil then
		return false
	end
	-- #3181 (Derek2 2026-11-10: "certain cats atleast at the beginning of alleyway are bugged and cant be caught no
	-- matter where I put net"): a beginner's tutorial stray was theirs alone (F87), so to everyone else, other new
	-- players included, it was a cat no net could catch. Anyone's swing lands on it now.
	return stray.lockedBy == 0 or stray.lockedBy == player.UserId or lockExpired(stray)
end

-- Free strays for a near miss: swingable, not Dropped (a dropped cat stays where it fell, F67) and not mid-walk home.
local function hoppable(stray: Stray, player: Player, now: number): boolean
	return swingable(stray, player, now)
		and stray.drop == nil
		and not stray.returning
		and stray.lockedBy == 0
end

local function swingCheck(player: Player): NetSwing.SwingCheck
	local last = lastSwing[player]
	return {
		carrying = carrying[player] ~= nil,
		busy = holdsCatch(player) or inRescue(player),
		inFlight = inFlight(player),
		inCamp = campOf(player) ~= nil,
		inTown = inTownSquare(player),
		sinceSwing = if last ~= nil then serverNow() - last else nil,
	}
end

-- Tells the swinger and every client near them how the swing went, for the smack, the bounce and the whoosh.
-- #2341 (Derek2: "make the rescue also start if you swing your net at them"): RescueService's, set at its start
-- (it requires this module, so it registers instead): a swing that lands on no stray tries the stuck cats in reach,
-- true when it took one.
local swingRescue: ((Player, Vector3, Vector3) -> boolean)? = nil

function CatService.setSwingRescue(
	handler: (player: Player, origin: Vector3, look: Vector3) -> boolean
)
	swingRescue = handler
end

local function announceSwing(player: Player, at: Vector3, hit: boolean)
	for _, other in Players:GetPlayers() do
		local position = if other ~= player then rootPosition(other) else at
		if position ~= nil and (position - at).Magnitude <= SWUNG_RANGE_STUDS then
			Net.fire(other, "NetSwung", player.UserId, hit)
		end
	end
end

-- The net lands, NetSmackDelay after SwingNet arrived: the nearest swingable stray in reach is the hit. A hit starts
-- its catch (a Dropped one is picked up at once); with no stray in reach, a stuck cat in reach starts its rescue
-- (#2341, swingRescue); a miss makes the free strays near the swinger hop away, unless the
-- player has not caught a cat yet. At night in an area there is nothing to land on and nothing hops.
local function landSwing(player: Player)
	local profile = DataService.get(player)
	local character = player.Character
	local rootInstance = if character ~= nil
		then character:FindFirstChild("HumanoidRootPart")
		else nil
	if
		profile == nil
		or player.Parent ~= Players
		or rootInstance == nil
		or not rootInstance:IsA("BasePart")
	then
		return
	end
	local root = rootInstance :: BasePart
	local check = swingCheck(player)
	check.sinceSwing = nil -- this swing's own cooldown is already spent
	if NetSwing.refusal(check) ~= nil then
		announceSwing(player, root.Position, false) -- a carry or a rescue began while the net came down
		return
	end
	local now = serverNow()
	local origin, look = root.Position, root.CFrame.LookVector
	local open = openFor(profile) -- #2692: a night pass swings at its own tutorial stray
	local targets: { NetSwing.Target } = {}
	local near = 0
	if open then
		for id, stray in strays do
			if swingable(stray, player, now) then
				table.insert(targets, { id = id, position = stray.body.Position })
				-- only the strays a miss would make hop count as near (review N294)
				if
					hoppable(stray, player, now) and NetSwing.nearMiss(origin, stray.body.Position)
				then
					near += 1
				end
			end
		end
	end
	local picked = NetSwing.pick(origin, look, targets, NetSwing.extraFor(profile.mystery)) -- #2565: the Long Net
	-- #2774: a beginner's swing near their own tutorial stray lands on it whichever way they face
	if picked == nil and profile.tutorialStep < Config.TutorialGuaranteedStrayStep then
		for _, target in targets do
			local candidate = strays[target.id]
			if
				candidate ~= nil
				and candidate.beginner == player.UserId
				and NetSwing.beginnerReach(origin, target.position)
			then
				picked = target
				break
			end
		end
	end
	local stray = if picked ~= nil then strays[picked.id] else nil
	local started = false
	if stray ~= nil then
		local reason = if stray.drop ~= nil
			then pickUp(player, profile, stray)
			else startCatch(
				player,
				profile,
				stray,
				Telemetry.swingHit(player, stray.def.rarity, "net", stray.area)
			)
		started = reason == nil
		if reason ~= nil then
			Net.toast(player, reason :: string, "warn") -- the checker loses the narrowing over the two calls
		end
	elseif
		open
		and swingRescue ~= nil
		and (swingRescue :: (Player, Vector3, Vector3) -> boolean)(player, origin, look)
	then
		started = true -- #2341: it landed on a stuck cat; RescueService answers as for its prompt
	elseif near > 0 and NetSwing.missHops(profile.tutorialStep) then
		for _, other in strays do
			if hoppable(other, player, now) and NetSwing.nearMiss(origin, other.body.Position) then
				hop(other, player)
			end
		end
	end
	announceSwing(player, origin, started)
	Telemetry.netSwing(player, NetSwing.result(stray ~= nil, near), Economy.level(profile, "net"))
end

-- SwingNet() (F93): no arguments; one per NetSwingCooldown (the limiter in Net is the flood guard). The swing is
-- judged when the net lands, NetSmackDelay from now. A refused swing gets no answer: the client checks the same
-- before it plays the smack.
local function onSwingNet(player: Player)
	if DataService.get(player) == nil then
		return
	end
	if NetSwing.refusal(swingCheck(player)) ~= nil then
		return
	end
	lastSwing[player] = serverNow()
	task.delay(Config.NetSmackDelay, landSwing, player)
end

-- Adds the cat to the player's cafe and, with `notify`, tells them and the server (CatCaught, the shout-out). The
-- carry has already ended, or never began: dusk checks a Dropped stray in for its last carrier this way.
local function checkIn(player: Player, carry: Carry, notify: boolean, profile: Types.PlayerProfile?)
	local def = carry.def
	-- F89: whether the collection held an Epic or better before this cat, for the first Epic's card
	local before = profile or DataService.get(player)
	local hadEpicOrBetter = before ~= nil and RareMoments.ownsEpicOrBetter(before.collection)
	local instance, isNew = CafeService.addCaughtCat(
		player,
		def,
		notify,
		profile,
		carry.charm,
		carry.method,
		carry.variant
	)
	local bonusXp = carry.bonusXp
	if bonusXp ~= nil and bonusXp > 0 then
		CatStats.addXp(instance, bonusXp) -- #1884: a PURRFECT catch joins a level up (CatXpBase is level 2)
	end
	if notify then
		local current = DataService.get(player)
		if current ~= nil then
			Telemetry.onboarding(player, current, "first_checkin")
		end
		if carry.funnel ~= nil then
			Telemetry.catchCheckedIn(player, carry.funnel, instance.uid, instance.spotId ~= nil)
		end
		Net.fire(player, "CatCaught", def.id, isNew, instance.variant)
		local verb = if carry.method == "rescue" then "rescued" else "caught"
		-- the shout-out chime rises with rarity; F89: a Legendary or Mythical one at most once a minute a player
		RareMomentService.shoutOut(
			player,
			def.rarity,
			Catching.shoutOut(player.DisplayName, verb, def, carry.variant),
			-- #2567: a pity or shower cat's line stays in this server; #3470: a Secret's too
			carry.pity == true or def.rarity == Catalog.SECRET
		)
		if def.rarity == Catalog.SECRET then
			Telemetry.custom(
				player,
				"secret_caught",
				carry.knocks,
				{ RareMoments.how(carry.method), instance.variant }
			)
		end
		RareMomentService.secured(player, def, carry.variant, carry.method, hadEpicOrBetter)
		EventRewardService.secured(player) -- #2486: a Cafe Event's reward for a secure in its window
		-- F101: a check-in scores for the Rescue Rally, a rescued cat three times (the rescue's points)
		RallyService.score(player, if carry.method == "rescue" then "rescue" else "checkIn")
	end
end

-- `profile` is passed on the save-on-leave path, where the session is closing and a lookup must not race it.
local function finishCheckIn(player: Player, notify: boolean, profile: Types.PlayerProfile?)
	local extra = endPacked(player) -- #2565: the packed cat hops in first
	-- #3145: an error checking the packed cat in must not leave the held one in the arms
	local ok, err: unknown = true, nil
	if extra ~= nil then
		local packedCat = extra
		ok, err = pcall(function()
			checkIn(player, packedCat, notify, profile)
		end)
	end
	local carry = endCarry(player)
	if carry ~= nil then
		checkIn(player, carry, notify, profile)
	end
	if not ok then
		error(err, 0)
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
		knocks = stray.knocks,
		pity = stray.pity,
	}
	despawn(stray, owner)
	checkIn(owner, carry, true)
	Net.toast(owner, string.format("%s followed you home at dusk.", carry.def.name), "good")
end

-- The client asks as it comes within reach of a door; by the time the ask arrives a running player is a few studs
-- on, so the server allows that much more.
local CHECK_IN_LAG_STUDS = 4

local function onCheckIn(player: Player)
	local carry = carrying[player] or packed[player] -- #2565
	local plot = PlotService.get(player)
	if carry == nil or plot == nil then
		return
	end
	-- Either door works (layout v2): the back door is the short way in from the back alley.
	local range = Config.CheckInRangeStuds + CHECK_IN_LAG_STUDS
	if
		not withinRange(player, plot.door.Position, range)
		and not withinRange(player, plot.backDoorZone.Position, range)
	then
		return
	end
	finishCheckIn(player, true)
end

-- F84 (hometown-cannon.md section 4): a carrier who walks into a camp checks the cat in there, as at a door.
-- CampCheckIn goes to every client first, while the cat is still in their arms, so each client copies it into the
-- camp's basket; then CatCaught as for any check-in.
local function campCheckIn(player: Player, campId: string)
	local carry = carrying[player] or packed[player] -- #2565
	if carry == nil then
		return
	end
	Net.fireAll("CampCheckIn", player.UserId, campId)
	Telemetry.custom(
		player,
		"camp_checkin",
		math.floor(serverNow() - carry.startedAt),
		{ campId, carry.def.rarity, tostring(carry.knocks) }
	)
	finishCheckIn(player, true)
end

-- How near the straight path from `from` to `to` passes `point`.
local function pathDistance(from: Vector3, to: Vector3, point: Vector3): number
	local step = to - from
	local length = step:Dot(step)
	local t = if length > 1e-6 then math.clamp((point - from):Dot(step) / length, 0, 1) else 0
	return (from + step * t - point).Magnitude
end

-- The server's own check-in (Derek 2026-10-28 01:22: "make it friendlier so that you can't run past it"): ten times
-- a second it checks every carrier's path since the last look, so one who runs straight past a door within
-- CheckInRangeStuds is checked in even if the client's ask never came. A step longer than MAX_STEP_STUDS is a
-- teleport or a respawn, not a walk, so only its end counts (review N225). A carrier inside a camp's rect checks in
-- there (F84); a camp is CampDepth deep, so no run skips it between two looks.
local MAX_STEP_STUDS = 16
local lastCarrierAt: { [Player]: Vector3 } = {}
local function checkInPassing()
	local seen: { [Player]: Vector3 } = {}
	local loaded: { Player } = {}
	for player in carrying do
		table.insert(loaded, player)
	end
	for player in packed do
		if carrying[player] == nil then
			table.insert(loaded, player) -- #2565: a packed cat alone checks in the same way
		end
	end
	-- #3145: each carrier on its own, so one whose check-in throws does not skip everyone after it in this look
	local function look(player: Player)
		local position = rootPosition(player)
		local plot = PlotService.get(player)
		if position == nil or plot == nil then
			return -- no cafe to check a cat in to, at a camp or a door (review N280)
		end
		local campId = Layout.campAt(position.X, position.Z)
		if campId ~= nil then
			campCheckIn(player, campId)
			return
		end
		local from = lastCarrierAt[player] or position
		if (position - from).Magnitude > MAX_STEP_STUDS then
			from = position
		end
		seen[player] = position
		local range = Config.CheckInRangeStuds
		if
			pathDistance(from, position, plot.door.Position) <= range
			or pathDistance(from, position, plot.backDoorZone.Position) <= range
		then
			finishCheckIn(player, true)
			seen[player] = nil
		end
	end
	for _, player in loaded do
		local ok, err = pcall(function()
			look(player)
		end)
		if not ok then
			warn("[CatService] check-in: " .. tostring(err))
		end
	end
	lastCarrierAt = seen
end

-- F84: each character's `Camp` attribute names the camp it stands in (its area id), nil elsewhere, for the client's
-- Tackle button and safe zone chip; the server's own checks look again (campOf). `NetHidden` is true while a cat is
-- in the arms or the character stands anywhere but a catching area outside its camp (netAway: Derek 2026-11-03 for the
-- Town Square, 2026-11-04 #1080 for the cafes and every warp or landing), so the net comes out only where catching
-- happens; the swing checks look again (swingCheck).
local function markCamps()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character == nil then
			continue
		end
		local campId = campOf(player)
		if character:GetAttribute("Camp") ~= campId then
			character:SetAttribute("Camp", campId)
		end
		local netHidden = if carrying[player] ~= nil or netAway(player) then true else nil
		if character:GetAttribute("NetHidden") ~= netHidden then
			character:SetAttribute("NetHidden", netHidden)
		end
		-- #2706: the walk speed follows stepping on and off the Town Square
		local onSquare = if inTownSquare(player) then true else nil
		if character:GetAttribute("OnSquare") ~= onSquare then
			character:SetAttribute("OnSquare", onSquare)
			CatService.refreshSpeed(player)
		end
	end
end

-- F67 (data-model 10c v0.10) ------------------------------------------------------------------------------

-- The floor under a carrier's root: the first solid part below it, cats and characters aside, else a root's height
-- (3 studs) down.
local function floorBelow(root: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	params.FilterDescendantsInstances = catsAndCharacters()
	local hit = Workspace:Raycast(root, Vector3.new(0, -12, 0), params)
	return if hit ~= nil then hit.Position else root - Vector3.new(0, 3, 0)
end

-- The stray spot of `areaId` nearest `position`, or nil when the area has none.
local function nearestSpot(areaId: string, position: Vector3): Vector3?
	local area = world.areas[areaId]
	if area == nil then
		return nil
	end
	local best: Vector3? = nil
	local bestDistance = math.huge
	for _, point in area.spawnPoints do
		local distance = (point.Position - position).Magnitude
		if distance < bestDistance then
			best, bestDistance = point.Position, distance
		end
	end
	return best
end

-- Where a let-go cat walks to and the area that is: where it was caught, else (a carry with no homePos) a free spot
-- of its own area. Nil when there is nowhere, and the player keeps the cat (reviewer N99). #3470: a Secret cat has no
-- area of its own, so one with no homePos (a bait bowl's) goes to a free spot of the area the player stands in (`at`).
local function homeFor(carry: Carry, at: Vector3?): (Vector3?, string?)
	local home = carry.homePos
	if home ~= nil then
		local areaId = WorldBuilder.areaAt(world, home) or carry.def.area
		if world.areas[areaId] ~= nil then
			return home, areaId
		end
	end
	local areaId = carry.def.area
	if world.areas[areaId] == nil and at ~= nil then
		areaId = WorldBuilder.areaAt(world, at) or areaId
	end
	local area = world.areas[areaId]
	if area == nil or #area.spawnPoints == 0 then
		return nil, nil
	end
	local pointIndex = freeSpawnPoint(areaId, nil)
	return area.spawnPoints[pointIndex or rng:NextInteger(1, #area.spawnPoints)].Position, areaId
end

-- Home again: a normal stray where it was caught, with the circles back. Its next catch adds no charm (S36), so drop
-- and re-catch is no charm loop. drop_outcome logs "returned" for the player who let it go.
local function arriveHome(stray: Stray, home: Vector3)
	if not stray.alive or not stray.returning then
		return
	end
	local drop = stray.drop
	stray.returning = false
	stray.drop = nil
	stray.recaught = true
	stray.home = home
	stray.model:PivotTo(CFrame.new(home) * stray.model:GetPivot().Rotation)
	stray.model:SetAttribute("Returning", false)
	stray.model:SetAttribute("Dropped", false)
	stray.model:SetAttribute("PickUp", false)
	local owner = if drop ~= nil then Players:GetPlayerByUserId(drop.owner) else nil
	if owner ~= nil then
		Telemetry.custom(owner, "drop_outcome", 1, { "returned", stray.def.rarity, stray.area })
	end
end

-- The path a walking-home cat follows: a cat's size, and it may hop up a step.
local RETURN_AGENT = { AgentRadius = 1, AgentHeight = 2, AgentCanJump = true, WaypointSpacing = 4 }

-- The walk home at DropReturnWalkSpeed: along a PathfindingService path, again from where it got to when a path
-- runs out short of home, and straight at home up to the first thing in the way when there is no path. It ends when
-- someone picks the cat up or dusk takes it (either despawns it), within DropHomeRadiusStuds of home, or after
-- DropReturnMaxSeconds, when the cat appears at home. It walks whether or not anyone is near (unlike wander, S35),
-- since a walk is short and someone may be chasing it. A home up on a perch (a porch, a rock, the Sewer's catwalk) is
-- walked to on the floor under it, and arriveHome puts the cat up there (review S88).
local function walkHome(stray: Stray, home: Vector3)
	local deadline = os.clock() + Config.DropReturnMaxSeconds
	-- #2687: the Lost and Found's Homing Bell walks the dropper's own cat home faster from Tier 5
	local drop = stray.drop
	local owner = if drop ~= nil then Players:GetPlayerByUserId(drop.owner) else nil
	local ownerProfile = if owner ~= nil then DataService.get(owner) else nil
	local speed = Config.DropReturnWalkSpeed
		* StationPerks.homingSpeed(if ownerProfile ~= nil then Economy.tier(ownerProfile) else nil)
	local walking = function(): boolean
		return stray.alive and stray.returning and os.clock() < deadline
	end
	local area = world.areas[stray.area]
	local goal = if area ~= nil and home.Y > area.floorY + PERCH_ABOVE
		then Vector3.new(home.X, area.floorY, home.Z)
		else home
	local path = PathfindingService:CreatePath(RETURN_AGENT)
	while walking() do
		local at = stray.model:GetPivot().Position
		if (at - goal).Magnitude <= Config.DropHomeRadiusStuds then
			break
		end
		local computed = pcall(function()
			path:ComputeAsync(at, goal)
		end)
		if not walking() then
			break
		end
		if computed and path.Status == Enum.PathStatus.Success then
			for i, waypoint in path:GetWaypoints() do
				if i > 1 and not Mover.walkTo(stray.model, waypoint.Position, speed, walking) then
					break
				end
			end
		else
			Mover.walkTo(stray.model, clearPath(at, goal), speed, walking)
		end
		-- no closer (a path that ends short, or a wall in the way): try again in a moment
		local now = stray.model:GetPivot().Position
		if walking() and (now - goal).Magnitude > (at - goal).Magnitude - 1 then
			task.wait(1)
		end
	end
	if stray.alive and stray.returning then
		arriveHome(stray, home)
	end
end

-- A death while the areas are closed (the Drop button is refused then): the cat lands where the carrier fell in an
-- area, else at a free spot in its own area, as a Dropped stray anyone picks up once the areas open and that the
-- next dusk checks in for its last carrier.
local function dropAtNight(player: Player, carry: Carry, root: Vector3?)
	local name = carry.def.name
	local here = if root ~= nil then WorldBuilder.areaAt(world, root) else nil
	if here ~= nil then
		if knockLoose(player, 0, here) ~= nil then
			Net.toast(player, string.format("You dropped %s.", name), "info")
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
	spawnStray(carry.def, homeId, point.Position, pointIndex, nil, nil, {
		charm = carry.charm,
		variant = carry.variant,
		method = carry.method,
		drop = Shove.newDrop(player.UserId, 0, serverNow()),
		homePos = carry.homePos,
		knocks = carry.knocks,
		pity = carry.pity,
	})
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

-- The Drop button (Derek 2026-10-27; F67, round 4 Q4): by day the cat is put down at the carrier's feet, wherever
-- they stand, as a Dropped, Returning stray with the player as its last carrier and no shover. It walks back to where
-- it was caught (walkHome) and anyone picks it up on the way with a swing (F93), gaining no charm. While the areas are
-- closed the button is refused, so no cat walks into a closed area.
-- A carrier's death drops the cat the same way, where the character fell and before the respawn (data-model 10c
-- v0.13.3), so Reset Character is never a free check-in and cannot skip a Tackle or the dusk sweep; at night it
-- cannot walk home, so dropAtNight. Leaving the game is the one exit that still checks the cat in.
-- #3145 (Derek2 2026-11-10: "sometimes cat don't drop off from bag and then stays like this and cant drop"): why the
-- Drop button cannot put `carry` down right now, as a drop_refused reason and the words for a toast ("" for no
-- toast), or nil when it can. Asked before a Backpack cat is unpacked, so a refused Drop leaves it in the Backpack,
-- and every refusal says why instead of doing nothing.
local DROP_CLOSED_TEXT = "Keep hold of it, the areas are closed."
local DROP_NO_HOME_TEXT = "It has nowhere to walk back to. Bring it to the camp."
local function dropRefusal(player: Player, carry: Carry): (string?, string?)
	if player.Character == nil or rootPosition(player) == nil then
		return "no_body", "" -- between a death and the respawn: nowhere to put it down, and nobody to read a toast
	end
	if not openFor(DataService.get(player)) then -- #2692: a night pass drops as by day
		return "closed", DROP_CLOSED_TEXT
	end
	if homeFor(carry, rootPosition(player)) == nil then
		return "no_home", DROP_NO_HOME_TEXT
	end
	return nil, nil
end

-- #3145: a Drop the server refused, said in a toast when it has words and counted by reason (Telemetry
-- drop_refused), all but "closed": the night's refusal is the rule working, said every time, and not a fault to count.
local function refuseDrop(player: Player, reason: string, text: string?)
	if reason ~= "closed" then
		Telemetry.custom(player, "drop_refused", 1, { reason })
	end
	if text ~= nil and text ~= "" then
		Net.toast(player, text, "warn")
	end
end

local function dropCarry(player: Player, died: boolean)
	local carry = carrying[player]
	local character = player.Character
	local root = rootPosition(player)
	-- a death with no root left (fallen below the world) still drops: the cat starts at home, which needs no spot
	-- (review N240)
	if carry == nil or character == nil or (root == nil and not died) then
		return
	end
	if not openFor(DataService.get(player)) then -- #2692: a night pass drops as by day
		if died then
			dropAtNight(player, carry, root)
		else
			refuseDrop(player, "closed", DROP_CLOSED_TEXT)
		end
		return
	end
	local home, areaId = homeFor(carry, rootPosition(player))
	if home == nil or areaId == nil then
		if not died then
			refuseDrop(player, "no_home", DROP_NO_HOME_TEXT) -- #3145: was silent
		end
		return
	end
	endCarry(player)
	local stray = spawnStray(
		carry.def,
		areaId,
		if root ~= nil then outOfCamp(floorBelow(root)) else home,
		nil,
		nil,
		nil,
		{
			charm = carry.charm,
			variant = carry.variant,
			method = carry.method,
			drop = Shove.newDrop(player.UserId, 0, serverNow()),
			homePos = home,
			returning = true,
			knocks = carry.knocks,
			pity = carry.pity,
		}
	)
	task.spawn(walkHome, stray, home)
	Net.toast(
		player,
		string.format(
			if died
				then "You dropped %s. It's walking home."
				else "You let %s go. It's walking home.",
			carry.def.name
		),
		"info"
	)
end

local function onDropCat(player: Player)
	-- #2565: the first press drops the held cat, the next the packed one. #2731: with only the packed cat, Drop
	-- (now on the HUD for it) unpacks and drops it; while the areas are shut for this player it says why not, as for a
	-- held cat, and stays packed
	-- #2873: not mid catch or rescue (the gamepad's DPad down, G and the HUD all land here), so a press meant for the
	-- circles never lets a cat go
	if CatService.inMinigame(player) then
		return
	end
	if carrying[player] ~= nil then
		dropCarry(player, false)
		return
	end
	local pack = packed[player]
	if pack == nil then
		-- #3145: the server holds no cat, yet the player pressed Drop: their screen still shows one. A fresh sync
		-- takes the carry banner down (UIController checks it against every sync). At most one a second (DropCat's
		-- limiter); a G press with nothing on screen never gets here, the client only sends it while it shows a cat.
		refuseDrop(player, "none", nil)
		CafeService.setCarrying(player, nil)
		return
	end
	-- #3145: asked before the cat leaves the Backpack. Before, a Drop that could not finish (no home to walk to)
	-- still moved the cat into the hands and then did nothing, press after press.
	local reason, text = dropRefusal(player, pack)
	if reason ~= nil then
		refuseDrop(player, reason, text)
		return
	end
	unpackCat(player, true)
	dropCarry(player, false)
	sayHeld(player)
end

-- Lifecycle -----------------------------------------------------------------------------------------------

-- #1884 (catch-rework.md 7a): how often strays look round for players to be curious or skittish about.
local MOOD_TICK_SECONDS = 0.2

-- Whether a Curious or Skittish stray is free to react: alive, nobody catching it, not running or resting from a
-- miss or hop, not Dropped or walking home, and on the floor (a perch cat stays put, as for wandering).
local function canReact(stray: Stray, now: number): boolean
	if not stray.alive or stray.lockedBy ~= 0 or stray.jumping or now < stray.fleeingUntil then
		return false
	end
	if stray.drop ~= nil or stray.returning or stray.beginner ~= nil then
		return false
	end
	local area = world.areas[stray.area]
	return area ~= nil and stray.home.Y <= area.floorY + PERCH_ABOVE
end

-- A Curious stray walks CuriousWalkStuds toward the first player who comes within CuriousRangeStuds, once.
local function curious(stray: Stray, _player: Player, root: Vector3, now: number)
	local at = stray.model:GetPivot().Position
	if not Moods.noticed(at, root) then
		return
	end
	stray.curiousAt = now
	stray.model:SetAttribute("CuriousAt", now)
	stray.model:SetAttribute("Napping", false)
	local area = world.areas[stray.area]
	local target =
		clearPath(at, WorldBuilder.clampToArea(area, Moods.curiousTarget(at, root), 2, at))
	stray.walk += 1
	local walk = stray.walk
	task.spawn(function()
		Mover.walkTo(stray.model, target, Config.StrayWanderSpeed, function()
			return stray.alive and stray.lockedBy == 0 and stray.walk == walk
		end)
	end)
end

-- A Skittish stray hops SkittishHopStuds away from a player inside its front arc, at most once a SkittishCooldown;
-- never from a player before tutorialStep 2 (7a).
local function skittish(stray: Stray, player: Player, root: Vector3, now: number): boolean
	if not Moods.hopReady(stray.skittishAt, now) then
		return false
	end
	local pivot = stray.model:GetPivot()
	if not Moods.inFrontArc(pivot.Position, pivot.LookVector, root) then
		return false
	end
	local profile = DataService.get(player)
	if profile == nil or not Moods.canStartle(profile.tutorialStep) then
		return false
	end
	stray.skittishAt = now
	hop(stray, player, Config.SkittishHopStuds)
	return true
end

local function moodTick()
	local now = serverNow()
	local roots: { [Player]: Vector3 } = {}
	for _, player in Players:GetPlayers() do
		local root = rootPosition(player)
		if root ~= nil and carrying[player] == nil and not inFlight(player) then
			roots[player] = root
		end
	end
	if next(roots) == nil then
		return
	end
	for _, stray in strays do
		local reacts = (stray.mood == "Curious" and stray.curiousAt == nil)
			or stray.mood == "Skittish"
		if not reacts or not canReact(stray, now) then
			continue
		end
		for player, root in roots do
			if stray.mood == "Curious" then
				curious(stray, player, root, now)
				if stray.curiousAt ~= nil then
					break
				end
			elseif skittish(stray, player, root, now) then
				break
			end
		end
	end
end

function CatService.start(builtWorld: WorldBuilder.World)
	world = builtWorld
	local folder = Instance.new("Folder")
	folder.Name = "Strays"
	folder.Parent = Workspace:FindFirstChild("World") or Workspace
	straysFolder = folder

	Net.on("SwingNet", onSwingNet)
	Net.on("CatchPress", onCatchPress)
	Net.on("CheckIn", onCheckIn)
	task.spawn(function()
		while true do
			task.wait(0.1)
			-- one bad carrier must not end the check-ins for the server's life (review N226, as N185)
			xpcall(checkInPassing, function(err: unknown)
				warn("[CatService] check-in: " .. tostring(err))
			end)
			xpcall(markCamps, function(err: unknown)
				warn("[CatService] camps: " .. tostring(err))
			end)
		end
	end)
	Net.on("DropCat", onDropCat)
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
		if carrying[player] ~= nil or packed[player] ~= nil then
			finishCheckIn(player, false, profile)
		end
	end)

	-- #2845: an owner's save usually loads after their first character spawns, so CharacterAdded's wearBackpack finds
	-- no Backpack yet; put it on once the save is in (a no-op without a character, or with the pack already worn)
	DataService.onLoaded:Connect(function(player: Player)
		wearBackpack(player)
		keepShoes(player) -- #4050
	end)

	-- #2856: the pack stays on. Again once the avatar's appearance is in (it can rebuild the torso), and a light
	-- check every PACK_CHECK_SECONDS for any other way it came off. #3165: the cat in the hands the same way.
	task.spawn(function()
		while true do
			task.wait(PACK_CHECK_SECONDS)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(function()
					keepBackpack(player)
					keepHeld(player) -- #3165
					keepShoes(player) -- #4050
				end)
				if not ok then
					warn("[CatService] keepBackpack: " .. tostring(err))
				end
			end
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAppearanceLoaded:Connect(function()
			task.wait(0.1)
			keepBackpack(player)
			keepHeld(player) -- #3165: a carry kept through a respawn went on before the appearance was in
			keepShoes(player) -- #4050
		end)
		player.CharacterAdded:Connect(function(character)
			local body = character:WaitForChild("Humanoid", 10)
			if body ~= nil and body:IsA("Humanoid") then
				(body :: Humanoid).Died:Connect(function()
					-- a frame later, so a character torn down by the player leaving (no parent by then) is not a
					-- death: leaving checks the cat in instead
					task.defer(function()
						if
							player.Parent ~= nil
							and character.Parent ~= nil
							and player.Character == character
						then
							dropCarry(player, true)
							if unpackCat(player, true) then
								dropCarry(player, true) -- #2565: the packed cat drops too
								sayHeld(player) -- #3145
							end
						end
					end)
				end)
			end
			task.wait(0.2)
			-- #2052: a catch still running from before a respawn ends now, judged like walking off (out of range, a
			-- Miss), so the new character is not held still and dying never dodges the cost
			for _, stray in strays do
				local attempt = stray.attempt
				if stray.lockedBy == player.UserId and attempt ~= nil then
					finishCatch(player, stray, attempt)
				end
			end
			wearBackpack(player) -- #2719
			keepShoes(player) -- #4050
			local pack = packed[player]
			if pack ~= nil then
				attachPacked(player, pack) -- #2565
			end
			local carry = carrying[player]
			if carry ~= nil then
				attachHeldCat(player, carry)
				return
			end
			local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid?
			if humanoid ~= nil then
				setSpeed(player, humanoid, Config.NormalWalkSpeed + pawsBonus(player))
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		purrfectStreak[player] = nil
		-- endCarry (via the finalizer above) clears the carry record; this only mops up when the profile is
		-- already gone, so the handler order between services does not matter.
		if carrying[player] ~= nil and DataService.get(player) == nil then
			carrying[player] = nil
		end
		if packed[player] ~= nil and DataService.get(player) == nil then
			packed[player] = nil
		end
		circleHistory[player] = nil
		Second.forget(player) -- #3022
		lastCatchStart[player] = nil
		lastSwing[player] = nil
		startledUntil[player] = nil
		for _, stray in strays do
			if stray.lockedBy == player.UserId then
				setLock(stray, 0)
			end
		end
	end)

	-- The sunrise wave (NightService), the tutorial rule, bait and, since #1159, daytime top-ups under the floor.
	task.spawn(function()
		while true do
			task.wait(5)
			tutorialTick()
			-- #3022: after it, so a beginner's tutorial stray has its `near` point first; one bad tick must not end
			-- the tutorial rule for the server's life
			xpcall(Second.tick, function(err: unknown)
				warn("[CatService] second cat tick: " .. tostring(err))
			end)
		end
	end)
	-- #3022: the stray waits from the moment the first customer is served, and the goal card hears of it at once
	Telemetry.onStep(function(player: Player, name: string)
		if name ~= "first_customer_served" then
			return
		end
		task.defer(function()
			xpcall(Second.served, function(err: unknown)
				warn("[CatService] second cat: " .. tostring(err))
			end, player)
			if DataService.get(player) ~= nil then
				CafeService.sync(player)
			end
		end)
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(1)
			local nowClock = os.clock()
			xpcall(topUpTick, function(err: unknown)
				warn("[CatService] top-ups: " .. tostring(err))
			end, nowClock - last)
			last = nowClock
		end
	end)
	task.spawn(function()
		while true do
			task.wait(MOOD_TICK_SECONDS)
			xpcall(moodTick, function(err: unknown)
				warn("[CatService] moods: " .. tostring(err))
			end)
		end
	end)
end

-- Dusk (v0.9, F66): every stray leaves, a Dropped one to its last carrier (leaveAtDusk). A stray someone is catching
-- goes once that catch ends, unless the catch lands it. #3077: an uncaught pity cat waits through its first night
-- (PityService says which, setPityKeeps), so one that came out just before dusk is still there at sunrise.
function CatService.nightFalls()
	waveNumber += 1 -- #3661: a sunrise wave still being placed stops here
	local leaving: { Stray } = {}
	local keeps = pityKeeps
	for _, stray in strays do
		local slot = stray.model:GetAttribute(Pity.SLOT_ATTRIBUTE)
		local waits = type(slot) == "number" and keeps ~= nil and keeps(slot)
		-- #2692: a beginner's own tutorial stray stays for their night pass
		if stray.beginner == nil and not waits then
			table.insert(leaving, stray)
		end
	end
	for _, stray in leaving do
		whenUnlocked(stray, leaveAtDusk)
	end
end

-- Sunrise (v0.9, F66): every area gets its wave of WaveSize strays, whether or not anyone has it unlocked. #3661:
-- rolled at once, placed over Config.WaveSpreadSeconds.
-- F88: a Lucky Day's waves roll at LuckyDayWaveLuck, and the day is logged as `lucky_day` (value the players in the
-- server; the first area a Mythical came to, or "none"). #1888: any special day logs it, with its kinds ("lucky",
-- "golden+rainbow").
function CatService.sunriseWave()
	local luckyDay = ClockService.luckyDay()
	local kinds = ClockService.dayKinds()
	local kindNames: { string } = {}
	if kinds ~= nil then
		for _, kind in { "lucky", "golden", "rainbow" } do
			if (kinds :: any)[kind] == true then
				table.insert(kindNames, kind)
			end
		end
	end
	local luck = if luckyDay then Config.LuckyDayWaveLuck else 1
	local mythicalArea = "none"
	waveNumber += 1
	local wave = waveNumber
	local waves: { { WavePlace } } = {}
	for _, areaDef in Catalog.areas do
		local places, mythical = rollWave(areaDef, luck)
		if mythical and mythicalArea == "none" then
			mythicalArea = areaDef.id
		end
		table.insert(waves, places)
	end
	-- #3661: the first few of every area (its rarest) at once, then the rest in turn, one area after another
	local order = StrayTopUp.waveOrder(waves, Config.WaveAtOnce)
	local later: { WavePlace } = order.later
	for _, entry: WavePlace in order.now do
		placeWave(entry)
	end
	if #later > 0 then
		local gap = StrayTopUp.waveGap(#later, Config.WaveSpreadSeconds)
		task.spawn(function()
			for _, entry: WavePlace in later do
				task.wait(gap)
				if waveNumber ~= wave or not ClockService.areasOpen() then
					return -- dusk came (or the next sunrise): this wave is over
				end
				xpcall(placeWave, function(err: unknown)
					warn("[CatService] wave: " .. tostring(err))
				end, entry)
			end
		end)
	end
	if #kindNames > 0 then
		-- a server event with no player of its own: logged under the first player here, none in an empty server
		local players = DataService.loadedPlayers()
		local someone: Player? = players[1]
		if someone ~= nil then
			Telemetry.custom(
				someone,
				"lucky_day",
				#players,
				{ mythicalArea, table.concat(kindNames, "+") }
			)
		end
	end
end

-- Checks in the cat the player carries, wherever they are: NightService sends a carrier home at dusk and the cat
-- is checked in on arrival (CatCaught as usual).
function CatService.forceCheckIn(player: Player)
	if carrying[player] ~= nil or packed[player] ~= nil then
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

-- F84: true mid Cat Cannon flight or cloud hop.
-- #2692: whether the night leaves this player alone: a beginner who has not checked in a first cat, or (#3035) a
-- Tier 1 player in their first session while the nightCatch switch is on (shared/NightPass).
function CatService.nightPass(player: Player): boolean
	local profile = DataService.get(player)
	return profile ~= nil and NightPass.of(profile, LiveFlagService.on(NightPass.FLAG))
end

function CatService.inFlight(player: Player): boolean
	return inFlight(player)
end

-- F84: the camp the player stands in (its area id), or nil.
function CatService.campOf(player: Player): string?
	return campOf(player)
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
	local now = serverNow()
	if carrying[target] == nil then
		-- #2565: a packed cat alone is knocked loose like a held one. #3145: only one that will fall; before, a
		-- tackle inside the grace, or with nowhere for the cat to land, still moved it from the Backpack into the hands
		local pack = packed[target]
		if
			pack == nil
			or not Shove.canKnockLoose(pack, now)
			or world.areas[areaId] == nil
			or rootPosition(target) == nil
		then
			return nil
		end
		unpackCat(target, true) -- quiet: it falls in the same breath, or sayHeld below
	end
	local carry = carrying[target]
	if carry == nil or not Shove.canKnockLoose(carry, now) then
		sayHeld(target)
		return nil
	end
	local loose = if forced ~= nil then forced == "loose" else Shove.landsLoose(rng:NextNumber())
	if loose and knockLoose(target, shoverUserId, areaId) ~= nil then
		if unpackCat(target, true) then
			knockLoose(target, shoverUserId, areaId) -- #2565: a tackle drops both (Derek2)
			sayHeld(target)
		end
		return "loose"
	end
	sayHeld(target)
	carry.immuneUntil = now + Shove.HELD_IMMUNE_SECONDS
	showCarry(target, carry)
	task.delay(Shove.HELD_IMMUNE_SECONDS + 0.05, function()
		if carrying[target] == carry then
			showCarry(target, carry)
		end
	end)
	return "held"
end

-- #2651 (tier6-7-areas.md section 5): a carrier who fell into an area's mist drops whatever it carried, in the hands
-- and in the Backpack, back onto the area's floor (knockLoose clamps the spot inside it), never lost. No shover.
function CatService.dropForFall(player: Player, areaId: string)
	if world.areas[areaId] == nil or rootPosition(player) == nil then
		return -- #3145: nowhere to land, so a Backpack cat stays packed (knockLoose would refuse it in the hands)
	end
	if carrying[player] == nil then
		unpackCat(player, true)
	end
	if carrying[player] ~= nil and knockLoose(player, 0, areaId) ~= nil then
		if unpackCat(player, true) then
			knockLoose(player, 0, areaId)
		end
	end
	sayHeld(player) -- #3145: whatever a quiet unpack left in the hands
end

function CatService.isCarrying(player: Player): boolean
	return carrying[player] ~= nil
end

-- #2565: a cat in the hands or in the Backpack: blocks the cannon (CannonService); tackling reads isCarrying (#2731).
function CatService.isLoaded(player: Player): boolean
	return carrying[player] ~= nil or packed[player] ~= nil
end

-- #2565: the packed cat's id, or nil.
-- #2719: puts the Backpack on the player's character now (MysteryMarketService, right after the buy).
function CatService.keepShoes(player: Player)
	keepShoes(player)
end

function CatService.tintShoes(player: Player)
	tintShoes(player)
end

function CatService.wearBackpack(player: Player)
	wearBackpack(player)
end

-- #3699: recolours the worn Backpack from the save (MysteryMarketService, right after a pick).
function CatService.tintBackpack(player: Player)
	tintBackpack(player)
end

function CatService.packedOf(player: Player): string?
	local carry = packed[player]
	return if carry ~= nil then carry.def.id else nil
end

-- A Swift Potion started or ran out (PotionService, F64), or a Startled slow (F57): the character's speed follows at
-- once, from whatever it is doing now (a Catch Rush, a carry, Startled or neither). #2706: with no cat, on the Town
-- Square (the character's OnSquare, kept by markCamps), TownWalkSpeedBonus more.
function CatService.refreshSpeed(player: Player)
	local character = player.Character
	local humanoid = if character ~= nil
		then character:FindFirstChildOfClass("Humanoid") :: Humanoid?
		else nil
	if humanoid == nil then
		return
	end
	local carry = carrying[player]
	local startled = startledUntil[player]
	-- #2706: a little faster on the Town Square
	local square = if (character :: Model):GetAttribute("OnSquare") == true
		then Config.TownWalkSpeedBonus
		else 0
	local base = if carry == nil
		then Config.NormalWalkSpeed + pawsBonus(player) + square
		elseif
			carry.rushUntil ~= nil and carry.rushUntil > serverNow()
		then Config.CatchRushWalkSpeed
		else carrySpeed(player) -- #3063, #3535: Swift Paws and the Speed Shoes, never on the rush
	-- Startled slows a carry too (a forfeit miss), never speeds one up (review N247)
	if startled ~= nil and startled > serverNow() then
		base = math.min(base, Config.StartledWalkSpeed)
	end
	setSpeed(player, humanoid, base)
end

-- Studio-only test hook: knocks the player's carried cat loose where they stand, as a shove from nobody would,
-- whatever the grace or immunity: a Dropped stray anyone picks up. Errors outside a catching area. Returns the new
-- StrayId.
-- Studio-only test hook (Laptop-Tester, 2026-11-07): ends every catch `player` has running, judged as walking off (a
-- Miss), as a respawn does (#2052). Returns how many ended.
function CatService.debugEndCatch(player: Player): number
	assert(RunService:IsStudio(), "debugEndCatch is Studio only")
	local ended = 0
	for _, stray in strays do
		local attempt = stray.attempt
		if stray.lockedBy == player.UserId and attempt ~= nil then
			finishCatch(player, stray, attempt)
			ended += 1
		end
	end
	return ended
end

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

-- Puts a freed cat in the player's arms (RescueService). `foundAt` is where it was stuck: a Drop walks it back to the
-- stray spot nearest that (F67), never into a bin or up a tree. False when they already carry one.
function CatService.startCarry(
	player: Player,
	def: Types.CatDef,
	method: Types.CatchMethod,
	charm: number?,
	variant: string?,
	funnel: Telemetry.CatchFunnel?,
	foundAt: Vector3?
): boolean
	local homePos = if foundAt ~= nil
		then nearestSpot(WorldBuilder.areaAt(world, foundAt) or def.area, foundAt)
		else nil
	return startCarry(player, def, method, charm, variant, nil, funnel, homePos)
end

-- RescueService registers how to tell whether a player's rescue attempt is running.
function CatService.setRescueCheck(check: (Player) -> boolean, text: ((Player) -> string)?)
	inRescue = check
	if text ~= nil then
		rescueText = text
	end
end

-- Where strays and stuck cats live in the world (Workspace.World.Strays).
function CatService.strayFolder(): Folder
	return straysFolder
end

-- Why the player cannot leave by fast travel right now, or nil: carrying a cat (walking it home is the loop and
-- bumps depend on it), or in the middle of a catch or a rescue.
-- `hopOk` (#2568, an open trade) lets a cloud hop through: the night's trip home keeps a trade going.
function CatService.busyReason(player: Player, hopOk: boolean?): string?
	local character = player.Character
	local hopping = character ~= nil
		and character:GetAttribute("CloudHopAt") ~= nil
		and character:GetAttribute("Launching") ~= true
	if inFlight(player) and not (hopOk == true and hopping) then
		return "You're already flying"
	end
	if carrying[player] ~= nil or packed[player] ~= nil then
		return Cannon.CARRY_TEXT -- every catching area is a wild area with a camp (F84); #2565: a packed cat too
	end
	if CatService.inCatch(player) then
		return "Finish this catch first"
	end
	if inRescue(player) then
		return rescueText(player)
	end
	return nil
end

-- #3211: what TradeService asks before a trade opens and while one is open (shared/Trade.busy). Carrying or packing
-- a cat is not on it. `hopOk` as in busyReason: the night's cloud hop home keeps a trade going (#2568).
function CatService.tradeDoing(
	player: Player,
	hopOk: boolean?
): { flying: boolean, catching: boolean, rescuing: boolean }
	local character = player.Character
	local hopping = character ~= nil
		and character:GetAttribute("CloudHopAt") ~= nil
		and character:GetAttribute("Launching") ~= true
	return {
		flying = inFlight(player) and not (hopOk == true and hopping),
		catching = CatService.inCatch(player),
		rescuing = inRescue(player),
	}
end

function CatService.strayCount(areaId: string): number
	return countStrays(areaId)
end

-- #1572 (luck-and-rare-moments.md 1h): spawns slot `slot`'s pity cat `catId` (`kind`) at a free hiding spot of the
-- area for its rarity (point 1 when all are taken), coat rolled as any stray's, out until PityService ends it (a
-- pity cat waits through one night, #3077; a shower cat goes at dusk). ATTRIBUTE (its kind,
-- for the gold beam) and SLOT_ATTRIBUTE go on the model. A normal stray in every way, except that a catch asks the
-- pity claim first. Nil when the area or cat is unknown.
function CatService.spawnPity(
	catId: string,
	areaId: string,
	kind: string,
	slot: number,
	coat: string? -- #2486: a Cafe Event shower's "rainbow"; nil rolls the coat as a stray's
): string?
	local def = Catalog.getCat(catId)
	local area = world.areas[areaId]
	if def == nil or area == nil or #area.spawnPoints == 0 then
		return nil
	end
	local pointIndex = freeSpawnPoint(areaId, def.rarity) or 1
	local point = area.spawnPoints[pointIndex]
	local stray = spawnStray(def, areaId, point.Position, pointIndex, nil, coat)
	stray.model:SetAttribute(Pity.ATTRIBUTE, kind)
	stray.model:SetAttribute(Pity.SLOT_ATTRIBUTE, slot)
	stray.pity = true
	return stray.id
end

-- #1572: the pity cat of `slot` leaves this server (another server's catch got it): every copy still out puffs
-- away, a catch in progress on it included. A copy already caught here is someone's carry and stays.
function CatService.removePity(slot: number): number
	local leaving: { Stray } = {}
	for _, stray in strays do
		if stray.alive and stray.model:GetAttribute(Pity.SLOT_ATTRIBUTE) == slot then
			table.insert(leaving, stray)
		end
	end
	for _, stray in leaving do
		local holder = if stray.lockedBy ~= 0
			then Players:GetPlayerByUserId(stray.lockedBy)
			else nil
		setLock(stray, 0)
		despawn(stray)
		if holder ~= nil then
			Net.fire(holder, "CatchResult", stray.id, {}, false, 0)
		end
	end
	return #leaving
end

-- #1572: PityService's claim, asked on a pity cat's catch.
function CatService.setPityClaim(claim: (Player, number) -> boolean)
	pityClaim = claim
end

-- #3077: PityService's answer at nightfall: whether the pity cat of `slot` waits through this night.
function CatService.setPityKeeps(keeps: (number) -> boolean)
	pityKeeps = keeps
end

-- #2796: PityService's hook, told when a catch starts on the pity cat of `slot`.
function CatService.setPityStarted(started: (Player, number) -> ())
	pityStarted = started
end

-- #2796: where the uncaught pity cat of `slot` is in this server, or nil.
function CatService.pityPosition(slot: number): Vector3?
	for _, stray in strays do
		if stray.alive and stray.model:GetAttribute(Pity.SLOT_ATTRIBUTE) == slot then
			return stray.body.Position
		end
	end
	return nil
end

-- Studio-only test hook: spawns a given cat at a free spawn point of the area (or point 1 if all are taken), in the
-- coat `coat` names ("gold", or true for gold; "rainbow", F99) and rolled as usual otherwise.
function CatService.debugSpawnStray(
	catId: string,
	areaId: string,
	coat: (boolean | string)?
): string
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
		point.Position,
		pointIndex,
		Config.StrayDespawnSeconds,
		if coat == true or coat == "gold"
			then "gold"
			elseif coat == "rainbow" then "rainbow"
			else nil
	)
	return stray.id
end

-- Studio-only test hook (F99 QA check 1): the next stray a wave or a refill spawns gets `coat` ("gold" or
-- "rainbow"); nil clears it.
function CatService.debugNextCoat(coat: string?)
	assert(RunService:IsStudio(), "debugNextCoat is Studio only")
	debugNextCoat = if coat == "gold" or coat == "rainbow" then coat else nil
end

-- #2913, #2915: the stray a first flight into `areaId` comes down beside (CannonService), or nil. In the Alleyway
-- it is the beginner's own tutorial stray, until their first catch; in the Park the free stray nearest its landing
-- pad, until the first Park catch (onboarding first_park_catch). Never one someone else is catching, a Dropped cat,
-- one walking home or another beginner's.
local PARK_BESIDE_STUDS = 60 -- a Park stray further than this from the pad doesn't count
function CatService.firstLandingStray(player: Player, areaId: string): Vector3?
	local profile = DataService.get(player)
	if profile == nil then
		return nil
	end
	local function free(stray: Stray): boolean
		return stray.alive
			and stray.area == areaId
			and stray.drop == nil
			and not stray.returning
			and (stray.lockedBy == 0 or stray.lockedBy == player.UserId or lockExpired(stray))
	end
	if areaId == TUTORIAL_AREA then
		if profile.stats.catsCaught > 0 then
			return nil
		end
		for _, stray in strays do
			if stray.beginner == player.UserId and free(stray) then
				return stray.body.Position
			end
		end
		return nil
	end
	local pad = Layout.landingPads[areaId]
	if
		areaId ~= "park"
		or pad == nil
		or Onboarding.reached(profile.telemetry, "first_park_catch")
	then
		return nil
	end
	local centre = Vector3.new(pad.centre.x, pad.centre.y, pad.centre.z)
	local best: Vector3? = nil
	local bestDistance = PARK_BESIDE_STUDS
	for _, stray in strays do
		if free(stray) and (stray.beginner == nil or stray.beginner == player.UserId) then
			local at = stray.body.Position
			local distance = (at - centre).Magnitude
			if distance < bestDistance then
				best, bestDistance = at, distance
			end
		end
	end
	return best
end

return CatService
