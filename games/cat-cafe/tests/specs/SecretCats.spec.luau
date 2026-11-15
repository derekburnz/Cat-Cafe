--!strict
-- #3470: Secret cats, the rarity above Mythical. A rolled Mythical turns Secret Catalog.secretPerMythical of the time
-- while the `secretCats` switch is on (Catching.secret), so no odds table lists it; it is on no Index page and in no
-- count, earns at its owner's best open area, and every rule keyed by rarity knows it.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Catching = require(Shared.Catching)
	local CatStats = require(Shared.CatStats)
	local Circles = require(Shared.Circles)
	local Config = require(Shared.Config)
	local GlobalCatch = require(Shared.GlobalCatch)
	local GoldenFish = require(Shared.GoldenFish)
	local IndexRewards = require(Shared.IndexRewards)
	local LiveFlags = require(Shared.LiveFlags)
	local Moods = require(Shared.Moods)
	local NetSwing = require(Shared.NetSwing)
	local Rescue = require(Shared.Rescue)
	local Types = require(Shared.Types)

	local ROLLS = 100000

	-- One source's rolls as the services make them: a rarity from `odds`, then the Secret turn.
	local function tally(odds: Types.LureOdds, on: boolean, seed: number): { [string]: number }
		local random = Random.new(seed)
		local counts: { [string]: number } = {}
		for _ = 1, ROLLS do
			local rarity = Catching.pickRarity(odds, random:NextNumber())
			local secret = Catching.secret(rarity, random:NextNumber(), random:NextNumber(), on)
			local got: string = if secret ~= nil then secret.rarity else rarity
			counts[got] = (counts[got] or 0) + 1
		end
		return counts
	end

	describe("the catalog", function()
		it("has ten Secret cats of no area, the first three not new", function()
			expect(#Catalog.secretCats).to.equal(10)
			local new = 0
			for _, def in Catalog.secretCats do
				if def.secretNew then
					new += 1
				end
			end
			expect(new).to.equal(7)
			for _, id in { "nebula", "glitch", "cafe_ghost" } do
				expect((Catalog.getCat(id) :: Types.CatDef).secretNew).to.equal(nil)
			end
			for _, def in Catalog.secretCats do
				expect(def.rarity).to.equal("Secret")
				expect(def.area).to.equal("secret")
				expect(Catalog.getArea(def.area)).to.equal(nil)
				expect(def.exclusive).to.equal(nil)
				expect(def.incomePerSecond).to.equal(300)
				expect(Catalog.getCat(def.id)).to.equal(def)
			end
		end)

		it("ranks Secret over Mythical and keeps the odds order at five", function()
			expect(#Catalog.rarityOrder).to.equal(5)
			expect(table.find(Catalog.rarityOrder :: { string }, "Secret")).to.equal(nil)
			expect(Catalog.rarityRank.Secret > Catalog.rarityRank.Mythical).to.equal(true)
			expect(Catching.rarityAtLeast("Secret", "Mythical")).to.equal(true)
			expect(Catalog.catRarityOrder[#Catalog.catRarityOrder]).to.equal("Secret")
		end)

		it("earns four times a Mythical", function()
			expect(Catalog.rarities.Secret.incomePerSecond).to.equal(
				4 * Catalog.rarities.Mythical.incomePerSecond
			)
		end)

		it("starts with its switch off", function()
			expect(LiveFlags.OFF_BY_DEFAULT[Catching.SECRET_FLAG]).to.equal(true)
			expect(LiveFlags.parse({})[Catching.SECRET_FLAG]).to.equal(false)
		end)
	end)

	describe("the Secret turn", function()
		it("never happens with the switch off", function()
			for index, area in Catalog.areas do
				local counts = tally(area.odds, false, index)
				expect(counts.Secret).to.equal(nil)
			end
			for index, lure in Catalog.lures do
				expect(tally(lure.odds, false, 100 + index).Secret).to.equal(nil)
			end
			-- and a roll that would turn any Mythical does nothing
			expect(Catching.secret("Mythical", 0, 0, false)).to.equal(nil)
		end)

		it("turns only a Mythical, and only under secretPerMythical", function()
			for _, rarity: Types.Rarity in Catalog.rarityOrder do
				local got = Catching.secret(rarity, 0, 0, true)
				expect(got ~= nil).to.equal(rarity == "Mythical")
			end
			expect(Catching.secret("Mythical", Catalog.secretPerMythical - 1e-6, 0, true) ~= nil).to.equal(
				true
			)
			expect(Catching.secret("Mythical", Catalog.secretPerMythical, 0, true)).to.equal(nil)
			expect(Catching.secret("Mythical", 0.999, 0, true)).to.equal(nil)
		end)

		it("picks the first three evenly while secretAreas is off (no area list)", function()
			local list =
				{ Catalog.getCat("nebula"), Catalog.getCat("glitch"), Catalog.getCat("cafe_ghost") }
			expect(Catalog.secretCats[1]).to.equal(list[1])
			expect(Catalog.secretCats[2]).to.equal(list[2])
			expect(Catalog.secretCats[3]).to.equal(list[3])
			for step = 0, 999 do
				local def = Catching.secret("Mythical", 0, step / 1000, true) :: Types.CatDef
				expect(def.secretNew).to.equal(nil)
			end
			expect(Catching.secret("Mythical", 0, 0, true)).to.equal(list[1])
			expect(Catching.secret("Mythical", 0, 0.34, true)).to.equal(list[2])
			expect(Catching.secret("Mythical", 0, 0.67, true)).to.equal(list[3])
			expect(Catching.secret("Mythical", 0, 0.999999, true)).to.equal(list[3])
			expect(Catching.secret("Mythical", 0, 1, true)).to.equal(list[3])
		end)

		-- #4221: one Secret per area
		it("gives each Secret one home area, and no two the same", function()
			local seen: { [string]: string } = {}
			for _, def in Catalog.secretCats do
				expect(def.area).to.equal("secret")
				local home = def.secretArea
				expect(home ~= nil).to.equal(true)
				-- (a home area that is not in the game yet, like the Snowy Mountain before Sunday, just rolls nothing)
				expect(seen[home :: string]).to.equal(nil)
				seen[home :: string] = def.id
			end
			expect((Catalog.getCat("cafe_ghost") :: Types.CatDef).secretArea).to.equal("alley")
			expect((Catalog.getCat("glitch") :: Types.CatDef).secretArea).to.equal("neighbourhood")
			expect((Catalog.getCat("nebula") :: Types.CatDef).secretArea).to.equal("snowy")
			-- Derek 2026-11-14: the other seven, one per area
			local homes: { [string]: string } = {
				lucky_clover = "park",
				moonstag = "woods",
				ooze = "sewer",
				djinn = "desert",
				phoenix = "ruins",
				abyss = "waterpark",
				excalipurr = "castle",
			}
			-- Model-Agent's model names (#4250)
			local models: { [string]: string } = {
				lucky_clover = "CatCafe_Cat_LuckyClover",
				moonstag = "CatCafe_Cat_Moonstag",
				ooze = "CatCafe_Cat_Ooze",
				djinn = "CatCafe_Cat_Djinn",
				phoenix = "CatCafe_Cat_Phoenix",
				abyss = "CatCafe_Cat_Abyss",
				excalipurr = "CatCafe_Cat_Excalipurr",
			}
			for id, home in homes do
				local def = Catalog.getCat(id) :: Types.CatDef
				expect(def.secretArea).to.equal(home)
				expect(def.secretNew).to.equal(true)
				expect(Catalog.catModelName(id)).to.equal(models[id])
			end
		end)

		it("gives an area's Mythical only that area's Secret", function()
			for _, pick in { 0, 0.5, 0.999999 } do
				expect(Catching.secret("Mythical", 0, pick, true, { "alley" })).to.equal(
					Catalog.getCat("cafe_ghost")
				)
				expect(Catching.secret("Mythical", 0, pick, true, { "neighbourhood" })).to.equal(
					Catalog.getCat("glitch")
				)
				expect(Catching.secret("Mythical", 0, pick, true, { "snowy" })).to.equal(
					Catalog.getCat("nebula")
				)
			end
		end)

		it("gives the new seven only through their own area, and nothing for no area", function()
			for _, pick in { 0, 0.5, 0.999999 } do
				expect(Catching.secret("Mythical", 0, pick, true, { "park" })).to.equal(
					Catalog.getCat("lucky_clover")
				)
				expect(Catching.secret("Mythical", 0, pick, true, { "castle" })).to.equal(
					Catalog.getCat("excalipurr")
				)
			end
			expect(Catching.secret("Mythical", 0, 0, true, {})).to.equal(nil)
			-- and the odds and the switch still rule an area that has one
			expect(Catching.secret("Mythical", Catalog.secretPerMythical, 0, true, { "alley" })).to.equal(
				nil
			)
			expect(Catching.secret("Mythical", 0, 0, false, { "alley" })).to.equal(nil)
			expect(Catching.secret("Legendary", 0, 0, true, { "alley" })).to.equal(nil)
		end)

		it("gives a bait bowl the Secrets of the areas its tier opens, evenly", function()
			local function secretsAt(tier: number): { [string]: boolean }
				local got: { [string]: boolean } = {}
				for step = 0, 99 do
					local def =
						Catching.secret("Mythical", 0, step / 100, true, Catching.baitAreas(tier))
					if def ~= nil then
						got[def.id] = true
					end
				end
				return got
			end
			local one = secretsAt(1)
			expect(one.cafe_ghost).to.equal(true)
			expect(one.glitch).to.equal(nil)
			expect(one.lucky_clover).to.equal(nil)
			expect(one.nebula).to.equal(nil)
			local three = secretsAt(3)
			expect(three.cafe_ghost and three.glitch).to.equal(true)
			expect(three.nebula).to.equal(nil)
			expect(three.lucky_clover).to.equal(true)
			expect(three.moonstag).to.equal(nil)
			local eight = secretsAt(8)
			expect(eight.cafe_ghost and eight.glitch).to.equal(true)
			-- Nebula's Snowy Mountain opens at Tier 8 once the area is in the Catalog
			expect(eight.nebula).to.equal(if Catalog.getArea("snowy") ~= nil then true else nil)
			-- the bowl's areas are the ones pickBaitCat draws from
			for _, id in Catching.baitAreas(3) do
				expect((Catalog.getArea(id) :: Types.AreaDef).tier <= 3).to.equal(true)
			end
		end)

		it("takes a hundredth of the Mythical share and moves no other rarity", function()
			-- the same seed with the switch off and on: the rarity rolls are the same numbers, so every rarity but
			-- Mythical has exactly the same count, and Mythical plus Secret is the old Mythical
			local odds: Types.LureOdds =
				{ Common = 0, Rare = 0, Epic = 20, Legendary = 30, Mythical = 50 }
			local off, on = tally(odds, false, 7), tally(odds, true, 7)
			expect(on.Epic).to.equal(off.Epic)
			expect(on.Legendary).to.equal(off.Legendary)
			expect((on.Mythical or 0) + (on.Secret or 0)).to.equal(off.Mythical)
			-- about 50,000 Mythicals, so about 500 Secrets (3 sigma is about 67)
			local secrets = on.Secret or 0
			expect(secrets > 400 and secrets < 600).to.equal(true)
		end)

		it("is never picked by the area, bait or rescue tables themselves", function()
			for _, area in Catalog.areas do
				for _, rarity: Types.Rarity in Catalog.catRarityOrder do
					for _, def in Catching.candidates(rarity, area.id) do
						expect(def.rarity == "Secret").to.equal(false)
					end
				end
				expect(Catching.pickCat("Mythical", area.id, 0.5).rarity).to.equal("Mythical")
			end
			for tier = 1, 7 do
				for _, rarity: Types.Rarity in Catalog.rarityOrder do
					for step = 0, 9 do
						local def = Catching.pickBaitCat(rarity, tier, step / 10)
						expect(def.rarity == "Secret").to.equal(false)
					end
				end
			end
		end)
	end)

	describe("rules keyed by rarity", function()
		it("give every cat rarity a catch, a rescue, a mood and a sprint", function()
			local random = Random.new(11)
			local function roll(): number
				return random:NextNumber()
			end
			for _, rarity: Types.Rarity in Catalog.catRarityOrder do
				for _, area in Catalog.areas do
					local circles = Circles.schedule(rarity, 1, 100, roll, area.id)
					expect(#circles >= 1).to.equal(true)
					expect(#circles <= Circles.maxCircles()).to.equal(true)
					local windows = Circles.windowsFor(3, rarity, area.id, "base")
					expect(windows.good > 0).to.equal(true)
					local challenge =
						Rescue.newChallenge(rarity, "cage", 100, roll, nil, area.id, nil)
					expect((challenge.speed or 0) > 0).to.equal(true)
					expect(#(challenge.zones or {}) >= 1).to.equal(true)
				end
				expect(Circles.trustFor(rarity).need > 0).to.equal(true)
				expect(type(Moods.roll(rarity, 0.5))).to.equal("string")
				expect(Catching.fleeStuds(rarity) > 0).to.equal(true)
				expect(NetSwing.hopStuds(rarity) > 0).to.equal(true)
				expect(Config.RescueBarSpeed[rarity] ~= nil).to.equal(true)
				expect(Config.RescueZoneWidth[rarity] ~= nil).to.equal(true)
				expect(Config.CollectorValue[rarity] ~= nil).to.equal(true)
				expect(Config.FishFirstCatch[rarity] ~= nil).to.equal(true)
				expect(GlobalCatch.COLORS[rarity] ~= nil).to.equal(true)
			end
		end)

		it("make the Secret the hardest catch and rescue", function()
			local secret, mythical = Catalog.rarities.Secret, Catalog.rarities.Mythical
			expect(secret.circles).to.equal(8)
			expect(secret.circles > mythical.circles).to.equal(true)
			expect(secret.trustNeed > mythical.trustNeed).to.equal(true)
			expect(secret.fleeStuds > mythical.fleeStuds).to.equal(true)
			expect(secret.rescueHits).to.equal(8)
			expect(Circles.maxCircles() >= 2 * Circles.ringCap("Secret")).to.equal(true)
			expect(Config.RescueBarSpeed.Secret > Config.RescueBarSpeed.Mythical).to.equal(true)
		end)

		it("pay more golden fish than a Mythical", function()
			expect(GoldenFish.forCatch("Secret", true, false, "net")).to.equal(
				Config.FishFirstCatch.Secret
			)
			expect(
				GoldenFish.forCatch("Secret", true, false, "net")
					> GoldenFish.forCatch("Mythical", true, false, "net")
			).to.equal(true)
			expect(GoldenFish.forCatch("Secret", false, false, "bait")).to.equal(0)
		end)

		it("always let a Secret's chat line through", function()
			local gate = GlobalCatch.gate(60)
			expect(GlobalCatch.take(gate, 0, "Legendary")).to.equal(true)
			expect(GlobalCatch.take(gate, 1, "Legendary")).to.equal(false)
			expect(GlobalCatch.take(gate, 2, "Secret")).to.equal(true)
			expect(GlobalCatch.take(gate, 3, "Mythical")).to.equal(true)
		end)
	end)

	describe("income", function()
		it("is the rarity's rate at the owner's best open area", function()
			local def = Catalog.secretCats[1]
			expect(CatStats.areaMultiplier(def)).to.equal(1)
			expect(CatStats.areaMultiplier(def, 1)).to.equal(1)
			local best = 1
			for _, area in Catalog.areas do
				best = math.max(best, area.incomeMultiplier)
				expect(CatStats.areaMultiplier(def, area.tier)).to.equal(best)
			end
			expect(best > 1).to.equal(true)
		end)
	end)

	describe("the Index", function()
		it("counts a Secret on no page and in no total", function()
			local collection: { [string]: number } = {}
			for _, def in Catalog.secretCats do
				collection[def.id] = 1
			end
			expect(IndexRewards.progress(collection, IndexRewards.ALL)).to.equal(0)
			for _, area in Catalog.areas do
				expect(IndexRewards.progress(collection, area.id)).to.equal(0)
			end
			expect(IndexRewards.progress(collection, "secret")).to.equal(0)
		end)
	end)

	-- #3497: the proof before the `secretCats` switch goes on. A build that does not know a cat id drops that cat on
	-- load, and Secret cats came without a save version bump, so every build that may run must know all three ids.
	describe("a save holding Secret cats", function()
		local ProfileSchema = require(Shared.ProfileSchema)
		local NOW = 1_800_000_000
		local SHIPPED = { "cafe_ghost", "glitch", "nebula" } -- #3486, sorted

		local function secretIds(): { string }
			local ids: { string } = {}
			for _, def in Catalog.cats do
				if def.rarity == "Secret" then
					table.insert(ids, def.id)
				end
			end
			table.sort(ids)
			return ids
		end

		it("keeps each one through a load and a second load, in every coat", function()
			local raw: any = ProfileSchema.template(NOW - 3600)
			local held: { [string]: { catId: string, variant: string } } = {}
			for _, catId in secretIds() do
				for _, variant in { "base", "gold", "rainbow" } do
					local uid = catId .. "_" .. variant
					raw.cats[uid] = {
						uid = uid,
						catId = catId,
						variant = variant,
						caughtAt = NOW - 60,
						level = 3,
						xp = 5,
						charm = 77,
					}
					held[uid] = { catId = catId, variant = variant }
				end
			end
			local once: any = ProfileSchema.migrate(raw, NOW)
			local twice: any = ProfileSchema.migrate(once, NOW + 60)
			for _, profile in { once, twice } do
				for uid, want in held do
					local cat = profile.cats[uid]
					expect(cat).to.be.ok()
					expect(cat.catId).to.equal(want.catId)
					expect(cat.variant).to.equal(want.variant)
					expect(cat.level).to.equal(3)
					expect(cat.charm).to.equal(77)
				end
			end
		end)

		it("keeps one in a role, one soaking at the spa and its Index stamps", function()
			local ids = secretIds()
			local raw: any = ProfileSchema.template(NOW - 3600)
			for index, catId in ids do
				raw.cats["s" .. index] = {
					uid = "s" .. index,
					catId = catId,
					variant = "base",
					caughtAt = NOW - 60,
					spotId = if index == 1 then "waiter_1" else nil,
					level = 1,
					xp = 0,
					charm = 50,
				}
				raw.collection[catId] = NOW - 60
			end
			raw.spa = { slots = 1, soaking = { ["1"] = { uid = "s2", at = NOW - 30 } } }
			local profile: any = ProfileSchema.migrate(raw, NOW)
			expect(profile.cats.s1.spotId).to.equal("waiter_1")
			expect(profile.spa.soaking["1"].uid).to.equal("s2")
			for index, catId in ids do
				expect(profile.cats["s" .. index].catId).to.equal(catId)
				expect(profile.collection[catId]).to.be.ok()
				expect((Catalog.getCat(catId) :: any).rarity).to.equal("Secret")
			end
		end)

		it(
			"needs no switch: the load never reads secretCats, and a traded one is made whole",
			function()
				-- ProfileSchema is pure and takes no flags, so a build with the switch off (LiveFlags.OFF_BY_DEFAULT)
				-- loads these saves exactly as above
				expect(LiveFlags.OFF_BY_DEFAULT.secretCats).to.equal(true)
				for _, catId in secretIds() do
					local cat: any =
						ProfileSchema.cleanCat({ uid = "t", catId = catId, variant = "gold" }, NOW)
					expect(cat).to.be.ok()
					expect(cat.catId).to.equal(catId)
					expect(cat.variant).to.equal("gold")
				end
			end
		)

		it("keeps the same three ids the first Secret build shipped, and adds the seven", function()
			-- a renamed or removed id would drop saved cats: change this list only with a migration
			local ids = secretIds()
			for _, id in SHIPPED do
				expect(table.find(ids, id) ~= nil).to.equal(true)
			end
			expect(#ids).to.equal(#SHIPPED + 7)
		end)
	end)

	describe("the lines", function()
		it("name the area and never the cat when one appears", function()
			expect(Catching.waveShoutOut("Secret", "base", "Park")).to.equal(
				"A Secret cat is somewhere in the Park!"
			)
			expect(Catching.waveShoutOut("Secret", "rainbow", "Old Ruins", true)).to.equal(
				"A Secret cat is somewhere in the Old Ruins!"
			)
		end)

		it("name the cat when it is caught", function()
			local def = Catalog.getCat("nebula") :: Types.CatDef
			expect(Catching.shoutOut("Sam", "caught", def, "base")).to.equal(
				"Sam caught a SECRET cat: Nebula!"
			)
			local gold = Catching.shoutOut("Sam", "caught", def, "gold") :: string
			expect(gold:find("SECRET cat: Nebula", 1, true) ~= nil).to.equal(true)
		end)
	end)

	describe("roaming (#3545)", function()
		it(
			"walks three times as fast over three times the reach, still slower than a player",
			function()
				expect(Config.SecretWanderSpeed).to.equal(3 * Config.StrayWanderSpeed)
				expect(Config.SecretWanderRadius).to.equal(3 * Config.StrayWanderRadius)
				expect(Config.SecretWanderPauseScale > 0 and Config.SecretWanderPauseScale < 1).to.equal(
					true
				)
				expect(Config.SecretWanderSpeed < 16).to.equal(true) -- a carrier walks at 16, a player at 20
			end
		)

		it("is never Sleepy, so it never stays put", function()
			for _, u in { 0, 0.1, 0.19, 0.2, 0.5, 0.999999 } do
				expect(Moods.roll(Catalog.SECRET, u) ~= "Sleepy").to.equal(true)
			end
			local weights = Catalog.rarities.Secret.moods
			expect(weights.Sleepy).to.equal(0)
			expect(weights.Sleepy + weights.Curious + weights.Skittish).to.equal(100)
		end)
	end)
end
