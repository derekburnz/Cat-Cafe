--!strict
-- The Ticket Booth's buy moment (#4061, Effects/BoothFx): when it plays and that it stays inside the phone budgets.
-- Written by the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local BoothFx = require(Effects:WaitForChild("BoothFx")) :: any

	describe("Effects Ticket Booth", function()
		it("plays only when tickets spent went up", function()
			expect(BoothFx.bought({ spent = 10 }, { spent = 60 })).to.equal(true)
			expect(BoothFx.bought({ spent = 10 }, { spent = 10 })).to.equal(false)
			expect(BoothFx.bought({ spent = 60 }, { spent = 0 })).to.equal(false) -- a save reset
		end)

		it("stays quiet when the booth is off or the view is odd", function()
			expect(BoothFx.bought(nil, { spent = 60 })).to.equal(false)
			expect(BoothFx.bought({ spent = 10 }, nil)).to.equal(false)
			expect(BoothFx.bought({ spent = "10" }, { spent = 60 })).to.equal(false)
			expect(BoothFx.bought({}, {})).to.equal(false)
		end)

		it("keeps the burst within the phone's caps", function()
			local p = Presets.boothFx
			expect(p.sparkles <= Presets.budget.low.maxBurst).to.equal(true)
			expect(p.tickets > 0 and p.tickets <= 1).to.equal(true)
			expect(#p.colours >= 2).to.equal(true)
			expect(Presets.emitters.catchSparkle).to.be.ok()
			expect(p.tag).to.equal("TicketBooth")
		end)
	end)
end
