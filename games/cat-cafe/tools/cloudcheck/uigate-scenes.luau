--!nocheck
--[[
	uigate-scenes: what the UI gate (uigate.mjs) opens on each screen size. Called with (UIShim) from ui-shim.luau.

	setup() starts the real UI the way Controllers/UIController does (the same catalog keys from shared/Catalog)
	and hands it a mid-game player chosen to stress the layout: a 10-digit money count, a 20-letter cat name,
	full crew slots, quests half done, a bowl of bait, crates and potions. Each scene then opens one window through
	the same call the game uses. A new window goes in SCENES; the gate builds it at every screen size.
]]

local UIShim = ...

local Scenes = {}

local UI
local Catalog

-- The catalog exactly as UIController.start builds it.
local function catalogLikeTheGame()
	return {
		cats = Catalog.cats,
		upgrades = Catalog.upgrades,
		decor = Catalog.decor,
		lures = Catalog.lures,
		spots = Catalog.spots,
		tiers = Catalog.tiers,
		areas = Catalog.areas,
		rarities = Catalog.rarities,
		tipJar = Catalog.tipJar,
		indexMilestones = Catalog.indexMilestones,
		indexPrizes = Catalog.indexPrizes,
		spinWheel = Catalog.spinWheel,
		crates = Catalog.crates,
		crateDecor = Catalog.crateDecor,
		fishShop = Catalog.fishShop,
		potions = Catalog.potions,
		mysteryGift = Catalog.mysteryGift,
		dealerAmountWeights = Catalog.dealerAmountWeights,
		quests = Catalog.quests,
		questPrizes = Catalog.questPrizes,
		achievements = Catalog.achievements,
		achievementPrizes = Catalog.achievementPrizes,
		dailyTreat = Catalog.dailyTreat,
	}
end

local function questRows(pools, count)
	local rows = {}
	local names = {}
	for name in pools do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in names do
		for _, row in pools[name] do
			if #rows < count then
				table.insert(rows, row)
			end
		end
	end
	local out = {}
	for index, row in rows do
		local needs = row.needs or 1
		local progress = if index <= 2 then needs else math.floor(needs / 2)
		table.insert(out, {
			id = row.id,
			text = row.text or row.id,
			progress = progress,
			needs = needs,
			claimed = index == 1,
		})
	end
	return out
end

-- A mid-game player: Tier 3, about half the cats found, every Tier 3 spot filled.
local function samplePlayer(now)
	local cats = {}
	local collection = {}
	local goldCollection = {}
	local spots = {}
	for _, spot in Catalog.spots do
		if (spot.tier or 1) <= 3 then
			table.insert(spots, spot.id)
		end
	end
	for index, def in Catalog.cats do
		if index % 2 == 1 then
			collection[def.id] = now - index * 600
		end
		if index % 9 == 1 then
			goldCollection[def.id] = now - index * 300
		end
	end
	local count = 0
	for index, def in Catalog.cats do
		if count >= 14 or collection[def.id] == nil then
			continue
		end
		count += 1
		local uid = "gate_" .. count
		cats[uid] = {
			uid = uid,
			catId = def.id,
			variant = if count == 3 then "gold" else "base",
			name = if count == 1 then "Sir Whiskerton Fluff" else nil,
			caughtAt = now - index * 600,
			spotId = spots[count],
			locked = count == 2,
			level = 10 + count,
			xp = 40,
			xpToNext = 120,
			charm = 60,
			stars = 3,
			rating = 12.5 * count,
		}
	end
	local upgradeLevels = {}
	for index, upgrade in Catalog.upgrades do
		upgradeLevels[upgrade.id] = if index % 3 == 0 then 0 else 3
	end
	local decorOwned, decorPlaced = {}, {}
	for index, decor in Catalog.decor do
		if index <= 4 then
			decorOwned[decor.id] = true
			decorPlaced[decor.id] = index <= 2
		end
	end
	local lures = {}
	for index, lure in Catalog.lures do
		lures[lure.id] = if index <= 3 then 12 - index * 3 else 0
	end
	local potions = {}
	for index, potion in Catalog.potions do
		potions[potion.id] = if index <= 3 then index else 0
	end
	local crates = {}
	for index, crate in Catalog.crates do
		if index <= 2 then
			crates[crate.id] = index
		end
	end
	local achievements = {}
	for index, row in Catalog.achievements do
		achievements[row.id] = {
			progress = if index <= 3 then row.needs else math.floor(row.needs / 3),
			claimed = index == 1,
		}
	end
	local day = math.floor(now / 86400)
	return {
		money = 1234567890,
		incomePerSecond = 98765.4,
		tier = 3,
		cafeProgress = 0.6,
		cafeProgressText = "3 / 5 upgrades",
		tables = 6,
		customers = 9,
		upgradeLevels = upgradeLevels,
		decorOwned = decorOwned,
		decorPlaced = decorPlaced,
		lures = lures,
		cats = cats,
		collection = collection,
		goldCollection = goldCollection,
		tutorialStep = nil,
		introSeen = true,
		settings = UIShim.require("ReplicatedStorage.Shared.Settings").defaults(),
		indexRewards = {},
		spin = { lastFreeDay = day - 1, banked = 2 },
		goldenFish = 1234,
		crates = crates,
		crateLuck = { alley = 12 },
		fishPerks = {},
		potions = potions,
		buffs = {},
		-- F88: the Lucky Cat at level 3, so the Luck chip shows and every odds card has Luck x1.3 in it
		luck = 1.3,
		luckSources = { { id = "statue", value = 0.3 } },
		quests = {
			daily = questRows(Catalog.quests.daily, 4),
			weekly = questRows(Catalog.quests.weekly, 3),
			dailyResetsAt = now + 5 * 3600,
			weeklyResetsAt = now + 3 * 86400,
			dailyRerollUsed = false,
			weeklyRerollUsed = false,
			dailySetClaimed = false,
			weeklySetClaimed = false,
		},
		achievements = achievements,
		dailyTreat = { stamp = 2, lastDay = day - 1, due = true, nextDay = 3 },
	}
