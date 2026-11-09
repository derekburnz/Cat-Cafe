--!strict
-- UI/Components/GoalFold.luau: the folded goal card's one line (#2714).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local GoalFold = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("GoalFold")
	) :: any

	local function progress(ready: boolean, met: { boolean }): any
		local requirements = {}
		for _, done in met do
			table.insert(requirements, { met = done })
		end
		return { ready = ready, nextTier = { name = "Grand Cafe" }, requirements = requirements }
	end

	describe("GoalFold.chip", function()
		it("names the next tier and how many of its requirements are met", function()
			local words, gold = GoalFold.chip(progress(false, { true, false, true }), nil)
			expect(words).to.equal("🏆 Grand Cafe 2/3")
			expect(gold).to.equal(false)
		end)

		it("says Rank up! in gold once ready, before a nudge", function()
			local words, gold =
				GoalFold.chip(progress(true, { true, true }), "📖 Find 3 more cats")
			expect(words).to.equal("🏆 Rank up!")
			expect(gold).to.equal(true)
		end)

		it("shows the nudge, and the top tier with nothing next", function()
			expect((GoalFold.chip(progress(false, { false }), "📖 Find 3 more cats"))).to.equal(
				"📖 Find 3 more cats"
			)
			expect((GoalFold.chip(nil, nil))).to.equal("🏆 Top tier")
			expect((GoalFold.chip({ ready = false, requirements = {} }, nil))).to.equal(
				"🏆 Top tier"
			)
		end)

		it("is saved as a setting the server knows (off by default)", function()
			local Settings = require(
				game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Settings")
			) :: any
			expect(Settings.kinds[GoalFold.SETTING]).to.equal("switch")
			expect(Settings.defaults()[GoalFold.SETTING]).to.equal(false)
		end)
	end)
end
