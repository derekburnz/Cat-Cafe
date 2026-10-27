--!strict
-- The bait bowl (F28, data-model section 8): one bowl on the cafe's back step (v0.5 F44), bought as the lure_bowl
-- upgrade.
-- UseLure(lureId) puts one food in and rolls the cat in the same step (rarity from the food's odds, the cat among
-- that rarity's cats in every area the tier opens, charm and gold), so a rejoin cannot reroll it. The cat arrives
-- LureWaitSeconds later, online or not, and sits eating at the bowl. ResolveBait("tame") adds it to the cat room,
-- "letgo" sends it off; the food is used either way. CafeService draws the bowl and sends it in ProfileSync, which
-- names the cat only once it has arrived (reviewer N30).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CafeService = require(script.Parent.CafeService)
local CatStats = require(ReplicatedStorage.Shared.CatStats)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Catching = require(ReplicatedStorage.Shared.Catching)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Guard = require(script.Parent.Parent.Util.Guard)
local Net = require(script.Parent.Net)
local PlotService = require(script.Parent.PlotService)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)

local BaitService = {}

local CHOICES = { "tame", "letgo" }

local rng = Random.new()
local shownArrival: { [Player]: number } = {} -- placedAt of the bait whose arrival this player has been sent

-- Within `range` studs of the player's own bowl. No plot or no character is out of range.
local function nearOwnBowl(player: Player, range: number): boolean
	local plot = PlotService.get(player)
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if plot == nil or root == nil or not root:IsA("BasePart") then
		return false
	end
	return ((root :: BasePart).Position - plot.baitBowl.Position).Magnitude <= range
end

-- "10 minutes", "1 minute", "45 seconds"
local function waitText(seconds: number): string
	if seconds >= 120 then
		return string.format("%d minutes", math.floor(seconds / 60))
	elseif seconds >= 60 then
		return "1 minute"
	end
	return string.format("%d seconds", seconds)
end

local function onUseLure(player: Player, rawLureId: unknown)
	local lureId = Guard.id(rawLureId)
	local profile = DataService.get(player)
	if lureId == nil or profile == nil then
		return
	end
	local lure = Catalog.getLure(lureId)
	if lure == nil then
		return
	end
	if Economy.level(profile, "lure_bowl") < 1 then
		Net.toast(player, "Buy the Bait bowl in Upgrades first.", "warn")
		return
	end
	if profile.bait ~= nil then
		Net.toast(player, "There is food in your bowl already.", "warn")
		return
	end
	local stock = profile.lures[lureId] or 0
	if stock < 1 then
		Net.toast(player, string.format("You have no %s left.", lure.name), "warn")
		return
	end
	if not nearOwnBowl(player, Config.BaitBowlRangeStuds) then
		Net.toast(player, "Walk to your bait bowl first.", "warn")
		return
	end

	if stock > 1 then
		profile.lures[lureId] = stock - 1
	else
		profile.lures[lureId] = nil
	end
	local rarity: Types.Rarity = Catching.pickRarity(lure.odds, rng:NextNumber())
	local def = Catching.pickBaitCat(rarity, Economy.tier(profile), rng:NextNumber())
	local bait: Types.BaitState = {
		lureId = lureId,
		placedAt = os.time(),
		catId = def.id,
		variant = if rng:NextNumber() < Config.GoldChanceBait then "gold" else "base",
		charm = CatStats.rollCharm(rng:NextNumber(), rng:NextNumber()),
	}
	profile.bait = bait
	profile.stats.luresUsed += 1
	Telemetry.onboarding(player, profile, "first_bait")
	Telemetry.custom(player, "bait_rolled", 1, { lureId, rarity, "none" }) -- "none": no catnip buff yet
	Telemetry.baitStep(player, bait, 1)
	if profile.tutorialStep == 4 then
		CafeService.advanceTutorial(profile, 5) -- the last step: set bait
	end
	Net.toast(
		player,
		string.format(
			"%s is in the bowl. A cat will come by in %s.",
			lure.name,
			waitText(Config.LureWaitSeconds)
		),
		"good"
	)
	CafeService.refreshPlot(player)
	CafeService.sync(player)
end

local function onResolveBait(player: Player, rawChoice: unknown)
	local choice = Guard.oneOf(rawChoice, CHOICES)
	local profile = DataService.get(player)
	if choice == nil or profile == nil then
		return
	end
	local bait = profile.bait
	if bait == nil or os.time() < CafeService.baitReadyAt(bait) then
		CafeService.sync(player) -- the card waits for a fresh bowl state
		return
	end
	if not nearOwnBowl(player, Config.BaitResolveRangeStuds) then
		Net.toast(player, "Walk to your bait bowl first.", "warn")
		CafeService.sync(player)
		return
	end

	-- Empty the bowl before granting, so a second press cannot tame twice.
	profile.bait = nil
	shownArrival[player] = nil
	Telemetry.onboarding(player, profile, "first_bait_resolved")
	local def = Catalog.getCat(bait.catId)
	Telemetry.custom(
		player,
		"bait_resolved",
		1,
		{ bait.lureId, if def ~= nil then def.rarity :: string else "unknown", choice }
	)
	if choice == "tame" then
		Telemetry.baitStep(player, bait, 3)
	end
	if choice == "tame" and def ~= nil then
		profile.stats.baitsTamed += 1
		local _, isNew =
			CafeService.addCaughtCat(player, def, true, nil, bait.charm, "bait", bait.variant)
		Net.fire(player, "CatCaught", def.id, isNew)
		local text =
			Catching.shoutOut(player.DisplayName, "tamed", def, bait.variant, " at their bait bowl")
		if text ~= nil then
			Net.fireAll("Announce", text, def.rarity)
		end
		return
	end
	profile.stats.baitsLetGo += 1
	Net.toast(
		player,
		string.format("The %s wandered off, full of food.", if def ~= nil then def.name else "cat"),
		"info"
	)
	CafeService.refreshPlot(player)
	CafeService.sync(player)
end

-- Within a second of a cat arriving, put it at the bowl and send the bowl state that names it. A rejoin is
-- caught on the first pass after load as well.
local function checkArrivals()
	local now = os.time()
	for _, player in DataService.loadedPlayers() do
		local profile = DataService.get(player)
		local bait = if profile ~= nil then profile.bait else nil
		if
			bait ~= nil
			and now >= CafeService.baitReadyAt(bait)
			and shownArrival[player] ~= bait.placedAt
		then
			shownArrival[player] = bait.placedAt
			CafeService.refreshPlot(player)
			CafeService.sync(player)
			Telemetry.baitStep(player, bait, 2)
		end
	end
end

function BaitService.start()
	Net.on("UseLure", onUseLure)
	Net.on("ResolveBait", onResolveBait)
	Players.PlayerRemoving:Connect(function(player)
		shownArrival[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			checkArrivals()
		end
	end)
end

return BaitService
