--!strict
-- The stray waiting for your second cat (#3022): a gentle beacon inside the phone budgets.
-- Written by the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Presets = require(Client:WaitForChild("Effects"):WaitForChild("Presets")) :: any
	local Logic = require(Client:WaitForChild("Effects"):WaitForChild("Logic")) :: any

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

		it("waits while the bowl step is the one ask, and only then (#4384)", function()
			local p = Presets.waitingCat
			expect(p.holdStep).to.equal(4)
			expect(Logic.waitingHeld(p.holdStep, 1, 0)).to.equal(true)
			for _, step in { 0, 1, 2, 3, 5, 6 } do
				expect(Logic.waitingHeld(step, 1, 0)).to.equal(false)
			end
			-- a step not yet known holds nothing
			expect(Logic.waitingHeld(nil, 1, 0)).to.equal(false)
			-- no Bait bowl yet (or not known yet): the beacon to the free second cat stays
			expect(Logic.waitingHeld(p.holdStep, 0, 0)).to.equal(false)
			expect(Logic.waitingHeld(p.holdStep, nil, 0)).to.equal(false)
			-- and never for long, so nobody is left with no next step
			expect(p.holdMost >= 60 and p.holdMost <= 300).to.equal(true)
			expect(Logic.waitingHeld(p.holdStep, 1, p.holdMost - 1)).to.equal(true)
			expect(Logic.waitingHeld(p.holdStep, 1, p.holdMost)).to.equal(false)
			-- #4654: no switch any more
			expect(p.holdSwitch).never.to.be.ok()
		end)
	end)
end
