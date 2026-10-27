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
						if share and cats then
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

		it("names the cats of the unlocked areas only and the area the next rank up adds (QA)", function()
			local Catalog = require(
				game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Catalog")
			) :: any
			local catalog = { cats = Catalog.cats, lures = Catalog.lures, areas = Catalog.areas }
			local kibble = Catalog.luresById.kibble
			local wrong: { string } = {}
			for tier = 1, 5 do
				local split: string = FoodOdds.split(catalog, kibble, tier)
				local nextArea = nil
				for _, area in Catalog.areas do
					if area.tier == tier + 1 then
						nextArea = area
					end
				end
				for _, rarity in Catalog.rarityOrder do
					local expected: { string } = {}
					for _, def in Catalog.cats do
						if def.rarity == rarity and Catalog.areasById[def.area].tier <= tier then
							table.insert(expected, def.name)
						end
					end
					local listed: { string } = {}
					local cats = split:match("\n" .. rarity .. " [%d%.]+%%: ([^\n]+)")
					for name in (cats or ""):gmatch("([^,]+) [%d%.]+%%") do
						table.insert(listed, (name:gsub("^ ", "")))
					end
					table.sort(expected)
					table.sort(listed)
					if table.concat(listed, ",") ~= table.concat(expected, ",") then
						table.insert(wrong, ("tier %d %s: %s"):format(tier, rarity, cats or "missing"))
					end
				end
				local rankTier, rankArea = split:match("Rank up to Tier (%d+) to add the (.-) cats")
				local got = if rankTier and rankArea then rankTier .. " " .. rankArea else nil
				local expected = if nextArea then ("%d %s"):format(nextArea.tier, nextArea.name) else nil
				if got ~= expected then
					table.insert(wrong, ("tier %d rank up: %s"):format(tier, tostring(got)))
				end
			end
			expect(wrong).to.deepEqual({})
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

		it("shows every food's five rarities in the catalog's order, adding up to 100 (QA)", function()
			local Catalog = require(
				game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Catalog")
			) :: any
			local wrong: { string } = {}
			for _, lure in Catalog.lures do
				local line: string = FoodOdds.line(lure.odds)
				local order: { string } = {}
				local sum = 0
				for share, rarity in line:gmatch("([%d%.]+)%% (%a+)") do
					sum += tonumber(share) :: number
					table.insert(order, rarity :: string)
				end
				-- two decimals: each of the five shares is at most 0.005 off
				if table.concat(order, ",") ~= table.concat(Catalog.rarityOrder, ",") or math.abs(sum - 100) > 0.025 then
					table.insert(wrong, lure.id .. ": " .. line)
				end
			end
			expect(wrong).to.deepEqual({})
		end)

		it("says the odds are not set rather than showing none (QA)", function()
			expect(FoodOdds.line(nil)).to.equal("Odds: not set")
		end)
	end)

	describe("FoodOdds.extras", function()
		it("shows the shiny chance and the five charm star odds the server rolls with (QA)", function()
			local Config = require(
				game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config")
			) :: any
			local text = FoodOdds.extras()
			local shiny = text:match("^Shiny ([%d%.]+)%% · Charm ")
			expect(shiny).to.be.ok()
			-- data-model section 8: ShinyChanceBait 0.02, so the card says 2%
			expect(tonumber(shiny or "") :: number).to.be.near((Config.ShinyChanceBait or 0.02) * 100, 1e-9)
			local shares: { number } = {}
			local sum = 0
			for count, share in text:gmatch("(%d)★ ([%d%.]+)%%") do
				expect(tonumber(count)).to.equal(#shares + 1)
				table.insert(shares, tonumber(share) :: number)
				sum += tonumber(share) :: number
			end
			expect(#shares).to.equal(5)
			expect(sum).to.be.near(100, 0.05)
			if Config.CharmStarOdds then
				for index, share in Config.CharmStarOdds do
					expect(shares[index]).to.be.near(share, 0.005 + 1e-9)
				end
			end
		end)
	end)
end
