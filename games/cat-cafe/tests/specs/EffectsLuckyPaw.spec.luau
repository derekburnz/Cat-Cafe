--!strict
-- The Lucky Cat statue's beckoning paw (F88, luck-and-rare-moments.md section 1a: "Its paw waves a little faster at
-- each level"). Logic.pawWave is pure; the paw turning on the statue (LuckyPaw.luau on Gameplay-Engineer's "LuckyCat"
-- model with Model-Agent's `_Paw` piece) is a Studio row (effects-list "Lucky Cat paw").
-- Written by the Animation-Engineer (QA said new specs may go straight in here).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local p = Presets.luckyPaw

	describe("Effects Lucky Cat paw", function()
		it("beckons forward and back by the same amount at every level", function()
			for level = 1, 5 do
				local most, least = 0, 0
				for t = 0, p.seconds[level], 0.01 do
					local a = Logic.pawWave(t, level)
					most = math.max(most, a)
					least = math.min(least, a)
					expect(math.abs(a) <= math.rad(p.degrees) + 1e-9).to.equal(true)
				end
				expect(most).to.be.near(math.rad(p.degrees), 0.01)
				expect(least).to.be.near(-math.rad(p.degrees), 0.01)
			end
		end)

		it("waves a little faster at each level", function()
			for level = 2, 5 do
				expect(p.seconds[level] < p.seconds[level - 1]).to.equal(true)
			end
			for level = 1, 5 do
				local s = p.seconds[level]
				expect(Logic.pawWave(0.3, level)).to.be.near(Logic.pawWave(0.3 + s, level), 1e-9)
			end
		end)

		it("keeps the empty plinth and an unknown level still", function()
			for _, level in { 0, 6, -1 } do
				expect(Logic.pawWave(0.4, level)).to.equal(0)
			end
		end)

		it("moves smoothly at 60 frames a second, even at level 5", function()
			local last = Logic.pawWave(0, 5)
			for t = 1 / 60, p.seconds[5] * 2, 1 / 60 do
				local a = Logic.pawWave(t, 5)
				expect(math.abs(a - last) < math.rad(4)).to.equal(true)
				last = a
			end
		end)
	end)
end
