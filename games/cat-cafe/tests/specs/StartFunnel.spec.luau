--!strict
-- shared/StartFunnel (#5551): first_five_v1, the play first start's first five minutes as one ordered funnel.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local StartFunnel = require(Shared.StartFunnel)

	describe("StartFunnel.STEPS", function()
		it("is Growth's 23 steps in order, each named once", function()
			expect(StartFunnel.COUNT).to.equal(23)
			expect(StartFunnel.STEPS[1]).to.equal("loaded")
			expect(StartFunnel.STEPS[16]).to.equal("park_flight")
			expect(StartFunnel.STEPS[23]).to.equal("tier_3")
			for index, name in StartFunnel.STEPS do
				expect(StartFunnel.INDEX[name]).to.equal(index)
			end
		end)
		it("times only milestones that are steps", function()
			for name in StartFunnel.TIMED do
				expect(StartFunnel.INDEX[name]).never.to.equal(nil)
			end
		end)
	end)

	describe("StartFunnel.due", function()
		it("fills every earlier step not yet logged", function()
			local out = StartFunnel.due(2, 5)
			expect(#out).to.equal(3)
			expect(out[1]).to.equal(3)
			expect(out[3]).to.equal(5)
		end)
		it("logs nothing for a step already passed, and never past the end", function()
			expect(#StartFunnel.due(8, 5)).to.equal(0)
			expect(#StartFunnel.due(5, 5)).to.equal(0)
			expect(#StartFunnel.due(22, 99)).to.equal(1)
			expect(#StartFunnel.due(-3, 1)).to.equal(1)
		end)
	end)

	describe("saved values", function()
		it("clamps firstFiveStep and startSide", function()
			expect(StartFunnel.validStep(nil)).to.equal(nil)
			expect(StartFunnel.validStep("3")).to.equal(nil)
			expect(StartFunnel.validStep(2.5)).to.equal(nil)
			expect(StartFunnel.validStep(0 / 0)).to.equal(nil)
			expect(StartFunnel.validStep(99)).to.equal(StartFunnel.COUNT)
			expect(StartFunnel.validStep(-1)).to.equal(0)
			expect(StartFunnel.validSide(9999)).to.equal(StartFunnel.SIDE_ALL)
			expect(StartFunnel.validSide(5)).to.equal(5)
		end)
		it("gives each side kind its own bit", function()
			local mask = 0
			for _, kind in StartFunnel.SIDE do
				local bit = StartFunnel.sideBit(kind) :: number
				expect(StartFunnel.has(mask, bit)).to.equal(false)
				mask += bit
				expect(StartFunnel.has(mask, bit)).to.equal(true)
			end
			expect(mask).to.equal(StartFunnel.SIDE_ALL)
			expect(StartFunnel.sideBit("nope")).to.equal(nil)
		end)
		it("lets a client report only what the screen sees", function()
			for _, kind in StartFunnel.CLIENT_SIDE do
				expect(StartFunnel.sideBit(kind)).never.to.equal(nil)
			end
		end)
	end)
end