end

function Scenes.setup()
	Catalog = UIShim.require("ReplicatedStorage.Shared.Catalog")
	UI = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI")
	-- Claim all in the Quests window, the Index window and the Tip Jar shows once the server has ClaimAll
	-- (Gameplay-Engineer); the gate checks the buttons now
	local Config = UIShim.require("ReplicatedStorage.Shared.Config")
	Config.QuestClaimAll = true
	Config.IndexClaimAll = true
	Config.TipJarClaimAll = true
	UI.init({ catalog = catalogLikeTheGame(), keybinds = true })
	UI.cannon.setEnabled(true) -- the Cat Cannon is live (F84): Cannon in the bottom row, no Alley or Areas
	local now = os.time()
	UI.update(samplePlayer(now))
	UI.tipJar.set({ sessionStartedAt = workspace:GetServerTimeNow() - 25 * 60, claimed = { [1] = true } })
end

-- the first Mythical cat in the catalog, and this player's id, for the big pull scenes (F89)
local function mythicalCat()
	for _, def in Catalog.cats do
		if def.rarity == "Mythical" then
			return def.id
		end
	end
	return Catalog.cats[1].id
end

local function localUserId()
	return game:GetService("Players").LocalPlayer.UserId
end

-- presses a button the way a player does: the first TextButton or ImageButton named `name` under the window;
-- "Daily.Quest2.Claim" walks down one name at a time
local function press(windowName, name)
	local playerGui = UIShim.playerGui
	-- windows sit in CatCafeModals.Root.Container; the HUD and the Index have pieces with the same names (Cats)
	local modals = playerGui:FindFirstChild("CatCafeModals")
	local rootFrame = modals and modals:FindFirstChild("Root")
	local container = rootFrame and rootFrame:FindFirstChild("Container")
	local window = (container and container:FindFirstChild(windowName))
		or playerGui:FindFirstChild(windowName, true)
	assert(window, "uigate: no window " .. windowName)
	local holder = window
	for part in string.gmatch(name, "[^%.]+") do
		holder = holder and holder:FindFirstChild(part, true)
	end
	assert(holder, "uigate: no " .. name .. " in " .. windowName)
	local button = if holder:IsA("GuiButton") then holder else holder:FindFirstChildWhichIsA("GuiButton", true)
	assert(button, "uigate: " .. name .. " has no button")
	UIShim.fire(UIShim.eventOf(button, "Activated")) -- Components/Button listens to Activated only
end

-- a code that pays a big prize (F94: up to three pictures)
local CODE_PRIZE = {
	coins = 5000,
	coinSeconds = 600,
	fish = 25,
	spins = 2,
	lures = { caviar = 1 },
	crates = { classic_crate = 1 },
}

