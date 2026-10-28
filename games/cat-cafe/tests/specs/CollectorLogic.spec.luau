--!strict
-- UI/Components/CollectorLogic.luau: the Cat Collector's card turns his offer into pictures, asks twice before a
-- rare trade and opens near him (F63, data-model section 12b).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local CollectorLogic = require(Components:WaitForChild("CollectorLogic")) :: any

	describe("CollectorLogic.prize", function()
		it("names the wanted cat's own area crates", function()
			local prize = CollectorLogic.prize({ value = 12, crates = { zone = 1 }, fish = 20 }, "park")
			expect(prize.fish).to.equal(20)
			expect(prize.crates.park_crate).to.equal(1)
			expect(prize.crates.park_golden_crate).to.equal(nil)
			local golden =
				CollectorLogic.prize({ value = 120, crates = { golden = 2 }, fish = 100 }, "woods")
			expect(golden.crates.woods_golden_crate).to.equal(2)
			expect(golden.crates.woods_crate).to.equal(nil)
		end)

		it("keeps foods and spins and drops empty parts", function()
			local prize = CollectorLogic.prize({ value = 2, lures = { tuna = 3 }, spins = 1 }, "alley")
			expect(prize.lures.tuna).to.equal(3)
			expect(prize.spins).to.equal(1)
			expect(prize.fish).to.equal(nil)
			expect(prize.crates).to.equal(nil)
			local odd = CollectorLogic.prize({ value = 1, fish = 0, lures = { tuna = -1 } }, "alley")
			expect(odd.fish).to.equal(nil)
			expect(odd.lures).to.equal(nil)
		end)

		it("shows no crate without the cat's area and nothing without an offer", function()
			local prize = CollectorLogic.prize({ value = 7, crates = { zone = 1 } }, nil)
			expect(prize.crates).to.equal(nil)
			expect(CollectorLogic.prize(nil, "alley")).to.equal(nil)
		end)
	end)

	describe("CollectorLogic.needsConfirm", function()
		it("asks twice from Rare up and for any gold cat, as Sell does", function()
			expect(CollectorLogic.needsConfirm("Common", nil)).to.equal(false)
			expect(CollectorLogic.needsConfirm("Common", "gold")).to.equal(true)
			expect(CollectorLogic.needsConfirm("Rare", nil)).to.equal(true)
			expect(CollectorLogic.needsConfirm("Mythical", nil)).to.equal(true)
			expect(CollectorLogic.needsConfirm(nil, nil)).to.equal(false)
		end)
	end)

	describe("CollectorLogic.near", function()
		local range = CollectorLogic.RANGE
		it("opens within his range and closes a stud past it", function()
			expect(range).to.equal(12)
			expect(CollectorLogic.near(range, false)).to.equal(true)
			expect(CollectorLogic.near(range + 0.5, false)).to.equal(false)
			expect(CollectorLogic.near(range + 0.5, true)).to.equal(true)
			expect(CollectorLogic.near(range + 1.5, true)).to.equal(false)
			expect(CollectorLogic.near(nil, true)).to.equal(false)
		end)
	end)

	describe("CollectorLogic.catLine and clock", function()
		it("reads the rarity with Gold in front of a gold cat", function()
			expect(CollectorLogic.catLine("Rare", nil)).to.equal("Rare")
			expect(CollectorLogic.catLine("Epic", "gold")).to.equal("Gold Epic")
			expect(CollectorLogic.catLine(nil, nil)).to.equal("Common")
		end)

		it("counts his time down to 0:00", function()
			expect(CollectorLogic.clock(180)).to.equal("3:00")
			expect(CollectorLogic.clock(161.2)).to.equal("2:42")
			expect(CollectorLogic.clock(-4)).to.equal("0:00")
		end)
	end)
end
