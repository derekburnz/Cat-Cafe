--!strict
-- shared/GiftStallSave: the Christmas Event's Gift Stall save and the server's buy rules (#5643, snowglobe-village-spec
-- section 5).
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local GiftStallSave = require(Shared:WaitForChild("GiftStallSave")) :: any
	local Catalog = require(Shared:WaitForChild("Catalog")) :: any
	local Economy = require(Shared:WaitForChild("Economy")) :: any
	local LiveFlags = require(Shared:WaitForChild("LiveFlags")) :: any
	local Looks = require(Shared:WaitForChild("Looks")) :: any
	local ProfileSchema = require(Shared:WaitForChild("ProfileSchema")) :: any
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local GiftStallLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("GiftStallLogic")
	) :: any

	local open = GiftStallSave.OPENS_AT + 60

	describe("GiftStallSave", function()
		it("sells the spec's 8 items for 1,800 Snowflakes, as the window shows them", function()
			local total = 0
			for _, item in GiftStallSave.ITEMS do
				total += item.price
			end
			expect(#GiftStallSave.ITEMS).to.equal(8)
			expect(total).to.equal(GiftStallSave.TOTAL)
			expect(GiftStallLogic.TOTAL).to.equal(GiftStallSave.TOTAL)
			for i, item in GiftStallSave.ITEMS do
				local shown = GiftStallLogic.ITEMS[i]
				expect(shown.id).to.equal(item.id)
				expect(shown.kind).to.equal(item.kind)
				expect(shown.cost).to.equal(item.price)
			end
		end)

		it("cleans a save: known items only", function()
			local save = GiftStallSave.sanitize({
				bought = { santa_hat = true, made_up = true, snowman = "yes" },
			})
			expect(save.bought.santa_hat).to.equal(true)
			expect(save.bought.made_up).to.equal(nil)
			expect(save.bought.snowman).to.equal(nil)
			expect(GiftStallSave.sanitize(nil)).to.equal(nil)
			expect(GiftStallSave.sanitize(5)).to.equal(nil)
		end)

		it("keeps the bought items through a save round trip, and a new save has none", function()
			local fresh = ProfileSchema.migrate({}, open)
			expect(fresh.giftStall).to.equal(nil)
			local raw = ProfileSchema.migrate({}, open)
			raw.giftStall = { bought = { knit_beanie = true } }
			raw.snowflakes = 40
			local again = ProfileSchema.migrate(raw, open)
			expect(again.giftStall.bought.knit_beanie).to.equal(true)
			expect(again.snowflakes).to.equal(40)
		end)

		it(
			"refuses with the switch off, outside the dates, before Tier 2, owned or short",
			function()
				local save = GiftStallSave.fresh()
				expect(GiftStallSave.buyBlocker(save, 1000, "santa_hat", open, 2, true)).to.equal(
					nil
				)
				expect(GiftStallSave.buyBlocker(save, 1000, "made_up", open, 2, true)).to.equal(
					"Unknown item"
				)
				expect(GiftStallSave.buyBlocker(save, 1000, "santa_hat", open, 2, false)).to.equal(
					"The Gift Stall is closed"
				)
				expect(
					GiftStallSave.buyBlocker(
						save,
						1000,
						"santa_hat",
						GiftStallSave.OPENS_AT - 1,
						2,
						true
					)
				).to.equal("The Gift Stall opens on Dec 1")
				expect(
					GiftStallSave.buyBlocker(
						save,
						1000,
						"santa_hat",
						GiftStallSave.CLOSES_AT,
						2,
						true
					)
				).to.be.ok()
				expect(GiftStallSave.buyBlocker(save, 1000, "santa_hat", open, 1, true)).to.equal(
					"Opens at Tier 2"
				)
				expect(GiftStallSave.buyBlocker(save, 149, "santa_hat", open, 2, true)).to.equal(
					"You need more Snowflakes"
				)
				expect(GiftStallSave.buyBlocker(nil, nil, "santa_hat", open, 2, true)).to.equal(
					"You need more Snowflakes"
				)
				save.bought.santa_hat = true
				expect(GiftStallSave.buyBlocker(save, 1000, "santa_hat", open, 2, true)).to.equal(
					"Already yours"
				)
			end
		)

		it("spends the price once and never twice", function()
			local save = GiftStallSave.fresh()
			expect(GiftStallSave.buy(save, 260, "santa_hat")).to.equal(110)
			expect(save.bought.santa_hat).to.equal(true)
			expect(GiftStallSave.buy(save, 110, "santa_hat")).to.equal(nil)
			expect(GiftStallSave.buy(save, 100, "snowman")).to.equal(nil)
			expect(save.bought.snowman).to.equal(nil)
			expect(GiftStallSave.buy(save, 200.9, "snowman")).to.equal(0)
		end)

		it("puts decor in decorOwned and the hats in the Looks items", function()
			for _, item in GiftStallSave.ITEMS do
				if item.kind == "decor" then
					local def = Catalog.getDecor(GiftStallSave.decorId(item.id))
					expect(def).to.be.ok()
					expect(def.source).to.equal("christmas")
					expect(def.cost).to.equal(0)
				else
					expect(Looks.accessory(GiftStallSave.lookId(item.id))).to.be.ok()
				end
			end
			expect(#Catalog.christmasDecor).to.equal(5)
			local save = GiftStallSave.fresh()
			save.bought.snowman = true
			save.bought.reindeer_antlers = true
			local decor: { [string]: boolean } = {}
			expect(GiftStallSave.grantOwned(save, decor)).to.equal(1)
			expect(decor.decor_snowman).to.equal(true)
			expect(decor.decor_reindeer_antlers).to.equal(nil)
			expect(GiftStallSave.grantOwned(save, decor)).to.equal(0)
			expect(GiftStallSave.grantOwned(nil, decor)).to.equal(0)
			local passItems: { [string]: boolean } = { acc_leaf_beret = true }
			local items = GiftStallSave.lookItems(save, passItems)
			expect(items.acc_reindeer_antlers).to.equal(true)
			expect(items.acc_leaf_beret).to.equal(true)
			expect(passItems.acc_reindeer_antlers).to.equal(nil) -- a copy
			expect(table.find(
				Looks.owned("accessory", function()
					return false
				end, items),
				"acc_reindeer_antlers"
			)).to.be.ok()
		end)

		it("never hands Stall, Booth or Harvest pieces out free through BuyDecor", function()
			local profile = ProfileSchema.migrate({}, open)
			profile.coins = 1e9
			profile.tier = 9
			expect(Economy.decorBlocker(profile, "decor_little_tree")).to.equal("Not for sale here")
			expect(Economy.decorBlocker(profile, "decor_feast_pie")).to.equal("Not for sale here")
			for _, def in Catalog.boothDecor do
				expect(Economy.decorBlocker(profile, def.id)).to.equal("Not for sale here")
			end
		end)

		it("gives the window its view: the count, the prices and what is owned", function()
			local save = GiftStallSave.fresh()
			save.bought.little_tree = true
			local view = GiftStallSave.view(save, 260)
			expect(view.snowflakes).to.equal(260)
			expect(#view.items).to.equal(8)
			expect(GiftStallLogic.owns(view, "little_tree")).to.equal(true)
			expect(GiftStallLogic.owns(view, "santa_hat")).to.equal(false)
			local rows = GiftStallLogic.rows(view, "outfit")
			expect(#rows).to.equal(3)
			expect(GiftStallLogic.action(view, rows[1]).mode).to.equal("buy")
			expect(GiftStallSave.view(nil, nil).snowflakes).to.equal(0)
		end)

		it("rides the christmasEvent switch, off by default", function()
			expect(LiveFlags.defaults()[GiftStallSave.FLAG]).never.to.equal(true)
		end)
	end)
end
