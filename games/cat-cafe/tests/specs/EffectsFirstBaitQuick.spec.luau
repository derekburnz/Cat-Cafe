--!strict
-- Effects/FirstBaitCut's quick scene (#5548, baitCutQuick): about 1.5 s with the cat on time, a 3 s cap, one bite,
-- and never a "skipped" outcome. Off keeps today's numbers.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local FirstBaitCut = { preset = Logic.firstBaitPreset, outcome = Logic.firstBaitOutcome }
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("FirstBaitCut quick", function()
		it("keeps today's numbers with the switch off", function()
			local p = FirstBaitCut.preset(false)
			expect(p.swingIn).to.equal(Presets.firstBaitCut.swingIn)
			expect(p.cap).to.equal(5.5)
			expect(p.waitCat).to.equal(3.0)
		end)

		it("runs about 1.5 s with the cat on time and caps at 3 s", function()
			local p = FirstBaitCut.preset(true)
			local length = p.swingIn + p.walk + p.eat + p.swingOut
			expect(math.abs(length - 1.5) < 1e-6).to.equal(true)
			expect(p.cap).to.equal(3.0)
			expect(p.waitCat).to.equal(1.2)
			expect(p.bites).to.equal(1)
			-- the walk fits SlotWalk's 7 studs a second
			expect(p.walkDistance / 7 <= p.walk + 1e-6).to.equal(true)
			-- a late cat still gets back inside the cap
			expect(p.waitCat + p.walkMax + p.eat + p.swingOut <= p.cap).to.equal(true)
			-- the base preset is left as it was
			expect(Presets.firstBaitCut.swingIn).to.equal(0.4)
		end)

		it("never reports skipped on the quick scene", function()
			expect(FirstBaitCut.outcome(true, true, true)).to.equal("shown")
			expect(FirstBaitCut.outcome(true, false, true)).to.equal("none")
			expect(FirstBaitCut.outcome(true, true, false)).to.equal("skipped")
			expect(FirstBaitCut.outcome(false, true, false)).to.equal("shown")
			expect(FirstBaitCut.outcome(false, false, false)).to.equal("none")
		end)
	end)
end
