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

		it("reads the /event command on any chat path (#2754)", function()
			expect(OwnerTest.isEventCommand("/event")).to.equal(true)
			expect(OwnerTest.isEventCommand("/event full 5")).to.equal(true)
			expect(OwnerTest.isEventCommand("/EVENT stop")).to.equal(true)
			expect(OwnerTest.isEventCommand("/events")).to.equal(false)
			expect(OwnerTest.isEventCommand("hello qa")).to.equal(false)
			expect(OwnerTest.isEventCommand(" /event")).to.equal(false)
			expect(OwnerTest.isEventCommand(nil)).to.equal(false)
		end)

		it("answers a line two chat paths both deliver only once (#2754)", function()
			local last = { userId = 1, text = "/event full 5", at = 10 }
			expect(OwnerTest.isRepeat(nil, 1, "/event full 5", 10, 1)).to.equal(false)
			expect(OwnerTest.isRepeat(last, 1, "/event full 5", 10.5, 1)).to.equal(true)
			expect(OwnerTest.isRepeat(last, 1, "/event full 5", 11.2, 1)).to.equal(false)
			expect(OwnerTest.isRepeat(last, 1, "/event stop", 10.5, 1)).to.equal(false)
			expect(OwnerTest.isRepeat(last, 2, "/event full 5", 10.5, 1)).to.equal(false)
		end)

		it("has the OwnerGrant remote and an owner_test_ sku apart from sales", function()
			expect(table.find(Remotes.ClientToServer, "OwnerGrant")).to.be.ok()
			expect(OwnerTest.SKU_PREFIX).to.equal("owner_test_")
			expect(OwnerTest.ATTRIBUTE).to.equal("OwnerTest")
			expect(OwnerTest.LABEL).to.equal("Owner test mode")
		end)
	end)
end
