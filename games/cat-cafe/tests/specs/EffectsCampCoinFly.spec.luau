--!strict
-- Effects/CampCoinFly (#5533 v2): only this player's first three quiet start check-ins, a short rate line that pops and
-- settles, and plain rate words.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local CampCoinFly = require(Effects:WaitForChild("CampCoinFly")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("CampCoinFly", function()
		it("plays for this player's first three check-ins on the quiet start only", function()
			expect(CampCoinFly.due(true, true, 0, 3)).to.equal(true)
			expect(CampCoinFly.due(true, true, 2, 3)).to.equal(true)
			expect(CampCoinFly.due(true, true, 3, 3)).to.equal(false)
			expect(CampCoinFly.due(false, true, 0, 3)).to.equal(false)
			expect(CampCoinFly.due(true, false, 0, 3)).to.equal(false)
			expect(Presets.campCoinFly.checkIns).to.equal(3)
		end)

		it("writes the rate plainly", function()
			expect(CampCoinFly.rateText(12)).to.equal("+12/s")
			expect(CampCoinFly.rateText(0)).to.equal("+0/s")
			expect(CampCoinFly.rateText(15000)).to.equal("+15K/s")
			expect(CampCoinFly.rateText(2300000)).to.equal("+2.3M/s")
			expect(CampCoinFly.rateText(-5)).to.equal("+0/s")
		end)

		it("pops the line in big, settles it and fades it out", function()
			local size0 = CampCoinFly.lineAt(0, 2, 1.6, 0.25, 0.5)
			expect(math.abs(size0 - 1.6) < 1e-6).to.equal(true)
			local size1, clear1 = CampCoinFly.lineAt(1, 2, 1.6, 0.25, 0.5)
			expect(size1).to.equal(1)
			expect(clear1).to.equal(0)
			local _, clear2 = CampCoinFly.lineAt(1.9, 2, 1.6, 0.25, 0.5)
			expect(clear2 > 0.5 and clear2 < 1).to.equal(true)
		end)
	end)
end
