--!strict
-- shared/SwiftPaws.luau (#3063, #3317): the Golden Fish Market's Swift Paws perk, five levels (+1, +1, then +0.5),
-- levels 3 to 5 behind their own switch, first in the Market's perks.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local LiveFlags = require(Shared.LiveFlags)
	local ProfileSchema = require(Shared.ProfileSchema)
	local SwiftPaws = require(Shared.SwiftPaws)

	describe("bonus", function()
		it(
			"adds +1 for levels 1 and 2 and +0.5 for 3 to 5, and nothing without the perk",
			function()
				local profile = ProfileSchema.template(100)
				expect(SwiftPaws.bonus(profile, true)).to.equal(0)
				local want = { 1, 2, 2.5, 3, 3.5 }
				for level = 1, 5 do
					profile.fishPerks[SwiftPaws.ID] = level
					expect(SwiftPaws.bonus(profile, true)).to.be.near(want[level])
				end
				expect(SwiftPaws.speedAt(9)).to.be.near(3.5)
				expect(SwiftPaws.speedAt(-1)).to.equal(0)
			end
		)

		it("is 0 while the switch is off or with no save, and keeps the level", function()
			local profile = ProfileSchema.template(100)
			profile.fishPerks[SwiftPaws.ID] = 2
			expect(SwiftPaws.bonus(profile, false)).to.equal(0)
			expect(profile.fishPerks[SwiftPaws.ID]).to.equal(2)
			expect(SwiftPaws.bonus(nil, true)).to.equal(0)
		end)

		it(
			"keeps a full carry slower than a plain walk, both under the catch rush, and under the Swift Potion",
			function()
				local row = Catalog.getFishShopRow(SwiftPaws.ID)
				assert(row and row.costs and row.maxLevel)
				local most = SwiftPaws.speedAt(row.maxLevel)
				expect(most < 4).to.equal(true) -- the Swift Potion's +4, sold for Robux, stays the bigger bump
				expect(Config.CarryWalkSpeed + most < Config.NormalWalkSpeed).to.equal(true)
				expect(Config.NormalWalkSpeed + most < Config.CatchRushWalkSpeed).to.equal(true)
			end
		)
	end)

	describe("catalog and switches", function()
		it(
			"is a five-level perk at 60, 150, 300, 500 and 800 golden fish, first of the perks",
			function()
				local row = Catalog.getFishShopRow(SwiftPaws.ID)
				assert(row and row.costs)
				expect(row.kind).to.equal("perk")
				expect(row.maxLevel).to.equal(5)
				expect(row.costs :: any).to.deepEqual({ 60, 150, 300, 500, 800 })
				local firstPerk: string? = nil
				for _, shopRow in Catalog.fishShop do
					if shopRow.kind ~= "crate" then
						firstPerk = shopRow.id
						break
					end
				end
				expect(firstPerk).to.equal(SwiftPaws.ID)
			end
		)

		it(
			"has its own live switch, on by default, and one for levels 3 to 5, off by default",
			function()
				expect(table.find(LiveFlags.KEYS, SwiftPaws.FLAG) ~= nil).to.equal(true)
				expect(LiveFlags.defaults()[SwiftPaws.FLAG]).to.equal(true)
				expect(table.find(LiveFlags.KEYS, SwiftPaws.FLAG_FIVE) ~= nil).to.equal(true)
				expect(LiveFlags.defaults()[SwiftPaws.FLAG_FIVE]).to.equal(false)
			end
		)

		it("stops at level 2 until levels 3 to 5 are switched on", function()
			expect(SwiftPaws.topLevel(5, false)).to.equal(2)
			expect(SwiftPaws.topLevel(5, true)).to.equal(5)
			expect(SwiftPaws.topLevel(1, false)).to.equal(1)
		end)

		it("caps a saved level at the row's max, and keeps levels 3 to 5", function()
			local raw = ProfileSchema.template(100) :: any
			raw.fishPerks = { [SwiftPaws.ID] = 9 }
			expect(ProfileSchema.migrate(raw, 100).fishPerks[SwiftPaws.ID]).to.equal(5)
			raw = ProfileSchema.template(100) :: any
			raw.fishPerks = { [SwiftPaws.ID] = 4 }
			expect(ProfileSchema.migrate(raw, 100).fishPerks[SwiftPaws.ID]).to.equal(4)
		end)
	end)
end
