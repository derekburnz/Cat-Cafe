--!strict
-- StoreFunnel.luau (#1888): the Store funnel's steps and the client's noted source.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local StoreFunnel = require(Shared.StoreFunnel)
	local Config = require(Shared.Config)

	describe("StoreFunnel", function()
		it("numbers its five steps in order, as store_v1 (#2914)", function()
			expect(StoreFunnel.NAME).to.equal("store_v1")
			expect(StoreFunnel.index("opened")).to.equal(1)
			expect(StoreFunnel.index("tab_viewed")).to.equal(2)
			expect(StoreFunnel.index("buy_pressed")).to.equal(3)
			expect(StoreFunnel.index("prompt_closed")).to.equal(4)
			expect(StoreFunnel.index("completed")).to.equal(5)
			expect(StoreFunnel.index("cancelled")).to.equal(0)
		end)

		it(
			"takes the noted source once, and other when none or an unknown one was noted",
			function()
				StoreFunnel.noteSource("new_dot")
				expect(StoreFunnel.takeSource()).to.equal("new_dot")
				expect(StoreFunnel.takeSource()).to.equal("other")
				StoreFunnel.noteSource("somewhere")
				expect(StoreFunnel.takeSource()).to.equal("other")
			end
		)

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

		it(
			"reads a store guard report as a known source and reason, and nothing else (#1936)",
			function()
				for _, source in StoreFunnel.GUARD_SOURCES do
					for _, reason in StoreFunnel.GUARD_REASONS do
						local from, why = StoreFunnel.guardBlock(source .. ":" .. reason)
						expect(from).to.equal(source)
						expect(why).to.equal(reason)
					end
				end
				for _, bad in
					{
						"store",
						"store:",
						":no_tap",
						"shop:no_tap",
						"store:later",
						"store:no_tap:x",
						7,
						"",
					}
				do
					local from, why = StoreFunnel.guardBlock(bad)
					expect(from).to.equal(nil)
					expect(why).to.equal(nil)
				end
				expect(StoreFunnel.guardBlock(string.rep("a", 40) .. ":busy")).to.equal(nil)
				expect(StoreFunnel.GUARD_BLOCKS_MAX).to.equal(20)
			end
		)

		it(
			"reads a buy source tag as a known source and a whole id, and nothing else (#4176)",
			function()
				for _, source in StoreFunnel.BUY_SOURCES do
					local from, id = StoreFunnel.buySource(source .. ":3731165229")
					expect(from).to.equal(source)
					expect(id).to.equal(3731165229)
				end
				for _, bad: unknown in
					{
						"store",
						"store:",
						":12",
						"shop:12",
						"store:-3",
						"store:1.5",
						"store:0",
						"store:12:1",
						7,
						"",
					} :: { unknown }
				do
					local from, id = StoreFunnel.buySource(bad)
					expect(from).to.equal(nil)
					expect(id).to.equal(nil)
				end
				expect(StoreFunnel.buySource("hud_badge:" .. string.rep("9", 40))).to.equal(nil)
			end
		)

		it("maps PassShop's prompt sources to purchase sources (#4176)", function()
			expect(StoreFunnel.buySourceOf(nil)).to.equal("store")
			expect(StoreFunnel.buySourceOf("store")).to.equal("store")
			expect(StoreFunnel.buySourceOf("cafePass")).to.equal("cafe_pass")
			expect(StoreFunnel.buySourceOf("hud_badge")).to.equal("hud_badge")
			expect(StoreFunnel.buySourceOf("somewhere")).to.equal("store")
		end)
	end)
end
