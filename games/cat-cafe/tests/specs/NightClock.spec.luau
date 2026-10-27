--!strict
-- UI/Components/NightClock.luau: the short night's clock chip text, dusk warning and areas closing (F66).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local NightClock = require(Components:WaitForChild("NightClock")) :: any

	describe("NightClock.chipText", function()
		it("shows the phase and the time left", function()
			expect(NightClock.chipText("day", 252, 15)).to.equal("Day  4:12")
			expect(NightClock.chipText("night", 65, 15)).to.equal("Night  1:05")
			expect(NightClock.chipText("night", 5, 15)).to.equal("Night  0:05")
		end)

		it("counts down to night in the dusk warning", function()
			expect(NightClock.chipText("day", 15, 15)).to.equal("Night in 0:15")
			expect(NightClock.chipText("day", 12.4, 15)).to.equal("Night in 0:12")
			expect(NightClock.chipText("day", 15.5, 15)).to.equal("Day  0:16")
		end)

		it("never goes below zero", function()
			expect(NightClock.chipText("night", -3, 15)).to.equal("Night  0:00")
		end)
	end)

	describe("NightClock.isDusk", function()
		it("is only the last seconds of a day", function()
			expect(NightClock.isDusk("day", 15, 15)).to.equal(true)
			expect(NightClock.isDusk("day", 0.5, 15)).to.equal(true)
			expect(NightClock.isDusk("day", 16, 15)).to.equal(false)
			expect(NightClock.isDusk("day", 0, 15)).to.equal(false)
			expect(NightClock.isDusk("night", 10, 15)).to.equal(false)
		end)
	end)

	describe("NightClock.duskTitle", function()
		it("counts the seconds up", function()
			expect(NightClock.duskTitle(15)).to.equal("Night falls in 15 s!")
			expect(NightClock.duskTitle(14.2)).to.equal("Night falls in 15 s!")
			expect(NightClock.duskTitle(0.1)).to.equal("Night falls in 1 s!")
		end)
	end)

	describe("NightClock.areasOpen", function()
		it("closes only on false", function()
			expect(NightClock.areasOpen(false)).to.equal(false)
			expect(NightClock.areasOpen(true)).to.equal(true)
			expect(NightClock.areasOpen(nil)).to.equal(true)
		end)
	end)
end
