--!strict
-- #4920 item 7: the Rank Up window's grey button says what is still missing (RankUpNeeds.missing), the first need
-- not met: cats, then the rarity, then the coins.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local RankUpNeeds =
		require(Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("RankUpNeeds"))

	local function money(amount: number): string
		return "$" .. tostring(amount)
	end

	local function needs(fields: { [string]: any }): any
		local base: { [string]: any } = {
			coinsHave = 100,
			coinsNeed = 100,
			catsHave = 6,
			catsNeed = 6,
			rarity = nil,
			rarityHave = 0,
			rarityNeed = 0,
			ready = false,
		}
		for key, value in fields do
			base[key] = value
		end
		return base
	end

	local KINDS: any = { distinctCats = 6 }
	local ANY: any = { distinctCats = 3, anyCats = true }

	describe("RankUpNeeds.missing (#4920)", function()
		it("names the kinds still to catch first", function()
			expect(RankUpNeeds.missing(KINDS, needs({ catsHave = 4, coinsHave = 0 }), money)).to.equal(
				"Need 2 more kinds"
			)
			expect(RankUpNeeds.missing(KINDS, needs({ catsHave = 5 }), money)).to.equal("Need 1 more kind")
		end)

		it("says cats where any cats count (Tier 2, #4809)", function()
			expect(RankUpNeeds.missing(ANY, needs({ catsHave = 1, catsNeed = 3 }), money)).to.equal(
				"Need 2 more cats"
			)
			expect(RankUpNeeds.missing(ANY, needs({ catsHave = 2, catsNeed = 3 }), money)).to.equal(
				"Need 1 more cat"
			)
		end)

		it("then the rarity, then the coins", function()
			local rare = needs({ rarity = "Rare", rarityHave = 0, rarityNeed = 2, coinsHave = 0 })
			expect(RankUpNeeds.missing(KINDS, rare, money)).to.equal("Need 2 more Rare+")
			local one = needs({ rarity = "Legendary", rarityHave = 0, rarityNeed = 1 })
			expect(RankUpNeeds.missing(KINDS, one, money)).to.equal("Need a Legendary+ cat")
			expect(RankUpNeeds.missing(KINDS, needs({ coinsHave = 40 }), money)).to.equal("Need $60 more")
		end)

		it("is nil when nothing is missing", function()
			expect(RankUpNeeds.missing(KINDS, needs({}), money)).to.equal(nil)
		end)

		it("fits the 260 px button: at most 22 letters for every rarity", function()
			for _, rarity in { "Rare", "Epic", "Legendary", "Mythical", "Secret" } do
				for _, short in { 1, 2, 9 } do
					local line = RankUpNeeds.missing(
						KINDS,
						needs({ rarity = rarity, rarityHave = 0, rarityNeed = short }),
						money
					) :: string
					expect(#line <= 22).to.equal(true)
				end
			end
		end)
	end)
end
