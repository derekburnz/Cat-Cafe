--!strict
-- Fake catalog (data-model.md v0.1) and a pretend server, so the UI runs in Studio with no backend.
-- Usage from any LocalScript:  require(path.to.UI).demo()
-- Everything here is client-side pretend money. Delete or leave unused in production.

local Demo = {}

local function now(): number
	return os.time()
end

local CATALOG = {
	cats = {
		{
			id = "tabby",
			name = "Tabby",
			rarity = "Common",
			incomePerSecond = 1,
			area = "both",
			favoriteSpot = "counter",
			description = "The starter. Stripes, snacks, naps.",
			color = { 233, 162, 75 },
		},
		{
			id = "tuxedo",
			name = "Tuxedo",
			rarity = "Common",
			incomePerSecond = 1,
			area = "both",
			favoriteSpot = "window",
			description = "Dressed for dinner, waiting for it.",
			color = { 43, 43, 53 },
		},
		{
			id = "ginger",
			name = "Ginger",
			rarity = "Common",
			incomePerSecond = 1,
			area = "both",
			favoriteSpot = "cushion",
			description = "Warm, round, always in the sun.",
			color = { 217, 123, 75 },
		},
		{
			id = "smoke",
			name = "Smoke",
			rarity = "Common",
			incomePerSecond = 1,
			area = "both",
			favoriteSpot = "shelf",
			description = "Grey as a rainy morning.",
			color = { 138, 143, 153 },
		},
		{
			id = "snow",
			name = "Snow",
			rarity = "Common",
			incomePerSecond = 1,
			area = "both",
			favoriteSpot = "window",
			description = "All white, hates the alley puddles.",
			color = { 247, 241, 230 },
		},
		{
			id = "calico",
			name = "Calico",
			rarity = "Rare",
			incomePerSecond = 3,
			area = "both",
			favoriteSpot = "cushion",
			description = "Three colors, three opinions.",
			color = { 240, 200, 150 },
		},
		{
			id = "siamese",
			name = "Siamese",
			rarity = "Rare",
			incomePerSecond = 3,
			area = "both",
			favoriteSpot = "counter",
			description = "Loud. Supervises the espresso machine.",
			color = { 232, 214, 186 },
		},
		{
			id = "tortie",
			name = "Tortie",
			rarity = "Rare",
			incomePerSecond = 3,
			area = "park",
			favoriteSpot = "shelf",
			description = "Brindled and bossy.",
			color = { 120, 80, 50 },
		},
		{
			id = "bengal",
			name = "Bengal",
			rarity = "Rare",
			incomePerSecond = 3,
			area = "park",
			favoriteSpot = "cattree",
			description = "Spotted and fast. Climbs everything.",
			color = { 214, 150, 80 },
		},
		{
			id = "sphynx",
			name = "Sphynx",
			rarity = "Epic",
			incomePerSecond = 8,
			area = "both",
			favoriteSpot = "cushion",
			description = "No fur, all attitude. Loves the warm cushion.",
			color = { 232, 160, 160 },
		},
		{
			id = "ragdoll",
			name = "Ragdoll",
			rarity = "Epic",
			incomePerSecond = 8,
			area = "park",
			favoriteSpot = "cattree",
			description = "Huge, fluffy, goes limp when carried.",
			color = { 225, 225, 232 },
		},
		{
			id = "void",
			name = "Void",
			rarity = "Legendary",
			incomePerSecond = 25,
			area = "both",
			favoriteSpot = "shelf",
			description = "Pure black with glowing eyes. Appears when you stop looking.",
			color = { 25, 22, 30 },
		},
	},
	upgrades = {
		{
			id = "cafe_level",
			name = "Cafe level",
			description = "Opens new cat spots and unlocks more of the shop",
			maxLevel = 5,
			costs = { 0, 250, 800, 2500, 8000 },
			startLevel = 1,
		},
		{
			id = "tables",
			name = "Tables",
			description = "Each table seats two more customers and adds tips",
			maxLevel = 6,
			costs = { 100, 250, 600, 1500, 3500, 8000 },
			startLevel = 0,
		},
		{
			id = "espresso",
			name = "Espresso machine",
			description = "Better coffee, bigger tips from every cat",
			maxLevel = 3,
			costs = { 0, 300, 1200 },
			startLevel = 1,
			requiresCafeLevelAtLevel = { [3] = 3 },
		},
		{
			id = "gloves",
			name = "Catching gloves",
			description = "Steadier hands: better odds on every grab",
			maxLevel = 3,
			costs = { 500, 2500, 10000 },
			startLevel = 0,
		},
		{
			id = "lure_bowl",
			name = "Lure bowl",
			description = "Unlocks luring with food at lure spots",
			maxLevel = 1,
			costs = { 400 },
			startLevel = 0,
			requiresCafeLevel = 2,
		},
		{
			id = "park_access",
			name = "Park pass",
			description = "Opens the park, where rarer cats roam",
			maxLevel = 1,
			costs = { 1000 },
			startLevel = 0,
			requiresCafeLevel = 3,
		},
	},
	decor = {
		{
			id = "plants",
			name = "Window plants",
			cost = 150,
			category = "Plants",
			effect = "+5% tips",
		},
		{ id = "rug", name = "Cozy rug", cost = 400, category = "Floor", effect = "+5% tips" },
		{
			id = "neon_sign",
			name = "Neon cat sign",
			cost = 1500,
			category = "Wall",
			effect = "+10% tips",
			requiresCafeLevel = 4,
		},
		{
			id = "fish_tank",
			name = "Fish tank",
			cost = 5000,
			category = "Furniture",
			effect = "+10% tips, cats stare at it",
			requiresCafeLevel = 4,
		},
	},
	lures = {
		{
			id = "kibble",
			name = "Kibble",
			cost = 25,
			attracts = "Common",
			description = "Cheap and crunchy. Brings the regulars.",
			odds = { Common = 70, Rare = 26, Epic = 3.5, Legendary = 0.5 },
		},
		{
			id = "tuna",
			name = "Tuna",
			cost = 100,
			attracts = "Rare",
			description = "The good stuff. Rare cats come running.",
			odds = { Common = 45, Rare = 42, Epic = 11, Legendary = 2 },
		},
		{
			id = "salmon",
			name = "Salmon",
			cost = 500,
			attracts = "Epic",
			description = "Nobody can resist it, not even the Void.",
			odds = { Common = 15, Rare = 50, Epic = 28, Legendary = 7 },
		},
	},
	spots = {
		{ id = "counter_1", spotType = "counter", cafeLevel = 1 },
		{ id = "window_1", spotType = "window", cafeLevel = 1 },
		{ id = "cushion_1", spotType = "cushion", cafeLevel = 2 },
		{ id = "shelf_1", spotType = "shelf", cafeLevel = 3 },
		{ id = "cattree_1", spotType = "cattree", cafeLevel = 4 },
		{ id = "patio_1", spotType = "patio", cafeLevel = 5 },
		{ id = "patio_2", spotType = "patio", cafeLevel = 5 },
	},
}

