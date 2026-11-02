--!strict
-- Luck's effects (F88, luck-and-rare-moments.md 1a and 1c): the Lucky Day's gold tint by day only, the Lucky Cat
-- statue's level read from its model and sparkling only on a level up this client saw, and the jade shimmer's numbers.
-- Written by the vfx-animator for QA to move into tests/specs.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects luck", function()
		it("tints the world only on a Lucky Day by day", function()
			expect(Logic.luckyDayOn(true, "day")).to.equal(true)
			expect(Logic.luckyDayOn(true, nil)).to.equal(true)
			expect(Logic.luckyDayOn(true, "night")).to.equal(false)
			expect(Logic.luckyDayOn(false, "day")).to.equal(false)
			expect(Logic.luckyDayOn(nil, "day")).to.equal(false)
			expect(Logic.luckyDayOn("yes", "day")).to.equal(false)
		end)

		it("reads a statue's level from its model name", function()
			expect(Logic.luckyCatLevel("CatCafe_Plot_LuckyCat_0")).to.equal(0)
			expect(Logic.luckyCatLevel("CatCafe_Plot_LuckyCat_5")).to.equal(5)
			expect(Logic.luckyCatLevel("CatCafe_Plot_LuckyCat_6") == nil).to.equal(true)
			expect(Logic.luckyCatLevel("LuckyCat") == nil).to.equal(true)
			expect(Logic.luckyCatLevel("CatCafe_Plot_LuckyCat_Paw") == nil).to.equal(true)
		end)

		it("sparkles only for a level up this client saw", function()
			expect(Logic.luckyLevelUp(nil, 3)).to.equal(false) -- a join or a stream in
			expect(Logic.luckyLevelUp(0, 1)).to.equal(true) -- the first statue on the plinth
			expect(Logic.luckyLevelUp(4, 5)).to.equal(true)
			expect(Logic.luckyLevelUp(2, 2)).to.equal(false) -- the same statue again
			expect(Logic.luckyLevelUp(3, 2)).to.equal(false)
			expect(Logic.luckyLevelUp(0, 0)).to.equal(false)
		end)

		it("keeps the Lucky Day tint warm and gentle", function()
			local l = Presets.luckyDay
			expect(l.tint.R >= l.tint.G and l.tint.G >= l.tint.B).to.equal(true)
			expect(l.tint.B > 0.7).to.equal(true) -- a tint, not a filter
			expect(l.saturation >= 0 and l.saturation <= 0.15).to.equal(true)
			expect(math.abs(l.brightness) <= 0.05).to.equal(true)
			expect(l.clouds.R >= l.clouds.B).to.equal(true)
			expect(l.seconds > 0).to.equal(true)
		end)

		it("colours each statue's sparkle by its look and keeps the jade shimmer faint", function()
			local s = Presets.luckyCat
			expect(#s.colours).to.equal(5)
			expect(s.colours[4]).to.equal(Presets.palette.golden)
			expect(s.shimmerFrom).to.equal(5)
			expect(s.fill >= 0.7 and s.fill < 1).to.equal(true)
			expect(s.centre > 1.2 and s.centre < 3.2).to.equal(true) -- between the cushion and the head top
			local b = Presets.budget
			expect(b.lowPerformance.luckyShimmers).to.equal(0)
			expect(b.low.luckyShimmers <= b.high.luckyShimmers).to.equal(true)
		end)
	end)
end
