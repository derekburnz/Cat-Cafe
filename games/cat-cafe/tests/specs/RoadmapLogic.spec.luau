--!strict
-- UI/Components/RoadmapLogic.luau: the Grand Opening roadmap's strip, list and toasts (#1893, first-hour.md 1).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local RoadmapLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("RoadmapLogic")
	) :: any

	describe("RoadmapLogic.view", function()
		it("hides before the tutorial's end, once finished, and without grandOpening", function()
			expect(RoadmapLogic.view({ tutorialStep = 3, grandOpening = { done = {} } })).to.equal(
				nil
			)
			expect(
				RoadmapLogic.view({
					tutorialStep = 5,
					grandOpening = { done = {}, finished = true },
				})
			).to.equal(nil)
			expect(RoadmapLogic.view({ tutorialStep = 9 })).to.equal(nil)
		end)

		it(
			"counts the done steps and highlights the lowest unfinished one, in any order",
			function()
				local view = RoadmapLogic.view({
					tutorialStep = 6,
					grandOpening = { done = { [1] = true, [4] = true } },
				})
				expect(view.title).to.equal("Grand Opening 2/8")
				expect(view.count).to.equal(2)
				expect(#view.rows).to.equal(8)
				expect(view.rows[2].next).to.equal(true)
				expect(view.rows[3].next).to.equal(false)
				expect(view.rows[4].done).to.equal(true)
			end
		)

		it("reads string keys from the sync as numbers", function()
			local view =
				RoadmapLogic.view({ tutorialStep = 6, grandOpening = { done = { ["3"] = true } } })
			expect(view.count).to.equal(1)
			expect(view.rows[3].done).to.equal(true)
		end)
	end)

	describe("RoadmapLogic.toast", function()
		it("names the step and its reward", function()
			expect(RoadmapLogic.toast(4)).to.equal("Grand Opening 4/8: Tier 2! +10 golden fish")
			expect(RoadmapLogic.toast(99)).to.equal("Grand Opening")
		end)
	end)
end
