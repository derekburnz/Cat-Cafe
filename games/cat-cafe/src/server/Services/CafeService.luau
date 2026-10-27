--!strict
-- The cafe itself: income accounting, placement, shop purchases, decor, tables, offline earnings and ProfileSync.
-- Every handler validates its arguments, settles income first, mutates the profile, refreshes the world, then syncs.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetRegistry = require(script.Parent.Parent.World.AssetRegistry)
local CatStats = require(ReplicatedStorage.Shared.CatStats)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local ClockService = require(script.Parent.ClockService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local EquipBest = require(ReplicatedStorage.Shared.EquipBest)
local Guard = require(script.Parent.Parent.Util.Guard)
local Layout = require(script.Parent.Parent.World.Layout)
local Net = require(script.Parent.Net)
local PlotService = require(script.Parent.PlotService)
local ProfileSchema = require(ReplicatedStorage.Shared.ProfileSchema)
local Types = require(ReplicatedStorage.Shared.Types)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

type Profile = Types.PlayerProfile

local CafeService = {}

local carrying: { [Player]: string? } = {} -- catId while walking a caught stray home
local rng = Random.new() -- charm rolls for caught cats

-- Settled profile or nil when not loaded yet.
local function profileFor(player: Player): Profile?
	local profile = DataService.get(player)
	if profile ~= nil then
		Economy.settle(profile, os.time(), ClockService.epoch())
	end
	return profile
end

-- What the cafe earns per second right now: the day rate, times NightIncomeMultiplier at night (section 11).
local function currentRate(profile: Profile): number
	return Economy.incomePerSecond(profile) * Economy.phaseMultiplier(ClockService.phase())
end

-- The cats as the client sees them: saved fields plus rating, stars and XP progress (CatStats.view).
function CafeService.catViews(profile: Profile): { [string]: Types.CatView }
	local views: { [string]: Types.CatView } = {}
	for uid, instance in profile.cats do
		views[uid] = CatStats.view(instance)
	end
	return views
end

-- When the bowl's cat arrives (data-model section 8): LureWaitSeconds after the food went in, online or not.
function CafeService.baitReadyAt(bait: Types.BaitState): number
	return bait.placedAt + Config.LureWaitSeconds
end

-- The bowl as ProfileSync sends it: the rolled cat only once it has arrived, so the reveal is not spoiled (N30).
local function baitView(profile: Profile, now: number): Types.BaitView?
	local bait = profile.bait
	if bait == nil then
		return nil
	end
	local readyAt = CafeService.baitReadyAt(bait)
	local view: Types.BaitView = { lureId = bait.lureId, readyAt = readyAt }
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

function CafeService.buildState(player: Player, profile: Profile): Types.PlayerState
	local plot = PlotService.get(player)
	local now = os.time()
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
		lures = profile.lures,
		bait = baitView(profile, now),
		cats = CafeService.catViews(profile),
		collection = profile.collection,
		shinyCollection = profile.shinyCollection,
		plotIndex = if plot ~= nil then plot.index else 0,
		carrying = carrying[player],
		dataSaves = DataService.saves(),
		tutorialStep = profile.tutorialStep,
		settings = { music = profile.settings.music, sfx = profile.settings.sfx },
		serverTime = now,
	}
end

-- World refresh -------------------------------------------------------------------------------------------

-- "Barista", "Waiter": the role a slot holds, for labels and toasts.
local function roleName(spot: Types.SpotDef): string
	return spot.spotType:sub(1, 1):upper() .. spot.spotType:sub(2)
end

-- A label over a role slot this tier has not opened yet.
local function ensureLockLabel(slot: BasePart, spot: Types.SpotDef): BillboardGui
	local existing = slot:FindFirstChild("LockLabel")
	if existing ~= nil and existing:IsA("BillboardGui") then
		return existing :: BillboardGui
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "LockLabel"
	billboard.Size = UDim2.fromOffset(200, 24) -- wide enough for one line
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.MaxDistance = 20 -- only near the slot, so labels from the plots next door do not stack up
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = Enum.Font.Gotham
	text.TextColor3 = Color3.fromRGB(240, 240, 240)
	text.TextStrokeTransparency = 0.3
	text.Text = string.format("%s: opens at Tier %d", roleName(spot), spot.tier)
	text.Parent = billboard
	billboard.Parent = slot
	return billboard
