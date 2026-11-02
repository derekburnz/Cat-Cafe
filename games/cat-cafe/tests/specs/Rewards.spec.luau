--!strict
-- Every prize table against rewards-and-shops.md sections 1 and 2 (F94): no shop food in any prize, at most two
-- pictures a prize and three on the big ones, and the money wording of section 5. QA checks 1 to 3 and 7.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Catalog = require(ReplicatedStorage.Shared.Catalog)

	local SHOP_FOOD = { kibble = true, tuna = true, salmon = true }
	-- tester codes keep their big prizes (section 2f: `playtest` stays as it is and ends before the game is public)
	local TESTER_CODES = { playtest = true, playtest2 = true }

	-- The pictures a prize shows: coins, golden fish, spins, and one for each food, crate and potion. A forever bonus
	-- and a name tag do not count (section 1, rule 3).
	local function pictures(prize: any): number
		local n = 0
		if prize.coins ~= nil or prize.coinSeconds ~= nil then
			n += 1
		end
		if prize.fish ~= nil then
			n += 1
		end
		if prize.spins ~= nil then
			n += 1
		end
		for _, field in { "lures", "crates", "potions" } do
			for _ in prize[field] or {} do
				n += 1
			end
		end
		return n
	end

	-- Every prize in the game as { name, prize, big }, the big ones as section 1 lists them.
	local function everyPrize(): { { name: string, prize: any, big: boolean } }
		local out = {}
		local function add(name: string, prize: any, big: boolean)
			table.insert(out, { name = name, prize = prize, big = big })
		end
		for _, row in Catalog.tipJar do
			add("tipJar " .. row.step, row.prize, row.minutes == 120)
		end
		for _, row in Catalog.dailyTreat do
			add("dailyTreat " .. row.day, row.prize, row.day == 7)
		end
		for id, prize in Catalog.questPrizes do
			add("quest " .. id, prize, id == "dailySet" or id == "weeklySet")
		end
		for size, prize in Catalog.achievementPrizes do
			add("achievement " .. size, prize, size == "XL")
		end
		local finishers = { cats10 = true, gold10 = true, total25 = true, total50 = true }
		for page, prizes in Catalog.indexPrizes do
			for id, prize in prizes do
				add("index " .. page .. " " .. id, prize, finishers[id] == true)
			end
		end
		for _, row in Catalog.collectorOffers do
			add("collector " .. row.value, row, false)
		end
		for id, code in Catalog.codes do
			if not TESTER_CODES[id] then
				add("code " .. id, code.prize, true)
			end
		end
		return out
	end

	describe("no shop food in prizes (section 1 rule 1, QA check 1)", function()
		it("no table, wheel slice, gift or code but the tester codes pays Kibble, Tuna or Salmon", function()
			for _, entry in everyPrize() do
				for lureId: string in entry.prize.lures or {} do
					if SHOP_FOOD[lureId] then
						error(string.format("%s pays %s", entry.name, lureId))
					end
				end
			end
			for _, row in Catalog.spinWheel do
				expect(row.kind == "lure" and SHOP_FOOD[row.lureId :: string] == true).to.equal(false)
			end
			for _, row in Catalog.mysteryGift do
				expect(row.kind == "lure" and SHOP_FOOD[row.id :: string] == true).to.equal(false)
			end
		end)

		it("pays food only as a dealer food, one or two at a time", function()
			for _, entry in everyPrize() do
				for lureId, count in entry.prize.lures or {} do
					local def = Catalog.getLure(lureId)
					assert(def ~= nil, entry.name)
					expect(def.source).to.equal("dealer")
					expect(count <= 2).to.equal(true)
				end
			end
		end)
	end)

	describe("two pictures a prize, three for the big ones (section 1 rule 3, QA check 2)", function()
		it("never shows more", function()
			for _, entry in everyPrize() do
				local most = if entry.big then 3 else 2
				if pictures(entry.prize) > most then
					error(string.format("%s shows %d pictures", entry.name, pictures(entry.prize)))
				end
			end
		end)

		it("does not count a forever bonus or a name tag", function()
			expect(pictures(Catalog.indexPrizes.alley.gold10)).to.equal(3)
			expect(pictures(Catalog.indexPrizes.all.total50)).to.equal(3)
			expect(pictures(Catalog.indexPrizes.alley.cats6)).to.equal(2)
		end)
	end)

	describe("the new rows (section 2, QA check 3)", function()
		it("the Tip Jar's two hour gift is a Classic Crate and 30 golden fish", function()
			expect(Catalog.tipJar[12].minutes).to.equal(120)
			expect(Catalog.tipJar[12].prize :: any).to.deepEqual({
				crates = { classic_crate = 1 },
				fish = 30,
			})
		end)

		it("the wheel's slice 2 pays 3 golden fish and slice 4 a Caviar", function()
			expect(Catalog.spinWheel[2].kind).to.equal("fish")
			expect(Catalog.spinWheel[2].count).to.equal(3)
			expect(Catalog.spinWheel[4].lureId).to.equal("caviar")
			expect(Catalog.spinWheel[4].count).to.equal(1)
		end)

		it("cats6 pays each area's crate with fish or two of its dealer food", function()
			local want: { [string]: any } = {
				alley = { fish = 5 },
				park = { fish = 10 },
				neighbourhood = { lures = { caviar = 2 } },
				woods = { lures = { moon_milk = 2 } },
				sewer = { lures = { star_treat = 2 } },
			}
			for area, extra in want do
				local prize = Catalog.indexPrizes[area].cats6 :: any
				expect(prize.crates[area .. "_crate"]).to.equal(1)
				expect(prize.fish).to.equal((extra :: any).fish)
				expect(prize.lures).to.deepEqual((extra :: any).lures)
				expect(prize.spins).never.to.be.ok()
			end
		end)

		it("gold6 pays 10 more golden fish than before and no food or spins", function()
			local fish: { [string]: number } = { alley = 50, park = 60, neighbourhood = 70, woods = 90, sewer = 110 }
			for area, count in fish do
				local prize = Catalog.indexPrizes[area].gold6
				expect(prize.fish).to.equal(count)
				expect(prize.lures).never.to.be.ok()
				expect(prize.spins).never.to.be.ok()
			end
		end)

		it("a Mystery gift is a potion 60%, 10 golden fish 30% or a spin 10%", function()
			local chances: { [string]: number } = {}
			for _, row in Catalog.mysteryGift do
				chances[row.kind] = row.chance
			end
			expect(chances :: any).to.deepEqual({ potion = 60, fish = 30, spin = 10 })
		end)
	end)

	describe("money, not tips (section 5, QA check 7)", function()
		it("names the Tip Potions Money Potions and keeps their ids", function()
			local tip = Catalog.getPotion("tip_potion")
			local big = Catalog.getPotion("big_tip_potion")
			assert(tip ~= nil and big ~= nil)
			expect(tip.name).to.equal("Money Potion")
			expect(tip.effect).to.equal("+25% money")
			expect(big.name).to.equal("Big Money Potion")
			expect(big.effect).to.equal("+50% money")
		end)

		it("never says tips on a potion, a decor piece or an upgrade", function()
			for _, def in Catalog.potions do
				expect(string.find(string.lower(def.name .. def.effect), "tip", 1, true)).never.to.be.ok()
			end
			for _, def in Catalog.decor do
				expect(string.find(string.lower(def.effect or ""), "tips", 1, true)).never.to.be.ok()
			end
			for _, def in Catalog.crateDecor do
				expect(string.find(string.lower(def.effect or ""), "tips", 1, true)).never.to.be.ok()
			end
			for _, def in Catalog.upgrades do
				expect(string.find(string.lower(def.description or ""), "tips", 1, true)).never.to.be.ok()
			end
		end)
	end)
end
