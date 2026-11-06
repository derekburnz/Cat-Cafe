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
	local count = tile:FindFirstChild("Count")
	assert(count and count.Visible, "uigate: the HUD bowl tile has no 2 with two bowls (#1161)")
	local mark = tile:FindFirstChild("Claim")
	assert(mark and mark.Visible == catWaiting, "uigate: the HUD bowl tile's ! is wrong for a waiting cat (#1161)")
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
	end },
	{ "Decor", function()
		UI.open("Decor")
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
		-- #1729: the big-spot Garden Bench has the small "Big spot" tag, the small-spot Tulip Bed none
		local bench = lawn and lawn:FindFirstChild("garden_bench", true)
		local tulips = lawn and lawn:FindFirstChild("tulip_bed", true)
		assert(bench and bench:FindFirstChild("BigSpot"), "uigate: the Garden Bench card has no Big spot tag (#1729)")
		assert(tulips and tulips:FindFirstChild("BigSpot") == nil, "uigate: the Tulip Bed card has a Big spot tag (#1729)")
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
		} :: any)
		UI.open("Decor")
		press("Decor", "Style")
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local row = modals and modals:FindFirstChild("music", true)
		assert(row, "uigate: no Cafe music row on the Style tab (#1168)")
		local asked: { string } = {}
		local connection = UI.events.pickStyle:Connect(function(kind: string, id: string)
			table.insert(asked, kind .. ":" .. id)
		end)
		press("Decor", "music.jukebox_starlight_purr")
		press("Decor", "music.Default")
		connection:Disconnect()
		assert(
			table.concat(asked, ",") == "music:jukebox_starlight_purr,music:",
			"uigate: the music row asked " .. table.concat(asked, ",")
		)
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
		local kibble = window:FindFirstChild("kibble", true)
		assert(star and kibble, "uigate: no Star Treat or Kibble row")
		assert(star.LayoutOrder < kibble.LayoutOrder, "uigate: the bowl lists Kibble before the Star Treat (#1609)")
		press("Bait", "star_treat.Details")
		local detail = star:FindFirstChild("Detail", true) :: TextLabel
		assert(detail and detail.Visible, "uigate: Details did not open")
		assert(string.find(detail.Text, "Mythical", 1, true), "uigate: the Details text has no odds: " .. detail.Text)
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
		press("CatCafeBaitCard", "Close") -- the X; See the cat brings it back
		assertBowlTile(true)
		UI.bait.openPicker()
		assertBowlTabs(2, "A cat is at bowl 2!")
		assertBowlAction("See the cat")
		press("Bait", "Bowls.Bowl1")
		assertBowlTabs(1, "is in bowl 1")
	end },
	-- #1161: the cat's card with two bowls names the bowl, and its banner stays clear of the X on a phone
	{ "BaitCardBowl2", function()
		local now = workspace:GetServerTimeNow()
		UI.bait.setSecond("on")
		UI.bait.set({ lureId = Catalog.lures[2].id, readyAt = now - 5, placedAt = now - 300 }, 2)
		UI.bait.showReady({ catId = Catalog.cats[2].id, stars = 2 }, 2)
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
		count = count and count:FindFirstChild("Count")
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
	end },
	{ "Settings", function()
		UI.open("Settings")
	end },
	{ "TipJar", function()
		UI.tipJar.open()
	end },
	-- #1646: the Cafe Pass at level 4 with level 2's free spin claimed, the paid track locked
	{ "CafePass", function()
		UI.pass.set({ season = 1, startsAt = 0, endsAt = 1798934400, level = 4, xp = 3500, xpPerLevel = 800,
			levels = 30, paid = false, claimedFree = { 2 }, claimedPaid = {}, claimable = 1, items = {} })
		UI.pass.open()
		local modals = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("CatCafeModals")
		local window = modals and modals:FindFirstChild("CafePass", true)
		assert(window and window:IsA("GuiObject") and window.Visible, "uigate: the Cafe Pass is not open")
		local level4 = window:FindFirstChild("Level4", true)
		local claim = level4 and level4:FindFirstChild("Free") and level4.Free:FindFirstChild("Claim")
		assert(claim and claim:IsA("GuiObject") and claim.Visible, "uigate: level 4's free reward has no Claim")
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
		assert(prize and string.find(prize.Text, "^Jackpot: 100 golden fish"), "uigate: slice 8 is not the fish jackpot")
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
	-- F99 section 2: a rainbow stray's once-a-minute toast on a turning rainbow edge
	{ "RainbowSpawn", function()
		UI.rainbowSpawned(firstArea(), Catalog.cats[10].id)
	end },
	{ "Potions", function()
		UI.open("Potions")
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
	end },
	{ "Quests", function()
		UI.open("Quests")
	end },
	-- #1573: a tap on an unfinished daily pins it: its row reads "📌 ..." and the HUD's quest line follows it
	{ "QuestsPinned", function()
		UI.open("Quests")
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local window = modals and modals:FindFirstChild("Quests", true)
		assert(window, "uigate: no Quests window")
		local daily = window:FindFirstChild("Quest1", true).Parent
		local pinnedRow = nil
		for slot = 1, 5 do
			local row = daily:FindFirstChild("Quest" .. slot)
			local claim = row and row:FindFirstChild("Claim", true)
			local check = row and row:FindFirstChild("Check", true)
			if row and row.Visible and not (claim and claim.Visible) and not (check and check.Visible) then
				pinnedRow = row
				press("Quests", "Quest" .. slot .. ".Pin")
				break
			end
		end
		assert(pinnedRow, "uigate: no unfinished daily to pin")
		local title = pinnedRow:FindFirstChild("Title")
		assert(string.sub(title.Text, 1, 4) == "📌", ("uigate: the pinned quest reads %q (#1573)"):format(title.Text))
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
	-- F93: a catch three circles in: Perfect, Good, Perfect, each cleared with its word, the pips filling
	{ "Catch", function()
		local list = startCatch("gate_stray", "Epic", 5, 0, 0.82)
		local t0 = workspace:GetServerTimeNow()
		for index, delay in { 0, 0.06, 0 } do
			local target = list[index].startsAt + list[index].shrinkSeconds
			task.delay(target - t0 + delay, tapCircles)
		end
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
	{ "CatchPromptCatch", function()
		UI.catch.show({
			strayId = "gate_stray",
			catId = Catalog.cats[2].id,
			catName = "Mochi",
			rarity = "Epic",
			holdDuration = 0.5,
		})
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
	-- #1796: tutorial step 3 asks for a table: the HUD's Upgrades tile and the table row in Upgrades glow; step 4 moves
	-- the glow to the Bait bowl row
	{ "TutorialUpgradeGlow", function()
		local levels = { tables = 0, lure_bowl = 0, espresso = 0, net = 0, lucky_cat = 0 }
		UI.update({ tutorialStep = 3, tier = 1, upgradeLevels = levels } :: any)
		UI.tutorial.show(UI.tutorial.hint({ tutorialStep = 3, tier = 1, cats = {}, upgradeLevels = levels }))
		local hud = UIShim.playerGui:FindFirstChild("CatCafeHUD")
		local tile = hud and hud:FindFirstChild("Upgrades", true)
		assert(tile and tile:FindFirstChild("TutorialGlow"), "uigate: the Upgrades tile does not glow at step 3 (#1796)")
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
	-- F87 section 2g: "Need a hand?" after 90 s on one tutorial step
	{ "HelpCard", function()
		UI.tutorial.showHelp()
	end },
	{ "CatFound", function()
		UI.showCatFound(Catalog.cats[2].id, true)
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
		UI.rally.update(rallyState({ lap = 2, points = 50, myPoints = 7 }))
	end },
	-- F101: this player's laps used up this weekend, the bar nearly full
	{ "RallyBannerDone", function()
		UI.rally.update(rallyState({ lap = 5, points = 85, myPoints = 12, lapsPaid = 4, lapsDone = true }))
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
		UI.rally.update(rallyState({ points = 30, myPoints = 2 }))
	end },
	-- F101 (review S113): a rescue during a Rally: the banner steps aside, so the rescue bar's header is clear
	{ "RallyRescue", function()
		UI.rally.update(rallyState({ lap = 2, points = 50, myPoints = 7 }))
		UI.rescue.show("gate_rescue", rescueChallenge())
	end },
	-- F101: Friday, 5 h 20 m before the Rally: the countdown under the clock and no banner
	{ "RallySoon", function()
		local t = workspace:GetServerTimeNow()
		UI.rally.update(rallyState({ active = false, endsAt = 0, startsAt = t + 5 * 3600 + 1200 }))
	end },
	-- F102: TradeService runs, so the HUD's top row holds seven tiles with Trade before Invite (review N334)
	{ "HUDTrade", function()
		workspace:SetAttribute("TradingOn", true)
		UI.update({ tier = 3 })
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
	-- 2x on sale, "3x" once owned
	{ "HUDMoneyBadge", function()
		UI.store.preview(storePrices(true), {})
	end },
	{ "HUDMoneyBadgeOwned", function()
		local Config = UIShim.require("ReplicatedStorage.Shared.Config")
		UI.store.preview(storePrices(true), { [Config.MoneyPassIds[3]] = true })
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
	-- #1425: the Passes tab, a grid of pass cards 3 across
	{ "StorePasses", function()
		UI.store.preview(storePrices(true), {})
		UI.open("Store")
		press("CatCafeModals", "passes")
		assertStoreCards(false)
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
	-- #1168: the Thank You Badge (a product, hidden for a supporter) and the Sign Style Pack (a pass, hidden at 0)
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
			local gone = modals:FindFirstChild("grid:thankYou", true)
			assert(gone == nil or not (gone :: GuiObject).Visible, "uigate: a supporter still sees the Thank You Badge (#1168)")
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
