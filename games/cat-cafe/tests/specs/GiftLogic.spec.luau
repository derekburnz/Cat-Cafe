--!strict
-- UI/Components/GiftLogic.luau: Mystery Visitor gift tiers on the UI (#2614).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local GiftLogic = require(Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("GiftLogic")) :: any

	describe("GiftLogic", function()
		it("reads the wrap's tier, common for anything unknown", function()
			expect(GiftLogic.tier("rare")).to.equal("rare")
			expect(GiftLogic.tier("super")).to.equal("super")
			expect(GiftLogic.tier("common")).to.equal("common")
			expect(GiftLogic.tier("Rare")).to.equal("rare")
			expect(GiftLogic.tier("Super")).to.equal("super")
			expect(GiftLogic.tier(nil)).to.equal("common")
			expect(GiftLogic.tier(7)).to.equal("common")
		end)

		it("titles the card and the HUD line by tier", function()
			expect(GiftLogic.title(nil)).to.equal("Mystery gift!")
			expect(GiftLogic.title("rare")).to.equal("Rare gift!")
			expect(GiftLogic.title("super")).to.equal("Super gift!")
			expect(GiftLogic.chip("common")).to.equal("A gift waits at your cafe")
			expect(GiftLogic.chip("super")).to.equal("A super gift waits at your cafe!")
		end)

		it("knows a gift waits from the plot's MysteryGiftAt", function()
			expect(GiftLogic.waiting(1794000000)).to.equal(true)
			expect(GiftLogic.waiting(0)).to.equal(false)
			expect(GiftLogic.waiting(nil)).to.equal(false)
		end)
	end)
end
