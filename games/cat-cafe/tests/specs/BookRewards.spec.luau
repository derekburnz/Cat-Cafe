--!strict
-- UI/Components/BookRewards.luau: the Book's per-area milestones (F48, data-model section 11b).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local BookRewards = require(Components:WaitForChild("BookRewards")) :: any

	local CATALOG = {
		cats = {
			{ id = "tabby", area = "alley" },
			{ id = "tuxedo", area = "alley" },
			{ id = "calico" }, -- no area: an Alleyway cat
			{ id = "siamese", area = "alley" },
			{ id = "corgi_cat", area = "park" },
		},
		bookMilestones = {
			{ id = "cats3", need = 3 },
			{ id = "cats6", need = 6 },
			{ id = "all4", need = 4 },
			{ id = "gold4", need = 4, gold = true },
		},
		bookPrizes = {
			alley = {
				cats3 = { coins = 300 },
				all4 = { lures = { salmon = 1 }, decorId = "book_alley" },
				gold4 = { decorId = "book_alley_gold" },
			},
			park = { cats3 = { coins = 1000 } },
		},
	}

	describe("BookRewards.counts", function()
		it("counts the area's cats found and gold, with no area meaning the Alleyway", function()
			local state = {
				collection = { tabby = 1, calico = 2, corgi_cat = 3 },
				goldCollection = { tabby = 1 },
			}
			local counts = BookRewards.counts(CATALOG, state, "alley")
			expect(counts.total).to.equal(4)
			expect(counts.found).to.equal(2)
			expect(counts.gold).to.equal(1)
			expect(BookRewards.counts(CATALOG, state, "park").found).to.equal(1)
		end)
	end)

	describe("BookRewards.views", function()
		it("skips milestones without a prize and keeps catalog order", function()
			local views = BookRewards.views(CATALOG, {}, "alley")
			expect(#views).to.equal(3)
			expect(views[1].milestone.id).to.equal("cats3")
			expect(views[2].milestone.id).to.equal("all4")
			expect(views[3].milestone.id).to.equal("gold4")
		end)

		it("marks reached milestones ready, claimed ones claimed, and caps the count", function()
			local state = {
				collection = { tabby = 1, tuxedo = 1, calico = 1, siamese = 1 },
				goldCollection = { tabby = 1 },
				bookRewards = { alley = { cats3 = true } },
			}
			local views = BookRewards.views(CATALOG, state, "alley")
			expect(views[1].state).to.equal("claimed")
			expect(views[2].state).to.equal("ready")
			expect(views[2].have).to.equal(4)
			expect(views[3].state).to.equal("locked")
			expect(views[3].have).to.equal(1)
		end)

		it("has no cards without milestones or prizes for the area", function()
			expect(#BookRewards.views({ cats = CATALOG.cats }, {}, "alley")).to.equal(0)
			expect(#BookRewards.views(CATALOG, {}, "woods")).to.equal(0)
		end)
	end)

	describe("BookRewards.claimable", function()
		it("counts ready milestones per area and in all", function()
			local state = { collection = { tabby = 1, tuxedo = 1, calico = 1 } }
			local perArea, total = BookRewards.claimable(CATALOG, state)
			expect(perArea.alley).to.equal(1)
			expect(perArea.park).to.equal(nil)
			expect(total).to.equal(1)
			local _, none = BookRewards.claimable(CATALOG, { collection = {} })
			expect(none).to.equal(0)
		end)
	end)

	describe("BookRewards labels", function()
		it("names the need, saying All once it is the whole page", function()
			expect(BookRewards.needLabel({ id = "cats3", need = 3 }, 10)).to.equal("3 cats")
			expect(BookRewards.needLabel({ id = "cats10", need = 10 }, 10)).to.equal("All 10")
			expect(BookRewards.needLabel({ id = "gold10", need = 10, gold = true }, 10)).to.equal(
				"All 10 gold"
			)
			expect(BookRewards.needLabel({ id = "gold10", need = 10, gold = true }, 12)).to.equal(
				"10 gold"
			)
		end)

		it("finds the milestone behind a Book decor piece and names it", function()
			local areaId, milestone = BookRewards.decorSource(CATALOG, "book_alley_gold")
			expect(areaId).to.equal("alley")
			expect(milestone.id).to.equal("gold4")
			expect(BookRewards.decorSource(CATALOG, "plants")).to.equal(nil)
			expect(BookRewards.unlockLabel(milestone, "Alleyway", 4)).to.equal(
				"All 4 Alleyway cats as gold"
			)
			expect(BookRewards.unlockLabel({ id = "cats10", need = 10 }, "Park", 10)).to.equal(
				"All 10 Park cats"
			)
			expect(BookRewards.isBookDecor({ id = "book_alley", source = "book" })).to.equal(true)
			expect(BookRewards.isBookDecor({ id = "plants" })).to.equal(false)
		end)

		it("finds normal pieces whose gold piece is owned and placed", function()
			local catalog = {
				cats = {},
				decor = {
					{ id = "book_alley" },
					{ id = "book_alley_gold", replaces = "book_alley" },
					{ id = "book_park_gold", replaces = "book_park" },
				},
			}
			local replaced = BookRewards.replacedBy(catalog, {
				decorOwned = { book_alley = true, book_alley_gold = true, book_park_gold = true },
				decorPlaced = { book_alley = true, book_alley_gold = true, book_park_gold = false },
			})
			expect(replaced.book_alley).to.equal("book_alley_gold")
			expect(replaced.book_park).to.equal(nil)
		end)

		it("lists a prize's foods in id order", function()
			local list = BookRewards.lureList({ lures = { tuna = 2, salmon = 1 } })
			expect(#list).to.equal(2)
			expect(list[1].id).to.equal("salmon")
			expect(list[2].count).to.equal(2)
			expect(#BookRewards.lureList({ coins = 5 })).to.equal(0)
		end)
	end)
end
