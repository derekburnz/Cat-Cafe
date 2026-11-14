--!strict
-- shared/ReturnGoals (#2916): the next goals for the session recap and the welcome back card, with their progress.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local ProfileSchema = require(Shared.ProfileSchema)
	local ReturnGoals = require(Shared.ReturnGoals)

	local NOW = 1_800_000_000

	local function withCats(count: number): any
		local profile: any = ProfileSchema.template(NOW - 3600)
		local added = 0
		for _, def in Catalog.cats do
			if added >= count then
				break
			end
			if def.area == "alley" and def.exclusive ~= true then
				profile.collection[def.id] = { count = 1 }
				added += 1
			end
		end
		return profile
	end

	local function kinds(goals: { any }): { string }
		local out = {}
		for _, goal in goals do
			table.insert(out, goal.kind)
		end
		return out
	end

	describe("ReturnGoals.pick", function()
		it("names Tier 2's cats with progress, then its cost", function()
			local profile = withCats(2) -- #4188: Tier 2 needs 3
			profile.coins = 1000
			local goals = ReturnGoals.pick(profile, NOW)
			local tier2 = Catalog.getTier(2) :: any
			expect(goals[1].kind).to.equal("cats")
			expect(goals[1].have).to.equal(2)
			expect(goals[1].need).to.equal(tier2.distinctCats)
			expect(goals[1].tier).to.equal(2)
			expect(goals[1].area).to.equal(tier2.area)
			expect(goals[2].kind).to.equal("coins")
			expect(goals[2].have).to.equal(1000)
			expect(goals[2].need).to.equal(tier2.cost)
			expect(#goals <= ReturnGoals.MAX).to.equal(true)
		end)

		it("leaves out a met need", function()
			local tier2 = Catalog.getTier(2) :: any
			local profile = withCats(tier2.distinctCats)
			profile.coins = tier2.cost
			local found = kinds(ReturnGoals.pick(profile, NOW))
			expect(table.find(found, "cats")).to.equal(nil)
			expect(table.find(found, "coins")).to.equal(nil)
		end)

		it("adds what the cafe earns while away once it earns, after the Tier goals", function()
			local profile = withCats(2)
			local goals = ReturnGoals.pick(profile, NOW)
			local last: any = goals[#goals]
			if last.kind == "away" then
				expect(last.amount > 0).to.equal(true)
				expect(last.hours > 0).to.equal(true)
			end
			for _, goal in goals do
				expect(table.find(ReturnGoals.KINDS, goal.kind)).never.to.equal(nil)
			end
		end)

		it("gives a player at the last Tier no Tier goals", function()
			local profile = withCats(1)
			profile.tier = Catalog.maxTier
			for _, goal in ReturnGoals.pick(profile, NOW) do
				expect(goal.kind).to.equal("away")
			end
		end)
	end)

	describe("ReturnGoals.done", function()
		it("is met by its own need or by reaching its Tier", function()
			local profile = withCats(3)
			local goal: any = { kind = "cats", have = 3, need = 4, tier = 2 }
			expect(ReturnGoals.done(goal, profile)).to.equal(false)
			local more = withCats(4)
			expect(ReturnGoals.done(goal, more)).to.equal(true)
			profile.tier = 2
			expect(ReturnGoals.done(goal, profile)).to.equal(true)
			expect(
				ReturnGoals.done(
					{ kind = "coins", need = 500, tier = 3 } :: any,
					{ coins = 600, tier = 1 } :: any
				)
			).to.equal(true)
			expect(ReturnGoals.done({ kind = "away", amount = 10, hours = 8 } :: any, profile)).to.equal(
				false
			)
		end)
	end)
end
