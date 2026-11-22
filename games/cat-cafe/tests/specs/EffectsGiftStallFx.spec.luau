--!strict
-- Snowglobe Village's Gift Stall buy sparkle (#5641): the spend read, when it plays and the Reduce Motion count.
-- Written by the vfx-animator.
return function()
	local Effects = game:GetService("StarterPlayer")
		:WaitForChild("StarterPlayerScripts")
		:WaitForChild("Client")
		:WaitForChild("Effects")
	local Fx = require(Effects:WaitForChild("GiftStallFx")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects Gift Stall buy sparkle", function()
		it("reads a spend, never a first value, a rise or a nil", function()
			expect(Fx.spent(nil, 40)).to.equal(nil)
			expect(Fx.spent(40, nil)).to.equal(nil)
			expect(Fx.spent(40, "30")).to.equal(nil)
			expect(Fx.spent(40, 40)).to.equal(nil)
			expect(Fx.spent(40, 55)).to.equal(nil)
			expect(Fx.spent(250, 100)).to.equal(150)
		end)

		it("plays only with the switch on, a spend and the stall in reach", function()
			local within = Presets.giftStallFx.within
			expect(Fx.plays(true, 150, 10, within)).to.equal(true)
			expect(Fx.plays(false, 150, 10, within)).to.equal(false)
			expect(Fx.plays(true, nil, 10, within)).to.equal(false)
			expect(Fx.plays(true, 150, nil, within)).to.equal(false)
			expect(Fx.plays(true, 150, within + 1, within)).to.equal(false)
		end)

		it("halves the sparkles with Reduce Motion and waits on christmasEvent", function()
			expect(Fx.sparkles(12, false)).to.equal(12)
			expect(Fx.sparkles(12, true)).to.equal(6)
			expect(Fx.sparkles(5, true)).to.equal(3)
			expect(Presets.giftStallFx.flag).to.equal("christmasEvent")
			expect(Presets.giftStallFx.tag).to.equal("SnowglobeStall")
		end)
	end)
end
