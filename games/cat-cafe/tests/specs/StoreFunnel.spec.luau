--!strict
-- StoreFunnel.luau (#1888): the Store funnel's steps and the client's noted source.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local StoreFunnel = require(Shared.StoreFunnel)
	local Config = require(Shared.Config)

	describe("StoreFunnel", function()
		it("numbers its four steps in order", function()
			expect(StoreFunnel.index("opened")).to.equal(1)
			expect(StoreFunnel.index("tab_viewed")).to.equal(2)
			expect(StoreFunnel.index("buy_pressed")).to.equal(3)
			expect(StoreFunnel.index("completed")).to.equal(4)
			expect(StoreFunnel.index("cancelled")).to.equal(0)
		end)

		it("takes the noted source once, and other when none or an unknown one was noted", function()
			StoreFunnel.noteSource("new_dot")
			expect(StoreFunnel.takeSource()).to.equal("new_dot")
			expect(StoreFunnel.takeSource()).to.equal("other")
			StoreFunnel.noteSource("somewhere")
			expect(StoreFunnel.takeSource()).to.equal("other")
		end)

		it("names our passes and products and nothing else", function()
			expect(StoreFunnel.passSku(Config.VipPassId)).to.equal("pass_vip")
			expect(StoreFunnel.passSku(Config.GoldenPondPassId)).to.equal("pass_golden_pond")
			expect(StoreFunnel.passSku(Config.MoneyPassIds[3])).to.equal("pass_money_3")
			expect(StoreFunnel.passSku(Config.ExtraSlotPassIds[1])).to.equal("pass_extra_slot_1")
			expect(StoreFunnel.passSku(0)).to.equal(nil)
			expect(StoreFunnel.passSku(12345)).to.equal(nil)
			expect(StoreFunnel.passSku("2072030274")).to.equal(nil)
			for id, made in Config.ProductIds do
				if made ~= 0 then
					expect(StoreFunnel.productSku(made)).to.equal("product_" .. id)
				end
			end
			expect(StoreFunnel.productSku(12345)).to.equal(nil)
		end)
	end)
end
