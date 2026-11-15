--!strict
-- shared/HarvestHollow and UI/Components/HarvestLogic: the Harvest Stall's items, buttons and the keep line (#4251).
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local HarvestHollow =
		require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HarvestHollow")) :: any
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Logic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("HarvestLogic")
	) :: any

	describe("HarvestHollow", function()
		it("sells five outfits and six decor for 480 pumpkins in all (spec section 4)", function()
			expect(#HarvestHollow.STALL).to.equal(11)
			expect(HarvestHollow.TOTAL).to.equal(480)
			expect(#Logic.rows("outfit")).to.equal(5)
			expect(#Logic.rows("decor")).to.equal(6)
			expect(Logic.rows("outfit")[2].name).to.equal("Sunflower Hat")
			expect(HarvestHollow.item("wheat_wreath").price).to.equal(60)
			expect(HarvestHollow.item("nope")).to.equal(nil)
			expect(HarvestHollow.item(5)).to.equal(nil)
		end)
		it("keeps every id unique and every price a whole pumpkin count", function()
			local seen = {}
			for _, item in HarvestHollow.STALL do
				expect(seen[item.id]).to.equal(nil)
				seen[item.id] = true
				expect(item.price > 0 and item.price % 1 == 0).to.equal(true)
			end
		end)
		it("opens Wed Nov 25 20:00 UTC and closes Sun Dec 6 23:59 UTC", function()
			expect(HarvestHollow.open(1795636800 - 1)).to.equal(false)
			expect(HarvestHollow.open(1795636800)).to.equal(true)
			expect(HarvestHollow.open(1796601540 - 1)).to.equal(true)
			expect(HarvestHollow.open(1796601540)).to.equal(false)
		end)
		it("earns two rarities lower, never below Common (section 3b)", function()
			expect(HarvestHollow.earnsLike("Mythical")).to.equal("Epic")
			expect(HarvestHollow.earnsLike("Legendary")).to.equal("Rare")
			expect(HarvestHollow.earnsLike("Epic")).to.equal("Common")
			expect(HarvestHollow.earnsLike("Common")).to.equal("Common")
			expect(HarvestHollow.earnsLike("Secret")).to.equal("Common")
		end)
	end)

	describe("HarvestLogic", function()
		local hat = HarvestHollow.item("acorn_hat")
		it("prices in pumpkins, grey while short", function()
			local short = Logic.action({ tier = 3, harvest = { pumpkins = 39, bought = {} } }, hat)
			expect(short.mode).to.equal("buy")
			expect(short.text).to.equal("🎃 40")
			expect(short.enabled).to.equal(false)
			expect(short.style).to.equal("ghost")
			local enough = Logic.action({ tier = 3, harvest = { pumpkins = 40 } }, hat)
			expect(enough.enabled).to.equal(true)
			expect(enough.style).to.equal("gold")
		end)
		it("shows Owned once bought and the tier gate below Tier 2", function()
			expect(
				Logic.action(
					{ tier = 3, harvest = { pumpkins = 0, bought = { acorn_hat = true } } },
					hat
				).text
			).to.equal("Owned")
			local locked = Logic.action({ tier = 1, harvest = { pumpkins = 500 } }, hat)
			expect(locked.text).to.equal("Opens at Tier 2")
			expect(locked.enabled).to.equal(false)
		end)
		it("reads no pumpkins before the save arrives", function()
			expect(Logic.pumpkins({ tier = 2 })).to.equal(0)
			expect(Logic.pumpkins(nil)).to.equal(0)
			expect(Logic.pumpkins({ harvest = { pumpkins = 12.7 } })).to.equal(12)
		end)
		it("words the keep line with the newest area", function()
			expect(Logic.keepLine("Mythical", "Woods")).to.equal(
				"Yours to keep · earns like a Woods Epic"
			)
			expect(Logic.keepLine("Common", "Alleyway")).to.equal(
				"Yours to keep · earns like an Alleyway Common"
			)
			expect(Logic.keepLine("Legendary", nil)).to.equal("Yours to keep · earns like a Rare")
		end)
		it(
			"shows the HUD Harvest button only while open, from Tier 2, with the switch on (#4251)",
			function()
				local H = HarvestHollow
				local during = H.OPENS_AT + 3600
				expect(Logic.hudShown(during, 2, nil)).to.equal(true)
				expect(Logic.hudShown(during, 5, true)).to.equal(true)
				expect(Logic.hudShown(during, 1, nil)).to.equal(false)
				expect(Logic.hudShown(during, nil, nil)).to.equal(false)
				expect(Logic.hudShown(during, 3, false)).to.equal(false)
				expect(Logic.hudShown(H.OPENS_AT - 1, 3, nil)).to.equal(false)
				expect(Logic.hudShown(H.CLOSES_AT, 3, nil)).to.equal(false)
				expect(Logic.nextChange(H.OPENS_AT - 60)).to.equal(H.OPENS_AT)
				expect(Logic.nextChange(during)).to.equal(H.CLOSES_AT)
				expect(Logic.nextChange(H.CLOSES_AT)).to.equal(nil)
			end
		)
	end)
end
