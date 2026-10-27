--!strict
-- Dealer.luau against data-model section 8b: the night dealer's per-player stock, the same on every server for the
-- same UserId, window and tier, drawn from the tier's DealerSlotWeights, with bought marks cleared only when the
-- window moves forward (reviewer N32).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local Dealer = require(Shared.Dealer)

	describe("windows", function()
		it("are DealerWindowSeconds long and restock at the next one", function()
			local w = Config.DealerWindowSeconds
			expect(Dealer.window(0)).to.equal(0)
			expect(Dealer.window(w - 1)).to.equal(0)
			expect(Dealer.window(w)).to.equal(1)
			expect(Dealer.restocksAt(Dealer.window(w * 5 + 30))).to.equal(w * 6)
		end)
	end)

	describe("stock", function()
		it("is the same for the same player, window and tier, with three dealer foods", function()
			local first = Dealer.stock(123456, 2900000, 3)
			local again = Dealer.stock(123456, 2900000, 3)
			expect(#first).to.equal(Dealer.SLOTS)
			for slot = 1, Dealer.SLOTS do
				expect(first[slot]).to.equal(again[slot])
				local def = Catalog.getLure(first[slot])
				expect(def).to.be.ok()
				expect((def :: any).source).to.equal("dealer")
			end
		end)

		it("works for Studio's negative test UserIds", function()
			expect(#Dealer.stock(-1, 2900000, 1)).to.equal(Dealer.SLOTS)
		end)

		it("never offers a food the tier gives no weight (Star Treat at Tier 1)", function()
			for userId = 1, 300 do
				for _, lureId in Dealer.stock(userId, 2900000, 1) do
					expect(lureId ~= "star_treat").to.equal(true)
				end
			end
		end)

		it("follows the tier's weights over many players and windows", function()
			for tier, weights in Catalog.dealerSlotWeights do
				local counts: { [string]: number } = {}
				local total = 0
				for userId = 1, 400 do
					for window = 1, 5 do
						for _, lureId in Dealer.stock(userId * 7919, 2900000 + window, tier) do
							counts[lureId] = (counts[lureId] or 0) + 1
							total += 1
						end
					end
				end
				local weightTotal = 0
				for _, weight in weights do
					weightTotal += weight
				end
				for lureId, weight in weights do
					expect((counts[lureId] or 0) / total).to.be.near(weight / weightTotal, 0.03)
				end
			end
		end)

		it("pick walks the weights in catalog order and clamps the roll", function()
			local weights = { sardines = 1, caviar = 1, moon_milk = 0, star_treat = 2 }
			expect(Dealer.pick(weights, 0)).to.equal("sardines")
			expect(Dealer.pick(weights, 0.3)).to.equal("caviar")
			expect(Dealer.pick(weights, 0.6)).to.equal("star_treat")
			expect(Dealer.pick(weights, 1)).to.equal("star_treat")
			expect(Dealer.pick(weights, -2)).to.equal("sardines")
		end)
	end)

	describe("refresh", function()
		it("clears the bought marks only when the window moves forward", function()
			local state = { window = 10, bought = { ["1"] = true } }
			Dealer.refresh(state, 10)
			expect(state.bought["1"]).to.equal(true)
			Dealer.refresh(state, 9) -- another server a second behind at the edge
			expect(state.window).to.equal(10)
			expect(state.bought["1"]).to.equal(true)
			Dealer.refresh(state, 11)
			expect(state.window).to.equal(11)
			expect(state.bought["1"]).never.to.be.ok()
		end)
	end)
end