local DECOR_BONUS: { [string]: number } =
	{ plants = 0.05, rug = 0.05, neon_sign = 0.10, fish_tank = 0.10 }
local SELL_VALUE: { [string]: number } = { Common = 25, Rare = 150, Epic = 600, Legendary = 3000 }

function Demo.run(UI: any): () -> ()
	local running = true
	local nextUid = 1
	local function uid(): string
		nextUid += 1
		return "demo_" .. tostring(nextUid)
	end

	local catById: { [string]: any } = {}
	for _, def in CATALOG.cats do
		catById[def.id] = def
	end

	local profile = {
		money = 50,
		upgradeLevels = { cafe_level = 1, espresso = 1 } :: { [string]: number },
		decorOwned = {} :: { [string]: boolean },
		decorPlaced = {} :: { [string]: boolean },
		lures = {} :: { [string]: number },
		equippedLure = nil :: string?,
		cats = {} :: { [string]: any },
		collection = { tabby = now() } :: { [string]: number },
	}
	local starter = uid()
	profile.cats[starter] =
		{ uid = starter, catId = "tabby", variant = "base", caughtAt = now(), spotId = "counter_1" }

	local spotType: { [string]: string } = {}
	for _, spot in CATALOG.spots do
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
				local favorite = def.favoriteSpot == spotType[instance.spotId]
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

	local connections = {}
	table.insert(
		connections,
		UI.events.buyUpgrade:Connect(function(upgradeId: string)
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
	)
	table.insert(
		connections,
		UI.events.buyDecor:Connect(function(decorId: string)
			for _, def in CATALOG.decor do
				if def.id == decorId and not profile.decorOwned[decorId] and spend(def.cost) then
					profile.decorOwned[decorId] = true
					profile.decorPlaced[decorId] = true
					UI.toast(def.name .. " placed", "good")
					push()
				end
			end
		end)
	)
	table.insert(
		connections,
		UI.events.toggleDecor:Connect(function(decorId: string, placed: boolean)
			if profile.decorOwned[decorId] then
				profile.decorPlaced[decorId] = placed
				push()
			end
		end)
	)
	table.insert(
		connections,
		UI.events.buyLure:Connect(function(lureId: string)
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
	)
	table.insert(
		connections,
		UI.events.equipLure:Connect(function(lureId: string)
			if (profile.lures[lureId] or 0) > 0 then
				profile.equippedLure = lureId
				push()
			end
		end)
	)
	table.insert(
		connections,
		UI.events.placeCat:Connect(function(catUid: string, spotId: string)
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
		end)
	)
	table.insert(
		connections,
		UI.events.unplaceCat:Connect(function(catUid: string)
			local instance = profile.cats[catUid]
			if instance then
				instance.spotId = nil
				push()
			end
		end)
	)
	table.insert(
		connections,
		UI.events.sellCat:Connect(function(catUid: string)
			local instance = profile.cats[catUid]
			if instance then
				local def = catById[instance.catId]
				profile.cats[catUid] = nil
				profile.money += SELL_VALUE[def.rarity] or 0
				UI.toast(("Sold %s for $%d"):format(def.name, SELL_VALUE[def.rarity] or 0), "good")
				push()
			end
		end)
	)
	table.insert(
		connections,
		UI.events.claimOffline:Connect(function()
			profile.money += 312
			UI.toast("+$312 claimed", "good")
			push()
		end)
	)
	table.insert(
		connections,
		UI.events.grabEnded:Connect(function(_strayId: string?, result: string)
			UI.toast("Ring result: " .. result, "info")
		end)
	)

	push()
	UI.toast("Demo mode: pretend server, pretend money", "info")

	-- money ticks, a cat shows up every 25 s, one ring demo near the start
	task.spawn(function()
		task.wait(2)
		if running then
			UI.showOfflineEarnings(312, 1245)
		end
		task.wait(3)
		if running then
			UI.catch.show({ catId = "void", strayId = "demo_stray" })
			task.wait(0.8)
			UI.catch.startRing({ duration = 1.5 })
			task.wait(1.0)
			UI.catch.stopRing()
			task.wait(1.2)
			UI.catch.hide()
			UI.setCarrying({ catId = "void" })
			task.wait(4)
			UI.setCarrying(nil)
			UI.tutorial.show("Place your new cat: open Cats, then the Cat room tab")
			task.wait(6)
			UI.tutorial.hide()
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
