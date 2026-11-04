--!strict
-- The shop-only cats' effects (#1191): Sprinkles' sprinkle puff stays one small rainbow burst, no more often than
-- the brief allows, and Duchess Marzipan's petals are one modest emitter that lies still in Low performance, all
-- inside the phone budget. Written by the vfx-animator for QA to move into tests/specs.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects shop cats", function()
		it("puffs Sprinkles at most once every 20 s", function()
			local s = Presets.shopCats.sprinkles
			expect(s.catId).to.equal("sprinkles") -- Design-Agent's id on #1191
			expect(s.gap >= 20).to.equal(true)
		end)

		it("is one small rainbow burst", function()
			local s = Presets.shopCats.sprinkles
			expect(#s.colours >= 5).to.equal(true)
			expect(#s.colours * s.each <= 12).to.equal(true)
			expect(Presets.emitters.sprinkle ~= nil).to.equal(true)
			expect(Presets.emitters.sprinkle.rate).to.equal(0) -- a burst, never a steady stream
		end)

		it("glows briefly instead with Reduce Motion", function()
			local g = Presets.shopCats.sprinkles.glow
			expect(g.seconds > 0 and g.seconds <= 2).to.equal(true)
			expect(g.brightness > 0).to.equal(true)
		end)

		it("drifts Duchess Marzipan's petals on one modest emitter, near the player only", function()
			local d = Presets.shopCats.duchess
			expect(d.catId).to.equal("duchess_marzipan") -- Design-Agent's id on #1191
			local petal = Presets.emitters.lilacPetal
			expect(petal ~= nil and petal.rate > 0 and petal.rate <= 2).to.equal(true)
			expect(d.within <= 60).to.equal(true)
		end)

		it("keeps her petals still in Low performance and inside the budget", function()
			local b = Presets.budget
			expect(b.lowPerformance.shopCatEmitters).to.equal(0) -- the still petals on her spot instead
			expect(b.low.shopCatEmitters >= 1).to.equal(true)
			expect(b.low.shopCatEmitters <= b.high.shopCatEmitters).to.equal(true)
			expect(#Presets.shopCats.duchess.still.spots >= 1).to.equal(true)
			expect(Presets.shopCats.duchess.shift.sparkles <= 12).to.equal(true)
		end)
	end)
end
