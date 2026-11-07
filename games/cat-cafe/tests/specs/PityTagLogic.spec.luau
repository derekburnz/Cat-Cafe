--!strict
-- UI/Components/PityTagLogic: the pity cat's tag (#2099, luck-and-rare-moments.md 1j).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local PityTagLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("PityTagLogic")
	) :: any

	describe("PityTagLogic", function()
		it("reads the PityCat attribute as a Legendary or Mythical tag, else none", function()
			expect(PityTagLogic.kind("Legendary")).to.equal("Legendary")
			expect(PityTagLogic.kind("Mythical")).to.equal("Mythical")
			expect(PityTagLogic.kind(nil)).to.equal(nil)
			expect(PityTagLogic.kind("")).to.equal(nil)
			expect(PityTagLogic.kind(true)).to.equal(nil)
		end)

		it("hides while the cat is held in a net and shows again once it bolts", function()
			expect(PityTagLogic.shows("Legendary", nil)).to.equal(true)
			expect(PityTagLogic.shows("Legendary", 0)).to.equal(true)
			expect(PityTagLogic.shows("Mythical", 12345)).to.equal(false)
			expect(PityTagLogic.shows(nil, nil)).to.equal(false)
		end)

		it("shrinks to the icon past 60 studs, shows within 150 and says only Pity cat", function()
			expect(PityTagLogic.compact(30)).to.equal(false)
			expect(PityTagLogic.compact(60)).to.equal(false)
			expect(PityTagLogic.compact(61)).to.equal(true)
			expect(PityTagLogic.RANGE).to.equal(150)
			expect(PityTagLogic.TEXT).to.equal("Pity cat")
		end)
	end)
end
