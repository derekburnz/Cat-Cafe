--!strict
-- #5300 shared/PerfectCatch and its CatStats rule: which catches mark a cat Perfect, x1.5 with the coat, charm 1x while
-- the switch is on, the one charm 80+ migration and the Cats chip. Each case puts the switch back off.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local PerfectCatch = require(Shared:WaitForChild("PerfectCatch")) :: any
	local CatStats = require(Shared:WaitForChild("CatStats")) :: any
	local Catalog = require(Shared:WaitForChild("Catalog")) :: any
	local Config = require(Shared:WaitForChild("Config")) :: any
	local LiveFlags = require(Shared:WaitForChild("LiveFlags")) :: any
	local Tips = require(Shared:WaitForChild("Tips")) :: any
	local Trade = require(Shared:WaitForChild("Trade")) :: any
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local CatBuffs = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("CatBuffs")
	) :: any

	local catId = Catalog.cats[1].id
	local function cat(variant: string, charm: number, perfect: boolean?): any
		local instance = CatStats.newInstance("u" .. variant .. charm, catId, 1, charm)
		instance.variant = variant
		instance.perfect = perfect
		return instance
	end

	describe("PerfectCatch", function()
		afterEach(function()
			CatStats.setPerfectCatch(false)
		end)

		it("is off by default", function()
			expect(LiveFlags.OFF_BY_DEFAULT[PerfectCatch.FLAG]).to.equal(true)
			expect(table.find(LiveFlags.KEYS, PerfectCatch.FLAG)).to.be.ok()
		end)

		it("marks only a purrfect finish without AutoPress", function()
			expect(PerfectCatch.marks("purrfect", false)).to.equal(true)
			expect(PerfectCatch.marks("purrfect", nil)).to.equal(true)
			expect(PerfectCatch.marks("purrfect", true)).to.equal(false)
			expect(PerfectCatch.marks("great", false)).to.equal(false)
			expect(PerfectCatch.marks("nice", false)).to.equal(false)
			expect(PerfectCatch.marks("bolt", false)).to.equal(false)
			expect(PerfectCatch.marks(nil, false)).to.equal(false)
		end)

		it("pays x1.5 multiplied with the coat and counts charm 1x while on", function()
			local plain = CatStats.rating(cat("base", 50, nil))
			CatStats.setPerfectCatch(true)
			local near = function(a: number, b: number): boolean
				return math.abs(a - b) < 1e-6 * math.max(1, b)
			end
			expect(near(CatStats.rating(cat("base", 50, true)), plain * 1.5)).to.equal(true)
			expect(
				near(CatStats.rating(cat("gold", 50, true)), plain * Config.GoldMultiplier * 1.5)
			).to.equal(true)
			expect(
				near(
					CatStats.rating(cat("rainbow", 50, true)),
					plain * Config.RainbowMultiplier * 1.5
				)
			).to.equal(true)
			-- charm no longer moves the rate
			expect(near(CatStats.rating(cat("base", 100, nil)), plain)).to.equal(true)
			expect(near(CatStats.rating(cat("base", 0, nil)), plain)).to.equal(true)
		end)

		it("leaves charm and pay as before while off", function()
			local plain = CatStats.rating(cat("base", 50, nil))
			expect(CatStats.rating(cat("base", 50, true))).to.equal(plain)
			expect(CatStats.rating(cat("base", 100, nil)) > plain).to.equal(true)
			expect(CatBuffs.charmText(100)).to.equal("Charm +20%")
		end)

		it("marks charm 80 and up once, and counts 51 to 79", function()
			local cats = {
				a = cat("base", 80, nil),
				b = cat("base", 99, nil),
				c = cat("base", 79, nil),
				d = cat("base", 51, nil),
				e = cat("base", 50, nil),
				f = cat("base", 10, nil),
			}
			local seen = {}
			local marked, lower = PerfectCatch.migrate(cats, seen)
			expect(marked).to.equal(2)
			expect(lower).to.equal(2)
			expect(cats.a.perfect).to.equal(true)
			expect(cats.b.perfect).to.equal(true)
			expect(cats.c.perfect).to.equal(nil)
			expect(seen[PerfectCatch.KEY]).to.equal(true)
			cats.g = cat("base", 90, nil) -- a cat that arrives later is not migrated
			marked, lower = PerfectCatch.migrate(cats, seen)
			expect(marked).to.equal(0)
			expect(cats.g.perfect).to.equal(nil)
		end)

		it(
			"keeps the migration key through a load and ClearTips, and TipSeen may not carry it",
			function()
				expect(Tips.sanitizeSeen({ [PerfectCatch.KEY] = true }, false)[PerfectCatch.KEY]).to.equal(
					true
				)
				expect(Tips.cleared({ [PerfectCatch.KEY] = true })[PerfectCatch.KEY]).to.equal(true)
				expect(Tips.seenId(PerfectCatch.KEY)).to.equal(false)
			end
		)

		it("travels with the cat in a trade", function()
			expect(Trade.arrival(cat("base", 50, true), 5).perfect).to.equal(true)
			expect(Trade.arrival(cat("base", 50, nil), 5).perfect).to.equal(nil)
		end)

		it("shows the Perfect chip after the coat only while on", function()
			local chips =
				CatBuffs.chips({ favourite = false, gold = true, perfect = true, level = 1 })
			expect(#chips).to.equal(1)
			CatStats.setPerfectCatch(true)
			chips = CatBuffs.chips({ favourite = false, gold = true, perfect = true, level = 1 })
			expect(#chips).to.equal(2)
			expect(chips[1].kind).to.equal("gold")
			expect(chips[2].kind).to.equal("perfect")
			expect(chips[2].text).to.equal("★ Perfect +50%")
			expect(CatBuffs.charmText(100)).to.equal("")
		end)
	end)
end
