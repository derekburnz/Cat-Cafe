--!strict
-- The Grand Opening ribbon cut (#1922, first-hour.md 1d): a short, bouncy snap and gentle balloons. Written by the
-- vfx-animator for QA to move into tests/specs.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects grand opening", function()
		it("snaps at the last roadmap step, quickly", function()
			local g = Presets.grandOpening
			expect(g.lastStep).to.equal(8)
			expect(g.swing + g.fade <= 1.5).to.equal(true)
			expect(g.degrees > 0 and g.degrees <= 90).to.equal(true)
			expect(g.confetti > 0 and g.confetti <= 1).to.equal(true)
		end)

		it("swings with a small bounce that settles at 1", function()
			expect(Logic.easeOutBack(0)).to.equal(0)
			expect(math.abs(Logic.easeOutBack(1) - 1) < 1e-6).to.equal(true)
			expect(Logic.easeOutBack(0.8) > 1).to.equal(true)
		end)

		it("bobs only a few balloon clusters a little", function()
			local g = Presets.grandOpening
			expect(g.wobble > 0 and g.wobble <= 8).to.equal(true)
			expect(g.most >= 1 and g.most <= 6).to.equal(true)
		end)
	end)
end