end

local function refreshSpots(plot: WorldBuilder.Plot, profile: Profile)
	local tier = Economy.tier(profile)
	plot.model:SetAttribute("Tier", tier)
	WorldBuilder.setDressing(plot, tier)
	-- one label per role, on the next slot of that role to open: four at Tier 1 instead of every locked slot
	local nextLocked: { [string]: Types.SpotDef } = {}
	for _, spot in Catalog.spots do
		local current = nextLocked[spot.spotType]
		if tier < spot.tier and (current == nil or spot.tier < current.tier) then
			nextLocked[spot.spotType] = spot
		end
	end
	for _, spot in Catalog.spots do
		local slot: BasePart? = plot.spots[spot.id]
		if slot ~= nil then
			ensureLockLabel(slot, spot).Enabled = nextLocked[spot.spotType] == spot
		end
	end
end

-- Working cats stand at their slots; up to #plot.napSpots cats without a job nap in the cafe, highest rating first,
-- so the collection is on show from the street (world-and-feel.md section 4, F37). Each model carries what the
-- world labels and effects read: Slot, Napping, Rarity, Shiny and Rate (its coins per second after the cafe and
-- tier multipliers, 0 while napping); working cats are tagged WorkingCat.
type CatPlacement = { instance: Types.CatInstance, slot: string, anchor: BasePart }

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
	table.sort(resting, CatStats.isBetter)
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
	for _, child in plot.cats:GetChildren() do
		local uid = child:GetAttribute("Uid")
		local placement: CatPlacement? = if type(uid) == "string" then wanted[uid] else nil
		if placement == nil or child:GetAttribute("Slot") ~= placement.slot then
			child:Destroy()
		else
			wanted[uid :: string] = nil
			child:SetAttribute("Rate", Economy.catRate(placement.instance) * multiplier)
		end
	end
	for uid, placement in wanted do
		local instance = placement.instance
		local def = Catalog.getCat(instance.catId)
		local model = AssetRegistry.cloneCat(instance.catId, instance.variant)
		model.Name = uid
		model:SetAttribute("Uid", uid)
		model:SetAttribute("CatId", instance.catId)
		model:SetAttribute("Slot", placement.slot)
		model:SetAttribute("SpotId", instance.spotId)
		model:SetAttribute("Napping", instance.spotId == nil)
		model:SetAttribute("Rarity", if def ~= nil then def.rarity else nil)
		model:SetAttribute("Shiny", instance.variant == "shiny")
		model:SetAttribute("Rate", Economy.catRate(instance) * multiplier)
		model:SetAttribute("OwnerUserId", player.UserId)
		if instance.spotId ~= nil then
			CollectionService:AddTag(model, "WorkingCat") -- the client's Audio purrs from the nearest few
		end
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- a cat streams in whole (reviewer S37)
		model:PivotTo(placement.anchor.CFrame)
		model.Parent = plot.cats
	end
end

local function refreshDecor(plot: WorldBuilder.Plot, profile: Profile)
	for _, def in Catalog.decor do
		local shouldShow = profile.decorOwned[def.id] == true
			and profile.decorPlaced[def.id] == true
		local existing = plot.decor:FindFirstChild(def.id)
		if shouldShow then
			local anchor: BasePart? = plot.decorAnchors[def.id]
			if existing == nil and anchor ~= nil then
				local model = AssetRegistry.clone(def.asset)
				model.Name = def.id
				model:PivotTo(anchor.CFrame)
				model.Parent = plot.decor
			end
		elseif existing ~= nil then
			existing:Destroy()
		end
	end
end

