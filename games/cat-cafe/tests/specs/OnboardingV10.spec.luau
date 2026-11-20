--!strict
-- shared/Onboarding.v10Due (#5533 v2): onboarding_v10, the play first start's milestones.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Onboarding = require(Shared.Onboarding)
	local ProfileSchema = require(Shared.ProfileSchema)

	local function fresh(): any
		local state = ProfileSchema.template(1000).telemetry :: any
		Onboarding.reach(state, "joined")
		Onboarding.reach(state, "loaded")
		return state
	end
	local function facts(tier: number, hand: number, park: boolean?, ready: boolean?): any
		return { tier = tier, handCats = hand, parkCatch = park == true, nextReady = ready == true }
	end

	it("has its ten milestones in order", function()
		expect(Onboarding.V10_COUNT).to.equal(10)
		expect(Onboarding.V10_STEPS[3]).to.equal("first_catch")
		expect(Onboarding.V10_STEPS[10]).to.equal("tier_3")
	end)

	it("logs joined and loaded, then first_catch only on the net catch", function()
		local state = fresh()
		local due = Onboarding.v10Due(state, 0, facts(1, 0))
		expect(#due).to.equal(2)
		expect(#Onboarding.v10Due(state, 2, facts(1, 0), "arrived_park")).to.equal(0)
		local caught = Onboarding.v10Due(state, 2, facts(1, 0), "net_catch")
		expect(#caught).to.equal(1)
		expect(caught[1]).to.equal(3)
	end)

	it("lets a done step prove the ones before it", function()
		local state = fresh()
		local due = Onboarding.v10Due(state, 2, facts(1, 1))
		expect(due[#due]).to.equal(4) -- first_home proves first_catch
		local ready = Onboarding.v10Due(state, 4, facts(1, 3, false, true))
		expect(ready[#ready]).to.equal(6) -- catches_3, rank_ready
		local tier2 = Onboarding.v10Due(state, 6, facts(2, 3))
		expect(tier2[#tier2]).to.equal(7)
		local arrived = Onboarding.v10Due(state, 7, facts(2, 3), "arrived_park")
		expect(arrived[1]).to.equal(8)
		local done = Onboarding.v10Due(state, 8, facts(3, 5, true))
		expect(done[#done]).to.equal(10)
	end)

	it("keeps only a whole saved step in range", function()
		local raw = ProfileSchema.template(1000) :: any
		raw.telemetry.cleanV10Step = 99
		expect(ProfileSchema.migrate(raw, 1000).telemetry.cleanV10Step).to.equal(Onboarding.V10_COUNT)
		local other = ProfileSchema.template(1000) :: any
		other.telemetry.cleanV10Step = "x"
		expect(ProfileSchema.migrate(other, 1000).telemetry.cleanV10Step).to.equal(nil)
	end)
end
