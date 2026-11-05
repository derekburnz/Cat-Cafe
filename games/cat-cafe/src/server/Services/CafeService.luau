--!strict
-- The cafe itself: income accounting, placement, shop purchases, decor, tables, offline earnings and ProfileSync.
-- Every handler validates its arguments, settles income first, mutates the profile, refreshes the world, then syncs.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AssetRegistry = require(script.Parent.Parent.World.AssetRegistry)
local Bait = require(ReplicatedStorage.Shared.Bait)
local Bedtime = require(ReplicatedStorage.Shared.Bedtime)
local CatPose = require(script.Parent.Parent.World.CatPose)
local CatStats = require(ReplicatedStorage.Shared.CatStats)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local ClockService = require(script.Parent.ClockService)
local Config = require(ReplicatedStorage.Shared.Config)
local Crates = require(ReplicatedStorage.Shared.Crates)
local DailyTreat = require(ReplicatedStorage.Shared.DailyTreat)
local DataService = require(script.Parent.DataService)
local DecorBest = require(ReplicatedStorage.Shared.DecorBest)
local Economy = require(ReplicatedStorage.Shared.Economy)
local EquipBest = require(ReplicatedStorage.Shared.EquipBest)
local GoldenFish = require(ReplicatedStorage.Shared.GoldenFish)
local Guard = require(script.Parent.Parent.Util.Guard)
local IndexRewards = require(ReplicatedStorage.Shared.IndexRewards)
local Lawn = require(ReplicatedStorage.Shared.Lawn)
local LawnBuilder = require(script.Parent.Parent.World.LawnBuilder)
local Layout = require(script.Parent.Parent.World.Layout)
local LeaderboardService = require(script.Parent.LeaderboardService)
local Leaderboards = require(ReplicatedStorage.Shared.Leaderboards)
local Leaderstats = require(script.Parent.Leaderstats)
local Luck = require(ReplicatedStorage.Shared.Luck)
local NameService = require(script.Parent.NameService)
local Net = require(script.Parent.Net)
local PalService = require(script.Parent.PalService)
local PassService = require(script.Parent.PassService)
local PlotService = require(script.Parent.PlotService)
local Potions = require(ReplicatedStorage.Shared.Potions)
local ProfileSchema = require(ReplicatedStorage.Shared.ProfileSchema)
local Quests = require(ReplicatedStorage.Shared.Quests)
local Settings = require(ReplicatedStorage.Shared.Settings)
local SleepSpots = require(script.Parent.Parent.World.SleepSpots)
local Telemetry = require(script.Parent.Telemetry)
local TipService = require(script.Parent.TipService)
local Trade = require(ReplicatedStorage.Shared.Trade)
local Types = require(ReplicatedStorage.Shared.Types)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

type Profile = Types.PlayerProfile

local CafeService = {}

local PLAIN_FLAP = "CatCafe_CatFlap_Plain" -- the cafe's own cat flap alone, for a door set with none picked (F80)

local carrying: { [Player]: string? } = {} -- catId while walking a caught stray home
-- Each player's cat levels at their last sync (v0.12 F75), so a level gained in any settle sends one CatLevelUp
local knownLevels: { [Player]: { [string]: number } } = {}
local rng = Random.new() -- charm rolls for caught cats
-- F102: TradeService says whether a cat is on offer in an open trade (set at its start; nothing is on offer before)
local offerCheck: (player: Player, uid: string) -> boolean = function(
	_player: Player,
	_uid: string
): boolean
	return false
end
-- #1574: and whether a decor or lawn piece is
local pieceOfferCheck: (player: Player, id: string) -> boolean = function(
	_player: Player,
	_id: string
): boolean
	return false
end

-- Settled profile or nil when not loaded yet.
local function profileFor(player: Player): Profile?
	local profile = DataService.get(player)
	if profile ~= nil then
		Economy.settle(profile, os.time(), ClockService.epoch())
	end
	return profile
end

-- What the cafe earns per second right now: the day rate, times NightIncomeMultiplier at night (section 11) and the
-- Tip Potion's share while one runs (F64) and the pal bonus (F92, Economy.tipMultiplier). PotionService syncs when a
-- potion ends and CafeService when the pals change, so the HUD's rate follows.
local function currentRate(profile: Profile): number
	return Economy.incomePerSecond(profile)
		* Economy.phaseMultiplier(ClockService.phase())
		* Economy.tipMultiplier(profile, os.time())
end

-- The cats as the client sees them: saved fields plus rating, stars and XP progress (CatStats.view). A name is
-- the filtered text NameService shows (F33), nil while it is unfiltered or failed, so the catalog name shows.
function CafeService.catViews(player: Player, profile: Profile): { [string]: Types.CatView }
	local views: { [string]: Types.CatView } = {}
	for uid, instance in profile.cats do
		local view = CatStats.view(instance, profile.tier)
		view.name = NameService.displayName(player, instance)
		views[uid] = view
	end
	return views
end

-- When the bowl's cat arrives (data-model section 8), online or not: the readyAt UseLure fixed (the wait, Big Bowl
-- and the Index's bait speed in it, F54), or for a bowl filled before that, LureWaitSeconds after the food went in,
-- never the wait of a bowl level bought since (F82).
function CafeService.baitReadyAt(_profile: Types.PlayerProfile, bait: Types.BaitState): number
	return bait.readyAt or bait.placedAt + Config.LureWaitSeconds
end

-- The Second Bait Bowl for this player (#1161): "on" with the pass, "offer" without it. Capacity, not a paid random
-- item (Bait.secondBowl), so no PolicyService gate. `player` stays for callers that may need it later.
function CafeService.secondBowl(_player: Player, profile: Types.PlayerProfile): Types.SecondBowl
	return Bait.secondBowl(Economy.passes(profile).secondBowl == true)
end

-- The bowl as ProfileSync sends it: the rolled cat only once it has arrived, so the reveal is not spoiled (N30).
local function baitView(profile: Profile, now: number, bowl: number): Types.BaitView?
	local bait = Bait.stateOf(profile, bowl)
	if bait == nil then
		return nil
	end
	local readyAt = CafeService.baitReadyAt(profile, bait)
	local view: Types.BaitView =
		{ lureId = bait.lureId, placedAt = bait.placedAt, readyAt = readyAt, night = bait.night }
	if now >= readyAt then
		view.cat = {
			catId = bait.catId,
			variant = bait.variant,
			charm = bait.charm,
			stars = CatStats.stars(bait.charm),
		}
	end
	return view
end

-- F88: the player's Luck and its sources, each with when it ends (os.time()) where it ends, for the Luck chip.
local function luckView(profile: Profile, now: number): (number, { Types.LuckSource })
	local luckyDay = ClockService.luckyDay()
	local sources: { Types.LuckSource } = {}
	for _, source in Luck.sources(profile, now, luckyDay) do
		local endsAt: number? = nil
		if source.id == "potion" then
			endsAt = now + Potions.left(profile, Potions.LUCKY, now)
		elseif source.id == "lucky_day" then
			endsAt = now + math.max(0, ClockService.phaseEndsAt() - Workspace:GetServerTimeNow())
		end
		local row: Types.LuckSource =
			{ id = source.id :: string, value = source.value, endsAt = endsAt }
		table.insert(sources, row)
	end
	return Luck.of(profile, now, luckyDay), sources
end

function CafeService.buildState(player: Player, profile: Profile): Types.PlayerState
	local plot = PlotService.get(player)
	local now = os.time()
	local totals = IndexRewards.totals(profile)
	local luck, luckSources = luckView(profile, now)
	return {
		money = math.floor(profile.coins),
		incomePerSecond = currentRate(profile), -- drops at nightfall; the client predicts coins with it
		tier = Economy.tier(profile),
		cafeProgress = nil,
		cafeProgressText = nil,
		tables = Economy.level(profile, "tables"),
		customers = nil,
		catsOwned = Economy.countsByCat(profile),
		upgradeLevels = profile.upgradeLevels,
		decorOwned = profile.decorOwned,
		decorPlaced = profile.decorPlaced,
		decorUnlocked = profile.decorUnlocked,
		lures = profile.lures,
		bait = baitView(profile, now, 1),
		bait2 = baitView(profile, now, 2), -- #1161: sent while food is in it, even after the pass went, so it can be emptied
		secondBowl = CafeService.secondBowl(player, profile),
		cats = CafeService.catViews(player, profile),
		collection = profile.collection,
		goldCollection = profile.goldCollection,
		rainbowCollection = profile.rainbowCollection, -- F99
		indexRewards = profile.indexRewards,
		spin = table.clone(profile.spin),
		goldenFish = profile.goldenFish,
		crates = profile.crates,
		crateLuck = profile.crateLuck,
		fishPerks = profile.fishPerks,
		goldLuck = totals.goldLuck,
		rainbowLuck = IndexRewards.rainbowLuck(profile), -- F99: the food card's "Rainbow 0.5%" line
		baitSpeed = totals.baitSpeed,
		plotIndex = if plot ~= nil then plot.index else 0,
		carrying = carrying[player],
		dataSaves = DataService.saves(),
		tutorialStep = profile.tutorialStep,
		introSeen = profile.introSeen,
		potions = profile.potions, -- F64
		catFood = profile.catFood, -- #1181: the Bag's cat food
		hideCredit = profile.hideCredit == true, -- #1083: the Settings row "Show my name on the Thank You board"
		buffs = Potions.endsAt(profile, now), -- F64: endsAt in server time; the save keeps seconds left
		settings = Settings.copy(profile.settings),
		quests = Quests.view(profile, now), -- F73
		achievements = Quests.achievementsView(profile),
		dailyTreat = DailyTreat.view(profile.dailyTreat, now), -- F70
		stats = table.clone(profile.stats),
		tipsSeen = table.clone(profile.tipsSeen), -- F87
		feedbackAsked = profile.feedbackAsked,
		stuckHelpShown = table.clone(profile.stuckHelpShown),
		starterCatClaimed = profile.starterCatClaimed, -- F96
		luck = luck, -- F88
		luckSources = luckSources,
		longNap = Economy.passes(profile).longNap, -- F95: the welcome back card's line
		tradeLog = table.clone(profile.tradeLog), -- F102: the Trades page
		lawnOwned = profile.lawnOwned, -- F91: the Front lawn tab
		lawn = profile.lawn,
		lawnStyles = profile.lawnStyles,
		serverTime = now,
	}
end

-- World refresh -------------------------------------------------------------------------------------------

-- "+1 golden fish", "+8 golden fish": the fish part of a toast.
local function fishText(fish: number): string
	return string.format("+%d golden fish", fish)
end

-- "Barista", "Waiter": the role a slot holds, for toasts.
local function roleName(spot: Types.SpotDef): string
	return spot.spotType:sub(1, 1):upper() .. spot.spotType:sub(2)
end

local function refreshSpots(plot: WorldBuilder.Plot, profile: Profile)
	local tier = Economy.tier(profile)
	plot.model:SetAttribute("Tier", tier)
	WorldBuilder.setDressing(plot, tier)
	-- No floating "opens at Tier N" text over locked slots (Derek 2026-10-27: placeholder text is ugly); the
	-- Upgrades screen's Roles section lists which slots each tier opens.
end

-- Working cats stand at their slots; up to #plot.napSpots cats without a job nap in the cafe, highest rating first,
-- so the collection is on show from the street (world-and-feel.md section 4, F37). Each model carries what the
-- world labels and effects read: Slot, Napping, Rarity, Gold, Rate (its coins per second after the cafe and
-- tier multipliers, 0 while napping) and DisplayName (its filtered name, else the catalog name; F33); working cats
-- are tagged WorkingCat. At night a working cat may be on a bedtime trip or asleep on a sleep spot (F79,
-- BedtimeService): on the walking body without its outfit, with Bedtime, SleepSpot and Asleep.
-- #1534: by day the resting cats past the nap spots nap on the free F79 sleep spots too (slot "bed_<spot id>", at
-- `at`), best first, so more of the collection is on show; at night those spots are the working cats' beds.
type CatPlacement = { instance: Types.CatInstance, slot: string, anchor: BasePart?, at: CFrame? }

