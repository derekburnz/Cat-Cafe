--!strict
-- The pity cat's lasting mark (#2099, luck-and-rare-moments.md 1j): the ground ring breathing from 90 to 100% of
-- its size over 2 s and back. The ring and sparkles on a real stray are a Studio row.
-- Written by the Animation-Engineer.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local m = Presets.pity.mark

	describe("pity mark breath", function()
		it(
			"starts small, is full size after breathSeconds and small again after twice that",
			function()
				expect(math.abs(Logic.pityBreath(0) - 0.9) < 1e-6).to.equal(true)
				expect(math.abs(Logic.pityBreath(m.breathSeconds) - 1) < 1e-6).to.equal(true)
				expect(math.abs(Logic.pityBreath(m.breathSeconds * 2) - 0.9) < 1e-6).to.equal(true)
			end
		)
		it("stays between 90 and 100%", function()
			for i = 0, 40 do
				local k = Logic.pityBreath(i * 0.17)
				expect(k >= 0.9 - 1e-6 and k <= 1 + 1e-6).to.equal(true)
			end
		end)
		it("is gold for a Legendary and violet for a Mythical", function()
			expect(m.legendary).to.equal(Presets.palette.golden)
			expect(m.mythical).to.equal(Presets.palette.aurora)
		end)
	end)
end
