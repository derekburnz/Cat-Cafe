--!strict
-- Effects/GuideArrow (#5465): one arrow by the player, pointing flat at the tutorial's target.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local GuideArrow = require(Effects:WaitForChild("GuideArrow")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects guide arrow", function()
		it("lies ahead of the feet, flat toward the target", function()
			local at, forward =
				GuideArrow.place(Vector3.new(0, 1, 0), Vector3.new(0, 30, -40), 4.5, 0)
			expect(math.abs(at.Z + 4.5) < 1e-6).to.equal(true)
			expect(at.Y).to.equal(1)
			expect(math.abs(forward.Z + 1) < 1e-6).to.equal(true)
			expect(forward.Y).to.equal(0)
		end)

		it("has no way to point with the target straight overhead", function()
			local at, forward =
				GuideArrow.place(Vector3.new(2, 0, 3), Vector3.new(2, 50, 3), 4.5, 0)
			expect(at).to.equal(nil)
			expect(forward).to.equal(nil)
		end)

		it("slides within its reach and holds still with Reduce Motion", function()
			local p = Presets.guideArrow
			for t = 0, 3, 0.1 do
				local s = GuideArrow.slide(t, p.reach, p.period, false)
				expect(s >= -1e-6 and s <= p.reach + 1e-6).to.equal(true)
				expect(GuideArrow.slide(t, p.reach, p.period, true)).to.equal(0)
			end
		end)

		it("reads the attributes GuideTrail writes", function()
			expect(Presets.guideArrow.target).to.equal("GuideTarget")
			expect(Presets.guideArrow.colour).to.equal("GuideColour")
		end)
	end)
end
