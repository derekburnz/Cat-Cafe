--!strict
-- Onboarding.luau against growth analytics-plan section 3: twelve steps, each logged once and only in order. A step
-- reached early is held until every step before it is logged, so a rank up before bait never fakes the bait steps.
-- The "edges (QA)" block is QA's: 500 seeded play orders with every step reached twice, names that are not steps, a
-- finished funnel and the shipped names.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Onboarding = require(Shared.Onboarding)
	local Types = require(Shared.Types)

	local function fresh(): Types.TelemetryState
		return { onboardingStep = 0, achieved = {} }
	end

	describe("steps", function()
		it("are the plan's twelve, numbered by position", function()
			expect(Onboarding.COUNT).to.equal(12)
			expect(Onboarding.STEPS[1]).to.equal("joined")
			expect(Onboarding.STEPS[7]).to.equal("first_bait")
			expect(Onboarding.STEPS[12]).to.equal("tier_3")
			expect(Onboarding.index("first_bait_resolved")).to.equal(8)
		end)
	end)

	describe("reach", function()
		it("logs the next step and advances", function()
			local state = fresh()
			expect(Onboarding.reach(state, "joined") :: any).to.deepEqual({ "joined" })
			expect(state.onboardingStep).to.equal(1)
		end)

		it("logs a step only once", function()
			local state = fresh()
			Onboarding.reach(state, "joined")
			expect(#Onboarding.reach(state, "joined")).to.equal(0)
			expect(state.onboardingStep).to.equal(1)
		end)

		it("holds a later step and logs nothing for it yet", function()
			local state = fresh()
			Onboarding.reach(state, "joined")
			expect(#Onboarding.reach(state, "tier_2")).to.equal(0)
			expect(state.onboardingStep).to.equal(1)
			expect(state.achieved["9"]).to.equal(true)
		end)

		it("logs held steps in order once the gap closes", function()
			local state = fresh()
			for _, step in
				{ "joined", "saw_alley", "first_catch", "first_checkin" } :: { Onboarding.StepName }
			do
				Onboarding.reach(state, step)
			end
			Onboarding.reach(state, "first_table") -- 6, held
			Onboarding.reach(state, "first_bait") -- 7, held
			Onboarding.reach(state, "tier_2") -- 9, held behind 8
			expect(Onboarding.reach(state, "first_role") :: any).to.deepEqual({
				"first_role",
				"first_table",
				"first_bait",
			})
			expect(state.onboardingStep).to.equal(7)
			expect(state.achieved :: any).to.deepEqual({ ["9"] = true })
			expect(Onboarding.reach(state, "first_bait_resolved") :: any).to.deepEqual({
				"first_bait_resolved",
				"tier_2",
			})
			expect(next(state.achieved)).never.to.be.ok()
		end)

		it("never logs a step out of order whatever the play order", function()
			local state = fresh()
			local logged: { number } = {}
			local order: { Onboarding.StepName } = {
				"tier_3",
				"first_offline_claim",
				"joined",
				"tier_2",
				"first_catch",
				"saw_alley",
				"returned_next_day",
				"first_bait",
				"first_checkin",
				"first_bait_resolved",
				"first_table",
				"first_role",
			}
			for _, step in order do
				for _, name in Onboarding.reach(state, step) do
					table.insert(logged, Onboarding.index(name))
				end
			end
			expect(#logged).to.equal(12)
			for i, step in logged do
				expect(step).to.equal(i)
			end
		end)
	end)

	describe("edges (QA)", function()
		it("logs 1 to 12 once each and holds nothing, over 500 seeded orders", function()
			local rng = Random.new(16)
			for _ = 1, 500 do
				local order = table.clone(Onboarding.STEPS)
				for i = #order, 2, -1 do
					local j = rng:NextInteger(1, i)
					order[i], order[j] = order[j], order[i]
				end
				local state = fresh()
				local logged: { number } = {}
				for _, step in order do
					-- every step twice in a row, as a second check-in or rank up would
					for _ = 1, 2 do
						for _, name in Onboarding.reach(state, step) do
							table.insert(logged, Onboarding.index(name))
						end
					end
				end
				expect(#logged).to.equal(Onboarding.COUNT)
				for i, step in logged do
					expect(step).to.equal(i)
				end
				expect(state.onboardingStep).to.equal(Onboarding.COUNT)
				expect(next(state.achieved)).never.to.be.ok()
			end
		end)

		it("ignores a name that is not a step", function()
			local state = fresh()
			Onboarding.reach(state, "joined")
			expect(#Onboarding.reach(state, "first_lure" :: any)).to.equal(0)
			expect(state.onboardingStep).to.equal(1)
			expect(next(state.achieved)).never.to.be.ok()
			expect(Onboarding.index("first_lure")).to.equal(0)
		end)

		it("logs nothing more once the last step is logged", function()
			local state: Types.TelemetryState = { onboardingStep = Onboarding.COUNT, achieved = {} }
			for _, step in Onboarding.STEPS do
				expect(#Onboarding.reach(state, step)).to.equal(0)
			end
			expect(next(state.achieved)).never.to.be.ok()
		end)

		it("keeps the shipped step names in the plan's order (analytics-plan 3.1)", function()
			expect(Onboarding.STEPS :: any).to.deepEqual({
				"joined",
				"saw_alley",
				"first_catch",
				"first_checkin",
				"first_role",
				"first_table",
				"first_bait",
				"first_bait_resolved",
				"tier_2",
				"returned_next_day",
				"first_offline_claim",
				"tier_3",
			})
		end)
	end)
end
