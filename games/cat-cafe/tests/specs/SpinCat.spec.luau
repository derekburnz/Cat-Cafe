--!strict
-- shared/SpinCat.luau and the cat slice in shared/Spin.luau (#5171, switch spinCat): off, the wheel is exactly
-- Catalog.spinWheel; on, a ninth slice gives a Secret cat at 0.25% (weight 0.5 of 200, from slice 1), which spin
-- luck never lifts. And the money rule behind it: nothing sold for Robux gives spins (monetization-policy).
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Catalog = require(ReplicatedStorage.Shared.Catalog)
	local Spin = require(ReplicatedStorage.Shared.Spin)
	local SpinCat = require(ReplicatedStorage.Shared.SpinCat)

	local function total(rows: { any }): number
		local sum = 0
		for _, row in rows do
			sum += row.weight
		end
		return sum
	end

	local function weightOf(rows: { any }, slice: number): number?
		for _, row in rows do
			if row.slice == slice then
				return row.weight
			end
		end
		return nil
	end

	describe("SpinCat (#5171)", function()
		afterEach(function()
			Spin.setCat(nil)
		end)

		it(
			"picks Lucky Clover, or Cafe Ghost while secretAreas is off, both real Secrets",
			function()
				expect(SpinCat.catFor(true)).to.equal("lucky_clover")
				expect(SpinCat.catFor(false)).to.equal("cafe_ghost")
				for _, id in { SpinCat.catFor(true), SpinCat.catFor(false) } do
					local def = Catalog.getCat(id)
					expect(def ~= nil).to.equal(true)
					expect((def :: any).rarity).to.equal("Secret")
				end
				expect(SpinCat.rowFor(false, true)).to.equal(nil)
				expect((SpinCat.rowFor(true, false) :: any).catId).to.equal("cafe_ghost")
			end
		)

		it("leaves the wheel exactly as it was with the switch off", function()
			Spin.setCat(nil)
			expect(Spin.wheel()).to.equal(Catalog.spinWheel)
			expect(Spin.rows(nil)).to.equal(Catalog.spinWheel)
			expect(Spin.slice(9)).to.equal(nil)
			expect(#Spin.rows(0.3)).to.equal(8)
		end)

		it(
			"adds a ninth slice at 0.25%, taken from slice 1, with the others' chances kept",
			function()
				Spin.setCat(SpinCat.row("lucky_clover"))
				local wheel = Spin.wheel()
				expect(#wheel).to.equal(9)
				expect(total(wheel)).to.equal(200)
				expect(weightOf(wheel, 9)).to.equal(0.5)
				expect(weightOf(wheel, 1)).to.equal(69.5)
				for slice = 2, 8 do
					expect(weightOf(wheel, slice)).to.equal(Catalog.spinWheel[slice].weight)
				end
				local cat = Spin.slice(9) :: any
				expect(cat.kind).to.equal("cat")
				expect(cat.catId).to.equal("lucky_clover")
				expect(cat.jackpot).to.equal(true)
				expect(Spin.amount(cat, 1000)).to.equal(1)
				-- Catalog.spinWheel itself is untouched (the world wheel and its effects read it)
				expect(#Catalog.spinWheel).to.equal(8)
				expect(Catalog.spinWheel[1].weight).to.equal(70)
			end
		)

		it("keeps the cat at 0.25% whatever the spin luck", function()
			Spin.setCat(SpinCat.row("lucky_clover"))
			for _, luck in { 0, 0.1, 0.2, 0.3, 0.9 } do
				local rows = Spin.rows(luck)
				expect(math.abs(total(rows) - 200) < 1e-9).to.equal(true)
				expect(weightOf(rows, 9)).to.equal(0.5)
			end
		end)

		it("lands on the cat for exactly a 0.25% share of rolls and returns its row", function()
			Spin.setCat(SpinCat.row("lucky_clover"))
			local rolls = 200000
			local hits = 0
			for k = 0, rolls - 1 do
				local row = Spin.pick(k / rolls, 0.3)
				if row.slice == 9 then
					hits += 1
					expect(row.kind).to.equal("cat")
				end
			end
			expect(math.abs(hits / rolls * 100 - 0.25) < 0.01).to.equal(true)
		end)

		it("names the cat in the jackpot toast and adds it up by cat in Use all", function()
			Spin.setCat(SpinCat.row("lucky_clover"))
			local text = Spin.jackpotText(Spin.slice(9) :: any, 1, nil) :: string
			expect(string.find(text, (Catalog.getCat("lucky_clover") :: any).name, 1, true) ~= nil).to.equal(
				true
			)
			local totals =
				Spin.summarize({ { slice = 9, amount = 1 }, { slice = 1, amount = 200 } })
			expect(#totals).to.equal(2)
			local catTotal: any = nil
			for _, each in totals do
				if each.kind == "cat" then
					catTotal = each
				end
			end
			expect(catTotal ~= nil and catTotal.id == "lucky_clover" and catTotal.amount == 1).to.equal(
				true
			)
		end)
	end)

	-- monetization-policy: a paid spin that can give a cat is a paid random item, so this slice is only allowed while
	-- spins are free. Fails if a Robux product, the paid Cafe Pass track or a shop row starts giving spins.
	describe("spins are never sold (#5171)", function()
		local function givesSpins(value: any, seen: { [any]: boolean }): boolean
			if type(value) ~= "table" or seen[value] then
				return false
			end
			seen[value] = true
			for key, each in value do
				if key == "spins" or key == "spin" or each == "spin" or each == "spins" then
					return true
				end
				if givesSpins(each, seen) then
					return true
				end
			end
			return false
		end

		it("no developer product gives spins", function()
			for _, product in Catalog.products do
				if givesSpins(product, {}) then
					error("product " .. product.id .. " gives spins")
				end
			end
		end)

		it("no paid Cafe Pass level gives spins", function()
			for _, season in Catalog.passSeasons do
				if givesSpins((season :: any).paid, {}) then
					error("season " .. (season :: any).id .. "'s paid track gives spins")
				end
			end
		end)

		it("nothing in the Golden Fish Market or the Corner Shop gives spins", function()
			for _, row in Catalog.fishShop do
				expect(givesSpins(row, {})).to.equal(false)
			end
			for _, row in Catalog.cornerShop do
				expect(givesSpins(row, {})).to.equal(false)
			end
		end)
	end)
end
