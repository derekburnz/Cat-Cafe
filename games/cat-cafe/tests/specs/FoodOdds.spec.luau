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
						-- a spare cat (F78) is in no area and never comes from bait
						local area = Catalog.areasById[def.area]
						if def.rarity == rarity and area and area.tier <= tier then
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

	describe("FoodOdds.split and spare cats (F78)", function()
		it("leaves spare cats out when the catalog has no areas", function()
			local catalog = {
				cats = {
					{ id = "tabby", name = "Tabby", rarity = "Common", area = "alley" },
					{ id = "calico", name = "Pirate Cat", rarity = "Common", area = "spare" },
				},
			}
			local lure = { id = "kibble", odds = { Common = 100 } }
			local split: string = FoodOdds.split(catalog, lure, 1)
			expect(split:find("Tabby", 1, true)).to.be.ok()
			expect(split:find("Pirate Cat", 1, true)).never.to.be.ok()
		end)
	end)

	describe("FoodOdds.split and the bait roll", function()
		it("names exactly the cats the server's bait roll can pick, at every tier (QA, F28)", function()
			local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
			local Catalog = require(Shared:WaitForChild("Catalog")) :: any
			local Catching = require(Shared:WaitForChild("Catching")) :: any
			local catalog = { cats = Catalog.cats, lures = Catalog.lures, areas = Catalog.areas }
			local wrong: { string } = {}
			for tier = 1, 5 do
				local split: string = FoodOdds.split(catalog, Catalog.luresById.kibble, tier)
				for _, rarity in Catalog.rarityOrder do
					local rolled: { [string]: boolean } = {}
					for i = 0, 239 do
						rolled[Catching.pickBaitCat(rarity, tier, (i + 0.5) / 240).name] = true
					end
					local shown: { [string]: boolean } = {}
					local cats = split:match("\n" .. rarity .. " [%d%.]+%%: ([^\n]+)") or ""
					for name in cats:gmatch("([^,]+) [%d%.]+%%") do
						shown[(name:gsub("^ ", ""))] = true
					end
					for name in rolled do
						if not shown[name] then
							table.insert(wrong, ("tier %d: the roll can pick %s, the card does not show it"):format(tier, name))
						end
					end
					for name in shown do
						if not rolled[name] then
							table.insert(wrong, ("tier %d: the card shows %s, the roll never picks it"):format(tier, name))
						end
					end
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

	describe("FoodOdds.rich", function()
		local function hexOf(rarity: string): string
			return if rarity == "Rare" then "2F80E0" else "6E7691"
		end

		it("puts each rarity's name and share in its own colour, in order", function()
			local row = FoodOdds.rich({ Common = 70, Rare = 25, Epic = 4.5, Legendary = 0.4, Mythical = 0.1 }, hexOf)
			-- a no-break space (U+00A0) between each name and its share
			expect(row).to.equal(
				'<font color="#6E7691">Common\u{00A0}70%</font>   <font color="#2F80E0">Rare\u{00A0}25%</font>   '
					.. '<font color="#6E7691">Epic\u{00A0}4.5%</font>   <font color="#6E7691">Legendary\u{00A0}0.4%</font>   '
					.. '<font color="#6E7691">Mythical\u{00A0}0.1%</font>'
			)
		end)

		it("shows every food's five rarities in order, adding up to 100, the same as the plain line", function()
			local Catalog = require(
				game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Catalog")
			) :: any
			local wrong: { string } = {}
			for _, lure in Catalog.lures do
				local plain = FoodOdds.rich(lure.odds, hexOf):gsub("<[^>]+>", "")
				local order: { string } = {}
				local sum = 0
				for rarity, share in plain:gmatch("(%a+)\u{00A0}([%d%.]+)%%") do
					sum += tonumber(share) :: number
					table.insert(order, rarity :: string)
				end
				if table.concat(order, ",") ~= table.concat(Catalog.rarityOrder, ",") or math.abs(sum - 100) > 0.025 then
					table.insert(wrong, lure.id .. ": " .. plain)
				end
			end
			expect(wrong).to.deepEqual({})
		end)

		it("says the odds are not set rather than showing none", function()
			expect(FoodOdds.rich(nil, hexOf)).to.equal("Odds: not set")
		end)
	end)

	describe("FoodOdds.extras", function()
		it("shows the shiny chance and the five charm star odds the server rolls with (QA)", function()
			local Config = require(
				game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config")
			) :: any
			local text = FoodOdds.extras()
			local shiny = text:match("^Gold ([%d%.]+)%% · Charm ")
			expect(shiny).to.be.ok()
			-- data-model section 8: GoldChanceBait (was ShinyChanceBait), so the card says its percent
			expect(tonumber(shiny or "") :: number).to.be.near(Config.GoldChanceBait * 100, 1e-9)
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

	describe("FoodOdds with the Index's forever bonuses (F54)", function()
		local Config = require(
			game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config")
		) :: any

		it("puts gold luck in the gold chance and says so", function()
			local base = Config.GoldChanceBait * 100
			local lucky = FoodOdds.extras(0.4)
			local gold, luck = lucky:match("^Gold ([%d%.]+)%% %(%+(%d+)%% luck%) · Charm ")
			expect(tonumber(gold or "") :: number).to.be.near(base * 1.4, 0.005)
			expect(luck).to.equal("40")
			expect(FoodOdds.extras(0)).to.equal(FoodOdds.extras())
			local capped = FoodOdds.extras(9):match("^Gold ([%d%.]+)%%")
			expect(tonumber(capped or "") :: number).to.be.near(base * 2.5, 0.005)
		end)

		it("adds a running potion's luck past the Index's cap and doubles for a Lucky Potion (F73)", function()
			local base = Config.GoldChanceBait * 100
			local rush = FoodOdds.extras(9, 0.25)
			local gold, luck = rush:match("^Gold ([%d%.]+)%% %(%+(%d+)%% luck%) · Charm ")
			-- BaitService: the Index's luck capped at GoldLuckMax, then the Gold Rush Potion's on top
			expect(tonumber(gold or "") :: number).to.be.near(base * (2.5 + 0.25), 0.005)
			expect(luck).to.equal("175")
			local lucky = FoodOdds.extras(0.4, 0.25, 2)
			local doubled, luck2 =
				lucky:match("^Gold ([%d%.]+)%% %(%+(%d+)%% luck, Lucky Potion x2%) · Charm ")
			expect(tonumber(doubled or "") :: number).to.be.near(base * 1.65 * 2, 0.005)
			expect(luck2).to.equal("65")
			local onlyLucky = FoodOdds.extras(0, 0, 2):match("^Gold ([%d%.]+)%% %(Lucky Potion x2%) · Charm ")
			expect(tonumber(onlyLucky or "") :: number).to.be.near(base * 2, 0.005)
			expect(FoodOdds.extras(0, 0, 1)).to.equal(FoodOdds.extras())
		end)

		it("shortens the bait wait by the faster bait, after the bowl level and the Big Bowl (F82)", function()
			local wait = Config.LureWaitSeconds -- 600, a level 1 bowl's
			expect(FoodOdds.waitSeconds(1, false, 0)).to.equal(wait)
			expect(FoodOdds.waitSeconds(0, false, 0)).to.equal(wait) -- no bowl reads as a level 1 bowl
			expect(FoodOdds.waitSeconds(1, true, nil)).to.equal(480)
			expect(FoodOdds.waitSeconds(1, false, 0.38)).to.equal(math.floor(wait * 0.62))
			expect(FoodOdds.waitSeconds(1, true, 0.9)).to.equal(240)
			-- the summed Index percents carry float error; the server adds a hair before flooring, so 372, not 371
			expect(FoodOdds.waitSeconds(1, false, 0.38000000000000012)).to.equal(372)
			-- F73: the Index's 0.38 and a Quick Bait Potion's 0.25 together stay inside BaitSpeedMax
			expect(FoodOdds.waitSeconds(1, false, 0.38 + 0.25)).to.equal(
				FoodOdds.waitSeconds(1, false, Config.BaitSpeedMax or 0.5)
			)
			-- each level's wait, as shared Bait.waitSeconds and the server's Economy.baitWaitSeconds
			local levels: { number } = Config.BowlWaitSeconds
			expect(#levels).to.equal(5)
			for level, seconds in levels do
				expect(FoodOdds.waitSeconds(level, false, 0)).to.equal(seconds)
				expect(FoodOdds.waitSeconds(level, true, 0)).to.equal(math.floor(seconds * 0.8 + 1e-6))
			end
			expect(FoodOdds.waitSeconds(2, true, 0)).to.equal(456)
			expect(FoodOdds.waitSeconds(5, false, 0.5)).to.equal(240)
			expect(FoodOdds.waitSeconds(9, false, 0)).to.equal(levels[5]) -- past the top reads as the top bowl
		end)

		it("halves the wait for food set at night, Big Bowl first, then the faster bait (F60)", function()
			local night = Config.LureWaitSecondsNight
			expect(night).to.equal(300)
			expect(FoodOdds.waitSeconds(1, false, 0, true)).to.equal(night)
			expect(FoodOdds.waitSeconds(1, true, 0, true)).to.equal(240)
			expect(FoodOdds.waitSeconds(1, false, 0.38, true)).to.equal(186)
			expect(FoodOdds.waitSeconds(1, true, 0.5, true)).to.equal(120)
			expect(FoodOdds.waitSeconds(1, false, 0, false)).to.equal(FoodOdds.waitSeconds(1, false, 0))
			expect(FoodOdds.waitSeconds(5, false, 0, true)).to.equal(240)
			expect(FoodOdds.waitSeconds(5, true, 0, true)).to.equal(192)
		end)
	end)

	describe("FoodOdds and the bowl levels (F82)", function()
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		local Catalog = require(Shared:WaitForChild("Catalog")) :: any
		local Bait = require(Shared:WaitForChild("Bait")) :: any
		local catalog = { cats = Catalog.cats, lures = Catalog.lures, areas = Catalog.areas }
		local salmon = Catalog.luresById.salmon

		it("shows a food's odds in the player's bowl, the table the server rolls", function()
			expect(FoodOdds.atBowl(nil, 3)).to.equal(nil)
			expect(FoodOdds.atBowl(salmon.odds, 0).Legendary).to.be.near(8.5, 1e-9)
			expect(FoodOdds.atBowl(salmon.odds, 1).Legendary).to.be.near(8.5, 1e-9)
			expect(FoodOdds.atBowl(salmon.odds, 2).Legendary).to.be.near(9.36, 1e-9)
			expect(FoodOdds.atBowl(salmon.odds, 5).Legendary).to.be.near(11.94, 1e-9)
			local off: { string } = {}
			for level = 0, 5 do
				for _, lure in Catalog.lures do
					local shown = FoodOdds.atBowl(lure.odds, level)
					local rolled = Bait.oddsFor(lure.odds, level)
					local total = 0
					for _, rarity in Catalog.rarityOrder do
						total += shown[rarity]
						if shown[rarity] ~= rolled[rarity] then
							table.insert(off, ("%s level %d %s"):format(lure.id, level, rarity))
						end
					end
					if math.abs(total - 100) > 1e-6 then
						table.insert(off, ("%s level %d adds to %s"):format(lure.id, level, tostring(total)))
					end
				end
			end
			expect(table.concat(off, "; ")).to.equal("")
		end)

		it("draws the card's row and the split at the bowl's shares", function()
			local row = FoodOdds.rich(FoodOdds.atBowl(salmon.odds, 2), function()
				return "000000"
			end)
			expect(row:find("Legendary" .. utf8.char(0xA0) .. "9.36%", 1, true)).to.be.ok()
			local plain: string = FoodOdds.split(catalog, salmon, 5)
			expect(FoodOdds.split(catalog, salmon, 5, 1)).to.equal(plain)
			expect(plain:find("moves", 1, true)).never.to.be.ok()
			local comfy: string = FoodOdds.split(catalog, salmon, 5, 2)
			expect(comfy:find("\nLegendary 9.36%: ", 1, true)).to.be.ok()
			expect(comfy:find("Your Comfy Bowl moves 4% of each rarity's chance up one rarity.", 1, true)).to.be.ok()
		end)

		it("names the next bowl, its wait and the Salmon's rarer cats on the shop row", function()
			local first, second = FoodOdds.bowlStep(catalog, 1, false)
			expect(first).to.equal("Next: Comfy Bowl · 9m 30s wait")
			expect(second).to.equal("Rarer bait cats: Salmon Legendary 8.5% to 9.36%")
			expect((FoodOdds.bowlStep(catalog, 1, true))).to.equal("Next: Comfy Bowl · 7m 36s wait")
			local royal, rarer = FoodOdds.bowlStep(catalog, 4, false)
			expect(royal).to.equal("Next: Royal Bowl · 8m wait")
			expect(rarer).to.equal("Rarer bait cats: Salmon Legendary 11.08% to 11.94%")
		end)

		it("keeps the catalog's line before the first bowl and names the top bowl at the top", function()
			local first, second = FoodOdds.bowlStep(catalog, 0, false)
			expect(first).to.equal("Next: Bait Bowl · 10m wait")
			expect(second).to.equal(nil)
			local top, line = FoodOdds.bowlStep(catalog, 5, false)
			expect(top).to.equal("Royal Bowl · 8m wait")
			expect(line).to.equal("Top bowl: bait cats at their rarest")
		end)
	end)
end