local function refreshTables(plot: WorldBuilder.Plot, profile: Profile)
	local count = math.min(Economy.level(profile, "tables"), #plot.tableAnchors)
	for i, anchor in plot.tableAnchors do
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

-- The bait bowl in the front garden (data-model section 8): the bowl once the upgrade is bought, the food in it
-- while a cat is on its way and the cat itself, eating, once it has arrived, so the street sees it. The item
-- models are tiny, so they are scaled up to read from the path. BaitReadyAt is for display only.
local BOWL_SCALE = 2
local FOOD_SCALE = 1.2 -- the food item sits in the bowl

local function refreshBait(player: Player, plot: WorldBuilder.Plot, profile: Profile)
	local owned = Economy.level(profile, "lure_bowl") >= 1
	local bait = if owned then profile.bait else nil
	local readyAt = if bait ~= nil then CafeService.baitReadyAt(bait) else 0
	local ready = bait ~= nil and os.time() >= readyAt
	plot.model:SetAttribute("BaitReadyAt", readyAt)
	if not owned then
		plot.bait:ClearAllChildren()
		return
	end

	if plot.bait:FindFirstChild("Bowl") == nil then
		local bowl = AssetRegistry.clone("CatCafe_Item_FoodBowl")
		bowl.Name = "Bowl"
		bowl:ScaleTo(BOWL_SCALE)
		bowl:PivotTo(plot.baitBowl.CFrame)
		bowl.Parent = plot.bait
	end

	local lureId = if bait ~= nil then bait.lureId else nil
	local food = plot.bait:FindFirstChild("Food")
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
		model:PivotTo(plot.baitBowl.CFrame * CFrame.new(0, 0.1, 0))
		model.Parent = plot.bait
	end

	-- one cat per food: the key changes with each new food, so a stale cat never stays
	local key = if ready and bait ~= nil
		then string.format("%s@%d", bait.catId, bait.placedAt)
		else nil
	local cat = plot.bait:FindFirstChild("Cat")
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
		model:SetAttribute("Shiny", bait.variant == "shiny")
		model:SetAttribute("OwnerUserId", player.UserId)
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		model:PivotTo(plot.baitCat.CFrame)
		model.Parent = plot.bait
	end
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
	refreshCats(player, plot, profile)
	refreshDecor(plot, profile)
	refreshTables(plot, profile)
	refreshBait(player, plot, profile)
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
end

function CafeService.sync(player: Player)
	local profile = profileFor(player)
	if profile == nil then
		return
	end
	Net.fire(player, "ProfileSync", CafeService.buildState(player, profile))
	refreshShowcase(player, profile)
end

-- Mutations used by other services -----------------------------------------------------------------------

local function newUid(): string
	return HttpService:GenerateGUID(false):sub(1, 12):lower()
end

function CafeService.advanceTutorial(profile: Profile, step: number)
	if profile.tutorialStep < step then
		profile.tutorialStep = step
	end
end

-- Adds a caught cat to the profile, pays the first-catch reward, puts it to work in a free open role slot.
-- Returns the instance and whether this cat id was new to the collection.
-- `knownProfile` is passed on the save-on-leave path, where the session is closing and a lookup must not race it.
-- `charm` is the stray's roll when the caller has one (CatService can roll it at spawn and show stars on the
-- prompt); otherwise it is rolled here.
-- `method` is how the cat was found, "net" when nil; "rescue" also sets the rescued flag. `variant` keeps a shiny
-- roll made before the cat was owned (a bait cat when the food went in, a stuck cat at night start).
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
	instance.method = method or "net"
	if method == "rescue" then
		instance.rescued = true
	end
	if variant ~= nil then
		instance.variant = variant
		if variant == "shiny" and profile.shinyCollection[def.id] == nil then
			profile.shinyCollection[def.id] = now
		end
	end
	profile.cats[instance.uid] = instance
	profile.stats.catsCaught += 1
	if isNew then
		profile.collection[def.id] = now
		Economy.credit(profile, Catalog.rarities[def.rarity].firstCatchReward)
	end
	CafeService.advanceTutorial(profile, 2)

	for _, spot in Catalog.spots do
		if Economy.spotIsOpen(profile, spot.id) and Economy.catOnSpot(profile, spot.id) == nil then
			instance.spotId = spot.id
			CafeService.advanceTutorial(profile, 3)
			break
		end
	end

	CafeService.refreshPlot(player)
	if notify then
		if isNew then
			Net.toast(
				player,
				string.format(
					"New cat! %s joins the collection (+$%d)",
					def.name,
					Catalog.rarities[def.rarity].firstCatchReward
				),
				"good"
			)
		end
		local stars = CatStats.starsText(CatStats.stars(CatStats.charm(instance)))
		local spot = if instance.spotId ~= nil
			then Catalog.getSpot(instance.spotId :: string)
			else nil
		if spot ~= nil then
			Net.toast(
				player,
				string.format("%s %s is working as %s", stars, def.name, roleName(spot)),
				"info"
			)
		else
			Net.toast(
				player,
				string.format(
					"%s %s is in the cat room. Every role is taken; give it one from there.",
					stars,
					def.name
				),
				"info"
			)
		end
		CafeService.sync(player)
	end
	return instance, isNew
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
	CafeService.advanceTutorial(profile, 3)
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
	if plan.catsPlaced > 0 then
		CafeService.advanceTutorial(profile, 3)
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
	local def = Catalog.getCat(instance.catId)
	if def == nil then
		return
	end
	profile.cats[uid] = nil
	profile.stats.catsSold += 1
	local value = Catalog.rarities[def.rarity].sellValue
	Economy.credit(profile, value)
	Net.toast(player, string.format("Sold %s for $%d", def.name, value), "good")
	CafeService.refreshPlot(player)
	CafeService.sync(player)
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
	profile.upgradeLevels[upgradeId] = Economy.level(profile, upgradeId) + 1
	if upgradeId == "tables" then
		-- a player who already baited the bowl has done step 5's task too (reviewer S48)
		CafeService.advanceTutorial(profile, if profile.stats.luresUsed > 0 then 5 else 4)
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
	profile.tier = def.tier
	local area = Catalog.getArea(def.area)
	Net.toast(
		player,
		string.format(
			"Your cafe is now a %s! %s is open and %d role slots are ready.",
			def.name,
			if area ~= nil then area.name else def.area,
			def.slots
		),
		"good"
	)
	Net.fireAll("Announce", string.format("%s's cafe is now a %s!", player.DisplayName, def.name))
	print(string.format("[CafeService] %s ranked up to Tier %d", player.Name, def.tier))
	CafeService.refreshPlot(player)
	CafeService.sync(player)
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
	if not profile.decorOwned[decorId] then
		return
	end
	if placed then
		profile.decorPlaced[decorId] = true
	else
		profile.decorPlaced[decorId] = nil
	end
	CafeService.refreshPlot(player)
	CafeService.sync(player)
