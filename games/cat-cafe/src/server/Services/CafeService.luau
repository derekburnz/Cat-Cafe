--!strict
-- The cafe itself: income accounting, placement, shop purchases, decor, tables, offline earnings and ProfileSync.
-- Every handler validates its arguments, settles income first, mutates the profile, refreshes the world, then syncs.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetRegistry = require(script.Parent.Parent.World.AssetRegistry)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
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

-- Settled profile or nil when not loaded yet.
local function profileFor(player: Player): Profile?
	local profile = DataService.get(player)
	if profile ~= nil then
		Economy.settle(profile, os.time())
	end
	return profile
end

function CafeService.buildState(player: Player, profile: Profile): Types.PlayerState
	local plot = PlotService.get(player)
	return {
		money = math.floor(profile.coins),
		incomePerSecond = Economy.incomePerSecond(profile),
		cafeLevel = Economy.cafeLevel(profile),
		cafeProgress = nil,
		cafeProgressText = nil,
		tables = Economy.level(profile, "tables"),
		customers = nil,
		catsOwned = Economy.countsByCat(profile),
		upgradeLevels = profile.upgradeLevels,
		decorOwned = profile.decorOwned,
		decorPlaced = profile.decorPlaced,
		lures = profile.lures,
		equippedLure = profile.equippedLure,
		cats = profile.cats,
		collection = profile.collection,
		plotIndex = if plot ~= nil then plot.index else 0,
		carrying = carrying[player],
		dataSaves = DataService.saves(),
		tutorialStep = profile.tutorialStep,
		serverTime = os.time(),
	}
end

function CafeService.sync(player: Player)
	local profile = profileFor(player)
	if profile == nil then
		return
	end
	Net.fire(player, "ProfileSync", CafeService.buildState(player, profile))
end

-- World refresh -------------------------------------------------------------------------------------------

local function ensureLockLabel(furniture: Model, spot: Types.SpotDef): BillboardGui
	local existing = furniture:FindFirstChild("LockLabel", true)
	if existing ~= nil and existing:IsA("BillboardGui") then
		return existing :: BillboardGui
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "LockLabel"
	billboard.Size = UDim2.fromOffset(140, 30)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.MaxDistance = 40
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = Enum.Font.Gotham
	text.TextColor3 = Color3.fromRGB(240, 240, 240)
	text.TextStrokeTransparency = 0.3
	text.Text = string.format("Locked: cafe level %d", spot.cafeLevel)
	text.Parent = billboard
	billboard.Parent = furniture.PrimaryPart or furniture
	return billboard
end

local function refreshSpots(plot: WorldBuilder.Plot, profile: Profile)
	local cafeLevel = Economy.cafeLevel(profile)
	for _, spot in Catalog.spots do
		local furniture: Model? = plot.spotFurniture[spot.id]
		if furniture ~= nil then
			ensureLockLabel(furniture, spot).Enabled = cafeLevel < spot.cafeLevel
		end
	end
end

local function refreshCats(player: Player, plot: WorldBuilder.Plot, profile: Profile)
	local wanted: { [string]: Types.CatInstance } = {}
	for uid, instance in profile.cats do
		if instance.spotId ~= nil then
			wanted[uid] = instance
		end
	end
	for _, child in plot.cats:GetChildren() do
		local uid = child:GetAttribute("Uid")
		local instance = if type(uid) == "string" then wanted[uid] else nil
		if instance == nil or child:GetAttribute("SpotId") ~= instance.spotId then
			child:Destroy()
		else
			wanted[uid :: string] = nil
		end
	end
	for uid, instance in wanted do
		local spot: BasePart? = plot.spots[instance.spotId :: string]
		if spot ~= nil then
			local model = AssetRegistry.clone(Catalog.catModelName(instance.catId))
			model.Name = uid
			model:SetAttribute("Uid", uid)
			model:SetAttribute("CatId", instance.catId)
			model:SetAttribute("SpotId", instance.spotId)
			model:SetAttribute("OwnerUserId", player.UserId)
			model:PivotTo(spot.CFrame)
			model.Parent = plot.cats
		end
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

function CafeService.refreshPlot(player: Player)
	local profile = DataService.get(player)
	local plot = PlotService.get(player)
	if profile == nil or plot == nil then
		return
	end
	refreshSpots(plot, profile)
	refreshEspresso(plot, profile)
	refreshCats(player, plot, profile)
	refreshDecor(plot, profile)
	refreshTables(plot, profile)
end

-- Mutations used by other services -----------------------------------------------------------------------

local function newUid(): string
	return HttpService:GenerateGUID(false):sub(1, 12):lower()
end

local function advanceTutorial(profile: Profile, step: number)
	if profile.tutorialStep < step then
		profile.tutorialStep = step
	end
end

