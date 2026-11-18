--!strict
-- UI/Components/GiftStallLogic: the Christmas Event's Gift Stall rows and buttons (snowglobe-village-spec section 5).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Logic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("GiftStallLogic")
	) :: any

	describe("GiftStallLogic", function()
		it(
			"sells the spec's 8 items, 3 outfits and 5 decor, for 1,800 Snowflakes in all",
			function()
				local total, outfits, decor = 0, 0, 0
				for _, item in Logic.ITEMS do
					total += item.cost
					if item.kind == "outfit" then
						outfits += 1
					else
						decor += 1
					end
				end
				expect(#Logic.ITEMS).to.equal(8)
				expect(outfits).to.equal(3)
				expect(decor).to.equal(5)
				expect(total).to.equal(Logic.TOTAL)
				expect(Logic.TOTAL).to.equal(1800)
			end
		)

		it("starts from PlayerState.snowflakes with nothing owned", function()
			local view = Logic.defaultView({ snowflakes = 420.7 })
			expect(view.snowflakes).to.equal(420)
			expect(#view.items).to.equal(8)
			expect(Logic.flakes(Logic.defaultView({}))).to.equal(0) -- nil is 0
			expect(Logic.flakes(Logic.defaultView(nil))).to.equal(0)
			for _, item in view.items do
				expect(item.owned).to.equal(false)
			end
		end)

		it("splits rows by tab and takes the view's cost and owned", function()
			local view = {
				snowflakes = 200,
				items = {
					{ id = "santa_hat", name = "Santa Hat", cost = 150, owned = true },
					{ id = "snowman", name = "Snowman", cost = 200, owned = false },
					{ id = "little_tree", name = "Little Lit Tree", cost = 350, owned = false },
					{ id = "mystery_new", name = "New Thing", cost = 10, owned = false },
				},
			}
			local outfits = Logic.rows(view, "outfit")
			expect(#outfits).to.equal(1)
			expect(outfits[1].owned).to.equal(true)
			local decor = Logic.rows(view, "decor")
			expect(#decor).to.equal(3) -- an id the client does not know lands on Decor
			expect(decor[3].model).to.equal(nil)
			expect(Logic.owns(view, "santa_hat")).to.equal(true)
			expect(Logic.owns(view, "snowman")).to.equal(false)
		end)

		it("shows Owned, the price in gold when affordable, and grey when short", function()
			local view = { snowflakes = 200, items = {} }
			local owned = Logic.action(
				view,
				{ id = "a", kind = "decor", name = "A", cost = 100, owned = true }
			)
			expect(owned.mode).to.equal("owned")
			expect(owned.enabled).to.equal(false)
			local buy = Logic.action(
				view,
				{ id = "b", kind = "decor", name = "B", cost = 200, owned = false }
			)
			expect(buy.mode).to.equal("buy")
			expect(buy.enabled).to.equal(true)
			expect(buy.style).to.equal("gold")
			local short = Logic.action(
				view,
				{ id = "c", kind = "decor", name = "C", cost = 201, owned = false }
			)
			expect(short.mode).to.equal("short")
			expect(short.enabled).to.equal(false)
		end)
	end)
end
