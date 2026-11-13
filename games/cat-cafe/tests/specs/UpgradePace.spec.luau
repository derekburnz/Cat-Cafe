--!strict
-- #2996: the upgrade_bought event's numbers (shared/UpgradePace).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local UpgradePace = require(Shared.UpgradePace)

	describe("UpgradePace (#2996)", function()
		it("counts the levels bought over each upgrade's start level", function()
			expect(UpgradePace.bought({})).to.equal(0)
			expect(UpgradePace.bought({ tables = 1 })).to.equal(1)
			expect(UpgradePace.bought({ tables = 2, lure_bowl = 1 })).to.equal(3)
			-- Espresso starts at level 1, so its level 1 is no buy and its level 2 is one
			expect((Catalog.getUpgrade("espresso") :: any).startLevel).to.equal(1)
			expect(UpgradePace.bought({ espresso = 1 })).to.equal(0)
			expect(UpgradePace.bought({ espresso = 2, tables = 1 })).to.equal(2)
			expect(UpgradePace.bought({ not_an_upgrade = 9 })).to.equal(0)
		end)

		it("names the first four buys one by one and the rest together", function()
			expect(UpgradePace.nth(1)).to.equal("1")
			expect(UpgradePace.nth(2)).to.equal("2")
			expect(UpgradePace.nth(3)).to.equal("3")
			expect(UpgradePace.nth(4)).to.equal("4")
			expect(UpgradePace.nth(5)).to.equal("5+")
			expect(UpgradePace.nth(40)).to.equal("5+")
			expect(UpgradePace.nth(0)).to.equal("1")
		end)

		it("measures from the last buy this session, else from the join", function()
			expect(UpgradePace.gap(1000, nil, 940)).to.equal(60)
			expect(UpgradePace.gap(1000, 925.4, 940)).to.equal(74)
			expect(UpgradePace.gap(1000, 1001, 940)).to.equal(0)
		end)
	end)
end
