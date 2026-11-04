--!strict
-- The shop-only cats' effects (#1191): Sprinkles' sprinkle puff stays one small rainbow burst, no more often than
-- the brief allows, inside the phone budget. Written by the vfx-animator for QA to move into tests/specs.
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
	end)
end
