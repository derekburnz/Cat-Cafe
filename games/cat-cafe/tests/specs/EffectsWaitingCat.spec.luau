--!strict
-- The stray waiting for your second cat (#3022): a gentle beacon inside the phone budgets.
-- Written by the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Presets = require(Client:WaitForChild("Effects"):WaitForChild("Presets")) :: any

	describe("Effects waiting cat", function()
		it("has a gentle steady beacon and slow rings", function()
			local p = Presets.waitingCat
			local beacon = Presets.emitters[p.emitter]
			expect(beacon).to.be.ok()
			expect(beacon.rate <= 8).to.equal(true)
			expect(p.ringEvery >= 1 / 3).to.equal(true)
			expect(p.seconds > p.delay).to.equal(true)
			expect(p.attribute).to.equal("WaitsFor")
		end)

		it(
			"keeps a calmer beacon after the bright part and a paw badge seen from afar (#3238)",
			function()
				local p = Presets.waitingCat
				expect(p.calmEvery > p.ringEvery).to.equal(true)
				expect(p.marker.within >= p.within).to.equal(true)
				expect(p.marker.bob > 0).to.equal(true)
				expect(p.marker.seconds >= 1 / 3).to.equal(true)
				expect(type(p.marker.glyph)).to.equal("string")
			end
		)
	end)
end
