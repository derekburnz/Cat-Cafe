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
		if def.area == "secret" then
			continue -- #3470: the sample player has found no Secret cat
		end
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
	-- #3307: the tips clock reads real seconds, so on a long full run (the big tablets take about an hour) it put the
	-- session ask or the faces ask up on its own part way through, and that ask held the tip card for the tip scenes
	-- after it ("did not show"). Both count as done today here; their own scenes open them by hand.
	local SessionFeedback = UIShim.require("ReplicatedStorage.Shared.SessionFeedback") :: any
	UI.update({ feedbackAsked = true, sessionFeedbackDay = SessionFeedback.day(now) } :: any)
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

-- A scene that needs the player at `tier` whatever the scenes before it left (the Cannon picker locks an area the
-- tier has not opened, and several earlier scenes end on Tier 1 or 2): sets it, and Scenes.close puts back the tier
-- the scene found (#3082: CannonExtras failed in CI once main's scene order moved).
-- #3615: camp extras with the Yard Sale's lucky pick rows for `tier` (shared/YardPick); `taken` puts the next pick
-- 1 h 20 m off.
local function yardPickExtras(tier: number, taken: boolean)
	local extras = campExtras(0, taken)
	extras.yardSale.pick = UIShim.require("ReplicatedStorage.Shared.YardPick").rows(tier)
	extras.yardSale.held = if taken then 0 else 1
	extras.yardSale.nextAt = if taken then workspace:GetServerTimeNow() + 80 * 60 else nil
	return extras
end

local function yardPickCard()
	local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
	local card = modals and modals:FindFirstChild("YardSale", true)
	assert(card and card.Visible, "uigate: the Yard Sale card is not up (#3615)")
	return card
end

local function atTier(tier: number)
	if Scenes._rankTier == nil then
		Scenes._rankTier = (UI.getState() :: any).tier
	end
	UI.update({ tier = tier } :: any)
end

-- #2651 part 4: LateStationsState for the Oasis Spa and Relic Museum cards. `soak` is how long the cat in slot 1 has
-- soaked (nil: slot 1 empty); slot 2 is open and empty, slot 3 waits to be bought. Two Alleyway exhibits are given.
local function lateState(soak, live)
	local now = workspace:GetServerTimeNow()
	local hour = 3600
	local soaking = {
		{ slot = 1 },
		{ slot = 2 },
	}
	if soak ~= nil then
		local at = now - soak
		soaking[1] = {
			slot = 1,
			uid = "gate_5",
			catId = (UI.getState() :: any).cats.gate_5.catId,
			doneAt = at + hour,
			fullAt = at + 24 * hour,
			levels = math.floor(soak / hour),
		}
	end
	local LateStations = UIShim.require("ReplicatedStorage.Shared.LateStations")
	local alley = LateStations.rooms[1].cats
	return {
		live = live ~= false,
		spa = {
			open = true,
			slots = 2,
			nextPrice = 250,
			soaking = soaking,
			ready = if soak ~= nil and soak >= hour then 1 else 0,
		},
		museum = {
			open = true,
			filled = { [alley[9]] = "base", [alley[10]] = "gold" },
			count = 2,
			total = LateStations.EXHIBITS,
			canFill = 1,
			rooms = {},
			bonus = 0,
		},
	}
end

-- #2651 part 4: the sample cats plus spare copies of gate_4's cat (one gold), so a Museum exhibit can be filled
-- (Scenes.close puts the sample cats back)
local function lateCats()
	local cats = table.clone((UI.getState() :: any).cats)
	local base = cats.gate_4
	for index, variant in { "base", "gold", "base" } do
		local copy = table.clone(base)
		copy.uid = "gate_spare" .. index
		copy.variant = variant
		copy.spotId = nil
		copy.locked = false
		copy.level = index * 3
		cats[copy.uid] = copy
	end
	Scenes._lateCats = true
	UI.update({ cats = cats })
end

-- #3196: the Mystic Pool's card open on `uid` (nil: no cat picked), gate_1 holding a Legendary trait. `waiting` is a
-- re-roll waiting for its choice; `view` replaces the station's numbers.
local function mysticPool(waiting, uid, view)
	local cats = table.clone((UI.getState() :: any).cats)
	cats.gate_1 = table.clone(cats.gate_1)
	cats.gate_1.trait = { id = "goldenWhiskers" }
	view = view or { tokens = 2, freeLeft = 0, held = 1 }
	view.pending = waiting
	UI.update({ cats = cats, goldenFish = 34, traits = view } :: any)
	Scenes._poolTraits = true
	UI.close()
	assert(UI.mysticPool.open(true, uid), "uigate: the Mystic Pool did not open (#3196)")
	assert(UI.isOpen() == "MysticPool", "uigate: the Mystic Pool's ring opened " .. tostring(UI.isOpen()) .. " (#3196)")
	local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
	return modals:FindFirstChild("MysticPool", true)
end

-- #3296: Mouse Dash's card open with its switch on; `circle` whether Circle Streak is still playable beside it.
local function mouseDashCard(circle)
	UI.close()
	UI.update({ goldenFish = 12 } :: any)
	UI.mouseDash.setFlags(true, circle)
	UI.mouseDash.state({
		loaded = true,
		best = 37,
		bestSeconds = 30,
		today = { 10, 20 },
		legend = false,
		mouser = true,
		free = true,
		firstRun = false,
		top = {
			{ rank = 1, name = "Sam", points = 61, seconds = 55 },
			{ rank = 2, name = "You", points = 37, seconds = 30, me = true },
		},
	})
	UI.arcade.open()
	assert(UI.isOpen() == "MouseDash", "uigate: with mouseDash on the cabinet opened " .. tostring(UI.isOpen()) .. " (#3296)")
	return UIShim.playerGui:FindFirstChild("CatCafeModals"):FindFirstChild("MouseDash", true)
end

local function lateWindow(name)
	local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
	local window = modals and modals:FindFirstChild(name, true)
	assert(window, "uigate: no " .. name .. " window (#2651)")
	return window
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
	local function mine(uid, rate, trait)
		local cat = samplePlayer(workspace:GetServerTimeNow()).cats[uid]
		local def = Catalog.getCat(cat.catId)
		return {
			uid = uid,
			catId = cat.catId,
			rarity = def and def.rarity or "Common",
			variant = if cat.variant == "gold" then "gold" else nil,
			level = cat.level,
			rateForMe = rate,
			trait = trait,
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
			-- #3710: a Legendary trait on my first cat and a Rare one on Sam's second
			cats = {
				mine("gate_1", 12, { id = "goldenWhiskers" }),
				mine("gate_3", 110),
				mine("gate_5", 62),
			},
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
					trait = { id = "bigTipper_rare" },
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
	-- #2885: the lines are in the status banner (under the counters on touch, under the clock on a PC), which must not
	-- cover the goal card
	local goal = hud:FindFirstChild("TierGoal", true) :: GuiObject?
	local banner = hud:FindFirstChild("StatusBanner", true) :: GuiObject
	assert(banner and banner.Visible and chip:IsDescendantOf(banner), "uigate: the Cafe Event chip is not in the status banner (#2885)")
	if goal and goal.Visible then
		local a, as = banner.AbsolutePosition, banner.AbsoluteSize
		local g, gs = goal.AbsolutePosition, goal.AbsoluteSize
		local apart = a.X + as.X <= g.X + 1 or g.X + gs.X <= a.X + 1 or a.Y + as.Y <= g.Y + 1 or g.Y + gs.Y <= a.Y + 1
		assert(apart, "uigate: the Cafe Event chip runs into the goal card (#2487)")
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
-- #3153: the tutorial's spotlight while it shows (Components/TutorialArrow), or nil
local function tutorialSpotlight(): Frame?
	for _, piece in UIShim.playerGui:GetDescendants() do
		if piece.Name == "TutorialSpotlight" and piece:IsA("Frame") and piece.Visible then
			return piece
		end
	end
	return nil
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
	local gui = arrow:FindFirstAncestorWhichIsA("ScreenGui") :: ScreenGui
	local screen = gui.AbsoluteSize
	-- #3154: a ScreenGui that keeps clear of Roblox's top bar may still draw up in it
	local bar = if gui.IgnoreGuiInset then 0 else (game:GetService("GuiService"):GetGuiInset()).Y
	assert(
		a0.X >= -1 and a0.Y >= -1 - bar and a1.X <= screen.X + 1 and a1.Y <= screen.Y + 1,
		("uigate: the arrow at %s runs off the screen (%d,%d to %d,%d) (#2314)"):format(where, a0.X, a0.Y, a1.X, a1.Y)
	)
	local overlaps = a0.X < t1.X - 1 and t0.X < a1.X - 1 and a0.Y < t1.Y - 1 and t0.Y < a1.Y - 1
	assert(not overlaps, "uigate: the arrow covers " .. where .. " (#2314)")
	local gap = math.max(t0.X - a1.X, a0.X - t1.X, t0.Y - a1.Y, a0.Y - t1.Y)
	assert(gap < 24, ("uigate: the arrow sits %d px from %s (#2314)"):format(gap, where))
end
-- #2697: step 2 with every sample cat resting at Tier 1 (Scenes.close puts the crew back)
local function stepTwoResting()
	local before = UI.getState() :: any
	Scenes._crew = { cats = before.cats, tier = before.tier, extraSlots = before.extraSlots or 0 }
	local cats = {}
	for uid, cat in before.cats do
		local copy = table.clone(cat)
		copy.spotId = nil
		cats[uid] = copy
	end
	UI.update({ tutorialStep = 2, tier = 1, extraSlots = 0, cats = cats } :: any)
	UI.tutorial.show(UI.tutorial.hint(UI.getState()) or "Tap Cats and give your new cat a job")
	task.wait(0.1)
end
-- #2697: step 4 with the Bait bowl owned and empty and Kibble in the bag
local function stepFourFood()
	local before = UI.getState() :: any
	Scenes._stepState = { upgradeLevels = before.upgradeLevels, lures = before.lures, bait = before.bait }
	local levels = table.clone(before.upgradeLevels or {})
	levels.lure_bowl = math.max(levels.lure_bowl or 0, 1)
	-- #3285: an empty bowl is false in the UI's state (UIController), as UI.update skips a nil
	UI.update({ tutorialStep = 4, upgradeLevels = levels, lures = { kibble = 3 }, bait = false } :: any)
	UI.bait.set(nil)
	UI.tutorial.show(UI.tutorial.hint(UI.getState()) or "Tap the Bait bowl and put Kibble in it")
	task.wait(0.1)
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

-- #3611: roll boards side by side on the screen, each at the size BinController's billboard gives it here
local function binBoards(list: { { view: { [string]: any }, lit: number? } })
	local RollBoard = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Components.RollBoard")
	local RollBoardLogic =
		UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Components.RollBoardLogic")
	local Scale = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Scale")
	local gui = Instance.new("ScreenGui")
	gui.Name = "BinBoardGate"
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 100 -- over the HUD, so the shot shows the boards
	gui.Parent = UIShim.playerGui
	Scenes._binBoards = gui
	local share = math.max(0.66, Scale.billboard(1000) / 1000)
	local gap = 8
	local width = RollBoard.WIDTH * share
	local total = #list * width + (#list - 1) * gap
	local view = workspace.CurrentCamera.ViewportSize
	assert(total <= view.X, "uigate: the roll boards do not fit this screen side by side (#3611)")
	for index, entry in list do
		local input: { [string]: any } = { uses = 3, nextAt = 0, now = 1000 }
		for key, value in entry.view do
			input[key] = value
		end
		local made = RollBoardLogic.bin(input)
		local holder = Instance.new("Frame")
		holder.Name = "Board" .. index
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0, 0.5)
		holder.Position = UDim2.new(0.5, -total / 2 + (index - 1) * (width + gap), 0.5, 0)
		holder.Size = UDim2.fromOffset(width, RollBoard.height(made) * share)
		holder.Parent = gui
		local board = RollBoard.new(holder)
		local scale = Instance.new("UIScale")
		scale.Scale = share
		scale.Parent = board.frame
		board:set(made)
		board:light(entry.lit)
		assert(
			RollBoard.height(made) * share <= view.Y,
			"uigate: a roll board is taller than this screen (#3611)"
		)
		local rows = 0
		for _, child in board.frame:GetChildren() do
			if child:IsA("Frame") then
				rows += 1
			end
		end
		assert(rows == #made.rows, "uigate: the roll board drew " .. rows .. " rows (#3611)")
	end
end

-- #3050: the Rummage Bin's bar as an early rummage gets it: 2 hits, wide zones, a slow marker
local function binChallenge()
	local t = workspace:GetServerTimeNow()
	return {
		kind = "bar",
		startsAt = t - 1,
		phase = 0.3,
		speed = 0.4,
		zoneWidth = 0.4,
		zones = { 0.35, 0.7 },
		hitsNeeded = 2,
		paws = 3,
		endsAt = t + 20,
		zone = 1,
		zoneEndsAt = t + 20,
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

-- #3633: the rich tip's gold bubble as it floats over a money bag, drawn on the screen so the gate can see it (a
-- BillboardGui is not drawn here): one with a single bag waiting and one with two. Each is the real screen bound to
-- a made-up plot, its bubble and button moved into a frame of the billboard's own size.
local function richTipBubbles()
	local RichTip = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Screens.RichTip")
	local gui = Instance.new("ScreenGui")
	gui.Name = "RichTipGate"
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 100 -- over the HUD, so the shot shows the bubbles
	gui.Parent = UIShim.playerGui
	Scenes._richTipGate = { gui = gui, made = {} }
	local now = workspace:GetServerTimeNow()
	local frames = {}
	for index, amounts in { { 187000 }, { 187000, 288000 } } do
		local plot = Instance.new("Model")
		plot.Name = "RichTipGatePlot" .. index
		local anchor = Instance.new("Part")
		anchor.Name = "RichTipAnchor"
		anchor.Anchored = true
		anchor.Parent = plot
		local folder = Instance.new("Folder")
		folder.Name = "RichBags"
		folder.Parent = plot
		for serial, amount in amounts do
			local record = Instance.new("Configuration")
			record.Name = "b" .. serial
			record:SetAttribute("Amount", amount)
			record:SetAttribute("ExpiresAt", now + 161 + serial)
			record:SetAttribute("Position", Vector3.new(serial, 0, 0))
			record.Parent = folder
		end
		plot.Parent = workspace
		local tip = RichTip.new(gui, { collect = function() end, collected = function() end, missed = function() end })
		tip:bind(plot)
		table.insert(Scenes._richTipGate.made, tip)
		table.insert(Scenes._richTipGate.made, plot)
	end
	UIShim.advance(0.6)
	local boards = {}
	for _, child in gui:GetChildren() do
		if child:IsA("BillboardGui") then
			table.insert(boards, child)
		end
	end
	assert(#boards == 2, "uigate: the rich tip scene did not make two bubbles (#3633)")
	for index, billboard in boards do
		assert(billboard.Enabled, "uigate: no rich tip bubble for a waiting bag (#3633)")
		local size = billboard.Size
		local holder = Instance.new("Frame")
		holder.Name = "Bubble" .. index
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = UDim2.new(0.5, (index - 1.5) * (size.X.Offset + 24), 0.5, 0)
		holder.Size = UDim2.fromOffset(size.X.Offset, size.Y.Offset)
		holder.Parent = gui
		for _, part in billboard:GetChildren() do
			part.Parent = holder
		end
		table.insert(frames, holder)
	end
	return frames
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
			-- #3518: an iPhone SE is 500 design px tall and gets its two and a half rows; a smaller phone still (a
			-- Galaxy A06's 705 x 338 game view, 451 design px) has the window at the screen's full height with 2.2
			local camera = workspace.CurrentCamera :: Camera
			local least = if camera.ViewportSize.Y / Scale.get() >= 500 then 2.5 else 2
			assert(rows >= least, ("uigate: the Upgrades list shows %.1f rows on a short screen (#2339)"):format(rows))
		end
	end },
	{ "Decor", function()
		UI.open("Decor")
		assertEquipBestInHeader("the All tab")
	end },
	-- #2735 (Derek2: "see which decor images to make more clear/bigger since so many players are on mobile (make sure
	-- they don't go out of bounds tho)"): on touch each Decor card's picture is at least 64 real px tall and each Decor
	-- Index picture at least 60; every piece of a card stays inside its card and every card inside its grid's width
	{ "DecorArtPhone", function()
		local Scale = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Scale")
		local touch = Scale.isTouch()
		local function inside(inner: GuiObject, outer: GuiObject, what: string)
			local a, b = inner.AbsolutePosition, outer.AbsolutePosition
			local ok = a.X >= b.X - 1
				and a.Y >= b.Y - 1
				and a.X + inner.AbsoluteSize.X <= b.X + outer.AbsoluteSize.X + 1
				and a.Y + inner.AbsoluteSize.Y <= b.Y + outer.AbsoluteSize.Y + 1
			assert(ok, "uigate: " .. what .. " runs out of bounds (#2735)")
		end
		UI.open("Decor")
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals") :: Instance
		local window = modals:FindFirstChild("Decor", true) :: Instance
		local grid = window:FindFirstChild("Grid", true) :: ScrollingFrame
		local cards = 0
		for _, card in grid:GetChildren() do
			if card:IsA("Frame") and card.Visible and card:FindFirstChild("Art") then
				cards += 1
				local art = card:FindFirstChild("Art") :: GuiObject
				if touch then
					assert(art.AbsoluteSize.Y >= 64, ("uigate: %s's picture is %d px on a phone (#2735)"):format(card.Name, art.AbsoluteSize.Y))
				end
				for _, name in { "Art", "Name", "Effect", "Rarity", "Owned", "Action" } do
					local piece = card:FindFirstChild(name) :: GuiObject?
					if piece and piece.Visible then
						inside(piece, card, card.Name .. "'s " .. name)
					end
				end
				local x1, x2 = card.AbsolutePosition.X, card.AbsolutePosition.X + card.AbsoluteSize.X
				assert(x1 >= grid.AbsolutePosition.X - 1 and x2 <= grid.AbsolutePosition.X + grid.AbsoluteSize.X + 1, "uigate: the " .. card.Name .. " card sticks out of the grid (#2735)")
			end
		end
		assert(cards > 0, "uigate: no Decor cards")
		UI.close()
		UI.open("Collection")
		press("Collection", "DecorTab")
		local index = modals:FindFirstChild("Collection", true) :: Instance
		local cells = index:FindFirstChild("Cells", true) :: Instance
		local shown = 0
		for _, cell in cells:GetChildren() do
			if cell:IsA("Frame") and cell.Visible then
				shown += 1
				local biggest = 0
				for _, child in cell:GetChildren() do
					if child:IsA("GuiObject") and child.Visible then
						biggest = math.max(biggest, math.min(child.AbsoluteSize.X, child.AbsoluteSize.Y))
						inside(child, cell, "the Index's " .. cell.Name .. " " .. child.Name)
					end
				end
				if touch then
					assert(biggest >= 60, ("uigate: the Index's %s picture is %d px on a phone (#2735)"):format(cell.Name, biggest))
				end
			end
		end
		assert(shown > 0, "uigate: no Decor Index cells")
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
	-- #3572: the Sale badge. Roblox answers the half prices of Config.StoreWasPrice for the King Cat Pack and the Royal
	-- Cat, so their cards show "SALE" with the true old price struck through; a card at its old price shows none
	{ "StoreSale", function()
		local Config = UIShim.require("ReplicatedStorage.Shared.Config")
		local prices = storePrices(true)
		prices[Config.KingPackPassId] = { robux = Config.StoreWasPrice.kingPack.now, forSale = true }
		prices[Config.RoyalCatPassId] = { robux = Config.StoreWasPrice.royalCat.now, forSale = true }
		UI.store.preview(prices, {})
		UI.open("Store")
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local window = modals and modals:FindFirstChild("Store", true)
		assert(window, "uigate: no Store window (#3572)")
		local sale, plain = 0, 0
		for _, item in window:GetDescendants() do
			if item.Name == "Badge" and item:IsA("TextLabel") and item.Visible then
				if string.find(item.Text, "SALE", 1, true) then
					sale += 1
					assert(item.RichText, "uigate: the Sale badge is not rich text, so its old price is not struck (#3572)")
				else
					plain += 1
				end
			end
		end
		assert(sale >= 2, "uigate: the Store shows " .. sale .. " Sale badges, expected the King Cat Pack and the Royal Cat (#3572)")
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
	-- #3722: the tiles are not built at start-up; the quiet build lays them a few a frame while the window is shut
	{ "IndexQuietBuild", function()
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local window = modals and modals:FindFirstChild("Collection", true) :: Instance?
		assert(window, "uigate: no Index window")
		local function tiles(): number
			local count = 0
			for _, each in (window :: Instance):GetDescendants() do
				if each:IsA("TextButton") and each:FindFirstChild("Name") then
					count += 1
				end
			end
			return count
		end
		for _ = 1, 600 do
			UIShim.advance(1 / 60)
		end
		assert(UI.isOpen() ~= "Collection", "uigate: the Index is open before the quiet build check")
		local built = tiles()
		assert(built > 50, ("uigate: the quiet build laid %d tiles in 10 s with the Index shut (#3722)"):format(built))
		UI.open("Collection")
		assert(tiles() == built, "uigate: opening the Index built tiles twice (#3722)")
	end },
	-- #3722: the Decor cards are not built at start-up either; a new catalog empties the grid, and the quiet build
	-- lays the cards a few a frame while the window is shut, so opening it builds none twice
	{ "DecorQuietBuild", function()
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local window = modals and modals:FindFirstChild("Decor", true) :: Instance?
		assert(window, "uigate: no Decor window")
		-- only the main grid's cards: a frame named by a decor id (the Lawn tab's own cards stay through a catalog)
		local ids: { [string]: boolean } = {}
		local DecorPieces = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Components.DecorPieces") :: any
		for _, decor in DecorPieces.all(catalogLikeTheGame()) do
			ids[decor.id] = true
		end
		local function cards(): number
			local count = 0
			for _, each in (window :: Instance):GetDescendants() do
				if each:IsA("Frame") and ids[each.Name] and each:FindFirstChild("Action") then
					count += 1
				end
			end
			return count
		end
		UI.setCatalog(catalogLikeTheGame())
		assert(cards() == 0, ("uigate: setCatalog built %d Decor cards at once (#3722)"):format(cards()))
		for _ = 1, 600 do
			UIShim.advance(1 / 60)
		end
		assert(UI.isOpen() ~= "Decor", "uigate: Decor is open before the quiet build check")
		local built = cards()
		assert(built > 50, ("uigate: the quiet build laid %d Decor cards in 10 s with the window shut (#3722)"):format(built))
		UI.open("Decor")
		assert(cards() == built, "uigate: opening Decor built cards twice (#3722)")
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
	-- #2884 (Derek2: the forever banner "runs out of space and keeps twitching"): with every bonus claimed the pills read
	-- short, measure once and hold still frame after frame (scale, caption and each pill's width), clear of the title's
	-- words and inside the title bar
	{ "IndexPerksBusy", function()
		local before: any = UI.getState()
		local restore = {
			goldLuck = before.goldLuck or 0,
			rainbowLuck = before.rainbowLuck or 0,
			baitSpeed = before.baitSpeed or 0,
			indexRewards = before.indexRewards or {},
		}
		UI.update({
			indexRewards = { rainbow = { rainbow1 = true, rainbow3 = true, rainbow5 = true } },
			goldLuck = 1.25,
			rainbowLuck = 0.75,
			baitSpeed = 0.35,
		})
		UI.open("Collection")
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local row = modals and modals:FindFirstChild("Forever", true) :: Frame?
		assert(row, "uigate: no forever pills row in the Index (#2884)")
		for _ = 1, 5 do
			UIShim.advance(1 / 60)
		end
		assert(
			row.Visible,
			"uigate: the forever pills row is hidden with bonuses claimed (#2884)"
		)
		local scale = row:FindFirstChildOfClass("UIScale") :: UIScale
		local caption = row:FindFirstChild("Caption") :: TextLabel
		local function snapshot(): string
			local parts = { ("%.3f"):format(scale.Scale), tostring(caption.Visible) }
			for _, child in row:GetChildren() do
				if child:IsA("TextLabel") and child.Visible then
					assert(
						not string.find(child.Text, "(", 1, true),
						("uigate: the forever pill %q is not the short form (#2884)"):format(
							child.Text
						)
					)
					table.insert(
						parts,
						child.Name .. "=" .. math.floor(child.AbsoluteSize.X + 0.5)
					)
				end
			end
			table.sort(parts)
			return table.concat(parts, ",")
		end
		local settled = snapshot()
		for _ = 1, 10 do
			UIShim.advance(1 / 60)
			local now = snapshot()
			assert(
				now == settled,
				("uigate: the forever pills still move (%s to %s, #2884)"):format(settled, now)
			)
		end
		local header = row.Parent :: GuiObject
		local title = header:FindFirstChild("Title") :: TextLabel
		local subtitle = header:FindFirstChild("Subtitle") :: TextLabel
		local wordsEnd = title.AbsolutePosition.X
			+ math.max(title.TextBounds.X, subtitle.TextBounds.X)
		assert(
			row.AbsolutePosition.X >= wordsEnd - 1,
			("uigate: the forever pills cover the Index title (row at %d, words end at %d, #2884)"):format(
				row.AbsolutePosition.X,
				wordsEnd
			)
		)
		assert(
			row.AbsolutePosition.X + row.AbsoluteSize.X
				<= header.AbsolutePosition.X + header.AbsoluteSize.X + 1,
			"uigate: the forever pills run past the title bar (#2884)"
		)
		UI.update(restore :: any)
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
	-- #3717: the picked cat's trait on the small detail card: its name with its rarity, then its effects; a cat with
	-- none reads "No trait yet" only while the traits switch is on
	{ "CatsTrait", function()
		local before = (UI.getState() :: any).cats
		Scenes._traitBefore = before -- Scenes.close puts the cats back, so no later scene sees this trait
		local cats = table.clone(before)
		cats.gate_3 = table.clone(cats.gate_3)
		cats.gate_3.trait = { id = "cosmicFortune" }
		UI.update({ cats = cats } :: any)
		Scenes._poolTraits = true
		UI.open("Cats")
		task.delay(0.2, function()
			press("Cats", "gate_3")
			-- the name of the trait shows: in its own row, or on the phone's short sheet beside the Charm line
			local shown = false
			for _, piece in UIShim.playerGui:GetDescendants() do
				if piece:IsA("TextLabel") and piece.Visible and piece.Text:find("Cosmic Fortune", 1, true) then
					shown = true
				end
			end
			assert(shown, "uigate: the detail card does not name the cat's trait (#3717)")
		end)
	end },
	{ "CatsFeed", function()
		local before: any = UI.getState()
		Scenes._feedBefore = { catFood = before.catFood, cats = before.cats }
		UI.update({ catFood = { small_cat_snack = 2, cat_snack = 3, big_cat_snack = 1 } } :: any)
		UI.open("Cats")
		task.wait(0.2)
		press("Cats", "gate_3")
		press("Cats", "Feed") -- #3924: the tiles show once Feed is pressed
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
		-- #2839 (Derek2, phone: "buttons squished"): the Perks button fits inside the header and stays clear of the X
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local root = modals and modals:FindFirstChild("Root")
		local container = root and root:FindFirstChild("Container")
		local window = container and container:FindFirstChild("RankUp") :: GuiObject?
		local perks = window and window:FindFirstChild("Perks", true) :: GuiObject?
		local close = window and window:FindFirstChild("Close", true) :: GuiObject?
		local header = window and window:FindFirstChild("Header", true) :: GuiObject?
		assert(perks and close and header, "uigate: no Perks button, X or header on Rank Up (#2839)")
		local face = (perks :: GuiObject):FindFirstChild("Face") :: GuiObject?
		local shown = face or perks :: GuiObject
		local top, bottom = shown.AbsolutePosition.Y, shown.AbsolutePosition.Y + shown.AbsoluteSize.Y
		local headerTop = (header :: GuiObject).AbsolutePosition.Y
		local headerBottom = headerTop + (header :: GuiObject).AbsoluteSize.Y
		assert(top >= headerTop - 1 and bottom <= headerBottom + 1, ("uigate: the Perks button (%d-%d) runs out of the header (%d-%d) (#2839)"):format(top, bottom, headerTop, headerBottom))
		local gap = (close :: GuiObject).AbsolutePosition.X - (shown.AbsolutePosition.X + shown.AbsoluteSize.X)
		assert(gap >= 8, ("uigate: the Perks button is %d px from the X (#2839)"):format(gap))
	end },
	{ "RankUpTier2", function()
		-- #2121: the Tier 1 card lists all five upgrade caps, Bait Bowl among them; the line still fits. The level is not
		-- pinned (#3204 moved the Tier 2 caps), only that the line is there
		Scenes._rankTier = (UI.getState() :: any).tier -- Scenes.close puts the sample tier back
		UI.update({ tier = 1 } :: any)
		UI.open("RankUp")
		local found = false
		for _, inst in UIShim.playerGui:GetDescendants() do
			if inst:IsA("TextLabel") and string.find(inst.Text, "bait bowl to %d") then
				found = true
				assert(inst.TextFits ~= false, "uigate: the Tier 2 upgrade line does not fit (#2121)")
			end
		end
		assert(found, "uigate: the Tier 2 card does not list the bait bowl cap (#2121)")
	end },
	-- #2915: ranking up to Tier 2 turns the rank-up button into "Fly to the Park"; pressing it closes the window, and
	-- the picker (opened here, as the trip to the cannon would) rings the Park card's Launch. A flight ends both.
	{ "ParkFly", function()
		Scenes._rankTier = (UI.getState() :: any).tier -- Scenes.close puts the sample tier back
		Scenes._parkFly = (UI.getState() :: any).money or 0 -- the sample's money would make Tier 3 ready
		UI.update({ money = 0, tier = 1 } :: any)
		UI.update({ tier = 2 } :: any)
		UI.open("RankUp")
		UIShim.advance(0.1)
		local function buttonText(): string
			local face = UIShim.playerGui:FindFirstChild("RankUpButton", true) :: Instance
			assert(face, "uigate: no rank-up button (#2915)")
			for _, piece in face:GetDescendants() do
				if piece:IsA("TextLabel") and piece.Text ~= "" then
					return piece.Text
				end
			end
			return if face:IsA("TextButton") then face.Text else ""
		end
		assert(buttonText():find("Fly to the Park", 1, true), "uigate: the rank-up button reads " .. buttonText() .. " after Tier 2 (#2915)")
		press("RankUp", "RankUpButton")
		UIShim.advance(0.1)
		assert(UI.cannon.fly.ring == "park", "uigate: Fly to the Park did not ring the Park (#2915)")
		UI.cannon.open()
		UIShim.advance(0.3)
		local window = UIShim.playerGui:FindFirstChild("Cannon", true) :: Instance
		local park = window:FindFirstChild("park", true) :: Instance
		local launch = park and park:FindFirstChild("Launch", true) :: Instance
		assert(launch and launch:FindFirstChild("TutorialGlow"), "uigate: no ring on the Park card's Launch (#2915)")
		local town = window:FindFirstChild("town", true) :: Instance
		local other = town and town:FindFirstChild("Launch", true) :: Instance
		assert(other == nil or other:FindFirstChild("TutorialGlow") == nil, "uigate: the ring is on the wrong card (#2915)")
	end },
	-- #2687 part 4: the "Unlocked!" card a station's reveal brings: the station's picture and name, the new perk in gold
	-- and its one line, every word fitting, the card on screen with its button a finger tall
	{ "PerkUnlocked", function()
		local StationPerks = UIShim.require("ReplicatedStorage.Shared.StationPerks")
		UI.perks.card:showUnlocked(StationPerks.get("haggler"))
		local gui = UIShim.playerGui:FindFirstChild("CatCafePerks") :: ScreenGui
		local card = gui:FindFirstChild("Card", true) :: Frame
		assert(card.Visible, "uigate: no Unlocked card (#2687)")
		local seen = {}
		for _, piece in card:GetDescendants() do
			if piece:IsA("TextLabel") and piece.Visible and piece.Text ~= "" then
				seen[piece.Name] = piece.Text
				assert(piece.TextFits ~= false, "uigate: the Unlocked card's words do not fit: " .. piece.Text .. " (#2687)")
			end
		end
		assert(seen.Station == "Yard Sale", "uigate: the Unlocked card names " .. tostring(seen.Station) .. " (#2687)")
		assert(seen.Perk and seen.Perk:find("Haggler", 1, true), "uigate: the Unlocked card does not name its perk (#2687)")
		local inset = game:GetService("GuiService"):GetGuiInset()
		local view = workspace.CurrentCamera.ViewportSize
		local at, size = card.AbsolutePosition + inset, card.AbsoluteSize
		assert(at.X >= 0 and at.Y >= 0 and at.X + size.X <= view.X + 0.5 and at.Y + size.Y <= view.Y + 0.5, "uigate: the Unlocked card runs off screen (#2687)")
	end },
	-- #2687 part 4: the rank up window teases the next station's perk in gold, and its Perks button opens "Your perks"
	-- over it: one row per owned perk, then the next one locked ("Opens at Tier 6"), every word fitting, the list inside
	-- the card and the card on screen
	{ "PerkList", function()
		Scenes._rankTier = (UI.getState() :: any).tier
		UI.update({ tier = 5 } :: any)
		UI.open("RankUp")
		local teaser = UIShim.playerGui:FindFirstChild("PerkTeaser", true) :: TextLabel
		assert(teaser and teaser.Visible and teaser.Text:find("Oasis Spa", 1, true), "uigate: the rank up window does not tease the next station (#2687)")
		assert(teaser.TextFits ~= false, "uigate: the perk teaser does not fit: " .. teaser.Text .. " (#2687)")
		press("RankUp", "Perks")
		local gui = UIShim.playerGui:FindFirstChild("CatCafePerks") :: ScreenGui
		local card = gui:FindFirstChild("Card", true) :: Frame
		assert(card.Visible, "uigate: Perks did not open Your perks (#2687)")
		local list = card:FindFirstChild("List") :: ScrollingFrame
		local owned, locked = 0, 0
		for _, row in list:GetChildren() do
			if row:IsA("Frame") then
				local name = row:FindFirstChild("Name") :: TextLabel
				local line = row:FindFirstChild("Line") :: TextLabel
				assert(name.TextFits ~= false and line.TextFits ~= false, "uigate: a perk row's words do not fit: " .. name.Text .. " / " .. line.Text .. " (#2687)")
				if line.Text:find("Opens at Tier", 1, true) then
					locked += 1
					assert(line.Text == "Opens at Tier 6", "uigate: the locked perk reads " .. line.Text .. " (#2687)")
				else
					owned += 1
				end
			end
		end
		assert(owned == 4 and locked == 1, ("uigate: Your perks at Tier 5 shows %d owned and %d locked, not 4 and 1 (#2687)"):format(owned, locked))
		local cardAt, cardSize = card.AbsolutePosition, card.AbsoluteSize
		local listAt, listSize = list.AbsolutePosition, list.AbsoluteSize
		assert(listAt.Y >= cardAt.Y and listAt.Y + listSize.Y <= cardAt.Y + cardSize.Y + 0.5, "uigate: the perks list runs out of its card (#2687)")
		local inset = game:GetService("GuiService"):GetGuiInset()
		local view = workspace.CurrentCamera.ViewportSize
		local at = cardAt + inset
		assert(at.Y >= 0 and at.Y + cardSize.Y <= view.Y + 0.5, "uigate: Your perks runs off screen (#2687)")
	end },
	-- #2784 (Derek2: no "+$/s" tags over his own cats): a working cat tagged before its parts arrive (your own cafe's,
	-- in place before the UI starts) gets its tag once a part comes, and a tag lost with its part is made again
	{ "RateTagLateParts", function()
		local cat = Instance.new("Model")
		cat.Name = "gate_late_cat"
		cat:SetAttribute("Rate", 12)
		cat:SetAttribute("Rarity", "Epic")
		cat:SetAttribute("Napping", false)
		cat:SetAttribute("DisplayName", "Late Cat")
		cat.Parent = workspace
		cat:AddTag("WorkingCat")
		local tags = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Screens.WorldTags").new(true)
		local function tagOf(): BillboardGui?
			return cat:FindFirstChild("CatCafeRateTag", true) :: BillboardGui?
		end
		assert(tagOf() == nil, "uigate: a tag before the cat has a part")
		local body = Instance.new("Part")
		body.Name = "Body"
		body.Size = Vector3.new(2, 2, 3)
		body.Position = Vector3.new(0, 3, -10)
		body.Parent = cat
		cat.PrimaryPart = body
		UIShim.advance(0.1)
		local tag = tagOf()
		assert(tag and tag.Enabled, "uigate: no rate tag once the cat's part arrived (#2784)")
		assert(((tag :: any).Rate :: TextLabel).Text:find("12") ~= nil, "uigate: the late tag reads " .. ((tag :: any).Rate :: TextLabel).Text)
		-- the server swaps the cat's body: the tag goes with the old one and comes back on the new
		local swap = body:Clone()
		swap.Parent = cat
		cat.PrimaryPart = swap
		body:Destroy()
		UIShim.advance(0.1)
		local again = tagOf()
		assert(again and again.Enabled and again.Parent == swap, "uigate: the rate tag did not come back after its part went (#2784)")
		tags:destroy()
		cat:Destroy()
	end },
	-- #2874 (console): on a gamepad the catch card's cap reads X (the prompt's GamepadKeyCode) and the HUD's Drop
	-- caps read "↓" (DPad down drops, #2879) while the menu letters hide; back on the keyboard they read E and G again
	{ "GamepadKeyCaps", function()
		local UserInputService = game:GetService("UserInputService")
		local changed = UIShim.eventOf(UserInputService, "LastInputTypeChanged")
		local function use(inputType)
			UIShim.setLastInput(inputType)
			UIShim.fire(changed, inputType)
			UIShim.advance(0.1)
		end
		UI.setCarrying({ catId = Catalog.cats[1].id, catName = "Mochi", rarity = "Rare" } :: any)
		UI.catch.show({ strayId = "gate_pad", catId = Catalog.cats[2].id, catName = "Mochi", rarity = "Rare", keyCode = Enum.KeyCode.E, gamepadKeyCode = Enum.KeyCode.ButtonX } :: any)
		UIShim.advance(0.3)
		local card = UIShim.playerGui:FindFirstChild("CatCafeCatch") :: ScreenGui
		local glyph = (card:FindFirstChild("Key", true) :: any).Glyph :: TextLabel
		local hud = UIShim.playerGui:FindFirstChild("CatCafeHUD") :: ScreenGui
		local drop = hud:FindFirstChild("Drop", true)
		local dropKey = if drop then drop:FindFirstChild("Key", true) :: TextLabel? else nil
		use(Enum.UserInputType.Gamepad1)
		assert(glyph.Text == "X", "uigate: the catch card's cap reads " .. glyph.Text .. " on a gamepad, not X (#2874)")
		if dropKey then
			assert(dropKey.Text == "↓" and dropKey.Visible, "uigate: the Drop cap reads " .. dropKey.Text .. " on a gamepad (#2874)")
		end
		for _, key in hud:GetDescendants() do
			if key.Name == "Key" and key:GetAttribute("PadKey") == "" then
				assert(not (key :: TextLabel).Visible, "uigate: the " .. key.Parent.Name .. " letter cap shows on a gamepad (#2874)")
			end
		end
		use(Enum.UserInputType.Keyboard)
		assert(glyph.Text == "E", "uigate: the catch card's cap reads " .. glyph.Text .. " on a keyboard (#2874)")
		if dropKey then
			assert(dropKey.Text == "G", "uigate: the Drop cap reads " .. dropKey.Text .. " on a keyboard (#2874)")
		end
		UIShim.setLastInput(nil)
		UI.catch.hide()
		UI.setCarrying(nil)
	end },
	-- #2885 (Derek2: the day, event and shower banner "slightly below the currency ... don't push those down into middle
	-- of screen ... doesn't cause problems with the 2x money", with a clear border) and #2881 (Luck pushed toward the
	-- middle with the x2+ money tag): a lucky, golden day with the party running, the money pass owned and Luck x2.5.
	-- On touch the banner hangs under the counters, the Luck row (when under them) lines up with the money, and
	-- nothing overlaps; every line's words fit (#2882)
	{ "StatusBannerBusy", function()
		local t = workspace:GetServerTimeNow()
		UIShim.advance(4)
		local Config = UIShim.require("ReplicatedStorage.Shared.Config")
		UI.store.preview(storePrices(true), { [Config.MoneyPassIds[3]] = true })
		UI.update({ luck = 2.5, luckSources = { { id = "statue", value = 1.5 } } })
		Scenes._cafeEvent = true
		cafeEvent({ EventStartsAt = t - 20, EventEndsAt = t + 7180, EventRunning = true })
		-- after cafeEvent, which binds a plain day's clock
		local clock = Instance.new("Folder")
		clock.Name = "Clock"
		clock:SetAttribute("Phase", "day")
		clock:SetAttribute("PhaseEndsAt", t + 190)
		clock:SetAttribute("AreasOpen", true)
		clock:SetAttribute("Day", 4)
		clock:SetAttribute("LuckyDay", true)
		clock:SetAttribute("GoldenDay", true)
		UI.clock.bind(clock)
		UIShim.advance(0.5)
		local hud = UIShim.playerGui:FindFirstChild("CatCafeHUD") :: ScreenGui
		local banner = hud:FindFirstChild("StatusBanner", true) :: Frame
		assert(banner and banner.Visible, "uigate: no status banner on a lucky day with a party (#2885)")
		assert(banner:FindFirstChild("Ring"), "uigate: the status banner has no ring (#2885)")
		for _, name in { "LuckyDay", "EventChip", "EventNext" } do
			local line = banner:FindFirstChild(name, true) :: TextLabel
			assert(line and line.Visible, "uigate: the banner has no " .. name .. " line (#2885)")
			assert(line.TextFits, ("uigate: the banner's %s line %q is cut, %d px wide (#2882)"):format(name, line.Text, line.AbsoluteSize.X))
			local right = line.AbsolutePosition.X + line.AbsoluteSize.X
			assert(right <= banner.AbsolutePosition.X + banner.AbsoluteSize.X + 1, "uigate: the banner's " .. name .. " line runs out of it (#2882)")
		end
		local function rect(o: GuiObject): (Vector2, Vector2)
			return o.AbsolutePosition, o.AbsolutePosition + o.AbsoluteSize
		end
		local function apart(a: GuiObject, b: GuiObject): boolean
			local a0, a1 = rect(a)
			local b0, b1 = rect(b)
			return a1.X <= b0.X + 1 or b1.X <= a0.X + 1 or a1.Y <= b0.Y + 1 or b1.Y <= a0.Y + 1
		end
		local counters = hud:FindFirstChild("Counters", true) :: GuiObject
		for _, name in { "Counters", "Menu", "MenuFold", "TierGoal", "Icons", "MoneyBadge", "Quests", "Index" } do
			local other = hud:FindFirstChild(name, true) :: GuiObject?
			if other and other.Visible and other ~= banner then
				assert(apart(banner, other), "uigate: the status banner overlaps " .. name .. " (#2885)")
			end
		end
		-- #3178: on a PC the clock and banner are at the top middle, where toasts stack; a toast keeps clear of them
		if not UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Scale").isTouch() then
			press("CatCafeHUD", "LuckyDay.Tap") -- the day card open under the banner, the lowest of the three
			local dayCard = hud:FindFirstChild("DayCard", true) :: GuiObject
			assert(dayCard and dayCard.Visible, "uigate: the day card did not open (#3178)")
			UI.toast("Welcome back! +$12,345 while you were away", "info") -- the stack places itself again
			UIShim.advance(0.5)
			local toasts = UIShim.playerGui:FindFirstChild("CatCafeToasts")
			local stack = toasts and toasts:FindFirstChild("Stack", true)
			local clockPiece = hud:FindFirstChild("Clock", true) :: GuiObject
			local checked = 0
			for _, pill in (stack and stack:GetChildren() or {}) :: { Instance } do
				if pill:IsA("GuiObject") and pill.Visible then
					checked += 1
					assert(apart(pill, banner), "uigate: a toast lies over the status banner on a PC (#3178)")
					assert(apart(pill, clockPiece), "uigate: a toast lies over the clock on a PC (#3178)")
					assert(apart(pill, dayCard), "uigate: a toast lies over the open day card on a PC (#3178)")
				end
			end
			assert(checked > 0, "uigate: no toast to check against the top middle banner (#3178)")
		end
		if UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Scale").isTouch() then
			local below = banner.AbsolutePosition.Y >= counters.AbsolutePosition.Y + counters.AbsoluteSize.Y - 1
			assert(below, "uigate: the status banner is not under the money (#2885)")
			assert(banner.AbsolutePosition.Y <= hud.AbsoluteSize.Y * 0.45, "uigate: the status banner sits in the middle of the screen (#2885)")
			local luck = hud:FindFirstChild("Luck", true) :: GuiObject?
			if luck and luck.Visible then
				assert(apart(banner, luck), "uigate: the status banner overlaps the Luck chip (#2885)")
				for _, name in { "Menu", "MenuFold", "Quests", "Bowl" } do
					local other = hud:FindFirstChild(name, true) :: GuiObject?
					if other and other.Visible then
						assert(apart(luck, other), "uigate: the Luck chip overlaps " .. name .. " (#2881)")
					end
				end
				local under = luck.AbsolutePosition.Y >= counters.AbsolutePosition.Y + counters.AbsoluteSize.Y - 1
				if under then
					-- left edges level, or as near as the menu grid lets it, never centred under the pair
					local dx = luck.AbsolutePosition.X - counters.AbsolutePosition.X
					assert(dx <= counters.AbsoluteSize.X / 3, ("uigate: the Luck chip is %d px right of the money's left edge, pushed toward the middle (#2881)"):format(dx))
				end
			end
		end
		-- let the day's and the party's toasts age past TipQueue.TOAST_QUIET, so the scenes after start on a quiet
		-- moment (FirstVisitAway's card waits for one)
		UIShim.advance(21)
	end },
	-- #2880 (Derek2: "the pop ups ... are too early and too often"): no slide-in ask in a session's first minutes, and
	-- none right after another; once the gap has passed the next one shows
	{ "AskPacing", function()
		local function ask(): boolean
			return UI.asks.card({
				title = "Gate ask",
				choices = { { id = "ok", label = "OK", style = "primary" } },
				seconds = 5,
				answer = function() end,
			})
		end
		assert(not UI.asks.paced(), "uigate: an ask may show in the session's first minutes (#2880)")
		assert(ask() == false, "uigate: a slide-in ask showed in the session's first minutes (#2880)")
		UI.asks.skipPace()
		assert(ask() == true, "uigate: the ask did not show once the first minutes had passed (#2880)")
		UIShim.advance(6)
		assert(ask() == false, "uigate: a second ask showed right after the first (#2880)")
	end },
	-- #2872 (console): on a gamepad Select lands on the HUD's menu, a window takes the selection on its first useful
	-- button (never its X) as it opens, closing hands the menu tile back, and Select again lets go
	{ "GamepadWindow", function()
		local GuiService = game:GetService("GuiService")
		UIShim.setLastInput(Enum.UserInputType.Gamepad1)
		GuiService.SelectedObject = nil
		UI.gamepadSelect()
		local tile = GuiService.SelectedObject
		assert(tile ~= nil and tile:IsA("GuiButton"), "uigate: Select on a gamepad selected nothing in the HUD (#2872)")
		assert(tile:IsDescendantOf(UIShim.playerGui:FindFirstChild("CatCafeHUD", true) or UIShim.playerGui), "uigate: Select left the HUD")
		UI.open("Upgrades")
		UIShim.advance(0.3)
		local first = GuiService.SelectedObject
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals") :: ScreenGui
		assert(first ~= nil and first:IsA("GuiButton") and first:IsDescendantOf(modals), "uigate: Upgrades opened on a gamepad selected no button in it (#2872)")
		assert(first.Name ~= "Close" and (first.Parent :: Instance).Name ~= "Close", "uigate: the window selected its X first (#2872)")
		assert(first:FindFirstAncestor("Tabs") == nil, "uigate: Upgrades selected a tab, not its first row's button (#2872)")
		assert((UIShim.playerGui :: any).SelectionImageObject ~= nil, "uigate: no selection ring (#2872)")
		-- #2965: the window's container is a selection group that stops at every edge, so the DPad stays in the window
		local container = first:FindFirstAncestor("Container") :: any
		assert(container ~= nil and container.SelectionGroup == true, "uigate: the open window is no selection group (#2965)")
		for _, side in { "Up", "Down", "Left", "Right" } do
			assert(
				container["SelectionBehavior" .. side] == Enum.SelectionBehavior.Stop,
				"uigate: the selection can leave the window going " .. side .. " (#2965)"
			)
		end
		UI.close()
		UIShim.advance(0.3)
		assert(GuiService.SelectedObject == tile, "uigate: closing the window did not hand the menu tile back (#2872)")
		UI.gamepadSelect()
		assert(GuiService.SelectedObject == nil, "uigate: Select again did not let go (#2872)")
		UIShim.setLastInput(nil)
	end },
	-- #3839 (84 "Setting GuiService.SelectedObject to invalid GuiObject" a day): a button whose ScreenGui was taken out of
	-- PlayerGui keeps Enabled and Visible, and the engine refuses it; GamepadNav.select and restore leave it alone
	{ "GamepadSelectDetached", function()
		local GuiService = game:GetService("GuiService")
		local GamepadNav = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Components.GamepadNav")
		local gui = Instance.new("ScreenGui")
		gui.Name = "GateDetachedSelect"
		local button = Instance.new("TextButton")
		button.Size = UDim2.fromOffset(120, 48)
		button.Parent = gui
		gui.Parent = UIShim.playerGui
		assert(GamepadNav.shown(button), "uigate: a button in an open ScreenGui in PlayerGui does not count as shown (#3839)")
		assert(GamepadNav.select(button) and GuiService.SelectedObject == button, "uigate: a shown button was not selected (#3839)")
		gui.Parent = nil
		assert(not GamepadNav.shown(button), "uigate: a button whose ScreenGui left PlayerGui still counts as shown (#3839)")
		GamepadNav.restore(button)
		assert(GuiService.SelectedObject == nil, "uigate: restore handed the selection to a button out of PlayerGui (#3839)")
		assert(not GamepadNav.select(button), "uigate: select took a button out of PlayerGui (#3839)")
		gui:Destroy()
	end },
	-- #2868 (Derek2: the "+$/s" tags a little smaller, and on the sleeping cats too): a resting cat napping in a
	-- cafe's Cats folder shows its name over "Resting" (it earns nothing), a working cat its rate, both a fifth smaller
	{ "RateTagResting", function()
		local plot = Instance.new("Model")
		plot.Name = "gate_rest_plot"
		local cats = Instance.new("Folder")
		cats.Name = "Cats"
		cats.Parent = plot
		local function cat(name: string, napping: boolean, x: number): Model
			local model = Instance.new("Model")
			model.Name = name
			local body = Instance.new("Part")
			body.Name = "Body"
			body.Size = Vector3.new(2, 2, 3)
			body.Position = Vector3.new(x, 3, -10)
			body.Parent = model
			model.PrimaryPart = body
			model:SetAttribute("Rate", if napping then 0 else 9)
			model:SetAttribute("Rarity", "Rare")
			model:SetAttribute("Napping", napping)
			model:SetAttribute("DisplayName", name)
			model.Parent = cats
			if not napping then
				model:AddTag("WorkingCat")
			end
			return model
		end
		local sleeper = cat("Sleepy Cat", true, -3)
		local worker = cat("Busy Cat", false, 3)
		plot.Parent = workspace
		plot:AddTag("Plot")
		local tags = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Screens.WorldTags").new(true)
		local function tagOf(model: Model): any
			return model:FindFirstChild("CatCafeRateTag", true)
		end
		local rest, work = tagOf(sleeper), tagOf(worker)
		assert(rest and rest.Enabled, "uigate: no tag over a resting cat (#2868)")
		assert(rest.Rate.Text:find("Resting", 1, true) ~= nil, "uigate: the resting tag reads " .. rest.Rate.Text .. " (#2868)")
		assert(rest.CatName.Text == "Sleepy Cat", "uigate: the resting tag's name reads " .. rest.CatName.Text)
		assert(work and work.Enabled and work.Rate.Text:find("9") ~= nil, "uigate: the working cat's tag reads wrong (#2868)")
		local count = 0
		for _, d in sleeper:GetDescendants() do
			count += if d.Name == "CatCafeRateTag" then 1 else 0
		end
		assert(count == 1, "uigate: the resting cat has " .. count .. " tags (#2868)")
		assert(work.Size.X.Scale <= 1.6 + 1e-6 and work.Size.X.Offset >= 30, "uigate: the rate tag is not smaller in studs, or lost its #2551 pixel floor (#2868)")
		tags:setRates(false)
		assert(not rest.Enabled and not work.Enabled, "uigate: the Cat income switch left a tag on (#2868)")
		tags:destroy()
		plot:Destroy()
	end },
	-- #2651 part 4 (late-stations.md section 1): the Oasis Spa card, a cat 3 h 10 m in (+3 levels, Collect lit), an
	-- empty slot and slot 3 for 250 golden fish
	{ "OasisSpa", function()
		UI.lateStations.update(lateState(3 * 3600 + 600))
		UI.lateStations.open("spa")
		assert(UI.isOpen() == "OasisSpa", "uigate: the spa's prompt opened " .. tostring(UI.isOpen()) .. " (#2651)")
		local window = lateWindow("OasisSpa")
		local level = window:FindFirstChild("Slot1", true):FindFirstChild("Level")
		assert(string.match(level.Text, "^Lv %d+ → %d+$"), "uigate: the soaking cat reads " .. level.Text .. " (#2651)")
		local collect = window:FindFirstChild("Collect", true)
		local words = collect and collect:FindFirstChildWhichIsA("TextLabel", true)
		assert(words and words.Text == "Collect +3 levels", "uigate: Collect reads " .. tostring(words and words.Text) .. " (#2904)")
		local buy = window:FindFirstChild("Slot3", true):FindFirstChild("Action")
		local price = buy and buy:FindFirstChildWhichIsA("TextLabel", true)
		local found = false
		for _, piece in buy:GetDescendants() do
			if piece:IsA("TextLabel") and piece.Text == "250" then
				found = true
			end
		end
		assert(found, "uigate: slot 3 does not show its 250 fish price (#2651) " .. tostring(price and price.Text))
	end },
	-- #2651 part 4: Add a cat on the empty slot turns the card to the cats that can go in, each with Relax; a press
	-- sends SpaPut with that slot and the cat
	{ "OasisSpaPicker", function()
		UI.lateStations.update(lateState(3 * 3600 + 600))
		UI.lateStations.open("spa")
		press("OasisSpa", "Slot2.Action")
		local picker = lateWindow("OasisSpa"):FindFirstChild("Picker", true)
		assert(picker and picker.Visible, "uigate: Add a cat did not open the cat list (#2651)")
		local list = picker:FindFirstChild("List")
		local rows = 0
		for _, row in list:GetChildren() do
			if row:IsA("Frame") then
				rows += 1
				assert(row.Name ~= "gate_5", "uigate: the cat already soaking is in the list (#2651)")
			end
		end
		assert(rows >= 10, "uigate: the cat list has only " .. rows .. " cats (#2651)")
		local sent = nil
		local connection = UI.events.lateStation:Connect(function(remote, slot, uid)
			sent = remote .. ":" .. tostring(slot) .. ":" .. tostring(uid)
		end)
		local first = nil
		for _, row in list:GetChildren() do
			if row:IsA("Frame") and (first == nil or row.LayoutOrder < first.LayoutOrder) then
				first = row
			end
		end
		press("OasisSpa", "Picker.List." .. first.Name .. ".Relax")
		connection:Disconnect()
		assert(sent == "SpaPut:2:" .. first.Name, "uigate: Relax sent " .. tostring(sent) .. " (#2651)")
		-- the list again, for the screenshot
		UI.lateStations.update(lateState(3 * 3600 + 600))
		press("OasisSpa", "Slot2.Action")
	end },
	-- #2651 part 4: Take out on a cat 20 minutes in asks first ("It won't level up.")
	{ "OasisSpaTakeOut", function()
		UI.lateStations.update(lateState(20 * 60))
		UI.lateStations.open("spa")
		press("OasisSpa", "Slot1.Action")
		local window = lateWindow("OasisSpa")
		local confirm = window:FindFirstChild("Confirm", true)
		assert(confirm and confirm.Visible, "uigate: Take out did not ask first (#2651)")
		local ask = confirm:FindFirstChild("Ask")
		assert(string.find(ask.Text, "out now? It won't level up.", 1, true), "uigate: the question reads " .. ask.Text .. " (#2651)")
	end },
	-- #3196 (trait-station.md section 1): the Mystic Pool's card on a cat with a Legendary trait: its two effects,
	-- Re-roll for a Trait Token, the odds line on the card, and a free token to collect. Roll sends RollTrait's event
	-- with that cat.
	{ "MysticPool", function()
		local window = mysticPool(nil, "gate_1")
		local name = window:FindFirstChild("Trait", true):FindFirstChild("Name")
		assert(name.Text == "Golden Whiskers", "uigate: the trait card reads " .. name.Text .. " (#3196)")
		local effects = window:FindFirstChild("Trait", true):FindFirstChild("Effect2")
		assert(effects.Text ~= "", "uigate: a Legendary trait shows one effect only (#3196)")
		-- #3961: the main card's odds are six rarity pills
		local pills = window:FindFirstChild("OddsPills", true)
		local mythic = pills and pills:FindFirstChild("Mythic") :: TextLabel?
		assert(pills and pills.Visible and mythic and mythic.Text == "Mythic 5%", "uigate: the odds pills are not on the card (#3196, #3961)")
		local roll = window:FindFirstChild("Roll", true):FindFirstChildWhichIsA("TextLabel", true)
		assert(roll.Text == "Re-roll · 1 Trait Token", "uigate: Roll reads " .. roll.Text .. " (#3196)")
		local tokens = window:FindFirstChild("Tokens", true)
		assert(tokens.Text == "1 Trait Token ready", "uigate: the token line reads " .. tokens.Text .. " (#3196)")
		-- #3848: the whole card, Collect included, sits on the screen with room under it
		local _, screenH, inset = UIShim.screen()
		local bottom = window.AbsolutePosition.Y + window.AbsoluteSize.Y + (inset or 0) -- the modals sit under the top bar
		assert(bottom <= screenH - 8, ("uigate: the Mystic Pool card ends %d px from the screen's bottom (#3848)"):format(screenH - bottom))
		local sent = nil
		local connection = UI.events.rollTrait:Connect(function(uid)
			sent = uid
		end)
		press("MysticPool", "Roll")
		connection:Disconnect()
		assert(sent == "gate_1", "uigate: Roll sent " .. tostring(sent) .. " (#3196)")
		local resting = window:FindFirstChild("Roll", true):FindFirstChildWhichIsA("TextLabel", true)
		assert(resting.Text == "...", "uigate: Roll does not rest while the server answers (#3196)")
		-- the server's answer wakes the card (here a refusal that took nothing but a token, for the picture)
		UI.update({ traits = { tokens = 1, freeLeft = 0, held = 1 } } :: any)
		assert(resting.Text == "Re-roll · 1 Trait Token", "uigate: Roll did not wake on the answer: " .. resting.Text .. " (#3196)")
	end },
	-- #3196: a new player's card: a cat with no trait picked from the list, and "Free roll (5 left)"
	{ "MysticPoolFree", function()
		local window = mysticPool(nil, nil, { tokens = 0, freeLeft = 5, held = 0, nextAt = workspace:GetServerTimeNow() + 3 * 3600 })
		local roll = window:FindFirstChild("Roll", true)
		press("MysticPool", "Change")
		local picker = window:FindFirstChild("Picker", true)
		assert(picker.Visible, "uigate: Pick a cat did not open the cat list (#3196)")
		for _ = 1, 10 do
			UIShim.advance(1 / 60) -- the rest of the rows, a few a frame
		end
		press("MysticPool", "Picker.List.gate_2.Pick")
		assert(not picker.Visible, "uigate: picking a cat left the list open (#3196)")
		local words = roll:FindFirstChildWhichIsA("TextLabel", true)
		assert(words.Text == "Free roll (5 left)", "uigate: Roll reads " .. words.Text .. " (#3196)")
		local name = window:FindFirstChild("Trait", true):FindFirstChild("Name")
		assert(name.Text == "No trait yet", "uigate: a cat with no trait reads " .. name.Text .. " (#3196)")
		local tokens = window:FindFirstChild("Tokens", true)
		assert(tokens.Text:find("^Next free token in "), "uigate: the token line reads " .. tokens.Text .. " (#3196)")
	end },
	-- #3196: the cat list, each row with its trait
	{ "MysticPoolPicker", function()
		local window = mysticPool(nil, "gate_1")
		press("MysticPool", "Change")
		local list = window:FindFirstChild("Picker", true):FindFirstChild("List")
		for _ = 1, 10 do
			UIShim.advance(1 / 60) -- the rest of the rows, a few a frame
		end
		local rows = 0
		for _, row in list:GetChildren() do
			rows += if row:IsA("Frame") then 1 else 0
		end
		assert(rows >= 10, "uigate: the cat list has only " .. rows .. " cats (#3196)")
		local trait = list:FindFirstChild("gate_1"):FindFirstChild("Trait", true)
		assert(trait.Text:find("Golden Whiskers", 1, true), "uigate: the row reads " .. trait.Text .. " (#3196)")
		-- #3950: a trait is a bold pill of its rarity's colour that fits its row
		assert(trait.BackgroundTransparency == 0 and trait.TextFits, "uigate: the row's trait is not a whole pill (#3950)")
		local holder = trait.Parent :: GuiObject
		assert(trait.AbsolutePosition.X + trait.AbsoluteSize.X <= holder.AbsolutePosition.X + holder.AbsoluteSize.X + 1, "uigate: the trait pill spills off its row (#3950)")
		-- #3874 (Derek 2026-11-13: "a search bar and a filter menu that they can pop up and close with an X. Make the
		-- default sort by money"): the search box, Filter and Back share one row and the list starts right under it;
		-- on a short screen at least three whole rows show at once
		local picker = window:FindFirstChild("Picker", true)
		local tools = picker:FindFirstChild("Tools")
		local search = tools:FindFirstChild("Search")
		assert(search and search:IsA("TextBox"), "uigate: the search box is not on the tool row (#3874)")
		for _, name in { "Filter", "Back" } do
			local button = tools:FindFirstChild(name)
			assert(button, "uigate: the tool row has no " .. name .. " (#3874)")
			assert(
				math.abs(button.AbsolutePosition.Y - search.AbsolutePosition.Y) <= 1,
				"uigate: " .. name .. " is not on the search box's row (#3874)"
			)
			assert(
				button.AbsolutePosition.X >= search.AbsolutePosition.X + search.AbsoluteSize.X,
				"uigate: " .. name .. " overlaps the search box (#3874)"
			)
		end
		assert(search.AbsoluteSize.X >= 120, ("uigate: the search box is only %d px wide (#3874)"):format(search.AbsoluteSize.X))
		assert(search.PlaceholderText:find("cats", 1, true), "uigate: the search hint reads " .. search.PlaceholderText .. " (#3874)")
		assert(list.AbsolutePosition.Y <= tools.AbsolutePosition.Y + tools.AbsoluteSize.Y + 12, "uigate: the list does not start under the tool row (#3874)")
		assert(list:FindFirstChild("gate_1"):FindFirstChild("Rarity", true), "uigate: a row has no rarity tag (#3700)")
		local fit = list.AbsoluteSize.Y / (list:FindFirstChild("gate_1").AbsoluteSize.Y + 6)
		print(("[MysticPoolPicker] %.1f rows show at once"):format(fit))
		if UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Scale").isShort() then
			assert(fit >= 3, ("uigate: only %.1f rows show at once on this short screen (#3874)"):format(fit))
		end
		-- the list runs by money by default: each shown row earns no more than the one above
		local function order(): { string }
			local rows = {}
			for _, row in list:GetChildren() do
				if row:IsA("Frame") and row.Visible then
					table.insert(rows, row)
				end
			end
			table.sort(rows, function(x, y)
				return x.LayoutOrder < y.LayoutOrder
			end)
			local names = {}
			for _, row in rows do
				table.insert(names, row.Name)
			end
			return names
		end
		local cats = (UI.getState() :: any).cats
		local byMoney = order()
		for index = 2, #byMoney do
			local above, below = cats[byMoney[index - 1]], cats[byMoney[index]]
			assert(
				(tonumber(above.rating) or 0) >= (tonumber(below.rating) or 0),
				("uigate: the list is not by money: %s above %s (#3874)"):format(byMoney[index - 1], byMoney[index])
			)
		end
		-- Filter pops up the Sort and Show chips with an X; Money is in use; Has trait and a sort work at once
		local menu = picker:FindFirstChild("FilterMenu")
		assert(not menu.Visible, "uigate: the Filter pop-up is open before Filter is pressed (#3874)")
		press("MysticPool", "Picker.Tools.Filter")
		assert(menu.Visible, "uigate: Filter did not open its pop-up (#3874)")
		local money = menu:FindFirstChild("SortMoney"):FindFirstChildWhichIsA("TextLabel", true)
		assert(money.Text:find("Money", 1, true) and money.Text:find("▼", 1, true), "uigate: the Money sort chip reads " .. money.Text .. " (#3874)")
		assert(menu:FindFirstChild("SortName") == nil, "uigate: the pop-up still has a Name sort (#3874)")
		press("MysticPool", "Picker.FilterMenu.Hastrait")
		local shown = 0
		for _, row in list:GetChildren() do
			shown += if row:IsA("Frame") and row.Visible then 1 else 0
		end
		local withTrait = 0
		for _, cat in cats do
			withTrait += if cat.trait ~= nil then 1 else 0
		end
		assert(withTrait >= 1, "uigate: the sample cats have no trait for the Has trait filter (#3700)")
		assert(shown == withTrait, ("uigate: Has trait shows %d cats, %d have a trait (#3700)"):format(shown, withTrait))
		local filterWords = tools:FindFirstChild("Filter"):FindFirstChildWhichIsA("TextLabel", true)
		assert(filterWords.Text:find("•", 1, true), "uigate: Filter does not show that a filter is on: " .. filterWords.Text .. " (#3874)")
		press("MysticPool", "Picker.FilterMenu.All")
		press("MysticPool", "Picker.FilterMenu.SortLevel")
		for _ = 1, 10 do
			UIShim.advance(1 / 60)
		end
		local byLevel = order()
		for index = 2, #byLevel do
			local above, below = cats[byLevel[index - 1]], cats[byLevel[index]]
			assert(
				(tonumber(above.level) or 1) >= (tonumber(below.level) or 1),
				("uigate: Level does not sort: %s above %s (#3874)"):format(byLevel[index - 1], byLevel[index])
			)
		end
		press("MysticPool", "Picker.FilterMenu.Close")
		assert(not menu.Visible, "uigate: the X did not close the Filter pop-up (#3874)")
	end },
	-- #3874: the Filter pop-up left open, for the picture: Sort and Show over the list, the X at the top right
	{ "MysticPoolFilter", function()
		local window = mysticPool(nil, "gate_1")
		press("MysticPool", "Change")
		for _ = 1, 10 do
			UIShim.advance(1 / 60)
		end
		press("MysticPool", "Picker.Tools.Filter")
		local menu = window:FindFirstChild("Picker", true):FindFirstChild("FilterMenu")
		assert(menu.Visible, "uigate: Filter did not open its pop-up (#3874)")
		local close = menu:FindFirstChild("Close")
		local bottom = menu.AbsolutePosition.Y + menu.AbsoluteSize.Y
		local card = window.AbsolutePosition.Y + window.AbsoluteSize.Y
		assert(bottom <= card, ("uigate: the Filter pop-up runs %d px past the card (#3874)"):format(bottom - card))
		assert(close.AbsolutePosition.X + close.AbsoluteSize.X <= menu.AbsolutePosition.X + menu.AbsoluteSize.X + 1, "uigate: the X sits outside the pop-up (#3874)")
		for _, name in { "SortMoney", "SortLevel", "SortRarity", "All", "Working", "Resting", "Notrait", "Hastrait" } do
			local chip = menu:FindFirstChild(name)
			assert(chip, "uigate: the pop-up has no " .. name .. " (#3874)")
			assert(
				chip.AbsolutePosition.X + chip.AbsoluteSize.X <= close.AbsolutePosition.X - 2 or chip.AbsolutePosition.Y >= close.AbsolutePosition.Y + close.AbsoluteSize.Y,
				"uigate: " .. name .. " runs under the X (#3874)"
			)
			assert(chip.AbsolutePosition.X + chip.AbsoluteSize.X <= menu.AbsolutePosition.X + menu.AbsoluteSize.X, "uigate: " .. name .. " runs out of the pop-up (#3874)")
		end
	end },
	-- #3196: a re-roll waiting: the old trait and the new one side by side, Keep old and Take new the same size and
	-- style, the odds line on it; Take new sends ChooseTrait's event with true
	{ "MysticPoolChoice", function()
		local window = mysticPool({ uid = "gate_1", id = "cosmicFortune" }, "gate_1")
		local choice = window:FindFirstChild("Choice", true)
		assert(choice.Visible, "uigate: a waiting re-roll does not show its choice (#3196)")
		local old, new = choice.Old:FindFirstChild("Name"), choice.New:FindFirstChild("Name")
		assert(old.Text == "Golden Whiskers" and new.Text == "Cosmic Fortune", "uigate: the choice reads " .. old.Text .. " / " .. new.Text .. " (#3196)")
		assert(choice.New.Effect3.Text ~= "", "uigate: a Mythic trait does not show its three effects (#3196)")
		assert(choice.KeepOld.AbsoluteSize == choice.TakeNew.AbsoluteSize, "uigate: Keep old and Take new differ in size (#3196)")
		assert(choice.OddsLine.Text:find("Mythic 5%", 1, true), "uigate: the choice has no odds line (#3196)")
		local sent = nil
		local connection = UI.events.chooseTrait:Connect(function(takeNew)
			sent = takeNew
		end)
		press("MysticPool", "Choice.TakeNew")
		connection:Disconnect()
		assert(sent == true, "uigate: Take new sent " .. tostring(sent) .. " (#3196)")
	end },
	-- #3196: Odds, one tap from Roll: every rarity with its percent and the "equally likely" line
	{ "MysticPoolOdds", function()
		local window = mysticPool(nil, "gate_1")
		press("MysticPool", "Odds")
		local list = window:FindFirstChild("OddsList", true)
		assert(list.Visible, "uigate: Odds did not open the list (#3196)")
		assert(list.Mythic.Percent.Text == "5%" and list.Common.Percent.Text == "30%" and list.Epic.Percent.Text == "12%", "uigate: the odds list reads wrong (#3196)")
		assert(list.Equal.Text:find("equally likely", 1, true), "uigate: the odds list lacks the equal line (#3196)")
	end },
	-- #3864: the Trait Token offer once the free rolls are used: both bundles with their prices, the full odds, a
	-- No thanks that hides it, and once a session only
	{ "MysticPoolOffer", function()
		local window = mysticPool(nil, "gate_1", { tokens = 0, freeLeft = 0, held = 0, bundles = true })
		local offer = window:FindFirstChild("TokenOffer", true)
		assert(offer and offer.Visible, "uigate: the token offer did not show after the free rolls (#3864)")
		local want = { "20 Tokens · R$99", "50 Tokens · R$199" }
		for index, words in want do
			local button = offer:FindFirstChild("Bundle" .. index, true)
			local label = button and button:FindFirstChildWhichIsA("TextLabel", true)
			assert(button and button.Visible and label and label.Text == words, "uigate: bundle " .. index .. " reads " .. tostring(label and label.Text) .. " (#3864)")
			assert(label.TextFits, "uigate: bundle " .. index .. "'s label does not fit (#3864)")
		end
		local odds = 0
		for _, piece in offer:GetDescendants() do
			if piece:IsA("TextLabel") and piece.Visible and piece.Text:find("%d+%%") then
				odds += 1
			end
		end
		assert(odds >= 1, "uigate: the token offer shows no odds before the buy buttons (#3864)")
		local no = offer:FindFirstChild("NoThanks", true)
		local bottom = offer.AbsolutePosition.Y + offer.AbsoluteSize.Y
		assert(no and no.AbsolutePosition.Y + no.AbsoluteSize.Y <= bottom + 1, "uigate: No thanks hangs below the offer (#3864)")
		press("MysticPool", "TokenOffer.NoThanks")
		assert(not offer.Visible, "uigate: No thanks did not hide the token offer (#3864)")
		UI.update({ traits = { tokens = 0, freeLeft = 0, held = 0, bundles = true } } :: any)
		assert(not offer.Visible, "uigate: the token offer showed twice in one session (#3864)")
	end },
	-- #2651 part 4 (late-stations.md section 2): the Relic Museum card on the Alleyway room, two exhibits given (one
	-- gold), one that can be filled with its green "!", the rest silhouettes with "You have n"
	{ "RelicMuseum", function()
		lateCats()
		UI.lateStations.update(lateState(nil))
		UI.lateStations.open("museum")
		assert(UI.isOpen() == "RelicMuseum", "uigate: the museum's prompt opened " .. tostring(UI.isOpen()) .. " (#2651)")
		local window = lateWindow("RelicMuseum")
		local title = window:FindFirstChild("Room", true)
		assert(string.match(title.Text, "Hall 2/10$"), "uigate: the room reads " .. title.Text .. " (#2651)")
		local dots = 0
		for _, piece in window:GetDescendants() do
			if piece.Name == "Dot" and piece:IsA("GuiObject") and piece.Visible then
				dots += 1
			end
		end
		-- #3123: a cat's only copy can be given too, so every owned cat of the room shows one, gate_4's among them
		assert(dots >= 1, "uigate: " .. dots .. " exhibits show a ! (#2651)")
	end },
	-- #2651 part 4: tapping the exhibit with a ! lists its copies weakest first; the gold copy asks first
	{ "RelicMuseumGive", function()
		lateCats()
		UI.lateStations.update(lateState(nil))
		UI.lateStations.open("museum")
		local window = lateWindow("RelicMuseum")
		local tile = nil -- gate_4's exhibit: its copy and the three spares (#3123: the only-copy tiles show a ! too)
		for _, piece in window:GetDescendants() do
			if piece.Name == "Line" and piece:IsA("TextLabel") and piece.Text == "You have 4" then
				tile = piece.Parent
			end
		end
		assert(tile, "uigate: no exhibit reads You have 4 (#2651)")
		press("RelicMuseum", tile.Name)
		local give = window:FindFirstChild("Give", true)
		assert(give and give.Visible, "uigate: the exhibit did not list its copies (#2651)")
		local list = give:FindFirstChild("List")
		local order = {}
		for _, row in list:GetChildren() do
			if row:IsA("Frame") then
				order[row.LayoutOrder] = row.Name
			end
		end
		assert(order[1] == "gate_spare1", "uigate: the weakest copy is not first (#2651): " .. tostring(order[1]))
		local sent = nil
		local connection = UI.events.lateStation:Connect(function(remote, uid)
			sent = remote .. ":" .. tostring(uid)
		end)
		press("RelicMuseum", "Give.List.gate_spare2.Give")
		local confirm = window:FindFirstChild("Confirm", true)
		assert(confirm.Visible and sent == nil, "uigate: the gold copy did not ask first (#2651)")
		assert(confirm:FindFirstChild("Ask").Text == "This is a gold cat. Give it anyway?", "uigate: the gold warning reads " .. confirm:FindFirstChild("Ask").Text)
		connection:Disconnect()
	end },
	-- #2920 (Derek2: on a first catch "stop the minigame first circle when its over the circle and prompt them to click
	-- or press space now"): a held ring closes onto its ring, stops there and pulses its device's prompt; still waiting
	-- seconds later
	{ "CatchHoldWaiting", function()
		local t = workspace:GetServerTimeNow()
		local list = { { startsAt = t + 0.2, shrinkSeconds = 1.2, x = 0.5, y = 0.55, hold = true, holdSeconds = 60 } }
		UI.catch.show({ strayId = "gate_hold", catId = Catalog.cats[2].id, catName = "Mochi", rarity = "Common" })
		UI.catch.showCircles("gate_hold", list :: any, { perfect = 0.074, good = 0.18 })
		UIShim.advance(1.6 + 4)
		local layer = UIShim.playerGui:FindFirstChild("CatCafeCatchCircles") :: ScreenGui
		local art = layer:FindFirstChild("Circle1", true):FindFirstChild("Art") :: Frame
		local closer = art:FindFirstChild("Closer") :: Frame
		local ring = art:FindFirstChild("Ring") :: Frame
		assert(
			math.abs(closer.AbsoluteSize.X - ring.AbsoluteSize.X) <= 3,
			("uigate: the held ring's circle is %d px across, its ring %d: it did not stop on it (#2920)"):format(
				closer.AbsoluteSize.X,
				ring.AbsoluteSize.X
			)
		)
		local prompt = art:FindFirstChild("HoldPrompt") :: TextLabel
		local words = { ["Tap now!"] = true, ["Click now!"] = true, ["Press Space now!"] = true, ["Press A now!"] = true }
		assert(prompt and prompt.Visible and words[prompt.Text], "uigate: no press prompt on the held ring (#2920)")
		assert(art.Parent and (art.Parent :: GuiObject).Visible, "uigate: the held ring went before the press (#2920)")
	end },
	-- #2871 (console): on a gamepad the catch line under the cat's name names A or R2
	{ "GamepadCatchWords", function()
		UIShim.setLastInput(Enum.UserInputType.Gamepad1)
		local t = workspace:GetServerTimeNow()
		local list = { { startsAt = t + 0.2, shrinkSeconds = 1.2, x = 0.5, y = 0.55 } }
		UI.catch.show({ strayId = "gate_pad", catId = Catalog.cats[2].id, catName = "Mochi", rarity = "Common" })
		UI.catch.showCircles("gate_pad", list :: any, { perfect = 0.074, good = 0.18 })
		UIShim.advance(0.3)
		local found = false
		for _, piece in UIShim.playerGui:GetDescendants() do
			if piece:IsA("TextLabel") and piece.Text:find("each circle meets its ring", 1, true) then
				found = true
				assert(piece.Text:find("Press A or R2", 1, true), "uigate: the catch line on a gamepad reads " .. piece.Text .. " (#2871)")
				assert(piece.TextFits ~= false, "uigate: the gamepad catch line does not fit (#2871)")
			end
		end
		assert(found, "uigate: no catch line under the cat's name (#2871)")
		UIShim.setLastInput(nil)
	end },
	-- #2920 (Derek2: "not even let the player click before its in the circle so you cant miss first one"): a tap before
	-- the held ring stops sends nothing; a tap once it waits goes out as a Perfect
	{ "CatchHoldPress", function()
		local t = workspace:GetServerTimeNow()
		local list = { { startsAt = t + 0.2, shrinkSeconds = 1.2, x = 0.5, y = 0.55, hold = true, holdSeconds = 60 } }
		local sent = {}
		local connection = UI.events.catchPressed:Connect(function(_strayId, index, grade)
			table.insert(sent, tostring(index) .. ":" .. tostring(grade))
		end)
		UI.catch.show({ strayId = "gate_hold2", catId = Catalog.cats[2].id, catName = "Mochi", rarity = "Common" })
		UI.catch.showCircles("gate_hold2", list :: any, { perfect = 0.074, good = 0.18 })
		UIShim.advance(0.7)
		tapCircles()
		UIShim.advance(0.2)
		tapCircles()
		assert(#sent == 0, "uigate: a tap before the held ring stopped went out as " .. table.concat(sent, ", ") .. " (#2920)")
		UIShim.advance(10)
		local layer = UIShim.playerGui:FindFirstChild("CatCafeCatchCircles") :: ScreenGui
		assert(layer.Enabled, "uigate: the catch gave up while the held ring waited (#2920)")
		tapCircles()
		connection:Disconnect()
		assert(#sent == 1 and sent[1] == "1:perfect", "uigate: the press on the held ring went out as " .. table.concat(sent, ", ") .. " (#2920)")
		UI.catch.hide()
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
	-- #3224 (Derek2: the card "just shows cat on top instead of what it is"): a catch that begins with the net swing
	-- has no prompt card up for its stray; the header names the cat from the stray's own attributes
	{ "CatchSwingName", function()
		local model = Instance.new("Model")
		model.Name = "Stray_gate_swing"
		local body = Instance.new("Part")
		body.Name = "Body"
		body.Size = Vector3.new(2, 2, 3)
		body.Position = Vector3.new(0, 3, -12)
		body.Parent = model
		model.PrimaryPart = body
		model:SetAttribute("StrayId", "gate_swing")
		model:SetAttribute("CatId", Catalog.cats[2].id)
		model:SetAttribute("CatName", "Sand Cat")
		model:SetAttribute("Rarity", "Epic")
		model:SetAttribute("Gold", true)
		model:SetAttribute("Variant", "gold")
		model.Parent = workspace
		model:AddTag("Stray")
		local t = workspace:GetServerTimeNow()
		local list = { { startsAt = t + 0.3, shrinkSeconds = 0.8, x = 0.4, y = 0.5 }, { startsAt = t + 1.0, shrinkSeconds = 0.8, x = 0.6, y = 0.5 } }
		UI.catch.showCircles("gate_swing", list :: any, { perfect = 0.037, good = 0.09 })
		UIShim.advance(0.2)
		local layer = UIShim.playerGui:FindFirstChild("CatCafeCatchCircles")
		local name = layer and layer:FindFirstChild("CatName", true)
		local rarity = layer and layer:FindFirstChild("Rarity", true)
		assert(name and name:IsA("TextLabel"), "uigate: no catch header name (#3224)")
		assert(name.Text == "Gold Sand Cat", "uigate: a net-swing catch's header reads " .. name.Text .. ", not Gold Sand Cat (#3224)")
		assert(rarity and rarity.Text == "Epic", "uigate: a net-swing catch's rarity pill reads " .. tostring(rarity and rarity.Text) .. " (#3224)")
		assert(name.TextFits, "uigate: Gold Sand Cat does not fit the catch header (#3224)")
		model:RemoveTag("Stray")
		model:Destroy()
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
	-- #3470 section 5: a black "SECRET" pill with a white edge over each Secret stray and the name under it, "???"
	-- until the kind has been caught once; none over a Mythical; hidden in a net, back on a bolt
	{ "SecretTags", function()
		local function stray(id: string, rarity: string, name: string?, x: number): Model
			local model = Instance.new("Model")
			model.Name = "Stray_" .. id
			local body = Instance.new("Part")
			body.Name = "Body"
			body.Size = Vector3.new(2, 2, 3)
			body.Position = Vector3.new(x, 3, -12)
			body.Parent = model
			model.PrimaryPart = body
			model:SetAttribute("StrayId", id)
			model:SetAttribute("Rarity", rarity)
			model:SetAttribute("CatName", name)
			model.Parent = workspace
			model:AddTag("Stray")
			return model
		end
		local unknown = stray("secret_1", "Secret", "???", -4)
		local known = stray("secret_2", "Secret", "Nebula", 0)
		local plain = stray("secret_3", "Mythical", "Sunbeam", 4)
		-- the shim's tag signals never fire, so start the tags again to pick the three up
		UI.catch.secret:destroy()
		UI.catch.secret = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Screens.SecretTags").new()
		local function tagOf(model: Model): BillboardGui?
			return (model.PrimaryPart :: BasePart):FindFirstChild("CatCafeSecretTag") :: BillboardGui?
		end
		local a, b = tagOf(unknown), tagOf(known)
		assert(a and b, "uigate: no SECRET tag over a Secret stray (#3470)")
		assert(tagOf(plain) == nil, "uigate: a SECRET tag over a Mythical stray (#3470)")
		local tagA, tagB = (a :: any).Tag, (b :: any).Tag
		assert(tagA.Label.Text == "SECRET" and tagB.Label.Text == "SECRET", "uigate: the tag reads SECRET (#3470)")
		assert((a :: any).CatName.Text == "???", "uigate: an uncaught Secret is named ??? (#3470)")
		assert((b :: any).CatName.Text == "Nebula", "uigate: a known Secret shows its name (#3470)")
		assert((a :: BillboardGui).Enabled and (b :: BillboardGui).Enabled, "uigate: the SECRET tags are up (#3470)")
		assert((a :: BillboardGui).AlwaysOnTop and (a :: BillboardGui).MaxDistance == 150, "uigate: seen over walls within 150 studs (#3470)")
		assert(tagA:FindFirstChildOfClass("UIStroke").Color == Color3.new(1, 1, 1), "uigate: the pill has a white edge (#3470)")
		unknown:SetAttribute("LockedBy", 1)
		assert(not (a :: BillboardGui).Enabled, "uigate: the tag should hide while a net holds the cat (#3470)")
		unknown:SetAttribute("LockedBy", 0)
		assert((a :: BillboardGui).Enabled, "uigate: the tag should come back when the cat bolts (#3470)")
		unknown:SetAttribute("CatName", "Glitch")
		assert((a :: any).CatName.Text == "Glitch", "uigate: the name follows the CatName attribute (#3470)")
		plain:SetAttribute("Rarity", "Secret")
		assert(tagOf(plain), "uigate: Rarity set later should bring the tag (#3470)")
		for _, model in { unknown, known, plain } do
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
	-- #2692: at night a new player with the night pass (the NightPass attribute, before the first check-in) sees the
	-- area cards open, no moon cover; once the pass ends, the cover is back
	{ "CannonNightPass", function()
		local t = workspace:GetServerTimeNow()
		UI.clock.set("night", t + 120)
		UI.clock.setAreasOpen(false)
		UIShim.player:SetAttribute("NightPass", true)
		UI.cannon.open()
		UIShim.advance(0.3)
		local window = UIShim.playerGui:FindFirstChild("Cannon", true) :: Instance
		local function covers(): number
			local count = 0
			for _, piece in window:GetDescendants() do
				if piece.Name == "Night" and piece:IsA("GuiObject") and piece.Visible then
					count += 1
				end
			end
			return count
		end
		assert(covers() == 0, "uigate: a night cover shows for a player with the night pass (#2692)")
		UIShim.player:SetAttribute("NightPass", nil)
		UIShim.advance(0.3)
		assert(covers() > 0, "uigate: no night cover once the night pass ends (#2692)")
		UIShim.player:SetAttribute("NightPass", true) -- the shot: open cards at night
		UIShim.advance(0.3)
		Scenes._nightPass = true
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
						or text == "Sold by the night dealer's cart"
						or text == "Sold on the Day Cart from Tier 6", -- #3462
					("uigate: a food row says %q (#1281)"):format(text)
				)
			end
		end
		assert(counts == #Catalog.lures, ("uigate: %d food rows for %d foods"):format(counts, #Catalog.lures))
		-- #3462: the Day Cart's own foods are off the list while its Tier 6 shelf is shut (the cartTier6 switch)
		for _, id in { "honey_cream", "comet_treat" } do
			local row = window:FindFirstChild(id, true)
			assert(row and row:IsA("GuiObject") and not row.Visible, "uigate: " .. id .. " is listed with the cart's shelf shut (#3462)")
		end
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
			shown == "kibble,comet_treat,honey_cream,star_treat,moon_milk,caviar,salmon,sardines,tuna",
			"uigate: the bowl with only Kibble lists " .. shown .. " (#2323)"
		)
		UI.update({ lures = { kibble = 3, salmon = 1 } })
		shown = order()
		assert(
			shown == "salmon,kibble,comet_treat,honey_cream,star_treat,moon_milk,caviar,sardines,tuna",
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
	-- #2795 (Derek2: Grand Opening from the first catch, compact on phones): mid tutorial (the first table step) the
	-- closed strip shows at 0/8 under the goal card beside the tutorial strip, and the first table's toast plays
	{ "GrandOpeningTutorial", function()
		local before = UI.getState() :: any
		-- Scenes.close puts these back, so the scenes after this one keep their bowls, tier and finished tutorial
		Scenes._stepState = {
			upgradeLevels = before.upgradeLevels,
			tutorialStep = before.tutorialStep,
			tier = before.tier,
			grandOpening = before.grandOpening,
		}
		local levels = { tables = 0, lure_bowl = 0, espresso = 0, net = 0, lucky_cat = 0 }
		UI.update({ tutorialStep = 3, tier = 1, upgradeLevels = levels, grandOpening = { done = {} } } :: any)
		UI.tutorial.show(UI.tutorial.hint({ tutorialStep = 3, tier = 1, cats = {}, upgradeLevels = levels }))
		task.wait(0.1)
		local strip = UIShim.playerGui:FindFirstChild("GrandOpening", true)
		assert(strip and strip.Visible, "uigate: no Grand Opening strip after the first catch (#2795)")
		local title = strip:FindFirstChild("Title")
		assert(title and title.Text == "Grand Opening 0/8", "uigate: the strip reads " .. tostring(title and title.Text))
		-- closed, as a new account has it (the roadmapOpen setting starts false), so it takes two lines on a phone
		local steps = strip:FindFirstChild("Steps")
		if steps and steps.Visible then
			UIShim.fire(UIShim.eventOf(strip, "Activated")) -- an earlier scene in this run tapped it open
		end
		assert(steps == nil or not steps.Visible, "uigate: the Grand Opening list did not close (#2795)")
		UI.roadmap.step(1)
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
	-- #2966 and #2968 (console pass 2): on a gamepad the Tackle bar's key cap reads Y, the gift card takes the selection
	-- as it shows, and B closes it and lets go
	{ "GamepadPopups", function()
		local GuiService = game:GetService("GuiService")
		local inputs = game:GetService("UserInputService")
		UIShim.setLastInput(Enum.UserInputType.Gamepad1)
		UIShim.fire(UIShim.eventOf(inputs, "LastInputTypeChanged"), Enum.UserInputType.Gamepad1)
		UI.setZone("Alley")
		UI.shove.setEnabled(true)
		Scenes._tackle = true
		UIShim.advance(0.3)
		local tackle = UIShim.playerGui:FindFirstChild("CatCafeTackle") :: ScreenGui
		local key = tackle and tackle:FindFirstChild("Key", true) :: TextLabel?
		-- a touch screen has the round Tackle button with no key cap
		if not UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Scale").isTouch() then
			assert(key and key.Visible and key.Text == "Y", "uigate: the Tackle bar's key cap reads " .. tostring(key and key.Text) .. " on a gamepad (#2966)")
		end
		GuiService.SelectedObject = nil
		UI.recap.lastInput = os.clock() - 30
		UI.gift.show("fav", { "+$25000", "1 Tip Potion" })
		local card = UIShim.playerGui:FindFirstChild("CatCafeGift"):FindFirstChild("Card", true) :: Frame
		local selected = GuiService.SelectedObject
		assert(selected ~= nil and selected:IsDescendantOf(card), "uigate: the gift card took no selection on a gamepad (#2968)")
		local input = { KeyCode = Enum.KeyCode.ButtonB, UserInputType = Enum.UserInputType.Gamepad1 }
		UIShim.fire(UIShim.eventOf(inputs, "InputBegan"), input, true)
		UIShim.advance(0.1)
		assert(not card.Visible, "uigate: B did not close the gift card (#2968)")
		assert(GuiService.SelectedObject == nil, "uigate: the selection stayed on the closed gift card (#2968)")
		UIShim.setLastInput(nil)
		UIShim.fire(UIShim.eventOf(inputs, "LastInputTypeChanged"), inputs:GetLastInputType())
	end },
	-- #3633 (Derek 2026-11-12: "make the rich tip pop up like 50-75% smaller it takes up too much screen")
	{ "RichTipBubble", function()
		local frames = richTipBubbles()
		for index, holder in frames do
			assert(
				holder.AbsoluteSize.X * holder.AbsoluteSize.Y <= 220 * 168 * 0.45,
				"uigate: the rich tip bubble is not at least 55% smaller than the old 220 x 168 (#3633)"
			)
			for _, label in holder:GetDescendants() do
				if label:IsA("TextLabel") and label.Visible and label.Text ~= "" then
					assert(label.TextFits, "uigate: rich tip bubble " .. index .. " cuts off " .. label.Text .. " (#3633)")
				end
			end
			local more = holder:FindFirstChild("More", true) :: TextLabel
			assert(more.Visible == (index == 2), "uigate: the waiting bags line shows with one bag or hides with two (#3633)")
			local collect = holder:FindFirstChild("Collect", true) :: GuiObject
			assert(collect.AbsoluteSize.Y >= 32, "uigate: the rich tip's Collect is under 32 px tall (#3633)")
		end
	end },
	-- #3464: the Rummage Bin's loot card, a two-item win and a golden crate win
	{ "LootCardTwo", function()
		UI.loot.show({ id = "first_tuna", first = true, items = {
			{ kind = "lure", id = "tuna", count = 2 },
			{ kind = "fish", count = 10 },
		} })
		local card = UIShim.playerGui:FindFirstChild("CatCafeLoot"):FindFirstChild("Card", true)
		assert(card.Visible, "uigate: no loot card for a two-item rummage win (#3464)")
		local rows = card:FindFirstChild("Rows")
		local one, two = rows:FindFirstChild("Row1"), rows:FindFirstChild("Row2")
		assert(one and two and rows:FindFirstChild("Row3") == nil, "uigate: the loot card does not list exactly the two items won (#3464)")
		assert((one:FindFirstChild("Name") :: TextLabel).Text == "Tuna", "uigate: the loot card's first row is not Tuna (#3464)")
		assert((one:FindFirstChild("Amount") :: TextLabel).Text == "x2", "uigate: the loot card's Tuna row does not read x2 (#3464)")
		assert((two:FindFirstChild("Amount") :: TextLabel).Text == "+10", "uigate: the loot card's golden fish row does not read +10 (#3464)")
		-- the pop-in (Effects/LootCardFx) starts the card a little small and lands the rows in turn; once it has
		-- played out the card is at full size with both rows up
		UIShim.advance(1)
		assert(one.Visible and two.Visible, "uigate: a loot card row is still hidden after the pop-in (#3464)")
		assert(one.AbsoluteSize.Y >= 36, "uigate: a loot card row is under 36 px tall (#3464)")
	end },
	{ "LootCardGold", function()
		UI.loot.show({ id = "golden", first = false, items = { { kind = "crate", id = "alley_golden_crate", count = 1 } } })
		local card = UIShim.playerGui:FindFirstChild("CatCafeLoot"):FindFirstChild("Card", true)
		assert(card.Visible, "uigate: no loot card for a golden crate win (#3464)")
		local frame = card:FindFirstChild("Frame") :: UIStroke
		local Theme = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Theme")
		assert(frame.Color == Theme.colors.gold, "uigate: a golden crate win has no gold frame (#3464)")
		-- a tap on the card closes it; a win with nothing to list shows nothing
		UIShim.fire(UIShim.eventOf(card, "Activated"))
		assert(not card.Visible, "uigate: a tap did not close the loot card (#3464)")
		UI.loot.show({ id = "tuna", first = false })
		assert(not card.Visible, "uigate: a win with no items showed a loot card (#3464)")
		UI.loot.show({ id = "golden", first = false, items = { { kind = "crate", id = "alley_golden_crate", count = 1 } } })
	end },
	{ "GiftCardLike", function()
		UI.recap.lastInput = os.clock() - 30 -- idle
		UI.gift.show("like", { "+$12500", "1 Tip Potion" })
		local card = UIShim.playerGui:FindFirstChild("CatCafeGift"):FindFirstChild("Card", true)
		assert(card.Visible, "uigate: no like gift card when idle (#1947)")
		-- #3171: the drawing of the game page with the cursor on its 👍
		local holder = card:FindFirstChild("PictureHolder") :: Frame
		local cursor = holder and holder:FindFirstChild("Cursor", true) :: TextLabel?
		assert(holder and holder.Visible and cursor and cursor.Text == "👆", "uigate: the like card has no game page picture with a cursor (#3171)")
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
		assert(not (card:FindFirstChild("PictureHolder") :: Frame).Visible, "uigate: the favourite card shows the like picture (#3171)")
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
	-- #2792 (Derek2: "make it obvious when he visits"): a new account's first rich customer arrives while the player is
	-- out catching: the ask card's one line says so, and Go to my cafe travels home. The Mystery Visitor's card is next,
	-- and the rich customer's card went when its visit ended
	{ "FirstVisitAway", function()
		local trips = {}
		local connection = UI.events.travel:Connect(function(destination)
			table.insert(trips, destination)
		end)
		local function away()
			return true
		end
		UI.firstVisit.changed("rich", away)
		task.wait(0.1)
		local ask = UIShim.playerGui:FindFirstChild("CatCafeAsk")
		local title = ask and ask:FindFirstChild("Title", true)
		assert(title and title.Text == "💰 A rich customer is at your cafe!", "uigate: the first rich customer's card reads " .. tostring(title and title.Text) .. " (#2792)")
		press("CatCafeAsk", "Choice_go")
		connection:Disconnect()
		assert(#trips == 1 and trips[1] == "home", "uigate: Go to my cafe travelled to " .. table.concat(trips, ", ") .. " (#2792)")
		UI.firstVisit.changed(nil, away)
		UI.firstVisit.changed("mystery", away)
		task.wait(0.1)
		assert(ask:FindFirstChild("Holder", true).Visible and title.Text == "🎁 A visitor left you a gift!", "uigate: no card for the first Mystery Visitor (#2792)")
		UI.firstVisit.changed(nil, away)
		task.wait(0.4)
		assert(not ask:FindFirstChild("Holder", true).Visible, "uigate: the card stays after the visit ended (#2792)")
		UI.firstVisit.changed("collector", away)
	end },
	-- #3620 (Review-QA's Studio round 3: the Daily Treat window opened over the rich customer's card and left it half
	-- hidden): the card waits while a window is up, steps aside when one opens over it and comes back when it closes
	{ "FirstVisitYields", function()
		local function away()
			return true
		end
		-- the card comes at present()'s next one second look after the window has closed, so wait for it, not a fixed time
		local function comes(): boolean
			for _ = 1, 16 do
				if UI.firstVisit.carded then
					return true
				end
				task.wait(0.25)
			end
			return UI.firstVisit.carded
		end
		UI.firstVisit.changed(nil, away)
		UI.open("DailyTreat")
		UI.firstVisit.changed("rich", away)
		task.wait(0.3)
		local ask = UIShim.playerGui:FindFirstChild("CatCafeAsk")
		local holder = ask and ask:FindFirstChild("Holder", true)
		assert(holder and not UI.firstVisit.carded, "uigate: the rich customer's card showed over a window (#3620)")
		UI.close()
		assert(comes() and holder.Visible, "uigate: the card did not come once the window closed (#3620)")
		UI.open("DailyTreat")
		task.wait(0.6)
		assert(not UI.firstVisit.carded, "uigate: the card stayed under a window that opened over it (#3620)")
		UI.close()
		assert(comes() and holder.Visible, "uigate: the card did not come back after the window (#3620)")
	end },
	-- #2791 (Derek2: "we have gift milestones can be improved but don't make this ... take a lot of precious phone
	-- screen space"): the gift ladder on the Rewards tile, no new slot: the tile counts down to the next step and its
	-- list shows the next two with what they pay
	{ "GiftLadder", function()
		Scenes._ladder = true -- Scenes.close takes the ladder away again
		UI.update({
			playSeconds = 15,
			giftNext = {
				{ id = "m2", at = 120, prize = { coinSeconds = 60 } },
				{ id = "m4", at = 240, prize = { lures = { tuna = 1 } } },
			},
		} :: any)
		local hudGui = UIShim.playerGui:FindFirstChild("CatCafeHUD")
		local tile = hudGui and hudGui:FindFirstChild("Rewards", true)
		assert(tile and tile.Visible, "uigate: no Rewards tile with the gift ladder (#2791)")
		local label = tile:FindFirstChild("Label", true)
		local text = label and label.Text or ""
		-- the time to the next gift, or "Rewards" with the red "!" while a Tip Jar gift waits (the sample player's)
		local dot = tile:FindFirstChild("Dot", true)
		assert(string.match(text, "^%d+:%d%d$") or (text == "Rewards" and dot and dot.Visible), "uigate: the Rewards tile reads " .. text .. ", not the next gift's time (#2791)")
		press("CatCafeHUD", "Icons.Rewards")
		local pop = hudGui:FindFirstChild("Pop", true)
		assert(pop and pop.Visible, "uigate: the Rewards tile didn't open the gift list (#2791)")
		local first = pop:FindFirstChild("Ladder1")
		local second = pop:FindFirstChild("Ladder2")
		assert(first and second, "uigate: the gift list doesn't show the next two steps (#2791)")
		local words = first:FindFirstChild("Label", true)
		assert(words and string.find(words.Text, "$", 1, true), "uigate: the first step reads " .. tostring(words and words.Text) .. " (#2791)")
	end },
	-- #2797 (Derek2: "reward for inviting and do after 5 min-15 min"): the one invite card with its reward, on the
	-- slide-in ask card (UIController's offerInvite times it); its two lines fit a small phone
	{ "InviteRewardCard", function()
		local InviteCardLogic = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Components.InviteCardLogic")
		local view = { cardShown = false, fish = 20, leftToday = 5, cardFrom = 300, cardBy = 900 }
		UI.asks.skipPace() -- #2880: as if the session had run its first minutes
		local shown = UI.asks.card({
			title = InviteCardLogic.title(view),
			choices = {
				{ id = "invite", label = InviteCardLogic.INVITE, style = "primary" },
				{ id = "later", label = InviteCardLogic.NOT_NOW, style = "ghost" },
			},
			seconds = InviteCardLogic.SECONDS,
			lines = 2,
			answer = function() end,
		})
		assert(shown, "uigate: the invite card didn't show (#2797)")
		local ask = UIShim.playerGui:FindFirstChild("CatCafeAsk")
		local title = ask and ask:FindFirstChild("Title", true)
		assert(title and string.find(title.Text, "you both get", 1, true), "uigate: the invite card reads " .. tostring(title and title.Text) .. " (#2797)")
	end },
	-- #2798 (Derek2: the Cozy Cafe countdown is the gift icon's tooltip, not a new strip): standing in your cafe, the
	-- Rewards list says when the next Cozy gift comes; once the bag waits on the counter the tile wears the red "!"
	{ "CozyCountdown", function()
		local plot = Instance.new("Model")
		plot.Name = "CozyPlot"
		plot:SetAttribute("CozyActive", true)
		plot:SetAttribute("CozyNextAt", workspace:GetServerTimeNow() + 130)
		plot:SetAttribute("CozyBagAt", 0)
		Scenes._cozy = plot -- Scenes.close takes it away again
		UI.cozy.plot = plot
		UI.cozy.refresh()
		press("CatCafeHUD", "Icons.Rewards")
		local hudGui = UIShim.playerGui:FindFirstChild("CatCafeHUD")
		local pop = hudGui:FindFirstChild("Pop", true)
		local row = pop and pop.Visible and pop:FindFirstChild("Cozy")
		local words = row and row:FindFirstChild("Label", true)
		assert(words and string.match(words.Text, "^Cozy gift in 2:%d%d$"), "uigate: the Cozy row reads " .. tostring(words and words.Text) .. " (#2798)")
		plot:SetAttribute("CozyActive", false)
		plot:SetAttribute("CozyBagAt", workspace:GetServerTimeNow())
		UI.cozy.refresh()
		assert(hudGui:FindFirstChild("Rewards", true):FindFirstChild("Dot", true).Visible, "uigate: no red ! on the Rewards tile for a waiting Cozy bag (#2798)")
		-- the open list's row follows (HUD._fillPop)
		assert(pop.Visible, "uigate: the Rewards list closed (#2798)")
		words = row:FindFirstChild("Label", true)
		assert(words and words.Text == "Cozy gift waiting!", "uigate: the waiting bag's row reads " .. tostring(words and words.Text) .. " (#2798)")
		-- #2854 (Derek2: "make it auto claim if clicked"): a press on the waiting bag's row asks the server to take it
		local asked = 0
		local connection = UI.events.takeCozy:Connect(function()
			asked += 1
		end)
		press("CatCafeHUD", "Pop.Cozy")
		connection:Disconnect()
		assert(asked == 1, "uigate: the Cozy gift row's press did not ask to take the bag (#2854)")
	end },
	-- #1893: step 8's Grand Opening banner
	{ "GrandOpeningDone", function()
		UI.update({ tutorialStep = 9, grandOpening = { done = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true } } })
		UI.roadmap.step(8)
	end },
	-- #1895: the account's short first bait in the bowl: "A cat is coming!" on the HUD's row over the money and in the
	-- Bait bowl window. #2946: Config.FirstBaitWaitSeconds (1 s since then, 45 s for #2774, 120 before); the scene
	-- holds the wait a second longer (FirstBait.SLACK) so the line is still up when it is checked
	{ "BaitFirstComing", function()
		local now = workspace:GetServerTimeNow()
		local first = UIShim.require("ReplicatedStorage.Shared.Config").FirstBaitWaitSeconds + 1
		UI.bait.set({ lureId = Catalog.lures[1].id, readyAt = now + first, placedAt = now }, 1)
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
	-- #3008 (Derek2: "make the food bowl refill button a bit smaller but always there and it refills with your best
	-- food available"): Refill is its own smaller button on the status card with the food's picture beside it. On an
	-- empty bowl it is live and a press puts in the rarest food in the bag; with food in the bowl it stays, greyed;
	-- with an empty bag it stays, greyed, and reads "No food". (#1573's Refill was the big action button, only with
	-- the food the bowl last held.)
	{ "BaitRefill", function()
		local now = workspace:GetServerTimeNow()
		local before = UI.getState()
		local tuna = Catalog.lures[2]
		UI.update({ lures = { kibble = 3, [tuna.id] = 2, salmon = 1 } })
		UI.bait.set(nil, 1)
		UI.bait.openPicker()
		local status = baitWindow():FindFirstChild("Status", true)
		local refill = status and status:FindFirstChild("Refill") :: GuiObject?
		assert(refill and refill.Visible, "uigate: no Refill on the empty bowl (#3008)")
		local action = status:FindFirstChild("Action") :: GuiObject
		assert(not action.Visible, "uigate: the empty bowl has a second button beside Refill (#3008)")
		assert(
			refill.AbsoluteSize.X < action.AbsoluteSize.X and refill.AbsoluteSize.Y < action.AbsoluteSize.Y,
			"uigate: Refill is not smaller than the card's action button (#3008)"
		)
		local function words(): string
			local shown = (refill :: GuiObject):FindFirstChildWhichIsA("TextLabel", true)
			return if shown then shown.Text else ""
		end
		assert(string.find(words(), "Refill", 1, true), "uigate: Refill reads " .. words() .. " (#3008)")
		local picture = status:FindFirstChild("RefillFood") :: GuiObject?
		assert(picture and picture.Visible, "uigate: no picture of the food Refill uses (#3008)")
		local sub = status:FindFirstChild("Sub", true)
		-- #1693: the line is just the wait
		assert(
			sub and string.find(sub.Text, "A cat comes by in", 1, true),
			"uigate: the empty bowl's line is not the wait (#1693)"
		)
		-- a press puts in the best food in the bag: the Salmon, not the Tuna or the Kibble
		local sent = nil
		local connection = UI.events.useLure:Connect(function(lureId, bowl)
			sent = tostring(lureId) .. "@" .. tostring(bowl)
		end)
		press("Bait", "Status.Refill")
		assert(sent == "salmon@1", "uigate: Refill sent " .. tostring(sent) .. " (#3008)")
		-- food in the bowl: Refill stays, greyed, and a press sends nothing
		UI.bait.set({ lureId = "salmon", readyAt = now + 300, placedAt = now }, 1)
		UI.update({ lures = { kibble = 3, [tuna.id] = 2 } })
		assert(refill.Visible, "uigate: Refill went while food is in the bowl (#3008)")
		sent = nil
		press("Bait", "Status.Refill")
		assert(sent == nil, "uigate: Refill on a full bowl sent " .. tostring(sent) .. " (#3008)")
		-- an empty bowl and an empty bag: still there, greyed, "No food", no picture
		UI.bait.set(nil, 1)
		UI.update({ lures = {} })
		assert(refill.Visible, "uigate: Refill went with an empty bag (#3008)")
		assert(string.find(words(), "No food", 1, true), "uigate: Refill with no food reads " .. words() .. " (#3008)")
		assert(not picture.Visible, "uigate: a food picture beside Refill with an empty bag (#3008)")
		sent = nil
		press("Bait", "Status.Refill")
		connection:Disconnect()
		assert(sent == nil, "uigate: Refill with an empty bag sent " .. tostring(sent) .. " (#3008)")
		-- left for the picture: the empty bowl with the bag's best food on the button
		UI.update({ lures = { kibble = 3, [tuna.id] = 2, salmon = 1 } })
		Scenes._refillBag = before.lures
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
	-- #3815: the first bowl cat (tutorial step 4) has one wide glowing "Tame it!" with the tutorial's arrow and no X, Let go
	-- or line under the cat; a later bowl cat's card has them all back
	{ "BaitCardFirst", function()
		local now = workspace:GetServerTimeNow()
		local cat = { catId = Catalog.cats[1].id, stars = 1 }
		UI.bait.set({ lureId = Catalog.lures[1].id, readyAt = now - 5, placedAt = now - 30 }, 1)
		-- a first bowl cat's card, then a later one's: the later card has its X and Let go back and no glow
		UI.update({ tutorialStep = 4 })
		UI.bait.showReady(cat, 1)
		UI.update({ tutorialStep = 9 })
		UI.bait.showReady(cat, 1)
		local card = UIShim.playerGui:FindFirstChild("CatCafeBaitCard")
		local tame = card:FindFirstChild("Tame", true)
		assert(card:FindFirstChild("LetGo", true).Visible and card:FindFirstChild("Close", true).Visible,
			"uigate: a later bowl cat's card lost Let go or the X (#3815)")
		assert(tame:FindFirstChild("TutorialGlow") == nil, "uigate: a later bowl cat's Tame still glows (#3815)")
		-- the first bowl cat's card, as the scene's picture
		UI.update({ tutorialStep = 4 })
		UI.bait.showReady(cat, 1)
		assert(tame.Visible and tame.Size.X.Offset >= 200, "uigate: the first bowl cat's Tame is not the wide one (#3815)")
		assert(tame:FindFirstChild("TutorialGlow") ~= nil, "uigate: the first bowl cat's Tame does not glow (#3815)")
		assert(not card:FindFirstChild("LetGo", true).Visible, "uigate: the first bowl cat's card shows Let go (#3815)")
		assert(not card:FindFirstChild("Close", true).Visible, "uigate: the first bowl cat's card shows the X (#3815)")
		assert(not card:FindFirstChild("Hint", true).Visible, "uigate: the first bowl cat's line sits under the arrow (#3815)")
		local label = tame:FindFirstChildWhichIsA("TextLabel", true)
		assert(label and label.Text == "Tame it!", "uigate: the first bowl cat's button says " .. tostring(label and label.Text))
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
		assert(badgeDraws("CafePass", "73605076279409"), "uigate: the Cafe Pass badge is not the Pass medal (#2588)")
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
			if piece:IsA("ImageLabel") and string.find(piece.Image, "124822185603420", 1, true) then
				drawn = true
			end
		end
		assert(drawn, "uigate: the Pumpkin uniform's square does not draw its picture (#2592)")
	end },
	-- #1626: the busiest top strip, a VIP owner who has not bought the paid track: Buy and Claim all. Derek2 11-11:
	-- the chat tag button left the pass for the Bag's Titles tab
	{ "CafePassTag", function()
		UI.store.preview({ [3728336202] = { robux = 299, forSale = true } }, {})
		UI.pass.set({ season = 1, startsAt = 0, endsAt = 1798934400, level = 4, xp = 3500, xpPerLevel = 800,
			levels = 30, paid = false, claimedFree = {}, claimedPaid = {}, claimable = 2, items = {},
			tags = { "vip" }, tagShown = "vip" })
		UI.pass.open()
		local modals = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("CatCafeModals")
		local window = modals and modals:FindFirstChild("CafePass", true)
		local tag = window and window:FindFirstChild("ChatTag", true)
		assert(not (tag and tag:IsA("GuiObject") and tag.Visible), "uigate: the Cafe Pass still shows the chat tag button")
	end },
	-- Derek2 11-11: the Bag's Titles tab: No title, the owned VIP title equipped, the rest greyed with no Equip
	{ "BagTitles", function()
		UI.pass.set({ season = 1, startsAt = 0, endsAt = 1798934400, level = 4, xp = 3500, xpPerLevel = 800,
			levels = 30, paid = false, claimedFree = {}, claimedPaid = {}, claimable = 0, items = {},
			tags = { "vip" }, tagShown = "vip" })
		UI.open("Potions")
		press("Potions", "TitlesTab")
		local window = UIShim.playerGui:FindFirstChild("Potions", true)
		local list = window and window:FindFirstChild("TitleList", true)
		assert(list and list:IsA("GuiObject") and list.Visible, "uigate: the Bag's Titles list is not up")
		local vip = list:FindFirstChild("vip")
		local equip = vip and vip:FindFirstChild("Equip", true)
		assert(equip and (equip :: any).Visible, "uigate: the owned VIP title has no button")
		local maple = list:FindFirstChild("tag_maple")
		local locked = maple and maple:FindFirstChild("Equip", true)
		assert(maple and not (locked and (locked :: any).Visible), "uigate: a locked title shows Equip")
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
	-- #3157 (Derek2: "spin the wheel one after another not all at once into one spin"): Use all plays each roll in
	-- turn with "Spin 1 of 3" above Spin; Skip lands one and the next turns after a beat; Skip all shows the card
	{ "SpinAllChain", function()
		UI.spin.open()
		UI.spin.allResult(
			{ { slice = 1, amount = 100 }, { slice = 2, amount = 3 }, { slice = 3, amount = 1 } },
			{ { kind = "coins", amount = 100 } }
		)
		UIShim.advance(0.5)
		local window = UIShim.playerGui:FindFirstChild("SpinWheel", true)
		local spins = window:FindFirstChild("Spins", true)
		assert(spins.Text == "Spin 1 of 3", "uigate: no Spin 1 of 3 while Use all plays (#3157): " .. spins.Text)
		local all = window:FindFirstChild("UseAll", true)
		assert(all.Visible, "uigate: no Skip all while Use all plays (#3157)")
		press("SpinWheel", "SkipTap")
		UIShim.advance(0.7)
		assert(spins.Text == "Spin 2 of 3", "uigate: the next roll did not turn after a Skip (#3157): " .. spins.Text)
		press("SpinWheel", "UseAll")
		UIShim.advance(0.7)
		local card = window:FindFirstChild("AllCard", true)
		assert(card and card.Visible, "uigate: Skip all did not show the totals card (#3157)")
		assert(spins.Text ~= "Spin 2 of 3", "uigate: the count stayed up after Skip all (#3157)")
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
		-- #3535: the Speed Shoes are on the shelf (their switch on), so the featured card is there in their week too
		game:GetService("ReplicatedStorage"):SetAttribute("LiveFlag_speedShoes", true)
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
		local shoes = false
		for _, piece in window:GetDescendants() do
			if piece:IsA("TextLabel") and piece.Text == "Speed Shoes" then
				shoes = true
				assert(piece.TextFits, "uigate: the Speed Shoes' name does not fit its card (#3535)")
			end
		end
		assert(shoes, "uigate: the Speed Shoes are not on Juniper's shelf with their switch on (#3535)")
		UI.update({ mysterySeen = true } :: any)
	end },
	-- #2574: the featured item owned and buys not open yet ("Soon")
	{ "MysteryMarketOwned", function()
		local before: any = UI.getState()
		Scenes._cashMoney = { money = before.money, passBoosts = before.passBoosts or false, goldenFish = before.goldenFish or 0 }
		UI.update({ goldenFish = 1200, mystery = { backpack = true, long_net = true }, mysterySeen = true, mysteryOpen = false } :: any)
		UI.mystery.open()
	end },
	-- #3699: the owned Backpack's button reads "Colours" with the switch bagColours on, and opens the picker in
	-- Juniper's window: Mint for the bag and Gold for the trim tapped, Save sends SetBagColours once
	{ "BagColourPicker", function()
		local before: any = UI.getState()
		Scenes._cashMoney = { money = before.money, passBoosts = before.passBoosts or false, goldenFish = before.goldenFish or 0 }
		local RS = game:GetService("ReplicatedStorage")
		RS:SetAttribute("LiveFlag_bagColours", true)
		UI.update({ goldenFish = 1200, mystery = { backpack = true }, mysterySeen = true, mysteryOpen = true, bagColours = false } :: any)
		UI.mystery.open()
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local window = modals and modals:FindFirstChild("MysteryMarket", true)
		assert(window, "uigate: no Mystery Market window (#3699)")
		local open: any = nil
		for _, item in window:GetDescendants() do
			if item:IsA("TextLabel") and item.Text == "Colours" then
				open = item
			end
		end
		assert(open, "uigate: the owned Backpack's button does not read Colours (#3699)")
		local holder: any = open.Parent
		while holder and holder.Name ~= "Buy" do
			holder = holder.Parent
		end
		assert(holder, "uigate: the Colours label is not on a Buy button (#3699)")
		local function tap(target: any, what: string)
			assert(target, "uigate: no " .. what .. " (#3699)")
			local button = nil
			if target:IsA("GuiButton") and target.Interactable ~= false then
				button = target
			else
				for _, piece in target:GetDescendants() do
					if piece:IsA("GuiButton") and piece.Interactable ~= false then
						button = piece
						break
					end
				end
			end
			assert(button, "uigate: " .. what .. " has no button (#3699)")
			UIShim.fire(UIShim.eventOf(button, "Activated"))
		end
		tap(holder, "Colours button")
		local picker = window:FindFirstChild("BagColours", true)
		assert(picker and picker.Visible, "uigate: Colours did not open the picker (#3699)")
		local sent: { string } = {}
		local listening = UI.events.setBagColours:Connect(function(main: string, trim: string)
			table.insert(sent, main .. "/" .. trim)
		end)
		local bag = picker:FindFirstChild("main", true)
		local trim = picker:FindFirstChild("trim", true)
		assert(bag and trim, "uigate: the picker has no Bag and Trim grids (#3699)")
		tap(bag:FindFirstChild("Swatch_mint"), "Mint swatch")
		-- a short screen shows one block at a time behind Bag and Trim tabs; a tall one shows both
		local trimTab = picker:FindFirstChild("Tab_trim", true)
		if trimTab ~= nil then
			assert(bag.Visible and not trim.Visible, "uigate: a short screen should open on the Bag block alone (#3699)")
			tap(trimTab, "Trim tab")
			assert(trim.Visible and not bag.Visible, "uigate: the Trim tab did not show the Trim block (#3699)")
		else
			assert(bag.Visible and trim.Visible, "uigate: a tall screen shows both blocks (#3699)")
		end
		tap(trim:FindFirstChild("Swatch_honey"), "Honey swatch")
		tap(picker:FindFirstChild("Save", true), "Save")
		listening:Disconnect()
		assert(#sent == 1 and sent[1] == "mint/honey", "uigate: Save should send the two picks once (#3699), got " .. table.concat(sent, ","))
		UI.update({ bagColours = { main = "mint", trim = "honey" } } :: any)
		RS:SetAttribute("LiveFlag_bagColours", nil)
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
	-- #3722: the Market's crate cards are not built inside setCatalog; opening the window builds them at once
	{ "MarketDelayedBuild", function()
		UI.setCatalog(catalogLikeTheGame())
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local window = modals and modals:FindFirstChild("FishMarket", true) :: Instance?
		assert(window, "uigate: no Market window (#3722)")
		local ids: { [string]: boolean } = {}
		for _, crate in (catalogLikeTheGame() :: any).crates or {} do
			ids[crate.id] = true
		end
		local function cards(): number
			local n = 0
			for _, each in (window :: Instance):GetDescendants() do
				if each:IsA("Frame") and ids[each.Name] then
					n += 1
				end
			end
			return n
		end
		assert(cards() == 0, ("uigate: setCatalog built %d Market crate cards at once (#3722)"):format(cards()))
		UI.market.open()
		assert(cards() > 0, "uigate: opening the Market built no crate cards (#3722)")
		UI.close()
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
	-- #2745: two Alley Crates on offer in a trade: their card reads "In a trade" with Open greyed; the Park Crates open
	{ "MarketCrateInTrade", function()
		Scenes._crates = (UI.getState() :: any).crates or {}
		UI.update({ crates = { park_crate = 2, alley_crate = 3 } } :: any)
		local state = tradeState()
		state.cratesOn = true
		state.me.crates = { { id = "alley_crate", name = "Alley Crate", area = "alley", count = 2 } }
		UI.trade.state(state)
		UI.market.open()
		press("FishMarket", "CratesTab")
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local market = modals and modals:FindFirstChild("FishMarket", true)
		local found = false
		for _, label in (market or Instance.new("Folder")):GetDescendants() do
			if label:IsA("TextLabel") and label.Text == "You have 3 (2 in a trade)" then
				found = true
			end
		end
		assert(found, "uigate: the Alley Crate's card does not say it is in a trade (#2745)")
	end },
	-- #2290 (Derek2: "buying items fast from shop sometimes stays too long on the ... waiting button"): three perks
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
		-- #3317: the Star Treat left the Market, so three perks (Swift Paws first)
		local ids = { "swift_paws", "golden_espresso", "big_bowl" }
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
		-- #3190: a perk reads "..." until its next price comes
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
	-- #3298: the Lucky Charm row is hidden until its switch is on; on, it shows with its level, price and what it adds
	{ "MarketLuckyCharm", function()
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		UI.update({ fishPerks = { lucky_charm = 1 } } :: any) -- the next scene clears it
		UI.market.open()
		press("FishMarket", "TreatsTab")
		local window = UIShim.playerGui:FindFirstChild("FishMarket", true)
		local row = window and window:FindFirstChild("lucky_charm", true) :: GuiObject?
		assert(row and not row.Visible, "uigate: the Lucky Charm row shows with its switch off (#3298)")
		ReplicatedStorage:SetAttribute("LiveFlag_luckyCharm", true)
		UI.update({ fishPerks = { lucky_charm = 1 } } :: any)
		assert(row.Visible, "uigate: the Lucky Charm row is hidden with its switch on (#3298)")
		local found: { [string]: boolean } = {}
		for _, piece in row:GetDescendants() do
			if piece:IsA("TextLabel") or piece:IsA("TextButton") then
				if string.find(piece.Text, "Lucky Charm", 1, true) then found.name = true end
				if string.find(piece.Text, "+0.1 Luck", 1, true) then found.blurb = true end
				if string.find(piece.Text, "Level 1 / 3", 1, true) then found.level = true end
				if string.find(piece.Text, "250", 1, true) then found.price = true end
			end
		end
		assert(found.name and found.blurb and found.level and found.price, "uigate: the Lucky Charm row misses its name, line, level or price (#3298)")
		local list = row:FindFirstAncestorWhichIsA("ScrollingFrame")
		if list then
			list.CanvasPosition = Vector2.new(0, 100000) -- the picture: the last row, scrolled into view
		end
	end },
	-- #2577 (Derek2: "the buttons for buying crates sometimes get stuck on ... for a while"): only the pressed crate reads
	-- "...", another crate's press queues behind it, and an open the server never answers frees its button after 6 s (#3362: 2.5 before)
	-- as "Try again" (with a toast), when the queued press goes
	{ "MarketCrateWait", function()
		game:GetService("ReplicatedStorage"):SetAttribute("LiveFlag_luckyCharm", nil) -- #3298: back to its default
		UI.update({ fishPerks = {} } :: any)
		local charmRow = UIShim.playerGui:FindFirstChild("lucky_charm", true)
		local charmList = charmRow and charmRow:FindFirstAncestorWhichIsA("ScrollingFrame")
		if charmList then
			charmList.CanvasPosition = Vector2.zero
		end
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
		UIShim.advance(2.8) -- no CrateResult for park; #3362: a slow answer is still waited for
		assert(label("park_crate") == "...", "uigate: an Open reads " .. label("park_crate") .. " after 2.8 s, before its 6 s wait is up (#3362)")
		UIShim.advance(3.5)
		assert(label("park_crate") == "Try again", "uigate: an unanswered Open reads " .. label("park_crate") .. " after 6.3 s (#2577)")
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
	{ "Feedback", function()
		UI.bugReport.open("bug")
	end },
	-- #3066: the feedback stand opens the window straight on its text box, on the Idea chip, with no faces first
	{ "FeedbackStand", function()
		UI.bugReport.open("idea", "none")
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
	-- #3657: a thumbs down on the slide-in ask brings the reasons up on the same card, in two rows with Skip; the
	-- face is sent once, with the reason tapped
	{ "FeedbackAskReasons", function()
		local sent = {}
		local connection = UI.events.sendFeedback:Connect(function(face, chip)
			table.insert(sent, tostring(face) .. ":" .. tostring(chip))
		end)
		-- an ask the scene before left saying "Thanks!" slides away first (showAsk leaves a shown card alone)
		-- the clock is run by hand: a scene that yields is left behind on a slow CI run and wakes inside a later scene
		UIShim.advance(2.5)
		UI.tips.showAsk()
		UIShim.advance(0.4)
		press("CatCafeAsk", "Choice_no")
		UIShim.advance(0.2)
		local ask = UIShim.playerGui:FindFirstChild("CatCafeAsk")
		local title = ask:FindFirstChild("Title", true)
		assert(title.Text == "What is the main reason?", "uigate: after a thumbs down the ask reads " .. title.Text .. " (#3657)")
		assert(title.TextFits, "uigate: the reasons title does not fit (#3657)")
		assert(#sent == 0, "uigate: the face was sent before a reason could be picked (#3657)")
		local second = ask:FindFirstChild("Choices2", true)
		assert(second.Visible, "uigate: the reasons ask has no second row (#3657)")
		for _, name in { "Choice_too_hard", "Choice_confusing", "Choice_boring", "Choice_laggy", "Choice_skip" } do
			local piece = ask:FindFirstChild(name, true)
			assert(piece, "uigate: the reasons ask lacks " .. name .. " (#3657)")
			local label = piece:FindFirstChildWhichIsA("TextLabel", true)
			assert(label == nil or label.TextFits, "uigate: " .. name .. "'s words do not fit (#3657)")
		end
		press("CatCafeAsk", "Choice_boring")
		connection:Disconnect()
		assert(#sent == 1 and sent[1] == "no:boring", "uigate: the reasons ask sent " .. table.concat(sent, " ") .. " (#3657)")
	end },
	-- #3272 (Derek2: "a thumb up or down or neutral face very simple"): the once-a-day session ask, thumbs up, a plain
	-- face and thumbs down, with its title on one card
	{ "SessionAsk", function()
		-- it takes the card over from the F87 faces ask, as on a slow CI run where the tips clock put that one up first
		UI.tips.showAsk()
		UI.tips.showSessionAsk()
		task.wait(0.3)
		local found = {}
		for _, piece in UIShim.playerGui:GetDescendants() do
			if piece:IsA("TextLabel") or piece:IsA("TextButton") then
				local text = (piece :: TextLabel).Text
				if text == "Enjoying Catch a Cat Cafe?" or text:find("👍") or text:find("😐") or text:find("👎") then
					if (piece :: GuiObject).Visible then
						found[text] = piece
					end
				end
			end
		end
		local title = found["Enjoying Catch a Cat Cafe?"] :: TextLabel?
		assert(title, "uigate: the session ask has no title (#3272)")
		assert(title.TextFits, "uigate: the session ask's title does not fit (#3272)")
		local glyphs = 0
		for text in found do
			if text ~= "Enjoying Catch a Cat Cafe?" then
				glyphs += 1
			end
		end
		assert(glyphs >= 3, ("uigate: the session ask shows %d of the three thumbs and face (#3272)"):format(glyphs))
	end },
	-- #3296: Mouse Dash. With its switch on the cabinet opens its card: the best and titles, today's prizes (the
	-- arcade's, shared), "Play (free)" and no way to Circle Streak once that game is vaulted
	{
		"MouseDashCard",
		function()
			local window = mouseDashCard(false)
			local play = window:FindFirstChild("Play", true):FindFirstChildWhichIsA("TextLabel", true)
			assert(play.Text == "Play (free)", "uigate: Mouse Dash's Play reads " .. play.Text .. " (#3296)")
			local records = window:FindFirstChild("Records", true)
			assert(records.Text == "Best 37 · Mouser", "uigate: Mouse Dash's records read " .. records.Text .. " (#3296)")
			-- #3553: the lit sign, the free play, the next prize with its picture, and no prize list until Prizes is pressed
			local sign = window:FindFirstChild("Sign", true)
			assert(sign and sign:FindFirstChild("Title").Text == "MOUSE DASH", "uigate: no lit sign on Mouse Dash's card (#3553)")
			assert(window:FindFirstChild("Free", true).Text == "1 free play today", "uigate: the free play reads " .. window:FindFirstChild("Free", true).Text .. " (#3553)")
			local nextCard = window:FindFirstChild("NextCard", true)
			assert(nextCard.Words.Text == "Golden Crate + Caviar at 30 points", "uigate: the menu's next prize reads " .. nextCard.Words.Text .. " (#3553)")
			assert(nextCard.Picture.Image.Image ~= "", "uigate: the menu's next prize has no picture (#3553)")
			local prizes = window:FindFirstChild("PrizeList", true)
			assert(prizes and not prizes.Visible, "uigate: the prize list shows before Prizes is pressed (#3553)")
			press("MouseDash", "Prizes")
			assert(prizes.Visible, "uigate: Prizes did not open the prize list (#3553)")
			local last = prizes:FindFirstChild("Prize100")
			assert(last and last.PrizeName.Text == "3 Star Treats + 2 Alley Crates + 50 fish", "uigate: Mouse Dash's card lacks the arcade's prizes (#3296)")
			for _, at in { 10, 20, 30, 100 } do
				local row = prizes:FindFirstChild("Prize" .. at)
				assert(row.Picture.Image.Image ~= "", "uigate: prize " .. at .. " has no picture (#3553)")
				assert(row.Picture.AbsoluteSize.Y >= 30, "uigate: prize " .. at .. "'s picture is " .. row.Picture.AbsoluteSize.Y .. " px (#3553)")
			end
			assert(prizes.Prize10.Mark.Text:find("Earned", 1, true) and prizes.Prize30.Mark.Text == "NEXT", "uigate: the prize list does not mark earned and next (#3553)")
			assert(not prizes.Prize40.Mark.Visible, "uigate: a prize still to come is marked (#3553)")
			-- the leaderboard in the station menus' row look (Derek 2026-11-12), the player's own row edged
			press("MouseDash", "Leaderboard")
			assert(not prizes.Visible, "uigate: the prize list stays up under the leaderboard (#3553)")
			local top = window:FindFirstChild("TopList", true)
			assert(top and top.Visible and top.Top1.PlayerName.Text == "Sam" and top.Top1.Badge.Rank.Text == "1", "uigate: the leaderboard's first row is wrong")
			assert(top.Top2.Visible and top.Top2:FindFirstChildWhichIsA("UIStroke").Enabled, "uigate: the player's own leaderboard row has no edge")
			assert(not top.Top3.Visible, "uigate: an empty leaderboard row shows")
			press("MouseDash", "Leaderboard")
			assert(not top.Visible, "uigate: a second press did not fold the leaderboard away (#3553)")
			assert(window:FindFirstChild("IdeaBy", true), "uigate: no idea credit on Mouse Dash's card (#3296)")
			local other = window:FindFirstChild("CircleStreak", true)
			assert(other and not other.Visible, "uigate: a vaulted Circle Streak still has its button (#3296)")
			local sent = false
			local connection = UI.events.mouseDashPlay:Connect(function()
				sent = true
			end)
			press("MouseDash", "Play")
			connection:Disconnect()
			assert(sent, "uigate: Play on Mouse Dash's card sent nothing (#3296)")
		end,
	},
	-- #3296: while both switches are on (testing) the card has a button to Circle Streak, which opens its card
	{
		"MouseDashBoth",
		function()
			local window = mouseDashCard(true)
			local other = window:FindFirstChild("CircleStreak", true)
			assert(other and other.Visible, "uigate: no button to Circle Streak while both games are on (#3296)")
			press("MouseDash", "CircleStreak")
			assert(UI.isOpen() == "Arcade", "uigate: the Circle Streak button opened " .. tostring(UI.isOpen()) .. " (#3296)")
			UI.close()
			mouseDashCard(true)
		end,
	},
	-- #3296: a game on the board: nine holes that never overlap, 64 px or more each, the hearts and score strip clear
	-- of every hole, and each animal centred in its hole. A tap sends the run, the wave and the hole.
	{
		"MouseDashBoard",
		function()
			local window = mouseDashCard(false)
			local nowAt = workspace:GetServerTimeNow()
			UI.mouseDash.began(7, 3, nowAt, nowAt + 92)
			UI.mouseDash.wave(7, 1, {
				{ hole = 2, kind = "mouse", upAt = nowAt, downAt = nowAt + 600 },
				{ hole = 6, kind = "kitten", upAt = nowAt, downAt = nowAt + 600 },
				{ hole = 7, kind = "golden", upAt = nowAt, downAt = nowAt + 600 },
			}, nil)
			UI.mouseDash.judged(7, 1, { outcome = "empty", hole = 9, gain = 0, heart = 0 }, 23, 2, 4, {}, 0)
			local board = window:FindFirstChild("Board", true)
			assert(board and board.Visible, "uigate: Mouse Dash's board did not come up (#3296)")
			assert(board:FindFirstChild("Score", true).Text == "23", "uigate: the score is not the server's (#3296)")
			-- #3553: the next prize's banner, with its picture and bar, clear of every hole (checked below with the strip)
			local banner = board:FindFirstChild("NextPrize")
			assert(banner and banner.Visible, "uigate: no next prize banner on the board of " .. tostring(board.AbsoluteSize) .. " (#3553)")
			assert(banner.Bar.Count.Text == "23/30", "uigate: the banner's bar reads " .. banner.Bar.Count.Text .. " (#3553)")
			assert(banner.Picture.Image.Image ~= "", "uigate: the banner has no prize picture (#3553)")
			-- the run's clock (Derek 2026-11-12): time left, in place of the best
			local clock = board:FindFirstChild("Time", true)
			assert(clock, "uigate: no clock on the board")
			local hud = board:FindFirstChild("Hud")
			local holes = {}
			for index = 1, 9 do
				local hole = board:FindFirstChild("Hole" .. index, true)
				assert(hole and hole:IsA("GuiButton"), "uigate: no hole " .. index .. " (#3296)")
				holes[index] = hole
				local size, at = hole.AbsoluteSize, hole.AbsolutePosition
				-- #3518: 64 px, or 52 on a phone under 360 px tall (a Galaxy A06 draws them 56), still over the 44 px a
				-- finger needs
				local least = if (workspace.CurrentCamera :: Camera).ViewportSize.Y < 360 then 52 else 64
				assert(size.X >= least and size.Y >= least, "uigate: hole " .. index .. " is " .. size.X .. " px on a board of " .. tostring(board.AbsoluteSize) .. " in a window of " .. tostring(window.AbsoluteSize) .. " (#3296)")
				-- clear of the hearts and score strip (Derek: the corner symbol was too close to the spawn)
				local hx, hy = hud.AbsolutePosition.X, hud.AbsolutePosition.Y
				local clearX = at.X >= hx + hud.AbsoluteSize.X + 15 or at.X + size.X <= hx - 15
				local clearY = at.Y >= hy + hud.AbsoluteSize.Y + 15 or at.Y + size.Y <= hy - 15
				assert(clearX or clearY, "uigate: hole " .. index .. " is under the hearts and score strip (#3296)")
				local bx, by = banner.AbsolutePosition.X, banner.AbsolutePosition.Y
				local offX = at.X >= bx + banner.AbsoluteSize.X + 10 or at.X + size.X <= bx - 10
				local offY = at.Y >= by + banner.AbsoluteSize.Y + 10 or at.Y + size.Y <= by - 10
				assert(offX or offY, "uigate: hole " .. index .. " is under the next prize banner (#3553)")
				-- each animal's frame is centred on its hole, left to right (Derek: "look off centred")
				local animal = hole:FindFirstChild("Animal", true)
				local middle = animal.AbsolutePosition.X + animal.AbsoluteSize.X / 2
				assert(math.abs(middle - (at.X + size.X / 2)) <= 1, "uigate: hole " .. index .. "'s animal is off centre (#3296)")
			end
			for a = 1, 9 do
				for b = a + 1, 9 do
					local pa, pb, size = holes[a].AbsolutePosition, holes[b].AbsolutePosition, holes[a].AbsoluteSize
					assert(math.abs(pa.X - pb.X) >= size.X or math.abs(pa.Y - pb.Y) >= size.Y, "uigate: holes " .. a .. " and " .. b .. " overlap (#3296)")
				end
			end
			assert(holes[2]:FindFirstChild("Animal", true).Visible, "uigate: the mouse in hole 2 is not up (#3296)")
			assert(holes[6]:FindFirstChild("Zzz", true).Visible, "uigate: the kitten in hole 6 has no Zzz (#3296)")
			assert(not holes[1]:FindFirstChild("Animal", true).Visible, "uigate: an empty hole shows an animal (#3296)")
			local sent = nil
			local connection = UI.events.mouseDashTap:Connect(function(run, index, hole)
				sent = run .. ":" .. index .. ":" .. hole
			end)
			UIShim.fire(UIShim.eventOf(holes[2], "MouseButton1Down")) -- a hole takes the press, not the release
			connection:Disconnect()
			assert(sent == "7:1:2", "uigate: a tap on hole 2 sent " .. tostring(sent) .. " (#3296)")
			UI.mouseDash.judged(7, 1, { outcome = "catch", hole = 2, kind = "mouse", gain = 1, heart = 0 }, 24, 2, 5, {}, 0)
			local caught = holes[2]:FindFirstChild("Animal", true):FindFirstChild("Art")
			assert(caught.ImageRectOffset.X == 256 and caught.ImageRectOffset.Y == 0, "uigate: a caught mouse does not show its bopped picture (#3296)")
			-- a risen animal stays inside its own button, so a tap on its ears is a tap on its hole
			for index = 1, 9 do
				local art = holes[index]:FindFirstChild("Art")
				local clip = art:FindFirstChild("Clip")
				local top = clip.AbsolutePosition.Y + clip.AbsoluteSize.Y - 0.83 * art.AbsoluteSize.X
				assert(top >= holes[index].AbsolutePosition.Y - 1, "uigate: hole " .. index .. "'s animal rises above its button (#3296)")
				local floor = board:FindFirstChild("Backdrop")
				assert(floor.AbsoluteSize.X >= holes[9].AbsolutePosition.X + holes[9].AbsoluteSize.X - holes[1].AbsolutePosition.X, "uigate: the cellar floor is smaller than the holes (#3296)")
			end
			assert(board:FindFirstChild("Score", true).Text == "24", "uigate: the score did not move on a catch (#3296)")
		end,
	},
	-- #3765 (Derek: the banners "pop up on top of the game and should be moved higher up so we can see"): Ready,
	-- Faster!, the kitten hint and Prize: sit in the window's header, above every hole and clear of the close button
	{
		"MouseDashBanner",
		function()
			local window = mouseDashCard(false)
			local nowAt = workspace:GetServerTimeNow()
			UI.mouseDash.began(9, 3, nowAt, nowAt + 92)
			local banner = window:FindFirstChild("Banner", true)
			assert(banner ~= nil and banner.Visible, "uigate: a new game shows no Ready banner (#3765)")
			assert(banner.Text == "Ready?", "uigate: the banner reads " .. banner.Text .. " (#3765)")
			banner.Text = "Let sleeping kittens nap!" -- the longest line it takes
			local bottom = banner.AbsolutePosition.Y + banner.AbsoluteSize.Y
			local grid = window:FindFirstChild("Board", true):FindFirstChild("Grid", true)
			assert(bottom <= grid.AbsolutePosition.Y, ("uigate: the banner ends at %d, over the holes from %d (#3765)"):format(bottom, grid.AbsolutePosition.Y))
			local hud = window:FindFirstChild("Hud", true)
			assert(bottom <= hud.AbsolutePosition.Y, "uigate: the banner covers the hearts and score (#3765)")
			local close = window:FindFirstChild("Close", true)
			if close ~= nil then
				assert(banner.AbsolutePosition.X + banner.AbsoluteSize.X <= close.AbsolutePosition.X, "uigate: the banner runs under the close button (#3765)")
			end
			assert(banner.AbsoluteSize.X >= 150 and banner.AbsoluteSize.Y >= 20, ("uigate: the banner is %d by %d (#3765)"):format(banner.AbsoluteSize.X, banner.AbsoluteSize.Y))
			-- for the picture: Ready's own clock has put it away by the time the scene is drawn
			UIShim.advance(1)
			banner.Visible = true
		end,
	},
	-- #3296: the end of a game: the card again with the game's line, and the arcade's prizes ticked
	{
		"MouseDashOver",
		function()
			local window = mouseDashCard(false)
			UI.mouseDash.began(8, 3, workspace:GetServerTimeNow())
			UI.mouseDash.over(8, { points = 42, seconds = 51, reason = "quit", win = false, best = 42, bestSeconds = 51, newBest = true, paid = { 30, 40 }, today = { 10, 20, 30, 40 }, legend = false, mouser = true })
			task.wait(0.1)
			local last = window:FindFirstChild("LastGame", true)
			assert(last.Visible and last.Text == "Score 42 · New best!", "uigate: the last game's line reads " .. last.Text .. " (#3296)")
			assert(window:FindFirstChild("Card", true).Visible, "uigate: the card did not come back after a game (#3296)")
		end,
	},
	-- #3296: closing the window mid game puts the board away at once, before the server answers (Review-QA on
	-- #3405: a late or lost MouseDashOver must not leave the board's keys bound), and the answer still fills the card
	{
		"MouseDashClose",
		function()
			local window = mouseDashCard(false)
			UI.mouseDash.began(9, 3, workspace:GetServerTimeNow())
			assert(UI.mouseDash.playing(), "uigate: no Mouse Dash game after it began (#3296)")
			local quit = nil
			local connection = UI.events.mouseDashQuit:Connect(function(run)
				quit = run
			end)
			UI.close()
			connection:Disconnect()
			assert(quit == 9, "uigate: closing Mouse Dash mid game asked to quit run " .. tostring(quit) .. " (#3296)")
			assert(not UI.mouseDash.playing(), "uigate: Mouse Dash still counts as playing with its window shut (#3296)")
			assert(not window:FindFirstChild("Board", true).Visible, "uigate: the board is still up after the window closed (#3296)")
			UI.mouseDash.over(9, { points = 12, seconds = 20, reason = "quit", win = false, best = 37, bestSeconds = 44, newBest = false, paid = { 10 }, today = { 10 }, legend = false, mouser = false })
			UI.mouseDash.open()
			local last = window:FindFirstChild("LastGame", true)
			assert(last.Visible and string.find(last.Text, "12", 1, true) ~= nil, "uigate: the closed game's line reads " .. last.Text .. " (#3296)")
		end,
	},
	-- #3062: the Cat Arcade's card (records, today's prizes, Play, the idea credit), a game on the board, and the card
	-- after a game
	{
		"ArcadeCard",
		function()
			UI.update({ goldenFish = 12 } :: any)
			UI.arcade.state({
				loaded = true,
				best = 37,
				bestCircles = 30,
				today = { 10, 20 },
				legend = false,
				serverBest = 61,
				serverCircles = 45,
				serverName = "Sam",
			})
			UI.arcade.open()
			local window = UIShim.playerGui:FindFirstChild("Arcade", true)
			assert(
				window and window:FindFirstChild("IdeaBy", true),
				"uigate: no idea credit on the arcade card (#3062)"
			)
			assert(
				window:FindFirstChild("Prize100", true),
				"uigate: no milestone list on the arcade card (#3062)"
			)
		end,
	},
	-- #3296: the first game of the day is free, so Play reads "Play (free)" and is on with no golden fish
	{
		"ArcadeFree",
		function()
			UI.update({ goldenFish = 0 } :: any)
			UI.arcade.state({
				loaded = true,
				best = 12,
				bestCircles = 10,
				today = {},
				legend = false,
				serverBest = 0,
				serverCircles = 0,
				free = true,
			})
			UI.arcade.open()
			local window = UIShim.playerGui:FindFirstChild("Arcade", true)
			assert(window, "uigate: the arcade window didn't open (#3296)")
			local found = false
			for _, item in window:GetDescendants() do
				if (item:IsA("TextLabel") or item:IsA("TextButton")) and (item :: any).Text == "FREE" then
					found = true
				end
			end
			assert(found, "uigate: Play's pill doesn't say FREE for the day's free game (#3296)")
		end,
	},
	-- #3338: the Leaderboard tab, ten names (a long one), the viewer's line marked
	{
		"ArcadeLeaderboard",
		function()
			UI.update({ goldenFish = 12 } :: any)
			local top = {}
			for rank = 1, 10 do
				table.insert(top, {
					rank = rank,
					name = if rank == 2 then "AVeryLongDisplayName_Here" else "Player" .. rank,
					points = if rank == 1 then 100 else 100 - rank * 7,
					circles = 50 + rank,
					me = if rank == 4 then true else nil,
				})
			end
			UI.arcade.state({
				loaded = true,
				best = 72,
				bestCircles = 54,
				today = { 10, 20 },
				legend = false,
				serverBest = 72,
				serverCircles = 54,
				serverName = "Sam",
				top = top,
			} :: any)
			UI.arcade.open()
			press("Arcade", "LeaderboardTab")
			local window = UIShim.playerGui:FindFirstChild("Arcade", true)
			local board = window and window:FindFirstChild("Leaderboard", true)
			assert(board and board.Visible, "uigate: the arcade's Leaderboard tab does not show (#3338)")
			local line = board:FindFirstChild("Line4", true)
			assert(line and line.Visible, "uigate: the arcade leaderboard has no 4th line (#3338)")
			local name = line:FindFirstChild("Name")
			assert(
				name and string.find(name.Text, "(you)", 1, true),
				"uigate: the viewer's line is not marked (#3338)"
			)
		end,
	},
	{
		"ArcadeBoard",
		function()
			UI.update({ goldenFish = 12 } :: any)
			UI.arcade.state({
				loaded = true,
				best = 0,
				bestCircles = 0,
				today = {},
				legend = false,
				serverBest = 0,
				serverCircles = 0,
			})
			UI.arcade.open()
			local at = workspace:GetServerTimeNow()
			local circles = {}
			for i = 1, 10 do
				table.insert(circles, {
					startsAt = at - 0.2 + (i - 1) * 1.9,
					shrinkSeconds = 1.2,
					x = 0.25 + (i % 3) * 0.25,
					y = 0.3 + (i % 2) * 0.4,
					kind = "single",
				})
			end
			UI.arcade.block(1, 1, circles, { perfect = 0.06, good = 0.15 }, 0)
			UI.arcade.judged(1, 1, 1, "perfect", 12, { 10 })
		end,
	},
	{
		"ArcadeOver",
		function()
			UI.update({ goldenFish = 12 } :: any)
			UI.arcade.state({
				loaded = true,
				best = 52,
				bestCircles = 40,
				today = { 10, 20, 30, 40, 50 },
				legend = true,
				serverBest = 100,
				serverCircles = 58,
				serverName = "Sam",
			})
			UI.arcade.open()
			local at = workspace:GetServerTimeNow()
			UI.arcade.block(
				2,
				1,
				{ { startsAt = at + 1, shrinkSeconds = 1.2, x = 0.5, y = 0.5, kind = "single" } },
				{ perfect = 0.06, good = 0.15 },
				0
			)
			UI.arcade.over(2, {
				points = 52,
				circles = 40,
				win = false,
				best = 52,
				bestCircles = 40,
				newBest = true,
				serverBest = 100,
				serverCircles = 58,
				serverName = "Sam",
				paid = { 50 },
				today = { 10, 20, 30, 40, 50 },
				legend = true,
			})
			task.wait(1.4)
		end,
	},
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
		-- #3131 (Derek2: "highlight/make bigger the check game description for codes"): a filled strip with words
		-- bigger than body text, all on one line, clear of the box above and the answer card below
		local Theme = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Theme")
		assert(hint.BackgroundTransparency == 0 and hint.TextSize > Theme.sizes.textBody, "uigate: the codes hint is not highlighted and bigger (#3131)")
		assert(hint.TextFits, "uigate: the codes hint does not fit on one line (#3131)")
		local row = store:FindFirstChild("Redeem", true) :: GuiObject
		assert(row and hint.AbsolutePosition.Y >= row.AbsolutePosition.Y + row.AbsoluteSize.Y, "uigate: the codes hint lies on the code box (#3131)")
		local result = store:FindFirstChild("Result", true) :: GuiObject
		assert(result and result.AbsolutePosition.Y >= hint.AbsolutePosition.Y + hint.AbsoluteSize.Y, "uigate: the codes hint lies on the answer card (#3131)")
	end },
	-- #3686: a code redeemed while the Codes page stays open joins the used list at once, inside the page
	{ "CodesUsedFills", function()
		UI.update({ codesRedeemed = {} } :: any)
		UI.codes.open()
		press("Store", "codes")
		local store = UIShim.playerGui:FindFirstChild("Store", true)
		local used = store and store:FindFirstChild("Used", true) :: GuiObject?
		assert(used and used:FindFirstChild("playtest") == nil, "uigate: a used code before any was redeemed (#3686)")
		UI.codes.result(true, "Code redeemed!", CODE_PRIZE)
		UI.update({ codesRedeemed = { playtest = 1793900000 } } :: any)
		task.wait()
		local row = used:FindFirstChild("playtest") :: GuiObject?
		assert(row, "uigate: the used list did not fill while the page was open (#3686)")
		local page = used:FindFirstAncestorWhichIsA("ScrollingFrame") :: ScrollingFrame?
		if page then
			local bottom = row.AbsolutePosition.Y + row.AbsoluteSize.Y
			local reach = page.AbsolutePosition.Y + page.AbsoluteCanvasSize.Y
			assert(bottom <= reach + 1, "uigate: the new used code lies past the page's scroll end (#3686)")
		end
		local empty = used:FindFirstChild("Empty") :: GuiObject?
		assert(empty and not empty.Visible, "uigate: the used list still says nothing was used (#3686)")
	end },
	-- #1714: a refusal is one calm line in place; nothing used yet says so
	{ "CodesRefused", function()
		UI.codes.open()
		press("Store", "codes")
		-- #3686: the refused code stays on show, and tapping back into the box clears it for the next one
		local store = UIShim.playerGui:FindFirstChild("Store", true)
		local box = store and store:FindFirstChildWhichIsA("TextBox", true)
		assert(box, "uigate: no code box in the Store's Codes page")
		box.Text = "WRONGCODE"
		UI.codes.result(false, "That code doesn't exist", nil)
		assert(box.Text == "WRONGCODE", "uigate: a refused code left the box before the player came back to it (#3686)")
		UIShim.fire(UIShim.eventOf(box, "Focused")) -- the player taps back into the box
		task.wait()
		assert(box.Text == "", "uigate: a refused code stays in the box when the player taps it again (#3686)")
		box.Text = "WRONGCODE"
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
	-- #3470: no Secret page for a player who has found none; with one found the page comes last with only that cat,
	-- "1 found" and no total, no Rewards button, and the two not found have no tile
	{ "IndexSecret", function()
		UI.open("Collection")
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local window = modals and modals:FindFirstChild("Collection", true)
		local page = window and window:FindFirstChild("secret", true)
		assert(page, "uigate: the Secret page was never built (#3470)")
		assert(not page.Visible, "uigate: the Secret page shows before any Secret cat is found (#3470) " .. page:GetFullName())
		local collection = table.clone(samplePlayer(os.time()).collection)
		collection.nebula = 1
		UI.update({ collection = collection })
		UI.openIndex("secret")
		assert(page.Visible, "uigate: no Secret page once a Secret cat is found (#3470)")
		local header = page:FindFirstChild("Header")
		assert(header.Count.Text == "1 found", "uigate: the Secret page reads " .. tostring(header.Count.Text) .. " (#3470)")
		assert(not header.Rewards.Visible, "uigate: the Secret page has a Rewards button (#3470)")
		local cats = page:FindFirstChild("Cats")
		assert(cats.nebula.Visible, "uigate: the found Secret cat has no tile (#3470)")
		assert(not cats.glitch.Visible and not cats.cafe_ghost.Visible, "uigate: a Secret cat not found has a tile (#3470)")
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
	-- #3924 (Derek 2026-11-13: "just one row of things an equip/unequip button (no move), remove sell ... make the lock a
	-- small square ... feed opens the menu attached ... rename just when you click on their name"): Equip, Feed and the
	-- Lock square on one row, no Sell or Move, the food row shut until Feed, a tap on the name opens Rename
	{ "CatsOneRow", function()
		local player = samplePlayer(os.time())
		player.cats.gate_rainbow = rainbowCat()
		UI.update({ cats = player.cats })
		UI.open("Cats")
		task.delay(0.2, function()
			press("Cats", "gate_rainbow")
			task.wait(0.1)
			local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
			local rootFrame = modals and modals:FindFirstChild("Root")
			local container = rootFrame and rootFrame:FindFirstChild("Container")
			local cats = container and container:FindFirstChild("Cats")
			assert(cats, "uigate: no Cats window (#3924)")
			local actions = cats:FindFirstChild("Actions", true)
			assert(actions, "uigate: no Actions row (#3924)")
			for _, gone in { "Sell", "Rest", "Move" } do
				assert(cats:FindFirstChild(gone, true) == nil, "uigate: the cat room still has " .. gone .. " (#3924)")
			end
			local lock = actions:FindFirstChild("Lock", true)
			assert(lock and lock.Visible, "uigate: no Lock square on the row (#3924)")
			local size = lock.AbsoluteSize
			assert(math.abs(size.X - size.Y) <= 2, "uigate: the Lock is not square: " .. tostring(size) .. " (#3924)")
			local top = actions.AbsolutePosition.Y
			local edge = actions.AbsolutePosition.X + actions.AbsoluteSize.X + 1
			for _, name in { "Assign", "Feed", "Lock" } do
				local piece = actions:FindFirstChild(name, true)
				assert(piece, "uigate: no " .. name .. " on the row (#3924)")
				assert(math.abs(piece.AbsolutePosition.Y - top) <= 2, "uigate: " .. name .. " is off the row (#3924)")
				assert(piece.AbsolutePosition.X + piece.AbsoluteSize.X <= edge, "uigate: " .. name .. " spills off the row (#3924)")
			end
			local feedRow = cats:FindFirstChild("FeedRow", true)
			assert(feedRow and not feedRow.Visible, "uigate: the food row shows before Feed (#3924)")
			press("Cats", "Feed")
			task.wait(0.1)
			assert(feedRow.Visible, "uigate: Feed did not open the food row (#3924)")
			press("Cats", "NameTap")
			task.wait(0.1)
			local rename = modals:FindFirstChild("Rename", true)
			assert(rename and rename.Visible, "uigate: a tap on the name did not open Rename (#3924)")
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
	-- #3931 (Derek 2026-11-13: "the decor menu side gets cut off for the new areas in index"): with every area the
	-- page tabs wrap into rows, each tab whole inside the tab row, none past the window's right edge
	{ "IndexDecorTabsFit", function()
		UI.setCatalog(catalogLikeTheGame())
		UI.open("Collection")
		press("Collection", "DecorTab")
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local window = modals and modals:FindFirstChild("Collection", true) :: Instance
		local decor = window:FindFirstChild("DecorIndex", true) :: Instance
		local bar = decor:FindFirstChild("Pages") :: GuiObject
		assert(bar, "uigate: no Decor Index tab row (#3931)")
		local x0, x1 = bar.AbsolutePosition.X, bar.AbsolutePosition.X + bar.AbsoluteSize.X
		local y0, y1 = bar.AbsolutePosition.Y, bar.AbsolutePosition.Y + bar.AbsoluteSize.Y
		local tabs = 0
		for _, tab in bar:GetChildren() do
			if tab:IsA("TextButton") then
				tabs += 1
				local p, z = tab.AbsolutePosition, tab.AbsoluteSize
				assert(p.X >= x0 - 1 and p.X + z.X <= x1 + 1 and p.Y >= y0 - 1 and p.Y + z.Y <= y1 + 1, "uigate: the " .. tab.Name .. " tab is cut off (#3931)")
				local name = tab:FindFirstChild("Name") :: TextLabel
				assert(name and name.TextFits, "uigate: the " .. tab.Name .. " tab's name does not fit (#3931)")
			end
		end
		assert(tabs >= 9, "uigate: only " .. tabs .. " Decor Index tabs (#3931)")
		local progress = decor:FindFirstChild("Progress") :: GuiObject
		assert(progress.AbsolutePosition.Y >= y1 - 1, "uigate: the completion line sits under the tabs (#3931)")
	end },
	-- #3722: the Decor Index builds no cells at start-up; a page's cells are made the first time it shows
	{ "DecorIndexLazy", function()
		UI.setCatalog(catalogLikeTheGame())
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local window = modals and modals:FindFirstChild("Collection", true) :: Instance?
		local cells = window and window:FindFirstChild("Cells", true) :: Instance?
		assert(cells, "uigate: no Decor Index cells frame (#3722)")
		local function count(): number
			local n = 0
			for _, cell in (cells :: Instance):GetChildren() do
				if cell:IsA("Frame") then
					n += 1
				end
			end
			return n
		end
		assert(count() == 0, ("uigate: setCatalog built %d Decor Index cells (#3722)"):format(count()))
		UI.open("Collection")
		press("Collection", "DecorTab")
		local first = count()
		assert(first > 0, "uigate: the Decor Index's first page has no cells (#3722)")
		-- another page than the one open builds its own cells the first time it shows
		local chipBar = (window :: Instance):FindFirstChild("rally", true)
		local other: string? = nil
		if chipBar ~= nil and chipBar.Parent ~= nil then
			for _, chip in chipBar.Parent:GetChildren() do
				if chip:IsA("TextButton") and chip.Name ~= "rally" then
					other = chip.Name
					break
				end
			end
		end
		assert(other, "uigate: the Decor Index has one page only (#3722)")
		local otherChip = (chipBar :: Instance).Parent:FindFirstChild(other :: string) :: GuiButton
		UIShim.fire(UIShim.eventOf(otherChip, "Activated"))
		local after = count()
		UIShim.fire(UIShim.eventOf((chipBar :: Instance) :: GuiButton, "Activated"))
		assert(after > first or count() > first, ("uigate: a second page built no cells of its own (%d, %d, %d, #3722)"):format(first, after, count()))
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
		-- #3064: the row's small cards are built when it first opens, not with the window
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local window = modals and modals:FindFirstChild("Collection", true)
		local section = window and window:FindFirstChild("rainbow", true)
		local row = section and section:FindFirstChild("All", true)
		assert(row, "uigate: the rainbow strip has no All row")
		local function cards(): number
			local count = 0
			for _, child in row:GetChildren() do
				if child:IsA("GuiObject") then
					count += 1
				end
			end
			return count
		end
		assert(cards() == 0, "uigate: the shut milestone row already holds " .. cards() .. " cards (#3064)")
		press("Collection", "rainbow.Expand")
		assert(cards() > 0, "uigate: Expand milestones built no cards (#3064)")
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
		UI.toast(short, "info") -- (#3080: a green toast off the keep list no longer shows)
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
		-- #3205 (Derek2: "the quick update in ... gets cut off"): the restart warning's calm early mark is an info
		-- toast, and still shows every word
		local notice = "A quick update is coming in 10 minutes, then a 30-minute event! Keep playing, your cafe is saved."
		UI.toast(notice, "info")
		local warned = find(notice)
		assert(warned.TextTruncate == Enum.TextTruncate.None, "uigate: the restart warning ends in ... (#3205)")
		assert(warned.TextFits, "uigate: the restart warning's words do not all fit (#3205)")
		local warnedPill = warned.Parent :: Frame
		local view = workspace.CurrentCamera.ViewportSize
		assert(
			warnedPill.AbsolutePosition.X >= -0.5 and warnedPill.AbsolutePosition.X + warnedPill.AbsoluteSize.X <= view.X + 0.5,
			"uigate: the restart warning's pill runs off screen (#3205)"
		)
	end },
	-- #2729 (Derek2: "big claims of index and quests cap at one line and put …"; "remove all the extra ones"): a long
	-- Index claim is one row ending in "…", no reward chips under it; a cut nudge never shows; a long warning wraps
	{ "ToastOneLine", function()
		-- #3080: a claim shows no toast at all; the green line that still shows (a Robux receipt) keeps the one row
		local gone = "3 Index rewards: $5,000, 2 Golden fish, Rare Crate, Luck Potion, Tuna x3, Cat Treat x2, Sardines x4"
		local claim = "Thank you! $5,000, 2 Golden fish, Rare Crate, Luck Potion, Tuna x3, Cat Treat x2, Sardines x4, Gold Rush Potion"
		local warning = "That cat is locked. Unlock it from its card in the Cats window first, then try selling it again."
		UI.toast("A cheap Rare Crate at the Fish Market!", "info")
		UI.toast(gone, "good")
		UI.toast(claim, "good")
		UI.toast(warning, "warn")
		local function find(text: string): TextLabel?
			for _, label in UIShim.playerGui:GetDescendants() do
				if label:IsA("TextLabel") and label.Name == "Text" and label.Text == text then
					return label
				end
			end
			return nil
		end
		UIShim.advance(0.6)
		assert(find("A cheap Rare Crate at the Fish Market!") == nil, "uigate: a cut nudge still shows (#2729)")
		assert(find(gone) == nil, "uigate: a claim still shows a green toast (#3080, #3054)")
		local line = find(claim)
		assert(line, "uigate: no receipt toast (#2729, #3080 keeps it)")
		local pill = (line :: TextLabel).Parent :: Frame
		assert(pill:FindFirstChild("Rewards") == nil, "uigate: the claim still lists its rewards as chips (#2729)")
		assert(not (line :: TextLabel).TextWrapped, "uigate: the claim wrapped onto more rows (#2729)")
		assert((line :: TextLabel).TextTruncate == Enum.TextTruncate.AtEnd, "uigate: the long claim does not end in … (#2729)")
		local scale = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Scale").get()
		assert(pill.AbsoluteSize.Y <= 44 * scale + 1, ("uigate: the claim's pill is %d px tall, more than one row (#2729)"):format(pill.AbsoluteSize.Y))
		local root = (pill:FindFirstAncestorOfClass("ScreenGui") :: ScreenGui)
		local at, size = pill.AbsolutePosition, pill.AbsoluteSize
		local view = workspace.CurrentCamera.ViewportSize
		assert(at.X >= -0.5 and at.X + size.X <= view.X + 0.5, "uigate: the claim's pill runs off screen (#2729) in " .. root.Name)
		local warn = find(warning)
		if warn then -- (a short phone may still be holding it in the queue)
			UIShim.advance(0.3)
			assert(warn.TextWrapped, "uigate: the long warning did not wrap (#2729 keeps #2207 for warnings)")
		end
	end },
	-- #2338 (Laptop-Tester, iPhone SE: the Welcome back toast lay over the Index, Quests and Potions tiles): the pill
	-- keeps clear of the menu's tiles, the goal card, the corner tiles and the bottom row, and on screen; a wide screen
	-- keeps it centred
	{ "ToastClear", function()
		local line = "Welcome back! +$12,345 while you were away"
		UI.toast(line, "info") -- (#3080: green toasts off the keep list no longer show; the place is what is measured)
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
		UI.toast("Same words", "info")
		UIShim.advance(3)
		UI.toast("Same words", "info")
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
	-- #2479 (Derek2: Claim all's rewards "make it look so cluttered"), since #2729 (Derek2: "big claims of index and
	-- quests cap at one line and put …"): a many-reward claim is one row ending in "…", no chips, inside the screen
	{ "ToastClaimAll", function()
		-- (#3080: an Index claim shows no toast now; a Robux receipt is the long green line left)
		local claim = "Thank you! +$11.3M, +25 golden fish, 1 Alley Crate, +5% gold luck forever, 1 spin, +2% faster bait forever"
		UI.toast(claim, "good")
		task.wait(0.4)
		local found: Frame? = nil
		for _, piece in UIShim.playerGui:GetDescendants() do
			if piece.Name == "Toast" and piece:FindFirstChild("Text") and (piece :: any).Text.Text == claim then
				found = piece :: Frame
			end
		end
		assert(found, "uigate: no Claim all toast (#2729)")
		local toast = found :: Frame
		assert(toast:FindFirstChild("Rewards") == nil, "uigate: the Claim all toast still lists chips (#2729)")
		local line = toast:FindFirstChild("Text") :: TextLabel
		assert(not line.TextWrapped and line.TextTruncate == Enum.TextTruncate.AtEnd, "uigate: the Claim all toast is not one row ending in … (#2729)")
		local view = workspace.CurrentCamera.ViewportSize
		local left, right = toast.AbsolutePosition.X, toast.AbsolutePosition.X + toast.AbsoluteSize.X
		assert(left >= -0.5 and right <= view.X + 0.5, "uigate: the Claim all toast runs off the screen (#2729)")
	end },
	-- F99 section 2: a rainbow stray's once-a-minute toast on a turning rainbow edge
	{ "RainbowSpawn", function()
		UI.rainbowSpawned(firstArea(), Catalog.cats[10].id)
	end },
	{ "Potions", function()
		UI.open("Potions")
		-- #2588: the Bag window's corner badge is the HUD Bag tile's backpack, not a potion
		assert(badgeDraws("Potions", "118552497512285"), "uigate: the Bag window's badge is not the backpack (#2588)")
	end },
	-- #1281: the Bag's Bait tab: the bowl foods the player has, each with its picture, grade badge and count, no Use
	-- #3190 (Derek2: "... delays on using potions too fast"): two quick Use presses both count at once, the button never
	-- reads "...", and the bag's count drops before the server answers
	{ "PotionsFastUse", function()
		UI.update({ potions = { tip_potion = 3 }, buffs = {} })
		UI.open("Potions")
		UIShim.advance(0.2)
		local window = UIShim.playerGui:FindFirstChild("Potions", true) :: GuiObject
		local function texts(): string
			local all = {}
			for _, piece in window:GetDescendants() do
				if piece:IsA("TextLabel") or piece:IsA("TextButton") then
					table.insert(all, (piece :: any).Text)
				end
			end
			return table.concat(all, "|")
		end
		press("Potions", "Use")
		press("Potions", "Use")
		UIShim.advance(0.1)
		local now = texts()
		assert(not now:find("|%.%.%.|") and not now:find("^%.%.%.|"), "uigate: Use reads ... after a fast press (#3190)")
		assert(now:find("x1", 1, true), "uigate: two fast Uses did not count at once, the bag shows " .. now)
	end },
	-- #3326 (Derek2: "add a use all potions in inventory button right below potions button in bag"): the button heads
	-- the Potions list while a potion would take, and a press asks first on a card naming what it drinks
	{ "PotionsUseAll", function()
		-- PotionsFastUse runs just before this scene and leaves a Use press waiting for the server (#3190), which would
		-- count against this bag. An empty bag is the server answering it; then the scene's own bag goes in
		UI.update({ potions = {}, buffs = {} })
		UI.update({ potions = { tip_potion = 3, swift_potion = 2 }, buffs = {} })
		UI.open("Potions")
		UIShim.advance(0.2)
		local window = UIShim.playerGui:FindFirstChild("Potions", true) :: GuiObject
		local row = window:FindFirstChild("UseAllRow", true) :: GuiObject
		assert(row and row.Visible, "uigate: no Use all potions button on the Potions tab (#3326)")
		press("Potions", "UseAllPotions")
		local ask = window:FindFirstChild("UseAllConfirm", true) :: GuiObject
		assert(ask and ask.Visible, "uigate: Use all potions did not ask first (#3326)")
		local line = (ask:FindFirstChild("Line", true) :: TextLabel).Text
		assert(line == "Money x3, Swift x2", "uigate: the confirm card reads " .. line)
	end },
	{ "PotionsUseAllHidden", function()
		UI.update({ potions = { tip_potion = 3 }, buffs = {} })
		UI.open("Potions")
		press("Potions", "BaitTab")
		local window = UIShim.playerGui:FindFirstChild("Potions", true) :: GuiObject
		local row = window:FindFirstChild("UseAllRow", true) :: GuiObject
		assert(not row:FindFirstAncestorWhichIsA("ScrollingFrame").Visible, "uigate: Use all potions shows off the Potions tab")
	end },
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
				if string.find(d.Image, "72888217681662", 1, true) then
					crates += 1
				end
			end
		end
		assert(crates > 0, "uigate: no achievement shows the Classic Crate's picture (#2089)")
		-- #3694: Devoted counts hours ("16/50 hours"), not seconds, and the words fit their box
		local hours: TextLabel? = nil
		for _, d in UIShim.playerGui:GetDescendants() do
			if d:IsA("TextLabel") and string.match(d.Text, "^%d+/50 hours$") then
				hours = d
			end
		end
		assert(hours, "uigate: Devoted does not count in hours (#3694)")
		assert((hours :: TextLabel).TextFits, "uigate: Devoted's hours do not fit (#3694)")
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
	-- #3024: on a touch screen Give up takes two taps: the first only asks, for 3 seconds, and the attempt goes on; a
	-- second tap gives up. A mouse click gives up at once. The Rummage Bin shares the bar, so it does the same.
	{ "RescueGiveUpTwice", function()
		local touch = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Scale").isTouch()
		for _, spot in { "gate_rescue", "bin_alley" } do
			UI.rescue.show(spot, if spot == "bin_alley" then binChallenge() else rescueChallenge())
			local barGui = UIShim.playerGui:FindFirstChild("CatCafeRescueBar")
			local giveUp = barGui and barGui:FindFirstChild("GiveUp", true)
			assert(giveUp, "uigate: the bar has no Give up (#3024)")
			local label = giveUp:FindFirstChild("Label", true) :: TextLabel
			assert(label and string.sub(label.Text, 1, 7) == "Give up", "uigate: Give up reads " .. tostring(label and label.Text) .. " (#3024)")
			if touch then
				press("CatCafeRescueBar", "GiveUp")
				assert(label.Text == "Tap again to give up", "uigate: the first tap on Give up reads " .. label.Text .. " (#3024)")
				assert(label.TextFits, "uigate: Tap again to give up does not fit its button (#3024)")
				UIShim.advance(1)
				assert(UI.rescue.isActive(), "uigate: one tap on Give up ended the attempt on touch (#3024)")
				-- left alone, it goes back to Give up and the attempt is still on
				UIShim.advance(3)
				assert(string.sub(label.Text, 1, 7) == "Give up", "uigate: Give up still asks after 3 seconds (#3024)")
				assert(UI.rescue.isActive(), "uigate: the ask running out ended the attempt (#3024)")
				press("CatCafeRescueBar", "GiveUp")
				assert(label.Text == "Tap again to give up", "uigate: Give up does not ask again (#3024)")
				-- #3556: a second tap straight away is the same burst of taps and only keeps asking
				press("CatCafeRescueBar", "GiveUp")
				assert(label.Text == "Tap again to give up", "uigate: a fast second tap changed Give up to " .. label.Text .. " (#3556)")
				assert(UI.rescue.isActive(), "uigate: a fast second tap on Give up ended the attempt (#3556)")
				-- #3556: on touch Give up sits in the top right corner, away from the bar
				assert(giveUp:FindFirstAncestor("GiveUpCorner") ~= nil, "uigate: Give up is not in its corner on touch (#3556)")
				UIShim.advance(0.5)
			else
				assert(giveUp:FindFirstAncestor("BarGroup") ~= nil, "uigate: Give up left the bar on a mouse screen (#3556)")
			end
			press("CatCafeRescueBar", "GiveUp")
			UIShim.advance(1)
			assert(not UI.rescue.isActive(), "uigate: Give up did not end the attempt (#3024)")
		end
		-- the picture: the ask showing on touch, the plain button on a mouse screen
		UI.rescue.show("gate_rescue", rescueChallenge())
		if touch then
			press("CatCafeRescueBar", "GiveUp")
		end
	end },
	-- #3050: the Rummage Bin's bar is the rescue bar under the bin's spot id: its own name, no rarity chip, 2 pips
	{ "RummageBinBar", function()
		UI.rescue.show("bin_alley", binChallenge())
		local barGui = UIShim.playerGui:FindFirstChild("CatCafeRescueBar")
		assert(barGui and barGui.Enabled, "uigate: no bar for the Rummage Bin (#3050)")
		local name = barGui:FindFirstChild("CatName", true) :: TextLabel?
		assert(name and name.Text == "Rummage Bin", "uigate: the bin's bar is not named Rummage Bin (#3050)")
		local rarity = barGui:FindFirstChild("Rarity", true) :: TextLabel?
		assert(rarity and not rarity.Visible, "uigate: the bin's bar shows a rarity chip (#3050)")
		local pips = barGui:FindFirstChild("Pips", true)
		local count = 0
		for _, pip in pips:GetChildren() do
			if pip:IsA("Frame") then
				count += 1
			end
		end
		assert(count == 2, "uigate: the bin's bar has " .. count .. " pips, not 2 (#3050)")
		assert(UI.rescue.isActive(), "uigate: the bin's bar does not count as a rescue on screen (#3050)")
	end },
	-- #3885: a Rummage Bin win closes the bar at once, with no win banner (the prize pops out of the bin instead)
	{ "RummageBinWinCloses", function()
		UI.rescue.show("bin_alley", binChallenge())
		UI.rescue.update("bin_alley", 2, 3, true, true, nil, { id = "first_tuna", first = true, items = {
			{ kind = "lure", id = "tuna", count = 2 },
		} } :: any)
		local barGui = UIShim.playerGui:FindFirstChild("CatCafeRescueBar")
		assert(barGui and not barGui.Enabled, "uigate: the bin's bar stays up after a win (#3885)")
		assert(not UI.rescue.isActive(), "uigate: the bin's win still counts as a rescue on screen (#3885)")
	end },
	-- #3611: the roll board that hovers over the Rummage Bin, drawn on the screen at the size its billboard gives it
	-- (BOARD_SMALLEST on a phone): the list with its chances, the list mid roll with a row lit, and the two one
	-- prize states beside the empty bin's faded list
	{ "BinBoardList", function()
		binBoards({ { view = { uses = 3 } } })
	end },
	{ "BinBoardRoll", function()
		binBoards({ { view = { uses = 3, playing = "crate", rolling = true }, lit = 4 } })
	end },
	{ "BinBoardStates", function()
		binBoards({
			-- #3680: no fixed first prize; the prize the bar is played for stands in its place
			{ view = { uses = 0, playing = "crate", rolling = false, prize = "crate" } },
			{ view = { uses = 3, prize = "golden" } },
			{ view = { uses = 3, nextAt = 1245 } },
		})
	end },
	-- #3050: a win closes the bar on the prize's name (no toast, #3080): every prize's two lines fit the banner, the
	-- first Tuna points at the bowl, and the tap catcher goes so a phone can move again
	{ "RummageBinWin", function()
		-- #3885: a win closes the bar at once; the loot card names the prize and carries the banner's line
		local barGui = UIShim.playerGui:FindFirstChild("CatCafeRescueBar")
		local function win(id: string, first: boolean): TextLabel
			UI.rescue.show("bin_alley", binChallenge())
			local t = workspace:GetServerTimeNow()
			UI.rescue.update("bin_alley", 2, 3, true, true, {
				zone = 3,
				startsAt = t,
				phase = 0.4,
				speed = 0.5,
				zoneEndsAt = t + 5,
			}, { id = id, first = first, items = { { kind = "lure", id = "tuna", count = 2 } } } :: any)
			assert(not barGui.Enabled, "uigate: the bin's bar stays up after a win: " .. id .. " (#3885)")
			UIShim.advance(1)
			local card = UIShim.playerGui:FindFirstChild("CatCafeLoot"):FindFirstChild("Card", true)
			assert(card.Visible, "uigate: no loot card after a bin win: " .. id .. " (#3885)")
			local hint = card:FindFirstChild("Hint") :: TextLabel
			assert(not hint.Visible or hint.TextFits, "uigate: the loot card's hint does not fit: " .. hint.Text .. " (#3885)")
			return hint
		end
		for _, id in { "fish", "salmon", "potion", "crate", "golden" } do
			win(id, false)
			UIShim.advance(3)
		end
		-- #3460: the first Tuna still points at the bowl, now on the loot card
		local hint = win("first_tuna", true)
		assert(hint.Visible and hint.Text:find("Put it in your bowl", 1, true), "uigate: the first Tuna does not point at the bowl (#3050, #3885)")
		local tap = barGui:FindFirstChild("Tap")
		assert(tap and not tap.Visible, "uigate: the tap catcher still covers the screen after a bin win (#3050)")
		local toasts = UIShim.playerGui:FindFirstChild("CatCafeToasts")
		if toasts then
			for _, d in toasts:GetDescendants() do
				assert(not (d:IsA("TextLabel") and d.Visible and d.Text:find("Tuna", 1, true)), "uigate: a bin win shows a toast (#3080)")
			end
		end
	end },
	-- #3050: a miss costs nothing and the bar says so in its own words, not a stuck cat's
	{ "RummageBinMiss", function()
		UI.rescue.show("bin_alley", binChallenge())
		local t = workspace:GetServerTimeNow()
		UI.rescue.update("bin_alley", 0, 0, true, false, {
			zone = 1,
			startsAt = t,
			phase = 0.4,
			speed = 0.5,
			zoneEndsAt = t + 5,
		})
		local barGui = UIShim.playerGui:FindFirstChild("CatCafeRescueBar")
		local outcome = barGui:FindFirstChild("Outcome", true) :: TextLabel
		local detail = barGui:FindFirstChild("Detail", true) :: TextLabel
		assert(outcome.Text == "Try again!" and detail.Text == "", "uigate: a bin miss reads " .. outcome.Text .. " / " .. detail.Text .. " (#3050, #3885)")
		assert(outcome.TextFits and detail.TextFits, "uigate: the bin's miss words do not fit (#3050)")
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
	-- #3301 (Derek2: "a quick bubble with OWNER "whatever messege I put" on screen when i shout"): the longest shout
	-- (OwnerTest.SHOUT_MAX, 120 characters) in the bubble
	{ "OwnerShout", function()
		UI.ownerShout(
			"Double coins in every cafe for the next ten minutes, go catch some strays and say hi to everyone in town!!"
		)
		task.wait(0.8)
		local found = false
		for _, piece in UIShim.playerGui:GetDescendants() do
			if piece:IsA("TextLabel") and (piece :: TextLabel).Text == "OWNER" and (piece :: TextLabel).Visible then
				found = true
			end
		end
		assert(found, "uigate: the owner shout has no OWNER title (#3301)")
	end },
	{ "TeamRescue", function()
		UI.teamRescue(4242, localUserId(), 1240)
	end },
	-- F92: four pals on the server. Derek 2026-11-13 ("move that to just be in money breakdown area ... and don't put
	-- a line anywhere"): no pal chip on the HUD; the boosts card a tap on the money opens has the "Friend bonus" row
	{ "HUDPals", function()
		local t = workspace:GetServerTimeNow()
		UI.update({ buffs = { tip_potion = t + 492 } })
		UI.pals({ 4242, 4343, 4444, 4545 })
		UIShim.advance(0.1)
		local hud = UIShim.playerGui:FindFirstChild("CatCafeHUD") :: ScreenGui
		assert(hud:FindFirstChild("Pals", true) == nil, "uigate: the HUD still has a pal chip (2026-11-13)")
		for _, piece in hud:GetDescendants() do
			if piece:IsA("TextLabel") and (piece :: TextLabel).Visible then
				assert(not (piece :: TextLabel).Text:find("with pals", 1, true), "uigate: the HUD shows " .. (piece :: TextLabel).Text .. " (2026-11-13)")
			end
		end
		press("CatCafeHUD", "Counters.Money")
		local card = hud:FindFirstChild("Boosts", true) :: GuiObject
		assert(card and card.Visible, "uigate: the money did not open the boosts card (F92)")
		local found = false
		for _, piece in card:GetDescendants() do
			if piece:IsA("TextLabel") and (piece :: TextLabel).Text == "Friend bonus (4)" then
				found = true
			end
		end
		assert(found, "uigate: the boosts card has no Friend bonus (4) row (F92)")
		press("CatCafeHUD", "Counters.Money")
	end },
	-- #3052 (Derek2 11-10: "sometimes ui still gets pushed down when friends join"): on any device no piece of the HUD
	-- moves or changes size when pals join and leave, with the Luck chip up and a Lucky Day on, as in his screenshot
	{ "HUDPalsStay", function()
		local hud = UIShim.playerGui:FindFirstChild("CatCafeHUD") :: ScreenGui
		local root = hud:FindFirstChild("Root") :: Frame
		local before = UI.getState() :: any
		Scenes._stepState = { money = before.money, buffs = before.buffs }
		local t = workspace:GetServerTimeNow()
		UI.update({ money = 25.3e9, buffs = { lucky_potion = t + 300 } } :: any)
		local clock = Instance.new("Folder")
		clock.Name = "Clock"
		clock:SetAttribute("Phase", "day")
		clock:SetAttribute("PhaseEndsAt", workspace:GetServerTimeNow() + 190)
		clock:SetAttribute("AreasOpen", true)
		clock:SetAttribute("Day", 4)
		clock:SetAttribute("NextLuckyDay", 8)
		clock:SetAttribute("LuckyDay", true)
		UI.clock.bind(clock)
		Scenes._palsClock = true
		UI.pals({})
		UIShim.advance(0.2)
		local function shot(): { [string]: { Vector2 } }
			local out = {}
			for _, piece in root:GetDescendants() do
				-- (an open boosts card gains its Friend bonus row, which is where the bonus belongs)
				if piece:IsA("GuiObject") and piece.Visible and not piece:FindFirstAncestor("Boosts") then
					local path = piece:GetFullName()
					if out[path] == nil then
						out[path] = { piece.AbsolutePosition, piece.AbsoluteSize }
					end
				end
			end
			return out
		end
		local base = shot()
		for index, pals in { { 4242 }, { 4242, 4343 }, { 4242, 4343, 4444, 4545 }, { 4242 }, {} } do
			UI.pals(pals)
			UIShim.advance(0.2)
			local now = shot()
			for path, was in base do
				local is = now[path]
				if is ~= nil and not path:find("Clock", 1, true) then -- (the clock's words tick)
					local moved = (is[1] - was[1]).Magnitude
					local grew = (is[2] - was[2]).Magnitude
					assert(moved < 1 and grew < 1, ("uigate: with pals set %d, %s moved %d px and grew %d px (#3052)"):format(index, path, moved, grew))
				end
			end
			for path in now do
				assert(base[path] ~= nil or path:find("Clock", 1, true), ("uigate: with pals set %d, %s showed up (2026-11-13)"):format(index, path))
			end
		end
	end },
	-- #2712 (Derek2 11-09: "fix this reoccuring issue of currencys being shoved down on mobile"): the money keeps its
	-- place whatever chips join the row (pals, a potion timer, a long amount); the row, when it does not fit beside the
	-- money, goes under it, never moving the money
	{ "TopRowChips", function()
		local hud = UIShim.playerGui:FindFirstChild("CatCafeHUD")
		local root = hud:FindFirstChild("Root") :: Frame
		local counters = hud:FindFirstChild("Counters", true) :: Frame
		local function money(): Vector2
			UIShim.advance(0.1)
			return counters.AbsolutePosition - root.AbsolutePosition
		end
		local before = UI.getState() :: any
		Scenes._stepState = { money = before.money, buffs = before.buffs }
		UI.pals({})
		UI.update({ buffs = {} } :: any)
		local base = money()
		local t = workspace:GetServerTimeNow()
		local combos = {
			{ pals = { 4242 }, buffs = {} },
			{ pals = { 4242, 4343, 4444, 4545 }, buffs = {} },
			{ pals = { 4242 }, buffs = { tip_potion = t + 492 } },
			{ pals = { 4242, 4343 }, buffs = { tip_potion = t + 492, lucky_potion = t + 300, swift_potion = t + 200 } },
		}
		for index, combo in combos do
			UI.update({ buffs = combo.buffs } :: any)
			UI.pals(combo.pals)
			local now = money()
			assert(
				math.abs(now.Y - base.Y) < 1,
				("uigate: combo %d moved the money from y %d to %d (#2712)"):format(index, base.Y, now.Y)
			)
		end
		-- a longer amount may change what fits, but chips still never move it
		UI.pals({})
		UI.update({ money = 987654321098, buffs = {} } :: any)
		local alone = money()
		UI.update({ buffs = combos[4].buffs } :: any)
		UI.pals(combos[4].pals)
		local long = money()
		assert(math.abs(long.Y - alone.Y) < 1, ("uigate: with a long amount the chips moved the money from y %d to %d (#2712)"):format(alone.Y, long.Y))
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
		UI.asks.skipPace() -- #2880
		UI.asks.show("invite_ask")
	end },
	-- #2766: the update Event's Notify Me ask on the slide-in card, its two lines and two buttons
	{ "EventAsk", function()
		local EventRsvp = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Components.EventRsvp")
		UI.asks.skipPace() -- #2880
		local shown = UI.asks.card({
			title = EventRsvp.title(3600, 0),
			choices = {
				{ id = "remind", label = EventRsvp.REMIND, style = "primary" },
				{ id = "later", label = EventRsvp.LATER },
			},
			seconds = EventRsvp.ASK_SECONDS,
			lines = 2,
			answer = function() end,
		})
		assert(shown == true, "uigate: the Event ask did not show on a free card (#2766)")
	end },
	-- F93: the touch Net button, in a catching area while a swing could go (phones only)
	{ "NetButton", function()
		UI.setZone("Alley")
		UI.net.setEnabled(true)
	end },
	-- #2510 (Derek2: "add a tackle button instead of the bar in the middle of screen for mobile/ipad players"): in a
	-- catching area on touch the Tackle is a round button left of the Net button, clear of the jump button, the Net
	-- button and the potion timers; a tap greys it with the seconds left. With a mouse it stays the bar.
	-- #3342 (Derek2: "tackling immunity for the first 5 minutes"): while the join shield runs, a "🛡️ Safe m:ss" chip
	-- sits just over the Tackle bar or button, clear of it, and goes once the shield is over
	-- #3752: at a stuck cat's trap in a catching area the Rescue card and the Tackle bar (or the touch Tackle button)
	-- both show, and neither covers the other
	{ "RescueOverTackle", function()
		UI.setZone("Alley")
		UI.net.setEnabled(true)
		UI.shove.setEnabled(true)
		Scenes._tackle = true
		UI.catch.show({ strayId = "gate_rescue", catId = Catalog.cats[2].id, catName = "Mochi", rarity = "Rare", kind = "rescue" } :: any)
		Scenes._rescueCard = true
		UIShim.advance(0.6)
		local tackle = UIShim.playerGui:FindFirstChild("CatCafeTackle") :: ScreenGui
		local bar = tackle:FindFirstChild("Tackle", true) :: GuiObject
		assert(tackle.Enabled and bar.Visible, "uigate: no Tackle beside the Rescue card (#3752)")
		local catchGui = UIShim.playerGui:FindFirstChild("CatCafeCatch") :: ScreenGui
		local card = catchGui:FindFirstChild("Card", true) :: GuiObject
		assert(catchGui.Enabled and card.Visible, "uigate: no Rescue card (#3752)")
		local c0, c1 = card.AbsolutePosition, card.AbsolutePosition + card.AbsoluteSize
		local b0, b1 = bar.AbsolutePosition, bar.AbsolutePosition + bar.AbsoluteSize
		local clear = c1.X <= b0.X + 0.5 or b1.X <= c0.X + 0.5 or c1.Y <= b0.Y + 0.5 or b1.Y <= c0.Y + 0.5
		assert(clear, string.format("uigate: the Rescue card (bottom %d) covers the Tackle (top %d) (#3752)", c1.Y, b0.Y))
		assert(c0.Y >= 0, "uigate: the Rescue card left the screen over the Tackle bar (#3752)")
	end },
	{ "TackleShield", function()
		local me = game:GetService("Players").LocalPlayer
		me:SetAttribute("TackleShieldUntil", workspace:GetServerTimeNow() + 272)
		UI.setZone("Alley")
		UI.net.setEnabled(true)
		UI.shove.setEnabled(true)
		Scenes._tackle = true
		UIShim.advance(0.3)
		local gui = UIShim.playerGui:FindFirstChild("CatCafeTackle") :: ScreenGui
		local button = gui:FindFirstChild("Tackle", true) :: TextButton
		local chip = gui:FindFirstChild("Shield", true) :: TextLabel
		assert(chip and chip.Visible, "uigate: no shield chip while the join shield runs (#3342)")
		assert(chip.Text:find("Safe 4:3") ~= nil, "uigate: the shield chip reads " .. chip.Text .. " (#3342)")
		-- over the round button on touch, beside the bar's right end with a mouse (#3744)
		local chipBottom = chip.AbsolutePosition.Y + chip.AbsoluteSize.Y
		local over = chipBottom <= button.AbsolutePosition.Y + 0.5
		local beside = chip.AbsolutePosition.X >= button.AbsolutePosition.X + button.AbsoluteSize.X - 0.5
		assert(over or beside, "uigate: the shield chip covers the Tackle (#3342)")
		me:SetAttribute("TackleShieldUntil", workspace:GetServerTimeNow() - 1)
		UIShim.advance(0.3)
		assert(not chip.Visible, "uigate: the shield chip stayed after the shield ended (#3342)")
		me:SetAttribute("TackleShieldUntil", workspace:GetServerTimeNow() + 272)
		UIShim.advance(0.3)
	end },
	-- #3744 (Studio 11-12: "D... Safe 8:18 ..."): a cat in the bag in a catching area while the join shield runs, so
	-- the Drop pill, the Tackle and the Safe chip all show: the chip touches neither the pill nor the Tackle
	{ "PackDropShield", function()
		local player = UIShim.player
		local character = player.Character
		if character == nil then
			character = Instance.new("Model")
			character.Name = "Tester"
			character.Parent = workspace;
			(player :: any).Character = character
			UIShim.fire(UIShim.eventOf(player, "CharacterAdded"), character)
		end
		Scenes._packed = character
		character:SetAttribute("PackedCatId", Catalog.cats[1].id)
		player:SetAttribute("TackleShieldUntil", workspace:GetServerTimeNow() + 498)
		UI.setZone("Alley")
		UI.net.setEnabled(true)
		UI.shove.setEnabled(true)
		Scenes._tackle = true
		UIShim.advance(0.5)
		local hud = UIShim.playerGui:FindFirstChild("CatCafeHUD") :: ScreenGui
		local pill = hud:FindFirstChild("PackDrop", true) :: GuiObject
		local gui = UIShim.playerGui:FindFirstChild("CatCafeTackle") :: ScreenGui
		local chip = gui:FindFirstChild("Shield", true) :: TextLabel
		local tackle = gui:FindFirstChild("Tackle", true) :: GuiObject
		assert(pill and pill.Visible, "uigate: no Drop pill with a cat in the bag (#3744)")
		assert(chip and chip.Visible, "uigate: no Safe chip while the join shield runs (#3744)")
		assert(tackle and tackle.Visible, "uigate: no Tackle in the Alley with a cat in the bag (#3744)")
		local function apart(a: GuiObject, b: GuiObject): boolean
			local a0, a1 = a.AbsolutePosition, a.AbsolutePosition + a.AbsoluteSize
			local b0, b1 = b.AbsolutePosition, b.AbsolutePosition + b.AbsoluteSize
			return a1.X <= b0.X + 0.5 or b1.X <= a0.X + 0.5 or a1.Y <= b0.Y + 0.5 or b1.Y <= a0.Y + 0.5
		end
		assert(apart(chip, pill), "uigate: the Safe chip lies over the Drop pill (#3744)")
		assert(apart(chip, tackle), "uigate: the Safe chip lies over the Tackle (#3744)")
	end },
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
		-- #2721: on the thumb's arc above Net, not level with it
		assert(button.AbsolutePosition.Y + size.Y <= (netButton :: GuiObject).AbsolutePosition.Y + 0.5, "uigate: the Tackle button is not above Net (#2721)")
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
	-- #2724 (Derek2: "remove the extra hud clutter when doing catching so its easier to see / focus") and #2727 ("remove
	-- the pop up bubbles when catching cats"): while the circles run only the money stays on the HUD's root, a toast
	-- that comes waits (a warning still shows), and when they end the HUD is back as it was and the toast shows.
	-- The snapshot is taken mid-catch.
	{ "CatchFocus", function()
		local hud = UIShim.playerGui:FindFirstChild("CatCafeHUD") :: ScreenGui
		local root = hud:FindFirstChild("Root") :: Frame
		-- #2808: with a potion running, its timers stay down mid-catch (since #2827 they never show at all)
		UI.update({ buffs = { tip_potion = workspace:GetServerTimeNow() + 492 } } :: any)
		UIShim.advance(0.1)
		local timers = root:FindFirstChild("PotionTimers") :: Frame
		assert(timers ~= nil and not timers.Visible, "uigate: the potion timers showed before the catch (#2827)")
		local before: { [Instance]: boolean } = {}
		for _, child in root:GetChildren() do
			if child:IsA("GuiObject") then
				before[child] = child.Visible
			end
		end
		local function toast(text: string): TextLabel?
			for _, label in UIShim.playerGui:GetDescendants() do
				if label:IsA("TextLabel") and label.Name == "Text" and label.Text == text then
					return label
				end
			end
			return nil
		end
		-- a whole catch, start to end: the HUD steps aside and the toast waits
		startCatch("gate_focus", "Rare", 3, 0.2, 0.9)
		UIShim.advance(0.3)
		assert(UI.catch.circlesActive(), "uigate: the catch circles did not start")
		for child in before do
			local piece = child :: GuiObject
			if piece.Name ~= "Counters" then
				assert(not piece.Visible, "uigate: the HUD's " .. piece.Name .. " still shows mid-catch (#2724)")
			end
		end
		UIShim.advance(1.2) -- past a timer tick
		assert(not timers.Visible, "uigate: the potion timers came back mid-catch on their tick (#2808)")
		-- #3164: the left side laid out again mid-catch outside a render (the HUD's own AbsoluteSize handlers: a
		-- window resized, the money counter growing) leaves the menu's arrow tab down
		local fold = root:FindFirstChild("MenuFold") :: GuiObject
		assert(fold ~= nil and before[fold] == true, "uigate: the menu's arrow tab was not up before the catch (#3164)")
		local resized: any = root:GetPropertyChangedSignal("AbsoluteSize")
		local ran = 0
		for _, connection in resized.handlers do -- the shim's signal: its live connections, each with its `fn`
			if connection.Connected then
				connection.fn()
				ran += 1
			end
		end
		assert(ran > 0, "uigate: the HUD has no AbsoluteSize handler on its root, so #3164's check proves nothing")
		assert(not fold.Visible, "uigate: the menu's arrow tab showed mid-catch after a layout (#3164)")
		UI.toast("Tip Jar: 2 gifts claimed!", "info") -- (#3080: info, a green one never shows)
		UI.toast("Your paws are shaking!", "warn")
		UIShim.advance(0.3)
		assert(toast("Tip Jar: 2 gifts claimed!") == nil, "uigate: a toast showed mid-catch (#2727)")
		assert(toast("Your paws are shaking!") ~= nil, "uigate: a warning waited mid-catch (#2727)")
		UI.catch.hideCircles()
		UI.catch.hide()
		UIShim.advance(0.5)
		for child, was in before do
			assert((child :: GuiObject).Visible == was, "uigate: the HUD's " .. child.Name .. " did not come back after the catch (#2724)")
		end
		assert(toast("Tip Jar: 2 gifts claimed!") ~= nil, "uigate: the waiting toast never showed after the catch (#2727)")
		-- and the screen as it looks mid-catch, for the snapshot
		startCatch("gate_focus2", "Rare", 3, 0.2, 0.9)
		UIShim.advance(0.3)
	end },
	-- #3078 (Derek2 11-10: "the ui after catch still takes a second to pop back up should be instant"): the HUD is
	-- back the moment the result arrives, while the result word is still to come or still up, for a catch and a miss
	{ "CatchHudBack", function()
		local hud = UIShim.playerGui:FindFirstChild("CatCafeHUD") :: ScreenGui
		local root = hud:FindFirstChild("Root") :: Frame
		UIShim.advance(4) -- earlier scenes' toasts and results gone
		local before: { [Instance]: boolean } = {}
		for _, child in root:GetChildren() do
			if child:IsA("GuiObject") then
				before[child] = child.Visible
			end
		end
		local function back(what: string)
			for child, was in before do
				assert(
					(child :: GuiObject).Visible == was,
					"uigate: the HUD's " .. child.Name .. " is not back the moment " .. what .. " (#3078)"
				)
			end
		end
		startCatchV3("gate_back", "Common", { "single", "single", "single" }, 2, 8)
		UIShim.advance(0.3)
		local hiddenNow = false
		for child, was in before do
			if was and not (child :: GuiObject).Visible then
				hiddenNow = true
			end
		end
		assert(hiddenNow, "uigate: the HUD did not step aside for the catch, so the scene proves nothing (#3078)")
		UI.catch.showGrades("gate_back", { "perfect", "perfect", "perfect" }, true, 0, nil,
			{ trust = 8, trustNeed = 8, finish = "purrfect", streak = 3 })
		back("a catch's result comes")
		assert(UI.catch.circlesActive(), "uigate: the result word was skipped (#3078 keeps its flash)")
		UIShim.advance(2)
		back("the catch's word has gone")
		startCatchV3("gate_back2", "Common", { "single", "single", "single" }, 2, 8)
		UIShim.advance(0.3)
		UI.catch.showGrades("gate_back2", { "miss" }, false, 0, nil, nil)
		back("a miss's result comes")
		UIShim.advance(2)
	end },
	-- #2731 (Derek2's backpack bugs: no way to drop a packed cat with empty arms): with a PackedCatId on the character
	-- and nothing in the arms, a small "Drop bag cat" pill sits where the carry banner would, thumb sized, on screen,
	-- one line; a tap fires dropCat. While carrying, the carry banner's Drop takes over and the pill hides.
	{ "PackDrop", function()
		local player = UIShim.player
		local character = player.Character
		if character == nil then
			character = Instance.new("Model")
			character.Name = "Tester"
			character.Parent = workspace;
			(player :: any).Character = character
			UIShim.fire(UIShim.eventOf(player, "CharacterAdded"), character)
		end
		Scenes._packed = character
		character:SetAttribute("PackedCatId", Catalog.cats[1].id)
		UIShim.advance(0.5)
		local hud = UIShim.playerGui:FindFirstChild("CatCafeHUD") :: ScreenGui
		local pill = hud:FindFirstChild("PackDrop", true) :: GuiObject
		assert(pill and pill.Visible, "uigate: no Drop pill with a cat in the backpack (#2731)")
		local size = pill.AbsoluteSize
		local hit = (pill:FindFirstChild("Hit") or pill:FindFirstChild("Face", true)) :: GuiButton
		assert(hit.AbsoluteSize.Y >= 36, ("uigate: the Drop pill takes a %d px tap, under a thumb (#2731)"):format(hit.AbsoluteSize.Y))
		local root = hud:FindFirstChild("Root") :: GuiObject
		local at, rootAt, rootSize = pill.AbsolutePosition, root.AbsolutePosition, root.AbsoluteSize
		assert(at.X >= rootAt.X and at.Y >= rootAt.Y and at.X + size.X <= rootAt.X + rootSize.X + 0.5 and at.Y + size.Y <= rootAt.Y + rootSize.Y + 0.5, "uigate: the Drop pill runs off screen (#2731)")
		for _, label in pill:GetDescendants() do
			if label:IsA("TextLabel") and label.Text ~= "" and label.Text ~= "G" then
				assert(label.TextFits, "uigate: the Drop pill's words do not fit: " .. label.Text .. " (#2731)")
			end
		end
		-- #3010 (Derek2: "drop cat from bag and probably drop button also on mobile overlaps the cafe and cannon
		-- buttons slightly so make it smaller"): the pill, its tap pad, and then the carry banner with its Drop each
		-- stop at least 3 px above every bottom row tile, and on touch the pill is smaller than #2731's 160 x 44
		local travel = hud:FindFirstChild("Travel", true) :: GuiObject
		local function clearOfRow(piece: GuiObject, what: string)
			local foot = piece.AbsolutePosition.Y + piece.AbsoluteSize.Y
			for _, tile in travel:GetChildren() do
				if tile:IsA("GuiObject") and tile.Visible then
					local gap = tile.AbsolutePosition.Y - foot
					assert(gap >= 3, ("uigate: %s is %.1f px from the bottom row's %s (#3010)"):format(what, gap, tile.Name))
				end
			end
		end
		clearOfRow(pill, "the Drop pill")
		clearOfRow(hit, "the Drop pill's tap pad")
		if UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Scale").isTouch() then
			local scale = size.X / pill.Size.X.Offset
			assert(pill.Size.X.Offset < 160 and pill.Size.Y.Offset < 44, "uigate: the Drop pill is not smaller on touch (#3010)")
			assert(hit.AbsoluteSize.Y >= 44 - 0.5 or hit.AbsoluteSize.Y >= 44 * scale - 0.5, "uigate: the smaller Drop pill lost its thumb sized tap pad (#3010)")
		end
		local fired = 0
		local connection = UI.events.dropCat:Connect(function()
			fired += 1
		end)
		UIShim.fire(UIShim.eventOf(hit, "Activated"))
		connection:Disconnect()
		assert(fired == 1, "uigate: the Drop pill did not fire dropCat (#2731)")
		UI.setCarrying({ catId = Catalog.cats[1].id, catName = "Mochi", rarity = "Rare" } :: any)
		UIShim.advance(0.3)
		assert(not pill.Visible, "uigate: the Drop pill shows beside the carry banner (#2731)")
		local carry = hud:FindFirstChild("Carry", true) :: GuiObject
		assert(carry and carry.Visible, "uigate: no carry banner while carrying (#3010)")
		clearOfRow(carry, "the carry banner")
		local drop = carry:FindFirstChild("Drop") :: GuiObject
		clearOfRow((drop:FindFirstChild("Hit") or drop) :: GuiObject, "the carry banner's Drop tap pad")
		-- #3145 (Derek2: the carry banner stayed up for a cat that was gone and Drop did nothing): UI.carryView says
		-- what the screen holds, and shared/CarrySync calls it stale whenever that is not the server's carried cat, so
		-- UIController sets it again: a banner left up, and a cat left in the UI's state with no banner
		local CarrySync = UIShim.require("ReplicatedStorage.Shared.CarrySync")
		local held = Catalog.cats[1].id
		local view = (UI :: any).carryView()
		assert(view.built and view.banner and view.catId == held, "uigate: UI.carryView does not see the carry banner (#3145)")
		assert(not CarrySync.stale(held, held, view), "uigate: a shown carry reads as stale (#3145)")
		assert(CarrySync.stale(nil, nil, view), "uigate: a banner up for a cat the server no longer has does not read as stale (#3145)")
		UI.setCarrying(nil)
		UIShim.advance(0.3)
		assert(pill.Visible, "uigate: the Drop pill did not come back after carrying (#2731)")
		view = (UI :: any).carryView()
		assert(view.built and not view.banner and view.catId == nil, "uigate: UI.carryView still sees a carry after it ended (#3145)")
		assert(not CarrySync.stale(nil, nil, view), "uigate: an empty screen reads as stale (#3145)")
		UI.update({ carrying = held } :: any) -- a sync's copy with no banner call after it
		view = (UI :: any).carryView()
		assert(view.catId == held and not view.banner, "uigate: UI.carryView does not see the cat left in the UI's state (#3145)")
		assert(CarrySync.stale(nil, nil, view), "uigate: a cat left in the UI's state does not read as stale (#3145)")
		UI.setCarrying(nil)
		UIShim.advance(0.1)
		view = (UI :: any).carryView()
		assert(view.catId == nil and not view.banner and not carry.Visible, "uigate: UI.setCarrying(nil) did not clear the screen (#3145)")
		-- #3119 (Derek2: "drop bag cat / drop on pc now goes inside my cafe/cannon ui make it stack on top of tackle
		-- for PC"): off touch the pill stands a Tackle bar's height and a gap over the bottom row's tiles; in a
		-- catching area the bar sits in that place, over the row and under the pill, and the pill does not move
		if not UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Scale").isTouch() then
			local TackleBar = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Screens.TackleBar")
			local scale = pill.AbsoluteSize.X / pill.Size.X.Offset
			local rowTop = math.huge
			for _, tile in travel:GetChildren() do
				if tile:IsA("GuiObject") and tile.Visible then
					rowTop = math.min(rowTop, tile.AbsolutePosition.Y)
				end
			end
			local function foot(piece: GuiObject): number
				return piece.AbsolutePosition.Y + piece.AbsoluteSize.Y
			end
			local room = rowTop - foot(pill)
			assert(room >= (TackleBar.HEIGHT + 8) * scale - 0.5, ("uigate: the Drop pill is %.1f px over the bottom row, less than the Tackle bar's place (#3119)"):format(room))
			local before = pill.AbsolutePosition.Y
			UI.setZone("Alley")
			UI.shove.setEnabled(true)
			Scenes._tackle = true
			UIShim.advance(0.3)
			local tackleGui = UIShim.playerGui:FindFirstChild("CatCafeTackle") :: ScreenGui
			local bar = tackleGui and tackleGui:FindFirstChild("Tackle", true) :: GuiObject?
			assert(bar and tackleGui.Enabled, "uigate: no Tackle bar in a catching area with a cat in the backpack (#3119)")
			assert(math.abs(pill.AbsolutePosition.Y - before) < 0.5, "uigate: the Drop pill moved when the Tackle bar came (#3119)")
			assert(bar.AbsolutePosition.Y - foot(pill) >= 3, ("uigate: the Drop pill is %.1f px over the Tackle bar, not stacked on it (#3119)"):format(bar.AbsolutePosition.Y - foot(pill)))
			assert(rowTop - foot(bar) >= 3, ("uigate: the Tackle bar is %.1f px from the bottom row under a Drop (#3119)"):format(rowTop - foot(bar)))
			-- the carry banner takes the same place (the bar hides while carrying)
			UI.setCarrying({ catId = Catalog.cats[1].id, catName = "Mochi", rarity = "Rare" } :: any)
			UIShim.advance(0.3)
			assert(rowTop - foot(carry) >= (TackleBar.HEIGHT + 8) * scale - 0.5, "uigate: the carry banner is not over the Tackle bar's place (#3119)")
			UI.setCarrying(nil)
			UIShim.advance(0.3)
		end
	end },
	-- #2721 (Derek2: "do some research for where mobile players like their buttons and move the net/tackle to where it
	-- would fit best"): NET just left of the jump button, centres level, and TACKLE on the thumb's arc up and left of
	-- it, both within 1.8 jump widths of the jump button's centre, clear of each other, the jump button, the bottom
	-- row and the goal card, on screen and thumb sized. No touch buttons with a mouse.
	{ "ActionButtonsReach", function()
		local Scale = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Scale")
		local NetButtonPlace = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Components.NetButtonPlace")
		UI.setZone("Alley")
		UI.net.setEnabled(true)
		UI.shove.setEnabled(true)
		Scenes._tackle = true
		UIShim.advance(0.3)
		local netGui = UIShim.playerGui:FindFirstChild("CatCafeNetButton") :: ScreenGui
		local tackleGui = UIShim.playerGui:FindFirstChild("CatCafeTackle") :: ScreenGui
		local net = netGui and netGui:FindFirstChild("Net", true) :: GuiObject?
		local tackle = tackleGui and tackleGui:FindFirstChild("Tackle", true) :: GuiObject?
		if not Scale.isTouch() then
			assert(netGui == nil or not netGui.Enabled, "uigate: the touch Net button shows with a mouse (#2721)")
			return
		end
		assert(net and netGui.Enabled and tackle and tackleGui.Enabled, "uigate: no Net or Tackle button in a catching area (#2721)")
		local viewport = workspace.CurrentCamera.ViewportSize
		local jumpAt, jumpSize = NetButtonPlace.jump(viewport)
		local jumpCentre = jumpAt + Vector2.new(jumpSize, jumpSize) / 2
		-- AbsolutePosition is measured below the top bar's inset, even in a ScreenGui that ignores it; the jump
		-- button's spot is in screen pixels
		local inset = game:GetService("GuiService"):GetGuiInset()
		local function box(object: GuiObject): (number, number, number, number)
			local at = object.AbsolutePosition + inset
			return at.X, at.Y, at.X + object.AbsoluteSize.X, at.Y + object.AbsoluteSize.Y
		end
		local function apart(a: { number }, b: { number }): boolean
			return a[3] <= b[1] + 0.5 or b[3] <= a[1] + 0.5 or a[4] <= b[2] + 0.5 or b[4] <= a[2] + 0.5
		end
		local jumpBox = { jumpAt.X, jumpAt.Y, jumpAt.X + jumpSize, jumpAt.Y + jumpSize }
		local boxes = {}
		for name, button in { NET = net :: GuiObject, TACKLE = tackle :: GuiObject } do
			local x1, y1, x2, y2 = box(button)
			local b = { x1, y1, x2, y2 }
			boxes[name] = b
			assert(x2 - x1 >= 44 and y2 - y1 >= 44, ("uigate: %s is %d px, under a thumb's 44 (#2721)"):format(name, x2 - x1))
			assert(x1 >= 0 and y1 >= 0 and x2 <= viewport.X + 0.5 and y2 <= viewport.Y + 0.5, "uigate: " .. name .. " runs off screen (#2721)")
			local reach = (Vector2.new((x1 + x2) / 2, (y1 + y2) / 2) - jumpCentre).Magnitude
			assert(reach <= jumpSize * 1.8, ("uigate: %s is %d px from the jump button, out of the thumb's reach (#2721)"):format(name, reach))
			assert(apart(b, jumpBox), "uigate: " .. name .. " covers the jump button (#2721)")
		end
		assert(apart(boxes.NET, boxes.TACKLE), "uigate: NET and TACKLE overlap (#2721)")
		assert(math.abs((boxes.NET[2] + boxes.NET[4]) / 2 - jumpCentre.Y) <= 1, "uigate: NET is not level with the jump button (#2721)")
		assert(boxes.TACKLE[4] <= boxes.NET[2] + 0.5, "uigate: TACKLE is not above NET (#2721)")
		-- every HUD button on screen (the bottom row's tiles, the menu) and the goal card
		local hud = UIShim.playerGui:FindFirstChild("CatCafeHUD") :: ScreenGui
		local function shown(object: Instance): boolean
			local at: Instance? = object
			while at and at ~= hud do
				if at:IsA("GuiObject") and not at.Visible then
					return false
				end
				at = at.Parent
			end
			return true
		end
		for _, other in hud:GetDescendants() do
			local goal = other.Name == "TierGoal"
			if other:IsA("GuiObject") and (goal or other:IsA("GuiButton")) and other.AbsoluteSize.X >= 20 and shown(other) then
				local x1, y1, x2, y2 = box(other)
				for which, b in boxes do
					assert(apart(b, { x1, y1, x2, y2 }), ("uigate: %s covers the HUD's %s (#2721)"):format(which, other:GetFullName()))
				end
			end
		end
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
		-- #2871: 300 design px; a 1080p TV draws the UI at 1.5 times, so the same strip is 327.6 px there
		local stripScale = math.max(1, UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Scale").get())
		assert(strip.AbsoluteSize.X < 300 * stripScale, "uigate: the 30 ring strip is " .. strip.AbsoluteSize.X .. " px wide (#2332)")
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
		-- #3009 (Derek2: the cat's banner "should be instantly gone ... after it is caught"): the header with the
		-- cat's name, rarity and hint is hidden the moment the result comes
		local layer = UIShim.playerGui:FindFirstChild("CatCafeCatchCircles")
		local header = layer and layer:FindFirstChild("Header", true) :: GuiObject?
		assert(header and not header.Visible, "uigate: the catch header is still up after the catch (#3009)")
		task.wait(0.75)
		local banner = layer and layer:FindFirstChild("FinishBanner", true)
		assert(banner and banner.Visible and banner.Text == "PURRFECT!", "uigate: no PURRFECT! banner after the wrap (#1884)")
		assert(not header.Visible, "uigate: the catch header came back with the word (#3009)")
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
	-- #3009 (Derek2: the word and the banner "stay for too long on catch should disappear almost instantly"): the
	-- word pops with the net wrap (0.6 s), is gone 0.4 s later and the catch screen is off; the next catch's header
	-- shows again. A bolt's header goes at once too, its "So close!" stays 0.8 s.
	{ "CatchV3Flash", function()
		startCatchV3("gate_v3x", "Common", { "single", "single", "single" }, 2, 8)
		task.wait(0.4)
		local layer = UIShim.playerGui:FindFirstChild("CatCafeCatchCircles") :: ScreenGui
		local header = layer:FindFirstChild("Header", true) :: GuiObject
		assert(header.Visible, "uigate: no header during the catch (#3009)")
		UI.catch.showGrades("gate_v3x", { "perfect", "good", "perfect" }, true, 0, nil,
			{ trust = 8, trustNeed = 8, finish = "great", streak = 0 })
		assert(not header.Visible, "uigate: the catch header is still up after the catch (#3009)")
		task.wait(0.7)
		local banner = layer:FindFirstChild("FinishBanner", true) :: TextLabel
		assert(banner.Visible and banner.Text == "GREAT!", "uigate: no GREAT! with the net wrap (#3009)")
		task.wait(0.4) -- 1.1 s after the result: the word's 0.4 s is over
		assert(not layer.Enabled or not banner.Visible, "uigate: the catch word is still up 1.1 s after the catch (#3009)")
		assert(not layer.Enabled, "uigate: the catch screen is still on 1.1 s after the catch (#3009)")
		-- the next catch has its header again; a bolt hides it at once and keeps So close! for 0.8 s
		startCatchV3("gate_v3y", "Rare", { "single", "single" }, 2, 8)
		task.wait(0.3)
		assert(layer.Enabled and header.Visible, "uigate: the next catch has no header (#3009)")
		UI.catch.finished("gate_v3y", { trust = -1, trustNeed = 8, finish = "bolt", streak = 0 })
		UI.catch.showGrades("gate_v3y", { "miss", "miss" }, false, 0)
		assert(not header.Visible, "uigate: the catch header is still up after a bolt (#3009)")
		task.wait(0.4)
		banner = layer:FindFirstChild("FinishBanner", true) :: TextLabel
		assert(banner.Visible and banner.Text == "So close!", "uigate: So close! went too soon (#3009)")
		task.wait(0.6)
		assert(not layer.Enabled, "uigate: the catch screen is still on 1 s after a bolt (#3009)")
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
		local jumpSize = select(2, NetButtonPlace.jump(viewport))
		local gx2, gy2 = x0 + grab.AbsoluteSize.X, y0 + grab.AbsoluteSize.Y
		local jumpClear = gx2 <= jumpAt.X + 0.5 or jumpAt.X + jumpSize <= x0 + 0.5 or gy2 <= jumpAt.Y + 0.5 or jumpAt.Y + jumpSize <= y0 + 0.5
		assert(jumpClear, "uigate: the RESCUE button runs onto the jump button (#2409)")
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
		UI.toast(line, "info") -- (#3080: info; a green toast off the keep list never shows)
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
		-- #3206 (Derek2: "make sure to not play tackle cutscene when not in safezone"): due out in a catching area, the
		-- lesson waits; it starts once the player is back on the safe street
		UI.setZone("Alley")
		UI.tips.show("tackle_lesson")
		UIShim.advance(1.5)
		assert(not UI.intro.playing(), "uigate: the tackling lesson started outside the safe zone (#3206)")
		UI.setZone(nil)
		for _ = 1, 60 do -- (a tip card that took the free moment out there finishes first)
			if UI.intro.playing() then
				break
			end
			UIShim.advance(0.25)
		end
		assert(UI.intro.playing(), "uigate: the tackling lesson did not start back on the safe street (#3206, #2198)")
		UIShim.advance(0.25)
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
		assert(table.find(seen, "tackle_lesson") == nil, "uigate: the lesson was saved as seen before it ended (#2198) " .. table.concat(seen, ","))
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
		assert(seen[#seen] == "tackle_lesson", "uigate: the lesson's end did not save the tackle tip as seen (#2198) " .. table.concat(seen, ","))
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
	-- #3106: a new player's first delivery says "on its way to your cafe!" once; a player past the walk-through never
	{ "FirstDeliveryToast", function()
		local function count(text: string): number
			local found = 0
			for _, label in UIShim.playerGui:GetDescendants() do
				if label:IsA("TextLabel") and label.Name == "Text" and label.Text == text then
					found += 1
				end
			end
			return found
		end
		local line = "🧺 Mochi is on its way to your cafe!"
		UI.update({ tutorialStep = 5 })
		UI.cannon.checkedIn("Mochi")
		UIShim.advance(0.3)
		assert(count(line) == 0, "uigate: the delivery pop-up showed past the walk-through (#3106)")
		UI.update({ tutorialStep = 2 })
		UI.cannon.checkedIn("Mochi")
		UI.cannon.checkedIn("Mochi")
		UIShim.advance(0.3)
		assert(count(line) == 1, "uigate: a new player's first delivery did not show its pop-up once (#3106)")
	end },
	-- #3105: the loading screen over the still wait before the first shot, and a play sliding it away
	{ "IntroLoading", function()
		-- #3179: with the loadingScreen switch off (its default, and before its attribute arrives) nothing shows and
		-- the intro has no count to wait for; an explicit true brings the screen back
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local gui = UIShim.playerGui:FindFirstChild("CatCafeIntroWait") :: ScreenGui
		for _, off in { nil, false } :: { any } do
			ReplicatedStorage:SetAttribute("LiveFlag_loadingScreen", off)
			UI.intro.waiting(true)
			UIShim.advance(0.3)
			assert(not gui.Enabled, "uigate: the loading screen showed with its switch off (#3179)")
			assert(UI.intro.race() == 0, "uigate: the intro waits for a loading screen that is not up (#3179)")
		end
		ReplicatedStorage:SetAttribute("LiveFlag_loadingScreen", true)
		UI.intro.waiting(true)
		assert(gui.Enabled, "uigate: the loading screen did not show (#3105)")
		local count = gui:FindFirstChild("Count", true) :: TextLabel
		local fill = gui:FindFirstChild("Fill", true) :: Frame
		local paw = gui:FindFirstChild("Paw", true) :: TextLabel
		assert(gui:FindFirstChild("Face", true), "uigate: the loading screen has no cat (#3109)")
		UIShim.advance(0.9)
		-- #3109: the count creeps while the save loads, and never reaches 100 by itself
		local value = tonumber((count.Text:gsub("%%", "")))
		assert(value and value > 20 and value <= 90, "uigate: the loading count reads " .. count.Text .. " after 0.9 s (#3109)")
		assert(fill.Size.X.Scale > 0.2 and fill.Size.X.Scale <= 0.9, "uigate: the loading bar did not fill with the count (#3109)")
		assert(paw.Position.X.Scale == fill.Size.X.Scale, "uigate: the paw is not at the bar's tip (#3109)")
		-- hidden and shown again at once: the slide away must not carry the new show off (review on #3107)
		UI.intro.waiting(false)
		UI.intro.waiting(true)
		UIShim.advance(0.6)
		local cover = gui:FindFirstChild("Cover") :: Frame
		assert(gui.Enabled, "uigate: the loading screen went off after a quick hide and show (#3105)")
		assert(cover.Position.Y.Scale == 0, "uigate: the loading screen slid away after a quick hide and show (#3105)")
		UIShim.advance(10)
		assert(count.Text ~= "100%", "uigate: the loading count sat at 100 while still loading (#3109)")
		ReplicatedStorage:SetAttribute("LiveFlag_loadingScreen", nil) -- #3179: back to its default
	end },
	-- #3109 (Derek2 11-10: "instantly goes up to 100 really fast then transitions to the tutorial scenes"): once the
	-- save is in the count races to 100 in SHOWN_MIN at most from the screen's start, and stays up until the play
	{ "IntroLoadingRace", function()
		local LoadingCount = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Components.LoadingCount")
		assert(UI.intro.race() == 0, "uigate: a race with no loading screen up should take no time (#3109)")
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		ReplicatedStorage:SetAttribute("LiveFlag_loadingScreen", true) -- #3179: the screen is behind this switch
		UI.intro.waiting(true)
		UIShim.advance(0.3)
		local seconds = UI.intro.race()
		assert(
			seconds >= LoadingCount.RACE_MIN and seconds <= LoadingCount.SHOWN_MIN,
			("uigate: the race to 100 takes %.2f s (#3109)"):format(seconds)
		)
		assert(UI.intro.race() <= seconds, "uigate: a second ask restarted the race (#3109)")
		local gui = UIShim.playerGui:FindFirstChild("CatCafeIntroWait") :: ScreenGui
		local count = gui:FindFirstChild("Count", true) :: TextLabel
		local fill = gui:FindFirstChild("Fill", true) :: Frame
		UIShim.advance(seconds / 2)
		assert(count.Text ~= "100%", "uigate: the count hit 100 half way through its race (#3109)")
		UIShim.advance(seconds / 2 + 0.1)
		assert(count.Text == "100%", "uigate: the count reads " .. count.Text .. " after its race (#3109)")
		assert(fill.Size.X.Scale == 1, "uigate: the bar is not full at 100 (#3109)")
		assert(gui.Enabled, "uigate: the loading screen left before the intro started (#3109)")
		ReplicatedStorage:SetAttribute("LiveFlag_loadingScreen", nil)
	end },
	{ "IntroLoadingLifts", function()
		game:GetService("ReplicatedStorage"):SetAttribute("LiveFlag_loadingScreen", true) -- #3179
		UI.intro.waiting(true)
		UI.intro.start({ skipAfter = 5 })
		UI.intro.setShot(1, "Welcome to your cat cafe!", nil, 4.2)
		UIShim.advance(0.5)
		local gui = UIShim.playerGui:FindFirstChild("CatCafeIntroWait") :: ScreenGui
		assert(not gui.Enabled, "uigate: the loading screen stayed up over the intro (#3105)")
		-- #3179: the switch back to its default for the scenes after these three
		game:GetService("ReplicatedStorage"):SetAttribute("LiveFlag_loadingScreen", nil)
	end },
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
		-- #2871: 48 design px; a 1080p TV draws the UI at 1.5 times
		local dotScale = math.max(1, UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Scale").get())
		assert(y >= 0 and y + dot.AbsoluteSize.Y <= 48 * dotScale, ("uigate: the shot dot sits %d px from the top, not near it (#2702)"):format(y))
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
		-- #3024: only where the lower bar shows (a PC); on touch it is hidden, and on a 4:3 iPad its hidden frame sat above
		-- the read bar and failed this for nothing. The touch branch below checks the read bar against Skip and Next.
		if bottom.Visible then
			assert(read.AbsolutePosition.Y + read.AbsoluteSize.Y <= bottom.AbsolutePosition.Y + 1, "uigate: the read bar sits on the lower bar (#2182)")
		end
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
		-- #3168: a press moves on at once, the shot it lands in (was not in a shot's first second, #2182), and a second
		-- press on the same shot does nothing (the shim's tweens end at once, so the bar's fill is not checked here)
		UI.intro.setShot(2, "Boom! Every area starts at a safe camp", nil, 4.2)
		UIShim.fire(UIShim.eventOf(tap, "Activated"))
		UIShim.fire(UIShim.eventOf(nextPill, "Activated"))
		assert(#fired == 1 and fired[1] == 2, ("uigate: a press at once fired introNext %d times (#3168)"):format(#fired))
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
	-- #2916 (an open loop at exit): Gameplay's next goals on the recap, each over its progress bar with its count (the
	-- "away" goal with none), under the Today line and in place of the one "what's next" line
	{ "SessionRecapGoals", function()
		UI.update({ tutorialStep = 9, grandOpening = { done = { [1] = true, [2] = true, [3] = true } } })
		UI.recap.shown = false
		UI.recap.lastInput = os.clock() - 30 -- idle
		UI.recap.show({
			minutes = 41,
			newCats = 3,
			earned = 12500,
			goals = {
				{ kind = "cats", have = 3, need = 5, tier = 4, area = "woods" },
				{ kind = "coins", have = 1200000, need = 5000000, tier = 4 },
				{ kind = "away", amount = 48200, hours = 8 },
			},
		} :: any)
		local card = UIShim.playerGui:FindFirstChild("CatCafeRecap"):FindFirstChild("Card", true) :: Frame
		assert(card.Visible, "uigate: no session recap card with goals (#2916)")
		local first = card:FindFirstChild("Line1", true) :: TextLabel
		local second = card:FindFirstChild("Line2", true) :: TextLabel
		assert(second.Visible and not string.find(second.Text, "Grand Opening", 1, true), "uigate: the one next line still shows beside the goals (#2916)")
		local goal1 = card:FindFirstChild("Goal1", true) :: Frame
		local text1 = goal1:FindFirstChild("Text") :: TextLabel
		assert(goal1.Visible and text1.Text == "Open the Woods: 3 of 5 cats", "uigate: the first goal reads " .. text1.Text .. " (#2916)")
		assert(goal1.AbsolutePosition.Y >= first.AbsolutePosition.Y + first.AbsoluteSize.Y - 1, "uigate: the goals are not under the Today line (#2916)")
		assert(goal1.AbsolutePosition.Y + goal1.AbsoluteSize.Y <= second.AbsolutePosition.Y + 1, "uigate: the goals run into the next line (#2916)")
		local fill = goal1:FindFirstChild("Fill", true) :: Frame
		local track = fill.Parent :: Frame
		assert(math.abs(fill.AbsoluteSize.X - track.AbsoluteSize.X * 0.6) <= 2, "uigate: the first goal's bar is not at 3/5 (#2916)")
		local shortScreen = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Scale").isShort()
		local goal3 = card:FindFirstChild("Goal3", true) :: Frame
		if shortScreen then
			assert(not goal3.Visible, "uigate: three goals on a short screen (#2916)")
		else
			assert(goal3.Visible and not (goal3:FindFirstChild("Bar") :: Frame).Visible, "uigate: the away goal has a bar (#2916)")
		end
		local last = card:FindFirstChild("Line3", true) :: TextLabel
		local bottom = last.AbsolutePosition.Y + last.AbsoluteSize.Y
		assert(bottom <= card.AbsolutePosition.Y + card.AbsoluteSize.Y + 1, "uigate: the recap's last line hangs off the card (#2916)")
		assert(card.AbsolutePosition.Y >= 0, "uigate: the recap with goals runs off the top of the screen (#2916)")
	end },
	-- #2916 (a goal on return): with no ReturnHook pick, the welcome back card's line points at Gameplay's nearest goal
	{ "WelcomeBackGoal", function()
		Scenes._returnHook = true
		UI.update({
			tipsSeen = { stuck_cat = true, codes_cat = true },
			returnHook = false,
			returnGoals = { { kind = "cats", have = 3, need = 5, tier = 4, area = "woods" } },
		} :: any)
		UI.showOfflineEarnings(48200, 3 * 3600)
		local card = UIShim.playerGui:FindFirstChild("CatCafePopups"):FindFirstChild("Offline", true) :: Frame
		assert(card and card.Visible, "uigate: no welcome back card (#2916)")
		local hook = card:FindFirstChild("Hook") :: TextLabel
		assert(hook.Visible and hook.Text == "Next: open the Woods, 3 of 5 cats", "uigate: the welcome back goal line reads " .. hook.Text .. " (#2916)")
		assert(hook.TextFits, "uigate: the welcome back goal line does not fit (#2916)")
	end },
	-- F87 section 2f: a brand new player's small HUD, the money, the hint strip, Home and the Cannon, the Tutorial
	-- tile and Settings
	{ "SmallHUD", function()
		UI.update({ tutorialStep = 0, tier = 1, cats = {}, potions = {}, goldenFish = 0 })
		UI.tutorial.show(UI.tutorial.hint({ tutorialStep = 0, tier = 1, cats = {}, upgradeLevels = {} }))
	end },
	-- the first loop done: every piece comes back (from a new player's state to the sample player again, at step 5).
	-- #3161 (Derek2 11-10: "it highlights all buttons and so many pop ups when catching first food bowl cat"): that
	-- many opening at once carry no gold "New!" (Components/HudUnlocks.pops); one or two opening together still do
	{ "SmallHUDNew", function()
		UI.update({ tutorialStep = 0, tier = 1, cats = {}, potions = {}, goldenFish = 0 })
		-- #3183 (Derek2 11-10: "remove all the new pop ups in buttons when finishing tutorial steps"): step 2 opens
		-- Cats and Upgrades with no gold "New!" either
		UI.update({ tutorialStep = 2 } :: any)
		for _, piece in (UIShim.playerGui:FindFirstChild("CatCafeHUD") :: ScreenGui):GetDescendants() do
			assert(not (piece.Name == "New" and piece:IsA("TextLabel")), "uigate: a New! badge on " .. piece.Parent.Name .. " at a tutorial step (#3183)")
		end
		local player = samplePlayer(os.time())
		player.tutorialStep = 5
		UI.update(player)
		local hud = UIShim.playerGui:FindFirstChild("CatCafeHUD") :: ScreenGui
		for _, piece in hud:GetDescendants() do
			assert(not (piece.Name == "New" and piece:IsA("TextLabel")), "uigate: a New! badge on " .. piece.Parent.Name .. " as the tutorial's end opens the whole HUD (#3161)")
		end
		local quests = hud:FindFirstChild("Quests", true) :: GuiObject?
		assert(quests ~= nil and quests.Visible, "uigate: the Quests tile did not open at the tutorial's end")
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
	-- #3880: step 4 with the table and the Bait bowl bought: the Upgrades window's X glows (with the arrow and the
	-- spotlight), and not once the tutorial is done
	{ "TutorialUpgradeClose", function()
		local levels = { tables = 1, lure_bowl = 1, espresso = 0, net = 0, lucky_cat = 0 }
		UI.update({ tutorialStep = 4, tier = 1, upgradeLevels = levels } :: any)
		UI.open("Upgrades")
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local window = modals and modals:FindFirstChild("Upgrades", true)
		local close = window and window:FindFirstChild("Close", true)
		assert(close, "uigate: the Upgrades window has no X (#3880)")
		assert(close:FindFirstChild("TutorialGlow"), "uigate: the Upgrades X does not glow after the bowl is bought (#3880)")
		local bowl = window:FindFirstChild("lure_bowl", true)
		assert(bowl and bowl:FindFirstChild("TutorialGlow") == nil, "uigate: the owned Bait bowl row still glows (#3880)")
		task.wait(0.2) -- the arrow and spotlight settle on the X for the picture
	end },
	-- #2912: at step 3 with coins for a table, a Buy button stands on the tutorial strip, on screen, clear of the strip
	-- and with its words fitting; short of coins it is gone
	{ "TutorialBuy", function()
		local levels = { tables = 0, lure_bowl = 0, espresso = 0, net = 0, lucky_cat = 0 }
		UI.update({ tutorialStep = 3, tier = 1, money = 850, upgradeLevels = levels } :: any)
		UI.tutorial.show(UI.tutorial.hint({ tutorialStep = 3, tier = 1, cats = {}, upgradeLevels = levels }))
		task.wait(0.2)
		local hud = UIShim.playerGui:FindFirstChild("CatCafeHUD") :: ScreenGui
		local buy = hud:FindFirstChild("TutorialBuy", true) :: GuiObject?
		local strip: GuiObject? = nil -- the strip label, not the HUD's Tutorial tile of the same name
		for _, piece in hud:GetDescendants() do
			if piece.Name == "Tutorial" and piece:IsA("TextLabel") and piece.Text ~= "" then
				strip = piece
			end
		end
		assert(buy ~= nil and buy.Visible, "uigate: no Buy button on the strip at step 3 with 850 coins (#2912)")
		assert(strip ~= nil and strip.Visible, "uigate: the tutorial strip is hidden at step 3")
		local text: TextLabel? = nil
		for _, piece in (buy :: GuiObject):GetDescendants() do
			if piece:IsA("TextLabel") and string.find(piece.Text, "Buy a table", 1, true) then
				text = piece
			end
		end
		assert(text ~= nil, "uigate: the Buy button does not say Buy a table (#2912)")
		assert((text :: TextLabel).TextFits ~= false, "uigate: the Buy button's words do not fit (#2912)")
		local b, s = (buy :: GuiObject), (strip :: GuiObject)
		local screen = hud.AbsoluteSize
		assert(b.AbsolutePosition.X >= 0 and b.AbsolutePosition.X + b.AbsoluteSize.X <= screen.X and b.AbsolutePosition.Y >= 0, "uigate: the Buy button runs off screen (#2912)")
		assert(b.AbsolutePosition.Y + b.AbsoluteSize.Y <= s.AbsolutePosition.Y + 1, ("uigate: the Buy button (bottom %d) overlaps the strip (top %d) (#2912)"):format(b.AbsolutePosition.Y + b.AbsoluteSize.Y, s.AbsolutePosition.Y))
		UI.update({ money = 100 } :: any)
		assert(not b.Visible, "uigate: the Buy button shows with 100 coins for a 150 table (#2912)")
		UI.update({ money = 850 } :: any)
	end },
	-- #2314 (Derek2: "also show big arrow on screen temporarily pointing toward what to click next"): step 3's big
	-- arrow points at the HUD's Upgrades tile, whole on screen and off the tile; with Upgrades open it moves to the
	-- table row; the step done, it is gone
	{ "TutorialArrow", function()
		tutorialArrowStep()
		local tile = UIShim.playerGui:FindFirstChild("CatCafeHUD"):FindFirstChild("Upgrades", true)
		assertArrowAt(tile:FindFirstChild("TutorialGlow", true).Parent :: GuiObject, "the Upgrades tile")
		-- #3153 (Derek2: "the one pointing to upgrades randomly disapears"): still there long after the step began
		UIShim.advance(10)
		assertArrowAt(tile:FindFirstChild("TutorialGlow", true).Parent :: GuiObject, "the Upgrades tile, 10 s on")
		-- #3153 (Derek2: "your screen should darken"): the spotlight darkens round the tile and leaves it clear
		local spot = tutorialSpotlight()
		assert(spot, "uigate: no spotlight round the Upgrades tile (#3153)")
		local face = tile:FindFirstChild("TutorialGlow", true).Parent :: GuiObject
		local centre = face.AbsolutePosition + face.AbsoluteSize / 2
		for _, box in (spot :: Frame):GetChildren() do
			if box:IsA("Frame") then
				local b0, b1 = box.AbsolutePosition, box.AbsolutePosition + box.AbsoluteSize
				assert(
					not (centre.X > b0.X and centre.X < b1.X and centre.Y > b0.Y and centre.Y < b1.Y),
					"uigate: the spotlight darkens the Upgrades tile itself (#3153)"
				)
				assert(box.BackgroundTransparency < 1, "uigate: the spotlight does not darken (#3153)")
				assert(not box.Active, "uigate: the spotlight would take taps (#3153)")
			end
		end
	end },
	{ "TutorialArrowRow", function()
		tutorialArrowStep()
		UI.open("Upgrades")
		task.wait(0.2) -- the list scrolls the table row into view
		local window = UIShim.playerGui:FindFirstChild("CatCafeModals"):FindFirstChild("Upgrades", true)
		assertArrowAt(window:FindFirstChild("tables", true) :: GuiObject, "the table row")
	end },
	-- #2697 (Derek2: "make it insanely clear what to click with arrows and flashing highlights around buttons"): step
	-- 2 with a resting cat rings the HUD's Cats tile, then Equip Best inside Cats, each with the big arrow at it
	{ "TutorialJob", function()
		stepTwoResting()
		local tile = UIShim.playerGui:FindFirstChild("CatCafeHUD"):FindFirstChild("Cats", true)
		local glow = tile and tile:FindFirstChild("TutorialGlow", true)
		assert(glow, "uigate: the Cats tile does not ring at step 2 with a resting cat (#2697)")
		assertArrowAt(glow.Parent :: GuiObject, "the Cats tile")
	end },
	{ "TutorialJobEquip", function()
		stepTwoResting()
		UI.open("Cats")
		task.wait(0.1)
		-- Decor has an Equip Best too: the one in a shown window
		local glow: Instance? = nil
		for _, piece in UIShim.playerGui:FindFirstChild("CatCafeModals"):GetDescendants() do
			if piece.Name == "EquipBest" and piece:IsA("GuiObject") and piece.AbsoluteSize.X > 0 then
				local ring = piece:FindFirstChild("TutorialGlow", true)
				local shown = true
				local node: Instance? = piece
				while node and node:IsA("GuiObject") do
					shown = shown and (node :: GuiObject).Visible
					node = node.Parent
				end
				if shown then
					glow = ring
					assert(ring, "uigate: Equip Best does not ring at step 2 with a resting cat (#2697)")
				end
			end
		end
		assert(glow, "uigate: no Equip Best on screen in Cats (#2697)")
		assertArrowAt((glow :: Instance).Parent :: GuiObject, "Equip Best")
	end },
	-- #2697: step 4 with the bowl owned and empty rings the HUD's Bowl tile, then the Kibble row's Use
	{ "TutorialFood", function()
		stepFourFood()
		local tile = UIShim.playerGui:FindFirstChild("CatCafeHUD"):FindFirstChild("Bowl", true)
		local glow = tile and tile:FindFirstChild("TutorialGlow", true)
		assert(glow, "uigate: the Bowl tile does not ring at the food step (#2697)")
		local cats = UIShim.playerGui:FindFirstChild("CatCafeHUD"):FindFirstChild("Cats", true)
		assert(cats:FindFirstChild("TutorialGlow", true) == nil, "uigate: the Cats tile rings at the food step (#2697)")
	end },
	-- #3285 (Derek2: "turn off the dimming and arrow for foodbowl after they put the food inside it"): once the bowl
	-- holds food the step waits for the cat, so the Bowl tile's ring, its arrow and the dim all go
	{ "TutorialFoodIn", function()
		stepFourFood()
		local tile = UIShim.playerGui:FindFirstChild("CatCafeHUD"):FindFirstChild("Bowl", true)
		assert(tile and tile:FindFirstChild("TutorialGlow", true), "uigate: the Bowl tile does not ring at the food step (#2697)")
		local now = os.time()
		UI.update({ bait = { lureId = "kibble", placedAt = now, readyAt = now + 5 } } :: any)
		task.wait(0.2)
		assert(tile:FindFirstChild("TutorialGlow", true) == nil, "uigate: the Bowl tile still rings with food in the bowl (#3285)")
		assert(tutorialSpotlight() == nil, "uigate: the screen still dims with food in the bowl (#3285)")
		local line = UI.tutorial.hint(UI.getState())
		assert(line == "A cat is on its way to your bowl", ("uigate: the food step's strip says %q with food in the bowl (#3285)"):format(tostring(line)))
		UI.update({ bait = false } :: any)
	end },
	{ "TutorialFoodUse", function()
		stepFourFood()
		UI.bait.openPicker()
		task.wait(0.2)
		local window = baitWindow()
		local rings = {}
		for _, piece in window:GetDescendants() do
			if piece.Name == "TutorialGlow" then
				table.insert(rings, piece)
			end
		end
		assert(#rings == 1, ("uigate: %d rings in the bowl window at the food step, wants the Kibble row's Use (#2697)"):format(#rings))
		local use = rings[1].Parent :: GuiObject
		assertArrowAt(use, "the Kibble row's Use")
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
		-- #3154: the tutorial's end moves the arrow to the Tutorial tile's ×, which is not the Upgrades tile
		local tile = UIShim.playerGui:FindFirstChild("CatCafeHUD"):FindFirstChild("Upgrades", true) :: GuiObject
		local t0, t1 = tile.AbsolutePosition, tile.AbsolutePosition + tile.AbsoluteSize
		for _, piece in UIShim.playerGui:GetDescendants() do
			if piece.Name == "TutorialArrow" and piece:IsA("GuiObject") and piece.Visible then
				local a0, a1 = piece.AbsolutePosition, piece.AbsolutePosition + piece.AbsoluteSize
				local gap = math.max(t0.X - a1.X, a0.X - t1.X, t0.Y - a1.Y, a0.Y - t1.Y)
				assert(gap > 40, "uigate: the tutorial arrow stays at Upgrades after its step (#2314)")
			end
		end
		-- #3154: let the × pulse this step starts (6 s on, 12 s long) run out, so its arrow never stands in for the
		-- goal card's in the scenes after this one
		UIShim.advance(20)
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
	-- #2714 (Derek2 11-09: "let you shrink down your goal so they have more screen space"): on touch the ▶ button folds the
	-- goal card into one finger-tall chip and saves goalFolded; a tap on the chip opens it again. Desktop has no tab.
	{ "GoalFolded", function()
		local goal = UIShim.playerGui:FindFirstChild("TierGoal", true) :: GuiObject
		local fold = goal:FindFirstChild("Fold") :: GuiObject
		local touch = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Scale").isTouch()
		if not touch then
			assert(not fold.Visible, "uigate: a fold tab on the goal card on desktop (#2714)")
			return
		end
		local saved = {}
		local watch = UI.events.setSetting:Connect(function(key, value)
			table.insert(saved, tostring(key) .. "=" .. tostring(value))
		end)
		local tall = goal.AbsoluteSize.Y
		assert(fold.Visible, "uigate: no fold tab on the goal card on touch (#2714)")
		-- #2828 (Derek2: "set it to be one of the white arrows like the rest"): the HUD's white arrow button, its size
		local arrow = fold:FindFirstChild("Label", true) :: TextLabel?
		local menuFold = UIShim.playerGui:FindFirstChild("MenuFold", true) :: GuiObject?
		assert(arrow and arrow.Text == "▶", "uigate: the goal card's fold button is not the white ▶ arrow (#2828)")
		assert(menuFold == nil or (fold.AbsoluteSize - menuFold.AbsoluteSize).Magnitude < 1, ("uigate: the goal fold button is %dx%d, the menu's %dx%d (#2828)"):format(fold.AbsoluteSize.X, fold.AbsoluteSize.Y, menuFold and menuFold.AbsoluteSize.X or 0, menuFold and menuFold.AbsoluteSize.Y or 0))
		assert(fold.AbsolutePosition.X + fold.AbsoluteSize.X <= goal.AbsolutePosition.X + 0.5, "uigate: the goal fold button covers the card (#2828)")
		assert(fold.AbsolutePosition.X >= 0, "uigate: the goal fold button is off screen (#2828)")
		press("TierGoal", "Fold")
		task.wait(0.1)
		assert(goal.AbsoluteSize.Y < tall * 0.6, ("uigate: the folded goal card is %d px tall, was %d (#2714)"):format(goal.AbsoluteSize.Y, tall))
		local title = goal:FindFirstChild("Title") :: TextLabel
		assert(title.Visible and title.TextFits and string.find(title.Text, "🏆", 1, true), "uigate: the folded chip reads " .. title.Text .. " (#2714)")
		assert(#saved == 1 and saved[1] == "goalFolded=true", "uigate: folding saved " .. table.concat(saved, ", ") .. " (#2714)")
		Scenes._goalFolded = true -- Scenes.close opens it again
		watch:Disconnect()
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
	-- #3022 (Derek2 11-10: "make it obvious to go catch second cat to earn more money and progress 'your goal'"): from
	-- the first customer served the goal card reads "Catch a 2nd cat" under the gold YOUR GOAL line, with the server's
	-- numbers: a new Tier 1 cafe has both jobs taken, so the wide card's money line names the new-cat bonus and never
	-- "2x". Two preview lines show under it for 6 s, once. No bars and no Rank up! sticker.
	-- #3554: on the way to a first Park catch the goal card reads "Visit the Park 🐾", then "Catch a Park cat 🐾",
	-- with no requirement bars under it, and goes back to the tier goal after
	{ "ParkGoal", function()
		local goal = UIShim.playerGui:FindFirstChild("TierGoal", true) :: GuiObject
		local title = goal:FindFirstChild("Title") :: TextLabel
		-- a ready rank up comes before any goal, so the cafe is short of money for the next tier here
		local before: any = UI.getState()
		Scenes._parkGoal = { money = before.money }
		UI.update({ money = 0 } :: any)
		UIShim.advance(0.1)
		local tierTitle = title.Text
		for _, words in { "Catch a Park cat 🐾", "Visit the Park 🐾" } do
			UI.parkTrail.set(nil, words)
			UIShim.advance(0.1)
			assert(goal.Visible, "uigate: no goal card on the way to the Park (#3554)")
			assert(title.Visible and title.Text == words, "uigate: the Park goal reads " .. title.Text .. " (#3554)")
			assert(title.TextFits, "uigate: " .. words .. " does not fit the goal card (#3554)")
			for index = 1, 3 do
				local row = goal:FindFirstChild("Row" .. index) :: GuiObject
				assert(not row.Visible, "uigate: a requirement bar under the Park goal (#3554)")
			end
		end
		UI.parkTrail.set(nil, nil)
		UIShim.advance(0.1)
		assert(title.Text == tierTitle, "uigate: the goal card kept the Park goal, it reads " .. title.Text .. " (#3554)")
		UI.parkTrail.set(nil, "Visit the Park 🐾") -- the picture
		UIShim.advance(0.1)
	end },
	-- #3558: one menu look for a whole session. The switch flipping after the UI was built changes nothing here, so no
	-- window can end up with cream cards under white words; the flip reaches a player at their next join.
	{ "MenuFamilyLatch", function()
		local MenuFamily = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Components.MenuFamily")
		local RS = game:GetService("ReplicatedStorage")
		local name = "LiveFlag_" .. MenuFamily.FLAG
		local was = RS:GetAttribute(name)
		local on = MenuFamily.on()
		local card = MenuFamily.card.card
		RS:SetAttribute(name, not on)
		assert(MenuFamily.on() == on, "uigate: the menu look followed a mid-session switch flip (#3558)")
		assert(MenuFamily.card.card == card, "uigate: the card colour followed a mid-session switch flip (#3558)")
		RS:SetAttribute(name, was)
		UI.open("Quests")
	end },
	-- #3555: the first rank up's walk-through: the goal card lit with "You can rank up!", then the rank up window's
	-- button with "Press to rank up", and a press on the dim tells the caller. Nothing is left once it is closed.
	{ "RankSpotlight", function()
		local SpotlightGuide = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Components.SpotlightGuide")
		local rankSpot: any = UI.rankSpot
		local function caption(): TextLabel?
			return UIShim.playerGui:FindFirstChild(SpotlightGuide.CAPTION, true) :: TextLabel?
		end
		local free, window = rankSpot.moment()
		assert(free and window == nil, "uigate: the walk-through's moment is not free on a plain HUD (#3555)")
		assert(rankSpot.set("button", "You can rank up!", nil), "uigate: no goal card to light (#3555)")
		UIShim.advance(0.2)
		local words = caption()
		assert(words ~= nil and words.Visible, "uigate: no words by the lit goal card (#3555)")
		assert(words.Text == "You can rank up!" and words.TextFits, "uigate: the goal card's words do not fit (#3555)")
		rankSpot.set("none")
		UIShim.advance(0.1)
		assert(caption() == nil, "uigate: the walk-through's words stayed after it closed (#3555)")
		UI.open("RankUp")
		UIShim.advance(0.5)
		local _, open = rankSpot.moment()
		assert(open == "RankUp", "uigate: the moment does not name the rank up window (#3555)")
		assert(rankSpot.set("confirm", "Press to rank up", nil), "uigate: no rank up button to light (#3555)")
		UIShim.advance(0.2)
		words = caption()
		assert(words ~= nil and words.Visible, "uigate: no words by the lit rank up button (#3555)")
		assert(words.Text == "Press to rank up" and words.TextFits, "uigate: the button's words do not fit (#3555)")
		local screen = (words:FindFirstAncestorOfClass("ScreenGui") :: ScreenGui).AbsoluteSize
		assert(
			words.AbsolutePosition.X >= 0
				and words.AbsolutePosition.Y >= 0
				and words.AbsolutePosition.X + words.AbsoluteSize.X <= screen.X
				and words.AbsolutePosition.Y + words.AbsoluteSize.Y <= screen.Y,
			"uigate: the walk-through's words run off the screen (#3555)"
		)
		Scenes._rankSpot = true
	end },
	{ "SecondCatGoal", function()
		local Scale = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Scale")
		local touch = Scale.isTouch()
		-- (UIShim.advance all through, never task.wait: the 6 s below outruns the runner's own clock, and a wait after
		-- it would only come back once the picture is taken)
		local before: any = UI.getState()
		Scenes._secondCat = { tier = before.tier, money = before.money, tutorialStep = before.tutorialStep }
		UI.update({ tier = 1, tutorialStep = 3, money = 120, secondCat = { now = 2.5, with = 2.5, cats = 1, bonus = 50 } } :: any)
		UIShim.advance(0.1)
		local goal = UIShim.playerGui:FindFirstChild("TierGoal", true) :: GuiObject
		assert(goal.Visible, "uigate: no goal card for the second cat (#3022)")
		local line = goal:FindFirstChild("Goal") :: TextLabel
		assert(line.Visible and line.Text == "🏆 YOUR GOAL", "uigate: the second cat goal has no YOUR GOAL line (#3022)")
		local title = goal:FindFirstChild("Title") :: TextLabel
		local expected = "Catch a 2nd cat 🐾 1/2"
		assert(title.Visible and title.Text == expected, "uigate: the second cat goal reads " .. title.Text .. " (#3022)")
		assert(title.TextFits, "uigate: the second cat goal does not fit its card (#3022)")
		assert(not (goal:FindFirstChild("RankReady") :: GuiObject).Visible, "uigate: a Rank up! sticker on the second cat goal (#3022)")
		for index = 1, 3 do
			local row = goal:FindFirstChild("Row" .. index) :: GuiObject
			assert(not row.Visible, "uigate: a requirement bar under the second cat goal (#3022)")
		end
		-- the lines under the title, top down: a wide card's money line (it stays), then the two preview lines
		local function shownLines(): { TextLabel }
			local out = {}
			for index = 1, 3 do
				local label = goal:FindFirstChild("GoalLine" .. index) :: TextLabel
				if label.Visible then
					table.insert(out, label)
				end
			end
			return out
		end
		local function texts(labels: { TextLabel }): string
			local out = {}
			for _, label in labels do
				table.insert(out, label.Text)
			end
			return table.concat(out, " | ")
		end
		local lines = shownLines()
		local hook = if touch then 0 else 1
		-- #3155 (Derek2: "remove the pop ups for cat progress towards your goal at start"): no preview lines, only the
		-- wide card's money line
		assert(#lines == hook, "uigate: the second cat goal shows " .. texts(lines) .. " (#3155)")
		if not touch then
			assert(lines[1].Text == "New cats pay +$50 💰", "uigate: the second cat goal's money line reads " .. lines[1].Text .. " (#3022)")
		end
		local bottom = goal.AbsolutePosition.Y + goal.AbsoluteSize.Y
		for _, label in lines do
			assert(not string.find(label.Text, "2x", 1, true), "uigate: the second cat goal says 2x with both jobs taken (#3022)")
			assert(label.TextFits, "uigate: the second cat goal's line does not fit the card: " .. label.Text .. " (#3022)")
			assert(label.AbsolutePosition.Y + label.AbsoluteSize.Y <= bottom + 0.5, "uigate: the second cat goal's lines run out of the card (#3022)")
		end
		local tall = goal.AbsoluteSize.Y
		-- the money line stays
		UIShim.advance(6.3)
		lines = shownLines()
		assert(#lines == hook, "uigate: the second cat goal's lines changed: " .. texts(lines) .. " (#3022)")
		assert(goal.AbsoluteSize.Y <= tall, "uigate: the second cat goal grew (#3022)")
		assert(title.Visible and title.Text == expected, "uigate: the second cat goal went (#3022)")
		-- a job really free, the server's two rates: only then "2x" (the wide card's money line)
		UI.update({ secondCat = { now = 1.5, with = 3, cats = 1, bonus = 50 } } :: any)
		UIShim.advance(0.1)
		if not touch then
			lines = shownLines()
			assert(#lines == 1 and lines[1].Text == "2 cats earn 2x 💰", "uigate: with a free job the goal's money line reads " .. texts(lines) .. " (#3022)")
		end
		-- #3238: dusk shuts the areas, and the card says when the strays come back, on a phone too
		UI.clock.setAreasOpen(false)
		UIShim.advance(0.1)
		lines = shownLines()
		local night = if touch then "Next cat at sunrise 🌅" else "Strays come back at sunrise 🌅"
		assert(#lines == 1 and lines[1].Text == night, "uigate: at night the second cat goal reads " .. texts(lines) .. " (#3238)")
		assert(lines[1].TextFits, "uigate: the night line does not fit its width (#3238) " .. tostring(lines[1].AbsoluteSize))
		assert(lines[1].AbsolutePosition.Y + lines[1].AbsoluteSize.Y <= goal.AbsolutePosition.Y + goal.AbsoluteSize.Y + 0.5, "uigate: the night line runs out of the card (#3238)")
		assert(title.Text == expected, "uigate: the second cat goal's title changed at night (#3238)")
		UI.clock.setAreasOpen(true)
		UIShim.advance(0.1)
		-- the second cat is in: the tier goal is back
		UI.update({ secondCat = false } :: any)
		UIShim.advance(0.1)
		assert(not string.find(title.Text, "2nd cat", 1, true), "uigate: the goal card still asks for a 2nd cat after it (#3022)")
		assert(#shownLines() == 0, "uigate: the second cat goal's lines stayed on the tier goal (#3022)")
		assert((goal:FindFirstChild("Row1") :: GuiObject).Visible, "uigate: the tier goal's bars did not come back after the second cat (#3022)")
		-- back for the picture
		UI.update({ secondCat = { now = 2.5, with = 2.5, cats = 1, bonus = 50 } } :: any)
		UIShim.advance(0.1)
		lines = shownLines()
		assert(title.Text == expected and #lines == hook, "uigate: the second cat goal did not come back: " .. title.Text .. " | " .. texts(lines) .. " (#3022)")
		if not touch then
			assert(lines[1].Text == "New cats pay +$50 💰", "uigate: the second cat goal's money line came back as " .. lines[1].Text .. " (#3022)")
		end
	end },
	-- #2912: after the first bait cat the goal card reads "Free a stuck cat" until the first rescue starts; at night it
	-- says when the stuck cats come back; the tier goal returns after.
	{ "StuckCatGoal", function()
		local before: any = UI.getState()
		Scenes._secondCat = Scenes._secondCat or { tier = before.tier, money = before.money, tutorialStep = before.tutorialStep }
		UI.update({ tier = 1, tutorialStep = 5, money = 120, secondCat = false, stuckGoal = true } :: any)
		UIShim.advance(0.1)
		local goal = UIShim.playerGui:FindFirstChild("TierGoal", true) :: GuiObject
		assert(goal.Visible, "uigate: no goal card for the stuck cat (#2912)")
		local title = goal:FindFirstChild("Title") :: TextLabel
		local expected = "Free a stuck cat 🐾"
		assert(title.Visible and title.Text == expected, "uigate: the stuck cat goal reads " .. title.Text .. " (#2912)")
		assert(title.TextFits, "uigate: the stuck cat goal does not fit its card (#2912)")
		assert(not (goal:FindFirstChild("RankReady") :: GuiObject).Visible, "uigate: a Rank up! sticker on the stuck cat goal (#2912)")
		local function night(): TextLabel?
			for _, piece in goal:GetDescendants() do
				if piece:IsA("TextLabel") and piece.Visible and string.find(piece.Text, "at sunrise 🌅", 1, true) then
					return piece
				end
			end
			return nil
		end
		assert(night() == nil, "uigate: the stuck cat goal's night line shows by day (#2912)")
		UI.clock.setAreasOpen(false)
		UIShim.advance(0.1)
		local line = night()
		assert(line ~= nil, "uigate: at night the stuck cat goal has no sunrise line (#2912)")
		assert((line :: TextLabel).TextFits, "uigate: the stuck cat goal's night line does not fit (#2912)")
		assert(title.Text == expected, "uigate: the stuck cat goal's title changed at night (#2912)")
		UI.clock.setAreasOpen(true)
		UIShim.advance(0.1)
		UI.update({ stuckGoal = false } :: any)
		UIShim.advance(0.1)
		assert(title.Text ~= expected, "uigate: the goal card still asks for a stuck cat after it (#2912)")
		UI.update({ stuckGoal = true } :: any) -- back for the picture
		UIShim.advance(0.1)
		assert(title.Text == expected, "uigate: the stuck cat goal did not come back (#2912)")
	end },
	-- #3529: while five different cats is the goal the card reads "Catch new kinds of cat 3/5", and the catch card
	-- says "New kind! 3/5 for Cozy Cafe" for a kind the player has never owned
	{ "NewKindGoal", function()
		local before: any = UI.getState()
		Scenes._secondCat = Scenes._secondCat or { tier = before.tier, money = before.money, tutorialStep = before.tutorialStep }
		UI.update({ tier = 1, tutorialStep = 5, money = 120, secondCat = false, stuckGoal = false, newKindGoal = 3 } :: any)
		UIShim.advance(0.1)
		local goal = UIShim.playerGui:FindFirstChild("TierGoal", true) :: GuiObject
		assert(goal.Visible, "uigate: no goal card for new kinds (#3529)")
		local title = goal:FindFirstChild("Title") :: TextLabel
		local expected = "Catch new kinds of cat 🐾 3/5"
		if title.Text == "New kinds of cat 🐾 3/5" then
			expected = title.Text -- the phone's narrower card
		end
		assert(title.Visible and title.Text == expected, "uigate: the new kinds goal reads " .. title.Text .. " (#3529)")
		assert(title.TextFits, "uigate: the new kinds goal does not fit its card (#3529)")
		-- the stuck cat goal wins while both are set
		UI.update({ stuckGoal = true } :: any)
		UIShim.advance(0.1)
		assert(title.Text == "Free a stuck cat 🐾", "uigate: the new kinds goal beat the stuck cat goal (#3529)")
		UI.update({ stuckGoal = false } :: any)
		UIShim.advance(0.1)
		assert(title.Text == expected, "uigate: the new kinds goal did not come back (#3529)")
		UI.update({ newKindGoal = false } :: any)
		UIShim.advance(0.1)
		assert(title.Text ~= expected, "uigate: the goal card still asks for new kinds after it (#3529)")
		UI.update({ newKindGoal = 3 } :: any) -- back for the picture
		UIShim.advance(0.1)
		-- the catch card's line
		UI.catch.show({ strayId = "gate_new", catId = Catalog.cats[2].id, catName = "Mochi", rarity = "Rare", newKind = "New kind! 3/5 for Cozy Cafe" } :: any)
		UIShim.advance(0.3)
		local prompt = UIShim.playerGui:FindFirstChild("Hint", true) :: TextLabel
		local hint: TextLabel? = nil
		for _, piece in UIShim.playerGui:GetDescendants() do
			if piece:IsA("TextLabel") and piece.Name == "Hint" and piece.Text == "New kind! 3/5 for Cozy Cafe" then
				hint = piece
			end
		end
		assert(prompt ~= nil and hint ~= nil, "uigate: the catch card has no New kind line (#3529)")
		assert((hint :: TextLabel).Visible and (hint :: TextLabel).TextFits, "uigate: the New kind line is hidden or does not fit (#3529)")
		UI.catch.show({ strayId = "gate_new", catId = Catalog.cats[2].id, catName = "Mochi", rarity = "Rare" } :: any)
		UIShim.advance(0.1)
		assert(not (hint :: TextLabel).Visible, "uigate: a repeat kind still shows the New kind line (#3529)")
		UI.catch.show({ strayId = "gate_new", catId = Catalog.cats[2].id, catName = "Mochi", rarity = "Rare", newKind = "New kind! 3/5 for Cozy Cafe" } :: any)
		UIShim.advance(0.3)
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
		UIShim.advance(18.5) -- #3154: a 6 s wait and a 12 s pulse; the scene before may leave the tutorial mid-way, which this update just finished
		UI.update({ tutorialStep = 9 } :: any)
		assert(dot:FindFirstChild("PulseRing") == nil, "uigate: the × pulses with no tutorial step done (#2211)")
		UI.update({ tutorialStep = 4 } :: any)
		UI.update({ tutorialStep = 9 } :: any)
		UIShim.advance(5.5)
		assert(dot:FindFirstChild("PulseRing") == nil, "uigate: the × pulses before the cat card and the cannon move (#3154)")
		UIShim.advance(0.7) -- #3154: 6 s after the tutorial's end
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
		-- #3154 (Derek2: "make the tutorial X closing way more obvious on tutorial finish"): the big arrow points at the
		-- ×, off the Hide tips tag, with the spotlight round it
		assertArrowAt(dot.Parent :: GuiObject, "the Tutorial tile's ×")
		-- #3638 (Derek 2026-11-12: "no need to force them to close tips and darken screen just show the x for a bit"):
		-- the arrow, ring and tag only, the screen is not darkened, and it is over in 6 s
		assert(tutorialSpotlight() == nil, "uigate: the screen darkens round the Tutorial tile's × (#3638)")
		local across = (dot :: GuiObject).AbsoluteSize.X
		assert(across >= 21 - 0.5, ("uigate: the Tutorial tile's × is %.1f px across (#2411)"):format(across))
		UIShim.advance(5.2) -- #3638: the pulse lasts 6 s (1 s of it gone above)
		assert(dot:FindFirstChild("PulseRing") == nil, "uigate: the ×'s pulse does not end (#2411)")
		assert(dot:FindFirstChild("Pulse") == nil, "uigate: the ×'s bounce does not end (#2211)")
		assert(hint() == nil, "uigate: the Hide tips tag does not go (#2411)")
		-- #2411: a tutorial that ends with the HUD off the screen (a cut, a cutscene) pulses once it is back
		UI.setVisible(false)
		UI.update({ tutorialStep = 4 } :: any)
		UI.update({ tutorialStep = 9 } :: any)
		UIShim.advance(7) -- #3154: past the 6 s wait
		assert(dot:FindFirstChild("PulseRing") == nil, "uigate: the × pulsed with the HUD hidden (#2411)")
		UI.setVisible(true)
		UIShim.advance(0.5)
		assert(dot:FindFirstChild("PulseRing"), "uigate: the × did not pulse once the HUD came back (#2411)")
		UIShim.advance(12.5) -- #3154: the pulse lasts 12 s
		UI.update({ tutorialStep = 4 } :: any)
		UI.update({ tutorialStep = 9 } :: any) -- again, for the picture
		UIShim.advance(7.5) -- #3154: the 6 s wait, then the icon row settles
	end },
	-- F87 section 2g: "Need a hand?" after 90 s on one tutorial step
	{ "HelpCard", function()
		UI.tutorial.showHelp()
	end },
	{ "CatFound", function()
		UI.showCatFound(Catalog.cats[2].id, true)
	end },
	-- #2833 (Derek2: "only do the double pop-up if its a legendary+ or any new cat"): a repeat Common catch gets no big
	-- card and (#2844) no toast; a repeat Legendary still gets the card
	{ "CatFoundRepeat", function()
		local common, legendary = nil, nil
		for _, def in Catalog.cats do
			if common == nil and def.rarity == "Common" then
				common = def
			elseif legendary == nil and def.rarity == "Legendary" then
				legendary = def
			end
		end
		assert(common and legendary, "uigate: no Common or Legendary cat in the catalog (#2833)")
		local popupsGui = UIShim.playerGui:FindFirstChild("CatCafePopups")
		local card = popupsGui and popupsGui:FindFirstChild("CatFound", true) :: GuiObject?
		assert(card ~= nil, "uigate: no cat found card (#2833)")
		local function shown(): boolean
			local at: Instance? = card
			while at and not at:IsA("PlayerGui") do
				if (at:IsA("GuiObject") and not at.Visible) or (at:IsA("ScreenGui") and not at.Enabled) then
					return false
				end
				at = at.Parent
			end
			return true
		end
		UI.showCatFound(common.id, false, { charmGain = 2 })
		UIShim.advance(0.3)
		assert(not shown(), "uigate: a repeat Common catch opened the big card (#2833)")
		-- #2844: and no "joined your cafe" toast either
		for _, label in UIShim.playerGui:GetDescendants() do
			if label:IsA("TextLabel") and string.find(label.Text, "joined your cafe", 1, true) then
				error("uigate: a repeat Common catch still shows a joined your cafe toast (#2844)")
			end
		end
		UI.showCatFound(legendary.id, false)
		UIShim.advance(0.3)
		assert(shown(), "uigate: a repeat Legendary catch did not open the big card (#2833)")
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
	-- #2827 (Derek2 11-09: "fully hide that active potions bubble (people can just look in bag if they care)"): four
	-- potions running and no potion chip, folded or not, on any device; the Luck and pal row is not this one
	{ "HUDPotionsHidden", function()
		local t = workspace:GetServerTimeNow()
		UI.update({
			buffs = { tip_potion = t + 492, swift_potion = t + 130, lucky_potion = t + 492, steady_potion = t + 300 },
		})
		UIShim.advance(1.2) -- past a tick
		local timers = UIShim.playerGui:FindFirstChild("PotionTimers", true) :: GuiObject?
		assert(timers == nil or not timers.Visible, "uigate: the potion chip still shows (#2827)")
		local count = timers and timers:FindFirstChild("Count", true) :: TextLabel?
		assert(count == nil or count.Text == "" or count.Text == "x0", "uigate: the hidden potion row still counts (#2827)")
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
		assert(bag == "rbxassetid://118552497512285", "uigate: the Bag tile is not Model-Agent's backpack (#2453)")
		assert(bag ~= ShopIcons.hud("Potion"), "uigate: the Bag tile shows the Potions bottle (#2453)")
		-- #2866: its only backup is the group's earlier backpack, never a bottle or the money bag
		assert(ShopIcons.backup(bag) == "rbxassetid://88244676943674", "uigate: the Bag's backpack does not fall back to the earlier backpack (#2866)")
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
	-- #3082: every opened station's strip has a button, so nobody has to fly there: Collect on the Park's waiting
	-- basket (in place of the dot), Open on the Neighbourhood's Yard Sale, which brings up its card
	{ "CannonExtras", function()
		atTier(3) -- the Park and the Neighbourhood are open
		UI.campExtras.update(campExtras(1, false))
		UI.cannon.open()
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local window = modals and modals:FindFirstChild("Cannon", true)
		assert(window, "uigate: no Cannon window")
		local function button(areaId: string): TextButton?
			local card = window:FindFirstChild(areaId, true)
			local found = card and card:FindFirstChild("Collect", true)
			return if found and found:IsA("GuiObject") and found.Visible then found else nil
		end
		local function word(holder: Instance): string
			for _, piece in holder:GetDescendants() do
				if piece:IsA("TextLabel") and piece.Text ~= "" then
					return piece.Text
				end
			end
			return if holder:IsA("TextButton") then holder.Text else ""
		end
		local park, yard = button("park"), button("neighbourhood")
		assert(park and word(park) == "Collect", "uigate: no Collect on the Park's waiting Picnic Basket (#3082)")
		assert(yard and word(yard) == "Open", "uigate: no Open on the Neighbourhood's Yard Sale strip (#3082)")
	end },
	-- #3082: Open on the Yard Sale strip puts the Yard Sale's card up in the picker's place
	{ "CannonOpensStation", function()
		atTier(3)
		UI.campExtras.update(campExtras(1, false))
		UI.cannon.open()
		press("Cannon", "neighbourhood.Collect")
		task.wait(0.4)
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local yard = modals and modals:FindFirstChild("YardSale", true)
		assert(yard and yard:IsA("GuiObject") and yard.Visible, "uigate: Open did not bring up the Yard Sale card (#3082)")
	end },
	-- F100: the same picker with nothing ready: "Next in 2 h 10 m" and "New crates in 3 h"
	{ "CannonExtrasWait", function()
		atTier(3)
		UI.campExtras.update(campExtras(0, true))
		UI.cannon.open()
	end },
	-- #3082: the Desert card's Oasis Spa strip has Open, which brings up the spa's card from anywhere
	{ "CannonOpensSpa", function()
		atTier(6) -- the Desert (and its spa) open at Tier 6; Scenes.close puts the tier back
		UI.lateStations.update(lateState(3 * 3600 + 600))
		UI.cannon.open()
		press("Cannon", "desert.Collect")
		task.wait(0.4)
		assert(UI.isOpen() == "OasisSpa", "uigate: Open on the Desert strip opened " .. tostring(UI.isOpen()) .. " (#3082)")
	end },
	-- #3082: 14 fish in the pond: Collect on the Woods strip in place of the red dot, for every player (#1463 had it
	-- for a Golden Pond owner; the pass doubles the fish instead, #3093)
	{ "CannonPondCollect", function()
		local extras = campExtras(0, true)
		extras.pond = { open = true, held = 14 }
		atTier(4) -- the Woods (and its pond) open at Tier 4; Scenes.close puts the tier back
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
		assert(shown, "uigate: no Collect on the pond strip (#3082)")
	end },
	-- #3715: Picnic Treats (the `picnicTreats` switch): the Picnic Basket's pick card with a pick waiting. Three
	-- treats, each with its potion and a Pick button, and nothing that reads as a sale or a roll
	{ "PicnicTreats", function()
		atTier(2)
		local extras = campExtras(1, true)
		extras.picnic = { open = true, held = 1, treats = { "sandwich", "lemonade", "cupcake" } }
		UI.campExtras.update(extras)
		UI.campExtras.openPicnic()
		assert(UI.isOpen() == "PicnicTreats", "uigate: the Picnic Treats card did not open (#3715)")
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local card = modals and modals:FindFirstChild("PicnicTreats", true)
		assert(card, "uigate: no Picnic Treats card (#3715)")
		local status = card:FindFirstChild("Status", true)
		assert(status and status.Text == "Pick one treat.", "uigate: the Picnic Treats line reads " .. tostring(status and status.Text) .. " (#3715)")
		local gives = {}
		for _, id in { "sandwich", "lemonade", "cupcake" } do
			local treat = card:FindFirstChild(id, true)
			assert(treat and treat:FindFirstChild("Pick", true), "uigate: no Pick on the " .. id .. " (#3715)")
			table.insert(gives, treat:FindFirstChild("Gives", true).Text)
		end
		assert(
			table.concat(gives, ", ") == "1 Money Potion, 1 Swift Potion, 1 Lucky Potion",
			"uigate: the treats give " .. table.concat(gives, ", ") .. " (#3715)"
		)
		for _, piece in card:GetDescendants() do
			if piece:IsA("TextLabel") or piece:IsA("TextButton") then
				local words = string.lower(piece.Text)
				for _, banned in { "robux", "buy", "sale", "hurry", "last chance", "spin", "lucky pick" } do
					assert(not string.find(words, banned, 1, true), "uigate: a word Picnic Treats must not use: " .. piece.Text)
				end
			end
		end
		-- Pick on the Lemonade asks the server for that treat and no other
		local asked = nil
		local connection = UI.events.pickPicnicTreat:Connect(function(treatId)
			asked = treatId
		end)
		press("PicnicTreats", "lemonade.Pick")
		connection:Disconnect()
		assert(asked == "lemonade", "uigate: Pick on the Lemonade asked for " .. tostring(asked) .. " (#3715)")
		-- the server's new state answers the pick: the wait line, the buttons off
		local after = campExtras(0, true)
		after.picnic = { open = true, held = 0, nextAt = workspace:GetServerTimeNow() + 4 * 3600, treats = { "sandwich", "lemonade", "cupcake" } }
		UI.campExtras.update(after)
		assert(string.find(status.Text, "Next picnic in", 1, true), "uigate: no wait line after a pick: " .. status.Text .. " (#3715)")
		asked = nil
		connection = UI.events.pickPicnicTreat:Connect(function(treatId)
			asked = treatId
		end)
		pcall(press, "PicnicTreats", "cupcake.Pick")
		connection:Disconnect()
		assert(asked == nil, "uigate: a treat could be picked while none waits (#3715)")
		-- back to a waiting pick for the picture
		UI.campExtras.update(extras)
	end },
	-- #3715: the card with no pick waiting: "Next picnic in 3 h 12 min" and the three treats greyed
	{ "PicnicTreatsWait", function()
		atTier(2)
		local extras = campExtras(0, true)
		extras.picnic = { open = true, held = 0, nextAt = workspace:GetServerTimeNow() + 3 * 3600 + 12 * 60 - 20, treats = { "sandwich", "lemonade", "cupcake" } }
		UI.campExtras.update(extras)
		UI.campExtras.openPicnic()
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local card = modals and modals:FindFirstChild("PicnicTreats", true)
		local status = card and card:FindFirstChild("Status", true)
		assert(status and string.find(status.Text, "Next picnic in 3 h 12", 1, true), "uigate: the wait reads " .. tostring(status and status.Text) .. " (#3715)")
	end },
	-- #3715: with Picnic Treats on, the Park strip's button on the Cat Cannon opens the pick card and collects nothing
	{ "CannonOpensPicnic", function()
		atTier(3)
		local extras = campExtras(1, false)
		extras.picnic = { open = true, held = 1, treats = { "sandwich", "lemonade", "cupcake" } }
		UI.campExtras.update(extras)
		UI.cannon.open()
		local collected = false
		local connection = UI.events.collectCampExtra:Connect(function()
			collected = true
		end)
		press("Cannon", "park.Collect")
		connection:Disconnect()
		assert(not collected, "uigate: the Park strip collected the basket with Picnic Treats on (#3715)")
		assert(UI.isOpen() == "PicnicTreats", "uigate: the Park strip opened " .. tostring(UI.isOpen()) .. " (#3715)")
		-- the scenes after this one read the plain basket
		UI.campExtras.update(campExtras(1, false))
	end },
	-- F100: the Yard Sale card, the Classic Crate bought today and the Park Crate for 40 golden fish
	{ "YardSale", function()
		local extras = campExtras(0, false)
		extras.yardSale.stock[1].bought = true
		extras.yardSale.held = 1
		UI.campExtras.update(extras)
		UI.campExtras.openYardSale(extras.yardSale)
	end },
	-- #3953: today's crate still free: the wide card with its "FREE TODAY" pill, the odds as pills in view (no Odds
	-- button to find them behind) and the Take button
	{ "YardSaleFree", function()
		local extras = campExtras(0, false)
		UI.campExtras.update(extras)
		UI.campExtras.openYardSale(extras.yardSale)
		task.wait(0.2)
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local yard = modals and modals:FindFirstChild("YardSale", true)
		assert(yard, "uigate: no Yard Sale card (#3953)")
		local crates = yard:FindFirstChild("Crates", true)
		local card = crates and crates:FindFirstChildWhichIsA("Frame")
		assert(card, "uigate: no crate card on the Yard Sale (#3953)")
		local status = card:FindFirstChild("Status")
		assert(
			status and status:IsA("TextLabel") and status.Text == "FREE TODAY",
			"uigate: the Yard Sale crate has no FREE TODAY pill (#3953)"
		)
		assert(card:FindFirstChild("OddsSheet", true) == nil, "uigate: the Yard Sale still hides its odds on a sheet (#3953)")
		local odds = card:FindFirstChild("Odds", true)
		local pills = 0
		for _, pill in (if odds then odds:GetChildren() else {}) do
			if pill:IsA("TextLabel") and string.find(pill.Text, "%%") then
				pills += 1
			end
		end
		assert(pills >= 2, "uigate: the Yard Sale crate shows " .. pills .. " odds pills (#3953)")
	end },
	-- #3955: the Lost and Found's card with two finds waiting: the picture with its "2 WAITING" pill, what can turn
	-- up with chances, and Claim; pressing Claim sends CollectCampExtra("lostFound"), and the answer's reveal shows the
	-- find large on the card in place of a toast
	{ "LostFound", function()
		local extras = campExtras(0, false)
		extras.lostFound = { open = true, held = 2 }
		UI.campExtras.update(extras)
		UI.campExtras.openLostFound()
		task.wait(0.2)
		assert(UI.isOpen() == "LostFound", "uigate: the Lost and Found card did not open (#3955)")
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local card = modals and modals:FindFirstChild("LostFound", true)
		assert(card, "uigate: no Lost and Found card (#3955)")
		local status = card:FindFirstChild("Status", true) :: TextLabel
		assert(status and status.Text == "2 WAITING", "uigate: the Lost and Found pill reads " .. tostring(status and status.Text))
		local finds = card:FindFirstChild("Finds", true) :: Instance
		local tiles = 0
		for _, tile in finds:GetChildren() do
			if tile:IsA("Frame") then
				tiles += 1
			end
		end
		assert(tiles >= 5, "uigate: the Lost and Found shows " .. tiles .. " finds (#3955)")
		local sent: string? = nil
		local connection = UI.events.collectCampExtra:Connect(function(extraId: string)
			sent = extraId
		end)
		press("LostFound", "Claim")
		connection:Disconnect()
		assert(sent == "lostFound", "uigate: Claim sent " .. tostring(sent) .. " (#3955)")
	end },
	{ "LostFoundReveal", function()
		local extras = campExtras(0, false)
		extras.lostFound = { open = true, held = 1 }
		UI.campExtras.update(extras)
		UI.campExtras.openLostFound()
		task.wait(0.2)
		UI.campExtras.collected("lostFound", { "+25 golden fish" }, { fish = 25 })
		task.wait(0.1)
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local card = modals and modals:FindFirstChild("LostFound", true)
		local reveal = card and card:FindFirstChild("Reveal", true) :: GuiObject
		assert(reveal and reveal.Visible, "uigate: the Lost and Found find is not revealed on the card (#3955)")
		local words = reveal:FindFirstChild("Words") :: TextLabel
		assert(words and words.Text == "+25 golden fish", "uigate: the reveal reads " .. tostring(words and words.Text))
	end },
	{ "LostFoundWait", function()
		local extras = campExtras(0, false)
		extras.lostFound = { open = true, held = 0, nextAt = workspace:GetServerTimeNow() + 4800 }
		UI.campExtras.update(extras)
		UI.campExtras.openLostFound()
		task.wait(0.2)
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local card = modals and modals:FindFirstChild("LostFound", true)
		local title = card and card:FindFirstChild("Heading", true) :: TextLabel
		assert(title and title.Text == "Nothing found yet", "uigate: the empty Lost and Found reads " .. tostring(title and title.Text))
	end },
	-- #3615: the Yard Sale card as the lucky pick (the `yardSaleRoll` switch): the board with one row per crate a
	-- Tier 4 player can win, chances to one decimal, and the Lucky pick button
	{ "YardSalePick", function()
		local extras = yardPickExtras(4, false)
		UI.campExtras.update(extras)
		UI.campExtras.openYardSale(extras.yardSale)
		task.wait(0.3)
		local card = yardPickCard()
		local pick = card:FindFirstChild("Pick", true)
		assert(pick and pick.Visible, "uigate: the lucky pick is not on the Yard Sale card (#3615)")
		local crates = card:FindFirstChild("Crates", true)
		assert(crates and not crates.Visible, "uigate: the free crate card shows beside the lucky pick (#3615)")
		local rows, golden = 0, 0
		for _, piece in pick:GetDescendants() do
			if piece:GetAttribute("RowId") ~= nil then
				rows += 1
				local chance = piece:FindFirstChild("Chance")
				assert(chance and string.match(chance.Text, "^%d+%.%d%%$"), "uigate: a lucky pick row has no chance to one decimal (#3615)")
				if string.find(piece:GetAttribute("RowId"), "golden", 1, true) then
					golden += 1
				end
			end
		end
		assert(rows == #extras.yardSale.pick and golden >= 1, "uigate: the lucky pick board has " .. rows .. " rows (#3615)")
		for _, piece in card:GetDescendants() do
			if piece:IsA("TextLabel") or piece:IsA("TextButton") then
				local words = string.lower(piece.Text)
				assert(
					not string.find(words, "gamble", 1, true) and not string.find(words, "bet ", 1, true) and not string.find(words, "spin", 1, true),
					"uigate: a word the lucky pick must not use: " .. piece.Text
				)
			end
		end
	end },
	-- #3615: the pick taken: rows dimmed, "Next pick in 1 h 20 m", the button off
	{ "YardSalePickWait", function()
		local extras = yardPickExtras(4, true)
		UI.campExtras.update(extras)
		UI.campExtras.openYardSale(extras.yardSale)
		task.wait(0.3)
		local line = yardPickCard():FindFirstChild("Line", true)
		assert(line and string.find(line.Text, "Next pick in", 1, true), "uigate: no wait on the taken lucky pick (#3615)")
	end },
	-- #3615: YardSalePicked(1): the light rolls down the board twice and stops on row 1, the only lit row. Tier 1's
	-- short board and its first row, so the whole roll ends inside the 1.5 s a scene is given: a longer one ran on
	-- into the next scene and failed there (the Tier 4 board's roll to row 3 is about 2 s)
	{ "YardSalePickLanded", function()
		local extras = yardPickExtras(1, false)
		UI.campExtras.update(extras)
		UI.campExtras.openYardSale(extras.yardSale)
		task.wait(0.1)
		local landing = 1
		UI.campExtras.picked(landing)
		local total = 0
		for _, step in UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Components.RollBoardLogic").rollSteps(#extras.yardSale.pick, landing) do
			total += step.rest
		end
		assert(total < 1.2, "uigate: the lucky pick's roll takes " .. total .. " s, too long for this scene (#3615)")
		task.wait(total + 0.15)
		local lit = {}
		for _, piece in yardPickCard():GetDescendants() do
			if piece:GetAttribute("RowId") ~= nil then
				local stroke = piece:FindFirstChildWhichIsA("UIStroke")
				if stroke and stroke.Thickness == 3 then
					table.insert(lit, piece.Name)
				end
			end
		end
		local want = "Row" .. landing
		assert(#lit == 1 and lit[1] == want, "uigate: the pick's light is on " .. table.concat(lit, ",") .. ", not " .. want .. " (#3615)")
	end },
	-- #1200: the Garden Nursery at Tier 3: owned pieces read Owned, the rest Buy with the price, Tier 4 and 5 pieces
	-- "Opens at Tier 4"; then its Fences tab
	{ "LawnStall", function()
		UI.nursery.open("pieces")
	end },
	{ "LawnStallFences", function()
		UI.nursery.open("fence")
	end },
	-- #1052: the Corner Shop with every line: a Swift Potion left, snacks part bought, no Big Snack, a Steady Potion sold out
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
				{ itemId = "steady_potion", price = 3500, amount = 1, bought = 1 },
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
		-- #3209 (Derek2: "add different section buttons at top of day cart for potions/cat food/bait"): a tab per
		-- section; the open tab shows only its own header and rows
		local function shows(kind: string): boolean
			local header = window:FindFirstChild("Section_" .. kind, true) :: GuiObject
			return header.Visible
		end
		for _, kind in { "potion", "food", "bait" } do
			assert(window:FindFirstChild(kind .. "Tab", true), "uigate: no " .. kind .. " tab on the Day Cart (#3209)")
		end
		assert(shows("potion") and not shows("food") and not shows("bait"), "uigate: the Day Cart does not open on Potions alone (#3209)")
		assert(not (window:FindFirstChild("kibble", true) :: GuiObject).Visible, "uigate: a bait row shows on the Potions tab (#3209)")
		press("CornerShop", "foodTab")
		assert(shows("food") and not shows("potion"), "uigate: the Cat food tab did not switch the list (#3209)")
		assert((window:FindFirstChild("cat_snack", true) :: GuiObject).Visible, "uigate: no food rows on the Cat food tab (#3209)")
		assert(not (window:FindFirstChild("swift_potion", true) :: GuiObject).Visible, "uigate: a potion row shows on the Cat food tab (#3209)")
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
		-- #3340 (Derek2: "sometimes the buy all gets stuck on ..."): with no answer, "Buying..." ends on its own
		local function allText(): string
			for _, piece in (all :: Instance):GetDescendants() do
				if (piece:IsA("TextLabel") or piece:IsA("TextButton")) and piece.Text ~= "" then
					return piece.Text
				end
			end
			return if all:IsA("TextButton") then all.Text else ""
		end
		assert(allText() == "Buying...", "uigate: Buy all reads " .. allText() .. " while it waits (#2593)")
		UIShim.advance(3.3)
		assert(allText() == "Buy all", "uigate: an unanswered Buy all still reads " .. allText() .. " (#3340)")
		UI.cornerShop.setStock(view()) -- the answer ends the wait
		press("CornerShop", "baitTab") -- #3209: the bait section is on its own tab
		press("CornerShop", "Section_bait.BuyAll") -- the shot: the bait section's card
	end },
	-- #3462: the Day Cart's own two baits at Tier 6, in the billions. After the Buy all scene, which leaves the cart on its Bait tab
	{ "CornerShopTier6Bait", function()
		UI.update({ money = 5000000000, tier = 6, lures = { honey_cream = 1 } })
		UI.cornerShop.setStock({
			window = 5000000,
			restocksAt = workspace:GetServerTimeNow() + 192,
			snackXp = 0,
			stock = {
				{ itemId = "salmon", price = 80000, amount = 2, bought = 0 },
				{ itemId = "honey_cream", price = 1000000000, amount = 2, bought = 0, needsTier = 6 },
				{ itemId = "comet_treat", price = 3000000000, amount = 1, bought = 0, needsTier = 6 },
			},
		})
		UI.cornerShop.open()
		press("CornerShop", "baitTab")
		local window = UIShim.playerGui:FindFirstChild("CornerShop", true)
		assert(window, "no Corner Shop window")
		for _, id in { "honey_cream", "comet_treat" } do
			local row = window:FindFirstChild(id, true)
			assert(row and row:IsA("GuiObject") and row.Visible, "uigate: no " .. id .. " row at Tier 6 (#3462)")
		end
	end },
	-- #3462: the Day Cart's three Tier 6 potions, one sold out for the day
	{ "CornerShopTier6Potions", function()
		UI.update({ money = 30000000000, tier = 6 })
		UI.cornerShop.setStock({
			window = 5000000,
			restocksAt = workspace:GetServerTimeNow() + 192,
			snackXp = 0,
			stock = {
				{ itemId = "gold_rush_potion", price = 3000000, amount = 2, bought = 0 },
				{ itemId = "big_lucky_potion", price = 5000000000, amount = 1, bought = 0, needsTier = 6 },
				{ itemId = "big_gold_rush_potion", price = 8000000000, amount = 2, bought = 1, needsTier = 6, outToday = true },
				{ itemId = "mega_tip_potion", price = 20000000000, amount = 1, bought = 0, needsTier = 6 },
			},
		})
		UI.cornerShop.open()
		press("CornerShop", "potionTab")
		local window = UIShim.playerGui:FindFirstChild("CornerShop", true)
		assert(window, "no Corner Shop window")
		for _, id in { "big_lucky_potion", "big_gold_rush_potion", "mega_tip_potion" } do
			local row = window:FindFirstChild(id, true)
			assert(row and row:IsA("GuiObject") and row.Visible, "uigate: no " .. id .. " row at Tier 6 (#3462)")
		end
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
	-- #3195: the red "!" over the Night Market's cart from nightfall until the market is opened that night
	{ "NightMarketBang", function()
		local cart = Instance.new("Model")
		cart.Name = "DealerCart"
		local body = Instance.new("Part")
		body.Name = "Body"
		body.Size = Vector3.new(6, 5, 4)
		body.Position = Vector3.new(6, 2.5, -18)
		body.Parent = cart
		cart.PrimaryPart = body
		cart:SetAttribute("Open", true)
		cart.Parent = workspace
		cart:AddTag("DealerCart")
		UI.dealer.setNight(true)
		local gui = UIShim.playerGui:FindFirstChild("CatCafeNightMarketBang", true) :: BillboardGui?
		assert(gui and gui.Enabled and gui.Adornee == body, "uigate: no ! over the Night Market at night (#3195)")
		local line = (gui :: BillboardGui):FindFirstChild("Line", true) :: TextLabel
		assert(line.Text == "🌙 Rare foods tonight!", "uigate: the Night Market bubble reads " .. line.Text .. " (#3195)")
		UI.dealer.open()
		assert(not (gui :: BillboardGui).Enabled, "uigate: the Night Market's ! stays after it was opened (#3195)")
		UI.close()
		UI.dealer.setNight(true)
		assert(not (gui :: BillboardGui).Enabled, "uigate: the Night Market's ! came back the same night (#3195)")
		UI.dealer.setNight(false)
		UI.dealer.setNight(true)
		assert((gui :: BillboardGui).Enabled, "uigate: the Night Market's ! did not come back the next night (#3195)")
		Scenes._nightCart = cart
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
	-- F100: the Lost and Found paid out. #3080, #3054 (Derek2: "whenever claiming something no need for a bubble
	-- saying exactly what you claimed"): no prize toast any more; the counters say it
	{ "CampPrize", function()
		UIShim.advance(4) -- earlier scenes' toasts gone
		UI.campExtras.collected(
			"lostFound",
			{ "1 Lucky Potion", "+10 golden fish" },
			{ potions = { lucky_potion = 1 }, fish = 10 }
		)
		UIShim.advance(0.3)
		for _, piece in UIShim.playerGui:GetDescendants() do
			assert(piece.Name ~= "Toast", "uigate: a claim still shows a prize toast (#3080, #3054)")
		end
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
	-- F101, #3691: the Cat Cannon at night during a Rally: the cards keep their night cover and wear no Rally tag
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
		for _, item in UIShim.playerGui:GetDescendants() do
			if item:IsA("TextLabel") and string.find(item.Text, "Rally: rescues", 1, true) then
				error("uigate: a Cat Cannon card still wears the Rally tag (#3691): " .. item:GetFullName())
			end
		end
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
	-- #2864: a Backpack cat with empty hands shows the carry marker over the door ("Check in here"); a cat in the hands
	-- takes over ("Bring it here" at the camp), the bag's comes back when the hands empty, and none once the bag empties
	{ "BagCarryMarker", function()
		local door = Instance.new("Part")
		door.Name = "GateBagDoor"
		door.Parent = workspace
		local camp = Instance.new("Part")
		camp.Name = "GateBagCamp"
		camp.Parent = workspace
		local billboard = UIShim.playerGui:FindFirstChild("CatCafeCarryMarker", true) :: BillboardGui
		assert(billboard, "uigate: no carry marker (#2864)")
		local label = billboard:FindFirstChild("Label", true) :: TextLabel
		-- #3055: the carry marker is about half its old 180 x 64 or less; the tutorial's flash marker keeps its size
		assert(billboard.Size.X.Offset <= 160 and billboard.Size.Y.Offset <= 40,
			"uigate: the carry marker is " .. tostring(billboard.Size) .. ", want 160 x 40 or less (#3055)")
		local tutorialMarker = UIShim.playerGui:FindFirstChild("CatCafeTutorialMarker", true) :: BillboardGui
		assert(tutorialMarker and tutorialMarker.Size.X.Offset == 180, "uigate: the tutorial marker changed size (#3055)")
		local function says(): string?
			return if billboard.Enabled then label.Text else nil
		end
		UI.setBagCarry({ catId = Catalog.cats[1].id, door = door } :: any)
		assert(says() == "Check in here", "uigate: a Backpack cat shows no door marker (#2864)")
		assert((UI.getState() :: any).carrying == nil, "uigate: a Backpack cat set state.carrying (#2864)")
		UI.setCarrying({ catId = Catalog.cats[2].id, camp = camp } :: any)
		assert(says() == "Bring it here", "uigate: the hands' cat did not win the marker (#2864)")
		UI.setCarrying(nil)
		assert(says() == "Check in here", "uigate: the Backpack cat's marker did not come back (#2864)")
		UI.setBagCarry(nil)
		assert(says() == nil, "uigate: the marker stayed after the bag emptied (#2864)")
		door:Destroy()
		camp:Destroy()
	end },
	-- #2860 (Derek2: the event "flashes and shows during catching minigames when it should be hidden"): the chip's
	-- countdown repaints every second, and mid-catch it stays down; after the catch it is back
	{ "CafeEventCatch", function()
		local t = workspace:GetServerTimeNow()
		Scenes._cafeEvent = true
		cafeEvent({ EventStartsAt = t - 20, EventEndsAt = t + 7180, EventRunning = true })
		local chip = assertEventChip(2) -- running: "ends in 1:59:40" repaints every second
		local nextLine = UIShim.playerGui:FindFirstChild("EventNext", true) :: TextLabel
		startCatch("gate_eventchip", "Rare", 3, 0.2, 0.9)
		UIShim.advance(0.3)
		assert(UI.catch.circlesActive(), "uigate: the catch circles did not start")
		for _ = 1, 3 do
			UIShim.advance(1.1)
			UI.cafeEvent.tick()
			assert(not chip.Visible and not nextLine.Visible, "uigate: the Cafe Event chip showed mid-catch on its tick (#2860)")
		end
		UI.catch.hideCircles()
		UI.catch.hide()
		UIShim.advance(0.5)
		UI.cafeEvent.tick()
		assert(chip.Visible and nextLine.Visible, "uigate: the Cafe Event chip did not come back after the catch (#2860)")
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
		-- a 10 x 7.5 stud face at 40 px a stud, inside a small phone's height; #3518: on a 705 x 338 phone the 300 px
		-- face ran 7 px past the bottom under the top bar's inset, so it shrinks to the room below the bar there
		local inset = game:GetService("GuiService"):GetGuiInset().Y
		local faceHeight = math.min(300, workspace.CurrentCamera.ViewportSize.Y - inset - 8)
		face.Size = UDim2.fromOffset(faceHeight * 4 / 3, faceHeight)
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
		UI.arcade.setOn(true, true)
		press("CatCafeHUD", "Icons.Menu")
		-- Derek 2026-11-13 ("remove the old cat arcade icon from settings"): no Cat Arcade row in the list
		local pop = UIShim.playerGui:FindFirstChild("CatCafeHUD"):FindFirstChild("Pop", true)
		if pop and pop.Visible then
			assert(pop:FindFirstChild("Arcade") == nil, "uigate: the Menu list still has the Cat Arcade row (2026-11-13)")
		end
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
	-- 2x on sale; once owned, nothing (#3052: the boosts card has the pass's row)
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
		-- #3307: in the bar when their middle is over the root's top (on a big tablet they are taller than the bar and
		-- hang from the screen's top edge a little past it)
		if right(counters) > 0 and counters.AbsolutePosition.Y + counters.AbsoluteSize.Y / 2 <= root.AbsolutePosition.Y then
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
		-- #2710 (kept when #2827 hid the potion chip): on touch there is no Potions tile; the Bag has the potions
		local corner = hud:FindFirstChild("Corner", true)
		local tile = corner and corner:FindFirstChild("Potions")
		assert(tile == nil or not (tile :: GuiObject).Visible, "uigate: the Potions tile shows on touch (#2710)")
		local row = root:FindFirstChild("Potions") :: GuiObject
		assert(row.Visible, "uigate: no Luck row with luck 2x (#2393)")
		if counters.AbsolutePosition.Y + counters.AbsoluteSize.Y / 2 <= root.AbsolutePosition.Y then
			-- #2447: in the top bar the Luck row sits right of the counters, level with them (#3307: the middle is in
			-- the bar; on a big tablet the counters are taller than it)
			local gap = row.AbsolutePosition.X - (counters.AbsolutePosition.X + counters.AbsoluteSize.X)
			local narrow = (workspace.CurrentCamera :: Camera).ViewportSize.X < 760
			if narrow and row.AbsolutePosition.Y >= bottom then
				-- #3518: the third case (#2712, #2881), a phone too narrow for the pair (705 x 338): the counters stay in
				-- the bar and the row hangs under them, its left edge level with theirs or right of it, clear of the menu.
				-- Only under 760 px wide: an 844 x 390 phone keeps the pair in the bar, and the asserts below hold it there
				assert(row.AbsolutePosition.X >= counters.AbsolutePosition.X - 1, "uigate: the Luck row under the counters starts left of them (#2881)")
				assert(row.AbsolutePosition.X + row.AbsoluteSize.X <= root.AbsolutePosition.X + root.AbsoluteSize.X, "uigate: the Luck row under the counters runs off the screen (#2881)")
				assert(row.AbsolutePosition.Y - bottom <= 30, "uigate: the Luck row sits far under the counters (#2712)")
			else
				assert(gap >= 0 and gap <= 30, ("uigate: the Luck row sits %d px after the counters in the top bar (#2447)"):format(gap))
				local rowMid = row.AbsolutePosition.Y + row.AbsoluteSize.Y / 2
				local countersMid = counters.AbsolutePosition.Y + counters.AbsoluteSize.Y / 2
				assert(math.abs(rowMid - countersMid) <= 2, "uigate: the Luck row is not level with the counters (#2447)")
			end
		else
			assert(row.AbsolutePosition.Y >= bottom, "uigate: the Luck row is not under the counters on touch (#2393)")
			-- #2881 (Derek2: "luck gets pushed down into middle of screen"): the row hangs under the money with left
			-- edges level, or right of that where the menu grid is in the way; it was centred under the pair (#2393).
			-- #3518: a 667 x 375 phone, where the counters do not fit the bar, is the size that reaches this
			local left = row.AbsolutePosition.X - counters.AbsolutePosition.X
			assert(left >= -1 and left <= counters.AbsoluteSize.X / 2, ("uigate: the Luck row starts %d px from the counters' left edge (#2881)"):format(left))
			assert(row.AbsolutePosition.Y - bottom <= 30, "uigate: the Luck row sits far under the counters (#2712)")
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
	-- pass owned the badge beside the money is hidden (and since #3052 nothing stands in for it), and the golden fish sits
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
				-- (#3052: no cash tag between them any more, on any device)
				local before = amount.AbsolutePosition.X + amount.TextBounds.X
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
		UI.store.preview(storePrices(true), { [Config.MoneyPassIds[4]] = true })
		UIShim.advance(1 / 60)
		-- #3052 (Derek2 11-10: "if 4x money is bought just add it to money breakdown no need for a symbol"): an owned
		-- money pass shows no chip, tag or badge in the HUD (#1962's gold chip, #2447's tag after the amount)
		local hud = UIShim.playerGui:FindFirstChild("CatCafeHUD") :: ScreenGui
		assert(hud:FindFirstChild("CashChip", true) == nil, "uigate: the owned money pass still has a chip in the HUD (#3052)")
		local badge = hud:FindFirstChild("MoneyBadge", true) :: GuiObject
		assert(not badge.Visible, "uigate: the money badge shows with the 4x pass owned (#3052)")
		for _, piece in hud:GetDescendants() do
			if piece:IsA("TextLabel") or piece:IsA("TextButton") then
				local text = (piece :: any).Text :: string
				local shown = (piece :: GuiObject).Visible and (piece :: GuiObject).AbsoluteSize.X > 0
				assert(not (shown and (text:find("x4", 1, true) or text:find("4x", 1, true))), "uigate: the HUD still says " .. text .. " for the owned 4x pass (#3052)")
			end
		end
		-- its line is in the money's boosts card
		local BoostList = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Components.BoostList")
		local state = table.clone(UI.getState() :: any)
		state.passBoosts = { cafe = 0, staff = 1, money = 4 }
		local found = false
		for _, row in BoostList.rows(Catalog, state, workspace:GetServerTimeNow(), 0) do
			if row.key == "moneyPass" then
				found = row.value == "x4" and row.active
			end
		end
		assert(found, "uigate: the boosts card has no Money pass x4 row (#3052)")
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
	-- #2850 (Derek2: "move the 999 pack and extra food bowl somewhere in featured"): with the Starter Bundle unbought
	-- it is the hero, and the King Cat Pack and the Second Bait Bowl lead the picks; the hero lists the bundle's contents
	{ "StoreStarter", function()
		UI.update({ starterBought = false } :: any)
		UI.store.preview(storePrices(true), {})
		UI.open("Store")
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local storeWindow = modals and modals:FindFirstChild("Store", true)
		assert(storeWindow, "uigate: no Store window (#2850)")
		local names = {}
		for _, label in storeWindow:GetDescendants() do
			if label:IsA("TextLabel") and label.Visible then
				names[label.Text] = true
			end
		end
		for _, name in { "Starter Bundle", "King Cat Pack", "Second Bait Bowl" } do
			assert(names[name], "uigate: Featured does not show " .. name .. " (#2850)")
		end
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
		-- #3710: each side's cat with a trait wears its name; the other tiles show no band
		local shown = {}
		for _, item in UIShim.playerGui:GetDescendants() do
			if item.Name == "Trait" and item:IsA("TextLabel") and item.Visible then
				shown[item.Text] = true
			end
		end
		assert(shown["Golden Whiskers"], "uigate: my cat's trait is not on its trade tile (#3710)")
		assert(shown["Big Tipper"], "uigate: Sam's cat's trait is not on its trade tile (#3710)")
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
		-- #3710: the trait line under the rarity of each cat that has one
		local lines = 0
		for _, item in UIShim.playerGui:GetDescendants() do
			local parent = item.Parent
			if
				item.Name == "Trait"
				and item:IsA("TextLabel")
				and item.Visible
				and parent ~= nil
				and parent.Name:match("^Card%d")
				and (item.Text == "Golden Whiskers" or item.Text == "Big Tipper")
			then
				lines += 1
			end
		end
		assert(lines == 2, "uigate: the confirm cards show " .. lines .. " trait lines, not 2 (#3710)")
	end },
	-- F102: a gift: "Nothing" in red under You get and "You get nothing back"
	{ "TradeGift", function()
		local state = tradeState({ phase = "confirm", gift = true, theirRateForMe = 0, getValue = 0 })
		state.them.cats = {}
		UI.trade.state(state)
	end },
	-- #1574: the Decor tab: my tradeable pieces rarest first (a Legendary locked, one Sam owns greyed "Has it", the
	-- one on offer ticked), a piece on each side after the cats
	{ "TradeDecor", function()
		local before = UI.getState() :: any
		Scenes._decorOwned = before.decorOwned or {}
		local SharedTrade = UIShim.require("ReplicatedStorage.Shared.Trade")
		local pieces, owned, legendary = {}, {}, nil
		for _, decor in Catalog.crateDecor do
			local info = SharedTrade.piece(decor.id)
			if info ~= nil then
				if info.rarity == "Legendary" and legendary == nil then
					legendary = decor.id
					owned[decor.id] = true
				elseif #pieces < 7 and info.rarity ~= "Legendary" and info.rarity ~= "Mythical" then
					table.insert(pieces, decor.id)
					owned[decor.id] = true
				end
			end
		end
		assert(#pieces >= 3 and legendary ~= nil, "uigate: not enough tradeable crate decor for TradeDecor")
		UI.update({ decorOwned = owned, decorUnlocked = {} } :: any)
		local function tile(id)
			local info = SharedTrade.piece(id)
			return { id = id, name = info.name, kind = info.kind, rarity = info.rarity, bonus = info.bonus }
		end
		local state = tradeState()
		state.me.decor = { tile(pieces[1]) }
		state.them.decor = { tile(pieces[#pieces]), tile("tulip_bed") }
		state.theyHave = { pieces[2] }
		UI.trade.state(state)
		press("Trade", "Tabs.Decor")
		task.wait(0.05)
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local list = modals and modals:FindFirstChild("Picks", true)
		local shown = 0
		for _, piece in (list and list:FindFirstChild("List") or Instance.new("Folder")):GetChildren() do
			if piece.Name == "Piece" and piece:IsA("Frame") and piece.Visible then
				shown += 1
			end
		end
		-- the crate pieces above and the sample lawn's pieces
		assert(shown >= #pieces + 1, "uigate: the Decor tab shows " .. shown .. " pieces, not " .. (#pieces + 1))
	end },
	-- #1574: the confirm face with pieces after the cats, their rarity and tip bonus under them
	{ "TradeDecorConfirm", function()
		local SharedTrade = UIShim.require("ReplicatedStorage.Shared.Trade")
		local first = nil
		for _, decor in Catalog.crateDecor do
			local info = SharedTrade.piece(decor.id)
			if info ~= nil and first == nil then
				first = { id = decor.id, name = info.name, kind = info.kind, rarity = info.rarity, bonus = info.bonus }
			end
		end
		local state = tradeState({ phase = "confirm" })
		state.me.ready = true
		state.them.ready = true
		state.me.decor = { first }
		state.them.decor = {
			{ id = "tulip_bed", name = "Tulip bed", kind = "lawn", rarity = "Uncommon", bonus = 0.02 },
		}
		UI.trade.state(state)
	end },
	-- #2745: the Crates tab: banked crates in Market order with "x3", one on offer ("1 on"), one Sam can't open yet
	-- greyed; crates on each side after the cats, and the count picker after a long press
	{ "TradeCrates", function()
		local kinds = {}
		for _, crate in Catalog.crates do
			if not crate.golden and #kinds < 4 then
				table.insert(kinds, crate)
			end
		end
		assert(#kinds >= 3, "uigate: not enough crate kinds for TradeCrates")
		local banked = {}
		for index, crate in kinds do
			banked[crate.id] = index + 1
		end
		Scenes._crates = (UI.getState() :: any).crates or {}
		UI.update({ crates = banked } :: any)
		local state = tradeState()
		state.cratesOn = true
		state.me.crates = { { id = kinds[1].id, name = kinds[1].name, area = kinds[1].area, count = 1 } }
		state.them.crates = { { id = kinds[2].id, name = kinds[2].name, area = kinds[2].area, count = 3 } }
		state.crateBlocked = { [kinds[#kinds].id] = "They haven't reached the Desert yet" }
		UI.trade.state(state)
		press("Trade", "Tabs.Crates")
		task.wait(0.05)
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local picks = modals and modals:FindFirstChild("Picks", true)
		local shown = 0
		for _, tile in (picks and picks:FindFirstChild("List") or Instance.new("Folder")):GetChildren() do
			if tile.Name == "Crate" and tile:IsA("Frame") and tile.Visible then
				shown += 1
			end
		end
		assert(shown == #kinds, "uigate: the Crates tab shows " .. shown .. " crates, not " .. #kinds)
		local picker = picks and picks:FindFirstChild("CratePicker")
		assert(picker ~= nil, "uigate: no crate count picker")
		-- the long press's picker as it shows (the shim has no held press)
		picker.Visible = true
		picker:FindFirstChild("Title").Text = "How many " .. kinds[2].name .. "?"
		picker:FindFirstChild("Count").Text = "2"
	end },
	-- #2745: with cratesOn false the Crates tab stays hidden
	{ "TradeCratesOff", function()
		local state = tradeState()
		state.cratesOn = false
		UI.trade.state(state)
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local picks = modals and modals:FindFirstChild("Picks", true)
		local tab = picks and picks:FindFirstChild("Tabs")
		local crates = tab and tab:FindFirstChild("Crates")
		assert(crates ~= nil and not crates.Visible, "uigate: the Crates tab shows with cratesOn false")
	end },
	-- #2745 (section 1d): golden fish: 50 on my side, 120 on Sam's, each as a 🐟 card after the cats; a press on mine
	-- opens the picker as an amount with 10, 50 and Max and Sam's room today under its title
	{ "TradeFish", function()
		local state = tradeState()
		state.fishOn = true
		state.fishRoom = 150
		state.me.fish = 50
		state.them.fish = 120
		UI.trade.state(state)
		press("Trade", "Mine.Grid.Fish")
		task.wait(0.05)
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local picks = modals and modals:FindFirstChild("Picks", true)
		local picker = picks and picks:FindFirstChild("CratePicker")
		assert(picker ~= nil and picker.Visible, "uigate: the fish card's press opened no picker")
		assert(picker:FindFirstChild("Title").Text == "How many golden fish?", "uigate: the fish picker's title")
		assert(picker:FindFirstChild("Count").Text == "50", "uigate: the fish picker starts at what is on offer")
		local room = picker:FindFirstChild("Room")
		assert(room.Visible and room.Text == "They can get 150 more today", "uigate: the fish picker's room line")
		local theirs = modals:FindFirstChild("Theirs", true)
		local fish = theirs and theirs:FindFirstChild("Fish", true)
		assert(fish ~= nil and fish.Visible, "uigate: Sam's fish card is hidden")
	end },
	-- #2745: no fish yet: my card says Add, Sam's is hidden; with fishOn false neither shows
	{ "TradeFishNone", function()
		local state = tradeState()
		state.fishOn = true
		state.fishRoom = 250
		UI.trade.state(state)
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local mine = modals and modals:FindFirstChild("Mine", true)
		local theirs = modals and modals:FindFirstChild("Theirs", true)
		local myFish = mine and mine:FindFirstChild("Fish", true)
		assert(myFish ~= nil and myFish.Visible, "uigate: my fish card is hidden at 0")
		assert(not (theirs:FindFirstChild("Fish", true) :: Frame).Visible, "uigate: Sam's fish card shows at 0")
		state = tradeState({ version = 2 })
		state.fishOn = false
		state.me.fish = 10
		UI.trade.state(state)
		assert(not myFish.Visible, "uigate: my fish card shows with fishOn false")
		state = tradeState({ version = 3 })
		state.fishOn = true
		state.fishRoom = 250
		UI.trade.state(state)
	end },
	-- #2745: the confirm face with the fish after the cats
	{ "TradeFishConfirm", function()
		local state = tradeState({ phase = "confirm" })
		state.me.ready = true
		state.them.ready = true
		state.fishOn = true
		state.fishRoom = 150
		state.me.fish = 40
		state.them.fish = 0
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
	-- #1574: a trade that swapped decor: a crate piece and a lawn piece after the cat on the Got line, one piece alone
	-- on the Gave line (no "Nothing" there)
	{ "TradeLogDecor", function()
		local log = tradeLog(os.time())
		local piece = nil
		for _, decor in Catalog.crateDecor do
			if piece == nil then
				piece = { id = decor.id, kind = "decor", rarity = decor.rarity or "Rare" }
			end
		end
		assert(piece ~= nil, "uigate: no crate decor for TradeLogDecor")
		log[1].gave = {}
		log[1].gaveDecor = { piece }
		log[1].gotDecor = { piece, { id = "tulip_bed", kind = "lawn", rarity = "Uncommon" } }
		UI.update({ tradeLog = log })
		UI.open("TradeLog")
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local card = modals and modals:FindFirstChild("Trade1", true)
		local got = card and card:FindFirstChild("Got")
		local shown = 0
		for _, child in (got or Instance.new("Folder")):GetChildren() do
			if child:IsA("Frame") and child.Name:sub(1, 5) == "Piece" and child.Visible then
				shown += 1
			end
		end
		assert(shown == 2, "uigate: the Got line shows " .. shown .. " pieces, not 2")
		local nothing = card and card:FindFirstChild("GaveNothing")
		assert(nothing ~= nil and not (nothing :: TextLabel).Visible, "uigate: Gave says Nothing beside a piece")
	end },
	-- #2745: a trade of crates for golden fish: two crate kinds on the Gave line, 120 fish on the Got line
	{ "TradeLogCrates", function()
		local log = tradeLog(os.time())
		local kinds = {}
		for _, crate in Catalog.crates do
			if not crate.golden and #kinds < 2 then
				table.insert(kinds, crate.id)
			end
		end
		log[1].gave = {}
		log[1].got = {}
		log[1].gaveCrates = { { id = kinds[1], count = 3 }, { id = kinds[2], count = 1 } }
		log[1].gotFish = 120
		UI.update({ tradeLog = log })
		UI.open("TradeLog")
		local modals = UIShim.playerGui:FindFirstChild("CatCafeModals")
		local card = modals and modals:FindFirstChild("Trade1", true)
		local function shown(lineName)
			local line = card and card:FindFirstChild(lineName)
			local count = 0
			for _, child in (line or Instance.new("Folder")):GetChildren() do
				if child:IsA("Frame") and child.Name:sub(1, 5) == "Piece" and child.Visible then
					count += 1
				end
			end
			return count
		end
		assert(shown("Gave") == 2, "uigate: the Gave line shows " .. shown("Gave") .. " crates, not 2")
		assert(shown("Got") == 1, "uigate: the Got line shows " .. shown("Got") .. " items, not the fish")
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
	-- #3701: the cafe rest banner at the head of the toasts' stack, in its three states; in a 2x party no line
	-- names 2x. Its words are never cut off: every line stays inside the pill.
	{ "RestBannerWelcome", function()
		UI.rest.banner("welcome", true, 0)
		Scenes._rest = true
		local banner = UIShim.playerGui:FindFirstChild("RestBanner", true) :: GuiObject?
		assert(banner and banner.Visible, "uigate: the rest banner does not show (#3701)")
		local big = banner:FindFirstChild("Big", true) :: TextLabel
		assert(big.Text == "Stand still for 2x money", "uigate: the rest banner's welcome is not the design's (#3701)")
		UI.rest.banner("welcome", false, 0)
		assert(not string.find(big.Text, "2x", 1, true), "uigate: the rest banner names 2x in a 2x party (#3701)")
		UI.rest.banner("welcome", true, 0)
	end },
	{ "RestBannerCounting", function()
		UI.rest.banner("counting", true, 80)
		Scenes._rest = true
		local banner = UIShim.playerGui:FindFirstChild("RestBanner", true) :: GuiObject
		local big = banner:FindFirstChild("Big", true) :: TextLabel
		assert(big.Text == "2x money in 1:20", "uigate: the rest banner's count is not the design's (#3701)")
	end },
	{ "RestBannerResting", function()
		UI.rest.banner("resting", true, 0)
		Scenes._rest = true
		local banner = UIShim.playerGui:FindFirstChild("RestBanner", true) :: GuiObject
		local big = banner:FindFirstChild("Big", true) :: TextLabel
		assert(big.Text == "2x money ON", "uigate: the rest banner's resting line is not the design's (#3701)")
		UI.rest.banner("resting", false, 0)
		assert(not string.find(big.Text, "2x", 1, true), "uigate: the resting banner names 2x in a 2x party (#3701)")
		UI.rest.banner("resting", true, 0)
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
	if Scenes._richTipGate ~= nil then
		-- #3633's scene: its bubbles and made-up plots
		for _, made in Scenes._richTipGate.made do
			if typeof(made) == "Instance" then
				made:Destroy()
			else
				made:destroy()
			end
		end
		Scenes._richTipGate.gui:Destroy()
		Scenes._richTipGate = nil
	end
	if Scenes._rankSpot then
		Scenes._rankSpot = nil
		(UI.rankSpot :: any).set("none") -- #3555's scene
	end
	if Scenes._rest then
		Scenes._rest = nil
		UI.rest.banner(nil) -- #3701's scenes
	end
	if UI.loot.card then
		UI.loot.card:hide()
	end
	reel(false)
	if Scenes._packed ~= nil then
		Scenes._packed:SetAttribute("PackedCatId", nil) -- #2731's scene
		Scenes._packed = nil
	end
	if Scenes._refillBag ~= nil then
		UI.update({ lures = Scenes._refillBag }) -- #3008's scene
		Scenes._refillBag = nil
	end
	if Scenes._nightPass then
		UIShim.player:SetAttribute("NightPass", nil) -- #2692's scene
		UI.clock.setAreasOpen(true)
		UI.clock.clear()
		Scenes._nightPass = nil
	end
	if Scenes._poolTraits then
		-- #3196's scenes: the pool's numbers put away (false is the `traits` switch off), or the Park card keeps the
		-- Mystic Pool line in place of the Picnic Basket for every scene after them (CannonExtras, #3436)
		UI.update({ traits = false } :: any)
		Scenes._poolTraits = nil
	end
	if Scenes._palsClock then
		-- #3052's scene: its Lucky Day clock put away, or it stays bound for every scene after it in the shard and
		-- the tip scenes that follow lose their free moment (#3408)
		UI.clock.clear()
		Scenes._palsClock = nil
	end
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
	if Scenes._nightCart ~= nil then
		Scenes._nightCart:Destroy() -- #3195's scene
		UI.dealer.setNight(false)
		Scenes._nightCart = nil
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
	-- #3105, #3109: the loading screen put away, so the next scene starts with none up (IntroLoading leaves it
	-- showing, and IntroLoadingRace, the scene after it, begins by asking for a race with no screen up)
	local introWait = UIShim.playerGui:FindFirstChild("CatCafeIntroWait")
	if introWait ~= nil and introWait:IsA("ScreenGui") and introWait.Enabled then
		UI.intro.waiting(false)
		UIShim.advance(1) -- its slide away
	end
	if Scenes._rallyPeek then
		Scenes._rallyPeek = nil
		UI.rally.update(rallyState({ active = false, endsAt = 0, startsAt = 0 })) -- #2098: the banner put away
	end
	if Scenes._rescueCard then
		Scenes._rescueCard = nil
		UI.catch.hide() -- #3752's scene
	end
	if Scenes._tackle then
		Scenes._tackle = nil
		UI.shove.setEnabled(false) -- #2510's Tackle button
	end
	if Scenes._binBoards then
		Scenes._binBoards:Destroy() -- #3611's boards
		Scenes._binBoards = nil
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
	if UI.perks.card and UI.perks.card:isShowing() then
		UI.perks.card:hide() -- #2687
	end
	if Scenes._returnHook then
		Scenes._returnHook = nil
		local current: any = UI.getState()
		current.returnHook = nil -- #2123's welcome back scene
		UI.update({ returnGoals = false } :: any) -- #2916's welcome back scene (getState is a copy)
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
	if Scenes._crates ~= nil then
		UI.update({ crates = Scenes._crates } :: any) -- #2745's Crates tab scene
		Scenes._crates = nil
	end
	if Scenes._decorOwned ~= nil then
		UI.update({ decorOwned = Scenes._decorOwned } :: any) -- #2053's rarity tint scene
		Scenes._decorOwned = nil
	end
	if Scenes._parkFly ~= nil then
		UI.update({ money = Scenes._parkFly } :: any)
		Scenes._parkFly = nil
		UI.cannon.clearFly() -- #2915's scene
	end
	if Scenes._rankTier ~= nil then
		UI.update({ tier = Scenes._rankTier } :: any) -- #2121's Tier 2 rank-up scene
		Scenes._rankTier = nil
	end
	if Scenes._traitBefore then
		UI.update({ cats = Scenes._traitBefore } :: any) -- #3717's CatsTrait: gate_3 without its trait again
		Scenes._traitBefore = nil
	end
	if Scenes._feedBefore then
		UI.update({ catFood = Scenes._feedBefore.catFood or {} } :: any) -- #2418's CatsFeed: the Bag's food back
		Scenes._feedBefore = nil
	end
	if Scenes._secondCat then
		local was = Scenes._secondCat -- #3022's second cat goal scene: the tier goal and the sample cafe back
		Scenes._secondCat = nil
		UI.update({ secondCat = false, stuckGoal = false, tier = was.tier, money = was.money, tutorialStep = was.tutorialStep } :: any)
	end
	if Scenes._goalFolded then
		Scenes._goalFolded = nil
		local goal = UIShim.playerGui:FindFirstChild("TierGoal", true)
		if goal then
			UIShim.fire(UIShim.eventOf(goal, "Activated")) -- #2714's scene: the chip's tap opens the card again
		end
	end
	if Scenes._stepState then
		UI.update(Scenes._stepState :: any) -- #2697's food steps and #2712's top row scenes: the state back
		Scenes._stepState = nil
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
	if Scenes._lateCats then
		Scenes._lateCats = nil
		UI.update({ cats = samplePlayer(os.time()).cats }) -- #2651's Museum scenes
	end
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
	if Scenes._cozy then
		Scenes._cozy = nil
		UI.cozy.plot = nil -- #2798's scene: no Cozy line
		UI.cozy.refresh()
	end
	if Scenes._ladder then
		Scenes._ladder = nil
		UI.update({ giftNext = {} } :: any) -- #2791's scene: the ladder done, the Rewards tile as it was
	end
	UI.parkTrail.set(nil, nil) -- #3554's scene: the tier goal again
	if Scenes._parkGoal then
		UI.update(Scenes._parkGoal :: any)
		Scenes._parkGoal = nil
	end
	-- the help card waits for Got it
	local ask = UIShim.playerGui:FindFirstChild("CatCafeAsk")
	if ask and ask:FindFirstChild("Choice_ok", true) and ask:FindFirstChild("Card", true).Visible then
		press("CatCafeAsk", "Choice_ok")
	end
	-- #3657: on the faces ask "ok" brings the reasons up on the same card; Skip puts it away
	if ask and ask:FindFirstChild("Choice_skip", true) and ask:FindFirstChild("Card", true).Visible then
		press("CatCafeAsk", "Choice_skip")
	end
	-- F92: the invite nudge's Not now
	if ask and ask:FindFirstChild("Choice_later", true) and ask:FindFirstChild("Card", true).Visible then
		press("CatCafeAsk", "Choice_later")
	end
	UI.firstVisit.changed(nil, function() -- #2792's scene: no first visit at the cafe
		return false
	end)
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
