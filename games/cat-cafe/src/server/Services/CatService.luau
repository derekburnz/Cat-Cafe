--!strict
-- Strays: sunrise waves per area, the net (the swing, lock, closing circles, the chase after a miss), carrying a caught
-- or rescued cat home and check-in. The bait bowl is BaitService; NightService closes the areas at night and calls
-- nightFalls, sunriseWave and forceCheckIn (v0.9, F66). Server authoritative: the client only says that it swung
-- (F93) and which circle it pressed for; what the swing lands on, distance, locks, the schedule, the press times, the
-- chase and odds live here.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local AreaRares = require(ReplicatedStorage.Shared.AreaRares)
local CafeEvents = require(ReplicatedStorage.Shared.CafeEvents)
local Cannon = require(ReplicatedStorage.Shared.Cannon)
local CatStorm = require(ReplicatedStorage.Shared.CatStorm)
local Catching = require(ReplicatedStorage.Shared.Catching)
local Circles = require(ReplicatedStorage.Shared.Circles)
local EventService = require(script.Parent.EventService)
local FreeCatch = require(ReplicatedStorage.Shared.FreeCatch)
local HeldCat = require(ReplicatedStorage.Shared.HeldCat)
local Luck = require(ReplicatedStorage.Shared.Luck)
local Mover = require(ReplicatedStorage.Shared.Mover)
local Net = require(script.Parent.Net)
local NetSwing = require(ReplicatedStorage.Shared.NetSwing)
local NightPass = require(ReplicatedStorage.Shared.NightPass)
local PerfectCatch = require(ReplicatedStorage.Shared.PerfectCatch)
local CATCH_CURVE_FLAG = "catchCurve" -- #5392: shared/Circles curveWindows, curveSpeed and perfectGain
local CATCH_PERFECT_ATTRIBUTE = "CatchPerfectGain" -- #5392: the running catch's Perfect trust (UI/Components/CatchTrust)
local SecondCat = require(ReplicatedStorage.Shared.SecondCat)
local SecretCalm = require(ReplicatedStorage.Shared.SecretCalm)
local Shove = require(ReplicatedStorage.Shared.Shove)
local SpeedShoes = require(ReplicatedStorage.Shared.SpeedShoes)
local StrayTopUp = require(ReplicatedStorage.Shared.StrayTopUp)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

-- Modules whose exported types CatService does not name sit in one table, so the main chunk stays under
-- Luau's limit of 200 local registers (the Open Cloud engine smoke test failed on it, 2026-11-15).
local M = {
	-- #4251: an area that is not one of the ten (Harvest Hollow) says itself who may catch there (CatService.addArea),
	-- and the hooks told of every stray caught by net, with the area it was caught in (CatService.onCaught)
	areaGates = {} :: { [string]: (Types.PlayerProfile) -> boolean },
	caughtHooks = {} :: { (Player, Types.CatDef, string) -> () },
	campHooks = {} :: { (Player, string) -> () }, -- #5533: told of every camp check-in (CatService.onCampCheckIn)
	-- #4251: checks in a cat caught or picked up in an added area with no camp (set below finishCheckIn)
	homeFromCampless = nil :: ((Player, string) -> ())?,
	AssetRegistry = require(script.Parent.Parent.World.AssetRegistry),
	Badges = require(ReplicatedStorage.Shared.Badges),
	BagColours = require(ReplicatedStorage.Shared.BagColours),
	CafeService = require(script.Parent.CafeService),
	CatStats = require(ReplicatedStorage.Shared.CatStats),
	Catalog = require(ReplicatedStorage.Shared.Catalog),
	Clock = require(ReplicatedStorage.Shared.Clock),
	ClockService = require(script.Parent.ClockService),
	Config = require(ReplicatedStorage.Shared.Config),
	Cooldown = require(ReplicatedStorage.Shared.Cooldown),
	DataService = require(script.Parent.DataService),
	DragonKeep = require(ReplicatedStorage.Shared.DragonKeep),
	Economy = require(ReplicatedStorage.Shared.Economy),
	FreeStart = require(ReplicatedStorage.Shared.FreeStart), -- #5533 streetCats
	EventRewardService = require(script.Parent.EventRewardService),
	GoldenFish = require(ReplicatedStorage.Shared.GoldenFish),
	Guard = require(script.Parent.Parent.Util.Guard),
	IndexRewards = require(ReplicatedStorage.Shared.IndexRewards),
	Layout = require(script.Parent.Parent.World.Layout),
	LiveFlagService = require(script.Parent.LiveFlagService),
	PlayTime = require(script.Parent.Parent.Util.PlayTime), -- #5533 streetCats
	NightSpread = require(ReplicatedStorage.Shared.NightSpread), -- #5164
	Moods = require(ReplicatedStorage.Shared.Moods),
	Onboarding = require(ReplicatedStorage.Shared.Onboarding),
	NetTiers = require(ReplicatedStorage.Shared.NetTiers), -- #5170
	ParkFirstEasy = require(ReplicatedStorage.Shared.ParkFirstEasy), -- #5182
	Payout = require(script.Parent.Payout),
	Pity = require(ReplicatedStorage.Shared.Pity),
	PlotService = require(script.Parent.PlotService),
	RankUpRightAway = require(ReplicatedStorage.Shared.RankUpRightAway), -- #5031
	Tier3Path = require(ReplicatedStorage.Shared.Tier3Path), -- #5038
	HoodWelcome = require(ReplicatedStorage.Shared.HoodWelcome), -- #5652
	PicnicSeats = require(ReplicatedStorage.Shared.PicnicSeats), -- #5572
	PicnicParty = require(ReplicatedStorage.Shared.PicnicParty),
	MutationBoost = require(ReplicatedStorage.Shared.MutationBoost), -- #5493
	CatchLost = require(ReplicatedStorage.Shared.CatchLost), -- #5500
	StrayMeets = require(ReplicatedStorage.Shared.StrayMeets), -- onboarding_v9 near_stray
	OpenSpot = require(script.Parent.Parent.World.OpenSpot), -- #5038: where a waiting Park stray may sit
	Potions = require(ReplicatedStorage.Shared.Potions),
	RallyService = require(script.Parent.RallyService),
	RareMomentService = require(script.Parent.RareMomentService),
	RareMoments = require(ReplicatedStorage.Shared.RareMoments),
	SecretBeacons = require(script.Parent.SecretBeacons),
	StationPerks = require(ReplicatedStorage.Shared.StationPerks),
	SwiftPaws = require(ReplicatedStorage.Shared.SwiftPaws),
	TouchReach = require(ReplicatedStorage.Shared.TouchReach),
}

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
	perfect: boolean?, -- #5300: a Dropped stray that was a Perfect catch keeps its mark for whoever checks it in
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
	-- #5652 (hoodWelcome): the user id of the player whose first Neighbourhood landing brought it (shared/HoodWelcome).
	-- Not reserved and caught the normal way; only its caught log reads it.
	hoodFor: number?,
	-- #3035: the user id of the first-session Tier 1 player whose night pass brought it (shared/NightPass), at their
	-- plot's `near` point. Not reserved: anyone out at night may catch it. It leaves by night once that player's pass
	-- ends, and is an ordinary stray from the sunrise.
	nightFor: number?,
	-- #5533 (streetCats, shared/FreeStart): a Common put on an Alleyway `near` point for a play first start save's
	-- first minutes. Anyone may catch it; it leaves once no such save is in its first minutes.
	street: boolean?,
	-- #5572 (picnicParty): the user id of the player whose Picnic Party seated it on the blanket (the model's PicnicFor
	-- attribute). Theirs alone, an easy catch that cannot be lost, and it never wanders off the blanket.
	picnic: number?,
	-- #1884 (catch-rework.md 7a): its mood, rolled at spawn (the Mood attribute); a Curious one's walk toward a
	-- player (server time, nil until it notices one) and a Skittish one's last hop (server time)
	mood: Types.CatMood,
	curiousAt: number?,
	skittishAt: number?,
	secretHops: { [number]: number }, -- #4255 follow-up: a Secret's hops away from each player (by UserId), SecretCalm
	walk: number, -- bumped by every walk that starts, so an older walk stops where it is
	alive: boolean,
}

-- #5572: a player's picnic cats while their Picnic Party runs (Street.picnics)
type Picnic = { pivot: CFrame, defs: { Types.CatDef }, n: number, stray: Stray? }
-- #5676: each running party's blanket middle, by user id (CatService.picnicCats and picnicClear keep it)
local picnicSpots: { [number]: Vector3 } = {}

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
	perfect: boolean?, -- #5300 (shared/PerfectCatch): every ring Perfect with the perfectCatch switch on
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
	perfect: boolean?, -- #5300: a Perfect cat keeps its mark through a drop
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

-- #4255 follow-up: how fast the player's root moves (zero without a character), for SecretCalm.running
local function rootVelocity(player: Player): Vector3
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root ~= nil and root:IsA("BasePart") then
		return root.AssemblyLinearVelocity
	end
	return Vector3.zero
end

local function withinRange(player: Player, position: Vector3, range: number): boolean
	local root = rootPosition(player)
	return root ~= nil and (root - position).Magnitude <= range
end

