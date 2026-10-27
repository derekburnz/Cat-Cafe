--!strict
-- Dealer.luau against data-model section 8b: the night dealer's stock, shared by every player on every server in
-- the same window since v0.5 F43, drawn from the one DealerSlotWeights row, with bought marks cleared only when the
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
		it("is the same three dealer foods for everyone in a window (F43)", function()
			local first = Dealer.stock(2900000)
			local again = Dealer.stock(2900000)
			expect(#first).to.equal(Dealer.SLOTS)
			for slot = 1, Dealer.SLOTS do
				expect(first[slot]).to.equal(again[slot])
				local def = Catalog.getLure(first[slot])
				expect(def).to.be.ok()
				expect((def :: any).source).to.equal("dealer")
			end
		end)

		it("changes from window to window", function()
			local differs = 0
			for window = 2900000, 2900019 do
				local a, b = Dealer.stock(window), Dealer.stock(window + 1)
				for slot = 1, Dealer.SLOTS do
					if a[slot] ~= b[slot] then
						differs += 1
					end
				end
			end
			expect(differs > 20).to.equal(true)
		end)

		it("follows DealerSlotWeights over many windows", function()
			local weights = Catalog.dealerSlotWeights
			local counts: { [string]: number } = {}
			local total = 0
			for window = 1, 4000 do
				for _, lureId in Dealer.stock(2900000 + window * 7) do
					counts[lureId] = (counts[lureId] or 0) + 1
					total += 1
				end
			end
			local weightTotal = 0
			for _, weight in weights do
				weightTotal += weight
			end
			for lureId, weight in weights do
				expect((counts[lureId] or 0) / total).to.be.near(weight / weightTotal, 0.03)
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

		it("counts every slot as bought while the window is behind the saved one (N32)", function()
			local state = { window = 10, bought = {} }
			Dealer.refresh(state, 9)
			expect(Dealer.behind(state, 9)).to.equal(true)
			expect(Dealer.behind(state, 10)).to.equal(false)
			Dealer.refresh(state, 11)
			expect(Dealer.behind(state, 11)).to.equal(false)
		end)
	end)
end
