--!strict
-- shared/StuckGoal (#2912): from the first bait cat resolved until the first rescue starts.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Onboarding = require(Shared.Onboarding)
	local ProfileSchema = require(Shared.ProfileSchema)
	local StuckGoal = require(Shared.StuckGoal)

	local NOW = 1_800_000_000

	local function save(steps: { string }): any
		local profile: any = ProfileSchema.template(NOW - 3600)
		for _, step in steps do
			Onboarding.reach(profile.telemetry, step :: any)
		end
		return profile
	end

	describe("StuckGoal.waiting", function()
		it("is false on a new save and before the first bait cat is resolved", function()
			expect(StuckGoal.waiting(save({}))).to.equal(false)
			expect(StuckGoal.waiting(save({ "first_bait" }))).to.equal(false)
		end)

		it("is true once the first bait cat is tamed or let go", function()
			expect(StuckGoal.waiting(save({ "first_bait", "first_bait_resolved" }))).to.equal(true)
		end)

		it("ends when the first rescue starts, with a rescue done, and at Tier 2", function()
			expect(
				StuckGoal.waiting(
					save({ "first_bait", "first_bait_resolved", "first_rescue_started" })
				)
			).to.equal(false)
			local rescued = save({ "first_bait", "first_bait_resolved" })
			rescued.stats.rescues = 1
			expect(StuckGoal.waiting(rescued)).to.equal(false)
			expect(StuckGoal.waiting(save({ "first_bait", "first_bait_resolved", "tier_2" }))).to.equal(
				false
			)
		end)
	end)

	describe("StuckGoal.active", function()
		it("needs the server's word", function()
			expect(StuckGoal.active(nil, nil, false)).to.equal(false)
			expect(StuckGoal.active(false, nil, false)).to.equal(false)
			expect(StuckGoal.active(true, nil, false)).to.equal(true)
		end)

		it(
			"stops on a rescue bar or a carried cat, and TRAIL_SECONDS after it first showed",
			function()
				expect(StuckGoal.active(true, 5, true)).to.equal(false)
				expect(StuckGoal.active(true, StuckGoal.TRAIL_SECONDS - 1, false)).to.equal(true)
				expect(StuckGoal.active(true, StuckGoal.TRAIL_SECONDS, false)).to.equal(false)
			end
		)
	end)

	describe("StuckGoal.where", function()
		it(
			"points nowhere at night, at the cannon from town or another area, at the cat in the Alleyway",
			function()
				expect(StuckGoal.where(nil, false)).to.equal("none")
				expect(StuckGoal.where("alley", false)).to.equal("none")
				expect(StuckGoal.where(nil, true)).to.equal("cannon")
				expect(StuckGoal.where("park", true)).to.equal("cannon")
				expect(StuckGoal.where("alley", true)).to.equal("cat")
			end
		)
	end)

	describe("StuckGoal.followed", function()
		it("is a flat distance of FOLLOWED_STUDS", function()
			local cat = Vector3.new(10, 0, 10)
			expect(StuckGoal.followed(Vector3.new(10 + StuckGoal.FOLLOWED_STUDS, 40, 10), cat)).to.equal(
				true
			)
			expect(StuckGoal.followed(Vector3.new(11 + StuckGoal.FOLLOWED_STUDS, 0, 10), cat)).to.equal(
				false
			)
		end)
	end)

	describe("StuckGoal.aside", function()
		it("stands aside within ASIDE_STUDS of the cat and not beyond", function()
			expect(StuckGoal.aside(StuckGoal.ASIDE_STUDS, false)).to.equal(true)
			expect(StuckGoal.aside(StuckGoal.ASIDE_STUDS + 1, false)).to.equal(false)
		end)

		it("comes back only past ASIDE_BACK_STUDS, so it does not flicker at the edge", function()
			expect(StuckGoal.ASIDE_BACK_STUDS > StuckGoal.ASIDE_STUDS).to.equal(true)
			expect(StuckGoal.aside(StuckGoal.ASIDE_STUDS + 1, true)).to.equal(true)
			expect(StuckGoal.aside(StuckGoal.ASIDE_BACK_STUDS + 1, true)).to.equal(false)
		end)

		it("never stands aside without a cat or a player", function()
			expect(StuckGoal.aside(nil, true)).to.equal(false)
			expect(StuckGoal.aside(nil, false)).to.equal(false)
		end)
	end)

	describe("StuckGoal words", function()
		it("has no hurry wording and two step names", function()
			expect(#StuckGoal.STEPS).to.equal(2)
			for _, line in { StuckGoal.TITLE, StuckGoal.LINE, StuckGoal.TOWN_LINE, StuckGoal.NIGHT } do
				expect(string.find(string.lower(line), "hurry")).never.to.be.ok()
			end
		end)
	end)
end
