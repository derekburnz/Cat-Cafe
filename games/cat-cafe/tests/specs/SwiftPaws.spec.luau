--!strict
-- shared/SwiftPaws.luau (#3063, #3317, #4705): the Golden Fish Market's Swift Paws perk, ten levels (+1, +1, then
-- +0.5), levels 3 to 5 and 6 to 10 each behind their own switch, first in the Market's perks.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local LiveFlags = require(Shared.LiveFlags)
	local ProfileSchema = require(Shared.ProfileSchema)
	local SwiftPaws = require(Shared.SwiftPaws)

	describe("bonus", function()
		it(
			"adds +1 for levels 1 and 2 and +0.5 for 3 to 10, and nothing without the perk",
			function()
				local profile = ProfileSchema.template(100)
				expect(SwiftPaws.bonus(profile, true)).to.equal(0)
				local want = { 1, 2, 2.5, 3, 3.5, 4, 4.5, 5, 5.5, 6 }
				for level = 1, 10 do
					profile.fishPerks[SwiftPaws.ID] = level
					expect(SwiftPaws.bonus(profile, true)).to.be.near(want[level])
				end
				expect(SwiftPaws.speedAt(14)).to.be.near(6)
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
			"keeps the first five levels' carry slower than a plain walk, under the catch rush and the Swift Potion",
			function()
				-- #4705: levels 6 to 10 (Derek's ask) go past these on purpose; the first five keep them
				local most = SwiftPaws.speedAt(SwiftPaws.MID_TOP)
				expect(most < 4).to.equal(true) -- the Swift Potion's +4, sold for Robux, stays the bigger bump
				expect(Config.CarryWalkSpeed + most < Config.NormalWalkSpeed).to.equal(true)
				expect(Config.NormalWalkSpeed + most < Config.CatchRushWalkSpeed).to.equal(true)
			end
		)
	end)

	describe("catalog and switches", function()
		it(
			"is a ten-level perk from 60 to 1100 golden fish, each dearer, first of the perks (#4860)",
			function()
				local row = Catalog.getFishShopRow(SwiftPaws.ID)
				assert(row and row.costs)
				expect(row.kind).to.equal("perk")
				expect(row.maxLevel).to.equal(10)
				expect(row.costs :: any).to.deepEqual({
					60,
					150,
					300,
					500,
					800,
					850,
					900,
					950,
					1000,
					1100,
				})
				expect(#SwiftPaws.LEVELS).to.equal(10)
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
			"has its own live switch, on by default, and none for levels 3 to 5 (#4654 batch 7) or 6 to 10 (#4654)",
			function()
				expect(table.find(LiveFlags.KEYS, SwiftPaws.FLAG) ~= nil).to.equal(true)
				expect(LiveFlags.defaults()[SwiftPaws.FLAG]).to.equal(true)
				expect(table.find(LiveFlags.KEYS, "swiftPaws5")).to.equal(nil)
				expect(table.find(LiveFlags.KEYS, "swiftPaws10")).to.equal(nil)
			end
		)

		it("stops at level 2 until levels 3 to 5 are switched on", function()
			expect(SwiftPaws.topLevel(5, false)).to.equal(2)
			expect(SwiftPaws.topLevel(5, true)).to.equal(5)
			expect(SwiftPaws.topLevel(1, false)).to.equal(1)
			-- #4705: levels 6 to 10 wait on their own switch, and only after levels 3 to 5 are open
			expect(SwiftPaws.topLevel(10, true)).to.equal(5)
			expect(SwiftPaws.topLevel(10, true, false)).to.equal(5)
			expect(SwiftPaws.topLevel(10, true, true)).to.equal(10)
			expect(SwiftPaws.topLevel(10, false, true)).to.equal(2)
		end)

		it("caps a saved level at the row's max, and keeps levels 3 to 5", function()
			local raw = ProfileSchema.template(100) :: any
			raw.fishPerks = { [SwiftPaws.ID] = 14 }
			expect(ProfileSchema.migrate(raw, 100).fishPerks[SwiftPaws.ID]).to.equal(10)
			-- #4705: an old level 5 save is kept as it is, ready for level 6
			raw = ProfileSchema.template(100) :: any
			raw.fishPerks = { [SwiftPaws.ID] = 5 }
			expect(ProfileSchema.migrate(raw, 100).fishPerks[SwiftPaws.ID]).to.equal(5)
			raw = ProfileSchema.template(100) :: any
			raw.fishPerks = { [SwiftPaws.ID] = 4 }
			expect(ProfileSchema.migrate(raw, 100).fishPerks[SwiftPaws.ID]).to.equal(4)
		end)
	end)
end