end

local function onBuyLure(player: Player, rawId: unknown)
	local lureId = Guard.id(rawId)
	local profile = profileFor(player)
	if profile == nil or lureId == nil then
		return
	end
	local def = Catalog.getLure(lureId)
	if def == nil or def.source ~= "shop" then
		return -- dealer foods are only sold by the night dealer
	end
	-- Lures cost coins only, so the paid-random-items policy gate is a no-op in the slice. Logged so the hook exists.
	local policy = DataService.policy(player)
	if policy ~= nil and policy.ArePaidRandomItemsRestricted == true then
		print(
			string.format(
				"[CafeService] policy note: paid random items restricted for %d (lures are coin-only, allowed)",
				player.UserId
			)
		)
	end
	if not Economy.trySpend(profile, def.cost) then
		Net.toast(player, "Not enough coins", "warn")
		CafeService.sync(player)
		return
	end
	profile.lures[lureId] = (profile.lures[lureId] or 0) + 1
	Net.toast(player, string.format("Bought %s (%d)", def.name, profile.lures[lureId]), "good")
	CafeService.sync(player)
end

local function onClaimOffline(player: Player)
	local profile = profileFor(player)
	if profile == nil then
		return
	end
	local amount = DataService.takePendingOffline(player)
	if amount <= 0 then
		return
	end
	Economy.credit(profile, amount)
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
		CafeService.sync(player)
	end
end

local function onLoaded(player: Player, profile: Profile)
	local plot = PlotService.assign(player)
	if plot == nil then
		Net.toast(player, "The street is full. Try another server.", "warn")
	end
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
	Players.PlayerRemoving:Connect(function(player)
		carrying[player] = nil
	end)

	Net.on("PlaceCat", onPlaceCat)
	Net.on("UnplaceCat", onUnplaceCat)
	Net.on("EquipBest", onEquipBest)
	Net.on("SellCat", onSellCat)
	Net.on("BuyUpgrade", onBuyUpgrade)
	Net.on("BuyDecor", onBuyDecor)
	Net.on("RankUp", onRankUp)
	Net.on("ToggleDecor", onToggleDecor)
	Net.on("BuyLure", onBuyLure)
	Net.on("ClaimOffline", onClaimOffline)
	Net.on("TutorialAdvance", onTutorialAdvance)
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
