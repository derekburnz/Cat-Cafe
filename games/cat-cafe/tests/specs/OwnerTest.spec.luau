--!strict
-- shared/OwnerTest (#1770, owner test mode): only Derek2's user id is an owner, and nothing a product grants can be
-- traded, so a grant with no Robux can never reach another player.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local OwnerTest = require(Shared.OwnerTest)
	local Remotes = require(Shared.Remotes)

	describe("OwnerTest", function()
		it(
			"lists only Derek2's user id (the account named 2573351 is user id 140223517)",
			function()
				expect(#Config.OwnerTestUserIds).to.equal(1)
				expect(Config.OwnerTestUserIds[1]).to.equal(140223517)
				expect(OwnerTest.isOwner(140223517)).to.equal(true)
				-- user id 2573351 is a different player
				expect(OwnerTest.isOwner(2573351)).to.equal(false)
				expect(OwnerTest.isOwner(0)).to.equal(false)
				expect(OwnerTest.isOwner("140223517")).to.equal(false)
				expect(OwnerTest.isOwner(nil)).to.equal(false)
			end
		)

		it("grants nothing tradeable: every product's cats are exclusive", function()
			for _, product in Catalog.products do
				local loose = OwnerTest.tradeableIn(product)
				if #loose > 0 then
					error(
						string.format(
							"%s holds tradeable %s",
							product.id,
							table.concat(loose, ", ")
						)
					)
				end
			end
		end)

		it("has the OwnerGrant remote and an owner_test_ sku apart from sales", function()
			expect(table.find(Remotes.ClientToServer, "OwnerGrant")).to.be.ok()
			expect(OwnerTest.SKU_PREFIX).to.equal("owner_test_")
			expect(OwnerTest.ATTRIBUTE).to.equal("OwnerTest")
			expect(OwnerTest.LABEL).to.equal("Owner test mode")
		end)
	end)
end
