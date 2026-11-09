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
		it("launches with the Backpack and the Long Net, golden fish only", function()
			expect(#Catalog.mysteryItems).to.equal(2)
			expect(Catalog.mysteryItems[1].id).to.equal("backpack")
			expect(backpack.cost).to.equal(400)
			expect(backpack.minTier).to.equal(1)
			expect(longNet.cost).to.equal(320)
			expect(longNet.minTier).to.equal(2)
			expect(Config.MysterySaleShare).to.equal(0.75)
			expect(WEEK).to.equal(604800)
		end)

		it("starts its weeks on a Saturday 00:00 UTC", function()
			expect(epoch % 86400).to.equal(0)
			expect((epoch // 86400 + 4) % 7).to.equal(6) -- 1970-01-01 was a Thursday (4)
		end)
	end)

	describe("the weekly sale (section 2b)", function()
		it("features the Backpack in the launch week, then alternates", function()
			local launch = epoch + 2 * 86400 + 12 * 3600 -- Monday 2026-11-09 12:00 UTC
			expect(MysteryMarket.featuredAt(launch)).to.equal("backpack")
			expect(MysteryMarket.featuredAt(epoch)).to.equal("backpack")
			expect(MysteryMarket.featuredAt(epoch + WEEK - 1)).to.equal("backpack")
			expect(MysteryMarket.featuredAt(epoch + WEEK)).to.equal("long_net")
			expect(MysteryMarket.featuredAt(epoch + 2 * WEEK)).to.equal("backpack")
			expect(MysteryMarket.nextFeatured(epoch + 10)).to.equal("long_net")
			-- before the epoch the count still cycles (floored)
			expect(MysteryMarket.featuredAt(epoch - 1)).to.equal("long_net")
		end)

		it("ends the sale at the next week's start", function()
			expect(MysteryMarket.nextAt(epoch)).to.equal(epoch + WEEK)
			expect(MysteryMarket.nextAt(epoch + WEEK - 1)).to.equal(epoch + WEEK)
			expect(MysteryMarket.nextAt(epoch + WEEK)).to.equal(epoch + 2 * WEEK)
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
				expect(MysteryMarket.priceOf(backpack, epoch + WEEK)).to.equal(400)
				expect(MysteryMarket.priceOf(longNet, epoch + WEEK)).to.equal(240)
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
