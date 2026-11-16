--!strict
-- The Cat Arcade's pops (#3062, Effects/ArcadeFx): no pop goes over the phone's burst cap, and Mouse Dash's helpers
-- are there. Circle Streak's ring grades went with that game (#4722). Written by the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local ArcadeFx = require(Effects:WaitForChild("ArcadeFx")) :: any

	describe("Effects arcade", function()
		it("keeps every pop within the phone's burst cap", function()
			local p = Presets.arcade
			local most = Presets.budget.low.maxBurst
			for _, count in { p.milestone.sparkles, p.fish.sparkles } do
				expect(count <= most).to.equal(true)
			end
		end)

		it(
			"exposes milestone, goldenFish and Mouse Dash's burst, word and ready, and no ring grades",
			function()
				for _, name in { "milestone", "goldenFish", "burst", "word", "ready", "shine" } do
					expect(type(ArcadeFx[name])).to.equal("function")
				end
				expect(ArcadeFx.hit).to.equal(nil)
				expect(Presets.arcade.grades).to.equal(nil)
			end
		)
	end)
end
