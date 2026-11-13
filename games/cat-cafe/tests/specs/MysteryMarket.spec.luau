--!strict
-- shared/MysteryMarket.luau (#2565, mystery-market.md sections 2 and 5): the weekly featured sale on the global
-- clock, its price, and who can buy.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local MysteryMarket = require(Shared.MysteryMarket)
	local ProfileSchema = require(Shared.ProfileSchema)

	local WEEK = Config.MysteryRotateSeconds
	local epoch = Config.MysteryEpoch
	local backpack = Catalog.getMysteryItem("backpack") :: any
	local longNet = Catalog.getMysteryItem("long_net") :: any

	describe("the shelf (section 4d)", function()
		it(
			"has the Backpack, the Long Net and the Speed Shoes (#3535), golden fish only",
			function()
				expect(#Catalog.mysteryItems).to.equal(3)
				expect(Catalog.mysteryItems[3].id).to.equal("speed_shoes")
				expect(Catalog.mysteryItems[3].cost).to.equal(500)
				expect(Catalog.mysteryItems[3].minTier).to.equal(1)
				expect(Catalog.mysteryItems[3].flag).to.equal("speedShoes")
				expect(backpack.flag).to.equal(nil)
				expect(longNet.flag).to.equal(nil)
				expect(Catalog.mysteryItems[1].id).to.equal("backpack")
				expect(backpack.cost).to.equal(400)
				expect(backpack.minTier).to.equal(1)
				expect(longNet.cost).to.equal(320)
				expect(longNet.minTier).to.equal(2)
				expect(Config.MysterySaleShare).to.equal(0.75)
				expect(WEEK).to.equal(604800)
			end
		)

		it("starts its weeks on a Saturday 00:00 UTC", function()
			expect(epoch % 86400).to.equal(0)
			expect((epoch // 86400 + 4) % 7).to.equal(6) -- 1970-01-01 was a Thursday (4)
		end)
	end)

	describe("the weekly sale (section 2b)", function()
		-- #3535: Friday 2026-11-13 22:00 UTC, the update; a week later; Saturday 2026-11-28 00:00 UTC
		local FRIDAY, NEXT_FRIDAY, BACK = 1794607200, 1795212000, 1795824000

		it("features the Backpack in the launch week until Friday's update", function()
			local launch = epoch + 2 * 86400 + 12 * 3600 -- Monday 2026-11-09 12:00 UTC
			expect(MysteryMarket.featuredAt(launch)).to.equal("backpack")
			expect(MysteryMarket.featuredAt(epoch)).to.equal("backpack")
			expect(MysteryMarket.featuredAt(FRIDAY - 1)).to.equal("backpack")
			expect(MysteryMarket.nextFeatured(epoch + 10)).to.equal("speed_shoes")
		end)

		it("features the Speed Shoes for the update's week, then the Long Net (#3535)", function()
			expect(FRIDAY).to.equal(epoch + WEEK - 7200) -- Friday 22:00 UTC
			expect(NEXT_FRIDAY).to.equal(FRIDAY + WEEK)
			expect(BACK).to.equal(epoch + 3 * WEEK) -- a rotation week's own start
			expect(#Config.MysteryFeatured).to.equal(2)
			expect(MysteryMarket.featuredAt(FRIDAY)).to.equal("speed_shoes")
			expect(MysteryMarket.featuredAt(NEXT_FRIDAY - 1)).to.equal("speed_shoes")
			expect(MysteryMarket.featuredAt(NEXT_FRIDAY)).to.equal("long_net")
			expect(MysteryMarket.featuredAt(BACK - 1)).to.equal("long_net")
			expect(MysteryMarket.nextFeatured(FRIDAY)).to.equal("long_net")
			expect(MysteryMarket.nextFeatured(NEXT_FRIDAY)).to.equal("backpack")
		end)

		it("carries on with the rotation after the dated weeks, one item a week", function()
			expect(MysteryMarket.featuredAt(BACK)).to.equal("backpack")
			expect(MysteryMarket.featuredAt(BACK + WEEK)).to.equal("long_net")
			expect(MysteryMarket.featuredAt(BACK + 2 * WEEK)).to.equal("speed_shoes")
			expect(MysteryMarket.featuredAt(BACK + 3 * WEEK)).to.equal("backpack")
			-- the dated weeks never overlap and each names a real item
			local last = -math.huge
			for _, entry in Config.MysteryFeatured do
				expect(entry.from >= last).to.equal(true)
				expect(entry.to > entry.from).to.equal(true)
				expect(Catalog.getMysteryItem(entry.id) ~= nil).to.equal(true)
				last = entry.to
			end
		end)

		it("ends each sale where the next one starts", function()
			expect(MysteryMarket.nextAt(epoch)).to.equal(FRIDAY)
			expect(MysteryMarket.nextAt(FRIDAY - 1)).to.equal(FRIDAY)
			expect(MysteryMarket.nextAt(FRIDAY)).to.equal(NEXT_FRIDAY)
			expect(MysteryMarket.nextAt(NEXT_FRIDAY)).to.equal(BACK)
			expect(MysteryMarket.nextAt(BACK)).to.equal(BACK + WEEK)
			expect(MysteryMarket.nextAt(BACK + WEEK - 1)).to.equal(BACK + WEEK)
		end)

		it("keeps an item behind a live switch off the shelf until the switch is on", function()
			local shoes = Catalog.getMysteryItem("speed_shoes") :: any
			expect(MysteryMarket.listed(shoes, nil)).to.equal(false)
			expect(MysteryMarket.listed(shoes, {})).to.equal(false)
			expect(MysteryMarket.listed(shoes, { speedShoes = false })).to.equal(false)
			expect(MysteryMarket.listed(shoes, { speedShoes = true })).to.equal(true)
			expect(MysteryMarket.listed(backpack, nil)).to.equal(true)
		end)

		it(
			"prices the featured item at 0.75, to the nearest 5, and the rest at full price",
			function()
				expect(MysteryMarket.salePrice(400)).to.equal(300)
				expect(MysteryMarket.salePrice(320)).to.equal(240)
				expect(MysteryMarket.salePrice(260)).to.equal(195)
				expect(MysteryMarket.salePrice(150)).to.equal(115) -- 112.5 rounds up
				expect(MysteryMarket.priceOf(backpack, epoch)).to.equal(300)
				expect(MysteryMarket.priceOf(longNet, epoch)).to.equal(320)
				-- #3535: from Friday's update the Backpack is back at 400 and the Speed Shoes are 375, 500 after
				local shoes = Catalog.getMysteryItem("speed_shoes") :: any
				expect(MysteryMarket.priceOf(backpack, 1794607200)).to.equal(400)
				expect(MysteryMarket.priceOf(longNet, 1794607200)).to.equal(320)
				expect(MysteryMarket.priceOf(shoes, 1794607200 - 1)).to.equal(500)
				expect(MysteryMarket.priceOf(shoes, 1794607200)).to.equal(375)
				expect(MysteryMarket.priceOf(shoes, 1795212000 - 1)).to.equal(375)
				expect(MysteryMarket.priceOf(shoes, 1795212000)).to.equal(500)
				expect(MysteryMarket.priceOf(longNet, 1795212000)).to.equal(240)
			end
		)
	end)

	describe("canBuy", function()
		local function profileWith(fish: number, tier: number): any
			local p: any = ProfileSchema.template(0)
			p.goldenFish = fish
			p.tier = tier
			return p
		end

		it("needs the fish at this week's price", function()
			expect(MysteryMarket.canBuy(profileWith(300, 1), backpack, epoch)).to.equal(true)
			local ok, why = MysteryMarket.canBuy(profileWith(299, 1), backpack, epoch)
			expect(ok).to.equal(false)
			expect(why).to.equal(MysteryMarket.FISH_TEXT)
			expect(MysteryMarket.canBuy(profileWith(300, 1), backpack, epoch + WEEK)).to.equal(
				false
			)
		end)

		it("refuses an owned item and one above the player's tier", function()
			local p = profileWith(1000, 1)
			local ok, why = MysteryMarket.canBuy(p, longNet, epoch)
			expect(ok).to.equal(false)
			expect(why).to.equal("Opens at Tier 2")
			p.mystery.backpack = true
			ok, why = MysteryMarket.canBuy(p, backpack, epoch)
			expect(ok).to.equal(false)
			expect(why).to.equal(MysteryMarket.OWNED_TEXT)
		end)

		it("opens with the save version bump (Config.MysteryOpen, version 44)", function()
			expect(Config.MysteryOpen).to.equal(true)
			expect(ProfileSchema.VERSION >= 44).to.equal(true)
		end)
	end)
end
