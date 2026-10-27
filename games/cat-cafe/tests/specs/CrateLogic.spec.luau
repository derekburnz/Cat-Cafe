--!strict
-- UI/Components/CrateLogic.luau: crates by id, golden ones, and the "highest" crate of a wheel slice or an All Cats
-- prize (golden-fish.md sections 5b and 6, F54).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local CrateLogic = require(Components:WaitForChild("CrateLogic")) :: any

	local CRATES = {
		alley_crate = {
			id = "alley_crate",
			name = "Alley Crate",
			area = "alley",
			golden = false,
			price = 60,
		},
		alley_golden_crate = {
			id = "alley_golden_crate",
			name = "Golden Alley Crate",
			area = "alley",
			golden = true,
		},
		park_crate = {
			id = "park_crate",
			name = "Park Crate",
			area = "park",
			golden = false,
			price = 60,
		},
		woods_golden_crate = { id = "woods_golden_crate", area = "woods", golden = true },
		classic_crate = {
			id = "classic_crate",
			name = "Classic Crate",
			area = "classic",
			golden = false,
		},
	}
	local AREAS = {
		{ id = "alley", tier = 1 },
		{ id = "park", tier = 2 },
		{ id = "neighbourhood", tier = 3 },
		{ id = "woods", tier = 4 },
	}

	describe("CrateLogic.byId", function()
		it("reads a map or a list and skips bad rows", function()
			local fromList = CrateLogic.byId({ { id = "park_crate" }, "junk", { name = "no id" } })
			expect(fromList.park_crate).to.be.ok()
			local count = 0
			for _ in fromList do
				count += 1
			end
			expect(count).to.equal(1)
			expect(CrateLogic.byId({ woods_crate = { name = "Woods Crate" } }).woods_crate.name).to.equal(
				"Woods Crate"
			)
			expect(next(CrateLogic.byId(nil))).to.equal(nil)
		end)
	end)

	describe("CrateLogic.isGolden", function()
		it("trusts the catalog's flag, else the id", function()
			expect(CrateLogic.isGolden("alley_golden_crate", CRATES.alley_golden_crate)).to.equal(
				true
			)
			expect(CrateLogic.isGolden("alley_crate", CRATES.alley_crate)).to.equal(false)
			expect(CrateLogic.isGolden("sewer_golden_crate", nil)).to.equal(true)
			expect(CrateLogic.isGolden("sewer_crate", nil)).to.equal(false)
		end)
	end)

	describe("CrateLogic.resolve", function()
		it("keeps a named crate", function()
			expect(CrateLogic.resolve("classic_crate", CRATES, AREAS, 4)).to.equal("classic_crate")
		end)

		it("picks the plain crate of the highest area the tier opens", function()
			expect(CrateLogic.resolve("highest", CRATES, AREAS, 1)).to.equal("alley_crate")
			expect(CrateLogic.resolve("highest", CRATES, AREAS, 2)).to.equal("park_crate")
		end)

		it("skips areas without a plain crate and never takes a golden one", function()
			-- Tier 4 opens the Woods, which has only a golden crate here, and the Neighbourhood has none
			expect(CrateLogic.resolve("highest", CRATES, AREAS, 4)).to.equal("park_crate")
		end)

		it("stays highest when nothing matches", function()
			expect(CrateLogic.resolve("highest", {}, AREAS, 3)).to.equal("highest")
			expect(CrateLogic.resolve("highest", CRATES, nil, 3)).to.equal("highest")
		end)
	end)

	describe("CrateLogic.name", function()
		it("uses the catalog name, else a readable id", function()
			expect(CrateLogic.name("park_crate", CRATES.park_crate)).to.equal("Park Crate")
			expect(CrateLogic.name("woods_golden_crate", CRATES.woods_golden_crate)).to.equal(
				"Woods Golden Crate"
			)
			expect(CrateLogic.name("highest", nil)).to.equal("Crate")
		end)
	end)
end
