--!strict
-- Effects/Catch's Perfect catch burst (#5300): when PURRFECT! turns to "+50%" with perfectCatch on, a sky blue burst
-- pops round it. The pure parts: the text match and the preset.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects Perfect catch burst", function()
		it("matches only the +50% word", function()
			expect(Logic.isPerfectPlus("+50%", "+50%")).to.equal(true)
			expect(Logic.isPerfectPlus("  +50% ", "+50%")).to.equal(true)
			expect(Logic.isPerfectPlus("PURRFECT!", "+50%")).to.equal(false)
			expect(Logic.isPerfectPlus("+5%", "+50%")).to.equal(false)
			expect(Logic.isPerfectPlus("", "+50%")).to.equal(false)
		end)

		it("is sky blue, reads the perfectCatch switch and outdoes PURRFECT!'s rings", function()
			local p = Presets.catchWord.perfectPlus
			expect(p.flag).to.equal("perfectCatch")
			expect(p.text).to.equal("+50%")
			local c = p.colour
			expect(c.B > c.R and c.B > c.G).to.equal(true)
			expect(p.rings > Presets.catchWord.words.purrfect.rings).to.equal(true)
			expect(p.watch >= 2.05).to.equal(true) -- the banner's whole hold (CatchCircles RESULT.perfect)
		end)
	end)
end
