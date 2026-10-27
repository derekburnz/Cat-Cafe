--!strict
-- UI/Components/FoodOdds.luau: the odds text on every food card (data-model section 8, reviewer N69).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local FoodOdds = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("FoodOdds")
	) :: any

	describe("FoodOdds.percent", function()
		it("drops trailing zeros and keeps up to two decimals", function()
			expect(FoodOdds.percent(70)).to.equal("70%")
			expect(FoodOdds.percent(100)).to.equal("100%")
			expect(FoodOdds.percent(3.5)).to.equal("3.5%")
			expect(FoodOdds.percent(17.5)).to.equal("17.5%")
			expect(FoodOdds.percent(12.5)).to.equal("12.5%")
			expect(FoodOdds.percent(0.4)).to.equal("0.4%")
			expect(FoodOdds.percent(10)).to.equal("10%")
		end)
	end)

	describe("FoodOdds.split", function()
		it("adds each rarity's per-cat shares back up to its share (N69)", function()
			local Catalog = require(
				game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Catalog")
			) :: any
			local catalog = { cats = Catalog.cats, lures = Catalog.lures, areas = Catalog.areas }
			local off: { string } = {}
			for _, lure in Catalog.lures do
				for tier = 1, 5 do
					local split: string = FoodOdds.split(catalog, lure, tier)
					for line in split:gmatch("[^\n]+") do
						local share, cats = line:match("^%a+ ([%d%.]+)%%: (.+)$")
						if share then
							local sum, count = 0, 0
							for each in cats:gmatch("([%d%.]+)%%") do
								sum += tonumber(each) :: number
								count += 1
							end
							-- two decimals: each cat is at most 0.005 off
							if
								math.abs(sum - (tonumber(share) :: number))
								> count * 0.005 + 1e-6
							then
								table.insert(off, ("%s tier %d: %s"):format(lure.id, tier, line))
							end
						end
					end
				end
			end
			expect(off).to.deepEqual({})
		end)
	end)

	describe("FoodOdds.line", function()
		it("lists the five rarities in order", function()
			local line =
				FoodOdds.line({ Common = 70, Rare = 25, Epic = 4, Legendary = 0.9, Mythical = 0.1 })
			expect(line).to.equal(
				"Odds: 70% Common · 25% Rare · 4% Epic · 0.9% Legendary · 0.1% Mythical"
			)
		end)
	end)
end