-- How far a catch may start from and stay within: GrabRangeStuds and 2 for lag, plus #5309's BIG_REACH while bigNet
-- is on (Sync's run: a 12 stud swing the client allows was refused "Too far away" at the start of the circles).
local function catchRange(): number
	return M.Config.GrabRangeStuds + 2 + (if NetSwing.big() then NetSwing.BIG_REACH else 0)
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
	return if root ~= nil then M.Layout.campAt(root.X, root.Z) else nil
end

-- #5676 (switch picnicNet): the camp's no-net rule gives way within PicnicParty.NET_STUDS of the player's own
-- running party's blanket, so its cats can be caught where they sit.
local function campBlocks(player: Player): boolean
	if campOf(player) == nil then
		return false
	end
	local spot: Vector3? = picnicSpots[player.UserId]
	local root = rootPosition(player)
	if spot == nil or root == nil or not M.LiveFlagService.on(M.PicnicParty.NET_FLAG) then
		return true
	end
	local dx, dz = root.X - spot.X, root.Z - spot.Z
	return math.sqrt(dx * dx + dz * dz) > M.PicnicParty.NET_STUDS
end

-- True while the player's character stands on the Town Square (Derek 2026-11-03: "character in town square should
-- put net away"). No strays roam it, so the net is away there as it is while a cat is in the arms.
local function inTownSquare(player: Player): boolean
	local root = rootPosition(player)
	return root ~= nil and M.Layout.inTownSquare(root.X, root.Z)
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
	if campOf(player) ~= nil then
		return campBlocks(player) -- #5676: out by the player's own picnic blanket
	end
	return WorldBuilder.areaAt(world, root) == nil
end

-- F84 (section 4): a drop spot in a camp or at its edge moves out into the wild part (Layout.outOfCamp), then onto
-- that area's roam floor, since straight out from the Alleyway camp's middle can meet the building backs (N279).
local function outOfCamp(position: Vector3): Vector3
	local x, z, campId = M.Layout.outOfCamp(position.X, position.Z)
	local out = Vector3.new(x, position.Y, z)
	local area = if campId ~= nil then world.areas[campId] else nil
	return if area ~= nil then WorldBuilder.clampToArea(area, out, 2) else out
end

-- #2692: whether the areas are open for this player: by the clock, or by the night pass of a beginner who has not
-- checked in a first cat (shared/NightPass). #3035: or of a Tier 1 player in their first session, while the
-- nightCatch switch is on.
local function openFor(profile: Types.PlayerProfile?): boolean
	return NightPass.open(
		M.ClockService.areasOpen(),
		profile ~= nil and NightPass.of(profile, M.LiveFlagService.on(NightPass.FLAG))
	)
end

local function areaUnlocked(profile: Types.PlayerProfile, areaId: string): boolean
	local gate = M.areaGates[areaId]
	if gate ~= nil then
		return gate(profile)
	end
	local area = M.Catalog.getArea(areaId)
	if area == nil then
		return false
	end
	return M.Economy.tier(profile) >= area.tier
end

-- #3897: a rare cat's spawn banner goes only to the players who have its area open, never to the whole server.
local function announceToArea(areaId: string, text: string, rarity: Types.Rarity)
	local area = M.Catalog.getArea(areaId)
	for _, player in Players:GetPlayers() do
		local profile = M.DataService.get(player)
		if
			profile ~= nil
			and Catching.hearsSpawn(M.Economy.tier(profile), if area ~= nil then area.tier else nil)
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
	local area = M.Catalog.getArea(areaId)
	if area == nil then
		return 0, nil
	end
	local players: { Player } = {}
	local profiles: { Types.PlayerProfile } = {}
	for _, player in M.DataService.loadedPlayers() do
		local profile = M.DataService.get(player)
		if profile ~= nil then
			table.insert(players, player)
			table.insert(profiles, profile)
		end
	end
	local luck, from = M.IndexRewards.luckiest(profiles, area.tier, M.Economy.tier, os.time())
	return luck, if from ~= nil then players[from] else nil
end

-- The rainbow luck a stray or a rescue trap in the area rolls with (F99, rainbow-coat.md section 1): the highest
-- Index rainbow luck among the players in the server whose tier has the area open, 0 when nobody has. No potion
-- adds to it.
function CatService.rainbowLuckFor(areaId: string): number
	local area = M.Catalog.getArea(areaId)
	if area == nil then
		return 0
	end
	local profiles: { Types.PlayerProfile } = {}
	for _, player in M.DataService.loadedPlayers() do
		local profile = M.DataService.get(player)
		if profile ~= nil then
			table.insert(profiles, profile)
		end
	end
	return M.IndexRewards.bestRainbowLuck(profiles, area.tier, M.Economy.tier)
end

-- The coat a stray of `def` spawning in the area gets (F99): one roll, rainbow first and then gold
-- (Catching.rollCoat), each with the best luck in the server for the area.
local function rollStrayCoat(def: Types.CatDef, areaId: string): string
	local kinds = M.ClockService.dayKinds() -- #1572: a Golden or Rainbow Day lifts both chances until night
	return Catching.rollCoat(
		def,
		rng:NextNumber(),
		M.IndexRewards.rainbowChance(
			M.Clock.rainbowChance(M.MutationBoost.rainbow(), kinds), -- #5493: twice with mutationBoost on
			CatService.rainbowLuckFor(areaId)
		),
		M.IndexRewards.rollChance(
			M.Clock.goldChance(M.MutationBoost.gold(), kinds),
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
	local profile = M.DataService.get(player)
	-- #3871: plus the working cats' speed traits (Quick Paws and the combos that hold it), the best one only
	local traits = if profile ~= nil then M.Economy.traitBonus(profile, "speed") else 0
	-- #4447: the Dragon Keep's wing cards and set, inside DragonKeep.WALK_CAP
	local dragon = if profile ~= nil then M.DragonKeep.of(profile).walk else 0
	-- #4878: Speed Rush, +10 for everyone while it runs (walking and carrying; never the catch rush)
	return M.SwiftPaws.bonus(profile, M.LiveFlagService.on(M.SwiftPaws.FLAG))
		+ traits
		+ dragon
		+ EventService.speedRushWalk()
end

-- #3535: the carry walk speed: CarryWalkSpeed with Swift Paws and, with the Speed Shoes owned, the shoes' bonus, which stops one short of the player's own walk speed with no cat (shared/SpeedShoes.carry).
-- Never on the catch rush or a Startled slow.
local function carrySpeed(player: Player): number
	local paws = pawsBonus(player)
	return SpeedShoes.carry(
		M.Config.CarryWalkSpeed + paws,
		M.Config.NormalWalkSpeed + paws,
		M.DataService.get(player),
		true -- #4654 batch 7: the `speedShoes` switch is retired
	)
end

local function setSpeed(player: Player, humanoid: Humanoid, base: number)
	local profile = M.DataService.get(player)
	local still = holdsCatch(player)
	humanoid.WalkSpeed = if still
		then 0
		else base + (if profile ~= nil then M.Potions.speedBonus(profile, os.time()) else 0)
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

-- #4197 Secret Hunt: the running hunt's Secret strays (huntTick below). `gone` is huntTick's, called by despawn.
type Hunt = {
	id: string,
	count: number, -- cats the hunt hides
	spawned: number, -- of them out now or caught
	found: number,
	paid: boolean,
	ids: { [string]: boolean }, -- stray id -> one of the hunt's, still out
}
local hunt: Hunt? = nil
local huntGone: (stray: Stray, catcher: Player?) -> () = function() end

-- `catcher` is the player who just caught it, nil when it leaves. A knocked-loose cat logs who ended up with it
-- (drop_outcome, F16): against the catcher, or its old carrier when nobody caught it.
-- #4227: the wild Mythicals and Secrets out in each area, in ReplicatedStorage's AreaRares attribute for the Cannon
-- picker's and the HUD Cannon button's bubbles. Rewritten after each spawn and despawn, only when it changed.
local areaRaresText = ""
local function writeAreaRares()
	local rows: { AreaRares.Row } = {}
	for _, stray in strays do
		if stray.alive then
			table.insert(rows, {
				area = stray.area,
				rarity = stray.def.rarity :: string,
				wild = stray.drop == nil and stray.beginner == nil,
			})
		end
	end
	local text = HttpService:JSONEncode(AreaRares.count(rows))
	if text ~= areaRaresText then
		areaRaresText = text
		ReplicatedStorage:SetAttribute(AreaRares.ATTRIBUTE, text)
	end
end

-- #5500 (catchLostLog): a started net catch that ended with no cat, and why (shared/CatchLost)
local function lostCatch(player: Player?, stray: Stray, reason: string)
	if player == nil or not M.LiveFlagService.on(M.CatchLost.FLAG) then
		return
	end
	local attempt = stray.attempt
	local rings = if attempt ~= nil then #attempt.grades else 0
	Telemetry.custom(
		player,
		"catch_lost", -- CatchLost.EVENT
		rings,
		{ reason, Telemetry.device(player) or "unknown", stray.area }
	)
end

local function despawn(stray: Stray, catcher: Player?)
	if not stray.alive then
		return
	end
	if
		stray.attempt ~= nil
		and stray.lockedBy ~= 0
		and (catcher == nil or catcher.UserId ~= stray.lockedBy)
	then
		-- #5500: the cat went while someone was catching it
		lostCatch(
			Players:GetPlayerByUserId(stray.lockedBy),
			stray,
			if catcher == nil then "gone" else "other_player"
		)
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
	writeAreaRares()
	local running = hunt
	if running ~= nil and running.ids[stray.id] then
		huntGone(stray, catcher)
	end
	if stray.def.rarity == M.Catalog.SECRET then
		M.SecretBeacons.clear(stray.id)
		-- #3470: gone with nobody holding it (dusk, or a Dropped one nobody picked up)
		local someone: Player? = if catcher == nil then M.DataService.loadedPlayers()[1] else nil
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
		and stray.picnic == nil -- #5572: a picnic cat stays on its seat
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
	local secret = stray.def.rarity == M.Catalog.SECRET
	local speed = if secret then M.Config.SecretWanderSpeed else M.Config.StrayWanderSpeed
	local radius = if secret then M.Config.SecretWanderRadius else M.Config.StrayWanderRadius
	local pause = if secret then M.Config.SecretWanderPauseScale else 1
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
	local model = M.AssetRegistry.cloneCat(def.id, variant)
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
		if def.rarity == M.Catalog.SECRET and kept == nil then Catching.SECRET_NAME else def.name
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
	local mood: Types.CatMood = M.Moods.roll(def.rarity, rng:NextNumber(), beginner ~= nil)
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
			else M.CatStats.rollCharm(rng:NextNumber(), rng:NextNumber()),
		variant = variant,
		method = if kept ~= nil then kept.method else "net",
		drop = if kept ~= nil then kept.drop else nil,
		homePos = if kept ~= nil then kept.homePos else nil,
		returning = kept ~= nil and kept.returning == true,
		knocks = if kept ~= nil then kept.knocks or 0 else 0,
		pity = kept ~= nil and kept.pity == true,
		perfect = if kept ~= nil and kept.perfect == true then true else nil, -- #5300
		recaught = false,
		beginner = beginner,
		mood = mood,
		secretHops = {},
		walk = 0,
		alive = true,
	}
	strays[id] = stray
	writeAreaRares()
	if def.rarity == M.Catalog.SECRET then
		-- #3470: its sky beam shows from anywhere (Effects)
		M.SecretBeacons.set(id, areaId, position)
		M.SecretBeacons.follow(id, model)
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
			or clock - (lastRainbowToastAt :: number) >= M.Config.RainbowSpawnToastSeconds
		if toast then
			lastRainbowToastAt = clock
		end
		-- #5265 (Derek 2026-11-18: "make it no spawns that I can see from areas not unlocked yet"): with the
		-- lockedAreaQuiet switch (on unless set false) only the players whose tier opens the area hear it, so no toast,
		-- beam or sound for an area they cannot go to yet
		if M.LiveFlagService.on("lockedAreaQuiet") then
			local area = M.Catalog.getArea(areaId)
			for _, player in Players:GetPlayers() do
				local profile = M.DataService.get(player)
				if
					profile ~= nil
					and Catching.hearsSpawn(
						M.Economy.tier(profile),
						if area ~= nil then area.tier else nil
					)
				then
					Net.fire(player, "RainbowSpawned", areaId, def.id, id, toast)
				end
			end
		else
			Net.fireAll("RainbowSpawned", areaId, def.id, id, toast)
		end
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
	local spec = M.Layout.areas[areaId]
	if spec == nil then
		return nil, nil
	end
	return M.Layout.gatePosition(spec)
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
local function secretSpawned(stray: Stray, source: string?)
	local areaDef = M.Catalog.getArea(stray.area)
	local text = Catching.waveShoutOut(
		stray.def.rarity,
		stray.variant,
		if areaDef ~= nil then areaDef.name else stray.area
	)
	if text ~= nil then
		announceToArea(stray.area, text, stray.def.rarity)
	end
	local someone: Player? = M.DataService.loadedPlayers()[1]
	if someone ~= nil then
		Telemetry.custom(someone, "secret_spawn", 1, { stray.area, source or "wild" })
	end
end

local function spawnAt(
	areaId: string,
	pointIndex: number,
	rarity: Types.Rarity,
	beginner: number?,
	owned: { [string]: any }? -- #4188: a beginner's collection, so their tutorial stray is a kind they lack
): Stray
	local area = world.areas[areaId]
	-- #3470: a rolled Mythical turns Secret 1 time in 100 (never a beginner's stray; #4654 batch 5: the `secretCats`
	-- switch is retired). It takes the Mythical's point, and everyone hears the area and never the spot.
	-- (review note on #3486: the two draws are made only for a Mythical)
	local secret = if beginner == nil
			and rarity == "Mythical"
			and M.Catalog.getArea(areaId) ~= nil -- #4251: never in Harvest Hollow
		then Catching.secret(
			rarity,
			rng:NextNumber(),
			rng:NextNumber(),
			true,
			{ areaId }, -- #4221 (secretAreas retired, #4656)
			Catching.wildSecretShare( -- #5694 secretWild: 1 in 6, else #5418's share
				M.LiveFlagService.on(Catching.WILD_SECRET_FLAG),
				M.LiveFlagService.on(Catching.SECRET_DOUBLE_FLAG)
			)
		)
		else nil
	local def = secret
		or (
			if owned ~= nil
				then Catching.pickNewCat(rarity, areaId, rng:NextNumber(), owned)
				else Catching.pickCat(rarity, areaId, rng:NextNumber())
		)
	local point = area.spawnPoints[pointIndex]
	local stray = spawnStray(def, areaId, point.Position, pointIndex, nil, nil, nil, beginner)
	if secret ~= nil then
		secretSpawned(stray)
	end
	return stray
end

-- The Alleyway's spawn point indices with zone `near`, in order: plot p owns the p-th (v4, F84). #4920: another
-- area's with `areaId` (the Park's, for the walk-through's Park trip at night).
local function tutorialPoints(areaId: string?): { number }
	local area = world.areas[areaId or TUTORIAL_AREA]
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
	local night = not M.ClockService.areasOpen()
	local nightCatch = M.LiveFlagService.on(NightPass.FLAG)
	for _, player in M.DataService.loadedPlayers() do
		local profile = M.DataService.get(player)
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
	for _, player in M.DataService.loadedPlayers() do
		local profile = M.DataService.get(player)
		local plot = M.PlotService.get(player)
		if profile == nil or plot == nil then
			continue
		end
		if profile.tutorialStep >= M.Config.TutorialGuaranteedStrayStep then
			-- #3035: at night a first-session Tier 1 player with the pass finds one Common at their own point too,
			-- a new one within a tick of the last being caught. Not reserved and no easy catch: the Beginner
			-- attribute would give them the tutorial's "Try again!" and swing help on the client.
			-- #3659: and so does a Tier 1 player who has not caught a cat by hand yet, in any session
			if
				night
				and M.Economy.tier(profile) == NightPass.WALK_TIER
				and NightPass.walkOf(profile)
			then
				-- #4920 (Sync's night run 2026-11-16): the walk-through's Park trip at night (#4916's pass flies it
				-- there) finds one Common at a Park `near` point, a kind the save lacks, as Tier 1 does in the Alleyway
				nightHolders[player.UserId] = true
				local points = tutorialPoints(NightPass.PARK_AREA)
				local point = if #points > 0 then points[(plot.index - 1) % #points + 1] else nil
				local taken = occupiedPoints[NightPass.PARK_AREA] or {}
				if point ~= nil and taken[point] == nil then
					spawnAt(NightPass.PARK_AREA, point, "Common", nil, profile.collection).nightFor =
						player.UserId
				end
			elseif night and NightPass.nightCatOf(profile, nightCatch) then
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
				if
					profile.collection[stray.def.id] ~= nil
					and profile.collection[Catching.pickNewCat(
							"Common",
							TUTORIAL_AREA,
							0.5,
							profile.collection
						).id]
						== nil
				then
					-- #4188: a kind this beginner already has (a stray left at the point from before) goes, and the next
					-- tick brings one they lack in its place
					despawn(stray)
					continue
				end
				reserve(stray, player.UserId)
			end
			-- funnel steps first_stray_in_view and near_stray (easy-start.md section 5)
			if not M.Onboarding.reached(profile.telemetry, "near_stray") then
				if withinRange(player, stray.body.Position, NEAR_STRAY_STUDS) then
					Telemetry.onboarding(player, profile, "near_stray")
				elseif
					not M.Onboarding.reached(profile.telemetry, "first_stray_in_view")
					and withinRange(player, stray.body.Position, IN_VIEW_STUDS)
				then
					Telemetry.onboarding(player, profile, "first_stray_in_view")
				end
			end
		elseif strayId == nil then
			-- #4188: a kind the beginner lacks, so the tutorial ends on three kinds (the starter, this one, the bait cat)
			spawnAt(TUTORIAL_AREA, own, "Common", player.UserId, profile.collection)
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

-- #5533 (streetCats, shared/FreeStart): while a play first start save is in its first STREET_SECONDS of play, by day,
-- the Alleyway keeps STREET_COUNT Commons on its `near` points (the save's own point first, then the nearest free
-- ones, never another loaded player's own point), refilled each tick (5 s). Each is a kind the save lacks when it
-- can be. Its first EASY_CATCHES catches by hand, and its first EASY_CATCHES in the Park this session, are the easy
-- kind (Street.easy, in easyCatch). One table, as the module is short of locals.
local Street = {}
do
	local parkCaught: { [Player]: number } = {}

	function Street.tick()
		local on = M.LiveFlagService.on(M.FreeStart.STREET_FLAG)
		local day = M.ClockService.areasOpen()
		local near = tutorialPoints()
		local area = world.areas[TUTORIAL_AREA]
		local occupied = occupiedPoints[TUTORIAL_AREA] or {}
		local owned: { [number]: boolean } = {} -- near points of loaded players not on their street minutes
		local due: { { profile: Types.PlayerProfile, own: number? } } = {}
		for _, player in M.DataService.loadedPlayers() do
			local profile = M.DataService.get(player)
			local plot = M.PlotService.get(player)
			if profile == nil or plot == nil then
				continue
			end
			local own = near[plot.index]
			if
				on
				and day
				and M.FreeStart.active(profile.telemetry.freeStart, M.Economy.tier(profile))
				and M.FreeStart.streetDue(
					profile.telemetry.freeStart,
					M.PlayTime.seconds(player, profile)
				)
			then
				table.insert(due, { profile = profile, own = own })
			elseif own ~= nil then
				owned[own] = true
			end
		end
		if #due == 0 then
			-- nobody in their first minutes: the street's extra Commons go, unless held, dropped or reserved
			for _, stray in strays do
				if
					stray.street
					and stray.alive
					and stray.beginner == nil
					and stray.drop == nil
					and (stray.lockedBy == 0 or lockExpired(stray))
				then
					despawn(stray)
				end
			end
			return
		end
		local live = 0
		for _, index in near do
			local strayId = occupied[index]
			local stray = if strayId ~= nil then strays[strayId] else nil
			if stray ~= nil and stray.alive then
				live += 1
			end
		end
		local first = due[1]
		local from = if first.own ~= nil then area.spawnPoints[first.own].Position else nil
		local free: { number } = {}
		for _, index in near do
			if occupied[index] == nil and not owned[index] then
				table.insert(free, index)
			end
		end
		if from ~= nil then
			table.sort(free, function(a: number, b: number): boolean
				return (area.spawnPoints[a].Position - from).Magnitude
					< (area.spawnPoints[b].Position - from).Magnitude
			end)
		end
		local i = 1
		while live < M.FreeStart.STREET_COUNT and free[i] ~= nil do
			spawnAt(TUTORIAL_AREA, free[i], "Common", nil, first.profile.collection).street = true
			live += 1
			i += 1
		end
	end

	-- Whether `stray` is one of the save's easy first catches (shared/FreeStart.easyDue).
	function Street.easy(player: Player, profile: Types.PlayerProfile, stray: Stray): boolean
		local joined = profile.telemetry.freeStart
		if
			joined ~= true
			or not M.LiveFlagService.on(M.FreeStart.STREET_FLAG)
			or not M.FreeStart.active(joined, M.Economy.tier(profile))
		then
			return false
		end
		local park = stray.area == M.Tier3Path.AREA
		local done = if park then parkCaught[player] or 0 else SecondCat.caught(profile.stats)
		return M.FreeStart.easyDue(joined, done, stray.def.rarity, stray.variant, park)
	end

	function Street.caught(player: Player, area: string)
		if area == M.Tier3Path.AREA then
			parkCaught[player] = (parkCaught[player] or 0) + 1
		end
	end

	function Street.forget(player: Player)
		parkCaught[player] = nil
	end

	-- #5572 (picnicParty, Design's spec item 4): each player's picnic cats while their Picnic Party runs, by user id:
	-- the basket station's pivot, the cats to seat in order, how many are seated so far and the one on the blanket.
	-- One at a time: the next sits down a moment after the one before is caught. Not saved.
	Street.picnics = {} :: { [number]: Picnic }

	-- Seats picnic cat n + 1 for `userId`, when one is still to come.
	function Street.picnicSeat(userId: number)
		local picnic: Picnic? = Street.picnics[userId]
		if picnic == nil or picnic.stray ~= nil then
			return
		end
		local def: Types.CatDef? = picnic.defs[picnic.n + 1]
		local seat: CFrame? = M.PicnicSeats.seat(picnic.pivot, picnic.n + 1)
		if def == nil or seat == nil then
			return
		end
		picnic.n += 1
		local stray = spawnStray(def, M.Tier3Path.AREA, seat.Position, nil, nil, nil, nil, nil)
		stray.picnic = userId
		stray.mood = "Sleepy" -- curled up on the blanket
		stray.model:SetAttribute("Mood", "Sleepy")
		stray.model:SetAttribute("PicnicFor", userId)
		stray.model:SetAttribute("PicnicSeat", picnic.n)
		stray.model:PivotTo(seat)
		picnic.stray = stray
	end

	-- Takes `stray` away once nobody holds a catch on it.
	function Street.picnicGo(stray: Stray)
		task.spawn(function()
			while stray.alive and stray.lockedBy ~= 0 and not lockExpired(stray) do
				task.wait(0.5)
			end
			if stray.alive then
				despawn(stray)
			end
		end)
	end

	-- A picnic cat was caught (by its player; nobody else may start a catch on one).
	function Street.picnicCaught(player: Player, stray: Stray)
		if stray.picnic == nil then
			return
		end
		local picnic: Picnic? = Street.picnics[stray.picnic :: number]
		if picnic == nil or picnic.stray ~= stray then
			return
		end
		picnic.stray = nil
		player:SetAttribute("PicnicCat" .. picnic.n, true)
		Telemetry.custom(
			player,
			"picnic_cat_caught",
			picnic.n,
			{ tostring(stray.def.rarity), stray.def.id }
		)
		local userId = player.UserId
		local nextDef: Types.CatDef? = picnic.defs[picnic.n + 1]
		local line = M.PicnicParty.nextLine(
			if nextDef ~= nil then nextDef.rarity else nil,
			picnic.n + 1 == #picnic.defs
		)
		if line ~= nil and M.LiveFlagService.on(M.PicnicParty.FLOW_FLAG) then
			Net.toast(player, line, "good") -- #5707: what comes next, as the next cat sits down
		end
		task.delay(M.PicnicParty.CAT_NEXT_SECONDS, function()
			if Street.picnics[userId] == picnic then
				Street.picnicSeat(userId)
			end
		end)
	end

	-- The cats for a party: the first picnic (the save has not caught the named Park Rare yet) two Commons (the spec's
	-- Uncommon; the game has no such rarity) and that Rare; later ones two from the Park's normal table.
	function Street.picnicDefs(profile: Types.PlayerProfile): { Types.CatDef }
		local park = M.Tier3Path.AREA
		local named: Types.CatDef? = Catching.candidates("Rare", park)[1]
		if named ~= nil and profile.collection[named.id] == nil then
			return {
				Catching.pickCat("Common", park, rng:NextNumber()),
				Catching.pickCat("Common", park, rng:NextNumber()),
				named :: Types.CatDef,
			}
		end
		local areaDef = M.Catalog.getArea(park)
		local out: { Types.CatDef } = {}
		for _ = 1, 2 do
			local rarity: Types.Rarity = if areaDef ~= nil
				then Catching.pickRarity(areaDef.odds, rng:NextNumber())
				else "Common"
			table.insert(out, Catching.pickCat(rarity, park, rng:NextNumber()))
		end
		return out
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

	local function secondPad(areaId: string?): Vector3?
		local pad = M.Layout.landingPads[areaId or SecondCat.AREA]
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
		stray.home = SecondCat.leash(stray.home, pad, M.Config.StrayWanderRadius)
		if stray.mood ~= "Curious" or stray.curiousAt ~= nil then
			stray.mood = "Curious"
			stray.curiousAt = nil
			stray.model:SetAttribute("Mood", "Curious")
			stray.model:SetAttribute("CuriousAt", nil)
		end
		stray.model:SetAttribute("Napping", false) -- a Sleepy one gets up
	end

	-- Whether the stray can be the one that waits: on the Alleyway's floor (#5038: or `areaId`'s), nobody's catch,
	-- tutorial stray or waiting stray, not Dropped, walking home or running, and a plain Rare or below (SecondCat.fits).
	local function canWait(stray: Stray, now: number, areaId: string?): boolean
		if not stray.alive or stray.area ~= (areaId or SecondCat.AREA) then
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
		local plot = M.PlotService.get(player)
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
		if not SecondCat.waiting(profile) then
			return -- #5031: waiting for a Tier 2 cat (M.RankUpRightAway), not the second cat: no second cat steps
		end
		Second.step(player, profile, SecondCat.SHOWN)
		local root = rootPosition(player)
		local inAlley = root ~= nil and WorldBuilder.areaAt(world, root) == SecondCat.AREA
		-- onboarding_v9 (switch strayMeets): for a first catch by hand the stray walks over to stand by the landing
		if
			inAlley
			and M.LiveFlagService.on(M.StrayMeets.FLAG)
			and M.StrayMeets.due(SecondCat.caught(profile.stats))
		then
			local meet = M.StrayMeets.point(pad, waiting.home)
			if (meet - waiting.home).Magnitude > 0.5 then
				waiting.home = meet
			end
		end
		-- onboarding_v9's stray_marked counts only once the player stands in the Alleyway. The step_time above starts
		-- at the first customer served, still in town, so it logged stray_marked (and the cannon steps before it)
		-- before the flight and the drop showed at near_stray (Growth's read 2026-11-18)
		if
			inAlley
			and M.Onboarding.cleanWants(
				profile.telemetry.cleanV9Step or 0,
				M.Onboarding.CLEAN_EVENTS.strayMarked
			)
		then
			Telemetry.cleanEvent(player, profile, M.Onboarding.CLEAN_EVENTS.strayMarked)
		end
		if root ~= nil and SecondCat.followed(root, waiting.body.Position) then
			Second.step(player, profile, SecondCat.FOLLOWED)
			if
				M.Onboarding.cleanWants(
					profile.telemetry.cleanV9Step or 0,
					M.Onboarding.CLEAN_EVENTS.nearStray
				)
			then
				Telemetry.cleanEvent(player, profile, M.Onboarding.CLEAN_EVENTS.nearStray) -- #4504: near_stray_2
			end
		end
	end

	-- Whether the player's save waits for its second cat, or (#5031, switch rankUpRightAway) for the cat Tier 2 still
	-- needs after the first check-in (the bowl cat was let go)
	local function waitsForCat(profile: Types.PlayerProfile): boolean
		return SecondCat.waiting(profile)
			or M.RankUpRightAway.strayWaits(profile, M.LiveFlagService.on(M.RankUpRightAway.FLAG))
	end
	Second.waitsForCat = waitsForCat

	-- Whether the rule runs for the player now: their save waits for a cat (waitsForCat), the areas are open and their
	-- hands and Backpack are empty.
	local function secondCatDue(player: Player): Types.PlayerProfile?
		local profile = M.DataService.get(player)
		if
			profile == nil
			or not waitsForCat(profile)
			or carrying[player] ~= nil
			or packed[player] ~= nil
			or not M.ClockService.areasOpen()
		then
			return nil
		end
		return profile
	end

	-- #5038 (switch tier3Path, shared/Tier3Path): at Tier 2 a stray of a kind the player lacks (once the kinds are
	-- met, a Rare they lack) waits near the Park camp's landing, as the Alleyway's does. The nearest fitting free Park
	-- stray within Tier3Path.SEARCH_STUDS of the landing is theirs; with none, one of Tier3Path.spawnRarity and a kind
	-- they lack arrives at the Park's nearest free `near` point, at most once every Tier3Path.SPAWN_SECONDS.
	type ParkNeed = "kinds" | "rare" -- shared/Tier3Path.Need
	local parkSpawned: { [Player]: number } = {}

	-- #5487 (Derek 2026-11-19: "those cats with paws on top that only take one hit in park still exist remove that"):
	-- no Park stray waits any more (no gold paw badge, no one circle catch); tier3Path keeps its goal line and gift
	local PARK_WAITS = false
	local function parkNeed(player: Player): (Types.PlayerProfile?, ParkNeed?)
		local profile = M.DataService.get(player)
		if
			not PARK_WAITS
			or profile == nil
			or not M.LiveFlagService.on(M.Tier3Path.FLAG)
			or carrying[player] ~= nil
			or packed[player] ~= nil
			or not M.ClockService.areasOpen()
		then
			return nil, nil
		end
		return profile, M.Tier3Path.need(profile)
	end

	-- Sync's PC run of #5049: a waiting stray wedged against the Park gate's low wall and a pillar could not be netted
	-- on foot (the player stopped 7 studs off, up on the wall). A stray only waits where nothing solid stands within
	-- OPEN_STUDS of it above the floor: a wall, pillar, fence or prop that could keep the player away.
	local OPEN_STUDS = 6
	local function openSpot(stray: Stray): boolean
		local area = world.areas[stray.area]
		if area == nil then
			return false
		end
		local exclude: { Instance } = { stray.model }
		for _, player in Players:GetPlayers() do
			if player.Character ~= nil then
				table.insert(exclude, player.Character :: Model)
			end
		end
		return M.OpenSpot.clear(stray.body.Position, area.floorY, OPEN_STUDS, exclude)
	end

	local function pickPark(
		player: Player,
		profile: Types.PlayerProfile,
		pad: Vector3,
		need: ParkNeed
	): Stray?
		local now = serverNow()
		local best: Stray? = nil
		local bestDistance = math.huge
		for _, stray in strays do
			if
				canWait(stray, now, M.Tier3Path.AREA)
				and M.Tier3Path.fits(profile, stray.def, stray.variant, need)
				and openSpot(stray)
			then
				local at = stray.body.Position
				local distance = (Vector3.new(at.X, pad.Y, at.Z) - pad).Magnitude
				if distance <= M.Tier3Path.SEARCH_STUDS and distance < bestDistance then
					best, bestDistance = stray, distance
				end
			end
		end
		if best ~= nil then
			return best
		end
		local clock = os.clock()
		if clock - (parkSpawned[player] or -math.huge) < M.Tier3Path.SPAWN_SECONDS then
			return nil
		end
		local area = world.areas[M.Tier3Path.AREA]
		if area == nil then
			return nil
		end
		local occupied = occupiedPoints[M.Tier3Path.AREA] or {}
		local pick: number? = nil
		local pickDistance = math.huge
		for _, index in tutorialPoints(M.Tier3Path.AREA) do
			if occupied[index] == nil then
				local distance = (area.spawnPoints[index].Position - pad).Magnitude
				if distance < pickDistance then
					pick, pickDistance = index, distance
				end
			end
		end
		local rarity = M.Tier3Path.spawnRarity(profile, need)
		if pick == nil or rarity == nil then
			return nil
		end
		parkSpawned[player] = clock
		local stray =
			spawnAt(M.Tier3Path.AREA, pick, rarity :: Types.Rarity, nil, profile.collection)
		-- (a kind they lack, unless they own every one of that rarity: then it is just another stray)
		return if M.Tier3Path.fits(profile, stray.def, stray.variant, need) then stray else nil
	end

	local function parkFor(
		player: Player,
		profile: Types.PlayerProfile,
		stray: Stray?,
		pad: Vector3,
		need: ParkNeed
	)
		if stray ~= nil then
			return
		end
		local picked = pickPark(player, profile, pad, need)
		if picked == nil then
			return
		end
		waitFor(picked, player.UserId, pad)
		Telemetry.custom(player, "tier3_path", 1, { need :: string })
	end

	-- Whether a stray that waits for a player still waits for what they need now: the right area and, in the Park,
	-- a kind (or Rare) they still lack
	type Due = {
		player: Player,
		profile: Types.PlayerProfile,
		area: string,
		pad: Vector3,
		need: ParkNeed?,
	}
	local function stillFits(stray: Stray, entry: Due): boolean
		if stray.area ~= entry.area then
			return false
		end
		local need: ParkNeed? = entry.need
		return need == nil or M.Tier3Path.fits(entry.profile, stray.def, stray.variant, need)
	end

	function Second.tick()
		local alleyPad = secondPad()
		local parkPad = secondPad(M.Tier3Path.AREA)
		local due: { [number]: Due } = {}
		for _, player in M.DataService.loadedPlayers() do
			local profile = secondCatDue(player)
			if profile ~= nil and alleyPad ~= nil then
				due[player.UserId] = {
					player = player,
					profile = profile,
					area = SecondCat.AREA,
					pad = alleyPad,
					need = nil,
				}
			elseif parkPad ~= nil then
				local parkProfile, need = parkNeed(player)
				if parkProfile ~= nil and need ~= nil then
					due[player.UserId] = {
						player = player,
						profile = parkProfile,
						area = M.Tier3Path.AREA,
						pad = parkPad,
						need = need :: ParkNeed,
					}
				end
			end
		end
		local has: { [number]: Stray } = {}
		for _, stray in strays do
			local who = stray.waitsFor
			if who == nil then
				continue
			end
			local entry = due[who]
			if
				entry == nil
				or has[who] ~= nil
				or not stray.alive
				or stray.drop ~= nil
				or stray.returning
				or not stillFits(stray, entry)
			then
				waitFor(stray, nil)
			else
				has[who] = stray
			end
		end
		for userId, entry in due do
			if entry.need ~= nil then
				parkFor(entry.player, entry.profile, has[userId], entry.pad, entry.need :: ParkNeed)
			else
				secondCatFor(entry.player, entry.profile, has[userId], entry.pad)
			end
		end
	end

	-- #5038: the waiting Park stray's catch is the first catch's slow circle too (easyCatch)
	function Second.parkWaits(player: Player, profile: Types.PlayerProfile, stray: Stray): boolean
		return PARK_WAITS
			and stray.waitsFor == player.UserId
			and stray.area == M.Tier3Path.AREA
			and M.LiveFlagService.on(M.Tier3Path.FLAG)
			and M.Tier3Path.need(profile) ~= nil
	end

	-- #5652 (switch hoodWelcome, shared/HoodWelcome): on an account's first Neighbourhood landing from Tier 3 (their
	-- root within HoodWelcome.LANDED_STUDS of the camp's landing, by day), one stray of a Neighbourhood kind they lack
	-- comes to the free spawn point nearest the landing and keeps near it, as tier3Path's waiting stray did in the Park.
	-- Rarity: the area's odds over the rarities that still have a kind they lack (none when they own every kind). Its
	-- catch is the normal one for everyone. Marked had (stats.hoodWelcome) as it comes, so it comes once per account.
	function Second.hood()
		if not M.LiveFlagService.on(M.HoodWelcome.FLAG) or not M.ClockService.areasOpen() then
			return
		end
		local areaId = M.HoodWelcome.AREA
		local pad = secondPad(areaId)
		local area = world.areas[areaId]
		local areaDef = M.Catalog.getArea(areaId)
		if pad == nil or area == nil or areaDef == nil then
			return
		end
		for _, player in M.DataService.loadedPlayers() do
			local profile = M.DataService.get(player)
			local character = player.Character
			local root = if character ~= nil
				then character:FindFirstChild("HumanoidRootPart")
				else nil
			if
				profile == nil
				or root == nil
				or not root:IsA("BasePart")
				or not M.HoodWelcome.due(profile, true)
			then
				continue
			end
			local at = (root :: BasePart).Position
			if (Vector3.new(at.X, pad.Y, at.Z) - pad).Magnitude > M.HoodWelcome.LANDED_STUDS then
				continue
			end
			local stats = profile.stats :: any
			stats[M.HoodWelcome.STAT] = 1 -- once per account, whatever happens next
			local rarity =
				M.HoodWelcome.rarity(profile.collection, areaDef.odds :: any, rng:NextNumber())
			if rarity == nil then
				continue -- every Neighbourhood kind owned: nothing to welcome them with
			end
			local occupied = occupiedPoints[areaId] or {}
			local pick: number? = nil
			local pickDistance = math.huge
			for index, point in area.spawnPoints do
				if occupied[index] == nil then
					local distance = (point.Position - pad).Magnitude
					if distance < pickDistance then
						pick, pickDistance = index, distance
					end
				end
			end
			if pick == nil then
				continue
			end
			local stray = spawnAt(areaId, pick, rarity :: Types.Rarity, nil, profile.collection)
			stray.hoodFor = player.UserId
			stray.home = SecondCat.leash(stray.home, pad, M.Config.StrayWanderRadius)
			Net.toast(player, M.HoodWelcome.TOAST, "info")
			Telemetry.custom(player, "hood_welcome", 1, { "shown", stray.def.rarity })
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
		parkSpawned[player] = nil
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
		local someone: Player? = M.DataService.loadedPlayers()[1]
		if someone ~= nil then
			Telemetry.custom(someone, "wave_rare", 1, { areaDef.id, rerolled })
		end
	end
	table.sort(rarities, function(a, b)
		return M.Catalog.rarityRank[a] > M.Catalog.rarityRank[b]
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
	if not M.ClockService.areasOpen() then
		table.clear(topUpLeft)
		table.clear(entryLeft)
		return
	end
	local open: { [string]: number } = {}
	for _, player in M.DataService.loadedPlayers() do
		local profile = M.DataService.get(player)
		if profile ~= nil then
			local tier = M.Economy.tier(profile)
			for _, areaDef in M.Catalog.areas do
				if tier >= areaDef.tier then
					open[areaDef.id] = (open[areaDef.id] or 0) + 1
				end
			end
		end
	end
	for _, areaDef in M.Catalog.areas do
		if world.areas[areaDef.id] == nil then
			continue
		end
		local nearGate, live = nearGateCount(areaDef.id)
		local gateX = gateOf(areaDef.id)
		if gateX ~= nil and StrayTopUp.entryShort(nearGate, live, areaDef.entryFloor) then
			-- #1621: the start of the area gets its own quicker top-up
			local wait = (entryLeft[areaDef.id] or M.Config.StrayEntryTopUpSeconds) - dt
			if wait <= 0 then
				local rarity: Types.Rarity = Catching.pickRarity(areaDef.odds, rng:NextNumber())
				local point = freeSpawnPoint(areaDef.id, rarity, nil, true)
				if point ~= nil then
					spawnAt(areaDef.id, point, rarity)
					live += 1
				end
				wait = M.Config.StrayEntryTopUpSeconds
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

-- #4195 part 3, Cat Storm (shared/CatStorm): while an admin event's storm runs, by day, each area somebody has open
-- gets one more stray every CatStorm.gap seconds, rolled on the area's odds with the Mythical weight times the
-- storm's boost, until it has had CatStorm.total of them or holds too many already. The model carries
-- CatStorm.ATTRIBUTE for the client's falling streak. No area line for a storm's Mythical (the storm's own banner
-- says it; a Secret still gets its line from spawnAt). Each storm's strays are counted in `storm_strays` at its end.
local stormLeft: { [string]: number } = {} -- seconds until each area's next storm stray
local stormDropped: { [string]: number } = {} -- storm strays each area has had in this storm
local stormEndsAt: number? = nil -- the storm these belong to

local function stormOver()
	local dropped, mythical = 0, 0
	for key, count in stormDropped do
		if key == "Mythical" then
			mythical = count
		else
			dropped += count
		end
	end
	if dropped > 0 then
		local someone: Player? = M.DataService.loadedPlayers()[1]
		if someone ~= nil then
			Telemetry.custom(someone, "storm_strays", dropped, { tostring(mythical) })
		end
	end
	table.clear(stormLeft)
	table.clear(stormDropped)
	stormEndsAt = nil
end

local function stormTick(dt: number)
	local boost, startsAt, endsAt = EventService.catStorm()
	if boost == nil or startsAt == nil or endsAt == nil then
		if stormEndsAt ~= nil then
			stormOver()
		end
		return
	end
	if stormEndsAt ~= endsAt then
		if stormEndsAt ~= nil then
			stormOver()
		end
		stormEndsAt = endsAt
	end
	if not M.ClockService.areasOpen() then
		return -- the areas are closed at night; the storm picks up at sunrise
	end
	local open: { [string]: boolean } = {}
	for _, player in M.DataService.loadedPlayers() do
		local profile = M.DataService.get(player)
		if profile ~= nil then
			local tier = M.Economy.tier(profile)
			for _, areaDef in M.Catalog.areas do
				if tier >= areaDef.tier then
					open[areaDef.id] = true
				end
			end
		end
	end
	local count = #M.Catalog.areas
	for index, areaDef in M.Catalog.areas do
		local id = areaDef.id
		if world.areas[id] == nil or not open[id] then
			continue
		end
		local gap = CatStorm.gap(endsAt - startsAt, areaDef.waveSize)
		local left = (stormLeft[id] or CatStorm.offset(index, count, gap)) - dt
		if left <= 0 then
			left = gap
			local had = stormDropped[id] or 0
			if
				had < CatStorm.total(areaDef.waveSize)
				and CatStorm.room(countStrays(id), areaDef.waveSize)
			then
				local rarity: Types.Rarity =
					Catching.pickRarity(CatStorm.odds(areaDef.odds, boost), rng:NextNumber())
				local point = freeSpawnPoint(id, rarity)
				if point ~= nil then
					local stray = spawnAt(id, point, rarity)
					stray.model:SetAttribute(CatStorm.ATTRIBUTE, true)
					stormDropped[id] = had + 1
					if stray.def.rarity == "Mythical" then
						stormDropped.Mythical = (stormDropped.Mythical or 0) + 1
					end
				end
			end
		end
		stormLeft[id] = left
	end
end

-- #4197 Secret Hunt (shared/CafeEvents ADMIN_KINDS.hunt): while the admin event runs, by day, its Secret strays come
-- out one a second in random areas somebody has open, each with a Secret's own area line, until the hunt has
-- `count` of them. Whoever catches one keeps it as any Secret. One gone at dusk comes back at sunrise while the hunt
-- runs. When all are caught every player here gets ADMIN.huntFish golden fish, once. EventService publishes the
-- count caught as the effects' `secretFound` (the bar's "1/3"). Its strays carry HUNT_ATTRIBUTE; ones still out at
-- the end stay until dusk like any Secret. Only while the `secretCats` switch is on.
local HUNT_ATTRIBUTE = "HuntCat"

huntGone = function(stray: Stray, catcher: Player?)
	local running = hunt :: Hunt
	running.ids[stray.id] = nil
	if catcher == nil then
		running.spawned -= 1 -- gone at dusk: out again at sunrise
		return
	end
	running.found += 1
	EventService.setHuntFound(running.id, running.found)
	Telemetry.custom(catcher, "secret_hunt_found", running.found, { running.id })
	if running.found < running.count or running.paid then
		return
	end
	running.paid = true
	local fish = CafeEvents.ADMIN.huntFish
	for _, player in M.DataService.loadedPlayers() do
		local profile = M.DataService.get(player)
		if profile ~= nil then
			M.GoldenFish.credit(profile, fish)
			Telemetry.fishSource(player, profile, fish, "TimedReward", "secret_hunt")
			M.CafeService.sync(player)
			Net.toast(
				player,
				string.format("All %d Secret cats found! +%d golden fish", running.count, fish),
				"good"
			)
		end
	end
end

local function huntTick()
	local id, count = EventService.secretHunt()
	if id == nil then
		hunt = nil
		return
	end
	local running = hunt
	if running == nil or running.id ~= id then
		running = { id = id, count = count, spawned = 0, found = 0, paid = false, ids = {} }
		hunt = running
		EventService.setHuntFound(id, 0)
	end
	assert(running ~= nil, "secret hunt run")
	if
		running.spawned >= running.count
		or not M.ClockService.areasOpen()
		or #M.Catalog.secretCats == 0
	then
		return
	end
	-- #4221: each area hides only its own Secret, so the hunt picks among the open areas that have one and spawns
	-- that area's Secret there (the secretAreas switch is retired, #4656)
	local own: { [string]: { Types.CatDef } } = {}
	for _, secretDef in M.Catalog.secretCats do
		local home = secretDef.secretArea
		if home ~= nil then
			local list = own[home] or {}
			table.insert(list, secretDef)
			own[home] = list
		end
	end
	local open: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, player in M.DataService.loadedPlayers() do
		local profile = M.DataService.get(player)
		if profile ~= nil then
			local tier = M.Economy.tier(profile)
			for _, areaDef in M.Catalog.areas do
				if
					tier >= areaDef.tier
					and not seen[areaDef.id]
					and world.areas[areaDef.id] ~= nil
					and own[areaDef.id] ~= nil
				then
					seen[areaDef.id] = true
					table.insert(open, areaDef.id)
				end
			end
		end
	end
	if #open == 0 then
		return
	end
	local areaId = open[rng:NextInteger(1, #open)]
	local point = freeSpawnPoint(areaId, "Mythical")
	if point == nil then
		return -- that area is full; another next second
	end
	local choices: { Types.CatDef } = own[areaId]
	local def = choices[rng:NextInteger(1, #choices)]
	local stray = spawnStray(def, areaId, world.areas[areaId].spawnPoints[point].Position, point)
	stray.model:SetAttribute(HUNT_ATTRIBUTE, true)
	running.ids[stray.id] = true
	running.spawned += 1
	secretSpawned(stray, "hunt")
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
	local model = M.AssetRegistry.cloneCat(carry.def.id, carry.variant)
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
	carry.rushUntil = now + M.Config.CatchRushSeconds
	character:SetAttribute("RushUntil", carry.rushUntil)
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid?
	if humanoid ~= nil then
		setSpeed(player, humanoid, M.Config.CatchRushWalkSpeed)
	end
	task.delay(M.Config.CatchRushSeconds, function()
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
	local profile = M.DataService.get(player)
	return profile ~= nil and profile.mystery.backpack == true
end

-- #3699: the worn Backpack in its owner's two colour picks (the built colours with the switch off or nothing picked).
-- The server colours the parts, so every player sees them.
local function tintBackpack(player: Player)
	local character = player.Character
	local pack = if character ~= nil then HeldCat.pack(character) else nil
	local profile = M.DataService.get(player)
	if pack == nil or profile == nil then
		return
	end
	local picked = profile.bagColours
	M.BagColours.tint(pack, M.BagColours.picks(picked))
end

-- #2719: the Backpack's owner wears it (HeldCat.wearPack), at spawn and after the buy; every player sees it.
local function wearBackpack(player: Player)
	local character = player.Character
	if
		character == nil
		or not hasBackpack(player)
		or HeldCat.pack(character) ~= nil
		or not M.AssetRegistry.has(HeldCat.PACK_ASSET)
	then
		return
	end
	local pack = M.AssetRegistry.clone(HeldCat.PACK_ASSET)
	if HeldCat.wearPack(pack, character) then
		pack.Parent = character
		tintBackpack(player) -- #3699
	else
		pack:Destroy()
	end
end

-- #4049: the worn Speed Shoes in their owner's two colour picks (the built colours with nothing picked). The server colours the parts, so every player sees them.
local function tintShoes(player: Player, worn: Instance?)
	local character = player.Character
	local folder = worn
		or (if character ~= nil then character:FindFirstChild(SpeedShoes.WORN) else nil)
	local profile = M.DataService.get(player)
	if folder == nil or profile == nil then
		return
	end
	M.BagColours.tint(folder, M.BagColours.picks(profile.shoeColours, "shoes"), "shoes")
end

-- #4050: the Speed Shoes' owner wears them (SpeedShoes.wear), at spawn, after the buy and whenever they came off
-- (keepBackpack's check); every player sees them. Without them, none.
-- #4878: Speed Rush no longer lends a pair (it adds walk speed, pawsBonus); a pair it lent before comes off at its end.
local function keepShoes(player: Player)
	local character = player.Character
	if character == nil or character.Parent == nil then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return
	end
	local want = SpeedShoes.owns(M.DataService.get(player))
	local old = character:FindFirstChild(SpeedShoes.WORN)
	if old ~= nil and want and SpeedShoes.onFeet(old, character) then
		return
	end
	if old ~= nil then
		old:Destroy()
	end
	if want and M.AssetRegistry.has(SpeedShoes.ASSET) then
		local folder = SpeedShoes.wear(M.AssetRegistry.clone(SpeedShoes.ASSET), character)
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
	local model = M.AssetRegistry.cloneCat(carry.def.id, carry.variant)
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
		M.CafeService.setCarrying(player, carry.def.id)
	end
	return true
end

-- #3145: after a quiet unpack whose put-down did not happen: the cat is in the hands after all, so the client hears.
local function sayHeld(player: Player)
	local carry = carrying[player]
	if carry ~= nil and M.CafeService.carrying(player) ~= carry.def.id then
		M.CafeService.setCarrying(player, carry.def.id)
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
	pity: boolean?,
	perfect: boolean?
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
		local profile = M.DataService.get(player)
		if profile ~= nil and SecondCat.waiting(profile) then
			Second.step(player, profile, SecondCat.CAUGHT)
		end
		if profile ~= nil and method == "net" then
			Telemetry.cleanEvent(player, profile, M.Onboarding.CLEAN_EVENTS.netCatch) -- #4504: second_net_catch
		end
		-- #3035: a first-session Tier 1 player's first night catch of the session (Research-Agent: do they use it)
		if
			profile ~= nil
			and not M.ClockService.areasOpen()
			and NightPass.firstOf(profile, M.LiveFlagService.on(NightPass.FLAG))
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
		perfect = if perfect == true then true else nil,
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
	M.CafeService.setCarrying(player, def.id)
	local profile = M.DataService.get(player)
	if profile ~= nil then
		-- a catch is out in an area: first_catch implies the alley step when TutorialAdvance 1 never came (#1273)
		if not M.Onboarding.reached(profile.telemetry, "first_catch") then
			local tries = if method == "rescue"
				then profile.stats.rescueAttempts
				else profile.stats.grabsAttempted
			Telemetry.custom(player, "first_catch_tries", math.max(1, tries), {
				if method == "rescue" then "rescue" else "net",
			})
			Telemetry.onboarding(player, profile, "first_catch")
			-- #1273: still holding it CARRY_STEP_SECONDS later (a check-in sooner implies the step)
			task.delay(CARRY_STEP_SECONDS, function()
				local current = M.DataService.get(player)
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
	M.CafeService.setCarrying(player, nil)
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
	-- #4601: the sprint takes over from any walk still running, so two walks never move the cat at once
	stray.walk += 1
	local walk = stray.walk
	task.spawn(function()
		Mover.walkTo(stray.model, target, M.Config.StrayFleeSpeed, function()
			return stray.alive and stray.lockedBy == 0 and stray.walk == walk
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
	local ends = serverNow() + M.Config.StartledSeconds
	startledUntil[player] = ends
	character:SetAttribute("StartledUntil", ends)
	CatService.refreshSpeed(player)
	task.delay(M.Config.StartledSeconds, function()
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
local function freeCatch(player: Player, profile: Types.PlayerProfile): boolean
	return FreeCatch.applies(
		M.LiveFlagService.on(FreeCatch.FLAG),
		Telemetry.device(player),
		M.Economy.tier(profile)
	)
end

local function easyCatch(player: Player, profile: Types.PlayerProfile, stray: Stray): boolean
	-- Derek 2026-11-20 21:16 UTC ("the one cat in park area still has the slow catch that lets you one shot catch
	-- them remove that", "happens multiple times inside park now"): with the switch parkCatchNormal on, no Park cat
	-- gets the slow first catch circle, picnic cats included
	local parkNormal = stray.area == M.Tier3Path.AREA and M.LiveFlagService.on("parkCatchNormal")
	if stray.picnic == player.UserId and not parkNormal then
		return true -- #5572: a picnic cat cannot be lost
	end
	if stray.waitsFor == player.UserId and Second.waitsForCat(profile) then
		return true
	end
	if Second.parkWaits(player, profile, stray) then
		return true -- #5038
	end
	if not parkNormal and Street.easy(player, profile, stray) then
		return true -- #5533 streetCats
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
	-- Derek 2026-11-14 (#4307): every catch on a phone, tablet or console below Tier 2 (shared/FreeCatch)
	if freeCatch(player, profile) then
		return true
	end
	-- #3181: another beginner's tutorial stray too, now that anyone may catch one
	return profile.tutorialStep < M.Config.TutorialGuaranteedStrayStep
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
		serverNow() + M.Config.TutorialRetrySeconds,
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
	task.delay(M.Config.TutorialRetrySeconds, function()
		local profile = M.DataService.get(player)
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
	local profile = M.DataService.get(player)
	if profile == nil or player.Parent ~= Players then
		setLock(stray, 0)
		return -- the leaving player's lost catch is logged by PlayerRemoving
	end
	Circles.expire(attempt, serverNow())
	recordCircles(player, profile, attempt)
	-- Walking out of range, or finishing a rescue mid-catch (reviewer S21: the carried cat wins), is a Miss, so
	-- stepping away before a hard circle never dodges the cost (reviewer S33).
	local forfeit: string? = nil
	if carrying[player] ~= nil then
		forfeit = "Check in the cat you are carrying first"
	elseif not withinRange(player, stray.body.Position, catchRange()) then
		forfeit = "Too far away"
	end
	local succeeded = forfeit == nil and Circles.succeeded(attempt)
	local pitySlot = stray.model:GetAttribute(M.Pity.SLOT_ATTRIBUTE)
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
			stray.attempt = attempt -- #5500: so the log counts the rings
			lostCatch(player, stray, "pity_lost")
			stray.attempt = nil
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
		M.Badges.noteFinish(profile.stats, finishKind == "purrfect" and not profile.flags.autoPress)
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
		{ rarity, tostring(M.Economy.level(profile, "net")), result }
	)
	if not succeeded then
		Telemetry.startMiss(player, profile, stray.area) -- #5551
		stray.attempt = attempt -- #5500: so the log counts the rings
		lostCatch(
			player,
			stray,
			M.CatchLost.missReason(
				if forfeit == nil
					then nil
					elseif carrying[player] ~= nil then "carrying"
					else "too_far",
				Circles.firstMiss(attempt)
			)
		)
		stray.attempt = nil
	end

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
		local recaught = stray.recaught -- #4251: a let go cat that walked home pays no Harvest pumpkins twice
		-- #1181 (corner-shop-v2.md section 3): 1 in CatchSnackChance a stray's net catch drops a Small Snack, never a
		-- Dropped or re-caught cat's, so shoving and catching one cat again cannot farm them
		local dropsSnack = stray.drop == nil
			and not stray.recaught
			and snackRandom:NextNumber() < M.Config.CatchSnackChance
		despawn(stray, player)
		local bonusXp = if finishKind == "purrfect" and not profile.flags.autoPress
			then M.Config.CatXpBase
			else nil
		-- #5300: every ring Perfect (not while AutoPress is set) marks the cat while the perfectCatch switch is on.
		-- #5379 (Derek 2026-11-19: "even when getting all perfect circles it sometimes doesnt give the perfect
		-- bonus"): a good player who lands over 95% Perfect across 50 rings gets the scripted-press flag, which held
		-- the mark back until they fell under 85%. With perfectFlagged on the flag no longer blocks the mark; it
		-- still holds back the charm, the bonus XP and the badge count.
		local flagBlocks = profile.flags.autoPress
			and not M.LiveFlagService.on(PerfectCatch.FLAGGED_FLAG)
		local perfectMark = M.LiveFlagService.on(PerfectCatch.FLAG)
			and (PerfectCatch.marks(finishKind, flagBlocks) or stray.perfect == true)
		startCarry(
			player,
			def,
			method,
			charm,
			variant,
			nil,
			funnel,
			homePos,
			knocks,
			bonusXp,
			pity,
			perfectMark
		)
		if waitedFor ~= nil and waitedFor ~= player.UserId then
			-- #3181: the beginner it waited for gets a new one at their point now, not at the next 5 s tick
			task.defer(tutorialTick)
		end
		if dropsSnack then
			local paid =
				M.Payout.pay(player, profile, { catFood = { small_cat_snack = 1 } }, "catch_snack")
			if #paid > 0 then
				Net.toast(player, "The cat dropped a snack: " .. paid[1] .. " in your Bag", "good")
			end
		end
		if area == "park" then
			Telemetry.onboarding(player, profile, "first_park_catch")
		end
		Street.caught(player, area) -- #5533 streetCats
		Street.picnicCaught(player, stray) -- #5572
		if stray.hoodFor ~= nil and stray.hoodFor == player.UserId then
			stray.hoodFor = nil
			Telemetry.custom(player, "hood_welcome", 1, { "caught", def.rarity }) -- #5652
		end
		if M.Catalog.getArea(area) ~= nil then
			Telemetry.caughtIn(player, profile, area) -- #3695: the clean funnel's area steps (the ten areas)
		end
		if not recaught then
			for _, hook in M.caughtHooks do
				task.spawn(hook, player, def, area)
			end
		end
		local home = M.homeFromCampless
		if home ~= nil then
			home(player, area)
		end
		return
	end

	-- #4815 (Derek 2026-11-16): in the walk-through (Tier 1) a missed catch never scares the cat either: it stays put
	-- with no sprint or wait, as a beginner's tutorial stray does
	local easy = easyCatch(player, profile, stray)
	-- #5496 (parkFirstCalm): on a phone, tablet or console a Park miss leaves the cat put until the first Park catch
	local parkCalm = M.ParkFirstEasy.calm(
		stray.area,
		M.Onboarding.reached(profile.telemetry, "first_park_catch"), -- ParkFirstEasy.STEP
		Telemetry.device(player),
		M.LiveFlagService.on(M.ParkFirstEasy.CALM_FLAG)
	)
	-- #5500 (missKeepsCommon, plan A fix 2): a missed Common, in any area on any device, stays put with no bolt, slow
	-- or wait; the Perfect bonus is lost with the catch. Rares and up keep the chase
	local commonCalm = rarity == "Common" and M.LiveFlagService.on("missKeepsCommon")
	-- #5707 picnicFlow: a missed picnic cat stays on its seat, its circles as hard as any Park cat's
	local picnicCalm = stray.picnic == player.UserId
		and M.LiveFlagService.on(M.PicnicParty.FLOW_FLAG)
	if easy or parkCalm or commonCalm or picnicCalm or NetSwing.calm(M.Economy.tier(profile)) then
		if not easy then
			-- a Tier 1 miss that would have bolted before, so the bolt read can tell the two apart
			Telemetry.custom(
				player,
				"catch_finish",
				#attempt.grades,
				{ "calm_miss", rarity, stray.mood }
			)
		end
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
		perfect = carry.perfect,
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
	if campBlocks(player) then
		return "Step out of the camp to catch it"
	end
	if not areaUnlocked(profile, stray.area) then
		return "This area opens at a higher tier. Rank up to catch cats here"
	end
	if not openFor(profile) then
		-- a stray still waiting out someone's catch at dusk (v0.9, F66); #2692: not for a night pass
		return M.Clock.CLOSED_TEXT
	end
	if stray.lockedBy ~= 0 and not lockExpired(stray) then
		-- busy, including the player's own catch in progress: a second start never restarts the circles
		return if stray.lockedBy == player.UserId
			then "Keep going, the circles are coming"
			else "Someone else is catching it"
	end
	if stray.picnic ~= nil and stray.picnic ~= player.UserId then
		return "That cat is at someone's picnic" -- #5572
	end
	if not withinRange(player, stray.body.Position, catchRange()) then
		return "Too far away"
	end
	local now = serverNow()
	if now < stray.fleeingUntil then
		return "It's running!"
	end
	local selfRetryAt = stray.selfRetryAt[player.UserId]
	if selfRetryAt ~= nil and now < selfRetryAt then
		return M.Cooldown.text(selfRetryAt - now) -- #2324
	end
	local last = lastCatchStart[player]
	if last ~= nil and now - last < M.Config.GrabCooldownSeconds then
		return "Give it a moment"
	end
	-- One catch at a time: a script must not run circles on two strays at once.
	if holdsCatch(player) then
		return "Finish this catch first"
	end
	lastCatchStart[player] = now

	-- a Steady Paw Potion running now plays the circles of the next net level (F64)
	local netLevel = M.Potions.netLevel(profile, M.Economy.level(profile, "net"), os.time())
	local function roll(): number
		return rng:NextNumber()
	end
	-- F87: a beginner's own tutorial stray is one slow circle with doubled bands (easy-start.md section 2b)
	local tutorial = easyCatch(player, profile, stray) -- #2774: any rarity, until the first check-in
	local dragonFx = M.DragonKeep.of(profile) -- #4447: Quick Paws and Steady Claw
	-- F83: the rarer the cat, the narrower its bands; CatchSchedule sends these, so the client draws the real ones
	-- #5392 (catchCurve): one smooth curve by net, area tier and coat, in place of NetWindows, catchWindowScale and
	-- QuickRing; the early, touch and Park scales, slow rings and potions stay on top
	local curve = not tutorial and M.LiveFlagService.on(CATCH_CURVE_FLAG)
	local windows = if tutorial
		then Circles.tutorialWindows(netLevel)
		-- #2322: wider in the first area; #3135: a little narrower for a gold or rainbow coat
		-- #2913 follow-up: a little wider for a player's first few catches by hand
		else Circles.scaled(
			if curve
				then Circles.curveWindows(netLevel, stray.def.rarity, stray.area, stray.variant)
				else Circles.windowsFor(netLevel, stray.def.rarity, stray.area, stray.variant),
			-- #4299: or wider on a phone or tablet, whichever is wider
			math.max(
				Circles.earlyScale(SecondCat.caught(profile.stats)),
				Circles.touchScale(Telemetry.device(player), true) -- #4654: touchCatchReach shipped
			)
				-- #5182 (parkFirstEasy): the Park keeps the Alleyway's width until the first Park catch
				* M.ParkFirstEasy.scale(
					stray.area,
					M.Onboarding.reached(profile.telemetry, "first_park_catch"), -- ParkFirstEasy.STEP
					M.LiveFlagService.on(M.ParkFirstEasy.FLAG)
				)
		)
	-- #5601 (steadySoft, Derek 2026-11-20: "the potion that makes circle radius bigger is a little too strong"): a
	-- Steady Paw Potion's bands go Potions.STEADY_SOFT of the way from the save's own net to the next, not all of it
	if not tutorial and M.LiveFlagService.on(M.Potions.STEADY_SOFT_FLAG) then
		local own = M.Economy.level(profile, "net")
		if netLevel > own then
			local function base(level: number): Types.NetWindows
				return if curve
					then Circles.curveWindows(level, stray.def.rarity, stray.area, stray.variant)
					else Circles.windowsFor(level, stray.def.rarity, stray.area, stray.variant)
			end
			windows = M.Potions.steadySoften(windows, base(netLevel), base(own))
		end
	end
	if curve then
		windows = Circles.capped(windows)
	end
	-- #2920: a player's very first catch holds its ring on the target until the press
	-- #3662: the first catch by hand, which a bowl cat in the cafe no longer uses up
	-- Derek 2026-11-14: and every free catch on a phone, tablet or console below Tier 2 (shared/FreeCatch)
	local hold = tutorial
		and M.Config.CatchHoldFirstRing
		and (SecondCat.caught(profile.stats) == 0 or freeCatch(player, profile))
	local circles: { Types.CatchCircle } = if tutorial -- typed: luau-lsp cannot iterate the if's union (#4814)
		then Circles.tutorialSchedule(
			now,
			roll,
			hold,
			M.LiveFlagService.on(Circles.QUICK_FIRST_FLAG) -- #5232: held rings shrink in 0.7 s
		)
		else Circles.schedule(
			stray.def.rarity,
			netLevel,
			now,
			roll,
			stray.area,
			dragonFx.slowRings,
			if curve then Circles.curveSpeed(stray.def.rarity, stray.area, stray.variant) else nil
		) -- #3140, #4447, #5392
	-- #4814 (Derek 2026-11-16): the first catch by hand ignores every press before its ring is in the Good band
	if SecondCat.caught(profile.stats) == 0 then
		for _, circle in circles do
			circle.noEarly = true
		end
	end
	-- #1884 (catch-rework.md 7b): the trust bar; the tutorial stray's one ring catches on a Good or Perfect
	-- #1884 (7a): a swing landing just as a Curious cat walks up starts with CuriousTrustBonus more
	local trust = if tutorial
		then Circles.tutorialTrust(#circles) -- #4845: a held first catch runs 3 rings and lands on the last
		else Circles.trustFor(stray.def.rarity, M.Moods.trustBonus(stray.curiousAt, now))
	-- #5170 (netTiers): the owned net level cuts the Perfect hits, never under two (a potion widens windows only)
	if not tutorial and M.LiveFlagService.on(M.NetTiers.FLAG) then
		trust.start += M.NetTiers.trustBonus(
			M.Economy.level(profile, "net"),
			trust.start,
			trust.need
		)
	end
	local attempt = Circles.newAttempt(circles, windows, trust, not tutorial and dragonFx.forgive)
	-- #5392: a bigger Perfect from a better net, more so in the first areas; the client's bar reads the attribute
	attempt.perfectGain = if curve
		then Circles.perfectGain(netLevel, stray.area, trust.start, trust.need)
		else nil
	player:SetAttribute(CATCH_PERFECT_ATTRIBUTE, attempt.perfectGain)
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
	local pitySlot = stray.model:GetAttribute(M.Pity.SLOT_ATTRIBUTE)
	if type(pitySlot) == "number" and pityStarted ~= nil then
		pityStarted(player, pitySlot) -- #2796
	end
	-- a catch starts in reach of a stray, so catch_started implies near_stray when the tutorial stray was never the one
	-- (a player who caught another cat first would hold every later step behind it)
	Telemetry.onboarding(player, profile, "catch_started")
	-- #5551 first_five_v1: the first swing, then the first Park swing once at Tier 2
	Telemetry.firstFive(
		player,
		profile,
		if stray.area == M.Tier3Path.AREA and M.Economy.tier(profile) >= 2
			then "park_catch_started"
			else "catch_started"
	)
	Telemetry.cleanEvent(player, profile, M.Onboarding.CLEAN_EVENTS.catchStart) -- #4504: catch_2_started

	-- A circle nobody presses is a Miss at its deadline (#1884: trust lost, and the catch ends only if the cat bolts);
	-- walking out of range ends it.
	task.spawn(function()
		while stray.attempt == attempt do
			local deadline = Circles.nextDeadline(attempt)
			if deadline == nil then
				return
			end
			-- #4597: a tap made before the deadline may still be on its way, so wait CatchPressStampSeconds more
			local grace = M.Config.CatchPressStampSeconds
			task.wait(math.max(0, deadline + grace - serverNow()) + 0.05)
			if stray.attempt ~= attempt then
				return
			end
			local before = attempt.nextIndex
			Circles.expire(attempt, serverNow() - grace)
			sendJudged(player, stray.id, attempt, before)
			if
				Circles.isDone(attempt)
				or not withinRange(player, stray.body.Position, catchRange())
			then
				finishCatch(player, stray, attempt)
				return
			end
		end
	end)
	-- Whatever happens, the lock never outlives its schedule.
	task.delay(math.max(0, stray.lockUntil - now) + 0.05, function()
		if stray.alive and stray.lockedBy == player.UserId and lockExpired(stray) then
			if stray.attempt == attempt then
				lostCatch(player, stray, "timeout") -- #5500
			end
			setLock(stray, 0)
		end
	end)
	return nil
end

-- One press for circle `index`. #4597: the client sends its own tap time (`rawStamp`, the ring clock), believed up to
-- CatchPressStampSeconds before the arrival (Circles.pressTime); with none, the press is stamped on arrival and half
-- the player's ping (capped) is taken off. Out-of-order, repeated and early presses are ignored (Circles.press). A Miss or the
-- last circle ends the catch at once.
local function onCatchPress(
	player: Player,
	rawStrayId: unknown,
	rawIndex: unknown,
	rawStamp: unknown
)
	local strayId = M.Guard.id(rawStrayId)
	local index = M.Guard.int(rawIndex, 1, MAX_CIRCLES)
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
	-- #4597: the tap's own time when the client sent one (held to a short bound), else arrival less half the ping
	local pressTime = Circles.pressTime(arrival, player:GetNetworkPing(), rawStamp)
	local before = attempt.nextIndex
	if before == 1 then
		local pressed = M.DataService.get(player)
		if pressed ~= nil then
			Telemetry.firstFive(player, pressed, "ring_try") -- #5551: the first ring press
		end
	end
	Circles.press(attempt, index, pressTime, arrival)
	-- #1727: the server's grade at once, so a device that guessed Miss on an edge press (S101) shows the rest
	sendJudged(player, strayId, attempt, before)
	for judged = before, attempt.nextIndex - 1 do
		logCircle(player, strayId, attempt, judged)
		local grade = attempt.grades[judged]
		if grade == "good" or grade == "perfect" then
			local profile = M.DataService.get(player)
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
	local perfect = stray.perfect == true -- #5300: the mark rides with the cat
	despawn(stray, player) -- logs drop_outcome against the player who ended up with it
	local area = stray.area
	startCarry(player, def, method, charm, variant, true, nil, homePos, knocks, nil, pity, perfect)
	local home = M.homeFromCampless
	if home ~= nil then
		home(player, area)
	end
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
		Mover.walkTo(stray.model, target, M.Config.StrayFleeSpeed, function()
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

-- #4255 follow-up (SecretCalm rule 1): whether a stray may hop away from `player`; only a Secret is capped.
local function secretMayHop(stray: Stray, player: Player): boolean
	local hops = stray.secretHops[player.UserId]
	return stray.def.rarity ~= M.Catalog.SECRET or SecretCalm.mayHop(hops)
end

local function countSecretHop(stray: Stray, player: Player)
	if stray.def.rarity == M.Catalog.SECRET then
		stray.secretHops[player.UserId] = (stray.secretHops[player.UserId] or 0) + 1
	end
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
	local profile = M.DataService.get(player)
	return {
		cooldown = if profile ~= nil then NetSwing.cooldownFor(profile) else nil, -- #4447: Ember Net
		carrying = carrying[player] ~= nil,
		busy = holdsCatch(player) or inRescue(player),
		inFlight = inFlight(player),
		inCamp = campBlocks(player), -- #5676: not by the player's own picnic blanket
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
	local profile = M.DataService.get(player)
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
	local picked = NetSwing.pick(origin, look, targets, NetSwing.extraForProfile(profile)) -- #2565, #4447
	-- #2774: a beginner's swing near their own tutorial stray lands on it whichever way they face
	if picked == nil and profile.tutorialStep < M.Config.TutorialGuaranteedStrayStep then
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
	elseif near > 0 and NetSwing.missHops(profile.tutorialStep, M.Economy.tier(profile)) then
		for _, other in strays do
			if
				hoppable(other, player, now)
				and NetSwing.nearMiss(origin, other.body.Position)
				and secretMayHop(other, player)
			then
				hop(other, player)
				countSecretHop(other, player)
			end
		end
	end
	announceSwing(player, origin, started)
	Telemetry.netSwing(player, NetSwing.result(stray ~= nil, near), M.Economy.level(profile, "net"))
end

-- SwingNet() (F93): no arguments; one per NetSwingCooldown (the limiter in Net is the flood guard). The swing is
-- judged when the net lands, NetSmackDelay from now. A refused swing gets no answer: the client checks the same
-- before it plays the smack.
local function onSwingNet(player: Player)
	if M.DataService.get(player) == nil then
		return
	end
	if NetSwing.refusal(swingCheck(player)) ~= nil then
		return
	end
	lastSwing[player] = serverNow()
	task.delay(M.Config.NetSmackDelay, landSwing, player)
end

-- Adds the cat to the player's cafe and, with `notify`, tells them and the server (CatCaught, the shout-out). The
-- carry has already ended, or never began: dusk checks a Dropped stray in for its last carrier this way.
local function checkIn(player: Player, carry: Carry, notify: boolean, profile: Types.PlayerProfile?)
	local def = carry.def
	-- F89: whether the collection held an Epic or better before this cat, for the first Epic's card
	local before = profile or M.DataService.get(player)
	local hadEpicOrBetter = before ~= nil and M.RareMoments.ownsEpicOrBetter(before.collection)
	local instance, isNew = M.CafeService.addCaughtCat(
		player,
		def,
		notify,
		profile,
		carry.charm,
		carry.method,
		carry.variant,
		carry.perfect
	)
	local bonusXp = carry.bonusXp
	if bonusXp ~= nil and bonusXp > 0 then
		M.CatStats.addXp(instance, bonusXp) -- #1884: a PURRFECT catch joins a level up (CatXpBase is level 2)
	end
	if notify then
		local current = M.DataService.get(player)
		if current ~= nil then
			Telemetry.onboarding(player, current, "first_checkin")
		end
		if carry.funnel ~= nil then
			Telemetry.catchCheckedIn(player, carry.funnel, instance.uid, instance.spotId ~= nil)
		end
		Net.fire(player, "CatCaught", def.id, isNew, instance.variant)
		-- #4447: the Dragon Keep's Double Catch, a plain second copy that joins quietly with its own toast
		local keeper = M.DataService.get(player)
		if
			keeper ~= nil
			and M.DragonKeep.bringsFriend(M.DragonKeep.of(keeper), def.rarity, rng:NextNumber())
		then
			M.CafeService.addCaughtCat(player, def, false, keeper, nil, carry.method, nil)
			Net.toast(player, string.format("Your %s brought a friend!", def.name), "good")
		end
		local verb = if carry.method == "rescue" then "rescued" else "caught"
		-- the shout-out chime rises with rarity; F89: a Legendary or Mythical one at most once a minute a player
		M.RareMomentService.shoutOut(
			player,
			def.rarity,
			Catching.shoutOut(player.DisplayName, verb, def, carry.variant),
			-- #2567: a pity or shower cat's line stays in this server; #3470: a Secret's too
			carry.pity == true or def.rarity == M.Catalog.SECRET
		)
		if def.rarity == M.Catalog.SECRET then
			Telemetry.custom(
				player,
				"secret_caught",
				carry.knocks,
				{ M.RareMoments.how(carry.method), instance.variant }
			)
		end
		M.RareMomentService.secured(player, def, carry.variant, carry.method, hadEpicOrBetter)
		M.EventRewardService.secured(player) -- #2486: a Cafe Event's reward for a secure in its window
		-- F101: a check-in scores for the Rescue Rally, a rescued cat three times (the rescue's points)
		M.RallyService.score(player, if carry.method == "rescue" then "rescue" else "checkIn")
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

-- #4251 (Sync's Harvest Studio run, 2026-11-17): Harvest Hollow has no camp and stands far from every cafe door, and
-- fast travel waits until the arms are empty (busyReason), so a cat caught there could never be taken home. A cat
-- caught or picked up in an added area with no camp goes home a moment later instead, once the catch has shown in
-- the arms: checked in as at a door, if it is still the cat in the arms (or the Backpack) by then.
M.homeFromCampless = function(player: Player, areaId: string)
	local area = world.areas[areaId]
	if area == nil or area.camp ~= nil or M.areaGates[areaId] == nil then
		return -- only an added area (CatService.addArea), never one of the ten
	end
	local carry = carrying[player] or packed[player]
	if carry == nil then
		return
	end
	task.delay(1, function()
		if carrying[player] == carry or packed[player] == carry then
			finishCheckIn(player, true)
		end
	end)
end

-- Dusk (data-model section 9, v0.9): a Dropped stray goes to its last carrier while they are in the server, checked
-- in as if they had walked it home, so a shove or a Drop never loses a cat; every other stray just leaves.
local function leaveAtDusk(stray: Stray)
	local drop = stray.drop
	local owner = if drop ~= nil then Players:GetPlayerByUserId(drop.owner) else nil
	if owner == nil or M.DataService.get(owner) == nil then
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
		perfect = stray.perfect, -- #5300
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
	local plot = M.PlotService.get(player)
	if carry == nil or plot == nil then
		return
	end
	-- Either door works (layout v2): the back door is the short way in from the back alley.
	local range = M.Config.CheckInRangeStuds + CHECK_IN_LAG_STUDS
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
	local profile = M.DataService.get(player)
	if profile ~= nil then
		-- #5551: onto the camp ring with the cat (the server checks in as the carrier enters the camp), and the Park's
		Telemetry.firstFive(player, profile, "camp_ring")
		if campId == M.Tier3Path.AREA and M.Economy.tier(profile) >= 2 then
			Telemetry.firstFive(player, profile, "park_home")
		end
	end
	finishCheckIn(player, true)
	for _, hook in M.campHooks do
		task.spawn(hook, player, campId)
	end
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
		local plot = M.PlotService.get(player)
		if position == nil or plot == nil then
			return -- no cafe to check a cat in to, at a camp or a door (review N280)
		end
		local campId: string? = M.Layout.campAt(position.X, position.Z)
		-- #5707 picnicFlow: by their own blanket a carrier checks in at the blanket's camp, in the rect or not
		local spot: Vector3? = picnicSpots[player.UserId]
		if campId == nil and spot ~= nil and M.LiveFlagService.on(M.PicnicParty.FLOW_FLAG) then
			local dx, dz = position.X - spot.X, position.Z - spot.Z
			if math.sqrt(dx * dx + dz * dz) <= M.PicnicParty.NET_STUDS then
				campId = M.Layout.campAt(spot.X, spot.Z)
			end
		end
		if campId ~= nil then
			campCheckIn(player, campId :: string)
			return
		end
		local from = lastCarrierAt[player] or position
		if (position - from).Magnitude > MAX_STEP_STUDS then
			from = position
		end
		seen[player] = position
		local range = M.Config.CheckInRangeStuds
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
	local deadline = os.clock() + M.Config.DropReturnMaxSeconds
	-- #2687: the Lost and Found's Homing Bell walks the dropper's own cat home faster from Tier 5
	local drop = stray.drop
	local owner = if drop ~= nil then Players:GetPlayerByUserId(drop.owner) else nil
	local ownerProfile = if owner ~= nil then M.DataService.get(owner) else nil
	local ownerTier = if ownerProfile ~= nil then M.Economy.tier(ownerProfile) else nil
	local speed = M.Config.DropReturnWalkSpeed * M.StationPerks.homingSpeed(ownerTier)
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
		if (at - goal).Magnitude <= M.Config.DropHomeRadiusStuds then
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
		perfect = carry.perfect,
	})
	local areaDef = M.Catalog.getArea(homeId)
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
	if not openFor(M.DataService.get(player)) then -- #2692: a night pass drops as by day
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
	if not openFor(M.DataService.get(player)) then -- #2692: a night pass drops as by day
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
			perfect = carry.perfect,
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
		M.CafeService.setCarrying(player, nil)
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

-- A Curious stray walks CuriousWalkStuds toward the first player who comes within CuriousRangeStuds, once. `pivot`
-- is the stray's own, read once a look by moodTick (#4601).
local function curious(stray: Stray, pivot: CFrame, root: Vector3, now: number)
	local at = pivot.Position
	if not M.Moods.noticed(at, root) then
		return
	end
	stray.curiousAt = now
	stray.model:SetAttribute("CuriousAt", now)
	stray.model:SetAttribute("Napping", false)
	local area = world.areas[stray.area]
	local target =
		clearPath(at, WorldBuilder.clampToArea(area, M.Moods.curiousTarget(at, root), 2, at))
	stray.walk += 1
	local walk = stray.walk
	task.spawn(function()
		Mover.walkTo(stray.model, target, M.Config.StrayWanderSpeed, function()
			return stray.alive and stray.lockedBy == 0 and stray.walk == walk
		end)
	end)
end

-- A Skittish stray hops SkittishHopStuds away from a player inside its front arc, at most once a SkittishCooldown;
-- never from a player before tutorialStep 2 (7a).
local function skittish(
	stray: Stray,
	pivot: CFrame,
	player: Player,
	root: Vector3,
	now: number
): boolean
	if not M.Moods.hopReady(stray.skittishAt, now) then
		return false
	end
	if not M.Moods.inFrontArc(pivot.Position, pivot.LookVector, root) then
		return false
	end
	local profile = M.DataService.get(player)
	if profile == nil or not M.Moods.canStartle(profile.tutorialStep) then
		return false
	end
	-- #4255 follow-up (SecretCalm): a Secret startles once a visit, only at a player running at it, never mid-swing
	if stray.def.rarity == M.Catalog.SECRET then
		local last = lastSwing[player]
		if
			not secretMayHop(stray, player)
			or not SecretCalm.running(rootVelocity(player))
			or SecretCalm.swinging(if last ~= nil then now - last else nil)
		then
			return false
		end
	end
	stray.skittishAt = now
	hop(stray, player, M.Config.SkittishHopStuds)
	countSecretHop(stray, player)
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
		-- #4601: one pivot read per stray a look, not one per stray and player (30 players and a full server of
		-- strays made it thousands of engine calls a second); the stray only moves after the break below
		local pivot = stray.model:GetPivot()
		for player, root in roots do
			if stray.mood == "Curious" then
				curious(stray, pivot, root, now)
				if stray.curiousAt ~= nil then
					break
				end
			elseif skittish(stray, pivot, player, root, now) then
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
	M.DataService.beforeRelease(function(player, profile)
		if carrying[player] ~= nil or packed[player] ~= nil then
			finishCheckIn(player, false, profile)
		end
	end)

	-- #2845: an owner's save usually loads after their first character spawns, so CharacterAdded's wearBackpack finds
	-- no Backpack yet; put it on once the save is in (a no-op without a character, or with the pack already worn)
	M.DataService.onLoaded:Connect(function(player: Player)
		wearBackpack(player)
		keepShoes(player) -- #4050
	end)

	-- #4197/#4878: Speed Rush starts or ends: everyone's walk speed follows at once
	local rushing = EventService.speedRush()
	EventService.adminChanged:Connect(function()
		local now = EventService.speedRush()
		if now == rushing then
			return
		end
		rushing = now
		for _, player in Players:GetPlayers() do
			local ok, err = pcall(function()
				keepShoes(player)
				CatService.refreshSpeed(player)
			end)
			if not ok then
				warn("[CatService] speed rush: " .. tostring(err))
			end
		end
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
				setSpeed(player, humanoid, M.Config.NormalWalkSpeed + pawsBonus(player))
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		purrfectStreak[player] = nil
		Street.forget(player) -- #5533
		-- endCarry (via the finalizer above) clears the carry record; this only mops up when the profile is
		-- already gone, so the handler order between services does not matter.
		if carrying[player] ~= nil and M.DataService.get(player) == nil then
			carrying[player] = nil
		end
		if packed[player] ~= nil and M.DataService.get(player) == nil then
			packed[player] = nil
		end
		circleHistory[player] = nil
		Second.forget(player) -- #3022
		lastCatchStart[player] = nil
		lastSwing[player] = nil
		startledUntil[player] = nil
		for _, stray in strays do
			if stray.lockedBy == player.UserId then
				if stray.attempt ~= nil then
					lostCatch(player, stray, "left") -- #5500
				end
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
			xpcall(Street.tick, function(err: unknown) -- #5533 streetCats
				warn("[CatService] street tick: " .. tostring(err))
			end)
			xpcall(Second.hood, function(err: unknown) -- #5652 hoodWelcome
				warn("[CatService] hood welcome: " .. tostring(err))
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
			if M.DataService.get(player) ~= nil then
				M.CafeService.sync(player)
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
			xpcall(stormTick, function(err: unknown)
				warn("[CatService] cat storm: " .. tostring(err))
			end, nowClock - last) -- #4195
			xpcall(huntTick, function(err: unknown)
				warn("[CatService] secret hunt: " .. tostring(err))
			end) -- #4197
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
		local slot = stray.model:GetAttribute(M.Pity.SLOT_ATTRIBUTE)
		local waits = type(slot) == "number" and keeps ~= nil and keeps(slot)
		-- #2692: a beginner's own tutorial stray stays for their night pass
		if stray.beginner == nil and not waits then
			table.insert(leaving, stray)
		end
	end
	if not M.LiveFlagService.on(M.NightSpread.FLAG) then
		for _, stray in leaving do
			whenUnlocked(stray, leaveAtDusk)
		end
		return
	end
	-- #5164 (nightSpread): PER_STEP strays a frame, so dusk is no one long server frame. A stray caught or gone in
	-- between is skipped; a sunrise in between (waveNumber moved on) stops the rest, which the day keeps.
	local wave = waveNumber
	task.spawn(function()
		for n, run in M.NightSpread.chunks(leaving, M.NightSpread.PER_STEP) do
			if n > 1 then
				task.wait(M.NightSpread.STEP_SECONDS)
				if waveNumber ~= wave then
					return
				end
			end
			for _, stray in run do
				if stray.alive then
					whenUnlocked(stray, leaveAtDusk)
				end
			end
		end
	end)
end

-- Sunrise (v0.9, F66): every area gets its wave of WaveSize strays, whether or not anyone has it unlocked. #3661:
-- rolled at once, placed over Config.WaveSpreadSeconds.
-- F88: a Lucky Day's waves roll at LuckyDayWaveLuck, and the day is logged as `lucky_day` (value the players in the
-- server; the first area a Mythical came to, or "none"). #1888: any special day logs it, with its kinds ("lucky",
-- "golden+rainbow").
function CatService.sunriseWave()
	local luckyDay = M.ClockService.luckyDay()
	local kinds = M.ClockService.dayKinds()
	local kindNames: { string } = {}
	if kinds ~= nil then
		for _, kind in { "lucky", "golden", "rainbow" } do
			if (kinds :: any)[kind] == true then
				table.insert(kindNames, kind)
			end
		end
	end
	local luck = if luckyDay then M.Config.LuckyDayWaveLuck else 1
	local mythicalArea = "none"
	waveNumber += 1
	local wave = waveNumber
	local waves: { { WavePlace } } = {}
	for _, areaDef in M.Catalog.areas do
		local places, mythical = rollWave(areaDef, luck)
		if mythical and mythicalArea == "none" then
			mythicalArea = areaDef.id
		end
		table.insert(waves, places)
	end
	-- #3661: the first few of every area (its rarest) at once, then the rest in turn, one area after another
	local order = StrayTopUp.waveOrder(waves, M.Config.WaveAtOnce)
	local later: { WavePlace } = order.later
	if M.LiveFlagService.on(M.NightSpread.FLAG) then
		-- #5164: the rarest of every area PER_STEP at a time, STEP_SECONDS apart, not all in the sunrise frame
		task.spawn(function()
			for n, run in M.NightSpread.chunks(order.now, M.NightSpread.PER_STEP) do
				if n > 1 then
					task.wait(M.NightSpread.STEP_SECONDS)
					if waveNumber ~= wave or not M.ClockService.areasOpen() then
						return
					end
				end
				for _, entry: WavePlace in run do
					xpcall(placeWave, function(err: unknown)
						warn("[CatService] wave: " .. tostring(err))
					end, entry)
				end
			end
		end)
	else
		for _, entry: WavePlace in order.now do
			placeWave(entry)
		end
	end
	if #later > 0 then
		local gap = StrayTopUp.waveGap(#later, M.Config.WaveSpreadSeconds)
		task.spawn(function()
			for _, entry: WavePlace in later do
				task.wait(gap)
				if waveNumber ~= wave or not M.ClockService.areasOpen() then
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
		local players = M.DataService.loadedPlayers()
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
	local profile = M.DataService.get(player)
	return profile ~= nil and NightPass.of(profile, M.LiveFlagService.on(NightPass.FLAG))
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

-- #5584 (Derek 2026-11-20: "increase speed while in town square by a decent amount so people don't get bored of
-- running"): with switch townFast on, the Town Square bonus is this instead of TownWalkSpeedBonus (20 + 10)
local TOWN_FAST = 10

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
	local square = if (character :: Model):GetAttribute("OnSquare") ~= true
		then 0
		elseif ReplicatedStorage:GetAttribute("LiveFlag_townFast") == true then TOWN_FAST -- #5584
		else M.Config.TownWalkSpeedBonus
	local base = if carry == nil
		then M.Config.NormalWalkSpeed + pawsBonus(player) + square
		elseif
			carry.rushUntil ~= nil and carry.rushUntil > serverNow()
		then M.Config.CatchRushWalkSpeed
		else carrySpeed(player) -- #3063, #3535: Swift Paws and the Speed Shoes, never on the rush
	-- Startled slows a carry too (a forfeit miss), never speeds one up (review N247)
	if startled ~= nil and startled > serverNow() then
		base = math.min(base, M.Config.StartledWalkSpeed)
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

-- #5381: whether this profile has the area open (its gate, else its tier), for AreaWholeService's areasKept.
function CatService.areaUnlocked(profile: Types.PlayerProfile, areaId: string): boolean
	return areaUnlocked(profile, areaId)
end

-- #4251: an area that is not one of the ten (Harvest Hollow, World/HarvestWorld), added once it is built: its
-- AreaInfo (spawn points, floor, bounds, roam) and who may catch there. Its strays come only from spawnIn; no
-- wave, top-up, bait, rescue or pity knows it.
function CatService.addArea(info: WorldBuilder.AreaInfo, gate: (Types.PlayerProfile) -> boolean)
	world.areas[info.id] = info
	M.areaGates[info.id] = gate
end

-- #4251: one stray of `rarity` (a cat of that rarity whose `area` is `areaId`) at a free spawn point of an added
-- area, spread from the others there. False when the area is unknown or every point is taken.
function CatService.spawnIn(areaId: string, rarity: Types.Rarity): boolean
	if world.areas[areaId] == nil or M.areaGates[areaId] == nil then
		return false
	end
	local point = freeSpawnPoint(areaId, rarity)
	if point == nil then
		return false
	end
	spawnAt(areaId, point, rarity)
	return true
end

-- #4251: `hook(player, def, areaId)` runs (in its own thread) after every successful net catch, as the cat goes
-- into the catcher's arms; not for a cat let go that walked home first (`recaught`), so Harvest pumpkins and the pie
-- count each cat once (Sync's Harvest run, 2026-11-17: a drop then a late re-catch paid +1 twice).
-- #5572: a Picnic Party started for `player` at the basket station whose pivot is `pivot`: its cats come to the
-- blanket one after another (shared/PicnicSeats), the first now. A party already running keeps its cats.
function CatService.picnicCats(player: Player, profile: Types.PlayerProfile, pivot: CFrame)
	if Street.picnics[player.UserId] ~= nil then
		return
	end
	for n = 1, #M.PicnicSeats.SPOTS do
		player:SetAttribute("PicnicCat" .. n, nil)
	end
	Street.picnics[player.UserId] = { pivot = pivot, defs = Street.picnicDefs(profile), n = 0 }
	picnicSpots[player.UserId] = M.PicnicSeats.centre(pivot).Position
	Street.picnicSeat(player.UserId)
end

-- #5572: the party is over (or the player left): the cat still on the blanket goes once nobody is catching it.
function CatService.picnicClear(player: Player)
	local picnic: Picnic? = Street.picnics[player.UserId]
	Street.picnics[player.UserId] = nil
	picnicSpots[player.UserId] = nil
	if picnic ~= nil and picnic.stray ~= nil then
		Street.picnicGo(picnic.stray :: Stray)
	end
end

function CatService.onCaught(hook: (Player, Types.CatDef, string) -> ())
	table.insert(M.caughtHooks, hook)
end

-- #5533: `hook` hears of every cat checked in at a camp, with the camp's id
function CatService.onCampCheckIn(hook: (Player, string) -> ())
	table.insert(M.campHooks, hook)
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
	local def = M.Catalog.getCat(catId)
	local area = world.areas[areaId]
	if def == nil or area == nil or #area.spawnPoints == 0 then
		return nil
	end
	local pointIndex = freeSpawnPoint(areaId, def.rarity) or 1
	local point = area.spawnPoints[pointIndex]
	local stray = spawnStray(def, areaId, point.Position, pointIndex, nil, coat)
	stray.model:SetAttribute(M.Pity.ATTRIBUTE, kind)
	stray.model:SetAttribute(M.Pity.SLOT_ATTRIBUTE, slot)
	stray.pity = true
	return stray.id
end

-- #1572: the pity cat of `slot` leaves this server (another server's catch got it): every copy still out puffs
-- away, a catch in progress on it included. A copy already caught here is someone's carry and stays.
function CatService.removePity(slot: number): number
	local leaving: { Stray } = {}
	for _, stray in strays do
		if stray.alive and stray.model:GetAttribute(M.Pity.SLOT_ATTRIBUTE) == slot then
			table.insert(leaving, stray)
		end
	end
	for _, stray in leaving do
		local holder = if stray.lockedBy ~= 0
			then Players:GetPlayerByUserId(stray.lockedBy)
			else nil
		if stray.attempt ~= nil then
			lostCatch(holder, stray, "pity_lost") -- #5500
		end
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
		if stray.alive and stray.model:GetAttribute(M.Pity.SLOT_ATTRIBUTE) == slot then
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
	local def = M.Catalog.getCat(catId)
	local areaDef = M.Catalog.getArea(areaId)
	assert(def ~= nil and areaDef ~= nil, "unknown cat or area")
	local area = world.areas[areaId]
	local pointIndex = freeSpawnPoint(areaId, def.rarity) or 1
	local point = area.spawnPoints[pointIndex]
	local stray = spawnStray(
		def :: Types.CatDef,
		areaId,
		point.Position,
		pointIndex,
		M.Config.StrayDespawnSeconds,
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
	local profile = M.DataService.get(player)
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
	local pad = M.Layout.landingPads[areaId]
	if
		areaId ~= "park"
		or pad == nil
		or M.Onboarding.reached(profile.telemetry, "first_park_catch")
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
