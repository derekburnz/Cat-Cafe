--!strict
-- shared/SwiftPaws.luau (#3063): the Golden Fish Market's Swift Paws perk, +1 walk speed a level for two levels.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local LiveFlags = require(Shared.LiveFlags)
	local ProfileSchema = require(Shared.ProfileSchema)
	local SwiftPaws = require(Shared.SwiftPaws)

	describe("bonus", function()
		it("adds PER_LEVEL a level, and nothing without the perk", function()
			local profile = ProfileSchema.template(100)
			expect(SwiftPaws.bonus(profile, true)).to.equal(0)
			profile.fishPerks[SwiftPaws.ID] = 1
			expect(SwiftPaws.bonus(profile, true)).to.equal(1)
			profile.fishPerks[SwiftPaws.ID] = 2
			expect(SwiftPaws.bonus(profile, true)).to.equal(2)
		end)

		it("is 0 while the switch is off or with no save, and keeps the level", function()
			local profile = ProfileSchema.template(100)
			profile.fishPerks[SwiftPaws.ID] = 2
			expect(SwiftPaws.bonus(profile, false)).to.equal(0)
			expect(profile.fishPerks[SwiftPaws.ID]).to.equal(2)
			expect(SwiftPaws.bonus(nil, true)).to.equal(0)
		end)

		it("keeps a full carry slower than a plain walk, and both under the catch rush", function()
			local row = Catalog.getFishShopRow(SwiftPaws.ID)
			assert(row and row.costs and row.maxLevel)
			local most = row.maxLevel * SwiftPaws.PER_LEVEL
			expect(Config.CarryWalkSpeed + most < Config.NormalWalkSpeed).to.equal(true)
			expect(Config.NormalWalkSpeed + most < Config.CatchRushWalkSpeed).to.equal(true)
		end)
	end)

	describe("catalog and switch", function()
		it("is a two-level perk at 60 and 150 golden fish", function()
			local row = Catalog.getFishShopRow(SwiftPaws.ID)
			assert(row and row.costs)
			expect(row.kind).to.equal("perk")
			expect(row.maxLevel).to.equal(2)
			expect(row.costs[1]).to.equal(60)
			expect(row.costs[2]).to.equal(150)
		end)

		it("has its own live switch, on by default", function()
			expect(table.find(LiveFlags.KEYS, SwiftPaws.FLAG) ~= nil).to.equal(true)
			expect(LiveFlags.defaults()[SwiftPaws.FLAG]).to.equal(true)
		end)

		it("caps a saved level at the row's max", function()
			local raw = ProfileSchema.template(100) :: any
			raw.fishPerks = { [SwiftPaws.ID] = 9 }
			local profile = ProfileSchema.migrate(raw, 100)
			expect(profile.fishPerks[SwiftPaws.ID]).to.equal(2)
		end)
	end)
end
