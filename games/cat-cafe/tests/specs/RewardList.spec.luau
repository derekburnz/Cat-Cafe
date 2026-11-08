--!strict
-- UI/Components/RewardList.luau: a Claim all toast's title and reward chips (#2479).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local RewardList = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("RewardList")
	) :: any

	describe("RewardList", function()
		it("splits a Claim all line into its title and rewards", function()
			local title, items = RewardList.split(
				"4 Index rewards: +$11.3M, +25 golden fish, 1 Alley Crate, +5% gold luck forever, 1 spin"
			)
			expect(title).to.equal("4 Index rewards")
			expect(#items).to.equal(5)
			expect(items[1]).to.equal("+$11.3M")
			expect(items[5]).to.equal("1 spin")
		end)

		it("keeps a money comma and leaves short lines alone", function()
			local _, items = RewardList.split("3 quests: +$1,234, +5 golden fish, 1 spin")
			expect(items[1]).to.equal("+$1,234")
			expect(#items).to.equal(3)
			expect(RewardList.split("Quest done: +$300, 1 spin")).to.equal(nil)
			expect(RewardList.split("Caught a cat!")).to.equal(nil)
		end)

		it("gives each reward its picture", function()
			expect(RewardList.icon("+$11.3M")).to.equal("💰")
			expect(RewardList.icon("+25 golden fish")).to.equal("🐟")
			expect(RewardList.icon("1 Alley Crate")).to.equal("📦")
			expect(RewardList.icon("2 spins")).to.equal("🎡")
			expect(RewardList.icon("+5% gold luck forever")).to.equal("🍀")
			expect(RewardList.icon("+2% faster bait forever")).to.equal("⚡")
			expect(RewardList.icon("something new")).to.equal(RewardList.DEFAULT_ICON)
		end)

		it("stays a little longer the more it holds, up to MAX_LIFETIME", function()
			expect(RewardList.lifetime(3, 3.2)).to.equal(3.2)
			expect(math.abs(RewardList.lifetime(5, 3.2) - 3.8) < 1e-9).to.equal(true)
			expect(RewardList.lifetime(40, 3.2)).to.equal(RewardList.MAX_LIFETIME)
		end)
	end)
end