-- an F93 rescue bar mid attempt: a Legendary needs six hits, one landed, with a spare zone per paw
local function rescueChallenge()
	local t = workspace:GetServerTimeNow()
	return {
		kind = "bar",
		startsAt = t - 1,
		phase = 0.3,
		speed = 0.9,
		zoneWidth = 0.16,
		zones = { 0.3, 0.7, 0.45, 0.82, 0.2, 0.6, 0.35, 0.75, 0.5 },
		hitsNeeded = 6,
		paws = 3,
		endsAt = t + 9,
		zone = 1,
		zoneEndsAt = t + 1.5,
		zonePasses = 2,
		speedUpPerHit = 0.08,
	}
end

-- F93 catch circles: `count` circles from `first` seconds on, one every 0.7 s, each closing over `shrink` seconds,
-- with the header of a named cat of `rarity`
local function startCatch(strayId, rarity, count, first, shrink)
	local t = workspace:GetServerTimeNow()
	local list = {}
	local spots = { { 0.2, 0.4 }, { 0.45, 0.65 }, { 0.7, 0.35 }, { 0.35, 0.2 }, { 0.8, 0.7 }, { 0.55, 0.3 }, { 0.15, 0.75 } }
	for index = 1, count do
		local spot = spots[(index - 1) % #spots + 1]
		table.insert(list, { startsAt = t + first + (index - 1) * 0.7, shrinkSeconds = shrink, x = spot[1], y = spot[2] })
	end
	UI.catch.show({ strayId = strayId, catId = Catalog.cats[2].id, catName = "Mochi", rarity = rarity })
	UI.catch.showCircles(strayId, list, { perfect = 0.037, good = 0.09 })
	return list
end

-- a tap anywhere on the circles, as a finger does
local function tapCircles()
	local tap = UIShim.playerGui:FindFirstChild("CatCafeCatchCircles"):FindFirstChild("Tap")
	UIShim.fire(UIShim.eventOf(tap, "InputBegan"), {
		UserInputType = Enum.UserInputType.Touch,
		Position = Vector3.new(400, 300, 0),
	})
end

-- name, how the game opens it
local SCENES = {
	{ "Upgrades", function()
		UI.open("Upgrades")
	end },
	{ "Decor", function()
		UI.open("Decor")
	end },
	{ "Index", function()
		UI.open("Collection")
	end },
	{ "Cats", function()
		UI.open("Cats")
	end },
	{ "CatsPicked", function()
		UI.open("Cats")
		-- the cards build on the next frame; the gold cat, level 13, at work: favourite or Likes, Gold and level chips
		task.delay(0.2, function()
			press("Cats", "gate_3")
		end)
	end },
	{ "RankUp", function()
		UI.open("RankUp")
	end },
	{ "Cannon", function()
		UI.cannon.open()
	end },
	{ "Bait", function()
		UI.bait.openPicker()
	end },
	{ "Dealer", function()
		UI.dealer.open()
	end },
	{ "DealerNight", function()
		-- F94: one stock all night, the countdown to sunrise
		UI.dealer.setStock({
			window = 20400,
			restocksAt = workspace:GetServerTimeNow() + 7 * 60 + 12,
			stock = {
				{ lureId = "sardines", cost = 25000, amount = 3, bought = 1 },
				{ lureId = "caviar", cost = 120000, amount = 1, bought = 1 },
				{ lureId = "moon_milk", cost = 400000, amount = 0, bought = 0 },
				{ lureId = "star_treat", cost = 2500000, amount = 2, bought = 0 },
			},
		})
		UI.dealer.open()
	end },
	{ "Settings", function()
		UI.open("Settings")
	end },
	{ "TipJar", function()
		UI.tipJar.open()
	end },
	{ "Spin", function()
		UI.spin.open()
	end },
	{ "SpinOdds", function()
		UI.spin.open()
		press("SpinWheel", "Odds")
	end },
	{ "Market", function()
		UI.market.open()
		press("FishMarket", "CratesTab")
	end },
	{ "MarketFresh", function()
		-- F94: a window mid-way, one row sold out to this player, one not stocked, a crate row
		UI.freshCatch.setStock({
			window = 5900000,
			restocksAt = workspace:GetServerTimeNow() + 192,
			stock = {
				{ itemId = "tip_potion", fish = 10, amount = 3, bought = 1 },
				{ itemId = "swift_potion", fish = 6, amount = 2, bought = 2 },
				{ itemId = "steady_potion", fish = 12, amount = 0, bought = 0 },
				{ itemId = "quick_bait_potion", fish = 15, amount = 1, bought = 0 },
				{ itemId = "big_tip_potion", fish = 25, amount = 1, bought = 0 },
				{ itemId = "lucky_potion", fish = 25, amount = 0, bought = 0 },
				{ itemId = "gold_rush_potion", fish = 30, amount = 1, bought = 0 },
				{ itemId = "classic_crate", fish = 50, amount = 1, bought = 0 },
			},
		})
		UI.market.open()
		press("FishMarket", "FreshTab")
	end },
	{ "MarketFreshNight", function()
		UI.freshCatch.setStock(nil)
		UI.market.open()
		press("FishMarket", "FreshTab")
	end },
	{ "Feedback", function()
		UI.bugReport.open("bug")
	end },
	-- F87: the Feedback tile opens on the three faces, and a face brings the chips
	{ "FeedbackFaces", function()
		UI.bugReport.open()
	end },
	{ "FeedbackChips", function()
		UI.bugReport.open()
		press("BugReport", "Face_love")
	end },
	-- F87: the one slide-in faces ask over the travel row
	{ "FeedbackAsk", function()
		UI.tips.showAsk()
	end },
	{ "Codes", function()
		UI.codes.open()
	end },
	{ "CodesPrize", function()
		UI.codes.open()
		UI.codes.result(true, "Code redeemed!", CODE_PRIZE)
	end },
	-- F96: the Bellhop Cat's stand card before the first goals are done, Take me home greyed
	{ "Bellhop", function()
		UI.starterCat.open({
			claimed = false,
			gate = "task",
			line = "Finish your first goals to take me home",
			rate = 3,
		})
	end },
	-- once the game is in a group: Join the group beside Take me home, and the server's refusal
	{ "BellhopGroup", function()
		UI.starterCat.open({ claimed = false, gate = "group", rate = 243 })
		press("StarterCat", "TakeMeHome")
		UI.starterCat.result(false, "Join the Cat Cafe group to take me home")
	end },
	{ "BellhopHome", function()
		UI.starterCat.open({ claimed = true, gate = "group", line = "Already home with you", rate = 98765.4 })
	end },
	-- F96 section 3: the favorite ask on the tip card
	{ "FavoriteAsk", function()
		UI.asks.show("favorite_ask")
	end },
	-- the Index's Exclusive page, after every area
	{ "IndexExclusive", function()
		UI.openIndex("exclusive")
	end },
	-- an exclusive cat in the cat room reads "Can't sell"
	{ "CatsBellhop", function()
		local player = samplePlayer(os.time())
		player.cats.gate_bellhop = {
			uid = "gate_bellhop",
			catId = "bellhop_cat",
			variant = "base",
			caughtAt = os.time() - 60,
			level = 1,
			xp = 0,
			xpToNext = 40,
			charm = 60,
			stars = 3,
			rating = 243,
		}
		UI.update({ cats = player.cats })
		UI.open("Cats")
		task.delay(0.2, function()
			press("Cats", "gate_bellhop")
		end)
	end },
	-- F97 section 6: two spare cats (no Index page) with their "Classic" tag, one gold under its sparkle
	{ "CatsClassic", function()
		local player = samplePlayer(os.time())
		local count = 0
		for _, def in Catalog.cats do
			if def.area == "spare" and count < 2 then
				count += 1
				local uid = "gate_classic_" .. count
				player.cats[uid] = {
					uid = uid,
					catId = def.id,
					variant = if count == 1 then "gold" else "base",
					caughtAt = os.time() - 30 * count,
					level = 5,
					xp = 0,
					xpToNext = 40,
					charm = 50,
					stars = 3,
					rating = 12,
				}
			end
		end
		UI.update({ cats = player.cats })
		UI.open("Cats")
	end },
	{ "Potions", function()
		UI.open("Potions")
	end },
	{ "Quests", function()
		UI.open("Quests")
	end },
	{ "QuestsWeekly", function()
		UI.open("Quests")
		press("Quests", "WeeklyTab")
	end },
	{ "QuestsAchievements", function()
		UI.open("Quests")
		press("Quests", "AchievementsTab")
	end },
	-- a claim shows at once: the row reads Claimed and drops to the bottom (Derek 2026-10-29)
	{ "QuestsClaimed", function()
		UI.open("Quests")
		press("Quests", "DailyTab")
		press("Quests", "Daily.Quest2.Claim")
	end },
	-- Claim all on the Achievements tab (two met in the sample player)
	{ "QuestsClaimAll", function()
		UI.open("Quests")
		press("Quests", "AchievementsTab")
		press("Quests", "ClaimAll")
	end },
	{ "DailyTreat", function()
		UI.open("DailyTreat")
	end },
	-- F93: the rescue bar after one hit, the zone moved on and the marker sped up (the scene is drawn about two
	-- seconds in, so the zone keeps a few seconds)
	{ "Rescue", function()
		UI.rescue.show("gate_rescue", rescueChallenge())
		local t = workspace:GetServerTimeNow()
		UI.rescue.update("gate_rescue", 1, 3, false, false, {
			zone = 2,
			startsAt = t,
			phase = 0.6,
			speed = 0.97,
			zoneEndsAt = t + 5,
		})
	end },
	-- F93: the touch Net button, in a catching area while a swing could go (phones only)
	{ "NetButton", function()
		UI.setZone("Alley")
		UI.net.setEnabled(true)
	end },
	-- F93: a catch three circles in: Perfect, Good, Perfect, each cleared with its word, the pips filling
	{ "Catch", function()
		local list = startCatch("gate_stray", "Epic", 5, 0, 0.82)
		local t0 = workspace:GetServerTimeNow()
		for index, delay in { 0, 0.06, 0 } do
			local target = list[index].startsAt + list[index].shrinkSeconds
			task.delay(target - t0 + delay, tapCircles)
		end
	end },
	-- F93: the result word over the strip once the server's grades land (three Perfects of four: EXCELLENT!)
	{ "CatchResult", function()
		startCatch("gate_stray", "Rare", 4, 1, 1)
		task.delay(1.8, function()
			UI.catch.showGrades("gate_stray", { "perfect", "good", "perfect", "perfect" }, true, 0)
		end)
	end },
	-- F87: a context tip's card at the top centre, its bar draining
	{ "TipCard", function()
		UI.tips.show("second_cat")
	end },
	-- F87: the first long return, the offline tip's ribbon on the card (the client tips marked seen, so no stuck cat
	-- or Codes Cat tip pops up in later scenes)
	{ "OfflineTip", function()
		UI.update({ tipsSeen = { stuck_cat = true, codes_cat = true } })
		UI.showOfflineEarnings(48200, 3 * 3600)
	end },
	-- F87 section 2f: a brand new player's small HUD, the money, the hint strip, Home and the Cannon, the Tutorial
	-- tile and Settings
	{ "SmallHUD", function()
		UI.update({ tutorialStep = 0, tier = 1, cats = {}, potions = {}, goldenFish = 0 })
		UI.tutorial.show(UI.tutorial.hint({ tutorialStep = 0, tier = 1, cats = {}, upgradeLevels = {} }))
	end },
	-- the first loop done: every piece comes back, each button with its gold "New!" (from a new player's state to the
	-- sample player again, at step 5)
	{ "SmallHUDNew", function()
		UI.update({ tutorialStep = 0, tier = 1, cats = {}, potions = {}, goldenFish = 0 })
		local player = samplePlayer(os.time())
		player.tutorialStep = 5
		UI.update(player)
	end },
	-- F87 section 2g: "Need a hand?" after 90 s on one tutorial step
	{ "HelpCard", function()
		UI.tutorial.showHelp()
	end },
	{ "CatFound", function()
		UI.showCatFound(Catalog.cats[2].id, true)
	end },
	-- F96: a Bellhop claim that works: the card closes and the claim card shows (after CatFound, which first shows the
	-- card's pieces)
	{ "BellhopClaim", function()
		UI.starterCat.open({ claimed = false, gate = "task", rate = 3 })
		UI.starterCat.result(true)
	end },
	-- F89: this player's big pull card for a gold Mythical cat. It closes by itself at 2.4 s and the gate looks 2.5 s in,
	-- so it starts 0.5 s into the scene, after the word has slammed down and the shake has settled
	{ "BigPullCat", function()
		task.delay(0.5, function()
			UI.securedRare(localUserId(), mythicalCat(), "Mythical", true, "gold")
		end)
	end },
	-- F89 and F99: the longest rarity word, RAINBOW LEGENDARY!, on a rainbow card
	{ "BigPullRainbow", function()
		task.delay(0.5, function()
			UI.securedRare(localUserId(), mythicalCat(), "Legendary", false, "rainbow")
		end)
	end },
	-- F89 section 2b: a Mythical style piece out of a Classic crate: the reveal, then the big card with Use it as the
	-- crate's lid blows open 0.6 s later
	{ "BigPullPiece", function()
		UI.market.open()
		task.delay(0.3, function()
			UI.market.result("classic_crate", "classic_gold_leaf", false, 0)
		end)
	end },
	-- last, since no window closes it: the money's boosts card with a Money Potion running and some boosts bought
	{ "HUDBoosts", function()
		local t = workspace:GetServerTimeNow()
		UI.update({
			buffs = { tip_potion = t + 492, swift_potion = t + 130 },
			fishPerks = { golden_espresso = 2 },
		})
		press("CatCafeHUD", "Counters.Money")
	end },
	-- F88: a Lucky Day with a Lucky Potion running: the Luck chip glowing at the start of the potion row, its card
	-- open over the counters (closing the boosts card), and "Lucky Day now" under the clock
	{ "HUDLuck", function()
		local t = workspace:GetServerTimeNow()
		UI.update({
			luck = 2.3,
			luckSources = {
				{ id = "statue", value = 0.3 },
				{ id = "potion", value = 0.5, endsAt = t + 492 },
				{ id = "lucky_day", value = 0.5, endsAt = t + 190 },
			},
			buffs = { tip_potion = t + 492, swift_potion = t + 130, lucky_potion = t + 492 },
		})
		local clock = Instance.new("Folder")
		clock.Name = "Clock"
		clock:SetAttribute("Phase", "day")
		clock:SetAttribute("PhaseEndsAt", t + 190)
		clock:SetAttribute("AreasOpen", true)
		clock:SetAttribute("Day", 4)
		clock:SetAttribute("NextLuckyDay", 8)
		clock:SetAttribute("LuckyDay", true)
		UI.clock.bind(clock)
		press("CatCafeHUD", "Luck")
	end },
	-- F88: the night before a Lucky Day, LuckyDayWarnSeconds before sunrise: the warning banner and "Lucky Day at
	-- sunrise" under the clock, the Luck card from the scene before closed
	{ "LuckyDaySoon", function()
		local t = workspace:GetServerTimeNow()
		local hud = UIShim.playerGui:FindFirstChild("CatCafeHUD")
		local card = hud and hud:FindFirstChild("LuckCard", true)
		if card and card.Visible then
			press("CatCafeHUD", "LuckCard.Close")
		end
		UI.update({ luck = 1.3, luckSources = { { id = "statue", value = 0.3 } } })
		local clock = Instance.new("Folder")
		clock.Name = "Clock"
		clock:SetAttribute("Phase", "night")
		clock:SetAttribute("PhaseEndsAt", t + 60)
		clock:SetAttribute("AreasOpen", false)
		clock:SetAttribute("Day", 3)
		clock:SetAttribute("NextLuckyDay", 4)
		clock:SetAttribute("LuckyDay", false)
		UI.clock.bind(clock)
		UI.luckyDay("warning", "A Lucky Day starts at sunrise!")
	end },
}

Scenes.names = {}
for _, scene in SCENES do
	table.insert(Scenes.names, scene[1])
end

function Scenes.open(name)
	for _, scene in SCENES do
		if scene[1] == name then
			scene[2]()
			return
		end
	end
	error("uigate: no scene " .. tostring(name))
end

function Scenes.close()
	UI.close()
	UI.catch.hideCircles()
	UI.catch.hide()
	UI.rescue.hide()
	UI.net.setEnabled(false)
	UI.setZone(nil)
	UI.tips.reset()
	UI.tutorial.hide()
	-- the help card waits for Got it
	local ask = UIShim.playerGui:FindFirstChild("CatCafeAsk")
	if ask and ask:FindFirstChild("Choice_ok", true) and ask:FindFirstChild("Card", true).Visible then
		press("CatCafeAsk", "Choice_ok")
	end
	-- the cat found card goes by itself after 5 s; Nice! now, so it is not over the next scene
	local found = UIShim.playerGui:FindFirstChild("CatCafePopups")
	found = found and found:FindFirstChild("CatFound", true)
	if found and found.Visible then
		press("CatCafePopups", "CatFound.Ok")
	end
	-- the big pull card takes a tap after 1 s (F89)
	local pull = UIShim.playerGui:FindFirstChild("CatCafeBigPull")
	if pull and pull.Enabled then
		press("CatCafeBigPull", "Card")
	end
	-- the offline card waits for its Claim
	local popups = UIShim.playerGui:FindFirstChild("CatCafePopups")
	local offline = popups and popups:FindFirstChild("Offline", true)
	if offline and offline.Visible then
		press("CatCafePopups", "Offline.Claim")
	end
end

return Scenes
