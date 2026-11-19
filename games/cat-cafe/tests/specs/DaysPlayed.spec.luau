--!strict
-- shared/DaysPlayed.luau (#5505 part 1): UTC days played and their milestones.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local DaysPlayed = require(Shared.DaysPlayed)
	local LiveFlags = require(Shared.LiveFlags)
	local ProfileSchema = require(Shared.ProfileSchema)

	describe("DaysPlayed", function()
		it("counts each new UTC day once and never resets", function()
			local state, counted = DaysPlayed.note(nil, 100)
			expect(state.count).to.equal(1)
			expect(counted).to.equal(true)
			state, counted = DaysPlayed.note(state, 100)
			expect(state.count).to.equal(1)
			expect(counted).to.equal(false)
			state = DaysPlayed.note(state, 105) -- days away cost nothing
			expect(state.count).to.equal(2)
			state = DaysPlayed.note(state, 104) -- a clock behind the last day counts nothing
			expect(state.count).to.equal(2)
			expect(DaysPlayed.day(105 * 86400 - 1)).to.equal(104)
			expect(DaysPlayed.day(105 * 86400)).to.equal(105)
		end)

		it("pays the milestones in order, each once", function()
			local state: DaysPlayed.State = { count = 1, last = 0, paid = 0 }
			expect(DaysPlayed.due(state)).to.equal(nil)
			expect((DaysPlayed.next(state) :: any).days).to.equal(2)
			state.count = 4
			expect((DaysPlayed.due(state) :: any).days).to.equal(2)
			state.paid = 2
			expect((DaysPlayed.due(state) :: any).days).to.equal(3)
			state.paid = 3
			expect(DaysPlayed.due(state)).to.equal(nil)
			expect((DaysPlayed.next(state) :: any).days).to.equal(5)
			state.count, state.paid = 40, 30
			expect(DaysPlayed.due(state)).to.equal(nil)
			expect(DaysPlayed.next(state)).to.equal(nil)
		end)

		it("picks a kind not owned from the newest area, by rule", function()
			for tier = 1, 10 do
				for _, rarity in { "Rare", "Epic", "Legendary" } do
					local first = DaysPlayed.pickCat(rarity, tier, {})
					expect(first ~= nil).to.equal(true)
					local def = Catalog.getCat(first :: string) :: any
					expect(def.rarity).to.equal(rarity)
					expect(def.exclusive == true).to.equal(false)
					expect(DaysPlayed.pickCat(rarity, tier, {})).to.equal(first) -- never rolled
					local owned = { [first :: string] = 1 }
					local second = DaysPlayed.pickCat(rarity, tier, owned)
					expect(second ~= nil).to.equal(true)
				end
			end
			local park = DaysPlayed.pickCat("Rare", 2, {}) :: string
			expect((Catalog.getCat(park) :: any).area).to.equal(DaysPlayed.newestArea(2))
		end)

		it("keeps a valid field in the save and drops anything else", function()
			local profile: any = ProfileSchema.template(1700000000)
			profile.daysPlayed = { count = 3, last = 100, paid = 2 }
			local kept = ProfileSchema.migrate(profile, 1700000000).daysPlayed :: any
			expect(kept.count).to.equal(3)
			expect(kept.paid).to.equal(2)
			expect(DaysPlayed.sanitize({ count = "x", last = 1 })).to.equal(nil)
		end)

		it("is off by default", function()
			expect(LiveFlags.OFF_BY_DEFAULT[DaysPlayed.FLAG]).to.equal(true)
		end)
	end)
end