-- Adds a caught cat to the profile, pays the first-catch reward, auto-places it on a free open spot.
-- Returns the instance and whether this cat id was new to the collection.
-- `knownProfile` is passed on the save-on-leave path, where the session is closing and a lookup must not race it.
function CafeService.addCaughtCat(
	player: Player,
	def: Types.CatDef,
	notify: boolean,
	knownProfile: Profile?
): (Types.CatInstance, boolean)
	local profile = knownProfile
	if profile ~= nil then
		Economy.settle(profile, os.time())
	else
		profile = profileFor(player)
	end
	assert(profile ~= nil, "profile not loaded")
	local now = os.time()
	local isNew = profile.collection[def.id] == nil
	local instance: Types.CatInstance =
		{ uid = newUid(), catId = def.id, variant = "base", caughtAt = now, spotId = nil }
	profile.cats[instance.uid] = instance
	profile.stats.catsCaught += 1
	if isNew then
		profile.collection[def.id] = now
		Economy.credit(profile, Catalog.rarities[def.rarity].firstCatchReward)
	end
	advanceTutorial(profile, 2)

	for _, spot in Catalog.spots do
		if Economy.spotIsOpen(profile, spot.id) and Economy.catOnSpot(profile, spot.id) == nil then
			instance.spotId = spot.id
			advanceTutorial(profile, 3)
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
		if instance.spotId ~= nil then
			Net.toast(
				player,
				string.format("%s is resting on %s", def.name, instance.spotId :: string),
				"info"
			)
		else
			Net.toast(
				player,
				string.format("%s is in the cat room. Open a spot to place it.", def.name),
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

-- Consumes one of the equipped lure. Returns the lure def used, or nil with a reason.
function CafeService.consumeEquippedLure(player: Player): (Types.LureDef?, string?)
	local profile = profileFor(player)
	if profile == nil then
		return nil, "Not loaded"
	end
	if Economy.level(profile, "lure_bowl") < 1 then
		return nil, "Buy the Lure bowl upgrade first"
	end
	local lureId = profile.equippedLure
	if lureId == nil or (profile.lures[lureId] or 0) < 1 then
		return nil, "Equip a lure first"
	end
	local def = Catalog.getLure(lureId)
	if def == nil then
		return nil, "Unknown lure"
	end
	profile.lures[lureId] = (profile.lures[lureId] or 1) - 1
	if profile.lures[lureId] <= 0 then
		profile.lures[lureId] = nil
		profile.equippedLure = nil
	end
	profile.stats.luresUsed += 1
	CafeService.sync(player)
	return def, nil
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
	if Catalog.getSpot(spotId) == nil then
		return
	end
	if not Economy.spotIsOpen(profile, spotId) then
		Net.toast(player, "That spot is locked. Raise the cafe level.", "warn")
		return
	end
	if Economy.catOnSpot(profile, spotId) ~= nil then
		Net.toast(player, "That spot is taken.", "warn")
		return
	end
	if instance.spotId ~= nil then
		Net.toast(player, "Remove the cat from its spot first.", "warn")
		return
	end
	instance.spotId = spotId
	advanceTutorial(profile, 3)
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
		advanceTutorial(profile, 4)
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
	if def == nil then
		return
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
	if profile.equippedLure == nil then
		profile.equippedLure = lureId
	end
	Net.toast(player, string.format("Bought %s (%d)", def.name, profile.lures[lureId]), "good")
	CafeService.sync(player)
end

local function onEquipLure(player: Player, rawId: unknown)
	local profile = profileFor(player)
	if profile == nil then
		return
	end
	if rawId == nil then
		profile.equippedLure = nil
		CafeService.sync(player)
		return
	end
	local lureId = Guard.id(rawId)
	if lureId == nil or (profile.lures[lureId] or 0) < 1 then
		return
	end
	profile.equippedLure = lureId
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
	local step = Guard.int(rawStep, 1, 4)
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
			"[CafeService] %s loaded: $%d, %d cats, cafe level %d, plot %d",
			player.Name,
			math.floor(profile.coins),
			ProfileSchema.catCount(profile),
			Economy.cafeLevel(profile),
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
	Net.on("SellCat", onSellCat)
	Net.on("BuyUpgrade", onBuyUpgrade)
	Net.on("BuyDecor", onBuyDecor)
	Net.on("ToggleDecor", onToggleDecor)
	Net.on("BuyLure", onBuyLure)
	Net.on("EquipLure", onEquipLure)
	Net.on("ClaimOffline", onClaimOffline)
	Net.on("TutorialAdvance", onTutorialAdvance)
	Net.on("RequestSync", function(player)
		CafeService.sync(player)
		local offline, seconds = DataService.peekPendingOffline(player)
		if offline > 0 then
			Net.fire(player, "OfflineEarnings", offline, seconds)
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
