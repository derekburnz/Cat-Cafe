--!strict
-- shared/NetTiers.luau (#5170): Perfect hits per net level and rarity match Design's table, never under two, and the
-- net's caps, maxLevel and windows follow the switch.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Circles = require(Shared.Circles)
	local Config = require(Shared.Config)
	local LiveFlags = require(Shared.LiveFlags)
	local NetTiers = require(Shared.NetTiers)

	local function hits(rarity: string, netLevel: number): number
		local trust = Circles.trustFor(rarity :: any)
		local start = trust.start + NetTiers.trustBonus(netLevel, trust.start, trust.need)
		local n = 0
		while start < trust.need do
			start += Config.TrustPerfect
			n += 1
		end
		return n
	end

	local TABLE: { [string]: { number } } = {
		-- net level 0 to 5
		Common = { 3, 2, 2, 2, 2, 2 },
		Rare = { 4, 3, 3, 2, 2, 2 },
		Epic = { 5, 4, 4, 3, 3, 2 },
		Legendary = { 6, 5, 5, 4, 4, 3 },
		Mythical = { 7, 6, 6, 5, 5, 4 },
		Secret = { 8, 7, 7, 6, 6, 5 },
	}

	describe("NetTiers", function()
		it("cuts Perfect hits per Design's table", function()
			for rarity, row in TABLE do
				if Catalog.rarities[rarity] ~= nil then
					for level = 0, 5 do
						expect(hits(rarity, level)).to.equal(row[level + 1])
					end
				end
			end
		end)

		it("never lets one hit catch, and never takes from another bonus", function()
			for rarity in Catalog.rarities do
				local plain = Circles.trustFor(rarity :: any)
				local start = plain.start + NetTiers.trustBonus(5, plain.start, plain.need)
				expect(start + Config.TrustPerfect < plain.need).to.equal(true)
				-- a Curious head start already past the room gets nothing more, and nothing taken away
				local curious = Circles.trustFor(rarity :: any, plain.need)
				expect(NetTiers.trustBonus(5, curious.start, curious.need)).to.equal(0)
			end
		end)

		it("opens Net 4 at Tier 7 and Net 5 at Tier 9 only with the switch on, and back", function()
			local net = Catalog.getUpgrade("net") :: any
			Catalog.setNetTiers(true)
			expect(net.maxLevel).to.equal(5)
			expect(Catalog.tierForLevel("net", 4)).to.equal(7)
			expect(Catalog.tierForLevel("net", 5)).to.equal(9)
			expect(net.costs[4]).to.equal(15000000000)
			expect(net.costs[5]).to.equal(1500000000000)
			expect(Circles.windows(5).good).to.equal(Config.NetWindows[5].good)
			Catalog.setNetTiers(false)
			expect(net.maxLevel).to.equal(3)
			expect(Catalog.tierForLevel("net", 4)).to.equal(nil)
			expect(Catalog.tierForLevel("net", 3)).to.equal(5)
			-- a level 4 or 5 save, or a potion on Net 3, plays Net 3's windows with the switch off
			expect(Circles.windows(4).good).to.equal(Config.NetWindows[3].good)
			expect(Circles.windows(6).good).to.equal(Config.NetWindows[3].good)
		end)

		it("is off by default", function()
			expect(LiveFlags.OFF_BY_DEFAULT[NetTiers.FLAG]).to.equal(true)
		end)
	end)
end
