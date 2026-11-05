--!strict
-- The shop-only cats' effects (#1191): Sprinkles' sprinkle puff stays one small rainbow burst, no more often than
-- the brief allows, Duchess Marzipan's petals are one modest emitter that lies still in Low performance, and King
-- Croissant's glow, motes, trim shine and crown pop stay small, all inside the phone budget. Written by the vfx-animator for QA to move into tests/specs.
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

		it("gives King Croissant one gold glow, one mote emitter and a crown pop at most every 20 s", function()
			local k = Presets.shopCats.king
			expect(k.catId).to.equal("king_croissant") -- Design-Agent's id on #1191
			expect(k.pop.gap >= 20).to.equal(true)
			expect(k.pop.sparkles + k.pop.stars <= 16).to.equal(true) -- one burst
			local mote = Presets.emitters.goldMote
			expect(mote ~= nil and mote.rate > 0 and mote.rate <= 3).to.equal(true)
			expect(k.most >= 1 and k.most <= 3).to.equal(true)
			expect(k.glow.brightness > 0 and k.glow.brightness <= 1.5).to.equal(true)
			expect(k.trim.speed > 0 and k.trim.tile > 0).to.equal(true)
		end)

		it("sweeps the Royal Crest's shine once every 8 s, quickly, on a few signs", function()
			local r = Presets.shopCats.royalCrest
			expect(r.every).to.equal(8) -- Design-Agent's brief on #1191
			expect(r.sweep > 0 and r.sweep < r.every).to.equal(true)
			expect(r.most >= 1 and r.most <= 4).to.equal(true)
			expect(r.model).to.equal("CatCafe_Plot_SignRoyalCrest_Frame") -- Model-Agent, #1289
			expect(r.part).to.equal("Frame")
		end)
	end)
end
