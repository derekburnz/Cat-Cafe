--!strict
-- Catch v3 (#1884, catch-rework.md section 7): the ring pops, the Perfect hit-stop and the finish. Written by the
-- vfx-animator for QA to move into tests/specs.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects catch v3", function()
		it("names a grade sent as a word or the old number", function()
			expect(Logic.gradeName("perfect")).to.equal("perfect")
			expect(Logic.gradeName(1)).to.equal("perfect")
			expect(Logic.gradeName(0.5)).to.equal("good")
			expect(Logic.gradeName("miss")).to.equal("miss")
			expect(Logic.gradeName(0)).to.equal("miss")
			expect(Logic.gradeName("odd") == nil).to.equal(true)
		end)

		it(
			"reads the server's finish, bare or in a table, and nothing on a bolt or the v2 catch",
			function()
				expect(Logic.catchFinish(true, 0, nil, "great")).to.equal("great")
				expect(Logic.catchFinish(true, 0, nil, { finish = "purrfect", trust = 8 })).to.equal(
					"purrfect"
				)
				expect(Logic.catchFinish(true, 0, { finish = "nice" })).to.equal("nice")
				expect(Logic.catchFinish(false, 0, nil, { finish = "bolt" }) == nil).to.equal(true)
				expect(Logic.catchFinish(true, 0, nil) == nil).to.equal(true)
			end
		)

		it("keeps the hit-stop short and every grade's pop small", function()
			local j = Presets.catchJudge
			expect(j.hitStop > 0 and j.hitStop <= 0.1).to.equal(true)
			for _, name in { "perfect", "good", "miss" } do
				local g = j.grades[name]
				expect(g ~= nil and g.colour ~= nil).to.equal(true)
				expect(g.sparkles + g.puff <= 8).to.equal(true)
				expect(g.ring > 0 and g.ring <= 2.5).to.equal(true)
			end
		end)

		it("waits for the net wrap and has a look for every finish", function()
			local f = Presets.catchFinish
			expect(f.wrap > 0 and f.wrap <= 1).to.equal(true)
			for _, finish in { "purrfect", "great", "nice" } do
				expect(f.confetti[finish] > 0 and f.confetti[finish] <= 1).to.equal(true)
				expect(Presets.catchWord.words[finish] ~= nil).to.equal(true)
			end
			expect(f.confetti.purrfect > f.confetti.great and f.confetti.great > f.confetti.nice).to.equal(
				true
			)
		end)
	end)
end
