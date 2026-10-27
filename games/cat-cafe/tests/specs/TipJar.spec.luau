--!strict
-- shared/TipJar.luau and Catalog.tipJar: the Tip Jar's playtime gifts (F47, data-model section 11b).
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Catalog = require(ReplicatedStorage.Shared.Catalog)
	local TipJar = require(ReplicatedStorage.Shared.TipJar)

	describe("Catalog.tipJar (section 11b table)", function()
		-- step -> { minutes, kind, seconds or lureId, minCoins or count }
		local expected: { { any } } = {
			{ 2, "coins", 30, 50 },
			{ 5, "lure", "kibble", 2 },
			{ 10, "coins", 60, 100 },
			{ 15, "lure", "tuna", 1 },
			{ 20, "coins", 90, 150 },
			{ 30, "lure", "tuna", 2 },
			{ 40, "coins", 120, 250 },
			{ 50, "lure", "salmon", 1 },
			{ 60, "coins", 180, 400 },
			{ 75, "lure", "sardines", 1 },
			{ 90, "coins", 300, 600 },
			{ 120, "lure", "caviar", 1 },
		}

		it("has the twelve steps in order, each at its own index", function()
			expect(#Catalog.tipJar).to.equal(#expected)
			for index, def in ipairs(Catalog.tipJar) do
				local row = expected[index]
				expect(def.step).to.equal(index)
				expect(def.minutes).to.equal(row[1])
				expect(def.kind).to.equal(row[2])
				if def.kind == "coins" then
					expect(def.seconds).to.equal(row[3])
					expect(def.minCoins).to.equal(row[4])
					expect(def.lureId).never.to.be.ok()
				else
					expect(def.lureId).to.equal(row[3])
					expect(def.count).to.equal(row[4])
					expect(def.seconds).never.to.be.ok()
				end
			end
		end)

		it("unlocks later with every step, and every food is a real lure", function()
			for index, def in ipairs(Catalog.tipJar) do
				if index > 1 then
					expect(def.minutes > Catalog.tipJar[index - 1].minutes).to.equal(true)
				end
				if def.kind == "lure" then
					expect(Catalog.getLure(def.lureId :: string)).to.be.ok()
				end
			end
		end)
	end)

	describe("TipJar rules", function()
		local first = Catalog.tipJar[1] -- 2 minutes, 30 s of day rate, at least 50
		local last = Catalog.tipJar[12] -- 120 minutes, 1 Caviar

		it("a step is ready once the session has run its minutes", function()
			expect(TipJar.unlocksAfter(first)).to.equal(120)
			expect(TipJar.isReady(first, 1000, 1119.9)).to.equal(false)
			expect(TipJar.isReady(first, 1000, 1120)).to.equal(true)
			expect(TipJar.isReady(last, 1000, 1000 + 7199)).to.equal(false)
			expect(TipJar.isReady(last, 1000, 1000 + 7200)).to.equal(true)
		end)

		it("a coins step pays its seconds of day rate, never under its floor", function()
			expect(TipJar.coins(first, 0)).to.equal(50)
			expect(TipJar.coins(first, 1.5)).to.equal(50) -- 45 is under the floor
			expect(TipJar.coins(first, 10)).to.equal(300)
			expect(TipJar.coins(first, 10.55)).to.equal(316) -- floored
			expect(TipJar.coins(first, -5)).to.equal(50)
			expect(TipJar.coins(Catalog.tipJar[11], 100)).to.equal(30000)
		end)

		it("a food step pays no coins", function()
			expect(TipJar.coins(last, 1000)).to.equal(0)
		end)

		it("a fresh session has every step unclaimed, as a dense array", function()
			local claimed = TipJar.unclaimed()
			expect(#claimed).to.equal(#Catalog.tipJar)
			for _, flag in ipairs(claimed) do
				expect(flag).to.equal(false)
			end
			expect(TipJar.step(3)).to.equal(Catalog.tipJar[3])
			expect(TipJar.step(13)).never.to.be.ok()
		end)
	end)
end
