--!strict
-- Effects/MoneyBag (#3360): the drop and collect beats of a rich customer's money bag, keyed off the plot's
-- RichBags display records. Written by the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local MoneyBag = require(Effects:WaitForChild("MoneyBag")) :: any

	describe("Effects money bag", function()
		it("drops only for a new waiting bag", function()
			expect(MoneyBag.beat(nil, true)).to.equal("drop")
			expect(MoneyBag.beat(nil, false)).to.equal(nil)
		end)

		it("pops only for a claimed bag", function()
			expect(MoneyBag.beat("claimed", false)).to.equal("collect")
			expect(MoneyBag.beat("claimed", true)).to.equal("collect")
			expect(MoneyBag.beat("missed", false)).to.equal(nil)
			expect(MoneyBag.beat("missed", true)).to.equal(nil)
			expect(MoneyBag.beat(42, true)).to.equal(nil)
		end)

		it("stays inside the budgets", function()
			local p = Presets.moneyBag
			expect(p.dropSparkles <= Presets.budget.low.maxBurst).to.equal(true)
			expect(p.collectSparkles <= Presets.budget.high.maxBurst).to.equal(true)
			expect(p.confetti <= Presets.confetti.maxLive).to.equal(true)
			expect(p.dropRing < p.collectRing).to.equal(true)
			expect(p.within > 0).to.equal(true)
		end)
	end)
end