-- The name over a cat model; a named cat not filtered yet asks NameService, which refreshes once it has the text.
local function shownName(player: Player, instance: Types.CatInstance): string
	NameService.request(player, instance)
	local def = Catalog.getCat(instance.catId)
	return NameService.displayName(player, instance)
		or (if def ~= nil then def.name else instance.catId)
end

-- One cat's model at `at` for its `slot`, not parented yet, its Rate for an owner at `tier`. A working cat stands on
-- the worker body (S, Model-Agent #826; Derek picked S on 2026-11-02) in its role's outfit, its front legs posed for
-- the role and holding the role's cup, tray or microphone (CatDress.workPose), else sits on the seated body (B) while
-- its worker is not exported; with `sleepSpot` (F79) it is on the walking body (A) without the outfit instead, on a
-- bedtime trip to that spot or asleep on it. Resting cats mix their idles (Derek 2026-10-27: "use a
-- mix of idle animations"): the odd nap spots sit on B and wash a paw, the even ones lie on A, where they sleep and
-- sit up into a loaf with its purr.
local function buildCat(
	player: Player,
	instance: Types.CatInstance,
	slot: string,
	at: CFrame,
	multiplier: number,
	tier: number,
	sleepSpot: string?
): Model
	local def = Catalog.getCat(instance.catId)
	local spot = if instance.spotId ~= nil then Catalog.getSpot(instance.spotId) else nil
	local napIndex = tonumber(slot:match("^nap_(%d+)$"))
	local body: AssetRegistry.Body = if sleepSpot ~= nil
		then "walk"
		elseif spot ~= nil then "work"
		elseif napIndex ~= nil and napIndex % 2 == 1 then "sit"
		else "walk"
	local model, built = AssetRegistry.cloneCat(instance.catId, instance.variant, body)
	model.Name = instance.uid
	model:SetAttribute("Uid", instance.uid)
	model:SetAttribute("CatId", instance.catId)
	model:SetAttribute("Slot", slot)
	model:SetAttribute("SpotId", instance.spotId)
	model:SetAttribute("Napping", instance.spotId == nil)
	model:SetAttribute("Rarity", if def ~= nil then def.rarity else nil)
	model:SetAttribute("Gold", instance.variant == "gold")
	model:SetAttribute("Variant", instance.variant) -- F99: a rainbow cat's coat flows at work and at rest
	model:SetAttribute("Rate", Economy.catRate(instance, tier) * multiplier)
	model:SetAttribute("DisplayName", shownName(player, instance))
	model:SetAttribute("Level", CatStats.level(instance))
	model:SetAttribute("OwnerUserId", player.UserId)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- a cat streams in whole (reviewer S37)
	model:PivotTo(at)
	if built ~= "walk" then
		model:SetAttribute("Pose", built) -- the client's Effects keep a seated cat seated and a worker at work
	end
	if spot ~= nil then
		CollectionService:AddTag(model, "WorkingCat") -- the client's Audio purrs from the nearest few
		model:SetAttribute("Role", spot.spotType)
		if sleepSpot ~= nil then
			model:SetAttribute("Bedtime", true)
			model:SetAttribute("SleepSpot", sleepSpot)
		else
			CatPose.dress(model, spot.spotType) -- F25: a working cat sits at its station in its role's outfit
		end
	end
	return model
end

local function refreshCats(player: Player, plot: WorldBuilder.Plot, profile: Profile)
	local multiplier = Economy.cafeMultiplier(profile) * Economy.tierMultiplier(profile)
	local wanted: { [string]: CatPlacement } = {}
	local resting: { Types.CatInstance } = {}
	for uid, instance in profile.cats do
		if instance.spotId ~= nil then
			local spot: BasePart? = plot.spots[instance.spotId :: string]
			if spot ~= nil then
				wanted[uid] =
					{ instance = instance, slot = instance.spotId :: string, anchor = spot }
			end
		else
			table.insert(resting, instance)
		end
	end
	table.sort(resting, CatStats.betterFor(profile.tier))
	local nappers: { [string]: Types.CatInstance } = {} -- the best few resting cats, by uid
	for n = 1, math.min(#resting, #plot.napSpots) do
		nappers[resting[n].uid] = resting[n]
	end
	-- A napper still among the best keeps its spot, so a change in the order does not shuffle every cat
	-- (reviewer N60); the others take the free spots in order.
	local takenSpots: { [number]: boolean } = {}
	for _, child in plot.cats:GetChildren() do
		local uid, slot = child:GetAttribute("Uid"), child:GetAttribute("Slot")
		local instance = if type(uid) == "string" then nappers[uid] else nil
		local n = if type(slot) == "string" then tonumber(slot:match("^nap_(%d+)$")) else nil
		if instance ~= nil and n ~= nil and n <= #plot.napSpots and not takenSpots[n] then
			takenSpots[n] = true
			wanted[instance.uid] =
				{ instance = instance, slot = slot :: string, anchor = plot.napSpots[n] }
		end
	end
	local nextSpot = 1
	for n = 1, math.min(#resting, #plot.napSpots) do
		local instance = resting[n]
		if wanted[instance.uid] == nil then
			while takenSpots[nextSpot] do
				nextSpot += 1
			end
			takenSpots[nextSpot] = true
			wanted[instance.uid] =
				{ instance = instance, slot = "nap_" .. nextSpot, anchor = plot.napSpots[nextSpot] }
		end
	end
	-- #1534: by day the resting cats after the nap spots' few nap on the free sleep spots (cat beds, cat trees, decor
	-- trees), best first. A spot under a working station (an entertainer on its tree top) or still held by a cat
	-- walking back from bed is not free. A cat already on a free one keeps it, so the order changing never shuffles
	-- them; past the last free spot the rest stay in the cat room.
	if not ClockService.isNight() and #resting > #plot.napSpots then
		local free: { [string]: SleepSpots.Spot } = {}
		local order: { SleepSpots.Spot } = {}
		for _, spot in SleepSpots.list(plot) do
			free[spot.id] = spot
			table.insert(order, spot)
		end
		for _, placement in wanted do
			local anchor = placement.anchor
			if placement.instance.spotId ~= nil and anchor ~= nil then
				local under = SleepSpots.at(order, anchor.CFrame)
				if under ~= nil then
					free[under.id] = nil
				end
			end
		end
		for _, child in plot.cats:GetChildren() do
			local held = child:GetAttribute("SleepSpot")
			if type(held) == "string" then
				free[held] = nil
			end
		end
		-- the same fill as bedtime (Bedtime.assign): best first, a cat keeps a spot it is on, the rest in spot order
		local ids: { string } = {}
		for _, spot in order do
			if free[spot.id] ~= nil then
				table.insert(ids, spot.id)
			end
		end
		local uids: { string } = {}
		for n = #plot.napSpots + 1, #resting do
			table.insert(uids, resting[n].uid)
		end
		local held: { [string]: string } = {}
		for _, child in plot.cats:GetChildren() do
			local uid, slot = child:GetAttribute("Uid"), child:GetAttribute("Slot")
			local id = if type(slot) == "string" then slot:match("^bed_(.+)$") else nil
			if type(uid) == "string" and id ~= nil then
				held[uid] = id
			end
		end
		for uid, id in Bedtime.assign(uids, ids, held) do
			wanted[uid] = { instance = profile.cats[uid], slot = "bed_" .. id, at = free[id].at }
		end
	end
	-- At night (F79) a cat asleep on a spot that has gone (a decor cat tree put away) is built again on a free one.
	local sleepSpots: { SleepSpots.Spot }? = if ClockService.isNight()
		then SleepSpots.list(plot)
		else nil
	local spotIds: { [string]: boolean } = {}
	if sleepSpots ~= nil then
		for _, spot in sleepSpots do
			spotIds[spot.id] = true
		end
	end
	for _, child in plot.cats:GetChildren() do
		local uid = child:GetAttribute("Uid")
		local placement: CatPlacement? = if type(uid) == "string" then wanted[uid] else nil
		local sleepSpot = child:GetAttribute("SleepSpot")
		if
			placement == nil
			or child:GetAttribute("Slot") ~= placement.slot
			or (
				sleepSpots ~= nil
				and child:GetAttribute("Asleep") == true
				and not (type(sleepSpot) == "string" and spotIds[sleepSpot])
			)
		then
			child:Destroy()
		else
			wanted[uid :: string] = nil
			child:SetAttribute(
				"Rate",
				Economy.catRate(placement.instance, profile.tier) * multiplier
			)
			child:SetAttribute("DisplayName", shownName(player, placement.instance))
			-- a rise plays the owner's level up sparkle (F75); the hover card reads it on other players' cats
			child:SetAttribute("Level", CatStats.level(placement.instance))
		end
	end
	-- A working cat built at night (a join, or one placed after dark) is built asleep on the first free sleep spot,
	-- best rating first, without the walk (F79); one left over sits at its station as by day.
	local beds: { [string]: SleepSpots.Spot } = {}
	if sleepSpots ~= nil then
		local taken: { [string]: boolean } = {}
		for _, child in plot.cats:GetChildren() do
			local held = child:GetAttribute("SleepSpot")
			if type(held) == "string" then
				taken[held] = true
			end
		end
		local free: { string } = {}
		local byId: { [string]: SleepSpots.Spot } = {}
		for _, spot in sleepSpots do
			byId[spot.id] = spot
			if not taken[spot.id] then
				table.insert(free, spot.id)
			end
		end
		local workers: { Types.CatInstance } = {}
		for _, placement in wanted do
			if placement.instance.spotId ~= nil then
				table.insert(workers, placement.instance)
			end
		end
		table.sort(workers, CatStats.betterFor(profile.tier))
		local uids: { string } = {}
		for _, instance in workers do
			table.insert(uids, instance.uid)
		end
		for uid, id in Bedtime.assign(uids, free, {}) do
			beds[uid] = byId[id]
		end
	end
	for uid, placement in wanted do
		local bed = beds[uid]
		local model = buildCat(
			player,
			placement.instance,
			placement.slot,
			if bed ~= nil then bed.at else placement.at or (placement.anchor :: BasePart).CFrame,
			multiplier,
			profile.tier,
			if bed ~= nil then bed.id else nil
		)
		if bed ~= nil then
			model:SetAttribute("Asleep", true)
		end
		model.Parent = plot.cats
	end
end

-- Puts the piece's model at `at` (moving it when its place changed), or takes it away when `at` is nil. Every
-- placed piece carries DecorId, for the client's effects (F53).
local function showDecor(plot: WorldBuilder.Plot, def: Types.DecorDef, at: BasePart?)
	local existing = plot.decor:FindFirstChild(def.id)
	if at == nil then
		if existing ~= nil then
			existing:Destroy()
		end
		return
	end
	if existing ~= nil and existing:IsA("Model") then
		if existing:GetAttribute("DecorAt") ~= at.Name then
			existing:SetAttribute("DecorAt", at.Name)
			existing:PivotTo(at.CFrame)
		end
		return
	end
	local model = AssetRegistry.clone(def.asset)
	model.Name = def.id
	model:SetAttribute("DecorId", def.id)
	model:SetAttribute("DecorAt", at.Name)
	model:PivotTo(at.CFrame)
	model.Parent = plot.decor
end

-- A door set or cat flap model (F80) named `name` in plot.decor at `at`, carrying `decorId` for the equip flash, or
-- none when `asset` is nil. It never collides, is touched or blocks a cast, so both doorways stay open to players,
-- customers and cats. It is Persistent and only moved when its place changes, so each client keeps the leaves and
-- the flap it swings (DoorController); a door set's back door sign comes off (removeDoorSign).
local function showStyleModel(
	plot: WorldBuilder.Plot,
	name: string,
	asset: string?,
	decorId: string?,
	at: CFrame
): Model?
	local existing = plot.decor:FindFirstChild(name)
	if existing ~= nil and (asset == nil or existing:GetAttribute("Asset") ~= asset) then
		existing:Destroy()
		existing = nil
	end
	if asset == nil then
		return nil
	end
	local model: Model
	if existing ~= nil and existing:IsA("Model") then
		model = existing :: Model
		if not model:GetPivot():FuzzyEq(at, 0.001) then
			model:PivotTo(at)
		end
	else
		model = AssetRegistry.clone(asset)
		model.Name = name
		model:SetAttribute("Asset", asset)
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				local part = descendant :: BasePart
				part.Anchored = true
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
			end
		end
		WorldBuilder.removeDoorSign(model)
		model:PivotTo(at)
		model.Parent = plot.decor
	end
	model:SetAttribute("DecorId", decorId)
	return model
end

-- The door set and cat flap in use (F80, golden-fish.md 4b) swap models in: DoorFront in the front doorway and
-- DoorBack in the back one (the piece's CatCafe_Door_<Name>, or its _Front and _Back versions where the art has
-- them), each at the bottom centre of its opening facing out, and CatFlap at the back door model's `CatFlap`
-- attachment: the door set's, else the real back door's (Model-Agent #509, its leaf as built, shut; each client
-- carries the flap with the leaf as it swings), else low on the back door panel's yard face. A door set with no cat
-- flap picked brings the cafe's own flap alone (PLAIN_FLAP, no DecorId), as the cafe's back door it replaces had one.
-- With none in use the cafe keeps its own doors.
local function refreshDoors(plot: WorldBuilder.Plot, profile: Profile)
	local front = plot.door.CFrame * CFrame.new(0, -plot.door.Size.Y / 2, 0)
	local back = plot.backDoor.CFrame
		* CFrame.new(0, -plot.backDoor.Size.Y / 2, 0)
		* CFrame.Angles(0, math.pi, 0)
	local doorId = Crates.styleInUse(profile, "door")
	local doorDef = if doorId ~= nil then Catalog.getDecor(doorId) else nil
	local function doorAsset(side: string): string?
		if doorDef == nil then
			return nil
		end
		local named = doorDef.asset .. "_" .. side
		return if AssetRegistry.has(named) then named else doorDef.asset
	end
	showStyleModel(plot, "DoorFront", doorAsset("Front"), doorId, front)
	local backModel = showStyleModel(plot, "DoorBack", doorAsset("Back"), doorId, back)
	local flapAt = back * CFrame.new(0, 0, -plot.backDoor.Size.Z / 2 - 0.05)
	local doorModel: Model? = if backModel ~= nil then backModel else plot.backDoorArt
	local hinge = if doorModel ~= nil then doorModel:FindFirstChild("CatFlap", true) else nil
	if hinge ~= nil and hinge:IsA("Attachment") then
		flapAt = (hinge :: Attachment).WorldCFrame
	end
	local flapId = Crates.styleInUse(profile, "catflap")
	local flapDef = if flapId ~= nil then Catalog.getDecor(flapId) else nil
	local flapAsset = if flapDef ~= nil
		then flapDef.asset
		elseif backModel ~= nil and AssetRegistry.has(PLAIN_FLAP) then PLAIN_FLAP
		else nil
	showStyleModel(plot, "CatFlap", flapAsset, flapId, flapAt)
end

local function refreshDecor(plot: WorldBuilder.Plot, profile: Profile)
	local replaced = Economy.replacedDecor(profile) -- a placed stand-in takes its piece's spot (none since F54)
	local function inUse(def: Types.DecorDef): boolean
		return profile.decorOwned[def.id] == true
			and profile.decorPlaced[def.id] == true
			and not replaced[def.id]
	end
	-- Shop pieces, each on its own anchor.
	for _, def in Catalog.decor do
		showDecor(plot, def, if inUse(def) then plot.decorAnchors[def.id] else nil)
	end
	-- Crate furniture and decorations (F53) take the decor spots in catalog order; the F48 Index pieces among them
	-- keep their own anchors.
	local nextSpot = 1
	for _, def in Catalog.crateDecor do
		if not Crates.takesSpot(def) then
			continue
		end
		local anchor: BasePart? = plot.decorAnchors[def.id]
		local spot: BasePart? = nil
		if anchor ~= nil then
			spot = if inUse(def) then anchor else nil
		elseif inUse(def) then
			spot = plot.decorSpots[nextSpot]
			nextSpot += 1
		end
		showDecor(plot, def, spot)
	end
	-- The wallpaper, floor and paint in use, by decor id, for the client to colour the cafe's tagged shell parts.
	for _, slot in Crates.STYLE_SLOTS do
		plot.model:SetAttribute(slot.attribute, Crates.styleInUse(profile, slot.kind))
	end
	-- The door set and cat flap in use, by decor id, and their models (F80).
	for _, slot in Crates.MODEL_SLOTS do
		plot.model:SetAttribute(slot.attribute, Crates.styleInUse(profile, slot.kind))
	end
	refreshDoors(plot, profile)
end

-- Tables and their chairs, one per tables level. Each chair carries the customers' way to it (CustomerController):
-- Aisle, beside the aisle on the chair's side at its row's lane, then Approach, on the lane in line with the chair,
-- so nobody walks through a table (Layout.plot.tables).
local function refreshTables(plot: WorldBuilder.Plot, profile: Profile)
	local count = math.min(Economy.level(profile, "tables"), #plot.tableAnchors)
	for i, anchor in plot.tableAnchors do
		local spot = Layout.plot.tables[i]
		local name = "table_" .. i
		local existing = plot.tables:FindFirstChild(name)
		if i > count then
			if existing ~= nil then
				existing:Destroy()
			end
		elseif existing == nil then
			local group = Instance.new("Model")
			group.Name = name
			local tableModel = AssetRegistry.clone("CatCafe_Furniture_TableRound")
			tableModel:PivotTo(anchor.CFrame)
			tableModel.Parent = group
			for s, offset in Layout.plot.seatOffsets do
				local chair = AssetRegistry.clone("CatCafe_Furniture_Chair")
				chair.Name = "Chair_" .. s
				chair:PivotTo(
					anchor.CFrame
						* CFrame.new(offset.x, offset.y, offset.z)
						* CFrame.Angles(0, math.rad(offset.rotY or 0), 0)
				)
				if spot ~= nil then
					local x = spot.x + offset.x
					local side = if x < 0 then -1 else 1
					chair:SetAttribute(
						"Aisle",
						(plot.cframe * CFrame.new(side * Layout.plot.aisleX, 0, spot.lane)).Position
					)
					chair:SetAttribute(
						"Approach",
						(plot.cframe * CFrame.new(x, 0, spot.lane)).Position
					)
				end
				chair.Parent = group
			end
			group.Parent = plot.tables
		end
	end
end

-- Cafe expansions (data-model section 5b): expansion n opens at Tier n + 1 as a patio section in the yard. The
-- back door is open whenever the plot has an owner (layout v2).
local function refreshExpansions(plot: WorldBuilder.Plot, profile: Profile)
	local tier = Economy.tier(profile)
	for n, expansion in plot.expansions do
		WorldBuilder.setExpansionOpen(expansion, tier >= n + 1)
	end
	WorldBuilder.setBackDoorOpen(plot, tier >= 1) -- layout v2: every owned cafe's back door opens onto the alley
end

local function refreshEspresso(plot: WorldBuilder.Plot, profile: Profile)
	local level = math.clamp(Economy.level(profile, "espresso"), 1, 3)
	local assetName = "CatCafe_Furniture_EspressoMachine_L" .. level
	local existing = plot.model:FindFirstChild("Espresso")
	if existing ~= nil and existing:GetAttribute("Asset") == assetName then
		return
	end
	if existing ~= nil then
		existing:Destroy()
	end
	local model = AssetRegistry.clone(assetName)
	model.Name = "Espresso"
	model:SetAttribute("Asset", assetName)
	model:PivotTo(plot.espresso.CFrame)
	model.Parent = plot.model
end

-- The Lucky Cat statue in the front garden (F88, luck-and-rare-moments.md section 1): CatCafe_Plot_LuckyCat_<level>,
-- level 0 a plinth and sign before the first level is bought, swapped when the level changes. Named LuckyCat and
-- tagged LuckyCat, with its Level attribute, for the client's effects: the paw wave (the <asset>_Paw child) of
-- levels 1 to 5 and the level up sparkle.
local function refreshLuckyCat(plot: WorldBuilder.Plot, profile: Profile)
	local level = math.clamp(Economy.level(profile, Luck.UPGRADE), 0, 5)
	local assetName = "CatCafe_Plot_LuckyCat_" .. level
	local existing = plot.model:FindFirstChild("LuckyCat")
	if existing ~= nil and existing:GetAttribute("Asset") == assetName then
		return
	end
	if existing ~= nil then
		existing:Destroy()
	end
	local model = AssetRegistry.clone(assetName)
	model.Name = "LuckyCat"
	model:SetAttribute("Asset", assetName)
	model:SetAttribute("Level", level)
	CollectionService:AddTag(model, "LuckyCat")
	model:PivotTo(plot.luckyCat.CFrame)
	model.Parent = plot.model
end

-- The bait bowl in the front garden (data-model section 8): the bowl once the upgrade is bought, the food in it
-- while a cat is on its way and the cat itself, eating, once it has arrived, so the street sees it. The item
-- models are tiny, so they are scaled up to read from the path. BaitReadyAt is for display only.
local BOWL_SCALE = 2
local FOOD_SCALE = 1.2 -- the food item sits in the bowl

-- One bowl's models in its folder (#1161: bowl 1 in Bait/, bowl 2 in Bait2/). `shown` is whether the bowl stands.
local function refreshBowl(
	player: Player,
	folder: Folder,
	bowlAnchor: BasePart,
	catAnchor: BasePart,
	profile: Profile,
	shown: boolean,
	bait: Types.BaitState?
)
	if not shown then
		folder:ClearAllChildren()
		return
	end
	local readyAt = if bait ~= nil then CafeService.baitReadyAt(profile, bait) else 0
	local ready = bait ~= nil and os.time() >= readyAt

	if folder:FindFirstChild("Bowl") == nil then
		local bowl = AssetRegistry.clone("CatCafe_Item_FoodBowl")
		bowl.Name = "Bowl"
		bowl:ScaleTo(BOWL_SCALE)
		bowl:PivotTo(bowlAnchor.CFrame)
		bowl.Parent = folder
	end

	local lureId = if bait ~= nil then bait.lureId else nil
	local food = folder:FindFirstChild("Food")
	if food ~= nil and food:GetAttribute("LureId") ~= lureId then
		food:Destroy()
		food = nil
	end
	local lure = if lureId ~= nil then Catalog.getLure(lureId) else nil
	if food == nil and lure ~= nil then
		local model = AssetRegistry.clone(lure.asset)
		model.Name = "Food"
		model:SetAttribute("LureId", lure.id)
		model:ScaleTo(FOOD_SCALE)
		model:PivotTo(bowlAnchor.CFrame * CFrame.new(0, 0.1, 0))
		model.Parent = folder
	end

	-- one cat per food: the key changes with each new food, so a stale cat never stays
	local key = if ready and bait ~= nil
		then string.format("%s@%d", bait.catId, bait.placedAt)
		else nil
	local cat = folder:FindFirstChild("Cat")
	if cat ~= nil and cat:GetAttribute("BaitKey") ~= key then
		cat:Destroy()
		cat = nil
	end
	local def = if key ~= nil and bait ~= nil then Catalog.getCat(bait.catId) else nil
	if cat == nil and key ~= nil and bait ~= nil and def ~= nil then
		local model = AssetRegistry.cloneCat(bait.catId, bait.variant)
		model.Name = "Cat"
		model:SetAttribute("BaitKey", key)
		model:SetAttribute("CatId", bait.catId)
		model:SetAttribute("Rarity", def.rarity)
		model:SetAttribute("Gold", bait.variant == "gold")
		model:SetAttribute("Variant", bait.variant) -- F99: a rainbow bait cat shows its coat as it arrives
		model:SetAttribute("OwnerUserId", player.UserId)
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		model:PivotTo(catAnchor.CFrame)
		model.Parent = folder
	end
end

local function refreshBait(player: Player, plot: WorldBuilder.Plot, profile: Profile)
	local owned = Economy.level(profile, "lure_bowl") >= 1
	local bait = if owned then profile.bait else nil
	plot.model:SetAttribute(
		"BaitReadyAt",
		if bait ~= nil then CafeService.baitReadyAt(profile, bait) else 0
	)
	refreshBowl(player, plot.bait, plot.baitBowl, plot.baitCat, profile, owned, bait)
	-- #1161: the second bowl stands while it is "on", and while food is still in it without the pass (a refund),
	-- so that food's cat can still be tamed or let go
	local bait2 = if owned then profile.bait2 else nil
	local shown2 = owned and (bait2 ~= nil or CafeService.secondBowl(player, profile) == "on")
	plot.model:SetAttribute(
		"BaitReadyAt2",
		if bait2 ~= nil then CafeService.baitReadyAt(profile, bait2) else 0
	)
	refreshBowl(player, plot.bait2, plot.baitBowl2, plot.baitCat2, profile, shown2, bait2)
end

function CafeService.refreshPlot(player: Player)
	local profile = DataService.get(player)
	local plot = PlotService.get(player)
	if profile == nil or plot == nil then
		return
	end
	refreshSpots(plot, profile)
	refreshExpansions(plot, profile)
	refreshEspresso(plot, profile)
	refreshLuckyCat(plot, profile)
	refreshDecor(plot, profile) -- before the cats: at night they sleep on decor cat trees (F79, review S89)
	refreshCats(player, plot, profile)
	refreshTables(plot, profile)
	refreshBait(player, plot, profile)
	LawnBuilder.refresh(plot, profile) -- F91: the front lawn's pieces, path and fence
end

-- F91 (front-lawn.md section 1b): the front lawn pieces the cafe's tier has earned and it does not own yet (a Garden
-- Bench at Tier 2, an Umbrella Table at Tier 3), each placed in an empty big spot when there is one, with a toast.
-- Rank up and load both call it, so a cafe already past those tiers when the lawn arrives gets them too. Only once the
-- lawn's art is in, so nothing is given that the player cannot see.
-- #1283 (lawn-nursery.md section 6b): then it lays the best lawn (Lawn.applyBest), which fills the spots a rank up
-- opens and, on a save's first load after #1283, replaces a lawn placed by hand. Pieces out add money, so what was
-- earned so far settles at the old rate first.
local function giveLawnGifts(player: Player, profile: Profile)
	if not WorldBuilder.lawnLive() then
		return
	end
	Economy.settle(profile, os.time(), ClockService.epoch())
	local names: { string } = {}
	for _, id in Lawn.grantTierGifts(profile) do
		local piece = Catalog.getLawn(id)
		if piece ~= nil then
			local article = if piece.name:match("^[AEIOU]") ~= nil then "an " else "a "
			table.insert(names, article .. piece.name)
		end
	end
	if #names > 0 then
		Net.toast(
			player,
			string.format("Your front lawn got %s, free!", table.concat(names, " and ")),
			"good"
		)
	end
	Lawn.applyBest(profile)
end

-- Bedtime (F79, BedtimeService) ----------------------------------------------------------------------------------

-- Gets the working cat `uid` up for a bedtime trip to `sleepSpot`, or back from one: its model goes onto the walking
-- body without the outfit where it is now, with Bedtime and SleepSpot, and Asleep false. With `stretch` it stretches
-- first (StretchAt, the server time the client plays the get-up stretch from). Returns the new model, or nil when the
-- cat has no model in the cafe or no longer works there.
function CafeService.bedtimeBody(
	player: Player,
	uid: string,
	sleepSpot: string,
	stretch: boolean
): Model?
	local profile = DataService.get(player)
	local plot = PlotService.get(player)
	local old = if plot ~= nil then plot.cats:FindFirstChild(uid) else nil
	local instance = if profile ~= nil then profile.cats[uid] else nil
	if
		profile == nil
		or plot == nil
		or old == nil
		or not old:IsA("Model")
		or instance == nil
		or instance.spotId == nil
	then
		return nil
	end
	local slot = old:GetAttribute("Slot")
	local multiplier = Economy.cafeMultiplier(profile) * Economy.tierMultiplier(profile)
	local model = buildCat(
		player,
		instance,
		if type(slot) == "string" then slot else instance.spotId :: string,
		(old :: Model):GetPivot(),
		multiplier,
		profile.tier,
		sleepSpot
	)
	model:SetAttribute("Asleep", false)
	if stretch then
		model:SetAttribute("StretchAt", Workspace:GetServerTimeNow())
	end
	old:Destroy()
	model.Parent = plot.cats
	return model
end

-- Ends the working cat `uid`'s bedtime trip back to its station: it sits there again on the seated body in its
-- outfit, as refreshCats builds it by day.
function CafeService.endBedtime(player: Player, uid: string)
	local profile = DataService.get(player)
	local plot = PlotService.get(player)
	if profile == nil or plot == nil then
		return
	end
	local model = plot.cats:FindFirstChild(uid)
	if model ~= nil then
		model:Destroy()
	end
	refreshCats(player, plot, profile)
end

-- "$2.6/s", "$12/s": the HUD's rounding (one decimal under 10), so the toast and the income pill agree.
local function rateText(perSecond: number): string
	local value = if perSecond >= 10
		then string.format("%.0f", perSecond)
		else string.format("%.1f", perSecond)
	return "$" .. (value:gsub("%.0$", "")) .. "/s"
end

-- What the street sees of this cafe, kept current on every sync because level ups change rates between refreshes:
-- the cats in it and their Rate tags, and the plot's tier name, rate and sign.
local function refreshShowcase(player: Player, profile: Profile)
	local plot = PlotService.get(player)
	if plot == nil then
		return
	end
	refreshCats(player, plot, profile)
	local tierDef = Catalog.getTier(Economy.tier(profile))
	local tierName = if tierDef ~= nil then tierDef.name else ""
	-- the plot's Rate stays the day rate (the street's CafeSigns apply the night share themselves); the sign's own
	-- line shows what the cafe earns now
	local rate = Economy.incomePerSecond(profile)
	PlotService.setShowcase(
		player,
		tierName,
		rate,
		tierName .. "  " .. rateText(currentRate(profile))
	)
	Leaderstats.update(
		player,
		currentRate(profile),
		ProfileSchema.collectionCount(profile),
		tierName
	)
end

-- Sends CatLevelUp(uid, level) for each cat whose level rose since the last sync (data-model section 4b, F75). XP is
-- granted in every settle, and the periodic sync settles every SyncIntervalSeconds, so a level up shows within that.
-- A player's first sync and a cat new since the last one only record the level: nothing levelled up that anyone saw.
local function announceLevelUps(player: Player, profile: Profile)
	if player.Parent == nil then
		knownLevels[player] = nil
		return
	end
	local known = knownLevels[player]
	local levels: { [string]: number } = {}
	for uid, instance in profile.cats do
		local level = CatStats.level(instance)
		levels[uid] = level
		local before = if known ~= nil then known[uid] else nil
		if before ~= nil and level > before then
			Net.fire(player, "CatLevelUp", uid, level)
		end
	end
	knownLevels[player] = levels
end

function CafeService.sync(player: Player)
	local profile = profileFor(player)
	if profile == nil then
		return
	end
	-- F98: the Money board's best rate, all time and this week, as of every sync
	Leaderboards.noteRate(profile, Leaderboards.moneyRate(profile), os.time())
	Net.fire(player, "ProfileSync", CafeService.buildState(player, profile))
	-- the net upgrade bought, on the Player for the net in hand every client shows (Effects, #527); a set that
	-- changes nothing does not replicate
	player:SetAttribute("NetLevel", Economy.level(profile, "net"))
	refreshShowcase(player, profile)
	announceLevelUps(player, profile) -- after both, so the card and the model's Level are already the new level
end

-- Mutations used by other services -----------------------------------------------------------------------

local function newUid(): string
	return CatStats.uidFromGuid(HttpService:GenerateGUID(false))
end

-- Moves the tutorial on to `step` when it is behind, and logs tutorial_step for every step it passes, as
-- TutorialAdvance does for the steps the client reports, so a step skipped over (an upgrade bought from step 3, a
-- catch before the alley step) still counts and never reads as a drop in the funnel.
function CafeService.advanceTutorial(player: Player, profile: Profile, step: number)
	local from = profile.tutorialStep
	if from < step then
		profile.tutorialStep = step
		for passed = from + 1, step do
			Telemetry.custom(player, "tutorial_step", 1, { tostring(passed) })
		end
	end
end

-- Adds a caught cat to the profile, pays the first-catch reward, puts it to work in a free open role slot.
-- Returns the instance and whether this cat id was new to the collection.
-- `knownProfile` is passed on the save-on-leave path, where the session is closing and a lookup must not race it.
-- `charm` is the stray's roll when the caller has one (CatService can roll it at spawn and show stars on the
-- prompt); otherwise it is rolled here.
-- `method` is how the cat was found, "net" when nil; "rescue" also sets the rescued flag. `variant` keeps a gold or
-- rainbow (F99) roll made before the cat was owned (a bait cat when the food went in, a stuck cat at night start).
function CafeService.addCaughtCat(
	player: Player,
	def: Types.CatDef,
	notify: boolean,
	knownProfile: Profile?,
	charm: number?,
	method: Types.CatchMethod?,
	variant: string?
): (Types.CatInstance, boolean)
	local profile = knownProfile
	if profile ~= nil then
		Economy.settle(profile, os.time(), ClockService.epoch())
	else
		profile = profileFor(player)
	end
	assert(profile ~= nil, "profile not loaded")
	local now = os.time()
	local isNew = profile.collection[def.id] == nil
	local rolled = if charm ~= nil
		then charm
		else CatStats.rollCharm(rng:NextNumber(), rng:NextNumber())
	local instance = CatStats.newInstance(newUid(), def.id, now, rolled)
	local how: Types.CatchMethod = method or "net"
	instance.method = how
	local howText: string = how -- analytics fields are plain strings
	if method == "rescue" then
		instance.rescued = true
	end
	local firstGold = false
	local firstRainbow = false
	if variant ~= nil then
		instance.variant = variant
		if variant == "rainbow" then
			-- F99 (rainbow-coat.md section 5): the Rainbow page counts each cat's first rainbow coat
			firstRainbow = profile.rainbowCollection[def.id] == nil
			if firstRainbow then
				profile.rainbowCollection[def.id] = now
			end
			Telemetry.custom(
				player,
				"rainbow_found",
				1,
				{ def.rarity :: string, howText, if firstRainbow then "yes" else "no" }
			)
		elseif variant == "gold" then
			firstGold = profile.goldCollection[def.id] == nil
			if firstGold then
				profile.goldCollection[def.id] = now
			end
			Telemetry.custom(
				player,
				"gold_found",
				1,
				{ howText, def.rarity, if firstGold then "yes" else "no" }
			)
		end
	end
	-- F62: gold, Legendary and Mythical cats arrive locked
	if CatStats.arrivesLocked(def.id, instance.variant) then
		instance.locked = true
	end
	profile.cats[instance.uid] = instance
	profile.stats.catsCaught += 1
	-- F73: the quest and achievement counters that follow catsCaught (net, rescue and bait alike)
	if (Catalog.rarityRank[def.rarity] or 0) >= Catalog.rarityRank.Rare then
		profile.stats.rareCatches += 1
	end
	if instance.variant == "gold" then
		profile.stats.goldCatches += 1
	elseif instance.variant == "rainbow" then
		profile.stats.rainbowCatches += 1
	end
	Telemetry.custom(player, "cat_caught", 1, { def.id, howText, instance.variant })
	if isNew then
		profile.collection[def.id] = now
		local reward = Catalog.rarities[def.rarity].firstCatchReward
		Economy.credit(profile, reward)
		-- the starter cat is the first book entry, so two entries means this was the player's first new cat
		local first = ProfileSchema.collectionCount(profile) <= 2
		Telemetry.source(
			player,
			profile,
			reward,
			if first then "Onboarding" else "Gameplay",
			if first then "first_catch_reward" else "collection_reward"
		)
		Telemetry.collected(player, profile, def)
	end
	-- Golden fish (F52): a new Index entry, a first gold, a first rainbow (F99), or an Epic and better repeat by net
	-- or rescue
	local fish = GoldenFish.forCatch(def.rarity, isNew, firstGold, how, firstRainbow)
	if fish > 0 then
		GoldenFish.credit(profile, fish)
		Telemetry.fishSource(
			player,
			profile,
			fish,
			"Gameplay",
			if isNew or firstGold then "first_catch" else "repeat_catch"
		)
	end
	-- F87 (easy-start.md section 2d): the first check-in, before it moves the tutorial on
	local firstCheckIn = profile.tutorialStep < Config.TutorialGuaranteedStrayStep
	CafeService.advanceTutorial(player, profile, 2)

	-- #1534 (Derek2 2026-11-05: "best cat/cats depending on how many spots"): the best cats take the open role
	-- slots, so a better new cat takes the place of a weaker one, and the first cat still takes its job by itself
	-- (F87 section 2d)
	CafeService.autoEquip(player, profile)
	if instance.spotId == nil then
		Telemetry.custom(player, "slots_full", 1, { tostring(Economy.tier(profile)) })
	end
	-- funnel steps (easy-start.md section 5): a second cat checked in, five different cats owned
	if profile.stats.catsCaught >= 2 then
		Telemetry.onboarding(player, profile, "second_cat")
	end
	if Economy.distinctCats(profile) >= 5 then
		Telemetry.onboarding(player, profile, "five_cats")
	end

	CafeService.refreshPlot(player)
	if notify then
		-- F87 context tips (easy-start.md section 3): the first check-in ends the newcomer shield; a second cat wants
		-- a job. The like ask's moment (a first Legendary or better) is TipService's since F96 (Tips.dueAsk).
		if firstCheckIn then
			TipService.show(player, "tackle")
		end
		if profile.stats.catsCaught >= 2 then
			TipService.show(player, "second_cat")
		end
		if isNew then
			Net.toast(
				player,
				string.format(
					"New cat! %s joins the collection (+$%d, %s)",
					def.name,
					Catalog.rarities[def.rarity].firstCatchReward,
					fishText(fish)
				),
				"good"
			)
		elseif firstGold then
			Net.toast(player, string.format("First gold %s! %s", def.name, fishText(fish)), "good")
		elseif fish > 0 then
			Net.toast(
				player,
				string.format("%s %s again: %s", def.rarity, def.name, fishText(fish)),
				"good"
			)
		end
		local spot = if instance.spotId ~= nil
			then Catalog.getSpot(instance.spotId :: string)
			else nil
		if spot ~= nil and firstCheckIn then
			-- F87 section 2d: the first cat's card, with the cafe's new rate
			Net.toast(
				player,
				string.format(
					"Your first cat! %s is your %s now (%s)",
					def.name,
					roleName(spot),
					rateText(Economy.incomePerSecond(profile))
				),
				"good"
			)
		elseif spot ~= nil then
			-- F97 section 5: no charm stars on any cat text now
			Net.toast(
				player,
				string.format("%s is working as %s", def.name, roleName(spot)),
				"info"
			)
		else
			Net.toast(
				player,
				string.format(
					"%s is in the cat room. Every role is taken; give it one from there.",
					def.name
				),
				"info"
			)
		end
		CafeService.sync(player)
	end
	return instance, isNew
end

-- F96 (starter-cat.md section 2): a cat given, not caught (the free Bellhop Cat): level 1, base coat and `charm`,
-- method "starter". It joins the collection with no first-catch reward and counts toward no catch, quest or Index
-- (an exclusive cat). The best cats then take the open role slots (#1534), this one when it is among them; else it
-- rests.
function CafeService.addGiftCat(
	player: Player,
	profile: Profile,
	def: Types.CatDef,
	charm: number
): Types.CatInstance
	Economy.settle(profile, os.time(), ClockService.epoch())
	local now = os.time()
	local instance = CatStats.newInstance(newUid(), def.id, now, charm)
	instance.method = "starter"
	profile.cats[instance.uid] = instance
	if profile.collection[def.id] == nil then
		profile.collection[def.id] = now
	end
	CafeService.autoEquip(player, profile) -- #1534: the best cats take the slots, this one too when it is among them
	local spot = if instance.spotId ~= nil then Catalog.getSpot(instance.spotId :: string) else nil
	Net.toast(
		player,
		if spot ~= nil
			then string.format("The %s joined your cafe as your %s!", def.name, roleName(spot))
			else string.format(
				"The %s joined your cafe! It is resting in the cat room.",
				def.name
			),
		"good"
	)
	CafeService.refreshPlot(player)
	CafeService.sync(player)
	return instance
end

-- F102: TradeService registers how to tell a cat on offer in an open trade (selling, locking and the Cat Collector
-- wait for it).
function CafeService.setOfferCheck(check: (player: Player, uid: string) -> boolean)
	offerCheck = check
end

-- Whether `uid` is on offer in `player`'s open trade.
function CafeService.isOffered(player: Player, uid: string): boolean
	return offerCheck(player, uid)
end

-- #1574: TradeService registers how to tell a decor or lawn piece on offer (locking it waits for it).
function CafeService.setPieceOfferCheck(check: (player: Player, id: string) -> boolean)
	pieceOfferCheck = check
end

function CafeService.setCarrying(player: Player, catId: string?)
	carrying[player] = catId
	CafeService.sync(player)
end

function CafeService.carrying(player: Player): string?
	return carrying[player]
end

-- Remote handlers -----------------------------------------------------------------------------------------

local function onPlaceCat(player: Player, rawUid: unknown, rawSpot: unknown)
	local uid, spotId = Guard.id(rawUid), Guard.id(rawSpot)
	local profile = profileFor(player)
	if profile == nil or uid == nil or spotId == nil then
		return
	end
	local instance = profile.cats[uid]
	if instance == nil then
		return
	end
	local spot = Catalog.getSpot(spotId)
	if spot == nil then
		return
	end
	if not Economy.spotIsOpen(profile, spotId) then
		Net.toast(player, string.format("That role opens at Tier %d.", spot.tier), "warn")
		return
	end
	if Economy.catOnSpot(profile, spotId) ~= nil then
		Net.toast(player, "Another cat already has that role.", "warn")
		return
	end
	if instance.spotId ~= nil then
		Net.toast(player, "Take the cat off its current role first.", "warn")
		return
	end
	instance.spotId = spotId
	CafeService.advanceTutorial(player, profile, 3)
	Telemetry.onboarding(player, profile, "first_role_assigned")
	Telemetry.catWorking(player, uid)
	local catDef = Catalog.getCat(instance.catId)
	Telemetry.custom(player, "role_favorite", 1, {
		instance.catId,
		spot.spotType,
		if catDef ~= nil and catDef.favoriteRole == spot.spotType then "yes" else "no",
	})
	CafeService.refreshPlot(player)
	CafeService.sync(player)
end

local function onUnplaceCat(player: Player, rawUid: unknown)
	local uid = Guard.id(rawUid)
	local profile = profileFor(player)
	if profile == nil or uid == nil then
		return
	end
	local instance = profile.cats[uid]
	if instance == nil or instance.spotId == nil then
		return
	end
	instance.spotId = nil
	CafeService.refreshPlot(player)
	CafeService.sync(player)
end

-- #1534 (issue, Derek2 2026-11-05: "best cat/cats depending on how many spots"): the best cats take the open role
-- slots by themselves, as Equip Best would place them, at each join, rank up, new slot (the Extra Slot pass), new
-- cat and trade. A better cat takes the place of a weaker one; the cats left over rest (CafeService's nap spots,
-- then the sleep spots by day). Earnings so far settle at the old rate first. Returns how many cats changed spot;
-- the caller refreshes the plot and syncs.
function CafeService.autoEquip(player: Player, profile: Profile): number
	local plan = EquipBest.plan(profile)
	if EquipBest.isOptimal(profile, plan) then
		return 0
	end
	Economy.settle(profile, os.time(), ClockService.epoch())
	local before: { [string]: string? } = {}
	for uid, instance in profile.cats do
		before[uid] = instance.spotId
	end
	local changed = EquipBest.apply(profile, plan)
	for uid, instance in profile.cats do
		-- only the cats that took a new spot, so a join or rank up doesn't log the whole cafe again
		if instance.spotId ~= nil and instance.spotId ~= before[uid] then
			Telemetry.catWorking(player, uid)
		end
	end
	if plan.catsPlaced > 0 then
		CafeService.advanceTutorial(player, profile, 3)
		Telemetry.onboarding(player, profile, "first_role_assigned")
	end
	return changed
end

-- Equip best: one tap gives the owned cats the open role slots for the highest rate (shared/EquipBest).
-- Nothing is bought or sold, so the only check is that the profile is loaded; the plan itself only ever
-- uses slots this tier has opened and cats this player owns.
local function onEquipBest(player: Player)
	local profile = profileFor(player)
	if profile == nil then
		return
	end
	local plan = EquipBest.plan(profile)
	if EquipBest.isOptimal(profile, plan) then
		Net.toast(player, "Your cats are already in their best roles.", "info")
		CafeService.sync(player)
		return
	end
	local changed = EquipBest.apply(profile, plan)
	for uid, instance in profile.cats do
		if instance.spotId ~= nil then
			Telemetry.catWorking(player, uid)
		end
	end
	if plan.catsPlaced > 0 then
		CafeService.advanceTutorial(player, profile, 3)
		Telemetry.onboarding(player, profile, "first_role_assigned")
	end
	Net.toast(
		player,
		string.format(
			"%d cats working in %d roles (%d moved): %s",
			plan.catsPlaced,
			plan.spotsOpen,
			changed,
			rateText(currentRate(profile))
		),
		"good"
	)
	CafeService.refreshPlot(player)
	CafeService.sync(player)
end

-- Unequip all (UI thread, the cat inventory's Unequip All button): every working cat rests in the cat room. Like
-- equip best, nothing is bought or sold, so the only check is that the profile is loaded.
local function onUnequipAll(player: Player)
	local profile = profileFor(player)
	if profile == nil then
		return
	end
	local rested = EquipBest.restAll(profile)
	if rested == 0 then
		Net.toast(player, "No cats are working right now.", "info")
		CafeService.sync(player)
		return
	end
	Net.toast(
		player,
		string.format(
			"%d %s resting in the cat room.",
			rested,
			if rested == 1 then "cat is" else "cats are"
		),
		"info"
	)
	CafeService.refreshPlot(player)
	CafeService.sync(player)
end

local function onSellCat(player: Player, rawUid: unknown)
	local uid = Guard.id(rawUid)
	local profile = profileFor(player)
	if profile == nil or uid == nil then
		return
	end
	local instance = profile.cats[uid]
	if instance == nil then
		return
	end
	if ProfileSchema.catCount(profile) <= 1 then
		Net.toast(player, "You cannot sell your last cat.", "warn")
		return
	end
	if instance.locked == true then
		Net.toast(player, "This cat is locked. Unlock it to sell it.", "warn")
		return
	end
	if offerCheck(player, uid) then
		Net.toast(player, Trade.Messages.catInTrade, "warn") -- F102: take it off the offer first
		return
	end
	local def = Catalog.getCat(instance.catId)
	if def == nil then
		return
	end
	if def.exclusive == true then
		-- F95 and F96: an exclusive cat can be locked but never sold
		Net.toast(
			player,
			string.format("The %s stays with you. Exclusive cats cannot be sold.", def.name),
			"warn"
		)
		return
	end
	profile.cats[uid] = nil
	profile.stats.catsSold += 1
	local value = Catalog.rarities[def.rarity].sellValue
	Economy.credit(profile, value)
	Telemetry.source(player, profile, value, "Gameplay", "sell_cat")
	Telemetry.custom(player, "cat_sold", 1, { instance.catId, instance.variant })
	Net.toast(player, string.format("Sold %s for $%d", def.name, value), "good")
	CafeService.refreshPlot(player)
	CafeService.sync(player)
end

-- F62 (section 4): the lock icon on a cat card. A locked cat cannot be sold or traded to the Cat Collector.
local function onLockCat(player: Player, rawUid: unknown, rawLocked: unknown)
	local uid = Guard.id(rawUid)
	local profile = profileFor(player)
	if profile == nil or uid == nil or type(rawLocked) ~= "boolean" then
		return
	end
	local instance = profile.cats[uid]
	if instance == nil then
		return
	end
	if rawLocked and offerCheck(player, uid) then
		Net.toast(player, Trade.Messages.catInTrade, "warn") -- F102: a locked cat cannot be on offer
		CafeService.sync(player)
		return
	end
	instance.locked = if rawLocked then true else nil
	CafeService.sync(player)
end

-- #1574 (trading.md section 1b): the lock on a decor or lawn card. Only a Legendary and up piece has one; it arrives
-- locked and must be unlocked here before it can go on offer, and one on offer cannot be locked.
local function onLockDecor(player: Player, rawId: unknown, rawLocked: unknown)
	local id = Guard.id(rawId)
	local profile = profileFor(player)
	if profile == nil or id == nil or type(rawLocked) ~= "boolean" then
		return
	end
	local info = Trade.piece(id)
	if info == nil or not Trade.ownsPiece(profile, id) or not Trade.lockable(info.rarity) then
		return
	end
	if rawLocked and pieceOfferCheck(player, id) then
		Net.toast(player, Trade.Messages.pieceInTrade, "warn")
		CafeService.sync(player)
		return
	end
	profile.decorUnlocked[id] = if rawLocked then nil else true
	CafeService.sync(player)
end

-- #1574: after a trade moved decor or lawn pieces, the best owned pieces go out (as EquipBestDecor, without its toast).
function CafeService.autoEquipDecor(_player: Player, profile: Profile)
	local cap = Crates.spotCap(Economy.tier(profile), profile.fishPerks.extra_decor_spot or 0)
	profile.decorPlaced = DecorBest.plan(profile, cap).placed
	if WorldBuilder.lawnLive() then
		Lawn.applyBest(profile)
	end
end

local function onBuyUpgrade(player: Player, rawId: unknown)
	local upgradeId = Guard.id(rawId)
	local profile = profileFor(player)
	if profile == nil or upgradeId == nil then
		return
	end
	local blocker = Economy.upgradeBlocker(profile, upgradeId)
	if blocker ~= nil then
		Net.toast(player, blocker, "warn")
		CafeService.sync(player)
		return
	end
	local cost = Economy.nextUpgradeCost(profile, upgradeId) :: number
	if not Economy.trySpend(profile, cost) then
		Net.toast(player, "Not enough coins", "warn")
		return
	end
	Telemetry.sink(player, profile, cost, "Shop", upgradeId)
	profile.upgradeLevels[upgradeId] = Economy.level(profile, upgradeId) + 1
	if upgradeId == "tables" then
		-- a player who already baited the bowl has done step 5's task too (reviewer S48)
		CafeService.advanceTutorial(player, profile, if profile.stats.luresUsed > 0 then 5 else 4)
		Telemetry.onboarding(player, profile, "first_table")
	elseif upgradeId == "lure_bowl" then
		Telemetry.onboarding(player, profile, "bowl_bought")
		-- #1281: food is sold at the Corner Shop now, so a first bowl comes with one Kibble for the tutorial's last
		-- step ("Put Kibble in your bowl"); a player who already has food or has baited before gets none
		local held = 0
		for _, count in profile.lures do
			held += count
		end
		if profile.stats.luresUsed == 0 and held <= 0 then
			profile.lures.kibble = 1
		end
	end
	local def = Catalog.getUpgrade(upgradeId) :: Types.UpgradeDef
	Net.toast(
		player,
		string.format("%s is now level %d", def.name, profile.upgradeLevels[upgradeId]),
		"good"
	)
	CafeService.refreshPlot(player)
	CafeService.sync(player)
end

-- Next tier (data-model section 5b): every requirement is checked again here, then the cost is spent. Nothing
-- resets; the new role slots, caps, decor and area open from the tier itself.
local function onRankUp(player: Player)
	local profile = profileFor(player)
	if profile == nil then
		return
	end
	local blocker = Economy.rankUpBlocker(profile)
	if blocker ~= nil then
		Net.toast(player, blocker, "warn")
		CafeService.sync(player)
		return
	end
	local def = Catalog.getTier(Economy.tier(profile) + 1) :: Types.TierDef
	if not Economy.trySpend(profile, def.cost) then
		Net.toast(player, "Not enough coins", "warn")
		return
	end
	Telemetry.sink(player, profile, def.cost, "Gameplay", "rank_up_" .. def.tier)
	profile.tier = def.tier
	Telemetry.rankedUp(player, profile)
	local fish = GoldenFish.forRankUp(def.tier) -- F52
	GoldenFish.credit(profile, fish)
	Telemetry.fishSource(player, profile, fish, "Gameplay", "rank_up")
	local area = Catalog.getArea(def.area)
	Net.toast(
		player,
		string.format(
			"Your cafe is now a %s! %s is open and %d role slots are ready%s.",
			def.name,
			if area ~= nil then area.name else def.area,
			def.slots,
			if fish > 0 then string.format(", and you got %d golden fish", fish) else ""
		),
		"good"
	)
	Net.fireAll("Announce", string.format("%s's cafe is now a %s!", player.DisplayName, def.name))
	giveLawnGifts(player, profile) -- F91: a Garden Bench at Tier 2, an Umbrella Table at Tier 3
	CafeService.autoEquip(player, profile) -- #1534: the new slots take the best resting cats
	print(string.format("[CafeService] %s ranked up to Tier %d", player.Name, def.tier))
	CafeService.refreshPlot(player)
	CafeService.sync(player)
	LeaderboardService.rankedUp(player) -- F98: after the sync noted the new rate
end

local function onBuyDecor(player: Player, rawId: unknown)
	local decorId = Guard.id(rawId)
	local profile = profileFor(player)
	if profile == nil or decorId == nil then
		return
	end
	local blocker = Economy.decorBlocker(profile, decorId)
	if blocker ~= nil then
		Net.toast(player, blocker, "warn")
		CafeService.sync(player)
		return
	end
	local def = Catalog.getDecor(decorId) :: Types.DecorDef
	if not Economy.trySpend(profile, def.cost) then
		Net.toast(player, "Not enough coins", "warn")
		return
	end
	Telemetry.sink(player, profile, def.cost, "Shop", decorId)
	profile.decorOwned[decorId] = true
	profile.decorPlaced[decorId] = true
	Net.toast(player, string.format("%s placed (%s)", def.name, def.effect), "good")
	CafeService.refreshPlot(player)
	CafeService.sync(player)
end

local function onToggleDecor(player: Player, rawId: unknown, rawPlaced: unknown)
	local decorId, placed = Guard.id(rawId), Guard.bool(rawPlaced)
	local profile = profileFor(player)
	if profile == nil or decorId == nil or placed == nil then
		return
	end
	local def = Catalog.getDecor(decorId)
	if def == nil or not profile.decorOwned[decorId] then
		return
	end
	if placed and Crates.isStyle(def.kind) then
		-- one wallpaper, floor, paint, door set and cat flap: the new one takes the old one's place (F53, F80)
		local current = Crates.styleInUse(profile, def.kind :: Types.DecorKind)
		if current ~= nil then
			profile.decorPlaced[current] = nil
		end
	elseif placed and Crates.takesSpot(def) and not profile.decorPlaced[decorId] then
		local cap = Crates.spotCap(Economy.tier(profile), profile.fishPerks.extra_decor_spot or 0)
		if Crates.spotsUsed(profile, Economy.replacedDecor(profile)) >= cap then
			Net.toast(player, "Every decor spot is full. Put a piece away first.", "warn")
			CafeService.sync(player)
			return
		end
	end
	if placed then
		profile.decorPlaced[decorId] = true
	else
		profile.decorPlaced[decorId] = nil
	end
	CafeService.refreshPlot(player)
	CafeService.sync(player)
end

-- Equip Best for decor (Derek 2026-10-28): the best owned pieces out for the most money (shared/DecorBest), the rest
-- put away, then one toast and a sync. Only owned pieces move. Since #1283 (lawn-nursery.md section 6b) it lays the
-- best lawn too (Lawn.applyBest; the server keeps it best anyway) and the toast counts both.
local function onEquipBestDecor(player: Player)
	local profile = profileFor(player)
	if profile == nil then
		return
	end
	local cap = Crates.spotCap(Economy.tier(profile), profile.fishPerks.extra_decor_spot or 0)
	local plan = DecorBest.plan(profile, cap)
	local lawnChanged = WorldBuilder.lawnLive() and Lawn.applyBest(profile)
	local lawnBonus, lawnOut = Lawn.bonus(profile)
	if plan.pieces == 0 and lawnOut == 0 then
		Net.toast(player, "No decor yet. Find some in the Market's crates.", "info")
		CafeService.sync(player)
		return
	end
	local what = if lawnOut > 0 then "decor and lawn" else "decor"
	if DecorBest.isSame(profile, plan) and not lawnChanged then
		Net.toast(
			player,
			string.format("Your best %s %s already out.", what, if lawnOut > 0 then "are" else "is"),
			"info"
		)
		CafeService.sync(player)
		return
	end
	profile.decorPlaced = plan.placed
	CafeService.refreshPlot(player)
	Net.toast(
		player,
		string.format(
			"Best %s out: +%d%% money",
			what,
			math.floor((plan.bonus + lawnBonus) * 100 + 0.5)
		),
		"good"
	)
	CafeService.sync(player)
end

-- #1281 (corner-shop-v2.md section 1b): the bowl foods are sold at the Corner Shop now (its "bait" rows), so every
-- BuyLure is refused with a pointer there. The remote goes in the next cleanup.
local function onBuyLure(player: Player, _rawId: unknown)
	if profileFor(player) == nil then
		return
	end
	Net.toast(player, "Bait food is at the Corner Shop now", "info")
end

local function onClaimOffline(player: Player)
	local profile = profileFor(player)
	if profile == nil then
		return
	end
	local amount, seconds = DataService.takePendingOffline(player)
	if amount <= 0 then
		return
	end
	Economy.credit(profile, amount)
	Telemetry.source(player, profile, amount, "TimedReward", "offline")
	local cap = if Economy.passes(profile).longNap
		then Config.OfflineCapPassSeconds
		else Config.OfflineCapSeconds
	-- F95 raised the cap from an hour to 8 (16 with Long Nap), so an hour or more uncapped is "60+"
	local away = if seconds >= cap
		then "capped"
		elseif seconds < 15 * 60 then "0-14"
		elseif seconds < 60 * 60 then "15-59"
		else "60+"
	Telemetry.custom(player, "offline_claim", amount, { away })
	Telemetry.onboarding(player, profile, "first_offline_claim")
	Net.toast(player, string.format("Welcome back! +$%d while you were away", amount), "good")
	CafeService.sync(player)
end

local function onTutorialAdvance(player: Player, rawStep: unknown)
	local step = Guard.int(rawStep, 1, 5)
	local profile = profileFor(player)
	if profile == nil or step == nil then
		return
	end
	if step == profile.tutorialStep + 1 then
		profile.tutorialStep = step
		if step == 1 then
			Telemetry.onboarding(player, profile, "entered_alley") -- #1273: tutorial card 0 done
		end
		Telemetry.custom(player, "tutorial_step", 1, { tostring(step) })
		CafeService.sync(player)
	end
end

-- The Settings screen (data-model section 14 `settings`): a switch takes a boolean, a volume a number it clamps
-- to 0 to 1, a choice one of its strings (shared/Settings). Unknown keys and values that do not fit are dropped.
local function onSetSetting(player: Player, rawKey: unknown, rawValue: unknown)
	local value = Settings.clean(rawKey, rawValue)
	local profile = profileFor(player)
	if profile == nil or value == nil then
		return
	end
	local settings = profile.settings :: any
	if settings[rawKey :: string] == value then
		return -- nothing changed; no sync
	end
	settings[rawKey :: string] = value
	CafeService.sync(player)
end

local function onLoaded(player: Player, profile: Profile)
	Economy.setPals(profile, PalService.count(player)) -- F92: pals who were here before the save loaded
	local plot = PlotService.assign(player)
	if plot == nil then
		Net.toast(player, "The street is full. Try another server.", "warn")
	end
	giveLawnGifts(player, profile) -- F91: a cafe already at Tier 2 or 3 when the lawn arrives
	CafeService.autoEquip(player, profile) -- #1534: the best cats on the open slots
	CafeService.refreshPlot(player)
	CafeService.sync(player)
	local offline, seconds = DataService.peekPendingOffline(player)
	if offline > 0 then
		Net.fire(player, "OfflineEarnings", offline, seconds)
	end
	if not DataService.saves() then
		Net.toast(
			player,
			"Studio mode: progress will not be saved (enable API access in Game Settings)",
			"warn"
		)
	end
	print(
		string.format(
			"[CafeService] %s loaded: $%d, %d cats, Tier %d, plot %d",
			player.Name,
			math.floor(profile.coins),
			ProfileSchema.catCount(profile),
			Economy.tier(profile),
			if plot ~= nil then plot.index else 0
		)
	)
end

function CafeService.start()
	DataService.onLoaded:Connect(onLoaded)
	PassService.changed:Connect(function(player: Player, passes: Economy.Passes)
		-- a pass bought in game (F95): what was earned so far settles at the old rate, then the new one shows
		local profile = profileFor(player)
		if profile ~= nil then
			Economy.setPasses(profile, passes)
			if CafeService.autoEquip(player, profile) > 0 then -- #1534: an Extra Slot pass's slot fills
				CafeService.refreshPlot(player)
			end
			CafeService.sync(player)
		end
	end)
	PalService.changed:Connect(function(player: Player, count: number)
		-- F92: a pal came or went; what was earned so far settles at the old bonus, then the new rate shows
		local profile = profileFor(player)
		if profile ~= nil then
			Economy.setPals(profile, count)
			CafeService.sync(player)
		end
	end)
	NameService.changed:Connect(function(player: Player)
		CafeService.refreshPlot(player)
		CafeService.sync(player)
	end)
	TipService.changed:Connect(CafeService.sync) -- F87: "Show tips again" sends the cleared tipsSeen
	Players.PlayerRemoving:Connect(function(player)
		carrying[player] = nil
		knownLevels[player] = nil
	end)

	Net.on("PlaceCat", onPlaceCat)
	Net.on("UnplaceCat", onUnplaceCat)
	Net.on("EquipBest", onEquipBest)
	Net.on("UnequipAll", onUnequipAll)
	Net.on("SellCat", onSellCat)
	Net.on("LockCat", onLockCat)
	Net.on("LockDecor", onLockDecor)
	Net.on("BuyUpgrade", onBuyUpgrade)
	Net.on("BuyDecor", onBuyDecor)
	Net.on("RankUp", onRankUp)
	Net.on("ToggleDecor", onToggleDecor)
	Net.on("EquipBestDecor", onEquipBestDecor)
	Net.on("BuyLure", onBuyLure)
	Net.on("ClaimOffline", onClaimOffline)
	Net.on("TutorialAdvance", onTutorialAdvance)
	Net.on("SetSetting", onSetSetting)
	Net.on("RequestSync", function(player)
		CafeService.sync(player)
		local offline, seconds = DataService.peekPendingOffline(player)
		if offline > 0 then
			Net.fire(player, "OfflineEarnings", offline, seconds)
		end
	end)

	-- The rate changes at dusk and dawn: settle the old phase and send the new rate at once.
	ClockService.changed:Connect(function()
		for _, player in DataService.loadedPlayers() do
			-- #1534: at nightfall the cats napping on the sleep spots by day go back to the cat room before the
			-- working cats walk to bed; at sunrise they come out on the spots that are free
			CafeService.refreshPlot(player)
			CafeService.sync(player)
		end
	end)

	-- Periodic sync so the client's predicted counter never drifts far from the truth.
	task.spawn(function()
		while true do
			task.wait(Config.SyncIntervalSeconds)
			for _, player in DataService.loadedPlayers() do
				CafeService.sync(player)
			end
		end
	end)
end

return CafeService
