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
		allSpots = Catalog.allSpots, -- #2047: as UIController sends it, with the pass-only slots (hidden while locked)
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
		-- a copy the scenes may change (QuestsPassXp, #2070); shared/Catalog's own tables are frozen
		achievementPrizes = (function()
			local copy = {}
			for size, prize in Catalog.achievementPrizes do
				copy[size] = table.clone(prize)
			end
			Scenes._achievementPrizes = copy
			return copy
		end)(),
		dailyTreat = Catalog.dailyTreat,
		catFood = Catalog.catFood, -- #1616: the Bag's Cat food tab rows, as UIController
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
	local rainbowCollection = {} -- F99: four rainbow cats, so rainbow1 and rainbow3 wait on the Rainbow track
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
		if index % 12 == 2 and def.area ~= "spare" and def.exclusive ~= true then
			rainbowCollection[def.id] = now - index * 200
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
		rainbowCollection = rainbowCollection,
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
		-- F91: a lawn half done: two pieces out, two more in the bag, a Red Brick path and the White Picket
		lawnOwned = {
			tulip_bed = true,
			mailbox = true,
			lamp_post = true,
			garden_bench = true,
			red_brick = true,
			white_picket = true,
		},
		lawn = { small1 = "tulip_bed", big1 = "garden_bench" },
		lawnStyles = { path = "red_brick", fence = "white_picket" },
	}
end

