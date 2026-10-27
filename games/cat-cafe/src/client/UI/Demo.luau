--!strict
-- The shared catalog plus a pretend server, so the UI runs in Studio with no backend.
-- Usage from any LocalScript: require the UI module and call UI.demo()
-- Everything here is client-side pretend money. Delete or leave unused in production.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Format = require(script.Parent.Components.Format)
local RankUp = require(script.Parent.Screens.RankUp)
local RescueMarker = require(Shared:WaitForChild("RescueMarker"))
local Types = require(script.Parent.Types)

local Demo = {}

local function now(): number
	return os.time()
end

-- The real catalog (src/shared/Catalog.luau), so the demo shows the slice's actual cats and prices.
local CATALOG: Types.Catalog = {
	cats = Catalog.cats,
	upgrades = Catalog.upgrades,
	decor = Catalog.decor,
	lures = Catalog.lures,
	spots = Catalog.spots,
	tiers = Catalog.tiers,
	areas = Catalog.areas,
}

-- data-model section 10: circles and shrink time per rarity, Basic Net windows
local DEMO_CIRCLES: { [string]: { count: number, shrink: number } } = {
	Common = { count = 1, shrink = 1.4 },
	Rare = { count = 2, shrink = 1.15 },
	Epic = { count = 3, shrink = 0.95 },
	Legendary = { count = 4, shrink = 0.8 },
	Mythical = { count = 5, shrink = 0.65 },
}
local DEMO_WINDOWS: Types.CatchWindows = { perfect = 0.045, good = 0.11 }

local DECOR_BONUS: { [string]: number } =
	{ plants = 0.05, rug = 0.05, neon_sign = 0.10, fish_tank = 0.10 }
-- the bait bowl's wait, short so the demo shows the cat arriving (the design's LureWaitSeconds is 600)
local DEMO_BAIT_SECONDS = 20
-- the night dealer's stock window, short so one restock shows each night (DealerWindowSeconds is 600)
local DEMO_DEALER_WINDOW = 20

local SELL_VALUE: { [string]: number } =
	{ Common = 25, Rare = 150, Epic = 600, Legendary = 3000, Mythical = 12000 }

