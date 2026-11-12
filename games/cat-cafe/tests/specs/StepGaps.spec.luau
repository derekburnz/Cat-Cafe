--!strict
-- shared/StepGaps (#3530): step_gap buckets, quit_have fields, and Onboarding.reachDetail's held and released steps.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Onboarding = require(Shared.Onboarding)
	local StepGaps = require(Shared.StepGaps)

	local function state(): any
		return { onboardingStep = 0, achieved = {} }
	end

	describe("gaps", function()
		it("names five gaps between real onboarding steps, the first before the second", function()
			expect(#StepGaps.GAPS).to.equal(5)
			local seen: { [string]: boolean } = {}
			for _, gap in StepGaps.GAPS do
				expect(seen[gap.name]).to.equal(nil)
				seen[gap.name] = true
				expect(Onboarding.index(gap.from) >= 1).to.equal(true)
				expect(Onboarding.index(gap.to) > Onboarding.index(gap.from)).to.equal(true)
			end
			expect(seen.bait_to_rescue).to.equal(true)
			expect(seen.served_to_second_cat).to.equal(true)
			expect(seen.second_cat_to_five).to.equal(true)
			expect(seen.ready_to_tier_2).to.equal(true)
			expect(seen.loaded_to_first_move).to.equal(true)
		end)

		it("finds the gaps a step ends and the steps worth a clock", function()
			local ends = StepGaps.endingAt("tier_2")
			expect(#ends).to.equal(1)
			expect(ends[1].name).to.equal("ready_to_tier_2")
			expect(#StepGaps.endingAt("first_bait")).to.equal(0)
			expect(StepGaps.marks("first_bait")).to.equal(true)
			expect(StepGaps.marks("second_cat")).to.equal(true)
			expect(StepGaps.marks("first_table")).to.equal(false)
		end)
	end)

	describe("bucket", function()
		it("has four buckets with edges at 15, 60 and 120 seconds", function()
			expect(StepGaps.bucket(0)).to.equal("under_15s")
			expect(StepGaps.bucket(14.9)).to.equal("under_15s")
			expect(StepGaps.bucket(15)).to.equal("15_60s")
			expect(StepGaps.bucket(59.9)).to.equal("15_60s")
			expect(StepGaps.bucket(60)).to.equal("60_120s")
			expect(StepGaps.bucket(119.9)).to.equal("60_120s")
			expect(StepGaps.bucket(120)).to.equal("over_120s")
			expect(StepGaps.bucket(1e9)).to.equal("over_120s")
			expect(StepGaps.bucket(0 / 0)).to.equal("under_15s")
		end)

		it("measures from the session clock, and says so when it cannot", function()
			local seconds, bucket = StepGaps.measure(true, 100, 139.6)
			expect(seconds).to.equal(39)
			expect(bucket).to.equal("15_60s")
			seconds, bucket = StepGaps.measure(true, nil, 500)
			expect(seconds).to.equal(0)
			expect(bucket).to.equal("earlier_visit")
			seconds, bucket = StepGaps.measure(false, 100, 500)
			expect(seconds).to.equal(0)
			expect(bucket).to.equal("no_start")
			seconds, bucket = StepGaps.measure(true, 500, 100)
			expect(seconds).to.equal(0)
			expect(bucket).to.equal("under_15s")
		end)
	end)

	describe("quit_have", function()
		it("caps kinds of cat at five", function()
			expect(StepGaps.kinds(0)).to.equal("0")
			expect(StepGaps.kinds(3)).to.equal("3")
			expect(StepGaps.kinds(5)).to.equal("5")
			expect(StepGaps.kinds(40)).to.equal("5")
			expect(StepGaps.kinds(-2)).to.equal("0")
			expect(StepGaps.kinds(0 / 0)).to.equal("0")
		end)

		it("puts coins in four shares of the Tier 2 cost", function()
			expect(StepGaps.coinShare(0, 13500)).to.equal("under_25")
			expect(StepGaps.coinShare(3374, 13500)).to.equal("under_25")
			expect(StepGaps.coinShare(3375, 13500)).to.equal("25_50")
			expect(StepGaps.coinShare(6750, 13500)).to.equal("50_75")
			expect(StepGaps.coinShare(10125, 13500)).to.equal("75_plus")
			expect(StepGaps.coinShare(1e12, 13500)).to.equal("75_plus")
			expect(StepGaps.coinShare(100, 0)).to.equal("75_plus")
			expect(StepGaps.coinShare(0 / 0, 13500)).to.equal("under_25")
		end)

		it("sends three low cardinality fields", function()
			local fields = StepGaps.quitFields(4, 7000, 13500, false)
			expect(#fields).to.equal(3)
			expect(fields[1]).to.equal("4")
			expect(fields[2]).to.equal("50_75")
			expect(fields[3]).to.equal("not_ready")
			expect(StepGaps.quitFields(5, 20000, 13500, true)[3]).to.equal("ready")
		end)
	end)

	describe("reachDetail", function()
		it("logs like reach when nothing is held", function()
			local s = state()
			local reach = Onboarding.reachDetail(s, "joined")
			expect(reach.log :: any).to.deepEqual({ "joined" })
			expect(#reach.held).to.equal(0)
			expect(next(reach.released)).to.equal(nil)
		end)

		it(
			"names the bait result as held when it comes before the rescue, then as released",
			function()
				local s = state()
				-- everything up to the first bait, in order
				for index = 1, Onboarding.index("first_bait") do
					Onboarding.reach(s, Onboarding.STEPS[index] :: any)
				end
				expect(Onboarding.furthest(s)).to.equal("first_bait")
				local early = Onboarding.reachDetail(s, "first_bait_resolved")
				expect(#early.log).to.equal(0)
				expect(early.held :: any).to.deepEqual({ "first_bait_resolved" })
				-- reached again while held: nothing new
				local again = Onboarding.reachDetail(s, "first_bait_resolved")
				expect(#again.log).to.equal(0)
				expect(#again.held).to.equal(0)
				local started = Onboarding.reachDetail(s, "first_rescue_started")
				expect(started.log :: any).to.deepEqual({ "first_rescue_started" })
				expect(next(started.released)).to.equal(nil)
				local done = Onboarding.reachDetail(s, "first_rescue_done")
				expect(done.log :: any).to.deepEqual({ "first_rescue_done", "first_bait_resolved" })
				expect(done.released.first_bait_resolved).to.equal(true)
				expect(done.released.first_rescue_done).to.equal(nil)
				expect(#done.held).to.equal(0)
			end
		)

		it("names implied steps put on hold with the step itself", function()
			local s = state()
			for index = 1, Onboarding.index("five_cats") do
				Onboarding.reach(s, Onboarding.STEPS[index] :: any)
			end
			-- tier_2 with the card never reported: rank_up_card_seen logs, rank_up_ready and tier_2 follow in order
			local reach = Onboarding.reachDetail(s, "tier_2")
			expect(reach.log :: any).to.deepEqual({ "rank_up_card_seen", "rank_up_ready", "tier_2" })
			expect(#reach.held).to.equal(0)
			expect(next(reach.released)).to.equal(nil)
		end)

		it(
			"times every step exactly once over 300 seeded orders (held now or logged, never both)",
			function()
				local random = Random.new(3530)
				for _ = 1, 300 do
					local s = state()
					local order = table.clone(Onboarding.STEPS)
					random:Shuffle(order)
					local timed: { [string]: number } = {}
					for _, name in order do
						local reach = Onboarding.reachDetail(s, name :: any)
						for _, held in reach.held do
							timed[held] = (timed[held] or 0) + 1
						end
						for _, logged in reach.log do
							if not reach.released[logged] then
								timed[logged] = (timed[logged] or 0) + 1
							end
						end
					end
					for _, name in Onboarding.STEPS do
						expect(timed[name]).to.equal(1)
					end
				end
			end
		)
	end)
end
