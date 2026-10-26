--!strict
-- The shared catalog plus a pretend server, so the UI runs in Studio with no backend.
-- Usage from any LocalScript: require the UI module and call UI.demo()
-- Everything here is client-side pretend money. Delete or leave unused in production.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local RankUp = require(script.Parent.Screens.RankUp)
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
		equippedLure = nil :: string?,
		cats = {} :: { [string]: Types.CatInstance },
		collection = { tabby = now() } :: { [string]: number },
		tier = 1,
	}
	local starter = uid()
	profile.cats[starter] = {
		uid = starter,
		catId = "tabby",
		variant = "base",
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
			equippedLure = profile.equippedLure,
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
				if not profile.equippedLure then
					profile.equippedLure = lureId
				end
				push()
			end
		end
	end)
	connections[#connections + 1] = UI.events.equipLure:Connect(function(lureId: string)
		if (profile.lures[lureId] or 0) > 0 then
			profile.equippedLure = lureId
			push()
		end
	end)
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
	connections[#connections + 1] = UI.events.equipBest:Connect(function()
		UI.toast("Equip best: the server would place your top cats", "info")
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

	-- Pretend server for the closing circles: the schedule is made here, presses are stamped on
	-- arrival and judged against each circle's target, then the chance is rolled (data-model 10).
	local function demoCatch(catId: string)
		local def = catById[catId]
		local rarity: string = if def then def.rarity else "Common"
		local spec = DEMO_CIRCLES[rarity] or DEMO_CIRCLES.Common
		local strayId = "demo_stray_" .. catId
		UI.catch.show({ catId = catId, strayId = strayId, stars = 3, press = true })
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
		local scores: { number } = table.create(#schedule, 0)
		local pressed: { [number]: boolean } = {}
		local connection = UI.events.catchPressed:Connect(function(id: string, index: number)
			local circle = schedule[index]
			if id ~= strayId or not circle or pressed[index] then
				return
			end
			pressed[index] = true
			local offset =
				math.abs(Workspace:GetServerTimeNow() - (circle.startsAt + circle.shrinkSeconds))
			scores[index] = if offset <= DEMO_WINDOWS.perfect
				then 1
				elseif offset <= DEMO_WINDOWS.good then 0.5
				else 0
		end)
		UI.catch.showCircles(strayId, schedule, DEMO_WINDOWS)
		local last = schedule[#schedule]
		task.wait(
			last.startsAt
				+ last.shrinkSeconds
				+ DEMO_WINDOWS.good
				+ 0.2
				- Workspace:GetServerTimeNow()
		)
		connection:Disconnect()
		local total = 0
		for _, score in scores do
			total += score
		end
		local chance = total / #scores
		local success = math.random() < chance
		UI.catch.showResult(strayId, scores, chance, success)
		task.wait(1.8)
		UI.catch.hide()
		if success then
			UI.setCarrying({ catId = catId })
			task.wait(3)
			UI.setCarrying(nil)
		end
	end

	connections[#connections + 1] = UI.events.rescueEnded:Connect(
		function(_rescueSpotId: string?, _catId: string?, completed: boolean)
			if completed then
				UI.toast("Rescued! A real server would hand you the cat now", "good")
			end
		end
	)

	push()
	UI.toast("Demo mode: pretend server, pretend money", "info")

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
			-- rescue prompt: the 4 s bar, no ring
			task.wait(3)
			UI.catch.show({ kind = "rescue", catId = "calico", rescueSpotId = "demo_rescue_1" })
			task.wait(0.8)
			UI.catch.startRescue(4)
			task.wait(4.2)
			UI.catch.stopRescue(true)
			task.wait(1.2)
			UI.catch.hide()
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
				profile.cats[newUid] = {
					uid = newUid,
					catId = def.id,
					variant = "base",
					caughtAt = now(),
					spotId = nil,
				}
				local isNew = profile.collection[def.id] == nil
				profile.collection[def.id] = now()
				UI.showCatFound(def.id, isNew)
				if def.rarity == "Epic" or def.rarity == "Legendary" then
					UI.announce(("Someone caught a %s %s!"):format(def.rarity, def.name))
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
