--!strict
-- Onboarding.luau against growth analytics-plan section 3 and easy-start.md section 5 (F87): the funnel v2's 24 steps,
-- each logged once and only in order. A step reached early is held until every step before it is logged, so a rank
-- up before bait never fakes the bait steps. A version 1 state (12 steps) moves to the same steps in v2.
-- The "edges (QA)" block is QA's: 500 seeded play orders with every step reached twice, names that are not steps, a
-- finished funnel and the shipped names.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Onboarding = require(Shared.Onboarding)
	local Types = require(Shared.Types)

	local function fresh(): Types.TelemetryState
		return { onboardingStep = 0, achieved = {}, funnel = 2, firstDay = 0 }
	end

	describe("steps", function()
		it("are the 24 of funnel v2, numbered by position, logged as onboarding_v2", function()
			expect(Onboarding.COUNT).to.equal(24)
			expect(Onboarding.VERSION).to.equal(2)
			expect(Onboarding.FUNNEL).to.equal("onboarding_v2")
			expect(Onboarding.STEPS[1]).to.equal("joined")
			expect(Onboarding.STEPS[2]).to.equal("first_move")
			expect(Onboarding.STEPS[13]).to.equal("first_bait")
			expect(Onboarding.STEPS[24]).to.equal("tier_3")
			expect(Onboarding.index("first_bait_resolved")).to.equal(16)
		end)

		it("keep every v1 step, in the same order", function()
			local last = 0
			for _, name in Onboarding.V1_STEPS do
				local step = Onboarding.index(name)
				expect(step > last).to.equal(true)
				last = step
			end
			expect(#Onboarding.V1_STEPS).to.equal(12)
		end)
	end)

	describe("fromV1 (save version 19)", function()
		it("moves each v1 step to the same step in v2", function()
			local want = { 1, 3, 7, 8, 9, 11, 13, 16, 20, 22, 23, 24 }
			for old, new in want do
				local step = Onboarding.fromV1(old, {})
				expect(step).to.equal(new)
			end
			expect((Onboarding.fromV1(0, {}))).to.equal(0)
		end)

		it("moves held steps too and drops keys that are not v1 steps", function()
			local _, held = Onboarding.fromV1(4, { ["6"] = true, ["9"] = true, ["13"] = true, x = true, ["7"] = false })
			expect(held :: any).to.deepEqual({ ["11"] = true, ["20"] = true })
		end)
	end)

	describe("reached", function()
		it("is true for a logged or held step and false for the rest", function()
			local state = fresh()
			Onboarding.reach(state, "joined")
			Onboarding.reach(state, "tier_2")
			expect(Onboarding.reached(state, "joined")).to.equal(true)
			expect(Onboarding.reached(state, "tier_2")).to.equal(true)
			expect(Onboarding.reached(state, "first_move")).to.equal(false)
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
			expect(state.achieved["20"]).to.equal(true)
		end)

		it("logs held steps in order once the gap closes", function()
			local state = fresh()
			for i = 1, 8 do
				Onboarding.reach(state, Onboarding.STEPS[i])
			end
			Onboarding.reach(state, "second_cat") -- 10, held
			Onboarding.reach(state, "first_table") -- 11, held
			Onboarding.reach(state, "tier_2") -- 20, held behind 12
			expect(Onboarding.reach(state, "first_role") :: any).to.deepEqual({
				"first_role",
				"second_cat",
				"first_table",
			})
			expect(state.onboardingStep).to.equal(11)
			expect(state.achieved :: any).to.deepEqual({ ["20"] = true })
			for i = 12, 18 do
				Onboarding.reach(state, Onboarding.STEPS[i])
			end
			expect(Onboarding.reach(state, "rank_up_ready") :: any).to.deepEqual({
				"rank_up_ready",
				"tier_2",
			})
			expect(next(state.achieved)).never.to.be.ok()
		end)

		it("never logs a step out of order whatever the play order", function()
			local state = fresh()
			local logged: { number } = {}
			local order = table.clone(Onboarding.STEPS)
			-- the steps backwards, then forwards: every one but joined waits for the one before it
			for i = 1, math.floor(#order / 2) do
				order[i], order[#order - i + 1] = order[#order - i + 1], order[i]
			end
			for _, step in order do
				for _, name in Onboarding.reach(state, step) do
					table.insert(logged, Onboarding.index(name))
				end
			end
			expect(#logged).to.equal(24)
			for i, step in logged do
				expect(step).to.equal(i)
			end
		end)
	end)

	describe("fromSave (QA S72)", function()
		local function facts(over: { [string]: number }?): Onboarding.SaveFacts
			local out =
				{ catsCaught = 0, distinctCats = 0, tables = 0, bowl = 0, tier = 1, parkCats = 0 }
			for key, value in over or {} do
				(out :: any)[key] = value
			end
			return out
		end

		it("shows nothing for a fresh save", function()
			expect(#Onboarding.fromSave(facts())).to.equal(0)
		end)

		it("lists what a save shows in step order", function()
			expect(
				Onboarding.fromSave(
					facts({
						catsCaught = 9,
						distinctCats = 6,
						tables = 2,
						bowl = 1,
						tier = 3,
						parkCats = 1,
					})
				) :: any
			).to.deepEqual({
				"second_cat",
				"first_table",
				"bowl_bought",
				"five_cats",
				"rank_up_card_seen",
				"rank_up_ready",
				"tier_2",
				"first_park_catch",
				"tier_3",
			})
		end)

		it("unsticks an alpha save past tier_2 that owns a Park cat but catches only beyond it", function()
			-- v1 step 9 is tier_2 (v2 step 20) and the held v1 step 12 is tier_3 (v2 step 24)
			local step, achieved = Onboarding.fromV1(9, { ["12"] = true })
			local state = { onboardingStep = step, achieved = achieved, funnel = 2, firstDay = 0 }
			local logged: { string } = {}
			local save = facts({ catsCaught = 30, distinctCats = 12, tables = 4, bowl = 2, tier = 3, parkCats = 3 })
			for _, name in Onboarding.fromSave(save) do
				for _, done in Onboarding.reach(state, name) do
					table.insert(logged, done)
				end
			end
			-- first_park_catch logs; returned_next_day and first_offline_claim repeat in play, so tier_3 stays held
			expect(logged :: any).to.deepEqual({ "first_park_catch" })
			expect(state.achieved["24"]).to.equal(true)
		end)

		it("unsticks an alpha save moved to first_table that already owns the bowl", function()
			local step, achieved = Onboarding.fromV1(6, { ["7"] = true })
			local state = { onboardingStep = step, achieved = achieved, funnel = 2, firstDay = 0 }
			expect(Onboarding.STEPS[state.onboardingStep]).to.equal("first_table")
			local logged: { string } = {}
			for _, name in Onboarding.fromSave(facts({ catsCaught = 4, tables = 1, bowl = 1 })) do
				for _, done in Onboarding.reach(state, name) do
					table.insert(logged, done)
				end
			end
			-- bowl_bought fills the gap, so the held first_bait follows it
			expect(logged :: any).to.deepEqual({ "bowl_bought", "first_bait" })
			expect(Onboarding.STEPS[state.onboardingStep]).to.equal("first_bait")
		end)

		it("logs nothing twice on the next join", function()
			local state = { onboardingStep = 12, achieved = {}, funnel = 2, firstDay = 0 }
			for _, name in Onboarding.fromSave(facts({ catsCaught = 2, tables = 1, bowl = 1 })) do
				expect(#Onboarding.reach(state, name)).to.equal(0)
			end
		end)
	end)

	describe("edges (QA)", function()
		it("logs 1 to 24 once each and holds nothing, over 500 seeded orders", function()
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
			local state: Types.TelemetryState =
				{ onboardingStep = Onboarding.COUNT, achieved = {}, funnel = 2, firstDay = 0 }
			for _, step in Onboarding.STEPS do
				expect(#Onboarding.reach(state, step)).to.equal(0)
			end
			expect(next(state.achieved)).never.to.be.ok()
		end)

		it("keeps the shipped step names in the plan's order (analytics-plan 3.1, easy-start.md section 5)", function()
			expect(Onboarding.STEPS :: any).to.deepEqual({
				"joined",
				"first_move",
				"saw_alley",
				"near_stray",
				"catch_started",
				"first_circle_hit",
				"first_catch",
				"first_checkin",
				"first_role",
				"second_cat",
				"first_table",
				"bowl_bought",
				"first_bait",
				"first_rescue_started",
				"first_rescue_done",
				"first_bait_resolved",
				"five_cats",
				"rank_up_card_seen",
				"rank_up_ready",
				"tier_2",
				"first_park_catch",
				"returned_next_day",
				"first_offline_claim",
				"tier_3",
			})
		end)
	end)
end