-- Config.TipGapSeconds (150 since #2407): the tip queue's gap, read where a scene waits it out
local function tipGap(): number
	return UIShim.require("ReplicatedStorage.Shared.Config").TipGapSeconds :: number
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
	-- F99: the food cards' "Rainbow 0.5%" line shows once the server has rainbow rolls (Gameplay-Engineer)
	Config.RainbowChanceBait = Config.RainbowChanceBait or 0.005
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

-- F92: the first catching area the gate's Tier 1 player has open, for a pal who is out there
-- F100: CampExtrasState for the Tier 3 sample player: the Picnic Basket holding `picnic` potions, the Yard Sale's
-- two crates (`bought` today or not), the Pond and the Lost and Found shut; `open` false shuts all four.
local function campExtras(picnic, bought, open)
	local now = workspace:GetServerTimeNow()
	local on = open ~= false
	return {
		day = math.floor(now / 86400),
		picnic = { open = on, held = picnic, nextAt = if picnic < 2 then now + 7800 else nil },
		yardSale = {
			open = on,
			held = if bought then 0 else 2,
			nextAt = now + 3 * 3600,
			stock = {
				{ crateId = "park_crate", price = 0, bought = bought }, -- #1051: one free crate a day
			},
		},
		pond = { open = false, held = 0 },
		lostFound = { open = false, held = 0 },
	}
end

-- #2078: a Rescue Rally bar's count ("45 / 90") clear of every step marker, each marker's number (the points it
-- pays at) under it, numbers and markers clear of each other, and all of it above `belowY` (the next row's top).
local function assertRallyBar(track, expected, belowY)
	assert(track and track:IsA("GuiObject") and track.Visible, "uigate: no Rescue Rally bar on screen (#2078)")
	local function box(object)
		local at, size = object.AbsolutePosition, object.AbsoluteSize
		return at.X, at.Y, at.X + size.X, at.Y + size.Y
	end
	local function textBox(label)
		local x1, y1, x2, y2 = box(label)
		local bounds = label.TextBounds
		local mid = (x1 + x2) / 2
		if label.TextXAlignment == Enum.TextXAlignment.Left then
			return x1, (y1 + y2 - bounds.Y) / 2, x1 + bounds.X, (y1 + y2 + bounds.Y) / 2
		end
		return mid - bounds.X / 2, (y1 + y2 - bounds.Y) / 2, mid + bounds.X / 2, (y1 + y2 + bounds.Y) / 2
	end
	local function clear(a, b)
		local ax1, ay1, ax2, ay2 = table.unpack(a)
		local bx1, by1, bx2, by2 = table.unpack(b)
		return ax2 <= bx1 + 0.5 or bx2 <= ax1 + 0.5 or ay2 <= by1 + 0.5 or by2 <= ay1 + 0.5
	end
	local points = track:FindFirstChild("Points")
	assert(points and points:IsA("TextLabel") and points.Text ~= "", "uigate: the Rally bar has no count (#2078)")
	local count = { textBox(points) }
	assert(points.TextFits, "uigate: the Rally count " .. points.Text .. " does not fit its label (#2078)")
	local numbers = {}
	for index, at in expected do
		local marker = track:FindFirstChild("Step" .. index)
		assert(marker and marker.Visible, "uigate: the Rally bar has no step " .. index .. " (#2078)")
		local markerBox = { box(marker) }
		assert(
			clear(count, markerBox),
			string.format("uigate: step %d's picture covers the Rally count %s (#2078)", index, points.Text)
		)
		local number = marker:FindFirstChild("At")
		assert(
			number and number.Visible and number.Text == tostring(at),
			string.format("uigate: step %d shows %q under it, not %d (#2078)", index, number and number.Text or "", at)
		)
		local numberBox = { textBox(number) }
		assert(clear(count, numberBox), "uigate: step " .. index .. "'s number runs into the Rally count (#2078)")
		assert(numberBox[4] <= belowY + 0.5, "uigate: step " .. index .. "'s number runs into the row under the bar (#2078)")
		for other, otherBox in numbers do
			assert(clear(numberBox, otherBox), string.format("uigate: steps %d and %d's numbers overlap (#2078)", other, index))
		end
		numbers[index] = numberBox
		local previous = track:FindFirstChild("Step" .. (index - 1))
		if previous then
			assert(clear(markerBox, { box(previous) }), string.format("uigate: steps %d and %d overlap (#2078)", index - 1, index))
		end
	end
end

-- F101: a RallyState, running for another day and 4 hours unless `fields` says otherwise.
-- F102: other players in the server for the Trade window's list (removed again by Scenes.close)
local tradePlayers = {}
local function addTradePlayer(name, userId, tier, busy)
	local player = Instance.new("Player")
	player.Name = name
	player.DisplayName = name
	player.UserId = userId
	workspace:SetAttribute("TradingOn", true) -- TradeService is live, so the HUD shows the Trade tile
	player:SetAttribute("Tier", tier)
	player:SetAttribute("Trading", busy == true)
	player.Parent = game:GetService("Players")
	table.insert(tradePlayers, player)
end

-- F102: the Trades page's log: three trades (one a gift from me, one with nine cats each way), newest first
local function tradeLog(now)
	local function pick(rarity, index)
		local found = 0
		for _, def in Catalog.cats do
			if def.rarity == rarity and def.exclusive ~= true then
				found += 1
				if found == index then
					return def.id
				end
			end
		end
		return Catalog.cats[1].id
	end
	local nine = {}
	for index = 1, 9 do
		local rarity = if index % 3 == 0 then "Epic" elseif index % 2 == 0 then "Rare" else "Common"
		table.insert(nine, { catId = pick(rarity, 1 + index % 2), rarity = rarity, level = index + 2 })
	end
	return {
		{
			id = "log_1",
			at = now - 12 * 60,
			partnerName = "Sam",
			gave = { { catId = pick("Common", 1), rarity = "Common", level = 11 } },
			got = { { catId = pick("Epic", 1), rarity = "Epic", variant = "gold", level = 18 } },
		},
		{
			id = "log_2",
			at = now - 26 * 3600,
			partnerName = "Mia",
			gave = { { catId = pick("Rare", 1), rarity = "Rare", variant = "rainbow", level = 7 } },
			got = {},
		},
		{ id = "log_3", at = now - 4 * 86400, partnerName = "Alexandria_Longname", gave = nine, got = nine },
	}
end

-- F102: a TradeState with Sam: my offer from the sample player's cats (gate_1, the gold gate_3, gate_5), Sam's an
-- Epic and a rainbow Rare from the catalog; `fields` overrides
local function tradeState(fields)
	workspace:SetAttribute("TradingOn", true)
	local function firstOf(rarity, skip)
		for _, def in Catalog.cats do
			if def.rarity == rarity and def.exclusive ~= true and def.id ~= skip then
				return def.id
			end
		end
		return Catalog.cats[1].id
	end
	local function mine(uid, rate)
		local cat = samplePlayer(workspace:GetServerTimeNow()).cats[uid]
		local def = Catalog.getCat(cat.catId)
		return {
			uid = uid,
			catId = cat.catId,
			rarity = def and def.rarity or "Common",
			variant = if cat.variant == "gold" then "gold" else nil,
			level = cat.level,
			rateForMe = rate,
		}
	end
	local state = {
		tradeId = "gate_trade",
		version = 3,
		phase = "offer",
		me = {
			userId = 1,
			name = "Tester",
			ready = false,
			confirmed = false,
			cats = { mine("gate_1", 12), mine("gate_3", 110), mine("gate_5", 62) },
		},
		them = {
			userId = 4242,
			name = "Sam",
			ready = true,
			confirmed = false,
			cats = {
				{ uid = "sam_1", catId = firstOf("Epic"), rarity = "Epic", level = 18, rateForMe = 240 },
				{
					uid = "sam_2",
					catId = firstOf("Rare"),
					rarity = "Rare",
					variant = "rainbow",
					level = 7,
					rateForMe = 1250,
				},
			},
		},
		giveValue = 12,
		getValue = 41,
		lopsided = false,
		gift = false,
		myRateNow = 184,
		theirRateForMe = 1490,
	}
	for key, value in fields or {} do
		state[key] = value
	end
	return state
end

-- #2487: a Cafe Party on ReplicatedStorage's attributes (EventService's shape, shared/CafeEvents), painted at once
local function cafeEvent(fields: { [string]: any })
	local store = game:GetService("ReplicatedStorage")
	local attrs: { [string]: any } = {
		EventId = "party-gate",
		EventTitle = "Cafe Party",
		EventEffects = "gate-full",
	}
	-- the shim has no HttpService: the gate's one effects string decodes to the full party's effects
	UI.cafeEvent.decode = function(json: string): any
		if json ~= "gate-full" then
			return nil
		end
		return {
			days = { "lucky", "golden", "rainbow" },
			money = 2,
			luck = 0.5,
			showers = { count = 8, gapSeconds = 900, firstAfter = 600 },
			reward = { cosmeticId = "Decor_PartyBunting" },
		}
	end
	for key, value in fields do
		attrs[key] = value
	end
	for key, value in attrs do
		store:SetAttribute(key, value)
	end
	-- the chip sits under the day clock and shows with it
	local clock = Instance.new("Folder")
	clock.Name = "Clock"
	clock:SetAttribute("Phase", "day")
	clock:SetAttribute("PhaseEndsAt", workspace:GetServerTimeNow() + 300)
	clock:SetAttribute("AreasOpen", true)
	clock:SetAttribute("Day", 3)
	clock:SetAttribute("NextLuckyDay", 5)
	clock:SetAttribute("LuckyDay", false)
	UI.clock.bind(clock)
	UI.cafeEvent.tick()
end

-- #2487: the event chip shows with `lines` lines, its words fit, and it ends above the goal card
local function assertEventChip(lines: number): TextLabel
	local hud = UIShim.playerGui:FindFirstChild("CatCafeHUD") :: ScreenGui
	local chip = hud:FindFirstChild("EventChip", true) :: TextLabel
	assert(chip and chip.Visible, "uigate: no Cafe Event chip under the clock (#2487)")
	assert(chip.TextFits, "uigate: the Cafe Event chip's words do not fit (#2487)")
	local nextLine = hud:FindFirstChild("EventNext", true) :: TextLabel
	local shown = if nextLine.Visible then 2 else 1
	assert(shown == lines, ("uigate: the Cafe Event chip has %d lines, not %d (#2487)"):format(shown, lines))
	assert(not nextLine.Visible or nextLine.TextFits, "uigate: the next shower line does not fit (#2487)")
	local last = if nextLine.Visible then nextLine else chip
	local chipBottom = chip.AbsolutePosition.Y + chip.AbsoluteSize.Y
	assert(last == chip or last.AbsolutePosition.Y >= chipBottom - 1, "uigate: the next shower line is over the chip (#2487)")
	local goal = hud:FindFirstChild("TierGoal", true) :: GuiObject?
	if goal and goal.Visible then
		local bottom = last.AbsolutePosition.Y + last.AbsoluteSize.Y
		assert(bottom <= goal.AbsolutePosition.Y + 1, "uigate: the Cafe Event chip runs into the goal card (#2487)")
	end
	return chip
end

local function rallyState(fields)
	local t = workspace:GetServerTimeNow()
	local state = {
		active = true,
		endsAt = t + 28 * 3600,
		startsAt = t - 20 * 3600,
		lap = 1,
		goal = 90,
		points = 0,
		myPoints = 0,
		lapsPaid = 0,
		lapsDone = false,
	}
	for key, value in fields do
		state[key] = value
	end
	return state
end

-- #2098: the Rally banner only pops up when this player scores: a state one point down, then `fields`, so the scene
-- shows the banner up just after a catch (Scenes.close ends the Rally again, which puts it away).
local function rallyScore(fields)
	local before = table.clone(fields)
	before.myPoints = (fields.myPoints or 1) - 1
	UI.rally.update(rallyState(before))
	UI.rally.update(rallyState(fields))
	Scenes._rallyPeek = true
end

local function firstArea()
	for _, area in Catalog.areas do
		if area.tier <= 1 then
			return area.id
		end
	end
	return Catalog.areas[1].id
end

-- F103: the crate reel plays once shared Config has its numbers (Gameplay-Engineer adds them); the reel scenes turn
-- them on and Scenes.close turns them off again, so the other Market scenes keep the card reveal
-- the Store's prices as Roblox would answer them: the plan's money ladder (R$5, R$15, R$25) and Long Nap (R$199)
local function storePrices(forSale)
	local Config = UIShim.require("ReplicatedStorage.Shared.Config")
	local robux = { [2] = 5, [3] = 15, [4] = 25 }
	local prices = {}
	for multiplier, id in Config.MoneyPassIds do
		prices[id] = { robux = robux[multiplier] or 25, forSale = forSale }
	end
	prices[Config.LongNapPassId] = { robux = 199, forSale = forSale }
	-- #1425: the rest of the passes and the potion packs at store-skus.md's prices, so every tab has priced cards
	local others = {
		VipPassId = 25,
		CatAccessoriesPassId = 149,
		UniformStylesPassId = 149,
		CafeStylePassId = 249,
		GrandThemePassId = 799,
		RoyalCatPassId = 599,
		KingPackPassId = 999,
		GardenDecorPackPassId = 149, -- #1168: shows once its id is set
		SecondBowlPassId = 149, -- #2010: the Cats tab's Second Bait Bowl card
	}
	for key, robux in others do
		local id = Config[key]
		if type(id) == "number" and id ~= 0 then
			prices[id] = { robux = robux, forSale = forSale }
		end
	end
	local slots = Config.ExtraSlotPassIds
	if type(slots) == "table" then
		for _, id in slots do
			prices[id] = { robux = 149, forSale = forSale }
		end
	end
	local packs = { potion_pack_xs = 10, potion_pack_s = 25, potion_pack_m = 49, potion_pack_l = 99, steady_paw_pack = 25 }
	for key, robux in packs do
		local id = (Config.ProductIds or {})[key]
		if type(id) == "number" and id ~= 0 then
			prices[id] = { robux = robux, forSale = forSale }
		end
	end
	return prices
end

local REEL_CONFIG = {
	CrateReelTiles = 40,
	CrateReelLandingTile = 34,
	CrateReelProtectFrom = 26,
	CrateReelProtectTo = 37,
	CrateReelTopSpeed = 15,
	CrateReelRampSeconds = 0.3,
	CrateReelStopSeconds = 0.8,
	CrateReelHoldSeconds = 0.25,
}
local reelWasOn = nil
local function reel(on)
	local Config = UIShim.require("ReplicatedStorage.Shared.Config")
	if reelWasOn == nil then
		reelWasOn = Config.CrateReelTiles ~= nil
	end
	if reelWasOn then
		return -- the real Config has them: leave them be
	end
	for key, value in REEL_CONFIG do
		Config[key] = if on then value else nil
	end
end

-- an F99 rainbow cat for the cat room: the first Epic in the catalog, level 8, resting
local function rainbowCat()
	local catId = Catalog.cats[1].id
	for _, def in Catalog.cats do
		if def.rarity == "Epic" then
			catId = def.id
			break
		end
	end
	return {
		uid = "gate_rainbow",
		catId = catId,
		variant = "rainbow",
		caughtAt = os.time() - 20,
		level = 8,
		xp = 0,
		xpToNext = 400,
		charm = 70,
		stars = 4,
		rating = 900,
	}
end

-- an F98 LeaderboardSync: full top 50 lists with long names, this player (id 1) fourth on all time Money and off
-- this week's list
local function leaderboardSync()
	local names = { "Mittens4Ever", "xX_CatQueen_Xx", "SuperLongDisplayName", "Biscuit", "TunaTycoon", "Pawsome" }
	local function list(count, top, step, first)
		local rows = {}
		for rank = 1, count do
			local userId = if rank == 4 and first then 1 else 1000 + rank
			table.insert(rows, {
				rank = rank,
				userId = userId,
				name = if userId == 1 then "You Player" else names[(rank - 1) % #names + 1] .. rank,
				value = math.max(top - (rank - 1) * step, 1),
				crown = rank <= 10,
			})
		end
		return rows
	end
	return {
		boards = {
			index = { allTime = list(50, 68, 1) },
			playtime = { allTime = list(50, 2472 * 4, 90), week = list(24, 1860, 60) },
			money = { allTime = list(50, 1240000000, 22000000, true), week = list(50, 8400000, 150000) },
		},
		me = {
			index = { value = 31 },
			playtime = { rank = 37, value = 2472 },
			money = { rank = 4, value = 1174000000 },
		},
		week = 2901,
	}
end

-- #1221 (Derek 2026-11-04: the Store's pass cards "push out past the sides" and "lose their outlines"): every card
-- shown, its gold outline included, sits inside the page's edges with the scroll bar's strip left clear, and its
-- description stays inside the card and clear of its button. #1425: on Featured (`featured` true) the hero and the
-- three picks also fit the page's height, since that tab never scrolls. Fails the scene when a card or its words run
-- past.
local function assertStoreCards(featured)
	local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
	local window = modals and modals:FindFirstChild("Store", true)
	local pageName = if featured then "Featured" else "List"
	local page = window and window:FindFirstChild(pageName, true)
	assert(page and page:IsA("GuiObject") and page.Visible, "uigate: the Store window's " .. pageName .. " page is not up")
	local left = page.AbsolutePosition.X
	local right = left + page.AbsoluteSize.X
	local top = page.AbsolutePosition.Y
	local bottom = top + page.AbsoluteSize.Y
	local cards = 0
	for _, card in page:GetDescendants() do
		if not card:IsA("Frame") or card:FindFirstChild("Buy") == nil or not card.Visible then
			continue
		end
		local parent = card.Parent
		if parent and parent:IsA("GuiObject") and not parent.Visible then
			continue
		end
		local buy = card:FindFirstChild("Buy")
		local stroke = card:FindFirstChildOfClass("UIStroke")
		assert(buy and buy:IsA("GuiObject") and stroke, "uigate: Store card " .. card.Name .. " has no button or outline")
		local k = buy.AbsoluteSize.Y / buy.Size.Y.Offset -- design px to screen px (the window's UIScale)
		local outline = stroke.Thickness * k
		local bar = if page:IsA("ScrollingFrame") then page.ScrollBarThickness * k else 0
		local x1 = card.AbsolutePosition.X - outline
		local x2 = card.AbsolutePosition.X + card.AbsoluteSize.X + outline
		assert(
			x1 >= left - 0.5 and x2 <= right - bar + 0.5,
			string.format(
				"uigate: Store card %s runs past the page's inner edge (%.1f to %.1f, page %.1f to %.1f less a %.1f px bar, #1221)",
				card.Name,
				x1,
				x2,
				left,
				right,
				bar
			)
		)
		if featured then
			local y1 = card.AbsolutePosition.Y - outline
			local y2 = card.AbsolutePosition.Y + card.AbsoluteSize.Y + outline
			assert(
				y1 >= top - 0.5 and y2 <= bottom + 0.5,
				string.format(
					"uigate: Featured card %s does not fit the page's height (%.1f to %.1f, page %.1f to %.1f, #1425)",
					card.Name,
					y1,
					y2,
					top,
					bottom
				)
			)
		end
		local effect = card:FindFirstChild("Effect")
		if effect and effect:IsA("TextLabel") and effect.Text ~= "" then
			local effectBottom = effect.AbsolutePosition.Y + effect.AbsoluteSize.Y
			local cardBottom = card.AbsolutePosition.Y + card.AbsoluteSize.Y
			local clear = effect.AbsolutePosition.X + effect.AbsoluteSize.X <= buy.AbsolutePosition.X + 0.5
				or effectBottom <= buy.AbsolutePosition.Y + 0.5
			assert(
				effectBottom <= cardBottom + 0.5 and clear,
				"uigate: Store card " .. card.Name .. "'s description runs out of the card or under its button (#1221)"
			)
		end
		cards += 1
	end
	assert(cards > 0, "uigate: the Store window shows no cards on " .. pageName)
	if featured then
		local hero = page:FindFirstChild("hero")
		local picks = page:FindFirstChild("Picks")
		if hero and hero.Visible and picks and picks.Visible then
			assert(
				hero.AbsolutePosition.Y + hero.AbsoluteSize.Y <= picks.AbsolutePosition.Y + 0.5,
				"uigate: the Store's hero card runs over its top picks (#1425)"
			)
		end
	end
end

-- presses a button the way a player does: the first TextButton or ImageButton named `name` under the window;
-- "Daily.Quest2.Claim" walks down one name at a time
-- #2314: tutorial step 3 (a table to buy), with its strip, so the Upgrades tile glows and the big arrow comes
-- #2403 (Derek2: "the equip best for decor top of banner is too big and sticking out and also equip best disappears
-- while in style menu"): the Decor window's Equip Best shows, within its header's top and bottom edges
local function assertEquipBestInHeader(where: string)
	local modal = UIShim.playerGui:FindFirstChild("CatCafeModals") :: ScreenGui
	local best = modal:FindFirstChild("EquipBest", true) :: GuiObject
	assert(best and best.Visible, "uigate: no Equip Best on " .. where .. " (#2403)")
	local header = (best.Parent :: Instance):FindFirstChild("Header", true) :: GuiObject
	assert(header, "uigate: the Decor window has no header (#2403)")
	local top, bottom = best.AbsolutePosition.Y, best.AbsolutePosition.Y + best.AbsoluteSize.Y
	local headTop, headBottom = header.AbsolutePosition.Y, header.AbsolutePosition.Y + header.AbsoluteSize.Y
	assert(
		top >= headTop - 1 and bottom <= headBottom + 1,
		("uigate: Equip Best (%d to %d) sticks out of the header (%d to %d) on %s (#2403)"):format(
			top,
			bottom,
			headTop,
			headBottom,
			where
		)
	)
end

local function tutorialArrowStep()
	local levels = { tables = 0, lure_bowl = 0, espresso = 0, net = 0, lucky_cat = 0 }
	UI.update({ tutorialStep = 3, tier = 1, upgradeLevels = levels } :: any)
	UI.tutorial.show(UI.tutorial.hint({ tutorialStep = 3, tier = 1, cats = {}, upgradeLevels = levels }))
	task.wait(0.1)
end
-- #2314: the big arrow shows, whole on the screen, off `target` and within 24 px of it
local function assertArrowAt(target: GuiObject, where: string)
	local found: GuiObject? = nil
	for _, piece in UIShim.playerGui:GetDescendants() do
		if piece.Name == "TutorialArrow" and piece:IsA("GuiObject") and piece.Visible then
			found = piece
		end
	end
	assert(found, "uigate: no tutorial arrow at " .. where .. " (#2314)")
	local arrow = found :: GuiObject
	local a0, a1 = arrow.AbsolutePosition, arrow.AbsolutePosition + arrow.AbsoluteSize
	local t0, t1 = target.AbsolutePosition, target.AbsolutePosition + target.AbsoluteSize
	local screen = (arrow:FindFirstAncestorWhichIsA("ScreenGui") :: ScreenGui).AbsoluteSize
	assert(
		a0.X >= -1 and a0.Y >= -1 and a1.X <= screen.X + 1 and a1.Y <= screen.Y + 1,
		("uigate: the arrow at %s runs off the screen (%d,%d to %d,%d) (#2314)"):format(where, a0.X, a0.Y, a1.X, a1.Y)
	)
	local overlaps = a0.X < t1.X - 1 and t0.X < a1.X - 1 and a0.Y < t1.Y - 1 and t0.Y < a1.Y - 1
	assert(not overlaps, "uigate: the arrow covers " .. where .. " (#2314)")
	local gap = math.max(t0.X - a1.X, a0.X - t1.X, t0.Y - a1.Y, a0.Y - t1.Y)
	assert(gap < 24, ("uigate: the arrow sits %d px from %s (#2314)"):format(gap, where))
end
-- #1161: the Bait bowl window, and its bowl tabs shown with `selected` chosen and the status title holding `title`.
local function baitWindow()
	local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
	local window = modals and modals:FindFirstChild("Bait", true)
	assert(window, "uigate: no Bait window")
	return window
end
local function assertBowlTabs(selected, title)
	local window = baitWindow()
	local tabs = window:FindFirstChild("Bowls", true)
	assert(tabs and tabs.Visible, "uigate: two bowls but no bowl tabs (#1161)")
	local shown = window:FindFirstChild("Status", true):FindFirstChild("Title").Text
	assert(string.find(shown, title, 1, true), ("uigate: bowl %d's card says %q (#1161)"):format(selected, shown))
end

-- #1161: the status card's button reads `text`
local function assertBowlAction(text)
	local status = baitWindow():FindFirstChild("Status", true)
	local action = status and status:FindFirstChild("Action", true)
	assert(action and action.Visible, "uigate: the bowl card has no button (#1161)")
	local shown = action:FindFirstChildWhichIsA("TextLabel", true)
	local label = if action:IsA("TextButton") then action.Text elseif shown then shown.Text else ""
	assert(string.find(label, text, 1, true), ("uigate: the bowl card's button says %q (#1161)"):format(label))
end
-- #1161: the HUD's bowl tile with its "2", and its "!" while a cat waits at either bowl
local function assertBowlTile(catWaiting)
	local hud = UIShim.playerGui:FindFirstChild("CatCafeHUD")
	local tile = hud and hud:FindFirstChild("Bowl", true)
	assert(tile and tile.Visible, "uigate: no HUD bowl tile (#1161)")
	local count = tile:FindFirstChild("Count", true)
	assert(count and count.Visible, "uigate: the HUD bowl tile has no 2 with two bowls (#1161)")
	local mark = tile:FindFirstChild("Claim")
	assert(mark and mark.Visible == catWaiting, "uigate: the HUD bowl tile's ! is wrong for a waiting cat (#1161)")
end

-- #2588: whether a window's corner badge (Components/Panel) draws the picture with this asset id
local function badgeDraws(windowName: string, assetId: string): boolean
	local window = UIShim.playerGui:FindFirstChild(windowName, true)
	local badge = window and window:FindFirstChild("Badge", true)
	if badge == nil then
		return false
	end
	for _, piece in badge:GetDescendants() do
		if piece:IsA("ImageLabel") and string.find(piece.Image, assetId, 1, true) then
			return true
		end
	end
	return false
end

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
	-- on a touch screen a Components/Button's face stops taking input and its Hit pad takes the tap
	local button = nil
	if holder:IsA("GuiButton") and holder.Interactable ~= false then
		button = holder
	else
		for _, piece in holder:GetDescendants() do
			if piece:IsA("GuiButton") and piece.Interactable ~= false then
				button = piece
				break
			end
		end
	end
	assert(button, "uigate: " .. name .. " has no button")
	UIShim.fire(UIShim.eventOf(button, "Activated")) -- Components/Button listens to Activated only
end

-- #1919: the first cat of an area that the sample player has not found (every other catalog cat is), Epic and up
-- when `shy`
local function missingCat(areaId, shy)
	for index, def in Catalog.cats do
		local rare = def.rarity == "Epic" or def.rarity == "Legendary" or def.rarity == "Mythical"
		if index % 2 == 0 and def.area == areaId and def.exclusive ~= true and (shy == nil or rare == shy) then
			return def
		end
	end
	error("uigate: no missing cat in " .. areaId)
end

-- #1919: the Index's detail line for a missing cat (its tile on the area's page, opened with a tap)
local function indexHint(def)
	UI.openIndex(def.area)
	press("Collection", def.id)
	local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
	local window = modals and modals:FindFirstChild("Collection", true)
	local cover = window and window:FindFirstChild("Description", true)
	assert(cover, "uigate: no detail card description in the Index")
	return cover.Text
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

-- Catch v3 (#1884): the same circles with CatchSchedule's trust and ring kinds, over a stray model tagged as the
-- server tags them (kinds: a list of "single", "double" or "paw", one per ring)
local function startCatchV3(strayId, rarity, kinds, trustStart, trustNeed, info)
	local model = Instance.new("Model")
	model.Name = "Stray_" .. strayId
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2, 2, 3)
	body.Position = Vector3.new(0, 3, -12)
	body.Parent = model
	model.PrimaryPart = body
	model:SetAttribute("StrayId", strayId)
	model.Parent = workspace
	model:AddTag("Stray")
	local t = workspace:GetServerTimeNow()
	local list = {}
	local at = t + 0.3
	local doubles = 0 -- a double's halves come in pairs, half 1 then half 2, DoubleRingGap apart
	-- #2060: spots as the server rolls them (0.25 to 0.75 by 0.3 to 0.7); a double's second half keeps the first's
	local rolls = { { 0.3, 0.35 }, { 0.7, 0.62 }, { 0.42, 0.68 }, { 0.62, 0.32 }, { 0.28, 0.6 }, { 0.55, 0.5 } }
	local roll = 0
	for _, kind in kinds do
		local half = nil
		if kind == "double" then
			doubles += 1
			half = (doubles - 1) % 2 + 1
		end
		if half ~= 2 then
			roll = roll % #rolls + 1
		end
		local spot = rolls[roll]
		table.insert(list, {
			startsAt = at,
			shrinkSeconds = 0.8,
			x = spot[1],
			y = spot[2],
			kind = kind,
			half = half,
		})
		at += if half == 1 then UIShim.require("ReplicatedStorage.Shared.Config").DoubleRingGap else 0.7
	end
	UI.catch.show(info or { strayId = strayId, catId = Catalog.cats[2].id, catName = "Mochi", rarity = rarity })
	UI.catch.showCircles(strayId, list, { perfect = 0.037, good = 0.09 }, trustStart, trustNeed)
	return list, model
end

-- a tap anywhere on the circles, as a finger does
local function tapCircles()
	local tap = UIShim.playerGui:FindFirstChild("CatCafeCatchCircles"):FindFirstChild("Tap")
	UIShim.fire(UIShim.eventOf(tap, "InputBegan"), {
		UserInputType = Enum.UserInputType.Touch,
		Position = Vector3.new(400, 300, 0),
	})
end

-- F91: the player's own plot as UIController binds it, with the lawn live (LawnPath) and the six LawnSpots parts
local lawnPlot = nil
local function bindLawnPlot()
	if lawnPlot == nil then
		local Lawn = UIShim.require("ReplicatedStorage.Shared.Lawn")
		local plot = Instance.new("Model")
		plot.Name = "Plot_1"
		plot:SetAttribute("LawnPath", "red_brick")
		local spots = Instance.new("Folder")
		spots.Name = "LawnSpots"
		spots.Parent = plot
		for _, spot in Lawn.SPOTS do
			local part = Instance.new("Part")
			part.Name = spot.id
			part.Anchored = true
			part.Position = Vector3.new(spot.x, spot.y, spot.z)
			part.Parent = spots
		end
		plot.Parent = workspace
		lawnPlot = plot
	end
	UI.richTip.bind(lawnPlot)
end

-- name, how the game opens it
local SCENES = {
	{ "Upgrades", function()
		UI.open("Upgrades")
		-- #2339 (Laptop-Tester, iPhone SE: "windows show only about 1.5 rows"): on a short screen the list shows at
		-- least two and a half of its 104 px rows
		local Scale = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Scale")
		if Scale.isShort() then
			local modal = UIShim.playerGui:FindFirstChild("CatCafeModals") :: ScreenGui
			local list = modal:FindFirstChild("List", true) :: ScrollingFrame
			local rows = list.AbsoluteSize.Y / (104 * Scale.get())
			assert(rows >= 2.5, ("uigate: the Upgrades list shows %.1f rows on a short screen (#2339)"):format(rows))
		end
	end },
	{ "Decor", function()
		UI.open("Decor")
		assertEquipBestInHeader("the All tab")
	end },
	-- #2053 (Derek2: "fish tank background shows blue but its an epic"): a crate piece's picture sits on its rarity's
	-- tint (the Epic Fish tank purple, the Rare Neon cat sign blue), as its pill
	{ "DecorRarityTint", function()
		local before = UI.getState() :: any
		local owned = table.clone(before.decorOwned or {})
		owned.fish_tank = true
		owned.neon_sign = true
		Scenes._decorOwned = before.decorOwned or {}
		UI.update({ decorOwned = owned } :: any)
		UI.open("Decor")
		task.wait(0.05)
		local Theme = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Theme")
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		-- a lightened tint keeps the hue: the strongest channel of the rarity stays the strongest
		local function top(c: Color3): string
			return if c.R >= c.G and c.R >= c.B then "R" elseif c.G >= c.B then "G" else "B"
		end
		for id, rarity in { fish_tank = "Epic", neon_sign = "Rare" } do
			local card = modals:FindFirstChild(id, true)
			local art = card and card:FindFirstChild("Art")
			assert(art, "uigate: no " .. id .. " card in the Decor window")
			local want = Theme.rarityColor(rarity)
			local got = (art :: Frame).BackgroundColor3
			assert(top(got) == top(want), ("uigate: %s's picture sits on %s, not its %s tint (#2053)"):format(id, tostring(got), rarity))
		end
	end },
	-- F91, #1283: the Lawn chip, the total over the owned pieces, path and fence cards (out first)
	{ "DecorLawn", function()
		bindLawnPlot()
		UI.open("Decor")
		press("Decor", "FrontLawn")
		-- #1751: the Garden Bench is out (Remove), the Lamp Post stored (Use)
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local lawn = modals and modals:FindFirstChild("Lawn", true)
		local function action(id: string): string
			local card = lawn and lawn:FindFirstChild(id, true)
			local button = card and card:FindFirstChild("Action", true)
			local label = button and (if button:IsA("TextButton") then button else button:FindFirstChildWhichIsA("TextLabel", true))
			return if label then label.Text else "?"
		end
		assert(string.find(action("garden_bench"), "Remove", 1, true), "uigate: the out Garden Bench reads " .. action("garden_bench") .. " (#1751)")
		assert(string.find(action("lamp_post"), "Use", 1, true), "uigate: the stored Lamp Post reads " .. action("lamp_post") .. " (#1751)")
		-- #2081: Big spots, Small spots, then Paths and fences, top to bottom, each card under its own heading, and no
		-- per-card "Big spot" tag (#1729's, which the headings replace)
		local Lawn = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Components.LawnLogic")
		local lastY = -math.huge
		for _, group in Lawn.groups(UI.getState()) do
			local heading = lawn and lawn:FindFirstChild("Heading_" .. group.key, true)
			local cells = lawn and lawn:FindFirstChild("Cards_" .. group.key, true)
			assert(heading and heading:IsA("TextLabel") and heading.Visible, "uigate: no " .. group.key .. " heading on the Lawn chip (#2081)")
			assert(cells and cells:IsA("GuiObject"), "uigate: no " .. group.key .. " grid on the Lawn chip (#2081)")
			assert(heading.Text == group.title, ("uigate: the %s heading reads %q, not %q (#2081)"):format(group.key, heading.Text, group.title))
			assert(heading.AbsolutePosition.Y > lastY, "uigate: the " .. group.key .. " heading is above the one before it (#2081)")
			assert(cells.AbsolutePosition.Y >= heading.AbsolutePosition.Y + heading.AbsoluteSize.Y - 1, "uigate: the " .. group.key .. " cards start above their heading (#2081)")
			for _, card in group.cards do
				local frame = cells:FindFirstChild(card.id)
				assert(frame and (frame :: GuiObject).Visible, ("uigate: %s is not under the %s heading (#2081)"):format(card.id, group.key))
				assert(frame:FindFirstChild("BigSpot") == nil, "uigate: " .. card.id .. " still has a Big spot tag (#2081)")
			end
			lastY = cells.AbsolutePosition.Y
		end
		assert(lawn:FindFirstChild("Heading_big", true), "uigate: the Garden Bench's Big spots heading is missing (#2081)")
		assert(lawn:FindFirstChild("Heading_styles", true), "uigate: the Paths and fences heading is missing (#2081)")
	end },
	-- #2075 (Derek2: "uncommon and common use same color background and golden background looks too plain"): the
	-- Uncommon Mailbox's tile in mint, apart from the Common Tulip Bed's, and a Golden piece on its gold sheen
	{ "DecorLawnRarity", function()
		bindLawnPlot()
		local owned = table.clone(samplePlayer(os.time()).lawnOwned)
		Scenes._lawnOwned = table.clone(owned)
		owned.golden_paw_statue = true
		UI.update({ lawnOwned = owned } :: any)
		UI.open("Decor")
		press("Decor", "FrontLawn")
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local lawn = modals and modals:FindFirstChild("Lawn", true)
		local function tile(id)
			local card = lawn and lawn:FindFirstChild(id, true)
			return card and card:FindFirstChild("Icon")
		end
		local common, uncommon, golden = tile("tulip_bed"), tile("mailbox"), tile("golden_paw_statue")
		assert(common and uncommon and golden, "uigate: a lawn card is missing (#2075)")
		local a, b = common.BackgroundColor3, uncommon.BackgroundColor3
		assert(math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) > 0.1,
			"uigate: Uncommon's lawn tile is Common's colour (#2075)")
		assert(b.G > b.R, "uigate: Uncommon's lawn tile isn't mint (#2075)")
		local sheen = golden:FindFirstChild("GoldenSheen")
		assert(sheen and sheen.Enabled, "uigate: the Golden lawn piece has no gold sheen (#2075)")
		assert(common:FindFirstChild("GoldenSheen") == nil or not common.GoldenSheen.Enabled,
			"uigate: a Common lawn piece shines gold (#2075)")
		local pill = uncommon.Parent:FindFirstChild("Rarity")
		assert(pill and pill.BackgroundColor3.G > pill.BackgroundColor3.R, "uigate: the Uncommon pill isn't mint (#2075)")
	end },
	-- #1624: the Style tab, the cafe sign (Royal Crest in use) and the uniforms once the server sends looks
	{ "DecorStyle", function()
		UI.update({
			signStyles = { "bakery_stripes", "royal_crest" },
			signStyle = "royal_crest",
			looks = {
				uniform = "midnight",
				uniforms = { "default", "striped", "midnight", "mint", "uniform_pumpkin" },
				accessory = "hat", -- #1708
				accessories = { "hat", "glasses", "acc_leaf_beret", "acc_tiny_lantern" },
				theme = "garden",
				themes = { "default", "garden", "grand" },
			},
		})
		UI.open("Decor")
		press("Decor", "Style")
		assertEquipBestInHeader("the Style tab")
	end },
	-- #2147 (store-pass-looks.md 7.4): with the Cat Accessories pass owned, the accessory row has its small gold line
	-- under the buttons, "+15% money on every working cat, whatever you pick"
	{ "DecorStyleOutfitNote", function()
		local Config = UIShim.require("ReplicatedStorage.Shared.Config")
		UI.store.preview(storePrices(true), { [Config.CatAccessoriesPassId] = true })
		UI.update({
			looks = {
				uniform = "midnight",
				uniforms = { "default", "striped", "midnight" },
				accessory = "",
				accessories = { "hat", "glasses" },
				theme = "garden",
				themes = { "default", "garden" },
			},
		})
		UI.open("Decor")
		press("Decor", "Style")
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local tab = modals and modals:FindFirstChild("StyleTab", true)
		local row = tab and tab:FindFirstChild("accessory")
		local note = row and row:FindFirstChild("Note") :: TextLabel?
		assert(note and note.Visible, "uigate: no +15% line under the accessory row (#2147)")
		assert((note :: TextLabel).TextFits, "uigate: the accessory row's +15% line does not fit (#2147)")
		local options = (row :: Instance):FindFirstChild("Options") :: GuiObject
		assert((note :: TextLabel).AbsolutePosition.Y >= options.AbsolutePosition.Y + options.AbsoluteSize.Y - 1, "uigate: the +15% line is not under the buttons (#2147)")
		local uniform = tab:FindFirstChild("uniform")
		assert(uniform and uniform:FindFirstChild("Note") == nil, "uigate: the uniform row has a note (#2147)")
		UI.store.preview({}, {})
	end },
	-- #2007 (Derek2: "cafe sign cant change back to plain also put symbols beside each one"): every sign style with
	-- its symbol, Paw Chalkboard in use, then the sync for Plain ("" now, where nil left the old pick gold)
	{ "DecorStylePlain", function()
		UI.update({
			signStyles = {
				"bakery_stripes",
				"royal_crest",
				"frame_golden_leaf",
				"sign_maple_board",
				"pack_flower_box",
				"pack_starry_night",
				"pack_paw_chalkboard",
			},
			signStyle = "pack_paw_chalkboard",
		})
		UI.open("Decor")
		press("Decor", "Style")
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local row = modals and modals:FindFirstChild("sign", true)
		local title = row and row:FindFirstChild("Title")
		assert(title and title:IsA("TextLabel"), "uigate: no Cafe sign row on the Style tab")
		assert(title.Text == "Cafe sign: 🐾 Paw Chalkboard", "uigate: the sign row's title reads " .. title.Text)
		UI.update({ signStyle = "" })
		task.wait(0.05)
		assert(title.Text == "Cafe sign: ⬜ Plain", "uigate: Plain should be in use after the sync, title " .. title.Text)
	end },
	-- #1875: the Cafe music row (free for everyone) under the looks, Catnap Waltz in use; a tap asks for the song
	{ "DecorStyleMusic", function()
		UI.update({
			signStyles = { "bakery_stripes", "royal_crest" },
			signStyle = "royal_crest",
			looks = {
				uniform = "midnight",
				uniforms = { "default", "striped", "midnight", "mint", "uniform_pumpkin" },
				accessory = "hat",
				accessories = { "hat", "glasses", "acc_leaf_beret", "acc_tiny_lantern" },
				theme = "garden",
				themes = { "default", "garden", "grand" },
			},
			jukeboxTracks = {
				"jukebox_rainy_window",
				"jukebox_catnap_waltz",
				"jukebox_bakery_bounce",
				"jukebox_starlight_purr",
			},
			jukebox = "jukebox_catnap_waltz",
			jukeboxShuffle = "shuffle", -- #2077
		} :: any)
		UI.open("Decor")
		press("Decor", "Style")
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local row = modals and modals:FindFirstChild("music", true)
		assert(row, "uigate: no Cafe music row on the Style tab (#1168)")
		-- #2401: Shuffle is the row's first button, left of the mix on the same line
		local shuffleButton = row:FindFirstChild("shuffle", true) :: GuiObject
		local mixButton = row:FindFirstChild("Default", true) :: GuiObject
		assert(
			shuffleButton and mixButton and shuffleButton.AbsolutePosition.X < mixButton.AbsolutePosition.X,
			"uigate: Shuffle is not first in the music row (#2401)"
		)
		local asked: { string } = {}
		local connection = UI.events.pickStyle:Connect(function(kind: string, id: string)
			table.insert(asked, kind .. ":" .. id)
		end)
		press("Decor", "music.jukebox_starlight_purr")
		press("Decor", "music.shuffle")
		press("Decor", "music.Default")
		connection:Disconnect()
		assert(
			table.concat(asked, ",") == "music:jukebox_starlight_purr,music:shuffle,music:",
			"uigate: the music row asked " .. table.concat(asked, ",")
		)
	end },
	{ "Index", function()
		UI.open("Collection")
	end },
	-- #2493: the forever pills' fit runs deferred and settles: after a few frames its scale holds still, and the row
	-- stays inside the title bar
	{ "IndexPerksFit", function()
		UI.open("Collection")
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local row = modals and modals:FindFirstChild("Forever", true) :: Frame?
		assert(row, "uigate: no forever pills row in the Index (#2493)")
		local scale = row:FindFirstChildOfClass("UIScale") :: UIScale
		for _ = 1, 5 do
			UIShim.advance(1 / 60)
		end
		local settled = scale.Scale
		for _ = 1, 5 do
			UIShim.advance(1 / 60)
			assert(scale.Scale == settled, ("uigate: the forever pills' scale still moves (%.3f to %.3f, #2493)"):format(settled, scale.Scale))
		end
		local header = row.Parent :: GuiObject
		if row.Visible then
			assert(row.AbsolutePosition.X >= header.AbsolutePosition.X, "uigate: the forever pills run off the title bar (#2493)")
		end
	end },
	-- #1919: a missing Park cat at Tier 3 says to catch it there or wait for bait
	{ "IndexHintPark", function()
		local text = indexHint(missingCat("park"))
		assert(string.find(text, "Catch one in the Park, or it may come to your bait.", 1, true), "uigate: the Park hint reads " .. text)
	end },
	-- #1919: a missing Woods cat (Epic or up) at Tier 3 says the Woods opens at Tier 4, and to walk up slowly
	{ "IndexHintWoods", function()
		local text = indexHint(missingCat("woods", true))
		assert(string.find(text, "opens at Tier 4", 1, true), "uigate: the Woods hint reads " .. text)
		assert(string.find(text, "Shy: walk up slowly.", 1, true), "uigate: no shy line on an Epic or rarer: " .. text)
	end },
	{ "Cats", function()
		UI.open("Cats")
	end },
	-- #2294 (Derek2: "the border gets cut off at the bottom of cat menu"): scrolled to its end, the grid's last row
	-- keeps its whole outline (the gate's strokeclip check reads every card; this scene puts the last row in view)
	{ "CatsGridEnd", function()
		-- three times the sample player's cats, so the grid scrolls
		local before = UI.getState() :: any
		Scenes._crew = { cats = before.cats, tier = before.tier, extraSlots = before.extraSlots or 0 }
		local cats = {}
		for uid, cat in before.cats do
			cats[uid] = cat
			for copy = 1, 2 do
				local twin = table.clone(cat)
				twin.spotId = nil
				cats[uid .. "_twin" .. copy] = twin
			end
		end
		UI.update({ cats = cats } :: any)
		UI.open("Cats")
		task.wait(0.1)
		local container = UIShim.playerGui:FindFirstChild("CatCafeModals"):FindFirstChild("Container", true) :: Instance
		local window = container and container:FindFirstChild("Cats")
		local grid = window and window:FindFirstChild("Grid", true) :: ScrollingFrame
		assert(grid and grid:IsA("ScrollingFrame"), "uigate: no cat grid")
		-- the canvas's end against the last row's outline, measured before scrolling; then the grid scrolls to its end
		-- so the gate's strokeclip check reads the last row in view
		local canvasEnd = grid.AbsolutePosition.Y - grid.CanvasPosition.Y + grid.AbsoluteCanvasSize.Y
		local last = 0
		for _, card in grid:GetChildren() do
			if card:IsA("GuiObject") and card.Visible then
				local stroke = card:FindFirstChildWhichIsA("UIStroke")
				last = math.max(last, card.AbsolutePosition.Y + card.AbsoluteSize.Y + (if stroke then stroke.Thickness else 0))
			end
		end
		assert(last > 0 and last <= canvasEnd + 0.5, ("uigate: the last row's outline ends %.1f px past the cat grid's end (#2294)"):format(last - canvasEnd))
		grid.CanvasPosition = Vector2.new(0, math.max(0, grid.AbsoluteCanvasSize.Y - grid.AbsoluteWindowSize.Y))
	end },
	-- #1955 (auto-equip.md): the Auto Equip switch at the crew strip's right end, over Equip Best, gold while on; it
	-- shows once the server saves settings.autoEquip
	{ "CatsAutoEquip", function()
		local before = (UI.getState() :: any).settings
		local settings = table.clone(before or {})
		settings.autoEquip = true
		Scenes._settings = before -- Scenes.close puts the settings back
		UI.update({ settings = settings } :: any)
		UI.open("Cats")
		local SettingsList = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Components.SettingsList")
		if SettingsList.isKey(SettingsList.AUTO_EQUIP_KEY) then
			local switch = UIShim.playerGui:FindFirstChild("AutoEquip", true)
			assert(switch and switch.Visible, "uigate: no Auto Equip switch in the Cats window (#1955)")
			local function shows(): string
				for _, inst in (switch :: Instance):GetDescendants() do
					if (inst:IsA("TextLabel") or inst:IsA("TextButton")) and string.find(inst.Text, "Auto Equip", 1, true) then
						return inst.Text
					end
				end
				return (switch :: any).Text
			end
			assert(shows() == "Auto Equip: On", "uigate: the switch shows " .. shows() .. " with the setting on")
			-- #2076: a sync sent before the server applied the press keeps the old value; the switch keeps the press
			local function sync(on: boolean)
				local next = table.clone(settings)
				next.autoEquip = on
				UI.update({ settings = next } :: any)
			end
			press("Cats", "AutoEquip")
			assert(shows() == "Auto Equip: Off", "uigate: the switch shows " .. shows() .. " after pressing Off")
			sync(true) -- stale
			assert(shows() == "Auto Equip: Off", "uigate: a stale sync flashed the switch back On (#2076)")
			sync(false) -- the server caught up
			assert(shows() == "Auto Equip: Off", "uigate: the switch shows " .. shows() .. " once the server agrees")
			sync(true) -- a later change from elsewhere (Settings) shows at once
			assert(shows() == "Auto Equip: On", "uigate: the switch ignored a real change after the press settled")
		end
	end },
	-- #2047 (Derek2: "with the extra slots it doesn't show all the working cats on the top"): a Tier 5 cafe with Grand
	-- Cafe and the Extra Slot pass works all 12 slots, the two pass-only waiter slots too, and the crew strip shows 12
	{ "CatsExtraSlots", function()
		local Shared = UIShim.require("ReplicatedStorage.Shared.Catalog")
		local before = UI.getState() :: any
		Scenes._crew = { cats = before.cats, tier = before.tier, extraSlots = before.extraSlots or 0 }
		-- a Tier 5 cafe with two extra slots: the first `open` spots (#2675 adds the Tier 6/7 ones after them)
		local open = Shared.openSlotCount(5, 2)
		local cats = {}
		local index = 0
		for uid, cat in before.cats do
			index += 1
			local copy = table.clone(cat)
			local spot = if index <= open then Shared.allSpots[index] else nil
			copy.spotId = if spot then spot.id else nil
			cats[uid] = copy
		end
		assert(index >= open, "uigate: the sample player has too few cats to fill every open slot")
		UI.update({ cats = cats, tier = 5, extraSlots = 2 } :: any)
		UI.open("Cats")
		task.wait(0.1)
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local shown = 0
		for slot = 1, open do
			local spot = Shared.allSpots[slot]
			for _, square in modals:GetDescendants() do
				if square.Name == spot.id and square:IsA("GuiButton") and square.Visible then
					shown += 1
					break
				end
			end
		end
		assert(shown == open, ("uigate: the crew strip shows %d of %d working cats (#2047)"):format(shown, open))
		-- checked; put the sample player back and close, so the scene adds no findings of its own (the crew squares'
		-- tap size is the Cats scene's baseline, and the Tier 5 HUD has its own)
		UI.update(Scenes._crew :: any)
		Scenes._crew = nil
		UI.close()
	end },
	{ "CatsPicked", function()
		UI.open("Cats")
		-- the cards build on the next frame; the gold cat, level 13, at work: favourite or Likes, Gold and level chips
		task.delay(0.2, function()
			press("Cats", "gate_3")
		end)
	end },
	-- #2418 (Derek2: "make the feeding cats from cat menu much easier and more clean looking then long blue bubbles and
	-- text"): the picked cat's food tiles under its chips, one per food, inside the card; a tap feeds that food to
	-- this cat; a cat at the top level and a Bag with no food each say so in the row instead
	{ "CatsFeed", function()
		local before: any = UI.getState()
		Scenes._feedBefore = { catFood = before.catFood, cats = before.cats }
		UI.update({ catFood = { small_cat_snack = 2, cat_snack = 3, big_cat_snack = 1 } } :: any)
		UI.open("Cats")
		task.wait(0.2)
		press("Cats", "gate_3")
		task.wait(0.1)
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local row = modals:FindFirstChild("FeedRow", true) :: Frame
		assert(row and row.Visible, "uigate: no food tiles on the picked cat's card (#2418)")
		local card = (row.Parent :: GuiObject)
		local c0, c1 = card.AbsolutePosition, card.AbsolutePosition + card.AbsoluteSize
		local tiles = 0
		for _, id in { "small_cat_snack", "cat_snack", "big_cat_snack" } do
			local tile = row:FindFirstChild(id) :: GuiObject
			assert(tile and tile.Visible, "uigate: no " .. id .. " tile (#2418)")
			local t0, t1 = tile.AbsolutePosition, tile.AbsolutePosition + tile.AbsoluteSize
			assert(t0.X >= c0.X and t1.X <= c1.X and t0.Y >= c0.Y and t1.Y <= c1.Y, "uigate: the " .. id .. " tile leaves the card (#2418)")
			tiles += 1
		end
		assert(tiles == 3, "uigate: food tiles " .. tiles)
		local count = row:FindFirstChild("cat_snack"):FindFirstChild("Count") :: TextLabel
		assert(count.Text == "x3", "uigate: the cat_snack tile counts " .. count.Text .. " (#2418)")
		local fed: { string } = {}
		local listening = UI.events.feedCat:Connect(function(foodId: string, uid: string)
			table.insert(fed, foodId .. "@" .. uid)
		end)
		press("Cats", "FeedRow.cat_snack")
		listening:Disconnect()
		assert(table.concat(fed, ",") == "cat_snack@gate_3", "uigate: the tile fed " .. table.concat(fed, ",") .. " (#2418)")
		-- no food in the Bag: one line where to get it
		UI.update({ catFood = {} } :: any)
		task.wait(0.1)
		local note = row:FindFirstChild("FeedNote") :: TextLabel
		assert(row.Visible and note.Visible and note.Text:find("Corner Shop", 1, true), "uigate: no food line with an empty Bag (#2418)")
		assert(row:FindFirstChild("cat_snack") == nil, "uigate: a food tile stays with an empty Bag (#2418)")
		UI.update({ catFood = { small_cat_snack = 2, cat_snack = 3, big_cat_snack = 1 } } :: any)
		task.wait(0.1)
	end },
	{ "RankUp", function()
		UI.open("RankUp")
	end },
	{ "RankUpTier2", function()
		-- #2121: the Tier 1 card lists all five upgrade caps now Bait Bowl 3 opens at Tier 2; the line still fits
		Scenes._rankTier = (UI.getState() :: any).tier -- Scenes.close puts the sample tier back
		UI.update({ tier = 1 } :: any)
		UI.open("RankUp")
		local found = false
		for _, inst in UIShim.playerGui:GetDescendants() do
			if inst:IsA("TextLabel") and string.find(inst.Text, "bait bowl to 3", 1, true) then
				found = true
				assert(inst.TextFits ~= false, "uigate: the Tier 2 upgrade line does not fit (#2121)")
			end
		end
		assert(found, "uigate: the Tier 2 card does not say bait bowl to 3 (#2121)")
	end },
	{ "MoodIcons", function()
		-- Catch v3 (catch-rework.md 7a): a mood icon over each stray with a Mood, Skittish with its arc; hidden
		-- while caught (LockedBy), gone with the Mood
		local function stray(id: string, mood: string?, x: number): Model
			local model = Instance.new("Model")
			model.Name = "Stray_" .. id
			local body = Instance.new("Part")
			body.Name = "Body"
			body.Size = Vector3.new(2, 2, 3)
			body.Position = Vector3.new(x, 3, -12)
			body.Parent = model
			model.PrimaryPart = body
			model:SetAttribute("StrayId", id)
			if mood then
				model:SetAttribute("Mood", mood)
			end
			model.Parent = workspace
			model:AddTag("Stray")
			return model
		end
		local sleepy = stray("mood_1", "Sleepy", -4)
		local skittish = stray("mood_2", "Skittish", 0)
		local plain = stray("mood_3", nil, 4)
		-- the shim's tag signals never fire, so start the icons again to pick the three up
		UI.catch.moods:destroy()
		UI.catch.moods = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Screens.MoodIcons").new()
		local function iconOf(model: Model): BillboardGui?
			return (model.PrimaryPart :: BasePart):FindFirstChild("CatCafeMoodIcon") :: BillboardGui?
		end
		local a, b = iconOf(sleepy), iconOf(skittish)
		assert(a and b, "uigate: no mood icon over a stray with a Mood")
		assert(iconOf(plain) == nil, "uigate: a mood icon over a stray with no Mood")
		assert((a :: any).Icon.Glyph.Text == "zZ", "uigate: Sleepy should show zZ")
		assert((b :: any).Icon.Glyph.Text == "!", "uigate: Skittish should show !")
		assert((a :: any).Arc.Visible == false and (b :: any).Arc.Visible == true, "uigate: only Skittish shows the arc")
		assert((b :: BillboardGui).MaxDistance == 20, "uigate: the icon shows within MoodIconStuds (20)")
		plain:SetAttribute("Mood", "Curious")
		local c = iconOf(plain)
		assert(c and (c :: any).Icon.Glyph.Text == "?", "uigate: a Mood set later should show its icon")
		skittish:SetAttribute("LockedBy", 1)
		assert((b :: BillboardGui).Enabled == false, "uigate: the icon should hide while the cat is caught")
		skittish:SetAttribute("LockedBy", 0)
		assert((b :: BillboardGui).Enabled == true, "uigate: the icon should come back after the catch")
		sleepy:SetAttribute("Mood", nil)
		assert(iconOf(sleepy) == nil, "uigate: the icon should go with the Mood")
		for _, model in { sleepy, skittish, plain } do
			model:Destroy()
		end
	end },
	-- #2110 (Derek2: the real name with its coat, not "Stray"): the longest cat name on its rainbow coat fits the
	-- catch header on every screen
	{ "CatchRainbowName", function()
		startCatchV3("gate_name", "Mythical", { "single", "single", "single" }, 2, 10, {
			strayId = "gate_name",
			catId = Catalog.cats[2].id,
			catName = "Duchess Marzipan",
			rarity = "Mythical",
			rainbow = true,
		})
		local layer = UIShim.playerGui:FindFirstChild("CatCafeCatchCircles")
		local name = layer and layer:FindFirstChild("CatName", true)
		assert(name and name:IsA("TextLabel"), "uigate: no catch header name (#2110)")
		assert(name.Text == "Rainbow Duchess Marzipan", "uigate: the catch header reads " .. name.Text .. " (#2110)")
		assert(name.TextFits, "uigate: Rainbow Duchess Marzipan does not fit the catch header (#2110)")
	end },
	-- #2099 (luck-and-rare-moments.md 1j): a "Pity cat" tag over each stray with PityCat, gold for a Legendary and
	-- violet with a rainbow edge for a Mythical, none over a plain stray; hidden in a net, back on a bolt, gone with
	-- the attribute
	{ "PityTags", function()
		local function stray(id: string, pity: string?, x: number): Model
			local model = Instance.new("Model")
			model.Name = "Stray_" .. id
			local body = Instance.new("Part")
			body.Name = "Body"
			body.Size = Vector3.new(2, 2, 3)
			body.Position = Vector3.new(x, 3, -12)
			body.Parent = model
			model.PrimaryPart = body
			model:SetAttribute("StrayId", id)
			if pity then
				model:SetAttribute("PityCat", pity)
			end
			model.Parent = workspace
			model:AddTag("Stray")
			return model
		end
		local legendary = stray("pity_1", "Legendary", -4)
		local mythical = stray("pity_2", "Mythical", 0)
		local plain = stray("pity_3", nil, 4)
		-- the shim's tag signals never fire, so start the tags again to pick the three up
		UI.catch.pity:destroy()
		UI.catch.pity = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Screens.PityTags").new()
		local function tagOf(model: Model): BillboardGui?
			return (model.PrimaryPart :: BasePart):FindFirstChild("CatCafePityTag") :: BillboardGui?
		end
		local a, b = tagOf(legendary), tagOf(mythical)
		assert(a and b, "uigate: no Pity cat tag over a pity stray (#2099)")
		assert(tagOf(plain) == nil, "uigate: a Pity cat tag over a plain stray (#2099)")
		local tagA, tagB = (a :: any).Tag, (b :: any).Tag
		assert(tagA.Label.Text == "Pity cat" and tagB.Label.Text == "Pity cat", "uigate: the tag reads Pity cat (#2099)")
		assert((a :: BillboardGui).Enabled and (b :: BillboardGui).Enabled, "uigate: the Pity cat tags are up (#2099)")
		assert((a :: BillboardGui).AlwaysOnTop and (a :: BillboardGui).MaxDistance == 150, "uigate: seen over walls within 150 studs (#2099)")
		local edgeA = tagA:FindFirstChildOfClass("UIStroke"):FindFirstChildOfClass("UIGradient")
		local edgeB = tagB:FindFirstChildOfClass("UIStroke"):FindFirstChildOfClass("UIGradient")
		assert(not edgeA.Enabled and edgeB.Enabled, "uigate: only the Mythical tag has the rainbow edge (#2099)")
		assert(tagA.BackgroundColor3 ~= tagB.BackgroundColor3, "uigate: Legendary gold and Mythical violet differ (#2099)")
		legendary:SetAttribute("LockedBy", 1)
		assert(not (a :: BillboardGui).Enabled, "uigate: the tag should hide while a net holds the cat (#2099)")
		legendary:SetAttribute("LockedBy", 0)
		assert((a :: BillboardGui).Enabled, "uigate: the tag should come back when the cat bolts (#2099)")
		plain:SetAttribute("PityCat", "Legendary")
		assert(tagOf(plain), "uigate: PityCat set later should bring the tag (#2099)")
		mythical:SetAttribute("PityCat", nil)
		assert(tagOf(mythical) == nil, "uigate: the tag should go with the PityCat attribute (#2099)")
		-- Laptop-Tester, Studio 11-07: a pity cat streamed in as its model before its parts (it spawns at a far hiding
		-- spot) had no tag; the tag now comes with the first part, and again with the new part after a stream out
		local far = Instance.new("Model")
		far.Name = "Stray_pity_far"
		far:SetAttribute("StrayId", "pity_far")
		far:SetAttribute("PityCat", "Legendary")
		far.Parent = workspace
		far:AddTag("Stray")
		UI.catch.pity:_watch(far)
		local function arrive(): Part
			local body = Instance.new("Part")
			body.Name = "Body"
			body.Size = Vector3.new(2, 2, 3)
			body.Position = Vector3.new(8, 3, -12)
			body.Parent = far
			far.PrimaryPart = body
			UIShim.fire(UIShim.eventOf(far, "DescendantAdded"), body)
			UIShim.advance(1 / 60) -- the deferred refresh
			return body
		end
		local first = arrive()
		assert(first:FindFirstChild("CatCafePityTag"), "uigate: no Pity cat tag once a streamed pity cat's parts arrive (#2099)")
		UIShim.fire(UIShim.eventOf(far, "DescendantRemoving"), first)
		first.Parent = nil
		UIShim.advance(1 / 60)
		local again = arrive()
		assert(again:FindFirstChild("CatCafePityTag"), "uigate: no Pity cat tag after the cat streamed back in (#2099)")
		for _, model in { legendary, mythical, plain, far } do
			model:Destroy()
		end
	end },
	-- #2005 section 1 (Derek2: "with an exclamation mark to show its being caught"): a gold ! over a stray while its
	-- NetDown is set, just above the catcher's trust bar; another stray without it has none, and it goes with NetDown
	{ "CatchMark", function()
		local _, model = startCatchV3("gate_mark", "Rare", { "single", "single", "single", "single" }, 4, 14)
		model:SetAttribute("NetDown", true)
		local other = Instance.new("Model")
		other.Name = "Stray_gate_mark_free"
		local body = Instance.new("Part")
		body.Name = "Body"
		body.Size = Vector3.new(2, 2, 3)
		body.Position = Vector3.new(5, 3, -12)
		body.Parent = other
		other.PrimaryPart = body
		other.Parent = workspace
		other:AddTag("Stray")
		-- the shim's tag signals never fire, so start the marks again to pick the strays up
		UI.catch.mark:destroy()
		UI.catch.mark = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Screens.CatchMark").new()
		local function markOf(stray: Model): BillboardGui?
			return (stray.PrimaryPart :: BasePart):FindFirstChild("CatCafeCatchMark") :: BillboardGui?
		end
		local mark = markOf(model)
		assert(mark, "uigate: no ! over a stray being caught (#2005)")
		assert((mark :: any).Badge.Glyph.Text == "!", "uigate: the catch mark should read !")
		assert(markOf(other) == nil, "uigate: a ! over a stray nobody is catching (#2005)")
		other:SetAttribute("NetDown", true)
		assert(markOf(other), "uigate: a NetDown set later should show its ! (#2005)")
		other:SetAttribute("NetDown", nil)
		assert(markOf(other) == nil, "uigate: the ! should go when the catch ends (#2005)")
		-- #2469: the tackle lesson's staged cat (TackleStage.STRAY_TAG) with its NetDown gets the same !
		other:RemoveTag("Stray")
		other:AddTag("StagedStray")
		other:SetAttribute("NetDown", true)
		UI.catch.mark:destroy()
		UI.catch.mark = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Screens.CatchMark").new()
		assert(markOf(other), "uigate: no ! over the tackle lesson's pinned cat (#2469)")
		other:Destroy()
	end },
	-- #2015: no glyph in the Theme's icon tables is an emoji from Unicode 12 on, which Roblox's font draws blank (the
	-- Decor tile showed nothing when its pictures failed); tests/specs/GlyphFont checks the Store and Style glyphs
	{ "GlyphsDrawable", function()
		local Theme = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Theme")
		local NEW = { { 0x1FA00, 0x1FAFF }, { 0x1F7E0, 0x1F7EB }, { 0x1F6D5, 0x1F6DF }, { 0x1F6FA, 0x1F6FF }, { 0x1F90C, 0x1F90F }, { 0x1F93F, 0x1F93F }, { 0x1F971, 0x1F979 }, { 0x1F97B, 0x1F97B }, { 0x1F9A3, 0x1F9AF }, { 0x1F9BA, 0x1F9BF }, { 0x1F9C3, 0x1F9CF } }
		for _, name in { "icons", "upgradeIcons", "roleIcons", "foodIcons" } do
			for key, glyph in Theme[name] do
				if type(glyph) == "string" then
					for _, code in utf8.codes(glyph) do
						for _, range in NEW do
							assert(code < range[1] or code > range[2], ("uigate: Theme.%s.%s is %s, drawn blank (#2015)"):format(name, tostring(key), glyph))
						end
					end
				end
			end
		end
		assert(Theme.icons.decor == "🌿", "uigate: the Decor tile's fallback should be 🌿 (#2015)")
	end },
	{ "Cannon", function()
		UI.cannon.open()
	end },
	{ "Bait", function()
		UI.bait.openPicker()
		-- #1281: no Buy on any food; each says how many you have, or where to get more
		local window = baitWindow()
		local counts = 0
		for _, piece in window:GetDescendants() do
			assert(piece.Name ~= "Buy", "uigate: a Buy button in the bowl menu (#1281: foods sell at the Corner Shop)")
			if piece.Name == "Count" and piece:IsA("TextLabel") then
				counts += 1
				local text = piece.Text
				assert(
					string.match(text, "^You have %d+$")
						or text == "Get more at the Corner Shop"
						or text == "Sold by the night dealer's cart",
					("uigate: a food row says %q (#1281)"):format(text)
				)
			end
		end
		assert(counts == #Catalog.lures, ("uigate: %d food rows for %d foods"):format(counts, #Catalog.lures))
	end },
	-- #1612 / #1609: compact food rows, rarest first, no "Attracts" chip and no odds on the row; Details on the Star
	-- Treat opens its odds with the gold line and the split under them
	{ "BaitDetails", function()
		UI.bait.openPicker()
		local window = baitWindow()
		assert(window:FindFirstChild("Attracts", true) == nil, "uigate: an Attracts chip is back on a food row (#1612)")
		assert(window:FindFirstChild("Odds", true) == nil, "uigate: an odds line is back on a food row (#1612)")
		local star = window:FindFirstChild("star_treat", true)
		local moon = window:FindFirstChild("moon_milk", true)
		assert(star and moon, "uigate: no Star Treat or Moon Milk row")
		-- neither is in the bag here, so they keep the rarest first order behind the foods the player has (#2323)
		assert(star.LayoutOrder < moon.LayoutOrder, "uigate: the bowl lists Moon Milk before the Star Treat (#1609)")
		press("Bait", "star_treat.Details")
		local detail = star:FindFirstChild("Detail", true) :: TextLabel
		assert(detail and detail.Visible, "uigate: Details did not open")
		assert(string.find(detail.Text, "Mythical", 1, true), "uigate: the Details text has no odds: " .. detail.Text)
	end },
	-- #2323: a tutorial player with Kibble alone sees it at the top, not under six foods they don't have; once Salmon
	-- is in the bag it leads, then Kibble, then the rest rarest first
	{ "BaitOwnedFirst", function()
		local before: any = UI.getState()
		UI.update({ lures = { kibble = 3 } })
		UI.bait.openPicker()
		local window = baitWindow()
		local function order(): string
			local rows = {}
			for _, lure in Catalog.lures do
				local row = window:FindFirstChild(lure.id, true)
				assert(row and row:IsA("GuiObject"), "uigate: no row for " .. lure.id)
				table.insert(rows, row)
			end
			table.sort(rows, function(a, b)
				return a.LayoutOrder < b.LayoutOrder
			end)
			local names = {}
			for _, row in rows do
				table.insert(names, row.Name)
			end
			return table.concat(names, ",")
		end
		local shown = order()
		assert(
			shown == "kibble,star_treat,moon_milk,caviar,salmon,sardines,tuna",
			"uigate: the bowl with only Kibble lists " .. shown .. " (#2323)"
		)
		UI.update({ lures = { kibble = 3, salmon = 1 } })
		shown = order()
		assert(
			shown == "salmon,kibble,star_treat,moon_milk,caviar,sardines,tuna",
			"uigate: the bowl with Kibble and Salmon lists " .. shown .. " (#2323)"
		)
		UI.update({ lures = before.lures }) -- later Bait scenes keep their own bag (BaitRefill needs its Tuna)
	end },
	-- #1161: the Second Bait Bowl pass owned, bowl 1 filling and bowl 2 empty: two tabs, and the screen opens on
	-- bowl 2 (the empty one that takes food) with its Use buttons live
	{ "BaitTwoBowls", function()
		local now = workspace:GetServerTimeNow()
		UI.bait.setSecond("on")
		UI.bait.set({ lureId = Catalog.lures[1].id, readyAt = now + 250, placedAt = now - 50 }, 1)
		UI.bait.openPicker()
		assertBowlTabs(2, "Bowl 2 is empty")
	end },
	-- #1897: the account's first wow cat is on its way, and the bowl says so honestly
	{ "BaitWow", function()
		local now = workspace:GetServerTimeNow()
		UI.bait.set({ lureId = Catalog.lures[1].id, readyAt = now + 250, placedAt = now - 50, wow = true }, 1)
		UI.bait.openPicker()
		local window = baitWindow()
		local title = window:FindFirstChild("Status", true):FindFirstChild("Title").Text
		assert(title == "Your next cat will be Rare or better!", "uigate: the wow bowl reads " .. title)
	end },
	-- #1893 (first-hour.md 1b): the Grand Opening strip under the goal card at 3/8, tapped open into its eight steps
	-- (the next one highlighted), then milestone 4's toast and dot
	{ "GrandOpening", function()
		UI.update({ tutorialStep = 9, grandOpening = { done = { [1] = true, [2] = true, [3] = true } } })
		local strip = UIShim.playerGui:FindFirstChild("GrandOpening", true)
		assert(strip and strip.Visible, "uigate: no Grand Opening strip after the tutorial (#1893)")
		local title = strip:FindFirstChild("Title")
		assert(title and title.Text == "Grand Opening 3/8", "uigate: the strip reads " .. tostring(title and title.Text))
		UIShim.fire(UIShim.eventOf(strip, "Activated"))
		local steps = strip:FindFirstChild("Steps")
		assert(steps and steps.Visible, "uigate: a tap didn't open the Grand Opening steps (#1893)")
		UI.roadmap.step(4)
	end },
	-- #1920 (first-hour.md 6): the session recap card at a calm moment: today, the Grand Opening's next step, a cooking
	-- bait cat and the offline share with tomorrow, and an X; no countdown and no store link
	{ "SessionRecap", function()
		local now = workspace:GetServerTimeNow()
		UI.update({ tutorialStep = 9, grandOpening = { done = { [1] = true, [2] = true, [3] = true } } })
		UI.bait.set({ lureId = Catalog.lures[1].id, readyAt = now + 170, placedAt = now - 50 }, 1)
		UI.recap.shown = false
		UI.recap.lastInput = os.clock() - 30 -- idle
		UI.recap.show({ minutes = 41, newCats = 3, earned = 12500 })
		local gui = UIShim.playerGui:FindFirstChild("CatCafeRecap")
		local card = gui and gui:FindFirstChild("Card", true)
		assert(card and card.Visible, "uigate: no session recap card when idle (#1920)")
		local first = card:FindFirstChild("Line1", true)
		assert(first and first.Text == "Today: 3 new cats, $12K earned", "uigate: the recap's first line reads " .. tostring(first and first.Text))
		local second = card:FindFirstChild("Line2", true)
		assert(second and string.find(second.Text, "Grand Opening 3/8", 1, true), "uigate: the recap's next line reads " .. tostring(second and second.Text))
		assert(card:FindFirstChild("Line3", true).Text == "Your bait cat arrives in 3 min. It waits for you", "uigate: the recap's bait line reads " .. card:FindFirstChild("Line3", true).Text)
		assert(card:FindFirstChild("Line4", true).Visible, "uigate: no offline line on the recap")
		UI.recap.show({ minutes = 80, newCats = 1, earned = 1 })
		assert(first.Text == "Today: 3 new cats, $12K earned", "uigate: the recap showed twice in a session (#1920)")
	end },
	-- #2123 (first-hour.md 6a): with Gameplay's ReturnHook pick the offline share has its own line and one Tomorrow
	-- line closes the card (a treat with its prize, the longest), in place of the cooking bait line
	{ "SessionRecapTomorrow", function()
		local now = workspace:GetServerTimeNow()
		UI.update({ tutorialStep = 9, grandOpening = { done = { [1] = true, [2] = true, [3] = true } } })
		UI.bait.set({ lureId = Catalog.lures[1].id, readyAt = now + 170, placedAt = now - 50 }, 1)
		UI.recap.shown = false
		UI.recap.lastInput = os.clock() - 30 -- idle
		UI.recap.show({ minutes = 16, newCats = 3, earned = 12500, tomorrow = { kind = "treat", day = 7 } } :: any)
		local gui = UIShim.playerGui:FindFirstChild("CatCafeRecap")
		local card = gui and gui:FindFirstChild("Card", true) :: Frame?
		assert(card and card.Visible, "uigate: no session recap card when idle (#2123)")
		local three = card:FindFirstChild("Line3", true) :: TextLabel
		local four = card:FindFirstChild("Line4", true) :: TextLabel
		assert(three.Text == "Your cats keep earning while you're away: 50% pay, up to 8\u{00A0}h", "uigate: the recap's offline line reads " .. three.Text .. " (#2123)")
		local RecapLogic = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Components.RecapLogic")
		local want = "Tomorrow: Daily Treat day 7, " .. RecapLogic.treatWords(7)
		assert(four.Visible and four.Text == want, "uigate: the recap's Tomorrow line reads " .. four.Text .. " (#2123)")
		assert(four.TextFits and three.TextFits, "uigate: the offline or Tomorrow line does not fit (#2123)")
		local bottom = four.AbsolutePosition.Y + four.AbsoluteSize.Y
		assert(bottom <= card.AbsolutePosition.Y + card.AbsoluteSize.Y + 1, "uigate: the Tomorrow line hangs off the recap card (#2123)")
		-- #2235 (Derek2: "the text from cafe so far is hard to read", "make it obvious that cats earn offline"): the
		-- offline line is a mint callout in bold, and no blank row sits between it and the next line
		assert((three.Parent :: Frame).BackgroundTransparency == 0 and (four.Parent :: Frame).BackgroundTransparency == 1, "uigate: the offline line is not the recap's callout (#2235)")
		assert(three.TextSize >= 17 and four.TextSize >= 17, "uigate: the recap's lines are " .. four.TextSize .. " px (#2235)")
		-- #2295 (desktop test of #2243: "...100% pay, up to" with "16 h" cut off): the callout's words sit inside its padded
		-- row, and the row is as tall as all of their wrapped rows
		local row = three.Parent :: Frame
		local rowBottom = row.AbsolutePosition.Y + row.AbsoluteSize.Y
		assert(row.Name == "Row3" and three.AbsolutePosition.Y > row.AbsolutePosition.Y, "uigate: the offline callout's words are not inside its padded row")
		assert(three.AbsolutePosition.Y + three.TextBounds.Y < rowBottom, "uigate: the offline callout is shorter than its words")
		local space = (four.Parent :: Frame).AbsolutePosition.Y - rowBottom
		assert(space <= 10, "uigate: a gap of " .. space .. " px under the offline line (#2235)")
		local cardBottom = card.AbsolutePosition.Y + card.AbsoluteSize.Y
		assert(cardBottom - bottom <= 24, "uigate: " .. (cardBottom - bottom) .. " px of empty card under the last line (#2235)")
	end },
	-- #1947 (like-prompts.md section 2): the like and favourite gift cards, paid before they show, with "Gift added!",
	-- the coins Payout paid and the potions, and the first button and Close the same size
	{ "GiftCardLike", function()
		UI.recap.lastInput = os.clock() - 30 -- idle
		UI.gift.show("like", { "+$12500", "1 Tip Potion" })
		local card = UIShim.playerGui:FindFirstChild("CatCafeGift"):FindFirstChild("Card", true)
		assert(card.Visible, "uigate: no like gift card when idle (#1947)")
		local action = card:FindFirstChild("Action", true)
		local close = card:FindFirstChild("Close", true)
		-- #2705: on touch the like card has Got it alone, the row's width, and says to tap 👍 next time
		if UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Scale").isTouch() then
			assert(action.Visible and not close.Visible, "uigate: the like card on touch is not Got it alone (#2705)")
			local label = action:FindFirstChildWhichIsA("TextLabel", true) :: TextLabel
			assert(label and label.Text == "Got it", "uigate: the like card's button reads " .. tostring(label and label.Text) .. " on touch (#2705)")
		else
			assert(action.Visible and action.Size == close.Size, "uigate: the gift card's Close is not the same size as its ask (#1947)")
		end
	end },
	{ "GiftCardFav", function()
		UI.recap.lastInput = os.clock() - 30
		UI.gift.show("fav", { "+$25000", "1 Tip Potion", "1 Lucky Potion", "1 Swift Potion" })
		local card = UIShim.playerGui:FindFirstChild("CatCafeGift"):FindFirstChild("Card", true)
		assert(card.Visible, "uigate: no favourite gift card when idle (#1947)")
	end },
	-- How to like pressed: the thumbs-up hint and Close alone; the press is reported once
	{ "GiftCardLiked", function()
		local reports = {}
		local watch = UI.events.playtimeGift:Connect(function(what)
			table.insert(reports, what)
		end)
		UI.recap.lastInput = os.clock() - 30
		UI.gift.show("like", { "+$12500", "1 Tip Potion" })
		press("CatCafeGift", "Action")
		watch:Disconnect()
		local card = UIShim.playerGui:FindFirstChild("CatCafeGift"):FindFirstChild("Card", true)
		if UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Scale").isTouch() then
			-- #2705: Got it reports like:gotit and closes the card
			assert(#reports == 1 and reports[1] == "like:gotit", "uigate: Got it reported " .. table.concat(reports, ", ") .. " (#2705)")
			assert(not card.Visible, "uigate: the like card stays after Got it (#2705)")
			return
		end
		assert(#reports == 1 and reports[1] == "like:like", "uigate: Like the game reported " .. table.concat(reports, ", ") .. " (#1947)")
		assert(card.Visible and not card:FindFirstChild("Action", true).Visible, "uigate: the like card did not thank after Like (#1947)")
	end },
	-- #1919 (first-hour.md 5): while step 7 (twelve cats) is next, the goal card reads "Find N more cats" with the
	-- Index icon; a tap opens the Index on an open area's page and reports index_hint_tap with it
	{ "IndexNudge", function()
		local few = {}
		for index, def in Catalog.cats do
			if index <= 6 and def.exclusive ~= true then
				few[def.id] = os.time() - index * 60
			end
		end
		Scenes._fewCats = true -- Scenes.close puts the sample collection back
		UI.update({ tutorialStep = 9, collection = few, grandOpening = { done = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true } } })
		local goal = UIShim.playerGui:FindFirstChild("TierGoal", true)
		local title = goal and goal:FindFirstChild("Title")
		assert(title and string.match(title.Text, "^Find %d+ more cats?$"), "uigate: the goal card reads " .. tostring(title and title.Text) .. " (#1919)")
		assert(goal:FindFirstChild("IndexIcon").Visible, "uigate: no Index icon on the nudge (#1919)")
	end },
	{ "IndexNudgeTap", function()
		local few = {}
		for index, def in Catalog.cats do
			if index <= 6 and def.exclusive ~= true then
				few[def.id] = os.time() - index * 60
			end
		end
		Scenes._fewCats = true
		UI.update({ tutorialStep = 9, collection = few, grandOpening = { done = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true } } })
		local tapped = nil
		local connection = UI.events.indexHintTap:Connect(function(areaId)
			tapped = areaId
		end)
		UIShim.fire(UIShim.eventOf(UIShim.playerGui:FindFirstChild("TierGoal", true), "Activated"))
		connection:Disconnect()
		assert(UI.isOpen() == "Collection", "uigate: the nudge opened " .. tostring(UI.isOpen()) .. ", not the Index (#1919)")
		local open = false
		for _, area in Catalog.areas do
			if area.id == tapped and area.tier <= 3 then
				open = true
			end
		end
		assert(open, "uigate: index_hint_tap named " .. tostring(tapped) .. ", not an open area (#1919)")
	end },
	-- #1893: step 8's Grand Opening banner
	{ "GrandOpeningDone", function()
		UI.update({ tutorialStep = 9, grandOpening = { done = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true } } })
		UI.roadmap.step(8)
	end },
	-- #1895: the account's short first bait (2 minutes) in the bowl: "A cat is coming!" on the HUD's row over the money
	-- and in the Bait bowl window
	{ "BaitFirstComing", function()
		local now = workspace:GetServerTimeNow()
		UI.bait.set({ lureId = Catalog.lures[1].id, readyAt = now + 102, placedAt = now - 18 }, 1)
		local chip = UIShim.playerGui:FindFirstChild("CatComing", true)
		if UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Scale").isTouch() then
			-- #2447: never on touch, where the counters' row is up in the top bar
			assert(chip and not chip.Visible, "uigate: \"A cat is coming!\" shows on touch (#2447)")
		else
			assert(chip and chip.Visible and string.find(chip.Text, "A cat is coming!", 1, true),
				"uigate: no \"A cat is coming!\" over the money during the first bait (#1895)")
		end
		UI.bait.openPicker()
		local status = baitWindow():FindFirstChild("Status", true)
		local sub = status and status:FindFirstChild("Sub", true)
		assert(sub and string.find(sub.Text, "A cat is coming!", 1, true),
			"uigate: the bowl window doesn't say a cat is coming (#1895)")
	end },
	-- #1573: a Tuna bait that has come and gone; the empty bowl offers Refill with the same food
	{ "BaitRefill", function()
		local now = workspace:GetServerTimeNow()
		local tuna = Catalog.lures[2]
		UI.bait.set({ lureId = tuna.id, readyAt = now - 5, placedAt = now - 600 }, 1)
		UI.bait.set(nil, 1)
		UI.bait.openPicker()
		local status = baitWindow():FindFirstChild("Status", true)
		local action = status and status:FindFirstChild("Action", true)
		assert(action and action.Visible, "uigate: no Refill on the empty bowl (#1573)")
		local sub = status:FindFirstChild("Sub", true)
		-- #1693: the line is just the wait now; Refill puts the same food back in
		assert(
			sub and string.find(sub.Text, "A cat comes by in", 1, true),
			"uigate: the empty bowl's line is not the wait (#1693)"
		)
	end },
	-- #1161: both bowls filling, bowl 2 at night: the tabs count down on their own
	{ "BaitBothRunning", function()
		local now = workspace:GetServerTimeNow()
		UI.bait.setSecond("on")
		UI.bait.set({ lureId = Catalog.lures[1].id, readyAt = now + 250, placedAt = now - 50 }, 1)
		UI.bait.set({ lureId = Catalog.lures[2].id, readyAt = now + 95, placedAt = now - 30, night = true }, 2)
		UI.bait.openPicker()
		assertBowlTabs(1, "is in bowl 1")
	end },
	-- #1161: bowl 1 filling and a cat at bowl 2: the window opens on bowl 2 with See the cat, and the HUD's bowl tile
	-- shows the "!" for it and the "2"
	{ "BaitOneReady", function()
		local now = workspace:GetServerTimeNow()
		UI.bait.setSecond("on")
		UI.bait.set({ lureId = Catalog.lures[1].id, readyAt = now + 250, placedAt = now - 50 }, 1)
		UI.bait.set({ lureId = Catalog.lures[2].id, readyAt = now - 5, placedAt = now - 300 }, 2)
		UI.bait.showReady({ catId = Catalog.cats[2].id, stars = 2 }, 2)
		local banner = UIShim.playerGui:FindFirstChild("CatCafeBaitCard"):FindFirstChild("Banner", true)
		assert(banner.Text == "A CAT CAME TO BOWL 2!", "uigate: the cat's card says " .. banner.Text .. " (#1161)")
		-- #2137: the card's dim covers the whole screen, the top bar's strip too
		local dim = UIShim.playerGui:FindFirstChild("CatCafeBaitCardDim")
		local backdrop = dim and dim:FindFirstChild("Backdrop") :: GuiObject?
		assert(dim and (dim :: ScreenGui).Enabled and backdrop, "uigate: no dim behind the bait card (#2137)")
		local screenY = workspace.CurrentCamera.ViewportSize.Y
		assert((backdrop :: GuiObject).AbsolutePosition.Y <= 0 and (backdrop :: GuiObject).AbsoluteSize.Y >= screenY - 1, "uigate: the bait card's dim stops short of the top (#2137)")
		press("CatCafeBaitCard", "Close") -- the X; See the cat brings it back
		UIShim.advance(1) -- the card pops out first
		assert(not (dim :: ScreenGui).Enabled, "uigate: the bait card's dim stays after the card closed (#2137)")
		assertBowlTile(true)
		UI.bait.openPicker()
		assertBowlTabs(2, "A cat is at bowl 2!")
		assertBowlAction("See the cat")
		press("Bait", "Bowls.Bowl1")
		assertBowlTabs(1, "is in bowl 1")
	end },
	-- #2014 (Derek2: "food bowl cats wait until not mid catch to pop up on screen"): a cat comes to bowl 2 during a
	-- catch; the card holds (the bowl tile shows the !) until the circles end, then shows a moment after
	{ "BaitWaitsForCatch", function()
		local now = workspace:GetServerTimeNow()
		UI.bait.setSecond("on")
		UI.bait.set({ lureId = Catalog.lures[2].id, readyAt = now - 1, placedAt = now - 300 }, 2)
		startCatch("gate_bait_wait", "Common", 4, 0.3, 1.5)
		assert(UI.catch.circlesActive(), "uigate: the catch circles should be running")
		UI.bait.arrived({ catId = Catalog.cats[2].id, stars = 2 }, 2)
		local gui = UIShim.playerGui:FindFirstChild("CatCafeBaitCard")
		task.wait(0.5)
		assert(gui and not gui.Enabled, "uigate: the bait card popped up mid catch (#2014)")
		assertBowlTile(true)
		UI.catch.hideCircles()
		UI.catch.hide()
		task.wait(0.3)
		assert(not gui.Enabled, "uigate: the bait card should wait a moment after the catch (#2014)")
		task.wait(UI.bait.SETTLE + 0.5)
		assert(gui.Enabled, "uigate: the bait card never showed after the catch (#2014)")
		local banner = gui:FindFirstChild("Banner", true)
		assert(banner.Text == "A CAT CAME TO BOWL 2!", "uigate: the cat's card says " .. banner.Text)
	end },
	-- #2412 (Derek2: "make food bowl cat pop ups never appear mid catch or while holding a cat"): a cat (an Epic, so the
	-- first wow card comes too) reaches the bowl while a cat is carried; neither card shows until the carry ends
	{ "BaitWaitsForCarry", function()
		local epic: string? = nil
		for _, def in Catalog.cats do
			if def.rarity == "Epic" then
				epic = def.id
				break
			end
		end
		assert(epic, "uigate: no Epic cat in the catalog")
		local now = workspace:GetServerTimeNow()
		UI.bait.set({ lureId = Catalog.lures[2].id, readyAt = now - 1, placedAt = now - 300 }, 1)
		UI.setCarrying({ catId = Catalog.cats[1].id, catName = Catalog.cats[1].name, rarity = Catalog.cats[1].rarity })
		UI.bait.arrived({ catId = epic, stars = 2 }, 1)
		UI.bait.wow("Epic", false, epic)
		task.wait(UI.bait.SETTLE + 0.5)
		local card = UIShim.playerGui:FindFirstChild("CatCafeBaitCard")
		local pull = UIShim.playerGui:FindFirstChild("CatCafeBigPull")
		assert(card and not card.Enabled, "uigate: the bait card popped up while carrying a cat (#2412)")
		assert(not (pull and pull.Enabled), "uigate: the wow card popped up while carrying a cat (#2412)")
		UI.setCarrying(nil)
		task.wait(UI.bait.SETTLE + 0.6)
		assert(card.Enabled, "uigate: the bait card never showed after the carry (#2412)")
		pull = UIShim.playerGui:FindFirstChild("CatCafeBigPull")
		assert(pull and pull.Enabled, "uigate: the wow card never showed after the carry (#2412)")
		UI.bait.set(nil, 1) -- the bowl empty again for the scenes after
	end },
	-- #1161: the cat's card with two bowls names the bowl, and its banner stays clear of the X on a phone
	{ "BaitCardBowl2", function()
		local now = workspace:GetServerTimeNow()
		UI.bait.setSecond("on")
		UI.bait.set({ lureId = Catalog.lures[2].id, readyAt = now - 5, placedAt = now - 300 }, 2)
		UI.bait.showReady({ catId = Catalog.cats[2].id, stars = 2 }, 2)
	end },
	-- #2530 (Derek2: "remove pop ups for cats caught progress towards goal just adds more clutter"): the Tame card has
	-- no "Park N / M" area count any more (#1919)
	{ "BaitCardArea", function()
		local now = workspace:GetServerTimeNow()
		UI.bait.set({ lureId = Catalog.lures[1].id, readyAt = now - 5, placedAt = now - 300 }, 1)
		UI.bait.showReady({ catId = missingCat("park").id, stars = 2 }, 1)
		local pill = UIShim.playerGui:FindFirstChild("CatCafeBaitCard"):FindFirstChild("AreaCount", true)
		assert(pill == nil, "uigate: the Tame card still shows an area count (#2530)")
	end },
	-- #1161: a cat at each bowl: bowl 1 first, and each tab says its own bowl
	{ "BaitBothReady", function()
		local now = workspace:GetServerTimeNow()
		UI.bait.setSecond("on")
		UI.bait.set({ lureId = Catalog.lures[1].id, readyAt = now - 20, placedAt = now - 300 }, 1)
		UI.bait.set({ lureId = Catalog.lures[2].id, readyAt = now - 5, placedAt = now - 300 }, 2)
		UI.bait.showReady({ catId = Catalog.cats[2].id, stars = 2 }, 2)
		UI.bait.showReady({ catId = Catalog.cats[3].id, stars = 3 }, 1)
		press("CatCafeBaitCard", "Close")
		assertBowlTile(true)
		UI.bait.openPicker()
		assertBowlTabs(1, "A cat is at bowl 1!")
		assertBowlAction("See the cat")
		press("Bait", "Bowls.Bowl2")
		assertBowlTabs(2, "A cat is at bowl 2!")
		assertBowlAction("See the cat")
	end },
	-- #1161: the pass bought with the window open: ProfileSync's secondBowl goes from "offer" to "on", and the locked
	-- card gives way to an empty bowl 2 that takes food, with the HUD's "2", no rejoin
	{ "BaitBoughtMidSession", function()
		local Config = UIShim.require("ReplicatedStorage.Shared.Config")
		local prices = storePrices(true)
		prices[Config.SecondBowlPassId] = { robux = 149, forSale = true }
		UI.store.preview(prices, {})
		UI.bait.setSecond("offer")
		UI.bait.openPicker()
		press("Bait", "Bowls.Bowl2")
		assertBowlTabs(2, "Get a second bowl")
		UI.bait.setSecond("on")
		assertBowlTabs(2, "Bowl 2 is empty")
		-- Use on a food the player has puts it in bowl 2
		local food = Catalog.lures[1].id
		UI.update({ lures = { [food] = 3 } })
		local sent = nil
		local connection = UI.events.useLure:Connect(function(lureId, bowl)
			sent = tostring(lureId) .. "@" .. tostring(bowl)
		end)
		press("Bait", food .. ".Use")
		connection:Disconnect()
		assert(sent == food .. "@2", "uigate: Use after the pass sent " .. tostring(sent) .. " (#1161)")
		local hud = UIShim.playerGui:FindFirstChild("CatCafeHUD")
		local count = hud and hud:FindFirstChild("Bowl", true)
		count = count and count:FindFirstChild("Count", true)
		assert(count and count.Visible, "uigate: the HUD bowl tile has no 2 after the pass (#1161)")
	end },
	-- #1161: no pass: bowl 2's tab is locked; tapping it shows the pass card with its price. #1767: under it three
	-- short lines on what it gives, not the seven-food odds table
	{ "BaitSecondOffer", function()
		local Config = UIShim.require("ReplicatedStorage.Shared.Config")
		local prices = storePrices(true)
		prices[Config.SecondBowlPassId] = { robux = 149, forSale = true }
		UI.store.preview(prices, {})
		UI.bait.setSecond("offer")
		UI.bait.openPicker()
		assertBowlTabs(1, "empty") -- never opens on the locked tab
		press("Bait", "Bowls.Bowl2")
		local window = baitWindow()
		local title = window:FindFirstChild("Status", true):FindFirstChild("Title")
		assert(title.Text == "Get a second bowl", "uigate: bowl 2's tab shows " .. title.Text .. " (#1161)")
		local odds = window:FindFirstChild("SecondOdds", true)
		assert(odds and odds.Visible, "uigate: the locked bowl 2 shows no card under it (#1161)")
		local lines = 0
		for _, child in odds:GetChildren() do
			if child:IsA("TextLabel") then
				lines += 1
				assert(string.sub(child.Name, 1, 5) ~= "Odds_", "uigate: bowl 2 lists a food's odds again (#1767)")
			end
		end
		assert(lines == 4, ("uigate: bowl 2's card has %d lines, wants a heading and 3 (#1767)"):format(lines))
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
		-- #2057: rarest first, Star Treat's row on top
		local tops: { [string]: number } = {}
		for _, d in game:GetService("Players").LocalPlayer.PlayerGui:GetDescendants() do
			if d:IsA("Frame") and (d.Name == "star_treat" or d.Name == "sardines") and d.AbsoluteSize.Y > 40 then
				tops[d.Name] = d.AbsolutePosition.Y
			end
		end
		local star, sardines = tops.star_treat, tops.sardines
		assert(star and sardines, "uigate: the dealer drew no Star Treat or Sardines row (#2057)")
		assert(star < sardines, "uigate: the dealer lists Sardines above Star Treat, wants rarest first (#2057)")
	end },
	-- #2573 (riverpopcorn886's idea): Buy all on the strip; its card lists the plan, best grade first, and at 3M coins
	-- says 3 of 4 fit (one Star Treat, two Sardines); Buy sends one buyDealerAll with the night shown
	{ "DealerBuyAll", function()
		local before: any = UI.getState()
		Scenes._cashMoney = { money = before.money, passBoosts = before.passBoosts or false, goldenFish = before.goldenFish or 0 }
		UI.update({ money = 3000000 })
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
		local window = UIShim.playerGui:FindFirstChild("Dealer", true)
		local all = window and window:FindFirstChild("BuyAll", true)
		assert(all and all.Visible, "uigate: the dealer has no Buy all while foods fit (#2573)")
		local sent: { any } = {}
		local connection = UI.events.buyDealerAll:Connect(function(night)
			table.insert(sent, night)
		end)
		press("Dealer", "BuyAll")
		local cover = window:FindFirstChild("BuyAllCover", true)
		assert(cover and cover.Visible, "uigate: Buy all opened no confirm card (#2573)")
		local list = cover:FindFirstChild("List", true).Text
		assert(string.find(list, "1 Star Treat", 1, true) == 1, "uigate: the Buy all card lists " .. list .. " (#2573)")
		local partial = cover:FindFirstChild("Partial", true)
		assert(partial.Visible and string.find(partial.Text, "3 of 4", 1, true), "uigate: the card reads " .. partial.Text .. " (#2573)")
		press("Dealer", "BuyAllCover.Cancel")
		assert(not cover.Visible and #sent == 0, "uigate: Cancel sent Buy all or kept the card (#2573)")
		press("Dealer", "BuyAll")
		press("Dealer", "BuyAllCover.Buy")
		connection:Disconnect()
		assert(#sent == 1 and sent[1] == 20400, "uigate: Buy sent " .. #sent .. " Buy all (#2573)")
		-- the shot shows the card again
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
		press("Dealer", "BuyAll")
	end },
	{ "Settings", function()
		UI.open("Settings")
	end },
	{ "TipJar", function()
		UI.tipJar.open()
	end },
	-- #1965: the HUD's Pass tile while a season runs, with the Cafe Pass ticket and a reward ready to claim
	{ "HUDPass", function()
		UI.pass.set({ season = 1, startsAt = 0, endsAt = 1798934400, level = 4, xp = 3500, xpPerLevel = 800,
			levels = 30, paid = false, claimedFree = { 2 }, claimedPaid = {}, claimable = 1, items = {} })
		local tile = UIShim.playerGui:FindFirstChild("CatCafeHUD"):FindFirstChild("Pass", true)
		assert(tile and tile.Visible, "uigate: no Pass tile while a season runs (#1965)")
	end },
	-- #1646: the Cafe Pass at level 4 with level 2's free spin claimed, the paid track locked
	{ "CafePass", function()
		UI.pass.set({ season = 1, startsAt = 0, endsAt = 1798934400, level = 4, xp = 3500, xpPerLevel = 800,
			levels = 30, paid = false, claimedFree = { 2 }, claimedPaid = {}, claimable = 1, items = {} })
		UI.pass.open()
		-- #2588: the corner badge is the HUD Pass tile's medal, not the 🍁 emoji
		assert(badgeDraws("CafePass", "79367870405446"), "uigate: the Cafe Pass badge is not the Pass medal (#2588)")
		local modals = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("CatCafeModals")
		local window = modals and modals:FindFirstChild("CafePass", true)
		assert(window and window:IsA("GuiObject") and window.Visible, "uigate: the Cafe Pass is not open")
		local level4 = window:FindFirstChild("Level4", true)
		local claim = level4 and level4:FindFirstChild("Free") and level4.Free:FindFirstChild("Claim")
		assert(claim and claim:IsA("GuiObject") and claim.Visible, "uigate: level 4's free reward has no Claim")
		-- #2089: the "?" mystery box picture is retired: no crate reward (nor anything else) draws it
		for _, d in game:GetService("Players").LocalPlayer.PlayerGui:GetDescendants() do
			if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and string.find(d.Image, "76162414943592", 1, true) then
				error("uigate: " .. d:GetFullName() .. " still draws the ? mystery box (#2089)")
			end
		end
	end },
	-- #1646: the paid track not bought yet, with Roblox's price on the buy button, and the Store's Cafe Pass card
	{ "CafePassBuy", function()
		UI.store.preview({ [3728336202] = { robux = 299, forSale = true } }, {})
		UI.pass.set({ season = 1, startsAt = 0, endsAt = 1798934400, level = 4, xp = 3500, xpPerLevel = 800,
			levels = 30, paid = false, claimedFree = {}, claimedPaid = {}, claimable = 2, items = {} })
		UI.pass.open()
		local modals = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("CatCafeModals")
		local window = modals and modals:FindFirstChild("CafePass", true)
		local buy = window and window:FindFirstChild("Buy", true)
		assert(buy and buy:IsA("GuiObject") and buy.Visible, "uigate: no buy button on the Cafe Pass")
	end },
	{ "StoreCafePass", function()
		UI.store.preview({ [3728336202] = { robux = 299, forSale = true } }, {})
		UI.pass.set({ season = 1, startsAt = 0, endsAt = 1798934400, level = 4, xp = 3500, xpPerLevel = 800,
			levels = 30, paid = false, claimedFree = {}, claimedPaid = {}, claimable = 2, items = {} })
		UI.store.open()
		press("Store", "cafePass")
	end },
	-- #1646: the paid track bought at level 7, its reached rewards ready to claim
	{ "CafePassPaid", function()
		UI.pass.set({ season = 1, startsAt = 0, endsAt = 1798934400, level = 7, xp = 5900, xpPerLevel = 800,
			levels = 30, paid = true, claimedFree = { 2, 4 }, claimedPaid = { 1 }, claimable = 7, items = {},
			tags = { "vip", "tag_maple" }, tagShown = "tag_maple" })
		UI.pass.open()
		-- #2087: a paid item's picture and name sit centred in the room over Claim (they hugged the top), and the
		-- uniform's square is the uniform's own colour
		local modals = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("CatCafeModals")
		local window = modals and modals:FindFirstChild("CafePass", true)
		for _, level in { 3, 5 } do
			local column = window and window:FindFirstChild("Level" .. level, true)
			local card = column and column:FindFirstChild("Paid")
			local group = card and card:FindFirstChild("ItemGroup")
			local claim = card and card:FindFirstChild("Claim")
			assert(group and claim and claim.Visible, "uigate: level " .. level .. "'s paid item has no picture or Claim (#2087)")
			local roomTop, roomBottom = card.AbsolutePosition.Y, claim.AbsolutePosition.Y
			local middle = group.AbsolutePosition.Y + group.AbsoluteSize.Y / 2
			local third = (roomBottom - roomTop) / 3
			assert(
				middle >= roomTop + third and middle <= roomBottom - third,
				string.format("uigate: level %d's paid item is not centred over Claim (%.0f in %.0f..%.0f, #2087)", level, middle, roomTop, roomBottom)
			)
		end
		local uniform = window:FindFirstChild("Level3", true).Paid.ItemGroup.Item
		-- #2592: the Pumpkin uniform's own picture (its apron and cap) in place of the 👕 on a pumpkin tile (#2087)
		local drawn = false
		for _, piece in uniform:GetDescendants() do
			if piece:IsA("ImageLabel") and string.find(piece.Image, "119763026239046", 1, true) then
				drawn = true
			end
		end
		assert(drawn, "uigate: the Pumpkin uniform's square does not draw its picture (#2592)")
	end },
	-- #1626: the busiest top strip, a VIP owner who has not bought the paid track: Buy, Claim all and the chat tag
	{ "CafePassTag", function()
		UI.store.preview({ [3728336202] = { robux = 299, forSale = true } }, {})
		UI.pass.set({ season = 1, startsAt = 0, endsAt = 1798934400, level = 4, xp = 3500, xpPerLevel = 800,
			levels = 30, paid = false, claimedFree = {}, claimedPaid = {}, claimable = 2, items = {},
			tags = { "vip" }, tagShown = "vip" })
		UI.pass.open()
		local modals = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("CatCafeModals")
		local window = modals and modals:FindFirstChild("CafePass", true)
		local tag = window and window:FindFirstChild("ChatTag", true)
		assert(tag and tag:IsA("GuiObject") and tag.Visible, "uigate: no chat tag button on the Cafe Pass")
	end },
	{ "Spin", function()
		UI.spin.open()
	end },
	{ "SpinOdds", function()
		UI.spin.open()
		press("SpinWheel", "Odds")
	end },
	-- #2246 (Derek2 11-07: "Add the ability to skip spins"): while the wheel turns "Tap to skip" sits on its rim, and a
	-- tap on the wheel lands it; the shot is mid turn, with the hint up
	{ "SpinSkipHint", function()
		UI.spin.open()
		UI.spin.result(1, 100)
		UIShim.advance(0.5)
		local window = UIShim.playerGui:FindFirstChild("SpinWheel", true)
		local hint = window and window:FindFirstChild("SkipHint", true)
		assert(hint and hint.Visible, "uigate: no Tap to skip while the wheel turns (#2246)")
		local tap = window:FindFirstChild("SkipTap", true)
		assert(tap and tap.Visible, "uigate: the wheel cannot be tapped while it turns (#2246)")
	end },
	{ "SpinSkipTap", function()
		UI.spin.open()
		UI.spin.result(1, 100)
		UIShim.advance(0.5)
		press("SpinWheel", "SkipTap")
		local window = UIShim.playerGui:FindFirstChild("SpinWheel", true)
		local hint = window:FindFirstChild("SkipHint", true)
		assert(not hint.Visible, "uigate: Tap to skip stayed up after the wheel landed (#2246)")
		assert(not window:FindFirstChild("SkipTap", true).Visible, "uigate: a tap on the wheel did not land it (#2246)")
		-- Space skips the next one, as the button and the tap do
		UIShim.advance(10)
		UI.spin.result(1, 100)
		UIShim.advance(0.5)
		assert(hint.Visible, "uigate: no Tap to skip on the second spin (#2246)")
		local input = { KeyCode = Enum.KeyCode.Space, UserInputType = Enum.UserInputType.Keyboard }
		UIShim.fire(UIShim.eventOf(game:GetService("UserInputService"), "InputBegan"), input, false)
		assert(not hint.Visible, "uigate: Space did not skip the spin (#2246)")
	end },
	-- #1500: the end of the Odds list, where the two 0.5% jackpots sit in gold
	{ "SpinOddsJackpots", function()
		UI.spin.open()
		press("SpinWheel", "Odds")
		local modals = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("CatCafeModals")
		local window = modals and modals:FindFirstChild("SpinWheel", true)
		local list = window and window:FindFirstChild("Rows", true)
		assert(list and list:IsA("ScrollingFrame"), "uigate: no Odds list")
		list.CanvasPosition = Vector2.new(0, 100000)
		local count = 0
		for _, row in list:GetChildren() do
			if row:IsA("Frame") and string.match(row.Name, "^Slice%d+$") then
				count += 1
			end
		end
		assert(count == #Catalog.spinWheel, ("uigate: %d odds rows for %d slices"):format(count, #Catalog.spinWheel))
		local prize = list:FindFirstChild("Slice8") and list.Slice8:FindFirstChild("Prize")
		local fishJackpot = Catalog.spinWheel[8].count -- #2237: 60 since the fish cut
		assert(prize and string.find(prize.Text, "^Jackpot: " .. fishJackpot .. " golden fish"), "uigate: slice 8 is not the fish jackpot")
	end },
	-- #2574: Juniper's window at Tier 1 with 350 golden fish: this week's item on sale on the gold card, the "?" teaser
	-- and the rest at full price (the Long Net greyed until Tier 2); opening sends MarkMysterySeen once
	{ "MysteryMarket", function()
		local before: any = UI.getState()
		Scenes._cashMoney = { money = before.money, passBoosts = before.passBoosts or false, goldenFish = before.goldenFish or 0 }
		UI.update({ goldenFish = 350, mystery = {}, mysterySeen = false, mysteryOpen = true } :: any)
		local seen = 0
		local counting = UI.events.mysterySeen:Connect(function()
			seen += 1
		end)
		UI.mystery.open()
		counting:Disconnect()
		assert(seen == 1, "uigate: the first open should send MarkMysterySeen once (#2574)")
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local window = modals and modals:FindFirstChild("MysteryMarket", true)
		assert(window and window:FindFirstChild("Featured", true), "uigate: no featured card (#2574)")
		assert(window:FindFirstChild("Teaser", true), "uigate: no next week teaser (#2574)")
		UI.update({ mysterySeen = true } :: any)
	end },
	-- #2574: the featured item owned and buys not open yet ("Soon")
	{ "MysteryMarketOwned", function()
		local before: any = UI.getState()
		Scenes._cashMoney = { money = before.money, passBoosts = before.passBoosts or false, goldenFish = before.goldenFish or 0 }
		UI.update({ goldenFish = 1200, mystery = { backpack = true, long_net = true }, mysterySeen = true, mysteryOpen = false } :: any)
		UI.mystery.open()
	end },
	-- #2614: a Super gift waits on your plot: the HUD's gold line under the clock column; opening it shows the
	-- "Super gift!" card with the top area's crate and its 15 golden fish
	{ "MysteryGiftSuper", function()
		local world = workspace:FindFirstChild("World") or Instance.new("Folder")
		world.Name = "World"
		world.Parent = workspace
		local plots = world:FindFirstChild("Plots") or Instance.new("Folder")
		plots.Name = "Plots"
		plots.Parent = world
		local plot = Instance.new("Model")
		plot.Name = "GatePlot"
		plot:SetAttribute("OwnerUserId", game:GetService("Players").LocalPlayer.UserId)
		plot:SetAttribute("MysteryGiftAt", 1794000000)
		plot:SetAttribute("MysteryGiftTier", "Super")
		plot.Parent = plots
		Scenes._giftPlot = plot
		UI.giftWait.start()
		local line = UIShim.playerGui:FindFirstChild("GiftWaiting", true) :: TextLabel?
		assert(line and line.Visible and string.find(line.Text, "super gift", 1, true), "uigate: no gift line (#2614)")
		UI.potions.giftResult("crate", "highest", 1, "Super", 15)
		local card = UIShim.playerGui:FindFirstChild("Gift", true)
		local title = card and card:FindFirstChild("Title") :: TextLabel?
		assert(title and string.find(title.Text, "Super gift!", 1, true), "uigate: the gift card's heading (#2614)")
	end },
	{ "Market", function()
		-- #2571: a save that never opened Treats and perks shows the tab's red "!"; opening the tab clears it and
		-- sends it as seen once
		local seenBefore = (UI.getState() :: any).storeSeen
		UI.update({ storeSeen = { featured = 1 } } :: any)
		local sent: { string } = {}
		local counting = UI.events.storeSeen:Connect(function(tab: string)
			table.insert(sent, tab)
		end)
		UI.market.open()
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local tab = modals and modals:FindFirstChild("TreatsTab", true)
		local dot = tab and tab:FindFirstChild("NewDot", true)
		assert(dot and (dot :: GuiObject).Visible, "uigate: no ! on Treats and perks before it is opened (#2571)")
		press("FishMarket", "TreatsTab")
		assert(not (dot :: GuiObject).Visible, "uigate: opening Treats and perks did not clear its ! (#2571)")
		press("FishMarket", "CratesTab")
		press("FishMarket", "TreatsTab")
		assert(table.concat(sent, ",") == "treats", "uigate: Treats and perks sent as seen: " .. table.concat(sent, ","))
		counting:Disconnect()
		UI.update({ storeSeen = if type(seenBefore) == "table" then seenBefore else {} } :: any)
		press("FishMarket", "CratesTab")
	end },
	-- #2290 (Derek2: "buying items fast from shop sometimes stays too long on the ... waiting button"): three Treats
	-- bought fast go to the server 0.55 s apart (its 2 a second never drops one), each shows "..." from its press, and
	-- a buy the server never answers frees its button 2 s after it was sent, not 5
	{ "MarketFastBuys", function()
		local before = (UI.getState() :: any).goldenFish
		UI.update({ goldenFish = 100000 } :: any)
		local sent: { string } = {}
		local counting = UI.events.buyFishItem:Connect(function(id: string)
			table.insert(sent, id)
		end)
		UI.market.open()
		press("FishMarket", "TreatsTab")
		local ids = { "star_treat", "golden_espresso", "big_bowl" }
		for _, id in ids do
			press("FishMarket", id .. ".Buy")
		end
		local window = UIShim.playerGui:FindFirstChild("FishMarket", true)
		local function label(id: string): string
			local row = window:FindFirstChild(id, true)
			local buy = row and row:FindFirstChild("Buy", true)
			local face = buy and (if buy:IsA("TextButton") then buy else buy:FindFirstChildWhichIsA("TextLabel", true))
			for _, piece in (buy :: Instance):GetDescendants() do
				if (piece:IsA("TextLabel") or piece:IsA("TextButton")) and piece.Text ~= "" then
					return piece.Text
				end
			end
			return if face then face.Text else ""
		end
		assert(#sent == 1, ("uigate: %d buys went at once, not 1 (#2290)"):format(#sent))
		for _, id in ids do
			assert(label(id) == "...", "uigate: " .. id .. " reads " .. label(id) .. " right after its press (#2290)")
		end
		UIShim.advance(0.6)
		assert(#sent == 2, ("uigate: %d buys sent after 0.6 s, not 2 (#2290)"):format(#sent))
		UIShim.advance(0.6)
		assert(#sent == 3, ("uigate: %d buys sent after 1.2 s, not 3 (#2290)"):format(#sent))
		assert(sent[1] == ids[1] and sent[2] == ids[2] and sent[3] == ids[3], "uigate: the buys went out of order (#2290)")
		UIShim.advance(1.2) -- the first buy was sent 2.4 s ago with no answer
		assert(label(ids[1]) ~= "...", "uigate: an unanswered buy still reads ... 2.4 s after it was sent (#2290)")
		UIShim.advance(1.5)
		for _, id in ids do
			assert(label(id) ~= "...", "uigate: " .. id .. " still reads ... (#2290)")
		end
		counting:Disconnect()
		UI.update({ goldenFish = before } :: any)
	end },
	-- #2577 (Derek2: "the buttons for buying crates sometimes get stuck on ... for a while"): only the pressed crate reads
	-- "...", another crate's press queues behind it, and an open the server never answers frees its button after 2.5 s
	-- as "Try again" (with a toast), when the queued press goes
	{ "MarketCrateWait", function()
		local before = UI.getState()
		local crates, fish = before.crates, (before :: any).goldenFish
		UI.update({ crates = { park_crate = 2, alley_crate = 1 }, goldenFish = 100000 } :: any)
		local sent: { string } = {}
		local counting = UI.events.openCrate:Connect(function(id: string)
			table.insert(sent, id)
		end)
		UI.market.open()
		press("FishMarket", "CratesTab")
		local window = UIShim.playerGui:FindFirstChild("FishMarket", true)
		local function label(id: string): string
			local card = window:FindFirstChild(id, true)
			local open = card and card:FindFirstChild("Open", true)
			for _, piece in (open :: Instance):GetDescendants() do
				if (piece:IsA("TextLabel") or piece:IsA("TextButton")) and piece.Text ~= "" then
					return piece.Text
				end
			end
			return ""
		end
		press("FishMarket", "park_crate.Open")
		assert(#sent == 1 and sent[1] == "park_crate", "uigate: Open sent " .. table.concat(sent, ",") .. " (#2577)")
		assert(label("park_crate") == "...", "uigate: the pressed crate reads " .. label("park_crate") .. " (#2577)")
		assert(label("alley_crate") ~= "...", "uigate: another crate reads ... while one opens (#2577)")
		press("FishMarket", "alley_crate.Open")
		assert(#sent == 1 and label("alley_crate") == "...", "uigate: a second Open went at once or shows no wait (#2577)")
		UIShim.advance(2.8) -- no CrateResult for park
		assert(label("park_crate") == "Try again", "uigate: an unanswered Open reads " .. label("park_crate") .. " after 2.8 s (#2577)")
		assert(#sent == 2 and sent[2] == "alley_crate", "uigate: the queued Open did not go once the first ran out (#2577)")
		local toast = false
		for _, d in UIShim.playerGui:GetDescendants() do
			if d:IsA("TextLabel") and string.find(d.Text, "didn't go through", 1, true) then
				toast = true
			end
		end
		assert(toast, "uigate: no toast when an Open ran out unanswered (#2577)")
		UI.market.result("alley_crate", "", false, 0) -- a refusal frees alley at once
		assert(label("alley_crate") ~= "...", "uigate: a refused Open still reads ... (#2577)")
		counting:Disconnect()
		UI.update({ crates = crates or {}, goldenFish = fish } :: any)
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
	-- #1633: the Codes Cat's circle opens the Store on Featured; the player taps Codes on the rail
	{ "Codes", function()
		UI.codes.open()
	end },
	{ "CodesPrize", function()
		-- #1714: the used list, newest first; a code no longer in the table shows its code and date only
		UI.update({ codesRedeemed = { playtest = 1793900000, old_code = 1793000000 } } :: any)
		UI.codes.open()
		press("Store", "codes")
		UI.codes.result(true, "Code redeemed!", CODE_PRIZE)
		local store = UIShim.playerGui:FindFirstChild("Store", true)
		local used = store and store:FindFirstChild("Used", true)
		assert(used and used:FindFirstChild("playtest") and used:FindFirstChild("old_code"), "uigate: no used codes (#1714)")
		assert(store:FindFirstChild("Header", true), "uigate: no Codes header (#1714)")
		local hint = store:FindFirstChild("Hint", true) :: TextLabel?
		assert(hint and hint.Visible and hint.Text == "Check the game description for codes", "uigate: no codes hint (#2610)")
	end },
	-- #1714: a refusal is one calm line in place; nothing used yet says so
	{ "CodesRefused", function()
		UI.codes.open()
		press("Store", "codes")
		UI.codes.result(false, "That code doesn't exist", nil)
	end },
	-- #1633: the circle's Store opens on Featured, and walking out closes it from any tab; a Store the player opened
	-- with the tile stays when they walk out
	{ "CodesBenchWalkOut", function()
		UI.codes.open()
		assert(UI.store.benchShowing(), "the circle should open the Store")
		assert(not UI.store.codesShowing(), "the circle should open the Store on Featured, not Codes")
		press("Store", "codes")
		UI.codes.close()
		assert(not UI.store.benchShowing(), "walking out should close the Store the circle opened")
		UI.store.open()
		UI.codes.open()
		assert(not UI.store.benchShowing(), "a Store already open is not the circle's")
		UI.codes.close()
		assert(UI.store.codesShowing() == false, "the tile's Store stays on Featured")
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
	-- F99: a rainbow Epic in the cat room: the turning rainbow edge and badge, "Rainbow Epic ..." and its x3 chip
	{ "CatsRainbow", function()
		local player = samplePlayer(os.time())
		player.cats.gate_rainbow = rainbowCat()
		UI.update({ cats = player.cats })
		UI.open("Cats")
		task.delay(0.2, function()
			press("Cats", "gate_rainbow")
		end)
	end },
	-- its sell asks twice: "Sell your Rainbow ...? It earns x3", then "Really sell it?"
	{ "CatsRainbowSell", function()
		local player = samplePlayer(os.time())
		player.cats.gate_rainbow = rainbowCat()
		UI.update({ cats = player.cats })
		UI.open("Cats")
		task.delay(0.2, function()
			press("Cats", "gate_rainbow")
			press("Cats", "Sell")
			press("Cats", "Sell")
		end)
	end },
	-- #1618 (Derek2 11-05: "don't even need that button just remove it"): no Sell extras card in the cat room
	{ "CatsNoSellExtras", function()
		UI.open("Cats")
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		assert(modals and modals:FindFirstChild("SellExtras", true) == nil, "uigate: the Sell extras card is back")
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
	-- #1766: the Decor Index's Rally page says where its pieces come from, and a piece not owned reads "Rally Crate"
	{ "IndexDecorRally", function()
		UI.open("Collection")
		press("Collection", "DecorTab")
		press("Collection", "rally")
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local window = modals and modals:FindFirstChild("Collection", true)
		local source = window and window:FindFirstChild("Source", true)
		assert(source and source.Visible, "uigate: the Rally page does not say where its pieces come from (#1766)")
		local locked = 0
		for _, child in window:GetDescendants() do
			if child:IsA("TextLabel") and child.Text == "Rally Crate" and child.Visible then
				locked += 1
			end
		end
		assert(locked > 0, "uigate: no Rally piece reads Rally Crate (#1766)")
	end },
	-- #1772: the Gold tab opens with a Gold cats line over the areas, as the Rainbow tab has Rainbow cats
	{ "IndexGold", function()
		UI.open("Collection")
		press("Collection", "GoldTab")
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local window = modals and modals:FindFirstChild("Collection", true)
		local line = window and window:FindFirstChild("all", true)
		assert(line and line.Visible, "uigate: the Gold tab has no overall line (#1772)")
		local title = line:FindFirstChild("Area", true)
		assert(title and title.Text == "Gold cats", "uigate: the Gold tab's line reads " .. tostring(title and title.Text) .. " (#1772)")
		press("Collection", "IndexTab")
		assert(title.Text ~= "Gold cats", "uigate: the Cats tab's line still reads Gold cats (#1772)")
	end },
	-- F99 section 3: the Index's Rainbow tab, the Rainbow cats line with its strip open on "Reward ready", rainbow
	-- tiles on turning borders
	{ "IndexRainbow", function()
		UI.open("Collection")
		press("Collection", "RainbowTab")
		press("Collection", "rainbow.Header.Rewards")
	end },
	-- F99 section 4: three claimed, so the rainbow luck pill shows by the tabs and the milestones row has its band
	{ "IndexRainbowLuck", function()
		UI.update({
			indexRewards = { rainbow = { rainbow1 = true, rainbow3 = true, rainbow5 = true } },
			rainbowLuck = 0.2,
		})
		UI.open("Collection")
		press("Collection", "RainbowTab")
		press("Collection", "rainbow.Header.Rewards")
		press("Collection", "rainbow.Expand")
	end },
	-- #2270 (Derek2: "the bold text on index rewards is hard to read"): every forever pill, the NEXT sticker and the
	-- reward band read at 4.5:1 or better against their own fill, and no turning bands sit under their words
	{ "IndexRewardContrast", function()
		local before: any = UI.getState()
		local restore = { goldLuck = before.goldLuck or 0, baitSpeed = before.baitSpeed or 0 }
		UI.update({
			indexRewards = { rainbow = { rainbow1 = true, rainbow3 = true, rainbow5 = true } },
			rainbowLuck = 0.2,
			goldLuck = 0.1,
			baitSpeed = 0.2,
		})
		UI.open("Collection")
		press("Collection", "RainbowTab")
		press("Collection", "rainbow.Header.Rewards")
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local window = modals and modals:FindFirstChild("Collection", true)
		assert(window, "uigate: no Index window (#2270)")
		local function lum(c: Color3): number
			local function ch(x: number): number
				return if x <= 0.03928 then x / 12.92 else ((x + 0.055) / 1.055) ^ 2.4
			end
			return 0.2126 * ch(c.R) + 0.7152 * ch(c.G) + 0.0722 * ch(c.B)
		end
		local names = { bonus = true, goldLuck = true, rainbowLuck = true, baitSpeed = true, NextSticker = true, Bonus = true }
		local checked, seen = 0, {}
		for _, label in window:GetDescendants() do
			if label:IsA("TextLabel") and names[label.Name] and label.Visible and label.Text ~= "" then
				local a, b = lum(label.TextColor3), lum(label.BackgroundColor3)
				local ratio = (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05)
				assert(
					ratio >= 4.5,
					("uigate: %s %q reads at %.2f:1 (#2270)"):format(label.Name, label.Text, ratio)
				)
				local bands = label:FindFirstChild("Rainbow")
				assert(
					not (bands and bands:IsA("UIGradient") and bands.Enabled),
					"uigate: rainbow bands tint the words of " .. label.Name .. " (#2270)"
				)
				checked += 1
				seen[label.Name] = true
			end
		end
		assert(seen.rainbowLuck and seen.NextSticker, "uigate: no rainbow luck pill or NEXT sticker to check (#2270)")
		assert(checked >= 3, "uigate: only " .. checked .. " reward labels checked (#2270)")
		UI.update(restore :: any) -- later Index scenes keep their own header pills
	end },
	-- #2272 (Derek2: "show cat collector through walls like rich tip"): while he visits, his tag draws over walls out
	-- to the rich tip's 150 studs, on a solid bubble so it reads against any wall
	{ "CollectorTagWalls", function()
		bindLawnPlot()
		local spot = lawnPlot:FindFirstChild("CollectorSpot")
		if spot == nil then
			spot = Instance.new("Part")
			spot.Name = "CollectorSpot"
			spot.Anchored = true
			spot.Position = Vector3.new(0, 3, 0)
			spot.Parent = lawnPlot
		end
		local uid
		for id in (UI.getState() :: any).cats or {} do
			uid = id
			break
		end
		assert(uid, "uigate: no owned cat for the Collector to offer on")
		UI.collector.offer(uid, { value = 1, fish = 5 }, workspace:GetServerTimeNow() + 120)
		UIShim.advance(0.3)
		local tag = UIShim.playerGui:FindFirstChild("CatCafeCollectorTag", true)
		UI.collector.offer("", nil, 0)
		assert(tag and tag:IsA("BillboardGui"), "uigate: no Collector tag (#2272)")
		assert(tag.AlwaysOnTop, "uigate: the Collector tag hides behind walls (#2272)")
		assert(tag.MaxDistance >= 150, "uigate: the Collector tag fades at " .. tag.MaxDistance .. " studs, under the rich tip's 150 (#2272)")
		local button = tag:FindFirstChild("Tag")
		assert(button and button.BackgroundTransparency == 0, "uigate: the Collector tag has no bubble behind its words (#2272)")
	end },
	-- a found rainbow cat's card: "Rainbow" before its name, a rainbow edge
	{ "IndexRainbowCat", function()
		UI.open("Collection")
		press("Collection", "RainbowTab")
		local first
		for index, def in Catalog.cats do
			if index % 12 == 2 and def.area ~= "spare" and def.exclusive ~= true then
				first = def.id
				break
			end
		end
		press("Collection", "Book." .. first)
	end },
	-- #2207 (Derek2: "IBowBeforeGod tamed an Epic Gardener Cat at their..."): a toast too long for one row wraps and
	-- the pill grows taller, every word showing; a short one stays one 40 px row
	{ "ToastWrap", function()
		local long = "IBowBeforeGod tamed a Legendary Gardener Cat at their bait bowl!"
		local short = "Saved!"
		UI.announce(long, "Legendary") -- (#2399: Epic shout-outs no longer show)
		UI.toast(short, "good")
		-- (a short phone shows fewer toasts at once and the rest wait their turn, #2338: the clock runs till it is up)
		local function find(text: string): TextLabel
			for _ = 1, 40 do
				for _, label in UIShim.playerGui:GetDescendants() do
					if label:IsA("TextLabel") and label.Text == text and label.Name == "Text" then
						UIShim.advance(0.3)
						return label
					end
				end
				UIShim.advance(0.25)
			end
			error("uigate: no toast reading " .. text)
		end
		local line = find(long)
		local pill = line.Parent :: Frame
		assert(line.TextWrapped, "uigate: the long toast did not wrap (#2207)")
		assert(line.TextTruncate == Enum.TextTruncate.None, "uigate: the long toast still ends in ... (#2207)")
		assert(line.TextFits, "uigate: the long toast's words do not all fit (#2207)")
		assert(pill.AbsoluteSize.Y > line.TextBounds.Y, "uigate: the long toast's pill is shorter than its rows (#2207)")
		local tall = pill.AbsoluteSize.Y
		local lone = find(short)
		assert(not lone.TextWrapped, "uigate: a short toast wrapped (#2207)")
		local lonePill = lone.Parent :: Frame
		assert(lone.TextFits, "uigate: the short toast's word does not fit (#2207)")
		assert(tall > lonePill.AbsoluteSize.Y + 4, "uigate: the long toast's pill is no taller than a one-row pill (#2207)")
	end },
	-- #2338 (Laptop-Tester, iPhone SE: the Welcome back toast lay over the Index, Quests and Potions tiles): the pill
	-- keeps clear of the menu's tiles, the goal card, the corner tiles and the bottom row, and on screen; a wide screen
	-- keeps it centred
	{ "ToastClear", function()
		local line = "Welcome back! +$12,345 while you were away"
		UI.toast(line, "good")
		task.wait(0.1)
		UIShim.advance(0.5)
		local pill: GuiObject? = nil
		for _, label in UIShim.playerGui:GetDescendants() do
			if label:IsA("TextLabel") and label.Text == line and label.Name == "Text" then
				pill = label.Parent :: GuiObject
			end
		end
		assert(pill, "uigate: no Welcome back toast (#2338)")
		local hud = UIShim.playerGui:FindFirstChild("CatCafeHUD") :: ScreenGui
		local root = hud:FindFirstChild("Root") :: Frame
		local menu = root:FindFirstChild("Menu") :: Frame -- the tile grid (the bottom row has a Menu button too)
		local parts: { GuiObject } = {}
		for _, tile in menu:GetChildren() do
			if tile:IsA("GuiObject") and tile.Visible then
				table.insert(parts, tile)
			end
		end
		for _, name in { "MenuFold", "TierGoal", "Travel", "Corner" } do
			local part = root:FindFirstChild(name) :: GuiObject?
			if part and part.Visible then
				table.insert(parts, part)
			end
		end
		local p0, p1 = pill.AbsolutePosition, pill.AbsolutePosition + pill.AbsoluteSize
		local reach = 0
		for _, part in parts do
			local a0, a1 = part.AbsolutePosition, part.AbsolutePosition + part.AbsoluteSize
			if part.Parent == menu then
				reach = math.max(reach, a1.X)
			end
			local apart = a1.X <= p0.X or p1.X <= a0.X or a1.Y <= p0.Y or p1.Y <= a0.Y
			assert(apart, "uigate: the Welcome back toast lies over the HUD's " .. part.Name .. " (#2338)")
		end
		local screen = hud.AbsoluteSize
		assert(p1.X <= screen.X, "uigate: the Welcome back toast runs off the right edge (#2338)")
		local middle = (p0.X + p1.X) / 2
		if reach < screen.X / 2 - 240 then
			assert(math.abs(middle - screen.X / 2) < 2, ("uigate: the toast sits %d px off centre with room to spare (#2338)"):format(middle - screen.X / 2))
		end
	end },
	-- #2399 (Derek2: "way too many bubble pop ups in the middle top of screen especially for mobile"): at most two
	-- toasts on a phone and three on a PC, the same words again inside ten seconds show nothing (a warning always
	-- does), and an Epic shout-out shows nothing
	{ "ToastFewer", function()
		local ToastRules = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Components.ToastRules")
		local touch = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Scale").isTouch()
		local function shown(): { string }
			local lines = {}
			for _, label in UIShim.playerGui:GetDescendants() do
				if label:IsA("TextLabel") and label.Name == "Text" and label.Parent and label.Parent.Name == "Toast" then
					table.insert(lines, label.Text)
				end
			end
			return lines
		end
		UIShim.advance(4) -- earlier scenes' toasts gone
		for index = 1, 4 do
			UI.toast("Fewer toast " .. index, "info")
		end
		UIShim.advance(0.1)
		local most = ToastRules.maxVisible(touch)
		assert(#shown() <= most, ("uigate: %d toasts on screen, at most %d (#2399)"):format(#shown(), most))
		UIShim.advance(12) -- all gone, queued ones too
		UI.toast("Same words", "good")
		UIShim.advance(3)
		UI.toast("Same words", "good")
		UIShim.advance(0.1)
		assert(not table.find(shown(), "Same words"), "uigate: the same words showed again inside ten seconds (#2399)")
		UI.toast("Not enough coins", "warn")
		UIShim.advance(3)
		UI.toast("Not enough coins", "warn")
		UIShim.advance(0.1)
		assert(table.find(shown(), "Not enough coins"), "uigate: a repeated warning did not show (#2399)")
		assert(UI.announce("Someone tamed an Epic Cat!", "Epic") == false, "uigate: an Epic shout-out showed (#2399)")
		UIShim.advance(0.1)
		assert(not table.find(shown(), "Someone tamed an Epic Cat!"), "uigate: an Epic shout-out pill is up (#2399)")
		UIShim.advance(12)
	end },
	-- #2479 (Derek2: Claim all's rewards "make it look so cluttered"): a many-reward toast shows its title and the
	-- rewards as chips with pictures, all inside the pill and on the screen
	{ "ToastClaimAll", function()
		UI.toast(
			"4 Index rewards: +$11.3M, +25 golden fish, 1 Alley Crate, +5% gold luck forever, 1 spin, +2% faster bait forever",
			"good"
		)
		task.wait(0.4)
		local found: Frame? = nil
		for _, piece in UIShim.playerGui:GetDescendants() do
			if piece.Name == "Toast" and piece:FindFirstChild("Rewards") then
				found = piece :: Frame
			end
		end
		assert(found, "uigate: the Claim all toast has no reward chips (#2479)")
		local toast = found :: Frame
		local title = toast:FindFirstChild("Text") :: TextLabel
		assert(title.Text == "4 Index rewards", "uigate: the Claim all toast's title reads " .. title.Text .. " (#2479)")
		local chips = 0
		local view = workspace.CurrentCamera.ViewportSize
		for _, chip in (toast:FindFirstChild("Rewards") :: Instance):GetChildren() do
			if chip:IsA("TextLabel") then
				chips += 1
				local left, right = chip.AbsolutePosition.X, chip.AbsolutePosition.X + chip.AbsoluteSize.X
				local bottom = chip.AbsolutePosition.Y + chip.AbsoluteSize.Y
				assert(left >= toast.AbsolutePosition.X - 1 and right <= toast.AbsolutePosition.X + toast.AbsoluteSize.X + 1, "uigate: a reward chip sticks out of its toast (#2479)")
				assert(bottom <= toast.AbsolutePosition.Y + toast.AbsoluteSize.Y + 1, "uigate: a reward chip hangs under its toast (#2479)")
				assert(left >= 0 and right <= view.X, "uigate: a reward chip runs off the screen (#2479)")
			end
		end
		assert(chips == 6, ("uigate: the Claim all toast shows %d chips, not 6 (#2479)"):format(chips))
	end },
	-- F99 section 2: a rainbow stray's once-a-minute toast on a turning rainbow edge
	{ "RainbowSpawn", function()
		UI.rainbowSpawned(firstArea(), Catalog.cats[10].id)
	end },
	{ "Potions", function()
		UI.open("Potions")
		-- #2588: the Bag window's corner badge is the HUD Bag tile's backpack, not a potion
		assert(badgeDraws("Potions", "88244676943674"), "uigate: the Bag window's badge is not the backpack (#2588)")
	end },
	-- #1281: the Bag's Bait tab: the bowl foods the player has, each with its picture, grade badge and count, no Use
	{ "BagBait", function()
		UI.update({ lures = { kibble = 12, tuna = 3, salmon = 1 } })
		UI.open("Potions")
		press("Potions", "BaitTab")
		local window = UIShim.playerGui:FindFirstChild("Potions", true)
		local list = window and window:FindFirstChild("BaitList", true)
		assert(list and list:IsA("GuiObject") and list.Visible, "uigate: the Bag's Bait list is not up")
		local tuna = list:FindFirstChild("tuna")
		assert(tuna, "uigate: no Tuna row on the Bait tab")
		local count = tuna:FindFirstChild("Count") :: TextLabel
		assert(count.Text == "x3", "uigate: Tuna count " .. count.Text)
		assert(list:FindFirstChild("Use", true) == nil, "uigate: the Bait tab has a Use button")
	end },
	-- #1616: the Bag's Cat food tab: each snack size shows its own picture, not the same star
	{ "BagFood", function()
		UI.update({ catFood = { small_cat_snack = 2, cat_snack = 3, big_cat_snack = 1, cat_feast = 1 } } :: any)
		UI.open("Potions")
		press("Potions", "FoodTab")
		local window = UIShim.playerGui:FindFirstChild("Potions", true)
		local list = window and window:FindFirstChild("FoodList", true)
		assert(list and list:IsA("GuiObject") and list.Visible, "uigate: the Bag's Cat food list is not up")
		local seen: { [string]: boolean } = {}
		for _, id in { "small_cat_snack", "cat_snack", "big_cat_snack", "cat_feast" } do
			local row = list:FindFirstChild(id)
			local glyph = row and row:FindFirstChild("Glyph", true) :: TextLabel?
			assert(glyph, "uigate: no " .. id .. " row on the Cat food tab")
			assert(not seen[glyph.Text], "uigate: two snacks share the picture " .. glyph.Text .. " (#1616)")
			seen[glyph.Text] = true
		end
	end },
	-- #1773: Feed's cat list as cards: two cats of one kind, a gold one and a rainbow one, each with its head, rarity
	-- and level line, a bar toward the next level and its own Feed. #1771: the tabs are gold when chosen.
	{ "BagFeed", function()
		local cats = {}
		local picks = {}
		for _, def in Catalog.cats do
			if def.area ~= "spare" and #picks < 3 then
				table.insert(picks, def)
			end
		end
		local function add(uid: string, def: any, variant: string, level: number, xp: number)
			cats[uid] = {
				uid = uid,
				catId = def.id,
				variant = variant,
				caughtAt = os.time() - 60,
				level = level,
				xp = xp,
				xpToNext = 40,
				charm = 50,
				stars = 3,
				rating = 12,
			}
		end
		add("gate_feed_1", picks[1], "base", 24, 300)
		add("gate_feed_2", picks[1], "base", 7, 20)
		add("gate_feed_3", picks[2], "gold", 15, 100)
		add("gate_feed_4", picks[3], "rainbow", 3, 5)
		UI.update({ cats = cats, catFood = { cat_snack = 3 } } :: any)
		UI.open("Potions")
		press("Potions", "FoodTab")
		press("Potions", "cat_snack.Feed")
		local window = UIShim.playerGui:FindFirstChild("Potions", true)
		local list = window and window:FindFirstChild("CatList", true)
		assert(list and list.Visible, "uigate: Feed's cat list is not up (#1773)")
		for index = 1, 4 do
			local card = list:FindFirstChild("gate_feed_" .. index)
			assert(card and card:IsA("Frame"), "uigate: no card for cat " .. index .. " (#1773)")
			assert(card:FindFirstChild("Head") and card:FindFirstChild("XpBar"), "uigate: cat card " .. index .. " has no head or bar (#1773)")
			assert(card:FindFirstChild("Feed", true), "uigate: cat card " .. index .. " has no Feed (#1773)")
		end
		local gold = list:FindFirstChild("gate_feed_3"):FindFirstChild("CatName")
		assert(string.sub(gold.Text, 1, 5) == "Gold ", "uigate: the gold cat's card reads " .. gold.Text .. " (#1773)")
		-- #2196 (playtester Tyrell: "going into the feed menu lags his game"): a state update and the once a second
		-- refresh keep every card (and its 3D head); a cat that gained XP gets a new card, the others stay
		local before: { [string]: Instance } = {}
		for index = 1, 4 do
			before[index] = list:FindFirstChild("gate_feed_" .. index)
		end
		UI.update({ money = 123456 })
		UIShim.advance(1.1)
		for index = 1, 4 do
			assert(list:FindFirstChild("gate_feed_" .. index) == before[index], "uigate: cat card " .. index .. " was made again on a refresh with nothing new (#2196)")
		end
		local fed = table.clone(cats)
		fed.gate_feed_2 = table.clone(cats.gate_feed_2)
		fed.gate_feed_2.xp = 32
		local line2 = before[2]:FindFirstChild("Level").Text
		UI.update({ cats = fed } :: any)
		local card2 = list:FindFirstChild("gate_feed_2")
		assert(card2 and card2:FindFirstChild("Level").Text ~= line2, "uigate: the fed cat's card kept its old XP (#2196)")
		assert(list:FindFirstChild("gate_feed_1") == before[1], "uigate: feeding one cat made another's card again (#2196)")
	end },
	-- #2196 (Derek2 11-07: "The food menu where you go to feed cats Lags the game so bad ... it should only render as
	-- you scroll"): with 300 cats only the cards in view (and a few each side) are made, each with one 3D head;
	-- scrolled half way the cats there have cards and the count stays small, and the canvas is as tall as every card
	{ "BagFeedMany", function()
		local defs = {}
		for _, def in Catalog.cats do
			if def.area ~= "spare" and #defs < 6 then
				table.insert(defs, def)
			end
		end
		local cats = {}
		for index = 1, 300 do
			local def = defs[(index % #defs) + 1]
			local uid = ("gate_many_%03d"):format(index)
			cats[uid] = {
				uid = uid,
				catId = def.id,
				variant = if index % 25 == 0 then "gold" elseif index % 40 == 0 then "rainbow" else "base",
				caughtAt = os.time() - index,
				level = 1 + (index % 45),
				xp = index,
				xpToNext = 40,
				charm = 50,
				stars = 3,
				rating = 12,
			}
		end
		UI.update({ cats = cats, catFood = { cat_snack = 3 } } :: any)
		UI.open("Potions")
		press("Potions", "FoodTab")
		press("Potions", "cat_snack.Feed")
		local window = UIShim.playerGui:FindFirstChild("Potions", true)
		local list = window and window:FindFirstChild("CatList", true)
		assert(list and list.Visible, "uigate: Feed's cat list is not up (#2196)")
		local function made(): (number, number)
			local cards, views = 0, 0
			for _, child in list:GetChildren() do
				if child:IsA("Frame") and child.Visible and child:FindFirstChild("XpBar") then
					cards += 1
				end
			end
			for _, view in list:GetDescendants() do
				if view:IsA("ViewportFrame") then
					views += 1
				end
			end
			return cards, views
		end
		local cards, views = made()
		print(("uigate: BagFeedMany at the top: %d cards, %d 3D heads for 300 cats"):format(cards, views))
		assert(cards > 0 and cards <= 20, "uigate: Feed made " .. cards .. " cards for 300 cats (#2196)")
		assert(views <= 24, "uigate: Feed holds " .. views .. " 3D heads for 300 cats (#2196)")
		local canvas = list.AbsoluteCanvasSize.Y
		local window2 = list.AbsoluteWindowSize.Y
		local scale = list:FindFirstChild("Title").AbsoluteSize.Y / 36
		assert(canvas >= 300 * 68 * scale, "uigate: the canvas (" .. canvas .. ") is not as tall as 300 cards (#2196)")
		list.CanvasPosition = Vector2.new(0, (canvas - window2) / 2)
		UIShim.advance(0.1)
		local seen = 0
		for _, child in list:GetChildren() do
			if child:IsA("Frame") and child.Visible and child:FindFirstChild("XpBar") then
				local top = child.AbsolutePosition.Y - list.AbsolutePosition.Y
				if top > -10 and top < window2 then
					seen += 1
				end
			end
		end
		assert(seen >= 3, "uigate: scrolled half way, only " .. seen .. " cards are in view (#2196)")
		cards, views = made()
		print(("uigate: BagFeedMany half way: %d cards, %d 3D heads, %d in view"):format(cards, views, seen))
		assert(cards <= 20 and views <= 24, "uigate: scrolling made " .. cards .. " cards (#2196)")
		list.CanvasPosition = Vector2.new(0, 0)
		UIShim.advance(0.1)
		local top = nil
		for _, child in list:GetChildren() do
			if child:IsA("Frame") and child.Visible and child:FindFirstChild("XpBar") then
				if top == nil or child.LayoutOrder < top.LayoutOrder then
					top = child
				end
			end
		end
		local line = top and top:FindFirstChild("Level").Text or ""
		assert(string.find(line, "Level 45", 1, true), "uigate: back at the top, the first card reads " .. line .. " (#2196)")
	end },
	{ "Quests", function()
		UI.open("Quests")
	end },
	-- #2528 (Derek2: "remove the quest line showing a brief summary under your goal"): no quest line under the goal
	-- card, and no pin on a quest's row (it only led that line, #1573)
	{ "QuestsNoLine", function()
		UI.open("Quests")
		local hud = UIShim.playerGui:FindFirstChild("CatCafeHUD")
		assert(hud and hud:FindFirstChild("QuestLine", true) == nil, "uigate: the HUD still has a quest line (#2528)")
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local window = modals and modals:FindFirstChild("Quests", true)
		assert(window, "uigate: no Quests window")
		assert(window:FindFirstChild("Pin", true) == nil, "uigate: a quest row still has a pin (#2528)")
	end },
	{ "QuestsWeekly", function()
		UI.open("Quests")
		press("Quests", "WeeklyTab")
	end },
	{ "QuestsAchievements", function()
		UI.open("Quests")
		press("Quests", "AchievementsTab")
		-- #2089: an achievement's crate draws its own crate's picture, never the retired "?" mystery box
		local crates = 0
		for _, d in UIShim.playerGui:GetDescendants() do
			if d:IsA("ImageLabel") or d:IsA("ImageButton") then
				assert(not string.find(d.Image, "76162414943592", 1, true), "uigate: " .. d:GetFullName() .. " draws the ? mystery box (#2089)")
				if string.find(d.Image, "81784091360384", 1, true) then
					crates += 1
				end
			end
		end
		assert(crates > 0, "uigate: no achievement shows the Classic Crate's picture (#2089)")
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
	-- #2070 (Derek2: "make pass xp also come from achievements and weeklys"): while a Cafe Pass season runs, a weekly
	-- quest shows its "+N pass XP" pill, and so does an achievement once its prize carries passXp
	{ "QuestsPassXp", function()
		local small = Scenes._achievementPrizes.S
		Scenes._passXp = { small = small.passXp }
		-- a season running, as the game sends it (the pass sets PrizeChips.passOpen)
		UI.pass.set({ season = 1, startsAt = 0, endsAt = 1798934400, level = 4, xp = 3500, xpPerLevel = 800,
			levels = 30, paid = false, claimedFree = {}, claimedPaid = {}, claimable = 0, items = {} })
		if small.passXp == nil then
			small.passXp = 50 -- Gameplay's #2070 amount, until its catalog change is on main
		end
		UI.open("Quests")
		local function pill(tab)
			press("Quests", tab)
			task.wait(0.2)
			-- (no sync: opening the pass alone must show the pills)
			task.wait(0.2)
			local page = UIShim.playerGui:FindFirstChild(
				if tab == "WeeklyTab" then "Weekly" else "Achievements",
				true
			)
			for _, d in (page or UIShim.playerGui):GetDescendants() do
				if d:IsA("TextLabel") and d.Visible and string.find(d.Text, "pass XP", 1, true) then
					return d.Text
				end
			end
			return nil
		end
		local weekly = pill("WeeklyTab")
		assert(weekly ~= nil, "uigate: a weekly quest shows no pass XP pill while the pass is open (#2070)")
		local achievement = pill("AchievementsTab")
		assert(achievement ~= nil, "uigate: an achievement with passXp shows no pass XP pill (#2070)")
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
	-- #2460: once the server says the rescue is done, the full-screen tap catcher goes so a phone can move again under
	-- the "Rescued!" banner; the next rescue has it back
	{ "RescueResultTapThrough", function()
		UI.rescue.show("gate_rescue", rescueChallenge())
		local barGui = UIShim.playerGui:FindFirstChild("CatCafeRescueBar")
		local tap = barGui and barGui:FindFirstChild("Tap")
		assert(tap and tap.Visible, "uigate: no tap catcher during the rescue (#2460)")
		local t = workspace:GetServerTimeNow()
		UI.rescue.update("gate_rescue", 3, 3, true, true, {
			zone = 3,
			startsAt = t,
			phase = 0.4,
			speed = 1,
			zoneEndsAt = t + 5,
		})
		local outcome = barGui:FindFirstChild("Outcome", true) :: TextLabel?
		assert(outcome and outcome.Text == "Rescued!", "uigate: no Rescued! banner (#2460)")
		assert(not tap.Visible, "uigate: the tap catcher still covers the screen after the rescue (#2460)")
		UIShim.advance(5)
		UI.rescue.show("gate_rescue", rescueChallenge())
		assert(tap.Visible, "uigate: the next rescue has no tap catcher (#2460)")
	end },
	-- #2219 (crispi_255): a rescuer two hits in misses; the server sends the bar back to the start (no hits, zone 1)
	-- and the flash says "MISS! Back to the start", whole, with every pip empty
	{ "RescueMissReset", function()
		UI.rescue.show("gate_rescue", rescueChallenge())
		local t = workspace:GetServerTimeNow()
		UI.rescue.update("gate_rescue", 2, 3, false, false, {
			zone = 3,
			startsAt = t,
			phase = 0.4,
			speed = 1.05,
			zoneEndsAt = t + 5,
		})
		UI.rescue.update("gate_rescue", 0, 2, false, false, {
			zone = 1,
			startsAt = t,
			phase = 0.4,
			speed = 0.9,
			zoneEndsAt = t + 5,
		})
		local barGui = UIShim.playerGui:FindFirstChild("CatCafeRescueBar")
		local word = barGui and barGui:FindFirstChild("Word", true)
		assert(word and word:IsA("TextLabel"), "uigate: no flash word on the rescue bar (#2219)")
		assert(word.Visible and word.Text == "MISS! Back to the start", "uigate: the reset flash reads " .. word.Text .. " (#2219)")
		assert(word.TextFits, "uigate: the reset flash is cut off (#2219)")
	end },
	-- #2318 (Derek2: "sometimes rescue's say miss even if you hit it properly"): a tap 0.02 of the bar past the zone's
	-- edge, where the marker sat 0.03 s ago, is a hit on the server (RescueMarker.SEEN_LAG), so the bar flashes NICE!
	{ "RescueSeenLag", function()
		local t = workspace:GetServerTimeNow()
		local challenge = rescueChallenge()
		-- zone 0.5 wide 0.1, tolerance 0.03: its right edge is 0.58; the marker at 0.60 now, moving right at 1 bar a second
		challenge.zones = { 0.5, 0.3, 0.7 }
		challenge.zoneWidth = 0.1
		challenge.startsAt = t - 0.5
		challenge.phase = 0.1
		challenge.speed = 1
		challenge.zone = 1
		UI.rescue.show("gate_rescue", challenge)
		local barGui = UIShim.playerGui:FindFirstChild("CatCafeRescueBar")
		UIShim.fire(UIShim.eventOf(barGui:FindFirstChild("Tap"), "InputBegan"), {
			UserInputType = Enum.UserInputType.Touch,
			Position = Vector3.new(400, 300, 0),
		})
		local word = barGui:FindFirstChild("Word", true) :: TextLabel
		assert(word.Visible and word.Text == "NICE!", "uigate: a tap just after the zone flashes " .. word.Text .. " (#2318)")
	end },
	-- F92: a Team Rescue helper's copy of the bar, two hits in: "Helping!" and the rescuer's paws
	{ "RescueHelper", function()
		local challenge = rescueChallenge()
		challenge.helper = true
		challenge.hits = 2
		challenge.zone = 3
		UI.rescue.show("gate_rescue", challenge)
	end },
	-- F92: the Team Rescue pop on the helper's screen, with the helper's tip
	{ "TeamRescue", function()
		UI.teamRescue(4242, localUserId(), 1240)
	end },
	-- F92: four pals on the server: three faces, "+1" and "+15% with pals" after the potion timer
	{ "HUDPals", function()
		local t = workspace:GetServerTimeNow()
		UI.update({ buffs = { tip_potion = t + 492 } })
		UI.pals({ 4242, 4343, 4444, 4545 })
	end },
	-- F92: a joiner whose pal is out in the first area: "Your pal is in the Alleyway" over the glowing Cannon
	{ "PalArrived", function()
		UI.palArrived(4242, firstArea())
	end },
	-- F84: the name card in the clouds at the top centre, held so the scene catches it (Derek 2026-11-03: the flying
	-- character shows below it)
	{ "CannonFlightCard", function()
		UI.cannon.flight("woods", workspace:GetServerTimeNow() - 1.6, 5)
	end },
	-- F92: the Cannon picker with that pal's tag on the area's card
	{ "CannonPal", function()
		UI.palArrived(4242, firstArea())
		UI.cannon.open()
	end },
	-- F92: the one invite nudge on the slide-in ask card
	{ "InviteAsk", function()
		UI.asks.show("invite_ask")
	end },
	-- F93: the touch Net button, in a catching area while a swing could go (phones only)
	{ "NetButton", function()
		UI.setZone("Alley")
		UI.net.setEnabled(true)
	end },
	-- #2510 (Derek2: "add a tackle button instead of the bar in the middle of screen for mobile/ipad players"): in a
	-- catching area on touch the Tackle is a round button left of the Net button, clear of the jump button, the Net
	-- button and the potion timers; a tap greys it with the seconds left. With a mouse it stays the bar.
	{ "TackleButton", function()
		local Scale = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Scale")
		local NetButtonPlace = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Components.NetButtonPlace")
		UI.setZone("Alley")
		UI.net.setEnabled(true)
		UI.shove.setEnabled(true)
		Scenes._tackle = true
		UIShim.advance(0.3)
		local gui = UIShim.playerGui:FindFirstChild("CatCafeTackle") :: ScreenGui
		assert(gui and gui.Enabled, "uigate: no Tackle in a catching area (#2510)")
		local button = gui:FindFirstChild("Tackle", true) :: TextButton
		assert(button and button.Visible, "uigate: no Tackle button (#2510)")
		local function box(object: GuiObject): (number, number, number, number)
			local at, size = object.AbsolutePosition, object.AbsoluteSize
			return at.X, at.Y, at.X + size.X, at.Y + size.Y
		end
		local function apart(a: GuiObject, b: GuiObject, what: string)
			local ax1, ay1, ax2, ay2 = box(a)
			local bx1, by1, bx2, by2 = box(b)
			local clear = ax2 <= bx1 + 0.5 or bx2 <= ax1 + 0.5 or ay2 <= by1 + 0.5 or by2 <= ay1 + 0.5
			assert(clear, "uigate: the Tackle button covers " .. what .. " (#2510)")
		end
		if not Scale.isTouch() then
			assert(button.AbsoluteSize.X > button.AbsoluteSize.Y * 3, "uigate: the mouse Tackle is not the bar (#2510)")
			return
		end
		local size = button.AbsoluteSize
		assert(math.abs(size.X - size.Y) < 1 and size.X >= 44, "uigate: the touch Tackle is not a round thumb-sized button (#2510)")
		local word = button:FindFirstChild("Word") :: TextLabel
		assert(word.Text == "TACKLE" and word.TextFits, "uigate: the Tackle button's word reads " .. word.Text .. " (#2510)")
		local net = UIShim.playerGui:FindFirstChild("CatCafeNetButton")
		local netButton = net and net:FindFirstChild("Net", true) :: GuiObject?
		assert(netButton and (net :: ScreenGui).Enabled, "uigate: no Net button beside the Tackle (#2510)")
		apart(button, netButton :: GuiObject, "the Net button")
		local ay = button.AbsolutePosition.Y
		assert(math.abs(ay - (netButton :: GuiObject).AbsolutePosition.Y) < 1, "uigate: the Tackle button is not level with Net (#2510)")
		local camera = workspace.CurrentCamera
		local jumpAt, jumpSize = NetButtonPlace.jump(camera.ViewportSize)
		local bx1, by1, bx2, by2 = box(button)
		local jumpClear = bx2 <= jumpAt.X or jumpAt.X + jumpSize <= bx1 or by2 <= jumpAt.Y or jumpAt.Y + jumpSize <= by1
		assert(jumpClear, "uigate: the Tackle button covers the jump button (#2510)")
		local hud = UIShim.playerGui:FindFirstChild("CatCafeHUD")
		local timers = hud and hud:FindFirstChild("PotionTimers", true) :: GuiObject?
		if timers and timers.Visible then
			apart(button, timers :: GuiObject, "the potion timers")
		end
		-- a tap: the grey covers it and the word counts the seconds
		UIShim.fire(UIShim.eventOf(button, "Activated"))
		UIShim.advance(0.2)
		local cool = button:FindFirstChild("Cool") :: Frame
		assert(cool.Visible and cool.Size.Y.Scale > 0.8, "uigate: the Tackle button did not grey after a tap (#2510)")
		assert(word.Text:match("^%ds$") ~= nil, "uigate: the recharging Tackle button reads " .. word.Text .. " (#2510)")
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
	-- #2332 (Derek2: "it should fully be only failing if the heart bar hits 0"): a catch with 30 rings keeps its strip
	-- to ten pips, inside the screen, and slides once the play passes the tenth
	{ "CatchLongStrip", function()
		local list = startCatch("gate_stray", "Mythical", 30, 0, 0.82)
		local layer = UIShim.playerGui:FindFirstChild("CatCafeCatchCircles")
		local strip = layer:FindFirstChild("Strip", true) :: Frame
		local function shown(): (number, number)
			local count, first = 0, nil
			for index = 1, #list do
				local pip = strip:FindFirstChild("Pip" .. index) :: Frame
				if pip.Visible then
					count += 1
					first = first or index
				end
			end
			return count, first or 0
		end
		local count, first = shown()
		assert(count == 10 and first == 1, ("uigate: a 30 ring catch shows %d pips from %d (#2332)"):format(count, first))
		assert(strip.AbsoluteSize.X < 300, "uigate: the 30 ring strip is " .. strip.AbsoluteSize.X .. " px wide (#2332)")
		-- the eleventh ring judged: the strip slides on by two
		UI.catch.judged("gate_stray", 11, "good")
		count, first = shown()
		assert(count == 10 and first == 3, ("uigate: after ring 11 the strip shows %d pips from %d (#2332)"):format(count, first))
	end },
	-- #1727: circle 1 hit, circle 2 pressed just past its Good band (a Miss on this device), then the server's
	-- CatchJudged calls that press Good: circles 3 and 4 never went away, so the catch goes on in view
	{ "CatchEdgeMiss", function()
		local list = startCatch("gate_stray", "Common", 4, 0.3, 0.82)
		local function art(index)
			local layer = UIShim.playerGui:FindFirstChild("CatCafeCatchCircles")
			local holder = layer and layer:FindFirstChild("Circle" .. index, true)
			return holder and holder:FindFirstChild("Art")
		end
		local function waitUntil(at)
			local wait = at - workspace:GetServerTimeNow()
			if wait > 0 then
				task.wait(wait)
			end
		end
		local function target(index)
			return list[index].startsAt + list[index].shrinkSeconds
		end
		waitUntil(target(1))
		tapCircles()
		waitUntil(target(2) + 0.12)
		tapCircles()
		task.wait(0.3)
		local third = art(3)
		assert(third and third.Visible, "CatchEdgeMiss: circle 3 went before the server's word on circle 2")
		UI.catch.judged("gate_stray", 2, "good")
		waitUntil(target(3) - 0.2)
		third = art(3)
		assert(third and third.Visible, "CatchEdgeMiss: circle 3 went after the server called circle 2 Good")
	end },
	-- F93: the result word over the strip once the server's grades land (three Perfects of four: EXCELLENT!)
	{ "CatchResult", function()
		startCatch("gate_stray", "Rare", 4, 1, 1)
		task.delay(1.8, function()
			UI.catch.showGrades("gate_stray", { "perfect", "good", "perfect", "perfect" }, true, 0)
		end)
	end },
	-- #2405 (Derek2: "for mobile people who need to click screen to move cant move for a second due to their screen
	-- being covered"): the full-screen tap catcher goes with the result, so the result word shows over a screen that
	-- moves again; the next catch brings it back
	{ "CatchResultTapThrough", function()
		startCatch("gate_tap", "Rare", 2, 1, 1)
		local layer = UIShim.playerGui:FindFirstChild("CatCafeCatchCircles")
		local tap = layer and layer:FindFirstChild("Tap")
		assert(tap and tap.Visible, "uigate: no tap catcher during the catch (#2405)")
		UI.catch.showGrades("gate_tap", { "perfect", "good" }, true, 0)
		assert(not tap.Visible, "uigate: the tap catcher still covers the screen after the catch (#2405)")
		UIShim.advance(3)
		startCatch("gate_tap2", "Rare", 2, 1, 1)
		assert(tap.Visible, "uigate: the next catch has no tap catcher (#2405)")
	end },
	-- Catch v3 (#1884, catch-rework.md 7b, 7c): the trust bar over the stray, no progress strip, a red paw ring with a
	-- paw print, and the bar moving to the server's trust from CatchJudged
	{ "CatchV3Trust", function()
		startCatchV3("gate_v3", "Legendary", { "single", "paw", "double", "double", "single" }, 2, 14)
		local layer = UIShim.playerGui:FindFirstChild("CatCafeCatchCircles")
		local strip = layer and layer:FindFirstChild("Strip", true)
		assert(strip and not strip.Visible, "uigate: Catch v3 still shows the progress strip (#1884)")
		local bar = UIShim.playerGui:FindFirstChild("CatchTrustBar")
		assert(bar and bar.Enabled and bar.Adornee ~= nil, "uigate: Catch v3 has no trust bar over the stray (#1884)")
		local paw = layer:FindFirstChild("Circle2", true)
		local number = paw and paw:FindFirstChild("Number", true)
		assert(number and number.Text == "🐾", "uigate: the paw ring has no paw print (#1884)")
		-- #2005: the whole paw ring red with "Don't swing!", and a double ring's second half in blue with "x2"
		local warning = paw:FindFirstChild("DontSwing", true)
		assert(warning and warning.Text == "Don't swing!", "uigate: the paw ring has no Don't swing! (#2005)")
		local good = paw:FindFirstChild("GoodBand", true)
		local goodStroke = good and good:FindFirstChildOfClass("UIStroke")
		assert(goodStroke and goodStroke.Color.R > 0.8 and goodStroke.Color.G < 0.4, "uigate: the paw ring's band isn't red (#2005)")
		local first, second = layer:FindFirstChild("Circle3", true), layer:FindFirstChild("Circle4", true)
		assert(first and first:FindFirstChild("Double", true) == nil, "uigate: the first half of a double has an x2 (#2005)")
		local tag = second and second:FindFirstChild("Double", true)
		assert(tag and tag.Text == "x2", "uigate: a double ring's second half has no x2 tag (#2005)")
		UI.catch.judged("gate_v3", 1, "perfect", 4)
		task.wait(0.4)
		local fill = bar:FindFirstChild("Fill", true)
		assert(fill and math.abs(fill.Size.X.Scale - 4 / 14) < 0.02, "uigate: the trust bar isn't at the server's trust (#1884)")
	end },
	-- #2005 section 4 (Derek2: "make it the entire circle not just the perfect line and have a don't swing! text"): a
	-- paw ring mid close, red all over with Don't swing! under it
	{ "CatchPawRing", function()
		startCatchV3("gate_paw", "Epic", { "single", "single", "single", "paw" }, 2, 14)
	end },
	-- #2005 section 4 ("the rapid rings are not clear"): both halves of a double ring closing, the second in blue, x2
	{ "CatchDoubleRing", function()
		startCatchV3("gate_double", "Epic", { "single", "single", "single", "double", "double" }, 2, 14)
	end },
	-- #2060 (Derek2: "move across the screen so not only do you have to time it but find the next one each time"):
	-- each ring at its own spot inside the safe box, away from the one before, the next one showing ahead of its turn,
	-- and a paw ring's Don't swing! on screen
	{ "CatchRingsMove", function()
		local list = startCatchV3("gate_move", "Epic", { "single", "single", "paw", "single", "single" }, 2, 14)
		local layer = UIShim.playerGui:FindFirstChild("CatCafeCatchCircles")
		local view = layer.AbsoluteSize
		local root = layer:FindFirstChild("Root")
		local top, size = root.AbsolutePosition, root.AbsoluteSize
		local function centre(index)
			local holder = layer:FindFirstChild("Circle" .. index, true)
			return holder and holder.AbsolutePosition, holder
		end
		local last = nil
		for index = 1, #list do
			local at = centre(index)
			assert(at, "uigate: ring " .. index .. " was not drawn (#2060)")
			local x, y = (at.X - top.X) / size.X, (at.Y - top.Y) / size.Y
			assert(
				x > 0.25 and x < 0.75 and y > 0.35 and y < 0.65 and at.Y > view.Y * 0.2 and at.Y < view.Y * 0.75,
				"uigate: ring " .. index .. " sits outside the safe box (#2060) at " .. tostring(at)
			)
			if last then
				local moved = math.abs(at.X - last.X) >= size.X * 0.15 or math.abs(at.Y - last.Y) >= size.Y * 0.11
				assert(moved, "uigate: ring " .. index .. " sits on the last ring's spot (#2060)")
			end
			last = at
		end
		-- the lead-in: ring 2 shows at its spot while ring 1 is still closing
		local wait = list[1].startsAt + list[1].shrinkSeconds - 0.15 - workspace:GetServerTimeNow()
		if wait > 0 then
			task.wait(wait)
		end
		local _, second = centre(2)
		assert(second and second.Visible, "uigate: the next ring doesn't show ahead of its turn (#2060)")
		local warning = layer:FindFirstChild("Circle3", true):FindFirstChild("DontSwing", true)
		local bottom = warning.AbsolutePosition.Y + warning.AbsoluteSize.Y
		assert(bottom < view.Y - 8, "uigate: the paw ring's Don't swing! runs off the screen (#2060)")
	end },
	-- Catch v3 (#1884, 7d): a Purrfect catch's banner (Root.FinishBanner, after the net wrap); #2464: no HUD streak
	{ "CatchV3Finish", function()
		startCatchV3("gate_v3f", "Common", { "single", "single", "single" }, 2, 8)
		task.wait(0.4)
		UI.catch.showGrades("gate_v3f", { "perfect", "perfect", "perfect" }, true, 0, nil,
			{ trust = 8, trustNeed = 8, finish = "purrfect", streak = 3 })
		task.wait(0.75)
		local layer = UIShim.playerGui:FindFirstChild("CatCafeCatchCircles")
		local banner = layer and layer:FindFirstChild("FinishBanner", true)
		assert(banner and banner.Visible and banner.Text == "PURRFECT!", "uigate: no PURRFECT! banner after the wrap (#1884)")
		-- #2464: no streak text over the money any more, it pushed the top row down
		assert(UIShim.playerGui:FindFirstChild("PurrfectStreak", true) == nil, "uigate: the Purrfect x3 text is back (#2464)")
	end },
	-- Catch v3 (#1884): UIController's way in: the circles first, then UI.catch.trust; a Miss doesn't end it; then
	-- UI.catch.finished just before the grades
	{ "CatchV3Hooks", function()
		startCatchV3("gate_v3h", "Rare", { "single", "single", "single", "single", "single" }, nil, nil)
		UI.catch.trust("gate_v3h", 2, 10)
		local bar = UIShim.playerGui:FindFirstChild("CatchTrustBar")
		assert(bar and bar.Enabled, "uigate: UI.catch.trust didn't show the trust bar (#1884)")
		UI.catch.judged("gate_v3h", 1, "miss", 0)
		task.wait(0.3)
		local layer = UIShim.playerGui:FindFirstChild("CatCafeCatchCircles")
		local second = layer and layer:FindFirstChild("Circle2", true)
		local art = second and second:FindFirstChild("Art")
		assert(art and art.Visible, "uigate: a Miss ended a Catch v3 try (#1884)")
		UI.catch.finished("gate_v3h", { trust = -1, trustNeed = 10, finish = "bolt", streak = 0 })
		UI.catch.showGrades("gate_v3h", { "miss", "miss" }, false, 0)
		task.wait(0.2)
		local banner = layer:FindFirstChild("FinishBanner", true)
		assert(banner and banner.Visible and banner.Text == "So close!", "uigate: a bolt doesn't read So close! (#1884)")
	end },
	-- Catch v3 (#1884, 7d): NICE! in cream for a catch with a Miss in it
	{ "CatchV3Nice", function()
		startCatchV3("gate_v3n", "Rare", { "single", "single", "single", "single", "single" }, 2, 10)
		task.wait(0.4)
		UI.catch.showGrades("gate_v3n", { "perfect", "miss", "good", "perfect", "perfect" }, true, 0, nil,
			{ trust = 10, trustNeed = 10, finish = "nice", streak = 0 })
		task.wait(0.75)
		local layer = UIShim.playerGui:FindFirstChild("CatCafeCatchCircles")
		local banner = layer and layer:FindFirstChild("FinishBanner", true)
		assert(banner and banner.Visible and banner.Text == "NICE!", "uigate: no NICE! banner (#1884)")
		assert(UIShim.playerGui:FindFirstChild("PurrfectStreak", true) == nil, "uigate: the Purrfect x3 text is back (#2464)")
	end },
	-- 2026-11-03 (Derek: "too much text on screen make pictures easy for kids"): the prompt cards with no hint line,
	-- a little picture of the minigame in its place: a stuck cat's rescue bar, a stray's catch ring
	{ "CatchPromptRescue", function()
		UI.catch.show({
			strayId = "gate_stuck",
			catId = Catalog.cats[2].id,
			catName = "Garbage Bag Cat",
			rarity = "Rare",
			kind = "rescue",
			holdDuration = 0.5,
		})
	end },
	-- #2315 (Derek2: "make sure mobile players have a way of doing rescue instead of holding e since they cant"): when
	-- Roblox says the prompt is pressed by touch, the card offers its big RESCUE button even on a device that also
	-- reports a keyboard (every profile here, the desktop ones included), and no "[E] HOLD" key cap
	{ "CatchPromptRescueTouch", function()
		UI.catch.show({
			strayId = "gate_stuck",
			catId = Catalog.cats[2].id,
			catName = "Garbage Bag Cat",
			rarity = "Rare",
			kind = "rescue",
			holdDuration = 0.5,
			touch = true,
		} :: any)
		local gui = UIShim.playerGui:FindFirstChild("CatCafeCatch") or UIShim.playerGui
		local grab = gui:FindFirstChild("Grab", true) :: TextButton
		assert(grab and grab.Visible, "uigate: no RESCUE button for a touch prompt (#2315)")
		local label = grab:FindFirstChild("Label", true) :: TextLabel
		assert(label and label.Text == "RESCUE", "uigate: the touch button reads " .. (if label then label.Text else "nothing"))
		local key = gui:FindFirstChild("Key", true) :: GuiObject?
		assert(key == nil or not key.Visible, "uigate: the [E] key cap still shows for a touch prompt (#2315)")
		-- #2409 (Derek2: "rescue button is overlapping net button on mobile"): on a phone the button takes the Net
		-- button's spot, the Net button steps away meanwhile, and neither lands on Roblox's jump button
		if not UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Scale").isTouch() then
			return
		end
		local NetButtonPlace = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Components.NetButtonPlace")
		UI.setZone("Alley")
		UI.net.setEnabled(true)
		UIShim.advance(0.3)
		local net = UIShim.playerGui:FindFirstChild("CatCafeNetButton") :: ScreenGui
		assert(net and not net.Enabled, "uigate: the Net button shows under the RESCUE button (#2409)")
		local viewport = workspace.CurrentCamera.ViewportSize
		local netAt, netSize = NetButtonPlace.place(viewport)
		local jumpAt = NetButtonPlace.jump(viewport)
		local inset = game:GetService("GuiService"):GetGuiInset()
		local x0, y0 = grab.AbsolutePosition.X + inset.X, grab.AbsolutePosition.Y + inset.Y
		assert(math.abs(x0 - netAt.X) <= 2 and math.abs(y0 - netAt.Y) <= 2, ("uigate: the RESCUE button is at %d,%d, not the Net button's %d,%d (#2409)"):format(x0, y0, netAt.X, netAt.Y))
		assert(math.abs(grab.AbsoluteSize.X - netSize) <= 2, "uigate: the RESCUE button is not the Net button's size (#2409)")
		assert(y0 + grab.AbsoluteSize.Y <= jumpAt.Y, "uigate: the RESCUE button runs onto the jump button (#2409)")
		assert(label.TextFits, "uigate: RESCUE does not fit its button (#2409)")
		UI.net.setEnabled(false)
	end },
	{ "CatchPromptCatch", function()
		UI.catch.show({
			strayId = "gate_stray",
			catId = Catalog.cats[2].id,
			catName = "Mochi",
			rarity = "Epic",
			holdDuration = 0.5,
		})
	end },
	-- #2324 (Derek2: "make it a brief text message and not long ex: 'cooling down 1 second'"): after a miss the card
	-- counts the wait down in one short line, rounded up, on one line on every profile
	{ "CatchPromptCooldown", function()
		UI.catch.show({
			strayId = "gate_cooldown",
			catId = Catalog.cats[2].id,
			catName = "Mochi",
			rarity = "Epic",
			holdDuration = 0.5,
			retryAt = workspace:GetServerTimeNow() + 3.2,
		})
		local action = UIShim.playerGui:FindFirstChild("CatCafeCatch"):FindFirstChild("Action", true) :: TextLabel
		assert(action.Text == "Cooling down 4s", "uigate: the card after a miss reads " .. action.Text .. " (#2324)")
		assert(action.TextFits, "uigate: Cooling down 4s does not fit the catch card (#2324)")
		local hint = UIShim.playerGui:FindFirstChild("CatCafeCatch"):FindFirstChild("Hint", true) :: TextLabel?
		assert(hint == nil or not hint.Visible, "uigate: the cooldown card still has a hint line (#2324)")
	end },
	-- #2340 (Derek2: "make pretty much all buttons in the game a one click confirm instead of hold"): a prompt with no
	-- hold (a rescue since #2344, the Index boards since this) shows no HOLD tag on its card
	{ "CatchPromptNoHold", function()
		UI.catch.show({
			strayId = "gate_stuck",
			catId = Catalog.cats[2].id,
			catName = "Garbage Bag Cat",
			rarity = "Rare",
			kind = "rescue",
			holdDuration = 0,
		})
		local card = UIShim.playerGui:FindFirstChild("CatCafeCatch")
		local hold = card:FindFirstChild("Hold", true) :: GuiObject?
		assert(hold == nil or not hold.Visible, "uigate: a one press prompt still says HOLD (#2340)")
	end },
	-- F87: a context tip's card at the top centre, its bar draining
	{ "TipCard", function()
		UI.tips.show("second_cat")
	end },
	-- #2282 (Derek2: "on the persons first perfect catch have a quick side tip that explains it boosts their charm"):
	-- a catch whose Perfects added Charm brings the tip card with the Charm line, once; a Perfect-less catch does not
	{ "PerfectCharmTip", function()
		local before: any = (UI.getState() :: any).tipsSeen or {}
		-- every other tip seen, so no client-found tip (the luck chip's, the Codes Cat's) takes the card or restarts
		-- the gap while the scene waits
		local tipsSeen = table.clone(before)
		for _, def in UIShim.require("ReplicatedStorage.Shared.Tips").LIST do
			tipsSeen[def.id] = true
		end
		tipsSeen.perfect = nil
		UI.update({ tipsSeen = tipsSeen } :: any)
		local seen: { string } = {}
		local counting = UI.events.tipSeen:Connect(function(id: string)
			table.insert(seen, id)
		end)
		local function charmLine(): TextLabel?
			for _, label in UIShim.playerGui:GetDescendants() do
				if label:IsA("TextLabel") and label.Text:find("Charm", 1, true) and label.Text:find("Perfects", 1, true) then
					return label
				end
			end
			return nil
		end
		UIShim.advance(tipGap() + 1) -- past TipGapSeconds after the TipCard scene's tip, so the queue may show the next one
		UI.catch.showGrades("uigate_stray", { "good", "good" }, true, 0)
		UIShim.advance(1)
		assert(charmLine() == nil, "uigate: a catch with no Perfect showed the Charm tip (#2282)")
		UI.catch.showGrades("uigate_stray", { "perfect", "good" }, true, 2)
		UIShim.advance(4)
		local line = charmLine()
		assert(line and line.Visible, "uigate: the first Perfect catch did not show the Charm tip (#2282)")
		assert(line.Text == "Perfects boost a cat's Charm, and more Charm earns more money!", "uigate: the Charm tip reads " .. line.Text)
		assert(line.TextFits, "uigate: the Charm tip's line does not fit its card (#2282)")
		UIShim.advance(12)
		assert(table.find(seen, "perfect"), "uigate: the Charm tip was not saved as seen (#2282)")
		counting:Disconnect()
		UI.update({ tipsSeen = before } :: any)
	end },
	-- #2408 (Derek2: "because of so many pop ups on cafe tier up its hard to see the cutscene showing next place
	-- unlocked"): the rank up's camera cut (a stand-in cut player here): the HUD steps aside, a toast sent meanwhile
	-- waits, and both come back when the cut ends
	{ "RankUpCutQuiet", function()
		local before: any = (UI.getState() :: any).tipsSeen or {}
		local tipsSeen = table.clone(before)
		for _, def in UIShim.require("ReplicatedStorage.Shared.Tips").LIST do
			tipsSeen[def.id] = true
		end
		tipsSeen.rank_up = nil
		UI.update({ tipsSeen = tipsSeen } :: any)
		local cut: { started: boolean, done: ((boolean) -> ())? } = { started = false, done = nil }
		UI.tips.setCutPlayer(function(id: string, _caption: string, _seconds: number, done: (boolean) -> ()): boolean
			if id ~= "rank_up" then
				return false
			end
			cut.started = true
			cut.done = done
			return true
		end)
		UIShim.advance(tipGap() + 1) -- past TipGapSeconds after an earlier scene's tip
		UI.tips.show("rank_up")
		UIShim.advance(1)
		assert(cut.started, "uigate: the rank up cut never played (#2408)")
		local hud = UIShim.playerGui:FindFirstChild("CatCafeHUD") :: ScreenGui
		assert(not hud.Enabled, "uigate: the HUD stays over the rank up cut (#2408)")
		local line = "Your cafe is now a Cozy Cafe! Two new role slots are ready"
		UI.toast(line, "good")
		task.wait(0.2)
		local function toastUp(): boolean
			for _, piece in UIShim.playerGui:GetDescendants() do
				if piece.Name == "Toast" and piece:GetAttribute("Line") == line then
					local gui = piece:FindFirstAncestorOfClass("ScreenGui")
					return gui ~= nil and gui.Enabled
				end
			end
			return false
		end
		assert(not toastUp(), "uigate: a toast drew over the rank up cut (#2408)")
		local done = cut.done :: (boolean) -> ()
		done(false)
		task.wait(0.2)
		assert(hud.Enabled, "uigate: the HUD did not come back after the cut (#2408)")
		assert(toastUp(), "uigate: the toast held over the cut never showed (#2408)")
		UI.tips.setCutPlayer(nil)
		UI.update({ tipsSeen = before } :: any)
	end },
	-- #2302 (Derek2: "add tackling somewhere in tutorial or something if it's not already"): the "tackle them" card,
	-- with the key or button for this device, on one card that fits, saved as seen
	{ "TackleTryTip", function()
		local before: any = (UI.getState() :: any).tipsSeen or {}
		local tipsSeen = table.clone(before)
		for _, def in UIShim.require("ReplicatedStorage.Shared.Tips").LIST do
			tipsSeen[def.id] = true
		end
		tipsSeen.tackle_try = nil
		UI.update({ tipsSeen = tipsSeen } :: any)
		local seen: { string } = {}
		local counting = UI.events.tipSeen:Connect(function(id: string)
			table.insert(seen, id)
		end)
		UIShim.advance(tipGap() + 1) -- past TipGapSeconds after an earlier scene's tip
		UI.tips.show("tackle_try")
		UIShim.advance(1)
		local line: TextLabel? = nil
		for _, label in UIShim.playerGui:GetDescendants() do
			if label:IsA("TextLabel") and label.Text:find("tackle them and grab their cat", 1, true) then
				line = label
			end
		end
		assert(line and line.Visible, "uigate: the tackle_try tip did not show (#2302)")
		local text = (line :: TextLabel).Text
		assert(
			text == "Press Q to tackle them and grab their cat!"
				or text == "Tap Tackle to tackle them and grab their cat!"
				or text == "Press Y to tackle them and grab their cat!",
			"uigate: the tackle_try tip reads " .. text .. " (#2302)"
		)
		assert((line :: TextLabel).TextFits, "uigate: the tackle_try tip's line does not fit its card (#2302)")
		assert(table.find(seen, "tackle_try"), "uigate: the tackle_try tip was not saved as seen (#2302)")
		counting:Disconnect()
		UI.update({ tipsSeen = before } :: any)
	end },
	-- #2477 (Derek2: "the tutorial should guide you to cannon after bait bowl"): the walk-through ending this session
	-- (step 4, the bowl, to 5) puts "Hop in the cannon to catch more cats!" on the tutorial strip, with the arrow
	{ "CannonAfterBowl", function()
		UI.cannon.setWild(nil)
		UI.update({ tutorialStep = 4, tier = 2 } :: any)
		UI.update({ tutorialStep = 5 } :: any)
		task.wait(0.1)
		local hud = UIShim.playerGui:FindFirstChild("CatCafeHUD", true) :: Instance
		local texts: { string } = {}
		for _, piece in hud:GetDescendants() do
			if piece.Name == "Tutorial" and piece:IsA("TextLabel") and piece.Visible then
				table.insert(texts, piece.Text)
			end
		end
		assert(
			table.find(texts, "Hop in the cannon to catch more cats!"),
			"uigate: the tutorial strip after the bowl reads " .. table.concat(texts, " | ") .. " (#2477)"
		)
		UI.cannon.wrapUp.on = false -- as a flight clears it, so later scenes keep their own lines
		UI.update({ tutorialStep = 9 } :: any)
	end },
	-- #2198 (Derek2: "a forced cut scene after first catch"): the server's tackle tip plays as the tackling lesson on
	-- the intro's screen: four captions with four dots, the read bar and Next, no Skip; it ends by itself and saves
	-- the tip as seen
	{ "TackleLesson", function()
		local seen: { string } = {}
		local counting = UI.events.tipSeen:Connect(function(id: string)
			table.insert(seen, id)
		end)
		local before: any = (UI.getState() :: any).tipsSeen or {}
		local tipsSeen = table.clone(before)
		tipsSeen.tackle_lesson = nil -- #2409: the lesson has its own tip id
		UI.update({ tipsSeen = tipsSeen } :: any)
		-- #2312: IntroController's stager, as it hands it over, takes the camera for each caption and gives it back
		local staged: { number } = {}
		UI.intro.setTackleStager(function(shot: number)
			table.insert(staged, shot)
		end)
		UI.tips.show("tackle_lesson")
		UIShim.advance(0.5)
		assert(UI.intro.playing(), "uigate: the tackle tip did not start the lesson (#2198)")
		local gui = UIShim.playerGui:FindFirstChild("CatCafeIntro") :: ScreenGui
		local caption = gui:FindFirstChild("Caption", true) :: TextLabel
		local skip = gui:FindFirstChild("Skip", true) :: GuiObject
		local nextPill = gui:FindFirstChild("Next", true) :: TextButton
		assert(caption.Text == "Other players can tackle you while you carry!", "uigate: the lesson opens on " .. caption.Text .. " (#2198)")
		assert(caption.TextFits, "uigate: the lesson's first caption does not fit (#2198)")
		assert(not skip.Visible, "uigate: the lesson has a Skip (#2198)")
		assert(nextPill.Visible, "uigate: the lesson has no Next (#2198)")
		local dots = 0
		for _, dot in (gui:FindFirstChild("Dots", true) :: Instance):GetChildren() do
			if dot:IsA("Frame") and dot.Visible then
				dots += 1
			end
		end
		assert(dots == 4, ("uigate: the lesson shows %d dots, not 4 (#2198)"):format(dots))
		UIShim.advance(0.6)
		UIShim.fire(UIShim.eventOf(nextPill, "Activated"))
		assert(caption.Text == "Get tackled and you drop your cat!", "uigate: Next did not move the lesson on (#2198)")
		assert(#seen == 0, "uigate: the lesson was saved as seen before it ended (#2198)")
		assert(gui:FindFirstChild("TackleCue", true) == nil, "uigate: the Tackle cue shows before its caption (#2469)")
		-- #2469: the third caption shows the Tackle bar with this device's key and presses it as the lunge starts
		UIShim.advance(1.1)
		UIShim.fire(UIShim.eventOf(nextPill, "Activated"))
		local cue = gui:FindFirstChild("TackleCue", true) :: Frame?
		assert(cue and cue.Visible, "uigate: no Tackle bar on the lesson's third caption (#2469)")
		local key = cue:FindFirstChild("Key") :: TextLabel?
		local Logic = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Components.TackleLessonLogic")
		local Scale = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Scale")
		if Scale.isTouch() then
			assert(key == nil, "uigate: the touch Tackle cue has a key cap (#2469)")
		else
			assert(key and key.Text == Logic.cueKey("keyboard"), "uigate: the Tackle cue's key cap is wrong (#2469)")
		end
		assert(cue:GetAttribute("Pressed") == nil, "uigate: the Tackle cue pressed before the lunge (#2469)")
		local cueTop = cue.AbsolutePosition.Y + cue.AbsoluteSize.Y
		assert(cueTop <= caption.AbsolutePosition.Y + 1, "uigate: the Tackle cue overlaps the caption (#2469)")
		UIShim.advance(1.0)
		assert(cue:GetAttribute("Pressed") == true, "uigate: the Tackle cue was not pressed as the lunge starts (#2469)")
		UIShim.advance(1.1)
		UIShim.fire(UIShim.eventOf(nextPill, "Activated"))
		assert(gui:FindFirstChild("TackleCue", true) == nil, "uigate: the Tackle cue stays on the last caption (#2469)")
		UIShim.advance(20)
		assert(not UI.intro.playing(), "uigate: the lesson did not end by itself (#2198)")
		assert(#seen == 1 and seen[1] == "tackle_lesson", "uigate: the lesson's end did not save the tackle tip as seen (#2198)")
		local shots = table.concat(staged, ",")
		assert(shots == "1,2,3,4,0", "uigate: the lesson staged the camera as " .. shots .. ", not 1,2,3,4,0 (#2312)")
		UI.intro.setTackleStager(nil)
		counting:Disconnect()
		UI.update({ tipsSeen = before } :: any)
	end },
	-- F87: the first long return, the offline tip's ribbon on the card (the client tips marked seen, so no stuck cat
	-- or Codes Cat tip pops up in later scenes)
	{ "OfflineTip", function()
		UI.update({ tipsSeen = { stuck_cat = true, codes_cat = true } })
		UI.showOfflineEarnings(48200, 3 * 3600)
		-- an ask (the invite nudge) waits for the Welcome back card (Studio run 2026-11-07)
		assert(not UI.tips.quiet(), "uigate: an ask could slide in under the Welcome back card")
		-- #2137: the dim behind the card covers the whole screen, the top bar's strip too
		local dim = UIShim.playerGui:FindFirstChild("CatCafePopupsDim")
		local backdrop = dim and dim:FindFirstChild("Backdrop") :: GuiObject?
		assert(dim and (dim :: ScreenGui).Enabled and backdrop, "uigate: no dim behind the Welcome back card (#2137)")
		local screen = workspace.CurrentCamera.ViewportSize
		assert((backdrop :: GuiObject).AbsolutePosition.Y <= 0 and (backdrop :: GuiObject).AbsoluteSize.Y >= screen.Y - 1, ("uigate: the dim starts at y %d, %d tall, not the whole %d (#2137)"):format((backdrop :: GuiObject).AbsolutePosition.Y, (backdrop :: GuiObject).AbsoluteSize.Y, screen.Y))
	end },
	-- #2157 (Desktop-Tester on #2128): a replay asked for with Settings open and the Welcome back card up closes
	-- Settings at once and collects the earnings, so the card never comes back after the intro
	{ "IntroReplayTidy", function()
		UI.update({ tipsSeen = { stuck_cat = true, codes_cat = true } })
		local claimed = 0
		local counting = UI.events.claimOffline:Connect(function()
			claimed += 1
		end)
		UI.showOfflineEarnings(48200, 3 * 3600)
		UI.open("Settings")
		assert(UI.isOpen() == "Settings", "uigate: Settings did not open")
		UI.events.introReplay:Fire()
		assert(UI.isOpen() == nil, "uigate: Settings stays open on a replay (#2157)")
		assert(claimed == 1, ("uigate: the replay collected the earnings %d times, not once (#2157)"):format(claimed))
		UIShim.advance(1)
		local popups = UIShim.playerGui:FindFirstChild("CatCafePopups")
		local card = popups and popups:FindFirstChild("Offline", true) :: GuiObject?
		assert(card == nil or not card.Visible, "uigate: the Welcome back card is still up after a replay (#2157)")
		UI.events.introReplay:Fire()
		assert(claimed == 1, "uigate: a second replay collected again (#2157)")
		counting:Disconnect()
	end },
	-- #2182 (intro-cutscene.md 2b): with a hold, Next just left of Skip and the gold read bar under the caption; a
	-- press in a shot's first second does nothing, then one press moves on once
	-- #2242 (Derek2 11-07: "add the rare customers chance to the tutorial scene like rich customer tips"): the rich
	-- visitor shot's caption fits one line, and the grab's gold "+$" pops over the bag and is gone by 1.6 s
	{ "IntroRichTip", function()
		UI.intro.start({ skipAfter = 5 })
		UI.intro.setShot(6, "Rich visitors leave big tips. Grab them fast!", nil, 4.2)
		local gui = UIShim.playerGui:FindFirstChild("CatCafeIntro") :: ScreenGui
		local caption = gui:FindFirstChild("Caption", true) :: TextLabel
		assert(caption.TextFits, "uigate: the rich visitor caption does not fit (#2242)")
		local camera = workspace.CurrentCamera
		local bag = camera.CFrame.Position + camera.CFrame.LookVector * 20
		UI.intro.tipPop(bag, 2400)
		UIShim.advance(0.3)
		-- the shim's camera puts every world point behind it, so the pop is made but hidden; its words are checked
		local pop = gui:FindFirstChild("TipPop", true) :: TextLabel
		assert(pop ~= nil, "uigate: no tip pop over the bag (#2242)")
		assert(pop.Text == "+$2,400" and pop.TextFits, "uigate: the tip pop reads " .. pop.Text .. " (#2242)")
		UIShim.advance(1.5)
		assert(gui:FindFirstChild("TipPop", true) == nil, "uigate: the tip pop stayed past 1.6 s (#2242)")
	end },
	-- #2702 (Derek2 11-09: "make the tutorial cutscene skip button more obvious maybe one quick flash on the bottom right
	-- when its ready" and "fix the black bar on the top of screen for mobile so it just shows the dots"): as Skip's bar
	-- fills it flashes once with a gold ring spreading out; on touch there is no top bar and the dots sit near the top
	{ "IntroSkipFlash", function()
		UI.intro.start({ skipAfter = 5 })
		UI.intro.setShot(2, "Fly the Cat Cannon to catch stray cats!", nil, 4.2)
		local gui = UIShim.playerGui:FindFirstChild("CatCafeIntro") :: ScreenGui
		local skip = gui:FindFirstChild("Skip", true) :: TextButton
		assert(skip:FindFirstChild("Flash") == nil, "uigate: Skip flashed before its bar filled (#2702)")
		UIShim.advance(5.1)
		assert(skip:FindFirstChild("Flash"), "uigate: Skip did not flash as it turned ready (#2702)")
		local ring = gui:FindFirstChild("SkipRing", true) :: GuiObject?
		assert(ring, "uigate: no gold ring spreading from Skip (#2702)")
		local touch = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Scale").isTouch()
		local top = gui:FindFirstChild("TopBar") :: Frame
		assert(top.Visible == not touch, ("uigate: the top bar shows %s on %s (#2702)"):format(tostring(top.Visible), if touch then "touch" else "desktop"))
		local dot = gui:FindFirstChild("Dot2", true) :: Frame
		local root = gui:FindFirstChild("Root") :: Frame -- the whole screen (the shim measures under Roblox's top bar)
		local y = dot.AbsolutePosition.Y - root.AbsolutePosition.Y
		assert(y >= 0 and y + dot.AbsoluteSize.Y <= 48, ("uigate: the shot dot sits %d px from the top, not near it (#2702)"):format(y))
		UIShim.advance(0.2) -- mid ring, for the picture
	end },
	{ "IntroNext", function()
		local fired: { number } = {}
		local counting = UI.events.introNext:Connect(function(shot: number)
			table.insert(fired, shot)
		end)
		UI.intro.start({ skipAfter = 5 })
		UI.intro.setShot(1, "Fly the Cat Cannon to catch stray cats!", nil, 4.2)
		UIShim.advance(1)
		local gui = UIShim.playerGui:FindFirstChild("CatCafeIntro") :: ScreenGui
		assert(gui and gui.Enabled, "uigate: no intro screen (#2182)")
		local nextPill = gui:FindFirstChild("Next", true) :: TextButton
		local skip = gui:FindFirstChild("Skip", true) :: TextButton
		local tap = gui:FindFirstChild("Tap", true) :: TextButton
		local read = gui:FindFirstChild("ReadBar", true) :: Frame
		local caption = gui:FindFirstChild("Caption", true) :: TextLabel
		local bottom = gui:FindFirstChild("BottomBar") :: Frame
		assert(nextPill and nextPill.Visible and tap and tap.Visible, "uigate: no Next on a shot with a hold (#2182)")
		local label = nextPill:FindFirstChild("Label") :: TextLabel
		assert(label.Text == "Next ›" and label.TextFits, "uigate: Next reads " .. label.Text .. " or does not fit (#2182)")
		assert(math.abs(nextPill.AbsoluteSize.Y - skip.AbsoluteSize.Y) < 1, "uigate: Next is not Skip's height (#2182)")
		assert(math.abs(nextPill.AbsolutePosition.Y - skip.AbsolutePosition.Y) < 1, "uigate: Next is not level with Skip (#2182)")
		assert(nextPill.AbsolutePosition.X + nextPill.AbsoluteSize.X < skip.AbsolutePosition.X, "uigate: Next runs into Skip (#2182)")
		assert(nextPill.AbsolutePosition.X >= 0, "uigate: Next runs off the screen (#2182)")
		assert(read.Visible, "uigate: no read bar on a shot with a hold (#2182)")
		assert(read.AbsolutePosition.Y >= caption.AbsolutePosition.Y + caption.AbsoluteSize.Y - 1, "uigate: the read bar is not under the caption (#2182)")
		assert(read.AbsolutePosition.Y + read.AbsoluteSize.Y <= bottom.AbsolutePosition.Y + 1, "uigate: the read bar sits on the lower bar (#2182)")
		-- #2394 (Derek2: "the bottom just takes up a lot of space that could be camera"): on touch no lower bar; the
		-- caption and its read bar sit over Skip and Next, which stay inside the screen
		if UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Scale").isTouch() then
			assert(not bottom.Visible, "uigate: the lower bar shows on touch (#2394)")
			assert(read.AbsolutePosition.Y + read.AbsoluteSize.Y <= skip.AbsolutePosition.Y, "uigate: the read bar runs onto Skip and Next (#2394)")
			assert(caption.AbsolutePosition.Y + caption.AbsoluteSize.Y <= skip.AbsolutePosition.Y, "uigate: the caption runs onto Skip and Next (#2394)")
			local screenBottom = gui.AbsoluteSize.Y
			assert(skip.AbsolutePosition.Y + skip.AbsoluteSize.Y <= screenBottom - 12, "uigate: Skip sits on the bottom edge (#2394)")
		else
			assert(bottom.Visible, "uigate: no lower bar on a PC (#2394)")
		end
		-- a press in the first second of a shot does nothing (the shim's os.clock runs with UIShim.advance; its tweens end at once,
		-- so the bar's fill is not checked here)
		UI.intro.setShot(2, "Boom! Every area starts at a safe camp", nil, 4.2)
		UIShim.fire(UIShim.eventOf(nextPill, "Activated"))
		assert(#fired == 0, "uigate: Next moved on in a shot's first second (#2182)")
		UIShim.advance(1.05)
		UIShim.fire(UIShim.eventOf(tap, "Activated"))
		UIShim.fire(UIShim.eventOf(nextPill, "Activated"))
		assert(#fired == 1 and fired[1] == 2, ("uigate: a tap after a second fired introNext %d times (#2182)"):format(#fired))
		counting:Disconnect()
	end },
	-- #2123 (first-hour.md 6a): the welcome back card with the reason to play today under the coins, the card taller
	-- by the line and Collect still clear of the note
	{ "WelcomeBackHook", function()
		Scenes._returnHook = true
		UI.update({ tipsSeen = { stuck_cat = true, codes_cat = true }, returnHook = { kind = "treat", day = 2 } } :: any)
		UI.showOfflineEarnings(48200, 3 * 3600)
		local popups = UIShim.playerGui:FindFirstChild("CatCafePopups")
		local card = popups and popups:FindFirstChild("Offline", true) :: Frame?
		assert(card and card.Visible, "uigate: no welcome back card (#2123)")
		local hook = card:FindFirstChild("Hook") :: TextLabel
		local amount = card:FindFirstChild("Amount") :: TextLabel
		local note = card:FindFirstChild("Note") :: TextLabel
		local claim = card:FindFirstChild("Claim", true) :: GuiObject
		assert(hook and hook.Visible and hook.Text == "Daily Treat day 2 is ready", "uigate: the welcome back hook line reads " .. tostring(hook and hook.Text) .. " (#2123)")
		assert(hook.TextFits, "uigate: the welcome back hook line does not fit (#2123)")
		assert(hook.AbsolutePosition.Y >= amount.AbsolutePosition.Y + amount.AbsoluteSize.Y - 1, "uigate: the hook line is not under the coins (#2123)")
		assert(note.AbsolutePosition.Y >= hook.AbsolutePosition.Y + hook.AbsoluteSize.Y - 1, "uigate: the note sits on the hook line (#2123)")
		local claimTop = claim.AbsolutePosition.Y
		assert(note.AbsolutePosition.Y + note.TextBounds.Y <= claimTop + 1, "uigate: the note runs into Collect (#2123)")
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
	-- #1796: tutorial step 3 asks for a table: the HUD's Upgrades tile and the table row in Upgrades glow; step 4 moves
	-- the glow to the Bait bowl row
	{ "TutorialUpgradeGlow", function()
		local levels = { tables = 0, lure_bowl = 0, espresso = 0, net = 0, lucky_cat = 0 }
		UI.update({ tutorialStep = 3, tier = 1, upgradeLevels = levels } :: any)
		UI.tutorial.show(UI.tutorial.hint({ tutorialStep = 3, tier = 1, cats = {}, upgradeLevels = levels }))
		local hud = UIShim.playerGui:FindFirstChild("CatCafeHUD")
		local tile = hud and hud:FindFirstChild("Upgrades", true)
		assert(tile and tile:FindFirstChild("TutorialGlow", true), "uigate: the Upgrades tile does not glow at step 3 (#1796)")
		UI.open("Upgrades")
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local window = modals and modals:FindFirstChild("Upgrades", true)
		local tables = window and window:FindFirstChild("tables", true)
		local bowl = window and window:FindFirstChild("lure_bowl", true)
		assert(tables and tables:FindFirstChild("TutorialGlow"), "uigate: the table row does not glow at step 3 (#1796)")
		assert(bowl and bowl:FindFirstChild("TutorialGlow") == nil, "uigate: the Bait bowl row glows at step 3 (#1796)")
		UI.update({ tutorialStep = 4 } :: any)
		assert(tables:FindFirstChild("TutorialGlow") == nil, "uigate: the table row still glows at step 4 (#1796)")
		assert(bowl:FindFirstChild("TutorialGlow"), "uigate: the Bait bowl row does not glow at step 4 (#1796)")
		task.wait(0.1) -- the list scrolls the Bait bowl row into view
	end },
	-- #2314 (Derek2: "also show big arrow on screen temporarily pointing toward what to click next"): step 3's big
	-- arrow points at the HUD's Upgrades tile, whole on screen and off the tile; with Upgrades open it moves to the
	-- table row; the step done, it is gone
	{ "TutorialArrow", function()
		tutorialArrowStep()
		local tile = UIShim.playerGui:FindFirstChild("CatCafeHUD"):FindFirstChild("Upgrades", true)
		assertArrowAt(tile:FindFirstChild("TutorialGlow", true).Parent :: GuiObject, "the Upgrades tile")
	end },
	{ "TutorialArrowRow", function()
		tutorialArrowStep()
		UI.open("Upgrades")
		task.wait(0.2) -- the list scrolls the table row into view
		local window = UIShim.playerGui:FindFirstChild("CatCafeModals"):FindFirstChild("Upgrades", true)
		assertArrowAt(window:FindFirstChild("tables", true) :: GuiObject, "the table row")
	end },
	{ "TutorialArrowGone", function()
		-- the sample cafe's money can make its rank up ready, and then the goal card's own arrow (#2331) comes and goes
		-- on a timer, so whether it shows here depended on how long the scenes before took: no rank up ready while
		-- this checks, so only the tutorial step's arrow counts
		local money = (UI.getState() :: any).money
		UI.update({ money = 0 } :: any)
		tutorialArrowStep()
		-- money 0 keeps the rank up from being ready, so the goal card's own arrow (#2331) never stands in for the
		-- tutorial's: whether it was ready came from whichever scenes ran before this one in its shard
		local money = (UI.getState() :: any).money
		UI.update({ tutorialStep = 5, money = 0 } :: any)
		task.wait(0.1)
		for _, piece in UIShim.playerGui:GetDescendants() do
			assert(
				not (piece.Name == "TutorialArrow" and piece:IsA("GuiObject") and piece.Visible),
				"uigate: the tutorial arrow stays after its step (#2314)"
			)
		end
		UI.update({ money = money } :: any)
	end },
	-- #2331 (Derek2: "cozy cafe (tier up cafe) is more obviously your main goal to tier up and maybe flash and point
	-- towards it when tier up is ready"): the goal card's gold "YOUR GOAL" line over the bigger tier name, its edge
	-- pulsing and the big arrow at it while the rank up is ready; opening the rank up card stops both until the rank
	-- up is ready again
	{ "GoalCardReady", function()
		local before: any = UI.getState()
		Scenes._goalBefore = { tier = before.tier, money = before.money, tutorialStep = before.tutorialStep }
		UI.update({ tier = 3, tutorialStep = 9, money = 0 } :: any)
		task.wait(0.1) -- the HUD draws the not ready state before the next update
		UI.update({ money = 2e9 } :: any) -- ready again just now, so the arrow's first showing starts here
		task.wait(0.1)
		local goal = UIShim.playerGui:FindFirstChild("TierGoal", true) :: GuiObject
		assert(goal:FindFirstChild("RankReady").Visible, "uigate: the sample cafe's rank up is not ready (#2331)")
		local line = goal:FindFirstChild("Goal") :: TextLabel
		assert(line.Visible and line.Text == "🏆 YOUR GOAL", "uigate: the goal card has no YOUR GOAL line (#2331)")
		local title = goal:FindFirstChild("Title") :: TextLabel
		assert(title.Visible and title.TextFits, "uigate: the goal card's tier name does not fit (#2331)")
		assertArrowAt(goal, "the goal card")
	end },
	{ "GoalCardSeen", function()
		local goal = UIShim.playerGui:FindFirstChild("TierGoal", true) :: GuiObject
		UI.open("RankUp")
		UI.close()
		UI.update({ money = 2e9 + 1 } :: any)
		task.wait(0.1)
		local function arrowShows(): boolean
			for _, piece in UIShim.playerGui:GetDescendants() do
				if piece.Name == "TutorialArrow" and piece:IsA("GuiObject") and piece.Visible then
					return true
				end
			end
			return false
		end
		assert(not arrowShows(), "uigate: the arrow still points at the goal card after the rank up card opened (#2331)")
		local edge = goal:FindFirstChild("Border") :: UIStroke
		assert(edge.Thickness < 3, "uigate: the goal card still pulses after the rank up card opened (#2331)")
		assert(goal:FindFirstChild("RankReady").Visible, "uigate: the Rank up! sticker went with the arrow (#2331)")
		-- not ready, then ready again: the arrow is back
		UI.update({ money = 0 } :: any)
		task.wait(0.1)
		UI.update({ money = 2e9 } :: any)
		task.wait(0.1)
		assertArrowAt(goal, "the goal card, ready again")
		local was = Scenes._goalBefore
		Scenes._goalBefore = nil
		UI.update({ tier = was.tier, money = was.money, tutorialStep = was.tutorialStep } :: any)
	end },
	-- #2211 (crispi_255): the tutorial's last step done: the Tutorial tile's red × gets a gold ring and bounces for
	-- a few seconds, then is plain again; a player who finished it before (no step change) gets no pulse
	{ "TutorialDoneX", function()
		local hud = UIShim.playerGui:FindFirstChild("CatCafeHUD")
		local dot: Instance? = nil
		for _, piece in (hud :: Instance):GetDescendants() do
			if piece.Name == "Dot" and piece.Parent and piece.Parent.Name == "Hide" then
				dot = piece
			end
		end
		assert(dot, "uigate: no × on the Tutorial tile (#2211)")
		UI.update({ tutorialStep = 9 } :: any)
		UIShim.advance(6.5) -- the scene before may leave the tutorial mid-way, which this update just finished
		UI.update({ tutorialStep = 9 } :: any)
		assert(dot:FindFirstChild("PulseRing") == nil, "uigate: the × pulses with no tutorial step done (#2211)")
		UI.update({ tutorialStep = 4 } :: any)
		UI.update({ tutorialStep = 9 } :: any)
		assert(dot:FindFirstChild("PulseRing"), "uigate: the × does not pulse when the tutorial ends (#2211)")
		-- #2411 (Derek2: "the highlight to remove the tutorial/tips after finishing tutorial is missing and the X isn't
		-- obvious"): a gold "Hide tips with ×" tag beside the tile while it pulses, whole on the screen, and the × at
		-- least 21 px across
		local function hint(): TextLabel?
			return (hud :: Instance):FindFirstChild("HideHint", true) :: TextLabel?
		end
		UIShim.advance(1) -- the icon row settles
		local tag = hint()
		assert(tag and tag.Visible and tag.TextFits, "uigate: no Hide tips tag by the Tutorial tile's × (#2411)")
		local screen = ((hud :: Instance) :: ScreenGui).AbsoluteSize
		local t0, t1 = tag.AbsolutePosition, tag.AbsolutePosition + tag.AbsoluteSize
		assert(t0.X >= 0 and t1.X <= screen.X, "uigate: the Hide tips tag runs off the screen (#2411)")
		local across = (dot :: GuiObject).AbsoluteSize.X
		assert(across >= 21 - 0.5, ("uigate: the Tutorial tile's × is %.1f px across (#2411)"):format(across))
		UIShim.advance(6.5)
		assert(dot:FindFirstChild("PulseRing") == nil, "uigate: the ×'s pulse does not end (#2411)")
		assert(dot:FindFirstChild("Pulse") == nil, "uigate: the ×'s bounce does not end (#2211)")
		assert(hint() == nil, "uigate: the Hide tips tag does not go (#2411)")
		-- #2411: a tutorial that ends with the HUD off the screen (a cut, a cutscene) pulses once it is back
		UI.setVisible(false)
		UI.update({ tutorialStep = 4 } :: any)
		UI.update({ tutorialStep = 9 } :: any)
		UIShim.advance(1)
		assert(dot:FindFirstChild("PulseRing") == nil, "uigate: the × pulsed with the HUD hidden (#2411)")
		UI.setVisible(true)
		UIShim.advance(0.5)
		assert(dot:FindFirstChild("PulseRing"), "uigate: the × did not pulse once the HUD came back (#2411)")
		UIShim.advance(6.5)
		UI.update({ tutorialStep = 4 } :: any)
		UI.update({ tutorialStep = 9 } :: any) -- again, for the picture
		UIShim.advance(1)
	end },
	-- F87 section 2g: "Need a hand?" after 90 s on one tutorial step
	{ "HelpCard", function()
		UI.tutorial.showHelp()
	end },
	{ "CatFound", function()
		UI.showCatFound(Catalog.cats[2].id, true)
	end },
	-- #2530: a new Park cat's reveal has no "Park N / M" area count any more (#1919)
	{ "CatFoundArea", function()
		local def = missingCat("park")
		UI.showCatFound(def.id, true)
		local pill = UIShim.playerGui:FindFirstChild("CatCafePopups"):FindFirstChild("AreaCount", true)
		assert(pill == nil, "uigate: the new-cat reveal still shows an area count (#2530)")
	end },
	-- F99: a rainbow cat's card: NEW RAINBOW ... CAT! and a turning rainbow edge
	{ "CatFoundRainbow", function()
		UI.showCatFound(Catalog.cats[2].id, true, { rainbow = true })
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
	-- #1897: the first wow cat's card, "YOUR FIRST EPIC!", and the same cat's first Epic card (SecuredRare) right
	-- after it plays nothing more. The smaller card closes at 2 s, so it starts 0.9 s in to be up when the gate looks
	{ "BigPullWow", function()
		local epic = nil
		for _, def in Catalog.cats do
			if def.rarity == "Epic" then
				epic = def.id
				break
			end
		end
		assert(epic, "uigate: no Epic cat in the catalog")
		task.delay(0.9, function()
			-- BaitReady first, then FirstWow(rarity, first): the card takes the bowl cat of that rarity for its portrait
			UI.bait.showReady({ catId = epic }, 1)
			UI.bait.wow("Epic", true)
			UI.securedRare(localUserId(), epic, "Epic", false, nil)
			local pull = UIShim.playerGui:FindFirstChild("CatCafeBigPull")
			local word = pull and pull:FindFirstChild("Word", true)
			assert(word and word.Text == "YOUR FIRST EPIC!", "uigate: the wow card reads " .. tostring(word and word.Text))
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
	-- F103: a Classic Crate's reel 2.2 s in, slowing towards a Common on tile 34 under the gold marker
	{ "CrateReel", function()
		reel(true)
		UI.market.open()
		task.delay(0.3, function()
			UI.market.result("classic_crate", "classic_latte_brown", false, 0)
		end)
	end },
	-- #2246: "Tap to skip" under the strip while it rolls, and Space skips it as a tap does
	{ "CrateReelSkipKey", function()
		reel(true)
		UI.market.open()
		UI.market.result("classic_crate", "classic_latte_brown", false, 0)
		UIShim.advance(0.2)
		local hint = UIShim.playerGui:FindFirstChild("FishMarket", true):FindFirstChild("SkipHint", true)
		assert(hint and hint.Visible, "uigate: no Tap to skip on the rolling reel (#2246)")
		local input = { KeyCode = Enum.KeyCode.Space, UserInputType = Enum.UserInputType.Keyboard }
		UIShim.fire(UIShim.eventOf(game:GetService("UserInputService"), "InputBegan"), input, false)
		assert(not hint.Visible, "uigate: Space did not skip the reel (#2246)")
	end },
	-- a tap skips it: the landing, then the prize card with its buttons
	{ "CrateReelSkip", function()
		reel(true)
		UI.market.open()
		task.delay(0.3, function()
			UI.market.result("classic_crate", "classic_latte_brown", false, 0)
		end)
		task.delay(0.6, function()
			press("FishMarket", "ReelCover")
		end)
	end },
	-- last, since no window closes it: the money's boosts card with a Money Potion running and some boosts bought
	{ "HUDBoosts", function()
		UI.pals({ 4242 }) -- F92: one pal on the server, so the card has the Pals row
		local t = workspace:GetServerTimeNow()
		UI.update({
			buffs = { tip_potion = t + 492, swift_potion = t + 130 },
			fishPerks = { golden_espresso = 2 },
		})
		press("CatCafeHUD", "Counters.Money")
		local away = UIShim.playerGui:FindFirstChild("Away", true) :: TextLabel?
		assert(away and away.Visible and string.find(away.Text, "earn while away", 1, true), "uigate: no away line on the money card (#2621)")
	end },
	-- #1624: the same card for a player with VIP, Cafe Style, both outfit passes and 2x Money: three more rows
	{ "HUDBoostsPasses", function()
		UI.pals({ 4242 })
		local t = workspace:GetServerTimeNow()
		UI.update({
			buffs = { tip_potion = t + 492, swift_potion = t + 130 },
			fishPerks = { golden_espresso = 2 },
			passBoosts = { cafe = 0.6, staff = 1.3225, rich = 1.25, money = 2 },
		})
		press("CatCafeHUD", "Counters.Money")
		-- #2147: each outfit pass on its own row by name, "+15%", in place of "Outfit passes x1.32"
		local hud = UIShim.playerGui:FindFirstChild("CatCafeHUD")
		local named: { [string]: boolean } = {}
		for _, label in (hud :: Instance):GetDescendants() do
			if label:IsA("TextLabel") and label.Visible then
				for _, name in { "Cat Accessories", "Uniform Styles" } do
					if string.find(label.Text, name, 1, true) then
						assert(label.TextFits, "uigate: the " .. name .. " boost row does not fit (#2147)")
						named[name] = true
					end
				end
				assert(not string.find(label.Text, "Outfit passes", 1, true), "uigate: the money card still says Outfit passes (#2147)")
			end
		end
		assert(named["Cat Accessories"] and named["Uniform Styles"], "uigate: the money card names no outfit pass (#2147)")
	end },
	-- #2090 (Derek2: "add an arrow to hide potion effects ... a lot of screen clutter"): four potions running, so the
	-- row has the arrow tab; a tap folds them into one "x4" chip, a tap on that brings them back; the shot is folded
	{ "HUDPotionsFold", function()
		local t = workspace:GetServerTimeNow()
		UI.update({
			buffs = { tip_potion = t + 492, swift_potion = t + 130, lucky_potion = t + 492, steady_potion = t + 300 },
		})
		local timers = UIShim.playerGui:FindFirstChild("PotionTimers", true)
		assert(timers and timers.Visible, "uigate: no potion timers row (#2090)")
		local function chips()
			local count = 0
			for _, child in timers:GetChildren() do
				if child:IsA("TextButton") and child.Name ~= "Fold" and child.Name ~= "Folded" and child.Visible then
					count += 1
				end
			end
			return count
		end
		-- #2396 (Derek2: "make sure potion list defaults to closed down on every join"): the row starts folded
		assert(timers.Folded.Visible and chips() == 0, "uigate: the potion row does not start folded (#2396)")
		press("CatCafeHUD", "PotionTimers.Folded")
		local running = chips()
		assert(running >= 2, "uigate: the scene needs two or more potions running (#2090)")
		assert(timers.Fold.Visible, "uigate: no arrow tab with " .. running .. " potions running (#2090)")
		press("CatCafeHUD", "PotionTimers.Fold")
		assert(chips() == 0 and timers.Folded.Visible, "uigate: the arrow did not fold the potions away (#2090)")
		assert(timers.Folded.Count.Text == "x" .. running, "uigate: the folded chip says " .. timers.Folded.Count.Text .. " (#2090)")
		assert(not timers.Fold.Visible, "uigate: the arrow tab shows while folded (#2090)")
		press("CatCafeHUD", "PotionTimers.Folded")
		assert(chips() == running and not timers.Folded.Visible, "uigate: the folded chip did not bring the potions back (#2090)")
		press("CatCafeHUD", "PotionTimers.Fold") -- folded for the shot
		Scenes._potionsFolded = timers
	end },
	-- F88: a Lucky Day with a Lucky Potion running: the Luck chip with gold text at the start of the potion row, its card
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
		-- #1776: one line of what Luck does to each rarity, no next cat or next crate odds
		local hud = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("CatCafeHUD")
		local boost = hud:FindFirstChild("Boost", true)
		assert(boost and boost.Visible, "uigate: the Luck card shows no rarity pills (#1776)")
		for _, rarity in { "Epic", "Legendary", "Mythical" } do
			local pill = boost:FindFirstChild(rarity)
			local want = rarity .. " +130%"
			assert(pill and pill.Text == want, "uigate: the Luck card's " .. rarity .. " pill reads " .. tostring(pill and pill.Text) .. " (#1776)")
		end
		assert(hud:FindFirstChild("FoodOdds", true) == nil, "uigate: the Luck card still lists the next cat's odds (#1776)")
		-- #2079: the card's rows read "+50%", not "+0.5"
		local rowText = {}
		for _, d in hud:GetDescendants() do
			if d:IsA("TextLabel") and d.Visible and d.Text == "+50%" then
				table.insert(rowText, d.Text)
			end
		end
		assert(#rowText > 0, "uigate: the Luck card's Lucky Day row doesn't read +50% (#2079)")
		-- #2084: the clover sits left of the day line's first letter, never over it
		local line = hud:FindFirstChild("LuckyDay", true)
		-- #2416: the clover and the words share a row; the words start at their label's left edge
		local clover = line and line.Parent and line.Parent:FindFirstChild("Clover")
		assert(line and line.Visible and clover and clover.Visible, "uigate: no Lucky Day line with its clover (#2084)")
		local cloverRight = clover.AbsolutePosition.X + clover.AbsoluteSize.X
		local textLeft = line.AbsolutePosition.X
		assert(cloverRight <= textLeft + 1, ("uigate: the clover ends at %d, over the day line's words from %d (#2084)"):format(cloverRight, textLeft))
	end },
	-- F88: the night before a Lucky, Golden and Rainbow Day, LuckyDayWarnSeconds before sunrise: "Triple Day soon!"
	-- over the three names, on a small phone too (#1572; no countdown line under the clock since #1572), the Luck card from the scene before closed
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
		UI.luckyDay("warning", "A Lucky Day starts at sunrise!", { lucky = true, golden = true, rainbow = true })
		-- #1572: the warning names every kind tomorrow brings
		local found = false
		for _, d in UIShim.playerGui:GetDescendants() do
			if d:IsA("TextLabel") and d.Text == "Triple Day soon!" then
				found = true
			end
		end
		assert(found, "uigate: the sunrise warning doesn't say tomorrow is a Triple Day (#1572)")
	end },
	-- #2453: the Bag tile is a backpack, not the Potions tile's bottle (nor the gold money bag)
	{ "HUDBagBackpack", function()
		local ShopIcons = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Components.ShopIcons")
		local bag = ShopIcons.hud("Bag")
		assert(bag == "rbxassetid://88244676943674", "uigate: the Bag tile is not Model-Agent's backpack (#2453)")
		assert(bag ~= ShopIcons.hud("Potion"), "uigate: the Bag tile shows the Potions bottle (#2453)")
		assert(ShopIcons.backup(bag) == nil, "uigate: the Bag's backpack falls back to another picture (#2453)")
		assert(bag ~= ShopIcons.clean("Bag"), "uigate: the Bag tile shows the gold money bag (#2453)")
	end },
	-- #1737: the Night Market banner at nightfall with the market cart's picture left of the title (was a moon emoji)
	{ "NightMarketBanner", function()
		local AreaTitle = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Screens.AreaTitle")
		local ShopIcons = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Components.ShopIcons")
		local picture = ShopIcons.hud("NightMarket")
		assert(picture ~= nil, "NightMarketBanner: no Night Market picture")
		local card = AreaTitle.new(UIShim.playerGui)
		card:banner(
			"night_market",
			"The Night Market is open!",
			"Rare foods tonight at the dealer's cart in town.",
			UI.Theme.colors.berry,
			6,
			picture
		)
	end },
	-- #1572: a Lucky, Golden and Rainbow Day at once: "Lucky · Golden · Rainbow Day" under the clock, its card open
	{ "HUDDayKinds", function()
		local t = workspace:GetServerTimeNow()
		local clock = Instance.new("Folder")
		clock.Name = "Clock"
		clock:SetAttribute("Phase", "day")
		clock:SetAttribute("PhaseEndsAt", t + 190)
		clock:SetAttribute("AreasOpen", true)
		clock:SetAttribute("Day", 9)
		clock:SetAttribute("LuckyDay", true)
		clock:SetAttribute("GoldenDay", true)
		clock:SetAttribute("RainbowDay", true)
		UI.clock.bind(clock)
		task.wait(0.1)
		local hud = UIShim.playerGui:FindFirstChild("CatCafeHUD")
		local line = hud and hud:FindFirstChild("LuckyDay", true) :: TextLabel
		assert(line and line.Visible, "uigate: no day line under the clock")
		assert(line.Text == "Lucky · Golden · Rainbow Day", "uigate: day line " .. line.Text)
		press("CatCafeHUD", "LuckyDay.Tap")
		local card = hud:FindFirstChild("DayCard", true) :: Frame
		assert(card and card.Visible, "uigate: the day card did not open")
		-- #1572 (1h): the pity sign's two lines on the day card too
		local pity = card:FindFirstChild("Pity") :: TextLabel
		assert(pity and string.find(pity.Text, "Legendary cat in", 1, true), "uigate: the day card has no pity lines (#1572)")
		assert(string.find(pity.Text, "Mythical cat in", 1, true), "uigate: the day card has no Mythical line (#1572)")
	end },
	-- F100: the Cannon picker with the Tier 3 player's camp extras: the Picnic Basket ready (red dot), the Yard Sale's
	-- new crates (no dot)
	{ "CannonExtras", function()
		UI.campExtras.update(campExtras(1, false))
		UI.cannon.open()
	end },
	-- F100: the same picker with nothing ready: "Next in 2 h 10 m" and "New crates in 3 h"
	{ "CannonExtrasWait", function()
		UI.campExtras.update(campExtras(0, true))
		UI.cannon.open()
	end },
	-- #1463: a Golden Pond owner with 14 fish in the pond: Collect on the Woods strip in place of the red dot
	{ "CannonPondCollect", function()
		local extras = campExtras(0, true)
		extras.pond = { open = true, held = 14 }
		UI.update({ tier = 4 }) -- the Woods (and its pond) open at Tier 4; Scenes.close puts Tier 3 back
		game:GetService("Players").LocalPlayer:SetAttribute("GoldenPondPass", true)
		UI.campExtras.update(extras)
		UI.cannon.open()
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local window = modals and modals:FindFirstChild("Cannon", true)
		local shown = false
		for _, piece in (window and window:GetDescendants()) or {} do
			if piece.Name == "Collect" and piece:IsA("GuiObject") and piece.Visible then
				shown = true
			end
		end
		assert(shown, "uigate: no Collect on the pond strip for a Golden Pond owner (#1463)")
	end },
	-- F100: the Yard Sale card, the Classic Crate bought today and the Park Crate for 40 golden fish
	{ "YardSale", function()
		local extras = campExtras(0, false)
		extras.yardSale.stock[1].bought = true
		extras.yardSale.held = 1
		UI.campExtras.update(extras)
		UI.campExtras.openYardSale(extras.yardSale)
	end },
	-- #1200: the Garden Nursery at Tier 3: owned pieces read Owned, the rest Buy with the price, Tier 4 and 5 pieces
	-- "Opens at Tier 4"; then its Fences tab
	{ "LawnStall", function()
		UI.nursery.open("pieces")
	end },
	{ "LawnStallFences", function()
		UI.nursery.open("fence")
	end },
	-- #1052: the Corner Shop with every line: a Swift Potion left, snacks part bought, no Big Snack, a whistle sold out
	{ "CornerShop", function()
		UI.cornerShop.setStock({
			window = 5000000,
			restocksAt = workspace:GetServerTimeNow() + 192,
			snackXp = 4800,
			stock = {
				{ itemId = "swift_potion", price = 2400, amount = 3, bought = 1 },
				{ itemId = "cat_snack", price = 6000, amount = 2, bought = 1 },
				{ itemId = "big_cat_snack", price = 24000, amount = 0, bought = 0 },
				{ itemId = "cat_feast", price = 12000, amount = 1, bought = 0 },
				{ itemId = "cat_whistle", price = 18000, amount = 1, bought = 1 },
			},
		})
		UI.cornerShop.open()
	end },
	-- #1281: the three bait foods at the Corner Shop: their clean pictures and grade badges, "You have n" from the
	-- player's lures, Salmon sold out
	{ "CornerShopBait", function()
		UI.update({ money = 100000, tier = 2, lures = { kibble = 4, tuna = 1 } })
		UI.cornerShop.setStock({
			window = 5000000,
			restocksAt = workspace:GetServerTimeNow() + 192,
			snackXp = 0,
			stock = {
				{ itemId = "swift_potion", price = 2400, amount = 3, bought = 1 },
				{ itemId = "kibble", price = 200, amount = 3, bought = 0 },
				{ itemId = "tuna", price = 1000, amount = 2, bought = 1 },
				{ itemId = "salmon", price = 5000, amount = 1, bought = 1 },
			},
		})
		UI.cornerShop.open()
		local window = UIShim.playerGui:FindFirstChild("CornerShop", true)
		assert(window, "no Corner Shop window")
		local kibble = window:FindFirstChild("kibble", true)
		assert(kibble, "no kibble row")
		local effect = kibble:FindFirstChild("Effect", true) :: TextLabel
		assert(effect.Text == "Bait for your bowl · You have 4", "kibble effect: " .. effect.Text)
		local salmon = window:FindFirstChild("salmon", true)
		assert(salmon, "no salmon row")
		local salmonEffect = salmon:FindFirstChild("Effect", true) :: TextLabel
		assert(salmonEffect.Text == "Bait for your bowl · You have 0", "salmon effect: " .. salmonEffect.Text)
	end },
	-- #1599: the whole Day Cart in stock, grouped under Potions, Cat food and Bait, in the compact rows
	{ "CornerShopSections", function()
		UI.update({ money = 6000, tier = 3, lures = { kibble = 2 } })
		UI.cornerShop.setStock({
			window = 5000001,
			restocksAt = workspace:GetServerTimeNow() + 192,
			snackXp = 0,
			stock = {
				{ itemId = "swift_potion_small", price = 700, amount = 0, bought = 0 },
				{ itemId = "swift_potion", price = 1400, amount = 1, bought = 1 },
				{ itemId = "swift_potion_big", price = 2100, amount = 2, bought = 0 },
				{ itemId = "steady_potion_small", price = 2800, amount = 0, bought = 0 },
				{ itemId = "steady_potion", price = 3500, amount = 1, bought = 0 },
				{ itemId = "steady_potion_big", price = 4200, amount = 2, bought = 0 },
				{ itemId = "quick_bait_potion_small", price = 4900, amount = 0, bought = 1 },
				{ itemId = "quick_bait_potion", price = 5600, amount = 1, bought = 0 },
				{ itemId = "quick_bait_potion_big", price = 6300, amount = 2, bought = 0 },
				{ itemId = "cat_whistle_small", price = 7000, amount = 0, bought = 0 },
				{ itemId = "cat_whistle", price = 7700, amount = 1, bought = 0 },
				{ itemId = "cat_whistle_big", price = 8400, amount = 2, bought = 1 },
				{ itemId = "small_cat_snack", price = 9100, amount = 0, bought = 0 },
				{ itemId = "cat_snack", price = 9800, amount = 1, bought = 0 },
				{ itemId = "big_cat_snack", price = 10500, amount = 2, bought = 0 },
				{ itemId = "cat_feast", price = 11200, amount = 0, bought = 0 },
				{ itemId = "kibble", price = 11900, amount = 1, bought = 1 },
				{ itemId = "tuna", price = 12600, amount = 2, bought = 0 },
				{ itemId = "salmon", price = 13300, amount = 0, bought = 0 },
			},
		})
		UI.cornerShop.open()
		local window = UIShim.playerGui:FindFirstChild("CornerShop", true)
		assert(window, "no Corner Shop window")
		for _, kind in { "potion", "food", "bait" } do
			assert(window:FindFirstChild("Section_" .. kind, true), "no section " .. kind)
		end
	end },
	-- #2593 (Derek2: a Buy all for each Day Cart section): a real window's stock, so the shared planAll and the rows
	-- agree. Each section with something to buy has Buy all; its card lists the plan, Cancel sends nothing, Buy sends
	-- one with the section and the window, and the header reads "Buying..." until the next stock
	{ "CornerShopBuyAll", function()
		local Shop = UIShim.require("ReplicatedStorage.Shared.CornerShop") :: any
		local Catalog = UIShim.require("ReplicatedStorage.Shared.Catalog") :: any
		local window = nil
		for w = 5000, 9000 do
			local kinds = {}
			for _, item in Shop.stock(w) do
				local row = Catalog.getCornerShopRow(item.itemId)
				if item.amount > 0 and (row.needsTier or 1) <= 3 then
					kinds[row.kind] = (kinds[row.kind] or 0) + 1
				end
			end
			if (kinds.potion or 0) >= 2 and (kinds.food or 0) >= 1 and (kinds.bait or 0) >= 1 then
				window = w
				break
			end
		end
		assert(window, "uigate: no Day Cart window with every section in stock (#2593)")
		local function view()
			return Shop.view({ window = window, bought = {}, day = 0, today = {}, foodXpToday = 0 }, window, 3)
		end
		local before = UI.getState()
		Scenes._cashMoney = { money = before.money, passBoosts = (before :: any).passBoosts or false, goldenFish = (before :: any).goldenFish or 0 }
		UI.update({ money = 50000, tier = 3, lures = {} })
		UI.cornerShop.setStock(view())
		UI.cornerShop.open()
		local shop = UIShim.playerGui:FindFirstChild("CornerShop", true)
		local header = shop:FindFirstChild("Section_potion", true)
		local all = header and header:FindFirstChild("BuyAll", true)
		assert(all and all.Visible, "uigate: the Potions header has no Buy all (#2593)")
		local sent: { string } = {}
		local connection = UI.events.buyCornerShopAll:Connect(function(kind, w)
			table.insert(sent, kind .. ":" .. tostring(w))
		end)
		press("CornerShop", "Section_potion.BuyAll")
		local cover = shop:FindFirstChild("BuyAllCover", true)
		assert(cover and cover.Visible, "uigate: Buy all opened no card (#2593)")
		local list = cover:FindFirstChild("List", true).Text
		assert(string.find(list, "^%d+ "), "uigate: the Buy all card lists " .. list .. " (#2593)")
		press("CornerShop", "BuyAllCover.Cancel")
		assert(not cover.Visible and #sent == 0, "uigate: Cancel sent a Buy all or kept the card (#2593)")
		press("CornerShop", "Section_potion.BuyAll")
		press("CornerShop", "BuyAllCover.Buy")
		connection:Disconnect()
		assert(#sent == 1 and sent[1] == "potion:" .. window, "uigate: Buy sent " .. table.concat(sent, ","))
		UI.cornerShop.setStock(view()) -- the answer ends the wait
		press("CornerShop", "Section_bait.BuyAll") -- the shot: the bait section's card
	end },
	-- #2214 (crispi_255): a red "!" over the Fish Market while crates wait to open, "📦 3 crates to open" under it;
	-- with none it is gone
	-- #2501 (Derek2: "put an exclamation mark above the free group cat station"): a "!" over the Bellhop Cat's stand
	-- while the cat is not taken, gone once it is
	{ "StarterCatBang", function()
		local stand = Instance.new("Model")
		stand.Name = "CatCafe_Street_BellhopStand"
		local base = Instance.new("Part")
		base.Name = "Base"
		base.Size = Vector3.new(6, 4, 4)
		base.Position = Vector3.new(10, 2, -20)
		base.Parent = stand
		stand.PrimaryPart = base
		stand.Parent = workspace
		stand:AddTag("BellhopStand")
		local before = (UI.getState() :: any).starterCatClaimed
		local function bang(): BillboardGui?
			for _, gui in UIShim.playerGui:GetDescendants() do
				if gui:IsA("BillboardGui") and gui.Name == "CatCafeStarterBang" and gui.Adornee == base then
					return gui
				end
			end
			return nil
		end
		UI.update({ starterCatClaimed = false } :: any)
		local gui = bang()
		assert(gui and gui.Enabled, "uigate: no ! over the free cat's stand (#2501)")
		local line = (gui :: BillboardGui):FindFirstChild("Line", true) :: TextLabel
		assert(string.find(string.lower(line.Text), "free cat", 1, true), "uigate: the stand's bubble reads " .. line.Text .. " (#2501)")
		UI.update({ starterCatClaimed = true } :: any)
		assert(not (gui :: BillboardGui).Enabled, "uigate: the stand's ! stays after the cat is taken (#2501)")
		UI.update({ starterCatClaimed = before } :: any)
		stand:Destroy()
	end },
	{ "MarketBang", function()
		local stall = Instance.new("Model")
		stall.Name = "CatCafe_FishMarket"
		local counter = Instance.new("Part")
		counter.Name = "Counter"
		counter.Size = Vector3.new(8, 6, 4)
		counter.Position = Vector3.new(0, 3, -20)
		counter.Parent = stall
		stall.PrimaryPart = counter
		stall.Parent = workspace
		stall:AddTag("FishMarket")
		Scenes._market = { stall = stall, crates = UI.getState().crates, seen = (UI.getState() :: any).storeSeen }
		UI.update({ storeSeen = { treats = 1 } } :: any) -- #2571: Treats and perks seen, so only crates raise the !
		local function bang(): BillboardGui
			local gui = UIShim.playerGui:FindFirstChild("CatCafeMarketBang", true)
			assert(gui and gui:IsA("BillboardGui"), "uigate: no ! billboard over the Fish Market (#2214)")
			return gui :: BillboardGui
		end
		UI.update({ crates = { park = 2, alley = 1 } } :: any)
		local gui = bang()
		assert(gui.Enabled and gui.Adornee == counter, "uigate: the Fish Market's ! is not up with crates to open (#2214)")
		local line = gui:FindFirstChild("Line", true) :: TextLabel
		assert(line.Text == "📦 3 crates to open", "uigate: the Fish Market bubble reads " .. line.Text .. " (#2214)")
		UI.update({ crates = {} } :: any)
		assert(not gui.Enabled, "uigate: the Fish Market's ! stays up with no crates (#2214)")
		UI.update({ crates = { park = 1 } } :: any)
		assert(gui.Enabled and line.Text == "📦 1 crate to open", "uigate: one crate reads " .. line.Text .. " (#2214)")
		-- #2571: never opened Treats and perks: the ! asks to check them with no crates, and crates come first
		UI.update({ storeSeen = { featured = 1 } } :: any)
		assert(line.Text == "📦 1 crate to open", "uigate: crates did not come first over the treats line (#2571)")
		UI.update({ crates = {} } :: any)
		assert(
			gui.Enabled and line.Text == "🍪 Treats and perks to check out!",
			"uigate: the Fish Market's ! does not ask to check the treats: " .. line.Text .. " (#2571)"
		)
		UI.update({ storeSeen = { treats = 1 } } :: any)
		assert(not gui.Enabled, "uigate: the treats ! stays after Treats and perks was seen (#2571)")
	end },
	-- #2345 (Derek2: "add an exclamation mark to the upgrades if something is available to buy that you can afford"):
	-- the Upgrades tile's red "!" shows with an upgrade affordable, stays after Upgrades is opened, and goes with no
	-- money to spend
	{ "UpgradesBang", function()
		local before: any = UI.getState()
		Scenes._spinState = { money = before.money, spin = before.spin, tutorialStep = before.tutorialStep }
		UI.update({ money = 1e12, tutorialStep = 9 } :: any)
		local tile = UIShim.playerGui:FindFirstChild("CatCafeHUD"):FindFirstChild("Upgrades", true) :: Instance
		local dot = tile:FindFirstChild("Dot", true) :: GuiObject
		assert(dot and dot.Visible, "uigate: no ! on the Upgrades tile with an upgrade affordable (#2345)")
		UI.open("Upgrades")
		UI.close()
		UI.update({ money = 1e12 + 1 } :: any)
		assert(dot.Visible, "uigate: the Upgrades ! went when Upgrades was opened, with an upgrade still affordable (#2345)")
		UI.update({ money = 0 } :: any)
		task.wait(0.1)
		assert(not dot.Visible, "uigate: the Upgrades ! stays with nothing affordable (#2345)")
		UI.update({ money = 1e12 } :: any)
	end },
	-- #2358 (Derek2: "show an exclamation mark near spin when you have one"): the HUD's spin line with its red "!" for
	-- today's free spin and for banked spins, gone with none; and the "!" over the Spin Wheel in the world
	{ "SpinBang", function()
		local before: any = UI.getState()
		Scenes._spinState = Scenes._spinState
			or { money = before.money, spin = before.spin, tutorialStep = before.tutorialStep }
		local wheel = Instance.new("Model")
		wheel.Name = "SpinWheel"
		local post = Instance.new("Part")
		post.Name = "Post"
		post.Size = Vector3.new(2, 10, 2)
		post.Position = Vector3.new(-10, 5, -24)
		post.Parent = wheel
		wheel.PrimaryPart = post
		wheel.Parent = workspace
		wheel:AddTag("SpinWheel")
		Scenes._spinWheel = wheel
		local today = math.floor(workspace:GetServerTimeNow() / 86400)
		local hud = UIShim.playerGui:FindFirstChild("CatCafeHUD") :: ScreenGui
		local line = hud:FindFirstChild("FreeSpin", true) :: GuiObject
		local words = line:FindFirstChild("Text") :: TextLabel
		local mark = line:FindFirstChild("Claim") :: GuiObject
		local function bang(): BillboardGui?
			for _, gui in UIShim.playerGui:GetDescendants() do
				if gui:IsA("BillboardGui") and gui.Adornee == post then
					return gui
				end
			end
			return nil
		end
		-- #2397 (Derek2: "for mobile remove the free spin at town square"): on touch the line never shows (its words
		-- are still kept up to date); the wheel's "!" shows either way
		local touch = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Scale").isTouch()
		local function lineShows(): boolean
			if touch then
				assert(not line.Visible, "uigate: the free spin line shows on touch (#2397)")
				return true
			end
			return line.Visible
		end
		UI.update({ tutorialStep = 9, spin = { lastFreeDay = today - 1, banked = 0 } } :: any)
		UIShim.advance(1.1) -- the wheel's "!" finds the new model within a second
		assert(lineShows() and mark.Visible, "uigate: no ! on the free spin line (#2358)")
		assert(words.Text == "🎡 Free spin at the Town Square", "uigate: the spin line reads " .. words.Text .. " (#2358)")
		local gui = bang()
		assert(gui and gui.Enabled, "uigate: no ! over the Spin Wheel with a free spin (#2358)")
		local bubble = (gui :: BillboardGui):FindFirstChild("Line", true) :: TextLabel
		assert(bubble.Text == "🎡 Free spin!", "uigate: the Spin Wheel bubble reads " .. bubble.Text .. " (#2358)")
		UI.update({ spin = { lastFreeDay = today, banked = 2 } } :: any)
		assert(lineShows() and words.Text == "🎡 2 spins at the Town Square", "uigate: banked spins read " .. words.Text .. " (#2358)")
		assert(bubble.Text == "🎡 2 spins to use", "uigate: the Spin Wheel bubble reads " .. bubble.Text .. " with 2 banked (#2358)")
		UI.update({ spin = { lastFreeDay = today, banked = 0 } } :: any)
		assert(not line.Visible, "uigate: the spin line stays with no spin left (#2358)")
		assert(not (gui :: BillboardGui).Enabled, "uigate: the Spin Wheel's ! stays with no spin left (#2358)")
		UI.update({ spin = { lastFreeDay = today - 1, banked = 2 } } :: any) -- the sample's spins, for the snapshot
	end },
	-- #2214 add-on (Derek2: "show exclamation mark when someone is doing a rescue also"): another player rescuing at a
	-- spot puts the "!" over it, "🆘 Rescue on! Come help"; a helper joining reads "🐾 Team Rescue on!"; it goes when
	-- the rescue ends, and the rescuer never sees their own
	{ "RescueBang", function()
		local spot = Instance.new("Part")
		spot.Name = "RescueSpot_gate"
		spot.Size = Vector3.new(2, 1, 2)
		spot.Position = Vector3.new(6, 1, -16)
		spot:SetAttribute("RescueSpotId", "gate_spot")
		spot:SetAttribute("LockedBy", 0)
		spot:SetAttribute("HelpedBy", 0)
		spot.Parent = workspace
		spot:AddTag("RescueSpot")
		Scenes._rescueSpot = spot
		local function bang(): BillboardGui?
			for _, gui in UIShim.playerGui:GetDescendants() do
				if gui:IsA("BillboardGui") and gui.Name == "CatCafeRescueBang" and gui.Adornee == spot then
					return gui
				end
			end
			return nil
		end
		UIShim.advance(0.6)
		local idle = bang()
		assert(idle == nil or not idle.Enabled, "uigate: a free rescue spot shows a ! (#2214)")
		spot:SetAttribute("LockedBy", localUserId() + 1)
		UIShim.advance(0.6)
		local gui = bang()
		assert(gui and gui.Enabled, "uigate: no ! over a rescue in progress (#2214)")
		local line = gui:FindFirstChild("Line", true) :: TextLabel
		assert(line.Text == "🆘 Rescue on! Come help", "uigate: the rescue bubble reads " .. line.Text .. " (#2214)")
		spot:SetAttribute("HelpedBy", localUserId() + 2)
		UIShim.advance(0.6)
		assert(line.Text == "🐾 Team Rescue on!", "uigate: a Team Rescue reads " .. line.Text .. " (#2214)")
		spot:SetAttribute("LockedBy", localUserId())
		spot:SetAttribute("HelpedBy", 0)
		UIShim.advance(0.6)
		assert(not gui.Enabled, "uigate: the rescuer sees a ! over their own rescue (#2214)")
		spot:SetAttribute("LockedBy", localUserId() + 1) -- on again, for the picture
		UIShim.advance(0.6)
	end },
	-- F100: the prize toast after the Lost and Found: the line and two pictures
	{ "CampPrize", function()
		UI.campExtras.collected(
			"lostFound",
			{ "1 Lucky Potion", "+10 golden fish" },
			{ potions = { lucky_potion = 1 }, fish = 10 }
		)
	end },
	-- F101: a Rescue Rally on its second lap, the bar past its first step, this player on 7 points
	{ "RallyBanner", function()
		rallyScore({ lap = 2, points = 50, myPoints = 7 })
		local rallyGui = UIShim.playerGui:FindFirstChild("CatCafeRally")
		assert(rallyGui and rallyGui.Enabled, "uigate: the Rally banner did not pop up when this player scored (#2098)")
		-- #2078: "50 / 90" clear of the pictures, and 14, 27, 45, 68 and 90 under the steps, above "You: 7 points"
		local track = UIShim.playerGui:FindFirstChild("RallyBar", true)
		local mine = track and track.Parent and track.Parent:FindFirstChild("Mine")
		assert(mine and mine:IsA("TextLabel"), "uigate: the Rally banner has no Mine line (#2078)")
		local mineTop = mine.AbsolutePosition.Y + (mine.AbsoluteSize.Y - mine.TextBounds.Y) / 2
		assertRallyBar(track, { 14, 27, 45, 68, 90 }, mineTop)
	end },
	-- #2078: the Town Square board's face (500 x 200, the board's own layout) on a big goal: "135 / 300" past the
	-- bar's end, clear of the pictures, and each step's points under it, above the time left
	{ "RallyBoardFace", function()
		local RallyBar = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Components.RallyBar")
		local RallyLogic = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Components.RallyLogic")
		local RallyBoards = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Screens.RallyBoards")
		local Theme = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Theme")
		local gui = Instance.new("ScreenGui")
		gui.Name = "RallyBoardFaceGate"
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.DisplayOrder = 100 -- over the HUD, so the shot shows the face
		gui.Parent = UIShim.playerGui
		Scenes._rallyFace = gui
		local face = Instance.new("Frame")
		face.Name = "Face"
		face.BackgroundColor3 = Color3.fromHex("2B2F3A") -- the board's dark face
		face.AnchorPoint = Vector2.new(0.5, 0.5)
		face.Position = UDim2.fromScale(0.5, 0.5)
		face.Size = UDim2.fromOffset(RallyBoards.FACE.X, RallyBoards.FACE.Y)
		face.Parent = gui
		local layout = RallyBoards.BAR
		local bar = RallyBar.new({
			parent = face,
			name = "RallyBoardBar",
			size = layout.size,
			position = layout.position,
			marker = layout.marker,
			textSize = layout.textSize,
			countWidth = layout.countWidth,
			numberSize = layout.numberSize,
			textColor = Theme.chalk,
		})
		bar:set(RallyLogic.view(rallyState({ goal = 300, points = 135 }), workspace:GetServerTimeNow()))
		local faceRight = face.AbsolutePosition.X + face.AbsoluteSize.X
		local points = bar.frame:FindFirstChild("Points")
		assert(
			points.AbsolutePosition.X + points.AbsoluteSize.X <= faceRight + 0.5,
			"uigate: the board's Rally count runs off its face (#2078)"
		)
		assertRallyBar(bar.frame, { 45, 90, 150, 225, 300 }, face.AbsolutePosition.Y + RallyBoards.LEFT_Y)
	end },
	-- F101: this player's laps used up this weekend, the bar nearly full
	{ "RallyBannerDone", function()
		rallyScore({ lap = 5, points = 85, myPoints = 12, lapsPaid = 4, lapsDone = true })
	end },
	-- #2098: a Rally running and nobody scoring here: the banner stays hidden
	{ "RallyBannerHidden", function()
		-- the Rally off first, so nothing from an earlier scene is waiting to pop up
		UI.rally.update(rallyState({ active = false, endsAt = 0, startsAt = 0, myPoints = 7 }))
		UI.rally.update(rallyState({ lap = 2, points = 50, myPoints = 7 }))
		UI.rally.update(rallyState({ lap = 2, points = 52, myPoints = 7 })) -- someone else's points
		Scenes._rallyPeek = true
		local gui = UIShim.playerGui:FindFirstChild("CatCafeRally")
		assert(gui and gui:IsA("ScreenGui"), "uigate: no Rally banner built (#2098)")
		assert(not gui.Enabled, "uigate: the Rally banner shows though this player has not scored (#2098)")
	end },
	-- F101: the Cat Cannon at night during a Rally: every card's "Rally: rescues x3" tag over its night cover
	{ "RallyCannonNight", function()
		local t = workspace:GetServerTimeNow()
		local clock = Instance.new("Folder")
		clock.Name = "Clock"
		clock:SetAttribute("Phase", "night")
		clock:SetAttribute("PhaseEndsAt", t + 60)
		clock:SetAttribute("AreasOpen", false)
		clock:SetAttribute("Day", 3)
		clock:SetAttribute("NextLuckyDay", 4)
		clock:SetAttribute("LuckyDay", false)
		UI.clock.bind(clock)
		UI.rally.update(rallyState({ points = 12, myPoints = 0 }))
		UI.cannon.open()
	end },
	-- F101: three potions running and the Luck chip: on the phone the row beside the menu reaches the top centre,
	-- so the banner moves down under it
	{ "RallyBannerPotions", function()
		local t = workspace:GetServerTimeNow()
		UI.update({ buffs = { tip_potion = t + 492, swift_potion = t + 130, lucky_potion = t + 492 } })
		rallyScore({ points = 30, myPoints = 2 })
	end },
	-- F101 (review S113): a rescue during a Rally: the banner steps aside, so the rescue bar's header is clear
	{ "RallyRescue", function()
		rallyScore({ lap = 2, points = 50, myPoints = 7 })
		UI.rescue.show("gate_rescue", rescueChallenge())
	end },
	-- #2608: lap 3 in this server: the banner's gold pill reads "Lap 3: bigger prizes!" and the name steps down to the flag
	{ "RallyLapThree", function()
		rallyScore({ lap = 3, points = 50, myPoints = 7 })
		local banner = UIShim.playerGui:FindFirstChild("CatCafeRally", true)
		local lap = banner and banner:FindFirstChild("Lap", true) :: TextLabel?
		assert(lap and lap.Visible and lap.Text == "Lap 3: bigger prizes!", "uigate: no lap pill (#2608)")
	end },
	-- F101: Friday, 5 h 20 m before the Rally: the countdown under the clock and no banner
	{ "RallySoon", function()
		local t = workspace:GetServerTimeNow()
		UI.rally.update(rallyState({ active = false, endsAt = 0, startsAt = t + 5 * 3600 + 1200 }))
	end },
	-- #2487 (live-events.md section 3): a Cafe Party 2:59:10 away: the hourglass chip under the clock, clear of the
	-- goal card
	{ "CafeEventSoon", function()
		local t = workspace:GetServerTimeNow()
		Scenes._cafeEvent = true
		cafeEvent({ EventStartsAt = t + 10750, EventEndsAt = t + 10750 + 7200, EventRunning = false })
		local chip = assertEventChip(1)
		assert(chip.Text == "⏳ Cafe Party in 2:59", "uigate: the event chip reads " .. chip.Text .. " (#2487)")
	end },
	-- #2487: the party running: the start banner and the gold chip with the end and the next shower
	{ "CafeEventRunning", function()
		local t = workspace:GetServerTimeNow()
		Scenes._cafeEvent = true
		UIShim.advance(4) -- earlier scenes' toasts gone
		cafeEvent({ EventStartsAt = t - 20, EventEndsAt = t + 7180, EventRunning = true })
		local chip = assertEventChip(2)
		assert(chip.Text:find("Cafe Party · ends in 1:59:", 1, true) ~= nil, "uigate: the running chip reads " .. chip.Text .. " (#2487)")
		local nextLine = (UIShim.playerGui:FindFirstChild("EventNext", true) :: TextLabel).Text
		assert(nextLine:find("^next shower 9:") ~= nil, "uigate: the running chip's next shower reads " .. nextLine .. " (#2487)")
		local banner = false
		for _, label in UIShim.playerGui:GetDescendants() do
			if label:IsA("TextLabel") and label.Name == "Text" and label.Parent and label.Parent.Name == "Toast" then
				if label.Text:find("^Cafe Party! x2 cafe earnings and rare cat showers until %d%d:%d%d$") then
					banner = true
				end
			end
		end
		assert(banner, "uigate: no Cafe Party start banner (#2487)")
		-- a second pass shows no second banner
		UI.cafeEvent.tick()
		local banners = 0
		for _, label in UIShim.playerGui:GetDescendants() do
			if label:IsA("TextLabel") and label.Name == "Text" and label.Parent and label.Parent.Name == "Toast" then
				if label.Text:find("^Cafe Party!") then
					banners += 1
				end
			end
		end
		assert(banners == 1, ("uigate: %d Cafe Party banners, not 1 (#2487)"):format(banners))
	end },
	-- #2487: the Town Square board's face while the party runs, its words drawn on a 10 x 7.5 stud face
	{ "CafeEventBoard", function()
		local t = workspace:GetServerTimeNow()
		Scenes._cafeEvent = true
		cafeEvent({ EventStartsAt = t - 20, EventEndsAt = t + 7180, EventRunning = true })
		-- the board: a tagged model with a Screen part, its face's words moved onto a frame the shot can show
		local EventBoards = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Screens.EventBoards")
		local EventLogic = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Components.EventLogic")
		local model = Instance.new("Model")
		model.Name = "CatCafe_Square_EventBoard"
		local screen = Instance.new("Part")
		screen.Name = "Screen"
		screen.Parent = model
		model.Parent = workspace
		model:AddTag(EventBoards.TAG)
		local gui = Instance.new("ScreenGui")
		gui.Name = "EventBoardFaceGate"
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.DisplayOrder = 100 -- over the HUD, so the shot shows the face
		gui.Parent = UIShim.playerGui
		Scenes._eventFace = { gui = gui, model = model }
		local boards = EventBoards.new(gui)
		Scenes._eventFace.boards = boards
		local attrs = game:GetService("ReplicatedStorage")
		local view = EventLogic.read(function(name: string): any
			return attrs:GetAttribute(name)
		end, UI.cafeEvent.decode)
		boards:set(view, nil)
		local surface = gui:FindFirstChild("EventBoardFace")
		assert(surface and surface:IsA("SurfaceGui"), "uigate: the tagged board got no face (#2487)")
		local face = Instance.new("Frame")
		face.Name = "Face"
		face.BackgroundColor3 = Color3.fromHex("2B2F3A")
		face.AnchorPoint = Vector2.new(0.5, 0.5)
		face.Position = UDim2.fromScale(0.5, 0.5)
		face.Size = UDim2.fromOffset(400, 300) -- a 10 x 7.5 stud face at 40 px a stud, inside a small phone's height
		face.Parent = gui
		for _, child in surface:GetChildren() do
			child.Parent = face
		end
		local heading = face:FindFirstChild("Heading") :: TextLabel
		assert(heading.Text == "Cafe Party!", "uigate: the board's heading reads " .. heading.Text .. " (#2487)")
		local shown = 0
		for index = 1, EventBoards.LINES do
			local line = face:FindFirstChild("Line" .. index) :: TextLabel
			if line.Visible then
				shown += 1
				assert(line.TextFits, "uigate: the board's line " .. line.Text .. " does not fit (#2487)")
			end
		end
		assert(shown == 5, ("uigate: the board shows %d effect lines, not 5 (#2487)"):format(shown))
	end },
	-- F102: TradeService runs, so the HUD's top row holds seven tiles with Trade before Invite (review N334)
	{ "HUDTrade", function()
		workspace:SetAttribute("TradingOn", true)
		UI.update({ tier = 3 })
	end },
	-- #2462 (Derek2 11-08: "show the trade button but grayed out until unlocked and when clicked it says unlocks at
	-- Tier 3"): below the trading tier the Trade tile shows greyed, a tap opens nothing and says which tier opens it
	{ "HUDTradeLocked", function()
		workspace:SetAttribute("TradingOn", true)
		Scenes._tradeTier = { tier = (UI.getState() :: any).tier }
		UI.update({ tier = 1 })
		local hud = UIShim.playerGui:FindFirstChild("CatCafeHUD") :: ScreenGui
		local tile = hud:FindFirstChild("Trade", true) :: GuiObject
		assert(tile and tile.Visible, "uigate: no Trade tile below the trading tier (#2462)")
		press("CatCafeHUD", "Icons.Trade")
		local note = hud:FindFirstChild("LockedNote", true) :: TextLabel?
		assert(note and note.Text == "Unlocks at Tier 3", "uigate: the greyed Trade tile says " .. tostring(note and note.Text) .. " (#2462)")
		assert(UI.isOpen() ~= "Trade", "uigate: the greyed Trade tile opened the Trade window (#2462)")
	end },
	-- Fewer buttons (Derek 2026-11-02): the Rewards tile's list (gifts and the Daily Treat) and the Menu tile's list
	-- (Settings, Invite) under the icon row
	{ "HUDRewards", function()
		press("CatCafeHUD", "Icons.Rewards")
	end },
	{ "HUDMenu", function()
		press("CatCafeHUD", "Icons.Menu")
	end },
	-- carrying a cat: the banner over the bottom row with the cat's head in its rarity circle (Derek 2026-11-03)
	{ "HUDCarry", function()
		UI.setCarrying({ catId = Catalog.cats[1].id, catName = Catalog.cats[1].name, rarity = Catalog.cats[1].rarity })
	end },
	-- the Store (Derek 2026-11-02 20:01): passes on sale; the HUD's gold Store tile at the top of the left grid
	{ "HUDStore", function()
		UI.store.preview(storePrices(true), {})
	end },
	-- #1606: the money pass badge beside the money: the rainbow "X2 Cash / Only R$5" (#1759) with no money pass and the
	-- 2x on sale; once owned, "💰 Cash x3" on the side over the money (#1962)
	-- #2334 (Derek2: "the gold fish and money should be side by side in bottom left and the 2x cash ... should be to the
	-- right of both of those"): left to right the money, the golden fish, then the badge, none touching
	{ "HUDMoneyBadge", function()
		local before: any = UI.getState()
		Scenes._cashMoney = { money = before.money, passBoosts = before.passBoosts or false, goldenFish = before.goldenFish or 0 }
		UI.update({ passBoosts = false, goldenFish = 1234 } :: any)
		UI.store.preview(storePrices(true), {})
		UIShim.advance(1 / 60)
		local hud = UIShim.playerGui:FindFirstChild("CatCafeHUD") :: ScreenGui
		local counters = hud:FindFirstChild("Counters", true) :: Frame
		local money = counters:FindFirstChild("Money") :: GuiObject
		local fish = counters:FindFirstChild("Fish") :: GuiObject
		local badge = hud:FindFirstChild("MoneyBadge", true) :: GuiObject
		assert(fish.Visible and badge.Visible, "uigate: the golden fish or the money badge is hidden (#2334)")
		local function right(gui: GuiObject): number
			return gui.AbsolutePosition.X + gui.AbsoluteSize.X
		end
		assert(right(money) <= fish.AbsolutePosition.X, "uigate: the golden fish is not right of the money (#2334)")
		local touch = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Scale").isTouch()
		if not touch then
			assert(right(fish) <= badge.AbsolutePosition.X, "uigate: the money badge is not right of the golden fish (#2334)")
			return
		end
		-- #2393 (Derek2: "make it on the top middle of the screen for at least the luck/money/gold fish ... and put the
		-- 2x money advertising on the right side above potions"): on touch the counters are centred at the top, the
		-- badge is in the right half, its foot over the Potions corner, clear of the right column's lines
		local root = hud:FindFirstChild("Root") :: Frame
		local middle = root.AbsolutePosition.X + root.AbsoluteSize.X / 2
		if right(counters) > 0 and counters.AbsolutePosition.Y + counters.AbsoluteSize.Y <= root.AbsolutePosition.Y + 2 then
			-- #2447 (Derek2 11-08: "move these into this little bar between chat and tutorial"): up in Roblox's top
			-- bar, between its buttons and the icon row
			local inset = game:GetService("GuiService"):GetGuiInset()
			local bar = game:GetService("GuiService").TopbarInset
			local icons = root:FindFirstChild("Icons") :: GuiObject
			assert(counters.AbsolutePosition.X + inset.X >= bar.Min.X, "uigate: the counters run into Roblox's buttons (#2447)")
			assert(right(counters) <= icons.AbsolutePosition.X, "uigate: the counters run into the icon row (#2447)")
			assert(counters.AbsolutePosition.Y + inset.Y >= 0, "uigate: the counters poke over the screen's top (#2447)")
		else
			local countersMiddle = counters.AbsolutePosition.X + counters.AbsoluteSize.X / 2
			assert(math.abs(countersMiddle - middle) <= 2, "uigate: the counters are not centred on touch (#2393)")
		end
		assert(counters.AbsolutePosition.Y < root.AbsolutePosition.Y + root.AbsoluteSize.Y / 4, "uigate: the counters are not at the top on touch (#2393)")
		-- #2533 (Derek2: "move the 2x cash below the money on mobile/ipad ... where it currently is is too close to
		-- net/takcle button"): right under the money, left edges level (under the Luck row when that is under it)
		local luckRow = root:FindFirstChild("Potions") :: GuiObject?
		local over = counters.AbsolutePosition.Y + counters.AbsoluteSize.Y
		if luckRow and luckRow.Visible and luckRow.AbsolutePosition.Y >= over then
			over = luckRow.AbsolutePosition.Y + luckRow.AbsoluteSize.Y
		end
		local drop = badge.AbsolutePosition.Y - over
		assert(drop >= 0 and drop <= 24, ("uigate: the money badge sits %d px under the money (#2533)"):format(drop))
		assert(math.abs(badge.AbsolutePosition.X - money.AbsolutePosition.X) <= 2, "uigate: the money badge is not level with the money (#2533)")
		-- and well clear of the Net button and the Tackle button left of it
		local NetButtonPlace = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Components.NetButtonPlace")
		local tackleAt = NetButtonPlace.tackle(workspace.CurrentCamera.ViewportSize)
		local guiInset = game:GetService("GuiService"):GetGuiInset()
		assert(badge.AbsolutePosition.Y + badge.AbsoluteSize.Y + guiInset.Y + 40 <= tackleAt.Y or right(badge) + guiInset.X + 40 <= tackleAt.X, "uigate: the money badge is near the Net and Tackle buttons (#2533)")
		-- #2529 (Derek2: "move potions and the dropdown menu to the left of the my cafe button on mobile"): left to right
		-- the Potions tile, the arrow tab, then the bottom row, all clear of the bottom right
		local corner = root:FindFirstChild("Corner") :: GuiObject
		local fold = root:FindFirstChild("TravelFold") :: GuiObject
		local travel = root:FindFirstChild("Travel") :: GuiObject
		assert(right(corner) <= fold.AbsolutePosition.X, "uigate: the Potions tile is not left of the arrow tab (#2529)")
		assert(right(fold) <= travel.AbsolutePosition.X, "uigate: the arrow tab is not left of the bottom row (#2529)")
		assert(right(travel) <= tackleAt.X + guiInset.X, "uigate: the bottom row reaches the Tackle button (#2529)")
		-- clear of Roblox's touch jump button (70 px at 95, 90 from the bottom right; 120 at 170, 210 on a big screen)
		local view = workspace.CurrentCamera.ViewportSize
		local guiTop = game:GetService("GuiService"):GetGuiInset().Y
		local small = math.min(view.X, view.Y) <= 500
		local jumpSize = if small then 70 else 120
		local jumpX = view.X - (if small then 95 else 170)
		local jumpY = view.Y - (if small then 90 else 210)
		local bx, by = badge.AbsolutePosition.X, badge.AbsolutePosition.Y + guiTop
		local onJump = bx < jumpX + jumpSize and bx + badge.AbsoluteSize.X > jumpX
			and by < jumpY + jumpSize and by + badge.AbsoluteSize.Y > jumpY
		assert(not onJump, "uigate: the money badge sits on the jump button (#2499)")
		for _, name in { "FreeSpin", "TierGoal", "Menu" } do
			local other = root:FindFirstChild(name) :: GuiObject?
			if other and other.Visible then
				local left = other.AbsolutePosition.X
				local apart = badge.AbsolutePosition.Y >= other.AbsolutePosition.Y + other.AbsoluteSize.Y
					or right(badge) <= left
					or badge.AbsolutePosition.X >= right(other)
					or badge.AbsolutePosition.Y + badge.AbsoluteSize.Y <= other.AbsolutePosition.Y
				assert(apart, "uigate: the money badge runs into " .. name .. " on touch (#2393)")
			end
			if other and other.Visible and name ~= "FreeSpin" then
				local clear = counters.AbsolutePosition.X >= right(other) or right(counters) <= other.AbsolutePosition.X
					or counters.AbsolutePosition.Y >= other.AbsolutePosition.Y + other.AbsoluteSize.Y
				assert(clear, "uigate: the counters run into " .. name .. " on touch (#2393)")
			end
		end
	end },
	-- #2393: on touch the Luck row sits centred under the counters at the top and the money's boosts card opens under
	-- the counters; #2397: the goal card takes at least a quarter less room than on a PC. A PC keeps the counters in
	-- the bottom left.
	{ "HUDTouchTop", function()
		local touch = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Scale").isTouch()
		UI.update({ luck = 2 } :: any)
		UIShim.advance(1 / 60)
		local hud = UIShim.playerGui:FindFirstChild("CatCafeHUD") :: ScreenGui
		local root = hud:FindFirstChild("Root") :: Frame
		local counters = root:FindFirstChild("Counters") :: Frame
		local bottom = counters.AbsolutePosition.Y + counters.AbsoluteSize.Y
		if not touch then
			local rootBottom = root.AbsolutePosition.Y + root.AbsoluteSize.Y
			assert(bottom > rootBottom - 80 and counters.AbsolutePosition.X < root.AbsolutePosition.X + 40, "uigate: the counters left the bottom left on a PC (#2393)")
			return
		end
		local row = root:FindFirstChild("Potions") :: GuiObject
		assert(row.Visible, "uigate: no Luck row with luck 2x (#2393)")
		if bottom <= root.AbsolutePosition.Y + 2 then
			-- #2447: in the top bar the Luck row sits right of the counters, level with them
			local gap = row.AbsolutePosition.X - (counters.AbsolutePosition.X + counters.AbsoluteSize.X)
			assert(gap >= 0 and gap <= 30, ("uigate: the Luck row sits %d px after the counters in the top bar (#2447)"):format(gap))
			local rowMid = row.AbsolutePosition.Y + row.AbsoluteSize.Y / 2
			local countersMid = counters.AbsolutePosition.Y + counters.AbsoluteSize.Y / 2
			assert(math.abs(rowMid - countersMid) <= 2, "uigate: the Luck row is not level with the counters (#2447)")
		else
			assert(row.AbsolutePosition.Y >= bottom, "uigate: the Luck row is not under the counters on touch (#2393)")
			local middle = counters.AbsolutePosition.X + counters.AbsoluteSize.X / 2
			local rowMiddle = row.AbsolutePosition.X + row.AbsoluteSize.X / 2
			assert(math.abs(rowMiddle - middle) <= 2, "uigate: the Luck row is not centred under the counters (#2393)")
		end
		press("CatCafeHUD", "Counters.Money")
		local card = root:FindFirstChild("Boosts") :: GuiObject
		assert(card.Visible, "uigate: the money did not open the boosts card on touch (#2393)")
		assert(card.AbsolutePosition.Y >= bottom, "uigate: the boosts card covers the counters on touch (#2393)")
		press("CatCafeHUD", "Counters.Money")
		local goal = root:FindFirstChild("TierGoal") :: GuiObject
		local scale = (root:FindFirstChildOfClass("UIScale") :: UIScale).Scale
		local area = goal.AbsoluteSize.X * goal.AbsoluteSize.Y / (scale * scale)
		assert(area <= 0.55 * 250 * 160, ("uigate: the goal card is %d design px², not about half (#2397, #2415)"):format(area))
		-- #2415 (Derek2: "net overlaps your goal bubble"): the goal card ends above the Net
		-- button, on a Lucky Day too (its line under the clock pushes the column down)
		local clock = Instance.new("Folder")
		clock.Name = "Clock"
		clock:SetAttribute("Phase", "day")
		clock:SetAttribute("PhaseEndsAt", workspace:GetServerTimeNow() + 190)
		clock:SetAttribute("AreasOpen", true)
		clock:SetAttribute("Day", 4)
		clock:SetAttribute("NextLuckyDay", 8)
		clock:SetAttribute("LuckyDay", true)
		UI.clock.bind(clock)
		UIShim.advance(0.1)
		local NetButtonPlace = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Components.NetButtonPlace")
		local netAt = NetButtonPlace.place(workspace.CurrentCamera.ViewportSize)
		local inset = game:GetService("GuiService"):GetGuiInset()
		for _, name in { "TierGoal" } do
			local part = root:FindFirstChild(name) :: GuiObject
			if part.Visible then
				local foot = part.AbsolutePosition.Y + part.AbsoluteSize.Y + inset.Y
				assert(foot <= netAt.Y, ("uigate: %s ends at %d px, over the Net button from %d (#2415)"):format(name, foot, netAt.Y))
			end
		end
	end },
	-- #2194 (playtester Dread via Derek2: "The cash at the bottom left should probably not push the 2x cash and fish"):
	-- the money badge and the golden fish stay put while the digits tick within an amount's shape ("$1.24M" to
	-- "$1.29M"); #2383 (Derek2: "isn't supposed to be a big gap between the money and fish"): at every amount the fish
	-- sits a short gap after it, never on it
	{ "HUDCashSteady", function()
		-- an earlier scene's 2x Money pass hides the badge (it shows as the side chip): no pass here, the golden fish
		-- shown, both put back by Scenes.close
		local before: any = UI.getState()
		Scenes._cashMoney = { money = before.money, passBoosts = before.passBoosts or false, goldenFish = before.goldenFish or 0 }
		UI.update({ passBoosts = false, goldenFish = 1234 } :: any)
		UI.store.preview(storePrices(true), {})
		local hud = UIShim.playerGui:FindFirstChild("CatCafeHUD") :: ScreenGui
		local counters = hud:FindFirstChild("Counters", true) :: Frame
		local badge = hud:FindFirstChild("MoneyBadge", true) :: GuiObject -- (over the Potions corner on touch, #2393)
		local touch = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Scale").isTouch()
		local fish = counters:FindFirstChild("Fish") :: GuiObject
		local amount = (counters:FindFirstChild("Money") :: Instance):FindFirstChild("Amount", true) :: TextLabel
		assert(badge.Visible and fish.Visible, "uigate: the money badge or the golden fish is hidden (#2194)")
		local scale = amount.AbsoluteSize.Y / 36
		-- each run is one shape: the fish and the badge hold still through it
		for _, run in { { 0, 7 }, { 111, 999 }, { 11111, 88888 }, { 1210000, 1290000 }, { 33300000, 33700000 }, { 111e15, 999e15 } } do
			local badgeX, fishX
			for _, money in run do
				UI.update({ money = money })
				UIShim.advance(1 / 60)
				if badgeX == nil then
					badgeX, fishX = badge.AbsolutePosition.X, fish.AbsolutePosition.X
				end
				assert(math.abs(badge.AbsolutePosition.X - badgeX) < 1, ("uigate: %s moves the money badge %d px (#2194)"):format(amount.Text, badge.AbsolutePosition.X - badgeX))
				assert(math.abs(fish.AbsolutePosition.X - fishX) < 1, ("uigate: %s moves the golden fish %d px (#2194)"):format(amount.Text, fish.AbsolutePosition.X - fishX))
				local gap = (fish.AbsolutePosition.X - (amount.AbsolutePosition.X + amount.TextBounds.X)) / scale
				assert(gap >= 4, "uigate: " .. amount.Text .. " runs into the golden fish (#2194, #2334)")
				-- (at most the room's slack, widest for an amount of 1s, plus the row's own gap)
				assert(gap <= 45, ("uigate: the golden fish sits %d px after %s (#2383)"):format(gap, amount.Text))
				-- (on touch the badge is over the Potions corner instead, #2393)
				assert(touch or fish.AbsolutePosition.X + fish.AbsoluteSize.X <= badge.AbsolutePosition.X, "uigate: the golden fish runs into the money badge (#2334)")
			end
		end
	end },
	-- #2254 (Derek2 11-07: "gold fish is hovering wrong now if you did already buy the 2x/3x/4x money"): with a money
	-- pass owned the badge beside the money is hidden (the "Cash x4" chip shows on the side), and the golden fish sits
	-- a normal gap after the money, at every pass and from short to long amounts; with none it keeps #2194's place
	{ "HUDFishWithPass", function()
		local Config = UIShim.require("ReplicatedStorage.Shared.Config")
		local before: any = UI.getState()
		Scenes._cashMoney = { money = before.money, passBoosts = before.passBoosts or false, goldenFish = before.goldenFish or 0 }
		UI.update({ goldenFish = 878 } :: any)
		local hud = UIShim.playerGui:FindFirstChild("CatCafeHUD") :: ScreenGui
		local counters = hud:FindFirstChild("Counters", true) :: Frame
		local fish = counters:FindFirstChild("Fish") :: GuiObject
		local amount = (counters:FindFirstChild("Money") :: Instance):FindFirstChild("Amount", true) :: TextLabel
		local scale = amount.AbsoluteSize.Y / 36
		for pass = 2, 4 do
			UI.store.preview(storePrices(true), { [Config.MoneyPassIds[pass]] = true })
			for _, money in { 1234, 373e9, 88888, 999e15 } do
				UI.update({ money = money })
				UIShim.advance(1 / 60)
				-- (#2447: on touch the small cash tag sits between them, so the fish is measured from the tag)
				local chip = counters:FindFirstChild("CashChip") :: GuiObject?
				local before = if chip and chip.Visible
					then chip.AbsolutePosition.X + chip.AbsoluteSize.X
					else amount.AbsolutePosition.X + amount.TextBounds.X
				local gap = (fish.AbsolutePosition.X - before) / scale
				assert(gap >= 4 and gap <= 40, ("uigate: with the %dx pass the golden fish sits %d px after %s (#2254)"):format(pass, gap, amount.Text))
			end
		end
		UI.update({ money = 373e9 })
	end },
	-- #1936 (release.md section 3): in the first 30 minutes of play the badge says a plain "x2", with no price and no
	-- pulse; a tap still opens the Store
	{ "HUDMoneyBadgeQuiet", function()
		-- Scenes.close puts the play time and an earlier scene's 2x Money pass back
		Scenes._quiet = { passBoosts = (UI.getState() :: any).passBoosts or false }
		UI.update({ playSeconds = 600, passBoosts = false } :: any)
		UI.store.preview(storePrices(true), {})
		local badge = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("MoneyBadge", true)
		assert(badge and badge.Visible, "uigate: the quiet money badge is hidden (#1936)")
		local pill = badge:FindFirstChild("Pill") :: TextLabel
		local price = badge:FindFirstChild("Price") :: TextLabel
		assert(pill.Text == "x2", "uigate: the quiet money badge reads " .. tostring(pill.Text) .. " (#1936)")
		assert(not price.Visible, "uigate: the quiet money badge shows a price (#1936)")
	end },
	{ "HUDMoneyBadgeOwned", function()
		local Config = UIShim.require("ReplicatedStorage.Shared.Config")
		UI.store.preview(storePrices(true), { [Config.MoneyPassIds[3]] = true })
		-- #1962: the owned multiplier is the bold gold chip on the side, over the money
		local chip = UIShim.playerGui:FindFirstChild("CashChip", true)
		if UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Scale").isTouch() then
			-- #2447: on touch a small tag in the counters' row, right after the money, up in Roblox's top bar
			UIShim.advance(1 / 60)
			local tag = chip and chip:FindFirstChild("Tag") :: TextLabel?
			assert(chip and chip.Visible and tag and tag.Text == "💰 x3", "uigate: the cash tag reads " .. tostring(tag and tag.Text) .. " (#2447)")
			local money = UIShim.playerGui:FindFirstChild("Money", true) :: GuiObject
			assert(chip.Parent == money.Parent, "uigate: the cash tag is not in the counters' row (#2447)")
			local gap = chip.AbsolutePosition.X - (money.AbsolutePosition.X + money.AbsoluteSize.X)
			assert(gap >= 0 and gap <= 30, ("uigate: the cash tag sits %d px after the money (#2447)"):format(gap))
			assert(tag.AbsoluteSize.Y <= 30, ("uigate: the cash tag is %d px tall, not a small tag (#2447)"):format(tag.AbsoluteSize.Y))
			local inset = game:GetService("GuiService"):GetGuiInset()
			assert(money.AbsolutePosition.Y + money.AbsoluteSize.Y <= 2, ("uigate: the money's bottom is %d px under the top bar (#2447)"):format(money.AbsolutePosition.Y + money.AbsoluteSize.Y))
			assert(money.AbsolutePosition.Y + inset.Y >= 0, "uigate: the money pokes over the screen's top (#2447)")
		else
			assert(chip and chip.Visible and chip.Text == "💰 Cash x3", "uigate: the cash chip reads " .. tostring(chip and chip.Text) .. " (#1962)")
		end
	end },
	-- #1770 owner test mode: the server's OwnerTest attribute on the owner's account shows a small label up top
	{ "HUDOwnerTest", function()
		local player = game:GetService("Players").LocalPlayer
		player:SetAttribute("OwnerTest", true)
		UI.store.preview(storePrices(true), {})
		local tag = player.PlayerGui:FindFirstChild("OwnerTest", true)
		assert(tag and tag.Visible, "uigate: owner test mode shows no label (#1770)")
		assert(tag.Text == "Owner test mode", "uigate: the owner label reads " .. tostring(tag.Text) .. " (#1770)")
	end },
	-- the Store window for a new player (#1425): it opens on Featured, the King Cat Pack as the hero over 2x Money,
	-- Long Nap and the Royal Cat, all in view with no scrolling
	{ "Store", function()
		UI.store.preview(storePrices(true), {})
		UI.open("Store")
		assertStoreCards(true)
	end },
	-- #1888: the Store funnel reports each tab once a visit (deferred past the open) and the first buy of a visit
	{ "StoreFunnel", function()
		UI.store.preview(storePrices(true), {})
		local sent = {}
		local connection = UI.events.storeReport:Connect(function(kind, value)
			table.insert(sent, kind .. "=" .. tostring(value))
		end)
		UI.open("Store")
		assert(#sent == 0, "uigate: the open's first tab should wait for the modal's store_opened")
		task.wait(0.05)
		press("CatCafeModals", "passes")
		press("CatCafeModals", "featured")
		press("CatCafeModals", "passes")
		task.wait(0.05)
		local joined = table.concat(sent, ",")
		assert(joined == "store_tab=featured,store_tab=passes", "uigate: Store tabs reported " .. joined)
		-- a priced card on the Passes tab (the List page, not Featured's hidden cards), its Buy pressed twice
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local storeWindow = modals and modals:FindFirstChild("Store", true)
		local list = storeWindow and storeWindow:FindFirstChild("List", true)
		assert(list and list.Visible, "uigate: the Passes tab's list is not up")
		local button = nil
		for _, card in list:GetDescendants() do
			local buy = card:IsA("Frame") and card.Visible and card:FindFirstChild("Buy")
			if buy then
				local candidates = { buy }
				for _, piece in buy:GetDescendants() do
					table.insert(candidates, piece)
				end
				for _, piece in candidates do
					if piece:IsA("GuiButton") and piece.Interactable ~= false and piece.Active ~= false then
						button = piece
						break
					end
				end
			end
			if button then
				break
			end
		end
		assert(button, "uigate: no live Buy on the Passes tab")
		UIShim.fire(UIShim.eventOf(button, "Activated"))
		UIShim.fire(UIShim.eventOf(button, "Activated"))
		local buys = 0
		for _, line in sent do
			if string.sub(line, 1, 10) == "store_buy=" then
				buys += 1
			end
		end
		assert(buys == 1, "uigate: a buy should report once a visit, got " .. buys)
		UI.close()
		UI.open("Store")
		task.wait(0.05)
		assert(sent[#sent] == "store_tab=featured", "uigate: a new visit should report its first tab again")
		connection:Disconnect()
	end },
	-- #1425: the Passes tab, a grid of pass cards 3 across
	{ "StorePasses", function()
		UI.store.preview(storePrices(true), {})
		UI.open("Store")
		press("CatCafeModals", "passes")
		assertStoreCards(false)
	end },
	-- #2147 (Derek2: "make the +15% earned more obvious"): the Cat Accessories and Uniform Styles cards lead their words
	-- with a gold "+15% money" chip, under the picture and over the words; no other card has one
	{ "StorePassesPerk", function()
		UI.store.preview(storePrices(true), {})
		UI.open("Store")
		press("CatCafeModals", "passes")
		assertStoreCards(false)
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local window = modals and modals:FindFirstChild("Store", true)
		local list = window and window:FindFirstChild("List", true)
		local chips: { [string]: boolean } = {}
		for _, label in (list :: Instance):GetDescendants() do
			if not (label:IsA("TextLabel") and label.Name == "Name" and label.Visible) then
				continue
			end
			local card = label.Parent :: Frame
			local perk = card:FindFirstChild("Perk") :: TextLabel?
			local effect = card:FindFirstChild("Effect") :: TextLabel
			local shown = perk ~= nil and perk.Visible
			if label.Text == "Cat Accessories" or label.Text == "Uniform Styles" then
				assert(shown and (perk :: TextLabel).Text == "+15% money", "uigate: the " .. label.Text .. " card has no +15% money chip (#2147)")
				local chip = perk :: TextLabel
				assert(chip.TextFits, "uigate: the +15% chip's words do not fit (#2147)")
				assert(effect.AbsolutePosition.Y >= chip.AbsolutePosition.Y + chip.AbsoluteSize.Y, "uigate: the " .. label.Text .. " words sit on the chip (#2147)")
				assert(chip.AbsolutePosition.Y >= label.AbsolutePosition.Y + label.AbsoluteSize.Y - 1, "uigate: the chip sits on the name (#2147)")
				local cardRight = card.AbsolutePosition.X + card.AbsoluteSize.X
				assert(chip.AbsolutePosition.X + chip.AbsoluteSize.X <= cardRight, "uigate: the chip runs off the card (#2147)")
				chips[label.Text] = true
			else
				assert(not shown, "uigate: the " .. label.Text .. " card has a perk chip (#2147)")
			end
		end
		assert(chips["Cat Accessories"] and chips["Uniform Styles"], "uigate: an outfit pass card is missing (#2147)")
		-- 7.3: the prompt says Cat Accessories was just bought: the thank-you toast (the sparkle is Animation's)
		local Config = UIShim.require("ReplicatedStorage.Shared.Config")
		local PassShop = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Components.PassShop")
		PassShop.purchased:Fire(Config.CatAccessoriesPassId)
		local toast = nil
		for _, label in UIShim.playerGui:GetDescendants() do
			if label:IsA("TextLabel") and string.find(label.Text, "Your working cats now earn +15%!", 1, true) then
				toast = label
			end
		end
		assert(toast and toast.Text == "🎀 Your working cats now earn +15%!", "uigate: no +15% toast after buying Cat Accessories (#2147)")
	end },
	-- #2010 (Derek2: "extra food bowl is missing from live game store"): the Cats tab sells the Second Bait Bowl
	{ "StoreCatsBowl", function()
		UI.store.preview(storePrices(true), {})
		UI.open("Store")
		press("CatCafeModals", "cats")
		assertStoreCards(false)
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local window = modals and modals:FindFirstChild("Store", true)
		local list = window and window:FindFirstChild("List", true)
		local found = false
		for _, label in (list :: Instance):GetDescendants() do
			if label:IsA("TextLabel") and label.Name == "Name" and label.Text == "Second Bait Bowl" and label.Visible then
				found = true
			end
		end
		assert(found, "uigate: the Cats tab has no Second Bait Bowl card (#2010)")
	end },
	-- #1425: the Potions tab, each pack with its exact contents and the bag count
	{ "StorePotions", function()
		UI.store.preview(storePrices(true), {})
		UI.open("Store")
		press("CatCafeModals", "potions")
		assertStoreCards(false)
	end },
	-- #1605 (Derek2 11-05: "scrolling down in shop causes it to snap back up"): a scrolled tab keeps its place when the
	-- window renders again on a state change; another tab still starts at the top
	{ "StoreScrollHolds", function()
		UI.store.preview(storePrices(true), {})
		UI.open("Store")
		press("CatCafeModals", "potions")
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local window = modals and modals:FindFirstChild("Store", true)
		local list = window and window:FindFirstChild("List", true) :: ScrollingFrame
		assert(list, "no Store list")
		list.CanvasPosition = Vector2.new(0, 120)
		UI.update(samplePlayer(os.time()))
		UI.store.preview(storePrices(true), {})
		assert(list.CanvasPosition.Y == 120, "the list snapped to " .. list.CanvasPosition.Y)
		press("CatCafeModals", "passes")
		assert(list.CanvasPosition.Y == 0, "a new tab did not start at the top")
	end },
	-- 2x Money and Long Nap owned: the ladder's next rung (3x, in place of x2) and Long Nap marked Owned
	{ "StoreOwned", function()
		local Config = UIShim.require("ReplicatedStorage.Shared.Config")
		UI.store.preview(storePrices(true), { [Config.MoneyPassIds[2]] = true, [Config.LongNapPassId] = true })
		UI.open("Store")
		assertStoreCards(true)
	end },
	-- #1823 (store-layout-v2.md §4): an owned pass keeps its card, greyed, with "✓ Yours" where the price was
	{ "StoreYours", function()
		local Config = UIShim.require("ReplicatedStorage.Shared.Config")
		UI.store.preview(storePrices(true), { [Config.MoneyPassIds[2]] = true, [Config.LongNapPassId] = true })
		UI.open("Store")
		press("Store", "passes")
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local card = modals and modals:FindFirstChild("grid:longNap", true)
		assert(card, "uigate: no Long Nap card on the Passes tab (#1823)")
		local owned = card:FindFirstChild("Owned") :: TextLabel
		local dim = card:FindFirstChild("Dim") :: Frame
		assert(owned and owned.Visible and owned.Text == "✓ Yours", "uigate: the owned Long Nap does not say Yours (#1823)")
		assert(dim and dim.Visible, "uigate: the owned Long Nap is not greyed (#1823)")
	end },
	-- #1823 section 4: a New dot on each rail tab not opened since it gained an item and on the HUD's Store tile;
	-- opening a tab clears its dot and tells the server once, and the tile's dot goes when every tab is seen
	{ "StoreNewDots", function()
		UI.store.preview(storePrices(true), {})
		-- every tab seen first, so tabs an earlier scene opened (sent as seen, never saved here) start fresh
		local allSeen = { featured = 1, passes = 1, cats = 1, potions = 1, cafePass = 1, codes = 1 }
		UI.update({ storeSeen = allSeen } :: any)
		UI.update({ storeSeen = { featured = 1 } } :: any)
		local hud = UIShim.playerGui:FindFirstChild("CatCafeHUD")
		local hudRoot = hud and hud:FindFirstChild("Root")
		local menu = hudRoot and hudRoot:FindFirstChild("Menu") -- on touch the tile is the grid's first square
		local tile = hudRoot and (hudRoot:FindFirstChild("Store") or (menu and menu:FindFirstChild("Store")))
		local tileDot = tile and tile:FindFirstChild("NewDot")
		assert(tileDot and (tileDot :: GuiObject).Visible, "uigate: the HUD's Store tile has no New dot (#1823)")
		local sent: { string } = {}
		local connection = UI.events.storeSeen:Connect(function(tab: string)
			table.insert(sent, tab)
		end)
		UI.open("Store")
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local rail = modals and modals:FindFirstChild("Rail", true)
		local function dot(tab: string): boolean
			local button = rail and rail:FindFirstChild(tab)
			local found = button and button:FindFirstChild("NewDot")
			assert(found, "uigate: the " .. tab .. " rail button has no New dot (#1823)")
			return (found :: GuiObject).Visible
		end
		assert(not dot("featured"), "uigate: Featured was seen but shows a New dot (#1823)")
		assert(dot("passes") and dot("cats"), "uigate: unseen tabs show no New dot (#1823)")
		press("Store", "passes")
		assert(not dot("passes"), "uigate: opening Passes did not clear its New dot (#1823)")
		assert(table.concat(sent, ",") == "passes", "uigate: MarkStoreSeen sent " .. table.concat(sent, ","))
		press("Store", "featured")
		press("Store", "passes")
		assert(#sent == 1, "uigate: Passes was sent as seen twice (#1823)")
		connection:Disconnect()
		UI.update({ storeSeen = allSeen } :: any)
		assert(not (tileDot :: GuiObject).Visible, "uigate: the Store tile's New dot stays with every tab seen (#1823)")
		press("Store", "cats")
	end },
	-- #1168 row 8: the Steady Paw Pack on the Potions tab, its card saying what is in it
	{ "StoreSteadyPaw", function()
		UI.store.preview(storePrices(true), {})
		UI.open("Store")
		press("Store", "potions")
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local card = modals and modals:FindFirstChild("grid:steadyPaw", true)
		assert(card and card.Visible, "uigate: no Steady Paw Pack card on the Potions tab (#1168)")
	end },
	-- #1823: a pass the server confirms while the Store is open gets Animation's pop (StoreMotion) and VFX's burst on
	-- its card, and the card still sits inside the page afterwards
	{ "StoreBoughtMotion", function()
		local Config = UIShim.require("ReplicatedStorage.Shared.Config")
		UI.store.preview(storePrices(true), {})
		UI.open("Store")
		press("Store", "passes")
		UI.store.preview(storePrices(true), { [Config.VipPassId] = true })
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local card = modals and modals:FindFirstChild("grid:vip", true)
		assert(card, "uigate: no VIP card on Passes (#1823)")
		assert(card:FindFirstChildOfClass("UIScale"), "uigate: the bought VIP card did not pop (StoreMotion, #1823)")
		assertStoreCards(false)
	end },
	-- #1875: the Jukebox is free, so no Jukebox Pass card shows on Passes even with a pass id set
	{ "StoreNoJukebox", function()
		local Config = UIShim.require("ReplicatedStorage.Shared.Config")
		local was = Config.JukeboxPassId
		Config.JukeboxPassId = 1168002
		UI.store.preview(storePrices(true), {})
		UI.open("Store")
		press("Store", "passes")
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		assert(modals and modals:FindFirstChild("grid:jukebox", true) == nil, "uigate: a Jukebox Pass card on Passes (#1875)")
		assertStoreCards(false)
		Config.JukeboxPassId = was
	end },
	-- #1168: the Thank You Badge (a product, reads Yours for a supporter, #2073) and the Sign Style Pack (a pass, hidden at 0)
	-- on the Passes tab, each saying what it holds
	{ "StoreThankYouSign", function()
		local Config = UIShim.require("ReplicatedStorage.Shared.Config")
		local player = game:GetService("Players").LocalPlayer
		local was = Config.SignStylePackPassId
		Config.SignStylePackPassId = 1168001
		player:SetAttribute("Supporter", nil)
		local prices = storePrices(true)
		prices[1168001] = { robux = 99, forSale = true }
		local badgeId = (Config.ProductIds or {}).thank_you_badge
		if type(badgeId) == "number" and badgeId ~= 0 then
			prices[badgeId] = { robux = 49, forSale = true }
		end
		UI.store.preview(prices, {})
		UI.open("Store")
		press("Store", "passes")
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local sign = modals and modals:FindFirstChild("grid:signStylePack", true)
		assert(sign and sign:IsA("GuiObject") and sign.Visible, "uigate: no Sign Style Pack card on Passes (#1168)")
		if type(badgeId) == "number" and badgeId ~= 0 then
			local thanks = modals and modals:FindFirstChild("grid:thankYou", true)
			assert(thanks and thanks:IsA("GuiObject") and thanks.Visible, "uigate: no Thank You Badge card (#1168)")
			player:SetAttribute("Supporter", true)
			-- #2073: a supporter keeps the card, now reading Yours, instead of it vanishing
			local kept = modals:FindFirstChild("grid:thankYou", true)
			assert(kept and kept:IsA("GuiObject") and kept.Visible, "uigate: a supporter's Thank You Badge card vanished (#2073)")
			player:SetAttribute("Supporter", nil)
		end
		assertStoreCards(false)
		Config.SignStylePackPassId = was
	end },
	-- the passes off sale (as on live until launch): every card says Soon
	{ "StoreSoon", function()
		UI.store.preview(storePrices(false), {})
		UI.open("Store")
		assertStoreCards(true)
	end },
	-- #1167 (Derek 2026-11-04: "the Store UI/menu is missing"): with every pass off sale the HUD's gold Store tile
	-- still shows, and a press on it opens the Store window. A hidden tile or a window that does not open fails here.
	{ "HUDStoreOffSale", function()
		UI.store.preview(storePrices(false), {})
		local hud = UIShim.playerGui:FindFirstChild("CatCafeHUD")
		local hudRoot = hud and hud:FindFirstChild("Root")
		local menu = hudRoot and hudRoot:FindFirstChild("Menu") -- on touch the tile is the grid's first square
		local tile = hudRoot and (hudRoot:FindFirstChild("Store") or (menu and menu:FindFirstChild("Store")))
		assert(tile and tile:IsA("GuiObject") and tile.Visible, "uigate: the HUD's Store tile is hidden (#1167)")
		press("CatCafeHUD", "Store")
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local modalRoot = modals and modals:FindFirstChild("Root")
		local container = modalRoot and modalRoot:FindFirstChild("Container")
		local window = container and container:FindFirstChild("Store")
		assert(window and window:IsA("GuiObject") and window.Visible, "uigate: the Store tile did not open the Store")
		assertStoreCards(true)
	end },
	-- F102: the Trade window's players: Sam to ask, Alex under the minimum tier, Mia busy in a trade
	{ "TradePlayers", function()
		addTradePlayer("Sam", 4242, 4, false)
		addTradePlayer("Alex", 4343, 2, false)
		addTradePlayer("Mia", 4444, 5, true)
		UI.open("Trade")
	end },
	-- F102: Sam's request card
	{ "TradeAsk", function()
		UI.trade.asked("gate_request", 4242, "Sam", workspace:GetServerTimeNow() + 20)
	end },
	-- F102: the offer: three of my cats against Sam's Epic and rainbow Rare, Sam ready; my cats on the right with the
	-- locked gate_2 and the offered ones dimmed
	{ "TradeOffer", function()
		UI.trade.state(tradeState())
	end },
	-- F102: Sam just added a cat: "Changed!" over Sam's side, the new tile flashing, both Ready cleared
	{ "TradeChanged", function()
		local state = tradeState()
		state.them.ready = false
		-- half a second in the future so the 2 s flash is still on when the picture is taken
		state.changed = { side = "them", uid = "sam_2", at = workspace:GetServerTimeNow() + 1.5 }
		UI.trade.state(state)
	end },
	-- F102: both ready, the countdown over the grids
	{ "TradeCountdown", function()
		local state = tradeState({ phase = "countdown", countdownEndsAt = workspace:GetServerTimeNow() + 4 })
		state.me.ready = true
		UI.trade.state(state)
	end },
	-- F102: the confirm screen of a lopsided trade: the red line and Confirm waiting
	{ "TradeConfirm", function()
		local state = tradeState({ phase = "confirm", lopsided = true })
		state.me.ready = true
		UI.trade.state(state)
	end },
	-- F102: a gift: "Nothing" in red under You get and "You get nothing back"
	{ "TradeGift", function()
		local state = tradeState({ phase = "confirm", gift = true, theirRateForMe = 0, getValue = 0 })
		state.them.cats = {}
		UI.trade.state(state)
	end },
	-- F102 part 2: Settings ends with the Trading section once TradeService runs: Friends only picked, then Trades
	{ "SettingsTrading", function()
		workspace:SetAttribute("TradingOn", true)
		local settings = UIShim.require("ReplicatedStorage.Shared.Settings").defaults()
		settings.tradeRequests = "friends"
		UI.update({ settings = settings })
		UI.open("Settings")
		local modals = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("CatCafeModals")
		local panel = modals and modals:FindFirstChild("Settings", true)
		local list = panel and panel:FindFirstChild("List", true)
		if list and list:IsA("ScrollingFrame") then
			list.CanvasPosition = Vector2.new(0, 100000) -- scrolled to the end, where the section is
		end
	end },
	-- F102 part 2: the Trades page: a trade 12 minutes ago, a gift yesterday, nine cats each way 4 days ago
	{ "TradeLog", function()
		UI.update({ tradeLog = tradeLog(os.time()) })
		UI.open("TradeLog")
	end },
	{ "TradeLogEmpty", function()
		UI.update({ tradeLog = {} })
		UI.open("TradeLog")
	end },
	-- testers (Derek's notes): Settings' Testers section with Reset my save, scrolled to the end where it sits, and
	-- the confirm card its Reset opens
	{ "SettingsTester", function()
		game:GetService("Players").LocalPlayer:SetAttribute("Tester", true)
		UI.open("Settings")
		local modals = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("CatCafeModals")
		local panel = modals and modals:FindFirstChild("Settings", true)
		local list = panel and panel:FindFirstChild("List", true)
		if list and list:IsA("ScrollingFrame") then
			list.CanvasPosition = Vector2.new(0, 100000)
		end
	end },
	{ "SettingsResetConfirm", function()
		game:GetService("Players").LocalPlayer:SetAttribute("Tester", true)
		UI.open("Settings")
		press("Settings", "resetSave.Open")
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
	reel(false)
	if Scenes._tradeTier ~= nil then
		UI.update(Scenes._tradeTier :: any) -- #2462's scene
		Scenes._tradeTier = nil
	end
	if Scenes._rescueSpot ~= nil then
		Scenes._rescueSpot:Destroy() -- #2214's rescue scene
		Scenes._rescueSpot = nil
	end
	if Scenes._spinWheel ~= nil then
		Scenes._spinWheel:Destroy() -- #2358's scene
		Scenes._spinWheel = nil
	end
	if Scenes._spinState ~= nil then
		UI.update(Scenes._spinState :: any) -- #2345 and #2358's scenes
		Scenes._spinState = nil
	end
	if Scenes._market ~= nil then
		Scenes._market.stall:Destroy() -- #2214's scene
		UI.update({ crates = Scenes._market.crates, storeSeen = Scenes._market.seen or {} } :: any)
		Scenes._market = nil
	end
	if Scenes._giftPlot ~= nil then
		Scenes._giftPlot:Destroy() -- #2614's scene
		Scenes._giftPlot = nil
		UI.giftWait.start()
		UIShim.advance(5) -- the gift card closes by itself
	end
	if Scenes._cashMoney ~= nil then
		UI.update(Scenes._cashMoney :: any) -- #2194's scene
		Scenes._cashMoney = nil
	end
	if UI.intro.playing() then
		UI.intro.finish() -- #2182's Next scene
	end
	if Scenes._potionsFolded then
		-- #2090: the potions back out for the other scenes
		local folded = Scenes._potionsFolded:FindFirstChild("Folded")
		if folded and folded.Visible then
			press("CatCafeHUD", "PotionTimers.Folded")
		end
		Scenes._potionsFolded = nil
	end
	if Scenes._rallyPeek then
		Scenes._rallyPeek = nil
		UI.rally.update(rallyState({ active = false, endsAt = 0, startsAt = 0 })) -- #2098: the banner put away
	end
	if Scenes._tackle then
		Scenes._tackle = nil
		UI.shove.setEnabled(false) -- #2510's Tackle button
	end
	if Scenes._rallyFace then
		Scenes._rallyFace:Destroy() -- #2078's board face
		Scenes._rallyFace = nil
	end
	if Scenes._eventFace then
		Scenes._eventFace.boards:destroy() -- #2487's board face
		Scenes._eventFace.gui:Destroy()
		Scenes._eventFace.model:Destroy()
		Scenes._eventFace = nil
	end
	if Scenes._cafeEvent then
		Scenes._cafeEvent = nil
		game:GetService("ReplicatedStorage"):SetAttribute("EventId", "") -- #2487: the party put away
		UI.cafeEvent.forget()
		UI.cafeEvent.tick()
	end
	if UI.recap.card and UI.recap.card:isShowing() then
		UI.recap.card:hide() -- #1920
	end
	if Scenes._settings then
		UI.update({ settings = Scenes._settings } :: any) -- #1955's Auto Equip scene
		Scenes._settings = nil
	end
	if UI.gift.card and UI.gift.card:isShowing() then
		UI.gift.card:hide() -- #1947
	end
	if Scenes._returnHook then
		Scenes._returnHook = nil
		local current: any = UI.getState()
		current.returnHook = nil -- #2123's welcome back scene
	end
	if Scenes._quiet then
		local before = Scenes._quiet
		Scenes._quiet = nil
		UI.update({ playSeconds = false, passBoosts = before.passBoosts } :: any) -- #1936's quiet badge scene
	end
	if Scenes._passXp then
		-- #2070's pass XP scene: the pass closed again and the S prize as it was
		UI.pass.set(nil)
		Scenes._achievementPrizes.S.passXp = Scenes._passXp.small
		Scenes._passXp = nil
	end
	if Scenes._lawnOwned then
		UI.update({ lawnOwned = Scenes._lawnOwned } :: any) -- #2075's lawn rarity scene
		Scenes._lawnOwned = nil
	end
	if Scenes._decorOwned ~= nil then
		UI.update({ decorOwned = Scenes._decorOwned } :: any) -- #2053's rarity tint scene
		Scenes._decorOwned = nil
	end
	if Scenes._rankTier ~= nil then
		UI.update({ tier = Scenes._rankTier } :: any) -- #2121's Tier 2 rank-up scene
		Scenes._rankTier = nil
	end
	if Scenes._feedBefore then
		UI.update({ catFood = Scenes._feedBefore.catFood or {} } :: any) -- #2418's CatsFeed: the Bag's food back
		Scenes._feedBefore = nil
	end
	if Scenes._crew then
		UI.update(Scenes._crew :: any) -- #2047's extra slots scene: the sample cats, tier and no extra slots back
		Scenes._crew = nil
	end
	if Scenes._fewCats then
		Scenes._fewCats = nil
		UI.update({ collection = samplePlayer(os.time()).collection }) -- #1919's nudge scenes
	end
	UI.close()
	UI.pals({}) -- F92: no pals, which also takes a pal's marker and Cannon tag away
	UI.campExtras.update(campExtras(0, false, false)) -- F100: every camp extra shut, so other Cannon scenes stay as they were
	if game:GetService("Players").LocalPlayer:GetAttribute("GoldenPondPass") ~= nil then
		-- #1463: no Golden Pond owner outside its scene, and the sample player's Tier 3 back
		game:GetService("Players").LocalPlayer:SetAttribute("GoldenPondPass", nil)
		UI.update({ tier = 3 })
	end
	UI.rally.update(rallyState({ active = false, endsAt = 0, startsAt = workspace:GetServerTimeNow() + 3 * 86400 })) -- F101: no Rally
	UI.trade.state(nil) -- F102: no trade, no TradeService, and the other players leave
	UI.setCarrying(nil) -- no carry banner
	UI.store.preview({}, {}) -- no pass on sale or owned (the HUD's Store tile shows either way, #1167)
	UI.bait.set(nil, 2) -- #1161: one bowl again, empty
	UI.bait.set(nil, 1)
	UI.bait.setSecond(nil)
	if workspace:GetAttribute("TradingOn") ~= nil then
		workspace:SetAttribute("TradingOn", nil)
		-- the HUD drops its Trade tile again, and Trade requests (SettingsTrading) goes back to its default; only
		-- the TradeLog scenes read tradeLog, and each sets its own
		UI.update({ settings = UIShim.require("ReplicatedStorage.Shared.Settings").defaults() })
	end
	for _, player in tradePlayers do
		player:Destroy()
	end
	table.clear(tradePlayers)
	UI.catch.hideCircles()
	UI.catch.hide()
	UI.rescue.hide()
	UI.net.setEnabled(false)
	UI.setZone(nil)
	UI.tips.reset()
	UI.tutorial.hide()
	local me = game:GetService("Players").LocalPlayer
	if me:GetAttribute("Tester") ~= nil then
		me:SetAttribute("Tester", nil) -- the Testers section hides again
	end
	-- the HUD's Rewards or Menu list closes with another press of the tile that opened it
	local hudGui = UIShim.playerGui:FindFirstChild("CatCafeHUD")
	local pop = hudGui and hudGui:FindFirstChild("Pop", true)
	if pop and pop.Visible then
		press("CatCafeHUD", if pop:FindFirstChild("Settings") then "Icons.Menu" else "Icons.Rewards")
	end
	-- the help card waits for Got it
	local ask = UIShim.playerGui:FindFirstChild("CatCafeAsk")
	if ask and ask:FindFirstChild("Choice_ok", true) and ask:FindFirstChild("Card", true).Visible then
		press("CatCafeAsk", "Choice_ok")
	end
	-- F92: the invite nudge's Not now
	if ask and ask:FindFirstChild("Choice_later", true) and ask:FindFirstChild("Card", true).Visible then
		press("CatCafeAsk", "Choice_later")
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
