--!strict
-- #5038: at Tier 2 a new kind waits by the Park landing, the goal card names one next thing, and a welcome gift
-- tops the coins up once toward Tier 3 (shared/Tier3Path).

return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared:WaitForChild("Catalog"))
	local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
	local ProfileSchema = require(Shared:WaitForChild("ProfileSchema"))
	local Tier3Path = require(Shared:WaitForChild("Tier3Path"))

	local tier3 = Catalog.getTier(3) :: any

	-- the plain kinds of `rarity` that count toward Tier 3, Park ones first
	local function kinds(rarity: string, area: string?): { any }
		local list = {}
		for _, def in Catalog.cats do
			if
				def.rarity == rarity
				and def.exclusive ~= true
				and def.area ~= "harvest"
				and def.area ~= "secret"
				and (area == nil or def.area == area)
			then
				table.insert(list, def)
			end
		end
		return list
	end

	-- a Tier 2 save holding `commons` Common kinds and `rares` Rare kinds (none from the Park), with `coins`
	local function save(commons: number, rares: number, coins: number): any
		local profile = ProfileSchema.template(1000) :: any
		profile.tier = 2
		profile.coins = coins
		profile.cats = {}
		profile.collection = {}
		local n = 0
		local function add(def: any)
			n += 1
			profile.collection[def.id] = 1
			profile.cats["u" .. n] = { uid = "u" .. n, catId = def.id }
		end
		local c, r = 0, 0
		for _, def in kinds("Common") do
			if c < commons and def.area ~= "park" then
				add(def)
				c += 1
			end
		end
		for _, def in kinds("Rare") do
			if r < rares and def.area ~= "park" then
				add(def)
				r += 1
			end
		end
		assert(c == commons and r == rares, "not enough sample kinds")
		return profile
	end

	describe("Tier3Path", function()
		it("is a live switch that starts off", function()
			expect(table.find(LiveFlags.KEYS, Tier3Path.FLAG) ~= nil).to.equal(true)
			expect(LiveFlags.OFF_BY_DEFAULT[Tier3Path.FLAG]).to.equal(true)
			expect(LiveFlags.defaults()[Tier3Path.FLAG]).to.equal(false)
		end)

		it("asks for the kinds first, then the Rares, and nothing off Tier 2", function()
			local short = save(2, 0, 0)
			expect(Tier3Path.need(short)).to.equal("kinds")
			expect(Tier3Path.kindsShort(short)).to.equal(tier3.distinctCats - 2)
			local kindsMet = save(tier3.distinctCats, 0, 0)
			expect(Tier3Path.need(kindsMet)).to.equal("rare")
			expect(Tier3Path.raresShort(kindsMet)).to.equal(tier3.needsRarityCount)
			local met = save(tier3.distinctCats - tier3.needsRarityCount, tier3.needsRarityCount, 0)
			expect(Tier3Path.need(met)).to.equal(nil)
			local tier1 = save(2, 0, 0)
			tier1.tier = 1
			expect(Tier3Path.need(tier1)).to.equal(nil)
		end)

		it(
			"lets only a plain Park kind the player lacks wait, a Rare once the kinds are met",
			function()
				local profile = save(2, 0, 0)
				local parkCommon = kinds("Common", "park")[1]
				local parkRare = kinds("Rare", "park")[1]
				local alleyCommon = kinds("Common", "alley")[1]
				expect(Tier3Path.fits(profile, parkCommon, "base", "kinds")).to.equal(true)
				expect(Tier3Path.fits(profile, parkCommon, "gold", "kinds")).to.equal(false)
				expect(Tier3Path.fits(profile, alleyCommon, "base", "kinds")).to.equal(false)
				expect(Tier3Path.fits(profile, parkCommon, "base", "rare")).to.equal(false)
				expect(Tier3Path.fits(profile, parkRare, "base", "rare")).to.equal(true)
				profile.collection[parkCommon.id] = 1
				expect(Tier3Path.fits(profile, parkCommon, "base", "kinds")).to.equal(false)
				local legendary = kinds("Legendary", "park")[1]
				if legendary ~= nil then
					expect(Tier3Path.fits(profile, legendary, "base", "rare")).to.equal(false)
				end
				local fresh = save(2, 0, 0)
				expect(Tier3Path.spawnRarity(fresh, "kinds")).to.equal("Common")
				expect(Tier3Path.spawnRarity(fresh, "rare")).to.equal("Rare")
				-- every Park Common owned: the kinds ask a Rare; every Park Rare owned too: nothing to bring in
				for _, def in kinds("Common", "park") do
					fresh.collection[def.id] = 1
				end
				expect(Tier3Path.spawnRarity(fresh, "kinds")).to.equal("Rare")
				for _, def in kinds("Rare", "park") do
					fresh.collection[def.id] = 1
				end
				expect(Tier3Path.spawnRarity(fresh, "kinds")).to.equal(nil)
				expect(Tier3Path.spawnRarity(fresh, "rare")).to.equal(nil)
			end
		)

		it("names one next thing on the goal card", function()
			local short = save(4, 0, 0)
			local left = tier3.distinctCats - 4
			expect(Tier3Path.goalLine(short)).to.equal(
				string.format("Catch %d more new kinds", left)
			)
			expect(Tier3Path.goalLine(short, true)).to.equal(
				string.format("Catch %d new kinds", left)
			)
			expect(Tier3Path.goalLine(save(tier3.distinctCats - 1, 0, 0))).to.equal(
				"Catch 1 more new kind"
			)
			expect(Tier3Path.goalLine(save(tier3.distinctCats - 1, 1, 0))).to.equal(
				"Catch 1 more Rare"
			)
			expect(Tier3Path.goalLine(save(tier3.distinctCats - 2, 2, 0))).to.equal(nil)
		end)

		it(
			"pays the welcome gift once, capped, never past Tier 3's cost, only with the switch on",
			function()
				local met = save(tier3.distinctCats - 2, 2, 0)
				expect(Tier3Path.topUpFor(met, false)).to.equal(0)
				expect(Tier3Path.topUpFor(met, true)).to.equal(Tier3Path.GIFT_MAX)
				local near = save(tier3.distinctCats - 2, 2, tier3.cost - 500)
				expect(Tier3Path.topUpFor(near, true)).to.equal(500)
				local rich = save(tier3.distinctCats - 2, 2, tier3.cost + 1)
				expect(Tier3Path.topUpFor(rich, true)).to.equal(0)
				expect(Tier3Path.giftLine(15000)).to.equal("Welcome gift: +$15,000 toward Tier 3")
				met.stats.tier3TopUp = 100
				expect(Tier3Path.topUpFor(met, true)).to.equal(0)
				expect(Tier3Path.topUpFor(save(2, 0, 0), true)).to.equal(0)
			end
		)
	end)
end
