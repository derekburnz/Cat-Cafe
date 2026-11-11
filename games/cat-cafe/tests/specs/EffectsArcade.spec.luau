--!strict
-- The Cat Arcade's pops (#3062, Effects/ArcadeFx): every grade has its words and colour, the miss has no sparkle or
-- ring, and no pop goes over the phone's burst cap. Written by the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local ArcadeFx = require(Effects:WaitForChild("ArcadeFx")) :: any

	describe("Effects arcade", function()
		it("has perfect, good and miss with words, and a quiet miss", function()
			local grades = Presets.arcade.grades
			for _, grade in { "perfect", "good", "miss" } do
				expect(type(grades[grade].word)).to.equal("string")
				expect(grades[grade].colour).to.be.ok()
			end
			expect(grades.miss.sparkles).to.equal(0)
			expect(grades.miss.rings).to.equal(0)
		end)

		it("keeps every pop within the phone's burst cap", function()
			local p = Presets.arcade
			local most = Presets.budget.low.maxBurst
			for _, count in
				{
					p.grades.perfect.sparkles,
					p.grades.good.sparkles,
					p.milestone.sparkles,
					p.fish.sparkles,
				}
			do
				expect(count <= most).to.equal(true)
			end
		end)

		it("exposes hit, milestone and goldenFish", function()
			for _, name in { "hit", "milestone", "goldenFish" } do
				expect(type(ArcadeFx[name])).to.equal("function")
			end
		end)
	end)
end
