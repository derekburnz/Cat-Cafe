--!strict
-- UI/Components/DealerRows.luau: the night dealer's three slots as shop rows (data-model section 8b).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local DealerRows = require(Components:WaitForChild("DealerRows")) :: any
	local Catalog = require(
		game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Catalog")
	) :: any

	local lureById = Catalog.luresById

	describe("DealerRows.group", function()
		it("shows a food in two slots once, with both slots open", function()
			local rows = DealerRows.group({
				slots = {
					{ lureId = "sardines", cost = 800, bought = false },
					{ lureId = "caviar", cost = 3000, bought = false },
					{ lureId = "sardines", cost = 800, bought = false },
				},
				restocksAt = 0,
			}, lureById)
			expect(#rows).to.equal(2)
			expect(rows[1].lureId).to.equal("sardines")
			expect(rows[1].open).to.deepEqual({ 1, 3 })
			expect(rows[1].total).to.equal(2)
			expect(rows[2].lureId).to.equal("caviar")
			expect(rows[2].open).to.deepEqual({ 2 })
		end)

		it("leaves bought slots out of open so Buy sends the next one", function()
			local rows = DealerRows.group({
				slots = {
					{ lureId = "moon_milk", cost = 10000, bought = true },
					{ lureId = "moon_milk", cost = 10000, bought = false },
					{ lureId = "star_treat", cost = 40000, bought = true },
				},
				restocksAt = 0,
			}, lureById)
			expect(rows[1].open).to.deepEqual({ 2 })
			expect(rows[2].open).to.deepEqual({})
			expect(rows[2].total).to.equal(1)
		end)

		it("uses the server's price and skips foods the catalog does not know", function()
			local rows = DealerRows.group({
				slots = {
					{ lureId = "mystery", cost = 1, bought = false },
					{ lureId = "caviar", cost = 2500, bought = false },
				},
				restocksAt = 0,
			}, lureById)
			expect(#rows).to.equal(1)
			expect(rows[1].cost).to.equal(2500)
			expect(rows[1].open).to.deepEqual({ 2 })
		end)
	end)

	describe("DealerRows.clock", function()
		it("counts minutes and seconds and stops at zero", function()
			expect(DealerRows.clock(252)).to.equal("4:12")
			expect(DealerRows.clock(59.2)).to.equal("1:00")
			expect(DealerRows.clock(5)).to.equal("0:05")
			expect(DealerRows.clock(-3)).to.equal("0:00")
		end)
	end)
end