function Demo.run(UI: any): () -> ()
	local running = true
	local nextUid = 1
	local function uid(): string
		nextUid += 1
		return "demo_" .. tostring(nextUid)
	end

	local catById: { [string]: Types.CatDef } = {}
	for _, def in CATALOG.cats do
		catById[def.id] = def
	end

	local profile = {
		money = 50,
		upgradeLevels = { espresso = 1 } :: { [string]: number },
		decorOwned = {} :: { [string]: boolean },
		decorPlaced = {} :: { [string]: boolean },
		lures = {} :: { [string]: number },
		cats = {} :: { [string]: Types.CatInstance },
		collection = { tabby = now() } :: { [string]: number },
		tier = 1,
	}
	local starter = uid()
	profile.cats[starter] = {
		uid = starter,
		catId = "tabby",
		variant = "base",
		name = "Mochi", -- a player's name for the cat, as the server sends it after RenameCat
		caughtAt = now(),
		spotId = "barista_1",
		level = 2,
		stars = 3,
		rating = 1.2,
	}

	local spotType: { [string]: string } = {}
	for _, spot in CATALOG.spots :: { Types.SpotDef } do
		spotType[spot.id] = spot.spotType
	end

	local function rate(): number
		local multiplier = 1
			+ 0.10 * (profile.upgradeLevels.tables or 0)
			+ 0.15 * ((profile.upgradeLevels.espresso or 1) - 1)
		for decorId, placed in profile.decorPlaced do
			if placed then
				multiplier += DECOR_BONUS[decorId] or 0
			end
		end
		local total = 0
		for _, instance in profile.cats do
			if instance.spotId then
				local def = catById[instance.catId]
				local favorite = def.favoriteRole == spotType[instance.spotId]
				total += def.incomePerSecond * (if favorite then 1.5 else 1)
			end
		end
		return total * multiplier
	end

	local function push()
		UI.update({
			money = math.floor(profile.money),
			incomePerSecond = rate(),
			upgradeLevels = profile.upgradeLevels,
			decorOwned = profile.decorOwned,
			decorPlaced = profile.decorPlaced,
			lures = profile.lures,
			cats = profile.cats,
			collection = profile.collection,
			customers = 2 * (profile.upgradeLevels.tables or 0),
			tier = profile.tier,
		})
	end

	local function spend(cost: number): boolean
		if profile.money < cost then
			UI.toast("Not enough coins", "warn")
			return false
		end
		profile.money -= cost
		return true
	end

	UI.init({ catalog = CATALOG })

	local connections: { any } = {}
	connections[#connections + 1] = UI.events.buyUpgrade:Connect(function(upgradeId: string)
		for _, def in CATALOG.upgrades do
			if def.id == upgradeId then
				local level = profile.upgradeLevels[upgradeId] or 0
				local cost = def.costs[level + 1]
				if level >= def.maxLevel or not cost then
					return
				end
				if spend(cost) then
					profile.upgradeLevels[upgradeId] = level + 1
					UI.toast(def.name .. " is now Lv " .. tostring(level + 1), "good")
					push()
				end
			end
		end
	end)
	connections[#connections + 1] = UI.events.buyDecor:Connect(function(decorId: string)
		for _, def in CATALOG.decor do
			if def.id == decorId and not profile.decorOwned[decorId] and spend(def.cost) then
				profile.decorOwned[decorId] = true
				profile.decorPlaced[decorId] = true
				UI.toast(def.name .. " placed", "good")
				push()
			end
		end
	end)
	connections[#connections + 1] = UI.events.toggleDecor:Connect(
		function(decorId: string, placed: boolean)
			if profile.decorOwned[decorId] then
				profile.decorPlaced[decorId] = placed
				push()
			end
		end
	)
	connections[#connections + 1] = UI.events.buyLure:Connect(function(lureId: string)
		for _, def in CATALOG.lures do
			if def.id == lureId and spend(def.cost) then
				profile.lures[lureId] = (profile.lures[lureId] or 0) + 1
				push()
			end
		end
	end)
	-- Bait bowl (F28): the food goes in, the cat is rolled at once and shows up DEMO_BAIT_SECONDS later
	local bait: Types.BaitView? = nil
	local baitCat: Types.BaitCat? = nil
	connections[#connections + 1] = UI.events.useLure:Connect(function(lureId: string)
		local lure: Types.LureDef? = nil
		for _, def in CATALOG.lures do
			if def.id == lureId then
				lure = def
			end
		end
		if not lure or bait or (profile.upgradeLevels.lure_bowl or 0) < 1 then
			return
		end
		local food = lure :: Types.LureDef
		if (profile.lures[lureId] or 0) < 1 then
			return
		end
		profile.lures[lureId] -= 1
		local roll = math.random() * 100
		local rarity: string = "Common"
		for _, name in { "Common", "Rare", "Epic", "Legendary", "Mythical" } do
			local share = (food.odds :: any)[name] or 0
			if roll < share then
				rarity = name
				break
			end
			roll -= share
		end
		local pool: { Types.CatDef } = {}
		for _, def in CATALOG.cats do
			if def.rarity == rarity then
				table.insert(pool, def)
			end
		end
		local picked = if #pool > 0 then pool[math.random(1, #pool)] else CATALOG.cats[1]
		local charm = math.floor((math.random() + math.random()) / 2 * 101)
		local view: Types.BaitView = { lureId = lureId, readyAt = now() + DEMO_BAIT_SECONDS }
		bait = view
		baitCat = {
			catId = picked.id,
			variant = if math.random() < 0.2 then "shiny" else "base",
			charm = charm,
			stars = math.clamp(math.ceil(charm / 20), 1, 5),
		}
		UI.bait.set(view)
		UI.toast(food.name .. " is in the bowl. A cat comes by soon!", "good")
		push()
		task.delay(DEMO_BAIT_SECONDS, function()
			if running and bait == view and baitCat then
				UI.bait.showReady(baitCat)
			end
		end)
	end)
	connections[#connections + 1] = UI.events.resolveBait:Connect(function(choice: Types.BaitChoice)
		local cat = baitCat
		if not cat or not bait then
			return
		end
		bait, baitCat = nil, nil
		UI.bait.set(nil)
		if choice == "tame" then
			local newUid = uid()
			profile.cats[newUid] = {
				uid = newUid,
				catId = cat.catId,
				variant = cat.variant or "base",
				caughtAt = now(),
				spotId = nil,
			}
			local isNew = profile.collection[cat.catId] == nil
			profile.collection[cat.catId] = now()
			UI.showCatFound(cat.catId, isNew, { stars = cat.stars, shiny = cat.variant == "shiny" })
			push()
		else
			UI.toast("It wandered off. Maybe next time!", "info")
		end
	end)

	-- Night dealer (F32): three slots rolled from the tier's weights at night start and at each window, gone by
	-- day. Every Buy is answered with fresh stock, as the server does. N opens the cart (the prompt in the game).
	local dealerStock: Types.DealerStock? = nil
	local dealerGift = false
	local function rollDealer()
		local weights = Catalog.dealerSlotWeights -- v0.5 F43: one row for everyone
		local total = 0
		for _, weight in weights do
			total += weight
		end
		local slots: { Types.DealerSlot } = {}
		for _ = 1, 3 do
			local roll = math.random() * total
			local pick = "sardines"
			for lureId, weight in weights do
				roll -= weight
				if weight > 0 and roll <= 0 then
					pick = lureId
					break
				end
			end
			table.insert(
				slots,
				{ lureId = pick, cost = Catalog.luresById[pick].cost, bought = false }
			)
		end
		local stock: Types.DealerStock = { slots = slots, restocksAt = now() + DEMO_DEALER_WINDOW }
		dealerStock = stock
		UI.dealer.setStock(stock)
	end
	-- the server refuses a slot whose food changed with a restock (S42)
	local function buyDealer(slot: number, lureId: string)
		local stock = dealerStock
		if not stock then
			return
		end
		local entry = stock.slots[slot]
		if entry and entry.lureId == lureId and not entry.bought and spend(entry.cost) then
			entry.bought = true
			profile.lures[entry.lureId] = (profile.lures[entry.lureId] or 0) + 1
			local name = Catalog.luresById[entry.lureId].name
			UI.toast("Bought " .. name .. ". Use it in your bait bowl!", "good")
			push()
		end
		UI.dealer.setStock(stock)
	end
	connections[#connections + 1] = UI.events.buyDealerFood:Connect(buyDealer)
	connections[#connections + 1] = UserInputService.InputBegan:Connect(
		function(input: InputObject, processed: boolean)
			if not processed and input.KeyCode == Enum.KeyCode.N then
				UI.dealer.open()
			end
		end
	)
	connections[#connections + 1] = UI.events.placeCat:Connect(
		function(catUid: string, spotId: string)
			local instance = profile.cats[catUid]
			if not instance then
				return
			end
			for _, other in profile.cats do
				if other.spotId == spotId then
					UI.toast("That spot is taken", "warn")
					return
				end
			end
			instance.spotId = spotId
			UI.toast(catById[instance.catId].name .. " placed on " .. spotId, "good")
			push()
		end
	)
	connections[#connections + 1] = UI.events.unplaceCat:Connect(function(catUid: string)
		local instance = profile.cats[catUid]
		if instance then
			instance.spotId = nil
			push()
		end
	end)
	connections[#connections + 1] = UI.events.sellCat:Connect(function(catUid: string)
		local instance = profile.cats[catUid]
		if instance then
			local def = catById[instance.catId]
			profile.cats[catUid] = nil
			profile.money += SELL_VALUE[def.rarity] or 0
			UI.toast(("Sold %s for $%d"):format(def.name, SELL_VALUE[def.rarity] or 0), "good")
			push()
		end
	end)
	-- the server filters the name before anyone else sees it; the demo keeps it as typed
	connections[#connections + 1] = UI.events.renameCat:Connect(
		function(catUid: string, name: string)
			local instance = profile.cats[catUid]
			if instance then
				instance.name = name
				UI.toast(("Renamed to %s"):format(name), "good")
				push()
			end
		end
	)
	connections[#connections + 1] = UI.events.equipBest:Connect(function()
		UI.toast("Equip best: the server would place your top cats", "info")
	end)
	connections[#connections + 1] = UI.events.unequipAll:Connect(function()
		local rested = 0
		for _, instance in profile.cats do
			if instance.spotId then
				instance.spotId = nil
				rested += 1
			end
		end
		UI.toast(("%d cats are resting in the cat room."):format(rested), "info")
		push()
	end)
	connections[#connections + 1] = UI.events.travel:Connect(function(destination: string)
		UI.toast(
			if destination == "home"
				then "Travel: the server would take you to your cafe"
				else ("Travel: the server would take you to %s"):format(
					Format.areaName(destination)
				),
			"info"
		)
		UI.travel.result(destination, true)
	end)
	connections[#connections + 1] = UI.events.dropCat:Connect(function()
		UI.setCarrying(nil)
		UI.toast("Dropped: the server would set the cat down with you on the first try", "info")
	end)
	connections[#connections + 1] = UI.events.claimOffline:Connect(function()
		profile.money += 312
		UI.toast("+$312 claimed", "good")
		push()
	end)
	connections[#connections + 1] = UI.events.rankUp:Connect(function()
		local progress = RankUp.progress(CATALOG, UI.getState())
		local nextTier = progress.nextTier
		if progress.ready and nextTier and spend(nextTier.cost) then
			profile.tier = nextTier.tier
			UI.close()
			UI.announce(("Your cafe is now a %s!"):format(nextTier.name))
			push()
		end
	end)

	-- Pretend server for the closing circles: the schedule is made here, presses are stamped on arrival and
	-- graded against each circle's target. Data-model 10 step 5: the first Miss ends the catch and the cat runs
	-- off for a moment (v0.5, tries are unlimited), no Miss catches, and every Perfect adds 4 charm (doubled when
	-- all are Perfect).
	local function demoCatch(catId: string)
		local def = catById[catId]
		local rarity: string = if def then def.rarity else "Common"
		local spec = DEMO_CIRCLES[rarity] or DEMO_CIRCLES.Common
		local strayId = "demo_stray_" .. catId
		UI.catch.show({
			catId = catId,
			strayId = strayId,
			stars = 3,
			press = true,
		})
		task.wait(1.2)
		local start = Workspace:GetServerTimeNow() + 0.6
		local schedule: { Types.CatchCircle } = {}
		for _ = 1, spec.count do
			local shrink = spec.shrink * (1 + (math.random() * 0.6 - 0.3))
			table.insert(schedule, {
				startsAt = start,
				shrinkSeconds = shrink,
				x = math.random(),
				y = math.random(),
			})
			start += shrink + 0.35 + math.random() * 0.35
		end
		local grades: { Types.CircleGrade } = {}
		local missed = false
		local connection = UI.events.catchPressed:Connect(function(id: string, index: number)
			local circle = schedule[index]
			if id ~= strayId or not circle or missed or index ~= #grades + 1 then
				return
			end
			local offset =
				math.abs(Workspace:GetServerTimeNow() - (circle.startsAt + circle.shrinkSeconds))
			local grade: Types.CircleGrade = if offset <= DEMO_WINDOWS.perfect
				then "perfect"
				elseif offset <= DEMO_WINDOWS.good then "good"
				else "miss"
			table.insert(grades, grade)
			missed = grade == "miss"
		end)
		UI.catch.showCircles(strayId, schedule, DEMO_WINDOWS)
		-- judge until a Miss, the last circle, or a circle's deadline passing with no press
		while not missed and #grades < #schedule do
			local circle = schedule[#grades + 1]
			if
				Workspace:GetServerTimeNow()
				> circle.startsAt + circle.shrinkSeconds + DEMO_WINDOWS.good + 0.15
			then
				local miss: Types.CircleGrade = "miss"
				table.insert(grades, miss)
				missed = true
			else
				task.wait(0.05)
			end
		end
		connection:Disconnect()
		local success = not missed
		local perfects = 0
		for _, grade in grades do
			if grade == "perfect" then
				perfects += 1
			end
		end
		local charm = if success then perfects * 4 * (if perfects == #schedule then 2 else 1) else 0
		UI.catch.showGrades(strayId, grades, success, nil, charm)
		task.wait(1.8)
		UI.catch.hide()
		if success then
			UI.setCarrying({ catId = catId })
			task.wait(3)
			UI.setCarrying(nil)
		end
	end

	push()
	UI.toast("Demo mode: pretend server, pretend money", "info")

	-- Rescue minigame (F27): the pretend server judges each press with the same marker maths as the real one
	local demoRescue: Types.RescueChallenge? = nil
	local rescueHits, rescuePaws = 0, 0
	local function startDemoRescue()
		local challenge: Types.RescueChallenge = {
			kind = "bar",
			startsAt = Workspace:GetServerTimeNow() + 0.6,
			phase = 0,
			speed = 1.0,
			zoneWidth = 0.24,
			zones = { 0.72, 0.3, 0.55 },
			hitsNeeded = 3,
			paws = 3,
		}
		demoRescue = challenge
		rescueHits, rescuePaws = 0, 3
		UI.rescue.show("demo_rescue_1", challenge)
	end
	connections[#connections + 1] = UI.events.rescuePressed:Connect(function(spotId: string)
		local challenge = demoRescue
		if not challenge then
			return
		end
		local t = Workspace:GetServerTimeNow()
		local position =
			RescueMarker.position(challenge.startsAt, challenge.phase or 0, challenge.speed or 1, t)
		local zones: { number } = challenge.zones or {}
		local centre = zones[rescueHits + 1] or 0.5
		if RescueMarker.inZone(position, centre, challenge.zoneWidth or 0.3, 0.03) then
			rescueHits += 1
		else
			rescuePaws -= 1
		end
		local success = rescueHits >= (challenge.hitsNeeded or #zones)
		local done = success or rescuePaws <= 0
		if done then
			demoRescue = nil
		end
		UI.rescue.update(spotId, rescueHits, rescuePaws, done, success)
	end)
	connections[#connections + 1] = UI.events.rescueCancelled:Connect(function()
		demoRescue = nil
	end)

	-- clock: a short day and night so the chip can be seen flipping (real lengths are 180 s and 120 s)
	task.spawn(function()
		local phase: Types.ClockPhase = "day"
		while running do
			local length = if phase == "day" then 45 else 30
			UI.clock.set(phase, now() + length)
			task.wait(length)
			phase = if phase == "day" then "night" else "day"
			if running then
				UI.toast(
					if phase == "night"
						then "Night falls. Strays are out!"
						else "Morning. The cafe opens.",
					"info"
				)
				if phase == "night" then
					rollDealer()
					if not dealerGift then
						-- pretend coins so the demo can buy from him
						dealerGift = true
						profile.money += 5000
						push()
					end
					UI.toast("The night dealer is on the street. Press N to see his cart.", "info")
				else
					dealerStock = nil
					UI.dealer.setStock(nil)
				end
			end
		end
	end)

	-- the dealer restocks when his window ends, while it is still night
	task.spawn(function()
		while running do
			task.wait(0.5)
			local stock = dealerStock
			if stock and now() >= stock.restocksAt + 1 then
				rollDealer()
			end
		end
	end)

	-- money ticks, a cat shows up every 25 s, one ring demo near the start
	task.spawn(function()
		task.wait(2)
		if running then
			UI.showOfflineEarnings(312, 1245)
		end
		task.wait(3)
		if running then
			-- v0.3 net: one Common circle, then three Epic circles
			demoCatch("tabby")
			task.wait(2)
			demoCatch("sphynx")
			UI.tutorial.show("Place your new cat: open Cats, then the Cat room tab")
			task.wait(6)
			UI.tutorial.hide()
			-- rescue minigame (F27): a Rare in a bin, three hits with Rare speed and zone width
			task.wait(3)
			UI.catch.show({
				kind = "rescue",
				catId = "calico",
				rescueSpotId = "demo_rescue_1",
				press = true,
			})
			task.wait(1)
			startDemoRescue()
		end
	end)
	task.spawn(function()
		local sinceCat = 0
		while running do
			local dt = task.wait(0.5)
			profile.money += rate() * dt
			sinceCat += dt
			if sinceCat >= 25 then
				sinceCat = 0
				local pool = CATALOG.cats
				local def = pool[math.random(1, #pool)]
				local newUid = uid()
				-- one in five is shiny here (5% in the game) so the cat room's gold cards show up
				local shiny = math.random() < 0.2
				profile.cats[newUid] = {
					uid = newUid,
					catId = def.id,
					variant = if shiny then "shiny" else "base",
					caughtAt = now(),
					spotId = nil,
				}
				local isNew = profile.collection[def.id] == nil
				profile.collection[def.id] = now()
				-- the demo rolls stars and a Purrfect bonus so the reveal shows every part
				UI.showCatFound(def.id, isNew, {
					shiny = shiny,
					stars = math.random(1, 5),
					charmGain = if math.random() < 0.3 then math.random(2, 6) else nil,
				})
				if def.rarity == "Epic" or def.rarity == "Legendary" then
					UI.announce(
						("Someone caught %s %s %s!"):format(
							if def.rarity:match("^[AEIOU]") then "an" else "a",
							def.rarity,
							def.name
						)
					)
				end
			end
			UI.update({ money = math.floor(profile.money), incomePerSecond = rate() })
			if sinceCat == 0 then
				push()
			end
		end
	end)

	return function()
		running = false
		for _, connection in connections do
			connection:Disconnect()
		end
	end
end

return Demo
